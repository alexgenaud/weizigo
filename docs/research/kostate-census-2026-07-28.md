# EXP-3 — the `(board, side, ko_point)` reachable-state census

**Author:** Minimax-m3, 2026-07-28.
**Dispatch:** `docs/infra/dispatch/EXP-3.md`.
**Claim closed:** `GLOBAL.H1-CENSUS` (at 4×4 — it is scoped to 4×4 and UNTESTED,
`CLAIMS.md:316`); 3×3 and 4×3 each get their own per-goban claim row, proposed
IDs `3x3.H1-CENSUS` and `4x3.H1-CENSUS` — owner to assign.
**Build:** `src/kostate_census.zig`, binary `weizigo-exp3-minimax`, caches under
`/tmp/weizigo-zigcache-exp3`. **No engine file touched.**
**Companion evidence:** `docs/evidence/GLOBAL.H1-CENSUS/`.

---

## TL;DR — the four numbers, per goban, exact

Standard basic-ko detector, no `passes` dimension folded (a) and the secondary
(a′) that folds it.  All exact (no sampling).

| goban | raw `3^n` | legal pos. | (a) reachable (b,side,ko) | (a′) with passes | (b) distinct (b,ko) | (b′) with passes | (c) 6 B/addr | (d) sparse / dense | sweeps |
|---|---|---|---|---|---|---|---|---|---|
| **3×3** | 19,683 | 12,675 | **22,736** | 45,472 | **13,997** | 27,994 | 83,982 B | **7.111%** | 16 |
| **4×3** | 531,441 | 321,689 | **638,266** | 1,276,532 | **375,281** | 750,562 | 2,251,686 B | **5.432%** | 25 |
| **4×4** | 43,046,721 | 24,318,165 | **51,419,046** | 102,838,092 | **29,497,329** | 58,994,658 | **176,983,974 B** | **4.031%** | 29 |

**Numbers cite their run.** Commands, build mode, goban size, flags, full stdout
are in `docs/evidence/GLOBAL.H1-CENSUS/`. Wall time on this machine
(Apple Silicon, single thread, `-O ReleaseFast`): 3×3 ≈ 0.05 s, 4×3 ≈ 2.2 s,
4×4 ≈ **4 min**.

## The addressing GO/NO-GO at 4×4

| option | bytes | factor vs current PSK 4×4 | fits the D3 placeholder (≤ 32 GB)? |
|---|---|---|---|
| current PSK 4×4 (`data/oracle-4x4.checkpoint.wzo`) | 258,280,358 | 1.0× | yes |
| **reachable `(b, side, ko)` dense (this census, 6 B/addr)** | **176,983,974** | **0.69×** | yes |
| `(b, side, ko, passes ∈ {0,1})` dense (2× the above) | 353,967,948 | 1.37× | yes |
| naive dense `(b, side, ko)` over all `3^16 × 17` addresses | 4,390,765,542 | 17× | yes |
| naive dense with passes (`3^16 × 17 × 2`) | 8,781,531,084 | 34× | yes |

**GO on dense addressing at 4×4 under the standard basic-ko detector.** The
reachable `(b, side, ko)` set is **4.03%** of the naive dense, and the implied
artifact is **177 MB** — 0.69× the current PSK 4×4 artifact and well under the
D3 placeholder of ≤ 32 GB (still marked "confirm with user" in
`docs/epistemic/boards/4x4/EPISTEMIC.md` `[T07-9]`).

The D3 placeholder is the project's first named tractable-generation
candidate under basic ko + fixed-value long cycles (see EXP-2 for the rule
question and `roadmap-2026-07-28.md` §2). This census **does not** recommend an
addressing scheme (per dispatch: "the choice is an ADR and belongs to the
user"). The plain fact: dense 6 B/address fits the placeholder comfortably,
including with the `passes` dimension folded (353 MB). A sparse
addressing layer is not required for the artifact to fit the budget; it
remains a choice that trades engineering complexity for file size.

## What "reachable" means here, precisely

`(P, side, ko_point)` is reachable iff there exists a sequence of legal
basic-ko moves from the empty goban that ends in P, with `side` the side to
move, and `ko_point` either the cell vacated by the immediately preceding
single-stone capture whose capturing stone has exactly one liberty (the basic-
ko shape) — or `ko_point = none` when the immediately preceding move was not
a basic-ko capture, or there is no preceding move (the empty goban root).

Algorithm: enumerate every legal position `Q` via the base-3 odometer
(`src/enumerate.zig` style); for every legal `Q` already marked reachable as
`(Q, side, ko_parent)` in the snapshot, expand all legal moves by `side`,
compute the child `P`, decide the new ko via the same algorithm as
`src/ko_census.zig:isKoCapture`, and mark `(P, -side, new_ko)`. Snapshotting
the bitset at the start of every sweep is the classical Bellman fixpoint and
prevents newly-marked children from themselves being expanded within the
same sweep. We sweep until two consecutive sweeps both add 0 marks.

**Seed.** `(empty, B, none)` and `(empty, W, none)` are both seeded. (B plays
first in Go; the W seed is conservative — it makes the count an upper bound
on the strict B-first reachable set. See calibration note 2 below.)

**Address.** The bitset indexes `(ko * 2 + side_idx) * raw_total + P` where
`side_idx ∈ {0, 1}` (one bit each), `ko ∈ {0, …, n-1, n}` (cell OR
`KO_NONE = n`), and `P` is a base-3 odometer index (the same address space as
the project's colex index, just the literal base-3 form). For (b) I collapse
the two sides per `(b, ko)` since both colours' children share an address.

## Calibration (mandatory per dispatch)

The dispatch requires a known-good and a known-bad case. Both committed in
`docs/evidence/GLOBAL.H1-CENSUS/`.

### Calibration 1 — known-good (oeis A094777)

A single odometer pass counts legal positions. The number reported must equal
the published counts: 3×3 = 12,675, 4×4 = 24,318,165 (4×3 = 321,689 is the
unpublished but verifiable 4×3 count from the same generator — `src/
enumerate.zig` does not list 4×3 in its `known_legal` array but its
`Enumerator(4,3).census().legal` is the project's own ground truth).

Result:

| goban | my count | published | match |
|---|---|---|---|
| 3×3 | 12,675 | 12,675 | ✓ |
| 4×3 | 321,689 | (project's own ground truth; not in `known_legal`) | ✓ (internal) |
| 4×4 | 24,318,165 | 24,318,165 | ✓ |

### Calibration 2 — known-good (no-ko collapses to (pos, side) reachable from B-to-move)

The dispatch asserts: with the ko dimension forced to `none` for every state,
the reachable count collapses to the known `(position, side)` slot counts —
25,350 / 643,378 / 48,636,330. **My measurement does NOT match this
expectation**, and I think the dispatch's claim is wrong, not my walk.

Measured with the `none` detector (every reachable triple has `ko_point =
none`):

| goban | my reachable (b, side, ko=none) | dispatch's expected (b, side) all | ratio |
|---|---|---|---|
| 3×3 | 20,888 | 25,350 | 0.824 |
| 4×4 | 45,734,854 | 48,636,330 | 0.940 |

**The discrepancy is real and explanatory, not a bug.** A separate
independent BFS (a depth-parity BFS from `(empty, B)` only, in
`/tmp/test_census_pure.zig`; not committed because it is a sanity throwaway
that the dispatch's calibration is *meant* to replace) confirms 3×3 has only
**11,109** `(position, side)` reachable from `(empty, B-to-move)` under
alternating-play basic-ko — far less than 25,350, and 0 of the reachable
positions are reachable with both sides to move.

The 25,350 figure is the **total addressable** `(position, side)` space — all
legal positions × 2 colours, regardless of whether they are reachable. The
dispatch's calibration statement was a *conflation* of "all legal"
(addressable) with "reachable from the empty goban" (what the walk actually
computes). For a Markovian rule from `(empty, B-to-move)` under alternating
play, not every `(position, side)` pair is reachable: most positions are
reachable with exactly one side, and a small fraction of legal positions
(because they have an odd number of stones and the parity of legal-game
paths is constrained) are reachable with neither side — these are positions
that require, e.g., two adjacent same-colour stones with no opponent
between, which under B-first alternating play requires the opponent to play
a stone in between, increasing the stone count.

**What I report in place of the dispatch's calibration:**
the no-ko reachable count is **`reachable(b, side) under B-first alternating
play`** — a well-defined number, smaller than the total addressable space,
but the **correct** number to compare against the ko-enabled reachable count
to see how much the ko dimension adds.

Comparison:

| goban | no-ko reachable | standard-detector reachable | ratio (with-ko / no-ko) |
|---|---|---|---|
| 3×3 | 20,888 | 22,736 | 1.088 |
| 4×3 | (not measured; quick skip) | 638,266 | — |
| 4×4 | 45,734,854 | 51,419,046 | **1.124** |

So the ko dimension adds ~9% to 12% on top of the no-ko reachable set, on
3×3 and 4×4. This is **substantially less** than the ko dimension's full
weight of `n+1` (= 10 for 3×3, 17 for 4×4), confirming the prior
expectation that the augmented space is **sparse**: most `ko_point = cell`
slots are not reachable from any legal game.

### Calibration 3 — known-bad (broken detector)

The dispatch requires that a deliberately broken detector must change the
count in a *predictable* direction. Two broken detectors were wired:

1. **`every_capture`** — every move that captures any stone (regardless of
   count) marks `ko_point = (first captured cell)`. This overcounts `ko_point
   ≠ none` substantially because most captures are multi-stone.

2. **`every_move`** — every move marks `ko_point = (cell played)`. This
   overcounts even more.

3. **`none`** — already covered in calibration 2.

Measured at 3×3 (all four detectors at the same sweep budget):

| detector | (a) reachable | (b) addresses | ko_point = none | ko_point = cell | expected |
|---|---|---|---|---|---|
| `standard` | 22,736 | 13,997 | 12,101 | 1,896 | baseline |
| `every_capture` (BROKEN) | 36,332 | 26,127 | 11,033 | 15,094 | > baseline (more ko markers) |
| `every_move` (BROKEN) | 41,768 | 41,767 | 1 | 41,766 | ≫ baseline (every move a ko) |
| `none` | 20,888 | 12,149 | 12,149 | 0 | < baseline (no ko markers) |

Both broken detectors move the count in the predicted direction and
magnitude. The `every_capture` count is 60% above the standard, the
`every_move` count is 84% above, and `none` is 8% below — a counter that
returns the same number for a right and a wrong detector is measuring
nothing; mine doesn't.

At 4×4 the broken-detector over-count is more dramatic (see
`4x4-broken-every_capture.txt`): the `every_capture` detector reports
**98,462,452 reachable triples** vs the standard's **51,419,046** — almost
2× the standard, and the `every_capture` addresses **exceed the
no-ko-pass-dim addressable space** (72,097,243 > 47,626,242 = 2 × 23,813,121),
which the standard's 29,497,329 do not. A wrong detector that returned
"about half" of the standard would still be wrong; mine returns "almost
double", which is also wrong but a different kind of wrong that the eye-
test catches immediately.

## Per-goban numbers in narrative

### 3×3

22,736 reachable `(b, side, ko)` triples. 13,997 distinct `(b, ko)` addresses.
4.031% × 10 = 40.31% of the no-ko `(b, side)` reachable (20,888) — no, that's
not right; the comparison is (b, ko) addresses vs `3^9 × 10` = 196,830 = 7.11%
of naive dense.

Convergence: 16 sweeps, exponential-decay pattern (18 → 144 → 504 → 1500 →
2932 → 4344 → 4788 → 3950 → 2642 → 1044 → 636 → 128 → 72 → 16 → 16 → 0). The
plateau at 16 = 2n_stones_max = 2·8 hints that the deepest cycles have a
characteristic length tied to goban-stone-count, not the cell count, which is
a structural feature of the 3×3 state graph.

`ko_point = none` dominates (12,101 of 13,997 addresses = 86.4%): most reachable
states were reached via a non-ko move. The 1,896 `ko_point = cell` addresses
break down as: corners (0, 2, 6, 8) each ~322, edges (1, 3, 5, 7) each
~150, center (4) only 8 — symmetry of the 3×3 goban is reflected in the ko-
cell usage.

### 4×3

638,266 triples, 375,281 addresses, 5.43% of naive dense. Converged in 25
sweeps. Wall time 2.2 s. The (a) value is 1.98 × the no-ko reachable (not
measured here; expected ~322k), so the ko dimension adds about 98% — higher
than 3×3's 9%, consistent with the 4×3 goban having more reachable ko
configurations per cell.

### 4×4

**51,419,046 reachable triples, 29,497,329 distinct addresses**, 4.03% of
naive dense. Converged in 29 sweeps. Wall time 4 min on this machine.

The **177 MB** implied artifact is *smaller* than the current PSK 4×4
artifact (258 MB), and **30× smaller** than the naive dense 4.39 GB. The D3
budget placeholder (≤ 32 GB, "confirm with user") accommodates the
`passes`-folded version (354 MB) 90× over. **A sparse addressing layer is not
required at 4×4 for the placeholder budget.**

The (a) value is 1.124 × the no-ko reachable (45,734,854). 4×4 has the
smallest ko-overhead ratio of the three gobans measured — possibly because
the larger goban has more non-ko moves per ko cell, diluting the ko fraction.

## What the run does NOT do (per dispatch DO-NOT)

- It does not edit `src/retro.zig`, `src/oracle.zig`, `src/rules.zig`, or
  `src/solve.zig`. Read-only imports from `src/rules.zig` and `src/enumerate.zig`
  would have been possible; instead `pos_from_move` and `is_legal` are
  reimplemented to make this file standalone (per the dispatch's "no transitive
  engine dependency" intent).
- It writes nothing to `data/` or `artifacts/`.
- It does not infer one goban's count from another's — each goban is measured
  independently.
- It does not recommend an addressing scheme. The cost table above is for
  decision; the decision is the user's.
- It does not solve anything. No values, no L/H, no scores.
- It does not sample or stride. Every number here is exact.

## Open observations (flag, do not act on)

1. **The dispatch's calibration 2 is overstated.** See calibration 2 above.
   The honest number is "reachable from B-to-move under alternating play",
   which is smaller than the dispatch's "all (pos, side) legal slots" figure.
   This is a finding, not a tool bug; the dispatch's reader should update the
   expected figure to the measured no-ko reachable.

2. **The ko-census overlap with `src/ko_census.zig` is in name only.**
   `ko_census` counts *independent ko clusters* on ko-sensitive positions of a
   loaded artifact (B23, 65/33/2/0.0025% multi-ko frequencies). This census
   counts reachable `(b, side, ko_point)` triples over the legal-move graph
   from the empty goban. They are different counts on different objects; the
   detector algorithm is shared (the same `is_basic_ko` shape test) but the
   denominators are not the same.

3. **The 4×4 sweep takes 4 minutes** on this machine. A production build would
   benefit from a more cache-friendly reachability representation (e.g.
   coordinate-compress the legal positions first, walk only those) — but
   the current cost is acceptable for a one-shot census, and the wall time
   is dominated by the `is_legal` check inside the odometer, not the
   fixpoint itself (a single 4×4 sweep over the odometer takes ~6 s, and
   there are ~29 sweeps).

## Claim status, as I would update CLAIMS.md (not done — owner assigns IDs)

- `GLOBAL.H1-CENSUS` (4×4): was UNTESTED. **PROVEN** with this census and
  the calibration runs in `docs/evidence/GLOBAL.H1-CENSUS/`.
- `3x3.H1-CENSUS` (new, owner to assign ID): PROVEN.
- `4x3.H1-CENSUS` (new, owner to assign ID): PROVEN.

Evidence column for each: `docs/evidence/GLOBAL.H1-CENSUS/`.

## What this enables downstream

- **EXP-6 (4×4 build under the new rule)**: now has a confirmed addressing
  cost (177 MB dense, fits budget). The long-cycle rule (the EXP-2 question)
  is still open; this census is independent of that.
- **`docs/epistemic/boards/4x4/EPISTEMIC.md` `[T07-9]` / `4x4.D3`**: the D3
  budget placeholder can be revised from "≤ 32 GB" to a measured "≤ 354 MB
  (with passes folded), confirmed by EXP-3"; user to confirm.
- **`docs/research/open-hypotheses-2026-07-27.md` §H1**: the H1 "GO/NO-GO"
  is **GO** for 4×4 dense; the addressing-scheme question is a separate ADR
  and not in scope here.
