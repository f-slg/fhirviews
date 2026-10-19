paciente <- list(resourceType = "Patient", id = "p1")
observacion <- list(resourceType = "Observation", id = "o1", status = "final")

test_that("acepta un recurso, una lista y un Bundle", {
  r <- fhir_recursos(paciente)
  expect_s3_class(r, "fhir_recursos")
  expect_length(r, 1L)

  expect_length(fhir_recursos(list(paciente, observacion)), 2L)

  bundle <- list(resourceType = "Bundle", type = "searchset",
                 entry = list(list(resource = paciente),
                              list(fullUrl = "sin-recurso"),
                              list(resource = observacion)))
  r <- fhir_recursos(bundle)
  expect_length(r, 2L)
  expect_identical(r[[2]]$id, "o1")

  # Una lista que mezcla Bundles y recursos
  expect_length(fhir_recursos(list(bundle, paciente)), 3L)
})

test_that("acepta JSON, NDJSON y archivos", {
  json <- '{"resourceType": "Patient", "id": "p1"}'
  expect_identical(fhir_recursos(json)[[1]]$id, "p1")

  arreglo <- '[{"resourceType": "Patient", "id": "p1"},
               {"resourceType": "Patient", "id": "p2"}]'
  expect_length(fhir_recursos(arreglo), 2L)

  ndjson <- paste('{"resourceType": "Patient", "id": "p1"}',
                  '{"resourceType": "Patient", "id": "p2"}', "", sep = "\n")
  expect_length(fhir_recursos(ndjson), 2L)

  vector <- c('{"resourceType": "Patient", "id": "p1"}',
              '{"resourceType": "Patient", "id": "p2"}')
  expect_length(fhir_recursos(vector), 2L)

  archivo <- withr_tempfile(".ndjson")
  writeLines(vector, archivo)
  expect_length(fhir_recursos(archivo), 2L)

  archivo_json <- withr_tempfile(".json")
  writeLines(arreglo, archivo_json)
  expect_length(fhir_recursos(archivo_json), 2L)
})

test_that("combina y subdivide conservando la clase", {
  r <- c(fhir_recursos(paciente), observacion)
  expect_s3_class(r, "fhir_recursos")
  expect_length(r, 2L)
  expect_s3_class(r[2], "fhir_recursos")
  expect_output(print(r), "2 recursos")
})

test_that("da errores claros", {
  expect_error(fhir_recursos(1:3), class = "fhirviews_error")
  expect_error(fhir_recursos(list(id = "x")), class = "fhirviews_error")
  expect_error(fhir_recursos("{no es json"), class = "fhirviews_error")
})
