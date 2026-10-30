#' Tabla rápida de recursos FHIR
#'
#' Convierte recursos en una tabla con una fila por recurso y una columna por
#' cada elemento de primer nivel, sin escribir un `ViewDefinition`. Sirve
#' para echar un vistazo a los datos (es la vista previa del panel
#' *Connections* de RStudio); para tablas definitivas y reproducibles usa
#' [vista_ejecutar()].
#'
#' Los valores simples se copian tal cual; las listas de valores simples se
#' unen con `"; "`; los elementos complejos (por ejemplo `name` o `code`) se
#' muestran como JSON compacto.
#'
#' @param recursos Recursos FHIR en cualquier forma que acepte
#'   [fhir_recursos()].
#' @param tipo Tipo de recurso opcional para quedarse solo con ese tipo.
#' @param max_caracteres Largo máximo del texto de cada celda compleja; se
#'   recorta con `...`.
#'
#' @return Un `data.frame` con las columnas `resourceType`, `id` y una por
#'   cada elemento de primer nivel (salvo `text`, la narrativa HTML).
#' @export
#' @examples
#' fhir_tabla(list(
#'   list(resourceType = "Patient", id = "p1", gender = "female",
#'        name = list(list(family = "Paredes Cevallos", given = list("Ana")))),
#'   list(resourceType = "Patient", id = "p2", birthDate = "2001-11-30")
#' ))
fhir_tabla <- function(recursos, tipo = NULL, max_caracteres = 200L) {
  recursos <- fhir_recursos(recursos)
  if (!is.numeric(max_caracteres) || length(max_caracteres) != 1L ||
      is.na(max_caracteres) || max_caracteres < 4) {
    cli::cli_abort("{.arg max_caracteres} debe ser un número mayor que 3.",
                   class = "fhirviews_error")
  }
  usar <- rep(TRUE, length(recursos))
  if (!is.null(tipo)) {
    tipos <- vapply(recursos, function(r) {
      t <- r[["resourceType"]]
      if (is.character(t) && length(t) == 1L) t else NA_character_
    }, character(1))
    usar <- !is.na(tipos) & tipos == tipo
  }
  if (!any(usar)) {
    return(data.frame(resourceType = character(), id = character(),
                      stringsAsFactors = FALSE))
  }
  # Las celdas se arman en el motor de JavaScript, que ya tiene los recursos
  # como JSON: convertir cada celda con jsonlite::toJSON() es muy lento con
  # decenas de miles de recursos
  m <- motor_actual()
  inicio <- m$tamano()
  on.exit(m$liberar(inicio), add = TRUE)
  ids <- m$cargar(recursos)[usar]
  res <- m$tabla(ids, max_caracteres)
  cols <- stats::setNames(res$columnas, res$campos)
  structure(cols, row.names = .set_row_names(length(ids)),
            class = "data.frame")
}
