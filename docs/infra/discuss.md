# Discuss — structured relay protocol

**Status: living protocol. [Current.]**

**A cross-harness discussion skill. Read this, then adopt the protocol.**

## Goal

Conclude or kill every topic. No open loops. No zombie threads.

## Mechanics

Maintain a numbered outline of topics. The agent tracks all topics but
engages with **only one at a time.** The human and agent trade short
messages — a sentence, a paragraph, at most half a page. Keep it a relay,
not a lecture.

## Tempo

The human sets the pace:

- **Quick** — surface-level. Decisions in one or two exchanges. Good for
  triage, delegation, pruning.
- **Deep** — thorough. Explore until exhaustion. Good for design,
  strategy, hard problems.
- **Mixed** — breadth-first scan for quick wins, then slow down on what
  remains.

The agent mirrors the human's tempo. If the human is terse, be terse. If
the human goes deep, go deep.

## Rules

1. **One topic at a time.** Finish or park before moving on.
2. **Numbered outline.** Topics are `1.`, `1.1`, `1.2`, `2.` etc.
   Cross-reference related topics by number.
3. **Conclude or kill.** Every topic ends in a decision, an action, a
   delegation, or an explicit "park for later." Nothing stays open
   indefinitely.
4. **Write conclusions to disk.** When a topic concludes, record the
   outcome in `untracked/heap.md` or the relevant project doc. The
   outline shrinks.
5. **Prune the outline.** Remove dead topics. Merge duplicates. Keep it
   current.

## Topic states

- `[ ]` — not yet discussed
- `[~]` — in progress (only one at a time)
- `[✓]` — concluded (decision made, action delegated, or parked with date)
- `[✗]` — killed (not worth discussing, or superseded)

## Example

```
[ ] 1. managent MVP scope
[ ] 2. Phase 2 tooling (status reporter)
[ ] 3. Heap hygiene — how often to prune?
```

Human picks topic 1. Agent and human trade 3-4 exchanges. Decision: scope
is 6 commands, audited at design and test. Agent writes conclusion to
`docs/infra/managent/scope.md`. Topic marked `[✓]`. Move to topic 2.
