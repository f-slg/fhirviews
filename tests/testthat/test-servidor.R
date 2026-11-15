# Pruebas contra servidores reales. No se ejecutan en CRAN.
#
# * Lectura: el servidor público https://hapi.fhir.org/baseR4.
# * Escritura: solo si la variable de entorno FHIRVIEWS_SERVIDOR_ESCRITURA
#   apunta a un servidor de pruebas propio.
# * Integracion automatizada aislada: bash data-raw/probar-hapi.sh
#   (imagen fijada por digest, Docker o Podman, limpieza al terminar).

publico <- "https://hapi.fhir.org/baseR4"

test_that("lectura y paginacion en el servidor publico", {
  skip_on_cran()
  skip_if(identical(Sys.getenv("FHIRVIEWS_SOLO_SERVIDOR_PROPIO"), "true"),
          "Servidor publico excluido de la integracion aislada")
  skip_if_not(fhir_disponible(publico, tiempo = 10), "HAPI público no responde")
  con <- fhir_conectar(publico)
  expect_identical(con$version_fhir, "4.0.1")
  r <- fhir_buscar(con, "Patient", `_count` = 5, max_paginas = 2,
                   progreso = FALSE)
  expect_gt(length(r), 5L)
  expect_lte(length(r), 10L)
  df <- vista_ejecutar(r, vista_crear("Patient", c(sexo = "gender")))
  expect_identical(nrow(df), length(r))
  expect_identical(fhir_leer(con, "Patient", r[[1]]$id)$id, r[[1]]$id)
  expect_error(fhir_leer(con, "Patient", "fhirviews-no-existe-0"),
               class = "fhirviews_error_http")
})

# URL del servidor de escritura, o se omite la prueba
servidor_escritura <- function() {
  skip_on_cran()
  url <- Sys.getenv("FHIRVIEWS_SERVIDOR_ESCRITURA")
  skip_if(!nzchar(url), "FHIRVIEWS_SERVIDOR_ESCRITURA no está definida")
  skip_if_not(fhir_disponible(url), "El servidor de pruebas no responde")
  url
}

# Texto único por ejecución, para no mezclar datos de ejecuciones anteriores
marca_prueba <- function() {
  gsub("[^A-Za-z0-9]", "",
       paste0("fv", format(Sys.time(), "%Y%m%d%H%M%OS3"),
              sample.int(1e6, 1)))
}

sis_prueba <- "https://f-slg.github.io/fhirviews/prueba"

test_that("SQL a FHIR, perfiles R4, referencias y retorno a tablas", {
  con <- fhir_conectar(servidor_escritura(), panel = FALSE)
  skip_if_not_installed("DBI")
  skip_if_not_installed("duckdb", "1.3.0")
  marca <- marca_prueba()
  id_paciente <- paste0(marca, "-p")
  ids_observaciones <- paste0(marca, "-o", 1:2)
  db <- conectar_duckdb()
  on.exit(DBI::dbDisconnect(db), add = TRUE)
  creados <- list()
  on.exit(for (r in rev(creados)) try(fhir_borrar(con, r), silent = TRUE), add = TRUE)

  DBI::dbWriteTable(db, "pacientes_sql", data.frame(
    id = id_paciente, sexo = "female", apellido = paste("Prueba", marca),
    nombre = "Ficticio", nacimiento = "1985-03-12"))
  DBI::dbWriteTable(db, "observaciones_sql", data.frame(
    id = ids_observaciones, paciente = id_paciente,
    valor = c("72.00", "88.5"), fecha = "2025-06-01T10:00:00-05:00"))
  perfil_p <- "http://hl7.org/fhir/StructureDefinition/Patient"
  perfil_o <- "http://hl7.org/fhir/StructureDefinition/Observation"
  mp <- fhir_mapa("Patient", c(id = "id", gender = "sexo",
    "name[0].family" = "apellido", "name[0].given[0]" = "nombre",
    birthDate = "nacimiento"), constantes = list("meta.profile[0]" = perfil_p))
  mo <- fhir_mapa("Observation", c(id = "id", "subject.reference" = "paciente",
    "valueQuantity.value" = "valor", effectiveDateTime = "fecha"),
    constantes = list(status = "final", "meta.profile[0]" = perfil_o,
      "category[0].coding[0].system" = "http://terminology.hl7.org/CodeSystem/observation-category",
      "category[0].coding[0].code" = "vital-signs",
      "code.coding[0].system" = "http://loinc.org", "code.coding[0].code" = "8867-4",
      "valueQuantity.unit" = "/min", "valueQuantity.system" = "http://unitsofmeasure.org",
      "valueQuantity.code" = "/min"), referencias = c("subject.reference" = "Patient"))
  p <- fhir_desde_sql(db, "SELECT * FROM pacientes_sql WHERE id = ?", mp, list(id_paciente))
  o <- fhir_desde_sql(db, "SELECT * FROM observaciones_sql ORDER BY id", mo)
  archivo <- withr_tempfile(".ndjson")
  fhir_escribir(c(p, o), archivo)
  textos <- readLines(archivo, encoding = "UTF-8")
  expect_length(textos, 3L)
  expect_match(textos[2], '"value":72.00', fixed = TRUE)

  # Validar el JSON exacto que se enviara, con perfiles base explicitos.
  expect_true(attr(fhir_validar(con, textos[1], perfil = perfil_p), "valido"))
  creado <- fhir_actualizar(con, textos[1])
  creados <- c(creados, list(creado))
  expect_identical(creado$id, id_paciente)
  for (i in 2:3) {
    expect_true(attr(fhir_validar(con, textos[i], perfil = perfil_o), "valido"))
    creado <- fhir_actualizar(con, textos[i])
    creados <- c(creados, list(creado))
    expect_identical(creado$subject$reference, paste0("Patient/", id_paciente))
  }
  # Un control negativo demuestra que el validador realmente aplica reglas.
  invalido <- p[[1]]
  invalido$gender <- "mujer"
  validacion <- fhir_validar(con, invalido, perfil = perfil_p)
  expect_false(isTRUE(attr(validacion, "valido")))
  expect_true(any(validacion$severidad %in% c("error", "fatal")))

  recuperados <- fhir_leer(con, "Patient", id_paciente, como_recursos = TRUE)
  for (id in ids_observaciones) {
    recuperados <- c(recuperados, fhir_leer(con, "Observation", id, como_recursos = TRUE))
  }
  expect_identical(recuperados[[1]]$id, id_paciente)
  vista <- vista_crear("Observation", c(
    paciente = "subject.getReferenceKey(Patient)", valor = "value.ofType(Quantity).value",
    limite = "value.ofType(Quantity).value.lowBoundary()"))
  v8 <- vista_ejecutar(recuperados, vista)
  sql <- vista_ejecutar_duckdb(recuperados, vista, con_db = db)
  expect_identical(v8$id, ids_observaciones)
  expect_equal(v8$valor, c(72, 88.5))
  expect_equal(v8$limite, c(71.995, 88.45))
  expect_identical(v8$paciente, rep(id_paciente, 2L))
  expect_equal(sql, v8)
})

test_that("Encounter y Condition desde SQL, perfiles R4 y referencias", {
  con <- fhir_conectar(servidor_escritura(), panel = FALSE)
  skip_if_not_installed("DBI")
  skip_if_not_installed("duckdb", "1.3.0")
  db <- conectar_duckdb()
  on.exit(DBI::dbDisconnect(db), add = TRUE)
  creados <- list()
  on.exit(for (r in rev(creados)) try(fhir_borrar(con, r), silent = TRUE), add = TRUE)
  marca <- marca_prueba()
  ip <- paste0(marca, "-p")
  ie <- paste0(marca, "-e")
  ic <- paste0(marca, "-c")
  base <- "http://hl7.org/fhir/StructureDefinition/"
  DBI::dbWriteTable(db, "pacientes_ec", data.frame(id = ip, sexo = "female"))
  DBI::dbWriteTable(db, "encuentros_ec", data.frame(id = ie, paciente = ip,
    estado = "finished", clase = "AMB", inicio = "2026-01-14T10:00:00-05:00",
    fin = "2026-01-14T11:00:00-05:00"))
  DBI::dbWriteTable(db, "diagnosticos_ec", data.frame(id = ic, paciente = ip,
    encuentro = ie, estado = "active", verificacion = "confirmed", inicio = "2026-01-14"))
  mp <- fhir_mapa("Patient", c(id = "id", gender = "sexo"),
    constantes = list("meta.profile[0]" = paste0(base, "Patient")))
  me <- fhir_mapa("Encounter", c(id = "id", status = "estado", "class.code" = "clase",
    "subject.reference" = "paciente", "period.start" = "inicio", "period.end" = "fin"),
    constantes = list("class.system" = "http://terminology.hl7.org/CodeSystem/v3-ActCode",
      "meta.profile[0]" = paste0(base, "Encounter")), referencias = c("subject.reference" = "Patient"))
  mc <- fhir_mapa("Condition", c(id = "id", "subject.reference" = "paciente",
    "encounter.reference" = "encuentro", "clinicalStatus.coding[0].code" = "estado",
    "verificationStatus.coding[0].code" = "verificacion", onsetDateTime = "inicio"),
    constantes = list("clinicalStatus.coding[0].system" = "http://terminology.hl7.org/CodeSystem/condition-clinical",
      "verificationStatus.coding[0].system" = "http://terminology.hl7.org/CodeSystem/condition-ver-status",
      "category[0].coding[0].system" = "http://terminology.hl7.org/CodeSystem/condition-category",
      "category[0].coding[0].code" = "encounter-diagnosis", "code.text" = "Diagnostico ficticio de integracion",
      "meta.profile[0]" = paste0(base, "Condition")),
    referencias = c("subject.reference" = "Patient", "encounter.reference" = "Encounter"))
  p <- fhir_desde_sql(db, "SELECT * FROM pacientes_ec WHERE id = ?", mp, list(ip))
  e <- fhir_desde_sql(db, "SELECT * FROM encuentros_ec WHERE id = ?", me, list(ie))
  cnd <- fhir_desde_sql(db, "SELECT * FROM diagnosticos_ec WHERE id = ?", mc, list(ic))
  archivo <- withr_tempfile(".ndjson")
  fhir_escribir(c(p, e, cnd), archivo)
  textos <- readLines(archivo, encoding = "UTF-8")
  expect_length(textos, 3L)
  for (i in seq_along(textos)) {
    perfil <- paste0(base, c("Patient", "Encounter", "Condition")[i])
    expect_true(attr(fhir_validar(con, textos[i], perfil = perfil), "valido"))
    creado <- fhir_actualizar(con, textos[i])
    creados <- c(creados, list(creado))
    expect_identical(creado$id, c(ip, ie, ic)[i])
  }
  expect_identical(creados[[2]]$subject$reference, paste0("Patient/", ip))
  expect_identical(creados[[3]]$subject$reference, paste0("Patient/", ip))
  expect_identical(creados[[3]]$encounter$reference, paste0("Encounter/", ie))
  # Probar tambien que el validador aplica los perfiles nuevos.
  invalido <- e[[1]]
  invalido$status <- "inexistente"
  validacion <- fhir_validar(con, invalido, perfil = paste0(base, "Encounter"))
  expect_false(isTRUE(attr(validacion, "valido")))
  expect_true(any(validacion$severidad %in% c("error", "fatal")))
  invalido <- cnd[[1]]
  invalido$subject$reference <- paste0("Encounter/", ie)
  invalido$subject$type <- "Encounter"
  validacion <- fhir_validar(con, invalido, perfil = paste0(base, "Condition"))
  detalle <- paste(capture.output(as.data.frame(validacion)), collapse = "\n")
  expect_false(isTRUE(attr(validacion, "valido")), info = detalle)
  expect_true(any(validacion$severidad %in% c("error", "fatal")), info = detalle)
  invalido <- cnd[[1]]
  invalido$clinicalStatus$coding[[1]]$code <- "inexistente"
  validacion <- fhir_validar(con, invalido, perfil = paste0(base, "Condition"))
  expect_false(isTRUE(attr(validacion, "valido")))
  expect_true(any(validacion$severidad %in% c("error", "fatal")))
  le <- fhir_leer(con, "Encounter", ie, como_recursos = TRUE)
  lc <- fhir_leer(con, "Condition", ic, como_recursos = TRUE)
  ve <- vista_crear("Encounter", c(paciente = "subject.getReferenceKey(Patient)",
    estado = "status", clase = "class.code"))
  vc <- vista_crear("Condition", c(paciente = "subject.getReferenceKey(Patient)",
    encuentro = "encounter.getReferenceKey(Encounter)", estado = "clinicalStatus.coding.code"))
  te <- vista_ejecutar(le, ve)
  tc <- vista_ejecutar(lc, vc)
  expect_identical(te, data.frame(id = ie, paciente = ip, estado = "finished", clase = "AMB"))
  expect_identical(tc, data.frame(id = ic, paciente = ip, encuentro = ie, estado = "active"))
  expect_equal(vista_ejecutar_duckdb(le, ve, con_db = db), te)
  expect_equal(vista_ejecutar_duckdb(lc, vc, con_db = db), tc)
})

test_that("Immunization desde SQL, perfil R4, dosis y referencias", {
  con <- fhir_conectar(servidor_escritura(), panel = FALSE)
  skip_if_not_installed("DBI")
  skip_if_not_installed("duckdb", "1.3.0")
  db <- conectar_duckdb()
  on.exit(DBI::dbDisconnect(db), add = TRUE)
  creados <- list()
  on.exit(for (r in rev(creados)) try(fhir_borrar(con, r), silent = TRUE), add = TRUE)
  marca <- marca_prueba()
  ip <- paste0(marca, "-p")
  ie <- paste0(marca, "-e")
  ids <- paste0(marca, "-i", 1:2)
  perfil <- "http://hl7.org/fhir/StructureDefinition/Immunization"
  DBI::dbWriteTable(db, "paciente_im", data.frame(id = ip))
  DBI::dbWriteTable(db, "encuentro_im", data.frame(id = ie, paciente = ip))
  DBI::dbWriteTable(db, "vacunaciones", data.frame(id = ids, paciente = ip, encuentro = ie,
    estado = c("completed", "not-done"), fecha = c("2026-01-14T10:00:00-05:00", NA),
    fecha_texto = c(NA, "Fecha desconocida"), dosis = c("0.50", NA), unidad = c("mL", NA),
    sistema_unidad = c("http://unitsofmeasure.org", NA), numero = c(1L, NA_integer_),
    numero_texto = c(NA, "desconocido"), motivo = c(NA, "Registro ficticio: no administrada"),
    fuente = c(TRUE, FALSE)))
  mp <- fhir_mapa("Patient", c(id = "id"))
  me <- fhir_mapa("Encounter", c(id = "id", "subject.reference" = "paciente"),
    constantes = list(status = "finished", "class.system" = "http://terminology.hl7.org/CodeSystem/v3-ActCode",
      "class.code" = "AMB", "subject.type" = "Patient"), referencias = c("subject.reference" = "Patient"))
  mi <- fhir_mapa("Immunization", c(id = "id", status = "estado", "patient.reference" = "paciente",
    "encounter.reference" = "encuentro", occurrenceDateTime = "fecha", occurrenceString = "fecha_texto",
    "doseQuantity.value" = "dosis", "doseQuantity.unit" = "unidad", "doseQuantity.code" = "unidad",
    "doseQuantity.system" = "sistema_unidad", "protocolApplied[0].doseNumberPositiveInt" = "numero",
    "protocolApplied[0].doseNumberString" = "numero_texto", "statusReason.text" = "motivo", primarySource = "fuente"),
    constantes = list("meta.profile[0]" = perfil, "patient.type" = "Patient", "encounter.type" = "Encounter",
      "vaccineCode.coding[0].system" = "https://example.org/fhir/CodeSystem/vacunas",
      "vaccineCode.coding[0].code" = "VAC-FICT-01", "vaccineCode.text" = "Vacuna ficticia"),
    referencias = c("patient.reference" = "Patient", "encounter.reference" = "Encounter"))
  p <- fhir_desde_sql(db, "SELECT * FROM paciente_im WHERE id = ?", mp, list(ip))
  e <- fhir_desde_sql(db, "SELECT * FROM encuentro_im WHERE id = ?", me, list(ie))
  vacunas <- fhir_desde_sql(db, "SELECT * FROM vacunaciones ORDER BY id", mi)
  archivo <- withr_tempfile(".ndjson")
  fhir_escribir(c(p, e, vacunas), archivo)
  textos <- readLines(archivo, encoding = "UTF-8")
  expect_length(textos, 4L)
  expect_match(textos[3], '"value":0.50', fixed = TRUE)
  perfiles <- paste0("http://hl7.org/fhir/StructureDefinition/", c("Patient", "Encounter", "Immunization", "Immunization"))
  for (i in seq_along(textos)) {
    expect_true(attr(fhir_validar(con, textos[i], perfil = perfiles[i]), "valido"))
    creado <- fhir_actualizar(con, textos[i])
    creados <- c(creados, list(creado))
    expect_identical(creado$id, c(ip, ie, ids)[i])
  }
  for (r in creados[3:4]) {
    expect_identical(r$patient$reference, paste0("Patient/", ip))
    expect_identical(r$encounter$reference, paste0("Encounter/", ie))
  }
  # Controles del perfil: estado, destino de referencia, SimpleQuantity e imm-1.
  invalidos <- list(vacunas[[1]], vacunas[[1]], vacunas[[1]], vacunas[[1]])
  invalidos[[1]]$status <- "inexistente"
  invalidos[[2]]$patient <- list(reference = paste0("Encounter/", ie), type = "Encounter")
  invalidos[[3]]$doseQuantity$comparator <- "<"
  invalidos[[4]]$education <- list(list(presentationDate = "2026-01-14"))
  for (r in invalidos) {
    validacion <- fhir_validar(con, r, perfil = perfil)
    detalle <- paste(capture.output(as.data.frame(validacion)), collapse = "\n")
    expect_false(isTRUE(attr(validacion, "valido")), info = detalle)
    expect_true(any(validacion$severidad %in% c("error", "fatal")), info = detalle)
  }
  leidas <- c(fhir_leer(con, "Immunization", ids[1], como_recursos = TRUE),
              fhir_leer(con, "Immunization", ids[2], como_recursos = TRUE))
  expect_identical(vapply(leidas, `[[`, "", "id"), ids)
  expect_identical(leidas[[1]]$occurrenceDateTime, "2026-01-14T10:00:00-05:00")
  expect_identical(leidas[[2]]$occurrenceString, "Fecha desconocida")
  expect_null(leidas[[2]]$doseQuantity)
  expect_false(leidas[[2]]$primarySource)
  vista <- vista_crear("Immunization", c(paciente = "patient.getReferenceKey(Patient)",
    encuentro = "encounter.getReferenceKey(Encounter)", estado = "status",
    fecha_texto = "occurrence.ofType(string)", dosis = "doseQuantity.value",
    limite = "doseQuantity.value.lowBoundary()", numero = "protocolApplied.doseNumber.ofType(positiveInt).first()",
    numero_texto = "protocolApplied.doseNumber.ofType(string).first()"))
  v8 <- vista_ejecutar(leidas, vista)
  sql <- vista_ejecutar_duckdb(leidas, vista, con_db = db)
  expect_identical(v8$id, ids)
  expect_identical(v8$paciente, rep(ip, 2L))
  expect_identical(v8$encuentro, rep(ie, 2L))
  expect_identical(v8$estado, c("completed", "not-done"))
  expect_equal(v8$dosis, c(0.5, NA_real_))
  expect_equal(v8$limite, c(0.495, NA_real_))
  expect_identical(v8$fecha_texto, c(NA_character_, "Fecha desconocida"))
  expect_equal(v8$numero, c(1L, NA_integer_))
  expect_identical(v8$numero_texto, c(NA_character_, "desconocido"))
  expect_equal(sql, v8)
  catalogo <- vista_plantilla("inmunizaciones")
  expect_equal(vista_ejecutar_duckdb(leidas, catalogo, con_db = db), vista_ejecutar(leidas, catalogo))
})

test_that("ciclo completo de escritura en un servidor de pruebas", {
  con <- fhir_conectar(servidor_escritura(), panel = FALSE)
  marca <- marca_prueba()
  apellido <- paste("Paredes", marca)

  creados <- lapply(1:3, function(i) {
    fhir_crear(con, list(
      resourceType = "Patient",
      identifier = list(list(system = sis_prueba,
                             value = paste0(marca, "-", i))),
      name = list(list(family = apellido,
                       given = list(paste0("Prueba", i)))),
      gender = if (i == 1) "female" else "male",
      birthDate = "1985-03-12"
    ))
  })
  on.exit(for (p in creados) try(fhir_borrar(con, p), silent = TRUE), add = TRUE)
  expect_true(all(vapply(creados, function(p) es_texto(p$id), logical(1))))

  encontrados <- fhir_buscar(
    con, "Patient", identifier = paste0(sis_prueba, "|", marca, "-1"),
    progreso = FALSE)
  expect_length(encontrados, 1L)
  expect_identical(attr(encontrados, "total"), 1L)

  # Paginación real: _count = 1 obliga a seguir los enlaces next
  todos <- fhir_buscar(con, "Patient", family = apellido, `_count` = 1,
                       progreso = FALSE)
  expect_length(todos, 3L)
  expect_setequal(vapply(todos, `[[`, "", "id"),
                  vapply(creados, `[[`, "", "id"))
  dos <- fhir_buscar(con, "Patient", family = apellido, `_count` = 1,
                     max_paginas = 2, progreso = FALSE)
  expect_length(dos, 2L)
  # Un número grande no se envía en notación científica (1e+05)
  expect_length(fhir_buscar(con, "Patient", family = apellido,
                            `_count` = 100000, progreso = FALSE), 3L)

  p <- creados[[1]]
  p$telecom <- list(list(system = "phone", value = "0991234567"))
  actualizado <- fhir_actualizar(con, p)
  expect_identical(actualizado$telecom[[1]]$value, "0991234567")
  expect_identical(actualizado$meta$versionId, "2")
  expect_identical(fhir_leer(con, "Patient", p$id, version = "1")$meta$versionId,
                   "1")
  expect_null(fhir_leer(con, "Patient", p$id, version = "1")$telecom)

  todo <- fhir_everything(con, "Patient", p$id, progreso = FALSE)
  expect_true(p$id %in% vapply(todo, `[[`, "", "id"))

  v <- fhir_validar(con, list(resourceType = "Patient", gender = "mujer"))
  if (attr(v, "estado") >= 400L) {
    expect_identical(attr(v, "valido"), NA)
  } else {
    expect_false(attr(v, "valido"))
  }
  expect_true(any(v$severidad %in% c("error", "fatal")))
  expect_true(attr(fhir_validar(con, creados[[2]]), "valido"))

  # fhir_peticion: cualquier petición, con la respuesta completa
  r <- fhir_peticion(con, "GET", paste0("Patient/", p$id))
  expect_identical(attr(r, "estado"), 200L)
  expect_identical(r$id, p$id)

  fhir_borrar(con, creados[[3]])
  expect_error(fhir_leer(con, "Patient", creados[[3]]$id),
               class = "fhirviews_error_http_410")
})

test_that("transaccion, vistas con V8 y DuckDB y fhir_tabla con datos reales", {
  con <- fhir_conectar(servidor_escritura(), panel = FALSE)
  marca <- marca_prueba()
  uuid <- function(n) sprintf("urn:uuid:%08d-0000-4000-8000-%012d", n, n)
  paciente <- list(
    resourceType = "Patient",
    identifier = list(list(system = sis_prueba, value = marca)),
    name = list(list(family = "Salazar Moreno", given = list("Jorge", "Luis"))),
    gender = "male", birthDate = "2001-11-30",
    address = list(list(use = "home", city = "Loja", district = "Loja",
                        state = "Loja"))
  )
  observacion <- function(n, valor) {
    list(resourceType = "Observation", status = "final",
         category = list(list(coding = list(list(
           system = "http://terminology.hl7.org/CodeSystem/observation-category",
           code = "vital-signs")))),
         code = list(coding = list(list(system = "http://loinc.org",
                                        code = "8867-4",
                                        display = "Heart rate"))),
         subject = list(reference = uuid(1)),
         effectiveDateTime = sprintf("2025-06-0%dT10:00:00-05:00", n),
         valueQuantity = list(value = valor, unit = "/min",
                              system = "http://unitsofmeasure.org",
                              code = "/min"))
  }
  diagnostico <- list(
    resourceType = "Condition",
    clinicalStatus = list(coding = list(list(
      system = "http://terminology.hl7.org/CodeSystem/condition-clinical",
      code = "active"))),
    code = list(coding = list(list(system = "http://hl7.org/fhir/sid/icd-10",
                                   code = "A90", display = "Dengue"))),
    subject = list(reference = uuid(1)),
    recordedDate = "2025-06-01"
  )
  entrada <- function(n, recurso) {
    list(fullUrl = uuid(n), resource = recurso,
         request = list(method = "POST", url = recurso$resourceType))
  }
  transaccion <- list(resourceType = "Bundle", type = "transaction", entry = list(
    entrada(1, paciente), entrada(2, observacion(1, 72)),
    entrada(3, observacion(2, 88.5)), entrada(4, diagnostico)))

  res <- fhir_crear(con, transaccion)
  expect_identical(res$type, "transaction-response")
  ubicaciones <- vapply(res$entry, function(e) e$response$location, "")
  expect_length(ubicaciones, 4L)
  expect_true(all(startsWith(vapply(res$entry, function(e) e$response$status,
                                    ""), "201")))
  rutas <- sub("/_history/.*$", "", ubicaciones)
  # Se borran primero los que referencian al paciente
  on.exit(for (r in rev(rutas)) try(fhir_borrar(con, r), silent = TRUE),
          add = TRUE)
  id_paciente <- sub("^Patient/", "", rutas[1])

  obs <- fhir_buscar(con, "Observation", subject = rutas[1], progreso = FALSE)
  expect_length(obs, 2L)
  vista <- vista_crear("Observation", c(
    paciente = "subject.getReferenceKey(Patient)",
    fecha = "effective.ofType(dateTime)",
    valor = "value.ofType(Quantity).value",
    unidad = "value.ofType(Quantity).unit"))
  df <- vista_ejecutar(obs, vista)
  expect_identical(nrow(df), 2L)
  expect_identical(unique(df$paciente), id_paciente)
  expect_setequal(df$valor, c(72, 88.5))

  # La búsqueda con un único resultado (un Bundle de una entrada) da la misma
  # tabla con los dos motores
  pac <- fhir_buscar(con, "Patient", identifier = paste0(sis_prueba, "|", marca),
                     progreso = FALSE)
  expect_length(pac, 1L)
  vp <- vista_plantilla("pacientes")
  tabla_v8 <- vista_ejecutar(pac, vp)
  expect_identical(nrow(tabla_v8), 1L)
  expect_identical(tabla_v8$id, id_paciente)
  rapida <- fhir_tabla(pac)
  expect_identical(rapida$id, id_paciente)
  expect_match(rapida$name, "Salazar Moreno", fixed = TRUE)

  skip_if_not_installed("duckdb", "1.3.0")
  expect_identical(vista_ejecutar_duckdb(pac, vp), tabla_v8)
  expect_identical(vista_ejecutar_duckdb(obs, vista)[order(df$fecha), ],
                   df[order(df$fecha), ])
  todo <- fhir_everything(con, "Patient", id_paciente, progreso = FALSE)
  expect_setequal(vapply(todo, `[[`, "", "resourceType"),
                  c("Patient", "Observation", "Condition"))
  dx <- vista_ejecutar_duckdb(todo, vista_plantilla("diagnosticos"))
  expect_identical(nrow(dx), 1L)
  expect_identical(dx, vista_ejecutar(todo, vista_plantilla("diagnosticos")))
})

test_that("terminologia del servidor: $expand y $validate-code en lote", {
  con <- fhir_conectar(servidor_escritura(), panel = FALSE)
  vs <- "http://hl7.org/fhir/ValueSet/administrative-gender"
  sis <- "http://hl7.org/fhir/administrative-gender"
  exp <- tryCatch(tx_expandir(con, vs), fhirviews_error_http = function(e) NULL)
  skip_if(is.null(exp), "El servidor no expande administrative-gender")
  expect_setequal(exp$code, c("male", "female", "other", "unknown"))

  codigos <- c("female", "mujer", "male", "unknown")
  en_lote <- tx_validar_codigo(con, vs, sis, codigos)
  de_a_uno <- tx_validar_codigo(con, vs, sis, codigos, lote = FALSE)
  expect_identical(en_lote$valido, c(TRUE, FALSE, TRUE, TRUE))
  expect_identical(en_lote$valido, de_a_uno$valido)

})

test_that("terminologia con ValueSet en linea", {
  con <- fhir_conectar(servidor_escritura(), panel = FALSE)
  sis <- "http://hl7.org/fhir/administrative-gender"
  # Con el ValueSet como recurso (POST con un Parameters tipado)
  recurso <- list(resourceType = "ValueSet", url = "urn:fhirviews:vs",
                  status = "active",
                  compose = list(include = list(list(system = sis, concept = list(
                    list(code = "female"), list(code = "male"))))))
  expect_setequal(tx_expandir(con, recurso)$code, c("female", "male"))
  # HAPI no admite el parámetro valueSet en $validate-code (HAPI-0901); otros
  # servidores, como tx.fhir.org, sí
  r <- tryCatch(tx_validar_codigo(con, recurso, sis, c("female", "other")),
                fhirviews_error_http_400 = function(e) e)
  if (inherits(r, "fhirviews_error_http_400")) {
    expect_match(paste(tabla_outcome(r$outcome)$mensaje, collapse = " "),
                 "HAPI-0901")
    skip("El servidor no valida con un ValueSet en línea")
  }
  expect_identical(r$valido, c(TRUE, FALSE))
})

test_that("exportacion masiva ($export) de punta a punta", {
  con <- fhir_conectar(servidor_escritura(), panel = FALSE)
  marca <- marca_prueba()
  p <- fhir_crear(con, list(
    resourceType = "Patient",
    identifier = list(list(system = sis_prueba, value = marca)),
    gender = "female", birthDate = "1990-01-01"))
  on.exit(try(fhir_borrar(con, p), silent = TRUE), add = TRUE)

  inicio <- tryCatch(
    fhir_exportar(con, "paciente", tipos = "Patient", esperar = FALSE),
    fhirviews_error_exportacion = function(e) NULL,
    fhirviews_error_http = function(e) NULL)
  skip_if(is.null(inicio), "El servidor no admite $export")
  carpeta <- tempfile("export-")
  on.exit(unlink(carpeta, recursive = TRUE), add = TRUE)
  inicio$carpeta <- carpeta
  x <- fhir_exportar_estado(inicio, esperar = TRUE, intervalo = 1,
                            max_espera = 180, progreso = FALSE)
  expect_identical(x$estado, "completada")
  expect_true("Patient" %in% names(x$archivos))
  expect_true(all(file.exists(unlist(x$archivos))))
  r <- fhir_recursos(unlist(x$archivos))
  expect_true(p$id %in% vapply(r, `[[`, "", "id"))
  v <- vista_crear("Patient", c(sexo = "gender"))
  df <- vista_ejecutar(r, v)
  expect_identical(df$sexo[df$id == p$id], "female")
  skip_if_not_installed("duckdb", "1.3.0")
  db <- vista_ejecutar_duckdb(x$archivos$Patient, v)
  expect_identical(db[order(db$id), ], df[order(df$id), ],
                   ignore_attr = "row.names")
})
