# Fleet & model-measurement audit — 2026-08-20

**Author:** claude-fable-5 (holistic seat, read-only bar held — no store writes, no kills, no commits)
**Date:** 2026-08-20, morning
**Scope:** progress toward `L1 (the dashboard tells the truth)`; the fleet automation toolchain
(dispatcher, keeper, watcher, runner, managent); model-performance collection; race protocol as
practiced. Method: live process table, live logs (`docs/infra/dispatch-heals.jsonl`,
`untracked/log/fleet-keeper.log`), fresh runs of `tools/orcha-acceptance.sh` and
`bin/weizigo-claimlint`, and the governing docs, each claim carrying its file:line.
**Companions:** `docs/status/ROADMAP-2026-08-20.md` (the plan) ·
`docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/grand-race.md` (the model-test protocol).

---

## 1. Where the project stands (landmarks)

- **L0 (the table and the instruments exist)** — banked. The 1-ko smoke red was cleared (T499,
  commit `b2eec10`: the asserted 0 was wrong; true value −4, hand-derived).
- **L1 (the dashboard tells the truth)** — *substantially met, not declarable.* The acceptance
  suite (fresh run, 2026-08-20) reads: AC5 **FAIL** (a duty blocks landmark declaration — no
  duty has ever recorded a chunk), AC6 7 unexplained `verified=fail` dispatches, AC7 20
  wall-kills, all other checks PASS. Claimlint: 228 rows parsed, C7 unabsorbed **0**,
  calibration PASS (C2=11 dead links, C3=48 unbacked, C10=998 volatile — known debts).
- **L2 (proven 4×4 values)** — **the remainder enumerated by the 2026-08-19 audit has now been
  executed**: T472 Track A ruled, T473 I11 exhaustive (0/48,636,330 slice + 0/99,133,036 table,
  commit `1680a04`), T474 second auditor PASS WITH FINDINGS (commit `d23cdfb`), T475 denominators
  absorbed. What is left is *clerical*: propagate T474's N1–N3 (placement-only I5 graph language;
  T472 ruling into CLAIMS.md 4×4.C1 / PROGRESS.md:440; the 7/7-vs-6/10 mutant table) and put a
  discharge ruling in front of the operator. L2, the critical path, is one absorption pass and
  one ruling from closed.
- **L4 (the ledger is clean)** — C3 at 48; `DCLAIM` is the only mechanism that moves it and has
  never run a chunk.
- Kanban: 187 rows — 172 done, 7 dispatchable, 4 in_progress (T505, T364, T491, T486), 3 blocked
  (T487, T489, T497). The absorption machinery (T481 §13) is mostly landed: c7 --json (T482),
  pre-commit floor (T483/T484), the done-gate (T485, seeded+null arms, no bypass), dispatch-verify
  findings parsing (T488). Open: partition trigger (T486), archive parser (T487), prose sweep
  (T489), audit enforcement (T491).

**Verdict on "approaching L1":** correct. The observation layer works — the gauges that read
wrong today mostly *say so themselves*. What blocks declaration is a short, enumerable list
(§5 and the roadmap), plus the duty mechanism actually running.

## 2. The fleet automation — findings

The machinery basically works: the dispatcher heals what it watches die (25/25 heals in the log
are `healed_by: dispatcher`), the keeper keeps the fleet at cap (its log is 384× "at cap — no
dispatch" vs 6 dispatches — that is a *full* fleet, not a broken keeper), and the done-gate has
held. The findings below are the gap between "works to some degree" and "reliable".

**F1 — Two keeper loops are running against the live queue right now.** Pid 9793
(`tools/fleet-keeper.sh`, 10:19) and pid 22047 (`tools/fleet-keeper.sh status`, 03:11 — 7h+).
`fleet-keeper.sh:80-81` silently ignores unknown arguments, so the diagnostic invocation
`fleet-keeper.sh status` (a `fleet-cooldown.sh` verb, not a keeper verb) fell into the infinite
loop. Both write `untracked/fleet-keeper.pressure.json`, `heal.json`, `logjam.flag`, and the same
log with **no locking and no single-instance guard**. The log shows interleaved iterations ~2 s
apart within each 10 s window.

**F2 — A keeper can run as a permanent no-op at the delegation cap.** One of the two loops
inherited `WEIZIGO_AGENT_DEPTH=3`; every dispatch it fires is refused
(`fleet-keeper.log:215` REFUSED / `:216` the other keeper dispatches the same row one second
later). The keeper never checks its own depth at startup. This also re-opens the
duplicate-dispatch window (two keepers can select the same row in the same second; only the row
flipping to `in_progress` inside that window prevents it).

**F3 — The regression suite pollutes the live telemetry it is supposed to protect.** 8 of the
25 records in `docs/infra/dispatch-heals.jsonl` (32%) are fixtures T989/T990 from
`tools/regression-dispatch.sh` — the harness exports `MANAGENT_STORE` and `WEIZIGO_MODEL_PERF`
(`:71-72`) but **not `WEIZIGO_DISPATCH_HEALS`**, and `heal_dispatch` defaults to the real repo
(`tools/dispatch_verify.py:356`, via `bin/subagent:292`). Every `zig build test` appends two fake
heal records, which then feed the keeper's T504 heal-cooldown signal
(`fleet-keeper.sh:283-310`). Contrast `regression-dispatch-verification.sh:82`, which exports it
correctly. This is the T425/T448 shape — the test perturbing the live instrument — for the third
time.

**F4 — The one documented automatic heal does not exist in any shipped script.**
`fleet-monitoring.md:56-72` and `fleet-surface.md:157-198` both specify `WATCH_FLEET_HEAL=1`;
`untracked/watch-fleet.sh` at HEAD contains no heal at all (T492 dropped it along with the
`WATCH_FLEET_ONCE`/`WATCH_FLEET_SOURCE`/`etime_secs` hooks). The regression
(`tools/regression-watch-fleet.sh:55-71`) was re-pinned to old commit `333b855` and green-lights
a heal **extracted from git history**, not the live file. Healing survives only because
`dispatch_verify.heal_dispatch` covers the watched-child case; a row orphaned any other way is
healed by nobody. Also: the operator console itself lives at `untracked/watch-fleet.sh`, outside
the `tools/` discipline every other instrument obeys.

**F5 — Stale loud artifacts.** `untracked/fleet-keeper.logjam.flag` says
`T364 … waited=241min` while `pressure.json` says NORMAL and T364 is *running* — the flag is
written (`fleet-keeper.sh:536-537`) but never removed when pressure exits. A loud artifact that
outlives its condition trains readers to ignore it.

**F6 — Degraded identity is the live norm.** 14 of 33 run records in `untracked/runs/` are
`runner_<pid>.json`, not task-named — exactly the mode `runner.md:149-154` calls "how the fleet
ran blind": `managent liveness` cannot attribute those beats, `managent tell <id> pause|kill`
cannot reach them. Two fixture leaks sit in the same directory (`T449-NULL-OLD.json`,
`T449-REG-NULL.json`).

**F7 — Duplication census (the consolidation case, measured).** Orphan/dead-claim detection is
implemented **five times in four codebases with four definitions** (watch-fleet pgrep;
managent `classifyReapRows` used by reap+resume; managent audit; two separate argus checks;
dispatch_verify heal — only the last one acts). Model canonicalization ×4 (managent
`canonical_models[]`, dispatch, subagent, watch-fleet `mdl()`), and the keeper's least-data
picker (`fleet-keeper.sh:247-248`) lists only 5 models where dispatch admits 9 — **a model-less
row can never draw a Claude label, so the T503 exploration-first rule cannot sample them.**
Bundle-glob resolution ×4, row-state gate ×3, duration formatting ×3, and the keeper re-derives
managent's holds-conflict rule in Python-inside-bash. Root cause of much of it:
`managent status --json` omits `added` and `claim_count`, so the keeper shells `managent show`
per row and parses `tasks.json` raw (`fleet-keeper.sh:180-189`, `:312-329`).

**F8 — Wall-kills are the dominant failure.** 16/25 heals are exit 124, ten of them at exactly
2700.4–2700.7 s (the dispatch default wall) — these are timeouts, not crashes. AC7 counts 20.
Either the briefs are too big (the handover's own diagnosis) or the walls are miscalibrated per
task class; nobody currently distinguishes "hung" from "honest work that needed 50 minutes".

**F9 — Known live-write hazard, still unfixed:** `managent assert` derives the assertion-ledger
path from CWD repo root, not `MANAGENT_STORE` (`fleet-surface.md:207-215`) — a scratch run from
inside the live repo writes the live ledger. Filed, deferred (T353 held the file), still open.

**F10 — Stale prose contradicting shipped mechanism** (each an L1 item):
`duties.md:71-73` ("managent has no duty verbs" — `cmdDuty`/`cmdLandmark` shipped, T478);
`STANDING-ABSORB.md:6-13` (threshold-5 language, retired by ratified D3);
`model-perf.md:1` ("untracked scratch" — it is tracked); `bakeoff.md` "fleet cap of two"
vs `FLEET_CAP=5`; `fleet-monitoring.md`/`fleet-surface.md` duplicate the heal spec while
declaring they don't; `model-task-matrix.md` §3b "in flight" for closed T451/T452/T453.

## 3. Model-performance measurement — why it keeps failing

**The mechanical half runs; the judgement half structurally lapses.** The only automated writer
is `dispatch_verify.record_perf` (101 ledger lines; 60 pass / 41 fail; nothing for `claude-*`
because Claude seats don't dispatch through that path). Impressions have lapsed under three
different orchestrator models — `model-perf.md:2703` ("the seat, not the models") — and the
file's own diagnosis stands: model-perf is append-only prose with **no lint, no gate, no duty**.
The four registered duties (DCLAIM/DRPLAY/DARGUS/DFLEET) do not cover it; `managent done` does
not ask for it. Until an impression (or an explicit waiver) is *demanded by a gate at close*,
this will lapse again — that is the ratified absorption lesson (D3) applied to the other ledger.

**Specific defects, measured:**
- **Tokens have never been collected once.** All 6 `untracked/bakeoff/*/tokens.template.md`
  files are blank; every race records the gap. The protocol makes token capture a *human* step —
  it must be mechanized or it will stay at n=0. There is also **no price table** despite
  `bakeoff.md:224-226` pointing at one.
- **The T503 profiles table went stale within hours of being pasted** (flash correctness 1.69
  n=68 live vs 1.81 n=57 pasted) — the doc even says "recompute, never hand-hold". The tool
  implements 6 dimensions and 4 task-type buckets where directive D027 ordered 8 and 8.
- **Attribution is split:** `tasks.json` `agent` is populated on 176/187 rows, `model` on 28.
  Two silent model-epoch boundaries (2026-08-05 preview bump, 2026-08-18 new `deepseek-v4-pro`
  under the same label) mean aggregates that cross them are meaningless; nothing enforces the
  boundary.
- **Allocation beliefs remain confounded by construction** (`model-perf.md:64-95`): data was
  collected under the allocations it is used to justify. Only races break this — which is why
  the grand race matters beyond the fun of it.

**The race protocol is good on paper and was breached in practice (T452, the largest race ever
run — 7 lanes including both Claude models):**
- ran from the **main checkout** (`lanes.json: root_is_worktree=false`) with the key reachable
  by relative path;
- **family exclusion was breached**: graders kimi-k2.7 and glm-5.2 each graded a lane set
  containing *their own output* (glm scored itself E=16); the task note *reinterprets* the rule
  rather than meeting it;
- blinding leaked (lanes self-identified as MiniMax-M3 in their own text);
- the result is essentially unrecorded: `docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/T447-escape-sweep.md:126-143` still
  says "dispatched", no inter-grader agreement was computed, scores live only in two findings
  files, the seal never formally opened.

What *did* work, and must be kept: key sealed pre-dispatch with commit hash (T447 `111c141`,
T456 `e01fb19`); blind name-hash shuffle with a sealed lane map; mechanical grading where the
task allows (T456 collapsed grader-validity into the task's own null/seeded arms); and the field
beating the key (all five T447 lanes found the `regression-argus-doctor.sh:195` live-AGENTS.md
seeding the key missed → T448/T449/T450). Enforcement, not redesign, is what the protocol needs.

## 4. Absorption — the crisis is machined, not yet closed

C7 is 0 *today* and the done-gate (T485) is live with seeded and null controls and no `--force`
bypass — a real mechanism where three seats' prose failed. Open ends: T486 (partition trigger),
T487 (archive NON-CONFORMING parser), T489 (prose sweep — F10's STANDING-ABSORB language is its
work), T491 (audit enforcement). Note `STANDING-ABSORB` has **never recorded a chunk**
(`last_chunk_ts: null`; last findings dated 2026-08-05) and its trigger note ("11 > 5") is
stale against the measured 0 — the standing row is currently decoration; T486 is what makes it
mechanical.

## 5. Immediate actions (operator or seat — each ≤5 minutes, none performed by this audit)

1. **Kill the stray keeper:** `kill 22047` (the `fleet-keeper.sh status` mis-invocation, running
   since 03:11 at depth cap). Verify one keeper remains: `ps aux | grep fleet-keeper`.
2. **Remove the stale flag:** `rm untracked/fleet-keeper.logjam.flag` (contradicts
   `pressure.json`; T364 is running).
3. **Stop the telemetry pollution:** one-line fix — export `WEIZIGO_DISPATCH_HEALS` in
   `tools/regression-dispatch.sh` (copy `regression-dispatch-verification.sh:82`); then scrub
   the 8 T989/T990 records from `docs/infra/dispatch-heals.jsonl` (append a correction record,
   don't rewrite history silently — or filter fixture IDs at read time in the keeper).
4. **Close L2:** dispatch the N1–N3 propagation absorb pass and put the discharge ruling in
   front of the operator. The critical path is one clerical step from banked.
5. Register the F1–F10 fixes as rows (drafted with acceptance bars in
   `docs/status/ROADMAP-2026-08-20.md` §2).

---

**Landmark:** this audit is `L1 (the dashboard tells the truth)` work — it measures where the
dashboard still lies (F1–F10) and finds `L2 (proven 4×4 values)` one absorption pass from
closed, whose loss would be the operator's if the clerical tail is left to rot.

**Human summary:** the fleet runs — mostly at cap, healing its own watched deaths — but it runs
on duplicated logic in four languages, a keeper that accepts garbage arguments and runs twice,
a test suite that writes fake records into live telemetry, and a documented self-heal that no
shipped script contains. Model measurement collects the mechanical half and structurally drops
the judgement half; tokens have never been counted once; the best race ever run breached its own
blinding and family-exclusion rules and was never written up. None of this is mysterious: every
failure has a file:line, most have a one-row fix, and the consolidation the operator wants is
justified by measurement (F7), not tidiness.
