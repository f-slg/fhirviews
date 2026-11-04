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
if (FALSE) { # (interactive() || identical(Sys.getenv("IN_PKGDOWN"), "true")) && fhir_disponible("https://hapi.fhir.org/baseR4")
con <- fhir_conectar("https://hapi.fhir.org/baseR4")
pacientes <- fhir_buscar(con, "Patient", gender = "female", `_count` = 5,
                         max_paginas = 1)
pacientes
vista_ejecutar(pacientes, vista_crear("Patient", c(nacimiento = "birthDate")))
}
```
