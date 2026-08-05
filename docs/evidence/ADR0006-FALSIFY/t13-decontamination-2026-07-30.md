# ADR0006-FALSIFY — T13 decontamination

**Task:** T119 · **Role:** worker · **Model:** DSPro · **Date:** 2026-07-30
**Source:** Opus T110 re-implementation (`docs/evidence/T13/probe-reimplementation-2026-07-30.md` §7)
**Target:** `docs/infra/dispatch/ADR0006-FALSIFY.md` contamination list

## Finding

**T13 is not contaminated by ADR-0006.** Opus T110 (2026-07-30) confirmed:

1. **The retrograde sweep never applied the eye-prune.** `src/retro.zig:98`:
   `pub const apply_eye_prune = false`. The stored L==H values T13 tests
   against were produced by expanding every empty point — no move was ever
   skipped due to the eye-prune.

2. **The probe's history-aware query (`ab_solve`) does apply the eye-prune**
   (`src/retro.zig:537-540`). So the two sides of T13's comparison use
   different move sets: the sweep (unpruned) vs the probe (pruned). This is
   exactly the exposure `ADR0006-FALSIFY.md` describes: a mismatch
   could, a priori, be an ADR-0006 violation rather than a C2 violation.

3. **But the exposure is vacuous for the twelve recorded lines.** T110 §7
   re-solved all twelve with the prune disabled — making the probe's move set
   identical to the sweep's — and found **bit-identical values** in every
   case:

   ```
   counterexamples surviving with the eye-prune OFF: 12/12
   values unchanged by the prune setting: 12/12
   ```

   The prune changes no value in any of these searches. `3x2.T13` is
   invariant to ADR-0006.

4. **Corroborated independently by T114** (`docs/audits/2026-07-30-eye-prune-validation.md`),
   which found no ADR-0006 falsification across an exhaustive 4×4 structural
   battery. T114's §H (sound control) also found agreement between the
   eye-pruned forward search and the unpruned retrograde table at 2×2, 3×2,
   and scoped 3×3/4×3.

## Action

`docs/infra/dispatch/ADR0006-FALSIFY.md` should strike T13 from its
contamination list. The list currently reads:

> Every forward search the project uses as ground truth applies this prune —
> the 2×2/3×2 exact solver, the finisher, T13, E2.

The corrected list is:

> Every forward search the project uses as ground truth applies this prune —
> the 2×2/3×2 exact solver, the finisher, E2. T13 was investigated 2026-07-30
> (T110) and found invariant to the prune on all twelve recorded lines.

The rest of the contamination list stands: `3x2.C1`, `3x3.C3`/E2, and the
finisher remain exposed.

## What does NOT change

- `3x3.C3`/E2 remains on the contamination list.
- The finisher remains on the contamination list.
- ADR-0006 itself is not proven — only its irrelevance to T13 is established.
- The dispatch's acceptance criteria (exhaustive 3×3 check, calibration) are
  unaffected.

## Distinction: solver prune vs enumeration prune

T110 §6 found that applying the eye-prune to the **reachability enumeration**
(not the solver) silently deleted three of T13's own recorded lines. This is a
separate finding and is recorded in T110's report. The rule it produces:

> **ADR-0006 belongs in the solver, never in a reachability enumeration.**

Any future history-sensitivity probe that enumerates arrival histories with an
eye-pruned move generator will under-report. `t13_probe.py` keeps an
`eye_prune=True` switch on `enumerate_lines` so the wrong answer can be
reproduced deliberately for calibration.

---

*Identifier: DSPro/T119, Task 3 of 3. No engine files modified.*
*Claims supported: `GLOBAL.ADR0006-EYE` (decontamination only — does not prove the ADR)*
