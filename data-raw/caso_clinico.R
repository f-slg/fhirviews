# -----------------------------------------------------------------------------
# fhirviews · Caso clínico del taller aprende-fhir
#
# Reúne en inst/extdata/caso_clinico.ndjson los recursos del caso clínico
# ficticio del taller https://github.com/f-slg/aprende-fhir (mismo autor,
# licencia MIT): Luis Alberto Paredes Cevallos, de Riobamba, que vive en
# Quito. Se toma la última versión de cada recurso (las soluciones
# "actualizar"), se les asigna un id fijo y se reemplazan las variables de
# Postman ({{patientId}}, ...) por esos ids, de modo que las referencias
# quedan resueltas como en un servidor.
#
# Uso: Rscript data-raw/caso_clinico.R [ruta a aprende-fhir]
# -----------------------------------------------------------------------------
taller <- commandArgs(trailingOnly = TRUE)[1]
if (is.na(taller)) taller <- file.path("..", "aprende-fhir")
modulos <- file.path(taller, "modulos")
stopifnot(dir.exists(modulos))

# archivo de solución -> variable de Postman que define (o NA)
archivos <- c(
  "17-busquedas-y-versiones/soluciones/17a_patient_agregar_correo.json" = "patientId",
  "04-profesionales-y-organizaciones/soluciones/04a_practitioner_crear.json" = "practitionerId",
  "04-profesionales-y-organizaciones/soluciones/04b_organization_red.json" = "organizationId",
  "04-profesionales-y-organizaciones/soluciones/04c_organization_hospital.json" = "hospitalId",
  "05-diagnostico-y-encuentro/soluciones/05a_condition_intoxicacion.json" = "conditionIntoxId",
  "05-diagnostico-y-encuentro/soluciones/05b_encounter_crear.json" = "encounterId",
  "06-observaciones/soluciones/06a_observation_presion_arterial.json" = "obsPAId",
  "06-observaciones/soluciones/06b_observation_temperatura.json" = "obsTempId",
  "06-observaciones/soluciones/06c_observation_frecuencia_respiratoria.json" = "obsFRId",
  "06-observaciones/soluciones/06d_observation_frecuencia_cardiaca.json" = "obsFCId",
  "06-observaciones/soluciones/06e_observation_fiebre_boolean.json" = NA,
  "06-observaciones/soluciones/06f_observation_motivo_string.json" = NA,
  "06-observaciones/soluciones/06g_observation_sangre_oculta_codeable.json" = NA,
  "06-observaciones/soluciones/06h_observation_titulo_ratio.json" = NA,
  "07-antecedentes/soluciones/07a_allergyintolerance_penicilina.json" = "allergyId",
  "07-antecedentes/soluciones/07b_medicationstatement_losartan.json" = NA,
  "07-antecedentes/soluciones/07c_familymemberhistory_madre.json" = "motherHistoryId",
  "07-antecedentes/soluciones/07d_familymemberhistory_padre.json" = NA,
  "08-vacunacion/soluciones/08a_immunization_diferida.json" = NA,
  "08-vacunacion/soluciones/08b_practitioner_enfermera.json" = "nursePractitionerId",
  "08-vacunacion/soluciones/08c_encounter_vacunacion.json" = "vaccinationEncounterId",
  "08-vacunacion/soluciones/08d_immunization_influenza.json" = "fluImmunizationId",
  "08-vacunacion/soluciones/08e_immunization_td.json" = NA,
  "10-ordenes-y-derivacion/soluciones/10a_location_consultorio.json" = "officeLocationId",
  "10-ordenes-y-derivacion/soluciones/10b_practitionerrole_medica_general.json" = "salazarRoleId",
  "10-ordenes-y-derivacion/soluciones/10c_practitioner_oncologo.json" = "oncologistId",
  "10-ordenes-y-derivacion/soluciones/10d_practitionerrole_oncologo.json" = "oncologistRoleId",
  "10-ordenes-y-derivacion/soluciones/10e_encounter_consulta_nodulo.json" = "noduleEncounterId",
  "10-ordenes-y-derivacion/soluciones/10f_servicerequest_ecografia.json" = "ultrasoundRequestId",
  "10-ordenes-y-derivacion/soluciones/10g_diagnosticreport_ecografia.json" = "ultrasoundReportId",
  "10-ordenes-y-derivacion/soluciones/10h_servicerequest_biopsia.json" = "biopsyRequestId",
  "10-ordenes-y-derivacion/soluciones/10i_servicerequest_derivacion.json" = NA,
  "11-anatomia-patologica/soluciones/11b_bodystructure_actualizar.json" = "bodyStructureId",
  "11-anatomia-patologica/soluciones/11d_specimen_actualizar.json" = "specimenId",
  "11-anatomia-patologica/soluciones/11f_observation_tamano_tumor_actualizar.json" = "obsTumorId",
  "11-anatomia-patologica/soluciones/11h_observation_receptor_estrogeno_actualizar.json" = "obsREId",
  "11-anatomia-patologica/soluciones/11i_diagnosticreport_patologia.json" = "diagnosticReportId",
  "11-anatomia-patologica/soluciones/11j_condition_cancer_mama.json" = "conditionCancerId",
  "12-plan-y-consentimiento/soluciones/12a_careteam_comite.json" = "careTeamId",
  "12-plan-y-consentimiento/soluciones/12b_goal_control_enfermedad.json" = "goalControlId",
  "12-plan-y-consentimiento/soluciones/12c_goal_calidad_vida.json" = "goalQualityId",
  "12-plan-y-consentimiento/soluciones/12d_careplan_oncologico.json" = "carePlanId",
  "12-plan-y-consentimiento/soluciones/12e_consent_cirugia.json" = NA,
  "13-procedimientos/soluciones/13b_procedure_actualizar.json" = "procedureId",
  "14-citas/soluciones/14a_location_hospital_dia.json" = "dayHospitalLocationId",
  "14-citas/soluciones/14b_schedule_quimioterapia.json" = "scheduleId",
  "14-citas/soluciones/14d_slot_ciclo1_ocupado.json" = "slot1Id",
  "14-citas/soluciones/14g_appointment_ciclo1_cumplida.json" = "appointment1Id",
  "14-citas/soluciones/14f_appointmentresponse_paciente.json" = NA,
  "14-citas/soluciones/14h_slot_ciclo2.json" = "slot2Id",
  "14-citas/soluciones/14j_appointment_ciclo2_cancelada.json" = "appointment2Id",
  "15-medicamentos/soluciones/15a_observation_superficie_corporal.json" = "obsBSAId",
  "15-medicamentos/soluciones/15b_medicationrequest_doxorrubicina.json" = "medReqDoxoId",
  "15-medicamentos/soluciones/15d_medicationadministration_actualizar.json" = "medAdminDoxoId",
  "15-medicamentos/soluciones/15g_medicationrequest_suspender.json" = "medReqTamoxId",
  "15-medicamentos/soluciones/15f_medicationadministration_tamoxifeno.json" = NA,
  "16-seguimiento/soluciones/16a_questionnaire_seguimiento.json" = NA,
  "16-seguimiento/soluciones/16b_questionnaireresponse_octubre.json" = NA,
  "16-seguimiento/soluciones/16c_questionnaireresponse_enero.json" = "responseJanuaryId",
  "16-seguimiento/soluciones/16d_observation_dolor.json" = NA
)

# Ids legibles: patientId -> "patient", obsPAId -> "obs-pa"; sin variable, el
# nombre del archivo (06e_observation_fiebre_boolean -> "06e-observation-...")
id_variable <- function(v) {
  v <- sub("Id$", "", v)
  tolower(gsub("([a-z])([A-Z])", "\\1-\\2", v))
}
ids <- ifelse(is.na(archivos), gsub("_", "-", sub("\\.json$", "",
                                                   basename(names(archivos)))),
              id_variable(archivos))
variables <- stats::setNames(ids[!is.na(archivos)], archivos[!is.na(archivos)])

lineas <- vapply(seq_along(archivos), function(i) {
  texto <- paste(readLines(file.path(modulos, names(archivos)[i]),
                           encoding = "UTF-8", warn = FALSE), collapse = "\n")
  for (v in names(variables)) {
    texto <- gsub(paste0("{{", v, "}}"), variables[[v]], texto, fixed = TRUE)
  }
  pendientes <- regmatches(texto, gregexpr("\\{\\{[^}]+\\}\\}", texto))[[1]]
  if (length(pendientes) > 0L) {
    stop(names(archivos)[i], ": variables sin resolver: ",
         paste(unique(pendientes), collapse = ", "))
  }
  r <- jsonlite::fromJSON(texto, simplifyVector = FALSE)
  r$id <- ids[i]
  r <- c(list(resourceType = r$resourceType, id = r$id),
         r[setdiff(names(r), c("resourceType", "id"))])
  as.character(jsonlite::toJSON(r, auto_unbox = TRUE, digits = NA,
                                null = "null"))
}, character(1))

stopifnot(!anyDuplicated(ids))
dir.create(file.path("inst", "extdata"), showWarnings = FALSE,
           recursive = TRUE)
destino <- file.path("inst", "extdata", "caso_clinico.ndjson")
writeLines(enc2utf8(lineas), destino, useBytes = TRUE)
tipos <- table(vapply(lineas, function(l) {
  jsonlite::fromJSON(l)$resourceType
}, character(1)))
message(length(lineas), " recursos en ", destino, ":\n",
        paste0("  ", names(tipos), ": ", tipos, collapse = "\n"))
