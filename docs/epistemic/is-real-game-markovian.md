Author: `Opus/Orcha` · Date: 2026-07-29
Status: **ANALYSIS.** No claim status changed. Decision-relevant for the pending
`ADR-0020` fork; cites measured results, marks the one unknown that matters.

# With ko in the state, is the real game Markovian?

The human's question: *if we consider ko to be part of the Markovian state, is the
real game Markovian — or "mostly Markovian but for complex 2+ko cycles"?*

Short answer: **"mostly Markovian" is measured and true for legality, and false for
value — and the counterexample is not a complex multi-ko position.**

## Three things can be non-Markovian, and they come apart

Keeping them separate is the whole answer, because the project has repeatedly
concluded something about one from evidence about another.

### 1. Legality — effectively Markovian, and this is measured

Under PSK, legality depends on the entire visited set. Adding `ko_point` to the
state captures **exactly one ply of history**: the immediate recapture. It cannot
express repetition of period > 2 — double ko, triple ko, sending-two-returning-one,
rotating ko. So on `(board, side, ko_point, passes)` PSK legality is *formally* not
Markovian.

**Empirically it almost never matters.** EXP-1: across **130,171 plies and 1,015,076
candidate moves, PSK never once forbade a move that basic ko allowed**, and it binds
**0 times** in both recorded human-vs-engine games. It binds only under uniformly
random play. For legality, then, "mostly Markovian, the exceptions are exotic" is not
a hope — it is a measurement.

### 2. Termination — non-Markovian by construction

Under any rule where a repetition ends the game — including first-revisit truncation,
the rule `ADR-0019` chose — *when* the game ends is a function of the visited set.
`ko_point` cannot help at all here, because the rule quantifies over **all**
previously-visited states, not the last one. This is not a defect to be repaired by
enlarging the state a little; it is what the rule says.

### 3. Value — **not** Markovian, and this is now measured too

`QA023-KERNEL-AUDIT` (2026-07-29), reproducing `PINRULE-SUFFICIENCY`: state
`(178,0,6,0)` — goban `[B,W,B,␣,W,␣]`, Black to move, `passes=0`, **no ko point
active** — has two valid arrivals giving first-revisit-truncation values **−3** and
**−6**, while the corrected fixpoint gives `L=H=−6`. Two histories, one tuple, two
values.

## Why "complex 2+ko cycles" is the wrong mental model

**That witness is not a multi-ko position, and it could not be one.** It sits on a
**6-cell goban** with two empty points and no active ko. 3×2 is too small to hold two
independent ko fights. If non-Markovianity of value required 2+ko structure, it could
not appear there at all.

It appears at the smallest goban that has *any* cycle structure: 3×2 carries **216,176
simple cycles** at length cap 14 over **1,676 cycle-involved** vertices (`2B-2`,
corrected). The mechanism is **repetition in general**, not multi-ko in particular —
capture/recapture patterns and pass sequences generate cycles densely.

So: **putting ko in the state fixes the period-2 case and nothing else**, and the
non-period-2 cases are *structurally everywhere*. What is rare is **meeting them in
real play** — which is a claim about play, not about the state space, and is exactly
what EXP-1 measured for legality.

## Enlarging the state is already foreclosed — by measurement, not by taste

The natural repair — carry more history — has been tried and closed:

- **RETRO_PLY** (ban the last N gobans): the memo key still requires the full
  history. Measured, foreclosed (`GLOBAL.RPLY`).
- **Score-on-cycle**: byte-identical state counts to PSK (118,475,182 / 116,114,272).
  Provably as hard (`GLOBAL.R2`).
- **Bounded window in the state** `(board, side, passes, last-N)`: measured,
  foreclosed (`ruleset-options.md`).
- **kill-X%**: made the ko-sensitive region *worse* (`GLOBAL.R3`).

This is `AUDIT-DSPro` §2.2's point and it is the strongest structural fact the project
owns: every bounded-history representation was foreclosed **by measurement**, not by
lack of imagination.

## The one unknown, and it is the decision-relevant one

| | legality | value |
|---|---|---|
| formally Markovian on the tuple? | no | **no** (3×2 witness) |
| divergence measured in **real play**? | **yes — ≈ 0** (EXP-1) | **never measured** |

**Nobody has measured how often the value gap binds in real play.** That is `S2` /
`EXP-8`, blocked behind the new-rule tables. And it decides everything: if value
divergence in real play is ≈ 0 like legality divergence, then a Markovian
(fresh-start) table is a **practically correct player that is theoretically wrong** —
which is precisely the `K2` target of `knowledge-ladder.md`: *provably optimal under a
stated rule, with a measured divergence from the rule being played.*

## Consequence for `ADR-0020`

Truncation is not Markovian on the tuple, and enlarging the tuple is foreclosed. So:

- **(a) Keep truncation, accept a history-dependent solve** → that is PSK's
  intractability again. Closed.
- **(b) Adopt a Markovian *rule*** — fresh-start / shortest-arrival semantics, which
  **survives** the corrected kernel (`396/396` agreements) and is what the table
  already holds. Honest, and narrower than "real-game Go".
- **(c) Ship (b) plus the measured gap** — the `K2` deliverable, and the negative
  result stated once as a contribution.

**(c) is the only option that yields something both true and interesting, and it
depends on a measurement nobody has taken.** So `S2` becomes the highest-value
unblocked experiment in the project — far cheaper than any 4×4 build, and it is the
number that decides whether the deliverable is worth shipping.

**One caution on framing.** "Mostly Markovian" is a fair description of the *legality*
result and an unfair one for *value*: the value counterexample is generic, not exotic,
and the project has three times this month concluded something about value from
evidence about legality. Say which one is meant, every time.
