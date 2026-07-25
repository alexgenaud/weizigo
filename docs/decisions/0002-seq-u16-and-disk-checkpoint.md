# 0002 — Widen sequence to u16; add disk checkpoint

Date: 2026-07-14 · Status: accepted

## Context

The transposition key is `(blind, seq)`: `blind` = which of 25 cells are
occupied; `seq` = the black/white pattern of the occupied cells. `seq` was a
`u8` that only recorded the first 8 stones — the true reason perfect hashing
was capped at 8 ply (not RAM, not 64-bit types). Re-running the 0–8 stone
layers on every code change was also wasteful.

## Decision

- **`seq` `u8` → `u16`** (`seq_from_pos/seq_from_view` record up to 16 stones;
  `seq_score.seq`, `lowest.seq`; `LAST_SAVE_DEPTH` 8→16; PANIC guard 127→32767;
  `collision_size` → `u16` with rows for 9–16 stones; sentinel 255→0xFFFF).
  Ceiling is now a *type* ceiling of 16 stones; behaviour for ≤8 stones is
  identical.
- **Disk checkpoint** (`src/persist.zig`): save/load the table so the shallow
  layers need not be recomputed. Format is decoupled from memory — a flat
  record stream `{blind, black, seq, score}`, split into black/white sections,
  each sorted by (blind, seq) with blinds delta-coded and everything LEB128
  varint packed. `apply/load` reserve seq index 0 and return the next free
  index for resuming a search (`init_tables` widened u8→u32).

## Why

Widening the type is the direct lever on the depth ceiling. A bespoke
delta+varint codec compresses this sorted integer data well without pulling in
the new `std.Io` flate streaming API, and stays fully unit-testable in tiny
memory. gzip / score-frequency coding can be layered later.

## Notes

Deep runs still need *measured* `collision_size`/`seq_table_size` values for
9–16 stones (current values are 2^(n-1) worst-case bounds) and the RAM to
hold them.
