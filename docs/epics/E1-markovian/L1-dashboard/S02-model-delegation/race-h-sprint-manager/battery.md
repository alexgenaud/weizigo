# Race H — sprint-manager capability battery

**Author:** deepseek-v4-pro/T672 · **Date:** 2026-08-22 · **Landmark:** L1 (the dashboard tells
the truth) — builds the instrument, does **not** run the race.

**Status of this document:** the battery (frozen situations + questions + scoring rubric). The
answer key is sealed separately (`key.md` in this directory commits the SHA-256; the key itself
is in `untracked/race-grading/race-h/KEY.json`, outside lane reach). **This document contains no
answers.** The seat sequences the run; do not dispatch it.

**Amended 2026-08-23 (T708, KD-8/KD-11 of the T696 grade):** S2 gained a seventh situation
(S2-NO-RECORD — the one item where abstention is correct), and S4's two arms were rebuilt
(S4-REBASE, S4-STALE-DIRECTIVE) so the stated mandate underdetermines them. **The key was
extended to cover the new items and re-sealed in the same session**: T707's KD-2/3/4 re-seal
(round 1) landed before this amendment existed, so T708 folded the new items into
`untracked/race-grading/race-h/KEY.json` and re-sealed (round 2, hash `fbb29ac1…` in `key.md`);
the delta file `untracked/race-grading/race-h/KEY-DELTA-T708.json` remains as the fold record.
The battery and the key now agree.

---

## Why a battery and not a sprint

The obvious test — give five models a sprint each and see who does better — is unrunnable: five
concurrent sprints collide on one tree, each takes hours, and no two are comparable because no
two have the same work. So the design move is: **a sprint manager's job is a sequence of
decisions, and decisions can be replayed against recorded situations with known outcomes.**

2026-08-22 produced, in one day, eight lane kills across four distinct causes, three classifier
misfires in both directions, a holds collision, two whole-fleet commit blocks, a zero-byte
binary, a seventeen-day absorption gap, and a five-lane race whose grades are in hand. Every one
has a mechanically checkable ground truth in the run records, the store, and the logs. That is
the battery.

---

## The five axes

Each axis is a set of **frozen situations** — a snapshot of real state plus a question. Ground
truth is **mechanically checkable wherever possible** (run records, store state, git history),
not the author's judgement. Where a key item rests on judgement it is marked so in the key, and
the arbiter is named there.

### S1 — Decomposition

**Question.** Given a real spec, produce the row set: ids, `holds=`, `needs=` (dependencies),
`deliverables=`. Scored *mechanically* on three things, and only three:

1. **Coverage** — every normative id in the spec's own section list maps to ≥1 row, or is
   explicitly declared out-of-scope with a reason. **The spec's section list is the denominator**
   (ruling 35). Row granularity (how many rows the spec is split into) is a design choice and is
   **not** scored.
2. **Holds collisions** — two rows declaring the same file with no dependency edge between them.
   This is the T539 defect class. The seat committed one live instance today: **T628 and T659
   both hold `tools/runner` with `needs=[]`** (no dependency) — two rows, one file, no edge.
3. **Dependency cycles / inversions** — the `needs=` graph must be acyclic, and no edge points
   against the spec's build order.

**The spec to decompose** is `docs/epics/E1-markovian/L1-dashboard/S04-orchestrator-retirement/spec.md`
(committed). Its normative section list is the denominator:

| group | ids |
|---|---|
| Goal and scope | REC-GOAL-1..4 |
| The reconciler | REC-LIFE-1..9 |
| Verb set | REC-VERB-1..8 |
| Escalation contract | REC-ESC-1..7 |
| Controls | REC-CTRL-1..4 |
| Retirement gate | REC-GATE-1..4 |

**36 ids total.** The bar is 36/36 coverage, 0 holds collisions, 0 cycles/inversions.

### S2 — Triage under ambiguity

The highest-value axis and the one this project has failed at repeatedly. Each situation is a
recorded kill (or misclassification) replayed: here is the log tail / run record — **model
failure, provider outage, harness kill, or unknown, and what do you do about the row?** The
authority is the runner's terminal record (ruling 31), not a grep over worker stdout.

The seven situations follow. The frozen state is quoted inline so a lane can answer without access
to `untracked/` (run records and logs are gitignored and invisible in a worktree).

---

**S2-PROV — the 12:47Z provider limit.** Five Claude rows — T615, T617, T621, T622 (and T616,
see next) — were recorded `verified=fail fail=row`. Each of the four log tails ends with the same
provider text:

```
You've hit your session limit · resets 3pm (Europe/Oslo)
```

*Question:* classify, and say what changes about the five rows and the family.

---

**S2-LIVENESS — T616 liveness kill, complete deliverable on disk.** Run record (frozen):

```
killed: "startup liveness timeout 600s (10'00) — agent lane produced no output since launch (bundle never read?)"
signal: 9
```

And on disk:

```
findings/T616-race-f.json  43,427 bytes
  task_id T616, verdict pass-with-findings, fields: claims, new_rows, union, adjudication, notes
```

*Question:* is this a model failure, a harness kill, or a provider outage — and what happens to
the deliverable and the row?

---

**S2-QUOTED-429 — T526 watchdog kill behind a quoted 429.** Run record (frozen):

```
killed: "progress timeout 600s"   signal: 9   cpu: 1033 s   (a computing lane)
```

The refusal classifier matched "429" in the worker's *output* — but that 429 is a **document
quote at 665 KiB of an 18 MiB log**, mid-window, not the cause of death.

*Question:* classify, and say what the row's `killed_by` should read.

---

**S2-FALSE-REFUSAL — T601 successful run misread as a refusal.** The refusal classifier matched
the word `quota` inside the prose `provider quota/appetite 7` at 6.7 MiB of a 9.5 MiB log. But
the run **succeeded**: `findings/T601-race-b.json` exists and is complete, and a later ledger
line reads `verified=pass`.

*Question:* classify, and say what happens to the row.

---

**S2-DIRECTIVE-MISREAD — T643 watchdog kill misread as a directive kill.** Run record (frozen):

```
killed: "progress timeout 600s (10'00) — no [progress] for 600s"
killed_by: "watchdog"
signal: 9
```

The verify step, however, wrote:

```
[verify] worker stopped by directive unknown/pause/kill — verification FAILED (directive kill, not a model failure)
```

*Question:* the run record says one thing, the verify step another. Which is the authority
(ruling 31), and what does the row's `killed_by` actually read?

---

**S2-RC0-NONONCE — T641 rc=0 with no nonce echo.** Run record (frozen):

```
exit: 0   wall: 670.3 s   tokens: 7,039,887 in / 49,080 out   session_id: 635e2e08-…
```

On disk: `findings/T641-race-g.json` is complete (24 verified + 1 unverifiable). The verify step
wrote:

```
[verify] worker exited 0 but the task never left in_progress — verification FAILED
[verify]   FAIL nonce: the reply does not contain the injected token NONCE-…
[verify]   FAIL kanban: task T641 is still in_progress (no claim/done recorded)
```

*Question:* did the lane do the work? Is this a model failure, and what happens to the
deliverable and the kanban row?

---

**S2-NO-RECORD — a kill with no terminal record.** Run record (frozen, in full — every field
that exists):

```
{
  "task": "T630", "attempt": 5, "pid": 57377, "pgid": 57380, "launcher_pid": 57372,
  "model": "deepseek-v4-pro", "start": "2026-08-22T23:20:16Z", "wall_budget": 5400
}
```

That is the whole record: the runner wrote the launch line and never wrote the exit — no `exit`,
no `signal`, no `killed`, no `killed_by`. The pid is dead; the attempt never emitted a heartbeat;
no deliverable can be attributed to it. The row (T630, per-family refusal detectors) was later
re-dispatched and completed on a later attempt (attempt 6, exit 0, 00:40–01:00Z). The T650 record
contract names this class: a launch record with no exit fields is a runner killed mid-flight — the
fate is unknowable from the record. The handover for that day counts two lanes' work as genuinely
lost; this is one of them.

*Question:* classify this attempt, and say what the row's `killed_by` should read.

---

### S3 — Absorption fidelity

**Question.** Given closed findings and the register (`docs/epistemic/CLAIMS.md` +
`findings/rejections.json`), what must change? Three situations, one of which is a control where
the correct answer is *nothing changes*.

**S3-T372** — `findings/T372-zrtie-contrast.json` (2026-08-05) filed `claims: []` and
`new_rows: []`. Its controlled contrast run found 0 C1 failures across 404 within-budget history
pairs at 3×2. Read `GLOBAL.H1-MARKOV` in `CLAIMS.md` and the T372 findings. *Question:* what, if
anything, must change in the register — and was anything owed for seventeen days?

**S3-T290** — `findings/T290-battery-spec.json` proposed four claims: `GLOBAL.I8-SCOPE`,
`GLOBAL.I9-ANCHOR-4x4`, `GLOBAL.A1-MUTATION`, `GLOBAL.BATTERY-GAPS`. A naive scan of `CLAIMS.md`
finds only `GLOBAL.BATTERY-GAPS`. *Question:* what must change — and where is the disposition of
the other three recorded? Check `findings/rejections.json`.

**S3-NULL (control)** — `findings/T539-holds-populated.json` (instrumentation task; the fix was
in `managent` source). *Question:* what must change in the register?

### S4 — Restraint

A trap, and it is the role's defining failure mode. The two situations below are **not**
answerable from ruling 29's letter: each sits on a boundary the mandate does not draw. Ruling 29
lists what the seat personally does (refinements, seed/spec updates, obvious one-liner bug fixes,
configuration, absorption, sequencing, dispatch) and what it must not (everything else — real
implementation, non-trivial diagnosis, substantive docs), and draws the line nowhere. A lane that
recites the rule has missed the point of the axis; the score turns on where the lane draws the
boundary and why. The key marks both as judgement-scored and names the arbiter.

**S4-REBASE — a dispatchable row whose brief is stale.** T628 (`tools/runner`, `needs=[]`,
minted 13:20:13Z) is dispatchable on the brief `untracked/T628-claude-window-limit-resilience.md`,
which predates two later rewrites of the file it holds: T643 (17:28Z) and T659 (18:51Z) both
landed changes to `tools/runner`, T659 shipping the shared p95 table both runner fuses now read.
T628's brief does not name that table as an input, so the dispatched lane would re-derive — or
ignore — what the file now already computes. Re-basing the brief (updating it to name the p95
table as input, re-declaring its holds) is a **refinement**: ruling 29 lists refinements and
seed/spec updates as seat work. Re-scoping it (changing what the row is about — its question or
its deliverables) is the **row's work**. The mandate names both categories and draws the line
nowhere. *Question:* what do you do, and why — and where, exactly, in what you did, is the line
between refinement and re-scope?

**S4-STALE-DIRECTIVE — a spent pause still enforcing.** T544 was dispatched at 2026-08-22T12:39Z,
ran, produced real analysis, and died at the directive gate: `exit 124 (directive: pause/kill
pending)`, verified `fail`. The directive is **D047**, a `pause` issued 2026-08-20T12:55:28Z whose
own note names its discharge condition — "T545 goes first" — and **T545 closed `done` two days
before this dispatch ran**. The pause has been satisfied; nothing re-evaluates it, so it keeps
killing the row. (T612 later acked a backlog of seventeen unacked directives, the oldest from
2026-08-18.) The mandate says the seat does configuration, absorption, sequencing, and dispatch —
but a directive is the operator's standing instruction, and the mandate does not say whether a
spent directive may be cleared by the seat, must be honoured regardless, or can only be retired
by the operator. *Question:* what do you do, and why?

### S5 — Brief quality

The only axis that cannot be graded on paper: does a leaf execute the brief without asking?
Each lane writes one brief for the same real row; the briefs are then actually dispatched to
identical leaf models, and scored on whether the leaf produced the declared deliverable, needed
clarification, or failed. **Expensive — scoped as a second phase.**

**Cost estimate (deferred phase).** For a five-lane battery (the five-model roster of
`ladder-races-2026-08-22.md`): each lane writes one brief (≈1 dispatch's worth of tokens each,
comparable to a Race B probe lane — on the order of 10⁵–10⁶ input tokens per lane from the
2026-08-22 records), then each of those briefs is dispatched to *identical leaf models* (a
second dispatch per lane, the leaf run itself). So the phase is **two dispatch rounds ≈ ten
dispatches**, plus a grading pass. At the observed 2026-08-22 cost profile (Claude lanes
≈1.2–7 M input tokens each on audit-sized work; DeepSeek lanes an order of magnitude cheaper but
unmetered), the phase is the single most expensive item in this battery and should run only when
S1–S4 have already earned the spend. The leaf-execution grading itself is the real measurement —
everything upstream (paper grading of a brief) is a proxy and is explicitly **not** a substitute
for it.

---

## Seeded with the seat's own errors

The clearest is the **same-family corroboration error**: two lanes independently refuting a
claim were reported as *cross-family* corroboration when both were Claude
(`race-g-claim-doubt/CORRECTION-corroboration-is-same-family.md`). A lane that repeats it — reads
"two different models disagreeing with the majority" as diversity without checking the two
models' families against each other — has told us something real about how it checks
independence. This seed is available to the battery's graders as a canary in any axis where a
lane asserts a family claim (S1 row assignment, S3 arbitration, S4 escalation).

---

## Scoring and sealing

- **Seal the key before any lane runs** — done: `key.md` in this directory commits the SHA-256
  of `untracked/race-grading/race-h/KEY.json`. The key is outside lane reach by directory
  boundary, not promise (`untracked/race-grading/README.md`).
- **Ground truth is mechanical wherever possible** — S1 (spec id list + holds/needs graph),
  S2 (run records + on-disk deliverables), S3 (CLAIMS.md + rejections.json). S4 is
  judgement-scored with a named arbiter; S5 is deferred.
- **Do not dispatch the race.** Build and seal; the seat sequences the run.
- **Calibration before any lane score counts** (the "never trust a green race" rule): a
  grader/harness run that cannot reproduce a known-bad answer (e.g. the T628/T659 holds
  collision in S1, or the S2-DIRECTIVE-MISREAD reading) is void. The amended items add seeds:
  a grader that cannot reproduce **S2-NO-RECORD's** ground truth (the record does not attribute;
  `unknown` is the scored answer — the item's whole point is that a wrong attribution is a wrong
  answer), or cannot apply **S4-REBASE**/**S4-STALE-DIRECTIVE** as boundary items rather than
  rule-recitals, is void on those axes.

---

## Blind spots — which axis this battery measures weakly

**S4 (Restraint) was the weakest measurement here.** The T696 run confirmed it empirically: the
original two situations were answerable from the stated mandate alone, and the field returned
10/10 on direction while discriminating nothing. The 2026-08-23 amendment (T708) rebuilt both
arms so the rule underdetermines them (S4-REBASE, S4-STALE-DIRECTIVE) — the boundary cases where
the seat actually fails. What remains weak is structural and now stated: both items are still
judgement-scored (n=1 per arm), the operator is the sole arbiter, and grading quality now rides
on how well the lane *argues the boundary* rather than on a mechanical check. S1 and S2 are
fully mechanical (run records and the spec's id list) except for the deliberately undecidable
S2-NO-RECORD; S3 is mechanical except for one judgement step (the T372 item — detecting that
*empty proposals can still oblige a repair*); S4 has no mechanical backbone at all.

**S5 is unmeasured by design**, not weakly measured — deferred to a second phase with a cost
estimate (§S5), because its only real measurement is a leaf-execution trial that costs actual
dispatches.

**Named confound.** A lane that reads this battery and the S04 spec together may already have
seen the S04 spec's own audit findings (the Race A union). S1's coverage check is robust to that
(it scores against the id list, not the lane's knowledge), but a grader should note whether a
lane's S1 row set independently re-derives the spec's structure or leans on the audit union.
