# managent — consensus surface (proposals, human-actions, roadmap) — 2026-07-28

**Status:** design of record for the *new-feature* delivery. The two *defect
fixes* (state file moves to a tracked path; the `context` field is dropped
end-to-end) ship in a separate commit immediately before this one; see the
prior commit's message for their rationale and acceptance.

**Author:** Orcha (MiniMax-M3), Orchestrator. **Reviewers:** Opus, Dabir.
**Implementation:** this commit's source diff.

**What this delivers, in one line.** Three new commands
(`propose` / `agree` / `amend` / `apply`, `human-actions`, `roadmap`) and
an explicit `owner` field on every task, so that the state and the human's
obligations become command output rather than prose the human assembles
from a free-form msg channel.

---

## 1. Why

Two managers writing without reading is how the human ends up relaying
messages between agents (Dabir 011). The project needs a single
consensus + human-action surface. The first cut (this commit) is the
mechanism: a proposals log, ownership tracking, and three readable
commands. The discipline that uses it is the Orchestrator's standing
behaviour after this commit lands.

## 2. The schema change

`tasks.json` gains one field per task:

```
"owner": "agent" | "human" | "orchestrator" | "muhtasib" | "dabir"
```

Default for existing tasks: `agent` (read on next load; written on next
save). The field is informational for now; the binary does not refuse
state transitions based on owner. The human-actions view uses it.

A new file `docs/infra/managent/proposals.jsonl` (tracked, append-only,
one JSON object per line) carries the proposals log. Schema:

```
{
  "id": "P-2026-07-28-001",          // monotonic; matches at-least-once
  "proposed_by": "orcha",            // agent name
  "proposed_at": "2026-07-28T...",   // ISO-8601
  "action": "add" | "claim" | "done" | "amend" | "set-status" | "register-bundle",
  "target": "EXP-9",                 // task id (or other target)
  "args": { ... },                   // action-specific
  "status": "proposed" | "agreed" | "amended" | "applied" | "rejected",
  "agreed_by": null | "opus",
  "agreed_at": null | "2026-07-28T...",
  "amend_note": null | "..."
}
```

## 3. The new commands

**`managent propose <action> <target> [--args k=v,k=v] [--by <who>]`** —
append a proposal to `proposals.jsonl`. No state change.

**`managent agree <proposal-id> [--by <who>]`** — flip a proposal's
`status` to `agreed` (or `amended` with `--note`). The proposer may not
agree their own proposal; this is the "two-man rule" that prevents a
single manager from self-confirming. The constraint is enforced by
record (the binary refuses if `agreed_by == proposed_by`).

**`managent apply <proposal-id>`** — apply an agreed proposal to
`tasks.json`. The proposer or the human may apply. The binary refuses if
the proposal is not `agreed` (or `amended`).

**`managent human-actions`** — list every task where `owner == "human"`
and `status == "dispatchable"`. Header explains what the human is
expected to do. This is the user's "what MUST or CAN I do right now" as
a command.

**`managent roadmap`** — print the dependency graph as a tree, rooted at
items with no `needs`. Each node is the task ID; status and set are
appended. The first heading of the bundle (or "—") is the short label.
This is the user's "what is the agreed roadmap" as a command.

## 4. What the Orchestrator's standing behaviour is, after this lands

- Every state change goes through `propose` → `agree` (or `amend`) →
  `apply`. No direct edits to `tasks.json` by the Orchestrator. The
  proposals log is the audit trail.
- The Orchestrator reads `human-actions` at the start of every
  substantive response to the user, and surfaces the items in the
  reply (or in the channel if the reply is reasoning).
- The Orchestrator reads `roadmap` whenever a task transitions to
  `done` (so the user can see what unblocks).
- The msg channel (`untracked/msg/<milestone>/`) is for *reasoning and
  arguments only*; never for status. Status is the `managent` output.

## 5. The acceptance test

After this commit, the following must hold (run by the Orchestrator,
recorded in the channel):

1. `managent propose add EXP-99 --by orcha` writes P-…-001 to
   `proposals.jsonl`. Status `proposed`.
2. `managent agree P-…-001 --by opus` flips status to `agreed`.
3. `managent apply P-…-001` updates `tasks.json` (EXP-99 added) and
   flips status to `applied`. The state is the agreed plan, recorded
   in three steps.
4. The two-man rule: agreeing one's own proposal is refused
   (`managent agree P-…-001 --by orcha` is rejected when `orcha` is
   the proposer).
5. `managent human-actions` lists zero items initially; after the
   test, the test task with `owner=human` appears.
6. `managent roadmap` prints a tree that matches the dependency graph
   in the dispatch briefs.
7. No engine file touched. The four engine files are not in this
   commit's diff.

## 6. What this design does NOT do

- It does not invent a UI. The surface is plain-text CLI.
- It does not enforce capability or context gating. The metadata is
  informational.
- It does not retroactively re-propose the existing 14 tasks. They
  are already in `tasks.json`; the proposals flow applies to
  *future* changes. Migrating the existing tasks is a follow-up.
- It does not change `holds` semantics. MUTATION still serialises
  per-file. ANALYSIS still parallelises without limit.

## 7. Promotion

- This design doc is the design of record for this commit.
- The implementation is this commit's source diff.
- The spec is updated in the same commit
  (`docs/infra/managent/spec.md`).
- The dispatch README is updated in the same commit
  (`docs/infra/dispatch/README.md`).
- Opus and Dabir review through the channel. A review that amends
  the spec or the code is a follow-up commit with the review's
  verdict in the message.
