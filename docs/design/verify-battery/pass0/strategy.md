# verify-battery — STRATEGY

```
Status:   PROPOSED — awaiting independent audit, then human ratification
Author:   Fable/Navigator (claude-fable-5) · 2026-07-31
Process:  sprint checkpoints (spec → strategy → acceptance) per docs/infra/sprint.md;
          execution per docs/infra/delegation/ (DELEGATOR / DELEGATEE / ROLES)
Inputs:   pass0/spec.md (frozen snapshot) · pass0/spec-audit.md
          (NEEDS-FIX: 2 blockers B1–B2, 3 critical C1–C3, 7 must M1–M7, 4 should)
Audit:    this document, before any design task is dispatched
```

## 0. Standing assumptions

1. The pass-0 audit endorses the architecture (one instrument, adversarially
   reviewed once, invoked sixty times) and finds **completeness gaps, not
   structural flaws**. This strategy plans against the spec *as it will read
   after the B/C/M revision*; if the revision changes the architecture, this
   strategy returns to PROPOSED.
2. Every task is registered in `bin/managent`, brief in
   `docs/infra/dispatch/`, header per `DELEGATOR.md`; **no brief names a
   model**. IDs below (`V-1`…) are strategy-local labels.
3. All builds and runs go through `tools/runner` (4 GB RSS SIGKILL).
4. The audit's condition for the sprint's central claim is adopted as a
   planning constraint: the battery earns "one instrument beats sixty" only
   if the invariant set is complete **and the shared-code boundary is
   explicit**. Both are P0 deliverables.

## 1. Phases and gates

### P0 — spec repair + the long-pole head start (concurrent)

| id | kind | deliverable | holds | needs |
|---|---|---|---|---|
| **V-1** | ANALYSIS | **I5 feasibility memo** → `docs/design/verify-battery/pass1/i5-feasibility.md`: memory plan for iterative Tarjan over 51,419,046 nodes under 4 GB (bytes/node, frame stack, on-the-fly adjacency), fallback if breached (sample-only or size threshold), fixture strategy for C2 (corrupt a known-good artifact at one slot → `KO_SENSITIVE` outside the cycle-reachable set), calibration targets (3×2 max SCC = 1,676; Wave 1 SCC-2x2) | — | — |
| **V-2** | MUTATION | spec revision resolving B1, B2, C1–C3, M1–M7 (S/O at reviser's discretion), citing V-1 for B2/C2 | `docs/infra/verify-battery/spec.md` | V-1 |
| **V-3** | ANALYSIS | pass-1 spec audit → `pass1/spec-audit.md` | — | V-2 |

V-1 runs **now**, concurrent with nothing blocking it — it is audit finding
S4 ("M4's design should start before M1's schema is frozen") made concrete,
and its output is the resolution of blocker B2 and critical C2, so V-2
cannot honestly close those findings without it.

Starting positions for the V-2 reviser (report divergence, don't adapt):

- **B1:** add invariant **I10 — TIE value correctness**: `TIE = median(L,
  TIE, H)` at every non-terminal (at minimum `TIE ∈ [L, H]`). The QA-023
  precedent is the rationale; cite it.
- **B2 / C2:** adopt V-1's budget, fallback, and fixture strategy verbatim
  or say why not.
- **C1:** add invariant **I11 — move-set consistency**: for a stated sample,
  the artifact's move set equals the rules engine's legal move set.
- **C3:** pin the v1 artifact by path **and SHA-256** (T126's `SHA256SUMS`
  entry is the source of truth).
- **M6:** add invariant **I12 — score range**: `L, H ∈ [−area, +area]`.
- **M7 (load-bearing — flag for the human at G1):** state the shared-code
  policy: which `src/` modules the battery may import, which it must
  re-implement. The audit's Q5 answer is the guide: every module the battery
  shares with the solver is a blind spot every invariant inherits.
- **M1–M5, M3-exit:** exhaustiveness table per invariant per goban; A2 scope
  (`data/` + `artifacts/`, enumerated); output schema must carry exit code
  and denominator fields; locate the 24 truncation-gap states in a file the
  battery loads; **two failure classes** in the result schema —
  *artifact-bad* (non-zero exit, the battery worked) vs *battery-bad*
  (harness error), so I5 tripping at 3×2 is reportable as the
  larger-than-sprint finding §7 says it is.

**Gate G1 — human ratifies the revised spec**, explicitly including the M7
shared-code policy and the S1 decision (I5 separately invocable, run once
per goban, not per artifact).

### P1 — harness design

| id | kind | deliverable | holds | needs |
|---|---|---|---|---|
| **V-4** | ANALYSIS | M1 design → `pass1/design-M1.md`: CLI, result schema (exit-code classes, denominators, proposed-row format), artifact loading per the M7 policy | — | G1 |
| **V-5** | ANALYSIS | M1 design audit → `pass1/design-M1-audit.md` | — | V-4 |

M4's design does **not** wait here — V-1 already is its design seed; only
its output fields bind to V-4's schema.

**Gate G2 — human ratifies the schema.** Frozen for the sprint thereafter.

### P2 — three invariant lanes (concurrent, disjoint holds)

| id | kind | deliverable | holds | needs |
|---|---|---|---|---|
| **V-6** | MUTATION | M1 harness build | `src/verify_battery.zig` | G2 |
| **V-7** | MUTATION | M2 table invariants: I1, I2, I3, I6 + I10 (TIE) + I12 (range) | `src/vb_table.zig` | G2 |
| **V-8** | MUTATION | M3 fixpoint invariants: I4, I7, I8, I9 + I11 (move-set) + S3 pass-dimension check | `src/vb_fixpoint.zig` | G2 |
| **V-9** | MUTATION | M4 graph invariant I5, separately invocable, per V-1's memory plan | `src/vb_graph.zig` | G2, V-1 |
| V-7r/8r/9r | ANALYSIS | code review per lane, fresh seat; adversarial (different model preferred) for V-8 and V-9 — the move relation and Tarjan are where this project's defects have lived (`fixpoint_kernel`, 2B-2's `index`/`lowlink` slip) | — | its lane |

Dispatch note for V-9, carried in the brief per spec §6: prefer whoever ran
Wave 1's SCC tasks — same instrument, known failure mode.

### P3 — fixtures, calibration, and the independent re-implementation

| id | kind | deliverable | holds | needs |
|---|---|---|---|---|
| **V-10** | MUTATION | M5 known-bad fixtures + calibration: every invariant fails its fixture with the invariant named (A1); committed numbers reproduced (A3); **v1 fails I7** (A4) | fixture files, `docs/evidence/BATTERY/` | V-6–V-9 |
| **V-11** | ANALYSIS | **A5 blind re-implementation**: one invariant from {I4, I5, I7} — chosen by the acceptance auditor, not the author (S2) — re-implemented from spec + schema only, **no battery source in the brief's READS** | one new file under `docs/evidence/BATTERY/` | G2 (not V-6–V-9) |
| **V-12** | ANALYSIS | acceptance audit of A1–A6 evidence | — | V-10, V-11 |

Two independence rules, both from the audit's Q5:

- **V-11 is dispatched blind and in parallel with P2/P3**, not after — it
  needs only the ratified spec and schema, and a re-implementer who has seen
  the battery's source is not independent. Different model than the lane
  author; same-model disclosed loudly if unavoidable.
- **At least one V-10 fixture is authored by a seat other than the
  invariant's implementer** — a too-easy fixture passes R2 while proving
  nothing (the 2B-5 positive-control precedent).

**Gate G3 — human ratifies the instrument.** Only a ratified battery runs
the fleet; running it early converts sixty cheap runs into sixty rumors.

### P4 — the fleet run

| id | kind | deliverable | holds | needs |
|---|---|---|---|---|
| **V-13** | RUN | all five gobans × in-scope artifacts; I5 once per goban (S1); results + proposed rows → `docs/evidence/BATTERY/` | evidence dir | G3 |
| V-14+ | MUTATION | register absorption: proposed rows → `CLAIMS.md` through the normal serial pipeline | `docs/epistemic/CLAIMS.md` | V-13 |

Concurrency at P4 is **RSS-metered, not agent-metered** (R7, audit O4): the
runner caps each process; **Orcha's dispatch pacing is the mechanism that
caps the sum** — at most two 4×4-scale invocations in flight across the
whole project, this sprint and oracle-v2 combined. The battery never writes
the register (R4); V-14 tasks serialise on the `CLAIMS.md` hold like any
other mutation.

## 2. Parallelism summary for Orcha

```
P0:  V-1 ──────────┐
                   ├─► V-2 ──► V-3 ──► [G1]
     (V-1 alone)───┘
P1:  [G1] ──► V-4 ──► V-5 ──► [G2]
P2:  [G2] ──► V-6, V-7, V-8, V-9   (four lanes; reviews trail)
P3:  lanes ──► V-10 ──┐
     [G2] ──► V-11 ───┼─► V-12 ──► [G3]
P4:  [G3] ──► V-13 ──► V-14+ (serial register absorption)
```

Critical path: V-1 → V-2 → V-3 → G1 → V-4 → V-5 → G2 → **V-9 (the long
pole, per S4)** → V-10 → V-12 → G3 → V-13. V-11 is off the critical path by
construction. Use `needs=`, not `set=`.

## 3. Cross-sprint coordination (oracle-v2)

- **Schema anticipates bracket artifacts.** oracle-v2's WZO2 stores L/H, and
  I2/I3/I10 are already stated in bracket form. V-4's schema takes artifact
  kind (pinned-V vs bracket) as an input, so the battery runs against WZO2
  the day it exists — the declared M4-overlap merge stays out of scope, but
  nothing in the schema forecloses it.
- **A4's target is independent of oracle-v2:** v1's defects (DTT constant)
  are the free known-bad fixture; oracle-v2 replacing v1 does not remove the
  file, and C3's path+SHA pin makes the target immune to `data/` churn.
- **Shared RSS meter** as above: two 4×4-scale invocations project-wide.
  oracle-v2's solve (wall ≤ 4 h) and a battery I4/I5 run at 4×4 count
  against the same budget; Orcha meters at dispatch.
- **No file contention:** the battery touches no solver-held path and never
  `src/gtp.zig` (held by oracle-v2 M3 for its sprint duration).

## 4. What would falsify this strategy

- **V-3 returns REDO:** the completeness-gaps-only premise collapses;
  strategy withdrawn, not patched.
- **V-1 finds no ≤ 4 GB Tarjan plan and no acceptable fallback:** I5 leaves
  the battery and becomes a separate instrument — a spec change through G1,
  not a quiet scope trim.
- **A4 fails at V-10 — the battery passes v1:** the instrument is not
  sensitive; the fleet run does not happen; finding reported as the
  headline negative.
- **V-11 disagrees with the battery:** §1's premise is not yet earned; the
  disagreement is adjudicated (fresh seat) before G3, and the fleet waits.
- **I5 contradicts stored `KO_SENSITIVE` at 3×2:** larger-than-sprint
  finding; escalate to the human immediately (both sides are committed).

## 5. For the strategy auditor

Grade **blocker / critical / must / should / could**; verdict **PASS /
NEEDS-FIX / REDO**. Write to `docs/design/verify-battery/pass0/strategy-audit.md`.

1. V-1 before V-2 puts the long-pole memo on the critical path to G1. Is
   that right, or should V-2 close B2 with a conditional and let V-1 land
   during P1?
2. Is V-11's blindness actually enforceable given the briefs are tracked in
   the same repo the re-implementer clones? What must its READS exclude?
3. Does the two-exit-class scheme (artifact-bad vs battery-bad) survive the
   I5-at-3×2 scenario in §4, where the artifact and the battery may *both*
   be right and the committed census wrong?
4. Is Orcha's dispatch pacing a sufficient mechanism for the project-wide
   two-heavy-runs cap, or does it need tooling (a runner-level semaphore)?
5. Sixty cells: does the fleet-run matrix (V-13) actually cover the dozen
   questions × five gobans the spec §1 gestures at, and where is that
   matrix enumerated before V-13 dispatches?
