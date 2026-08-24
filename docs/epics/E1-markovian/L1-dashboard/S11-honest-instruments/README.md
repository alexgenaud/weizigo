# S11 — Honest instruments (sprint map)

**Scope statement:** `docs/status/scope-honest-instruments.md` — every reading this system reports is
known, unknown, or refused; never a confident wrong value.

**Method** (operator's, 2026-08-24): design blind from scratch, document what exists blind, compare
both directions, then write a new spec informed by both with acceptance tests first and red.

**The seat's role:** construct this plan and enforce it. The seat does not research, document, or
implement. Every artifact below is produced by a dispatched worker and audited by a different one.

## Phases

| phase | shape | blind to | converges? | gate to leave |
|---|---|---|---|---|
| 1 — design | 2 arms in parallel, different models | the repository, each other, all of phase 2 | no | both arms closed + graded + reconciled |
| 2 — what-is | 2 arms in parallel, different models | each other, all of phase 1 | no | both arms closed + graded + reconciled |
| 3 — compare | serial, single owner | nothing — this is the first meeting point | **yes** | bidirectional comparison + decisions recorded |
| 4 — spec | serial | nothing | — | spec + acceptance tests (red) + plan, each audited |
| 5 — execute | serial passes | nothing | — | every acceptance test green, each pass audited |

**Blindness is enforced by the briefs, not by trust:** each arm's brief carries only its own half
inline and never points at a shared file, so no arm can read another's instructions out of curiosity.
Arms are graded by a worker that did not produce them.

## Per-phase loop (the same four steps everywhere)

1. **arms/** — N independent products, one document each, authors blind to each other.
2. **grade.md** — a different worker audits every arm against the phase's acceptance conditions.
   Records what each arm got right, wrong, and missed. Never written by an arm's author.
3. **reconcile.md** — the merged result: what survives from which arm and why. Disagreements between
   arms are recorded as disagreements, never averaged away.
4. **STATUS row updated** — progress is the existence *and* grade of these artifacts, nothing else.

## Measuring progress

`STATUS.md` is the only progress surface. An artifact counts when it exists **and** carries a grade.
A missing artifact and an ungraded artifact are both incomplete. The baseline this sprint must move is
the count in phase 2's reconcile: how many surfaces emit a value where the honest answer is "cannot
determine", how many checks cannot fail, how many places reinterpret unrecognised input.
