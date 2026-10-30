# Motores de FHIRPath
#
# El motor de vistas no llama a fhirpath.js directamente: usa un "motor", una
# lista de funciones con esta interfaz:
#
#   cargar(recursos)                      -> enteros (un nodo por recurso)
#   evaluar(ids, expresion, variables, por_nodo, modo)
#                                         (por_nodo: lista con nombre de
#                                         vectores, un valor por nodo)
#                                         -> lista, un elemento por nodo:
#                                            valores (modo "valores") o
#                                            enteros de nodos (modo "nodos")
#   validar(expresion)                    -> TRUE o error
#   desconocido(contexto, expresion)      -> list(campo, tipo) con el primer
#                                            elemento que no existe en el
#                                            modelo, o NULL
#   es_recurso(tipo)                      -> TRUE si es un recurso de R4
#   tipo(contexto, expresion)             -> list(tipo, ruta) con el tipo FHIR
#                                            del resultado, o NULL si no se
#                                            puede deducir sin datos
#   tabla(ids, maximo)                    -> list(campos, columnas) para
#                                            fhir_tabla()
#   tamano()                              -> nodos guardados
#   liberar(desde)                        -> descarta los nodos desde `desde`
#   version()                             -> versión de la biblioteca
#
# Hoy existe el motor "v8" (fhirpath.js en V8). Un motor escrito en R solo
# tendría que implementar la misma interfaz y registrarse en motor_crear().

.fhirviews <- new.env(parent = emptyenv())

motores_disponibles <- function() {
  "v8"
}

# Devuelve el motor elegido con options(fhirviews.motor = ...), creándolo la
# primera vez.
motor_actual <- function() {
  nombre <- getOption("fhirviews.motor", "v8")
  if (!is.character(nombre) || length(nombre) != 1L ||
      !nombre %in% motores_disponibles()) {
    cli::cli_abort(c(
      "El motor de FHIRPath {.val {nombre}} no est\u00e1 disponible.",
      "i" = "Motores disponibles: {.val {motores_disponibles()}}."
    ), class = "fhirviews_error")
  }
  m <- .fhirviews$motores[[nombre]]
  if (is.null(m)) {
    m <- motor_crear(nombre)
    if (is.null(.fhirviews$motores)) .fhirviews$motores <- list()
    .fhirviews$motores[[nombre]] <- m
  }
  m
}

motor_crear <- function(nombre) {
  switch(nombre,
    v8 = motor_v8()
  )
}

# Lee el archivo en binario: fhirpath.min.js contiene bytes 0x1A (Ctrl-Z) en
# las tablas del analizador ANTLR, y en Windows la lectura en modo texto
# (como la de V8::source()) los toma como fin de archivo y corta el script.
cargar_js <- function(ct, ruta) {
  codigo <- rawToChar(readBin(ruta, "raw", file.size(ruta)))
  Encoding(codigo) <- "UTF-8"
  invisible(ct$eval(codigo))
}

ruta_js <- function(...) {
  system.file("js", ..., package = "fhirviews", mustWork = TRUE)
}

# --- Motor V8 ----------------------------------------------------------------

motor_v8 <- function() {
  ct <- V8::v8()
  ct$eval("var window = globalThis;")
  cargar_js(ct, ruta_js("fhirpath", "fhirpath.min.js"))
  cargar_js(ct, ruta_js("fhirpath", "fhirpath.r4.min.js"))
  cargar_js(ct, ruta_js("fhirviews.js"))

  llamar <- function(codigo, expresion = NULL) {
    texto <- tryCatch(
      ct$eval(codigo),
      error = function(e) error_fhirpath(conditionMessage(e), expresion)
    )
    jsonlite::fromJSON(texto, simplifyVector = FALSE)
  }

  list(
    nombre = "v8",
    version = function() ct$eval("fhirviews.version()"),
    cargar = function(recursos) {
      fuente <- attr(recursos, "fuente")
      if (!is.null(fuente)) {
        # Texto JSON original: V8 lo lee sin pasar por jsonlite::toJSON()
        inicio <- as.integer(ct$eval("fhirviews.tamano()"))
        ct$assign("fhirviews_entrada", I(fuente))
        ids <- llamar("JSON.stringify(fhirviews.cargarTextos(fhirviews_entrada))")
        ct$eval("fhirviews_entrada = null;")
        ids <- as.integer(unlist(ids))
        if (length(ids) == length(recursos)) {
          return(ids)
        }
        ct$eval(sprintf("fhirviews.liberar(%d)", inicio))
      }
      ct$assign("fhirviews_entrada",
                as.character(a_json(unclass(sin_fuente(recursos)))))
      ids <- llamar("JSON.stringify(fhirviews.cargar(fhirviews_entrada))")
      ct$eval("fhirviews_entrada = null;")
      as.integer(unlist(ids))
    },
    evaluar = function(ids, expresion, variables = NULL, por_nodo = NULL,
                       modo = c("valores", "nodos")) {
      modo <- match.arg(modo)
      if (length(ids) == 0L) {
        return(list())
      }
      codigo <- sprintf(
        "JSON.stringify(fhirviews.evaluar(%s, %s, %s, %s, %s))",
        jsonlite::toJSON(as.integer(ids)),
        a_json(expresion, unbox = TRUE),
        a_json_variables(variables),
        if (is.null(por_nodo)) "null" else
          jsonlite::toJSON(por_nodo, digits = NA, na = "null"),
        a_json(modo, unbox = TRUE)
      )
      res <- llamar(codigo, expresion)
      if (modo == "nodos") {
        res <- lapply(res, function(x) as.integer(unlist(x)))
      }
      res
    },
    tipo = function(contexto, expresion) {
      res <- llamar(sprintf("JSON.stringify(fhirviews.tipo(%s, %s))",
                            a_json(contexto, unbox = TRUE),
                            a_json(expresion, unbox = TRUE)), expresion)
      if (is.null(res$tipo)) NULL else res
    },
    desconocido = function(contexto, expresion) {
      res <- llamar(sprintf("JSON.stringify(fhirviews.desconocido(%s, %s))",
                            a_json(contexto, unbox = TRUE),
                            a_json(expresion, unbox = TRUE)), expresion)
      if (is.null(res$campo)) NULL else res
    },
    es_recurso = function(tipo) {
      isTRUE(ct$eval(sprintf("fhirviews.esRecurso(%s)",
                             a_json(tipo, unbox = TRUE))) == "true")
    },
    validar = function(expresion) {
      llamar(sprintf("JSON.stringify(fhirviews.validar(%s))",
                     a_json(expresion, unbox = TRUE)), expresion)
      invisible(TRUE)
    },
    tabla = function(ids, maximo) {
      texto <- tryCatch(
        ct$eval(sprintf("JSON.stringify(fhirviews.tabla(%s, %d))",
                        jsonlite::toJSON(as.integer(ids)), as.integer(maximo))),
        error = function(e) error_fhirpath(conditionMessage(e))
      )
      res <- jsonlite::fromJSON(texto, simplifyVector = FALSE)
      # Cada columna pasa a un vector (null a NA) con el tipo común de sus
      # valores, como unlist()
      list(campos = as.character(unlist(res$campos)),
           columnas = lapply(res$columnas, jsonlite::fromJSON,
                             simplifyVector = TRUE))
    },
    tamano = function() as.integer(ct$eval("fhirviews.tamano()")),
    liberar = function(desde = 0L) {
      ct$eval(sprintf("fhirviews.liberar(%d)", as.integer(desde)))
      invisible(NULL)
    }
  )
}

# --- JSON y variables --------------------------------------------------------

a_json <- function(x, unbox = FALSE) {
  if (unbox) {
    return(jsonlite::toJSON(x, auto_unbox = TRUE))
  }
  jsonlite::toJSON(x, auto_unbox = TRUE, null = "null", na = "null",
                   digits = NA)
}

a_json_variables <- function(variables) {
  if (length(variables) == 0L) {
    return("{}")
  }
  a_json(preparar_variables(variables))
}

# Las fechas y horas de R se pasan como literales de FHIRPath para que se
# comparen como fechas y no como texto.
preparar_variables <- function(variables) {
  if (length(variables) == 0L) {
    return(structure(list(), names = character()))
  }
  if (is.null(names(variables)) || any(names(variables) == "")) {
    cli::cli_abort("Todas las variables deben tener nombre.",
                   class = "fhirviews_error")
  }
  lapply(variables, function(v) {
    if (inherits(v, "Date")) {
      list(literal = paste0("@", format(v, "%Y-%m-%d")))
    } else if (inherits(v, "POSIXt")) {
      list(literal = paste0("@", format(v, "%Y-%m-%dT%H:%M:%S", tz = "UTC"),
                            "Z"))
    } else {
      v
    }
  })
}

error_fhirpath <- function(mensaje, expresion = NULL) {
  mensaje <- sub("^Error: ", "", mensaje)
  mensaje <- paste(strsplit(mensaje, "\n", fixed = TRUE)[[1]], collapse = "; ")
  cli::cli_abort(c(
    if (is.null(expresion)) "Error al evaluar FHIRPath." else
      "Error al evaluar la expresi\u00f3n FHIRPath {.code {expresion}}.",
    "x" = "{mensaje}"
  ), class = c("fhirviews_error_fhirpath", "fhirviews_error"), call = NULL)
}
