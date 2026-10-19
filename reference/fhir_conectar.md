# Conectarse a un servidor FHIR

Crea una conexión a un servidor HL7 FHIR R4 que usan las demás funciones
`fhir_*`. Las peticiones piden y envían `application/fhir+json`, se
reintentan si el servidor está saturado (códigos 429 y 503) y los
errores muestran el `OperationOutcome` del servidor.

## Usage

``` r
fhir_conectar(
  url,
  token = NULL,
  cabeceras = list(),
  tiempo = 60,
  verificar = TRUE,
  panel = TRUE
)
```

## Arguments

- url:

  Dirección base del servidor, por ejemplo
  `"https://hapi.fhir.org/baseR4"` o `"http://localhost:8080/fhir"`.

- token:

  Token de acceso (OAuth2 *bearer*) opcional. No se muestra al imprimir
  la conexión, solo se envía a URL del propio servidor y, si el servidor
  no usa https (y no es local), se avisa de que viajaría sin cifrar.
  Para no escribirlo en el código, guárdalo en una variable de entorno y
  usa por ejemplo `Sys.getenv("FHIR_TOKEN")`.

- cabeceras:

  Lista con nombre de cabeceras HTTP adicionales.

- tiempo:

  Segundos de espera máxima por petición.

- verificar:

  Si es `TRUE` (por defecto), consulta el `CapabilityStatement`
  (`GET [base]/metadata`) para comprobar que el servidor responde y
  anotar su software y versión de FHIR.

- panel:

  Si es `TRUE` (por defecto) y se usa RStudio, registra la conexión en
  el panel *Connections* (ver
  [`fhir_conexion_activa()`](https://f-slg.github.io/fhirviews/reference/fhir_conexion_activa.md)).

## Value

Un objeto de clase `fhir_conexion`, que además queda como conexión
activa para los addins y
[`fhir_ejecutar_texto()`](https://f-slg.github.io/fhirviews/reference/fhir_ejecutar_texto.md).

## See also

[`fhir_buscar()`](https://f-slg.github.io/fhirviews/reference/fhir_buscar.md),
[`fhir_leer()`](https://f-slg.github.io/fhirviews/reference/fhir_leer.md),
[`fhir_crear()`](https://f-slg.github.io/fhirviews/reference/fhir_crear.md),
[`fhir_peticion()`](https://f-slg.github.io/fhirviews/reference/fhir_peticion.md).

## Examples

``` r
con <- fhir_conectar("https://hapi.fhir.org/baseR4")
con
#> <fhir_conexion> https://hapi.fhir.org/baseR4
#>   Servidor:     HAPI FHIR Server 8.13.10-SNAPSHOT/6bd250944e/2026-09-25
#>   Versión FHIR: 4.0.1
```
