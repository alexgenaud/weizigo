# PROVENANCE — EXP-5 3×3 solve

**Claim ID:** `3x3.BASICKO-TIE` (proposed — owner: CLAIMS.md seat)
**Task:** EXP-5 · Role: worker · Model: DSPro · Date: 2026-07-29
**Parent claim:** QA-026 (scoped to 3×3)

## Acceptance criterion

+9, exactly, for Black on the empty 3×3 goban, plus:
- Root filled (no UNDEF)
- Colour-inversion symmetry exhaustive
- 2×2/3×2 gate passes from same binary
- Tie-vs-score disambiguation

## Run command

```
tools/runner -- zig run -O ReleaseFast src/exp5_solve.zig
```

Build mode: `ReleaseFast` (via runner). Binary: `weizigo-exp5-DSPro` (tmp).
No engine files touched. Caches under `/tmp/weizigo-zigcache`.

## Result

| acceptance | value |
|---|---|
| root (empty, B) | +9 ✓ |
| root (empty, W) | −9 ✓ |
| root filled? | YES (0 UNDEF / 73,758 reachable) |
| anchor matched? | YES |
| gate passed? | YES (2×2=0, 3×2=0) |
| colour-inversion | 0 violations / 73,758 |
| root is TIE? | NO (scored +9, L==H==9) |

## Calibration

**⚠ 2026-07-30 (T125, T102): The brute-force cross-check in stdout §7
("Brute-force cross-check (late positions, few empty points)") was produced by
a defective evaluator with a successor-buffer aliasing bug that affects
every solver in the EXP-4→EXP-7 chain. The 50/50 agreements are not evidence.
The gate chain (2×2/3×2 re-run from this binary), Bellman self-consistency,
and colour-inversion symmetry are independently verified. See
`docs/audits/audit-2x2-mismatch-2026-07-30.md` and `GLOBAL.BRUTE-ALIASING`.**

### Known-good
2×2 root = 0, 3×2 root = 0, re-run from this binary. Both pass. **Brute-force
cross-check in stdout §7 is withdrawn (T102 buffer-aliasing).**

### Known-bad 1 (perturbation)
Perturbed state lin=150 (L==H=9) to L=H=10. Symmetry checker found 2 inversion violations / 73,758. A root-only check would not have detected this — the perturbation was on a non-root state.

### Known-bad 2 (PSK artifact distinction)
Both the PSK artifact and our fixpoint return +9 at the root (coincidence). The PSK artifact has 8,698 ko-sensitive slots (L≠H, bracket-valued) while our fixpoint resolves all states to single values via median-pin. The tables differ below the root; a root-only comparison would be blind to the difference. The structural argument is: any checker that only compares roots would pass both rules, but a state-by-state comparison reveals the divergence.

## Files

- `src/exp5_solve.zig` — standalone solver (this task's file)
- `docs/evidence/QA-026/3x3/exp5-solve-2026-07-29.stdout` — full run output
- `docs/evidence/QA-026/3x3/PROVENANCE.md` — this file
- `docs/research/newrule-3x3-2026-07-28.md` — research write-up
