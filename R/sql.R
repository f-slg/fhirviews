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
#' `where`, `constant` y `%rowIndex`) y buena parte de FHIRPath:
#' navegación por campos (los elementos de elección como `value` o
#' `effective` buscan sus variantes `valueQuantity`, `valueString`...),
#' índices (`name[0]`), `where()`, `select()`, `exists()`, `empty()`,
#' `all()`, `allTrue()` y afines, `count()`, `first()`, `last()`, `tail()`,
#' `skip()`, `take()`, `single()`, `distinct()`, `isDistinct()`,
#' `union()`/`|`, `combine()`, `intersect()`, `exclude()`, `subsetOf()`,
#' `supersetOf()`, `in`, `contains`, `not()`, `iif()`, `trace()`, `is`,
#' `as`, `ofType()`, `extension(url)`, `getResourceKey()`,
#' `getReferenceKey()`, funciones de texto (`join()`, `startsWith()`,
#' `endsWith()`, `contains()`, `indexOf()`, `substring()`, `upper()`,
#' `lower()`, `trim()`, `length()`, `replace()`, `matches()`,
#' `replaceMatches()`, `split()`, `toChars()`), conversiones (`toString()`,
#' `toInteger()`, `toDecimal()`, `toBoolean()` y sus `convertsTo...()`),
#' aritmética, `abs()`, `ceiling()`, `floor()`, `round()`, `truncate()`,
#' `sqrt()`, `power()` exacta, comparaciones de fechas y horas con su
#' precisión y `lowBoundary()`/`highBoundary()` de fechas y horas.
#'
#' La traducción reproduce el resultado de `fhirpath.js`
#' ([vista_ejecutar()]). Si una expresión usa algo que no se puede traducir
#' con certeza, se produce un error de clase `fhirviews_error_sql` que
#' sugiere usar [vista_ejecutar()]; lo que solo se puede decidir con los
#' datos (por ejemplo, comparar una fecha sin hora con una fecha y hora, que
#' depende de la zona horaria del equipo, o textos con caracteres que DuckDB
#' y JavaScript pasan a mayúsculas de forma distinta) da un error al
#' ejecutar la consulta, nunca un resultado distinto.
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
#'   que acepte [fhir_recursos()], incluidos texto JSON y archivos `.json`
#'   con un recurso o un Bundle (que se escriben antes en un archivo NDJSON
#'   temporal).
#' @param vista Un `ViewDefinition` en cualquier forma que acepte
#'   [vista_leer()].
#' @param con_db Conexión DBI a DuckDB. Si es `NULL` (por defecto), se usa
#'   una base en memoria.
#' @param tabla Nombre opcional de una tabla de `con_db` donde guardar el
#'   resultado en lugar de traerlo a R; útil con resultados muy grandes.
#' @param diferido Si es `TRUE`, no ejecuta la vista: devuelve una tabla
#'   diferida de dplyr (`tbl_dbi` de dbplyr) sobre la consulta, para filtrar,
#'   agrupar y resumir con dplyr dentro de DuckDB y traer a R solo el
#'   resultado con [dplyr::collect()]. Requiere los paquetes dplyr y dbplyr.
#'   Cada vez que se usa la tabla, DuckDB vuelve a leer los archivos.
#'
#' @details
#' Con `diferido = TRUE` la tabla queda unida a la conexión: si `con_db` es
#' `NULL` se crea una que sigue abierta mientras exista la tabla (ciérrala
#' con `DBI::dbDisconnect(dbplyr::remote_con(tabla))` al terminar), y si
#' `archivos` son recursos de R, el archivo temporal se borra al cerrar la
#' sesión de R. Las columnas sin tipo deducible se convierten según los
#' valores, lo que obliga a recorrer los datos una vez al crear la tabla.
#' Al traer los datos con [dplyr::collect()], los elementos complejos (como
#' `name.first()`) llegan como texto JSON y las colecciones como listas de
#' DuckDB, no como las listas de R de [vista_ejecutar()].
#'
#' @return Un `data.frame` como el de [vista_ejecutar()]; si se indica
#'   `tabla`, la conexión DBI de forma invisible; con `diferido = TRUE`, una
#'   tabla diferida de dbplyr.
#' @export
#' @examplesIf requireNamespace("duckdb", quietly = TRUE) && interactive()
#' archivo <- system.file("extdata", "caso_clinico.ndjson",
#'                        package = "fhirviews")
#' vista <- vista_crear("Patient", c(sexo = "gender", nacimiento = "birthDate"))
#' vista_ejecutar_duckdb(archivo, vista)
#' @examplesIf requireNamespace("duckdb", quietly = TRUE) && requireNamespace("dbplyr", quietly = TRUE) && interactive()
#' # Resultado diferido: el resumen se calcula en DuckDB
#' pacientes <- vista_ejecutar_duckdb(archivo, vista, diferido = TRUE)
#' dplyr::count(pacientes, sexo) |> dplyr::collect()
#' DBI::dbDisconnect(dbplyr::remote_con(pacientes))
vista_ejecutar_duckdb <- function(archivos, vista, con_db = NULL,
                                  tabla = NULL, diferido = FALSE) {
  rlang::check_installed(c("DBI", "duckdb"),
                         reason = "para ejecutar vistas con DuckDB.")
  if (!rlang::is_bool(diferido)) {
    cli::cli_abort("{.arg diferido} debe ser {.code TRUE} o {.code FALSE}.",
                   class = "fhirviews_error")
  }
  if (diferido) {
    rlang::check_installed(c("dplyr", "dbplyr"),
                           reason = "para devolver una tabla diferida.")
    if (!is.null(tabla)) {
      cli::cli_abort("Usa {.arg tabla} o {.code diferido = TRUE}, no los dos.",
                     class = "fhirviews_error")
    }
  }
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
    if (is.null(tabla) && !diferido) {
      on.exit(DBI::dbDisconnect(con_db), add = TRUE)
    }
  }
  cargar_json_duckdb(con_db)
  if (!is.character(archivos) || son_recursos_texto(archivos)) {
    archivos <- escribir_ndjson_temporal(archivos)
    if (!diferido) on.exit(unlink(archivos), add = TRUE)
  }
  trad <- traducir_vista(vista, origen_sql(archivos))
  if (diferido) {
    final <- sql_final(con_db, trad, sprintf("(%s)", unclass(trad$sql)))
    return(dplyr::tbl(con_db, dplyr::sql(final$sql)))
  }
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

# Texto que vista_ejecutar_duckdb() lee con fhir_recursos() y no como rutas
# de DuckDB: texto JSON o archivos .json (que pueden ser un Bundle o un
# recurso con varias líneas, no NDJSON)
son_recursos_texto <- function(x) {
  if (length(x) == 0L || anyNA(x)) {
    return(FALSE)
  }
  if (any(grepl("^\\s*[[{]", x))) {
    return(TRUE)
  }
  all(grepl("\\.json$", x, ignore.case = TRUE)) &&
    !any(grepl("[*?[]", x)) && all(file.exists(x))
}

escribir_ndjson_temporal <- function(recursos) {
  recursos <- fhir_recursos(recursos)
  fuente <- fuente_alineada(recursos)
  if (!is.null(fuente)) {
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
  sql <- unclass(trad$sql)
  if (any(vapply(trad$tipos, is.na, logical(1)))) {
    # Columnas sin tipo deducible: se guarda el resultado y se decide el tipo
    # según los valores
    # tempfile() no usa el generador de números aleatorios de R, así que no
    # altera .Random.seed
    temporal <- gsub("[^A-Za-z0-9_]", "_",
                     basename(tempfile("fhirviews_tmp_")))
    ejecutar(sprintf("CREATE TEMP TABLE %s AS %s", temporal, sql), FALSE)
    on.exit(DBI::dbExecute(con, paste("DROP TABLE IF EXISTS", temporal)),
            add = TRUE)
    final <- sql_final(con, trad, temporal)
    sql <- final$sql
    trad$tipos <- final$tipos
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
    # y una columna sin tipo del `type` ni del modelo, toda vacía, es lógica
    if (!isTRUE(trad$colecciones[[nm]]) && isTRUE(trad$sin_tipo[[nm]]) &&
        !nm %in% trad$con_modelo && is.atomic(df[[nm]]) &&
        all(is.na(df[[nm]]))) {
      df[[nm]] <- as.logical(df[[nm]])
    }
  }
  df
}

# Consulta final: las columnas sin tipo deducible se convierten según los
# valores de `fuente` (una tabla o una subconsulta entre paréntesis).
# Devuelve list(sql, tipos).
sql_final <- function(con, trad, fuente) {
  desconocidas <- names(trad$tipos)[vapply(trad$tipos, is.na, logical(1))]
  if (length(desconocidas) == 0L) {
    return(list(sql = unclass(trad$sql), tipos = trad$tipos))
  }
  if (startsWith(fuente, "(")) fuente <- paste(fuente, "AS fhirviews_vista")
  for (nm in desconocidas) {
    trad$tipos[[nm]] <- tryCatch(
      detectar_tipo(con, fuente, nm, trad$colecciones[[nm]]),
      error = function(e) {
        cli::cli_abort(c(
          "DuckDB no pudo ejecutar la vista.",
          "x" = "{limpiar_mensaje(conditionMessage(e))}"
        ), class = c("fhirviews_error_vista", "fhirviews_error"), call = NULL)
      })
  }
  sql <- sprintf("SELECT %s FROM %s", paste(vapply(names(trad$tipos),
    function(nm) {
      expr <- comillas(nm)
      if (nm %in% desconocidas) {
        expr <- convertir_final(expr, trad$tipos[[nm]], trad$colecciones[[nm]])
      }
      paste(expr, "AS", comillas(nm))
    }, character(1)), collapse = ", "), fuente)
  list(sql = sql, tipos = trad$tipos)
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
  if (all(t %in% c(enteros, "DOUBLE"))) {
    # Como en vista_ejecutar(): si todos son enteros (3.0 es 3), entero
    valores <- if (coleccion) {
      sprintf("SELECT CAST(x AS DOUBLE) AS v FROM (SELECT unnest(%s) AS x FROM %s)",
              col, tabla)
    } else {
      sprintf("SELECT CAST(%s AS DOUBLE) AS v FROM %s", col, tabla)
    }
    enteros_sql <- sprintf(
      "SELECT coalesce(bool_and(v = trunc(v) AND abs(v) <= 2147483647), true) AS e FROM (%s) WHERE v IS NOT NULL",
      valores)
    return(if (isTRUE(DBI::dbGetQuery(con, enteros_sql)$e)) "INTEGER" else
      "DOUBLE")
  }
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
      while (j <= n && grepl("[0-9T:.+Z-]", ch[j]) &&
             !(ch[j] == "." && (j == n || !grepl("[0-9]", ch[j + 1L])))) {
        j <- j + 1L
      }
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
      fecha = {
        hora <- startsWith(t$valor, "T")
        valor <- sub("T$", "", sub("^T", "", t$valor))
        patron <- if (hora) re_hora else re_fecha
        if (!grepl(patron, valor, perl = TRUE)) {
          error(paste0("Fecha u hora mal escrita: {.code @", t$valor, "}."))
        }
        list(t = "lit", tipo = "VARCHAR", valor = valor,
             clase = if (hora) "hora" else "fecha")
      },
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
    list(foco = uno("r", info = list(tipos = vista$resource,
                                     ruta = vista$resource)),
         recurso = "r", indice = "0",
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
  # Columnas a las que vista_ejecutar() da el tipo del modelo
  con_modelo <- names(modelo)[vapply(modelo, function(t) grepl("^[a-z]", t),
                                     logical(1))]
  list(sql = structure(sql, class = "fhir_sql"), tipos = tipos,
       colecciones = colecciones[nombres], sin_tipo = sin_tipo[nombres],
       con_modelo = con_modelo)
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
    if (x$tipo == "DOUBLE") {
      # vista_ejecutar() deja como enteros los números sin decimales si el
      # modelo no da el tipo: se decide según los valores
      return(tipo_sql_fhir(modelo[[cl$name]]))
    }
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
  foco <- uno("")
  if (!is.null(repetir)) {
    coleccion <- descendientes_sql(unlist(repetir), ctx)
    foco$info <- info_repeat(unlist(repetir), ctx)
  } else {
    x <- traducir_expresion(expresion, ctx)
    foco <- uno("", info = x$info, cadena = clase_cadena(x))
    coleccion <- a_lista(x, ctx)
    if (!is.null(s$forEachOrNull)) {
      coleccion <- sprintf("coalesce(nullif(%s, []::JSON[]), [NULL::JSON])",
                           coleccion)
    }
  }
  v <- nueva_var(ctx)
  i <- nueva_var(ctx)
  ctx2 <- ctx
  foco$sql <- v
  ctx2$foco <- foco
  ctx2$en_recurso <- FALSE
  ctx2$indice <- sprintf("(%s - 1)", i)
  interior <- traducir_partes(s, ctx2, tipos, anotar, modelo)
  list(lista = sprintf("flatten(list_transform(%s, lambda %s, %s: %s))",
                       coleccion, v, i, partes_a_lista(interior)),
       nombres = interior$nombres)
}

# Tipo FHIR de los nodos de repeat: el que dan las rutas desde el foco, si
# es el mismo en el primer nivel y en el siguiente
info_repeat <- function(rutas, ctx) {
  ctx_tmp <- ctx
  ctx_tmp$n <- new.env(parent = emptyenv())
  ctx_tmp$n$i <- 0L
  ctx_tmp$en_recurso <- FALSE
  infos <- tryCatch(lapply(rutas, function(r) {
    arbol <- fp_analizar(r)
    uno_nivel <- fp_sql(arbol, ctx_tmp)$info
    ctx_tmp$foco <- uno("x", info = uno_nivel)
    list(uno_nivel, fp_sql(arbol, ctx_tmp)$info)
  }), error = function(e) NULL)
  if (is.null(infos)) return(NULL)
  todas <- unlist(infos, recursive = FALSE)
  if (all(vapply(todas, identical, logical(1), todas[[1]]))) todas[[1]]
}

# Recorrido en preorden de repeat. Se calcula por niveles (cada nivel
# una sola vez, ligado a una variable lambda) y cada nodo lleva una clave con
# las posiciones (ruta, hijo) desde el foco; ordenar por esa clave da el
# preorden. La profundidad es fija: si los datos tienen más niveles, error.
descendientes_sql <- function(rutas, ctx) {
  limite <- getOption("fhirviews.sql_profundidad", 12L)
  arboles <- lapply(rutas, fp_analizar)
  info_nodos <- info_repeat(rutas, ctx)
  hijos <- function(nivel, info = info_nodos) {
    p <- nueva_var(ctx)
    ctx2 <- ctx
    ctx2$foco <- uno(sprintf("%s.n", p), info = info)
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
      anterior <- hijos(anterior, if (d == 1L) ctx$foco$info else info_nodos)
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
