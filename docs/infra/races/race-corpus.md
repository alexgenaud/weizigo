# Race corpus — what every race we ran actually measured

**Author:** deepseek-v4-pro/T899 · **Date:** 2026-08-24 · **Row:** T899 (race-corpus
consolidation) · **Landmark:** advances `L1 (the dashboard tells the truth)` — this is the
first document that joins the race record, the schema that actually got used, and the
confounds, so the dashboard can stop quoting race orderings as if they were tiers.

**Non-promise up front (binding):** nothing in this document emits a tier. The emission gate
(`measurement-methodology.md` §5) requires an anchored cell, n ≥ 2, and **≥ 2 qualified models
at different cost**. `cost` is `null` in every one of the 49 structured rows in
`docs/infra/model-task-metrics.jsonl` (verified by direct read, not pattern matching — see §8).
Therefore **no cell can pass the gate today, none ever has, and none is emitted here.** Every
ordering below is a **provisional (n=1) reading with its confounds attached**, never a rung.

---

## 1. The races, enumerated

"Race" = two or more models given a byte-identical (or answer-keyed) task whose outputs were
blind-graded or mechanically gated, plus the grading rounds themselves. One row per race. Where
the primary sources are uncommitted (`untracked/`), the source is named by description, not path
(claimlint C10 / the T899 brief's committed-paths-only rule).

| # | race | date | question (short) | entrants | judge | protocol | verdict | primary sources (committed) |
|---|---|---|---|---|---|---|---|---|
| 1 | **EPISTEMIC race 1** (falsification design) | 2026-08-05 | does the lane kill seeded-mutant packets but not the clean twin? | dspro, dsflash | conductor glm-5.2/T371 (non-deepseek); graded by execution | bakeoff v1 (T328, landed same day) | flash 3/3 (0 false alarms); pro 2/3 (1 false alarm) | `findings/T371-race-first-runs.json`; `docs/evidence/EPISTEMIC-RACES/packets/MANIFEST.md` §race1; `docs/infra/bakeoff.md` |
| 2 | **EPISTEMIC race 2** (honest refusal) | 2026-08-05 | promote grounded claims, refuse the seeded traps, name the right gap | dspro, dsflash | conductor glm-5.2/T371 | bakeoff v1 | both 4/6; flash false-refuses 2 grounded packets, pro 1 wrong-gap refusal | `findings/T371-race-first-runs.json`; `docs/evidence/EPISTEMIC-RACES/packets/MANIFEST.md` §race2 |
| 3 | **T447 escape sweep** (read-only audit) | 2026-08-18 | find the session-leader escape paths in `tools/runner` | flash, dspro, glm, minimax, kimi (+ late unscored qwen) | claude-opus-5, blind, mechanical anchors | bakeoff v1 | flash 38 > dspro 34 > glm 30 > minimax 27 > kimi 25; qwen unscored (wall-killed) | `docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/T447-escape-sweep.md`; `findings/T447-regression-escape-sweep.json`; `docs/infra/model-task-metrics.jsonl` (5 audit rows) |
| 4 | **T452 design race** | 2026-08-19 | is a bounded semantics-preserving 2×2 fix possible? | flash, glm, kimi, minimax (round 2 expanded to 7 lanes A–G) | two independent blind graders: kimi/T459, glm/T460 | bakeoff v1 | graders **disagree**: T459 top A/E=20, D=19, B/C/F/G=18; T460 B/C/F/G=18, A/D/E=16; both: "bounded fix exists" is correct, C/F/G a tier above B on rigor | `findings/T459-t452-grading.json`; `findings/T460-t452-grading.json`; `docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/T447-escape-sweep.md` §T452 |
| 5 | **pass1-spec-r1** (spec/design tournament) | 2026-08-20 | author the pass-1 ownership-verb spec from the measured escape | 7 lanes (fable, opus, sonnet, haiku, dspro, dsflash, qwen) | 7 graders, blind (leaky — lanes self-identified) | grand-race v1.5 | no tier emitted (n=1); **union** = 41 findings, best single 21, four criticals each from a different model | `docs/epics/E1-markovian/L1-dashboard/S01-process-ownership/pass1/grading/03-round1-analysis.md`; `docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/metric-vocabulary.md`; `findings/T554-pass1-ownership.json` |
| 6 | **Aspect races A1–A5, E3, E5** (orchestration aspects) | 2026-08-20 | five orchestration aspects + two sealed epistemic packets, frozen fixtures | 7 lanes (fable, opus, sonnet, haiku, dspro, dsflash, qwen) | mechanical keys; **grading never completed** (G3/G4 red at dispatch) | grand-race v1.5 | **no grading → no capability verdict**; most lanes wall-killed by host memory pressure (exit 124 / `reason: host-memory-pressure`) — this is a *fleet-reliability* datum, not a quality datum | `docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/grand-race-p0.md`; `docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/grand-race-ledger.jsonl` |
| 7 | **race #1 (T447 replication)** | 2026-08-21 | replicate the T447 read-only audit (matrix hole #5) | opus, sonnet, haiku | deepseek-v4-flash (G3-clean, non-Claude), blind | grand-race v1.5 | opus 46 > sonnet 26 > haiku 0 (haiku false-negative "no escape paths"); provisional n=1 | `findings/T557-race1-t447-replication.json`; `docs/infra/model-task-metrics.jsonl` (3 rows, run_id `race1-t447-replication`) |
| 8 | **Race A** (audit) | 2026-08-22 | independent read-only audit of the S04 reconciler spec (dspro-authored) | sonnet, haiku, dsflash (+ opus as live T584; fable added later) | no blind grade; per-lane verdicts | ladder-races window 1 | all pass-with-findings; **no ranking emitted** (the union is the audit-loop fold input) | `findings/T588-race-a-sonnet.json`, `T589-race-a-haiku.json`, `T590-race-a-dsflash.json`, `T614-race-a-fable.json`; `docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/ladder-races-2026-08-22.md` |
| 9 | **Race B** (discernment, 2 arms) | 2026-08-22 | proactive / overreach / underreach, model × instruction-set (minimal vs orient preamble) | opus, sonnet, haiku, dspro, dsflash × 2 arms | grader seat claude-opus-5/T654 + 5 scorers (Race C) | ladder-races window 1 | **premise-doubt**: the three seeded triggers were never deployed in the lane environments, so Race B/C measured premise-doubt, not discernment; arm-delta ≈ 0 | `findings/T654-race-c-grade.json`; `docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/race-b-discernment/{brief,rubric,preamble-minimal,preamble-orient}.md` |
| 10 | **Race C** (mechanical bookkeeping = score Race B) | 2026-08-22 | score all ten Race B lanes against the sealed rubric | 5 scorers (haiku, sonnet, opus, dspro, dsflash) | grader claude-opus-5/T654 (ruled 12 inputs first, then graded scorers) | ladder-races window 1 | scorer-4 12/12 > scorer-3 10/12 > scorer-5 9/12 > scorer-1/2 8/12; scorer-1/2 flat 3/3 (no discrimination) | `findings/T654-race-c-grade.json`; `findings/T620..T624-race-c.json` |
| 11 | **Race F** (adjudication) | 2026-08-22 | adjudicate the union of five audits real/false/uncertain | fable, opus, sonnet, haiku, dsflash | grader deepseek-v4-flash/T632 (disclosed its own ~70% doubt on the G1 hinge) | ladder-races window 1 | five entrants; grader flagged harness kills (not docked) and its own ruling uncertainty; **no clean tier** — grading itself is the measured skill | `findings/T632-race-f-grade.json`; `findings/T615..T619-race-f.json` |
| 12 | **Race G** (claim doubt, batch 1) | 2026-08-22 | do lanes challenge a false epistemic claim (the claim-doubt axis) | opus, sonnet, haiku, dspro, dsflash | grader round via `T644..T648-race-g-grade.json` | ladder-races window 1 | per-lane verdicts recorded; batch-1 grade files exist but the durable synthesis is batch 2 (below) | `findings/T638..T642-race-g.json`, `T644..T648-race-g-grade.json` |
| 13 | **Race G2** (claim doubt, batch 2) | 2026-08-23 | re-rule 25 register rows at HEAD + 4 sealed canaries | opus, sonnet, haiku, dspro, dsflash | grader deepseek-v4-pro/T706 (ruled first, then cross-checked sealed key) | ladder-races | **opus 1st** (3/4 canaries, 25/25 status, pareto-dominant), **sonnet 2nd**, **dspro/flash 3–4 near-twins**, **haiku last** (0/4 canaries, 0/5 status recall) | `findings/T706-race-g-batch2-grade.json`; `findings/T690..T694-race-g2.json`; `docs/infra/model-task-metrics.jsonl` (5 rows) |
| 14 | **Race G-science** (claim-status audit, science arm) | 2026-08-23 | audit 25 sealed register rows' status + rationale at HEAD | opus, sonnet, haiku, dspro, dsflash | grader seat ruling `T730-race-g-science-grade.json` (ruled before lanes opened) | ladder-races science arm | grading-round ruling found 5 status-errors (G30/G34/G36/G38/G39) and 10 rationale-gaps; **the grader's own note: 2 of its 10 rationale findings unrepaired at HEAD** | `findings/T730-race-g-science-grade.json`, `T730-ruling.json`, `T731-race-g-claim-repairs.json`; `docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/race-g-claim-doubt/*.md` |
| 15 | **Race H** (sprint-manager battery) | 2026-08-22 | decomposition / triage / restraint / act on a frozen sprint-manager battery | opus, sonnet, haiku, dspro, dsflash | grader deepseek-v4-pro/T695 (same model as entrant T688 — disclosed, T688 not favored) | ladder-races | opus 1st, flash 2nd, dspro 3rd, haiku 4th, sonnet 5th; two key defects found (coverage escape-hatch, one mis-scored item) | `findings/T695-race-h-grade.json`; `findings/T685..T689-race-h.json`; `docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/race-h-sprint-manager/{battery,key}.md` |
| 16 | **Race I** (Waypoint-3 decomposition) | 2026-08-23 | decompose the 4×4 proof-fix into registerable rows | opus, sonnet, dspro, dsflash, ox-alpha | synthesis seat claude-opus-5/T749 (trunk + grafts, re-verified every number) | v2 | **document ranking** opus (trunk) > flash > dspro > ox-alpha > sonnet; ranking explicitly "ranks five documents, not five models"; 6 new findings incl. C8 vacuity | `findings/T749-race-i-synthesis.json`; `findings/T740..T744-waypoint3-spec.json` |
| 17 | **Race W** (terminology refactor) | 2026-08-23 | glossary three-ladders + DIRECTION §5/header note | ox-alpha, opus, dspro | **self-judged** (judge graded its own lane winner of both sections) → retro-marked unaudited | v2 (rule violated) | opus lane "won" both sections — **not evidence**; blind re-judge T780–T784 partial | `findings/T757-terminology-refactor.json`; `docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/race-protocol-v2.md` §7; `docs/status/OPEN.md` §A1 (resolved 2026-08-24 via T871 seat) |
| 18 | **Race X** (S06 spec audit) | 2026-08-23 | three independent audits of the S06 spec | dspro (T807), ox-alpha (T808), T809 | three graders: opus/T810, sonnet/T811, haiku/T812 | v2 | graders **disagree on the winner**: T810→T809, T811→T808, T812→T809; subject drifted mid-race (rev 2 vs rev 3) — not a clean three-way | `findings/T807..T809-race-x-s06-audit.json`; `findings/T810..T812-race-x-grade.json` + their `-ruling.json` siblings |
| 19 | **cost-repeatability** (T774) | 2026-08-23 | is per-model token cost repeatable across identical re-runs? | dspro, dsflash (instrument validation, not a capability race) | mechanical (20/20 repeats, analysis.py) | v2 | 20/20 repeats complete with token readings; validates the cost instrument, ranks nobody | `findings/T774-cost-repeatability.json`; `docs/evidence/T774-cost-repeatability/protocol.md` |
| 20 | **diffrace** (implement) | 2026-08-24 | fix the T818 "nonce vs no-work" defect in `tools/dispatch_verify.py` | dspro, dsflash, sonnet, ox-alpha, + 2 no-shows | judge glm-5.2/T832 (mechanical gates, 172 arms) | v2 | flash (T827) 1st — fixes the actual open-row T818 wound; sonnet 2nd; ox-alpha 3rd; dspro 4th (both "perfect 172/172" close an *unrelated* defect); 2 no-shows | `findings/T832-diffrace-judge.json`; `findings/T852-land-diffrace-winner.json`; `docs/infra/model-task-metrics.jsonl` (6 rows, `race=T832-diffrace`) |
| 21 | **ratrace** (infra) | 2026-08-24 | fix the UNKNOWN-forever rate defect in `watch-fleet.sh` | dspro, dsflash, glm (+ kimi, minimax no-shows) | judge claude-sonnet-5/T843 (mechanical, live-transcript fixtures) | v2 | flash (T839) 1st (correct per-turn sum + third CONCERNS state); dspro (T838) 2nd; glm (T840) real defects (max-of-per-turn mis-aggregation) → qualified=false; 2 no-shows | `findings/T843-rate-judge.json`; `findings/T853-land-rate-winner.json`; `docs/infra/model-task-metrics.jsonl` (5 rows) |
| 22 | **Race C3** (claim-evidence triage) | 2026-08-24 | classify 42 register claims (a: commit-it / b: re-run / c: draft-resolution) + 2 canaries | **9 lanes**: opus, sonnet, haiku, dspro, dsflash, glm, kimi, minimax, ox-alpha | adjudicator claude-fable-5/T893 (v2.1 rule 9; no lane of its own) | v2.1 | **two mechanical dimensions introduced**: investigative effort (paths named/real, median "where I looked") and discernment (normalized entropy of verdict distribution); adjudication: a=2, b=16, c=3, d=19 (already committed), undecidable=2 | `findings/T893-race-c3-adjudication.json`; `docs/epistemic/c3-evidence-triage.md`; `docs/infra/model-task-metrics.jsonl` (9 rows, `race=T893-race-c3-adjudication`) |

**Not a race, but folded into the record:** `pass1-spec-r1`'s grading round (the grader-quality
data in `metric-vocabulary.md`); the T459/T460 double-grading of T452; the Race W blind re-judge
(T780–T784, blocked on consensus T784); and the aspect-race round 2 (T546) which captured real
token readings for the first time.

**Races whose primary sources are gone or uncommitted:** every lane output, sealed key, and
patch in rows 1–22 above lives under `untracked/` (gitignored). The *verdicts and grade records*
are committed in `findings/`; the *artifacts* are volatile. Rows where even the verdict is not
committed are listed in the table as such ("no ranking emitted", "grading never completed").
Absence of an assertion is UNKNOWN, never "none" — where a race produced no committed grade
(aspect races; Race B's lane-level discernment), that is stated, not inferred.

---

## 2. Protocol revisions in force

| rev | document | when | what changed |
|---|---|---|---|
| v1 | `docs/infra/bakeoff.md` (T328) | 2026-08-05 | one brief, N lanes, one output file, one blind grader, sealed key; the n=1 caveat is standing |
| v1.5 | `grand-race.md` (fable, + P0 by opus/T529) | 2026-08-20 | phases, roster epochs, gates G1–G6 (tokens, isolation, family exclusion, blinding, records, impressions), grading panel + null/seeded controls, ledger schema |
| v2 | `race-protocol-v2.md` (T779) | 2026-08-23 | six testable rules R1–R6: pre-registered rubric, hermetic lanes, mechanical blinding (content-hash), one fresh blind judge with evidence quotes, family rule + audited/unaudited status, two-field ledger write; Race W retro-marked unaudited |
| v2.1 | `docs/status/landmark-waypoints-seed-2026-08-23.md` §4b | 2026-08-24 | rules 7–11: odd panels, split = merge guidance, seat adjudicates from primary sources, two verdicts per race (document + performance), **no self-judging ever** + field-only second reading |

The races span v1 (rows 1–4), v1.5 (rows 5–11), v2 (rows 12–20), v2.1 (row 22). Race W (row 17)
is the boundary: run under v2 but in violation of its own R5, and the rule that would have
prevented it (no self-judging) only became explicit as v2.1 rule 11. **Every verdict quoted below
carries its protocol revision; a v1 verdict is not interchangeable with a v2.1 verdict.**

---

## 3. The schema that actually got used — vs the one the docs describe

The schema documents (`measurement-methodology.md` §3, `grand-race.md` §6) describe a rich
record: `task_type, model, serving_tag, epoch, run_id, n, score_raw, rubric_max, cost, wall_s,
cpu_s, rss_mb, grader, blind, evidence, as_of`, plus verification fields and an anchor. What
`docs/infra/model-task-metrics.jsonl` actually holds (49 rows, read directly):

**Populated in (nearly) every row** — the envelope survived: `task_type, model, serving_tag,
epoch, run_id, task_id, n, correctness, rubric_max, qualified, actionable, grader, blind,
evidence, as_of, notes`.

**Always null — the load-bearing holes:**

- `cost` — **null in 49/49 rows.** The single most consequential empty column. `measurement-methodology.md`
  §6 named it the highest-leverage item ("until (b) lands, the goldilocks cost ladder is not
  computable across families"); it still has not landed. This alone voids the emission gate
  everywhere (§4).
- `tier_emitted` — absent in 49/49 (correctly so — see §4).
- `cpu_s` null 45/49, `rss_mb` null 40/49 — the trailer fields arrive only for the
  runner-captured lanes.
- `grader` null 7/49, `verdict` null 22/49, `race` null 21/49 — the 21 rows without a `race`
  field are the pre-race-identity rows (T447 and the T626 repeats), which were re-keyed by
  task type without a race provenance.

**Invented by one judge, never reused (each is a finding about the schema, not a measurement):**

- `t818_concrete_test` / `t818_note` — 6 rows, only `T832-diffrace`.
- `wall_s_grade` — 5 rows, only `T843-rate-judge`.
- `canary_recall_num/den, false_flags, flags_total, unique_catch, reference` — 5 rows, only
  `T706-race-g-batch2`.
- `mechanical_score, cost_grade, blind_note, green_arms_broken, red_arms_turned_green` — 20 rows,
  only the diffrace/ratrace judges.
- `paths_named, paths_real, median_what_i_checked, discernment_entropy` — 9 rows, only C3 (T893),
  i.e. the two dimensions the operator named *this week* and T750 is folding in.
- `task_scope, capabilities` — 11 rows (C3 + diffrace), the fields the operator asked for on
  2026-08-24, backfilled onto at most two races.

**The race-grade files (not the JSONL) carried their own ad-hoc shapes.** Race X is the worked
example, stated by its own grader (`findings/T810-race-x-grade.json` §metrics_supplied_summary):
a byte-identical brief asked three entrants for nine fields, and they arrived three ways —
top-level, nested under `measurement`, and as sentences inside a `notes` blob. "The brief asked
workers to 'record these fields' and never gave a shape, so nothing can aggregate this round
without hand-parsing." That is the standing B1 defect made concrete: **nothing writes the ledger
automatically, so each race's judge minted its own field names.**

---

## 4. Measurements vs beliefs — the emission gate applied by name

Gate (`measurement-methodology.md` §5): a tier is emitted only when the cell is **anchored**,
**n ≥ 2**, and holds **≥ 2 qualified models at different cost**. Otherwise `unmeasured` or
`provisional (n=1)`.

Applying it to the whole corpus:

- **`cost` is null everywhere** (49/49), so the "different cost" clause is unverifiable for
  every cell. **The gate fails on the cost clause before n and anchoring are even consulted.**
  Result: **zero tiers have ever been emitted, and none is emitted here.** `tier_emitted` is
  absent in all 49 rows — which is the honest reading, and the judges who wrote `provisional
  (n=1)` / "no tier emitted" (T832, T843, T557, T447) were right to.
- **n per (model × task type) cell:** opus has 46 (T447-rep) *plus* race-A — but across
  *different graders and subjects*; that is n=1 per race, not n=2 in one cell. No (model × task
  type) cell has two runs **under the same rubric and grader**. So even the best-populated cell
  (audit) is provisional.
- **Measurements that DO exist** (provisional, n=1, but real — mechanical or blind-scored with a
  sealed key): T447 audit scores; race1-rep scores; Race G2 canary-detection and status recall;
  C3 effort/discernment; diffrace/ratrace mechanical gate passage; T774 cost repeatability.
- **Beliefs, plainly so:** `goldilocks.md` ("working hypotheses (NOT rules)", the naive-prior
  ladder Fable > DSPro > Opus > Flash > Sonnet > Qwen > Haiku > Gemma — explicitly a starting
  guess); `ladder-races-2026-08-22.md` tier design (a *plan* for races, not a result);
  `docs/infra/archive/model-perf-2026-08-21.md` (stamped "impressions, not measurements").
  These are Class B/C beliefs, written to be falsified, and they are cited here only as such.

**The one number that has survived as a *measurement*, not a belief:** the **union** result from
pass1-spec-r1 — 7 models → 41 findings, best single → 21, four criticals each from a different
model — reproduced in three committed places (`goldilocks.md:12`, `measurement-methodology.md:221`,
`pass1/OWNER-LOG.md:572`). That is a statement about the *field's union*, not a ranking of any
model, and it is the strongest single finding the corpus produced.

---

## 5. Confounds — expected to be large, listed so no ladder hides them

1. **Thinking level is unrecorded for every pi-routed lane.** deepseek, ollama and
   openrouter/ox-alpha all route through pi; `--thinking` is set nowhere in this repository, and
   no ledger column records it. Every deepseek/ollama/oxalpha entrant may have run at a
   different effective reasoning budget. This alone may dominate several published orderings
   (T447's flash-over-pro, Race G2's pro/flash near-tie, C3). `T891` fixes the recording; this
   row establishes which results are affected — **all of rows 1–22 where a pi-routed lane
   appears.**
2. **Lane invocations differ by provider.** Two providers have run without the stdout stream and
   without a session file, so their output reached the judge through a different channel
   (`grand-race-p0.md` §5 — DeepSeek lanes dispatched `--no-session`, destroying token records at
   dispatch; partially fixed in round 2 via `pi-session-jsonl`).
3. **Grader mix.** Several published orderings merge scores from different graders. T447 was
   graded by opus; race1-rep by flash; Race G2 by dspro; Race H by dspro. A model compared
   across those races is compared across graders. T452 shows the magnitude: two independent
   graders disagreed on 3 of 7 lanes' absolute scores.
4. **Self-judging.** Race W's judge graded its own lane winner of both sections (T757
   disclosure); retro-marked unaudited. v2.1 rule 11 now forbids it, but the pre-v2.1 corpus is
   contaminated where the grader shared a family with a lane it ranked.
5. **Subject drift mid-race.** Race X's three entrants audited two different revisions (rev 2 vs
   rev 3) through no fault of their own — T810's grader explicitly downgraded it from a
   three-way race to a two-way + one.
6. **Premise falsity.** Race B's three seeded triggers were never deployed in the lane
   environments, so Race B/C measured *premise-doubt*, not discernment (T654). A race whose
   premise is false measures the premise.
7. **Host memory pressure.** The aspect races (A2/A4/E3/E5) killed most lanes with exit 124
   (`reason: host-memory-pressure`) — `grand-race-p0.md` and the ledger record these as
   *infrastructure* (`verified: infrastructure`), never as quality. Any ordering that counted
   those as DNFs is wrong.
8. **Blinding leaks.** Race X's grader (`findings/T810-race-x-grade.json` §blind_honesty)
   disclosed that `bin/managent orient` prints the recent git log — including commit subjects
   naming the entrants — so the grader knew identities before scoring. Hashing filenames cannot
   remove a leak that lives in the preamble.
9. **Epoch / silent model swaps.** `model-perf.md` recorded two silent swaps that "poisoned
   aggregates"; the roster-epoch discipline (grand-race.md §2) exists precisely because of it.
   Cross-epoch comparisons are uncounted.
10. **Grading is itself the measured skill, and the graders disagree.** Race F's grader stated
    ~70% doubt on its own load-bearing hinge; Race C's five scorers produced a flat 3/3 scale
    (scorer-1/2) that cannot rank, against scorer-4's discriminating 12/12. A race whose grader
    is weak measures the grader, not the lane.

---

## 6. The ladder the operator asked for — by task type, scope, capability

**Every cell carries its evidence tag: `measured` (mechanical or sealed-key blind) vs
`impression` vs `folklore`; its n; and its confounds.** All are provisional (n=1); none is a
rung (the wiggle-free bar — n ≥ 2 with grader agreement — is met by no cell). Where a cell would
hide its confounds, it is left blank with the reason, per the brief: *a ladder that hides its
confounds is worse than no ladder.*

### 6.1 By task type (the 8 operator types)

| task type | best-supported reading (n=1 each) | tag | n | confounds |
|---|---|---|---|---|
| **T-A audit** | flash 38 > dspro 34 > glm 30 > minimax 27 > kimi 25 (T447, opus-graded); opus 46 > sonnet 26 > haiku 0 (race1-rep, flash-graded) | measured | 1 each | grader mix (opus graded the DS field, flash graded the Claude field); no cost; thinking unrecorded (DS lanes) |
| **T-B implement** | flash 1st (diffrace T827, ratrace T839); sonnet 2nd (diffrace T828); ox-alpha mid; dspro 4th (diffrace T826 — closes an unrelated defect); glm qualified=false (ratrace T840) | measured (mechanical gates) | 1 | cost null; 2 no-shows per race (kimi/minimax) — a no-show is a fleet datum, not a quality datum |
| **T-C diagnosis** | no committed race result | — | 0 | unmeasured |
| **T-D bookkeeping** | Race C scorers: scorer-4 12/12 > scorer-3 10/12 > scorer-5 9/12 > scorer-1/2 8/12 (flat) | measured (vs grader ruling) | 1 | the *task* was premise-doubt (confound 6) |
| **T-E spec authoring** | Race I: opus (trunk) > flash > dspro > ox-alpha > sonnet — "ranks five documents, not five models" (T749); pass1-spec-r1 union, no ranking | measured (synthesis re-verification) | 1 | no cost; n=1 documents |
| **T-F adjudication** | Race G2: opus 25/25 status + 3/4 canaries > sonnet > dspro/flash (tie) > haiku 0/4 | measured (canary + status recall) | 1 | grader (dspro) shares model with one entrant (disclosed) |
| **T-G brief refresh / staleness** | Race G2/G-science: opus strongest (pareto-dominant, 100% precision); sonnet good recall, over-refutes; dspro/flash 100% precision / ~50–60% recall; haiku 0 flags | measured | 1 | cite-gap class vs dead-code class — two different sub-skills the rubric merged |
| **T-H sprint manager** | Race H: opus 1st > flash 2nd > dspro 3rd > haiku 4th > sonnet 5th | measured (KEY.json) | 1 | grader same-model-as-entrant (disclosed); key escape-hatch let one dodge through |

### 6.2 By task scope (size-class readings, where a race varied it)

The corpus barely varied scope — nearly every race was a bounded, single-file or single-document
task. The only scope-varied datum is **cost/wall** (T774 cost-repeatability, n=20 repeats, two
models — a repeatability finding, not a ranking). **Scope is unmeasured as a ladder dimension**:
no race ran the same subject at two scopes. Honest answer to "which model for which scope" —
*the corpus does not yet support a scope ladder.*

### 6.3 By capability (the cross-cutting axes)

| capability | best-supported reading | tag | n | confounds |
|---|---|---|---|---|
| **citation integrity / no fabrication** | qwen (T447) — "caught the one finding no API model caught, every citation verified" (goldilocks.md); opus (Race G2) re-derived artifact bytes, 100% precision on genuine defects | measured + impression | 1 | qwen wall-killed in most races (fleet, not quality); the confident-wrong-answer is symmetric — no model exempt |
| **investigative effort** | C3: glm 42 real paths (tied opus) vs haiku 14; minimax 45, opus 42, sonnet 35, dspro 34, flash 33, ox-alpha 36, kimi 19 | measured (mechanical) | 1 | — (this is the *new* dimension, T750) |
| **discernment** | C3: ox-alpha 0.96 > sonnet 0.95 > minimax 0.89 > opus 0.88 > dspro 0.77 > flash 0.63 > kimi 0.56 > haiku 0.17 ≈ glm 0.17 | measured (normalized entropy) | 1 | haiku = low effort AND no discernment; glm = high effort, no discernment — *different failures*, per the operator ruling |
| **premise-checking / re-checking one's own assignment** | Race X T808 (caught the subject moving mid-race); Race C scorer-4 (verified claims with its own commands) | impression (judge-noted, not scored) | 1 | no mechanical proxy yet |
| **code throughput** | separable from verification depth (goldilocks.md) | impression | — | wall_s is load-confounded (grand-race.md §3.4); no clean throughput reading |

**What the ladder does NOT say, and why it cannot yet:** no cost ordering (cost null); no
Claude-vs-DeepSeek cross-ordering that survives the thinking-level confound; no scope ladder; no
"established rung" anywhere. The only confident rungs from the whole corpus are the ones
`goldilocks.md` already claimed as extremes and that the races did not disturb: **Fable > Sonnet**
and the honest "the middle is NOT ranked."

---

## 7. Recommended metric set going forward

**Keep (already mechanical or near-mechanical):**

1. `citation_integrity_mech` — split from the panel score (methodology §6): paths/lines that do
   not exist or do not say what was claimed. Outranks panel. *This is the corpus's one proven
   discriminator.*
2. `verification_rate` = verified ÷ claims_load_bearing, with unchecked and refuted recorded
   separately.
3. Mechanical gate passage for `implement` (acceptance command sealed before dispatch) — diffrace
   and ratrace are the worked examples of how to do this right.

**Adopt (C3's two, mechanically computable, T750 folding in):**

4. **investigative effort** — distinct real paths named + median length of the "where I looked"
   field. Cheap, hard to game without doing work, and it separated haiku (didn't look) from glm
   (looked hard, then answered the same anyway).
5. **discernment** — normalized entropy of the verdict distribution. It is the *only* mechanical
   proxy yet found for "does the output vary with the input", and it caught the "everything is
   strictly re-runnable" non-classification that effort alone would have rewarded.

**Replace:**

- The **0–10 panel correctness score** should be demoted to a note wherever a mechanical anchor
  exists (canary-detection recall for audit/adjudication; gate passage for implement; the C3 pair
  for triage). Panel scores merged across graders (confound 3) are the corpus's most misused
  numbers.
- The **flat-3/3 scale** failure (Race C scorer-1/2) is the defect to design against: a rubric
  that cannot rank is a control that cannot fire. Require at least one discriminator per rubric.

**Still have no mechanical proxy — state them as gaps, don't fake them:**

- **correction work** ("fixed a wrong finding") — methodology §10 named it unmeasured; it still
  is. The one thing that moved the ladder (T557's B-3 retraction) has no column.
- **premise-checking** — the skill T808 showed (re-verify the assignment before answering) and
  Race C proved (the premise was false); no metric yet.
- **cost across families** — blocked on the token split (methodology §6(b)); until it lands, the
  cost ladder and the emission gate's "different cost" clause both stay uncomputable.

---

## 8. Which numbers here were verified how

Per the T899 brief's caution (the seat published two wrong corpus numbers on 2026-08-24 — one by
counting already-committed paths, one by a substring regex with no control), every number above
that came from pattern-matching was spot-checked against its primary source. The split:

- **Verified by direct read (not pattern matching):** the JSONL schema census in §3 (49 rows,
  `cost` null 49/49, `tier_emitted` absent 49/49, per-key null counts) — computed by parsing
  every row. The T447 scores (§6.1) — read from the result table in
  `T447-escape-sweep.md:51-59`, which states them directly. The union result (41/21/4) — read
  from three independent committed documents (§4).
- **Taken from a single committed findings file's own claim (spot-checked, not independently
  re-derived):** every per-race verdict in §1's table. Where two sources exist for one race and
  they disagree (T452's two graders; Race X's three graders), the disagreement is stated in the
  table rather than averaged.
- **Not re-derived here:** the C3 effort/discernment table (§6.3) — it is the operator's own
  ruling, recorded in the (volatile) `race-c3-sealed/OPERATOR-RULING.md`, and re-stated in
  `findings/T893-race-c3-adjudication.json`; the mechanical computation belongs to T893/T750, not
  this row. Flagged here as *single-source* for that reason.

Any number a reader plans to act on should be re-read from the cited `findings/*.json` before it
is dispatched — the standing rule (AGENTS.md "numbers cite their run") applies to this document
too, and this document is a census, not a re-run.

---

**Landmark:** advances `L1 (the dashboard tells the truth)` — what was 20+ unjoined race records
is now one enumerated corpus with its schema holes, its measurement/belief split, and its
confounds attached; and the honest headline is that **no tier has ever been emitted, and none
should be until `cost` stops being null and a cell reaches n ≥ 2 under one grader.** The two new
mechanical dimensions (effort, discernment) are the first capability readings that survive the
confounds, and they are the ones worth building the dashboard around.
