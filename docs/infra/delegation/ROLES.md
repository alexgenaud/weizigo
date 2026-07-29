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
| **Auditor** | verifies, rules, says when work should stop. Many, each given a scope | `roles/AUDITOR.md` |
| **Orchestrator** | the queue and the stores. **Exactly one, ever** | `roles/ORCHESTRATOR.md` |

The boundary that matters: the auditor never owns the queue, and the counsel never
executes. Both collapses have already cost this project time.

**Workers** execute tasks; their role file is `delegation/DELEGATEE.md`. Identified by task — `EXP-4`, `B99`, `AUDIT-12`. Two workers on
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

## Dispatching, claiming, and the board

The Orchestrator owns the board end-to-end: it records dispatches on the
human's behalf, records claims when a worker has started but not claimed, and
marks `done` when a worker has finished but not updated the board.
**The board is the bug when it disagrees with reality.** (The prior
"Orchestrator does not claim on the agent's behalf" rule was rescinded
2026-07-29 by D-8.)

```
human/orchestrator  →  managent dispatch <id> --to <agent> [--note <text>]  # queueing
worker/orchestrator →  managent claim <id> --agent <name>                   # start
worker              →  managent done <id>                                   # completion
```

`dispatched_to` records *who the human wanted*; `agent` records *who did the
work*. They may differ — dispatched to X, done by Y when X was busy, failed, or
not available; any agent can claim any `dispatchable` task. **When the
Orchestrator claims on a worker's behalf, it uses the worker's name in
`--agent`, never its own** — the `agent` field feeds the performance ledger and
must attribute the work to the worker.

The normal path is worker self-claim (`managent claim` / `managent next`); a
dispatched task sitting unclaimed is a hygiene gap the Orchestrator resolves
(nudge the worker, or record the claim), not a boundary to preserve. The
Orchestrator's standing job is to keep the `dispatchable` set non-empty and
honest: **empty dispatchable is a bug** (the human has nothing to dispatch
to), and a `dispatchable` task with no in-flight work is standing-tier feed.
The command details are in `docs/infra/managent/spec.md`.

## Instance vs model (review independence)

**Instances are not models.** Fresh instances of the same model are freely
available; a fresh instance holds no memory of, and no attachment to, another
instance's work. So **self-review bars are instance-level by nature** — a fresh
worker console of a model is not the same agent as that model's
Orchestrator/Auditor instance, and the panel used this reading (seat A: a fresh
GLM worker console while the GLM Orchestrator instance was barred).

**But a same-model fresh instance does NOT remove correlated error**: shared
training -> shared blind spots -> the same wrong step looks plausible twice.
So the independence a fresh instance buys is **procedural, not epistemic**:

- **Same-model fresh-instance review is acceptable** for procedural / compliance
  / calibration checks (did the worker follow the brief, cite real paths, run
  the calibration).
- **For adversarial review of load-bearing reasoning, prefer a different
  model.** That is what the three-seat blind panel bought (GLM / DeepSeek-Pro /
  Kimi-k2.7 on the QA-018 review) — independent training, not just independent
  instances.
- **If only the same model is available, disclose it.** A same-model review of
  load-bearing reasoning must say so loudly; its verdict is procedural
  confirmation, not independent adjudication.

**Standing wording (when a consensus surface is needed):** *Bar the instance
always; prefer a different model where the object under review is load-bearing
reasoning; disclose same-model review when unavoidable.* (User clarification,
2026-07-29, Dabir msg 031.)
