# QA-027 — 4×4 re-run evidence

**Task: T129 · Role: worker · Model: DSPro · Date: 2026-07-31**

## Artifact

```
data/oracle-4x4-basicko-tie-area.wzo
SHA256: edd9f68ef243f67de21152432f9e8f521536317527d425208e6901f90b11c0cc
Size: 258,280,358 bytes
Produced by: T113 (mechanical serialization of EXP-6 fixpoint)
Rules: basic ko + TIE=0, area scoring, komi 0
Root: V=+1 (B), V=-1 (W), bracket=1 (both)
Table: 43,046,721 slots, 24,318,165 valued (56.49%), 18,728,556 UNDEF
Bracket slots: B=981,071, W=981,071 (2.28% each)
```

## Instrument

```
Source: src/t129_exp7_4x4.zig
Build: tools/runner -- zig build-exe -O ReleaseFast src/t129_exp7_4x4.zig -femit-bin=/tmp/t129_exp7_4x4
Binary: /tmp/t129_exp7_4x4 (ReleaseFast, x86_64)
```

## Runs

| run | goban | policy | games | seed | result |
|---|---|---|---|---|---|
| acceptance | 4×4 | oracle | 2,000 | 20260728 | **10.71%** certified (3,000/28,000 fresh-start nodes) |
| acceptance | 4×4 | oracle-rt | 2,000 | 20260728 | **10.71%** certified (3,000/28,000 fresh-start nodes) |
| acceptance | 4×4 | random | 2,000 | 20260728 | 27.84% certified (11,746/42,186 fresh-start nodes) |
| acceptance | 4×4 | mixed | 2,000 | 20260728 | 22.12% certified (7,291/32,964 fresh-start nodes) |
| calib good | 3×3 | oracle | 2,000 | 20260728 | **100.00%** certified (8,000/8,000 nodes) |
| calib bad-1 | 4×4 PSK perturbed | oracle | 100 | 20260728 | 96.15% certified (1,250/1,300) — **perturbation detected** |
| calib bad-2 | 4×4 PSK unmodified | oracle | 500 | 20260728 | 100.00% certified (6,500/6,500) — PSK table passes new-rule check |

## Raw outputs

- `stdout-2026-07-31.txt` — 4×4 acceptance runs (all four policies)
- `calibration-known-good-3x3.txt` — 3×3 calibration (100%)
- `calibration-known-bad-perturbed.txt` — perturbed PSK root detection

## Methodology notes

1. **Bellman check only on fresh-start states (passes=0, ko=none).** The artifact
   stores values for (board, side, passes=0, ko=none) only. Non-fresh-start states
   (passes=1 after a pass) are skipped in the Bellman statistics. Total visited
   nodes and fresh-start-checked nodes are both reported.

2. **Pass-child value computation.** For children with passes=1 (after a pass),
   the opponent can pass again to end the game at area_score. The value is
   computed as max(area, artifact_V) for Black or min(area, artifact_V) for White.
   This is exact under the two-pass termination rule.

3. **Ko-approximation.** For children with ko≠none (after a basic-ko capture),
   the artifact's ko=none value is used. This may cause false-positive violations
   if the ko restriction changes the true value. However, the root-level violation
   (and many others) do not involve ko at all.

4. **Flag-read fraction is non-degenerate.** The artifact's fb/fw columns store
   bit 0 = (L<H) — the bracket indicator. Under oracle self-play, 8.82% of
   visited nodes are bracket-valued. This is NOT all-zero, so the flag is not
   degenerate under this rule, contrary to the brief's expectation.
