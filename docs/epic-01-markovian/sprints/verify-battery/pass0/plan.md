# verify-battery — STRATEGY

```
Status:   RATIFIED (G2, 2026-07-31) — executed through P3-H (T168–T187);
          open: V-13 fleet run, V-14 absorption (G3)
Author:   Fable/Navigator (claude-fable-5) · 2026-07-31
Revised:  Fable/T136 · 2026-07-31 — live copy; the pass-0 original is
          frozen at docs/epic-01-markovian/sprints/verify-battery/archive/plan.md. Resolves
          strategy-audit SB1–SB2, SC1–SC3, SM1–SM5, SS1–SS3, SO1–SO2
          (pass0/strategy-audit.md, Opus/T133, NEEDS-FIX). Each resolution
          is tagged [Xn]. Companion to the pass-1 spec revision at
          docs/epic-01-markovian/sprints/verify-battery/pass0/spec.md.
Process:  human-gated checkpoints under the delegation regime
          (docs/infra/delegation/ — DELEGATOR / DELEGATEE / ROLES).
          docs/infra/sprint.md is RATIFIED rev 4 (d53c2a8) and rewritten
          200b974 (substance D-16…D-20) — the un-retirement happened; G1–G3
          below are human-ratification points. [SM1]
Inputs:   pass0/spec.md · pass0/spec-audit.md · pass0/plan.md ·
          pass0/strategy-audit.md · pass1/i5-feasibility.md (DSPro/T134)
Audit:    pass-1 audit covers this document and the revised spec together
```

## 0. Standing assumptions

1. **Inherited facts are verified, not assumed** [replaces pass-0 §0.1,
   which treated the spec audit's finding list as complete — the T133 audit
   showed three calibration anchors slipped through]. Every number a task
   brief carries as a target must cite the register by `file:line`; a brief
   that cannot cite its target does not dispatch. The revised spec §4/§5
   complies.
2. Every task is registered in `bin/managent`; brief per `DELEGATOR.md`;
   **no brief names a model**. Strategy-local labels (`V-1`…) map to kanban
   IDs in §1's tables. As of this revision the substrate is verified: T134
   (V-1) done, T136 (V-2) claimed, `_sys.next_id` corrected. [SM2]
3. All builds and runs go through `tools/runner` (4 GB RSS SIGKILL).
4. The battery earns "one instrument beats sixty" only if the invariant set
   is complete **and the shared-code boundary is explicit**. Both are now
   spec content (§6a matrix; R8 policy), ratified at G1.
5. Deliverable paths are repo-relative throughout [SO1].

## 1. Phases and gates

### P0 — spec repair + the long-pole head start

| id | kanban | kind | deliverable | holds | needs |
|---|---|---|---|---|---|
| **V-1** | T134 — **done** | ANALYSIS | I5 feasibility memo → `docs/epic-01-markovian/sprints/verify-battery/archive/i5-feasibility.md` (peak ≈ 1.2–1.5 GB at 4×4, tiered fallbacks, corrupt-one-slot fixture, calibration targets) | — | — |
| **V-2** | T136 — **this revision** | MUTATION | pass-1 spec + strategy: `docs/epic-01-markovian/sprints/verify-battery/pass0/spec.md`, `docs/epic-01-markovian/sprints/verify-battery/pass0/plan.md`. Resolves B1–B2, C1–C3, M1–M7, S1–S4, O1–O4, SB1–SB2, SC1–SC3, SM1–SM5, SS1–SS3, SO1–SO2. | `docs/epic-01-markovian/sprints/verify-battery/pass0/spec.md` `docs/epic-01-markovian/sprints/verify-battery/pass0/plan.md` | V-1 |
| **V-3** | T137 | ANALYSIS | pass-1 audit of both documents → `docs/epic-01-markovian/sprints/verify-battery/archive/spec-audit.md` — independent seat, not the T133 auditor and not the reviser | — | V-2 |
| **V-R** | T138 | ANALYSIS | 3×2 reconciliation memo → `docs/evidence/QA-023/census-reconciliation.md`: confirm (or refute) the 36-phantom identity behind the 2,586/2,622 census split and the 1,724/1,704/1,678 cycle-reachable spread; states the phantom-exclusion convention I5 adopts [SC2, SB2] | `docs/evidence/QA-023/census-reconciliation.md` | — |

What changed against pass 0 [SB1, SB2, SC1, SC2]: V-2's starting positions
are gone — they are *done*, in the revised spec, with the three stale
calibration anchors corrected there (I8 polarity → agreement fixture citing
T102/T103; A3 relabeled 3×2 with both committed values over their own
denominators; "Wave 1 SCC" references replaced by the QA-023 evidence paths).
V-R runs concurrently with V-3; it blocks nothing on the critical path but
must land before V-10 gates on A3.

**Gate G1 — human ratifies the revised spec.** Agenda, explicitly:
1. the **R8 shared-code policy** (import nothing from `src/` — the costliest
   decision in the sprint) [M7];
2. the **§6a sixty-cell matrix** as the definition of done [SM4];
3. **S1** (I5 separately invocable, once per goban);
4. the **ADR-0020 amendment**: its "24 mismatch states" clause (lines 47–49,
   62–63) predates T102's finding and needs amending to the agreement
   fixture — an ACCEPTED ADR changes only through the human [SB1];
5. the **sprint un-retirement** — adopt, or formally retire the proposal and
   let the delegation regime carry the gates [SM1].

### P1 — harness design

| id | kanban | kind | deliverable | holds | needs |
|---|---|---|---|---|---|
| **V-4** | at dispatch | ANALYSIS | M1 design → `docs/epic-01-markovian/sprints/verify-battery/archive/design-M1.md`: CLI, result schema (three exit classes per R6, denominators, §6a cell coordinates, proposed-row format), artifact loading per R8 | — | G1 |
| **V-5** | at dispatch | ANALYSIS | M1 design audit → `docs/epic-01-markovian/sprints/verify-battery/archive/design-M1-audit.md` | — | V-4 |

M4's design does **not** wait here — the feasibility memo is its design
seed; only its output fields bind to V-4's schema.

**Gate G2 — human ratifies the schema.** Frozen for the sprint thereafter.
G2 is also **V-11's dispatch deadline** [SM3].

### P2 — three invariant lanes (concurrent, disjoint holds)

| id | kanban | kind | deliverable | holds | needs |
|---|---|---|---|---|---|
| **V-6** | at dispatch | MUTATION | M1 harness build | `src/verify_battery.zig` | G2, **V-11 committed** [SM3] |
| **V-7** | at dispatch | MUTATION | M2 table invariants: I1, I2, I3, I6, I10, I12 | `src/vb_table.zig` | G2 |
| **V-8** | at dispatch | MUTATION | M3 fixpoint invariants: I4, I7, **I8 (agreement polarity — gap = 0, cite T102/T103)** [SB1], I9, I11 | `src/vb_fixpoint.zig` | G2 |
| **V-9** | at dispatch | MUTATION | M4 graph invariant I5 per the feasibility memo | `src/vb_graph.zig` | G2 |
| V-7r/8r/9r | at dispatch | ANALYSIS | code review per lane, fresh seat; adversarial (different model preferred) for V-8 and V-9 — the move relation and Tarjan are where this project's defects have lived (`fixpoint_kernel`, 2B-2's `index`/`lowlink` slip) | — | its lane |

Dispatch note for V-9, carried in the brief per spec §6: prefer whoever ran
the **QA-023 SCC evidence** (`2B-2`/`2B-FIX-KO` lineage) — same instrument,
known failure mode. (Pass 0 said "Wave 1's SCC tasks"; no such tasks exist
[SC1].)

### P3 — fixtures, calibration, and the independent re-implementation

| id | kanban | kind | deliverable | holds | needs |
|---|---|---|---|---|---|
| **V-10** | at dispatch | MUTATION | M5 known-bad fixtures + calibration: every invariant fails its fixture with the invariant named (A1); committed numbers reproduced per revised A3 (both 3×2 targets over their denominators); **v1 fails I7** (A4) | `docs/evidence/BATTERY/calibration.md` `data/fixtures/` [SC3] | V-6–V-9, V-R |
| **V-11** | dispatched at G2 | ANALYSIS | **A5 blind re-implementation**: one invariant from {I4, I5, I7} — chosen by the acceptance auditor, not the author (S2) — re-implemented from spec + schema only | `docs/evidence/BATTERY/reimplementation.md` [SC3] | G2 (not V-6–V-9) |
| **V-12** | at dispatch | ANALYSIS | acceptance audit of A1–A6 evidence | — | V-10, V-11 |

Two independence rules, now with enforcement [SM3]:

- **V-11's blindness is chronological, not honorary.** V-11 dispatches at G2
  and its deliverable is **committed before V-6's first commit** — V-6's
  `needs` encodes this, and then the battery source does not exist to be
  read. If chronology slips, V-11 runs in a git worktree pinned to the
  pre-P2 commit. Its row carries
  `caps=independence:has-not-read-src/vb_*`. READS excludes `src/vb_*.zig`,
  `src/verify_battery.zig`, the V-4/V-5 documents, all lane deliverables
  and reviews, and V-10's fixtures; READS includes the ratified spec, the
  ratified schema, and the artifact under test — nothing else. Different
  model than the lane author; same-model disclosed loudly if unavoidable.
- **At least one V-10 fixture is authored by a seat other than the
  invariant's implementer** — a too-easy fixture passes R2 while proving
  nothing (the 2B-5 positive-control precedent).

Every `holds` entry above is a concrete repo-relative path, registerable
verbatim, so V-10, V-11 and V-13 hold disjoint files and are genuinely
concurrent [SC3].

**Gate G3 — human ratifies the instrument.** Only a ratified battery runs
the fleet; running it early converts sixty cheap runs into sixty rumors.

### P4 — the fleet run

| id | kanban | kind | deliverable | holds | needs |
|---|---|---|---|---|---|
| **V-13** | at dispatch | RUN | the §6a matrix: five gobans × in-scope artifacts (spec A2's enumerated list); I5 once per goban (S1); results + proposed rows → `docs/evidence/BATTERY/fleet.md` | `docs/evidence/BATTERY/fleet.md` [SC3] | G3 |
| **V-14a–e** | at dispatch | MUTATION | register absorption, **one task per goban** (2×2, 3×2, 3×3, 4×3, 4×4): proposed rows → `CLAIMS.md` through the normal serial pipeline [SS3] | `docs/epistemic/CLAIMS.md` | V-13; V-14b needs V-14a, etc. (serial) |

Concurrency at P4 is **RSS-metered, not agent-metered** (R7): the runner
caps each process at 4 GB; the project-wide sum — at most two 4×4-scale
invocations in flight, this sprint and oracle-v2 combined — **is owned by
Orcha at dispatch time, with the human as backstop** [Q4]. A seat that wants
a heavy run and cannot see the global count asks before dispatching; it does
not assume. If a `flock`-guarded slot count in `tools/runner` costs a few
lines, build it opportunistically; do not block the sprint on it. The
battery never writes the register (R4); V-14 tasks serialise on the
`CLAIMS.md` hold like any other mutation.

## 2. Parallelism summary for Orcha

```
P0:  V-1 (done) ──► V-2 (done) ──► V-3 ──► [G1]
     V-R ─────────────────────────────────┘ (before V-10, off critical path)
P1:  [G1] ──► V-4 ──► V-5 ──► [G2]
P2:  [G2] ──► V-11 (commit first), then V-6; V-7, V-8, V-9 (reviews trail)
P3:  lanes + V-R ──► V-10 ──┐
     V-11 ──────────────────┼─► V-12 ──► [G3]
P4:  [G3] ──► V-13 ──► V-14a…e (serial register absorption)
```

Critical path: V-3 → G1 → V-4 → V-5 → G2 → **V-9 (the long pole, per S4)** →
V-10 → V-12 → G3 → V-13 → V-14. V-11 is off the critical path by
construction — and the construction is now real: disjoint `holds` paths and
a commit-before-V-6 ordering rather than a shared directory [SC3, SM3]. Use
`needs=`, not `set=`.

## 3. Cross-sprint coordination (oracle-v2)

- **Schema anticipates bracket artifacts.** oracle-v2's WZO2 stores L/H, and
  I2/I3/I10 are already stated in bracket form. V-4's schema takes artifact
  kind (pinned-V vs bracket) as an input, so the battery runs against WZO2
  the day it exists — the declared M4-overlap merge stays out of scope, but
  nothing in the schema forecloses it.
- **A4's target is independent of oracle-v2:** v1's DTT defect is the free
  known-bad fixture; oracle-v2 replacing v1 does not remove the file, and
  A4's inline path + SHA-256 pin makes the target immune to `data/` churn
  [SM5].
- **Shared RSS meter** as in §1/P4: two 4×4-scale invocations project-wide,
  owned by Orcha; oracle-v2's strategy declares the same meter
  (`docs/epic-01-markovian/sprints/oracle-v2/pass0/plan.md`).
- **No file contention:** the battery touches no solver-held path and never
  `src/gtp.zig` (held by oracle-v2 M3 for its sprint duration).

## 4. What would falsify this strategy

- **V-3 returns REDO:** the premise that the pass-0 defects were reparable
  in place collapses; strategy withdrawn, not patched.
- **The feasibility memo's budget is breached in practice** (V-9 measures
  > 4 GB despite the plan): fallback tiers engage; if even F4 (size
  threshold) is unacceptable to the human, I5 leaves the battery — a spec
  change through G1, not a quiet scope trim.
- **A4 fails at V-10 — the battery passes v1:** the instrument is not
  sensitive; the fleet run does not happen; finding reported as the headline
  negative.
- **V-11 disagrees with the battery:** §1's premise is not yet earned; the
  disagreement is adjudicated (fresh seat) before G3, and the fleet waits.
- **A clean battery run disagrees with a committed register figure:**
  **reference-bad** — the register entry is audited before the battery is
  [SS2]. The 3×2 spread is the standing example; V-R exists so this fires as
  "reference disputed, here is the spread," not "the sprint may be broken."
- **I5 contradicts stored `KO_SENSITIVE` at 3×2 beyond the known spread:**
  larger-than-sprint finding; escalate to the human immediately [SC2].

## 5. For the pass-1 auditor

Grade **blocker / critical / must / should / could**; verdict **PASS /
NEEDS-FIX / REDO**. Write to `docs/epic-01-markovian/sprints/verify-battery/archive/spec-audit.md`
(one audit covers the revised spec and this document).

1. V-6 now needs V-11's commit [SM3]. That puts a blind ANALYSIS task ahead
   of the harness build on the dependency graph. Is the independence worth
   the serialisation, or should the worktree variant be the default so V-6
   starts at G2?
2. A3 carries two 3×2 census targets pending V-R. If V-R *refutes* the
   36-phantom identity, what happens to V-10's gate — block, or carry the
   divergence as reference-bad into the fleet run?
3. R8 (import nothing) triples the battery's implementation surface. Does
   the strategy's schedule survive an honest costing of three re-implemented
   subsystems (loader, addressing, rules engine) across V-6–V-9?
4. Is one pass-1 audit for two documents (spec + strategy) sufficient
   independence, or does the coupling hide anything?
