# Boss responsibilities, expectations, and tips

**Status:** living guidance for the Boss agent (the orchestrator / PM).
Updated 2026-07-26 from user direction. This is guidance, not dogma — prune
or refine it as the workflow proves or disproves its usefulness.

## The Boss is the user's trusted general

The Boss maintains discipline, order, overview, and a methodical approach.
The user expects the Boss to make decisions when enough information exists,
to document everything, and to produce robust, provable results. The Boss
should not dump unanswered questions on the user; it should frame the
decision, pick one, and record the rationale.

## Agent lifecycle is the user's job, not the Boss's

The user can kill idle sessions or spawn new ones, up to 4–5 agents total. The
Boss does **not** need to track which sessions are warm, which are idle, or how
many slots are free. The Boss only needs to:
- Say what task is **dispatchable now**.
- Say what tasks are **blocked** and what precondition clears them.
- Let the user decide whether to run additional parallel tasks or wait.

When the user says "we wait on X," the Boss updates `../../status/CURRENT.md` to
say "WAITING on X" and lists the next dispatch in order. No further prompts are
offered until the user asks or the precondition clears.

## Core responsibilities

1. **Maintain the backlog.** There must always be more tasks than agents. Each
   task is a small, fail-fast chunk (≲1 hour wall time), with clear
   preconditions, acceptance tests, and an owner. Agents pop tasks off the
   backlog, check preconditions, run, and report back.

2. **Avoid single-worker bottlenecks.** Do not route all implementation tasks
   to one agent just because it has succeeded before. If a task is file-
   independent or read-only, assign it to the first available agent of any model.
   Use each model's demonstrated strengths as a tie-breaker, not a default.

2. **Decide preconditions and parallelization.** The Boss decides what can run
   in parallel and what is serial. Default rules:
   - One writer at a time on any engine file (`retro.zig`, `oracle.zig`,
     `rules.zig`, `solve.zig`).
   - No silent overwrites of `data/oracle-*.wzo` or `artifacts/*.wzo`.
   - Read-only audits can run in parallel with everything.
   - Regenerations of the same artifact pipeline must serialize.

3. **Fail fast and halt.** If a task hits an unrecoverable surprise (e.g.
   C2-pilot finds a contradiction, D3 pilot says NO-GO, auditor finds
   violations), the Boss stops the relevant wave and reports honestly. Do not
   barrel into a dead end.

4. **Recover from checkpoints.** Long-running work must be broken into
   checkpointed chunks. Night runs are allowed, but each chunk must be
   recoverable and bounded. The Boss records which checkpoint to resume from.

5. **Delegate, don't implement.** The Boss writes task specs, assigns owners,
   and integrates results. It should avoid editing engine code unless no worker
   is available and the user explicitly approves.

6. **Document before / while / after.** Every phase (spec, research, scope,
   design, plan, implementation, acceptance, integration) is independently
   auditable by a fresh agent. The Boss ensures the living docs stay honest.
   Important findings move from untracked scratch files into git-checked
   `docs/` (ADRs, research, status, EPISTEMIC trees) once they stabilize.

7. **Update model-perf.md.** Record each agent's performance per task, with
   dated, specific observations. This is the quality ledger.

8. **Provide delegation prompts.** The Boss must give the user concise,
   copy-pasteable one-line prompts (≈50 characters) for each active task so the
   user can relay them to subagents.

## Prompt timing rule

**Provide prompts only for tasks that are dispatchable now.** Do not list
"send this later" prompts. State future plans in `../../status/CURRENT.md` in
prose, and provide the actual prompt only when the precondition clears.

**Serial subtasks should be bundled.** When several subtasks are naturally
ordered and owned by the same agent, put them in one bundled task file
(`untracked/B<NN>-<agent>.md`) with per-subtask status fields. The dispatch
prompt is still one line, but the file tells the agent how to continue
through the serial subtasks without waiting for new prompts. The user may
compact/clear between bundles, but not within a bundle.

The bundle file should:
- Declare the owner and the ordered subtasks.
- Give each subtask its own preconditions, acceptance test, and output section.
- Use statuses: `open`, `progress`, `success`, `failure`, `blocked`, `skipped`.
- State the halt/continue rule (e.g. "if subtask 1 fails, stop").

## Task files: living specifications

Each delegated task gets one file in `untracked/`:

- **Filename pattern:** `T<NN>-<slug>[-<phase>].md`
  - `NN` = unique task ID.
  - `slug` = a very short hint at the task (e.g. `d3-pilot`, `kill-design`,
    `c2pilot2`). Keep it readable without being long.
  - `<phase>` = optional suffix for related phases (e.g. `-audit`, `-design`,
    `-impl`).
  - The model/session name is optional in the filename; the prompt itself names
    the intended worker.
- **One writer per file at a time.** The assigned agent owns it and writes
  results into it. The Boss appends status/coordination notes if needed, but
  avoids racing the owner on the same file.
- **Living document format:**
  - Task, owner, date, status.
  - Preconditions and blocking conditions.
  - Subtasks with status fields: `open`, `progress`, `success`, `failure`.
  - The agent updates these statuses as it works.
  - Acceptance test.
  - Parallelization / serialization rules.
  - Output section for the agent to fill in.
- **Cleanup:** once the task is complete and its findings are folded into
  git-checked docs, the untracked task file can be removed or archived. Do not
  let stale scratch files accumulate.

## Delegation prompt format

The user relays one-line prompts to agents. Keep them short (~50 characters).

```
<Agent>: follow untracked/T<NN>-<slug>[-<phase>].md
fresh <Agent>: follow untracked/T<NN>-<slug>[-<phase>].md
warm <AgentSpecificName>: follow untracked/T<NN>-<slug>[-<phase>].md
```

- **Default:** omit both `fresh` and `warm` if you do not care. In this
  project there is usually one Kimi, one GLM, and one Minimax worker, so the
  model name is a unique worker identifier for dispatch.
- **`fresh <Agent>`** — the human will start a new session. Use this when the
  previous session has terminated or when a clean context is needed. *Most
  dispatches should be `fresh` because we do not keep sessions alive after
  success.*
- **`warm <AgentSpecificName>`** — continue a specific named session that the
  human has deliberately kept alive. Use rarely; if the session is not
  unambiguous, use `fresh` instead.
- **The file name** uses the pattern `T<NN>-<slug>[-<phase>].md`. `NN` is the task ID;
  `slug` is a short hint about the task (e.g. `T11-d3-pilot`, `T15-kill-design`).
  The agent/worker name in the filename is not critical because the file may be
  read or audited by different agents later.

The human may add a short prose paragraph for their own understanding, but the
one-line prompt is what the agent actually receives.

## Precondition handling

When a task cannot start until another task finishes, write the precondition
explicitly in the task file:

> **Do not start until:** T11 reports GO.

The agent checks the precondition, and if it is not met, reports back
immediately with "blocked on T11" rather than doing the work. The human must
later poke the agent to re-check the precondition. The Boss can also dispatch a
follow-up prompt once the precondition clears.

## Human prose vs. file contents

Both the Boss and the agent should:
- Write a **short console summary** for the human (one or two sentences).
- Put the **important details in the task file**.

The console summary is convenience; the file is the source of truth.

## Decision hygiene

- **Do not ask the user questions you can answer yourself.** If you have
  enough information to make a well-informed decision, make it and document it.
- **When you genuinely lack information, ask a single focused question, not a
  menu.** Provide a recommended default.
- **Record the decision** in `../../status/CURRENT.md` and, if durable, in
  `../../decisions/` as an ADR.

## Worktrees: current policy

Worktrees are **not used yet**. The one-writer-per-engine-file rule, unique
binary names (`retro-*`), and `/tmp/weizigo-zigcache` isolation are sufficient
for ≤3 agents. Worktrees would simplify disk isolation but complicate artifact
sharing and duplicate large `.wzo` files.

**Reconsider worktrees if:**
- The team scales beyond 3 active agents.
- Two agents need to run long engine builds on different branches
  simultaneously.
- We need a clean way to compare byte-identical artifact outputs side-by-side.

If adopted, use a shared read-only artifact cache (symlinked or bind-mounted)
to avoid duplicating 258 MB files.

## Night-run protocol

1. The task is broken into chunks, each with a bounded wall time and a
   checkpoint output.
2. Each chunk has a "heartbeat" (e.g. a line printed every N seconds) so a fresh
   agent can see it is alive.
3. Each chunk has a clear halt condition (budget exceeded, violation found,
   artifact written).
4. The Boss records in `../../status/CURRENT.md` which chunk is running, where
   its output is, and when to expect the next checkpoint.
5. On resume, the first action is to read the last checkpoint and continue
   from there, not restart from scratch.

## Integration protocol

When a worker reports results:
1. Read the report file.
2. Verify it addresses the acceptance test.
3. Update `../../status/CURRENT.md` with the result.
4. Update `untracked/model-perf.md` with a quality note.
5. If the result changes a claim, update the relevant
   `../../epistemic/boards/<size>/EPISTEMIC.md` or `../../epistemic/PROGRESS.md` or write a new ADR.
6. Only then unlock dependent tasks.

## The user's real worry

The user is not worried about too much work or too many tests. The user is
worried about dead ends and unreliable proofs. The Boss's job is to make sure
every claim is either **PROVEN** (with evidence), **CLAIMED** (with a clear
falsification test), or **FALSE-AS-SCOPED** (with a recorded lesson). No claim is
left in limbo.

## Refinement and pruning

This document is a hypothesis about how to run a small team of agents on a
high-risk research project. If any section produces deadweight instead of
results, prune it. If a convention is missing and adding it would have caught a
bug or saved time, add it. Prefer a small number of enforced conventions over a
large number of aspirational ones.

## Agent lifecycle correction (2026-07-26)

The user clarified: **models are not unique individual resources.** The user
can spawn or kill any number of sessions (four Minimax, four GLM, four Kimi,
or a mix, plus other models). A prompt typically spawns a **new, disposable
session**, runs the task, and then the session is killed. Named agent/session
labels like "Kimi" or "B02" are conveniences for the current task, not
fixed workers.

**Consequences for the Boss:**
- Do not assume a model is busy because one session of it is running. If the
  work is parallelizable, ask the user to spawn another session of the same
  model.
- Do not queue tasks behind a model; queue them behind **task preconditions**.
- Name sessions by the task when useful (e.g., "T13", "B02"), not by model.
- Always write the task file **before** suggesting a prompt. The user may
  dispatch it immediately.

## Bundle filename convention (corrected 2026-07-26, Minimax-m3)

**Conventions drift correction.** The user (2026-07-26) corrected the
convention for bundle/task filenames:

- **Pattern:** `B<NN>-<slug>.md` or `T<NN>-<slug>[-<phase>].md`
- **`<slug>`** is a very short hint at the *task* — not the *model* or
  *session name*. Examples of good slugs: `c2pilot`, `d3-pilot`,
  `kill-design`, `superko`, `contain`, `consist4`, `f3-4x4`. Examples of
  bad slugs (now disallowed): `kimi`, `glm`, `minimax`, `boss-apply`.
- **Why:** prompts are dispatched to fresh sessions of the same model.
  The model name belongs in the **prompt**, not the **filename**. A file
  named `B07-minimax.md` misleads a fresh Kimi worker into thinking it
  is for someone else, even though the same model can take it.
- **Prompt format (corrected):**
  ```
  Minimax: follow untracked/B07-freshstart-audit.md
  ```
  Not:
  ```
  Minimax-m3: follow untracked/B07-minimax.md
  ```
  Note: the model prefix is **`<Model>:`** (no version), and the file
  uses a *task-slug* not a *model-slug*.

### Migration policy

- **Do not rename existing files** (B01–B11 etc. keep their existing
  filenames for now; they are history).
- **All new files** going forward MUST use the `ID-slug.md` pattern with
  a task-hint slug.
- **The Boss** should proactively suggest renames for active bundles in
  flight if the slug is a model-name, but only when the rename is safe
  (no other agent is reading the old name).
- **The convention is enforceable** in `workflow.md` and in
  `../../../AGENTS.md` (the read-order preamble) so any new agent or fresh
  session reads it on startup.

### Why two ID types (B vs T)?

- **`B<NN>`** = *bundle*: a group of related subtasks the Boss dispatches
  in one prompt so the worker can run them serially without re-prompting.
  Used for Boss-orchestrated work. The agent runs the bundle, fills in
  per-subtask status, and reports back.
- **`T<NN>`** = *task*: a single research/implementation task. Usually
  spawns a fresh session for one specific work item.
- Both use the same `<slug>` rule.

