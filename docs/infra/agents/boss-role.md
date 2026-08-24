# Boss role — RETIRED 2026-07-28 (four items kept below)

The orchestrator's job is now **`docs/infra/delegation/DELEGATOR.md`** (how to write a task
nobody can execute wrongly: the nine-line brief header, costing the method, a test that can
fail, a named reviewer, heartbeats, model fit) plus **`docs/infra/dispatch/README.md`** (the
live experiment graph, concurrency rules, definition of done, escalation) and the seat allocation in the kanban `agent` fields + `model-perf.md`.

**Dropped as obsolete** — if any of this is still wanted, say so:
the `B<NN>`/`T<NN>` bundle-filename convention and its migration policy; the one-line ~50-char
dispatch prompt format (`fresh|warm <Agent>: follow untracked/<file>`); the "provide prompts only
for dispatchable tasks" timing rule; the two agent-lifecycle sections (models are disposable
sessions, not individuals); the precondition/integration/night-run protocols (now the brief
header's `BLOCKS / BLOCKED BY`, the heartbeat rule, and the dispatch README); "fail fast and
halt"; "delegate, don't implement"; "the user's real worry" (every claim PROVEN / CLAIMED /
FALSE-AS-SCOPED — now in `AGENTS.md`).

**Line-number citations into this file are now stale.** `docs/evidence/README.md` cites
`boss-role.md:212` (the model-performance ledger) and `boss-role.md:267,271` (the B-bundle
dispatch lines); both pointed into the 298-line version, recoverable with
`git show e94b107:docs/infra/agents/boss-role.md`. Those citations were left untouched on purpose
— they are deliberate records of destroyed evidence, not links to repair.

## Kept: decision hygiene

- **Do not ask the user a question you can answer yourself.** With enough information, decide,
  and record the rationale in the commit and the findings file (`findings/<task-id>-<slug>.json`) — and in an ADR if durable.
- **When you genuinely lack information, ask one focused question, not a menu** — with a
  recommended default.

## Kept: backlog depth and worker routing

There must always be more tasks than agents, each a fail-fast chunk (≲1 hour wall time) with
preconditions, an acceptance test and an owner. Do not route all implementation to whichever
agent succeeded last: if a task is file-independent or read-only, give it to the first available
agent, using demonstrated strengths as a tie-breaker rather than a default.

## Kept: worktree policy (still current)

Worktrees are **not used**. One-writer-per-engine-file, unique binary names, and
`/tmp/weizigo-zigcache` isolation suffice for ≤3 concurrent mutation/build agents (analysis
parallelises without limit — see `docs/infra/delegation/ROLES.md` §Concurrency). **Reconsider if:**
the team scales past 3 concurrent mutation/build agents; two agents need long engine builds on
different branches at once; or we need to
compare byte-identical artifact outputs side by side. If adopted, use a shared read-only artifact
cache so 258 MB `.wzo` files are not duplicated.

## Kept: the quality ledger

Record each agent's per-task performance, dated and specific, in `docs/infra/model-perf.md`.
