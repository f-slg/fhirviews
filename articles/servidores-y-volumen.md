# Servidores reales y grandes volúmenes

Las viñetas anteriores trabajan con servidores de prueba abiertos y con
datos que caben cómodamente en memoria. En un hospital, un ministerio o
una red de servicios aparecen tres necesidades más, que fhirviews 0.2.0
cubre:

| Necesidad | Qué usar | Sección |
|----|----|----|
| El servidor exige iniciar sesión (OAuth2) | `autenticacion = fhir_auth_*()` en [`fhir_conectar()`](https://f-slg.github.io/fhirviews/reference/fhir_conectar.md) | [1](#autenticacion-smart-on-fhir) |
| Descargar una población completa, no solo una búsqueda | [`fhir_exportar()`](https://f-slg.github.io/fhirviews/reference/fhir_exportar.md) (FHIR Bulk Data, `$export`) | [2](#exportacion-masiva-con-export) |
| Aplanar millones de recursos en un portátil | [`vista_ejecutar_duckdb()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar_duckdb.md) (motor DuckDB) | [3](#motor-duckdb-millones-de-recursos) |

Al final, la [sección 4](#flujo-completo) une las tres piezas en un
flujo de vigilancia epidemiológica.

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
#>    paciente     inicio grave
#> 1 den-p0001 2025-02-27 FALSE
#> 2 den-p0003 2025-02-27 FALSE
#> 3 den-p0004 2025-04-05 FALSE
#> 4 den-p0005 2025-04-27 FALSE
#> 5 den-p0006 2025-03-02 FALSE
#> 6 den-p0007 2025-02-26 FALSE
nrow(con_duckdb)
#> [1] 661

ordenar <- function(d) d[order(d$paciente), ]
all.equal(ordenar(con_duckdb), ordenar(con_v8), check.attributes = FALSE)
#> [1] TRUE
```

[`vista_sql()`](https://f-slg.github.io/fhirviews/reference/vista_sql.md)
muestra la consulta que se ejecuta, útil para entender el motor o para
correrla en otra herramienta que hable SQL de DuckDB:

``` r

sql <- vista_sql(vista_crear("Patient", c(sexo = "gender")),
                 desde = "pacientes.ndjson")
cat(substr(sql, 1, 400), "...\n")
#> SELECT f."id" AS "id", f."sexo" AS "sexo"
#> FROM (
#>   SELECT unnest([{'id': json_extract_string(r, '$.id'), 'sexo': json_extract_string(list_extract(list_transform([flatten(list_transform([json_extract(r, '$."gender"')], lambda z1: CASE WHEN z1 IS NULL OR CAST(z1 AS VARCHAR) = 'null' THEN []::JSON[] WHEN starts_with(CAST(z1 AS VARCHAR), '[') THEN list_filter(CAST(z1 AS JSON[]), lambda z2: z2 IS NOT N ...
```

### Rendimiento

Tiempo de punta a punta, desde el archivo NDJSON hasta el `data.frame`,
con pacientes sintéticos y una vista con `where`, cuatro columnas y
`forEach` sobre `name` (`data-raw/motor-duckdb.R`; Linux, 8 núcleos, R
4.5.2, duckdb 1.5.6):

| Pacientes | Motor V8 (s) | Motor DuckDB (s) | Veces más rápido |
|----------:|-------------:|-----------------:|-----------------:|
|    10 000 |          2,6 |             0,16 |               16 |
|    50 000 |         11,8 |             0,72 |               16 |
|   100 000 |         24,2 |             0,94 |               26 |
|   250 000 |         62,4 |             1,67 |               37 |
| 1 000 000 |    no medido |              5,5 |                  |

El motor V8 no se midió con un millón de pacientes: necesita más memoria
de la que tiene un portátil típico. El motor DuckDB usó como máximo unos
1,3 GB.

### Conformidad y límites

El motor DuckDB pasa también **las 133 pruebas *shareable*** del banco
oficial:

``` r

vista_conformidad(c("basic.json", "foreach.json", "union.json", "repeat.json"),
                  motor = "duckdb")
#> Banco de pruebas de SQL on FHIR (FHIR/sql-on-fhir.js@6677c20, 2026-07-09) 
#> fhirviews 0.2.0 · motor DuckDB 1.5.6
#> 
#>   shareable       53 de  53 aprobadas
#>   total           53 de  53 aprobadas
```

Es un motor **experimental**:

- Traduce un subconjunto de FHIRPath: navegación, elementos de elección
  (`value`, `effective`, `onset`…), `where()`,
  [`exists()`](https://rdrr.io/r/base/exists.html), `empty()`,
  `first()`, `join()`, `ofType()`, `extension()`, `getResourceKey()`,
  `getReferenceKey()`, comparaciones, lógica y constantes.
- Lo que no sabe traducir no lo adivina: da un error de clase
  `fhirviews_error_sql` que sugiere usar
  [`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md).
- `repeat` recorre hasta 12 niveles de anidamiento (opción
  `fhirviews.sql_profundidad`).
- No calcula `lowBoundary()` ni `highBoundary()` (pruebas experimentales
  del banco).

En la práctica: **desarrolla y valida la vista con
[`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md)**
sobre una muestra y **ejecútala a escala con
[`vista_ejecutar_duckdb()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar_duckdb.md)**.
Las pruebas del paquete comparan ambos motores con las vistas de todas
las viñetas y exigen tablas idénticas.

Con una base DuckDB propia, el resultado se puede guardar como tabla en
lugar de traerlo a R:

``` r

db <- DBI::dbConnect(duckdb::duckdb(), "vigilancia.duckdb")
vista_ejecutar_duckdb("exportacion/Condition.ndjson", confirmados,
                      con_db = db, tabla = "dengue")
DBI::dbGetQuery(db, "SELECT count(*) FROM dengue")
```

## 4. Flujo completo

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
tasas se explican en la viñeta [*Tasas por cantón con FHIR y
pobecu*](https://f-slg.github.io/fhirviews/articles/tasas-pobecu.md).
