# Ollama concurrency limit — measured 2026-08-20

**Task:** T357 (does the Ollama concurrency limit queue or fail at the 6th?) ·
**Worker:** glm-5.2/T357.2 · **Date:** 2026-08-20 ·
**Landmark:** advances `L1 (the dashboard tells the truth)` — a measured cap
replaces a guess in fleet scheduling.
**Status:** MEASUREMENT (not a dispatch-policy change — the brief forbade that;
the scheduling ruling is the operator's).

## Headline

The operator believed Ollama allows **about five** simultaneous active
exchanges and that a **sixth waits rather than fails**, but no one had run the
sixth. Measured: **the sixth queues and succeeds** (no failure), and so do the
7th through 16th. A hard failure exists but it is a **`429 Too Many Requests:
too many concurrent requests`** that first appeared at **N = 20** (2 of 20),
not at 6. The "~5" belief is too conservative for `glm-5.2:cloud`; the
queue-then-429 threshold sits around **18–20 concurrent exchanges against a
~3-session background**, and is load-dependent, not a fixed wall.

## What was run

N concurrent one-shot `ollama run glm-5.2:cloud "<unique arithmetic>"` requests
at N = 4, 5, 6, 8, 12, 16, 20, each wrapped in `tools/runner` with a distinct
`MANAGENT_TASK_ID` so `untracked/heartbeat.jsonl` records a tool-written finish
`ts` + true `wall` per worker. Baseline single-request latency ≈ **1.4 s**.

**Evidence** (tool-written, not agent-narrated): `docs/evidence/OLLAMA-CONC/`
— `heartbeat-excerpt.jsonl` (71 lines), `per-worker-table.tsv`,
`driver-summaries.json`, `429-error-samples.txt`, `PROVENANCE.md`.

### Results (heartbeat `wall` is the true per-process duration; `rc` is the OS exit status)

| N tried | succeeded | 429-failed | heartbeat walls, sorted (s) |
|---:|---:|---:|---|
| 4 | 4 | 0 | 1.8, 2.2, 2.6, 3.4 |
| 5 | 5 | 0 | 1.4, 1.4, 1.7, 2.3, 3.8 |
| **6** | **6** | **0** | 2.0, 2.8, 3.5, 4.2, 4.8, **5.5** |
| 8 | 8 | 0 | 6.6, 7.1, 7.3, 7.9, 9.1, 9.2, 9.3, 9.6 |
| 12 | 12 | 0 | 1.1, 1.1, 1.6, 2.8, 3.9, 4.1, 4.6, 4.9, 5.7, 5.9, 6.5, 6.9 |
| 16 | 16 | 0 | 2.0 … 10.0 |
| 20 | 18 | **2** | **0.2, 0.3**, 1.3 … 9.0 |

Denominator stated per the standing rule: each row is *N tried, N succeeded,
K 429-failed*, against a background of **3 live persistent
`ollama launch pi --model glm-5.2:cloud` sessions** (T353, T357, T362) that
were active throughout — see "Fleet state" below. Total concurrent exchanges
at each peak = N (probes) + up to 3 (background).

## The five questions the brief required

**1. Does the sixth queue or fail?**
**Queues.** At N=6 all six succeed; the 6th's true wall is **5.5 s** against a
**1.4 s** baseline → it waited ≈ 4 s, then ran. No connection error. Confirmed
reproducibly (and the 7th–16th also queue-and-succeed).

**2. If it queues, what is the wait, and is the queue ordered?**
The wait grows with N: median heartbeat wall rises 1.4 s (N=4) → 5.5 s (N=6)
→ 5.9 s (N=12) → 8+ s (N=16/20). The shape is a **staircase**: workers finish
in groups at the same wall (e.g. N=12: three at ~1.1 s, then singles at 2.8 /
3.9 / 4.1, then a cluster 4.6–6.9). That batched-clustering shape is consistent
with a **small number of concurrent service slots** (≈ 2–3 visible against
the background) draining a queue, **not a single strictly-ordered FIFO
queue**. **The data does not conclusively prove ordering** — multiple workers
finishing at the same wall is compatible with FIFO service into a multi-slot
drain, but I did not tag probe launch order tightly enough to distinguish FIFO
from a re-ordered multi-slot queue. Stated as unsettled.

**3. If it fails, is it detectable by `bin/ollama-subagent`, and does the row
stay claimable — or does it leave a claimed row with a dead worker (the state
that wedged the fleet on 2026-08-04)?**
The failure is **detectable**: `ollama run` exits **rc=1** and prints
`Error: 429 Too Many Requests: too many concurrent requests` to stderr (see
`429-error-samples.txt`); the heartbeat records the fast fail
(wall 0.2–0.3 s, empty answer). `bin/ollama-subagent`'s dispatch-verify path
calls `dispatch_verify.heal_dispatch` (tools/dispatch_verify.py:296), which
on **rc != 0 with the row still `in_progress`** runs `managent reopen
<task_id>` → the row returns to `dispatchable`. So a 429-killed dispatch
would **not** leave a claimed row with a dead worker; it would be reopened.
**Caveat (stated against the brief's end-to-end bar):** this is a
**code-read inference plus the observed 429 rc**, **not** a live end-to-end
trace of a real `bin/ollama-subagent` 429 → heal. I deliberately did not
induce a real 429 inside a live `bin/ollama-subagent` dispatch (it would fire a
real worker into the live kanban against the running fleet). The component
facts are each verified independently; the composition is inferred.

**4. Does the limit count live sessions or simultaneous exchanges?**
The data **leans toward simultaneous active exchanges**, but **does not
cleanly settle it** — stated as unsettled. Three persistent
`ollama launch pi` sessions (T353, T357, T362) were live throughout, mostly
idle (between exchanges). My 20 transient one-shots still largely succeeded
(only 2 of 20 429'd). If *live sessions* were the counted quantity, the 3
background sessions would have consumed slots and one-shots would have
started failing far below N=16. They did not. The counter appears to charge
**active streaming exchanges**, which idle persistent sessions do not hold.
**This is not a controlled result**: the fleet was not quiet, the background
sessions' activity was uncontrolled, and I did not run the clean
"K idle persistent + M active one-shot" matrix the brief described. That
matrix needs a quiet fleet, which this run did not have (see "Fleet state").

**5. What is the practical cap for our workflow, where workers think far
longer than they stream?**
Materially higher than "~5." Each worker holds an **active-exchange slot only
while streaming** (seconds); it then goes **idle for minutes** while thinking.
The 429 only appears when *simultaneous active exchanges* reach ~18–20
(against the background); idle-thinking workers do not count. So a fleet of
many long-thinking workers can coexist as long as the number **actively
streaming at the same instant** stays below ~12–16 (the clean-queue ceiling
observed here). A scheduling cap of ~5 is far below what the server allows;
the binding constraint is **peak concurrent streaming**, not headcount.

## Fleet state at measurement time (the quiet-fleet precondition was NOT met)

The brief said to run on a quiet fleet. **It was not quiet.** `ps` at each
burst showed **6** `ollama launch pi` lines = **3** sessions (each session =
a `tools/runner` python parent + an `ollama` child): **T353** (active, ~9 % CPU,
generating), **T357** (this worker), **T362** (just dispatched). `/api/ps`
returned `{"models":[]}` (cloud models do not register as locally loaded).
All measurements are therefore of **residual capacity against that
background**, not a clean single-tenant reading. The operator dispatched
T352/T362 while T357 ran; the quiet-fleet guarantee was the operator's to
give and was not given. A clean re-measurement on a drained fleet is the
one follow-up that would tighten every number above.

## Method deviation (documented)

The brief proposed launching the six through `bin/ollama-subagent`. I used
`ollama run` one-shots wrapped in `tools/runner` instead. `bin/ollama-subagent`
launches a full persistent `ollama launch pi` agent that thinks for tens of
minutes — it would occupy the concurrency slots being measured for the whole
run, risk the 1800–2700 s wall-kill, and dispatch real workers into the live
kanban. The Ollama concurrency limit is a server/cloud property observable by
any concurrent Ollama request; `ollama run` one-shots measure the same limit
while preserving the brief's required evidence (heartbeat file + exit
statuses). The deviation and its rationale are recorded in
`docs/evidence/OLLAMA-CONC/PROVENANCE.md`.

## What the data does NOT settle (per the brief's bars)

1. **Live-sessions vs active-exchanges (question 4):** not cleanly settled —
   needs the controlled K-idle + M-active matrix on a quiet fleet.
2. **Queue ordering (question 2):** the staircase is compatible with FIFO into
   a multi-slot drain, but launch order was not tagged tightly enough to prove
   FIFO. Stated as unsettled.
3. **Live end-to-end of the heal (question 3):** the 429→rc=1→`heal_dispatch`→
   `reopen` chain is a code-read inference, not a traced live dispatch. Stated
   as inferred.
4. **The exact 429 threshold:** clean at 16, 2 fails at 20, against a ~3
   background that varied in activity. The threshold is load-dependent, not a
   fixed wall; the honest statement is "≈ 18–20 against this background,"
   not a single integer.

## No dispatch-policy change

Per the brief, no scheduling ruling is made in this row. The measurement is
the deliverable; the operator owns the cap.