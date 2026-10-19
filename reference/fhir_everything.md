# Todos los datos de un paciente u otro compartimento (\$everything)

Ejecuta la operación `$everything`
(`GET [base]/Patient/[id]/$everything`) y sigue la paginación del Bundle
que devuelve.

## Usage

``` r
fhir_everything(
  con,
  recurso = "Patient",
  id,
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

  Tipo de recurso del compartimento; casi siempre `"Patient"` (también
  existe para `"Encounter"` en algunos servidores).

- id:

  Id del recurso.

- parametros:

  Lista con nombre de parámetros adicionales, útil para nombres como
  `"subject:Patient"` o construidos en un programa.

- max_paginas:

  Número máximo de páginas que se descargan.

- progreso:

  Si es `TRUE`, muestra el avance (por defecto, en sesiones
  interactivas).

## Value

Una lista de recursos de clase `fhir_recursos`.

## Examples

``` r
con <- fhir_conectar("https://hapi.fhir.org/baseR4")
uno <- fhir_buscar(con, "Patient", `_count` = 1, max_paginas = 1)
todo <- fhir_everything(con, "Patient", uno[[1]]$id, max_paginas = 1)
todo
#> <fhir_recursos> 20 recursos
#>   Observation: 19
#>   Patient: 1
```
