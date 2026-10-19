# -----------------------------------------------------------------------------
# fhirviews · Datos ficticios de vigilancia de dengue (2025)
#
# Genera inst/extdata/dengue_2025.ndjson.gz: pacientes (Patient) y
# diagnósticos de dengue (Condition) FICTICIOS en los cantones de El Oro,
# Guayas, Los Ríos y Manabí. El número de casos de cada cantón se simula a
# partir de su población 2025 (paquete pobecu) y de un riesgo que varía entre
# cantones; no representa la situación epidemiológica real.
#
# Cada dirección lleva el cantón y la provincia (district, state) y el código
# DPA del cantón en una extensión ilustrativa:
#   https://f-slg.github.io/fhirviews/StructureDefinition/codigo-dpa
#
# Requisitos: pobecu
# Uso:        Rscript data-raw/dengue.R
# -----------------------------------------------------------------------------
set.seed(2026)
url_dpa <- "https://f-slg.github.io/fhirviews/StructureDefinition/codigo-dpa"

cantones <- pobecu::poblacion("canton", anio = 2025)
cantones <- cantones[cantones$dpa_provin %in% c("07", "09", "12", "13"), ]
riesgo <- stats::rlnorm(nrow(cantones), meanlog = log(12), sdlog = 0.7)
cantones$casos <- stats::rpois(nrow(cantones),
                               cantones$poblacion * riesgo / 1e5)

n <- sum(cantones$casos)
caso_canton <- rep(seq_len(nrow(cantones)), cantones$casos)
edades <- pmin(stats::rgamma(n, shape = 2.2, scale = 13), 95)
inicio <- as.Date("2025-01-01") +
  pmin(round(stats::rgamma(n, shape = 6, scale = 18)), 364)
nacimiento <- inicio - round(edades * 365.25)
sexo <- sample(c("female", "male"), n, replace = TRUE)
grave <- stats::runif(n) < 0.06
estado <- ifelse(stats::runif(n) < 0.12, "refuted", "confirmed")

lineas <- character(2L * n)
for (i in seq_len(n)) {
  c <- cantones[caso_canton[i], ]
  id_p <- sprintf("den-p%04d", i)
  paciente <- list(
    resourceType = "Patient", id = id_p, gender = sexo[i],
    birthDate = format(nacimiento[i]),
    address = list(list(
      use = "home", district = c$canton, state = c$provincia, country = "EC",
      extension = list(list(url = url_dpa, valueCode = c$dpa_canton))
    ))
  )
  diagnostico <- list(
    resourceType = "Condition", id = sprintf("den-c%04d", i),
    clinicalStatus = list(coding = list(list(
      system = "http://terminology.hl7.org/CodeSystem/condition-clinical",
      code = "resolved"))),
    verificationStatus = list(coding = list(list(
      system = "http://terminology.hl7.org/CodeSystem/condition-ver-status",
      code = estado[i]))),
    code = list(
      coding = list(
        list(system = "http://hl7.org/fhir/sid/icd-10",
             code = if (grave[i]) "A91" else "A90",
             display = if (grave[i]) "Dengue hemorrhagic fever" else
               "Dengue fever [classical dengue]"),
        list(system = "http://snomed.info/sct", code = "38362002",
             display = "Dengue")),
      text = if (grave[i]) "Dengue grave" else "Dengue"),
    subject = list(reference = paste0("Patient/", id_p)),
    onsetDateTime = format(inicio[i]),
    recordedDate = format(inicio[i] + sample(1:4, 1))
  )
  lineas[2L * i - 1L] <- jsonlite::toJSON(paciente, auto_unbox = TRUE)
  lineas[2L * i] <- jsonlite::toJSON(diagnostico, auto_unbox = TRUE)
}

destino <- file.path("inst", "extdata", "dengue_2025.ndjson.gz")
con <- gzfile(destino, "w", encoding = "UTF-8")
writeLines(enc2utf8(lineas), con)
close(con)
message(n, " casos ficticios (", 2L * n, " recursos) en ", destino, " (",
        round(file.size(destino) / 1024), " KB)")
