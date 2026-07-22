# Go rules: ko and scoring

Reference for the ruleset choices in `decisions/0003`.

## Ko / repetition

- **Basic (simple) ko**: may not *immediately* recreate the board from one
  move ago. Bans only length-2 repetitions; does not stop longer cycles
  (triple ko, eternal life, sending-two-returning-one).
- **Superko**: extend the ban to *all* previous positions.
  - **Positional (PSK)**: no prior whole-board *stone configuration* may
    recur. ← this project's rule ("exact board positions never repeat").
  - **Situational (SSK)**: no prior *(position + side to move)* may recur.
    Slightly more permissive; PSK and SSK diverge only in rare positions.
- Either superko guarantees **finite games** (finitely many positions, each
  usable once).
- Key fact: **a whole-board position can only recur after a capture.** Each
  move adds one stone and removes only captured stones; in capture-free play
  the stone count strictly increases, so nothing can repeat. ⇒ ko/superko is
  vacuous until a capture happens.

## Scoring

- **Area (Chinese, Ing, NZ, Tromp-Taylor, AGA-area)**: stones on board +
  surrounded territory. **Pure function of the terminal snapshot.**
- **Territory (Japanese, Korean)**: surrounded empty territory + prisoners.
  **Needs prisoner counts → path-dependent, not snapshot-recoverable.**
- Usually agree within a point or two; differ in mechanics (dame filling,
  passes, komi).

## Ruleset comparison

| Ruleset | Scoring | Ko / repetition | Suicide |
|---|---|---|---|
| Japanese | Territory | Basic ko; unresolvable cycles → "no result" (無勝負), replay | Forbidden |
| Korean | Territory (≈ Japanese) | Basic ko + no-result | Forbidden |
| Chinese | Area | Basic ko; rare cycles by tournament provision (draw/void/replay) | Forbidden |
| AGA | Area & territory reconciled | Situational superko | Forbidden |
| New Zealand / Tromp-Taylor | Area | Positional superko | Allowed (multi-stone) |
| Ing (SST) | Area, komi 8 | Elaborate ko procedure to force resolution (avoids no-result) | Forbidden |

Notes:
- Life & death: Japanese rules *analyze* it by agreement; area rules just
  **play it out** (filling your own territory is free) — friendlier to a machine.
- This project **forbids suicide** (`armies_from_move` returns `Suicide`), so
  it is *not* Tromp-Taylor exactly — closer to Chinese/area with a nonstandard
  symmetric komi (`simple_score`: ±1 by side).

## Oracle

**5×5 Go is solved: Black (first player) wins by 25** — Black takes the whole
board; no white group can live against best play (van der Werf & van den Herik,
~2002, area scoring). Use as a correctness check once the solver runs.
