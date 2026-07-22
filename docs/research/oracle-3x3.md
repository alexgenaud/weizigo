# 3x3 oracle prototype: forward fresh-start filling is INTRACTABLE (2026-07-17)

Attempt to build the first oracle artifact — the fresh-start value (ADR-0008)
of every legal 3x3 (position, side) — by forward search with the validated
solve.zig semantics (superko + ko_ref GHI rule + eye-prune), memoized directly
into the colex array. `src/oracle.zig`, ReleaseFast.

## What happened

- **Cold ascending sweep** (empty board first): no progress in >5 min — the
  empty root alone is the full 3x3 solve through a GHI-tainted, unmemoizable
  opening. Killed. (The 5x5 forward-solve wall, docs/research/
  forward-solve-scaling.md, reproduced in miniature.)
- **Warm bottom-up sweep** (8-stone endgame roots first to fill the memo):
  after 13:49 min (826 CPU-s) it was STILL INSIDE LAYER 8 — the 402
  eight-stone boards with a single empty cell each. Killed.
- **Single-root probes** (10M-node budget): the first two legal 8-stone roots
  each EXCEEDED 10,000,000 nodes (~7 s apiece), with search lines reaching
  **2,186 and 1,958 plies deep** — on a 9-cell board.

## Why (the mechanism, now measured three ways)

An "endgame" root is not small: its best line often CAPTURES and REOPENS the
board (the ADR-0006 reopening problem — the eye-prune only protects
Benson-alive groups, and most 8-stone-3x3 groups are not). The reopened
subtree is the whole game, its ko-affected core is GHI-tainted (`ko_ref < d`)
so the memo never keeps it, and every root pays it again. Positional superko
makes individual lines legal for THOUSANDS of plies (capture cycles that never
exactly repeat a position), so each unmemoized descent is astronomically deep.
Rough cost: >=10M nodes/root x 25,350 roots — years, not minutes.

## Conclusions

1. **Forward fresh-start filling cannot build the oracle even at 3x3.** This
   closes the question empirically at the smallest interesting scale; it was
   already measured at 5x5. The clean-only (`ko_ref >= d`) memo is sound but
   keeps ~nothing where it matters.
2. **The retrograde engine (#6') is now the critical path**, not an
   optimization: values must propagate from terminals with ko handled
   STRUCTURALLY (Kishimoto–Müller-style bucketing or an explicit
   cycle-resolution rule), so each position is processed once.
3. **Depth postscript**: 3x3 DFS lines exceed 2,100 plies. Game-line length
   under positional superko is bounded by the count of legal positions, not by
   any small constant — now measured, not argued.

## What remains valid and ready

- `src/rules.zig` — generic rules, cross-validated against the 5x5 stack
  (500 random boards vs terminal.zig; 1000 random moves vs state.zig). Solid.
- `src/oracle.zig` — the solver machinery, colex-array memo plumbing, and the
  full VALIDATION BATTERY (published anchors, exhaustive colour-inversion +
  dihedral checks, order-independence probe, no-memo spot checks) are written
  and waiting: they will validate the retrograde table the moment it exists.
- ADR-0008 semantics (fresh-start value) stands: retrograde must produce
  values matching it (spot-checkable per position with the forward solver,
  which IS tractable for isolated near-terminal roots).

## Next (the #6' design ADR, now unavoidable)

Retrograde over the colex space, per layer, with the two hard parts front and
center: (a) predecessor generation / un-capture, or successor-counting value
iteration over the position graph; (b) the ko/GHI representation — what extra
state distinguishes history-sensitive buckets, and how cycles resolve under
positional superko. The 3x3 numbers above are the design constraints.
