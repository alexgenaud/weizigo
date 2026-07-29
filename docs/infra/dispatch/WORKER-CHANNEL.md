<!--managent set=Z holds=tools/runner needs=AGENT-IDENTITY,RUNNER-CEILING-->
# WORKER-CHANNEL — a channel workers cannot ignore: directives at the choke points, plus heartbeats

**Design:** `docs/infra/agent-identity-and-worker-channel.md` Part 2 — read it first. It states the constraint that shapes everything here and this brief does not re-argue it.

## The constraint, first

**There is no push.** A worker mid-tool-call cannot be interrupted by a file appearing. Directive latency is bounded by how often the worker looks, and any design promising instant pause is lying. Do not build one.

## The insight to implement

Do not build a channel workers must *remember* to read. Attach the read to the tools they cannot avoid — the project has two mandatory choke points: **`tools/runner`** (every ad-hoc build and run) and **`managent claim` / `done`** (the only status transitions).

1. **`managent claim` prints the inbox** — the unavoidable start-of-work read.
2. **`tools/runner` emits a heartbeat and prints pending directives on every invocation**, and **exits non-zero when a `pause` or `kill` directive is pending.** A directive then takes effect at the worker's next build — seconds to minutes, which is the real bound and sufficient for every case that arose on 2026-07-29.
3. **`managent ping [--note <text>]`** so a thinking worker can prove liveness between builds.

This converts politeness into enforcement: a worker ignoring the channel cannot compile.

## Commands

```
managent tell <agent-id|task-id> <directive> [--note <text>]   # court -> worker
                     directive ∈ pause | resume | kill | amend | question
managent inbox [<agent-id>]        # defaults to the caller's identity
managent ping [--note <text>]      # heartbeat + optional progress line
managent liveness                  # last heartbeat per in_progress task, with age
```

Extend `SPEC-msgbus.md` minimally: **`--to` accepts a task id**, so an inbox is addressable per worker as well as per role. Keep its decision that unread is per *role* for the court; make it per *task* for workers, so a reopened task's new claimant inherits unread directives.

## Storage — split by durability

- **Directives → the tracked store** beside the kanban, with the message index. Few, small, auditable: *who paused 2B-6 and why* must survive a clone.
- **Heartbeats → `untracked/heartbeat.jsonl`**, append-only, discarded on completion. Telemetry, not evidence — the one case where evidence-in-git does not apply. Putting them in `tasks.json` would churn the kanban on every build, against the rule that it rides with a docs wave.

## Record the measurements the guard already takes

`tools/runner` measures wall-clock and peak RSS; `RUNNER-CEILING` adds CPU. **Record them in the heartbeat per `(identifier, task)`.** Wall-clock and CPU per task then accumulate as a by-product — figures `model-perf.md` has never had for any seat and the human has asked after twice. No new instrumentation; write down what is already measured. Cost stays a human-entered field (billing is not agent-visible).

## Then make the Orchestrator's hardest step mechanical

`managent liveness` replaces comparing the kanban against `ps` by hand — which is how a 5-hour CPU spinner went unnoticed, since compiled zig test binaries are anonymous and every name-based grep missed it. Add to `managent audit`: **an `in_progress` task whose last heartbeat exceeds a threshold is a `reopen` candidate.** That is the reconciliation the Orchestrator performs most often and most often gets wrong.

## Acceptance

- A `pause` posted by the court **stops the next `tools/runner` invocation** with a non-zero exit and a legible reason. Demonstrate it.
- `claim` prints a waiting directive.
- `liveness` shows ages; `audit` flags a stale `in_progress` task.
- A heartbeat carries identifier, task, timestamp, command, wall, CPU, peak RSS.
- **The RSS guard and the CPU/wall ceilings still fire** — do not regress `RUNNER-CEILING` or the host-panic fix. Re-run their calibrations.
- **Latency is stated, not implied:** say in the docs that a directive lands at the next build or ping, and give the measured typical delay.

## Deliverable

`tools/runner`, `src/managent/main.zig`, `bin/managent` refreshed, `SPEC-msgbus.md` and `docs/infra/runner.md` updated. **Holds `tools/runner`**; `needs AGENT-IDENTITY` (directives are addressed to identifiers) **and `RUNNER-CEILING`** — that task and this one edit the same function of the same file, so they land in order rather than racing.
