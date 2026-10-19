# Evaluar una expresión FHIRPath

Evalúa una expresión [FHIRPath](https://hl7.org/fhirpath/) sobre cada
recurso. Es útil para explorar los datos y probar las expresiones antes
de usarlas en las columnas de un `ViewDefinition`.

## Usage

``` r
vista_fhirpath(recursos, expresion, variables = list(), simplificar = TRUE)
```

## Arguments

- recursos:

  Recursos FHIR en cualquier forma que acepte
  [`fhir_recursos()`](https://f-slg.github.io/fhirviews/reference/fhir_recursos.md).

- expresion:

  Texto con la expresión FHIRPath.

- variables:

  Lista con nombre de variables para la expresión, que se usan como
  `%nombre`. Los objetos `Date` y `POSIXct` se pasan como fechas de
  FHIRPath.

- simplificar:

  Si es `TRUE` (por defecto) y cada recurso da como mucho un valor
  simple, devuelve un vector (con `NA` cuando no hay valor); si algún
  recurso da varios valores simples, una lista de vectores. Si es
  `FALSE`, o si el resultado incluye elementos complejos, devuelve la
  lista de resultados tal como los entrega FHIRPath, con un elemento por
  recurso.

## Value

Un vector o una lista con un elemento por recurso.

## Details

Además de las funciones de FHIRPath, están disponibles las que define
SQL on FHIR: `getResourceKey()` y `getReferenceKey([tipo])`.

## See also

[`fhirviews_motor()`](https://f-slg.github.io/fhirviews/reference/fhirviews_motor.md)
para saber qué motor y qué versión de fhirpath.js se usan.

## Examples

``` r
pacientes <- list(
  list(resourceType = "Patient", id = "p1", gender = "female",
       birthDate = "1985-03-12",
       name = list(list(family = "Paredes Cevallos",
                        given = list("Ana", "Luc\u00eda")))),
  list(resourceType = "Patient", id = "p2", gender = "male",
       birthDate = "2001-11-30",
       name = list(list(family = "Salazar Moreno", given = list("Jorge"))))
)
vista_fhirpath(pacientes, "getResourceKey()")
#> [1] "p1" "p2"
vista_fhirpath(pacientes, "name.given.join(' ')")
#> [1] "Ana Lucía" "Jorge"    
vista_fhirpath(pacientes, "birthDate < %corte",
               variables = list(corte = as.Date("2000-01-01")))
#> [1]  TRUE FALSE
vista_fhirpath(pacientes, "name.given")
#> [[1]]
#> [1] "Ana"   "Lucía"
#> 
#> [[2]]
#> [1] "Jorge"
#> 
```
