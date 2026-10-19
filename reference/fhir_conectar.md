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
  panel = TRUE,
  autenticacion = NULL
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
  usa por ejemplo `Sys.getenv("FHIR_TOKEN")`. Para tokens que caducan,
  usa mejor `autenticacion`.

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

- autenticacion:

  Autenticación SMART on FHIR / OAuth2 creada con
  [`fhir_auth_cliente()`](https://f-slg.github.io/fhirviews/reference/fhir_auth.md),
  [`fhir_auth_backend()`](https://f-slg.github.io/fhirviews/reference/fhir_auth.md)
  o
  [`fhir_auth_interactiva()`](https://f-slg.github.io/fhirviews/reference/fhir_auth.md).
  Las URL del servidor de autorización se descubren con
  [`fhir_smart_configuracion()`](https://f-slg.github.io/fhirviews/reference/fhir_smart_configuracion.md)
  si no se indican. El token se pide en la primera petición, se renueva
  solo al expirar y, como con `token`, solo se envía al propio servidor.
  No se puede usar junto con `token`.

## Value

Un objeto de clase `fhir_conexion`, que además queda como conexión
activa para los addins y
[`fhir_ejecutar_texto()`](https://f-slg.github.io/fhirviews/reference/fhir_ejecutar_texto.md).

## See also

[`fhir_buscar()`](https://f-slg.github.io/fhirviews/reference/fhir_buscar.md),
[`fhir_leer()`](https://f-slg.github.io/fhirviews/reference/fhir_leer.md),
[`fhir_crear()`](https://f-slg.github.io/fhirviews/reference/fhir_crear.md),
[`fhir_peticion()`](https://f-slg.github.io/fhirviews/reference/fhir_peticion.md),
[fhir_auth](https://f-slg.github.io/fhirviews/reference/fhir_auth.md).

## Examples

``` r
if (FALSE) { # fhir_disponible("https://hapi.fhir.org/baseR4")
con <- fhir_conectar("https://hapi.fhir.org/baseR4")
con
}
if (FALSE) { # interactive()
# Servidor protegido con SMART Backend Services
con <- fhir_conectar(
  "https://fhir.ejemplo.org/r4",
  autenticacion = fhir_auth_backend("mi-cliente", "privada.pem",
                                    kid = "clave-2026")
)
}
```
