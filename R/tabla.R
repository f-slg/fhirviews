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
  if (!is.null(tipo)) {
    tipos <- vapply(recursos, function(r) as.character(r$resourceType %||% NA),
                    character(1))
    recursos <- recursos[!is.na(tipos) & tipos == tipo]
  }
  campos <- unique(unlist(lapply(recursos, names)))
  campos <- c(intersect(c("resourceType", "id"), campos),
              setdiff(campos, c("resourceType", "id", "text")))
  if (length(recursos) == 0L) {
    return(data.frame(resourceType = character(), id = character(),
                      stringsAsFactors = FALSE))
  }
  cols <- lapply(campos, function(campo) {
    valores <- lapply(recursos, function(r) celda_tabla(r[[campo]],
                                                        max_caracteres))
    unlist(valores)
  })
  names(cols) <- campos
  structure(cols, row.names = .set_row_names(length(recursos)),
            class = "data.frame")
}

celda_tabla <- function(x, max_caracteres) {
  if (is.null(x)) {
    return(NA)
  }
  if (is.atomic(x) && length(x) == 1L) {
    return(x)
  }
  simples <- is.list(x) && is.null(names(x)) &&
    all(vapply(x, function(e) is.atomic(e) && length(e) == 1L, logical(1)))
  texto <- if (simples) {
    paste(unlist(x), collapse = "; ")
  } else {
    as.character(jsonlite::toJSON(x, auto_unbox = TRUE, digits = NA,
                                  null = "null"))
  }
  if (nchar(texto) > max_caracteres) {
    texto <- paste0(substr(texto, 1L, max_caracteres - 3L), "...")
  }
  texto
}
