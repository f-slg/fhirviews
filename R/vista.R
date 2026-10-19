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
#'   texto); si algún valor no es compatible (por ejemplo 1.7 en una columna
#'   `integer`) se avisa y se conserva sin convertir. Sin `type`, el tipo sale
#'   de los valores; si la columna no tiene ninguno, se deduce del modelo de
#'   FHIR R4 (por ejemplo `birthDate` es texto y `active`, lógico), para que
#'   la misma vista dé siempre los mismos tipos. Las fechas quedan como texto ISO 8601
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
    # Con el texto JSON original se cargan todos (JSON.parse es rápido) y se
    # filtran los índices: subdividir la lista descartaría ese texto y
    # obligaría a volver a convertir los recursos con jsonlite.
    if (all(usar) || !is.null(attr(recursos, "fuente"))) {
      ids <- m$cargar(recursos)[usar]
    } else {
      ids <- m$cargar(recursos[usar])
    }
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
  armar_tabla(filas, vista, m)
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

armar_tabla <- function(filas, vista, motor) {
  defs <- definiciones_columnas(vista)
  nombres <- names(filas$cols)
  inferidos <- NULL
  cols <- lapply(nombres, function(nm) {
    def <- defs[[nm]]
    valores <- filas$cols[[nm]]
    # Sin `type` y sin ningún valor, el tipo se deduce del modelo FHIR para
    # que la columna no dependa de los datos (vacía sería lógica)
    if (is.null(def$type) && !isTRUE(def$collection) &&
        all(vapply(valores, is.null, logical(1)))) {
      if (is.null(inferidos)) inferidos <<- inferir_tipos(vista, motor)
      def$type <- inferidos[[nm]]
    }
    convertir_columna(valores, def, nm)
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

# Tipo FHIR de cada columna sin `type`, deducido con el modelo R4 siguiendo
# los forEach/repeat de la vista (NULL si no se puede deducir o si no es un
# tipo primitivo)
inferir_tipos <- function(vista, motor) {
  tipos <- list()
  visitar <- function(s, ctx) {
    iteracion <- s$forEach %||% s$forEachOrNull %||% s[["repeat"]][[1]]
    if (!is.null(ctx) && !is.null(iteracion)) {
      ctx <- motor$tipo(ctx, iteracion)
    }
    for (cl in s$column) {
      if (!is.null(ctx) && is.null(cl$type) && !isTRUE(cl$collection)) {
        t <- motor$tipo(ctx, cl$path)$tipo
        if (!is.null(t) && grepl("^[a-z]", t)) tipos[[cl$name]] <<- t
      }
    }
    for (sub in s$select) visitar(sub, ctx)
    for (sub in s$unionAll) visitar(sub, ctx)
  }
  for (s in vista$select) {
    visitar(s, list(tipo = vista$resource, ruta = vista$resource))
  }
  tipos
}

convertir_columna <- function(valores, def, nombre = def$name) {
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
  if (is.null(def$type)) {
    return(vec)
  }
  convertir_tipo(vec, def$type, nombre)
}

# Convierte al tipo de R del `type` FHIR. Si algún valor no es compatible
# (por ejemplo 1.7 en una columna integer) avisa y conserva los valores en
# lugar de truncarlos o convertirlos en NA.
convertir_tipo <- function(vec, tipo, nombre) {
  avisar <- function(detalle) {
    cli::cli_warn(c(
      "La columna {.field {nombre}} tiene {.code type: {tipo}}, pero {detalle}.",
      "i" = "Se conservan los valores sin convertir."
    ), class = "fhirviews_aviso_tipo", call = NULL)
  }
  presentes <- !is.na(vec)
  if (tipo %in% tipos_logicos) {
    if (is.logical(vec)) return(vec)
    nuevo <- as.logical(vec)
    if (any(presentes & is.na(nuevo))) {
      avisar("hay valores que no son l\u00f3gicos")
      return(vec)
    }
    return(nuevo)
  }
  if (tipo %in% c(tipos_enteros, tipos_decimales)) {
    num <- suppressWarnings(as.numeric(vec))
    if (any(presentes & is.na(num))) {
      avisar("hay valores que no son num\u00e9ricos")
      return(vec)
    }
    if (tipo %in% tipos_decimales) return(num)
    no_enteros <- presentes & (num != round(num) | abs(num) > .Machine$integer.max)
    if (any(no_enteros)) {
      avisar(paste0("hay valores que no son enteros (por ejemplo ",
                    num[no_enteros][1], ")"))
      return(num)
    }
    return(as.integer(num))
  }
  # Tipos de texto (string, code, date, dateTime, uri...)
  if (is.logical(vec) && all(!presentes)) as.character(vec) else vec
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
