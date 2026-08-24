# stream2b-green — classification of every red, vacuous and unwired check

**Task:** T870 · **Worker:** claude-opus-5/T870 · **Date:** 2026-08-24
**Landmark:** advances `L1 (the dashboard tells the truth)` — first phase of the green-up.
**Nothing was changed.** No deletion, no fix, no test edit, no code edit. This document decides; a
later row executes.

---

## 0. The four totals

| verdict | count |
|---|---|
| **DELETE** — tests nothing, or tests something that should not exist | **11** |
| **FIX-THE-TEST** — the check is wrong about a system that is right | **21** |
| **FIX-THE-CODE** — the check is right about a system that is wrong | **10** |
| **unclassifiable** | **0** |
| **total entries** | **42** |

42 entries over 39 distinct artefacts: 26 red scripts (one, `regression-directive-kill.sh`, carries two
independent causes and is split into two entries), 5 unwired-but-green scripts, and 11 vacuity entries
(the 8 verified checks that cannot fail, plus two whole classes found today, plus the argus checklist
slug counted once as a check). Three red scripts are *also* unwired and are counted once, in the red
set, with the unwired fact recorded in their row.

**No entry carries two verdicts.** Where an artefact had two independent causes pulling in different
directions, it is split by arm and both halves are listed.

---

## 1. What reaching zero red will and will not prove

This section is the point of the row. It is written before the tables because the tables are only
worth reading against it.

### It will prove

1. **Every one of the 88 regression scripts exits 0 in the environment the sweep ran in.** That is a
   real and currently-absent fact.
2. **No script is red for a reason nobody has looked at.** Each of today's 23 reds has a named cause,
   a module, and an owner below. Today a worker who hits a red cannot tell "pre-existing" from
   "I broke it"; after the green-up they can.
3. **The three fail-closed guards added on 2026-08-24 no longer refuse their own fixtures.** The
   worktree/truncation guard in `tools/git-commit-mine`, the S10 store-loss detector, and the T682
   landmark gate account for **11 of the 23 reds between them**. A guard that fails its own test
   suite teaches the bypass that ends it — S10's spec said so, and it happened. Clearing these is the
   precondition for anyone trusting the guards at all.

### It will not prove

1. **That the system works.** Of today's 23 reds, **12 are the suite mis-measuring its own
   environment**, not the system under test failing: four assert that `bin/` has been deployed, three
   depend on the live working tree or live store (which three other lanes were writing during the
   sweep), one depends on the caller's `WEIZIGO_AGENT_DEPTH`, one on how much RAM the host had free,
   one on a 3-second clock race, one on being invoked with `sh` rather than `bash`, and two on being
   invoked without the argument `build.zig` passes them. Turning those green changes the *test*, not
   the *system*. Zero red is a statement about the suite, not about the solver, the store, or the
   dispatcher.
2. **That the checks can fail.** Eight checks that cannot fail under any input are verified below —
   and that eight is a **floor**: it came from two independent observers finding **disjoint** sets of
   four. This row found two further classes neither observer named:
   - **`set -euo pipefail` makes FAIL branches unreachable.** In `regression-managent-memory-safety.sh`
     and `regression-managent-status-json.sh` the assertion is written as `cmd; RC=$?; if [ "$RC" -ne 0 ]
     …` — under `set -e` the script dies at `cmd` and `RC=$?` is never reached. The check's own FAIL
     message is dead code; the script exits 1 with no diagnosis. Both were red today with a truncated
     log and no stated reason. Nobody had noticed because the exit code was still non-zero.
   - **A SKIP is rendered to the gate as a PASS.** Today **7 of the 65 green scripts skipped at least
     one arm and still exited 0** (`regression-directive-integrity`, `regression-managent-done-two-phase`,
     `regression-one-dispatch-path`, `regression-orcha-acceptance`, `regression-runner-reporting`,
     `regression-runner-taskid`, `regression-T227`). **43 of the 88 scripts contain a SKIP-then-`exit 0`
     path.** The suite's exit code cannot distinguish *verified* from *not run*. On a fresh clone, or a
     host without `sudo -n`, or before a build, an arbitrary share of the suite is green because it
     declined to measure.
3. **That the gate sees the checks.** **8 of 88 scripts are wired to nothing** — they can fail, but
   for nobody who would notice. One of them, `tools/regression-arbiter.sh`, is the *replacement*
   coverage for `tools/regression-runner-host-guard.sh`, a check retired as unrepairable: the
   retirement swapped one vacuous check for one unreachable one. Zero red over the 80 wired scripts
   says nothing about those 8, whatever colour they are.
4. **That the reading is reproducible.** The sweep ran against a moving tree: `HEAD` advanced
   `4827aaf` → `6943e23` during it, three other lanes were committing, an 89th regression script
   appeared mid-run, and `zig-out/` was rebuilt twice. One script's verdict flipped from red to green
   when a single environment variable was unset. Section 5 shows this concretely: this row's red set
   and T861's red set, both measured on 2026-08-24, differ by two scripts, and each difference is
   explained by *when* the sweep ran, not by any change to the code.
5. **Anything about the modules with no suite at all.** S09 censused 38 modules; `bin/weizigo-oracle`
   has zero regression and zero smoke coverage, `tools/gen-indices` cannot be given a regression arm
   at all until its argument parsing is fixed (any invocation rewrites tracked files). Zero red across
   88 scripts leaves those modules exactly as unmeasured as they are today.

**The honest one-line summary:** zero red will prove that the suite is quiet in one particular
environment at one particular moment. It will not prove that the checks can speak.

---

## 2. Method, and its own blind spots

**The sweep.** Every `tools/regression-*.sh` was run once, serially, as `sh <script>` from the
repository root — the same invocation `build.zig` uses (`b.addSystemCommand(&.{"sh", "tools/regression-…"})`,
verified for all 80 wired entries). Per-script watchdog 300 s. Started 2026-08-24 16:03Z at `HEAD`
`4827aaf`, finished 16:22Z at `HEAD` `6943e23`. Logs and the per-script exit table are volatile
(a scratch directory under the system temp area, not cited by path per the commit gate); every number
below is reproducible by re-running the same loop.

**Denominator: 88 scripts** — `ls tools/regression-*.sh | wc -l` = 88 at sweep start, **80 wired** into
`build.zig`, **8 unwired**. The prior figure of "86" was already stale when it was recorded; an 89th
script (`tools/regression-facts.sh`) landed from a concurrent lane *during* the sweep and is not in
this classification. Wiring was computed case-insensitively (`regression-T227.sh` is wired and a
case-sensitive grep falsely flags it — that error class was named in the brief and guarded against).

**Raw result: 26 of 88 non-zero.** Three of those are measurement artefacts, not reds at `HEAD`:
`regression-battery-baselines.sh` and `regression-battery-sweep.sh` **pass** when given the artifact
argument `build.zig` passes them (they are the only two scripts in the suite that take an argument),
and `regression-subagent-prompt.sh` **passes** with `WEIZIGO_AGENT_DEPTH` unset. **Corrected red count:
23 of 88.** All 26 are classified below, because all 26 sit in T861's known-red baseline and each needs
a disposition.

**Isolation performed, so a cause is asserted rather than guessed:**

- The three `git-commit-mine` reds were re-run against a copy of the wrapper with its `< 2000 files`
  threshold neutralised: **all three pass.** One code change, three reds.
- The four `bin/ is stale` reds were re-run against a shadow tree whose `bin/managent` is the freshly
  built binary: two pass outright, two fail *only* on the freshness arm. So all four are that one arm.
- `regression-subagent-prompt.sh`, `regression-precommit.sh` and `regression-fleet-keeper.sh` were
  re-run with `WEIZIGO_AGENT_DEPTH`, `MANAGENT_TASK_ID` and `MANAGENT_STORE` scrubbed: the first
  flipped to green, the other two did not.
- `regression-process-ownership.sh` was re-run with `bash` (its shebang) rather than `sh`: the syntax
  errors disappear and one real arm still fails.
- The store-loss refusal was reproduced directly: create a scratch store, `managent add` a row (which
  writes a census), remove the row from `tasks.json` by hand, `managent add` again → **REFUSED**. That
  is the mechanism behind five reds.

**Blind spots of this classification.**

1. **The tree moved under the sweep.** Three lanes were committing. A script that reads the live store
   or the live working tree got a reading of *that moment*. Sections 3 and 5 mark every such entry.
2. **`zig build test`'s module-level reds are out of this population.** `docs/infra/suite-truth.md`
   records `RED module main` — three stale `assign:` test expectations after `ox-alpha` moved to SPEND
   appetite. I did not re-run `zig test src/managent/main.zig` (it is the slowest step and the tree was
   being rebuilt by another lane). The suite-truth manifest's diagnosis is test drift, not a logic
   defect, and I have no reason to dispute it — but it is **inherited, not verified here**, and the
   green-up owes it a verdict.
3. **Arm-level vacuity inside unread scripts.** I read every failing script's relevant arm and every
   cited vacuous site. I did not read all 88 in full. The two new vacuity classes in §1.2 were found by
   pattern, and their censuses (2 sites and 43 sites) are pattern counts — a hand audit will find more.
4. **`regression-watch-fleet.sh` runs longer than 5 minutes.** My first pass killed it at 300 s
   (recorded honestly as a watchdog kill, not a failure); a second unbounded run reproduced the real
   failure (arms F and G). Its wall makes it unusable as a pre-commit check regardless of colour.
5. **`regression-argus-doctor.sh` writes into the live repository's scratch area** while it runs
   (its own positive control seeds a bundle into the repository's scratch brief area). I did not chase whether that is a
   T445-class escape; it is flagged for the executing row.

---

## 3. The red set — 23 red, 3 measurement artefacts, 27 entries

`module` is the module-test-contract subject (S09 §2 / T861 §10). `also unwired` marks a script the
gate never runs.

### 3a. FIX-THE-CODE — the check is right about a system that is wrong (7 red entries)

These are the valuable ones: a red test that is correct is a bug report nobody read.

| # | check | module | what it asserts | the defect it is catching | already recorded? |
|---|---|---|---|---|---|
| R1 | `regression-git-commit-mine.sh` | `tools/git-commit-mine` | the wrapper commits exactly the paths named and refuses foreign ones | **The T771 worktree guard's second invariant is not implemented.** Its own comment states the invariant as *"a commit must not shrink the tree by more than the paths it names"* — a **relative** test. The code (`tools/git-commit-mine:22`) is `[ "${before:-0}" -lt 2000 ]`, an **absolute** size test. It is therefore false in every scratch repository and cannot protect a small-but-healthy tree. **Verified: all three of R1–R3 pass with the constant neutralised.** | partly — `docs/infra/suite-truth.md` does not carry it (it predates the guard); T861's baseline lists R1 with disposition `deploy`, which is the wrong diagnosis |
| R2 | `regression-commit-concurrency.sh` | `tools/git-commit-mine` | two consoles committing at once do not steal each other's staged paths | same single defect as R1 | as R1 |
| R3 | `regression-claim-lifecycle.sh` | `tools/git-commit-mine` + `bin/managent` | the five T424 claim/close lifecycle flakes stay fixed | same single defect as R1 | as R1 |
| R4 | `regression-directive-kill.sh` **arm 8d** | `tools/dispatch_verify.py` | a refusal that caused a harness kill classifies as `verified=unreached` | classifies it `fail` instead. A provider refusal is recorded as the worker's failure. | **yes** — D021, and the head commit `4827aaf` ("OPEN: provider refusals recorded as successful empty runs") is the same seam |
| R5 | `regression-managent-lock.sh` | `bin/managent` (T337 flock) | after the lock holder is SIGKILLed the next mutating command still succeeds within 5 s | the command aborts: **RC=134 (SIGABRT)** in 0.034 s. Lock-release recovery panics rather than reclaiming a dead holder's lock. | **yes** — suite-truth manifest, shell regression 8, owner T337, explicitly "real defect in lock-release recovery, not fixture drift" |
| R6 | `regression-task-id-archive.sh` | `bin/managent` | `retire` writes `docs/infra/managent/archive.json` and a later mint never re-uses a retired id | `archive.json` is never written (`FileNotFoundError`), and the live id set comes back empty where two ids were expected. **The feature is unbuilt.** This is a test-first red: `T770` is still `dispatchable`. | **yes** — T770, dispatchable. See §6 note 2: this red is *correct by design* and must not be deleted to reach zero |
| R7 | `regression-watch-fleet.sh` | the live fleet dashboard script (tracked in git as an established exception to the scratch-directory convention; not cited by path, per the commit gate) | arms F/G: a worker whose bundle path contains "watch-fleet" is SHOWN in PROGRESS | it is missing at both widths. Deterministic, reproduces standalone. A row is invisible on the dashboard because of a substring in its own filename. | **yes** — suite-truth manifest, shell regression 1, owner T466/T492 |

### 3b. FIX-THE-TEST — the check is wrong about a system that is right (16 red entries)

| # | check | module | the specific wrong assertion | class |
|---|---|---|---|---|
| R8 | `regression-managent-status-json.sh` | `bin/managent` | arm 3 replaces the two-row scratch store with a one-row store written directly to `tasks.json`, leaving the census T848 wrote for two rows. The next `managent` call is refused by the store-loss detector; `set -euo pipefail` then kills the script at the command substitution, so **no arm ever reports**. T855 fixed exactly this in four sibling scripts by adding `weizigo_reset_census` from the shared scratch-repo helper; this script does not source the helper. | store-loss fixture drift |
| R9 | `regression-dispatch-caps.sh` | `bin/dispatch` + `tools/fleet_caps.py` | same mechanism: the fixture removes seeded rows from the scratch store by hand, so every later `managent add` is refused ("live rows: 0, census rows: 6"), the store is never seeded, and `bin/dispatch` then reports `cannot read kanban status --json`. **Reproduced in isolation.** | store-loss fixture drift |
| R10 | `regression-fleet-keeper.sh` | `tools/fleet-keeper.sh` | fails with `refused T1` on every dispatch arm — two causes, both fixture-side: bundle fixtures with no `**Landmark:**` line (T682 gate) and the store-loss detector. Still red with the environment scrubbed. | landmark + store-loss fixture drift |
| R11 | `regression-argus-doctor.sh` | `bin/argus` | three arms. **Arm 6 is a null control that hard-codes an environmental precondition it does not establish**: its comment says *"Live tree was deployed at T424 … Doctor should report CLEAN here"*, so it asserts the deploy-staleness reading appears under CLEAN. `bin/` is not deployed right now, so the reading correctly appears under NEEDS ACTION and the arm fails. Arms 12/13 fail on **their own positive controls** — the guard under test refuses correctly (a=1, b=1, no write) and the scratch-store add that must succeed is refused by the store-loss detector, because the fixture's own `remove_row` shrank the store. | state-dependent null control + store-loss fixture drift |
| R12 | `regression-precommit.sh` | `tools/hooks/pre-commit` | its null control runs the hook **on the live working tree** and asserts it passes. The hook correctly refused: three dirty paths are held by `T861`, an in-progress row. The check's verdict is a function of what other consoles have uncommitted. Note the irony precisely — **T861 is the row that recorded this script as red, and T861's own in-flight work is what makes it red.** | live-tree dependence |
| R13 | `regression-managent-memory-safety.sh` *(also unwired)* | `bin/managent` | arm 2 asserts `managent audit` exits 0 **against the live store**. `audit` exits 1 because of `[FIX]` findings created by other rows' uncommitted work (T848's dirty deliverable, T553's uncommitted holds). The script's stated subject is T122 memory safety — "must not bus-error or crash" — and arm 1 already tests that with `|| true`. Arm 2 smuggled a repo-cleanliness assertion into a memory-safety check. Its FAIL branch is also unreachable (V10). 94 s wall. | live-store dependence |
| R14 | `regression-ollama-dispatcher.sh` | `bin/subagent` + `tools/runner` arbiter | arm 4 drives a **real** local-model dispatch (declared need 18432 MB) through the T821 admission arbiter, which refused: `avail 30684 − committed 7680 − candidate 18432 = 4572 MB < reserve 4608 MB`. The check's subject is *tag canonicalisation* (raw tag in the launch line, canonical label in the agent lines) — arms 1–3 and 5–7 all pass. It has no business asking the host for 18 GB. | host-pressure dependence |
| R15 | `regression-task-identity.sh` *(also unwired)* | `bin/managent liveness` + `tools/runner` | arm 4 sleeps 2 s, SIGKILLs the runner, sleeps 1 s, and asserts the row still reads `[beating]` with `LIVENESS_STALE_MIN=0.05` — a **3.0-second staleness window entered with a 3-second-old beat**. There is no margin; under load the arm reads stale and the next assertion (`beats stopped`) inherits the miss. The output format it greps is current and correct. Pin the beat timestamp instead of racing the clock. | clock race |
| R16 | `regression-process-ownership.sh` *(also unwired)* | `managent treekill` + `tools/runner` | two faults, both fixture-side. (a) It is `#!/usr/bin/env bash` and uses bash-only substitution; run as `sh` it emits `syntax error near unexpected token '('` at two sites. Being unwired, it has **no canonical invocation** — so its colour depends on the sweeper's choice of shell. (b) Run with `bash`, arm S6 imports `tools/runner` without putting `tools/` on `sys.path`: `ModuleNotFoundError: No module named 'directive_policy'`. Everything else passes; one arm SKIPs for want of `sudo -n`. | invocation + import path |
| R17 | `regression-dispatch-verification.sh` | `tools/dispatch_verify.py` + `bin/subagent` | its scratch repo does not contain `tools/runner`, so both seeded arms die on `FileNotFoundError` before the assertion is reached. The fixture is incomplete, not the classifier. | incomplete scratch repo |
| R18 | `regression-directive-kill.sh` **arms 1–5** | `bin/dispatch` | its fixture bundle declares no `**Landmark:**` line, so `bin/dispatch` refuses before the directive logic is ever exercised. Three lines of fixture. | landmark fixture drift |
| R19 | `regression-window-resilience.sh` | `tools/window_policy.py` + `tools/fleet-keeper.sh` | same landmark drift on its own fixture bundles, plus one arm ("nudge/probe state machine wrong") whose real reading is unobtainable until the gate stops refusing the fixtures. **Additionally: this script is wired into `test_step` twice** (`build.zig:679` and `build.zig:914`) — see §4.6. | landmark fixture drift |
| R20 | `regression-subagent-prompt.sh` | `bin/subagent` | **Not red at `HEAD`: it passes with `WEIZIGO_AGENT_DEPTH` unset.** It is red for any caller already at the delegation cap, because it inherits the caller's depth instead of pinning its own. The suite-truth manifest's diagnosis — "`bin/subagent` no longer accepts the `--dsflash`/`--dspro` flags" — **is stale**; that is no longer what fails. One `env` line in the fixture. | caller-environment dependence |
| R21 | `regression-battery-baselines.sh` | `tools/battery-baseline-compare.py` | **Not red: it passes when given the artifact argument** `build.zig` passes it (`addArtifactArg`). Bare, it prints `FAIL: battery binary not provided/built (argv[1]='')` and exits 1 — a *usage error dressed as a failed assertion*, which is why two independent sweeps counted it as a defect. Make a missing argument `exit 2` with a usage message so no sweep can mis-read it. | missing-argument artefact |
| R22 | `regression-battery-sweep.sh` | `tools/battery-baseline-compare.py` + `src/oracle_v2_accept.zig` | same; **passes with both artifact arguments** (verified, full 4×4 + WZO2 sweep, `BASELINE COMPARISON: PASS`). It is additionally **not part of `zig build test`** at all — it is the explicit `zig build battery-sweep` step — so its presence in a red baseline of the *suite* is a category error as well as an artefact. | missing-argument artefact |
| R23 | `regression-managent-holds.sh` | `bin/managent` | see §3c: its only red arm is the deploy-freshness preflight. Once `bin/` is deployed the script passes outright (**verified**). | deploy precondition |

### 3c. DELETE — the check tests nothing, or tests something that should not exist (4 red entries)

| # | check | module | what it currently asserts | what disappears with it | what is left untested |
|---|---|---|---|---|---|
| R24 | the deploy-freshness preflight arm in `regression-managent-assert-store.sh` | `bin/managent` | `deployed bin/managent == built zig-out/bin/managent`, failing the whole script when not | nothing measured about `assert-store`. **Verified:** with a fresh binary the script passes outright | nothing — the same job is done by `tools/smoke.sh` (whose entire purpose is deployed-binary build-stamp freshness), by `bin/argus --mode doctor`'s staleness reading, and by `managent audit`'s own closing line. **Four scripts re-implement a fifth tool's job and each turns the whole suite red for it.** Survivor: `tools/smoke.sh`, run once as a suite preflight |
| R25 | the same arm in `regression-managent-holds.sh` | `bin/managent` | as above | as above (**verified pass** with a fresh binary) | as above |
| R26 | the same arm in `regression-managent-impression-gate.sh` | `bin/managent` | as above | as above (**verified**: only this arm remains red against a fresh binary) | as above |
| R27 | the same arm in `regression-managent-integrity.sh` | `bin/managent` | as above | as above (**verified**: only this arm remains red against a fresh binary) | as above |

*(A fifth delete in the red set — `regression-runner-guard.sh` — is listed with the vacuity set at V5,
because its defect is that its subject no longer exists.)*

---

## 4. Consolidation — where two checks cover one job

This is the bridge from this row to the simplification work, and the brief is right that it is worth
more than a longer list.

### 4.1 Host-pressure admission — **4 checks, 1 job, 1 survivor**

| check | state today | wired |
|---|---|---|
| `regression-runner-guard.sh` | **red** — asserts the T362 `host_total // 8` memory-pressure guard fires; **T821 deleted that guard**, so its seeded arm can never fire again | yes |
| `regression-runner-host-guard.sh` | **vacuous** — retired stub, `exit 0`, self-documented as "cannot be repaired into passing" | yes (`build.zig:333`) |
| `regression-subagent-resident-gate.sh` | **vacuous** — retired stub, `exit 0`, same rationale | yes (`build.zig:352`) |
| `regression-arbiter.sh` | **green** — the real T821 controls: real co-launch, futile-kill structurally impossible, effective overrun-stop, refusal-at-admission, and a null control | **no** |

**Recommendation: `tools/regression-arbiter.sh` survives and is wired; the other three are deleted.**
Net effect: −3 scripts, −2 vacuous checks, −1 red, and for the first time the mechanism that actually
governs admission is inside the gate. Note what the arithmetic says about T821's retirement: it
replaced one vacuous check with one unreachable check and left a third, red, testing the corpse.

### 4.2 Deploy freshness — **5 checks, 1 job, 1 survivor**

`tools/smoke.sh` exists for exactly this. `bin/argus --mode doctor` reports it. `managent audit`
prints it. And four `regression-managent-*.sh` scripts each re-implement it as arm 0 and fail the
whole script on it. **Recommendation: one suite preflight (`tools/smoke.sh`), run once, refusing
loudly; delete the four arms.** Net: −4 reds for one deployment step. This is the single cheapest
four-red reduction available and it does not weaken a thing.

### 4.3 Store-shrink fixture hygiene — **5 reds, 1 mechanical fix, and a structural one**

T855 fixed this class for four scripts by adding `weizigo_reset_census` to the shared scratch-repo
helper; **29 scripts source that helper and 5 still hit the detector**:
`regression-dispatch-caps.sh`, `regression-managent-status-json.sh`, `regression-fleet-keeper.sh`,
`regression-argus-doctor.sh` (arms 12/13), and — by the same mechanism — any fixture that removes a
row from a scratch store by hand.

**Recommendation:** source the helper in the five (mechanical), and then make the class impossible
rather than fixed: `tools/regression-scratch-repo.sh` is the check that owns the shared fixture
substrate, and it is **unwired** (§4.5). Wire it and give it an arm that fails when a fixture writes
`tasks.json` directly without resetting the census. Otherwise T855's repair will be re-done a third
time. *(Prose is not a remedy for a mechanism failure — this class has now recurred twice.)*

### 4.4 The `git-commit-mine` worktree guard — **3 reds, 1 code fix**

`regression-{git-commit-mine,commit-concurrency,claim-lifecycle}.sh` are **not** duplicates — they test
three different subjects — but they share one blocker, and all three pass when the `< 2000 files`
constant is neutralised. **Recommendation: fix the guard to implement the relative invariant its own
comment states**, then re-read all three. Do not touch the three scripts; there is nothing wrong with
them. This is the highest-leverage single code change in the batch: one guard, three reds, and the
guard starts doing the job it was written for (it currently cannot protect a small tree at all).

### 4.5 The 8 unwired scripts — wire 5, delete 3

`regression-arbiter.sh` · `regression-managent-done-git.sh` · `regression-managent-memory-safety.sh` ·
`regression-process-ownership.sh` · `regression-race-collect.sh` · `regression-request-accounting.sh` ·
`regression-scratch-repo.sh` · `regression-task-identity.sh`

Three are red and classified in §3 (`memory-safety` R13, `process-ownership` R16, `task-identity` R15);
five are green and classified at U1–U5 in §5. None should be deleted — `race-collect` guards the
blinding step that race-protocol-v2 exists to enforce, and `scratch-repo` owns the fixture substrate
29 other scripts depend on. **Being unwired is the worst place to have coverage of a shared substrate.**

### 4.6 `regression-window-resilience.sh` is wired into the suite twice

`build.zig:679` (`window_regression`, T628 wiring) and `build.zig:914`
(`window_resilience_regression`, T677 wiring) both `test_step.dependOn`. The T628 and T677 controls were
merged into one script and neither wiring was removed. **Recommendation: drop one line.** The suite
pays this script's wall twice for zero additional information — and reports two failures for one defect,
which inflates every red count taken from the step list.

### 4.7 Liveness — three checks, one reading, one idiom worth copying

`regression-task-identity.sh`, `regression-runner-claude-liveness.sh` and
`regression-runner-startup-liveness.sh` all read `managent liveness`. Do **not** consolidate them —
they test different fuses. But only `task-identity` races the wall clock (R15); the other two pin
timestamps and are green. **Recommendation: adopt the pinning idiom in `task-identity`** rather than
widening its window, which would only make the race rarer.

---

## 5. Two sweeps, one day, two answers — and why

`T861` landed a per-script known-red baseline of **24** scripts on 2026-08-24, measured with
`tools/runner --max-wall 60 -- sh <script>`. This row measured **26** with a 300 s watchdog. The sets
are not in dispute; the difference is instructive and belongs on the record.

| script | T861 | T870 | why |
|---|---|---|---|
| `regression-ollama-dispatcher.sh` | green | **red** | the T821 admission arbiter refused an 18 GB local lane. T861's run had host headroom; mine did not. **The verdict is a function of free RAM.** |
| `regression-precommit.sh` | green | **red** | the hook's null control runs on the live tree, and by the time I ran it **T861's own uncommitted, held paths were in it.** The measuring row changed the measurement. |

The two sweeps also used different watchdogs, and that changed what could be *diagnosed* rather than
what was red. T861 recorded four of its 24 as *"killed as silent at the 60 s wall cap
(fleet-keeper, managent-memory-safety, process-ownership, watch-fleet — they sleep/poll and are
full-suite material, not broken)"*. With a 300 s watchdog all four produced a real, named failure:
98 s, 94 s, 66 s and >300 s respectively, and R10, R13, R16 and R7 below are the diagnoses. **A
timeout is not a verdict** — "killed as silent" and "fails for this reason" are different readings,
and only the second is actionable. `regression-watch-fleet.sh` needed an unbounded run to speak at all.

Three further disagreements are about the *diagnosis*, not the colour, and all matter for the green-up
worklist:

- T861 records `regression-git-commit-mine.sh` with disposition **`deploy`**. It is not a deploy
  problem; it is the worktree guard's absolute-threshold defect (R1), and "deploy" would never fix it.
- T861 records `regression-subagent-prompt.sh` as red with disposition `repair`. It **passes** at `HEAD`
  in a scrubbed environment (R20); what needs repairing is its inheritance of the caller's depth.
- T861 keeps `regression-battery-baselines.sh` / `-sweep.sh` in the red baseline while correctly marking
  them `not-precommit`. They are not red at all (R21/R22); the baseline overstates redness by two.

**A count from one source is provisional until a second source corroborates it.** Two sweeps, four
hours apart, on the same commit-adjacent tree, agreed on 24 scripts and disagreed on 2 — and *both
disagreements were caused by the fleet's own concurrent activity*. Any zero-red claim must state the
host state and the environment it was measured in, or it is not a measurement.

**One thing could not be computed: the difference against the *first* sweep** ("23 of 86"). Only its
count was recorded, never its list. A count without its list cannot be diffed, which is why this
document publishes the list.

---

## 6. The vacuity set — 11 entries

### 6a. The eight verified checks that cannot fail (C1–C8 of the what-is union)

Every citation below was re-opened and re-verified by this row; where a live reproduction was possible
it was done.

| # | check | module | what it currently asserts | verdict | reason |
|---|---|---|---|---|---|
| V1 | battery **I8** (truncation-gap), `checkI8` at `src/vb_fixpoint.zig:388-397` | `src/vb_fixpoint.zig` | nothing — returns `.not_applicable` unconditionally | **DELETE** | Repairing it would preserve the illusion that I8 is measured in the battery. **What disappears:** an `I8: not-applicable` line in every battery report — and today's run prints exactly that. **What is left untested:** the loopy-fixpoint vs first-revisit comparison at 2×2 — which the stub never tested either; the real coverage is the committed Python fixture the code's own comment names (`docs/evidence/QA-026/calibration-2x2-mismatch.py`). Delete the stub and report I8 as `external`, naming the fixture. A slot that reports `not-applicable` forever is a claim of coverage. |
| V2 | battery **I11** (move-set consistency), `checkI11` at `src/vb_fixpoint.zig:468-476` | `src/vb_fixpoint.zig` | nothing — returns `.not_applicable` with a note that the dump format is unspecified (GAP-5, from a T172 blind analysis) | **DELETE** | **What disappears:** an `I11: not-applicable` line. **What is left untested:** battery-vs-solver legal-move-set agreement — **genuinely uncovered, by anything.** That is the honest state and it should be registered as an open gap in the claims register, not parked as a check that reports `not-applicable` in perpetuity. Deleting the stub *reveals* the gap; keeping it hides it. |
| V3 | `managent standing` **STANDING-REEVIDENCE** trigger, `src/managent/main.zig:10503` | `bin/managent` | fires when C3 debt grows | **FIX-THE-CODE** | **The one vacuous check that must be repaired, not deleted, because its subject is real.** `triggered = c3_debt > c3_prior and c3_prior > 0`, and `parseStateJson` (`:2727`) skips every `_`-prefixed key, so `serializeState` drops `_standing` on any other store write and `c3_prior` reads 0 forever. The second conjunct is then permanently false. The code documents its own fix at `:10689`: make `_standing` a first-class field in `StateMap`. Deleting the trigger would delete the only mechanism watching C3 debt growth. |
| V4 | `suite-truth.sh` summary-count comparisons, `tools/suite-truth.sh:519` and `:523` | `tools/suite-truth.sh` | observed `steps-failed` / `tests-crashed` / `tests-failed` equal the manifest | **FIX-THE-CODE** | Each comparison is guarded by `[ -n "$OBS_…" ]`, which cannot distinguish *nothing to compare* from *the regex failed to parse the Build Summary*. When Zig's summary format shifts — which it did once already, and T789 had to re-derive the regexes — all three comparisons go silently vacuous and the ratchet keeps exiting 0. **A ratchet that stops comparing without saying so is worse than no ratchet**, because it is trusted. Fix: when the Build Summary line is present but unparseable, fail loudly. |
| V5 | `tools/regression-runner-host-guard.sh` | `tools/runner` | nothing — echoes three lines and `exit 0`; wired at `build.zig:333` | **DELETE** | Its own header: *"This script cannot be repaired into passing"* — the T362 floor and tenant add-back it tested were deleted by T821. **What disappears:** one guaranteed pass in the suite's passing count. **What is left untested:** host-pressure admission — covered by `regression-arbiter.sh` once §4.1 wires it. An `exit 0` stub inside `zig build test` does not merely measure nothing; it *inflates the denominator of green*. |
| V6 | `tools/regression-subagent-resident-gate.sh` | `bin/subagent` | nothing — same shape, `exit 0`; wired at `build.zig:352` | **DELETE** | Same: the T713 resident-aware memory gate it tested was deleted by T821, and its controls assert per-provider special-casing that no longer exists by design. Same replacement (§4.1). |
| V7 | `tools/orcha-acceptance.sh` **AC3**, at `tools/orcha-acceptance.sh:89-90` | `tools/orcha-acceptance.sh` | `say AC3 PASS "enforced by tools/hooks/pre-commit (T455); this check reports, the hook blocks"` — an unconditional PASS | **DELETE** | It states in its own message that it measures nothing. **What disappears:** one of eleven acceptance lines, and a PASS the seat has been reading as evidence. **What is left untested:** nothing — the T455 holder-collision refusal is really covered by `regression-precommit.sh` and `regression-git-commit-mine-hook.sh`. Renumber AC3 out; do not "repair" it by re-reading the hook's log, which would be a second implementation of a check that already exists (§4.2's error class). |
| V8 | `bin/argus` checklist slug **`claimlint-green`**, regexes at `bin/argus:385-391`, always-green branch at `:419-427` | `bin/argus` | claimlint's C1a/C1b/C2/C6 counts are at or below the floor | **DELETE** | **Re-verified live.** claimlint prints `C1a ORPHANED orphans: 0`, `C2 DEAD-LINKS total: 0`, `C6 MISCITED cite-tag mismatches: 0`; the regexes search for `C1a orphans:`, `C2 total:`, `C6 cite-tag mismatches:`. None match — the section names were inserted into the labels and the patterns were never updated. Every parsed value stays `None`, the floor loop's `if val is not None` skips all four, `violations` is empty, and the check emits *"at or below floor"* unconditionally. **What disappears:** the `checklist` mode, which has no production consumer (`DARGUS` runs `--mode doctor` only; `checklist` is exercised solely by a regression test with a synthetic registry) — **and with it `bin/argus:365`'s second, looser `CLAIMLINT_FLOOR = {"C1a": 10, "C2": 12, "C6": 0}`**, a divergent copy of a floor whose real value is `C1a=0, C2=0, C6=0`. **What is left untested:** nothing — `tools/hooks/pre-commit` is the real floor gate and it is green and wired. Note the compounding: a dead check kept a stale floor alive, and the stale floor was 10 and 12 where the truth is 0. |

**C8/V8 is the same mechanism as the what-is document's D11** (a surface that emits a false "at or
below floor"). It is counted once here, as a check.

### 6b. Two classes neither observer named (found by this row)

| # | class | module | what it currently asserts | verdict | reason |
|---|---|---|---|---|---|
| V9 | **`set -euo pipefail` makes the FAIL branch dead code.** Sites: `tools/regression-managent-memory-safety.sh:29-36` and `:40-47`; `tools/regression-managent-status-json.sh:217`. | the regression harness itself | the arm's `if [ "$RC" -ne 0 ]; then echo "FAIL: …"` | **FIX-THE-TEST** | The idiom `cmd >/dev/null 2>/dev/null` followed by `RC=$?` cannot work under `set -e`: the shell exits at `cmd` and the FAIL message is unreachable. The same applies to `VAR=$(cmd)` — an assignment takes the substitution's status. **Both scripts were red today with a truncated log and no stated reason**, which is exactly how this class hides: the exit code is still non-zero, so the gate is satisfied and nobody reads the log. Fix: `cmd; RC=$?` → `if ! cmd; then …` or `cmd || RC=$?`. The two named sites are what a pattern scan found; the executing row owes a full census. |
| V10 | **A SKIP is delivered to the gate as a PASS.** Measured: **7 of today's 65 green scripts skipped at least one arm and still exited 0**; **43 of 88 scripts contain a SKIP-then-`exit 0` path**. | `tools/suite-truth.sh` (the gate), not the scripts | by omission: that a zero exit means "verified" | **FIX-THE-CODE** | Individual skips are legitimate — `sudo -n` is unavailable, an artifact is absent on a fresh clone, a binary is not built. What is not legitimate is that **the suite cannot report how much of itself ran.** `regression-managent-status-json.sh:40` is the clean example: no binary → `echo "SKIP…"; exit 0`. Before a build, that check is green and blind. Fix belongs in the gate, not in 43 scripts: count and report skipped arms as a third surface alongside reds and counts, with its own ratchet. **Until this exists, "all green" is not a claim anyone can check** — which is the precise dishonesty the operator named. |

*(V10's verdict is FIX-THE-CODE rather than FIX-THE-TEST because the change lands on the gate —
`tools/suite-truth.sh` — not on any check.)*

---

## 7. The five unwired-but-green scripts

For an unwired check, **FIX-THE-TEST means "wire it"** — the defect is in the check's installation and
the change lands on the check side, not the system side. **DELETE** would mean it should not exist. None
of the five should be deleted.

| # | check | module | what it asserts | verdict | reason |
|---|---|---|---|---|---|
| U1 | `tools/regression-arbiter.sh` | `tools/runner` (T821 arbiter) | real co-launch, futile-kill structurally impossible, effective overrun-stop, refusal-at-admission, and a null control | **FIX-THE-TEST** (wire it) | It is the **replacement** coverage for `regression-runner-host-guard.sh`, a check retired as unrepairable — and the replacement is the one nothing runs. It is the survivor of the §4.1 four-way consolidation, so wiring it is a precondition for deleting three scripts. One `addSystemCommand` line. |
| U2 | `tools/regression-managent-done-git.sh` | `bin/managent` | `managent done`'s commit path (T278) | **FIX-THE-TEST** (wire it) | Green today; sources the shared scratch-repo helper, so it is store-census-clean. No reason to be outside the gate. |
| U3 | `tools/regression-race-collect.sh` | `tools/race-collect.py` | content-hashing of the judge's blind set, and refusal of a set that leaks attribution | **FIX-THE-TEST** (wire it) | Green today. **The failure mode it guards — a leaked attribution — is the one thing race-protocol-v2 exists to prevent**, and it was explicitly preserved through the S06 consolidation for that reason. Leaving it unwired is the worst case of the eight. |
| U4 | `tools/regression-request-accounting.sh` | `tools/runner` / token accounting (T850) | per-request accounting invariants | **FIX-THE-TEST** (wire it) | Green today; T850 is closed. Its subject feeds the cost ladder. |
| U5 | `tools/regression-scratch-repo.sh` | `tools/lib/scratch-repo.sh` | the shared fixture substrate — including `weizigo_reset_census`, T855's repair | **FIX-THE-TEST** (wire it, and extend it per §4.3) | **29 regression scripts depend on this helper and nothing runs its own suite.** It is also the natural home for the arm that would make the §4.3 class structurally impossible instead of repaired-again. |

---

## 8. Notes the executing row must not lose

1. **Order matters, and two fixes unblock the rest.** Deploy `bin/` (§4.2) and fix the worktree guard
   (§4.4) and **7 of the 23 reds resolve without touching a single check.** Then the store-census
   hygiene pass (§4.3) takes 5 more. Then the landmark fixtures (R18/R19, and R10's second cause) take
   3. That is 15 of 23 in four mechanical steps, leaving 8 that need real thought.
2. **`regression-task-id-archive.sh` (R6) must not be deleted to reach zero.** It is a test written
   before its code, for `T770`, which is still `dispatchable`. Under the operator's own acceptance rule
   — *every change starts red* — a correct red is the expected state of a test whose code has not
   landed. **Zero red and "every change starts red" are only compatible if red-by-design tests are
   marked as such**, with an owner and an expiry, exactly as T861's ratchet does. If the green-up
   deletes R6 to make the count come out, it will have destroyed a bug report to improve a metric.
   Land T770 or carry R6 as an owned, expiring entry. Do not delete it.
3. **T861's ratchet must be deleted, not emptied.** Its own §11 says so, and this row's classification
   is the worklist that discharges it. Note that three of its 24 entries are misdiagnosed and two are
   not red at all (§5) — reconcile the baseline against this document before burning it down, or the
   ratchet will be deleted with two entries that were never failures and one whose disposition
   (`deploy` for R1) would never have worked.
4. **Do not "fix" a check by giving a second tool the same job.** V7 is the worked example: the honest
   repair of an unconditional PASS is to *delete it*, because the coverage already exists elsewhere.
   The suite has 12 jobs with more than one implementation already; the green-up should end with fewer,
   not more.
5. **Every entry above is reproducible, and none of it was fixed here.** `git status` shows this row
   touching exactly two files: this document and its findings.
