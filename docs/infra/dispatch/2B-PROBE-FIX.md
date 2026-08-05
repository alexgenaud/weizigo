<!--managent set=L holds=src/qa023_probe.zig-->
# 2B-PROBE-FIX — the probe never ran; fix two harness defects, re-measure, and split C1 from C2

**Opened by:** the Orchestrator's absorption check before promoting the QA-023 falsification into `CLAIMS.md`. Evidence: `docs/evidence/QA-023/probe-defect-2026-07-29/README.md`. **This supersedes the 2B-4 and 2B-FIX-KO probe numbers, which are artefacts. 2B-6 is gated on this task.**

## What is wrong

`truncated_value` was called with an arrival set that **contains the target state σ itself**, so its opening revisit check matched σ against σ and returned `TIE` before the terminal check, before `moves()`, before any recursion. Measured: **1,133 σ-in-arrival collisions out of 1,133 evaluations.** The evaluator was `return TIE;` with extra steps, so `disagreements` merely counted sampled states whose median fixpoint is non-zero.

1. **`src/qa023_probe.zig:1721`** — pass `arrival_len - 1`. `reference-semantics-2026-07-29.md` §1 defines the arrival visit-set as **exclusive of σ**; the buffer at `:1681-1712` is built inclusive.
2. **`src/qa023_probe.zig:1593`** — the continuation scratch stack is sized `history_depth + 4`. Continuation depth is bounded by the reachable state count (§1's termination argument), **not** by arrival depth. Overflow returns `null`, which is silently tallied in the budget-exhausted line. Defect 1 masked this entirely.

A worked counterexample is in §4 of the evidence README: a 4-move arrival where Black at `passes == 1` can pass into a terminal worth +6, and the probe returns TIE. There is no reading of §1 under which that is defensible.

## The task

1. **Reproduce the defect before fixing it.** Independently confirm the σ-in-arrival collision count (the evidence README's assertion patch is one way; your own is better). If you cannot reproduce it, say so and stop — that is a more important finding than the fix.
2. **Fix both defects** in `src/qa023_probe.zig`. Do not touch the rules (`apply_place`/`apply_pass`/`moves`) — the 2B-FIX-KO ko correction stands and is out of scope.
3. **Add a `--node-budget` flag** (hardcoded at `:3287`) and **report budget exhaustion honestly, separately from scratch overflow** — they are different failures and §2 of the reference semantics requires exhaustion never be read as agreement. Two counters, two lines.
4. **Re-measure** at 3×2: seeds and depths of your choosing, but state them. The corrected instrument exhausts ~93% of evaluations at the old 100,000-node budget, so **report the within-budget denominator on every line** (standing rule 3: state every denominator).
5. **Split the verdict into C1 and C2** — this is the deliverable that matters:
   - **C1 (Markovian state-sufficiency):** for a fixed σ, do two arrival histories with different visit-sets give different values? This is what the `QA-023` row in `CLAIMS.md` asserts and what the roadmap needs. Every observation so far — corrected and uncorrected — is **consistent with C1 holding**. Test it directly: same σ, deliberately contrasting histories (short vs long, disjoint visit-sets), both within budget.
   - **C2 (the median formula, `QA-026` / proof-v2 Thm 5.1):** does the common value equal `median(L, TIE, H)`? The corrected run shows **12 disagreements out of 77 within-budget evaluations**, all in the **over-pinning** direction (fixpoint pins TIE where truncation has a value), on a graph where the median rule pins TIE at 1,532 of 1,756 non-terminal states. Adjudicate each of the 12 by hand.
   - Report which conjunct fell. A single within-budget C1 counterexample falsifies QA-023 as stated in `CLAIMS.md`; a C2-only failure falsifies `QA-026` and leaves the state representation intact. **These have opposite roadmap consequences — do not report "QA-023 falsified" without saying which.**

## ⚠ ADDENDUM 2026-07-29 (added mid-flight) — `2B-3-AUDIT` has landed and it changes item 5

`docs/audits/2026-07-29-2b-3-history-pairs-audit.md` (independent Python
re-implementation) verifies the generator is **correct** but finds a **systematic
sampling bias** that bears directly on the C1 half of this task. Measured on 30
states with in-degree ≥ 2:

| metric | value |
|---|---|
| states where the DFS **misses the shortest path entirely** | **28/30 (93%)** |
| states where it includes **any** shortest path | **0/30 (0%)** |
| avg shortest-path length vs avg collected length | **5.1 vs 14.8 moves** |
| avg pairwise shared-prefix fraction | **62%** |

And short paths are the *most* visit-set-diverse: every sampled target with ≥2
shortest paths has visit-set-distinct ones. **The generator systematically misses
exactly the contrast C1 needs.**

Consequence for your item 5: **a C1-negative result from the existing generator
does not mean "no history-dependence".** It means "no history-dependence among
histories that share ~62% of their prefixes and sit at depth ≥ 13" — which is a
much weaker statement, and it is the statement the Orchestrator's own "nothing
observed contradicts C1" was resting on. Do not inherit that overstatement.

**So C1 needs a generator change, not just a probe fix.** The audit's recipe:
two-phase collection — (1) BFS for all shortest paths, guaranteed most diverse;
(2) DFS for long detour paths — then **pair short-vs-long deliberately** for
maximum contrast. If you would rather scope that out, say so explicitly and
report C1 as **UNTESTED-FOR-WANT-OF-CONTRAST** rather than as passing; an
honest "not tested" is worth more here than a weak pass, and the project has
been burned precisely by weak passes read as confirmations.

## Acceptance

- The collision count, independently reproduced (or a reasoned refutation).
- Both fixes, with the three-way split reported on a stated within-budget denominator.
- A per-state adjudication of the residual disagreements: real C2 counterexample, or a third defect.
- An explicit C1 verdict and an explicit C2 verdict, each with its evidence.
- **State the wrong-answer pass rate of your own check** (standing rule 4): what would a still-broken probe have scored on it?

## Deliverable

`docs/evidence/QA-023/probe-fix-<date>.md` + stdout + `PROVENANCE-*.md`. **Do not edit `CLAIMS.md`** — propose status changes for `QA-023`, `QA-026`, `3x2.QA023.B-PROBE`; the Orchestrator folds them in once a second seat agrees.

**Holds:** `src/qa023_probe.zig`. **Build/run:** through `tools/runner`. Never unfiltered `zig test src/qa023_probe.zig` — it collects the brute's exponential tests and has killed a console for 301 min; use `--test-filter`. Note `timeout(1)` does not exist on macOS; do not rely on it to bound a run.

**Read first:** `docs/evidence/QA-023/probe-defect-2026-07-29/README.md`, `reference-semantics-2026-07-29.md` §1-§2 (the trilemma and the three-way split), `ko-fix-rerun-2026-07-29.md` §6.1 (the unreachable perturbation branch — same root cause), `calibration-2026-07-29.md` (2B-5: the POS arm exercises a **parallel** PSK code path, so it did not cover the defective call site).
