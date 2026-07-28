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
```

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

**Independence.** A reviewer must know less than the worker: give the artefact,
the relevant foreclosures, and *find the flaw; assume one exists.* Anything
arguing for the conclusion biases the review.

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
