# 0004 — Terminal detection via Benson; GHI handling for the TT

Date: 2026-07-14 · Status: accepted (design; not yet implemented)

## Context

Two defects make the current transposition table unsound
(`research/transposition-bug-root-cause.md`):
- **P1** repetition is not prevented (no ko) → positions recur, even inside
  their own subtree.
- **P2** a horizon-limited heuristic value is stored in a depth-agnostic
  table → the same position gets different values at different plies.

## Decision

- **Terminal = Benson unconditional life.** A position is a leaf once every
  group is pass-alive and every empty region is owned. Score it by area.
  This makes leaf values the true game value → depth-independent → **removes
  P2** and makes the TT legitimately shareable across paths.
- **Superko removes P1** (see 0003) and makes the game tree finite.
- **GHI (superko makes legality history-dependent) handling:** cache only
  **unconditional** values — the "null-history" value, of which there is at
  most one per position. If a node's subtree invoked a superko ban that
  referenced an ancestor above it, mark it **tainted** and do not cache it
  (recompute on re-encounter). Conservative taint = "any superko ban fired in
  the subtree". The Kishimoto–Müller optimization (cache tainted values with a
  minimal ancestor dependency set) is deferred.

## Why

Benson is the sound, standard early-terminal test (conservative: it certifies
only *unconditional* life, so it never wrongly stops). Caching only
unconditional values is the simplest provably-correct GHI handling; ko-tainted
nodes are rare, so recomputing them costs little on 5×5.

## Consequences

- Need a Benson pass-alive implementation over `state.zig`'s army/liberty
  machinery.
- The `pos_score` heuristic stops being a leaf value; it may survive as a
  move-ordering hint only.
- Detection reuses `zobrist.zig` (path-set of position hashes).
