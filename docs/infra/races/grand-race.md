# The grand race — every model, every phase, one real deliverable

**Author:** claude-fable-5 · **Date:** 2026-08-20 · **Status:** PROPOSED — operator ratifies
roster, spend, and gates before P1 dispatches
**Protocol base:** `docs/infra/bakeoff.md` (T328) — this document *extends* it; where the two
disagree, this one wins for this race only.
**Evidence for every hardening rule below:** the T452 breaches recorded in
`docs/audits/2026-08-20-fleet-and-model-audit.md` §3.

## 1. Purpose — two deliverables from one spend

1. **The artifact:** the wave-2 fleet-toolchain consolidation (keeper / watcher / dispatcher →
   fewer, tested, modular Zig binaries; see `docs/status/ROADMAP-2026-08-20.md` Phase C) —
   specified, audited, implemented, and accepted through the project's own delivery pipeline.
2. **The measurement:** a definitive, race-grade profile of every model on every phase of that
   pipeline — ideation, specification, synthesis, auditing, implementation, and *grading itself*
   — collected mechanically, so the model-task allocation stops being folklore
   (`model-perf.md:64-95`, the confounding the belief audit named).

The subject is real work the project needs anyway. A synthetic subject would measure toy
performance; this one measures the job.

## 2. Roster

8 lanes, canonical labels (validate against the list, never a pattern):
`claude-fable-5`, `claude-opus-5`, `deepseek-v4-pro`, `deepseek-v4-flash`, `glm-5.2`,
`minimax-m3`, `kimi-k2.7`, `qwen3.8:27b-mlx` (local; best-effort — it was wall-killed with 0
bytes in T447; it stays in for exploration-first data, its DNFs are data too, and it never runs
during a measured suite run per `model-task-matrix.md:104-106`).

Every record carries **canonical label + serving tag + epoch date** (two silent model swaps have
already poisoned aggregates; the boundary is recorded, and the profiles tool refuses to
aggregate across it).

## 3. Phases

Each generation phase: byte-identical brief per lane, isolated worktree, `tools/runner` trailer
captured, lane output committed to the race directory before any grading.

| phase | every model independently… | sees | graded how |
|---|---|---|---|
| **P0 gate** | — (prerequisites, §4) | — | mechanical: all P0 rows green |
| **P1 ideas** | proposes a consolidation approach (≤2 pages: boundary, what merges, what stays, why) | the audit + roadmap + census F7 only | panel (§5), rubric R1 |
| **P2 specs** | writes a full spec from its own idea (interfaces, verbs, ownership table, migration, test story) | its own P1 output only | panel, rubric R2 + mechanical anchors (each of the census'd duplications addressed yes/no) |
| **P3 synthesis** | consolidates the best of **all eight anonymized specs** into one spec | all P2 outputs, anonymized | panel, rubric R3; **operator ratifies the winner** (with grafts from runners-up — judge-panel pattern) |
| **P4 audit** | independently audits the ratified synthesis (attack it: find the defect, the blur, the untestable claim) | the ratified spec | mechanical where possible (confirmed defects count), panel for the rest |
| **P4.5 battery** | — the acceptance battery is authored from the ratified spec and **sealed (commit hash recorded) before any implementation lane launches** — battery before code | — | the battery's own null + seeded controls |
| **P5 implementation** | implements the ratified spec in its own isolated worktree | ratified spec + sealed battery's *public* half | **mechanical first**: sealed battery pass rate, suite union green, controls RED-first honored; panel only for code quality on top |
| **P6 grading** | every model blind-grades every anonymized artifact of every phase, **including its own** | anonymized artifact sets | grader validity controls (§5); this phase *is itself scored* — grading is a measured skill |

**Merge rule:** one implementation merges (winner + grafts). The others are **demoted to
fixtures, never deleted** — duplication is the oracle; the losing implementations become mutual
test oracles for the fleet toolchain exactly as the engine re-implementations did.

**Freeze rule:** while P5 lanes run, no non-race task may hold `src/managent/main.zig` or the
fleet scripts. The live fleet keeps running the current tooling from the main tree.

## 4. P0 — prerequisites (the race does not start until these are green)

From `ROADMAP-2026-08-20.md` Phase D, restated as race gates because each maps to a recorded
breach:

| gate | rule | the breach it prevents |
|---|---|---|
| G1 tokens | harness captures per-lane token counts mechanically; a missing reading is recorded as missing, never estimated — and missing is the exception, not the default | 6/6 blank `tokens.template.md`; n=0 across all prior races |
| G2 isolation | harness **refuses to dispatch** unless `root_is_worktree=true` and the key/rubric directory is outside the worktree's reach | T452 ran from the main checkout with the key reachable by relative path |
| G3 family exclusion | harness refuses to *count* any grade where grader family == lane family; enforcement in `tools/bakeoff.sh`, not prose | T452's graders each ranked a set containing their own output; glm scored itself |
| G4 blinding | sanitizer pass strips/flags self-identifying text in lane outputs before grading; a lane that self-identifies is noted (that is itself a data point) | two T452 lanes named themselves; "ignored for scoring" was ad hoc |
| G5 record | `lanes.json` + sealed lane map are mandatory outputs of every phase; a race turn without them did not happen | T447 has no lanes.json; T452 is unrecorded in `docs/infra/races/` to this day |
| G6 impressions | the done-gate demands a model impression (or explicit waiver) at every race row's close | three seats lapsed identically; D3's partition logic, applied to model-perf |

## 5. Grading — the panel, its controls, and self-grades as data

- **Everyone grades everything, blind, including themselves.** Ranking uses only
  **non-family** grades (G3). Self-grades and family-grades are *retained and analyzed*, never
  counted: `self_preference_bias = self_grade − mean(non-family grades received)` is one of the
  most decision-relevant numbers this race produces.
- **Null control** per grading round: two near-identical artifacts must score within one rubric
  step, or that grader's round is invalid (bakeoff.md §grader-validity, kept verbatim).
- **Seeded control** per grading round: one deliberately weakened artifact (authored by the
  seat, sealed pre-round) inserted anonymously. A grader placing it in the top half fails
  validity for the round. Rubber-stamping becomes measurable instead of suspected.
- **Grader calibration:** each grader's mean absolute deviation from (a) the non-family
  consensus and (b) every mechanical anchor. Grading is a task some models will turn out to be
  cheap and excellent at — that is allocation gold (audits are the fleet's steady workload).
- Rubrics R1–R3 and all seeds are written by the seat, ratified by the operator, and **sealed
  with a commit hash before the phase dispatches** (the T447/T456 discipline that worked).

## 6. Data — one schema, mechanical capture, absorbed at close

Everything lands in `docs/infra/races/grand-race-ledger.jsonl` (append-only, one JSON per
event), written by the harness, never by hand:

```
lane record:  {race, phase, task_id, model, serving_tag, epoch_date, wall_s, cpu_s,
               peak_rss_mb, tokens_in, tokens_out, exit, heals, verified, artifact, sha256}
grade record: {race, phase, grader, artifact, scores{...}, total, is_self, is_family,
               null_ctrl_pass, seeded_ctrl_pass}
```

Derived per model (extension of `tools/model-profiles.py`, closing directive D027's 8×8 order):
generation quality per phase (non-family mean received) · honesty (claims failing verification —
the D2 base rate, per model this time) · completion reliability (wall-kill / 0-byte rate) ·
speed (wall, cpu) · cost (tokens; prices applied later, never in findings) · grader calibration ·
self-preference bias · independence (does it re-derive or re-run?).

**Absorption is part of the race, not an afterthought:** each phase closes through the T485
done-gate like any row; the final deliverable is (a) the merged implementation, (b)
`docs/infra/model-task-matrix.md` cells filled from the ledger with denominators, and (c) one
profile card per model — strengths, weaknesses, recommended task classes — *generated* from the
ledger (D-c rule: generated block, hand-edits lint-fail).

## 7. Honest limits, stated now

- **n=1 per cell.** One race gives each model one sample per phase (plus ~5 grading samples).
  Impressions from it are strong; *rankings* within a rubric step are noise. The remedy is the
  standing one: race again on the next real task; the ledger accumulates.
- **The subject favors systems-y models.** A fleet-tooling consolidation rewards Zig, shell,
  and process reasoning. The profile cards must say "on this task class"; the matrix has other
  rows for engine/proof work.
- **Grader consensus is not ground truth.** Mechanical anchors outrank panel scores wherever
  both exist; where the field disagrees with the key, the field may be right (T447: all five
  lanes beat the key) — key-beats are recorded and adjudicated, not suppressed.

## 7b. The aspect races run first — the cheap track (added 2026-08-20, rev 2)

Before any grand-race lane: the five **orchestrator aspect-races** designed at
`model-perf.md:97-114` (triage · verdict discipline · inbox handling · crash recovery ·
dispatch authoring) and the two sealed-but-never-run epistemic races (packets 3 and 5,
SHA-256s committed in `docs/evidence/EPISTEMIC-RACES/packets/MANIFEST.md`). Each runs every
rostered model against a **frozen fixture store** — identical platform state per lane — which
removes the confound the operator named: seat performance cannot be compared across seats that
inherited different repos, but it can be compared exactly here. Answer-keyed, blind-graded,
gates G1–G6 apply. These seven races are cheap (fixture stores, short walls, mostly mechanical
grading), are ready today, and produce the first unconfounded *orchestration-ability* data —
the input to the seat-allocation ruling. Their ledger records land in the same
`grand-race-ledger.jsonl` schema (§6) with `race: "aspect-<name>"`.

## 8. Cost and schedule envelope (operator's call; spend is a human decision)

Generation lanes: 8 × 4 phases (P1, P2, P3, P5) = 32. Grading lanes: 8 graders × 5 rounds = 40.
P4 audits: 8. Total ≈ **80 dispatches** plus reruns, walls 1800–3600 s. Ollama lanes are
credit-cheap and can run ≤5 concurrent streams (measured, T357); DeepSeek lanes have no known
limit; Claude lanes stay behind `WEIZIGO_BAKEOFF_ALLOW_CLAUDE=1` per run; qwen local runs only
on a quiet machine. **Go/no-go gate between every phase** — the operator can stop after P3 and
still walk away with a ratified consolidation spec and four phases of model data.

---

**Landmark:** this is `L9 (the fleet can race its own workers on demand)` exercised at full
width for the first time since D4 adopted it, in service of `L1 (the dashboard tells the
truth)` — the racers build the dashboard's next toolchain — and the profile cards close the
allocation-confounding debt named in the 2026-08-05 belief audit.

**Human summary:** eight models run the whole delivery pipeline on the real wave-2 consolidation
— independent ideas, independent specs, each synthesizing best-of-all, adversarial audit, sealed
acceptance battery, implementations in isolated worktrees, and blind cross-grading at every step
including self-grades (kept as bias data, never counted for ranking). Six gates fix the exact
holes the last race had: tokens mechanized, worktree isolation refused-not-requested, family
exclusion and blinding enforced by the harness, records mandatory, impressions demanded at
close. The operator holds a go/no-go between every phase, and the losers' implementations become
test fixtures, not waste.
