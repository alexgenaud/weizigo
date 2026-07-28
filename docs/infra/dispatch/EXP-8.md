# EXP-8 — the PSK divergence measurement (strategy S2)

**Closes:** `QA-012` as scoped to the endpoint comparison (new rule ↔ exact
PSK) rather than adjacent ladder rungs; supplies the value half of `QA-024`,
whose measured half is legality only. Bears on `QA-010`. **Blocks:** nothing —
it is the door the project keeps open to perfection. **Blocked by: EXP-6** for
the 4×4 measurement — **but the harness can and should be built earlier**,
against the EXP-4 (2×2, 3×2) and EXP-5 (3×3) tables. Runs in parallel with
EXP-7.

**Read first:** `docs/infra/dispatch/README.md`, then `AGENTS.md`, then
`docs/epistemic/roadmap-2026-07-28.md` §2 (S2 and "the door to perfection stays
open") and §3 (EXP-8), then `docs/research/psk-binding-rate-2026-07-28.md`
(EXP-1's result — the thing this experiment must **not** be confused with),
then `docs/research/ruleset-options.md` §RETRO_CYCLE and §kill-X% for what
exact PSK actually costs.

---

## The framing, which the write-up must carry verbatim in substance

**EXP-1 measured legality. EXP-8 measures value. They are different questions
and the first does not answer the second.**

EXP-1's result: in engine self-play across 4×4, 4×3 and 3×3, PSK forbade
nothing that basic ko allowed — **0 binding events in 130,171 plies and
1,015,076 candidate moves** (`psk-binding-rate-2026-07-28.md:355-357`), and 0 in
both recorded human-vs-engine games. That is strong, and strictly about **which
moves are legal along the lines actually played**.

It does **not** imply the two rules agree on *value*. Two reasons, both of which
must be stated:

1. **The rules differ deep in the tree, where play never went.** A value is a
   minimax over the whole subtree, including lines neither player chose
   precisely because they were bad. PSK bans some of those; the new rule allows
   them and terminates them at the tie. A ban that never binds *on the played
   line* can still change what the played line is worth.
2. **It is not even monotone.** Basic ko is the *weaker* restriction, so **both
   players gain options** relative to PSK. Black gaining options pushes the
   value up, White gaining options pushes it down; there is no sign-determined
   direction and no "PSK value ≥ new-rule value" inequality to lean on. **Do not
   assert one.** If you think a monotonicity argument exists, write it out and
   get it reviewed — `AGENTS.md` requires the theorem, not the intuition.

EXP-8 is what actually closes the value question, and the divergence rate it
produces **is** the user's "shrink the suboptimal play toward zero" metric, as a
number.

## The question, stated precisely

For sampled positions where exact PSK is computable, compare the new-rule table
against exact PSK on **two** quantities, reported separately:

- **Value divergence.** `|v_newrule(s) − v_PSK(s)| > 0` — rate, and the
  distribution of the magnitude.
- **Move divergence.** The move the new-rule table's selection rule picks
  (`Session.choose`, `src/gtp.zig` — a one-ply extremum over stored child
  values) versus the set of PSK-optimal moves at the same position. Report both
  *"picked a different move"* and *"picked a move strictly suboptimal under
  PSK"*, with the **PSK-value loss** of the picked move. Not the same number;
  the second is the one that matters for play strength.

## What "where PSK is computable" actually means — the hard constraint

Exact PSK is intractable **from the empty board on a 2×2**: 118,475,182 ban-set
states at a 200M-node budget (`ruleset-options.md:157-165`). There is no "small
board" escape — the escape is **depth**.

The exact solver is `Exact(w, h)` at `src/retro.zig:1794` (`Ctx`, `Key =
{idx, side, passes, win, bans}`, `solve()` at `:1859`), budget- and
entry-capped. **Import it read-only as a module; do not edit `src/retro.zig`.**
Earlier probes built with
`zig build-exe -O ReleaseSafe --dep retro -Mmain=<probe>.zig -Mretro=src/retro.zig -femit-bin=...`
(`c2-falsification-3x2.md:124-129` — that probe's own source was lost to
`untracked/`; yours goes in `docs/evidence/`).

So the sampling frame is **positions with few empty points**, and the frame is
itself a first-class deliverable:

- State the **empties threshold** and how you chose it — measure the solver's
  success rate against empty count and report the curve, rather than picking a
  number and hoping.
- Report **budget exhaustion as its own outcome**, never as agreement. Positions
  PSK could not solve are *excluded*, and exclusions must be counted; a
  denominator that quietly drops the hard positions is biased toward agreement
  in exactly the regime where divergence is most likely.
- Label the bias: PSK is computable precisely where cycles are *scarce*, which
  is where the rules are *least* likely to differ. **The result is a lower bound
  on divergence and must be reported as one.**

## Two sampling frames, both required

They answer different questions and must not be pooled.

- **(A) Reachable-play frame.** Positions drawn from playouts from the empty
  board (the `oracle` / `oracle-rt` / `mixed` / `random` policies of
  `src/reachcensus.zig`). Answers *"does it matter in play?"* — the frame the
  user's metric lives in.
- **(B) Uniform-over-slots frame.** Positions drawn uniformly from legal slots
  at the given empty count. Answers *"does the table diverge?"* Slot-uniform is
  the wrong denominator for a player
  (`reachable-kosensitivity-2026-07-28.md:47-52`): report it as the table
  measure, never as the play measure.

## Acceptance criterion

A **divergence rate with a stated sample size and a power argument**, per board
and per frame, no pooling:

- For each of 3×3 and 4×4 (and 2×2 / 3×2 while the harness is being built),
  and for each frame A and B: `d` divergences out of `n` PSK-solved positions,
  with `n` stated, exclusions stated, and a **95% confidence interval**.
- **The power argument is part of the criterion, not a garnish.** At zero
  divergences the rule of three gives a 95% upper bound of `3/n`: `n = 300`
  bounds the rate at ≤ 1%, `n = 1,000` at ≤ 0.3%. **State the bound you achieved
  and pick `n` to reach one you will defend.** "0 divergences observed" without
  an `n` is not a result.
- If `d > 0`: the magnitude distribution and ≥ 3 worked examples (position, both
  values, the move each rule prefers, the PSK-value loss).
- A one-sentence headline: *"On <board>, frame <A|B>, the new-rule table
  diverges from exact PSK in `d`/`n` sampled positions (95% CI …), `k` excluded
  for budget exhaustion."*

**A high divergence rate is a full deliverable, not a failure** — it says the
tractable rule is a poor proxy for the machine standard, which is exactly what
the user asked to have measured rather than assumed.

## Prior attempts this must distinguish itself from

1. **EXP-1** (`psk-binding-rate-2026-07-28.md`) — legality, not value. See the
   framing section. Its `(B) chosen move` counterfactual is **one ply deep** and
   under **basic-ko legality only**; it is not a value comparison and the
   document says so.
2. **The C2 falsification (`3x2.T13`)** compared fresh-start table values
   against a history-aware exact PSK solver at 3×2 and found 12 mismatches on
   508 non-trivial PSK histories (`docs/research/c2-falsification-3x2.md`) —
   the same *shape* of experiment against the old rule, and the best available
   model for your harness. Read it. It is **not** a result about the new rule,
   and its probe source is lost, so you are rebuilding, not reusing.
3. **kill-50% at 2×2 returned +1, "score unchanged" from PSK**
   (`ruleset-options.md:91-98`). One position, one board, a third rule. Not
   evidence of anything here.
4. **`QA-012` is UNTESTED and was posed as adjacent ladder rungs** (`j` vs
   `j+1`). You measure the endpoints instead, because there is exactly one
   affordable rung. Say so; do not let the write-up read as if the ladder was
   built.

## Calibration requirement (mandatory — dispatch README, done #4)

- **Known-good:** the harness, pointed at the **PSK** table
  (`artifacts/oracle-3x3.wzo` or `data/oracle-4x4.checkpoint.wzo`) versus the
  exact PSK solver on fresh-start positions, must report **agreement** where the
  project already knows agreement holds — the fresh-start single-score (L==H)
  region, `GLOBAL.C1`. A harness that finds the PSK table disagreeing with the
  PSK solver on L==H slots is broken, and every divergence it reports about the
  new table is noise.
- **Known-bad, two cases:** (1) run the harness on the **2×2** pair where the
  rules are *known* to disagree — new-rule/published **0** vs weizigo PSK **+1**
  (`retrograde-3x3.md:224-245`) — and it must report a root divergence; a
  detector that misses the one divergence provable from the literature detects
  nothing. (2) Perturb one new-rule value by 1 point and confirm the divergence
  count increases by exactly the number of sampled positions affected.

Both runs committed.

## Deliverables

- `docs/evidence/QA-012/` — harness source (the PSK driver **and** the sampler),
  raw output per board and per frame with commands, seeds, artifact paths and
  sha256s, budget/entry caps, the empties-vs-solvability curve, both
  calibration runs, and `PROVENANCE.md` per `docs/evidence/README.md`.
- `docs/research/psk-divergence-2026-07-28.md` — the rates with CIs and power
  argument, the exclusion accounting and its bias direction, the worked
  examples, the explicit statement that no monotonicity between the rules is
  claimed, every claim tagged. Per-board sections.
- One-line status for the `CLAIMS.md` owner (`QA-012`, and the value half of
  `QA-024`). **Do not edit `CLAIMS.md`.**

## Do NOT

- Do **not** edit `src/retro.zig` (where `Exact` lives), `src/oracle.zig`,
  `src/rules.zig` or `src/solve.zig`. Import read-only. If you truly need an
  edit, declare exclusive ownership in `docs/status/CURRENT.md` first and expect
  to wait — EXP-6 may be mid-build on a multi-hour run.
- Do **not** write to `data/` or `artifacts/`. Read-only experiment.
- Do **not** report a divergence rate without `n`, the exclusion count and the
  confidence bound.
- Do **not** count a budget-exhausted PSK solve as agreement, and do not raise
  the budget selectively on positions that disagree.
- Do **not** assert or assume monotonicity between the rules' values in either
  direction. Both players gain options under the weaker rule.
- Do **not** cite EXP-1's zero as evidence that the values agree. That
  conflation is the specific error this brief exists to prevent.
- Do **not** pool frames A and B, or pool boards (`AGENTS.md`).
- Do **not** conclude "the new rule is PSK-perfect" from a zero rate. Zero
  divergence on the computable subset is **evidence, never proof**, and that
  subset is biased toward agreement. The roadmap says this (§2, S2); keep it
  saying it.
