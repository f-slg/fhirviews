test_that("los limites conservan la escala del JSON y los contextos", {
  textos <- paste0('{"resourceType":"Observation","id":"o', 1:4,
                    '","valueQuantity":{"value":', c("1", "1.0", "1.00", "-1.00"), '}}')
  expect_equal(vista_fhirpath(textos, "value.ofType(Quantity).value.lowBoundary()"),
               c(0.5, 0.95, 0.995, -1.005))
  expect_equal(vista_fhirpath(textos, "value.ofType(Quantity).value.highBoundary()"),
               c(1.5, 1.05, 1.005, -0.995))
  arreglo <- paste0("[", paste(textos, collapse = ","), "]")
  bundle <- paste0('{"resourceType":"Bundle","entry":[',
    paste0('{"resource":', textos, '}', collapse = ","), "]}")
  for (x in list(arreglo, bundle)) {
    expect_equal(vista_fhirpath(x, "value.ofType(Quantity).value.lowBoundary()"),
                 c(0.5, 0.95, 0.995, -1.005))
    ndjson <- escribir_ndjson_temporal(x)
    expect_match(readLines(ndjson)[3], '"value":1.00', fixed = TRUE)
    unlink(ndjson)
  }
  v <- vista_crear("Observation", c(bajo = "value.lowBoundary()"),
                    por_cada = "value.ofType(Quantity)")
  expect_equal(vista_ejecutar(textos, v)$bajo, c(0.5, 0.95, 0.995, -1.005))
  expect_equal(vista_fhirpath(textos[1], "1.00.lowBoundary(2)"), 0.99)
  for (caso in list(c("1.0e-2", "0.0095", "0.0105"), c("1e2", "50", "150"))) {
    x <- paste0('{"resourceType":"Observation","valueQuantity":{"value":', caso[1], '}}')
    expect_equal(vista_fhirpath(x, "value.ofType(Quantity).value.lowBoundary()"), as.numeric(caso[2]))
    expect_equal(vista_fhirpath(x, "value.ofType(Quantity).value.highBoundary()"), as.numeric(caso[3]))
  }
  expect_true(is.na(vista_fhirpath(textos[1], "{}.lowBoundary()")))
  expect_error(vista_fhirpath(textos[1], "(1 | 2).lowBoundary()"),
               class = "fhirviews_error_fhirpath")
})

test_that("los limites temporales distinguen Date, DateTime y Time", {
  obs <- function(x) paste0('{"resourceType":"Observation","valueDateTime":"', x, '"}')
  casos <- list(
    c("2024-02", "2024-02-01T00:00:00.000+14:00", "2024-02-29T23:59:59.999-12:00"),
    c("2024-01-01T08:30:00-05:00", "2024-01-01T08:30:00.000-05:00", "2024-01-01T08:30:00.999-05:00"),
    c("2024-01-01T08:30:00Z", "2024-01-01T08:30:00.000Z", "2024-01-01T08:30:00.999Z"))
  for (caso in casos) {
    expect_identical(vista_fhirpath(obs(caso[1]), "value.ofType(dateTime).lowBoundary()"), caso[2])
    expect_identical(vista_fhirpath(obs(caso[1]), "value.ofType(dateTime).highBoundary()"), caso[3])
  }
  p <- '{"resourceType":"Patient","birthDate":"2024-02"}'
  expect_identical(vista_fhirpath(p, "birthDate.highBoundary()"), "2024-02-29")
  expect_identical(vista_fhirpath(p, "@T12:30.highBoundary()"), "12:30:59.999")
  expect_identical(vista_fhirpath(p, "@2024-02T.lowBoundary(8)"), "2024-02-01")
})

test_that("el lector funciona sin context.source ni JSON.rawJSON", {
  ct <- V8::v8()
  ct$eval("var window = globalThis;")
  cargar_js(ct, ruta_js("fhirpath", "fhirpath.min.js"))
  cargar_js(ct, ruta_js("fhirpath", "fhirpath.r4.min.js"))
  cargar_js(ct, ruta_js("lossless-json", "lossless-json.js"))
  ct$eval(paste0("var parseOriginal = JSON.parse; JSON.rawJSON = undefined; ",
    "JSON.parse = function(t, r) {return parseOriginal(t, r && function(k,v) {return r(k,v);});};"))
  cargar_js(ct, ruta_js("fhirviews.js"))
  ct$assign("texto", '{"resourceType":"Observation","valueQuantity":{"value":1.00}}')
  ct$eval("var ids = fhirviews.cargarTextos([texto]);")
  expect_identical(ct$eval(paste0("JSON.stringify(fhirviews.evaluar(ids, ",
    "'value.ofType(Quantity).value.lowBoundary()', null, null, 'valores'))")), "[[0.995]]")
  expect_match(ct$eval("JSON.stringify(fhirviews.recursosJSON([texto], null))"),
                "1.00", fixed = TRUE)
})
