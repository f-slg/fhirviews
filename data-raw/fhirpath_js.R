# -----------------------------------------------------------------------------
# fhirviews · Actualizar fhirpath.js
#
# Descarga la compilación para navegador de fhirpath.js (HL7/fhirpath.js,
# asset `fhirpath.zip` de cada release) y copia en inst/js/fhirpath/ los dos
# archivos que usa el paquete, sin modificarlos:
#
#   fhirpath.min.js     biblioteca (variable global `fhirpath`)
#   fhirpath.r4.min.js  modelo de FHIR R4 (variable global `fhirpath_r4_model`)
#   LICENSE.md          licencia de fhirpath.js
#   VERSION             versión incluida
#
# Al cambiar de versión, revisa también inst/COPYRIGHTS: el zip no trae la
# lista de dependencias empaquetadas. Para obtenerla, compila la misma versión
# y lee las fuentes del mapa de código:
#
#   git clone --depth 1 --branch <version> https://github.com/HL7/fhirpath.js
#   cd fhirpath.js && npm ci --ignore-scripts && cd browser-build && npx webpack
#   jq -r '.sources[]' fhirpath.min.js.map | grep node_modules
#
# (La compilación local de la 5.2.1 es idéntica byte a byte al zip oficial.)
#
# Uso: Rscript data-raw/fhirpath_js.R [version]
# -----------------------------------------------------------------------------
version <- commandArgs(trailingOnly = TRUE)[1]
if (is.na(version)) version <- "5.2.1"

url <- sprintf(
  "https://github.com/HL7/fhirpath.js/releases/download/%s/fhirpath.zip",
  version
)
zip <- tempfile(fileext = ".zip")
utils::download.file(url, zip, mode = "wb", quiet = TRUE)
tmp <- tempfile()
utils::unzip(zip, exdir = tmp)

destino <- file.path("inst", "js", "fhirpath")
dir.create(destino, showWarnings = FALSE, recursive = TRUE)
archivos <- c("fhirpath.min.js", "fhirpath.r4.min.js", "LICENSE.md")
ok <- file.copy(file.path(tmp, archivos), destino, overwrite = TRUE)
stopifnot(all(ok))
writeLines(version, file.path(destino, "VERSION"))

# Comprobación: la biblioteca carga en V8 y reporta la versión esperada
ct <- V8::v8()
ct$eval("var window = globalThis;")
invisible(ct$source(file.path(destino, "fhirpath.min.js")))
invisible(ct$source(file.path(destino, "fhirpath.r4.min.js")))
stopifnot(identical(ct$eval("fhirpath.version"), version))

message("fhirpath.js ", version, " copiado en ", destino)
