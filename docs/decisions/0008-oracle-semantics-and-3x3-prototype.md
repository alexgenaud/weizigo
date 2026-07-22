# 0008 — Oracle semantics (fresh-start value) + the 3x3 prototype

Date: 2026-07-17 · Status: **accepted** (semantics); prototype in progress

Refines ADR-0007 (goal = compressed perfect oracle). Defines what the oracle's
stored value MEANS, how the first oracle artifact is built, and how the shaky
parts (superko history, sign conventions) are validated.

## Decision 1: the oracle stores the FRESH-START value

`oracle[position][side]` = the optimal area score (Black-positive, komi 0) of
the game **starting at `position` with `side` to move**, history seeded with
the position itself (positional superko then forbids recreating any position
seen since this start). Properties:

- Well-defined for every legal position (no history parameter needed).
- Exactly `solve.zig`'s `solve_root` semantics — the validated engine.
- For a position reached MID-GAME with extra ko bans in force, the true value
  can differ. That gap is the **GHI residue**: it is MEASURED (the fraction of
  roots whose search saw any superko ban), not assumed away. If the residue
  positions matter for real play, they get history-aware treatment later
  (Kishimoto–Müller bucketing) — an extension, not a redefinition.

## Decision 2: the raw colex array IS both the memo table and the artifact

The builder solves every legal (position, side) as a fresh-start root, memoizing
GHI-clean interior values (`ko_ref >= d`, `passes == 0` only — the solve.zig
rule) directly into `values[colex]` arrays (one per side). After the sweep every
legal slot is filled (each got its own root pass). No separate transposition
table structure; no blind/seq machinery.

## Known theoretical hole, and how it is probed

The `ko_ref >= d` caching rule prevents reusing values that DEPENDED on
ancestor bans, but cannot know that a *new* context's ancestors would have
banned a line the original search explored freely (a positional cycle through
the node). This is the classic GHI problem; the rule is a sound-in-practice
compromise, not a theorem. Probes in the 3x3 build:

1. **Build-order independence**: build the full table twice (ascending vs
   descending root order); memo pollution is order-dependent, so byte-identical
   tables are strong (not conclusive) evidence of soundness.
2. **No-memo spot checks**: >= 6-stone roots re-solved with memoization
   disabled (node-budgeted) and compared.
3. **Published anchors**: empty 3x3 = B+9 (centre); 1.B side = +3; 1.B corner
   = -9 (Hayward, *Solving Go on Small Boards*).
4. **Exhaustive symmetry**: colour-inversion (`value(-pos,-side) ==
   -value(pos,side)`) and all 8 dihedral transforms, over EVERY legal position
   — replacing the hand-picked inversion unit tests the user does not fully
   trust with a total check.

## Sign conventions (canonical statement — user has been bitten here)

- Scores are **always Black-positive**, whoever is to move. Side-to-move
  selects the ARRAY (`vb` vs `vw`), never the sign of the stored value.
- Black maximizes; White minimizes.
- Colour inversion: `value(-pos, -side) == -value(pos, side)`. A colour-swap
  canonicalization therefore negates the stored score and flips the side key
  (exactly `solve.Table.get`'s behaviour).
- Dihedral transforms never change value or sign.

## Implementation

- `src/rules.zig` — board-size-generic rules (move/capture/suicide, area score,
  Benson `pass_alive`, `is_settled`, eye-prune predicate). Cross-validated
  against the 5x5 stack: 500 random boards vs `terminal.zig` (score, Benson,
  settled) and 1000 random moves vs `state.armies_from_move` — all equal.
- `src/oracle.zig` — generic solver (superko History + `ko_ref` GHI rule +
  ADR-0006 eye-prune) + the 3x3 build-and-validate `main`.
- Results: `docs/research/oracle-3x3.md`.

## Consequences / next

- The 3x3 oracle is the ground truth for the retrograde engine (same table,
  built backward, must match byte-for-byte).
- 4x4 is the next prototype scale (43 MB raw); 5x5 needs the density folds
  (legality ~2x, canonical ~16x) per ADR-0007.
- If the forward fresh-start build is too slow already at 3x3 (the empty-board
  root re-searches ko-tainted regions), that is *additional* evidence for
  retrograde — record the cost either way.
