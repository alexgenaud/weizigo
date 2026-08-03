# Subdelegation

```sh
bin/subagent <T-ID> --dspro         # DeepSeek-v4-Pro worker
bin/subagent <T-ID> --dsflash       # DeepSeek-v4-Flash worker
bin/subagent <T-ID> --dspro --wall=900     # wall guard, default 1800s
bin/subagent <T-ID> --dspro --dry-run      # print the command, spawn nothing
bin/subagent <path.md> --dsflash    # bare dispatch, no kanban lifecycle
```

No default model — name one. Max two concurrent; `&` them and `wait`.

DeepSeek dispatches DeepSeek only. Claude seats use the Claude Code harness and
do not need this tool.

Max two concurrent. `&` them and `wait`.

The script resolves the bundle, builds the claim/findings/done wrapper, runs
under `tools/runner`, and stamps `WEIZIGO_AGENT_DEPTH` on the child.

**Depth cap — a safety mechanism, not a security boundary.** Children run at
depth 2 with `WEIZIGO_AGENT_DEPTH` stamped, and `bin/subagent` refuses at 2: a
worker writes a file or returns output to its manager and stops.

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
6. **Max two DeepSeek pi-subagents at once.** They share the same filesystem and API key; three concurrent
   risk race conditions and rate limiting. This cap is a rate-limit scope on pi-subagents only — the
   concurrency authority is `docs/infra/delegation/ROLES.md` §Concurrency (analysis unlimited, mutation serial).

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
`--dspro`/`--dsflash` flag. The bundle carries everything else.

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
      "evidence_path": "docs/epic-01-markovian/sprints/verify-battery/archive/T172-blind-analysis.md"
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
