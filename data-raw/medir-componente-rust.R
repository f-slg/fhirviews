# Medicion reproducible sobre un paquete instalado con bytecode, sin pkgload.
# Rscript --vanilla data-raw/medir-componente-rust.R BINARIO SALIDA-NUEVA PAQUETE.tar.gz
# FHIRVIEWS_RUST_LIB puede seleccionar una biblioteca R nueva y aislada.
main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  stopifnot(length(args) == 3L)
  binario <- normalizePath(args[1], mustWork = TRUE)
  salida <- args[2]
  paquete <- normalizePath(args[3], mustWork = TRUE)
  commit_fuente <- system2("git", c("rev-parse", "HEAD"), stdout = TRUE)
  if (file.exists(salida) || !dir.create(salida, recursive = TRUE)) stop("La salida debe ser nueva")
  lib <- Sys.getenv("FHIRVIEWS_RUST_LIB")
  if (nzchar(lib)) .libPaths(c(normalizePath(lib, mustWork = TRUE), .libPaths()))
  library(fhirviews)
  stopifnot(utils::packageVersion("fhirviews") == "0.5.0.9002", requireNamespace("openssl", quietly = TRUE))
  source("tests/testthat/helper-constructor-r4.R", local = TRUE)
  source("data-raw/experimento-rust/ayudas.R", local = TRUE)
  sha256 <- function(archivo) {
    con <- file(archivo, "rb"); on.exit(close(con))
    unname(unclass(as.character(openssl::sha256(con))))
  }
  archivo_plan <- tempfile(fileext = ".json")
  on.exit(unlink(archivo_plan), add = TRUE)
  inicio <- proc.time()[["elapsed"]]
  preparado <- crear_experimento(archivo_plan, binario)$preparado
  preparacion_r <- proc.time()[["elapsed"]] - inicio
  componente <- fhir_componente_rust(binario, fallback = FALSE)
  prueba <- casos_constructor_r4(3L)
  esperado <- fhir_desde_tabla(prueba$datos$Patient, prueba$mapas$Patient)
  frio <- system.time(actual <- fhir_desde_tabla(prueba$datos$Patient,
    prueba$mapas$Patient, componente = componente))[["elapsed"]]
  stopifnot(identical(actual, esperado))
  metodos <- list(r = fhir_desde_tabla, r_preparado = preparado,
    rust_componente = function(datos, mapa) fhir_desde_tabla(datos, mapa, componente))
  casos_fijos <- stats::setNames(lapply(c(300L, 3000L), casos_constructor_r4), c("300", "3000"))
  referencias <- lapply(casos_fijos, function(casos) stats::setNames(
    lapply(names(casos$datos), function(t) fhir_desde_tabla(casos$datos[[t]], casos$mapas[[t]])),
    names(casos$datos)))
  set.seed(20261115L)
  plan <- expand.grid(tipo = names(prueba$datos), n = c(300L, 3000L),
    metodo = names(metodos), repeticion = 1:3, stringsAsFactors = FALSE)
  plan <- plan[sample.int(nrow(plan)), ]
  tiempos <- vector("list", nrow(plan))
  for (i in seq_len(nrow(plan))) {
    paso <- plan[i, ]
    casos <- casos_fijos[[as.character(paso$n)]]
    datos <- casos$datos[[paso$tipo]]; mapa <- casos$mapas[[paso$tipo]]
    referencia <- referencias[[as.character(paso$n)]][[paso$tipo]]
    segundos <- system.time(actual <- metodos[[paso$metodo]](datos, mapa))[["elapsed"]]
    stopifnot(identical(referencia, actual))
    tiempos[[i]] <- cbind(paso, segundos = segundos, json_exacto = TRUE)
    cat(i, "/", nrow(plan), paso$tipo, paso$n, paso$metodo, segundos, "s\n")
    flush.console()
  }
  tiempos <- do.call(rbind, tiempos)
  utils::write.csv(tiempos, file.path(salida, "tiempos.csv"), row.names = FALSE)
  resumen <- aggregate(segundos ~ tipo + n + metodo, tiempos, median)
  resumen <- reshape(resumen, idvar = c("tipo", "n"), timevar = "metodo", direction = "wide")
  names(resumen) <- sub("^segundos[.]", "", names(resumen))
  resumen <- resumen[order(resumen$n, resumen$tipo), ]
  resumen$razon_r <- resumen$r / resumen$rust_componente
  resumen$razon_preparado <- resumen$r_preparado / resumen$rust_componente
  utils::write.csv(resumen, file.path(salida, "resumen.csv"), row.names = FALSE)
  version_rust <- system2(binario, "--capabilities", stdout = TRUE)
  manifiesto <- list(version = "0.5.0.9002", commit_fuente = commit_fuente,
    paquete = basename(paquete), sha256_paquete = sha256(paquete), sha256_binario = sha256(binario),
    muestras = nrow(tiempos), recursos = names(prueba$datos), filas = c(300L, 3000L),
    repeticiones = 3L, semilla = 20261115L, orden = "aleatorio", todos_json_exactos = TRUE,
    preparacion_plan_r_segundos = preparacion_r, primera_llamada_componente_3_patient_segundos = frio,
    contrato = jsonlite::fromJSON(paste(version_rust, collapse = "\n")),
    entorno = list(R = R.version.string, sistema = as.list(Sys.info()[c("sysname", "release", "version", "machine")]),
      V8 = as.character(utils::packageVersion("V8"))),
    limites = c("Tiempos locales de construccion y validacion, no de FHIRPath ni SQL on FHIR.",
      "La instalacion y compilacion se excluyen. La primera llamada se registra aparte.",
      "Cada llamada medida incluye inicio del proceso, comprobacion del binario, transporte y lectura del plan.",
      "Las filas y mapas, la referencia R para comparar y el GC previo quedan fuera del tiempo.",
      "El plan R preparado es un comparador experimental, no una API publica ni el mejor R posible.",
      "No se mide memoria ni se compara con Helios u otros paquetes."))
  jsonlite::write_json(manifiesto, file.path(salida, "MANIFIESTO.json"), auto_unbox = TRUE, pretty = TRUE)
  writeLines(capture.output(utils::sessionInfo()), file.path(salida, "sessionInfo.txt"))
  print(resumen)
}
main()
