con_piloto <- function(codigo, perfil = "basico") {
  anterior <- Sys.getenv(c("FHIRVIEWS_PILOTO_SALIDA", "FHIRVIEWS_PILOTO_PERFIL", "TZ"),
                         unset = NA_character_)
  on.exit(for (nombre in names(anterior)) {
    if (is.na(anterior[[nombre]])) Sys.unsetenv(nombre) else
      do.call(Sys.setenv, stats::setNames(list(anterior[[nombre]]), nombre))
  }, add = TRUE)
  carpeta <- tempfile("piloto-test-")
  on.exit(unlink(carpeta, recursive = TRUE), add = TRUE)
  Sys.setenv(FHIRVIEWS_PILOTO_SALIDA = carpeta, FHIRVIEWS_PILOTO_PERFIL = perfil, TZ = "UTC")
  codigo(carpeta, system.file("examples", "piloto.R", package = "fhirviews"))
}

test_that("el piloto basico distingue aprobacion tecnica y validacion de usuarios", {
  con_piloto(function(carpeta, script) {
    expect_output(source(script), "Informe local del piloto")
    resultado <- jsonlite::read_json(file.path(carpeta, "aceptacion.json"))
    expect_identical(resultado$resultado_tecnico, "aprobado")
    expect_identical(resultado$validacion_usuario_externo, "pendiente")
    expect_identical(resultado$perfil, "basico")
    expect_equal(resultado$hallazgos$vigilancia$eventos_confirmados, 661)
    expect_equal(resultado$hallazgos$contrato_estricto$bloque_rechazado, 2)
    expect_equal(resultado$hallazgos$contrato_estricto$bloques_entregados, 1)
    expect_true(file.exists(file.path(carpeta, "experiencia-usuario.txt")))
    expect_identical(resultado$controles[[4]]$estado, "no_evaluado")
    expect_true(all(vapply(resultado$controles[1:3], function(x) x$estado == "aprobado", logical(1))))
    expect_true(file.exists(file.path(carpeta, "vigilancia", "casos_confirmados.csv")))
    expect_error(source(script), "ya existe")
  })
})

test_that("un fallo del piloto deja evidencia y no puede declararse aprobado", {
  con_piloto(function(carpeta, script) {
    local_mocked_bindings(vista_ejecutar_lotes = function(..., estricto = FALSE) stop("detalle privado"))
    expect_error(source(script), "contrato_estricto")
    resultado <- jsonlite::read_json(file.path(carpeta, "aceptacion.json"))
    expect_identical(resultado$resultado_tecnico, "no_aprobado")
    expect_identical(resultado$controles[[3]]$estado, "fallo")
    expect_true(file.exists(file.path(carpeta, "experiencia-usuario.txt")))
    expect_false(grepl("detalle privado", paste(readLines(file.path(carpeta, "aceptacion.json")), collapse = "")))
  })
})

test_that("el perfil completo verifica tambien la recuperacion transaccional", {
  skip_if_not_installed("DBI")
  skip_if_not_installed("duckdb", "1.3.0")
  con_piloto(function(carpeta, script) {
    expect_output(source(script), "Rollback verificado")
    resultado <- jsonlite::read_json(file.path(carpeta, "aceptacion.json"))
    expect_identical(resultado$resultado_tecnico, "aprobado")
    expect_true(all(vapply(resultado$controles, function(x) x$estado == "aprobado", logical(1))))
  }, "completo")
})

test_that("las advertencias requieren revision sin exponer sus mensajes", {
  con_piloto(function(carpeta, script) {
    original <- vista_ejecutar
    local_mocked_bindings(vista_ejecutar = function(...) {
      warning("mensaje privado que no debe registrarse", call. = FALSE)
      original(...)
    })
    expect_error(source(script), "requiere revision")
    texto <- paste(readLines(file.path(carpeta, "aceptacion.json")), collapse = "")
    r <- jsonlite::fromJSON(texto, simplifyVector = FALSE)
    expect_identical(r$resultado_tecnico, "requiere_revision")
    expect_identical(r$controles[[2]]$estado, "requiere_revision")
    expect_equal(r$controles[[2]]$advertencias, 2)
    expect_length(r$advertencias, 2L)
    expect_false(grepl("mensaje privado", texto, fixed = TRUE))
    expect_true(file.exists(file.path(carpeta, "experiencia-usuario.txt")))
  })
})

test_that("detecta errores de asignacion aunque se conserven los totales", {
  escenarios <- c(evento = "evento_referencia_incorrecto",
                   canton = "conteo_territorial_incorrecto",
                   mes = "conteo_mensual_incorrecto")
  for (escenario in names(escenarios)) local({
    modo <- escenario
    con_piloto(function(carpeta, script) {
      leer <- utils::read.csv
      local_mocked_bindings(read.csv = function(file, ...) {
        x <- leer(file, ...)
        if (modo == "evento" && basename(file) == "casos_confirmados.csv") {
          x$codigo_dpa[x$id == "den-c0001"] <- "0702"
        }
        objetivo <- if (modo == "canton") "resumen_canton.csv" else
          if (modo == "mes") "resumen_mensual.csv" else ""
        if (basename(file) == objetivo) {
          # Intercambiar dos conteos conserva el total y el numero de filas.
          x$casos[1:2] <- rev(x$casos[1:2])
        }
        x
      }, .package = "utils")
      expect_error(source(script), "vigilancia")
      r <- jsonlite::read_json(file.path(carpeta, "aceptacion.json"))
      expect_identical(r$resultado_tecnico, "no_aprobado")
      expect_identical(r$diagnosticos$vigilancia$codigo, unname(escenarios[[modo]]))
      if (modo == "canton") {
        expect_identical(r$diagnosticos$vigilancia$referencia, "0701")
        expect_equal(r$diagnosticos$vigilancia$esperado, 55)
        expect_equal(r$diagnosticos$vigilancia$observado, 1)
      }
      if (modo == "mes") {
        expect_identical(r$diagnosticos$vigilancia$referencia, "2025-01")
        expect_equal(r$diagnosticos$vigilancia$esperado, 5)
        expect_equal(r$diagnosticos$vigilancia$observado, 73)
      }
    })
  })
})

test_that("un total incorrecto conserva un diagnostico numerico seguro", {
  con_piloto(function(carpeta, script) {
    leer <- utils::read.csv
    local_mocked_bindings(read.csv = function(file, ...) {
      x <- leer(file, ...)
      if (basename(file) == "casos_confirmados.csv") x <- x[-1L, , drop = FALSE]
      x
    }, .package = "utils")
    expect_error(source(script), "vigilancia")
    r <- jsonlite::read_json(file.path(carpeta, "aceptacion.json"))
    expect_identical(r$diagnosticos$vigilancia$codigo, "total_eventos_incorrecto")
    expect_equal(r$diagnosticos$vigilancia$esperado, 661)
    expect_equal(r$diagnosticos$vigilancia$observado, 660)
  })
})
