test_that("Specimen admite muestras clinicas y ambientales sin inventar obligatorios", {
  minimo <- fhir_desde_tabla(data.frame(id = "s1"), fhir_mapa("Specimen", c(id = "id")))
  expect_identical(names(minimo[[1]]), c("resourceType", "id"))
  m <- fhir_mapa("Specimen", c(id = "id", status = "estado", "subject.reference" = "lugar",
    "collection.collectedPeriod.start" = "inicio", "collection.collectedPeriod.end" = "fin",
    "collection.quantity.value" = "volumen"),
    constantes = list("collection.quantity.system" = "http://unitsofmeasure.org",
      "collection.quantity.code" = "mL"), referencias = c("subject.reference" = "Location"))
  datos <- data.frame(id = "s1", estado = "available", lugar = "l1", inicio = "2026-01-14",
    fin = "2026-01-15", volumen = "5.00")
  r <- fhir_desde_tabla(datos, m)
  expect_identical(r[[1]]$subject$reference, "Location/l1")
  expect_identical(r[[1]]$collection$collectedPeriod$start, datos$inicio)
  expect_match(attr(r, "fuente"), '"value":5.00', fixed = TRUE)
  expect_error(fhir_desde_tabla(transform(datos, estado = "invalido"), m), "ValueSet requerido")
  expect_error(fhir_mapa("Specimen", c(id = "id", "subject.reference" = "x"),
    referencias = c("subject.reference" = "Observation")), "destino FHIR permitido")
  eleccion <- fhir_mapa("Specimen", c(id = "id"), constantes = list(
    "collection.collectedDateTime" = "2026-01-14", "collection.collectedPeriod.start" = "2026-01-14"))
  expect_error(fhir_desde_tabla(data.frame(id = "s1"), eleccion), "eleccion")
  for (destino in c("parent[0].reference", "processing[0].additive[0].reference")) {
    expect_error(fhir_mapa("Specimen", stats::setNames(c("id", "x"), c("id", destino)),
      referencias = stats::setNames("Patient", destino)), "destino FHIR permitido")
  }
})

test_that("DiagnosticReport exige status y code, y valida elecciones y media", {
  d <- data.frame(id = "d1")
  for (cs in list(list(), list(status = "final"), list("code.text" = "Ficticio"))) {
    expect_error(fhir_desde_tabla(d, fhir_mapa("DiagnosticReport", c(id = "id"), cs)), "obligatorio")
  }
  cs <- list(status = "final", "code.text" = "Informe ficticio")
  r <- fhir_desde_tabla(d, fhir_mapa("DiagnosticReport", c(id = "id"), cs))
  expect_null(r[[1]]$subject)
  expect_null(r[[1]]$result)
  for (extra in list(list(status = "invalido"),
    list(effectiveDateTime = "2026-01-14", "effectivePeriod.start" = "2026-01-14"),
    list("media[0].comment" = "Ficticio"), list(issued = "2026-01-14"))) {
    prueba <- utils::modifyList(cs, extra)
    expect_error(fhir_desde_tabla(d, fhir_mapa("DiagnosticReport", c(id = "id"), prueba)),
      class = "fhirviews_error_mapeo")
  }
  for (destino in c("result[0].reference", "specimen[0].reference", "media[0].link.reference")) {
    expect_error(fhir_mapa("DiagnosticReport", stats::setNames(c("id", "x"), c("id", destino)),
      referencias = stats::setNames("Patient", destino)), "destino FHIR permitido")
  }
})

test_that("colecciones de referencias conservan orden y omiten ausentes", {
  c <- casos_constructor_r4()
  d <- c$datos$DiagnosticReport
  d$resultados <- list(c("o1", NA, "", "o2"), character(), c("o3", "o3"))
  d$muestras <- list("s1", NULL, c("s2", "s3"))
  r <- fhir_desde_tabla(d, c$mapas$DiagnosticReport)
  expect_identical(r[[1]]$result, list(list(reference = "Observation/o1"), list(reference = "Observation/o2")))
  expect_null(r[[2]]$result)
  expect_null(r[[2]]$specimen)
  expect_length(r[[3]]$result, 2L) # No eliminar referencias repetidas por inferencia.
  expect_identical(r[[3]]$specimen[[2]]$reference, "Specimen/s3")
  d$resultados[[2]] <- "id con espacios"
  e <- tryCatch(fhir_desde_tabla(d, c$mapas$DiagnosticReport), error = identity)
  expect_s3_class(e, "fhirviews_error_mapeo")
  expect_identical(e$fila, 2L)
  expect_identical(e$campo, "result[].reference")
  literal <- fhir_mapa("DiagnosticReport", c(id = "id", "result[].reference" = "refs"),
    constantes = list(status = "final", "code.text" = "Ficticio"))
  x <- data.frame(id = "d1"); x$refs <- list(c("Observation/o1", "https://example.org/fhir/Observation/o2"))
  expect_length(fhir_desde_tabla(x, literal)[[1]]$result, 2L)
  x$refs[[1]][2] <- "Specimen/s1"
  expect_error(fhir_desde_tabla(x, literal), "destino FHIR permitido")
})

test_that("colecciones de referencias rechazan objetos ambiguos y solapamientos", {
  for (otro in c("result[0].reference", "result[1].display", "result[].reference", "result[].display")) {
    destinos <- c("id", "result[].reference", otro)
    expect_error(fhir_mapa("DiagnosticReport", stats::setNames(c("id", "a", "b"), destinos)),
      class = "fhirviews_error_mapeo")
  }
  for (destino in c("name[].family", "name[].given[]", "contact[].organization.reference", "result[]")) {
    tipo <- if (startsWith(destino, "result")) "DiagnosticReport" else "Patient"
    expect_error(fhir_mapa(tipo, stats::setNames(c("id", "a"), c("id", destino))),
      class = "fhirviews_error_mapeo")
  }
  anidado <- fhir_mapa("Specimen", c(id = "id", "processing[0].additive[].reference" = "a"),
    referencias = c("processing[0].additive[].reference" = "Substance"))
  d <- data.frame(id = "s1"); d$a <- list(c("a1", "a2"))
  expect_identical(fhir_desde_tabla(d, anidado)[[1]]$processing[[1]]$additive[[2]]$reference, "Substance/a2")
})

test_that("el ejemplo SQL de laboratorio produce relaciones y tablas iguales en los dos motores", {
  skip_if_not_installed("DBI")
  skip_if_not_installed("duckdb", "1.4.0")
  e <- new.env(parent = globalenv())
  sys.source(system.file("examples", "laboratorio-r4.R", package = "fhirviews"), e)
  r <- e$laboratorio_r4()
  expect_length(r$recursos, 5L)
  expect_identical(vapply(r$recursos, `[[`, "", "resourceType"),
    c("Patient", "Specimen", "Observation", "Observation", "DiagnosticReport"))
  expect_identical(r$tablas$resultados$observacion, c("demo-lab-o1", "demo-lab-o2"))
  expect_equal(r$tablas$muestras$volumen, 5)
  expect_equal(r$tablas$muestras$limite, 4.995)
  expect_equal(r$tablas$observaciones$limite, c(71.995, 13.495))
  expect_identical(r$recursos[[5]]$specimen[[1]]$reference, "Specimen/demo-lab-s")
})
