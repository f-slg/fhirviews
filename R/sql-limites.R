# Limites decimales: json_extract() normaliza 1.00 a 1.0. Relacionamos los
# tokens numericos originales con las rutas de json_tree(), en su orden
# documental. Las cadenas JSON completas forman un token y se excluyen:
# numeros dentro de texto, nombres de campos o escapes no se confunden.
# Se calculan estas columnas solo para vistas que las necesitan.
origen_decimales_sql <- function(desde) {
  patron <- '"([^"\\\\]|\\\\.)*"|-?(0|[1-9][0-9]*)(\\.[0-9]+)?([eE][+-]?[0-9]+)?'
  sprintf(paste0(
    "(SELECT r, list_filter(regexp_extract_all(CAST(r AS VARCHAR), %s), ",
    "lambda t: NOT starts_with(t, '\"')) AS sof_numeros, ",
    "(SELECT list(fullkey ORDER BY id) FROM json_tree(r) ",
    "WHERE type IN ('BIGINT', 'UBIGINT', 'DOUBLE')) AS sof_rutas ",
    "FROM (SELECT json AS r FROM %s))"), texto_sql(patron), desde)
}

# Rutas estaticas desde la raiz, con indices explicitos. Las iteraciones,
# filtros y operaciones que cambian el valor no conservan esta identidad;
# se rechazan en lugar de adivinar la escala del numero resultante.
ruta_decimal_sql <- function(n, ctx) {
  raiz <- function() list(ruta = "$", info = list(tipos = ctx$tipo_recurso,
                                                  ruta = ctx$tipo_recurso))
  if (is.null(n) || n$t == "this") {
    if (ctx$en_recurso) return(raiz())
    return(NULL)
  }
  if (n$t == "var" && n$nombre %in% c("resource", "rootResource")) return(raiz())
  if (n$t == "campo") {
    if (is.null(n$base) && n$nombre == ctx$tipo_recurso && ctx$en_recurso) return(raiz())
    padre <- ruta_decimal_sql(n$base, ctx)
    if (is.null(padre) || !is.null(padre$eleccion)) return(NULL)
    info <- modelo_hijo(padre$info, n$nombre)
    if (is.null(info)) return(NULL)
    if (isTRUE(info$eleccion)) {
      return(list(ruta = padre$ruta, info = info, eleccion = n$nombre))
    }
    return(list(ruta = paste0(padre$ruta, ".", n$nombre), info = info))
  }
  if (n$t == "llamada" && n$fn %in% c("ofType", "as") && length(n$args) == 1L) {
    padre <- ruta_decimal_sql(n$base, ctx)
    if (is.null(padre)) return(NULL)
    tipo <- nombre_tipo_arg(n$args[[1]])
    if (!is.null(padre$eleccion)) {
      if (!tipo %in% padre$info$tipos) return(NULL)
      padre$ruta <- paste0(padre$ruta, ".", con_sufijo(padre$eleccion, tipo))
      padre$eleccion <- NULL
    }
    padre$info <- list(tipos = tipo, ruta = tipo)
    return(padre)
  }
  if (n$t == "indice" && n$i$t == "lit" && n$i$tipo == "BIGINT") {
    padre <- ruta_decimal_sql(n$base, ctx)
    if (is.null(padre)) return(NULL)
    padre$ruta <- paste0(padre$ruta, "[", n$i$valor, "]")
    return(padre)
  }
  NULL
}

limite_decimal_sql <- function(n, base, alto, ctx) {
  literal <- if (!is.null(n) && n$t == "lit" && n$tipo %in% numericos) n$valor
  if (!is.null(literal)) {
    raw <- texto_sql(literal)
  } else {
    ruta <- ruta_decimal_sql(n, ctx)
    if (is.null(ruta) || !is.null(ruta$eleccion)) {
      no_traducible(paste("Los limites decimales requieren un literal o una ruta",
                         "desde el recurso con indices explicitos; no se infiere",
                         "la escala despues de operaciones o iteraciones."))
    }
    ctx$n$decimales <- TRUE
    # Dos propiedades numericas con el mismo nombre no son JSON FHIR valido.
    raw <- sprintf(paste0("CASE WHEN len(sof_numeros) <> len(sof_rutas) OR ",
      "len(sof_rutas) <> len(list_distinct(sof_rutas)) THEN %s ",
      "ELSE list_extract(sof_numeros, list_position(sof_rutas, %s)) END"),
      error_sql("JSON numerico ambiguo"), texto_sql(ruta$ruta))
  }
  # Comprueba tipo y cardinalidad de la expresion original, ademas de la
  # existencia de su literal. Esto detecta rutas con arreglos sin indice.
  numero <- a_val(base, "DOUBLE", ctx, estricto = "limite decimal")
  par <- sprintf("{'raw': %s, 'numero': %s}", raw, numero)
  sql <- ligar(par, function(v) {
    escala <- sprintf(paste0("length(regexp_extract(%1$s.raw, '\\.([0-9]+)', 1)) - ",
      "coalesce(TRY_CAST(nullif(regexp_extract(%1$s.raw, '[eE]([+-]?[0-9]+)', 1), '') AS INTEGER), 0)"), v)
    ligar(escala, function(p) {
      delta <- sprintf(paste0("CAST(CASE WHEN %1$s < 0 THEN ",
        "'5' || repeat('0', greatest(0, least(18, -%1$s - 1))) ELSE ",
        "'0.' || repeat('0', greatest(0, least(8, %1$s))) || '5' END AS DECIMAL(38,18))"), p)
      limite <- sprintf("(TRY_CAST(%s.raw AS DECIMAL(38,18)) %s %s)", v,
                         if (alto) "+" else "-", delta)
      ligar(limite, function(b) {
        redondeo <- sprintf("trunc(%1$s, 8) %2$s CASE WHEN %1$s %3$s trunc(%1$s, 8) THEN 0.00000001 ELSE 0 END",
                            b, if (alto) "+" else "-", if (alto) ">" else "<")
        sprintf(paste0("CASE WHEN %1$s.numero IS NULL THEN NULL ",
          "WHEN %1$s.raw IS NULL THEN %2$s ",
          "WHEN %3$s < -18 OR %3$s > 8 OR %4$s IS NULL THEN %5$s ",
          "ELSE CAST(%6$s AS DOUBLE) END"), v,
          error_sql("el limite decimal requiere indices explicitos en la ruta"), p, b,
          error_sql("el limite decimal admite escalas de -18 a 8 y numeros representables"), redondeo)
      }, ctx)
    }, ctx)
  }, ctx)
  val(sql, "DOUBLE")
}
