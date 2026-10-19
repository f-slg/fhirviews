# Leer un ViewDefinition

Lee un `ViewDefinition` de SQL on FHIR desde texto JSON, un archivo o
una lista de R y lo valida con
[`vista_validar()`](https://f-slg.github.io/fhirviews/reference/vista_validar.md).

## Usage

``` r
vista_leer(x, validar = TRUE)
```

## Arguments

- x:

  Texto JSON, ruta a un archivo `.json` o lista de R con el
  `ViewDefinition`.

- validar:

  Si es `TRUE` (por defecto), comprueba que la vista sea válida.

## Value

Una lista de clase `fhir_vista`.

## See also

[`vista_crear()`](https://f-slg.github.io/fhirviews/reference/vista_crear.md)
para armar vistas sencillas desde R y
[`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md)
para aplicarlas.

## Examples

``` r
vista <- vista_leer('{
  "resourceType": "ViewDefinition",
  "name": "pacientes",
  "resource": "Patient",
  "select": [{"column": [
    {"name": "id", "path": "getResourceKey()"},
    {"name": "sexo", "path": "gender"}
  ]}]
}')
vista
#> <ViewDefinition> pacientes 
#>   Recurso: Patient
#>   Columnas (2): id, sexo
```
