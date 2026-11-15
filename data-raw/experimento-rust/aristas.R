# Contrasta comportamientos de borde contra R, sin suponer que R valida perfiles.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop("Uso: Rscript aristas.R BINARIO SALIDA-NUEVA")
salida <- args[2]
if (file.exists(salida) || !dir.create(salida, recursive = TRUE)) stop("La salida debe ser nueva")
source("data-raw/experimento-rust/cargar.R")
source("data-raw/experimento-rust/ayudas.R")
e <- crear_experimento(file.path(salida, "plan.json"), normalizePath(args[1], mustWork = TRUE))
literales <- c(NA_character_, "", "Patient/p1", "Group/g1", "Observation/o1", "Unknown/u1",
  "patient/p1", "p1", "Patient/", "Patient/a/b", "Patient/p1/", "#p1", "Patient/p1?x=1",
  "Patient/p1/_history/v2", paste0("Patient/", strrep("a", 64)), paste0("Patient/", strrep("a", 65)),
  "http://example.invalid/fhir/Patient/p1", "https://example.invalid/fhir/Observation/o1",
  "https://example.invalid/fhir/Patient/p1?x=1", "https://example.invalid/foo", "https://example.invalid/",
  "https://example.invalid/a\nb/Patient/p1", "Patient/p1\n", "urn:uuid:00000000-0000-0000-0000-000000000001",
  "mailto:ficticio@example.invalid", "otro:opaque", "Patient/pá", "Patient/p1\t")
declaradas <- c(NA_character_, "Patient", "Group", "HumanName", "http://hl7.org/fhir/StructureDefinition/Patient",
  "https://example.invalid/StructureDefinition/PerfilPropio")
firma <- function(f, datos, mapa) {
  r <- tryCatch(f(datos, mapa), error = identity)
  if (inherits(r, "error")) return(list(clase = class(r)[1], fila = r$fila, campo = r$campo))
  list(json = fhirviews:::motor_actual()$recursos_json(attr(r, "fuente")))
}
conteo <- 0L
for (literal in literales) for (declarada in declaradas) {
  mapa <- fhirviews::fhir_mapa("Observation", c(id = "id", "subject.reference" = "literal", "subject.type" = "declarada"),
    constantes = list(status = "final", "code.text" = "Resultado ficticio"))
  datos <- data.frame(id = "o1", literal = literal, declarada = declarada)
  base <- firma(e$original, datos, mapa)
  for (m in c("preparado", "rust")) {
    r <- firma(e[[m]], datos, mapa)
    if (!identical(base, r)) {
      # Entradas ficticias; se conservan solo localmente para diagnosticar el piloto.
      dput(list(literal = literal, declarada = declarada, metodo = m, esperado = base, obtenido = r))
      stop("Diferencia en referencias", call. = FALSE)
    }
    conteo <- conteo + 1L
  }
}
jsonlite::write_json(list(estado = "aprobado", escenarios = length(literales)*length(declaradas),
  comparaciones = conteo, alcance = "Referencias: paridad con R actual; no prueba conformidad de perfiles ni existencia del destino"),
  file.path(salida, "aristas.json"), auto_unbox = TRUE, pretty = TRUE)
cat("Aristas aprobadas:", conteo, "comparaciones.\n")
