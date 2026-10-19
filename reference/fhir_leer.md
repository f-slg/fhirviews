# Leer un recurso

Lee un recurso por su tipo e id (`GET [base]/[tipo]/[id]`), o una
versión concreta (`_history`).

## Usage

``` r
fhir_leer(con, recurso, id = NULL, version = NULL)
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

## Value

El recurso como lista de R.

## Examples

``` r
con <- fhir_conectar("https://hapi.fhir.org/baseR4")
uno <- fhir_buscar(con, "Patient", `_count` = 1, max_paginas = 1)
paciente <- fhir_leer(con, "Patient", uno[[1]]$id)
paciente$resourceType
#> [1] "Patient"
```
