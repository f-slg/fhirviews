mapa_inmunizacion_prueba <- function(...) fhir_mapa("Immunization", ...)
base_inmunizacion <- function() list(
  status = "completed", "vaccineCode.text" = "Vacuna ficticia",
  "patient.reference" = "Patient/p1", occurrenceDateTime = "2026-01-14")

test_that("Immunization construye fecha, texto y dosis sin inferir datos", {
  m <- mapa_inmunizacion_prueba(c(id = "id", status = "estado", "patient.reference" = "paciente",
    "encounter.reference" = "encuentro", "encounter.type" = "tipo_encuentro",
    occurrenceDateTime = "fecha", occurrenceString = "fecha_texto",
    primarySource = "fuente", "doseQuantity.value" = "volumen",
    "protocolApplied[0].doseNumberPositiveInt" = "numero", "protocolApplied[0].doseNumberString" = "numero_texto"),
    constantes = list("vaccineCode.coding[0].system" = "https://example.org/vacunas",
      "vaccineCode.coding[0].code" = "VAC-FICT-01", "patient.type" = "Patient"),
    referencias = c("patient.reference" = "Patient", "encounter.reference" = "Encounter"))
  d <- data.frame(id = c("i1", "i2"), estado = c("completed", "not-done"), paciente = "p1",
    encuentro = c("e1", NA), tipo_encuentro = c("Encounter", NA), fecha = c("2026-01-14T10:00:00-05:00", NA),
    fecha_texto = c(NA, "Fecha desconocida"), fuente = c(TRUE, FALSE), volumen = c("0.50", NA),
    numero = c(1L, NA_integer_), numero_texto = c(NA, "desconocido"))
  r <- fhir_desde_tabla(d, m)
  expect_length(r, 2L)
  expect_identical(r[[1]]$patient$reference, "Patient/p1")
  expect_identical(r[[1]]$encounter$reference, "Encounter/e1")
  expect_identical(r[[1]]$occurrenceDateTime, d$fecha[1])
  expect_identical(r[[2]]$occurrenceString, "Fecha desconocida")
  expect_null(r[[2]]$occurrenceDateTime)
  expect_null(r[[2]]$doseQuantity)
  expect_null(r[[2]]$encounter)
  expect_false(r[[2]]$primarySource)
  expect_identical(r[[1]]$protocolApplied[[1]]$doseNumberPositiveInt, 1L)
  expect_identical(r[[2]]$protocolApplied[[1]]$doseNumberString, "desconocido")
  expect_match(attr(r, "fuente")[[1]], '"value":0.50', fixed = TRUE)
  archivo <- withr_tempfile(".ndjson")
  fhir_escribir(r, archivo)
  expect_equal(vista_fhirpath(fhir_recursos(archivo), "doseQuantity.value.lowBoundary()"), c(0.495, NA_real_))
})

test_that("Immunization exige los obligatorios, codigos y elecciones R4", {
  d <- data.frame(id = "i1")
  for (campo in names(base_inmunizacion())) {
    cs <- base_inmunizacion()
    cs[[campo]] <- NULL
    expect_error(fhir_desde_tabla(d, mapa_inmunizacion_prueba(c(id = "id"), constantes = cs)),
      "obligatorio", class = "fhirviews_error_mapeo")
  }
  for (estado in c("inexistente", "COMPLETED")) {
    cs <- base_inmunizacion(); cs$status <- estado
    expect_error(fhir_desde_tabla(d, mapa_inmunizacion_prueba(c(id = "id"), constantes = cs)), "ValueSet requerido")
  }
  cs <- base_inmunizacion(); cs$status <- "entered-in-error"
  expect_identical(fhir_desde_tabla(d, mapa_inmunizacion_prueba(c(id = "id"), constantes = cs))[[1]]$status, "entered-in-error")
  cs <- base_inmunizacion(); cs$occurrenceString <- "Fecha desconocida"
  expect_error(fhir_desde_tabla(d, mapa_inmunizacion_prueba(c(id = "id"), constantes = cs)), "eleccion")
  cs <- base_inmunizacion(); cs[["protocolApplied[0].series"]] <- "Serie ficticia"
  expect_error(fhir_desde_tabla(d, mapa_inmunizacion_prueba(c(id = "id"), constantes = cs)), "obligatorio")
  for (numero in list(0, -1, 1.2, "1")) {
    cs <- base_inmunizacion(); cs[["protocolApplied[0].doseNumberPositiveInt"]] <- numero
    expect_error(fhir_desde_tabla(d, mapa_inmunizacion_prueba(c(id = "id"), constantes = cs)), class = "fhirviews_error_mapeo")
  }
  cs <- base_inmunizacion(); cs[["protocolApplied[0].doseNumberPositiveInt"]] <- 1L
  cs[["protocolApplied[0].doseNumberString"]] <- "primera"
  expect_error(fhir_desde_tabla(d, mapa_inmunizacion_prueba(c(id = "id"), constantes = cs)), "eleccion")
})

test_that("Immunization respeta SimpleQuantity sin restringir Quantity general", {
  expect_error(mapa_inmunizacion_prueba(c(id = "id", "doseQuantity.comparator" = "comparador")), "prohibido")
  # Los limites de un Range tambien son SimpleQuantity.
  expect_error(fhir_mapa("Observation", c(id = "id", "referenceRange[0].low.comparator" = "x")), "prohibido")
  general <- fhir_mapa("Observation", c(id = "id", "valueQuantity.comparator" = "comparador"),
    constantes = list(status = "final", "code.text" = "Resultado ficticio"))
  expect_identical(fhir_desde_tabla(data.frame(id = "o1", comparador = "<"), general)[[1]]$valueQuantity$comparator, "<")
})

test_that("Immunization acepta Date sin inventar una hora y comprueba referencias", {
  cs <- base_inmunizacion(); cs$occurrenceDateTime <- NULL
  m <- mapa_inmunizacion_prueba(c(id = "id", occurrenceDateTime = "fecha"), constantes = cs)
  expect_identical(fhir_desde_tabla(data.frame(id = "i1", fecha = as.Date("2026-01-14")), m)[[1]]$occurrenceDateTime, "2026-01-14")
  instant <- mapa_inmunizacion_prueba(c(id = "id", "meta.lastUpdated" = "fecha"), constantes = base_inmunizacion())
  expect_error(fhir_desde_tabla(data.frame(id = "i1", fecha = as.Date("2026-01-14")), instant), "Clase no admitida")
  expect_error(mapa_inmunizacion_prueba(c(id = "id", "patient.reference" = "paciente"),
    referencias = c("patient.reference" = "Group")), "destino FHIR permitido")
  expect_error(mapa_inmunizacion_prueba(c(id = "id", "encounter.reference" = "encuentro"),
    referencias = c("encounter.reference" = "Observation")), "destino FHIR permitido")
  cs <- base_inmunizacion(); cs[["patient.reference"]] <- "Group/g1"
  expect_error(fhir_desde_tabla(data.frame(id = "i1"), mapa_inmunizacion_prueba(c(id = "id"), constantes = cs)), "destino FHIR permitido")
  cs <- base_inmunizacion(); cs[["patient.reference"]] <- NULL; cs[["patient.type"]] <- "Patient"
  expect_error(fhir_desde_tabla(data.frame(id = "i1"), mapa_inmunizacion_prueba(c(id = "id"), constantes = cs)), "type solo")
  cs[["patient.identifier.value"]] <- "identificador-local"
  expect_identical(fhir_desde_tabla(data.frame(id = "i1"), mapa_inmunizacion_prueba(c(id = "id"), constantes = cs))[[1]]$patient$identifier$value,
    "identificador-local")
  cs <- base_inmunizacion(); cs[["performer[0].actor.reference"]] <- "Patient/p1"
  expect_error(fhir_desde_tabla(data.frame(id = "i1"), mapa_inmunizacion_prueba(c(id = "id"), constantes = cs)), "destino FHIR permitido")
})
