# oracle-v2 STRATEGY — Audit

```
Auditor:  DSPro/T132 · Role: worker · Model: DSPro · Date: 2026-07-31
Target:   docs/design/oracle-v2/pass0/strategy.md (PROPOSED, Fable/Navigator, 2026-07-31)
Verdict:  NEEDS-FIX
```

## Verdict

**NEEDS-FIX.** The strategy correctly absorbs every finding from the spec
audit (F1–F9), the phase decomposition is sound, the parallel lanes in P2
are well-chosen, and the falsification conditions in §4 are honest and
specific. Two findings at **must** level block ratification, both in the
coordination between code reviews and the integration phase. Neither is an
architectural flaw; both are spec-level gaps in the strategy that can be
resolved before O-1 dispatches.

---

## Findings

### F1 — MUST: Code reviews (O-5r/6r/7r) do not gate O-8, but O-8 consumes their output

The P2 table lists O-5r/6r/7r as ANALYSIS tasks that "trail each lane."
O-8's `needs=` lists only O-5, O-6, O-7 — not the reviews. The strategy
diagram confirms:

```
P2:  [G2] ──► O-5 ──┐            (three lanes concurrent;
     [G2] ──► O-6 ──┼─► O-8      reviews trail each lane)
     [G2] ──► O-7 ──┘
```

The consequence: O-5 completes → O-8 can start immediately (if O-6 and O-7
are also done). Thirty minutes later, O-5r completes and finds a defect in
O-5's DTT computation or serialisation. O-8 has already been running
integration checks against a defective artifact. Rework cascades:
O-5 → O-5 (rework) → O-8 (rework).

The fix is not to move the reviews onto the critical path — the strategy is
correct that reviews should not serially gate the next phase. The fix is to
state the coordination explicitly: **O-8 must not be dispatched until all
three reviews (O-5r, O-6r, O-7r) return PASS or NEEDS-FIX with no blocking
findings.** The kanban mechanism is to add O-5r, O-6r, O-7r to O-8's
`needs=` list, OR to state that the Orchestrator withholds O-8 until the
review verdicts are in. Either works; neither is currently stated.

The same gap exists for O-9 (which consumes O-8's output and is reviewed by
O-10). The strategy correctly makes O-10 a gate on G3 (O-10 → G3), which is
the right shape. But O-9's `needs=` lists O-8 — if O-8 completes and O-9
starts before O-8's review (which isn't separately listed, but O-10 reviews
O-9's evidence, not O-8's code), the same cascade can occur.

**Required:** State the review-completion gate for O-8 explicitly. Either
add O-5r/6r/7r to O-8's `needs=`, or state that the Orchestrator must
withhold O-8 until all three review verdicts are in. Similarly, state
whether O-9 requires O-8 to have passed its review (O-8 has no separate
review task listed; O-10 reviews O-9's evidence, not O-8's code — this is
a second gap, see F2).

### F2 — MUST: No acceptance criteria for review tasks (O-5r/6r/7r, O-10)

The DELEGATOR.md header requires every brief to carry ACCEPTANCE criteria:
falsifiable, with numbers. The strategy lists the review tasks in the P2
table with only their kind (ANALYSIS), deliverable path, and the word
"review." The strategy itself states (§1) that "Audits are dispatched by
Orcha as fresh-seat ANALYSIS tasks; for load-bearing reasoning a different
model than the author is preferred." But it does not state what standard
the reviews apply, what constitutes PASS vs NEEDS-FIX, or what they must
examine.

Specifically:

- **O-5r** reviews O-5 (M2 solver: DTT + serialisation). What must the
  reviewer verify? The DTT computation against the fixpoint? The
  serialisation path against the format contract? The A7 gate-chain
  results? Without stated acceptance, the reviewer could verify the easy
  parts and miss the load-bearing one — the same failure mode as 2B-3-AUDIT.
- **O-6r** reviews O-6 (M3 engine: ko/passes tracking, lookup, R6 modes).
  The R6 modes (basic-ko/psk/ssk) are the spec's F3 resolution, which
  won't exist until O-1 is done. The review brief must include the resolved
  R6 semantics.
- **O-7r** reviews O-7 (M4a acceptance: A3, A5, A6 fixtures, A9 recipe).
  The A6 known-bad fixtures are the calibration — the review must verify
  they fail *correctly*, not just that they fail.
- **O-10** reviews O-9's evidence. The strategy says "independent read of
  O-9's evidence; A6 especially — the corrupted fixtures must FAIL, named."
  This is close to an acceptance criterion but needs the denominator
  discipline: how many fixtures, what failure mode is expected per fixture.

The Orchestrator could invent these when writing the briefs. But the
strategy is the upstream document that ensures consistency — the reviewer
of O-5 should not apply a different standard than the reviewer of O-6.

**Required:** Add acceptance criteria for each review task, or state a
single review standard that applies to all four. Minimum: (a) trace one
complete evaluation end-to-end through the code under review (per the
QA-023 standing rule), (b) verify the acceptance criteria of the task
being reviewed actually pass with stated denominators, (c) verify that any
calibration fixture fails as expected and the failure is named.

### F3 — SHOULD: No time box for O-1 (spec revision)

O-1 resolves F1–F6 and gates the entire sprint. F1 alone (M2's solver
access — "no mutation" vs "no touch," naming the exact interface) is a
design decision that could consume significant analysis. The strategy
provides "starting positions (recommendations, not decisions)" which helps,
but does not state a budget.

Without a time box, O-1 could become an unbounded bottleneck. If O-1 takes
a day, the entire sprint waits. The strategy budgets O-5 at ≤ 4h (the R9
wall budget) and O-3 at ≤ 30min (the spec-audit Q3 recommendation), but
does not budget O-1.

**Suggested:** State an expected wall time for O-1 (e.g. ≤ 2h). If O-1
exceeds it, the Orchestrator should check for scope creep — O-1's job is to
resolve F1–F6, not to perfect the spec.

### F4 — SHOULD: M4a (O-7) delivery time not constrained; shares file with M4b

The strategy says O-7 "runs concurrently with M2/M3, which puts the
acceptance checks in existence *before* the code they will judge." This is
a sound delivery-pipeline pattern. However:

- O-7 owns `src/oracle_v2_accept.zig`, which O-8 also owns. The strategy
  correctly notes that `holds=` serialises them. But O-8 cannot start until
  both O-7 completes AND O-5/O-6 complete. If O-7's agent over-engineers
  the acceptance harness (writing an elaborate framework instead of the
  decoupled checks A3/A5/A6/A9), O-7 could become the bottleneck on the
  non-critical path that then *enters* the critical path.
- The strategy does not state which checks in O-7 are the *minimum* for
  M4a to be considered done. A3 (colour inversion), A5 (round-trip), A6
  (known-bad fixtures), A9 (reproducibility recipe) — that's four checks.
  But A3 and A5 require M1's format (which exists at P2 start); A6 requires
  constructing corrupted artifacts (also possible from the format alone);
  A9 is a documentation task.

**Suggested:** State that O-7's deliverable is the *minimum viable* A3/A5/
A6/A9 — the checks that need only the format contract. The integration
checks (A1, A2, A8) belong to O-8. A short time box for O-7 (≤ 1h) would
prevent it from drifting into O-8's territory.

### F5 — COULD: The P2 "three lanes concurrent" assumes 6 agent slots

P2 dispatches three MUTATION tasks (O-5, O-6, O-7) and three ANALYSIS
tasks (O-5r, O-6r, O-7r) concurrently. That is six agent consoles
simultaneously. If the human has fewer than six available (or fewer than
three for the MUTATION tasks), the parallelism degrades gracefully — the
kanban serialises on `holds=` automatically for mutation, and ANALYSIS runs
in any order.

The strategy's parallelism summary is correct as far as the kanban is
concerned. The practical constraint is the human's ability to manage six
concurrent workers. This is not a strategy defect, but it is a resource
assumption the strategy does not state.

**Suggested:** Add a note: "P2's peak concurrency is 6 agents (3 workers +
3 reviewers). If console slots are constrained, prioritise the MUTATION
lanes (O-5 first — it is on the critical path) and let ANALYSIS reviews
trail."

### F6 — COULD: Three human ratification gates (G1, G2, G3) have no SLA

G1 (ratify revised spec after O-2), G2 (ratify format after O-4), and G3
(ratify acceptance after O-10) each require the human to read, evaluate,
and ratify. If the human is unavailable, the sprint stalls. This is
inherent in human-gated processes, and each gate is correctly placed (after
an independent audit, per the verify-then-promote rule). The strategy does
not promise a turnaround time.

**No action required** — this is noted so the human is aware of the
dependency, not because the strategy should change. The gates are correctly
positioned; the human's availability is a project-level constraint, not a
strategy defect.

---

## Responses to the strategy's five audit questions (§5)

### Q1: Is the G1-before-O-3 serialisation worth its latency?

**Yes.** The strategy's reasoning is sound: M1 defines the key encoding and
column schema — the interface between M2 (writer) and M3 (reader). Starting
M1 before the spec revision is ratified risks building a format against a
spec that changes.

The argument for starting M1 at risk is weaker than it appears. The spec
audit found no architectural flaws — that is true. But F1 (M2's solver
access) could change what key components M2 can produce. If O-1 adopts
interpretation 2 (read-only import of existing fixpoint), the key encoding
is the existing StateIdx32. If O-1 adopts interpretation 1 (re-solve from
scratch), the key encoding might differ. The format depends on which
interpretation wins. Waiting for G1 is cheap (O-1 + O-2 + human turnaround)
compared to redoing M1.

**Verdict: the serialisation is correct; the strategy's Q3 answer from the
spec audit stands.**

### Q2: Does the M4a/M4b split genuinely de-risk the critical path?

**Yes, with the F1 caveat.** The split moves M4a (checks needing only the
format contract) from after M2+M3 to concurrent with them. This shortens
the critical path by M4a's duration. The shared `oracle_v2_accept.zig` file
is serialised by `holds=` automatically; the strategy correctly notes this.

The de-risking is real: M4a puts the acceptance checks into existence
before the code they will judge, following the delivery-pipeline rule that
caught the EXP-4→7 buffer aliasing. If O-7 finishes first, the checks exist
and O-5/O-6 can run them as self-tests. If O-5/O-6 finish first, O-7 can
write checks that already know the interface.

The risk left unaddressed is F4: O-7 has no time box and shares a file with
O-8. If O-7 overruns, it delays O-8.

**Verdict: the split is correct; add the time box from F4.**

### Q3: Is the `data/` write exemption handled correctly?

**Yes.** The strategy:

1. Redirects O-5's writes to `untracked/oracle-v2/` — a standing-rule-
   compliant path (DELEGATEE.md permits `untracked/` writes).
2. Defers the `data/` population to P3, executed by the human or a brief
   carrying an explicit exemption.
3. Cites R7's reproduction command as the mechanism that makes the `data/`
   write a copy, not a novel build.

One subtlety not stated: R7 requires "one documented command regenerates
the artifact from a clean clone, byte-identical to a recorded SHA-256." The
artifact path in `data/` must match what R7's command produces. The
strategy could clarify that the SHA-256 recorded is of the `untracked/`
artifact, and the `data/` copy is verified against that hash before
population. But this is a detail for O-9's brief, not a strategy defect.

**Verdict: correctly handled. No standing-rule change needed.**

### Q4: Are O-1/O-2 rightly two briefs, or one relay brief?

**Two briefs is correct.** The strategy follows the verify-then-promote
rule: O-1 (MUTATION) writes the revision; O-2 (ANALYSIS) audits it as a
fresh seat, ideally a different model. A single relay brief with a named
reviewer would:

- Give the reviewer the reviser's context, violating the "know less than
  the author" principle (DELEGATOR.md rule 5).
- Make the audit a step within a task rather than a gate between tasks,
  losing the kanban's visibility into whether the audit is in progress or
  complete.
- Prevent the Orchestrator from assigning a different model to the audit
  — the relay brief's reviewer is named in the brief, not selected at
  dispatch time.

The two-brief split also enables the G1 human gate to read O-2's verdict
before ratifying, which is exactly the verify-then-promote pattern from the
QA-023 chain.

**Verdict: two briefs is correct.**

### Q5: Where is this plan most likely to deadlock or starve the kanban?

**Three points, none fatal:**

1. **G1 → O-3 gap.** Between G1 (human ratifies spec) and O-3 completion,
   only O-3 is dispatchable (MUTATION, serial). If O-3's agent is slow or
   the task is descoped, nothing else can run. The strategy's suggested
   30-minute time box for M1 (in the spec-audit Q3 answer) should be stated
   in the strategy, not just the audit. **Mitigation: the strategy could
   state O-3's expected wall time (≤ 30min).**

2. **G2 → O-5 gap.** After G2, O-5/O-6/O-7 are all dispatchable. No empty
   set here. But O-5 is on the critical path and its wall budget is ≤ 4h.
   If O-5 fails (A7 gate chain doesn't reproduce, or R9 breach), the sprint
   stalls. The strategy correctly lists this as a falsification condition.

3. **O-8 starvation if O-7 overruns.** O-8 needs O-5, O-6, AND O-7. If O-7
   takes longer than O-5 (unlikely, but possible if O-7's agent
   over-engineers), O-8 waits. This is F4.

**Verdict: the plan's dependency graph has no cycles and no empty
dispatchable sets by construction. The risks are latency, not deadlock.**

---

## What the strategy gets right

1. **The spec-audit absorption is thorough.** Every finding F1–F9 is
   addressed: F1 (starting position for the reviser), F2 (byte budget gate
   in O-3), F3 (R6 resolution in O-1), F4 (A1 pinned in O-1), F5 (fixpoint
   convention in O-1), F6 (passes=2 in O-1), F7 (M4a/M4b split adopted),
   F8 (R8 review in O-3's deliverables), F9 (naming in O-3's deliverables).
   No finding was dropped.

2. **The falsification conditions (§4) are honest and specific.** Each one
   states what outcome would mean the strategy is wrong, and what action
   follows. The F2 gate "working" as a planned outcome — byte budget
   exceeding 600 MB returns to Orcha — is correctly framed as the gate
   succeeding, not the sprint failing.

3. **The parallelism summary (§2) correctly distinguishes `needs=` from
   `set=`.** No phase boundaries that `needs=` doesn't already encode. This
   prevents the set-proliferation anti-pattern.

4. **The verify-battery overlap (§3) is declared and scoped.** "A bonus
   check, not a gate of this sprint." Correctly bounded.

5. **The `data/` write exemption is explicit and logged.** Follows the
   standing rule's intent while enabling the sprint.

6. **The strategy states its own audit process (§5) with specific
   questions.** This is the right pattern — the strategy invites
   falsification rather than ratification.

---

## Summary

| Grade | Count | IDs |
|-------|-------|-----|
| BLOCKER | 0 | — |
| MUST | 2 | F1, F2 |
| SHOULD | 2 | F3, F4 |
| COULD | 2 | F5, F6 |

The two MUST findings are coordination gaps in the review-to-integration
handoff, not architectural defects. Both can be resolved by adding explicit
language to §1 (Phases and gates) and §2 (Parallelism summary) — no
restructuring needed. The SHOULD findings (O-1 time box, O-7 time box) are
sprint-efficiency concerns; the strategy is correct without them, but
riskier.
