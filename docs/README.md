# weizigo docs

Working notes for the brute-force / perfect small-goban Go solver.

## Read order (start here)

1. `epistemic/PROGRESS.md` — the living specification: what we know, what we need to
   know, what we need to build. The hub; read it first.
2. `epistemic/names.md` — canonical names (the table, the values, the two regions).
3. `status/leak-crisis.md` — the current-focus crisis.
4. `about-this-document.md` — the documentation method.
5. `infra/delegation/DELEGATOR.md` (writing a task) or `infra/delegation/DELEGATEE.md`
   (executing one) — read one, only when it applies to you.
6. `epistemic/GLOSSARY.md` — terms.
7. `AGENTS.md` (repo root) — the router: foreclosures, the behaviour rules that bind every
   agent, and which single process file each role reads.
8. `epistemic/boards/CONCEPTS.md` — the cross-size concept-inventory (fact-topics
   every goban-size tree must address; definitions only, no status).
9. `epistemic/boards/4x4/EPISTEMIC.md` — the 4×4 epistemic tree (the active focus).
10. `status/HANDOVER.md` — tactical session continuity. `engine/ARCHITECTURE.md` — module
    map. `engine/TODO.md` — legacy backlog (being superseded by PROGRESS + status/).

## Layout

- `epistemic/PROGRESS.md` — the living specification (current truth; the hub).
- `epistemic/names.md` — canonical names register (proposed; pending propagation).
- `about-this-document.md` — the documentation-as-specification-as-research
  method.
- `infra/delegation/` — `DELEGATOR.md` (how to write a task) and `DELEGATEE.md` (how to
  execute one). `infra/dispatch/` — one brief per experiment + the dispatch README.
  `infra/agents/workflow.md`, `infra/sprint.md`, `infra/subagent.md`,
  `infra/agents/boss-role.md`, `infra/agents/worker-role.md`, `infra/delegation.md` —
  retired 2026-07-28; each is a stub naming its replacement.
- `status/CURRENT.md` — ephemeral in-flight task status (read on resume;
  update continuously).
- `status/` — current state and live crises (`leak-crisis.md`).
- `decisions/` — Architecture Decision Records (ADRs), append-only, one
  numbered file per decision. Append new ones; supersede, don't rewrite.
- `research/` — durable findings, measurements, dead-ends, and lessons.
- `epistemic/boards/CONCEPTS.md` — cross-size concept-inventory (fact-topics only).
- `epistemic/boards/<WxH>/EPISTEMIC.md` — per-goban-size epistemic trees (status per
  claim, falsifiable experiments, current focus).
- `epistemic/GLOSSARY.md` — terms and abbreviations. Project-invented shorthand is
  marked `[project term]`.
- `status/HANDOVER.md` — session-continuity snapshot (tactical; updated every
  session). `engine/ARCHITECTURE.md` — module map. `engine/TODO.md` — legacy backlog.

## Conventions

- Dates are absolute (e.g. 2026-07-24), never "today."
- Numbers that came from a run include how they were produced (command,
  goban size, flags).
- When a research note drives a decision, link them by filename.
- Status markers: `[ ]` todo · `[~]` in progress · `[x]` done · `[-]` dropped.
- The document state and the code state are coupled: both inch toward the
  truth together (see `about-this-document.md`).
