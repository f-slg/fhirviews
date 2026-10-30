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
#' * `column`, `select` y `unionAll`, si aparecen, tienen al menos un
#'   elemento;
#' * cada constante tiene nombre y un solo valor (`valueString`,
#'   `valueInteger`, etc.), y su nombre no es una variable reservada de
#'   FHIRPath o del motor (`resource`, `rootResource`, `context`, `rowIndex`,
#'   `ucum`, `sct`, `loinc`...);
#' * todas las expresiones FHIRPath se pueden compilar.
#'
#' Además, con el modelo de FHIR R4 avisa (sin error) si `resource` no es un
#' tipo de recurso de R4 o si una ruta usa un elemento que no existe (por
#' ejemplo `name.familia` en lugar de `name.family`): FHIRPath no da error en
#' esos casos y la vista devolvería una tabla vacía o columnas sin valores.
#' Solo se revisan los pasos de navegación simples; los elementos de
#' elección (`value`), las extensiones y las expresiones con operadores no
#' generan avisos. Se pueden silenciar con
#' `suppressWarnings(..., classes = "fhirviews_aviso_vista")`.
#'
#' @param vista Un `ViewDefinition` en cualquier forma que acepte
#'   [vista_leer()].
#'
#' @return La vista, de forma invisible, si es válida. Si no, un error de
#'   clase `fhirviews_error_vista` con la lista de problemas encontrados. Los
#'   avisos del modelo R4 son de clase `fhirviews_aviso_vista`.
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
  avisos <- avisos_vista(vista)
  if (length(avisos) > 0L) {
    mostrar <- utils::head(avisos, 10L)
    cli::cli_warn(c(
      "El ViewDefinition usa elementos que no existen en FHIR R4.",
      stats::setNames(mostrar, rep("!", length(mostrar))),
      if (length(avisos) > 10L)
        c("i" = "... y {length(avisos) - 10L} aviso{?s} m\u00e1s."),
      "i" = "Esas rutas no devuelven valores: revisa la ortograf\u00eda."
    ), class = "fhirviews_aviso_vista", avisos = avisos, call = NULL)
  }
  invisible(vista)
}

# Recursos y elementos que no existen en el modelo R4 (avisos, no errores)
avisos_vista <- function(v) {
  m <- motor_actual()
  avisos <- character()
  if (!m$es_recurso(v$resource)) {
    return(paste0("{.val ", v$resource, "} no es un tipo de recurso de ",
                  "FHIR R4."))
  }
  revisar <- function(ctx, expresion, donde) {
    if (is.null(ctx) || !es_texto(expresion)) {
      return(invisible())
    }
    d <- m$desconocido(ctx, expresion)
    if (!is.null(d)) {
      avisos <<- c(avisos, paste0(
        "{.field ", donde, "}: {.field ", escapar_cli(d$campo),
        "} no es un elemento de {.cls ", d$tipo, "} ({.code ",
        escapar_cli(expresion), "})."))
    }
  }
  visitar <- function(s, ctx, donde) {
    iteracion <- s$forEach %||% s$forEachOrNull
    campo <- if (!is.null(s$forEach)) "forEach" else "forEachOrNull"
    if (!is.null(s[["repeat"]])) {
      # Las rutas de repeat se aplican en cada nivel del recorrido, con
      # tipos distintos: no se revisan, ni lo que cuelga de ellas
      ctx <- NULL
    } else if (!is.null(iteracion)) {
      revisar(ctx, iteracion, paste0(donde, ".", campo))
      if (!is.null(ctx)) ctx <- m$tipo(ctx, iteracion)
    }
    for (j in seq_along(s$column)) {
      revisar(ctx, s$column[[j]]$path, paste0(donde, ".column[", j, "].path"))
    }
    for (j in seq_along(s$select)) {
      visitar(s$select[[j]], ctx, paste0(donde, ".select[", j, "]"))
    }
    for (j in seq_along(s$unionAll)) {
      visitar(s$unionAll[[j]], ctx, paste0(donde, ".unionAll[", j, "]"))
    }
  }
  raiz <- list(tipo = v$resource, ruta = v$resource)
  for (i in seq_along(v$where)) {
    revisar(raiz, v$where[[i]]$path, paste0("where[", i, "].path"))
  }
  for (i in seq_along(v$select)) {
    visitar(v$select[[i]], raiz, paste0("select[", i, "]"))
  }
  avisos
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
# Variables de entorno que define FHIRPath o el motor; una constante con estos
# nombres quedaría oculta
nombres_reservados <- c("resource", "rootResource", "context", "rowIndex",
                        "ucum", "sct", "loinc", "factory", "terminologies",
                        "questionnaire")

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
    } else if (k$name %in% nombres_reservados) {
      agregar("La constante {.val ", k$name, "} usa un nombre reservado de ",
              "FHIRPath o de SQL on FHIR ({.code %", k$name, "}); ",
              "elige otro nombre.")
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
    for (e in intersect(c("column", "select", "unionAll"), names(s))) {
      if (!is.list(s[[e]]) || length(s[[e]]) == 0L) {
        agregar("{.field ", donde, ".", e, "} debe ser una lista con al ",
                "menos un elemento.")
      }
    }
    if (length(s$column) == 0L && length(s$select) == 0L &&
        length(s$unionAll) == 0L) {
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
    if (length(s$unionAll) > 0L) {
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
