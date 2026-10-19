#' Validar un ViewDefinition
#'
#' Comprueba que un `ViewDefinition` cumpla la estructura de SQL on FHIR antes
#' de ejecutarlo:
#'
#' * tiene `resource` y al menos un `select`;
#' * cada `select` usa solo los elementos permitidos y como mucho uno de
#'   `forEach`, `forEachOrNull` y `repeat`;
#' * cada columna tiene `name` y `path`; los nombres son válidos en SQL
#'   (empiezan con una letra y solo usan letras, números y `_`) y no se
#'   repiten;
#' * los `select` de un `unionAll` producen las mismas columnas, en el mismo
#'   orden;
#' * cada constante tiene nombre y un solo valor (`valueString`,
#'   `valueInteger`, etc.);
#' * todas las expresiones FHIRPath se pueden compilar.
#'
#' @param vista Un `ViewDefinition` en cualquier forma que acepte
#'   [vista_leer()].
#'
#' @return La vista, de forma invisible, si es válida. Si no, un error de
#'   clase `fhirviews_error_vista` con la lista de problemas encontrados.
#' @export
#' @examples
#' vista_validar(vista_crear("Patient", c(sexo = "gender")))
#'
#' mala <- list(resource = "Patient",
#'              select = list(list(column = list(
#'                list(name = "1id", path = "id"),
#'                list(name = "sexo", path = "gender.(")))))
#' try(vista_validar(mala))
vista_validar <- function(vista) {
  if (!inherits(vista, "fhir_vista")) {
    vista <- vista_leer(vista, validar = FALSE)
  }
  problemas <- problemas_vista(vista)
  if (length(problemas) > 0L) {
    mostrar <- utils::head(problemas, 10L)
    cli::cli_abort(c(
      "El ViewDefinition no es v\u00e1lido.",
      stats::setNames(mostrar, rep("x", length(mostrar))),
      if (length(problemas) > 10L)
        c("i" = "... y {length(problemas) - 10L} problema{?s} m\u00e1s.")
    ), class = c("fhirviews_error_vista", "fhirviews_error"),
    problemas = problemas, call = NULL)
  }
  invisible(vista)
}

elementos_select <- c("column", "select", "unionAll", "forEach",
                      "forEachOrNull", "repeat", "extension", "id")
elementos_columna <- c("name", "path", "description", "collection", "type",
                       "tag", "extension", "id")
tipos_constante <- c(
  "valueBase64Binary", "valueBoolean", "valueCanonical", "valueCode",
  "valueDate", "valueDateTime", "valueDecimal", "valueId", "valueInstant",
  "valueInteger", "valueInteger64", "valueOid", "valueString",
  "valuePositiveInt", "valueTime", "valueUnsignedInt", "valueUri",
  "valueUrl", "valueUuid"
)
patron_nombre <- "^[A-Za-z][A-Za-z0-9_]*$"

problemas_vista <- function(v) {
  p <- character()
  agregar <- function(...) p <<- c(p, paste0(...))

  if (!is.list(v) || length(v) == 0L) {
    return("La vista est\u00e1 vac\u00eda.")
  }
  if (!es_texto(v$resource)) {
    agregar("Falta {.field resource}: el tipo de recurso de la vista.")
  }
  if (!is.null(v$resourceType) && !identical(v$resourceType, "ViewDefinition")) {
    agregar("{.field resourceType} debe ser {.val ViewDefinition}.")
  }

  expresiones <- character()
  ruta <- function(e, donde) {
    if (!es_texto(e)) {
      agregar("{.field ", donde, "} debe ser una expresi\u00f3n FHIRPath (texto).")
    } else {
      expresiones[donde] <<- e
    }
  }

  # Constantes
  nombres_const <- character()
  for (i in seq_along(v$constant)) {
    k <- v$constant[[i]]
    donde <- paste0("constant[", i, "]")
    if (!es_texto(k$name) || !grepl(patron_nombre, k$name)) {
      agregar("{.field ", donde, ".name} falta o no es un nombre v\u00e1lido.")
    } else {
      nombres_const <- c(nombres_const, k$name)
    }
    valores <- intersect(names(k), tipos_constante)
    if (length(valores) != 1L) {
      agregar("{.field ", donde, "} debe tener exactamente un valor ",
              "({.field valueString}, {.field valueInteger}, etc.).")
    }
  }
  if (anyDuplicated(nombres_const)) {
    agregar("Hay constantes con el mismo nombre: ",
            paste(unique(nombres_const[duplicated(nombres_const)]),
                  collapse = ", "), ".")
  }

  # Condiciones
  for (i in seq_along(v$where)) {
    ruta(v$where[[i]]$path, paste0("where[", i, "].path"))
  }

  # Selecciones (recursivo); devuelve los nombres de columnas en orden
  revisar_select <- function(s, donde) {
    if (!is.list(s) || (length(s) > 0L && is.null(names(s)))) {
      agregar("{.field ", donde, "} debe ser un objeto.")
      return(character())
    }
    extra <- setdiff(names(s), elementos_select)
    if (length(extra) > 0L) {
      agregar("{.field ", donde, "} tiene elementos no permitidos: ",
              paste(extra, collapse = ", "), ".")
    }
    iter <- intersect(names(s), c("forEach", "forEachOrNull", "repeat"))
    if (length(iter) > 1L) {
      agregar("{.field ", donde, "} solo puede tener uno de forEach, ",
              "forEachOrNull y repeat.")
    }
    if (!is.null(s$forEach)) ruta(s$forEach, paste0(donde, ".forEach"))
    if (!is.null(s$forEachOrNull)) {
      ruta(s$forEachOrNull, paste0(donde, ".forEachOrNull"))
    }
    if ("repeat" %in% names(s)) {
      if (!is.list(s[["repeat"]]) && !is.character(s[["repeat"]]) ||
          length(s[["repeat"]]) == 0L) {
        agregar("{.field ", donde, ".repeat} debe ser una lista de ",
                "expresiones FHIRPath.")
      }
      for (j in seq_along(s[["repeat"]])) {
        ruta(s[["repeat"]][[j]], paste0(donde, ".repeat[", j, "]"))
      }
    }
    if (is.null(s$column) && is.null(s$select) && is.null(s$unionAll)) {
      agregar("{.field ", donde, "} no tiene column, select ni unionAll.")
    }
    cols <- character()
    for (j in seq_along(s$column)) {
      cl <- s$column[[j]]
      dc <- paste0(donde, ".column[", j, "]")
      if (!is.list(cl)) {
        agregar("{.field ", dc, "} debe ser un objeto.")
        next
      }
      extra <- setdiff(names(cl), elementos_columna)
      if (length(extra) > 0L) {
        agregar("{.field ", dc, "} tiene elementos no permitidos: ",
                paste(extra, collapse = ", "), ".")
      }
      if (!es_texto(cl$name)) {
        agregar("{.field ", dc, ".name} es obligatorio.")
      } else {
        if (!grepl(patron_nombre, cl$name)) {
          agregar("El nombre de columna {.val ", cl$name, "} (", dc, ") no ",
                  "es v\u00e1lido: debe empezar con una letra y usar solo ",
                  "letras, n\u00fameros y _.")
        }
        cols <- c(cols, cl$name)
      }
      ruta(cl$path, paste0(dc, ".path"))
      if (!is.null(cl$collection) &&
          !(is.logical(cl$collection) && length(cl$collection) == 1L)) {
        agregar("{.field ", dc, ".collection} debe ser true o false.")
      }
      if (!is.null(cl$type) && !es_texto(cl$type)) {
        agregar("{.field ", dc, ".type} debe ser un texto.")
      }
    }
    for (j in seq_along(s$select)) {
      cols <- c(cols, revisar_select(s$select[[j]],
                                     paste0(donde, ".select[", j, "]")))
    }
    if (!is.null(s$unionAll)) {
      ramas <- lapply(seq_along(s$unionAll), function(j) {
        revisar_select(s$unionAll[[j]], paste0(donde, ".unionAll[", j, "]"))
      })
      if (length(ramas) > 0L) {
        for (j in seq_along(ramas)[-1]) {
          if (!identical(ramas[[j]], ramas[[1]])) {
            agregar("Las ramas de {.field ", donde, ".unionAll} no tienen ",
                    "las mismas columnas en el mismo orden: (",
                    paste(ramas[[1]], collapse = ", "), ") frente a (",
                    paste(ramas[[j]], collapse = ", "), ").")
          }
        }
        cols <- c(cols, ramas[[1]])
      }
    }
    cols
  }

  if (!is.list(v$select) || length(v$select) == 0L) {
    agregar("Falta {.field select}: la vista debe tener al menos una ",
            "selecci\u00f3n con columnas.")
    cols <- character()
  } else {
    cols <- unlist(lapply(seq_along(v$select), function(i) {
      revisar_select(v$select[[i]], paste0("select[", i, "]"))
    }))
  }
  if (anyDuplicated(cols)) {
    agregar("Hay columnas con el mismo nombre: ",
            paste(unique(cols[duplicated(cols)]), collapse = ", "), ".")
  }

  # Expresiones FHIRPath
  if (length(expresiones) > 0L) {
    m <- motor_actual()
    for (donde in names(expresiones)) {
      error <- tryCatch({
        m$validar(expresiones[[donde]])
        NULL
      }, fhirviews_error_fhirpath = function(e) e)
      if (!is.null(error)) {
        agregar("La expresi\u00f3n de {.field ", donde, "} no es v\u00e1lida: ",
                "{.code ", gsub("[{}]", "", expresiones[[donde]]), "}.")
      }
    }
  }
  # Escapar llaves de los textos que no son marcas de cli
  p
}

es_texto <- function(x) {
  is.character(x) && length(x) == 1L && !is.na(x) && nzchar(x)
}

# Nombres de las columnas de una vista, en orden
columnas_vista <- function(v) {
  cols_select <- function(s) {
    c(vapply(s$column, function(cl) as.character(cl$name %||% NA), character(1)),
      unlist(lapply(s$select, cols_select)),
      if (length(s$unionAll) > 0L) cols_select(s$unionAll[[1]]))
  }
  unlist(lapply(v$select, cols_select)) %||% character()
}
