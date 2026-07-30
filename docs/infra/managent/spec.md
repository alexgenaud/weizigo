# managent — agent-manager specification

**A CLI tool for registering, claiming, and tracking subagent tasks.
Enforces dependencies (`needs`) and engine-file locks (`holds`); `set` is a
parallel-group label, not a gate.**

**ORCHA-AUTOMATION (2026-07-30):** stdout/stderr split, `--json`, `sync`, `audit`,
`standing`, `why`, attribution enforcement. See §"ORCHA-AUTOMATION commands" below.

**AGENT-IDENTITY (2026-07-29):** derived identifier (`<agent>/<task-id>[.attempt]`),
`whoami` command, identifier display in `status`/`show`/`why`/`--json`.

---

## Interface

Eighteen commands.

```
managent add <id>              register a task
managent dispatch <id>         record a human→agent dispatch (task stays dispatchable)
managent claim <id>            claim a task for execution
managent done <id>             mark a task complete
managent done <id> --fail      mark a task failed
managent reopen <id>           reopen a killed in_progress/failed task (→ dispatchable)
managent purge                 purge done/failed tasks (and clean their IDs from remaining needs)
managent set <id> <A|B|C|…>      reassign a task's phase set (A–Z)
managent needs <id> [--add…/--rm…]  add/remove dependency edges
managent agent <id> <name>     set the model/agent for a task
managent [status]              show current state (default command)
managent next                  claim the next available task
managent show <id>             show details for one task
managent whoami <id>           resolve agent identifier for a task
managent why <claim-id>        show tasks that produced evidence for a claim
managent sync <role>           print unread inbox; exit non-zero when write owed
managent audit [--json]        cross-check kanban against reality; exit 1 if FIX findings, 0 otherwise (WARN-only / clean)
managent standing              print standing-tier triggers and task status
```

### Output streams

**stdout = data.** `status`, `show`, `why`, `sync`, `audit`, `standing` write
their payload to stdout — anything a caller might parse, filter, or redirect.

**stderr = diagnostics.** Warnings, errors, `REJECTED`, `BLOCKED`, migration
notices, and progress chatter go to stderr.

Regression check: `status 2>/dev/null` is non-empty; `status 1>/dev/null` is
silent on a clean run.

---

## Bundle metadata

`managent add` reads metadata from the task's bundle file. The file is
found by globbing `untracked/<id>-*.md`. If multiple files match, the
first (sorted) is used. Override with `--bundle <path>`.

Metadata lives in an HTML comment on its own line near the top of the file:

```markdown
<!--managent set=C holds=src/retro.zig needs=B07 caps=reasoning:sustained-->
# B09 — auditor sensitivity test
```

Keys:

| Key | Required | Meaning |
|---|---|---|
| `set` | yes | **Parallel-group label** (any uppercase letter A–Z, arbitrary unique name). The only gates are `needs` and `holds`; sets do not order or gate (the lexicographic phase gate is retired). Use one set per parallel group; express all sequencing with `needs`. |
| `holds` | no | Space-separated file paths (relative to repo root) that need exclusive write access. If any `holds` are present, the task is automatically assigned to Set C. |
| `needs` | no | **Comma-separated** task IDs that must be `done` before this task can be claimed (e.g. `needs=2B-2,2B-3`). |
| `caps` | no | Space-separated capability tokens from the vocabulary in `docs/infra/delegation/ROLES.md` §4: `reasoning:sustained`, `independence:has-not-read-<X>`, `session:persistent`, `sub-delegation:yes`. Informational; used by `next` for filtering. **Most tasks declare none** — specify only what changes the outcome. (`isolation: exclusive <paths>` is not a `caps` token; that is what `holds` is.) |

**Context-window requirements are rejected.** A `context=500k` key lived here
until 2026-07-28; it specified nothing that changes an outcome, and it produced an
overspecified contradiction — a task demanding 500k assigned to a model with under
300k, unnoticed because the requirement was decorative. A task that only a
500k-context model can hold is a badly scoped brief: the fix is a smaller brief,
not a bigger model.

### ANALYSIS vs MUTATION — expressible only on the MUTATION side

`ROLES.md` §5 splits tasks into **ANALYSIS** (parallel and unlimited; writes
exactly one new file, never modifying an existing one) and **MUTATION** (serial;
may modify existing files; cites the analysis that recommended it).

This metadata expresses MUTATION: `holds=<paths>` declares the exclusive paths and
forces Set C, and since only one task per set may be in progress, that serialises
it; `needs=<analysis-id>` records the analysis it cites, and additionally blocks
the mutation until that analysis is `done`.

It **cannot** express ANALYSIS. `set` admits at most three in-progress tasks
(A/B/C), so "unlimited parallelism" has no encoding; and no key declares the one
new output path — `holds` means exclusive write access, and setting it would
wrongly serialise an analysis into Set C. Closing that gap is a design decision
for the OVERSEER and ADVISOR; no syntax is invented here.

---

## Commands in detail

### `managent add <id>`

Registers a task. Finds the bundle file by glob, parses its metadata.

With `--auto`, mints an opaque monotonic `T<N>` ID (e.g. `T099`) from the
counter stored in `_sys.next_id`, and derives the brief filename from the
bundle's title. Old-style IDs (non-`T`-prefixed) continue to work; new
tasks should use `--auto`.

```
$ managent add B09

  registered B09  [set: C, holds src/retro.zig]  [dispatchable]

$ managent add --auto --bundle docs/infra/dispatch/EXP-17.md --set A

  registered T100  [set: A]  [dispatchable]
  bundle: docs/infra/dispatch/EXP-17.md
```

Optional flags: `--auto` (mint opaque T<N> ID), `--bundle <path>` to
override path, `--set <A|B|C>` to override the metadata value,
`--needs <id>` to add an extra dependency.

If the task ID already exists: error. If no bundle file found: error.

---

### `managent claim <id>`

Claims a dispatchable task. Fails with a clear message if dependencies
are unmet or the parallel set is locked.

```
$ managent claim B09

  claimed B09  [set: C locked]
  follow untracked/B09-auditor-sensitivity.md

$ managent claim B10

  BLOCKED: B10 needs B07 (in progress)

$ managent claim B99

  REJECTED: set C is held by B09
```

Optional: `--agent <name>` to label who claimed it — a role or task label, never a
model name (`ROLES.md` §2).

### `managent dispatch <id> --to <agent> [--note <text>]`

Records the human→agent dispatch decision: a specific agent is *queued* for
this task. The task **stays in `dispatchable`**, the agent still claims it
via `managent claim <id>` per the existing protocol. This makes the dispatch
visible in `managent status` instead of only in the channel.

```
$ managent dispatch EXP-2B --to minimax-m3 --note "QA-023 gate computational half."

  dispatched EXP-2B  to minimax-m3  [set: A]
  awaiting claim by minimax-m3 (or another agent): managent claim EXP-2B
  note recorded (40 bytes)
```

**Required:** `--to <agent>`. The agent label is informational; any agent may
later claim the task via `managent claim <id> --agent <name>`. The dispatch
is the *queueing* signal, not an authorization.

**Optional:** `--note <text>` (≤ 4 KiB). Free-form context. Information, not a
substitute for any dedicated field. **Do not** use `--note` to record state
that has its own field (status, holds, needs, agent, dispatched_to). It is
for the *why* of the dispatch, recovery shape on resumption, or whatever else
would otherwise be lost in `untracked/msg/`.

**Warnings, not errors:** dispatching to a task that is `in_progress` or
`done` is recorded anyway and prints a warning. The audit trail is the
priority; the lifecycle is the lifecycle.

---

### `managent done <id>`

Reports task completion. Releases the set lock. Unblocks dependents.

```
$ managent done B09

  B09 done  [set: C released]  [unblocks: B10]

$ managent done B09 --fail

  B09 failed  [set: C released]
```

### `managent reopen <id>`

Reopens a task that was killed mid-attempt (status `in_progress` or `failed`)
back to `dispatchable`: clears `agent`/`claimed`/`done`, keeps
`dispatched`/`dispatched_to`/`note` as the audit trail (a re-dispatch
overwrites `dispatched_to`). The Orchestrator's D-8 tool for re-queueing a
console that was terminated without completing — the alternative (fail +
re-add) would orphan the `needs` edges of dependents. Not allowed on `done`
(a real completion is not re-queueable; mint a new task), `dispatchable`
(already claimable), or `blocked` (dependencies unmet).

```
$ managent reopen EXP-2B

  reopened EXP-2B  [set: A]  (was in_progress)
  follow docs/infra/dispatch/EXP-2B.md
```

### `managent purge`

Removes every `done` and `failed` task from the state file, and **removes the
purged IDs from every remaining task's `needs`** — so a dependent waiting on a
now-done prerequisite no longer displays or blocks on it (e.g. `EXP-4` with
`needs EXP-2 EXP-2B` becomes `needs EXP-2B` once `EXP-2` is done and purged).
The Orchestrator's D-8 declutter tool: done results are absorbed into the
durable docs (`CLAIMS.md` / `PROGRESS.md` / `model-perf.md`) and committed
before purging, so the task entry is no longer needed. Prints the purged IDs
and the tasks whose `needs` were cleaned. Run after a wave of completions.

```
$ managent purge

  purged 25 task(s): EXP-2 EXP-3 ... EXP-8
  cleaned needs of: EXP-4
```

### `managent set <id> <A|B|C|…>`

Reassign a task's phase set (any uppercase letter A–Z). Sets are sequential
phases: a task in set N may not start until every task in every earlier set
is done/failed; within a set, tasks run in parallel, gated only by `needs` and
`holds`. A strict chain gets one set per task (A, B, C, …). Use to fix a
mislabeled set without re-adding the task.

### `managent needs <id> [--add <dep>...] [--rm <dep>...]`

Add or remove a task's `needs` edges (deduplicated). Use to re-point a
dependent when the gate changes (e.g. `EXP-4 needs EXP-2B` →
`needs EXP-4 --rm EXP-2B --add 2B-4 --add 2B-5 --add 2B-6` when the monolithic
EXP-2B is replaced by the 2B-N micro-tasks).

---

### `managent` or `managent status`

Prints the current kanban. No arguments.

```
$ managent

  dispatchable (1)
    B10  follow untracked/B10-ko-census.md  [set: A, caps: reasoning:sustained]

  in progress (1)
    B09  worker  follow untracked/B09-auditor-sensitivity.md  [set: C, holds src/retro.zig]

  blocked (0)
    -- none --

  done (13)
    B01 B02 B03 B04 B05 B06 B07 B08 B11 B12 B13 B14

  failed
    -- none --
```

---

### `managent next`

Agent self-service. Claims the first dispatchable task whose `caps` the agent has
been told it satisfies; a task declaring no `caps` is eligible for anyone.

```
$ managent next --caps reasoning:sustained

  claimed B10  [set: A locked]
  follow untracked/B10-ko-census.md
```

If no matching task or the set is locked, prints nothing and exits 0.
The calling agent should retry.

---

### `managent show <id>`

```
$ managent show B09

  B09  in progress
    bundle:   untracked/B09-auditor-sensitivity.md
    set:      C
    holds:    src/retro.zig
    needs:    -- none --
    needed by: B10
    caps:     reasoning:sustained
    added:    2026-07-26 14:00
    claimed:  2026-07-26 16:00
```

---

## Task lifecycle (derived vs stored status)

```
  blocked ──→ dispatchable ──→ in_progress ──→ done
      ↑              │               │
      │              │               └── failed
      └── needs unmet
```

**`dispatchable` and `blocked` are derived from `needs`, not stored.**
After the `MANAGENT-DERIVE-STATUS` fix (2026-07-29), every invocation of
managent re-derives these two statuses from the needs graph.  They are
stored in `tasks.json` for display and persistence across commands, but
the authoritative value is computed by `deriveStatus()` on every read.

**`in_progress`, `done`, and `failed` are stored facts** — a claim happened
or a completion happened.  They are never derived from the graph.

### Warning for in-progress with unmet needs

If a task is `in_progress` but its `needs` are not all `done` (e.g. a
dependency was added via `needs --add` while the task was claimed), the
`status` command prints a loud warning:

```
  !! Unmet-dependency warnings (in_progress tasks):
     EXP-2B in progress but needs 2B-PROBE-FIX=done UNMETA=unknown
```

The task stays `in_progress` — we do not silently un-claim a live
console — but the kanban says so out loud.

### Migration on load

Every invocation runs a one-time migration that corrects any stored
`dispatchable`/`blocked` that disagrees with the needs graph.  Rows
that changed are printed on stderr:

```
  blocked ──→ dispatchable ──→ in_progress ──→ done
      ↑              │               │
      │              │               └── failed
      └── needs unmet
```

---

## State file

`docs/infra/managent/tasks.json` — a single JSON object, tracked by git
(survives fresh clone). managent is the only writer. Atomic writes via
temp-file + rename.

```json
{
  "B09": {
    "status": "in_progress",
    "agent": "worker",
    "bundle": "untracked/B09-auditor-sensitivity.md",
    "set": "C",
    "holds": ["src/retro.zig"],
    "needs": [],
    "caps": ["reasoning:sustained"],
    "added": "2026-07-26T14:00:00Z",
    "claimed": "2026-07-26T16:00:00Z",
    "done": null,
    "dispatched": "2026-07-26T15:30:00Z",
    "dispatched_to": "Fable5",
    "note": "QA-009 cross-check; Opus reviews adversarially."
  }
}
```

### Field semantics

| Field | Set by | When | Meaning |
|---|---|---|---|
| `status` | `add`, `claim`, `done`, (derived) | lifecycle + load-time migration | `dispatchable` / `in_progress` / `done` / `failed` / `blocked`. **`dispatchable` and `blocked` are derived from `needs` on every read** (see §"Derived vs stored status" above); the stored value may be overwritten by migration on load. `in_progress`, `done`, and `failed` are stored facts. |
| `agent` | `claim` | when claimed | model name of the agent that *claimed* (not the dispatched agent). Used by `agentIdentifier()` to form `<agent>/<task-id>` |
| `bundle` | `add` | registration | path to the brief |
| `set` | `add` | registration | parallelization group A/B/C |
| `holds` | `add` | registration | file paths the task writes exclusively |
| `needs` | `add` | registration | task IDs that must be `done` first |
| `caps` | `add` | registration | optional capability tokens (see `ROLES.md`) |
| `added` | `add` | registration | ISO-8601 timestamp |
| `claimed` | `claim` | when claimed | ISO-8601 timestamp |
| `done` | `done` | when completed | ISO-8601 timestamp |
| `dispatched` | `dispatch` | when dispatched | ISO-8601 timestamp of the human→agent dispatch |
| `dispatched_to` | `dispatch` | when dispatched | agent name (informational; the agent still claims) |
| `note` | `dispatch`, `add` | when recorded | free-form context, ≤ 4 KiB |
| `claim_count` | `claim` | incremented each claim | number of times claimed; when >1, identifier appends `.N` suffix |

**Identifier.** The agent identifier is derived, not stored: `<agent>/<task-id>`
(or `<agent>/<task-id>.<claim_count>` when claimed more than once). When `agent`
is unset the identifier is `unknown/<task-id>`, and `managent done` (non-fail)
refuses to close. See `managent whoami <id>`.

**`dispatched` and `dispatched_to` are not the same as `agent`.** The human
*dispatches* the task; the agent *claims* it. They may match (the dispatched
agent actually does the work) or differ (dispatched to X, claimed by Y
because X was busy / failed / not available). Both records are kept.

---

## Concurrency

`flock` on the state file for every read and write. Multiple shells may
invoke managent simultaneously from any directory in the repo.

The binary finds the repo root by walking up from cwd looking for `.git`.
State file path: `<root>/docs/infra/managent/tasks.json`.

---

## What managent does NOT do

- Does NOT spawn agent/harness sessions.
- Does NOT import any weizigo module.
- Does NOT know about user decisions (UD-1, UD-2, …); those stay in
  `docs/infra/delegation.md`.

---

## ORCHA-AUTOMATION commands (2026-07-30)

### `managent sync <role>`

Scans `untracked/msg/<milestone>/` for message files, prints the inbox
(unread messages addressed to `<role>` or `all`), prints the last message
`<role>` posted and the event count since, and exits non-zero when the gap
exceeds a threshold — "you owe a write."

```
$ managent sync orchestrator

  INBOX for 'orchestrator' (unread messages):
    M046  from dabir  to all
           subject line here

  LAST POSTED by 'orchestrator': M45
  events since: 1 new messages

  SYNC: 1 unread, 1 events since last post — you owe a write.
```

Read state is persisted in the `_sync` key of `tasks.json`.

### `managent audit [--json]`

Cross-checks the kanban against reality. Reports discrepancies:

- `in_progress`/`done` task with currently unmet `needs` → **gate it** (was claimed over an unmet dependency)
- `done` task with `agent == null` → **attribute it**
- `done` task whose `holds` paths are not in `git ls-files` → **commit these**
- `done` task claimed before a dependency was `done` (timestamp comparison) → **warn**: gated claim
- `in_progress` task with note containing "GATED" → **verify premise is still valid**
- `in_progress` task holding untracked `src/*.zig` → **snapshot before git clean -x**
- `dispatchable` task with unmet `needs` → **gate it**
- `blocked` task with all needs met → should be dispatchable
- Task note mentions claim-status change but cites no second seat → **warn**
- `zig-out/bin/managent` newer than `bin/managent` → **cp it**
- `CLAIMS.md` has uncommitted changes but last commit cites no second seat → **verify before commit**

Exits non-zero when FIX-level findings exist. `--json` outputs a JSON array
of findings.

### `managent standing`

Checks the four standing-tier triggers and **auto-registers** any that fired
(creating the brief file and adding the task to the kanban). Triggers:

- **STANDING-HOLISTIC-AUDIT** — milestone shape changes (new message directory)
- **STANDING-CLEANUP** — tree dirty across two turns (git diff --stat > 0 on consecutive runs)
- **STANDING-REEVIDENCE** — claimlint C3 debt grows
- **STANDING-CONSOLIDATE** — any new falsification (FALSE-AS-SCOPED count increased)

Trigger state is persisted in the `_standing` key of `tasks.json`. Each
template brief lives in `docs/infra/dispatch/STANDING-*.md`.

### `managent why <claim-id>`

Search the kanban for tasks that reference a claim ID (in their bundle path,
note, or task ID). Prints each task's status, agent, bundle, and completion
 timestamp. Deterministic; no summarisation by model.

### Attribution enforcement

`managent done <id>` **refuses** (exits non-zero) when `agent` is unset.
The caller must either have claimed with `--agent <worker>`, or supply
`--agent <worker>` on the `done` command. `--fail` is exempt (a failed
task may not have been attributed).

### Commit-before-purge guard

`managent purge` refuses if any `done`/`failed` task's `holds` paths are
not tracked by git (`git ls-files`). The Orchestrator must commit before
purging — the guard makes the prescription mechanical.

### `--json` flag

`status --json` and `audit --json` output JSON arrays to stdout for
machine consumption.

---

## Acceptance criteria

1. `add B09` finds `untracked/B09-*.md`, parses metadata, registers task.
2. `add <id>` with duplicate ID is rejected.
3. `claim <id>` succeeds for dispatchable task; prints bundle path.
4. `claim <id>` fails with "BLOCKED" when dependency not done.
5. `claim <id>` fails with "REJECTED" when set locked.
6. `done <id>` releases set; dependents become dispatchable.
7. `done --fail` releases set; dependents stay blocked.
8. `managent` (no args) prints human-readable status.
9. `next --caps reasoning:sustained` claims a task requiring
   `caps=reasoning:sustained` and skips one requiring `caps=session:persistent`.
10. `next` claims first eligible task or silently exits 0.
11. Two concurrent `claim` for same set: only one succeeds.
12. `show <id>` prints all fields.
13. State file survives process crash (atomic write).
14. `dispatch <id> --to <agent>` records `dispatched` + `dispatched_to`; status stays `dispatchable`.
15. `dispatch <id> --note <text>` records `note` (≤ 4 KiB) and shows it in `show <id>`.
