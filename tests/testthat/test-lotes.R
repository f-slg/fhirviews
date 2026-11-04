test_that("los bloques conservan filas, listas, orden y liberan el motor", {
  archivo <- system.file("extdata", "caso_clinico.ndjson", package = "fhirviews")
  vista <- vista_plantilla("signos_vitales")
  esperado <- vista_ejecutar(archivo, vista)
  bloques <- list()
  inicio <- motor_actual()$tamano()
  resumen <- vista_ejecutar_lotes(archivo, vista, function(tabla, bloque) {
    bloques[[bloque]] <<- tabla
  }, tamano_lote = 7)
  obtenido <- do.call(rbind, bloques)
  rownames(obtenido) <- NULL
  expect_equal(obtenido, esperado)
  expect_equal(resumen$recursos, length(fhir_recursos(archivo)))
  expect_equal(resumen$filas, nrow(esperado))
  expect_equal(resumen$bloques, length(bloques))
  expect_identical(motor_actual()$tamano(), inicio)
})

test_that("lee gzip, multiples archivos, blancos y archivos vacios", {
  a <- withr_tempfile(".ndjson.gz")
  b <- withr_tempfile(".ndjson")
  c <- gzfile(a, "wt")
  writeLines(c('', '{"resourceType":"Patient","id":"p1"}', ''), c)
  close(c)
  writeLines('{"resourceType":"Patient","id":"p2"}', b)
  ids <- character()
  v <- vista_crear("Patient", c(sexo = "gender"))
  r <- vista_ejecutar_lotes(c(a, b), v, function(tabla, bloque) {
    ids <<- c(ids, tabla$id)
  }, 1)
  expect_identical(ids, c("p1", "p2"))
  expect_equal(r$bloques, 2)
  writeLines(character(), b)
  r <- vista_ejecutar_lotes(b, v, function(...) stop("no se debe llamar"))
  expect_equal(r, list(bloques = 0, recursos = 0, filas = 0))
  expect_error(vista_ejecutar_lotes(b, v, identity, 0), class = "fhirviews_error")
  expect_error(vista_ejecutar_lotes(b, v, NULL), class = "fhirviews_error")
  writeLines('{"resourceType":"Patient","id":"p3"}', b)
  inicio <- motor_actual()$tamano()
  expect_error(vista_ejecutar_lotes(b, v, function(...) stop("fallo")), "fallo")
  expect_identical(motor_actual()$tamano(), inicio)
})

test_that("forEach y colecciones dan el mismo resultado entre bloques", {
  archivo <- withr_tempfile(".ndjson")
  writeLines(c(
    '{"resourceType":"Patient","id":"p1","name":[{"given":["Ana","Luz"]},{"given":["Eva"]}]}',
    '{"resourceType":"Patient","id":"p2","name":[{"given":["Luis"]}]}'), archivo)
  vista <- vista_leer(list(resource = "Patient", select = list(
    list(column = list(list(name = "id", path = "id"))),
    list(forEach = "name", column = list(
      list(name = "orden", path = "%rowIndex", type = "integer"),
      list(name = "dados", path = "given", collection = TRUE, type = "string"))))))
  resultados <- list()
  vista_ejecutar_lotes(archivo, vista, function(tabla, bloque) {
    resultados[[bloque]] <<- tabla
  }, 1)
  obtenido <- do.call(rbind, resultados)
  rownames(obtenido) <- NULL
  expect_identical(obtenido, vista_ejecutar(archivo, vista))
})

vista_lote_tipada <- function(tipo = "decimal", coleccion = FALSE,
                              ruta = "value.ofType(Quantity).value") {
  list(resource = "Observation", select = list(list(column = list(
    list(name = "id", path = "getResourceKey()", type = "id"),
    list(name = "valor", path = ruta, type = tipo, collection = coleccion)))))
}

archivo_lote_tipada <- function(valores) {
  archivo <- withr_tempfile(envir = parent.frame())
  writeLines(vapply(seq_along(valores), function(i) {
    as.character(jsonlite::toJSON(list(resourceType = "Observation",
      id = paste0("o", i), valueQuantity = list(value = valores[[i]])),
      auto_unbox = TRUE, null = "null"))
  }, character(1)), archivo)
  archivo
}

test_that("el contrato estricto mantiene tipos con ausentes y bloques vacios", {
  archivo <- archivo_lote_tipada(list(NULL, 2, 3))
  tablas <- list()
  resumen <- vista_ejecutar_lotes(archivo, vista_lote_tipada("integer"),
    function(tabla, bloque) tablas[[bloque]] <<- tabla, 1, estricto = TRUE)
  expect_identical(tablas[[1]]$valor, NA_integer_)
  expect_identical(tablas[[2]]$valor, 2L)
  expect_equal(resumen$bloques, 3)
  v <- vista_lote_tipada("integer")
  v$where <- list(list(path = "false"))
  vacias <- list()
  vista_ejecutar_lotes(archivo, v, function(t, b) vacias[[b]] <<- t, 1, TRUE)
  expect_length(vacias, 3)
  expect_true(all(vapply(vacias, function(t) identical(t$valor, integer()), logical(1))))
})

test_that("rechaza valores antes de coaccionar y no entrega el bloque incompatible", {
  archivo <- archivo_lote_tipada(list(1.5, "DATO-CLINICO-123"))
  entregados <- list()
  inicio <- motor_actual()$tamano()
  e <- tryCatch(vista_ejecutar_lotes(archivo, vista_lote_tipada(),
    function(t, b) entregados[[b]] <<- t, 1, TRUE), error = identity)
  expect_s3_class(e, "fhirviews_error_esquema")
  expect_equal(e$bloque, 2)
  expect_identical(e$columna, "valor")
  expect_identical(e$fase, "esquema")
  expect_equal(e$completados, list(bloques = 1, recursos = 1, filas = 1))
  expect_length(entregados, 1)
  expect_false(grepl("DATO-CLINICO-123", conditionMessage(e), fixed = TRUE))
  expect_null(e$parent)
  expect_identical(motor_actual()$tamano(), inicio)
  expect_error(vista_ejecutar_lotes(archivo, vista_lote_tipada(), function(...) {
    stop("No debe recibir el bloque mezclado")
  }, 2, TRUE), class = "fhirviews_error_esquema")
  # Compatibilidad: el modo habitual sigue avisando y conservando el valor.
  tablas <- list()
  expect_warning(vista_ejecutar_lotes(archivo, vista_lote_tipada(),
    function(t, b) tablas[[b]] <<- t, 1), class = "fhirviews_aviso_tipo")
  expect_identical(tablas[[2]]$valor, "DATO-CLINICO-123")
})

test_that("verifica rango, finitud y tipo de cada valor y elemento", {
  fallar <- function() stop("incompatible")
  for (tipo in c("integer", "positiveInt", "unsignedInt")) {
    for (valor in list(1.7, Inf, -Inf, NaN, .Machine$integer.max + 1, "2", TRUE)) {
      expect_error(convertir_lote_estricto(list(valor),
        list(type = tipo, collection = FALSE), fallar), "incompatible")
    }
  }
  for (tipo in c("positiveInt", "unsignedInt")) {
    expect_error(convertir_lote_estricto(list(-1),
      list(type = tipo, collection = FALSE), fallar), "incompatible")
  }
  expect_error(convertir_lote_estricto(list(0),
    list(type = "positiveInt", collection = FALSE), fallar), "incompatible")
  expect_identical(convertir_lote_estricto(list(0, NULL),
    list(type = "unsignedInt", collection = FALSE), fallar), c(0L, NA_integer_))
  expect_error(convertir_lote_estricto(list("TRUE"),
    list(type = "boolean", collection = FALSE), fallar), "incompatible")
  expect_error(convertir_lote_estricto(list(123),
    list(type = "string", collection = FALSE), fallar), "incompatible")
  expect_error(convertir_lote_estricto(list(list(value = 2)),
    list(type = "decimal", collection = FALSE), fallar), "incompatible")
  expect_identical(convertir_lote_estricto(list(NULL, TRUE, FALSE),
    list(type = "boolean", collection = FALSE), fallar), c(NA, TRUE, FALSE))
  expect_error(convertir_lote_estricto(list(list(1, "2")),
    list(type = "integer", collection = TRUE), fallar), "incompatible")
  expect_identical(convertir_lote_estricto(list(list(1, 2), list()),
    list(type = "integer", collection = TRUE), fallar), list(c(1L, 2L), integer()))
})

test_that("exige tipos explicitos y un contrato comun entre ramas", {
  archivo <- archivo_lote_tipada(list(1))
  v <- vista_lote_tipada()
  v$select[[1]]$column[[2]]$type <- NULL
  e <- tryCatch(vista_ejecutar_lotes(archivo, v, function(...) stop("destino"),
                                   estricto = TRUE), error = identity)
  expect_s3_class(e, "fhirviews_error_esquema")
  expect_equal(e$bloque, 0)
  expect_identical(e$columna, "valor")
  v$select[[1]]$column[[2]]$type <- "Cantidad"
  expect_error(vista_ejecutar_lotes(archivo, v, identity, estricto = TRUE),
               class = "fhirviews_error_esquema")
  a <- vista_lote_tipada("decimal")$select[[1]]
  b <- vista_lote_tipada("string")$select[[1]]
  v <- list(resource = "Observation", select = list(list(unionAll = list(a, b))))
  expect_error(vista_ejecutar_lotes(archivo, v, identity, estricto = TRUE),
               class = "fhirviews_error_esquema")
  b <- a
  v$select[[1]]$unionAll[[2]] <- b
  tablas <- list()
  vista_ejecutar_lotes(archivo, v, function(t, b) tablas[[b]] <<- t, estricto = TRUE)
  expect_identical(tablas[[1]]$valor, c(1, 1))
  expect_error(vista_ejecutar_lotes(archivo, v, identity, estricto = NA),
               class = "fhirviews_error")
})

test_that("protege errores de lectura, cardinalidad y destino y conserva contexto", {
  archivo <- archivo_lote_tipada(list(1, 2))
  entregados <- character()
  e <- tryCatch(vista_ejecutar_lotes(archivo, vista_lote_tipada(), function(t, b) {
    entregados <<- c(entregados, t$id)
    if (b == 2) stop("PACIENTE-SECRETO EN EL DESTINO")
  }, 1, TRUE), error = identity)
  expect_identical(entregados, c("o1", "o2"))
  expect_identical(e$fase, "procesar")
  expect_equal(e$completados$bloques, 1)
  expect_false(grepl("PACIENTE-SECRETO", conditionMessage(e), fixed = TRUE))
  expect_null(e$parent)
  writeLines(c('{"resourceType":"Observation","id":"o1","valueQuantity":{"value":1}}',
               '{"PACIENTE-SECRETO"'), archivo)
  e <- tryCatch(vista_ejecutar_lotes(archivo, vista_lote_tipada(), function(...) {},
                                   1, TRUE), error = identity)
  expect_identical(e$fase, "lectura")
  expect_equal(e$bloque, 2)
  expect_false(grepl("PACIENTE-SECRETO", conditionMessage(e), fixed = TRUE))
  writeLines('{"resourceType":"Patient","name":[{"given":["Ana","Secreto"]}]}', archivo)
  v <- list(resource = "Patient", select = list(list(column = list(
    list(name = "nombre", path = "name.given", type = "string")))))
  e <- tryCatch(vista_ejecutar_lotes(archivo, v, identity, estricto = TRUE), error = identity)
  expect_identical(e$fase, "evaluacion")
  expect_identical(e$columna, "nombre")
  expect_false(grepl("Ana|Secreto", conditionMessage(e)))
})

test_that("un fallo no mezcla archivos ni altera los bloques confirmados", {
  a <- archivo_lote_tipada(list(1))
  b <- archivo_lote_tipada(list("secreto"))
  vistos <- integer()
  e <- tryCatch(vista_ejecutar_lotes(c(a, b), vista_lote_tipada(), function(t, b) {
    vistos <<- c(vistos, b)
  }, 1, TRUE), error = identity)
  expect_equal(vistos, 1)
  expect_equal(e$indice_archivo, 2)
  expect_equal(e$bloque, 2)
})

test_that("una transaccion externa revierte los bloques y permite reintentar sin duplicados", {
  skip_if_not_installed("DBI")
  skip_if_not_installed("duckdb", "1.3.0")
  db <- conectar_duckdb()
  on.exit(DBI::dbDisconnect(db), add = TRUE)
  DBI::dbWriteTable(db, "resultados", data.frame(id = "anterior", valor = 9))
  archivo <- archivo_lote_tipada(list(1, 2))
  cargar <- function(fallar = FALSE) DBI::dbWithTransaction(db, {
    DBI::dbExecute(db, "DELETE FROM resultados")
    vista_ejecutar_lotes(archivo, vista_lote_tipada(), function(t, b) {
      DBI::dbAppendTable(db, "resultados", t)
      if (fallar && b == 2) stop("fallo despues de escribir")
    }, 1, TRUE)
  })
  expect_error(cargar(TRUE), class = "fhirviews_error_lotes")
  expect_equal(DBI::dbReadTable(db, "resultados"), data.frame(id = "anterior", valor = 9))
  cargar()
  cargar()
  expect_equal(DBI::dbGetQuery(db, "SELECT * FROM resultados ORDER BY id"),
               data.frame(id = c("o1", "o2"), valor = c(1, 2)))
})

test_that("no confia en la clase o metadatos de errores del consumidor", {
  archivo <- archivo_lote_tipada(list(1))
  e <- tryCatch(vista_ejecutar_lotes(archivo, vista_lote_tipada(), function(...) {
    stop(structure(list(message = "SECRETO", columna = "SECRETO"),
                   class = c("fhirviews_error_lotes", "error", "condition")))
  }, estricto = TRUE), error = identity)
  expect_s3_class(e, "fhirviews_error_lotes")
  expect_identical(e$fase, "procesar")
  expect_null(e$columna)
  expect_false(grepl("SECRETO", conditionMessage(e), fixed = TRUE))
})

test_that("las colecciones gzip conservan vacios tipados y rechazan objetos", {
  archivo <- withr_tempfile(".ndjson.gz")
  con <- gzfile(archivo, "wt")
  writeLines(c('{"resourceType":"Patient","name":[{"given":["Ana","Luz"]}]}',
               '{"resourceType":"Patient"}'), con)
  close(con)
  v <- list(resource = "Patient", select = list(list(column = list(
    list(name = "nombres", path = "name.given", type = "string", collection = TRUE)))))
  tablas <- list()
  vista_ejecutar_lotes(archivo, v, function(t, b) tablas[[b]] <<- t, 1, TRUE)
  expect_identical(tablas[[1]]$nombres, list(c("Ana", "Luz")))
  expect_identical(tablas[[2]]$nombres, list(character()))
  archivo <- archivo_lote_tipada(list(1))
  v <- vista_lote_tipada("decimal", TRUE, "value.ofType(Quantity)")
  expect_error(vista_ejecutar_lotes(archivo, v, identity, estricto = TRUE),
               class = "fhirviews_error_esquema")
})

test_that("los numeros no finitos no se confunden con ausentes al serializar", {
  archivo <- withr_tempfile(".ndjson")
  writeLines('{"resourceType":"Observation","valueQuantity":{"value":1e309}}', archivo)
  e <- tryCatch(vista_ejecutar_lotes(archivo, vista_lote_tipada(), function(...) {
    stop("El bloque no debe llegar al destino")
  }, estricto = TRUE), error = identity)
  expect_s3_class(e, "fhirviews_error_lotes")
  expect_identical(e$fase, "lectura")
  expect_identical(e$motivo, "numero_no_finito")
  archivo <- archivo_lote_tipada(list(1e200))
  v <- vista_lote_tipada(ruta = "value.ofType(Quantity).value.power(10000)")
  expect_error(vista_ejecutar_lotes(archivo, v, function(...) {
    stop("No se debe entregar un resultado infinito")
  }, estricto = TRUE), class = "fhirviews_error_lotes")
  m <- motor_actual()
  inicio <- m$tamano()
  on.exit(m$liberar(inicio), add = TRUE)
  ids <- m$cargar(list(list(resourceType = "Observation", valueQuantity = list(value = 1e200))))
  expect_error(m$evaluar(ids, "value.ofType(Quantity).value.power(10000)", estricto = TRUE),
               "no finito")
})
