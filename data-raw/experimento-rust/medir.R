args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop("Uso: Rscript medir.R BINARIO SALIDA-NUEVA")
binario <- normalizePath(args[1], mustWork = TRUE)
salida <- args[2]
if (file.exists(salida) || !dir.create(salida, recursive = TRUE)) stop("La salida debe ser nueva")
source("data-raw/experimento-rust/cargar.R")
source("data-raw/experimento-rust/ayudas.R")
source("data-raw/experimento-rust/casos.R")
preparacion <- system.time(e <- crear_experimento(file.path(salida, "plan.json"), binario))[["elapsed"]]
metodos <- c("original", "preparado", "rust")
calentamiento <- casos_rust(5L)
for (m in metodos) for (tipo in names(calentamiento$datos)) {
  invisible(e[[m]](calentamiento$datos[[tipo]], calentamiento$mapas[[tipo]]))
}
textos <- function(x) fhirviews:::motor_actual()$recursos_json(attr(x, "fuente"))
set.seed(20261115)
mediciones <- list()
for (n in c(300L, 3000L)) {
  casos <- casos_rust(n)
  for (tipo in names(casos$datos)) {
    referencia <- NULL
    for (repeticion in 1:3) for (m in sample(metodos)) {
      gc()
      tiempo <- system.time(r <- e[[m]](casos$datos[[tipo]], casos$mapas[[tipo]]))
      json <- textos(r)
      if (is.null(referencia)) referencia <- json
      stopifnot(length(r) == n, identical(referencia, json))
      mediciones[[length(mediciones) + 1L]] <- data.frame(
        recurso = tipo, filas = n, repeticion = repeticion, metodo = m,
        segundos = unname(tiempo[["elapsed"]]), usuario = unname(tiempo[["user.self"]]),
        sistema = unname(tiempo[["sys.self"]]),
        usuario_hijos = unname(tiempo[["user.child"]]), sistema_hijos = unname(tiempo[["sys.child"]]))
      cat(tipo, n, repeticion, m, tiempo[["elapsed"]], "s\n")
      flush.console()
      utils::write.csv(do.call(rbind, mediciones), file.path(salida, "tiempos.csv"), row.names = FALSE)
    }
  }
}
tabla <- do.call(rbind, mediciones)
resumen <- aggregate(segundos ~ recurso + filas + metodo, tabla,
  function(x) c(mediana = median(x), minimo = min(x), maximo = max(x)))
resumen <- cbind(resumen[c("recurso", "filas", "metodo")], as.data.frame(resumen$segundos))
utils::write.csv(resumen, file.path(salida, "resumen.csv"), row.names = FALSE)
jsonlite::write_json(list(estado = "completado", fecha_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
  preparacion_compartida_segundos = preparacion, repeticiones = 3L, semilla = 20261115L,
  recursos = names(calentamiento$datos), filas = c(300L, 3000L), metodos = metodos,
  alcance = "Constructor completo por lote, incluido arranque CLI Rust, lectura del plan y transporte temporal. Excluye compilacion, carga de paquete, preparacion unica y creacion del mapa.",
  comparacion_json_exacta_cada_lote = TRUE, sistema = as.list(Sys.info()[c("sysname", "release", "version", "machine")]),
  carga = "Paquete instalado con bytecode; sin pkgload",
  version_r = R.version.string, version_paquete = as.character(utils::packageVersion("fhirviews")),
  sesion = capture.output(sessionInfo())), file.path(salida, "entorno.json"), auto_unbox = TRUE, pretty = TRUE)
print(resumen)
