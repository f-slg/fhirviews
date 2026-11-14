# Actualiza la distribucion UMD original, sin modificarla. No requiere npm.
# Rscript data-raw/lossless_json.R [version]
version <- commandArgs(trailingOnly = TRUE)[1]
if (is.na(version)) version <- "4.3.3"
archivo <- tempfile(fileext = ".tgz")
tmp <- tempfile()
dir.create(tmp)
utils::download.file(sprintf(
  "https://registry.npmjs.org/lossless-json/-/lossless-json-%s.tgz", version),
  archivo, mode = "wb", quiet = TRUE)
utils::untar(archivo, exdir = tmp)
destino <- file.path("inst", "js", "lossless-json")
dir.create(destino, recursive = TRUE, showWarnings = FALSE)
stopifnot(all(file.copy(c(file.path(tmp, "package/lib/umd/lossless-json.js"),
                          file.path(tmp, "package/LICENSE.md")),
                        destino, overwrite = TRUE)))
writeLines(version, file.path(destino, "VERSION"))
unlink(c(archivo, tmp), recursive = TRUE)
