# Se ejecuta desde probar-sql-dbi.sh contra sus dos contenedores propios.
options(warn = 2)
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 2L)
raiz <- normalizePath(args[1])
salida <- normalizePath(args[2])
pkgload::load_all(raiz, quiet = TRUE)
library(testthat)

espera <- as.integer(Sys.getenv("FHIRVIEWS_SQL_ESPERA", "120"))
stopifnot(!is.na(espera), espera > 0L, nzchar(Sys.getenv("FHIRVIEWS_SQL_PASSWORD")))
contexto <- list()
conectar <- function(motor) {
  limite <- Sys.time() + espera
  repeat {
    con <- tryCatch(if (motor == "postgres") {
      DBI::dbConnect(RPostgres::Postgres(), host = "127.0.0.1",
        port = as.integer(Sys.getenv("FHIRVIEWS_PG_PORT")),
        dbname = "fhirviews_pruebas", user = "fhirviews",
        password = Sys.getenv("FHIRVIEWS_SQL_PASSWORD"),
        connect_timeout = 3, timezone = "UTC")
    } else {
      DBI::dbConnect(odbc::odbc(),
        Driver = Sys.getenv("FHIRVIEWS_ODBC_DRIVER", "ODBC Driver 18 for SQL Server"),
        Server = paste0("127.0.0.1,", Sys.getenv("FHIRVIEWS_MSSQL_PORT")),
        Database = "tempdb", UID = "sa", PWD = Sys.getenv("FHIRVIEWS_SQL_PASSWORD"),
        Encrypt = "yes", TrustServerCertificate = "yes", timeout = 3,
        timezone = "UTC", timezone_out = "UTC")
    }, error = identity)
    if (!inherits(con, "error")) return(con)
    if (Sys.time() >= limite) stop("No se pudo conectar a ", motor, ": ", conditionMessage(con))
    Sys.sleep(2)
  }
}

probar <- function(motor) {
  con <- conectar(motor)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  pg <- motor == "postgres"
  marca <- function(i) if (pg) paste0("$", i) else "?"
  texto <- function(columna) paste0("CAST(", columna, if (pg) " AS TEXT)" else " AS VARCHAR(40))")
  version <- DBI::dbGetQuery(con, if (pg) "SELECT version() AS version" else "SELECT @@VERSION AS version")$version
  info <- DBI::dbGetInfo(con)
  contexto[[motor]] <<- list(servidor = version,
    controlador_R = if (pg) "RPostgres" else "odbc",
    version_controlador_R = as.character(utils::packageVersion(if (pg) "RPostgres" else "odbc")),
    version_driver = info[["driver.version"]])
  DBI::dbExecute(con, paste0("CREATE TABLE pacientes (id BIGINT PRIMARY KEY, ",
    "sexo VARCHAR(12), nacimiento DATE, apellido ", if (pg) "TEXT" else "NVARCHAR(80)",
    ", nombre ", if (pg) "TEXT" else "NVARCHAR(80)", ", activo ", if (pg) "BOOLEAN" else "BIT", ")"))
  insertar <- paste0("INSERT INTO pacientes VALUES (", paste(vapply(1:6, marca, ""), collapse = ", "), ")")
  ids <- c("9007199254740993", "9007199254740994")
  DBI::dbExecute(con, insertar, params = list(ids[1], "female", as.Date("2000-02-29"), "Muñoz", "María", TRUE))
  DBI::dbExecute(con, insertar, params = list(ids[2], NA_character_, as.Date(NA), NA_character_, "José", FALSE))
  consulta <- paste0("SELECT ", texto("id"), " AS id, sexo, nacimiento, apellido, nombre, activo FROM pacientes")
  datos <- DBI::dbGetQuery(con, paste(consulta, "ORDER BY id"))
  test_that(paste(motor, "tipos nativos y BIGINT"), {
    expect_identical(datos$id, ids)
    expect_s3_class(datos$nacimiento, "Date")
    expect_identical(datos$activo, c(TRUE, FALSE))
    expect_identical(datos$apellido, c("Muñoz", NA_character_))
    expect_identical(datos$nombre, c("María", "José"))
  })
  mp <- fhir_mapa("Patient", c(id = "id", gender = "sexo", birthDate = "nacimiento",
    "name[0].family" = "apellido", "name[0].given[0]" = "nombre", active = "activo"))
  pacientes <- fhir_desde_sql(con, paste(consulta, "ORDER BY id"), mp)
  test_that(paste(motor, "Patient desde SQL"), {
    expect_length(pacientes, 2L)
    expect_identical(pacientes[[1]]$id, ids[1])
    expect_identical(pacientes[[1]]$name[[1]]$family, "Muñoz")
    expect_identical(pacientes[[1]]$name[[1]]$given, list("María"))
    expect_identical(pacientes[[1]]$birthDate, "2000-02-29")
    expect_true(pacientes[[1]]$active)
    expect_false(pacientes[[2]]$active)
    expect_null(pacientes[[2]]$birthDate)
    expect_null(pacientes[[2]]$gender)
    expect_null(pacientes[[2]]$name[[1]]$family)
  })
  test_that(paste(motor, "parametros, cero filas y errores de mapeo"), {
    uno <- fhir_desde_sql(con, paste(consulta, "WHERE", texto("id"), "=", marca(1)), mp, list(ids[1]))
    expect_length(uno, 1L)
    expect_identical(uno[[1]]$id, ids[1])
    expect_length(fhir_desde_sql(con, paste(consulta, "WHERE sexo =", marca(1)), mp,
      list("' OR 1=1 --")), 0L)
    expect_length(fhir_desde_sql(con, paste(consulta, "WHERE 1 = 0"), mp), 0L)
    expect_error(fhir_desde_sql(con, paste(consulta, "UNION ALL", consulta), mp),
      class = "fhirviews_error_mapeo")
    expect_error(fhir_desde_sql(con,
      paste0("SELECT ", texto("id"), " AS id, 'invalido' AS sexo FROM pacientes"),
      fhir_mapa("Patient", c(id = "id", gender = "sexo"))), class = "fhirviews_error_mapeo")
    expect_true(DBI::dbIsValid(con))
  })
  DBI::dbExecute(con, paste0("CREATE TABLE resultados (id VARCHAR(10) PRIMARY KEY, paciente BIGINT, ",
    "valor DECIMAL(12,2), unidad VARCHAR(20), registrado ", if (pg) "TIMESTAMPTZ" else "DATETIMEOFFSET(6)", ")"))
  DBI::dbExecute(con, paste0("INSERT INTO resultados VALUES ('o1', ", ids[1],
    ", 72.00, 'mg/dL', '2026-01-14T10:00:00-05:00'), ('o2', ", ids[2], ", NULL, NULL, NULL)"))
  # DATETIMEOFFSET se convierte explicitamente a una marca UTC nativa del
  # controlador; el CAST decimal a texto conserva la escala de la base.
  instante <- if (pg) "registrado" else "CAST(SWITCHOFFSET(registrado, '+00:00') AS DATETIME2(6))"
  qo <- paste0("SELECT id, ", texto("paciente"), " AS paciente, ", texto("valor"),
    " AS valor, unidad, ", instante, " AS momento FROM resultados ORDER BY id")
  mo <- fhir_mapa("Observation", c(id = "id", "subject.reference" = "paciente",
    "valueQuantity.value" = "valor", "valueQuantity.unit" = "unidad", effectiveDateTime = "momento"),
    constantes = list(status = "final", "code.text" = "Medición ficticia"),
    referencias = c("subject.reference" = "Patient"))
  observaciones <- fhir_desde_sql(con, qo, mo)
  test_that(paste(motor, "Observation, decimales y fechas con hora"), {
    expect_s3_class(DBI::dbGetQuery(con, qo)$momento, "POSIXct")
    expect_length(observaciones, 2L)
    expect_identical(observaciones[[1]]$subject$reference, paste0("Patient/", ids[1]))
    expect_identical(observaciones[[1]]$effectiveDateTime, "2026-01-14T15:00:00.000000Z")
    expect_match(attr(observaciones, "fuente")[[1]], '"value":72.00', fixed = TRUE)
    expect_null(observaciones[[2]]$valueQuantity)
    expect_null(observaciones[[2]]$effectiveDateTime)
    archivo <- file.path(salida, paste0(motor, "-recursos.ndjson"))
    fhir_escribir(c(pacientes, observaciones), archivo)
    expect_length(fhir_recursos(archivo), 4L)
    expect_equal(vista_fhirpath(fhir_recursos(archivo), "value.ofType(Quantity).value.lowBoundary()"),
      c(NA_real_, NA_real_, 71.995, NA_real_))
  })
  test_that(paste(motor, "retorno a tablas con V8 y DuckDB"), {
    vista <- vista_crear("Observation", c(paciente = "subject.getReferenceKey(Patient)",
      valor = "value.ofType(Quantity).value", limite = "value.ofType(Quantity).value.lowBoundary()"))
    v8 <- vista_ejecutar(observaciones, vista)
    sql <- vista_ejecutar_duckdb(observaciones, vista)
    expect_identical(v8$id, c("o1", "o2"))
    expect_identical(v8$paciente, ids)
    expect_equal(v8$valor, c(72, NA_real_))
    expect_equal(v8$limite, c(71.995, NA_real_))
    expect_equal(sql, v8)
  })
}

reporte <- testthat::ListReporter$new()
reporte$start_file("sql-dbi")
testthat::with_reporter(reporte, for (motor in c("postgres", "sqlserver")) probar(motor))
tabla <- as.data.frame(reporte$get_results())
tabla$detalle <- vapply(tabla$result, function(hechos) {
  fallos <- Filter(function(x) inherits(x, c("expectation_failure", "expectation_error", "expectation_warning")), hechos)
  paste(vapply(fallos, conditionMessage, character(1)), collapse = "\n")
}, character(1))
tabla$result <- NULL
utils::write.csv(tabla, file.path(salida, "resumen.csv"), row.names = FALSE, fileEncoding = "UTF-8")
jsonlite::write_json(list(version_fhirviews = as.character(utils::packageVersion("fhirviews")),
  motores = contexto, comprobaciones_aprobadas = sum(tabla$passed), grupos = tabla),
  file.path(salida, "resumen.json"), auto_unbox = TRUE, pretty = TRUE, null = "null")
writeLines(trimws(capture.output(utils::sessionInfo()), which = "right"),
  file.path(salida, "sessionInfo.txt"))
print(tabla[, c("test", "passed", "failed", "error", "warning", "skipped")], row.names = FALSE)
if (any(nzchar(tabla$detalle))) cat(paste(tabla$detalle[nzchar(tabla$detalle)], collapse = "\n"), "\n")
stopifnot(nrow(tabla) == 10L, !anyDuplicated(tabla$test), all(tabla$passed > 0L),
  !any(tabla$failed > 0L | tabla$error | tabla$warning > 0L | tabla$skipped))
cat("Integracion DBI aprobada: PostgreSQL y SQL Server, sin omisiones.\n")
