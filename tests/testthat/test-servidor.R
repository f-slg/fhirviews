# Pruebas contra servidores reales. No se ejecutan en CRAN.
#
# * Lectura: el servidor público https://hapi.fhir.org/baseR4.
# * Escritura: solo si la variable de entorno FHIRVIEWS_SERVIDOR_ESCRITURA
#   apunta a un servidor de pruebas propio, por ejemplo un HAPI local:
#     podman run -d -p 8080:8080 docker.io/hapiproject/hapi:latest
#     FHIRVIEWS_SERVIDOR_ESCRITURA=http://localhost:8080/fhir

publico <- "https://hapi.fhir.org/baseR4"

test_that("lectura y paginacion en el servidor publico", {
  skip_on_cran()
  skip_if_not(fhir_disponible(publico, tiempo = 10), "HAPI p\u00fablico no responde")
  con <- fhir_conectar(publico)
  expect_identical(con$version_fhir, "4.0.1")
  r <- fhir_buscar(con, "Patient", `_count` = 5, max_paginas = 2,
                   progreso = FALSE)
  expect_gt(length(r), 5L)
  expect_lte(length(r), 10L)
  df <- vista_ejecutar(r, vista_crear("Patient", c(sexo = "gender")))
  expect_identical(nrow(df), length(r))
  expect_identical(fhir_leer(con, "Patient", r[[1]]$id)$id, r[[1]]$id)
  expect_error(fhir_leer(con, "Patient", "fhirviews-no-existe-0"),
               class = "fhirviews_error_http")
})

test_that("ciclo completo de escritura en un servidor de pruebas", {
  skip_on_cran()
  url <- Sys.getenv("FHIRVIEWS_SERVIDOR_ESCRITURA")
  skip_if(!nzchar(url), "FHIRVIEWS_SERVIDOR_ESCRITURA no est\u00e1 definida")
  skip_if_not(fhir_disponible(url), "El servidor de pruebas no responde")
  con <- fhir_conectar(url)
  marca <- paste0("fhirviews-", format(Sys.time(), "%Y%m%d%H%M%OS3"))
  marca <- gsub("[^A-Za-z0-9-]", "", marca)

  creados <- lapply(1:3, function(i) {
    fhir_crear(con, list(
      resourceType = "Patient",
      identifier = list(list(system = "https://f-slg.github.io/fhirviews/prueba",
                             value = paste0(marca, "-", i))),
      name = list(list(family = "Paredes Cevallos",
                       given = list(paste0("Prueba", i)))),
      gender = if (i == 1) "female" else "male",
      birthDate = "1985-03-12"
    ))
  })
  on.exit(for (p in creados) try(fhir_borrar(con, p), silent = TRUE), add = TRUE)
  expect_true(all(vapply(creados, function(p) es_texto(p$id), logical(1))))

  encontrados <- fhir_buscar(
    con, "Patient",
    identifier = paste0("https://f-slg.github.io/fhirviews/prueba|", marca, "-1"),
    progreso = FALSE)
  expect_length(encontrados, 1L)

  # Paginación real: _count = 1 obliga a seguir los enlaces next
  todos <- fhir_buscar(con, "Patient", family = "Paredes Cevallos",
                       `_count` = 1, max_paginas = 3, progreso = FALSE)
  expect_length(todos, 3L)

  p <- creados[[1]]
  p$telecom <- list(list(system = "phone", value = "0991234567"))
  actualizado <- fhir_actualizar(con, p)
  expect_identical(actualizado$telecom[[1]]$value, "0991234567")
  expect_identical(actualizado$meta$versionId, "2")
  expect_identical(fhir_leer(con, "Patient", p$id, version = "1")$meta$versionId,
                   "1")

  todo <- fhir_everything(con, "Patient", p$id, progreso = FALSE)
  expect_true(p$id %in% vapply(todo, `[[`, "", "id"))

  v <- fhir_validar(con, list(resourceType = "Patient", gender = "mujer"))
  expect_false(attr(v, "valido"))

  fhir_borrar(con, creados[[3]])
  expect_error(fhir_leer(con, "Patient", creados[[3]]$id),
               class = "fhirviews_error_http")
})
