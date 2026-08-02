# engine-unification — pass0 accept

```
Task: T226 · Role: sprint manager · Model: not stated at dispatch · Date: 2026-08-02
Revision: 1 · Status: FINAL
```

## Goal recap

One tested rule engine, used by everything that claims a result. Pass0 delivers
measurement and the instruments to trust it. Pass1 delivers unification.

## Achieved

### P0 — acceptance-check fixes (T227)
Four defects in `src/managent/main.zig` fixed:
1. Signal-killed commands reported PASS — switch on `Child.Term` now catches
   `.signal`/`.stopped`/`.unknown`
2. `deliverables=` swallowed subsequent `key=` tokens — truncates at next key
3. `--skip-acceptance` accepted empty reason — rejected
4. `acceptance`/`skip_acceptance_reason` not serialized — added to `writeState`

Regression tests: `tools/regression-T227.sh`, 3/3 passing, byte-identity guard PASS.
Substrate isolation: `MANAGENT_STORE` env var, tests use isolated store.
Build audit (T254/DSPro): PASS — all four defects independently verified.

### P1 — differential harness (T252)
`src/differential.zig` with correct per-board implementation comparison metric.
Three controls:
- Null control: same impl twice → perfect agreement (PASS)
- Seeded-defect: mutant caught with witness values (PASS)
- Known-bad: three impls, one disagrees, witnesses verified (PASS)

Design audit (T255/DSPro): PASS — four non-blocking findings addressed.
Build audit (T256/DSFlash): PASS — known-bad recalibration confirmed non-vacuous.

### A4 — clone deletions
- `genericAreaScore` in exp6_solve.zig → delegates to `rules.areaScore()`
- `genericNeighbors` in exp6_solve.zig → delegates to `rules.neighborsRt()`
- Runtime dispatchers added to rules.zig with TDD tests (57/57 pass)
- Smoke suite: `tools/smoke.sh` (3 checks, <1s)

### P2 — agreement matrix (T257 + manual completion)
All five operations compared at 2×2 (81), 3×2 (729), 3×3 (19,683):

| operation | 2×2 | 3×2 | 3×3 |
|---|---|---|---|
| area_score | 81/81 | 729/729 | 19,683/19,683 |
| legality | 81/81 | 729/729 | 19,683/19,683 |
| capture | 81/81 | 729/729 | 19,683/19,683 |
| double_pass | 81/81 | 729/729 | 19,683/19,683 |
| encode_decode | 81/81 | 729/729 | 19,683/19,683 |

Matrix files: `docs/evidence/GLOBAL.DIFFERENTIAL/matrix-*-2026-08-01.md`

## Disagreements

None. All implementation pairs agree on all boards at all sizes. This is
expected post-A4 clone deletion — the surviving pairs share underlying
implementations.

## ADR-0020 gap adjudication (T287, 2026-08-03)

**The check was wrong, not the solver.** The 716 L≠H gaps at 2×2 (44% of
non-terminals) are the **genuine fixpoint** — 0 Bellman violations, 0 L>H
violations, 0 colour-inversion violations, verified by an independent Python
re-run (`docs/audits/adr0020-gap-adjudication.md`). Under ADR-0020 E3, L<H
*is* the honest output where the state alone does not determine the value.

**The pass condition "L==H on all reachable non-terminals" is unsound** — it
demands the solver contradict its own bracket semantics. The correct ADR-0020
pass condition is: **(C1)** 0 Bellman violations over reachable non-terminals;
**(C2)** 0 fixpoint-vs-truncation disagreements on the 24-state standing
fixture (172 reachable non-terminals at 2×2 — this passes, verified T102/T103).

Registered as `ADR-0020.LH-CORRECT` (PROVEN) and `ADR-0020.VERIFY-PASS`
(CLAIMED) in `docs/epistemic/CLAIMS.md`.

## What was promoted
- `Rules(w,h).area_score` — surviving instance; clone deleted from exp6_solve
- `Rules(w,h).neighbors` — surviving instance; clone deleted from exp6_solve

## What was demoted to fixture
- `exp6.genericAreaScore` — now a thin delegating wrapper
- `exp6.genericNeighbors` — now a thin delegating wrapper

## What could not be settled
- ADR-0020 gap interpretation (escalated)
- 4×4/4×3 sampling (deferred to pass1 — harness adapters exist for extension)
- Remaining clones: `genericChainCaptured`, `genericIsLegal`, `genericPosFromMove`
  in exp6_solve.zig still contain duplicate logic; deletion deferred to pass1
- `exp7_census.zig`, `t129_exp7_4x4.zig`, `exp6_hchain_audit.zig` all contain
  their own `genericAreaScore` clones — noted, not touched (analysis files)

## Pass1 tasks
1. Adjudicate ADR-0020 gap finding
2. Delete remaining clones (chain_captured, is_legal, pos_from_move)
3. Wire 4×4/4×3 sampling
4. Migrate all callers to unified engine
5. Full audit chain per sprint.md
