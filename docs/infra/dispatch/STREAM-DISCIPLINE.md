<!--managent set=D-->
# STREAM-DISCIPLINE — data on stdout, diagnostics on stderr, across every Zig binary

**Opened by:** the human, 2026-07-29, unable to `grep` `bin/managent` output from the command line. The cause turned out to be project-wide.

## The measurement

**764 `std.debug.print` calls across ~30 Zig files.** In Zig that writes to **stderr, unconditionally**. Exactly **one** file in the project writes to real stdout:

```
src/gtp.zig    std.Io.File.stdout()  (:691, :1056)   ← and it is correct
```

`gtp.zig` is the model to copy: **GTP protocol responses on stdout** (they must be — every GTP client, Sabaki included, reads the engine's stdout) and **diagnostics via `std.debug.print` on stderr**. That separation is exactly right and must not be disturbed.

Everywhere else, the tool's *data* goes to stderr:

| file | `debug.print` | what its data is |
|---|---|---|
| `qa023_probe.zig` | 152 | probe results — **committed as `*.stdout` evidence** |
| `managent/main.zig` | 132 | the kanban — **the human wants this greppable** |
| `claimlint.zig` | 128 | the claim-graph verdict — the pre-commit gate |
| `qa023_pinrule.zig` | 81 | census + group tables |
| `retro.zig` | 50 | engine progress + battery results |
| ~25 others | 1–30 each | censuses, harnesses, checks |

## Why this is a defect and not a preference

1. **Piping silently fails.** `managent status \| grep FOO` prints unfiltered text to the terminal **and** returns no matches — indistinguishable from "no such task". The human hit exactly this. It has presumably been defeating every agent that tried to filter output, unnoticed because habitual `2>&1` masks it.
2. **It blocks the automation already registered.** `ORCHA-AUTOMATION` item 0 covers `managent`; `audit`/`sync`/`liveness` are only useful if a script can read them, and `managent audit \| grep -q REJECTED` silently succeeds today.
3. **The evidence convention is built on it.** Deliverables cite `*.stdout` files that were captured with `2>&1`, so committed "stdout evidence" is stderr with diagnostics interleaved — which is why `[runner]` lines appear inside evidence files. Data and chatter in one stream cannot be separated after the fact.
4. **`claimlint` is a gate.** A gate whose output cannot be parsed is a gate that must be read by eye.

## The task

**The rule: stdout carries what a caller would parse, filter, redirect, or commit as evidence. stderr carries everything else — progress, warnings, errors, rejections, heartbeats.**

1. **Add a tiny output helper** (one place, e.g. `src/util.zig`) — `out(...)` → stdout, `note(...)`/`warn(...)` → stderr — so the choice is explicit at every call site and greppable in review. Do not leave 764 bare `std.debug.print` calls and a convention nobody can check.
2. **Convert per binary, in this priority order**, because the value is very unevenly distributed:
   - **`managent/main.zig`** — the human's explicit request. Coordinate with `ORCHA-AUTOMATION` item 0, which holds this file: **that task owns the managent conversion; do not both edit it.** Take it only if that task has landed.
   - **`claimlint.zig`** — it is a gate; its verdict must be machine-readable.
   - **`qa023_probe.zig`, `qa023_pinrule.zig`** and the census tools — their output becomes committed evidence.
   - The rest, as reached.
3. **Leave `gtp.zig` alone** except to confirm it. Verify the protocol still goes to stdout and diagnostics to stderr, and record that it was the reference.
4. **`retro.zig` and the engine files** — one writer per engine file is a standing rule. If a conversion touches `src/retro.zig`, `oracle.zig`, `rules.zig` or `solve.zig`, declare it and do those in a separate commit, or defer them and say so.
5. **A regression check per converted binary**: `<tool> 2>/dev/null` must still emit the data, and `<tool> 1>/dev/null` must emit only diagnostics. **One line each, and its absence is the root cause of this defect** — nothing anywhere asserted which stream the data was on.
6. **`--json` where it is nearly free** — `managent status`, `claimlint`, the censuses. Deterministic machine output is what makes the rest of the tooling composable. Optional; say what you skipped.

## Acceptance

- The helper exists and is used; no new bare `std.debug.print` for data.
- Priority binaries converted, with the regression check for each.
- `gtp.zig` confirmed unchanged in behaviour.
- A one-line note in `AGENTS.md` §"Build / test / run" stating the convention, so the next tool is written correctly rather than converted later.
- **State what you did not convert and why.** A partial pass honestly reported is worth more than a claimed-complete one — a banner reported as placed but never written happened on this project today.

## Deliverable

The converted sources, the helper, the regression checks, the `AGENTS.md` line. **Holds nothing exclusively** — but it touches many files, so land it in per-binary commits and check `bin/managent status` for concurrent holders before starting each. `cp zig-out/bin/managent bin/managent` after any managent rebuild.

**Read first:** `src/gtp.zig:691,1056` (the reference pattern), `docs/infra/dispatch/ORCHA-AUTOMATION.md` item 0, `docs/infra/runner.md`.
