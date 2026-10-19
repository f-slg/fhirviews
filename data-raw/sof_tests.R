# -----------------------------------------------------------------------------
# fhirviews · Actualizar el banco oficial de pruebas de SQL on FHIR
#
# Copia los JSON de tests/ del repositorio FHIR/sql-on-fhir.js (licencia MIT)
# en inst/sof-tests/, sin modificarlos, junto con su licencia y un archivo
# FUENTE con el commit usado.
#
# Uso: Rscript data-raw/sof_tests.R [ref]
#      (ref: rama, etiqueta o commit; por defecto, el último commit que
#      modificó tests/ en main)
# -----------------------------------------------------------------------------
devtools::load_all(quiet = TRUE)

ref <- commandArgs(trailingOnly = TRUE)[1]
if (is.na(ref)) {
  ref <- jsonlite::fromJSON(paste0(
    "https://api.github.com/repos/FHIR/sql-on-fhir.js/commits",
    "?path=tests&sha=main&per_page=1"
  ))$sha[1]
}

destino <- file.path("inst", "sof-tests")
unlink(destino, recursive = TRUE)
info <- descargar_banco_sof(ref, destino)

utils::download.file(
  sprintf("https://raw.githubusercontent.com/FHIR/sql-on-fhir.js/%s/LICENSE.md",
          info$sha),
  file.path(destino, "LICENSE.md"), quiet = TRUE
)
message(length(list.files(destino, pattern = "\\.json$")), " archivos de ",
        "FHIR/sql-on-fhir.js@", substr(info$sha, 1, 7), " en ", destino)
