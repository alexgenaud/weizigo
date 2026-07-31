# ARTIFACT PROVENANCE — 4×4 basic-ko + TIE=0 WZO file

**Task: T126 · Role: DSPro · Date: 2026-07-31**

## File

```
data/oracle-4x4-basicko-tie-area.wzo
Size: 258,280,358 bytes
SHA-256: edd9f68ef243f67de21152432f9e8f521536317527d425208e6901f90b11c0cc
```

SHA-256 verified by T126 (this task) on 2026-07-31 before recording:
```
$ shasum -a 256 data/oracle-4x4-basicko-tie-area.wzo
edd9f68ef243f67de21152432f9e8f521536317527d425208e6901f90b11c0cc  data/oracle-4x4-basicko-tie-area.wzo
```

## Producing task

**T113 (DSFlash)** — QA-026 persist task. EXP-6 produced the fixpoint in memory;
T113 added WZO serialisation to `src/exp6_solve.zig` and wrote the artifact.

## Rules ID

**2** (byte 9 in the WZO1 header) — basic-ko + TIE=0 for long cycles.

| aspect | value |
|---|---|
| Scoring | Chinese area, komi 0 |
| Ko rule | Basic ko (single-point ko recapture prohibition) |
| Long cycles | Value = TIE (= 0) for state repetition on the DFS path |
| Terminal | Two consecutive passes; area score |

The standard `artifact.decode()` rejects rules_id ≠ 1. To read this file, patch
byte 9 to 1 before calling `decode()`.

## State counts

| count | value |
|---|---|
| Total reachable states (all passes) | 147,638,298 |
| Compact states (passes ∈ {0,1}) | 99,133,036 |
| Fresh-start states in compact | 48,505,262 |
| Positions with ≥1 side valued | 24,318,165 |
| Fixpoint sweeps | 31 |
| Peak RSS | 3,629 MB |
| Wall time | ~1 h |

**Root values:** `vb[0] = +1` (L=+1, H=+16), `vw[0] = −1` (L=−16, H=−1).
The MIGOS II anchor +2 is not reproduced under basic ko + TIE=0 — this is a
ruleset difference (basic ko vs PSK), not a bug.

## Format reference

`docs/evidence/QA-026/4x4/wzo-format.md` — full WZO1 header specification,
column layout, flags semantics, and reading code (Python). Written by DSFlash/T113.

## Acceptance

| criterion | result |
|---|---|
| Gate chain (2×2=0, 3×2=0, 3×3=+9) | PASS |
| Fixpoint converged | YES (31 sweeps) |
| Root filled (UNDEF = −128) | YES (V=+1 ≠ −128) |
| MIGOS II anchor (+2) | FAIL (root=+1; ruleset difference) |
| Finisher | Not run |
| Colour-inversion symmetry | Not exhaustively verified |
| CRC-32 payload check | Computed and stored in header (ISO-HDLC) |

## Production command

```
tools/runner --rss-cap-mb 8192 --max-wall 14400 --max-cpu 28800 -- \
  zig run -O ReleaseFast src/exp6_solve.zig
```

## Calibration caveat

⚠ **2026-07-30 (T125, T102):** `src/exp6_solve.zig` imports `qa023_brute_2x2.zig`
for the 2×2 gate and carries the successor-buffer aliasing defect pattern
(`brute_value` at line 824–862). Any brute-force cross-check in this solver
is affected. See `GLOBAL.BRUTE-ALIASING` in `CLAIMS.md`. The fixpoint results
stand independently.

## SHA256SUMS

Recorded in `artifacts/SHA256SUMS` (project root), entry added by T126 on
2026-07-31:

```
edd9f68ef243f67de21152432f9e8f521536317527d425208e6901f90b11c0cc  data/oracle-4x4-basicko-tie-area.wzo
```

## Related

- `docs/evidence/QA-026/4x4/PROVENANCE.md` — the EXP-6 *solve* provenance (this file documents the *artifact*)
- `docs/evidence/QA-026/4x4/wzo-format.md` — WZO1 format specification
- `docs/evidence/QA-026/4x4/exp6-solve-2026-07-29.stdout` — EXP-6 run output
- `src/exp6_solve.zig` — solver with WZO serialisation
- `src/artifact.zig` — WZO1 format (ADR-0011)
- `docs/epistemic/CLAIMS.md` — claim register, row `4x4.BASICKO-TIE`

— DSPro/T126, 2026-07-31
