archivo_alergias <- function() {
  system.file("extdata", "alergias_r4.ndjson", package = "fhirviews")
}

test_that("alergias conserva eventos, categorias y codificaciones sin mezclarlas", {
  v <- vista_plantilla("alergias")
  expect_no_error(vista_validar(v))
  x <- vista_ejecutar(archivo_alergias(), v)
  expect_identical(x$id, c("a1", "a1", "a1", "a2", "a3"))
  expect_identical(x$paciente, c("p1", "p1", "p1", "p2", "p3"))
  expect_identical(x$encuentro, c("e1", "e1", "e1", NA_character_, NA_character_))
  expect_identical(x$estado_clinico, c("active", "active", "active", NA_character_, "inactive"))
  expect_identical(x$verificacion, c(rep("confirmed", 3), "entered-in-error", NA_character_))
  expect_identical(x$criticidad, c(rep("high", 3), NA_character_, NA_character_))
  expect_identical(x$categoria, c(rep(list(c("food", "medication")), 3),
    list("environment", character())))
  expect_identical(x$fecha_registro, c(rep("2026-01-14", 3), NA_character_, NA_character_))
  expect_identical(x$gravedad_reaccion, c("severe", "severe", "mild", NA_character_, NA_character_))
  expect_identical(x$fecha_reaccion, c(rep("2026-01-13T10:00:00Z", 2),
    "2026-01-10", NA_character_, NA_character_))
  expect_identical(x$descripcion_reaccion, c(rep("Evento ficticio 1", 2),
    "Evento ficticio 2", NA_character_, NA_character_))
  expect_identical(x$reaccion_codigo, c("M1", "M2", "M3", NA_character_, NA_character_))
  expect_identical(x$reaccion, c(paste("Manifestación ficticia", 1:3), NA_character_, NA_character_))
  # El primer Coding de a3 no tiene code: no se le asigna el code del segundo.
  expect_identical(x$sustancia_codigo, c(rep("A", 3), NA_character_, NA_character_))
  expect_identical(x$sustancia_sistema[5], "urn:ejemplo:primero")
  expect_identical(x$sustancia_descripcion[5], "Sin código")
  expect_identical(length(unique(x$id)), 3L)
})

test_that("alergias permite elegir sistemas de estado y conserva una salida vacia tipada", {
  v <- vista_plantilla("alergias",
    constantes = list(sistema_estado_clinico = "urn:ejemplo:traducciones"))
  x <- vista_ejecutar(archivo_alergias(), v)
  expect_identical(x$estado_clinico, c(rep("activo", 3), NA_character_, NA_character_))
  vacia <- vista_ejecutar(list(list(resourceType = "Patient", id = "p1")), v)
  expect_identical(nrow(vacia), 0L)
  expect_identical(names(vacia), names(x))
  expect_type(vacia$categoria, "list")
  # Es una vista de lectura; no habilita un nuevo constructor SQL a FHIR.
  expect_error(fhir_mapa("AllergyIntolerance", c(id = "id")), class = "fhirviews_error_mapeo")
})

test_that("alergias conserva todos los datos con V8 y DuckDB", {
  skip_on_cran()
  skip_if_not_installed("DBI")
  skip_if_not_installed("duckdb", "1.5.5")
  v <- vista_plantilla("alergias")
  v8 <- vista_ejecutar(archivo_alergias(), v)
  sql <- vista_ejecutar_duckdb(archivo_alergias(), v)
  expect_identical(as.list(sql), as.list(v8))
  expect_identical(nrow(sql), 5L)
})

test_that("alergias mantiene sus relaciones al procesar un recurso por bloque", {
  tablas <- list()
  vista_ejecutar_lotes(archivo_alergias(), vista_plantilla("alergias"),
    function(tabla, bloque) {
      tablas[[bloque]] <<- tabla
      invisible(NULL)
    }, tamano_lote = 1L, estricto = TRUE)
  expect_identical(vapply(tablas, nrow, integer(1)), c(3L, 1L, 1L))
  completa <- vista_ejecutar(archivo_alergias(), vista_plantilla("alergias"))
  expect_identical(as.list(do.call(rbind, tablas)), as.list(completa))
})
