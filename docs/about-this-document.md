# About this document (the method)

This chapter describes the method behind `epistemic/PROGRESS.md` and the `docs/` tree.
It is itself part of the structure it describes — the living document is
self-describing and is pruned like everything else.

## The document is an epistemological structure

The point is not to log activity; it is to track **knowledge**. Three
questions organize everything:

- **What do we know?** — stated concisely when proven, with the evidence that
  makes us certain.
- **What do we need to know?** — the open questions, each a `TODO` pointing
  at the experiment or analysis that closes it.
- **What do we need to build in order to know?** — the code, probes, and
  proofs that turn "need to know" into "know."

The final goal is **provable knowledge**: a perfect, provable account of
larger and larger Go games. Every chapter is a step toward or away from
that; nothing is kept that doesn't serve it.

## Documentation-as-specification-as-research

The document is written **before, during, and after** the work — not merely
after. The discipline:

- **Before:** state what we intend and what would prove or falsify it
  (a `TODO` with an acceptance test). Writing first exposes bad plans early.
- **During:** keep the relevant chapter honest as the work proceeds; mark
  assumptions explicitly.
- **After:** record what actually happened — success or failure — and
  prune.

This couples the **document state** and the **code state**: both inch toward
the truth together. When an experiment falsifies a claim, the code changes
*and* the chapter changes in the same step.

## When console discussion becomes documentation

Most console discussion is ephemeral and stays so. A discussion is distilled
into the tree only when it does one of:

- **changes a decision** → a new ADR in `decisions/` (append-only; supersede,
  don't rewrite).
- **reveals a finding / measurement / dead-end / lesson** → a `research/`
  note.
- **changes the plan or status** → an update to `status/` (or `PROGRESS.md`).
- Everything else → stays in console.

The living document is the **distilled** record, never the transcript.

## `TODO` comments in the documentation

Open items live **in the documentation**, not only in code. Every `TODO` is
one of two kinds:

- **"clean up the language"** — the claim is true but stated unclearly,
  inconsistently, or in deprecated jargon; the fix is editorial.
- **"write experiment / proof to know"** — the claim is open; the fix is a
  falsifiable experiment or a proof, after which the `TODO` is replaced by a
  concise proven statement.

This keeps the document *true and useful*: it never asserts what we don't
know, and it never leaves a known truth buried in detail.

## Pruning and condensation

Frequently. When something is **100% proven or falsified**, compress it to a
concise statement plus the *evidence that we know it and how we know it* —
the supporting detail can move to a leaf or be deleted. Conversely, open
questions get *more* detail (the experiment design, the failure modes) until
they close. The tree grows resolution where it is uncertain and shrinks it
where it is certain.

## Roles and conventions

- `epistemic/PROGRESS.md` — strategic, current-truth overview. The hub. Touched in
  essentially every session.
- `status/HANDOVER.md` — tactical session continuity (the immediate next task,
  gotchas). Updated every session. Distinct from PROGRESS.
- `decisions/` — append-only history; never rewritten. ADRs are the record of
  *why* a decision was made, frozen in time.
- `research/` — findings, measurements, dead-ends. Historical record.
- `status/` — current state and live crises (e.g. `leak-crisis.md`).
- `epistemic/names.md` — canonical names register.
- `epistemic/GLOSSARY.md` — terms; project-invented shorthand marked `[project term]`.
- `AGENTS.md` (repo root) — agent behavior rules and foreclosures.

Status markers (carry over from the legacy `engine/TODO.md`): `[ ]` todo · `[~]` in
progress · `[x]` done · `[-]` dropped.

## Related

- `infra/agents/workflow.md` — the broader agent workflow intention
  (pipeline phases, fail-fast subtasks, readiness-for-context-clear,
  parallelization, auditability). This file is the *documentation* method;
  that one is the *agent* method. They compose.
- `status/CURRENT.md` — the ephemeral in-flight-task file that makes the
  "always ready to clear context" rule concrete.

## Reflexive note

This chapter is itself subject to the method. As the project matures and the
method proves itself (or doesn't), this chapter is pruned to the concise
evidence of what worked. If the method fails, that failure becomes a
`research/` note and this chapter shrinks.
