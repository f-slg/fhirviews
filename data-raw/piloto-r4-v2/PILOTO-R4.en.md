# External pilot of R4 scope

[Español](PILOTO-R4.md) · **English**

Protocol **2.1**, candidate **0.5.0.9002**, fictional data. Record file, commit,
SHA-256 and environment. Technical reports, the human decision and profile
validation are separate evidence. The candidate has no version DOI and does
not inherit the DOI of 0.5.0.9000.

## Choose and prepare the session

Agree three decisions: R/FHIR participant profile, basic/full technical level
and core/seven scope. Core covers five constructor types and allergy extraction;
seven adds Specimen/DiagnosticReport and requires full level and completed
R09/F09. Seven types are covered across cases; the laboratory example produces
five resources of four types.

The [detailed evaluation](EVALUACION-PILOTO.en.md) defines questions, observation,
understanding, assistance, repetition, issues and closure. The
[preparation guide](LEEME.en.md) covers dependencies, hashes, installation,
session opening and files. Use the [R](PROTOCOLO-PERFIL-R.en.md) or
[FHIR](PROTOCOLO-PERFIL-FHIR.en.md) protocol. The
[appendix](ANEXO-OBSERVADOR.en.md) provides solutions to consult after the first attempt.

## Execute and record

1. Prepare dependencies, identity and a new directory per attempt. The launcher
   verifies the candidate and installs it in an isolated library.
2. Complete tasks/questions before consulting solutions. Self-directed
   documentation is allowed; record every observer intervention, its content,
   type and count.
3. R order: 01–06, 09 if applicable, 07, 08. FHIR order: 01–07, 09 if applicable,
   08. Laboratory evaluation precedes seven-type closure.
4. Record state, understanding, answers, evidence, active minutes and waiting.
   Repeat identified manual tasks while retaining both attempts.
5. Review issues and conclusion, export JSON/CSV/TXT and inspect files before
   sharing through the agreed channel. The bilingual form works locally and
   does not send results.

## Interpret and close

The candidate’s five automatic checks retain their schema: basic excludes
recovery; full requires it. Human laboratory work does not add an automatic
check. F07 requires a validation plan; executing a test server is a separately
agreed extension. Rust is optional too. No servers or patient data are required.

Human acceptance requires completed in-scope tasks, correct understanding,
checked evidence and review by both people. Open critical/high issues prevent
favorable closure. Retain assistance records; claim independence only for tasks
repeated without help and supported by new-attempt files. Unexecuted profile
validation remains not evaluated even if the local session is accepted.
Explicit minor follow-up or repetition after corrections are valid decisions;
automatic results never replace human judgment.

## Continuity across rounds

Retain protocol 2.0, records and hashes if that round has started. Use 2.1 for a
new round or by agreement before tasks begin; previous exports are not imported
here. Both languages share tasks, criteria and identity. Switching language
preserves answers without translating them. The R package remains the same
verified candidate.
