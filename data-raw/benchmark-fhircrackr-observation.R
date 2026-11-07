# -----------------------------------------------------------------------------
# fhirviews · Comparación con fhircrackr: Observation
#
# Complementa data-raw/benchmark-fhircrackr.R con un recurso más anidado:
#   - dos codificaciones por recurso (una local y una LOINC), que obligan a
#     filtrar por sistema
#   - elementos de elección (effectiveDateTime, valueQuantity)
#   - referencia al paciente
#   - componentes: la presión arterial trae sistólica y diastólica; la glucosa,
#     ninguno (forEachOrNull: una fila con componentes vacíos)
#   - un 10 % de observaciones preliminares que el filtro descarta
#
# Formatos de entrada: NDJSON para fhirviews y Bundles XML de 500 recursos para
# fhircrackr. Antes de medir comprueba que las tablas sean idénticas.
#
# Uso: Rscript data-raw/benchmark-fhircrackr-observation.R [tamaños] [repeticiones] [csv] [núcleos]
#   Rscript data-raw/benchmark-fhircrackr-observation.R 1000,10000,50000,100000 3
# [núcleos] es el argumento ncores de fhir_crack() (por defecto 1).
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
salida <- if (length(args) >= 3) args[3] else
  "data-raw/benchmark-fhircrackr-observation.csv"
nucleos <- if (length(args) >= 4) as.integer(args[4]) else 1L
por_bundle <- 500L
loinc <- "http://loinc.org"
local <- "http://hospital.ejemplo/codigos"

# --- Datos sintéticos ---------------------------------------------------------
datos <- function(n) {
  set.seed(1)
  i <- seq_len(n)
  data.frame(
    i = i,
    paciente = sample(seq_len(max(1, n %/% 5)), n, TRUE),
    presion = stats::runif(n) < 0.4,
    final = stats::runif(n) >= 0.1,
    mes = sample(1:12, n, TRUE), dia = sample(1:28, n, TRUE),
    glucosa = round(stats::runif(n, 60, 250), 1),
    sistolica = sample(90:180, n, TRUE), diastolica = sample(50:110, n, TRUE)
  )
}
como_json <- function(d) {
  base <- sprintf(paste0(
    '{"resourceType":"Observation","id":"o%d","status":"%s",'),
    d$i, ifelse(d$final, "final", "preliminary"))
  codigo <- ifelse(d$presion,
    sprintf('"code":{"coding":[{"system":"%s","code":"PA"},{"system":"%s","code":"85354-9"}]},', local, loinc),
    sprintf('"code":{"coding":[{"system":"%s","code":"GLU"},{"system":"%s","code":"2339-0"}]},', local, loinc))
  sujeto <- sprintf('"subject":{"reference":"Patient/p%d"},"effectiveDateTime":"2025-%02d-%02dT08:30:00Z"',
                    d$paciente, d$mes, d$dia)
  valor <- ifelse(d$presion,
    sprintf(paste0(',"component":[',
      '{"code":{"coding":[{"system":"%s","code":"S"},{"system":"%s","code":"8480-6"}]},',
      '"valueQuantity":{"value":%d,"unit":"mm[Hg]"}},',
      '{"code":{"coding":[{"system":"%s","code":"D"},{"system":"%s","code":"8462-4"}]},',
      '"valueQuantity":{"value":%d,"unit":"mm[Hg]"}}]}'),
      local, loinc, d$sistolica, local, loinc, d$diastolica),
    sprintf(',"valueQuantity":{"value":%s,"unit":"mg/dL"}}', format(d$glucosa, nsmall = 1, trim = TRUE)))
  paste0(base, codigo, sujeto, valor)
}
como_xml <- function(d) {
  codigo <- ifelse(d$presion,
    sprintf('<code><coding><system value="%s"/><code value="PA"/></coding><coding><system value="%s"/><code value="85354-9"/></coding></code>', local, loinc),
    sprintf('<code><coding><system value="%s"/><code value="GLU"/></coding><coding><system value="%s"/><code value="2339-0"/></coding></code>', local, loinc))
  valor <- ifelse(d$presion,
    sprintf(paste0(
      '<component><code><coding><system value="%s"/><code value="S"/></coding>',
      '<coding><system value="%s"/><code value="8480-6"/></coding></code>',
      '<valueQuantity><value value="%d"/><unit value="mm[Hg]"/></valueQuantity></component>',
      '<component><code><coding><system value="%s"/><code value="D"/></coding>',
      '<coding><system value="%s"/><code value="8462-4"/></coding></code>',
      '<valueQuantity><value value="%d"/><unit value="mm[Hg]"/></valueQuantity></component>'),
      local, loinc, d$sistolica, local, loinc, d$diastolica),
    sprintf('<valueQuantity><value value="%s"/><unit value="mg/dL"/></valueQuantity>',
            format(d$glucosa, nsmall = 1, trim = TRUE)))
  # Orden de elementos de FHIR R4: id, status, code, subject, effective[x],
  # value[x], component
  sprintf(paste0(
    '<entry><resource><Observation xmlns="http://hl7.org/fhir"><id value="o%d"/>',
    '<status value="%s"/>%s<subject><reference value="Patient/p%d"/></subject>',
    '<effectiveDateTime value="2025-%02d-%02dT08:30:00Z"/>%s</Observation></resource></entry>'),
    d$i, ifelse(d$final, "final", "preliminary"), codigo, d$paciente,
    d$mes, d$dia, valor)
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

# --- fhirviews: ViewDefinition estándar --------------------------------------
vista <- vista_leer('{
  "resource": "Observation",
  "where": [{"path": "status = \'final\'"}],
  "select": [
    {"column": [
      {"name": "id", "path": "getResourceKey()"},
      {"name": "paciente", "path": "subject.getReferenceKey(Patient)"},
      {"name": "loinc", "path": "code.coding.where(system = \'http://loinc.org\').code.first()"},
      {"name": "fecha", "path": "effective.ofType(dateTime)"},
      {"name": "valor", "path": "value.ofType(Quantity).value"},
      {"name": "unidad", "path": "value.ofType(Quantity).unit"}
    ]},
    {"forEachOrNull": "component", "column": [
      {"name": "comp_loinc", "path": "code.coding.where(system = \'http://loinc.org\').code.first()"},
      {"name": "comp_valor", "path": "value.ofType(Quantity).value"}
    ]}
  ]
}')

# --- fhircrackr: descripción XPath + crack + melt + limpieza en R ------------
diseno <- fhir_table_description(
  resource = "Observation",
  cols = c(id = "id", status = "status", paciente = "subject/reference",
           loinc = "code/coding[system/@value='http://loinc.org']/code",
           fecha = "effectiveDateTime",
           valor = "valueQuantity/value", unidad = "valueQuantity/unit",
           comp_loinc = "component/code/coding[system/@value='http://loinc.org']/code",
           comp_valor = "component/valueQuantity/value"),
  sep = "|", brackets = c("[", "]"), format = "compact"
)
sin_indice <- function(x) sub("^\\[[0-9.]+\\]", "", x)
crackr_tabla <- function(bundles) {
  df <- fhir_crack(bundles, diseno, verbose = 0, ncores = nucleos)
  df <- df[sin_indice(df$status) == "final", , drop = FALSE]
  # forEachOrNull component: se expanden las filas con componentes y se
  # conservan las demás con componentes vacíos
  con_comp <- !is.na(df$comp_loinc)
  expandidas <- fhir_melt(df[con_comp, , drop = FALSE],
                          columns = c("comp_loinc", "comp_valor"),
                          brackets = c("[", "]"), sep = "|", all_columns = TRUE)
  expandidas$resource_identifier <- NULL
  df <- rbind(df[!con_comp, , drop = FALSE], expandidas)
  df <- fhir_rm_indices(df, brackets = c("[", "]"))
  data.frame(
    id = df$id, paciente = sub("^Patient/", "", df$paciente), loinc = df$loinc,
    fecha = df$fecha, valor = as.numeric(df$valor), unidad = df$unidad,
    comp_loinc = df$comp_loinc, comp_valor = as.numeric(df$comp_valor)
  )
}

# --- Comprobación de equivalencia --------------------------------------------
normalizar <- function(x) {
  x <- as.data.frame(x)[c("id", "paciente", "loinc", "fecha", "valor",
                          "unidad", "comp_loinc", "comp_valor")]
  for (k in c("id", "paciente", "loinc", "unidad", "comp_loinc")) {
    x[[k]] <- as.character(x[[k]])
  }
  x$fecha <- format(as.POSIXct(as.character(x$fecha), tz = "UTC",
                               tryFormats = c("%Y-%m-%dT%H:%M:%OSZ",
                                              "%Y-%m-%dT%H:%M:%OS",
                                              "%Y-%m-%d %H:%M:%OS")),
                    "%Y-%m-%dT%H:%M:%S")
  x$valor <- as.numeric(x$valor)
  x$comp_valor <- as.numeric(x$comp_valor)
  x <- x[order(x$id, x$comp_loinc, na.last = TRUE), ]
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

  recursos <- fhir_recursos(ndjson)
  bundles <- fhir_load(carpeta)
  v8 <- normalizar(vista_ejecutar(recursos, vista))
  cr <- normalizar(crackr_tabla(bundles))
  stopifnot(isTRUE(all.equal(v8, cr, check.attributes = FALSE)))
  # El motor DuckDB es experimental: si no traduce la vista, se informa
  db <- tryCatch(normalizar(vista_ejecutar_duckdb(ndjson, vista, con_db = con)),
                 fhirviews_error_sql = function(e) {
                   message("DuckDB no traduce la vista: ", conditionMessage(e))
                   NULL
                 })
  if (!is.null(db)) stopifnot(isTRUE(all.equal(v8, db, check.attributes = FALSE)))

  fila <- data.frame(
    recursos = as.integer(n), filas = nrow(v8),
    mb_ndjson = round(mb_json, 1), mb_xml = round(mb_xml, 1),
    fhircrackr_total = mediana(function() crackr_tabla(fhir_load(carpeta))),
    fhircrackr_transformacion = mediana(function() crackr_tabla(bundles)),
    fhirviews_v8_total = mediana(function()
      vista_ejecutar(fhir_recursos(ndjson), vista)),
    fhirviews_v8_transformacion = mediana(function()
      vista_ejecutar(recursos, vista)),
    fhirviews_duckdb_total = if (is.null(db)) NA_real_ else mediana(function()
      vista_ejecutar_duckdb(ndjson, vista, con_db = con))
  )
  rm(recursos, bundles); unlink(ndjson); unlink(carpeta, recursive = TRUE)
  message(sprintf(
    "%d observaciones: fhircrackr %.2f s · fhirviews V8 %.2f s · DuckDB %s s (total)",
    n, fila$fhircrackr_total, fila$fhirviews_v8_total,
    format(round(fila$fhirviews_duckdb_total, 2))))
  fila
}))
DBI::dbDisconnect(con)
res[grep("^fhir", names(res))] <- lapply(res[grep("^fhir", names(res))], round, 3)
res$equipo <- paste(Sys.info()[["sysname"]], parallel::detectCores(), "nucleos,",
                    "R", paste(R.version$major, R.version$minor, sep = "."),
                    "fhircrackr", as.character(utils::packageVersion("fhircrackr")),
                    paste0("(ncores = ", nucleos, ")"),
                    "duckdb", as.character(utils::packageVersion("duckdb")))
utils::write.csv(res, salida, row.names = FALSE)
print(res)
