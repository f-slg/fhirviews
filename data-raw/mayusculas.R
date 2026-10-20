# -----------------------------------------------------------------------------
# fhirviews · Caracteres que DuckDB y JavaScript pasan a mayúsculas o
# minúsculas de forma distinta
#
# upper()/lower() de DuckDB usan una tabla de Unicode distinta de
# toUpperCase()/toLowerCase() de JavaScript (por ejemplo, "ß" pasa a "SS" en
# JavaScript y queda igual en DuckDB; "Σ" final pasa a "ς"). El motor DuckDB
# da error si el texto tiene alguno de estos caracteres (re_mayusculas_dudosas
# y re_minusculas_dudosas en R/sql-fhirpath.R). Este script recorre todo
# Unicode y escribe los rangos; hay que volver a correrlo al actualizar
# fhirpath.js, V8 o duckdb. Los caracteres fuera del plano básico se tratan
# siempre como dudosos (JavaScript los cuenta como dos unidades).
#
# Uso: Rscript data-raw/mayusculas.R
# -----------------------------------------------------------------------------
ct <- V8::v8()
js <- jsonlite::fromJSON(ct$eval(paste0(
  "(function(){var u=[],l=[];for(var c=1;c<=0xFFFF;c++){",
  "if(c>=0xD800&&c<=0xDFFF)continue;var s=String.fromCodePoint(c);",
  "u.push(s.toUpperCase());l.push(s.toLowerCase());}",
  "return JSON.stringify({u:u,l:l});})()")))
puntos <- setdiff(1:0xFFFF, 0xD800:0xDFFF)
con <- DBI::dbConnect(duckdb::duckdb(shared_home = FALSE))
db <- DBI::dbGetQuery(con, paste(
  "SELECT c, upper(chr(c::INTEGER)) AS u, lower(chr(c::INTEGER)) AS l",
  "FROM range(1, 65536) t(c) WHERE c < 55296 OR c > 57343 ORDER BY c"))
DBI::dbDisconnect(con)
stopifnot(identical(as.integer(db$c), as.integer(puntos)))

rangos <- function(x) {
  grupos <- split(x, cumsum(c(1, diff(x) != 1)))
  paste(vapply(grupos, function(v) {
    if (length(v) == 1L) sprintf("\\\\x{%X}", v) else
      sprintf("\\\\x{%X}-\\\\x{%X}", v[1], v[length(v)])
  }, character(1)), collapse = "")
}
cat("V8", V8::engine_info()$version, "/ duckdb",
    as.character(utils::packageVersion("duckdb")), "\n")
cat("re_mayusculas_dudosas: [", rangos(puntos[js$u != db$u]),
    "\\\\x{10000}-\\\\x{10FFFF}]\n", sep = "")
cat("re_minusculas_dudosas: [", rangos(puntos[js$l != db$l]),
    "\\\\x{10000}-\\\\x{10FFFF}]\n", sep = "")
