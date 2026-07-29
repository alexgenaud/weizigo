Author: Orchestrator (Opus 5, claude-opus-5[1m]) · Date: 2026-07-29
Status: **DESIGN — specified, not built.** Implementation registered as
`AGENT-IDENTITY` then `WORKER-CHANNEL`. Extends
`docs/infra/managent/SPEC-msgbus.md` (role-addressed bus); does not replace it.

# Agent identity, and a channel workers actually read

Two ideas from the human, 2026-07-29. The second makes the first implementable,
so identity is specified first.

---

# Part 1 — Identity: `<model>/<role-or-task>`

## The problem

The project refers to agents by **model name** — "DSPro", "kimi-k2.7", "fable-5" —
as though that were a name. It is not. On 2026-07-29 **five separate DeepSeek-v4-Pro
instances** ran five different tasks; `model-perf.md` can only say so in prose, and
`managent`'s `agent` field held the same string for all five. A model name
identifies a *kind of worker*, never a worker.

## The scheme

| kind | identifier | why it is unique |
|---|---|---|
| **court** | `<model>/<role>` — `Opus/Orcha`, `DSPro/Dabir`, `Kimi/Auditor` | each court role is singleton **by rule** (`ORCHESTRATOR.md`: *exactly one, ever*) |
| **worker** | `<model>/<task-id>` — `DSPro/2B-5`, `Fable/2B-0` | a task has one claimant at a time — `claim` is the only transition to `in_progress`, gated by `needs` and `holds` |

Both are `<model>/<discriminator>`. One shape, two namespaces.

## Edge cases, decided

- **Re-attempts.** Reopen and re-claim by the *same* model repeats an identifier
  (`DSPro/2B-5` twice). Append the attempt when the count exceeds one:
  **`DSPro/2B-5.2`**. `managent` knows the claim count; it should mint this, not
  the agent. (`EXP-2B` was reopened and re-cut, so this is a real case, not a
  hypothetical.)
- **Handover overlap.** Briefly two agents answer to one role. The role transfers
  **atomically at the outgoing agent's stand-down message**; before it, the
  successor is `Opus/Orcha-elect` and holds nothing. This matches the existing
  rule that succession is not overlap.
- **Undeclared model.** `unknown/<task-id>`, and `managent done` refuses it
  (already `ORCHA-AUTOMATION` §3). `ADR0006-FALSIFY` shipped with
  `Model: not stated at dispatch`, which is exactly this hole.
- **Sub-delegation.** A worker that spawns a helper: `<model>/<task-id>+<n>`. Rare;
  define it now so it is not improvised later.

## Nothing new in the kanban

`managent` already stores `agent` (the model) per task, and the task id is the key.
**The identifier is therefore derivable, not a new field** — `agent + task-id`
composes it. Keep it derived; a stored duplicate would drift.

## Where identity must appear

- **Every artefact an agent produces**, at first use, in full. `AGENTS.md` already
  requires the model in every file; it should require the **identifier**.
- **Channel messages** — as `from` / `to`, replacing bare role names for workers.
- **Commit trailers**, where a worker commits its own deliverables.

## Abbreviation

Shorthand is allowed and expected, because context usually resolves it: `2B-5`
inside its own deliverable, `Orcha` in the channel, `DSPro` when only one is in
play. **The rule is the project's existing one — expand in full at first use, then
abbreviate.** An identifier that never appears in full is not an identifier.

---

# Part 2 — A channel workers actually read

## What went wrong today, concretely

| event | what it cost |
|---|---|
| `2B-6` needed pausing | the human paused it by hand |
| an `EXP-2B` console span 5 h of CPU | found by the human, not by the system |
| `2B-PROBE-FIX` needed a mid-flight addendum | written to its brief; relayed by the human |
| `2B-3-AUDIT`, `EVIDENCE-INTEGRITY` completed without ever being claimed | nobody knew they were running |
| `AUDIT-REF-DSPro`'s console closed | left its deliverable untracked |

Three distinct needs: **liveness** (is it alive, what is it doing), **inbound
control** (pause, redirect, correct), **outbound status** (progress, blockers).

## The honest constraint, stated first

**There is no push.** `SPEC-msgbus.md` says so and it is still true: a worker
mid-tool-call cannot be interrupted by a file appearing. Directive latency is
bounded by how often the worker looks. Any design promising instant pause is lying.

## The design insight: hook the check to what a worker cannot avoid

Do not build a channel workers must *remember* to read. Attach the read to the
tools they must already use. The project has exactly two mandatory choke points:

1. **`tools/runner`** — every ad-hoc build and run goes through it (project rule,
   enforced after the 2026-07-29 host panic).
2. **`managent claim` / `done`** — the only status transitions.

So:

- **`managent claim` prints the inbox** — the start-of-work read, unavoidable.
- **`tools/runner` emits a heartbeat and prints pending directives on every
  invocation**, and **exits non-zero when a `pause` or `kill` directive is
  pending**, so a worker cannot build on obliviously. A directive therefore takes
  effect at the worker's *next build* — typically seconds to minutes, which is the
  real bound and is good enough for every case in the table above.
- **`managent ping [--note <text>]`** for an explicit heartbeat between builds, so
  a thinking worker can prove liveness.

This converts politeness into enforcement. A worker that ignores the channel
cannot compile.

## Commands (extending the msgbus)

```
managent tell <agent-id|task-id> <directive> [--note <text>]   # court -> worker
                     directive ∈ pause | resume | kill | amend | question
managent inbox [<agent-id>]        # defaults to the caller's identity
managent ping [--note <text>]      # heartbeat + optional progress line
managent liveness                  # last heartbeat per in_progress task, with age
```

`tell` reuses the bus; the only extension to `SPEC-msgbus.md` is that **`--to`
accepts a task id**, so `inbox` is addressable per worker as well as per role. The
existing decision — *unread is per role, not per instance* — stays correct for the
court and extends naturally: unread is **per task** for workers, so a reopened
task's new claimant inherits the unread directives, which is what you want.

## Storage: split by durability, deliberately

- **Directives are decisions** → the **tracked** store beside the kanban, with the
  message index. Few, small, durable, auditable. "Who paused 2B-6 and why" must
  survive a clone.
- **Heartbeats are telemetry** → **`untracked/heartbeat.jsonl`**, append-only,
  discarded on completion. Chatty by nature; `untracked/` is the correct home, and
  this is the one case where the project's *evidence-in-git* rule does not apply,
  because a heartbeat is not evidence of anything.

This split matters: putting heartbeats in `tasks.json` would make the kanban churn
on every build, against the standing rule that `tasks.json` rides with a docs wave.

## The free win: the statistics gap closes itself

`tools/runner` already measures wall-clock and peak RSS per invocation, and
`RUNNER-CEILING` adds CPU. If the heartbeat records them per `(identifier, task)`,
then **wall-clock and CPU per task accumulate as a by-product** — the exact figures
`model-perf.md` has never had for any seat, tracked by nobody, and which the human
has asked about twice. No new instrumentation; only writing down what the guard
already measures.

Cost per task remains un-measurable agent-side (billing is not visible to the
agent) and stays a human-entered field.

## What `liveness` gives the Orchestrator

Cadence step 2 currently means comparing the kanban against `ps` by hand — which is
how the 5-hour spinner was missed for five hours, because compiled zig test
binaries are anonymous. `managent liveness` replaces that with a table, and
`managent audit` gains a real rule: **an `in_progress` task whose last heartbeat is
older than a threshold is a `reopen` candidate.** That is the single reconciliation
the Orchestrator performs most often and the one most often performed wrongly.

---

# Sequencing

`AGENT-IDENTITY` first — it is mostly convention plus a derived accessor, it blocks
nothing, and Part 2 addresses messages *to identities*, so it wants the identifiers
to exist. Then `WORKER-CHANNEL`.

Both touch contended files: `src/managent/main.zig` is held by
`MANAGENT-DERIVE-STATUS` and `ORCHA-AUTOMATION`; `tools/runner` by
`RUNNER-CEILING`. Sequence behind them via `needs` — and note that
`WORKER-CHANNEL`'s runner hook and `RUNNER-CEILING`'s CPU ceiling are the same
edit to the same function, so they should land in that order rather than race.
