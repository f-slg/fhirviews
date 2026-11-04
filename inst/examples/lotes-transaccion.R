# Datos FICTICIOS. Requiere DBI y duckdb. No conecta con servidores.
# source(system.file("examples", "lotes-transaccion.R", package = "fhirviews"))
local({
  library(fhirviews)
  ejecutar <- function() {
    archivo <- system.file("extdata", "caso_clinico.ndjson", package = "fhirviews")
    vista <- vista_leer(list(resource = "Observation", where = list(
      list(path = "value.ofType(Quantity).exists()")), select = list(list(column = list(
        list(name = "id", path = "getResourceKey()", type = "id"),
        list(name = "valor", path = "value.ofType(Quantity).value", type = "decimal")
      )))))
    # Base temporal en memoria con un resultado previo que debe conservarse al fallar.
    db <- vista_duckdb(archivo, list(resultados = vista))
    on.exit(DBI::dbDisconnect(db), add = TRUE)
    anterior <- DBI::dbReadTable(db, "resultados")
    cargar <- function(provocar_fallo = FALSE) DBI::dbWithTransaction(db, {
      # Reemplazar el conjunto completo dentro de la misma transaccion evita
      # acumular duplicados al repetir la carga. No usar sobre una tabla ajena.
      DBI::dbExecute(db, "DELETE FROM resultados")
      vista_ejecutar_lotes(archivo, vista, function(tabla, bloque) {
        DBI::dbAppendTable(db, "resultados", tabla)
        if (provocar_fallo && nrow(tabla) > 0L) stop("Fallo simulado del destino")
      }, tamano_lote = 10, estricto = TRUE)
    })
    fallo <- tryCatch(cargar(TRUE), fhirviews_error_lotes = identity)
    stopifnot(inherits(fallo, "fhirviews_error_lotes"),
              identical(fallo$fase, "procesar"),
              identical(DBI::dbReadTable(db, "resultados"), anterior))
    # Reintentar toda la carga con la misma entrada y vista.
    cargar()
    cargar()
    actual <- DBI::dbReadTable(db, "resultados")
    ordenar <- function(x) {
      x <- x[order(x$id), , drop = FALSE]
      rownames(x) <- NULL
      x
    }
    stopifnot(identical(ordenar(actual), ordenar(anterior)))
    cat("Rollback verificado; dos cargas completas conservaron",
        nrow(actual), "filas sin acumular duplicados.\n")
  }
  ejecutar()
})
