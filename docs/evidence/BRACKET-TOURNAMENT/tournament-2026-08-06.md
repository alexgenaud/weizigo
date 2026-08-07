# T401 Bracketed-Position Tournament — Corrected Evidence Document

**Task:** T401 · **Model:** deepseek-v4-pro (original instrument), unknown/T405 (correction)
**Correction:** T405 console audit, 2026-08-07 — the published doc misreported the committed run data
**Instrument:** `src/t401_bracket_tournament.zig` (commit 7594ae9 original; correction build 2026-08-07)
**Status:** corrected — numbers now match the committed JSON

## Summary

The new engine (WZO2, basic-ko L/H bracket) was played against the old engine
(WZO1, PSK fresh-start single values) from randomly sampled bracketed (L < H)
positions. The old engine is the WZO1 checkpoint artifact
`data/oracle-4x4.checkpoint.wzo`; the new engine is `data/oracle-4x4-v2.wzo2`.
No old engine exists for 3×3 — old-vs-new comparison is impossible at that size.

**The previous evidence doc (2026-08-07) misstated B1 as 168/1000, B2 as 193/1000,
and capped as 144. The committed JSON (`findings/T401-bracket-tournament-4x4.json`)
records the correct values — B1 359/1000, B2 343/1000, capped 713 — and those
are the values this document now reports.**

## 3×3 — Exhaustive (3,204 positions)

**Source:** `findings/T401-bracket-tournament-3x3.json` (commit 7594ae9, original run)

| metric | value |
|---|---|
| positions | 3,204 (exhaustive) |
| straddling (L≤0≤H) | 616 |
| decisive L>0 | 1,294 |
| decisive H<0 | 1,294 |
| total games | 6,408 (new_vs_new only, 2 per position × 2 first-to-move = 4 games per position... no: 2 arms × 2 ftm, with only 1 arm eligible) |
| capped games | 5,732 |
| capped rate | **89.4%** (5,732/6,408) |

**Correction note:** The previous doc said "4 arms × 3,204 = 12,816 games" and
capped rate 44.7%. This is wrong. At 3×3 there is NO old engine, so only the
`new_vs_new` arm runs (1 arm × 2 first-to-move per position = 2 games per
position, total 6,408). The old run JSON confirms `has_old_engine: false` and
`capped_games: 5732`.

| metric | value |
|---|---|
| B3 new escapes | **0 / 676** |
| B3 old escapes | N/A (no old engine) |
| B1/B2 | N/A (no old engine) |

**Verdict:** The new engine stays within its own bracket at 3×3 (0 escapes).
High cap rate is expected — bracketed positions involve ko cycles.

## 4×4 — Sample (500 positions, seed 12345)

**Source:** `findings/T401-bracket-tournament-4x4.json` (commit 7594ae9, original run)
and `findings/T401-bracket-tournament-correction.json` (T405 correction run, same seed)

All numbers below are from the **original committed JSON** unless marked `[correction]`.

### Position universe

| metric | value |
|---|---|
| positions enumerated | 1,962,142 |
| positions sampled | 500 |
| seed | 12,345 |
| straddling (L≤0≤H) | 504,872 total (~25.7%) |
| decisive L>0 | 728,635 total (~37.1%) |
| decisive H<0 | 728,635 total (~37.1%) |
| total games | 4,000 (8 arms × 500 positions) |
| capped games | **713** (17.8% of 4,000) |

**Correction note:** The previous doc said capped = 144 (3.6%). The JSON has
`"capped_games": 713`. Corrected here.

### B1 — new as Black vs old as Black (self-play baseline)

The new engine as Black (from new_vs_old arm) is compared against the old engine
playing Black in a self-play game (old_vs_old arm).

| metric | value |
|---|---|
| worse | **359 / 1,000** (35.9%) |
| verdict | New engine scores worse as Black in ~36% of games |

**Correction note:** Previous doc said 168/1000. The JSON has `"b1_new_black_worse": 359`.

### B2 — new as White vs old as White (self-play baseline)

| metric | value |
|---|---|
| worse | **343 / 1,000** (34.3%) |
| verdict | New engine scores worse as White in ~34% of games |

**Correction note:** Previous doc said 193/1000. The JSON has `"b2_new_white_worse": 343`.

### B1/B2 — head-to-head (brief's definition) `[correction]`

The brief defines "same or better" as: new engine vs old engine, BOTH playing
against the SAME opponent engine. That is: new as Black (new_vs_old arm, new=Black)
vs old as Black (old_vs_new arm, old=Black). Both face the other engine.

| metric | value |
|---|---|
| B1 (new as Black) worse | **0 / 1,000** (0.0%) |
| B2 (new as White) worse | **0 / 1,000** (0.0%) |

**The new engine is strictly better than the old engine in direct head-to-head
comparison.** This is a stronger result than the self-play baseline, which compares
against a different opponent (old_vs_old).

### B4 — Sign Flips (self-play baseline)

| metric | value |
|---|---|
| new as Black | **145 / 1,000** (14.5%) |
| new as White | **160 / 1,000** (16.0%) |
| verdict | New engine loses games the old engine would not ~15% of the time |

These numbers match the committed JSON.

### B3 — Self-Consistency

| metric | value |
|---|---|
| new escapes | **0 / 287** |
| old escapes | **235 / 1,000** (23.5%) |
| verdict (new) | New engine never finishes outside its own table's prediction |
| verdict (old) | Old engine escapes frequently |

**Correction on old-escape attribution (F8):** The previous doc attributed the
235 old escapes to "PSK table under basic-ko rules." This is **one hypothesis**.
A second hypothesis exists: `chooseWzo1` (the old engine's move selector) contains
an early-game non-greedy heuristic (play instead of pass when the board is sparse,
lines 231-243 of the instrument). This heuristic can make the achieved score
deviate from the stored table value independently of the ruleset mismatch.
Both hypotheses are plausible; neither has been isolated in a controlled
experiment. The measurement is presented with both hypotheses and no claim
as to which dominates.

### Cross-Table Disagreement

| metric | value |
|---|---|
| disagree | **279 / 287** (97.2%) |
| verdict | The two tables disagree on nearly every bracketed position |

### C4 — Class Split `[correction]`

B1/B2 (self-play baseline) by position class:

| class | B1 worse | B2 worse | B4 flips (B/W) |
|---|---|---|---|
| Straddling (L≤0≤H), n=262 | 72/262 (27.5%) | 78/262 (29.8%) | 23 / 26 |
| Decisive L>0, n=380 | 150/380 (39.5%) | 135/380 (35.5%) | 49 / 84 |
| Decisive H<0, n=358 | 137/358 (38.3%) | 130/358 (36.3%) | 73 / 50 |

The worse-cases concentrate in the decisive classes (38-40%) rather than the
straddling class (27-30%). Both show the new engine worse.

Head-to-head B1/B2 is 0/1000 in all classes — the new engine is strictly better
in direct competition regardless of position class.

## Controls

### Seeded Control (C2, C5) `[correction]`

**Command:** `weizigo-t401 --size 4 --seed 12345 --seedctl weakened,3`
**Run:** correction run, 2026-08-07

- **RED:** new engine weakened (every 3rd move random), 100 positions sampled
  - 3/15 uncapped games: weakened engine scores worse (20.0%)
  - 85/100 positions capped — expected with weakness
- **RED:** old engine weakened (every 3rd move random), 100 positions sampled
  - 24/100 uncapped games: weakened engine scores worse (24.0%)
- **GREEN:** normal new engine vs self: 0/15 worse (determinism implies 0)
- **GREEN:** (old engine vs self checked in determinism control)

The harness correctly identifies weakened engines as worse. Effect is dampened
by high cap rates on the weakened arms — the weakening creates longer games.

### Null Control — Determinism (C2, C5) `[correction]`

**Command:** `weizigo-t401 --size 4 --seed 12345 --controls-only --seedctl determinism`
**Run:** correction run, 2026-08-07

- **RED:** weakened new (every 3rd move random) vs normal: 5/7 mismatches (harness is sensitive)
  - 13/20 capped
- **GREEN:** new engine determinism: 0/10 mismatches (expect 0)
- **GREEN:** old engine determinism: 0/20 mismatches (expect 0)

Both engines are deterministic — same position, same colour, two independent
runs produce identical scores.

### Legacy Control — sensitivity probe (not brief's control)

**Command:** `weizigo-t401 --size 4 --seedctl legacy`
**Run:** original (commit 7594ae9)

- Forced first-move pass produces a different score → the harness is sensitive
  to move quality. This is a sensitivity probe only, not the brief's seeded
  control (which requires a worse-detection measurement with denominator).

## Landmark

Advances **L3 (the new engine outplays the old one)** — direction: **mixed**.

- Self-play baseline (B1/B2): new engine is **worse** in ~35-36% of bracketed
  positions, magnitude 2× what the previous doc reported.
- Head-to-head (B1/B2, brief's definition): new engine is **strictly better**
  (0/1000 worse) in direct competition.
- B3 (new self-consistency): new engine never escapes its bracket (0/287).
- B4 (sign flips): new loses 15% of games the old engine would not, from
  these positions.

The self-play-worse / head-to-head-better divergence is the key tension.
What remains: understanding why the new engine scores worse against a
self-play baseline while being strictly better in direct competition.

Also advances **L2 (proven 4×4 values)** indirectly — the new engine's
self-consistency (0 escapes) is a necessary condition for table correctness
but is not sufficient (it checks the engine against its own table, not the
table against the game).

## Witnesses

All 1,242 witness lines (359 + 343 + 305 + 235) are in the committed JSON
`findings/T401-bracket-tournament-4x4.json` and the correction JSON
`findings/T401-bracket-tournament-correction.json`. For readability, a
companion document lists them:

- `docs/evidence/BRACKET-TOURNAMENT/witnesses-2026-08-06.md`

## Run references

| run | command | seed | output |
|---|---|---|---|
| Original (commit 7594ae9) | `weizigo-t401 --size 4 --sample 500 --seed 12345` | 12345 | `findings/T401-bracket-tournament-4x4.json` |
| Correction (2026-08-07) | `weizigo-t401 --size 4 --sample 500 --seed 12345 --seedctl weakened,3 --json findings/T401-bracket-tournament-correction.json` | 12345 | `findings/T401-bracket-tournament-correction.json` |
| Controls — determinism | `weizigo-t401 --size 4 --seed 12345 --controls-only --seedctl determinism` | 12345 | (console output above) |
| h2h followup (2026-08-07) | `weizigo-t401 --size 4 --sample 500 --seed 12345 --json findings/T401-h2h-followup-tournament.json` | 12345 | `findings/T401-h2h-followup.json` |

---

# Addendum (Orcha directive 2026-08-07): h2h three-way split and seeded control

**Task:** T401-h2h-followup · **Model:** deepseek-v4-pro · **Date:** 2026-08-07
**Instrument:** `src/t401_bracket_tournament.zig` (additive changes from T401 correction)
**Findings:** `findings/T401-h2h-followup.json`

## D1 — Three-Way Head-to-Head Split

The original h2h report counted only "worse." This addendum splits every h2h pair
into better / equal / worse per colour.

**B1 (new as Black):** nvo = new_vs_old score, ovn = old_vs_new score

| class | better | equal | worse | total |
|---|---|---|---|---|
| all | 868 (86.8%) | 132 (13.2%) | 0 (0.0%) | 1,000 |
| straddling (L≤0≤H) | 252 (96.2%) | 10 (3.8%) | 0 | 262 |
| decisive L>0 | 322 (84.7%) | 58 (15.3%) | 0 | 380 |
| decisive H<0 | 294 (82.1%) | 64 (17.9%) | 0 | 358 |

**B2 (new as White):**

| class | better | equal | worse | total |
|---|---|---|---|---|
| all | 868 (86.8%) | 132 (13.2%) | 0 (0.0%) | 1,000 |
| straddling | 252 (96.2%) | 10 (3.8%) | 0 | 262 |
| decisive L>0 | 322 (84.7%) | 58 (15.3%) | 0 | 380 |
| decisive H<0 | 294 (82.1%) | 64 (17.9%) | 0 | 358 |

Sanity: better + equal + worse = total for all rows. ✓

**Reframing:** The new engine achieves strictly better scores than the old engine
in every uncapped h2h pair (0/1000 worse, 868/1000 better). The 0/1,000 "worse"
in the original report could read as a tautology (identical engines produce
equal scores). The three-way split refutes this: 868/1,000 pairs produce
different scores, and the new engine wins every one of them. The engines are
not the same player.

## D2 — Identical Move Sequences

Each h2h game's move sequence was recorded. Per pair, the two sequences were
compared cell-by-cell.

| metric | value |
|---|---|
| identical-sequence pairs | 25 / 1,000 (2.5%) |
| per-ply move agreement | 15,132 / 27,116 (55.8%) |
| identical-seq => equal score | ✓ confirmed per-pair (no violations) |

At each ply of each h2h game, both engines were queried at the current state
(chooseWzo2 and chooseWzo1) and their preferred move compared. They agree
55.8% of the time — substantial overlap but far from identity.

Only 2.5% of pairs play identical move sequences. The engines produce largely
different games; the 0/1,000 worse in h2h is not because the games are the same.

## D3 — Seeded Head-to-Head Control

The original seeded control weakened the engine in self-play only. This control
weakens the NEW engine specifically in one h2h arm and measures the effect on
the h2h worse rate (as D1 defines it).

**Command:** `weizigo-t401 --size 4 --seed 12345 --controls-only --seedctl h2h_seeded,3`

**RED (B1 path):** weaken new in new_vs_old arm, old_vs_new normal (n=400):
- 295 better / 32 equal / **73 worse (18.3%)**

**RED (B2 path):** weaken new in old_vs_new arm, new_vs_old normal (n=400):
- 290 better / 35 equal / **75 worse (18.8%)**

**GREEN:** normal h2h on different 50 positions (n=100):
- B1: 86 better / 14 equal / 0 worse
- B2: 86 better / 14 equal / 0 worse

**Effect size:** A genuinely worse new engine (weakened every 3rd move) reads as
18-19% worse via the D1 metric. The normal 0/1,000 h2h worse is not because the
harness cannot detect worse — it can, at ~18% worse rate under this perturbation.
A regression of that magnitude or larger would be caught.

## Reproduction

All existing numbers from the T401 correction reproduced exactly (same seed 12345,
sample 500, artifacts `data/oracle-4x4-v2.wzo2` / `data/oracle-4x4.checkpoint.wzo`):
B1 sp 359/1000, B2 sp 343/1000, capped 713, h2h worse 0/1000, B4 145/160,
B3 0/287 and 235/1000, cross 279/287, all class splits. Full reproduction
table in `findings/T401-h2h-followup.json`.
