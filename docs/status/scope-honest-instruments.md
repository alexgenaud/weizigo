# Scope — Honest instruments

**Status:** scope statement, 2026-08-24. Written by the orchestration seat under the operator's
four-step method: (1) design the ideal solution from scratch, (2) document what exists, both blind to
each other; (3) compare; (4) new spec informed by both, tests first and red, then refactor to green.

**Why this scope and not another.** Ten defects were found on 2026-08-24. Five were instruments
reporting a confident wrong value. Three were checks that reported success while measuring nothing —
which is the same failure, since a check that passes without measuring is an instrument reporting a
reading it never took. Two were duplicated implementations, and that class is already partly specified
and already more than half remediated. So eight of ten fall inside this scope, and every fix to the
other two must be validated by these same instruments: repairing them second means building on readings
already known to lie.

---

## §1 — SHARED INPUT. Both courses receive exactly this section and nothing else from this file.

### Honest instruments — every reading is known, unknown, or refused

Every surface in this system that reports something — a status, a count, a rate, a liveness signal, a
verdict, a test result — must distinguish three outcomes: a value it actually measured, an explicit
statement that it could not determine the value, or a refusal to answer. It may never emit a number, a
zero, or a success to stand in for an absence, and it may never reinterpret input it does not recognise
as though it were something it does recognise. The purpose is that any reading taken from this system
can either be trusted, or be known to be untrustworthy; until that holds, no other change can be shown
to have improved anything, because the only instruments available to judge it are the ones in question.

---

## §2 — FOR COURSE 1 ONLY (design from scratch). Do not read §3.

You are designing from nothing. **Do not read this repository's existing specifications, tools, or
source.** If you find yourself naming a file that exists here, stop — you are documenting, not designing.

Observed symptoms, stated deliberately without naming any component, so that you design for the class of
problem rather than reconstruct the current system:

- A recorded author identity was a test fixture's rather than the real one, for 680 of 1,415 saved revisions.
- A throughput figure was displayed at 15% of its true value, because a per-item quantity was aggregated
  by taking a maximum rather than a sum. It looked plausible for weeks.
- A summary line reported a failure count of 5 for a check whose own detail section reported 0, because
  non-failing items were folded into a failing counter.
- Forty completed units of work were recorded as not started, and dependency links continued to wait on
  them after the evidence of completion existed on disk.
- A liveness display attributed a stale signal from an abandoned attempt to a live one, and named the
  wrong worker.
- Three checks reported success while measuring nothing; one could not fail under any input.
- An unrecognised command-line option was silently reinterpreted as a different, valid command.
- A newly added guard refused legitimate writes inside test fixtures, which is how a guard gets disabled.

Deliver: the simplest design that makes the §1 property hold for a system of this kind, the contract
each reporting surface must satisfy, and how conformance is tested. State what you deliberately leave
out and why. Simplicity is the deliverable, not coverage.

---

## §3 — FOR COURSE 2 ONLY (document what exists). Do not read §2. Do not propose a design.

Describe what this repository actually does today, as it is, without judgement and without proposing
changes. Every mechanism you describe must carry a `file:line` citation, because line references in this
project have been measured to drift. Where two mechanisms do the same job, say so and cite both. Where a
surface reports a value, state exactly what it does when it has no data. Where a check exists, state
what would have to break for it to fail — and if nothing would, say that.

Deliver: an inventory of every reporting surface and every check, what each does with absent or
contradictory input, and which of them share a job. **An honest "this mechanism's purpose is unknown to
me" is a result, not a gap.** Do not invent a rationale for anything.

---

## Sequencing note

Course 2 is roughly three times the work of course 1 and decides whether the comparison is fair: a thin
description of what exists will lose to a rich design regardless of merit, so it is resourced heavier and
its citations are mandatory. Neither course sees the other's output until both are closed.
