# engine-unification — pass0 spec

```
Task: T226 · Role: sprint manager · Model: not stated at dispatch · Date: 2026-08-01
Revision: 1 · Status: PROPOSED
Source: draft-spec.md (Orcha, 2026-08-01)
```

## Goal

One tested rule engine, used by everything that claims a result. Every duplicate
implementation kept as a test fixture. Agreement measured **before** anything is
promoted, moved, or deleted.

Pass0 delivers the measurement and the instruments to trust it. Pass1 delivers
the unification.

## Why pass0 stops at measurement

The draft spec's inbox (T221–T225) was abandoned by Orcha. The instruments this
sprint depends on — a correct acceptance check and a differential harness — do
not exist. Building them is a sprint-internal prerequisite, and they must be
verified before they are used to verify anything else.

More fundamentally, the draft spec states the rule and the brief reinforces it:
*measure before you touch*. Moving code before comparing implementations is the
exact mechanism that produced the passes bug (T192). Pass0 produces the agreement
matrix; pass1 acts on it.

## Scope — pass0

**In:**
- Fix the acceptance-check defect (`.exited` reads 0 on signalled children —
  T221 Defect 1). The fix lives in `src/managent/main.zig`.
- Fix the `deliverables=` parser swallowing subsequent `key=` tokens (T221
  Defect 2).
- Require non-empty reason for `--skip-acceptance` (T221 also-in-scope).
- Regression tests for all three, red before green.
- Differential harness: compare every available implementation of a given
  operation, at every enumerable goban size, and report agreement.
- Agreement matrix populated for these operations (priority order):
  1. **Double-pass / pass application** — most size-invariant rule in Go;
     pass-encoding error survived to 518 MB 4×4 artifact
  2. **Area score** of a terminal position
  3. **Legality** of a move
  4. **Capture** resolution
  5. **Key encode/decode** round-trip (WZO1 + WZO2)
- ADR-0020 truncation-agreement fixture: verify the 24 2×2 states are a
  standing agreement fixture (gap = 0/172 reachable non-terminals).
- Every disagreement reported as a witness input, not fixed.

**Out (deferred to pass1):**
- Adjudication of disagreements
- Promotion of one implementation per operation
- Demotion of others to fixtures
- Caller migration
- Any new features
- Claims, evidence, and the epistemic tree (sequenced after the sprint by the
  human)

## Operations under measurement

| operation | implementations |
|---|---|
| pass application / double-pass | `exp4_solve.apply_pass3`, `exp6_solve.apply_pass32` / `apply_pass` / `apply_pass4`, `oracle_v2_build` pass encoding, `oracle_v2_consumer_load` pass decoding, `rules.Rules.pos_from_move` |
| area score | `exp4_solve.area_score3`, `exp6_solve.genericAreaScore`, `score.Score.chinese_area`, `terminal.area_score` |
| move legality | `exp4_solve.is_legal3`, `exp6_solve.genericIsLegal`, `rules.Rules.pos_from_move` (returns error), `oracle_v2_build` place logic |
| capture / chain capture | `exp4_solve.chain_captured3`, `exp6_solve.genericChainCaptured`, `rules.Rules` (implicit in pos_from_move), `state.update_captures` |
| state encode/decode | `exp6_solve.encodeState4` / `decodeBoard4` etc., `oracle_v2_build` key encoding, `oracle_v2_consumer_load.decodeLin`, `state.view_from_pos` / `pos_from_view` |

This list may grow as the differential harness discovers additional overlap.

## Non-goals (this sprint)

- New features of any kind
- Changes to existing claims, evidence files, or CLAIMS.md
  (new evidence under `docs/evidence/GLOBAL.DIFFERENTIAL/` is in scope)
- Performance optimisation
- Any change to `src/oracle_v2_build.zig` that is not strictly required for
  the differential harness to load it (T212 ran; the artifact is valid; the
  build path is stable)

## Acceptance criteria

- **AC-S1:** `managent done` rejects a task whose `acceptance=` command was
  killed by a signal (SIGKILL, SIGTERM, etc.) — does not report PASS.
- **AC-S2:** `managent done --skip-acceptance ""` is rejected (empty reason).
- **AC-S3:** `deliverables=` in the meta header does not swallow subsequent
  `key=` tokens.
- **AC-S4:** The differential harness has its own tests (TDD) and at least one
  known-bad fixture that it catches. The known-bad fixture must be a synthetic
  disagreement (two hand-written functions that differ on the same input), not
  a live implementation — live faults get fixed and the check then silently
  tests nothing.
- **AC-S5:** Agreement matrix populated for double-pass, area score, legality,
  capture, and key encode/decode at 2×2, 3×2, 3×3. 4×4 sampled within a
  120-second budget (sample count ≥ 10,000 random legal-ish positions, seed
  fixed for reproducibility).
- **AC-S6:** ADR-0020 truncation-agreement verified: the 24-state standing
  agreement fixture produces gap = 0 (all 172 reachable non-terminals at 2×2
  agree between loopy-game fixpoint and first-revisit truncation values).
- **AC-S7:** Every disagreement in the matrix has a concrete witness input.
- **AC-S8:** Regression tests exist for the three acceptance-check defects and
  pass (`zig test src/managent/main.zig` or equivalent).
- **AC-S9:** The differential harness and acceptance fixes are committed
  separately, each with its own `managent done` verdict.

## What reaches the human

A blocker I cannot resolve; a ruling only he can make; evidence that we are
spinning. Not progress reports.
