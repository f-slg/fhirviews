# -----------------------------------------------------------------------------
# fhirviews · Medición de rendimiento (para el README)
#
# Mide el tiempo de vista_ejecutar() con pacientes sintéticos (dos nombres,
# una dirección y una condición where) leídos desde NDJSON (texto JSON
# original) y desde listas de R. Guarda data-raw/rendimiento.csv.
#
# Uso: Rscript data-raw/rendimiento.R
# -----------------------------------------------------------------------------
library(fhirviews)
set.seed(1)

paciente <- function(i) {
  sprintf(paste0(
    '{"resourceType":"Patient","id":"p%d","gender":"%s","birthDate":"%d-%02d-15",',
    '"name":[{"use":"official","family":"Apellido%d","given":["Nombre","Segundo"]},',
    '{"use":"usual","given":["Apodo"]}],',
    '"address":[{"use":"home","city":"Ciudad%d","district":"Canton%d","country":"EC"}]}'),
    i, sample(c("female", "male"), 1), sample(1930:2020, 1), sample(1:12, 1),
    i, i %% 200, i %% 221)
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

medir <- function(expr, veces = 3) {
  stats::median(replicate(veces, system.time(force(expr()))[["elapsed"]]))
}
tamanos <- c(1000, 5000, 10000, 25000, 50000)
res <- do.call(rbind, lapply(tamanos, function(n) {
  lineas <- vapply(seq_len(n), paciente, character(1))
  r_json <- fhir_recursos(lineas)
  r_lista <- fhir_recursos(lapply(lineas, jsonlite::fromJSON,
                                  simplifyVector = FALSE))
  filas <- nrow(vista_ejecutar(r_json, vista))
  t_json <- medir(function() vista_ejecutar(r_json, vista))
  t_lista <- if (n <= 25000) medir(function() vista_ejecutar(r_lista, vista)) else NA
  message(n, ": ", t_json, " s (JSON), ", t_lista, " s (listas)")
  data.frame(recursos = n, filas = filas, json = t_json, listas = t_lista)
}))
res$equipo <- paste(Sys.info()[["sysname"]], R.version$major, R.version$minor,
                    sep = " ")
utils::write.csv(res, "data-raw/rendimiento.csv", row.names = FALSE)
print(res)
