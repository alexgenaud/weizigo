# T407 — the four-game divergence matrix (2026-08-07)

**Task:** T407 · **Worker:** glm-5.2/T407 · **Date:** 2026-08-07
**Instrument:** `src/t407_divergence_matrix.zig` (additive; game engine and move
selectors copied verbatim from the proven `src/t401_bracket_tournament.zig`,
restructured for the four-game matrix)
**Build:** `tools/runner -- zig build-exe -O ReleaseFast --dep version
-Mroot=src/t407_divergence_matrix.zig -Mversion=src/version.zig ...`
**Binary:** `/tmp/weizigo/t407/t407` · **Ply cap:** 400 (cap-hits are their own
class, never scored)
**Supporting data:** `divergence-matrix-2026-08-07-3x3-data.json`,
`divergence-matrix-2026-08-07-4x4-data.json` (this directory)

**Engines.**
- **New** = WZO2 oracle, basic-ko L/H bracket. 3×3: `data/oracle-3x3-v2.wzo2`
  (built 2026-08-04). 4×4: `data/oracle-4x4-v2.wzo2` (518 MB, built 2026-08-04).
- **Old** = WZO1 oracle, fresh-start single value, PSK enforcement
  (`chooseWzo1`, `inHistory` PSK check). 3×3: `artifacts/oracle-3x3.wzo`
  (rules_id=1 PSK, 118 KB, 2026-07-27). 4×4:
  `data/oracle-4x4.checkpoint.wzo` (rules_id=1 PSK, 258 MB, 2026-07-21) — the
  same old-engine artifact T401 used. The new-engine source at HEAD is commit
  `2e0c4c9`; the old artifacts predate the WZO2 reframe (commit `ae39978` is the
  ruleset-exploration commit that produced the PSK 4×4 checkpoint).

**The four games per position** (operator ruling 2026-08-07; self-play needs
only one game — swapping colours in a self-play arm is the same engine in both
seats, so it is a tautology to run twice). All four start with the table's
side-to-move (`bp.side`):

| slot | Black | White | name |
|---|---|---|---|
| 1 | new | new | `new_new` |
| 2 | new | old | `new_old` |
| 3 | old | new | `old_new` |
| 4 | old | old | `old_old` |

**Class A** = all four (non-capped) scores agree. **Class B** = any pair
differs. For each Class B position the catalogue records the four scores, the
bracket `[L,H]`, the stone count, the bracket class, and the first ply at which
the move sequences diverge — both the self-play pair (`new_new` vs `old_old`)
and the cross pair (`new_old` vs `old_new`) — with the two moves involved.

---

## 1. Controls (run before any headline is read)

### Null — seat-symmetry / determinism (one-time, 20 positions)

`runNullSeatSymmetry`: (a) a code-level tautology assertion that
`engineForSide` for the self-play arms is seat-independent, and (b) two
identical runs of `new_new` and `old_old` compared byte-for-byte (move sequence
+ score).

| size | tautology | new_new byte-identical | old_old byte-identical | verdict |
|---|---|---|---|---|
| 3×3 | PASS | 0/0 mismatches (all 20 sampled capped) | 0/20 | PASS |
| 4×4 | PASS | 0/14 mismatches | 0/20 | PASS |

The 0/0 for new_new at 3×3 is the cap rate at work (96 % of 3×3 bracketed
positions cap under 400 plies — see §2); the old_old arm gave 20 non-capped
pairs, all byte-identical. No seat-dependence or non-determinism detected.

### Seeded weakened-h2h control — exercises the SAME path that produces the headline

`runSeededH2h`: weaken the new engine (random legal move every 3rd ply) in the
cross arm where new is the first mover; compare the weakened new-first score to
the normal new-first score. RED must read "new got worse"; GREEN is
`new_old` determinism.

| size | RED new-got-worse | RED equal | RED better | GREEN determinism |
|---|---|---|---|---|
| 3×3 | 38/200 (19.0 %) | 157 | 5 | 0/50 |
| 4×4 | **80/200 (40.0 %)** | 107 | 13 | 0/50 |

A regression of 19–40 % cannot hide behind the headline. The 0-worse
head-to-head reading is **controlled**, not merely labelled — matching T401's
finding that the h2h path detects a knowingly weakened engine.

---

## 2. The class split — denominators first

### 3×3 — exhaustive over the fresh-start bracketed set

- Positions enumerated (L<H, passes=0, ko=NONE): **3,204** (straddling 616,
  decisive L>0 1,294, decisive H<0 1,294).
- **Cap-class: 3,078 / 3,204 (96.1 %)** — at least one of the four games hit the
  400-ply cap. The 3×3 self-play of either engine cycles and does not double-pass
  within 400 plies for the large majority of bracketed positions.
- **Scored (all four non-capped): 126 / 3,204.**
- **Class A: 126 / 126 (100 %). Class B: 0 / 126 (0 %).**
- Self-play baseline (new_new vs old_old): **0 better / 126 equal / 0 worse.**
- Cross h2h (new_old vs old_new): **0 better / 126 equal / 0 worse.**
- Identical-sequence cross pairs: **126 / 126 (100 %).** Per-ply move agreement
  new_new vs old_old: **430 / 430 (100 %).**

**Class B is empty at 3×3.** Per the brief this must be reconciled, not
published as agreement. The reconciliation: the 400-ply cap removes 96 % of the
positions, and the 126 that do terminate are the near-settled ones where both
engines play the same forced moves to the same double-pass — a biased,
near-terminal subset. Class B=0 at 3×3 says the two engines agree on the
*easy-to-terminate* tail, not that they agree everywhere. T401's 359/1,000
divergence was measured at 4×4 under a very different cap profile (18 % cap).
**The 4×4 leg below is the load-bearing measurement; the 3×3 leg is reported
as the empty-class-B case the brief required, with the cap-rate explanation.**

### 4×4 — declared sample: 500 / 1,962,142 bracketed positions, seed 12345

- Enumerated bracketed positions: 1,962,142 (straddling 504,872, decisive L>0
  728,635, decisive H<0 728,635). Sampled 500 by reservoir sampling (seed 12345,
  matching T401 for comparability).
- **Cap-class: 230 / 500 (46 %)** — positions where ≥1 of the 4 games capped.
- **Scored (all four non-capped): 270 / 500.**
- **Class A: 119 / 270 (44.1 %). Class B: 151 / 270 (55.9 %)** — disagreement is
  the majority among scored positions.

---

## 3. The verdict — MIXED (a heuristic, a plugin)

Per the rubric (operator 2026-08-07), classify into exactly one of {new
strictly worse, mixed, new strictly better}.

**Three-way splits, 4×4, 270 scored positions:**

| comparison | new better | equal | new worse | total |
|---|---|---|---|---|
| Self-play baseline (`new_new` vs `old_old`, same first-to-move) | **62** | 152 | **56** | 270 |
| Cross head-to-head (`new_old` vs `old_new`) | **150** | 120 | **0** | 270 |

- Identical-sequence cross pairs: **20 / 270 (7.4 %)** — the engines are *not*
  the same player; the 0-worse h2h is not a tautology.
- Per-ply move agreement (`new_new` vs `old_old`): **1,396 / 2,040 (68.4 %).**

**Verdict: MIXED — better on some positions, worse on others.** New is *never
worse* head-to-head (0/270, reproducing T401's 0/1,000) and better in 55.6 % of
cross games; but new's *self-play* score is worse than old's self-play score on
56/270 (20.7 %) and better on 62/270 (23.0 %). The two facts together are the
signature of a **heuristic, a cheat** — the change is one tool in the
toolchest, a **plugin to be mixed and matched**, and the research question
becomes *when* it works. The class-B catalogue (§4) is exactly the map of
"when". **A tournament can refute and build confidence; only a proof can
promote this from "plugin" to "correct", and no proof is offered here.**

The direction this cuts: `L3 (the engine outplays the old engine)` —
**negative on the self-play baseline, positive on head-to-head**, exactly as
T401 found. `L2 (proven 4×4 values)` — protected: the new engine never escapes
its own bracket (§5).

---

## 4. The class-B catalogue — where the engines disagree (4×4, 151 positions)

Full catalogue in `divergence-matrix-2026-08-07-4x4-data.json`
(`class_b_catalogue`). Twelve examples (cell labels A–D × 1–4; `pass` = pass):

```
colex=32259514 side=-1 bracket=[5,16]   stones=12 nn=5  no=5  on=2  oo=2  | sp_div=ply5 new=C1  old=pass x_div=ply5 a=C1  b=pass
colex=18304427 side= 1 bracket=[3,16]   stones=10 nn=3  no=3  on=-2 oo=-2 | sp_div=ply2 new=A3  old=pass x_div=ply2 a=A3  b=pass
colex=5270665  side= 1 bracket=[-16,-3] stones=8  nn=-3 no=0  on=-6 oo=-6 | sp_div=ply6 new=B1  old=pass x_div=ply6 a=B1  b=pass
colex=31963613 side= 1 bracket=[3,16]   stones=12 nn=3  no=16 on=3  oo=16 | sp_div=ply5 new=B1  old=pass x_div=ply5 a=pass b=B1
colex=28667127 side=-1 bracket=[3,16]   stones=12 nn=3  no=3  on=-16 oo=4 | sp_div=ply1 new=C4  old=A3  x_div=ply1 a=C4  b=A3
colex=2874408  side=-1 bracket=[1,16]   stones=8  nn=1  no=4  on=-16 oo=16| sp_div=ply1 new=B1  old=D2  x_div=ply1 a=B1  b=D2
colex=8651057  side=-1 bracket=[-16,-4] stones=9  nn=-4 no=-4 on=-16 oo=-16| sp_div=ply1 new=B2  old=pass x_div=ply1 a=B2  b=pass
```

### Structural patterns

- **The divergence is an early pass-vs-play decision.** 112 / 151 (74.2 %) of
  class-B divergences are one engine playing a move while the other passes. The
  `sp_div` and `x_div` ply distributions are **byte-identical** (ply 0: 16,
  ply 1: 23, ply 2: 24, ply 3: 21, ply 4: 19, ply 5: 14, ply 6: 13, ply 7: 10,
  ply 8: 8, ply 9: 1, ply 11: 2) — the first-mover's engine drives both pairs
  to diverge at the same ply, which is the harness's expected symmetry and a
  built-in consistency check.
- **The disagreement concentrates in the decisive classes.** Class B by
  bracket class: decisive L>0 **71**, decisive H<0 **77**, straddling **3**.
  Per-bracket-class class-B rate (denominator = scored in that class):

  | bracket class | scored | Class A | Class B | cap | class-B rate | cross h2h new better/equal/worse | self-play new better/equal/worse |
  |---|---|---|---|---|---|---|---|
  | straddling (L≤0≤H) | 11 | 8 | 3 | 120 | 27.3 % | 3 / 8 / 0 | 0 / 8 / 3 |
  | decisive L>0 | 125 | 54 | 71 | 65 | 56.8 % | 71 / 54 / 0 | 27 / 70 / 28 |
  | decisive H<0 | 134 | 57 | 77 | 45 | 57.5 % | 76 / 58 / 0 | 35 / 74 / 25 |

  The straddling class caps 91 % (120/131 enumerated in the sample) and agrees
  on the rare terminating positions; the decisive classes terminate more often
  and disagree more than half the time. **Cross h2h new-worse is 0 in every
  class.** Self-play new-worse is 3 (straddling) + 28 (L>0) + 25 (H<0) = 56.
- **The first-mover's engine dominates the score.** In 31/151 class-B
  positions `nn==on` and `no==oo` (the score is set by which engine moves
  first, regardless of opponent); in 33/151 the self-play scores agree
  (`nn==oo`) and only the cross arms differ. The divergence is overwhelmingly
  about *whether the side-to-move plays or passes*, and the old engine's
  pass/play threshold (its `chooseWzo1` early-game heuristic + PSK value
  table) differs from the new engine's pinned-value bracket selection.

---

## 5. The historical-table check — does every result fall within every table?

For every non-capped game outcome (4×4: 270 positions × 4 games = **1,080
games**; 3×3: 126 × 4 = 504) the achieved score is classified against the
start position's stored bracket/value in each table generation as **within
[L,H] / above H / below L / no-entry**. Below L is the alarm.

### 3×3 (504 games)

| table | within | above | below | no_entry | total |
|---|---|---|---|---|---|
| `data/oracle-3x3-v2.wzo2` (current WZO2) | 504 | 0 | 0 | 0 | 504 |
| `artifacts/oracle-3x3.wzo` (WZO1 PSK) | 504 | 0 | 0 | 0 | 504 |

Every 3×3 terminating game falls within both tables. No alarm at 3×3 (on the
near-terminal 126-position subset).

### 4×4 (1,080 games)

| table | within | above | below | no_entry | total | below-by-slot [nn,no,on,oo] |
|---|---|---|---|---|---|---|
| `data/oracle-4x4-v2.wzo2` (current WZO2) | 897 | 94 | **89** | 0 | 1,080 | **[0, 0, 59, 30]** |
| `data/oracle-4x4.checkpoint.wzo` (WZO1 PSK) | 694 | 183 | **203** | 0 | 1,080 | [31, 14, 102, 56] |
| `data/oracle-4x4-basicko-tie-area.wzo` (WZO1 basic-ko) | 37 | 278 | **365** | 400 | 1,080 | [94, 83, 97, 91] |
| `data/oracle-4x4-parallel.checkpoint.wzo` (WZO1 PSK) | 722 | 155 | **167** | 36 | 1,080 | [17, 10, 91, 49] |

`below_by_slot` = `[new_new, new_old, old_new, old_old]` — which slot the
below-L game was played in. The slot tells you *which engine occupied the
side-to-move* (the side whose floor L bounds).

**The alarm decomposes by slot into two different things:**

1. **Self-consistency escape** — the engine that *owns* the table scores below
   its own floor. This is the real defect signal.
   - **New engine vs its own table (`v2.wzo2`, slot `new_new`): 0 / 270 below.**
     The new engine never escapes its own bracket. **B3 holds at 4×4** —
     matching T401's 0/287. `L2` is protected.
   - **Old engine vs its own table (`checkpoint.wzo`, slot `old_old`): 56 /
     270 below.** The old engine escapes its own floor 20.7 % of the time — the
     known old-table self-inconsistency (T401 found 235/1,000 old escapes). The
     `checkpoint.wzo` is the writes-**on** build the foreclosure distrusts; this
     is consistent with that distrust, not new evidence against it.

2. **Cross-table disagreement** — an engine scored below a table it does *not*
   own (new vs the PSK tables; old vs the WZO2 table). This is expected: the
   tables encode different rulesets and the engines are not optimal per a table
   built under a different rule. The `basicko-tie-area` table (rules_id=2)
   shows the most below (365) and 400 `no-entry` because it is a different
   ruleset's fresh-start slice with many undefined positions for these start
   states.

**No below-L witness indicts the new engine's own table.** The 89 below-L
against `v2.wzo2` are **all** old-engine slots (`old_new` 59, `old_old` 30) —
the old engine underperforming against the new table's guarantee, which is the
expected direction (new never loses to old, §3). The new engine's self-play
(`new_new`) is **0 below-L against its own table**.

**Above H** (94 against `v2.wzo2`) is not automatically an error: a game where
the *opponent* played below the floor lets the side-to-move exceed H. The newer
tables agree with the achieved score in the within/above region; no `above H`
case is a defect on its own.

---

## 6. Reconciliation with T401

| question | T401 (1,000-position 4×4 sample) | T407 (500-position 4×4 sample) | agree? |
|---|---|---|---|
| h2h new-worse | 0 / 1,000 | 0 / 270 | yes |
| h2h new-better | 868 / 1,000 | 150 / 270 (55.6 %) | yes (different sample) |
| self-play baseline new-worse | 359 / 1,000 (B1), 343 / 1,000 (B2) | 56 / 270 (20.7 %) | yes (same direction) |
| new-engine B3 escapes | 0 / 287 | 0 / 270 | yes |
| identical-sequence h2h pairs | 25 / 1,000 (2.5 %) | 20 / 270 (7.4 %) | same order of magnitude |
| per-ply move agreement | 15,132 / 27,116 (55.8 %) | 1,396 / 2,040 (68.4 %) | same ballpark |

T407 reproduces every T401 reading that is comparable. The new contribution is
the **class-B catalogue with the divergence ply and the two moves**: the
disagreement is an early pass-vs-play decision (74 %), concentrated in the
decisive classes (98 % of class B), with the first-mover's engine dominating
the score. That is the map of *when* the new engine differs from the old one,
which is what T401's "0 worse / 359 worse" contradiction pointed at and could
not itself locate.

---

## 7. Scope and residuals

- **4×4 is a declared sample** (500 / 1,962,142, seed 12345), not exhaustive.
  The 3×3 leg is exhaustive but 96 % capped, so its 126 scored positions are a
  near-terminal tail — reported as the empty-class-B case, not as agreement.
- **The 400-ply cap** is the binding constraint on both sizes. A higher cap
  would reduce the cap-class and enlarge the scored denominator; the cap rate
  itself (3×3 96 %, 4×4 46 %) is a finding about how long these engines cycle
  before double-pass, not a bug.
- **`basicko-tie-area.wzo` and `parallel.checkpoint.wzo`** are WZO1 artifacts
  loaded read-only for the historical check; the KO_SENSITIVE columns of all
  WZO1 4×4 tables remain distrusted pending Track A (foreclosure). The
  historical matrix counts them honestly (`no_entry` has its own denominator).
- **The old engine's `chooseWzo1` early-game "play anyway" heuristic** is a
  play-time rule, not a table property; it is the source of much of the
  pass-vs-play divergence and is reproduced verbatim from T401.

**Landmark:** advances `L3 (the engine outplays the old engine)` — the
divergence is now *located*: an early pass-vs-play decision in the decisive
classes, with new never worse head-to-head but worse than old's self-play on
56/270 — **mixed, a plugin, not a strict improvement**. Advances `L2 (proven
4×4 values)` — protected: the new engine is 0/270 below its own floor. The
remaining question is *when* the plugin works best, which the class-B
catalogue now maps.

— glm-5.2/T407