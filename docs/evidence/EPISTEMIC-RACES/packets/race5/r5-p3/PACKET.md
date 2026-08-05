# Race 5 · Packet R5-P3 — the single-tie-constant axiom set

*Exam item for EPISTEMIC-RACES race 5 (formal precision — seeded inconsistency audit). Audit the axiom set below for consistency. Output: a consistency audit document — CONSISTENT or INCONSISTENT; if inconsistent, name the minimal inconsistent subset and prove it; then state what the correct repair looks like. False alarms are counted against you.*

---

## The axiom set

A formalisation of the value rule the project's solver uses, together with the measured 4×4
bracket and the published anchor.

- **A1.** **Colour inversion.** For every (position, side): `value(-pos, -side) = -value(pos, side)`.
- **A2.** **Single tie constant.** The value function is `V = median(L, TIE, H)` — i.e.
  `V = max(L, min(TIE, H))` — with **one global constant** `TIE = t` for both sides.
- **A3.** **Measured bracket.** At the empty 4×4, the measured bracket is
  `[L = +1, H = +16]` for Black and `[L = −16, H = −1]` for White.
- **A4.** **Published anchor.** The published MIGOS anchor for the empty 4×4 is
  `(+2, −2)` — Black +2, White −2 — colour-symmetric.

## Task

Audit the set. Is it consistent? If not: which axioms form the minimal inconsistent subset,
and what is the contradiction? Then: what does the correct repair look like (which axiom
should be amended or withdrawn, and to what)?
