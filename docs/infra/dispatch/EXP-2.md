# EXP-2 — Prove or kill QA-023 (THE GATE)

**Closes:** `QA-023` (and refines `QA-026`). **Blocks:** EXP-4, EXP-5, EXP-6,
EXP-7, EXP-8 — i.e. the entire roadmap. **Does not block:** EXP-3.

**Read first:** `docs/infra/dispatch/README.md`, then `AGENTS.md`, then
`docs/epistemic/roadmap-2026-07-28.md` §2 in full, then
`docs/research/ruleset-options.md` §"Correction: bounded N-ply superko" and
§"Option B / RETRO_CYCLE" — those two sections are the failures this experiment
must distinguish itself from.

---

## The claim under test

> **QA-023.** Under **basic ko + a fixed-value verdict for long cycles**, the
> state `(board, side_to_move, ko_point, passes)` is a sufficient **Markovian**
> state for exact solving. No game history is required.

If true: the resulting table is *chainable by construction*; C2, C3, C4, the GHI
problem, the `ko_ref >= d` guard and the bracket-cut orphan (O1) do not arise —
not because they were solved, but because the representation stops provoking
them. This is also the MIGOS II ruleset, so the published anchors become a
legitimate comparison for the first time.

If false: the roadmap fails, and the project needs a genuinely new idea.
**Say so loudly and stop.** Do not invent a workaround.

## Why this is not already foreclosed — read this carefully

The project has two standing results that look like they kill QA-023. They do
not, and understanding exactly why is the substance of this task.

1. **RETRO_CYCLE:** basic ko + **score-on-cycle** is byte-identically as
   intractable as PSK (118,475,182 / 116,114,272 states — identical counts).
2. **RETRO_PLY:** the bounded N-ply history window did not help; every N,
   including N=1, blew the budget.

Both were run with a cycle verdict of **score-on-cycle** — the game ends *scored
by area at the board that repeated*. That verdict is a **function of which board
you cycled back to**, so it is genuinely path-dependent, and the full history is
dragged into the key. The documented reason for RETRO_PLY's failure is exactly
this: *"to give a bounded rule a terminal verdict on longer cycles you must
detect those cycles, which requires remembering every board seen."*

**The hypothesis is that a CONSTANT verdict breaks that chain.** A fixed tie
value does not depend on which board repeated, so there is nothing for history
to determine.

**The obvious objection, which you must answer head-on:** *you still have to
detect the cycle, and detection needs history.* That is true in a **forward
search** — and it is precisely what killed RETRO_PLY. The claim is that a
**retrograde fixpoint over the whole finite state graph** never detects a cycle
at runtime: it solves all states simultaneously, and cycles manifest as states
that no finite path to a terminal pins down. **Establishing or refuting that
distinction is the core of this experiment.**

---

## Part A — the proof obligation (do this before writing any code)

Produce a written argument, in `docs/evidence/QA-023/proof.md`, addressing all
five points. Anything you cannot establish, record as an open sub-claim with an
ID — do not paper over it.

**A1. State sufficiency.** Show that `(board, side, ko_point, passes)`
determines the set of legal moves and the terminal conditions, with no further
history. Be explicit about `passes` (two consecutive passes end the game) and
about what `ko_point` means.

**A2. Nail the basic-ko definition.** There are two non-identical
formalisations in circulation:
   - (i) after a capture of exactly one stone, the capturing point is forbidden
     to the opponent's immediate reply;
   - (ii) a move may not recreate the whole board as it stood one ply ago.

They coincide in almost all cases. *Almost* is not good enough for a solver.
Determine whether they are exactly equivalent given the rest of this project's
rules (suicide forbidden, passes exempt); if not, produce the distinguishing
position and **state which one we adopt**. This is an ADR-worthy decision — flag
it, do not decide it silently.

**A3. Well-definedness of the value.** With infinite play valued at a constant
`T`, argue the game value of every state is well defined. Reference class:
finite two-player zero-sum games on a finite graph with a fixed value for
infinite play — the same structure as chess endgame tablebases, where repetition
is a draw and retrograde analysis yields win/draw/loss. Cite the reference class
honestly; do not overstate that this project's situation is identical.

**A4. The algorithm — and correct my error.** `roadmap-2026-07-28.md` §2 and
`QA-026` say the existing L/H `converge` machinery is "exactly the right tool."
**That is too strong and I want it fixed.** L and H are the least and greatest
fixpoints; a game with a fixed draw value generally needs a *threshold-attractor*
computation (for each threshold `v`: can the maximiser force a terminal `≥ v`,
or — if `T ≥ v` — force infinite play?). Same infrastructure (state graph, colex
addressing, sweeps), different fixpoint. **Specify the actual algorithm and
argue it correct.** If it does turn out that iterating L/H and pinning `L≠H`
states to `T` is equivalent, prove that; do not assume it.

**A5. The value domain.** A tie is not an area score. With komi 0 the area score
on an odd-point board is always odd, so at 3×3 a tie of 0 lies outside the
natural value set. Specify the domain (`ℤ ∪ {tie}`, tie ordered between −1 and
+1, or an alternative) and how it is represented in a byte-per-slot column.
Another ADR-worthy decision.

**Review requirement — and the independence condition matters more than the
review.** A second agent must attempt to **refute** the proof before Part B is
trusted. But note who wrote this brief: Opus, who proposed QA-023 and wants it
true. A reviewer who reads this document inherits that framing.

So the reviewer must be given **only**: the proof from A1-A5, the two
foreclosures (`ruleset-options.md` RETRO_CYCLE and RETRO_PLY), and the
instruction *"find the flaw; assume one exists."* **Do not** give the reviewer
this brief, the roadmap, or the critique — all three argue for the conclusion.

Record the verdict verbatim, including a reviewer who fails to find a flaw
(that is the outcome we want, and it is only worth something if the reviewer was
genuinely trying). If the reviewer's objection is dismissed, record **why**, in
their words and yours. An objection overruled without a written reason is the
failure mode that produced the `ko_ref >= d` bug — which, per ADR-0013, "looked
obviously correct and was wrong."

---

## Part B — the computational check

> **CORRECTED 2026-07-28 (Opus).** An earlier revision of this brief specified
> the check at **2×2 only**. That was wrong and would have produced a *vacuous
> pass*: **2×2 admits no reachable non-root cycles** (`CLAIMS.md:159`,
> `2x2.T12`; `4x4/EPISTEMIC.md:401`). QA-023 is a claim about how **long cycles**
> are valued — so a board with no long cycles cannot test it. The project has
> already been caught by exactly this once: T12, the C2-pilot at 2×2, came back
> "PARTIAL/tautological" for the same reason. **Do not repeat it.**

Implement the rule in a new standalone file (do NOT touch `src/retro.zig`,
`src/oracle.zig`, `src/rules.zig`, `src/solve.zig`).

**B1 — 2×2 as a smoke test only.** Cheap, and it catches gross errors. But
record explicitly that it **cannot** exercise the cycle semantics, and do not
count it as evidence for QA-023.

**B2 — 3×2 is the real check.** 3×2 *does* admit non-trivial cycles — T13 found
508 reachable non-trivial PSK histories there (`docs/research/c2-falsification-3x2.md`),
which is why 3×2 and not 2×2 was where C2 actually fell.

1. Enumerate all reachable `(board, side, ko_point, passes)` states at 3×2.
2. Solve by the Part-A algorithm.
3. **Independently** brute-force the same game by explicit game-tree evaluation
   carrying full history under the same rule, and compare **every state**.
4. **Report the cycle census:** how many states are only resolved by the
   fixed-value verdict — i.e. how many would be unpinned without it. **If that
   count is zero, the check is vacuous and 3×2 is not sufficient either** —
   escalate and move to 3×3 rather than reporting a pass.

**B3 — Calibration (mandatory).** Show the checker catches a deliberately broken
variant: perturb one state's value and confirm the comparison fails. A checker
with no failing case proves nothing — this is dispatch definition-of-done #4 and
the project has already shipped an uncalibrated auditor once.

**Acceptance:** exact agreement on every 3×2 state, a **non-zero** cycle census,
a passing calibration case, and the adversarial proof review. **Any disagreement
⇒ QA-023 is false ⇒ STOP and escalate.**

## Cross-check you get for free

The published 2×2 value under this ruleset is **0**; weizigo's PSK value is
**+1** (`docs/research/retrograde-3x3.md:224-245` — the two rulesets *provably
disagree* at 2×2 and 2×3). So a correct implementation must return **0**, not
+1. If it returns +1 you have implemented PSK by accident. This is the cheapest
correctness signal available and it costs nothing — check it before anything
else.

---

## Deliverables

- `docs/evidence/QA-023/proof.md` — Part A, with the adversarial review verdict.
- `docs/evidence/QA-023/` — the 2×2 solver source, the brute-force reference,
  both outputs, the calibration run.
- `docs/research/qa023-basicko-markovian-2026-07-28.md` — the findings, every
  claim tagged, the ADR-worthy decisions from A2 and A5 flagged for the user.
- A one-line status for the `CLAIMS.md` owner to fold in (do not edit that file).

## Do NOT

- Do not touch the engine files. Do not touch `data/` or `artifacts/`.
- Do not relitigate the score-on-cycle or PSK foreclosures — they are correct.
  Your job is to show this rule is *different*, not that they were wrong.
- Do not proceed to 3×3 or 4×4. That is EXP-4/5/6 and it is gated on this.
- Do not report success on the 2×2 check alone. Without Part A it is one data
  point on a four-point board, and this project has been burned by exactly that
  kind of evidence before.
