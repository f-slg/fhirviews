# Regresiones de la auditoría técnica (errores A1-A3, problemas M1-M6)

paciente_r <- list(resourceType = "Patient", id = "p1", gender = "female")

test_that("A1: un enlace next repetido no produce un bucle infinito", {
  p <- simular(function(req, ruta) {
    respuesta_fhir(list(
      resourceType = "Bundle", type = "searchset",
      link = list(list(relation = "next", url = paste0(base, "/Patient?p=2"))),
      entry = list(list(resource = paciente("x")))))
  })
  con <- con_simulada(panel = FALSE)
  expect_warning(r <- fhir_buscar(con, "Patient", progreso = FALSE),
                 class = "fhirviews_aviso")
  expect_length(r, 2L)
  expect_length(p$lista, 2L)
})

test_that("A2: un Bundle transaction o batch se env\u00eda a la base", {
  p <- simular(function(req, ruta) {
    respuesta_fhir(list(resourceType = "Bundle", type = "transaction-response",
                        entry = list(list(response = list(status = "201 Created")))))
  })
  con <- fhir_conectar(base, token = "t", verificar = FALSE, panel = FALSE)
  for (tipo in c("transaction", "batch")) {
    r <- fhir_crear(con, list(resourceType = "Bundle", type = tipo,
                              entry = list()))
    req <- p$lista[[length(p$lista)]]
    expect_identical(req$method, "POST")
    expect_identical(req$url, base)
    expect_identical(httr2::req_get_headers(req, "reveal")$Authorization,
                     "Bearer t")
    expect_identical(r$type, "transaction-response")
  }
  # Un Bundle de otro tipo (por ejemplo collection) se guarda como recurso
  fhir_crear(con, list(resourceType = "Bundle", type = "collection"))
  expect_match(p$lista[[length(p$lista)]]$url, "/Bundle$")
  fhir_desconectar(con)
})

test_that("A3: el validador rechaza column, select y unionAll vac\u00edos", {
  base_vista <- function(...) list(resource = "Patient", select = list(list(...)))
  col <- list(list(name = "id", path = "id"))
  for (v in list(base_vista(column = col, unionAll = list()),
                 base_vista(column = list()),
                 base_vista(column = col, select = list()))) {
    e <- expect_error(vista_validar(v), class = "fhirviews_error_vista")
    expect_true(any(grepl("al menos un elemento", e$problemas)))
  }
  expect_error(vista_ejecutar(paciente_r, base_vista(column = col,
                                                      unionAll = list())),
               class = "fhirviews_error_vista")
})

test_that("M1: las constantes no pueden usar nombres reservados", {
  for (nombre in c("resource", "rootResource", "rowIndex", "context")) {
    v <- list(resource = "Patient",
              constant = list(list(name = nombre, valueString = "x")),
              select = list(list(column = list(list(name = "id", path = "id")))))
    e <- expect_error(vista_validar(v), class = "fhirviews_error_vista")
    expect_true(any(grepl("reservado", e$problemas)))
  }
})

test_that("M2: con tipos mezclados se aprovecha el JSON original", {
  json <- c('{"resourceType": "Patient", "id": "p1", "gender": "female"}',
            '{"resourceType": "Observation", "id": "o1", "status": "final"}',
            '{"resourceType": "Patient", "id": "p2", "gender": "male"}')
  r <- fhir_recursos(json)
  v <- vista_crear("Patient", c(sexo = "gender"))
  m <- motor_actual()
  llamadas <- 0L
  original <- m$cargar
  m$cargar <- function(recursos) {
    if (is.null(attr(recursos, "fuente"))) llamadas <<- llamadas + 1L
    original(recursos)
  }
  .fhirviews$motores$v8 <- m
  on.exit(.fhirviews$motores$v8$cargar <- original, add = TRUE)
  df <- vista_ejecutar(r, v)
  expect_identical(df$id, c("p1", "p2"))
  expect_identical(df$sexo, c("female", "male"))
  expect_identical(llamadas, 0L)
  expect_identical(vista_ejecutar(unclass(r), v), df)
})

test_that("M3: type no trunca ni convierte en NA en silencio", {
  obs <- list(resourceType = "Observation", id = "o",
              valueQuantity = list(value = 1.7), valueString = "si")
  v <- function(path, tipo) {
    list(resource = "Observation", select = list(list(column = list(
      list(name = "v", path = path, type = tipo)))))
  }
  expect_warning(df <- vista_ejecutar(obs, v("value.ofType(Quantity).value",
                                             "integer")),
                 class = "fhirviews_aviso_tipo")
  expect_identical(df$v, 1.7)
  expect_warning(df <- vista_ejecutar(list(resourceType = "Observation",
                                           id = "o", valueString = "si"),
                                      v("value.ofType(string)", "boolean")),
                 class = "fhirviews_aviso_tipo")
  expect_identical(df$v, "si")
  entero <- list(resourceType = "Observation", id = "o",
                 valueQuantity = list(value = 3))
  expect_identical(vista_ejecutar(entero, v("value.ofType(Quantity).value",
                                            "integer"))$v, 3L)
})

test_that("M4: las columnas vac\u00edas sin type toman el tipo del modelo FHIR", {
  v <- vista_crear("Patient", c(
    nacimiento = "birthDate", activo = "active",
    partos = "multipleBirth.ofType(integer)",
    nombre = "name.where(use = 'official').family",
    vivo = "deceased.exists().not()"
  ))
  df <- vista_ejecutar(paciente_r, v)
  expect_type(df$nacimiento, "character")
  expect_type(df$activo, "logical")
  expect_type(df$partos, "integer")
  expect_type(df$nombre, "character")
  # Sin filas también
  vacio <- vista_ejecutar(list(), v)
  expect_identical(vacio$nacimiento, character())
  expect_identical(vacio$partos, integer())
  # Dentro de forEach y repeat
  qr <- list(resourceType = "QuestionnaireResponse", id = "q",
             item = list(list(item = list(list()))))
  df <- vista_ejecutar(qr, list(resource = "QuestionnaireResponse", select = list(
    list(`repeat` = list("item"), column = list(list(name = "link", path = "linkId"))))))
  expect_identical(df$link, c(NA_character_, NA_character_))
  m <- motor_actual()
  ctx <- list(tipo = "Observation", ruta = "Observation")
  expect_identical(m$tipo(ctx, "component.value.ofType(Quantity).value")$tipo,
                   "decimal")
  expect_null(m$tipo(ctx, "value"))
  expect_null(m$tipo(ctx, "status = 'final' and subject.exists()"))
})

test_that("M5: avisa si el token viajar\u00eda por http", {
  expect_warning(fhir_conectar("http://ejemplo.org/fhir", token = "t",
                               verificar = FALSE, panel = FALSE),
                 class = "fhirviews_aviso_seguridad")
  for (url in c("http://localhost:8080/fhir", "http://127.0.0.1/fhir",
                "https://ejemplo.org/fhir")) {
    expect_no_warning(fhir_conectar(url, token = "t", verificar = FALSE,
                                    panel = FALSE))
  }
  expect_no_warning(fhir_conectar("http://ejemplo.org/fhir",
                                  verificar = FALSE, panel = FALSE))
})

test_that("M6: rutas de archivo inexistentes, varias y vac\u00edas", {
  e <- expect_error(fhir_recursos("no/existe/pacientes.ndjson"),
                    class = "fhirviews_error")
  expect_match(conditionMessage(e), "No se encontr")
  a <- withr_tempfile(".ndjson")
  b <- withr_tempfile(".json")
  vacio <- withr_tempfile(".json")
  writeLines(c('{"resourceType": "Patient", "id": "a1"}',
               '{"resourceType": "Patient", "id": "a2"}'), a)
  writeLines('{"resourceType": "Bundle", "entry": [{"resource":
              {"resourceType": "Patient", "id": "b1"}}]}', b)
  file.create(vacio)
  r <- fhir_recursos(c(a, b, vacio))
  expect_identical(vapply(r, `[[`, "", "id"), c("a1", "a2", "b1"))
  expect_false(is.null(attr(r, "fuente")))
  expect_identical(vista_ejecutar(r, vista_crear("Patient", c(n = "1")))$id,
                   c("a1", "a2", "b1"))
  expect_error(fhir_recursos(c(a, '{"resourceType": "Patient"}')),
               class = "fhirviews_error")
})
