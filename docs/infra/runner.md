# tools/runner — guarded runner for agent builds

**Status:** landed 2026-07-29, B-2 from `docs/infra/host/incident-2026-07-29.md`.

**Why.** The 2026-07-29 02:37 host kernel panic was caused by a `zig
build-exe -O Debug` of `src/oracle.zig` (or similar) ballooning to
12.5 GB RSS / 21.8 GB peak while the compressor was already at 100 %
of its segments limit. Jetsam did not act in time; `watchdogd` starved
91 s; the kernel panicked on core 0. The fix is a guard that does not
depend on the agent's discipline:

- **default `-O ReleaseFast` / `-Doptimize=ReleaseFast`** — the LLVM
  path in Debug is the memory hog; ReleaseFast is the only
  agent-build mode that does not exceed the RSS cap on a sane brief.
- **RSS cap, default 4 GB, hard SIGKILL on the process group** —
  Jetsam demonstrably does not act before the kernel watchdog
  does, so the runner *is* the safety net.

**Reference.** Opus 5's EXP-9 run, 2026-07-29 03:00–03:40, used this
pattern; the panic did not recur.

## Usage

```sh
tools/runner [options] -- <command> [args...]
```

The `--` separates runner flags from the wrapped command. The runner
walks the process tree of `<command>` every `--poll-ms` (default 250)
and SIGKILLs the *process group* (not just the wrapper's child) the
moment any member's RSS exceeds `--rss-cap-mb` (default 4096). Exit
code **124** (the timeout convention) on guard kill. Per-member peak
RSS is logged on exit by default.

### Options

| Flag | Default | Meaning |
|---|---|---|
| `--rss-cap-mb <N>` | 4096 | hard ceiling; SIGKILL the group on exceed |
| `--poll-ms <N>` | 250 | check interval |
| `--no-prepend-zig` | (off) | do not auto-add an optimize flag to `zig` invocations |
| `--log-rss` | (off) | log per-member RSS every poll (verbose) |
| `--no-show-peak-on-exit` | (on) | skip the per-member peak log |

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

# Run a regression that uses 200k games; 8 GB ceiling.
tools/runner --rss-cap-mb 8192 -- zig build-exe -O ReleaseFast \
    src/arena.zig -femit-bin=/tmp/arena

# Verify the guard kills a runaway.
tools/runner --rss-cap-mb 100 -- python3 -c "x=bytearray(500*1024*1024); \
    [x.__setitem__(i,1) for i in range(0,len(x),4096)]; \
    import time; time.sleep(30)"
# → [runner] RSS cap exceeded; SIGKILL pgid ...
# → [runner] exit 124 (RSS cap, 100 MB) in 0.1 s
```

## Platform notes

- **macOS / BSD:** RSS read via `ps -o rss= -p <pid>` (kB). Process
  tree via `ps -axo pid=,ppid=`. The runner's `localtime_r` path is
  not used (Zig 0.16.0 dev does not expose `std.c.tm`); see the
  source.
- **Linux:** RSS read from `/proc/<pid>/status` (VmRSS in kB).
  Process tree by walking `/proc/<pid>/status` for PPid. **Faster
  and more accurate on Linux**; macOS's `ps` is the fallback when
  /proc is absent.

## What the runner does NOT do

- Does **not** swap, compress, or throttle — it SIGKILLs. A more
  graceful path (SIGTERM with a grace period, then SIGKILL) is a
  standing-tier enhancement, not a fix; the rule is "fail loud".
- Does **not** checkpoint, restart, or carry state across runs.
  Each invocation is fresh.
- Does **not** watch for *unrelated* processes. The tree walk is
  anchored to `<command>`; a process the agent does not spawn is
  not measured.

## Provenance

| field | value |
|---|---|
| Author | Orchestrator (MiniMax-M3) |
| Date | 2026-07-29 |
| Reference implementation | Opus 5's EXP-9 build pattern, 2026-07-29 |
| Incident that motivated it | `docs/infra/host/incident-2026-07-29.md` B-2 |
| Test on commit | 100 MB cap kills a 509 MB Python in 0.1 s; `zig build` peaks at ~32 MB |
| Code | `tools/runner` (Python, stdlib only) |
