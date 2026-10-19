res <- vista_conformidad()

test_that("pasan todas las pruebas shareable del banco oficial", {
  shareable <- res[res$perfil %in% "shareable", ]
  expect_gte(nrow(shareable), 133L)
  for (i in seq_len(nrow(shareable))) {
    expect(shareable$aprobada[i],
           sprintf("%s / %s: %s", shareable$archivo[i], shareable$prueba[i],
                   shareable$detalle[i]))
  }
})

test_that("las experimentales no retroceden", {
  experimental <- res[res$perfil %in% "experimental", ]
  expect_gte(sum(experimental$aprobada), 7L)
})

test_that("el resumen y el informe oficial", {
  expect_s3_class(res, "fhir_conformidad")
  expect_named(res, c("archivo", "prueba", "perfil", "aprobada", "detalle"))
  expect_match(attr(res, "fuente"), "sql-on-fhir.js@")
  expect_output(print(res), "shareable +[0-9]+ de +[0-9]+ aprobadas")

  archivo <- withr_tempfile(".json")
  basico <- vista_conformidad("basic.json", informe = archivo)
  informe <- jsonlite::fromJSON(archivo, simplifyVector = FALSE)
  expect_named(informe, "basic.json")
  expect_length(informe$basic.json$tests, nrow(basico))
  primera <- informe$basic.json$tests[[1]]
  expect_named(primera, c("name", "result"))
  expect_true(is.logical(primera$result$passed))

  expect_error(vista_conformidad("no-existe.json"), class = "fhirviews_error")
})

test_that("la comparacion detecta diferencias", {
  recursos <- fhir_recursos(list(resourceType = "Patient", id = "p1",
                                 name = list(list(given = list("A", "B")))))
  vista <- list(resource = "Patient", select = list(list(column = list(
    list(name = "id", path = "id"),
    list(name = "g", path = "name.given", collection = TRUE)))))
  bien <- list(view = vista,
               expect = list(list(id = "p1", g = list("A", "B"))))
  expect_true(ejecutar_prueba_sof(bien, recursos)$aprobada)
  mal <- list(view = vista, expect = list(list(id = "p1", g = list("A"))))
  expect_false(ejecutar_prueba_sof(mal, recursos)$aprobada)
  filas <- list(view = vista, expect = list())
  expect_match(ejecutar_prueba_sof(filas, recursos)$detalle, "1 filas")
  error <- list(view = vista, expectError = TRUE)
  expect_false(ejecutar_prueba_sof(error, recursos)$aprobada)
})

test_that("descarga el banco desde GitHub", {
  skip_on_cran()
  skip_if_offline("api.github.com")
  descargado <- tryCatch(vista_conformidad("basic.json", descargar = TRUE),
                         fhirviews_error = function(e) NULL)
  skip_if(is.null(descargado), "GitHub no respondi\u00f3 (l\u00edmite de la API)")
  expect_true(all(descargado$aprobada))
})
