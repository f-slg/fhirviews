skip_on_cran()
skip_if_not_installed("duckdb", "1.3.0")
skip_if_not_installed("DBI")

test_that("los dos motores aprueban todos los limites oficiales", {
  res <- vista_conformidad("fn_boundary.json", motor = "duckdb")
  expect_true(all(res$aprobada), info = paste(res$detalle, collapse = "\n"))
})

test_that("SQL conserva los tokens decimales originales y distingue texto", {
  valores <- c("1", "1.0", "1.00", "-1.00", "1.0e-2", "1e2", "0.00000001")
  textos <- paste0('{"resourceType":"Observation","id":"o', seq_along(valores),
    '","note":[{"text":"123, \\\"456\\\", 1.00 y \\\\789"}],',
    '"valueQuantity":{"value":', valores, '},"component":[{"valueQuantity":{"value":2.00}}]}')
  v <- vista_crear("Observation", c(
    bajo = "value.ofType(Quantity).value.lowBoundary()",
    alto = "value.ofType(Quantity).value.highBoundary()",
    componente = "component[0].value.ofType(Quantity).value.lowBoundary()"))
  con <- conectar_duckdb()
  on.exit(DBI::dbDisconnect(con))
  db <- vista_ejecutar_duckdb(textos, v, con_db = con)
  expect_equal(db, vista_ejecutar(textos, v))
  expect_equal(db$bajo, c(0.5, 0.95, 0.995, -1.005, 0.0095, 50, 0))
  expect_equal(db$alto, c(1.5, 1.05, 1.005, -0.995, 0.0105, 150, 0.00000002))
  expect_equal(db$componente, rep(1.995, length(valores)))
  literal <- vista_crear("Observation", c(x = "1.00.lowBoundary()"))
  expect_equal(vista_ejecutar_duckdb(textos, literal, con_db = con), vista_ejecutar(textos, literal))
  expect_error(vista_sql(vista_crear("Observation", c(x = "(-1.00).lowBoundary()"))),
               class = "fhirviews_error_sql")
  falta_indice <- vista_crear("Observation", c(x = "component.value.ofType(Quantity).value.lowBoundary()"))
  expect_error(vista_ejecutar_duckdb(textos, falta_indice, con_db = con), "indices explicitos")
  excesivo <- '{"resourceType":"Observation","valueQuantity":{"value":1.000000000}}'
  expect_error(vista_ejecutar_duckdb(excesivo, v, con_db = con), "escalas")
})
