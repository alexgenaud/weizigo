# Published 5×5 oracle — a principal variation (coordinates)

5×5 Go is **solved**: with the optimal first move at the **center (c3 / tengen)**,
**Black wins by 25** (the whole board). Solved by Erik van der Werf in 2002
(Japanese rules; the whole-board result is the same under Chinese/area). The
value + best first move are the proven, unambiguous facts. There is **no unique
"perfect game"** — once Black plays the center, every White reply loses, so many
continuations are equally optimal. Below is *one* published principal variation.

## The line (from van der Werf's solution, via Hayward's course notes)

Source diagram: "a 5x5 pv" in *Solving Go on Small Boards*
(https://webdocs.cs.ualberta.ca/~hayward/355/ssgo.pdf, p. 18), reproducing van
der Werf's solution. Columns a–e (left→right), rows 1–5 (**row 1 = bottom**).

| # | Color | Coord | weizigo idx |
|---|-------|-------|-------------|
| 1 | B | c3 | 12 (center) |
| 2 | W | c2 | 17 |
| 3 | B | b2 | 16 |
| 4 | W | b3 | 11 |
| 5 | B | d2 | 18 |
| 6 | W | c4 | 7 |
| 7 | B | d3 | 13 |
| 8 | W | a2 | 15 |
| 9 | B | b1 | 21 |
| 10 | W | b5 | 1 |
| 11 | B | a4 | 5 |
| 12 | W | d4 | 8 |
| 13 | B | b4 | 6 |

weizigo index = `(5 - row) * 5 + col`, with a..e → 0..4.

Position after the 13 plies (`.`=empty, lowercase=Black, uppercase=White, letter
= army/group id, as printed by `state.print_armies`):

```
row5  . A . . .
row4  a a B B .
row3  . C b b .
row2  D c E b .
row1  . c . . .
      a b c d e
```

## What this line is (and isn't)

- It stops at **13 plies**, not at the final all-Black board. Van der Werf's
  search proves the whole-board win ~6 plies early via **Benson's algorithm**
  (unconditional life), so the PV ends once Black's win is certified, before the
  dead White stones are actually captured and the board filled.
- It is *a* principal variation for the center opening, not the unique game.

## Engine verification (what weizigo confirmed)

Replayed through `state.armies_from_move` move by move:
- **all 13 moves are legal** (no suicide, no collision);
- **no captures** — pure construction, 13 stones placed, 13 on the board;
- **final occupancy + colors match the published diagram exactly.**

What weizigo could **not** confirm: the **+25 value**. Certifying that requires
either playing out the capture of the dead White stones to an all-Black terminal
(needs the full solve, which does not yet complete — see TODO scaling items), or
a Benson eye-space check that `terminal.is_settled` will not pass while the dead
White stones are still on the board. So: **legality of the published line is
engine-verified; the game-theoretic value is cited, not re-proven here.**

## Sources
- Hayward, *Solving Go on Small Boards* (course notes), p. 18 "a 5x5 pv":
  https://webdocs.cs.ualberta.ca/~hayward/355/ssgo.pdf
- Van der Werf, *5×5 Go solved* (animated optimal play, 3 strongest openings):
  http://erikvanderwerf.tengen.nl/5x5/5x5solved.html
- Van der Werf, *Solving Go on Small Boards* (paper):
  http://erikvanderwerf.tengen.nl/pubdown/solving_go_on_small_boards.pdf
