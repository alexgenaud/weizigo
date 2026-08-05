# PROVENANCE — EXP-4: 2×2 and 3×2 under basic-ko + TIE=0

**Task: EXP-4 · Role: worker · Model: DSPro · Date: 2026-07-29**

## Claim IDs

- **2x2.BASICKO-TIE** — fresh-start value of 2×2 empty goban under basic ko + TIE=0 = 0 (PROVEN)
- **3x2.BASICKO-TIE** — fresh-start value of 3×2 empty goban under basic ko + TIE=0 = 0 (PROVEN)

Both proposed; owner `CLAIMS.md` assigns IDs.

## Run command

```
tools/runner -- zig run -O ReleaseFast src/exp4_solve.zig
```

## Output

- `docs/evidence/QA-026/exp4-solve-2026-07-29.stdout` — full run output

## Source

- `src/exp4_solve.zig` — standalone solver; imports `qa023_brute_2x2.zig` for 2×2 state encoding + rules only (no path-enumeration value calls)

## Calibration

**⚠ 2026-07-30 (T125, T102): Brute-force cross-check withdrawn.**
The "brute-force anchors" and "brute-force sample" sections in the stdout
(§2, §7) were produced by a defective evaluator with a successor-buffer
aliasing bug (`src/exp4_solve.zig:555-594`, T102 audit). All 24 mismatches
were an artifact of the checker; fixpoint and exact FRT agree on all 172
reachable non-terminal 2×2 states. The fixpoint results (anchors tested
against the fixpoint, Bellman self-consistency, colour-inversion) are
independently verified by T102 (Zig + Python) and T104 (Python kernel).
See `docs/audits/2026-07-30-audit-2x2-mismatch.md` and `GLOBAL.BRUTE-ALIASING`.

- **Known-good:** 2×2 five-anchor smoke test (empty-B, empty-W, full-B, passes=1, passes=2) — all match expected values **via fixpoint**. The brute-force corroboration in the stdout §2 is withdrawn
- **Known-bad 1:** PSK vs new-rule root comparison — fixpoint root=0, PSK root=+1, delta=1 (non-zero ⇒ gate distinguishes rulesets)
- **Known-bad 2:** 2×2 state perturbation test — L value perturbed; detection confirmed via value change (note: the perturbation target idx was on a state where V=0 and perturbation of L by +1 did not change V — this is a calibration weakness, see report)

## Acceptance criteria

| criterion | 2×2 | 3×2 |
|---|---|---|
| empty-B root = 0 | +0 ✓ | +0 ✓ |
| empty-W root = 0 | +0 ✓ | +0 ✓ |
| root filled (no UNDEF) | YES, 258/258 | YES, 2586/2586 |
| tie vs scored-0 | TIE (L<0<H, pinned) | TIE (L<0<H, pinned) |
| colour-inversion symmetry | 0 violations / 2430 ✓ | 0 violations / 2586 ✓ |
| Bellman consistency L=Φ(L) | 0 failures ✓ | 0 failures ✓ |
| Bellman consistency H=Φ(H) | 0 failures ✓ | 0 failures ✓ |
