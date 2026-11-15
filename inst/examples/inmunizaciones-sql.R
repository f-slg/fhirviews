# SQL -> Patient, Encounter e Immunization -> NDJSON -> tablas.
# Datos ficticios. Requiere DBI y RSQLite. No es una recomendacion de vacunacion.
library(fhirviews)
db <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
DBI::dbWriteTable(db, "pacientes", data.frame(id = "p1"))
DBI::dbWriteTable(db, "encuentros", data.frame(id = "e1", paciente = "p1"))
DBI::dbWriteTable(db, "vacunaciones", data.frame(
  id = c("i1", "i2"), paciente = "p1", encuentro = c("e1", NA),
  estado = c("completed", "not-done"), vacuna = "VAC-FICT-01", descripcion = "Vacuna ficticia",
  sistema_vacuna = "https://example.org/fhir/CodeSystem/vacunas",
  fecha = c("2026-01-14T10:00:00-05:00", NA), fecha_texto = c(NA, "Fecha desconocida"),
  dosis = c("0.50", NA), unidad = c("mL", NA), sistema_unidad = c("http://unitsofmeasure.org", NA),
  numero = c(1L, NA_integer_), numero_texto = c(NA, "desconocido"),
  motivo = c(NA, "Registro ficticio: no administrada")))
mp <- fhir_mapa("Patient", c(id = "id"))
me <- fhir_mapa("Encounter", c(id = "id", "subject.reference" = "paciente"),
  constantes = list(status = "finished", "class.system" = "http://terminology.hl7.org/CodeSystem/v3-ActCode",
    "class.code" = "AMB", "subject.type" = "Patient"), referencias = c("subject.reference" = "Patient"))
mi <- fhir_mapa("Immunization", c(id = "id", status = "estado", "patient.reference" = "paciente",
  "encounter.reference" = "encuentro", "encounter.type" = "tipo_encuentro",
  "vaccineCode.coding[0].system" = "sistema_vacuna", "vaccineCode.coding[0].code" = "vacuna",
  "vaccineCode.text" = "descripcion", occurrenceDateTime = "fecha", occurrenceString = "fecha_texto",
  "doseQuantity.value" = "dosis", "doseQuantity.unit" = "unidad", "doseQuantity.code" = "unidad",
  "doseQuantity.system" = "sistema_unidad", "protocolApplied[0].doseNumberPositiveInt" = "numero",
  "protocolApplied[0].doseNumberString" = "numero_texto", "statusReason.text" = "motivo"),
  # En este ejemplo ambas filas proceden de la fuente primaria.
  constantes = list("patient.type" = "Patient", primarySource = TRUE),
  referencias = c("patient.reference" = "Patient", "encounter.reference" = "Encounter"))
pacientes <- fhir_desde_sql(db, "SELECT * FROM pacientes", mp)
encuentros <- fhir_desde_sql(db, "SELECT * FROM encuentros", me)
# El tipo opcional se omite junto con la referencia cuando no hay encuentro.
sql <- paste("SELECT *, CASE WHEN NULLIF(encuentro, '') IS NOT NULL THEN 'Encounter' END AS tipo_encuentro",
             "FROM vacunaciones ORDER BY id")
vacunas <- fhir_desde_sql(db, sql, mi)
DBI::dbDisconnect(db)
archivo <- tempfile(fileext = ".ndjson")
fhir_escribir(c(pacientes, encuentros, vacunas), archivo)
vista <- vista_crear("Immunization", c(paciente = "patient.getReferenceKey(Patient)",
  encuentro = "encounter.getReferenceKey(Encounter)", estado = "status",
  fecha = "occurrence.ofType(dateTime)", fecha_texto = "occurrence.ofType(string)",
  dosis = "doseQuantity.value", numero = "protocolApplied.doseNumber.ofType(positiveInt).first()",
  numero_texto = "protocolApplied.doseNumber.ofType(string).first()"))
tabla <- vista_ejecutar(archivo, vista)
print(tabla)
stopifnot(identical(tabla$id, c("i1", "i2")), identical(tabla$estado, c("completed", "not-done")),
  is.na(tabla$encuentro[2]), identical(tabla$fecha_texto[2], "Fecha desconocida"),
  isTRUE(all.equal(tabla$dosis, c(0.5, NA_real_))), is.null(vacunas[[2]]$doseQuantity))
# Para un servidor: crear primero Patient y Encounter, y validar Immunization
# con fhir_validar(con_fhir, vacunas[[1]], perfil = "URL-canonica-del-perfil").
