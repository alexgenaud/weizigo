# Two-life census — coexisting unconditional life, and whether life ever sits under a straddling bracket

**Task:** T393 · **Role:** worker · **Model:** deepseek-v4-flash · **Identifier:** flash/T393 ·
**Date:** 2026-08-06
**Instrument:** `src/t393_census.zig` (additive; no engine, artifact, or axiom edits) — modes
`--selftest`, `--wzo2`, `--wzo1`, `--twolife`; SHA-256
`98ad3d89d58ebb8437c5e63e14b3fcaf026914462de70b90810677eb32735130`
**Data:** `findings/T393-two-life-census.json` · `docs/research/two-life-census-2026-08-06.md`
**Status:** CENSUS — every figure carries its denominator; committed cross-checks reproduced
(§5). No solving, no re-derivation, no fixes.

**Landmark:** advances `L2 (proven 4×4 values)` — the bracketed region is now characterised
by territory structure: **a straddling bracket never contains unconditional life, and
unconditional life always certifies (L==H)** at every size with a WZO2 table. What remains
for L2: the independent regeneration of the ko-sensitive columns (Track A) — see §6.

---

## 1. The operator's question

*"Are there goban sizes or positions where neither player is guaranteed to be able to
establish a strong territory?"* (Operator, 2026-08-06.)

T382 (`goban-pathology-2026-08-05.md:74-83`) found a colour with **zero** Benson-alive stones
in 100% of trusted-region states through 3×3 and 99.999% at 4×3, and flagged the 4×4
measurement as pending. T393 measures the static half of the operator's question: how rare is
coexisting unconditional life, and how does the presence of a Benson-alive chain sit relative
to the solved table's bracket classes — specifically the straddling class (L ≤ 0 ≤ H with
L < H, the A4 pin_0 class), where the game is a draw under the TIE=0 pinning. T394 measures
the forcible half (independent, non-blocking).

Benson life means Benson 1976 as implemented (`benson_alive` in `src/rules.zig`), *not*
eye-counting; uninvadable territory in the Müller 1997 sense is out of scope (the
`terminal-territory-bug.md` trap is respected).

**The answers up front.**

1. **Coexisting unconditional life begins at 4×3**, with exactly **2** positions (a
   colour-inverse pair), and is vanishingly rare at 4×4: **324 of 24,318,165** legal
   positions (0.0013%, one in ~75,000). 3×3 has none. The T382 zero-alive series is now
   complete through 4×4.
2. **The hypothesis survives at every measured size: no state containing a Benson-alive
   chain has a bracket straddling zero.** Z ∧ any-alive = 0 at 3×3 and 4×4, over all
   99,133,036 entries and over the 48,505,262-entry fresh-start slice at 4×4 (and the
   49,428 / 24,330 slices at 3×3). Of the committed 895,216 pin_0 entries at 4×4, **zero**
   contain a Benson-alive chain for either colour.
3. **Stronger, and not forced by Benson alone:** no entry whose side to move *or* whose
   opponent holds a Benson-alive chain is in **any** non-certified bracket (L/H/Z counts are
   all zero). Wherever unconditional life exists, the stored table certifies L==H. §4.2.
4. **The operator's shape claim is refuted at 3×3:** unconditional life exists *without* a
   centre stone — the diamond `.x./x.x/.x.` (the four edge-midpoints; the brief's two named
   shapes are the same cell set) is Benson-alive with an empty centre. 206 raw positions,
   **38** up to rotation/reflection, **19** up to rotation/reflection/colour-inversion.

---

## 2. Method — what was measured and on what

The WZO2 tables (`data/oracle-3x3-v2.wzo2`, `data/oracle-4x4-v2.wzo2`) were walked group by
group. Each group is one legal position (colex key, per the format contract §2.1); each entry
is a `(position, side, ko, passes)` state with its bracket (L, H) and DTT. Per position,
`benson_alive` was computed once for each colour and cached for all of the position's entries
(24,318,165 positions × 2 at 4×4, so no per-entry recomputation).

- **Part 1 — two-life frequency** (position-level): both colours have ≥ 1 Benson-alive chain.
  Sizes: 3×3 and 4×4 over WZO2; 4×3 over the WZO1 artifact `artifacts/oracle-4x3.wzo` — **no
  WZO2 artifact exists at 4×3, so the 4×3 figures are WZO1-denominated (stated, not hidden)**.
  WZO1 vs WZO2 position-level counts are interchangeable here: legality and Benson aliveness
  are rule-family-independent position predicates, verified by the 4×4 double-count in §5.
- **Part 2 — life-vs-bracket join** (entry-level, per bracket class of the *state*): the
  predicate "the side to move holds a Benson-alive chain NOW", crossed with the bracket
  classes **T** (L==H), **L** (L<H, L>0), **H** (L<H, H<0), **Z** (L<H, L≤0≤H). Reported for
  all entries and for the fresh-start slice (passes=0, ko=none) — the "now" reading of a
  fresh-start position. The converse slice ("of the 895,216 draw-by-loop entries, how many
  contain a chain") is the Z∧either count, reported with its denominator.
- **Part 3 — winner's-structure check** (3×3 only): among positions where a colour is
  Benson-alive, does life exist without a stone of that colour at the centre point? Counted
  raw, mod D4 (rotation/reflection), and mod D4×colour-inversion. (The brief's "73,758
  states" is the committed reachable-`(board,side,ko,passes)` count for 3×3 from
  `newrule-3x3-2026-07-28.md:114`, not an alive-position count — positions where a colour is
  alive are **1,766 of 12,675** legal positions at 3×3; both readings are reported.)

---

## 3. Part 1 — two-life frequency (completing the T382 series)

| goban | legal positions | **both colours Benson-alive** | % | a colour at zero alive | % |
|---|---|---|---|---|---|
| 2×2 | 57 | 0 | 0% | 57 | 100% |
| 3×2 | 489 | 0 | 0% | 489 | 100% |
| 3×3 | 12,675 | **0** | 0% | 12,675 | 100% |
| 4×3 | 321,689 | **2** | 0.0006% | 321,687 | 99.9994% |
| 4×4 | 24,318,165 | **324** | 0.0013% | 24,317,841 | 99.9987% |

(2×2–4×3 rows: T382, `goban-pathology-2026-08-05.md:74-83`, WZO1; the 4×4 zero-alive row was
T382's pending figure, measured here. 3×3/4×4 two-life from WZO2; 4×3 from WZO1.)

**Coexisting life is a 4×3-and-up phenomenon and stays extraordinarily rare.** The two 4×3
positions are a colour-inverse pair — at the smallest goban where it happens, the coexistence
is a symmetric interlock:

```
.xo.          .ox.
xxoo          ooxx
.xo.          .ox.
```

At 4×4, the 324 two-life positions are band-family shapes (all eight shown by the instrument,
in colex order, are a four-wide black band and a four-wide white band with shifted edge
stones); **the brief's hand-verified example is the colex-first one**:

```
.x..
xxxx
oooo
.o..
```

---

## 4. Part 2 — life vs. bracket: the join

### 4.1 Bracket totals (reproducing the A4 pin census exactly)

| goban · slice | entries | T (L==H) | L (L<H, L>0) | H (L<H, H<0) | Z (L≤0≤H) |
|---|---|---|---|---|---|
| 3×3 · all | 49,428 | 44,020 | 2,080 | 2,080 | 1,248 |
| 3×3 · fresh-start | 24,330 | 21,126 | 1,294 | 1,294 | 616 |
| 4×4 · all | 99,133,036 | 95,677,624 | 1,280,098 | 1,280,098 | **895,216** |
| 4×4 · fresh-start | 48,505,262 | 46,543,120 | 728,635 | 728,635 | 504,872 |

The 4×4 all-entries row equals the committed A4 pin census exactly
(`rebuild-2026-08-03.md:174`, `baselines.md:70`: pin_T=95,677,624, pin_L=pin_H=1,280,098,
pin_0=895,216) — the instrument's bracket classification is the acceptance instrument's.

### 4.2 The join — alive-chain predicates per bracket

Entries where the side to move, or the opponent, holds a Benson-alive chain, by bracket:

| slice | bracket | side-to-move alive | opponent alive | either | both | none |
|---|---|---|---|---|---|---|
| 3×3 all (49,428) | T | 3,270 | 3,270 | 6,540 | 0 | 37,480 |
| | L | 0 | 0 | 0 | 0 | 2,080 |
| | H | 0 | 0 | 0 | 0 | 2,080 |
| | Z | **0** | **0** | **0** | 0 | 1,248 |
| 3×3 fresh-start (24,330) | T | 1,504 | 1,766 | 3,270 | 0 | 17,856 |
| | L / H / Z | 0 | 0 | 0 | 0 | 1,294 / 1,294 / 616 |
| 4×4 all (99,133,036) | T | 2,766,492 | 2,766,492 | 5,531,688 | 1,296 | 90,145,936 |
| | L / H | 0 | 0 | 0 | 0 | 1,280,098 |
| | Z | **0** | **0** | **0** | 0 | 895,216 |
| 4×4 fresh-start (48,505,262) | T | 1,358,216 | 1,389,364 | 2,746,932 | 648 | 43,796,188 |
| | L / H / Z | 0 | 0 | 0 | 0 | 728,635 / 728,635 / 504,872 |

Every alive-chain entry is in the certified class; every straddling entry is alive-free.

**Hypothesis verdict: STANDS.** Z ∧ either-alive = 0 at every size and slice. **Converse
slice:** of the 895,216 pin_0 entries at 4×4 (and 1,248 at 3×3), **zero** contain a
Benson-alive chain for either colour. **Position-level form:** 507,484 positions at 4×4 (and
624 at 3×3) have at least one straddling entry; **zero** of those positions contain any
alive chain.

**Why this is not trivially forced, and why it matters.**

**Withdrawn (2026-08-06, T398):** an earlier draft of this paragraph argued that a
Benson-alive chain's *k* stones bound the owner's score away from zero (≥ *k* for Black),
which would rule out straddling for terminated lines and leave only loop states as the
possible exception. **That is wrong, and T393's own 3×3 table refutes it.**
Unconditional life bounds the owner's *area*; the score is area *minus the opponent's*,
and the opponent can hold more of the goban. The value distribution of WZO2 entries
containing a Black Benson-alive chain at 3×3:

| L | −2 | −1 | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 9 |
|---|---|---|---|---|---|---|---|---|---|---|
| entries | 4 | 26 | 60 | 98 | 112 | 72 | 132 | 88 | 160 | 2,518 |

**90 entries have a Black unconditionally-alive chain and a value ≤ 0; 60 sit exactly at
zero.** The lowest is `L == H == −2` with a two-stone alive chain — where the earlier claim
would predict `≥ +2`, so it is wrong by four points and by sign. A live chain is compatible
with a negative score, a zero score, and could a priori be compatible with a straddling
bracket. T393's categorical result — *wherever unconditional life sits on the goban, the
stored table certifies `L == H`* — is therefore **less expected** than the earlier draft
claimed, not a more expected one.

A straddling bracket could in principle arise from a terminated state (a live chain losing
on area) just as easily as from a draw-loop state — the zeroing-out argument does not
work in either case. The table nevertheless shows **no such state exists**: wherever
unconditional life is on the board, the least/greatest-fixpoint pair is already certified
(L==H). This is a measured structural property of the stored tables, not a derived theorem;
note the L<H columns are the distrusted ko-sensitive region per the foreclosures, and the
finding's force is *categorical* (alive entries never co-occur with non-T brackets), so it
is robust to value distrust unless Track A's regeneration changes which entries are L<H
(then the re-run is a 5-minute check on this instrument).

**Whose loop threat survives a live group?** The question is moot in the measured tables:
no straddling state contains a live group, so no loop threat survives one. At the coarser
position level the same is true: no alive-chain position has any straddling entry.

---

## 5. Part 3 — winner's structure at 3×3: life without the centre

| quantity | count | denominator |
|---|---|---|
| positions where a colour is Benson-alive | 1,766 | 12,675 legal (883 per colour; colour-symmetric) |
| …with the alive colour having **no stone at the centre point** | **206** | 1,766 alive positions |
| …strict: centre completely empty | 182 | 206 |
| …opponent's stone at the centre instead | 24 | 206 |
| **modulo D4 (rotation/reflection)** | **38** | — |
| modulo D4 × colour-inversion | 19 | 38 (exactly 2:1 — every orbit's colour-inverse is distinct, consistent with zero two-life positions at 3×3) |

**Answer: yes — unconditional life at 3×3 exists without a centre stone.** The brief's
prediction is confirmed mechanically: the diamond `.x./x.x/.x.` (cells 1,3,5,7 — also "the
four-edge-midpoints shape"; both names denote the same cell set) is Benson-alive with an
empty centre; its orbit is present in the counted set (also the selftest positive control).
Distinct orbit representatives (canonical orientation):

```
.o.        .x.        oo.        xx.        o.o        x.x        ooo        ooo
o.o        x.x        o.o        x.x        o.o        x.x        o.o        x.x
.o.        .x.        .o.        .x.        .o.        .x.        .o.        .x.
```

The operator's stronger shape claim ("to establish a strong territory you need the centre")
is false at 3×3: 206 of 1,766 alive positions do without the centre, in 38 distinct shapes.

---

## 6. Controls and calibration (the brief's bars)

- **Null control** — empty 3×3 and lone corner stone report zero alive chains (selftest),
  and the committed 3×3 two-life = 0 cross-check passes.
- **Positive control** — the brief's 4×4 example (both colours alive), the 3×3 diamond, and a
  3×3 two-eye ring shape (all in selftest). The brief's example is additionally the
  colex-first two-life position at 4×4 (shown by `--twolife`).
- **Seeded-defect control** — three deliberately broken vitality predicates (never-alive,
  always-alive, White-blind); each trips the canary that the correct predicate passes
  (selftest). **Control gap (T398):** these mutants are substituted only into hand-built
  canary boards (`src/t393_census.zig:671-693`), never into the sweep — so no control
  proves the Z cell *can* report non-zero. The zero reading survives on the
  by-construction argument in §1 above, which is sound but is not a control. The
  general lesson: a control that exercises a predicate is not a control on the cell
  you report.
- **Synthetic Z-cell positive control (T398)** — a 2×2 fixture with a straddling entry
  planted on a position with a Benson-alive chain; the sweep reports `z_either == 1`,
  proving the Z cell reporting path is live.
- **Independent re-implementation** — every 1024th group compared
  `rules.benson_alive` against the independent `naive_benson_alive`: 13 groups (3×3) and
  23,749 groups (4×4), **0 mismatches** (the QA-023 rule: re-implementation is what finds
  defects).
- **Committed cross-checks, all reproduced** — 3×3 WZO2 groups/entries = 12,675/49,428 and
  L<H = 5,408 (T382); 3×3 pin_L == pin_H; 4×4 pin census = A4 baseline **MATCH**; 4×3
  two-life = 2 (T382 series); 4×4 two-life = 324 identically on the WZO1 checkpoint
  (`data/oracle-4x4.checkpoint.wzo`) and the WZO2 table — the position-level count is stable
  across the WZO1/WZO2 rule-family split.
- **Artifact hashes** — `data/oracle-3x3-v2.wzo2`
  `d79c17cd6fd00ba4608bdc5b86c9930a15d2a7050e2cdce07b0203f5aeaf7beb`, `data/oracle-4x4-v2.wzo2`
  `0c3366f07fb33c6f2838ead48ad3080b64dbe55935b87af4f140d81a29e4e15a` (the same artifact the
  battery cites), `artifacts/oracle-4x3.wzo`
  `5316f428ad821c79c5dcd62188c648d6455ffd2e698e9b5d49db93ae0a6ecad1`,
  `data/oracle-4x4.checkpoint.wzo`
  `a2174fedd6a0591dc66b0b42ef1f52bdc28b97c448dbc5b043d96de3a3b1e118`.
- All runs 2026-08-06, ReleaseFast under `tools/runner` (4 GB RSS guard).

---

**Landmark:** advances `L2 (proven 4×4 values)` — the bracketed region is now characterised
by territory structure: straddling states never contain unconditional life, and unconditional
life always certifies (L==H), at every size with a WZO2 table; the T382 zero-alive series is
complete through 4×4 (coexisting life begins at 4×3 with 2 positions; 324 at 4×4, one in
~75,000). What remains: the independent regeneration of the ko-sensitive columns (Track A);
this census is a categorical property of the stored table and survives ko-sensitive value
distrust unless the regeneration changes the L<H membership itself. Independent of
`T394 (can-force-life: a Boolean retrograde pass testing "loops are mutual territory-denial")`
— T393 is the static half of the operator's question; T394 is the forcible half.
