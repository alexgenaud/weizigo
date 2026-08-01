# Manager brief template — dispatch + absorption

**Author:** DSPro/T179 · 2026-07-31
**Status:** LIVING — replace placeholders, do not edit structure.

A manager brief is what a builder/manager agent reads before spawning subagents. It is the single
document that turns a sprint spec into a set of dispatches, collects findings, and produces the
absorption handoff. Fill in the `<PLACEHOLDERS>`, then dispatch.

---

## 1. Task list

Each row is one subagent dispatch. Fill in the brief path for each.

| task ID | brief path | model | holds | notes |
|---|---|---|---|---|
| `<TASK-1>` | `<path-to-brief-1>` | `<DSPro or DSFlash>` | `<paths or —>` | `<what this task does>` |
| `<TASK-2>` | `<path-to-brief-2>` | `<model>` | `<paths>` | `<notes>` |
| ... | ... | ... | ... | ... |

**Concurrency limit:** `<N>` subagents at once (see `docs/infra/delegation/ROLES.md` — max 2 for DeepSeek, unlimited for read-only analysis).

**Model guidance:** Use DSPro for reasoning-heavy tasks (audits, re-implementation, spec analysis).
Use DSFlash for mechanical sweeps, terminology, formatting, and census runs. Specify only when it
changes the outcome (per ROLES.md "Specification restraint").

## 2. Dispatch instructions

For each task in the table above, construct the dispatch prompt using the **prompt wrapper** from
`docs/infra/agents/subdelegation.md` (the "Prompt wrapper" section). Copy the wrapper, replace the
four placeholders, then append the task-specific prompt below the `---` separator.

### Dispatch template (one per subagent)

```
pi --provider deepseek --model <deepseek-model> -p "You are <MODEL>/<TASK-ID>.

FIRST — claim your task:
  bin/managent claim <TASK-ID> --agent <MODEL>

Read your brief at <BRIEF-PATH>.

WHEN DONE — before any other output:
  1. Write your findings to untracked/<TASK-ID>-findings.json per the schema at docs/infra/agents/findings-schema.json.
  2. Run `bin/managent done <TASK-ID>`.

---
<actual task prompt here>"
```

### Task-specific prompt guidelines

- **One bounded task per subagent.** One file to read, one question to answer, one deliverable.
- **State the deliverable path explicitly.** The subagent must know where to write its output.
- **Include the calibration gate if applicable.** "Before reporting success, reproduce X at Y size."
- **State the acceptance test.** "You have succeeded when file Z exists and passes its tests."

### Example (audit subagent)

```
pi --provider deepseek --model deepseek-v4-pro -p "You are DSPro/T999-audit.

FIRST — claim your task:
  bin/managent claim T999-audit --agent DSPro

Read your brief at docs/design/foo/pass0/spec.md.

WHEN DONE — before any other output:
  1. Write your findings to untracked/T999-audit-findings.json per the schema at docs/infra/agents/findings-schema.json.
  2. Run `bin/managent done T999-audit`.

---
Audit docs/design/foo/pass0/spec.md against its acceptance criteria. Report every gap with severity and which tasks it blocks. Write detailed analysis to untracked/T999-audit.md. Do not edit the spec."
```

## 3. Findings collection

After all subagents finish, collect their `untracked/T<id>-findings.json` files. Verify each one:

1. **File exists** — if missing, the subagent may have crashed before writing findings; check `bin/managent status` to see if it claimed but never `done`d.
2. **Valid JSON** — parse it. If malformed, the subagent hallucinated the schema; re-dispatch or hand-fix.
3. **Required fields present** — `task_id`, `date`, `model`, `summary` must be non-empty.
4. **Claims touched match reality** — if the task edited `CLAIMS.md`, `claims_touched` must list the claim IDs.

## 4. Gap flagging

Scan all findings files for `gaps_found` entries. For each gap:

1. **Record it in the absorption file** — the gap object copies verbatim from the findings.
2. **If severity is CRITICAL:** halt the sprint until the gap is resolved. CRITICAL means a downstream task cannot start.
3. **If severity is HIGH:** flag it prominently in the absorption summary. The Orchestrator decides whether to proceed.
4. **If Moderate or Minor:** record it; resolution can happen in a follow-up sprint.

**Gap triage checklist (per gap):**
- [ ] Is the gap real? (manager spot-checks the evidence)
- [ ] Does it block any task in the current sprint?
- [ ] Does it need a spec/design amendment, or just an implementation note?
- [ ] Who owns resolution — the manager, the spec author, or a separate task?

## 5. Absorption handoff

After all subagents finish and gaps are triaged, write one absorption file:

```
untracked/absorption-<YYYY-MM-DD>.json
```

### Format

```json
{
  "date": "<YYYY-MM-DD>",
  "manager_task": "<MANAGER-TASK-ID>",
  "manager_model": "<MODEL>",
  "sprint": "<sprint-name>",
  "subagent_count": <N>,
  "all_done": <true|false>,
  "gaps_critical": <N>,
  "gaps_high": <N>,
  "gaps_moderate": <N>,
  "gaps_minor": <N>,
  "findings": [
    { "...": "copy of T<id>-findings.json contents" },
    { "...": "next subagent findings" }
  ],
  "summary": "<one-paragraph summary of what the batch produced>"
}
```

### Example

```json
{
  "date": "2026-07-31",
  "manager_task": "T173",
  "manager_model": "DSPro",
  "sprint": "verify-battery",
  "subagent_count": 4,
  "all_done": true,
  "gaps_critical": 0,
  "gaps_high": 0,
  "gaps_moderate": 1,
  "gaps_minor": 2,
  "findings": [
    {
      "task_id": "T168",
      "date": "2026-07-31",
      "model": "DSPro",
      "summary": "Built vb_common.zig and verify_battery.zig harness — compiles, JSON output works.",
      "claims_touched": [],
      "proposed_status": "none",
      "evidence_path": "untracked/T168-notes.md",
      "artifacts_produced": ["src/vb_common.zig", "src/verify_battery.zig"],
      "builds": true,
      "next_steps": "Ready for T169-T171 to write invariant modules against."
    }
  ],
  "summary": "All four verify-battery subagents completed. M1 harness builds and runs. M2 table invariants pass 19/19 tests. M3 fixpoint invariants pass 7/7 tests. M4 graph I5 calibrates. One moderate gap (I7 recurrence check deferred). Sprint ready for integration."
}
```

## 6. Post-absorption

1. **Commit the absorption file** to git (it lives in `untracked/`, which is git-ignored — the absorption file SHOULD be committed to `docs/evidence/` if it contains load-bearing findings).
2. **Update `docs/status/CURRENT.md`** with the batch result.
3. **If any `claims_touched` entries exist:** file a follow-up task for the Orchestrator/claimlint to absorb them into `CLAIMS.md`.
4. **If any `gaps_found` entries exist:** file follow-up tasks for resolution in the next sprint, unless the gap is CRITICAL (handle immediately).
