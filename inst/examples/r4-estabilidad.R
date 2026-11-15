# Aceptacion local R4 con seis recursos FICTICIOS de cinco tipos.
# Sys.setenv(FHIRVIEWS_R4_SALIDA = "r4-01", FHIRVIEWS_R4_SQL = "false")
# source(system.file("examples", "r4-estabilidad.R", package = "fhirviews"))
# Con FHIRVIEWS_R4_SQL=true requiere DBI/duckdb y compara tambien ambos motores.
local({
  library(fhirviews)
  ejecutar <- function() {
    salida <- Sys.getenv("FHIRVIEWS_R4_SALIDA", unset = "")
    modo <- Sys.getenv("FHIRVIEWS_R4_SQL", unset = "false")
    if (!nzchar(salida) || file.exists(salida)) stop("Elige una carpeta R4 nueva.", call. = FALSE)
    if (!modo %in% c("true", "false")) stop("FHIRVIEWS_R4_SQL debe ser true o false.", call. = FALSE)
    sql <- identical(modo, "true")
    if (sql && (!requireNamespace("DBI", quietly = TRUE) || !requireNamespace("duckdb", quietly = TRUE))) {
      stop("El ensayo SQL requiere DBI y duckdb.", call. = FALSE)
    }
    if (!dir.create(salida, recursive = TRUE)) stop("No se pudo crear la salida R4.", call. = FALSE)
    exigir <- function(ok, codigo) {
      if (!isTRUE(ok)) stop(paste("Control R4:", codigo), call. = FALSE)
    }
    datos <- list(
      Patient = data.frame(id = "p1", sexo = "female", activo = FALSE,
        apellido = "Paredes", fecha = as.Date("2000-02-29")),
      Encounter = data.frame(id = "e1", paciente = "p1", estado = "finished"),
      Condition = data.frame(id = "c1", paciente = "p1", encuentro = "e1"),
      Observation = data.frame(id = "o1", paciente = "p1", valor = "72.00"),
      Immunization = data.frame(id = c("i1", "i2"), paciente = "p1",
        encuentro = c("e1", NA_character_), tipo_encuentro = c("Encounter", NA_character_),
        estado = c("completed", "not-done"), primaria = c(TRUE, FALSE),
        fecha = c("2026-01-14T10:00:00-05:00", NA_character_),
        fecha_texto = c(NA_character_, "Fecha desconocida"),
        dosis = c("0.50", NA_character_), unidad = c("mL", NA_character_),
        sistema_unidad = c("http://unitsofmeasure.org", NA_character_),
        numero = c(1L, NA_integer_), numero_texto = c(NA_character_, "desconocido"),
        motivo = c(NA_character_, "Evento ficticio: no administrada")))
    mapas <- list(
      Patient = fhir_mapa("Patient", c(id = "id", gender = "sexo", active = "activo",
        "name[0].family" = "apellido", birthDate = "fecha")),
      Encounter = fhir_mapa("Encounter", c(id = "id", status = "estado",
        "subject.reference" = "paciente"), constantes = list("subject.type" = "Patient",
          "class.system" = "http://terminology.hl7.org/CodeSystem/v3-ActCode", "class.code" = "AMB"),
        referencias = c("subject.reference" = "Patient")),
      Condition = fhir_mapa("Condition", c(id = "id", "subject.reference" = "paciente",
        "encounter.reference" = "encuentro"), constantes = list("subject.type" = "Patient",
          "encounter.type" = "Encounter", "code.text" = "Diagnostico ficticio"),
        referencias = c("subject.reference" = "Patient", "encounter.reference" = "Encounter")),
      Observation = fhir_mapa("Observation", c(id = "id", "subject.reference" = "paciente",
        "valueQuantity.value" = "valor"), constantes = list(status = "final",
          "subject.type" = "Patient", "code.text" = "Resultado ficticio"),
        referencias = c("subject.reference" = "Patient")),
      Immunization = fhir_mapa("Immunization", c(id = "id", status = "estado",
        "patient.reference" = "paciente", "encounter.reference" = "encuentro",
        "encounter.type" = "tipo_encuentro", primarySource = "primaria",
        occurrenceDateTime = "fecha", occurrenceString = "fecha_texto",
        "doseQuantity.value" = "dosis", "doseQuantity.unit" = "unidad",
        "doseQuantity.code" = "unidad", "doseQuantity.system" = "sistema_unidad",
        "protocolApplied[0].doseNumberPositiveInt" = "numero",
        "protocolApplied[0].doseNumberString" = "numero_texto", "statusReason.text" = "motivo"),
        constantes = list("patient.type" = "Patient", "vaccineCode.text" = "Vacuna ficticia"),
        referencias = c("patient.reference" = "Patient", "encounter.reference" = "Encounter")))
    db <- NULL
    if (sql) {
      args <- if ("shared_home" %in% names(formals(duckdb::duckdb))) list(shared_home = FALSE) else list()
      db <- DBI::dbConnect(do.call(duckdb::duckdb, args))
      on.exit(DBI::dbDisconnect(db), add = TRUE)
    }
    grupos <- lapply(names(datos), function(tipo) {
      if (!sql) return(fhir_desde_tabla(datos[[tipo]], mapas[[tipo]]))
      DBI::dbWriteTable(db, tipo, datos[[tipo]])
      consulta <- paste0('SELECT * FROM "', tipo, '" WHERE ',
        if (tipo == "Immunization") 'paciente = ?' else 'id = ?', ' ORDER BY id')
      parametro <- if (tipo == "Immunization") "p1" else datos[[tipo]]$id
      fhir_desde_sql(db, consulta, mapas[[tipo]], parametros = list(parametro))
    })
    names(grupos) <- names(datos)
    recursos <- do.call(c, grupos)
    exigir(length(recursos) == 6L, "conteo_recursos")
    exigir(identical(grupos$Patient[[1]]$active, FALSE) &&
      identical(grupos$Patient[[1]]$birthDate, "2000-02-29"), "tipos_paciente")
    exigir(identical(grupos$Condition[[1]]$encounter$reference, "Encounter/e1") &&
      identical(grupos$Observation[[1]]$subject$reference, "Patient/p1"), "referencias")
    exigir(is.null(grupos$Immunization[[2]]$encounter) &&
      is.null(grupos$Immunization[[2]]$doseQuantity) &&
      identical(grupos$Immunization[[2]]$primarySource, FALSE), "ausentes_y_booleano")
    vistas <- list(
      Patient = vista_crear("Patient", c(activo = "active", nacimiento = "birthDate")),
      Encounter = vista_crear("Encounter", c(paciente = "subject.getReferenceKey(Patient)", estado = "status")),
      Condition = vista_crear("Condition", c(paciente = "subject.getReferenceKey(Patient)", encuentro = "encounter.getReferenceKey(Encounter)")),
      Observation = vista_crear("Observation", c(paciente = "subject.getReferenceKey(Patient)", valor = "value.ofType(Quantity).value",
        limite = "value.ofType(Quantity).value.lowBoundary()")),
      Immunization = vista_crear("Immunization", c(paciente = "patient.getReferenceKey(Patient)",
        encuentro = "encounter.getReferenceKey(Encounter)", dosis = "doseQuantity.value",
        limite = "doseQuantity.value.lowBoundary()", fecha = "occurrence.ofType(dateTime)",
        fecha_texto = "occurrence.ofType(string)", numero = "protocolApplied.doseNumber.ofType(positiveInt).first()",
        numero_texto = "protocolApplied.doseNumber.ofType(string).first()")))
    tablas <- lapply(vistas, function(v) vista_ejecutar(recursos, v))
    exigir(identical(tablas$Immunization$id, c("i1", "i2")) &&
      identical(tablas$Immunization$fecha_texto, c(NA_character_, "Fecha desconocida")) &&
      identical(tablas$Immunization$numero_texto, c(NA_character_, "desconocido")) &&
      identical(tablas$Immunization$numero, c(1L, NA_integer_)), "elecciones")
    exigir(isTRUE(all.equal(tablas$Observation$limite, 71.995)) &&
      isTRUE(all.equal(tablas$Immunization$limite, c(0.495, NA_real_))), "precision_decimal")
    for (formato in c("ndjson", "json")) {
      archivo <- file.path(salida, paste0("recursos-r4.", formato))
      fhir_escribir(recursos, archivo, formato)
      fuente <- paste(readLines(archivo, warn = FALSE), collapse = "\n")
      exigir(grepl('"value":72.00', fuente, fixed = TRUE) &&
        grepl('"value":0.50', fuente, fixed = TRUE), "escala_json")
      leidos <- fhir_recursos(archivo)
      for (tipo in names(vistas)) {
        exigir(isTRUE(all.equal(tablas[[tipo]], vista_ejecutar(leidos, vistas[[tipo]]))), "retorno_v8")
      }
    }
    if (sql) for (tipo in names(vistas)) {
      tabla_sql <- vista_ejecutar_duckdb(file.path(salida, "recursos-r4.ndjson"), vistas[[tipo]])
      exigir(isTRUE(all.equal(tablas[[tipo]], tabla_sql)), "retorno_duckdb")
    }
    rechazado <- function(expr) {
      e <- tryCatch({ force(expr); NULL }, error = identity)
      exigir(inherits(e, "fhirviews_error_mapeo"), "negativo_no_rechazado")
    }
    rechazado(fhir_desde_tabla(data.frame(id = "c1"), fhir_mapa("Condition", c(id = "id"))))
    rechazado(fhir_desde_tabla(data.frame(id = c("p1", "p1")), fhir_mapa("Patient", c(id = "id"))))
    mal <- datos$Immunization
    mal$estado[1] <- "invalido"
    rechazado(fhir_desde_tabla(mal, mapas$Immunization))
    mal <- datos$Immunization
    mal$paciente[1] <- NA_character_
    rechazado(fhir_desde_tabla(mal, mapas$Immunization))
    rechazado(fhir_mapa("Immunization", c(id = "id", "doseQuantity.comparator" = "comparador")))
    resumen <- list(version_fhir = "4.0.1", recursos = 6L, tipos = names(datos),
      origen = if (sql) "DuckDB con consultas parametrizadas" else "data.frame",
      motores = if (sql) c("V8", "DuckDB") else "V8", negativos_rechazados = 5L,
      escala_conservada = c("72.00", "0.50"), validacion_perfiles = "no_evaluada_sin_servidor",
      validacion_usuario_externo = "pendiente")
    jsonlite::write_json(resumen, file.path(salida, "resumen.json"), auto_unbox = TRUE, pretty = TRUE)
    cat("Recorrido R4 aprobado con seis recursos ficticios y cinco tipos.\n")
    resumen
  }
  ejecutar()
})
