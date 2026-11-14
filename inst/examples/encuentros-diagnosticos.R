# SQL -> Patient, Encounter y Condition -> NDJSON -> tablas. Datos ficticios.
# Requiere DBI y RSQLite. Los estados y codigos son decisiones del ejemplo.
library(fhirviews)
db <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
DBI::dbWriteTable(db, "pacientes", data.frame(id = "p1", sexo = "female"))
DBI::dbWriteTable(db, "encuentros", data.frame(id = "e1", paciente = "p1",
  estado = "finished", clase = "AMB", inicio = "2026-01-14T10:00:00-05:00"))
DBI::dbWriteTable(db, "diagnosticos", data.frame(id = "c1", paciente = "p1",
  encuentro = "e1", estado = "active", verificacion = "confirmed",
  descripcion = "Diagnostico ficticio", inicio = "2026-01-14"))
mp <- fhir_mapa("Patient", c(id = "id", gender = "sexo"))
me <- fhir_mapa("Encounter", c(id = "id", status = "estado", "class.code" = "clase",
  "subject.reference" = "paciente", "period.start" = "inicio"),
  constantes = list("class.system" = "http://terminology.hl7.org/CodeSystem/v3-ActCode",
    "subject.type" = "Patient"), referencias = c("subject.reference" = "Patient"))
mc <- fhir_mapa("Condition", c(id = "id", "subject.reference" = "paciente",
  "encounter.reference" = "encuentro", "clinicalStatus.coding[0].code" = "estado",
  "verificationStatus.coding[0].code" = "verificacion", "code.text" = "descripcion",
  onsetDateTime = "inicio"), constantes = list(
    "clinicalStatus.coding[0].system" = "http://terminology.hl7.org/CodeSystem/condition-clinical",
    "verificationStatus.coding[0].system" = "http://terminology.hl7.org/CodeSystem/condition-ver-status",
    "subject.type" = "Patient", "encounter.type" = "Encounter"),
  referencias = c("subject.reference" = "Patient", "encounter.reference" = "Encounter"))
pacientes <- fhir_desde_sql(db, "SELECT * FROM pacientes", mp)
encuentros <- fhir_desde_sql(db, "SELECT * FROM encuentros WHERE id = ?", me, list("e1"))
diagnosticos <- fhir_desde_sql(db, "SELECT * FROM diagnosticos WHERE id = ?", mc, list("c1"))
DBI::dbDisconnect(db)

salida <- tempfile(fileext = ".ndjson")
fhir_escribir(c(pacientes, encuentros, diagnosticos), salida)
vista <- vista_crear("Condition", c(paciente = "subject.getReferenceKey(Patient)",
  encuentro = "encounter.getReferenceKey(Encounter)", estado = "clinicalStatus.coding.code"))
tabla <- vista_ejecutar(salida, vista)
print(tabla)
#   id paciente encuentro estado
# 1 c1       p1        e1 active
stopifnot(identical(tabla, data.frame(id = "c1", paciente = "p1", encuentro = "e1", estado = "active")))
# Validar los perfiles del proyecto antes de usar la salida con su servidor:
# fhir_validar(con_fhir, encuentros[[1]], perfil = "URL-canonica-del-perfil")
# fhir_validar(con_fhir, diagnosticos[[1]], perfil = "URL-canonica-del-perfil")
