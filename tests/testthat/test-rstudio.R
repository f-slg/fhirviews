bundle <- function(...) {
  list(resourceType = "Bundle", type = "searchset", total = length(list(...)),
       entry = lapply(list(...), function(r) list(resource = r)))
}

servidor_panel <- function(req, ruta) {
  if (ruta == "metadata") {
    return(respuesta_fhir(capacidad))
  }
  if (startsWith(ruta, "Patient")) {
    return(respuesta_fhir(bundle(
      list(resourceType = "Patient", id = "p1", gender = "female",
           name = list(list(family = "Paredes", given = list("Ana")))),
      list(resourceType = "Patient", id = "p2", birthDate = "2001-11-30"))))
  }
  respuesta_fhir(bundle())
}

test_that("analizar_peticion entiende el formato de Postman y .http", {
  p <- analizar_peticion("Patient?family=Paredes")
  expect_identical(p[c("metodo", "ruta")],
                   list(metodo = "GET", ruta = "Patient?family=Paredes"))
  expect_null(p$cuerpo)

  p <- analizar_peticion(c(
    "# comentario",
    "",
    "post Patient/$validate HTTP/1.1",
    "Prefer: return=OperationOutcome",
    "X-Otra:valor",
    "",
    '{"resourceType": "Patient",',
    ' "gender": "female"}'
  ))
  expect_identical(p$metodo, "POST")
  expect_identical(p$ruta, "Patient/$validate")
  expect_identical(p$cabeceras,
                   list(Prefer = "return=OperationOutcome", `X-Otra` = "valor"))
  expect_identical(jsonlite::fromJSON(p$cuerpo)$gender, "female")

  p <- analizar_peticion('PUT Patient/p1\n{"resourceType": "Patient"}')
  expect_match(p$cuerpo, "^\\{")
  expect_error(analizar_peticion("// nada\n\n"), class = "fhirviews_error")
})

test_that("conexion activa, fhir_ejecutar_texto y fhir_vista", {
  simular(servidor_panel)
  con <- fhir_conectar(base, panel = FALSE)
  expect_identical(fhir_conexion_activa()$url, base)

  r <- fhir_ejecutar_texto("GET Patient?gender=female")
  expect_s3_class(r, "fhir_respuesta")
  expect_identical(attr(r, "estado"), 200L)
  expect_output(print(r), "<fhir_respuesta> 200 . Bundle \\(searchset, total 2")
  expect_length(fhir_recursos(r), 2L)
  expect_false(is.null(attr(fhir_recursos(r), "fuente")))

  df <- fhir_vista(con, vista_crear("Patient", c(sexo = "gender")),
                   progreso = FALSE)
  expect_identical(df$sexo, c("female", NA))

  fhir_desconectar(con)
  expect_error(fhir_conexion_activa(), class = "fhirviews_error")
  expect_error(fhir_ejecutar_texto("GET Patient"), class = "fhirviews_error")
})

test_that("el token solo viaja al servidor de la conexion", {
  p <- simular(function(req, ruta) respuesta_fhir(bundle()))
  con <- fhir_conectar(base, token = "secreto", verificar = FALSE,
                       panel = FALSE)
  fhir_peticion(con, "GET", "Patient")
  fhir_peticion(con, "GET", "http://otro.test/fhir/Patient")
  cab <- lapply(p$lista, function(r) httr2::req_get_headers(r, "reveal"))
  expect_identical(cab[[1]]$Authorization, "Bearer secreto")
  expect_null(cab[[2]]$Authorization)
  fhir_desconectar(con)
})

test_that("registra el servidor en el panel Connections", {
  simular(servidor_panel)
  eventos <- new.env()
  observador <- list(
    connectionOpened = function(...) eventos$abierta <- list(...),
    connectionClosed = function(type, host) eventos$cerrada <- host,
    connectionUpdated = function(...) NULL
  )
  viejo <- options(connectionObserver = observador)
  on.exit(options(viejo), add = TRUE)

  con <- fhir_conectar(base, token = "secreto")
  a <- eventos$abierta
  expect_identical(a$type, "FHIR")
  expect_identical(a$host, base)
  expect_true(file.exists(a$icon))
  expect_match(a$connectCode, "fhir_conectar\\(\"https://fhir.test/fhir\"")
  expect_match(a$connectCode, "Sys.getenv")
  expect_false(grepl("secreto", a$connectCode))
  expect_identical(a$listObjectTypes()$recurso$contains, "data")

  objetos <- a$listObjects()
  expect_identical(objetos$name, "Patient")
  expect_identical(objetos$type, "recurso")
  columnas <- a$listColumns(recurso = "Patient")
  expect_identical(columnas$name,
                   c("resourceType", "id", "gender", "name", "birthDate"))
  previa <- a$previewObject(rowLimit = 1, recurso = "Patient")
  expect_identical(nrow(previa), 1L)
  expect_named(a$actions, c("Capacidades", "Abrir metadata"))

  a$disconnect()
  expect_identical(eventos$cerrada, base)
})

test_that("fhir_tabla aplana los recursos", {
  tabla <- fhir_tabla(list(
    list(resourceType = "Patient", id = "p1", gender = "female",
         text = list(div = "<div/>"),
         name = list(list(family = "Paredes", given = list("Ana"))),
         alias = list("a", "b")),
    list(resourceType = "Observation", id = "o1", status = "final")
  ))
  expect_identical(names(tabla),
                   c("resourceType", "id", "gender", "name", "alias", "status"))
  expect_identical(tabla$alias, c("a; b", NA))
  expect_match(tabla$name[1], '"family":"Paredes"', fixed = TRUE)
  expect_identical(nrow(fhir_tabla(list(), tipo = "Patient")), 0L)
  corta <- fhir_tabla(list(list(resourceType = "Patient", id = "p",
                                name = list(list(family = strrep("x", 50))))),
                      max_caracteres = 20)
  expect_identical(nchar(corta$name), 20L)
})

test_that("los addins generan codigo valido", {
  texto <- 'POST Patient\n\n{"resourceType": "Patient", "name": [{"text": "O\'Neil"}]}'
  codigo <- codigo_addin_peticion(texto)
  expresion <- parse(text = codigo[1])[[1]]
  expect_identical(eval(expresion[[3]][[2]]), texto)
  expect_identical(codigo[2], "fhir_respuesta")

  viejo <- options(fhirviews.addin_paginas = 2)
  on.exit(options(viejo), add = TRUE)
  codigo <- codigo_addin_vista("vista.json")
  expect_match(codigo[1], 'fhir_vista\\(fhir_conexion_activa\\(\\), "vista.json", max_paginas = 2\\)')
  expect_identical(codigo[2], "View(fhir_tabla_vista)")
  expect_error(addin_peticion(), class = "fhirviews_error")
})
