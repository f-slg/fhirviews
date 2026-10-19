# Addins de RStudio

Funciones que llaman los addins de RStudio (menú *Addins*). No hace
falta usarlas directamente.

## Usage

``` r
addin_peticion()

addin_vista()
```

## Value

`NULL`, de forma invisible.

## Details

- *Ejecutar petición FHIR*: toma el texto seleccionado (o la línea del
  cursor) y lo ejecuta con
  [`fhir_ejecutar_texto()`](https://f-slg.github.io/fhirviews/reference/fhir_ejecutar_texto.md)
  en la consola.

- *Ejecutar ViewDefinition*: toma el JSON seleccionado (o el archivo
  abierto), lo ejecuta contra el servidor activo con
  [`fhir_vista()`](https://f-slg.github.io/fhirviews/reference/fhir_vista.md)
  y abre el resultado. Descarga como mucho
  `getOption("fhirviews.addin_paginas", 5)` páginas.
