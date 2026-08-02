# T267 Key-Agreement Invariant — Evidence

Task: T267 · Model: deepseek-v4-pro · Date: 2026-08-02

## What was done

Added the key-agreement invariant to `src/differential.zig` and wired it into `zig build test`.

Three changes:
1. **`engineKoNewGeneric` replaced** with a real independent implementation using `rules.Rules.neighbors` (the engine path from gtp.zig:717-744), not an alias of `solverKoGeneric`.
2. **Key-agreement invariant** — 8 tests comparing full (colex, side, ko, passes, terminal) keys from engine vs builder construction on game sequences.
3. **`differential.zig` wired into `zig build test`** via `build.zig` test_step.

## Controls

| control | test | result |
|---|---|---|
| Null control (same fn twice) | T267 key-agreement null control | passed: 0 disagreements on self-play |
| Seeded-defect (old ko rule) | T267 key-agreement seeded-defect | caught: old ko disagrees on 3×2 self-play |
| Exhaustive ko scan (old) | ko key (T265): old engine rule disagrees | caught: disagreements on 2×2, 3×2 |
| Exhaustive ko scan (fixed) | ko key (T265): fixed engine rule agrees | 0 disagreements on 2×2, 3×2, 3×3 |
| Human game 1 (4×4) | key-agreement human game 1 | all keys agreed |
| Human game 2 (4×4) | key-agreement human game 2 | all keys agreed |
| Self-play 2×2 | key-agreement 2×2 self-play | all keys agreed |
| Self-play 3×2 | key-agreement 3×2 self-play | all keys agreed |
| Self-play 3×3 | key-agreement 3×3 self-play | all keys agreed |
| Self-play 4×4 | key-agreement 4×4 self-play | all keys agreed |

## 626ec55^ reproduction

The seeded-defect control uses `engineKoOldGeneric` which replicates the T265 pre-fix ko rule (ko set on ANY single capture, without checking liberties==1 and friendly==0). The exhaustive board scan (`oldDisagreeCount`) finds disagreements at 2×2 and 3×2. The game-sequence test (`replayWithOldKo`) additionally finds disagreements on 3×2 self-play.

This confirms: the invariant would have caught the T265 defect before the fix.
