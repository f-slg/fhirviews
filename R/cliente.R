#' Conectarse a un servidor FHIR
#'
#' Crea una conexión a un servidor HL7 FHIR R4 que usan las demás funciones
#' `fhir_*`. Las peticiones piden y envían `application/fhir+json`, se
#' reintentan si el servidor está saturado (códigos 429 y 503) y los errores
#' muestran el `OperationOutcome` del servidor.
#'
#' @param url Dirección base del servidor, por ejemplo
#'   `"https://hapi.fhir.org/baseR4"` o `"http://localhost:8080/fhir"`.
#' @param token Token de acceso (OAuth2 *bearer*) opcional. No se muestra al
#'   imprimir la conexión, solo se envía a URL del propio servidor y, si el
#'   servidor no usa https (y no es local), se avisa de que viajaría sin
#'   cifrar. Para no escribirlo en el código, guárdalo en una
#'   variable de entorno y usa por ejemplo `Sys.getenv("FHIR_TOKEN")`.
#'   Para tokens que caducan, usa mejor `autenticacion`.
#' @param autenticacion Autenticación SMART on FHIR / OAuth2 creada con
#'   [fhir_auth_cliente()], [fhir_auth_backend()] o
#'   [fhir_auth_interactiva()]. Las URL del servidor de autorización se
#'   descubren con [fhir_smart_configuracion()] si no se indican. El token se
#'   pide en la primera petición, se renueva solo al expirar y, como con
#'   `token`, solo se envía al propio servidor. No se puede usar junto con
#'   `token`.
#' @param cabeceras Lista con nombre de cabeceras HTTP adicionales.
#' @param tiempo Segundos de espera máxima por petición.
#' @param verificar Si es `TRUE` (por defecto), consulta el `CapabilityStatement`
#'   (`GET [base]/metadata`) para comprobar que el servidor responde y anotar
#'   su software y versión de FHIR.
#' @param panel Si es `TRUE` (por defecto) y se usa RStudio, registra la
#'   conexión en el panel *Connections* (ver [fhir_conexion_activa()]).
#'
#' @return Un objeto de clase `fhir_conexion`, que además queda como conexión
#'   activa para los addins y [fhir_ejecutar_texto()].
#' @seealso [fhir_buscar()], [fhir_leer()], [fhir_crear()], [fhir_peticion()],
#'   [fhir_auth].
#' @export
#' @examplesIf fhir_disponible("https://hapi.fhir.org/baseR4")
#' con <- fhir_conectar("https://hapi.fhir.org/baseR4")
#' con
#' @examplesIf interactive()
#' # Servidor protegido con SMART Backend Services
#' con <- fhir_conectar(
#'   "https://fhir.ejemplo.org/r4",
#'   autenticacion = fhir_auth_backend("mi-cliente", "privada.pem",
#'                                     kid = "clave-2026")
#' )
fhir_conectar <- function(url, token = NULL, cabeceras = list(), tiempo = 60,
                          verificar = TRUE, panel = TRUE,
                          autenticacion = NULL) {
  texto_simple(url, "url")
  if (!grepl("^https?://", url)) {
    cli::cli_abort("{.arg url} debe empezar con {.val http://} o {.val https://}.",
                   class = "fhirviews_error")
  }
  if (!is.null(token)) texto_simple(token, "token")
  if (!is.null(autenticacion)) {
    if (!inherits(autenticacion, "fhir_auth")) {
      cli::cli_abort(c(
        "{.arg autenticacion} debe crearse con {.fn fhir_auth_cliente},
         {.fn fhir_auth_backend} o {.fn fhir_auth_interactiva}.",
        "x" = "Se recibi\u00f3 un objeto de clase {.cls {class(autenticacion)}}."
      ), class = "fhirviews_error")
    }
    if (!is.null(token)) {
      cli::cli_abort("Usa {.arg token} o {.arg autenticacion}, no ambos.",
                     class = "fhirviews_error")
    }
  }
  if (!is.null(token) || !is.null(autenticacion)) {
    avisar_http(url, "El token")
  }
  if (length(cabeceras) > 0L &&
      (is.null(names(cabeceras)) || any(!nzchar(names(cabeceras))))) {
    cli::cli_abort("{.arg cabeceras} debe ser una lista con nombre.",
                   class = "fhirviews_error")
  }
  con <- structure(
    list(url = sub("/+$", "", url), token = token,
         cabeceras = as.list(cabeceras), tiempo = tiempo,
         servidor = NA_character_, version_fhir = NA_character_,
         auth = NULL),
    class = "fhir_conexion"
  )
  if (!is.null(autenticacion)) {
    con$auth <- preparar_auth(autenticacion, con$url, tiempo)
  }
  if (verificar) {
    cs <- peticion_json(con, "GET", "metadata")$datos
    software <- cs$software
    con$servidor <- trimws(paste(software$name %||% "", software$version %||% ""))
    con$version_fhir <- cs$fhirVersion %||% NA_character_
  }
  .fhirviews$activa <- con
  if (panel) {
    abrir_panel(con)
  }
  con
}

#' @export
print.fhir_conexion <- function(x, ...) {
  cat("<fhir_conexion> ", x$url, "\n", sep = "")
  if (!is.na(x$servidor) && nzchar(x$servidor)) {
    cat("  Servidor:     ", x$servidor, "\n", sep = "")
  }
  if (!is.na(x$version_fhir)) {
    cat("  Versi\u00f3n FHIR: ", x$version_fhir, "\n", sep = "")
  }
  if (!is.null(x$token)) cat("  Token:        (oculto)\n")
  if (!is.null(x$auth)) {
    cat("  Autenticaci\u00f3n: ", etiqueta_auth(x$auth$tipo), "\n", sep = "")
    cat("  Cliente:      ", x$auth$id, "\n", sep = "")
  }
  invisible(x)
}

#' Comprobar si un servidor FHIR responde
#'
#' Hace una petición rápida a `[base]/metadata`. Útil para omitir ejemplos o
#' pruebas cuando no hay conexión.
#'
#' @param url Dirección base del servidor.
#' @param tiempo Segundos de espera máxima.
#'
#' @return `TRUE` si el servidor responde con éxito; `FALSE` si no.
#' @export
#' @examples
#' fhir_disponible("https://hapi.fhir.org/baseR4")
fhir_disponible <- function(url, tiempo = 5) {
  req <- httr2::request(paste0(sub("/+$", "", url), "/metadata"))
  req <- httr2::req_headers(req, Accept = "application/fhir+json")
  req <- httr2::req_timeout(req, tiempo)
  req <- httr2::req_error(req, is_error = function(resp) FALSE)
  resp <- tryCatch(httr2::req_perform(req), error = function(e) NULL)
  !is.null(resp) && httr2::resp_status(resp) < 400L
}

#' Hacer una petición FHIR cualquiera
#'
#' Envía una petición HTTP al servidor, al estilo de Postman, y devuelve el
#' cuerpo de la respuesta como lista de R. Las demás funciones `fhir_*`
#' cubren los casos habituales; esta sirve para todo lo demás (operaciones
#' `$`, historial, `_history`, peticiones condicionales, etc.).
#'
#' @param con Conexión creada con [fhir_conectar()].
#' @param metodo Método HTTP: `"GET"`, `"POST"`, `"PUT"`, `"PATCH"` o
#'   `"DELETE"`.
#' @param ruta Ruta relativa a la base (por ejemplo `"Patient/123/_history"`
#'   o `"Patient?family=Paredes"`) o URL completa.
#' @param cuerpo Cuerpo de la petición: lista de R, texto JSON o ruta a un
#'   archivo JSON.
#' @param parametros Lista con nombre de parámetros de consulta. Un vector
#'   repite el parámetro (equivale a un *Y* en búsquedas FHIR).
#' @param cabeceras Lista con nombre de cabeceras adicionales.
#'
#' @return El cuerpo de la respuesta como lista de R de clase
#'   `fhir_respuesta` (vacía si el servidor no devolvió cuerpo), con los
#'   atributos `estado` (código HTTP) y `cabeceras`. Al imprimirla muestra el
#'   estado y el JSON con sangría, como Postman. Si es un Bundle, se puede
#'   pasar a [fhir_recursos()], [fhir_tabla()] o [vista_ejecutar()].
#' @export
#' @examplesIf fhir_disponible("https://hapi.fhir.org/baseR4")
#' con <- fhir_conectar("https://hapi.fhir.org/baseR4")
#' r <- fhir_peticion(con, "GET", "Patient", parametros = list(`_count` = 1,
#'                                                           `_summary` = "count"))
#' r$total
fhir_peticion <- function(con, metodo = "GET", ruta = "", cuerpo = NULL,
                          parametros = list(), cabeceras = list()) {
  comprobar_conexion(con)
  metodo <- toupper(metodo)
  res <- peticion_json(con, metodo, ruta, cuerpo = cuerpo_json(cuerpo),
                       parametros = parametros, cabeceras = cabeceras)
  nueva_respuesta(res)
}

nueva_respuesta <- function(res) {
  datos <- res$datos
  if (is.null(datos)) datos <- list()
  structure(datos, class = c("fhir_respuesta", "list"), estado = res$estado,
            cabeceras = res$cabeceras, texto = res$texto)
}

#' @export
print.fhir_respuesta <- function(x, ..., lineas = 40L) {
  estado <- attr(x, "estado")
  tipo <- x$resourceType
  resumen <- if (is.null(tipo)) "sin cuerpo" else tipo
  if (identical(tipo, "Bundle")) {
    resumen <- paste0("Bundle (", x$type %||% "?",
                      if (!is.null(x$total)) paste0(", total ", x$total),
                      ", ", length(x$entry), " entradas)")
  } else if (!is.null(x$id)) {
    resumen <- paste0(tipo, "/", x$id)
  }
  cat("<fhir_respuesta> ", estado %||% "", " \u00b7 ", resumen, "\n", sep = "")
  if (length(x) > 0L) {
    json <- strsplit(as.character(jsonlite::toJSON(
      unclass(x), auto_unbox = TRUE, pretty = TRUE, null = "null",
      digits = NA)), "\n")[[1]]
    cat(utils::head(json, lineas), sep = "\n")
    if (length(json) > lineas) {
      cat("... (", length(json) - lineas, " l\u00edneas m\u00e1s)\n", sep = "")
    }
  }
  invisible(x)
}

#' Buscar recursos con paginación automática
#'
#' Hace una búsqueda FHIR (`GET [base]/[tipo]?parametros`) y sigue los
#' enlaces `next` de cada Bundle hasta reunir todos los resultados.
#'
#' @param con Conexión creada con [fhir_conectar()].
#' @param recurso Tipo de recurso, por ejemplo `"Patient"` u `"Observation"`.
#' @param ... Parámetros de búsqueda con nombre, por ejemplo
#'   `family = "Paredes"`, `birthdate = "ge1980-01-01"` o
#'   `` `_count` = 100 ``. Un vector repite el parámetro (Y lógico); para un O
#'   lógico usa comas dentro del texto (`code = "8480-6,8462-4"`).
#' @param parametros Lista con nombre de parámetros adicionales, útil para
#'   nombres como `"subject:Patient"` o construidos en un programa.
#' @param max_paginas Número máximo de páginas que se descargan.
#' @param progreso Si es `TRUE`, muestra el avance (por defecto, en sesiones
#'   interactivas).
#'
#' @return Una lista de recursos de clase `fhir_recursos` (ver
#'   [fhir_recursos()]) que se puede pasar directamente a [vista_ejecutar()].
#'   El atributo `total` guarda el total que informa el servidor, si lo hace.
#' @export
#' @examplesIf fhir_disponible("https://hapi.fhir.org/baseR4")
#' con <- fhir_conectar("https://hapi.fhir.org/baseR4")
#' pacientes <- fhir_buscar(con, "Patient", gender = "female", `_count` = 5,
#'                          max_paginas = 1)
#' pacientes
#' vista_ejecutar(pacientes, vista_crear("Patient", c(nacimiento = "birthDate")))
fhir_buscar <- function(con, recurso, ..., parametros = list(),
                        max_paginas = Inf, progreso = interactive()) {
  comprobar_conexion(con)
  texto_simple(recurso, "recurso")
  paginar(con, recurso, c(parametros_busqueda(list(...)),
                          parametros_busqueda(parametros)),
          max_paginas, progreso)
}

#' Leer un recurso
#'
#' Lee un recurso por su tipo e id (`GET [base]/[tipo]/[id]`), o una versión
#' concreta (`_history`).
#'
#' @param con Conexión creada con [fhir_conectar()].
#' @param recurso Tipo de recurso (`"Patient"`) o referencia completa
#'   (`"Patient/123"`).
#' @param id Id del recurso; no hace falta si `recurso` es una referencia.
#' @param version Versión opcional (`vid`) para leer el historial.
#'
#' @return El recurso como lista de R.
#' @export
#' @examplesIf fhir_disponible("https://hapi.fhir.org/baseR4")
#' con <- fhir_conectar("https://hapi.fhir.org/baseR4")
#' uno <- fhir_buscar(con, "Patient", `_count` = 1, max_paginas = 1)
#' paciente <- fhir_leer(con, "Patient", uno[[1]]$id)
#' paciente$resourceType
fhir_leer <- function(con, recurso, id = NULL, version = NULL) {
  comprobar_conexion(con)
  ruta <- ruta_recurso(recurso, id)
  if (!is.null(version)) ruta <- paste0(ruta, "/_history/", version)
  peticion_json(con, "GET", ruta)$datos
}

#' Todos los datos de un paciente u otro compartimento ($everything)
#'
#' Ejecuta la operación `$everything` (`GET [base]/Patient/[id]/$everything`)
#' y sigue la paginación del Bundle que devuelve.
#'
#' @inheritParams fhir_buscar
#' @param recurso Tipo de recurso del compartimento; casi siempre
#'   `"Patient"` (también existe para `"Encounter"` en algunos servidores).
#' @param id Id del recurso.
#'
#' @return Una lista de recursos de clase `fhir_recursos`.
#' @export
#' @examplesIf fhir_disponible("https://hapi.fhir.org/baseR4")
#' con <- fhir_conectar("https://hapi.fhir.org/baseR4")
#' uno <- fhir_buscar(con, "Patient", `_count` = 1, max_paginas = 1)
#' todo <- fhir_everything(con, "Patient", uno[[1]]$id, max_paginas = 1)
#' todo
fhir_everything <- function(con, recurso = "Patient", id, parametros = list(),
                            max_paginas = Inf, progreso = interactive()) {
  comprobar_conexion(con)
  ruta <- paste0(ruta_recurso(recurso, id), "/$everything")
  paginar(con, ruta, parametros_busqueda(parametros), max_paginas, progreso)
}

#' Crear, actualizar y borrar recursos
#'
#' * `fhir_crear()` envía un recurso nuevo (`POST [base]/[tipo]`); el
#'   servidor le asigna el id. Un Bundle de tipo `transaction` o `batch` se
#'   envía a la base del servidor (`POST [base]`), que lo procesa: crea,
#'   actualiza o borra cada entrada según su `request`.
#' * `fhir_actualizar()` reemplaza un recurso existente
#'   (`PUT [base]/[tipo]/[id]`), o lo crea con ese id si el servidor lo
#'   permite.
#' * `fhir_borrar()` lo elimina (`DELETE [base]/[tipo]/[id]`).
#'
#' @param con Conexión creada con [fhir_conectar()].
#' @param recurso Para crear o actualizar: el recurso como lista de R, texto
#'   JSON o ruta a un archivo JSON. Para borrar: el tipo de recurso
#'   (`"Patient"`), una referencia (`"Patient/123"`) o el recurso mismo.
#' @param id Para borrar, el id del recurso, si `recurso` es solo el tipo.
#'
#' @return `fhir_crear()` y `fhir_actualizar()` devuelven el recurso tal como
#'   lo guardó el servidor (con su id y `meta.versionId`); para un Bundle
#'   `transaction` o `batch`, el Bundle de respuesta del servidor
#'   (`transaction-response` o `batch-response`). `fhir_borrar()` devuelve
#'   `TRUE` de forma invisible.
#' @export
#' @examplesIf interactive() && fhir_disponible("http://localhost:8080/fhir")
#' # Con un servidor HAPI local (por ejemplo, el del taller aprende-fhir)
#' con <- fhir_conectar("http://localhost:8080/fhir")
#' paciente <- fhir_crear(con, list(
#'   resourceType = "Patient",
#'   name = list(list(family = "Paredes Cevallos", given = list("Ana"))),
#'   gender = "female", birthDate = "1985-03-12"
#' ))
#' paciente$id
#'
#' paciente$telecom <- list(list(system = "phone", value = "0991234567"))
#' paciente <- fhir_actualizar(con, paciente)
#' paciente$meta$versionId
#'
#' fhir_borrar(con, paciente)
fhir_crear <- function(con, recurso) {
  comprobar_conexion(con)
  datos <- leer_recurso(recurso)
  if (identical(datos$tipo, "Bundle") &&
      isTRUE(datos$tipo_bundle %in% c("transaction", "batch"))) {
    # Las transacciones se procesan en la base, no en [base]/Bundle (que
    # guardaría el Bundle como un recurso más)
    return(peticion_json(con, "POST", "", cuerpo = datos$json)$datos)
  }
  res <- peticion_json(con, "POST", datos$tipo, cuerpo = datos$json,
                       cabeceras = list(Prefer = "return=representation"))
  representacion(con, res)
}

#' @rdname fhir_crear
#' @export
fhir_actualizar <- function(con, recurso) {
  comprobar_conexion(con)
  datos <- leer_recurso(recurso)
  if (is.null(datos$id)) {
    cli::cli_abort(c(
      "El recurso no tiene {.field id}: no se sabe cu\u00e1l actualizar.",
      "i" = "Para un recurso nuevo usa {.fn fhir_crear}."
    ), class = "fhirviews_error")
  }
  res <- peticion_json(con, "PUT", paste0(datos$tipo, "/", datos$id),
                       cuerpo = datos$json,
                       cabeceras = list(Prefer = "return=representation"))
  representacion(con, res)
}

#' @rdname fhir_crear
#' @export
fhir_borrar <- function(con, recurso, id = NULL) {
  comprobar_conexion(con)
  if (is.list(recurso)) {
    ruta <- ruta_recurso(recurso$resourceType, recurso$id)
  } else {
    ruta <- ruta_recurso(recurso, id)
  }
  peticion_json(con, "DELETE", ruta)
  invisible(TRUE)
}

#' Validar un recurso en el servidor ($validate)
#'
#' Envía un recurso a la operación `$validate` del servidor
#' (`POST [base]/[tipo]/$validate`) y devuelve los problemas encontrados.
#'
#' @param con Conexión creada con [fhir_conectar()].
#' @param recurso El recurso como lista de R, texto JSON o ruta a un archivo.
#' @param perfil URL canónica opcional de un perfil (`StructureDefinition`)
#'   contra el que validar.
#'
#' @return Un `data.frame` de clase `fhir_validacion` con una fila por
#'   problema (`severidad`, `codigo`, `mensaje`, `ubicacion`) y el atributo
#'   `valido` (`TRUE` si no hay errores). Al imprimirlo, resume el resultado.
#' @export
#' @examplesIf fhir_disponible("https://hapi.fhir.org/baseR4")
#' con <- fhir_conectar("https://hapi.fhir.org/baseR4")
#' fhir_validar(con, list(resourceType = "Patient", gender = "mujer"))
fhir_validar <- function(con, recurso, perfil = NULL) {
  comprobar_conexion(con)
  datos <- leer_recurso(recurso)
  parametros <- if (!is.null(perfil)) list(profile = perfil) else list()
  res <- peticion_json(con, "POST", paste0(datos$tipo, "/$validate"),
                       cuerpo = datos$json, parametros = parametros,
                       permitir = c(400L, 412L, 422L))
  tabla <- tabla_outcome(res$datos)
  attr(tabla, "valido") <- !any(tabla$severidad %in% c("error", "fatal"))
  class(tabla) <- c("fhir_validacion", "data.frame")
  tabla
}

#' @export
print.fhir_validacion <- function(x, ...) {
  errores <- sum(x$severidad %in% c("error", "fatal"))
  avisos <- sum(x$severidad %in% "warning")
  plural <- function(n, s, p) paste(n, if (n == 1L) s else p)
  if (isTRUE(attr(x, "valido"))) {
    cat("V\u00e1lido (", plural(avisos, "advertencia", "advertencias"),
        ").\n", sep = "")
  } else {
    cat("No v\u00e1lido: ", plural(errores, "error", "errores"), " y ",
        plural(avisos, "advertencia", "advertencias"), ".\n", sep = "")
  }
  if (nrow(x) > 0L) {
    print(as.data.frame(unclass(x), stringsAsFactors = FALSE)[, c(
      "severidad", "codigo", "ubicacion", "mensaje")], right = FALSE)
  }
  invisible(x)
}

#' Capacidades del servidor
#'
#' Lee el `CapabilityStatement` (`GET [base]/metadata`) y resume qué
#' recursos admite el servidor y qué se puede hacer con cada uno.
#'
#' @param con Conexión creada con [fhir_conectar()].
#'
#' @return Un `data.frame` con una fila por tipo de recurso: `recurso`,
#'   `interacciones` (`read`, `search-type`, `create`...) y
#'   `parametros_busqueda`. El `CapabilityStatement` completo queda en el
#'   atributo `capability`.
#' @export
#' @examplesIf fhir_disponible("https://hapi.fhir.org/baseR4")
#' con <- fhir_conectar("https://hapi.fhir.org/baseR4")
#' cap <- fhir_capacidades(con)
#' head(cap)
fhir_capacidades <- function(con) {
  comprobar_conexion(con)
  cs <- peticion_json(con, "GET", "metadata")$datos
  recursos <- unlist(lapply(cs$rest, function(r) r$resource), recursive = FALSE)
  tabla <- data.frame(
    recurso = vapply(recursos, function(r) as.character(r$type %||% NA),
                     character(1)),
    interacciones = vapply(recursos, function(r) {
      paste(vapply(r$interaction, function(i) as.character(i$code),
                   character(1)), collapse = ", ")
    }, character(1)),
    parametros_busqueda = vapply(recursos, function(r) {
      paste(vapply(r$searchParam, function(p) as.character(p$name),
                   character(1)), collapse = ", ")
    }, character(1)),
    stringsAsFactors = FALSE
  )
  attr(tabla, "capability") <- cs
  tabla
}

# --- Internas ----------------------------------------------------------------

comprobar_conexion <- function(con) {
  if (!inherits(con, "fhir_conexion")) {
    cli::cli_abort(c(
      "{.arg con} debe ser una conexi\u00f3n creada con {.fn fhir_conectar}.",
      "x" = "Se recibi\u00f3 un objeto de clase {.cls {class(con)}}."
    ), class = "fhirviews_error", call = rlang::caller_env())
  }
}

url_completa <- function(con, ruta) {
  if (grepl("^https?://", ruta)) {
    return(ruta)
  }
  ruta <- sub("^/+", "", ruta)
  if (!nzchar(ruta)) con$url else paste0(con$url, "/", ruta)
}

# El token solo se envía a la base del servidor o a rutas bajo ella
mismo_servidor <- function(con, url) {
  identical(url, con$url) || startsWith(url, paste0(con$url, "/")) ||
    startsWith(url, paste0(con$url, "?"))
}

agente <- function() {
  paste0("fhirviews/", utils::packageVersion("fhirviews"),
         " (https://github.com/f-slg/fhirviews)")
}

# Envía la petición y devuelve estado, cabeceras, datos (lista) y texto. Si
# el servidor responde con error (y el código no está en `permitir`), lanza
# un error con el OperationOutcome.
peticion_json <- function(con, metodo, ruta, cuerpo = NULL,
                          parametros = list(), cabeceras = list(),
                          permitir = integer()) {
  url <- url_completa(con, ruta)
  # El token solo se envía al servidor de la conexión, no a otras URL
  oauth <- !is.null(con$auth) && is.null(con$token) && mismo_servidor(con, url)
  resp <- enviar_peticion(con, metodo, url, cuerpo, parametros, cabeceras,
                          oauth = oauth)
  # Token rechazado (revocado o caducado antes de tiempo): se pide otro y se
  # reintenta una vez
  if (oauth && httr2::resp_status(resp) == 401L) {
    resp <- enviar_peticion(con, metodo, url, cuerpo, parametros, cabeceras,
                            oauth = oauth, renovar = TRUE)
  }

  estado <- httr2::resp_status(resp)
  texto <- if (httr2::resp_has_body(resp)) {
    httr2::resp_body_string(resp, encoding = "UTF-8")
  } else {
    ""
  }
  datos <- NULL
  if (nzchar(trimws(texto))) {
    datos <- tryCatch(jsonlite::fromJSON(texto, simplifyVector = FALSE),
                      error = function(e) NULL)
  }
  if (estado >= 400L && !estado %in% permitir) {
    error_http(metodo, url, estado, httr2::resp_status_desc(resp), datos,
               texto)
  }
  if (estado < 400L && nzchar(trimws(texto)) && is.null(datos)) {
    cli::cli_abort(c(
      "La respuesta del servidor no es JSON.",
      "x" = "{metodo} {url}",
      "i" = "Comienza con: {.val {substr(texto, 1, 80)}}"
    ), class = "fhirviews_error", call = NULL)
  }
  list(estado = estado, cabeceras = httr2::resp_headers(resp), datos = datos,
       texto = texto)
}

# Agrega los parametros de busqueda a la URL sin reconstruirla. Con
# httr2::req_url_query() la URL pasa por curl::curl_modify_url(), que con
# algunas versiones de libcurl codifica el `$` de las operaciones como `%24`
# (por ejemplo `ValueSet/%24expand`), y muchos servidores responden 404.
# Cada elemento de un vector se envia como un parametro repetido.
agregar_consulta <- function(url, parametros) {
  parametros <- parametros[!vapply(parametros, is.null, logical(1))]
  if (length(parametros) == 0L) {
    return(url)
  }
  pares <- unlist(Map(function(nombre, valor) {
    if (is.logical(valor)) {
      valor <- tolower(as.character(valor))
    } else if (is.numeric(valor)) {
      valor <- format(valor, scientific = FALSE, trim = TRUE)
    }
    paste0(codificar(nombre), "=", codificar(as.character(valor)))
  }, names(parametros), parametros), use.names = FALSE)
  paste0(url, if (grepl("?", url, fixed = TRUE)) "&" else "?",
         paste(pares, collapse = "&"))
}

codificar <- function(x) {
  vapply(enc2utf8(x), utils::URLencode, "", reserved = TRUE, USE.NAMES = FALSE)
}

enviar_peticion <- function(con, metodo, url, cuerpo, parametros, cabeceras,
                            oauth = FALSE, renovar = FALSE) {
  if (length(parametros) > 0L) {
    url <- agregar_consulta(url, parametros)
  }
  req <- httr2::request(url)
  req <- httr2::req_method(req, metodo)
  req <- httr2::req_user_agent(req, agente())
  req <- httr2::req_headers(req, Accept = "application/fhir+json",
                            !!!con$cabeceras, !!!cabeceras)
  if (oauth) {
    req <- httr2::req_auth_bearer_token(req, token_acceso(con, renovar))
  } else if (!is.null(con$token) && mismo_servidor(con, url)) {
    req <- httr2::req_auth_bearer_token(req, con$token)
  }
  if (!is.null(cuerpo)) {
    req <- httr2::req_body_raw(req, enc2utf8(cuerpo),
                               type = "application/fhir+json; charset=utf-8")
  }
  req <- httr2::req_timeout(req, con$tiempo)
  req <- httr2::req_retry(req, max_tries = 3L, is_transient = function(resp) {
    httr2::resp_status(resp) %in% c(429L, 503L)
  })
  req <- httr2::req_error(req, is_error = function(resp) FALSE)

  tryCatch(httr2::req_perform(req), error = function(e) {
    cli::cli_abort(c(
      "No se pudo conectar con el servidor FHIR.",
      "x" = "{metodo} {url}",
      "i" = "{limpiar_mensaje(conditionMessage(e))}"
    ), class = c("fhirviews_error_conexion", "fhirviews_error"), call = NULL)
  })
}

error_http <- function(metodo, url, estado, descripcion, datos, texto) {
  problemas <- character()
  if (identical(datos$resourceType, "OperationOutcome")) {
    tabla <- tabla_outcome(datos)
    problemas <- sprintf("[%s] %s%s", tabla$severidad, tabla$mensaje,
                         ifelse(is.na(tabla$ubicacion), "",
                                paste0(" (", tabla$ubicacion, ")")))
  } else if (nzchar(trimws(texto))) {
    problemas <- substr(gsub("\\s+", " ", texto), 1, 200)
  }
  problemas <- escapar_cli(utils::head(problemas, 10L))
  cli::cli_abort(c(
    "El servidor respondi\u00f3 {estado} {descripcion %||% ''}.",
    "x" = "{metodo} {url}",
    stats::setNames(problemas, rep("*", length(problemas)))
  ), class = c(paste0("fhirviews_error_http_", estado),
               "fhirviews_error_http", "fhirviews_error"),
  estado = estado, outcome = datos, call = NULL)
}

escapar_cli <- function(x) {
  gsub("\\}", "}}", gsub("\\{", "{{", x))
}

tabla_outcome <- function(oo) {
  problemas <- oo$issue
  texto <- function(x) if (is.null(x)) NA_character_ else
    paste(unlist(x), collapse = "; ")
  data.frame(
    severidad = vapply(problemas, function(i) texto(i$severity), character(1)),
    codigo = vapply(problemas, function(i) texto(i$code), character(1)),
    mensaje = vapply(problemas, function(i) {
      texto(i$diagnostics %||% i$details$text %||% i$details$coding[[1]]$display)
    }, character(1)),
    ubicacion = vapply(problemas, function(i) {
      texto(i$expression %||% i$location)
    }, character(1)),
    stringsAsFactors = FALSE
  )
}

# Convierte los parámetros de búsqueda en texto
parametros_busqueda <- function(x) {
  if (length(x) == 0L) {
    return(list())
  }
  if (is.null(names(x)) || any(!nzchar(names(x)))) {
    cli::cli_abort(c(
      "Los par\u00e1metros de b\u00fasqueda deben tener nombre.",
      "i" = "Por ejemplo: {.code family = \"Paredes\"}."
    ), class = "fhirviews_error", call = NULL)
  }
  lapply(x, function(v) {
    if (inherits(v, "Date")) {
      format(v, "%Y-%m-%d")
    } else if (is.logical(v)) {
      tolower(as.character(v))
    } else {
      as.character(v)
    }
  })
}

paginar <- function(con, ruta, parametros, max_paginas, progreso) {
  textos <- character()
  recursos <- list()
  total <- NULL
  siguiente <- NULL
  visitadas <- character()
  pagina <- 0L
  if (progreso) {
    cli::cli_progress_bar(format = paste(
      "{cli::pb_spin} Descargando p\u00e1gina {pagina}",
      "({length(recursos)} recursos)"
    ), clear = TRUE)
  }
  repeat {
    pagina <- pagina + 1L
    res <- if (is.null(siguiente)) {
      peticion_json(con, "GET", ruta, parametros = parametros)
    } else {
      peticion_json(con, "GET", siguiente)
    }
    bundle <- res$datos
    if (!identical(bundle$resourceType, "Bundle")) {
      cli::cli_abort(c(
        "El servidor no devolvi\u00f3 un Bundle.",
        "x" = "Devolvi\u00f3 {.val {bundle$resourceType %||% 'nada'}}."
      ), class = "fhirviews_error", call = NULL)
    }
    if (pagina == 1L) total <- bundle$total
    textos <- c(textos, res$texto)
    recursos <- c(recursos, recursos_desde_lista(bundle))
    if (progreso) cli::cli_progress_update()
    if (!is.null(siguiente)) visitadas <- c(visitadas, siguiente)
    siguiente <- enlace_siguiente(bundle, con)
    if (!is.null(siguiente) && siguiente %in% visitadas) {
      cli::cli_warn(c(
        "El servidor repiti\u00f3 un enlace {.field next} ya visitado; se
         detiene la paginaci\u00f3n para no entrar en un bucle.",
        "i" = "Se reunieron {length(recursos)} recurso{?s} en {pagina}
               p\u00e1gina{?s}."
      ), class = "fhirviews_aviso")
      break
    }
    if (is.null(siguiente) || pagina >= max_paginas) break
  }
  if (progreso) cli::cli_progress_done()
  r <- nuevo_fhir_recursos(recursos, fuente = textos)
  attr(r, "total") <- total
  r
}

enlace_siguiente <- function(bundle, con) {
  for (l in bundle$link) {
    if (identical(l$relation, "next") && es_texto(l$url)) {
      return(url_completa(con, l$url))
    }
  }
  NULL
}

ruta_recurso <- function(recurso, id = NULL) {
  texto_simple(recurso, "recurso")
  if (is.null(id)) {
    if (!grepl("^[A-Za-z]+/[^/]+", recurso)) {
      cli::cli_abort(c(
        "Falta el id del recurso.",
        "i" = "Usa {.code fhir_leer(con, \"Patient\", \"123\")} o
               {.code fhir_leer(con, \"Patient/123\")}."
      ), class = "fhirviews_error", call = NULL)
    }
    return(recurso)
  }
  paste0(recurso, "/", texto_simple(as.character(id), "id"))
}

# Recurso a enviar: lista, texto JSON o archivo -> tipo, id y JSON
leer_recurso <- function(recurso) {
  if (is.character(recurso) && length(recurso) == 1L) {
    if (!grepl("^\\s*[[{]", recurso) && file.exists(recurso)) {
      recurso <- paste(readLines(recurso, encoding = "UTF-8", warn = FALSE),
                       collapse = "\n")
    }
    json <- recurso
    datos <- parsear_json(json)
  } else if (is.list(recurso)) {
    datos <- unclass(recurso)
    json <- as.character(a_json(datos))
  } else {
    cli::cli_abort(
      "{.arg recurso} debe ser una lista de R, texto JSON o la ruta a un archivo.",
      class = "fhirviews_error", call = NULL
    )
  }
  if (!es_texto(datos$resourceType)) {
    cli::cli_abort("El recurso no tiene {.field resourceType}.",
                   class = "fhirviews_error", call = NULL)
  }
  tipo_bundle <- datos$type
  list(tipo = datos$resourceType, id = datos$id,
       tipo_bundle = if (is.character(tipo_bundle)) tipo_bundle,
       json = json)
}

cuerpo_json <- function(cuerpo) {
  if (is.null(cuerpo)) {
    return(NULL)
  }
  if (is.character(cuerpo) && length(cuerpo) == 1L) {
    if (!grepl("^\\s*[[{]", cuerpo) && file.exists(cuerpo)) {
      return(paste(readLines(cuerpo, encoding = "UTF-8", warn = FALSE),
                   collapse = "\n"))
    }
    return(cuerpo)
  }
  as.character(a_json(unclass(cuerpo)))
}

# Recurso devuelto por el servidor tras crear o actualizar; si no vino en el
# cuerpo, se lee desde la cabecera Location.
representacion <- function(con, res) {
  if (!is.null(res$datos) && !identical(res$datos$resourceType,
                                         "OperationOutcome")) {
    return(res$datos)
  }
  ubicacion <- res$cabeceras[["location"]] %||% res$cabeceras[["content-location"]]
  if (is.null(ubicacion)) {
    return(res$datos)
  }
  ruta <- sub("/_history/.*$", "", ubicacion)
  peticion_json(con, "GET", ruta)$datos
}
