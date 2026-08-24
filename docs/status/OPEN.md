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
