args_script <- commandArgs(trailingOnly = FALSE)
archivo_script <- sub("^--file=", "", args_script[grepl("^--file=", args_script)][1L])
source(file.path(dirname(normalizePath(archivo_script)), "ejecutar-integracion.R"))
nombres <- c(
  "ciclo completo de escritura en un servidor de pruebas",
  "transaccion, vistas con V8 y DuckDB y fhir_tabla con datos reales",
  "terminologia del servidor: $expand y $validate-code en lote",
  "exportacion masiva ($export) de punta a punta",
  "SQL a FHIR, perfiles R4, referencias y retorno a tablas",
  "Encounter y Condition desde SQL, perfiles R4 y referencias",
  "terminologia con ValueSet en linea"
)
bien <- data.frame(test = nombres, failed = 0L, error = FALSE, warning = 0L,
                   skipped = c(rep(FALSE, 6L), TRUE), passed = 1L,
                   omision = c(rep("", 6L),
                     "Reason: El servidor no valida con un ValueSet en l\u00ednea"))
stopifnot(isTRUE(comprobar_integracion(bien)))
publico <- bien[7L, ]
publico$test <- "lectura y paginacion en el servidor publico"
publico$passed <- 0L
publico$omision <- "Reason: Servidor publico excluido de la integracion aislada"
stopifnot(isTRUE(comprobar_integracion(rbind(bien, publico))))
publico$omision <- "Reason: No responde"
stopifnot(inherits(tryCatch(comprobar_integracion(rbind(bien, publico)),
                           error = identity), "error"))
falla <- function(x) inherits(tryCatch(comprobar_integracion(x), error = identity), "error")
for (columna in c("failed", "error", "warning", "skipped")) {
  malo <- bien
  malo[[columna]][1L] <- 1L
  stopifnot(falla(malo))
}
stopifnot(falla(bien[-1L, ]), falla(rbind(bien, bien[1L, ])))
for (i in c(5L, 6L)) { # Ambos recorridos SQL -> FHIR deben ejecutarse.
  stopifnot(falla(bien[-i, ]))
  malo <- bien; malo$skipped[i] <- TRUE; stopifnot(falla(malo))
  malo <- bien; malo$passed[i] <- 0L; stopifnot(falla(malo))
}
malo <- bien; malo$omision[7L] <- "Otra causa"; stopifnot(falla(malo))
malo <- bien; malo$passed[1L] <- 0L; stopifnot(falla(malo))
cat("Politica verificada: fallos, omisiones, grupos ausentes y duplicados rechazados.\n")
