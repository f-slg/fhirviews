#' Traducir un ViewDefinition a SQL de DuckDB (experimental)
#'
#' **Experimental**, como [vista_ejecutar_duckdb()]. Traduce un `ViewDefinition` a una consulta SQL de
#' [DuckDB](https://duckdb.org/) que lee los recursos FHIR como JSON y
#' devuelve la tabla de la vista. Es el motor que usa
#' [vista_ejecutar_duckdb()]; esta función solo genera el texto, para
#' revisarlo o ejecutarlo en otra herramienta (por ejemplo la línea de
#' comandos de DuckDB).
#'
#' El traductor cubre la estructura completa del `ViewDefinition` (`select`
#' anidados, `column`, `forEach`, `forEachOrNull`, `repeat`, `unionAll`,
#' `where`, `constant` y `%rowIndex`) y un subconjunto de FHIRPath:
#' navegación por campos (los elementos de elección como `value` o
#' `effective` buscan todas sus variantes, `valueQuantity`,
#' `valueString`...), índices (`name[0]`), `where()`, `select()`,
#' `exists()`, `empty()`, `count()`, `first()`, `last()`, `tail()`, `skip()`,
#' `take()`, `single()`, `distinct()`, `all()`, `not()`, `iif()`, `join()`,
#' `ofType()` sobre elementos de elección (`value.ofType(Quantity)` es
#' `valueQuantity`), `extension(url)`, `getResourceKey()`,
#' `getReferenceKey()`, funciones de texto (`startsWith()`, `endsWith()`,
#' `contains()`, `upper()`, `lower()`, `length()`, `substring()`,
#' `replace()`, `trim()`, `matches()`, `toString()`), conversiones
#' (`toInteger()`, `toDecimal()`), comparaciones, aritmética, `and`, `or`,
#' `xor`, `implies`, `|`, `in` y `contains`. Si una expresión usa algo
#' fuera de ese subconjunto, se produce un error de clase
#' `fhirviews_error_sql` que sugiere usar [vista_ejecutar()].
#'
#' Los elementos `repeat` se traducen hasta una profundidad fija (por
#' defecto 12 niveles; la opción `fhirviews.sql_profundidad` la cambia); si
#' los datos tienen más niveles, la consulta produce un error en lugar de
#' omitir filas.
#'
#' Los tipos de las columnas salen del `type` de cada columna, del tipo
#' de la expresión o, si no, del modelo FHIR R4. Las columnas cuyo tipo no
#' se puede deducir quedan como `JSON`; [vista_ejecutar_duckdb()] las
#' convierte después según los valores.
#'
#' @param vista Un `ViewDefinition` en cualquier forma que acepte
#'   [vista_leer()].
#' @param desde Origen de los recursos: rutas de archivos NDJSON (también
#'   comprimidos con gzip) o Parquet, o el nombre de una tabla o vista de
#'   DuckDB con una columna `json` (un recurso FHIR por fila).
#'
#' @return El texto de la consulta (clase `fhir_sql`).
#' @seealso [vista_ejecutar_duckdb()] para ejecutarla.
#' @export
#' @examples
#' vista <- vista_crear("Patient", c(sexo = "gender",
#'                                   apellido = "name.first().family"))
#' vista_sql(vista, "pacientes.ndjson")
vista_sql <- function(vista, desde = "recursos") {
  vista <- vista_leer(vista)
  traducir_vista(vista, origen_sql(desde))$sql
}

#' @export
print.fhir_sql <- function(x, ...) {
  cat(x, "\n", sep = "")
  invisible(x)
}

#' Ejecutar un ViewDefinition con DuckDB (experimental)
#'
#' **Experimental.** Este motor es un prototipo: su interfaz y el
#' subconjunto de FHIRPath que admite pueden cambiar. Para resultados de
#' referencia usa [vista_ejecutar()].
#'
#' Traduce el `ViewDefinition` a SQL con [vista_sql()] y lo ejecuta en
#' [DuckDB](https://duckdb.org/) directamente sobre archivos NDJSON o
#' Parquet, sin cargar los recursos en R ni en el motor de FHIRPath. DuckDB
#' lee los archivos en paralelo y por partes, de modo que se pueden
#' procesar millones de recursos con poca memoria.
#'
#' Es un motor alternativo a [vista_ejecutar()], que evalúa FHIRPath
#' completo con `fhirpath.js`. Este motor admite un subconjunto de FHIRPath
#' (ver [vista_sql()]); si la vista usa algo que no se puede traducir, el
#' error lo indica y sugiere usar [vista_ejecutar()].
#'
#' Requiere los paquetes DBI y duckdb (versión 1.3.0 o posterior) y la
#' extensión `json` de DuckDB, que el paquete duckdb no trae incorporada:
#' DuckDB la descarga la primera vez que se usa en cada sesión de R (hace
#' falta conexión a internet). La conexión que crea esta función guarda las
#' extensiones en la carpeta temporal de la sesión, no en `~/.duckdb`.
#'
#' @param archivos Rutas de archivos `.ndjson`, `.ndjson.gz` o `.parquet`
#'   (se pueden usar comodines como `"datos/*.ndjson"`), el nombre de una
#'   tabla de `con_db` con una columna `json`, o recursos en cualquier forma
#'   que acepte [fhir_recursos()] (que se escriben antes en un archivo
#'   temporal).
#' @param vista Un `ViewDefinition` en cualquier forma que acepte
#'   [vista_leer()].
#' @param con_db Conexión DBI a DuckDB. Si es `NULL` (por defecto), se usa
#'   una base en memoria.
#' @param tabla Nombre opcional de una tabla de `con_db` donde guardar el
#'   resultado en lugar de traerlo a R; útil con resultados muy grandes.
#'
#' @return Un `data.frame` como el de [vista_ejecutar()] o, si se indica
#'   `tabla`, la conexión DBI de forma invisible.
#' @export
#' @examplesIf requireNamespace("duckdb", quietly = TRUE) && interactive()
#' archivo <- system.file("extdata", "caso_clinico.ndjson",
#'                        package = "fhirviews")
#' vista_ejecutar_duckdb(archivo, vista_crear("Patient", c(
#'   sexo = "gender", nacimiento = "birthDate")))
vista_ejecutar_duckdb <- function(archivos, vista, con_db = NULL,
                                  tabla = NULL) {
  rlang::check_installed(c("DBI", "duckdb"),
                         reason = "para ejecutar vistas con DuckDB.")
  if (utils::packageVersion("duckdb") < "1.3.0") {
    cli::cli_abort(c(
      "El motor DuckDB necesita el paquete {.pkg duckdb} 1.3.0 o posterior.",
      "i" = "Actualiza con {.code install.packages(\"duckdb\")}."
    ), class = "fhirviews_error")
  }
  vista <- vista_leer(vista)
  propia <- is.null(con_db)
  if (propia) {
    con_db <- conectar_duckdb()
    if (is.null(tabla)) {
      on.exit(DBI::dbDisconnect(con_db), add = TRUE)
    }
  }
  cargar_json_duckdb(con_db)
  if (!is.character(archivos)) {
    archivos <- escribir_ndjson_temporal(archivos)
    on.exit(unlink(archivos), add = TRUE)
  }
  trad <- traducir_vista(vista, origen_sql(archivos))
  ejecutar_traduccion(con_db, trad, tabla)
}

# --- Ejecución ---------------------------------------------------------------

cargar_json_duckdb <- function(con) {
  ok <- tryCatch({
    DBI::dbExecute(con, "LOAD json")
    TRUE
  }, error = function(e) FALSE)
  if (ok) {
    return(invisible(TRUE))
  }
  tryCatch({
    DBI::dbExecute(con, "INSTALL json")
    DBI::dbExecute(con, "LOAD json")
  }, error = function(e) {
    cli::cli_abort(c(
      "No se pudo cargar la extensi\u00f3n {.val json} de DuckDB.",
      "x" = "{limpiar_mensaje(conditionMessage(e))}",
      "i" = "DuckDB la descarga la primera vez con {.code INSTALL json};
             hace falta conexi\u00f3n a internet esa vez."
    ), class = "fhirviews_error", call = NULL)
  })
  invisible(TRUE)
}

escribir_ndjson_temporal <- function(recursos) {
  recursos <- fhir_recursos(recursos)
  fuente <- attr(recursos, "fuente")
  if (!is.null(fuente) && length(fuente) == length(recursos)) {
    lineas <- gsub("[\r\n]+", " ", fuente)
  } else {
    lineas <- vapply(recursos, function(r) {
      as.character(jsonlite::toJSON(r, auto_unbox = TRUE, digits = NA,
                                    null = "null"))
    }, character(1))
  }
  archivo <- tempfile("fhirviews-", fileext = ".ndjson")
  con <- file(archivo, open = "wb")
  on.exit(close(con))
  writeLines(enc2utf8(lineas), con, useBytes = TRUE)
  archivo
}

ejecutar_traduccion <- function(con, trad, tabla) {
  ejecutar <- function(sql, consulta = TRUE) {
    f <- if (consulta) DBI::dbGetQuery else DBI::dbExecute
    tryCatch(f(con, sql), error = function(e) {
      cli::cli_abort(c(
        "DuckDB no pudo ejecutar la vista.",
        "x" = "{limpiar_mensaje(conditionMessage(e))}"
      ), class = c("fhirviews_error_vista", "fhirviews_error"), call = NULL)
    })
  }
  desconocidas <- names(trad$tipos)[vapply(trad$tipos, is.na, logical(1))]
  sql <- unclass(trad$sql)
  temporal <- NULL
  if (length(desconocidas) > 0L) {
    # Columnas sin tipo deducible: se guarda el resultado y se decide el tipo
    # según los valores
    temporal <- paste0("fhirviews_tmp_", paste(sample(letters, 10),
                                                collapse = ""))
    ejecutar(sprintf("CREATE TEMP TABLE %s AS %s", temporal, sql), FALSE)
    on.exit(DBI::dbExecute(con, paste("DROP TABLE IF EXISTS", temporal)),
            add = TRUE)
    for (nm in desconocidas) {
      trad$tipos[[nm]] <- detectar_tipo(con, temporal, nm,
                                        trad$colecciones[[nm]])
    }
    sql <- sprintf("SELECT %s FROM %s", paste(vapply(names(trad$tipos),
      function(nm) {
        expr <- comillas(nm)
        if (nm %in% desconocidas) {
          expr <- convertir_final(expr, trad$tipos[[nm]],
                                  trad$colecciones[[nm]])
        }
        paste(expr, "AS", comillas(nm))
      }, character(1)), collapse = ", "), temporal)
  }
  if (!is.null(tabla)) {
    if (!grepl(patron_nombre, tabla)) {
      cli::cli_abort("Nombre de tabla no v\u00e1lido: {.val {tabla}}.",
                     class = "fhirviews_error")
    }
    ejecutar(sprintf("CREATE OR REPLACE TABLE %s AS %s", comillas(tabla),
                     sql), FALSE)
    return(invisible(con))
  }
  df <- ejecutar(sql)
  for (nm in names(df)) {
    if (identical(trad$tipos[[nm]], "JSON")) {
      df[[nm]] <- json_a_r(df[[nm]], trad$colecciones[[nm]])
    }
    # Como en vista_ejecutar(): una colección vacía sin `type` es logical()
    if (isTRUE(trad$colecciones[[nm]]) && isTRUE(trad$sin_tipo[[nm]])) {
      vacias <- lengths(df[[nm]]) == 0L
      df[[nm]][vacias] <- list(logical())
    }
  }
  df
}

detectar_tipo <- function(con, tabla, columna, coleccion) {
  col <- comillas(columna)
  sql <- if (coleccion) {
    sprintf("SELECT DISTINCT json_type(x) AS t FROM (SELECT unnest(%s) AS x FROM %s)",
            col, tabla)
  } else {
    sprintf("SELECT DISTINCT json_type(%s) AS t FROM %s WHERE %s IS NOT NULL",
            col, tabla, col)
  }
  t <- DBI::dbGetQuery(con, sql)$t
  t <- setdiff(t[!is.na(t)], "NULL")
  enteros <- c("BIGINT", "UBIGINT")
  if (length(t) == 0L) return("BOOLEAN")
  if (all(t %in% "VARCHAR")) return("VARCHAR")
  if (all(t %in% "BOOLEAN")) return("BOOLEAN")
  if (all(t %in% enteros)) return("INTEGER")
  if (all(t %in% c(enteros, "DOUBLE"))) return("DOUBLE")
  if (any(t %in% c("OBJECT", "ARRAY"))) return("JSON")
  "VARCHAR"
}

# Texto JSON (objetos FHIR) a listas de R, como los devuelve vista_ejecutar()
json_a_r <- function(x, coleccion) {
  leer <- function(s) {
    if (is.na(s)) NULL else jsonlite::parse_json(s, simplifyVector = FALSE)
  }
  if (coleccion) {
    lapply(x, function(v) lapply(v, leer))
  } else {
    lapply(x, leer)
  }
}

# --- Origen de los datos ------------------------------------------------------

origen_sql <- function(desde) {
  if (!is.character(desde) || length(desde) == 0L || anyNA(desde)) {
    cli::cli_abort("{.arg desde} debe ser texto con rutas o el nombre de una tabla.",
                   class = "fhirviews_error")
  }
  es_parquet <- grepl("\\.parquet$", desde, ignore.case = TRUE)
  es_json <- grepl("\\.(nd)?json(l)?(\\.gz)?$", desde, ignore.case = TRUE)
  if (all(es_parquet)) {
    return(sprintf("(SELECT to_json(p) AS json FROM read_parquet(%s) p)",
                   lista_sql(desde)))
  }
  if (all(es_json | es_parquet) && any(es_parquet)) {
    cli::cli_abort("No se pueden mezclar archivos NDJSON y Parquet.",
                   class = "fhirviews_error")
  }
  if (all(es_json)) {
    return(sprintf(
      "read_json_objects(%s, format = 'newline_delimited')",
      lista_sql(normalizePath(desde, winslash = "/", mustWork = FALSE))
    ))
  }
  if (length(desde) == 1L && grepl(patron_nombre, desde)) {
    return(comillas(desde))
  }
  cli::cli_abort(c(
    "No se reconoce el origen {.val {desde}}.",
    "i" = "Usa archivos {.file .ndjson}, {.file .ndjson.gz} o
           {.file .parquet}, o el nombre de una tabla con una columna
           {.field json}."
  ), class = "fhirviews_error")
}

lista_sql <- function(x) {
  paste0("[", paste(texto_sql(x), collapse = ", "), "]")
}

texto_sql <- function(x) {
  paste0("'", gsub("'", "''", x, fixed = TRUE), "'")
}

comillas <- function(x) {
  paste0("\"", gsub("\"", "\"\"", x, fixed = TRUE), "\"")
}

# --- Analizador de FHIRPath --------------------------------------------------
#
# Convierte la expresión en un árbol de listas con un campo `t`:
#   lit (literal: tipo y valor), var (%nombre), this ($this), vacio ({}),
#   campo (base y nombre), llamada (base, fn y args), indice (base e i),
#   neg (a), op (op, a y b), es (op is/as, a y tipo).
# `base` es NULL cuando el campo o la función empiezan la ruta.

fp_tokens <- function(x) {
  ch <- strsplit(x, "")[[1]]
  n <- length(ch)
  i <- 1L
  tokens <- list()
  agregar <- function(tipo, valor) {
    tokens[[length(tokens) + 1L]] <<- list(tipo = tipo, valor = valor)
  }
  mientras <- function(patron) {
    j <- i
    while (j <= n && grepl(patron, ch[j])) j <- j + 1L
    j
  }
  error <- function(detalle) {
    cli::cli_abort(c("No se pudo analizar la expresi\u00f3n {.code {x}}.",
                     "x" = detalle),
                   class = c("fhirviews_error_sql", "fhirviews_error"),
                   call = NULL)
  }
  while (i <= n) {
    c1 <- ch[i]
    sig <- if (i < n) ch[i + 1L] else ""
    if (grepl("\\s", c1)) {
      i <- i + 1L
    } else if (c1 == "/" && sig == "/") {
      while (i <= n && ch[i] != "\n") i <- i + 1L
    } else if (grepl("[0-9]", c1)) {
      j <- mientras("[0-9]")
      if (j < n && ch[j] == "." && grepl("[0-9]", ch[j + 1L])) {
        j <- j + 1L
        while (j <= n && grepl("[0-9]", ch[j])) j <- j + 1L
      }
      agregar("num", paste(ch[i:(j - 1L)], collapse = ""))
      i <- j
    } else if (c1 == "'" || c1 == "`") {
      j <- i + 1L
      valor <- character()
      while (j <= n && ch[j] != c1) {
        if (ch[j] == "\\" && j < n) {
          j <- j + 1L
          e <- ch[j]
          if (e == "u" && j + 4L <= n) {
            valor <- c(valor, intToUtf8(strtoi(paste(ch[(j + 1L):(j + 4L)],
                                                     collapse = ""), 16L)))
            j <- j + 4L
          } else {
            valor <- c(valor, switch(e, n = "\n", t = "\t", r = "\r",
                                     f = "\f", e))
          }
        } else {
          valor <- c(valor, ch[j])
        }
        j <- j + 1L
      }
      if (j > n) error("Falta cerrar una cadena.")
      agregar(if (c1 == "'") "str" else "id", paste(valor, collapse = ""))
      i <- j + 1L
    } else if (c1 == "@") {
      j <- i + 1L
      while (j <= n && grepl("[0-9T:.+Z-]", ch[j])) j <- j + 1L
      if (j == i + 1L) error("Fecha mal escrita despu\u00e9s de {.code @}.")
      agregar("fecha", paste(ch[(i + 1L):(j - 1L)], collapse = ""))
      i <- j
    } else if (c1 == "%") {
      if (sig == "`" || sig == "'") {
        i <- i + 1L
        j <- i + 1L
        while (j <= n && ch[j] != sig) j <- j + 1L
        agregar("var", paste(ch[(i + 1L):(j - 1L)], collapse = ""))
        i <- j + 1L
      } else {
        i <- i + 1L
        j <- mientras("[A-Za-z0-9_]")
        if (j == i) error("Variable mal escrita despu\u00e9s de {.code %}.")
        agregar("var", paste(ch[i:(j - 1L)], collapse = ""))
        i <- j
      }
    } else if (c1 == "$") {
      i <- i + 1L
      j <- mientras("[A-Za-z]")
      agregar("dolar", paste(ch[i:(j - 1L)], collapse = ""))
      i <- j
    } else if (grepl("[A-Za-z_]", c1)) {
      j <- mientras("[A-Za-z0-9_]")
      agregar("id", paste(ch[i:(j - 1L)], collapse = ""))
      i <- j
    } else if (paste0(c1, sig) %in% c("<=", ">=", "!=", "!~")) {
      agregar("op", paste0(c1, sig))
      i <- i + 2L
    } else if (c1 %in% c("=", "~", "<", ">", "+", "-", "*", "/", "|", "&")) {
      agregar("op", c1)
      i <- i + 1L
    } else if (c1 %in% c(".", "(", ")", "[", "]", ",", "{", "}")) {
      agregar(c1, c1)
      i <- i + 1L
    } else {
      error(paste0("Car\u00e1cter inesperado: {.val ", c1, "}."))
    }
  }
  tokens
}

precedencias <- c(
  implies = 1, or = 2, xor = 2, and = 3, "in" = 4, contains = 4,
  "=" = 5, "~" = 5, "!=" = 5, "!~" = 5, "<" = 6, ">" = 6, "<=" = 6,
  ">=" = 6, "|" = 7, is = 8, as = 8, "+" = 9, "-" = 9, "&" = 9,
  "*" = 10, "/" = 10, div = 10, mod = 10
)

fp_analizar <- function(x) {
  tokens <- fp_tokens(x)
  pos <- 1L
  ver <- function() if (pos <= length(tokens)) tokens[[pos]] else NULL
  tomar <- function() {
    t <- ver()
    pos <<- pos + 1L
    t
  }
  error <- function(detalle) {
    cli::cli_abort(c("No se pudo analizar la expresi\u00f3n {.code {x}}.",
                     "x" = detalle),
                   class = c("fhirviews_error_sql", "fhirviews_error"),
                   call = NULL)
  }
  esperar <- function(tipo) {
    t <- tomar()
    if (is.null(t) || t$tipo != tipo) {
      error(paste0("Se esperaba {.code ", tipo, "}."))
    }
    t
  }
  operador <- function(t) {
    if (is.null(t)) return(NULL)
    if (t$tipo == "op" || (t$tipo == "id" && t$valor %in% names(precedencias))) {
      return(t$valor)
    }
    NULL
  }
  argumentos <- function() {
    esperar("(")
    args <- list()
    if (!identical(ver()$tipo, ")")) {
      repeat {
        args[[length(args) + 1L]] <- expresion(0)
        if (identical(ver()$tipo, ",")) {
          tomar()
        } else {
          break
        }
      }
    }
    esperar(")")
    args
  }
  nombre_tipo <- function() {
    partes <- esperar("id")$valor
    while (identical(ver()$tipo, ".")) {
      tomar()
      partes <- c(partes, esperar("id")$valor)
    }
    utils::tail(partes, 1L)
  }
  termino <- function() {
    t <- tomar()
    if (is.null(t)) error("La expresi\u00f3n termina antes de tiempo.")
    switch(t$tipo,
      num = list(t = "lit", tipo = if (grepl(".", t$valor, fixed = TRUE))
        "DOUBLE" else "BIGINT", valor = t$valor),
      str = list(t = "lit", tipo = "VARCHAR", valor = t$valor),
      fecha = list(t = "lit", tipo = "VARCHAR",
                   valor = sub("^T", "", t$valor)),
      var = list(t = "var", nombre = t$valor),
      dolar = {
        if (t$valor != "this") {
          error(paste0("{.code $", t$valor, "} no est\u00e1 disponible."))
        }
        list(t = "this")
      },
      "(" = {
        e <- expresion(0)
        esperar(")")
        e
      },
      "{" = {
        esperar("}")
        list(t = "vacio")
      },
      id = {
        if (t$valor %in% c("true", "false")) {
          list(t = "lit", tipo = "BOOLEAN", valor = t$valor)
        } else if (identical(ver()$tipo, "(")) {
          list(t = "llamada", base = NULL, fn = t$valor, args = argumentos())
        } else {
          list(t = "campo", base = NULL, nombre = t$valor)
        }
      },
      error(paste0("Elemento inesperado: {.code ", t$valor, "}."))
    )
  }
  postfijo <- function() {
    e <- termino()
    repeat {
      t <- ver()
      if (identical(t$tipo, ".")) {
        tomar()
        nombre <- esperar("id")$valor
        if (identical(ver()$tipo, "(")) {
          e <- list(t = "llamada", base = e, fn = nombre, args = argumentos())
        } else {
          e <- list(t = "campo", base = e, nombre = nombre)
        }
      } else if (identical(t$tipo, "[")) {
        tomar()
        i <- expresion(0)
        esperar("]")
        e <- list(t = "indice", base = e, i = i)
      } else {
        break
      }
    }
    e
  }
  unario <- function() {
    t <- ver()
    if (identical(t$tipo, "op") && t$valor %in% c("+", "-")) {
      tomar()
      a <- unario()
      return(if (t$valor == "-") list(t = "neg", a = a) else a)
    }
    postfijo()
  }
  expresion <- function(minimo) {
    izq <- unario()
    repeat {
      op <- operador(ver())
      if (is.null(op) || precedencias[[op]] < minimo) break
      tomar()
      if (op %in% c("is", "as")) {
        izq <- list(t = "es", op = op, a = izq, tipo = nombre_tipo())
      } else {
        der <- expresion(precedencias[[op]] + 1)
        izq <- list(t = "op", op = op, a = izq, b = der)
      }
    }
    izq
  }
  arbol <- expresion(0)
  if (pos <= length(tokens)) {
    error(paste0("Sobra texto desde {.code ", tokens[[pos]]$valor, "}."))
  }
  arbol
}

# --- Traductor de FHIRPath ----------------------------------------------------
#
# Cada expresión traducida es una lista con `sql` y `k` (clase):
#   coll: lista JSON[] (la colección de FHIRPath; vacía si no hay valores);
#   uno:  un valor JSON, o NULL si la colección está vacía;
#   val:  un valor de SQL del tipo `tipo` (BOOLEAN, VARCHAR, BIGINT o
#         DOUBLE), o NULL si está vacía.
# El contexto (ctx) tiene el foco (expresión `uno` o `coll`), el recurso
# (`r`), el índice de fila (%rowIndex), las constantes y un contador para
# nombrar variables de las funciones lambda.

coll <- function(sql) list(sql = sql, k = "coll")
uno <- function(sql) list(sql = sql, k = "uno")
val <- function(sql, tipo) list(sql = sql, k = "val", tipo = tipo)

numericos <- c("BIGINT", "DOUBLE", "INTEGER")

no_traducible <- function(detalle, .envir = parent.frame()) {
  cli::cli_abort(detalle, class = c("fhirviews_error_sql", "fhirviews_error"),
                 call = NULL, .envir = .envir)
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

a_val <- function(x, tipo, ctx) {
  if (x$k == "val") {
    if (identical(x$tipo, tipo)) return(x$sql)
    return(sprintf("TRY_CAST(%s AS %s)", x$sql, tipo))
  }
  json_a_tipo(a_uno(x, ctx), tipo)
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

# Tipos posibles de cada elemento de elección (value[x], effective[x]...)
# según el modelo FHIR R4 de fhirpath.js, juntando todos los recursos:
# list(value = c("Quantity", "CodeableConcept", "string", ...), ...)
elementos_eleccion <- function() {
  if (is.null(.fhirviews$elecciones)) {
    ct <- V8::v8()
    ct$eval("var window = globalThis;")
    cargar_js(ct, ruta_js("fhirpath", "fhirpath.r4.min.js"))
    texto <- ct$eval(paste0(
      "(function () { var m = fhirpath_r4_model.choiceTypePaths, r = {};",
      " Object.keys(m).forEach(function (k) {",
      "   var b = k.split('.').pop(); r[b] = r[b] || [];",
      "   m[k].forEach(function (t) { if (r[b].indexOf(t) < 0) r[b].push(t); });",
      " }); return JSON.stringify(r); })()"))
    .fhirviews$elecciones <- lapply(jsonlite::fromJSON(texto), as.character)
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
# todas sus variantes (valueQuantity, valueString...), como hace FHIRPath.
hijo <- function(base, nombre, ctx) {
  if (base$k == "val") {
    no_traducible("No se puede navegar a {.field {nombre}} desde un valor simple.")
  }
  variantes <- elementos_eleccion()[[nombre]]
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
  coll(sprintf("flatten(list_transform(%s, lambda %s: %s))", valores, v, caso))
}

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
  valor <- if (tipo == "BOOLEAN") tolower(as.character(valor)) else
    format(valor, scientific = FALSE, digits = 15)
  list(t = "lit", tipo = tipo, valor = valor)
}

traducir_literal <- function(n) {
  switch(n$tipo,
    VARCHAR = val(texto_sql(n$valor), "VARCHAR"),
    BOOLEAN = val(toupper(n$valor), "BOOLEAN"),
    val(sprintf("CAST(%s AS %s)", n$valor, n$tipo), n$tipo)
  )
}

fp_sql <- function(n, ctx) {
  switch(n$t,
    lit = traducir_literal(n),
    vacio = coll("[]::JSON[]"),
    this = ctx$foco,
    var = {
      nombre <- n$nombre
      if (nombre == "rowIndex") {
        val(ctx$indice, "BIGINT")
      } else if (nombre %in% c("resource", "rootResource")) {
        uno(ctx$recurso)
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
      base <- a_lista(fp_sql(n$base, ctx), ctx)
      i <- a_val(fp_sql(n$i, ctx), "BIGINT", ctx)
      uno(sprintf("list_extract(%s, %s + 1)", base, i))
    },
    neg = {
      a <- fp_sql(n$a, ctx)
      tipo <- if (a$k == "val" && a$tipo %in% numericos) a$tipo else "DOUBLE"
      val(sprintf("(-%s)", a_val(a, tipo, ctx)), tipo)
    },
    es = {
      tipo <- n$tipo
      filtrado <- fp_oftype(n$a, tipo, ctx)
      if (n$op == "as") filtrado else
        val(sprintf("(len(%s) > 0)", filtrado$sql), "BOOLEAN")
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
    return(coll(sprintf("list_distinct(list_concat(%s, %s))",
                        a_lista(a, ctx), a_lista(b, ctx))))
  }
  if (op %in% c("in", "contains")) {
    if (op == "contains") {
      tmp <- a
      a <- b
      b <- tmp
    }
    v <- nueva_var(ctx)
    lista <- sprintf("list_transform(%s, lambda %s: json_extract_string(%s, '$'))",
                     a_lista(b, ctx), v, v)
    return(val(sprintf("list_contains(%s, %s)", lista,
                       a_val(a, "VARCHAR", ctx)), "BOOLEAN"))
  }
  if (op == "&") {
    return(val(sprintf("concat(coalesce(%s, ''), coalesce(%s, ''))",
                       a_val(a, "VARCHAR", ctx), a_val(b, "VARCHAR", ctx)),
               "VARCHAR"))
  }
  texto <- (a$k == "val" && a$tipo == "VARCHAR") ||
    (b$k == "val" && b$tipo == "VARCHAR")
  if (op == "+" && texto) {
    return(val(sprintf("(%s || %s)", a_val(a, "VARCHAR", ctx),
                       a_val(b, "VARCHAR", ctx)), "VARCHAR"))
  }
  enteros <- a$k == "val" && b$k == "val" && a$tipo == "BIGINT" &&
    b$tipo == "BIGINT"
  tipo <- if (enteros && op != "/") "BIGINT" else "DOUBLE"
  simbolo <- switch(op, div = "//", mod = "%", op)
  if (op == "div") tipo <- "BIGINT"
  x <- a_val(a, if (op == "div") "DOUBLE" else tipo, ctx)
  y <- a_val(b, if (op == "div") "DOUBLE" else tipo, ctx)
  sql <- if (op == "div") {
    sprintf("CAST(trunc(%s / NULLIF(%s, 0)) AS BIGINT)", x, y)
  } else if (op %in% c("/", "mod")) {
    sprintf("(%s %s NULLIF(%s, 0))", x, simbolo, y)
  } else {
    sprintf("(%s %s %s)", x, simbolo, y)
  }
  val(sql, tipo)
}

comparar <- function(a, b, op, ctx) {
  simbolo <- switch(op, "!=" = "<>", "~" = "=", "!~" = "<>", op)
  insensible <- op %in% c("~", "!~")
  ta <- if (a$k == "val") a$tipo
  tb <- if (b$k == "val") b$tipo
  if (!is.null(ta) || !is.null(tb)) {
    tipos <- c(ta, tb)
    tipo <- if (all(tipos %in% numericos)) {
      if (length(unique(tipos)) == 1L) tipos[1] else "DOUBLE"
    } else if (length(tipos) == 2L && ta != tb) {
      "VARCHAR"
    } else {
      tipos[1]
    }
    x <- a_val(a, tipo, ctx)
    y <- a_val(b, tipo, ctx)
    if (insensible && tipo == "VARCHAR") {
      x <- sprintf("lower(trim(%s))", x)
      y <- sprintf("lower(trim(%s))", y)
    }
    return(val(sprintf("(%s %s %s)", x, simbolo, y), "BOOLEAN"))
  }
  # Dos rutas sin tipo conocido: números como números, el resto como texto
  numero <- "('BIGINT', 'UBIGINT', 'DOUBLE')"
  par <- sprintf("{'a': %s, 'b': %s}", a_uno(a, ctx), a_uno(b, ctx))
  sql <- ligar(par, function(v) {
    texto_a <- sprintf("json_extract_string(%s.a, '$')", v)
    texto_b <- sprintf("json_extract_string(%s.b, '$')", v)
    if (insensible) {
      texto_a <- sprintf("lower(trim(%s))", texto_a)
      texto_b <- sprintf("lower(trim(%s))", texto_b)
    }
    sprintf(paste0(
      "CASE WHEN json_type(%1$s.a) IN %2$s AND json_type(%1$s.b) IN %2$s ",
      "THEN TRY_CAST(%1$s.a AS DOUBLE) %3$s TRY_CAST(%1$s.b AS DOUBLE) ",
      "ELSE %4$s %3$s %5$s END"), v, numero, simbolo, texto_a, texto_b)
  }, ctx)
  val(sql, "BOOLEAN")
}

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
    variantes <- elementos_eleccion()[[base_nodo$nombre]]
    if (!is.null(variantes)) {
      if (!con_sufijo("", tipo) %in% variantes) {
        no_traducible("{.field {base_nodo$nombre}[x]} no admite el tipo {.code {tipo}}.")
      }
      nodo <- base_nodo
      nodo$nombre <- con_sufijo(base_nodo$nombre, tipo)
      return(fp_sql(nodo, ctx))
    }
  }
  if (is.null(tipos_json)) {
    no_traducible("{.code ofType({tipo})} solo se traduce sobre elementos de elecci\u00f3n (como {.code value.ofType({tipo})}) o con tipos primitivos.")
  }
  base <- if (is.null(base_nodo)) ctx$foco else fp_sql(base_nodo, ctx)
  v <- nueva_var(ctx)
  coll(sprintf("list_filter(%s, lambda %s: json_type(%s) IN (%s))",
               a_lista(base, ctx), v, v, tipos_json))
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
  if (fn == "ofType") {
    aridad(1)
    return(fp_oftype(n$base, nombre_tipo_arg(args[[1]]), ctx))
  }
  base <- if (is.null(n$base)) ctx$foco else fp_sql(n$base, ctx)
  # Contexto de las funciones que evalúan su argumento en cada elemento
  lambda <- function(cuerpo) {
    v <- nueva_var(ctx)
    ctx2 <- ctx
    ctx2$foco <- uno(v)
    ctx2$en_recurso <- FALSE
    list(v = v, x = cuerpo(ctx2))
  }
  arg <- function(i, tipo) a_val(fp_sql(args[[i]], ctx), tipo, ctx)
  texto <- function() a_val(base, "VARCHAR", ctx)
  lista <- function() a_lista(base, ctx)
  switch(fn,
    where = {
      aridad(1)
      l <- lambda(function(c2) a_bool(fp_sql(args[[1]], c2), c2))
      coll(sprintf("list_filter(%s, lambda %s: coalesce(%s, false))", lista(),
                   l$v, l$x))
    },
    select = {
      aridad(1)
      l <- lambda(function(c2) a_lista(fp_sql(args[[1]], c2), c2))
      coll(sprintf("flatten(list_transform(%s, lambda %s: %s))", lista(), l$v,
                   l$x))
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
      uno(sprintf("list_extract(%s, 1)", base$sql))
    },
    last = {
      aridad(0)
      if (base$k != "coll") return(base)
      uno(sprintf("list_extract(%s, -1)", base$sql))
    },
    single = {
      aridad(0)
      if (base$k != "coll") return(base)
      uno(a_uno(base, ctx))
    },
    tail = {
      aridad(0)
      coll(sprintf("list_slice(%s, 2, 2147483647)", lista()))
    },
    skip = {
      aridad(1)
      coll(sprintf("list_slice(%s, %s + 1, 2147483647)", lista(),
                   arg(1, "BIGINT")))
    },
    take = {
      aridad(1)
      coll(sprintf("list_slice(%s, 1, %s)", lista(), arg(1, "BIGINT")))
    },
    distinct = {
      aridad(0)
      coll(sprintf("list_distinct(%s)", lista()))
    },
    not = {
      aridad(0)
      val(sprintf("(NOT %s)", a_bool(base, ctx)), "BOOLEAN")
    },
    iif = {
      aridad(2:3)
      condicion <- a_bool(fp_sql(args[[1]], ctx), ctx)
      si <- a_lista(fp_sql(args[[2]], ctx), ctx)
      no <- if (narg == 3L) a_lista(fp_sql(args[[3]], ctx), ctx) else
        "[]::JSON[]"
      coll(sprintf("CASE WHEN coalesce(%s, false) THEN %s ELSE %s END",
                   condicion, si, no))
    },
    join = {
      aridad(0:1)
      separador <- if (narg == 1L) arg(1, "VARCHAR") else "''"
      sql <- ligar(lista(), function(l) {
        w <- nueva_var(ctx)
        sprintf(paste0(
          "CASE WHEN len(%1$s) = 0 THEN NULL ELSE array_to_string(",
          "list_transform(%1$s, lambda %2$s: json_extract_string(%2$s, '$')), %3$s) END"),
          l, w, separador)
      }, ctx)
      val(sql, "VARCHAR")
    },
    extension = {
      aridad(1)
      url <- arg(1, "VARCHAR")
      v <- nueva_var(ctx)
      coll(sprintf("list_filter(%s, lambda %s: json_extract_string(%s, '$.url') = %s)",
                   hijo(base, "extension", ctx)$sql, v, v, url))
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
                   partes, p, condicion, q, q))
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
      val(sprintf("regexp_matches(%s, %s)", texto(), arg(1, "VARCHAR")),
          "BOOLEAN")
    },
    upper = {
      aridad(0)
      val(sprintf("upper(%s)", texto()), "VARCHAR")
    },
    lower = {
      aridad(0)
      val(sprintf("lower(%s)", texto()), "VARCHAR")
    },
    trim = {
      aridad(0)
      val(sprintf("trim(%s)", texto()), "VARCHAR")
    },
    length = {
      aridad(0)
      val(sprintf("CAST(length(%s) AS BIGINT)", texto()), "BIGINT")
    },
    toString = {
      aridad(0)
      val(texto(), "VARCHAR")
    },
    toInteger = {
      aridad(0)
      val(a_val(base, "BIGINT", ctx), "BIGINT")
    },
    toDecimal = {
      aridad(0)
      val(a_val(base, "DOUBLE", ctx), "DOUBLE")
    },
    substring = {
      aridad(1:2)
      inicio <- arg(1, "BIGINT")
      sql <- if (narg == 1L) {
        sprintf("substring(%s, %s + 1)", texto(), inicio)
      } else {
        sprintf("substring(%s, %s + 1, %s)", texto(), inicio, arg(2, "BIGINT"))
      }
      val(sql, "VARCHAR")
    },
    replace = {
      aridad(2)
      val(sprintf("replace(%s, %s, %s)", texto(), arg(1, "VARCHAR"),
                  arg(2, "VARCHAR")), "VARCHAR")
    },
    no_traducible("La funci\u00f3n {.code {fn}()} no est\u00e1 en el subconjunto de FHIRPath que se traduce a SQL.")
  )
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

# --- Traductor del ViewDefinition --------------------------------------------
#
# Cada select se traduce en una expresión que da la lista de filas (una
# lista de STRUCT con una clave por columna) para el foco actual. Las partes
# de un select se combinan con un producto dentro de cada foco, forEach
# recorre la colección con list_transform (con el índice para %rowIndex) y
# unionAll concatena las listas. La consulta final hace unnest de las filas
# de cada recurso.

traducir_vista <- function(vista, desde) {
  constantes <- list()
  for (k in vista$constant) {
    constantes[[k$name]] <- literal_constante(k)
  }
  defs <- definiciones_columnas(vista)
  colecciones <- lapply(defs, function(d) isTRUE(d$collection))
  modelo <- tipos_modelo(vista)
  nuevo_ctx <- function() {
    list(foco = uno("r"), recurso = "r", indice = "0",
         constantes = constantes, tipo_recurso = vista$resource,
         en_recurso = TRUE, n = new.env(parent = emptyenv()))
  }

  # Primera pasada: el tipo de cada columna, que debe ser el mismo en todas
  # las ramas de unionAll
  candidatos <- list()
  anotar <- function(nombre, tipo) {
    candidatos[[nombre]] <<- c(candidatos[[nombre]], tipo)
  }
  ctx <- nuevo_ctx()
  ctx$n$i <- 0L
  traducir_partes(list(select = vista$select), ctx, tipos = NULL,
                  anotar = anotar, modelo = modelo)
  tipos <- lapply(names(candidatos), function(nm) {
    t <- unique(candidatos[[nm]])
    if (length(t) == 1L) t else if (all(t %in% numericos)) "DOUBLE" else
      NA_character_
  })
  names(tipos) <- names(candidatos)

  ctx <- nuevo_ctx()
  ctx$n$i <- 0L
  filas <- traducir_partes(list(select = vista$select), ctx, tipos = tipos,
                           anotar = NULL, modelo = modelo)
  filas_sql <- partes_a_lista(filas)
  nombres <- filas$nombres

  condiciones <- sprintf("json_extract_string(r, '$.resourceType') = %s",
                         texto_sql(vista$resource))
  for (w in vista$where) {
    x <- traducir_expresion(w$path, ctx)
    condiciones <- c(condiciones, condicion_where(x, w$path, ctx))
  }
  sql <- sprintf(paste0(
    "SELECT %s\nFROM (\n  SELECT unnest(%s) AS f\n",
    "  FROM (SELECT json AS r FROM %s)\n  WHERE %s\n)"),
    paste(sprintf("f.%s AS %s", comillas(nombres), comillas(nombres)),
          collapse = ", "),
    filas_sql, desde, paste(condiciones, collapse = "\n    AND "))
  tipos <- tipos[nombres]
  names(tipos) <- nombres
  sin_tipo <- vapply(defs, function(d) is.null(d$type), logical(1))
  list(sql = structure(sql, class = "fhir_sql"), tipos = tipos,
       colecciones = colecciones[nombres], sin_tipo = sin_tipo[nombres])
}

condicion_where <- function(x, expresion, ctx) {
  if (x$k == "val") {
    if (x$tipo != "BOOLEAN") {
      cli::cli_abort(
        "La condici\u00f3n {.code {expresion}} debe devolver verdadero o falso.",
        class = c("fhirviews_error_vista", "fhirviews_error"), call = NULL)
    }
    return(sprintf("coalesce(%s, false)", x$sql))
  }
  mensaje <- paste0("La condici\u00f3n ", expresion,
                    " debe devolver verdadero o falso")
  ligar(a_uno(x, ctx, mensaje), function(u) {
    sprintf(paste0(
      "CASE WHEN %1$s IS NULL THEN false WHEN json_type(%1$s) = 'BOOLEAN' ",
      "THEN CAST(%1$s AS BOOLEAN) ELSE error(%2$s) END"), u, texto_sql(mensaje))
  }, ctx)
}

# Tipo de SQL de un `type` de FHIR o de la clase de una expresión
tipo_sql_fhir <- function(tipo) {
  if (is.null(tipo) || is.na(tipo)) return(NA_character_)
  if (tipo %in% tipos_logicos) return("BOOLEAN")
  if (tipo %in% tipos_enteros) return("INTEGER")
  if (tipo == "integer64") return("BIGINT")
  if (tipo %in% tipos_decimales) return("DOUBLE")
  if (grepl("^[a-z]", tipo)) return("VARCHAR")
  "JSON"
}

tipo_columna <- function(cl, x, modelo) {
  if (!is.null(cl$type)) return(tipo_sql_fhir(cl$type))
  if (x$k == "val") {
    return(if (x$tipo == "BIGINT") "INTEGER" else x$tipo)
  }
  tipo_sql_fhir(modelo[[cl$name]])
}

# Valor final de una columna a partir de la expresión traducida
valor_columna <- function(x, tipo, coleccion, nombre, ctx) {
  destino <- if (is.na(tipo)) "JSON" else tipo
  if (coleccion) {
    v <- nueva_var(ctx)
    if (destino == "JSON") return(a_lista(x, ctx))
    return(sprintf("list_transform(%s, lambda %s: %s)", a_lista(x, ctx), v,
                   json_a_tipo(v, destino)))
  }
  if (x$k == "val") {
    if (destino == "JSON") return(sprintf("to_json(%s)", x$sql))
    if (identical(x$tipo, destino)) return(x$sql)
    return(sprintf("TRY_CAST(%s AS %s)", x$sql, destino))
  }
  mensaje <- paste0("La columna ", nombre, " devolvi\u00f3 varios valores para ",
                    "una fila; usa collection: true o first()")
  json_a_tipo(a_uno(x, ctx, mensaje), destino)
}

convertir_final <- function(expr, tipo, coleccion) {
  if (tipo == "JSON") return(expr)
  if (coleccion) {
    return(sprintf("list_transform(%s, lambda q: %s)", expr,
                   json_a_tipo("q", tipo)))
  }
  json_a_tipo(expr, tipo)
}

# Una parte es list(campos = vector con nombre de expresiones de una sola
# fila) o list(lista = expresión con la lista de filas); ambas con `nombres`.
traducir_partes <- function(s, ctx, tipos, anotar, modelo) {
  partes <- list()
  if (!is.null(s$column)) {
    campos <- character()
    for (cl in s$column) {
      x <- traducir_expresion(cl$path, ctx)
      tipo <- tipo_columna(cl, x, modelo)
      if (!is.null(anotar)) {
        anotar(cl$name, tipo)
        campos[cl$name] <- "NULL"
      } else {
        campos[cl$name] <- valor_columna(x, tipos[[cl$name]],
                                         isTRUE(cl$collection), cl$name, ctx)
      }
    }
    partes <- c(partes, list(list(campos = campos, nombres = names(campos))))
  }
  for (sub in s$select) {
    partes <- c(partes, list(traducir_select(sub, ctx, tipos, anotar, modelo)))
  }
  if (!is.null(s$unionAll)) {
    ramas <- lapply(s$unionAll, function(r) {
      traducir_select(r, ctx, tipos, anotar, modelo)
    })
    listas <- vapply(ramas, partes_a_lista, character(1))
    sql <- Reduce(function(a, b) sprintf("list_concat(%s, %s)", a, b), listas)
    partes <- c(partes, list(list(lista = sql, nombres = ramas[[1]]$nombres)))
  }
  producto_partes(partes, ctx)
}

traducir_select <- function(s, ctx, tipos, anotar, modelo) {
  repetir <- s[["repeat"]]
  expresion <- s$forEach %||% s$forEachOrNull
  if (is.null(expresion) && is.null(repetir)) {
    return(traducir_partes(s, ctx, tipos, anotar, modelo))
  }
  if (!is.null(repetir)) {
    coleccion <- descendientes_sql(unlist(repetir), ctx)
  } else {
    coleccion <- a_lista(traducir_expresion(expresion, ctx), ctx)
    if (!is.null(s$forEachOrNull)) {
      coleccion <- sprintf("coalesce(nullif(%s, []::JSON[]), [NULL::JSON])",
                           coleccion)
    }
  }
  v <- nueva_var(ctx)
  i <- nueva_var(ctx)
  ctx2 <- ctx
  ctx2$foco <- uno(v)
  ctx2$en_recurso <- FALSE
  ctx2$indice <- sprintf("(%s - 1)", i)
  interior <- traducir_partes(s, ctx2, tipos, anotar, modelo)
  list(lista = sprintf("flatten(list_transform(%s, lambda %s, %s: %s))",
                       coleccion, v, i, partes_a_lista(interior)),
       nombres = interior$nombres)
}

# Recorrido en preorden de repeat. Se calcula por niveles (cada nivel
# una sola vez, ligado a una variable lambda) y cada nodo lleva una clave con
# las posiciones (ruta, hijo) desde el foco; ordenar por esa clave da el
# preorden. La profundidad es fija: si los datos tienen más niveles, error.
descendientes_sql <- function(rutas, ctx) {
  limite <- getOption("fhirviews.sql_profundidad", 12L)
  arboles <- lapply(rutas, fp_analizar)
  hijos <- function(nivel) {
    p <- nueva_var(ctx)
    ctx2 <- ctx
    ctx2$foco <- uno(sprintf("%s.n", p))
    ctx2$en_recurso <- FALSE
    por_ruta <- vapply(seq_along(arboles), function(j) {
      c1 <- nueva_var(ctx)
      i1 <- nueva_var(ctx)
      sprintf("list_transform(%s, lambda %s, %s: {'k': list_concat(%s.k, [%d, %s]), 'n': %s})",
              a_lista(fp_sql(arboles[[j]], ctx2), ctx2), c1, i1, p, j, i1, c1)
    }, character(1))
    juntos <- Reduce(function(a, b) sprintf("list_concat(%s, %s)", a, b),
                     por_ruta)
    sprintf("flatten(list_transform(%s, lambda %s: %s))", nivel, p, juntos)
  }
  mensaje <- paste0("repeat tiene m\u00e1s de ", limite, " niveles; sube ",
                    "options(fhirviews.sql_profundidad) o usa vista_ejecutar()")
  # Cada nivel se calcula a partir del anterior en posición de argumento
  # (anidar lambdas encarece mucho el enlazado en DuckDB)
  inicio <- sprintf("[{'k': []::INTEGER[], 'n': %s}]", a_uno(ctx$foco, ctx))
  niveles <- character()
  anterior <- inicio
  todos <- tryCatch({
    for (d in seq_len(limite)) {
      anterior <- hijos(anterior)
      niveles <- c(niveles, anterior)
    }
    control <- sprintf("CASE WHEN len(%s) > 0 THEN error(%s) ELSE [] END",
                       hijos(anterior), texto_sql(mensaje))
    Reduce(function(a, b) sprintf("list_concat(%s, %s)", a, b),
           c(niveles, control))
  }, fhirviews_error_sql = function(e) {
    cli::cli_abort(c(
      "No se puede traducir {.code repeat} a SQL.",
      "x" = "{limpiar_mensaje(conditionMessage(e))}",
      "i" = "Usa {.fn vista_ejecutar}."
    ), class = c("fhirviews_error_sql", "fhirviews_error"), call = NULL)
  })
  x <- nueva_var(ctx)
  sprintf("list_transform(list_sort(%s), lambda %s: %s.n)", todos, x, x)
}

struct_sql <- function(campos) {
  paste0("{", paste(sprintf("%s: %s", texto_sql(names(campos)), campos),
                    collapse = ", "), "}")
}

partes_a_lista <- function(p) {
  if (!is.null(p$lista)) p$lista else sprintf("[%s]", struct_sql(p$campos))
}

producto_partes <- function(partes, ctx) {
  if (length(partes) == 0L) {
    return(list(campos = character(), nombres = character()))
  }
  acc <- partes[[1]]
  for (p in partes[-1]) {
    nombres <- c(acc$nombres, p$nombres)
    if (!is.null(acc$campos) && !is.null(p$campos)) {
      acc <- list(campos = c(acc$campos, p$campos), nombres = nombres)
      next
    }
    a <- nueva_var(ctx)
    b <- nueva_var(ctx)
    de <- function(var, parte) {
      if (!is.null(parte$campos)) return(parte$campos)
      stats::setNames(sprintf("%s.%s", var, comillas(parte$nombres)),
                      parte$nombres)
    }
    fila <- struct_sql(c(de(a, acc), de(b, p)))
    sql <- if (!is.null(acc$campos)) {
      sprintf("list_transform(%s, lambda %s: %s)", p$lista, b, fila)
    } else if (!is.null(p$campos)) {
      sprintf("list_transform(%s, lambda %s: %s)", acc$lista, a, fila)
    } else {
      sprintf("flatten(list_transform(%s, lambda %s: list_transform(%s, lambda %s: %s)))",
              acc$lista, a, p$lista, b, fila)
    }
    acc <- list(lista = sql, nombres = nombres)
  }
  acc
}

# Tipo FHIR de cada columna sin `type` según el modelo R4 (como
# inferir_tipos(), pero también para las columnas con collection: true)
tipos_modelo <- function(vista) {
  motor <- tryCatch(motor_actual(), error = function(e) NULL)
  if (is.null(motor)) {
    return(list())
  }
  tipos <- list()
  visitar <- function(s, ctx) {
    iteracion <- s$forEach %||% s$forEachOrNull %||% s[["repeat"]][[1]]
    if (!is.null(ctx) && !is.null(iteracion)) {
      ctx <- tryCatch(motor$tipo(ctx, iteracion), error = function(e) NULL)
    }
    for (cl in s$column) {
      if (!is.null(ctx) && is.null(cl$type)) {
        t <- tryCatch(motor$tipo(ctx, cl$path)$tipo, error = function(e) NULL)
        if (!is.null(t)) tipos[[cl$name]] <<- t
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
