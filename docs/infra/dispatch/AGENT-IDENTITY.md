<!--managent set=Y holds=src/managent/main.zig needs=ORCHA-AUTOMATION-->
# AGENT-IDENTITY — give every agent a unique identifier: `<model>/<role-or-task>`

**Design:** `docs/infra/agent-identity-and-worker-channel.md` Part 1 — read it first; it decides the edge cases and this brief does not repeat them.

## Why

The project names agents by **model**, which is a kind of worker and not a worker. On 2026-07-29 five separate DeepSeek-v4-Pro instances ran five tasks; `managent`'s `agent` field held the same string for all five, and `model-perf.md` can only distinguish them in prose. Attribution, the message bus, and any directive addressed to a worker all need a real identifier.

## The scheme

- **court:** `<model>/<role>` — `Opus/Orcha`, `DSPro/Dabir` (each role is singleton by rule)
- **worker:** `<model>/<task-id>` — `DSPro/2B-5` (a task has one claimant at a time)
- re-attempt after reopen: **`DSPro/2B-5.2`** — minted by `managent` from the claim count, never by the agent
- undeclared model: `unknown/<task-id>`, and `done` refuses it
- sub-delegation: `<model>/<task-id>+<n>`

**The identifier is derived, not stored** — `agent` + task id already compose it. Do not add a field; a stored duplicate drifts.

## The task

1. **A derived accessor** in `src/managent/main.zig` — one function returning the identifier for a task, with the `.2` attempt suffix when the claim count exceeds one. Use it in `status`, `show`, and every message the tool prints.
2. **`managent whoami <task-id>`** (or equivalent) so an agent can resolve its own identifier rather than guess it.
3. **Print identifiers, not models,** wherever the tool names an agent today.
4. **Update the convention in `AGENTS.md`:** an agent writes its **identifier** into every artefact it produces, in full at first use, abbreviated thereafter — the project's existing expand-at-first-use rule. Amend the current wording (which asks only for the model) rather than adding a second rule beside it.
5. **Backfill `model-perf.md`'s 2026-07-29 rows** with identifiers now that they can be stated: `DSPro/2B-3-AUDIT`, `DSPro/2B-PROBE-FIX`, `DSPro/2B-6`, `DSPro/EVIDENCE-INTEGRITY`, `DSPro/ADR0006-FALSIFY`.

## Acceptance

- Every place the tool named a model now names an identifier.
- `.2` suffix demonstrated on a reopened-and-re-claimed task.
- `unknown/` demonstrated, and `done` refusing it.
- One sentence in `AGENTS.md`, replacing rather than duplicating the model rule.
- **Rebuild discipline:** `cp zig-out/bin/managent bin/managent`, or the binary is stale.

## Deliverable

`src/managent/main.zig`, `bin/managent` refreshed, `AGENTS.md` amended, `model-perf.md` backfilled, `docs/infra/managent/spec.md` updated. **Holds `src/managent/main.zig`**; `needs ORCHA-AUTOMATION` so the three managent tasks land in sequence rather than racing the same file.
