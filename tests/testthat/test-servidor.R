# Pruebas contra servidores reales. No se ejecutan en CRAN.
#
# * Lectura: el servidor público https://hapi.fhir.org/baseR4.
# * Escritura: solo si la variable de entorno FHIRVIEWS_SERVIDOR_ESCRITURA
#   apunta a un servidor de pruebas propio, por ejemplo un HAPI local con
#   Bulk Data activado:
#     podman run -d -p 8080:8080 -e hapi.fhir.bulk_export_enabled=true \
#       docker.io/hapiproject/hapi:latest
#     FHIRVIEWS_SERVIDOR_ESCRITURA=http://localhost:8080/fhir

publico <- "https://hapi.fhir.org/baseR4"

test_that("lectura y paginacion en el servidor publico", {
  skip_on_cran()
  skip_if_not(fhir_disponible(publico, tiempo = 10), "HAPI público no responde")
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

# URL del servidor de escritura, o se omite la prueba
servidor_escritura <- function() {
  skip_on_cran()
  url <- Sys.getenv("FHIRVIEWS_SERVIDOR_ESCRITURA")
  skip_if(!nzchar(url), "FHIRVIEWS_SERVIDOR_ESCRITURA no está definida")
  skip_if_not(fhir_disponible(url), "El servidor de pruebas no responde")
  url
}

# Texto único por ejecución, para no mezclar datos de ejecuciones anteriores
marca_prueba <- function() {
  gsub("[^A-Za-z0-9]", "",
       paste0("fv", format(Sys.time(), "%Y%m%d%H%M%OS3"),
              sample.int(1e6, 1)))
}

sis_prueba <- "https://f-slg.github.io/fhirviews/prueba"

test_that("ciclo completo de escritura en un servidor de pruebas", {
  con <- fhir_conectar(servidor_escritura(), panel = FALSE)
  marca <- marca_prueba()
  apellido <- paste("Paredes", marca)

  creados <- lapply(1:3, function(i) {
    fhir_crear(con, list(
      resourceType = "Patient",
      identifier = list(list(system = sis_prueba,
                             value = paste0(marca, "-", i))),
      name = list(list(family = apellido,
                       given = list(paste0("Prueba", i)))),
      gender = if (i == 1) "female" else "male",
      birthDate = "1985-03-12"
    ))
  })
  on.exit(for (p in creados) try(fhir_borrar(con, p), silent = TRUE), add = TRUE)
  expect_true(all(vapply(creados, function(p) es_texto(p$id), logical(1))))

  encontrados <- fhir_buscar(
    con, "Patient", identifier = paste0(sis_prueba, "|", marca, "-1"),
    progreso = FALSE)
  expect_length(encontrados, 1L)
  expect_identical(attr(encontrados, "total"), 1L)

  # Paginación real: _count = 1 obliga a seguir los enlaces next
  todos <- fhir_buscar(con, "Patient", family = apellido, `_count` = 1,
                       progreso = FALSE)
  expect_length(todos, 3L)
  expect_setequal(vapply(todos, `[[`, "", "id"),
                  vapply(creados, `[[`, "", "id"))
  dos <- fhir_buscar(con, "Patient", family = apellido, `_count` = 1,
                     max_paginas = 2, progreso = FALSE)
  expect_length(dos, 2L)
  # Un número grande no se envía en notación científica (1e+05)
  expect_length(fhir_buscar(con, "Patient", family = apellido,
                            `_count` = 100000, progreso = FALSE), 3L)

  p <- creados[[1]]
  p$telecom <- list(list(system = "phone", value = "0991234567"))
  actualizado <- fhir_actualizar(con, p)
  expect_identical(actualizado$telecom[[1]]$value, "0991234567")
  expect_identical(actualizado$meta$versionId, "2")
  expect_identical(fhir_leer(con, "Patient", p$id, version = "1")$meta$versionId,
                   "1")
  expect_null(fhir_leer(con, "Patient", p$id, version = "1")$telecom)

  todo <- fhir_everything(con, "Patient", p$id, progreso = FALSE)
  expect_true(p$id %in% vapply(todo, `[[`, "", "id"))

  v <- fhir_validar(con, list(resourceType = "Patient", gender = "mujer"))
  expect_false(attr(v, "valido"))
  expect_true(attr(fhir_validar(con, creados[[2]]), "valido"))

  # fhir_peticion: cualquier petición, con la respuesta completa
  r <- fhir_peticion(con, "GET", paste0("Patient/", p$id))
  expect_identical(attr(r, "estado"), 200L)
  expect_identical(r$id, p$id)

  fhir_borrar(con, creados[[3]])
  expect_error(fhir_leer(con, "Patient", creados[[3]]$id),
               class = "fhirviews_error_http_410")
})

test_that("transaccion, vistas con V8 y DuckDB y fhir_tabla con datos reales", {
  con <- fhir_conectar(servidor_escritura(), panel = FALSE)
  marca <- marca_prueba()
  uuid <- function(n) sprintf("urn:uuid:%08d-0000-4000-8000-%012d", n, n)
  paciente <- list(
    resourceType = "Patient",
    identifier = list(list(system = sis_prueba, value = marca)),
    name = list(list(family = "Salazar Moreno", given = list("Jorge", "Luis"))),
    gender = "male", birthDate = "2001-11-30",
    address = list(list(use = "home", city = "Loja", district = "Loja",
                        state = "Loja"))
  )
  observacion <- function(n, valor) {
    list(resourceType = "Observation", status = "final",
         category = list(list(coding = list(list(
           system = "http://terminology.hl7.org/CodeSystem/observation-category",
           code = "vital-signs")))),
         code = list(coding = list(list(system = "http://loinc.org",
                                        code = "8867-4",
                                        display = "Heart rate"))),
         subject = list(reference = uuid(1)),
         effectiveDateTime = sprintf("2025-06-0%dT10:00:00-05:00", n),
         valueQuantity = list(value = valor, unit = "/min",
                              system = "http://unitsofmeasure.org",
                              code = "/min"))
  }
  diagnostico <- list(
    resourceType = "Condition",
    clinicalStatus = list(coding = list(list(
      system = "http://terminology.hl7.org/CodeSystem/condition-clinical",
      code = "active"))),
    code = list(coding = list(list(system = "http://hl7.org/fhir/sid/icd-10",
                                   code = "A90", display = "Dengue"))),
    subject = list(reference = uuid(1)),
    recordedDate = "2025-06-01"
  )
  entrada <- function(n, recurso) {
    list(fullUrl = uuid(n), resource = recurso,
         request = list(method = "POST", url = recurso$resourceType))
  }
  transaccion <- list(resourceType = "Bundle", type = "transaction", entry = list(
    entrada(1, paciente), entrada(2, observacion(1, 72)),
    entrada(3, observacion(2, 88.5)), entrada(4, diagnostico)))

  res <- fhir_crear(con, transaccion)
  expect_identical(res$type, "transaction-response")
  ubicaciones <- vapply(res$entry, function(e) e$response$location, "")
  expect_length(ubicaciones, 4L)
  expect_true(all(startsWith(vapply(res$entry, function(e) e$response$status,
                                    ""), "201")))
  rutas <- sub("/_history/.*$", "", ubicaciones)
  # Se borran primero los que referencian al paciente
  on.exit(for (r in rev(rutas)) try(fhir_borrar(con, r), silent = TRUE),
          add = TRUE)
  id_paciente <- sub("^Patient/", "", rutas[1])

  obs <- fhir_buscar(con, "Observation", subject = rutas[1], progreso = FALSE)
  expect_length(obs, 2L)
  vista <- vista_crear("Observation", c(
    paciente = "subject.getReferenceKey(Patient)",
    fecha = "effective.ofType(dateTime)",
    valor = "value.ofType(Quantity).value",
    unidad = "value.ofType(Quantity).unit"))
  df <- vista_ejecutar(obs, vista)
  expect_identical(nrow(df), 2L)
  expect_identical(unique(df$paciente), id_paciente)
  expect_setequal(df$valor, c(72, 88.5))

  # La búsqueda con un único resultado (un Bundle de una entrada) da la misma
  # tabla con los dos motores
  pac <- fhir_buscar(con, "Patient", identifier = paste0(sis_prueba, "|", marca),
                     progreso = FALSE)
  expect_length(pac, 1L)
  vp <- vista_plantilla("pacientes")
  tabla_v8 <- vista_ejecutar(pac, vp)
  expect_identical(nrow(tabla_v8), 1L)
  expect_identical(tabla_v8$id, id_paciente)
  rapida <- fhir_tabla(pac)
  expect_identical(rapida$id, id_paciente)
  expect_match(rapida$name, "Salazar Moreno", fixed = TRUE)

  skip_if_not_installed("duckdb", "1.3.0")
  expect_identical(vista_ejecutar_duckdb(pac, vp), tabla_v8)
  expect_identical(vista_ejecutar_duckdb(obs, vista)[order(df$fecha), ],
                   df[order(df$fecha), ])
  todo <- fhir_everything(con, "Patient", id_paciente, progreso = FALSE)
  expect_setequal(vapply(todo, `[[`, "", "resourceType"),
                  c("Patient", "Observation", "Condition"))
  dx <- vista_ejecutar_duckdb(todo, vista_plantilla("diagnosticos"))
  expect_identical(nrow(dx), 1L)
  expect_identical(dx, vista_ejecutar(todo, vista_plantilla("diagnosticos")))
})

test_that("terminologia del servidor: $expand y $validate-code en lote", {
  con <- fhir_conectar(servidor_escritura(), panel = FALSE)
  vs <- "http://hl7.org/fhir/ValueSet/administrative-gender"
  sis <- "http://hl7.org/fhir/administrative-gender"
  exp <- tryCatch(tx_expandir(con, vs), fhirviews_error_http = function(e) NULL)
  skip_if(is.null(exp), "El servidor no expande administrative-gender")
  expect_setequal(exp$code, c("male", "female", "other", "unknown"))

  codigos <- c("female", "mujer", "male", "unknown")
  en_lote <- tx_validar_codigo(con, vs, sis, codigos)
  de_a_uno <- tx_validar_codigo(con, vs, sis, codigos, lote = FALSE)
  expect_identical(en_lote$valido, c(TRUE, FALSE, TRUE, TRUE))
  expect_identical(en_lote$valido, de_a_uno$valido)

  # Con el ValueSet como recurso (POST con un Parameters tipado)
  recurso <- list(resourceType = "ValueSet", url = "urn:fhirviews:vs",
                  status = "active",
                  compose = list(include = list(list(system = sis, concept = list(
                    list(code = "female"), list(code = "male"))))))
  expect_setequal(tx_expandir(con, recurso)$code, c("female", "male"))
  # HAPI no admite el parámetro valueSet en $validate-code (HAPI-0901); otros
  # servidores, como tx.fhir.org, sí
  r <- tryCatch(tx_validar_codigo(con, recurso, sis, c("female", "other")),
                fhirviews_error_http_400 = function(e) e)
  if (inherits(r, "fhirviews_error_http_400")) {
    expect_match(conditionMessage(r), "HAPI-0901")
    skip("El servidor no valida con un ValueSet en línea")
  }
  expect_identical(r$valido, c(TRUE, FALSE))
})

test_that("exportacion masiva ($export) de punta a punta", {
  con <- fhir_conectar(servidor_escritura(), panel = FALSE)
  marca <- marca_prueba()
  p <- fhir_crear(con, list(
    resourceType = "Patient",
    identifier = list(list(system = sis_prueba, value = marca)),
    gender = "female", birthDate = "1990-01-01"))
  on.exit(try(fhir_borrar(con, p), silent = TRUE), add = TRUE)

  inicio <- tryCatch(
    fhir_exportar(con, "paciente", tipos = "Patient", esperar = FALSE),
    fhirviews_error_exportacion = function(e) NULL,
    fhirviews_error_http = function(e) NULL)
  skip_if(is.null(inicio), "El servidor no admite $export")
  carpeta <- tempfile("export-")
  on.exit(unlink(carpeta, recursive = TRUE), add = TRUE)
  inicio$carpeta <- carpeta
  x <- fhir_exportar_estado(inicio, esperar = TRUE, intervalo = 1,
                            max_espera = 180, progreso = FALSE)
  expect_identical(x$estado, "completada")
  expect_true("Patient" %in% names(x$archivos))
  expect_true(all(file.exists(unlist(x$archivos))))
  r <- fhir_recursos(unlist(x$archivos))
  expect_true(p$id %in% vapply(r, `[[`, "", "id"))
  v <- vista_crear("Patient", c(sexo = "gender"))
  df <- vista_ejecutar(r, v)
  expect_identical(df$sexo[df$id == p$id], "female")
  skip_if_not_installed("duckdb", "1.3.0")
  db <- vista_ejecutar_duckdb(x$archivos$Patient, v)
  expect_identical(db[order(db$id), ], df[order(df$id), ],
                   ignore_attr = "row.names")
})
