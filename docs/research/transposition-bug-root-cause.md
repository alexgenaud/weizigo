# Root cause: the depth-7 transposition "overwrite" bug

Commit `39dbe4a` was titled "Bugs in black white symmetries". The measurement
harness (`src/measure.zig`) reproduced and localized it: 5×5 depths 1–6 are
clean; depth 7 trips `set_game_score` "overwriting … score old=−1 with new=3"
— one canonical `(blind, color, seq)` key resolving to two different scores.

## It is NOT a black/white symmetry bug

Every collision dump showed `inverse=true`, but that's incidental (that orbit's
canonical form is an inverse one) and the inversion arithmetic is consistent
(`store_C == −raw·color`). The real cause is repetition + horizon.

## Evidence

Tracing every write to one colliding key within a single depth-7 search:

```
max_depth=7  ply=7  raw_score= 1  store_C=-1   ← board evaluated as a LEAF at ply 7
max_depth=7  ply=5  raw_score=-3  store_C= 3   ← SAME board, 2-ply lookahead at ply 5
```

The ply-5 and ply-7 boards were **byte-identical snapshots** (black at 0,3,9;
white at 8,14; only army *labels* differed = flag renumbering).

## Mechanism (two coupled defects)

- **P1 — repetition not prevented.** Ko/superko is not implemented
  (`KoRepeat` is an unused enum member; `armies_from_move` never returns it).
  So a position can appear **inside its own search subtree**: DFS reaches board
  B at ply 5, `get(B)` misses, recursion starts; within B's own subtree a
  capture/recapture cycle reaches B again at ply 7; `get(B)` still misses
  (B not stored until its ply-5 call returns) → B is searched and stored twice.
- **P2 — horizon-limited value in a depth-agnostic table.** In a depth-7
  search, B at ply 7 is a leaf (`pos_score` = −1) while B at ply 5 has 2 plies
  of lookahead (= 3). Different horizon → different value; the key has no depth,
  so the two writes collide.

**Captures are the enabler**: they decouple stone-count from ply-depth, letting
the same low-stone board recur at different plies. (Confirms the "more frequent
with captures" intuition; first visible at depth 7 = a shallow + a 2-ply-deeper
occurrence of the same 5-stone board within one search.)

## What is / isn't stored (facts)

- Key = `(lowest.blind, lowest.seq)`, table by side `color`, sign by
  `is_inverse` (`minimax.zig` get/set_game_score).
- Value = `2·diff − komi` from the snapshot + side. **No capture count, no ko,
  no depth.** For area scoring, capture count is correctly not needed.

## Fix

- **P2** → score at true settled terminals (Benson + area), depth-independent.
- **P1** → positional superko (finite, acyclic-enough tree).
- Remaining subtlety → GHI (`ghi-and-superko.md`).
See `decisions/0004`.
