#' Evaluar una expresión FHIRPath
#'
#' Evalúa una expresión [FHIRPath](https://hl7.org/fhirpath/) sobre cada
#' recurso. Es útil para explorar los datos y probar las expresiones antes de
#' usarlas en las columnas de un `ViewDefinition`.
#'
#' Además de las funciones de FHIRPath, están disponibles las que define SQL
#' on FHIR: `getResourceKey()` y `getReferenceKey([tipo])`.
#'
#' @param recursos Recursos FHIR en cualquier forma que acepte
#'   [fhir_recursos()].
#' @param expresion Texto con la expresión FHIRPath.
#' @param variables Lista con nombre de variables para la expresión, que se
#'   usan como `%nombre`. Los objetos `Date` y `POSIXct` se pasan como fechas
#'   de FHIRPath.
#' @param simplificar Si es `TRUE` (por defecto) y cada recurso da como mucho
#'   un valor simple, devuelve un vector (con `NA` cuando no hay valor); si
#'   algún recurso da varios valores simples, una lista de vectores. Si es
#'   `FALSE`, o si el resultado incluye elementos complejos, devuelve la lista
#'   de resultados tal como los entrega FHIRPath, con un elemento por recurso.
#'
#' @return Un vector o una lista con un elemento por recurso.
#' @seealso [fhirviews_motor()] para saber qué motor y qué versión de
#'   fhirpath.js se usan.
#' @export
#' @examples
#' pacientes <- list(
#'   list(resourceType = "Patient", id = "p1", gender = "female",
#'        birthDate = "1985-03-12",
#'        name = list(list(family = "Paredes Cevallos",
#'                         given = list("Ana", "Luc\u00eda")))),
#'   list(resourceType = "Patient", id = "p2", gender = "male",
#'        birthDate = "2001-11-30",
#'        name = list(list(family = "Salazar Moreno", given = list("Jorge"))))
#' )
#' vista_fhirpath(pacientes, "getResourceKey()")
#' vista_fhirpath(pacientes, "name.given.join(' ')")
#' vista_fhirpath(pacientes, "birthDate < %corte",
#'                variables = list(corte = as.Date("2000-01-01")))
#' vista_fhirpath(pacientes, "name.given")
vista_fhirpath <- function(recursos, expresion, variables = list(),
                           simplificar = TRUE) {
  if (!is.character(expresion) || length(expresion) != 1L || is.na(expresion)) {
    cli::cli_abort("{.arg expresion} debe ser un texto.",
                   class = "fhirviews_error")
  }
  recursos <- fhir_recursos(recursos)
  m <- motor_actual()
  inicio <- m$tamano()
  on.exit(m$liberar(inicio), add = TRUE)
  ids <- m$cargar(recursos)
  res <- m$evaluar(ids, expresion, variables)
  if (simplificar) simplificar_valores(res) else res
}

simplificar_valores <- function(res) {
  if (length(res) == 0L) {
    return(logical())
  }
  escalares <- vapply(res, function(v) {
    all(vapply(v, function(e) is.atomic(e) && length(e) == 1L, logical(1)))
  }, logical(1))
  if (!all(escalares)) {
    return(res)
  }
  if (all(lengths(res) <= 1L)) {
    valores <- lapply(res, function(v) if (length(v) == 0L) NA else v[[1]])
    return(unlist(valores, use.names = FALSE))
  }
  lapply(res, function(v) unlist(v, use.names = FALSE))
}

#' Motor de FHIRPath y versión de fhirpath.js
#'
#' fhirviews evalúa FHIRPath con un *motor*. Por ahora el único es `"v8"`:
#' la biblioteca [fhirpath.js](https://github.com/HL7/fhirpath.js) ejecutada
#' en el paquete V8. La opción `fhirviews.motor` queda reservada para elegir
#' otros motores en el futuro.
#'
#' @return `fhirviews_motor()` devuelve una lista de clase `fhirviews_motor`
#'   con el motor (`motor`), la versión de fhirpath.js (`fhirpath_js`) y la
#'   del motor de JavaScript (`v8`), que se imprime como un resumen.
#'   `fhirviews_version_fhirpath()` devuelve la versión de fhirpath.js
#'   incluida en el paquete, sin iniciar V8.
#' @export
#' @examples
#' fhirviews_version_fhirpath()
#' fhirviews_motor()
fhirviews_motor <- function() {
  m <- motor_actual()
  structure(list(
    motor = m$nombre,
    fhirpath_js = m$version(),
    v8 = V8::engine_info()$version
  ), class = "fhirviews_motor")
}

#' @export
print.fhirviews_motor <- function(x, ...) {
  cat("Motor de FHIRPath: ", x$motor, "\n",
      "fhirpath.js:       ", x$fhirpath_js, "\n",
      "V8:                ", x$v8, "\n", sep = "")
  invisible(x)
}

#' @rdname fhirviews_motor
#' @export
fhirviews_version_fhirpath <- function() {
  readLines(ruta_js("fhirpath", "VERSION"), warn = FALSE)[1]
}
