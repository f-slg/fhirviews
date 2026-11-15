# SQL -> Specimen -> Observation -> DiagnosticReport -> SQL on FHIR.
# Datos exclusivamente ficticios. Requiere DBI y DuckDB >= 1.3.0.
# source(system.file("examples", "laboratorio-r4.R", package = "fhirviews"))
# ejemplo <- laboratorio_r4()
# ejemplo$tablas$resultados
# Opcional: laboratorio_r4(componente = fhir_componente_rust("/ruta/binario"))

laboratorio_r4 <- function(prefijo = "demo-lab", componente = NULL) {
  stopifnot(requireNamespace("DBI", quietly = TRUE),
    requireNamespace("duckdb", quietly = TRUE),
    utils::packageVersion("duckdb") >= "1.3.0",
    is.character(prefijo), length(prefijo) == 1L, !is.na(prefijo),
    grepl("^[A-Za-z0-9.-]{1,45}$", prefijo))
  args <- if ("shared_home" %in% names(formals(duckdb::duckdb))) list(shared_home = FALSE) else list()
  db <- DBI::dbConnect(do.call(duckdb::duckdb, args))
  on.exit(DBI::dbDisconnect(db))
  id <- function(sufijo) paste0(prefijo, "-", sufijo)
  DBI::dbWriteTable(db, "pacientes", data.frame(id = id("p")))
  DBI::dbWriteTable(db, "muestras", data.frame(id = id("s"), paciente = id("p"),
    estado = "available", recogida = "2026-01-14T10:00:00-05:00", volumen = "5.00"))
  DBI::dbWriteTable(db, "observaciones", data.frame(id = id(c("o1", "o2")), paciente = id("p"),
    muestra = id("s"), informe = id("d"), valor = c("72.00", "13.50"),
    codigo = c("2339-0", "718-7"), unidad = c("mg/dL", "g/dL")))
  DBI::dbWriteTable(db, "informes", data.frame(id = id("d"), paciente = id("p"),
    estado = "final", emitido = "2026-01-14T16:00:00Z"))
  base <- "http://hl7.org/fhir/StructureDefinition/"
  mapas <- list(
    paciente = fhirviews::fhir_mapa("Patient", c(id = "id"),
      constantes = list("meta.profile[0]" = paste0(base, "Patient"))),
    muestra = fhirviews::fhir_mapa("Specimen", c(id = "id", status = "estado",
      "subject.reference" = "paciente", "collection.collectedDateTime" = "recogida",
      "collection.quantity.value" = "volumen"),
      constantes = list("meta.profile[0]" = paste0(base, "Specimen"),
        "type.text" = "Muestra ficticia", "collection.quantity.unit" = "mL",
        "collection.quantity.system" = "http://unitsofmeasure.org", "collection.quantity.code" = "mL"),
      referencias = c("subject.reference" = "Patient")),
    observacion = fhirviews::fhir_mapa("Observation", c(id = "id", "subject.reference" = "paciente",
      "specimen.reference" = "muestra", "valueQuantity.value" = "valor",
      "valueQuantity.unit" = "unidad", "valueQuantity.code" = "unidad", "code.coding[0].code" = "codigo"),
      constantes = list("meta.profile[0]" = paste0(base, "Observation"), status = "final",
        "code.coding[0].system" = "http://loinc.org", "valueQuantity.system" = "http://unitsofmeasure.org"),
      referencias = c("subject.reference" = "Patient", "specimen.reference" = "Specimen")),
    informe = fhirviews::fhir_mapa("DiagnosticReport", c(id = "id", status = "estado",
      "subject.reference" = "paciente", issued = "emitido", "result[].reference" = "resultados",
      "specimen[].reference" = "muestras"),
      constantes = list("meta.profile[0]" = paste0(base, "DiagnosticReport"), "code.text" = "Informe ficticio"),
      referencias = c("subject.reference" = "Patient", "result[].reference" = "Observation", "specimen[].reference" = "Specimen")))
  paciente <- fhirviews::fhir_desde_sql(db, "SELECT * FROM pacientes", mapas$paciente, componente = componente)
  muestra <- fhirviews::fhir_desde_sql(db, "SELECT * FROM muestras", mapas$muestra, componente = componente)
  observaciones <- fhirviews::fhir_desde_sql(db, "SELECT * FROM observaciones ORDER BY id", mapas$observacion, componente = componente)
  informe <- fhirviews::fhir_desde_sql(db,
    paste("SELECT i.*, (SELECT list(o.id ORDER BY o.id) FROM observaciones o WHERE o.informe = i.id) AS resultados,",
      "(SELECT list(DISTINCT o.muestra ORDER BY o.muestra) FROM observaciones o WHERE o.informe = i.id) AS muestras",
      "FROM informes i"), mapas$informe, componente = componente)
  recursos <- c(paciente, muestra, observaciones, informe)
  vistas <- list(
    muestras = fhirviews::vista_crear("Specimen", c(paciente = "subject.getReferenceKey(Patient)",
      volumen = "collection.quantity.value", limite = "collection.quantity.value.lowBoundary()")),
    resultados = fhirviews::vista_crear("DiagnosticReport", c(observacion = "getReferenceKey(Observation)"),
      por_cada = "result", columnas_recurso = c(id = "getResourceKey()", paciente = "subject.getReferenceKey(Patient)")),
    observaciones = fhirviews::vista_crear("Observation", c(muestra = "specimen.getReferenceKey(Specimen)",
      valor = "valueQuantity.value", limite = "valueQuantity.value.lowBoundary()")))
  tablas <- lapply(vistas, function(v) {
    r <- fhirviews::vista_ejecutar(recursos, v)
    sql <- fhirviews::vista_ejecutar_duckdb(recursos, v, con_db = db)
    stopifnot(isTRUE(all.equal(r, sql)))
    r
  })
  list(recursos = recursos, mapas = mapas, vistas = vistas, tablas = tablas)
}
