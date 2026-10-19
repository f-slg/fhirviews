# Pruebas de terminologías con respuestas simuladas (sin red)

sis_cie <- "http://hl7.org/fhir/sid/icd-10"
url_vs <- "http://ejemplo.org/ValueSet/diabetes"

# Expansión de 5 códigos que el servidor entrega por páginas
expansion_simulada <- function(req, ruta, total = 5L, ignorar_offset = FALSE) {
  q <- httr2::url_parse(req$url)$query
  desde <- if (ignorar_offset) 0L else as.integer(q$offset)
  cuantos <- as.integer(q$count)
  todos <- lapply(seq_len(total), function(i) {
    list(system = sis_cie, code = paste0("E1", i - 1L),
         display = paste("Diabetes", i), version = "2019")
  })
  pagina <- todos[seq_along(todos) > desde &
                    seq_along(todos) <= desde + cuantos]
  respuesta_fhir(list(resourceType = "ValueSet", url = url_vs,
                      expansion = list(identifier = "x", total = total,
                                       offset = desde, contains = pagina)))
}

test_that("tx_expandir pagina con offset y count", {
  p <- simular(function(req, ruta) expansion_simulada(req, ruta))
  con <- con_simulada()
  vs <- tx_expandir(con, url_vs, tamano_pagina = 2, filtro = "diab",
                    parametros = list(displayLanguage = "es"))
  expect_s3_class(vs, "data.frame")
  expect_identical(names(vs), c("system", "code", "display", "version"))
  expect_identical(vs$code, c("E10", "E11", "E12", "E13", "E14"))
  expect_identical(attr(vs, "total"), 5L)
  expect_identical(attr(vs, "valueset"), url_vs)
  expect_identical(attr(vs, "expansion")$identifier, "x")
  expect_length(p$lista, 3L)
  urls <- vapply(p$lista, function(r) utils::URLdecode(r$url), "")
  expect_match(urls[1], "ValueSet/\\$expand\\?url=.*&displayLanguage=es&filter=diab")
  expect_match(urls[1], "url=http://ejemplo.org/ValueSet/diabetes")
  expect_match(urls, "count=2")
  expect_match(urls[3], "offset=4")

  # max corta la descarga y el tamano de la ultima pagina
  vs3 <- tx_expandir(con, url_vs, max = 3, tamano_pagina = 2)
  expect_identical(vs3$code, c("E10", "E11", "E12"))
  expect_match(utils::URLdecode(p$lista[[5]]$url), "offset=2&count=1")

  expect_error(tx_expandir(con, url_vs, max = 0), class = "fhirviews_error")
  expect_error(tx_expandir(list(), url_vs), class = "fhirviews_error")
})

test_that("tx_expandir avisa si el servidor ignora offset", {
  simular(function(req, ruta) expansion_simulada(req, ruta,
                                                 ignorar_offset = TRUE))
  expect_warning(vs <- tx_expandir(con_simulada(), url_vs, tamano_pagina = 2),
                 class = "fhirviews_aviso")
  expect_identical(vs$code, c("E10", "E11"))
})

test_that("tx_expandir aplana jerarquias y omite codigos abstractos", {
  simular(function(req, ruta) respuesta_fhir(list(
    resourceType = "ValueSet", expansion = list(contains = list(
      list(system = sis_cie, code = "E10-E14", abstract = TRUE,
           contains = list(list(system = sis_cie, code = "E10"),
                           list(system = sis_cie, code = "E11",
                                display = "Tipo 2"))))))))
  vs <- tx_expandir(con_simulada(), url_vs)
  expect_identical(vs$code, c("E10", "E11"))
  expect_identical(vs$display, c(NA, "Tipo 2"))
  expect_false("version" %in% names(vs))
  expect_null(attr(vs, "total"))
})

test_that("tx_expandir envia un ValueSet propio por POST", {
  p <- simular(function(req, ruta) respuesta_fhir(list(
    resourceType = "ValueSet", expansion = list(total = 1, contains = list(
      list(system = sis_cie, code = "E11"))))))
  propio <- list(resourceType = "ValueSet", compose = list(include = list(
    list(system = sis_cie, concept = list(list(code = "E11"))))))
  vs <- tx_expandir(con_simulada(), propio, filtro = "tipo")
  expect_identical(vs$code, "E11")
  req <- p$lista[[1]]
  expect_identical(req$method, "POST")
  cuerpo <- jsonlite::fromJSON(cuerpo_req(req), simplifyVector = FALSE)
  expect_identical(cuerpo$resourceType, "Parameters")
  nombres <- vapply(cuerpo$parameter, `[[`, "", "name")
  expect_identical(nombres, c("valueSet", "filter", "offset", "count"))
  expect_identical(cuerpo$parameter[[1]]$resource$compose$include[[1]]$system,
                   sis_cie)
  expect_identical(cuerpo$parameter[[3]]$valueInteger, 0L)

  # Tambien como texto JSON
  json <- as.character(jsonlite::toJSON(propio, auto_unbox = TRUE))
  expect_identical(tx_expandir(con_simulada(), json)$code, "E11")
  expect_error(tx_expandir(con_simulada(), list(resourceType = "CodeSystem")),
               class = "fhirviews_error")
})

test_that("los errores del servidor muestran el OperationOutcome", {
  simular(function(req, ruta) {
    respuesta_fhir(oo("ValueSet desconocido: http://x"), estado = 404L)
  })
  con <- con_simulada()
  expect_error(tx_expandir(con, "http://x"), "ValueSet desconocido",
               class = "fhirviews_error_http_404")
  expect_error(tx_buscar_codigo(con, sis_cie, "Z"),
               class = "fhirviews_error_http")
  expect_error(tx_validar_codigo(con, "http://x", sis_cie, "Z"),
               class = "fhirviews_error_http")

  simular(function(req, ruta) respuesta_fhir(paciente("p1")))
  expect_error(tx_expandir(con_simulada(), url_vs), "ValueSet expandido",
               class = "fhirviews_error")
})

test_that("tx_buscar_codigo devuelve display, designaciones y propiedades", {
  p <- simular(function(req, ruta) respuesta_fhir(list(
    resourceType = "Parameters", parameter = list(
      list(name = "name", valueString = "LOINC"),
      list(name = "version", valueString = "2.77"),
      list(name = "display", valueString = "Glucose [Mass/volume]"),
      list(name = "designation", part = list(
        list(name = "language", valueCode = "es"),
        list(name = "use", valueCoding = list(
          system = "http://snomed.info/sct", code = "900000000000013009",
          display = "Synonym")),
        list(name = "value", valueString = "Glucosa"))),
      list(name = "property", part = list(
        list(name = "code", valueCode = "COMPONENT"),
        list(name = "value", valueString = "Glucose"))),
      list(name = "property", part = list(
        list(name = "code", valueCode = "parent"),
        list(name = "value", valueCode = "LP1"),
        list(name = "description", valueString = "Padre")))))))
  r <- tx_buscar_codigo(con_simulada(), "http://loinc.org", "2345-7",
                        version = "2.77", propiedades = c("COMPONENT", "parent"))
  expect_identical(r$display, "Glucose [Mass/volume]")
  expect_identical(r$nombre, "LOINC")
  expect_identical(r$version, "2.77")
  expect_identical(r$designaciones$valor, "Glucosa")
  expect_identical(r$designaciones$idioma, "es")
  expect_match(r$designaciones$uso, "900000000000013009 \\(Synonym\\)")
  expect_identical(r$propiedades$propiedad, c("COMPONENT", "parent"))
  expect_identical(r$propiedades$valor, c("Glucose", "LP1"))
  expect_identical(r$propiedades$descripcion, c(NA, "Padre"))
  expect_identical(attr(r, "respuesta")$resourceType, "Parameters")
  url <- utils::URLdecode(p$lista[[1]]$url)
  expect_match(url, "CodeSystem/\\$lookup\\?system=http://loinc.org&code=2345-7")
  expect_match(url, "property=COMPONENT&property=parent")
  expect_error(tx_buscar_codigo(con_simulada(), "http://loinc.org", ""),
               class = "fhirviews_error")
})

test_that("tx_validar_codigo valida cada codigo", {
  p <- simular(function(req, ruta) {
    valido <- grepl("code=E11", ruta)
    parametros <- list(list(name = "result", valueBoolean = valido))
    if (valido) {
      parametros <- c(parametros, list(list(name = "display",
                                            valueString = "Tipo 2")))
    } else {
      parametros <- c(parametros, list(list(name = "message",
                                            valueString = "No est\u00e1")))
    }
    respuesta_fhir(list(resourceType = "Parameters", parameter = parametros))
  })
  r <- tx_validar_codigo(con_simulada(), url_vs, sis_cie, c("E11", "I10"),
                         display = c("Tipo 2", NA))
  expect_identical(r$valido, c(TRUE, FALSE))
  expect_identical(r$display, c("Tipo 2", NA))
  expect_identical(r$mensaje, c(NA, "No est\u00e1"))
  expect_identical(r$sistema, c(sis_cie, sis_cie))
  urls <- vapply(p$lista, function(r) utils::URLdecode(r$url), "")
  expect_match(urls[1], "ValueSet/\\$validate-code\\?url=")
  expect_match(urls[1], "display=Tipo 2")
  expect_false(grepl("display", urls[2]))
  expect_error(tx_validar_codigo(con_simulada(), url_vs, c("a", "b", "c"),
                                 c("E11", "I10")),
               class = "fhirviews_error")
  expect_error(tx_validar_codigo(con_simulada(), url_vs, sis_cie, 11),
               class = "fhirviews_error")
})

test_that("las operaciones usan el token de la conexion", {
  p <- simular(function(req, ruta) expansion_simulada(req, ruta))
  tx_expandir(con_simulada(token = "abc"), url_vs)
  expect_match(httr2::req_get_headers(p$lista[[1]], "reveal")$Authorization,
               "Bearer abc")
})

condiciones_prueba <- function() {
  cond <- function(id, sistema, codigo) {
    list(resourceType = "Condition", id = id,
         subject = list(reference = paste0("Patient/p", id)),
         code = list(coding = list(list(system = sistema, code = codigo))))
  }
  list(cond("1", sis_cie, "E11"), cond("2", sis_cie, "I10"),
       cond("3", "http://snomed.info/sct", "44054006"),
       cond("4", "http://otro", "E11"), cond("5", sis_cie, "O'1"))
}

expansion_prueba <- data.frame(
  system = c(sis_cie, sis_cie, "http://snomed.info/sct", sis_cie),
  code = c("E10", "E11", "44054006", "O'1")
)

test_that("vista_con_valueset filtra con constantes", {
  vista <- vista_crear("Condition", c(codigo = "code.coding.first().code"))
  v <- vista_con_valueset(vista, expansion_prueba, nombre = "dm")
  expect_s3_class(v, "fhir_vista")
  nombres <- vapply(v$constant, `[[`, "", "name")
  expect_identical(nombres, c("dm_sistema_1", "dm_codigos_1",
                              "dm_sistema_2", "dm_codigos_2"))
  expect_identical(v$constant[[2]]$valueString, "|E10|E11|O'1|")
  expect_match(v$where[[1]]$path, "^code\\.coding\\.where\\(\\(system = %dm_sistema_1")
  df <- vista_ejecutar(condiciones_prueba(), v)
  expect_identical(df$id, c("1", "3", "5"))

  # Un solo sistema, sin sufijos
  v1 <- vista_con_valueset(vista, expansion_prueba[1:2, ])
  expect_identical(vapply(v1$constant, `[[`, "", "name"),
                   c("vs_sistema", "vs_codigos"))
  expect_identical(
    v1$where[[1]]$path,
    "code.coding.where(system = %vs_sistema and %vs_codigos.contains('|' & code & '|')).exists()"
  )
  # Las vistas encadenadas acumulan condiciones
  v2 <- vista_con_valueset(v1, expansion_prueba[3, ], nombre = "otro")
  expect_length(v2$where, 2L)
  expect_identical(nrow(vista_ejecutar(condiciones_prueba(), v2)), 0L)
})

test_that("vista_con_valueset puede agregar una columna en vez de filtrar", {
  vista <- vista_crear("Condition", c(codigo = "code.coding.first().code"),
                       por_cada = "code.coding")
  v <- vista_con_valueset(vista, expansion_prueba, columna = "diabetes")
  expect_null(v$where)
  df <- vista_ejecutar(condiciones_prueba(), v)
  expect_identical(df$diabetes, c(TRUE, FALSE, TRUE, FALSE, TRUE))
  expect_error(vista_con_valueset(v, expansion_prueba, nombre = "otro",
                                  columna = "diabetes"),
               class = "fhirviews_error")
})

test_that("vista_con_valueset revisa sus argumentos", {
  vista <- vista_crear("Condition", c(codigo = "code.coding.first().code"))
  expect_error(vista_con_valueset(vista, list(code = "a")),
               class = "fhirviews_error")
  expect_error(vista_con_valueset(vista, expansion_prueba[0, ]),
               class = "fhirviews_error")
  expect_error(vista_con_valueset(vista, data.frame(system = NA, code = "a")),
               class = "fhirviews_error")
  expect_error(vista_con_valueset(vista, data.frame(system = "s", code = "a|b")),
               class = "fhirviews_error")
  expect_error(vista_con_valueset(vista, expansion_prueba, nombre = "1x"),
               class = "fhirviews_error")
  v <- vista_con_valueset(vista, expansion_prueba[1, ])
  expect_error(vista_con_valueset(v, expansion_prueba[1, ]),
               class = "fhirviews_error")
})

test_that("vista_con_valueset funciona con el motor DuckDB", {
  skip_on_cran()
  skip_if_not_installed("DBI")
  skip_if_not_installed("duckdb", "1.3.0")
  json_disponible <- tryCatch({
    con <- conectar_duckdb()
    cargar_json_duckdb(con)
    DBI::dbDisconnect(con)
    TRUE
  }, error = function(e) FALSE)
  skip_if_not(json_disponible, "la extensi\u00f3n json de DuckDB no est\u00e1 disponible")
  vista <- vista_crear("Condition", c(codigo = "code.coding.first().code"))
  archivo <- withr_tempfile(".ndjson")
  writeLines(vapply(condiciones_prueba(), function(x) {
    as.character(jsonlite::toJSON(x, auto_unbox = TRUE))
  }, ""), archivo)
  v <- vista_con_valueset(vista, expansion_prueba)
  df <- vista_ejecutar_duckdb(archivo, v)
  expect_identical(df$id, c("1", "3", "5"))
  vc <- vista_con_valueset(vista, expansion_prueba, columna = "dm")
  dfc <- vista_ejecutar_duckdb(archivo, vc)
  expect_identical(dfc$dm, c(TRUE, FALSE, TRUE, FALSE, TRUE))
})

test_that("terminologia real con tx.fhir.org", {
  skip_on_cran()
  skip_if_offline("tx.fhir.org")
  skip_if_not(fhir_disponible("https://tx.fhir.org/r4", tiempo = 10))
  tx <- fhir_conectar("https://tx.fhir.org/r4", panel = FALSE)
  sexo <- tx_expandir(tx, "http://hl7.org/fhir/ValueSet/administrative-gender")
  expect_true(all(c("male", "female") %in% sexo$code))
  v <- tx_validar_codigo(tx, "http://hl7.org/fhir/ValueSet/administrative-gender",
                         "http://hl7.org/fhir/administrative-gender",
                         c("female", "mujer"))
  expect_identical(v$valido, c(TRUE, FALSE))
  lk <- tx_buscar_codigo(tx, "http://hl7.org/fhir/administrative-gender",
                         "female")
  expect_identical(lk$display, "Female")
})
