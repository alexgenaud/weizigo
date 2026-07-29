<!--managent set=Y holds=src/managent/main.zig needs=ORCHA-AUTOMATION-->
# AGENT-IDENTITY — give every agent a unique identifier: `<model>/<role-or-task>`

**Design:** `docs/infra/agent-identity-and-worker-channel.md` Part 1 — read it first; it decides the edge cases and this brief does not repeat them.

## Why

The project names agents by **model**, which is a kind of worker and not a worker. On 2026-07-29 five separate DeepSeek-v4-Pro instances ran five tasks; `managent`'s `agent` field held the same string for all five, and `model-perf.md` can only distinguish them in prose. Attribution, the message bus, and any directive addressed to a worker all need a real identifier.

## The scheme

- **court:** `<role>` — `Orchestrator`, `Dabir`, `Auditor` (each role is singleton by rule)
- **worker:** `<task-id>` — `2B-5` (a task has one claimant at a time)
- re-attempt after reopen: **`2B-5.2`** — minted by `managent` from the claim count, never by the agent
- undeclared model: `unknown/<task-id>`, and `done` refuses it
- sub-delegation: `<model>/<task-id>+<n>`

**The identifier is derived, not stored** — `agent` + task id already compose it. Do not add a field; a stored duplicate drifts.

## The task

1. **A derived accessor** in `src/managent/main.zig` — one function returning the identifier for a task, with the `.2` attempt suffix when the claim count exceeds one. Use it in `status`, `show`, and every message the tool prints.
2. **`managent whoami <task-id>`** (or equivalent) so an agent can resolve its own identifier rather than guess it.
3. **Print identifiers, not models,** wherever the tool names an agent today.
4. **Check `AGENTS.md`** — it was updated by `ROLE-NAMES` to the role/task-id convention. If anything remains that asks for the model in the identifier, amend it rather than adding a second rule beside it.
5. **Backfill `model-perf.md`'s 2026-07-29 rows** with task identifiers: `2B-3-AUDIT`, `2B-PROBE-FIX`, `2B-6`, `EVIDENCE-INTEGRITY`, `ADR0006-FALSIFY`. The model is already recorded in the `agent` field; the identifier carries the task, not the model (per `ROLE-NAMES`).

## Part 3 — opaque task IDs for new tasks

Design: `docs/infra/agent-identity-and-worker-channel.md` Part 3.

6. **`managent add` mints an opaque monotonic ID** — `T099` — and derives the brief filename `T<n>-<slug>.md` from the title, so ID and slug cannot drift. The slug is **display only**: never a lookup key, never in a `needs` edge.
7. **Alias, do not rename.** Existing IDs are cited across ~60 documents, commit messages and evidence directory names; renaming breaks committed history. Keep them, add an alias table, and resolve both forms.
8. **One namespace letter (`T`), not a class prefix** — a class prefix re-encodes semantics into the ID, which is what opaque IDs are for, and `managent` already uses A–Z for sets.

## Acceptance

- Every place the tool named a model now names an identifier.
- `.2` suffix demonstrated on a reopened-and-re-claimed task.
- `unknown/` demonstrated, and `done` refusing it.
- One sentence in `AGENTS.md`, replacing rather than duplicating the model rule.
- **Rebuild discipline:** `cp zig-out/bin/managent bin/managent`, or the binary is stale.

## Deliverable

`src/managent/main.zig`, `bin/managent` refreshed, `AGENTS.md` amended, `model-perf.md` backfilled, `docs/infra/managent/spec.md` updated. **Holds `src/managent/main.zig`**; `needs ORCHA-AUTOMATION` so the three managent tasks land in sequence rather than racing the same file.
