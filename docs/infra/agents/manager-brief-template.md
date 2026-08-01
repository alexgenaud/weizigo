# Manager brief template — dispatch + absorption

**Author:** T209 · 2026-08-01
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

### Creating a task (human or manager)

```sh
bin/managent suggest <slug> --model <model> [--set <A-Z>]
```

This prints a one-line dispatch prompt (`Follow untracked/T<ID>-<slug>.md`), creates the bundle
template, and stores the model on the task record. The bundle carries everything the worker needs.

### Dispatching (one line)

The worker's harness receives exactly one line:

```
Follow untracked/T<ID>-<slug>.md
```

The bundle at that path carries the task ID, slug, and everything else the worker needs (lifecycle
commands, deliverables, acceptance criteria). The worker reads the bundle and proceeds.

### The bundle carries everything

A task bundle created by `managent suggest` starts with:

```
<!--managent set=X deliverables=-->
# T<ID> — <slug>
```

The human (or manager) fills in:
- **`deliverables=`** — comma-separated paths in the meta header (machine-readable, checked by `managent done`)
- **`acceptance=`** (optional) — a shell command that must exit zero before `managent done` closes the task.
  Put it last in the meta header (it consumes the rest of the line). Example:
  `acceptance=tools/runner -- zig build test`
  Skip with `managent done <id> --skip-acceptance <reason>`; the reason is recorded and surfaced by audit. (T217)
- **Body** — task description, acceptance criteria, calibration, prior art, etc.

### Worker lifecycle (automatic)

The worker follows the bundle. At startup it runs:

```sh
bin/managent claim T<ID>
```

The `--agent` flag is optional — `claim` uses the model stored at suggest/dispatch time. On
completion:

```sh
bin/managent done T<ID>
```

The `done` command checks that every path in `deliverables=` exists on disk before marking the task
done. If a deliverable was committed but moved, update the meta header.

**The human does not ferry information between seats.** The worker self-claims, self-reports, and
commits its own work. The delegator verifies via `bin/managent status` + `git log`, never via
pasted console transcripts.

### Mechanical dispatch (preferred path)

For fully mechanical launch, `--exec` chains claim + harness invocation:

```sh
bin/managent claim T<ID> --exec "pi --provider deepseek --model deepseek-v4-pro"
```

This runs the harness with the bundle path injected (`pi -p "follow untracked/T<ID>-<slug>.md"`).

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

## 6. Post-absorption

1. **Commit the absorption file.** Load-bearing findings live at `docs/evidence/absorption/<date>.json`, which is tracked — committed to git before anything downstream cites it. A pure-mechanical batch may keep its file in `untracked/`, but never put load-bearing findings there: `untracked/` is git-ignored, which is how evidence dies.
2. **Update `docs/status/CURRENT.md`** with the batch result.
3. **If any `claims[]` or `new_rows` entries exist:** file a follow-up task for the Orchestrator/claimlint (or run `weizigo-absorb`) to absorb them into `CLAIMS.md`.
4. **If any gap mentions exist:** file follow-up tasks for resolution in the next sprint, unless the gap is CRITICAL (handle immediately).
