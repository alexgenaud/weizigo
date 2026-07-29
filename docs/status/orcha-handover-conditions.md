Author: `Opus/Orcha` · Date: 2026-07-29
Status: **RECOMMENDATION to the human.** Seat allocation is his call.

# Can a cheaper model hold Orcha? Conditions, and what today's evidence actually shows

## The uncomfortable part first

The Orchestrator seat exists to keep the kanban true and the stores absorbed. On
2026-07-29 an **Opus** seat held it, and the two errors that reached the durable
tree were **both the Orchestrator's**, not a worker's:

1. **Accepted half a verification.** Hand-checked six C2 counterexamples, confirmed
   the *truncated* side of each comparison, and silently assumed the *fixpoint*
   side — then promoted three claims to FALSE-AS-SCOPED on that basis.
2. **Saw the tell and mis-read it.** Noticed every counterexample was White-to-move
   and called it "a structural hint" about the median rule. It was a smoking gun for
   a side-keyed bug. `pin_L=142` vs `pin_H=0` was printed in every run, violating
   `AGENTS.md:46`'s own invariant, and went unread.

Meanwhile `DSPro` seats produced the σ-in-arrival fix with an independent
reproduction first, the sampling-bias finding, the adjudication that confirmed the
C1/C2 split, and the exhaustive ADR-0006 test; `Kimi-k3` found the kernel bug that
overturned the Orchestrator's promotion, while checkpointing under context
pressure. **Today's evidence does not show that the expensive seat was better at
the thing the seat is for.** It shows the expensive seat was good at *investigation*
— which the role file now says is not the Orchestrator's work to do inline.

That reframes the question. Orcha does not need a seat that reasons deeply. It
needs a seat that executes a cadence and refuses to skip steps.

## What the seat genuinely requires

| requirement | mechanisable? |
|---|---|
| read the channel, scan the kanban, fix drift, absorb, register, write | **yes** — `sync`, `audit`, `standing` (`ORCHA-AUTOMATION`) |
| know which task is alive | **yes** — `liveness` + heartbeat (`WORKER-CHANNEL`) |
| attribute work correctly | **yes** — `done` refuses an unset agent |
| write briefs that produce good work | **partly** — today's briefs worked because they demanded *reproduce before fixing*, *state your wrong-answer pass rate*, *report the within-budget denominator*. Those are templatable. |
| **decide when a worker's proposed claim change is wrong** | **not fully.** This is the residual judgement, and it is where the seat is load-bearing. |

That last row is the real question, and today gives a direct read on it: `DSPro/2B-PROBE-FIX`
proposed marking `QA-023` FALSIFIED — the error that would have recorded "the state
representation is dead" in the durable tree. But `DSPro/2B-6`, asked the question
squarely, **got it right and overrode its own model-sibling.** So DSPro can make the
call; the risk is not noticing that a call is needed.

**That risk is exactly what a guard fixes rather than a bigger model.** A claim-status
change must name the independent seat that agreed — enforced by `audit`, added to
`ORCHA-AUTOMATION` §6. Under that rule, the Orchestrator cannot promote alone, so the
seat's judgement matters less than its discipline.

## Conditions for handover — in order

1. **`MANAGENT-DERIVE-STATUS`** — status derived, not stored. Until then a gated task
   can be claimed, and the seat must catch it by eye. It bit twice today.
2. **`ORCHA-AUTOMATION`** — `sync`, `audit`, `standing`, attribution enforcement, and
   the two new guards. This converts the cadence from remembered to enforced.
3. **A named second seat for promotions.** Cheap and immediate: no claim status changes
   without citing the agreeing task in the commit.
4. *Desirable, not blocking:* `WORKER-CHANNEL` — replaces judging liveness from `ps`.

`AGENT-IDENTITY` is not a precondition; it makes the ledger honest but the seat runs
without it.

## Recommended shape after handover

- **`DSPro/Orcha`** runs the cadence and owns the kanban.
- **Deep investigation is a registered task**, never inline Orcha work — already the
  rule, and the rule the Opus seat broke all day.
- **Opus or Fable on call as Auditor**, not as a second Orchestrator (*exactly one,
  ever*). The seat that found σ-in-arrival should be dispatched *to a task*, which is
  how its output gets independently checked rather than promoted by its own author.
- **A Dabir seat fronts the conversation** so the human is not the relay.

## The test I would apply

Give `DSPro/Orcha` one turn with a deliberately dirty state — a task done but
unclaimed, a deliverable uncommitted, a gated task showing dispatchable, an unset
`agent`, a stale anchor. All five occurred today. If it finds and fixes them without
being told, it holds the seat. If it reports them instead of fixing them, it has the
same failure the human named this morning, and the cadence needs to be more
mechanical before the handover.
