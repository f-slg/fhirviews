# Reunir recursos FHIR en una lista

Convierte las formas habituales de recibir datos FHIR en una lista de
recursos, que es lo que usan
[`vista_fhirpath()`](https://f-slg.github.io/fhirviews/reference/vista_fhirpath.md)
y el resto de funciones de vistas.

## Usage

``` r
fhir_recursos(x)
```

## Arguments

- x:

  Recursos FHIR en cualquiera de estas formas:

  - un recurso (lista de R con `resourceType`);

  - un `Bundle`: se toman los recursos de `entry[].resource`;

  - una lista de recursos o de Bundles;

  - texto JSON con un recurso, un Bundle o un arreglo de recursos;

  - texto NDJSON (un recurso por línea) o un vector de caracteres con un
    recurso JSON por elemento;

  - la ruta a un archivo `.json` o `.ndjson`.

## Value

Una lista de recursos (listas de R) de clase `fhir_recursos`.

## Examples

``` r
paciente <- '{"resourceType": "Patient", "id": "p1",
              "name": [{"family": "Paredes Cevallos", "given": ["Ana"]}]}'
fhir_recursos(paciente)
#> <fhir_recursos> 1 recurso
#>   Patient: 1

ndjson <- c('{"resourceType": "Patient", "id": "p1"}',
            '{"resourceType": "Observation", "id": "o1", "status": "final"}')
fhir_recursos(ndjson)
#> <fhir_recursos> 2 recursos
#>   Observation: 1
#>   Patient: 1
```
