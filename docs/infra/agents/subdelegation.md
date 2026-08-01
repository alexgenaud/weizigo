# Subdelegation — dispatching work to DeepSeek Pro/Flash subagents

**Commands (DeepSeek models only):**
- `pi --provider deepseek --model deepseek-v4-pro -p "prompt"` — DeepSeek-v4-Pro subagent
- `pi --provider deepseek --model deepseek-v4-flash -p "prompt"` — DeepSeek-v4-Flash subagent

These work from DeepSeek sessions invoked via `odeeppi` or `oflashpi`. They do not work from Opus, Fable, or Ollama models. Opus and Fable in Claude Code have their own subagent capabilities.

API key is already exported in the parent shell. Subagents run in the same Pi harness as the parent. Output returns to stdout. Subagents share the project directory and can read/write files.

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
3. **Subagents never edit shared state.** No `CLAIMS.md`, no `CURRENT.md`, no `tasks.json`, no channel messages. Output goes to `untracked/` or a dedicated evidence path.
4. **Independent re-implementation is the highest-value use.** The only instrument that has found every real defect in this project is an independent seat. Subagents make this cheap.
5. **Max two subagents at once.** They share the same filesystem and API key. Three concurrent subagents risk race conditions and rate limiting.

## Pattern: independent audit

```sh
# Parent dispatches an audit subagent
pi --provider deepseek --model deepseek-v4-pro -p "You are DSPro/T999-audit. Read docs/design/foo/pass0/spec.md. Audit it against the acceptance criteria in the same file. Write your verdict and findings to untracked/T999-audit.md. Do not edit the spec."
```

## Pattern: parallel measurements

```sh
# Run SCC census at two goban sizes in parallel
pi --provider deepseek --model deepseek-v4-pro -p "You are DSPro/SCC-3x3. Read docs/infra/dispatch/SCC-3x3.md. Run the census. Write results to docs/evidence/SCC/3x3.md." &
pi --provider deepseek --model deepseek-v4-flash -p "You are DSFlash/SCC-4x3. Read docs/infra/dispatch/SCC-4x3.md. Run the census. Write results to docs/evidence/SCC/4x3.md." &
wait
```

## Recording

Subagent work is recorded in `model-perf.md` under the parent task, with a note that it was subdelegated. The subagent's model is stated.

## Prompt wrapper — claim / findings / done

Every subagent dispatch **must** use the wrapper below. The wrapper enforces three lifecycle steps the subagent does not know about on its own: claim the task before starting, write a standardized findings file, and mark the task done. The manager replaces `<PLACEHOLDERS>` before dispatch.

### Wrapper template

Copy this block verbatim, replace the four placeholders, then append the actual task prompt after the separator.

```
You are <MODEL>/<TASK-ID>.

FIRST — claim your task:
  bin/managent claim <TASK-ID> --agent <MODEL>

Read your brief at <BRIEF-PATH>.

WHEN DONE — before any other output:
  1. Write your findings to untracked/<TASK-ID>-findings.json per the schema at docs/infra/agents/findings-schema.json.
  2. Run `bin/managent done <TASK-ID>`.

---
<actual task prompt here>
```

**Placeholders:**
| placeholder | fill with | example |
|---|---|---|
| `<MODEL>` | short model name | `DSPro`, `DSFlash` |
| `<TASK-ID>` | kanban task ID | `T180`, `EXP-5` |
| `<BRIEF-PATH>` | path to the task brief | `untracked/T180-audit.md` |
| `<actual task prompt here>` | the real prompt (after the `---` separator) | `Audit the spec at docs/... Accept/Reject with gaps.` |

### Rules

1. **The wrapper is mandatory.** Every `odeeppi -p` or `oflashpi -p` dispatch uses it. No bare prompts.
2. **The separator is a horizontal rule.** `---` on its own line, blank line above and below, exactly as shown. The payload (actual task prompt) goes below it.
3. **The subagent writes findings before `done`.** If the findings write fails for any reason, the subagent must NOT mark the task done — the manager must know the task is incomplete.
4. **The `--agent` flag on claim** must match the model in the wrapper. This feeds `model-perf.md` attribution.

## Findings schema

Every subagent writes one findings file at `untracked/<TASK-ID>-findings.json`. The machine-readable schema is at `docs/infra/agents/findings-schema.json`. Required fields: `task_id`, `date`, `model`, `summary`. All other fields are optional but should be filled when relevant.

### Minimal valid findings file

```json
{
  "task_id": "T180",
  "date": "2026-07-31",
  "model": "DSPro",
  "summary": "Audited spec X: 1 gap found, otherwise consistent."
}
```

### Full example (audit with gaps)

```json
{
  "task_id": "T172",
  "date": "2026-07-31",
  "model": "DSPro",
  "summary": "Blind re-implementation analysis: 5 gaps found (GAP-5 CRITICAL), 12 invariants consistent with design.",
  "claims_touched": [],
  "proposed_status": "none",
  "evidence_path": "untracked/T172-blind-analysis.md",
  "gaps_found": [
    {
      "id": "GAP-5",
      "severity": "CRITICAL",
      "description": "I11 dump format unspecified — V-8 cannot implement I11 without it.",
      "blocks": "T169"
    },
    {
      "id": "GAP-3",
      "severity": "Moderate",
      "description": "I7 missing DTT recurrence check in value schema."
    }
  ],
  "next_steps": "Resolve GAP-5 before dispatching V-8; GAP-3 can be resolved during implementation."
}
```

### Full example (build with tests)

```json
{
  "task_id": "T169",
  "date": "2026-07-31",
  "model": "DSPro",
  "summary": "Built vb_table.zig: 6 invariants (I1,I2,I3,I6,I10,I12), 19/19 tests passing, WZO1 only.",
  "claims_touched": [],
  "proposed_status": "none",
  "evidence_path": "untracked/T169-notes.md",
  "artifacts_produced": ["src/vb_table.zig"],
  "verification": {
    "tests_passed": 19,
    "tests_total": 19,
    "calibrations_passed": ["I2=0/57 at 2x2", "I2=0/489 at 3x2", "I12 all legal slots in [-area,+area]"],
    "calibrations_failed": []
  },
  "builds": true,
  "next_steps": "Ready for merge into vb_common.zig when T168 lands."
}
```

## Manager absorption handoff

After all subagents in a batch finish, the manager (builder) aggregates findings into one file:

```
untracked/absorption-<YYYY-MM-DD>.json
```

This is a JSON array of all subagent findings objects, plus a header:

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

The absorption file is the single source of truth for what the batch produced. Claimlint can diff `claims_touched` + `proposed_status` against `CLAIMS.md` to detect unabsorbed findings.
