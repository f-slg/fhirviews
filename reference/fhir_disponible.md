# Comprobar si un servidor FHIR responde

Hace una petición rápida a `[base]/metadata`. Útil para omitir ejemplos
o pruebas cuando no hay conexión.

## Usage

``` r
fhir_disponible(url, tiempo = 5)
```

## Arguments

- url:

  Dirección base del servidor.

- tiempo:

  Segundos de espera máxima.

## Value

`TRUE` si el servidor responde con éxito; `FALSE` si no.

## Examples

``` r
fhir_disponible("https://hapi.fhir.org/baseR4")
#> [1] TRUE
```
