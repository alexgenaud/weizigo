# argus — STRATEGY

```
Status:   PROPOSED (rev 1)
Author:   DSPro/T189 · 2026-07-31
Inputs:   docs/epic-01-markovian/sprints/argus/pass0/spec.md (Opus 5, rev 1, PROPOSED)
Process:  docs/infra/sprint.md rev 4, RATIFIED (d53c2a8)
```

## 0. Standing assumptions

1. **Tier B, human-only approval.** Per spec declaration — Argus writes
   nothing but two git-ignored files, holds no authority, and costs only
   attention. No external approver beyond the human is required. Audit gates
   still apply per sprint.md, but the human is the sole gate-holder.
2. **Spec audit is the gating dependency.** The spec (§9) calls for an audit
   before plan.md is written. As of this writing the spec audit has not
   landed in `archive/spec.audit-1.md`. If the audit returns REDO or
   blocker-level findings, this plan is withdrawn and re-drafted. If it
   returns PASS-WITH-EDITS, the edits are applied and this plan stands.
3. **All builds and runs through `tools/runner`** (4 GB RSS SIGKILL).
   Argus is read-only but still executes commands — the runner is the
   guardrail.
4. **M2 (design.md) blocks M3 and M4.** The spec is explicit: "Two agents
   improvising a log grammar concurrently is the EXP-4→EXP-7 shape." M3 and
   M4 dispatch only after the human ratifies design.md.
5. **Model for M3/M4 is DSFlash** per spec R4 — the cheap fast tier. The
   builder (DSPro/T189) writes M1 and M2; the cheaper model executes M3 and
   M4 against the frozen design.
6. **No `set=` gating needed.** Every module touches a disjoint path.
   `needs=` expresses the real dependency (M3 needs M2; M4 needs M3).

## 1. Phases and gates

### P0 — spec audit (blocking, already dispatched)

The spec auditor (§9) writes to
`docs/epic-01-markovian/sprints/argus/archive/spec.audit-1.md`. This plan is
contingent on the audit not returning REDO.

### P1 — role + format (builder, this session)

| id | kanban | kind | deliverable | holds | needs |
|---|---|---|---|---|---|
| **A-1** | T189 — **this document** | ANALYSIS | M1: `docs/infra/roles/ARGUS.md` — the role definition in the voice of its siblings (AUDITOR.md, ORCHESTRATOR.md, DABIR.md). R3 write allowlist and forbidden verbs verbatim, advisory boundary, the Auditor/Orcha/Argus boundary, on-resume read order. | `docs/infra/roles/ARGUS.md` | — |
| **A-2** | T189 — **this document** | ANALYSIS | M2: `docs/epic-01-markovian/sprints/argus/pass0/design.md` — log grammar, append-only mechanism, summary layout, recomputability contract (A4), registry path decision. | `docs/epic-01-markovian/sprints/argus/pass0/design.md` | — |

M1 and M2 are concurrent per spec — they touch disjoint files. The builder
writes both in this session.

**Gate G0 — human ratifies plan + design.** The human reads plan.md,
design.md, and ARGUS.md (M1); confirms the log grammar is what he wants;
confirms the registry path. This is the only gate that gates M3.

### P2 — checklist registry (delegated, DSFlash)

| id | kanban | kind | deliverable | holds | needs |
|---|---|---|---|---|---|
| **A-3** | at dispatch | MUTATION | M3: tracked registry file at `docs/epic-01-markovian/sprints/argus/checklist.md`. Five seed slugs mechanized as exact commands, baselines re-measured against the current tree (not 45deb10), dated, the R11 growth rule recorded verbatim, R9 regression semantics per slug. | `docs/epic-01-markovian/sprints/argus/checklist.md` | G0 (A-2 ratified) |

The registry is tracked in git (R10). The first Argus run re-measures
baselines — the 45deb10 baselines in the spec are proposed, not ratified.
A-3's job is to run the five seed commands on the current tree, record the
values, and set `baseline_set_run` to this run's ID.

### P3 — calibration fixtures + first live run (delegated, DSFlash)

| id | kanban | kind | deliverable | holds | needs |
|---|---|---|---|---|---|
| **A-4** | at dispatch | ANALYSIS | M4: calibration fixtures (A1's three seeded defects in a scratch copy), the A2 mode-1 sweep with phantom adjudication, A3/A4/A5 mechanical verification, A6 consumer-load test with Orcha, A7 cost numbers. Evidence under `docs/evidence/ARGUS/`. | `docs/evidence/ARGUS/` | A-3 (registry must exist before calibration runs against it) |

A-4 is the largest module. Its sub-tasks are sequential within the module
(calibrate, then run, then verify) but no other module waits on it — M4 is
the terminal module.

**A-4 sub-steps** (one DSFlash session, sequential):

1. **A1 calibration** — create three seeded defects in a scratch copy, run
   mode 2, confirm exactly three violations each naming its slug and no
   other slug flips. Record the scratch copy path and the result.
2. **A2 mode-1 phantom rate** — one sweep on the unseeded tree, grade every
   finding, route `must`/`critical` findings to a different seat for
   adjudication. Record the phantom rate. If >50%, descope mode 1 per spec.
3. **A3 append-only** — run twice, diff the log: log after run 2 must
   contain log after run 1 as exact byte prefix.
4. **A4 summary reconciliation** — recount from the log alone (by a
   different seat or script), verify every count and date matches the
   summary.
5. **A5 read-only** — `git status --porcelain` after full run shows no
   changes outside the two allowlisted paths.
6. **A6 consumer-load** — Orcha reads `untracked/watchdog-summary.md`,
   either registers a briefed task or states nothing needs registering.
7. **A7 cost** — wall clock, turn/token cost for one checklist run and one
   sweep, artifact-load time broken out.

### Gate G1 — human reviews first-run evidence

The human reads `docs/evidence/ARGUS/` and either accepts Argus as
operational or descopes mode 1 (if A2's phantom rate exceeded half). This
gate closes the sprint's pass0.

## 2. Parallelism summary

```
P0:  spec-audit ──► [audit resolution, if any]
P1:  A-1 (ARGUS.md) ──┐
     A-2 (design.md) ──┼──► [G0: human ratifies plan+design]
P2:  [G0] ──► A-3 (registry)
P3:  A-3 ──► A-4 (calibration + first run) ──► [G1: human reviews evidence]
```

Critical path: spec-audit → G0 → A-3 → A-4 → G1. A-1 and A-2 are concurrent
with each other and with the spec audit's resolution (they touch disjoint
files). A-3 is serial behind G0. A-4 is serial behind A-3. No concurrency
beyond the P1 pair.

## 3. Cross-sprint coordination

None required. Argus touches only `untracked/watchdog.md`, `untracked/watchdog-summary.md`,
and `docs/epic-01-markovian/sprints/argus/checklist.md`. No overlap with
oracle-v2 or verify-battery. The `managent` read-only verbs Argus invokes
are idempotent and require no coordination.

## 4. What would falsify this strategy

- **Spec audit returns REDO** — plan withdrawn, re-drafted against the
  corrected spec. The builder does not proceed past P0 without a ratified
  spec.
- **G0 stalls on the log grammar** — the human rejects the format. The
  builder revises design.md and re-presents. M3/M4 do not dispatch until
  grammar is frozen.
- **A-3 cannot mechanize a seed slug** — a tool is missing, a path changed,
  a command fails. The slug is recorded as `status: blocked` in the registry
  with the failure reason; A-4 runs with the remaining slugs and reports the
  gap. The sprint does not block on tooling fixes (the spec says these are
  "informational not blocking").
- **A1 fails** — the instrument is not sensitive. A-4 stops there; the
  failure is reported as the headline finding. The sprint does not proceed
  to A2–A7 because the watchdog cannot bark.
- **A2 phantom rate > 50%** — mode 1 descoped per spec decision rule. Mode 2
  ships alone. This is a legitimate outcome, not a sprint failure.
- **A5 fails** — Argus mutated something. The role's Tier B safety argument
  collapses. The sprint halts; the finding escalates to the human
  immediately.
- **A6 fails in practice** — Orcha cannot act on the summary. The output
  format is wrong; design.md is revised and A-3/A-4 re-run. This is the most
  likely quiet failure per spec §8.
- **Every finding duplicates claimlint/managent audit** — Argus adds cadence
  and history but no new information. This is a legitimate outcome per spec
  §8; the recommendation is to fold the checklist into `managent audit` and
  retire the role.

## 5. For the plan auditor

Per sprint.md, the plan audit is document review, fresh session. Grade
**blocker / critical / must / should / could**; verdict **PASS /
PASS-WITH-EDITS / NEEDS-FIX / REDO**. Write to
`docs/epic-01-markovian/sprints/argus/archive/plan.audit-1.md`.

Questions worth asking, offered without answers:

1. **P0 contingency** — the plan gates on a spec audit that may not have
   been dispatched yet. Is the builder's "withdraw and re-draft" rule
   sufficient, or should the plan declare a timeout after which it proceeds
   with the spec as-is?
2. **A-4 scope** — seven sub-steps in one DSFlash session. Is that a
   coherent single task, or does "calibrate, run, verify" exceed a DSFlash
   attention budget and need splitting into A-4a/A-4b?
3. **M1 concurrent with M2** — the builder writes both. Is a same-agent
   author for both role definition and format a coupling risk (the role
   assumes a format detail that the format later changes)?
4. **No independent audit of the registry** — A-3 writes a tracked file with
   baselines that become truth. Is a single DSFlash session sufficient for
   baselines that downstream runs will measure regressions against?
5. **G1 vs sprint.md acceptance** — sprint.md §"Acceptance" requires tests
   passing, audit gates passing, consumer-load smoke test, and sprint owner
   ratification. G1 covers the last two. Do the A-4 sub-steps satisfy
   "tests passing" and "audit gates passing" without a separate acceptance
   document?
