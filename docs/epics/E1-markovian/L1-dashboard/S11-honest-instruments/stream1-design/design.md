# Honest instruments — the ideal design

**Task:** T865 · **Author:** deepseek-v4-flash/T865 · **Date:** 2026-08-24
**Landmark:** advances L1 (the dashboard tells the truth)
**Stream:** stream1-design — the single final document of the design phase, reconciled from two blind arms.
**Revision:** 1 · **Status:** RECONCILED — produced from both arms; phase grade pending per STATUS.md.

**Provenance and scope.** Two workers designed independently, blind to each other and to this
repository. This document is their consolidation. It verifies that their convergence is real (§1),
records where they differ and chooses each difference with a reason (§5), and carries both arms'
honest sections forward: what is deliberately left out (§6) and where this design is expensive or
annoying to live with (§7). A consolidation that dropped the costs would be worse than either arm,
so nothing of either honest section is dropped. The arms are described here in prose rather than
cited, because they live in the untracked working tree and are not durable citations.

**This is an ideal design.** It is not adjusted to fit what this repository currently does; that
comparison is a later stream's job, and contaminating the ideal with present constraints destroys
its only value.

---

## 0. The property

**Every reading is Measured, Unknown, or Refused — never a confident wrong value.**

A *reporting surface* is anything that emits a value meant to be believed: a status line, a count, a
rate, a liveness indicator, a verdict, a pass/fail result, a summary. The property has two halves:

1. **Trivalence.** Each emission is exactly one of:
   - **Measured(value)** — the surface actually determined the value in this invocation, with its
     provenance (clause 2);
   - **Unknown(reason)** — the surface attempted to determine the value and could not, naming what
     was attempted and what blocked it;
   - **Refused(reason)** — the surface will not answer this input, naming why.
2. **No fabrication.** No emission stands in for an absence: never a zero for "did not look", never a
   success for "measured nothing", never a default name for "did not know who", never a
   reinterpretation of unrecognised input as recognised input.

Until this holds, no other improvement is measurable — the judging instruments are themselves in
question.

---

## 1. Convergence — the arms agree, and the agreement is real

Both arms were written from the same symptom list and no shared source. Each names a **closed
three-valued result type returned by every reporting surface** as the entire mechanism: a value arm
that is unconstructible without provenance, and unknown/refused arms that are unconstructible
without a reason. Each makes a false reading *unrepresentable* rather than discouraged. Each
structures its contract as **seven clauses decidable by inspection**. The shared clause count is
itself a structural finding: seven independent yes/no questions suffice.

The convergence is real, and it is not two ideas wearing similar words. Evidence it is not
phrase-matching: the arms use different vocabulary throughout — the value arm is called "Measured"
in one and "Known" in the other, one speaks of "clauses", the other of "requirements", one reaches
for lease language and the other for witness language — yet they converge on the same seven
obligations. They also converge on the *rejections*: both independently reject a two-valued
Option/Maybe (it loses the Unknown/Refused distinction and the reason), out-of-band error codes or
a status field beside the value (the caller can ignore the status and read the default), a nullable
record (reintroduces the sentinel; the value and its present/absent flag can disagree), and
confidence-valued readings (a fourth "sort of known" state weakens decidability). Independent
convergence on the mechanism *and* on the same set of rejected alternatives is evidence about the
problem, not about the authors: every symptom in the brief is a place with two possible answers
being asked to express a third condition it had no symbol for, and it emitted the nearest symbol it
had — zero, success, or another party's name. Trivalence is the shared root.

Where one arm is stronger than the other, the difference is strength, not direction; the
consolidation keeps the stronger form rather than averaging (§5). In no case do the arms propose
different answers to the same question.

---

## 2. The mechanism — one type, one rule, four placements

### The type

A single **closed** three-valued sum type, `Reading<T>`, required at every emission boundary. Its
constructors are:

- `Measured(provenance, value)` — unconstructible without the provenance record (clause 2);
- `Unknown(reason)` — unconstructible without a non-empty reason (clause 3);
- `Refused(reason)` — unconstructible without a non-empty reason.

*Closed* means sealed: no fourth constructor may be added and no open union extended with a
"best-effort float". A number cannot stand in for an absence if the type has no way to put a bare
number there. A caller of a reporting surface handles all three constructors explicitly and never
applies a blanket "unwrap, default to zero/success"; any default is a deliberate per-call-site
choice that itself records why a default is being substituted.

### Four placements — where the type must reach

1. **Boundaries, not internals.** The type is required at every surface that crosses out of the
   instrument — display, log, saved record, IPC reply. Internal computation may stay total and
   ordinary; the obligation attaches at emission, where belief happens.
2. **Parsing is refusal-complete.** Every dispatch table ends in an explicit refusal arm. Because
   refusals are values, a refused input is reported loudly instead of silently rerouted — which
   surfaces typos and stale call-sites instead of laundering them.
3. **Aggregates are folds.** Summary numbers are defined in code as folds over the detail
   enumeration, textually adjacent to it. Parallel counters are forbidden by inspection, not by
   convention.
4. **Claims are leases.** Identity and liveness are written once, at the moment of evidence,
   stamped, and left to expire. Expiry is a pure function (evidence-time + horizon), so it needs no
   background process and cannot forget to run.

Why one mechanism: every symptom is a place with two possible answers being asked to express a third
condition it had no symbol for. Separate mechanisms for parsing strictness, counter hygiene,
identity, and staleness would be four ways of re-discovering that. What makes this *small*: no
central honesty service, no monitoring daemon, no new persistence layer — a type discipline plus
placement rules, all enforceable locally at each surface.

### What the mechanism does not solve — stated plainly

- **It does not make unmeasurable things measurable.** If the instrument genuinely cannot determine
  a value, the type's only contribution is that the absence is now visible as `Unknown`. The type is
  honesty plumbing, not a measurement engine.
- **It does not certify that a Measured value is true.** It guarantees the reading is what the
  instrument determined, with provenance; it does not guarantee the instrument is right. Provenance
  makes wrongness detectable — recompute, re-run, inspect — not impossible.
- **It does not detect disagreement between independent surfaces.** Within one surface,
  summary-vs-detail divergence is unrepresentable (clause 4). Between two surfaces, agreement is a
  separate property — consistency, not honesty — and needs a separate detector.
- **It does not guard against an adversary.** Provenance answers where a value came from, not
  whether someone lied about it. Tamper-evidence is a different threat model.
- **It does not repair what it reveals.** Once a false rate is honestly surfaced as a reading,
  fixing the rate is a different problem.
- **It does not convert legacy emitters.** Old two-valued surfaces are marked non-conforming until
  rewritten; a heuristic converter would be exactly a path that maps unknown-ish input to
  measured-looking output.

---

## 3. The contract — seven clauses, decidable by inspection

A surface **conforms** iff all seven clauses hold. Each clause is decidable by inspection: hold the
surface's emissions (and, for C7, its demonstrated behaviour) against the clause and answer yes or
no. No clause is aspirational; none contains "should", "usually", or "where possible".

**C1 — Trivalence.** Every emission of the surface is exactly one of `Measured(value)`,
`Unknown(reason)`, or `Refused(reason)` — and nothing else. There is no fourth state, no null, no
implicit default, no "empty means zero", no reserved value that means "no reading". A count of zero
items is `Measured(0)` — a real measurement, not the same thing as not knowing the count.
*Inspection:* enumerate the surface's possible outputs from its type and its code paths. If any
output is not one of the three tagged forms — including bare numbers, bare strings, booleans
standing alone, sentinel values — the clause fails.

**C2 — Provenance.** Every `Measured` value carries: the operation that produced it, the set of
contributing inputs (or the contributor count and denominator), the identity of the subject
measured, and the time. The value is recomputable from the carried fields alone.
*Inspection:* for each emitted `Measured`, reconstruct the value from its carried fields. If any
field is absent, or the reconstruction disagrees with the emitted value, the clause fails.

**C3 — Total refusal of the unrecognised.** An input the surface does not recognise produces
`Refused("unrecognised: <input>")`, echoing the raw input verbatim. No execution path maps
unrecognised input onto a recognised interpretation — no prefix-match fallback, no nearest-command
guess, no silent skip.
*Inspection:* walk every parse/dispatch branch. If any fall-through reaches a valid handler rather
than a refusal that quotes the raw input, the clause fails.

**C4 — Derived aggregates.** Every aggregate in a report is computed from the enumerated details of
that same report, at report time, as a sum/count fold over those details. The summary and its
detail section are projections of the same object; no counter is maintained separately from the
enumeration it summarises.
*Inspection:* trace each summary number to its computation. If it is incremented anywhere other
than inside the loop that produces the details it summarises — or aggregated by any function other
than the fold over those details — the clause fails.

**C5 — Birth-time identity.** Attribution (who authored, who owns, who acted) is captured once, at
record creation, from the acting context itself. Every identity or liveness reading names its
subject and carries the evidence that binds the reading to that subject — a process id, a worker
id, an artifact hash, a timestamp of observation. If the context cannot supply an identity, the
field is `Unknown("no identity at creation")`. Identity is never defaulted from ambient or fixture
state, never inherited from the environment, never back-filled later.
*Inspection:* find where each attributed field is written. If the writing site can execute with a
default, placeholder, or environment-inherited identity, or if any identity/liveness reading lacks
its binding evidence, the clause fails.

**C6 — Expiring claims.** Any claim about current state — alive, running, fresh, up to date —
carries the timestamp of its last evidence and expires to `Unknown("stale since <t>")` after a
stated horizon. A liveness signal cannot outlive its evidence, and attribution travels with the
signal, so a dead attempt's signal can never be displayed as another attempt's life. Expiry is a
pure function of evidence-time and horizon; it needs no background process.
*Inspection:* for each such claim, verify both the timestamp and the expiry-to-Unknown transition
exist. A claim readable after its horizon without degrading to Unknown fails the clause.

**C7 — Falsifiable checks.** Every check — anything that can report success/failure — has a
demonstrated input that makes it report failure and a demonstrated input that makes it report
success, both held as committed fixtures and exercised through the check's own code path; the two
fixtures differ only in the property being measured, never in which code path runs. A check with no
demonstrated failing input is not measuring anything and reports `Unknown("no falsifier exists")`,
not success, and is refused conformance.
*Inspection:* point at the known-bad fixture and at the recorded failure it provoked through the
live path. If either does not exist, if the check passes on the known-bad fixture, or if the
fixture pair changes more than the one measured property, the clause fails.

---

## 4. Conformance testing

Conformance of a given surface is decidable exactly as §3 promised: run the mechanical tests,
inspect for the seven clauses, answer yes or no. The verdict is binary and per surface: no partial
conformance, no "mostly". The whole system's honesty is the conjunction of its surfaces'
conformance.

**T1 — Declaration gate (static).** A lint walks the reporting surfaces and fails any whose
declaration returns a bare value rather than `Reading`. Catches C1 at declaration time, before
anything runs.

**T2 — Shape test (runtime).** Serialise a surface's output across a sampled corpus of runs;
assert every record parses as exactly one of the three tags, and every `Measured` carries the
recomputable provenance record. Mechanical, cheap, run in CI.

**T3 — Absence injection.** Empty, withhold, or block the surface's input source — empty store,
unset variable, dependency that never answers — and assert the surface returns `Unknown(reason)`,
never `Measured(0)`, never success. Catches "zero for did not look" and "completed work recorded
as not started".

**T4 — Unrecognised-input injection.** Feed each parser/dispatcher a fixed corpus of malformed,
truncated, misspelled, and plausible-but-wrong inputs; assert every one yields `Refused` with the
raw input echoed, and that program behaviour afterwards is identical to a session in which the
input was never sent. The plausible-but-wrong cases matter most: they are exactly the ones a
fallback path quietly absorbs.

**T5 — Recount test.** Independently recompute each summary from the emitted details and assert
equality; assert conservation — the categories partition the population, nothing counted twice,
nothing uncounted. For any count/sum/rate surface, feed a known multi-item input (say three items
of magnitudes 1, 2, 3) and assert the aggregate equals the reference sum (6), that its denominator
is the contributor count (3), and that the provenance names the aggregation operation. Catches
max-for-sum and folded-counter defects directly.

**T6 — Identity injection.** Run record creation under a controlled acting context; assert the
stored identity equals the injected one, and that running with no context yields `Unknown`, not a
default. Seed the environment with a decoy identity — the way test fixtures leak theirs — and
assert it appears in no record.

**T7 — Clock test.** Freeze time at evidence-writing; advance past the horizon; assert the claim
now reads `Unknown("stale since …")`. Kill the attempt that wrote a live claim, start a second
attempt, and assert the display attributes nothing of the first to the second.

**T8 — The anti-vacuity harness.** This is the load-bearing test policy, and it is a
*meta*-requirement. A check that cannot fail cannot produce a known-bad fixture, so vacuity is
made structurally detectable:

1. Every check ships two committed fixtures: **known-good** (must pass) and **known-bad** (must
   fail).
2. Both are exercised **through the check's real code path** — a positive control routed around
   the defective site covers nothing.
3. The suite asserts the known-bad fixture *fails*. A check that cannot fail therefore turns the
   suite red: "cannot fail" is converted from an invisible property into a build breakage.
4. **Path-equality rule.** The two fixtures differ only in the property being measured, never in
   which code path runs — mechanically identical except for the one input bit that should flip the
   reading. A fixture pair that changes two things at once is rejected. This is asserted by
   review, and it is the least automatable part of the design: the dodge it catches — a trivial
   known-bad that does not exercise the measurement path — is invisible to the harness.
5. A check that cannot produce a known-bad fixture is *defined* as vacuous: it measures nothing.
   Its author either admits there is no bad input, and the check is refused conformance, or lies
   about the fixture, and the harness catches the mismatch.
6. Periodically mutate the checked artefact — introduce each historically observed defect class
   (swapped aggregation operator, folded failure counter, leaked fixture identity) — and confirm
   the corresponding check trips. A mutation that survives means some check is decorative.
7. Impossibly clean counters are failures in themselves. A guard reporting `violations: 0` across
   every run ever recorded, on an artefact whose honest history includes violations, is reported
   as suspect, not reassuring.

**The suite's own report is a Reading.** The gate never emits a bare "green". Its output is
`Measured(all N pass)`, `Measured(k of N fail, naming each failing surface)`, or
`Unknown("suite did not execute: <reason>")` when the harness itself failed to run. A green display
whose harness crashed is therefore unrepresentable. The instrument that judges honesty is itself
held to the contract it enforces.

**Trigger.** The conformance suite is part of the build gate: it runs on every change, with no flag
to skip it. A calendar trigger runs it on a fixed cadence even when nobody has committed, because
"the gate runs on commit" silently becomes "never" in a system where commits are sparse.

**Consequence: fix or demote, never accumulate.** A failing surface is either fixed, or individually
demoted to a visible **known-broken register** with an owner and an expiry date. There is no third
state and no "expected failure" bucket that absorbs failures silently. If 23 of 86 fail, the
register reads `Measured(23 of 86 broken)` and names all 23; the remaining 63 are the only surfaces
whose readings may be trusted. The register is itself a reporting surface — it returns a `Reading`
and is subject to T1–T8 — so it cannot quietly report "all fine" while listing nothing. A demotion
is a *dated* decision; an expired demotion with no owner is reported as `Unknown` until someone
re-owns it.

---

## 5. Where the arms differ, and the choice

Two differences are genuine choices; the rest are complementary strengths, adopted in full. Each is
recorded rather than averaged, and each records its reason.

**5.1 Staleness: witness vs expiry — a genuine difference; choose expiry.**
One arm requires every liveness reading to carry a freshness witness (the evidence binding the
reading to its subject and its time) but does not require the reading itself to lapse. The other
requires the claim to expire to `Unknown("stale since <t>")` after a stated horizon. Under the
witness-only letter, a witnessed-but-stale "alive" could be presented as a current reading forever.
**Chosen: mandatory expiry, with the witness kept as the content of the evidence.** Reason: the
property itself — a claim whose evidence has expired is not a reading the surface determined, and
presenting it as `Measured` is exactly the fabrication class the design exists to make
unrepresentable. The witness is retained because it is the substance of what the timestamp is and
because it makes the expiry a computation the reader can verify. Expiry as a pure function of
evidence-time and horizon also removes the "forgot to run the janitor" failure mode.

**5.2 The vacuous check: honest emission vs refused conformance — a resolution, not an average.**
One arm makes vacuity a contract clause: a check with no demonstrated failing input is not
measuring anything and reports `Unknown("no falsifier exists")`, not success. The other makes
vacuity a harness refusal: a check that cannot produce a known-bad fixture is refused conformance.
**Both kept — they are different obligations.** The emission requirement binds the surface's output
while it exists, so the vacuous check never lies; the conformance refusal binds the harness's
verdict, so the vacuous check is never counted as a conformant instrument. A vacuous check must do
both: report `Unknown`, and be refused.

**5.3 Provenance: producer-population-time vs recomputability — complementary; recomputability is
the testable invariant, time is added.**
One arm's provenance triple is (what produced it, over what population, when). The other's is
recomputability: the value must be recomputable from the fields carried by the reading alone
(operation, contributing inputs or count + denominator, subject identity). **Chosen: recomputability
as the testable invariant, with the timestamp added.** "Can I recompute the value from the carried
fields" is the clause an inspector can actually verify; the timestamp is required anyway by clause
6's expiry.

**5.4 Identity: birth-time capture vs subject-and-witness — complementary; union in clause 5.**
One arm specifies *when and how* identity is captured: once, at record creation, from the acting
context; `Unknown` if the context cannot supply one; never defaulted, never back-filled. The other
specifies *what the reading carries*: the subject's identifier and the evidence binding the reading
to that subject. **Chosen: both.** The subject-and-witness is the reading's content; the birth-time
rule is the discipline that keeps that content honest — a witness captured later, or defaulted from
the environment, is a fabricated witness.

**5.5 The caller rule — an addition, adopted.**
One arm adds a rule the other does not state: callers must handle all three constructors
explicitly, and any default must be a deliberate per-call-site choice that records why. **Adopted.**
Reason: the arm that omits it names the design's worst cost — pressure to collapse `Unknown` into
zero/success at the presentation layer — and the caller rule is the mechanism that pays that cost.
Keeping the cost named without the rule would leave the disease diagnosed but untreated.

**5.6 The known-broken register and the suite-as-Reading — one arm's contribution, kept in full.**
One arm addresses how conformance keeps running and how failures are prevented from accumulating
(the register, the self-Reading, the calendar trigger); the other does not. The silence is an
omission, not an objection, so the contribution is kept in full (§4). The register and the
self-Reading are the parts of the testing story that close the loop.

**5.7 Terminology: "Measured" vs "Known" — a spelling choice, recorded.**
The arms name the value arm differently. Same semantics: the surface actually determined the value
in this invocation. **Chosen: Measured**, which cannot be misread as "the system knows it from
anywhere"; the definition is stated in clause 1 regardless. Recorded so the arms' convergence is
not mistaken for a semantic difference.

---

## 6. What is deliberately left out

- **Partial / confidence-valued readings.** There is no `Measured` with a confidence interval, no
  "best-effort value with an error bar", no fourth "sort of known" state. Anything short of a real
  measurement is `Unknown`. A continuous certainty value invites threshold-tuning and reintroduces
  the two-symbol problem (is 0.3 known or unknown?); three crisp states with reasons are strictly
  easier to act on.
- **Automatic repair, retry-until-green, self-healing staleness.** Anything that clears an
  `Unknown` without fresh evidence is a fabrication generator. Recovery is a human or upstream
  decision, visible as a new event.
- **Cryptographic provenance chains / tamper-evidence.** Provenance asks where a value came from,
  not whether someone lied about it. Tamper-evidence is a real property but a different threat
  model (adversary vs incompetence); adding it would double the design's size.
- **Fuzzy input correction ("did you mean…") as auto-execution.** Genuinely useful UX, and directly
  opposed to refusal-completeness. Surfaces may offer suggestions alongside a `Refused`, but never
  auto-execute the guess. The suggestion is free; the auto-execution is the omission.
- **A central honesty monitor that audits other components.** Tempting, because it promises
  coverage without touching each surface. Rejected: it recreates the original sin — a surface
  vouched for by something other than its own construction — and becomes a single point of the very
  dishonesty it watches for. Conformance lives in the type and the per-surface tests.
- **Backward-compatible tolerance layers.** Old two-valued emitters are not wrapped or shimmed into
  the new type with heuristic conversion; they are marked non-conforming until rewritten. A
  heuristic converter is precisely a path that maps unknown-ish input to measured-looking output.
- **Full data lineage.** `Measured` carries enough provenance to recompute the value — not a
  complete audit trail of every intermediate step. Lineage is a data-engineering problem; the
  honesty contract requires recomputability, not lineage.
- **Cross-surface reconciliation.** A layer that detects when two different surfaces disagree is a
  real detector but a separate property (consistency vs honesty), and adding it would double the
  design.
- **Remediation.** This designs honest reporting, not the repair of whatever the readings reveal.
  A broken guard, a wrong author identity, a false rate — once honestly surfaced, fixing them is a
  different problem.
- **Migration of existing surfaces.** How a legacy bare-value surface is converted to `Reading` is
  deliberately unspecified: the target is the contract; the porting effort is mechanical and
  project-specific.
- **Performance engineering of provenance.** Recording provenance on every reading has a real cost
  (§7); no optimization is designed for it, because an optimization that drops provenance silently
  reverts the contract, and any such optimization needs its own honest justification.

---

## 7. Where this design is expensive or annoying to live with

- **Every caller branches three ways, forever.** The single most annoying cost: code that used to
  read a number now must pattern-match on `Measured` / `Unknown` / `Refused` and say what it does in
  each case. The standing temptation — and the thing the design must forbid — is the "unwrap,
  default to zero/success" helper, because that helper *is* the lie, reintroduced at the call site.
  This is a permanent ergonomic tax, and it is the price of honesty. A design that pretends this is
  free will have the helper smuggled back in within a week.
- **Unknown-handling verbosity, and the presentation-layer collapse.** Every consumer must plan for
  three cases, and most UIs have no natural display for `Unknown(reason)`. Expect a long tail of
  "what do we even show here?" decisions, and pressure to collapse `Unknown` into zero/success at
  the presentation layer — the exact place the discipline is easiest to lose.
- **Provenance and recomputation overhead.** Carrying operation, inputs, denominator, subject and
  time on every reading costs memory and CPU, worst for high-frequency counters where the reading
  is taken millions of times and the provenance is read rarely. Fold-derived aggregates recompute
  at report time instead of maintaining cheap incremental counters; the temptation to cache an
  aggregate off-loop must be resisted, because it is precisely the defect clause 4 forbids. None of
  this can be engineered away silently.
- **Strict refusal breaks users and scripts.** Misspelled flags, legacy invocations, and near-miss
  inputs that used to work-by-luck now stop. The first weeks after adoption generate noise that
  looks like the design being hostile — and some of it is.
- **Fixture maintenance doubles, and the shortcut is invisible.** Every check needs a kept-current
  known-good/known-bad pair, and the mutation probes add recurring effort. When the artefact under
  check changes shape, twice as many fixtures go stale. Authors will try to dodge the work by
  writing a trivial known-bad that does not exercise the measurement path, and catching that dodge
  is human review work — the least automatable part of the design.
- **Lease tuning.** Horizons too short produce false `Unknown`s during slow legitimate runs,
  training people to ignore staleness — which is worse than no expiry. Horizons are configuration
  that must be revisited whenever workload latency changes.
- **The known-broken register wants to become a graveyard.** "Fix or demote, never accumulate" is a
  magnet for "demote and forget". The expiry mechanism fights this, but expiry is itself a clock
  that someone must wind. This is the part of the design most likely to rot first.
- **Latency of honesty.** Surfaces that genuinely cannot determine a value now force their
  consumers to stop and branch where they used to read a default and move on. This is correct, but
  it is *annoying*, and it will be felt as a slowdown by anyone who relied on the fake number being
  there.
- **All-or-nothing adoption per surface.** Half-trivalence — the tri-state type with a fallback
  parse path retained "temporarily" — is worth little, because a refusal-completeness violation
  launders garbage into `Measured` readings downstream of otherwise-honest surfaces. Each surface's
  migration is a hard cutover.

---

*End of the consolidated ideal design. No repository file, tool, or identifier is cited above; the
arms it consolidates are described in prose. The comparison against what this repository currently
does is a later stream's job and was deliberately not attempted here.*
