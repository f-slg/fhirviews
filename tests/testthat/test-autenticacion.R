# Autenticacion SMART on FHIR con un servidor de autorizacion simulado

url_token <- "https://auth.test/token"

respuesta_token <- function(token, expira = 3600) {
  httr2::response_json(body = list(access_token = token, token_type = "bearer",
                                   expires_in = expira))
}

smart_cfg <- list(
  token_endpoint = url_token,
  authorization_endpoint = "https://auth.test/authorize",
  token_endpoint_auth_methods_supported = list("client_secret_basic",
                                               "private_key_jwt")
)

# Servidor FHIR + servidor de autorizacion: entrega tokens numerados
servidor_smart <- function(cfg = smart_cfg, expira = 3600) {
  emitidos <- 0L
  function(req, ruta) {
    if (identical(req$url, url_token)) {
      emitidos <<- emitidos + 1L
      return(respuesta_token(paste0("t", emitidos), expira))
    }
    if (ruta == ".well-known/smart-configuration") {
      if (is.null(cfg)) return(respuesta_fhir(NULL, 404L))
      return(httr2::response_json(body = cfg))
    }
    respuesta_fhir(paciente("1"))
  }
}

form <- function(req) {
  lapply(req$body$data, function(x) utils::URLdecode(as.character(x)))
}

es_token <- function(req) identical(req$url, url_token)

test_that("descubre la configuracion SMART en .well-known", {
  simular(servidor_smart())
  cfg <- fhir_smart_configuracion(base)
  expect_identical(cfg$token_endpoint, url_token)
  expect_identical(cfg$authorization_endpoint, "https://auth.test/authorize")
  expect_identical(cfg$fuente, "smart-configuration")
})

test_that("usa las extensiones oauth-uris del CapabilityStatement", {
  cs <- capacidad
  cs$rest[[1]]$security <- list(extension = list(list(
    url = "http://fhir-registry.smarthealthit.org/StructureDefinition/oauth-uris",
    extension = list(list(url = "token", valueUri = url_token),
                     list(url = "authorize",
                          valueUri = "https://auth.test/authorize"))
  )))
  simular(function(req, ruta) {
    if (ruta == "metadata") respuesta_fhir(cs) else respuesta_fhir(NULL, 404L)
  })
  cfg <- fhir_smart_configuracion(base)
  expect_identical(cfg$token_endpoint, url_token)
  expect_identical(cfg$fuente, "CapabilityStatement")
})

test_that("sin configuracion SMART da un error claro", {
  simular(function(req, ruta) {
    if (ruta == "metadata") respuesta_fhir(capacidad) else
      respuesta_fhir(NULL, 404L)
  })
  expect_error(fhir_smart_configuracion(base),
               class = "fhirviews_error_autenticacion")
  expect_error(
    con_simulada(autenticacion = fhir_auth_cliente("c0", "s"), panel = FALSE),
    class = "fhirviews_error_autenticacion"
  )
})

test_that("client credentials: pide el token una vez y lo envia", {
  p <- simular(servidor_smart())
  con <- con_simulada(autenticacion = fhir_auth_cliente(
    "cliente-1", "mi-secreto", alcances = c("system/Patient.read",
                                            "system/Observation.read")
  ), panel = FALSE)
  fhir_leer(con, "Patient/1")
  fhir_leer(con, "Patient/1")
  fhir_peticion(con, "GET", "https://otro.test/fhir/Patient/1")

  urls <- vapply(p$lista, function(r) r$url, character(1))
  expect_identical(sum(urls == url_token), 1L)
  tok <- p$lista[[which(urls == url_token)]]
  f <- form(tok)
  expect_identical(f$grant_type, "client_credentials")
  expect_identical(f$scope, "system/Patient.read system/Observation.read")
  cab_tok <- httr2::req_get_headers(tok, "reveal")
  expect_identical(
    cab_tok$Authorization,
    paste("Basic", jsonlite::base64_enc("cliente-1:mi-secreto"))
  )

  fhir <- Filter(function(r) grepl("Patient", r$url), p$lista)
  cab <- lapply(fhir, function(r) httr2::req_get_headers(r, "reveal"))
  expect_identical(cab[[1]]$Authorization, "Bearer t1")
  expect_identical(cab[[2]]$Authorization, "Bearer t1")
  # A otro servidor no se envia el token
  expect_null(cab[[3]]$Authorization)
})

test_that("el secreto va en el cuerpo si el servidor solo admite post", {
  cfg <- smart_cfg
  cfg$token_endpoint_auth_methods_supported <- list("client_secret_post")
  p <- simular(servidor_smart(cfg))
  con <- con_simulada(autenticacion = fhir_auth_cliente("cliente-2", "s2"),
                      panel = FALSE)
  fhir_leer(con, "Patient/1")
  tok <- Filter(es_token, p$lista)[[1]]
  expect_identical(form(tok)$client_secret, "s2")
  expect_identical(form(tok)$client_id, "cliente-2")
  expect_null(httr2::req_get_headers(tok, "reveal")$Authorization)
})

test_that("renueva el token cuando expira", {
  p <- simular(servidor_smart(expira = 1))
  con <- con_simulada(autenticacion = fhir_auth_cliente(
    "cliente-3", "s3", url_token = url_token
  ), panel = FALSE)
  fhir_leer(con, "Patient/1")
  fhir_leer(con, "Patient/1")
  expect_identical(sum(vapply(p$lista, es_token, logical(1))), 2L)
  fhir <- Filter(Negate(es_token), p$lista)
  # Con url_token no hace falta el descubrimiento
  expect_false(any(grepl("well-known", vapply(fhir, function(r) r$url, ""))))
  cab <- lapply(fhir, function(r) httr2::req_get_headers(r, "reveal"))
  expect_identical(cab[[1]]$Authorization, "Bearer t1")
  expect_identical(cab[[2]]$Authorization, "Bearer t2")
})

test_that("un error del servidor de autorizacion se explica", {
  simular(function(req, ruta) {
    if (identical(req$url, url_token)) {
      return(httr2::response_json(400L, body = list(
        error = "invalid_client", error_description = "Cliente desconocido")))
    }
    respuesta_fhir(paciente("1"))
  })
  con <- con_simulada(autenticacion = fhir_auth_cliente(
    "cliente-4", "s4", url_token = url_token), panel = FALSE)
  expect_error(fhir_leer(con, "Patient/1"),
               class = "fhirviews_error_autenticacion")
})

test_that("el secreto y el token no se imprimen", {
  simular(servidor_smart())
  auth <- fhir_auth_cliente("cliente-5", "secreto-muy-secreto")
  expect_false(any(grepl("muy-secreto", capture.output(print(auth)))))
  con <- con_simulada(autenticacion = auth, panel = FALSE)
  fhir_leer(con, "Patient/1")
  salida <- capture.output(print(con))
  expect_false(any(grepl("muy-secreto|t1", salida)))
  expect_true(any(grepl("client credentials", salida)))
  expect_false(grepl("muy-secreto", codigo_conexion(con)))
  expect_match(codigo_conexion(con), "fhir_auth_cliente\\(\"cliente-5\"")
})

test_that("valida los argumentos", {
  expect_error(con_simulada(autenticacion = list(), panel = FALSE),
               class = "fhirviews_error")
  expect_error(con_simulada(token = "t", panel = FALSE,
                            autenticacion = fhir_auth_cliente("a", "b")),
               class = "fhirviews_error")
  expect_error(fhir_auth_cliente("a", "b", alcances = character()),
               class = "fhirviews_error")
  expect_error(fhir_auth_cliente("a", "b", envio = "otro"))
  expect_warning(
    fhir_conectar("http://fhir.test/fhir", verificar = FALSE, panel = FALSE,
                  autenticacion = fhir_auth_cliente(
                    "a", "b", url_token = "https://auth.test/token")),
    class = "fhirviews_aviso_seguridad"
  )
})

decodificar_jwt <- function(jwt) {
  partes <- strsplit(jwt, ".", fixed = TRUE)[[1]]
  b64 <- function(x) {
    x <- chartr("-_", "+/", x)
    x <- paste0(x, strrep("=", (4L - nchar(x) %% 4L) %% 4L))
    jsonlite::fromJSON(rawToChar(jsonlite::base64_dec(x)))
  }
  list(cabecera = b64(partes[1]), claims = b64(partes[2]))
}

test_that("Backend Services firma un JWT RS384 con kid", {
  skip_if_not_installed("jose")
  skip_if_not_installed("openssl")
  clave <- openssl::rsa_keygen(2048L)
  archivo <- tempfile(fileext = ".pem")
  on.exit(unlink(archivo), add = TRUE)
  openssl::write_pem(clave, archivo)
  p <- simular(servidor_smart())
  auth <- fhir_auth_backend("backend-1", archivo, kid = "k1",
                            alcances = "system/*.rs")
  expect_false(any(grepl("BEGIN", capture.output(print(auth)))))
  con <- con_simulada(autenticacion = auth, panel = FALSE)
  fhir_leer(con, "Patient/1")

  f <- form(Filter(es_token, p$lista)[[1]])
  expect_identical(f$grant_type, "client_credentials")
  expect_identical(f$scope, "system/*.rs")
  expect_identical(f$client_assertion_type,
                   "urn:ietf:params:oauth:client-assertion-type:jwt-bearer")
  expect_null(f$client_secret)
  jwt <- decodificar_jwt(f$client_assertion)
  expect_identical(jwt$cabecera$alg, "RS384")
  expect_identical(jwt$cabecera$kid, "k1")
  expect_identical(jwt$claims$iss, "backend-1")
  expect_identical(jwt$claims$sub, "backend-1")
  expect_identical(jwt$claims$aud, url_token)
  expect_true(nzchar(jwt$claims$jti))
  expect_lte(jwt$claims$exp - as.numeric(Sys.time()), 300)
  # La firma se verifica con la clave publica
  expect_no_error(jose::jwt_decode_sig(f$client_assertion, clave$pubkey))
  fhir <- Filter(Negate(es_token), p$lista)
  expect_identical(
    httr2::req_get_headers(fhir[[length(fhir)]], "reveal")$Authorization,
    "Bearer t1"
  )
})

test_that("Backend Services firma ES384 con claves P-384", {
  skip_if_not_installed("jose")
  skip_if_not_installed("openssl")
  p <- simular(servidor_smart())
  auth <- fhir_auth_backend("backend-2", openssl::ec_keygen("P-384"),
                            url_token = url_token)
  con <- con_simulada(autenticacion = auth, panel = FALSE)
  fhir_leer(con, "Patient/1")
  f <- form(Filter(es_token, p$lista)[[1]])
  jwt <- decodificar_jwt(f$client_assertion)
  expect_identical(jwt$cabecera$alg, "ES384")
  expect_null(jwt$cabecera$kid)

  expect_error(fhir_auth_backend("b", openssl::ec_keygen("P-256")),
               class = "fhirviews_error")
  expect_error(fhir_auth_backend("b", "no-existe.pem"),
               class = "fhirviews_error")
})

test_that("el flujo interactivo usa PKCE y aud (standalone)", {
  simular(servidor_smart())
  auth <- fhir_auth_interactiva("app-1",
                                redireccion = "https://app.test/callback")
  con <- con_simulada(autenticacion = auth, panel = FALSE)
  expect_identical(con$auth$url_autorizacion, "https://auth.test/authorize")
  f <- flujo_auth(con)
  expect_identical(f$flujo, httr2::oauth_flow_auth_code)
  fp <- f$parametros
  expect_true(fp$pkce)
  expect_identical(fp$auth_url, "https://auth.test/authorize")
  expect_identical(fp$auth_params$aud, base)
  expect_identical(fp$scope, "openid fhirUser launch/patient patient/*.read")
  expect_identical(fp$redirect_uri, "https://app.test/callback")
})

test_that("si el servidor rechaza el token, pide otro y reintenta", {
  rechazos <- 0L
  base_smart <- servidor_smart()
  p <- simular(function(req, ruta) {
    if (!identical(req$url, url_token) && rechazos == 0L) {
      rechazos <<- 1L
      return(respuesta_fhir(oo("Token revocado"), 401L))
    }
    base_smart(req, ruta)
  })
  con <- con_simulada(autenticacion = fhir_auth_cliente(
    "cliente-6", "s6", url_token = url_token), panel = FALSE)
  expect_identical(fhir_leer(con, "Patient/1")$id, "1")
  expect_identical(sum(vapply(p$lista, es_token, logical(1))), 2L)
  fhir <- Filter(Negate(es_token), p$lista)
  expect_identical(httr2::req_get_headers(fhir[[2]], "reveal")$Authorization,
                   "Bearer t2")
})
