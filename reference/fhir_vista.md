# Ejecutar una vista contra un servidor FHIR

Busca en el servidor los recursos del tipo de la vista (con
[`fhir_buscar()`](https://f-slg.github.io/fhirviews/reference/fhir_buscar.md))
y les aplica el `ViewDefinition` con
[`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md).
Los `where` de la vista se aplican después de descargar los datos; para
descargar menos, filtra también con parámetros de búsqueda en `...`.

## Usage

``` r
fhir_vista(
  con,
  vista,
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

- vista:

  Un `ViewDefinition` en cualquier forma que acepte
  [`vista_leer()`](https://f-slg.github.io/fhirviews/reference/vista_leer.md).

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

Un `data.frame`, como
[`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md).

## Examples

``` r
con <- fhir_conectar("https://hapi.fhir.org/baseR4")
fhir_vista(con, vista_crear("Patient", c(sexo = "gender",
                                         nacimiento = "birthDate")),
           `_count` = 10, max_paginas = 1)
#>               id   sexo nacimiento
#> 1  nhanes-121623   male 1962-12-31
#> 2  nhanes-118185 female 1993-10-24
#> 3  nhanes-115168   male 1979-04-07
#> 4  nhanes-123324   male 1960-02-24
#> 5  nhanes-118762 female 1991-06-17
#> 6  nhanes-120412   male 1973-02-28
#> 7  nhanes-117807 female 1958-12-24
#> 8  nhanes-112383   male 1995-03-14
#> 9  nhanes-115106 female 2010-12-25
#> 10 nhanes-123231   male 1958-05-23
```
