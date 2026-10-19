# -----------------------------------------------------------------------------
# fhirviews · Rendimiento del motor DuckDB frente al motor V8
#
# Escribe pacientes sintéticos (los mismos de data-raw/rendimiento.R) en
# NDJSON y mide vista_ejecutar() (V8) y vista_ejecutar_duckdb() con la misma
# vista. Guarda data-raw/motor-duckdb.csv.
#
# Uso: Rscript data-raw/motor-duckdb.R [tamaños] [máximo para V8] [csv]
#   Rscript data-raw/motor-duckdb.R 50000,250000,1000000 250000
# V8 solo se mide hasta 250 000 recursos por defecto: con 1 millón necesita
# más memoria de la que tiene un portátil típico.
# -----------------------------------------------------------------------------
library(fhirviews)
args <- commandArgs(TRUE)
tamanos <- if (length(args) >= 1) as.numeric(strsplit(args[1], ",")[[1]]) else
  c(50000, 1000000)
maximo_v8 <- if (length(args) >= 2) as.numeric(args[2]) else 250000
salida <- if (length(args) >= 3) args[3] else "data-raw/motor-duckdb.csv"
set.seed(1)

pacientes <- function(n) {
  i <- seq_len(n)
  sprintf(paste0(
    '{"resourceType":"Patient","id":"p%d","gender":"%s","birthDate":"%d-%02d-15",',
    '"name":[{"use":"official","family":"Apellido%d","given":["Nombre","Segundo"]},',
    '{"use":"usual","given":["Apodo"]}],',
    '"address":[{"use":"home","city":"Ciudad%d","district":"Canton%d","country":"EC"}]}'),
    i, sample(c("female", "male"), n, TRUE), sample(1930:2020, n, TRUE),
    sample(1:12, n, TRUE), i, i %% 200, i %% 221)
}
vista <- vista_leer('{
  "resource": "Patient",
  "where": [{"path": "birthDate > @1940-01-01"}],
  "select": [
    {"column": [
      {"name": "id", "path": "getResourceKey()"},
      {"name": "sexo", "path": "gender"},
      {"name": "nacimiento", "path": "birthDate", "type": "date"},
      {"name": "canton", "path": "address.where(use = \'home\').district.first()"}
    ]},
    {"forEach": "name", "column": [
      {"name": "orden", "path": "%rowIndex"},
      {"name": "uso", "path": "use"},
      {"name": "nombres", "path": "given.join(\' \')"}
    ]}
  ]
}')

segundos <- function(expr) system.time(force(expr))[["elapsed"]]
con <- fhirviews:::conectar_duckdb()
res <- do.call(rbind, lapply(tamanos, function(n) {
  archivo <- tempfile(fileext = ".ndjson")
  writeLines(pacientes(n), archivo)
  mb <- file.size(archivo) / 2^20
  # DuckDB: dos corridas (la primera calienta la caché del sistema)
  vista_ejecutar_duckdb(archivo, vista, con_db = con, tabla = "calentar")
  t_tabla <- segundos(vista_ejecutar_duckdb(archivo, vista, con_db = con,
                                            tabla = "resultado"))
  t_df <- segundos(db <- vista_ejecutar_duckdb(archivo, vista, con_db = con))
  t_v8 <- NA
  if (n <= maximo_v8) {
    gc()
    t_v8 <- segundos({
      recursos <- fhir_recursos(archivo)
      v8 <- vista_ejecutar(recursos, vista)
    })
    stopifnot(isTRUE(all.equal(db, v8, check.attributes = FALSE)))
    rm(recursos, v8)
  }
  unlink(archivo)
  message(sprintf("%d recursos (%.0f MB): DuckDB %.1f s (tabla) / %.1f s (data.frame), V8 %s s",
                  n, mb, t_tabla, t_df, format(t_v8)))
  data.frame(recursos = format(n, scientific = FALSE), mb = round(mb),
             filas = nrow(db),
             duckdb_tabla = round(t_tabla, 3), duckdb_df = round(t_df, 3),
             v8 = t_v8)
}))
DBI::dbDisconnect(con)
res$equipo <- paste(Sys.info()[["sysname"]], parallel::detectCores(), "nucleos,",
                    "R", paste(R.version$major, R.version$minor, sep = "."),
                    "duckdb", as.character(utils::packageVersion("duckdb")))
utils::write.csv(res, salida, row.names = FALSE)
print(res)
