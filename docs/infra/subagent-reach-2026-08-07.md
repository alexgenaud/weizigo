# Subagent reach from a DeepSeek parent — measured 2026-08-07 (T408)

> **CORRECTED 2026-08-07 (operator ruling).** This doc's original wording said
> "If a ceiling exists it sits above 6 and was not hit." That sentence was
> false and is retracted here. **Ollama imposes a cap at five simultaneous
> agents.** The 6-concurrent probe below did not observe an effect, but it used
> trivial warm round-trips (~9 s total) and **could not have detected a
> transfer-session cap** — absence of an observed effect is not evidence of
> absence of the cap. The binding operational constraint remains
> max-two-concurrent per parent. (The measurement record below is unchanged;
> only the interpretation is corrected. Findings file
> `findings/T408-subagent-reach.json` is untouched — T408's own wording was
> careful and accurate; the overstatement was the Orchestrator's, corrected
> in `docs/infra/managent/tasks.json` amendment 2026-08-07T11:09:40Z.)

**Executor:** deepseek-v4-flash/T409 (sprint console, acting as the DeepSeek parent under test) ·
**Date:** 2026-08-07 · **Row:** T408 (set G) · **Deliverable:** this doc + `findings/T408-subagent-reach.json`

**Why the console ran this row itself rather than subdelegating it:** the tool under test is
`bin/ollama-subagent`, which **refuses at depth ≥ 2** — and every `bin/subagent`-dispatched worker
runs at depth 2 by construction. A subdelegated worker cannot even invoke the tool this row
measures. T408's subject is the depth-1 DeepSeek parent's own reach, so the console *is* the only
faithful executor. Subdelegation decision recorded per sprint doctrine (deviation from "you do not
do the rows' work" is structural, not preference).

**Bottom line for a sprint console:** all three Ollama targets — **kimi-k2.7, glm-5.2, minimax-m3** —
are reachable from a DeepSeek parent via `bin/ollama-subagent`. Round-trip correctness 3/3. Kanban
interaction (claim/ping/done against a scratch store) works on all three (kimi needed one retry).
Concurrency through **6 simultaneous workers** completed with zero errors or hangs — the recorded
"five-agent ceiling" is **not observed** as a tool-level cap (caveat: the probe ran trivial warm
round-trips in ~9 s and could not have detected a transfer-session cap — see the correction banner;
**the cap exists at five**). The depth cap is enforced loudly on
both guarded wrappers, and the unguarded `ollama launch pi` second hop remains live (depth travels
by env, verified at 2). **A sprint may delegate to Ollama models**; keep the documented
max-two-concurrent convention per parent.

## Decision table — what a sprint console needs

| target (tag) | reachable from DS parent | round-trip correct | can claim/ping/done | safe concurrent count | recommended use |
|---|---|---|---|---|---|
| **kimi-k2.7** (`kimi-k2.7-code:cloud`) | YES — exit 0, 5.2 s, reply `+1` | YES (1/1) | YES — but flaky first try (1/2 attempts) | ≤5 (operator ruling); probe through 6 could not detect a transfer-session cap | leaf rows, read-heavy; **re-check output on multi-step shell bundles**; expect occasional instruction-following lapse |
| **glm-5.2** (`glm-5.2:cloud`) | YES — exit 0, 11.1 s, reply `+1` | YES (1/1) | YES (1/1) | ≤5 (operator ruling); probe through 6 could not detect a transfer-session cap | leaf rows incl. kanban-interactive ones; cheapest dependable all-rounder |
| **minimax-m3** (`minimax-m3:cloud`) | YES — exit 0, 124.2 s cold, reply `+1` | YES (1/1) | YES (1/1) | ≤5 (operator ruling); probe through 6 could not detect a transfer-session cap | leaf rows; **budget ~2 min cold start** before the 5-min timebox bites; fine once warm (9–74 s) |

Operational notes, not "works":
- **Kimi needs the `-code` tag.** `ollama show kimi-k2.7:cloud` → NOT FOUND; `kimi-k2.7-code:cloud`
  resolves. `bin/ollama-subagent`'s tag→canonical mapping handles this; a console must not guess.
- **minimax cold start is 25× the others** (124 s vs 5–11 s). Any probe timebox must count it.
- **Kimi's first kanban attempt did nothing.** Probe bundle asked for four `bin/managent` commands;
  attempt 1 replied `OK.` without running any (row stayed dispatchable). Attempt 2 (retry) executed
  all four verbatim. Retry count reported per brief — do not retry-until-green silently.

## Measurements

### 1. Reach + round trip (3/3 correct)

Identical trivial bundle (`docs/evidence/RESCUED-tmp-2026-08-08/t408/roundtrip.md`): *"Read `docs/epistemic/PROGRESS.md`.
Reply with ONLY the 4×4 root value from the gate-chain table in section 4.2."* Expected answer: `+1`
(the 4×4 `root` column, basic-ko tie-area table, PROGRESS.md §4.2). One probe proves reach + file
access + instruction-following in a single dispatch.

Command shape (per target): `bin/ollama-subagent docs/evidence/RESCUED-tmp-2026-08-08/t408/roundtrip.md --model <tag> --wall=300`
wrapped in `tools/runner` (rss 4 GB, progress-timeout 600 s, wall 300 s). All via the guarded path;
`bin/ollama-subagent` is the correct entry point for every dispatch here because the bundle was a
bare file target (no kanban row) — `bin/subagent` is the DeepSeek-only sibling and cannot reach
Ollama models at all.

| target | exit | wall | reply (verbatim, full) | verdict |
|---|---|---|---|---|
| kimi-k2.7-code:cloud | 0 | 5.2 s | `+1` | correct |
| glm-5.2:cloud | 0 | 11.1 s | `+1` | correct |
| minimax-m3:cloud | 0 | 124.2 s | `+1` | correct |

Run logs: `/tmp/weizigo/t408/runs/{kimi,glm,minimax}-roundtrip.log` (disposable; evidence quoted
here and in the findings file).

### 2. Kanban interaction against a scratch store (3/3 after retries)

Scratch store `docs/evidence/RESCUED-tmp-2026-08-08/t408-scratch.json` (`MANAGENT_STORE` override; the live kanban was never
a target — see Safety). One pre-registered dispatchable row per model (T902 glm, T903 kimi,
T904 minimax, model pre-stamped via `add --model`). Probe bundle: claim (no `--agent`, inherits
stamped model) → `sleep 12` → ping → done (no `--agent`, `--status pass`, note with an embedded
`"`). The 12 s sleep satisfies the T390 claim-at-close gate (10 s minimum).

| target | attempts | result | store state after |
|---|---|---|---|
| glm-5.2 (T902) | 1 | all four commands executed, outputs verbatim | done / pass / agent glm-5.2 / note round-tripped |
| minimax-m3 (T904) | 1 | all four commands executed, outputs verbatim | done / pass / agent minimax-m3 / note round-tripped |
| kimi-k2.7 (T903) | 2 | **attempt 1: replied `OK.`, ran nothing** (row stayed dispatchable) · attempt 2: all four commands executed | done / pass / agent kimi-k2.7 / note round-tripped |

The quoted `--note` (`t408 probe done with "quote" inside` and variants) round-tripped
byte-exact through the store on every row — the T399 JSON-escaping fix (7558775) is verified on the
write paths this sprint relies on (`done --note`). `add --note` is documented in `managent help`
but ignored by `cmdAdd` (note stored null) — a doc/impl mismatch, reported for the record, not this
row's scope.

Heartbeats (`ping --note`) landed under each scratch task ID, and the runner heartbeat for each
dispatch landed under `MANAGENT_TASK_ID=T408`.

### 3. Concurrency — 5 then 6 simultaneous workers

Round-trip bundle, mixed fleet. All sessions `exit 0`, reply `+1`.

- **5 concurrent** (glm×2, kimi×2, minimax×1): **5/5 completed**, total wall 83 s (per-run
  60.0–83.5 s). No queue error, no refusal, no hang.
- **6 concurrent** (glm×2, kimi×2, minimax×2): **6/6 completed**, total wall 9 s (sessions warm).
  No queue error, no refusal, no hang.

The recorded belief of a "five-agent ceiling on the Ollama pool only" was **not observed as a
tool-level cap through 6**: nothing queued, errored, or hung. **Corrected 2026-08-07 per operator
ruling — there IS a five-agent cap.** That probe used trivial warm round-trips (~9 s total) and
could not have detected a transfer-session cap; absence of an observed effect is not evidence of
absence of the cap. We may reasonably choose not to work around it while no negative side effect
appears; we must not claim there is no cap. The project's own max-two-concurrent dispatch
convention is the binding constraint for this sprint regardless. First 5-concurrent attempt is
reported honestly: a bash 3.2
`declare -A` failure silently collapsed all five slots to minimax-m3 (5/5 still completed); the
mixed run above is the corrected retry.

### 4. Depth — second hop permitted via the unguarded path only

Probe: `bin/ollama-subagent` stamps the child at depth 2. The child then attempts each dispatch
edge:

| edge | result |
|---|---|
| child → `bin/subagent` (with proper task argument) | **REFUSED** — exit 1, `subagent: REFUSED — you are a worker (depth 2)` |
| child → `bin/ollama-subagent` | **REFUSED** — exit 1, `ollama-subagent: REFUSED — you are a worker (depth 2)` |
| child → `ollama launch pi` (unguarded) | **PERMITTED** — grandchild launched and replied |

Grandchild (`gpt-oss:120b-cloud`) reported its own `WEIZIGO_AGENT_DEPTH` as **2** — the stamp
travels by env inheritance, unchanged (matches the T320/T321 documented mechanism). This **refutes
the first child's summary claim that the second hop "resets to depth 0"**; the corrected probe
(second dispatch) is the one recorded. The depth cap stops accidental recursion through the
project's wrappers; it is not a security boundary, unchanged by any 2026-08-06/07 tool changes.

Probe-quality note, reported per brief: depth attempt 1 ran `bin/subagent --dry-run --dsflash`
**without a task argument**, which exits 1 for missing arguments, not for the depth cap — the exact
T320 mis-attribution T321 corrected. The console re-ran the deterministic path with proper
arguments (both wrappers at `WEIZIGO_AGENT_DEPTH=2` → REFUSED, exit 1) and dispatched the corrected
bundle (grandchild depth echo) before recording the finding.

## Safety — the live kanban was not touched

`git status` on `docs/infra/managent/tasks.json` after all probes: the only diffs are (a) the
T409 claim made by this console at session start (required) and (b) Orcha's T405 amendment
(08:47:43Z, predates this session). No probe row, no scratch write reached the live store. All
`managent` exercises ran under `MANAGENT_STORE=docs/evidence/RESCUED-tmp-2026-08-08/t408-scratch.json`.

## What this means for the sprint (T409's staffing decision)

- **T407 and T406 may be staffed with Ollama workers**, per the operator's option, or with
  Flash/Pro — both paths are now validated end-to-end from this parent.
- Per-model guidance above applies (kimi: verify multi-step output; minimax: budget cold start;
  glm: dependable default).
- The depth cap works as documented on both wrappers; nothing in the 2026-08-06/07 tool changes
  broke reach, kanban, concurrency, or depth behaviour.

**Landmark:** advances `L4 (the ledger is clean)` and fleet capacity — the delegation tooling is
now measured, not believed. All negative findings are stated as loudly as the positive ones; no
retry-until-green was performed (kimi's retry and the two corrected probes are each disclosed with
their counts).

— deepseek-v4-flash/T409
