# Ejecutar una vista sobre archivos NDJSON por bloques

Lee como máximo `tamano_lote` líneas a la vez y entrega cada tabla a
`procesar`. Los recursos y nodos V8 de cada bloque se liberan antes del
siguiente. La memoria del resultado depende de lo que retenga
`procesar`. Una línea debe contener un recurso FHIR completo. Se admiten
líneas vacías y archivos gzip. El orden de archivos y recursos se
conserva.

## Usage

``` r
vista_ejecutar_lotes(
  archivos,
  vista,
  procesar,
  tamano_lote = 10000L,
  estricto = FALSE
)
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

- estricto:

  Con `TRUE`, exige `type` primitivo FHIR R4 en todas las columnas y el
  mismo contrato (`type` y `collection`) en cada rama. Valida cada valor
  antes de convertirlo y antes de llamar a `procesar`. No admite
  conversiones implícitas entre texto, números y lógicos. Los ausentes
  se conservan como `NA` del tipo declarado y las colecciones vacías
  como vectores vacíos de ese tipo. Por defecto es `FALSE`.

## Value

Invisiblemente, una lista con los totales `bloques`, `recursos` y
`filas`. Si no hay líneas con recursos no se llama a `procesar`. Si hay
un error, se detiene; los efectos previos de `procesar` permanecen.

## Details

El modo estricto comprueba tipos de R, cardinalidad y límites numéricos:
enteros finitos representables en R, rangos de
`positiveInt`/`unsignedInt` y decimales finitos. Rechaza números no
finitos en la entrada y en los resultados antes de serializarlos. Los
demás primitivos se representan como texto; no se validan aquí formatos
de fechas, URI, códigos ni perfiles FHIR.

Los errores estrictos tienen clase `fhirviews_error_lotes` (también
`fhirviews_error_esquema` si falla el contrato). Incluyen `bloque`,
`fase`, `columna` y `tipo_esperado` cuando se conocen, `motivo`,
`indice_archivo` y `completados` (totales de llamadas a `procesar` que
retornaron sin error). El bloque 0 indica un fallo de definición antes
de leer los archivos. Los mensajes no incorporan valores, rutas de
entrada ni el error original del destino. Los mensajes o avisos que
emita el propio consumidor quedan bajo su responsabilidad. Los avisos de
lectura o evaluación detienen el bloque en modo estricto.

La función no revierte escrituras, no reintenta y no guarda checkpoints.
Si falla `procesar`, el bloque actual puede tener escrituras parciales;
`completados` no demuestra persistencia y una transacción externa puede
revertir incluso esos bloques. No lo uses para decidir automáticamente
qué bloques omitir al reanudar.

Para reintentar sin acumular duplicados, usa una transacción que abarque
toda la carga y reemplace el resultado, o escribe en un destino temporal
nuevo que solo publiques cuando termine. Conserva las mismas entradas,
orden, vista y tamaño de bloque. El ejemplo instalado
`system.file("examples", "lotes-transaccion.R", package = "fhirviews")`
demuestra rollback y reemplazo completo con DuckDB y datos ficticios.

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
