# DELEGATOR — writing a task

A brief succeeds when a competent agent following it cannot reach a wrong answer
believing it is right.

## The header

```
CLAIM:      the CLAIMS.md row this settles
KIND:       ANALYSIS (parallel, one new file) or MUTATION (serial, cites its analysis)
OWNS:       exact paths — everything else is forbidden
READS:      the minimum
ACCEPTANCE: falsifiable, with numbers
REVIEW:     who dispatches it, and whether work may proceed meanwhile
DISPATCH:   the agent the human assigned this to; if blank, the Orchestrator
            queues it without a target and the agent self-claims
```

The `DISPATCH` row is *advisory*, not *authoritative*: it is the human's
preference, and any agent may still claim the task via
`managent claim <id> --agent <name>`. The pattern is in
`docs/infra/delegation/ROLES.md` §"Dispatching, claiming, and the
kanban" and the schema is in
`docs/infra/managent/spec.md`. **A delegator does not need to specify a
model; if you must, give a reason.**

## The bundle meta line — what `managent` enforces for you

Every bundle opens with `<!--managent set=X deliverables=… [holds=…] [acceptance=…]-->`,
and `managent done` refuses to close while a declared deliverable is missing. That
makes the meta line the only part of a brief a worker cannot skip, so put the
non-negotiables there rather than in prose:

- **The findings file, by exact path** — `findings/<id>-<slug>.json`, not a glob. A
  brief that says "findings to `findings/T2xx-*.json`" in prose gets a task that closes
  without one; T275 did exactly that on 2026-08-02.
- **The context dump, by exact path** — `findings/<id>-context.json`. Asking for it in
  the closing prompt works only if someone remembers to ask; declaring it means the
  dump exists *before* the task can close, and the dump is where two P0 defects came
  from. The shape is specified once, in `DELEGATEE.md` §Reporting.
- **`holds=`** for any single-owner file (`docs/epistemic/CLAIMS.md` above all) — the
  hold conflicts with a second task declaring the same path, which is cheaper than
  discovering the race afterwards.
- **`acceptance=`** whenever a runnable green condition exists. `managent audit` warns
  on every done task that never had one.

Note the gap this does *not* close: the check asks whether the file **exists**, not
whether it is committed — T272 closed `pass` on 2026-08-02 with every deliverable
untracked. T278 owns the fix; until it lands, verify with `git status` yourself before
accepting a close.

## Principles

**Falsifiability.** Name the result that would falsify the claim. If none would,
the test is decoration and the input is wrong. State what a *wrong* answer scores
on your criterion: one that a wrong answer usually passes proves nothing.

**Cost.** Cost the method before specifying it. If you cannot, make costing it the
first deliverable.

**Restraint.** Specify only what changes the outcome, and say why — including
about models. A per-task requirement with a stated reason is legitimate; standing
assignments and the final pick belong to the human. A task that only a huge
context window can hold is a badly scoped brief.

**Model assignment.** The brief does **not** specify a model — the human invokes the harness session and assigns the model at runtime (the model truth is known only there). You may *suggest* a model in the `DISPATCH` row or a dispatch note, but the choice is the human's. The agent is told its model at launch and writes the **real** model in the deliverable; the Orchestrator records stats and impressions in `docs/infra/model-perf.md`. (Temporary model preferences — e.g. 'use DeepSeek more right now' — are session memory, not disk rules; they change with billing and the human's call.)

**Independence.** A reviewer must know less than the worker: give the artefact,
the relevant foreclosures, and *find the flaw; assume one exists.* Anything
arguing for the conclusion biases the review. **Instances are not models**
(`ROLES.md` §"Instance vs model"): a fresh instance of the same model is
acceptable for procedural/compliance/calibration review, but for adversarial
review of load-bearing reasoning prefer a **different model** (shared training
→ correlated blind spots); disclose same-model review when unavoidable.

**Visibility.** Work that may run past a minute reports progress and carries a
budget. From outside, silence and progress look identical.

**Concurrency.** ANALYSIS writes exactly one new file and modifies nothing, so any
number may run at once. MUTATION may modify existing files, runs one at a time,
and cites the analysis that recommended it.

**Durability.** Evidence goes to `docs/evidence/<claim-id>/` when it is produced.
A claim whose evidence cannot be retrieved is not proven.

**Prior art.** Name the foreclosure or earlier attempt this task must distinguish
itself from. Foreclosures live in `AGENTS.md`.

**Honest negatives.** A negative result is a deliverable, reported with the same
confidence as a positive one.

## Before dispatching

Ask what a competent agent could get wrong while following this exactly — then fix
that. Apply this file's standards to this file.

Roles, naming, capability vocabulary, concurrency: `ROLES.md`.
