# Datos enteramente ficticios compartidos por los tres constructores.
casos_rust <- function(n) {
  repetir <- function(x) rep(x, length.out = n)
  ids <- function(prefijo) paste0(prefijo, seq_len(n))
  pacientes <- paste0("Patient/p", seq_len(n))
  if (!n) { ids <- function(prefijo) character(); pacientes <- character() }
  datos <- list(
    Patient = data.frame(id = ids("p"), sexo = repetir(c("female", "male", "unknown")),
      activo = repetir(c(FALSE, TRUE)), apellido = repetir(c("Muñoz", "李", "O'Connor")),
      fecha = as.Date(repetir(c("2000-02-29", "1981-07-12"))),
      fallecido = repetir(c(FALSE, NA)),
      fallecimiento = repetir(c(NA, "2026-01-01T10:00:00-05:00"))),
    Encounter = data.frame(id = ids("e"), estado = repetir(c("finished", "in-progress")),
      paciente = pacientes, inicio = repetir(c("2026-01-14T10:00:00-05:00", "2026-02-01")),
      actor = ids("Practitioner/a")),
    Condition = data.frame(id = ids("c"), paciente = pacientes,
      encuentro = ids("Encounter/e"),
      fecha = repetir(c("2026-01", NA)), edad = repetir(c(NA, "35.00")),
      texto = repetir(c("Condición ficticia", "Texto de prueba ñ"))),
    Observation = data.frame(id = ids("o"), paciente = pacientes,
      valor = repetir(c("0.50", "0.5", "72.00", "1.00", "12345678901234567890.001")),
      componente = repetir(c("12.00", NA)), limite = repetir(c("1.00", NA)),
      etiqueta = repetir(c("Componente ficticio", NA))),
    Immunization = data.frame(id = ids("i"), paciente = pacientes,
      encuentro = repetir(c("Encounter/e1", NA)), estado = repetir(c("completed", "not-done")),
      primaria = repetir(c(TRUE, FALSE)), fecha = repetir(c("2026-01-14T10:00:00-05:00", NA)),
      fecha_texto = repetir(c(NA, "Fecha desconocida")), dosis = repetir(c("0.50", NA)),
      unidad = repetir(c("mL", NA)), numero = repetir(c(1L, NA_integer_)),
      numero_texto = repetir(c(NA, "desconocido")), lote = repetir(c("Lote ficticio ñ", NA))))
  # Los ceros y FALSE permanecen; los NA y huecos se compactan.
  datos$Patient$nombres <- I(lapply(seq_len(n), function(i) c("Ana", NA, if (i %% 2) "María" else "")))
  mapas <- list(
    Patient = fhirviews::fhir_mapa("Patient", c(id = "id", gender = "sexo", active = "activo",
      "name[2].family" = "apellido", "name[2].given[]" = "nombres", birthDate = "fecha",
      deceasedBoolean = "fallecido", deceasedDateTime = "fallecimiento")),
    Encounter = fhirviews::fhir_mapa("Encounter", c(id = "id", status = "estado",
      "subject.reference" = "paciente", "period.start" = "inicio",
      "participant[0].individual.reference" = "actor"), constantes = list(
        "class.system" = "http://terminology.hl7.org/CodeSystem/v3-ActCode", "class.code" = "AMB")),
    Condition = fhirviews::fhir_mapa("Condition", c(id = "id", "subject.reference" = "paciente",
      "encounter.reference" = "encuentro", onsetDateTime = "fecha", "onsetAge.value" = "edad",
      "code.text" = "texto"), constantes = list(
        "clinicalStatus.coding[0].system" = "http://terminology.hl7.org/CodeSystem/condition-clinical",
        "clinicalStatus.coding[0].code" = "active",
        "verificationStatus.coding[0].system" = "http://terminology.hl7.org/CodeSystem/condition-ver-status",
        "verificationStatus.coding[0].code" = "confirmed")),
    Observation = fhirviews::fhir_mapa("Observation", c(id = "id", "subject.reference" = "paciente",
      "valueQuantity.value" = "valor", "component[0].code.text" = "etiqueta",
      "component[0].valueQuantity.value" = "componente",
      "component[0].referenceRange[0].low.value" = "limite"), constantes = list(
        status = "final", "code.text" = "Resultado ficticio")),
    Immunization = fhirviews::fhir_mapa("Immunization", c(id = "id", status = "estado",
      "patient.reference" = "paciente", "encounter.reference" = "encuentro",
      primarySource = "primaria", occurrenceDateTime = "fecha", occurrenceString = "fecha_texto",
      "doseQuantity.value" = "dosis", "doseQuantity.unit" = "unidad", lotNumber = "lote",
      "protocolApplied[0].doseNumberPositiveInt" = "numero",
      "protocolApplied[0].doseNumberString" = "numero_texto"), constantes = list(
        "vaccineCode.text" = "Vacuna ficticia")))
  list(datos = datos, mapas = mapas)
}
