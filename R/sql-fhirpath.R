# --- Traductor de FHIRPath a SQL de DuckDB -----------------------------------
#
# Cada expresión traducida es una lista con `sql` y `k` (clase):
#   coll: lista JSON[] (la colección de FHIRPath; vacía si no hay valores);
#   uno:  un valor JSON, o NULL si la colección está vacía;
#   val:  un valor de SQL del tipo `tipo` (BOOLEAN, VARCHAR, BIGINT o
#         DOUBLE), o NULL si está vacía.
# Además puede llevar:
#   info:   el tipo FHIR según el modelo R4 (list(tipos, ruta)), que se sigue
#           al navegar como lo hace fhirpath.js;
#   cadena: la clase de sus textos ("texto", "fecha", "hora", "sin" si no
#           puede tener textos, NA si no se sabe);
#   texto:  el texto de un literal numérico (para toString()).
# El contexto (ctx) tiene el foco (expresión `uno` o `coll`), el recurso
# (`r`), el índice de fila (%rowIndex), las constantes y un contador para
# nombrar variables de las funciones lambda.
#
# Regla general: el resultado debe ser el mismo que el de fhirpath.js
# (vista_ejecutar()). Cuando no se puede asegurar, la traducción falla con
# fhirviews_error_sql o la consulta llama a error() con un mensaje.

coll <- function(sql, info = NULL, cadena = NULL) {
  list(sql = sql, k = "coll", info = info, cadena = cadena)
}
uno <- function(sql, info = NULL, cadena = NULL) {
  list(sql = sql, k = "uno", info = info, cadena = cadena)
}
val <- function(sql, tipo, cadena = NULL, texto = NULL) {
  list(sql = sql, k = "val", tipo = tipo, cadena = cadena, texto = texto)
}

# Mismo tipo FHIR que `base` (first(), where(), skip()...)
como <- function(base, sql, k = "coll") {
  list(sql = sql, k = k, info = base$info, cadena = clase_cadena(base))
}

numericos <- c("BIGINT", "DOUBLE", "INTEGER")

no_traducible <- function(detalle, .envir = parent.frame()) {
  cli::cli_abort(detalle, class = c("fhirviews_error_sql", "fhirviews_error"),
                 call = NULL, .envir = .envir)
}

# Llamada a error() de DuckDB con un mensaje en español
error_sql <- function(mensaje) {
  sprintf("error(%s)", texto_sql(paste0("FHIRPath: ", mensaje)))
}

nueva_var <- function(ctx) {
  ctx$n$i <- ctx$n$i + 1L
  paste0("z", ctx$n$i)
}

# Usa `sql` varias veces sin repetir su cálculo (si no es un nombre simple)
ligar <- function(sql, f, ctx) {
  if (grepl("^[A-Za-z_][A-Za-z0-9_.]*$", sql)) {
    return(f(sql))
  }
  v <- nueva_var(ctx)
  sprintf("list_extract(list_transform([%s], lambda %s: %s), 1)", sql, v, f(v))
}

a_lista <- function(x, ctx) {
  if (x$k == "coll") return(x$sql)
  v <- nueva_var(ctx)
  valor <- if (x$k == "val") sprintf("to_json(%s)", x$sql) else x$sql
  sprintf("list_filter([%s], lambda %s: %s IS NOT NULL)", valor, v, v)
}

a_coll <- function(x, ctx) {
  if (x$k == "coll") return(x)
  list(sql = a_lista(x, ctx), k = "coll", info = x$info,
       cadena = clase_cadena(x))
}

a_uno <- function(x, ctx, mensaje = NULL) {
  if (x$k == "uno") return(x$sql)
  if (x$k == "val") return(sprintf("to_json(%s)", x$sql))
  mensaje <- mensaje %||%
    "FHIRPath: se esperaba un solo valor y la colecci\u00f3n tiene varios"
  ligar(x$sql, function(v) {
    sprintf("CASE WHEN len(%s) > 1 THEN error(%s) ELSE %s[1] END", v,
            texto_sql(mensaje), v)
  }, ctx)
}

json_a_tipo <- function(u, tipo) {
  switch(tipo,
    VARCHAR = sprintf("json_extract_string(%s, '$')", u),
    JSON = u,
    sprintf("TRY_CAST(%s AS %s)", u, tipo)
  )
}

# Conversión de un valor JSON que debe ser de un tipo: si es de otro, error
# (fhirpath.js tampoco convierte, por ejemplo, un número en texto)
json_estricto <- function(u, tipo, funcion, ctx) {
  ligar(u, function(w) {
    tipos <- switch(tipo,
      VARCHAR = "'VARCHAR'",
      BOOLEAN = "'BOOLEAN'",
      "'BIGINT', 'UBIGINT', 'DOUBLE'"
    )
    sprintf("CASE WHEN %1$s IS NULL THEN NULL WHEN json_type(%1$s) IN (%2$s) THEN %3$s ELSE %4$s END",
            w, tipos, if (tipo == "VARCHAR") json_a_tipo(w, tipo) else
              sprintf("CAST(%s AS %s)", w, tipo),
            error_sql(paste0(funcion, ": tipo de valor no admitido")))
  }, ctx)
}

# Valor de un tipo de SQL a partir de una expresión. Con `estricto`, los
# valores JSON de otro tipo dan error en lugar de convertirse.
a_val <- function(x, tipo, ctx, estricto = NULL) {
  if (x$k == "val") {
    if (identical(x$tipo, tipo)) return(x$sql)
    if (!is.null(estricto) &&
        !(x$tipo %in% numericos && tipo %in% numericos)) {
      no_traducible("{.code {estricto}} no admite un valor de tipo {x$tipo}.")
    }
    return(sprintf("TRY_CAST(%s AS %s)", x$sql, tipo))
  }
  if (!is.null(estricto)) {
    return(json_estricto(a_uno(x, ctx), tipo, estricto, ctx))
  }
  json_a_tipo(a_uno(x, ctx), tipo)
}

# El valor JSON es el lógico true
es_true <- function(u) {
  sprintf("(CASE WHEN json_type(%1$s) = 'BOOLEAN' THEN CAST(%1$s AS BOOLEAN) ELSE false END)",
          u)
}

# Evaluación de una colección como lógico (FHIRPath: un valor que no es
# lógico cuenta como verdadero)
a_bool <- function(x, ctx) {
  if (x$k == "val") {
    if (x$tipo == "BOOLEAN") return(x$sql)
    return(sprintf("(%s IS NOT NULL OR NULL)", x$sql))
  }
  ligar(a_uno(x, ctx), function(u) {
    sprintf("CASE WHEN %1$s IS NULL THEN NULL WHEN json_type(%1$s) = 'BOOLEAN' THEN CAST(%1$s AS BOOLEAN) ELSE true END",
            u)
  }, ctx)
}

# --- Modelo FHIR R4 -----------------------------------------------------------

# Tablas del modelo R4 de fhirpath.js (path2Type, type2Parent,
# choiceTypePaths y pathsDefinedElsewhere) como entornos de R
modelo_r4 <- function() {
  if (is.null(.fhirviews$modelo_r4)) {
    ct <- V8::v8()
    ct$eval("var window = globalThis;")
    cargar_js(ct, ruta_js("fhirpath", "fhirpath.r4.min.js"))
    texto <- ct$eval(paste0(
      "JSON.stringify({p: fhirpath_r4_model.path2Type,",
      " t: fhirpath_r4_model.type2Parent,",
      " c: fhirpath_r4_model.choiceTypePaths,",
      " o: fhirpath_r4_model.pathsDefinedElsewhere})"))
    m <- jsonlite::fromJSON(texto, simplifyVector = TRUE)
    entorno <- function(x) list2env(x, parent = emptyenv())
    .fhirviews$modelo_r4 <- list(path2Type = entorno(m$p),
                                 type2Parent = entorno(m$t),
                                 choiceTypePaths = entorno(m$c),
                                 pathsDefinedElsewhere = entorno(m$o))
  }
  .fhirviews$modelo_r4
}

normalizar_tipo_fhir <- function(t) {
  if (is.null(t)) return(NULL)
  sistema <- c("System.String" = "string", "System.Boolean" = "boolean",
               "System.Integer" = "integer", "System.Decimal" = "decimal",
               "System.Date" = "date", "System.DateTime" = "dateTime",
               "System.Time" = "time")
  if (t %in% names(sistema)) return(sistema[[t]])
  sub("^(FHIR|System)\\.", "", t)
}

# Tipo del hijo `nombre` según el modelo, como hijo() de inst/js/fhirviews.js.
# Devuelve list(tipos, ruta), con varios tipos si es un elemento de
# elección, o NULL si el modelo no lo conoce.
modelo_hijo <- function(info, nombre) {
  if (is.null(info) || length(info$tipos) != 1L || isTRUE(info$eleccion)) {
    return(NULL)
  }
  m <- modelo_r4()
  obtener <- function(e, k) if (exists(k, envir = e, inherits = FALSE))
    get(k, envir = e, inherits = FALSE)
  claves <- if (!is.null(info$ruta)) paste0(info$ruta, ".", nombre)
  t <- info$tipos
  for (n in 1:20) {
    if (is.null(t)) break
    claves <- c(claves, paste0(t, ".", nombre))
    t <- obtener(m$type2Parent, t)
  }
  for (k in claves) {
    tt <- normalizar_tipo_fhir(obtener(m$path2Type, k))
    if (!is.null(tt)) {
      if (tt %in% c("BackboneElement", "Element")) {
        return(list(tipos = tt, ruta = k))
      }
      return(list(tipos = tt, ruta = tt))
    }
    variantes <- obtener(m$choiceTypePaths, k)
    if (!is.null(variantes)) {
      return(list(tipos = as.character(variantes), ruta = NULL,
                  eleccion = TRUE))
    }
    otra <- obtener(m$pathsDefinedElsewhere, k)
    if (!is.null(otra)) {
      return(list(tipos = "BackboneElement", ruta = otra))
    }
  }
  NULL
}

tipos_texto_fhir <- c("string", "code", "id", "uri", "url", "canonical",
                      "markdown", "oid", "uuid", "base64Binary", "xhtml")

clase_fhir <- function(tipos) {
  vapply(tipos, function(t) {
    if (t %in% c("date", "dateTime", "instant")) return("fecha")
    if (t == "time") return("hora")
    if (t == "boolean") return("logico")
    if (t %in% c(tipos_enteros, tipos_decimales, "integer64")) return("numero")
    if (t %in% tipos_texto_fhir) return("texto")
    "complejo"
  }, character(1), USE.NAMES = FALSE)
}

# Clase de los textos que puede tener una expresión
clase_cadena <- function(x) {
  if (!is.null(x$cadena)) return(x$cadena)
  if (x$k == "val") return(if (x$tipo == "VARCHAR") "texto" else "sin")
  tipos <- x$info$tipos
  if (is.null(tipos)) return(NA_character_)
  clases <- setdiff(unique(clase_fhir(tipos)),
                    c("numero", "logico", "complejo"))
  if (length(clases) == 0L) "sin" else if (length(clases) == 1L) clases else
    NA_character_
}

juntar_cadenas <- function(a, b) {
  if (identical(a, "sin")) return(b)
  if (identical(b, "sin")) return(a)
  if (identical(a, b)) a else NA_character_
}

# Tipos posibles de cada elemento de elección (value[x], effective[x]...)
# juntando todos los recursos, para cuando el modelo no sabe dónde se está:
# list(value = c("Quantity", "CodeableConcept", "string", ...), ...)
elementos_eleccion <- function() {
  if (is.null(.fhirviews$elecciones)) {
    m <- modelo_r4()$choiceTypePaths
    r <- list()
    for (k in ls(m, all.names = TRUE)) {
      b <- sub("^.*\\.", "", k)
      r[[b]] <- unique(c(r[[b]], as.character(get(k, envir = m))))
    }
    .fhirviews$elecciones <- r
  }
  .fhirviews$elecciones
}

con_sufijo <- function(nombre, tipo) {
  paste0(nombre, toupper(substr(tipo, 1, 1)), substring(tipo, 2))
}

ruta_json <- function(nombre) {
  texto_sql(paste0("$.\"", gsub("\"", "\\\"", nombre, fixed = TRUE), "\""))
}

# Hijos `nombre` de cada elemento (los arreglos se aplanan). Si `nombre` es
# un elemento de elección (como `value`), se buscan a la vez el campo y
# sus variantes (valueQuantity, valueString...), como hace FHIRPath: las
# del modelo si se conoce la ruta, o las de todos los recursos si no.
hijo <- function(base, nombre, ctx) {
  if (base$k == "val") {
    no_traducible("No se puede navegar a {.field {nombre}} desde un valor simple.")
  }
  info <- modelo_hijo(base$info, nombre)
  variantes <- if (!is.null(info)) {
    if (isTRUE(info$eleccion)) info$tipos
  } else {
    elementos_eleccion()[[nombre]]
  }
  v <- nueva_var(ctx)
  w <- nueva_var(ctx)
  caso <- sprintf(paste0(
    "CASE WHEN %1$s IS NULL OR CAST(%1$s AS VARCHAR) = 'null' THEN []::JSON[] ",
    "WHEN starts_with(CAST(%1$s AS VARCHAR), '[') THEN list_filter(CAST(%1$s AS JSON[]), ",
    "lambda %2$s: %2$s IS NOT NULL AND CAST(%2$s AS VARCHAR) <> 'null') ",
    "ELSE [%1$s] END"), v, w)
  if (is.null(variantes)) {
    extraer <- function(u) sprintf("[json_extract(%s, %s)]", u, ruta_json(nombre))
  } else {
    rutas <- paste0("[", paste(vapply(c(nombre, con_sufijo(nombre, variantes)),
                                      ruta_json, character(1)),
                               collapse = ", "), "]")
    extraer <- function(u) {
      sprintf("coalesce(json_extract(%s, %s), []::JSON[])", u, rutas)
    }
  }
  if (base$k == "uno") {
    valores <- extraer(base$sql)
  } else {
    u <- nueva_var(ctx)
    valores <- sprintf("flatten(list_transform(%s, lambda %s: %s))",
                       base$sql, u, extraer(u))
  }
  coll(sprintf("flatten(list_transform(%s, lambda %s: %s))", valores, v, caso),
       info = info)
}

# --- Literales ---------------------------------------------------------------

# Fechas y horas de FHIRPath (también sirven en SQL: RE2 admite \d y (?:))
re_fecha <- paste0(
  "^(\\d{4})(?:-(\\d{2})(?:-(\\d{2})(?:T(\\d{2})(?::(\\d{2})(?::(\\d{2})",
  "(?:\\.(\\d+))?)?)?(Z|[+-]\\d{2}:\\d{2})?)?)?)?$")
re_hora <- "^(\\d{2})(?::(\\d{2})(?::(\\d{2})(?:\\.(\\d+))?)?)?$"
# Textos que pueden ser fechas u horas
re_parece_fecha <- paste0("^\\d{4}(-\\d{2}(-\\d{2}(T.*)?)?)?$|",
                          "^\\d{2}:\\d{2}(:\\d{2}(\\.\\d+)?)?$")

# Literal de una constante del ViewDefinition
literal_constante <- function(k) {
  campo <- intersect(names(k), tipos_constante)[1]
  valor <- k[[campo]]
  tipo <- switch(campo,
    valueBoolean = "BOOLEAN",
    valueInteger = , valuePositiveInt = , valueUnsignedInt = ,
    valueInteger64 = "BIGINT",
    valueDecimal = "DOUBLE",
    "VARCHAR"
  )
  clase <- switch(campo,
    valueDate = , valueDateTime = , valueInstant = "fecha",
    valueTime = "hora",
    NULL
  )
  valor <- if (tipo == "BOOLEAN") tolower(as.character(valor)) else
    format(valor, scientific = FALSE, digits = 15)
  list(t = "lit", tipo = tipo, valor = valor, clase = clase,
       constante = TRUE)
}

traducir_literal <- function(n) {
  switch(n$tipo,
    VARCHAR = val(texto_sql(n$valor), "VARCHAR", cadena = n$clase %||% "texto"),
    BOOLEAN = val(toupper(n$valor), "BOOLEAN"),
    val(sprintf("CAST(%s AS %s)", n$valor, n$tipo), n$tipo,
        texto = if (!isTRUE(n$constante)) n$valor)
  )
}

# --- Expresiones -------------------------------------------------------------

fp_sql <- function(n, ctx) {
  switch(n$t,
    lit = traducir_literal(n),
    vacio = coll("[]::JSON[]", cadena = "sin"),
    this = ctx$foco,
    var = {
      nombre <- n$nombre
      if (nombre == "rowIndex") {
        val(ctx$indice, "BIGINT")
      } else if (nombre %in% c("resource", "rootResource")) {
        uno(ctx$recurso, info = list(tipos = ctx$tipo_recurso,
                                     ruta = ctx$tipo_recurso))
      } else if (!is.null(ctx$constantes[[nombre]])) {
        traducir_literal(ctx$constantes[[nombre]])
      } else {
        no_traducible("La variable {.code %{nombre}} no est\u00e1 definida.")
      }
    },
    campo = {
      if (is.null(n$base)) {
        if (identical(n$nombre, ctx$tipo_recurso) && ctx$en_recurso) {
          return(ctx$foco)
        }
        base <- ctx$foco
      } else {
        base <- fp_sql(n$base, ctx)
      }
      hijo(base, n$nombre, ctx)
    },
    indice = {
      base <- fp_sql(n$base, ctx)
      i <- a_val(fp_sql(n$i, ctx), "BIGINT", ctx, estricto = "[]")
      como(base, sprintf("list_extract(%s, %s + 1)", a_lista(base, ctx), i),
           "uno")
    },
    neg = {
      a <- fp_sql(n$a, ctx)
      if (a$k == "val" && a$tipo %in% numericos) {
        return(val(sprintf("(-%s)", a$sql), a$tipo))
      }
      val(sprintf("(-%s)", a_val(a, "DOUBLE", ctx, estricto = "-")), "DOUBLE")
    },
    es = {
      if (n$op == "as") fp_oftype(n$a, n$tipo, ctx) else
        es_tipo(n$a, n$tipo, ctx)
    },
    op = fp_operador(n, ctx),
    llamada = fp_funcion(n, ctx),
    no_traducible("Elemento de FHIRPath no reconocido.")
  )
}

fp_operador <- function(n, ctx) {
  op <- n$op
  a <- fp_sql(n$a, ctx)
  b <- fp_sql(n$b, ctx)
  if (op %in% c("and", "or", "xor", "implies")) {
    x <- a_bool(a, ctx)
    y <- a_bool(b, ctx)
    sql <- switch(op,
      and = sprintf("(%s AND %s)", x, y),
      or = sprintf("(%s OR %s)", x, y),
      xor = sprintf("(%s <> %s)", x, y),
      implies = sprintf("((NOT %s) OR %s)", x, y)
    )
    return(val(sql, "BOOLEAN"))
  }
  if (op %in% c("=", "!=", "<", ">", "<=", ">=", "~", "!~")) {
    return(comparar(a, b, op, ctx))
  }
  if (op == "|") {
    return(conjunto(a, b, "union", ctx))
  }
  if (op %in% c("in", "contains")) {
    if (op == "contains") {
      tmp <- a
      a <- b
      b <- tmp
    }
    return(pertenece(a, b, ctx))
  }
  if (op == "&") {
    return(val(sprintf("concat(coalesce(%s, ''), coalesce(%s, ''))",
                       a_val(a, "VARCHAR", ctx, estricto = "&"),
                       a_val(b, "VARCHAR", ctx, estricto = "&")),
               "VARCHAR"))
  }
  aritmetica(a, b, op, ctx)
}

# --- Aritmética ----------------------------------------------------------------

# Clase de un valor para la aritmética: "numero", "texto" u otra
clase_aritmetica <- function(x) {
  if (x$k != "val") {
    if (clase_cadena(x) %in% c("fecha", "hora")) return("otra")
    return(NA_character_)
  }
  if (x$tipo %in% numericos) return("numero")
  if (identical(clase_cadena(x), "texto")) return("texto")
  "otra"
}

aritmetica <- function(a, b, op, ctx) {
  ca <- clase_aritmetica(a)
  cb <- clase_aritmetica(b)
  if (identical(ca, "otra") || identical(cb, "otra")) {
    no_traducible("La aritm\u00e9tica con fechas, horas o cantidades no se traduce.")
  }
  # Suma de textos
  if (op == "+" && (identical(ca, "texto") || identical(cb, "texto"))) {
    return(val(sprintf("(%s || %s)", texto_estricto(a, "+", ctx),
                       texto_estricto(b, "+", ctx)), "VARCHAR"))
  }
  if (op == "+" && is.na(ca) && is.na(cb)) {
    # Dos rutas: números o textos según los valores
    par <- sprintf("{'a': %s, 'b': %s}", a_uno(a, ctx), a_uno(b, ctx))
    sql <- ligar(par, function(v) {
      sprintf(paste0(
        "CASE WHEN %1$s.a IS NULL OR %1$s.b IS NULL THEN NULL ",
        "WHEN json_type(%1$s.a) IN %2$s AND json_type(%1$s.b) IN %2$s ",
        "THEN to_json(CAST(%1$s.a AS DOUBLE) + CAST(%1$s.b AS DOUBLE)) ",
        "WHEN json_type(%1$s.a) = 'VARCHAR' AND json_type(%1$s.b) = 'VARCHAR' ",
        "AND NOT regexp_matches(json_extract_string(%1$s.a, '$'), %3$s) ",
        "AND NOT regexp_matches(json_extract_string(%1$s.b, '$'), %3$s) ",
        "THEN to_json(json_extract_string(%1$s.a, '$') || json_extract_string(%1$s.b, '$')) ",
        "ELSE %4$s END"), v, "('BIGINT', 'UBIGINT', 'DOUBLE')",
        texto_sql(re_parece_fecha),
        error_sql("+ con valores de tipos no admitidos"))
    }, ctx)
    return(uno(sql))
  }
  enteros <- a$k == "val" && b$k == "val" && a$tipo == "BIGINT" &&
    b$tipo == "BIGINT"
  tipo <- if (enteros && op != "/") "BIGINT" else "DOUBLE"
  x <- a_val(a, if (op == "div") "DOUBLE" else tipo, ctx, estricto = op)
  y <- a_val(b, if (op == "div") "DOUBLE" else tipo, ctx, estricto = op)
  sql <- switch(op,
    div = sprintf("CAST(trunc(%s / NULLIF(%s, 0)) AS BIGINT)", x, y),
    "/" = sprintf("(%s / NULLIF(%s, 0))", x, y),
    mod = sprintf("(%s %% NULLIF(%s, 0))", x, y),
    sprintf("(%s %s %s)", x, op, y)
  )
  val(sql, if (op == "div") "BIGINT" else tipo)
}

# Texto de un operando de `+`: debe ser texto (no fecha)
texto_estricto <- function(x, funcion, ctx) {
  if (x$k == "val") {
    if (x$tipo != "VARCHAR" || !identical(clase_cadena(x), "texto")) {
      no_traducible("{.code {funcion}} no admite este tipo de valor.")
    }
    return(x$sql)
  }
  ligar(a_uno(x, ctx), function(u) {
    tipo_txt <- clase_cadena(x)
    dudosa <- if (identical(tipo_txt, "texto")) "false" else
      sprintf("regexp_matches(json_extract_string(%s, '$'), %s)", u,
              texto_sql(re_parece_fecha))
    sprintf(paste0(
      "CASE WHEN %1$s IS NULL THEN NULL WHEN json_type(%1$s) <> 'VARCHAR' OR %2$s ",
      "THEN %3$s ELSE json_extract_string(%1$s, '$') END"),
      u, dudosa, error_sql(paste0(funcion, ": se esperaba texto")))
  }, ctx)
}

# --- Comparaciones -----------------------------------------------------------

# Redondeo de Math.round() de JavaScript (mitades hacia +infinito)
js_redondear <- function(y) {
  sprintf(paste0("(CASE WHEN abs(%1$s) >= 4503599627370496 THEN %1$s ",
                 "WHEN %1$s - floor(%1$s) >= 0.5 THEN floor(%1$s) + 1 ",
                 "ELSE floor(%1$s) END)"), y)
}

# Número como lo compara fhirpath.js (roundToMaxPrecision: 8 decimales)
num_comparable <- function(x) {
  sprintf("(1e-8 * %s + 0.0)", js_redondear(sprintf("(%s / 1e-8)", x)))
}

# Clase de un valor JSON para comparar: s (texto), f (fecha), h (hora),
# b, i, d (lógico, entero, decimal), o (objeto) o ? (texto que puede ser
# fecha sin que se sepa su tipo)
clase_json <- function(u, cadena) {
  txt <- switch(cadena %|NA|% "?", texto = "'s'", fecha = "'f'", hora = "'h'",
    sprintf("CASE WHEN regexp_matches(json_extract_string(%s, '$'), %s) THEN '?' ELSE 's' END",
            u, texto_sql(re_parece_fecha)))
  sprintf(paste0("CASE json_type(%1$s) WHEN 'VARCHAR' THEN %2$s ",
                 "WHEN 'BOOLEAN' THEN 'b' WHEN 'BIGINT' THEN 'i' ",
                 "WHEN 'UBIGINT' THEN 'i' WHEN 'DOUBLE' THEN 'd' ELSE 'o' END"),
          u, txt)
}

`%|NA|%` <- function(x, y) if (is.null(x) || is.na(x)) y else x

clase_val <- function(x) {
  switch(x$tipo, BIGINT = "i", INTEGER = "i", DOUBLE = "d", BOOLEAN = "b",
         VARCHAR = switch(clase_cadena(x), fecha = "f", hora = "h", "s"))
}

# Clases posibles de un lado de la comparación
clases_posibles <- function(x) {
  if (x$k == "val") return(clase_val(x))
  cad <- clase_cadena(x)
  txt <- switch(cad %|NA|% "?", texto = "s", fecha = "f", hora = "h",
                sin = c("s", "?"), c("s", "?"))
  c(txt, "b", "i", "d", "o")
}

resultado_op <- function(op, signo) {
  # signo: -1, 0 o 1; devuelve el literal de SQL del resultado
  r <- switch(op,
    "=" = , "~" = signo == 0, "!=" = , "!~" = signo != 0,
    "<" = signo < 0, ">" = signo > 0, "<=" = signo <= 0, ">=" = signo >= 0)
  if (r) "true" else "false"
}

comparar <- function(a, b, op, ctx) {
  simbolo <- switch(op, "!=" = "<>", "~" = "=", "!~" = "<>", op)
  orden <- op %in% c("<", ">", "<=", ">=")
  equivalencia <- op %in% c("~", "!~")
  pa <- clases_posibles(a)
  pb <- clases_posibles(b)
  if (equivalencia && ((a$k == "val" && pa %in% c("i", "d")) ||
                       (b$k == "val" && pb %in% c("i", "d")))) {
    no_traducible("{.code ~} con n\u00fameros no se traduce.")
  }
  lado <- function(x) {
    if (x$k == "val") {
      list(sql = x$sql, json = FALSE, clase = sprintf("'%s'", clase_val(x)))
    } else {
      list(sql = a_uno(x, ctx), json = TRUE, cadena = clase_cadena(x))
    }
  }
  la <- lado(a)
  lb <- lado(b)
  par <- sprintf("{'a': %s, 'b': %s}", la$sql, lb$sql)
  sql <- ligar(par, function(v) {
    va <- paste0(v, ".a")
    vb <- paste0(v, ".b")
    ka <- if (la$json) clase_json(va, la$cadena) else la$clase
    kb <- if (lb$json) clase_json(vb, lb$cadena) else lb$clase
    clases <- sprintf("{'a': %s, 'b': %s, 'ka': %s, 'kb': %s}", va, vb, ka, kb)
    ligar(clases, function(w) {
      x <- paste0(w, ".a")
      y <- paste0(w, ".b")
      ka <- paste0(w, ".ka")
      kb <- paste0(w, ".kb")
      num <- function(z, json) if (json) sprintf("CAST(%s AS DOUBLE)", z) else
        sprintf("CAST(%s AS DOUBLE)", z)
      txt <- function(z, json) if (json) sprintf("json_extract_string(%s, '$')", z) else z
      bool <- function(z, json) if (json) sprintf("CAST(%s AS BOOLEAN)", z) else z
      ramas <- character()
      agregar <- function(cond, res) ramas <<- c(ramas, sprintf("WHEN %s THEN %s", cond, res))
      if ("?" %in% c(pa, pb)) {
        agregar(sprintf("%s = '?' OR %s = '?'", ka, kb),
                error_sql("no se sabe si un texto es una fecha; usa ofType() o vista_ejecutar()"))
      }
      if ("o" %in% pa && "o" %in% pb) {
        agregar(sprintf("%s = 'o' AND %s = 'o'", ka, kb),
                error_sql("la comparaci\u00f3n de elementos complejos no se traduce"))
      }
      if (any(pa %in% c("i", "d")) && any(pb %in% c("i", "d"))) {
        if (equivalencia) {
          agregar(sprintf("%s IN ('i', 'd') AND %s IN ('i', 'd')", ka, kb),
                  error_sql("~ con n\u00fameros no se traduce"))
        } else {
          entero <- sprintf("(CAST(%s AS BIGINT) %s CAST(%s AS BIGINT))",
                            x, simbolo, y)
          decimal <- sprintf("(%s %s %s)", num_comparable(num(x, la$json)),
                             simbolo, num_comparable(num(y, lb$json)))
          agregar(sprintf("%s IN ('i', 'd') AND %s IN ('i', 'd')", ka, kb),
                  sprintf("CASE WHEN %s = 'i' AND %s = 'i' THEN %s ELSE %s END",
                          ka, kb, entero, decimal))
        }
      }
      if (length(union(pa, pb)) > 1L) {
        distinto <- if (orden) {
          error_sql(paste("no se pueden comparar con", op, "valores de tipos distintos"))
        } else if (op %in% c("=", "~")) "false" else "true"
        agregar(sprintf("%s <> %s", ka, kb), distinto)
      }
      comunes <- intersect(pa, pb)
      if ("b" %in% comunes) {
        agregar(sprintf("%s = 'b'", ka), if (orden) {
          error_sql("no se pueden ordenar valores l\u00f3gicos")
        } else {
          sprintf("(%s %s %s)", bool(x, la$json), simbolo, bool(y, lb$json))
        })
      }
      if ("s" %in% comunes) {
        tx <- txt(x, la$json)
        ty <- txt(y, lb$json)
        res <- if (equivalencia) {
          sprintf("(%s %s %s)", texto_equivalente(tx), simbolo,
                  texto_equivalente(ty))
        } else if (orden) {
          sprintf("CASE WHEN regexp_matches(%s || %s, %s) THEN %s ELSE (%s %s %s) END",
                  tx, ty, texto_sql(re_fuera_bmp),
                  error_sql("orden de textos con caracteres fuera del plano b\u00e1sico"),
                  tx, simbolo, ty)
        } else {
          sprintf("(%s %s %s)", tx, simbolo, ty)
        }
        agregar(sprintf("%s = 's'", ka), res)
      }
      if ("f" %in% comunes) {
        agregar(sprintf("%s = 'f'", ka),
                comparar_fechas(txt(x, la$json), txt(y, lb$json), op, ctx))
      }
      if ("h" %in% comunes) {
        agregar(sprintf("%s = 'h'", ka),
                comparar_horas(txt(x, la$json), txt(y, lb$json), op, ctx))
      }
      vacio <- if (equivalencia) {
        # {} ~ {} es verdadero; un lado vacío, falso
        sprintf("WHEN %1$s IS NULL AND %2$s IS NULL THEN %3$s WHEN %1$s IS NULL OR %2$s IS NULL THEN %4$s",
                x, y, resultado_op(op, 0), resultado_op(op, 1))
      } else {
        sprintf("WHEN %s IS NULL OR %s IS NULL THEN NULL", x, y)
      }
      sprintf("CASE %s %s END", vacio, paste(ramas, collapse = " "))
    }, ctx)
  }, ctx)
  val(sql, "BOOLEAN")
}

re_fuera_bmp <- "[\\x{10000}-\\x{10FFFF}]"

# Caracteres en los que upper()/lower() de DuckDB y toUpperCase()/
# toLowerCase() de JavaScript dan resultados distintos (data-raw/mayusculas.R)
re_mayusculas_dudosas <- paste0(
  "[\\x{DF}\\x{149}\\x{1F0}\\x{26A}\\x{282}\\x{29D}\\x{390}\\x{3B0}",
  "\\x{587}\\x{10D0}-\\x{10FA}\\x{10FD}-\\x{10FF}\\x{13F8}-\\x{13FD}",
  "\\x{1C80}-\\x{1C88}\\x{1D8E}\\x{1E96}-\\x{1E9A}\\x{1F50}\\x{1F52}",
  "\\x{1F54}\\x{1F56}\\x{1F80}-\\x{1FAF}\\x{1FB2}-\\x{1FB4}\\x{1FB6}-",
  "\\x{1FB7}\\x{1FBC}\\x{1FC2}-\\x{1FC4}\\x{1FC6}-\\x{1FC7}\\x{1FCC}",
  "\\x{1FD2}-\\x{1FD3}\\x{1FD6}-\\x{1FD7}\\x{1FE2}-\\x{1FE4}\\x{1FE6}-",
  "\\x{1FE7}\\x{1FF2}-\\x{1FF4}\\x{1FF6}-\\x{1FF7}\\x{1FFC}\\x{2C5F}",
  "\\x{A794}\\x{A7B5}\\x{A7B7}\\x{A7B9}\\x{A7BB}\\x{A7BD}\\x{A7BF}",
  "\\x{A7C1}\\x{A7C3}\\x{A7C8}\\x{A7CA}\\x{A7D1}\\x{A7D7}\\x{A7D9}",
  "\\x{A7F6}\\x{AB53}\\x{AB70}-\\x{ABBF}\\x{FB00}-\\x{FB06}\\x{FB13}-",
  "\\x{FB17}\\x{10000}-\\x{10FFFF}]")
re_minusculas_dudosas <- paste0(
  "[\\x{130}\\x{3A3}\\x{13A0}-\\x{13F5}\\x{1C90}-\\x{1CBA}\\x{1CBD}-",
  "\\x{1CBF}\\x{2C2F}\\x{A7AE}\\x{A7B2}-\\x{A7B4}\\x{A7B6}\\x{A7B8}",
  "\\x{A7BA}\\x{A7BC}\\x{A7BE}\\x{A7C0}\\x{A7C2}\\x{A7C4}-\\x{A7C7}",
  "\\x{A7C9}\\x{A7D0}\\x{A7D6}\\x{A7D8}\\x{A7F5}\\x{10000}-\\x{10FFFF}]")

# Espacios que fhirpath.js cambia por " " en ~ y que trim() de JavaScript
# quita
re_espacios_js <- "[\\t-\\r \\x{85}\\x{A0}\\x{1680}\\x{2000}-\\x{200A}\\x{2028}\\x{2029}\\x{202F}\\x{205F}\\x{3000}]"
re_trim_js <- "[\\t-\\r \\x{A0}\\x{1680}\\x{2000}-\\x{200A}\\x{2028}\\x{2029}\\x{202F}\\x{205F}\\x{3000}\\x{FEFF}]"

con_guardia <- function(s, patron, mensaje, sql) {
  sprintf("CASE WHEN regexp_matches(%s, %s) THEN %s ELSE %s END", s,
          texto_sql(patron), error_sql(mensaje), sql)
}

mayusculas <- function(s) {
  con_guardia(s, re_mayusculas_dudosas,
              "upper() con caracteres que DuckDB convierte distinto",
              sprintf("upper(%s)", s))
}

minusculas <- function(s) {
  con_guardia(s, re_minusculas_dudosas,
              "lower() con caracteres que DuckDB convierte distinto",
              sprintf("lower(%s)", s))
}

texto_equivalente <- function(s) {
  sprintf("regexp_replace(%s, %s, ' ', 'g')", mayusculas(s),
          texto_sql(re_espacios_js))
}

# Partes de una fecha de FHIRPath en un STRUCT: c (forma canónica, en UTC si
# tiene zona horaria, de largo según la precisión), t (tiene hora), z (tiene
# zona), u (instante, para las que tienen hora) y ok (bien escrita y con
# 0 o 3 decimales en los segundos)
fecha_partes <- function(s, ctx) {
  m <- sprintf("regexp_extract(%s, %s, ['y', 'mo', 'd', 'h', 'mi', 'se', 'f', 'tz'])",
               s, texto_sql(re_fecha))
  ligar(sprintf("{'s': %s, 'm': %s}", s, m), function(p) {
    g <- function(campo) sprintf("%s.m.%s", p, campo)
    local <- sprintf(paste0(
      "make_timestamp(CAST(%s AS BIGINT), CAST(%s AS BIGINT), CAST(%s AS BIGINT), ",
      "CAST(%s AS BIGINT), CAST(coalesce(nullif(%s, ''), '0') AS BIGINT), ",
      "CAST(coalesce(nullif(%s, ''), '0') || '.' || coalesce(nullif(%s, ''), '0') AS DOUBLE))"),
      g("y"), g("mo"), g("d"), g("h"), g("mi"), g("se"), g("f"))
    minutos <- sprintf(paste0(
      "CASE WHEN %1$s IN ('', 'Z') THEN 0 ELSE (CASE WHEN left(%1$s, 1) = '-' ",
      "THEN -1 ELSE 1 END) * (CAST(substr(%1$s, 2, 2) AS BIGINT) * 60 + ",
      "CAST(substr(%1$s, 5, 2) AS BIGINT)) END"), g("tz"))
    largo <- sprintf("CASE WHEN %s <> '' THEN 23 WHEN %s <> '' THEN 16 ELSE 13 END",
                     g("se"), g("mi"))
    instante <- sprintf("CASE WHEN %s <> '' THEN %s - to_minutes(%s) END",
                        g("h"), local, minutos)
    sprintf(paste0(
      "{'ok': %1$s <> '' AND length(%2$s) IN (0, 3), 't': %3$s <> '', ",
      "'z': %4$s <> '', 'u': %5$s, ",
      "'c': CASE WHEN %3$s = '' THEN %6$s.s ELSE left(strftime(%5$s, '%%Y-%%m-%%dT%%H:%%M:%%S.%%g'), %7$s) END}"),
      g("y"), g("f"), g("h"), g("tz"), instante, p, largo)
  }, ctx)
}

# Comparación de dos textos canónicos con la regla de precisión de
# FHIRPath: si difieren en la parte común, decide el orden; si son iguales
# y tienen la misma precisión, son iguales; si no, el resultado es vacío
# (o falso con ~).
comparar_prefijo <- function(x, y, op) {
  l <- sprintf("least(length(%s), length(%s))", x, y)
  px <- sprintf("left(%s, %s)", x, l)
  py <- sprintf("left(%s, %s)", y, l)
  distinta <- switch(op, "~" = "false", "!~" = "true", "NULL")
  sprintf(paste0("CASE WHEN %1$s < %2$s THEN %3$s WHEN %1$s > %2$s THEN %4$s ",
                 "WHEN length(%5$s) = length(%6$s) THEN %7$s ELSE %8$s END"),
          px, py, resultado_op(op, -1), resultado_op(op, 1), x, y,
          resultado_op(op, 0), distinta)
}

comparar_fechas <- function(x, y, op, ctx) {
  orden <- op %in% c("<", ">", "<=", ">=")
  par <- sprintf("{'a': %s, 'b': %s}", fecha_partes(x, ctx),
                 fecha_partes(y, ctx))
  ligar(par, function(v) {
    a <- paste0(v, ".a")
    b <- paste0(v, ".b")
    # Una fecha sin hora frente a una fecha con hora: fhirpath.js pasa la
    # segunda a la zona horaria del equipo. Solo se traduce si el resultado
    # es el mismo en cualquier zona (de -12 a +14 horas).
    mixta <- if (orden) {
      signo <- function(d, t, horas) {
        corte <- sprintf("left(strftime(%s.u + to_hours(CASE WHEN %s.z THEN %d ELSE 0 END), '%%Y-%%m-%%d'), length(%s.c))",
                         t, t, horas, d)
        sprintf("(CASE WHEN %1$s.c < %2$s THEN -1 WHEN %1$s.c > %2$s THEN 1 ELSE 0 END)",
                d, corte)
      }
      res <- function(s, invertir) {
        s2 <- if (invertir) sprintf("(-%s)", s) else s
        sprintf("CASE WHEN %1$s < 0 THEN %2$s WHEN %1$s > 0 THEN %3$s ELSE NULL END",
                s2, resultado_op(op, -1), resultado_op(op, 1))
      }
      caso <- function(d, t, invertir) {
        bajo <- signo(d, t, -12)
        alto <- signo(d, t, 14)
        sprintf("CASE WHEN %s = %s THEN %s ELSE %s END", bajo, alto,
                res(bajo, invertir),
                error_sql(paste("comparar una fecha sin hora con una fecha y hora depende",
                               "de la zona horaria del equipo; compara con un literal con hora y zona",
                               "(por ejemplo @2024-01-01T00:00:00Z)")))
      }
      sprintf("CASE WHEN %s.t THEN %s ELSE %s END", a, caso(b, a, TRUE),
              caso(a, b, FALSE))
    } else {
      error_sql("igualdad entre una fecha y una fecha con hora no se traduce")
    }
    sprintf(paste0(
      "CASE WHEN NOT %1$s.ok OR NOT %2$s.ok THEN %3$s ",
      "WHEN %1$s.t AND %2$s.t AND %1$s.z <> %2$s.z THEN %4$s ",
      "WHEN %1$s.t = %2$s.t THEN %5$s ELSE %6$s END"),
      a, b, error_sql("fecha mal escrita o con una precisi\u00f3n de segundos no admitida"),
      error_sql("comparar fechas con y sin zona horaria depende de la zona del equipo"),
      comparar_prefijo(paste0(a, ".c"), paste0(b, ".c"), op), mixta)
  }, ctx)
}

hora_partes <- function(s, ctx) {
  m <- sprintf("regexp_extract(%s, %s, ['h', 'mi', 'se', 'f'])", s,
               texto_sql(re_hora))
  ligar(m, function(p) {
    sprintf(paste0(
      "{'ok': %1$s.h <> '' AND length(%1$s.f) IN (0, 3), ",
      "'c': %1$s.h || CASE WHEN %1$s.mi = '' THEN '' ELSE ':' || %1$s.mi END || ",
      "CASE WHEN %1$s.se = '' THEN '' ELSE ':' || %1$s.se || '.' || ",
      "CASE WHEN %1$s.f = '' THEN '000' ELSE %1$s.f END END}"), p)
  }, ctx)
}

comparar_horas <- function(x, y, op, ctx) {
  par <- sprintf("{'a': %s, 'b': %s}", hora_partes(x, ctx), hora_partes(y, ctx))
  ligar(par, function(v) {
    sprintf("CASE WHEN NOT %1$s.a.ok OR NOT %1$s.b.ok THEN %2$s ELSE %3$s END",
            v, error_sql("hora mal escrita o con una precisi\u00f3n de segundos no admitida"),
            comparar_prefijo(paste0(v, ".a.c"), paste0(v, ".b.c"), op))
  }, ctx)
}

# --- Conjuntos ---------------------------------------------------------------

# Clave de igualdad de un valor JSON (dos valores son iguales en FHIRPath si
# y solo si tienen la misma clave). Los objetos no se comparan: si hace
# falta compararlos, error.
clave_igualdad <- function(u, cadena, ctx) {
  txt <- sprintf("json_extract_string(%s, '$')", u)
  fecha <- ligar(fecha_partes(txt, ctx), function(p) {
    sprintf(paste0("CASE WHEN NOT %1$s.ok OR (%1$s.t AND NOT %1$s.z) THEN %2$s ",
                   "ELSE 'f:' || %1$s.c END"), p,
            error_sql("fecha sin zona horaria o mal escrita en una operaci\u00f3n de conjuntos"))
  }, ctx)
  cadena_sql <- switch(cadena %|NA|% "?",
    texto = sprintf("'s:' || %s", txt),
    fecha = fecha,
    hora = ligar(hora_partes(txt, ctx), function(p) {
      sprintf("CASE WHEN NOT %s.ok THEN %s ELSE 'h:' || %s.c END", p,
              error_sql("hora mal escrita"), p)
    }, ctx),
    sprintf("CASE WHEN regexp_matches(%s, %s) THEN %s ELSE 's:' || %s END",
            txt, texto_sql(re_parece_fecha),
            error_sql("no se sabe si un texto es una fecha; usa ofType() o vista_ejecutar()"),
            txt)
  )
  sprintf(paste0(
    "CASE json_type(%1$s) WHEN 'VARCHAR' THEN %2$s ",
    "WHEN 'BOOLEAN' THEN 'b:' || CAST(%1$s AS VARCHAR) ",
    "WHEN 'BIGINT' THEN 'n:' || CAST(%3$s AS VARCHAR) ",
    "WHEN 'UBIGINT' THEN 'n:' || CAST(%3$s AS VARCHAR) ",
    "WHEN 'DOUBLE' THEN 'n:' || CAST(%3$s AS VARCHAR) ",
    "ELSE 'o:' || CAST(%1$s AS VARCHAR) END"),
    u, cadena_sql, num_comparable(sprintf("CAST(%s AS DOUBLE)", u)))
}

claves <- function(lista, cadena, ctx) {
  q <- nueva_var(ctx)
  sprintf("list_transform(%s, lambda %s: %s)", lista, q,
          clave_igualdad(q, cadena, ctx))
}

# Error si hay que comparar objetos (más de `max` en las claves)
sin_objetos <- function(k, max, sql) {
  sprintf("CASE WHEN len(list_filter(%s, lambda o: starts_with(o, 'o:'))) > %d THEN %s ELSE %s END",
          k, max, error_sql("la comparaci\u00f3n de elementos complejos no se traduce"),
          sql)
}

# Elementos sin repetir, en el orden de su primera aparición
sin_repetir <- function(lista, cadena, ctx) {
  ligar(lista, function(l) {
    ligar(claves(l, cadena, ctx), function(k) {
      x <- nueva_var(ctx)
      i <- nueva_var(ctx)
      sin_objetos(k, 1L, sprintf(
        "list_filter(%s, lambda %s, %s: list_position(%s, %s[%s]) = %s)",
        l, x, i, k, k, i, i))
    }, ctx)
  }, ctx)
}

conjunto <- function(a, b, operacion, ctx) {
  cadena <- juntar_cadenas(clase_cadena(a), clase_cadena(b))
  info <- if (identical(a$info, b$info)) a$info
  la <- a_lista(a, ctx)
  lb <- a_lista(b, ctx)
  sql <- switch(operacion,
    union = sin_repetir(sprintf("list_concat(%s, %s)", la, lb), cadena, ctx),
    combine = sprintf("list_concat(%s, %s)", la, lb),
    intersect = , exclude = ligar(la, function(l) {
      ligar(claves(l, cadena, ctx), function(ka) {
        ligar(claves(lb, cadena, ctx), function(kb) {
          x <- nueva_var(ctx)
          i <- nueva_var(ctx)
          condicion <- sprintf("list_contains(%s, %s[%s])", kb, ka, i)
          if (operacion == "exclude") condicion <- paste("NOT", condicion)
          filtrado <- sprintf("list_filter(%s, lambda %s, %s: %s)", l, x, i,
                              condicion)
          if (operacion == "intersect") {
            filtrado <- sin_repetir(filtrado, cadena, ctx)
          }
          sin_objetos(sprintf("list_concat(%s, %s)", ka, kb), 0L, filtrado)
        }, ctx)
      }, ctx)
    }, ctx)
  )
  coll(sql, info = info, cadena = cadena)
}

# a in b
pertenece <- function(a, b, ctx) {
  cadena <- juntar_cadenas(clase_cadena(a), clase_cadena(b))
  ua <- a_uno(a, ctx)
  sql <- ligar(ua, function(u) {
    ligar(claves(a_lista(b, ctx), cadena, ctx), function(k) {
      ligar(clave_igualdad(u, cadena, ctx), function(c1) {
        sprintf("CASE WHEN %s IS NULL THEN NULL ELSE %s END", u,
                sin_objetos(sprintf("list_concat([%s], %s)", c1, k), 0L,
                            sprintf("list_contains(%s, %s)", k, c1)))
      }, ctx)
    }, ctx)
  }, ctx)
  val(sql, "BOOLEAN")
}

# Subconjunto: todos los de `a` están en `b`
subconjunto <- function(a, b, ctx) {
  cadena <- juntar_cadenas(clase_cadena(a), clase_cadena(b))
  sql <- ligar(claves(a_lista(a, ctx), cadena, ctx), function(ka) {
    ligar(claves(a_lista(b, ctx), cadena, ctx), function(kb) {
      x <- nueva_var(ctx)
      sin_objetos(sprintf("list_concat(%s, %s)", ka, kb), 0L,
                  sprintf("len(list_filter(%s, lambda %s: NOT list_contains(%s, %s))) = 0",
                          ka, x, kb, x))
    }, ctx)
  }, ctx)
  val(sql, "BOOLEAN")
}

# --- Tipos ---------------------------------------------------------------------

# Nombre de tipo de un argumento como `Patient` o `FHIR.Quantity`
nombre_tipo_arg <- function(arg) {
  if (identical(arg$t, "campo")) {
    return(arg$nombre)
  }
  if (identical(arg$t, "lit") && arg$tipo == "VARCHAR") {
    return(arg$valor)
  }
  no_traducible("Se esperaba un nombre de tipo.")
}

primitivos_json <- list(
  string = "'VARCHAR'", code = "'VARCHAR'", id = "'VARCHAR'",
  uri = "'VARCHAR'", url = "'VARCHAR'", canonical = "'VARCHAR'",
  markdown = "'VARCHAR'", date = "'VARCHAR'", dateTime = "'VARCHAR'",
  instant = "'VARCHAR'", time = "'VARCHAR'", oid = "'VARCHAR'",
  uuid = "'VARCHAR'", base64Binary = "'VARCHAR'",
  boolean = "'BOOLEAN'",
  integer = "'BIGINT', 'UBIGINT'", positiveInt = "'BIGINT', 'UBIGINT'",
  unsignedInt = "'BIGINT', 'UBIGINT'",
  decimal = "'DOUBLE', 'BIGINT', 'UBIGINT'"
)

# ofType(): sobre un elemento de elección (value.ofType(Quantity)) se
# traduce como el campo concreto (valueQuantity); sobre otras colecciones
# filtra por el tipo JSON de los valores primitivos.
fp_oftype <- function(base_nodo, tipo, ctx) {
  tipo <- sub("^(FHIR|System)\\.", "", tipo)
  tipos_json <- primitivos_json[[tipo]]
  if (identical(base_nodo$t, "campo")) {
    padre <- if (is.null(base_nodo$base)) ctx$foco else
      fp_sql(base_nodo$base, ctx)
    info <- if (padre$k != "val") modelo_hijo(padre$info, base_nodo$nombre)
    variantes <- if (!is.null(info)) {
      if (isTRUE(info$eleccion)) info$tipos
    } else {
      elementos_eleccion()[[base_nodo$nombre]]
    }
    if (!is.null(variantes)) {
      if (!con_sufijo("", tipo) %in% con_sufijo("", variantes)) {
        no_traducible("{.field {base_nodo$nombre}[x]} no admite el tipo {.code {tipo}}.")
      }
      nodo <- base_nodo
      nodo$nombre <- con_sufijo(base_nodo$nombre, tipo)
      x <- fp_sql(nodo, ctx)
      x$info <- list(tipos = tipo, ruta = tipo)
      x$cadena <- NULL
      return(x)
    }
  }
  if (is.null(tipos_json)) {
    no_traducible("{.code ofType({tipo})} solo se traduce sobre elementos de elecci\u00f3n (como {.code value.ofType({tipo})}) o con tipos primitivos.")
  }
  base <- if (is.null(base_nodo)) ctx$foco else fp_sql(base_nodo, ctx)
  info <- list(tipos = tipo, ruta = tipo)
  conocido <- base$info$tipos
  if (length(conocido) == 1L && !isTRUE(base$info$eleccion)) {
    # El tipo se conoce por el modelo: son todos o ninguno (los subtipos,
    # como positiveInt de integer, no se traducen)
    if (identical(conocido, tipo)) {
      return(coll(a_lista(base, ctx), info = info))
    }
    no_traducible("{.code ofType({tipo})} sobre valores de tipo {.code {conocido}} no se traduce.")
  }
  # Tipo desconocido: solo los lógicos se distinguen sin dudas en JSON
  if (tipo != "boolean") {
    no_traducible("{.code ofType({tipo})} sobre valores de tipo desconocido no se traduce.")
  }
  v <- nueva_var(ctx)
  coll(sprintf("list_filter(%s, lambda %s: json_type(%s) IN (%s))",
               a_lista(base, ctx), v, v, tipos_json), info = info)
}

# x is T: vacío si x está vacío, error si tiene varios elementos
es_tipo <- function(base_nodo, tipo, ctx) {
  filtrado <- a_lista(fp_oftype(base_nodo, tipo, ctx), ctx)
  base <- if (is.null(base_nodo)) ctx$foco else fp_sql(base_nodo, ctx)
  sql <- ligar(a_lista(base, ctx), function(l) {
    sprintf("CASE WHEN len(%s) = 0 THEN NULL WHEN len(%s) > 1 THEN %s ELSE len(%s) > 0 END",
            l, l, error_sql("is: se esperaba un solo valor"), filtrado)
  }, ctx)
  val(sql, "BOOLEAN")
}

# --- Funciones -----------------------------------------------------------------

# Número como texto, como lo escribe JavaScript (3.0 es "3")
numero_texto_js <- function(x) {
  sprintf(paste0(
    "CASE WHEN %1$s IS NULL THEN NULL ",
    "WHEN isinf(%1$s) OR isnan(%1$s) OR abs(%1$s) >= 1e21 OR ",
    "(%1$s <> 0 AND abs(%1$s) < 1e-6) THEN %2$s ",
    "WHEN %1$s = trunc(%1$s) THEN CAST(CAST(%1$s AS HUGEINT) AS VARCHAR) ",
    "ELSE CAST(%1$s AS VARCHAR) END"),
    x, error_sql("toString() de un n\u00famero muy grande o muy peque\u00f1o"))
}

# Texto con caracteres fuera del plano básico: JavaScript cuenta dos
# unidades por cada uno y DuckDB una
guardia_bmp <- function(s, funcion, sql) {
  con_guardia(s, re_fuera_bmp,
              paste0(funcion, "() con caracteres fuera del plano b\u00e1sico"),
              sql)
}

# Expresión regular de JavaScript (con las banderas "su" de fhirpath.js)
# traducida a RE2 si usa solo construcciones que significan lo mismo en los
# dos; si no, NULL.
regex_re2 <- function(patron) {
  ch <- strsplit(patron, "")[[1]]
  n <- length(ch)
  i <- 1L
  en_clase <- FALSE
  sintaxis <- strsplit("^$\\.*+?()[]{}|/", "")[[1]]
  salida <- character()
  while (i <= n) {
    c1 <- ch[i]
    if (c1 == "\\") {
      if (i == n) return(NULL)
      e <- ch[i + 1L]
      if (e %in% c("d", "D", "w", "W", "n", "r", "t", "f", "v", sintaxis) ||
          (!en_clase && e %in% c("b", "B")) || (en_clase && e == "-")) {
        salida <- c(salida, if (e == "v") "\\x{0B}" else paste0("\\", e))
        i <- i + 2L
        next
      }
      return(NULL)
    }
    if (en_clase) {
      if (c1 == "[") return(NULL)
      if (c1 == "]") en_clase <- FALSE
      salida <- c(salida, c1)
      i <- i + 1L
      next
    }
    if (c1 == "[") {
      en_clase <- TRUE
      salida <- c(salida, c1)
      if (i < n && ch[i + 1L] == "^") {
        salida <- c(salida, "^")
        i <- i + 1L
      }
      if (i < n && ch[i + 1L] == "]") return(NULL)
      i <- i + 1L
      next
    }
    if (c1 == "(") {
      if (i < n && ch[i + 1L] == "?") {
        if (i + 2L <= n && ch[i + 2L] == ":") {
          salida <- c(salida, "(?:")
          i <- i + 3L
          next
        }
        return(NULL)
      }
    }
    if (c1 == "{") {
      resto <- paste(ch[i:n], collapse = "")
      m <- regmatches(resto, regexpr("^\\{[0-9]+(,[0-9]*)?\\}", resto))
      if (length(m) == 0L) return(NULL)
      salida <- c(salida, m)
      i <- i + nchar(m)
      next
    }
    if (c1 %in% c("}", "]")) return(NULL)
    salida <- c(salida, c1)
    i <- i + 1L
  }
  if (en_clase) return(NULL)
  paste0("(?s)", paste(salida, collapse = ""))
}

# Argumento literal de texto (para expresiones regulares)
arg_literal <- function(nodo, fn) {
  if (identical(nodo$t, "lit") && nodo$tipo == "VARCHAR" && is.null(nodo$clase)) {
    return(nodo$valor)
  }
  no_traducible("{.code {fn}()} solo se traduce con un texto literal como expresi\u00f3n regular.")
}

regex_arg <- function(nodo, fn) {
  patron <- arg_literal(nodo, fn)
  re <- regex_re2(patron)
  if (is.null(re)) {
    no_traducible("La expresi\u00f3n regular {.val {patron}} usa construcciones que DuckDB interpreta distinto que JavaScript.")
  }
  texto_sql(re)
}

# Fecha, fecha y hora u hora en el límite inferior o superior de su
# precisión, como lowBoundary()/highBoundary() de fhirpath.js
limite_fecha <- function(s, clase, alto, ctx) {
  if (clase == "hora") {
    m <- sprintf("regexp_extract(%s, %s, ['h', 'mi', 'se', 'f'])", s,
                 texto_sql(re_hora))
    return(ligar(m, function(p) {
      relleno <- if (alto) c(":59", ":59", ".999") else c(":00", ":00", ".000")
      sprintf(paste0(
        "CASE WHEN %1$s.h = '' OR length(%1$s.f) > 3 THEN %2$s ELSE %1$s.h || ",
        "CASE WHEN %1$s.mi = '' THEN '%3$s' ELSE ':' || %1$s.mi END || ",
        "CASE WHEN %1$s.se = '' THEN '%4$s' ELSE ':' || %1$s.se END || ",
        "CASE WHEN %1$s.f = '' THEN '%5$s' ELSE '.' || rpad(%1$s.f, 3, '0') END END"),
        p, error_sql("hora mal escrita"), relleno[1], relleno[2], relleno[3])
    }, ctx))
  }
  m <- sprintf("regexp_extract(%s, %s, ['y', 'mo', 'd', 'h', 'mi', 'se', 'f', 'tz'])",
               s, texto_sql(re_fecha))
  ligar(m, function(p) {
    g <- function(campo) sprintf("%s.%s", p, campo)
    mes <- if (alto) "'12'" else "'01'"
    dia <- if (alto) {
      sprintf("strftime(last_day(make_date(CAST(%s AS BIGINT), CAST(coalesce(nullif(%s, ''), '12') AS BIGINT), 1)), '%%d')",
              g("y"), g("mo"))
    } else "'01'"
    fecha <- sprintf(
      "%s || '-' || coalesce(nullif(%s, ''), %s) || '-' || coalesce(nullif(%s, ''), %s)",
      g("y"), g("mo"), mes, g("d"), dia)
    relleno <- if (alto) c(":59", ":59", ".999") else c(":00", ":00", ".000")
    # fhirpath.js no agrega la zona horaria que pide la especificación
    sin_zona <- error_sql(paste("lowBoundary()/highBoundary() de una fecha y hora",
                                "sin hora o sin zona horaria no se traduce"))
    hora <- sprintf(paste0(
      "'T' || %1$s || CASE WHEN %2$s = '' THEN '%5$s' ELSE ':' || %2$s END || ",
      "CASE WHEN %3$s = '' THEN '%6$s' ELSE ':' || %3$s END || ",
      "CASE WHEN %4$s = '' THEN '%7$s' ELSE '.' || rpad(%4$s, 3, '0') END"),
      g("h"), g("mi"), g("se"), g("f"), relleno[1], relleno[2], relleno[3])
    sprintf(paste0(
      "CASE WHEN %1$s = '' OR length(%2$s) > 3 THEN %3$s ",
      "WHEN %4$s = '' THEN %5$s ",
      "WHEN %6$s = '' THEN %7$s ELSE %8$s || %9$s || %6$s END"),
      g("y"), g("f"), error_sql("fecha mal escrita"),
      g("h"), if (clase == "date") fecha else sin_zona, g("tz"), sin_zona,
      fecha, hora)
  }, ctx)
}

fp_funcion <- function(n, ctx) {
  fn <- n$fn
  args <- n$args
  narg <- length(args)
  aridad <- function(validas) {
    if (!narg %in% validas) {
      no_traducible("La funci\u00f3n {.code {fn}()} no admite {narg} argumento{?s}.")
    }
  }
  if (fn %in% c("ofType", "is", "as")) {
    aridad(1)
    if (fn == "is") {
      return(es_tipo(n$base, nombre_tipo_arg(args[[1]]), ctx))
    }
    return(fp_oftype(n$base, nombre_tipo_arg(args[[1]]), ctx))
  }
  base <- if (is.null(n$base)) ctx$foco else fp_sql(n$base, ctx)
  # Contexto de las funciones que evalúan su argumento en cada elemento
  lambda <- function(cuerpo) {
    v <- nueva_var(ctx)
    ctx2 <- ctx
    ctx2$foco <- uno(v, info = base$info, cadena = clase_cadena(base))
    ctx2$en_recurso <- FALSE
    list(v = v, x = cuerpo(ctx2))
  }
  arg <- function(i, tipo) {
    a_val(fp_sql(args[[i]], ctx), tipo, ctx, estricto = paste0(fn, "()"))
  }
  texto <- function() a_val(base, "VARCHAR", ctx, estricto = paste0(fn, "()"))
  lista <- function() a_lista(base, ctx)
  # Un número de la base (entero o decimal) como DOUBLE, con error si no lo es
  numero <- function() a_val(base, "DOUBLE", ctx, estricto = paste0(fn, "()"))
  # Valor JSON de la base con su tipo JSON, para las conversiones
  convertir <- function(f) {
    if (base$k == "val") {
      u <- sprintf("to_json(%s)", base$sql)
    } else {
      u <- a_uno(base, ctx)
    }
    ligar(u, function(w) {
      sprintf("CASE WHEN %1$s IS NULL THEN NULL ELSE %2$s END", w, f(w))
    }, ctx)
  }
  cadena_base <- clase_cadena(base)
  switch(fn,
    where = {
      aridad(1)
      # Como en fhirpath.js, un criterio que no es lógico cuenta como true
      l <- lambda(function(c2) a_bool(fp_sql(args[[1]], c2), c2))
      como(base, sprintf("list_filter(%s, lambda %s: coalesce(%s, false))",
                         lista(), l$v, l$x))
    },
    select = {
      aridad(1)
      res <- NULL
      l <- lambda(function(c2) {
        res <<- fp_sql(args[[1]], c2)
        a_lista(res, c2)
      })
      coll(sprintf("flatten(list_transform(%s, lambda %s: %s))", lista(), l$v,
                   l$x), info = res$info, cadena = clase_cadena(res))
    },
    exists = {
      aridad(0:1)
      if (narg == 0L) {
        return(val(sprintf("(len(%s) > 0)", lista()), "BOOLEAN"))
      }
      l <- lambda(function(c2) a_bool(fp_sql(args[[1]], c2), c2))
      val(sprintf("(len(list_filter(%s, lambda %s: coalesce(%s, false))) > 0)",
                  lista(), l$v, l$x), "BOOLEAN")
    },
    all = {
      aridad(1)
      l <- lambda(function(c2) a_bool(fp_sql(args[[1]], c2), c2))
      val(sprintf("(len(list_filter(%s, lambda %s: NOT coalesce(%s, false))) = 0)",
                  lista(), l$v, l$x), "BOOLEAN")
    },
    allTrue = , anyTrue = , allFalse = , anyFalse = {
      aridad(0)
      v <- nueva_var(ctx)
      buscado <- if (fn %in% c("allTrue", "anyFalse")) "false" else "true"
      sql <- ligar(lista(), function(l) {
        sprintf(paste0(
          "CASE WHEN len(list_filter(%1$s, lambda %2$s: json_type(%2$s) <> 'BOOLEAN')) > 0 ",
          "THEN %3$s ELSE list_contains(list_transform(%1$s, lambda %2$s: TRY_CAST(%2$s AS BOOLEAN)), %4$s) END"),
          l, v, error_sql(paste0(fn, "() necesita valores l\u00f3gicos")), buscado)
      }, ctx)
      if (fn %in% c("allTrue", "allFalse")) sql <- sprintf("(NOT %s)", sql)
      val(sql, "BOOLEAN")
    },
    empty = {
      aridad(0)
      val(sprintf("(len(%s) = 0)", lista()), "BOOLEAN")
    },
    hasValue = {
      aridad(0)
      val(sprintf("(len(%s) = 1)", lista()), "BOOLEAN")
    },
    count = {
      aridad(0)
      val(sprintf("CAST(len(%s) AS BIGINT)", lista()), "BIGINT")
    },
    first = {
      aridad(0)
      if (base$k != "coll") return(base)
      como(base, sprintf("list_extract(%s, 1)", base$sql), "uno")
    },
    last = {
      aridad(0)
      if (base$k != "coll") return(base)
      como(base, sprintf("list_extract(%s, -1)", base$sql), "uno")
    },
    single = {
      aridad(0)
      if (base$k != "coll") return(base)
      como(base, a_uno(base, ctx), "uno")
    },
    tail = {
      aridad(0)
      como(base, sprintf("list_slice(%s, 2, 2147483647)", lista()))
    },
    skip = , take = {
      aridad(1)
      # fhirpath.js usa slice() de JavaScript: con un número negativo cuenta
      # desde el final, distinto de la especificación; se evita
      cuantos <- ligar(arg(1, "BIGINT"), function(k) {
        sprintf("CASE WHEN %s < 0 THEN %s ELSE %s END", k,
                error_sql(paste0(fn, "() con un n\u00famero negativo")), k)
      }, ctx)
      sql <- if (fn == "skip") {
        sprintf("list_slice(%s, %s + 1, 2147483647)", lista(), cuantos)
      } else {
        sprintf("list_slice(%s, 1, %s)", lista(), cuantos)
      }
      como(base, sql)
    },
    distinct = {
      aridad(0)
      como(base, sin_repetir(lista(), cadena_base, ctx))
    },
    isDistinct = {
      aridad(0)
      sql <- ligar(lista(), function(l) {
        sprintf("(len(%s) = len(%s))", sin_repetir(l, cadena_base, ctx), l)
      }, ctx)
      val(sql, "BOOLEAN")
    },
    union = , combine = , intersect = , exclude = {
      aridad(1)
      conjunto(base, fp_sql(args[[1]], ctx), fn, ctx)
    },
    subsetOf = {
      aridad(1)
      subconjunto(base, fp_sql(args[[1]], ctx), ctx)
    },
    supersetOf = {
      aridad(1)
      subconjunto(fp_sql(args[[1]], ctx), base, ctx)
    },
    not = {
      aridad(0)
      val(sprintf("(NOT %s)", a_bool(base, ctx)), "BOOLEAN")
    },
    iif = {
      aridad(2:3)
      # fhirpath.js solo toma la rama verdadera con el lógico true
      cond <- fp_sql(args[[1]], ctx)
      condicion <- if (cond$k == "val") {
        if (cond$tipo == "BOOLEAN") cond$sql else "false"
      } else {
        ligar(a_uno(cond, ctx), function(u) {
          es_true(u)
        }, ctx)
      }
      si <- fp_sql(args[[2]], ctx)
      no <- if (narg == 3L) fp_sql(args[[3]], ctx) else coll("[]::JSON[]", cadena = "sin")
      coll(sprintf("CASE WHEN coalesce(%s, false) THEN %s ELSE %s END",
                   condicion, a_lista(si, ctx), a_lista(no, ctx)),
           info = if (identical(si$info, no$info)) si$info,
           cadena = juntar_cadenas(clase_cadena(si), clase_cadena(no)))
    },
    trace = {
      aridad(1)
      base
    },
    join = {
      aridad(0:1)
      separador <- if (narg == 1L) arg(1, "VARCHAR") else "''"
      sql <- ligar(lista(), function(l) {
        w <- nueva_var(ctx)
        sprintf(paste0(
          "CASE WHEN len(%1$s) = 0 THEN NULL ",
          "WHEN len(list_filter(%1$s, lambda %2$s: json_type(%2$s) <> 'VARCHAR')) > 0 THEN %4$s ",
          "ELSE array_to_string(",
          "list_transform(%1$s, lambda %2$s: json_extract_string(%2$s, '$')), %3$s) END"),
          l, w, separador, error_sql("join() necesita textos"))
      }, ctx)
      val(sql, "VARCHAR")
    },
    extension = {
      aridad(1)
      url <- arg(1, "VARCHAR")
      v <- nueva_var(ctx)
      ext <- hijo(base, "extension", ctx)
      coll(sprintf("list_filter(%s, lambda %s: json_extract_string(%s, '$.url') = %s)",
                   ext$sql, v, v, url),
           info = list(tipos = "Extension", ruta = "Extension"))
    },
    getResourceKey = {
      aridad(0)
      if (base$k == "uno") {
        return(val(sprintf("json_extract_string(%s, '$.id')", base$sql),
                   "VARCHAR"))
      }
      hijo(base, "id", ctx)
    },
    getReferenceKey = {
      aridad(0:1)
      v <- nueva_var(ctx)
      p <- nueva_var(ctx)
      q <- nueva_var(ctx)
      condicion <- sprintf("len(%s) >= 2", p)
      if (narg == 1L) {
        condicion <- sprintf("%s AND %s[-2] = %s", condicion, p,
                             texto_sql(nombre_tipo_arg(args[[1]])))
      }
      partes <- sprintf(
        "list_transform(%s, lambda %s: string_split(split_part(json_extract_string(%s, '$.reference'), '/_history', 1), '/'))",
        lista(), v, v)
      coll(sprintf("list_transform(list_filter(%s, lambda %s: %s), lambda %s: to_json(%s[-1]))",
                   partes, p, condicion, q, q), cadena = "texto")
    },
    startsWith = {
      aridad(1)
      val(sprintf("starts_with(%s, %s)", texto(), arg(1, "VARCHAR")),
          "BOOLEAN")
    },
    endsWith = {
      aridad(1)
      val(sprintf("suffix(%s, %s)", texto(), arg(1, "VARCHAR")), "BOOLEAN")
    },
    contains = {
      aridad(1)
      val(sprintf("contains(%s, %s)", texto(), arg(1, "VARCHAR")), "BOOLEAN")
    },
    matches = {
      aridad(1)
      val(sprintf("regexp_matches(%s, %s)", texto(), regex_arg(args[[1]], fn)),
          "BOOLEAN")
    },
    replaceMatches = {
      aridad(2)
      patron <- regex_arg(args[[1]], fn)
      reemplazo <- arg_literal(args[[2]], fn)
      # $1..$9 y $& de JavaScript; \ es literal en JavaScript y especial en RE2
      if (grepl("\\$[`'<]|\\$[0-9]{2}", reemplazo)) {
        no_traducible("El reemplazo {.val {reemplazo}} usa construcciones de JavaScript que no se traducen.")
      }
      r <- gsub("\\", "\\\\", reemplazo, fixed = TRUE)
      r <- gsub("$$", "\001", r, fixed = TRUE)
      r <- gsub("\\$([1-9])", "\\\\\\1", r)
      r <- gsub("$&", "\\0", r, fixed = TRUE)
      r <- gsub("\001", "$", r, fixed = TRUE)
      val(sprintf("regexp_replace(%s, %s, %s, 'g')", texto(), patron,
                  texto_sql(r)), "VARCHAR")
    },
    upper = {
      aridad(0)
      val(ligar(texto(), mayusculas, ctx), "VARCHAR")
    },
    lower = {
      aridad(0)
      val(ligar(texto(), minusculas, ctx), "VARCHAR")
    },
    trim = {
      aridad(0)
      val(sprintf("regexp_replace(%s, %s, '', 'g')", texto(),
                  texto_sql(paste0("^", re_trim_js, "+|", re_trim_js, "+$"))),
          "VARCHAR")
    },
    length = {
      aridad(0)
      val(ligar(texto(), function(s) {
        guardia_bmp(s, fn, sprintf("CAST(length(%s) AS BIGINT)", s))
      }, ctx), "BIGINT")
    },
    indexOf = {
      aridad(1)
      sql <- ligar(sprintf("{'s': %s, 'b': %s}", texto(), arg(1, "VARCHAR")),
                   function(p) {
        guardia_bmp(sprintf("%s.s", p), fn, sprintf(
          "CASE WHEN %1$s.b IS NULL THEN NULL ELSE CAST(instr(%1$s.s, %1$s.b) - 1 AS BIGINT) END",
          p))
      }, ctx)
      val(sql, "BIGINT")
    },
    substring = {
      aridad(1:2)
      largo <- if (narg == 2L) arg(2, "BIGINT") else "NULL::BIGINT"
      sql <- ligar(sprintf("{'s': %s, 'i': %s, 'n': %s}", texto(),
                           arg(1, "BIGINT"), largo), function(p) {
        guardia_bmp(sprintf("%s.s", p), fn, sprintf(paste0(
          "CASE WHEN %1$s.s IS NULL OR %1$s.i IS NULL OR %1$s.i < 0 OR ",
          "%1$s.i >= length(%1$s.s) THEN NULL ",
          "WHEN %1$s.n IS NULL THEN substring(%1$s.s, %1$s.i + 1) ",
          "WHEN %1$s.n < 0 THEN %2$s ",
          "ELSE substring(%1$s.s, %1$s.i + 1, %1$s.n) END"),
          p, error_sql("substring() con un largo negativo")))
      }, ctx)
      val(sql, "VARCHAR")
    },
    replace = {
      aridad(2)
      sql <- ligar(sprintf("{'s': %s, 'a': %s, 'b': %s}", texto(),
                           arg(1, "VARCHAR"), arg(2, "VARCHAR")), function(p) {
        # El reemplazo de JavaScript interpreta $&, $1... (fhirpath.js usa
        # replaceAll); con un patrón vacío inserta entre cada carácter
        sprintf(paste0(
          "CASE WHEN contains(%1$s.b, '$') THEN %2$s ",
          "WHEN %1$s.a = '' THEN %3$s ",
          "ELSE replace(%1$s.s, %1$s.a, %1$s.b) END"),
          p, error_sql("replace() con $ en el reemplazo"),
          guardia_bmp(sprintf("%s.s", p), fn, sprintf(
            "regexp_replace(%1$s.s, '', replace(%1$s.b, '\\', '\\\\'), 'g')", p)))
      }, ctx)
      val(sql, "VARCHAR")
    },
    toChars = {
      aridad(0)
      v <- nueva_var(ctx)
      sql <- ligar(texto(), function(s) {
        guardia_bmp(s, fn, sprintf(
          "CASE WHEN %1$s IS NULL THEN []::JSON[] ELSE list_transform(string_split(%1$s, ''), lambda %2$s: to_json(%2$s)) END",
          s, v))
      }, ctx)
      coll(sql, cadena = "texto")
    },
    split = {
      aridad(1)
      v <- nueva_var(ctx)
      sql <- ligar(sprintf("{'s': %s, 'b': %s}", texto(), arg(1, "VARCHAR")),
                   function(p) {
        sprintf(paste0(
          "CASE WHEN %1$s.s IS NULL OR %1$s.b IS NULL THEN []::JSON[] ",
          "WHEN %1$s.b = '' THEN %3$s ",
          "ELSE list_transform(string_split(%1$s.s, %1$s.b), lambda %2$s: to_json(%2$s)) END"),
          p, v, error_sql("split() con un separador vac\u00edo"))
      }, ctx)
      coll(sql, cadena = "texto")
    },
    toString = {
      aridad(0)
      if (base$k == "val") {
        if (!is.null(base$texto)) return(val(texto_sql(base$texto), "VARCHAR"))
        sql <- switch(base$tipo,
          VARCHAR = base$sql,
          BOOLEAN = sprintf("CASE WHEN %1$s THEN 'true' WHEN NOT %1$s THEN 'false' END",
                            base$sql),
          BIGINT = sprintf("CAST(%s AS VARCHAR)", base$sql),
          numero_texto_js(base$sql))
        return(val(sql, "VARCHAR"))
      }
      val(convertir(function(w) {
        sprintf(paste0(
          "CASE json_type(%1$s) WHEN 'VARCHAR' THEN json_extract_string(%1$s, '$') ",
          "WHEN 'BOOLEAN' THEN CAST(%1$s AS VARCHAR) ",
          "WHEN 'BIGINT' THEN CAST(%1$s AS VARCHAR) WHEN 'UBIGINT' THEN CAST(%1$s AS VARCHAR) ",
          "WHEN 'DOUBLE' THEN %2$s ELSE %3$s END"),
          w, numero_texto_js(sprintf("CAST(%s AS DOUBLE)", w)),
          error_sql("toString() de un elemento complejo no se traduce"))
      }), "VARCHAR")
    },
    toInteger = , convertsToInteger = {
      aridad(0)
      if (base$k == "val" && !is.null(base$texto) && base$tipo == "DOUBLE") {
        # Un decimal literal no se convierte en entero
        return(val(if (fn == "toInteger") "NULL::BIGINT" else "false",
                   if (fn == "toInteger") "BIGINT" else "BOOLEAN"))
      }
      f <- function(w) {
        sprintf(paste0(
          "CASE json_type(%1$s) WHEN 'BIGINT' THEN CAST(%1$s AS BIGINT) ",
          "WHEN 'UBIGINT' THEN CAST(%1$s AS BIGINT) ",
          "WHEN 'DOUBLE' THEN CASE WHEN CAST(%1$s AS DOUBLE) = trunc(CAST(%1$s AS DOUBLE)) ",
          "AND abs(CAST(%1$s AS DOUBLE)) < 9007199254740992 THEN CAST(CAST(%1$s AS DOUBLE) AS BIGINT) END ",
          "WHEN 'BOOLEAN' THEN CASE WHEN CAST(%1$s AS BOOLEAN) THEN 1 ELSE 0 END ",
          "WHEN 'VARCHAR' THEN CASE WHEN regexp_matches(json_extract_string(%1$s, '$'), '^[+-]?[0-9]+$') ",
          "THEN TRY_CAST(json_extract_string(%1$s, '$') AS BIGINT) END END"), w)
      }
      convertido(fn, f, "BIGINT", convertir)
    },
    toDecimal = , convertsToDecimal = {
      aridad(0)
      f <- function(w) {
        sprintf(paste0(
          "CASE json_type(%1$s) WHEN 'BIGINT' THEN CAST(%1$s AS DOUBLE) ",
          "WHEN 'UBIGINT' THEN CAST(%1$s AS DOUBLE) WHEN 'DOUBLE' THEN CAST(%1$s AS DOUBLE) ",
          "WHEN 'BOOLEAN' THEN CASE WHEN CAST(%1$s AS BOOLEAN) THEN 1.0 ELSE 0.0 END ",
          "WHEN 'VARCHAR' THEN CASE WHEN regexp_matches(json_extract_string(%1$s, '$'), '^[+-]?[0-9]+(\\.[0-9]+)?$') ",
          "THEN CAST(json_extract_string(%1$s, '$') AS DOUBLE) END END"), w)
      }
      convertido(fn, f, "DOUBLE", convertir)
    },
    toBoolean = , convertsToBoolean = {
      aridad(0)
      f <- function(w) {
        sprintf(paste0(
          "CASE json_type(%1$s) WHEN 'BOOLEAN' THEN CAST(%1$s AS BOOLEAN) ",
          "WHEN 'BIGINT' THEN CASE CAST(%1$s AS BIGINT) WHEN 1 THEN true WHEN 0 THEN false END ",
          "WHEN 'UBIGINT' THEN CASE CAST(%1$s AS BIGINT) WHEN 1 THEN true WHEN 0 THEN false END ",
          "WHEN 'DOUBLE' THEN CASE CAST(%1$s AS DOUBLE) WHEN 1 THEN true WHEN 0 THEN false END ",
          "WHEN 'VARCHAR' THEN CASE WHEN lower(json_extract_string(%1$s, '$')) IN ",
          "('true', 't', 'yes', 'y', '1', '1.0') THEN true WHEN lower(json_extract_string(%1$s, '$')) IN ",
          "('false', 'f', 'no', 'n', '0', '0.0') THEN false END END"), w)
      }
      convertido(fn, f, "BOOLEAN", convertir)
    },
    convertsToString = {
      aridad(0)
      val(convertir(function(w) {
        sprintf("json_type(%s) IN ('VARCHAR', 'BOOLEAN', 'BIGINT', 'UBIGINT', 'DOUBLE')", w)
      }), "BOOLEAN")
    },
    abs = , ceiling = , floor = , truncate = , sqrt = {
      aridad(0)
      x <- numero()
      sql <- switch(fn,
        abs = sprintf("abs(%s)", x),
        ceiling = sprintf("ceil(%s)", x),
        floor = sprintf("floor(%s)", x),
        truncate = sprintf("trunc(%s)", x),
        sqrt = ligar(x, function(y) {
          sprintf("CASE WHEN %1$s < 0 THEN NULL ELSE sqrt(%1$s) END", y)
        }, ctx))
      entero <- base$k == "val" && base$tipo == "BIGINT" && fn == "abs"
      if (entero) return(val(sprintf("abs(%s)", base$sql), "BIGINT"))
      val(sql, "DOUBLE")
    },
    round = {
      aridad(0:1)
      x <- numero()
      sql <- if (narg == 0L) {
        ligar(x, js_redondear, ctx)
      } else {
        ligar(sprintf("{'x': %s, 'p': %s}", x, arg(1, "BIGINT")), function(p) {
          sprintf(paste0("CASE WHEN %1$s.p < 0 OR %1$s.p > 15 THEN %2$s ",
                         "ELSE %3$s / pow(10, %1$s.p) END"),
                  p, error_sql("round() con una precisi\u00f3n fuera de 0 a 15"),
                  js_redondear(sprintf("(%1$s.x * pow(10, %1$s.p))", p)))
        }, ctx)
      }
      val(sql, "DOUBLE")
    },
    power = {
      aridad(1)
      # Solo potencias exactas de enteros: pow() de DuckDB y Math.pow() de
      # JavaScript pueden diferir en el último bit
      sql <- ligar(sprintf("{'x': %s, 'e': %s}", numero(), arg(1, "DOUBLE")),
                   function(p) {
        sprintf(paste0(
          "CASE WHEN %1$s.x IS NULL OR %1$s.e IS NULL THEN NULL ",
          "WHEN %1$s.x = trunc(%1$s.x) AND %1$s.e = trunc(%1$s.e) AND %1$s.e >= 0 ",
          "AND abs(pow(%1$s.x, %1$s.e)) < 9007199254740992 THEN pow(%1$s.x, %1$s.e) ",
          "ELSE %2$s END"),
          p, error_sql("power() solo se traduce con enteros y resultado exacto"))
      }, ctx)
      val(sql, "DOUBLE")
    },
    lowBoundary = , highBoundary = {
      aridad(0)
      tipo <- base$info$tipos
      clase <- if (identical(tipo, "date")) "date" else
        if (identical(tipo, "time") || identical(clase_cadena(base), "hora")) "hora" else
        if (length(tipo) == 1L && tipo %in% c("dateTime", "instant")) "dateTime" else
        if (identical(clase_cadena(base), "fecha") && base$k == "val") {
          if (grepl("T", base$sql, fixed = TRUE)) "dateTime" else "date"
        }
      if (is.null(clase)) {
        no_traducible("{.code {fn}()} solo se traduce con fechas, fechas y horas u horas (los decimales pierden su precisi\u00f3n al leer el JSON).")
      }
      s <- a_val(base, "VARCHAR", ctx, estricto = paste0(fn, "()"))
      val(ligar(s, function(x) limite_fecha(x, clase, fn == "highBoundary", ctx), ctx),
          "VARCHAR", cadena = if (clase == "hora") "hora" else "fecha")
    },
    no_traducible("La funci\u00f3n {.code {fn}()} no est\u00e1 en el subconjunto de FHIRPath que se traduce a SQL.")
  )
}

# Resultado de toX() o de convertsToX(); `f` convierte un valor JSON
convertido <- function(fn, f, tipo, convertir) {
  if (startsWith(fn, "convertsTo")) {
    return(val(convertir(function(w) sprintf("((%s) IS NOT NULL)", f(w))),
               "BOOLEAN"))
  }
  val(convertir(f), tipo)
}

# Traduce una expresión del ViewDefinition, con un error que indica cuál
traducir_expresion <- function(expresion, ctx) {
  tryCatch(fp_sql(fp_analizar(expresion), ctx),
    fhirviews_error_sql = function(e) {
      cli::cli_abort(c(
        "No se puede traducir {.code {expresion}} a SQL.",
        "x" = "{limpiar_mensaje(conditionMessage(e))}",
        "i" = "Usa {.fn vista_ejecutar}, que eval\u00faa FHIRPath completo con
               fhirpath.js."
      ), class = c("fhirviews_error_sql", "fhirviews_error"), call = NULL)
    })
}
