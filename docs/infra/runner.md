# tools/runner — guarded runner for agent builds

**Status:** landed 2026-07-29, B-2 from `docs/infra/host/incident-2026-07-29.md`.
**Wall/CPU ceiling + sweep:** added 2026-07-29, RUNNER-CEILING (DSFlash).

**Why.** The 2026-07-29 02:37 host kernel panic was caused by a `zig
build-exe -O Debug` of `src/oracle.zig` (or similar) ballooning to
12.5 GB RSS / 21.8 GB peak while the compressor was already at 100 %
of its segments limit. Jetsam did not act in time; `watchdogd` starved
91 s; the kernel panicked on core 0. The fix is a guard that does not
depend on the agent's discipline:

- **default `-O ReleaseFast` / `-Doptimize=ReleaseFast`** — the LLVM
  path in Debug is the memory hog; ReleaseFast is the only
  agent-build mode that does not exceed the RSS cap on a sane brief.
- **three ceilings, all default-on**: RSS (4 GB), wall (1800 s), CPU
  (3600 s) — hard SIGKILL on the process group on any breach.
- **`--sweep` mode**: standalone top-CPU-consumers listing for
  detecting orphaned zig processes.

**Why three ceilings.** A `zig test` binary spinning at 0% RSS sat
undetected for 5 hours because name-based greps missed the anonymous
process. The RSS guard would never fire. The wall ceiling catches the
long-duration case; the CPU ceiling catches the high-throughput case.
macOS does not have `timeout(1)` — the runner is the project's only
reliable time backstop.

**Reference.** Opus 5's EXP-9 run, 2026-07-29 03:00–03:40, used the RSS
pattern; the panic did not recur. Ceilings added by DSFlash/RUNNER-CEILING
per `docs/infra/dispatch/RUNNER-CEILING.md`.

## Usage

```sh
tools/runner [options] -- <command> [args...]
tools/runner --sweep            # standalone, no command needed
```

The `--` separates runner flags from the wrapped command. The runner
walks the process tree of `<command>` every `--poll-ms` (default 250)
and SIGKILLs the *process group* (not just the wrapper's child) the
moment any ceiling is breached. Exit code **124** (the timeout
convention) on guard kill. Per-member peak RSS and CPU are logged on
exit by default.

### Options

| Flag | Default | Meaning |
|---|---|---|
| `--rss-cap-mb <N>` | 4096 | hard RSS ceiling (MB); 0 to disable |
| `--max-wall <s>` | 1800 | hard wall-clock ceiling (seconds); 0 to disable |
| `--max-cpu <s>` | 3600 | hard cumulative-CPU ceiling (seconds); 0 to disable |
| `--poll-ms <N>` | 250 | check interval |
| `--no-prepend-zig` | (off) | do not auto-add an optimize flag to `zig` invocations |
| `--log-rss` | (off) | log per-member RSS every poll (verbose) |
| `--no-show-peak-on-exit` | (on) | skip the per-member peak log |
| `--sweep` | (off) | standalone: list top CPU consumers on the host |
| `--task-id <id>` | (none) | worker/task identifier (e.g. DSPro/2B-5); enables directive checking and heartbeat emission |
| `--directive-poll-s <N>` | 10 | re-check directives every N seconds during the run; a `pause`/`kill` directive then stops a RUNNING command (T370); 0 to disable |

### `--sweep` mode

Runs `ps -axo pid,etime,cputime,command`, sorts by CPU time
descending, and shows the top 20 processes. Useful for finding orphaned
`zig` test/build binaries (which compile to anonymous `.zig-cache/`
names and are invisible to `ps | grep zig`). Exits 0 after displaying.

### `zig` integration

When the wrapped command is `zig`, the runner auto-adds an optimize
flag if missing:

| subcommand | added |
|---|---|
| `zig build` | `-Doptimize=ReleaseFast` |
| `zig build install` | `-Doptimize=ReleaseFast` |
| `zig build-exe` / `build-lib` / `build-obj` / `test` / `run` | `-O ReleaseFast` |

Disable with `--no-prepend-zig` if you have a specific reason
(rare; the project's correctness runs use `-Doptimize=ReleaseSafe`
per `AGENTS.md`, but agents should default to ReleaseFast for speed
+ memory).

## Examples

```sh
# Build the project under the guard. Auto-adds -Doptimize=ReleaseFast.
tools/runner -- zig build

# Run a regression that uses 200k games; 8 GB ceiling, 1 h wall.
tools/runner --rss-cap-mb 8192 --max-wall 3600 -- zig build-exe -O ReleaseFast \
    src/arena.zig -femit-bin=/tmp/arena

# Verify the RSS guard kills a runaway.
tools/runner --rss-cap-mb 100 -- python3 -c "x=bytearray(500*1024*1024); \
    [x.__setitem__(i,1) for i in range(0,len(x),4096)]; \
    import time; time.sleep(30)"
# → [runner] KILL: RSS cap 100 MB exceeded
# → [runner] exit 124 (RSS cap 100 MB exceeded) in 0.1 s

# Verify the wall ceiling kills a long sleeper.
tools/runner --max-wall 2 -- sleep 60
# → [runner] KILL: wall ceiling 2s reached at 2.2s elapsed
# → [runner] exit 124 (wall ceiling 2s reached at 2.2s elapsed) in 2.2 s

# Verify the CPU ceiling kills a tight spinner.
tools/runner --max-cpu 1 -- python3 -c "x=0; \
    for i in range(50_000_000): x+=(i*i)&0xFF; print(x)"
# → [runner] KILL: CPU ceiling 1s exceeded (1.1s total)
# → [runner] exit 124 (CPU ceiling 1s exceeded (1.1s total)) in 1.1 s

# Sweep for orphaned zig processes.
tools/runner --sweep
```

## Platform notes

- **macOS / BSD:** RSS read via `ps -o rss= -p <pid>` (kB). CPU time
  read via `ps -o time= -p <pid>` (total CPU = user+system, format
  `[[hh:]mm:]ss.cc`). Process tree via `ps -axo pid=,ppid=`.
- **Linux:** RSS read from `/proc/<pid>/status` (VmRSS in kB). CPU
  time read via `/proc/<pid>/stat` (utime+stime, ticks converted).
  Process tree by walking `/proc/<pid>/status` for PPid. **Faster
  and more accurate on Linux**; macOS's `ps` is the fallback when
  /proc is absent.

## macOS `timeout(1)` gap

macOS does not ship `timeout(1)`. The command is part of GNU coreutils
and is available via Homebrew (`brew install coreutils` → `gtimeout`),
but is **not** present on a stock macOS install. This runner replaces
that missing tool for the project. See `docs/infra/host/macos-timeout-gap.md`.

## WORKER-CHANNEL additions (2026-07-29)

### Identity: `--task-id` or `MANAGENT_TASK_ID` (T370, 2026-08-06)

Every run should carry a task identity, by one of two channels:

1. **`MANAGENT_TASK_ID` env var (preferred)** — the dispatch wrappers
   (`bin/subagent`, `bin/ollama-subagent`, `tools/bakeoff.sh`) export it on
   the child, so every **nested** `tools/runner` invocation inherits it
   without any call site remembering a flag. A worker claimed by hand
   should `export MANAGENT_TASK_ID=<id>` right after claiming — `managent
   claim` prints the line to copy.
2. **`--task-id <id>`** — the explicit per-run override (also enables the
   runner's auto-claim/auto-done behaviour).

A run with **neither** is a *degraded mode*: the runner warns loudly on
stderr that liveness cannot attribute its heartbeats and directives cannot
reach it, and heartbeats land under `runner/<pid>`. This fallback used to
be silent — that is how the fleet ran blind (every real run fell to the
pid form, so `managent liveness` read live and dead rows identically, and
`managent tell <id> pause|kill` never matched a running worker).

### Directive checking

When `--task-id` is set (or `MANAGENT_TASK_ID` env var), the runner reads
`docs/infra/managent/directives.jsonl` before launching the command and prints
any pending (unread) directives to stderr.  If a `pause` or `kill` directive
is pending, the runner **exits 124** without launching the command — the worker
cannot run while paused or killed.

**Mid-run (T370):** directives are re-checked every `--directive-poll-s`
(default 10 s; `0` to disable) while the command executes. A
`managent tell <id> pause|kill` issued after launch therefore lands in a
**running** runner too: the process group is SIGKILLed and the runner
exits 124 naming the directive. A directive for a *different* task never
fires (the runner matches `target` against its own identity only).

### Heartbeat emission

On every invocation (including guard kills and directive blocks), the runner
appends a heartbeat JSON line to `untracked/heartbeat.jsonl`:

```json
{"command":"echo hello","cpu":0.0,"identifier":"WORKER-CHANNEL","rss_mb":0,"task":"WORKER-CHANNEL","ts":"2026-07-29T23:52:33Z","wall":0.3}
```

The heartbeat carries wall-clock time, cumulative CPU, peak RSS, command,
and the task identifier.  These accumulate per task in `heartbeat.jsonl`
and drive `managent liveness` and the staleness checks in `managent audit`.

### `managent liveness` states (T370, 2026-08-06)

`liveness` distinguishes three real states per in_progress task instead of
collapsing them into one "stale":

- `[beating]  last beat Ns ago  (M beats)` — runner beats are landing;
- `[beats stopped Nm ago]` — the task beat once but its beats stopped
  (killed mid-run, hung, or its runner exited without closing);
- `[never beat since dispatch <claimed>]` — no beat ever recorded for the
  task (claimed but never started, or running without identity).

The stale threshold is 5 minutes by default; override per run with
`--stale-min <float>` (minutes) or `LIVENESS_STALE_MIN`. The beat count
`(M beats)` is the number of runner-emitted heartbeats recorded under the
task (one per `[progress]` line, plus one on exit).

### Environment variable

If `--task-id` is not provided, the runner checks the
`MANAGENT_TASK_ID` environment variable as a fallback.

## What the runner does NOT do

- Does **not** swap, compress, or throttle — it SIGKILLs. A more
  graceful path (SIGTERM with a grace period, then SIGKILL) is a
  standing-tier enhancement, not a fix; the rule is "fail loud".
- Does **not** checkpoint, restart, or carry state across runs.
  Each invocation is fresh.
- Does **not** watch for *unrelated* processes. The tree walk is
  anchored to `<command>`; a process the agent does not spawn is
  not measured.
- Does **not** persist state across reboots.

## Provenance

| field | value |
|---|---|
| Author (RSS guard) | Orchestrator (MiniMax-M3) |
| Author (wall/CPU ceiling + sweep) | DSFlash / RUNNER-CEILING |
| Date | 2026-07-29 |
| Reference implementation | Opus 5's EXP-9 build pattern, 2026-07-29 |
| Incident that motivated it | `docs/infra/host/incident-2026-07-29.md` B-2 |
| Brief that added ceilings | `docs/infra/dispatch/RUNNER-CEILING.md` |
| macOS timeout gap | `docs/infra/host/macos-timeout-gap.md` |
| Test on commit | RSS 100 MB cap kills in 0.3 s; wall 2s cap kills in 2.2 s; CPU 1s cap kills in 1.1 s; sweep sorts by CPU |
| Code | `tools/runner` (Python, stdlib only) |
