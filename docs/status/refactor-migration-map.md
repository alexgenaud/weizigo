# Directory-refactor — migration map + purge list (T557's handoff to S1)

**Author:** deepseek-v4-pro/T557 (orchestrator, dropping to read-only after this) · **For:** the S1
refactor agent · **Seed:** `untracked/refactor-directory-seed.md` (read it first). This file is the
judgment half; the S1 agent writes the mechanical move-and-relink script and runs it against this map.

## Target tree (the seed's scheme)

`docs/epics/E1-markovian/<landmark>/S<n>-<slug>/pass<n>/<phase>.md` — epic · landmark · sprint · pass ·
phase. A sprint lives under its PRIMARY landmark.

## Hard constraints — violate none

1. **Never orphan a citation.** After every section, `bin/weizigo-claimlint` must stay at C2 ≤ 11. The
   script relinks every moved path in committed docs (sed), then claimlint is the gate.
2. **Hardcoded paths move LAST, if at all — never in the main body.** `docs/infra/managent/` (the
   kanban store — managent reads it by path), `findings/` (claimlint scans it by path),
   `docs/epistemic/CLAIMS.md` (the register), `docs/evidence/` (cited by hash). The main body must not
   touch them. IF coherence ultimately demands moving them, do it as a FINAL, separate, atomic commit —
   after shutting down managent and every running task, re-pointing the instrument paths in code, and
   testing that claimlint/managent still read them. That move is decided on its own merits, not as part
   of S1's main body.
3. **Preserve t11/t12** (unlanded seeds) — home them, do not delete.
4. **Run in sections** (one sprint/domain at a time), commit after each. Never one big bang.
5. **Binaries only in `zig-out/` + `bin/`** (both gitignored). Delete the root `./managent`.

## Section 1 — S01-process-ownership (orcha-refactor pass 1, DONE)

| current | new |
|---|---|
| `docs/infra/orcha-refactor/pass1/*` (24 files) | `docs/epics/E1-markovian/L1-dashboard/S01-process-ownership/pass1/` — `01-spec.md`→`spec.md`, `02-scope.md`→`scope.md`, `03-test.md`→`test.md`, `05-plan.md`→`plan.md`, `08-accept.md`→`accept.md`, `01-spec-audit-*.md`→`audit-*.md`, `07-build-audit-disposition.md`→`audit-build-disposition.md`, `OWNER-LOG.md`→`OWNER-LOG.md` (history), `STATUS.md`→`STATUS.md`, `LADDER.md`→`LADDER.md` |
| `docs/infra/orcha-refactor/grading/*` | `…/S01-process-ownership/pass1/grading/` |
| `docs/evidence/orcha-pass1-perfamily-topology/` | **check citations first** — if cited under `docs/evidence/`, leave it there; else move to `…/S01-process-ownership/pass1/perfamily-topology/` |
| `tools/regression-process-ownership.sh` | stays in `tools/` (scripts do not move under `docs/`) |
| `findings/T554/T555/T556/T557/T559-*.json` | stay in `findings/` (hardcoded) |

## Section 2 — S02-model-delegation (races + methodology + t11/t12)

| current | new |
|---|---|
| `docs/infra/races/{goldilocks,metric-vocabulary,measurement-methodology,grand-race,grand-race-p0,grand-race-p0-fixtures.sha256,roster-2026-08-20b,grand-race-ledger.jsonl,T447-escape-sweep,T456-honesty-instrument}*` | `docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/` |
| `docs/infra/model-perf.md` | `…/S02-model-delegation/` — AFTER T558's archive/registry restructure lands (two writers on one file collide; sequence them) |
| t11/t12 seeds (`untracked/bakeoff/pass1-overnight/t11-appetite-design/`, `t12-methodology-v2`) | unlanded — home under `…/S02-model-delegation/design/`, preserve |

## Section 3 — flat process docs (recommendation, open for the operator)

`docs/infra/sprint.md`, `channel.md`, `delegation/*`, `docs/infra/races/…` are the *process* layer, not
pass artifacts. **Recommendation: keep `docs/infra/` as the process home** (moving `sprint.md` breaks
the many citations to `docs/infra/sprint.md` and buys nothing — it is the pass protocol, not a pass
artifact). Only pass/race ARTIFACTS move under `docs/epics/`.

## Later sections (NOT in S1's first pass — engine, resumes after L1)

`docs/epistemic/`, `docs/research/`, `docs/decisions/`, `docs/audits/` are the engine's domain, keyed to
L2–L7. Map them only when L2 resumes; do not touch them in S1 (they are the critical path's home, and
moving them now risks the paused engine work).

## Purge list

1. ~~`./managent`~~ — 1.1 MB stale binary at the repo root. Deleted 2026-08-23 (T701); binaries live only in `zig-out/` + `bin/`.
2. `.gitignore` `ephemeral/` entry — the symlink was retired 2026-08-03; the entry is dead. Delete the line.
3. `untracked/bakeoff/` (≈224 files) — raw race I/O; per the seed, raw I/O goes to `/tmp/`, never cited.
   Archive or delete after confirming nothing committed cites it (claimlint C10 report, not a gate).
4. Flat `findings/` (≈456 files) — regroup is an OPEN question (by epoch? by task?); do NOT move the
   directory itself (claimlint scans it by path).

## The final atomic commit — DECIDED 2026-08-21: the hardcoded paths do NOT move

Assessed on coherence alone, after the sections landed and the suite was green: the four hardcoded
paths stay put. Rationale: they are the instrument-facing root, not pass/race artifacts —
`docs/infra/managent/` is the live kanban store (managent reads it by hardcoded path, and the epic-tree
fold already showed what moving a hardcoded path costs: claimlint C9 went 0→230 until the path was
re-pointed in code); `findings/` is claimlint-scanned by path; `docs/epistemic/CLAIMS.md` and
`docs/evidence/` are cited by hash across the register. Moving them buys no coherence — the "one
canonical tree" goal is already met for the pass/race artifacts under `docs/epics/E1-markovian/` — and
costs a managent+claimlint code re-point + rebuild + retest. The S1.5 residue (23 files citing the
moved `docs/infra/orcha-refactor` + `docs/infra/races` paths) was re-pointed and committed (`6fb5801`).
Closed: the refactor converges at `docs/epics/E1-markovian/` + the stable root.

## Open questions for the operator / S1 agent

1. Home for process docs (`sprint.md` et al.) — my rec: keep `docs/infra/`.
2. `findings/` grouping (epoch vs task) — decide before the regroup, never move the dir.
3. Exact sprint numbering under `L1-dashboard` (`S00-fleet-repair`? `S01-process-ownership`?
   `S02-model-delegation`?).
