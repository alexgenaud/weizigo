# RESUME — orchestration seat, written 2026-08-24 against a heavy context

**Read this first if the seat was cleared, compacted, or handed over.** It is written to be
sufficient on its own. `docs/status/handover-orcha-2026-08-24.md` has the task-by-task division;
`docs/status/OPEN.md` has owed decisions and known issues; this file is what a successor needs in
the first five minutes.

## Standing operator orders (2026-08-24) — these bind the seat

- **Reserve Fable.** Standing.
- **Use oxalpha liberally.** Standing. Credit is effectively unlimited; race it against everything.
- **Probe qwen infrequently.** A convenience, not a priority.
- **All other models get roughly equal opportunity.** Do not let habit concentrate work.
- **Steady pace over parallelism.** Run more serially even where tasks could run conflict-free.
- Contact protocol: `docs/infra/discuss.md` — recap in human words, **one** decision per ask, stop.
  He tracks nothing between messages. Bring only what he alone can decide.

## Do these before believing anything

1. **`bin/managent reap`.** Sixteen tasks once read as in flight while zero were alive.
2. **Check the store did not shrink.** `tasks.json` silently reverted to a pre-T785 snapshot on
   2026-08-24 and lost **59 tasks**; repaired at `67780db` by re-registering from briefs. There is
   still **no detector**. Compare the task count against the last commit before trusting the queue.
   This is the single most dangerous defect in the fleet — S10 (T846) specs the alarm.
3. **`git status` may be unreliable mid-read.** The shared index is churned by concurrent consoles;
   it has reported a tracked file as untracked, as staged-for-deletion, and refused adds with
   "beyond a symbolic link" — all transient, all false. **Re-read before acting on a git anomaly.**
   Three of my own readings today were wrong for this reason.

## Live quota facts (2026-08-24 ~10:00 local)

| family | state |
|---|---|
| **ollama** | **100% of the 5-hour window consumed**, resets ~11:00 local; 17.8% weekly. All three ollama workers died simultaneously when it hit. **Do not dispatch ollama until reset**, then one at a time. |
| **claude** | ~21% of the 5-hour window, 4h to reset; a significant fraction of the weekly. Returned `provider-429` earlier at only 4 runs — upstream strain, not our volume. Use, but not for bulk. |
| **deepseek** | 124M tokens / 807 requests today, no recorded ceiling. The bulk workhorse. |
| **oxalpha** | effectively unlimited. **Prefer it.** |

## The minimax lesson — act on this before re-enabling ollama

In one 5-hour window `minimax-m3` took **790 of ~792 requests, ran 2,902 s and produced nothing**,
while `glm-5.2` and `kimi-k2.7` got **one request each**. It starved its own family. A per-*family*
cap cannot prevent that — it needs a **per-model request budget**. glm did deliver a 25.8 KB patch
before dying (`untracked/ratrace/T840.patch`, copy preserved as `.delivered-before-death`), and the
dispatcher self-healed all three back to dispatchable — **correct recovery, but the reopened tasks
carried no record that usable work already existed on disk.** Recovery works; partial-delivery
preservation does not. That sentence is the fault-tolerance gap and it is evidence for S10.

## What is in flight and what it means

Races whose judging needs the outgoing seat's context (see the handover doc): the **diff race**
(T826–T831 → T832), the **rate race** (T838–T842 → T843/T844), the **corpus three-way** (T817/T818/
T820 → T819), plus closing **T818** and **T822**.

`S10` (**T846**, dispatched) is the failure-transparency sprint spec. Its ratified direction, decided
after weighing four options: **the close COMPUTES the verdict from checked acceptance conditions
rather than accepting the worker's assertion; what cannot be checked is recorded as a first-class
`unverified` outcome; the close is never refused except where deliverables are declared and absent.**
Reason: a refused close leaves `in_progress`, indistinguishable from a live worker — a verdict that
cannot be recorded is a lie of a different kind. The operator bookends that spec before pass 1.

## Gates that now exist and will refuse you

- **Caps** (T845, live): `bin/dispatch` honours `FLEET_CAP` / `FLEET_FAMILY_CAP` and refuses over
  them, with `--override-cap=<reason>` recorded to `untracked/fleet-cap-overrides.jsonl`. It
  refused the seat on its first live test; the seat did not override. Neither should you, casually.
- **Volatile citations** (T814): a new citation to `untracked/` or `/tmp/` **fails the commit**.
  Cite committed artifacts. Three consoles hit this on day one, the seat among them.
- **Test gate** (T789, live): `pre-commit … test gate: PASS (37s, budget 45s)`.
- **Titles over 40 characters are refused at dispatch.** It will bite you twice.
- **`managent done` takes `--status`, not `--verdict`** — an unrecognized flag is silently ignored
  and the verdict defaults to `pass`.

## Highest-value work, in order

1. **A store-loss detector** (in S10). Everything else is built on a record that can vanish.
2. **A per-model request budget** — the minimax lesson, before ollama returns.
3. **S06 passes 1 and 3–6** — shape ratified; interleave ordinary work through the changed
   mechanism between passes, and a pass is complete only when that work closes cleanly.
4. **The epistemic arc**: T836 (board proof census: proven vs optimal vs unknown per board size)
   then T837 (C3's 42 unbacked proofs). C2 is already **0**.

## THE INCIDENT — read this before touching git (2026-08-24)

The repository was silently repointed at a scratch directory **twice in thirty minutes**.

**Mechanism.** `tools/hooks/pre-commit` runs `tools/regression-managent-landmark.sh`, which
`mktemp`s a scratch dir and runs `git init` there. **58 regression scripts run `git init`; none
unsets `GIT_DIR`** — and git sets `GIT_DIR` for hooks. So a scratch init reinitialised the real
repository and left `core.worktree` pointing at `/tmp`. Every console's git then resolved against
the wrong tree. Commits truncated **2,556 files to 4**. The task store was overwritten with a stale
snapshot and **59 tasks vanished**.

**This is the mechanism behind every "tasks vanished" incident**, which the operator had said
happens often and is only ever noticed when he wonders why specified work is not done. It began the
day the test gate was wired into pre-commit — *we built the thing that broke it.*

**Two guards now exist, both demonstrated red-then-green:**
- `WEIZIGO_GITENV_ISOLATION` in `tools/hooks/pre-commit` — unsets `GIT_DIR`, `GIT_WORK_TREE`,
  `GIT_INDEX_FILE`, `GIT_OBJECT_DIRECTORY`, `GIT_NAMESPACE` before running anything, so a child's
  `git init` cannot reach back into this repo. One line, covers all 58 scripts.
- `WEIZIGO_WORKTREE_GUARD` in `tools/git-commit-mine` — refuses if `core.worktree` is set, and
  refuses to commit onto a HEAD holding fewer than 2,000 files. The second half is what turns a
  config error into a caught error instead of silent data loss.

**After every commit, verify:** `git rev-parse --show-toplevel` is this repo, and
`git ls-tree -r --name-only HEAD | wc -l` is >2000. If either fails, stop.

**Errors the outgoing seat made under context pressure, recorded so they are not repeated:**
moving `main` onto a truncated 6-file tree without checking the tree size; claiming appetite was a
structural blocker when `bin/dispatch` never consults it; and three git readings taken from an
index another console was mid-write on, each reported confidently and each wrong.

## Simplification done 2026-08-24 (the operator's standing instruction)

*"Assume everything is a vibe hack and cautiously improve and simplify."*

Removed: **10 of 11 git worktrees** (scratch copies of races finished days ago, and the vector for
the hijack); a **`watch-fleet-live.sh` running 10h43m** from an integration-test scratch dir; the
malformed task literally named `--bundle`; the **`com.weizigo.suite-truth` launchd agent**
(`StartInterval 86400`, ran the full suite daily and unattended — **disabled**, and T847 must rule
on whether it returns).

**Still unjustified, for T847:** 58 `git init` regression scripts · six ways to run tests · four
places kill records live, only the tracked one empty · two task stores · `untracked/` with 800+
files · `/private/tmp/weizigo/race-t447` which refuses to be removed.

## Live state at handover

`T847` is the **single** worker running: the end-to-end moving-parts inventory. Nothing else is
dispatched. Ollama resets ~11:00 local. The store holds 470 tasks. HEAD is intact at 2,564 files.
Five tasks whose verdicts were lost in the revert were closed **on evidence** (exit=0 plus
deliverables on disk), not reaped as abandoned — abandoning completed work would have been a second
falsification on top of the first.
