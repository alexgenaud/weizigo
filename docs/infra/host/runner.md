# runner — guarded execution wrapper for weizigo agent/build commands

**Created:** 2026-07-29 · **Updated:** 2026-08-01 (T214: progress watchdog)

## What it is

`tools/runner -- <command>` wraps a command in guard rails that prevent it
from panicking the host. The 2026-07-29 host kernel panic
(`docs/infra/host/incident-2026-07-29.md`) is the precedent — an unguarded
`zig build-exe` in Debug mode exhausted memory and the watchdog rebooted
the machine. The runner is the minimum stand.

## Guards

### 1. RSS cap (`--rss-cap-mb`, default 4096) — safety-critical, always on

Memory exhaustion panics the host. There is no amount of progress reporting
that earns an exemption from an out-of-memory kill. The runner walks the
process tree, sums RSS across all descendants, and SIGKILLs the process
group the instant any member exceeds the cap.

### 2. Progress watchdog (`--progress-timeout`, default 600)

The child reports progress on stderr with lines containing `[progress]`:

```
[progress] fixpoint sweep 12/40
[progress] dtt sweep 32/254 changed=14503
[progress] write chunk 4/9 256 MB
```

The runner parses these lines, forwards them to the runner's own stderr
so the user still sees them, and resets the progress timer. A child that
reports every few minutes runs as long as it needs — T212 was killed at
the default CPU ceiling of 3600 s with the fixpoint converged, the write
never happening. The progress watchdog would have let it finish.

The format is deliberately loose: any line containing `[progress]` is
counted. The text after the tag is for human consumption.

### 3. Fallback ceilings — for silent children only

When a child emits **no** `[progress]` lines at all, the runner falls back
to the traditional hard ceilings:

| flag | default | behaviour |
|---|---|---|
| `--max-wall` | 1800 s (30 min) | SIGKILL after this many wall seconds |
| `--max-cpu` | 3600 s (1 h) | SIGKILL when cumulative CPU across all descendants exceeds this |

These are the old stuck-detectors. They are kept because not every command
can be taught the progress protocol (e.g. `zig build-exe` has no natural
progress hook). The runner says so on stderr at startup:

```
[runner] guards: rss 4096 MB, progress-timeout 600s (10:00), fallback: wall 1800s cpu 3600s (silent children), poll = 250 ms
```

When it sees the first `[progress]` line:

```
[runner] progress watchdog active (first [progress] line seen)
```

After that, only RSS and progress-timeout kills apply.

## How to write a progress-emitting job

Three rules:

1. **Print to stderr.** The runner reads the child's stderr pipe. stdout
   is passed through unchanged.

2. **Include `[progress]`.** The exact format is free, but the tag must
   appear. Good: `[progress] fixpoint sweep 12/40`. Good: `[progress]
   45%`. No: `progress: sweep 12`.

3. **Emit at a natural cadence.** Every sweep, every chunk, every
   percentage point — whatever the job already measures. Do not add a
   timer-driven heartbeat; the runner's poll interval handles the
   timing. The only requirement is that the job emits at least one line
   per `--progress-timeout` seconds.

Example from `src/oracle_v2_build.zig`:

```zig
std.debug.print("[progress] fixpoint {d} sweeps converged={}\n",
    .{ fp4.sweeps, fp4.converged });
std.debug.print("[progress] write chunk {d}/{d} {d:.0} MB\n",
    .{ chunk_n, total_chunks, bytes_written });
```

## Liveness feed

Every `[progress]` line also writes a heartbeat to
`untracked/heartbeat.jsonl`, so `managent liveness` and `managent audit`
reflect real activity. Before T214, `managent audit` warned on every
in_progress task for want of a heartbeat. Now progress lines feed the
kanban automatically.

**Identity (T370, 2026-08-06):** heartbeats land under the task only when
the run carries identity — `MANAGENT_TASK_ID` env (set by the dispatch
wrappers; a worker claimed by hand should `export MANAGENT_TASK_ID=<id>`
after claiming) or `--task-id <id>`. A run with neither warns loudly and
falls to `runner/<pid>`, which liveness cannot attribute and directives
cannot reach. Directives are also re-checked every `--directive-poll-s`
(default 10 s) during the run, so `managent tell <id> pause|kill` stops a
running command, not just the next invocation.

## Platform notes

- **macOS:** no `timeout(1)`. The runner is the project's wall-time
  backstop.
- **RSS detection:** `/proc/<pid>/status` on Linux; `ps -o rss=` on macOS/BSD.
  Falls back gracefully.
- **Process tree:** `/proc` walk on Linux; `ps -axo pid=,ppid=` on macOS/BSD.
- **Non-blocking stderr read:** `fcntl` + `select` for stderr parsing.
  Python standard library only; no external dependencies.

## Usage

```
tools/runner [options] [--] <command> [args...]
tools/runner --sweep                   # standalone: list top CPU consumers
```

Key options:

| flag | default | description |
|---|---|---|
| `--rss-cap-mb` | 4096 | RSS ceiling (hard kill) |
| `--progress-timeout` | 600 | seconds without `[progress]` before kill; 0 to disable |
| `--max-wall` | 1800 | fallback wall seconds for silent children |
| `--max-cpu` | 3600 | fallback CPU seconds for silent children |
| `--poll-ms` | 250 | monitor check interval |
| `--task-id` | — | task identifier for heartbeat and directive checking |
| `--sweep` | — | standalone: list top CPU consumers |
| `--log-rss` | — | log per-PID RSS every poll |

Exit codes: 0 on success, child's exit code on failure, 124 on guard kill.
