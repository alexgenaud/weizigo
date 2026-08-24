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
| `stream1-design` | the repository, stream2, its sibling arm | 2 arms, parallel, different models | `stream1-design/design.md` |
| `stream2-whatis` | stream1, its sibling arm | 2 arms, parallel, different models | `stream2-whatis/whatis.md` |
| `stream2b-green` | nothing | serial | `stream2b-green/green.md` |
| `stream2c-delta` | nothing | serial, short | `stream2c-delta/delta.md` |
| `stream3-compare` | nothing — **first meeting of 1 and 2** | serial | `comparison.md` + `decisions.md` |
| `stream4-fix` | nothing | serial phases | one document per phase |

### Why stream2b exists, and why it gates stream3

**Operator ruling, 2026-08-24:** the full suite must reach **zero red** — by pruning scripts, functions
and tests that should not exist at all (four checks are already known to be unable to fail under any
input), then fixing code or tests until the remainder passes. *"We must eagerly move to zero red tests,
then remove the ratchets."* A ratchet is permitted only as a temporary device carrying a named owner and
an explicit expiry condition; a blanket "ignore failures" switch is forbidden.

This is not optional tidying. Under the acceptance rule, **a module cannot be accepted while its own
suite is red**, so zero-red is a precondition for accepting any work in `stream4-fix`, not a follow-up
to it. Measured starting point: **23 of 86 regression scripts fail.**

### Why stream2c exists, and why it is a delta rather than a re-run

The what-is arms describe a system with 23 red scripts and four vacuous checks. Green-up changes some of
that, so the inventory goes partly stale. **The seat's decision: do not re-run the full what-is.** Its
value is the inventory of instrument dishonesty, most of which green-up does not touch, and a second
full pass would cost far more than it corrects. Instead `stream2c` re-measures **only the counts
green-up could have moved** — the vacuous checks and the red set — and amends the what-is document,
recording what changed and what did not.

### Ordering, and the mutual dependency at its centre

`stream2b` and the module-test contract depend on each other: you cannot gate changes on module suites
while 23 of them are red, and you cannot reach zero red without knowing which suite covers which module.
Resolved by sequence: the contract declares the map **and a dated, per-script, owned baseline**; stream2b
burns that baseline to zero; **the ratchet is deleted as stream2b's final act.** Its deletion is an
acceptance condition of stream2b, not a hope.

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

## Acceptance rule — applies to every change, from a one-line edit to a full sprint

**Operator ruling, 2026-08-24.** Not a schedule. The rule is test-driven development plus continuous
integration, stated as three obligations:

1. **Every module has a test suite.** A *module* is a subset of the project, and in this project a
   module is not necessarily software. The tooling is software. The **epistemic tree is prose** —
   claims, evidence, proofs, falsifications, peer review — and it has a suite too. Experiments, tables
   and engines are software modules and each needs its own suite.
2. **Every change to a module runs that module's suite before the change is accepted.** No exceptions
   for size: a single task and a whole sprint obey the same rule.
3. **Every change starts red.** The test that proves the change is needed is written first and shown
   failing; acceptance is that same suite passing green.

A nightly full run may be worth having, but it is **not** the requirement and must not be mistaken for
one. Running everything on a timer does not tell you whether *this* change broke *that* module.

### The mechanism already half-exists, and that is why this rule bites

`tools/hooks/pre-commit` reads a module-test contract and announces *"change-based selection active"*.
The contract file exists at `docs/epics/E1-markovian/L1-dashboard/S09-module-test-contract/spec.md` and
declares **zero** `test … covers …` mappings. With no declarations every script's coverage reads empty,
so the gate runs a **fixed thirteen-script pool** regardless of what changed — and can only ever *narrow*
that pool, never add a suite from outside it.

**Measured consequence:** a change to `src/managent/main.zig` was accepted after running the fixed pool,
which does not contain the ~20 `regression-managent-*` scripts that cover it. Three of them broke and the
commit passed clean. The regression was found a day later by an unrelated worker.

So obligation 2 is not satisfiable today. Populating that contract, and letting the gate *select* rather
than only *skip*, is a prerequisite for accepting any change in `stream4-fix`.

## Concurrency, and why it is capped low

Operator ruling 2026-08-24: at most **2 rows per model**, **5 per family**, **10 concurrent overall**,
with no expectation of approaching any of them. His reason, recorded because it governs every future
decision here: parallelism is only a wall-clock optimisation and is often the source of unnecessary
complexity and failure. The per-model limit has no implementation yet and is enforced by the seat.
