#' Catálogo de vistas listas para usar
#'
#' Lista los `ViewDefinition` que trae el paquete para las tablas más
#' comunes en vigilancia y salud pública: pacientes con su dirección de
#' residencia, signos vitales, diagnósticos, enfermedades de notificación
#' obligatoria, inmunizaciones, encuentros y prescripciones de
#' medicamentos. Todas usan `getResourceKey()` para la columna `id` y
#' `getReferenceKey()` para las claves de otros recursos (por ejemplo
#' `paciente`), de modo que las tablas se pueden unir entre sí.
#'
#' Las vistas son JSON estándar de SQL on FHIR, guardados en la carpeta
#' `vistas` del paquete (`system.file("vistas", package = "fhirviews")`), y
#' dan los mismos resultados con [vista_ejecutar()] y con
#' [vista_ejecutar_duckdb()].
#'
#' @return Un `data.frame` con una fila por vista y las columnas `nombre`
#'   (para [vista_plantilla()]), `recurso` (tipo de recurso FHIR), `titulo`
#'   y `descripcion`.
#' @seealso [vista_plantilla()] para obtener una vista del catálogo.
#' @export
#' @examples
#' vista_catalogo()[, c("nombre", "recurso", "titulo")]
vista_catalogo <- function() {
  archivos <- archivos_catalogo()
  vistas <- lapply(archivos, vista_leer, validar = FALSE)
  campo <- function(nombre) {
    vapply(vistas, function(v) v[[nombre]] %||% NA_character_, character(1))
  }
  data.frame(
    nombre = sub("\\.json$", "", basename(archivos)),
    recurso = campo("resource"),
    titulo = campo("title"),
    descripcion = campo("description"),
    stringsAsFactors = FALSE
  )
}

#' Obtener una vista del catálogo
#'
#' Devuelve uno de los `ViewDefinition` de [vista_catalogo()] listo para
#' [vista_ejecutar()], [vista_ejecutar_duckdb()], [vista_duckdb()] o
#' [vista_sql()]. Sirve también como punto de partida para una vista
#' propia: [vista_json()] muestra su JSON para copiarlo y modificarlo.
#'
#' Algunas vistas tienen constantes que se pueden cambiar con
#' `constantes`. Por ejemplo, `notificacion_obligatoria` filtra los
#' diagnósticos con la constante `codigos`, una lista de categorías CIE-10
#' (tres caracteres) separadas por comas, y `diagnosticos` usa las
#' constantes `sistema_cie10` y `sistema_snomed` con el URI de cada sistema
#' de codificación.
#'
#' @param nombre Nombre de la vista, uno de los de la columna `nombre` de
#'   [vista_catalogo()].
#' @param constantes Lista con nombre opcional para cambiar el valor de
#'   constantes de la vista, por ejemplo
#'   `list(codigos = "A90,A91,A92")`. Solo se pueden cambiar constantes que
#'   la vista ya tiene.
#'
#' @return Una lista de clase `fhir_vista` (ver [vista_leer()]).
#' @seealso [vista_catalogo()] para la lista de vistas.
#' @export
#' @examples
#' caso <- system.file("extdata", "caso_clinico.ndjson", package = "fhirviews")
#' vista_ejecutar(caso, vista_plantilla("signos_vitales"))
#'
#' # Solo los casos de dengue hemorrágico (A91)
#' dengue <- system.file("extdata", "dengue_2025.ndjson.gz",
#'                       package = "fhirviews")
#' notificacion <- vista_plantilla("notificacion_obligatoria",
#'                                 constantes = list(codigos = "A91"))
#' head(vista_ejecutar(dengue, notificacion))
vista_plantilla <- function(nombre, constantes = NULL) {
  texto_simple(nombre, "nombre")
  archivos <- archivos_catalogo()
  nombres <- sub("\\.json$", "", basename(archivos))
  if (!nombre %in% nombres) {
    cli::cli_abort(c(
      "No hay una vista llamada {.val {nombre}} en el cat\u00e1logo.",
      "i" = "Vistas disponibles: {.val {nombres}}."
    ), class = "fhirviews_error")
  }
  vista <- vista_leer(archivos[[match(nombre, nombres)]], validar = FALSE)
  if (length(constantes) > 0L) {
    nuevas <- constantes_desde_r(constantes)
    actuales <- vapply(vista$constant, function(k) k$name, character(1))
    desconocidas <- setdiff(names(constantes), actuales)
    if (length(desconocidas) > 0L) {
      cli::cli_abort(c(
        "La vista {.val {nombre}} no tiene la constante {.val {desconocidas}}.",
        "i" = if (length(actuales) > 0L) {
          "Constantes de la vista: {.val {actuales}}."
        } else {
          "La vista no tiene constantes."
        }
      ), class = "fhirviews_error")
    }
    for (k in nuevas) {
      vista$constant[[match(k$name, actuales)]] <- k
    }
  }
  vista_leer(vista)
}

archivos_catalogo <- function() {
  carpeta <- system.file("vistas", package = "fhirviews")
  sort(list.files(carpeta, pattern = "\\.json$", full.names = TRUE))
}
