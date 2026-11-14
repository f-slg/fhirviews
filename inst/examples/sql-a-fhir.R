# SQL -> FHIR -> tabla, con datos ficticios. Requiere DBI y RSQLite.
library(fhirviews)
con_db <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")

DBI::dbWriteTable(con_db, "pacientes", data.frame(
  paciente_id = c("p1", "p2"), sexo = c("female", "male"),
  nacimiento = c("1985-03-12", "2001-11-30"),
  apellido = c("Paredes", "Salazar"), nombre = c("Ana", "Jorge")
))
DBI::dbWriteTable(con_db, "resultados", data.frame(
  resultado_id = c("o1", "o2"), paciente_id = c("p1", "p2"),
  valor = c("98.00", "131.0"), unidad = c("mg/dL", "mg/dL")
))

mapa_pacientes <- fhir_mapa("Patient", c(
  id = "paciente_id", gender = "sexo", birthDate = "nacimiento",
  "name[0].family" = "apellido", "name[0].given[0]" = "nombre"
))
pacientes <- fhir_desde_sql(con_db,
  "SELECT * FROM pacientes ORDER BY paciente_id", mapa_pacientes)

mapa_resultados <- fhir_mapa("Observation", c(
  id = "resultado_id", "subject.reference" = "paciente_id",
  "valueQuantity.value" = "valor", "valueQuantity.unit" = "unidad"
), constantes = list(
  status = "final", "code.text" = "Glucosa"
), referencias = c("subject.reference" = "Patient"))
observaciones <- fhir_desde_sql(con_db,
  "SELECT * FROM resultados ORDER BY resultado_id", mapa_resultados)

observaciones[[1]]$subject$reference  # "Patient/p1"
vista_fhirpath(observaciones, "value.ofType(Quantity).value")  # 98, 131

salida <- tempfile(fileext = ".ndjson")
fhir_escribir(c(pacientes, observaciones), salida)
fhir_escribir(observaciones, tempfile(fileext = ".json"), formato = "json")

# Comprobar los campos extraídos de los recursos construidos
vista <- vista_crear("Observation", c(
  paciente = "subject.getReferenceKey(Patient)",
  valor = "value.ofType(Quantity).value"
))
vista_ejecutar(salida, vista)
#   id paciente valor
# 1 o1       p1    98
# 2 o2       p2   131

# Parámetros enlazados por el controlador, sin interpolar valores
uno <- fhir_desde_sql(con_db,
  "SELECT * FROM pacientes WHERE paciente_id = ?", mapa_pacientes,
  parametros = list("p1"))
DBI::dbDisconnect(con_db)
stopifnot(length(pacientes) == 2L, length(observaciones) == 2L,
          length(uno) == 1L, nrow(vista_ejecutar(salida, vista)) == 2L)
