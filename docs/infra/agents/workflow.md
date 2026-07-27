# Agent workflow — intention & spirit (not dogma)

Written 2026-07-25 from the user's direction. This is **guidance, not
bureaucracy**: the agent decides how much workflow complexity is appropriate
for each task. Many tasks need almost none of this; a few benefit from all of
it. The goal is **efficiency, transparency, flexibility, and robust provably-
correct results** — never ceremony for its own sake.

> If encoding these as rules starts producing deadweight instead of results,
> the rules are wrong; prune them. The point is robust, well-documented
> outcomes on a cutting-edge research frontier where *epistemic* documentation
> (what we know / don't know / how we know) is the primary asset.

## The full pipeline (use the subset that fits)

A complete task may flow through, in order:

1. **Mutual human–agent understanding** — confirm we mean the same thing
   before doing. (This project's hardest bugs were sign/scope errors, not
   logic.)
2. **Specification** — write what is intended and what would prove or falsify
   it, *before* implementing.
3. **Research** — prior art, measurements, dead-ends already known (read the
   ADRs/research first; do not relitigate foreclosures).
4. **Scope** — what's in/out; what's a separate task.
5. **Design** — the approach; an ADR if it's a real decision.
6. **Plan** — small, fail-fast subtasks (see below).
7. **Implementation.**
8. **Tests** — including the standing gates (e.g. the #2 auditor; the zero-
   leak acceptance test).
9. **Human verification.**
10. **Git: branch → commit → integrate.**

**Each phase is independently auditable by a fresh agent.** That is the
parallelization / quality lever: a clean agent with only the relevant doc can
audit one phase without the context that produced it. Use this where it pays;
skip it where it doesn't.

## Document before / while / after

The living document (`../../epistemic/PROGRESS.md` + `../../status/` + `../../decisions/` + `../../research/`)
is written **before, during, and after** the work — not merely after.

- **Before:** state intent + the falsifiable acceptance test as a `TODO`.
  Writing first exposes bad plans (this project's kill-X% and PSK dead-ends
  would have been caught sooner with stricter before-docs).
- **While:** keep the relevant chapter honest as work proceeds; mark
  assumptions explicitly.
- **After:** record what actually happened — success **or** failure — and
  prune.

When a `TODO` closes it becomes a concise proven statement (with the evidence
that we know it and how we know it); the supporting detail moves to a leaf or
is deleted. Open questions get *more* detail (experiment design, failure
modes) until they close. **The document state and the code state inch toward
the truth together.**

## Fail-fast subtasks

Break work into small subtasks that each **fail fast**: a subtask should
either produce a checked-in result or fail visibly, not run for an hour as a
black box. (The 4-hour finisher black-box run was the anti-pattern that
motivated this.) Prefer an experiment that returns a number in seconds over
one that grinds.

## Always ready to clear context

Agents must **write unchecked task status to disk** continuously, so the work
is always resumable after a session failure, context clear, context compact,
or handover. Concretely:

- **Milestones** → committed to git (code + docs).
- **The current in-flight task** → `../../status/CURRENT.md` (ephemeral, updated
  often): what I am doing right now, the next concrete step, and any partial
  state not yet committed. A fresh session reads `../../epistemic/PROGRESS.md` →
  `../../status/leak-crisis.md` → `../../status/CURRENT.md` and resumes without loss.
- **Decisions/findings** → ADRs (`../../decisions/`) / `../../research/` (durable).
- **Console discussion** → distilled into the tree only when it changes a
  decision (ADR), reveals a finding (`../../research/`), or changes the plan
  (`../../status/`); else it stays ephemeral.

Aim to **implement → test → stabilize → verify → commit** in small cycles, so
that at any moment the committed state is coherent and the only thing at risk
is the current `../../status/CURRENT.md` line.

## Parallelization

When a parent task is broken into chunks:

- **Uniquely ID the files/outputs** of each chunk (e.g.
  `../../status/e3-lo-fixpoint.md`, not a shared scratch file) so parallel agents
  don't collide.
- **Each task declares its parallelization tolerance** (can run in parallel
  with what? must be serial after what?) — usually decided by the parent that
  breaks the chunks.
- The biggest hazard here is **concurrent writes to the same engine file**
  (`retro.zig`): two agents editing it at once will silently corrupt. Default
  to one writer per engine file; parallelize only on independent files
  (artifacts, probes, docs, tests).

## Epistemic discipline (frontier research)

This is the part that matters most for this project. Every claim carries a
**verification status**: PROVEN (cite how), CLAIMED (state what's missing), or
FALSE-AS-SCOPED (record the lesson). Never assert "proven/sound/correct"
without the evidence that makes it so — the `ko_ref >= d` bug and the E2
sign error both *looked* obviously right and weren't. When a result is
ambiguous (e.g. E3: valid PSK game + `lo=2` + reached `−9`, but the direct
`true < lo` check was intractable), **record the ambiguity explicitly** rather
than forcing a clean story. See `../../status/leak-crisis.md` for the live example.

## How much to use? (the agent's call)

- Trivial fix / doc edit → just do it; one line in `../../status/CURRENT.md`.
- A probe or measurement → spec-line + run + record; no ADR needed.
- A real decision (ruleset, engine semantics, a new bound claim) → ADR + the
  battery/auditor as the gate.
- Anything touching the engine's soundness → full pipeline + a fresh-agent
  audit + the standing gate.

The test of whether the workflow is right: did it produce a robust,
well-documented, provably-correct result with less total effort (including
rework) than ad-hoc? If not, simplify.
