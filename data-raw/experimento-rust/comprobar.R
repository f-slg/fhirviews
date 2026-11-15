args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop("Uso: Rscript comprobar.R BINARIO SALIDA-NUEVA")
binario <- normalizePath(args[1], mustWork = TRUE)
salida <- args[2]
if (file.exists(salida) || !dir.create(salida, recursive = TRUE)) stop("La salida debe ser nueva")
source("data-raw/experimento-rust/cargar.R")
source("data-raw/experimento-rust/ayudas.R")
source("data-raw/experimento-rust/casos.R")
e <- crear_experimento(file.path(salida, "plan.json"), binario)
metodos <- c("original", "preparado", "rust")
textos <- function(x) {
  if (!length(x)) return(character())
  fhirviews:::motor_actual()$recursos_json(attr(x, "fuente"))
}
comprobaciones <- 0L
exigir <- function(ok, codigo) {
  if (!isTRUE(ok)) stop(paste("Fallo diferencial:", codigo), call. = FALSE)
  comprobaciones <<- comprobaciones + 1L
}
for (n in c(0L, 1L, 8L, 31L)) {
  c <- casos_rust(n)
  for (tipo in names(c$datos)) {
    resultados <- lapply(metodos, function(m) e[[m]](c$datos[[tipo]], c$mapas[[tipo]]))
    for (i in 2:3) exigir(identical(textos(resultados[[1]]), textos(resultados[[i]])), paste(tipo, n, metodos[i], "JSON exacto"))
    if (n == 8L) {
      for (formato in c("ndjson", "json")) {
        archivos <- vapply(seq_along(resultados), function(i) {
          archivo <- file.path(salida, paste(tipo, i, formato, sep = "."))
          fhirviews::fhir_escribir(resultados[[i]], archivo, formato)
          archivo
        }, character(1))
        for (i in 2:3) exigir(identical(readBin(archivos[1], "raw", file.info(archivos[1])$size),
          readBin(archivos[i], "raw", file.info(archivos[i])$size)), paste(tipo, formato, "bytes"))
      }
      vista <- switch(tipo,
        Patient = fhirviews::vista_crear(tipo, c(activo = "active", nombres = "name.given.join(',')")),
        Encounter = fhirviews::vista_crear(tipo, c(paciente = "subject.getReferenceKey(Patient)", estado = "status")),
        Condition = fhirviews::vista_crear(tipo, c(paciente = "subject.getReferenceKey(Patient)", encuentro = "encounter.getReferenceKey(Encounter)")),
        Observation = fhirviews::vista_crear(tipo, c(valor = "value.ofType(Quantity).value", limite = "value.ofType(Quantity).value.lowBoundary()")),
        Immunization = fhirviews::vista_crear(tipo, c(dosis = "doseQuantity.value", limite = "doseQuantity.value.lowBoundary()", primaria = "primarySource")))
      tablas <- lapply(resultados, fhirviews::vista_ejecutar, vista = vista)
      for (i in 2:3) exigir(identical(tablas[[1]], tablas[[i]]), paste(tipo, "SQL on FHIR"))
      if (tipo == "Observation") {
        fuente <- paste(textos(resultados[[3]]), collapse = "\n")
        for (valor in c('"value":0.50', '"value":0.5}', '"value":72.00', '"value":1.00', '"value":12345678901234567890.001')) {
          exigir(grepl(valor, fuente, fixed = TRUE), paste("literal", valor))
        }
        exigir(isTRUE(all.equal(tablas[[3]]$limite[1:3], c(0.495, 0.45, 71.995))), "escala y lowBoundary")
      }
    }
  }
}
c <- casos_rust(3L)
casos_errores <- list()
agregar <- function(nombre, tipo, datos, mapa = c$mapas[[tipo]]) {
  casos_errores[[nombre]] <<- list(tipo = tipo, datos = datos, mapa = mapa)
}
mutar <- function(tipo, nombre, columna, valor, fila = 2L) {
  d <- c$datos[[tipo]]; d[[columna]][fila] <- valor; agregar(nombre, tipo, d)
}
mutar("Patient", "binding primitivo", "sexo", "invalido")
mutar("Patient", "code separador unicode", "sexo", "fe\u00a0male")
mutar("Patient", "booleano primitivo", "activo", "false")
mutar("Patient", "id vacio", "id", NA_character_)
mutar("Encounter", "status obligatorio", "estado", NA_character_)
mutar("Encounter", "destino reference", "paciente", "Observation/o1")
mutar("Encounter", "reference contenida", "paciente", "#p1")
mutar("Encounter", "reference relativa invalida", "paciente", "p1")
mutar("Encounter", "reference id demasiado largo", "paciente", paste0("Patient/", strrep("p", 65)))
mutar("Condition", "choice doble", "fecha", "2026-01-01")
mutar("Observation", "decimal no JSON", "valor", "00.50")
mutar("Observation", "component obligatorio", "etiqueta", NA_character_, 1L)
mutar("Immunization", "estado desconocido", "estado", "invalid")
mutar("Immunization", "paciente obligatorio", "paciente", NA_character_)
mutar("Immunization", "ocurrencia obligatoria", "fecha", NA_character_, 1L)
mutar("Immunization", "ocurrencia doble", "fecha_texto", "Fecha ficticia", 1L)
mutar("Immunization", "positiveInt cero", "numero", 0L, 1L)
for (tipo in names(c$datos)) {
  d <- c$datos[[tipo]]; d$id[2] <- d$id[1]; agregar(paste(tipo, "id duplicado"), tipo, d)
}
minimo <- data.frame(id = "x")
for (tipo in c("Observation", "Encounter", "Condition", "Immunization")) {
  agregar(paste(tipo, "faltan requeridos"), tipo, minimo, fhirviews::fhir_mapa(tipo, c(id = "id")))
}
for (caso in list(
  list("type solo", list("subject.type" = "Patient")),
  list("type distinto", list("subject.type" = "Group", "subject.reference" = "Patient/p1")),
  list("type no recurso", list("subject.type" = "HumanName", "subject.display" = "Ficticio")))) {
  tipo <- "Observation"
  constantes <- c(list(status = "final", "code.text" = "Ficticio"), caso[[2]])
  agregar(caso[[1]], tipo, minimo, fhirviews::fhir_mapa(tipo, c(id = "id"), constantes))
}
# El primer error debe ser el de la primera fila, aunque una conversion posterior falle.
d <- c$datos$Patient; d$sexo[1] <- "invalid"; d$id[2] <- "id con espacios"
agregar("precedencia estructural antes de primitivo", "Patient", d)
d <- c$datos$Patient; d$id[2] <- d$id[1]; d$sexo[3] <- "invalid"
agregar("validacion antes de ids duplicados", "Patient", d)
agregar("CodeableConcept requerido sin Coding", "Condition", minimo,
  fhirviews::fhir_mapa("Condition", c(id = "id"), list(
    "subject.reference" = "Patient/p1", "clinicalStatus.text" = "active")))
agregar("binding CodeableConcept sistema incorrecto", "Condition", minimo,
  fhirviews::fhir_mapa("Condition", c(id = "id"), list("subject.reference" = "Patient/p1",
    "clinicalStatus.coding[0].system" = "urn:invalido", "clinicalStatus.coding[0].code" = "active")))
errores <- lapply(names(casos_errores), function(nombre) {
  caso <- casos_errores[[nombre]]
  rs <- lapply(metodos, function(m) tryCatch(e[[m]](caso$datos, caso$mapa), error = identity))
  firmas <- lapply(rs, function(r) {
    exigir(inherits(r, "fhirviews_error_mapeo"), paste(nombre, "rechazado"))
    list(clase = class(r)[1], fila = r$fila, campo = r$campo)
  })
  for (i in 2:3) exigir(identical(firmas[[1]], firmas[[i]]), paste(nombre, "fila y campo", metodos[i]))
  list(caso = nombre, resultado = firmas[[1]])
})
# Variantes legales de referencias, todas con el mismo resultado que R.
for (literal in c("Patient/p1", "Patient/p1/_history/v2", "https://example.invalid/fhir/Patient/p1",
  "https://example.invalid/fhir/Patient/p1/_history/v2", "urn:uuid:00000000-0000-0000-0000-000000000001")) {
  mapa <- fhirviews::fhir_mapa("Observation", c(id = "id"), constantes = list(
    status = "final", "code.text" = "Ficticio", "subject.reference" = literal, "subject.type" = "Patient"))
  rs <- lapply(metodos, function(m) e[[m]](minimo, mapa))
  for (i in 2:3) exigir(identical(textos(rs[[1]]), textos(rs[[i]])), "referencias legales")
}
resumen <- list(estado = "aprobado", comprobaciones = comprobaciones,
  escenarios_validos = 20L, escenarios_errores = length(errores),
  tipos = names(c$datos), nodos = e$nodos, tipos_recurso_modelo_r4 = e$recursos_r4,
  errores = errores, alcance = "Paridad del constructor con entradas tipadas por R; no valida perfiles clinicos")
jsonlite::write_json(resumen, file.path(salida, "paridad.json"), auto_unbox = TRUE, pretty = TRUE, null = "null")
cat("Paridad aprobada:", comprobaciones, "comprobaciones,", length(errores), "errores esperados.\n")
