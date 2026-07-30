<!--managent set=T-->
# PINRULE-SUFFICIENCY — can ANY pointwise function of (L, TIE, H) be correct?

**Opened by:** the Orchestrator, reading `2B-PROBE-FIX`'s C2 falsification (`docs/epistemic/qa023-c2-adjudication-2026-07-29.md` §4). ANALYSIS, read-only, no file conflicts — it can run immediately and alongside anything.

## The question, and why it is the highest-value cheap experiment on the kanban

`2B-PROBE-FIX` falsified `V = median(L, TIE, H)` at 3×2: four states where the median pins TIE = 0 while the history-conditioned value is +1 or +3. On each, `L < 0 < H` — the truth lies inside the bracket but is not what the median selects.

The natural reading is "median was the wrong choice; try another pin rule." **That reading may be far too optimistic.** If two *distinct* states share the same `(L, TIE, H)` triple while having *different* history-conditioned truncation values, then **no pointwise function of `(L, TIE, H)` can be correct** — the inputs simply do not determine the output. Every candidate repair (median, a different bracket selector, a tie-breaking heuristic on L/H) dies at once, and the F2-REMEDY design needs strictly more state than the L/H pair carries.

That distinction decides whether F2-REMEDY is *repairable by substitution* or needs *a different algorithm class* (dependency sets, Kishimoto–Müller — whose costs are what made PSK intractable). It is one small experiment and nobody has run it.

## The task

At 3×2, under the corrected ko rule (post-`2B-FIX-KO`):

1. **Compute the fixpoint `(L, TIE, H)` for every reachable non-terminal state** — this already exists (`fixpoint-3x2`).
2. **Group states by their exact `(L, H)` pair.** Report the group-size distribution.
3. **Within each group of size ≥ 2, compare history-conditioned truncation values** using the *fixed* probe (`truncated_value` post-`2B-PROBE-FIX`, σ excluded, separate exhaustion counters). Note that ~93% of evaluations exhaust at the default 100,000-node budget: use `--node-budget` generously and **report the within-budget denominator per group**.
4. **The finding:** does any `(L, H)` group contain two states with *different* within-budget truncation values?
   - **Yes** → no pointwise pin rule can work. Report the smallest witness pair in full (both gobans, both values, both arrival histories). This is a **stronger falsification than C2** and it forecloses a whole family of repairs.
   - **No** (across everything within budget) → a pointwise rule remains *possible*; then **characterise the correct one** on the four known counterexample states, and say what it would have to return where the median returns TIE. Do **not** claim a rule works — claim only that the obstruction was not found, and state the coverage.
5. **Report the coverage honestly.** With 93% budget exhaustion this experiment is easy to run vacuously. State how many groups had ≥2 states with ≥1 within-budget evaluation each — that count is the real denominator, and if it is tiny, say so and say the experiment was inconclusive.

## Acceptance

- The `(L, H)` group-size distribution, with the number of groups actually testable.
- An explicit yes/no on the witness pair, with the witness in full if found.
- **The wrong-answer pass rate of your own check**: what would a still-broken evaluator, or a vacuous sample, have scored here? Given the exhaustion rate this is the question that decides whether the result means anything.
- No claim status changed; propose only.

## Deliverable

`docs/evidence/QA-023/pinrule-sufficiency-<date>.md` + stdout + `PROVENANCE-*.md`. Read-only on `src/` — if you need a new mode, put it in a **new file** (suggest `src/qa023_pinrule.zig`) and say so; `src/qa023_probe.zig` is contended (`F1-SEEDROOTS` is queued on it).

**Read first:** `docs/epistemic/qa023-c2-adjudication-2026-07-29.md` (§4 is this task's premise), `docs/evidence/QA-023/probe-fix-2026-07-29.md` §4 (the four counterexample states), `docs/evidence/QA-023/proof-v2-2026-07-28.md` §5.3 (the gadget that killed the v1 rule — a precedent for what a pin-rule counterexample looks like).
