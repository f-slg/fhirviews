# Verificacion del consumidor: paquete R instalado, binario extraido y sin Cargo.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 2L)
binario <- normalizePath(args[1], mustWork = TRUE)
salida <- args[2]
stopifnot(!file.exists(salida), dir.create(salida, recursive = TRUE))
library(fhirviews)
stopifnot(utils::packageVersion("fhirviews") >= "0.5.0.9002")
manifiesto <- jsonlite::read_json(file.path(dirname(dirname(binario)), "MANIFIESTO.json"), simplifyVector = TRUE)
conexion <- file(binario, "rb")
huella <- unclass(as.character(openssl::sha256(conexion)))
close(conexion)
stopifnot(identical(huella, manifiesto$ficheros[[manifiesto$ejecutable]]$sha256))
Sys.setenv(FHIRVIEWS_RUST_BIN = binario)
r <- testthat::test_package("fhirviews", filter = "componente-rust|mapeo-laboratorio", reporter = "summary")
tabla <- as.data.frame(r)
stopifnot(nrow(tabla) >= 10L, !any(tabla$failed > 0 | tabla$error | tabla$warning > 0 | tabla$skipped))
stopifnot(any(grepl("siete recursos", tabla$test, fixed = TRUE)))
marcador <- Sys.getenv("FHIRVIEWS_COMPILER_MARKER")
stopifnot(nzchar(marcador), !file.exists(marcador))
tabla$result <- NULL
jsonlite::write_json(list(estado = "aprobado", version_fhirviews = as.character(utils::packageVersion("fhirviews")),
  target = manifiesto$target, commit_fuente = manifiesto$commit_fuente,
  version_componente = manifiesto$version, sha256_binario = huella,
  compilador_invocado = FALSE, comprobaciones = sum(tabla$passed), grupos = tabla,
  sistema = unname(Sys.info()["sysname"]), arquitectura = unname(Sys.info()["machine"])),
  file.path(salida, "consumidor.json"), auto_unbox = TRUE, pretty = TRUE)
cat("Consumidor instalado aprobado:", sum(tabla$passed), "comprobaciones, sin invocar Rust.\n")
