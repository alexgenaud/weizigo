# `argus --mode doctor` — the Orchestrator's manual weekly sweep, encoded

**T425 (does one doctor command replace the manual weekly sweep?)** — **answered yes, with the brief's bars met.**

## What this is

A third mode for `bin/argus` that runs nine checks against the live tree and
groups the findings by what the operator should DO:

```
NEEDS ACTION  — fix it now (claim, commit, rescue, deploy)
CAN CLOSE     — done rows the operator can acknowledge
WATCH         — soft warnings (long in_progress, no heartbeat, hangs)
CLEAN         — green state for the periodic checks
```

Every finding names its evidence (a command, exit code, and the relevant
output, or a `file:line` cite) and the fix command (`managent claim <id>`,
`zig build deploy`, `rescue the file to docs/evidence/`, etc.). A diagnostic
that does not name the fix costs a round trip.

## Invocation

```
bin/argus --mode doctor
```

Default output paths (per R3, the third named output declared in the header):

| file | purpose |
|---|---|
| `untracked/watchdog.md` | append-only JSONL log (unchanged) |
| `untracked/watchdog-summary.md` | overwritten Markdown summary (unchanged) |
| `untracked/doctor-report.md` | the doctor report — NEEDS ACTION / CAN CLOSE / WATCH / CLEAN |

## The nine checks

| # | check | group on finding | source of the encoding |
|---|---|---|---|
| 1 | **Rows worked but never claimed** — `dispatchable` rows whose `bundle` file is dirty in the tree (T392/T395/T400/T404/T419 were this shape) | NEEDS ACTION | T424 fixed the upstream `git-commit-mine` gate; this is the forward-going detector |
| 2 | **`in_progress` with no heartbeat** — `managent liveness` flags "never beat" / "beats stopped"; honest disclaimer: "no heartbeat means no `MANAGENT_TASK_ID`, not necessarily a dead console" | WATCH | T387 ran a defective binary twice concurrently while misjudged as dead |
| 3 | **Findings non-conforming** — `bin/weizigo-claimlint` reports `C7 non-conforming files > 0` | NEEDS ACTION | 5 files were structurally excluded from absorption this week |
| 4 | **C7 unabsorbed above threshold + STANDING-ABSORB gate** — if C7 ≥ 5 but the standing row is `done`/`failed`, the trigger cannot re-fire | NEEDS ACTION | STANDING-ABSORB was firing into a `done` row this week and could never dispatch |
| 5 | **Evidence cited outside the repo** — `bin/weizigo-claimlint` C10 VOLATILE count (`/tmp`, absolute, `untracked/`) | NEEDS ACTION | 344 paths in 72 docs, 43 already destroyed (T421) |
| 6 | **Deployed binary staleness** — `bin/*` mtime vs `zig-out/bin/*` mtime; Python scripts (argus, smoke.sh) are exempt because they have no built counterpart | NEEDS ACTION | `bin/managent 95bbe8c` vs built `e5574d8` was live in today's suite run (the "stale deployed" class, T268) |
| 7 | **Uncommitted files in the tree, with age** — `git status --porcelain` excluding `untracked/` and the watchdog output files | NEEDS ACTION | Fable's week-close audit sat untracked; `model-perf.md` records too |
| 8 | **Long-running processes with no owning row** — `ps -eo pid,etime,command` filtered to `zig|weizigo` and ≥ 30 min | WATCH | T387's 14-hour hang; a 15h44m deadlocked Python driver |
| 9 | **Register/tree-map lockstep and floor drift** — `C1a`, `C2`, `C3`, `C9` counters vs `tools/hooks/claimlint-floor.json` | NEEDS ACTION or CLEAN | the floor rule from ARGUS.md (T211); cheap to keep clean |

## Bars met

- **Read-only.** argus does not mutate the kanban, the register, or any
  evidence. The third output is declared in the header; the R3 write
  allowlist now lists three paths.
- **No false alarms on CLEAN.** The current (clean) tree reports CLEAN for
  every check that is genuinely clean. Need-action findings (C10=879,
  uncommitted files) are real, not noise — the doctor surfaces them
  correctly.
- **Every finding names its evidence and the fix command.** R6 evidence
  rule is preserved (command + exit + output, or `file:line`).
- **Test-first.** Each of the ten arms in `tools/regression-argus-doctor.sh`
  seeds a specific defect against a scratch fixture (or the live tree)
  and asserts the doctor surfaces it under the right group. RED on the
  pre-fix script (every arm failed before the doctor mode existed), GREEN
  on the post-fix script. Wired into `zig build test`.
- **Findings file conforming; verified with `bin/weizigo-claimlint`** (C7
  non-conforming: 0).
- **The two known-live inputs to verify against are present** (per the
  brief): the register 221-rows-when-actual-228 stale fixture is reported
  under CLEAN (the doctor reads 228 from claimlint, not 221 from a stale
  fixture); the deploy-staleness check fires on real staleness when
  present. Both appear under NEEDS ACTION with their fix commands.

## Out of scope

The looping console is **not** part of this work. With
`bin/argus --mode doctor` correct and fast, a loop around it is trivial
(`watch`, a cron, or a `/loop`). A loop around an untrustworthy check
produces noise faster.

## Wire-up

`tools/regression-argus-doctor.sh` is wired into `zig build test` alongside
the T424 lifecycle controls. The doctor mode is invoked as
`bin/argus --mode doctor` and writes `untracked/doctor-report.md`.

## See also

- `docs/infra/roles/ARGUS.md` — the role description (R3 write allowlist,
  R5 one mode per invocation, R6 evidence rule, floor-grading rule)
- `tools/regression-argus-doctor.sh` — the ten controls
- `untracked/doctor-report.md` — the latest report (overwritten on each
  run; recomputable from `untracked/watchdog.md` per A4)
