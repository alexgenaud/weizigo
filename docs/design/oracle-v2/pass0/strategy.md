# oracle-v2 — STRATEGY

```
Status:   PROPOSED — awaiting independent audit, then human ratification
Author:   Fable/Navigator (claude-fable-5) · 2026-07-31
Process:  sprint checkpoints (spec → strategy → acceptance) per docs/infra/sprint.md;
          execution per docs/infra/delegation/ (DELEGATOR / DELEGATEE / ROLES)
Inputs:   pass0/spec.md (frozen snapshot) · pass0/spec-audit.md
          (NEEDS-FIX: 1 blocker F1, 5 must F2–F6, 2 should, 1 could)
Audit:    this document, before any design task is dispatched
```

## 0. Standing assumptions

1. The pass-0 audit found **spec omissions, not architectural flaws**. This
   strategy therefore plans against the spec *as it will read after the F1–F6
   revision*, and makes that revision its first gate. If the revision changes
   anything outside F1–F6's scope, this strategy returns to PROPOSED and is
   re-audited before any downstream task dispatches.
2. Every task below is registered in `bin/managent` with a brief in
   `docs/infra/dispatch/`, header per `DELEGATOR.md`. **No brief names a
   model** — the human assigns at runtime. Task IDs below (`O-1`…) are
   strategy-local labels; Orcha assigns real kanban IDs at registration.
3. All builds run under `tools/runner` (4 GB RSS SIGKILL). The 2026-07-29
   kernel panic is the precedent; no exceptions.
4. Concurrency is governed by the kanban: ANALYSIS tasks (one new file) run
   in parallel without limit; code tasks serialise automatically on `holds=`.

## 1. Phases and gates

Every gate is a human ratification point. Audits are dispatched by Orcha as
fresh-seat ANALYSIS tasks; for load-bearing reasoning a **different model**
than the author is preferred (`ROLES.md` §"Instance vs model").

### P0 — spec repair (serial, small)

| id | kind | deliverable | holds | needs |
|---|---|---|---|---|
| **O-1** | MUTATION | spec revision resolving F1–F6 (F7–F9 at reviser's discretion) | `docs/infra/oracle-v2/spec.md` | — |
| **O-2** | ANALYSIS | pass-1 spec audit → `docs/design/oracle-v2/pass1/spec-audit.md` | — | O-1 |

Starting positions for the reviser (recommendations, not decisions —
divergence is a finding to report, not adapt around):

- **F1 (blocker):** adopt the audit's interpretation 2 — the forbid-list
  becomes *no mutation* rather than *no touch*; M2 imports the existing
  fixpoint read-only, and the revision names the exact interface
  (`exp6_solve.zig` already builds the full `StateIdx32` key in memory; the
  defect is confined to the write path). If no importable interface exists,
  the revision states the minimal refactor that exposes one, and that
  refactor becomes its own audited task — M2 does not improvise it.
- **F2:** add the design gate verbatim — M1's `design.md` must derive a
  concrete byte budget before M2 may begin; > 600 MB returns the sprint to
  Orcha for re-scoping.
- **F3:** state R6's default rule, mismatch behaviour, and whether
  enforcement filters oracle suggestions or only rejects at the GTP layer.
- **F4:** pin the A1 script (or adopt the audit's ≥ 100-denominator random
  self-play form); state the seed.
- **F5:** state the solver's fixpoint convention (TIE=0 pinning) and that
  the stored L/H are the converged bounds under it, reader may override.
- **F6:** specify passes=2 terminal semantics and its DTT contract.

**Gate G1 — human ratifies the revised spec** (O-2 verdict PASS required).

### P1 — format design (the critical path)

| id | kind | deliverable | holds | needs |
|---|---|---|---|---|
| **O-3** | ANALYSIS | M1 design → `docs/design/oracle-v2/pass1/design-M1.md` | — | G1 |
| **O-4** | ANALYSIS | M1 design audit → `pass1/design-M1-audit.md` | — | O-3 |

O-3 must contain: the WZO2 key encoding, column schema (L, H, DTT, flags),
header layout, the **F2 byte budget** derived from EXP-3's counts (51,419,046
`(goban, side, ko)` triples; passes NOT folded), the artifact naming
convention (audit F9), and the R8 inventory of verifier checks the format
must support. The audit's Q3 answer stands: **M1 is not parallelised with
M2/M3** — the format is the interface, and two agents improvising it
concurrently is the EXP-4→7 failure mode.

**Gate G2 — human ratifies the format.** After G2 the format contract is
published to `docs/infra/oracle-v2/format.md` and is frozen for the sprint.

### P2 — parallel build (three lanes, disjoint holds)

| id | kind | deliverable | holds | needs |
|---|---|---|---|---|
| **O-5** | MUTATION | M2 solver: DTT in fixpoint, full-key serialisation | `src/artifact2.zig`, `src/oracle_v2_build.zig` | G2 |
| **O-6** | MUTATION | M3 engine: ko/passes tracking, full-key lookup, R6 modes | `src/gtp.zig` | G2 |
| **O-7** | MUTATION | M4a acceptance (decoupled checks: A3, A5, A6 fixtures, A9 recipe) | `src/oracle_v2_accept.zig` | G2 |
| O-5r/6r/7r | ANALYSIS | one code review per lane, fresh seat | — | its lane |

Adopting audit F7: M4 splits into **M4a** (needs only the format contract —
runs concurrently with M2/M3, which puts the acceptance checks in existence
*before* the code they will judge, per the delivery-pipeline rule) and
**M4b** (integration checks needing both M2 and M3).

O-5 runs the gate chain (A7: 2×2 = 0, 3×2 = 0, 3×3 = +9) **before** any 4×4
build. A 4×4 run without green anchors is a wasted wall-clock session.

**`data/` write exemption.** Standing rule (`DELEGATEE.md`): agents never
write `data/`. During P2, O-5 writes artifacts to `untracked/oracle-v2/`
only. The single run that populates `data/` with the ratified artifact is
executed by the human (or a brief carrying an explicit, logged exemption)
at P3 — R7's reproduction command makes this cheap.

### P3 — integration and acceptance

| id | kind | deliverable | holds | needs |
|---|---|---|---|---|
| **O-8** | MUTATION | M4b (A1 refusal script, A2 post-round-trip Bellman, A8 DTT) | `src/oracle_v2_accept.zig` | O-5, O-6, O-7 |
| **O-9** | RUN | full A1–A9 run; evidence + proposed rows → `docs/evidence/ORACLE-V2/` | evidence dir | O-8 |
| **O-10** | ANALYSIS | acceptance audit: independent read of O-9's evidence; A6 especially — the corrupted fixtures must FAIL, named | — | O-9 |

O-8 shares a file with O-7, so the kanban serialises them via `holds=` — no
special handling needed.

**Gate G3 — human ratifies acceptance.** Only then do proposed claim rows
enter the register, via the normal serial MUTATION pipeline (holds on
`docs/epistemic/CLAIMS.md`), never by the sprint's own tasks (spec R4
analogue; sixty-writer lesson).

## 2. Parallelism summary for Orcha

```
P0:  O-1 ──► O-2 ──► [G1]
P1:  [G1] ──► O-3 ──► O-4 ──► [G2]
P2:  [G2] ──► O-5 ──┐            (three lanes concurrent;
     [G2] ──► O-6 ──┼─► O-8      reviews trail each lane)
     [G2] ──► O-7 ──┘
P3:  O-8 ──► O-9 ──► O-10 ──► [G3]
```

Critical path: O-1 → O-2 → G1 → O-3 → O-4 → G2 → **O-5 (wall ≤ 4 h)** →
O-8 → O-9 → O-10 → G3. M3 and M4a are off the critical path. Express
dependencies with `needs=`, not `set=` — there is no phase boundary here
that `needs=` does not already encode.

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
- **M2 cannot reach a usable fixpoint interface** without mutating forbidden
  files: the F1 resolution was wrong; stop, new spec round (report-don't-adapt).
- **A1 does not improve** (spec §6): the sprint's central diagnosis is wrong.
  Pre-committed: this is published as the headline negative result.

## 5. For the strategy auditor

Grade **blocker / critical / must / should / could**; verdict **PASS /
NEEDS-FIX / REDO**. Write to `docs/design/oracle-v2/pass0/strategy-audit.md`.

1. Is the G1-before-O-3 serialisation worth its latency, given the audit
   found no architectural flaws — could M1 design start against the audit's
   recommended F1–F6 resolutions at risk?
2. Does the M4a/M4b split genuinely de-risk the critical path, or does the
   shared `oracle_v2_accept.zig` hold just move the serialisation?
3. Is the `data/` write exemption handled correctly, or does it need a
   standing-rule change ratified separately?
4. Are O-1/O-2 rightly two briefs, or one relay brief with a named reviewer?
5. Where is this plan most likely to deadlock or starve the kanban
   (holds cycles, an empty dispatchable set between gates)?
