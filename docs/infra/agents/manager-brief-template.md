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

**Concurrency limit:** `<N>` subagents at once (see `docs/infra/agents/subdelegation.md` rule 5 — max 2 for DeepSeek pi-subagents, API rate limit; the authority on parallelism is `docs/infra/delegation/ROLES.md` §Concurrency — analysis unlimited, mutation serial).

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
  1. Write your findings to findings/<TASK-ID>-<slug>.json per the schema at findings/README.md.
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

Read your brief at docs/epic-01-markovian/sprints/foo/pass0/spec.md.

WHEN DONE — before any other output:
  1. Write your findings to findings/T999-audit-<slug>.json per the schema at findings/README.md.
  2. Run `bin/managent done T999-audit`.

---
Audit docs/epic-01-markovian/sprints/foo/pass0/spec.md against its acceptance criteria. Report every gap with severity and which tasks it blocks. Write detailed analysis to untracked/T999-audit.md. Do not edit the spec."
```

## 3. Findings collection

After all subagents finish, collect their `findings/<TASK-ID>-<slug>.json` files. Verify each one:

1. **File exists** — if missing, the subagent may have crashed before writing findings; check `bin/managent status` to see if it claimed but never `done`d.
2. **Valid JSON** — parse it. If malformed, the subagent hallucinated the schema; re-dispatch or hand-fix.
3. **Required fields present** — `task_id`, `date`, `model` and the `claims` array must be non-empty per `findings/README.md`.
4. **Claims touched match reality** — `claims[].id` and `proposed_status` must use the `findings/README.md` status vocabulary, and `new_rows` must carry every row the task proposes for CLAIMS.md.

## 4. Gap flagging

Scan all findings files for gap mentions (in `notes`, or the evidence file cited by `claims[].evidence_path`). For each gap:

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

After all subagents finish and gaps are triaged, write one absorption file. **Load-bearing findings (claim status changes, new rows, anything cited downstream) go to `docs/evidence/absorption/<YYYY-MM-DD>.json`** — evidence in git, or the claim is not proven. `untracked/absorption-<YYYY-MM-DD>.json` is only for pure-mechanical batches that touch no claims.

```
docs/evidence/absorption/<YYYY-MM-DD>.json
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
    { "...": "copy of findings/<TASK-ID>-<slug>.json contents" },
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
      "claims": [],
      "new_rows": [],
      "notes": "Built vb_common.zig and verify_battery.zig harness — compiles, JSON output works. Ready for T169-T171 to write invariant modules against."
    }
  ],
  "summary": "All four verify-battery subagents completed. M1 harness builds and runs. M2 table invariants pass 19/19 tests. M3 fixpoint invariants pass 7/7 tests. M4 graph I5 calibrates. One moderate gap (I7 recurrence check deferred). Sprint ready for integration."
}
```

## 6. Post-absorption

1. **Commit the absorption file.** Load-bearing findings live at `docs/evidence/absorption/<date>.json`, which is tracked — committed to git before anything downstream cites it. A pure-mechanical batch may keep its file in `untracked/`, but never put load-bearing findings there: `untracked/` is git-ignored, which is how evidence dies.
2. **Update `docs/status/CURRENT.md`** with the batch result.
3. **If any `claims[]` or `new_rows` entries exist:** file a follow-up task for the Orchestrator/claimlint (or run `weizigo-absorb`) to absorb them into `CLAIMS.md`.
4. **If any gap mentions exist:** file follow-up tasks for resolution in the next sprint, unless the gap is CRITICAL (handle immediately).
