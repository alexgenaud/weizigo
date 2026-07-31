# oracle-v2 — STRATEGY

```
Status:   PROPOSED (rev 1) — pass-0 strategy-audit findings resolved;
          awaiting human ratification
Author:   Fable/Navigator (claude-fable-5) · 2026-07-31
Revised:  Fable/Navigator · 2026-07-31 — canonical, revised in place (rev 0
          text: git show 56950a1:docs/design/oracle-v2/pass0/strategy.md).
          Resolves strategy-audit F1–F6 (2 MUST, 2 SHOULD, 2 COULD;
          docs/design/oracle-v2/archive/strategy.audit-1.md, DSPro/T132).
          Each resolution is tagged [SFn]. Also absorbs the spec's M2a/M2b
          split (spec-audit F1 resolution) into the task tables.
Process:  sprint checkpoints (spec → strategy → acceptance) per docs/infra/sprint.md;
          execution per docs/infra/delegation/ (DELEGATOR / DELEGATEE / ROLES)
Inputs:   docs/infra/oracle-v2/pass0/spec.md (canonical revision, 2026-07-31)
          docs/design/oracle-v2/archive/spec.audit-1.md · spec.audit-2.md (PASS)
          docs/design/oracle-v2/archive/strategy.audit-1.md (NEEDS-FIX: 2 must)
```

## 0. Standing assumptions

1. The pass-0 audit found **spec omissions, not architectural flaws**. This
   strategy therefore plans against the spec *as revised* (pass 1, F1–F6
   resolved 2026-07-31). If the pass-1 spec audit (O-2) finds the revision
   changed anything outside F1–F9's scope, this strategy returns to PROPOSED
   and is re-audited before any downstream task dispatches.
2. Every task below is registered in `bin/managent` with a brief in
   `docs/infra/dispatch/`, header per `DELEGATOR.md`. **No brief names a
   model** — the human assigns at runtime. Task IDs below (`O-1`…) are
   strategy-local labels; Orcha assigns real kanban IDs at registration.
3. All builds run under `tools/runner` (4 GB RSS SIGKILL). The 2026-07-29
   kernel panic is the precedent; no exceptions.
4. Concurrency is governed by the kanban: ANALYSIS tasks (one new file) run
   in parallel without limit; code tasks serialise automatically on `holds=`.
5. **Human gates have no SLA [SF6].** G1/G2/G3 stall the sprint while the
   human is away. The gates are correctly placed (verify-then-promote); the
   latency is a project-level constraint, noted so nobody reads a stall as a
   defect.

## 1. Phases and gates

Every gate is a human ratification point. Audits are dispatched by Orcha as
fresh-seat ANALYSIS tasks; for load-bearing reasoning a **different model**
than the author is preferred (`ROLES.md` §"Instance vs model").

### Review standard [SF2] — applies to every review task below

A review task (O-2, O-4, O-5ar, O-5r, O-6r, O-7r, O-8r, O-10) returns
PASS / NEEDS-FIX / REDO and must, at minimum:

1. **Trace one complete evaluation end-to-end** through the artifact under
   review (the QA-023 standing rule) — not spot-check the easy parts.
2. **Re-verify the reviewed task's own acceptance criteria** with stated
   denominators — "A5 passed" is not acceptable; "A5: 51,419,046/51,419,046
   round-trips identical" is.
3. **Verify every calibration fixture fails as expected, and the failure is
   named** — a fixture that passes when it should fail voids the review.

Per-review foci (the brief carries these verbatim):

- **O-5ar** (M2a refactor): no behavioural change — v1 pipeline builds, A7
  chain reproduces, 3×3 v1 artifact byte-identical; the exposed interface is
  sufficient for M2b (DTT inputs, full-key iteration).
- **O-5r** (M2b builder): DTT computation against the fixpoint and the R10
  terminal anchor; serialisation against the frozen format contract; A7 gate
  chain from the new pipeline.
- **O-6r** (M3 engine): the brief **must include the ratified §3.1 R6
  semantics** — default, both mismatch behaviours, filter-both-sides — and
  the review verifies each against the code.
- **O-7r** (M4a): the A6 known-bad fixtures must fail **correctly** — each
  fixture's expected failure mode stated and observed, not merely "it failed."
- **O-8r** (M4b): A1/A2/A4/A8 checks against the format contract; the A1
  seed is pinned and recorded.
- **O-10** (acceptance evidence): independent read of O-9's evidence with
  denominator discipline — per A6 fixture, the expected failure mode and the
  observed one; per A-criterion, the reported denominator.

### P0 — spec repair (serial, small)

| id | kind | deliverable | holds | needs | box |
|---|---|---|---|---|---|
| **O-1** | MUTATION | spec revision resolving F1–F6 (F7–F9 at reviser's discretion) | `docs/infra/oracle-v2/pass0/spec.md` | — | ≤ 2 h [SF3] |
| **O-2** | ANALYSIS | spec audit → `docs/design/oracle-v2/archive/spec.audit-2.md` | — | O-1 | — |

If O-1 exceeds its box, the Orchestrator checks for scope creep — O-1's job
is to resolve F1–F6, not to perfect the spec [SF3].

> **Execution note (2026-07-31):** O-1 was executed by the Navigator at the
> human's direction, inline, same day as this revision. All findings resolved
> and tagged `[Fn]` in the live spec; the F1 starting position was verified
> against the code (no importable interface exists — sole `pub` is `main()`),
> so the stated minimal refactor became module M2a. O-2 is the next dispatch.

**Gate G1 — human ratifies the revised spec** (O-2 verdict PASS required).

### P1 — format design (the critical path) + fixpoint exposure (off it)

| id | kind | deliverable | holds | needs | box |
|---|---|---|---|---|---|
| **O-3** | ANALYSIS | M1 design → `docs/design/oracle-v2/design-M1.md` | — | G1 | ≤ 30 min |
| **O-4** | ANALYSIS | M1 design audit → `archive/design-M1.audit-1.md` | — | O-3 | — |
| **O-5a** | MUTATION | M2a: expose the fixpoint interface (`pub` only, no behavioural change; spec §5 M2a) | `src/exp6_solve.zig` | G1 | ≤ 1 h |
| **O-5ar** | ANALYSIS | M2a code review, fresh seat | — | O-5a | — |

O-3 must contain: the WZO2 key encoding, column schema (L, H, DTT, flags),
header layout, the **F2 byte budget** derived from EXP-3's counts (51,419,046
`(goban, side, ko)` triples; passes NOT folded), the artifact naming
convention (spec §4, `data/oracle-{goban}-v2.wzo2`), and the R8 baseline
inventory of verifier checks the format must support. The spec-audit's Q3
answer stands: **M1 is not parallelised with M2b/M3** — the format is the
interface, and two agents improvising it concurrently is the EXP-4→7 failure
mode. M2a needs no format, only the ratified spec, so it runs here — which
also closes the G1→O-3 starvation window the strategy audit flagged (Q5.1):
after G1, two lanes are dispatchable, not one.

**Gate G2 — human ratifies the format.** After G2 the format contract is
published to `docs/infra/oracle-v2/format.md` and is frozen for the sprint.

### P2 — parallel build (three lanes, disjoint holds)

| id | kind | deliverable | holds | needs | box |
|---|---|---|---|---|---|
| **O-5** | MUTATION | M2b builder: DTT + full-key serialisation via M2a's interface | `src/artifact2.zig`, `src/oracle_v2_build.zig` | G2, O-5ar | wall ≤ 4 h (R9) |
| **O-6** | MUTATION | M3 engine: ko/passes tracking, full-key lookup, §3.1 R6 modes | `src/gtp.zig` | G2 | — |
| **O-7** | MUTATION | M4a acceptance, **minimum viable** [SF4]: A3, A5, A6 fixtures, A9 recipe — the checks needing only the format contract. A1/A2/A4/A8 belong to O-8; drifting into them is scope creep. | `src/oracle_v2_accept.zig` | G2 | ≤ 1 h [SF4] |
| O-5r/6r/7r | ANALYSIS | one code review per lane, fresh seat, per the review standard above | — | its lane | — |

O-5 runs the gate chain (A7: 2×2 = 0, 3×2 = 0, 3×3 = +9) **before** any 4×4
build. A 4×4 run without green anchors is a wasted wall-clock session.

**Concurrency note [SF5].** P2's peak is 6 agents (3 workers + 3 reviewers).
If console slots are constrained, prioritise the MUTATION lanes — O-5 first,
it is the critical path — and let the ANALYSIS reviews trail. The kanban
degrades gracefully: `holds=` serialises mutation, ANALYSIS runs in any order.

**`data/` write exemption.** Standing rule (`DELEGATEE.md`): agents never
write `data/`. During P2, O-5 writes artifacts to `untracked/oracle-v2/`
only. The single run that populates `data/` with the ratified artifact is
executed by the human (or a brief carrying an explicit, logged exemption)
at P3 — R7's reproduction command makes this cheap; the recorded SHA-256 is
of the `untracked/` build and the `data/` copy is verified against it.

### P3 — integration and acceptance

| id | kind | deliverable | holds | needs |
|---|---|---|---|---|
| **O-8** | MUTATION | M4b (A1 pinned-seed self-play, A2 post-round-trip Bellman, A4 pin census, A8 DTT) | `src/oracle_v2_accept.zig` | O-5, O-6, O-7, **O-5r, O-6r, O-7r [SF1]** |
| **O-8r** | ANALYSIS | M4b code review, fresh seat **[SF1]** | — | O-8 |
| **O-9** | RUN | full A1–A9 run; evidence + proposed rows → `docs/evidence/ORACLE-V2/` | evidence dir | O-8, **O-8r [SF1]** |
| **O-10** | ANALYSIS | acceptance audit per the review standard: independent read of O-9's evidence; A6 especially — each corrupted fixture must FAIL in its named mode | — | O-9 |

**The review gates are deliberate [SF1].** O-8 consumes O-5/O-6/O-7's output;
a defect found by a trailing review after O-8 started would cascade rework
through the integration phase, so all three review verdicts (PASS, or
NEEDS-FIX with no blocking findings) gate O-8's dispatch — encoded in
`needs=`, not left to Orchestrator memory. Likewise O-9 is the expensive
wall-clock run; it does not start until O-8's code has been reviewed (O-8r).
Within P2 the reviews still trail their lanes — they gate the *next phase*,
not their own lane's progress.

O-8 shares a file with O-7, so the kanban serialises them via `holds=` — no
special handling needed.

**Gate G3 — human ratifies acceptance.** Only then do proposed claim rows
enter the register, via the normal serial MUTATION pipeline (holds on
`docs/epistemic/CLAIMS.md`), never by the sprint's own tasks (spec R4
analogue; sixty-writer lesson).

## 2. Parallelism summary for Orcha

```
P0:  O-1 ──► O-2 ──► [G1]
P1:  [G1] ──► O-3 ──► O-4 ─────► [G2]
     [G1] ──► O-5a ──► O-5ar ──────┐        (M2a off the critical path)
P2:  [G2] ──► O-5 ◄────────────────┘─┐      (three lanes concurrent;
     [G2] ──► O-6 ───────────────────┼─► O-8   reviews trail each lane,
     [G2] ──► O-7 ───────────────────┘         but gate O-8: needs=
                                                includes O-5r, O-6r, O-7r)
P3:  O-8 ──► O-8r ──► O-9 ──► O-10 ──► [G3]
```

Critical path: O-1 → O-2 → G1 → O-3 → O-4 → G2 → **O-5 (wall ≤ 4 h)** →
O-5r → O-8 → O-8r → O-9 → O-10 → G3. M2a, M3 and M4a are off the critical
path. Express dependencies with `needs=`, not `set=` — there is no phase
boundary here that `needs=` does not already encode.

## 3. Cross-sprint coordination (verify-battery)

- **Declared overlap stands:** M4 duplicates invariants the battery will
  also implement; deliberate, time-boxed, merge task out of scope (spec §5).
- **Shared RSS meter:** at most **two** 4×4-scale invocations at once
  *across both sprints*. Orcha meters heavy runs globally when dispatching
  O-5/O-9 alongside battery fleet runs; the runner caps each process, but
  nothing else caps the sum.
- **`src/gtp.zig` is held by O-6 for the sprint duration** — the kanban
  `holds=` entry is the enforcement; no other sprint may take it.
- The battery, once live, runs against the WZO2 artifact as an independent
  instrument. That is a bonus check, not a gate of this sprint.

## 4. What would falsify this strategy

- **O-2 returns REDO** (not PASS/NEEDS-FIX): the "omissions only" premise
  collapses and this strategy is withdrawn, not patched.
- **O-3's byte budget exceeds 600 MB:** P2 as scoped is wrong; the sprint
  returns to Orcha for re-scoping. That is the F2 gate *working* — a planned
  outcome, reported as such.
- **O-5a cannot expose a usable fixpoint interface** without behavioural
  change: the spec's F1 resolution was wrong; stop, new spec round
  (report-don't-adapt).
- **A1 does not improve** (spec §6): the sprint's central diagnosis is wrong.
  Pre-committed: this is published as the headline negative result.

## 5. Audit record

The strategy audit (`docs/design/oracle-v2/archive/strategy.audit-1.md`,
DSPro/T132, 2026-07-31) returned NEEDS-FIX: F1/F2 MUST, F3/F4 SHOULD, F5/F6
COULD; all five of the strategy's self-audit questions answered in the
strategy's favour. Resolutions in this revision:

| finding | resolution |
|---|---|
| F1 (MUST) reviews don't gate O-8 | O-5r/6r/7r added to O-8's `needs=`; O-8r added, gating O-9 [SF1] |
| F2 (MUST) no review acceptance criteria | Review standard section + per-review foci [SF2] |
| F3 (SHOULD) O-1 unboxed | O-1 ≤ 2 h; scope-creep check [SF3] |
| F4 (SHOULD) O-7 unboxed, shares file with O-8 | O-7 ≤ 1 h, minimum-viable A3/A5/A6/A9 only [SF4] |
| F5 (COULD) 6-slot assumption unstated | Concurrency note in P2 [SF5] |
| F6 (COULD) gate SLA | Standing assumption 5 [SF6] |

Ratification of this revision is the human's call; the MUST fixes are
coordination language, not restructuring, so no fresh strategy audit is
planned unless the human requests one.
