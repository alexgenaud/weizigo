# ROLES — who is who, and how many can run at once

Companions: `DELEGATOR.md` (writing a task), `DELEGATEE.md` (executing one).

## Specification restraint

Specify only what changes the outcome, and say why — including about models.
Default to specifying nothing. A per-task requirement is legitimate only if
the task would fail or come back materially worse without it (e.g. strongest
reasoning available because the roadmap gates on this proof; independence
from whichever model wrote the roadmap) — over-specification is the fault,
not model-naming. **Standing assignments** (a model bound to a role or class
of work) and **the final pick** (when a brief states a preference, not a
requirement) belong to the human alone, who alone knows what is available,
what it costs, and what is already loaded.

Capabilities worth stating, when any are (most tasks need none): `reasoning:
sustained` · `independence: has-not-read <X>` · `session: persistent` ·
`isolation: exclusive <paths>` · `sub-delegation: yes/no`. Context-window
size is not among them — a task only a huge window can hold is a badly
scoped brief.

## Roles, not models

A model name is not an identity — an implementation detail that happens to
map onto a role today. The mapping changes; the role does not. Thinking
managers (Dabir, Auditor, Orchestrator) are persistent, invoked by role, one
file each in `docs/infra/roles/`; the auditor never owns the queue and the
counsel never executes. Workers execute tasks, identified by task (`EXP-4`,
`AUDIT-12`) never by model — role file `delegation/DELEGATEE.md`.

## Model recording

Every agent knows its role, its task ID and its model, and writes the model
into each file it produces. Unknown is `not stated at dispatch`; a guess
corrupts the ledger attribution depends on. The launch prompt carries the
identity: `You are <model> <task-id>: follow <brief path>`.

## Concurrency — the authority for this project

Two task kinds, and the distinction is what makes unlimited parallelism
safe. **ANALYSIS** writes exactly one new file and modifies nothing shared —
audits, specs, censuses, measurements, reviews. Nothing can collide, so any
number may run at once, each declaring only its output path. **MUTATION** may
modify existing files, one at a time, drawn from a backlog, citing the
analysis that recommended it, declaring exclusive paths via the kanban
`holds=` field (`managent show <id>` displays them; `bin/managent resume`
lists every held path).

Analysis parallelises for free; mutation does not. **Throughput is set by the
mutation queue, not the agent count** — if the queue is the bottleneck, batch
recommendations into a single mutation rather than parallelising the queue.
Verified against `src/managent/main.zig`: `holds=<paths>` is the concurrency
gate (two in-progress tasks conflict only when they hold a file in common;
no `holds` means analysis parallelises without limit); `set=A|B|C` are
sequential **phases**, not parallel lanes, gated until every prior set is
done — one set unless a genuine phase boundary exists, real dependencies via
`needs=`.

The practical limit on analysis is consoles and cost, not the kanban. **This
section is the concurrency authority** — `sprint.md`, `subdelegation.md` and
`manager-brief-template.md` defer to it. There is **no fleet or per-provider
cap** on parallel workers (operator's ruling, 2026-08-19); the only numeric
bound is the *recursion* depth cap (`WEIZIGO_AGENT_DEPTH`/`MAX_DEPTH=3`),
a different mechanism from parallel width.

## Dispatching, claiming, and the kanban

**Who may dispatch (operator ruling, 2026-08-23 — this is the one home;
other docs point here, none restate it).** Any seat may register and dispatch
unless its brief says otherwise: author the brief file, then one
`bin/managent` registration, then `bin/dispatch` when ready. Paste-prompts
are only for interactive-console targets the human must launch because no
running console owns them. `bin/managent` and the automated dispatcher keep
sprints, tasks and races conflict-free (`holds=` serialization, `needs=`
edges) — there is no single-active-orchestrator gate. A **queue cool-down**
is the rare, scoped, expiring exception for a wide refactorization: it halts
the automated dispatch loop only — deliberate seat dispatches named as
exceptions continue.

Any seat keeps the kanban honest — record a dispatch, record a claim a
worker started but did not, mark `done` when finished but unrecorded. **The
kanban is the bug when it disagrees with reality.** Empty `dispatchable` is a
bug — nothing to feed the fleet. Command semantics, including how
`dispatched_to` and `agent` differ and why a seat claiming on a worker's
behalf must use the worker's name: `docs/infra/managent/spec.md`.

## Instance vs model (review independence)

**Instances are not models.** A fresh instance holds no memory of, and no
attachment to, another instance's work, so self-review bars are
instance-level, not model-level (a fresh GLM worker console is not the same
agent as the GLM Orchestrator instance). But same-model fresh instances do
not remove correlated error — shared training means shared blind spots — so
the independence a fresh instance buys is **procedural, not epistemic**:

- Same-model fresh-instance review is acceptable for procedural / compliance
  / calibration checks (did the worker follow the brief, cite real paths).
- For adversarial review of load-bearing reasoning, prefer a **different
  model** — independent training, not just instances (the 2026-07-29 QA-018
  three-seat blind panel: GLM-5.2, DeepSeek-Pro, Kimi-k2.7).
- If only the same model is available, disclose it loudly; its verdict is
  procedural confirmation, not independent adjudication.

**Standing wording:** *Bar the instance always; prefer a different model
where the object under review is load-bearing reasoning; disclose same-model
review when unavoidable.* (User clarification, 2026-07-29, Dabir msg 031.)

## Adjudication authority — operator ruling, 2026-08-20

**`claude-fable-5` holds the first and final word on review, evaluation,
consolidation and selection.** Operator: *"ALL models (including Fable)
participate independently, freshly, and blindly. Another independent fresh
Fable has the highest first and final word. There is no higher authority. I
always reserve the right to step in, but I am passing authority to Fable."*

1. **Author-Fable and judge-Fable are different instances** — every lane
   authors independently, freshly, blind; a *separate* fresh Fable then
   judges anonymized inputs. Same label, different session, no shared
   context.
2. **This deliberately overrides `G3` family exclusion** (otherwise a hard
   refusal at counting, `tools/bakeoff.sh`, T542, 2026-08-20) — recorded here
   rather than applied silently, since a bypassed gate without a note is how
   this project accumulated seventeen defects. A judge selecting its own
   family's winner has that fact recorded alongside the result.
3. **The Orchestrator and the operator are not exempt** — seat-authored
   seeds, briefs and roadmaps go to Fable before they are spent on a fleet.
   The seat proposes, Fable rules, the operator may step in.
