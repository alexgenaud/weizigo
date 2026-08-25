# RESUME — orchestration seat, written 2026-08-25 dawn for a fresh seat

Written to be sufficient on its own. The outgoing seat (`claude-opus-5`, T876) held the seat from
2026-08-24 evening through the night. This supersedes `RESUME-orcha-2026-08-24-night.md` for seat
state; that file's standing orders still bind except where amended below.

**62 commits landed this shift.** The headline is that the epistemic ledger went from largely
unexamined to fully audited, and a family of fleet defects that had been recorded for weeks got
mechanised.

## 1. What was settled

**The whole claims register is audited.** `docs/epistemic/claims-evidence-audit.md` (T907, Fable
adjudicating a three-lane race over all 233 rows against a closed five-verdict vocabulary):
**BACKED 145 · PROSE-ONLY 85 · ADJACENT 3 · DANGLING 0 · UNCHECKABLE 0.** Nothing dangles. Of the
150 rows whose status asserts something, **53 are defective — 42 re-runnable, 8 lost, 2 report,
1 stale-at-HEAD**. 67 of the 70 lane disagreements were the same artifact judged under a different
rule, not lanes looking at different things.

**Half the C3 debt was mis-pointing, not lost science.** `docs/epistemic/c3-evidence-triage.md`
(T893) ruled the 42 unbacked-PROVEN claims `a=2 b=16 c=3 **d=19**` — where (d) is *evidence already
committed, register not citing it*, a class the lane brief did not offer. T901 repointed 18 of them;
**C3 fell 42 → 24**, and T907's three independent lanes later verified all 18 as BACKED
number-for-number.

**A nine-model race ran and was adjudicated blind.** Substance /40: **oxalpha 37 · sonnet 35 ·
opus 33 · dspro 32 · dsflash 26 · kimi 21 · glm 19 · minimax 14 · haiku 8.** oxalpha won because it
was the only lane designing positive *and* negative control arms. `docs/infra/races/capability-metrics.md`
(T900) derived the dimension set from that race; `docs/infra/races/race-corpus.md` (T899)
consolidated every prior race.

**Do not build a model ladder from any of it yet.** T899 applied the emission gate by name:
`cost` is null in **49/49** rows, so the gate fails on the cost clause before n or anchoring are
consulted — **zero tiers have ever been emitted**, and no (model × task type) cell has two runs
under the same rubric *and* grader. The one durable measurement is about the *union* of a diverse
field, not any ranking: 7 models → 41 findings where the best single found 21, four criticals each
from a different model.

**Confound, unrecorded until now:** `pi --thinking` is set nowhere and recorded nowhere, and three
of four providers route through pi. Every race predates it. T891 threaded the flag; anything
measured before is a ranking of *models-as-served*, not of models.

## 2. Mechanised this shift — defects that had been recorded and never fixed

- **T880** — `holds=` silently truncated a space-separated list to its first entry, and the
  confirmation line printed one hold either way. T872 had shipped with **zero** of its four holds.
  Fixed, backfilled, with a `holds --sync` verb.
- **T895** — run records now declare their kind; `reap` reads the *dispatch* record, not the newest.
  This was catching healthy workers twice a day.
- **T902** — **private `GIT_INDEX_FILE` per commit.** The old flock serialised committers but the
  index was shared, so one console's commit captured another's staged files. Verified working: my
  commits now report *"contains exactly"*.
- **T890** — dead serving tags refused before launch (`kimi-k2.7:cloud` had been documented
  do-not-dispatch since 18 Aug and the dispatcher still accepted it).
- **T906** — the 40-char title gate moved from `bin/dispatch` to registration. **271 of 726 briefs
  (37%) violated it** because the gate was on the wrong door.
- **T764** — the C15 brief-citation check landed.

## 3. In flight

| row | model | what |
|---|---|---|
| T912 | opus | **waypoint 1** — adjudicate the 62 ko-sensitive 3×2 disagreements |
| T910 | dspro | bound the run-record scan; **target is a 9.14 s refresh, not the 1.11 s the brief first said** |
| T908 | glm | the live-rate defect (two seat hypotheses already falsified — read its CORRECTION 2) |
| T913 | dsflash | declare RAM by wall, not provider |
| T825 | minimax | reconcile the claim buckets against T907's audit |
| T709 | oxalpha | reconcile rc=0 with deliverables |

**Queued behind `src/managent/main.zig`** (contended, one writer): T873 (green-up fix-test, 21
entries — the S11 critical path), T892, T894, T909.

## 4. Traps earned this shift

- **A generic symptom hides a specific cause, three times over.** A model that does not exist was
  reported as *"the worker did not echo the nonce"*. A closed-but-running lane was reported as
  `UNKNOWN` tokens/s. A worker killed for memory was reported as bare `rc=124`, with the real reason
  one line higher in a log nobody reads. **Read the runner log and the transcript before believing
  a verdict class.**
- **A lane killed by the RSS cap never emits its JSON envelope, so its `session_id` is null** — and
  the transcript link dies with it. Find it by content in the harness transcript directory instead.
- **Raising a RAM cap can make a lane die sooner.** T912 grew to fill 1280 → 2760 → 7685 MB. That
  is unbounded growth in the *worker's own approach* (it wrote a recursive Python solver), not a
  tight cap. **Diagnose before re-dispatching; the seat burned four attempts not doing so.**
- **One unfinished row can freeze every commit in the repository.** T764 ended with 389 uncommitted
  red lines and the pre-commit gate refused the whole fleet until it was re-dispatched to finish.
- **Close releases holds; it does not stop the worker.** T786 closed `pass` and kept running 35
  minutes, committing 8 minutes after its own close, while its file was handed to another live row.
  T909 carries this.
- **The seat published three wrong numbers this shift**, each from reasoning instead of measuring:
  an evidence count that included already-committed files, a canary-recall figure from a substring
  regex (Fable found one lane scored 0/2, not 2/2), and a dashboard cost that timed the components
  it guessed at rather than the whole frame. **Measure, then state.**

## 5. Standing state and open items

- Caps unchanged: 2 rows/model, 5/family, 10 concurrent. **Fable is no longer strictly reserved** —
  the operator directed it to adjudicate (T893, T900, T907) and it is the strongest judge available.
- **A Claude usage limit takes out the seat and every Claude lane simultaneously.** Availability
  correlation, distinct from the family rule. Do not put the critical path on Claude lanes.
- Ollama and Claude both have windowed quotas the operator watches; he reports them. Pace against
  his numbers, not against the caps.
- **`docs/research/roadmap-perfect-4x4-2026-08-25.md`** holds the conditional reasoning toward a
  compressed provable 4×4 — explicitly *a* roadmap, with its five named uncertainties. Waypoint 1
  can invalidate everything after it, which is why it is first.
- Owed to the operator: OPEN.md A2, A3, A4 remain undecided.

## 6. Before believing any status

`bin/managent reap` — but **check the process table for a live `--arbiter-id <task>` runner before
trusting an orphan verdict** (T895 improved this; verify it holds). Then: repo points at itself,
`core.worktree` unset, HEAD file count >2000, `.gitignore` 46 lines, last author `alex@genaud.net`.
Re-verify after every commit.

## 7. How to talk to the operator

`docs/infra/discuss.md` governs: recap in human words, exactly one decision per ask, then stop.
**Never a structured question widget.** He corrects sharply and is usually right — this shift he
caught the seat cataloguing bugs instead of dispatching them, leaving oxalpha idle, over-long task
titles, and a komi argument that was simply wrong. **When he pushes back, check before defending.**
