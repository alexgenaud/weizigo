# OPEN — pending work, open questions, and known issues

**Purpose.** The operator asked (2026-08-24): *"Please keep track of all the pending tasks and ideas
and open discussion. Keep track of any issues and new items that require discussion."* This file is
that register. It is **maintained by the oversight seat**, tracked in git, and regenerated rather
than remembered.

**What lives where.** `bin/managent status` is live truth about tasks — this file never competes
with it, and the generated section below is a dated snapshot, not an authority.
`docs/status/roadmap-2026-08-23.md` holds the reasoning and the rulings.
`docs/status/landmark-waypoints-seed-2026-08-23.md` holds the ratified intent. This file holds the
things that are **owed, undecided, or wrong** and would otherwise live only in a conversation.

---

## A. Owed to the operator — decisions only he can make

| # | item | state |
|---|---|---|
| A1 | **Race W Section B** — 2–2 split between the opus and ox-alpha terminology rewrites; the protocol escalates a split to his own panel. Section A leans opus 3-of-4 with one tie. | awaiting his panel |
| A2 | **Does D044's DeepSeek time-priced rate band survive the budget-meter retirement?** The band is a fact about *when* a run happened, computed at write time; the retirement says agents know nothing of costs and never mention peak hours. | flagged, not decided |
| A3 | **Filling the 12 now-recoverable `cost: null` lanes in the sha256-sealed `tools/complementarity-inputs/*.json`** would change a dispatch-decision input using `trusted:false` readings. Deliberately not done. | ratification question |
| A4 | **Is the pi/openrouter API-key pattern more secure, and should claude / deepseek / ollama converge on it?** He raised it; it is a security review, not a measurement question. | unowned |

## B. Known issues with no owner yet

| # | issue | evidence |
|---|---|---|
| B1 | **Nothing writes the model-perf ledger automatically.** 24 rows across 72 possible cells; 59 empty; 9 of the 13 filled are `audit`. ox-alpha has **0 of 8** despite 7 completed tasks. Making each race's judge write its cells (T832) is a per-race instruction, not a mechanism. | `docs/infra/model-task-metrics.jsonl` |
| B2 | **The appetite table is compiled into `src/managent/main.zig`** with no file or env override, so a roster change needs a source edit, a rebuild, and a slot in a serialized chain. S06 pass 1 (the policy file) is the fix. | T834's own findings |
| B3 | **A consolidation pass editing a live file breaks the fleet while it works.** T821's arbiter edit left `name 'host_guard_on' is not defined` in `tools/runner`; 13 dispatches died in 0.1 s inside a 7-second window. `tools/runner` is re-read on every dispatch, so passes must land atomically or work on a copy. | the 13 `runner exception` records of 2026-08-23T22:19, cited in T821's findings |
| B4 | **ox-alpha does not reliably echo the dispatch nonce** — three instances (T770, T776 via raw pi; T818 through `bin/dispatch`, so the door is not the explanation). Work quality high, protocol compliance unreliable. | T818 findings |
| B5 | **`dispatch_verify` cannot distinguish "nonce not echoed" from "work absent."** T818 was complete — 12/12 chunks, 579 rows — and read as *orphaned* for two hours. | the diff race (T826–T831) fixes this |
| B6 | **A findings file citing volatile paths now fails the commit gate**, which is correct — but corpus-mining tasks must read `untracked/` sources. They must cite the committed corpus they produced, not the volatile sources they read. | T814's C10-NEW gate, hit by T818 |
| B7 | **The progress fuse still reads stdout only.** pi buffers to completion, so a working console looks dead: qwen/T824 sat at 2,951 log bytes for 33 minutes while its session file grew to 573 KB across 25 bash calls. The display half is fixed (T823/D082); the fuse half is `tools/runner` and needs a task. | T773, T823 |
| B8 | **92% of all closes are a pass; `fail-found` has been used 4 times in 573 tasks.** T816 makes the verdict explicit; whether the ratio then moves is the real test. | measured 2026-08-23 |

## C. Ideas raised and not yet dispatched

| # | idea | note |
|---|---|---|
| C1 | **A 'go science' race** — the operator suggested one to fill important cells deliberately rather than opportunistically. | his words, 2026-08-24 |
| C2 | **Stagger opus and sonnet onto corpus mining** after the grading rounds close, purely as model comparison. | deferred for Claude window contention |
| C3 | **Racing Zig design and planning in parallel** while implementation stays serial — diffs make scripts raceable, Zig not. | operator, 2026-08-24 |
| C4 | **`untracked/` is unnavigable** — 800+ files, briefs mixed with logs and scratch. Briefs are deliberately ephemeral, but that is not the same as unnavigable. | folded into T787 |
| C5 | **Every hand-picked constant needs a derivation or a deletion.** `total // 8` is gone; still unexamined: `MEMORY_GATE_MARGIN_MB` 2048, `FALLBACK_COOLDOWN_SECONDS` 30 min, `ARM_FRESHNESS_SECONDS` 3 h, `--poll-ms` 250, `--rss-cap-mb` 12288, `MAX_DEPTH` 3. | pattern found via T806 |

---
## Queue state, generated 2026-08-24T06:44Z

### IN FLIGHT (7)

- **T771** `claude-opus-5` — 
- **T818** `ox-alpha` — blind second derivation of type/scope/capabilities, chunks of 50, append-only chunk file
- **T822** `deepseek-v4-flash` — convergent, not another amendment: 25 unarmed ids each get an arm or get deleted; no thi
- **T828** `claude-sonnet-5` — diff race entrant: dispatch_verify nonce-vs-no-work, patch against a015496, scored by 17
- **T829** `claude-haiku-4-5-20251001` — diff race entrant: dispatch_verify nonce-vs-no-work, patch against a015496, scored by 17
- **T831** `ox-alpha` — diff race entrant (ox-alpha): dispatch_verify nonce-vs-no-work, patch against a015496
- **T834** `deepseek-v4-pro` — ollama back; 8 models equal at dial 5, oxalpha 9, fable reserved, qwen left to T833. Ver

### DISPATCHABLE (19)

- **DCLAIM** — DUTY per docs/infra/duties.md — never completes, one chunk per invocation, due after 5 t
- **STANDING-ABSORB** — C7 unabsorbed findings: 0 (closed partition, T481/T486 — the threshold of 5 was deleted 
- **DRPLAY** — DUTY per docs/infra/duties.md — never completes, one chunk per invocation, due after 5 t
- **DARGUS** — DUTY per docs/infra/duties.md — run argus doctor once and ACT on each item; never comple
- **STANDING-CLEANUP** — Working tree clean at last sweep (cooldown 2026-08-20); trigger is dirty-across-two-turn
- **--bundle** — 
- **T529** — 
- **T535** — 
- **T709** — 
- **T712** — 
- **T715** — 
- **T735** — ox-alpha shadow lane on race-G science set; model set at dispatch once T732 onboarding l
- **T750** — record canary_recall + fabricated_citations, retire thoroughness; backfill T706/T626/T55
- **T751** — token join: split into tokens.jsonl, canon_tag knows ox-alpha, metrics cost join; method
- **T753** — score the completed ox-alpha lanes T735/T744 against T730's ruling; no new ox-alpha spen
- **T764** — 
- **T787** — move 10 orphan sprints under their landmark, races to a sibling level, docs/epics/README
- **T825** — T814 follow-up: commit-or-repoint 29 bucket-(b) Tier-B rows, downgrade-or-rescope 13 buc
- **T830** `qwen3.8:27b-mlx` — diff race entrant: dispatch_verify nonce-vs-no-work, patch against a015496, scored by 17

### BLOCKED (10)

- **T767** — waits on T834 — 
- **T768** — waits on T767 — 
- **T775** — waits on T768 — 
- **T786** — waits on T775 — backfill task type (derived, labelled) + scope for 403/417 rows; assert both at registra
- **T798** — waits on T775 — killed_by is 18x in tools/runner and 0x in the kanban schema; 32 tasks have killed attem
- **T815** — waits on T798 — 573 tasks, zero parent linkage: race entrants and sprint passes have T-IDs and nothing s
- **T816** — waits on T815 — 67% of tasks never stated what done means; 92% of closes are a pass; fail-found used 4 t
- **T819** `claude-opus-5` — waits on T818 — third-party adjudication of two blind corpus derivations: per-field agreement, confusion
- **T832** `claude-opus-5` — waits on T828,T829,T831 — apply each patch in isolation at a015496, run the 172 pre-existing arms, disqualify non-
- **T833** — waits on T816 — operator: set qwen appetite 0 or 1 after T824. Recommend 1 (his own semantics: only when

---

## D. How this file is kept

Regenerate section "Queue state" from `bin/managent status --json`; edit sections A–C by hand when
an item is raised, resolved, or dispatched. **An item leaves this file only when it is dispatched,
decided, or explicitly killed** — never because it went quiet. When an item becomes a task, replace
its row with the task id so the trail survives.

## B-new. Issues found 2026-08-24 morning — for discussion on the operator's return

| # | issue | evidence |
|---|---|---|
| B9 | **The task store silently lost 59 tasks.** `tasks.json` reverted to a pre-T785 snapshot (409 tasks, max id 784) and was committed in that state at `cbb0b70`. Both live races, the appetite change, the board census and the epistemic sprint vanished; a running worker surfaced it by logging `FAIL kanban: task T836 not found`. **No fuller snapshot exists in git**, so verdicts, notes and impressions for T785–T824 are unrecoverable. Repaired at `67780db` by re-registering 59 tasks from their briefs (marked RECONSTRUCTED) and restoring the chains by hand. **This is T716's defect unfixed**, and it is the single most dangerous thing in the fleet: the store is the only record of what work exists. | `67780db` |
| B10 | **Claude is being rate-limited.** T836 (opus) recorded `provider refusal (reason=provider-429): the model was never reached — recorded as unreached, not a task failure`. The runner classifies it correctly, which is good; the operator's instinct that Claude is strained is confirmed. Only 4 Claude runs in the trailing 5-hour window, so the cause is not our volume. | `untracked/log/t836.log` |
| B11 | **The shared git index carried a corrupt entry** for the gitignored built binary `bin/weizigo-claimlint` (object `58b7066` absent from the object store), making every ordinary commit fail with `Error building trees`. Cleared with `git reset -- <path>`; `git write-tree` is healthy again. Something stages a gitignored build artifact — likely a hook or a build step — and that recurs. | this session |
| B12 | **A stale `in_progress` cohort came back with the reverted store**: T770, T774, T776, T780, T781, T783 all read in flight while being complete. `managent reap` is the tool; their verdict history is among the losses in B9. | store diff |
| B13 | **The test gate is live and working** — `pre-commit: … test gate: PASS (37s, budget 45s)`. Noted here because it is the first time a commit in this repository has been gated on tests, and its 45-second budget is now a load-bearing number. | T789 |

**My own two errors this session, recorded because they cost operator attention:** I called the
appetite table a structural blocker when `bin/dispatch <task> <model>` never consults appetite —
glm/kimi/minimax were usable the whole time. And a log-grep of mine reported "session limit" and
"rate limit" hits that were **documentation strings inside task output**, which is precisely the
T677 incident (a cooldown once armed from a quoted document). I nearly repeated it as a diagnosis.

## B-new-2. Found and acted on 2026-08-24 by the incoming orchestration seat

| # | issue | disposition |
|---|---|---|
| B14 | **The store repair left 36 completed tasks reading `dispatchable`, which silently blocked four race judgments.** Of the 43 rows re-registered from briefs after the 59-task loss, 36 carried a three-signal evidence set — committed findings **and** a run record with `exit=0` **and** a recovered model label **and** a real wall (265 s–4891 s). Because the entrant rows could never close, `needs` was never satisfied and the diff race, the rate race and the corpus three-way sat `blocked` indefinitely. Nobody would have noticed except a human asking why the races were never judged. | **RESOLVED.** 33 closed `pass` and 2 (`T841` kimi-k2.7, `T842` minimax-m3) closed `abandoned` — each on evidence, each noting that the grade was *not* re-derived. `T832` auto-unblocked. Remainder below. |
| B15 | **`managent lanes` is blind to this drift class.** It censuses findings-without-a-row and rows-without-findings, but not **row exists + `dispatchable` + findings already on disk** — the class that cost 36 rows. A census reporting two of three classes reads as "no drift" for the third. | open — needs an owner |
| B16 | **A dependency edge can outlive the evidence that satisfies it.** `needs` pointing at a row that can never close is the same falsehood as a destroyed verdict, in a different field. Closing the rows cleared it this time; nothing prevents a recurrence. | open — belongs in S10 |
| B17 | **Partial-delivery preservation, live instance.** `T840` (glm-5.2) exited 1 after 2929 s with **both** declared deliverables on disk, and was self-healed back to `dispatchable` carrying no record that usable work existed. Recovery works; preservation does not. | evidence for S10 |
| B18 | **Closing on evidence is gated on that evidence being committed**, which is correct — and it is why five rows remain open: `T799`, `T804`, `T823` (a shared deliverable has uncommitted modifications), `T840` and `T818` (findings files untracked). `T818` additionally trips `C11` — a tier-A status change with no `audited_by`. | open — bounded, named |
| B19 | **claimlint's summary prints a false red.** `C2 dangling evidence paths 5 (FAILS)` while C2's own detail section reports `total: 0` and states that those 5 bulk `.wzo` items do **not** fail. A false red in the instrument that gates every commit is how bypasses get learned. | open — needs an owner |

**Genuinely never ran, correctly `dispatchable`:** `T786`, `T787`, `T796`, `T798`, `T825`, and `T836` (whose run record shows `exit=1` — the provider-429, so the model was never reached).

**Method note, recorded because it nearly misled me.** `untracked/runs/<id>.json` — the bare file — is authoritative and holds the latest real attempt; the numbered siblings are mostly sub-2-second stubs. A glob that sorts `T814.1.json` ahead of `T814.json` reads `wall=1.0 s, model=None` for a run that actually took 4891 s on `deepseek-v4-pro`. Any future reconciliation must read the bare record, never a sorted glob.

## B-new-3. Found while finishing the reconciliation, 2026-08-24 (orcha seat)

| # | issue | evidence / disposition |
|---|---|---|
| B20 | **A race entrant's submission was sitting applied in the shared working tree.** The uncommitted diff to the rate race's own target file shared **343 of its 355 added lines** with `T840.patch` (glm-5.2's entry) — against 23 for T839 and 9 for T838. The entrant edited in-tree, captured the patch, and died before cleaning up. Committing it — which the reconciliation nearly did — would have made one entrant's code the baseline every other entrant is judged against. This is the Race-G contamination failure in a new place. | **RESOLVED.** Baseline restored from HEAD; the entry is preserved three ways (its own patch, the `.delivered-before-death` copy, and a captured working-tree diff). Race judging must apply each patch in isolation at the pinned commit, never against the working tree. |
| B21 | **RETRACTED — there is no citation deadlock.** I claimed the race protocol and the volatile-citation gate were mutually incompatible, inferring it from T847's failure without testing this case. Tested: `findings/T840-ratrace.json` cites four `untracked/` paths and **committed cleanly**. `C10-NEW` parses citations in documents that register evidence, not arbitrary strings in a findings file. The real and much narrower constraint is that a *declared deliverable* must be committed — so a race patch under a gitignored directory blocks its own row's close until force-added. `T840`'s patch is now committed (c2c2f7b), which also fixes B17 for that instance: a patch in git survives its worker's death. All four race judgments are unblocked. | the commit that disproved it |
| B22 | **`T771` cannot close honestly: its declared deliverable was never written.** The outgoing seat's row declares `findings/T771-oversight-seat.json`, which does not exist, so the close gate refuses it — correctly. The row also still carries `claude-fable-5`, faithful to its origin (Fable held that seat on the 23rd) and stale for every holder since, because seat handovers reuse one row rather than minting a new one. | open — writing that findings file is within the read-only advisor's remit and is the one act that closes its own row |

**Reconciliation outcome.** 39 rows closed on evidence (37 `pass`, 2 `abandoned`). `T819` and `T832` unblocked and are dispatchable. `T843`/`T844` remain blocked on B21. Six rows never ran and are correctly `dispatchable`: `T786`, `T787`, `T796`, `T798`, `T825`, `T836`. Store count unchanged at 479 throughout; every invariant re-verified after each commit.

| B23 | **ox-alpha returned two empty responses, then probed healthy — the fault was transient, not the model.** Two dispatches of the store-loss detector row came back exit 0 in 13.1 s and 8.8 s with no nonce and no claim, six minutes after the same model had completed a substantial lane on the *identical* provider path. A direct probe immediately afterwards had it read that same brief, echo a nonce, and summarise the task correctly including its arm count. **So this is an availability blip and nothing more.** Recorded here because the seat's first write-up implied ox-alpha was the weaker choice, which the evidence does not support: switching the row to `deepseek-v4-pro` was a liveness decision on n=1, not a capability comparison, and the standing measurement has ox-alpha at the best clean-pass rate. Ranking these two requires a head-to-head on one row. | two attempt records for that row; a direct provider probe; the model's own correct summary of the brief |
| B24 | **`managent suggest` does not apply the bundle's `holds=` meta.** A row minted by `suggest` before its brief is written keeps `holds: []`, so the file-conflict guard protects nothing even though the brief declares it. Deliverables *are* read from the same header at dispatch, so the parser exists — only `holds` is dropped. `T848` holds `src/managent/main.zig`, the one-writer file, and its row claims to hold nothing. | `T848`'s row versus its own bundle header |

## C-new. Dispatched or queued by the orcha seat, 2026-08-24

- **T848 — store-loss detector (S10 pass 1).** RUNNING on `deepseek-v4-pro`. Scope deliberately
  narrowed on the operator's ruling (*"robust simplicity rather than flakey complexity… fix root
  problems"*): the committed census plus write-time refuse, read-time alarm and retirement
  bookkeeping. The `unverified` verdict class, the computed close, the concern channel and kill
  history are **deferred, not scheduled** — a sixth verdict state that every scorer and dashboard
  must handle is not justified while a truthful note in an existing verdict demonstrably works, and
  part of the computed close already exists and refused three of this seat's own closes correctly.
- **T849 — scratch-repo fixture.** QUEUED behind T848, deliberately, for steady pace. The root-cause
  fix the detector only nets: one sourceable helper replacing 77 hand-rolled `git init` calls across
  58 scripts, converting **five** scripts in this row and no more. Census established: 83 regression
  scripts, 58 with `git init`, 51 of those with exactly one; scratch roots split 65 `/tmp/weizigo`
  against 11 `/private/tmp/weizigo`, the same directory through the symlink that has already made
  git refuse adds. **The material finding: `tools/hooks/pre-commit` is the only file in `tools/` that
  unsets the git environment**, so every one of these scripts is still unguarded when run directly,
  by the suite, or by `zig build test`. The hazard is closed for one invocation path, not for the class.

## E. On wake — do these in order (written for a fresh or compacted context)

**First, always:** `bin/managent reap`; `git rev-parse --show-toplevel` is this repo;
`git config --get core.worktree` unset; `git ls-tree -r --name-only HEAD | wc -l` >2000;
`git show HEAD:.gitignore | wc -l` is 46. Re-verify after every commit.

**Then close out what finished.** T848 (store-loss detector, deepseek-v4-pro), T849 (scratch-repo
fixture, glm-5.2), T850 (per-model request accounting, claude-sonnet-5). A worker that exits without
closing its own row needs `bin/managent reopen <id>` before any re-dispatch — never re-dispatch a
live row. Verify each deliverable exists **and is committed** before believing a close.

**Then dispatch, at most four in flight, at most one per model, ordered:**

1. **T832 — diff-race judgment.** Brief still to be written. From the committed design intent: the
   172 arms were written by T793 *before* the race, two already red as recorded defects, so a patch
   cannot be graded against arms fitted to it; **breaking a green arm outranks elegance**; and **a
   patch that touches the test file is disqualified — diff the test file for every entrant, including
   the well-behaved ones.** Apply each patch **in isolation at the pinned commit**, never against the
   working tree (see B20). The judge must also write its model-perf ledger cells — B1.
2. **T843 / T844 — rate-race judgment.** Judged twice: the operator smoke-tests the rendered output
   himself and **his reading counts retroactively**, so judges paste every frame verbatim and **name
   the hinge** — which ranking would change if he dislikes a given frame. Do not re-grade for him.
3. **T819 — corpus three-way.** T817's brief *deliberately differs* (seeded from the old classifier)
   while T818 and T820 are byte-identical, so the comparison measures two different things.
4. **T836 → T837 — the epistemic arc.** The only queued work touching the product. T836 previously
   died on a provider-429 without reaching the model; it is a retry, not a fresh failure.
5. **T849's remainder** — the other 53 scratch-repo conversions, batch size set by what T849 reports
   about how long one conversion takes and which scripts resist.

**Model rules in force:** Fable reserved. **Do not put a real row on ox-alpha until it passes an
agentic probe** — it failed the full loop three times since ~09:00Z while answering simple probes
fine (B23). One task per family, one row per model. The fleet keeper stays paused: one dispatcher.

**Known small fix, not yet owned:** a lane reports tokens only when dispatched with `--session`
(deepseek and ollama have it; the openrouter/ox-alpha lane has neither `--session` nor `--mode json`,
which is the whole explanation for its UNKNOWN token column). One line in the dispatch path.

## B-new-4. Observability gaps measured while three workers ran, 2026-08-24

| # | issue | evidence |
|---|---|---|
| B25 | **`managent liveness` displays a falsehood, which is worse than a gap.** With `T848` running on `deepseek-v4-pro` and `T849` on `glm-5.2`, it reported both as `[beats stopped]` with `command: pi --provider openrouter --model stealth` — the command and model of *earlier abandoned attempts* on those same rows. A heartbeat from a dead attempt is never superseded, so the surface attributes it to the live run and names the wrong model. Both tasks were in fact healthy. Anyone acting on that display would reopen or re-dispatch a working row. | `bin/managent liveness` versus the process table and the session transcripts, same minute |
| B26 | **A `claude` lane is unobservable by design, not by accident.** It is dispatched as bare `claude -p …` with no `--session`, its stdout is buffered to completion, and no heartbeat lands — so `T850` showed `UNKNOWN — no assertion`, a 2.7 KB log frozen for ten minutes, and no transcript, while being perfectly alive (two live pids). The process table was the *only* truthful signal. | `T850` across four surfaces |
| B27 | **The reliable liveness signal is the session transcript, and only two of four lanes have one.** `deepseek` is dispatched with `--mode json --session <path>` and `ollama` with `--session <path>`; both produced growing transcripts (736 KB and 127 KB, mtimes seconds old) that correctly showed health. The `openrouter`/`ox-alpha` lane gets neither flag and the `claude` lane gets none. **So the missing `--session` is not a cosmetic token-column gap — it removes liveness and attribution together for half the fleet.** That reframes it from nice-to-have to the cheapest observability fix available. | the four lanes' argv, measured |

**Verified working, recorded so it is not re-litigated:** the fleet keeper's pause is real, not just a flag — its own log writes `cooldown flag set — no new dispatches` every 30 s. And all four race-judge briefs (`T832`, `T843`, `T844`, `T819`) are amended with the closed field, the clean-baseline requirement, and the design assumptions their originals did not state; they are ready to dispatch as slots free.

## B-new-5. The authorship column is a forensic log of the git leak — 2026-08-24

| # | finding | evidence |
|---|---|---|
| B28 | **This repository's git identity was hijacked by a test fixture, and 680 of 1,415 commits are misattributed.** Authorship across all history: **733** correct (`Alexander E Genaud <alex@genaud.net>`), **655** as `T278 <t278@test>` spanning 2026-08-18 → 2026-08-24, **21** as `T682 <t682@test>` today, plus `T799`, `T841` and `T286` fixture identities on the stray commits. Nothing in `tools/git-commit-mine`, `bin/subagent` or `tools/runner` sets a git identity — the *local config itself* was overwritten. `tools/regression-managent-landmark.sh:57` runs `git config user.email t682@test` and that script is in the **pre-commit fast pool**, so it executes on every commit. It does `cd` to its scratch dir first, so with `GIT_DIR` unset the write is correctly scoped — but before the isolation guard, `GIT_DIR` overrode the `cd` and the write landed here. **So the authorship column is a forensic record of every occasion the leak fired**, and it fired across at least seven days. This is independent corroboration of the operator's report that tasks vanish *often* rather than once. | `git log --format='%an <%ae>' --all` tallied; the script's own lines 53–58 |
| B29 | **RESOLVED for the future, cleaned for the present.** The polluted local `user.email`/`user.name` have been unset, so the identity falls back to the operator's global `alex@genaud.net` — verified via `git var GIT_AUTHOR_IDENT`. The isolation guard prevents recurrence through the hook path, and a direct run was always safe because of the `cd`. **History is left as it is**: rewriting 680 commits would destroy the very forensic record that proves the incident's frequency, and the misattribution is recorded here instead. The two `base` commits stay too — they contain real T839 and T846 deliverables and are the worked example. | this file; `git config --unset` |

**Why this matters beyond tidiness.** The project treats identity as a per-console channel via `MANAGENT_TASK_ID` (see `docs/infra/fleet-git-isolation.md`), *not* via git author — so nothing depended on the fixture identity, and nothing breaks by restoring the real one. But it means that for seven days `git log` could not answer "who made this commit", on a project whose entire method rests on attributing work to tasks and models.

| B30 | **T836 was recorded as never reaching the model; it had in fact delivered.** A standing note said its run was a `provider-429` with the model unreached. Its single run record shows `exit=1` after **1,342 s**, and `docs/epistemic/board-proof-status.md` is on disk at **537 lines / 87,864 bytes**, authored `claude-opus-5/T836`, with an mtime landing at that run's end and a closing paragraph pointing at the companion findings it never got to write. **It is the delivered-before-death case, twice over now** (see B17 for T840). Re-dispatching it as a fresh failure would have overwritten 22 minutes of opus work; it has instead been re-dispatched as an **audit** — verify the census citation by citation, write the missing findings, commit both, change no claim status. | the run record versus the artifact's size, authorship and mtime |
| B31 | **A second worker staged its deliverables into the shared index while a third was mid-commit.** T850 had `docs/infra/request-accounting.md`, its findings, its regression script and its module staged at the same moment my own edit was staged; its file carried a new `untracked/` citation, so `C10-NEW` refused **my** commit for **its** content. The wrapper's scope check prevents cross-sweeping, but nothing prevents one console's unstaged-but-scanned work from failing another's commit. Yielding the index (`git reset -- <my path>`) and warning the worker (directive D082) was the working resolution. | the staged set at that moment; the refusal naming a file I had not touched |
| B32 | **RESOLVED — the pre-commit test gate was refusing ~2 of every 3 commits, and the cause was not load.** `tools/smoke.sh` failed the fast tier with **exit 141 (SIGPIPE)**, passing standalone and under the runner when stdout was `/dev/null`, but failing **2 of 3 runs** when stdout was a pipe — which is exactly how the hook captures it (`$(...)`). Root cause: `set -euo pipefail` plus three `echo "$OUT" | grep -q "…"` checks and an unguarded `| head -1`. `grep -q` exits on first match, so the writer takes SIGPIPE and **pipefail turns a passing check into a failing one** — the check was not merely flaky, it inverted. Fixed by removing the pipes: the three checks are now pure-shell substring tests (`[ "${OUT#*needle}" != "$OUT" ]`) and the `head` is guarded. Shown red (2/3 failing) then green (**10/10 passing**), with a seeded-defect control proving the new idiom is not vacuous — present→true, absent→false, empty→false. **This was fleet-blocking:** three running workers could not have committed their deliverables, and a row cannot close without them. | the 2-of-3 reproduction, then 10-of-10 |
| B33 | **I misattributed this twice before diagnosing it, and both corrections matter.** First I called it load flakiness; then I called it a regression from T848's rebuild, reasoning that `managent --version` now printed the whole status listing. In fact **there is no `--version` handling in `main.zig` at all** — unknown flags fall through to `status`, and always have, so T848 changed nothing here. That silent-fallthrough is the same defect already recorded for `managent done` ignoring unknown flags, and it deserves its own row: **an unrecognised flag should be refused, not reinterpreted.** | `grep -n '--version' src/managent/main.zig` returns only the import |

## B-new-6. The per-model budget's premise, now measured — 2026-08-24

| # | finding | evidence |
|---|---|---|
| B34 | **The minimax starvation is not reproduced in a measured window, and the real concentration is elsewhere.** T850 built the accounting (report-only, as scoped) and its first reading over the trailing 5 hours shows the ollama family split roughly evenly — `minimax-m3` **295** requests (36.9% of family), `glm-5.2` **275** (34.4%), `kimi-k2.7` **230** (28.8%). The documented premise for a per-model budget was minimax taking 790 of ~792 while glm and kimi got one each. That window predates the reset, so this does not refute the incident — but it does mean **the budget must be driven by measured shares rather than by that anecdote.** The concentration this window actually shows is **`claude-sonnet-5` at 598 requests, 75.6% of its family and 25.7% of the entire fleet.** Any cap written to the anecdote would have policed the wrong model. | `python3 tools/request-accounting.py` |
| B35 | **The honesty rule survived implementation.** `ox-alpha` reports `requests=0` with **5 unattributable attempts** named individually, rather than folding unknowns into a zero or a total; the ollama `[GIN]` cross-check reports `gin_total=923 gin_429=12 known=800 discrepancy=123` and explicitly does not reconcile it. Fleet total is stated as *known* = 2325 with 13 unattributable attempts alongside. This is the shape the brief demanded and it is what makes the numbers usable. | the same report |

**Audit of T850 by the seat, since a close is an assertion:** all four deliverables committed; 8 arms pass; the report-only scope was respected — no commits to `bin/dispatch`, `tools/fleet_caps.py`, `tools/window_policy.py` or `tools/runner`. Its `pass` is justified.

**Audit of T848 by the seat:** its 4 arms pass, and independently on the live store the census `row_count` 481 matches the live row count exactly, all 481 ids are present, `written_by` shows it updating on each mutation, and `orient` is correctly silent on a healthy store. Its `pass` is justified.

## B-new-7. Seat audits of T836 and T849, and what they turned up — 2026-08-24

**T849 (scratch-repo fixture) — `pass-with-findings` justified, verified independently.** It converted
**exactly five** scripts, one commit each, and its census matched the seat's figure for figure (83
scripts, 58 with `git init`, 77 calls, 51/4/1/2 distribution, 65 vs 11 scratch-root split). Its four
arms pass. **The seat then reproduced the incident from first principles against throwaway repos:**
with a leaked `GIT_DIR`, the old hand-rolled pattern **overwrote the victim repository's
`user.email`**, while the helper under identical conditions left the victim's identity, `core.worktree`
and tree untouched. That is direct experimental confirmation of B28, which until now was inferred from
authorship tallies. One of the five converted scripts is `regression-orient` — the pool script that
runs on **every commit** and carries the `t353@test` identity, so the highest-frequency leak path is
now the first one closed.

**T836 (board proof census) — `pass-with-findings` justified.** It verified rather than rewrote, as
amended: the census is committed unchanged, the verifier explicitly disclaims authorship, and
`claims[]`/`new_rows[]` are empty consistent with the census's own "carries no authority" framing. It
checked citations individually at file:line and **reproduced claimlint's C3 exactly at HEAD (42 Tier B
/ 0 Tier C / 24 Tier A of 66 PROVEN rows)**.

| # | issue it surfaced | why it matters |
|---|---|---|
| B36 | **A census reading rests on a claim archived as BOGUS.** §5 C-1 presents "Track A 2×2/3×2 regen complete (B15, byte-identical)" citing `PROGRESS.md:238-240`, where that text does not appear; the quote lives in `CLAIMS.md:1008-1009`, and `GLOBAL.B15` was **archived BOGUS on 2026-08-04**. The census flags PROGRESS.md line refs as possibly drifted but presents this reading without marking it unverified. | a live document asserting something built on a retracted claim |
| B37 | **A retracted 4×4 value is still published as current.** The withdrawn `+2` empty-4×4 result is still stated as current in `docs/epistemic/GLOSSARY.md`, alongside `+9` — and the census records that `3×3` and `4×3` have **no live value** at all. | the product-facing numbers are the ones that must not be stale |
| B38 | **Five citation line-references have drifted** (`src/rules.zig:1024-1027`→667, `SOLUTION-TREE.md:63`→53, `:65`→60, `:113`→109, `GLOSSARY.md:424`→425), each with the command that shows it. Individually trivial; collectively they mean commit-pinned line refs are decaying faster than they are maintained. | the project's citation discipline depends on these resolving |

**Census headline worth carrying forward:** the PROVEN fraction falls monotonically with board size, and **4×4 has 1 of 11 cells PROVEN**, with its `KO_SENSITIVE` column (3,455,412 entries, 3.49%, including the root bracket) UNTRUSTWORTHY pending Track A.
