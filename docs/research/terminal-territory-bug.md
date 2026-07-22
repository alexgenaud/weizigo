# Terminal-territory bug: `is_settled` over-fires (found + FIXED 2026-07-15)

## RESOLUTION (2026-07-15, commit b18e49d)
Fixed: `is_settled` now also requires **every empty point to have a stone
neighbour** (condition (3) below) — genuine eye-space, no colonizable interior.
Sound even against a passing defender; the double-pass path backstops territory
that is a player's only under alternating play. Tests added (6-stone open board
and open "two eyes" board -> false; full two-eye board -> true). Corrected
census: the minimal **decided** single-colour terminal is **10 stones** (two
full rows, every empty point walled), not the spurious 6; terminals now start at
k=10. High-density percentages barely move; sparse/mid ones drop sharply (the
open interiors that used to falsely count are now excluded).

--- original write-up below ---


## Symptom
`terminal.is_settled` returns true for positions that are NOT game-theoretically
decided — e.g. a 6-stone black group with two eyes on an otherwise empty 5x5.
Benson proves the *stones* immortal, but the wide-open rest is invadable: if
Black passes forever, White plays in and lives.

## Root cause — two notions conflated
- (A) Tromp-Taylor SCORING rule for an agreed-finished game: "empty region
  touching one colour = that colour's territory." Correct for *scoring*.
- (B) Proven-decided: "outcome cannot change whatever the opponent does."
  Required for a terminal *cutoff*.
`is_settled` implements (A) but is used as (B). They agree only when empty
regions are genuine eye-space; they diverge on large open regions. Benson gives
live STONES, not uninvadable TERRITORY.

## Impact
- Census ("minimal settled = 6 stones", per-k %) measured (A), not (B) — retract
  as "scoring-settled", not "decided".
- `solve.zig` uses `is_settled` as an early terminal cut -> UNSOUND (can return
  an inflated value). The sound terminal is double-pass; `is_settled` is only a
  valid *optimization* if strengthened. Latent correctness bug.
- `terminal.zig` test "settled: two eyes owning the board" (bottom two rows
  open) asserts `is_settled = true` -> WRONG (White invades if Black passes).
  Must fix the test. (`two_eyes_black`, only 1-pt eyes empty, is genuinely
  decided -> stays true.)

## Fix
Require every empty region to be a VITAL region: every empty point is a liberty
of a bordering pass-alive chain (genuine eye-space, no colonizable interior).
This is Benson's vitality condition, already computed inside `pass_alive`;
`is_settled` just doesn't use it. Makes the cut *unconditional* (sound even vs a
passing defender); the double-pass path remains the backstop for territory that
is a player's only under alternating play. Rigorous, less-conservative version:
Müller "unconditional territory" (1997).
Expected: `is_settled(6-stone open)` -> false; `is_settled(two 1-pt eyes)` ->
true.

## Plan (next session)
1. Failing tests: 6-stone open board = false; open "two eyes owning the board"
   = false.
2. Fix `is_settled` (vital regions); correct the bad test.
3. Re-run the census (`src/settled_census.zig`) for the true minimal-*decided*
   terminal + honest percentages.
4. Only then are leaf values trustworthy enough to persist.
