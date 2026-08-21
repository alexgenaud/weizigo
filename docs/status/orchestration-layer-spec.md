# Orchestration layer — spec sketch (discussion; not ratified)

**Status:** DISCUSSION SKETCH · **Owner:** deepseek-v4-pro/T557 · **Date:** 2026-08-21 · **Sits on:**
pass 2 (`docs/epics/E1-markovian/L1-dashboard/S01-process-ownership/pass2/spec.md`).

Goal in one line: **queue a task once; the fleet dispatches it when conditions clear; the dashboard
tells the truth; the operator steers spec/verification/direction and never relays.**

## 1. Ownership — the model

A running task is **owned**: a supervisor holds the child's handle and observes its death directly
(`waitpid`), and reaps its tree with `treekill`. Nothing scans `ps` or polls the kanban to re-derive who
owns what. The inference window (between spawn and observation) is the root cause of every orphan,
duplicate dispatch, and misattribution this month; held ownership closes it by construction.

## 2. Supervision — `managent supervise <id> <model>` (pass 2)

The held-handle supervisor. Contract already spec'd in pass 2: six HOLD assertions (no-detach, direct
waitpid death observation, treekill containment, foreground, single-instance, single-writer). Not
re-spec'd here — this is the foundation the rest sits on, and the queue/dashboard are inert without it.

## 3. Queue — the scheduler (the "wise agent")

One loop, long-lived (or triggered). Each cycle:

1. Read **dispatchable** rows.
2. Evaluate **conditions** — all must hold:
   - **holds clear** — no writer conflict on the row's files;
   - **needs satisfied** — its dependencies are done;
   - **appetite permits** — methodology §1 (Claude CONSERVE, Fable RESERVED, DS SPEND, local PROBE);
   - **fleet quiet** — load/memory below floor, host guard not firing;
   - **discharge known** — it has an acceptance command (done is gate-able).
3. Pick **one** (ordering: roadmap priority, then FIFO).
4. Dispatch `managent supervise <id> <model>` — model and harness both from the **data table**, never
   code.
5. On child death: reap (`treekill`), write the run record with reap fields, then **re-dispatch or
   record-fail** per policy (backoff, escalate after N).

**Discharge condition:** a row is done only when its acceptance command exits 0 **and** its deliverables
are committed **and** its verdict is recorded. Done is the only success; everything else is re-dispatch
or escalation — a queue that reports success while doing nothing is the named recurring defect.

**Overnight semantics:** a run budget (stop after N closes, like the duty counter), a wall ceiling, and a
"stop if any dashboard gauge crosses X" — so an unattended night terminates cleanly and reports.

## 4. Dashboard — the truth

Gauges, each **reproducible by the command the doc names** (L1's bar): dispatchable / in_progress / done
counts, per-task liveness (heartbeat age), fleet load + host memory, claimlint floor, last-close latency.
No gauge that cannot be re-derived from disk by hand. A gauge that cannot be re-derived is decoration.

## 5. Verification

- **Ownership / supervision:** pass 2's HOLD controls — each assertion has a seeded control.
- **Queue:** seeded — (a) a dispatchable row with holds clear → auto-dispatches; (b) a hold set → does
  NOT dispatch; (c) a failed lane → re-dispatch with backoff, no silent loss; (d) budget exhausted →
  stops and reports. Correctness = "the fleet drains itself and nothing is lost silently."
- **Dashboard:** every gauge re-derived by hand from disk equals the dashboard; the acceptance is the
  "three clean days" bar (zero process-relays).

## 6. Ordering

Pass 2 (supervision) first — the queue and dashboard sit on top and are inert without it. Design the
queue **now**, calmly, ahead of build; build it after pass 2's supervisor holds its first child.
Dashboard polish finishes L1.

## 7. Open rulings for the operator

1. **Ordering** — roadmap-priority, condition-first, or FIFO?
2. **Appetite** — a hard gate (CONSERVE can block a task) or a soft bias (it only deprioritizes)?
3. **One dispatch** — is the model→harness table fully data (a JSON row), or do hardcoded family
   branches remain?
4. **Overnight stop** — budget by closes, by wall, by gauge, or all three?
5. **Pre-ratification** — does the queue ever act on a row the operator hasn't explicitly queued, or is
   everything dispatched by prior intent?
