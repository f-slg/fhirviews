skip_if_not_installed("DBI")
skip_if_not_installed("duckdb")

recursos <- fhir_recursos(list(
  list(resourceType = "Patient", id = "p1", gender = "female",
       name = list(list(family = "Paredes", given = list("Ana", "Lucia")))),
  list(resourceType = "Patient", id = "p2", gender = "male",
       name = list(list(family = "Salazar", given = list("Jorge")))),
  list(resourceType = "Observation", id = "o1", status = "final",
       subject = list(reference = "Patient/p1"),
       valueQuantity = list(value = 98.5, unit = "mg/dL"))
))

test_that("guarda varias vistas y se pueden unir con SQL", {
  db <- vista_duckdb(recursos, list(
    paciente = vista_crear("Patient", c(sexo = "gender")),
    obs = vista_crear("Observation", c(
      paciente = "subject.getReferenceKey(Patient)",
      valor = "value.ofType(Quantity).value"))
  ))
  on.exit(DBI::dbDisconnect(db, shutdown = TRUE))
  expect_setequal(DBI::dbListTables(db), c("paciente", "obs"))
  r <- DBI::dbGetQuery(db, "SELECT p.sexo, o.valor FROM obs o
                            JOIN paciente p ON o.paciente = p.id")
  expect_identical(r$sexo, "female")
  expect_identical(r$valor, 98.5)
})

test_that("listas, objetos, nombres y modo agregar", {
  v <- vista_leer(list(name = "nombres", resource = "Patient",
                       select = list(list(column = list(
                         list(name = "id", path = "id"),
                         list(name = "dados", path = "name.given",
                              collection = TRUE),
                         list(name = "nombre", path = "name.first()"))))))
  db <- vista_duckdb(recursos, v)
  on.exit(DBI::dbDisconnect(db, shutdown = TRUE))
  r <- DBI::dbGetQuery(db, "SELECT id, len(dados) AS n, nombre FROM nombres
                            ORDER BY id")
  expect_identical(as.integer(r$n), c(2L, 1L))
  expect_match(r$nombre[1], '"family":"Paredes"', fixed = TRUE)

  vista_duckdb(recursos, v, con_db = db, sobrescribir = FALSE)
  expect_identical(DBI::dbGetQuery(db, "SELECT count(*) AS n FROM nombres")$n,
                   4)

  expect_error(vista_duckdb(recursos, vista_crear("Patient", c(s = "gender")),
                            con_db = db), class = "fhirviews_error")
  expect_error(vista_duckdb(recursos, list(`1x` = v), con_db = db),
               class = "fhirviews_error")
  expect_error(vista_duckdb(recursos, list(a = v, a = v), con_db = db),
               class = "fhirviews_error")
})
