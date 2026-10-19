#' Leer un ViewDefinition
#'
#' Lee un `ViewDefinition` de SQL on FHIR desde texto JSON, un archivo o una
#' lista de R y lo valida con [vista_validar()].
#'
#' @param x Texto JSON, ruta a un archivo `.json` o lista de R con el
#'   `ViewDefinition`.
#' @param validar Si es `TRUE` (por defecto), comprueba que la vista sea
#'   válida.
#'
#' @return Una lista de clase `fhir_vista`.
#' @seealso [vista_crear()] para armar vistas sencillas desde R y
#'   [vista_ejecutar()] para aplicarlas.
#' @export
#' @examples
#' vista <- vista_leer('{
#'   "resourceType": "ViewDefinition",
#'   "name": "pacientes",
#'   "resource": "Patient",
#'   "select": [{"column": [
#'     {"name": "id", "path": "getResourceKey()"},
#'     {"name": "sexo", "path": "gender"}
#'   ]}]
#' }')
#' vista
vista_leer <- function(x, validar = TRUE) {
  if (inherits(x, "fhir_vista")) {
    v <- x
  } else if (is.character(x) && length(x) == 1L) {
    if (!grepl("^\\s*[[{]", x) && file.exists(x)) {
      x <- paste(readLines(x, encoding = "UTF-8", warn = FALSE),
                 collapse = "\n")
    }
    v <- parsear_json(x)
  } else if (is.list(x)) {
    v <- x
  } else {
    cli::cli_abort(
      "{.arg x} debe ser texto JSON, la ruta a un archivo o una lista.",
      class = "fhirviews_error"
    )
  }
  v <- structure(unclass(v), class = "fhir_vista")
  if (validar) {
    vista_validar(v)
  }
  v
}

#' Crear un ViewDefinition sencillo
#'
#' Arma un `ViewDefinition` con una columna por expresión FHIRPath, sin
#' escribir JSON. Para vistas con varios niveles (`select` anidados,
#' `unionAll`, `repeat`) escribe el JSON o la lista completa y léela con
#' [vista_leer()].
#'
#' @param recurso Tipo de recurso FHIR, por ejemplo `"Patient"`.
#' @param columnas Vector de caracteres con nombre: el nombre es el de la
#'   columna y el valor, la expresión FHIRPath.
#' @param por_cada Expresión FHIRPath opcional (`forEach`): se genera una fila
#'   por cada elemento que devuelve, y las columnas se evalúan sobre él.
#' @param incluir_vacios Con `por_cada`, si es `TRUE` usa `forEachOrNull`: los
#'   recursos sin elementos dan una fila con `NA` en vez de no aparecer.
#' @param columnas_recurso Vector de caracteres con nombre, como `columnas`,
#'   con columnas que se evalúan sobre el recurso (no sobre cada elemento de
#'   `por_cada`). Por defecto, la clave del recurso en la columna `id`.
#' @param where Vector de caracteres con condiciones FHIRPath; solo se
#'   incluyen los recursos que las cumplen todas.
#' @param constantes Lista con nombre de constantes, que las expresiones usan
#'   como `%nombre`.
#' @param nombre Nombre de la vista (opcional).
#'
#' @return Una lista de clase `fhir_vista`.
#' @export
#' @examples
#' vista_crear("Patient", c(sexo = "gender", nacimiento = "birthDate"))
#'
#' # Una fila por cada nombre del paciente
#' vista_crear("Patient", c(apellido = "family", nombres = "given.join(' ')"),
#'             por_cada = "name")
#'
#' # Observaciones de presi\u00f3n arterial de un paciente
#' vista_crear(
#'   "Observation",
#'   c(paciente = "subject.getReferenceKey(Patient)",
#'     valor = "value.ofType(Quantity).value"),
#'   where = "code.coding.where(code = %codigo_pa).exists()",
#'   constantes = list(codigo_pa = "85354-9")
#' )
vista_crear <- function(recurso, columnas, por_cada = NULL,
                        incluir_vacios = FALSE,
                        columnas_recurso = c(id = "getResourceKey()"),
                        where = NULL, constantes = NULL, nombre = NULL) {
  texto_simple(recurso, "recurso")
  columnas <- columnas_nombradas(columnas, "columnas")
  v <- list(resourceType = "ViewDefinition")
  if (!is.null(nombre)) v$name <- texto_simple(nombre, "nombre")
  v$status <- "active"
  v$resource <- recurso
  if (length(constantes) > 0L) {
    v$constant <- constantes_desde_r(constantes)
  }
  seleccion <- list()
  if (is.null(por_cada)) {
    if (length(columnas_recurso) > 0L) {
      columnas <- c(columnas_nombradas(columnas_recurso, "columnas_recurso"),
                    columnas)
    }
    seleccion <- list(list(column = columnas_a_lista(columnas)))
  } else {
    texto_simple(por_cada, "por_cada")
    if (length(columnas_recurso) > 0L) {
      seleccion <- list(list(column = columnas_a_lista(
        columnas_nombradas(columnas_recurso, "columnas_recurso"))))
    }
    iteracion <- list(column = columnas_a_lista(columnas))
    iteracion <- c(stats::setNames(
      list(por_cada), if (incluir_vacios) "forEachOrNull" else "forEach"
    ), iteracion)
    seleccion <- c(seleccion, list(iteracion))
  }
  v$select <- seleccion
  if (length(where) > 0L) {
    if (!is.character(where)) {
      cli::cli_abort("{.arg where} debe ser un vector de caracteres.",
                     class = "fhirviews_error")
    }
    v$where <- lapply(unname(where), function(w) list(path = w))
  }
  vista_leer(v)
}

#' Convertir un ViewDefinition en JSON
#'
#' @param vista Un `ViewDefinition` en cualquier forma que acepte
#'   [vista_leer()].
#' @param bonito Si es `TRUE` (por defecto), con sangría.
#'
#' @return Texto JSON de clase `json`.
#' @export
#' @examples
#' vista_json(vista_crear("Patient", c(sexo = "gender")))
vista_json <- function(vista, bonito = TRUE) {
  vista <- vista_leer(vista, validar = FALSE)
  jsonlite::toJSON(unclass(vista), auto_unbox = TRUE, pretty = bonito,
                   null = "null", digits = NA)
}

#' @export
print.fhir_vista <- function(x, ...) {
  nombre <- x$name %||% x$title %||% x$id
  cat("<ViewDefinition>", if (!is.null(nombre)) nombre, "\n")
  cat("  Recurso: ", x$resource %||% "(sin definir)", "\n", sep = "")
  cols <- tryCatch(columnas_vista(x), error = function(e) character())
  cat("  Columnas (", length(cols), "): ",
      paste(cols, collapse = ", "), "\n", sep = "")
  if (length(x$where) > 0L) {
    cat("  Condiciones: ",
        paste(vapply(x$where, function(w) as.character(w$path %||% ""),
                     character(1)), collapse = "; "), "\n", sep = "")
  }
  invisible(x)
}

# --- Ayudas ------------------------------------------------------------------

`%||%` <- function(a, b) if (is.null(a)) b else a

texto_simple <- function(x, arg) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x)) {
    cli::cli_abort("{.arg {arg}} debe ser un texto no vac\u00edo.",
                   class = "fhirviews_error", call = NULL)
  }
  x
}

columnas_nombradas <- function(x, arg) {
  if (is.list(x)) x <- unlist(x)
  if (!is.character(x) || length(x) == 0L || is.null(names(x)) ||
      any(!nzchar(names(x)))) {
    cli::cli_abort(c(
      "{.arg {arg}} debe ser un vector de caracteres con nombre.",
      "i" = "Por ejemplo: {.code c(sexo = \"gender\")}."
    ), class = "fhirviews_error", call = NULL)
  }
  x
}

columnas_a_lista <- function(x) {
  unname(Map(function(nombre, ruta) list(name = nombre, path = ruta),
             names(x), unname(x)))
}

constantes_desde_r <- function(constantes) {
  if (is.null(names(constantes)) || any(!nzchar(names(constantes)))) {
    cli::cli_abort("{.arg constantes} debe ser una lista con nombre.",
                   class = "fhirviews_error", call = NULL)
  }
  unname(Map(function(nombre, valor) {
    if (length(valor) != 1L || is.na(valor)) {
      cli::cli_abort("La constante {.val {nombre}} debe tener un solo valor.",
                     class = "fhirviews_error", call = NULL)
    }
    campo <- if (inherits(valor, "Date")) {
      valor <- format(valor, "%Y-%m-%d")
      "valueDate"
    } else if (inherits(valor, "POSIXt")) {
      valor <- format(valor, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
      "valueDateTime"
    } else if (is.logical(valor)) {
      "valueBoolean"
    } else if (is.integer(valor)) {
      "valueInteger"
    } else if (is.numeric(valor)) {
      "valueDecimal"
    } else {
      valor <- as.character(valor)
      "valueString"
    }
    stats::setNames(list(nombre, valor), c("name", campo))
  }, names(constantes), constantes))
}
