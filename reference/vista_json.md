# Convertir un ViewDefinition en JSON

Convertir un ViewDefinition en JSON

## Usage

``` r
vista_json(vista, bonito = TRUE)
```

## Arguments

- vista:

  Un `ViewDefinition` en cualquier forma que acepte
  [`vista_leer()`](https://f-slg.github.io/fhirviews/reference/vista_leer.md).

- bonito:

  Si es `TRUE` (por defecto), con sangría.

## Value

Texto JSON de clase `json`.

## Examples

``` r
vista_json(vista_crear("Patient", c(sexo = "gender")))
#> {
#>   "resourceType": "ViewDefinition",
#>   "status": "active",
#>   "resource": "Patient",
#>   "select": [
#>     {
#>       "column": [
#>         {
#>           "name": "id",
#>           "path": "getResourceKey()"
#>         },
#>         {
#>           "name": "sexo",
#>           "path": "gender"
#>         }
#>       ]
#>     }
#>   ]
#> } 
```
