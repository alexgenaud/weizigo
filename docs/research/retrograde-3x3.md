# Retrograde engine prototype: L/H value iteration measured (2026-07-19/20)

First running implementation of ADR-0009 (`src/retro.zig`): successor-sweep
value iteration with two-sided (L/H) certification, ko-sensitive residue
finisher, DTT, and the validation battery. All numbers ReleaseFast on the dev
machine; reproduce with `zig run -O ReleaseFast src/retro.zig` (env
`RETRO_DIAG=1` for the residue-orbit census, `RETRO_ANCHOR=1` for the 3x3
anchor probe, `RETRO_3X3=1` for the 3x3 board alone).

## Finding 1: the retrograde core is FAST and converges in a handful of sweeps

| board | slots | legal | settled | sweeps | build+certify |
|---|---|---|---|---|---|
| 2x2 | 81 | 57 | 4 | 2 | <1 ms |
| 3x2 | 729 | 489 | 30 | 6 | 1 ms |
| 3x3 | 19,683 | 12,675 | 262 | 12 | ~130 ms |

Contrast: FORWARD fresh-start filling of the same 3x3 table was measured
INTRACTABLE (years; `research/oracle-3x3.md`). The value-iteration core is
not the cost at these scales — building AND certifying the whole 3x3 table is
~0.1 s. All the cost is in the ko-sensitive residue (Findings 3, 6).

## Finding 2: cross-root memo reuse is ORDER-DEPENDENT (measured, then fixed)

The first finisher implementation carried ordinary (`ko_ref`-clean) memo
writes ACROSS residue roots. At 2x2 this produced an ASYMMETRIC table
(exhaustive dihedral check: 116 failures) — direct empirical proof that a
fresh-start interior value is not valid under another root's history (the
ADR-0008 GHI residue), even when each value is individually "clean". Fix: each
residue root gets a fresh copy of the certified-only baseline, and only one
representative per symmetry orbit is solved (the orbit is filled by the proven
transforms). After the fix: symmetry PASS (0 failures across inversion,
dihedral, L/H-swap, flags at every board), orbit-clashes 0, bracket-fails 0.

Consequence for any future engine work: NEVER share ko_ref-clean memo entries
between roots. Within one root it is the validated solve.zig discipline;
across roots it is unsound and MEASURABLY so at 2x2 density.

## Finding 3: HISTORY-EXACT solving is the intractable thing itself

`retro.Exact` is a gold-standard forward solver whose memo key includes the
FULL positional-superko ban set (a bitset over the colex space): sound by
construction, no ko_ref rule, no GHI assumption, memo shareable across roots.
Measured at 2x2 — nine cells fewer than the "smallest interesting" board:

- The EMPTY 2x2 root alone exceeded the **3.0e7-state map cap** and did not
  complete under a 3M-node-per-root budget.
- Nearly every DFS path creates a unique ban set, so the exact memo's hit rate
  is negligible where it matters — memoization does not tame the exact game.
- Deepest-layer-first with a per-root budget: only the near-terminal roots
  complete (2x2: 8 of 114; 3x2: 68 of 600), all with **zero mismatches** and
  every value inside its [L,H] bracket.

This is the GHI problem's cost measured directly: the history-dependence IS
the entire cost of solving Go with superko. It closes the question of whether
some cleverer exact-forward scheme could have built the oracle — the exact
state space explodes before the position space does. Nodal certification +
bounded finishing (ADR-0009) is not an optimization but the only viable route.

## Finding 4: the ko-sensitive residue is LARGE on toy boards but SHRINKS

| board | legal/side | residue/side | fraction | orbit reps (B/W) |
|---|---|---|---|---|
| 2x2 | 57 | 41 | 72% | 6 / 3 |
| 3x2 | 489 | 189 | 39% | 33 / 24 |
| 3x3 | 12,675 | 4,349 | 34% | 375 / 247 |

Tiny boards are almost pure ko machines (little is Benson-settled, captures
recur constantly), so L/H certifies less there. The fraction FALLS with board
size; the 3x3 residue concentrates toward the middle layers (per-layer B-side
reps: k0:1 k1:18 k2:94 k3:356 k4:820 k5:1204 k6:1010 k7:548 k8:298), i.e. the
mid-game ko fights, not the near-terminal endgame.

## Finding 5: 2x2 is COMPLETELY solved; the finisher works there

At 2x2 the certified-seeded finisher resolves EVERY residue root — including
the empty board (max 2.85e8 nodes, well under the 500M budget): 9 orbit
representatives solved, 82 slots filled by symmetry, total 1.7e9 nodes / ~78 s.
Every finisher value inside its [L,H] bracket (0 bracket-fails), orbit
propagation never disagreed with a filled slot (0 orbit-clashes), final table
exhaustively symmetric. **The full pipeline (iterate → certify → finish →
validate) produces a complete, validated oracle at 2x2.**

## Finding 6: the finisher rescues NEAR-TERMINAL residue, NOT the opening

The critical scaling result. The 3x3 published anchors (empty = B+9, etc.) are
OPENING positions, and the opening is entirely residue (layers k0–k2 nearly
all ko-sensitive). Solving an anchor as a certified-seeded forward root was
measured:

- **empty(B) 3x3, seeded with all 8,326 certified values: exceeded 2.0e9
  nodes without completing** (~15 min), bracket [L=2, H=9].
- Even 3x2 near-terminal residue roots each exceed 40M nodes seeded; the
  finisher resolved 0 of 57 orbit reps at a 40M budget.

Why: the certified memo only cuts a subtree once the search REACHES a certified
position. From the opening the reachable early game is all residue, so there is
no memo help until deep — the same GHI wall as cold forward. Certified seeding
helps residue roots ADJACENT to the certified frontier (deep, near-terminal ko
fights), not the deep-opening handful.

**But the L/H BRACKETS are still informative for the opening.** For all five
3x3 published anchors, the published value is CONTAINED in the [L,H] bracket:

    empty(B)    want +9   bracket [ 2, 9]  ok
    empty(W)    want -9   bracket [-9,-2]  ok
    1.B centre  want +9   bracket [ 2, 9]  ok
    1.B side    want +3   bracket [ 2, 9]  ok
    1.B corner  want -9   bracket [-9,-2]  ok

So the engine correctly BRACKETS every anchor (consistent with published truth)
even where it cannot PIN it. Honest status of the 3x3 table:

- CERTIFIED core (66% of legal, L==H) — fully validated (tight by definition,
  plus symmetry + sampled forward spot checks + bracketed anchors).
- Near-terminal residue — resolvable by the finisher with enough budget,
  bracket-checked (demonstrated fully at 2x2).
- **Deep-opening residue (incl. the empty-board anchor) is an OPEN frontier**
  — needs history-aware treatment (Kishimoto–Müller dependency buckets) or an
  iterated/stronger opening solver. This is the same irreducible GHI core
  flagged in ADR-0009's honesty clause, now LOCALIZED to the opening and a
  minority, shrinking fraction.

This does not contradict certification soundness — L/H never claimed the
opening; it flagged it KO_SENSITIVE precisely because L≠H there. The engine
correctly identifies exactly which positions it cannot yet pin.

## Finding 7: even CERTIFIED deep positions are forward-intractable

Independent no-memo forward confirmation of certified 3x3 values (deep layers
≥6, sampled): of 400 sampled certified (position, side) roots, **295 exceeded
a 2M-node budget** — only 105 completed, and all 105 matched the certified
value exactly (0 mismatches). Certification via value iteration is cheap where
forward confirmation is not: this is the retrograde engine's whole reason to
exist, now visible even on positions with only 3–6 empty cells.

## Validation summary (which claim is covered by what)

| claim | mechanism | result |
|---|---|---|
| values sound | history-exact ground truth (2x2/3x2, reachable roots) | 0 mismatch (8, 68 roots) |
| values in range | [L,H] brackets (all boards, all finished/exact roots) | 0 bracket-fails |
| colour + dihedral symmetry | exhaustive whole-table (incl. L/H-swap + flags) | PASS all boards |
| published anchors (3x3) | bracket-contains-published | PASS (all 5) |
| certified deep values | sampled no-memo forward (3x3) | 105/105 match |
| complete pipeline | 2x2 full build→finish→validate | complete oracle |

## New data (no published reference found)

- 2x2 complete fresh-start oracle, both sides, all 57 legal positions
  (finisher-produced, bracket- and symmetry-consistent).
- 3x3 certified-core values (8,326 of 12,675 legal positions per side); value
  histogram (Black to move) over the certified core: −9:2018, −2:20, 0:32,
  2:12, 9:6244 — i.e. the certified 3x3 endgame is overwhelmingly ±9 (whole
  board to one side) with a thin band of close/seki-like values.

# Bracket-guided finishing measured (2026-07-21, ADR-0010)

The deep-opening frontier (Finding 6) is CLOSED. The finisher's forward solve
became fail-soft alpha-beta with the [L,H] brackets as cutoffs at every node
(history-free, so they fire inside the residue where certified-memo cuts
cannot), bracket-ordered moves, and an aspiration window opened one past the
root's own bracket. Design + soundness discipline: `decisions/0010`.

## Finding 8: bracket cutoffs collapse the finisher by ~6 orders of magnitude

Same battery, same budgets, plain (ADR-0009) vs bracketed (ADR-0010) finisher:

| board | reps  | plain                          | bracketed                      |
|---|---|---|---|
| 2x2 | 9   | 1.7e9 nodes, max 285M/root, ~78 s | 6,033 nodes, max 1,175/root, 1 ms |
| 3x2 | 57  | 0 of 57 solved at 40M/root        | all 57: 29,482 nodes, max 2,597, 2 ms |
| 3x3 | 622 | 0 solved; empty(B) >2.0e9, ~15 min | all 622: 156,178 nodes, max 6,378/root, 20 ms |

The anchor probe pins empty(B) 3x3 in **1,854 nodes, <1 ms** — the same root
the plain finisher abandoned past 2.0e9 nodes: ~10^6x. Why so large: with the
aspiration window inside [L,H], almost every child's bracket already lies
outside the window, so whole subtrees return as one table lookup; the search
only descends where brackets genuinely overlap the disputed range.

## Finding 9: the 3x3 oracle is COMPLETE (first board beyond 2x2)

All 622 residue orbit reps solved -> every legal (position, side) has an
exact fresh-start value. The standing battery, all green:

- anchors PIN and MATCH: empty +9/-9, centre +9, side +3, corner -9;
- 0 bracket-fails, 0 orbit-clashes; exhaustive symmetry PASS (incl. flags);
- exhaustive ground truth at 2x2/3x2: 0 mismatches (8 and 68 reachable roots);
- no-memo forward spot checks 105/105 completed match (295 budget-skipped).

New data: full-table value histogram (Black to move), all 12,675 legal:
-9:2850 -4:208 -3:488 -2:44 -1:360 0:56 1:316 2:28 3:518 4:236 9:7571.
DTT now extends through finished values: empty(B) = 3 plies (centre, pass,
pass — the cooperative fastest optimal resolution), max finite DTT = 16,
certified-with-FAR = 0.

## Finding 10: plain and bracketed finishers agree slot-for-slot at 2x2

Engine-vs-engine (`RETRO_PLAIN=1` runs both on fresh tables and diffs
in-process): final tables IDENTICAL — 0 diffs across all legal slots, both
sides (plain 1,718,995,756 nodes vs bracketed 6,033 — 285,000x on the one
board where both complete).

## Open questions carried forward

1. ~~Resolve the deep-opening residue~~ — DONE (ADR-0010, Findings 8–10).
   Iterated finishing and Kishimoto–Müller buckets were NOT needed; the
   fallback (KM dependency buckets) stays documented in ADR-0010 in case a
   larger board defeats bracket cuts.
2. ~~DTT through the finisher~~ — resolved as a side effect: with residue
   values filled, `dttPass` propagates through them (empty 3x3 = 3 plies).
   The V1-finishing variant is no longer blocking anything.
3. Sweep-count growth (2 → 6 → 12 at 2x2 → 3x2 → 3x3) — the 4x4/5x5 projection.
4. 4x4 scale run (43M slots in RAM): residue fraction + sweep count + the
   NEW number: bracketed-finisher nodes per opening root at 4x4.
5. ~~Persist the first real artifact~~ — DONE 2026-07-21 (ADR-0011,
   `artifact.zig` WZO1, `artifacts/oracle-{2x2,3x2,3x3}.wzo`, reload-verified
   byte-identical). New data from the reload probe: empty(B) fresh-start
   value = **+1 at 2x2 and +1 at 3x2** (both finisher-produced, inside their
   brackets, ground-truth-consistent).

## Published anchors vs the PSK ruleset (the ko-rule variant delta)

Van der Werf & Winands, "Solving Go for Rectangular Boards" (ICGA Journal
2009), Chinese rules, gives: 2x2 = 0 (any first move), 2x3 = 0, 3x3 = +9,
2x4 = +8, 3x4 = +4, 3x5 = +15, **4x4 = +2 (central first move)**, 4x5 = +20,
5x5 = +25. CRITICAL CONTEXT for comparing: **MIGOS II does NOT use superko**
— the paper states "since superko is not used, balanced long-cycle
repetition ... is scored as a long-cycle-tie" (basic ko in the hash, cycle
ties handled specially). weizigo plays POSITIONAL SUPERKO, where those
cycles are banned moves instead of ties.

Consequence: on cycle-dominated toy boards the two rulesets legitimately
DISAGREE — published 2x2 = 0 and 2x3 = 0 vs weizigo's exhaustively
ground-truthed PSK values of +1 and +1 (under PSK the cycles that would tie
are banned, and Black extracts a point). Where the value does not hinge on
long cycles the rulesets agree (3x3 = +9 matches exactly, all five anchor
positions). So: published values remain the anchor where they match; a
mismatch on a small board is FIRST a ko-rule-variant question, only then a
bug hunt. The 4x4 run's empty-board value should be compared against +2
with this lens.
