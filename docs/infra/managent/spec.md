# managent — agent-manager specification

**A CLI tool for registering, claiming, and tracking subagent tasks.
Enforces dependencies, parallel-set exclusion, and engine-file locks.**

---

## Interface

Nine commands. Five have zero required flags in daily use.

```
managent add <id>              register a task
managent dispatch <id>         record a human→agent dispatch (task stays dispatchable)
managent claim <id>            claim a task for execution
managent done <id>             mark a task complete
managent reopen <id>           reopen a killed in_progress/failed task (→ dispatchable)
managent purge                 purge done/failed tasks (and clean their IDs from remaining needs)
managent [status]              show current state (default command)
managent next                  claim the next available task
managent show <id>             show details for one task
```

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
| `set` | yes | Parallelization group: `A`, `B`, or `C`. Only one task per set may be in-progress. |
| `holds` | no | Space-separated file paths (relative to repo root) that need exclusive write access. If any `holds` are present, the task is automatically assigned to Set C. |
| `needs` | no | Space-separated task IDs that must be `done` before this task can be claimed. |
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

```
$ managent add B09

  registered B09  [set: C, holds src/retro.zig]  [dispatchable]

$ managent add B10

  registered B10  [set: A]  [blocked: needs B07]
```

Optional flags: `--bundle <path>` to override path, `--set <A|B|C>` to
override the metadata value, `--needs <id>` to add an extra dependency.

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

---

### `managent` or `managent status`

Prints the current board. No arguments.

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

## Task lifecycle

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
| `status` | `add`, `claim`, `done` | lifecycle | `dispatchable` / `in_progress` / `done` / `failed` / `blocked` |
| `agent` | `claim` | when claimed | role or model label of the agent that *claimed* (not the agent that was dispatched) |
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
