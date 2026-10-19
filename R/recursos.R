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
    return(recursos_desde_texto(x))
  }
  if (inherits(x, "fhir_respuesta")) {
    texto <- attr(x, "texto")
    x <- unclass(x)
    attributes(x) <- list(names = names(x))
    r <- recursos_desde_lista(x)
    fuente <- if (!is.null(texto) && nzchar(texto)) texto
    return(nuevo_fhir_recursos(r, fuente = fuente))
  }
  if (!is.list(x)) {
    cli::cli_abort(c(
      "{.arg x} debe ser una lista, texto JSON o la ruta a un archivo.",
      "x" = "Se recibi\u00f3 un objeto de clase {.cls {class(x)}}."
    ), class = "fhirviews_error")
  }
  nuevo_fhir_recursos(recursos_desde_lista(x))
}

# `fuente` guarda el texto JSON del que salieron los recursos (si se leyeron
# de texto o de archivos) para que el motor lo use sin volver a convertirlos
# a JSON. Cualquier modificación de la lista lo descarta.
nuevo_fhir_recursos <- function(x, fuente = NULL) {
  if (is.null(x)) x <- list()
  structure(unname(x), class = c("fhir_recursos", "list"), fuente = fuente)
}

sin_fuente <- function(x) {
  attr(x, "fuente") <- NULL
  x
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
    return(recursos_ndjson(x))
  }
  datos <- tryCatch(parsear_json(x), error = function(e) NULL)
  if (is.null(datos)) {
    return(recursos_ndjson(strsplit(x, "\r?\n")[[1]]))
  }
  nuevo_fhir_recursos(recursos_desde_lista(datos), fuente = x)
}

# Un recurso JSON por elemento (o por línea de NDJSON)
recursos_ndjson <- function(lineas) {
  lineas <- lineas[nzchar(trimws(lineas))]
  recursos <- lapply(lineas, parsear_json)
  nuevo_fhir_recursos(unlist(lapply(recursos, recursos_desde_lista),
                             recursive = FALSE), fuente = lineas)
}

recursos_desde_archivo <- function(ruta) {
  lineas <- readLines(ruta, encoding = "UTF-8", warn = FALSE)
  if (grepl("\\.ndjson$", ruta, ignore.case = TRUE)) {
    return(recursos_ndjson(lineas))
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
  nuevo_fhir_recursos(unclass(sin_fuente(x))[i])
}

#' @export
`[<-.fhir_recursos` <- function(x, i, value) {
  x <- unclass(sin_fuente(x))
  x[i] <- value
  nuevo_fhir_recursos(x)
}

#' @export
`[[<-.fhir_recursos` <- function(x, i, value) {
  x <- unclass(sin_fuente(x))
  x[[i]] <- value
  nuevo_fhir_recursos(x)
}

#' @export
`$<-.fhir_recursos` <- function(x, name, value) {
  cli::cli_abort("Usa {.code [[ ]]} para modificar un recurso de la lista.",
                 class = "fhirviews_error")
}

#' @export
c.fhir_recursos <- function(...) {
  partes <- lapply(list(...), fhir_recursos)
  fuentes <- lapply(partes, attr, "fuente")
  fuente <- if (all(!vapply(fuentes, is.null, logical(1)))) unlist(fuentes)
  nuevo_fhir_recursos(unlist(lapply(partes, function(p) unclass(sin_fuente(p))),
                             recursive = FALSE), fuente = fuente)
}
