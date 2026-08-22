# T592 — tools/scripts census: disposition table

**Task:** T592 · **Author:** deepseek-v4-flash/T592 · **Date:** 2026-08-22 · **Status:** snapshot, read-only
**Machine-readable sibling:** `findings/T592-tools-census.json` (one row per surface, 119 rows)

Census of every executable surface — `bin/` (11), `tools/` (incl. 70 regression scripts), `tools/hooks/` (2),
`untracked/*.sh` (4). Methods: `git log -1` per path, repo-wide caller grep, syntax-check (bash -n / python
ast.parse) on every script, read-only CLI probes, three full regression samples. The tree mutated under the
census (two files vanished, two landed committed mid-run) — treat every `last_commit` as a snapshot.

## Disposition summary

| verdict | count | rows |
|---|---|---|
| KEEP | 41 | everything else — see JSON |
| FIX | 6 | `bin/managent` · `bin/weizigo-arena` · `bin/weizigo-oracle` · `tools/gen-indices` · `tools/complementarity-record.json` · `tools/play_oracle.py` |
| DELETE (ratified only) | 1 | `tools/t265_diagnostic.zig` |
| MERGE-INTO (regressions) | 2 | `regression-managent-done-git.sh` → done-two-phase + integrity · `regression-managent-memory-safety.sh` → integrity |

## The headline — the specimen class, live

The brief's specimen (`managent liveness` → `error: SyntaxError`, build 5036557-dirty) **does not reproduce**
on current builds (c8ce08d-dirty): `liveness` works and now has invocation coverage
(`regression-claim-lifecycle.sh` T432 arms). But the census found the **same class, live**:

- **`managent agent <id> <model>` SEGFAULTS (Abort trap 6 / RC=134)** — deterministically, twice, against
  scratch stores. The store mutation *succeeds*; the crash is in the render path
  (`src/managent/main.zig:1236 cmdAgent` → `std/Io/Writer.zig:1040 alignBufferOptions`).
- **The wired suite catches it**: `tools/regression-managent-lock.sh` control 2 is RED right now — and the
  red is **unregistered**: `docs/infra/suite-truth.md` lists 4 known reds, none of which is this one. So
  `zig build test` today fails on more than the manifest admits, and `suite-truth.sh` would fail loudly.
- **Verbs with zero regression-invocation coverage** (all work today, all spec'd, none tested): `needs`,
  `sync`, `whoami`, `why`. `assign`/`shape` CLI paths have algorithm unit tests but no CLI-invocation test —
  the exact hole the `agent` segfault fell through for the mutating verbs that do have coverage.

## FIX rows (each becomes its own task — census is read-only)

| path | what is wrong | fix shape |
|---|---|---|
| `bin/managent` | `agent` verb segfaults on render after successful write | fix `cmdAgent` render (main.zig:1236) or the alignBuffer misuse; strike nothing — regression already exists; then register/clear the suite-truth red |
| `bin/weizigo-arena` | no-arg `error: FileNotFound` (hardcoded `data/oracle-4x4.wzo`, gone); zero regression; absent from `smoke.sh` deploy_check | point default at an existing artifact or drop the default; add smoke deploy_check + a smoke arm |
| `bin/weizigo-oracle` | alias of gtp; zero dedicated regression; absent from `smoke.sh` deploy_check | add deploy_check arm (or fold into gtp's row); prior silent breakage on record (T534) |
| `tools/gen-indices` | **confirmed silent mutator, first-hand**: no arg parsing — `--help` rewrites 3 tracked INDEX docs (census polluted, reverted) | add a guard (explicit `--write` or read-only default) before anyone else probes it |
| `tools/complementarity-record.json` | 10 citation labels double-T (`findings/TT620-…`); all dead links, single-T twins exist | re-point the 10 labels (T661's record) |
| `tools/play_oracle.py` | no exec bit despite shebang; zero coverage; oldest tool | exec-bit + regression, or retire to fixtures |

## DELETE row (ratified deletion only — needs Orchestrator ratification)

| path | evidence |
|---|---|
| `tools/t265_diagnostic.zig` | imports `tools/exp6_solve.zig` + `tools/colex.zig` (neither exists); zero build.zig wiring; referenced only by two historical audit docs; 2026-08-02 one-off |

## Regression-wiring gaps (regressions that exist but never run)

| script | state |
|---|---|
| `regression-managent-done-git.sh` | unwired; controls folded into done-two-phase + integrity (T337 S5 removed wiring as stale) — keep as fixture |
| `regression-managent-memory-safety.sh` | unwired; audit arms overlap integrity (T204); unique stdout-ordering arms uncovered — merge or rewire |
| `regression-process-ownership.sh` | unwired; the `own` verb's CLI has no other automated coverage — wire or fold |
| `regression-task-identity.sh` | unwired; MANAGENT_TASK_ID identity, not replaced by runner-taskid (runner-side only) — wire or fold |

67 of 71 regression scripts are wired into `zig build test`.

## Other hazards surfaced

- **`tools/race-c-prepare.py`** — confirmed side-effecting on *any* invocation incl. `--help` (wrote 11 lane
  inputs + resealed `untracked/race-grading/race-c/KEY.json`, gitignored); zero callers by grep (orphan by
  reference).
- **`untracked/watch-rebuild.sh`** — confirmed no-args hang (blocks reading a live log argument).
- **`tools/orcha-acceptance.sh`** live run: **ACCEPTANCE FAIL 6 checks** (AC1 claimed-no-worker ×4, AC4
  no-landmark ×4 — the T682 landmark backfill in flight, AC5 duty-blocks-landmark, AC7 2 wall-kills ≤24h,
  AC8 1 unabsorbed, AC9 3 non-conforming findings) — a real seat-health signal.
- **In-flight, uncommitted at snapshot**: `build.zig` + `tools/regression-managent-landmark.sh` (T682; must
  land together — committed build.zig does not yet reference it), `tools/fleet-keeper.sh`, `bin/dispatch`,
  `src/managent/main.zig`, race-g2 findings (T687/T692/T693 schema-non-conforming).
- **Debug scratch in `tools/`**: `regression-token-capture-debug.sh` (untracked, appeared/vanished mid-
  census) — debug fixtures belong in `/tmp/weizigo`, not `tools/`.

## Landmark

Advances `L4 (the ledger is clean)` — the census makes the tool fleet's true state auditable (which tools
run, who covers them, which reds are unregistered). What remains: the 6 FIX rows need dispatch; the DELETE
row needs ratification; the 4 unwired regressions need a wire-or-fold decision.
