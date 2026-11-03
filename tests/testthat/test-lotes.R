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
