# Ejecutar desde la carpeta del kit: Rscript INICIAR.R basico sesion-P01-intento01
# En RStudio: source("INICIAR.R"); iniciar_piloto("basico", "sesion-P01-intento01")
iniciar_piloto <- function(perfil = c("basico", "completo"), salida,
                          carpeta_kit = ".") {
  perfil <- match.arg(perfil)
  if (getRversion() < "4.1.0") stop("El piloto requiere R >= 4.1.", call. = FALSE)
  if (perfil == "completo" && getRversion() < "4.2.0") {
    stop("Este kit usa R >= 4.2 para el perfil completo con DuckDB.", call. = FALSE)
  }
  if (missing(salida) || length(salida) != 1L || is.na(salida) || !nzchar(salida)) {
    stop("Indica una carpeta de salida nueva por participante e intento.", call. = FALSE)
  }
  if (file.exists(salida)) stop("La carpeta de salida ya existe; elige otra.", call. = FALSE)
  kit <- normalizePath(carpeta_kit, mustWork = TRUE)
  dependencias <- c("cli", "httr2", "jsonlite", "rlang", "V8", "openssl")
  if (perfil == "completo") dependencias <- c(dependencias, "DBI", "duckdb")
  faltan <- dependencias[!vapply(dependencias, requireNamespace, logical(1), quietly = TRUE)]
  if (length(faltan)) {
    stop(paste("Faltan dependencias. Instalalas antes de repetir:\n",
      paste(deparse(substitute(install.packages(x), list(x = faltan))), collapse = "")), call. = FALSE)
  }
  if (perfil == "completo" && utils::packageVersion("duckdb") < "1.3.0") {
    stop("El perfil completo requiere duckdb >= 1.3.0.", call. = FALSE)
  }
  candidato <- jsonlite::read_json(file.path(kit, "CANDIDATO.json"))
  nombre <- candidato$paquete$archivo
  if (!is.character(nombre) || length(nombre) != 1L || is.na(nombre) ||
      basename(nombre) != nombre || !endsWith(nombre, ".tar.gz")) {
    stop("La identidad del candidato no es valida.", call. = FALSE)
  }
  paquete <- file.path(kit, "paquete", nombre)
  if (!file.exists(paquete)) stop("No se encontro el paquete; extrae el ZIP completo.", call. = FALSE)
  con <- file(paquete, "rb")
  sha <- tryCatch(unclass(as.character(openssl::sha256(con))), finally = close(con))
  if (!identical(tolower(sha), candidato$paquete$sha256) ||
      !identical(unname(tools::md5sum(paquete)), candidato$paquete$md5) ||
      file.info(paquete)$size != candidato$paquete$bytes) {
    stop("El archivo no coincide con el candidato comprobado. No se instalara.", call. = FALSE)
  }
  programa <- file.path(kit, "PROBAR-CANDIDATO.R")
  if (!file.exists(programa)) stop("El kit esta incompleto.", call. = FALSE)
  cat("Candidato:", candidato$version, "\nSHA-256:", sha,
      "\nPerfil:", perfil, "\nInstalacion y ensayo en un proceso R nuevo.\n")
  estado <- system2(file.path(R.home("bin"), "Rscript"),
    c("--vanilla", shQuote(programa), shQuote(normalizePath(paquete)), shQuote(salida), perfil))
  informe <- file.path(salida, "piloto", "aceptacion.json")
  datos <- if (file.exists(informe)) jsonlite::read_json(informe) else NULL
  identidad <- !is.null(datos) && identical(datos$version_fhirviews, candidato$version) &&
    identical(datos$candidato_md5, candidato$paquete$md5)
  if (dir.exists(salida)) jsonlite::write_json(list(
    esquema = "fhirviews-sesion-r4-v2", perfil = perfil,
    candidato_version = candidato$version, candidato_sha256 = sha,
    candidato_commit = candidato$fuente_commit, codigo_salida = estado,
    resultado_tecnico = if (is.null(datos)) "sin_informe" else if (!identidad)
      "identidad_incompatible" else datos$resultado_tecnico,
    evaluacion_externa = "pendiente"), file.path(salida, "SESION.json"),
    auto_unbox = TRUE, pretty = TRUE)
  if (estado != 0L) stop("El ensayo no fue aprobado; conserva y revisa sus registros.", call. = FALSE)
  if (!identidad) {
    stop("El informe no identifica el candidato esperado.", call. = FALSE)
  }
  cat("Ensayo tecnico aprobado. La evaluacion humana sigue pendiente.\n",
      "Para las tareas manuales, usa abrir_sesion() y el formulario del kit.\n")
  invisible(normalizePath(salida))
}

abrir_sesion <- function(salida) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("Instala jsonlite.", call. = FALSE)
  sesion <- jsonlite::read_json(file.path(salida, "SESION.json"))
  if (!identical(sesion$esquema, "fhirviews-sesion-r4-v2")) stop("Sesion desconocida.", call. = FALSE)
  lib <- normalizePath(file.path(salida, "biblioteca"), mustWork = TRUE)
  ruta <- normalizePath(file.path(lib, "fhirviews"), mustWork = TRUE)
  if ("fhirviews" %in% loadedNamespaces() &&
      !identical(normalizePath(getNamespaceInfo("fhirviews", "path")), ruta)) {
    stop("Reinicia R: hay otra copia de fhirviews cargada. Luego repite abrir_sesion().", call. = FALSE)
  }
  meta <- utils::packageDescription("fhirviews", lib.loc = lib)
  if (!identical(meta$Version, sesion$candidato_version)) stop("Version instalada incompatible.", call. = FALSE)
  .libPaths(c(lib, .libPaths()))
  library("fhirviews", lib.loc = lib, character.only = TRUE)
  if (!identical(normalizePath(getNamespaceInfo("fhirviews", "path")), ruta)) {
    stop("Se cargo una instalacion diferente.", call. = FALSE)
  }
  cat("Sesion abierta con fhirviews", meta$Version, "desde", ruta, "\n")
  invisible(ruta)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 2L) stop("Uso: Rscript INICIAR.R basico|completo carpeta-nueva", call. = FALSE)
  script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1L])
  # R codifica espacios como ~+~ en --file. Conservar una ruta literal existente.
  if (!file.exists(script)) script <- gsub("~+~", " ", script, fixed = TRUE)
  iniciar_piloto(args[1L], args[2L], dirname(normalizePath(script, mustWork = TRUE)))
}
