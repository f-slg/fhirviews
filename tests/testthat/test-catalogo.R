test_that("el catalogo lista las vistas incluidas", {
  cat_ <- vista_catalogo()
  expect_s3_class(cat_, "data.frame")
  expect_named(cat_, c("nombre", "recurso", "titulo", "descripcion"))
  expect_true(all(c("pacientes", "signos_vitales", "diagnosticos",
                    "inmunizaciones", "encuentros", "medicamentos",
                    "notificacion_obligatoria") %in% cat_$nombre))
  expect_false(anyNA(cat_$titulo))
  expect_false(anyNA(cat_$descripcion))
  expect_identical(cat_$recurso[cat_$nombre == "signos_vitales"],
                   "Observation")
})

test_that("cada vista del catalogo es valida y usa claves de recurso", {
  for (nombre in vista_catalogo()$nombre) {
    v <- vista_plantilla(nombre)
    expect_s3_class(v, "fhir_vista")
    expect_no_error(vista_validar(v))
    expect_identical(v$name, nombre)
    expect_identical(v$status, "active")
    expect_identical(v$select[[1]]$column[[1]]$path, "getResourceKey()",
                     label = nombre)
  }
})

test_that("vista_plantilla() cambia constantes y avisa de errores", {
  v <- vista_plantilla("notificacion_obligatoria",
                       constantes = list(codigos = "A91"))
  k <- Filter(function(k) k$name == "codigos", v$constant)[[1]]
  expect_identical(k$valueString, "A91")
  dengue <- system.file("extdata", "dengue_2025.ndjson.gz",
                        package = "fhirviews")
  df <- vista_ejecutar(dengue, v)
  expect_gt(nrow(df), 0L)
  expect_true(all(df$categoria == "A91"))

  expect_error(vista_plantilla("no_existe"), class = "fhirviews_error")
  expect_error(vista_plantilla("pacientes", constantes = list(x = 1)),
               class = "fhirviews_error")
  expect_error(vista_plantilla("diagnosticos", constantes = list(otra = "x")),
               class = "fhirviews_error")
})

test_that("las vistas dan las tablas esperadas con el caso clinico", {
  caso <- system.file("extdata", "caso_clinico.ndjson", package = "fhirviews")
  sv <- vista_ejecutar(caso, vista_plantilla("signos_vitales"))
  pa <- sv[sv$id == "obs-pa", ]
  expect_identical(pa$codigo, c("8480-6", "8462-4"))
  expect_identical(pa$valor, c(128, 84))
  expect_false(anyNA(sv$valor))

  pac <- vista_ejecutar(caso, vista_plantilla("pacientes"))
  expect_identical(pac$provincia, "Pichincha")

  inm <- vista_ejecutar(caso, vista_plantilla("inmunizaciones"))
  expect_identical(inm$motivo_no_aplicacion[inm$estado == "not-done"],
                   "MEDPREC")
})

# Recursos con casos limite que no estan en los archivos de ejemplo
recursos_limite <- function() {
  ref <- function(x) list(reference = x)
  cie <- function(codigo) list(coding = list(list(
    system = "http://hl7.org/fhir/sid/icd-10", code = codigo)))
  list(
    list(resourceType = "Patient", id = "p1", deceasedDateTime = "2025-01-02",
         address = list(list(use = "temp", district = "Otro"),
                        list(use = "home", district = "Loja",
                             state = "Loja"))),
    list(resourceType = "Patient", id = "p2", deceasedBoolean = FALSE),
    list(resourceType = "Condition", id = "c1", subject = ref("Patient/p1"),
         code = cie("B54"), onsetPeriod = list(start = "2025-01-01")),
    list(resourceType = "Condition", id = "c2", subject = ref("Patient/p2"),
         code = cie("A17.0"), onsetDateTime = "2025-02-01"),
    list(resourceType = "Condition", id = "c3", subject = ref("Patient/p2"),
         code = cie("J10")),
    list(resourceType = "Immunization", id = "i1", status = "completed",
         patient = ref("Patient/p1"),
         vaccineCode = list(coding = list(list(system = "urn:otro",
                                               code = "X1"))),
         protocolApplied = list(list(doseNumberString = "refuerzo"))),
    list(resourceType = "MedicationRequest", id = "m1", status = "active",
         intent = "order", subject = ref("Patient/p1"),
         medicationReference = ref("Medication/med1")),
    list(resourceType = "Observation", id = "o1", status = "final",
         category = list(list(coding = list(list(code = "vital-signs")))),
         code = list(coding = list(list(system = "http://loinc.org",
                                        code = "8310-5"))),
         subject = ref("Patient/p2"),
         effectivePeriod = list(start = "2025-03-01"),
         valueQuantity = list(value = 37, unit = "C"))
  )
}

test_that("vista_plantilla() maneja casos limite", {
  r <- recursos_limite()
  pac <- vista_ejecutar(r, vista_plantilla("pacientes"))
  expect_identical(pac$fallecido, c(TRUE, FALSE))
  expect_identical(pac$canton, c("Loja", NA))
  noti <- vista_ejecutar(r, vista_plantilla("notificacion_obligatoria"))
  expect_identical(noti$id, c("c1", "c2"))
  med <- vista_ejecutar(r, vista_plantilla("medicamentos"))
  expect_identical(med$medicamento_ref, "med1")
})

# Prueba diferencial: los dos motores deben dar la misma tabla
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

test_that("las vistas del catalogo dan lo mismo con V8 y DuckDB", {
  fuentes <- list(
    caso_clinico = system.file("extdata", "caso_clinico.ndjson",
                               package = "fhirviews"),
    dengue = system.file("extdata", "dengue_2025.ndjson.gz",
                         package = "fhirviews"),
    limite = recursos_limite()
  )
  filas <- 0L
  for (nombre in vista_catalogo()$nombre) {
    v <- vista_plantilla(nombre)
    for (f in names(fuentes)) {
      v8 <- vista_ejecutar(fuentes[[f]], v)
      db <- vista_ejecutar_duckdb(fuentes[[f]], v)
      expect_identical(as.list(db), as.list(v8),
                       label = paste(nombre, f, sep = " / "))
      filas <- filas + nrow(v8)
    }
  }
  expect_gt(filas, 1500L)
})
