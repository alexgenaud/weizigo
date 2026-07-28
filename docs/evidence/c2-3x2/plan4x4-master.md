<!-- RESCUED EVIDENCE -->
> **Provenance header** (added 2026-07-28 by the `docs/evidence/` rescue sweep;
> the body below this rule is verbatim and unedited).
>
> - **Original path:** `untracked/plan4x4-master.md`
> - **Original mtime:** 2026-07-26T00:14:12
> - **Rescued:** 2026-07-28
> - **sha256 (original, at rescue):** `ee278f04b61d6948210235cfe76906523ef266053627a70a0ff57b272122a03d`
> - **Supports:** `3x2.T13` (design), `4x4.C2`, `4x4.C3`, `GLOBAL.C2` — the C2-probe design
> - **Cited by:** `docs/status/leak-crisis.md:181` — "C2-probe design: `untracked/plan4x4-master.md` (B5/C2)"
>
> The original in `untracked/` is git-ignored and may be deleted at any time.
> This copy is the durable one. Do not edit the body; append corrections to
> `docs/evidence/README.md` instead.

---

# Master plan: solve 4×4 by building its isolated epistemic tree

**Synthesized by:** GLM-Boss, from the three model proposals (GLM, Minimax, Kimi).
**Date:** 2026-07-25. **Status:** DRAFT — awaiting user review before any execution.

## 1. The principle

A proof, falsification, or hypothesis at one board size is NOT evidence at
another. The leak crisis proved this: C3 was *supported* at 2×2/3×2 and
*falsified* at 3×3. Each board size gets its own isolated epistemic tree,
populated by experiments run *at that size*. Small boards are concept
laboratories and tool testbeds — sources of fact-topics (what to check), not
donors of proof status.

## 2. The concept-inventory (shared cross-size, no status)

`docs/boards/CONCEPTS.md` — definitions only; status lives in per-size trees.

**Structural (S):**
- S1: colex bijection collision-free. Prove: exhaustive round-trip at size.
- S2: Benson pass-alive theorem holds. Prove: exhaustive falsification at size.
- S3: rules kernel correct (moves, captures, scoring, life). Prove: cross-
  validation + published position counts.
- S4: area scoring correct. Prove: cross-validation + manual replay.

**Fixpoint (FP):**
- FP1: L is least, H is greatest fixpoint of the Bellman map (Knaster-Tarski).
  Prove: V0 AND V1 equations hold (zero violations) + monotone from -N bottom.
- FP2: where L==H, the value is history-independent. **The ADR-0009 honesty
  clause — explicitly NOT a theorem.** Prove: exact solver agrees across many
  ban sets at L==H positions. Falsify: one L==H position whose real-history
  value differs. (This is C2.)
- FP3: iteration converges in finite sweeps. Prove: zero-change sweep terminates.

**Value-correctness (C):**
- C1: fresh-start values correct as fresh-start values. Prove: exhaustive
  comparison vs independent exact solver.
- C2: single-score (L==H) positions are history-independent. (= FP2.)
- C3: bracket [L,H] bounds real-game score for any history. Prove: range-aware
  player zero leaks. Falsify: one valid game outside [L,H].
- C4: fresh-start == real-game. (FALSE for ko-sensitive by construction; TRUE
  for single-score only if C2 holds.)

**Finisher/engine (F):**
- F1: writes-on finisher (ko_ref guard) sound. (Falsified at 3×2; ADR-0013.)
- F2: bracket-guided finisher (ADR-0010) sound. Prove: engine-vs-engine or
  auditor + bracket containment.
- F3: writes-off (soundish) sound. Prove: #2 auditor zero violations.
- F4: KM dependency-guarded memo sound. Prove: auditor + byte-identical to
  writes-off.

**Play (P):**
- P1: anchor match implies real-game correctness. (FALSE for ko-sensitive.)
- P2: symmetry PASS implies correctness. (Necessary, not sufficient.)
- P3: fresh-start player plays real-game value. (FALSE — the leak.)

**Ruleset (R) — settled foreclosures, instantiated per size:**
- R1: PSK exact-solve intractable. R2: score-on-cycle = PSK intractability.
- R3: kill-X% does not collapse ko-sensitive region.

**Measured (M) — data, not knowledge:**
- M1: ko-sensitive fraction. M2: sweep count. M3: finisher node cost.

**The dependency tree (why this is a tree):**
```
certified-core-sound ──► C2 ──► FP2  [UNPROVEN AT EVERY SIZE — the single point of failure]
bracket-sound ────────► C3 ──► FP1, FP2
finisher-sound ───────► F2 ──► F3, FP2
fresh-start-correct ──► C1 ──► [needs independent exact solver]
```

## 3. The 4×4 tree — current honest status

Every status is *at 4×4*, from 4×4 evidence. Nothing inherited.

| claim | status @ 4×4 | evidence | blocker |
|---|---|---|---|
| S1 | PROVEN | bijection verified through 4×4 | — |
| S2 | NOT-TESTED @ 4×4 | falsified only at 3×3 | re-run |
| S3 | PROVEN | 24,318,165 matches OEIS; cross-validated | — |
| S4 | PROVEN | part of S3 | — |
| FP1 | NOT-TESTED | B1 ran only 2×2/3×2/3×3 | **B1-4×4** |
| FP2/C2 | CLAIMED (unproven) | ADR-0009 honesty clause; never proven anywhere | **C2-probe** |
| FP3 | PROVEN | 19 sweeps, zero-change terminating | — |
| C1 | SUPPORTED | anchors + symmetry + spot checks (no exhaustive ground truth) | exact solver intractable at 4×4 |
| C3 | NOT-TESTED | E2 not run at 4×4 | **E2-4×4** |
| C4 | FALSE (ko-sensitive) | structural | — |
| F1 | NOT-TESTED @ 4×4 | 3×2 conviction is a 3×2 fact | **auditor-4×4** |
| F2 | anchor-validated only | empty 4×4 = +2; 0 bracket-fails; symmetry PASS (consistency, not soundness) | — |
| F3 | NOT-TESTED (sampled, incomplete) | RETRO_CONSIST4 400-node sample did not finish | **bounded auditor-4×4** |
| F4 | NOT-TESTED @ 4×4 | KM validated at 3×2/3×3/4×3 only | — |
| P1 | FALSE (structural) | anchor = fresh-start, not real-game | — |
| P2 | necessary-not-sufficient | symmetry PASS ≠ correctness | — |
| P3 | FALSE (the leak) | fresh-start player is history-blind | — |
| R1 | PROVEN | PSK intractable (measured at 2×2; 4×4 structural) | — |
| R2 | PROVEN @ 2×2/3×2 | byte-identical state counts; 4×4 by structural identity | — |
| R3 | FALSIFIED @ 4×4 | RETRO_KILLCENSUS: kill-X% makes ko-sensitive region WORSE | — |
| M1 | 21.32% (10,367,922 / 48,636,330) | measured | — |
| M2 | 19 sweeps | measured | — |
| M3 | 649,517 reps, 6.1 min, ~1,663 nodes/rep | measured | — |

**The honest summary:** 4×4 structure is solid; 4×4 values are NOT. C1 is only
supported, C2 is claimed-and-likely-untestable, C3 is untested (suspect false),
and the finisher (F1/F3) was never auditor-verified at 4×4. The "complete 4×4
oracle" is a *computed* table, not a *proven* one. **The 4×4 tree is mostly
red. That is the honest starting position.**

## 4. Experiment plan (ordered by cost ↑, foundational-dependency ↓)

### E0 — B1-4×4: fixpoint verification [targets FP1]
- **What:** V0+V1 Bellman equations at every legal non-settled 4×4 position;
  re-converge from -N+1 and +N with zero-change confirmation.
- **Cost:** cheap (table reads after converge; converge ~495s).
- **Acceptance:** zero violations; re-converges hit zero-change at canonical.
- **Proves:** FP1 at 4×4. **Fail → STOP** (fixpoints wrong, everything void).

### E1 — E2sanity-4×4: policy wiring check [targets the E2 instrument]
- **What:** range-aware self-play with trivially-valid bounds (lo=-N, hi=+N).
- **Cost:** low (self-play, no converge).
- **Acceptance:** zero leaks. **Fail → FIX INSTRUMENT**, redo E1.

### E2 — E2-4×4: range-aware self-play [targets C3 — the crisis question]
- **What:** in-memory converge 4×4; both players range-aware (Black max lo,
  White min hi) with real PSK history; track promises; count leaks.
- **Cost:** medium-high (converge ~495s + self-play; measure tractability
  first with a 50-game probe before scaling).
- **Acceptance:** zero leaks → C3 supported at 4×4. Any leak → C3 falsified.
- **Expected (hypothesis, NOT evidence):** leaks, by analogy to 3×3 — but
  3×3 is a 3×3 fact; 4×4 must be measured.

### E3 — Auditor-4×4: writes-off self-consistency [targets F3, F1]
- **What:** #2 auditor (minimax-identity under fixed history) at 4×4, on a
  bounded deepest-first sample that completes. Run writes-on AND writes-off.
- **Cost:** high (prior 400-node sample ran ~14 min; needs tractable design).
- **Acceptance:** writes-off = zero violations on sample; writes-on = expected
  violations (confirming F1 buggy at 4×4 on its own evidence).

### E4 — C2-4×4: single-score history-independence [targets C2/FP2]
- **What:** exact solver at deep L==H 4×4 positions under multiple ban sets.
- **Cost:** unknown (tractability probe first; exact solver intractable from
  empty but may be tractable from ≥8-stone positions).
- **Acceptance (tractable):** zero value drift across ban sets → C2 supported
  (sampled). Any drift → C2 falsified at 4×4.
- **Acceptance (intractable):** C2 marked INTRACTABLE-TO-TEST-DIRECTLY; core
  soundness rests on FP2 alone (the unproven honesty clause). Honest.

### E5 — Anchor battery-4×4, reframed [targets P1, consistency]
- **What:** re-run anchor/symmetry/bracket-containment, labelled as
  consistency checks (not soundness proofs).
- **Cost:** low (standing battery).

### Decision tree
```
E0 (FP1) ── fail? STOP
          └ pass ─► E1 (wiring) ── fail? FIX, redo
                               └ pass ─► E2 (C3)
                                            leak?  C3 FALSE → deliverable = core-only (contingent on C2)
                                            no leak? C3 SUPPORTED → E3 (F3) → E4 (C2)
E3 (F3, sampled) ── always run
E4 (C2) ── tractable? C2 sampled-supported or falsified
        └ intractable? C2 = INTRACTABLE; core = conditional on FP2 (honest)
E5 (anchors) ── alongside, as consistency labeling
```

## 5. The three possible outcomes (what "solving 4×4" means)

1. **Full solution** — C2 and C3 both hold at 4×4: every (position, side) gets
   a single exact score or a sound [L,H] range.
2. **Core-only solution** — C2 holds, C3 fails: only L==H region is soundly
   shippable. Ko-sensitive region labelled "fresh-start fixpoint, NOT a real-game bound."
3. **No solution** — C2 fails: even the certified core is history-dependent;
   the position-to-score table concept collapses until a different
   representation (full-history states or loopy CGT) is built.

## 6. What we explicitly do NOT do

- Do NOT inherit small-board proof status into the 4×4 tree.
- Do NOT run new small-board experiments to support 4×4.
- Do NOT relitigate foreclosures (PSK, score-on-cycle, kill-X%, ko_ref bug).
- Do NOT assert the 4×4 certified core is "proven" until C2/FP2 at 4×4 resolves.
- Do NOT build 5×5 on the 4×4 tree until 4×4's C2/C3 have a status.
- Do NOT overwrite `data/oracle-4x4.wzo` or any artifact; new artifacts go to
  new paths and are re-hashed first.

## 7. Risk register (4×4-specific)

- **R1:** writes-off 4×4 intractable → deliverable degrades to core + bracket.
- **R2:** KM-deps unsound at 4×4 (fingerprint saturation) → fallback to
  writes-off, then core-only.
- **R3:** C2 falsified at 4×4 → even the core is unsound; re-theorize.
- **R4:** existing 4×4 artifact irreproducible → re-run from scratch.

## 8. Directory layout (proposed)

```
docs/boards/
  CONCEPTS.md              # the cross-size concept-inventory (definitions only)
  4x4/
    EPISTEMIC.md           # the 4×4 tree (truths, falsifications, hypotheses, unknowns)
    experiments/           # per-experiment specs + findings (e0-b1.md, e2-c3.md, ...)
    tables/                # measured tables (ko-sensitive region census, fixpoint checks, etc.)
  2x2/EPISTEMIC.md         # mined from existing research (no new runs)
  3x2/EPISTEMIC.md         # mined
  3x3/EPISTEMIC.md         # mined (includes E1/E2/E3/B1 findings)
```

Each `EPISTEMIC.md` is self-contained: a fresh agent reading only that file
can audit that board size's knowledge state. Trees reference each other only
for cross-size observations ("same claim-type, differently resolved"), never
for proof.

## 9. First concrete steps (if approved)

1. **Create `docs/boards/CONCEPTS.md`** — the inventory in §2 (no status).
2. **Create `docs/boards/4x4/EPISTEMIC.md`** — the 4×4 tree in §3 (honest
   status, all red/unknown nodes labelled).
3. **Mine small-board trees** from existing research (no new runs; just
   re-organize findings into the per-size format).
4. **Spec E0 (B1-4×4)** — the fixpoint check, cheapest foundation. Then
   implement and run.
5. **Spec E1 + E2-4×4** — wiring check + C3 crisis test, with a 50-game
   tractability probe before scaling.

Steps 1-3 are documentation only (no engine edits, no runs). Step 4 is the
first experiment. A context-cleared agent can resume at any step by reading
the relevant `EPISTEMIC.md` + experiment spec.
