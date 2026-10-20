# Cómo funciona por dentro

Este artículo describe el diseño interno de fhirviews para quien quiera
entender sus resultados, evaluar si sirve para un proyecto o contribuir
al código. Para empezar a usarlo, mejor la viñeta [*Primeros
pasos*](https://f-slg.github.io/fhirviews/fhirviews.md).

``` r

library(fhirviews)
fhirviews_motor()
#> Motor de FHIRPath: v8
#> fhirpath.js:       5.2.1
#> V8:                12.4.254.21
```

## Visión general

``` mermaid
flowchart LR
    subgraph R["R"]
        CL["Cliente FHIR<br/>R/cliente.R"]
        RE["fhir_recursos()<br/>R/recursos.R"]
        VA["Validador<br/>R/validar.R"]
        MV["Motor de vistas<br/>R/vista.R"]
        MO["Interfaz de motores<br/>R/motor.R"]
    end
    subgraph V8["V8 (JavaScript)"]
        GL["Capa propia<br/>inst/js/fhirviews.js"]
        FP["fhirpath.js 5.2.1<br/>+ modelo FHIR R4"]
    end
    SV["Servidor FHIR"] <-->|"httr2<br/>application/fhir+json"| CL
    CL --> RE
    RE --> MV
    VA --> MV
    MV --> MO
    MO <-->|"JSON"| GL
    GL --> FP
```

El paquete tiene cuatro piezas con responsabilidades separadas:

| Pieza | Archivo | Responsabilidad |
|----|----|----|
| Cliente | `R/cliente.R` | Peticiones HTTP, paginación, errores |
| Autenticación | `R/autenticacion.R` | SMART on FHIR / OAuth2: descubrimiento, tokens y su renovación |
| Exportación masiva | `R/bulk.R` | FHIR Bulk Data (`$export`): inicio, espera, manifiesto y descarga |
| Motor DuckDB | `R/sql.R` | Traducción de `ViewDefinition` y FHIRPath a SQL de DuckDB |
| Recursos | `R/recursos.R` | Reunir recursos de cualquier fuente y conservar su JSON original |
| Motor de vistas | `R/vista.R`, `R/validar.R` | Validar y ejecutar `ViewDefinition`, armar la tabla |
| Motor de FHIRPath | `R/motor.R`, `inst/js/fhirviews.js` | Evaluar expresiones FHIRPath por lotes |

## Cliente FHIR

Todas las peticiones pasan por una sola función interna,
`peticion_json()`, que:

- envía `Accept: application/fhir+json` (y `Content-Type` del mismo tipo
  con cuerpo), un `User-Agent` propio y las cabeceras de la conexión;
- agrega el token *bearer* **solo** si la URL pertenece al servidor de
  la conexión (los enlaces [`next`](https://rdrr.io/r/base/Control.html)
  que apunten a otro dominio no lo reciben);
- reintenta hasta tres veces ante 429 y 503, respetando `Retry-After`;
- convierte cualquier respuesta de error en una condición de R con clase
  `fhirviews_error_http_<código>`, el estado y el `OperationOutcome`
  completo, y un mensaje con sus `issue`:

``` r

e <- tryCatch(fhir_leer(con, "Patient", "x"), fhirviews_error_http_404 = function(e) e)
e$estado       # 404
e$outcome      # OperationOutcome como lista de R
```

La paginación sigue los enlaces
[`next`](https://rdrr.io/r/base/Control.html) de cada Bundle hasta que
no hay más o se alcanza `max_paginas`, y se detiene con un aviso si el
servidor repite un enlace. Cada página se guarda también como texto JSON
(ver más abajo).

[`fhir_crear()`](https://f-slg.github.io/fhirviews/reference/fhir_crear.md)
distingue los Bundle `transaction` y `batch`, que se envían a la base
del servidor para que los procese, del resto de recursos, que se envían
a `[base]/[tipo]`.

## Autenticación SMART on FHIR

[`fhir_auth_cliente()`](https://f-slg.github.io/fhirviews/reference/fhir_auth.md),
[`fhir_auth_backend()`](https://f-slg.github.io/fhirviews/reference/fhir_auth.md)
y
[`fhir_auth_interactiva()`](https://f-slg.github.io/fhirviews/reference/fhir_auth.md)
solo describen la autenticación;
[`fhir_conectar()`](https://f-slg.github.io/fhirviews/reference/fhir_conectar.md)
la prepara:

1.  Si no se indicaron las URL, las descubre con
    [`fhir_smart_configuracion()`](https://f-slg.github.io/fhirviews/reference/fhir_smart_configuracion.md):
    primero `[base]/.well-known/smart-configuration` y, si no existe,
    las extensiones `oauth-uris` del `CapabilityStatement` (SMART v1).
2.  Crea un cliente OAuth de httr2 con el método de autenticación
    adecuado: `client_secret_basic` o `client_secret_post` (según lo que
    declare el servidor) o `private_key_jwt` con una clave RS384 o
    ES384.
3.  En cada petición al propio servidor, `peticion_json()` obtiene el
    token vigente de la caché en memoria de httr2, que lo pide la
    primera vez y lo renueva cuando le quedan menos de 30 segundos. Si
    el servidor responde 401, descarta el token, pide otro y reintenta
    una sola vez.

En *Backend Services*, httr2 firma un JWT nuevo en cada pedido de token
(`iss` y `sub` = id del cliente, `aud` = URL del token, `exp` a cinco
minutos, `jti` aleatorio y `kid` en la cabecera). Se verificó con un
servidor de autorización independiente, escrito en Python con PyJWT, que
comprueba la firma y rechaza un `jti` repetido o una clave que no
corresponde.

## Exportación masiva

[`fhir_exportar()`](https://f-slg.github.io/fhirviews/reference/fhir_exportar.md)
sigue el protocolo asíncrono de [FHIR Bulk
Data](https://hl7.org/fhir/uv/bulkdata/):

| Paso | Petición | Respuesta esperada |
|----|----|----|
| Inicio | `GET [base]/$export`, `Patient/$export` o `Group/[id]/$export`, con `Prefer: respond-async` | `202 Accepted` + `Content-Location` |
| Estado | `GET [Content-Location]` | `202` (en curso, con `Retry-After` y `X-Progress`) o `200` con el manifiesto |
| Descarga | `GET [archivo]` por cada entrada de `output` y `error` | NDJSON |
| Cancelación | `DELETE [Content-Location]` | `202` |

Detalles de diseño:

- **Espera.** Respeta `Retry-After` (en segundos o como fecha HTTP); sin
  él, espera 1, 2, 4… segundos hasta un máximo de 60 entre consultas. Al
  superar `max_espera`, devuelve el trabajo en curso con un aviso, para
  retomarlo con
  [`fhir_exportar_estado()`](https://f-slg.github.io/fhirviews/reference/fhir_exportar.md).
- **Descarga.** Los archivos se escriben directamente en disco, sin
  pasar por la memoria; sin tiempo total máximo, pero se cortan si la
  transferencia se detiene durante `tiempo` segundos.
- **Seguridad.** El token se envía a un archivo solo si el manifiesto lo
  exige (`requiresAccessToken`) y el archivo está en el mismo servidor;
  si está en otro dominio, se detiene con un error en lugar de enviarlo.

## Recursos y el texto JSON original

[`fhir_recursos()`](https://f-slg.github.io/fhirviews/reference/fhir_recursos.md)
acepta listas de R, Bundles, texto JSON o NDJSON y archivos (incluidos
`.ndjson.gz`), y devuelve una lista de clase `fhir_recursos`. Cuando los
recursos vienen de texto (un archivo o un servidor), además guarda ese
texto en el atributo `fuente`:

``` r

caso <- fhir_recursos(system.file("extdata", "caso_clinico.ndjson",
                                  package = "fhirviews"))
length(attr(caso, "fuente"))   # una línea de NDJSON por recurso
#> [1] 60
```

Al ejecutar una vista, el motor pasa ese texto a V8, que lo lee con
`JSON.parse()`. Convertir listas de R a JSON con
[`jsonlite::toJSON()`](https://jeroen.r-universe.dev/jsonlite/reference/fromJSON.html)
es la parte más lenta del proceso, así que este atajo hace las vistas
unas cuatro veces más rápidas. Si la lista se modifica
(`r[[1]] <- ...`), el atributo se descarta y se usa la versión
modificada.

## Motor de FHIRPath

### Interfaz

El motor de vistas no llama a fhirpath.js directamente: usa un *motor*,
una lista de funciones (`cargar`, `evaluar`, `validar`, `tipo`,
`tamano`, `liberar`, `version`). Hoy existe el motor `"v8"`; un motor
escrito en R solo tendría que implementar la misma interfaz y se
elegiría con `options(fhirviews.motor = ...)`.

### Almacén de nodos

En V8 vive un almacén de **nodos**: los recursos cargados y los
elementos que devuelven `forEach` y `repeat`. R los maneja por su
índice. Una llamada evalúa una expresión sobre muchos nodos a la vez:

``` r

m <- fhirviews:::motor_actual()
inicio <- m$tamano()
ids <- m$cargar(caso[vapply(caso, function(r) r$resourceType == "Observation",
                            logical(1))])
length(ids)
#> [1] 12
# una sola llamada para las 12 observaciones
m$evaluar(ids[1:3], "code.text")
#> [[1]]
#> [[1]][[1]]
#> [1] "Presión arterial"
#> 
#> 
#> [[2]]
#> [[2]][[1]]
#> [1] "Temperatura corporal"
#> 
#> 
#> [[3]]
#> [[3]][[1]]
#> [1] "Frecuencia respiratoria"
# los componentes se guardan como nodos y conservan su tipo
comp <- m$evaluar(ids, "component", modo = "nodos")
m$evaluar(unlist(comp)[1:2], "value.ofType(Quantity).value")
#> [[1]]
#> [[1]][[1]]
#> [1] 128
#> 
#> 
#> [[2]]
#> [[2]][[1]]
#> [1] 84
m$liberar(inicio)
```

Como los nodos guardados conservan su tipo FHIR (son `ResourceNode` de
fhirpath.js), `ofType(Quantity)` funciona sobre un componente aunque se
evalúe aparte de su recurso. Las expresiones se compilan una vez y se
guardan en caché, y `%resource` apunta siempre al recurso de origen del
nodo.

### Funciones de SQL on FHIR

fhirpath.js no trae `getResourceKey()` ni `getReferenceKey()`; la capa
propia las define:

- `getResourceKey()` devuelve el `id` del recurso.
- `getReferenceKey([tipo])` devuelve el id de una referencia relativa o
  absoluta (sin `_history`). Con un tipo, solo si la referencia apunta a
  ese tipo de recurso.

Las constantes de fecha y hora (`valueDate`, `valueDateTime`…) se pasan
como literales de FHIRPath (`@2025-01-01`) para que se comparen como
fechas.

### Carga de fhirpath.js

`fhirpath.min.js` contiene bytes `0x1A` (Ctrl-Z) dentro de las tablas
del analizador ANTLR. En Windows, la lectura en modo texto los toma como
fin de archivo y corta el script, así que los archivos JavaScript se
leen en binario ([`readBin()`](https://rdrr.io/r/base/readBin.html)) en
lugar de con `V8::source()`.

## Motor de vistas

### Lotes y contextos

Un *contexto* es un lote de nodos con su `%rowIndex`. Cada parte de la
vista se evalúa sobre todo el lote y devuelve filas que recuerdan de qué
nodo salieron (`origen`):

``` mermaid
flowchart TD
    subgraph lote["Contexto: n nodos"]
        N1["nodo 1"]
        N2["nodo 2"]
        N3["..."]
    end
    lote -->|"column: 1 llamada por columna"| C["n filas"]
    lote -->|"forEach: 1 llamada"| H["hijos de cada nodo<br/>(nuevo contexto, %rowIndex 0, 1, ...)"]
    H -->|"partes anidadas"| F["filas de los hijos<br/>(origen = nodo padre)"]
    C --> P["producto por origen<br/>rep() + sequence()"]
    F --> P
```

- **`column`**: una llamada a FHIRPath por columna para todo el lote.
  Sin `collection: true`, una expresión que devuelve varios valores es
  un error que explica cómo resolverlo.
- **`forEach` / `forEachOrNull`**: una llamada que devuelve los hijos de
  cada nodo como nodos nuevos; `%rowIndex` es su posición. Con
  `forEachOrNull`, los nodos sin hijos reciben un nodo vacío, que
  produce una fila con `NA`.
- **`repeat`**: recorrido en profundidad (preorden) por las rutas
  indicadas, nivel por nivel: una llamada por ruta y nivel del árbol.
- **`unionAll`**: las filas de cada rama se concatenan y se ordenan de
  forma estable por su origen.
- **Producto**: las filas de las partes de una selección se combinan por
  recurso de origen con índices, sin bucles por recurso.

Así, el número de llamadas a V8 depende de la forma de la vista, no del
número de recursos:

``` r

vista <- vista_crear("Patient", c(sistema = "system", valor = "value"),
                     por_cada = "telecom")
system.time(vista_ejecutar(caso, vista))
#>    user  system elapsed 
#>   0.007   0.000   0.008
```

### Orden de columnas y de filas

Las columnas siguen la especificación: las de `column`, luego las de los
`select` anidados y al final las del `unionAll`. El orden de las filas
sigue el de los recursos y, dentro de cada uno, el de sus elementos; la
especificación no lo garantiza, así que no conviene depender de él.

### Tipos

``` mermaid
flowchart LR
    V["valores de una columna"] --> T{"¿tiene type?"}
    T -->|"sí"| C["convertir:<br/>boolean, integer, decimal, texto"]
    C -->|"valor incompatible"| A["aviso y valores sin convertir"]
    T -->|"no"| E{"¿tiene valores?"}
    E -->|"sí"| R["tipo de R de los valores"]
    E -->|"no"| M["tipo deducido del<br/>modelo FHIR R4"]
```

Para deducir el tipo sin datos, la capa JS recorre la expresión paso a
paso con el modelo R4 de fhirpath.js (`path2Type`, `choiceTypePaths`,
`pathsDefinedElsewhere`) y conoce el tipo que devuelven las funciones
habituales ([`exists()`](https://rdrr.io/r/base/exists.html) es lógico,
`count()` entero, `join()` texto…):

``` r

ctx <- list(tipo = "Patient", ruta = "Patient")
m$tipo(ctx, "birthDate")$tipo
#> [1] "date"
m$tipo(ctx, "name.where(use = 'official').family")$tipo
#> [1] "string"
m$tipo(list(tipo = "Observation", ruta = "Observation"),
       "component.value.ofType(Quantity).value")$tipo
#> [1] "decimal"
```

Si la expresión es más compleja (operadores, funciones desconocidas), no
se deduce nada y la columna vacía queda como lógica, como en R.

### Validación

[`vista_validar()`](https://f-slg.github.io/fhirviews/reference/vista_validar.md)
revisa toda la vista antes de ejecutarla y devuelve **todos** los
problemas a la vez (en `e$problemas`): elementos permitidos, un solo
tipo de iteración por selección, arreglos no vacíos, nombres de columnas
válidos en SQL y sin repetir, ramas de `unionAll` con las mismas
columnas, constantes con un solo valor y sin nombres reservados, y que
cada expresión FHIRPath compile.

## Motor DuckDB

[`vista_ejecutar_duckdb()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar_duckdb.md)
es un segundo motor, experimental, que no usa V8: traduce el
`ViewDefinition` completo a **una sola consulta SQL** de DuckDB.

- **Lectura sin esquema.** Cada línea del NDJSON se lee como un valor
  `JSON` con `read_json_objects()` (Parquet con `read_parquet()` y
  `to_json()`). No hace falta un esquema FHIR, así que funcionan los
  elementos de elección, las extensiones y los recursos heterogéneos.
- **Colecciones como listas.** Cada expresión FHIRPath traducida es una
  lista `JSON[]`, un valor JSON o un valor de SQL tipado. `a.b` es
  `json_extract` sobre cada elemento; `where()` y `select()` son
  `list_filter()` y `list_transform()`; los elementos de elección
  (`value`, `onset`…) buscan todas sus variantes según el modelo R4.
- **Estructura dentro de cada fila.** Cada `select` produce la lista de
  filas de un recurso; `forEach` usa `list_transform()` con el índice
  (para `%rowIndex`), `unionAll` concatena listas, `repeat` se resuelve
  por niveles (hasta `fhirviews.sql_profundidad`, 12 por defecto) y la
  consulta final aplica `unnest()`. Sin subconsultas correlacionadas,
  DuckDB procesa los archivos en paralelo, por bloques.
- **Errores.** Lo que no se puede traducir con certeza da un error de
  clase `fhirviews_error_sql` al traducir; una columna con varios
  valores sin `collection` o un `where` que no da un lógico son errores
  al ejecutar.
- **Garantía.** Además del banco oficial (133/133 *shareable*), una
  prueba diferencial ejecuta las vistas de todas las viñetas con los dos
  motores y exige tablas idénticas, valores y tipos.

``` r

cat(substr(vista_sql(vista_crear("Patient", c(sexo = "gender"))), 1, 300), "...")
#> SELECT f."id" AS "id", f."sexo" AS "sexo"
#> FROM (
#>   SELECT unnest([{'id': json_extract_string(r, '$.id'), 'sexo': json_extract_string(list_extract(list_transform([flatten(list_transform([json_extract(r, '$."gender"')], lambda z1: CASE WHEN z1 IS NULL OR CAST(z1 AS VARCHAR) = 'null' THEN []::JSON[] WH ...
```

## Seguridad y privacidad

- **FHIRPath aislado.** fhirpath.js corre en V8 sin acceso a red ni a
  archivos. Las funciones que harían peticiones (`resolve()`,
  `memberOf()` con un servidor de terminología) están desactivadas
  porque el modo asíncrono no se habilita.
- **Sin evaluación de código.** Los recursos se leen con `JSON.parse()`
  y las expresiones viajan a V8 como texto JSON escapado. Los addins de
  RStudio convierten el texto seleccionado en una cadena de R con
  [`deparse1()`](https://rdrr.io/r/base/deparse.html).
- **Token.** No se imprime (tampoco el secreto ni la clave privada),
  solo se envía al servidor de la conexión, el código que genera el
  panel *Connections* lo toma de
  [`Sys.getenv()`](https://rdrr.io/r/base/Sys.getenv.html) y se avisa si
  se usaría sin cifrar por http.
- **Datos personales.** Los mensajes de error incluyen la URL de la
  petición, con sus parámetros de búsqueda: si buscas por cédula u otro
  identificador, aparecerá en el error. Tenlo en cuenta al compartir
  registros o capturas.

## Limitaciones conocidas

- **Precisión decimal.** JSON no conserva los ceros finales (`1.10` se
  lee como `1.1`) y los enteros mayores que 2^53 pierden precisión. Por
  eso fallan las pruebas experimentales de `lowBoundary()` y
  `highBoundary()`.
- **Referencias.** `getReferenceKey()` no resuelve referencias
  `urn:uuid:` (las de los Bundle de transacción) ni a recursos
  contenidos (`#id`): devuelve vacío.
- **FHIR R4.** El modelo de tipos es el de R4.
- **Interrupciones.** Una evaluación larga dentro de V8 no se puede
  detener con Ctrl+C hasta que termina la llamada.

## Pruebas

| Conjunto | Qué cubre | Dónde corre |
|----|----|----|
| Banco oficial de SQL on FHIR | 144 pruebas, una expectativa por prueba *shareable* | Siempre |
| Motor y vistas | FHIRPath, tipos, validación, casos límite | Siempre |
| Cliente simulado | Peticiones, paginación, errores, transacciones (httr2 simulado) | Siempre |
| RStudio | Panel *Connections* con un observador simulado | Siempre |
| Servidor público | Lectura y paginación en hapi.fhir.org | Fuera de CRAN, con conexión |
| Servidor propio | Ciclo de escritura completo | Si `FHIRVIEWS_SERVIDOR_ESCRITURA` apunta a un servidor de pruebas |

La cobertura de las pruebas es de alrededor del 91 %.
