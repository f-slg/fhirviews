test_that("el analizador de FHIRPath arma el arbol", {
  a <- fp_analizar("name.where(use = 'official').family.first()")
  expect_identical(a$t, "llamada")
  expect_identical(a$fn, "first")
  expect_identical(a$base$nombre, "family")
  expect_identical(a$base$base$fn, "where")
  expect_identical(a$base$base$args[[1]]$op, "=")

  b <- fp_analizar("a + b * 2 > 3 and not_x or c")
  expect_identical(b$op, "or")
  expect_identical(b$a$op, "and")
  expect_identical(b$a$a$op, ">")
  expect_identical(b$a$a$a$b$op, "*")

  expect_identical(fp_analizar("@2020-01-01")$valor, "2020-01-01")
  expect_identical(fp_analizar("1.5")$tipo, "DOUBLE")
  expect_identical(fp_analizar("%`mi var`")$nombre, "mi var")
  expect_identical(fp_analizar("'a\\'b'")$valor, "a'b")
  expect_identical(fp_analizar("x is FHIR.Quantity")$tipo, "Quantity")
  expect_identical(fp_analizar("-x")$t, "neg")
  expect_identical(fp_analizar("name[0]")$t, "indice")

  expect_error(fp_analizar("@@"), class = "fhirviews_error_sql")
  expect_error(fp_analizar("name.("), class = "fhirviews_error_sql")
  expect_error(fp_analizar("'sin cerrar"), class = "fhirviews_error_sql")
  expect_error(fp_analizar("a b"), class = "fhirviews_error_sql")
})

test_that("vista_sql genera la consulta", {
  vista <- vista_crear("Patient", c(sexo = "gender",
                                    apellido = "name.first().family"))
  sql <- vista_sql(vista, "datos/pacientes.ndjson")
  expect_s3_class(sql, "fhir_sql")
  expect_match(sql, "read_json_objects", fixed = TRUE)
  expect_match(sql, "'Patient'", fixed = TRUE)
  expect_output(print(sql), "SELECT")
  expect_match(vista_sql(vista, "p.parquet"), "read_parquet", fixed = TRUE)
  expect_match(vista_sql(vista), "FROM \"recursos\"", fixed = TRUE)
  expect_error(vista_sql(vista, c("a.ndjson", "b.parquet")),
               class = "fhirviews_error")
  expect_error(vista_sql(vista, "no es una tabla"), class = "fhirviews_error")
})

test_that("lo que no se traduce da un error que sugiere vista_ejecutar()", {
  v <- vista_crear("Observation",
                   c(x = "value.ofType(Quantity).value.lowBoundary()"))
  expect_error(vista_sql(v), class = "fhirviews_error_sql")
  expect_error(vista_sql(v), "vista_ejecutar")
  expect_error(vista_sql(vista_crear("Patient", c(x = "%nada"))),
               class = "fhirviews_error_sql")
  expect_error(vista_sql(vista_crear("Patient", c(x = "name.ofType(Foo)"))),
               class = "fhirviews_error_sql")
  expect_error(vista_sql(vista_crear("Observation",
                                     c(x = "value.ofType(Foo)"))),
               class = "fhirviews_error_sql")
  expect_match(vista_sql(vista_crear("Observation", c(x = "value"))),
               "valueQuantity", fixed = TRUE)
  expect_error(vista_sql(vista_crear("Patient", c(x = "ofType(Foo)"))),
               class = "fhirviews_error_sql")
  expect_error(vista_sql(vista_crear("Patient", c(x = "first(1)"))),
               class = "fhirviews_error_sql")
})

# Las pruebas que ejecutan SQL necesitan la extension json de DuckDB, que
# se descarga la primera vez
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

caso <- system.file("extdata", "caso_clinico.ndjson", package = "fhirviews")

dengue <- system.file("extdata", "dengue_2025.ndjson.gz", package = "fhirviews")

# Los dos motores deben dar la misma tabla (valores y tipos) o fallar los dos
comparar_motores <- function(vista, recursos = caso, etiqueta = "") {
  v8 <- tryCatch(vista_ejecutar(recursos, vista), error = function(e) e)
  db <- tryCatch(vista_ejecutar_duckdb(recursos, vista), error = function(e) e)
  if (inherits(v8, "error")) {
    expect(inherits(db, "error"),
           sprintf("%s: V8 falla y DuckDB no", etiqueta))
    return(invisible())
  }
  if (inherits(db, "error")) {
    fail(sprintf("%s: DuckDB falla: %s", etiqueta,
                 cli::ansi_strip(conditionMessage(db))))
    return(invisible())
  }
  expect_identical(as.list(db), as.list(v8), label = etiqueta)
}

test_that("da lo mismo que vista_ejecutar() con el caso clinico", {
  comparar_motores(vista_crear("Patient", c(
    sexo = "gender", nacimiento = "birthDate", activo = "active",
    apellido = "name.where(use = 'official').family.first()",
    nombres = "name.first().given.join(' ')",
    telefonos = "telecom.where(system = 'phone').count()")))
  comparar_motores(vista_crear(
    "Observation",
    c(codigo = "code.coding.first().code", valor = "value.ofType(Quantity).value",
      unidad = "value.ofType(Quantity).unit",
      paciente = "subject.getReferenceKey(Patient)"),
    where = "status = 'final'"))
  comparar_motores(vista_crear("Patient", c(sistema = "system", valor = "value"),
                               por_cada = "telecom"))
  comparar_motores(vista_leer('{
    "resource": "QuestionnaireResponse",
    "select": [
      {"column": [{"name": "id", "path": "getResourceKey()"}]},
      {"repeat": ["item"], "column": [
        {"name": "orden", "path": "%rowIndex"},
        {"name": "pregunta", "path": "linkId"},
        {"name": "respuestas", "path": "answer.value.ofType(string)",
         "collection": true}
      ]}
    ]
  }'))
})

test_that("elementos de eleccion sin ofType() y extension(%constante)", {
  comparar_motores(vista_leer(r"-({"resource": "QuestionnaireResponse",
    "select": [{"column": [{"name": "r", "path": "getResourceKey()"}]},
    {"repeat": ["item"], "column": [
      {"name": "pregunta", "path": "linkId"},
      {"name": "i", "path": "%rowIndex"},
      {"name": "valor", "path": "answer.value.first().toString()"}]}]})-"),
    etiqueta = "repeat con answer.value")
  comparar_motores(vista_leer(r"-({"resource": "Patient",
    "constant": [{"name": "dpa",
      "valueUri": "https://f-slg.github.io/fhirviews/StructureDefinition/codigo-dpa"}],
    "select": [{"column": [
      {"name": "id", "path": "getResourceKey()"},
      {"name": "dpa", "path": "address.where(use = 'home').extension(%dpa).value.first()"}
    ]}]})-"), dengue, etiqueta = "extension(%dpa).value")
  comparar_motores(vista_crear("Observation", c(
    valor = "value", fecha = "effective", texto = "value.text")),
    etiqueta = "value y effective")
})

# Vistas de las viñetas: se buscan las llamadas a vista_crear(),
# vista_leer() y vista_ejecutar(recursos, "json") en sus bloques de R
vistas_vinetas <- function() {
  carpeta <- test_path("..", "..", "vignettes")
  if (!dir.exists(carpeta)) {
    carpeta <- system.file("doc", package = "fhirviews")
  }
  archivos <- file.path(carpeta, c("fhirviews.Rmd", "vistas.Rmd",
                                   file.path("articles", "tasas-pobecu.Rmd")))
  archivos <- archivos[file.exists(archivos)]
  vistas <- list()
  for (a in archivos) {
    lineas <- readLines(a, encoding = "UTF-8", warn = FALSE)
    inicio <- grep("^```\\{r", lineas)
    fin <- grep("^```\\s*$", lineas)
    codigo <- unlist(lapply(inicio, function(i) {
      f <- min(fin[fin > i])
      if (f > i + 1L) lineas[(i + 1L):(f - 1L)]
    }))
    expresiones <- tryCatch(parse(text = codigo, keep.source = FALSE),
                            error = function(e) expression())
    recursos <- if (basename(a) == "tasas-pobecu.Rmd") dengue else caso
    recorrer <- function(e) {
      if (!is.call(e)) return()
      fn <- if (is.symbol(e[[1]])) as.character(e[[1]]) else ""
      v <- NULL
      if (fn %in% c("vista_crear", "vista_leer")) {
        v <- tryCatch(eval(e, asNamespace("fhirviews")), error = function(x) NULL)
      } else if (fn == "vista_ejecutar" && length(e) >= 3L &&
                 is.character(e[[3]])) {
        v <- tryCatch(vista_leer(e[[3]]), error = function(x) NULL)
      }
      if (!is.null(v)) {
        vistas[[length(vistas) + 1L]] <<- list(
          vista = v, recursos = recursos,
          etiqueta = paste(basename(a), v$resource, length(vistas) + 1L))
      }
      for (i in seq_along(e)[-1]) {
        if (is.call(e[[i]])) recorrer(e[[i]])
      }
    }
    for (e in expresiones) recorrer(e)
  }
  vistas
}

test_that("los dos motores dan las mismas tablas con las vistas de las vi\u00f1etas", {
  vistas <- vistas_vinetas()
  skip_if(length(vistas) == 0L, "no se encontraron las vi\u00f1etas")
  expect_gte(length(vistas), 15L)
  for (v in vistas) {
    comparar_motores(v$vista, v$recursos, v$etiqueta)
  }
})

test_that("tipos, colecciones y objetos", {
  pacientes <- list(
    list(resourceType = "Patient", id = "p1", active = TRUE,
         name = list(list(family = "A", given = list("x", "y")))),
    list(resourceType = "Patient", id = "p2",
         extension = list(list(url = "u", valueInteger = 3L)))
  )
  vista <- vista_leer('{"resource": "Patient", "select": [{"column": [
    {"name": "id", "path": "id"},
    {"name": "activo", "path": "active"},
    {"name": "dados", "path": "name.given", "collection": true},
    {"name": "nombre", "path": "name.first()"},
    {"name": "ext", "path": "extension(\'u\').value.ofType(integer)"},
    {"name": "cuenta", "path": "name.given.count()"},
    {"name": "x", "path": "id + \'-\' + name.family.first()"}
  ]}]}')
  df <- vista_ejecutar_duckdb(pacientes, vista)
  expect_identical(df$activo, c(TRUE, NA))
  expect_identical(df$dados, list(c("x", "y"), logical()))
  expect_identical(df$nombre[[1]], list(family = "A", given = list("x", "y")))
  expect_null(df$nombre[[2]])
  expect_identical(df$ext, c(NA, 3L))
  expect_identical(df$cuenta, c(2L, 0L))
  expect_identical(df$x, c("p1-A", NA))
  comparar_motores(vista, pacientes)

  # Varios valores sin collection: error de la vista
  v2 <- vista_crear("Patient", c(g = "name.given"))
  expect_error(vista_ejecutar_duckdb(pacientes, v2),
               class = "fhirviews_error_vista")
  # where que no devuelve un logico
  v3 <- vista_crear("Patient", c(i = "id"), where = "id")
  expect_error(vista_ejecutar_duckdb(pacientes, v3),
               class = "fhirviews_error_vista")
})

test_that("guarda en una tabla y lee Parquet", {
  con <- conectar_duckdb()
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  vista <- vista_crear("Observation", c(
    valor = "value.ofType(Quantity).value",
    paciente = "subject.getReferenceKey(Patient)"))
  res <- vista_ejecutar_duckdb(caso, vista, con_db = con, tabla = "obs")
  expect_identical(res, con)
  n <- DBI::dbGetQuery(con, "SELECT count(*) AS n FROM obs")$n
  expect_equal(n, nrow(vista_ejecutar(caso, vista)))

  # Parquet con columnas STRUCT, como lo escribe DuckDB desde NDJSON
  lineas <- readLines(caso, encoding = "UTF-8")
  ndjson <- withr_tempfile(".ndjson")
  writeLines(grep('"resourceType":"Observation"', lineas, value = TRUE,
                  fixed = TRUE), ndjson, useBytes = TRUE)
  parquet <- withr_tempfile(".parquet")
  DBI::dbExecute(con, sprintf(
    "COPY (SELECT * FROM read_json('%s', format = 'newline_delimited'))
     TO '%s' (FORMAT parquet)", ndjson, parquet))
  desde_parquet <- vista_ejecutar_duckdb(parquet, vista, con_db = con)
  expect_equal(desde_parquet, vista_ejecutar(caso, vista), ignore_attr = TRUE)

  # Una tabla con una columna json
  DBI::dbExecute(con, sprintf(
    "CREATE TABLE recursos AS SELECT json FROM read_json_objects('%s')", caso))
  desde_tabla <- vista_ejecutar_duckdb("recursos", vista, con_db = con)
  expect_equal(nrow(desde_tabla), n)
})

test_that("pasan las pruebas shareable del banco oficial", {
  res <- vista_conformidad(motor = "duckdb")
  expect_identical(attr(res, "motor"), "duckdb")
  expect_output(print(res), "motor DuckDB")
  shareable <- res[res$perfil %in% "shareable", ]
  expect_gte(nrow(shareable), 133L)
  for (i in seq_len(nrow(shareable))) {
    expect(shareable$aprobada[i],
           sprintf("%s / %s: %s", shareable$archivo[i], shareable$prueba[i],
                   shareable$detalle[i]))
  }
})

# Recursos con casos límite para comparar las funciones de FHIRPath
recursos_fhirpath <- function() {
  archivo <- withr_tempfile(".ndjson")
  writeLines(enc2utf8(c(
    '{"resourceType":"Patient","id":"p1","active":true,"gender":"female","birthDate":"1970-06-15","multipleBirthInteger":2,"name":[{"use":"official","family":"P\u00e9rez","given":["Ana","Mar\u00eda"]},{"use":"usual","given":["Anita"]}],"telecom":[{"system":"phone","value":"+593 99 123 4567","rank":1},{"system":"email","value":"ana@x.org","rank":2}],"address":[{"use":"home","city":"Quito","line":["Av. 10 de Agosto"," N12 "],"postalCode":"170150","period":{"start":"2001-03","end":"2020-12-31T10:00:00Z"}}],"deceasedBoolean":false}',
    '{"resourceType":"Patient","id":"p2","gender":"male","birthDate":"1985","name":[{"family":"O\'Neil","given":["Jo"]}],"address":[{"use":"work","city":"guayaquil","postalCode":"0901"}],"deceasedDateTime":"2021-05-04T08:30:00-05:00"}',
    '{"resourceType":"Patient","id":"p3","birthDate":"2001-02","name":[{"use":"official","family":"\u00d1and\u00fa  ","given":["\u00c9mile","","Zo\u00eb"]}],"telecom":[{"system":"phone","value":"123"}],"multipleBirthBoolean":true}',
    '{"resourceType":"Patient","id":"p4"}',
    '{"resourceType":"Observation","id":"o1","status":"final","code":{"coding":[{"system":"http://loinc.org","code":"8480-6"}],"text":"PAS"},"valueQuantity":{"value":120.50,"unit":"mmHg"},"effectiveDateTime":"2024-03-01T10:15:00Z","subject":{"reference":"Patient/p1"}}',
    '{"resourceType":"Observation","id":"o2","status":"amended","code":{"text":"x"},"valueString":"positivo 12","effectivePeriod":{"start":"2024-01","end":"2024-02-15"},"subject":{"reference":"Patient/p2"}}',
    '{"resourceType":"Observation","id":"o3","status":"final","code":{"text":"y"},"valueInteger":-7,"effectiveDateTime":"2024-06-01T23:30:00+05:00","subject":{"reference":"Patient/p3"}}',
    '{"resourceType":"Observation","id":"o4","status":"final","code":{"text":"z"},"valueQuantity":{"value":3,"unit":"kg"},"effectiveDateTime":"2024-03-01T00:00:00.000Z"}'
  )), archivo, useBytes = TRUE)
  archivo
}

comparar_expresiones <- function(recurso, expresiones, recursos) {
  for (e in expresiones) {
    coleccion <- startsWith(e, "*")
    e <- sub("^\\*", "", e)
    vista <- vista_leer(list(
      resourceType = "ViewDefinition", resource = recurso, status = "active",
      select = list(list(column = list(
        list(name = "id", path = "id"),
        c(list(name = "x", path = e), if (coleccion) list(collection = TRUE)))))))
    comparar_motores(vista, recursos, paste(recurso, e))
  }
}

test_that("las funciones de FHIRPath dan lo mismo que vista_ejecutar()", {
  r <- recursos_fhirpath()
  comparar_expresiones("Patient", c(
    # Colecciones
    "name.given.count()", "name.given.distinct().count()", "name.given.last()",
    "name.given.tail().first()", "name.given.skip(1).first()",
    "*name.given.take(1)", "*name.given.combine(name.family)",
    "*name.given | name.family", "*name.given.union(name.family)",
    "*name.given.intersect('Ana' | 'Jo')", "*name.given.exclude('Ana')",
    "name.given.isDistinct()", "'Ana' in name.given",
    "name.given contains 'Jo'", "(1 | 1.0 | '1').count()",
    "name.given.subsetOf(name.given | 'x')", "(true | true).allTrue()",
    "name.exists().not()", "name.where(family).count()",
    "*name.select(given.first())", "name.all(given.exists())",
    # Lógica
    "active.not()", "iif(active, 'si', 'no')", "iif(gender = 'male', 1, 2)",
    "iif(gender, 1, 2)", "iif(active, 'si')",
    # Conversiones
    "id.toString()", "multipleBirth.toString()", "active.toString()",
    "address.postalCode.toInteger()", "address.postalCode.toDecimal()",
    "'1.5'.toInteger()", "1.5.toInteger()", "(1.5 * 2).toInteger()",
    "'T'.toBoolean()", "telecom.rank.first().toBoolean()",
    "'abc'.convertsToInteger()", "{}.convertsToInteger()",
    "(telecom.rank.first() / 3).toString()", "1.0.toString()",
    # Texto
    "name.family.first().substring(1)", "name.family.first().substring(1, 2)",
    "name.family.first().substring(10)", "name.family.first().substring(-1)",
    "name.family.first().startsWith('P')", "name.family.first().endsWith('z')",
    "name.family.first().contains('e')", "name.family.first().matches('^P')",
    "name.family.first().matches('[^a-c]+$')",
    "name.family.first().replace('e', 'E')",
    "name.family.first().replace('', '-')", "name.family.first().upper()",
    "name.family.first().lower()", "name.family.first().length()",
    "name.family.first().trim()", "address.line.first().trim()",
    "name.given.first().indexOf('n')",
    "name.given.first().replaceMatches('[aeiou]', '<$&>')",
    "*telecom.value.first().split(' ')", "*'abc'.toChars()",
    "name.family.first() ~ 'p\u00c9REZ'", "name.given.last() ~ 'anita'",
    "name.family.first() & '-' & gender",
    # Aritmética
    "1 + 2 * 3", "7 / 2", "7 div 2", "-7 mod 2", "0.1 + 0.2", "0.1 + 0.2 = 0.3",
    "multipleBirth.ofType(integer) + 1", "'a' + 'b'",
    "2.power(10)", "2.5.round()", "(-2.5).round()", "3.14159.round(2)",
    "16.sqrt()", "(-5.5).abs()", "1.5.ceiling()", "(-1.5).floor()",
    "(-1.7).truncate()",
    # Fechas
    "birthDate > @1980-01-01", "birthDate < @1980", "birthDate = @1970-06-15",
    "birthDate >= @2001-02-01", "birthDate = '1970-06-15'",
    "birthDate ~ @1970-06", "address.period.start < @2001-03-02",
    "deceased.ofType(dateTime) > @2021-05-04T08:00:00-05:00",
    "deceased.ofType(dateTime) = @2021-05-04T13:30:00Z",
    "address.period.end > @2020-12-31T05:00:00-05:00",
    "birthDate.lowBoundary()", "birthDate.highBoundary()",
    "deceased.ofType(dateTime).lowBoundary()",
    "deceased.ofType(dateTime).highBoundary()",
    "multipleBirth is boolean", "multipleBirth.is(integer)"
  ), r)
  comparar_expresiones("Observation", c(
    "value.ofType(Quantity).value", "value.ofType(Quantity).value * 2",
    "value.ofType(Quantity).value > 100", "value.ofType(integer) < 0",
    "value.ofType(Quantity).value.round()",
    "value.ofType(Quantity).value.toString()",
    "value.ofType(Quantity).value.toInteger()",
    "value.ofType(string).length()", "value.ofType(string).matches('\\\\d+')",
    "status = 'final' and value.exists()", "code.text ~ 'pas'",
    "subject.reference.substring(8)",
    "effective.ofType(dateTime) >= @2024-03-01T00:00:00Z",
    "effective.ofType(dateTime) < @2024-06-01T18:30:00Z",
    "effective.ofType(dateTime) = @2024-06-01T18:30:00Z"
  ), r)
})

test_that("lo que no se puede traducir con certeza da error", {
  r <- recursos_fhirpath()
  traduccion <- function(recurso, e) {
    expect_error(vista_sql(vista_crear(recurso, c(x = e))),
                 class = "fhirviews_error_sql", label = e)
  }
  ejecucion <- function(recurso, e) {
    expect_error(vista_ejecutar_duckdb(r, vista_crear(recurso, c(x = e))),
                 class = "fhirviews_error_vista", label = e)
  }
  # Decimales: su precisión se pierde al leer el JSON
  traduccion("Observation", "value.ofType(Quantity).value.lowBoundary()")
  # Expresiones regulares que JavaScript y RE2 leen distinto
  traduccion("Patient", "gender.matches('\\\\s')")
  traduccion("Patient", "gender.matches('(?<n>a)')")
  traduccion("Patient", "gender.matches(id)")
  traduccion("Patient", "1.0 ~ 1")
  traduccion("Patient", "1.exp()")
  traduccion("Patient", "birthDate + 1")
  traduccion("Patient", "name.ofType(HumanName)")
  # Valores que dependen de la zona horaria del equipo o de un tipo
  # desconocido
  ejecucion("Observation", "effective.ofType(dateTime) > @2024-03-01")
  ejecucion("Patient", "birthDate < @2000-01-01T00:00:00Z")
  ejecucion("Patient", "name.given.skip(-1).first()")
  ejecucion("Patient", "name.first() = name.last()")
  ejecucion("Patient", "multipleBirth + 1")
  ejecucion("Patient", "name.family.first().replace('e', '$&')")
  ejecucion("Patient", "deceased > @2021-01-01")
  # Caracteres que DuckDB y JavaScript tratan distinto
  raros <- list(list(resourceType = "Patient", id = "x",
                     name = list(list(family = "Stra\u00dfe",
                                      given = list("a\U0001F600b")))))
  expect_error(vista_ejecutar_duckdb(raros, vista_crear("Patient", c(
    x = "name.family.first().upper()"))), class = "fhirviews_error_vista")
  expect_error(vista_ejecutar_duckdb(raros, vista_crear("Patient", c(
    x = "name.given.first().length()"))), class = "fhirviews_error_vista")
})

test_that("las mayusculas dudosas cubren las diferencias entre DuckDB y V8", {
  # Recorre el plano básico hasta U+2FFF (data-raw/mayusculas.R lo hace con
  # todo Unicode)
  ct <- V8::v8()
  js <- jsonlite::fromJSON(ct$eval(paste0(
    "(function(){var u=[],l=[];for(var c=1;c<=0x2FFF;c++){",
    "var s=String.fromCharCode(c);u.push(s.toUpperCase());l.push(s.toLowerCase());}",
    "return JSON.stringify({u:u,l:l});})()")))
  con <- conectar_duckdb()
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  db <- DBI::dbGetQuery(con, paste0(
    "SELECT c, upper(chr(c::INTEGER)) AS u, lower(chr(c::INTEGER)) AS l, ",
    "regexp_matches(chr(c::INTEGER), ", texto_sql(re_mayusculas_dudosas), ") AS du, ",
    "regexp_matches(chr(c::INTEGER), ", texto_sql(re_minusculas_dudosas), ") AS dl ",
    "FROM range(1, 12288) t(c) ORDER BY c"))
  expect_true(all(db$du[js$u != db$u]))
  expect_true(all(db$dl[js$l != db$l]))
})

test_that("diferido devuelve una tabla de dbplyr", {
  skip_if_not_installed("dbplyr")
  skip_if_not_installed("dplyr")
  vista <- vista_crear("Observation", c(
    codigo = "code.coding.first().code",
    valor = "value.ofType(Quantity).value", valor_x = "value"))
  t <- vista_ejecutar_duckdb(caso, vista, diferido = TRUE)
  on.exit(DBI::dbDisconnect(dbplyr::remote_con(t)), add = TRUE)
  expect_s3_class(t, "tbl_dbi")
  v8 <- vista_ejecutar(caso, vista)
  local <- dplyr::collect(t)
  expect_identical(local$id, v8$id)
  expect_identical(local$valor, v8$valor)
  n <- dplyr::collect(dplyr::summarise(dplyr::filter(t, !is.na(valor)),
                                       n = dplyr::n()))$n
  expect_equal(n, sum(!is.na(v8$valor)))

  # Con recursos de R y una conexión propia
  con <- conectar_duckdb()
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  t2 <- vista_ejecutar_duckdb(fhir_recursos(caso), vista, con_db = con,
                              diferido = TRUE)
  expect_identical(dplyr::collect(t2)$valor, v8$valor)
  expect_error(vista_ejecutar_duckdb(caso, vista, tabla = "x", diferido = TRUE),
               class = "fhirviews_error")
  expect_error(vista_ejecutar_duckdb(caso, vista, diferido = NA),
               class = "fhirviews_error")
})

test_that("DuckDB lee un Bundle de una sola entrada", {
  # Una busqueda con un solo resultado: el texto de la pagina es un Bundle y
  # no se puede escribir como una linea de NDJSON
  b <- paste0('{"resourceType":"Bundle","type":"searchset","entry":',
              '[{"resource":{"resourceType":"Patient","id":"p1",',
              '"gender":"female"}}]}')
  v <- vista_crear("Patient", c(sexo = "gender"))
  esperado <- vista_ejecutar(b, v)
  expect_identical(nrow(esperado), 1L)
  expect_identical(vista_ejecutar_duckdb(fhir_recursos(b), v), esperado)
  # Texto JSON y archivos .json (un Bundle en varias lineas) tambien
  expect_identical(vista_ejecutar_duckdb(b, v), esperado)
  archivo <- withr_tempfile(".json")
  writeLines(jsonlite::prettify(b), archivo)
  expect_identical(vista_ejecutar_duckdb(archivo, v), esperado)
})

test_that("DuckDB no altera el generador de numeros aleatorios", {
  obs <- list(list(resourceType = "Observation", id = "o1", status = "final",
                   extension = list(list(url = "u", valueString = "a"))))
  v <- vista_crear("Observation", c(x = "extension.value.first()"))
  set.seed(1)
  a <- stats::runif(1)
  set.seed(1)
  vista_ejecutar_duckdb(obs, v)
  expect_identical(stats::runif(1), a)
})
