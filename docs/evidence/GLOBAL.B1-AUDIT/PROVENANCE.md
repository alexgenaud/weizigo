# PROVENANCE — `GLOBAL.B1-AUDIT` · re-converge-from-`+N` is multi-fixpointedness, not least-ness

**Author:** minimax-m3/T825 (C3 buckets reconciliation wave)
**Date:** 2026-08-25
**Claim closed:** `GLOBAL.B1-AUDIT` — "The re-converge-from-`+N` check is a multi-fixpointedness
observation, **not** a least-ness witness; the prior (a′) conclusion was unsound."
**Status:** PROVEN (as mathematics / a statement about a committed argument) — **unchanged by
this repoint.**
**Repointed from:** `leak-crisis.md:99-101; 4x4/EPISTEMIC.md:90-97; CONCEPTS.md:29-30` (claimlint
C3 flagged: no path under `docs/evidence/`).

---

## 1. The argument the claim is about

The claim asserts that a fixpoint reached from a non-bottom seed (the re-converge-from-`+N` check)
demonstrates *the existence of another fixpoint*, not that the canonical `lo` (= seeded `−N`,
Gauss–Seidel sweep) is **not** the least fixpoint. Concretely:

- **Knaster–Tarski** (per `docs/evidence/GLOBAL-FP1/proof-2026-07-30.md` Theorem) on a finite
  complete lattice gives a **whole lattice** of fixpoints, ordered by inclusion. Two extreme
  elements are the least and the greatest; everything else sits between.
- Re-converging from `+N` produces a fixpoint, but by definition `+N ≥ lfp(T)`, so the result is
  *some* fixpoint with `+N ≥ result ≥ lfp`. There is no logical way to read "lands above canonical"
  as "canonical is not least"; that would require the seed itself to be **below** the canonical,
  which `+N` is not.
- The re-converge observation is therefore a **measurement of multi-fixpointedness** (the lattice
  has more than one element), not a falsifier of least-ness. The "multi-fixpointedness" reading
  is what was carried in `leak-crisis.md:99-101` and adopted in the F1 acceptance set (the
  re-converge check was dropped from `4x4.FP1`'s acceptance gate because it confounded two
  propositions).

## 2. Where the argument is established in committed text

- **`docs/evidence/GLOBAL-FP1/proof-2026-07-30.md`**, the consequences section under "Multiple
  fixpoints are expected, not anomalous", explicitly names `GLOBAL.B1-AUDIT` as the claim
  carrying this consequence: *"a fixpoint landed on from another seed is not thereby least"* —
  the verbatim statement of the row's claim.
- **`docs/status/leak-crisis.md:99-101`** records the original re-labelling from "the re-converge
  falsifies canonical least-ness" to "the re-converge shows the lattice has more than one fixpoint".
- **`docs/epistemic/boards/4x4/EPISTEMIC.md:90-97`** records the F1 acceptance-set decision:
  the re-converge-from-`+N` check was dropped because it is necessary, not sufficient.
- **`docs/epistemic/boards/CONCEPTS.md:29-30`** states the proposition abstractly.

## 3. What this note does NOT establish

This note does not run a probe; the claim is a logical statement about the meaning of a re-converge
check, established by the FP1 proof note's consequence section and the committed leak-crisis
analysis. A probe would not add evidence — the proposition is true by Tarski's theorem
(construction in §1 above), and the committed proof is the witness.

## 4. Scope limit

The claim is about the **logical content** of the re-converge-from-`+N` check. It is not a claim
about any specific run output (no measurement row carries this claim as a parent). The empirical
re-converge values per goban live in `GLOBAL.B1-MULTIFIX` (MEASUREMENT, separately registered).
