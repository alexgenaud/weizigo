# weizigo docs

Working notes for the brute-force / perfect small-board Go solver.

## Read order (start here)

1. `PROGRESS.md` — the living specification: what we know, what we need to
   know, what we need to build. The hub; read it first.
2. `names.md` — canonical names (the table, the values, the two regions).
3. `status/leak-crisis.md` — the current-focus crisis.
4. `about-this-document.md` — the documentation method.
5. `agent-workflow.md` — the agent workflow intention (pipeline, readiness,
   parallelization).
5. `GLOSSARY.md` — terms.
6. `AGENTS.md` (repo root) — agent behavior rules and foreclosures.
7. `HANDOVER.md` — tactical session continuity. `ARCHITECTURE.md` — module
   map. `TODO.md` — legacy backlog (being superseded by PROGRESS + status/).

## Layout

- `PROGRESS.md` — the living specification (current truth; the hub).
- `names.md` — canonical names register (proposed; pending propagation).
- `about-this-document.md` — the documentation-as-specification-as-research
  method.
- `agent-workflow.md` — the agent workflow intention (spirit, not dogma).
- `status/CURRENT.md` — ephemeral in-flight task status (read on resume;
  update continuously).
- `status/` — current state and live crises (`leak-crisis.md`).
- `decisions/` — Architecture Decision Records (ADRs), append-only, one
  numbered file per decision. Append new ones; supersede, don't rewrite.
- `research/` — durable findings, measurements, dead-ends, and lessons.
- `GLOSSARY.md` — terms and abbreviations. Project-invented shorthand is
  marked `[project term]`.
- `HANDOVER.md` — session-continuity snapshot (tactical; updated every
  session). `ARCHITECTURE.md` — module map. `TODO.md` — legacy backlog.

## Conventions

- Dates are absolute (e.g. 2026-07-24), never "today."
- Numbers that came from a run include how they were produced (command,
  board size, flags).
- When a research note drives a decision, link them by filename.
- Status markers: `[ ]` todo · `[~]` in progress · `[x]` done · `[-]` dropped.
- The document state and the code state are coupled: both inch toward the
  truth together (see `about-this-document.md`).
