# S07 — spec: the delegation-evidence lattice (one navigable 3D surface)

**Artifact type: SPEC** (`docs/infra/sprint.md` — a spec says what we want, testably, for one
pass). **Owner:** deepseek-v4-pro/T776 · **Date:** 2026-08-23 · **Status:** PROPOSED (rev 1,
for operator ratification) — audited before anything is built. Not a worker brief, not a plan,
no code.

**Sits on (all committed paths):** the ratified intent
`docs/status/landmark-waypoints-seed-2026-08-23.md` §1 (this spec's §Inputs cite it) · the
dispatch policy + measured cells `docs/infra/model-task-matrix.md` · the measured record
`docs/infra/model-task-metrics.jsonl` · the priors `docs/infra/model-ladders.md` · the
qualification gate + emission gate + record shape
`docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/measurement-methodology.md` §3, §5 ·
the D027 eight-type/eight-dimension taxonomy `docs/infra/managent/directives.jsonl` (D027b,
line 78) as emitted by `tools/model-profiles.py` (T524) · the metric rulings + trust grades
`docs/status/T746-measurement-handover.md` · the one canonical-label + short-name table
`docs/infra/model-registry.md` · the pass protocol `docs/infra/sprint.md`.

**Inputs.** seed §1 (the 3D graph, its dimensions, the moving-average sampling policy, the
feedstock list) · `model-task-matrix.md` §1 (the task-type demand shapes) · `directives.jsonl`
D027b (the eight task types, verbatim) · `measurement-methodology.md` §5 (the qualification
gate — the "selection stays qualification-first" anchor the seed re-ratifies) ·
`T746-measurement-handover.md` §3.2 (the `trusted: false` retro readings) and §5 (the metric
rulings: canary_recall / false_flag_rate / unique_catch as the audit headline) · seed §4 rule 5
(race results scored **audited only**).

**Citation pins.** References to other documents are by **§ref** against `HEAD` at authoring
time, commit `cbb0b70` (2026-08-23). A citation that no longer resolves at `cbb0b70` is a spec
defect, not a reader's problem.

**Naming (PROPOSED — operator owns the number).** This sprint is proposed as **S07** under
`L1-dashboard` (the directory is new at `cbb0b70`; S01–S06 are taken). The brief flags it as
proposed; the operator assigns the final number. Nothing in this document depends on the number.

---

## 0. How to read this document

Every normative statement carries an id (`LAT-*`). §6 is the control table: the named controls
are the **mandatory core**; the test phase writes one seeded arm and one null arm for **every**
formula-bearing id before the first live reading. An id with no control is not a requirement, it
is a wish (the standing rule: *an instrument earns its first reading only after a null control
and a seeded-defect control*). §6 lists, by id, the controls this spec already assigns and the
ids whose arms are owed in the test phase — the owed list is enumerated, not "the rest", so
coverage debt cannot go silent (the S06 spec audit, `findings/T778-s06-spec-audit.json` finding
1, is the local scar this rule exists to prevent).

Where a ruling underdetermines a design choice, this spec states the **options** and a
**recommendation**, and marks it `[design-open]` — design may choose *only among the listed
options* without re-ratification; choosing anything else is a plan amendment. Decided rulings are
never reopened here.

The lattice is a **reporting-and-suggestion surface** (§1). It is not a picker: it never selects
a model for a row. The seed re-ratifies this boundary — *selection stays qualification-first
(methodology §5), cost excluded from choice until the T774 instrument-noise control readmits
it* — and this spec turns that boundary into a control (C5), not a paragraph.

---

## 1. Goal and scope

**LAT-GOAL-1 (the goal).** Delegation evidence becomes **one navigable surface** instead of
scattered ledgers. A reader asks, for any (model, task type, task scope): *what do we actually
know here, how sure are we, how much data is there, and does the data actually separate models?*
— and gets a cell whose answer is computed from committed ledgers by formula, never by
impression. End state: the operator sees one surface that reports most-common task types and
scopes, a suggested model per cell (marked as reporting-only), and the list of cells where
evidence is sparse.

**LAT-GOAL-2 (what it is NOT — the boundary, normative).** The lattice is **not a picker**.
Selection stays qualification-first per `measurement-methodology.md` §5, and cost is **excluded
from model choice entirely** until the T774 repeatability control readmits it (seed §1). The
lattice may *report* a cost figure as annotation; it may never *decide* on it. It never writes a
`managent` assignment, never changes a row's model, never emits a dispatch — it is read-only
over committed ledgers. The suggestion output (§4.3) is explicitly a *suggestion to a human or a
picker*, and the picker remains `soloPick`'s successor under T772's ratified direction — a
different subsystem this spec does not touch (the S06 audit noted the same boundary distinction,
`findings/T778-s06-spec-audit.json` finding 5).

**LAT-GOAL-3 (what this sprint delivers).** This row delivers the **spec only**. The phases
after spec (audit → design → test → build → accept) are the sprint manager's to plan per
`sprint.md`; §7 names the phase sequence and defers the plan (parallelism, effort, row
assignment) to `plan.md`.

---

## 2. The three dimensions and where each enumeration comes from

The graph has three axes. Each axis's value set is **finite and enumerated**, and each value's
provenance is named — no axis is open-ended, because an open-ended axis is an unbuildable surface.

### 2.1 Axis 1 — model (capability is per-cell, never a global scalar)

**LAT-DIM-1 (the model axis is the canonical roster).** The model axis is the canonical label
list, single source `docs/infra/model-registry.md` ("as of 2026-08-23": `claude-opus-5`,
`claude-sonnet-5`, `claude-fable-5`, `claude-haiku-4-5-20251001`, `deepseek-v4-pro`,
`deepseek-v4-flash`, `glm-5.2`, `minimax-m3`, `kimi-k2.7`, `qwen3.8:27b-mlx`, `oxalpha`).
Records write the canonical label; short names are presentation only (the T276 rule). The
lattice reads the roster from `managent models` (the T317 single source), never from a
hardcoded copy.

**LAT-DIM-2 (capability is per-cell, not one axis).** The first dimension is named "model
capability", and the seed's own §1 calls each cell's content "a ladder-or-similar". This spec
resolves the phrase to: **there is no global capability scalar.** `measurement-methodology.md`
§10 is the governing text — *"Capability is not one axis: verification depth and code throughput
are separable… Measure them separately."* So a model's standing lives **in each cell** as the
observed fields (§3.1), and a ladder exists only *within a (task type × scope) slice* (§3.7). A
"capability" number averaged across types or scopes is forbidden here for the same reason a
cross-goban claim is forbidden: it is aggregation the record does not support.

### 2.2 Axis 2 — task type (D027's eight, verbatim)

**LAT-DIM-3 (the task-type axis is D027's eight types, and only those).** The enumeration is
D027b (`docs/infra/managent/directives.jsonl`, directive D027b, recorded by T503 and emitted by
`tools/model-profiles.py` per `findings/T524-dimensions.json`), verbatim:

1. `spec/design`
2. `implementation-bounded`
3. `audit/verification`
4. `integration/reframe`
5. `infra/tooling`
6. `research/census`
7. `battery-heavy`
8. `orchestration-seat`

**LAT-DIM-4 (the two-taxonomy drift is a pre-read cleaning step, not a silent merge).** Two
committed taxonomies coexist and do not agree key-for-key: `model-task-matrix.md` §1 uses
`T-A…T-H` labels, and `model-task-metrics.jsonl` uses short keys (`audit`, `infra`,
`implement`, `research`). The lattice must **normalize onto D027's eight full names by reading
each row** (the `measurement-methodology.md` §8 rule: re-key by reading, never by label alone),
and a key that will not map is **refused and named** (a finding, not a nuisance — the D027c
keying precedent). Control C7 pins this. Adjudication/verdict-writing (`model-ladders.md` §1,
"matrix T-F; not a D027 type") is **out of the task-type axis** — it is a capability line, not
one of the eight, and the lattice does not admit a ninth type.

### 2.3 Axis 3 — task scope (five values, proposed and defended)

**LAT-DIM-5 (the scope enumeration — proposed).** Scope is the task's **operational footprint +
horizon**, an ordinal ladder of five values, proposed here and defended below:

| scope | name | write footprint | horizon | derivation (mechanical) |
|---|---|---|---|---|
| S1 | atom | one non-`src/` file (config / rename / one-liner) | minutes, no test | ≤1 deliverable, none a `src/` file, no `gate:` declared |
| S2 | leaf | one `src/` file + a regression/test arm | one session, sealed acceptance | 1 `src/` deliverable and a declared test/gate |
| S3 | feature | multiple `src/` files, or `holds=` across files | one pass, multi-commit | ≥2 `src/` deliverables or `holds=` names >1 engine file |
| S4 | sweep | read-only; findings/docs output only | bounded, no source writes | deliverables are findings/docs only, no `src/` writes |
| S5 | console | manages other rows | hours, dispatches its own leaves | bundle declares console/dispatch (the `orchestration-seat` shape) |

**LAT-DIM-6 (the defence).** Three reasons this enumeration and no other:

1. **It is the operator's own prior, not invented.** `model-ladders.md` §3 is titled "Ladder by
   task size/scope… before type is even considered" and its first five rows are, in order, the
   five rows above. This spec adopts that ladder as the enumeration and adds only the mechanical
   derivation rule, which the ladder (a beliefs doc) never had.
2. **It is ordinal in one dimension.** S1 < S2 < S3 by write footprint, S4 < S5 by horizon. An
   ordered axis is what makes the sampling policy (§4.4) a *rank* ("test where sparse") rather
   than a bag.
3. **It is derivable from fields already normative.** `deliverables=`, `holds=`, and the
   `gate:` declaration are already load-bearing (the S06 registration contract, `S06-orchestration-
   refactor/spec.md` ORC-REG-3, imported from T747). Scope adds no new record field; it is a
   function of fields the kanban already holds.

**LAT-DIM-7 (orthogonality — scope is size, not kind).** `model-ladders.md` §3's sixth row
("gate verification / holistic review / adjudication") names a *kind* of work, not a *size*, and
is therefore **not** a scope value here — it stays in `model-ladders.md` as a capability line.
Keeping the two axes orthogonal is what prevents the double-counting that a 3D graph invites:
an adjudication can be a leaf (S2) or a sweep (S4), and a sweep can be audit, research, or
integration. A scope value that is also a task type would make the lattice count the same fact
twice.

---

## 3. The cell contract

### 3.1 What a cell holds (store facts, derive numbers at report time)

**LAT-CELL-1 (the cell is one (model × type × scope) record, and it stores observations, not
derived numbers).** Per `measurement-methodology.md` §3 — *"store what was observed; never
freeze a derived or normalized number into the record."* A cell carries, per reading: the §3
observed fields (`score_raw` + `rubric_max`, `verified`/`unverified`/`fabricated_citations`/
`unique_catch`, `grader`, `blind`, `evidence` path, `as_of`), plus — per the T746 §5 metric
rulings — `canary_recall` and `false_flag_rate` as **numerator/denominator counts, never a
frozen percentage**. Certainty, richness, relevance, and distinctiveness are all **derived at
report time**, never stored.

**LAT-CELL-2 (the capability fields that count).** The headline pair for audit cells is
(`canary_recall`, `false_flag_rate`), and `unique_catch` is recorded — `measurement-methodology.md`
§5 names verified dissent the most valuable output there is and T746 §5 makes it a recorded
field. A rubric total alone does not headline any cell (T746 §5: volume can carry a total at
zero canaries).

### 3.2 Certainty — formula, never a vibe

**LAT-CELL-3 (the certainty formula).** Certainty is a function of `n_cell` — the count of
**eligible** readings (audited + trusted, §3.6) — and the emission gate:

```
certainty(cell):
  n = n_cell(cell)
  n == 0            → UNMEASURED
  n == 1            → UNMEASURED   # a single run licenses nothing (T746 §6 n-bar)
  n == 2            → PROVISIONAL   # a band, not an order
  n ≥ 3  AND  anchored(cell)  AND  |qualified_models(cell)| ≥ 2   → TIER
  n ≥ 3  (but unanchored, or <2 qualified)                        → PROVISIONAL
```

- **anchored(cell)** = at least one of the cell's readings comes from an anchored race
  (`measurement-methodology.md` §4.1: every race carries the anchor pair, `deepseek-v4-flash`
  primary / `claude-sonnet-5` secondary; a race with no anchor yields a within-race order and
  **no matrix cell**).
- **qualified_models(cell)** = models in the cell meeting the §5 gate (§3.7).

**LAT-CELL-4 (the n-bar supersession, stated not hidden).** `measurement-methodology.md` §5's
emission gate says "provisional (n=1)"; the later `T746-measurement-handover.md` §6 n-bar says
"a single run licenses nothing regardless of margin; n=2 licenses `provisional`; n=3 before any
tier claim." The later ruling supersedes the earlier wording: **n=1 renders `UNMEASURED`, not
`provisional`.** Recorded here so no reader has to re-derive the conflict.

### 3.3 Richness / sparseness — formula

**LAT-CELL-5 (richness and sparseness are one number).**

```
richness(cell)  = n_cell(cell)          # eligible readings, same definition as §3.2
sparseness(cell)= 1 / (richness + 1)    # 1.0 when empty, → 0 as n grows
```

A cell with `richness == 0` is **sparse** (the sampling policy's target, §4.4). A cell whose
certainty is `TIER` is **rich** — the emission gate is exactly the "we know enough to rank" bar,
so sampling there slows to the within-model-variance job (the qwen overnight re-runs,
`model-task-matrix.md` §3), never to exploration. Retro readings (`n_retro`, §3.6) do **not**
increment richness; they are reported beside it, never inside it.

### 3.4 Relevance — formula

**LAT-CELL-6 (relevance is volume share, with a stated denominator).**

```
relevance(type, scope) = p(type) × p(scope)
```

- `p(type)` = the task type's share of graded dispatch volume. The recorded seed shares are
  `measurement-methodology.md` §1 (audit 27% · infra 22% · battery 18% · implement 11% ·
  orchestration 8% · integration 6% · research 4% · spec 3%). These are **seed values**, not
  frozen constants: the lattice re-censuses from the kanban/ledger at read time and states the
  denominator every render (LAT-CTRL-4).
- `p(scope)` = the scope's share, from a **scope census** that does not yet exist (LAT-OUT-2,
  LAT-FLAG-2). Until it lands, `relevance` renders as `p(type) × (unknown)` — the type share
  with the scope factor shown as pending, never as an invented number.

This formula is what makes the "most-common task types and scopes" output (§4.1–4.2) a ranking
rather than a recollection.

### 3.5 Distinctiveness — formula

**LAT-CELL-7 (distinctiveness is the observed spread, within one panel only).**

```
distinctiveness(cell) = range(score_raw over qualified models in one race/panel)
                        # same rubric, same grader — never across panels
non_distinctive(cell)  = (range == 0)   # all measured models tied
```

`distinctiveness` is computed **only within a single race/panel** (same rubric, same grader),
because a score is relative to the field it competed in (`measurement-methodology.md` §4). The
T447 vs T447-rep non-comparability (`model-task-matrix.md` §2, "a different grader means not
directly comparable") is the standing proof that a cross-panel spread is a confound, not a
reading. A `non_distinctive` cell must **not** be quoted as a ranking — all measured models tied,
and per §5 position relative to consensus contributes zero. Control C4 pins this.

### 3.6 Trust grades, carried end to end

**LAT-CELL-8 (one trust grade per reading, two fields, one reduction rule).** Every reading
carries two grades, and the reduction rule is uniform:

| field | values | source |
|---|---|---|
| `audit` | `audited` / `unaudited` | seed §4 rule 5 — race results only |
| `trusted` | `true` (dispatch-time) / `false` (retro) | `T746-measurement-handover.md` §3.2 (`source: pi-session-jsonl-retro`) |

**Reduction rule (never flattened):** a reading contributes to `n_cell` (and therefore to
certainty, richness, and any ladder) **only if** `trusted == true` **and**, where the reading is
a race result, `audit == audited`. Anything else is reported beside the cell with its grade and
a stated count — `n_retro` (trusted:false readings, never folded into `n_cell`) and
`n_excluded_unaudited` (race results whose win is not evidence, seed §4: "Race W is
retro-marked unaudited: its committed text stands; its win is not evidence"). A `trusted:false`
reading can never reach a suggestion or a tier without saying so — this is T772's trust-grade
requirement applied to the reporting surface.

### 3.7 Ladder-or-similar, rendered

**LAT-CELL-9 (a slice renders a ladder only where the emission gate is met).** Within a
(type × scope) slice, models are ordered by `score_raw` **within one panel** (ordinal, with the
grader caveat carried). But a ladder is emitted **only** when the slice meets the §5 emission
gate (anchored, `n ≥ 2`, ≥2 qualified models). Otherwise the slice renders each model's readings
with their certainty grades and `unmeasured` elsewhere — "ladder-or-similar" from the seed is
resolved to: *ladder where warranted, raw readings with certainty everywhere else, unmeasured
where empty.*

**LAT-CELL-10 (the qualification gate is computed, with the pending constant named).** A model's
`qualified` status uses `measurement-methodology.md` §5:

```
qualified(m) = score ≥ θ(task_type)  AND  fabricated_citations == 0  AND  verification_rate ≥ φ(task_type)
```

`θ` (score threshold) and `φ` (verification floor) are **not yet recorded anywhere** —
`measurement-methodology.md` is headed "DESIGN, not ratified," and T772's fix (the landing
vehicle) is stalled at `cbb0b70`. Until `θ`/`φ` are ratified, the lattice computes the two
**mechanical** sub-gates (`fabricated_citations == 0`, `verification_rate ≥ φ` only where `φ` is
recorded, else held) and renders `qualified | underqualified | unmeasured` with the pending
constant shown — it never invents `θ` or `φ`, and it never lets the missing threshold silently
read as "qualified". This is a reported gap (LAT-FLAG-5), not a licence to guess.

---

## 4. Outputs

**LAT-OUT-1 (most-common task types).** The eight types ranked by `p(type)` descending, with the
census denominator stated. The seed shares (audit 27% … spec 3%) are the first row until the
re-census runs; a share quoted without its denominator is not a measurement (the standing
denominator rule).

**LAT-OUT-2 (most-common scopes).** The five scopes ranked by `p(scope)` descending, from the
scope census (LAT-FLAG-2 — the census is a design-phase deliverable, so this output renders
"pending" until it lands, and says so).

**LAT-OUT-3 (suggested model per cell — reporting-only).** For each (type × scope) slice: the
highest-ranked **qualified** model in the slice's ladder, **or `explore`** when the slice has no
qualified measured model. The `explore` marker is the D027 exploration-first / least-data rule
made visible (`model-task-matrix.md` §1: "an empty cell is a reason to dispatch"; T772's
ratified direction: "unmeasured is a reason to *try* it"). The suggestion carries its certainty
grade and is **never** a pick: it writes nothing, and the picker (selection) is out of scope
(LAT-GOAL-2). Cost never influences the suggestion — control C5 asserts that a seeded cost
difference does not change the rendered suggestion.

**LAT-OUT-4 (the sparse-cell list — the moving-average sampling policy).** All cells ordered by
`sparseness` descending (equivalently `richness` ascending), ties broken by `relevance`
descending (fill the common cells first). This is the seed's rule — *test more where evidence is
sparse, slow down where it is rich* — expressed as a rank: the list's head is where the next
exploration dispatch should point, and cells at `TIER` certainty drop off the exploration list
entirely (they are "rich"; further sampling there is the variance job, not exploration).

---

## 5. Data sources and trust grades, carried end to end

**LAT-SRC-1 (measured record — `docs/infra/model-task-metrics.jsonl`).** The measured cells.
Read, never written, by the lattice. Each row already carries the §3 observed fields and its
`evidence` path; the lattice adds only the derived fields at render time.

**LAT-SRC-2 (dispatch policy + holes — `docs/infra/model-task-matrix.md`).** The task-type
demand shapes (§1), the measured-cells matrix (§2), and the hole list (§4) — the last feeds the
sparse-cell list directly ("the holes, in the order worth filling" is exactly a sparse list, and
the lattice makes it a computed output instead of a hand-maintained table).

**LAT-SRC-3 (priors — `docs/infra/model-ladders.md`), routed as priors only.** Every placement
there is Class C belief and must never enter a cell as a reading. The lattice may render a
prior as a *suggestion-when-unmeasured* only if it is labelled `[prior, not evidence]` — and
even then it renders `explore`, not a ladder position (a prior is a reason to *test*, never a
ranking to report).

**LAT-SRC-4 (D027 map — `directives.jsonl` D027b).** The eight task types (§2.2) and the eight
dimensions. The dimensions are the *metric vocabulary* a cell can carry; the task types are the
axis. Nothing else in the lattice derives from D027.

**LAT-SRC-5 (the T746-recovered token ledger).** Carried with `trusted: false` /
`source: pi-session-jsonl-retro` per `T746-measurement-handover.md` §3.2. These readings feed
`n_retro` only — reported beside richness, never inside certainty, per the reduction rule
(§3.6). The operator's ruling that cpu/rss/token figures are collected but not trusted is the
reason they are a *report*, not a *decision input* (T746 §1 ruling 3).

**LAT-SRC-6 (race results, audited only).** Only `audit: audited` race results enter scoring
(seed §4 rule 5: "model-perf scores audited results only"). An `unaudited` result is rendered
with its exclusion count stated and its win treated as not-evidence.

**LAT-SRC-7 (excluded, named).** `docs/infra/archive/model-perf-2026-08-21.md` is stamped
*"impressions, not measurements; not evidence of ranking"* and is **excluded** from cells. It is
cited nowhere as a reading. `docs/infra/model-perf.md` is a thin pointer (`model-task-matrix.md`
§0); the lattice reads the files it points to, not the pointer.

---

## 6. Controls — never trust a green lattice

**LAT-CTRL-1 (the battery — the mandatory core).** Each control is scripted against a scratch
store (`MANAGENT_STORE`), regression-suite style. The seeded defects are synthetic fixtures,
never live docs (LAT-CTRL-3).

| # | control | seeded defect | expected | flips |
|---|---|---|---|---|
| C0 | null | empty metrics + empty census | every cell `UNMEASURED`; no tier, no suggestion, no sparse rank with false certainty; denominator `0` stated | LAT-CELL-3/5/6, LAT-OUT-1/3/4, LAT-CTRL-4 |
| C1 | trusted:false-only | a cell whose sole reading is `trusted: false` | renders `UNMEASURED`, shows `n_retro=1`, emits no suggestion/tier | LAT-CELL-8, LAT-SRC-5, LAT-CELL-3 |
| C2 | unaudited race | an `audit: unaudited` race result, top score | excluded from scoring, exclusion count stated, win not evidence | LAT-SRC-6, LAT-CELL-8 |
| C3 | fabricated citation | `fabricated_citations > 0`, highest score in cell | `underqualified` under the §5 gate; not the suggestion | LAT-CELL-10, LAT-OUT-3 |
| C4 | all-tie cell | two qualified models, identical scores | `non_distinctive`, no ranking emitted | LAT-CELL-7, LAT-CELL-9 |
| C5 | cost difference | two qualified models, one cheaper | suggestion unchanged (cost is annotation only) | LAT-GOAL-2, LAT-OUT-3 |
| C6 | cross-panel merge | two readings, different rubric/grader | not merged into one ladder; distinctiveness withheld, ordinal caveat stated | LAT-CELL-7 |
| C7 | taxonomy key | a `T-A` label / short JSONL key not normalized | refused and named (no silent drop) | LAT-DIM-3/4 |
| C8 | scope derivation | a bundle with no derivable scope | refused and named, not silently bucketed | LAT-DIM-5 |
| C9 | missing denominator | a render without its denominator | refused (the pane may not invent a figure) | LAT-CTRL-4, LAT-OUT-1/2 |

**LAT-CTRL-2 (red first).** The first live reading counts only after C0 (null) **and** the
seeded-defect controls pass — red first, then green (`sprint.md` TDD; the 2B-5 positive-control
failure is the local scar). Controls are written **before** implementation (test phase precedes
build).

**LAT-CTRL-3 (synthetic fixtures).** Every seeded defect is a fixture under the scratch store;
live faults get fixed, and a check against live data then silently tests nothing (calibration
rule).

**LAT-CTRL-4 (every render states its denominator).** No output may render a share, count, or
rate without the number it is a fraction of — including the within-budget / within-sample
denominator (the standing QA-023 rule: a rate quoted without the missing-sample denominator is
not a measurement).

**LAT-CTRL-5 (owed arms, enumerated — not "the rest").** The following normative ids are
structural (axis population, source wiring, phase/acceptance framing), not formula-bearing; the
test phase writes their arms. They are listed by id so the debt cannot go silent:

- **LAT-GOAL-1** — arm: a populated scratch store renders a navigable surface with all §4
  outputs present and no unlabelled number.
- **LAT-GOAL-2** — arm: the lattice executes no mutation (a write to `tasks.json` or a `managent`
  assignment attempt is refused); C5 covers the cost half.
- **LAT-DIM-1** — arm: the model axis equals `managent models` output exactly (no hardcoded
  roster drift).
- **LAT-DIM-2** — arm: a cross-type average is refused (no global capability scalar).
- **LAT-DIM-6/7** — arm: a scope value that is also a task type is refused (orthogonality).
- **LAT-CELL-1/2** — arm: the cell carries the §3 observed fields and headline pairs as counts,
  never a frozen percentage.
- **LAT-CELL-9** — arm: an emission-gate-failing slice renders raw readings, not a ladder.
- **LAT-SRC-1/2/3/4/7** — arm: source wiring (measured record read, holes feed the sparse list,
  priors render `[prior]` + `explore`, archive excluded).
- **LAT-OUT-2** — arm: scope census absent → output renders "pending", not a guess.
- **LAT-PLAN-1, LAT-ACC-1, LAT-ACC-2, LAT-FLAG-1…5** — framing; no behaviour to seed.

---

## 7. Phase sequence (the sprint manager's plan, named here)

**LAT-PLAN-1 (five phases, per `sprint.md`).** The pass protocol, with audit loops, in order:
**spec** (this document) → **design** (cell schema, scope-census spec, render layout,
trust-grade plumbing) → **test** (§6 controls written red, before build) → **build** (the
read-only reducer + renderer) → **accept** (§8). The plan (`plan.md`) — phases' gates,
parallelism, effort, row assignment, one-writer serialization — is the **sprint manager's** to
write; this row delivers the spec only and does not pre-allocate it.

---

## 8. Acceptance

**LAT-ACC-1 (the first live reading is gated).** A live render is not a reading until C0 (null)
and the seeded-defect controls are green against the scratch store, and every rendered output
states its denominator.

**LAT-ACC-2 (the not-a-picker proof).** Acceptance includes a fixture showing the lattice
mutates nothing and its suggestion changes under no cost-only perturbation (C5) — the boundary
LAT-GOAL-2 states is demonstrated, not asserted.

**LAT-ACC-3 (no invented number).** Every cell either computes its value from committed ledgers
by the §3 formulas or renders `unmeasured` / `pending` — never a guess. The QA-023 lesson
(impossibly clean counters, silent wrong answers) is the bar: a green lattice that renders
nothing is a defect, and a lattice that renders a number it did not derive is a bigger one.

---

## 9. Flags and open questions

**LAT-FLAG-1 (sprint number — operator owns it).** `S07` is proposed (header naming note). The
operator assigns the final number.

**LAT-FLAG-2 (the scope census does not exist).** `p(scope)` and the most-common-scopes output
(§4.2) are blocked on a census no tool has run. Design phase delivers the census spec; until it
lands, scope-factor relevance renders `(unknown)` and the output says "pending".

**LAT-FLAG-3 (two-taxonomy + JSONL key normalization is a pre-read step).** `T-A…T-H` and the
short JSONL keys must be re-keyed onto D027's eight by reading each row (LAT-DIM-4). The count
of remapped keys and any unmappable key are findings, stated in the render.

**LAT-FLAG-4 (oxalpha appetite reconciled).** The registry's current stance is the operator's
2026-08-23 "use oxalpha liberally" ruling (recorded in `docs/status/landmark-waypoints-seed-
2026-08-23.md` §5 and the model-registry stealth entry). Any stale `RESERVED` record is a record
defect; the lattice reads the canonical registry, never a hardcoded appetite, so it inherits the
correction rather than re-enacting the old value.

**LAT-FLAG-5 (the §5 qualification constants are unrecorded).** `θ(type)` and `φ(type)` are
named in `measurement-methodology.md` §5 but never given values; the gate is DESIGN, not
ratified. The lattice computes the mechanical sub-gates and renders the pending constant until
`θ`/`φ` are ratified (LAT-CELL-10). The n-bar supersession (LAT-CELL-4) is a second, smaller
instance of the same class: two committed texts disagree on `n=1`, and this spec records the
later ruling.

**Resolved at spec:**

1. **Is "model capability" a global scalar or per-cell?** Per-cell — `measurement-methodology.md`
   §10 governs; no cross-type average (LAT-DIM-2).
2. **Is the scope axis the model-ladders §3 ladder?** Its first five rows, with a mechanical
   derivation added; the sixth row is a kind, not a size, and stays out (LAT-DIM-5/7).
3. **Does a `trusted: false` reading count?** No — reported as `n_retro`, never in `n_cell`
   (LAT-CELL-8).
4. **Is the lattice a picker?** No — reporting/suggestion only; selection stays qualification-first
   and cost-excluded (LAT-GOAL-2, seed §1).
5. **What does `n=1` render?** `UNMEASURED`, per the later T746 §6 n-bar (LAT-CELL-4).

**Options with a recommendation (`[design-open]` — design may choose among these only):**

1. **Suggestion label when unmeasured.** (a) `explore` bare, or (b) `explore` + the
   `model-ladders.md` prior tagged `[prior, not evidence]`. **Recommend (b)** — the prior is
   useful routing, and the tag keeps it honest.
2. **Scope derivation failure mode.** (a) refuse the render for the unclassifiable bundle, or
   (b) bucket as `S-unknown` and report the count. **Recommend (a)** for cells, (b) for the
   census — a census must never silently drop a bundle (C8), but a single unclassifiable bundle
   must not halt the whole surface.

**Deferred to design (the spec states the principle, design states the mechanism):**

- the exact scope-census query and its denominator (LAT-FLAG-2);
- the render layout (which of §4's outputs appear in which pane) — the four outputs and the
  not-a-picker boundary are normative, the pixel layout is not;
- the `θ`/`φ` ratification path (LAT-FLAG-5) — the constants are the methodology's to ratify;
  the lattice merely refuses to invent them.

---

## 10. Milestone

**Landmark:** advances **L1 (the dashboard tells the truth)** — delegation evidence becomes one
navigable surface instead of scattered ledgers. On ratification, the next step is the design
phase; on build completion a reader can ask *what do we actually know about model X on task type
Y at scope Z* and get a computed answer — certainty, richness, relevance, distinctiveness, a
suggestion when warranted, and the list of cells where evidence is sparse — with every number
derived from committed ledgers and every denominator stated. What remains for L1 after that:
the scope census (LAT-FLAG-2), the qualification constants (LAT-FLAG-5), and the five-phase
build whose acceptance is the first gated live reading (§8).
