# ROLES — who is who, and how many can run at once

Read this if you are dispatching, or unsure what you are. Companions:
`DELEGATOR.md` (writing a task), `DELEGATEE.md` (executing one).

## Specification restraint

Specify only what changes the outcome, and say why. Default to specifying
nothing — including about models.

A per-task model requirement with a stated reason is legitimate: *the strongest
reasoning available, because the roadmap gates on this proof*, or *not whichever
model wrote the roadmap*, for independence. The test is whether the task would
fail or come back materially worse otherwise. Over-specification is the fault,
not model-naming.

Two things belong to the human, who alone knows what is available, what it costs
and what is already loaded: **standing assignments** — a model bound to a role or
a class of work — and **the final pick** when a brief states a preference rather
than a requirement.

Where such a recommendation is usually justified: grand overview, massive
refactorization, long-term thinking, and extremely complex cutting-edge
algorithms. Two suggestions for those cases. Prefer a strong model write the
specification, audit or review rather than do the work — a specification gets
argued with, whereas finished work from the strongest model in the room tends to
be ratified. And treat its exploratory code as scaffolding: if it proves
permanent, specify it and let someone else implement.

Capabilities worth stating, when any are (most tasks need none):
`reasoning: sustained` · `independence: has-not-read <X>` · `session: persistent`
· `isolation: exclusive <paths>` · `sub-delegation: yes/no`.

Context-window size is not among them. A task that only a huge window can hold is
a badly scoped brief; the fix is a smaller brief.

## Roles, not models

A model name is not an identity — it is an implementation detail that happens,
today, to map onto a role. The mapping will change; the role will not.

**Thinking managers** are persistent, invoked by role, and described one file
each in `docs/infra/roles/`:

| role | for | file |
|---|---|---|
| **Dabir** | counsel to the human: holds his intent and the agreed overview | `roles/DABIR.md` |
| **Muhtasib** | the grand auditor: verifies, rules, says when work should stop | `roles/MUHTASIB.md` |
| **Orchestrator** | the queue and the stores. **Exactly one, ever** | `roles/ORCHESTRATOR.md` |

The boundary that matters: the auditor never owns the queue, and the counsel never
executes. Both collapses have already cost this project time.

**Workers** are identified by task — `EXP-4`, `B99`, `AUDIT-12`. Two workers on
one model are not one agent, and a worker's model may change between attempts at
the same task, so a model name cannot identify one.

## Model recording

Every agent knows its role, its task ID and its model, and writes the model into
each file it produces. Unknown is recorded as `not stated at dispatch`; a guess
corrupts the ledger that attribution depends on.

The launch prompt carries the identity:

```
You are <model> <task-id>: follow <brief path>
```

## Concurrency

Two task kinds, and the distinction is what makes unlimited parallelism safe.

**ANALYSIS** writes exactly one new file and modifies nothing shared — audits,
specifications, censuses, measurements, reviews. Nothing can collide, so any
number may run at once, each declaring only its output path.

**MUTATION** may modify existing files. One at a time, drawn from a backlog,
citing the analysis that recommended it so the change is auditable rather than
improvised, and declaring exclusive paths in `docs/status/CURRENT.md`.

Analysis parallelises for free; mutation does not.

**Throughput** is therefore set by the mutation queue, not the agent count. Many
analysis agents can feed one serial queue. If the queue is the bottleneck, batch
related recommendations into a single mutation — do not parallelise the queue.

**Every task is registered in `bin/managent`**, and the human dispatches only from
its dispatchable set. The board already expresses both kinds, verified against
`src/managent/main.zig`:

- `holds=<paths>` is the concurrency gate — two in-progress tasks conflict only
  when they hold a file in common. A task with no `holds` never conflicts, so
  **analysis parallelises without limit**, and mutation serialises per-file
  automatically.
- `set=A|B|C` are sequential **phases**, not parallel lanes: a set is gated until
  every task in every prior set is done. Use one set unless a genuine phase
  boundary exists, and express real dependencies with `needs=`.

So the practical limit on analysis is consoles and cost, not the board.
