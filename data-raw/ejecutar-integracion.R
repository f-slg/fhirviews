# Politica de aceptacion: no dar verde si se omiten operaciones obligatorias.
comprobar_integracion <- function(tabla) {
  requeridas <- c(
    "ciclo completo de escritura en un servidor de pruebas",
    "transaccion, vistas con V8 y DuckDB y fhir_tabla con datos reales",
    "terminologia del servidor: $expand y $validate-code en lote",
    "exportacion masiva ($export) de punta a punta"
  )
  if (!all(requeridas %in% tabla$test) || anyDuplicated(tabla$test)) {
    stop("Faltan grupos obligatorios o hay resultados duplicados.")
  }
  if (any(tabla$failed > 0 | tabla$error | tabla$warning > 0)) {
    stop("La integracion contiene fallos, errores o advertencias.")
  }
  obligatorias <- tabla[match(requeridas, tabla$test), ]
  if (any(obligatorias$skipped | obligatorias$passed < 1L)) {
    stop("No se ejecutaron todas las operaciones obligatorias.")
  }
  permitida <- (
    tabla$test == "lectura y paginacion en el servidor publico" &
      tabla$omision == "Reason: Servidor publico excluido de la integracion aislada"
  ) | (
    tabla$test == "terminologia con ValueSet en linea" &
      tabla$omision == "Reason: El servidor no valida con un ValueSet en l\u00ednea"
  )
  if (any(tabla$skipped & !permitida)) stop("Hay omisiones no autorizadas.")
  invisible(TRUE)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  stopifnot(length(args) == 2L, nzchar(Sys.getenv("FHIRVIEWS_SERVIDOR_ESCRITURA")))
  raiz <- normalizePath(args[1L])
  salida <- normalizePath(args[2L])
  pkgload::load_all(raiz, quiet = TRUE)
  # Fallar antes de las pruebas si el servidor o el motor SQL no estan listos.
  con <- fhirviews::fhir_conectar(Sys.getenv("FHIRVIEWS_SERVIDOR_ESCRITURA"), panel = FALSE)
  stopifnot(identical(con$version_fhir, "4.0.1"))
  db <- fhirviews:::conectar_duckdb()
  tryCatch(fhirviews:::cargar_json_duckdb(db), finally = DBI::dbDisconnect(db))
  resultados <- testthat::test_local(raiz, filter = "^servidor$", reporter = "summary",
                                     stop_on_failure = FALSE)
  tabla <- as.data.frame(resultados)
  tabla$omision <- vapply(tabla$result, function(resultado) {
    mensajes <- vapply(Filter(function(x) inherits(x, "expectation_skip"), resultado),
                        conditionMessage, character(1))
    paste(mensajes, collapse = "; ")
  }, character(1))
  tabla$result <- NULL
  utils::write.csv(tabla, file.path(salida, "resumen.csv"), row.names = FALSE,
                   fileEncoding = "UTF-8")
  jsonlite::write_json(list(
    imagen = readLines(file.path(raiz, "data-raw", "hapi-image.txt")),
    version_fhirviews = as.character(utils::packageVersion("fhirviews")),
    comprobaciones_aprobadas = sum(tabla$passed),
    grupos = tabla
  ), file.path(salida, "resumen.json"), auto_unbox = TRUE, pretty = TRUE)
  writeLines(capture.output(utils::sessionInfo()), file.path(salida, "sessionInfo.txt"))
  comprobar_integracion(tabla)
  cat("Integracion aprobada; omisiones permitidas registradas en resumen.json.\n")
}
