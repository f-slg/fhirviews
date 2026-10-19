#' Ejecutar un ViewDefinition
#'
#' Aplica un `ViewDefinition` de [SQL on FHIR](https://sql-on-fhir.org/) a
#' un conjunto de recursos y devuelve la tabla resultante.
#'
#' Se admiten todos los elementos de la especificación: `select` anidados,
#' `column` (con `collection` y `type`), `forEach`, `forEachOrNull`,
#' `repeat`, `unionAll`, `where`, `constant` y la variable `%rowIndex`, además
#' de las funciones `getResourceKey()` y `getReferenceKey()`.
#'
#' El motor evalúa cada expresión sobre todos los recursos a la vez (una
#' llamada a FHIRPath por expresión y nivel), así que el tiempo crece poco con
#' el número de recursos.
#'
#' @param recursos Recursos FHIR en cualquier forma que acepte
#'   [fhir_recursos()]. Solo se usan los del tipo indicado en `resource`.
#' @param vista Un `ViewDefinition` en cualquier forma que acepte
#'   [vista_leer()].
#' @param validar Si es `TRUE` (por defecto), valida la vista antes de
#'   ejecutarla con [vista_validar()].
#'
#' @return Un `data.frame` con una columna por cada `column` de la vista, en
#'   el orden que define la especificación. Los tipos de R siguen el `type`
#'   de cada columna cuando se indica (`boolean` a lógico; `integer`,
#'   `positiveInt` y `unsignedInt` a entero; `decimal` a numérico; el resto a
#'   texto) y, si no, el de los valores. Las fechas quedan como texto ISO 8601
#'   porque FHIR admite fechas parciales (`"2024"`, `"2024-05"`). Las columnas
#'   con `collection: true` son listas.
#' @seealso [vista_crear()] y [vista_leer()] para definir la vista y
#'   [vista_fhirpath()] para probar expresiones.
#' @export
#' @examples
#' pacientes <- list(
#'   list(resourceType = "Patient", id = "p1", gender = "female",
#'        birthDate = "1985-03-12",
#'        name = list(list(use = "official", family = "Paredes Cevallos",
#'                         given = list("Ana", "Luc\u00eda"))),
#'        address = list(list(city = "Loja", district = "Loja"))),
#'   list(resourceType = "Patient", id = "p2", gender = "male",
#'        birthDate = "2001-11-30",
#'        name = list(list(family = "Salazar Moreno", given = list("Jorge"))))
#' )
#'
#' vista <- vista_crear(
#'   "Patient",
#'   c(sexo = "gender", nacimiento = "birthDate",
#'     apellido = "name.first().family", ciudad = "address.first().city")
#' )
#' vista_ejecutar(pacientes, vista)
#'
#' # Una fila por cada nombre, desde JSON
#' vista_ejecutar(pacientes, '{
#'   "resource": "Patient",
#'   "select": [
#'     {"column": [{"name": "id", "path": "getResourceKey()"}]},
#'     {"forEach": "name", "column": [
#'       {"name": "orden", "path": "%rowIndex"},
#'       {"name": "apellido", "path": "family"},
#'       {"name": "nombres", "path": "given", "collection": true}
#'     ]}
#'   ]
#' }')
vista_ejecutar <- function(recursos, vista, validar = TRUE) {
  vista <- vista_leer(vista, validar = validar)
  recursos <- fhir_recursos(recursos)
  tipos <- vapply(recursos, function(r) {
    t <- r[["resourceType"]]
    if (is.character(t) && length(t) == 1L) t else NA_character_
  }, character(1))
  usar <- !is.na(tipos) & tipos == vista$resource

  m <- motor_actual()
  inicio <- m$tamano()
  on.exit(m$liberar(inicio), add = TRUE)
  entorno <- new.env(parent = emptyenv())
  entorno$m <- m
  entorno$constantes <- constantes_vista(vista$constant)

  ids <- integer()
  if (any(usar)) {
    # Si todos son del tipo de la vista se cargan tal cual (y se aprovecha
    # el texto JSON original, si lo hay)
    ids <- if (all(usar)) m$cargar(recursos) else m$cargar(recursos[usar])
  }
  ctx <- list(nodo = ids, fila = rep(0L, length(ids)))

  for (w in vista$where) {
    res <- evaluar_ctx(ctx, w$path, entorno)
    cumple <- vapply(res, function(x) {
      if (length(x) == 0L) {
        return(FALSE)
      }
      if (length(x) > 1L || !is.logical(x[[1]])) {
        cli::cli_abort(c(
          "La condici\u00f3n {.code {w$path}} debe devolver verdadero o falso.",
          "x" = "Devolvi\u00f3 {.code {format_valor(x)}}."
        ), class = c("fhirviews_error_vista", "fhirviews_error"), call = NULL)
      }
      isTRUE(x[[1]])
    }, logical(1))
    ctx <- subconjunto_ctx(ctx, cumple)
  }

  filas <- ejecutar_partes(list(select = vista$select), ctx, entorno)
  armar_tabla(filas, vista)
}

# --- Evaluación por lotes ----------------------------------------------------
#
# Un contexto (ctx) es un lote de nodos sobre los que se evalúa una parte de
# la vista: `nodo` (índices en el almacén del motor) y `fila` (el valor de
# %rowIndex). El resultado de evaluar una parte es una lista de filas:
# `origen` (posición en el lote de la que sale cada fila) y `cols` (lista con
# nombre; cada columna es una lista con un valor por fila).

evaluar_ctx <- function(ctx, expresion, entorno, modo = "valores") {
  if (length(ctx$nodo) == 0L) {
    return(list())
  }
  por_nodo <- NULL
  if (grepl("%rowIndex", expresion, fixed = TRUE)) {
    por_nodo <- list(rowIndex = ctx$fila)
  }
  entorno$m$evaluar(ctx$nodo, expresion, entorno$constantes, por_nodo, modo)
}

subconjunto_ctx <- function(ctx, i) {
  list(nodo = ctx$nodo[i], fila = ctx$fila[i])
}

# Nodo vacío ({}) para las filas de forEachOrNull sin elementos
nodo_nulo <- function(entorno) {
  if (is.null(entorno$nulo)) {
    entorno$nulo <- entorno$m$cargar(list(structure(list(),
                                                    names = character())))
  }
  entorno$nulo
}

ejecutar_select <- function(s, ctx, entorno) {
  if (!is.null(s$forEach) || !is.null(s$forEachOrNull) ||
      !is.null(s[["repeat"]])) {
    exp <- expandir(s, ctx, entorno)
    filas <- ejecutar_partes(s, exp$ctx, entorno)
    filas$origen <- exp$padre[filas$origen]
    return(filas)
  }
  ejecutar_partes(s, ctx, entorno)
}

# Nodos hijos de cada nodo del lote según forEach, forEachOrNull o repeat
expandir <- function(s, ctx, entorno) {
  if (!is.null(s[["repeat"]])) {
    hijos <- descendientes(ctx, unlist(s[["repeat"]]), entorno)
  } else {
    expresion <- s$forEach %||% s$forEachOrNull
    hijos <- lapply(evaluar_ctx(ctx, expresion, entorno, modo = "nodos"),
                    as.integer)
    if (!is.null(s$forEachOrNull)) {
      vacios <- lengths(hijos) == 0L
      if (any(vacios)) {
        hijos[vacios] <- list(nodo_nulo(entorno))
      }
    }
  }
  largos <- lengths(hijos)
  list(
    ctx = list(nodo = as.integer(unlist(hijos)),
               fila = sequence(largos) - 1L),
    padre = rep(seq_along(hijos), largos)
  )
}

# Recorrido en profundidad (preorden) por las rutas de repeat
descendientes <- function(ctx, rutas, entorno) {
  if (length(ctx$nodo) == 0L) {
    return(list())
  }
  por_ruta <- lapply(rutas, function(r) {
    lapply(evaluar_ctx(ctx, r, entorno, modo = "nodos"), as.integer)
  })
  todos <- unlist(por_ruta)
  sub <- descendientes(list(nodo = todos, fila = rep(0L, length(todos))),
                       rutas, entorno)
  lapply(seq_along(ctx$nodo), function(i) {
    unlist(lapply(por_ruta, function(h) {
      unlist(lapply(h[[i]], function(k) c(k, sub[[match(k, todos)]])))
    }))
  })
}

ejecutar_partes <- function(s, ctx, entorno) {
  partes <- list()
  if (!is.null(s$column)) {
    partes <- c(partes, list(ejecutar_columnas(s$column, ctx, entorno)))
  }
  for (sub in s$select) {
    partes <- c(partes, list(ejecutar_select(sub, ctx, entorno)))
  }
  if (!is.null(s$unionAll)) {
    partes <- c(partes, list(ejecutar_union(s$unionAll, ctx, entorno)))
  }
  producto_filas(partes, length(ctx$nodo))
}

ejecutar_columnas <- function(columnas, ctx, entorno) {
  n <- length(ctx$nodo)
  cols <- list()
  for (cl in columnas) {
    res <- evaluar_ctx(ctx, cl$path, entorno)
    if (isTRUE(cl$collection)) {
      valores <- res
    } else {
      varios <- which(lengths(res) > 1L)
      if (length(varios) > 0L) {
        cli::cli_abort(c(
          "La columna {.field {cl$name}} devolvi\u00f3 varios valores para una fila.",
          "x" = "{.code {cl$path}} dio {.code {format_valor(res[[varios[1]]])}}.",
          "i" = paste("Usa {.code \"collection\": true} para guardar todos",
                      "los valores, o una expresi\u00f3n que devuelva uno solo",
                      "(por ejemplo con {.code first()}).")
        ), class = c("fhirviews_error_vista", "fhirviews_error"), call = NULL)
      }
      valores <- lapply(res, function(x) if (length(x) == 0L) NULL else x[[1]])
    }
    cols[cl$name] <- list(valores)
  }
  list(origen = seq_len(n), cols = cols)
}

ejecutar_union <- function(ramas, ctx, entorno) {
  res <- lapply(ramas, ejecutar_select, ctx = ctx, entorno = entorno)
  origen <- unlist(lapply(res, `[[`, "origen"))
  orden <- order(origen, method = "radix")
  nombres <- names(res[[1]]$cols)
  cols <- lapply(nombres, function(nm) {
    unlist(lapply(res, function(r) r$cols[[nm]]), recursive = FALSE)[orden]
  })
  list(origen = as.integer(origen[orden]),
       cols = stats::setNames(cols, nombres))
}

# Producto de las filas de varias partes, dentro de cada nodo de origen
producto_filas <- function(partes, n) {
  origen <- seq_len(n)
  cols <- list()
  for (p in partes) {
    orden <- order(p$origen, method = "radix")
    por_origen <- tabulate(p$origen, nbins = n)
    desde <- cumsum(c(0L, por_origen))[seq_len(n)]
    veces <- por_origen[origen]
    i_acc <- rep(seq_along(origen), times = veces)
    i_parte <- orden[sequence(veces, from = desde[origen] + 1L)]
    cols <- c(lapply(cols, `[`, i_acc), lapply(p$cols, `[`, i_parte))
    origen <- origen[i_acc]
  }
  list(origen = origen, cols = cols)
}

# --- Constantes y tabla final ------------------------------------------------

constantes_vista <- function(constantes) {
  if (length(constantes) == 0L) {
    return(list())
  }
  nombres <- vapply(constantes, function(k) k$name, character(1))
  valores <- lapply(constantes, function(k) {
    campo <- intersect(names(k), tipos_constante)[1]
    valor <- k[[campo]]
    switch(campo,
      valueDate = list(literal = paste0("@", valor)),
      valueDateTime = ,
      valueInstant = list(literal = paste0(
        "@", valor, if (!grepl("T", valor, fixed = TRUE)) "T"
      )),
      valueTime = list(literal = paste0("@T", valor)),
      valor
    )
  })
  stats::setNames(valores, nombres)
}

tipos_logicos <- "boolean"
tipos_enteros <- c("integer", "positiveInt", "unsignedInt")
tipos_decimales <- "decimal"

armar_tabla <- function(filas, vista) {
  defs <- definiciones_columnas(vista)
  nombres <- names(filas$cols)
  cols <- lapply(nombres, function(nm) {
    convertir_columna(filas$cols[[nm]], defs[[nm]])
  })
  names(cols) <- nombres
  structure(cols, row.names = .set_row_names(length(filas$origen)),
            class = "data.frame")
}

definiciones_columnas <- function(vista) {
  defs <- list()
  recorrer <- function(s) {
    for (cl in s$column) defs[[cl$name]] <<- cl
    for (sub in s$select) recorrer(sub)
    for (sub in s$unionAll) recorrer(sub)
  }
  for (s in vista$select) recorrer(s)
  defs
}

convertir_columna <- function(valores, def) {
  if (isTRUE(def$collection)) {
    return(lapply(valores, function(x) {
      if (length(x) == 0L) return(vector_tipo(def$type))
      if (all(vapply(x, function(e) is.atomic(e) && length(e) == 1L,
                     logical(1)))) unlist(x) else x
    }))
  }
  complejo <- vapply(valores, function(x) !is.null(x) && !is.atomic(x),
                     logical(1))
  if (any(complejo)) {
    return(valores)
  }
  vec <- unlist(lapply(valores, function(x) if (is.null(x)) NA else x))
  if (is.null(vec)) vec <- logical()
  tipo <- def$type
  if (is.null(tipo)) {
    return(vec)
  }
  if (tipo %in% tipos_logicos) {
    as.logical(vec)
  } else if (tipo %in% tipos_enteros) {
    as.integer(vec)
  } else if (tipo %in% tipos_decimales) {
    as.numeric(vec)
  } else if (is.logical(vec) && all(is.na(vec))) {
    as.character(vec)
  } else {
    vec
  }
}

vector_tipo <- function(tipo) {
  if (is.null(tipo)) return(logical())
  if (tipo %in% tipos_logicos) return(logical())
  if (tipo %in% tipos_enteros) return(integer())
  if (tipo %in% tipos_decimales) return(numeric())
  character()
}

format_valor <- function(x) {
  texto <- as.character(jsonlite::toJSON(x, auto_unbox = TRUE))
  if (nchar(texto) > 80L) paste0(substr(texto, 1L, 77L), "...") else texto
}
