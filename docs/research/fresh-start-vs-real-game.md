# Fresh-start scores vs real-game scores

**Date:** 2026-07-26  
**Status:** conceptual clarification following T13 and user questions.

## What the table contains

The weizigo artifacts hold **fresh-start scores**: the exact game-theoretic
score of each `(position, side)` reached from an **empty board with no prior
history**, under **basic ko** (the generation rule), with the sound finisher config
(`memo_writes=false`, bracket-guided alpha-beta).

C1 says these fresh-start scores are correct at 2×2/3×2. The claim is **not**
that the same scores are correct when the position is reached after a real
ko-history. Per-board epistemic independence applies: verification at one
board size does **not** transfer to another.

## Ko-sensitive vs history-dependent

The project uses two different distinctions that must not be conflated:

1. **L < H (wide bracket)** — positions where the fresh-start score is *not*
   unique across different cycle-resolution conventions. These are called
   **ko-sensitive** in the table because the L/H iteration itself spreads.
2. **L == H but score changes under real history** — positions where the
   fresh-start score *is* unique, but still differs from the score under some
   reachable PSK history. T13 found 12 such positions at 3×2.

So in a loose English sense, **even some L==H positions are
history-dependent**. They are "ko-sensitive" only in the project sense if
L < H. The single-score region is not provably history-independent.

## Generation rule vs real-game rule

- **Generation rule:** basic ko (one-ply repetition ban). This is tractable.
  The table is exact for fresh-start positions under this rule.
- **Play-time / real-game rule tested:** positional superko (PSK), no whole-board
  position may repeat. This is what made C2 false at 3×2.
- **SSK** (situational superko, no `(position, side)` repeat) is stricter than
  PSK and has not been the focus.

The engine is **not provably perfect for real games under any repetition
rule**, because it uses fresh-start scores and ignores the actual ban set.
It is exact only for the fresh-start game tree.

## Are there multiple tables per ruleset?

No. Building one full table per board size is already expensive. The project
has one table per size, generated under basic ko, with play-time legality
optionally enforced by PSK/SSK. The table does not distinguish histories.

## How to play real games better

To be real-game optimal, a player would need the score of `(position, side,
ban_set)` triples. Possible directions:
- **Goal-bounded forward solver / query engine:** search the actual game tree
  from the current position with the real ban set, using the table scores as
  heuristics / bounds.
- **History-aware tables:** store scores keyed by ban set. Intractable beyond
  small boards.
- **CGT / local decomposition:** give up on full-board tables and compute
  local values with loopy combinatorial game theory.

None of these are currently implemented.

## Terminology note

User request (2026-07-26): prefer plain words. A single integer is a **score**.
A `[L,H]` interval is a **range of scores** or just a **range**. Reserve
"bracket" for the L/H interval when context is clear.

## CGT

**CGT = Combinatorial Game Theory** (Berlekamp, Conway, Guy). It assigns
values (numbers, infinitesimals, loopy games) to local positions and combines
them. For Go, CGT is the research-grade route to exact ko values: it handles
long cycles and *loopy games* with values beyond simple integers. The project
has not built CGT support; the current engine uses full-board fixpoint
iteration instead.

## Why fresh-start scores are useful

- They are exact for the opening and for any analysis that starts from a
  position with no history.
- They are a strong baseline player and teaching tool.
- They give exact scores under the tractable basic-ko generation rule.
- They provide anchors (3×3 = +9, 4×4 = +2) and the `[L,H]` range of scores
  under cycle-convention spread (a fresh-start property; does **not** bound
  real PSK scores — C3 falsified at 3×3 by E2; see
  `../status/leak-crisis.md`).
- They are a building block: a history-aware player can use them as bounds,
  heuristics, or endgame tablebases.

The **honest deliverable** is the fresh-start score table + the CLAIMED `[L,H]`
fresh-start bracket, with the explicit non-promise that neither equals nor
bounds the real-game PSK score (C2 false at 3×2, C3 false at 3×3).

The project is **not** collapsing. The object shifts from "provably perfect
real-game oracle" to "provably correct fresh-start oracle + honest ranges".
That is a smaller, still valuable, deliverable. Whether to invest in more
research (history-aware tables, CGT, goal-bounded search) is a user decision.
