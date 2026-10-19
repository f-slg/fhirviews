# Pruebas de la exportación masiva (FHIR Bulk Data) con respuestas simuladas

ndjson <- function(...) {
  lineas <- vapply(list(...), function(r) {
    as.character(jsonlite::toJSON(r, auto_unbox = TRUE))
  }, "")
  httr2::response(status_code = 200L,
                  headers = list(`Content-Type` = "application/fhir+ndjson"),
                  body = charToRaw(paste0(paste(lineas, collapse = "\n"), "\n")))
}

manifiesto <- function(token = TRUE, error = list()) {
  list(
    transactionTime = "2025-06-01T10:00:00Z",
    request = paste0(base, "/Patient/$export"),
    requiresAccessToken = token,
    output = list(
      list(type = "Patient", url = paste0(base, "/archivos/p.ndjson"), count = 2),
      list(type = "Condition", url = paste0(base, "/archivos/c.ndjson"), count = 1)
    ),
    error = error
  )
}

# Ciclo completo: inicio -> 202 -> 202 con Retry-After -> 200 -> archivos
servidor_exportacion <- function(estado_final = NULL, envir = parent.frame()) {
  consultas <- 0L
  simular(function(req, ruta) {
    if (grepl("\\$export", ruta)) {
      return(respuesta_fhir(NULL, 202L, list(
        `Content-Location` = paste0(base, "/estado/42"))))
    }
    if (ruta == "estado/42") {
      if (req$method == "DELETE") return(respuesta_fhir(NULL, 202L))
      consultas <<- consultas + 1L
      if (consultas == 1L) {
        return(respuesta_fhir(NULL, 202L, list(`X-Progress` = "en cola")))
      }
      if (consultas == 2L) {
        return(respuesta_fhir(NULL, 202L, list(`X-Progress` = "50%",
                                               `Retry-After` = "7")))
      }
      if (!is.null(estado_final)) return(estado_final)
      return(respuesta_fhir(manifiesto()))
    }
    if (ruta == "archivos/p.ndjson") {
      return(ndjson(list(resourceType = "Patient", id = "p1", gender = "female"),
                    list(resourceType = "Patient", id = "p2", gender = "male")))
    }
    if (ruta == "archivos/c.ndjson") {
      return(ndjson(list(resourceType = "Condition", id = "c1",
                         subject = list(reference = "Patient/p1"))))
    }
    if (ruta == "archivos/e.ndjson") {
      return(ndjson(oo("Faltan permisos para Observation", "warning")))
    }
    respuesta_fhir(oo("no encontrado"), 404L)
  }, envir = envir)
}

simular_espera <- function(envir = parent.frame()) {
  esperas <- new.env()
  esperas$s <- numeric()
  local_mocked_bindings(dormir = function(s) esperas$s <- c(esperas$s, s),
                        .env = envir)
  esperas
}

test_that("fhir_exportar sigue el ciclo de Bulk Data y descarga los NDJSON", {
  p <- servidor_exportacion()
  esperas <- simular_espera()
  con <- con_simulada(token = "abc")
  carpeta <- withr_tempfile()
  exp <- fhir_exportar(con, "paciente", tipos = c("Patient", "Condition"),
                       desde = as.Date("2025-01-01"),
                       filtros = c("Condition?code=A90", "Patient?active=true"),
                       carpeta = carpeta, progreso = FALSE)

  expect_s3_class(exp, "fhir_exportacion")
  expect_identical(exp$estado, "completada")
  expect_identical(names(exp$archivos), c("Patient", "Condition"))
  expect_true(all(file.exists(unlist(exp$archivos))))
  expect_identical(exp$progreso, "50%")
  expect_identical(exp$manifiesto$transactionTime, "2025-06-01T10:00:00Z")

  # Inicio: Patient/$export, Prefer respond-async, Accept fhir+json
  inicio <- p$lista[[1]]
  expect_match(inicio$url, "/Patient/\\$export\\?")
  expect_match(inicio$url, "_type=Patient%2CCondition")
  expect_match(inicio$url, "_since=2025-01-01T00%3A00%3A00Z")
  expect_match(inicio$url, "_typeFilter=Condition.*_typeFilter=Patient")
  expect_identical(inicio$headers$Prefer, "respond-async")
  expect_identical(inicio$headers$Accept, "application/fhir+json")

  # Esperas: 1 s sin Retry-After, luego los 7 s que pide el servidor
  expect_identical(esperas$s, c(1, 7))

  # Descarga: NDJSON con el token (requiresAccessToken = true)
  descarga <- p$lista[[5]]
  expect_match(descarga$url, "archivos/p.ndjson$")
  expect_identical(descarga$headers$Accept, "application/fhir+ndjson")
  expect_match(httr2::req_get_headers(descarga, "reveal")$Authorization,
               "Bearer abc")

  # Los archivos se leen y se usan en vistas
  pacientes <- vista_ejecutar(exp$archivos$Patient,
                              vista_crear("Patient", c(sexo = "gender")))
  expect_identical(pacientes$sexo, c("female", "male"))
  expect_length(fhir_recursos(unlist(exp$archivos)), 3L)

  salida <- capture.output(print(exp))
  expect_match(salida[1], "completada")
  expect_true(any(grepl("Patient.*1 archivo, 2 recursos", salida)))
  expect_false(any(grepl("abc", salida)))
})

test_that("sin requiresAccessToken no se env\u00eda el token a los archivos", {
  p <- servidor_exportacion(respuesta_fhir(manifiesto(token = FALSE)))
  simular_espera()
  exp <- fhir_exportar(con_simulada(token = "abc"), carpeta = withr_tempfile(),
                       progreso = FALSE)
  expect_identical(exp$nivel, "sistema")
  expect_match(p$lista[[1]]$url, "/fhir/\\$export$")
  descarga <- p$lista[[length(p$lista)]]
  expect_match(descarga$url, "archivos/c.ndjson$")
  expect_null(httr2::req_get_headers(descarga, "reveal")$Authorization)
})

test_that("el modo as\u00edncrono consulta el estado y cancela", {
  p <- servidor_exportacion()
  simular_espera()
  con <- con_simulada()
  trabajo <- fhir_exportar(con, grupo = "brote-2025", esperar = FALSE,
                           carpeta = withr_tempfile())
  expect_identical(trabajo$estado, "en_curso")
  expect_identical(trabajo$nivel, "grupo")
  expect_match(p$lista[[1]]$url, "/Group/brote-2025/\\$export$")
  expect_identical(trabajo$url_estado, paste0(base, "/estado/42"))
  expect_match(capture.output(print(trabajo))[1], "en curso")

  trabajo <- fhir_exportar_estado(trabajo, progreso = FALSE)
  expect_identical(trabajo$estado, "en_curso")
  expect_identical(trabajo$progreso, "en cola")
  expect_length(p$lista, 2L)

  cancelada <- fhir_exportar_cancelar(trabajo)
  expect_identical(cancelada$estado, "cancelada")
  expect_identical(p$lista[[3]]$method, "DELETE")
  expect_match(p$lista[[3]]$url, "estado/42$")
  expect_error(fhir_exportar_estado(cancelada),
               class = "fhirviews_error_exportacion")

  # Seguir esperando hasta el final
  trabajo <- fhir_exportar_estado(trabajo, esperar = TRUE, progreso = FALSE)
  expect_identical(trabajo$estado, "completada")
  expect_length(trabajo$archivos, 2L)
  expect_error(fhir_exportar_estado(list()), class = "fhirviews_error")
})

test_that("los errores del servidor se informan con el OperationOutcome", {
  # Fallo de la exportación en la consulta de estado
  servidor_exportacion(respuesta_fhir(oo("Sin espacio en disco"), 500L))
  simular_espera()
  con <- con_simulada()
  e <- expect_error(fhir_exportar(con, carpeta = withr_tempfile(),
                                  progreso = FALSE),
                    class = "fhirviews_error_exportacion")
  expect_s3_class(e, "fhirviews_error_http_500")
  expect_match(conditionMessage(e), "Sin espacio en disco")

  # Respuesta 200 que no es un manifiesto
  servidor_exportacion(respuesta_fhir(list(resourceType = "Bundle")))
  expect_error(fhir_exportar(con, carpeta = withr_tempfile(), progreso = FALSE),
               class = "fhirviews_error_exportacion")

  # Inicio rechazado (servidor sin $export)
  simular(function(req, ruta) respuesta_fhir(oo("$export no admitido"), 400L))
  expect_error(fhir_exportar(con, progreso = FALSE),
               class = "fhirviews_error_http_400")

  # Inicio sin Content-Location
  simular(function(req, ruta) respuesta_fhir(NULL, 202L))
  expect_error(fhir_exportar(con, progreso = FALSE),
               class = "fhirviews_error_exportacion")

  # Archivo que no se puede descargar
  m <- manifiesto(token = FALSE)
  m$output[[1]]$url <- paste0(base, "/archivos/no-existe.ndjson")
  servidor_exportacion(respuesta_fhir(m))
  carpeta <- withr_tempfile()
  expect_error(fhir_exportar(con, carpeta = carpeta, progreso = FALSE),
               class = "fhirviews_error_http_404")
  expect_length(list.files(carpeta), 0L)

  # Argumentos
  expect_error(fhir_exportar(con, "grupo"), class = "fhirviews_error")
  expect_error(fhir_exportar(con, tipos = 1), class = "fhirviews_error")
  expect_error(fhir_exportar(list()), class = "fhirviews_error")
})

test_that("los archivos de error del manifiesto se descargan y se avisan", {
  m <- manifiesto(error = list(list(type = "OperationOutcome",
                                    url = paste0(base, "/archivos/e.ndjson"))))
  servidor_exportacion(respuesta_fhir(m))
  simular_espera()
  expect_warning(
    exp <- fhir_exportar(con_simulada(), carpeta = withr_tempfile(),
                         progreso = FALSE),
    "Faltan permisos", class = "fhirviews_aviso"
  )
  expect_length(exp$errores, 1L)
  expect_true(file.exists(exp$errores))
  expect_length(exp$archivos, 2L)
})

test_that("el token no se env\u00eda a archivos de otro servidor", {
  m <- manifiesto(token = TRUE)
  m$output[[1]]$url <- "https://almacen.otro.test/p.ndjson"
  servidor_exportacion(respuesta_fhir(m))
  simular_espera()
  expect_error(fhir_exportar(con_simulada(token = "abc"),
                             carpeta = withr_tempfile(), progreso = FALSE),
               "otro servidor", class = "fhirviews_error_exportacion")
})

test_that("se respeta max_espera, intervalo y Retry-After como fecha", {
  servidor_exportacion()
  esperas <- simular_espera()
  con <- con_simulada()
  expect_warning(
    trabajo <- fhir_exportar(con, max_espera = 0.5, progreso = FALSE),
    "sigue en curso", class = "fhirviews_aviso"
  )
  expect_identical(trabajo$estado, "en_curso")
  expect_length(esperas$s, 0L)

  servidor_exportacion()
  esperas <- simular_espera()
  exp <- fhir_exportar(con, intervalo = 3, carpeta = withr_tempfile(),
                       progreso = FALSE)
  expect_identical(esperas$s, c(3, 7))

  expect_identical(segundos_retry_after(list(`retry-after` = "12")), 12)
  local_tiempo <- Sys.getlocale("LC_TIME")
  on.exit(Sys.setlocale("LC_TIME", local_tiempo), add = TRUE)
  Sys.setlocale("LC_TIME", "C")
  futuro <- format(Sys.time() + 30, "%a, %d %b %Y %H:%M:%S GMT", tz = "GMT")
  expect_true(segundos_retry_after(httr2::resp_headers(httr2::response(
    headers = list(`Retry-After` = futuro)))) > 0)
  expect_identical(segundos_retry_after(list()), NA_real_)
  expect_identical(parametros_exportacion(NULL, as.POSIXct(
    "2025-03-01 12:00:00", tz = "UTC"), NULL)[["_since"]],
    "2025-03-01T12:00:00Z")
})

test_that("exportaci\u00f3n real contra el servidor de referencia de SMART", {
  skip_on_cran()
  skip_if_offline("bulk-data.smarthealthit.org")
  url <- "https://bulk-data.smarthealthit.org/fhir"
  skip_if_not(fhir_disponible(url, tiempo = 10))
  con <- fhir_conectar(url, panel = FALSE)
  exp <- tryCatch(
    fhir_exportar(con, "paciente", tipos = "Patient",
                  carpeta = withr_tempfile(), max_espera = 120,
                  progreso = FALSE),
    fhirviews_error = function(e) skip(conditionMessage(e))
  )
  skip_if(identical(exp$estado, "en_curso"), "El servidor no termin\u00f3 a tiempo")
  expect_true("Patient" %in% names(exp$archivos))
  pacientes <- fhir_recursos(exp$archivos$Patient)
  expect_gt(length(pacientes), 0L)
})
