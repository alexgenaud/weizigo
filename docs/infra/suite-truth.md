# suite-truth — the manifest of known reds in `zig build test`

**Task:** T369 (created) · **Author:** deepseek-v4-pro · **Date:** 2026-08-18
**Ratcheted:** T788 · deepseek-v4-pro · 2026-08-23

This file is the single source of truth for why `zig build test` is red. It is
read by `tools/suite-truth.sh`, the gate that runs the suite, extracts the
observed failing set, and exits 0 only when observed == manifest (in either
direction: a new red is loud; a fixed red must be struck). Ratchet down only —
the same shape as the claimlint floor in `tools/hooks/claimlint-floor.json`.

**Baseline (current):** run of 2026-08-23 ~16:32Z (T788 re-baseline), guarded
(`tools/runner`, `-Doptimize=ReleaseSafe`), host: load 3.62/3.68/3.84, ~32.7 GB
free (vm_stat Pages free 1,995,989 × 16 KB), **no local model resident** (no
`mlx-engine` runner, `ollama ps` empty), two cloud lanes in flight (T774 claude
audit, T785 spec — both `claude -p`, ~0% CPU). Wall **906 s**. Log:
`untracked/log/T788-suite.log`. Evidence artifact:
`untracked/log/suite-evidence.log` (26/26 declared readings present).

```
Build Summary: 112/122 steps succeeded (9 failed); 1344/1348 tests passed (1 skipped, 3 failed)
```

- **0 crashes** — the qa023_brute_2x2 / t419_taxonomy / vb_bellman_4x4 crash
  families of the 2026-08-18 baseline remain FIXED (T451/T452/T453).
- **0 compile failures** — the `rules.zig` root+engine conflict (4 modules) is
  FIXED (T530); no `RED compile` entries remain.
- **3 tests FAIL (not crash)** — the `assign:` family in `src/managent/main.zig`
  (see below). The suite's failure mode has shifted from crashes to assertion
  failures, which the gate's crash-oriented regexes mis-classify (see the
  "Gate classification gap" finding — this is T789's to design around).
- **8 shell regressions fail** (was 4 on 2026-08-21): two fixed since then
  (claimlint-promotion, race-p0), six new.

## The failed steps

### RED module `main` — 3 FAILED `assign:` tests (NEW)

- **Target:** `zig test src/managent/main.zig` — 3 of 41 tests fail, all in the
  T635 `assign:` family (`src/managent/main.zig` ~line 11996):
  - `assign: OFF family absent from every candidate list` — expected 5, found 6.
  - `assign: single qualified candidate forces method=forced` — expected
    `forced`, found `random`.
  - `assign: named model is preferred, qualified list still recorded` —
    expected 5, found 6.
- **Cause:** `ox-alpha` (family `ox-alpha`) moved from RESERVED to **SPEND**
  appetite on 2026-08-23 (operator ruling, supersedes T732's RESERVED). The
  qualified candidate list is now SIX models (claude opus/sonnet/haiku, deepseek
  pro/flash, ox-alpha), not five. The T635 test expectations (`candidates.len
  == 5`, `method=forced` when only deepseek-v4-pro survives exclusion) were not
  updated for the sixth candidate. The assign **logic** is correct (ox-alpha is
  spend-qualified); the **test expectations** are stale.
- **Owning row:** ox-alpha placement (T753) / the 2026-08-23 ox-alpha SPEND
  ruling. Fix = update the T635 expectations (or the appetite, if the ruling
  changes).
- **Verdict:** NEW red — test drift, not a logic defect.

### Shell regression 1 — `tools/regression-watch-fleet.sh` — NEW red (kept)

- **Fails:** arms F and G — a seeded worker whose bundle path contains
  "watch-fleet" (`T492-watch-fleet-keypress-reset.md`) must be SHOWN in
  PROGRESS but is missing; arm G inherits (row missing at both widths).
  Reproduces standalone; deterministic.
- **Owning row:** T466/T492 territory · **Verdict:** defect — the live file
  (`untracked/watch-fleet.sh`) does not surface the T492-bundle-path worker.

### Shell regression 2 — `tools/regression-argus-doctor.sh` — state-dependent (kept)

- **Cause:** two arms fail: doctor does not surface C7-unabsorbed under CLEAN
  and does not surface deploy staleness under CLEAN, while the arms assert it
  should. At rest C7 = 8 unabsorbed, above the threshold of 5 — exactly the
  state-dependent arm T442 owns (Orchestrator directive D071, 2026-08-18).
- **Owning row:** T442 · **Verdict:** state-dependent (reading of state, not a
  suite defect) — recorded here, do not fix in a suite-truth row.

### Shell regression 3 — `tools/regression-claimlint-promotion.sh` — FIXED (struck)

- **Cause was:** stale `KILL_MATRIX` path (S1 doc-move, `eb714a7`). **Fixed:**
  T527/T557 re-pointed `KILL_MATRIX` to
  `docs/epics/E1-markovian/sprints/verify-battery/pass1/kill-matrix.json` (file
  exists). Passes standalone (RC 0) and in-suite.

### Shell regression 4 — `tools/regression-race-p0.sh` — FIXED (struck)

- **Cause was:** stale `SEALS` path (S2 doc-move, `966da63`) — and the same
  move left `ROSTER` stale too (the manifest diagnosed only SEALS). **Fixed:**
  T788 re-pointed both `SEALS` and `ROSTER` in `tools/race-p0-verify.sh` to
  `docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/`. Passes
  standalone (RC 0) and in-suite.

### Shell regression 5 — `tools/regression-subagent-prompt.sh` — NEW red

- **Fails:** every arm. `bin/subagent` no longer accepts the `--dsflash` /
  `--dspro` / positional flags the regression drives — the CLI moved to
  `--provider deepseek|ollama|claude|pi`. (In-suite the refusals rendered as
  "REFUSED — you are at the delegation cap (depth 3 of 3)"; standalone at HEAD
  it now renders "missing --provider". `bin/subagent` is being actively edited
  by the guard sprint, so the exact text shifts run to run.)
- **Owning row:** subagent CLI change — T713 resident gate / S08 guard sprint.

### Shell regression 6 — `tools/regression-fleet-keeper.sh` — NEW red

- **Fails:** its `subagent-prompt regression` sub-arm (same subagent CLI cause
  as #5). Every other sub-arm in the script passes.
- **Owning row:** same as subagent-prompt.

### Shell regression 7 — `tools/regression-managent-holds.sh` — NEW red

- **Fails:** arms 1–3 — `managent add` REFUSES a bundle that declares no
  `**Landmark:**` line (the T682 landmark gate). The T539 `write_bundle`
  fixtures do not include a Landmark line.
- **Owning row:** T682 landmark gate — fixture drift (the fixtures predate the
  gate; they need a `**Landmark:**` line added).

### Shell regression 8 — `tools/regression-managent-lock.sh` — NEW red

- **Fails:** control 2 — after the lock holder is SIGKILLed, the mutating
  command fails (RC 134 / SIGABRT in-suite; "error: FileNotFound" standalone —
  symptom is timing/state-dependent). Control 1 (rejection-path release)
  passes.
- **Owning row:** T337 flock store lock — real defect in lock-release recovery,
  not fixture drift.

### Shell regression 9 — `tools/regression-managent-store-pollution.sh` — NEW red

- **Fails:** arm C — the clean lane's `managent done` is now REJECTED without
  `--impression`/`--impression-waiver` (the T522 close gate). The clean-lane
  fixture predates the gate.
- **Owning row:** T522 impression-or-waiver at close — fixture drift.

### Shell regression 10 — `tools/regression-directive-kill.sh` — NEW red

- **Fails:** arms 1–5 — `bin/dispatch` REFUSES the `T6251-bundle.md` fixture
  for declaring no `**Landmark:**` line (T682 landmark gate). **Plus** arm 8d —
  the T616 fixture (a refusal that caused a harness kill) is classified
  `verified=fail` instead of `verified=unreached` (D021 dispatch_verify
  classification defect).
- **Owning row:** T682 landmark gate (fixture drift) + D021 (classification).

### Console surface — `cosmetic-failed-command` regression (surfaces manifest)

Not a reds-manifest row but a gate surface: the CONSOLE carries **2 cosmetic
`failed command:` lines** against a manifest of 0 (see
`docs/infra/suite-truth-manifest.md`). The two lines decompose as:
1. **One genuine noise line** — a passing test binary (the mutant-battery
   module) re-leaked `[EXPECTED] M1–M10 …` readings to stderr via
   `std.debug.print`, the exact class T531/T564 routed through `evidence.print`.
2. **One gate mis-classification** — the `main` test binary's real failure
   (3 failed tests) is counted as "cosmetic" because the gate subtracts only
   *crash* steps, not *failed* steps.

This surface ratchets **down only** (floor 0), so it cannot be re-baselined
away — it needs the noise re-routed through `evidence.print` and the gate's
cosmetic calc to subtract failed steps. Both are T789 (gate design) / T531-T564
territory, recorded here for loudness, not fixed in this row.

## Gate classification gap (T789 input)

The gate (`tools/suite-truth.sh`) was built when the suite's failure mode was
**crashes** (signal ABRT). The suite now fails by **assertion** instead:

- The `RED module` regex (`^error: '[^.']+\.test\.`) matches *any* test error
  line, so 3 `failed:` assertion lines surface as "module `main` crashed" when
  they are failed tests, not crashes.
- The `tests-crashed` extraction (`tests passed (…, N crashed)`) no longer
  parses the Build Summary, which now prints `(1 skipped, 3 failed)` — so
  `OBS_TESTS_CRASHED` is silently empty.
- The CONSOLE cosmetic calc (`test-binary failed-command lines − crashed
  steps`) has no term for *failed* steps, so a real test failure is counted as
  cosmetic noise.

These are findings, not obstacles — T789 (test-gate wiring) owns the redesign.

## Struck — the 2026-08-18 crash families (fixed by T451/T452/T453)

The three crash families this file was created to track are **fixed at HEAD**
and remain struck: `t419_taxonomy` (T451), `qa023_brute_2x2` (T452),
`vb_bellman_4x4` (T453). Also struck earlier, unchanged:
`regression-managent-integrity.sh` (deploy-staleness, T369) and
`regression-git-commit-mine.sh` (env-bleed, T454) — both are deploy-hygiene
**state-dependent** readings that re-appear if the suite runs before a deploy;
`zig build deploy-managent` clears them. The `rules.zig` root+engine compile
family (4 modules) struck by T530 remains fixed.

## Machine section — parsed by `tools/suite-truth.sh`

Do not edit the lines below without re-running the gate (ratchet only).

RED module main
RED script tools/regression-argus-doctor.sh
RED script tools/regression-directive-kill.sh
RED script tools/regression-fleet-keeper.sh
RED script tools/regression-managent-holds.sh
RED script tools/regression-managent-lock.sh
RED script tools/regression-managent-store-pollution.sh
RED script tools/regression-subagent-prompt.sh
RED script tools/regression-watch-fleet.sh
COUNT steps-failed 9
COUNT tests-crashed 0
