# Detailed evaluation of the external R4 pilot

[Español](EVALUACION-PILOTO.md) · **English**

**Protocol 2.1 · Candidate 0.5.0.9003 · Fictional data.** This document defines
observation, interpretation and closure. [LEEME.en.md](LEEME.en.md) covers
installation. The [R](PROTOCOLO-PERFIL-R.en.md) and
[FHIR](PROTOCOLO-PERFIL-FHIR.en.md) protocols contain participant tasks; the
[observer appendix](ANEXO-OBSERVADOR.en.md) contains reference answers.

## 1. Purpose and evaluation questions

Determine whether people outside development can prepare the candidate,
execute and modify an R4 workflow, explain results and retain reproducible
evidence. Find problems and prioritize improvements for a bounded release.
The session is not a clinical evaluation or certification of interoperability
with every system.

| Dimension | Question | Supporting evidence |
|---|---|---|
| Preparation | Can the participant install and open the correct copy? | Identity, loaded library, environment, times and assistance. |
| Correctness | Do outputs match sources and checks? | Resources, views, tables and diagnostics checked against originals. |
| Understanding | Can the participant explain keys, rows, absence and limits? | Own answers and a justified observer assessment. |
| Independence | Can tasks be solved and repeated without intervention? | Task states, interventions and evidence of manual repetition. |
| Semantics | Are mapping and extraction decisions defensible? | Field/Coding/reference matrices and identified information loss. |
| Reproducibility | Does another attempt preserve results and decisions? | Fixed candidate, two directories, scripts, views and comparison. |
| Usefulness | Does the workflow address a recognizable participant need? | Own-use example, limitations and stated priorities. |

An automatic pass, a favorable opinion and a completed task are different
forms of evidence. Keep them separate to understand both failures and success.

## 2. Three decisions before starting

| Decision | Options | Consequence |
|---|---|---|
| Participant profile | R / FHIR | R evaluates analysis and use; FHIR audits semantics/interoperability. |
| Technical level | Basic / full | Full adds DBI/DuckDB and recovery; basic does not evaluate them. |
| Human-evaluation scope | Five-type core / seven constructors | Seven requires full level and completed R09/F09. |

**Core:** Patient, Encounter, Condition, Observation and Immunization. The
installed check builds six resources of these five types. AllergyIntolerance
reading evaluates extraction/counting without adding a constructor.

**Seven:** core plus Specimen and DiagnosticReport through the laboratory case.
That case has five resources of four types, extending joint coverage to seven
constructor types. It does not contain seven resources in one file. To recommend
a release for this scope, obtain laboratory evidence from both participant
profiles; an R record alone does not answer the FHIR audit questions.

Do not exclude task 09 while claiming evaluation of seven types. If an obstacle
prevents execution, retain seven-type scope with a pending result or repeat in
another session with explicitly agreed core scope. Do not shrink scope after a
failure to conceal it. Retain both attempts.

Rust and a FHIR server are separate extensions, unnecessary for the local trial.
A `$validate` trial is agreed separately using a test server, canonical profiles
and fictional data. Resources are not written to a server as part of this pilot.

## 3. Participants, preparation and materials

Initially include one R user and one person with FHIR experience. Record R,
SQL, FHIR, profile and usual-tool experience; FHIR knowledge does not imply R
proficiency. Use an agreed participant ID. If one person completes both profiles,
retain separate records, execution order and prior exposure: the second session
has a learning effect.

The maintainer supplies the same ZIP, hash, candidate and protocol to everyone
in a round. Record delivery date and prior use of earlier materials. Analyze
different protocols as separate rounds. The form rejects imports with another
candidate/task identity. Do not copy passed checkboxes to changed tasks.

The observer prepares the browser, R, directory and dependencies and checks the
kit before the appointment. Preparation performed for the participant must be
documented and does not demonstrate independent installation. To evaluate an
installation from scratch, reserve that activity and time it separately.

Agree available time, breaks, delivery channel and the option to stop. There is
no predefined passing time: early sessions establish a baseline. When time runs
out, record the task as blocked/pending and arrange continuation; duration alone
is not a technical failure. Multiple appointments can share the same round ID;
use new attempt directories when rerunning the trial.

## 4. Session script

1. **Opening.** Explain that the tool and documentation are being evaluated.
   Record profile, level, scope, environment, experience and previously consulted
   material. Agree how observations are recorded. Do not record audio/video by default.
2. **Preparation.** Run R01/F01, separating dependencies, installation and opening.
   Check identity and retain reviewed original messages.
3. **First attempt.** Read each task, ask the participant to explain what they are
   trying and allow self-directed documentation. Avoid revealing expected answers
   or correcting an explanation before recording it.
4. **Observation.** Record active/wait time, assistance, evidence and explanations.
   Ask the task’s understanding questions without suggesting the answer. A brief
   verbatim phrase may help document a misunderstanding.
5. **Laboratory.** Complete R09/F09 before closure under seven-type scope. Check all
   three views, references and decimals; opening the example is insufficient.
6. **Repetition.** R07/F08 includes another trial and identified manual tasks.
   Retain the first attempt, new assistance and effects of learning.
7. **Closure.** R08/F08: interview, issue review, human decision and export. Confirm
   that the participant considers the conclusion faithful to the observations.

Suggested R order: 01–06, 09 when applicable, 07, 08. FHIR order: 01–07, 09 when
applicable, 08. Consult reference answers after recording the first attempt.
Memorizing syntax is not required to demonstrate understanding.

## 5. Recording assistance and outcomes

| State | Recording rule |
|---|---|
| Pending | Not started or insufficient evidence. |
| Completed without assistance | Criteria and explanation met with zero observer interventions; self-directed documentation is permitted. |
| Completed with assistance | Criteria met after one or more recorded interventions. |
| Blocked | Unable to continue because of tool, environment, documentation or available time; describe the cause. |
| Failed | Attempted, but result or interpretation does not meet expectations. |
| Not evaluated | Explicitly excluded from scope with a written reason; not a pass. |

Record every intervention: task, timing, type and content. Useful types are
clarifying the prompt, directing to documentation, a conceptual hint, code
correction or a complete solution. An observer explanation that changes the
solution path is assistance. Record help resolving network problems too,
identifying it as environmental. Count identifiable assistance episodes rather
than individual keystrokes.

Record **active minutes** separately from **waiting minutes**. Active time
includes documentation search and reasoning; waiting includes downloads,
installation execution, breaks and interruptions. Do not count the same time
in both categories. Compare equivalent tasks, preparation and technical levels.
Short duration does not demonstrate correctness.

## 6. Understanding, ease and evidence

| Observed understanding | Criterion |
|---|---|
| Pending | Questions have not been asked/reviewed. |
| Correct | Explains decisions and limitations with concrete evidence. |
| Partial | Executes or explains part of the task but misses a relevant distinction. |
| Incorrect | Misinterprets the unit, relationship, validation or result. |

Retain initial answers and subsequent corrections in the answers field. A
participant who learns after a hint can finish with correct understanding and
an assisted state. Partial/incorrect understanding requires review; do not mark
complete while an essential explanation remains incorrect, even if tables match.
The form checks record completeness. The observer judges and justifies answers;
the form does not automatically assess FHIR knowledge.

Optionally ask task ease: **1 very difficult, 2 difficult, 3 intermediate,
4 easy, 5 very easy**. This is a descriptive local measure, not a validated
scale or passing score. A response is optional; ask which step influenced it.
It does not replace time, correctness or understanding.

Every completed task needs an evidence reference, answers, understanding,
checks, time and coherent intervention counts. Use filenames relative to the
evidence package. The form does not check file existence: the observer opens
and compares them before marking review complete.

For repetition, identify tasks, new attempt/files, outcome and interventions.
An initially assisted task may later be repeated independently; retain both
observations. The record supports independence for an explicit subset of tasks
repeated without assistance, without extending that claim to other tasks.

## 7. Issues and closure criteria

| Impact | Example | Treatment |
|---|---|---|
| Critical | Incorrect output accepted as valid, false association or loss of integrity. | Suspend favorable closure; investigate, correct and repeat. |
| High | An essential in-scope task cannot be completed. | Resolve or retest in another environment; do not accept. |
| Medium | Continuing requires assistance or a documented workaround. | Prioritize and verify a solution; explicitly retain any follow-up. |
| Low | Unclear wording/navigation/presentation without changed results. | Record improvement and owner. |

Each issue contains task, minimal steps, expected/observed behavior, environment,
evidence, impact, owner and next test. Corrected means a change was applied;
closed requires retesting and identification of the reviewer. An interpretation
error can also reveal a documentation problem.

**Accept for the stated scope:** identity and technical checks verified; every
required in-scope task completed with correct understanding and reviewed
evidence; no open critical/high issues; explicit conclusion reviewed by both
participant and maintainer. Recorded assistance is allowed: session acceptance
does not claim independence.

**Accept with explicit follow-up:** the same essential conditions, with
medium/low issues described, owned and assigned a next test. Do not use this
option to bypass required laboratory work, incorrect interpretation or a high
issue. Any open issue must be reflected in the decision; do not select plain
acceptance while issues remain open.

**Repeat after corrections:** an essential condition is missing, documentation
needs changing or relevant uncertainty remains. This is a useful outcome too.
Keep a pending decision until both people review the evidence.

F07 can be completed with an explained validation plan; external profiles then
remain **not evaluated**. If a server extension is executed, record results
separately and review every warning/rejection/indeterminate response. Neither
a plan nor local acceptance demonstrates conformance to a project profile.

## 8. Closing interview and analysis across sessions

Ask concrete questions without encouraging a favorable recommendation:

1. Which work task would you try to solve with this workflow?
2. Which step caused the most uncertainty, and what information was missing?
3. Which result was hardest to interpret or verify?
4. What could you repeat independently, and what help would you still need?
5. Which three changes would you prioritize, and why?
6. What would you check before recommending the tool or using another source?

Analyze by participant profile, technical level, scope, round and experience.
For each task report attempted, completed independently, assisted, blocked,
failed and excluded counts, retaining explicit numerators/denominators. An
unstarted or blocked required task does not leave the denominator to improve
the result. Report out-of-scope exclusions separately. Do not combine basic/full
levels or different protocol rounds into a single success rate.

Report active/wait times with observation counts. With few participants, show
individual values and range; do not infer general superiority or population
satisfaction. Before/after comparisons use the same tasks and report protocol,
environment and learning changes. Repetition has a practice effect and alone
does not show improvement caused by the product.

The round conclusion summarizes observed scope, participants/experience,
per-task outcomes, misunderstandings, up to three priorities, owners and the
next trial. Keep a record of changes between rounds.

## 9. Evidence package and continuity

Keep candidate/hash, protocol, SESION.json, original technical reports,
scripts, JSON views, fictional NDJSON, comparisons, JSON/CSV/TXT records,
experience notes and issues. Open exports to check preservation of scope,
answers, understanding and assistance. Test import in an empty record after
exporting the current session.

Browser storage is auxiliary: export before closing. Review paths/personal
information before sharing only agreed files. Completed records are never
included in the distributed ZIP. The maintainer defines evidence ownership
and storage location; the kit does not transmit it.

If protocol 2.0 was already delivered, retain it and its hash for that round.
Use 2.1 for a new round or by explicit agreement before starting tasks. The R
package keeps its identity; task and ZIP identities change. Exports from the
previous protocol cannot be imported into this one.
