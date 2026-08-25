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
| A1 | **Race W — RESOLVED 2026-08-24.** The operator delegated adjudication to the T871 seat ("this is not democracy — judge from the primary sources"). Ruling: Section A stands as committed (opus lane, 3-of-4 blind lean). Section B: the committed **hybrid stands** — clause-by-clause check confirmed it carries all three of ox-alpha's Amendment-2 clauses plus opus's defect catalogue and promotion/dispatch binding, and scopes the W0 gate better than either pure lane. Performance verdict (separate, per protocol v2.1 rule 10): opus best overall (Section A win + craft), ox-alpha strongest doctrinal completeness (all grafts trace to its lane), deepseek third (dropped the W0 hard gate). Protocol amendments from this case are §4b of the seed doc. | resolved |
| A2 | **Does D044's DeepSeek time-priced rate band survive the budget-meter retirement?** The band is a fact about *when* a run happened, computed at write time; the retirement says agents know nothing of costs and never mention peak hours. | flagged, not decided |
| A3 | **Filling the 12 now-recoverable `cost: null` lanes in the sha256-sealed `tools/complementarity-inputs/*.json`** would change a dispatch-decision input using `trusted:false` readings. Deliberately not done. | ratification question |
| A4 | **Is the pi/openrouter API-key pattern more secure, and should claude / deepseek / ollama converge on it?** He raised it; it is a security review, not a measurement question. | unowned |

## B. Known issues with no owner yet

| # | issue | evidence |
|---|---|---|
| B1 | **Nothing writes the model-perf ledger automatically.** 24 rows across 72 possible cells; 59 empty; 9 of the 13 filled are `audit`. ox-alpha has **0 of 8** despite 7 completed tasks. Making each race's judge write its cells (T832) is a per-race instruction, not a mechanism. | `docs/infra/model-task-metrics.jsonl` |
| B2 | **The appetite table is compiled into `src/managent/main.zig`** with no file or env override, so a roster change needs a source edit, a rebuild, and a slot in a serialized chain. S06 pass 1 (the policy file) is the fix. | T834's own findings |
| B3 | **A consolidation pass editing a live file breaks the fleet while it works.** T821's arbiter edit left `name 'host_guard_on' is not defined` in `tools/runner`; 13 dispatches died in 0.1 s inside a 7-second window. `tools/runner` is re-read on every dispatch, so passes must land atomically or work on a copy. | the 13 `runner exception` records of 2026-08-23T22:19, cited in T821's findings |
| B4 | **ox-alpha lanes die; it is not a protocol problem.** SUPERSEDES the nonce reading. Measured 2026-08-25: T926 **exit 0 in 37.4 s, never claimed the row, no output, no work** (rss 158 MB); T924 ran 4,110 s, did excellent science, then exited 0 having written **neither** declared deliverable; T709 was refused on RAM before launch. **CAUSE FOUND, same day, from the operator's console: HTTP 429, `limit_source:
upstream_provider_shared_pool`, "stealth/ox-alpha is temporarily rate-limited upstream".** The
lane log holds **40 occurrences of 429** — twenty retries, all refused — and `tools/runner` then
recorded **exit 0**. The lanes were never non-compliant; they were never served. Our own dispatch
rate was 18 claims in nine hours, so the pressure is other users of the shared pool, not us.
**B4 as previously written was a wrong diagnosis that stood for weeks**, and the seat acted on it
by putting waypoint 1 on ox-alpha (T924: 4,110 s, complete ladder, neither deliverable written).
The instrument defect is registered as **T934** — a provider refusing service must not exit 0. **Decision (T914 seat): ox-alpha is off the dispatch list** until lane telemetry can distinguish provider death from model behaviour. Work quality is the best in the field (37/40, race C3) — this is a lane-reliability finding, not a capability one. | `docs/evidence/T926/` (run record + lane log, preserved), `findings/T924-4x4-d3-tractability.json` |
| B4-old | **ox-alpha does not reliably echo the dispatch nonce** — three instances (T770, T776 via raw pi; T818 through `bin/dispatch`, so the door is not the explanation). Work quality high, protocol compliance unreliable. | T818 findings |
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
## SHIFT LOG — 2026-08-25, T914 seat (supersedes the NEXT UP tables below)

Everything under `NEXT UP` was generated 2026-08-24T18:40Z and its two tables have since gone
stale — every row in "in flight now" has closed. Left in place rather than hand-rewritten,
because **T894** is the registered durable fix (dispatch-readiness ordering with an estimate
column, in `managent status` and `orient`, not in this file). Read this block first.

### Settled

- **Waypoint 1 is answered** (T912, `92909d3`): where writes-off and the committed 3×2 table
  disagreed on the 62 ko-sensitive pairs, **writes-off is right on 62 of 62**. Stronger than the
  question asked — the artifact at HEAD already agrees with a fresh writes-off rebuild on all
  **978** (slot, side) values; the 62 were repaired by the regeneration at `ae39978`, so the
  disagreement is historical, not live. **Open, for the operator:** the row was told to
  adjudicate with the history-exact solver. That solver resolved **0 of 62** — and 0 of its own
  24-pair null control — after 1.72 × 10⁹ nodes and 330 s. The row substituted the ADR-0013
  minimax identity under a fixed root history (62 of 62 in 7 ms), documented it, and ran the
  control. Waypoint 1 was therefore answered by an instrument the roadmap did not name, and
  waypoint 1 gates 4×4 compute on Track A.
- **The repository-wide commit freeze is lifted** (T914, `b3a841c`). The S09 module contract
  declared `test tools/regression-runner-guard.sh covers tools/runner`; T872 deleted that script
  at `12e7055` and dropped its known-red line but left the coverage declaration. Every commit
  staging `tools/runner` therefore selected a file that does not exist and was refused. Verified
  after the fix: every `test … covers …` path the contract declares exists on disk.
- **The dashboard's cost was mis-attributed and is now measured** (T910). Bounded run-record
  scan, reap/resume 0.79 s → 0.36 s — but profiling showed the ~9.14 s frame is **~2,294
  fork/exec per frame in `watch-fleet.sh`**, not run-record parsing. The row corrected two brief
  imprecisions rather than executing them.

### New rows registered this shift

| row | what | why now |
|---|---|---|
| **T915** | real `tools/runner` coverage, red-first with both controls | T914 removed a broken gate; that is not the same as having one. B3: one bad `tools/runner` edit killed 13 dispatches in 0.1 s. |
| **T921** | Debug + ReleaseSafe suite resource profile, drained host | Operator ruling: big runs and resource requirements outrank model-perf data. Debug has **never** been profiled — ~12.5 GB and a kernel panic in July, routed around ever since. |
| **T922** | `build.zig` is an undeclared shared writer | T908 and T910 were editing it concurrently; neither declared it. T910 caught the collision itself and added the hold — a model noticed, the mechanism did not. |
| **T916–T920** | Race J: five sealed lanes on T915's runner guard | Registered and **parked** behind the big runs, per the operator's ordering. |

### Race J, designed and parked

Five byte-identical sealed briefs (verified before any entrant ran, the T863 Step-0 discipline):
ox-alpha, dsflash, dspro, kimi, sonnet. Measures **control design on infra** — the dimension that
predicted the C3 winner, never measured outside audit — and fills `fabricated_interfaces`
mechanically, which currently reads UNKNOWN (not zero) for six of nine models. Two canaries with
knowable answers sit in the required-assertions list: the memory-pressure host guard T821 deleted,
and band boundaries that live in `bin/subagent`, not `tools/runner`. The multi-model claim under
test is **union coverage** — distinct runner behaviours across all arms versus the best single arm,
the 41-versus-21 audit statistic asked of infra. A null result there is worth having: it would mean
we stop paying for breadth on infra work.

### The measurement gap this shift quantified

502 closed rows against 52 metric rows. Audit is 32% of the work and 69% of the measurement.
**Four types — orchestration (45 rows), battery (35), spec (18), integration (14) — have never
been measured at all**, 113 completed rows between them. `cost` is null in 52 of 52, which is why
no tier has ever been emitted. Every Tier-2 judged dimension is n=1: one race, one grader, one
task type.

---
## NEXT UP — STALE, generated 2026-08-24T18:40Z (see SHIFT LOG above)

**`est` is a dispatch-time estimate: how long the lane is expected to run.** It is the same
column the DONE list uses for elapsed time; here it means *expected*, there it means *actual*.
Estimates are the seat's, often wrong, and deliberately shown anyway — a wrong estimate that
gets corrected is worth more than no estimate. `why` is what has to happen before it goes.

### In flight now (3)

| row | model | est | elapsed | what it is |
|---|---|---|---|---|
| T872 | dspro | 3h | ~30m | green-up delete wave — 3 of 11 committed, post-sweep running |
| T880 | dsflash | 90m | ~60m | holds parse + report bug — red tests written, fix landed, verifying |
| T890 | glm | 2h | ~15m | one serving-tag path (the kimi dead-tag bug) |

### Next out the door (ordered)

| # | row | est | why it is not out yet |
|---|---|---|---|
| 1 | **T891** lane telemetry parity | 2h | holds `bin/subagent` — waits on T890 |
| 2 | **T877** run-record identity (the reap blinding) | 3h | holds `src/managent/main.zig` — waits on T880 |
| 3 | **T892** directives reach the worker | 2h | holds `src/managent/main.zig` — waits on T880 |
| 4 | **T873** green-up fix-test wave (21 entries) | 4h | shared change-log + suite — waits on T872 |
| 5 | **T893** race-C3 adjudication (consensus + Fable) | 2h | waits on the nine lanes being scored — ready now |
| 6 | **T874** green-up fix-code wave (10 entries) | 4h | waits on T873 |
| 7 | **T875** C3 evidence triage (superseded) | — | **the race answered this**; row to be retired or rescoped |

### Standing / duties (never close, run when triggered)

`DARGUS`, `DCLAIM`, `DRPLAY`, `STANDING-ABSORB`, `STANDING-CLEANUP` — these are duties, not
queue entries, and should never sit at the head of the dispatchable list.

### Cold storage — registered, real, not scheduled

`T529` `T535` `T709` `T712` `T713` `T715` `T735` `T750` `T751` `T753` `T764` `T767` `T768`
`T770` `T772` `T775` `T782` `T786` `T787` `T796` `T798` `T825` `T830` `T833` `T837` `T863`
plus the blocked `T784` `T815` `T816`. None of these is next; they are listed so the trail
survives, not to be read as a plan.

**Retired 2026-08-24:** the malformed `--bundle` row — a bundle flag captured as a task id,
never dispatchable, and it had been sitting at the head of the queue for weeks. That is the
`L9`-at-the-top complaint's literal cause: the list was sorted by id, so junk and duties led it.
The durable fix (ordering by dispatch-readiness with an estimate column, in `managent status`
and `orient` rather than in this file) is registered as **T894**.

---
## Queue state, generated 2026-08-24T06:44Z (STALE — superseded by NEXT UP above)

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

## B-new-8. The diff race is judged — T832, audited by the seat, 2026-08-24

**Ruling: `T827` (deepseek-v4-flash) wins; `T828` (claude-sonnet-5) second.** Then `T831` (ox-alpha),
`T826` (deepseek-v4-pro), `T829` (claude-haiku-4-5-20251001) failed, `T830` (qwen) never ran.

**Why the mechanical headline was wrong, which is the valuable part.** `T826` and `T831` score a
perfect 172/172 by turning the two recorded-defect arms green — but those arms test the
*empty-deliverables* defect, **not** the T818 nonce-vs-no-work wound the race exists to fix. Under the
actual incident shape (an open row, rc=0, deliverables present, nonce not echoed) both still return
the exact `fail=row` the race was called to abolish. In xfail semantics their fix reads as
"unexpected success = FAILED", so the raw suite output flatters them and the design harness exposes
them. The judge caught this and ranked on the concrete T818 case instead, which is what the handover
named as the decisive test.

**Verified independently by the seat:**
- **The disqualification rule holds.** Every patch touches only `tools/dispatch_verify.py`; the test
  file is byte-identical to base under all five, so nothing was disqualified and nothing was graded
  against arms fitted to it.
- **`T829` really is unusable.** Its patch diffs against an absolute scratch-copy path under the system temp directory rather than against `a/tools/dispatch_verify.py`, so it has no valid path
  prefixes and will not apply — haiku patched a temp copy. The `fail` is correct.
- **All six ledger rows landed** in `docs/infra/model-task-metrics.jsonl`, including `T830` recorded as
  **`no-show`** rather than omitted. This is the first race to write its own cells, which is a partial
  answer to B1 — still per-race instruction, not yet a mechanism.

| # | follow-up this ruling creates | why |
|---|---|---|
| B39 | **Land `T827`'s patch and pin the T818 open-row case as a test arm.** The judge's own "where I would not bet" names it: with that arm pinned, `T826` and `T831` would turn a green arm red — the outcome the brief ranks worst. Until it exists, the suite cannot tell a real fix from a flattering one. | the race produced a winner; the value is only realised when it lands |
| B40 | **The full suite carries 3 failures and 7 errors at base**, identical across base and every patch — pre-existing cwd/path artifacts in the `token_capture`, `dispatch` and `s06` modules, unrelated to any patch. Noted so they are not mistaken for race damage, and because a suite with 10 known-bad results at base is a weak oracle. | measured from every worktree |

## B-new-9. The corpus three-way is judged — T819, audited by the seat, 2026-08-24

**Reported as two experiments, per the amendment.** Judge `kimi-k2.7`/T819.

**Experiment 1 — does seeding from the legacy classifier help?** T817's brief-aware classifier scores
**27/27 = 100%** against a hand-built ground truth; the legacy keyword classifier scores **19/27 =
70.4%**. So the brief-aware claim **reproduces**, but **the published 78% figure does not** — the
measured legacy accuracy is 70.4%. Caveat the seat adds: the ground truth is **n=27**, which is a thin
basis for a 100% claim, and the eight legacy misses are concentrated in `spec`→`audit` confusion.

**Experiment 2 — the clean two-model comparison, and the consequential result.** T818 (`ox-alpha`) and
T820 (`deepseek-v4-pro`) worked from **byte-identical briefs** over the same 578 tasks. Their
`task_type` labels agree on **206 of 578 — 35.6%**. Scope taxonomies are outright incompatible and
capability vocabularies are model-specific. The seat recomputed independently on the subset it could
extract and got **16/49 = 32.7%** — same magnitude, so the figure is credible. (Two earlier
recomputations by the seat returned 0% and were its own extraction errors: `task_type` is a nested
object, and the two corpora use different id keys.)

| # | consequence | why it matters |
|---|---|---|
| B41 | **Task-type labels are model-dependent, not objective.** Two capable models given identical instructions over the same 578 tasks agree about a third of the time. **Every "model X suits task type Y" conclusion therefore rests on labels that two models cannot reproduce** — including the task-type frequencies used to argue allocation. This does not say the labels are useless; it says the label is a *judgement*, and any allocation claim built on one needs its inter-rater agreement stated alongside it. | 206/578, plus incompatible scope taxonomies |
| B42 | **The published legacy-classifier accuracy is wrong.** 78% is the standing figure; measured accuracy on the ground truth is **70.4%**. Whatever rests on the 78% number needs restating. | 19/27 |
| B43 | **A brief amendment cannot add a deliverable.** The seat's amendment asked T819 to write model-perf ledger cells; the bundle header did not declare `docs/infra/model-task-metrics.jsonl`, so the close gate could not check it and **no ledger rows were written**. Same class as B24 (`suggest` drops `holds=`): the header is the only thing the mechanism reads, and prose asking for more is unenforceable. | 35 ledger rows, none for the corpus lanes |

## B-new-10. The rate race is judged, and the diff race is landed — 2026-08-24

### Rate race (T843, judge `claude-sonnet-5`) — `T839` (deepseek-v4-flash) wins

`T838` (deepseek-v4-pro) is a near-tie: both fix the UNKNOWN-forever rate defect correctly and break
nothing. `T839` additionally gives CONCERNS a third state so that a live worker `pgrep` cannot see does
not read as dead — the race's own motivating incident. **Hinge, named as the protocol requires:** if the
operator judges that third state to be unnecessary complexity (T840 argued explicitly against it), the
ranking narrows to a near-tie with `T838`. No disqualifications — all three patches applied cleanly at
the pinned base and touched only the two permitted files. Five ledger rows written, each marked
provisional at n=1 with no tier emitted per the methodology's emission gate.

| # | finding | evidence |
|---|---|---|
| B44 | **The live rates the operator saw were wrong by ~6.5×, and looked plausible.** T840 — the patch that had been sitting applied in the working tree — reads per-message `usage.output` and takes the **MAX**, treating it as a cumulative counter. It is not. The seat verified on a live transcript: successive `output` values run 186, 140, 158, 158, 182, 638, 3693, 2517 — **non-monotonic**, so per-turn — while `usage.totalTokens` climbs monotonically. On that transcript **MAX = 8,164 against SUM = 52,851: the MAX approach reports 15.4% of the true output.** T838 and T839 both sum. This is precisely the "renders a plausible number without reading the transcript correctly is worse than UNKNOWN" hazard the brief warned about, and it is why clearing the contamination was right even though it cost a working-looking column. | the judge's D1, reproduced independently by the seat |
| B45 | **T840 also silently drops transcript-less orphaned tasks from CONCERNS** — a stray shell `continue`, reproduced 3 of 3 runs, breaking a previously-green holder arm. A dashboard that hides orphans is worse than one that shows UNKNOWN. | the judge's D2 |

**Landing `T839` deliberately waits** on `T844`, the protocol's second independent reading, now running
on `claude-haiku-4-5-20251001` with an explicit instruction not to read the first ruling before forming
its own. A split escalates to the operator's panel. Note that the entire ollama family entered this
race, so neither glm, kimi nor minimax could judge it.

### Diff race landed (T852, `glm-5.2`) — `pass`, and the suite can now tell a real fix from a flattering one

`T827`'s patch was applied **verbatim** — byte-identical, no reimplementation, no rebase needed. The
T818 open-row case is now a pinned arm, shown **red at HEAD before** the change (`work-present +
nonce-missing on an open row must NOT be fail=row`) and green after. It ships with a **control** the
seat did not ask for: work-*absent* + nonce-missing must **still** be `fail=row`, so a fix cannot
over-broaden into recovering work that was never done.

**The flatterer check confirmed the judge's prediction.** In an isolated worktree at the pinned base,
`T826`'s patch makes the new arm **RED** while still showing its two "unexpected successes" — the
flattering 172/172 headline. Seat verified independently at HEAD: **174 tests, OK, expected failures=2**,
so the two recorded defects remain honestly red rather than papered over.

| # | still open | why |
|---|---|---|
| B46 | **`T837` (C3's 42 unbacked proofs) is deliberately NOT dispatched.** Its dependencies (T835, T836) are now met, but it is the one queued row that could change the project's epistemic record, and T836 just found a live document resting on a claim archived BOGUS. Downgrading or backing 42 PROVEN claims is a bookend question, not a seat decision. | held for the operator |

## B-new-11. Second rate reading, and a flaw in the seat's own method — 2026-08-24

`T844` (`claude-haiku-4-5-20251001`) independently ranks **`T839` first, `T838` runner-up, `T840`
disqualified on arithmetic** — the same order as `T843`. Both readings agree, so no split escalates to
the operator, and `T853` now lands `T839`.

| # | finding | why it matters |
|---|---|---|
| B47 | **The second reading was not independent, and the seat caused that.** The protocol wants two blind reads precisely so a wrong first read is caught. The seat's directive D083 handed the second judge the measured aggregation data *and named it "the critical hinge"*; the judge's findings carry a `critical_directive_d083` section restating it as the ranking criterion. **So this is corroboration, not an independent ranking.** The partial defence: the aggregation defect is a fact the seat verified itself against a live transcript, not the first judge's opinion — MAX=8,164 vs SUM=52,851 is arithmetic, and either judge would have had to contend with it. But the ranking hinge was supplied rather than found, and a future two-judge race must pass the second judge the *field* and nothing else. | D083 versus the protocol's intent |
| B48 | **The second judge hedged well, and its hedge is worth keeping.** It recorded what would have to be true for its ranking to be wrong: if the operator's own live testing shows T840's rates are correct at magnitude, then either `output` is cumulative-with-overwrite after all, or the seat's sample was unrepresentative, or T840's code is not what runs. That is the right shape for a verdict awaiting a human reading, and it is the reason his smoke test still counts retroactively. | `notes_on_operator_reading` |

**Landing brief (`T853`) carries the operator's own test as its acceptance criterion:** render a live
frame showing a real rate, show UNKNOWN still appears for a genuinely transcript-less lane (the
openrouter lane has neither `--session` nor `--mode json`, so UNKNOWN is *correct* there), and
cross-check the rendered rate against hand arithmetic on the same transcript. Seeing a number is not
the test; seeing the right number is.

## B-new-12. The rate winner is landed and verified in the operator's own terms — 2026-08-24

`T853` (`claude-sonnet-5`) applied `T839`'s patch **verbatim** — 402 `+` lines in the working-tree diff
matching 402 in the patch, no rebase, no reimplementation. Regression arm **O went FAIL → PASS**: that
is the UNKNOWN-forever defect closing.

**`T853` could not run the live demonstration and refused to fake one.** At the time no pi-lane task was
alive (only its own claude lane), `pgrep` could not see its own process tree from inside the sandbox, and
Claude Code's native transcript format does not match the envelope the reader expects. Rather than
render a plausible frame it exercised T839's real code against a real completed transcript and said so.
**That refusal is the correct call** — fabricating the frame would have been the T840 failure in a new
costume — but it left the acceptance test unmet, so the seat ran it.

**Seat verification, sampled with a live task running (`T854`, deepseek lane):**

| what | value |
|---|---|
| rendered frame | `T854  L1  dspro  2'02  53.0/s  35s` |
| hand arithmetic | SUM(per-turn `output`) = **6,465**, elapsed **122 s** |
| SUM ÷ elapsed | **53.0/s** — exactly the rendered figure |
| MAX ÷ elapsed (the T840 method) | 23.2/s — *not* what is rendered |

So the column shows a **right** number, not merely a non-empty one, and it demonstrably aggregates by
sum. The freshness slot also renders (`35s`).

| # | still open after this landing | detail |
|---|---|---|
| B49 | **`claude` lanes will still read UNKNOWN, and that is now a known format gap, not a mystery.** Claude Code writes its own per-session transcript with `usage` nested as `message.usage.output_tokens`, which is not the envelope the reader parses. Combined with B27 (the claude lane is dispatched with no `--session` at all), claude lanes remain unmeasured and unobservable. The fix covers the `deepseek` and `ollama` lanes. | T853's findings |
| B50 | **Three watch-fleet arms are red at base and unchanged by the landing — including the exact-fill invariant.** Arms C, F and N fail identically before and after. Arm **N** is the exact-fill check, and it renders **1 line instead of the expected 22/38/58** — "a drastic pre-existing failure, not an off-by-one". **The invariant every rate-race brief treated as load-bearing has an arm that has not been passing**, so no entrant's claim to preserve it was ever actually tested. | base-vs-patched runs, same host |
| B51 | **The deployed managent binary has drifted from what several regression scripts assert** (e.g. `lanes` "not clean on a null store", duty "next did not claim"), which forced T851 to revert otherwise-valid conversions to keep its batch all-green. The drift is a task in itself; T854 is asked to enumerate every script it blocks. | T851's findings |

## B-new-13. My audit of T848 was incomplete — the detector breaks fixtures — 2026-08-24

| # | finding | detail |
|---|---|---|
| B52 | **T848's store-loss detector is correct on the live store and fires falsely inside test fixtures.** T854 enumerated five regression scripts now RED from binary drift, and **three cite this detector refusing writes**: `regression-managent-duty.sh`, `regression-managent-done-two-phase.sh`, `regression-managent-ledger-board-seam.sh`. Two more are separate drift in the same binary: `regression-managent-lanes.sh` (null-store assertion) and `regression-managent-store-pollution.sh` (its fixture predates `done`'s impression-or-waiver gate). **This is precisely the failure the S10 spec named** — *"the detector's own false positives would teach the bypass that ends it"* — so it is being fixed before anything else, as `T855`. | T854's drift report |
| B53 | **The seat's audit of T848 was incomplete, and the gap is instructive.** I verified its own four arms, recomputed the census against the live store, and confirmed `orient` stays silent on a healthy store — all true, all still true. **What I did not do was check whether it broke other scripts**, which is the one rule this project states most often: breaking a previously-green arm outranks everything else. An audit that only runs the subject's own tests cannot see a regression it caused elsewhere. **A close audit must include a broader arm sweep, not just the row's own controls.** T848's verdict is not withdrawn — the detector does what it claims on the live store — but it is qualified, and the qualification was found by the next worker rather than by me. | this file |

**`T855` is scoped to fix it without weakening it**, and its acceptance has two halves deliberately: the
five scripts green, **and** the seeded-defect arm still red-capable on a hand-reverted scratch store. A
change that makes the arm pass because the detector no longer fires is called out in the brief as worse
than leaving the scripts red. No blanket bypass flag, no scratch-path heuristic — a store with **no**
census is an unmeasured store, and the honest handling of an unmeasured quantity here is UNKNOWN, not an
alarm.

**Scratch-repo consolidation status:** 26 scripts converted across three batches (T849's 5, T851's 10,
T854's 10, plus the helper's own arm file), including all three pre-commit pool members and
`regression-managent-landmark` — the script that caused the repointing incident and hijacked this
repository's identity. T854 reports only **seven** cleanly-green mechanical candidates remained before it
started, so the mechanical phase is nearly exhausted; what is left is the named resisters, the multi-init
scripts, and the drift-blocked five — none of which proceed without the seat's sign-off or `T855`.

## B-new-14. The fixture drift is fixed without weakening the gate — T855, audited 2026-08-24

**`src/managent/main.zig` was not touched.** The detector's logic is therefore *provably* unchanged —
the strongest possible answer to the risk this row carried, which was that it might pass by disabling
the protection. It fixed the fixtures, not the gate, exactly as scoped.

| check | result |
|---|---|
| the five previously-red scripts | **all five exit 0** (duty, done-two-phase, ledger-board-seam, lanes, store-pollution) |
| the detector still has teeth | **yes** — seeded revert still gives `orient alarmed (rc=1) naming T9002 + census path` and `add refused (rc=1); store still 1 row` |
| all four census arms | pass |
| detector logic changed? | **no** — zero lines of `main.zig` in the commit |

**The one live-file change is legitimate and was the real risk.** `tools/runner`'s automatic close ran
`managent done <task>` with neither `--impression` nor `--impression-waiver`, which the impression gate
now refuses. Rather than fabricate an impression for a lane where no model narrated one, it now **waives
by name**: *"worker-channel auto-done on exit 0 — no model ran to narrate an impression"*. That is the
honest option, and it is the gate working as designed rather than being worked around.

**Applying B53's lesson, with one honest gap.** The risk here was a live file every dispatch reads, so I
verified it the way that counts: dispatched a real task and confirmed it claimed, stayed alive, and grew
its transcript to 175 KB. **My attempt at a broad script sweep exceeded its time limit and did not
complete**, so "nothing else broke" is supported by a real dispatch and the five named scripts, not by an
exhaustive pass. Stated rather than implied.

## B-new-15. Provider refusals are invisible to our records — 2026-08-24

| # | finding | evidence |
|---|---|---|
| B54 | **An upstream rate-limit is recorded as a successful empty run.** The operator sees explicit `429 … "stealth/ox-alpha is temporarily rate-limited upstream"` in his own console, while our harness records those same runs as **exit 0 with no output** — three such runs today, at 13.1 s, 8.8 s and one longer. **No 429 appears anywhere in our logs.** The `provider-429` classification exists only as a `dispatch_verify` verification outcome (`verified=unreached reason=provider-429`) and evidently cannot see the refusal on pi lanes. So the honest reading — *the provider refused, the model was never reached* — is rendered as a clean success. | his console versus our run records |
| B55 | **Every model-quality inference the seat drew from those empty runs is withdrawn.** The seat told the operator three times that ox-alpha showed "unreliable protocol compliance"; that was already retracted once when the nonce check was shown to read its own prompt back, and it is now retracted a second time on a different ground: the empty runs are consistent with upstream refusal, and there is no evidence for a model explanation. **Two independent instrument defects produced the same false accusation against one model.** | this file |
| B56 | **A near-miss worth recording as method.** The seat's first check for 429s in a run log reported two hits and was about to report "ox-alpha hit rate limits and recovered". The matches were the digits inside a process id (`84291`). Caught before reporting. This is the same class as an earlier incident where a log grep matched documentation strings inside task output. **A substring match is not evidence; the match must be shown in context before it is believed.** | the grep and the pid |

**Model selection rule adopted, operator 2026-08-24:** for the most important findings and audits, use
**one model per family** — one Claude, one DeepSeek, one Ollama, plus ox-alpha when it is responsive —
rather than several from one family. Family diversity is what distinguishes a property of the problem
from a habit of one provider. Currently: the ideal consolidation is on DeepSeek, the what-is audit on
Ollama, and Claude is unreliable this hour (one row produced nothing in 488 s with no 429 recorded), so
the Claude arm waits rather than being forced.

## B-new-16. `reap` declared three live workers orphans — found by the T871 seat, 2026-08-24

| # | finding | evidence |
|---|---|---|
| B57 | **The bare run record is not single-writer, and `reap` trusts it.** With T861, T867 and T869 all alive in the process table (runners with `--arbiter-id`, walls 15–35 min into a 45-min budget), `bin/managent reap` reported all three `[ORPHAN] no live process` and offered `reap --close` to mark them abandoned. Cause: each worker's own test invocations run through `tools/runner` under the task's id, and every such run **overwrites the task's bare run record** (the per-task JSON in the volatile runs directory) — T861's bare record was on `attempt: 205`, command `sh tools/regression-window-resilience.sh`, wall 2.8 s, a dead pid. Reap read the clobbered record's pid, found it dead, and declared the row orphaned. T870 alone read `[BACKED]`, because its worker classifies without running tests, so its record was never clobbered. **The method note of B-new-2 ("the bare record is authoritative") is hereby qualified: the bare record is authoritative only for rows whose worker runs no tests — which green-up workers all do.** | the reap output versus `ps` in the same minute; T861's bare run record at attempt 205 |
| B58 | **Near-miss, recorded as method.** Following the standing on-wake instruction ("run `bin/managent reap`", then close orphans) would have destroyed three healthy rows mid-work — the same shape as B25 (`liveness` attributing a dead attempt's heartbeat to a live run), now in the instrument the handover names as the *first* thing to trust. Until the run record is single-writer, an orphan verdict requires a process-table check for a live `--arbiter-id <task>` runner before any close. | this session |

## B-new-17. Found by the T876 orchestration seat, 2026-08-24 evening

| # | finding | evidence / disposition |
|---|---|---|
| B59 | **The file-conflict guard has been reporting success while holding nothing.** `managent add` reads `holds=` from a bundle header, and a **space-separated** list is silently truncated to its first entry (comma works). Probed on a scratch store with a null control: the comma form stored three paths, the space form stored one, and **no warning was printed either way**. Worse, the confirmation line printed `[set: A, holds tools/runner]` in *both* cases — the surface that tells the operator what was recorded cannot distinguish one hold from three-showing-one, which is why the parse defect survived. Live cost: **`T872` declared four holds and its store row carries zero** (space-separated *and* minted by `suggest`, which drops holds entirely — B24), so the delete wave ran with none of its four files guarded. | **dispatched as `T878`**, queued behind `T877`; the probe above is handed to it as its seeded-defect control |
| B60 | **`reap` picks the newest run record for a task id, not the dispatch record.** This is the mechanism under B57/B58, now located: `latestRunRecordFor` selects by `start` timestamp with no notion of what kind of run wrote the record, so a worker's own nested `tools/runner` test invocation — newer, short-lived, exited — becomes the record reap judges the row by. What T650 fixed was *retention* (attempts are archived, never lost); **identity** was never fixed, and a human process-table check is currently standing in for the missing mechanism. | **dispatched as `T877`**, which also carries the ratified data-contamination amendment (`tools/facts` must state provenance and read UNKNOWN where its source is overwritable) |
| B61 | **A full serial sweep of the 89 regression scripts costs ~20 minutes** (77 of 89 in 18 min, measured under a 300 s per-script watchdog, one at a time). This is now a load-bearing number for brief authoring: **any brief demanding a before-and-after sweep needs a wall of at least two hours**, not the standard 2700 s. `T872` was dispatched with 2700 s against an acceptance condition requiring two sweeps plus eleven deletions with a gated commit each, and could not have passed at any level of worker skill. | the seat's own timing of the in-flight sweep |
| B62 | **A directory literally named `WORK=` was created in the repository root**, holding a mirrored `WORK=/private/tmp/weizigo/t862-smoke-…/` scratch task store (tasks.json, its lockfile, store-census.json), timestamped this evening. A shell assignment reached a `mkdir` as a literal path. Nothing entered git and repository integrity checks pass, but this is the **T445 live-repo-escape class** landing inside the working tree again, and `tools/lib/scratch-repo.sh` — the one place a scratch repo is supposed to be created — is not what produced it. | the directory and its timestamps; culprit call site not yet identified |
| B63 | **`.test-patches/` is 144 MB of race-entrant repository clones with three nested `.git` directories inside the live repo root, and it is untracked but NOT gitignored.** `git check-ignore` returns nothing for it or for `WORK=`. A single `git add -A` — the command the whole `tools/git-commit-mine` discipline exists to prevent — would stage both. Deliberately **not deleted**: the rate-race judgments (`T843`/`T844`) are blocked rows that may still need those trees. The gitignore entry is the fix, and it collides with the documented integrity constant "`.gitignore` is 46 lines", which every wake check asserts. | `du -sh`, `find -name .git`, `git check-ignore -v` |

**On B63's collision.** The 46-line constant is a canary against the repoint incident, which rewrote
`.gitignore` down to 4 lines. It is also exactly the hand-picked constant class of C5: a legitimate
addition must update the asserted value everywhere in the same commit, or the canary reads as a breach.
That is a two-line change and a real decision about which document owns the number — recorded here
rather than done silently mid-shift.
