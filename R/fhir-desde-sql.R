#' Construir recursos FHIR R4 desde tablas o consultas SQL
#'
#' Define un mapeo explicito de columnas a destinos FHIR y construye un
#' recurso por fila. Admite `Patient`, `Observation`, `Encounter`, `Condition`
#' e `Immunization`.
#' No intenta invertir un `ViewDefinition`, que puede haber perdido datos.
#'
#' Los destinos usan nombres JSON de FHIR, puntos e indices desde cero:
#' `name[0].family`, `code.coding[0].code`, `valueQuantity.value`.
#' Un destino terminado en `[]`, como `name[0].given[]`, toma una columna
#' de listas de valores primitivos. Cada elemento repetido debe declarar
#' su indice o `[]`; no se evalua FHIRPath ni codigo R en el mapeo.
#'
#' `NA`, `NULL`, cadenas vacias y listas vacias se omiten. Los indices
#' sin contenido se compactan; no se escriben objetos vacios ni `null`.
#' Cada fila debe producir un `id` no vacio y unico. Para agrupar filas
#' del mismo recurso, prepara primero una fila por recurso en SQL o en R,
#' usando columnas de listas para las colecciones.
#'
#' Los tipos y cardinalidades se comprueban con metadatos base de FHIR
#' R4 4.0.1. Se revisan campos obligatorios, elementos de eleccion, fechas,
#' identificadores, tipos primitivos, destinos de referencias y bindings
#' requeridos que pueden enumerarse con la terminologia R4 incluida. Para
#' `Coding` y `CodeableConcept` se comprueba el par `system`/`code`.
#' Los valores `code` admiten solo espacios simples internos; `uri`, `url`
#' y `canonical` no admiten espacios ni otros caracteres de separacion.
#' Estos controles lexicos no comprueban que una URL exista.
#' Se conserva la restriccion de `SimpleQuantity`: no admite `comparator`,
#' por ejemplo en `Immunization.doseQuantity`. Una `Quantity` general puede
#' admitirlo. El estado, la vacuna, el paciente y una variante de
#' `occurrence[x]` son obligatorios en `Immunization`; si se construye
#' `protocolApplied`, cada entrada exige una variante de `doseNumber[x]`.
#' Esto no sustituye la validacion de invariantes, terminologias y perfiles
#' con [fhir_validar()]. No se inventan codigos, unidades o estados.
#'
#' Los destinos decimales aceptan numeros o texto numerico JSON. El texto
#' conserva la escala (`"1.00"` se escribe como el numero JSON `1.00`).
#' Para conservar un `DECIMAL(p,s)` de SQL, extraelo como texto en la
#' consulta; una vez convertido a un numero de R no se recuperan sus ceros.
#' `Date` se admite como `date` o `dateTime`, conservando precision de fecha;
#' `POSIXct`/`POSIXlt` se convierten a UTC. Los identificadores
#' tambien aceptan enteros seguros, convertidos a texto; para BIGINT usa un
#' CAST a texto en SQL. El resto de textos no admite conversion implicita.
#'
#' @param recurso Tipo FHIR: `"Patient"`, `"Observation"`, `"Encounter"`,
#'   `"Condition"` o `"Immunization"`.
#' @param campos Vector de texto con destinos FHIR como nombres y columnas
#'   de origen como valores.
#' @param constantes Lista con nombre de valores fijos, con destinos FHIR
#'   como nombres. Se aplica a cada fila.
#' @param referencias Vector con nombre: destino terminado en `.reference`
#'   y tipo de recurso al que apunta. Convierte la clave de origen en una
#'   referencia relativa, por ejemplo `Patient/p1`. Una referencia construida
#'   requiere `reference`, `identifier` o `display`; `type` solo no identifica
#'   un destino.
#' @param datos Un `data.frame`; cada fila representa un recurso.
#' @param mapa Mapeo creado con `fhir_mapa()`.
#' @param con_db Conexion DBI abierta (DuckDB, PostgreSQL, SQLite, SQL Server,
#'   etc., mediante su controlador DBI).
#' @param sql Consulta que produce una fila por recurso. La consulta se
#'   ejecuta tal como se recibe; se recomienda usar parametros para valores.
#' @param parametros Lista opcional de parametros enlazados por el
#'   controlador DBI, sin interpolarlos en el SQL.
#'
#' @return `fhir_mapa()` devuelve un `fhir_mapa`. Las otras funciones
#'   devuelven [fhir_recursos()], sin enviar recursos a un servidor FHIR ni
#'   crear tablas por su cuenta. La consulta SQL se ejecuta tal como se recibe.
#'   `fhir_desde_sql()` trae el resultado completo a memoria.
#'   Usa [fhir_escribir()] para guardar JSON o NDJSON conservando decimales.
#' @export
#' @examples
#' mapa <- fhir_mapa("Patient", c(
#'   id = "paciente_id", gender = "sexo",
#'   "name[0].family" = "apellido", "name[0].given[0]" = "nombre"))
#' datos <- data.frame(paciente_id = "p1", sexo = "female",
#'                     apellido = "Paredes", nombre = "Ana")
#' recursos <- fhir_desde_tabla(datos, mapa)
#' vista_fhirpath(recursos, "name.given")
fhir_mapa <- function(recurso, campos = character(), constantes = list(),
                       referencias = character()) {
  esquema <- esquema_mapeo()
  if (!es_texto(recurso) || !recurso %in% esquema$recursos) {
    error_mapeo("{.arg recurso} debe ser uno de {.val {unlist(esquema$recursos)}}.")
  }
  comprobar_vector_mapeo(campos, "campos")
  comprobar_vector_mapeo(referencias, "referencias")
  if (!is.list(constantes) || (length(constantes) &&
      (is.null(names(constantes)) || anyNA(names(constantes)) ||
       any(!nzchar(names(constantes))) || anyDuplicated(names(constantes))))) {
    error_mapeo("{.arg constantes} debe ser una lista con nombres unicos.")
  }
  destinos <- c(names(campos), names(constantes))
  if (anyDuplicated(destinos) || !"id" %in% destinos) {
    error_mapeo("El mapeo debe incluir id y no repetir destinos.")
  }
  rutas <- stats::setNames(lapply(destinos, ruta_mapeo, recurso = recurso), destinos)
  # Ningun destino puede ser padre de otro, ni [] coexistir con indices.
  normalizadas <- vapply(rutas, function(r) r$normalizada, character(1))
  for (i in seq_along(normalizadas)) {
    for (j in seq_len(i - 1L)) {
      a <- normalizadas[i]
      b <- normalizadas[j]
      if (a == b || startsWith(a, paste0(b, "/")) ||
          startsWith(b, paste0(a, "/"))) {
        error_mapeo("Hay destinos superpuestos en el mapeo.")
      }
    }
  }
  for (destino in names(referencias)) {
    if (!destino %in% destinos || !endsWith(destino, ".reference") ||
        !isTRUE(motor_actual()$es_recurso(referencias[[destino]]))) {
      error_mapeo("Cada referencia debe indicar un destino .reference y un tipo FHIR R4.",
                  campo = destino)
    }
    validar_destino_referencia(referencias[[destino]], rutas[[destino]]$destinos,
                               campo = destino)
  }
  structure(list(recurso = recurso, campos = campos, constantes = constantes,
                 referencias = referencias, rutas = rutas), class = "fhir_mapa")
}

#' @rdname fhir_mapa
#' @export
fhir_desde_tabla <- function(datos, mapa) {
  comprobar_mapa(mapa)
  if (!is.data.frame(datos) || anyDuplicated(names(datos))) {
    error_mapeo("{.arg datos} debe ser un data.frame con columnas unicas.")
  }
  faltan <- setdiff(unname(mapa$campos), names(datos))
  if (length(faltan)) {
    error_mapeo("Faltan columnas requeridas por el mapeo: {.val {faltan}}.")
  }
  if (!nrow(datos)) return(fhir_recursos(NULL))
  recursos <- lapply(seq_len(nrow(datos)), function(i) {
    r <- list(resourceType = mapa$recurso)
    for (destino in names(mapa$rutas)) {
      valor <- if (destino %in% names(mapa$campos)) {
        datos[[mapa$campos[[destino]]]][[i]]
      } else mapa$constantes[[destino]]
      ruta <- mapa$rutas[[destino]]
      referencia <- mapa$referencias[destino]
      if (!length(referencia) || is.na(referencia)) referencia <- NULL
      convertir <- function(v) valor_mapeo(v, ruta$tipo, i, destino, referencia)
      if (isTRUE(ruta$coleccion)) {
        valor <- lapply(seq_along(valor), function(j) convertir(valor[[j]]))
        valor <- Filter(Negate(is.null), valor)
        if (!length(valor)) valor <- NULL
      } else valor <- convertir(valor)
      if (!is.null(valor)) r <- asignar_mapeo(r, ruta$pasos, valor)
    }
    r <- compactar_mapeo(r)
    validar_recurso_mapeado(r, list(tipo = mapa$recurso, prefijo = ""), i)
    r
  })
  ids <- vapply(recursos, function(r) r$id %||% "", character(1))
  if (any(!nzchar(ids)) || anyDuplicated(ids)) {
    error_mapeo("Cada fila debe producir un id no vacio y unico.", campo = "id")
  }
  fhir_recursos(motor_actual()$serializar_recursos(recursos))
}

#' @rdname fhir_mapa
#' @export
fhir_desde_sql <- function(con_db, sql, mapa, parametros = NULL) {
  comprobar_mapa(mapa)
  if (!es_texto(sql)) error_mapeo("{.arg sql} debe ser una consulta de texto.")
  rlang::check_installed("DBI", reason = "para leer la consulta SQL.")
  datos <- if (is.null(parametros)) DBI::dbGetQuery(con_db, sql) else
    DBI::dbGetQuery(con_db, sql, params = parametros)
  fhir_desde_tabla(datos, mapa)
}

#' Escribir recursos FHIR como JSON o NDJSON
#'
#' Conserva los literales decimales de la fuente JSON cuando estan
#' disponibles. No valida perfiles ni envia recursos a un servidor.
#' Un archivo JSON contiene un arreglo de recursos; NDJSON, uno por linea.
#' Reemplaza el contenido del archivo indicado.
#' @param recursos Recursos aceptados por [fhir_recursos()].
#' @param archivo Ruta de salida.
#' @param formato `"ndjson"` (por defecto) o `"json"`.
#' @return La ruta de salida, de forma invisible.
#' @export
#' @examples
#' archivo <- tempfile(fileext = ".ndjson")
#' fhir_escribir(list(resourceType = "Patient", id = "p1"), archivo)
#' fhir_recursos(archivo)
#' unlink(archivo)
fhir_escribir <- function(recursos, archivo, formato = c("ndjson", "json")) {
  formato <- match.arg(formato)
  if (!es_texto(archivo)) error_mapeo("{.arg archivo} debe ser una ruta de texto.")
  recursos <- fhir_recursos(recursos)
  fuente <- attr(recursos, "fuente")
  textos <- if (!length(recursos)) character() else if (!is.null(fuente)) {
    motor_actual()$recursos_json(fuente)
  } else motor_actual()$serializar_recursos(unclass(sin_fuente(recursos)))
  if (formato == "json") textos <- paste0("[", paste(textos, collapse = ","), "]")
  con <- file(archivo, open = "wb")
  on.exit(close(con))
  writeLines(enc2utf8(textos), con, useBytes = TRUE)
  invisible(archivo)
}

error_mapeo <- function(mensaje, fila = NULL, campo = NULL) {
  entorno <- rlang::env(parent.frame(), fila = fila, campo = campo)
  cli::cli_abort(c(mensaje, if (!is.null(fila)) "i" = "Fila {fila}.",
                   if (!is.null(campo)) "i" = "Destino {.val {campo}}."),
    class = c("fhirviews_error_mapeo", "fhirviews_error"), fila = fila,
    campo = campo, call = NULL, .envir = entorno)
}

comprobar_vector_mapeo <- function(x, argumento) {
  if (!is.character(x) || anyNA(x) || any(!nzchar(x)) ||
      (length(x) && (is.null(names(x)) || anyNA(names(x)) ||
                     any(!nzchar(names(x))) || anyDuplicated(names(x))))) {
    error_mapeo("{.arg {argumento}} debe ser un vector de texto con nombres unicos.")
  }
}

comprobar_mapa <- function(mapa) {
  if (!inherits(mapa, "fhir_mapa")) {
    error_mapeo("{.arg mapa} debe crearse con fhir_mapa().")
  }
}

esquema_mapeo <- function() {
  if (is.null(.fhirviews$esquema_mapeo)) {
    .fhirviews$esquema_mapeo <- jsonlite::fromJSON(system.file(
      "schema", "mapeo-r4.json", package = "fhirviews", mustWork = TRUE),
      simplifyVector = FALSE)
  }
  .fhirviews$esquema_mapeo
}

elemento_mapeo <- function(ctx, nombre) {
  esquema <- esquema_mapeo()$esquemas[[ctx$tipo]]
  ruta <- paste0(if (nzchar(ctx$prefijo)) paste0(ctx$prefijo, "."), nombre)
  e <- esquema[[ruta]]
  elegida <- NULL
  if (is.null(e)) {
    elecciones <- names(esquema)[endsWith(names(esquema), "[x]")]
    for (eleccion in elecciones) {
      base <- sub("\\[x\\]$", "", eleccion)
      tipos <- unlist(esquema[[eleccion]]$tipos)
      if (ruta %in% con_sufijo(base, tipos)) {
        elegida <- tipos[match(ruta, con_sufijo(base, tipos))]
        e <- esquema[[eleccion]]
        ruta <- eleccion
        break
      }
    }
  }
  if (is.null(e)) return(NULL)
  tipos <- unlist(e$tipos)
  tipo <- elegida %||% if (length(tipos) == 1L) tipos else NULL
  siguiente <- if (!is.null(e$ref)) {
    partes <- strsplit(e$ref, ".", fixed = TRUE)[[1]]
    list(tipo = partes[1], prefijo = paste(partes[-1], collapse = "."))
  } else if (!is.null(tipo) && tipo %in% c("BackboneElement", "Element")) {
    list(tipo = ctx$tipo, prefijo = ruta)
  } else list(tipo = if (is.null(tipo)) NULL else e$contextos[[tipo]] %||% tipo, prefijo = "")
  if (identical(tipo, "Reference")) siguiente$destinos <- e$destinos
  c(e, list(tipo = tipo, ruta = ruta, siguiente = siguiente))
}

ruta_mapeo <- function(campo, recurso) {
  if (!es_texto(campo) || endsWith(campo, ".")) {
    error_mapeo("Destino mal escrito.", campo = campo)
  }
  partes <- strsplit(campo, ".", fixed = TRUE)[[1]]
  ctx <- list(tipo = recurso, prefijo = "")
  pasos <- list()
  normal <- character()
  destinos <- NULL
  for (i in seq_along(partes)) {
    m <- regmatches(partes[i], regexec(
      "^([A-Za-z][A-Za-z0-9]*)(\\[([0-9]*)\\])?$", partes[i]))[[1]]
    if (!length(m)) error_mapeo("Destino mal escrito.", campo = campo)
    e <- elemento_mapeo(ctx, m[2])
    if (is.null(e)) error_mapeo("El destino no existe en FHIR R4.", campo = campo)
    if (identical(e$max, "0")) {
      error_mapeo("El destino esta prohibido por el perfil de tipo FHIR.", campo = campo)
    }
    if (identical(e$tipo, "Resource")) {
      error_mapeo("No se admite construir recursos contained; construye recursos separados.", campo = campo)
    }
    arreglo <- nzchar(m[3])
    repetido <- e$max == "*" || as.numeric(e$max) > 1
    if (!identical(arreglo, repetido)) {
      error_mapeo("Los campos repetidos requieren [indice] o [] y los simples no los admiten.",
                  campo = campo)
    }
    coleccion <- arreglo && !nzchar(m[4])
    if (coleccion && i != length(partes)) {
      error_mapeo("[] solo se admite al final del destino.", campo = campo)
    }
    pasos <- c(pasos, list(m[2]))
    normal <- c(normal, m[2])
    if (arreglo && !coleccion) {
      indice <- as.numeric(m[4])
      if (!is.finite(indice) || indice > 10000 ||
          (e$max != "*" && indice >= as.numeric(e$max))) {
        error_mapeo("Indice fuera del rango admitido.", campo = campo)
      }
      pasos <- c(pasos, list(as.integer(indice) + 1L))
      normal <- c(normal, as.character(indice))
    }
    if (identical(ctx$tipo, "Reference") && m[2] == "reference") destinos <- ctx$destinos
    ctx <- e$siguiente
  }
  if (is.null(e$tipo) || !grepl("^[a-z]", e$tipo)) {
    error_mapeo("El destino debe ser un campo primitivo, no un objeto completo.", campo = campo)
  }
  list(pasos = pasos, tipo = e$tipo, coleccion = coleccion,
       destinos = destinos,
       normalizada = paste(normal, collapse = "/"))
}

asignar_mapeo <- function(x, pasos, valor) {
  clave <- pasos[[1]]
  if (is.null(x)) x <- list()
  if (is.integer(clave) && length(x) < clave) length(x) <- clave
  if (length(pasos) == 1L) x[clave] <- list(valor) else {
    x[clave] <- list(asignar_mapeo(x[[clave]], pasos[-1], valor))
  }
  x
}

compactar_mapeo <- function(x) {
  if (!is.list(x)) return(x)
  x <- lapply(x, compactar_mapeo)
  x <- x[!vapply(x, function(v) is.null(v) || (is.list(v) && !length(v)), logical(1))]
  x
}

valor_mapeo <- function(x, tipo, fila, campo, referencia = NULL) {
  if (is.null(x) || !length(x)) return(NULL)
  if (inherits(x, "AsIs")) class(x) <- setdiff(class(x), "AsIs")
  if (inherits(x, "POSIXlt")) x <- as.POSIXct(x)
  if (length(x) != 1L || is.list(x) || inherits(x, "integer64")) {
    error_mapeo("Se esperaba un valor primitivo; para BIGINT usa texto SQL.", fila, campo)
  }
  if (is.numeric(x) && is.nan(x)) error_mapeo("Un valor NaN no es un primitivo FHIR.", fila, campo)
  if (is.na(x)) return(NULL)
  if (is.factor(x)) x <- as.character(x)
  if (is.character(x) && !nzchar(x)) return(NULL)
  if (inherits(x, "Date") && tipo %in% c("date", "dateTime")) x <- format(x, "%Y-%m-%d")
  if (inherits(x, "POSIXt") && tipo %in% c("dateTime", "instant")) {
    x <- format(x, "%Y-%m-%dT%H:%M:%OS6Z", tz = "UTC")
  }
  if (is.object(x)) error_mapeo("Clase no admitida; convierte la columna a un tipo primitivo.", fila, campo)
  x <- unname(x)
  if ((tipo == "id" || !is.null(referencia)) && is.numeric(x) &&
      !is.object(x) && is.finite(x) && x == trunc(x) && abs(x) <= 9007199254740991) {
    x <- format(x, scientific = FALSE, trim = TRUE, digits = 16)
  }
  if (!is.null(referencia)) {
    if (!is.character(x) || !grepl("^[A-Za-z0-9.-]{1,64}$", x)) {
      error_mapeo("La referencia necesita una clave FHIR valida.", fila, campo)
    }
    return(paste0(referencia, "/", x))
  }
  if (tipo == "boolean") {
    if (!is.logical(x)) error_mapeo("Se esperaba un booleano.", fila, campo)
    return(x)
  }
  if (tipo %in% tipos_enteros) {
    if (!is.numeric(x) || is.object(x) || !is.finite(x) || x != trunc(x) ||
        x < -2147483648 || x > 2147483647 ||
        (tipo == "positiveInt" && x <= 0) || (tipo == "unsignedInt" && x < 0)) {
      error_mapeo("Entero fuera del tipo o rango FHIR.", fila, campo)
    }
    return(x)
  }
  if (tipo == "decimal") {
    if (is.numeric(x) && !is.object(x) && is.finite(x)) {
      x <- as.character(jsonlite::toJSON(x, auto_unbox = TRUE, digits = NA))
    }
    if (!is.character(x) || !grepl(
        "^-?(0|[1-9][0-9]*)(\\.[0-9]+)?([eE][+-]?[0-9]+)?$", x)) {
      error_mapeo("Se esperaba un decimal finito o su literal JSON.", fila, campo)
    }
    return(list(`__fhirviews_decimal` = x))
  }
  if (!is.character(x)) error_mapeo("Se esperaba texto.", fila, campo)
  if (tipo == "code" && !grepl("(*UCP)\\A\\S+( \\S+)*\\z", x, perl = TRUE)) {
    error_mapeo("Un code FHIR solo admite espacios simples internos.", fila, campo)
  }
  if (tipo %in% c("uri", "url", "canonical") && grepl("(*UCP)\\s", x, perl = TRUE)) {
    error_mapeo("Una URI FHIR no admite espacios ni caracteres de separacion.", fila, campo)
  }
  if (tipo == "id" && !grepl("^[A-Za-z0-9.-]{1,64}$", x)) {
    error_mapeo("Identificador FHIR no valido.", fila, campo)
  }
  if (tipo %in% c("date", "dateTime", "instant", "time") && !fecha_mapeo(x, tipo)) {
    error_mapeo("Fecha u hora FHIR no valida.", fila, campo)
  }
  x
}

fecha_mapeo <- function(x, tipo) {
  fecha <- "[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?"
  hora <- "[0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]+)?"
  zona <- "(Z|[+-][0-9]{2}:[0-9]{2})"
  patron <- switch(tipo, date = fecha, time = hora,
    dateTime = paste0(fecha, "(T", hora, zona, ")?"),
    instant = paste0("[0-9]{4}-[0-9]{2}-[0-9]{2}T", hora, zona))
  if (!grepl(paste0("^", patron, "$"), x)) return(FALSE)
  if (tipo != "time") {
    d <- strsplit(x, "T", fixed = TRUE)[[1]][1]
    if (nchar(d) == 4L) d <- paste0(d, "-01-01")
    if (nchar(d) == 7L) d <- paste0(d, "-01")
    fecha_valida <- tryCatch(as.Date(d), error = function(e) NA)
    if (is.na(fecha_valida) || substr(d, 1, 4) == "0000") return(FALSE)
    if (grepl("T", x, fixed = TRUE) && nchar(strsplit(x, "T", fixed = TRUE)[[1]][1]) != 10L) return(FALSE)
  }
  h <- if (tipo == "time") x else if (grepl("T", x, fixed = TRUE)) {
    strsplit(x, "T", fixed = TRUE)[[1]][2]
  } else NULL
  if (!is.null(h)) {
    if (as.integer(substr(h, 1, 2)) > 23 || as.integer(substr(h, 4, 5)) > 59 ||
        as.integer(substr(h, 7, 8)) > 60) return(FALSE)
    z <- regmatches(h, regexpr("[+-][0-9]{2}:[0-9]{2}$", h))
    if (length(z) && (as.integer(substr(z, 2, 3)) > 14 ||
        as.integer(substr(z, 5, 6)) > 59 ||
        (substr(z, 2, 3) == "14" && substr(z, 5, 6) != "00"))) return(FALSE)
  }
  TRUE
}

validar_recurso_mapeado <- function(r, ctx, fila, prefijo = "") {
  esquema <- esquema_mapeo()$esquemas[[ctx$tipo]]
  inicio <- if (nzchar(ctx$prefijo)) paste0(ctx$prefijo, ".") else ""
  hijos <- names(esquema)[startsWith(names(esquema), inicio)]
  hijos <- hijos[!grepl(".", substring(hijos, nchar(inicio) + 1L), fixed = TRUE)]
  for (h in hijos) {
    nombre <- substring(h, nchar(inicio) + 1L)
    e <- esquema[[h]]
    elegidos <- if (endsWith(nombre, "[x]")) {
      intersect(names(r), con_sufijo(sub("\\[x\\]$", "", nombre), unlist(e$tipos)))
    } else intersect(names(r), nombre)
    if ((e$min > 0 && !length(elegidos)) || length(elegidos) > 1L) {
      error_mapeo("Falta un campo obligatorio o hay tipos de eleccion incompatibles.",
                  fila, paste0(prefijo, nombre))
    }
  }
  for (nombre in setdiff(names(r), "resourceType")) {
    e <- elemento_mapeo(ctx, nombre)
    if (is.null(e)) error_mapeo("Campo FHIR desconocido.", fila, paste0(prefijo, nombre))
    valores <- if (e$max == "*" || as.numeric(e$max) > 1) r[[nombre]] else list(r[[nombre]])
    if (length(valores) < e$min || (e$max != "*" && length(valores) > as.numeric(e$max))) {
      error_mapeo("Cardinalidad FHIR incompatible.", fila, paste0(prefijo, nombre))
    }
    for (v in valores) {
      validar_vinculo_mapeo(v, e, fila, paste0(prefijo, nombre))
      if (identical(e$tipo, "Reference")) {
        validar_referencia_mapeo(v, e$destinos, fila, paste0(prefijo, nombre))
      }
    }
    if (!is.null(e$tipo) && grepl("^[A-Z]", e$tipo) || !is.null(e$ref)) {
      for (v in valores) validar_recurso_mapeado(v, e$siguiente, fila, paste0(prefijo, nombre, "."))
    }
  }
}

validar_vinculo_mapeo <- function(valor, elemento, fila, campo) {
  vinculo <- elemento$vinculo
  if (is.null(vinculo) || !identical(vinculo$fuerza, "required")) return(invisible(NULL))
  tipo <- elemento$tipo
  if (identical(tipo, "CodeableConcept")) {
    valores <- valor$coding %||% list()
    if (!length(valores) || !any(vapply(valores, function(x) !is.null(x$code), logical(1)))) {
      error_mapeo("El binding requerido necesita al menos un Coding con code; text no lo sustituye.", fila, campo)
    }
  } else if (identical(tipo, "Coding")) valores <- list(valor) else valores <- list(list(code = valor))
  # Un ValueSet externo o con filtros no se sustituye por una lista parcial.
  if (is.null(vinculo$codigos)) return(invisible(NULL))
  coincide <- function(coding) {
    if (is.null(coding$code)) return(FALSE)
    any(vapply(vinculo$codigos, function(codigo) {
      mismo_codigo <- if (isTRUE(codigo$caseSensitive)) identical(coding$code, codigo$code) else
        identical(tolower(coding$code), tolower(codigo$code))
      mismo_sistema <- !tipo %in% c("Coding", "CodeableConcept") ||
        identical(coding$system, codigo$system)
      mismo_codigo && mismo_sistema
    }, logical(1)))
  }
  if (!any(vapply(valores, coincide, logical(1)))) {
    error_mapeo("El codigo o par system/code no pertenece al ValueSet requerido {.val {vinculo$valueSet}}.",
                fila, campo)
  }
  invisible(NULL)
}

validar_destino_referencia <- function(tipo, destinos, fila = NULL, campo) {
  destinos <- unlist(destinos, use.names = FALSE)
  if (!isTRUE(motor_actual()$es_recurso(tipo)) ||
      (length(destinos) && !"Resource" %in% destinos && !tipo %in% destinos)) {
    error_mapeo("El tipo {.val {tipo}} no es un destino FHIR permitido para esta referencia.", fila, campo)
  }
  invisible(NULL)
}

validar_referencia_mapeo <- function(referencia, destinos, fila, campo) {
  if (is.null(referencia$reference) && is.null(referencia$identifier) && is.null(referencia$display)) {
    error_mapeo("Una referencia requiere reference, identifier o display; type solo no identifica un destino.", fila, campo)
  }
  declarada <- referencia$type
  if (!is.null(declarada)) {
    declarada <- sub("^http://hl7.org/fhir/StructureDefinition/", "", declarada)
    if (!grepl("^[A-Z][A-Za-z0-9]+$", declarada)) declarada <- NULL
  }
  literal <- referencia$reference
  tipo <- NULL
  if (!is.null(literal)) {
    if (startsWith(literal, "#")) {
      error_mapeo("No se construyen referencias a recursos contained.", fila, paste0(campo, ".reference"))
    }
    patron <- "([A-Z][A-Za-z0-9]+)/[A-Za-z0-9.-]{1,64}(/_history/[A-Za-z0-9.-]{1,64})?$"
    absoluto <- grepl("^https?://", literal)
    relativo <- !grepl("^[A-Za-z][A-Za-z0-9+.-]*:", literal)
    if (absoluto || relativo) {
      m <- regmatches(literal, regexec(paste0(if (absoluto) "^https?://.+/" else "^", patron), literal))[[1]]
      if (length(m)) tipo <- m[2] else if (relativo) {
        error_mapeo("Una referencia relativa debe tener la forma Tipo/id.", fila, paste0(campo, ".reference"))
      }
    }
  }
  for (t in unique(c(tipo, declarada))) validar_destino_referencia(t, destinos, fila, campo)
  if (!is.null(tipo) && !is.null(declarada) && tipo != declarada) {
    error_mapeo("Reference.type no coincide con el tipo de la referencia literal.", fila, campo)
  }
  invisible(NULL)
}
