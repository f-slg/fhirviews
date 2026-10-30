#' Exportación masiva de datos (FHIR Bulk Data, `$export`)
#'
#' Pide al servidor una exportación masiva según la especificación
#' [FHIR Bulk Data Access](https://hl7.org/fhir/uv/bulkdata/): el servidor
#' prepara archivos NDJSON (un recurso por línea) en segundo plano y, al
#' terminar, `fhir_exportar()` los descarga a una carpeta local. Es la forma
#' adecuada de reunir datos de toda una población (vigilancia epidemiológica,
#' indicadores), y el NDJSON es justo el formato que [vista_ejecutar()]
#' procesa más rápido.
#'
#' El proceso tiene tres pasos:
#'
#' 1. *Inicio*: `GET [base]/$export` (o `Patient/$export`, o
#'    `Group/[id]/$export`) con `Prefer: respond-async`. El servidor responde
#'    `202 Accepted` y una dirección de estado en `Content-Location`.
#' 2. *Espera*: se consulta la dirección de estado; mientras responde `202`
#'    se espera lo que indica `Retry-After` (o, si no lo indica, cada vez
#'    más tiempo, hasta un minuto) y se muestra el avance de `X-Progress`.
#'    Cuando responde `200`, el cuerpo es el manifiesto con la lista de
#'    archivos.
#' 3. *Descarga*: cada archivo del manifiesto se guarda en `carpeta`. Si el
#'    manifiesto indica `requiresAccessToken`, se envía el token de la
#'    conexión, pero solo a archivos del mismo servidor.
#'
#' Con `esperar = FALSE`, `fhir_exportar()` devuelve la exportación en curso
#' justo después del inicio; luego se consulta con `fhir_exportar_estado()`
#' (que la descarga cuando está lista) o se cancela con
#' `fhir_exportar_cancelar()` (`DELETE` a la dirección de estado).
#'
#' @param con Conexión creada con [fhir_conectar()].
#' @param nivel Qué exportar: `"sistema"` (todos los datos del servidor,
#'   `[base]/$export`), `"paciente"` (todos los pacientes y sus datos,
#'   `Patient/$export`) o `"grupo"` (los pacientes de un `Group`,
#'   `Group/[id]/$export`). Si se da `grupo`, por defecto es `"grupo"`.
#' @param grupo Id del recurso `Group`, para `nivel = "grupo"`.
#' @param tipos Vector de tipos de recurso a exportar (parámetro `_type`), por
#'   ejemplo `c("Patient", "Condition")`. Por defecto, todos.
#' @param desde Exportar solo los recursos modificados desde ese momento
#'   (parámetro `_since`): un `Date`, un `POSIXct` o un texto en formato
#'   FHIR `instant` (`"2025-01-01T00:00:00Z"`).
#' @param filtros Vector de filtros de búsqueda por tipo (parámetro
#'   `_typeFilter`), por ejemplo
#'   `"Condition?code=http://hl7.org/fhir/sid/icd-10|A90"`.
#' @param carpeta Carpeta donde se guardan los archivos NDJSON. Se crea si no
#'   existe.
#' @param esperar Si es `TRUE` (por defecto), espera a que el servidor termine
#'   y descarga los archivos. Si es `FALSE`, devuelve la exportación en curso.
#' @param intervalo Segundos entre consultas de estado. Por defecto se usa
#'   `Retry-After`; si se da, nunca se consulta antes de lo que pide el
#'   servidor.
#' @param max_espera Segundos máximos de espera. Si se agotan, se avisa y se
#'   devuelve la exportación en curso, que se puede seguir consultando con
#'   `fhir_exportar_estado()`.
#' @param progreso Si es `TRUE`, muestra el avance (por defecto, en sesiones
#'   interactivas).
#'
#' @return Un objeto de clase `fhir_exportacion`, una lista con:
#'   * `estado`: `"en_curso"`, `"completada"` o `"cancelada"`;
#'   * `archivos`: lista con nombre por tipo de recurso, con las rutas de los
#'     archivos descargados (se pasan tal cual a [fhir_recursos()] o
#'     [vista_ejecutar()]);
#'   * `errores`: rutas de los archivos de `OperationOutcome` con los
#'     problemas que el servidor informó durante la exportación;
#'   * `manifiesto`: el manifiesto del servidor como lista de R;
#'   * `url_estado`, `carpeta`, `nivel` y `progreso` (último `X-Progress`).
#' @seealso [fhir_recursos()], [vista_ejecutar()], [fhir_buscar()] para
#'   consultas pequeñas.
#' @export
#' @examplesIf interactive() && fhir_disponible("https://bulk-data.smarthealthit.org/fhir")
#' # Servidor de referencia de SMART (datos sintéticos, sin autenticación)
#' con <- fhir_conectar("https://bulk-data.smarthealthit.org/fhir")
#' exp <- fhir_exportar(con, "paciente", tipos = c("Patient", "Condition"))
#' exp
#' pacientes <- vista_ejecutar(exp$archivos$Patient,
#'                             vista_crear("Patient", c(sexo = "gender")))
#' table(pacientes$sexo)
#'
#' # Sin esperar: consultar más tarde o cancelar
#' trabajo <- fhir_exportar(con, "sistema", esperar = FALSE)
#' trabajo <- fhir_exportar_estado(trabajo)
#' fhir_exportar_cancelar(trabajo)
fhir_exportar <- function(con, nivel = c("sistema", "paciente", "grupo"),
                          grupo = NULL, tipos = NULL, desde = NULL,
                          filtros = NULL, carpeta = tempfile("fhir_export_"),
                          esperar = TRUE, intervalo = NULL, max_espera = 3600,
                          progreso = interactive()) {
  comprobar_conexion(con)
  if (missing(nivel) && !is.null(grupo)) nivel <- "grupo"
  nivel <- match.arg(nivel)
  texto_simple(carpeta, "carpeta")
  ruta <- switch(nivel,
    sistema = "$export",
    paciente = "Patient/$export",
    grupo = {
      if (is.null(grupo)) {
        cli::cli_abort("Para {.code nivel = \"grupo\"} falta {.arg grupo}.",
                       class = "fhirviews_error")
      }
      paste0("Group/", texto_simple(as.character(grupo), "grupo"), "/$export")
    }
  )
  parametros <- parametros_exportacion(tipos, desde, filtros)
  res <- peticion_json(con, "GET", ruta, parametros = parametros,
                       cabeceras = list(Prefer = "respond-async"))
  url_estado <- res$cabeceras[["content-location"]]
  if (res$estado != 202L || !es_texto(url_estado)) {
    cli::cli_abort(c(
      "El servidor no inici\u00f3 la exportaci\u00f3n as\u00edncrona.",
      "x" = "Respondi\u00f3 {res$estado} {if (!es_texto(url_estado))
             'sin cabecera Content-Location'}.",
      "i" = "Se esperaba {.code 202 Accepted} con {.field Content-Location}:
             puede que el servidor no admita {.code $export}."
    ), class = "fhirviews_error_exportacion", call = NULL)
  }
  x <- structure(list(
    estado = "en_curso", nivel = nivel, url_estado = url_completa(con, url_estado),
    carpeta = carpeta, progreso = NA_character_, manifiesto = NULL,
    archivos = list(), errores = character(), con = con
  ), class = "fhir_exportacion")
  if (!esperar) {
    return(x)
  }
  fhir_exportar_estado(x, esperar = TRUE, intervalo = intervalo,
                       max_espera = max_espera, progreso = progreso)
}

#' @rdname fhir_exportar
#' @param x Exportación devuelta por `fhir_exportar()` o por
#'   `fhir_exportar_estado()`.
#' @param descargar Si es `TRUE` (por defecto), descarga los archivos cuando
#'   la exportación está lista.
#' @details `fhir_exportar_estado()` consulta el estado una vez (o, con
#'   `esperar = TRUE`, hasta que termine) y devuelve la exportación
#'   actualizada: hay que guardarla de nuevo,
#'   `trabajo <- fhir_exportar_estado(trabajo)`.
#' @export
fhir_exportar_estado <- function(x, esperar = FALSE, descargar = TRUE,
                                 intervalo = NULL, max_espera = 3600,
                                 progreso = interactive()) {
  comprobar_exportacion(x)
  if (identical(x$estado, "cancelada")) {
    cli::cli_abort("La exportaci\u00f3n fue cancelada.",
                   class = "fhirviews_error_exportacion")
  }
  if (identical(x$estado, "en_curso")) {
    x <- if (esperar) {
      esperar_exportacion(x, intervalo, max_espera, progreso)
    } else {
      consultar_exportacion(x)$x
    }
  }
  if (descargar && identical(x$estado, "completada") &&
      length(x$archivos) == 0L) {
    x <- descargar_exportacion(x, progreso)
  }
  x
}

#' @rdname fhir_exportar
#' @details `fhir_exportar_cancelar()` envía `DELETE` a la dirección de
#'   estado; el servidor deja de preparar los archivos (o borra los ya
#'   preparados). Devuelve, de forma invisible, la exportación con
#'   `estado = "cancelada"`.
#' @export
fhir_exportar_cancelar <- function(x) {
  comprobar_exportacion(x)
  peticion_json(x$con, "DELETE", x$url_estado)
  x$estado <- "cancelada"
  invisible(x)
}

#' @export
print.fhir_exportacion <- function(x, ...) {
  estados <- c(en_curso = "en curso", completada = "completada",
               cancelada = "cancelada")
  cat("<fhir_exportacion> ", estados[[x$estado]], " (nivel ", x$nivel, ")\n",
      sep = "")
  if (identical(x$estado, "en_curso")) {
    cat("  Estado:  ", x$url_estado, "\n", sep = "")
    if (!is.na(x$progreso)) cat("  Avance:  ", x$progreso, "\n", sep = "")
  }
  if (length(x$archivos) > 0L) {
    cat("  Carpeta: ", x$carpeta, "\n", sep = "")
    conteo <- conteo_manifiesto(x$manifiesto$output)
    for (tipo in names(x$archivos)) {
      n <- conteo[tipo]
      cat("  ", formatC(tipo, width = -24L), " ",
          length(x$archivos[[tipo]]),
          if (length(x$archivos[[tipo]]) == 1L) " archivo" else " archivos",
          if (!is.na(n)) paste0(", ", n, " recursos"), "\n", sep = "")
    }
  } else if (identical(x$estado, "completada")) {
    cat("  Sin archivos descargados.\n")
  }
  if (length(x$errores) > 0L) {
    cat("  Problemas informados por el servidor: ",
        paste(x$errores, collapse = ", "), "\n", sep = "")
  }
  invisible(x)
}

# --- Internas ----------------------------------------------------------------

comprobar_exportacion <- function(x) {
  if (!inherits(x, "fhir_exportacion")) {
    cli::cli_abort(c(
      "{.arg x} debe ser una exportaci\u00f3n creada con {.fn fhir_exportar}.",
      "x" = "Se recibi\u00f3 un objeto de clase {.cls {class(x)}}."
    ), class = "fhirviews_error", call = rlang::caller_env())
  }
}

parametros_exportacion <- function(tipos, desde, filtros) {
  p <- list()
  if (!is.null(tipos)) {
    if (!is.character(tipos) || length(tipos) == 0L || anyNA(tipos)) {
      cli::cli_abort("{.arg tipos} debe ser un vector de tipos de recurso.",
                     class = "fhirviews_error", call = NULL)
    }
    p[["_type"]] <- paste(tipos, collapse = ",")
  }
  if (!is.null(desde)) {
    p[["_since"]] <- if (inherits(desde, "POSIXt")) {
      format(as.POSIXct(desde), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    } else if (inherits(desde, "Date")) {
      paste0(format(desde, "%Y-%m-%d"), "T00:00:00Z")
    } else {
      texto_simple(desde, "desde")
    }
  }
  if (!is.null(filtros)) {
    if (!is.character(filtros) || anyNA(filtros)) {
      cli::cli_abort("{.arg filtros} debe ser un vector de caracteres.",
                     class = "fhirviews_error", call = NULL)
    }
    p[["_typeFilter"]] <- filtros
  }
  p
}

# Una consulta de estado: devuelve la exportación actualizada y los segundos
# que pide esperar el servidor (NA si no lo indica)
consultar_exportacion <- function(x) {
  res <- tryCatch(
    peticion_json(x$con, "GET", x$url_estado),
    fhirviews_error_http = function(e) {
      cli::cli_abort(
        "La exportaci\u00f3n masiva fall\u00f3 en el servidor.",
        parent = e, estado = e$estado, outcome = e$outcome, call = NULL,
        class = c("fhirviews_error_exportacion",
                  setdiff(class(e), c("rlang_error", "error", "condition")))
      )
    }
  )
  if (res$estado == 202L) {
    avance <- res$cabeceras[["x-progress"]]
    if (es_texto(avance)) x$progreso <- avance
    return(list(x = x, espera = segundos_retry_after(res$cabeceras)))
  }
  manifiesto <- res$datos
  if (res$estado != 200L || !is.list(manifiesto) ||
      is.null(manifiesto$output)) {
    cli::cli_abort(c(
      "La respuesta de estado no es un manifiesto de exportaci\u00f3n.",
      "x" = "Respondi\u00f3 {res$estado}; se esperaba 202 (en curso) o 200 con
             la lista {.field output}."
    ), class = "fhirviews_error_exportacion", call = NULL)
  }
  x$estado <- "completada"
  x$manifiesto <- manifiesto
  list(x = x, espera = NA_real_)
}

segundos_retry_after <- function(cabeceras) {
  valor <- cabeceras[["retry-after"]]
  if (!es_texto(valor)) {
    return(NA_real_)
  }
  # httr2 entiende segundos y fechas HTTP
  s <- tryCatch(
    httr2::resp_retry_after(httr2::response(headers = list(`Retry-After` = valor))),
    error = function(e) NA_real_
  )
  if (length(s) != 1L || is.na(s)) NA_real_ else max(0, as.numeric(s))
}

# Envoltorio de Sys.sleep para poder simularlo en las pruebas
dormir <- function(segundos) Sys.sleep(segundos)

esperar_exportacion <- function(x, intervalo, max_espera, progreso) {
  inicio <- Sys.time()
  espera_sin_aviso <- 1
  avance <- ""
  if (progreso) {
    cli::cli_progress_bar(
      format = "{cli::pb_spin} Exportando datos FHIR {avance} [{cli::pb_elapsed}]",
      clear = TRUE
    )
  }
  repeat {
    r <- consultar_exportacion(x)
    x <- r$x
    if (!identical(x$estado, "en_curso")) break
    avance <- if (is.na(x$progreso)) "" else paste0("(", x$progreso, ")")
    if (progreso) cli::cli_progress_update(force = TRUE)
    espera <- if (!is.null(intervalo)) {
      max(intervalo, r$espera, na.rm = TRUE)
    } else if (!is.na(r$espera)) {
      r$espera
    } else {
      # Sin Retry-After: espera exponencial, hasta un minuto
      e <- espera_sin_aviso
      espera_sin_aviso <- min(espera_sin_aviso * 2, 60)
      e
    }
    transcurrido <- as.numeric(difftime(Sys.time(), inicio, units = "secs"))
    if (transcurrido + espera > max_espera) {
      if (progreso) cli::cli_progress_done()
      cli::cli_warn(c(
        "La exportaci\u00f3n sigue en curso tras {round(transcurrido)} s
         ({.arg max_espera} = {max_espera}).",
        "i" = "Cons\u00faltala m\u00e1s tarde con
               {.code x <- fhir_exportar_estado(x, esperar = TRUE)} o
               canc\u00e9lala con {.fn fhir_exportar_cancelar}."
      ), class = "fhirviews_aviso")
      return(x)
    }
    dormir(espera)
  }
  if (progreso) cli::cli_progress_done()
  x
}

descargar_exportacion <- function(x, progreso) {
  m <- x$manifiesto
  dir.create(x$carpeta, recursive = TRUE, showWarnings = FALSE)
  con_token <- isTRUE(m$requiresAccessToken)
  salida <- m$output
  if (progreso && length(salida) > 0L) {
    cli::cli_progress_bar("Descargando archivos", total = length(salida),
                          clear = TRUE)
  }
  tipos <- character()
  rutas <- character()
  for (f in salida) {
    tipo <- f$type %||% "Recurso"
    tipos <- c(tipos, tipo)
    rutas <- c(rutas, file.path(x$carpeta, nombre_archivo(f$url, tipo, tipos)))
    descargar_archivo(x$con, f$url, rutas[length(rutas)], con_token)
    if (progreso) cli::cli_progress_update()
  }
  if (progreso && length(salida) > 0L) cli::cli_progress_done()
  x$archivos <- split(rutas, factor(tipos, levels = unique(tipos)))

  errores <- character()
  if (length(m$error) > 0L) {
    carpeta_errores <- file.path(x$carpeta, "errores")
    dir.create(carpeta_errores, showWarnings = FALSE)
    tipos_error <- character()
    for (f in m$error) {
      tipo <- f$type %||% "OperationOutcome"
      tipos_error <- c(tipos_error, tipo)
      archivo <- file.path(carpeta_errores,
                           nombre_archivo(f$url, tipo, tipos_error))
      descargar_archivo(x$con, f$url, archivo, con_token)
      errores <- c(errores, archivo)
    }
    avisar_errores_exportacion(errores)
  }
  x$errores <- errores
  x
}

# Tipo.ndjson; si hay varios archivos del mismo tipo, Tipo_2.ndjson, ...
nombre_archivo <- function(url, tipo, tipos) {
  tipo <- gsub("[^A-Za-z0-9_-]", "_", tipo)
  n <- sum(tipos == tipos[length(tipos)])
  ext <- if (grepl("\\.gz([?#].*)?$", url)) ".ndjson.gz" else ".ndjson"
  paste0(tipo, if (n > 1L) paste0("_", n), ext)
}

origen_url <- function(url) {
  tolower(sub("^(https?://[^/?#]+).*$", "\\1", url))
}

descargar_archivo <- function(con, url, archivo, con_token) {
  if (!es_texto(url) || !grepl("^https?://", url)) {
    cli::cli_abort("El manifiesto tiene una URL de archivo no v\u00e1lida: {.val {url}}.",
                   class = "fhirviews_error_exportacion", call = NULL)
  }
  mismo_origen <- identical(origen_url(url), origen_url(con$url))
  req <- httr2::request(url)
  req <- httr2::req_user_agent(req, agente())
  req <- httr2::req_headers(req, Accept = "application/fhir+ndjson")
  if (mismo_origen) {
    req <- httr2::req_headers(req, !!!con$cabeceras)
  }
  # Token fijo o, con autenticación SMART, el token OAuth vigente
  usa_token <- con_token && (!is.null(con$token) || !is.null(con$auth))
  if (usa_token) {
    # El token solo se envía a archivos del propio servidor
    if (!mismo_origen) {
      cli::cli_abort(c(
        "El archivo {.url {url}} requiere el token, pero est\u00e1 en otro
         servidor.",
        "i" = "Por seguridad, el token solo se env\u00eda a
               {.url {origen_url(con$url)}}."
      ), class = "fhirviews_error_exportacion", call = NULL)
    }
    token <- con$token %||% token_acceso(con)
    req <- httr2::req_auth_bearer_token(req, token)
  }
  # Sin tiempo total: los archivos pueden ser grandes. Se corta si la
  # descarga se detiene durante `con$tiempo` segundos.
  req <- httr2::req_options(req, connecttimeout = con$tiempo,
                            low_speed_time = con$tiempo, low_speed_limit = 1L)
  req <- httr2::req_retry(req, max_tries = 3L, is_transient = function(resp) {
    httr2::resp_status(resp) %in% c(429L, 503L)
  })
  req <- httr2::req_error(req, is_error = function(resp) FALSE)
  resp <- tryCatch(httr2::req_perform(req, path = archivo), error = function(e) {
    unlink(archivo)
    cli::cli_abort(c(
      "No se pudo descargar un archivo de la exportaci\u00f3n.",
      "x" = "GET {url_mensaje(url)}",
      "i" = "{limpiar_mensaje(conditionMessage(e))}"
    ), class = c("fhirviews_error_conexion", "fhirviews_error"), call = NULL)
  })
  if (!file.exists(archivo)) {
    # Respuestas guardadas en memoria (por ejemplo, simuladas)
    writeBin(if (httr2::resp_has_body(resp)) httr2::resp_body_raw(resp) else
      raw(), archivo)
  }
  estado <- httr2::resp_status(resp)
  if (estado >= 400L) {
    texto <- if (file.exists(archivo)) {
      paste(readLines(archivo, encoding = "UTF-8", warn = FALSE), collapse = "\n")
    } else {
      ""
    }
    unlink(archivo)
    datos <- tryCatch(jsonlite::fromJSON(texto, simplifyVector = FALSE),
                      error = function(e) NULL)
    error_http("GET", url, estado, httr2::resp_status_desc(resp), datos, texto)
  }
  invisible(archivo)
}

avisar_errores_exportacion <- function(archivos) {
  oo <- tryCatch(fhir_recursos(archivos), error = function(e) list())
  problemas <- unlist(lapply(oo, function(o) {
    if (!identical(o$resourceType, "OperationOutcome")) return(NULL)
    tabla_outcome(o)$mensaje
  }))
  problemas <- escapar_cli(utils::head(problemas[!is.na(problemas)], 5L))
  cli::cli_warn(c(
    "El servidor inform\u00f3 problemas durante la exportaci\u00f3n.",
    stats::setNames(problemas, rep("*", length(problemas))),
    "i" = "Detalle en {.file {archivos}}."
  ), class = "fhirviews_aviso")
}

conteo_manifiesto <- function(salida) {
  tipos <- vapply(salida, function(f) as.character(f$type %||% NA), character(1))
  n <- vapply(salida, function(f) {
    if (is.numeric(f$count)) as.numeric(f$count) else NA_real_
  }, numeric(1))
  if (length(tipos) == 0L) {
    return(stats::setNames(numeric(), character()))
  }
  conteo <- tapply(n, tipos, function(v) if (anyNA(v)) NA_real_ else sum(v))
  stats::setNames(as.numeric(conteo), names(conteo))
}
