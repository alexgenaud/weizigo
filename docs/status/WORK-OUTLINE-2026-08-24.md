# Work outline — 2026-08-23/24

**Status keys:** `DONE` landed and verified · `PROGRESS` running now · `TODO` specified, not started
· `BLOCKED` waits on something named · `FAIL` attempted and did not land · `OPEN?` needs an
operator ruling.

**Provenance warning.** Written by the outgoing seat at 82% context. It made real errors under that
load (see `RESUME-orcha.md` §incident). Every line below is derived from the task store and the
filesystem, but **spot-check before acting**. Where this contradicts `bin/managent status`, the
store wins.

---

## 0. IMMEDIATE — the queue is lying about 36 tasks

- `FAIL` The 2026-08-24 store revert lost 59 tasks; re-registration recovered their briefs but **not
  their completion state**.
- `TODO` **36 tasks sit `dispatchable` while holding committed findings — they finished.** The 36, each holding
  committed findings:

  > T785 T788 T789 T790 T791 T792 T793 T794 T797 T799 T800 T801 T802 T803 T804 T805 T806 T807 T808 T809 T810 T811 T812 T813 T814 T817 T820 T821 T823 T824 T826 T827 T828 T829 T831 T835

  Close them on committed-findings evidence, as T774/T776/
  T780/T781/T783 were closed. **Until this is done the queue will re-dispatch a day of work.**
- `TODO` 6 of the 43 reconstructed rows have no findings at all — those genuinely need re-running.

## 1. Measurement integrity

- `DONE` 448 lost token readings recovered; ledger coverage 20% → 53%.
- `DONE` glm, minimax, kimi, oxalpha had **never** been metered; now are.
- `DONE` Token counts proven **not rankable** — CV 0.14–0.34 over 20 repeats (T774).
- `DONE` Cost removed from model selection; picker now `solo-least-data` (T772).
- `DONE` `canon_tag` parity — a serving tag was reaching the ledger.
- `DONE` Within-model variance measured: 22/28/33/36/37 on one brief — n=1 orders nothing.
- `TODO` **Nothing writes the model-perf ledger automatically.** 24 rows across 72 cells; 59 empty;
  oxalpha 0 of 8 despite 7 completed tasks. Deepest remaining measurement gap.
- `TODO` T750 record canary_recall / fabricated_citations / unique_catch; retire `thoroughness`.
- `TODO` T751 token join + trust grades end to end.
- `BLOCKED` T819 three-way corpus agreement (waits on T818's close).

## 2. Testing — built from nothing

- `DONE` 300+ unit arms across five modules, 0.172 s. **Zero existed before 2026-08-23.**
- `DONE` Round-trip tier on the `--test-worker` seam: 10 arms, 70.6 s, labelled OUTCOME /
  SCAFFOLD / PINNED-DEFECT so tests cannot freeze the interfaces.
- `DONE` Suite re-baselined: 112/122 steps, 1344/1348 tests, 906 s; smoke 1 s.
- `DONE` Three-tier gate wired into pre-commit with change-based selection (T789).
- `TODO` S09 module contracts (T790's spec exists, nothing built).
- `TODO` The overnight exhaustive tier — specified, not built.

## 3. Consolidation — one door per job

- `DONE` Census: **ten jobs** had more than one way to do them.
- `DONE` One canonicalizer (was four, one parity control, one phantom control reference).
- `DONE` One short-name table (was two — **and they had diverged**).
- `DONE` Caps enforced at dispatch (T845); it refused the seat on its first live test.
- `DONE` S06 arbiter pass (T821).
- `OPEN?` S06 shape **ratified**; passes 1, 3, 4, 5, 6 need minting. Interleave ordinary work
  through the changed mechanism between passes.
- `TODO` The dispatch rewire (pass 5) is where **five doors become one**; 159 of 364 executions
  had skipped the layer adding the nonce and the token meter.

## 4. Fault tolerance and transparency

- `DONE` T846 — S10 spec written. Direction: the close **computes** the verdict from checked
  conditions; `unverified` becomes first-class; the close is refused only where deliverables are
  declared and absent.
- `OPEN?` **The operator bookends S10 before pass 1.**
- `TODO` **Store-loss detector.** The record of what work exists has silently vanished twice.
  Highest severity in the project.
- `BLOCKED` T798 kill/attempt history on the task (`killed_by`: 18× in the runner, **0×** in the
  schema; 1,476 kill events live only in gitignored state).
- `BLOCKED` T816 the close contract; T815 parent IDs and derived prefixes.
- `TODO` Per-**model** request budget — minimax took 790 of ~792 Ollama requests and produced
  nothing, starving its own family. A per-family cap cannot prevent that.
- `TODO` Partial-delivery preservation: glm delivered a patch then died; the dispatcher reopened
  the task with **no record that usable work existed on disk**. Recovery works; preservation does not.

## 5. The repository corruption

- `FAIL` The repo was silently repointed at a scratch dir **twice in thirty minutes**; commits
  truncated **2,556 files to 4**; the task store was overwritten and 59 tasks vanished.
- `DONE` Root cause: `tools/hooks/pre-commit` runs a regression script that `git init`s a scratch
  dir; **58 scripts do that and none unsets `GIT_DIR`**, which git sets for hooks.
- `DONE` Guard 1 — `WEIZIGO_GITENV_ISOLATION` in the hook (one line, covers all 58).
- `DONE` Guard 2 — `WEIZIGO_WORKTREE_GUARD` in `git-commit-mine`: refuses a repointed repo or a
  commit onto a HEAD under 2,000 files.
- `FAIL` The outgoing seat moved `main` onto a truncated 6-file tree before noticing. Recovered.
- `TODO` Why does testing a task queue require 58 scratch repositories at all?

## 6. Simplification (operator: assume everything is a vibe hack)

- `DONE` 10 of 11 git worktrees removed — scratch copies of races finished days ago, and the
  hijack vector.
- `DONE` A `watch-fleet-live.sh` running **10h43m** from an integration-test scratch dir, killed.
- `DONE` A task literally named `--bundle`, dispatchable since 2026-08-08, retired.
- `DONE` `com.weizigo.suite-truth` launchd agent (daily, unattended, full suite) **disabled**.
- `PROGRESS` **T847** — one worker inventorying every moving part: what it is for (or `UNKNOWN`),
  who invokes it, blast radius, verdict, plus **the list of parts whose failure would be silent**.
- `OPEN?` Should the daily suite agent return?
- `TODO` Unjustified: six ways to run tests · four places kill records live (only the tracked one
  empty) · two task stores · `untracked/` at 800+ files · one worktree that refuses removal.

## 7. Epistemic tree — the only theme touching the product

- `DONE` C2 dangling citations **13 → 0**; C3 46 → 42.
- `DONE` New-volatile-citation ratchet: a fresh `untracked/` or `/tmp/` citation now fails the commit.
- `DONE` Glossary: `arm`, `lane`, `row` defined.
- `BLOCKED` T836 board proof census — per board size, **proven vs optimal-not-proven vs unknown vs
  untrustworthy**, each with rule set, citation and falsifier; then the ordered path to 4x4.
- `BLOCKED` T837 — C3's 42 PROVEN-without-evidence rows triaged; the "no evidence at all" count is
  how much of our *proven* is assertion.
- `TODO` C10 volatile ~1375 (grandfathered) · C13 unclassified 24 · C12 dead globs 5.

## 8. Races — collected and unread

- `DONE` RACE-X: S06 spec audited by three models, graded by three; first `fail-found` verdict in
  573 tasks; independent count **12 of 37** requirements armed against a claimed 22 of 31.
- `DONE` Race W re-judge: four blind judges; **split**, so it escalates to the operator's panel.
- `DONE` Diff race (six models patching one file via patches — makes `implement` raceable).
- `DONE` Rate race dispatched; ollama entrants died on the window cap.
- `TODO` **Three races' judgments are unread.** Measurement collected and not consumed.
- `OPEN?` Race W Section B — 2–2, needs the operator's panel.

## 9. Model roster

- `DONE` Ollama returned; oxalpha onboarded and measured (7 tasks, best clean-pass rate).
- `DONE` Appetite equalised in code; the 0–9 dial **specced but not implemented** — eight models at
  `spend` is *permitted-equally*, which is weaker than *drawn-equally*.
- `TODO` Implement the dial; retire `conserve` (no branch — behaves as `spend`) or give it meaning.
- `TODO` qwen appetite → 1 (T833, blocked on the main.zig chain).
