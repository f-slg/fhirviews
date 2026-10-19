#' Reunir recursos FHIR en una lista
#'
#' Convierte las formas habituales de recibir datos FHIR en una lista de
#' recursos, que es lo que usan [vista_fhirpath()] y el resto de funciones de
#' vistas.
#'
#' @param x Recursos FHIR en cualquiera de estas formas:
#'   * un recurso (lista de R con `resourceType`);
#'   * un `Bundle`: se toman los recursos de `entry[].resource`;
#'   * una lista de recursos o de Bundles;
#'   * texto JSON con un recurso, un Bundle o un arreglo de recursos;
#'   * texto NDJSON (un recurso por línea) o un vector de caracteres con un
#'     recurso JSON por elemento;
#'   * la ruta a un archivo `.json` o `.ndjson`.
#'
#' @return Una lista de recursos (listas de R) de clase `fhir_recursos`.
#' @export
#' @examples
#' paciente <- '{"resourceType": "Patient", "id": "p1",
#'               "name": [{"family": "Paredes Cevallos", "given": ["Ana"]}]}'
#' fhir_recursos(paciente)
#'
#' ndjson <- c('{"resourceType": "Patient", "id": "p1"}',
#'             '{"resourceType": "Observation", "id": "o1", "status": "final"}')
#' fhir_recursos(ndjson)
fhir_recursos <- function(x) {
  if (inherits(x, "fhir_recursos")) {
    return(x)
  }
  if (is.null(x)) {
    return(nuevo_fhir_recursos(list()))
  }
  if (is.character(x)) {
    return(nuevo_fhir_recursos(recursos_desde_texto(x)))
  }
  if (!is.list(x)) {
    cli::cli_abort(c(
      "{.arg x} debe ser una lista, texto JSON o la ruta a un archivo.",
      "x" = "Se recibi\u00f3 un objeto de clase {.cls {class(x)}}."
    ), class = "fhirviews_error")
  }
  nuevo_fhir_recursos(recursos_desde_lista(x))
}

nuevo_fhir_recursos <- function(x) {
  structure(unname(x), class = c("fhir_recursos", "list"))
}

recursos_desde_lista <- function(x) {
  if (!is.null(x[["resourceType"]])) {
    if (identical(x[["resourceType"]], "Bundle")) {
      entradas <- x[["entry"]]
      res <- lapply(entradas, function(e) e[["resource"]])
      return(res[!vapply(res, is.null, logical(1))])
    }
    return(list(x))
  }
  if (length(x) > 0L && !is.null(names(x)) && any(names(x) != "")) {
    cli::cli_abort(c(
      "La lista no parece un recurso FHIR: le falta {.field resourceType}.",
      "i" = "Pasa un recurso, un Bundle o una lista sin nombres de recursos."
    ), class = "fhirviews_error")
  }
  unlist(lapply(x, function(e) {
    if (is.character(e)) recursos_desde_texto(e) else recursos_desde_lista(e)
  }), recursive = FALSE)
}

recursos_desde_texto <- function(x) {
  if (length(x) == 1L && !grepl("^\\s*[[{]", x) && file.exists(x)) {
    return(recursos_desde_archivo(x))
  }
  if (length(x) > 1L) {
    x <- x[nzchar(trimws(x))]
    return(lapply(x, parsear_json))
  }
  datos <- tryCatch(parsear_json(x), error = function(e) NULL)
  if (is.null(datos)) {
    lineas <- strsplit(x, "\r?\n")[[1]]
    lineas <- lineas[nzchar(trimws(lineas))]
    return(lapply(lineas, parsear_json))
  }
  recursos_desde_lista(datos)
}

recursos_desde_archivo <- function(ruta) {
  lineas <- readLines(ruta, encoding = "UTF-8", warn = FALSE)
  if (grepl("\\.ndjson$", ruta, ignore.case = TRUE)) {
    lineas <- lineas[nzchar(trimws(lineas))]
    return(lapply(lineas, parsear_json))
  }
  recursos_desde_texto(paste(lineas, collapse = "\n"))
}

parsear_json <- function(texto) {
  tryCatch(
    jsonlite::fromJSON(texto, simplifyVector = FALSE),
    error = function(e) {
      cli::cli_abort(c(
        "No se pudo leer el texto como JSON.",
        "x" = "{conditionMessage(e)}"
      ), class = "fhirviews_error", call = NULL)
    }
  )
}

#' @export
print.fhir_recursos <- function(x, ...) {
  tipos <- vapply(x, function(r) {
    t <- r[["resourceType"]]
    if (is.null(t)) NA_character_ else as.character(t)
  }, character(1))
  cat("<fhir_recursos> ", length(x),
      if (length(x) == 1L) " recurso" else " recursos", "\n", sep = "")
  if (length(x) > 0L) {
    tabla <- table(tipos, useNA = "ifany")
    cat(paste0("  ", names(tabla), ": ", tabla, collapse = "\n"), "\n", sep = "")
  }
  invisible(x)
}

#' @export
`[.fhir_recursos` <- function(x, i) {
  nuevo_fhir_recursos(unclass(x)[i])
}

#' @export
c.fhir_recursos <- function(...) {
  partes <- lapply(list(...), function(p) unclass(fhir_recursos(p)))
  nuevo_fhir_recursos(unlist(partes, recursive = FALSE))
}
