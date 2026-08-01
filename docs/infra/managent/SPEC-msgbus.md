# SPEC — managent as message bus

**Status:** **BUILT AND IN USE.** The role-addressed read/unread index ships as `managent sync <role>`;
worker control as `managent tell` / `inbox`; heartbeats as `managent ping` / `liveness`; directives live in
the tracked `docs/infra/managent/directives.jsonl`. (The command surface below is the original design; the
shipped surface is the one in `docs/infra/agent-identity-and-worker-channel.md`.)

## Why

Agents cannot see each other. Messages are files; nothing indexes them, nothing
tracks who has read what, and senders choose their own numbers. The observed
consequences: two messages numbered `007`, a dispatch to a brief filename that did
not exist, the human relaying filenames by hand, and an Orchestrator attributing
four of five tree changes to the wrong author because he could only infer
authorship from `git status`.

The bodies stay where they are. What is missing is an index.

## Model

**Messages are files. managent holds the index.** The index is a second queue,
independent of the kanban — the kanban holds *status*, the bus holds
*conversation*. Nothing on the bus has a status beyond read/unread; anything that
needs one is a task, not a message.

## Commands

```
managent post --from <role> --to <role[,role]|all> --subj "<text>" [--re <task-id>] <file>
managent inbox <role>                 # unread addressed to <role> or to all
managent msgs [--re <task-id>]        # the index: id · from · to · subj · when · read-by
managent read <msg-id> --as <role>    # mark read
```

## Record

Stored beside the kanban, in the **tracked** state file:

```json
{ "id": "M017",
  "file": "untracked/msg/milestone-01-ko-reframe/017-dabir-to-orchestrator.md",
  "from": "dabir", "to": ["orchestrator"], "subj": "message-bus spec + attribution correction",
  "re": "MSGBUS", "ts": "2026-07-29T09:12:00Z", "read_by": ["orchestrator"] }
```

## Design decisions, and why

**managent assigns the id.** Senders never choose a number, so the duplicate-`007`
collision cannot recur.

**Unread is per role, not per agent instance.** A new Dabir taking over from the
last inherits the Dabir inbox. This matches how handover already works and means a
message is not lost because its intended reader's session ended.

**Subject lines are the human's view, not decoration.** `managent msgs` is the
answer to *"what are they arguing about?"* without reading any prose. A subject of
"update" wastes the only field the human reads. Require substance.

**`--re <task-id>` links conversation to work,** so the reasoning about a task can
be found from the task. One field, high value.

**The index is tracked; the bodies are not.** When a milestone directory is pruned,
the index survives as permanent minutes — who discussed what, and when — while the
transcript goes. That is exactly the human's standing instruction: keep the
findings, discard the bloody details.

## Task-addressed directives (WORKER-CHANNEL, 2026-07-29)

The msgbus addresses court messages by role.  For one-way control signals
from the court to a worker, the project uses **directives**, which are
addressable by task ID and written to `docs/infra/managent/directives.jsonl`
(a tracked JSONL file beside the kanban).

### Commands

```
managent tell <target> <directive> [--note <text>] [--from <who>]
    directive \in {pause, resume, kill, amend, question}
managent inbox [<target>]
```

`managent tell` appends a directive to `directives.jsonl`.  The runner checks
for directives on every invocation and **exits 124 before launching the command**
when a `pause` or `kill` directive is pending.  `managent claim` prints any
pending directives for the claimed task.  See `docs/infra/dispatch/WORKER-CHANNEL.md`
for the full design.

Directives survive a fresh clone (tracked); heartbeats do not (untracked).

## The honest limitation

**There is no push.** Nothing wakes an agent when mail arrives. The bus works only
if `managent inbox <role>` is the **first action of every session** — so that
belongs in the role files and in `AGENTS.md`, not in the tool. What the tool
provides is that *not having read* becomes visible instead of invisible.

Directives improve on this by hooking into `tools/runner` — a worker cannot
build through the runner without seeing pending pause/kill directives (§2 of
`docs/infra/agent-identity-and-worker-channel.md`).

## Deliberately excluded

Threading, priorities, message types, delivery guarantees, acknowledgement beyond
read, and a separate cc concept (`--to` taking a list covers it). Each would add
surface without addressing the failure. If the bus starts needing features, the
likely cause is status leaking back into messages — fix that instead.

## Acceptance

- Two agents posting concurrently receive distinct ids.
- `inbox` for a role omits what that role has read and includes broadcasts.
- The index round-trips through the tracked state file.
- A message whose body file is missing is reported, not silently skipped — the
  dispatch-to-a-nonexistent-brief failure in a new place.
- `msgs` output is legible to the human without opening a message.
