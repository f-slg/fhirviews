# FHIR profile: semantics and R4 interoperability

[Español](PROTOCOLO-PERFIL-FHIR.md) · **English**

Protocol **2.1**, candidate **0.5.0.9002**, fictional data.

Read [the evaluation](EVALUACION-PILOTO.en.md) and
[technical preparation](LEEME.en.md) first. Record participant profile,
basic/full technical level and core/seven scope as three separate choices.

Tasks 01–08 are required. Task 09 is required for **seven** scope and
needs full level; explicitly exclude it for core. Perform 09 before closure 08.
Answer in your own words. Self-directed documentation is allowed.

The observer records state, active/wait time, interventions, understanding,
answers, consulted documentation, evidence and manual repeats. Do not consult
reference answers before the first attempt. Memorized commands are not required.

## F01. Define interoperability scope and candidate identity

**Purpose:** Delimit the claims this session can support and prepare a reproducible environment.

**Scope:** Required for core and seven.

### Prompt and steps

1. Agree on FHIR participant profile, technical level, core/seven scope and interoperability questions. Record FHIR, R, SQL, profile and terminology experience separately.
2. Check candidate identity and open the isolated library using LEEME.en.md; record R assistance separately from semantic defects.
3. Read the five checks and distinguish local construction, table comparison, profile validation and human evaluation. Record DBI/recovery exclusions at basic level.
4. Identify the supplied base-profile/HAPI evidence as prior evidence and state which checks of your own environment are outside this session.

### Understanding questions

- What does the local constructor check, and what requires profile or terminology validation?
- What evidence would you request to claim interoperability with a specific system?

### Observable criteria

- Identity, environment, level and agreed scope were recorded.
- Installation was checked and assistance described.
- Checking layers and their evidence were distinguished.
- Unevaluated profiles and servers were stated explicitly.

**Evidence to retain:** Identity/environment, reports consulted and a written checked/not-evaluated matrix.

### Operational preparation

Adapt the ID, directory and technical level to the agreement. API names and filenames stay unchanged.

```r
source("INICIAR.R")
iniciar_piloto("completo", "sesion-P02-intento01")
abrir_sesion("sesion-P02-intento01")
packageVersion("fhirviews")
find.package("fhirviews")
help("fhir_mapa", package = "fhirviews")
browseVignettes("fhirviews")
```

**Task record:** state; active/wait minutes; interventions and assistance;
observed understanding; answers; documentation; evidence; repeat outcome/files if performed.

## F02. Review mappings, cardinalities and semantic decisions

**Purpose:** Distinguish base-model rules, constructor contract and source decisions.

**Scope:** Required for core and seven.

### Prompt and steps

1. Review maps in r4-estabilidad.R and the resulting resources. Relate columns, constants and references to concrete JSON destinations.
2. For Patient, Encounter, Condition, Observation and Immunization, create a field/source-or-constant/base-or-constructor requirement/project-decision matrix.
3. Check at least Encounter status/class, Condition subject, Observation status/code and Immunization patient/vaccineCode/occurrence using the help and agreed R4 model.
4. Explain a constant that cannot automatically transfer to another source and why a ViewDefinition is not a complete inverse map.

### Understanding questions

- Why does the constructor requiring id not mean every FHIR resource must already have it before creation?
- Is it valid to assume status=final for every source because the example uses it?

### Observable criteria

- The matrix distinguishes columns, constants and references.
- Base requirements, invariants/profiles and local contract were separated.
- Semantic decisions requiring project agreement were identified.
- The limits of reconstruction from a tabular projection were explained.

**Evidence to retain:** Per-resource matrix with versioned documentary sources and decision rationale.

**Task record:** state; active/wait minutes; interventions and assistance;
observed understanding; answers; documentation; evidence; repeat outcome/files if performed.

## F03. Audit types, choices, dates and precision

**Purpose:** Check that transformation preserves meaning and rejects incompatible alternatives.

**Scope:** Required for core and seven.

### Prompt and steps

1. Compare FALSE, absence and i1/i2 texts against NDJSON and views. Identify occurrence[x] and doseNumber[x] by their JSON names and types.
2. Inspect the JSON literals 72.00/0.50 and computed boundaries; explain the risk of SQL DECIMAL→double before mapping.
3. In a separate fictional script, try Patient.active="false", an impossible date and an Immunization with both occurrence alternatives. Record rejections with class and field when known.
4. Explain partial date/Date versus an instant with timezone and why hours, quantities or absent fields must not be filled in for convenience.

### Understanding questions

- Do the literals 72 and 72.00 provide the same precision evidence?
- What semantic harm could result from replacing an unknown date with an invented date?

### Observable criteria

- Present values and missing fields were checked without invented conversions.
- Choice alternatives and scale were checked in the exact source.
- All three invalid cases were rejected and diagnostics retained.
- The participant explained dates and precision with their limitations.

**Evidence to retain:** Choice matrix, NDJSON fragments, script and negative-case diagnostics.

**Task record:** state; active/wait minutes; interventions and assistance;
observed understanding; answers; documentation; evidence; repeat outcome/files if performed.

## F04. Check references and graph integrity

**Purpose:** Distinguish permitted target, constructed key and existence of the referenced resource.

**Scope:** Required for core and seven.

### Prompt and steps

1. Draw or tabulate links among the six core resources. Identify type/id, patient references and encounter relationships.
2. Check that each local reference resolves to the expected resource by type and id; record absent optional links.
3. Create one negative case targeting Group from Immunization.patient and another using a syntactically valid patient id absent from the dataset. Compare behavior.
4. Explain handling of duplicate ids across servers, absolute references, URNs and persistence dependencies; identify what the local constructor does not check.

### Understanding questions

- Can Patient/nonexistent pass the constructor? What remains to be checked?
- Is id p1 sufficient to join resources from two different servers?

### Observable criteria

- The case’s links were checked by type and id.
- Optional absences were retained and explained.
- Incompatible target rejection and an unresolved reference were contrasted.
- Structural validation was distinguished from existence/resolution.

**Evidence to retain:** Link inventory, both-case script and rejection/unresolved-reference evidence.

**Task record:** state; active/wait minutes; interventions and assistance;
observed understanding; answers; documentation; evidence; repeat outcome/files if performed.

## F05. Examine bindings and Coding fidelity

**Purpose:** Check vocabulary selection without treating labels or partial lists as full validation.

**Scope:** Required for core and seven.

### Prompt and steps

1. Inspect clinicalStatus/verificationStatus Coding in the allergy example. Identify canonical system, code, display and additional translations.
2. Check the Coding selected by the view and that system/code/display belong to the same entry. Inspect the Coding entry without a code.
3. Create two fictional Patient cases separately: valid and invalid gender. Record rejection of the enumerable required binding and explain why this does not validate any clinical terminology.
4. List systems/ValueSets/versions needed for your environment, distinguishing required/extensible bindings and example data. Server terminology queries remain outside scope unless agreed.

### Understanding questions

- Can display be used as a stable concept identifier?
- Why does a partial code list or code.text not demonstrate a complete required binding?

### Observable criteria

- Coding entries were reviewed as coherent system/code pairs.
- Canonical states and translations were checked without mixing entries.
- The enumerable required binding rejected the invalid code.
- External terminology and project profiles remained explicit requirements.

**Evidence to retain:** Checked Coding table, negative case and project terminology requirements.

**Task record:** state; active/wait minutes; interventions and assistance;
observed understanding; answers; documentation; evidence; repeat outcome/files if performed.

## F06. Audit the projection and its information loss

**Purpose:** Assess whether views retain sufficient relationships for the declared use.

**Scope:** Required for core and seven.

### Prompt and steps

1. Create and save an Immunization view with patient and both occurrence alternatives; justify keys, types and omitted columns.
2. Run the allergy view and check reaction/manifestation relationships, categories as lists and records without reactions.
3. Compare rows, distinct ids and row meaning; identify an extraction that could introduce false associations or overcounting.
4. At full level, compare equivalent V8/DuckDB tables by keys, values and types. At basic level, leave engine comparison not evaluated; explain the conformance suite’s scope.

### Understanding questions

- What information beyond this view would you need to reconstruct the original resource?
- Does passing the test suite imply that any FHIRPath can be translated to SQL?

### Observable criteria

- The saved definition and information loss were explained.
- Reaction/manifestation relationships and rows without reactions were checked.
- Rows and resources were distinguished without artificial associations.
- Engine comparison was documented according to technical level.

**Evidence to retain:** Participant ViewDefinition, audit table and engine comparison or justified exclusion.

**Task record:** state; active/wait minutes; interventions and assistance;
observed understanding; answers; documentation; evidence; repeat outcome/files if performed.

## F07. Design validation against environment profiles

**Purpose:** Produce a reviewable interoperability plan without claiming unperformed executions.

**Scope:** Required for core and seven.

### Prompt and steps

1. For each resource in scope, list base profile, project profile if any, FHIR version, terminology and references needing resolution.
2. Review supplied HAPI evidence as prior maintainer evidence and distinguish it from participant execution. Record remaining project invariants/requirements.
3. Define a future trial or, only if a test server was agreed, run $validate on exact JSON retaining canonical profile, server/version, date, HTTP status and OperationOutcome.
4. Include a valid resource and an altered resource that must be rejected. For an executed server trial classify valid/rejected/indeterminate and review warnings; otherwise leave profile validation not evaluated.

### Understanding questions

- What does valido=NA or an incomplete OperationOutcome mean?
- Why does declaring meta.profile not itself prove conformance with that profile?

### Observable criteria

- A per-resource profile/version/requirements matrix exists.
- Maintainer evidence was separated from participant execution.
- The plan includes positive/negative cases and interpretation rules.
- External validation status was recorded without approving unexecuted checks.

**Evidence to retain:** Validation matrix/plan; for an agreed execution, exact JSON and reviewed OperationOutcome with date/profile/server.

**Task record:** state; active/wait minutes; interventions and assistance;
observed understanding; answers; documentation; evidence; repeat outcome/files if performed.

## F08. Repeat the audit and issue a bounded conclusion

**Purpose:** Check repetition, review findings and decide what interoperability was evaluated.

**Scope:** Required for core and seven.

### Prompt and steps

1. Repeat the installed trial in a new directory and a manual references/Coding/choices audit without hints; identify repeated tasks and retain both evidence sets.
2. Compare findings and record data/type/interpretation discrepancies separately from environment differences. Correct and retest critical/high issues before favorable closure.
3. Answer the interview: hardest mapping decision, missing information for your environment, confidence reviewing results and up to three priority improvements.
4. Participant and maintainer review scope, unexecuted profiles, assistance, owners and human decision; export records and review attachments.

### Understanding questions

- Which interoperability claim can this session support, and which requires another test?
- Would you recommend this path for an integration trial, and under which concrete conditions?

### Observable criteria

- The second attempt was retained and manual-repeat scope identified.
- Findings were compared and discrepancies recorded.
- The conclusion distinguishes structure, semantics, profiles and usefulness.
- Both people reviewed the export, priorities and follow-up.

**Evidence to retain:** Two attempts, repeated audit, exported record and conclusion identifying pending scope.

**Task record:** state; active/wait minutes; interventions and assistance;
observed understanding; answers; documentation; evidence; repeat outcome/files if performed.

## F09. Audit Specimen and DiagnosticReport end to end

**Purpose:** Complete semantic review of the two additional constructors under seven-type scope.

**Scope:** Required for seven; exclude with a reason for core.

### Prompt and steps

1. Confirm full level and run laboratorio-r4.R with fictional data. Identify maps, queries, types and generated resources.
2. Audit the Patient→Specimen/Observation/DiagnosticReport graph and result[].reference/specimen[].reference collections; check all references by type and id.
3. Check required DiagnosticReport status/code, base optionality of subject and Specimen status/subject, issued timezone and quantity precision. Separately test invalid status and result targeting the wrong type.
4. Save all three views, exact NDJSON and V8/DuckDB comparisons; add these types to the F07 plan. Under core scope, justify not evaluated without claiming seven-type review.

### Understanding questions

- Must every Specimen have a Patient subject in base R4?
- What prevents a structurally valid reference from resolving to the wrong result in another source?

### Observable criteria

- Laboratory maps and graph were audited with all links.
- Base cardinalities were distinguished from project requirements.
- Both invalid cases were rejected and precision checked.
- All three views/engines and profile requirements were documented.

**Evidence to retain:** Graph, field matrix, NDJSON, negative diagnostics, three views and compared tables.

**Task record:** state; active/wait minutes; interventions and assistance;
observed understanding; answers; documentation; evidence; repeat outcome/files if performed.
