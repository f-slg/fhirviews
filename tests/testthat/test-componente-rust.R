test_that("el componente es explicito y sus opciones son estrictas", {
  for (x in list(NULL, NA_character_, "", c("a", "b"))) {
    expect_error(fhir_componente_rust(x), class = "fhirviews_error_componente")
  }
  for (x in list(NA, 1, c(TRUE, FALSE))) {
    expect_error(fhir_componente_rust("no-existe", fallback = x), class = "fhirviews_error_componente")
  }
  for (x in list(NA_real_, 0, Inf, 1.5, 3601)) {
    expect_error(fhir_componente_rust("no-existe", tiempo = x), class = "fhirviews_error_componente")
  }
  m <- fhir_mapa("Patient", c(id = "id"))
  expect_error(fhir_desde_tabla(data.frame(id = character()), m, componente = list()),
    class = "fhirviews_error_componente")
  componente <- fhir_componente_rust(tempfile(), fallback = FALSE)
  expect_length(fhir_desde_tabla(data.frame(id = character()), m, componente), 0)
})

test_that("los destinos del componente coinciden con el modelo R4 usado por R", {
  tipos <- unlist(esquema_mapeo()$recursos_r4, use.names = FALSE)
  expect_true("Resource" %in% tipos)
  expect_identical(anyDuplicated(tipos), 0L)
  expect_true(all(vapply(tipos, function(t) isTRUE(motor_actual()$es_recurso(t)), logical(1))))
})

test_that("el respaldo R avisa y no oculta los errores de los datos", {
  d <- data.frame(id = "p1", sexo = "female")
  m <- fhir_mapa("Patient", c(id = "id", gender = "sexo"))
  esperado <- fhir_desde_tabla(d, m)
  componente <- fhir_componente_rust(tempfile())
  expect_warning(actual <- fhir_desde_tabla(d, m, componente), class = "fhirviews_aviso_componente")
  expect_identical(actual, esperado)
  componente$fallback <- FALSE
  expect_error(fhir_desde_tabla(d, m, componente), class = "fhirviews_error_componente")
  componente$fallback <- TRUE
  d$sexo <- "invalido"
  esperado <- firma_error_mapeo(function() fhir_desde_tabla(d, m))
  expect_warning(actual <- firma_error_mapeo(function() fhir_desde_tabla(d, m, componente)),
    class = "fhirviews_aviso_componente")
  expect_identical(actual, esperado)
})

test_that("el contrato rechaza respuestas incompletas, esquemas y conteos distintos", {
  binario <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
  componente <- fhir_componente_rust(binario, fallback = FALSE)
  m <- fhir_mapa("Patient", c(id = "id"))
  capacidad <- list(contrato = "fhirviews-r4-validator/1", version_fhir = "4.0.1",
    componente = "fhirviews-rust-validator", alcance = "recursos-construidos-y-tipados-por-r")
  respuesta <- list(contrato = capacidad$contrato, version_fhir = "4.0.1",
    esquema_id = plan_componente_rust()$esquema_id,
    resultado = list(valido = TRUE, recursos = 1L, error = NULL))
  mala <- respuesta
  testthat::local_mocked_bindings(proceso_componente_rust = function(componente, argumentos, carpeta) {
    if (identical(argumentos, "--capabilities")) capacidad else mala
  })
  for (caso in list(list(resultado = NULL), list(esquema_id = "otro"),
    list(resultado = list(valido = TRUE, recursos = 0)),
    list(resultado = list(valido = NA, recursos = 1)),
    list(resultado = list(valido = FALSE, recursos = 1, error = list(fila = 2, campo = "id", motivo = "x"))),
    list(resultado = list(valido = FALSE, recursos = 1, error = list(fila = 1, campo = "id", motivo = "x"))))) {
    mala <- utils::modifyList(respuesta, caso, keep.null = TRUE)
    expect_error(fhir_desde_tabla(data.frame(id = "p1"), m, componente), class = "fhirviews_error_componente")
  }
})

test_that("el componente real produce el mismo JSON y las mismas tablas para siete recursos", {
  componente <- componente_rust_pruebas()
  for (n in c(0L, 1L, 3L, 17L)) {
    c <- casos_constructor_r4(n)
    for (tipo in names(c$datos)) {
      esperado <- fhir_desde_tabla(c$datos[[tipo]], c$mapas[[tipo]])
      actual <- fhir_desde_tabla(c$datos[[tipo]], c$mapas[[tipo]], componente)
      expect_identical(actual, esperado, info = paste(tipo, n))
      if (!n) next
      for (formato in c("json", "ndjson")) {
        a <- withr_tempfile(); b <- withr_tempfile()
        fhir_escribir(esperado, a, formato); fhir_escribir(actual, b, formato)
        expect_identical(readBin(a, "raw", file.info(a)$size), readBin(b, "raw", file.info(b)$size))
      }
      columnas <- switch(tipo,
        Patient = c(sexo = "gender"),
        Encounter = c(estado = "status", paciente = "subject.getReferenceKey(Patient)"),
        Condition = c(paciente = "subject.getReferenceKey(Patient)"),
        Observation = c(valor = "valueQuantity.value", limite = "valueQuantity.value.lowBoundary()"),
        Immunization = c(fecha = "occurrence.ofType(dateTime)"),
        Specimen = c(volumen = "collection.quantity.value", limite = "collection.quantity.value.lowBoundary()"),
        DiagnosticReport = c(resultados = "result.reference.join('|')"))
      vista <- vista_crear(tipo, columnas)
      expect_identical(vista_ejecutar(actual, vista), vista_ejecutar(esperado, vista))
    }
  }
})

test_that("el ejecutable local admite rutas con espacios y limpia el transporte", {
  original <- componente_rust_pruebas()
  carpeta <- tempfile("componente con espacios "); dir.create(carpeta)
  on.exit(unlink(carpeta, recursive = TRUE))
  binario <- file.path(carpeta, paste0("validador local", if (.Platform$OS.type == "windows") ".exe" else ""))
  expect_true(file.copy(original$binario, binario, copy.mode = TRUE))
  componente <- fhir_componente_rust(binario, fallback = FALSE)
  temporales <- function() sort(list.files(tempdir(), pattern = "^fhirviews-rust-"))
  antes <- temporales()
  casos <- casos_constructor_r4(1L)
  for (i in 1:2) {
    actual <- fhir_desde_tabla(casos$datos$DiagnosticReport, casos$mapas$DiagnosticReport, componente)
    expect_identical(actual, fhir_desde_tabla(casos$datos$DiagnosticReport, casos$mapas$DiagnosticReport))
  }
  expect_identical(temporales(), antes)
  expect_true(nzchar(componente$cache$huella))
})

test_that("el componente real conserva mensajes completos y el primer error", {
  componente <- componente_rust_pruebas()
  casos <- casos_constructor_r4()
  for (tipo in names(casos$datos)) {
    d <- casos$datos[[tipo]]; m <- casos$mapas[[tipo]]
    for (ids in list(c("igual", "igual", "tercero"), c("valido", "id malo", "otro"), c("valido", NA, "otro"))) {
      d$id <- ids
      expect_identical(firma_error_mapeo(function() fhir_desde_tabla(d, m, componente)),
        firma_error_mapeo(function() fhir_desde_tabla(d, m)))
    }
  }
  for (tipo in c("Patient", "Specimen", "DiagnosticReport")) {
    d <- casos$datos[[tipo]]; m <- casos$mapas[[tipo]]
    columna <- if (tipo == "Patient") "sexo" else "estado"
    for (valor in c("invalido", NA_character_)) {
      d[[columna]][1] <- valor
      d$id[2] <- "id malo" # Un error de tipo posterior no debe ocultar la primera fila.
      expect_identical(firma_error_mapeo(function() fhir_desde_tabla(d, m, componente)),
        firma_error_mapeo(function() fhir_desde_tabla(d, m)))
    }
  }
  # La ausencia de status es valida para Specimen: ambos metodos deben llegar
  # al error primitivo posterior, sin inventar un obligatorio en la primera fila.
  d <- casos$datos$DiagnosticReport; d$resultados[[1]] <- "Specimen/s1"
  m <- casos$mapas$DiagnosticReport; m$referencias <- m$referencias[names(m$referencias) != "result[].reference"]
  expect_identical(firma_error_mapeo(function() fhir_desde_tabla(d, m, componente)),
    firma_error_mapeo(function() fhir_desde_tabla(d, m)))
})

test_that("bindings, elecciones y objetos anidados mantienen el diagnostico completo", {
  componente <- componente_rust_pruebas()
  d <- data.frame(id = "ficticio")
  casos <- list(
    list("Condition", list("subject.reference" = "Patient/p1", "clinicalStatus.text" = "Activo")),
    list("Condition", list("subject.reference" = "Patient/p1",
      "clinicalStatus.coding[0].system" = "urn:incorrecto", "clinicalStatus.coding[0].code" = "active")),
    list("Observation", list(status = "final")),
    list("Observation", list(status = "final", "code.text" = "Ficticio", "subject.type" = "Patient")),
    list("Observation", list(status = "final", "code.text" = "Ficticio",
      "subject.reference" = "Patient/p1", "subject.type" = "Group")),
    list("Specimen", list("collection.collectedDateTime" = "2026-01-14", "collection.collectedPeriod.start" = "2026-01-14")),
    list("DiagnosticReport", list(status = "final", "code.text" = "Ficticio", "media[0].comment" = "Sin link")),
    list("DiagnosticReport", list(status = "final", "code.text" = "Ficticio",
      effectiveDateTime = "2026-01-14", "effectivePeriod.start" = "2026-01-14")))
  for (caso in casos) {
    m <- fhir_mapa(caso[[1]], c(id = "id"), constantes = caso[[2]])
    expect_identical(firma_error_mapeo(function() fhir_desde_tabla(d, m, componente)),
      firma_error_mapeo(function() fhir_desde_tabla(d, m)))
  }
})

test_that("un ejecutable ajeno al protocolo falla de forma controlada", {
  binario <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
  componente <- fhir_componente_rust(binario, fallback = FALSE, tiempo = 1L)
  d <- data.frame(id = "p1"); m <- fhir_mapa("Patient", c(id = "id"))
  expect_error(fhir_desde_tabla(d, m, componente), class = "fhirviews_error_componente")
  componente$fallback <- TRUE
  expect_warning(actual <- fhir_desde_tabla(d, m, componente), class = "fhirviews_aviso_componente")
  expect_identical(actual, fhir_desde_tabla(d, m))
})

test_that("SQL parametrizado transmite el componente al constructor", {
  skip_if_not_installed("DBI")
  skip_if_not_installed("RSQLite")
  componente <- componente_rust_pruebas()
  db <- DBI::dbConnect(RSQLite::SQLite()); on.exit(DBI::dbDisconnect(db))
  DBI::dbWriteTable(db, "muestras", data.frame(id = c("s1", "s2"), estado = c("available", "unavailable")))
  m <- fhir_mapa("Specimen", c(id = "id", status = "estado"))
  actual <- fhir_desde_sql(db, "SELECT * FROM muestras WHERE id = ?", m, list("s2"), componente)
  expect_identical(actual[[1]]$id, "s2")
  expect_identical(actual, fhir_desde_tabla(data.frame(id = "s2", estado = "unavailable"), m))
})
