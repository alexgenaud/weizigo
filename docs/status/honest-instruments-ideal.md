# Honest instruments — ideal design (blind course)

**Task:** T857 · **Author:** ox-alpha/T857 · **Date:** 2026-08-24
**Landmark:** advances L1 (the dashboard tells the truth)

**Blindness statement.** This document was designed from scratch against the
problem class described in the task brief. It deliberately names no component,
file, tool, or identifier of the system it will be compared against; the
symptoms it designs for are quoted generically in the brief and restated
generically here. The comparison this feeds is only meaningful if this side of
it is uncontaminated.

---

## 0. The property

**Every reading is known, unknown, or refused.**

A *reporting surface* is anything that emits a value meant to be believed: a
status line, a count, a rate, a liveness indicator, a verdict, a pass/fail
result. The property has two halves:

1. **Trivalence.** Each emission is exactly one of:
   - **Measured** — a value the surface actually determined, with provenance;
   - **Unknown** — an explicit statement that the value could not be
     determined, with a reason;
   - **Refused** — an explicit statement that the surface will not answer
     this input, with a reason.
2. **No fabrication.** No emission stands in for an absence: never a zero for
   "did not look", never a success for "measured nothing", never a default
   name for "did not know who", never a reinterpretation of unrecognised
   input as recognised input.

Until this holds, no other improvement is measurable — the judging
instruments are themselves in question.

## 1. The contract

A surface **conforms** iff all seven clauses hold. Each clause is decidable by
inspection: hold the surface's emissions (and, for C7, its demonstrated
behaviour) against the clause and answer yes or no. No clause is aspirational;
none contains "should", "usually", or "where possible".

**C1 (trivalence).** Every emission is `Measured(value)`, `Unknown(reason)`,
or `Refused(reason)` — and nothing else. There is no fourth state, no null,
no implicit default, no "empty means zero".

*Inspection:* enumerate the surface's possible outputs (from its type or its
code paths). If any output is not one of the three tagged forms — including
bare numbers, bare strings, booleans standing alone — the clause fails.

**C2 (provenance).** Every `Measured` value records: what produced it, over
what population (denominator), and when. A number without its denominator is
not a reading.

*Inspection:* for each emitted `Measured`, find the provenance triple. If any
element is absent, the clause fails.

**C3 (total refusal of the unrecognised).** An input the surface does not
recognise produces `Refused("unrecognised: <input>")`. There is no execution
path that maps unrecognised input to a recognised interpretation — no
prefix-match fallback, no nearest-command guess, no silent skip.

*Inspection:* for each parse/dispatch branch, verify the fall-through case is
refusal. If the fall-through reaches a valid handler, the clause fails.

**C4 (derived counts).** Every aggregate in a report is computed from the
enumerated details of that same report, at report time. No counter is
maintained separately from the enumeration it summarises.

*Inspection:* for each number in a summary, trace its computation. If it is
incremented anywhere other than inside the loop that produces the details it
summarises — or aggregated by any function other than the sum/count over those
details — the clause fails.

**C5 (birth-time identity).** Attribution (who authored, who owns, who acted)
is captured once, at record creation, from the acting context itself. If the
context cannot supply an identity, the field is `Unknown("no identity at
creation")`. Identity is never defaulted from ambient or fixture state, and
never back-filled later.

*Inspection:* find where each attributed field is written. If the writing
site can execute with a default, placeholder, or inherited-from-environment
identity, the clause fails.

**C6 (expiring claims).** Any claim about current state — alive, running,
fresh, up to date — carries the timestamp of its last evidence and expires to
`Unknown("stale since <t>")` after a stated horizon. A liveness signal cannot
outlive its evidence, and attribution travels with the signal, so a dead
attempt's signal can never be displayed as another attempt's life.

*Inspection:* for each such claim, verify both the timestamp and the
expiry-to-Unknown transition exist. A claim readable after its horizon without
degrading to Unknown fails the clause.

**C7 (falsifiable checks).** For every check — anything that can report
success/failure — there exists a demonstrated input that makes it report
failure and a demonstrated input that makes it report success, both held as
committed fixtures and exercised through the check's own code path. A check
with no demonstrated failing input is not measuring anything and reports
`Unknown("no falsifier exists")`, not success.

*Inspection:* point at the known-bad fixture and at the recorded failure it
provoked through the live path. If either does not exist, or the check
passes on the known-bad fixture, the clause fails.

## 2. The smallest design

One mechanism, four applications. The mechanism is the **tri-state reading**
of C1: a single sum-type at every emission boundary, whose `Measured` arm is
unconstructible without provenance (C2) and whose `Unknown`/`Refused` arms are
unconstructible without a reason. Make the dishonest states unrepresentable
and the honest ones mandatory; everything else follows from where the type is
required.

Why one mechanism and not several: each symptom in the brief is a place where
a two-valued world (worked/didn't, number/no-number, seen/not-seen) was forced
to encode a third condition it had no symbol for, and chose whichever of its
two symbols was nearer — zero, success, someone else's name. Trivalence is not
one fix among many; it is the shared root. Separate mechanisms for parsing
strictness, counter hygiene, identity, and staleness would be four ways of re-
discovering that. So: the type is the whole design; below are merely the four
places it must reach.

1. **Boundaries, not internals.** The tri-state type is required at every
   surface that crosses out of the instrument (display, log, saved record,
   IPC reply). Internal computation may stay total and ordinary; the obligation
   attaches at emission, where belief happens.
2. **Parsing is refusal-complete (C3).** Dispatch tables end in an explicit
   refusal arm. Because refusals are values, a refused command can be reported
   loudly instead of silently rerouted — which also surfaces typos and stale
   call-sites instead of laundering them.
3. **Aggregates are folds (C4).** Summary numbers are defined in code as
   folds over the detail enumeration, textually adjacent to it. Parallel
   counters are forbidden by inspection of C4, not by convention.
4. **Claims are leases (C5, C6).** Identity and liveness are written once,
   at the moment of evidence, stamped, and left to expire. Expiry is a pure
   function (evidence-time + horizon), so it needs no background process and
   cannot forget to run.

What makes this *small*: no central honesty service, no monitoring daemon, no
new persistence layer. It is a type discipline plus four placement rules, all
enforceable locally at each surface.

## 3. Testing conformance

Clause-by-clause, plus one meta-test that catches the vacuous checker.

- **C1/C2 — shape test.** Serialise a surface's output across a sampled
  corpus of runs; assert every record parses as one of the three tags and
  every `Measured` carries the provenance triple. Mechanical, cheap, run in CI.
- **C3 — garbage test.** Feed each parser/dispatcher a fixed corpus of
  malformed, truncated, misspelled, and plausible-but-wrong inputs. Assert
  every one yields `Refused` with the echo of the input, and that program
  behaviour afterwards is identical to a session in which the input was never
  sent. The plausible-but-wrong cases matter most: they are exactly the ones a
  fallback path quietly absorbs.
- **C4 — recount test.** Independently recompute each summary from the
  emitted details and assert equality. Additionally assert conservation: the
  parts' categories partition the population (every item counted somewhere,
  nothing counted twice). The 15%-low throughput symptom and the 5-vs-0
  summary/detail split are both caught here, because both violate the fold.
- **C5 — identity injection test.** Run record creation under a controlled
  acting context; assert the stored identity equals the injected one, and that
  running with *no* context yields `Unknown`, not a default. Seed the
  environment with a decoy identity (the way test fixtures leak theirs) and
  assert it does not appear in any record.
- **C6 — clock test.** Freeze time at evidence-writing; advance past the
  horizon; assert the claim now reads `Unknown("stale …")`. Then kill the
  attempt that wrote a live claim, start a second attempt, and assert the
  display attributes nothing of the first attempt to the second.
- **C7 — anti-vacuity harness.** This is the load-bearing test policy, and it
  is a *meta*-requirement:
  1. Every check ships with two committed fixtures: **known-good** (must
     pass) and **known-bad** (must fail).
  2. Both fixtures are exercised **through the check's real code path** — a
     positive control routed around the defective site covers nothing.
  3. The suite asserts the known-bad fixture *fails*. Therefore a check that
     cannot fail turns the suite red, which converts "cannot fail" from an
     invisible property into a build breakage.
  4. Periodically, mutate the checked artefact (introduce each historically
     observed defect class — swapped aggregation operator, folded failure
     counter, leaked fixture identity) and confirm the corresponding check
     trips. A mutation that survives means some check is decorative.
  5. Treat impossibly clean counters as failures in themselves: a guard with
     `violations: 0` across every run ever recorded, on an artefact whose
     honest history includes violations, is reported as suspect, not
     reassuring.

Conformance of a given surface is then decidable exactly as §1 promised: run
the six mechanical tests, inspect for the seven clauses, answer yes or no.

## 4. What is deliberately left out

- **Confidence scores instead of trivalence.** A continuous certainty value
  invites threshold-tuning and reintroduces the two-symbol problem (is 0.3
  known or unknown?). Three crisp states with reasons are strictly easier to
  act on. Left out on purpose.
- **Automatic repair, retry-until-green, self-healing staleness.** Anything
  that clears an `Unknown` without fresh evidence is a fabrication generator.
  Recovery is a human or upstream decision, visible as a new event.
- **Cryptographic provenance chains / tamper-evidence.** C2 asks where a value
  came from, not whether someone lied about it. Tamper-evidence is a real
  property but a different threat model (adversary vs incompetence); adding it
  would double the design's size. Omitted.
- **Fuzzy input correction ("did you mean…").** Genuinely useful UX, and
  directly opposed to C3. Surfaces may offer suggestions alongside a `Refused`,
  but never auto-execute the guess. The suggestion is free; the auto-execution
  is the omission.
- **Central honesty monitor that audits other components.** Tempting, because
  it promises coverage without touching each surface. Rejected: it recreates
  the original sin — a surface vouched for by something other than its own
  construction — and becomes a single point of the very dishonesty it watches
  for. Conformance lives in the type and the per-surface tests.
- **Backward-compatible tolerance layers.** Old two-valued emitters are not
  wrapped or shimmed into the new type with heuristic conversion; they are
  marked non-conforming until rewritten. A heuristic converter is precisely a
  path that maps unknown-ish input to measured-looking output.

## 5. Where this design is expensive or annoying

- **Unknown-handling verbosity.** Every consumer must plan for three cases,
  and most UIs have no natural display for `Unknown(reason)`. Expect a long
  tail of "what do we even show here?" decisions, and pressure to collapse
  Unknown into zero/success — i.e., pressure to regress the whole property at
  the presentation layer, the exact place the discipline is easiest to lose.
- **Strict refusal breaks users and scripts.** Misspelled flags, legacy
  invocations, and near-miss inputs that used to work-by-luck now stop. The
  first weeks after adoption generate noise that looks like the design being
  hostile, and some of it will be.
- **Fixture maintenance doubles.** Every check needs a kept-current pair of
  fixtures, and the mutation probes (§3, C7.4) add recurring effort. When the
  artefacts under check change shape, twice as many fixtures go stale.
- **Lease tuning.** Horizons too short produce false `Unknown`s during slow
  legitimate runs, training people to ignore staleness — which is worse than
  no expiry. Horizons are configuration that must be revisited whenever
  workload latency changes.
- **Recomputation cost.** Fold-derived aggregates (C4) recompute at report
  time instead of maintaining cheap incremental counters. On large populations
  or hot paths this is measurably slower, and the temptation to cache an
  aggregate off-loop must be resisted because it is precisely the defect C4
  forbids.
- **Adoption is all-or-nothing per surface.** Half-trivalence (tri-state type,
  but a fallback parse path retained "temporarily") is worth little, because
  C3 violations launder garbage into Measured readings downstream of
  otherwise-honest surfaces. Each surface's migration is a hard cutover.

---

*End of blind design. No repository file, tool, or identifier is referenced
above; the findings record for this task states what was and was not read.*
