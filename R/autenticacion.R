#' Autenticación SMART on FHIR (OAuth2)
#'
#' Crean la configuración de autenticación que se pasa a [fhir_conectar()] en
#' el argumento `autenticacion`, para servidores protegidos con
#' [SMART on FHIR](https://hl7.org/fhir/smart-app-launch/):
#'
#' * `fhir_auth_cliente()`: flujo *client credentials* con un secreto
#'   compartido (cliente confidencial simétrico).
#' * `fhir_auth_backend()`: [SMART Backend
#'   Services](https://hl7.org/fhir/smart-app-launch/backend-services.html),
#'   *client credentials* en el que el cliente se identifica con un JWT
#'   firmado (RS384 o ES384) con su clave privada, sin secreto compartido.
#'   Es el flujo habitual entre sistemas (exportaciones, tableros, ETL).
#' * `fhir_auth_interactiva()`: flujo *authorization code* con PKCE y
#'   lanzamiento *standalone*: abre el navegador para que la persona inicie
#'   sesión y autorice el acceso. Solo en sesiones interactivas.
#'
#' Si no se indican `url_token` (ni `url_autorizacion`, en el flujo
#' interactivo), [fhir_conectar()] los descubre con
#' [fhir_smart_configuracion()]. El token se pide al hacer la primera
#' petición, se guarda en memoria, se renueva solo cuando expira (o con el
#' *refresh token*, en el flujo interactivo) y solo se envía a URL del propio
#' servidor FHIR. Ni el token ni el secreto ni la clave se muestran al
#' imprimir la conexión o este objeto.
#'
#' @param id Identificador del cliente (`client_id`) registrado en el
#'   servidor de autorización.
#' @param secreto Secreto del cliente (`client_secret`). Para no escribirlo en
#'   el código, guárdalo en una variable de entorno y usa por ejemplo
#'   `Sys.getenv("FHIR_SECRETO")`. En `fhir_auth_interactiva()` es opcional
#'   (solo para clientes confidenciales).
#' @param alcances Vector de *scopes* SMART, por ejemplo
#'   `c("system/Patient.read", "system/Observation.read")` o, en SMART v2,
#'   `"system/*.rs"`.
#' @param url_token URL del *token endpoint*. Si es `NULL`, se descubre.
#' @param envio Cómo se envía el secreto al pedir el token: `"cabecera"`
#'   (HTTP Basic, `client_secret_basic`) o `"cuerpo"` (`client_secret_post`).
#'   Si es `NULL`, se usa la cabecera salvo que el servidor declare que solo
#'   admite el cuerpo.
#' @param clave_privada Clave privada RSA (de al menos 2048 bits, firma
#'   RS384) o EC de la curva P-384 (firma ES384): ruta a un archivo PEM, el
#'   texto PEM o un objeto `key` del paquete openssl. La clave pública
#'   correspondiente (su JWKS) debe estar registrada en el servidor.
#' @param kid Identificador de la clave (`kid`) que se pone en la cabecera
#'   del JWT; SMART lo pide para que el servidor elija la clave pública.
#' @param contrasena Contraseña de la clave privada, si está cifrada.
#' @param url_autorizacion URL del *authorization endpoint*. Si es `NULL`, se
#'   descubre.
#' @param redireccion URL de redirección registrada para el cliente. Con una
#'   dirección local (`http://localhost:puerto/`), R recibe la respuesta
#'   del navegador (requiere el paquete httpuv).
#' @param cache_disco Si es `TRUE`, guarda el token en el disco (cifrado por
#'   httr2) para no tener que iniciar sesión en cada sesión de R.
#'
#' @return Un objeto de clase `fhir_auth` para el argumento `autenticacion`
#'   de [fhir_conectar()].
#' @seealso [fhir_conectar()], [fhir_smart_configuracion()].
#' @name fhir_auth
#' @examplesIf interactive()
#' # Cliente con secreto (client credentials)
#' con <- fhir_conectar(
#'   "https://fhir.ejemplo.org/r4",
#'   autenticacion = fhir_auth_cliente(
#'     "mi-cliente", Sys.getenv("FHIR_SECRETO"),
#'     alcances = "system/*.read"
#'   )
#' )
#'
#' # SMART Backend Services con clave privada
#' con <- fhir_conectar(
#'   "https://fhir.ejemplo.org/r4",
#'   autenticacion = fhir_auth_backend(
#'     "mi-cliente", "~/.claves/fhir-privada.pem",
#'     alcances = c("system/Patient.read", "system/Observation.read"),
#'     kid = "clave-2026"
#'   )
#' )
#'
#' # Inicio de sesión en el navegador (authorization code + PKCE)
#' con <- fhir_conectar(
#'   "https://launch.smarthealthit.org/v/r4/fhir",
#'   autenticacion = fhir_auth_interactiva("mi-app")
#' )
NULL

#' @rdname fhir_auth
#' @export
fhir_auth_cliente <- function(id, secreto, alcances = "system/*.read",
                              url_token = NULL, envio = NULL) {
  texto_simple(id, "id")
  texto_simple(secreto, "secreto")
  if (!is.null(envio)) {
    envio <- rlang::arg_match(envio, c("cabecera", "cuerpo"))
  }
  nueva_auth("cliente", id, alcances, url_token = url_token,
             secreto = secreto, envio = envio)
}

#' @rdname fhir_auth
#' @export
fhir_auth_backend <- function(id, clave_privada, alcances = "system/*.read",
                              kid = NULL, contrasena = NULL,
                              url_token = NULL) {
  texto_simple(id, "id")
  if (!is.null(kid)) texto_simple(kid, "kid")
  rlang::check_installed(c("jose", "openssl"),
                         reason = "para firmar el JWT de SMART Backend Services.")
  clave <- leer_clave(clave_privada, contrasena)
  nueva_auth("backend", id, alcances, url_token = url_token, clave = clave,
             kid = kid)
}

#' @rdname fhir_auth
#' @export
fhir_auth_interactiva <- function(id,
                                  alcances = c("openid", "fhirUser",
                                               "launch/patient",
                                               "patient/*.read"),
                                  secreto = NULL, url_autorizacion = NULL,
                                  url_token = NULL,
                                  redireccion = "http://localhost:1410/",
                                  cache_disco = FALSE) {
  texto_simple(id, "id")
  if (!is.null(secreto)) texto_simple(secreto, "secreto")
  texto_simple(redireccion, "redireccion")
  if (grepl("^http://(localhost|127\\.0\\.0\\.1)([:/]|$)", redireccion)) {
    rlang::check_installed("httpuv",
                           reason = "para recibir la respuesta del navegador.")
  }
  nueva_auth("interactiva", id, alcances, url_token = url_token,
             secreto = secreto, url_autorizacion = url_autorizacion,
             redireccion = redireccion, cache_disco = isTRUE(cache_disco))
}

#' @export
print.fhir_auth <- function(x, ...) {
  cat("<fhir_auth> ", etiqueta_auth(x$tipo), "\n", sep = "")
  cat("  Cliente:  ", x$id, "\n", sep = "")
  cat("  Alcances: ", x$alcances, "\n", sep = "")
  if (!is.null(x$secreto)) cat("  Secreto:  (oculto)\n")
  if (!is.null(x$clave)) {
    cat("  Clave:    (oculta, firma ", alg_clave(x$clave), ")\n", sep = "")
  }
  if (!is.null(x$url_token)) cat("  Token:    ", x$url_token, "\n", sep = "")
  invisible(x)
}

#' Descubrir la configuración SMART de un servidor
#'
#' Lee `[base]/.well-known/smart-configuration` y, si el servidor no lo
#' publica, busca las extensiones `oauth-uris` en la seguridad del
#' `CapabilityStatement` (`[base]/metadata`), como en SMART v1. Así se
#' obtienen las URL del servidor de autorización que usa [fhir_conectar()]
#' con [fhir_auth_cliente()], [fhir_auth_backend()] o
#' [fhir_auth_interactiva()].
#'
#' @param url Dirección base del servidor FHIR.
#' @param tiempo Segundos de espera máxima por petición.
#'
#' @return Una lista con `token_endpoint`, `authorization_endpoint` (o
#'   `NULL`), `fuente` (`"smart-configuration"` o `"CapabilityStatement"`) y
#'   `configuracion` (el documento completo leído).
#' @seealso [fhir_auth].
#' @export
#' @examplesIf interactive()
#' cfg <- fhir_smart_configuracion("https://launch.smarthealthit.org/v/r4/fhir")
#' cfg$token_endpoint
fhir_smart_configuracion <- function(url, tiempo = 30) {
  texto_simple(url, "url")
  url <- sub("/+$", "", url)
  cfg <- obtener_json(paste0(url, "/.well-known/smart-configuration"), tiempo)
  if (is.list(cfg) && es_texto(cfg$token_endpoint)) {
    return(list(token_endpoint = cfg$token_endpoint,
                authorization_endpoint = cfg$authorization_endpoint,
                fuente = "smart-configuration", configuracion = cfg))
  }
  cs <- obtener_json(paste0(url, "/metadata"), tiempo)
  uris <- uris_oauth(cs)
  if (es_texto(uris$token)) {
    return(list(token_endpoint = uris$token,
                authorization_endpoint = uris$authorize,
                fuente = "CapabilityStatement", configuracion = cs))
  }
  cli::cli_abort(c(
    "No se encontr\u00f3 la configuraci\u00f3n SMART de {.url {url}}.",
    "x" = "No responde {.path .well-known/smart-configuration} ni declara
           {.field oauth-uris} en su {.field CapabilityStatement}.",
    "i" = "Indica las URL con el argumento {.arg url_token} (y
           {.arg url_autorizacion})."
  ), class = c("fhirviews_error_autenticacion", "fhirviews_error"))
}

# --- Internas ----------------------------------------------------------------

nueva_auth <- function(tipo, id, alcances, url_token = NULL, secreto = NULL,
                       clave = NULL, kid = NULL, envio = NULL,
                       url_autorizacion = NULL, redireccion = NULL,
                       cache_disco = FALSE) {
  if (!is.character(alcances) || length(alcances) == 0L ||
      anyNA(alcances) || !all(nzchar(alcances))) {
    cli::cli_abort("{.arg alcances} debe ser un vector de texto no vac\u00edo.",
                   class = "fhirviews_error", call = rlang::caller_env())
  }
  if (!is.null(url_token)) texto_simple(url_token, "url_token")
  if (!is.null(url_autorizacion)) {
    texto_simple(url_autorizacion, "url_autorizacion")
  }
  structure(
    list(tipo = tipo, id = id, alcances = paste(alcances, collapse = " "),
         url_token = url_token, url_autorizacion = url_autorizacion,
         secreto = secreto, clave = clave, kid = kid, envio = envio,
         redireccion = redireccion, cache_disco = cache_disco),
    class = "fhir_auth"
  )
}

etiqueta_auth <- function(tipo) {
  switch(tipo,
         cliente = "SMART client credentials (secreto)",
         backend = "SMART Backend Services (JWT)",
         interactiva = "SMART authorization code + PKCE (standalone)")
}

leer_clave <- function(clave, contrasena = NULL) {
  if (!inherits(clave, "key")) {
    if (is.character(clave) && length(clave) == 1L && !grepl("BEGIN", clave)) {
      clave <- path.expand(clave)
      if (!file.exists(clave)) {
        cli::cli_abort("No existe el archivo de clave {.file {clave}}.",
                       class = "fhirviews_error", call = rlang::caller_env())
      }
    }
    args <- list(clave)
    if (!is.null(contrasena)) args$password <- contrasena
    clave <- tryCatch(do.call(openssl::read_key, args), error = function(e) {
      cli::cli_abort(c(
        "No se pudo leer la clave privada.",
        "i" = "{limpiar_mensaje(conditionMessage(e))}"
      ), class = "fhirviews_error", call = NULL)
    })
  }
  alg_clave(clave)
  clave
}

# Algoritmo de firma SMART que corresponde a la clave (RS384 o ES384)
alg_clave <- function(clave) {
  if (inherits(clave, "rsa")) {
    return("RS384")
  }
  if (inherits(clave, "ecdsa") &&
      identical(as.list(clave)$data$curve, "P-384")) {
    return("ES384")
  }
  cli::cli_abort(c(
    "La clave privada debe ser RSA o EC de la curva P-384.",
    "i" = "SMART Backend Services firma con RS384 o ES384."
  ), class = "fhirviews_error", call = NULL)
}

obtener_json <- function(url, tiempo) {
  req <- httr2::request(url)
  req <- httr2::req_user_agent(req, agente())
  req <- httr2::req_headers(req, Accept = "application/json, application/fhir+json")
  req <- httr2::req_timeout(req, tiempo)
  req <- httr2::req_error(req, is_error = function(resp) FALSE)
  resp <- tryCatch(httr2::req_perform(req), error = function(e) NULL)
  if (is.null(resp) || httr2::resp_status(resp) >= 400L ||
      !httr2::resp_has_body(resp)) {
    return(NULL)
  }
  tryCatch(jsonlite::fromJSON(httr2::resp_body_string(resp, encoding = "UTF-8"),
                              simplifyVector = FALSE),
           error = function(e) NULL)
}

# Extensiones oauth-uris de SMART v1 en CapabilityStatement.rest.security
uris_oauth <- function(cs) {
  if (!is.list(cs)) {
    return(list())
  }
  for (r in cs$rest) {
    for (ext in r$security$extension) {
      if (identical(ext$url, paste0("http://fhir-registry.smarthealthit.org/",
                                    "StructureDefinition/oauth-uris"))) {
        uris <- list()
        for (sub in ext$extension) {
          if (es_texto(sub$url) && es_texto(sub$valueUri)) {
            uris[[sub$url]] <- sub$valueUri
          }
        }
        return(uris)
      }
    }
  }
  list()
}

es_local <- function(url) {
  grepl("^https?://(localhost|127\\.0\\.0\\.1|\\[::1\\])([:/]|$)", url)
}

avisar_http <- function(url, que) {
  if (grepl("^http://", url) && !es_local(url)) {
    cli::cli_warn(c(
      "{que} se enviar\u00e1 sin cifrar: {.url {url}} usa http, no https.",
      "i" = "Usa la direcci\u00f3n https del servidor si la tiene."
    ), class = "fhirviews_aviso_seguridad", call = NULL)
  }
}

# Completa la configuración (descubrimiento SMART) y crea el cliente OAuth de
# httr2 que usará cada petición de la conexión
preparar_auth <- function(auth, base, tiempo) {
  cfg <- NULL
  if (is.null(auth$url_token) ||
      (auth$tipo == "interactiva" && is.null(auth$url_autorizacion))) {
    cfg <- fhir_smart_configuracion(base, tiempo)
  }
  url_token <- auth$url_token %||% cfg$token_endpoint
  url_autorizacion <- auth$url_autorizacion %||% cfg$authorization_endpoint
  if (auth$tipo == "interactiva" && !es_texto(url_autorizacion)) {
    cli::cli_abort(c(
      "El servidor no declara un {.field authorization_endpoint}.",
      "i" = "Ind\u00edcalo con {.arg url_autorizacion}."
    ), class = c("fhirviews_error_autenticacion", "fhirviews_error"),
    call = NULL)
  }
  avisar_http(url_token, "Las credenciales del cliente")

  metodo <- "body"
  parametros <- list()
  if (auth$tipo == "backend") {
    metodo <- "jwt_sig"
    # Lista y no jwt_claim(): httr2 crea en cada petición de token un JWT
    # nuevo (exp a 5 minutos y jti aleatorio)
    parametros <- list(
      claim = list(iss = auth$id, sub = auth$id, aud = url_token),
      size = 384L,
      header = if (!is.null(auth$kid)) list(kid = auth$kid) else list()
    )
  } else if (!is.null(auth$secreto)) {
    envio <- auth$envio
    if (is.null(envio)) {
      admitidos <- unlist(cfg$configuracion$token_endpoint_auth_methods_supported)
      envio <- if (!is.null(admitidos) &&
                   "client_secret_post" %in% admitidos &&
                   !"client_secret_basic" %in% admitidos) "cuerpo" else "cabecera"
    }
    metodo <- if (envio == "cuerpo") "body" else "header"
  }
  # El nombre identifica el token guardado: uno por cliente, servidor y
  # alcances
  nombre <- paste0("fhirviews-", rlang::hash(list(
    auth$tipo, auth$id, auth$secreto, url_token, base, auth$alcances)))
  cliente <- httr2::oauth_client(
    id = auth$id, token_url = url_token, secret = auth$secreto,
    key = auth$clave, auth = metodo, auth_params = parametros, name = nombre
  )
  list(tipo = auth$tipo, id = auth$id, alcances = auth$alcances,
       cliente = cliente, url_token = url_token,
       url_autorizacion = url_autorizacion, redireccion = auth$redireccion,
       cache_disco = isTRUE(auth$cache_disco))
}

# Flujo OAuth de httr2 y sus parámetros para la conexión
flujo_auth <- function(con) {
  a <- con$auth
  if (a$tipo == "interactiva") {
    list(flujo = httr2::oauth_flow_auth_code, parametros = list(
      auth_url = a$url_autorizacion, scope = a$alcances, pkce = TRUE,
      # aud: SMART pide la base del servidor FHIR en el lanzamiento standalone
      auth_params = list(aud = con$url), redirect_uri = a$redireccion
    ))
  } else {
    list(flujo = httr2::oauth_flow_client_credentials,
         parametros = list(scope = a$alcances))
  }
}

# Token de acceso vigente: httr2 lo pide la primera vez, lo guarda y lo
# renueva cuando expira (con el refresh token, si lo hay). Con `renovar`, se
# descarta el guardado y se pide otro.
token_acceso <- function(con, renovar = FALSE) {
  f <- flujo_auth(con)
  token <- tryCatch(
    httr2::oauth_token_cached(con$auth$cliente, f$flujo, f$parametros,
                              cache_disk = con$auth$cache_disco,
                              reauth = renovar),
    error = function(e) {
      cli::cli_abort(c(
        "No se pudo obtener el token de acceso.",
        "x" = "{.url {con$auth$url_token}}",
        "i" = "{limpiar_mensaje(conditionMessage(e))}"
      ), class = c("fhirviews_error_autenticacion", "fhirviews_error"),
      call = NULL)
    }
  )
  token$access_token
}
