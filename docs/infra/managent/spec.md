# managent — agent-manager specification

**A CLI tool for registering, claiming, and tracking subagent tasks.
Enforces dependencies, parallel-set exclusion, and engine-file locks.**

---

## Interface

Six commands. Four have zero required flags in daily use.

```
managent add <id>              register a task
managent claim <id>            claim a task for execution
managent done <id>             mark a task complete
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

---

### `managent done <id>`

Reports task completion. Releases the set lock. Unblocks dependents.

```
$ managent done B09

  B09 done  [set: C released]  [unblocks: B10]

$ managent done B09 --fail

  B09 failed  [set: C released]
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
    "done": null
  }
}
```

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
