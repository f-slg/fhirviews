# Descubrir la configuración SMART de un servidor

Lee `[base]/.well-known/smart-configuration` y, si el servidor no lo
publica, busca las extensiones `oauth-uris` en la seguridad del
`CapabilityStatement` (`[base]/metadata`), como en SMART v1. Así se
obtienen las URL del servidor de autorización que usa
[`fhir_conectar()`](https://f-slg.github.io/fhirviews/reference/fhir_conectar.md)
con
[`fhir_auth_cliente()`](https://f-slg.github.io/fhirviews/reference/fhir_auth.md),
[`fhir_auth_backend()`](https://f-slg.github.io/fhirviews/reference/fhir_auth.md)
o
[`fhir_auth_interactiva()`](https://f-slg.github.io/fhirviews/reference/fhir_auth.md).

## Usage

``` r
fhir_smart_configuracion(url, tiempo = 30)
```

## Arguments

- url:

  Dirección base del servidor FHIR.

- tiempo:

  Segundos de espera máxima por petición.

## Value

Una lista con `token_endpoint`, `authorization_endpoint` (o `NULL`),
`fuente` (`"smart-configuration"` o `"CapabilityStatement"`) y
`configuracion` (el documento completo leído).

## See also

[fhir_auth](https://f-slg.github.io/fhirviews/reference/fhir_auth.md).

## Examples

``` r
if (FALSE) { # interactive()
cfg <- fhir_smart_configuracion("https://launch.smarthealthit.org/v/r4/fhir")
cfg$token_endpoint
}
```
