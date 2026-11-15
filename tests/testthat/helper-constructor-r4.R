# Datos ficticios compartidos por las pruebas del constructor R y su componente.
casos_constructor_r4 <- function(n = 3L) {
  i <- seq_len(n)
  clave <- function(p) paste0(p, i, recycle0 = TRUE)
  datos <- list(
    Patient = data.frame(id = clave("p"), sexo = rep("female", n)),
    Encounter = data.frame(id = clave("e"), paciente = clave("p")),
    Condition = data.frame(id = clave("c"), paciente = clave("p")),
    Observation = data.frame(id = clave("o"), muestra = clave("s"),
      valor = rep(c("0.50", "72.00", "12345678901234567890.001"), length.out = n)),
    Immunization = data.frame(id = clave("i"), paciente = clave("p")),
    Specimen = data.frame(id = clave("s"), paciente = clave("p"),
      volumen = rep("5.00", n), estado = rep("available", n)),
    DiagnosticReport = data.frame(id = clave("d"), paciente = clave("p"),
      estado = rep("final", n)))
  datos$DiagnosticReport$resultados <- lapply(i, function(j) paste0("o", c(j, j + 100L)))
  datos$DiagnosticReport$muestras <- lapply(i, function(j) paste0("s", j))
  mapas <- list(
    Patient = fhir_mapa("Patient", c(id = "id", gender = "sexo")),
    Encounter = fhir_mapa("Encounter", c(id = "id", "subject.reference" = "paciente"),
      constantes = list(status = "finished", "class.code" = "AMB"),
      referencias = c("subject.reference" = "Patient")),
    Condition = fhir_mapa("Condition", c(id = "id", "subject.reference" = "paciente"),
      referencias = c("subject.reference" = "Patient")),
    Observation = fhir_mapa("Observation", c(id = "id", "specimen.reference" = "muestra",
      "valueQuantity.value" = "valor"), constantes = list(status = "final", "code.text" = "Ficticio"),
      referencias = c("specimen.reference" = "Specimen")),
    Immunization = fhir_mapa("Immunization", c(id = "id", "patient.reference" = "paciente"),
      constantes = list(status = "completed", "vaccineCode.text" = "Ficticio", occurrenceDateTime = "2026-01-14"),
      referencias = c("patient.reference" = "Patient")),
    Specimen = fhir_mapa("Specimen", c(id = "id", status = "estado", "subject.reference" = "paciente",
      "collection.quantity.value" = "volumen"), constantes = list("collection.collectedDateTime" = "2026-01-14"),
      referencias = c("subject.reference" = "Patient")),
    DiagnosticReport = fhir_mapa("DiagnosticReport", c(id = "id", status = "estado",
      "subject.reference" = "paciente", "result[].reference" = "resultados", "specimen[].reference" = "muestras"),
      constantes = list("code.text" = "Informe ficticio", issued = "2026-01-14T15:00:00Z"),
      referencias = c("subject.reference" = "Patient", "result[].reference" = "Observation", "specimen[].reference" = "Specimen")))
  list(datos = datos, mapas = mapas)
}

componente_rust_pruebas <- function() {
  binario <- Sys.getenv("FHIRVIEWS_RUST_BIN")
  skip_if(!nzchar(binario), "FHIRVIEWS_RUST_BIN no esta definido")
  fhir_componente_rust(binario, fallback = FALSE)
}

firma_error_mapeo <- function(f) {
  e <- tryCatch(f(), error = identity)
  expect_s3_class(e, "fhirviews_error_mapeo")
  list(clase = class(e), fila = e$fila, campo = e$campo, mensaje = conditionMessage(e))
}
