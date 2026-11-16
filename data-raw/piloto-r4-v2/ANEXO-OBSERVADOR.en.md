# Observer guide and reference answers

[Español](ANEXO-OBSERVADOR.md) · **English**

**Protocol 2.1 · Candidate 0.5.0.9002.** Consult solutions after recording the
first attempt. Showing a solution, correcting code or giving a conceptual hint
counts as intervention. Expected results use fictional data and are not
participant observations.

## Preparation and observation

Read [EVALUACION-PILOTO.en.md](EVALUACION-PILOTO.en.md). Prepare an empty record
per profile and confirm participant R/FHIR, technical basic/full and core/seven
scope. Seven requires full level and task 09 before closure 08. Record experience,
preinstalled dependencies, exposure to solutions and planned assistance.

Read the prompt, allow an attempt and record the first explanation before
checking it. Allow assistance/breaks and record their content. Self-directed
reading is not observer assistance. Use consistent active/wait timing rules.
A successful script alone does not complete a human task.

Assess all understanding questions, retain answers and justify correct/partial/
incorrect. Keep initial and revised explanations after hints, and mark assisted.
Persistent essential misunderstanding prevents completion even if tables match.
Open referenced evidence files: the form does not verify them. Ease ratings are
optional. Session acceptance can include recorded assistance; independence needs
an identified manual repeat.

An illustrative intervention note might record task, moment, documentation hint,
one assistance episode, initial misconception, corrected explanation and filenames.
Do not copy illustrative notes into real participant records.

## Shared installed-trial references

Check version, commit and SHA-256 in CANDIDATO.json/SESION.json. Also compare
candidate MD5 against aceptacion.json, schema 2. Checks are api_instalada,
vigilancia, contrato_estricto, recuperacion and r4_cinco_recursos. Basic excludes
recovery; full requires it.

Surveillance: 755 events, 661 confirmed, 94 excluded and 65 cantons.
den-c0001→den-p0001, residence 0701, onset 2025-02-27; den-c0002 excluded.
Cantons 0701/0702/0704: 55/1/1; January/February/March 2025: 5/73/173.
These are fictional event counts, not unique people or rates.

Core R4 resources: Patient/p1, Encounter/e1, Condition/c1, Observation/o1 and
Immunization/i1/i2. Condition/c1 and Immunization/i1 reference Encounter/e1.
i2 retains textual date/dose and has no encounter/doseQuantity. Patient.active
is false. Literals 72.00/0.50 have lower boundaries 71.995/0.495.

Allergies: three records/five rows. a1 has two reactions with two/one
manifestations; a2/a3 each retain a row without a reaction. Categories are lists.
a1 clinicalStatus is selected by canonical system. In a3 do not mix system,
code and display from different Coding entries. These fixtures check extraction;
they are not a new constructor or clinical/terminology certification.

## Reference solution: immunization view

Show only after an attempt or on request for help. Other definitions are
acceptable when results and semantics are correct. Keep initial/extended views.
API names, technical paths and fictional data remain unchanged in both languages.

```r
# Adapt the path to the participant attempt.
recursos <- fhir_recursos("sesion-P01-intento01/piloto/r4/recursos-r4.ndjson")
vista <- vista_crear("Immunization", c(
  estado = "status", paciente = "patient.getReferenceKey(Patient)",
  fecha = "occurrence.ofType(dateTime)",
  fecha_texto = "occurrence.ofType(string)"))
tabla <- vista_ejecutar(recursos, vista)
writeLines(vista_json(vista), "vista-inmunizaciones-02.json")
releida <- vista_leer("vista-inmunizaciones-02.json")
isTRUE(all.equal(tabla, vista_ejecutar(recursos, releida)))
```

## Reference solutions: local construction and rejections

These cases run with the installed candidate without server/DuckDB. Supplying
them before an attempt makes that task assisted. Expected rejections are not
pilot failures. Participant scripts/answers remain the primary evidence.

```r
# Each diagnostic is an expected rejection, not a pilot failure.
rechazo_piloto <- function(expr) {
  e <- tryCatch({ force(expr); NULL }, error = identity)
  stopifnot(inherits(e, "fhirviews_error_mapeo"))
  list(clase = class(e), fila = e$fila, campo = e$campo)
}
datos <- data.frame(id = c("prueba-p1", "prueba-p2"),
  sexo = c("female", "male"), activo = c(FALSE, TRUE),
  nacimiento = as.Date(c("2000-02-29", "1990-01-01")))
mapa <- fhir_mapa("Patient", c(id = "id", gender = "sexo",
  active = "activo", birthDate = "nacimiento"))
pacientes <- fhir_desde_tabla(datos, mapa)
stopifnot(length(pacientes) == 2L, identical(pacientes[[1]]$active, FALSE))
duplicados <- datos; duplicados$id[2] <- duplicados$id[1]
rechazo_piloto(fhir_desde_tabla(duplicados, mapa))
sexo_invalido <- datos; sexo_invalido$sexo[1] <- "invalido"
rechazo_piloto(fhir_desde_tabla(sexo_invalido, mapa))
texto_logico <- datos; texto_logico$activo <- c("false", "true")
rechazo_piloto(fhir_desde_tabla(texto_logico, mapa))
fecha_invalida <- datos
fecha_invalida$nacimiento <- c("2025-02-29", "1990-01-01")
rechazo_piloto(fhir_desde_tabla(fecha_invalida, mapa))

vacunas <- data.frame(id = "prueba-i1", paciente = "prueba-p1")
constantes <- list(status = "completed", "vaccineCode.text" = "Vacuna ficticia",
  occurrenceDateTime = "2026-01-14")
mapa_vacuna <- fhir_mapa("Immunization", c(id = "id", "patient.reference" = "paciente"),
  constantes = constantes, referencias = c("patient.reference" = "Patient"))
ambas <- c(constantes, list(occurrenceString = "Fecha desconocida"))
rechazo_piloto(fhir_desde_tabla(vacunas, fhir_mapa("Immunization",
  c(id = "id", "patient.reference" = "paciente"), constantes = ambas,
  referencias = c("patient.reference" = "Patient"))))
rechazo_piloto(fhir_mapa("Immunization",
  c(id = "id", "patient.reference" = "paciente"), constantes = constantes,
  referencias = c("patient.reference" = "Group")))
# The constructor checks target type, not existence of another resource.
sin_paciente <- vacunas; sin_paciente$paciente <- "no-existe"
referencia_no_resuelta <- fhir_desde_tabla(sin_paciente, mapa_vacuna)
stopifnot(identical(referencia_no_resuelta[[1]]$patient$reference, "Patient/no-existe"))

informe <- data.frame(id = "prueba-d1")
rechazo_piloto(fhir_desde_tabla(informe, fhir_mapa("DiagnosticReport", c(id = "id"),
  constantes = list(status = "invalido", "code.text" = "Informe ficticio"))))
rechazo_piloto(fhir_mapa("DiagnosticReport", c(id = "id", "result[0].reference" = "resultado"),
  constantes = list(status = "final", "code.text" = "Informe ficticio"),
  referencias = c("result[0].reference" = "Patient")))
```

For R04 full level, the participant creates a DBI table and selects one id with
a bound parameter. Compare equivalent R/SQL selections rather than command
completion alone, and retain connection cleanup. Reference example:

```r
# Requires DBI/DuckDB. Reuse data and map from the previous block.
args_db <- if ("shared_home" %in% names(formals(duckdb::duckdb)))
  list(shared_home = FALSE) else list()
db <- DBI::dbConnect(do.call(duckdb::duckdb, args_db))
tryCatch({
  # Use only the columns needed for this comparison, with native types.
  DBI::dbWriteTable(db, "pacientes_piloto", datos)
  desde_sql <- fhir_desde_sql(db,
    "SELECT * FROM pacientes_piloto WHERE id = ? ORDER BY id", mapa,
    parametros = list("prueba-p1"))
  desde_r <- fhir_desde_tabla(datos[datos$id == "prueba-p1", ], mapa)
  stopifnot(identical(desde_sql[[1]], desde_r[[1]]))
}, finally = DBI::dbDisconnect(db))
```

## Laboratory references

Seven-type scope requires completed R09/F09. The example produces Patient,
Specimen, two Observation and DiagnosticReport; default keys start demo-lab-.
muestras has one row with volume 5.00/boundary 4.995; observaciones has two rows
with values 72.00/13.50 and boundaries 71.995/13.495; resultados has two rows,
one per referenced Observation. Compare all three tables between V8/DuckDB.

```r
source(system.file("examples", "laboratorio-r4.R", package = "fhirviews"))
ejemplo <- laboratorio_r4()
comparaciones <- vapply(names(ejemplo$vistas), function(nombre) {
  isTRUE(all.equal(ejemplo$tablas[[nombre]],
    vista_ejecutar_duckdb(ejemplo$recursos, ejemplo$vistas[[nombre]])))
}, logical(1))
stopifnot(all(comparaciones))
# Save NDJSON and all three views in an agreed new directory.
```

## Profile validation matrix

For F07 request one row per type/profile. Minimum fields: resource, FHIR
version, canonical/versioned profile, requirement source, terminology,
references, valid case, negative alteration, expected outcome, owner, planned
test server and not-evaluated/executed/indeterminate state. Without a server,
assess plan quality and leave profiles not evaluated.

If $validate execution was agreed, retain exact JSON, requested profile, date,
non-sensitive server/version, HTTP and reviewed OperationOutcome. Investigate
indeterminate results; do not treat NA as valid. Reading prior HAPI results is
documentary evidence, not participant execution. No server persistence is needed.

## Round conclusion

Review scope denominators, per-task outcomes, understanding, assistance,
manual repeats, active/wait times and optional ease. Separate R/FHIR,
basic/full and protocol 2.0/2.1. Show individual cases with few participants.
Link priorities to specific issues and state what will be repeated. Never
fabricate observations or prefill participants.

## References by task

### R01. Prepare the environment and identify the installation

**Reference answer:** Version 0.5.0.9002 with the supplied commit and file hash; the session library is loaded. Full level needs DBI/DuckDB and R ≥ 4.2; basic needs R ≥ 4.1. Finding documentation independently is not an observer intervention.

**Errors to detect:** Confusing version with file identity; loading another library; including network waits in analysis time.

**Evidence:** SESION.json, candidato.txt, reviewed library location, versions and preparation log.


### R02. Interpret checks and surveillance indicators

**Reference answer:** 755 input events, 661 confirmed, 94 excluded and 65 cantons. den-c0001→den-p0001, residence 0701, onset 2025-02-27; den-c0002 excluded. Canton 0701: 55 events; February: 73. These are fictional event counts; a rate needs a compatible denominator and period. Basic: recovery not evaluated; full: five checks passed.

**Errors to detect:** Turning counts into rates; counting events as patients; treating not evaluated as passed.

**Evidence:** Original report and interpretation note identifying the rows or fields checked.


### R03. Trace a table back to its R4 sources

**Reference answer:** Five types and six resources: p1/e1/c1/o1/i1/i2. Condition/c1 and Immunization/i1 reference Encounter/e1; both immunizations reference Patient/p1. active=false is present information. i2 has no encounter or quantity and retains textual date/dose alternatives. 72.00 and 0.50 have lower boundaries 71.995 and 0.495.

**Errors to detect:** Confusing false with absence; losing trailing zeros before mapping; inventing a date, quantity or patient.

**Evidence:** Local provenance table, references and reviewed fictional JSON fragments.


### R04. Build new resources and understand errors

**Reference answer:** Two valid Patient resources retain their ids and active=FALSE. Duplicate ids and gender outside the required binding produce fhirviews_error_mapeo. Ids are not grouped or silently overwritten. DBI uses WHERE id = ? with parametros=list(...), and CAST to text when source precision requires it. Local construction does not demonstrate profile validation.

**Errors to detect:** Using the text "false" as a logical value; deleting rows merely to obtain a pass; interpolating values into SQL.

**Evidence:** Participant script, valid NDJSON, diagnostics for both negative cases and DBI comparison when applicable.


### R05. Design, modify and reuse a view

**Reference answer:** Two rows i1/i2 with patient key p1. Project occurrence.ofType(dateTime) and occurrence.ofType(string) separately; missing alternatives remain NA. The reread definition produces the same table and types. A ViewDefinition can omit information and is insufficient to reconstruct the complete resource.

**Errors to detect:** Copying a solution and claiming independence; replacing NA; assuming a projection is reversible.

**Evidence:** vista-inmunizaciones-01.json, vista-inmunizaciones-02.json, tables and the participant’s explanation.


### R06. Analyze allergies while preserving the counting unit

**Reference answer:** Three ids and five rows: a1 has three manifestations in two reactions; a2 and a3 each retain a row without a reaction. Do not infer clinical absence from missing documentation. Categories remain lists. criticality and reaction.severity have different meanings.

**Errors to detect:** Counting rows as records; dropping allergies without reactions; assigning one severity to all manifestations.

**Evidence:** Counting script, table by id and explanation of the unit of analysis.


### R07. Repeat the analysis and examine recovery

**Reference answer:** Findings match; paths and durations need not match. A full retry replaces the load after rollback without accumulating duplicates. Independence is limited to manual tasks actually repeated without assistance, with evidence of the second attempt.

**Errors to detect:** Overwriting the first attempt; comparing totals only; claiming independence from an automatic script.

**Evidence:** Two reports, written comparison and manual-repeat files; describe any assistance.


### R08. Assess usefulness and agree on closure

**Reference answer:** Conclusions may request retesting after corrections, accept the stated scope, or accept with explicit minor follow-up. No favorable closure with incomplete required tasks, incorrect understanding or unverified critical/high issues. The session does not constitute clinical or institutional acceptance.

**Errors to detect:** Confusing satisfaction with correctness; closing an issue merely because code changed; omitting limitations.

**Evidence:** Reviewed exported record, experiencia-usuario.txt, issues and follow-up plan.


### R09. Evaluate the laboratory path for seven constructors

**Reference answer:** The example produces five resources of four types: Patient, Specimen, two Observation and DiagnosticReport. Together with the core case it covers seven constructor types; it is not seven resources in one file. One specimen/report, two observations and two result rows. Literals 5.00/72.00/13.50; lower boundaries 4.995/71.995/13.495. Compare specimens, observations and results with both engines.

**Errors to detect:** Confusing seven types across cases with seven laboratory resources; omitting a view; assuming profile validation.

**Evidence:** Laboratory NDJSON, three JSON view definitions, compared tables and participant explanation.


### F01. Define interoperability scope and candidate identity

**Reference answer:** R4 4.0.1, candidate 0.5.0.9002 identified by commit and SHA-256. HAPI CI is prior maintainer evidence, not a participant execution. A local pass or 144/144 view-suite result does not validate national profiles, terminology or reference existence.

**Errors to detect:** Using view conformance as general FHIR certification; claiming the participant ran HAPI after reading a report.

**Evidence:** Identity/environment, reports consulted and a written checked/not-evaluated matrix.


### F02. Review mappings, cardinalities and semantic decisions

**Reference answer:** The constructor requires a unique id per row by contract. Encounter requires status/class; Condition requires subject in the base; Observation status/code; Immunization status/vaccineCode/patient/one occurrence alternative. Invariants/profiles may require more. Example constants are explicit decisions, not clinical inference. Maps use JSON paths such as valueQuantity.value, not FHIRPath.

**Errors to detect:** Confusing the id contract with base cardinality; inventing codes/status; treating a snapshot as the entire profile.

**Evidence:** Per-resource matrix with versioned documentary sources and decision rationale.


### F03. Audit types, choices, dates and precision

**Reference answer:** active="false" is not boolean; 2025-02-29 is invalid; simultaneous occurrenceDateTime/occurrenceString are exclusive choices. Expect fhirviews_error_mapeo. FALSE remains present, absent alternatives are omitted/NA, and 72.00/0.50 retain boundaries 71.995/0.495. A date without time is not an instant; issued requires an instant with timezone.

**Errors to detect:** Checking precision only in R printing; converting text to boolean automatically; inventing timezone/time.

**Evidence:** Choice matrix, NDJSON fragments, script and negative-case diagnostics.


### F04. Check references and graph integrity

**Reference answer:** Group as an Immunization.patient target is rejected. Patient/no-existe can be structurally admissible while absent from the dataset; existence needs an additional check. Condition/c1 and Immunization/i1 link Encounter/e1; i2 has no encounter. Server provenance prevents confusing equal ids from different sources.

**Errors to detect:** Confusing allowed type with existence; resolving by position; ignoring id provenance.

**Evidence:** Link inventory, both-case script and rejection/unresolved-reference evidence.


### F05. Examine bindings and Coding fidelity

**Reference answer:** a1 contains the translation activo and canonical code active; the view selects by system. For a3, do not combine urn:ejemplo:primero with NO-MEZCLAR from another entry. Invalid Patient.gender is rejected. Extensible bindings are not closed enumerations; external/filtered ValueSets require agreed terminology services.

**Errors to detect:** Mixing system/code/display across entries; validating by display; closing an extensible binding.

**Evidence:** Checked Coding table, negative case and project terminology requirements.


### F06. Audit the projection and its information loss

**Reference answer:** Immunization retains i1/i2 and missing alternatives as NA; allergies has three records/five rows with manifestations tied to their reactions. A view can lose information. 144/144 applies to the fixed suite; DuckDB retains a documented subset and does not accept every expression.

**Errors to detect:** Treating extraction as reversible conversion; ignoring types; extrapolating the suite to all FHIRPath.

**Evidence:** Participant ViewDefinition, audit table and engine comparison or justified exclusion.


### F07. Design validation against environment profiles

**Reference answer:** The required task is completed by producing and explaining the plan; a server execution is an optional extension. No network/server is required for the core. $validate HTTP errors or incomplete responses are indeterminate; warnings need review. No production resources are saved/sent. A base-profile pass does not demonstrate a national profile pass.

**Errors to detect:** Marking profiles passed because a plan was written; treating NA as TRUE; executing against production without agreement.

**Evidence:** Validation matrix/plan; for an agreed execution, exact JSON and reviewed OperationOutcome with date/profile/server.


### F08. Repeat the audit and issue a bounded conclusion

**Reference answer:** Technical results remain separate from human and profile decisions. Favorable closure requires completed in-scope tasks, correct understanding and no open critical/high issues. Independence is limited to tasks repeated with evidence and zero interventions; it does not automatically extend to the entire profile.

**Errors to detect:** Generalizing to other servers/profiles; confusing R assistance with FHIR defects; claiming global independence without repeating every task.

**Evidence:** Two attempts, repeated audit, exported record and conclusion identifying pending scope.


### F09. Audit Specimen and DiagnosticReport end to end

**Reference answer:** Five resources/four types in the laboratory extend joint coverage to seven constructor types. Specimen can have an environmental subject and base status/subject are optional; DiagnosticReport requires status/code, not subject; issued is an instant with timezone. The report references two Observation and one Specimen. Reject invalid status and result targeting Patient. All three views must match in V8/DuckDB; HAPI/project profiles remain separate.

**Errors to detect:** Always requiring Patient for an environmental specimen; confusing structural references with resolution; claiming profile validation from table comparison.

**Evidence:** Graph, field matrix, NDJSON, negative diagnostics, three views and compared tables.
