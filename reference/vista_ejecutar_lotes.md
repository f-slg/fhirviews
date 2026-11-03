# Ejecutar una vista sobre archivos NDJSON por bloques

Lee como máximo `tamano_lote` líneas a la vez y entrega cada tabla a
`procesar`. Los recursos y nodos V8 de cada bloque se liberan antes del
siguiente. La memoria del resultado depende de lo que retenga
`procesar`. Una línea debe contener un recurso FHIR completo. Se admiten
líneas vacías y archivos gzip. El orden de archivos y recursos se
conserva.

## Usage

``` r
vista_ejecutar_lotes(archivos, vista, procesar, tamano_lote = 10000L)
```

## Arguments

- archivos:

  Rutas de archivos NDJSON, incluidos `.ndjson.gz`.

- vista:

  Un ViewDefinition aceptado por
  [`vista_leer()`](https://f-slg.github.io/fhirviews/reference/vista_leer.md).

- procesar:

  Función que recibe una tabla y su número de bloque
  (`function(tabla, bloque)`). Su resultado se descarta. Puede escribir
  en una base de datos o acumular resúmenes. Se llama también para
  bloques sin filas resultantes. Los tipos sin `type` explícito se
  infieren por bloque; declara tipos en la vista si necesitas un esquema
  fijo para la salida.

- tamano_lote:

  Número máximo de líneas leídas por bloque.

## Value

Invisiblemente, una lista con los totales `bloques`, `recursos` y
`filas`. Si no hay líneas con recursos no se llama a `procesar`. Si hay
un error, se detiene; los efectos previos de `procesar` permanecen.

## Examples

``` r
archivo <- system.file("extdata", "caso_clinico.ndjson", package = "fhirviews")
vista <- vista_crear("Patient", c(sexo = "gender"))
vista_ejecutar_lotes(archivo, vista,
  function(tabla, bloque) cat(bloque, nrow(tabla), "filas\n"), tamano_lote = 20)
#> 1 1 filas
#> 2 0 filas
#> 3 0 filas
```
