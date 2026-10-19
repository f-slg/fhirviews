# Servidor FHIR simulado con httr2 (sin red)

base <- "https://fhir.test/fhir"

respuesta_fhir <- function(datos, estado = 200L, cabeceras = list()) {
  cuerpo <- if (is.null(datos)) raw() else
    charToRaw(enc2utf8(as.character(jsonlite::toJSON(datos, auto_unbox = TRUE))))
  httr2::response(
    status_code = estado,
    headers = c(list(`Content-Type` = "application/fhir+json"), cabeceras),
    body = cuerpo
  )
}

capacidad <- list(resourceType = "CapabilityStatement", fhirVersion = "4.0.1",
                  software = list(name = "Servidor de prueba", version = "1.0"),
                  rest = list(list(mode = "server", resource = list(
                    list(type = "Patient",
                         interaction = list(list(code = "read"),
                                            list(code = "search-type")),
                         searchParam = list(list(name = "family")))))))

oo <- function(texto, severidad = "error") {
  list(resourceType = "OperationOutcome", issue = list(list(
    severity = severidad, code = "processing", diagnostics = texto,
    expression = list("Patient.gender"))))
}

paciente <- function(id) list(resourceType = "Patient", id = id)

# Servidor simulado: guarda las peticiones y responde según la ruta
simular <- function(responder, envir = parent.frame()) {
  # Forzar aquí: si se evalúa dentro de httr2, el mock queda atado a otro
  # entorno y sigue activo en las pruebas siguientes
  force(envir)
  peticiones <- new.env()
  peticiones$lista <- list()
  httr2::local_mocked_responses(function(req) {
    peticiones$lista[[length(peticiones$lista) + 1L]] <- req
    responder(req, sub("^https://fhir.test/fhir/?", "", req$url))
  }, env = envir)
  peticiones
}

cuerpo_req <- function(req) {
  d <- req$body$data
  if (is.raw(d)) rawToChar(d) else d
}

con_simulada <- function(...) fhir_conectar(base, verificar = FALSE, ...)
