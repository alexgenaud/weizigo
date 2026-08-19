# fleet-monitoring — when argus runs, and what heals itself

**Row:** T470 (when should argus run, and what should heal itself?) · **Author:** glm-5.2/T470
**Date:** 2026-08-19 · **Landmark:** advances `L1 (the dashboard tells the truth)`.
**Scope:** this is the *policy* — one page, the decision. The *implementation* of the surface
(`untracked/watch-fleet.sh`, four sections) and the regression controls live in
`docs/infra/fleet-surface.md` (T466/T469). This file does not duplicate that; it states the rule.

---

## Q1 — when should `bin/argus --mode doctor` run?

**Decision: not on a clock, not as a daemon. One serial pass, operator-invoked, on three
cheap triggers; the deep checks carry a load gate so monitoring never adds the load it watches.**

The hard version asks whether a monitor is worth more when load is light (cheap, nothing wrong)
or heavy (expensive, exactly when something thrashes). The repo's own record answers it: **every
failure we actually suffered was a heavy-load event, invisible until someone looked** —

- 2026-08-08: five test binaries at 100 % CPU, load 16, suite never finishing; the 35–52 min
  readings were load contamination, truth is 810.9 s (`docs/infra/suite-truth.md`).
- 2026-08-18: those contaminated readings were only corrected by re-running on a quiet machine.
- 2026-08-19: a race lane RSS-killed at 4121 MB against the 4096 MB cap; three consoles killed
  at their wall guards with uncommitted work in the tree.

So the monitor is *most valuable under heavy load* — but running it *more often* under heavy
load is backwards on cost: a watcher competing with the work it watches is the shape that
panicked this host on 2026-07-29 (`docs/infra/host/incident-2026-07-29.md` — load-induced,
watchdog starved 91 s). The operator's constraints are requirements, not preferences:
monitoring + background work must stay under 50 % of the machine, and he is not comfortable
with many asynchronous processes — one serial loop, not several watchers.

Resolution, and it is a **two-tier** answer:

1. **The cheap line stays always-on and serial.** `untracked/watch-fleet.sh` is one process
   doing `ps` + `managent status` — sub-second, trivially under the 50 % ceiling. This is the
   surface the operator actually watches; it satisfies "one serial loop" by construction.
2. **`argus --mode doctor` runs on triggers, not a timer.** Measured: a full doctor pass is
   **1.06 s real, 0.47 s user** on this host — cheap and read-only (it writes only to
   `untracked/`). But its deep arms (claimlint ×3, git status, artifact loading) are the part
   that could add load exactly when load is the problem, so it fires only when a cheap signal
   says something is wrong: a dead lane appears in CONCERNS, an unowned high-CPU process shows,
   or load crosses a threshold. The surface's alarm lines *are* the trigger surface; the
   operator also keeps his manual weekly run.
3. **A load gate inside doctor.** If the machine is already busy, the expensive arms yield or
   jitter; monitoring must never be the straw that panics the host. Doctor is a step of the
   same serial loop, not a concurrent watcher — so there is still only one always-on process.

A defended **no-daemon** ruling: a second always-on process is rejected because (a) the operator
does not want one, and (b) a timer-driven doctor under heavy load is the precise shape that
caused the 2026-07-29 panic. One serial loop with trigger-gated deep checks does the job and
cannot logjam higher-priority work.

## Q2 — what should heal itself, and what must never?

**Decision: exactly one automatic action — reopen a claimed task that is provably dead — and
everything else stays manual, including anything that touches a worker's uncommitted work.**

The one action: a row `in_progress`, claimed > 15 min, with **no heartbeat AND no matching live
process**, is reopened to `dispatchable` after an assertion records why. Lives behind
`WATCH_FLEET_HEAL=1`, default off. The gate is the load-bearing part, and the repo gives a
**live counterexample right now** that proves the gate is necessary: T450 shows `beats stopped
102m ago` in `managent liveness`, yet `ps` shows its runner (pid 44039) alive — "no heartbeat"
means "no `MANAGENT_TASK_ID`", not "dead console" (`bin/argus:828-829` says so itself). Reopen on
heartbeat alone would reopen a live task. So the trigger requires **both** signals agree:
no heartbeat *and* no process matching `Follow untracked/<id>-` in `ps -axww` (not `pgrep -f`,
which silently misses processes on macOS — `docs/infra/fleet-surface.md` §5).

| | trigger | action | assertion written | control it fires | control it does NOT fire wrongly |
|---|---|---|---|---|---|
| **reopen dead claim** | `in_progress`, claimed > 15 min, no heartbeat **and** no live process | `managent assert <id> dispatchable --note "auto-reopen: no process after <dur>"` then `managent reopen <id>` | the `assert` line above | `tools/regression-watch-fleet.sh` arm C: scratch store + processless old claim + `WATCH_FLEET_HEAL=1` → row dispatchable, scratch ledger holds the assertion | arm D: a live process (even with no heartbeat — the T450/T466 shape) → untouched; a fresh claim (< 15 min) → untouched; a `done`/`dispatchable` row → untouched (`reopen` refuses those statuses anyway) |

**What must NOT self-heal — and why:**

- **Killing orphans or any process.** A kill without a human is the class of action that
  destroyed a worker's run on 2026-08-18 (T443). The runner's own guards do hard kills
  *inside* guarded runs; the monitor does not kill anything it did not start.
- **Discarding uncommitted tree edits, deleting artifacts, or force-closing consoles.** On
  2026-08-19 three consoles were killed at their wall guards with real edits in the tree; an
  over-eager cleaner would have destroyed them. Anything that mutates `data/`, `artifacts/`,
  the working tree, or a `.wzo` is permanently off the self-heal list (AGENTS.md: "No silent
  writes to `data/` or `artifacts/`").
- **Auto-absorbing findings, auto-closing rows, auto-running doctor.** Absorption and close are
  Orchestrator/human decisions; auto-doctor is rejected in Q1.

The standing warning is the one the brief names: **an over-eager cleaner is the failure mode
this repo has already lived.** The heal set is one action, opt-in, double-gated, and asserts
before it acts — exactly the smallest set worth having, and no more.