args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 4L) stop("Uso: Rscript memoria.R BINARIO METODO FILAS PLAN")
binario <- normalizePath(args[1], mustWork = TRUE)
source("data-raw/experimento-rust/cargar.R")
source("data-raw/experimento-rust/ayudas.R")
source("data-raw/experimento-rust/casos.R")
constructor <- if (args[2] == "original") fhirviews::fhir_desde_tabla else {
  e <- crear_experimento(args[4], binario)
  e[[args[2]]]
}
casos <- casos_rust(as.integer(args[3]))
gc()
cat("INICIO_CONSTRUCTOR\n"); flush.console()
r <- constructor(casos$datos$Immunization, casos$mapas$Immunization)
stopifnot(length(r) == as.integer(args[3]))
cat("FIN_CONSTRUCTOR\n"); flush.console()
