# suite-truth — the manifest of known reds in `zig build test`

**Task:** T369 · **Author:** deepseek-v4-pro · **Date:** 2026-08-18

This file is the single source of truth for why `zig build test` is red. It is
read by `tools/suite-truth.sh`, the gate that runs the suite, extracts the
observed failing set, and exits 0 only when observed == manifest (in either
direction: a new red is loud; a fixed red must be struck). Ratchet down only —
the same shape as the claimlint floor in `tools/hooks/claimlint-floor.json`.

The measured baseline is run 2, 2026-08-18 (claude-fable-5, ledger A0016),
clean tree `751f4ed`, `-Doptimize=ReleaseSafe`, quiet machine, low load.
Log: `untracked/log/t369-suite-2026-08-18-run2.log` (3085 lines).

```
Build Summary: 56/65 steps succeeded (8 failed); 927/935 tests passed (1 skipped, 7 crashed)
[runner] exit 1 in 810.9 s
```

- Wall 810.9 s (≈13.5 min). The 35–52 min readings of 2026-08-08 were
  load-contaminated.
- **0 plain assertion failures** — every remaining red is a crash (signal ABRT)
  or a shell-script exit.
- The 7 crashes reproduce deterministically under seed `0xb0d1bce9` on a quiet
  machine; the resource-pressure hypothesis is **falsified**.

## The failed steps

Six crashes across four test binaries (three root causes), plus two
failing shell regressions (two were struck: managent-integrity
deploy-staleness by T369, git-commit-mine env-bleed by T454).

### Crash family 1 — `t419_taxonomy` (1 crash)

- **Target:** `src/t419_taxonomy.zig` — `test.classifyParent: no_loop_a margin is always >= 1`
- **Cause:** `@intCast(best_v - best_loopy_v)` at `src/t419_taxonomy.zig:141`.
  The fuzz test (PRNG seed 99) generates a `best_v` independently of the
  children's actual values, so a loopy child can beat `best_v`; the difference
  `best_v - best_loopy_v` is then negative and does not fit in `u16`. The
  comment's invariant ("the best loopy child cannot tie best_v") only holds when
  `best_v` really is the argmax/argmin over children — the fuzz generator
  violates that precondition.
- **First bad commit:** `cd82915` (T419) — the file has a single commit; born red.
- **Owning row:** T419 · **Verdict:** defect.

### Crash family 2 — `qa023_brute_2x2` (4 crashes)

- **Target:** `src/qa023_brute_2x2.zig` — the four 2×2 smoke tests
  (`empty board Black/White to move`, `passes=1 is NOT terminal`, `1-ko shape`).
  Run inside the `differential` test binary (via `exp6_solve.zig`), not as its
  own build target.
- **Cause:** T360's node-budget alarm at `src/qa023_brute_2x2.zig:204` is
  firing: the 2×2 brute search enumerates simple paths (history check rejects
  only repeats along the current path) and exceeds 20M nodes. The panic text
  itself says the alarm is the signal, not the disease: "Do not raise
  NODE_BUDGET; find what changed the move or terminal semantics."
- **Empirical bisect (single-file `zig test`):** the explosion is **born with
  the file** — the first smoke test hangs at *every* commit from its origin
  `7c71fe5` through `9d066c3` (pre-T339). The budget panic that turns the hang
  into a loud crash was added at `00bd3cb` (T360). **T360's stated suspect
  (T339's kernel extraction) is falsified:** `2062d82` (T339) is purely
  additive to `rules.zig` (0 deleted lines), and the explosion predates it.
- **First bad commit:** `00bd3cb` (T360) for the crash; the underlying
  explosion is at `7c71fe5` (file origin).
- **Owning row:** T360 (the alarm + its still-open diagnosis) · **Verdict:**
  defect — the alarm is firing, which is exactly the case "red-by-design"
  must not be allowed to launder.

### Crash family 3 — `vb_bellman_4x4` (2 crashes, two binaries)

- **Target:** `src/vb_bellman_4x4.zig` — `test.applyMove: 2x2 empty Black at cell 0`.
  The same crash appears in **two** test binaries: `vb_bellman_4x4` and
  `i4_differential` (which imports `applyMove`).
- **Cause:** `applyMove` slices the caller's board `board[0..MAX_N]` at
  `src/vb_bellman_4x4.zig:452`, but `MAX_N = 16` while the 2×2 test passes a
  4-element board — `index out of bounds: index 16, len 4`. `applyMove` takes
  `w`/`h` and is meant to be size-generic, but the ko call assumes a full 4×4
  buffer.
- **First bad commit:** `de4c074` (T343) — `applyMove`, the `board[0..MAX_N]`
  slice, and the 2×2 test all exist at the file's first commit; born red.
  Live since 2026-08-06 (reported by T350), twelve days unowned.
- **Owning row:** T343 · **Verdict:** defect.

### Shell regression 4 — `tools/regression-managent-integrity.sh` — STRUCK this row

- **Was:** T268 deploy-staleness check — `bin/managent` (2849ef8-dirty) !=
  `zig-out/bin/managent` (b2a8517-dirty); `zig build test` builds `zig-out/`
  but does not deploy to `bin/`.
- **Struck by T369:** `zig build deploy` (close-out, STATE rule 6) resolved the
  staleness; the red is gone at HEAD. It is a deploy-hygiene reading, not a
  code defect — it **re-appears** whenever source changes and the suite runs
  before the next deploy, at which point the gate will correctly report it as
  a NEW red (the operator should then `zig build deploy`).
- **Owning row:** T268 (the stamp check is working as designed).

### Shell regression 5 — `tools/regression-git-commit-mine.sh` — STRUCK by T454

- **Was:** `MANAGENT_TASK_ID` (T369, propagated by `tools/runner`) leaked into
  the regression's scratch repo; the wrapper's `--explicit` / task-scope arms
  tried to resolve the live task id in the scratch kanban and refused
  (`cannot resolve task T369 in the kanban`), and a leftover staged
  `docs/amendment2.md` cascaded the refusal into arms 4–9. Deterministic
  whenever the suite ran under a task identity — the fleet's normal case.
- **Struck by T454:** the wrapper now treats env-derived ids that the local
  kanban doesn't carry as advisory (warn + fall through to unlabelled),
  rather than refusing; explicit `--task` / `--bundle` keep the strict refusal
  because the caller named the id on purpose. Both readings now match
  (`sh tools/regression-git-commit-mine.sh` is GREEN under MANAGENT_TASK_ID
  set and unset), so the conditionality that the gate failed on is gone.
  The fix at the wrapper boundary also protects every other harness that
  invokes `tools/git-commit-mine` from a scratch repo, including
  regressions that don't yet exist.
- **Owning row:** T454 (the leak + the wrapper fix) · **Verdict:** fixed at
  the structural layer — env-derived ids are now advisory, kanban-known
  ids are authoritative.

### Shell regression 6 — `tools/regression-absorption-machinery.sh`

- **Cause:** hardcoded register count: arms A1/B1 assert `parsed 221 rows`
  while the live register now has the count `bin/weizigo-claimlint` prints
  on every run (rows parsed). The fixture copies the real register but the
  count is frozen at 221.
- **Owning row:** T406 · **Verdict:** defect.

### Shell regression 7 — `tools/regression-argus-doctor.sh`

- **Cause:** two arms fail: doctor does not surface C7-unabsorbed under CLEAN
  and does not surface deploy staleness under CLEAN, while the arms assert it
  should. At rest C7 = 8 unabsorbed, above the threshold of 5 — exactly the
  state-dependent arm T442 owns (Orchestrator directive D071, 2026-08-18).
- **Owning row:** T442 · **Verdict:** state-dependent (reading of state, not a
  suite defect) — recorded here, do not fix in T369.

## Corrections to the 2026-08-18 brief

- **claimlint C9 is 0, not 1.** The run-2 log's `C9 tree-mapping violations: 1`
  (`GLOBAL.T280-CTRL-SEEDED` doc-missing) is a **suite-time artifact** — the
  seeded register inside `regression-precommit.sh`'s seeded-defect control,
  which passed by design; several regression scripts seed fixture docs into
  the live tree and remove them only in an exit trap (Orchestrator directive
  D071, 2026-08-18, independently confirms the fixture-seeding class). The
  live register and the tree-map (printed by `bin/weizigo-claimlint` on every
  run) are in lockstep; `bin/weizigo-claimlint` reports C9 = 0. Nothing to fix.
- **The brief undercounted the shell reds** (it named only argus-doctor).
  The run-2 log carries four `run sh failure` steps: managent-integrity,
  git-commit-mine, absorption-machinery, argus-doctor. Two reproduce at
  HEAD — managent-integrity was deploy-hygiene and was struck by T369;
  git-commit-mine was env-bleed and was struck by T454. Two remain
  (absorption-machinery's 221↔228 hardcoded count; argus-doctor's
  deploy-staleness arm — state-dependent under T442).

## Machine section — parsed by `tools/suite-truth.sh`

Do not edit the lines below without re-running the gate (ratchet only).

RED module t419_taxonomy
RED module qa023_brute_2x2
RED module vb_bellman_4x4
RED script tools/regression-absorption-machinery.sh
RED script tools/regression-argus-doctor.sh
COUNT steps-failed 6
COUNT tests-crashed 6
