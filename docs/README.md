# weizigo docs

Working notes for the brute-force / perfect 5×5 Go solver.

## Layout

- `HANDOVER.md` — **start here** after a context compact/clear: current state,
  the immediate next task, gotchas, and how to build/run.
- `TODO.md` — the task backlog (Now / Next / Later / Housekeeping).
- `decisions/` — Architecture Decision Records (ADRs), one numbered file per
  decision. Each says the context, the decision, and why. Append new ones;
  don't rewrite history — if a decision is reversed, add a new ADR that
  supersedes the old and note it in both.
- `research/` — durable findings: Go rules, the transposition bug analysis,
  data-model / information-theory notes, and measurement results.

## Conventions

- Dates are absolute (e.g. 2026-07-14), never "today".
- Numbers that came from a run include how they were produced
  (`zig run -O ReleaseFast src/measure.zig`, board size, depth).
- When a research note drives a decision, link them by filename.

## Current focus (2026-07-14)

Fix the correctness bug **before** any deeper search or data-model work:
the transposition table is unsound because positions repeat (no ko rule) and
values are horizon-limited (see `research/transposition-bug-root-cause.md`).
Plan: positional superko + Benson terminal + area scoring
(`decisions/0003`, `decisions/0004`).
