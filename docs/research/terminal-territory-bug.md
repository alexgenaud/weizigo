# Terminal-territory bug: `is_settled` over-fires (found + FIXED 2026-07-15)

**Dead-end resolved.** `terminal.is_settled` returned true for positions
that were NOT game-theoretically decided (e.g. a 6-stone Black group with
two eyes on an otherwise empty 5×5: Benson proves the stones immortal, but
the wide-open rest is invadable — if Black passes forever, White plays in
and lives).

**How we know (root cause).** Two notions were conflated:
- (A) Tromp–Taylor SCORING rule for an agreed-finished game: "empty region
  touching one colour = that colour's territory." Correct for *scoring*.
- (B) Proven-decided: "outcome cannot change whatever the opponent does."
  Required for a terminal *cutoff*.
`is_settled` implemented (A) but was used as (B). They agree only when
empty regions are genuine eye-space; they diverge on large open regions.
Benson gives live *stones*, not uninvadable *territory*.

**Fix (commit b18e49d).** Strengthen `is_settled` to require every empty
point to have a stone neighbour (Benson vitality condition). Sound even
against a passing defender; the double-pass path backstops territory that
is a player's only under alternating play. Tests added (6-stone open
goban and open "two eyes" goban → false; full two-eye goban → true).
Corrected census: minimal decided single-colour terminal is now 10
stones (two full rows walled), not the spurious 6.

**Lesson.** "Sound terminal" is a stronger condition than "valid scoring
rule." Use the rigorous Müller "unconditional territory" (1997) for
sibling decisions; the eye-space vital-region test is the tractable
subset we use here. Full write-up (with test data) is in git history.
