mapa_paciente <- function() fhir_mapa("Patient", c(
  id = "id", gender = "sexo", birthDate = "fecha", "name[0].family" = "apellido",
  "name[0].given[]" = "nombres"), constantes = list(active = TRUE))

test_that("construye pacientes, colecciones y omite ausentes", {
  d <- data.frame(id = 1:2, sexo = c("female", NA), fecha = as.Date(c("2000-02-29", NA)),
                   apellido = c("Paredes", ""))
  d$nombres <- list(c("Ana", "Lucia"), character())
  r <- fhir_desde_tabla(d, mapa_paciente())
  expect_s3_class(r, "fhir_recursos")
  expect_identical(r[[1]]$id, "1")
  expect_identical(r[[1]]$name[[1]]$given, list("Ana", "Lucia"))
  expect_identical(r[[1]]$birthDate, "2000-02-29")
  expect_null(r[[2]]$name)
  expect_null(r[[2]]$gender)
  expect_null(r[[2]]$birthDate)
  expect_true(r[[2]]$active)
  expect_length(fhir_desde_tabla(d[FALSE, ], mapa_paciente()), 0)
  simples <- fhir_desde_tabla(data.frame(id = I("p1"), activo = I(TRUE)),
    fhir_mapa("Patient", c(id = "id", active = "activo")))
  expect_identical(simples[[1]]$id, "p1")
  expect_true(simples[[1]]$active)
})

test_that("los mapeos rechazan destinos inexistentes o ambiguos", {
  malo <- function(...) expect_error(fhir_mapa(...), class = "fhirviews_error_mapeo")
  malo("Foo", c(id = "id"))
  malo("Patient", c(gender = "s"))
  malo("Patient", c(id = "id", familia = "a"))
  malo("Patient", c(id = "id", "gender." = "a"))
  malo("Patient", c(id = "id", "name.family" = "a"))
  malo("Patient", c(id = "id", "gender[0]" = "s"))
  malo("Patient", c(id = "id", "name[0]" = "n"))
  malo("Patient", c(id = "id", "contained[0].id" = "n"))
  malo("Patient", c(id = "id", "name[].family" = "n"))
  malo("Patient", c(id = "id", "name[0].given[]" = "a", "name[0].given[0]" = "b"))
  malo("Patient", c(id = "id", "name[0].given[0]" = "a", "name[00].given[00]" = "b"))
  malo("Patient", c(id = "id"), constantes = list(id = "p1"))
  malo("Patient", c(id = "id"), referencias = c(id = "Patient"))
  expect_error(fhir_desde_tabla(data.frame(id = "p1"), mapa_paciente()),
               "Faltan columnas", class = "fhirviews_error_mapeo")
})

test_that("valida tipos, codigos, fechas y duplicados sin coerciones silenciosas", {
  probar <- function(campo, valores, recurso = "Patient", constantes = list()) {
    m <- fhir_mapa(recurso, stats::setNames(c("id", "x"), c("id", campo)), constantes)
    for (x in valores) expect_error(fhir_desde_tabla(data.frame(id = "p1", x = I(list(x))), m),
                                    class = "fhirviews_error_mapeo")
  }
  probar("gender", list("mujer", 1))
  probar("active", list("true", 1))
  probar("birthDate", list("2023-02-29", "2024-13", "0000", "ayer"))
  probar("multipleBirthInteger", list(1.2, Inf, 2147483648))
  probar("valueQuantity.value", list(Inf, NaN, "NaN", "1,00", "01.0"), "Observation",
         list(status = "final", "code.text" = "Medicion"))
  m <- fhir_mapa("Patient", c(id = "id"))
  expect_error(fhir_desde_tabla(data.frame(id = c("p1", "p1")), m), "unico")
  expect_error(fhir_desde_tabla(data.frame(id = NA_character_), m), "id")
  expect_error(fhir_desde_tabla(data.frame(id = "con espacio"), m), "Identificador")
})

test_that("Observation conserva decimales y referencias y exige obligatorios", {
  m <- fhir_mapa("Observation", c(id = "id", "subject.reference" = "paciente",
    "valueQuantity.value" = "valor", effectiveDateTime = "fecha"),
    constantes = list(status = "final", "code.text" = "Glucosa", "valueQuantity.unit" = "mg/dL"),
    referencias = c("subject.reference" = "Patient"))
  d <- data.frame(id = "o1", paciente = "p1", valor = "1.00", fecha = "2024-02-29T10:00:00-05:00")
  r <- fhir_desde_tabla(d, m)
  expect_identical(r[[1]]$subject$reference, "Patient/p1")
  expect_match(attr(r, "fuente"), '"value":1.00', fixed = TRUE)
  expect_equal(vista_fhirpath(r, "value.ofType(Quantity).value.lowBoundary()"), 0.995)
  # La cardinalidad debe proceder de Quantity base, no del perfil SimpleQuantity.
  comparador <- fhir_mapa("Observation", c(id = "id", "valueQuantity.comparator" = "c"),
                          constantes = list(status = "final", "code.text" = "Glucosa"))
  expect_identical(fhir_desde_tabla(data.frame(id = "o1", c = "<"), comparador)[[1]]$valueQuantity$comparator, "<")
  for (formato in c("json", "ndjson")) {
    archivo <- withr_tempfile()
    fhir_escribir(r, archivo, formato)
    expect_equal(vista_fhirpath(fhir_recursos(archivo),
                                "value.ofType(Quantity).value.highBoundary()"), 1.005)
  }
  for (constantes in list(list(), list(status = "final"), list(status = "foo", "code.text" = "x"))) {
    expect_error(fhir_desde_tabla(data.frame(id = "o1"),
      fhir_mapa("Observation", c(id = "id"), constantes)), class = "fhirviews_error_mapeo")
  }
  eleccion <- fhir_mapa("Patient", c(id = "id", deceasedBoolean = "b", deceasedDateTime = "f"))
  expect_error(fhir_desde_tabla(data.frame(id = "p1", b = TRUE, f = "2024"), eleccion), "eleccion")
  expect_error(fhir_desde_tabla(transform(d, paciente = "Patient/p1"), m), "clave")
  expect_error(fhir_desde_tabla(transform(d, fecha = "2024-01-01T12:00:00"), m), "Fecha")
  d$fecha <- as.POSIXct("2024-01-01 12:00:00", tz = "UTC")
  expect_identical(fhir_desde_tabla(d, m)[[1]]$effectiveDateTime, "2024-01-01T12:00:00.000000Z")
  d$fecha <- as.POSIXlt(d$fecha)
  expect_identical(fhir_desde_tabla(d, m)[[1]]$effectiveDateTime, "2024-01-01T12:00:00.000000Z")
})

test_that("SQL con parametros funciona en dos controladores DBI", {
  skip_if_not_installed("DBI")
  drivers <- list()
  if (requireNamespace("RSQLite", quietly = TRUE)) drivers$sqlite <- RSQLite::SQLite()
  if (requireNamespace("duckdb", quietly = TRUE)) {
    args <- if ("shared_home" %in% names(formals(duckdb::duckdb))) list(shared_home = FALSE) else list()
    drivers$duckdb <- do.call(duckdb::duckdb, args)
  }
  for (driver in drivers) {
    con <- DBI::dbConnect(driver)
    tryCatch({
      d <- data.frame(id = c("p1", "p2"), sexo = c("female", "male"))
      DBI::dbWriteTable(con, "pacientes", d)
      m <- fhir_mapa("Patient", c(id = "id", gender = "sexo"))
      r <- fhir_desde_sql(con, "SELECT * FROM pacientes WHERE id = ?", m, list("p1"))
      expect_length(r, 1)
      expect_identical(r[[1]]$id, "p1")
      expect_identical(vista_ejecutar(r, vista_crear("Patient", c(sexo = "gender"))), d[1, ])
      expect_equal(DBI::dbGetQuery(con, "SELECT count(*) AS n FROM pacientes")$n, 2)
    }, finally = DBI::dbDisconnect(con))
  }
})

test_that("Encounter comprueba obligatorios y codigos tambien en elementos anidados", {
  m <- fhir_mapa("Encounter", c(id = "id", status = "estado", "class.code" = "clase",
    "subject.reference" = "paciente", "period.start" = "inicio"),
    constantes = list("class.system" = "http://terminology.hl7.org/CodeSystem/v3-ActCode"),
    referencias = c("subject.reference" = "Patient"))
  d <- data.frame(id = "e1", estado = "finished", clase = "AMB", paciente = "p1", inicio = "2026-01-14T10:00:00-05:00")
  r <- fhir_desde_tabla(d, m)
  expect_identical(r[[1]]$class$code, "AMB")
  expect_identical(r[[1]]$subject$reference, "Patient/p1")
  expect_identical(r[[1]]$period$start, d$inicio)
  expect_error(fhir_desde_tabla(transform(d, estado = "inexistente"), m), "ValueSet requerido")
  expect_error(fhir_desde_tabla(transform(d, estado = NA_character_), m), "obligatorio")
  expect_error(fhir_desde_tabla(data.frame(id = "e1"),
    fhir_mapa("Encounter", c(id = "id"), constantes = list(status = "finished"))), "obligatorio")
  historia <- fhir_mapa("Encounter", c(id = "id"), constantes = list(status = "finished",
    "class.code" = "AMB", "statusHistory[0].status" = "inexistente",
    "statusHistory[0].period.start" = "2026-01-01"))
  expect_error(fhir_desde_tabla(data.frame(id = "e1"), historia), "ValueSet requerido")
  # La clase tiene binding extensible, no una enumeracion cerrada.
  local <- m
  local$constantes[["class.system"]] <- "https://example.org/clases"
  expect_identical(fhir_desde_tabla(transform(d, clase = "local"), local)[[1]]$class$code, "local")
  expect_error(fhir_desde_tabla(data.frame(id = "p1", uso = "inexistente"),
    fhir_mapa("Patient", c(id = "id", "name[0].use" = "uso"))), "ValueSet requerido")
})

test_that("Condition valida pares system/code, traducciones y elecciones", {
  cs <- "http://terminology.hl7.org/CodeSystem/condition-clinical"
  vs <- "http://terminology.hl7.org/CodeSystem/condition-ver-status"
  m <- fhir_mapa("Condition", c(id = "id", "subject.reference" = "paciente",
    "encounter.reference" = "encuentro", "clinicalStatus.coding[0].code" = "estado",
    onsetDateTime = "inicio"), constantes = list("clinicalStatus.coding[0].system" = cs,
      "verificationStatus.coding[0].system" = vs, "verificationStatus.coding[0].code" = "confirmed",
      "code.text" = "Diagnostico ficticio"),
    referencias = c("subject.reference" = "Patient", "encounter.reference" = "Encounter"))
  d <- data.frame(id = "c1", paciente = "p1", encuentro = "e1", estado = "active", inicio = "2026-01-14")
  r <- fhir_desde_tabla(d, m)
  expect_identical(r[[1]]$encounter$reference, "Encounter/e1")
  expect_identical(r[[1]]$clinicalStatus$coding[[1]]$code, "active")
  for (estado in c("inexistente", "ACTIVE")) {
    invalido <- d
    invalido$estado <- estado
    expect_error(fhir_desde_tabla(invalido, m), "ValueSet requerido")
  }
  incorrecto <- m
  incorrecto$constantes[["clinicalStatus.coding[0].system"]] <- "https://example.org/estados"
  expect_error(fhir_desde_tabla(d, incorrecto), "system/code")
  expect_error(fhir_desde_tabla(data.frame(id = "c1"), fhir_mapa("Condition", c(id = "id"),
    constantes = list("subject.reference" = "Patient/p1", "clinicalStatus.text" = "activo"))), "Coding")
  expect_error(fhir_desde_tabla(data.frame(id = "c1"),
    fhir_mapa("Condition", c(id = "id"))), "obligatorio")
  ambos <- fhir_mapa("Condition", c(id = "id"), constantes = list(
    "subject.reference" = "Patient/p1", onsetDateTime = "2026", "onsetAge.value" = "1"))
  expect_error(fhir_desde_tabla(data.frame(id = "c1"), ambos), "eleccion")
  # Se permite una traduccion adicional cuando hay al menos un codigo del ValueSet.
  traduccion <- fhir_mapa("Condition", c(id = "id"), constantes = list(
    "subject.reference" = "Patient/p1", "clinicalStatus.coding[0].system" = "https://example.org/local",
    "clinicalStatus.coding[0].code" = "activo", "clinicalStatus.coding[1].system" = cs,
    "clinicalStatus.coding[1].code" = "active"))
  expect_length(fhir_desde_tabla(data.frame(id = "c1"), traduccion)[[1]]$clinicalStatus$coding, 2L)
})

test_that("las referencias comprueban destinos R4 declarados y literales", {
  expect_error(fhir_mapa("Condition", c(id = "id", "encounter.reference" = "encuentro"),
    referencias = c("encounter.reference" = "Observation")), "destino FHIR permitido")
  expect_error(fhir_mapa("Patient", c(id = "id", "generalPractitioner[0].reference" = "profesional"),
    referencias = c("generalPractitioner[0].reference" = "Observation")), "destino FHIR permitido")
  m <- fhir_mapa("Condition", c(id = "id", "subject.reference" = "referencia"))
  for (r in c("Observation/o1", "https://fhir.example.org/Observation/o1", "p1", "#p1")) {
    expect_error(fhir_desde_tabla(data.frame(id = "c1", referencia = r), m), class = "fhirviews_error_mapeo")
  }
  expect_identical(fhir_desde_tabla(data.frame(id = "c1", referencia = "Group/g1"), m)[[1]]$subject$reference, "Group/g1")
  expect_identical(fhir_desde_tabla(data.frame(id = "c1", referencia = "https://fhir.example.org/Patient/p1/_history/2"), m)[[1]]$subject$reference,
    "https://fhir.example.org/Patient/p1/_history/2")
  tipo <- fhir_mapa("Condition", c(id = "id"), constantes = list(
    "subject.reference" = "Patient/p1", "subject.type" = "Group"))
  expect_error(fhir_desde_tabla(data.frame(id = "c1"), tipo), "no coincide")
  # Los destinos pueden ser recursos referenciados que el constructor aun no ofrece.
  profesional <- fhir_mapa("Patient", c(id = "id", "generalPractitioner[0].reference" = "profesional"),
    referencias = c("generalPractitioner[0].reference" = "Practitioner"))
  expect_identical(fhir_desde_tabla(data.frame(id = "p1", profesional = "pr1"), profesional)[[1]]$generalPractitioner[[1]]$reference,
    "Practitioner/pr1")
})
