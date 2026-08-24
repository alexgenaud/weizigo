# Moving-parts inventory — every part, one row, one verdict

**Task:** T847 · **Worker:** deepseek-v4-pro/T847 · **Date:** 2026-08-24 ·
**Landmark:** advances L1 (the dashboard tells the truth) — the fleet becomes something a person
can hold in their head.

**Operator's ruling this task answers:** *"There are too many weird moving parts … Assume
everything is a vibe hack and cautiously improve and simplify."*

**How to read the verdicts.** `UNKNOWN` in *what it is for* is a finding, not a gap to fill.
`DELETE`/`NEEDS-OPERATOR-RULING` on a part with a live caller is a proposal, not an action taken
unless §Deletions says it was. Column "who invokes it" = a person, a hook, a schedule, another
script, or **nothing**.

---

## 1. Background processes and schedulers

| what it is | what it is for | who/what invokes it | when it last did something | blast radius | verdict |
|---|---|---|---|---|---|
| `tools/fleet-keeper.sh` loop — pid 99956, **ppid 1** (detached orphan), up 3d16h since Aug 20 17:20 | auto-dispatches eligible tasks to keep the fleet full (one-writer invariant, logjam pressure, fleet cap) | started **manually** by a console; **not** launchd-managed (the `com.weizigo.fleet-keeper` plist exists but is **not loaded**) | 2026-08-24 ~10:17, writing `at cap (2/1) — no dispatch` to the keeper log (under `untracked/log/`) | if it dies or the cooldown flag is set, the fleet **sits idle and nothing alarms** — and as ppid 1 nothing supervises it | **KEEP-BUT-FIX** (supervise it, or an idle fleet is silent) |
| `com.weizigo.suite-truth` launchd agent (`~/Library/LaunchAgents/com.weizigo.suite-truth.plist`, `StartInterval 86400`) | nightly full-suite truth run; writes the suite verdict (under `untracked/test-gate/`) so a red suite is visible on every commit | launchd — **unloaded/disabled by the seat on 2026-08-24** | never since disabled (plist last touched Aug 23 23:42) | if it never runs, a nightly red is never discovered by a machine | **NEEDS-OPERATOR-RULING** — see §The suite-truth agent below |
| `com.weizigo.fleet-keeper` launchd plist (`tools/weizigo.fleet-keeper.plist`) | the launchd wrapper for the keeper | launchd — **not loaded** (the keeper runs manually instead) | never | two ways to start the keeper = drift; only one is actually used | **KEEP-BUT-FIX** — reconcile: run under launchd **or** delete the plist |
| `watch-fleet.sh` operator console view — pid 71324 (running from `untracked/`, ppid 66127, since 09:40) | human-readable fleet dashboard (PROGRESS/CONCERNS/RECENT/DONE/OPEN), 10 s refresh | the human, in a terminal | live (writes `.fleet.71324.*` state to `/tmp/weizigo/`) | read-only; if it misbehaves it only misleads the human's screen | **KEEP** |
| `tools/fleet-cooldown.sh` | sets/clears `untracked/fleet-keeper.cooldown` — the graceful-stop flag | human / Orchestrator | last cleared by the seat 2026-08-24T07:04Z (a zero-byte cooldown had paused the keeper ~4 days) | a forgotten zero-byte cooldown silently parks the whole fleet | **KEEP** |

**The suite-truth agent (ruling requested).** My recommendation is **do not re-enable it
unattended**, for three reasons it did not have when installed: (1) it runs the **full suite daily
unattended** — the same 58 `git init` regression-script family that caused the 2026-08-24 incident,
and the isolation guard is one commit old; (2) the suite is ~906 s of load on a host whose
load-contamination rule already makes it refuse while any lane runs; (3) it is a **second
scheduler** alongside fleet-keeper, which is exactly the "two doors, one gated" shape this project
keeps retiring. The value it provided — *a red discovered by a machine* — is real and should come
back, but as an **on-demand run by a seat after a commit lands**, not a daily unattended launchd
job. Keep the plist on disk but leave it unloaded until the suite is green and its run is guarded
by `tools/runner`.

---

## 2. Git worktrees

| what it is | what it is for | who/what invokes it | when it last did something | blast radius | verdict |
|---|---|---|---|---|---|
| main worktree `/Users/alex/Project/Zig/weizigo` | the one real checkout | every console | now (HEAD `819bbed`, 2,565 files) | the whole project | **KEEP** |
| 10 of 11 scratch worktrees | copies of races finished days ago | were removed by the seat 2026-08-24 | removed | (gone) | **DELETED** ✓ |
| `/private/tmp/weizigo/race-t447` | leftover directory **skeleton** from the T447 race (2026-08-18) — 186 empty subdirs, **0 files, no `.git` file, not a registered worktree** | nothing | last touched Aug 23 00:00 | none (empty) | **DELETED** ✓ (this task) |

**Why `race-t447` "refused to remove."** It was **not** a git worktree — it had no `.git` file and
`git worktree list` did not list it — so `git worktree remove` refused it (the only worktree-removal
tool the seat reached for). It was a plain directory of empty subdirectories, and `rm -rf` removed
it cleanly (exit 0). The refusal was a tool-choice mismatch, not a filesystem obstacle: no mount,
no `uchg`/`schg` flags, owner `alex`.

---

## 3. The incident's leftovers still in `main`'s history — new, load-bearing

The 2026-08-24 repointing left **two scratch commits in `main`** that no repair has cleaned. They
are the mechanism's fingerprint, and they are more than cosmetic:

| what it is | what it is for | who/what invokes it | when it last did something | blast radius | verdict |
|---|---|---|---|---|---|
| commit `76dc301` `base` — author `T841 <t841@test>` | **nothing** — a regression fixture's `git commit -qm base` that ran against the real repo | the incident (a `git init` regression script run inside pre-commit with `GIT_DIR` inherited) | 2026-08-24 09:33 | it **swept real T839 work** (`findings/T839-ratrace.json`, `untracked/ratrace/T839.patch`) into a `base`-labelled, fake-authored commit, **deleted 45 lines from `.gitignore`** (leaving only `untracked/`), and created `README.md` = `"base"` | **NEEDS-OPERATOR-RULING** — do not rewrite history without the operator; at minimum the `.gitignore` truncation must be fixed in a new commit |
| commit `7212504` `base` — author `T799 <t799@test>` | **nothing** — same mechanism | the incident | 2026-08-24 10:06 | **swept real T846 work** (`S10-failure-transparency/spec.md`, `findings/T846-failure-transparency.json`) into another `base` commit | **NEEDS-OPERATOR-RULING** — same |
| `README.md` at repo root (content `"base"`, 5 bytes) | **nothing** — the regression fixture's `echo base > README.md`; the project has no root README (AGENTS.md is the router) and did **not** have one before the incident (`cbc3ff1` has no README.md) | introduced by `76dc301` | — | a 5-byte file named README that misleads anyone who opens it | **DELETE** ✓ (this task, own commit) |
| `HEAD:.gitignore` (1 line, `untracked/` only) | ignores build/scratch dirs — **truncated by `76dc301`** from 46 lines to 1 | every git command | — | **`bin/*`, `log/`, `data/`, `zig-cache/`, `zig-out/` are no longer ignored in HEAD** — built binaries become stageable, which is exactly the B11 "gitignored build artifact got staged" recurrence vector | **KEEP-BUT-FIX** — the full 46-line `.gitignore` exists **only uncommitted in the working tree**; commit it now (not this task's file) |

These two `base` commits are also the concrete answer to *"the store was overwritten with a stale
snapshot and 59 tasks vanished"* — the scratch `git commit` committed whatever the shared index
held at that moment, including other consoles' staged work, under a fake author and a fake message.

---

## 4. The 58 `git init` regression scripts

| what it is | what it is for | who/what invokes it | when it last did something | blast radius | verdict |
|---|---|---|---|---|---|
| 58 of the 83 `tools/regression-*.sh` scripts run `git init` in a `mktemp` scratch dir (each also writes `echo base > README.md` and commits `base`) | regression fixtures that need a scratch git repo to test hooks/wrapper/kanban behaviour | the pre-commit fast tier (13 of them) and the full suite via `build.zig` (76 total) | continuously — the incident ran one inside a commit | each one, when run **inside a git hook with `GIT_DIR` inherited**, could re-init the real repo — the incident itself | **KEEP** — the one-line fix covers them all (below); a per-script `unset` would be 58 edits for zero extra coverage |

**The fix, verified this task.** `WEIZIGO_GITENV_ISOLATION` in `tools/hooks/pre-commit` unsets
`GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_NAMESPACE` as the **first statement**
before any git command. It is **committed in HEAD** (verified `git show HEAD:tools/hooks/pre-commit`).
The scripts themselves remain unhardened — a **blind spot stated plainly**: a `git init` regression
script run *outside* the hook (e.g. `zig build test`, `suite-truth.sh`) does **not** have `GIT_DIR`
set, so it is already safe there; the only entry point where `GIT_DIR` is set is the hook, and the
hook now clears it. A shared `safe_git_init()` helper is the simplification that would retire the
58 unguarded `git init` call sites in favour of one, but it is optional, not load-bearing.

---

## 5. The six ways to run tests

| what it is | what it is for | who/what invokes it | when it last did something | blast radius | verdict |
|---|---|---|---|---|---|
| `tools/smoke.sh` | 1 s fast smoke (rebaselined T788) | pre-commit fast tier, `zig build test`, humans | every commit | a silent-pass smoke hides engine breakage | **KEEP** |
| `tools/suite-truth.sh` | full suite + the scheduled/nightly verdict surface (`--scheduled` writes the verdict under `untracked/test-gate/`) | launchd (currently unloaded), seats on demand | 2026-08-23 | the "red visible on every commit" surface goes stale if it never runs | **KEEP-BUT-FIX** (see §1) |
| `zig build test` (`build.zig`, 103 KB) | the canonical suite: 76 regression scripts + unit tests + roundtrip + smoke | humans / agents | continuous | the main test entry point; a broken wiring reds everything | **KEEP** |
| `tests/unit/run.py` (+ 8 `test_*.py` modules) | Python unit tests, 300+ arms across five modules | `zig build test`, directly | continuous | tooling regressions go uncaught | **KEEP** |
| `tests/roundtrip/` (`test_dispatch_lifecycle.py`, 10 arms) | round-trip dispatch lifecycle, ~70 s, on the `--test-worker` seam | `zig build test` | continuous | dispatch-lifecycle regressions | **KEEP** |
| the 83 `tools/regression-*.sh` scripts, individually runnable | one regression each, guarding a specific tool/kernel property | the suite (76 wired) / pre-commit fast tier (13) / by hand | continuous | a specific defect's guard | **KEEP-BUT-FIX** — 7 are **not** wired into `build.zig` and so never run in the suite |

**The 7 unwired regression scripts** (exist, individually runnable, but `build.zig` never calls
them — so a defect they guard is not caught by the suite): `regression-arbiter.sh`,
`regression-managent-done-git.sh`, `regression-managent-memory-safety.sh`,
`regression-process-ownership.sh`, `regression-race-collect.sh`, `regression-T227.sh`,
`regression-task-identity.sh`. Each is **KEEP-BUT-FIX**: wire it into `build.zig` or delete it and
say why the coverage is gone.

---

## 6. The four places kill records live

| what it is | what it is for | who/what invokes it | when it last did something | blast radius | verdict |
|---|---|---|---|---|---|
| `untracked/runs/<task>.json` (1,296 files) | per-run terminal record: `killed`, `signal`, `exit`, `killed_by` | `tools/runner` on every run | continuous | the only place a kill's *cause* is recorded — and it is **untracked**, so un-auditable from the repo alone | **KEEP-BUT-FIX** (T798: surface `killed_by` into the kanban) |
| `untracked/log/*.log` (2,322 files) | runner/dispatch logs, 1,334 kill lines per T798's census | `tools/runner`, `bin/dispatch` | continuous | the only place 43 kill-visible tasks are visible at all | **KEEP** (untracked by design) |
| `untracked/tokens/tokens.jsonl` (1,907 lines) | token/non-zero-rc records (248 non-zero-rc per T798) | `tools/token-capture.py` | continuous | a third, divergent kill view | **KEEP-BUT-FIX** |
| `docs/infra/dispatch-heals.jsonl` (82 lines, **tracked**) | the **dispatcher heal** ledger — records *re-dispatches after* a kill (`healed_by: dispatcher`), **not the kills themselves** | `bin/dispatch` | 2026-08-24 07:44 (T840/841/842 provider-429) | misread as a kill ledger it reports nothing; as a heal ledger nothing reads it | **KEEP-BUT-FIX** — it is the "only tracked one" and it holds zero *kill* records by design; name it or make it the real kill ledger |

**The silent truth behind this table:** a task killed three times and then closed `pass` is
indistinguishable, on every tracked surface, from one that passed first try — because all three
kill records live in `untracked/` and the one tracked file records heals, not kills. T798 is the
fix task and is not yet done.

---

## 7. The two task stores (plus the ones nobody mentions)

| what it is | what it is for | who/what invokes it | when it last did something | blast radius | verdict |
|---|---|---|---|---|---|
| `docs/infra/managent/tasks.json` (480 rows, 737 KB) | the live kanban — the only record of what work exists | `bin/managent`, `bin/dispatch`, `tools/fleet-keeper.sh`, pre-commit | every task operation | **if it shrinks, work vanishes** — the 59-task loss, and **there is still no detector** | **KEEP-BUT-FIX** (S10/T846 specs the alarm; not built) |
| `docs/infra/managent/archive.json` (132 rows, 150 KB) | completed/cancelled task archive | `bin/managent` retire/archive | continuous | lower; archive loss loses verdict history, not live work | **KEEP** |
| `docs/infra/managent/directives.jsonl` (528 lines) | the inbox: `tell`/pause/amend/kill directives between consoles | `bin/managent tell`/`inbox` | continuous | a lost directive = a worker that never sees a pause/kill | **KEEP** |
| the tombstone under `untracked/managent/` (183 B, Jul 28) + a stale `.bak` | **tombstone** (documented) and a stale `.bak` | nothing | Jul 28 | low; the `.bak` is confusion | **KEEP** the tombstone, **DELETE** the stale `.bak` |

**Store-shape defects found this task:** (1) a malformed task row literally named **`--bundle`**
exists (status `dispatchable`, `duty:false`, bundle path under `untracked/` (`T430-phase2-audit`) which
**does not exist**) — a `managent add --bundle <file>` misparse that can never dispatch; **propose
purge** (`bin/managent purge --bundle`). (2) The seat's RESUME said this row was "removed" — it is
back, which is itself evidence the store reverted and the removal was lost.

---

## 8. `untracked/` — 8,349 files, and the duty rows

| what it is | what it is for | who/what invokes it | when it last did something | blast radius | verdict |
|---|---|---|---|---|---|
| `untracked/` (8,349 files: `tokens/` 2,787 · `log/` 2,322 · `runs/` 1,325 · `bakeoff/` 393 · `race-aspects/` 244 · `msg/` 101 · + `.wzo` oracle artifacts 258 MB each) | important-but-untracked: comms, large artifacts, in-progress bundles, run records | everything | continuous | losing it loses run records, kill records, and the `.wzo` oracles (hashed in `docs/evidence/README.md`) | **KEEP-BUT-FIX** — unnavigable (OPEN C4, folded into T787); 18 files are force-tracked inside it, which is a standing contradiction |
| `log/` at repo root (1,493 files) | old `weizigo-*` / `sabaki_*` logs | the engine, historically | Aug 7 (mtime) | none — gitignored, and now **un-ignored in HEAD** by the `.gitignore` truncation (§3) | **DELETE** (scratch debris; propose cleanup) |
| `DCLAIM` (duty, registered, `due_after:5`) | verify one unbacked `PROVEN` claim per chunk → L4 | `managent duty DCLAIM done` | findings `DCLAIM-2026-08-22*.json` | a failing duty blocks L4's landmark gate | **KEEP** |
| `DRPLAY` (duty, registered) | play one random 4×4 game vs the oracle → L2 | `managent duty DRPLAY done` | — | same, gates L2 | **KEEP** |
| `DARGUS` (duty, registered) | run `bin/argus --mode doctor` once and act → L1 | `managent duty DARGUS done` | — | same, gates L1 | **KEEP** |
| `DFLEET` (documented in `docs/infra/duties.md`, **not registered** in the store) | one keeper iteration per chunk | would be the keeper itself | never registered | the doc and the store disagree | **KEEP-BUT-FIX** — register it or delete the doc row |

---

## 9. Everything else found (tooling zoo, engine, surfaces)

| what it is | what it is for | who/what invokes it | when it last did something | blast radius | verdict |
|---|---|---|---|---|---|
| `tools/hooks/pre-commit` (28 KB, one file) | three gates: claimlint floor · staged-path scope backstop · fast test tier | git, every commit | now (this task's commits) | **blocks every commit if broken; was the incident vector** | **KEEP-BUT-FIX** (one 28 KB shell script is a consolidation target) |
| `WEIZIGO_GITENV_ISOLATION` (in pre-commit) | the isolation guard | pre-commit | every commit | a regression = the incident again | **KEEP** (verified committed) |
| `WEIZIGO_WORKTREE_GUARD` (in `tools/git-commit-mine`) | refuses `core.worktree` set, and a HEAD < 2,000 files | `tools/git-commit-mine` | every wrapped commit | a regression = silent repointing again | **KEEP** (verified red-then-green this task, §Verification) |
| `tools/git-commit-mine` + `-lib.sh` | path-limited commit wrapper (scope ⊆ deliverables ∪ findings ∪ shared surfaces) | agents, `--explicit` for seats | every wrapped commit | a bypass = the `d7e4bdb` sweep class | **KEEP** |
| `tools/runner` (186 KB Python) | process guard: wall/RSS/CPU/progress, writes heartbeat + run record + directive reads | `bin/dispatch`, `bin/subagent`, pre-commit test gate | every run | a defect kills lanes or (B7) reads stdout-only and misses live workers | **KEEP-BUT-FIX** |
| `bin/managent` (1.6 MB) | the kanban CLI | everything | every task operation | the whole fleet's memory | **KEEP** |
| `bin/dispatch` (35 KB Python) | headless dispatch, caps, windows, heals | `tools/fleet-keeper.sh`, seats | continuous | a bypass = ungated dispatch (T845 caps now live) | **KEEP** |
| `bin/subagent` (43 KB Python) | subagent launcher (`odeeppi`/`oflashpi`) | dispatchers | continuous | subdelegation door | **KEEP** |
| `bin/argus` | read-only doctor/watchdog (`--mode doctor`/`sweep`/`checklist`) | `DARGUS` duty, seats | on DARGUS runs | only surfaces when run; between runs its findings are silent | **KEEP** |
| `tools/fleet_caps.py` · `tools/window_policy.py` · `tools/dispatch_verify.py` · `tools/token-capture.py` · `tools/complementarity.py` · `tools/model-profiles.py` · `tools/model_tags.py` · `tools/bakeoff.sh` · `tools/race-*.py` | the measurement/dispatch instrument zoo | each imported by `bin/dispatch`/`bin/subagent`/keeper/regressions | continuous | a silent-wrong-answer in any is the QA-023 class | **KEEP** (each has a live importer — a basename grep already mis-flagged `window_policy.py` dead once; Python module imports are the **blind spot stated**) |
| `src/` (108 `.zig` files, ~50 `tNNN_*.zig` experiments) | the solver engine + per-experiment probes | `build.zig`, `zig build test` | continuous | the research product itself | **KEEP** (the `tNNN` throwaways are candidates for `archives/`, not deletion) |
| `src/managent/main.zig` (572 KB, one file) | the whole managent engine | compiled to `bin/managent` | on every rebuild | mid-edit by T834; one file = serialized edits | **KEEP-BUT-FIX** (S06 consolidation is the shape) |
| `build.zig` (103 KB) | suite wiring: 76 regressions + unit + roundtrip + smoke | `zig build test` | continuous | the test gate's backbone | **KEEP** |
| engine binaries `bin/weizigo-{oracle,gtp,arena,claimlint,reachcensus,engine-vs-engine,chainability}` | the compiled products | built by `zig build` | 2026-08-24 | stale binary = smoke reports STALE | **KEEP** (build artifacts) |
| `untracked/heartbeat.jsonl` (2.6 MB) | worker liveness heartbeats | `tools/runner` per run | continuous | `managent liveness` reads it; nothing alarms on its own | **KEEP** |
| `untracked/fleet-keeper.{attempts,heal,pressure}.json` | keeper state machine telemetry | `tools/fleet-keeper.sh` | live | low | **KEEP** |

---

## 10. Deletions performed this task (scratch debris, own commits where tracked)

| what | why | how |
|---|---|---|
| `/private/tmp/weizigo/race-t447` | empty worktree skeleton, 0 files, no `.git` | `rm -rf` (outside repo, no commit needed) |
| root `watch-fleet.sh` (untracked stray, differs from the tracked copy under `untracked/`) | scratch copy; the live viewer runs `watch-fleet.sh` from `untracked/` (pid 71324) | `rm` (untracked) |
| root `regression-watch-fleet.sh` (untracked stray, differs from `tools/regression-watch-fleet.sh`) | scratch copy of an 83 KB regression already in `tools/` | `rm` (untracked) |
| `Oops.rej` (untracked) | a rejected patch hunk from an edit to `tools/dispatch_verify.py` | `rm` (untracked) |
| `README.md` = `"base"` | scratch artifact introduced by incident commit `76dc301`; the project never had a root README | own commit via `tools/git-commit-mine --explicit` |

**Proposed but NOT done (live caller / operator surface):** purge the `--bundle` store row ·
commit the full `.gitignore` (working-tree fix, not this task's file) · register `DFLEET` or delete
its doc row · wire or delete the 7 unwired regression scripts · decide the suite-truth agent (§1).

---

## 11. The silent-failure list — the most valuable thing this task produces

*For each KEEP/KEEP-BUT-FIX part: if it misbehaved, would anyone notice without a human wondering?
The repository corruption ran at least a day because nothing compares a tree's size before and
after a commit. These are the parts whose failure is currently **silent**:*

1. **`tasks.json` shrinking** — no size/row-count detector compares before/after a commit. The
   59-task loss was only noticed when a worker logged `task T836 not found`. *The* one. S10/T846
   specs the alarm; it is not built.
2. **`HEAD:.gitignore` truncated to one line** — `bin/*`, `log/`, `data/`, `zig-cache/` are
   un-ignored in HEAD, so built binaries become stageable; the B11 "gitignored binary got staged"
   failure recurs silently until a commit breaks. The full file exists only in the working tree,
   uncommitted.
3. **fleet-keeper death/pause** — the keeper is a detached orphan (ppid 1), nothing supervises it;
   a zero-byte `untracked/fleet-keeper.cooldown` silently parked the fleet for **four days**.
4. **suite-truth nightly** — now disabled; a red suite is discovered by nothing until a human asks.
5. **harness kills** — a 3×-killed-then-pass task is indistinguishable from first-try pass on every
   tracked surface; all three kill records live in `untracked/`.
6. **model-perf ledger** — nothing writes `docs/infra/model-task-metrics.jsonl` automatically
   (OPEN B1); 59 of 72 cells empty.
7. **stale `in_progress` cohort** — tasks read in-flight while complete (OPEN B12); `managent reap`
   is manual, nothing alarms.
8. **the two `base` commits** — fake authors (`t841@test`/`t799@test`), fake messages, real T839
   and T846 work swept into them; nothing reads `git log` for anomalies, so they sat unnoticed.
9. **`dispatch-heals.jsonl`** — heal records accumulate; nothing reads them for a spike (e.g. the
   24 T989/T990 fixture-heal leak had to be flagged by a human audit note, not a check).
10. **`bin/argus` doctor findings** — only surfaced when `DARGUS` runs; between runs they are silent.
11. **watch-fleet strays** — a `watch-fleet-live.sh` ran 10h43m from a scratch dir unnoticed; only a
    human kill fixed it; nothing labels/kills long-running watchers.

---

## 12. Verification of the two guards (the brief required it; "do not assume")

- **`WEIZIGO_WORKTREE_GUARD`** — verified **functionally** in a scratch repo: against a 1-file HEAD
  it refused with `REFUSED — HEAD holds only 1 files`; with `core.worktree` set it refused with
  `REFUSED — core.worktree is set to '…'`. Live repo state is clean (`core.worktree` unset,
  HEAD = 2,565 files).
- **`WEIZIGO_GITENV_ISOLATION`** — verified by **inspection** (the honest limit): the `unset
  GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_NAMESPACE` line is the first
  executable statement of `tools/hooks/pre-commit`, and `git show HEAD:tools/hooks/pre-commit`
  confirms it is committed. I did **not** reproduce the full hook-with-GIT_DIR-set end-to-end run
  against the live repo — doing so is exactly the incident's mechanism, and the brief forbids
  running the suite. **Blind spot stated:** a full red-then-green of the isolation guard would need
  a scratch victim repo with `GIT_DIR` exported and a copy of pre-commit's first lines sourced; the
  committed presence + correct placement is what I verified, not a live reproduction.

---

## 13. The smallest set of moving parts that would still do this project's work

The project is: solve small gobans and record the results honestly. That needs **six parts**: the
solver engine (`src/` + `build.zig` + `zig build test`); the oracle artifacts (`.wzo`); **one**
kanban (`bin/managent` + `tasks.json` + `archive.json`); **one** dispatch path (`bin/dispatch` +
`tools/runner`); **one** commit path (`tools/git-commit-mine` + `tools/hooks/pre-commit` carrying
the claimlint floor and the fast test tier); and the claim register + findings
(`docs/epistemic/CLAIMS.md` + `findings/`). Everything else in this inventory — the suite-truth
agent, `watch-fleet.sh`, `bin/argus`, the four duties, the 83-script regression sprawl, the
measurement zoo (`complementarity.py`, `bakeoff.sh`, `race-*.py`, `model-profiles.py`,
`window_policy.py`, `token-capture.py`), the 8,349-file `untracked/` corpus, and the 572 KB
single-file `main.zig` — is convenience, measurement, or debt layered on top. Each can be deleted or
collapsed into the six without losing the ability to solve gobans and say what is proven; what they
buy is *visibility*, and this inventory is the list of places that visibility currently fails
silently (§11).
