#' Ejecutar una vista sobre archivos NDJSON por bloques
#'
#' Lee como máximo `tamano_lote` líneas a la vez y entrega cada tabla a
#' `procesar`. Los recursos y nodos V8 de cada bloque se liberan antes del
#' siguiente. La memoria del resultado depende de lo que retenga `procesar`.
#' Una línea debe contener un recurso FHIR completo. Se admiten líneas vacías
#' y archivos gzip. El orden de archivos y recursos se conserva.
#'
#' @param archivos Rutas de archivos NDJSON, incluidos `.ndjson.gz`.
#' @param vista Un ViewDefinition aceptado por [vista_leer()].
#' @param procesar Función que recibe una tabla y su número de bloque
#'   (`function(tabla, bloque)`). Su resultado se descarta. Puede escribir en
#'   una base de datos o acumular resúmenes. Se llama también para bloques sin
#'   filas resultantes. Los tipos sin `type` explícito se infieren por bloque;
#'   declara tipos en la vista si necesitas un esquema fijo para la salida.
#' @param tamano_lote Número máximo de líneas leídas por bloque.
#' @return Invisiblemente, una lista con los totales `bloques`, `recursos`
#'   y `filas`. Si no hay líneas con recursos no se llama a `procesar`.
#'   Si hay un error, se detiene; los efectos previos de `procesar` permanecen.
#' @encoding UTF-8
#' @export
#' @examples
#' archivo <- system.file("extdata", "caso_clinico.ndjson", package = "fhirviews")
#' vista <- vista_crear("Patient", c(sexo = "gender"))
#' vista_ejecutar_lotes(archivo, vista,
#'   function(tabla, bloque) cat(bloque, nrow(tabla), "filas\n"), tamano_lote = 20)
vista_ejecutar_lotes <- function(archivos, vista, procesar, tamano_lote = 10000L) {
  if (!is.character(archivos) || !length(archivos) || anyNA(archivos) ||
      any(!file.exists(archivos)) || any(dir.exists(archivos))) {
    cli::cli_abort("{.arg archivos} debe contener rutas a archivos existentes.",
                   class = "fhirviews_error")
  }
  if (!is.function(procesar)) {
    cli::cli_abort("{.arg procesar} debe ser una función.", class = "fhirviews_error")
  }
  if (!is.numeric(tamano_lote) || length(tamano_lote) != 1L ||
      is.na(tamano_lote) || !is.finite(tamano_lote) || tamano_lote < 1 ||
      tamano_lote != floor(tamano_lote) || tamano_lote > .Machine$integer.max) {
    cli::cli_abort("{.arg tamano_lote} debe ser un entero positivo.",
                   class = "fhirviews_error")
  }
  vista <- vista_leer(vista)
  totales <- list(bloques = 0, recursos = 0, filas = 0)
  leer_archivo <- function(archivo) {
    con <- if (grepl("\\.gz$", archivo, ignore.case = TRUE)) {
      gzfile(archivo, open = "rt", encoding = "UTF-8")
    } else file(archivo, open = "rt", encoding = "UTF-8")
    on.exit(close(con))
    repeat {
      lineas <- readLines(con, n = tamano_lote, warn = FALSE)
      if (!length(lineas)) break
      lineas <- lineas[nzchar(trimws(lineas))]
      if (!length(lineas)) next
      recursos <- recursos_ndjson(lineas)
      tabla <- vista_ejecutar(recursos, vista, validar = FALSE)
      totales$bloques <<- totales$bloques + 1
      totales$recursos <<- totales$recursos + length(recursos)
      totales$filas <<- totales$filas + nrow(tabla)
      procesar(tabla, totales$bloques)
      rm(recursos, tabla, lineas)
    }
  }
  for (archivo in archivos) leer_archivo(archivo)
  invisible(totales)
}
