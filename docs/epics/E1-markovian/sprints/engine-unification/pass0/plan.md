# engine-unification — pass0 plan

```
Task: T226 · Role: sprint manager · Model: not stated at dispatch · Date: 2026-08-01
Revision: 1 · Status: PROPOSED
```

## Pass shape

Three phases, strictly sequential. Each phase gates on the previous — a phase-2
subagent that runs before the acceptance check is fixed produces worthless
verdicts.

| phase | what | subagents | files touched |
|---|---|---|---|
| P0 — fix instruments | acceptance-check defects (T221 replacement) | 1 (DSPro) | `src/managent/main.zig`, test file |
| P1 — build harness | differential harness (T225 replacement) | 1 (DSPro) | new `src/differential.zig`, test file |
| P2 — run matrix | populate agreement matrix at all sizes | 2 parallel (DSPro + DSFlash) | `docs/evidence/GLOBAL.DIFFERENTIAL/` |

Max two concurrent DeepSeek subagents (rate limit). P0 and P1 are serial
(mutation on `src/`). P2 runs two measurements in parallel (disjoint output
files).

## Phase 0 — fix instruments

**Why first.** The acceptance check reads `.exited` on a union that may be
`.signal`. A SIGKILLed command currently reports PASS. Until this is fixed,
every acceptance verdict this sprint produces is worthless. The brief and the
draft spec both state this.

**Task.** One DSPro subagent. Scope:

1. Fix `acc_result.term.exited != 0` — treat any non-`.exited` termination as
   failure, report which signal.
2. Fix `deliverables=` parser — stop at next `key=` token, not just `-->`.
3. Require non-empty reason for `--skip-acceptance`.
4. Regression test per defect, red before green.
5. Commit. `managent done` with `--status pass` and `acceptance=tools/regression-T227.sh`.
   (AC-S1 verification — that a SIGKILLed acceptance is rejected — is demonstrated
   by a separate throwaway task, not by P0's own `done` acceptance, since after the
   fix a SIGKILLed command is correctly REJECTED and cannot produce a `done` verdict.)

**Deliverable:** committed fix + passing regression tests + `findings/T226-P0-*.json`.

**Hold:** `src/managent/main.zig` — declare on kanban before dispatch.

## Phase 1 — build differential harness

**Why second.** The harness is the core instrument. It must exist before any
agreement measurement. Its own correctness gates every finding that follows.

**Task.** One DSPro subagent. Scope:

1. Create `src/differential.zig` — a test harness that:
   - Takes a goban size and an operation name
   - Enumerates input states (exhaustive for 2×2, 3×2, 3×3; sampled for 4×4)
   - Runs every available implementation of that operation on each state
   - Reports: how many implementations, how many agree, every disagreement
     with a concrete witness input
2. Registration is cheap — adding an implementation is a one-line registration,
   not a rewrite.
3. Pure functions where possible. Entanglement with global state or file I/O
   is noted — it predicts which code will be hard to reuse.
4. **No refactoring of the implementations under comparison.** Observe first.
5. TDD: harness's own tests first, including a known-bad fixture it catches.
6. The double-pass case is the first operation wired, because it is the most
   size-invariant rule in Go and a pass-encoding error survived to 518 MB.
7. Commit. `managent done` with `--status pass` and an `acceptance=` that runs
   the harness's own tests plus a 2×2 double-pass smoke test.

**Deliverable:** `src/differential.zig` + tests + `findings/T226-P1-*.json`.

**Hold:** `src/differential.zig` (new file — declare on kanban).

## Phase 2 — populate agreement matrix

**Why third.** The harness is built and verified. Now run it.

**Tasks.** Two parallel DSPro/DSFlash subagents:

| subagent | goban sizes | operations | budget |
|---|---|---|---|
| P2a (DSPro) | 2×2, 3×2, 3×3 | double-pass, area score, legality, capture, encode/decode | exhaustive |
| P2b (DSFlash) | 4×4, 4×3 | double-pass, area score, legality | 120 s sampled (≥10,000 random positions, fixed seed) |

P2a also runs the ADR-0020 truncation-agreement check: verify the 24-state
standing fixture produces gap = 0 across all 172 reachable non-terminals at 2×2
(loopy-game fixpoint values vs first-revisit truncation values agree on all).

Each writes findings to `docs/evidence/GLOBAL.DIFFERENTIAL/matrix-<size>-2026-08-01.md`.
Disagreements are reported with witness inputs, not fixed.

Each subagent commits its own matrix files and marks its task done with
`acceptance=` verifying the matrix file exists and is parseable (e.g.
`test -s <matrix-file>`). P2a also verifies the ADR-0020 gap is zero.

**Deliverable:** agreement matrix populated + committed +
`findings/T226-P2a-*.json`, `findings/T226-P2b-*.json`.

## Concurrency discipline

- P0 holds `src/managent/main.zig`. Release on `done`.
- P1 holds `src/differential.zig` (new). Release on `done`.
- P2a and P2b touch only `docs/evidence/GLOBAL.DIFFERENTIAL/` — disjoint
  files, safe to parallelize.
- `src/oracle_v2_build.zig` — T212 is done; no restriction, but pass0 does not
  modify it except as strictly required to load its encode/decode logic for
  the differential harness comparison.
- No phase touches `src/exp4_solve.zig`, `src/exp5_solve.zig`,
  `src/exp6_solve.zig`, `src/rules.zig`, `src/score.zig`, `src/terminal.zig`,
  `src/state.zig`, `src/superko.zig` — observation only.

## Audit gates

| phase | gate | instrument | actor |
|---|---|---|---|
| P0 spec+plan | before dispatch | document review (fresh session) | DSFlash subagent (T253) |
| P0 build | after commit | independent verification: reproduce one defect, confirm fix | DSPro subagent (T254) |
| P1 design | before build | adversary review of harness API | DSPro subagent (T255) |
| P1 build | after commit | independent run: does the known-bad fixture actually fail? | DSFlash subagent (T256) |
| P2 results | after matrix populated | numbers audit: denominators, witness validity | DSPro subagent (T257) |

## Task IDs

New kanban tasks minted as T227, T228, T229, T230 (exact count depends on
parallel split). Created via `managent suggest` with `needs=T226` so they
don't become dispatchable before this plan is ratified.

## Effort estimate

| phase | subagent model | estimated wall time |
|---|---|---|
| P0 | DSPro | 15–30 min |
| P1 | DSPro | 30–60 min |
| P2a | DSPro | 15–30 min |
| P2b | DSFlash | 5–15 min |

Total: ~1–2 h elapsed (P0+P1 serial, then P2 parallel).

## Pass boundary report

After P2 completes: what agreed, what disagreed, what was promoted (none in
pass0), what was demoted (none in pass0), and what could not be settled.
Commits for P0 and P1 deliverables. `managent done T226` with verdict.
