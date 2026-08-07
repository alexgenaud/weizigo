# When does a position loop, and is a truncated game's score ever mistaken for a value?

**Task:** T412 · **Worker:** glm-5.2 · **Date:** 2026-08-07
**Landmark:** advances `L2 (proven 4×4 values)` — the loop phenomenon is now *located*
(exact positions where optimal play is forced into a loop) and *measured from the table*
(the ply cap the table itself implies), where before it was only inferred from a 96 %
cap rate.

**Amend.** This row was sharpened mid-flight by directive **D056** (claude-opus-5/Orcha,
2026-08-07): the *sibling test* (Q1) and the *dtt table read* (Q1b) replace the
per-ply replay as the primary questions. The replay (Q1c) is retained as secondary;
it was already complete when the amend arrived and corroborates the primary result.

---

## 0. The two caps are different mechanisms, and only one can corrupt a value

Restated from the brief so the rest of the doc is unambiguous:

| | **ply cap** (T401/T407) | **capture budget** (T387/T397/T402) |
|---|---|---|
| what | a tournament **stopping rule**: abandon a game after N plies | a **ruleset change**: forbid captures beyond `B` |
| where | the harness, during play | the solver, when computing the table |
| product | **no score** — the game is counted `capped`, excluded from scoring | **a score**, used as a value |
| status | honest but blinding (96 % of 3×3 games capped) | **demoted (T402)** — measured wrong |

**Audit (this row's first deliverable).** T407's harness classifies each played game
into `capped` or `scored` and the cap-hits are "their own class, never scored;
excluded from the historical-table matrix (which is over scored games only)"
(`src/t407_divergence_matrix.zig:982-986`, the `any_capped` branch). The stored
data confirms it: at 3×3, `cap_class = 3078`, `scored = 126`, `class_b = 0`
(`docs/evidence/BRACKET-TOURNAMENT/divergence-matrix-2026-08-07-3x3-data.json`);
at 4×4, `cap_class = 230`, `scored = 270`. **No capped game's score reaches any
table, register row, or promotion.** The cap's only risk is blindness, not
corruption. The capture-budget corruption the operator feared is a separate,
already-demoted mechanism (T402) and is not re-examined here.

---

## Q1 — the sibling test: is a loopy move ever the BEST move among its siblings?

*Instrument:* `src/t412_sibling.zig` (additive; reads WZO2 only). For every
non-terminal table position `p` (3×3 exhaustive; 4×4 reservoir sample, denominator
stated), enumerate its children (legal placements + pass); mark a child
**optimal** if its pinned value equals the Bellman best over all children (argmax
for Black to move, argmin for White, scores Black-positive); mark a child
**loopy** if `L < H` (the value-ambiguity marker — defended below). The **decisive
count** is the positions where *every* optimal child is loopy.

**Loopy criterion defended.** `L < H` is exactly the value-ambiguity marker: the
table could not collapse the position to a single score, which is the project's
own definition of draw-by-loop. A *graph* (on-a-cycle) criterion is **not** added:
the project already established SCC membership is near-vacuous (100 % of `L < H`
lie in a non-trivial SCC, but so do 98.1 % of `L == H`; `docs/research/force-life-
classifier-2026-08-06.md`), so a graph criterion would not materially change the
picture and would re-derive a settled result.

**Tautology guard (regression check).** For every parent the stored pinned value
`V_p = pinnedValue(L_p, H_p)` must equal the Bellman best over children. This is
0 mismatches on 47,456 checks at 3×3 and 0 on 200,000 at 4×4 — the child
enumerator and value computation agree with the table's fixpoint. (Sample
sufficient to catch a code regression; not an exhaustive re-proof.)

**Controls.** N1 (structural): the tautology guard above. S1 seeded
(`--seedctl force_loopy`, treat every child as loopy): forced-loop reads
**100 %** (47,456/47,456 at 3×3; 50,000/50,000 at 4×4) — the detector fires
universally when the data says so, so the real counts below are a genuine
subset, not a degenerate "always forced." The seeded control is shown red first
in `docs/evidence/T412-SIBLING-DTT/sibling-{3x3,4x4}-forceloopy-control.json`.

### Results

| goban | non-terminal parents (denom) | tautology mismatches | **FORCED-LOOP** (every optimal child loopy) | of which one-of-one | all-loopy k≥2 | partial | no-loop |
|---|---|---|---|---|---|---|---|
| 3×3 | 47,456 | 0 / 47,456 | **5,080 (10.70 %)** | 4,420 | 660 | 448 | 41,928 |
| 4×4 | 200,000 (sample of 98,616,794) | 0 / 200,000 | **6,073 (3.04 %)** | 5,487 | 586 | 862 | 193,065 |

- 3×3 children: 97,064 optimal children in total; 6,672 (6.87 %) of them are loopy.
- 4×4 children: 728,671 optimal; 7,793 (1.07 %) loopy.

**The count is non-zero at both sizes.** The operator's "no-problem" case
(count = 0, optimal play always avoids a loop, truncation costs nothing) is
**falsified**: there exist positions from which optimal play is *forced* into a
loop — every optimal move lands on a value-ambiguous child. These positions are
the finding; the ply cap is concealing a real phenomenon there, not trimming
blunders.

**The finer distribution makes it stronger.** The dominant case is
**one-of-one**: a position with exactly one optimal child, and that child is
loopy (4,420 / 5,080 at 3×3; 5,487 / 6,073 at 4×4 — 87 % and 90 % of the
forced-loop positions). One optimal move, and it is the loop. There is no
"choose the safe optimal sibling" escape at these positions; the loop is the
only optimal line.

### Witness boards (forced-loop positions, one optimal child, loopy)

3×3, colex 3, Black to move, `L = −9, H = −3`, 1/1 optimal child loopy:
```
· O ·
· · ·
· · ·
```
3×3, colex 7, Black to move, `L = −9, H = −3`, 1/1:
```
· · ·
O · ·
· · ·
```
(These are near-empty boards: a single White stone, Black to move, already in a
White-favoured bracket whose single optimal continuation is loopy.)

4×4, colex 8734224, White to move (passes=1), `L = −16, H = −3`, 1/1:
```
X · X X
X O · O
· · X ·
· X · O
```

### Side-by-side under the quasi-rule: NOT DONE — no artifact exists

The brief asked for the test under the *true* table value **and** the "no captures,
only add stones" quasi-rule, side by side; the operator's condition is that loop
paths be suboptimal *in truth or under the quasi-rule*. **No quasi-rule artifact
exists**: there is no `.wzo2` with a no-capture `rules_id` (the only committed
rules_id is `RULES_BASICKO_LH_AREA = 3`; a search for `*nocap*` / `*quasi*` returns
nothing). So the side-by-side **cannot be tested this row** — stated, not hidden.
A no-capture fixpoint build is a follow-up; until it exists, only the true-table
result above stands.

---

## Q1b — the ply cap is already in the table (the dtt read)

*Instrument:* `src/t412_sibling.zig`, `--dtt` path (a byte scan over all entries;
minutes). Each WZO2 entry's 4th byte is `DTT` (distance-to-termination;
`DTT_FAR = 255`). The recurrence (`src/oracle_v2_build.zig:165-271`):
`DTT(s) = 1 + min_{c ∈ VP(s)} DTT(c)`, terminal passes=2 children `DTT = 0`. So
`DTT` is **1-indexed** (a state one move from terminal has `DTT = 1`), and the max
over decisive entries is the deepest resolvable game length in plies.

### max DTT over L==H (decisive) entries — the honest ply cap

| goban | total entries | L==H (decisive) | L<H (loopy) | **max DTT (L==H)** | T407's ply cap | ratio |
|---|---|---|---|---|---|---|
| 3×3 | 49,428 | 44,020 | 5,408 | **9** | 400 | 44× generous |
| 4×3 | — | — | — | **unavailable** | — | — |
| 4×4 | 99,133,036 | 95,677,624 | 3,455,412 | **17** | 400 | 24× generous |

**4×3 has no WZO2 artifact** (the T394 generic fixpoint yields L/H but not DTT),
so its DTT is unavailable — stated, not hidden; a 4×3 DTT would need a fresh
fixpoint build that records DTT.

**The operator expected ~27 at 3×3 (three times the 9 points); the true figure is
9.** The deepest decisive 3×3 game resolves in 9 plies — one ply per point, i.e.
fill the board. 4×4 resolves in 17 plies. Both are *far* below T407's 400-ply cap.

**This is the result the operator asked us not to footnote.** The 96 %-capped 3×3
leg was **not** capped for depth: every resolvable 3×3 game finishes within 9
plies, so a 400-ply cap can only ever truncate a game that *never resolves* — a
loop. The cap rate measures loopiness, not depth. The loops are exactly the
`L < H` region the sibling test locates.

### DTT for L<H entries: populated, not a sentinel, and not a guarantee

| goban | L<H entries with DTT==FAR (255) | L<H DTT range | interpretation |
|---|---|---|---|
| 3×3 | 0 / 5,408 (0.00 %) | 1 .. 11 | populated |
| 4×4 | 0 / 3,455,412 (0.00 %) | 1 .. 18 | populated |

The `DTT_FAR` sentinel (255) is **unused in both tables** — zero entries at either
size carry it (including among L==H: 0 / 44,020 at 3×3, 0 / 95,677,624 at 4×4).
Every state, loopy or not, has a value-preserving path to a terminal.

For **L==H** entries DTT is the genuine game length (the game terminates in DTT
plies under optimal play). For **L<H** entries DTT is the *shortest*
value-preserving path to a zero-score terminal — **populated, but not a
termination guarantee**: the position is loopy, and a player may take the loop
instead, because the loop preserves the (pinned, zero) value too. So a finite DTT
on an L<H entry is a "best-case escaping line," not a bound the game must follow.
This is consistent with the sibling test: a forced-loop position has a finite DTT
(the escaping path exists) yet *every* optimal move keeps you in the loopy region
for at least one more ply.

### Honest cap per size

- **3×3: 9 plies suffice to resolve any decisive game.** T407's 400 is 44× the
  need; the 96 % cap is loop-trimming, not depth-trimming.
- **4×4: 17 plies suffice for any decisive game** (sample-derived max over the
  full 99 M entries, exact not sampled). 400 is 24× the need.
- **4×3: unknown** (no WZO2 DTT). A reasonable working cap is the 3×3/4×4
  extrapolation (≈ the point count, ≤ 12 for 4×3), but it is not measured here.

---

## Q1c — replay check (secondary): are looping paths made of optimal moves or blunders?

*Instrument:* `src/t412_loop_onset.zig` (additive; reuses the T401 game engine
verbatim, adds per-ply classification). For each bracketed (L<H) fresh-start
position, plays NEW-vs-NEW self-play (both sides table-argmax, the presumed-
optimal play) to the 400-ply cap; for every capped game, classifies each ply's
parent position (`bracketed` / `single` L==H / `no_entry`) and the chosen move
(`value_preserving` / `value_losing` / `unclassifiable`).

**Controls.** N1 null (`--controls-only`, empty position list): all zeros, no
crash. S1 seeded (`--seedctl weakened,3`, random legal move every 3rd ply): the
classifier labels **4.69 %** of capped-game plies `value_losing` and detects a
value-losing ply in 159 / 282 capped games — the detector fires when a blunder is
forced. The headline (0 % value-losing under optimal play) is only meaningful
because the classifier is proven able to see a blunder. Seed shown red first:
`docs/evidence/T412-LOOP-ONSET/loop-onset-3x3-weak.json`.

### Results

| goban | bracketed starts | capped | scored | cap plies | value-preserving | value-losing | unclassifiable | pos bracketed | pos single (L==H) | pos no-entry | games cycling |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 3×3 | 3,204 | 3,078 (96.07 %) | 126 | 1,231,200 | **100.00 %** | 0.00 % | 0.00 % | **100.00 %** | 0.00 % | 0.00 % | 100 % |
| 4×4 | 500 (sample) | 232 (46.40 %) | 268 | 92,800 | **100.00 %** | 0.00 % | 0.00 % | 98.70 % | 1.30 % | 0.00 % | 100 % |

**Under optimal self-play, capped games consist entirely of value-preserving
moves and stay (almost) entirely inside the bracketed region.** At 3×3 the loop
is confined to the `L < H` region with no exceptions (100 % bracketed, 0 %
single). At 4×4 there is a small leak: 7 / 232 capped games (3.02 %) visit a
single-valued (L==H) position at least once (1,203 / 92,800 plies = 1.30 %);
these games cycle through 11–16 distinct states. Every capped game revisits a
state (100 % cycling) — the loops are genuine cycles.

This corroborates the sibling test from the play side: the loops optimal play
enters are not blunders (0 % value-losing) and not escapes into unvalued states
(0 % unclassifiable); they are the table's own bracketed region, traversed
forever because every optimal move preserves the value and the value is a
bracket.

**Caveat on the 4×4 leak.** The committed 4×4 table is the writes-ON build
(`data/oracle-4x4.checkpoint.wzo` / `data/oracle-4x4-v2.wzo2`), which the
foreclosure in `AGENTS.md` flags as **not trustworthy for ko-sensitive values**.
The 7 games that touch a single (L==H) position while looping may be a table
artifact (a single value assigned within the ko-sensitive region) rather than a
real phenomenon. The 3×3 result (0 % single, on the fresh-start-correct 3×3
table) is clean.

---

## Q2 — can a cheap feature predict L<H?

*Instrument:* `src/t412_predictors.zig` (additive). For every fresh-start entry
(terminal=0, ko=NONE, passes=0) the label is `L < H`; each of 22 position-geometry
features (stone count/parity, per-side chain & liberty counts, min-liberty,
atari/mutual-atari, shared liberties, empty-region sizes, eye-space, Benson-alive-
now) is scored as a single-feature classifier by threshold sweep (best-F1 with
precision/recall). 3×3 exhaustive (23,420 fresh-start entries); 4×4 reservoir
sample (200,000 of 48,276,340).

**Controls.** N1 null (shuffle the labels, re-score the best feature): precision
collapses to the base rate (3×3: P = 0.1368 = base; 4×4: P = 0.0415 = base) — a
measurement returning 1.0 on shuffled labels is the failure mode this guards. S1
seeded (a "planted" feature = the true label on a random 10 % subset): at its
selecting threshold it reads **P = 1.0000, R ≈ 0.10** at both sizes — the
precision/recall arithmetic is correct and a perfect predictor is detectable.

### Results — the best single cheap feature, by size

| goban | fresh-start entries | L<H (base rate) | best non-planted feature | best F1 | precision | recall |
|---|---|---|---|---|---|---|
| 3×3 | 23,420 | 3,204 (0.1368) | `min_lib_opp` (≤ 2) | 0.299 | 0.193 | 0.668 |
| 4×4 | 200,000 (of 48.3 M) | 8,307 (0.0415) | `total_lib_opp` (≤ 6) | 0.107 | 0.059 | 0.622 |

**No cheap feature separates `L < H` from `L == H` meaningfully.** At 3×3 the best
feature's precision (0.193) barely beats the base rate (0.137); at 4×4 it is
essentially at the base rate (0.059 vs 0.042). `L < H` is a global/fixpoint
property — it is the *answer* the full solve produces — and it is not recoverable
from local board geometry. This is the negative result the brief anticipated and
is consistent with the prior findings: `canForceLife` is necessary-ish-not-
sufficient, SCC membership is near-vacuous, ko-freeness points the wrong way, and
now none of liberty/eye/atari/stone-count structure does better. **The next
attempt should not retry a local-geometry feature.** (Per-feature precision/recall
for all 22 features is in `docs/evidence/T412-PREDICTORS/predictors-{3x3,4x4}.json`.)

---

## Q3 — the operator's 3×3 confusion, resolved with the three numbers side by side

*"draw-by-loop roots are 2×2 and 3×2 only. 3×3 is decisive at +9 — does that mean
3×3 positions are never decided by capture-cap paths?"*

**No.** The **root** is one position. 3×3's empty-board root is single-valued
(+9), but that says nothing about the other positions. The bracket totals (from
the committed T394 census, `findings/T394-force-life.json`, reproducing the A4
pin census exactly at 3×3/4×4):

| goban | root value | total entries | `L < H` count | `L < H` fraction | straddle (`L≤0≤H`) count | straddle fraction |
|---|---|---|---|---|---|---|
| 3×3 | +9 (single) | 49,428 | 5,408 | 10.94 % | 1,248 | 2.52 % |
| 4×3 | [4, 12] (bracket, Black-favoured) | 1,293,848 | 93,096 | 7.20 % | 26,520 | 2.05 % |
| 4×4 | [1, 16] (bracket, Black-favoured) | 99,133,036 | 3,455,412 | 3.49 % | 895,216 | 0.90 % |

So 3×3 has plenty of loopy positions (5,408 of them, 1,248 straddling zero); only
its *empty board* is decisive. "Draw-by-loop roots" (straddling zero, `L≤0≤H`) are
indeed only 2×2 and 3×2; 4×3 and 4×4 roots are bracket-valued but **Black-favoured**
(`L > 0`), so they are decisive-for-Black under the bracket, not draws.

---

## Synthesis — what is now known, and what is not

**Known (this row).**
1. **Loop onset is located.** 5,080 / 47,456 3×3 positions (10.70 %) and 6,073 /
   200,000 sampled 4×4 positions (3.04 %) **force** optimal play into a loop —
   every optimal child is `L < H`. 87–90 % of these are *one-of-one*: the single
   optimal move is the loop. (Q1)
2. **The cap is in the table.** The deepest decisive game is 9 plies (3×3) and
   17 plies (4×4). T407's 400-ply cap is 24–44× generous; the 96 % 3×3 cap rate
   measures loopiness, not depth. (Q1b)
3. **Capped games are not blunders.** Under optimal self-play, capped games are
   100 % value-preserving moves, confined to the `L < H` region (100 % at 3×3;
   98.70 % at 4×4 with a small, possibly-artifact leak), and 100 % genuine
   cycles. (Q1c)
4. **No cheap predictor exists.** Best single-feature F1 ≈ 0.30 (3×3) / 0.11
   (4×4), precision barely above base rate. `L < H` is not recoverable from
   local geometry. (Q2)
5. **No capped score reaches any table.** (§0 audit.)

**Unknown / out of scope this row.**
- **The quasi-rule side-by-side** (Q1 under "no captures, only add stones"). No
  such artifact exists; the operator's "suboptimal in truth *or* under the
  quasi-rule" condition can only be half-tested (truth = falsified: optimal play
  *is* forced into loops at 5,080 positions). Whether the quasi-rule would
  exonerate those positions requires a no-capture fixpoint build — a follow-up.
- **4×3 DTT.** No WZO2 at 4×3; the honest cap there is unmeasured.
- **The 4×4 single-position leak** (7 capped games touching L==H) may be a
  writes-ON table artifact; resolving it needs the Track-A `memo_writes=false`
  regeneration the foreclosure already gates.
- **Whether the 5,080 forced-loop 3×3 positions are a *minimal* witness set**
  (a smaller "must-pass-through" frontier) is not analysed here; the sibling
  test counts positions, not a cut-set.

**Direction the result cuts.** Against the operator's "no-problem" hope: optimal
play *is* forced into loops at a measurable, non-zero fraction of positions, the
loops are genuine cycles in the bracketed region, and the ply cap is concealing
them (not trimming blunders, not truncating deep-but-resolvable games). The
honest deliverable per `AGENTS.md` is therefore: the fresh-start score table +
the CLAIMED `[L,H]` fresh-start bracket, with the explicit non-promise that
neither equals nor bounds the real-game PSK score — *and now with the loop
positions located*, so the cap's blindness is named rather than denied.

---

## Provenance

| artifact | path |
|---|---|
| sibling + dtt instrument | `src/t412_sibling.zig` |
| replay instrument | `src/t412_loop_onset.zig` |
| predictor instrument | `src/t412_predictors.zig` |
| sibling/dtt evidence (3×3) | `docs/evidence/T412-SIBLING-DTT/sibling-dtt-3x3.json` |
| sibling/dtt evidence (4×4) | `docs/evidence/T412-SIBLING-DTT/sibling-dtt-4x4.json` |
| force_loopy control (3×3) | `docs/evidence/T412-SIBLING-DTT/sibling-3x3-forceloopy-control.json` |
| force_loopy control (4×4) | `docs/evidence/T412-SIBLING-DTT/sibling-4x4-forceloopy-control.json` |
| replay evidence (3×3 opt) | `docs/evidence/T412-LOOP-ONSET/loop-onset-3x3-opt.json` |
| replay control (3×3 weak) | `docs/evidence/T412-LOOP-ONSET/loop-onset-3x3-weak.json` |
| replay control (3×3 null) | `docs/evidence/T412-LOOP-ONSET/loop-onset-3x3-null.json` |
| replay evidence (4×4 opt) | `docs/evidence/T412-LOOP-ONSET/loop-onset-4x4-opt.json` |
| predictor evidence (3×3) | `docs/evidence/T412-PREDICTORS/predictors-3x3.json` |
| predictor evidence (4×4) | `docs/evidence/T412-PREDICTORS/predictors-4x4.json` |
| T407 capped-game aggregates | `docs/evidence/BRACKET-TOURNAMENT/divergence-matrix-2026-08-07-{3x3,4x4}-data.json` |
| bracket totals (T394 census) | `findings/T394-force-life.json` |

All runs under `tools/runner` (4 GB RSS / wall / CPU guards); peak RSS observed
≤ 1.7 GB (4×4 sibling+dtt). Tables: `data/oracle-3x3-v2.wzo2`,
`data/oracle-4x4-v2.wzo2`. The 4×4 table is the writes-ON build (foreclosure
applies; the 4×4 single-position leak is reported under that caveat). Scores are
Black-positive throughout; the side-to-move picks the array, never the sign.

**Inbox.** Directive **D056** (AMEND, claude-opus-5/Orcha, 2026-08-07) was
received mid-work, acked, and acted on: the sibling test (Q1) and dtt read (Q1b)
were built and run as the primary questions; the replay (Q1c) was demoted to
secondary (already complete). Recorded in `findings/T412-loop-onset.json:notes`.