# S11 — Honest instruments (sprint map)

**Scope:** every reading this system reports is known, unknown, or refused — never a confident wrong
value. Full statement: `docs/status/scope-honest-instruments.md`.

**Method** (operator, 2026-08-24): design blind from scratch; document what exists blind; compare both
directions; then fix, with acceptance tests written first and shown red.

**The seat's role:** construct this plan and enforce it. The seat does not research, document, or
implement. Every artifact here is produced by a dispatched worker and graded by a different one.

## Vocabulary, so the hierarchy is unambiguous

- A **stream** is a body of work that can run in parallel with, and blind to, other streams.
- A **phase** is one audited loop inside a stream that produces **exactly one** final document.
  Phases of a sprint pass are: spec, research, scope, design, pass-plan, build, accept, verify — used
  as appropriate, not all of them always.

## Where things live

- `docs/.../S11-honest-instruments/<stream>/<phase>/<doc>.md` — **only the final, audited, refined
  document for that phase.** One per phase. If it is here, it has been graded and accepted.
- `untracked/epics/E1-markovian/L1-dashboard/S11-honest-instruments/<stream>/` — arms, revisions,
  grades, audits, scratch. All of it deletable. Nothing here is authoritative.

That split is the measurement: a phase is complete when and only when its single document exists in
`docs/` with a grade recorded in `STATUS.md`.

## The streams

| stream | blind to | runs | final document |
|---|---|---|---|
| `stream1-design` | the repository, stream2, its own sibling arm | 2 arms in parallel, different models | `stream1-design/design.md` |
| `stream2-whatis` | stream1, its own sibling arm | 2 arms in parallel, different models | `stream2-whatis/whatis.md` |
| `stream3-compare` | nothing — **first meeting point of 1 and 2** | serial, after both are accepted | `comparison.md` + `decisions.md` |
| `stream4-fix` | nothing | serial phases | one document per phase |

**Blindness is structural, not trusted:** every arm's brief carries its own instructions inline and
never points at a shared file, so no arm can read another's out of curiosity. Two arms per stream on
**different models**, so a finding present in both is a property of the problem and a finding present in
one is a property of that model.

## The loop inside every phase

1. **arms** (untracked) — N independent products, authors blind to each other.
2. **grade** (untracked) — a worker that authored none of them audits every arm against the phase's
   stated acceptance conditions.
3. **reconcile** → the single final document in `docs/`. Disagreements between arms are recorded **as
   disagreements**, never averaged away.

## Exit criterion for the whole sprint

Not "the code changed". A waypoint or pass is complete only when it leaves behind **unit tests and
regression tests that actually run periodically** and that would catch the defect returning. Today's
measured baseline: **23 of 86 regression scripts fail**, and nothing runs them on a schedule — the
daily unattended runner was disabled on 2026-08-24 after running unsupervised. So `stream4-fix` must
also deliver the periodic run itself, attended and reporting, or the suite it leaves behind is
decoration.

## Concurrency, and why it is capped low

Operator ruling 2026-08-24: at most **2 rows per model**, **5 per family**, **10 concurrent overall**,
with no expectation of approaching any of them. His reason, recorded because it governs every future
decision here: parallelism is only a wall-clock optimisation and is often the source of unnecessary
complexity and failure. The per-model limit has no implementation yet and is enforced by the seat.
