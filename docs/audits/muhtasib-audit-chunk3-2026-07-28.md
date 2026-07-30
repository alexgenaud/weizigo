# Muhtasib audit — Chunk 3: EXP-3 basic-ko state-space census reproduction

**Auditor:** Kimi-k2.7 Auditor (Muhtasib role).  
**Date:** 2026-07-28  
**Scope:** reproduce the EXP-3 reachable `(board, side, ko_point)` census and verify the headline numbers, calibration cases, and the stated caveat about B-to-move reachability.

## Method

Build `src/kostate_census.zig` in isolation per the dispatch provenance, run the standard detector on 3×3, 4×3, and 4×4, run the three 3×3 calibration detectors (`none`, `every_capture`, `every_move`), and run the 4×4 `none` calibration. Compare every number against `docs/research/kostate-census-2026-07-28.md` and `docs/evidence/GLOBAL.H1-CENSUS/PROVENANCE.md`.

## Build

```bash
cd /Users/alex/Project/Zig/weizigo
ZIG_LOCAL_CACHE_DIR=/tmp/weizigo-zigcache-exp3 \
ZIG_GLOBAL_CACHE_DIR=/tmp/weizigo-zigcache-exp3 \
zig build-exe -O ReleaseFast --name weizigo-exp3-minimax src/kostate_census.zig
```

## Commands and results

### Standard detector — headline numbers

| goban | command | legal positions | (a) triples | (b) addresses | sparse ratio | sweeps | wall time observed |
|---|---|---:|---:|---:|---:|---:|---|
| 3×3 | `./weizigo-exp3-minimax 3x3 standard on 64` | 12,675 | 22,736 | 13,997 | 7.111213% | 16 | <1 s |
| 4×3 | `./weizigo-exp3-minimax 4x3 standard on 64` | 321,689 | 638,266 | 375,281 | 5.431980% | 25 | ~1 s |
| 4×4 | `./weizigo-exp3-minimax 4x4 standard on 64` | 24,318,165 | 51,419,046 | 29,497,329 | 4.030823% | 29 | ~2 min |

### Calibration — ko-disabled (`none`) detector

| goban | command | (a) triples | (b) addresses | notes |
|---|---|---:|---:|---|
| 3×3 | `./weizigo-exp3-minimax 3x3 none on 64` | 20,888 | 12,149 | matches published caveat |
| 4×4 | `./weizigo-exp3-minimax 4x4 none on 64` | 45,734,854 | 23,813,121 | matches published caveat |

### Calibration — broken detectors at 3×3

| detector | command | (a) triples | (b) addresses | direction vs standard |
|---|---|---:|---:|---|
| `none` | `./weizigo-exp3-minimax 3x3 none on 64` | 20,888 | 12,149 | below (8% under) |
| `every_capture` | `./weizigo-exp3-minimax 3x3 every_capture on 64` | 36,332 | 26,127 | above (60% over) |
| `every_move` | `./weizigo-exp3-minimax 3x3 every_move on 64` | 41,768 | 41,767 | above (84% over) |

## Verdicts on specific claims

### Claim A: "4×4: 51,419,046 reachable triples; 29,497,329 distinct addresses"

**Status: VERIFIED.** Reproduced exactly: 51,419,046 triples, 29,497,329 addresses, 4.030823% sparse ratio, 29 sweeps. 4×4 legal-position count also matches: 24,318,165.

### Claim B: "3×3: 22,736 reachable triples; 13,997 addresses; 4×3: 638,266 triples; 375,281 addresses"

**Status: VERIFIED.** Reproduced exactly.

### Claim C: "Legal-position counts match OEIS A094777"

**Status: VERIFIED.** 3×3 = 12,675; 4×4 = 24,318,165; 4×3 = 321,689 (project's own ground truth). All match.

### Claim D: "The calibration-2 caveat: the dispatch's expected `(position, side)` slot count is the total addressable space, not the B-to-move reachable space"

**Status: VERIFIED.** The no-ko (`none`) runs gave:
- 3×3: 20,888 reachable triples (≈ 2 × 10,444, not 25,350).
- 4×4: 45,734,854 reachable triples (not 48,636,330).

This matches the published explanation: the walk seeds both `(empty, B, none)` and `(empty, W, none)`, so its no-ko count is approximately twice the B-first alternating-play reachable `(position, side)` set. The research doc states this honestly and prominently.

### Claim E: "Broken detectors move the count in the predicted direction and magnitude"

**Status: VERIFIED.** At 3×3:
- `none`: −8% vs standard.
- `every_capture`: +60% vs standard.
- `every_move`: +84% vs standard.

The counter does not return the same number for right and wrong detectors; the standard detector sits between the under- and over-counting extremes, as expected.

### Claim F: "Dense addressing at 4×4 is GO under the D3 placeholder (≤ 32 GB)"

**Status: VERIFIED.** The standard 4×4 artifact would be 176,983,974 B (~177 MB), which is 0.69× the current PSK 4×4 artifact and ~90× under the 32 GB placeholder. The passes-folded version is 353,967,948 B (~354 MB), still ~90× under the placeholder.

### Claim G: "No engine file touched; standalone except std"

**Status: VERIFIED by source inspection.** `src/kostate_census.zig` reimplements `pos_from_move` and `is_legal` and imports only `std`. It does not import `retro.zig`, `oracle.zig`, `rules.zig`, or `solve.zig`.

## Caveats

1. **This is a state-space census, not a solve.** It counts reachable states under basic ko; it does not compute values or prove tractability of a full retrograde build. The D3 placeholder is about addressing cost, not build time.
2. **Per-goban independence applies.** The 4×4 GO result does not imply 5×5 will fit the same budget.
3. **The `passes` dimension is folded by simple doubling in the report.** The code's `passdim` flag sets `triples_with_passes = triples * 2`. This is a sizing estimate, not a separate measurement of the reachable `(board, side, ko, passes)` set. The research doc presents it as an upper bound; it should not be read as an exact reachable count.

## Overall chunk verdict

All headline EXP-3 numbers are **VERIFIED** by independent reproduction. The calibration cases behave as documented, and the calibration-2 caveat is honestly stated. The addressing GO/NO-GO conclusion for 4×4 is **VERIFIED**. The claim that the tool is standalone and touches no engine file is **VERIFIED** by source inspection.
