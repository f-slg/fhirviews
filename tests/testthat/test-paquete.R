test_that("el paquete se carga", {
  expect_true("fhirviews" %in% loadedNamespaces())
})
