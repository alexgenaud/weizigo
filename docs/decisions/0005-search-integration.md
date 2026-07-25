# 0005 — Search integration: search-to-terminal with superko + Benson

Date: 2026-07-14 · Status: **accepted**

Refinement on implementation: `solve` is **full-board (5×5) only**. Restricting
moves to a sub-region of the 25-cell array is unsound — stones on the region
edge keep phantom liberties into the unplayable empty cells and can never be
captured. So Phase-1 validation uses **near-terminal full-board positions**
(few empty points → small tree, correct geometry) rather than 2×2/3×3 solves.
`x_width`/`y_height` params are dropped.

Ties `terminal.zig` (0004) and `superko.zig` together into a correct search,
replacing the depth-limited heuristic minimax that produced the transposition
bug (`research/transposition-bug-root-cause.md`).

## Goal

Compute the true game-theoretic value of a position under **Chinese/area +
positional superko** (ADR 0003) by searching to a real terminal, so leaf
values are depth-independent and the transposition table is sound.

## New module `solve.zig` (do not mutate `minimax.zig` in place)

The semantics change fundamentally (terminal instead of fixed depth), and many
`minimax.zig` tests pin the *old* depth-limited behaviour. So add a new
`src/solve.zig` and leave `minimax.zig` as a working reference until `solve` is
validated and scaled; then retire the old path. `solve` reuses `minimax.zig`'s
transposition machinery (`get/set_game_score`, `collision_size`, tables) in
Phase 2.

## Value convention

- `to_move: i8` = +1 Black, -1 White (the player about to move; cleaner than
  the old "last player" convention).
- Value = **area score from Black's perspective, minus komi** (`area_score` −
  `komi`), range `[-25-|komi| .. 25+|komi|]`, fits `i8`. Default `komi = 0`
  (matches the oracle: 5×5 = Black by 25).
- Interior nodes: Black **maximizes**, White **minimizes**.

## Move generation

Legal moves = every legal stone placement in the sub-board **plus pass**:

- Stone move: `child = armies_from_move(pos, to_move, p)`; skip on `Suicide`;
  **skip if `history.repeats(&child)`** (superko). Then `history.push(&child)`,
  recurse with `to_move` negated and `passes = 0`, `history.pop()`.
- **Pass**: board unchanged, do NOT push history, do NOT run `repeats` (passes
  are exempt from superko). Recurse with `to_move` negated and `passes + 1`.
- Pass is always available, so there is always ≥1 move — the old
  "no children" case is subsumed by passing.

Sub-board support (`x_width`, `y_height`) is kept for 2×2/3×3 testing.

## Terminal condition

A node is terminal when **either**:
- `terminal.is_settled(pos)` (Benson: all stones pass-alive, every empty region
  one colour) — an early, sound cut; **or**
- `passes == 2` (both players passed).

Terminal value = `area_score(pos) − komi`. Under optimal area play a player
only passes when nothing improves, so at a double-pass no dead stones remain and
`area_score` is exact (Tromp-Taylor semantics).

## Transposition table: what can be keyed

The TT key is `(blind, seq)` + side. `seq` holds only the first **16** stones,
so **only positions with ≤16 stones are hashable**. Positions with >16 stones
are near-terminal (≤8 empty points ⇒ shallow subtree) and are searched
**without** the TT. So the cutoff moves from "ply depth" to `num_stones ≤ 16`
(= `@popCount(blind)`). `collision_size` should drop its `max_depth` argument
(the value only ever depended on `num_stones`).

## Passing changes the value → don't cache pass-nodes (Phase 2)

The value of `(board, side)` depends on whether the opponent just passed: if so,
you may pass to end immediately. So `(board, side, passes)` is the true state.
Resolution: **cache only nodes reached with `passes == 0`** (the normal nodes);
compute `passes == 1` nodes inline (their stone-move children are normal,
cacheable nodes, so this is cheap). Keeps the key `(board, side)`.

## GHI: cache only history-independent values (Phase 2)

Superko makes legality path-dependent (`research/ghi-and-superko.md`). Handle it
with a per-node **dependency ply**:

- `solve` returns `(value, ko_ref)` where `ko_ref` = the shallowest game-line
  ply that any superko ban in this subtree referenced (a large sentinel if no
  ban fired). `repeats()` is extended to also return the matched history index.
- A node at ply `d` is **cacheable iff `ko_ref ≥ d`** — every ban it relied on
  referenced a position within its own subtree, so its value is
  path-independent. If `ko_ref < d`, a ban referenced an ancestor *above* the
  node → value is history-conditional → **do not cache**.
- Propagate upward: a cacheable child contributes the sentinel (no taint); a
  non-cacheable child contributes its `ko_ref`; a superko-pruned child
  contributes the matched ply. Parent `ko_ref` = min of these.

This confines the uncacheable set to genuinely ko-entangled nodes; the ko-free
majority caches normally. (Simpler fallback if needed: taint conservatively on
any ban and don't cache tainted — correct but caches less.)

## Phasing (build + test order)

- **Phase 1 — correctness, no TT.** `solve` with superko + pass + Benson/double
  -pass terminal + area scoring. **DONE** (`src/solve.zig`). Finding: without a
  TT, any non-settled position can reopen the board (a capture removes a whole
  group → near-empty board → explosive deep search), so Phase 1 can only
  validate the terminal / scoring / pass paths (settled positions, komi, colour
  symmetry, full-board double-pass). Deep capture & superko *search* validation
  is intractable without memoization → moves to Phase 2.
- **Phase 2 — TT + GHI, scale to 5×5.** Add the `(blind,seq)` cache with the
  `num_stones ≤ 16` cutoff, the `passes == 0`-only rule, and the `ko_ref`
  cacheability test. Oracle: **5×5 = Black by 25**.

## Blast radius / migration

- `minimax.zig`: unchanged initially; retire after `solve` is validated. Its
  depth-limited tests stay green meanwhile.
- `measure.zig`: still measures the old minimax for now; a new measurement mode
  for `solve` comes with Phase 2.
- `persist.zig`: unaffected (still `{blind, color, seq, score}`; values become
  terminal values).
- New tests live in `solve.zig`.

## Open questions / risks

- Recursion depth = game-line length; bounded by `superko.MAX_LINE`. Confirm
  it's ample for 5×5 (assert on overflow).
- Whether Phase-1 (no TT) reaches 3×3 fully; if not, bring Phase 2 forward.
- Exact `seq_table_size` for a full 5×5 to-terminal run (needs measured
  `collision_size` for 9–16 stones — already a Next-item).
