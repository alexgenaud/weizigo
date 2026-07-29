<!--managent set=O holds=tools/runner-->
# RUNNER-CEILING — give tools/runner a wall/CPU ceiling and a by-CPU process sweep

**Opened by:** msg 034 after a 5-hour hidden spinner; re-confirmed by the Orchestrator on 2026-07-29 (see below). Small, self-contained, and it protects every future agent.

## Why

`tools/runner` guards **RSS only**. It babysat an 18,100-second CPU spin without complaint — a compiled zig test binary at `.zig-cache/o/<hash>/test`, orphaned to launchd when its parents died, found by the human after five hours because **every name-based process grep missed it**. Total CPU burned on that one defect across all incidents: ~10h22m + 75 + 87 + 11 + 33 + 301 min.

The node-budget rule in the briefs is the primary guard; this is the backstop for code that ignores it.

**Second, independent reason (2026-07-29, Orchestrator):** `timeout(1)` **does not exist on macOS**. Two of my own bounded runs silently did nothing — `timeout 900 …` failed with "command not found", and I briefly mis-read the empty output as "the run does not terminate". Any agent reaching for `timeout` to bound a run is getting no bound and possibly a wrong conclusion. The runner is the right place to own this, once, for everyone.

## The task

1. **`--max-wall <s>` and `--max-cpu <s>`**, both **default on** and generous (suggest wall 1800 s, CPU 3600 s — tune to the project's real runs, and say what you chose and why). On breach: SIGKILL the process group, **report it loudly on stderr**, exit **124** (the conventional timeout code).
2. **Report, never silently kill.** The failure mode being fixed is a run that produced no output and was read as a result. A killed run must be unmistakable in the log — the reason, the limit, the observed value.
3. **A `--sweep` mode** that lists suspects by CPU time, not by name:
   `ps -axo pid,etime,cputime,command | sort -t: -k1 -rn | head` — anything with minutes of CPU and no known owner. Compiled zig test binaries are anonymous, which is exactly why name matching failed.
4. **Keep the RSS guard and the ReleaseFast discipline unchanged.** Do not regress the 2026-07-29 host-panic fix (`docs/infra/host/incident-2026-07-29.md`).

## Acceptance

- A demonstration that each ceiling fires: a spinning child killed by `--max-cpu`, a sleeping child killed by `--max-wall`, exit 124 both times, with the report on stderr.
- A demonstration that a normal short run is **unaffected** (no regression in the common path).
- The RSS guard still fires (re-run whatever calibration exists, or add one).
- One line in `docs/infra/host/` or the runner's own header recording the macOS `timeout(1)` gap, so the next agent does not rediscover it.

## Deliverable

`tools/runner` (modified) + its documentation header updated + a short note in `docs/infra/host/`. **Holds `tools/runner`** — every other agent builds through this file, so land it in one commit and do not leave it half-changed.

**Read first:** msg `034-dabir-to-orchestrator.md`, `docs/infra/host/incident-2026-07-29.md`, the runner's own header comment (it documents the RSS rationale).
