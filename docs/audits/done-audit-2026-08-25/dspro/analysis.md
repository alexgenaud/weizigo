# T946 — DONE audit, dspro arm: analysis

**Author:** deepseek-v4-pro/T946 · **Audited:** 24 rows (12 disjoint + 12 shared control)
**Landmark:** advances `L1 (the dashboard tells the truth)`.

## Census

| judgement | complete/yes/verified | partial/mixed | none/no/unverifiable |
|---|---|---|---|
| work_actually_done | 20 complete | 1 partial | 3 none |
| verdict_accurate | 23 yes | — | 1 no |
| absorbed | 17 yes | 4 partial | 3 no |
| self_reported_or_verified | 19 verified | — | 4 self-reported, 1 unverifiable |
| useful | 17 yes | 4 mixed | 3 no |

One recorded verdict I judge inaccurate (T943), one unverifiable attribution (T841), and four
rows whose result was only partially absorbed. The three `none`/`no` rows are all `abandoned`
negatives (T921 killed, T842 runaway, T841 starved) — those verdicts are honest, which is why
`verdict_accurate` stays 23/24 while `useful` and `absorbed` are lower.

## The single most important pattern

**Verdicts are honest; content-verification is the weak link — and the fleet never
self-catches a wrong headline number.** `fail-found` is zero across all 525 closes, and in my
24 rows the two objectively-wrong results both closed `pass`/`pass-with-findings` *without the
closing row detecting the defect*:

- **T924** published a 4×4.D3 projection that was **7.585× too high** (unweighted mean over
  125 capped roots). It closed `pass-with-findings`; the error was caught only by T929's
  re-derivation from committed CSV data.
- **T943** closed `pass` via `tools/runner` auto-close while its own acceptance regression was
  **RED** on a clean host (a caffeinate false-positive). The gate did not gate.

What would disprove it: a closed row whose deliverable carries a wrong number and which
**re-derived its own number and corrected it before close**. I found none; the only correction
came from a second row (T929). The pattern is the one the operator already named for tooling —
*"the tool reported success while doing nothing"* — but here it is *"the close reported success
while the content was wrong."*

## No-acceptance stratum rows in my slice

Three of my disjoint rows are in the no-`acceptance=` stratum: **T685**, **T804**, **T900**
(plus control **T421**, which predates machine-checked acceptance). None had a machine close
gate, yet all four are verifiable another way:

- T804 and T900 wrote their own regression tests (watch-fleet exact-fill; model-task-metrics
  9 arms) — self-authored gates, weaker than an independent acceptance but present.
- T685 was graded by an independent grader (T696) who held the key.
- T421 shipped the C10 claimlint checker, a machine instrument.

So the no-acceptance stratum is *not* a wasteland of unverifiable closes — but verification
there rides on the row's own test authorship or a later grader, both of which are exactly the
checks T924 and T943 lacked.

## Record-quality defects found (not the rows' fault, but load-bearing)

- **T580** — store `model` field is `deepseek-v4-pro`, but `agent`, the findings file, and the
  commit all say `claude-sonnet-5`. The model-performance ledger would attribute this work to
  the wrong model.
- **T564** — its run record (`T564.json`) is **misattributed**: its `command` field is
  `sh tools/regression-fleet-keeper.sh` (exit 1, wall 11.8s), not the task's own run. The task
  itself completed (suite-truth.md committed at `39ee966`).
- **T841** — its `verdict_note` is **byte-identical to T842's** ("held a lane ~48 min,
  produced nothing"). The starvation attribution (1 Ollama request vs T842's 790) is absent
  from the store; an auditor reading the store cannot tell the runaway from the starved lane.
- **T685** — the lane's findings file is **untracked** (`git ls-files`: no match). It survived
  only because grader T696 consumed it; on a fresh clone it would vanish.

## Rows I would re-open / correct

1. **T943 — re-verdict.** Closed `pass` on a red gate. Should be `pass-with-findings` at best;
   the false-positive regression is a real defect the close papered over.
2. **T580 — store correction, not re-open.** Fix the `model` field so the ledger attributes
   the work to `claude-sonnet-5`.
3. **T841 — note amendment.** Record the starvation (infra) vs runaway distinction, so the
   model-performance ledger does not read kimi's starved lane as incompetence.
4. **T924 — pointer amendment.** The doc was already corrected (commit `2614391`, T929); the
   store row should name that correction so a future reader does not re-trust the 7.585×-high
   number.

No row needs a full re-execution: every `work_actually_done = none` row is an honest
`abandoned`, and the two wrong results (T924, T943) have both already been corrected
downstream. What is missing is the *record* of those corrections in the store rows themselves.

## Control-slice note

The 12 control rows were audited blind of the sealed key (I read only `corpus.md`, which the
brief instructs). My independent readings matched the corpus §4 ground-truth summaries on all
12: T932/T927 clean passes; T894 work-real/record-absent (findings `audited_by claude-opus-5/T935`,
committed by the human seat); T924's 7.585× number; T921 true negative; T943 red gate; T842
runaway vs T841 starved; T907 blocked-then-committed (`594d860`); T387 partial (Bellman never
taken); T929 the correction; T421 fully absorbed.
