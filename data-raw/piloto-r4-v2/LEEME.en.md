# Participant guide for the external R4 pilot

[Español](LEEME.md) · **English** · Protocol **2.1**

The [detailed evaluation](EVALUACION-PILOTO.en.md) defines observation,
understanding, assistance, repetition and closure. Read it before agreeing the
session. This guide explains preparation, execution and documentation for
**fhirviews 0.5.0.9003**, for participants and observers. The kit contains
fictional data and an identified package copy. It needs neither patient data
nor a FHIR server. It is a development candidate, not a stable release or a
clinical evaluation. Automatic checks cover only the included cases; record
human use and closure separately.

## Before starting

There are three independent decisions:

| Choice | Meaning |
|---|---|
| Participant profile **R** | Analyst, researcher or epidemiologist; tasks R01–R09. |
| Participant profile **FHIR** | Interoperability or health informatics experience; F01–F09. |
| **Basic** technical level | Installed checks and manual tasks; no DuckDB evaluation. |
| **Full** technical level | Adds DBI/DuckDB, engine comparison and recovery. |
| **Core** scope | Five constructor types and allergy extraction; exclude laboratory with a reason. |
| **Seven** scope | Adds Specimen/DiagnosticReport; requires full level and completed R09/F09. |

Agree profile, level, scope, participant ID, environment and observer. No real
participants have been preassigned in this kit. Use an agreed ID such as P01
rather than names, email addresses or other personal information in shared files.

Attempt tasks before consulting solutions. The observer records time, help,
obstacles, outcome and evidence without solving tasks for the participant.
Hints/solutions count as assistance. Consult the
[observer appendix](ANEXO-OBSERVADOR.en.md) after the first attempt.

### Requirements

| Level | Requirements |
|---|---|
| Basic | R ≥ 4.1.0; cli, httr2, jsonlite, rlang, V8, openssl. |
| Full | R ≥ 4.2.0; basic dependencies plus DBI and duckdb ≥ 1.5.5. |

Install dependencies before starting; the launcher checks but does not install them:

```r
install.packages(c("cli", "httr2", "jsonlite", "rlang", "V8", "openssl"))
# Full level only:
install.packages(c("DBI", "duckdb"))
```

Rust, Java, Docker, PostgreSQL, SQL Server and HAPI are not required. Rust is
optional and not installed by the kit. Full level uses DuckDB’s json extension;
its first use may need a download. Record a network restriction separately from
a FHIR logic failure. A current browser opens the local form, which does not
run R, verify the package or send results.

## Download and verify

1. Obtain the agreed ZIP and matching .sha256 file. Do not mix revisions.
2. Before extraction, calculate SHA-256: Linux
   `sha256sum fhirviews-kit-piloto-r4-v2.zip`; macOS
   `shasum -a 256 fhirviews-kit-piloto-r4-v2.zip`; PowerShell
   `Get-FileHash .\fhirviews-kit-piloto-r4-v2.zip -Algorithm SHA256`.
   Compare with the published/supplied checksum. On mismatch, stop and request
   the correct file/hash.
3. Extract the complete ZIP into your own working directory. Keep internal
   filenames and layout: INICIAR.R locates the package/materials relatively.
4. Open FORMULARIO-PILOTO.html, choose Español/English and R/FHIR, and read
   PILOTO-R4.en.md and the selected participant protocol.
5. Compare CANDIDATO.json, MANIFIESTO-KIT.json and SHA256SUMS. Identity includes
   version, commit, size, SHA-256 and MD5. The launcher checks size and both
   hashes again before installation.

Check internal files with `sha256sum -c SHA256SUMS` on Linux or
`shasum -a 256 -c SHA256SUMS` on macOS. PowerShell can check the package with
`Get-FileHash .\paquete\fhirviews_0.5.0.9003.tar.gz -Algorithm SHA256` and compare
with CANDIDATO.json. Checksums detect changes but are not a cryptographic
publisher signature; obtain files from the agreed official source.

## Execute the agreed technical level

Start a fresh R/RStudio session with the extracted root as working directory:

```r
source("INICIAR.R")
iniciar_piloto("basico", "sesion-P01-intento01")
abrir_sesion("sesion-P01-intento01")
```

For full level install DBI/DuckDB and replace `"basico"` with `"completo"`.
Use a new output directory for every participant/attempt. The launcher refuses
to overwrite it. If another fhirviews copy is already loaded, restart R and
reopen the isolated session. A terminal can run:

```sh
Rscript INICIAR.R basico sesion-P01-intento01
```

The seven-type scope requires full level and R09/F09. Core excludes that task
as not evaluated with a reason. The five automatic checks do not change; human
acceptance for seven types additionally requires laboratory evaluation.
Function names, arguments, technical state keys, filenames and fictional data
values remain as provided by the Spanish-language package in both guides.

## Automatic checks and their limits

The launcher verifies identity, installs into an isolated R library and runs
the technical trial in a new R process. It does not observe tasks or fill in
the form. Verify 0.5.0.9003 and matching candidate checksums in SESION.json and
piloto/aceptacion.json.

| Check | What it covers |
|---|---|
| api_instalada | Isolated installation and loading. |
| vigilancia | 755 input events, 661 confirmed, 94 excluded and 65 cantons, all fictional; not unique people or real rates. |
| contrato_estricto | Incompatible block rejection before writing outputs. |
| recuperacion | Recovery/rollback; not evaluated at basic level. |
| r4_cinco_recursos | Six resources of five types: Patient, Encounter, Condition, Observation and two Immunization, with references, types, absence and decimal scale. |

Basic expects four passes and recovery not evaluated; full expects five passes.
Warnings or errors require review. Do not edit report states to obtain a pass.
Exit status, technical report and human evaluation are distinct results. The
historical five-type check does not limit the current constructor to five:
R09/F09 specifically covers the additional Specimen/DiagnosticReport case.

## Session tasks

| R task | Focus | FHIR task | Focus |
|---|---|---|---|
| R01 | Preparation/correct library. | F01 | Scope/validation layers. |
| R02 | Surveillance/counting unit. | F02 | Mappings/cardinalities. |
| R03 | Provenance/keys/precision. | F03 | Types/choices/negative cases. |
| R04 | Own construction/errors. | F04 | References/graph integrity. |
| R05 | Design/reuse views. | F05 | Bindings/Coding fidelity. |
| R06 | Allergy counts/relationships. | F06 | Projection/information loss. |
| R07 | Repetition/recovery. | F07 | Profile validation plan. |
| R08 | Usefulness/closure. | F08 | Repetition/bounded conclusion. |
| R09 | Analytical laboratory path. | F09 | Semantic laboratory audit. |

Tasks 01–08 are required; 09 is required under seven-type scope. R order:
01–06, 09 when applicable, 07, 08. FHIR order: 01–07, 09 when applicable, 08.
F07 requires a plan; server execution is a separate extension, unnecessary for
core completion. The [R](PROTOCOLO-PERFIL-R.en.md) and
[FHIR](PROTOCOLO-PERFIL-FHIR.en.md) protocols give steps, questions and evidence.
Data/outputs stay local until sharing is agreed.

### Laboratory R09/F09

At full level review the installed examples/laboratorio-r4.R. It builds a
Patient, Specimen, two Observation and DiagnosticReport from fictional data.
Check result[].reference/specimen[].reference and compare all three V8/DuckDB
tables. Record any obstruction without counting the task as passed. HAPI
base-profile evidence is separate: this local session does not validate project
or national profiles, external terminology, a participant server or clinical suitability.

## Observe and close

For each task record state, checked criteria, correct/partial/incorrect
understanding, active/wait minutes, each hint/intervention, independently
consulted documentation, own answers, evidence and manual repetition. Ease
1–5 is optional. Record issues with impact, evidence and retesting needs.

Do not require identical times or memorized commands. Assess understanding,
finding documentation and repeating the workflow. Assisted tasks remain
assisted; document independence only for specified manual tasks repeated
without assistance in another attempt, retaining both evidence sets.

Before ending:

1. Complete the selected form record; an automatic pass does not complete a human task.
2. Record obstacles in experiencia-usuario.txt or the form with reproducible steps.
3. Export JSON and optionally CSV/text. Browser storage is auxiliary; exports
   preserve evidence. The form does not send results.
4. Inspect files before sharing. Paths can identify users or internal layout;
   remove personal information/credentials. This pilot uses no patient data.
5. Review incomplete tasks/issues with the participant. Open critical/high
   issues prevent favorable closure; assign an owner, next action and retest.

Participant and maintainer agree the decision. A form summary does not change
technical evaluacion_externa=pendiente and does not turn an assisted session
into independent use.

## Outputs and sharing

| Path | Contents |
|---|---|
| SESION.json | Technical level, candidate identity, exit status and external-evaluation state. |
| piloto/aceptacion.json and aceptacion.csv | Structured automatic checks and summary. |
| piloto/sessionInfo.txt | R/package environment; may include local paths. |
| piloto/experiencia-usuario.txt | Local space for usability notes. |
| piloto/r4/ | recursos-r4.ndjson, recursos-r4.json and resumen.json; save human-task views/tables separately. |

Share only agreed, reviewed files. Do not publish full records in a public issue
if they contain paths, names or internal information. Agree delivery before
starting; no automatic delivery channel is included.

## Local bilingual form

FORMULARIO-PILOTO.html works offline and offers Español/English. Switching
language changes prompts/labels while preserving answers, states, identity,
scope and evidence. It does not translate entered answers. Paired .md/.en.md
guides have the same tasks and criteria. R/FHIR records are separate, with
JSON/CSV/text export. Browser storage may be blocked for file:// pages: export
before closing or changing computers. Import replaces both records and must
match this round’s candidate and task identity.

CSV exports display labels in the selected language and retain `*_code`
columns for comparing states across languages. JSON preserves complete answers
and all issues when resuming a record; entered text is not translated automatically.

Open FORMULARIO-PILOTO.html from the extracted ZIP. formulario.template.html
is development source with placeholders requiring processing; it is not the
executable participant form.

The form does not install packages, run R, validate FHIR or transmit files.
Review and manually send a prepared notice only through the agreed channel.

## Troubleshooting

| Symptom | Action |
|---|---|
| Missing dependency | Install the named package and retry in a new output directory. |
| Missing/old DuckDB | Use basic scope or R ≥ 4.2 and duckdb ≥ 1.5.5; record the limitation. |
| Output directory exists | Retain it and choose a new attempt directory. |
| Candidate checksum mismatch | Stop; obtain the correct ZIP/hash. |
| Another copy already loaded | Restart R, source INICIAR.R and reopen the same isolated session. |
| Warning or failed check | Keep original output/environment; do not edit reports. Review with maintainer. |
| Browser does not retain records | Export JSON before closing; importing also replaces current records. |
| Extension download blocked | Record the network error separately from engine semantics. |

For unresolved problems record OS, R, level, command, complete reviewed message
and expected result. Remove private information before sharing logs.

## Kit contents and limits

The kit includes EVALUACION-PILOTO, both participant protocols, PILOTO-R4,
observer appendix and their English counterparts; tareas.json/tareas.en.json;
the bilingual form/template; INICIAR.R and PROBAR-CANDIDATO.R; candidate and
kit manifests, SHA256SUMS, LICENSE.md and the source package in paquete/.

The kit has no DOI. The 0.5.0.9000 Zenodo DOI identifies a different archive
and does not transfer to 0.5.0.9003. Distribution is not CRAN acceptance,
clinical evaluation or approval against national profiles.

## Rounds and kit construction

Protocol 2.1 changes 2.0 tasks/criteria. Retain previous records with their ZIP
and hash; they cannot be imported into this revision. Continue already-started
sessions with their agreed protocol or arrange a new round.

The manifest records sources, hashes and unchanged candidate. If
fuente_kit_estado is archivos_de_trabajo_sobre_commit, its commit is an editing
base; exact materials are the hashed files inside the ZIP. It does not claim
that modifications are published at that commit. Reconstruction must produce
identical ZIP bytes and rejects altered sources. Completed records/local
sessions are never included in the distributed kit.
