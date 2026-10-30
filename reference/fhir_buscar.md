# Buscar recursos con paginación automática

Hace una búsqueda FHIR (`GET [base]/[tipo]?parametros`) y sigue los
enlaces [`next`](https://rdrr.io/r/base/Control.html) de cada Bundle
hasta reunir todos los resultados.

## Usage

``` r
fhir_buscar(
  con,
  recurso,
  ...,
  parametros = list(),
  max_paginas = Inf,
  progreso = interactive()
)
```

## Arguments

- con:

  Conexión creada con
  [`fhir_conectar()`](https://f-slg.github.io/fhirviews/reference/fhir_conectar.md).

- recurso:

  Tipo de recurso, por ejemplo `"Patient"` u `"Observation"`.

- ...:

  Parámetros de búsqueda con nombre, por ejemplo `family = "Paredes"`,
  `birthdate = "ge1980-01-01"` o `` `_count` = 100 ``. Un vector repite
  el parámetro (Y lógico); para un O lógico usa comas dentro del texto
  (`code = "8480-6,8462-4"`).

- parametros:

  Lista con nombre de parámetros adicionales, útil para nombres como
  `"subject:Patient"` o construidos en un programa.

- max_paginas:

  Número máximo de páginas que se descargan.

- progreso:

  Si es `TRUE`, muestra el avance (por defecto, en sesiones
  interactivas).

## Value

Una lista de recursos de clase `fhir_recursos` (ver
[`fhir_recursos()`](https://f-slg.github.io/fhirviews/reference/fhir_recursos.md))
que se puede pasar directamente a
[`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md).
El atributo `total` guarda el total que informa el servidor, si lo hace.

## Examples

``` r
con <- fhir_conectar("https://hapi.fhir.org/baseR4")
pacientes <- fhir_buscar(con, "Patient", gender = "female", `_count` = 5,
                         max_paginas = 1)
pacientes
#> <fhir_recursos> 5 recursos
#>   Patient: 5
vista_ejecutar(pacientes, vista_crear("Patient", c(nacimiento = "birthDate")))
#>                                     id nacimiento
#> 1            wellnessapp-demo-alex-223 1980-01-15
#> 2 6ac8f8ea-fe4a-4d0c-91f4-0814483430e7 1978-09-27
#> 3                        nhanes-120300 1954-08-20
#> 4                        nhanes-118520 1961-04-16
#> 5                        nhanes-118185 1993-10-24
```
