# DELEGATOR — writing and dispatching a task

A brief succeeds when a competent agent following it cannot reach a wrong answer
believing it is right. A dispatch succeeds when the worker runs detached, the
log lands where the next orchestrator will look, and the mechanical checks pass.

## The header

```
CLAIM:      the CLAIMS.md claim this settles
KIND:       ANALYSIS (parallel, one new file) or MUTATION (serial, cites its analysis)
OWNS:       exact paths — everything else is forbidden
READS:      the minimum
ACCEPTANCE: falsifiable, with numbers
REVIEW:     who dispatches it, and whether work may proceed meanwhile
DISPATCH:   the agent the human assigned this to; if blank, the Orchestrator
            queues it without a target and the agent self-claims
```

The `DISPATCH` line is *advisory*, not *authoritative*: it is the human's
preference, and any agent may still claim the task via
`managent claim <id> --agent <name>`. The pattern is in
`docs/infra/delegation/ROLES.md` §"Dispatching, claiming, and the
kanban" and the schema is in
`docs/infra/managent/spec.md`. **A delegator does not need to specify a
model; if you must, give a reason.**

## The bundle meta line — what `managent` enforces for you

Every bundle opens with `<!--managent set=X deliverables=… [holds=…] [acceptance=…]-->`,
and `managent done` refuses to close while a declared deliverable is missing. That
makes the meta line the only part of a brief a worker cannot skip, so put the
non-negotiables there rather than in prose:

- **The findings file, by exact path** — `findings/<id>-<slug>.json`, not a glob. A
  brief that says "findings to `findings/T2xx-*.json`" in prose gets a task that closes
  without one; T275 did exactly that on 2026-08-02.
- **The context dump, by exact path** — `findings/<id>-context.json`. Asking for it in
  the closing prompt works only if someone remembers to ask; declaring it means the
  dump exists *before* the task can close, and the dump is where two P0 defects came
  from. The shape is specified once, in `DELEGATEE.md` §Reporting.
- **`holds=`** for any single-owner file (`docs/epistemic/CLAIMS.md` above all) — the
  hold conflicts with a second task declaring the same path, which is cheaper than
  discovering the race afterwards.
- **`acceptance=`** whenever a runnable green condition exists. `managent audit` warns
  on every done task that never had one.

Note the gap this does *not* close: the check asks whether the file **exists**, not
whether it is committed — T272 closed `pass` on 2026-08-02 with every deliverable
untracked. T278 owns the fix; until it lands, verify with `git status` yourself before
accepting a close.

## Principles

**Falsifiability.** Name the result that would falsify the claim. If none would,
the test is decoration and the input is wrong. State what a *wrong* answer scores
on your criterion: one that a wrong answer usually passes proves nothing.

**Cost.** Cost the method before specifying it. If you cannot, make costing it the
first deliverable.

**Restraint.** Specify only what changes the outcome, and say why — including
about models. A per-task requirement with a stated reason is legitimate; standing
assignments and the final pick belong to the human. A task that only a huge
context window can hold is a badly scoped brief.

**Model assignment.** The brief does **not** specify a model — a model is assigned at dispatch time, and the model truth is known only there. For a **human-invoked seat** (a claude console, an ad-hoc session) the human invokes the harness and chooses the model. For a **headless worker** the Orchestrator chooses at dispatch — `bin/dispatch <T-id> <model>` — from the canonical set (T317, §Dispatching below), guided by `docs/infra/model-perf.md`. You may *suggest* a model in the `DISPATCH` line or a dispatch note. The agent is told its model at launch and writes the **real** model in the deliverable; the Orchestrator records stats and impressions in `docs/infra/model-perf.md`. (Temporary model preferences — e.g. 'use DeepSeek more right now' — are session memory, not disk rules; they change with billing and the human's call.)

**Independence.** A reviewer must know less than the worker: give the artefact,
the relevant foreclosures, and *find the flaw; assume one exists.* Anything
arguing for the conclusion biases the review. **Instances are not models**
(`ROLES.md` §"Instance vs model"): a fresh instance of the same model is
acceptable for procedural/compliance/calibration review, but for adversarial
review of load-bearing reasoning prefer a **different model** (shared training
→ correlated blind spots); disclose same-model review when unavoidable.

**Visibility.** Work that may run past a minute reports progress and carries a
budget. From outside, silence and progress look identical.

**Concurrency.** ANALYSIS writes exactly one new file and modifies nothing, so any
number may run at once. MUTATION may modify existing files, runs one at a time,
and cites the analysis that recommended it.

**Durability.** Evidence goes to `docs/evidence/<claim-id>/` when it is produced.
A claim whose evidence cannot be retrieved is not proven.

**Prior art.** Name the foreclosure or earlier attempt this task must distinguish
itself from. Foreclosures live in `AGENTS.md`.

**Honest negatives.** A negative result is a deliverable, reported with the same
confidence as a positive one.

## Before dispatching

Ask what a competent agent could get wrong while following this exactly — then fix
that. Apply this file's standards to this file.

## Dispatching a headless worker — the procedure

One command does all of it: `bin/dispatch <T-id> <model>`. It picks the
provider, applies the log convention, detaches, and prints the one data line
(stdout = data):

    dispatched T454 → glm-5.2 (ollama) · pid 61234 · untracked/log/t454.log

Refusals, before anything spawns: a row that is not `dispatchable` (an
in_progress re-dispatch is how the T350/T376/T389 duplicates happened — reopen
a dead row first), a model outside the canonical set, any `claude-*` label, a
task with no single `untracked/T<id>-*.md` bundle, a manager at the delegation
cap. `--dry-run` prints the exact nohup command without spawning;
`--wall=N` overrides the 2700 s default. The worker claims the row itself
(`managent claim <id> --agent <model>` is in the brief), runs under
`tools/runner` (RSS 4 GB, progress watchdog 600 s, wall fallback), and closes
with `managent done`; `bin/subagent` then verifies the work mechanically.

**Models.** Canonical labels are T317's list (`src/managent/main.zig
canonical_models[]`); the tag column is what actually runs:

| label | provider | what runs |
|---|---|---|
| deepseek-v4-pro | deepseek | `pi --provider deepseek --model deepseek-v4-pro -p …` |
| deepseek-v4-flash | deepseek | `pi --provider deepseek --model deepseek-v4-flash -p …` |
| glm-5.2 | ollama | `ollama launch pi --model glm-5.2:cloud -y -- -p …` |
| minimax-m3 | ollama | `ollama launch pi --model minimax-m3:cloud -y -- -p …` |
| kimi-k2.7 | ollama | `ollama launch pi --model kimi-k2.7-code:cloud -y -- -p …` |
| qwen3.8:27b-mlx | ollama | `ollama launch pi --model qwen3.8:27b-mlx -y -- -p …` |
| claude-opus-5 / -sonnet-5 / -fable-5 / -haiku-4-5-20251001 | claude seat | `claude -p …` from a claude console; never dispatched headless |

**The harness rule, plainly.** Every headless harness takes the brief as
`-p '<brief>'`. Whether `--` must precede it depends on who else parses flags:

- **deepseek** — `pi --provider deepseek --model deepseek-v4-flash -p '…'`.
  No `--`: `-p` is pi's own flag.
- **ollama** — `ollama launch pi --model glm-5.2:cloud -y -- -p '…'`.
  `--` REQUIRED: it ends `ollama launch`'s flag parse so `-p` reaches pi, not
  ollama launch. Drop it and pi never sees the brief.
- **claude** — `claude -p '…'`. No `--`.

`bin/subagent` and `bin/dispatch` build these for you; you normally see the
raw forms only in the log's `[runner] argv =` echo, which is the ground truth
of what ran.

**Detaching and logs.** `bin/dispatch` backgrounds the worker with the nohup
convention: stdout+stderr into `untracked/log/t<id>.log` (lowercase id —
`t454.log`, never `T454.log`; older files used `t<id>-dispatch.log`), detached
from your console. All diagnostics land in that log, not your terminal.

**Choosing a wall.** `--wall` is `tools/runner`'s *fallback* ceiling for
silent children; the 600 s progress watchdog catches stuck runs first, so err
high — a killed run wastes more than an idle guard. Observed practice:

| wall | when | observed on |
|---|---|---|
| 1800 (30 min) | tiny bounded edit | T469 |
| 2700 (45 min) | standard task — the mode | T451-T454, T458, T463, T470, T472, T475, T476 |
| 3600 (1 h) | mid task, tooling + regression | T443/T444/T450/T455/T457/T459-T462/T471 |
| 4500-5400 (75-90 min) | analysis- or audit-heavy | T442/T446/T448/T456/T464-T466/T468 |
| 7200 (2 h) | audits, suite runs | T369, T467 |

This is judgement, not a rule — the wall is a backstop, and the backstop's
job is to be generous.

**How to check whether it worked** (every step mechanical):

1. `bin/dispatch` printed the data line with the pid and log path.
2. Within seconds the worker claims: `bin/managent status` shows the row
   `in_progress` (it left `dispatchable`).
3. `bin/managent liveness T<id>` shows heartbeats once `tools/runner` is
   emitting. A fresh claim may read UNKNOWN for the first minutes — absence
   of a heartbeat is absence of instrumentation, not proof of death (D054).
4. `tail -f untracked/log/t<id>.log`: `[runner] argv` (exact command), the
   guards, the worker's `NONCE-…` echo, and at the end
   `[verify] worker reported success; side effects verified — verification
   PASSED`.
5. The row reaches `done` with a verdict.

**What dispatch verification proves and what it does not** (T411):

- Proves, mechanically, after the worker returns: the worker echoed the
  injected nonce (it read the prompt), every declared deliverable exists, and
  the row left `dispatchable` (claim → done happened). A per-model ledger
  line is recorded in `docs/infra/model-perf.md`. The worker's text is
  trusted in neither direction.
- Does **not** prove the work is *correct* — a pass is "believing the work,
  not the text"; the auditor/reviewer owns correctness (verify-then-promote).
- A log ending in `[verify] verification FAILED: …` names the failing check
  (nonce / deliverables / kanban row) — read that, not the worker's closing
  words. A row archived mid-run fails with "task not found" (T466): that is
  a kanban event, not a worker lie. A worker that reports blocked/abandoned
  may legitimately produce no deliverables and still verify — the work is
  believed, the verdict recorded.

Roles, naming, capability vocabulary, concurrency: `ROLES.md`.
