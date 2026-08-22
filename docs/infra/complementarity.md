# Portfolio complementarity — standing record (T661)

**Landmark:** L1. First real portfolio data. Replaces the labelled guess behind panel
selection (T636) with a measured complementarity record for two complete five-lane races:
**Race G (claim-doubt)** and **Race C (discernment-scoring)**, both all-grade-all, epoch
2026-08-22.

**Produced by:** deepseek-v4-flash/T661, 2026-08-22, from the committed race artifacts
(listed below). Machine-readable record: `tools/complementarity-record.json` (reduced by
`tools/complementarity.py`, T637); race inputs under `tools/complementarity-inputs/`.

> **Union coverage is coverage of the union we found, never of the truth.** Every coverage
> fraction below is over *n*, the graded reference union this run was given. A finding all
> five lanes missed is invisible here, and a reader who forgets that will over-trust a 92%
> figure. For Race G the union is the 25 sealed claims; for Race C it is the 12 graded
> inputs. Nothing here claims to cover the truth — only the union the graders agreed on.

---

## 1. Inputs, census, and what was excluded

| race | union (n) | lanes (findings) | grades | attribution key |
|---|---|---|---|---|
| G | 25 claims G01..G25 | `findings/T63{8,9}-race-g.json`, `findings/T64{0,1,2}-race-g.json` | `findings/T64{4,5,6,7,8}-race-g-grade.json` (five independent graders) + Fable's `findings/T649-grader-fairness.json` (context) | `untracked/race-grading/race-g/KEY.json` |
| C | 12 inputs, 2 sealed null controls | `findings/T62{0,1,2,3,4}-race-c.json` | `findings/T65{4,5,6,7,8}-race-c-grade.json` | `untracked/race-grading/race-c-grade/KEY.json` |

**Census (ruling 32 gate) — 3 rows killed and salvaged across the two races, all present
and scored; skip count 3, none skipped:**
- **T638** (Race G lane-5, deepseek-v4-flash) — watchdog kill, artifact complete (25/25 verdicts), scored.
- **T641** (Race G lane-2, claude-sonnet-5) — protocol kill, artifact complete (25/25 verdicts), scored.
- **T654** (Race C grader-1, claude-opus-5) — provider-limit kill, grade complete (12/12 matrix), scored.

Their artifacts count as work and are included everywhere below. No published figure here
hides a guard-killed row.

**Excluded from the rates: 3 Race C inputs, verdict `uncertain`** — see §4. Every other
union item is `real` and rates are over n = 25 (G) and n = 9 (C).

**Costs** are reported per lane and per best-subset, never blended with rates (ruling 35).
Deepseek lanes (T639, T638 in G; T623, T624 in C) have no structured usage in
`untracked/tokens/tokens.jsonl` — stated unknown, never guessed.

---

## 2. Method and decision rules (stated, so they can be argued with)

**Keying normalization (the brief's watch-the-keying warning).** Race G's lanes used two
schemes: batch labels `G01`…`G25` (T638, T642) and register claim IDs (T639, T640, T641).
Normalized onto the batch labels via the crosswalk carried by **T638**, the one lane that
has both (`G01 → GLOBAL.H1-MARKOV`, … `G25 → QA-022`). **Keys remapped per lane: 25 for
each of T639/T640/T641; 0 for T638/T642.** Verified before the join: all five lanes' target
sets are the same 25 claims (register sets exactly equal the target; G-label sets identical
to T638's). A naive join on register IDs would have turned three lanes' findings into
phantom absence — the remap is what makes the union full.

**Grader aggregation.** Each grade file carries a per-claim (G) or per-input (C) matrix of
which lanes it ruled correct. One caught set per union item is built by **majority vote
across the graders that have a matrix**:
- Race G: ≥3 of 5 grade files (T644–T648), all five have full matrices.
- Race C: ≥3 of 4 grade files (**T654, T655, T657, T658**; **T656 has no per-item matrix —
  narrative only — and is excluded from the poll, stated**). T655's matrix is trigger-granular
  (5 divergent triggers); it is mapped to input level by the rule *input correct iff all
  three triggers correct* (its own 7 unanimous inputs are all-correct for every scorer).

**Items with no grader majority (Race C only).** Three inputs split the four graders 2–2 —
the *reference ruling itself* is contested, not the scorers' behaviour. They are marked
`verdict: uncertain`, carry **no caught_by**, are excluded from every rate, and are reported
in §4 instead of being resolved by guessing.

**Merges.** Zero cross-lane phrasing merges were made: Race G's union *is* the claim set
(one verdict per claim per lane) and Race C's union *is* the input set (the race's own
unit), so there was nothing to merge. The tool records `merge_decisions: 0` for both races
(form B, caught_by declared upstream). No aggressive merging was needed or done; the
overlap you see in §3–§4 is measured, not manufactured.

**Sensitivity.** The headline record uses the majority matrices above. Because the five
Race G graders disagree on 60–96% of (claim, lane) cells and the four Race C graders on
67–92%, every headline number carries a per-grader band, computed by re-running the
reduction on each single grader's matrix (`sensitivity-race-g-{644..648}.json`,
`sensitivity-race-c-{654,655,657,658}.json`). The band is reported next to the headline.

---

## 3. Race G — claim-doubt (task type `claim-doubt/2026-08-22`, n = 25)

Attribution: lane-1 claude-opus-5 (T640), lane-2 claude-sonnet-5 (T641), lane-3
deepseek-v4-pro (T639), lane-4 claude-haiku-4-5-20251001 (T642), lane-5 deepseek-v4-flash
(T638).

### 3.1 Per-lane unique-catch (the number panel selection consumes)

| lane | model | catches (of 25) | unique catches | unique-catch rate (of own catches) | unique over union | cost (tokens) |
|---|---|---|---|---|---|---|
| lane-1 | claude-opus-5 | 23 | **7** | 0.304 | 0.280 | 26,604,448 |
| lane-2 | claude-sonnet-5 | 15 | 0 | 0.000 | 0.000 | 7,088,967 |
| lane-3 | deepseek-v4-pro | 16 | 0 | 0.000 | 0.000 | unknown |
| lane-4 | claude-haiku-4-5-20251001 | 14 | 0 | 0.000 | 0.000 | 3,838,076 |
| lane-5 | deepseek-v4-flash | 15 | 0 | 0.000 | 0.000 | unknown |

- **claude-opus-5 is the only lane with any unique catch** (G01, G06, G07, G10, G12, G17,
  G18 — seven claims no other lane alone got right), and it misses only **G16 (2x2.C1)** and
  **G25 (QA-022)**.
- Lanes 2–5 contribute **zero unique catches** under the majority: everything they catch,
  someone else catches too. Their role in this task type is redundancy, not coverage.
- **Grader band (unique over union, per single grader):** opus-5 ranges 0.00 (T644) –
  0.36 (T647), headline 0.28; lanes 2–5 are 0.00 under *every* grader. The T644 end of the
  band is its structurally different axis: it marks lanes 2/3/5 correct on all 25 claims
  (a rubber-stamp passes its status-agreement axis trivially — T645's warning), which
  flattens everyone's uniqueness. The other four graders (T645/T647/T648, and mostly T646)
  agree on opus-5's unique role.

### 3.2 Pairwise overlap (Jaccard |A∩B|/|A∪B|)

| | opus-5 | sonnet-5 | pro | haiku | flash |
|---|---|---|---|---|---|
| opus-5 | — | 0.52 | 0.56 | 0.54 | 0.52 |
| sonnet-5 | 0.52 | — | **0.94** | 0.71 | 0.88 |
| pro | 0.56 | 0.94 | — | 0.67 | **0.94** |
| haiku | 0.54 | 0.71 | 0.67 | — | 0.61 |
| flash | 0.52 | 0.88 | 0.94 | 0.61 | — |

Two clusters: **sonnet-5 / pro / flash are near-duplicates of each other** (0.88–0.94),
each ~0.5 against opus-5; haiku is the most distinct from the pack (0.61–0.71) yet still
has zero unique catches — its distinctness is spread across items others also caught, not
concentrated anywhere only it saw.

### 3.3 Best subset of size k (k = 1..5), with the marginal gain of each seat

| k | best subsets (all ties) | covered / 25 | coverage | marginal gain | fully-costed min cost |
|---|---|---|---|---|---|
| 1 | {opus-5} | 23 | 0.92 | +0.92 | 26.6M |
| 2 | {opus-5, sonnet-5} · {opus-5, pro} · {opus-5, flash} | 25 | **1.00** | **+0.08** (G16, G25) | 33.7M (opus+sonnet) |
| 3 | any triple containing opus-5 (6 ties) | 25 | 1.00 | 0.00 | unknown |
| 4 | any quadruple containing opus-5 (4 ties) | 25 | 1.00 | 0.00 | unknown |
| 5 | all five | 25 | 1.00 | 0.00 | unknown |

- **The curve flattens at k = 2.** The second seat buys exactly two claims (G16, G25) —
  the two opus-5 missed — and any of sonnet-5/pro/flash covers both. The third, fourth and
  fifth seats buy nothing on this union.
- **"How big should a claim-doubt panel be": two seats, anchored on claude-opus-5 plus one
  of {sonnet-5, pro, flash}.** The cheapest fully-costed full-coverage pair is opus-5 +
  sonnet-5 at ~33.7M tokens (deepseek seats cost unknown, so a cheaper pair may exist but
  is not measurable from the token ledger).
- **Aggregation-rule caveat:** the two swing claims (G16, G25) sit on the thinnest majorities
  in the record. G16's four correct lanes are a 3/5 vote from {T644, T646, T648}; drop the
  T644 axis and **nobody** is correct on G16 (4-grader majority is empty). G25's correct
  lanes (2, 3, 5) are a unanimous 5/5. The claim *that a second seat reaches 100%* is
  therefore more robust than the claim *about which specific claims it adds*.

---

## 4. Race C — discernment-scoring (task type `discernment-scoring/2026-08-22`)

Attribution: scorer-1 claude-sonnet-5 (T621), scorer-2 deepseek-v4-flash (T624), scorer-3
deepseek-v4-pro (T623), scorer-4 claude-opus-5 (T622), scorer-5 claude-haiku-4-5-20251001
(T620). The two sealed null controls (pair-6-minimal, pair-6-orient) were matched exactly by
all five scorers per every grader's control check; they are non-discriminating union members.

**n = 9** (12 inputs minus the 3 contested, below). **No uncaught items.** No merges.

### 4.1 Per-scorer unique-catch

| scorer | model | catches (of 9) | unique catches | unique-catch rate | unique over union | cost (tokens) |
|---|---|---|---|---|---|---|
| scorer-1 | claude-sonnet-5 | 8 | 0 | 0.000 | 0.000 | 1,603,560 |
| scorer-2 | deepseek-v4-flash | 8 | 0 | 0.000 | 0.000 | unknown |
| scorer-3 | deepseek-v4-pro | 8 | 0 | 0.000 | 0.000 | unknown |
| scorer-4 | claude-opus-5 | **9** | 0 | 0.000 | 0.000 | 1,713,162 |
| scorer-5 | claude-haiku-4-5-20251001 | 8 | 0 | 0.000 | 0.000 | 1,403,846 |

- **No scorer is uniquely correct on any input** — every input is caught by ≥ 2 scorers.
  This is stable across all four graders (sensitivity: unique = 0 for every scorer under
  every single-grader matrix; T658 gives scorer-4 8/9 and scorer-1/2/5 9/9, still no
  uniqueness).
- scorer-4 (claude-opus-5) is the only perfect completer (9/9). Every other scorer misses
  exactly one input under the majority: sonnet-5, flash and haiku miss pair-3-orient (the
  S3 dial-falsehood item); pro misses pair-4-orient instead (where the other four are
  right and pro is over-strict on S3).
- **Unique-catch rate says nothing here; completeness does.** This is a task type where
  models differ by *which* input they miss, and the misses are shared, not private.

### 4.2 Pairwise overlap

| | sonnet-5 | flash | pro | opus-5 | haiku |
|---|---|---|---|---|---|
| sonnet-5 | — | 1.00 | 0.78 | 0.89 | 1.00 |
| flash | 1.00 | — | 0.78 | 0.89 | 1.00 |
| pro | 0.78 | 0.78 | — | 0.89 | 0.78 |
| opus-5 | 0.89 | 0.89 | 0.89 | — | 0.89 |
| haiku | 1.00 | 1.00 | 0.78 | 0.89 | — |

sonnet-5/flash/haiku overlap perfectly (1.00) — identical caught sets on the majority
union (they differ only in *reasoning quality*, which this input-level record cannot see);
pro is the odd one out (its one miss differs from the others').

### 4.3 Best subset of size k

| k | coverage (of 9) | marginal |
|---|---|---|
| 1 | **1.00** ({opus-5}) | +1.00 |
| 2–5 | 1.00 | 0.00 |

- One seat — **claude-opus-5 alone** — reaches the full majority union at 1.7M tokens, the
  cheapest full-coverage configuration of either race. Every pair that omits both pro and
  opus-5 (i.e. {sonnet-5, flash}, {sonnet-5, haiku}, {flash, haiku}) covers only 8/9.
- **The flattening point for discernment-scoring is k = 1** — but see the caveat: the
  union's contested items (§4.4) are exactly where a panel would earn its keep, and they
  are excluded because the reference is contested, not because they are easy.

### 4.4 The three contested items (verdict `uncertain`, excluded from n)

The four graders split 2–2 on *who was right* on these three inputs; the split is not a
scorer-behaviour artefact but a **reference disagreement among the graders themselves**
(e.g. T654 revised its own pair-1-minimal ruling mid-flight; T655's and T657's pair-5
readings contradict T654's):

| input | grader camp A (T654, T655) | grader camp B (T657, T658) |
|---|---|---|
| pair-1-minimal | {scorer-4, scorer-5} | {scorer-1, scorer-2, scorer-3} |
| pair-5-minimal | {scorer-3, scorer-4} | {scorer-1, scorer-2, scorer-5} |
| pair-5-orient | {scorer-3, scorer-4} | {scorer-1, scorer-2, scorer-5} |

The camps are not stable across items (A is {4,5} on pair-1-minimal but {3,4} on pair-5;
B is {1,2,3} then {1,2,5}), so there is no single "contested bloc" of scorers either. These
three items are the honest limit of this record: the graders could not agree on the answer,
so the record says so instead of picking a camp.

---

## 5. Cross-race stability — the question this row exists to answer

Same five models ran both races (lane/scorer numbers differ; attribution in §3/§4). **n = 2
races — this is a two-point comparison, and every stability statement below is a prior, not
a measurement.** The honest read:

**Stable (both task types):**
- **claude-opus-5 is the anchor seat in both.** Only model with unique catches in claim-doubt
  (7 unique, 0.28 over union); only perfect completer in discernment-scoring (9/9). Panel
  selection may anchor on opus-5 for both types. Its cost is the highest in claim-doubt
  (26.6M tokens) but mid in discernment (1.7M) — do not fold that into the anchor decision;
  it is reported separately.
- **The other four models contribute zero unique catches in both task types** (majority
  rule). Nothing in either race makes sonnet-5, pro, haiku, or flash an irreplaceable
  coverage source. Under the grader band, opus-5's uniqueness in claim-doubt ranges
  0.00–0.36 but *no* grader gives any other lane a unique catch in either race.

**Type-specific (the part that must not be averaged away):**
- **Panel size flattens at different k:** claim-doubt needs k = 2 (second seat buys the two
  claims opus-5 misses); discernment-scoring is flat at k = 1 over the majority union.
- **Redundancy structure differs:** in claim-doubt the redundancy is *clustered*
  (sonnet-5/pro/flash at Jaccard 0.88–0.94); in discernment-scoring it is *pervasive*
  (sonnet-5/flash/haiku at 1.00) and the discriminating signal is which single input a
  model misses.

**Verdict for T636:** the *anchor* and the *who-never-contributes-uniquely* facts look
stable across these two task types at n = 2; the *how-big-should-the-panel-be* answer is
type-specific (2 vs 1) and must be read per task type, not averaged. That stability claim
is two races old and will be overturned by the first race that disagrees with it — treat it
as the current prior, not a law.

---

## 6. What T636 (panel selection) should take from this

1. **Anchor on claude-opus-5 for both task types** (only model with unique catches in G,
   only perfect completer in C). The prior-driven label it replaces was correct on this point.
2. **A second claim-doubt seat should be one of {sonnet-5, pro, flash}**, not haiku:
   {opus-5, haiku} covers only 24/25 (the claims opus-5 misses are G16 and G25; haiku
   catches G16 but not G25). This is a *measured* difference the prior could not have
   supplied.
3. **Do not seat models for uniqueness where the record shows none.** In discernment-scoring
   no model is unique; a one-seat panel (opus-5) reaches the whole union. Seats 2–5 buy
   robustness to the *reference* being contested (§4.4), not coverage.
4. **Consume the caught matrix, not just the rates:** `tools/complementarity-record.json`
   groups `caught_matrix` per item for marginal computation; the three `uncertain` Race C
   items and their camps are in §4.4 / `tools/complementarity-inputs/race-c.json`.

---

## 7. Reproduction

```sh
# self-tests
python3 tools/complementarity.py check
# majority record (this doc's headline numbers)
python3 tools/complementarity.py reduce \
  --input tools/complementarity-inputs/race-g.json \
  --input tools/complementarity-inputs/race-c.json
# standing record (all four races; race-a/race-f groups byte-identical to the prior record)
python3 tools/complementarity.py reduce \
  --input tools/complementarity-inputs/race-a.json \
  --input tools/complementarity-inputs/race-f.json \
  --input tools/complementarity-inputs/race-g.json \
  --input tools/complementarity-inputs/race-c.json \
  --out tools/complementarity-record.json
# per-grader sensitivity band
for f in tools/complementarity-inputs/sensitivity-*.json; do
  python3 tools/complementarity.py reduce --input "$f" >/dev/null
done
```

Inputs are deterministic and pinned: every race-input file records its own sha256 in
`tools/complementarity-record.json` (`generated_from`). Re-running on the same inputs
produces byte-identical output (control 4).
