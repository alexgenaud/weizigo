# Recoverability audit — the untracked graveyard

**Task:** T119 · **Role:** worker · **Model:** DSPro · **Date:** 2026-07-30
**Method:** For each item in the CONFIRMED LOST table of `docs/evidence/README.md`,
determine whether the committed code (`src/`) contains enough to regenerate the
result. T110 proved the point for T13: `retro.ab_solve` was never lost, only
the driver that called it was.

---

## Classification

Three categories:

| class | definition |
|---|---|
| **RECOVERABLE** | The committed `src/` primitives + the durable description suffice to regenerate the result. A driver must be written but no algorithm is missing. |
| **DURABLE SUMMARY EXISTS** | The raw output is lost but the numbers survive in a committed document. Regeneration would reproduce, not recover. |
| **LOST** | The artifact was pure text — reasoning, discussion, or run output that was never promoted to a committed file. No code can regenerate it. |

**Key principle: algorithms in `src/` are durable. Drivers and discussion in `untracked/` are not.**

---

## Load-bearing seven

### 1. `untracked/c2pilot_3x2.zig` (T13 probe source)

| field | value |
|---|---|
| **Classification** | **RECOVERABLE — and already recovered** |
| **Committed algorithms** | `src/retro.zig` (tables, `ab_solve`), `src/colex.zig` (Indexer), `src/rules.zig` (legality, scoring, Benson) |
| **Recovery** | `docs/evidence/T13/zig_t13_replay.zig` (72 lines, T110) + `docs/evidence/T13/t13_probe.py` (Python re-implementation) |
| **Verification** | All 12 recorded contradiction lines re-execute exactly; 5,868/5,868 cell values match between Python and Zig |

**What was lost:** a driver — a list of twelve histories and a loop.
**What was never lost:** `retro.ab_solve`, the L/H tables, the move/capture/suicide kernel, the Benson life implementation, the colex bijection.

### 2. `untracked/T13-minimax.md` (T13 raw output)

| field | value |
|---|---|
| **Classification** | **DURABLE SUMMARY EXISTS** |
| **What survives** | `docs/research/c2-falsification-3x2.md` — method, ban-set distribution, all 12 contradiction lines, 0/540 fresh-start sanity |
| **What is lost** | Raw stdout, exact enumeration order, the full 153,613 line count |

The durable summary is sufficient to reproduce the result (T110 did), and the
recovery (item 1) is stronger than the original since it is independent.

### 3. `untracked/T12-minimax.md` + `untracked/c2pilot_2x2.zig` (T12: C2-pilot-2×2)

| field | value |
|---|---|
| **Classification** | **RECOVERABLE** |
| **Committed algorithms** | Same as T13 (`src/retro.zig`, `src/colex.zig`, `src/rules.zig`), applied at 2×2 |
| **What survives** | One-line result in `dispatch-registry/SUBAGENTS.md`: "C2-pilot-2×2 PARTIAL/tautological, no non-root cycles" |
| **Recovery effort** | **Minimal.** The T110 re-implementation (`t13_probe.py`) parameterises goban size; setting `(2,2)` and running `census`/`sanity`/`search` would regenerate the result in seconds. A 2×2 goban has 4 cells and 64 states — far simpler than 3×2. |
| **Verification target** | The claim: at 2×2, PSK never fires during placement-only lines, so every history-aware query reduces to fresh-start. |

**What was lost:** a driver file even simpler than T13's.
**What was never lost:** the entire engine, which handles 2×2 trivially.

### 4. `untracked/T02-minimax.md` (B1 least-fixpoint results)

| field | value |
|---|---|
| **Classification** | **RECOVERABLE** |
| **Committed algorithms** | `src/retro.zig` — `RETRO_B1_LOFIX` probe (V0+V1 Bellman checks, the T02.1 `oppV0[child]` correction) |
| **Method survives** | `docs/evidence/b1-least-fixpoint/b1-spec.md` — the **specification** of the probe |
| **What is lost** | The numerical results (how many positions violated, at which sizes) |
| **Recovery effort** | **Moderate.** The spec + committed `src/retro.zig` contain everything needed. Write a driver that runs `RETRO_B1_LOFIX` at 2×2/3×2/3×3, collect the violation counts. |
| **Verification target** | The numbers reported in `docs/status/leak-crisis.md:86-101` |

### 5. `untracked/T02-audit-kimi.md` (Kimi audit convicting the (a′) variation)

| field | value |
|---|---|
| **Classification** | **LOST** |
| **What survives** | Two-line paraphrase in `docs/status/leak-crisis.md:99-101` + `docs/epistemic/CLAIMS.md:132` (`GLOBAL.B1-AUDIT`) |
| **Nature** | This was a reasoning document — why the (a′) variation (re-converge-from-`+N`) is unsound. The reasoning cannot be regenerated from code. |
| **Impact** | This audit is what removed the re-converge-from-`+N` check from `4x4.FP1` acceptance. The decision survives; the argument for it does not. |

### 6. `untracked/T07-audit-hypotheses.md` (~42 KB, eight findings)

| field | value |
|---|---|
| **Classification** | **LOST** |
| **What survives** | The product: `docs/epistemic/boards/4x4/EPISTEMIC.md` *is* the rewritten tree |
| **What is lost** | The eight individual findings, itemised reasoning, and intermediate states |
| **Impact** | The final tree survives. The path to it (which hypotheses were tested and rejected, which survived and why) does not. |

### 7. `untracked/B05-glm.md` (reframe scope)

| field | value |
|---|---|
| **Classification** | **DURABLE SUMMARY EXISTS** |
| **What survives** | `docs/epistemic/CLAIMS.md:258` (`GLOBAL.REFRAME`) + paraphrase at `docs/status/leak-crisis.md:146` |
| **What is lost** | The full argument for the reframe scope boundaries |

---

## Also-cited-but-missing

### 8. `untracked/c2pilot_2x2.zig` (T12 probe source)

Same as item 3 — RECOVERABLE. The committed engine + parameterisation to 2×2.

### 9. `untracked/T15-kimi.md` + `untracked/T15-review-kimi.md`

**LOST.** Capture-all design discussion. T15 was deferred, so nothing depends on them.

### 10. `untracked/T16-glm.md`

**DURABLE SUMMARY EXISTS.** The EPISTEMIC/CONCEPTS rewrite is the product.

### 11. B29/B30/B31/B32 — I1/I2/I3/I7 sources

| field | value |
|---|---|
| **Classification** | **LOST** |
| **What survives** | Summary rows in `docs/epistemic/innovations.md` |
| **Impact** | **I1 (single-ko formula)** is the most concerning — it is "tested, not proven" and the test is gone. The formula itself may survive in code (it is a mathematical claim, not a measurement), but the verification run is not recoverable. |
| **I2** (writes-off parallel finisher) — the algorithm is in `src/retro.zig`; the performance measurement is lost. |
| **I3** (ko decomposition) — if it lives in code, recoverable; if only in the run output, lost. |
| **I7** (99.5% sign-crossing) — a measurement; lost. |

---

## Summary

| count | classification |
|---|---|
| 3 | **RECOVERABLE** — T13, T12, T02/B1 results (primitives all in committed `src/`) |
| 3 | **DURABLE SUMMARY EXISTS** — T13 output, B05, T16 (enough survives to not need recovery) |
| 5 | **LOST** — T02-audit-kimi, T07, T15, B29–B32 (pure text, no code can regenerate) |

The asymmetry is structural: **anything whose computation is in committed `src/`
is recoverable** with a driver rewrite. **Anything that was human reasoning or
discussion** is irrevocably lost unless it was promoted to `docs/` before the
sweep. The `AGENTS.md` rule — *evidence in git, or the claim is not proven* —
was written because of this distinction and remains correct. But the register
overstated the damage for T13: "cannot be reproduced" was wrong when the engine
that produced the numbers was in the tree the entire time. T110's recovery
proves it.

---

## Action

1. `docs/evidence/README.md` — update the T13 note: the probe source is no
   longer lost. Add a pointer to `docs/evidence/T13/` for the re-implementation.
2. `docs/evidence/README.md` — update the T12 row: note recoverability from
   committed code (same engine, parameterised to 2×2).
3. `docs/evidence/README.md` — add a RECOVERABILITY column or annotation to the
   CONFIRMED LOST table.

*Identifier: DSPro/T119, Task 2 of 3. No engine files modified.*
