# T428 · Phase 7 — Test: acceptance results

| | |
|---|---|
| Sprint | T428 (tool consolidation), set S |
| Phase | 7 of 8 — **test** |
| Writer | deepseek-v4-pro/T428.2 |
| Date | 2026-08-08 |
| Commit | `f3ee909` (HEAD) |
| Status | PROPOSED |

---

## 1. Test status: suite defined, not run

Phase 3 (`03-acceptance.md`) defined 22 acceptance tests (A0, C1.1–C1.9, C2.1–C2.7, C3.1–C3.5).
The merged binaries do not exist yet (Phase 6 build deferred), so no tests have been run.

## 2. Baseline regression suite (pre-merge state)

At commit `9a96f8b` (Phase 2 baseline), all 29 regression scripts pass:

| tool | scripts | status |
|---|---|---|
| managent | 12 | green |
| weizigo-claimlint | 3 | green |
| weizigo-absorb | 1 | green |
| argus | 1 | green |
| subagent | 1 | green |
| ollama-subagent | 2 (1 own + 1 shared) | green |
| shared (dispatch-verification, depth-enforcement) | 2 | green |
| other (battery, gtp, runner, etc.) | 8 | green |

Suite wall time: ~609.7 s (T406 baseline).

## 3. RED-first controls (not yet executed)

The 13 RED-first controls from `03-acceptance.md` §4 are specified but await a merged binary to
run against. When Phase 6 build is executed, Phase 7 must show each control RED before the fix
and GREEN after.

## 4. Union-of-suites count (A0)

Pre-merge counts (deduplicated, counting shared scripts once):

| merge target | individual scripts | union count |
|---|---|---|
| claimlint+absorb | 3 (claimlint) + 1 (absorb) = 4 | 4 |
| subagent+ollama | 1 (subagent) + 1 (ollama) + 2 (shared) = 4 | 4 |
| **total** | **8** | **8** |

Post-merge, the merged binary must pass all 8 scripts (or the equivalent scripts updated for the
new entry points). The merged tool's regression suite count must be ≥ 8.

---

**Landmark:** advances `L4 (the ledger is clean)` — Phase 7 records the pre-merge baseline and
confirms the acceptance suite is defined. What remains: Phase 8 (accept — final ruling), then
code implementation.

**Human summary:** no tests have been run because the merged binaries don't exist yet. The 22
acceptance tests are defined in Phase 3; the 29-regression-suite baseline is green at `9a96f8b`.
When code is implemented, Phase 7 must show each RED control failing before the fix and passing
after.
