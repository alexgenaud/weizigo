# Agent workflow — RETIRED 2026-07-28 (two rules kept below)

The ten-phase pipeline, the fail-fast-subtask rule, the parallelization rules and the epistemic-
discipline section have moved: **`AGENTS.md`** (behaviour + foreclosures),
**`docs/infra/delegation/DELEGATOR.md`** (costing a method, testable acceptance, heartbeat,
reviewer ownership), **`docs/infra/delegation/DELEGATEE.md`** (execution, honest negatives).
Read those. The two rules below are documented **only here**.

## Document before / while / after

The living documents are written *before*, *during*, and *after* the work — not merely after.
**Before:** intent + the falsifiable acceptance test, as a `TODO`. **While:** keep the relevant
chapter honest; mark assumptions explicitly. **After:** record what actually happened — success
*or* failure — and prune. A closed `TODO` becomes a concise proven statement with its evidence;
supporting detail moves to a leaf or is deleted. Open questions get *more* detail (experiment
design, failure modes) until they close. The document state and the code state inch toward the
truth together (`docs/about-this-document.md`).

## Where state lives, so context can be cleared at any moment

- **Milestones** → committed to git (code + docs).
- **The in-flight task** → `docs/status/CURRENT.md`, updated continuously: what I am doing now,
  the next concrete step, any partial state not yet committed.
- **Decisions / findings** → `docs/decisions/` (ADRs, append-only) and `docs/research/`.
- **Console discussion** → distilled into the tree only when it changes a decision, reveals a
  finding, or changes the plan; otherwise it stays ephemeral.
- Aim for **implement → test → stabilize → verify → commit** in small cycles, so the committed
  state is always coherent and the only thing at risk is the current `CURRENT.md` line.

## How much process to apply (the agent's call)

Trivial fix or doc edit → do it, one line in `CURRENT.md`. A probe or measurement → spec-line,
run, record. A real decision (ruleset, engine semantics, a new bound claim) → ADR + the
auditor/battery as the gate. Anything touching engine soundness → the full pipeline + a
fresh-agent audit. If encoding these as rules produces deadweight instead of results, the rules
are wrong — prune them.
