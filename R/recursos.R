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
#'   * la ruta a un archivo `.json`, `.ndjson` o `.ndjson.gz`, o un vector de
#'     rutas (los recursos de todos los archivos se juntan).
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
    return(nuevo_fhir_recursos(r, fuente = fuente,
                               alineada = es_recurso_suelto(x)))
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
#
# `alineada` indica que cada texto de `fuente` es exactamente un recurso, en
# el mismo orden (no un Bundle ni un arreglo), y que se puede escribir tal cual
# como una línea de NDJSON.
nuevo_fhir_recursos <- function(x, fuente = NULL, alineada = FALSE) {
  if (is.null(x)) x <- list()
  structure(unname(x), class = c("fhir_recursos", "list"), fuente = fuente,
            fuente_alineada = if (!is.null(fuente)) isTRUE(alineada))
}

sin_fuente <- function(x) {
  attr(x, "fuente") <- NULL
  attr(x, "fuente_alineada") <- NULL
  x
}

# Textos de `fuente` que se pueden escribir como NDJSON (uno por recurso), o
# NULL
fuente_alineada <- function(x) {
  fuente <- attr(x, "fuente")
  if (!isTRUE(attr(x, "fuente_alineada")) || length(fuente) != length(x)) {
    return(NULL)
  }
  fuente
}

# Un recurso que no es Bundle (un texto que da exactamente ese recurso)
es_recurso_suelto <- function(x) {
  is.list(x) && es_texto(x[["resourceType"]]) &&
    !identical(x[["resourceType"]], "Bundle")
}

recursos_desde_lista <- function(x) {
  if (!is.list(x)) {
    cli::cli_abort(c(
      "No se reconoce un recurso FHIR en los datos.",
      "x" = "Se encontr\u00f3 un valor de clase {.cls {class(x)}} donde se
             esperaba un recurso (lista con {.field resourceType}) o un
             Bundle."
    ), class = "fhirviews_error", call = NULL)
  }
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
  x <- x[!is.na(x)]
  es_json <- grepl("^\\s*[[{]", x)
  # Rutas de archivo: todo lo que no empieza como JSON
  if (length(x) > 0L && !any(es_json)) {
    faltan <- x[!file.exists(x)]
    if (length(faltan) > 0L) {
      cli::cli_abort(c(
        "No se encontr\u00f3 {cli::qty(length(faltan))}el archivo{?s} {.file {faltan}}.",
        "i" = "Directorio de trabajo: {.file {getwd()}}."
      ), class = "fhirviews_error", call = NULL)
    }
    partes <- lapply(x, recursos_desde_archivo)
    return(do.call(c.fhir_recursos, partes))
  }
  if (length(x) > 1L) {
    if (!all(es_json | !nzchar(trimws(x)))) {
      cli::cli_abort(c(
        "El vector mezcla texto JSON con otras cosas.",
        "i" = "Pasa rutas de archivo o un recurso JSON por elemento, no ambos."
      ), class = "fhirviews_error", call = NULL)
    }
    return(recursos_ndjson(x))
  }
  datos <- tryCatch(parsear_json(x), error = function(e) NULL)
  if (is.null(datos)) {
    return(recursos_ndjson(strsplit(x, "\r?\n")[[1]]))
  }
  nuevo_fhir_recursos(recursos_desde_lista(datos), fuente = x,
                      alineada = es_recurso_suelto(datos))
}

# Un recurso JSON por elemento (o por línea de NDJSON)
recursos_ndjson <- function(lineas) {
  lineas <- lineas[nzchar(trimws(lineas))]
  recursos <- lapply(lineas, parsear_json)
  nuevo_fhir_recursos(unlist(lapply(recursos, recursos_desde_lista),
                             recursive = FALSE), fuente = lineas,
                      alineada = all(vapply(recursos, es_recurso_suelto,
                                            logical(1))))
}

recursos_desde_archivo <- function(ruta) {
  lineas <- readLines(ruta, encoding = "UTF-8", warn = FALSE)
  if (!any(nzchar(trimws(lineas)))) {
    return(nuevo_fhir_recursos(list(), fuente = character(), alineada = TRUE))
  }
  if (grepl("\\.ndjson(\\.gz)?$", ruta, ignore.case = TRUE)) {
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
  alineada <- all(vapply(partes, function(p) isTRUE(attr(p, "fuente_alineada")),
                         logical(1)))
  nuevo_fhir_recursos(unlist(lapply(partes, function(p) unclass(sin_fuente(p))),
                             recursive = FALSE), fuente = fuente,
                      alineada = alineada)
}
