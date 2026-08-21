# Subdelegation

```sh
bin/subagent --provider deepseek <T-ID> --dspro    # DeepSeek-v4-Pro worker
bin/subagent --provider deepseek <T-ID> --dsflash  # DeepSeek-v4-Flash worker
bin/subagent --provider deepseek <T-ID> --dspro --wall=900   # wall guard, default 1800s
bin/subagent --provider deepseek <T-ID> --dspro --dry-run    # print the command, spawn nothing
bin/subagent --provider deepseek <path.md> --dsflash   # bare dispatch, no kanban lifecycle

bin/subagent --provider ollama <T-ID> --model <tag>    # Ollama worker (guarded path)
bin/subagent --provider ollama <T-ID> --model glm-5.2:cloud --dry-run
bin/subagent --provider claude <T-ID> --model claude-sonnet-5   # headless claude -p (T494)
```

No default model — name one. **Two distinct limits, do not conflate:** (a) the *parallel* count — no fleet cap; ANALYSIS unlimited, MUTATION serial, conflict-free by `holds=` and task-kind per `docs/infra/delegation/ROLES.md` §Concurrency (operator's ruling 2026-08-19: no DeepSeek rate-limit cap); (b) the *recursion* depth — `WEIZIGO_AGENT_DEPTH`/`MAX_DEPTH=3` below stays: it bounds delegation chains so agent → subagent → sub-subagent cannot loop or branch infinitely.

`bin/subagent` is the ONE dispatcher (T437 merged the subagent pair; T527
removed the backward-compat wrappers `bin/ollama-subagent` and
`bin/subagent-ds` on 2026-08-20). The `--provider` flag is REQUIRED — a bare
call is a hard error naming the flag. `--provider deepseek` requires
`DEEPSEEK_API_KEY`; `--provider ollama` dispatches via `ollama launch pi` with
the same depth-cap contract (T321, 2026-08-03) and is the guarded path for
Ollama delegation; `ollama launch pi` itself remains directly callable and
unguarded — see §Reach matrix and §Depth-enforcement ruling below. Claude
seats normally run from the Claude Code harness; `--provider claude` runs a
headless `claude -p` for dispatched rows (T494).

**However, workers can reach beyond DeepSeek through other paths** (T320,
2026-08-03). See §Reach matrix below.

The script resolves the bundle, builds the claim/findings/done wrapper, runs
under `tools/runner`, and stamps `WEIZIGO_AGENT_DEPTH` on the child.

**Depth cap — a bound on recursion, not a ban on delegation** (T431,
2026-08-08). `WEIZIGO_AGENT_DEPTH` increments by one per dispatch and the
dispatch tools refuse at `MAX_DEPTH = 3`. So a human console (depth 1) may
dispatch a manager (2), which may dispatch a leaf (3), and the leaf stops.
The chain terminates; delegation is not banned.

Until T431 the cap stamped *every* child at 2 and refused at 2, so every child
was a leaf. That enforced the principle by making delegation impossible below
the human — and it had a cost that showed up as a process failure, not a
technical one: a sprint console could not dispatch its own phase audits, so it
asked the operator to paste them by hand. The operator became the transport
layer between consoles, which is both slower and less safe (a pasted line skips
the T411 dispatch verification that `bin/subagent` performs). Bounding the
depth instead of flattening it removes the need for that relay.

It stops accidental and eager recursion. It cannot stop a determined agent: on
a single-user machine any process running as that user can reach the
credential, and hiding it from a same-user child is not achievable in the
shell. Real containment needs OS-level separation — a separate user, a
container, or a broker holding the key. Do not trust this further than it
claims.

The credential travels by environment, never by argv: `tools/runner` echoes
argv and the heartbeat writer records it, so an `--api-key` flag leaks the key
into logs and evidence on every dispatch. Observed and redacted 2026-08-02;
never committed.

## Reach matrix (T320, corrected T321, 2026-08-03)

Who can dispatch what. Rows are labelled by **depth** (the gate), not by model
name. Updated for T431: the gate is `depth >= 3`, not `depth >= 2`.

| Dispatcher | → DeepSeek | → Ollama | → Claude |
|---|---|---|---|
| **Human console** (depth unset → 1) | WORKS — `bin/subagent` or `pi` | WORKS — `ollama launch pi` | WORKS — `claude -p` (headless Claude Code; never inside another harness) |
| **Manager** (depth 2) | WORKS — `bin/subagent`, child stamped 3 (T431; was REFUSED) | WORKS — `ollama launch pi` | WORKS — `claude -p` (headless Claude Code; never inside another harness) |
| **Leaf** (depth 3 = cap) | REFUSED — depth cap | WORKS — `ollama launch pi`, depth travels via env, no check | WORKS — `claude -p` (headless Claude Code; never inside another harness) |

**Two T320 cells were mis-attributed (corrected T321):**
- T320's `deepseek-v4-pro (d=2) → DeepSeek REFUSED` cell ran `bin/subagent
  --dry-run` with **no task argument** — it exited 1 for missing arguments,
  not because of the depth cap. The depth-cap refusal itself was demonstrated
  on the `glm-5.2 (d=2) → DeepSeek` cell (proper args, `REFUSED`, exit 1).
- Row labels named the model; the gate is depth. A DeepSeek/pi worker at
  depth 1 can dispatch DeepSeek/pi.

**Ollama → DeepSeek is real, not hypothetical (T321, 2026-08-03).** T320's
Ollama→DeepSeek cell was a `--dry-run` only — `--dry-run` returns before the
subprocess call, so it proved the depth check passed and `DEEPSEEK_API_KEY` is
present, not that a DeepSeek child ran. A real (non-dry-run)
`bin/subagent untracked/T321-probe-capital.md --dspro` dispatch (a file target,
so no kanban row is touched) was run from a `glm-5.2:cloud` console at depth
unset: the `deepseek-v4-pro` child replied exactly `Paris` and exited 0 in 4.5 s.
`DEEPSEEK_API_KEY` was present (len 35). The path works end-to-end; an Ollama leaf
**can** dispatch a real DeepSeek worker, and path 2 is demonstrated, not
speculative.

Key implications:
- **`ollama launch pi` has no depth cap.** A worker at any depth can launch
  Ollama children without restriction. The depth cap in `bin/subagent` stops
  DeepSeek→DeepSeek recursion but does not stop DeepSeek→Ollama or
  Ollama→anything.
- **`DEEPSEEK_API_KEY` is available inside Ollama workers.** If the allocation
  rule (Ollama for leaf rows only) is meant to be enforced technically, the
  key must not be present in Ollama environments.
- **The depth stamp travels through `ollama launch pi`** via standard env
  inheritance, without auto-increment. A depth-2 worker's Ollama child is also
  depth 2.

## Depth-enforcement ruling (T321, 2026-08-03)

The depth cap guards exactly **one** of the four dispatcher→target edges —
DeepSeek→DeepSeek via `bin/subagent`. The other three paths run free (T320):

1. `ollama launch pi` performs no depth check and no increment while the env
   value is inherited, so Ollama→Ollama is unbounded at any depth.
2. `DEEPSEEK_API_KEY` is present inside Ollama workers, so an Ollama leaf can
   dispatch DeepSeek whenever depth < 2. "Ollama for leaf rows only" is
   convention, not enforcement — and the path is **demonstrated by a real
   dispatch** (see the reach matrix), not merely dry-run possible.
3. A depth-2 worker's Ollama child is also depth 2 — the stamp travels without
   incrementing.

This is the doctrine's own caveat made concrete, not a contradiction of it: the
depth cap is a safety mechanism, not a security boundary. The decision is about
posture and cost, so the human rules. Option costs, one line each:

- **(a) Accept convention** — zero code; the risk is an accidental recursion
  burning cloud budget. Honest and cheap.
- **(b) Wrap the Ollama launch** — the guarded dispatcher stamps `WEIZIGO_AGENT_DEPTH`,
  increments it, and refuses at the worker depth; a convention backed by a tool,
  not a boundary, and it only helps if used instead of `ollama launch pi`.
- **(c) Strip `DEEPSEEK_API_KEY` from Ollama children** — the only option that
  truly enforces leaf-only (closes the now-demonstrated path 2); it breaks any
  legitimate Ollama→DeepSeek use. No such use is documented (Ollama models run as
  leaf workers; DeepSeek is dispatched from the human console or a manager via
  `bin/subagent`), and the throwaway probe found none either.

**Ruling: (b), with (a)'s honest documentation.** The guarded Ollama path
(ruled as `bin/ollama-subagent`, since T437/T527 the `--provider ollama` branch
of `bin/subagent`) mirrors the DeepSeek contract: it refuses at the worker depth
(`WEIZIGO_AGENT_DEPTH >= 2`), and stamps the child at depth 2. It is a safety
mechanism, not a security boundary — `ollama launch pi` remains directly callable
and unguarded, so the three paths above stay live and are documented as such.
**(c) is NOT moot** — the real dispatch proved an Ollama leaf can spend DeepSeek
budget — but it changes what existing consoles can do, so it is **held for the
human's explicit word** and not implemented here. Note (b) closes paths 1 and 3
(when used) but does **not** close path 2; only (c) does.

**Ruled 2026-08-03 evening (human): (c) is REJECTED.** Rationale as given:
stripping the key would only constrain *how* a runaway agent misbehaves, not
*whether* — it limits the models a loop can burn without preventing the loop —
and on a single-user machine the credential is reachable by any same-user
process anyway (§Depth cap above), so (c) solves no security or integrity
issue. If agents are permitted to dispatch across models, limiting their choice
of model is cost without containment. Standing posture stays **(b) plus honest
documentation**: path 2 (Ollama→DeepSeek) remains live and documented as such.
Revisit only if real containment (separate user, container, or key broker) is
proposed — that would change the premise, not the ruling.

**Clarified 2026-08-03 late evening (human): the Claude rule is about the
harness, not the dispatcher.** A Claude model must never run *inside* another
harness (e.g. a pi/Ollama process driving the Anthropic API itself). A
non-Claude worker spawning a shell command that launches a **headless Claude
Code session** (`claude -p "…" --model …`) is acceptable: the Claude model
still runs in its own harness with its own permission system. The budget and
runaway-loop exposure this opens is the same class the human accepted in the
(c) ruling above — documented, not enforced.

## Attribution never asks the model (T321, 2026-08-03)

T320 reported 0/4 self-identification mismatches, but it probed the `PI_MODEL`
env var — a different question from "what model do you believe you are."
Asked the latter, two of two workers were wrong (a `deepseek-v4-pro` worker said
`claude-opus-4-5`; a `glm-5.2` child said `GPT-5`), and neither string existed on
disk beforehand. So: **attribution reads `PI_MODEL` or comes from the
dispatcher; never from the model's self-report.**

## When to use

| scenario | subagent |
|---|---|
| Parallel independent audit (different instance, same model) | `bin/subagent <T-ID>` |
| Cheap mechanical sweep, terminology, formatting | `bin/subagent <T-ID> --flash` |
| Run two measurements at different goban sizes simultaneously | either |
| Adversarial review — must be a different instance, ideally different model | Pro reviews Pro, or Flash reviews Pro |

## Rules

1. **Give the subagent a bounded task.** One file to read, one question to answer, one deliverable. A subagent with an open-ended brief is a lost session.
2. **State the deliverable path.** The subagent must write its output to a specific file. The parent reads it after the subagent exits.
3. **Subagents never edit shared state *directly*.** No `CLAIMS.md`, no channel messages,
   no edits to the resume surface (`bin/managent resume` is read-only by construction;
   `CURRENT.md` is retired 2026-08-03).
   Kanban writes happen only via `bin/managent` (`claim` / `done` — the wrapper below enforces both).
   Output goes to `findings/` or a dedicated evidence path.
4. **Rows minted with `managent add` carry no model.** Unlike `managent suggest --model`,
   `managent add` (as of 2026-08-03) has no `--model` flag and stores nothing on the
   task record. A row created with `add` **must** be followed by
   `bin/managent agent <id> <model>` before dispatch, or it will close unattributed.
   **T317** will add `--model` to `add` so the habit is not the guard — a rule that
   lives only in the orchestrator's habits is exactly what failed here (seven rows
   hand-repaired on 2026-08-03: T292, T307, T309, T310, T305, T306, T313).
5. **Independent re-implementation is the highest-value use.** The only instrument that has found every real defect in this project is an independent seat. Subagents make this cheap.

## Patterns

```sh
bin/subagent T180                                  # audit
bin/subagent T181 & bin/subagent T182 --flash & wait   # parallel
```

## Recording

Subagent work is recorded in `model-perf.md` under the parent task, with a note that it was subdelegated. The subagent's model is stated.

## Prompt wrapper

`bin/subagent` builds the worker prompt from the bundle and wraps it with
kanban lifecycle commands:

```
Follow untracked/<TASK>-<slug>.md

FIRST: bin/managent claim <TASK> --agent <model>
You are a worker. The brief carries everything.

WHEN DONE, before any other output:
  1. Write findings/<TASK>-<slug>.json per findings/README.md
  2. bin/managent done <TASK> --agent <model> --status <...> --note <...>
```

`--agent <model>` is always included; the script resolves the model from the
`--dspro`/`--dsflash` flag (deepseek), the `--model` tag (ollama/claude). The
bundle carries everything else.

## Findings schema

Every subagent writes one findings file at `findings/<TASK-ID>-<slug>.json`.
The canonical schema and field semantics are at **`findings/README.md`**; the
machine-readable copy is `docs/infra/agents/findings-schema.json` (same schema).
Required fields: `task_id`, `date`, `model`, `claims`. `new_rows` only when the
task proposes new CLAIMS.md register rows. `findings/*.json` is what absorb and
claimlint C7 consume — a findings file written anywhere else silently bypasses
absorption.

### Minimal valid findings file

```json
{
  "task_id": "T180",
  "date": "2026-07-31",
  "model": "DSPro",
  "claims": [],
  "notes": "Audited spec X: 1 gap found, otherwise consistent."
}
```

### Full example (audit with gaps)

```json
{
  "task_id": "T172",
  "date": "2026-07-31",
  "model": "DSPro",
  "claims": [
    {
      "id": "CODE.VB-BLINDGAPS",
      "proposed_status": "PROVEN",
      "rationale": "Blind re-implementation of the verify-battery design found five spec gaps (GAP-5 CRITICAL).",
      "evidence_path": "docs/epics/E1-markovian/sprints/verify-battery/archive/T172-blind-analysis.md"
    }
  ],
  "new_rows": [],
  "notes": "GAP-5: invariant I11 requires a solver-side dump file whose format is defined nowhere — V-8 cannot implement I11 without it."
}
```

### Full example (build with tests)

```json
{
  "task_id": "T169",
  "date": "2026-07-31",
  "model": "DSPro",
  "claims": [],
  "new_rows": [],
  "notes": "Built vb_table.zig: 6 invariants (I1,I2,I3,I6,I10,I12), 19/19 tests passing, WZO1 only. Calibrations: I2=0/57 at 2x2, I2=0/489 at 3x2, I12 all legal slots in [-area,+area]. Ready for merge into vb_common.zig when T168 lands."
}
```

## Manager absorption handoff

After all subagents in a batch finish, the manager (builder) aggregates findings into one file.
**Load-bearing findings (claim status changes, new rows, anything cited downstream) go to
`docs/evidence/absorption/<YYYY-MM-DD>.json`** — evidence in git, or the claim is not proven.
`untracked/absorption-<YYYY-MM-DD>.json` is only for pure-mechanical batches that touch no claims.

```json
{
  "date": "2026-07-31",
  "manager_task": "T173",
  "manager_model": "DSPro",
  "subagent_count": 4,
  "findings": [
    { "task_id": "T168", ... },
    { "task_id": "T169", ... },
    { "task_id": "T170", ... },
    { "task_id": "T171", ... }
  ]
}
```

The absorption file is the single source of truth for what the batch produced. Claimlint C7 diffs
`findings/*.json` (`claims[].id` + `proposed_status` + `new_rows`) against `CLAIMS.md` to detect
unabsorbed findings; `weizigo-absorb` turns them into edit directives.
