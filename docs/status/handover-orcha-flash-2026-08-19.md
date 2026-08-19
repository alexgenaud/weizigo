# Handover pack — Orchestrator seat, claude-opus-5 → deepseek-v4-flash

**Written by** claude-opus-5/orcha, 2026-08-19, while still holding the seat.
**Purpose:** prove the project runs on tooling and process, not on one model's context.

## 1. The bet being tested

Everything the outgoing seat knows that is not in a file is lost at handover — deliberately.
If the project keeps running, the tooling carries it. If it degrades, **the metric that
degrades tells us what the seat was silently supplying**, which is worth more than a smooth
transition.

`docs/infra/model-perf.md:2703` — *"The seat, not the models"* — records the same orchestrator
failure under Opus, then deepseek-v4-pro, then a third session. Three models, one failure. That
is the evidence this handover is built on.

## 2. Entry gate — do not seat until all five are true

| # | condition | why | state |
|---|---|---|---|
| 1 | `T477` landed and deployed — dispatcher reopens a task whose worker it watched die | five orphaned tasks in two days, every one relayed by the operator | in flight |
| 2 | `T478` landed and deployed — duties scheduled and gating landmarks | duties rot into fake tasks without it | in flight |
| 3 | `bin/dispatch` in use for every dispatch | folklore removed from the seat's hottest path | **done** (T476) |
| 4 | Baseline scorecard measured on the outgoing seat | flash inherits a number to beat, not a blank page | §4 |
| 5 | Acceptance criteria runnable by the incoming seat itself | self-testable, not operator-judged | §3 |

## 3. Acceptance criteria — flash runs these on herself, daily

Each is mechanical. A human is not required to judge any of them.

| AC | check | pass |
|---|---|---|
| AC1 orphan heal | any task `in_progress` with no worker process | 0, or reopened within one dispatch cycle |
| AC2 fleet idle | `in_progress == 0` while `dispatchable > 0` | never longer than one cycle without a dispatch or a stated reason |
| AC3 scope | commits touching a path held by another live task | 0 |
| AC4 landmark chain | dispatched tasks whose brief names no landmark | 0 |
| AC5 duty currency | duties overdue when a landmark is declared | 0 (T478 enforces) |
| AC6 verification | dispatches closed without dispatch-verify pass, unexplained | 0 |
| AC7 brief size | tasks wall-killed with no output | ≤1 per day — three in one day meant briefs were too big |
| **AC8 absorption** | `bin/weizigo-claimlint` C7 unabsorbed | **≤5 (the threshold), checked at every landmark declaration and at each day's end.** The seat's recurring historical failure: findings pile up unabsorbed and the ledger drifts from what was actually learned |
| **AC9 findings conform** | claimlint non-conforming count | **0.** A task may not close `pass` with a malformed findings file — this fired on 2026-08-19: `glm-5.2/T454` closed `pass` with invalid JSON and only claimlint noticed |
| **AC10 findings exist** | tasks closed with no findings file | 0 — T440 sat unclosable for eleven days on exactly this |

## 4. Scorecard — the operator's instrument, measured the same way on both seats

Derived from the kanban, `model-perf.md` dispatch-verify lines, and git. No judgement.

| metric | outgoing seat | how measured |
|---|---|---|
| tasks closed, 2026-08-18/19 | **34 dispatched, 141 done in the register** | `status --json` |
| dispatch-verify pass rate, today | **24 / 34 = 71 %** | `model-perf.md` dispatch-verify lines |
| dispatch-verify pass rate, all time | 33 / 53 = 62 % | same |
| wall-killed with no output | **8** | `grep -l "exit 124" untracked/log/t*.log` |
| orphans the operator noticed first | **5** (T440, T448, T450, T452, T475) | conversation record |
| write conflicts caused by the seat | **1** — `d7e4bdb` committed two consoles' work | git |
| live tasks naming no landmark | **1** (T438) | AC4 |
| closed tasks missing declared findings | **2** (T379 ×2, inherited) | AC10 |
| unabsorbed findings | **0** — but cleared by `kimi/T480`, not by the seat | AC8 |
| acceptance suite | **FAIL — 2 checks** | `sh tools/orcha-acceptance.sh` |

**Models used today**, by dispatch count: minimax-m3 8, kimi-k2.7 7, glm-5.2 7, deepseek-v4-pro 6,
deepseek-v4-flash 4, qwen3.8 2. Ollama first, as ruled.

**The outgoing seat fails its own acceptance suite.** That is the baseline, and it is the right
one: flash inherits a low bar, a suite that catches the failures, and the mechanisms built in
response to each. A handover that reported a clean seat would be the less useful experiment.

**The outgoing seat's numbers are not good.** They are the honest baseline; flash inherits a low
bar and the tools built in response to each failure.

## 5. Rules for the outgoing seat during the trial — read-only means read-only

`claude-opus-5` stays available as counsel and auditor. It **may not**: write the kanban,
dispatch, commit, or edit any file. It **may**: read anything, answer the operator, and record
observations in `findings/`. Two orchestrators writing is the duplicate-writer hazard the whole
week has been spent eliminating — the fix must not be reintroduced by the handover itself.

## 6. Kill criteria — pre-registered, so the decision is not a mood

Hand the seat back to Opus (or to dspro) if, over a two-day trial:

- any AC fails three days running, or
- an incident of the T445 class (live-repo damage) occurs and is not caught by the mechanisms, or
- the operator has to relay more process gaps per day than the baseline in §4, or
- the seat stops dispatching for a full working session without saying why.

Otherwise the seat stays with flash and the trial extends.

## 7. What the seat actually does — the whole job

Register tasks; write and refresh briefs; dispatch via `bin/dispatch`; read what comes back;
consolidate findings into the ledgers and status docs; put rulings in front of the operator.
**Never a diff.** Verifying a worker's task means dispatching an independent check, not
re-running it inline (`docs/infra/roles/ORCHESTRATOR.md`, "What the Orchestrator does NOT do").

## 8. Live state at handover

**In flight:** `T477` (dispatcher self-heals what it breaks) → glm-5.2. Re-dispatched after being
wall-killed once — the task about auto-reopening orphans became an orphan, which is the clearest
possible argument for finishing it.

**Deployed this session:** `bin/managent` at `a514612` — carries T464's single status resolver,
the `retire` verb, and T478's duty verbs (`duty <UID> done`, `landmark <Ln> --declare`, `--duty`).
Smoke PASS. Nothing is built-but-undeployed.

**Duties registered and idle:** `DCLAIM`, `DRPLAY`, `DARGUS` — all "not due (0/5 closes since
chunk), no chunk yet". **Open design question for the operator:** a duty that has never run a
chunk currently counts as *current*, so `landmark L4 --declare` succeeds today. Arguably a duty
with no chunk should block the first declaration. Not changed unilaterally.

**Open operator rulings, oldest first:**

1. **T443 storage policy** P1/P2/P4/P5/P6 — `docs/status/T443-storage-vote-2026-08-18.md`.
2. **Audit policy** — three tiers, sampling, and the failure-is-success sentence —
   `docs/status/audit-policy-vote-2026-08-19.md`.
3. **Absorption spec** — `docs/infra/absorption-spec.md` (T481, Fable). Retires the threshold in
   favour of a partition: open tasks may hold unabsorbed findings, closed tasks must be zero.
   Its §13 lists implementation tasks awaiting the ruling.
4. **Two proposed landmarks** from T479: `L8` (proposed via T458) and `L9` (via T328).
5. **Auditor independence** — T471's research on whether independence is a property of the model
   family or of absent shared context.

**L2 remainder, registered and unstarted:** `T473` (I11 exhaustive at 4×4 — the only
scale-expensive item) and `T474` (second auditor over the G3b evidence chain). `T472` ruled and
`T475` absorbed the corrected denominators.

**Known failures the incoming seat inherits:** AC4 — `T438` names no landmark; AC10 — `T379`'s
two findings files were never written. Neither is repaired here, because repairing them by hand
is exactly the seat behaviour being retired.
