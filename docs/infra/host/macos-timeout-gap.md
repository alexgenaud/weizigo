# macOS `timeout(1)` gap

**Date:** 2026-07-29 (discovered).  **Author:** RUNNER-CEILING (DSFlash).

## The gap

macOS does not ship a `timeout(1)` utility.  The command is part of
GNU coreutils and is available via Homebrew (`brew install coreutils`
→ `gtimeout`), but it is **not** present on a stock macOS install.

Any agent reaching for `timeout 900 …` to bound a run silently gets
"command not found" and **no bound at all**.  Two bounded runs in the
EXP-9 session did exactly that — `timeout 900 …` failed with ENOENT
and the caller mis-read the empty output as "the run does not terminate".

## Project fix

`tools/runner` now owns the wall-time and CPU-time ceiling for the
entire project, via `--max-wall <s>` and `--max-cpu <s>` (both
default-on at 1800 s / 3600 s).  No agent should call `timeout`
directly.  Every zig/agent build that needs a time bound should use:

```
tools/runner -- <command> [args...]
```

The runner uses only stdlib Python and `/bin/ps` — no external
dependencies, no Homebrew requirement.

## Cross-reference

- `tools/runner` (the source, header comment §"macOS timeout(1) gap")
- `docs/infra/dispatch/RUNNER-CEILING.md` (the brief that added this feature)
- `docs/infra/host/incident-2026-07-29.md` (the host panic that motivated the runner)
