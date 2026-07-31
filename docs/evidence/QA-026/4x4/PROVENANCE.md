# PROVENANCE — EXP-6: 4×4 under basic-ko + TIE=0

**Task: EXP-6 · Role: worker · Model: DSPro · Date: 2026-07-29**

## Claim IDs

- **4x4.BASICKO-TIE** — fresh-start value of 4×4 empty goban under basic ko + TIE=0 = +1 (NOT the expected +2 anchor). Proposed; owner `CLAIMS.md` assigns ID.

## Run command

```
tools/runner --rss-cap-mb 8192 --max-wall 14400 --max-cpu 28800 -- \
  zig run -O ReleaseFast src/exp6_solve.zig
```

## Output

- `docs/evidence/QA-026/4x4/exp6-solve-2026-07-29.stdout` — full run output

## Source

- `src/exp6_solve.zig` — standalone solver extending EXP-5 to 4×4; imports `qa023_brute_2x2.zig` for 2×2 gate only

## Calibration

**⚠ 2026-07-30 (T125, T102): This solver imports `qa023_brute_2x2.zig` for
the 2×2 gate only, but `src/exp6_solve.zig` itself carries the same
successor-buffer aliasing defect pattern (`brute_value` at line 824-862,
identified in T102 audit §6). Any brute-force cross-check in this solver or
its derivatives is affected. See `GLOBAL.BRUTE-ALIASING`.**

- **Known-good:** gate chain re-run from this binary — 2×2=0, 3×2=0, 3×3=+9. All pass.
- **Known-bad 1 (QA-016):** NOT RUN — deferred (see research note §9)
- **Known-bad 2 (perturbation):** NOT RUN — deferred

## Acceptance criteria

| criterion | 4×4 |
|---|---|
| empty-B root = +2 | +1 FAIL |
| empty-W root = -2 | −1 FAIL |
| root filled (no UNDEF) | YES (V=1 ≠ −128) |
| root filled? anchor matched? gate passed? | YES · NO (+1≠+2) · YES |
| gate chain (2×2=0,3×2=0,3×3=+9) | PASS |
| fixpoint converged | YES (31 sweeps) |
| finisher ran? | NO |
| colour-inversion symmetry | not exhaustively verified |
