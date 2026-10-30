pacientes <- list(
  list(resourceType = "Patient", id = "p1", gender = "female",
       birthDate = "1985-03-12",
       name = list(list(family = "Paredes Cevallos",
                        given = list("Ana", "Luc\u00eda"))),
       managingOrganization = list(reference = "Organization/org1"),
       extension = list(list(
         url = "http://example.org/etnia",
         valueCodeableConcept = list(text = "Mestizo")))),
  list(resourceType = "Patient", id = "p2", gender = "male",
       birthDate = "2001-11-30",
       name = list(list(family = "Salazar Moreno", given = list("Jorge"))),
       managingOrganization = list(
         reference = "https://hapi.fhir.org/baseR4/Organization/org2/_history/3"))
)

observacion <- list(
  resourceType = "Observation", id = "o1", status = "final",
  subject = list(reference = "Patient/p1"),
  component = list(
    list(code = list(text = "sist\u00f3lica"),
         valueQuantity = list(value = 120, unit = "mm[Hg]")),
    list(code = list(text = "nota"), valueString = "en reposo")
  )
)

test_that("evalua expresiones simples", {
  expect_identical(vista_fhirpath(pacientes, "gender"), c("female", "male"))
  expect_identical(vista_fhirpath(pacientes, "name.given.first()"),
                   c("Ana", "Jorge"))
  expect_identical(vista_fhirpath(pacientes, "name.given.join(' ')"),
                   c("Ana Luc\u00eda", "Jorge"))
  expect_identical(vista_fhirpath(pacientes, "deceased.exists()"),
                   c(FALSE, FALSE))
  expect_identical(vista_fhirpath(pacientes, "telecom.empty()"),
                   c(TRUE, TRUE))
  expect_identical(vista_fhirpath(pacientes, "address.city"),
                   c(NA, NA))
})

test_that("varios valores dan una lista de vectores", {
  res <- vista_fhirpath(pacientes, "name.given")
  expect_identical(res, list(c("Ana", "Luc\u00eda"), "Jorge"))
  res <- vista_fhirpath(pacientes, "name", simplificar = FALSE)
  expect_identical(res[[2]][[1]]$family, "Salazar Moreno")
})

test_that("getResourceKey y getReferenceKey", {
  expect_identical(vista_fhirpath(pacientes, "getResourceKey()"),
                   c("p1", "p2"))
  expect_identical(
    vista_fhirpath(pacientes, "managingOrganization.getReferenceKey()"),
    c("org1", "org2")
  )
  expect_identical(
    vista_fhirpath(pacientes,
                   "managingOrganization.getReferenceKey(Organization)"),
    c("org1", "org2")
  )
  expect_identical(
    vista_fhirpath(pacientes, "managingOrganization.getReferenceKey(Patient)"),
    c(NA, NA)
  )
  expect_identical(
    vista_fhirpath(observacion, "subject.getReferenceKey(Patient)"), "p1"
  )
})

test_that("ofType y extension", {
  expect_identical(
    vista_fhirpath(observacion, "component.value.ofType(Quantity).value"),
    120L
  )
  expect_identical(
    vista_fhirpath(observacion, "component.value.ofType(string)"),
    "en reposo"
  )
  expect_identical(
    vista_fhirpath(pacientes,
                   "extension('http://example.org/etnia').value.ofType(CodeableConcept).text"),
    c("Mestizo", NA)
  )
})

test_that("variables, incluidas fechas", {
  expect_identical(
    vista_fhirpath(pacientes, "birthDate < %corte",
                   variables = list(corte = as.Date("2000-01-01"))),
    c(TRUE, FALSE)
  )
  expect_identical(
    vista_fhirpath(pacientes, "gender = %g", variables = list(g = "male")),
    c(FALSE, TRUE)
  )
  expect_error(vista_fhirpath(pacientes, "gender", variables = list(1)),
               class = "fhirviews_error")
})

test_that("los errores de FHIRPath son legibles y liberan memoria", {
  m <- motor_actual()
  antes <- m$tamano()
  expect_error(vista_fhirpath(pacientes, "name.("),
               class = "fhirviews_error_fhirpath")
  expect_identical(m$tamano(), antes)
  vista_fhirpath(pacientes, "gender")
  expect_identical(m$tamano(), antes)
  expect_error(vista_fhirpath(pacientes, c("a", "b")), class = "fhirviews_error")
})

test_that("el motor encadena nodos sin perder el tipo", {
  m <- motor_actual()
  inicio <- m$tamano()
  on.exit(m$liberar(inicio), add = TRUE)
  ids <- m$cargar(fhir_recursos(observacion))
  componentes <- m$evaluar(ids, "component", modo = "nodos")[[1]]
  expect_length(componentes, 2L)
  valores <- m$evaluar(componentes, "value.ofType(Quantity).value")
  expect_identical(valores, list(list(120L), list()))
  # %resource apunta al recurso de origen
  expect_identical(m$evaluar(componentes, "%resource.id")[[2]], list("o1"))
  # Variables distintas para cada nodo
  res <- m$evaluar(componentes, "%rowIndex",
                   por_nodo = list(rowIndex = c(0L, 1L)))
  expect_identical(res, list(list(0L), list(1L)))
  expect_true(m$validar("name.given"))
  expect_error(m$validar("name.("), class = "fhirviews_error_fhirpath")
})

test_that("informa el motor y la version de fhirpath.js", {
  expect_identical(fhirviews_version_fhirpath(), "5.2.2")
  expect_output(info <- fhirviews_motor(), "fhirpath.js")
  expect_identical(info$fhirpath_js, fhirviews_version_fhirpath())
  withr_opcion <- options(fhirviews.motor = "otro")
  on.exit(options(withr_opcion), add = TRUE)
  expect_error(motor_actual(), class = "fhirviews_error")
})
