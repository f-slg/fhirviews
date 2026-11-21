# R profile: analysis, independence and usefulness

[Español](PROTOCOLO-PERFIL-R.md) · **English**

Protocol **2.1**, candidate **0.5.0.9003**, fictional data.

Read [the evaluation](EVALUACION-PILOTO.en.md) and
[technical preparation](LEEME.en.md) first. Record participant profile,
basic/full technical level and core/seven scope as three separate choices.

Tasks 01–08 are required. Task 09 is required for **seven** scope and
needs full level; explicitly exclude it for core. Perform 09 before closure 08.
Answer in your own words. Self-directed documentation is allowed.

The observer records state, active/wait time, interventions, understanding,
answers, consulted documentation, evidence and manual repeats. Do not consult
reference answers before the first attempt. Memorized commands are not required.

## R01. Prepare the environment and identify the installation

**Purpose:** Check whether an external participant can prepare and open the supplied candidate using the documentation.

**Scope:** Required for core and seven.

### Prompt and steps

1. Agree on the R participant profile, basic/full technical level and five-type core/seven-constructor scope. Record prior R, SQL and FHIR experience, existing dependencies and planned assistance.
2. Check the ZIP and CANDIDATO.json. Record package version, commit and SHA-256, operating system, architecture and R version. Separate dependency preparation time from candidate installation time.
3. Run INICIAR.R into a new directory and abrir_sesion() in a clean R session. Check packageVersion(), find.package(), help and vignettes.
4. Keep SESION.json and the original log; describe each obstacle and the documentation used.

### Understanding questions

- How would you check that R is using this candidate rather than another installed copy?
- Which steps need network access, and which should work once dependencies are prepared?

### Observable criteria

- The supplied identity and the loaded installation were checked.
- Environment, technical level and scope were recorded before the tasks.
- Help and vignettes were located, or the obstacle was documented.
- Preparation times and observer interventions were recorded separately.

**Evidence to retain:** SESION.json, candidato.txt, reviewed library location, versions and preparation log.

### Operational preparation

Adapt the ID, directory and technical level to the agreement. API names and filenames stay unchanged.

```r
source("INICIAR.R")
iniciar_piloto("basico", "sesion-P01-intento01")
abrir_sesion("sesion-P01-intento01")
packageVersion("fhirviews")
find.package("fhirviews")
help("fhir_mapa", package = "fhirviews")
browseVignettes("fhirviews")
```

**Task record:** state; active/wait minutes; interventions and assistance;
observed understanding; answers; documentation; evidence; repeat outcome/files if performed.

## R02. Interpret checks and surveillance indicators

**Purpose:** Explain what the trial measures and identify an incorrect epidemiological interpretation.

**Scope:** Required for core and seven.

### Prompt and steps

1. Open aceptacion.json and aceptacion.csv. Locate identity, schema, checks, warnings and findings without editing the reports.
2. Explain what each check demonstrates and what is not evaluated at the chosen level. Check totals and event exclusions against the fictional files.
3. Follow den-c0001 to its patient and residence; check that den-c0002 is absent from confirmed events. Review at least one territorial and one monthly count in the example outputs.
4. Describe the unit of analysis and the additional information needed to count unique people or calculate a population rate.

### Understanding questions

- Can every output row be interpreted as a different person? Why?
- Does an automatic pass demonstrate unassisted use by another person or validation against a national profile?

### Observable criteria

- The five checks, exclusions and warnings were interpreted.
- Totals and an included/excluded event were checked against evidence.
- One territorial and one monthly aggregation were reviewed.
- Events, people and rates were distinguished, and limitations were written down.

**Evidence to retain:** Original report and interpretation note identifying the rows or fields checked.

### Operational preparation

Adapt the ID, directory and technical level to the agreement. API names and filenames stay unchanged.

```r
informe <- jsonlite::read_json("sesion-P01-intento01/piloto/aceptacion.json")
informe[c("version_fhirviews", "candidato_md5", "esquema_informe", "resultado_tecnico")]
read.csv("sesion-P01-intento01/piloto/aceptacion.csv")
```

**Task record:** state; active/wait minutes; interventions and assistance;
observed understanding; answers; documentation; evidence; repeat outcome/files if performed.

## R03. Trace a table back to its R4 sources

**Purpose:** Relate tables to resources and explain keys, missing values and precision.

**Scope:** Required for core and seven.

### Prompt and steps

1. Open the six resources in piloto/r4/recursos-r4.ndjson and create a local type/id/relevant references table.
2. Follow Patient, Encounter, Condition, Observation and Immunization; compare at least one table row with its NDJSON line.
3. Compare false, an absent field and NA; locate both immunizations’ occurrence and dose-number alternatives.
4. Inspect decimal literals in the file and explain what is lost if the SQL source supplies them as double.

### Understanding questions

- Why does a table printing 72 not demonstrate preservation of the literal 72.00?
- What is the risk of filling in an unknown date or joining tables only by row order?

### Observable criteria

- The number of types, resources and output rows were distinguished.
- The selected row’s keys and references were traced to their sources.
- FALSE, absence and NA were explained without filling in data.
- Scale was checked in JSON as well as in the R table.

**Evidence to retain:** Local provenance table, references and reviewed fictional JSON fragments.

### Operational preparation

Adapt the ID, directory and technical level to the agreement. API names and filenames stay unchanged.

```r
recursos <- fhir_recursos("sesion-P01-intento01/piloto/r4/recursos-r4.ndjson")
print(recursos)
```

**Task record:** state; active/wait minutes; interventions and assistance;
observed understanding; answers; documentation; evidence; repeat outcome/files if performed.

## R04. Build new resources and understand errors

**Purpose:** Create a small mapping with fictional data and resolve an error using the help.

**Scope:** Required for core and seven.

### Prompt and steps

1. Write a script with two new fictional Patient rows: distinct ids, valid gender, birthDate and logical active, including FALSE. Consult fhir_mapa(), fhir_desde_tabla() and fhir_escribir().
2. Build resources using an explicit map, write NDJSON and read it again. Check both records and retain the script, map and output.
3. In separate data copies, duplicate an id and use an invalid gender. Capture each rejection and explain how to correct the source without hiding the error.
4. At full level, repeat the valid case using a DuckDB table and a parameterized query selecting one id. Compare outputs and close the connection. At basic level, record that DBI was not evaluated.

### Understanding questions

- What does one input row mean to this constructor, and how would you prepare two rows with the same id?
- When would you use SQL parameters, and what would you do if a large identifier arrived rounded?

### Observable criteria

- The valid case was built, saved and reread with its explicit values.
- Both invalid inputs were rejected and their diagnostics were retained.
- The source correction was explained and made in a new copy.
- The DBI path was checked at full level or explicitly excluded at basic level.

**Evidence to retain:** Participant script, valid NDJSON, diagnostics for both negative cases and DBI comparison when applicable.

**Task record:** state; active/wait minutes; interventions and assistance;
observed understanding; answers; documentation; evidence; repeat outcome/files if performed.

## R05. Design, modify and reuse a view

**Purpose:** Solve a new extraction task using documentation and verify its meaning.

**Scope:** Required for core and seven.

### Prompt and steps

1. Create an Immunization view with status, patient and date from the trial NDJSON; retain the definition before extending it.
2. Add columns for both occurrence alternatives and save a second JSON definition. Run it and explain every NA using the original resources.
3. Read the saved definition with vista_leer() and repeat the extraction; check keys, values, types and counts without requiring row order unless agreed.
4. Describe a change for an analysis need of your own, using only the fictional data. Record documentation consulted and any supplied solution.

### Understanding questions

- What must you save so another person can reproduce this extraction?
- Which original information does your view leave out that another analysis might need?

### Observable criteria

- Two JSON versions were retained and the second was reused.
- Both immunizations remained correctly identified.
- Missing alternatives and types were checked against NDJSON.
- The participant explained the view and any assistance, beyond executing it.

**Evidence to retain:** vista-inmunizaciones-01.json, vista-inmunizaciones-02.json, tables and the participant’s explanation.

**Task record:** state; active/wait minutes; interventions and assistance;
observed understanding; answers; documentation; evidence; repeat outcome/files if performed.

## R06. Analyze allergies while preserving the counting unit

**Purpose:** Avoid overcounting records when expanding reactions and manifestations.

**Scope:** Required for core and seven.

### Prompt and steps

1. Locate the allergy NDJSON and execute the catalogue view. Compare nrow() with the number of distinct ids.
2. Group rows by id and reconstruct allergy→reaction→manifestation for a record with multiple rows.
3. Inspect an allergy with no reaction and its missing values. Identify multiple categories and distinguish criticality from reaction severity.
4. Explain which count you would report for recorded allergies and how it changes when counting manifestations. Retain the code and justification.

### Understanding questions

- What error would result from using nrow(table) as the number of allergies?
- Does an allergy with no documented reaction mean that no reaction occurred?

### Observable criteria

- Row and distinct-id counts were calculated separately.
- Manifestations retained their own reaction and severity.
- Allergies without reactions were retained in the analysis.
- The counting unit and treatment of missing values and lists were justified.

**Evidence to retain:** Counting script, table by id and explanation of the unit of analysis.

### Operational preparation

Adapt the ID, directory and technical level to the agreement. API names and filenames stay unchanged.

```r
archivo <- system.file("extdata", "alergias_r4.ndjson", package = "fhirviews")
alergias <- vista_ejecutar(archivo, vista_plantilla("alergias"))
alergias[, c("id", "estado_clinico", "gravedad_reaccion", "reaccion_codigo")]
length(unique(alergias$id))
```

**Task record:** state; active/wait minutes; interventions and assistance;
observed understanding; answers; documentation; evidence; repeat outcome/files if performed.

## R07. Repeat the analysis and examine recovery

**Purpose:** Check repeatability and document which tasks can be repeated without intervention.

**Scope:** Required for core and seven.

### Prompt and steps

1. Run the agreed technical level again in a different directory, retaining both reports and the same candidate.
2. Compare findings and states; distinguish path/time differences from data/type differences.
3. Repeat view creation/reuse and allergy counting without observer hints. Identify the tasks and files supporting the repeat.
4. At full level, review recovery and explain rollback/retry without duplicates. At basic level, retain not evaluated and limit the conclusion.

### Understanding questions

- Why does rerunning the automatic command alone not demonstrate that you can modify a view?
- What would you check before retrying a load that failed halfway through?

### Observable criteria

- Both attempts and the candidate were identified.
- Data, states and types were compared, with differences explained.
- The manual repeat recorded scope, result and interventions.
- Recovery was interpreted according to the technical level.

**Evidence to retain:** Two reports, written comparison and manual-repeat files; describe any assistance.

### Operational preparation

Adapt the ID, directory and technical level to the agreement. API names and filenames stay unchanged.

```r
iniciar_piloto("basico", "sesion-P01-intento02")
a <- jsonlite::read_json("sesion-P01-intento01/piloto/aceptacion.json")
b <- jsonlite::read_json("sesion-P01-intento02/piloto/aceptacion.json")
identical(a$hallazgos, b$hallazgos)
```

**Task record:** state; active/wait minutes; interventions and assistance;
observed understanding; answers; documentation; evidence; repeat outcome/files if performed.

## R08. Assess usefulness and agree on closure

**Purpose:** Decide what use was demonstrated and which improvements need follow-up.

**Scope:** Required for core and seven.

### Prompt and steps

1. Review R01–R07 and R09 when applicable; log obstacles and interpretation errors with expected/observed behavior and evidence.
2. Answer the closing interview: usefulness for your own task, most confusing step, confidence interpreting outputs and up to three priority improvements. Distinguish opinion from measurement.
3. Participant and maintainer review the decision for the exact scope, excluded tasks, owners and next check. Critical/high issues require correction and retesting.
4. Export JSON, CSV and text; check that records can be reopened and agreed attachments are readable and contain no personal information.

### Understanding questions

- Which real task would you try next with this tool, and what prevents you from doing it today?
- What would you need to check before recommending it to a colleague?

### Observable criteria

- Usefulness was related to a specific task and its limitations.
- Issues and priorities have evidence and an owner.
- The human decision and unevaluated scopes were explicit.
- Agreed exports and attachments were reviewed and retained.

**Evidence to retain:** Reviewed exported record, experiencia-usuario.txt, issues and follow-up plan.

**Task record:** state; active/wait minutes; interventions and assistance;
observed understanding; answers; documentation; evidence; repeat outcome/files if performed.

## R09. Evaluate the laboratory path for seven constructors

**Purpose:** Complete SQL→R4 laboratory→tables when evaluating the seven-type scope.

**Scope:** Required for seven; exclude with a reason for core.

### Prompt and steps

1. Confirm seven-type scope and full level; open the installed laboratorio-r4.R example and read inputs, maps and queries before execution.
2. Run laboratorio_r4() and write its resources to a new NDJSON. Identify types, ids and links between patient, specimen, observations and report.
3. Save the three views and compare V8/DuckDB tables by keys, values and types. Inspect volume/result scale in NDJSON.
4. Explain how to obtain one row per result and avoid counting a report twice. For core scope, mark not evaluated with a reason; do not claim evaluation of all seven types.

### Understanding questions

- Why does the report-reference table contain more rows than reports?
- Which parts of this case would require new decisions for another SQL source?

### Observable criteria

- The example ran from the verified installation using DBI/DuckDB.
- Specimen, result and report references and literals were checked.
- All three views were saved and tables compared with both engines.
- The interpretation distinguishes specimen, observation, report and view rows.

**Evidence to retain:** Laboratory NDJSON, three JSON view definitions, compared tables and participant explanation.

**Task record:** state; active/wait minutes; interventions and assistance;
observed understanding; answers; documentation; evidence; repeat outcome/files if performed.
