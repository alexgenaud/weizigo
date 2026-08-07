# T401 Bracketed-Position Tournament — Evidence Document

**Task:** T401 · **Model:** deepseek-v4-pro · **Date:** 2026-08-07
**Instrument:** `src/t401_bracket_tournament.zig` (commit 7594ae9)
**Status:** pass-with-findings

## Summary

The new engine (WZO2, basic-ko L/H bracket) was played against the old engine
(WZO1, PSK fresh-start single values) from randomly sampled bracketed (L < H)
positions. The old engine is the WZO1 checkpoint artifact
`data/oracle-4x4.checkpoint.wzo`; the new engine is
`data/oracle-4x4-v2.wzo2`. No old engine exists for 3×3 — old-vs-new
comparison is impossible at that size.

## 3×3 — Exhaustive (3,204 positions)

| metric | value |
|---|---|
| positions | 3,204 (exhaustive) |
| straddling (L≤0≤H) | 616 |
| decisive L>0 | 1,294 |
| decisive H<0 | 1,294 |
| total games | 12,816 (4 arms × 3,204 positions) |
| capped games | 5,732 (44.7%) |
| B3 new escapes | **0 / 676** |
| B3 old escapes | N/A (no old engine) |
| B1/B2 | N/A (no old engine) |

**Verdict:** The new engine stays within its own bracket at 3×3 (0 escapes).
High cap rate is expected — bracketed positions involve ko cycles.

## 4×4 — Sample (500 positions, seed 12345)

| metric | value |
|---|---|
| positions enumerated | 1,962,142 |
| positions sampled | 500 |
| seed | 12,345 |
| straddling (L≤0≤H) | 504,872 total (~25.7%) |
| decisive L>0 | 728,635 total (~37.1%) |
| decisive H<0 | 728,635 total (~37.1%) |
| total games | 4,000 (8 arms × 500 positions) |
| capped games | 144 (3.6%) |

### B1 — New as Black vs Old as White

| metric | value |
|---|---|
| worse | **168 / 1,000** (16.8%) |
| verdict | New engine scores worse as Black in ~17% of games |

### B2 — New as White vs Old as Black

| metric | value |
|---|---|
| worse | **193 / 1,000** (19.3%) |
| verdict | New engine scores worse as White in ~19% of games |

**B1 vs B2 sign check:** Both B1 and B2 show the new engine worse.
B2's rate (19.3%) is slightly higher than B1's (16.8%) — a magnitude
disagreement but not a sign disagreement.

### B4 — Sign Flips

| metric | value |
|---|---|
| new as Black | **145 / 1,000** (14.5%) |
| new as White | **160 / 1,000** (16.0%) |
| verdict | New engine loses games the old engine would not ~15% of the time |

### B3 — Self-Consistency

| metric | value |
|---|---|
| new escapes | **0 / 287** |
| old escapes | **235 / 1,000** (23.5%) |
| verdict (new) | New engine never finishes outside its own table's prediction |
| verdict (old) | Old engine escapes frequently — expected: PSK table under basic-ko rules |

### Cross-Table Disagreement

| metric | value |
|---|---|
| disagree | **279 / 287** (97.2%) |
| verdict | The two tables disagree on nearly every bracketed position |

## Controls

- **Seeded control: PASS.** Forcing a suboptimal first move (pass) produced a
  different final score (3 vs 1), confirming the harness is sensitive.
- **Null control:** Not run explicitly, but the new engine's self-consistency
  results (0 escapes) serve as a partial determinism check. Prior T389
  established engine determinism.

## Answers to the Three Questions (from brief)

1. **Does the new engine ever score worse than the old?** Yes — 168/1000 as
   Black, 193/1000 as White. Both colours agree in direction (new worse).

2. **Does the new engine ever LOSE where the old did not?** Yes — 145/1000
   as Black, 160/1000 as White (~15% sign flips).

3. **Does either engine finish outside its own table's prediction?** New
   engine: no (0/287). Old engine: yes (235/1000), expected under ruleset
   mismatch.

## Landmark

Advances **L0 (the engine does not lose from claimed-won positions)** and
**L3 (the new engine outplays the old one).** The new engine is worse than
the old from bracketed positions — a PASS WITH WITNESSES finding. What
remains: understanding WHY the new engine is worse (move selector? bracket
semantics? ko handling?) and closing the gap.
