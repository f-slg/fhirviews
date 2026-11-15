# Leer un recurso

Lee un recurso por su tipo e id (`GET [base]/[tipo]/[id]`), o una
versión concreta (`_history`).

## Usage

``` r
fhir_leer(con, recurso, id = NULL, version = NULL, como_recursos = FALSE)
```

## Arguments

- con:

  Conexión creada con
  [`fhir_conectar()`](https://f-slg.github.io/fhirviews/reference/fhir_conectar.md).

- recurso:

  Tipo de recurso (`"Patient"`) o referencia completa (`"Patient/123"`).

- id:

  Id del recurso; no hace falta si `recurso` es una referencia.

- version:

  Versión opcional (`vid`) para leer el historial.

- como_recursos:

  Con `TRUE`, devuelve
  [`fhir_recursos()`](https://f-slg.github.io/fhirviews/reference/fhir_recursos.md)
  con la fuente JSON original, para conservar escala decimal al ejecutar
  vistas o escribir NDJSON. Con `FALSE` (por defecto), devuelve la lista
  habitual de R, cuyos numeros no conservan ceros finales. Para un
  Bundle se aplican las reglas de extraccion de
  [`fhir_recursos()`](https://f-slg.github.io/fhirviews/reference/fhir_recursos.md).

## Value

El recurso como lista de R; con `como_recursos = TRUE`, una coleccion
`fhir_recursos` con su JSON fuente.

## Examples

``` r
con <- fhir_conectar("https://hapi.fhir.org/baseR4")
uno <- fhir_buscar(con, "Patient", `_count` = 1, max_paginas = 1)
paciente <- fhir_leer(con, "Patient", uno[[1]]$id)
paciente$resourceType
#> [1] "Patient"
```
