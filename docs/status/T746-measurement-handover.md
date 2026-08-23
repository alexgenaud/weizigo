# T746 — are we measuring the right things about models? Findings, rulings, and a handover

**Author:** `claude-opus-5`/T746 (discussion console with the operator) · **Date:** 2026-08-23 ·
**Landmark:** L1 (measurement integrity) · **For:** the `claude-fable-5` oversight seat (T771),
which holds the delegation / tooling / prose / process refactorization.
**Status:** the data fixes below are **done and on disk**. The tooling fixes are **queued, not
done** — six rows, listed in §7.

---

## 0. The question and the answer

The operator asked: *do we have confidence we are measuring and recording the right things
about models?* The decision it serves: placing `ox-alpha` against `claude-opus-5`,
`claude-sonnet-5`, `deepseek-v4-pro` and `deepseek-v4-flash` across the real task mix.

**Answer: not yet — but the gap was recording, not measuring.** The readings mostly existed and
were not joined; one whole family had never been metered at all; the model the decision is about
had zero cells and was excluded from every mechanized pick by a reservation the operator never
made; and the metric that actually predicts re-dispatch is computed in exactly one findings file
and appears in no ledger.

Three of those four are now fixed on disk. What remains is tooling, and it is queued.

---

## 1. Operator rulings recorded this session (2026-08-23)

1. **`ox-alpha` is used liberally, not reserved.** *"use oxalpha liberally"*; *"I want to compare
   Opus, Sonnet, DSPro, and Flash to oxalpha to get a sense of its strengths and weaknesses and
   where it lands on a ladder for our most frequent and important task types and phases."*
   The `RESERVED` appetite in the record was a **record defect** — see §3.1.
2. **The `pi --provider openrouter` invocation stays; the tooling changes to fit it.** The
   operator confirms the pattern works, and believes its API-key handling may be **more secure**
   than what we do for Claude, DeepSeek and Ollama — in which case it is the pattern the others
   should converge toward, and the integration question (how to make it first-class) is open
   work for Fable or a sprint, not a thing to normalize away.
3. **cpu / rss / token figures are collected but not trusted.** *"I am not confident that
   cpu/rss/tokens are reliable and repeatable. We can/should collect data, but not trust their
   veracity, and not necessarily make critical decisions based on these data."* This is the
   ruling that governs §3.4 and makes §4.1 a defect rather than a preference.
4. **Retroactive recovery is wanted.** *"I hope we can retroactively fix the data and collect
   more data for oxalpha."* Done — §3.2.

---

## 2. What was actually wrong

| # | defect | evidence |
|---|---|---|
| 1 | `ox-alpha` excluded from **every** mechanized assignment | `bin/managent assign --dry-run` → `ox-alpha: family ox-alpha appetite RESERVED (reserved task types only)` |
| 2 | 80% of the token ledger was UNKNOWN; the ollama-cloud family had **zero** readings ever | 621 rows, 127 readings; `glm-5.2` 0, `minimax-m3` 0, `kimi-k2.7` 0, `ox-alpha` 0 |
| 3 | the ledger's own reason for the UNKNOWNs was **false** | it asserts the pi session file *"cannot be attributed to this lane"*; `tools/token-capture.py` attributes it, and now has |
| 4 | `cost: null` in **24 of 24** rows of `model-task-metrics.jsonl` while readings sat on disk | nothing joins `untracked/runs/*.json` → the metrics record |
| 5 | the cost ladder has **no quality gate** and routes solo rows to the worst-measured discriminator | §4.1 |
| 6 | the stdout liveness fuse killed a working lane and blamed the lane | §4.2 |
| 7 | `stealth/ox-alpha` — a **serving tag** — was reaching records (the T276 defect) | 3 ledger rows; `canon_tag()` had no mapping |
| 8 | two D027 dimensions never recorded, and one of them gates qualification | §5 |

---

## 3. Fixed on disk this session

### 3.1 The `ox-alpha` appetite record — corrected
`docs/infra/model-registry.md` §Stealth model now records **SPEND**, with the operator's words,
and states that the mislabel was load-bearing rather than cosmetic. The **read-only advisor**
scope (T745) is recorded as a *scope* limit, not an appetite limit — and it costs little for
placement, since audit is 27% of volume and spec review is the growth cell, both read-only.

**Owed, one line, not applied here:** `src/managent/main.zig:321` still carries
`.{ .family = "ox-alpha", .appetite = .reserved }`. That file is serialized behind
T760/T767/T768/T770, so it belongs in Fable's batch. **Until it lands, no mechanized pick can
draw ox-alpha** — this is the shortest path to unblocking the comparison the operator asked for.

### 3.2 Retroactive token recovery — 448 lanes
New tool `tools/token-backfill.py`. The readings were never lost, only un-joined: when a
dispatcher passed no `--session`, `pi` wrote to `~/.pi/agent/sessions/<cwd-slug>/`, which
`tools/token-capture.py` already knows how to scan.

| | before | after |
|---|---|---|
| ledger rows | 621 | 1,069 |
| readings | 127 (20%) | **575 (53%)** |
| `glm-5.2` | 0 | 81 |
| `minimax-m3` | 0 | 32 |
| `kimi-k2.7` | 0 | 11 |
| `ox-alpha` | 0 | **5** |
| `deepseek-v4-pro` | 29 | 201 |
| `deepseek-v4-flash` | 25 | 171 |

Discipline: the ledger is append-only like a findings file. A MISSING record is a dated
assertion and was **never edited** — each recovered reading is appended with `supersedes_ts`
naming the record it corrects. 63 rows supersede an explicit UNKNOWN; 385 lanes had never been
recorded at all. Re-running appends nothing (idempotent).

**Validation, because no instrument's first reading counts without controls:**
- the same parser reproduces dispatch-time truth **exactly on 54/54** per-lane session files;
- attribution never contradicted an independent surface: **0 model conflicts over 160**
  comparable run records, 96 fully corroborated on task + start + model;
- two seeded-defect controls (`--control`) were each shown to **fail** on a seeded regression
  and pass clean;
- the ledger cannot validate the method end-to-end, because a lane writes *either* a per-lane
  session file *or* a cwd-slug one, never both — so the populations are disjoint by
  construction. Stated, not papered over.

Every recovered row carries `trusted: false`, `source: pi-session-jsonl-retro`, and
`corroborated: run-record | task-only | none`. **Evidence grades are not flattened.**

### 3.3 `ox-alpha`'s five lanes, recovered
| task | shape | start | in (fresh / cache) | out | turns | corroborated |
|---|---|---|---|---|---|---|
| T735 #1 | audit-adversarial | 10:11:42Z | 1,596,905 (113,257 / 1,483,648) | 16,657 | 39 | run-record |
| T735 #2 | audit-adversarial | 10:47:35Z | 2,168,300 (146,028 / 2,022,272) | 19,060 | 40 | run-record |
| T744 | spec (race I) | 10:49:25Z | 2,135,104 (171,840 / 1,963,264) | 19,069 | 42 | run-record |
| T745 | advisor | 10:58:00Z | 6,634,961 (547,409 / 6,087,552) | 44,762 | 125 | none |
| T754 | — | 11:53:01Z | 399,829 (105,237 / 294,592) | 7,540 | 15 | run-record |

Note the cache ratio: ~93% of ox-alpha's input is cache reads. Any cost comparison that sums
`tokens_in` without the fresh/cache split — as `tokens.jsonl` did before T558's split reached it
— overstates it by more than an order of magnitude. Same hazard applies to `claude-opus-5`.

### 3.4 `canon_tag` parity
`tools/token-capture.py` now maps `stealth/ox-alpha` → `ox-alpha` and carries `ox-alpha` in
`CANONICAL_MODELS`, matching `src/managent/main.zig`'s `canonicalizeModelTag`. Before this, any
per-canonical-label aggregation dropped ox-alpha **silently** instead of loudly.

The underlying smell for Fable: the canonicalizer exists in **four** places —
`src/managent/main.zig`, `tools/token-capture.py`, `tools/model-profiles.py`,
`tools/runner._model_from_argv` — and only `model-profiles.py` has a registry-parity control.
Per the standing doctrine the duplicates are mutual oracles and are not to be deleted; one is
production and the rest need the parity control that makes them oracles rather than drift.

---

## 4. The two findings that change decisions, not just records

### 4.1 The cost ladder has no quality gate — and it is picking the worst model (row T772)

```
$ bin/managent assign T750 --dry-run
method=solo-cost   model=claude-haiku-4-5-20251001
  claude-opus-5:     passed over — measured cost 2582009 > 1403846 (cheapest)
  claude-sonnet-5:   passed over — measured cost 1859929 > 1403846 (cheapest)
  deepseek-v4-pro:   passed over — measured cost unknown (not compared)
  deepseek-v4-flash: passed over — measured cost unknown (not compared)
```

`soloPick`'s comment says "cheapest **qualified** model". The only qualification applied is the
**appetite filter** — who may spend. methodology §5's gate (`score ≥ threshold` AND
`fabricated_citations == 0` AND `verification_rate ≥ floor`) is applied **nowhere in the
picker**. "Qualified" in code means *allowed to be asked*, not *shown able to do the work*.

`claude-haiku-4-5-20251001` is the model this project has most consistently measured as unable
to say *no*: 0/30 with a false-negative "no exploitable escape paths" (T557); 19 of 19 union
items called real where five are refutable (Race F); 0/4 canaries with fabricated citation paths
(T706). The ladder routes solo rows to it **because it is the cheapest model with a reading.**

And a second, compounding bias: unknown cost is never preferred over known-cheaper, so the
mechanism systematically preferred the family it could meter. §3.2 removes the asymmetry —
DeepSeek race lanes cost 1.1M–6.0M tokens against `claude-opus-5`'s 26.6M in race G.
**Consequence to weigh, not to act on unilaterally:** `docs/infra/complementarity.md`'s finding
that "the cheapest fully-costed full-coverage pair is opus-5 + sonnet-5 at ~33.7M tokens
(deepseek seats cost unknown, so a cheaper pair may exist)" is now very likely false — its own
parenthesis anticipated exactly this. Twelve lanes across `race-a`, `race-c`, `race-f`, `race-g`
and the eight sensitivity inputs hold `cost: null` and are now fillable; **all twelve are in the
strongest corroboration class.** Filling them edits a **sha256-sealed input to a dispatch
decision**, so it wants ratification, not a side effect — and under ruling 3 the reducer must
read the trust grade rather than average retro numbers into a live pick.

### 4.2 The liveness fuse killed a working lane and diagnosed the model (row T773)

`ox-alpha`/T735 attempt 2, killed at 600.9 s:
> `startup liveness timeout 600s (10'00) — agent lane produced no output since launch (bundle
> never read?)`

Its session file: first record `10:47:35.328Z` (1.3 s after launch), last record
`10:57:34.766Z` (0.2 s before the kill), 86 records, **40 assistant turns, 19,060 output
tokens.** The lane worked for the entire 600 seconds. The fuse reads **stdout**, and `pi`
buffers stdout to completion — documented twice before (the T447 qwen reading; Race F, where the
*winning* opus lane was killed the same way with its 43 KB deliverable already written and
recorded `verified=fail`). The note is worse than the kill: *"bundle never read?"* is a causal
claim about the model that the evidence refutes. A guard may state what it measured; it may not
attribute a cause it did not measure — the `killed_by` discipline already ratified for the
token-limit guard.

This lands hardest on ox-alpha, because every ox-alpha lane uses the raw `pi` invocation the
operator wants kept.

---

## 5. The metric rulings (row T750)

**The two D027 dimensions that were never recorded** — `tools/model-profiles.py` emits both as
`—` by design:

- **`thoroughness` (dim 3) — RETIRED, replaced by a mechanical successor.** "Depth of coverage"
  has no per-task signal and never had one; the directive's own examples are allocation-confounded
  impressions. Successor: **`canary_recall`** = seeded canaries landed ÷ seeded canaries present,
  against a sealed key. Same question, mechanical, already measured.
- **`citation_honesty` (dim 7) — RECORDED, from the race ledger, per run.** It is *already*
  load-bearing as methodology §5's **qualification gate** (`fabricated_citations == 0`
  disqualifies independently of score) while being absent from the record — so the gate cannot
  be run from the ledger at all. The signal exists: T626 itemizes 2, 2, 2, 4, 9 fabrications
  across five `deepseek-v4-flash` repeats of one brief.

**`correctness` stops being the audit headline** (audit is 27% of volume). A rubric total is
carried by volume of true-but-already-known findings: in T706 `deepseek-v4-pro` and
`deepseek-v4-flash` scored 23/25 and 24/25 at 100% precision while catching **1/4 and 0/4**
canaries; haiku scored 20/25 catching 0/4; opus caught 3/4 and was Pareto-dominant. One scalar
cannot separate those. The headline is the pair (`canary_recall`, `false_flag_rate`), recorded as
numerator/denominator counts — never a frozen percentage.

**`unique_catch` gets recorded.** methodology §5 calls verified dissent the most valuable output
there is and nothing records it. T706 computed it and it is the sharpest per-model fact in the
file: opus alone caught G34-status, G30 and G43 rationale; every other lane's unique set is
empty; G35 was caught by no lane.

**Per type, what predicts re-dispatch vs what is recorded:**

| type | share | predictor | recorded today | the gap |
|---|---|---|---|---|
| audit | 27% | canary recall at a stated false-flag rate | rubric total | volume can carry the total at 0 canaries |
| infra | 22% | did a control exist **before** the reading | verdict | record `controls_before_reading` |
| battery | 18% | wall/cpu/rss + completion | adequate | cost only (and now untrusted by ruling 3) |
| implement | 11% | sealed acceptance-gate exit status | verdict, 3 different bugs | no field fixes it — needs the sealed-gate race |
| orchestration | 8% | `close_latency_s`, `close_completeness` | **nothing** | both are `bin/managent` queries, never derived |
| integration | 6% | — | verdict, n≈1 | leave |
| research | 4% | — | verdict, n≈1 | leave |
| spec | 3% (growth cell) | downstream rework: did implementation renegotiate the spec | panel score | a panel score of a spec is the least falsifiable number we keep |

---

## 6. `ox-alpha` placement (row T753) and the n bar

Order, cheapest reliable first:
1. **Free — the two lanes that already ran.** T735 (audit-adversarial) and T744 (spec) hold
   findings. T730 grades ten lanes and **T735 is not one of them**; scoring it against T730's own
   ruling is a grade, not a dispatch.
2. **Audit / the T447 sealed key, 3 runs.** The best-instrumented cell in the project: sealed
   key, eight graded lanes across the four named comparators plus haiku, non-Claude grader
   available, and — the part that makes n interpretable — a **measured within-model variance
   band**: `deepseek-v4-flash` scored 22, 28, 33, 36, 37 over five repeats of this exact brief.
3. **Spec / design**, one shared brief against all four comparators — the operator's growth cell,
   and a read-only shape compatible with the advisor scope.

**The n bar, derived rather than chosen:** a 15-point spread on a 30-point rubric means n=2
yields a band, not an order. So **n=3 before any tier claim on ox-alpha; n=2 licenses
`provisional`; a single run licenses nothing regardless of margin.** methodology §5's emission
gate (anchored · n≥2 · ≥2 qualified models at different cost) stands unchanged beneath it.

**Grader independence caveat, new and specific:** G3 requires a grader outside the lane's family.
ox-alpha's family is **UNKNOWN**, so that guarantee cannot be given — it may share a family with
a lane it is graded against. Record the weaker guarantee explicitly rather than implying G3 held.

**On the reveal:** it is a **relabel, not an epoch bump**. Learning a model's name is not
evidence its weights changed, so measured cells survive under the new label. If the reveal
*also* discloses a version change, that **is** an epoch bump and those cells are labelled and
uncounted — two separate questions, recorded separately on the day. Recorded in the registry.

---

## 7. The queue handed to Fable

| row | title | state |
|---|---|---|
| **T772** | cost ladder has no quality gate; picks haiku, the worst measured discriminator | dispatchable — **highest severity, decides dispatches today** |
| **T773** | stdout liveness fuse killed a working lane and diagnosed the model | dispatchable |
| **T750** | record `canary_recall` + `fabricated_citations` + `unique_catch`; retire `thoroughness`; backfill from T706/T626/T557 | dispatchable |
| **T751** | runner falls back to the cwd-slug scan; trust grades end-to-end; the metrics join | dispatchable (rewritten per ruling 2) |
| **T752** | ox-alpha reveal checklist: matrix column, per-surface treatment, the relabel-not-epoch ruling | dispatchable |
| **T753** | ox-alpha placement against opus / sonnet / dspro / flash | blocked on T730 (rewritten per ruling 1) |

Plus the **one-line unblock**: `src/managent/main.zig:321` `ox-alpha` appetite
`.reserved` → the operator's liberal stance. Serialized behind the other `main.zig` rows; until
it lands, no mechanized pick can draw ox-alpha.

**Cross-cutting items for the refactorization sprint, in severity order:**
1. Qualification before cost, everywhere a model is chosen (T772). This is the difference
   between evidence-based delegation and cheapest-reading-wins.
2. Trust grades are structural, not advisory (ruling 3). A `trusted: false` reading must be
   unable to reach a pick without saying so. Consider whether the D044 DeepSeek rate band
   survives the budget-meter retirement — **ask, do not decide.**
3. Guards state what they measured and never attribute a cause (T773). The prose fix for this
   has been written twice and the identical error recurred; the mechanism is the remedy.
4. One canonicalizer, three copies, one parity control. Make the copies oracles.
5. The `pi/openrouter` API-key pattern as the *target* pattern for Claude / DeepSeek / Ollama if
   it is indeed more secure — an open question the operator raised, not a decided item.
6. Two live taxonomies (matrix §1's `T-A…T-H` vs D027's eight types). The JSONL is re-keyed;
   the prose is not, in either document.
7. **`managent done` silently ignores an unrecognized flag and defaults the verdict** — found by
   walking into it while closing this row. `done` takes `--status`; `amend` takes `--verdict`;
   the two subcommands disagree on the flag name for the same field. Passing
   `--verdict pass-with-findings` to `done` recorded `verdict=pass` with no warning. That field
   is cited as evidence by `model-task-matrix.md` §2 and `model-task-metrics.jsonl`, so a
   mistyped flag corrupts model-quality data silently — the exact defect class this document
   reports. The store cannot say how many past closes were affected (it records the resulting
   verdict, not the flag used), which is itself the argument for the fix: **refuse an
   unrecognized flag**, and make the two subcommands agree. T746's own verdict is corrected by
   amendment, with the original preserved.
8. **The findings schema has no field for "kanban rows this task registered."** `new_rows` means
   *CLAIMS.md* rows; this seat put kanban ids there and the C7 gate correctly refused the close
   six times. T767 already queues the `queued_kanban_rows` field — this is a second independent
   instance of the confusion it exists to remove, which is the argument for landing the field
   rather than writing more prose about the distinction.

---

## 8. Honest limits of this document

No grade was re-run: every score cited is read from committed findings. The censuses of
`untracked/runs/`, `untracked/tokens/` and the pi session directory are mine and reproducible
from the tools named. `findings/T730-ruling.json` does not exist yet, so ox-alpha's audit cell is
not yet a reading and T753 is correctly blocked. The retro readings are **validated on the
parser and corroborated on attribution, not validated end-to-end** — the ledger structurally
cannot do that, and the operator's ruling 3 is the right posture toward them regardless.
`tools/complementarity-record.json` was **not** regenerated: doing so would have changed live
dispatch behaviour from untrusted numbers, which is precisely what ruling 3 forbids.
