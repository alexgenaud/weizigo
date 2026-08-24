<!-- model-task-metrics.schema.md — T750, generated 2026-08-24.
     NEVER hand-edit.  Regenerate via tools/regression-model-task-metrics.sh
     when fields are added/renamed/retired.  Schema-conformance control lives
     in tools/regression-model-task-metrics.sh; the regression exit code is
     the gate. -->

# `docs/infra/model-task-metrics.jsonl` — schema and store-facts rule

**Task:** T750 (record what predicts re-dispatch; retire the dimension that
never had a signal).  **Date:** 2026-08-24.  **Source of truth for the
record's design:** `docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/measurement-methodology.md`
§3 (the governing rule: **store facts, derive at report time**) and §5/§6
(the verification and cost metrics).  **Conformance control:**
`tools/regression-model-task-metrics.sh` (wired into `zig build test`).

## 0. The rule that matters

> **Store what was observed; never freeze a derived or normalized number
> into the record.**

That is the methodology §3 rule verbatim, and it is what this schema is
built to enforce.  A `correctness` of 38 and `rubric_max` of 30 are
**observed** — they are the grader's own readings.  A derived `delta_anchor`
or a renormalized score is **derived** — and the schema refuses to store it.
When the same number has to be computed again at report time, that is the
design working as intended, not a deficiency.  §4 of the methodology is the
deferred vision; if and when a renormalization is built, the new column is
added here, not silently appended to existing rows.

The three ways the rule manifests in the schema:

1. **Counts, not percentages.** Any quantity that is the ratio of two
   integers (precision, recall, canary_recall) is stored as a numerator
   AND a denominator (`canary_recall_num`, `canary_recall_den`), never as
   `0.75` or `"75%"`.  The schema-conformance control refuses a row that
   carries a percentage where a num/den pair belongs.
2. **`null` means UNKNOWN, never 0.** When a field is not measured on a row
   (e.g. `cost` is null for runs before the T521 token capture), the value
   is `null`, not `0`.  Absence of an assertion is UNKNOWN — that is the
   "absence of evidence is not evidence of absence" discipline the
   measurement methodology §10 already commits to.
3. **One fact per field.** Each field records ONE observation.  If the
   same observation is reported in two forms (e.g. `mechanical_score` =
   `"60/60"` and a count pair underneath), the field is the count pair and
   the fraction is the report-time derivation, not a stored column.

## 1. Field reference

Every field, its JSON type, and the meaning of `null` where it applies.
Fields with `?` after the name are optional — present when observed, absent
when not.  "Task-type" labels a field whose presence depends on `task_type`.

### 1.1 Identity — every row has these

| field | type | meaning |
|---|---|---|
| `task_type` | string | One of: `audit`, `infra`, `research`, `implement`, `battery`, `spec/design`, `orchestration-seat`, `grade`, `integration/reframe`, `census-harvest`, `cleanup-hygiene`, `design-spec`, `race`, `science-probe`, `terminology-refactor`, `tooling-fix`, `onboarding-land`.  The D027 eight (audit/verification, infra/tooling, research/census, implementation-bounded, integration/reframe, spec/design, battery-heavy, orchestration-seat) coexist with T868's ten (`audit`, `census-harvest`, …).  Pick the one the row's source labels carry — both are valid; do not silently re-key (the matrix migration was operator-ratified and an unmigrated row is *not* a defect to be re-fixed in this file). |
| `model` | string | Canonical model label (one spelling per model; the canonicalizer is `src/managent/main.zig` `canonicalizeModelTag` via `tools/model_tags.py` — T801). |
| `serving_tag` | string | The full tag the API or runner recorded (e.g. `claude-haiku-4-5-20251001`, `stealth/ox-alpha`, `glm-5.2:cloud`).  Always present, even when identical to `model` — the record must carry the full provenance. |
| `epoch` | string | The epoch the run belongs to (e.g. `2026-08-18`, `pre-2026-08-18`, `2026-08-21`).  When the model has a recorded boundary (model-registry.md §Epoch rules), the row's epoch is the one it ran in, NOT the aggregate.  Aggregating across a boundary is the same class of defect as averaging pre- and post-bump deepseek-v4-flash. |
| `run_id` | string? | The race/run identifier when this row is one of N (e.g. `T626-ds-r3`); null for singleton tasks. |
| `task_id` | string | The kanban task identifier (e.g. `T447`, `T557`, `T885`). |
| `n` | int | Number of repeats this row aggregates.  `1` for a singleton.  Race rows may carry `n=1` even when they are "one of N" — the `run_id` is the disambiguator. |
| `as_of` | string | ISO date `YYYY-MM-DD` when the row was recorded.  Used to bucket observations into an epoch when `epoch` is absent. |

### 1.2 Score — at least one of these is present

| field | type | meaning |
|---|---|---|
| `correctness` | int? | The grader's raw score.  Null when no score was awarded (e.g. a wall-kill before completion, a no-show race entry, an implement task with no rubric). |
| `rubric_max` | int? | The rubric's maximum (denominator of `correctness`).  Null when no rubric was applied. |
| `mechanical_score` | string? | A free-form mechanical reading (e.g. `"60/60"`, `"172/172 (applies via patch -p0; FAILS git apply --check)"`).  Stored because some races express the headline as a string the schema refuses to decompose (the `0/0` no-show case, the per-arm detail of a diffrace).  Do not derive a stored fraction from it. |
| `verdict` | string? | Verdict class when the row has a non-rubric verdict: `pass`, `pass-with-findings`, `fail-found`, `blocked`, `abandoned`, `no-show`, `no completion in <N> s (wall-guard kill)`.  Distinct from `correctness` (a verdict is a *kind* of close, a correctness is a *number*). |
| `qualified` | bool? | True iff the row is qualified under methodology §5: `score ≥ threshold(task_type)` AND `fabricated_citations == 0` AND `verification_rate ≥ floor(task_type)`.  The gate is the goldilocks ladder's pre-condition. |
| `actionable` | bool? | True iff the dispatch record carries enough fields to drive a re-dispatch decision (`model`, `task_type`, `score`, at least one verification signal).  False rows are recorded but contribute no cell. |

### 1.3 Cost / resource — every row has these when measured

| field | type | meaning |
|---|---|---|
| `cost` | float? \| string? | Cost in tokens or USD; null when not measured.  The methodology §6 token split is the future form (T521); today's value is whatever the runner captured.  Recorded as a number when in tokens/USD, as a string only when the runner wrote a free-form value (e.g. `"unmeasured"`). |
| `cost_grade` | string? | The cost quality label (`measured`, `unmeasured`, `trusted`, `provisional`, etc.).  Always present when `cost` is null. |
| `wall_s` | float? | Wall-clock seconds.  Null when not measured (e.g. a no-show row). |
| `wall_s_grade` | string? | The wall-s quality label (`trusted`, `load-affected`, etc.).  When present, flags the wall-s as not a clean measurement. |
| `cpu_s` | float? | CPU seconds.  Null when not measured. |
| `rss_mb` | float? | Peak RSS in MB.  Null when not measured. |

### 1.4 Audit-only — task_type=audit or task_type=race (audit lane)

These are the fields the T750 amendment folded into the record because they
are **mechanically computable from lane output alone** — no grader, no
rubric, no judgement.  Two dimensions, both already measured per race (the
sealed race area's `analyse.py` is the working implementation; this row
read it and did not reinvent it).

| field | type | meaning |
|---|---|---|
| `canary_recall_num` | int? | Number of seeded canaries this row detected.  Null when no canaries were seeded (the audit row had no seeded-defect control). |
| `canary_recall_den` | int? | Number of seeded canaries present in the task.  Null when no canaries were seeded.  **Denominator is required when the numerator is present** — refuse the row if only one of the pair is set. |
| `false_flags` | int? | Number of FALSE flags (lanes called a defect the grader's ruling cleared).  The den of precision.  Null when no canaries were seeded. |
| `flags_total` | int? | The den of precision: `canary_recall_num + false_flags + over_refutation_count`.  Null when no canaries were seeded.  **Counts, not a ratio.** |
| `fabricated_citations` | int? | Number of citations the grader identified as fabricated (path does not exist, line number drifted, file says something different).  `0` is a *reading* (the grader looked and found none); `null` is **UNKNOWN** (no grader looked, or the grader did not record a count).  From the race ledger, never from a per-doc scan (C10 is per-doc, not per-task). |
| `unique_catch` | array<string>? | A list of finding IDs no other lane in the same race caught AND the grader verified.  Methodology §5 names verified dissent the most valuable output there is; nothing records it today, so the audit headline cannot show it.  Null when no race or no dissent. |
| `paths_named` | int? | Distinct file paths named anywhere in the lane's rows.  Investigative-effort mechanical signal. |
| `paths_real` | int? | Of `paths_named`, how many resolve to a real file on disk.  The interesting signal: high paths_named with high paths_real is *work*; high paths_named with low paths_real is *confabulation*. |
| `median_what_i_checked` | int? | Median length (chars) of the required "where I looked" field.  Investigative-effort mechanical signal.  Proxies "did the lane actually look" without a grader. |
| `discernment_entropy` | float? | Normalised Shannon entropy of the lane's verdict distribution over the corpus.  `1.00` = fully discriminating (the answer varied with the input); `0.00` = the same answer regardless of input.  **A classification whose output does not vary with its input carries no information about the input**, however confidently it is argued. |

### 1.5 Race ledger cross-reference

| field | type | meaning |
|---|---|---|
| `race` | string? | The race identifier this row belongs to (e.g. `T893-race-c3-adjudication`, `T832-diffrace`, `T843-rate-judge`).  When present, the row is one lane of one race. |
| `t818_concrete_test` | string? | A race-specific concrete test (e.g. `T832-diffrace`'s `PASS`/`FAIL` per lane on the T818 open-row nonce case).  Race-specific field; the schema accepts any string but the value is meaningless without the race's own protocol. |
| `t818_note` | string? | The concrete-test's free-form reasoning.  Race-specific. |

### 1.6 Task scope — when the row reports what was touched

| field | type | meaning |
|---|---|---|
| `task_scope.self_reported` | bool | True iff the worker reported the scope; false when the seat (managent) recorded it.  Methodology §10 treats self-reported data as Class-B until two-model + blind-grade. |
| `task_scope.files_touched` | array<string> | Files modified (paths in the repo).  Empty array when nothing was modified. |
| `task_scope.lines_added` | int? | Lines added across `files_touched`.  Null when not measured. |
| `task_scope.lines_removed` | int? | Lines removed across `files_touched`.  Null when not measured. |
| `task_scope.base` | string? | The commit sha the patch applies to (or `null` for non-implement tasks). |
| `task_scope.patch` | string? | The patch path (`untracked/diffrace/<id>.patch` etc.). |
| `task_scope.applies_git_apply_check` | bool? | True iff `git apply --check` succeeds.  Recorded because the dispatch gate is the project commit/pinning mechanism; a patch that does not pass it cannot enter the pipeline. |
| `task_scope.applies_git_apply_check_reason` | string? | Why a patch does or does not pass the check, when non-trivial. |

### 1.7 Capabilities — self-reported

| field | type | meaning |
|---|---|---|
| `capabilities.self_reported` | bool | True iff the worker reported the capabilities.  False when the seat inferred. |
| `capabilities.as_in_findings` | array<string>? | The capabilities the worker's findings file names.  Free-form: the schema does not enumerate; the contract is that the strings come from the findings file verbatim, not paraphrased. |

### 1.8 Notes — free-form

| field | type | meaning |
|---|---|---|
| `grader` | string? | The model that produced the grade (canonical label).  Null when no grader (e.g. a no-show row). |
| `blind` | bool? | True iff the lane did not know the model it was being compared to.  Methodology §5: blinding is a property of the race, recorded per row. |
| `blind_note` | string? | Free-form note when blinding was imperfect (e.g. `"instruction-only — patch and findings name the entrant"`, `"lanes mutually blind; adjudicator given lane→model map deliberately (T893 brief)"`).  The schema does not require it; when present, it explains a `blind=false` that is not a defect. |
| `evidence` | string? | Path to the source of the row's readings (e.g. `findings/T706-race-g-batch2-grade.json`, `docs/epistemic/c3-evidence-triage.md`).  Required when the row carries a per-claim reading (audit/race rows). |
| `notes` | string | Free-form one-paragraph note.  Carries the rank, the load-bearing observation, and any qualifications.  Empty string allowed for no-show rows. |

### 1.9 Reference (T750) — which truth the row was scored against

| field | type | meaning |
|---|---|---|
| `reference` | string? | For race rows where two truths disagree: `"grader_ruling"`, `"sealed_key"`, or `"grader_ruling_sealed_crosschecked"`.  The two truths (the sealed key and the grader's independent ruling) are never averaged; the row records which it was scored against.  Null when the row has only one truth source. |

## 2. Field retirements (T750) — and where the signal now lives

| retired field | was in `tools/model-profiles.py` as | moved to |
|---|---|---|
| `thoroughness` | D027 dimension 3 ("depth of coverage").  Emitted `—` (null) by design — no per-task recorded signal ever existed. | `canary_recall` (`canary_recall_num` / `canary_recall_den`).  Same question, mechanical, already measured per race. |
| `citation_honesty` | D027 dimension 7 ("fabricated citations graded down").  Emitted `—` (null) by design — the keyword proxy cannot distinguish "reported no fabricated citations" from "was caught fabricating"; the per-doc C10 scan does not feed back to a per-task record. | `fabricated_citations` (the race-ledger integer, NOT a per-doc scan).  The signal is recorded where the grader looked; a row that does not record the integer is **UNKNOWN** (null), not zero. |

**The retirement is a row-of-the-claim, not a removal of the model-profile
field.** `tools/model-profiles.py` continues to emit `thoroughness` and
`citation_honesty` as `—` (null), unchanged, so the dimension taxonomy
(D027, eight dimensions) is preserved for the cost-ladder and the
role-map (Auditor/Researcher dimensions still name "thoroughness" and
"citation honesty" — they name a *kind of capability* even though the
ledger cannot grade it).  What this row does is (a) record where the
signal now lives, (b) put the integer in the record where it can be
queried, and (c) keep the model-profile's null-by-design contract for
the per-task signal that does not exist.

The model's docstring at `tools/model-profiles.py` cites T750 as the
disposition (retired-with-successor / moved-to-race-ledger), and the
regression control still passes.

## 3. Three generalisations the T750 amendment demands

The two-field argument is not specific to the `audit` rubric — these
generalisations are stated here or refuted, per the brief.

1. **`canary_recall` is task-type-general.**  Any task type with a
   seeded-defect control (audit, implement, infra, orchestration) can
   carry `canary_recall_num` / `canary_recall_den`.  The C3 race (audit
   evidence triage) is one instance; the T832 diffrace (implement
   nonce-vs-work) is another — its `t818_concrete_test` field is the
   one-arm canary record.  Both are stored as counts, never percentages.
2. **`discernment` and `investigative_effort` are task-type-general.**
   They are mechanically computable from any lane's output rows (paths
   named, paths real, "where I looked" length, distribution of verdicts).
   The C3 race is the first task type to record them; nothing in their
   definition restricts them to audit.  A future race that produces
   distribution + path outputs — which is most races — can backfill.
3. **The pair (`canary_recall`, `discernment`) is not the same separator
   for every defect class.**  A lane that names many real paths AND
   answers the same class to 40 of 42 claims (Race C3's glm-5.2 case)
   is **not** lazy; it has done the work, then answered badly.  A
   metric that collapses "answered a different question" with "answered
   badly" mis-attributes the failure to the model.  The pair separates
   them: a high `paths_real` with low `discernment_entropy` is a
   *brief* defect (the class set the brief offered did not match the
   input) or a *model* defect (the model can't tell the inputs apart);
   the ledger records both, and the report has to say which.  This is
   the open question the brief insists we answer, not assume.

The honest answer to "is the brief ambiguous or the model deficient":
the metric alone cannot say.  The `race_grading_evidence` is the
cross-check — the T893 adjudication splits the C3 penalties between
"the brief owned it" (no legal class existed for 19 of the rows) and
"the model owned it" (rows with a clean answer that the lane still
mis-classified).  The ledger carries the metric; the grader carries
the attribution.

## 4. The conformance control

`tools/regression-model-task-metrics.sh` (wired into `zig build test`)
exercises the schema's load-bearing rules:

- **(a) percent-refused**: a row carrying `canary_recall_pct` or any
  `*_pct` field where a num/den pair belongs is REJECTED (the field is
  not even in the schema; the control asserts the *negative*).
- **(b) pair-required**: `canary_recall_num` and `canary_recall_den` are
  either both present or both null; same for `false_flags` /
  `flags_total` (when the latter is present the former is required).
- **(c) null-not-zero**: a `0` in `fabricated_citations` is allowed and
  is a *reading*; a `null` is UNKNOWN.  The control checks that the
  distinction is preserved (no row substitutes `0` for `null` where
  the field is absent).
- **(d) reference-present**: race rows whose `evidence` ends in a
  findings file that BOTH a grader ruling AND a sealed key could have
  generated carry `reference` set; the control warns (not refuses) on
  race rows that omit it.
- **(e) id-uniqueness**: every `(run_id, task_id, model, as_of)` tuple
  is unique (a re-run is a new row, not an edit).
- **(f) type-roundtrip**: every `task_type` value appears in the
  known set; unknown values are warned (the project grew task types
  organically and an unmapped value is a soft signal, not a hard fail).
- **(g) ledger-vs-source parity**: for every backfilled row, the source
  findings file contains the integers the row carries (the control
  grep's the source for the canary counts and the fabricated counts
  it backfilled).
- **(h) retirement-cited**: `tools/model-profiles.py`'s `thoroughness`
  and `citation_honesty` docstrings carry the T750 disposition text;
  the control greps for it.

The control is the standing gate.  A schema change that breaks a backfilled
row fails it.  A backfilled row whose integers do not match the source
fails it.  A new field that is a percentage where a num/den pair belongs
fails it.  The control is the only harness that can defend the schema
from a well-meaning future re-introduction of the defects T750 retired.

## 5. Re-key / migration policy

T565 migrated the task-type labels (T-A…T-H → the D027 eight plus
T868's ten).  The schema accepts BOTH because the migration is
operator-ratified and an unmigrated row is not a defect to be re-fixed
in this file.  The rule for new rows: pick the one the row's source
labels carry.  The rule for old rows: do not silently re-key; the
matrix and the matrix-cell docs are the migration surface, not the
JSONL.

## 6. Why this file is the one the dashboard queries

The brief names five target queries for the dispatch decision
(cost-ladder, cost quality, etc.); each needs a fact the JSONL
records.  Adding a column is cheap; re-querying every report that
already exists is not.  That is why the schema stores facts and
derives numbers at report time — the next time we want a different
aggregation, we do not migrate 44 rows, we write a query.

The T750 amendment makes that concrete: the audit-task headline is
the pair (`canary_recall`, `false_flag_rate`) — and both are now
*queried* from the num/den pair on the row, not stored as
percentages.  When the next amendment wants a different separator,
the same rows feed it.
