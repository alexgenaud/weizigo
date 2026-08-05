# Race 5 · Packet R5-P2 — the fresh-start vs real-game axiom set

*Exam item for EPISTEMIC-RACES race 5 (formal precision — seeded inconsistency audit). Audit the axiom set below for consistency. Output: a consistency audit document — CONSISTENT or INCONSISTENT; if inconsistent, name the minimal inconsistent subset and prove it. False alarms are counted against you.*

---

## The axiom set

A reconstruction of the project's standing statements about what its table does and does not
claim.

- **A1.** The table stores **fresh-start scores only** (claim C1): every entry is the exact
  game-theoretic fresh-start value of that (position, side) under ruleset R.
- **A2.** At 3×2, single-score history-independence (claim C2) is **falsified**: 154 of 508
  non-trivial PSK histories disagree with the fresh-start score of the same position.
- **A3.** The values in the L==H (single-score) region are **fresh-start exact** (C1 holds
  there); they are not claimed to be real-game exact.
- **A4.** For a (position, side) on which **every legal history reaches the same value**, the
  fresh-start score equals the real-game score.

## Task

Audit the set. Is it consistent? If not: which axioms form the minimal inconsistent subset,
and what is the contradiction? If yes, say so explicitly — a correct CONSISTENT verdict earns
the point; a false contradiction costs it.
