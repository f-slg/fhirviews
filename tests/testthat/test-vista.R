pacientes <- list(
  list(resourceType = "Patient", id = "p1", gender = "female",
       birthDate = "1985-03-12", active = TRUE,
       name = list(list(use = "official", family = "Paredes Cevallos",
                        given = list("Ana", "Lucia")),
                   list(use = "nickname", given = list("Anita"))),
       contact = list(list(name = list(family = "Paredes"),
                           address = list(city = "Quito")))),
  list(resourceType = "Patient", id = "p2", gender = "male",
       birthDate = "2001-11-30", active = FALSE,
       name = list(list(family = "Salazar Moreno", given = list("Jorge"))),
       address = list(list(city = "Loja"))),
  list(resourceType = "Observation", id = "o1", status = "final")
)

test_that("columnas simples, tipos y filtrado por recurso", {
  v <- vista_crear("Patient", c(sexo = "gender", activo = "active",
                                nacimiento = "birthDate"))
  df <- vista_ejecutar(pacientes, v)
  expect_s3_class(df, "data.frame")
  expect_identical(names(df), c("id", "sexo", "activo", "nacimiento"))
  expect_identical(df$id, c("p1", "p2"))
  expect_identical(df$activo, c(TRUE, FALSE))

  v <- vista_leer(list(resource = "Patient", select = list(list(column = list(
    list(name = "n", path = "name.count()", type = "decimal"),
    list(name = "falta", path = "deceased", type = "boolean"),
    list(name = "texto", path = "multipleBirth", type = "string"))))))
  df <- vista_ejecutar(pacientes, v)
  expect_type(df$n, "double")
  expect_identical(df$falta, c(NA, NA))
  expect_identical(df$texto, c(NA_character_, NA_character_))
})

test_that("una vista sin recursos del tipo devuelve una tabla vacia tipada", {
  v <- vista_leer(list(resource = "Encounter", select = list(list(column = list(
    list(name = "id", path = "id", type = "id"),
    list(name = "n", path = "length", type = "integer"))))))
  df <- vista_ejecutar(pacientes, v)
  expect_identical(nrow(df), 0L)
  expect_identical(df$id, character())
  expect_identical(df$n, integer())
})

test_that("forEach, forEachOrNull y %rowIndex", {
  v <- vista_crear("Patient", c(uso = "use", orden = "%rowIndex"),
                   por_cada = "name")
  df <- vista_ejecutar(pacientes, v)
  expect_identical(df$id, c("p1", "p1", "p2"))
  expect_identical(df$orden, c(0L, 1L, 0L))

  v <- vista_crear("Patient", c(ciudad = "city"), por_cada = "address")
  expect_identical(vista_ejecutar(pacientes, v)$id, "p2")
  v <- vista_crear("Patient", c(ciudad = "city"), por_cada = "address",
                   incluir_vacios = TRUE)
  df <- vista_ejecutar(pacientes, v)
  expect_identical(df$id, c("p1", "p2"))
  expect_identical(df$ciudad, c(NA, "Loja"))
})

test_that("collection devuelve columnas de lista", {
  v <- vista_leer(list(resource = "Patient", select = list(list(column = list(
    list(name = "id", path = "id"),
    list(name = "nombres", path = "name.given", collection = TRUE))))))
  df <- vista_ejecutar(pacientes, v)
  expect_type(df$nombres, "list")
  expect_identical(df$nombres[[1]], c("Ana", "Lucia", "Anita"))
  expect_identical(df$nombres[[2]], "Jorge")
})

test_that("varios valores sin collection dan un error claro", {
  v <- vista_crear("Patient", c(nombre = "name.given"))
  expect_error(vista_ejecutar(pacientes, v), class = "fhirviews_error_vista")
})

test_that("unionAll, select anidados y orden de columnas", {
  v <- vista_leer('{
    "resource": "Patient",
    "select": [{
      "column": [{"name": "id", "path": "getResourceKey()"}],
      "select": [{"column": [{"name": "sexo", "path": "gender"}]}],
      "unionAll": [
        {"forEach": "address", "column": [
          {"name": "ciudad", "path": "city"},
          {"name": "propia", "path": "true"}]},
        {"forEach": "contact.address", "column": [
          {"name": "ciudad", "path": "city"},
          {"name": "propia", "path": "false"}]}
      ]
    }]
  }')
  df <- vista_ejecutar(pacientes, v)
  expect_identical(names(df), c("id", "sexo", "ciudad", "propia"))
  df <- df[order(df$id), ]
  expect_identical(df$ciudad, c("Quito", "Loja"))
  expect_identical(df$propia, c(FALSE, TRUE))
})

test_that("repeat recorre en profundidad", {
  qr <- list(resourceType = "QuestionnaireResponse", id = "qr1", item = list(
    list(linkId = "1", item = list(list(linkId = "1.1"),
                                   list(linkId = "1.2", item = list(
                                     list(linkId = "1.2.1"))))),
    list(linkId = "2")))
  v <- vista_leer(list(resource = "QuestionnaireResponse", select = list(
    list(column = list(list(name = "id", path = "id"))),
    list(`repeat` = list("item"), column = list(
      list(name = "link", path = "linkId"),
      list(name = "i", path = "%rowIndex"))))))
  df <- vista_ejecutar(qr, v)
  expect_identical(df$link, c("1", "1.1", "1.2", "1.2.1", "2"))
  expect_identical(df$i, 0:4)
})

test_that("where y constantes, incluidas fechas", {
  v <- vista_crear("Patient", c(sexo = "gender"),
                   where = "birthDate < %corte",
                   constantes = list(corte = as.Date("2000-01-01")))
  expect_identical(vista_ejecutar(pacientes, v)$id, "p1")
  v <- vista_crear("Patient", c(sexo = "gender"),
                   where = c("active", "gender = %g"),
                   constantes = list(g = "female"))
  expect_identical(vista_ejecutar(pacientes, v)$id, "p1")
  v <- vista_crear("Patient", c(sexo = "gender"), where = "name.family")
  expect_error(vista_ejecutar(pacientes, v), class = "fhirviews_error_vista")
})

test_that("el resultado es el mismo desde listas o desde JSON", {
  v <- vista_crear("Patient", c(apellido = "family"), por_cada = "name")
  json <- vapply(pacientes, function(p) {
    as.character(jsonlite::toJSON(p, auto_unbox = TRUE))
  }, character(1))
  r <- fhir_recursos(json)
  expect_false(is.null(attr(r, "fuente")))
  expect_identical(vista_ejecutar(r, v), vista_ejecutar(pacientes, v))

  # Si se modifica la lista, se usa la versión modificada
  r[[1]] <- list(resourceType = "Patient", id = "nuevo")
  expect_null(attr(r, "fuente"))
  expect_identical(unique(vista_ejecutar(r, v)$id), "p2")
  expect_identical(vista_ejecutar(r, vista_crear("Patient", c(s = "gender")))$id,
                   c("nuevo", "p2"))
})

test_that("vista_leer, vista_json y print", {
  v <- vista_crear("Patient", c(sexo = "gender"), nombre = "demo")
  json <- vista_json(v)
  expect_s3_class(json, "json")
  v2 <- vista_leer(as.character(json))
  expect_identical(unclass(v2), unclass(v))

  archivo <- withr_tempfile(".json")
  writeLines(json, archivo)
  expect_identical(unclass(vista_leer(archivo)), unclass(v))
  expect_output(print(v), "Columnas \\(2\\): id, sexo")
  expect_error(vista_leer(3), class = "fhirviews_error")
  expect_error(vista_crear("Patient", c("gender")), class = "fhirviews_error")
})

test_that("vista_validar encuentra los problemas", {
  problemas <- function(v) {
    tryCatch({
      vista_validar(v)
      character()
    }, fhirviews_error_vista = function(e) e$problemas)
  }
  expect_length(problemas(vista_crear("Patient", c(a = "id"))), 0L)
  expect_match(problemas(list()), "vac")
  expect_match(problemas(list(select = list(list(column = list(
    list(name = "a", path = "id")))))), "resource")
  expect_match(problemas(list(resource = "Patient")), "select")
  base <- function(...) {
    list(resource = "Patient", select = list(list(...)))
  }
  expect_match(problemas(base(column = list(list(name = "1a", path = "id")))),
               "no es v")
  expect_match(problemas(base(column = list(list(name = "a", path = "id"),
                                            list(name = "a", path = "id")))),
               "mismo nombre")
  expect_match(problemas(base(column = list(list(path = "id")))),
               "obligatorio")
  expect_match(problemas(base(column = list(list(name = "a", path = "id",
                                                 otro = 1)))),
               "no permitidos")
  expect_match(problemas(base(forEach = "name", forEachOrNull = "name",
                              column = list(list(name = "a", path = "id")))),
               "solo puede")
  expect_match(problemas(base(column = list(list(name = "a", path = "id(")))),
               "no es v.lida")
  expect_match(problemas(c(base(column = list(list(name = "a", path = "id"))),
                           list(constant = list(list(name = "k"))))),
               "exactamente un valor")
  expect_match(problemas(base(unionAll = list(
    list(column = list(list(name = "a", path = "id"))),
    list(column = list(list(name = "b", path = "id")))))), "mismas columnas")
})
