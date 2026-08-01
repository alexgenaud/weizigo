# Subdelegation — dispatching work to DeepSeek Pro/Flash subagents

**Commands (DeepSeek models only):**
- `pi --provider deepseek --model deepseek-v4-pro -p "prompt"` — DeepSeek-v4-Pro subagent
- `pi --provider deepseek --model deepseek-v4-flash -p "prompt"` — DeepSeek-v4-Flash subagent

**Use the full `pi …` command above, never the `odeeppi`/`oflashpi` aliases.** Those are interactive-shell aliases: they do not exist in any non-interactive shell, so an agent dispatching `odeeppi -p "…"` from a tool-run shell gets `command not found` every time. Verified 2026-08-01 in both bash and zsh. This one line cost the project its entire autonomous-subdelegation capability — T226 could not dispatch a single audit subagent, fell back to doing every phase itself, and did not escalate.

Corrected 2026-08-01: an earlier version of this file claimed these commands "do not work from Opus, Fable, or Ollama models". **False.** `pi --provider deepseek --model deepseek-v4-pro -p "Reply with exactly the word OK"` was run from an Opus/Claude Code session in a non-interactive shell and returned `OK`, exit 0, in 1.8 s, peak RSS 194 MB. Any seat can subdelegate.

`DEEPSEEK_API_KEY` is exported and visible to non-interactive shells (verified). Subagents run in the same Pi harness as the parent, share the project directory, can read and write files, and return output on stdout. Dispatch under `tools/runner` so a hung subagent hits a guard instead of blocking the parent forever.

## When to use

| scenario | subagent |
|---|---|
| Parallel independent audit (different instance, same model) | `pi --provider deepseek --model deepseek-v4-pro` |
| Cheap mechanical sweep, terminology, formatting | `pi --provider deepseek --model deepseek-v4-flash` |
| Run two measurements at different goban sizes simultaneously | either |
| Adversarial review — must be a different instance, ideally different model | Pro reviews Pro, or Flash reviews Pro |

## Rules

1. **Give the subagent a bounded task.** One file to read, one question to answer, one deliverable. A subagent with an open-ended brief is a lost session.
2. **State the deliverable path.** The subagent must write its output to a specific file. The parent reads it after the subagent exits.
3. **Subagents never edit shared state *directly*.** No `CLAIMS.md`, no `CURRENT.md`, no channel messages.
   Kanban writes happen only via `bin/managent` (`claim` / `done` — the wrapper below enforces both).
   Output goes to `findings/` or a dedicated evidence path.
4. **Independent re-implementation is the highest-value use.** The only instrument that has found every real defect in this project is an independent seat. Subagents make this cheap.
5. **Max two DeepSeek pi-subagents at once.** They share the same filesystem and API key; three concurrent
   risk race conditions and rate limiting. This cap is a rate-limit scope on pi-subagents only — the
   concurrency authority is `docs/infra/delegation/ROLES.md` §Concurrency (analysis unlimited, mutation serial).

## Pattern: independent audit

```sh
# Parent dispatches an audit subagent
# First create the task:
bin/managent suggest audit-spec --model DSPro
# Fill in the bundle with the task description, then dispatch:
pi --provider deepseek --model deepseek-v4-pro -p "Follow untracked/T<ID>-audit-spec.md"
```

## Pattern: parallel measurements

```sh
# First create the tasks:
bin/managent suggest SCC-3x3 --model DSPro
bin/managent suggest SCC-4x3 --model DSFlash
# Fill in bundles, then dispatch:
pi --provider deepseek --model deepseek-v4-pro -p "Follow untracked/T<ID>-SCC-3x3.md" &
pi --provider deepseek --model deepseek-v4-flash -p "Follow untracked/T<ID>-SCC-4x3.md" &
wait
```

## Recording

Subagent work is recorded in `model-perf.md` under the parent task, with a note that it was subdelegated. The subagent's model is stated.

## Prompt wrapper — dispatch / claim / findings / done

Every subagent dispatch **must** use the wrapper below. The wrapper enforces the lifecycle: read the bundle, claim the task, produce findings, mark done. The manager replaces `<PLACEHOLDERS>` before dispatch.

### Wrapper template

```
Follow untracked/<TASK-ID>-<slug>.md

FIRST — claim your task:
  bin/managent claim <TASK-ID>

Read your brief at untracked/<TASK-ID>-<slug>.md — it carries everything.

WHEN DONE — before any other output:
  1. Write your findings to findings/<TASK-ID>-<slug>.json per the schema at findings/README.md.
  2. Run `bin/managent done <TASK-ID>`.

---
<actual task prompt here>
```

**Placeholders:**
| placeholder | fill with | example |
|---|---|---|
| `<TASK-ID>` | kanban task ID | `T180`, `EXP-5` |
| `<slug>` | task slug (from bundle path) | `audit-verify` |
| `<actual task prompt here>` | the real prompt (after the `---` separator) | `Audit the spec at docs/... Accept/Reject with gaps.` |

### Rules

1. **The wrapper is mandatory.** Every dispatch uses the bundle-reference form below. No bare prompts. Invoke it with the full `pi --provider deepseek --model …  -p` command — **not** the `odeeppi`/`oflashpi` aliases, which do not exist in non-interactive shells.
2. **The dispatch line is minimal.** The bundle carries everything — task ID, model, slug, lifecycle commands, deliverables, and acceptance criteria. The worker reads the bundle, not the prompt line.
3. **The separator is a horizontal rule.** `---` on its own line, blank line above and below, exactly as shown. The payload (actual task prompt) goes below it.
4. **The subagent writes findings before `done`.** If the findings write fails for any reason, the subagent must NOT mark the task done — the manager must know the task is incomplete.
5. **`claim` needs no `--agent`.** The model was stored at suggest/dispatch time; `claim` picks it up automatically.

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
