# Fleet git isolation — the shared `.git/index` hazard, mechanized (T278)

**Task:** T278 · **Role:** worker · **Model:** deepseek-v4-flash · **Date:** 2026-08-02
**Set:** B · **Verdict:** pass-with-findings (see Findings) · **Status:** recommendation
PROVEN by its controls; adoption pending the Orchestrator's second seat.

## 1. The failure class

Seven consoles share one `.git/index`. On 2026-08-02 the shared index produced
three incidents in one session:

| # | incident | commit | mechanism |
|---|---|---|---|
| 1 | T268's amendment absorbed T272's staged files (`src/claimlint.zig`, `tools/regression-precommit.sh`, `tools/hooks/`, `findings/T272-gate-hook.json`, `docs/infra/roles/ARGUS.md`, `findings/rejections.json`) | `f74012b` | `git commit` over a polluted index — content right, attribution wrong |
| 2 | The Orchestrator's own `git add -A docs/` swept two of T266's evidence files | `91f7cf3` | pathless add + commit — the seat that polices the rule broke it |
| 3 | A repair attempt briefly orphaned `5f87b5b` (T274) | — | `git reset`/`rebase` repair under concurrency; recovered via reflog |

The common class is **absorption**: content staged by one console lands in
another console's commit under another console's message. The prose rule
("name every path you commit") is in DELEGATEE.md and failed three times the day
it was needed. GRAND-AUDIT §4 is the standing warning: prose rules rot. This
document evaluates four mechanisms that make the hazard structurally impossible
— with a measurement for each — and recommends one. What is not acceptable is a
third prose rule.

## 2. The four options, evaluated

### 2.1 Per-agent git worktrees (`git worktree add`) — strongest isolation, highest cost

Each worktree has its own index (`.git/worktrees/<name>/index`), so `git add -A`
in one tree cannot see another tree's staged content. This catches incidents 1
and 2 *structurally* — the foreign content is physically unreachable.

Costs, measured against this project's actual substrate:

- **The kanban fragments.** `docs/infra/managent/tasks.json` lives in the
  working tree. A worktree is a separate checkout — every console would get its
  own copy of the kanban, and `managent` state would diverge per console
  (unless the store is symlinked or `MANAGENT_STORE` points at the main tree,
  which nothing enforces). The kanban is the attribution ledger; a split-brain
  ledger is a *worse* failure than a polluted index, and the audit machinery
  does not cover it.
- **A merge step becomes a new attribution surface.** The Orchestrator merges
  N branches; a careless merge is exactly the incident-2 class moved one step
  later.
- **Disk and discipline:** each tree is a full checkout; workers must not
  `cd` out of their tree (one more prose rule, in a scheme that exists to end
  prose rules).
- **The runner needs to know:** `tools/runner` walks the process tree of the
  command and measures RSS/wall/CPU — worktree-agnostic, no change. But
  `bin/subagent` computes `ROOT` from its own location and dispatches there; a
  worker in a worktree would need the dispatcher to know the tree layout.

**Verdict: ruled out.** The isolation is real but the kanban-fragmentation
hazard is a new, unattended failure class, and the merge step re-introduces the
very absorption it removes. The brief explicitly permits the answer "worktrees
are not worth it, with a measurement behind it" — the measurement here is that
the project's *state* (kanban) is more load-bearing than its *staging area*, and
worktrees isolate the second while risking the first.

### 2.2 A commit wrapper (`tools/git-commit-mine`) — recommended

The mechanism: a single script that **stages only the named paths, verifies the
staged set contains nothing outside the caller's declared scope, refuses
otherwise naming the foreign paths, commits only after that verification, and
verifies the commit contains exactly the named paths**. Details and controls in
§4. Against the three incidents:

- Incident 1: T268's `git commit` over a polluted index is impossible through
  the wrapper — a polluted index is *refused* (the exact seeded fixture, §4.2),
  and even in the Orchestrator's `--explicit` mode the commit is path-limited
  so foreign content cannot enter it (verified, §4.3).
- Incident 2: `git add -A` never happens through the wrapper — pathless
  invocation is refused (§4.5). The Orchestrator names paths explicitly; the
  wrapper then commits exactly those.
- Incident 3 (repair): the wrapper never resets or rebases — there is nothing
  to repair, because there is nothing to absorb.

Identity: the wrapper needs to know *whose* scope applies. Resolved from
`--task <id>`, `--bundle <file>`, or `$MANAGENT_TASK_ID` (see §2.4 for why the
env var is the right channel). Without identity it requires `--explicit` and
warns loudly — the designed user of that mode is the Orchestrator's
cross-cutting integration commits.

**Verdict: recommended.** Cheapest option (one POSIX script, no build, no git
plumbing), catches all three incidents, works for every seat, and — the
anti-rot property — the refusal and the path-limited commit are *mechanical*,
not behavioural.

### 2.3 A pre-commit check (inside the T272 hook) — closest runner-up, two real holes

The idea: refuse any commit whose staged paths are not a subset of the
committing task's declared deliverables plus its findings files. The brief asks
the two hard questions; here are the answers:

- **How does the hook know which task is committing?** Only a per-console env
  var is robust when two tasks are in progress: `MANAGENT_TASK_ID` is already
  the project's per-console identity channel (the runner honors it as the
  `--task-id` fallback; `bin/subagent` now sets it for dispatched workers,
  §4.6). `managent whoami` looks up an *identifier* from a task ID — it cannot
  tell the hook who is running, and a claimed-task lookup is ambiguous the
  moment two tasks are in progress and one console is committing files that
  another console declared. **With the env var, two in-progress tasks are not a
  problem** — each console carries its own identity.
- **The Orchestrator hole:** the hook cannot see `git commit`'s path arguments
  (the pre-commit hook receives none), so it cannot verify the Orchestrator's
  explicit-path discipline. The Orchestrator's scope is genuinely "anything"
  (integration commits absorb other agents' work by design — e.g. `f9469d1`),
  so the subset rule either blocks the Orchestrator or needs an escape hatch
  (`--no-verify` or a wildcard identity) — and every escape hatch is the rot
  point the mechanism exists to close.
- **It is not even installed.** `core.hooksPath` is unset today; the T272 hook
  sits in `tools/hooks/pre-commit` unused (CURRENT.md: "there is no gate
  today"; installation is T280's job, pending fixed controls). A mechanism that
  requires a *new* install step to be trusted has a worse deployment record in
  this project than a self-contained script.

**Verdict: ruled out as primary** — the Orchestrator hole and the uninstalled
hook make it weaker than the wrapper at deployment, and its only advantage over
the wrapper (it cannot be bypassed by forgetting) is purchased at the cost of
blocking or escape-hatching the seat that caused incident 2. Noted as a
possible follow-up hardening (§6) once T280 lands.

### 2.4 Serialize commits (advisory lock) — addresses the wrong failure mode

A commit lock (e.g. `flock` on a lockfile, acquired in a hook or wrapper)
converts a *corruption* hazard into a wait: two consoles can no longer write
`.git/index` concurrently. But **incidents 1 and 2 were absorption, not
corruption** — under a serialized commit, T272's staged files would still be in
the index when T268 commits, and would still land in `f74012b` under T268's
message. The lock serializes the commit; it does not scope the content. It
catches none of the three incidents and adds a wait on top. (The brief's own
description is honest: "it converts a corruption hazard into a wait" — there
was no corruption in any of the three incidents.)

**Verdict: ruled out.** It is the only option that catches none of the
incidents. The wrapper's *refusal* (identity mode) already provides the
valuable part — fleet-level serialization at the moment it matters (a genuinely
polluted index) — without the cost of locking every commit.

## 3. The adjacent defect in the same class: `managent done` reads the filesystem, not git

`managent done`'s deliverable check used `statFile` on each declared path.
T272 closed `pass` on 2026-08-02 with all deliverables untracked or uncommitted
— the check saw the files and passed. A deliverable that is not in git is not a
deliverable (AGENTS.md; the same mechanism that destroyed T13's evidence).

**Fixed (this task):** the check now asks git (`src/managent/main.zig`,
`cmdDone`). At close time, each declared path is verified against the index and
the worktree, and refused with the offending paths named otherwise. The two
edge cases the brief required rulings on:

- **A deliberately-untracked deliverable** (a large `.wzo` under `untracked/`):
  **accepted** if it is a retention-rule artifact per ARGUS T211 — path under
  `untracked/` *and* SHA-256 pinned in `artifacts/SHA256SUMS`. Retention-rule
  artifacts are legitimate non-git deliverables by design (they are too large
  to commit; their hashes make them verifiable). An untracked file that is NOT
  pinned is refused: "untracked — commit it".
- **A task that legitimately deletes a file:** the deliverable *is* the
  removal. **Accepted** only once the deletion is committed — `git log
  --diff-filter=D` records it (reason: "deleted in git history"). A staged but
  uncommitted deletion is **refused** ("deletion staged but not committed"),
  consistent with the committed-only rule; a file deleted on disk with the
  deletion unstaged is refused too.

The full decision table and both controls (null + seeded, naming the path) are
in §4.7; the retained-rule and deletion arms are exercised there as well.

## 4. The mechanism, its controls, and the runs

### 4.1 The wrapper's guarantees

`tools/git-commit-mine <paths…> -m <msg> [--task <id> | --bundle <file> | --explicit]`:

1. **Pathless invocation refused** — the `add -A` habit dies at the commit site.
2. **Only the named paths are staged** (`git add -- <paths>`), then the staged
   set is verified against (scope ∪ named paths). Scope for a task = its
   bundle's `deliverables=` meta header ∪ `findings/<id>-*.json` ∪ the two
   fleet-coordination surfaces (`docs/status/CURRENT.md`,
   `docs/status/HANDOVER.md` — any worker may legitimately touch these).
3. **Foreign staged paths → refused**, naming each, with the instruction to
   never unstage another console's work. (In `--explicit` mode — the
   Orchestrator's integration commits — the commit is path-limited instead,
   which is mechanically immune: foreign content cannot enter it.)
4. **Identity-mode scope check:** a named path outside the declared scope is
   refused, naming it. The escape for genuine need is `--explicit`.
5. **Verify-after:** the created commit is checked to contain exactly the named
   paths; a mismatch fails loudly.

### 4.2 Seeded-defect control — incident 1 reproduced (the fixture)

`tools/regression-git-commit-mine.sh` builds a scratch repo in `/tmp/weizigo`
and reproduces incident 1 exactly as it happened: **two staged sets, one
commit**. Set 1 is `src/claimlint.zig` staged (T272's console); set 2 is
`docs/amendment2.md` (T268's own work). The wrapper is then invoked for set 2.

Result (run 2026-08-02, `bash tools/regression-git-commit-mine.sh`, all 5 arms
PASS):

```
2. seeded control: incident 1 — two staged sets, one commit
   PASS: refused, named src/claimlint.zig, no commit created
   PASS: both staged sets intact, foreign content untouched
```

The refusal is a hard exit 1; the commit count is unchanged; both staged sets
survive with content intact. If T268 had used the wrapper, `f74012b` could not
have happened.

### 4.3 Null control and the explicit arm

```
1. null control: legit single-task commit
   PASS: commit bd85f3e contains exactly docs/amendment.md
3. explicit arm: foreign staged content present, commit is path-limited
   PASS: commit 8e436a3 contains only docs/amendment2.md
   PASS: foreign path still staged and untouched
```

The explicit arm is where the first cut of the wrapper was caught by its own
fixture: it used a plain `git commit` after warning, and the commit absorbed
the foreign staged files (3 files in one commit). The fix — a path-limited
`git commit -- <paths>` whenever foreign content is present — is what makes the
commit mechanically immune, and the fixture now asserts it.

### 4.4 The scope arm and the pathless arm

```
4. scope arm: path outside declared deliverables
   PASS: refused, naming docs/other.md as outside the declared scope
5. pathless arm: no paths -> refused
   PASS: pathless invocation refused
```

### 4.5 Cost of the refusal in a fleet

The refusal (identity mode) is the one cost the brief asked to be honest
about: a worker cannot commit while another console has staged files. In
practice the window is seconds (between another console's `git add` and its
`git commit`), and the refusal *is* the fleet serialization — scoped to the
moment it matters, instead of every commit (§2.4). The alternative — warning
and proceeding — is exactly how the first wrapper cut absorbed foreign files,
so the refusal is kept. Workers resolve it by waiting; they must never unstage
another console's work.

### 4.6 Identity plumbing — the one infrastructure change

`bin/subagent` now sets `MANAGENT_TASK_ID` in the dispatched worker's
environment (verified: `python3 -c ast.parse` OK, dry-run dispatch works). The
runner already honors the variable as the `--task-id` fallback. Human-launched
consoles export it per session (documented in §5). This answers the brief's
sub-question: the runner does **not** need to know about worktrees (not
recommending them); `bin/subagent` needed the one-line identity handover so a
dispatched worker's commit scope can be checked automatically.

### 4.7 The `done` check controls

`tools/regression-managent-done-git.sh` builds a scratch repo + scratch kanban
(`MANAGENT_STORE`) — the live kanban is never touched — and runs five arms
against the rebuilt `bin/managent` (stamp `05dae9b-dirty`, built 2026-08-02 via
`tools/runner --no-prepend-zig -- zig build -Doptimize=ReleaseSafe`):

```
1. null control: committed deliverables close normally            PASS (RC=0)
2. seeded: untracked deliverable refused, naming docs/seed.md    PASS (RC≠0)
3. seeded: modified deliverable refused, naming docs/mod.md      PASS (RC≠0)
4. retention: SHA256SUMS-pinned untracked/ artifact closes       PASS (RC=0)
5. deletion: staged deletion refused; committed deletion closes  PASS (both)
```

Each refusal names the offending path and leaves the task `in_progress`. The
two pre-existing managent regressions (`regression-managent-integrity.sh`,
`regression-managent-memory-safety.sh`) both PASS against the rebuilt binary
(run 2026-08-02).

## 5. Cost, stated honestly

- **One new script** (`tools/git-commit-mine`, ~150 lines of POSIX/bash) and
  **two regression scripts**; **one function re-written** in
  `src/managent/main.zig` (deliverable check, `cmdDone`) — rebuilt via the
  runner and deployed with the remove-copy-sign recipe; **one env-var line** in
  `bin/subagent`.
- **The refusal cost** (§4.5): a worker's commit can be blocked by another
  console's staged files, resolved by waiting. Bounded, and only when the index
  is genuinely polluted.
- **The discipline cost**: workers must invoke the wrapper instead of raw
  `git commit`. This is the same adoption burden as `tools/runner` for builds —
  which this project made mandatory and does not bypass.
- **What the wrapper does NOT do**: it cannot stop a worker who bypasses it
  entirely (a pre-commit gate could; see §2.3 for why that option was not
  chosen — the Orchestrator hole and the uninstalled hook — and §6 for the
  follow-up). It does not touch worktrees, branches, or the merge surface.

## 6. Follow-ups

- **T280** — install the T272 pre-commit hook (`core.hooksPath tools/hooks`)
  after its controls are fixed; a staged-path-subset check could then ride it
  as the bypass-proof backstop for *workers* (env-var identity, §2.3), with the
  wrapper remaining the Orchestrator's path-limited tool.
- **Adoption decision** (Orchestrator): make the wrapper the documented commit
  ritual in DELEGATEE.md §"Committing while a fleet is running" and require
  `MANAGENT_TASK_ID` export for human-launched consoles.
- **Deletion edge:** the `git log --diff-filter=D` acceptance (§3) is a
  history probe — a path deleted in an *old* commit would pass vacuously if
  redeclared. Ruled acceptable (the deliverable *is* the removal); flagging for
  the auditor.

## Provenance

| field | value |
|---|---|
| Author | T278 (deepseek-v4-flash) |
| Date | 2026-08-02 |
| Brief | `untracked/T278-fleet-git-isolation.md` |
| Controls (wrapper) | `tools/regression-git-commit-mine.sh` — all 5 arms PASS |
| Controls (done check) | `tools/regression-managent-done-git.sh` — all 5 arms PASS |
| Pre-existing regressions | integrity + memory-safety — PASS on rebuilt `bin/managent` `05dae9b` |
| Evidence | the regression scripts (in git); the scratch fixtures run under `/tmp/weizigo/` |
| Related | DELEGATEE.md §"Committing while a fleet is running"; CURRENT.md T278 block; `f9469d1` (T272 gate landed, not accepted) |
