# INTENT — what this project is for, and the principles that govern how it is done

The human's own statement of purpose and the project-global principles, recorded by the Dabir
because they are the most load-bearing things in the project and were, until now, the least
durable: they lived only in conversation, and every roadmap was inferred from memory.

**Everything else in `docs/` is downstream of this file.** If a plan cannot be
traced back to it, the plan has drifted. Correct this file rather than working
around it.

---

## The vision

**Provably perfect Go.** Not strong play, not play that usually wins — play whose
optimality can be *demonstrated*, and a machine that knows the difference.

## The three commitments

**Play optimally.** The engine should choose the best available move, under a
ruleset a human player would recognise as Go.

**Know when it is not.** An engine that plays well and cannot tell you when it is
guessing is less useful than one that plays adequately and always can. Honest
self-knowledge is a first-class deliverable, not a diagnostic afterthought.

**Shrink the gap toward zero.** Where optimality cannot yet be proven, the
distance from it must be measured, published, and made smaller. A known bound
beats an unexamined hope.

## Ambition and realism, held together

The vision is unlimited: provably perfect play, on ever larger gobans.

The practice is unsentimental. **4×4 now** — optimal to best play, while still
reaching for provable perfection rather than settling for adequacy. **5×5 and
beyond** afterwards, provably. Each goban is its own problem and earns its own
proof; none inherits another's.

Where a rule cannot be solved exactly, relax it deliberately, say so plainly, and
measure the distance to the rule we wanted. Where a claim cannot be proven, mark
it unproven. Pragmatism means choosing the tractable path — never quietly
lowering the standard and calling it done.

**The door to perfection is never closed.** A tractable answer today is a rung,
not a destination. No decision may be justified on the grounds that perfection is
unreachable.

## What follows from this

- **Time and cost are subordinate to provable perfection, reliability, and simple elegance.** A
  schedule is a plan, never an excuse to lower a standard. (Operator, 2026-08-19.)
- **A falsification is a result.** Most of what this project knows, it learned by
  being wrong on the record.
- **Evidence outlives agents.** Documentation, working code and the epistemic tree
  are immortal; the agents that produce them are not. Nothing that matters may
  live in a context window, a console, or a message.
- **Standards are not negotiable under pressure.** A test that cannot fail, a
  validation a wrong answer would also pass, a claim whose evidence has been
  deleted — these are not shortcuts. They are how a project comes to believe
  things that are not so.

## The project-global principles (operator, 2026-08-19)

*"In principle we aim for a provably perfect, robust, reliable process, code, and tests. Time
and costs are less important than provable perfection, reliability, and simple elegance."*

1. **Perfection is the constraint; time and cost are not.** Provable correctness, reliability,
   robustness, and simple elegance outrank schedule and spend, always. A tractable answer is a
   rung, never a lowered standard.
2. **Decide at the lowest competent seat.** The Orchestrator makes most questions and decisions
   itself. The operator is not a routing layer; he joins where a scope rule is overturned or the
   path to perfection is provably impossible.
3. **When a decision cannot be made, show the work.** Consider all alternatives, rate them,
   argue against each, and recommend exactly one. No recommendation without the alternatives it
   beat.
4. **When even that is undecidable, run all viable alternatives.** Try them in parallel, select
   the best, or learn the best from the attempts. Experiment is a decision method, not a hedge.
5. **Discuss with the operator only when perfection is provably impossible.** Then compromise or
   change course deliberately — never quietly lower the standard.

**Prescriptions that follow:** every decision is justified by the alternatives it beat; every
number cites its run and states its denominator; evidence outlives agents; a falsification is a
result; a recorded failure with proof is worth more than a `pass` that reinterpreted its brief;
prose is not a remedy for a mechanism failure — a rule that needs an agent to remember it does
not exist.

*Recorded 2026-07-28, amended 2026-08-19. Owned by the Dabir; authored by the human. Amend
freely — this is the one document that is not required to be defended, only to be true to his
intent.*
