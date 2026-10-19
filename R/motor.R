# Motores de FHIRPath
#
# El motor de vistas no llama a fhirpath.js directamente: usa un "motor", una
# lista de funciones con esta interfaz:
#
#   cargar(recursos)                      -> enteros (un nodo por recurso)
#   evaluar(ids, expresion, variables, por_nodo, modo)
#                                         -> lista, un elemento por nodo:
#                                            valores (modo "valores") o
#                                            enteros de nodos (modo "nodos")
#   validar(expresion)                    -> TRUE o error
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
      ct$assign("fhirviews_entrada", as.character(a_json(unclass(recursos))))
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
        if (is.null(por_nodo)) "null" else a_json(lapply(por_nodo, preparar_variables)),
        a_json(modo, unbox = TRUE)
      )
      res <- llamar(codigo, expresion)
      if (modo == "nodos") {
        res <- lapply(res, function(x) as.integer(unlist(x)))
      }
      res
    },
    validar = function(expresion) {
      llamar(sprintf("JSON.stringify(fhirviews.validar(%s))",
                     a_json(expresion, unbox = TRUE)), expresion)
      invisible(TRUE)
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
