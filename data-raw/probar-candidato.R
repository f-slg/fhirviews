# Biblioteca nueva para fhirviews; reutiliza las dependencias ya instaladas.
# Rscript data-raw/probar-candidato.R paquete.tar.gz carpeta-nueva [basico|completo]
args <- commandArgs(trailingOnly = TRUE)
if (!length(args) %in% c(2L, 3L)) {
  stop("Uso: Rscript probar-candidato.R paquete.tar.gz carpeta-nueva [basico|completo]",
       call. = FALSE)
}
archivo <- normalizePath(args[1L], mustWork = TRUE)
if (dir.exists(archivo) || !grepl("\\.tar\\.gz$", archivo)) stop("Se requiere un archivo .tar.gz.")
salida <- args[2L]
perfil <- if (length(args) == 3L) args[3L] else "basico"
if (!perfil %in% c("basico", "completo")) stop("Perfil permitido: basico o completo.")
if (file.exists(salida)) stop("La carpeta de salida ya existe.")
if (!dir.create(salida, recursive = TRUE)) stop("No se pudo crear la salida.")
salida <- normalizePath(salida)
biblioteca <- file.path(salida, "biblioteca")
dir.create(biblioteca)
candidato_md5 <- unname(tools::md5sum(archivo))
writeLines(c(paste0("archivo=", basename(archivo)),
             paste0("md5=", candidato_md5),
             paste0("bytes=", file.info(archivo)$size), paste0("perfil=", perfil),
             "dependencias=se reutilizan las ya instaladas; no se instalan automaticamente"),
           file.path(salida, "candidato.txt"))
log_instalacion <- file.path(salida, "instalacion.log")
estado <- system2(file.path(R.home("bin"), "R"),
  c("CMD", "INSTALL", shQuote(paste0("--library=", biblioteca)), shQuote(archivo)),
  stdout = log_instalacion, stderr = log_instalacion)
writeLines(as.character(estado), file.path(salida, "codigo-instalacion.txt"))
if (estado != 0L) stop("La instalacion fallo; consultar instalacion.log en la salida.", call. = FALSE)
if (!identical(unname(tools::md5sum(archivo)), candidato_md5)) {
  stop("El candidato cambio durante la instalacion; repetir con un archivo estable.", call. = FALSE)
}
# Un proceso R nuevo evita evaluar por accidente el namespace de pkgload o una
# instalacion anterior de fhirviews. La ruta del paquete se comprueba antes de usarlo.
hijo <- file.path(salida, "aceptar-instalacion.R")
writeLines(c(
  'args <- commandArgs(trailingOnly = TRUE)',
  '.libPaths(c(normalizePath(args[1L]), .libPaths()))',
  'library(fhirviews)',
  'stopifnot(identical(normalizePath(find.package("fhirviews")),',
  '                    normalizePath(file.path(args[1L], "fhirviews"))))',
  'Sys.setenv(FHIRVIEWS_PILOTO_SALIDA = args[2L], FHIRVIEWS_PILOTO_PERFIL = args[3L], FHIRVIEWS_CANDIDATO_MD5 = args[4L], TZ = "UTC")',
  'script <- system.file("examples", "piloto.R", package = "fhirviews")',
  'if (!nzchar(script)) stop("El candidato no incluye el kit de piloto; reconstruya el archivo.", call. = FALSE)',
  'for (nombre in c("vista_ejecutar_lotes", "fhir_mapa", "fhir_desde_sql", "fhir_desde_tabla", "fhir_escribir")) stopifnot(length(utils::help(nombre, package = "fhirviews")) == 1L)',
  'vinetas <- utils::vignette(package = "fhirviews")$results',
  'if (is.null(vinetas) || !all(c("fhirviews", "vistas", "servidores-y-volumen") %in% vinetas[, "Item"])) stop("El candidato no incluye las vinetas construidas; reconstruya con R CMD build.", call. = FALSE)',
  'writeLines(c("ayuda=vista_ejecutar_lotes", paste0("vinetas=", paste(vinetas[, "Item"], collapse = ","))), file.path(dirname(args[2L]), "documentacion-local.txt"))',
  'source(script)',
  'informe <- jsonlite::read_json(file.path(args[2L], "aceptacion.json"))',
  'stopifnot(identical(informe$resultado_tecnico, "aprobado"),',
  '          identical(informe$perfil, args[3L]),',
  '          identical(informe$candidato_md5, args[4L]),',
  '          identical(informe$version_fhirviews, as.character(utils::packageVersion("fhirviews"))),',
  '          informe$esquema_informe == 2L,',
  '          identical(informe$hallazgos$r4$version_fhir, "4.0.1"),',
  '          informe$hallazgos$r4$recursos == 6L,',
  '          setequal(unlist(informe$hallazgos$r4$tipos), c("Patient", "Observation", "Encounter", "Condition", "Immunization")),',
  '          informe$hallazgos$r4$negativos_rechazados == 5L)',
  'esperados <- c("api_instalada", "vigilancia", "contrato_estricto", "recuperacion", "r4_cinco_recursos")',
  'stopifnot(identical(vapply(informe$controles, function(x) x$prueba, character(1)), esperados),',
  '          identical(informe$controles[[5L]]$estado, "aprobado"))',
  'estados <- rep("aprobado", length(esperados))',
  'if (args[3L] == "basico") estados[4L] <- "no_evaluado"',
  'stopifnot(identical(vapply(informe$controles, function(x) x$estado, character(1)), estados))',
  'if (args[3L] == "completo") stopifnot(setequal(unlist(informe$hallazgos$r4$motores), c("V8", "DuckDB")))'
), hijo)
log_aceptacion <- file.path(salida, "aceptacion.log")
estado <- system2(file.path(R.home("bin"), "Rscript"),
  c("--vanilla", shQuote(hijo), shQuote(biblioteca),
    shQuote(file.path(salida, "piloto")), shQuote(perfil),
    shQuote(candidato_md5)),
  stdout = log_aceptacion, stderr = log_aceptacion)
writeLines(as.character(estado), file.path(salida, "codigo-aceptacion.txt"))
cat("Resultados:", salida, "\n")
if (estado != 0L) stop("La aceptacion fallo; consultar aceptacion.log y, si se genero, el informe local.", call. = FALSE)
cat("Candidato aprobado para el perfil", perfil, "; validacion con usuarios pendiente.\n")
