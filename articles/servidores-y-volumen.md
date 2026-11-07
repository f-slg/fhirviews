# Servidores reales y grandes volúmenes

Las viñetas anteriores trabajan con servidores de prueba abiertos y con
datos que caben cómodamente en memoria. En un hospital, un ministerio o
una red de servicios aparecen cuatro necesidades más, que fhirviews
cubre:

| Necesidad | Qué usar | Sección |
|----|----|----|
| El servidor exige iniciar sesión (OAuth2) | `autenticacion = fhir_auth_*()` en [`fhir_conectar()`](https://f-slg.github.io/fhirviews/reference/fhir_conectar.md) | [1](#autenticacion-smart-on-fhir) |
| Descargar una población completa, no solo una búsqueda | [`fhir_exportar()`](https://f-slg.github.io/fhirviews/reference/fhir_exportar.md) (FHIR Bulk Data, `$export`) | [2](#exportacion-masiva-con-export) |
| Aplanar millones de recursos en un portátil | [`vista_ejecutar_duckdb()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar_duckdb.md) (motor DuckDB) | [3](#motor-duckdb-millones-de-recursos) |
| Definir un indicador con un `ValueSet` (todos los códigos de diabetes) | [`tx_expandir()`](https://f-slg.github.io/fhirviews/reference/tx_expandir.md) y [`vista_con_valueset()`](https://f-slg.github.io/fhirviews/reference/vista_con_valueset.md) | [4](#terminologias) |

Al final, la [sección 5](#flujo-completo) une las piezas en un flujo de
vigilancia epidemiológica.

``` r

library(fhirviews)
```

## 1. Autenticación SMART on FHIR

Los servidores FHIR de producción casi nunca son abiertos: usan [SMART
on FHIR](https://hl7.org/fhir/smart-app-launch/), el perfil de OAuth2
del mundo FHIR. En lugar de pegar un token a mano (que además caduca),
[`fhir_conectar()`](https://f-slg.github.io/fhirviews/reference/fhir_conectar.md)
recibe una configuración de autenticación y se encarga de pedir el
token, renovarlo y enviarlo solo al servidor correcto.

### ¿Qué flujo usar?

| Flujo | Función | Cuándo | Credenciales |
|----|----|----|----|
| *Client credentials* con secreto | [`fhir_auth_cliente()`](https://f-slg.github.io/fhirviews/reference/fhir_auth.md) | Integraciones sencillas entre sistemas | `client_id` + secreto compartido |
| SMART Backend Services | [`fhir_auth_backend()`](https://f-slg.github.io/fhirviews/reference/fhir_auth.md) | Procesos automáticos: ETL, tableros, exportaciones nocturnas. Es el flujo que exigen la mayoría de servidores para `$export` | `client_id` + clave privada (RS384 o ES384); el servidor conoce la clave pública |
| *Authorization code* + PKCE | [`fhir_auth_interactiva()`](https://f-slg.github.io/fhirviews/reference/fhir_auth.md) | Una persona usa R y accede con su propio usuario | `client_id` (y secreto, si el cliente es confidencial); inicio de sesión en el navegador |

### Backend Services paso a paso

1.  **Generar el par de claves** (una sola vez). La clave privada se
    queda en tu equipo; la pública, en formato JWKS, se entrega al
    administrador del servidor de autorización para registrar el
    cliente:

    ``` r

    clave <- openssl::rsa_keygen(2048)
    openssl::write_pem(clave, "~/.claves/fhir-privada.pem")
    # JWKS con la clave pública, para registrar el cliente
    cat(jose::write_jwk(clave$pubkey))
    ```

2.  **Conectarse.** Las URL del servidor de autorización se descubren
    solas en `[base]/.well-known/smart-configuration` (o en el
    `CapabilityStatement`, como en SMART v1):

    ``` r

    con <- fhir_conectar(
      "https://fhir.hospital.ejemplo/r4",
      autenticacion = fhir_auth_backend(
        id = "tablero-vigilancia",
        clave_privada = "~/.claves/fhir-privada.pem",
        alcances = c("system/Patient.rs", "system/Condition.rs"),
        kid = "clave-2026"
      )
    )
    con
    #> <fhir_conexion> https://fhir.hospital.ejemplo/r4
    #>   Servidor:     ...
    #>   Versión FHIR: 4.0.1
    #>   Autenticación: SMART Backend Services (JWT)
    #>   Cliente:      tablero-vigilancia
    ```

3.  **Trabajar como siempre.**
    [`fhir_buscar()`](https://f-slg.github.io/fhirviews/reference/fhir_buscar.md),
    [`fhir_leer()`](https://f-slg.github.io/fhirviews/reference/fhir_leer.md),
    [`fhir_exportar()`](https://f-slg.github.io/fhirviews/reference/fhir_exportar.md)
    y las demás funciones usan el token sin que tengas que hacer nada.

Para ver qué publica un servidor antes de configurar nada:

``` r

fhir_smart_configuracion("https://launch.smarthealthit.org/v/r4/fhir")
```

### Qué hace fhirviews con el token

- Lo pide en la primera petición y lo guarda en memoria (nunca en disco,
  salvo que lo pidas con `cache_disco = TRUE` en el flujo interactivo).
- Lo renueva solo, antes de que caduque. Si el servidor lo rechaza igual
  (por ejemplo, porque fue revocado), pide uno nuevo y reintenta una
  vez.
- En *Backend Services* firma un JWT nuevo en cada pedido, con un `jti`
  aleatorio y una validez de cinco minutos, como exige la
  especificación.
- Solo lo envía a URL del propio servidor FHIR: un enlace
  [`next`](https://rdrr.io/r/base/Control.html) o un archivo que apunte
  a otro dominio no lo recibe.
- No lo imprime nunca, como tampoco el secreto ni la clave. Para no
  escribir secretos en el código, guárdalos en variables de entorno
  (`Sys.getenv("FHIR_SECRETO")`) o en un gestor de credenciales.

Si las credenciales son incorrectas, el error es explícito:

``` r

#> Error:
#> ! No se pudo obtener el token de acceso.
#> ✖ <https://auth.hospital.ejemplo/token>
#> ℹ OAuth failure [invalid_client] • Signature verification failed
```

## 2. Exportación masiva con `$export`

[`fhir_buscar()`](https://f-slg.github.io/fhirviews/reference/fhir_buscar.md)
es ideal para consultas puntuales, pero para una población completa
(todos los pacientes de una red, todas las notificaciones de un año) el
estándar es [FHIR Bulk Data Access](https://hl7.org/fhir/uv/bulkdata/):
el servidor prepara en segundo plano archivos NDJSON, un recurso por
línea, y el cliente los descarga cuando están listos.

### El ciclo de una exportación

| Paso | Petición | Qué hace [`fhir_exportar()`](https://f-slg.github.io/fhirviews/reference/fhir_exportar.md) |
|----|----|----|
| 1\. Inicio | `GET [base]/Patient/$export` con `Prefer: respond-async` | Envía los filtros y recibe `202 Accepted` con la dirección de estado |
| 2\. Espera | `GET [estado]` → `202` | Respeta `Retry-After`, muestra el avance (`X-Progress`) y, si el servidor no indica nada, espera cada vez más (1, 2, 4… hasta 60 s) |
| 3\. Manifiesto | `GET [estado]` → `200` | Lee la lista de archivos por tipo de recurso |
| 4\. Descarga | `GET [archivo]` | Guarda cada NDJSON en la carpeta indicada, con el token solo si el manifiesto lo exige |

``` r

# Servidor de referencia de SMART Health IT (datos sintéticos, abierto)
con <- fhir_conectar("https://bulk-data.smarthealthit.org/fhir")
#> <fhir_conexion> https://bulk-data.smarthealthit.org/fhir
#>   Servidor:     SMART Sample Bulk Data Server 2.1.1
#>   Versión FHIR: 4.0.1

exp <- fhir_exportar(
  con,
  nivel = "paciente",                 # "sistema", "paciente" o "grupo"
  tipos = c("Patient", "Condition", "Observation"),
  carpeta = "exportacion"
)
exp
#> <fhir_exportacion> completada (nivel paciente)
#>   Carpeta: exportacion
#>   Condition                1 archivo, 639 recursos
#>   Observation              2 archivos, 16315 recursos
#>   Patient                  1 archivo, 100 recursos
```

(Salida real de octubre de 2026: la exportación tardó unos 5 segundos.)
Con `desde = as.Date("2025-01-01")` (`_since`) se exporta solo lo
modificado desde esa fecha, útil para actualizaciones incrementales.

Los archivos quedan listos para el motor de vistas:

``` r

pacientes <- fhir_recursos(exp$archivos$Patient)
head(vista_ejecutar(pacientes, vista_crear("Patient", c(sexo = "gender",
                                                        nacimiento = "birthDate"))), 3)
#>                                     id   sexo nacimiento
#> 1 58c297c4-d684-4677-8024-01131d93835e female 1971-04-05
#> 2 588675dc-e80e-4528-a78f-af10f9755f23   male 2015-10-04
#> 3 118616a4-f0b2-411f-8050-39d5d27c738c   male 1995-05-04
```

### Exportaciones largas

En servidores grandes una exportación puede tardar horas. Con
`esperar = FALSE` se inicia y se consulta después, incluso desde otra
sesión de R si guardas el objeto:

``` r

trabajo <- fhir_exportar(con, "grupo", grupo = "cohorte-diabetes",
                         esperar = FALSE)
saveRDS(trabajo, "trabajo-export.rds")

# Más tarde
trabajo <- readRDS("trabajo-export.rds")
trabajo <- fhir_exportar_estado(trabajo)                  # una consulta
trabajo <- fhir_exportar_estado(trabajo, esperar = TRUE)  # hasta que termine
fhir_exportar_cancelar(trabajo)                           # o cancelarla
```

Los parámetros `filtros` (`_typeFilter`, por ejemplo
`"Condition?code=http://hl7.org/fhir/sid/icd-10|A90"`) y `max_espera`
controlan qué se exporta y cuánto se espera. Si el servidor informa
problemas (un `OperationOutcome` en la lista `error` del manifiesto), se
descargan en la subcarpeta `errores/` y se avisan.

## 3. Motor DuckDB: millones de recursos

Los bloques de esta sección se ejecutan al construir la viñeta solo si
se configura `FHIRVIEWS_VINETAS_DUCKDB=true`. La construcción estándar
los omite para evitar descargas. En un entorno sin internet, instala
previamente la extensión `json` con la misma versión de DuckDB y en el
directorio de extensiones que usará el proceso; comprueba `LOAD json`
antes de ejecutar el motor SQL.

[`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md)
evalúa FHIRPath con fhirpath.js dentro de R: es completo y preciso, pero
trabaja en memoria y su tiempo crece con cada recurso. Para volúmenes
grandes,
[`vista_ejecutar_duckdb()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar_duckdb.md)
**traduce el `ViewDefinition` a una consulta SQL** y la ejecuta con
[DuckDB](https://duckdb.org/) directamente sobre los archivos NDJSON
(también comprimidos, y con comodines como `"exportacion/*.ndjson"`) o
Parquet, sin cargarlos en R. Requiere los paquetes duckdb (1.3.0 o
posterior) y DBI.

### Mismo resultado, otro motor

Con los casos ficticios de dengue incluidos en el paquete:

``` r

archivo <- system.file("extdata", "dengue_2025.ndjson.gz", package = "fhirviews")

confirmados <- vista_leer(r"-({
  "resource": "Condition",
  "where": [{"path": "verificationStatus.coding.where(code = 'confirmed').exists()"}],
  "select": [{"column": [
    {"name": "paciente", "path": "subject.getReferenceKey(Patient)"},
    {"name": "inicio", "path": "onset.ofType(dateTime)", "type": "dateTime"},
    {"name": "grave", "type": "boolean",
     "path": "code.coding.where(system = 'http://hl7.org/fhir/sid/icd-10').code = 'A91'"}
  ]}]
})-")

con_duckdb <- vista_ejecutar_duckdb(archivo, confirmados)
con_v8 <- vista_ejecutar(fhir_recursos(archivo), confirmados)
head(con_duckdb)
nrow(con_duckdb)

ordenar <- function(d) d[order(d$paciente), ]
all.equal(ordenar(con_duckdb), ordenar(con_v8), check.attributes = FALSE)
```

[`vista_sql()`](https://f-slg.github.io/fhirviews/reference/vista_sql.md)
muestra la consulta que se ejecuta, útil para entender el motor o para
correrla en otra herramienta que hable SQL de DuckDB:

``` r

sql <- vista_sql(vista_crear("Patient", c(sexo = "gender")),
                 desde = "pacientes.ndjson")
cat(substr(sql, 1, 400), "...\n")
```

### Rendimiento

Tiempo de punta a punta, desde el archivo NDJSON hasta el `data.frame`,
con pacientes sintéticos y una vista con `where`, cuatro columnas y
`forEach` sobre `name`
([`data-raw/motor-duckdb.R`](https://github.com/f-slg/fhirviews/blob/main/data-raw/motor-duckdb.R)
del repositorio; Linux, 8 núcleos, R 4.5.2, duckdb 1.5.6):

| Pacientes | Motor V8 (s) | Motor DuckDB (s) | Veces más rápido |
|----------:|-------------:|-----------------:|-----------------:|
|    10 000 |          2,3 |             0,22 |               11 |
|    50 000 |         11,0 |             0,92 |               12 |
|   100 000 |         23,2 |             1,18 |               20 |
|   250 000 |         58,9 |             1,56 |               38 |
| 1 000 000 |    no medido |              5,8 |                  |

El motor V8 no se midió con un millón de pacientes: necesita más memoria
de la que tiene un portátil típico. El motor DuckDB usó como máximo unos
1,3 GB.

### Comparación con fhircrackr

[fhircrackr](https://CRAN.R-project.org/package=fhircrackr) es el
paquete de CRAN más usado para aplanar recursos FHIR en R: describe las
columnas con XPath sobre Bundles XML y expande las colecciones con
`fhir_melt()`. Con los mismos pacientes sintéticos y la misma tabla de
salida (filtro por fecha, cuatro columnas por paciente y una fila por
nombre), estos son los tiempos de punta a punta, desde los archivos
hasta el `data.frame`, con fhircrackr en uno y en ocho núcleos
(`ncores`). Son la mediana de tres corridas, después de comprobar que
los resultados fueran idénticos:

| Pacientes | Filas | fhircrackr, 1 núcleo (s) | fhircrackr, 8 núcleos (s) | fhirviews V8 (s) | fhirviews DuckDB (s) |
|---:|---:|---:|---:|---:|---:|
| 1 000 | 1 752 | 0,56 | 0,35 | 0,16 | 0,10 |
| 10 000 | 17 824 | 4,4 | 1,6 | 1,3 | 0,18 |
| 50 000 | 89 180 | 25,1 | 6,9 | 7,2 | 0,60 |
| 100 000 | 178 316 | 48,5 | 15,8 | 15,4 | 1,11 |

Cada paquete leyó su formato natural: NDJSON en fhirviews y Bundles XML
de 500 recursos en fhircrackr. Al interpretar los números conviene tener
en cuenta:

- El motor V8 usa un solo núcleo. Frente a fhircrackr con un núcleo es
  unas **3 veces más rápido** (de 4 a 5 veces solo en la transformación,
  con los datos ya en memoria); con `ncores = 8`, fhircrackr alcanza
  tiempos similares a los de V8. DuckDB usa todos los núcleos, así que
  su ventaja combina el motor con el paralelismo.
- Es un solo tipo de recurso (`Patient`) sintético y sencillo, medido en
  un solo equipo (Linux, 12 núcleos, R 4.5.2, duckdb 2.0.0). Con
  recursos más anidados el resultado puede cambiar.
- En fhirviews la extracción es un `ViewDefinition` estándar que se
  puede reutilizar en otras herramientas. En fhircrackr, el filtro por
  fecha y la numeración de los nombres se resuelven en R después de
  `fhir_crack()`, porque XPath 1.0 no compara fechas.

El script reproducible es
[`data-raw/benchmark-fhircrackr.R`](https://github.com/f-slg/fhirviews/blob/main/data-raw/benchmark-fhircrackr.R)
del repositorio.

Con un recurso más anidado, 100 000 `Observation` con dos codificaciones
por recurso, elementos de elección, referencias y una fila por
componente (`forEachOrNull`), el patrón se repite:

| Observaciones | Filas | fhircrackr, 1 núcleo (s) | fhircrackr, 8 núcleos (s) | fhirviews V8 (s) | fhirviews DuckDB (s) |
|---:|---:|---:|---:|---:|---:|
| 1 000 | 1 274 | 0,44 | 0,32 | 0,18 | 0,07 |
| 10 000 | 12 639 | 4,1 | 1,6 | 1,6 | 0,18 |
| 50 000 | 63 059 | 20,8 | 7,2 | 8,4 | 0,72 |
| 100 000 | 125 578 | 44,0 | sin memoria | 17,6 | 1,42 |

Con un núcleo, V8 es unas 2,5 veces más rápido. Con ocho, fhircrackr
iguala a V8 o lo supera ligeramente, pero cada proceso paralelo copia
los datos: con 100 000 observaciones los ocho procesos superaron los 14
GB de memoria del equipo. El script es
[`data-raw/benchmark-fhircrackr-observation.R`](https://github.com/f-slg/fhirviews/blob/main/data-raw/benchmark-fhircrackr-observation.R).

### Conformidad y límites

El motor DuckDB pasa también **las 133 pruebas *shareable*** del banco
oficial:

``` r

vista_conformidad(c("basic.json", "foreach.json", "union.json", "repeat.json"),
                  motor = "duckdb")
```

Es un motor **experimental**:

- Traduce un subconjunto amplio de FHIRPath: navegación, elementos de
  elección (`value`, `effective`, `onset`…), filtros y subconjuntos
  (`where()`, `select()`, `first()`, `last()`, `skip()`, `take()`,
  `distinct()`…), conjuntos (`|`,
  [`union()`](https://rdrr.io/r/base/sets.html), `combine()`,
  [`intersect()`](https://rdrr.io/r/base/sets.html), `exclude()`, `in`),
  conversiones ([`toString()`](https://rdrr.io/r/base/toString.html),
  `toInteger()`, `toDecimal()`, `toBoolean()`), funciones de texto,
  aritmética, redondeo, fechas con su precisión y
  `lowBoundary()`/`highBoundary()` de fechas y horas. El inventario
  completo está en
  [`data-raw/motor-duckdb.md`](https://github.com/f-slg/fhirviews/blob/main/data-raw/motor-duckdb.md)
  del repositorio.
- Lo que no sabe traducir no lo adivina: da un error de clase
  `fhirviews_error_sql` que sugiere usar
  [`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md).
  Lo que solo se sabe al ver los datos (por ejemplo, comparar una fecha
  sin hora con una fecha y hora, que en fhirpath.js depende de la zona
  horaria del equipo) da un error al ejecutar la consulta.
- `repeat` recorre hasta 12 niveles de anidamiento (opción
  `fhirviews.sql_profundidad`).

En la práctica: **desarrolla y valida la vista con
[`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md)**
sobre una muestra y **ejecútala a escala con
[`vista_ejecutar_duckdb()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar_duckdb.md)**.
Las pruebas del paquete comparan ambos motores con las vistas de todas
las viñetas y exigen tablas idénticas.

Con `diferido = TRUE`, el resultado es una tabla de dplyr sobre DuckDB
(requiere dplyr y dbplyr): los filtros y resúmenes se calculan en DuckDB
y solo el resultado llega a R.

``` r

casos <- vista_ejecutar_duckdb("exportacion/Condition.ndjson", confirmados,
                               diferido = TRUE)
casos |>
  dplyr::count(grave) |>
  dplyr::collect()
```

Con una base DuckDB propia, el resultado se puede guardar como tabla en
lugar de traerlo a R:

``` r

db <- DBI::dbConnect(duckdb::duckdb(), "vigilancia.duckdb")
vista_ejecutar_duckdb("exportacion/Condition.ndjson", confirmados,
                      con_db = db, tabla = "dengue")
DBI::dbGetQuery(db, "SELECT count(*) FROM dengue")
```

## 4. Terminologías: indicadores definidos con ValueSets

Los indicadores de salud pública casi nunca se definen con un código,
sino con un conjunto: “todos los diagnósticos de diabetes”, “las vacunas
del esquema regular”, “los resultados de laboratorio de glucosa”. En
FHIR ese conjunto es un `ValueSet`, y quien sabe qué códigos contiene es
un **servidor de terminología**: [tx.fhir.org](https://tx.fhir.org/r4)
(el de HL7, abierto), un
[Snowstorm](https://github.com/IHTSDO/snowstorm) con SNOMED CT o un HAPI
con las terminologías nacionales cargadas.

Las funciones `tx_*` usan la misma conexión que el resto del paquete
(con `token` o `autenticacion` si el servidor lo exige):

| Función | Operación | Para qué |
|----|----|----|
| [`tx_expandir()`](https://f-slg.github.io/fhirviews/reference/tx_expandir.md) | `ValueSet/$expand` | La lista de códigos de un `ValueSet`, por páginas |
| [`tx_buscar_codigo()`](https://f-slg.github.io/fhirviews/reference/tx_buscar_codigo.md) | `CodeSystem/$lookup` | Nombre, sinónimos y propiedades (padres, hijos…) de un código |
| [`tx_validar_codigo()`](https://f-slg.github.io/fhirviews/reference/tx_validar_codigo.md) | `ValueSet/$validate-code` | Si cada código de un vector pertenece al `ValueSet` |
| [`vista_con_valueset()`](https://f-slg.github.io/fhirviews/reference/vista_con_valueset.md) | (sin red) | Agregar los códigos expandidos a un `ViewDefinition` |

### Expandir un ValueSet

[`tx_expandir()`](https://f-slg.github.io/fhirviews/reference/tx_expandir.md)
acepta la URL canónica de un `ValueSet` publicado o un `ValueSet`
propio. Este, por ejemplo, define la diabetes como el concepto 73211009
de SNOMED CT y todos sus descendientes:

``` r

tx <- fhir_conectar("https://tx.fhir.org/r4", panel = FALSE)

diabetes_vs <- list(
  resourceType = "ValueSet",
  compose = list(include = list(list(
    system = "http://snomed.info/sct",
    filter = list(list(property = "concept", op = "is-a", value = "73211009"))
  )))
)
diabetes <- tx_expandir(tx, diabetes_vs)
nrow(diabetes)
#> [1] 124
head(diabetes[, c("code", "display")], 3)
#>       code                                                       display
#> 1 73211009                                             Diabetes mellitus
#> 2  2751001                            Fibrocalculous pancreatic diabetes
#> 3  4783006 Maternal diabetes mellitus with hypoglycemia affecting fetus OR newborn
```

Las expansiones grandes se piden por páginas (`tamano_pagina`, 1000
códigos por defecto, con los parámetros `offset` y `count`); `max`
limita el total y `filtro` busca por nombre. Otros parámetros de
`$expand`, como el idioma, van en
`parametros = list(displayLanguage = "es")`.

### Revisar códigos

``` r

tx_validar_codigo(tx, diabetes_vs, "http://snomed.info/sct",
                  c("44054006", "38341003"))[, c("codigo", "valido")]
#>     codigo valido
#> 1 44054006   TRUE
#> 2 38341003  FALSE

dm2 <- tx_buscar_codigo(tx, "http://snomed.info/sct", "44054006")
dm2$display
#> [1] "Type 2 diabetes mellitus"
subset(dm2$propiedades, propiedad == "parent")
#>   propiedad    valor       descripcion
#> 3    parent 73211009 Diabetes mellitus
```

### Usar la expansión en una vista

La expansión se hace una vez y se guarda dentro de la vista con
[`vista_con_valueset()`](https://f-slg.github.io/fhirviews/reference/vista_con_valueset.md):
el sistema y la lista de códigos quedan como constantes del
`ViewDefinition` y se agrega un `where`. La vista resultante no necesita
red, funciona igual con
[`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md)
y con
[`vista_ejecutar_duckdb()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar_duckdb.md),
y su JSON documenta los códigos exactos que se usaron en el indicador.
Aquí, con una expansión escrita a mano en la CIE-10:

``` r

cie10_diabetes <- data.frame(
  system = "http://hl7.org/fhir/sid/icd-10",
  code = c("E10", "E11", "E12", "E13", "E14")
)
v_diabetes <- vista_crear("Condition", c(
  paciente = "subject.getReferenceKey(Patient)",
  codigo = "code.coding.first().code",
  inicio = "onset.ofType(dateTime)"
))
v_diabetes <- vista_con_valueset(v_diabetes, cie10_diabetes, nombre = "dm")
v_diabetes$where[[1]]$path
#> [1] "code.coding.where(system = %dm_sistema and %dm_codigos.contains('|' & code & '|')).exists()"

diagnosticos <- fhir_recursos(lapply(
  list(c("1", "E11", "2025-03-02"), c("2", "I10", "2025-04-11"),
       c("3", "E10", "2025-06-20")),
  function(x) list(
    resourceType = "Condition", id = x[1],
    subject = list(reference = paste0("Patient/p", x[1])),
    code = list(coding = list(list(system = "http://hl7.org/fhir/sid/icd-10",
                                   code = x[2]))),
    onsetDateTime = x[3]
  )
))
vista_ejecutar(diagnosticos, v_diabetes)
#>   id paciente codigo     inicio
#> 1  1       p1    E11 2025-03-02
#> 2  3       p3    E10 2025-06-20
```

Con `columna = "diabetes"`, en vez de filtrar, se agrega una columna
lógica: útil para marcar varios grupos (diabetes, hipertensión…) en una
misma vista. La lista va como texto separado por `|` y no como una
cadena de `or`, así la expresión sigue siendo corta con miles de códigos
y el motor DuckDB la resuelve con una sola búsqueda de texto por
recurso.

## 5. Flujo completo

De un servidor protegido a tasas por cantón, sin pasar los recursos por
la memoria de R:

``` r

library(fhirviews)

# 1. Conexión con SMART Backend Services
con <- fhir_conectar(
  "https://fhir.ministerio.ejemplo/r4",
  autenticacion = fhir_auth_backend("vigilancia", "~/.claves/privada.pem",
                                    alcances = "system/*.rs", kid = "k1")
)

# 2. Exportación de los casos del año
exp <- fhir_exportar(con, "sistema", tipos = c("Patient", "Condition"),
                     filtros = "Condition?code=http://hl7.org/fhir/sid/icd-10|A90,A91",
                     desde = as.Date("2025-01-01"), carpeta = "dengue-2025")

# 3. Vistas a escala con DuckDB
casos <- vista_ejecutar_duckdb(exp$archivos$Condition, confirmados)
pacientes <- vista_ejecutar_duckdb(exp$archivos$Patient, v_paciente)

# 4. Tasas con la población oficial (pobecu)
por_canton <- aggregate(paciente ~ dpa_canton,
                        merge(casos, pacientes, by.x = "paciente", by.y = "id"),
                        length)
names(por_canton)[2] <- "casos"
por_canton$anio <- 2025
pobecu::pob_tasa(por_canton, "casos")
```

La vista `v_paciente` (con el código DPA del cantón) y el cálculo de
tasas se explican en el artículo [*Tasas por cantón con FHIR y
pobecu*](https://f-slg.github.io/fhirviews/articles/tasas-pobecu.html).
