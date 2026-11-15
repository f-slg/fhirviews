# Usar una instalacion real con bytecode R, igual que el paquete entregado.
# No cargar las funciones fuente mediante pkgload durante las mediciones.
lib <- Sys.getenv("FHIRVIEWS_RUST_LIB", unset = "")
if (nzchar(lib)) .libPaths(c(normalizePath(lib, mustWork = TRUE), .libPaths()))
library(fhirviews)
# La paridad se contrasta tambien contra desarrollos posteriores. Los tiempos
# publicados pertenecen a la version y commit fijados en su manifiesto.
stopifnot(utils::packageVersion("fhirviews") >= "0.5.0.9000")
