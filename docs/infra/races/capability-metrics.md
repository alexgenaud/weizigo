# Capability metrics — the dimensions we should have graded on (T900)

**Task:** T900 (claude-fable-5), 2026-08-24. **Operator ruling, verbatim:** *"The two metrics
were whimsical examples that I proposed in haste. I think you and Fable should decide what the
capabilities and metrics should be and regrade the models on better metrics."*
**Sources:** the nine sealed C3 lane rows (untracked race area, lanes T881–T889, read raw by
this row), the adjudication `docs/epistemic/c3-evidence-triage.md`, the T893 ledger rows and
T750 schema (`docs/infra/model-task-metrics.jsonl`, `docs/infra/model-task-metrics.schema.md`),
and the operator's penalty ruling (sealed race area, quoted in the adjudication §6).

**Conflict disclosure (race protocol v2.1 rule 11).** This row's author is claude-fable-5. It
had no lane in the C3 race. But (1) three of the nine lanes are Claude-family models (opus,
sonnet, haiku) — this document ranks models of its author's own family, said here in place;
and (2) the substance scores it inherits were graded by claude-fable-5/T893 — the same model.
The regrade is therefore **not independent of the substance grading**; where this document
confirms T893, that is one model agreeing with itself across two sessions, and it should be
weighted accordingly. The mechanical cells do not share this conflict; the judged cells do.

**Confound, stated before any ranking:** `--thinking` is set nowhere in this repository and
recorded nowhere, and three of four providers route through pi. Every lane may have run at a
different effective reasoning budget. Consequence drawn in §5: no dimension is fatally
confounded *as a dimension* (each measures a property of the output actually served), but
**every cross-model attribution is** — the ranking below is a ranking of
models-as-served-on-2026-08-24, not of models.

## 1. Instrument controls first — two live failures inside this row

The brief warned that the seat already published two wrong numbers from uncontrolled textual
matching. This row promptly reproduced the failure mode twice, and both were caught only
because the mechanical reading was checked against a raw-row read (the null/seeded-control
discipline applied to metrics themselves):

1. A strict one-JSON-object-per-line parser reported glm-5.2's lane as **34 of 44 rows
   delivered, one canary row absent entirely**. False: glm packed two JSON objects onto one
   line in five places; a tolerant decoder recovers all 44 rows, 44 unique. The "missing
   canary" was an artifact of the instrument.
2. A keyword regex for canary-flagging then scored glm **1/2 on canary recall**. False: glm
   flagged both canaries explicitly ("CANARY — this item DOES NOT BELONG"), one of them on a
   line the strict parser had dropped. glm is 2/2.

**Design rule this forces:** no mechanical metric cell enters the ledger from a pattern-match
alone. Each mechanical metric needs a known-good and a known-bad control read against the raw
rows before its first reading counts, and the cell's provenance names who read it. The
canary-recall cells written by this row (§4) were verified by reading the actual canary rows
of the three disputed lanes, not by regex.

## 2. The dimension set

The seat's seven-dimension proposal was the set to beat. Verdict: **keep six of seven, with
three reshapings; re-designate the seventh.** The load-bearing change is not any dimension but
the interpretation contract: the set splits into two tiers that must never be conflated.

**Tier 1 — screening metrics (mechanical, cheap, run on every lane, necessary-not-sufficient).**
A lane that fails any of these is defective and the failure is attributable without a judge. A
lane that passes all of them has established nothing about quality — minimax passed every
Tier-1 metric and finished 8th of 9. Tier 1 exists to spend zero judge-tokens on degenerate
output and to attribute failures correctly, not to rank models.

| dimension | cells | reshaping vs the proposal |
|---|---|---|
| **investigative effort** | `paths_named`, `paths_real`, `median_what_i_checked` | kept as T750 shipped it, unchanged. Known weakness kept on the label: `paths_named − paths_real` conflates *mention* with *citation*; only a cited-as-evidence path that does not exist is fabrication (that lives in the fabrication row below). |
| **discernment** | class-distribution counts; **new: confidence-distribution counts** | extended. The class-entropy cell (T750) caught glm (0.17) and haiku (0.17). The same failure exists on the confidence axis and nothing recorded it: **haiku answered `"confidence": "high"` on all 44 rows while scoring 8/40** — a confidence report that does not vary with the row carries no information about the row. Counts are stored; entropy is derived at report time (see the T750 note in §4). |
| **fabrication** | `fabricated_citations` (T750); **new: `fabricated_interfaces`** | split in two. A fabricated *citation* is an evidence path that does not exist (haiku on QA-021). A fabricated *interface* is an invented binary, subcommand, flag, or env var (minimax's `chainability-probe`, `--reuse-cross-root`, and the `run-2x2-memo-test` subcommand this row verified against `src/retro.zig`, which takes env hooks, not subcommands). score.py's existence check catches neither an invented flag on a real binary nor a real path cited for the wrong kind of thing; interface fabrication needs resolution against the actual binary/source, which is mechanical but is not a grep. |
| **canary recall** | `canary_recall_num/den` (T750) | kept. Eight lanes 2/2; haiku 0/2 — verified here by reading the raw canary rows (§1). |

**Tier 2 — capability dimensions (judged, expensive, rationed to raced/graded tasks).**

| dimension | verdict | evidence |
|---|---|---|
| **category fidelity** | keep, judged with a mechanical pre-filter | the dimension the old pair provably lacked: minimax scored 0.89 discernment, 45 real paths — and offered committed *source files* as class-(a) *evidence* and a theorem note as evidence for an *implementation* claim. A prefix check (a `src/` path cited as evidence for a behavior claim) is a cheap mechanical pre-filter, but the flagship error — a real, committed, *adjacent* artifact — is invisible to any path test and needs a judge (the same error class as the Tier-A adjacency audit, adjudication §7.1). |
| **control design** | keep, judged; the most valuable dimension measured | the race's winner-predictor, with an internal gradient the adjudication's one-liner compresses: at `CODE.ADR0011-GATE`, **opus correctly named the epistemic problem** ("a refusal gate is a negative claim and a green run does not evidence it") **but commanded only the positive run; oxalpha designed both arms** (positive: full gate + reload + byte-verify; negative: 1-line fault injection, expect refusal). At `GLOBAL.MEMO-XROOT`, oxalpha *and sonnet* designed the deliberate-defect-reintroduction; opus recognized the removed-defect situation without designing the recreation. Recognition < construction, and the construction end of the gradient is exactly the project's never-trust-a-green-test discipline. Refinement of the adjudication: oxalpha was the only lane to design controls at *both* sites, not the only lane to design any (sonnet designed one). |
| **self-reported limits** | keep, judged; mechanical proxies recorded but flagged gameable | real signal at the top of the field: sonnet 4 `revises` objects + 2 "could not determine" + 4 `low`-confidence rows; opus 2 + 3 and an unasked-for scope-gap flag; kimi's 2 honest batch-order self-corrections. The counters (`revises`, "could not determine", `low` usage) are screening proxies only — the moment they are known to be graded they are trivially farmable, so the ledger stores the counts and the *grade* stays judged (Goodhart warning recorded here so the next reader does not promote the counters to a grade). |
| **substance accuracy** | keep — but re-designated | it is not a peer dimension; it is **the outcome** every other dimension exists to predict or explain. Folding it into a composite with its own predictors double-counts. It stays the grade; the others stay the diagnosis. |

**Relation to T750 — said explicitly, per the brief.** Nothing T750 shipped changes definition:
`paths_named`, `paths_real`, `median_what_i_checked`, `discernment_entropy`,
`canary_recall_num/den`, `fabricated_citations` all survive as shipped, and no re-migration is
needed. What this row changes is (1) **the interpretation contract** — investigative effort and
discernment are hereby screening metrics, not capability grades; a report that ranks models by
them repeats the minimax error; (2) **additive fields** (§4). One tension flagged, not fixed:
`discernment_entropy` is a frozen *derived* number, which the T750 schema's own §0 rule
forbids — the fact is the class-distribution count. This row adds the counts; the float stays
for continuity and becomes a report-time derivation for future rows.

## 3. The regrade

Mechanical cells from the T893 ledger rows and this row's verified raw-row reading; judged
cells (0–2) by claude-fable-5/T900 under the §0 conflict disclosure. Canaries excluded where
the adjudication excluded them. Substance is the T893 grade (n = 40 judged rows).

| lane | model | substance /40 | effort (real/named, med. checked) | discernment: class entropy · conf dist (h/m/l) | fabrication (cit + iface) | canary | category fidelity | control design | self-rep. limits |
|---|---|---|---|---|---|---|---|---|---|
| T886 | ox-alpha | **37** | 36/71 · 261 | 0.96 · 33/10/1 | 0 + 0 | 2/2 | **2** | **2** | 1 |
| T887 | claude-sonnet-5 | **35** | 35/95 · 407 | 0.95 · 27/12/4 | 0 + n/r | 2/2 | **2** | 1 | **2** |
| T881 | claude-opus-5 | **33** | 42/106 · 520 | 0.88 · 26/18/0 | 0 + n/r | 2/2 | **2** | 1 | **2** |
| T882 | deepseek-v4-pro | **32** | 34/76 · 251 | 0.77 · 33/11/0 | 0 + n/r | 2/2 | **2** | 0 | 0 |
| T889 | deepseek-v4-flash | **26** | 33/70 · 446 | 0.63 · 41/3/0 | 0 + n/r | 2/2 | 1 | 0 | 0 |
| T884 | kimi-k2.7 | **21** | 19/44 · 160 | 0.56 · 34/10/0 | 0 + n/r | 2/2 | 1 | 1 | 1 |
| T883 | glm-5.2 | **19** | 42/115 · 397 | **0.17** · 32/12/0 | 0 + 0 | 2/2 | 1 | 0 | 0 |
| T885 | minimax-m3 | **14** | 45/103 · 422 | 0.89 · 33/11/0 | 0 + **3** | 2/2 | **0** | 0 | 1 |
| T888 | claude-haiku-4-5 | **8** | 14/33 · 165 | **0.17** · **44/0/0** | **1** + n/r | **0/2** | **0** | 0 | 0 |

n/r = no grader reading exists (UNKNOWN, not zero). Judged-cell one-liners: category fidelity —
minimax 0 (systematic source-as-evidence + adjacency), haiku 0 (answered "is this row Tier B?",
not the question), glm 1 (`sed`-of-a-document offered as a re-run; its four (a) rows correct),
kimi 1 (right substance buried in demote-adjacent (c) resolutions), dsflash 1 (PROVENANCE-note
template right on text-claims, wrong on behavior claims), top four 2. Control design — oxalpha
2 (both sites, both arms), sonnet 1 (MEMO-XROOT reintroduction), opus 1 (named the negative-
claim problem at GATE, designed neither control), kimi 1 (synthetic-failure refusal test at
GATE, buried in class (c)), all others 0. Self-reported limits — sonnet/opus 2, kimi/oxalpha/
minimax 1, rest 0.

**Resulting ranking, and the honest comparison the brief demands.** Any defensible weighting of
these dimensions yields: **oxalpha 1st; sonnet/opus 2nd–3rd (order weight-dependent — they tie
at 5/6 on the judged tier and 2 substance points apart); dspro 4th; dsflash/kimi 5th–6th (order
weight-dependent — dsflash wins substance 26–21, kimi wins the judged tier 3–1); glm 7th;
minimax 8th; haiku 9th.** That is the published substance ranking with at most two adjacent
swaps. So, per the brief's dichotomy — differs a lot means suspect, differs not at all means
adds nothing — the answer is **"differs not at all, and that is not 'adds nothing'":**

- **As a ranking, the new set adds nothing.** Substance already ordered the field; keep
  substance as the grade.
- **As screening, it would have saved real cost.** Discernment + canary + fabrication would
  have flagged haiku and glm mechanically before a judge read a single row, and it *did not
  need* the judge's 40-row adjudication to do it.
- **As diagnosis, it adds the thing substance can't say:** *why* each lane lost. minimax lost
  on category fidelity, glm on discernment, haiku on effort-and-everything, kimi on effort —
  four different failures that one number rendered identical.
- **The minimax test passes:** the proposal's known hole 1 asked whether the new set would
  rank minimax highly the way effort+discernment did. It does not — category fidelity 0 and
  fabricated interfaces 3 put it 8th on the judged tier as well as on substance. A metric set
  refutable by this race survived this race.

## 4. Schema recommendation — what becomes columns, what stays rationed

**Mechanical → columns (cheap; every raced/audited row).** All additive to T750; no shipped
field changes meaning:

- `class_counts` (object of ints, e.g. `{"a": 12, "b": 20, "c": 12}`) — the *fact* under
  `discernment_entropy`; entropy becomes a report-time derivation.
- `confidence_counts` (object of ints, `{"high": 44}` style) — the second discernment axis;
  degenerate confidence is now visible mechanically.
- `fabricated_interfaces` (int?; null = UNKNOWN) — invented binaries/subcommands/flags/env
  vars, grader-verified against source. Complements `fabricated_citations`.
- `revises_count`, `could_not_determine_count` (int?) — self-reported-limit *proxies*, stored
  as counts, never graded mechanically (Goodhart note in §2).
- `canary_recall_num/den` — already in the T750 schema; backfilled onto the nine C3 rows now.
- **identity gap, recommended for every future race row:** an effective-reasoning-budget field
  (`thinking_budget` or a serving-config string; null = UNKNOWN). Until it is recorded, every
  race inherits this race's confound.

**Judged → rationed cells (a grader per race, never per routine task).** `category_fidelity`,
`control_design`, `self_reported_limits`, each 0–2 with grader provenance. These are exactly
the expensive dimensions; the recommendation is to score them only where a race or a graded
audit already pays for a judge, and never to backfill them by keyword.

**Written now:** the nine `race=T893-race-c3-adjudication` rows in
`docs/infra/model-task-metrics.jsonl` carry the mechanical backfill (canary pair, class and
confidence counts) plus a nested `regrade` object (`task_id: T900`, grader, the three judged
cells, `fabricated_interfaces` where a reading exists) — nested so T893's cells and T900's
cells stay attributable to their own graders. `fabricated_citations: 1` is set on the haiku
row (grader evidence: the adjudication §6). The conformance control
`tools/regression-model-task-metrics.sh` passes after the edit.

## 5. What this race cannot say (n = 1 task, unrecorded budgets)

1. **It is a configuration ranking, not a model ranking.** Unrecorded reasoning budgets across
   three pi-routed providers mean any pairwise gap may be a budget gap. No dimension is
   dropped for it — each measures the served output, and a lane that fabricates *at the budget
   it was served* is unsafe to dispatch *at that budget* — but every "model X > model Y"
   sentence here means "as served on 2026-08-24".
2. **No within-model variance.** T626 measured real repeat-variance for one model on one task;
   here every cell is n = 1. A 2-point substance gap (sonnet/opus) is noise until raced again.
3. **No task-type transfer.** Everything above is one audit-shaped task. Hypotheses worth
   racing, stated as hypotheses: category fidelity should predict audit/verification and
   absorption work; control design should predict battery-heavy, implementation, and
   instrument-building work (it is the mechanized never-trust-a-green-test discipline);
   self-reported limits should predict handover/orchestration quality. **Not enough evidence**
   to assert any of the three — that is the correct answer, not a hedge (per the operator's
   separation of task type, task scope, and capability, these get columns only when a race
   measures them on those task types).
4. **No calibration-proper.** Confidence-vs-correctness per row would need per-row grades in
   machine-readable form; the adjudication's per-row verdicts are prose. Deferred, named.
5. **No cost cells.** All nine lanes ran unmeasured (`cost_grade: "unmeasured"`); nothing here
   feeds the cost ladder.
