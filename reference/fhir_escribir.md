# Escribir recursos FHIR como JSON o NDJSON

Conserva los literales decimales de la fuente JSON cuando estan
disponibles. No valida perfiles ni envia recursos a un servidor. Un
archivo JSON contiene un arreglo de recursos; NDJSON, uno por linea.
Reemplaza el contenido del archivo indicado.

## Usage

``` r
fhir_escribir(recursos, archivo, formato = c("ndjson", "json"))
```

## Arguments

- recursos:

  Recursos aceptados por
  [`fhir_recursos()`](https://f-slg.github.io/fhirviews/reference/fhir_recursos.md).

- archivo:

  Ruta de salida.

- formato:

  `"ndjson"` (por defecto) o `"json"`.

## Value

La ruta de salida, de forma invisible.

## Examples

``` r
archivo <- tempfile(fileext = ".ndjson")
fhir_escribir(list(resourceType = "Patient", id = "p1"), archivo)
fhir_recursos(archivo)
#> <fhir_recursos> 1 recurso
#>   Patient: 1
unlink(archivo)
```
