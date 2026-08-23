# Race protocol v2 — the six rules as testable requirements

**Author:** deepseek-v4-flash/T779 · **Date:** 2026-08-23 · **Status:** DECIDED (seat
decision, operator reviewing — `docs/status/landmark-waypoints-seed-2026-08-23.md` §4).
**Instruments:** `tools/race-collect.py` (mechanical collection + blinding) ·
`tools/regression-race-collect.sh` (its controls). **Supersedes:** the blinding, judging,
family, and ledger provisions of `grand-race.md` §3/§5/§6 (see §4 for the table).

## 0. Why v2 — the negative precedent

Race W (terminology refactor, 2026-08-23) produced three protocol failures, all disclosed
in `findings/T757-terminology-refactor.json`: the judge graded **its own lane** the winner
of both sections, the artifacts' **filenames leaked lane identity** (`out-T754-oxalpha.md`
etc.), and **two lanes committed against the brief's "do not commit."** Each failure was a
disciplinary avoid — "the judge should have recused", "the brief said strip names", "lanes
should have read the bar" — and each is exactly the class of failure that survives
discipline but dies under mechanism. Race results become evidence only when the protocol
makes bias **mechanical to prevent**, not disciplinary to avoid. This document turns the
six seat-decided rules (§4 of the seed ruling) into testable requirements, and the
instruments named above into the enforcement.

A rule is *testable* here in the project's sense: a machine (a script, a schema check, a
consumer gate) can verify it and fail loudly — the same pipeline discipline as the engine
gates G1–G6 (`grand-race.md` §4). Where an automated check does not exist yet, the
requirement states the predicate a future check must assert, and the fail condition it must
raise.

## 1. R1 — Pre-registered rubric

**Rule:** criteria and weights are fixed in the race brief **before any lane runs**; the
judge may note unregistered dimensions but must not score them — they become the next
race's criteria.

**Mechanism:** every race brief ships a rubric section (criteria + weights), and the brief
is sealed before dispatch. `tools/bakeoff.sh` already writes one byte-identical
`prompt.txt` and records its SHA-256 (grand-race.md §3); the rubric lives inside that
sealed brief, so "sealed" is the same seal.

**Checks (testable predicates):**
- *C1.1* the sealed brief (its SHA-256 recorded at dispatch) contains a rubric section
  naming every criterion and weight — a `grep` for the rubric markers resolves;
- *C1.2* the rubric's seal timestamp predates the first lane record in the race ledger —
  the ledger consumer can assert this ordering;
- *C1.3* the judge's report scores **only** registered dimensions.

**Fail conditions:** a scored dimension absent from the sealed rubric voids that score and
flags the round (the note-don't-score rule, seed ruling §4 rule 1, is mechanical at
promotion: the adjudicator's acceptance rejects unregistered scores, and the report must
carry the note separately). A brief whose rubric cannot be located in the sealed bytes is
a pre-flight failure: the race does not dispatch (operator go/no-go stands).

## 2. R2 — Hermetic lanes

**Rule:** byte-identical briefs; each lane writes **only its own** `untracked/race-*/lane-<id>/`
dir; lanes **never commit** and never cross-read. Attribution lives in a **sidecar
manifest, never inside the artifact.**

**Mechanism:** brief byte-identity is bakeoff.sh's existing `prompt.txt` seal. The
lane-side obligations are enforced at **collection time** by `tools/race-collect.py`, which
scans every `lane-<id>/` dir and refuses to blind anything that violates them:

- **GIT-COMMIT breach** — any lane file is tracked in the enclosing git repository, or the
  lane dir carries a nested `.git` (a lane that made its own repo). "Lanes never commit"
  is the R2 rule the two Race W lanes broke; the collector's refusal is the mechanism that
  now catches it.
- **SELF-ATTRIBUTION breach** — the artifact's content carries a canonical model label, a
  capitalized family proper noun, or a first-person family self-claim ("I am Claude",
  "as a DeepSeek model"). Detection vocabulary is synced with the G4 sanitizer in
  `tools/bakeoff.sh` (case is deliberate: lowercase "minimax" — the Go search algorithm —
  and lowercase "glm" are NOT family mentions in this project's prose).

**Checks (testable predicates):** `tools/race-collect.py <race-root>` exits 0 and emits a
blind set only when every present lane is clean; exits 1 naming the lane and breach class
otherwise, and **refuses to emit the blind set** (a leaked set is worse than none).

**Fail conditions:** any GIT-COMMIT or SELF-ATTRIBUTION breach → no blind set; the race's
outcome is recorded `unaudited` until a clean re-collection. MISSING-ARTIFACT (a lane dir
with no artifact) is **not** a blinding breach: the lane produced nothing (a DNF is data —
the qwen precedent, grand-race.md §2), it is excluded and noted in the compliance report.

**Stated limitation, not a gap:** cross-reading (a lane reading another lane's dir) leaves
no mechanical trace in the artifacts. The mechanism bounds the damage to that lane's score,
and the family rule (R5) + audited gate contain the consequence; a detection instrument for
cross-reads is future work, not a silent assumption.

## 3. R3 — Mechanical blinding

**Rule:** a **collection script, not a model**, gathers outputs under **content-hash
names**. Blinding is a mechanism, not judge discipline.

**Mechanism:** `tools/race-collect.py` copies each artifact byte-identically to
`<blind-dir>/<sha256[:16]>.md` (content-hash name; identical lane outputs collide
deterministically as `-2`, `-3` in lane-sorted order). The lane mapping lives only in the
sealed sidecar manifest `<blind-dir>/manifest.json` (blind name → lane id, plus each
artifact's full SHA-256, plus a self-seal `manifest_sha256` over the canonical manifest).
**stdout carries only hash names** — the judge's set never prints the mapping (the
anonymize.py precedent: "the map is not printed"). A re-collection over an existing
manifest refuses (exit 2): the judge's set is pinned once sealed.

**Checks (testable predicates):**
- *C3.1* every blind file's name is the first 16 hex chars of its own SHA-256 — re-hashing
  the emitted set verifies this mechanically;
- *C3.2* stdout lines are exactly the blind names, no lane id anywhere;
- *C3.3* the manifest is present, self-sealed, and refuses overwrite.

**Fail conditions:** a blind set whose names do not re-hash to their content invalidates
the grading round; a collector run that prints a lane id to stdout is a defect in the
instrument (its controls pin this — ARM 2 asserts stdout carries only hash names).

## 4. R4 — Judging

**Rule:** one fresh blind judge scoring per-criterion **with evidence quotes**; the rubric
is anchored in **checkable facts** (citations resolve, tests pass, claims verified) over
taste. The evidence-quote discipline also blunts style-fingerprinting, which hashing cannot
remove.

**Mechanism:** the judge's report cites, for every score, the artifact's checkable evidence
(a resolved citation, a passing test, a verified claim); the adjudicator verifies a sample
of those quotes before promotion (the "trace one datum end-to-end" audit rule, QA-023
chain). The judge sees only the blind set (R3).

**Checks (testable predicates):**
- *C4.1* the judge had no lane in the race (verifiable against the sealed manifest at
  unseal) — see R5 for what happens when every family competes;
- *C4.2* every scored dimension in the report resolves to a registered rubric dimension
  (R1) and carries an evidence quote;
- *C4.3* a sample of the evidence quotes resolves at HEAD (citations exist, tests pass).

**Fail conditions:** a score without an evidence quote, or a quote that does not resolve at
HEAD, is excluded from totals and the round is flagged. A judge whose report cannot
demonstrate any checkable anchor is a grader-validity failure (the null/seeded controls of
grand-race.md §5 still apply on top).

## 5. R5 — Family rule and audit status

**Rule:** prefer a judge with no lane in the race. When **every family competes**, judge
anyway and write the result with `audit_status: unaudited`; a **different-family confirming
judge** upgrades it to `audited`. **model-perf scores audited results only.**

**Mechanism:** the sealed manifest lets the adjudicator verify judge-family vs lane-family
(the G3 family-exclusion arithmetic of grand-race.md §4 stands — model family, not
dispatch family); the ledger record carries `audit_status` (R6); the model-perf consumer
**refuses** to ingest an `unaudited` record — the gate is at the consumer, mechanical, not
at the producer, disciplinary.

**Checks (testable predicates):**
- *C5.1* every race outcome record carries `audit_status` ∈ {`audited`, `unaudited`};
- *C5.2* `audited` records name the confirming judge (a different-family one) and the audit
  date;
- *C5.3* no `unaudited` record appears in model-perf / `model-task-metrics.jsonl` ingestion.

**Fail conditions:** an unaudited result quoted in model-perf, or promoted as evidence, is
a policy violation; Race W is the worked example (retro-marked, §3 below): its committed
text stands, **its win is not evidence**.

## 6. R6 — Two-field ledger write

**Rule:** every race outcome record carries **verdict + audit status**, extending the
ratified two-field verdict ruling (GLOSSARY, "two-field verdict").

**Mechanism / schema:** the race ledger is
`docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/grand-race-ledger.jsonl`
(append-only, one JSON per event). The §6 grade record of grand-race.md gains two
**required** fields:

```
grade/outcome record: {race, phase, grader, artifact, scores{...}, total, is_self,
                       is_family, null_ctrl_pass, seeded_ctrl_pass,
                       verdict, audit_status}
```

- `verdict` — the adjudicated outcome: winner(s) per section/criterion with totals, as
  structured JSON (e.g. `{"section_A": {"winner": "T755", "total": 25}}`), so the ledger
  consumer can diff it against the scores;
- `audit_status` — `"audited"` | `"unaudited"` (default `unaudited`; upgraded only by a
  different-family confirming judge, recorded with `audited_by` + `audit_date`).

**Checks (testable predicates):**
- *C6.1* every race outcome record carries both fields;
- *C6.2* a record lacking either field is treated as unaudited-and-void by the consumer
  (never silently promoted);
- *C6.3* the fields are written by the harness (or, for a recorded retro-mark, carry a
  `written_by` field naming the writer — §3).

**Fail conditions:** a consumer that would ingest an outcome without `audit_status` is a
defect in the consumer; an outcome without a `verdict` is not an outcome.

## 7. The ledger write, landed — Race W retro-marked unaudited (worked example)

Per seed ruling §4 rule 5, Race W is retro-marked `unaudited`: its committed text stands;
its win is **not evidence**. The standing path is "written by the harness"; the retro-mark
is a recorded exception — a protocol event written by the protocol's own task, so the
record carries `written_by: T779-race-protocol-v2`. One record appended to
`grand-race-ledger.jsonl`:

```json
{"race": "race-w-terminology", "phase": "adjudication", "event": "verdict",
 "date": "2026-08-23", "written_by": "T779-race-protocol-v2",
 "verdict": {
   "section_A_glossary_three_ladders": {"winner": "T755 (claude-opus-5)", "total": "25/25"},
   "section_B_direction_s5_and_header_note": {"winner": "T755 (claude-opus-5); three clauses grafted from T754", "total": "24/25"}},
 "audit_status": "unaudited",
 "audit_reason": "judge graded its own lane winner of both sections; filenames leaked lane identity; two lanes committed against the brief's do-not-commit (T757 disclosure); no different-family confirming judge",
 "evidence": "findings/T757-terminology-refactor.json"}
```

The verdict carries the **adjudicated** outcome from the T757 disclosure — this is a
retro-mark of status, not a re-grade (re-grading Race W is out of scope). The win is
recorded so the ledger is complete; `audit_status: unaudited` is what keeps it out of
model-perf.

## 8. Supersession vs grand-race.md

The protocol base stays `docs/infra/bakeoff.md` (T328) and `grand-race.md`; v2 **supersedes
the corresponding provisions** — it does not fork the doctrine. grand-race.md's other
provisions (purpose, roster, phases, P0 gates G1/G2/G5/G6, cost envelope) stand unchanged.

| grand-race.md provision | superseded by | what changes |
|---|---|---|
| §3 blinding via G4 sanitizer (redact + flag at dispatch) | R2/R3 | attribution is verified **at collection** (refuse-to-blind, not redact-and-flag); blind names are content hashes; the sidecar manifest is the only attribution home |
| §4 gate G4 (blinding sanitizer) | R3 | stands for dispatch-time hygiene; collection-time blinding is v2's |
| §4 gate G3 (family exclusion at counting) | R5 | stands (model family); the audited/unaudited gate adds the consumer-side refusal |
| §5 grading panel ("everyone grades everything, blind") | R4/R5 | one **fresh** blind judge with evidence quotes; when every family competes, judge anyway + `audit_status: unaudited` until a different-family confirm |
| §6 data schema (grade record) | R6 | `verdict` + `audit_status` added as required fields |
| §6 absorption ("model-perf" cells from the ledger) | R5/R6 | model-perf consumes **audited results only** |

## 9. Known gaps (restated from the seed ruling — stated, not papered over)

- **Style fingerprinting** is mitigated, not eliminated: hashing removes identity from the
  file system, the evidence-quote discipline blunts the prose, but a judge who has seen
  enough of a model's writing can still guess. R4's checkable-facts anchor is the defence;
  the residual risk is recorded, not denied.
- **Confirming-judge cost** doubles exactly when all families compete (rare): the
  different-family confirm is a second judge pass. Accepted spend for evidence-grade data.
- **Pre-registration can miss emergent dimensions:** the judge notes them, does not score
  them; they become the next race's criteria (R1).
- **Cross-reads are not mechanically detectable** (R2 limitation) — bounded, recorded,
  future instrument.

---

**Landmark:** advances `L1 (the dashboard tells the truth)` — race results become evidence
only when the protocol makes bias mechanical to prevent, not disciplinary to avoid: the
collector refuses to emit a set that is not blind, the ledger refuses to let an unaudited
result into model-perf, and Race W's win is recorded-but-not-evidence.
