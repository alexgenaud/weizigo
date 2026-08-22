# suite-truth — the manifest of known reds in `zig build test`

**Task:** T369 (created) · **Author:** deepseek-v4-pro · **Date:** 2026-08-18
**Ratcheted:** T564 · deepseek-v4-flash · 2026-08-21

This file is the single source of truth for why `zig build test` is red. It is
read by `tools/suite-truth.sh`, the gate that runs the suite, extracts the
observed failing set, and exits 0 only when observed == manifest (in either
direction: a new red is loud; a fixed red must be struck). Ratchet down only —
the same shape as the claimlint floor in `tools/hooks/claimlint-floor.json`.

**Baseline (current):** run of 2026-08-21 00:13Z (T564 ratchet), guarded
(`tools/runner`, `-Doptimize=ReleaseSafe`), quiet host (fleet drained), seed
`0x…`, wall ~15 min. Log: the `--log` path of that `sh tools/suite-truth.sh`
invocation. The 2026-08-18 baseline below is historical; the failure classes
changed completely (crashes fixed, compile failures + two shell reds now).

```
Build Summary: 83/96 steps succeeded (8 failed); 777/778 tests passed (1 skipped)
```

- **0 crashes** — the qa023_brute_2x2 / t419_taxonomy / vb_bellman_4x4 crash
  families of the 2026-08-18 baseline are FIXED (T451/T452/T453 landed).
- **4 test modules fail to COMPILE** — the `rules.zig` root+engine module
  conflict (a failure class the original RED-module crash regex cannot see;
  T564 added `RED compile`).
- **4 shell regressions fail** — argus-doctor (state-dependent, T442),
  watch-fleet (NEW, arms F/G), claimlint-promotion and race-p0 (both
  S1/S2-doc-move residue: a tool path was not re-pointed when the file it
  reads moved — one-line re-points will strike them).

## The failed steps

Four compile failures (one root cause), four failing shell regressions. The
crash families of the 2026-08-18 manifest are struck (fixed).

### Compile-failure family — `rules.zig` in both `root` and `engine` (4 modules) — STRUCK 2026-08-22 (T530)

- **Targets:** `src/keybyte_differential.zig`, `src/vb_closure.zig`,
  `src/vb_i11.zig`, `src/vb_mutants.zig` — each failed with
  `src/rules.zig:1:1: error: file exists in modules 'root' and 'engine'`.
- **Cause (historical):** these test roots import `evidence.zig` (root side) and the
  `engine` module (`src/smd1_engine.zig`, which re-exports `rules.zig`)
  together; `rules.zig:34` itself imports `evidence.zig`, so the same file is
  reachable from both module roots and Zig 0.16 refuses a file in two modules.
  `tools/smd1.zig` (which imports only `engine`) compiles fine — the conflict
  is specific to roots that import both paths.
- **Fix (T530, 2026-08-22):** the three battery roots that imported the `engine`
  module BY NAME now import the shim RELATIVELY (`@import("smd1_engine.zig")`)
  — the battery tree stays one module, so no file straddles `root` and
  `engine`. Verified: bare `zig test -O ReleaseSafe src/vb_mutants.zig` (the
  T530 acceptance command) passes, and all five engine-wired artifacts
  (vb_mutants, vb_closure, vb_i11, keybyte_differential, smd1) pass under the
  build.zig wiring. T564 recorded the class; the fix landed in T530's row.

### Shell regression 1 — `tools/regression-watch-fleet.sh` — NEW red

- **Fails:** arms F and G — a seeded worker whose bundle path contains
  "watch-fleet" (`T492-watch-fleet-keypress-reset.md`) must be SHOWN in
  PROGRESS but is missing; arm G inherits (row missing at both widths).
  Reproduces standalone; deterministic.
- **Owning row:** T466/T492 territory · **Verdict:** defect — the live file
  (`untracked/watch-fleet.sh`) does not surface the T492-bundle-path worker.

### Shell regression 2 — `tools/regression-argus-doctor.sh`

- **Cause:** two arms fail: doctor does not surface C7-unabsorbed under CLEAN
  and does not surface deploy staleness under CLEAN, while the arms assert it
  should. At rest C7 = 8 unabsorbed, above the threshold of 5 — exactly the
  state-dependent arm T442 owns (Orchestrator directive D071, 2026-08-18).
- **Owning row:** T442 · **Verdict:** state-dependent (reading of state, not a
  suite defect) — recorded here, do not fix in a suite-truth row.

### Shell regression 3 — `tools/regression-claimlint-promotion.sh` — S1-fold residue

- **Cause:** the 2026-08-21 S1 doc-move (`eb714a7`) moved
  `docs/epic-01-markovian/…/kill-matrix.json` to
  `docs/epics/E1-markovian/…/kill-matrix.json` but did NOT re-point the
  regression's `KILL_MATRIX` path (`tools/regression-claimlint-promotion.sh:39`).
  The script SKIPs (exit 1) on the missing file — "the check is blind" is a
  loud failure by design.
- **Fix (one line, not executed here):** re-point `KILL_MATRIX` to the new
  path; the regression then runs its controls. **Owning row:** the S1.5
  re-point residue (T557) · **Verdict:** defect (stale hardcoded path).

### Shell regression 4 — `tools/regression-race-p0.sh` — S2-move residue

- **Cause:** the 2026-08-21 S2 move (`966da63`) moved
  `docs/infra/races/grand-race-p0-fixtures.sha256` to
  `docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/`, but
  `tools/race-p0-verify.sh:57` still joins `docs/infra/races/…`. The live-tree
  null arm therefore NO-GOs on a missing seal file. The docstring at line 4
  was re-pointed (`6fb5801`); the SEALS path was missed.
- **Fix (one line, not executed here):** re-point `SEALS` to the new path.
  **Owning row:** the S2 re-point residue (T557) · **Verdict:** defect (stale
  hardcoded path).

## Struck — the 2026-08-18 crash families (fixed by T451/T452/T453)

The three crash families this file was created to track are **fixed at HEAD**;
their full cause analysis lives in the 2026-08-18 baseline commit of this file
and in the T451 (`t419_taxonomy` intCast), T452 (`qa023_brute_2x2` L/H
fixpoint) and T453 (`vb_bellman_4x4` applyMove OOB) findings. Struck by T564:

- `t419_taxonomy` — 1 crash → fixed (T451).
- `qa023_brute_2x2` — 4 crashes → fixed (T452).
- `vb_bellman_4x4` — 2 crashes, two binaries → fixed (T453).
- `tools/regression-absorption-machinery.sh` — hardcoded register count
  updated → green (T406 follow-up landed).

Also struck earlier, unchanged: `regression-managent-integrity.sh`
(deploy-staleness, T369) and `regression-git-commit-mine.sh` (env-bleed, T454)
— both remain deploy-hygiene readings that re-appear if the suite runs before
a deploy; `zig build deploy-managent` clears them.

## Corrections to the 2026-08-18 brief (historical)

- **claimlint C9 is 0, not 1.** The run-2 log's `C9 tree-mapping violations: 1`
  was a **suite-time artifact** — a seeded register inside
  `regression-precommit.sh`'s seeded-defect control, which passed by design.
  The live register and the tree-map are in lockstep; `bin/weizigo-claimlint`
  reports C9 = 0. Nothing to fix.
- **The brief undercounted the shell reds.** Four `run sh failure` steps
  existed; two were struck (managent-integrity deploy-hygiene by T369,
  git-commit-mine env-bleed by T454) and the remaining two are now the
  state-dependent argus-doctor (T442) plus the fixed absorption-machinery.

## Machine section — parsed by `tools/suite-truth.sh`

Do not edit the lines below without re-running the gate (ratchet only).

RED script tools/regression-argus-doctor.sh
RED script tools/regression-claimlint-promotion.sh
RED script tools/regression-race-p0.sh
RED script tools/regression-watch-fleet.sh
COUNT steps-failed 4
COUNT tests-crashed 0
