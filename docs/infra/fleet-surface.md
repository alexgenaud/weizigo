# fleet-surface — what the operator sees, and when the monitor acts

**Row:** T466 (what should the fleet surface show, and when should argus run?) —
design it, simply · **Author:** deepseek-v4-flash/T466 · **Date:** 2026-08-19
**Landmark:** advances `L1 (the dashboard tells the truth)` — the operator
currently learns about stale claims and dead lanes by reading a screen and
telling the Orchestrator; every gap he relays is a gap the surface should
have shown or the system should have healed.

**Implementation note.** The surface script (`untracked/watch-fleet.sh`) was
implemented by **T469** (glm-5.2, done 2026-08-19, commit `333b855`) as the
four sections below, per the Orchestrator's D077 amendment (2026-08-19T11:49Z,
recorded in `findings/T466-fleet-surface.json`). T466 contributed the design
decisions, the regression controls (`tools/regression-watch-fleet.sh`, wired
into `zig build test`), the time-notation fixes outside the script
(`tools/runner`, `bin/argus`), and this document. The working-tree copy of the
script is co-owned: after T469 committed, a claude console (the operator's)
kept iterating on it. The regression pins the **committed** contract, not the
live working file.

---

## 1. The surface — four sections and a footer (Part 1, as amended by D077)

The brief's single-table sketch is **superseded** by D077: the operator wants
four kanban sections, not one, because one table cannot show both "running
with a live process" and "stale / killed / unexplained" with the same
honesty. Each section is a row-per-task list:

| section | contract | row carries |
|---|---|---|
| **PROGRESS** | tasks running or on hold (claimed, live process) | id, landmark, elapsed, CPU, pid, model |
| **OPEN** | dispatchable soon — the do-now list (backlog table if it parses, else the dispatchable list, capped) | id, landmark, description |
| **CONCERNS** | everything that is neither progressing, open, nor done: stale claims, killed lanes, missing deliverables, anything the surface cannot explain | id, landmark, what is wrong, **the exact command that resolves it** |
| **DONE** | closed in the last 12 h, so the operator sees what landed without asking | id, landmark, verdict, description |

**CONCERNS is the load-bearing section** (D077: "the section that matters
most"). It is the list of things the operator currently has to notice himself
and relay to the Orchestrator, so every item ends with the resolving command —
`-> bin/managent reopen <id>` for a dead lane, with a `deliverables
present/missing` parenthetical so the operator knows whether the lane's output
survived before he re-queues it. A row that the surface cannot explain belongs
in CONCERNS by definition, never silently dropped.

**Landmark and task descriptions are elaborated once, below the tables** —
one line per landmark id that appears (with its short name from
`docs/epics/E1-markovian/LANDMARKS.md`) and one line per task id that
appears (its bundle's short description). No description is repeated inside a
table row. Empty sections print `(none)`, never vanish and never lie.

### Processes with no task → footer, not a section

Decision: **a footer (`NOT ON THE KANBAN`), not a row in any of the four
sections, and not a second table.** Reasons:

- The four sections are keyed by **task id**. A process with no task has no
  row key; forcing one in would invent pseudo-ids ("console", "race") and mix
  kinds in a table the operator reads as "the kanban".
- But unowned CPU is exactly the orphan signal this repo has been burned by —
  the all-night orphan (runner.md: "a zig test binary spinning at 0% RSS sat
  undetected for 5 hours"), the five test binaries at 100% CPU with load 16
  (D028, 2026-08-04). A surface that hides unowned processes is worse than
  none. The footer keeps them one glance away without contaminating the
  sections' truth.
- The footer classifies each leftover: `race` (bake-off/race lanes),
  `dispatcher` (`bin/subagent` launching machinery), `runner` (`tools/runner`
  wrappers), `console` (pi/ollama/claude processes — including bare `pi`,
  whose dispatcher exited and reparented it to launchd), and `ORPHAN?
  (in-repo)` — the gate for nameless build/test binaries: **ppid 1 (reparented)
  + cwd in the repo + build/test-shaped command** (`zig` / `weizigo` /
  `.zig-cache` / `test`). The ppid-1 + cwd test alone is NOT enough: console
  processes routinely have ppid 1 after their dispatcher exits and are work,
  not orphans (observed 2026-08-19: a live lane's `pi` showed as ORPHAN until
  the build/test-shaped refinement — see the pending patch in §6).

On 2026-08-19 the footer immediately earned its keep: it surfaced a **real
orphan** — `zig build -Doptimize=ReleaseFast test`, ppid 1, running 2h29 with
2.9 s CPU (a stuck build, almost certainly blocked on the zig global cache
lock held by another lane). Recorded in the findings; not killed by the
surface (killing is the operator's or a dedicated row's job — see §4).

## 2. Time notation (Part 2) — a ruling, applied everywhere

Operator rule, 2026-08-19: **a colon means an instant, always** (`HH:MM`,
`HH:MM:SS`, `HH:MM:SS.mmm`). **A duration never contains a colon.** Instants
are stored UTC and presented local (the surface header shows both).

Canonical duration forms (the rule's own examples):

| range | form | example |
|---|---|---|
| ≥ 3600 s | `NhMM` | `4h28` |
| 60–3599 s | `N'SS` | `19'48` |
| < 60 s, whole | `SSs` | `48s` (a bare `48` would be ambiguous next to pids) |
| < 60 s, fractional | `SS.cc` | `12.34` (a bare decimal can only be seconds) |

Fixed occurrences:

- `untracked/watch-fleet.sh` — CPU time went through `dur()` so the old
  `0:00.38` instant-vs-duration ambiguity is gone (both in T466's draft and
  T469's committed four-section version).
- `tools/runner` — the sweep mode printed raw `ps` `etime`/`cputime`
  (colon durations) and `_format_clock` produced `[H:]M:SS` for durations in
  kill messages and peak-CPU logs. Replaced with `_format_duration` (same
  canonical forms). Evidence fields keep the instrument's raw output
  (`(386.84s)` appears alongside); only human-facing text is reformatted.
- `bin/argus` — the doctor's long-running-process line printed raw `ps`
  `etime` (`dd-hh:mm:ss`) in the report text; now `running 19'48`-style, with
  the raw value preserved in `evidence_output`.

`bin/managent` liveness output was already compliant (`beats stopped 946m
ago`, `wall: 5099.7s`).

## 3. When does `bin/argus --mode doctor` run? (Part 3)

**Position: the monitor's marginal value is highest when load is heavy — the
failures this repo actually suffered were all invisible-until-looked — but the
cost structure forces a two-tier answer: a cheap, always-on, serial liveness
line, and an expensive deep check that runs on cheap triggers with a load
gate.**

The repo's own history is the evidence:

- **2026-08-08 suite readings (35–52 min vs 810.9 s quiet)** — the load
  contamination was discovered only when someone re-ran on a quiet machine
  (A0016). A cheap load gauge at suite time would have flagged "readings
  contaminated".
- **RSS-killed lane at 4121 MB vs the 4096 MB cap** — the runner's guard
  worked (the kill), but the *death* was invisible until liveness was polled.
- **All-night orphan** — 5 hours undetected at 0% RSS (runner.md).
- **Five test binaries at 100 % CPU, load 16** — the D028 pause had to be
  sent by hand; no monitor fired.

So the *expensive* doctor is most valuable when load is heavy, but running it
*more often* when load is heavy is backwards on cost. Resolution:

1. **The 10 s serial loop (watch-fleet) stays the always-on surface** — `ps` +
   `managent status` are cheap; it is one process, satisfying "prefer one
   serial loop over several concurrent watchers" and the 50 % combined
   resource ceiling trivially.
2. **`argus --mode doctor` runs on triggers, not on a clock**, when cheap
   signals say something is wrong: a dead lane appears in CONCERNS, the fleet
   is idle with work waiting, an unowned high-CPU process appears, or load
   crosses a threshold. The surface's alarm lines are the trigger surface.
   The operator also keeps his manual weekly run.
3. **A load gate inside doctor**: if the machine is already busy, the
   expensive parts (claimlint ×3, git status, artifact loading) yield or
   jitter — monitoring must never add the load it is watching. Doctor is
   invoked as a step of the same serial loop, not a concurrent watcher.

A defended "no change" applies to the *implementation* here: watch-fleet does
not auto-invoke argus in this row (an argus run from the 10 s loop every time
a trigger fires would add load exactly when load is the problem); it prints
the suggestion line. The scheduling decision above is the design; wiring a
gated scheduler is a small follow-up if the operator wants it.

## 4. Self-healing (Part 4) — one action, opt-in, with controls

**Proposed set: exactly one automatic action — reopen a claimed task with no
process after 15 minutes** — and everything else is a defended no-change.

- **The action**: a row `in_progress`, claimed > 15 min, with no matching
  process (`ps` scan for `Follow untracked/<id>-`, NOT `pgrep -f` — see §5)
  is reopened to `dispatchable` with an assertion first recording what did it
  and why (`managent assert <id> dispatchable --note "watch-fleet
  auto-reopen: no process after <dur>, claimed <ts>"`, then `managent reopen
  <id>`). It lives in the script behind **`WATCH_FLEET_HEAL=1`, default off**:
  this script is a surface, not a surgeon, and the 2026-08-18 live-repo
  incident (a kill by claude-fable-5 destroyed a worker's run, T443 A0014)
  is the standing warning against mutation without explicit consent.
- **Control that proves it fires**: `tools/regression-watch-fleet.sh` arm C —
  a scratch store with an old processless claim + `WATCH_FLEET_HEAL=1` →
  the row is dispatchable, the scratch ledger holds the assertion, the frame
  reports the heal.
- **Controls that prove it does not fire wrongly** (arm D): a live process
  (even with no heartbeat — the T448/T450/T466 shape) → untouched; a fresh
  claim (< 15 min) → untouched; a `done`/`dispatchable` row → untouched (and
  `reopen` refuses those statuses anyway, belt and braces).
- **Rejected as automatic** (each with its reason): killing orphans — a kill
  without a human is the class of action that caused the 2026-08-18 incident;
  the runner's guards already do hard kills inside guarded runs. Cleaning
  ephemera — deleting is destroying evidence (the B44 injury). Auto-absorbing
  findings — absorption is a human/Orchestrator decision. Auto-running doctor
  — see §3.

**Two defects the controls caught (both fixed in the committed contract):**

- **The age-gate epoch bug**: `date -j -f` without `-u` interprets the UTC
  claim timestamp as local time, so the age came out 2 h too large on this
  host (+0200) and the 15-minute gate misfired (a fresh claim looked 2 h old
  and was reopened). Fixed: `date -u -j -f ...`.
- **The HEAL_MIN leak** (found and fixed by T469): `HEAL_MIN=15` lived inside
  the `WATCH_FLEET_SOURCE != 1` block, so a test harness that sourced the
  file with `WATCH_FLEET_SOURCE=1` leaked the flag into the child shell,
  left `HEAL_MIN` unset, and the gate `$((HEAL_MIN * 60))` evaluated to 0 —
  heal fired on any processless claim regardless of age. Fixed: `HEAL_MIN`
  moved outside the block.

## 5. Defects found on the way (instrument-level, all load-bearing)

- **`pgrep -f` silently misses processes on macOS.** Proven 2026-08-19: a
  live T466 lane was invisible to `pgrep -f "T466"` while `ps` showed it
  plainly (the same command matched other lanes' processes). The surface
  therefore uses `ps -axww` + substring grep for all process detection. A
  monitor that misses a process is the silent-wrong-answer class this project
  hates.
- **`managent assert` derives the assertion ledger path from the CWD repo
  root, not `MANAGENT_STORE`.** Scratch isolation (A3) covers the store but
  not the ledger: a scratch run of the heal from a cwd inside the live repo
  writes assertions to the LIVE ledger. The T466 regression therefore runs
  the script from a scratch repo copy so its `cd $(dirname $0)/..` lands in
  the scratch. This is a real managent defect (the ledger should follow the
  store when `MANAGENT_STORE` is set) — **filed for a follow-up row**; do not
  fix in `src/managent/main.zig` here (T353 holds it). The T446 regression
  avoids it by writing assertions directly with `printf`.
- **Orphan found live**: `zig build -Doptimize=ReleaseFast test` (ppid 1,
  stuck, 2.9 s CPU over 2h29) — the footer surfaced it on the row's first
  run. Not killed by the surface.

## 6. Pending, deliberately not done here

- **ORPHAN-gate refinement patch** (bare-`pi` consoles → `console`, not
  `ORPHAN?`; gate requires build/test-shaped command): observed false
  positive on 2026-08-19, patch was written for the T466 draft and is
  recorded in the findings notes. The committed script still uses the
  ppid-1 + cwd gate; whoever next touches the live script should apply the
  refinement.
- **No daemon, no second always-on process**: one serial loop does the job.
- **Regression wiring**: `tools/regression-watch-fleet.sh` is wired into
  `zig build test` and pins the committed script contract via `git show
  HEAD:untracked/watch-fleet.sh`; if a future commit changes the layout or
  drops the test hooks, the suite fails loudly rather than silently stopping
  to test.
