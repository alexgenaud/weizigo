# T554 — Pass-1 spec grading, round 1 analysis (key unsealed)

**Author:** claude-fable-5/T554 (fresh instance, grading analyst) · **Date:** 2026-08-20 ·
**Round id:** `pass1-spec-r1` · **Applies:** T553 ruling §5 (`02-fable-ruling.md`) + operator
additions 2026-08-20 · **Inputs:** the seven files in `grades/`, the sealed key, grand-race
§5–§6.

## 1 Seal check

sha256 of the key at
`/private/tmp/claude-501/…/scratchpad/T554-grading-key.json` =
`6ce50e8f4c559bdb0ab88e055835e32bb2a6cd1322d2dd1b256fa49cb11c50e5`, which **equals** the
committed seal in `docs/epics/E1-markovian/L1-dashboard/S01-process-ownership/pass1/grading/key.sha256` (sealed 2026-08-20 before
grader dispatch). The key is authentic; this analysis is the unsealing.

**Unsealed facts.** Authors: spec-A = deepseek-v4-flash · spec-B = claude-fable-5 · spec-C =
claude-opus-5 · spec-E = claude-sonnet-5 · spec-G = deepseek-v4-pro · spec-H =
claude-haiku-4-5-20251001. Controls: spec-D = the seeded weak document (seat-authored,
`SEEDED-WEAK:fable-T554`); spec-A/spec-F = the null near-duplicate pair (F duplicates A;
verified independently here — the two differ only in title word order, list/rule glyphs, and
sentence reshuffling, 23,004 vs 22,999 bytes). Eight documents, not nine: the qwen3.8:27b-mlx
spec lane was killed by the harness (0-byte output, memory-pressure cull at 116 s) — **no model
may be graded on that**. The key also records that blinding (G4) was imperfect: all six spec
lanes self-identified in the raw tournament outputs, redacted by the sanitizer. Uniform across
lanes, so it separates nobody; recorded as a G4 data point, not a per-model one.

## 2 Validity per grader (grand-race §5)

Rule: a round is invalid if the null-pair verdicts differ by more than one step, or the seeded
weak document lands in the top half (positions 1–4 of 8) of the ranking. Invalid rounds are
retained and analyzed, never counted.

| grader | A verdict | F verdict | null pass | D verdict | D rank pos | seeded pass | **round** |
|---|---|---|---|---|---|---|---|
| claude-fable-5 | great | great | ✓ (0 steps) | terrible | 8/8 | ✓ | **VALID** |
| claude-opus-5 | great | great | ✓ (0 steps) | terrible | 8/8 | ✓ | **VALID** |
| claude-sonnet-5 | great | great | ✓ (0 steps) | terrible | 8/8 | ✓ | **VALID** |
| claude-haiku-4-5-20251001 | great | great | ✓ (0 steps) | bad | 8/8 | ✓ | **VALID** |
| deepseek-v4-pro | great | great | ✓ (0 steps) | terrible | 8/8 | ✓ | **VALID** |
| deepseek-v4-flash | great | great | ✓ (0 steps) | terrible | 8/8 | ✓ | **VALID** |
| qwen3.8:27b-mlx | good | good | ✓ (0 steps) | terrible | 8/8 | ✓ | **VALID** |

**All seven rounds are valid.** Every grader ranked the seeded weak document dead last, and no
grader's null-pair verdicts differ at all.

Three validity-adjacent observations, none of which flips a verdict:

1. **claude-haiku passed the null control at verdict level but failed it at score level.** Six
   of seven graders explicitly detected that A≡F (several ran a diff) and scored them
   identically. Haiku alone treated them as independent documents, gave the identical pair
   different metric scores (mechanism 9 vs 10, economy 7 vs 5), ranked F strictly above A —
   and its spec-F justifications describe a *"two-verb (snapshot-tree, kill-tree)"* design
   that spec-F (a single-verb A-duplicate) does not contain; that is spec-E's architecture.
   The protocol's step-rule is verdict-based, so the round formally stands, but haiku's
   per-document attributions are partly scrambled and its scores should be read accordingly.
2. **claude-fable-5's grader file correctly guessed both control identities** (called A/F "a
   grader-consistency control" and D "a seeded-defect arm"). The brief forbade *author*
   guessing, not control detection; noted because a grader that names the controls is also a
   grader whose validity controls no longer test rubber-stamping this round.
3. **Instruction-following data points:** deepseek-v4-pro used `#` headers instead of the
   briefed `##` (converted mechanically at parse; the file itself is untouched);
   claude-fable-5 and deepseek-v4-flash added preamble prose outside the four briefed
   sections; qwen put its citation-verification notes in an HTML comment. All seven delivered
   the four sections parseable — the S5 fixed shape did its job.

## 3 Verdict aggregation, both ways

Verdict scale: terrible=1 … great=5. (a) counts only non-family graders (G3); (b) counts all
seven valid graders. spec-F is the null duplicate of spec-A — shown for completeness,
attributed to its one author as one document.

| doc (author) | (a) G3-excluded mean [n] | (b) all-valid mean [n] | (a) verdict | (b) verdict |
|---|---|---|---|---|
| spec-C (claude-opus-5) | 5.00 [3] | 5.00 [7] | great | great |
| spec-E (claude-sonnet-5) | 5.00 [3] | 4.71 [7] | great | great |
| spec-A ≡ F (deepseek-v4-flash) | 4.80 [5] | 4.86 [7] | great | great |
| spec-B (claude-fable-5) | 4.00 [3] | 4.00 [7] | good | good |
| spec-G (deepseek-v4-pro) | 4.00 [5] | 4.00 [7] | good | good |
| spec-H (claude-haiku-4-5-20251001) | 2.33 [3] | 2.43 [7] | bad | bad |
| spec-D (seeded control) | 1.00 [3] | 1.14 [7] | terrible | terrible |

**The two orderings differ in exactly one place: spec-E vs spec-A/F.** Under G3 exclusion, E
(5.00) edges A/F (4.80) and ties C at the top; with all graders counted, A/F (4.86) edges E
(4.71). The cause is precise: E's family graders — claude-fable-5 and claude-opus-5 — both
rated E "good" while every non-family grader rated it "great". So the exclusion was **not
costless** this round, and the direction is the opposite of the feared one: the family effect
on E is *negative* (family graders were harsher on a family-mate's document than outsiders
were). Everywhere else the two countings agree, including both coarse tiers and the identity
of top (C), middle (B, G), bottom (H), and control (D).

Ranking-line corroboration (mean rank position, counted graders): C 1.00 · A/F ≈3.1 · E 3.67 ·
G 4.70 · B 6.00 · H 7.00 · D 8.00. The verdict scale compresses C and E into a tie; the
ranking lines break it — six of seven graders (all but claude-fable-5, family, uncounted)
ranked C strictly first. Note the verdict-vs-ranking wrinkle for B and G: identical counted
verdict means (4.00) but clearly separated mean ranks (G 4.70 vs B 6.00) — the coarse scale
hides an ordering the mandatory ranking line preserves, which is exactly what the S3
half-adoption was for.

## 4 Bias statistics

`family_preference` = mean verdict given to own-family genuine documents − mean verdict those
same documents received from non-family graders. `self_preference_bias` (ruling §5.2) =
self-grade − mean non-family grade received. Verdict-scale units (1 step = 1.0). Controls
excluded.

| grader | family docs | family_preference | self doc | self_preference_bias |
|---|---|---|---|---|
| claude-fable-5 | B C E H | **−0.33** | B | 0.00 |
| claude-opus-5 | B C E H | **−0.33** | C | 0.00 |
| claude-sonnet-5 | B C E H | −0.08 | E | 0.00 |
| claude-haiku-4-5-20251001 | B C E H | **+0.42** | H | **+1.67** |
| deepseek-v4-pro | A/F G | +0.13 | G | 0.00 |
| deepseek-v4-flash | A/F G | +0.13 | A (and F) | +0.20 |
| qwen3.8:27b-mlx | — (no family docs) | n/a | — | n/a |

The one number that matters: **claude-haiku graded its own document "good" while every counted
grader said "bad" — a +1.67-step self-preference**, the only self-grade in the round that
departs from the field at all (deepseek-v4-flash's +0.2 is one grader-step ÷ 5 counted, i.e.
qwen's lone "good"). Fable's and opus's negative family numbers are driven by their shared
"good" on E and low H verdicts, i.e. by being *harsher* on family. **Low-N caveat, mandatory:**
each cell rests on 2–4 documents on a 5-step scale in one round; ±0.33 here is a single verdict
step on a single document. Only haiku's +1.67 exceeds what one honest disagreement could
produce, and even it is n=1 self-documents.

**S2 statistic (importance weights vs own-document strengths).** No discriminating signal this
round: all seven graders — including qwen, which has no document — chose nearly the same weight
profile (mechanism/testability/evidence 8–10 at the top, economy 5–7 at the bottom). Within
that uniformity the individual cases *anti-track* self-interest: claude-fable-5 put its top
weight (10) on mechanism-fidelity, its own document's counted-weakest axis, and its bottom
weight (7) on economy-honesty, its document's strongest; claude-sonnet-5 weighted
scoping-honesty — its own document's hallmark — at only 6. claude-opus-5's profile (economy
lowest at 7, its document's one weak axis) is the only one *consistent* with self-serving
weighting, but claude-haiku, whose document is short, downweighted economy even further (5),
which breaks that reading. Verdict: S2 is null at n=1 round; keep computing it as rounds
accumulate.

## 5 Spread findings (S4)

One document's counted verdicts span ≥2 steps: **spec-G (deepseek-v4-pro), average → great.**

- claude-opus-5, *average*: "disciplined and well-cited, then **argues a required call site is
  impossible** on the strength of its own primitive's limit, and never once mentions cross-uid
  processes in a tool that kills."
- qwen3.8:27b-mlx, *great*: "the most epistemically honest: ownership is the *captured* set,
  not the *claimed* tree, which **turns the un-reapable normal-exit orphan into a named T548
  boundary instead of a false 'killed 0' success**."

The divergence is substantive, not noise: the panel disagrees on whether G's descoping of the
normal-exit orphan to T548 is honest boundary-drawing (qwen, and partially deepseek-v4-flash)
or an analytical error, since the sid-based enumeration in A/F reaches exactly that case
(opus, fable, sonnet in milder form). That is a question about the *artifact*, answerable at
synthesis time: if the sid route works as A/F and C describe, opus's reading is right and G
descoped a solvable case.

Two retained-not-counted spreads worth the consolidator's eye: (1) spec-H spans bad → good
across all valid graders, but the "good" is haiku's self-grade (§4); counted span is one step.
(2) spec-C is unanimous "great" among counted graders, but family grader claude-fable-5
(retained, uncounted) makes a concrete technical claim against it — "its verb exits 3 doing
nothing on a dead anchor, silently no-op'ing on the recurring normal-exit leak" — which is
checkable against the document and should be adjudicated during synthesis, not lost to G3.

## 6 Metric analysis

Clusters, recurrence, and dispersion. Dispersion = does the metric separate the six genuine
documents (D excluded — the seeded control makes every metric look discriminating; F folded
into A)? Figures are mean per-proposer standard deviation of scores across the six genuine
documents.

| cluster (proposers) | recurrence | dispersion (sd) | tag | discriminative rank |
|---|---|---|---|---|
| evidence/citation integrity (opus, sonnet, ds-pro, ds-flash, qwen) | 5/7 | ≈2.3 | scalar | **1** |
| uncertainty/scoping honesty (sonnet, ds-flash) | 2/7 | ≈2.5 | scalar | **2** (highest sd, low recurrence) |
| mechanism-fidelity (fable, opus, haiku, ds-pro, ds-flash, qwen) | 6/7 | ≈2.0 | scalar | 3 |
| safety-with-controls (all seven) | 7/7 | ≈2.0 | scalar | 4 |
| testable-ownership / testability (all seven) | 7/7 | ≈1.9 | scalar | 5 |
| controls-rigor (fable, opus, haiku) | 3/7 | ≈1.8 | scalar | 6 |
| cannibalization (fable, opus, sonnet, ds-pro, ds-flash, qwen) | 6/7 | ≈1.6 | scalar | 7 |
| per-family check (sonnet, haiku, ds-pro, qwen) | 4/7 | ≈1.6 | scalar | 8 |
| contract-completeness (fable, haiku) | 2/7 | ≈1.4 | scalar | 9 |
| economy (all seven, under five names) | 7/7 | ≈1.3 | **polar** | 10 |

Readings, ranked by power rather than popularity:

- **Evidence/citation integrity is the round's best metric and not its most popular.** It is
  what actually separates the upper tier: B's load-bearing unmeasured claim earns 4–6 where
  A/C/E earn 9–10, and H's fabricated `tools/console.zig` earns 2–3. It also produced the
  round's only cross-grader *measurement* dispute (opus scored G's citations 6, sonnet 8,
  ds-pro-as-author aside). claude-haiku is the only grader without a metric in this cluster —
  and also the grader with the scrambled attributions (§2).
- **Uncertainty/scoping-honesty has the highest raw dispersion (≈2.5) with only two
  proposers** — a discovered dimension candidate if it recurs next round. It is also the axis
  under the spec-G spread (§5): scored as a metric it rewards G; folded into other metrics it
  punishes G.
- **The 7/7 clusters (safety, testability, economy) mostly re-detect the bottom of the field.**
  Among the four strong documents they compress to 8–10 — high recurrence, moderate power.
- **Everything does *not* score 8–9**: the weakest cluster still shows sd ≈1.3. But strip H
  and the compression is real — most scalar metrics barely separate A/C/E/G. The two clusters
  that still do are the two at the top of this table.
- **Economy is polar** (verbose↔concise; both extremes were defended). Grader disagreement
  here is about the metric, not the documents — haiku scored the seeded control's brevity 9
  where five graders gave 2–4 ("short-and-wrong is not economy"). Observed AUTHOR positions,
  not grades: claude-opus-5 most verbose (27.0 KB, substance-dense); deepseek-v4-flash
  long-dense (23.0 KB, citation-heavy); claude-sonnet-5 long-discursive (20.5 KB);
  deepseek-v4-pro mid-tight (17.7 KB); claude-fable-5 concise (14.9 KB — "highest
  substance-per-byte" per two graders); claude-haiku-4-5 shortest (11.9 KB, brevity read by
  the panel as missing content).
- Vocabulary hygiene: fable's `economy-honesty` and opus's `economy-and-honesty` blend polar
  economy with scalar uncertainty-honesty; recorded in the vocabulary with a suggestion to
  split (see `docs/infra/races/metric-vocabulary.md`).

## 7 Per-model grades for the ledger

Derived from counted (non-family) verdicts; spec-A/F attributed as one document to
deepseek-v4-flash; qwen3.8:27b-mlx receives **no grade** (its lane was harness-killed — a
completion-reliability datum for the fleet, not a quality datum for the model).

| model | document | grade | nuance (one sentence) |
|---|---|---|---|
| claude-opus-5 | spec-C | **great** | Only lane that ran its own measurements — corroborating the escape chain, measuring the negative that refutes the token design, and catching the call site the brief itself omitted — at the cost of being the longest document, with one uncounted family critique (a possible dead-anchor no-op) owed adjudication at synthesis. |
| claude-sonnet-5 | spec-E | **great** | The field's sharpest single insight — the root is often already dead when the kill is called — drove the one genuinely different architecture, though the post-snapshot fork window is left unbounded. |
| deepseek-v4-flash | spec-A (≡F) | **great** | The sid==root-pid catch-all closes the dead-root leak with zero spawn change and every guard, arm, and deletion pinned to a checkable line; docked only for no instrument-mutation layer and for leaving the host-guard cull line in place. |
| claude-fable-5 | spec-B | **good** | The most original mechanism and the tightest prose in the field, but its load-bearing claim — that another process's environment is readable — was asserted unmeasured, and a rival lane measured it false on this host. |
| deepseek-v4-pro | spec-G | **good** | Disciplined, well-cited, and honest about its reach limit; the panel genuinely split (average→great) on whether descoping the normal-exit orphan to T548 was honest boundary-drawing or an error the sid design disproves. |
| claude-haiku-4-5-20251001 | spec-H | **bad** | Cited a file that does not exist, revived the reserved verb name `reap`, and defined ownership so the measured leak counts as success — the fabricated-citation finding is mechanical, not panel opinion. |

**Confidence labels (ruling §5.4).** The Claude-vs-Claude ordering (C = E > B > H) rests on
three countable graders and is **low-confidence** — presented as a panel reading, not a
finding. Partial exception: H's "bad" is corroborated by mechanically checkable facts (the
nonexistent `tools/console.zig`, the `reap` name collision), so it is sturdier than its n=3
suggests. Cross-family comparisons (A/F and G, five counted graders each) are the round's
most trustworthy panel numbers, and even they are n=1 documents per model.

## 8 Vocabulary

Created `docs/infra/races/metric-vocabulary.md` (T553 ruling §4): all 49 proposed metrics
(name, one-line definition, proposer, importance, scalar/polar tag), grouped into the ten
clusters of §6, under round id `pass1-spec-r1`, task type `design/spec`. Suggestions for
future rounds, never a required schema.

## 9 Ledger

Grand-race §6 defines the grade-record schema for `docs/infra/races/grand-race-ledger.jsonl`
and requires records be **written by the harness, never by hand**. No harness tooling for
grade records exists yet (the 71 existing ledger lines are all lane records; nothing in
`tools/`, `bin/`, or `src/` references the ledger). Accordingly, per instruction, the exact
append lines are given below and the ledger file itself is **not** hand-edited. 56 records:
7 graders × 8 documents, `scores` carrying each grader's own metric names verbatim, `total` =
sum of metric scores, plus `verdict`, `rank_pos`, `author`, and the §5/§6 control and family
flags. Generated mechanically by parsing the grade files (parser tolerated deepseek-v4-pro's
`#` headers); when append tooling lands (G5/T542 line), these lines are ready to feed it.

```jsonl
{"artifact": "spec-A", "author": "deepseek-v4-flash", "epoch_date": "2026-08-20b", "grader": "claude-fable-5", "is_family": false, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 1.5, "scores": {"cannibalization-precision": 9, "contract-completeness": 9, "controls-rigor": 9, "economy-honesty": 9, "mechanism-fidelity": 10, "safety-with-controls": 9, "testable-ownership": 9}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 64, "verdict": "great"}
{"artifact": "spec-B", "author": "claude-fable-5", "epoch_date": "2026-08-20b", "grader": "claude-fable-5", "is_family": true, "is_self": true, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 5.5, "scores": {"cannibalization-precision": 8, "contract-completeness": 8, "controls-rigor": 7, "economy-honesty": 9, "mechanism-fidelity": 6, "safety-with-controls": 8, "testable-ownership": 8}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 54, "verdict": "good"}
{"artifact": "spec-C", "author": "claude-opus-5", "epoch_date": "2026-08-20b", "grader": "claude-fable-5", "is_family": true, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 3.0, "scores": {"cannibalization-precision": 10, "contract-completeness": 9, "controls-rigor": 10, "economy-honesty": 8, "mechanism-fidelity": 6, "safety-with-controls": 10, "testable-ownership": 9}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 62, "verdict": "great"}
{"artifact": "spec-D", "author": "SEEDED-WEAK:fable-T554", "epoch_date": "2026-08-20b", "grader": "claude-fable-5", "is_family": true, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 8.0, "scores": {"cannibalization-precision": 1, "contract-completeness": 2, "controls-rigor": 1, "economy-honesty": 2, "mechanism-fidelity": 0, "safety-with-controls": 1, "testable-ownership": 1}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 8, "verdict": "terrible"}
{"artifact": "spec-E", "author": "claude-sonnet-5", "epoch_date": "2026-08-20b", "grader": "claude-fable-5", "is_family": true, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 4.0, "scores": {"cannibalization-precision": 8, "contract-completeness": 9, "controls-rigor": 8, "economy-honesty": 9, "mechanism-fidelity": 8, "safety-with-controls": 8, "testable-ownership": 9}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 59, "verdict": "good"}
{"artifact": "spec-F", "author": "NULL-DUP:deepseek-v4-flash", "epoch_date": "2026-08-20b", "grader": "claude-fable-5", "is_family": false, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 1.5, "scores": {"cannibalization-precision": 9, "contract-completeness": 9, "controls-rigor": 9, "economy-honesty": 9, "mechanism-fidelity": 10, "safety-with-controls": 9, "testable-ownership": 9}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 64, "verdict": "great"}
{"artifact": "spec-G", "author": "deepseek-v4-pro", "epoch_date": "2026-08-20b", "grader": "claude-fable-5", "is_family": false, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 5.5, "scores": {"cannibalization-precision": 8, "contract-completeness": 8, "controls-rigor": 8, "economy-honesty": 8, "mechanism-fidelity": 6, "safety-with-controls": 8, "testable-ownership": 8}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 54, "verdict": "good"}
{"artifact": "spec-H", "author": "claude-haiku-4-5-20251001", "epoch_date": "2026-08-20b", "grader": "claude-fable-5", "is_family": true, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 7.0, "scores": {"cannibalization-precision": 4, "contract-completeness": 4, "controls-rigor": 4, "economy-honesty": 4, "mechanism-fidelity": 3, "safety-with-controls": 4, "testable-ownership": 3}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 26, "verdict": "bad"}
{"artifact": "spec-A", "author": "deepseek-v4-flash", "epoch_date": "2026-08-20b", "grader": "claude-haiku-4-5-20251001", "is_family": false, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 4.0, "scores": {"contract-precision": 10, "controls-substantiveness": 9, "economy": 7, "mechanism-correctness": 9, "owned-definition": 10, "per-family-rigor": 9, "safety-completeness": 9}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 63, "verdict": "great"}
{"artifact": "spec-B", "author": "claude-fable-5", "epoch_date": "2026-08-20b", "grader": "claude-haiku-4-5-20251001", "is_family": true, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 6.0, "scores": {"contract-precision": 8, "controls-substantiveness": 6, "economy": 6, "mechanism-correctness": 6, "owned-definition": 7, "per-family-rigor": 7, "safety-completeness": 7}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 47, "verdict": "good"}
{"artifact": "spec-C", "author": "claude-opus-5", "epoch_date": "2026-08-20b", "grader": "claude-haiku-4-5-20251001", "is_family": true, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 1.0, "scores": {"contract-precision": 10, "controls-substantiveness": 9, "economy": 5, "mechanism-correctness": 9, "owned-definition": 10, "per-family-rigor": 9, "safety-completeness": 10}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 62, "verdict": "great"}
{"artifact": "spec-D", "author": "SEEDED-WEAK:fable-T554", "epoch_date": "2026-08-20b", "grader": "claude-haiku-4-5-20251001", "is_family": true, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 8.0, "scores": {"contract-precision": 5, "controls-substantiveness": 2, "economy": 9, "mechanism-correctness": 3, "owned-definition": 4, "per-family-rigor": 1, "safety-completeness": 3}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 27, "verdict": "bad"}
{"artifact": "spec-E", "author": "claude-sonnet-5", "epoch_date": "2026-08-20b", "grader": "claude-haiku-4-5-20251001", "is_family": true, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 2.0, "scores": {"contract-precision": 9, "controls-substantiveness": 9, "economy": 6, "mechanism-correctness": 10, "owned-definition": 10, "per-family-rigor": 9, "safety-completeness": 9}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 62, "verdict": "great"}
{"artifact": "spec-F", "author": "NULL-DUP:deepseek-v4-flash", "epoch_date": "2026-08-20b", "grader": "claude-haiku-4-5-20251001", "is_family": false, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 3.0, "scores": {"contract-precision": 9, "controls-substantiveness": 9, "economy": 5, "mechanism-correctness": 10, "owned-definition": 10, "per-family-rigor": 9, "safety-completeness": 9}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 61, "verdict": "great"}
{"artifact": "spec-G", "author": "deepseek-v4-pro", "epoch_date": "2026-08-20b", "grader": "claude-haiku-4-5-20251001", "is_family": false, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 5.0, "scores": {"contract-precision": 8, "controls-substantiveness": 8, "economy": 7, "mechanism-correctness": 9, "owned-definition": 9, "per-family-rigor": 8, "safety-completeness": 8}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 57, "verdict": "good"}
{"artifact": "spec-H", "author": "claude-haiku-4-5-20251001", "epoch_date": "2026-08-20b", "grader": "claude-haiku-4-5-20251001", "is_family": true, "is_self": true, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 7.0, "scores": {"contract-precision": 7, "controls-substantiveness": 6, "economy": 8, "mechanism-correctness": 7, "owned-definition": 7, "per-family-rigor": 4, "safety-completeness": 7}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 46, "verdict": "good"}
{"artifact": "spec-A", "author": "deepseek-v4-flash", "epoch_date": "2026-08-20b", "grader": "claude-opus-5", "is_family": false, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 2.5, "scores": {"cannibalization-completeness": 8, "citation-integrity": 9, "control-design": 8, "economy-and-honesty": 8, "mechanism-fidelity": 9, "safety-specification": 9, "testable-ownership-predicate": 9}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 60, "verdict": "great"}
{"artifact": "spec-B", "author": "claude-fable-5", "epoch_date": "2026-08-20b", "grader": "claude-opus-5", "is_family": true, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 4.0, "scores": {"cannibalization-completeness": 9, "citation-integrity": 6, "control-design": 8, "economy-and-honesty": 9, "mechanism-fidelity": 7, "safety-specification": 9, "testable-ownership-predicate": 9}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 57, "verdict": "good"}
{"artifact": "spec-C", "author": "claude-opus-5", "epoch_date": "2026-08-20b", "grader": "claude-opus-5", "is_family": true, "is_self": true, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 1.0, "scores": {"cannibalization-completeness": 10, "citation-integrity": 10, "control-design": 10, "economy-and-honesty": 7, "mechanism-fidelity": 10, "safety-specification": 10, "testable-ownership-predicate": 10}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 67, "verdict": "great"}
{"artifact": "spec-D", "author": "SEEDED-WEAK:fable-T554", "epoch_date": "2026-08-20b", "grader": "claude-opus-5", "is_family": true, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 8.0, "scores": {"cannibalization-completeness": 1, "citation-integrity": 0, "control-design": 1, "economy-and-honesty": 2, "mechanism-fidelity": 0, "safety-specification": 0, "testable-ownership-predicate": 1}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 5, "verdict": "terrible"}
{"artifact": "spec-E", "author": "claude-sonnet-5", "epoch_date": "2026-08-20b", "grader": "claude-opus-5", "is_family": true, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 5.0, "scores": {"cannibalization-completeness": 7, "citation-integrity": 9, "control-design": 8, "economy-and-honesty": 6, "mechanism-fidelity": 8, "safety-specification": 9, "testable-ownership-predicate": 9}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 56, "verdict": "good"}
{"artifact": "spec-F", "author": "NULL-DUP:deepseek-v4-flash", "epoch_date": "2026-08-20b", "grader": "claude-opus-5", "is_family": false, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 2.5, "scores": {}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 0, "verdict": "great"}
{"artifact": "spec-G", "author": "deepseek-v4-pro", "epoch_date": "2026-08-20b", "grader": "claude-opus-5", "is_family": false, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 6.0, "scores": {"cannibalization-completeness": 8, "citation-integrity": 9, "control-design": 8, "economy-and-honesty": 7, "mechanism-fidelity": 6, "safety-specification": 7, "testable-ownership-predicate": 7}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 52, "verdict": "average"}
{"artifact": "spec-H", "author": "claude-haiku-4-5-20251001", "epoch_date": "2026-08-20b", "grader": "claude-opus-5", "is_family": true, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 7.0, "scores": {"cannibalization-completeness": 5, "citation-integrity": 2, "control-design": 3, "economy-and-honesty": 4, "mechanism-fidelity": 3, "safety-specification": 3, "testable-ownership-predicate": 2}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 22, "verdict": "bad"}
{"artifact": "spec-A", "author": "deepseek-v4-flash", "epoch_date": "2026-08-20b", "grader": "claude-sonnet-5", "is_family": false, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 3.5, "scores": {"cannibalization-completeness": 9, "economy-vs-padding": 8, "evidence-citation-rigor": 9, "per-family-generality": 9, "safety-guard-controls": 9, "scoping-honesty": 9, "testable-ownership-definition": 9}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 62, "verdict": "great"}
{"artifact": "spec-B", "author": "claude-fable-5", "epoch_date": "2026-08-20b", "grader": "claude-sonnet-5", "is_family": true, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 6.0, "scores": {"cannibalization-completeness": 8, "economy-vs-padding": 8, "evidence-citation-rigor": 4, "per-family-generality": 8, "safety-guard-controls": 7, "scoping-honesty": 5, "testable-ownership-definition": 7}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 47, "verdict": "good"}
{"artifact": "spec-C", "author": "claude-opus-5", "epoch_date": "2026-08-20b", "grader": "claude-sonnet-5", "is_family": true, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 1.0, "scores": {"cannibalization-completeness": 10, "economy-vs-padding": 7, "evidence-citation-rigor": 10, "per-family-generality": 9, "safety-guard-controls": 10, "scoping-honesty": 10, "testable-ownership-definition": 9}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 65, "verdict": "great"}
{"artifact": "spec-D", "author": "SEEDED-WEAK:fable-T554", "epoch_date": "2026-08-20b", "grader": "claude-sonnet-5", "is_family": true, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 8.0, "scores": {"cannibalization-completeness": 1, "economy-vs-padding": 2, "evidence-citation-rigor": 1, "per-family-generality": 0, "safety-guard-controls": 0, "scoping-honesty": 1, "testable-ownership-definition": 1}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 6, "verdict": "terrible"}
{"artifact": "spec-E", "author": "claude-sonnet-5", "epoch_date": "2026-08-20b", "grader": "claude-sonnet-5", "is_family": true, "is_self": true, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 2.0, "scores": {"cannibalization-completeness": 9, "economy-vs-padding": 8, "evidence-citation-rigor": 10, "per-family-generality": 9, "safety-guard-controls": 9, "scoping-honesty": 9, "testable-ownership-definition": 9}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 63, "verdict": "great"}
{"artifact": "spec-F", "author": "NULL-DUP:deepseek-v4-flash", "epoch_date": "2026-08-20b", "grader": "claude-sonnet-5", "is_family": false, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 3.5, "scores": {"cannibalization-completeness": 9, "economy-vs-padding": 8, "evidence-citation-rigor": 9, "per-family-generality": 9, "safety-guard-controls": 9, "scoping-honesty": 9, "testable-ownership-definition": 9}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 62, "verdict": "great"}
{"artifact": "spec-G", "author": "deepseek-v4-pro", "epoch_date": "2026-08-20b", "grader": "claude-sonnet-5", "is_family": false, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 5.0, "scores": {"cannibalization-completeness": 7, "economy-vs-padding": 8, "evidence-citation-rigor": 8, "per-family-generality": 8, "safety-guard-controls": 8, "scoping-honesty": 9, "testable-ownership-definition": 7}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 55, "verdict": "good"}
{"artifact": "spec-H", "author": "claude-haiku-4-5-20251001", "epoch_date": "2026-08-20b", "grader": "claude-sonnet-5", "is_family": true, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 7.0, "scores": {"cannibalization-completeness": 5, "economy-vs-padding": 4, "evidence-citation-rigor": 3, "per-family-generality": 5, "safety-guard-controls": 4, "scoping-honesty": 3, "testable-ownership-definition": 5}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 29, "verdict": "bad"}
{"artifact": "spec-A", "author": "deepseek-v4-flash", "epoch_date": "2026-08-20b", "grader": "deepseek-v4-flash", "is_family": true, "is_self": true, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 2.5, "scores": {"cannibalization-completeness": 8, "economy": 8, "evidence-correctness": 9, "mechanism-fit": 9, "safety-guards": 9, "testability": 9, "uncertainty-honesty": 9}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 61, "verdict": "great"}
{"artifact": "spec-B", "author": "claude-fable-5", "epoch_date": "2026-08-20b", "grader": "deepseek-v4-flash", "is_family": false, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 6.0, "scores": {"cannibalization-completeness": 8, "economy": 7, "evidence-correctness": 6, "mechanism-fit": 7, "safety-guards": 8, "testability": 8, "uncertainty-honesty": 6}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 50, "verdict": "good"}
{"artifact": "spec-C", "author": "claude-opus-5", "epoch_date": "2026-08-20b", "grader": "deepseek-v4-flash", "is_family": false, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 1.0, "scores": {"cannibalization-completeness": 10, "economy": 7, "evidence-correctness": 10, "mechanism-fit": 9, "safety-guards": 10, "testability": 10, "uncertainty-honesty": 9}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 65, "verdict": "great"}
{"artifact": "spec-D", "author": "SEEDED-WEAK:fable-T554", "epoch_date": "2026-08-20b", "grader": "deepseek-v4-flash", "is_family": false, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 8.0, "scores": {"cannibalization-completeness": 1, "economy": 4, "evidence-correctness": 1, "mechanism-fit": 0, "safety-guards": 1, "testability": 1, "uncertainty-honesty": 0}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 8, "verdict": "terrible"}
{"artifact": "spec-E", "author": "claude-sonnet-5", "epoch_date": "2026-08-20b", "grader": "deepseek-v4-flash", "is_family": false, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 4.0, "scores": {"cannibalization-completeness": 8, "economy": 8, "evidence-correctness": 9, "mechanism-fit": 9, "safety-guards": 9, "testability": 9, "uncertainty-honesty": 10}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 62, "verdict": "great"}
{"artifact": "spec-F", "author": "NULL-DUP:deepseek-v4-flash", "epoch_date": "2026-08-20b", "grader": "deepseek-v4-flash", "is_family": true, "is_self": true, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 2.5, "scores": {"cannibalization-completeness": 8, "economy": 8, "evidence-correctness": 9, "mechanism-fit": 9, "safety-guards": 9, "testability": 9, "uncertainty-honesty": 9}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 61, "verdict": "great"}
{"artifact": "spec-G", "author": "deepseek-v4-pro", "epoch_date": "2026-08-20b", "grader": "deepseek-v4-flash", "is_family": true, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 5.0, "scores": {"cannibalization-completeness": 9, "economy": 8, "evidence-correctness": 9, "mechanism-fit": 9, "safety-guards": 9, "testability": 9, "uncertainty-honesty": 9}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 62, "verdict": "good"}
{"artifact": "spec-H", "author": "claude-haiku-4-5-20251001", "epoch_date": "2026-08-20b", "grader": "deepseek-v4-flash", "is_family": false, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 7.0, "scores": {"cannibalization-completeness": 5, "economy": 5, "evidence-correctness": 4, "mechanism-fit": 4, "safety-guards": 4, "testability": 4, "uncertainty-honesty": 3}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 29, "verdict": "bad"}
{"artifact": "spec-A", "author": "deepseek-v4-flash", "epoch_date": "2026-08-20b", "grader": "deepseek-v4-pro", "is_family": true, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 2.5, "scores": {"builds-on-mechanism": 9, "cannibalization": 8, "citation-accuracy": 9, "economy": 7, "per-family-check": 9, "safety": 9, "testability": 9}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 60, "verdict": "great"}
{"artifact": "spec-B", "author": "claude-fable-5", "epoch_date": "2026-08-20b", "grader": "deepseek-v4-pro", "is_family": false, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 6.0, "scores": {"builds-on-mechanism": 6, "cannibalization": 8, "citation-accuracy": 7, "economy": 7, "per-family-check": 7, "safety": 8, "testability": 8}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 51, "verdict": "good"}
{"artifact": "spec-C", "author": "claude-opus-5", "epoch_date": "2026-08-20b", "grader": "deepseek-v4-pro", "is_family": false, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 1.0, "scores": {"builds-on-mechanism": 9, "cannibalization": 9, "citation-accuracy": 9, "economy": 6, "per-family-check": 9, "safety": 10, "testability": 10}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 62, "verdict": "great"}
{"artifact": "spec-D", "author": "SEEDED-WEAK:fable-T554", "epoch_date": "2026-08-20b", "grader": "deepseek-v4-pro", "is_family": false, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 8.0, "scores": {"builds-on-mechanism": 1, "cannibalization": 2, "citation-accuracy": 1, "economy": 4, "per-family-check": 1, "safety": 2, "testability": 1}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 12, "verdict": "terrible"}
{"artifact": "spec-E", "author": "claude-sonnet-5", "epoch_date": "2026-08-20b", "grader": "deepseek-v4-pro", "is_family": false, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 4.0, "scores": {"builds-on-mechanism": 8, "cannibalization": 8, "citation-accuracy": 8, "economy": 8, "per-family-check": 8, "safety": 8, "testability": 9}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 57, "verdict": "great"}
{"artifact": "spec-F", "author": "NULL-DUP:deepseek-v4-flash", "epoch_date": "2026-08-20b", "grader": "deepseek-v4-pro", "is_family": true, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 2.5, "scores": {"builds-on-mechanism": 9, "cannibalization": 8, "citation-accuracy": 9, "economy": 7, "per-family-check": 9, "safety": 9, "testability": 9}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 60, "verdict": "great"}
{"artifact": "spec-G", "author": "deepseek-v4-pro", "epoch_date": "2026-08-20b", "grader": "deepseek-v4-pro", "is_family": true, "is_self": true, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 5.0, "scores": {"builds-on-mechanism": 7, "cannibalization": 8, "citation-accuracy": 6, "economy": 7, "per-family-check": 7, "safety": 8, "testability": 8}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 51, "verdict": "good"}
{"artifact": "spec-H", "author": "claude-haiku-4-5-20251001", "epoch_date": "2026-08-20b", "grader": "deepseek-v4-pro", "is_family": false, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 7.0, "scores": {"builds-on-mechanism": 2, "cannibalization": 4, "citation-accuracy": 3, "economy": 3, "per-family-check": 4, "safety": 2, "testability": 3}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 21, "verdict": "bad"}
{"artifact": "spec-A", "author": "deepseek-v4-flash", "epoch_date": "2026-08-20b", "grader": "qwen3.8:27b-mlx", "is_family": false, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 4.5, "scores": {"cannibalization": 7, "economy": 7, "evidence-and-citation": 7, "mechanism-correctness": 8, "per-family-residual": 7, "safety-quality": 8, "testability": 7}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 51, "verdict": "good"}
{"artifact": "spec-B", "author": "claude-fable-5", "epoch_date": "2026-08-20b", "grader": "qwen3.8:27b-mlx", "is_family": false, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 6.0, "scores": {"cannibalization": 7, "economy": 5, "evidence-and-citation": 7, "mechanism-correctness": 7, "per-family-residual": 7, "safety-quality": 7, "testability": 8}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 48, "verdict": "good"}
{"artifact": "spec-C", "author": "claude-opus-5", "epoch_date": "2026-08-20b", "grader": "qwen3.8:27b-mlx", "is_family": false, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 1.0, "scores": {"cannibalization": 9, "economy": 6, "evidence-and-citation": 9, "mechanism-correctness": 9, "per-family-residual": 8, "safety-quality": 9, "testability": 9}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 59, "verdict": "great"}
{"artifact": "spec-D", "author": "SEEDED-WEAK:fable-T554", "epoch_date": "2026-08-20b", "grader": "qwen3.8:27b-mlx", "is_family": false, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 8.0, "scores": {"cannibalization": 1, "economy": 3, "evidence-and-citation": 1, "mechanism-correctness": 1, "per-family-residual": 1, "safety-quality": 1, "testability": 1}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 9, "verdict": "terrible"}
{"artifact": "spec-E", "author": "claude-sonnet-5", "epoch_date": "2026-08-20b", "grader": "qwen3.8:27b-mlx", "is_family": false, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 3.0, "scores": {"cannibalization": 8, "economy": 7, "evidence-and-citation": 8, "mechanism-correctness": 9, "per-family-residual": 7, "safety-quality": 8, "testability": 8}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 55, "verdict": "great"}
{"artifact": "spec-F", "author": "NULL-DUP:deepseek-v4-flash", "epoch_date": "2026-08-20b", "grader": "qwen3.8:27b-mlx", "is_family": false, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 4.5, "scores": {"cannibalization": 7, "economy": 7, "evidence-and-citation": 7, "mechanism-correctness": 8, "per-family-residual": 7, "safety-quality": 8, "testability": 7}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 51, "verdict": "good"}
{"artifact": "spec-G", "author": "deepseek-v4-pro", "epoch_date": "2026-08-20b", "grader": "qwen3.8:27b-mlx", "is_family": false, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 2.0, "scores": {"cannibalization": 8, "economy": 8, "evidence-and-citation": 8, "mechanism-correctness": 8, "per-family-residual": 8, "safety-quality": 8, "testability": 9}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 57, "verdict": "great"}
{"artifact": "spec-H", "author": "claude-haiku-4-5-20251001", "epoch_date": "2026-08-20b", "grader": "qwen3.8:27b-mlx", "is_family": false, "is_self": false, "null_ctrl_pass": true, "phase": "grading-r1", "race": "orcha-refactor-pass1-spec", "rank_pos": 7.0, "scores": {"cannibalization": 5, "economy": 3, "evidence-and-citation": 3, "mechanism-correctness": 4, "per-family-residual": 4, "safety-quality": 3, "testability": 5}, "seeded_ctrl_pass": true, "task_id": "T554", "total": 27, "verdict": "average"}
```
