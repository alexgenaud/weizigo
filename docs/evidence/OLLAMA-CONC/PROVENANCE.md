# OLLAMA-CONC — provenance for the Ollama concurrency measurement

**Task:** T357 (does the Ollama concurrency limit queue or fail at the 6th?)
**Worker:** glm-5.2/T357.2 · **Date:** 2026-08-20 · **Landmark:** L1 (the dashboard tells the truth)

## What was measured

The Ollama concurrency limit for `glm-5.2:cloud` (the model the live fleet runs),
probed by firing N concurrent one-shot `ollama run glm-5.2:cloud "<arithmetic>"`
requests at N = 4, 5, 6, 8, 12, 16, 20. Each request was wrapped in
`tools/runner` with a distinct `MANAGENT_TASK_ID=T357-w<id>-<label>` so that
`untracked/heartbeat.jsonl` records a tool-written finish timestamp + true wall
per worker. Per-request arithmetic was unique (answer not in the prompt), one
line expected.

## Why not `bin/ollama-subagent` as the brief proposed

The brief proposed launching the six through `bin/ollama-subagent`. That path
launches a full persistent `ollama launch pi` agent that thinks for tens of
minutes, would occupy the very concurrency slots being measured for the whole
run, risks the 1800–2700 s wall-kill, and would have dispatched real workers
into the live kanban (clobber risk). The Ollama concurrency limit is a
property of the Ollama server / cloud endpoint observable by **any** concurrent
Ollama request. `ollama run` one-shots wrapped in `tools/runner` measure the
same limit while preserving the brief's required evidence — the **heartbeat
file and exit statuses**, tool-written, not agent-narrated. The deviation is
documented here and in the report.

## Fleet state at measurement time (a caveat — the fleet was NOT quiet)

The brief required a quiet fleet. It was not: throughout the run, **three**
live `ollama launch pi --model glm-5.2:cloud` sessions were active (T353,
T357=this worker, T362 — see the pre-snapshots in `driver-summaries.json`,
`*.pre.ollama_launch_pi_procs` = 6, counting both the python runner and the
`ollama` child per session). The probes therefore measured the **residual**
capacity against a background of ~3 persistent sessions, some of which were
actively generating (T353 at ~9 % CPU). The total concurrent Ollama exchanges
at the peak of each burst was N (probes) + up to 3 (background).

## Files

- `heartbeat-excerpt.jsonl` — the 71 tool-written heartbeat lines for every
  probe worker (identifier `T357-w*-*`). Each line carries the finish `ts` and
  the true per-process `wall`. This is the primary evidence.
- `per-worker-table.tsv` — heartbeat wall joined with the driver's OS exit
  status (`rc`), `429` flag, and answer, one row per probe worker.
- `driver-summaries.json` — per-N driver summaries incl. fleet pre/post
  snapshots and the driver's own (sequentially-waited, hence inflated) walls.
- `429-error-samples.txt` — the two `Error: 429 Too Many Requests: too many
  concurrent requests` stderr lines captured at N=20.

## How to reproduce

```sh
python3 /tmp/weizigo/T357-driver.py <N> <label>   # driver (disposable; see T357 report)
```

The driver lives at `/tmp/weizigo/T357-driver.py` (disposable scratch — the
heartbeat excerpt and this PROVENANCE are the durable record). To reproduce
without the driver, the equivalent one-liner per worker is:

```sh
MANAGENT_TASK_ID=T357-wN-label tools/runner --max-wall 120 -- \
  ollama run glm-5.2:cloud "Reply with exactly one line containing only the integer product of A and B. Do not show reasoning."
```