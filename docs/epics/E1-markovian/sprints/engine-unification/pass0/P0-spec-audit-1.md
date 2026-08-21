# P0 spec+plan audit
Auditor: DSFlash/T253 · Date: 2026-08-01
Verdict: NEEDS-FIX

## Findings

- F1: [plan.md:83] P2b's budget contradicts the spec's AC-S5. Spec AC-S5
  (spec.md:95) requires the 4×4 sample "within a 60-second budget"; the plan's
  P2b row says "120 s sampled". The plan as written cannot satisfy the sprint's
  own acceptance criterion, and AC-S5 as written would fail a 120 s run that
  follows the plan. One of the two must change (and if AC-S5 stays at 60 s the
  plan should also state whether the budget is per-size or combined for
  4×4 + 4×3, since the plan added 4×3 beyond anything AC-S5 mentions).
  (severity: must)

- F2: [plan.md:38-40] P0's own `managent done` acceptance is self-defeating and
  contradicts AC-S1 (spec.md:84-85). The plan prescribes `managent done --status
  pass` with an `acceptance=` that is "a test command that is SIGKILLed and must
  produce exit code ≠ 0". After the fix, a SIGKILLed acceptance is exactly what
  AC-S1 says managent must REJECT — so P0 can never be marked pass as written.
  Before the fix (or with a wrong fix), the killed command would wrongly report
  PASS — the QA-023 failure class: an acceptance that reads as proof precisely
  when the instrument under test is broken. AC-S1 verification must be a
  separate demonstration (a throwaway task whose acceptance is SIGKILLed, whose
  done is asserted rejected); P0's own `acceptance=` should be the regression
  tests (exit 0). As written this also breaks AC-S9 (spec.md:102-104), which
  requires P0's commit to carry its own passing done verdict. (severity: blocker)

- F3: [spec.md:41-47 vs spec.md:94-96] AC-S5 omits the fifth in-scope operation.
  Scope priority item 5 requires the matrix for "Key encode/decode round-trip
  (WZO1 + WZO2)", and the operations table (spec.md:69) lists it; the plan's P2a
  includes encode/decode (plan.md:82). But AC-S5 lists only double-pass, area
  score, legality, capture — a sprint could satisfy every AC with an empty
  encode/decode matrix. Add encode/decode to AC-S5 (and state which operations
  the 4×4 sample covers). (severity: should)

- F4: [spec.md:76 vs spec.md:41] Non-goal "Changes to claims, evidence files, or
  CLAIMS.md" is in tension with the in-scope agreement-matrix deliverable, which
  the plan writes to `docs/evidence/GLOBAL.DIFFERENTIAL/` (plan.md:88). A literal
  reader can treat the matrix files as "evidence files" and find the sprint
  contradicting its own non-goal. The plan's fresh-directory choice is a
  reasonable resolution; the spec should say "existing claims/evidence files" to
  remove the ambiguity. (severity: should)

- F5: [spec.md:95, plan.md:55, plan.md:83] "Sampled (not exhaustive)" / "120 s
  sampled" is procedurally undefined: no sample count, no selection rule, no
  seed. As written, a one-state sample satisfies AC-S5 — not falsifiable in any
  meaningful sense. Define the sample procedure (number of states, RNG/seed,
  determinism) so the run is reproducible, per the standing rule that numbers
  cite their run and denominator. (severity: should)

- F6: [spec.md:48-49, plan.md:85-86] Denominator ambiguity in the ADR-0020
  fixture: "verify the 24 2×2 states are a standing agreement fixture (gap =
  0/172 reachable non-terminals)". AC-S6's denominator (0/172) is clear, but the
  relationship between the 24-state fixture and the 172 reachable non-terminals
  is not (subset? the fixture is the 172 and 24 is stale? a different check?).
  Reconcile the two numbers in the task text so the P2a agent measures the right
  set. (severity: should)

- F7: [plan.md:91-92, plan.md:137] The P2 deliverables' commit and done procedure
  is unspecified. Deliverable is "agreement matrix populated + findings JSONs",
  but the boundary report commits only "P0 and P1 deliverables", and only P0/P1
  specify an `acceptance=` for `managent done`. The matrix is the sprint's core
  evidence and must be committed (evidence-in-git rule); P2a/P2b need defined
  done verdicts with acceptance commands. (severity: should)

- F8: [plan.md:64 vs spec.md:89-93] The P1 task text ("including a known-bad
  fixture it catches") does not carry AC-S4's explicit constraint that the
  fixture must be synthetic — two hand-written functions, not a live
  implementation. Without it in the brief, a P1 agent can register a live
  implementation as the fixture, which is precisely the failure AC-S4 exists to
  prevent (live faults get fixed and the check silently tests nothing).
  (severity: should)

- F9: [plan.md:100-101 vs spec.md:78-80] The plan's "pass0 does not modify
  `src/oracle_v2_build.zig`" is blanket-stricter than the spec's exception
  ("any change ... that is not strictly required for the differential harness to
  load it"). Likely moot (T212 validated the build path), but the plan should
  mirror the spec's carve-out so a strictly-required load fix is not forbidden.
  (severity: could)

- F10: [plan.md:17 vs plan.md:53-68] Phase-table label "differential harness +
  agreement matrix (T225 replacement)" overstates P1's scope: the P1 task builds
  the harness only; the matrix is produced in P2. Misleading label, harmless to
  execution. (severity: could)

- F11: [plan.md:106-114] The audit-gates table names each gate and its
  instrument but no actor. The P0-spec gate is this document (T253), which
  demonstrates the pattern works, but P0-build, P1-design, P1-build and P2-
  results gates have no assigned independent seat. Assign actors (or state the
  sprint manager mints audit tasks per gate) so the gates are enforceable, per
  verify-then-promote. (severity: could)

## Verdict rationale

The spec defines a clear, measurable goal: pass0 delivers fixed instruments
(AC-S1..S3, S8), a self-tested differential harness (AC-S4), and a populated
agreement matrix (AC-S5) with ADR-0020 verification (AC-S6), witnesses (AC-S7)
and separately committed, separately verified deliverables (AC-S9); the plan
sequences phases with correct dependencies — P0 (acceptance fix) before P1
(harness, whose done verdict depends on that fix) before P2 (measurement, which
requires the harness) — and respects the concurrency constraint (never more than
two concurrent subagents: 1/1/2, with disjoint files: main.zig, differential.zig,
per-size matrix files). The ACs are largely falsifiable, and the spec/plan agree
on scope, non-goals and the "report, don't fix" discipline. But two findings
force NEEDS-FIX: F2 (blocker) — P0's own done acceptance as written is a
SIGKILLed command under `--status pass`, which AC-S1 requires managent to reject,
so P0 cannot complete as written and the acceptance would wrongly pass a broken
fix (QA-023 class); F1 (must) — the plan's 120 s P2b budget contradicts AC-S5's
60-second budget, so the plan cannot satisfy the sprint's own acceptance
criterion. Five should-level and three could-level findings (AC-S5 omitting
encode/decode, evidence-files non-goal ambiguity, undefined sampling procedure,
24-vs-172 denominator, P2 commit/done procedure, P1 fixture constraint, plus
three wording/actor gaps) are cheap fixes to the two documents before dispatch.
