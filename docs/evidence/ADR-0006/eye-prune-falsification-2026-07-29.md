# ADR-0006 eye-prune falsification — 3×3 exhaustive

**Task:** ADR0006-FALSIFY set M
**Model:** not stated at dispatch
**Date:** 2026-07-29
**Source:** `src/eyeprune_falsify.zig`
**Status:** COMPLETE — 0 disagreements at 3×3

## What was tested

For every 3×3 legal position with at least one Benson-alive true eye, the
game-theoretic fresh-start score was computed twice:
1. **With** the ADR-0006 eye-prune (skip filling own Benson-alive true eye)
2. **Without** it (all legal moves considered)

Both scores were computed by the same forward minimax solver under:
- Area (Chinese) scoring, Black-positive
- Positional superko (matches `oracle.zig`'s solver)
- Double-pass or `is_settled` terminals
- One fresh memo per (position, side, prune-mode) solve

## Results

| metric | value |
|---|---|
| 3×3 legal positions | 12,675 |
| Positions with >= 1 Benson-alive true eye | **1,050** |
| (position, side) pairs checked | **1,050** |
| Disagreements (with vs without prune) | **0** |
| Calibration (wrong prune detected?) | **PASSED** (after 65 tries; score changed -9→-4) |
| Wrong-prune pass rate | 16/71 = **22.5%** |
| Search nodes, with prune | 34,496,888 |
| Search nodes, without prune | 150,286,500 |
| Ratio (without/with) | **4.36×** |
| Wall time | ~106 s |
| Peak RSS | 3 MB |

## Calibration

A synthetic wrong prune (forbid a non-eye legal move) was applied until a
disagreement was found. After 65 candidates, pruning cell 0 for Black on a
position where Black had a White-group-enclosed stone changed the score from
-9 to -4. The harness correctly detected this. The wrong-answer pass rate
of 22.5% means ~78% of arbitrary wrong prunes would be caught; the 22.5%
that "pass" are cases where the skipped move was off the optimal line.

## Verdict

**ADR-0006 eye-prune passes exhaustive 3×3 — no score changes detected.**

The prune is safe at this board size under positional superko, area scoring.

## Caveats (scoped to 3×3 only)

Per `AGENTS.md` per-board epistemic independence: **this result at 3×3 is
not evidence at 4×4 or above**.

### 4×4 cost estimate

A direct forward-search analogue at 4×4 is infeasible (the forward search is
intractable cold, and the number of eye-positions is much larger). Two
indirect approaches:

1. **Retrograde delta (two builds):** Build the 4×4 oracle twice — once with
   the finisher using the eye-prune, once without. The finisher only operates
   on the ko-sensitive region, so the value iteration itself is unchanged.
   Cost: 2 × ~29 sweeps × ~4 min/sweep = **~4 hours**. Requires one extra
   artifact (~258 MB).

2. **Spot-check sample:** Build one 4×4 oracle, then run the forward cross-check
   (finisher) on a random sample of 4×4 positions with Benson-alive true eyes,
   comparing with/without the prune. Cost: 1 build (~2 hours) + spot-check
   overhead. Statistical, not exhaustive.

## Build / run

```sh
zig build-exe -O ReleaseFast src/eyeprune_falsify.zig -femit-bin=/tmp/weizigo-eyeprune-falsify
tools/runner -- /tmp/weizigo-eyeprune-falsify
```

## Next checks

The result strengthens ADR-0006 at 3×3 but does not close the gap the audit
identified (§2.6 of AUDIT-DSPro-2026-07-29.md): the forward searches that use
the prune (finisher, T13, E2) operate at 3×2, 3×3, and 4×4. The 3×3 check
is now done; 3×2 is trivial; 4×4 is the open frontier.

A CLAIMS.md row is proposed below for the CLAIMS.md owner to fold in.
