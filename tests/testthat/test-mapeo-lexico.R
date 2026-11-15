test_that("code respeta espacios FHIR tambien sin un binding cerrado", {
  m <- fhir_mapa("Observation", c(id = "id", "code.coding[0].code" = "codigo"),
                 constantes = list(status = "final"))
  for (codigo in c(" local", "local ", "dos  espacios", "a\tb", "a\nb", "a\n",
                   "a\u00a0b", "a\u2003b")) {
    e <- tryCatch(fhir_desde_tabla(data.frame(id = "o1", codigo = codigo), m),
                  error = identity)
    expect_s3_class(e, "fhirviews_error_mapeo")
    expect_identical(e$fila, 1L)
    expect_identical(e$campo, "code.coding[0].code")
  }
  for (codigo in c("local", "dos palabras", "c\u00f3digo", "<")) {
    r <- fhir_desde_tabla(data.frame(id = "o1", codigo = codigo), m)
    expect_identical(r[[1]]$code$coding[[1]]$code, codigo)
  }
})

test_that("URI, URL y canonical rechazan separadores sin exigir una URL absoluta", {
  for (campo in c("identifier[0].system", "photo[0].url", "meta.profile[0]")) {
    m <- fhir_mapa("Patient", stats::setNames(c("id", "texto"), c("id", campo)))
    for (texto in c("https://example.org/con espacio", "a\tb", "a\nb", "a\u00a0b")) {
      expect_error(fhir_desde_tabla(data.frame(id = "p1", texto = texto), m),
                   "URI FHIR", class = "fhirviews_error_mapeo")
    }
    expect_length(fhir_desde_tabla(data.frame(id = "p1", texto = ""), m), 1L)
    for (texto in c("https://example.org/a%20b", "urn:oid:1.2.3", "#local",
                    "https://example.org/perfil|1.0")) {
      expect_length(fhir_desde_tabla(data.frame(id = "p1", texto = texto), m), 1L)
    }
  }
})
