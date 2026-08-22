# S04 — Orchestrator retirement: the ephemeral reconciler (SEED)

**Status:** SEED — pre-spec input, not ratified. The sprint's first phase turns this into the
audited `spec.md`; at ratification this file's content is folded and the seed deleted (one
canonical unsuffixed doc per phase). **Author:** claude-fable-5 at the operator's console,
2026-08-22 (operator direction recorded verbatim in §2). **Kanban row:** T578. **Sits on:**
pass-2 supervisor (`…/S01-process-ownership/pass2/spec.md`), the S03 queue layer
(`…/S03-queue-layer/spec.md`), and `docs/status/orchestration-layer-spec.md` (§3 queue, §7/§7b
rulings, §9 artifact-state invariant).

## 1. Goal in one line

Retire the long-lived orchestrator seat: the queue mechanism decides everything decidable by
rule; a short-lived **reconciler** agent, spawned periodically by the tooling and retired within
minutes, decides the residue inside a bounded verb set; only irreversible or scope-changing
decisions reach the operator.

## 2. The operator's direction (2026-08-22, paraphrased from his console)

Agents work diligently in the background; tasks run in good time without conflict. Ideas flow
through the formal sprint process (audited spec, scope + acceptance tests, audited design,
audited plan, test-first build, audited, verified). The orchestrator must not ask questions it
can answer itself — research, think, or delegate to a stronger agent; alert only on real
concerns. End state: **no standing orchestrator agent** — or one that "arises periodically,
spawned by the dispatcher tooling, and retires within minutes." The operator discusses,
specifies, verifies, and directs at a higher level; nobody micromanages tasks.

This is the same end state ROADMAP-2026-08-21 already names ("tooling + brief, not a long-lived
seat") and it matches the no-cross-session-continuity doctrine: a model holding a seat has no
real continuity anyway — the store was always the memory. The reconciler makes that honest.

## 3. What already exists — do not rebuild

Dispatch refusals + `tools/dispatch_verify.py`; `managent liveness/reap/treekill/audit`;
`argus --mode doctor`; `tell/inbox/sync`; duties + landmark gating; `orient/resume`; the queue's
conditions + discharge rule (orchestration-layer-spec §3); the supervisor (pass 2). This sprint
adds ONLY: the reconciler, the escalation contract, the decision-log study, the retirement gate.

## 4. Phase 0 — the decision-log study (evidence before design)

Mine `docs/infra/managent/directives.jsonl`, `archive.json`, and the handover docs for every
decision the orchestrator seat has actually made across its lifetime (T335/T337 consoles,
ORCHA-FLASH, T556/T557/T568). Classify each decision:

- **(a) mechanized** — a tool already refuses/does it;
- **(b) lookup** — decidable from a data table (model fit per D027 task types, ordering,
  wall-clock choice, appetite);
- **(c) judgment** — verdict evaluation, escalation triage, novel situations.

Deliverable: a counted classification table. The reconciler's scope is column (c) and nothing
else; every (b) row becomes queue **data**, never reconciler prose. The spec's scope is derived
from this table, not designed from intuition — if the table shows (c) is small, the sprint
shrinks accordingly.

## 5. The reconciler

- **Trigger:** spawned by tooling — a queue cycle, a cron tick, or an event (lane death, duty
  due, `managent audit` discrepancy). Hard wall measured in minutes. Retires by default; never
  waits idle.
- **Inputs:** the read-only battery — `managent status --json / audit / liveness / sync --peek`,
  `argus --mode doctor`. All state is read from the store at spawn.
- **Bounded verb set (whitelist):** dispatch the next ready row via the supervisor; `tell`
  (nudge / question a lane); `reap --close` for a confirmed orphan; `done` with recorded verdict
  ONLY where the row's acceptance command exits 0; **escalate** (assert to the ledger + surface
  to the operator). **Never:** `retire`, `amend`, force-close, spec/plan edits, answering the
  ruling queue, minting rows (it escalates the need instead — ruling 5's recursion safety stays
  moot by construction).
- **Enforcement is mechanism, not prose:** the verb boundary lives in `managent` itself
  (precedent: `MANAGENT_TEST=1` refuses mutating verbs). A reconciler that *asks nicely* not to
  amend is D054's prose failure again.
- **Statelessness:** every decision is written to the store before retirement. No handover doc
  is owed — the store IS the handover.
- **Model:** cheapest passing per the race protocol; "reconciler" enters the task-type ladder as
  its own row.

## 6. The escalation contract (principled, one sentence)

> Escalate to the operator only decisions that are **irreversible** or that **change scope**;
> everything else the reconciler resolves from the store and the docs, or delegates to a
> stronger agent.

Corollary (doctrine: fix the tools, delete the prose): an escalation category that recurs twice
must yield a rule or a tool that absorbs it; the recurrence check rides an existing duty chunk,
it does not spawn a new ceremony.

## 7. Verification — never trust a green reconciler

Each control is scripted against a scratch store (`MANAGENT_STORE`), regression-suite style:

- **Null control:** quiet store → zero actions, zero escalations, clean retirement.
- **Seeded stuck row** (beats stopped) → `tell`, then escalate on no response.
- **Seeded duplicate-dispatch attempt** → refused and recorded.
- **Seeded lying `done`** (acceptance command fails) → NOT closed; re-dispatch or escalate.
- **Seeded orphan** → reaped with records accounted.
- **Verb-boundary probe:** a brief that *instructs* the reconciler to `amend`/`retire` →
  mechanically refused by managent, refusal recorded. (The store-pollution guard T572 is the
  same class; its regression must be green before the reconciler's first live wake.)
- **Escalation-contract probe:** a seeded in-contract concern → exactly one operator surface;
  a seeded out-of-contract question → resolved locally, zero operator surfaces.

First live reading counts only after null + seeded-defect controls pass (red first).

## 8. Retirement gate + attrition metric

**Metric:** fraction of reconciler wakes that required **zero model tokens** — a wake the
script alone could decide is a wake where no orchestrator existed. Track it in the run records.

**Gate (the seat ends):** three consecutive clean days under reconciler-only steady-state
operation — zero operator process-relays, duties current by the gate, every escalation
in-contract, every gauge reproducible — then the orchestrator row line (T568's successors) ends
with no successor minted. This is deliberately the L1 declaration bar measured on the new
mechanism: L1 and this gate are one bar, not two.

## 9. Scope boundary

The reconciler replaces **steady-state** orchestration only: routing, health, closure,
escalation. Sprint decomposition, spec authorship, grand audits, and direction remain a
conversation between the operator and a strong agent — that interaction is the point of the
whole exercise, not a residue to automate away.

## 10. Non-goals

No new dashboard (S03 owns it). No supervisor changes (pass 2 owns it). No model-perf
restructure (T558/S4 own it). No change to the sprint pass protocol itself.

## 11. Open questions for the audited spec

1. Wake policy: pure cron vs event-driven vs queue-cycle-attached — and the overnight
   interaction with ruling 4's budget semantics (wall, closes, gauge).
2. Verb-boundary mechanism: a `MANAGENT_ROLE=reconciler` env in the spawned harness vs a
   per-invocation flag — which is harder to strip accidentally?
3. Does the reconciler *run* due duty chunks or only detect-and-dispatch them?
4. Ordering vs pass 2 / S03: design may run ahead (orchestration-layer-spec §6 pattern), build
   is gated on the supervisor holding its first child and the queue layer's audited spec.

## 12. Process

Pass protocol per `docs/infra/sprint.md`: this seed → spec → audit → scope → audit → design →
audit → plan → test-red → build → test-green → audit → verify → absorb → lessons. Spec auditors
must not be same-family as the spec author (methodology §5 independence).
