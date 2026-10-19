test_that("el analizador de FHIRPath arma el arbol", {
  a <- fp_analizar("name.where(use = 'official').family.first()")
  expect_identical(a$t, "llamada")
  expect_identical(a$fn, "first")
  expect_identical(a$base$nombre, "family")
  expect_identical(a$base$base$fn, "where")
  expect_identical(a$base$base$args[[1]]$op, "=")

  b <- fp_analizar("a + b * 2 > 3 and not_x or c")
  expect_identical(b$op, "or")
  expect_identical(b$a$op, "and")
  expect_identical(b$a$a$op, ">")
  expect_identical(b$a$a$a$b$op, "*")

  expect_identical(fp_analizar("@2020-01-01")$valor, "2020-01-01")
  expect_identical(fp_analizar("1.5")$tipo, "DOUBLE")
  expect_identical(fp_analizar("%`mi var`")$nombre, "mi var")
  expect_identical(fp_analizar("'a\\'b'")$valor, "a'b")
  expect_identical(fp_analizar("x is FHIR.Quantity")$tipo, "Quantity")
  expect_identical(fp_analizar("-x")$t, "neg")
  expect_identical(fp_analizar("name[0]")$t, "indice")

  expect_error(fp_analizar("@@"), class = "fhirviews_error_sql")
  expect_error(fp_analizar("name.("), class = "fhirviews_error_sql")
  expect_error(fp_analizar("'sin cerrar"), class = "fhirviews_error_sql")
  expect_error(fp_analizar("a b"), class = "fhirviews_error_sql")
})

test_that("vista_sql genera la consulta", {
  vista <- vista_crear("Patient", c(sexo = "gender",
                                    apellido = "name.first().family"))
  sql <- vista_sql(vista, "datos/pacientes.ndjson")
  expect_s3_class(sql, "fhir_sql")
  expect_match(sql, "read_json_objects", fixed = TRUE)
  expect_match(sql, "'Patient'", fixed = TRUE)
  expect_output(print(sql), "SELECT")
  expect_match(vista_sql(vista, "p.parquet"), "read_parquet", fixed = TRUE)
  expect_match(vista_sql(vista), "FROM \"recursos\"", fixed = TRUE)
  expect_error(vista_sql(vista, c("a.ndjson", "b.parquet")),
               class = "fhirviews_error")
  expect_error(vista_sql(vista, "no es una tabla"), class = "fhirviews_error")
})

test_that("lo que no se traduce da un error que sugiere vista_ejecutar()", {
  v <- vista_crear("Patient", c(x = "birthDate.lowBoundary()"))
  expect_error(vista_sql(v), class = "fhirviews_error_sql")
  expect_error(vista_sql(v), "vista_ejecutar")
  expect_error(vista_sql(vista_crear("Patient", c(x = "%nada"))),
               class = "fhirviews_error_sql")
  expect_error(vista_sql(vista_crear("Patient", c(x = "name.ofType(Foo)"))),
               NA)
  expect_error(vista_sql(vista_crear("Patient", c(x = "ofType(Foo)"))),
               class = "fhirviews_error_sql")
  expect_error(vista_sql(vista_crear("Patient", c(x = "first(1)"))),
               class = "fhirviews_error_sql")
})

# Las pruebas que ejecutan SQL necesitan la extension json de DuckDB, que
# se descarga la primera vez
skip_on_cran()
skip_if_not_installed("DBI")
skip_if_not_installed("duckdb", "1.3.0")
json_disponible <- tryCatch({
  con <- DBI::dbConnect(duckdb::duckdb())
  cargar_json_duckdb(con)
  DBI::dbDisconnect(con)
  TRUE
}, error = function(e) FALSE)
skip_if_not(json_disponible, "la extensi\u00f3n json de DuckDB no est\u00e1 disponible")

caso <- system.file("extdata", "caso_clinico.ndjson", package = "fhirviews")

# Las colecciones vacias sin `type` son logical() en vista_ejecutar() y del
# tipo del modelo FHIR en DuckDB: se comparan como NULL
sin_vacios <- function(df) {
  for (nm in names(df)) {
    if (is.list(df[[nm]])) {
      df[[nm]] <- lapply(df[[nm]], function(x) if (length(x)) x)
    }
  }
  df
}

comparar_motores <- function(vista, recursos = caso) {
  v8 <- vista_ejecutar(recursos, vista)
  db <- vista_ejecutar_duckdb(recursos, vista)
  expect_equal(sin_vacios(db), sin_vacios(v8), ignore_attr = TRUE)
}

test_that("da lo mismo que vista_ejecutar() con el caso clinico", {
  comparar_motores(vista_crear("Patient", c(
    sexo = "gender", nacimiento = "birthDate", activo = "active",
    apellido = "name.where(use = 'official').family.first()",
    nombres = "name.first().given.join(' ')",
    telefonos = "telecom.where(system = 'phone').count()")))
  comparar_motores(vista_crear(
    "Observation",
    c(codigo = "code.coding.first().code", valor = "value.ofType(Quantity).value",
      unidad = "value.ofType(Quantity).unit",
      paciente = "subject.getReferenceKey(Patient)"),
    where = "status = 'final'"))
  comparar_motores(vista_crear("Patient", c(sistema = "system", valor = "value"),
                               por_cada = "telecom"))
  comparar_motores(vista_leer('{
    "resource": "QuestionnaireResponse",
    "select": [
      {"column": [{"name": "id", "path": "getResourceKey()"}]},
      {"repeat": ["item"], "column": [
        {"name": "orden", "path": "%rowIndex"},
        {"name": "pregunta", "path": "linkId"},
        {"name": "respuestas", "path": "answer.value.ofType(string)",
         "collection": true}
      ]}
    ]
  }'))
})

test_that("tipos, colecciones y objetos", {
  pacientes <- list(
    list(resourceType = "Patient", id = "p1", active = TRUE,
         name = list(list(family = "A", given = list("x", "y")))),
    list(resourceType = "Patient", id = "p2",
         extension = list(list(url = "u", valueInteger = 3L)))
  )
  vista <- vista_leer('{"resource": "Patient", "select": [{"column": [
    {"name": "id", "path": "id"},
    {"name": "activo", "path": "active"},
    {"name": "dados", "path": "name.given", "collection": true},
    {"name": "nombre", "path": "name.first()"},
    {"name": "ext", "path": "extension(\'u\').value.ofType(integer)"},
    {"name": "cuenta", "path": "name.given.count()"},
    {"name": "x", "path": "id + \'-\' + name.family.first()"}
  ]}]}')
  df <- vista_ejecutar_duckdb(pacientes, vista)
  expect_identical(df$activo, c(TRUE, NA))
  expect_identical(df$dados, list(c("x", "y"), character()))
  expect_identical(df$nombre[[1]], list(family = "A", given = list("x", "y")))
  expect_null(df$nombre[[2]])
  expect_identical(df$ext, c(NA, 3L))
  expect_identical(df$cuenta, c(2L, 0L))
  expect_identical(df$x, c("p1-A", NA))
  comparar_motores(vista, pacientes)

  # Varios valores sin collection: error de la vista
  v2 <- vista_crear("Patient", c(g = "name.given"))
  expect_error(vista_ejecutar_duckdb(pacientes, v2),
               class = "fhirviews_error_vista")
  # where que no devuelve un logico
  v3 <- vista_crear("Patient", c(i = "id"), where = "id")
  expect_error(vista_ejecutar_duckdb(pacientes, v3),
               class = "fhirviews_error_vista")
})

test_that("guarda en una tabla y lee Parquet", {
  con <- DBI::dbConnect(duckdb::duckdb())
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  vista <- vista_crear("Observation", c(
    valor = "value.ofType(Quantity).value",
    paciente = "subject.getReferenceKey(Patient)"))
  res <- vista_ejecutar_duckdb(caso, vista, con_db = con, tabla = "obs")
  expect_identical(res, con)
  n <- DBI::dbGetQuery(con, "SELECT count(*) AS n FROM obs")$n
  expect_equal(n, nrow(vista_ejecutar(caso, vista)))

  # Parquet con columnas STRUCT, como lo escribe DuckDB desde NDJSON
  lineas <- readLines(caso, encoding = "UTF-8")
  ndjson <- withr_tempfile(".ndjson")
  writeLines(grep('"resourceType":"Observation"', lineas, value = TRUE,
                  fixed = TRUE), ndjson, useBytes = TRUE)
  parquet <- withr_tempfile(".parquet")
  DBI::dbExecute(con, sprintf(
    "COPY (SELECT * FROM read_json('%s', format = 'newline_delimited'))
     TO '%s' (FORMAT parquet)", ndjson, parquet))
  desde_parquet <- vista_ejecutar_duckdb(parquet, vista, con_db = con)
  expect_equal(desde_parquet, vista_ejecutar(caso, vista), ignore_attr = TRUE)

  # Una tabla con una columna json
  DBI::dbExecute(con, sprintf(
    "CREATE TABLE recursos AS SELECT json FROM read_json_objects('%s')", caso))
  desde_tabla <- vista_ejecutar_duckdb("recursos", vista, con_db = con)
  expect_equal(nrow(desde_tabla), n)
})

test_that("pasan las pruebas shareable del banco oficial", {
  res <- vista_conformidad(motor = "duckdb")
  expect_identical(attr(res, "motor"), "duckdb")
  expect_output(print(res), "motor DuckDB")
  shareable <- res[res$perfil %in% "shareable", ]
  expect_gte(nrow(shareable), 133L)
  for (i in seq_len(nrow(shareable))) {
    expect(shareable$aprobada[i],
           sprintf("%s / %s: %s", shareable$archivo[i], shareable$prueba[i],
                   shareable$detalle[i]))
  }
})
