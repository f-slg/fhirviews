# Pruebas del cliente con respuestas simuladas (sin red)

test_that("fhir_conectar verifica el servidor y oculta el token", {
  simular(function(req, ruta) respuesta_fhir(capacidad))
  con <- fhir_conectar(paste0(base, "/"), token = "secreto")
  expect_s3_class(con, "fhir_conexion")
  expect_identical(con$url, base)
  expect_identical(con$version_fhir, "4.0.1")
  expect_match(con$servidor, "Servidor de prueba")
  salida <- capture.output(print(con))
  expect_false(any(grepl("secreto", salida)))
  expect_true(any(grepl("oculto", salida)))
  expect_error(fhir_conectar("fhir.test"), class = "fhirviews_error")
  expect_error(fhir_buscar(list(), "Patient"), class = "fhirviews_error")
})

test_that("las peticiones llevan las cabeceras FHIR y el token", {
  p <- simular(function(req, ruta) respuesta_fhir(paciente("p1")))
  con <- con_simulada(token = "abc", cabeceras = list(`X-Prueba` = "1"))
  fhir_leer(con, "Patient", "p1")
  req <- p$lista[[1]]
  expect_identical(req$headers$Accept, "application/fhir+json")
  expect_identical(req$headers$`X-Prueba`, "1")
  expect_match(httr2::req_get_headers(req, "reveal")$Authorization,
               "Bearer abc")
  expect_match(req$options$useragent, "^fhirviews/")
})

test_that("fhir_buscar sigue los enlaces next", {
  p <- simular(function(req, ruta) {
    if (grepl("pagina=2", ruta)) {
      respuesta_fhir(list(resourceType = "Bundle", type = "searchset",
                          entry = list(list(resource = paciente("p3")))))
    } else {
      respuesta_fhir(list(
        resourceType = "Bundle", type = "searchset", total = 3,
        link = list(list(relation = "self", url = paste0(base, "/Patient")),
                    list(relation = "next",
                         url = paste0(base, "?_getpages=x&pagina=2"))),
        entry = list(list(resource = paciente("p1")),
                     list(resource = paciente("p2")))))
    }
  })
  con <- con_simulada()
  r <- fhir_buscar(con, "Patient", family = "Paredes",
                   code = c("a", "b"), birthdate = as.Date("2000-01-02"),
                   active = TRUE, parametros = list(`subject:Patient` = "p9"),
                   progreso = FALSE)
  expect_s3_class(r, "fhir_recursos")
  expect_identical(vapply(r, `[[`, "", "id"), c("p1", "p2", "p3"))
  expect_identical(attr(r, "total"), 3L)
  expect_length(attr(r, "fuente"), 2L)
  url <- p$lista[[1]]$url
  expect_match(url, "Patient\\?family=Paredes&code=a&code=b")
  expect_match(url, "birthdate=2000-01-02&active=true")
  expect_match(url, "subject%3APatient=p9")

  # El texto original sirve para ejecutar vistas
  df <- vista_ejecutar(r, vista_crear("Patient", c(n = "1")))
  expect_identical(df$id, c("p1", "p2", "p3"))

  r1 <- fhir_buscar(con, "Patient", max_paginas = 1, progreso = FALSE)
  expect_length(r1, 2L)
  expect_error(fhir_buscar(con, "Patient", "sin-nombre"),
               class = "fhirviews_error")
})

test_that("fhir_buscar exige un Bundle", {
  simular(function(req, ruta) respuesta_fhir(paciente("p1")))
  expect_error(fhir_buscar(con_simulada(), "Patient", progreso = FALSE),
               class = "fhirviews_error")
})

test_that("fhir_leer y fhir_everything arman la ruta", {
  p <- simular(function(req, ruta) {
    if (grepl("everything", ruta)) {
      respuesta_fhir(list(resourceType = "Bundle", type = "searchset",
                          entry = list(list(resource = paciente("p1")))))
    } else {
      respuesta_fhir(paciente("p1"))
    }
  })
  con <- con_simulada()
  expect_identical(fhir_leer(con, "Patient/p1")$id, "p1")
  fhir_leer(con, "Patient", "p1", version = "2")
  expect_match(p$lista[[2]]$url, "Patient/p1/_history/2$")
  expect_error(fhir_leer(con, "Patient"), class = "fhirviews_error")
  todo <- fhir_everything(con, "Patient", "p1", progreso = FALSE)
  expect_length(todo, 1L)
  expect_match(p$lista[[3]]$url, "Patient/p1/\\$everything$")
})

test_that("los errores muestran el OperationOutcome", {
  simular(function(req, ruta) {
    respuesta_fhir(oo("No existe {Patient/x}"), estado = 404L)
  })
  e <- tryCatch(fhir_leer(con_simulada(), "Patient", "x"),
                error = function(e) e)
  expect_s3_class(e, "fhirviews_error_http_404")
  expect_s3_class(e, "fhirviews_error_http")
  expect_identical(e$estado, 404L)
  expect_identical(e$outcome$resourceType, "OperationOutcome")
  mensaje <- cli::ansi_strip(conditionMessage(e))
  expect_match(mensaje, "404")
  expect_match(mensaje, "No existe {Patient/x}", fixed = TRUE)
  expect_match(mensaje, "Patient.gender", fixed = TRUE)
})

test_that("errores sin OperationOutcome y respuestas que no son JSON", {
  simular(function(req, ruta) {
    if (grepl("html", ruta)) {
      httr2::response(200L, headers = list(`Content-Type` = "text/html"),
                      body = charToRaw("<html>hola</html>"))
    } else {
      httr2::response(500L, headers = list(`Content-Type` = "text/plain"),
                      body = charToRaw("fallo interno"))
    }
  })
  con <- con_simulada()
  expect_error(fhir_leer(con, "Patient", "x"), "fallo interno",
               class = "fhirviews_error_http_500")
  expect_error(fhir_peticion(con, "GET", "html"), class = "fhirviews_error")
})

test_that("crear, actualizar y borrar", {
  p <- simular(function(req, ruta) {
    metodo <- req$method %||% "GET"
    if (metodo == "POST" && ruta == "Patient") {
      cuerpo <- jsonlite::fromJSON(cuerpo_req(req))
      respuesta_fhir(c(cuerpo, list(id = "nuevo")), estado = 201L)
    } else if (metodo == "PUT") {
      respuesta_fhir(NULL, estado = 200L,
                     cabeceras = list(Location = paste0(base,
                                                        "/Patient/p1/_history/2")))
    } else if (metodo == "DELETE") {
      respuesta_fhir(NULL, estado = 204L)
    } else {
      respuesta_fhir(c(paciente("p1"), list(meta = list(versionId = "2"))))
    }
  })
  con <- con_simulada()
  creado <- fhir_crear(con, list(resourceType = "Patient", gender = "female"))
  expect_identical(creado$id, "nuevo")
  req <- p$lista[[1]]
  expect_identical(req$method, "POST")
  expect_match(req$body$content_type, "application/fhir\\+json")
  expect_identical(req$headers$Prefer, "return=representation")

  json <- '{"resourceType": "Patient", "gender": "male"}'
  expect_identical(fhir_crear(con, json)$id, "nuevo")

  actualizado <- fhir_actualizar(con, paciente("p1"))
  expect_identical(actualizado$meta$versionId, "2")
  expect_match(p$lista[[3]]$url, "Patient/p1$")
  expect_error(fhir_actualizar(con, list(resourceType = "Patient")),
               class = "fhirviews_error")
  expect_error(fhir_crear(con, list(id = "x")), class = "fhirviews_error")

  expect_true(fhir_borrar(con, "Patient", "p1"))
  expect_true(fhir_borrar(con, paciente("p2")))
  expect_identical(p$lista[[length(p$lista)]]$method, "DELETE")
  expect_match(p$lista[[length(p$lista)]]$url, "Patient/p2$")
})

test_that("fhir_validar acepta las respuestas de error de $validate", {
  simular(function(req, ruta) {
    cuerpo <- cuerpo_req(req)
    if (grepl("mujer", cuerpo)) {
      respuesta_fhir(oo("C\u00f3digo desconocido 'mujer'"), estado = 412L)
    } else {
      respuesta_fhir(oo("Sin problemas", "information"))
    }
  })
  con <- con_simulada()
  v <- fhir_validar(con, list(resourceType = "Patient", gender = "mujer"),
                    perfil = "http://example.org/perfil")
  expect_s3_class(v, "fhir_validacion")
  expect_false(attr(v, "valido"))
  expect_identical(v$severidad, "error")
  expect_identical(v$ubicacion, "Patient.gender")
  expect_output(print(v), "No v.lido")
  v <- fhir_validar(con, list(resourceType = "Patient", gender = "female"))
  expect_true(attr(v, "valido"))
  expect_output(print(v), "V.lido")
})

test_that("fhir_capacidades y fhir_peticion", {
  simular(function(req, ruta) {
    if (ruta == "metadata") respuesta_fhir(capacidad) else
      respuesta_fhir(list(resourceType = "Bundle", total = 7))
  })
  con <- con_simulada()
  cap <- fhir_capacidades(con)
  expect_identical(cap$recurso, "Patient")
  expect_identical(cap$interacciones, "read, search-type")
  expect_identical(attr(cap, "capability")$fhirVersion, "4.0.1")
  r <- fhir_peticion(con, "get", "Patient",
                     parametros = list(`_summary` = "count"))
  expect_identical(r$total, 7L)
  expect_identical(attr(r, "estado"), 200L)
})

test_that("un servidor inalcanzable da un error de conexion", {
  expect_false(fhir_disponible("http://127.0.0.1:9", tiempo = 2))
  expect_error(fhir_conectar("http://127.0.0.1:9", tiempo = 2),
               class = "fhirviews_error_conexion")
})

test_that("las operaciones se envian con `$` sin codificar", {
  # Con req_url_query() y algunas versiones de libcurl el `$` llegaba como
  # %24 y servidores como tx.fhir.org respondian 404 (Unknown operation)
  expect_identical(
    agregar_consulta("https://x.org/r4/ValueSet/$expand",
                     list(url = "http://a.org/vs b", count = 1000,
                          activo = TRUE, nada = NULL, code = c("a|b", "\u00f1"))),
    paste0("https://x.org/r4/ValueSet/$expand?url=http%3A%2F%2Fa.org%2Fvs%20b",
           "&count=1000&activo=true&code=a%7Cb&code=%C3%B1"))
  expect_identical(agregar_consulta("https://x.org/r4/Patient?_count=5",
                                    list(family = "Le\u00f3n")),
                   "https://x.org/r4/Patient?_count=5&family=Le%C3%B3n")
  expect_identical(agregar_consulta("https://x.org/r4/metadata", list()),
                   "https://x.org/r4/metadata")

  p <- simular(function(req, ruta) respuesta_fhir(list(
    resourceType = "Bundle", type = "searchset", entry = list())))
  con <- con_simulada()
  fhir_everything(con, "Patient", "p1")
  expect_match(p$lista[[1]]$url, "/Patient/p1/$everything", fixed = TRUE)
})

test_that("los errores no muestran los valores de la busqueda", {
  expect_identical(
    url_mensaje(paste0(base, "/Patient?identifier=0102030405&_count=5")),
    paste0(base, "/Patient?identifier=***&_count=5"))
  expect_identical(url_mensaje(paste0(base, "/metadata")),
                   paste0(base, "/metadata"))
  simular(function(req, ruta) respuesta_fhir(list(
    resourceType = "OperationOutcome",
    issue = list(list(severity = "error", code = "processing",
                      diagnostics = "Fallo")))
  , estado = 500L))
  e <- tryCatch(fhir_peticion(con_simulada(), "GET",
                              "Patient?identifier=0102030405&_count=5"),
                fhirviews_error_http = function(e) e)
  expect_false(grepl("0102030405", conditionMessage(e)))
  expect_match(conditionMessage(e), "identifier=***", fixed = TRUE)
  anterior <- options(fhirviews.mostrar_consulta = TRUE)
  on.exit(options(anterior), add = TRUE)
  e <- tryCatch(fhir_peticion(con_simulada(), "GET",
                              "Patient?identifier=0102030405&_count=5"),
                fhirviews_error_http = function(e) e)
  expect_match(conditionMessage(e), "0102030405")
})

test_that("los parametros numericos no usan notacion cientifica", {
  expect_identical(parametros_busqueda(list(`_count` = 100000, v = 0.1)),
                   list(`_count` = "100000", v = "0.1"))
  expect_identical(texto_parametro(c(1e6, 2.5)), c("1000000", "2.5"))
  expect_identical(texto_parametro(as.POSIXct("2024-05-01 10:00:00",
                                              tz = "America/Guayaquil")),
                   "2024-05-01T15:00:00Z")
  expect_identical(agregar_consulta("https://x.org/r4/Patient",
                                    list(`_count` = 1e5)),
                   "https://x.org/r4/Patient?_count=100000")
})
