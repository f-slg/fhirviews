#' Guardar vistas en DuckDB
#'
#' Ejecuta uno o varios `ViewDefinition` con [vista_ejecutar()] y guarda cada
#' resultado como una tabla en una base [DuckDB](https://duckdb.org/), para
#' consultarlas y unirlas con SQL. Es la idea original de SQL on FHIR: vistas
#' tabulares de los recursos FHIR listas para cualquier motor SQL.
#'
#' Las columnas con `collection: true` se guardan como listas de DuckDB
#' (por ejemplo `VARCHAR[]`), que se pueden consultar con `unnest()` o
#' `len()`. Los elementos complejos (objetos FHIR) se guardan como texto
#' JSON. Las fechas quedan como texto ISO 8601; para convertirlas usa
#' `CAST(columna AS DATE)` en la consulta cuando sean fechas completas.
#'
#' Requiere los paquetes DBI y duckdb. Funciona también con otra conexión
#' DBI (SQLite, PostgreSQL...) siempre que admita los tipos de las columnas.
#'
#' @param recursos Recursos FHIR en cualquier forma que acepte
#'   [fhir_recursos()].
#' @param vistas Un `ViewDefinition` (en cualquier forma que acepte
#'   [vista_leer()]) o una lista de ellos. Las tablas se llaman como el
#'   nombre de cada elemento de la lista o, si no lo tiene, como el elemento
#'   `name` de la vista.
#' @param con_db Conexión DBI donde guardar las tablas. Si es `NULL` (por
#'   defecto), se crea una base DuckDB en memoria.
#' @param sobrescribir Si es `TRUE` (por defecto), reemplaza las tablas que ya
#'   existan; si es `FALSE`, agrega las filas al final.
#'
#' @return La conexión DBI, de forma invisible, para seguir consultándola con
#'   [DBI::dbGetQuery()]. Cierra con `DBI::dbDisconnect(con_db)` al terminar.
#' @export
#' @examplesIf requireNamespace("duckdb", quietly = TRUE)
#' pacientes <- list(
#'   list(resourceType = "Patient", id = "p1", gender = "female",
#'        birthDate = "1985-03-12",
#'        name = list(list(family = "Paredes Cevallos",
#'                         given = list("Ana", "Luc\u00eda")))),
#'   list(resourceType = "Patient", id = "p2", gender = "male",
#'        birthDate = "2001-11-30",
#'        name = list(list(family = "Salazar Moreno", given = list("Jorge"))))
#' )
#' observaciones <- list(
#'   list(resourceType = "Observation", id = "o1", status = "final",
#'        code = list(text = "Glucosa"), subject = list(reference = "Patient/p1"),
#'        valueQuantity = list(value = 98, unit = "mg/dL")),
#'   list(resourceType = "Observation", id = "o2", status = "final",
#'        code = list(text = "Glucosa"), subject = list(reference = "Patient/p2"),
#'        valueQuantity = list(value = 131, unit = "mg/dL"))
#' )
#'
#' db <- vista_duckdb(
#'   c(fhir_recursos(pacientes), observaciones),
#'   list(
#'     paciente = vista_crear("Patient", c(sexo = "gender",
#'                                          nombres = "name.given.join(' ')")),
#'     glucosa = vista_crear("Observation", c(
#'       paciente = "subject.getReferenceKey(Patient)",
#'       valor = "value.ofType(Quantity).value"))
#'   )
#' )
#' DBI::dbGetQuery(db, "
#'   SELECT p.nombres, p.sexo, g.valor
#'   FROM glucosa g JOIN paciente p ON g.paciente = p.id
#'   ORDER BY g.valor DESC")
#' DBI::dbDisconnect(db)
vista_duckdb <- function(recursos, vistas, con_db = NULL, sobrescribir = TRUE) {
  rlang::check_installed("DBI", reason = "para guardar vistas en una base SQL.")
  vistas <- lista_vistas(vistas)
  if (is.null(con_db)) {
    con_db <- conectar_duckdb()
  }
  recursos <- fhir_recursos(recursos)
  for (nombre in names(vistas)) {
    df <- vista_ejecutar(recursos, vistas[[nombre]])
    df <- preparar_tabla_sql(df)
    DBI::dbWriteTable(con_db, nombre, df, overwrite = sobrescribir,
                      append = !sobrescribir)
  }
  invisible(con_db)
}

conectar_duckdb <- function() {
  rlang::check_installed("duckdb", reason = "para guardar vistas en DuckDB.")
  # Sin `shared_home` DuckDB guarda extensiones en ~/.duckdb
  argumentos <- list()
  if ("shared_home" %in% names(formals(duckdb::duckdb))) {
    argumentos$shared_home <- FALSE
  }
  DBI::dbConnect(do.call(duckdb::duckdb, argumentos))
}

# Lista con nombre de vistas leídas y validadas
lista_vistas <- function(vistas) {
  es_una <- inherits(vistas, "fhir_vista") || is.character(vistas) ||
    (is.list(vistas) && !is.null(vistas$resource))
  if (es_una) {
    vistas <- list(vistas)
  }
  vistas <- lapply(vistas, vista_leer)
  nombres <- names(vistas) %||% rep("", length(vistas))
  for (i in seq_along(vistas)) {
    if (!nzchar(nombres[i])) {
      nombres[i] <- vistas[[i]]$name %||% ""
    }
  }
  if (any(!nzchar(nombres))) {
    cli::cli_abort(c(
      "Cada vista necesita un nombre para su tabla.",
      "i" = "Usa una lista con nombre ({.code list(pacientes = vista)}) o el
             elemento {.field name} del ViewDefinition."
    ), class = "fhirviews_error")
  }
  malos <- nombres[!grepl(patron_nombre, nombres)]
  if (length(malos) > 0L) {
    cli::cli_abort(c(
      "Nombre de tabla no v\u00e1lido: {.val {malos}}.",
      "i" = "Usa solo letras, n\u00fameros y _, empezando con una letra."
    ), class = "fhirviews_error")
  }
  if (anyDuplicated(nombres)) {
    cli::cli_abort("Hay vistas con el mismo nombre de tabla: {.val {unique(nombres[duplicated(nombres)])}}.",
                   class = "fhirviews_error")
  }
  stats::setNames(vistas, nombres)
}

# Columnas de lista: se dejan las de valores simples (listas de DuckDB) y se
# convierten a JSON las que tienen objetos.
preparar_tabla_sql <- function(df) {
  for (nm in names(df)) {
    col <- df[[nm]]
    if (!is.list(col)) next
    simples <- vapply(col, function(x) is.null(x) || is.atomic(x), logical(1))
    if (all(simples)) {
      df[[nm]] <- lapply(col, function(x) if (is.null(x)) character() else x)
    } else {
      df[[nm]] <- vapply(col, function(x) {
        if (is.null(x)) NA_character_ else
          as.character(jsonlite::toJSON(x, auto_unbox = TRUE, digits = NA,
                                        null = "null"))
      }, character(1))
    }
  }
  df
}
