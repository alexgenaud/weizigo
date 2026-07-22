# 0006 — Eye-fill pruning: making the to-terminal search tractable

Date: 2026-07-15 · Status: **accepted**

Extends ADR-0005 (search integration). Discovered while validating Phase 2.

## Context: the search-to-terminal is intractable without move pruning

Phase 1 already noted that "a capture can reopen the board." Phase 2 pinned down
*why every non-trivial position* hits this, not just contrived ones:

A Benson-alive group is alive only because it *keeps* its eyes. But **filling
your own eye is a legal move** (it is not suicide as long as the group still has
another liberty). The brute-force DFS therefore explores a live group filling
its own eyes one by one, down to a single liberty — at which point the opponent
plays that liberty and **captures the entire group**, reopening the board into a
near-empty position whose subtree is the whole game again.

Consequences observed:
- A 3-empty-point "endgame" (e.g. a black wall enclosing one dead white stone)
  drove game lines past `MAX_LINE = 2048` and blew the stack (`exit 138`), both
  with and without the transposition table. The TT memoizes revisits but does
  **not** shorten a single deep line, so it does not help here.
- With only 25 cells but self-eye-fill allowed, essentially **no** non-settled
  position is tractable — the value is correct but unreachable.

## Decision: forbid a player from filling its own true eye

In move generation, skip any empty point `p` such that **every orthogonal
neighbour of `p` is a stone of the mover that is Benson-unconditionally-alive**
(`terminal.pass_alive(pos, to_move)`), counting edge/corner points by their
present neighbours. Implemented as `solve.is_own_eye`.

### Why it is sound (does not change the game value)

Under **area (Chinese) scoring**, an empty point enclosed by your own *alive*
stones already counts as your territory. Playing there:
- does not gain a point (stone or territory, it is yours either way), and
- strictly reduces the group's eye space, only ever *risking* its life.

So the move is never better than passing (always available) or than any other
move, and it can never be the unique optimal choice. Removing it cannot lower
the mover's achievable value. The opponent, meanwhile, already cannot play in
those eyes (suicide). Hence a Benson-alive group's eyes are **immortal from both
sides**, groups stop dying spuriously, and alive regions settle instead of
reopening.

This is the standard "don't fill your own eyes" rule; the Benson certificate is
what makes it provably safe rather than a heuristic.

## Cost

`pass_alive(pos, to_move)` (two flood fills + a small fixpoint) runs once per
node. That is cheap relative to the exponential blow-up it removes: the dead-
stone endgame drops from stack-overflow to 4 nodes.

## Results (validated)

- `dead_white` position: Black **+25** for both sides to move; colour symmetry
  holds; TT result equals no-TT result. (`src/solve.zig` tests.)
- Machinery: TT get/set round-trips, inverse-side folding, block sizing — unit
  tested.

## What this does NOT solve (open, see TODO)

Eye-pruning tames *endgames* (positions with alive groups). It does **not** make
the **empty-board full solve** cheap: the opening/midgame with ≤16 stones is the
inherently large part, and that is exactly the regime the TT caches. Reaching
the global oracle (5×5 = Black+25 from empty) still depends on:
- **Line length**: positional superko lines can be long; recursion depth =
  line length. `MAX_LINE` was raised 2048→4096 as headroom, but a real bound
  (and likely an explicit depth-safe iteration or larger stack) is still needed.
- **seq-table sizing** for a full run (ADR-0005 open question; needs measured
  `collision_size` for 9–16 stones).
- Raw tree size / time.

These are the next frontier, not correctness gaps.
