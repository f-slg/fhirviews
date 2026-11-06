# -----------------------------------------------------------------------------
# fhirviews · Comparación con fhircrackr
#
# Genera los mismos pacientes sintéticos de data-raw/motor-duckdb.R en dos
# formatos de entrada nativos:
#   - NDJSON para fhirviews (motores V8 y DuckDB)
#   - Bundles XML de 500 recursos para fhircrackr (formato de fhir_save/fhir_load)
# y obtiene la misma tabla con ambos paquetes: filtro por fecha, cuatro
# columnas por paciente y una fila por cada nombre (forEach / fhir_melt).
# Antes de medir comprueba que ambas tablas sean idénticas.
#
# Se miden dos tiempos:
#   - total: desde los archivos en disco hasta el data.frame final
#   - transformacion: solo la conversión, con los datos ya leídos en memoria
#
# Uso: Rscript data-raw/benchmark-fhircrackr.R [tamaños] [repeticiones] [csv]
#   Rscript data-raw/benchmark-fhircrackr.R 1000,10000,50000 3
# -----------------------------------------------------------------------------
if (requireNamespace("devtools", quietly = TRUE) && file.exists("DESCRIPTION")) {
  devtools::load_all(quiet = TRUE)
} else {
  library(fhirviews)
}
library(fhircrackr)
args <- commandArgs(TRUE)
tamanos <- if (length(args) >= 1) as.numeric(strsplit(args[1], ",")[[1]]) else
  c(1000, 10000, 50000)
repeticiones <- if (length(args) >= 2) as.integer(args[2]) else 3L
salida <- if (length(args) >= 3) args[3] else "data-raw/benchmark-fhircrackr.csv"
por_bundle <- 500L

# --- Datos sintéticos ---------------------------------------------------------
datos <- function(n) {
  set.seed(1)
  i <- seq_len(n)
  data.frame(i = i,
             sexo = sample(c("female", "male"), n, TRUE),
             anio = sample(1930:2020, n, TRUE),
             mes = sample(1:12, n, TRUE))
}
como_json <- function(d) {
  sprintf(paste0(
    '{"resourceType":"Patient","id":"p%d","gender":"%s","birthDate":"%d-%02d-15",',
    '"name":[{"use":"official","family":"Apellido%d","given":["Nombre","Segundo"]},',
    '{"use":"usual","given":["Apodo"]}],',
    '"address":[{"use":"home","city":"Ciudad%d","district":"Canton%d","country":"EC"}]}'),
    d$i, d$sexo, d$anio, d$mes, d$i, d$i %% 200, d$i %% 221)
}
como_xml <- function(d) {
  sprintf(paste0(
    '<entry><resource><Patient xmlns="http://hl7.org/fhir"><id value="p%d"/>',
    '<name><use value="official"/><family value="Apellido%d"/>',
    '<given value="Nombre"/><given value="Segundo"/></name>',
    '<name><use value="usual"/><given value="Apodo"/></name>',
    '<gender value="%s"/><birthDate value="%d-%02d-15"/>',
    '<address><use value="home"/><city value="Ciudad%d"/>',
    '<district value="Canton%d"/><country value="EC"/></address>',
    '</Patient></resource></entry>'),
    d$i, d$i, d$sexo, d$anio, d$mes, d$i %% 200, d$i %% 221)
}
escribir_bundles <- function(entradas, carpeta) {
  dir.create(carpeta)
  grupos <- split(entradas, ceiling(seq_along(entradas) / por_bundle))
  for (k in seq_along(grupos)) {
    writeLines(c('<Bundle xmlns="http://hl7.org/fhir"><type value="searchset"/>',
                 grupos[[k]], "</Bundle>"),
               file.path(carpeta, paste0(k, ".xml")))
  }
}

# --- fhirviews: la vista es un ViewDefinition estándar -----------------------
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

# --- fhircrackr: descripción XPath + crack + melt + limpieza en R ------------
diseno <- fhir_table_description(
  resource = "Patient",
  cols = c(id = "id", sexo = "gender", nacimiento = "birthDate",
           canton = "address[use/@value='home']/district",
           uso = "name/use", nombres = "name/given"),
  sep = "|", brackets = c("[", "]"), format = "compact"
)
crackr_tabla <- function(bundles) {
  df <- fhir_crack(bundles, diseno, verbose = 0)
  # where: XPath 1.0 no compara fechas, se filtra en R antes de expandir
  fecha <- as.Date(sub("^\\[[0-9.]+\\]", "", df$nacimiento))
  df <- df[fecha > as.Date("1940-01-01"), , drop = FALSE]
  # forEach name: una fila por nombre
  df <- fhir_melt(df, columns = c("uso", "nombres"), brackets = c("[", "]"),
                  sep = "|", all_columns = TRUE)
  df <- fhir_rm_indices(df, brackets = c("[", "]"))
  data.frame(
    id = df$id, sexo = df$sexo, nacimiento = as.Date(df$nacimiento),
    canton = df$canton,
    orden = stats::ave(seq_len(nrow(df)), df$resource_identifier,
                       FUN = seq_along) - 1L,
    uso = df$uso, nombres = gsub("|", " ", df$nombres, fixed = TRUE)
  )
}

# --- Comprobación de equivalencia --------------------------------------------
normalizar <- function(x) {
  x <- as.data.frame(x)[c("id", "sexo", "nacimiento", "canton", "orden",
                          "uso", "nombres")]
  x$orden <- as.integer(x$orden)
  x$nacimiento <- as.Date(x$nacimiento)
  x <- x[order(x$id, x$orden), ]
  rownames(x) <- NULL
  x
}

segundos <- function(expr) system.time(force(expr))[["elapsed"]]
mediana <- function(f) {
  stats::median(vapply(seq_len(repeticiones), function(r) {
    gc(); segundos(f())
  }, numeric(1)))
}
con <- fhirviews:::conectar_duckdb()

res <- do.call(rbind, lapply(tamanos, function(n) {
  d <- datos(n)
  ndjson <- tempfile(fileext = ".ndjson")
  writeLines(como_json(d), ndjson)
  carpeta <- tempfile("bundles")
  escribir_bundles(como_xml(d), carpeta)
  mb_json <- file.size(ndjson) / 2^20
  mb_xml <- sum(file.size(list.files(carpeta, full.names = TRUE))) / 2^20

  # Equivalencia (y calentamiento)
  recursos <- fhir_recursos(ndjson)
  bundles <- fhir_load(carpeta)
  v8 <- normalizar(vista_ejecutar(recursos, vista))
  db <- normalizar(vista_ejecutar_duckdb(ndjson, vista, con_db = con))
  cr <- normalizar(crackr_tabla(bundles))
  stopifnot(isTRUE(all.equal(v8, cr, check.attributes = FALSE)),
            isTRUE(all.equal(v8, db, check.attributes = FALSE)))

  fila <- data.frame(
    recursos = as.integer(n), filas = nrow(v8),
    mb_ndjson = round(mb_json, 1), mb_xml = round(mb_xml, 1),
    fhircrackr_total = mediana(function() crackr_tabla(fhir_load(carpeta))),
    fhircrackr_transformacion = mediana(function() crackr_tabla(bundles)),
    fhirviews_v8_total = mediana(function()
      vista_ejecutar(fhir_recursos(ndjson), vista)),
    fhirviews_v8_transformacion = mediana(function()
      vista_ejecutar(recursos, vista)),
    fhirviews_duckdb_total = mediana(function()
      vista_ejecutar_duckdb(ndjson, vista, con_db = con))
  )
  rm(recursos, bundles); unlink(ndjson); unlink(carpeta, recursive = TRUE)
  message(sprintf(
    "%d recursos: fhircrackr %.2f s · fhirviews V8 %.2f s · DuckDB %.2f s (total)",
    n, fila$fhircrackr_total, fila$fhirviews_v8_total,
    fila$fhirviews_duckdb_total))
  fila
}))
DBI::dbDisconnect(con)
res[grep("^fhir", names(res))] <- lapply(res[grep("^fhir", names(res))], round, 3)
res$equipo <- paste(Sys.info()[["sysname"]], parallel::detectCores(), "nucleos,",
                    "R", paste(R.version$major, R.version$minor, sep = "."),
                    "fhircrackr", as.character(utils::packageVersion("fhircrackr")),
                    "duckdb", as.character(utils::packageVersion("duckdb")))
utils::write.csv(res, salida, row.names = FALSE)
print(res)
