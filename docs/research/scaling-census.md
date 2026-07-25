# Scaling census — the numbers that decide 5×5 feasibility

Measured by `RETRO_CENSUS` (retro.zig): build each board through
seed+converge+finalize only — the **history-free** part (L/H iteration +
certified/residue classification), NO finisher. This is the cheap, provably
sound stage. Run 2026-07-23, in-RAM, single machine.

## Raw data

| board | raw 3ⁿ | legal | legal % | side-slots | residue (KO) | residue % | sweeps | build |
|---|---|---|---|---|---|---|---|---|
| 2×2 | 81 | 57 | 70% | 114 | 82 | 71.93% | 2 | 0 ms |
| 3×2 | 729 | 489 | 67% | 978 | 378 | 38.65% | 6 | 2 ms |
| 3×3 | 19,683 | 12,675 | 64% | 25,350 | 8,698 | 34.31% | 12 | 138 ms |
| 4×3 | 531,441 | 321,689 | 60% | 643,378 | 170,276 | 26.47% | 17 | 4,742 ms |
| 4×4 | 43,046,721 | 24,318,165 | 56% | 48,636,330 | 10,367,922 | 21.32% | 19 | 494,433 ms (8.24 min) |

"side-slots" = legal × 2 (a value per side to move). "residue" = KO_SENSITIVE
slots (L < H) summed over both sides. "sweeps" = L/H fixpoint iterations to
convergence.

## What the trends say

1. **Residue FRACTION falls monotonically** (72% → 39% → 34% → 26% → 21%).
   The certified, history-free core — the cheap and provably sound part —
   grows to dominate. Extrapolating gently, 5×5 residue is ~18–20% of slots.
   *This is the single most encouraging number in the project.*

2. **Residue ABSOLUTE count grows roughly with the table** (82 → 378 → 8.7k →
   170k → **10.4M**). After folding the 8 board symmetries, 4×4 still has on the
   order of **~1.3M distinct residue positions** that the finisher must solve
   as independent ko-searches. This — not memory — is the cost wall.

3. **Legal fraction falls slowly** (70% → 56%). Consistent with the known 5×5
   legal count (~414 billion, ≈ 49% of 3²⁵).

4. **Sweeps grow slowly / sub-linearly** (2 → 6 → 12 → 17 → 19). Convergence is
   cheap; ~22–25 sweeps projected for 5×5. Each sweep is one linear pass over
   the table — the friendliest possible shape for out-of-core tiling.

5. **History-free build cost** is already 8.2 min for 4×4's 43M raw slots,
   in RAM. It is embarrassingly parallel per layer and streams linearly, so it
   is the *tractable* half of the problem — but see the 5×5 projection.

## 5×5 projection (order-of-magnitude, honest)

- raw 3²⁵ ≈ **847 billion**; legal ≈ **414 billion**; after 8-fold symmetry
  ≈ **25–50 billion** distinct positions.
- **Table on disk** (values only, ~1–2 bytes/side): order **50–150 GB**.
  Working L/H state during generation: several× that. → **Does not fit in
  40–48 GB RAM; must be out-of-core.** RAM is a working buffer, not the store.
- **History-free build**: scaling 4×4's 8.2 min by the raw-slot ratio (~19,700×)
  and dividing by fold (~14×) lands in the **~1–2 weeks** range on one machine
  — heavy but parallelizable and interruptible.
- **The residue is the crux**: ~18–20% of ~50B side-slots ≈ **~1 billion
  residue slots**, order **~10⁸ distinct ko-searches** after symmetry. Even at
  a few milliseconds each (optimistic, and only if reuse is sound and fast),
  that is the dominant term and the real feasibility question.

## Consequence for the fix tracks (ADR-0013)

The residue count reframes Track A vs Track B:

- The committed (buggy) 4×4 finish completed in hours **because** it reused work
  across searches (the very reuse that proved unsound). **Track A (writes off,
  no reuse) removes exactly that accelerant** — so a full writes-off 4×4 finish
  is expected to be much slower, possibly impractical. Early evidence: the
  `RETRO_CONSIST4` 400-node writes-off sample did not finish in ~14 min.
- Therefore **Track B (Kishimoto–Müller sound reuse) is likely required even
  for 4×4** to finish in reasonable time, not just for 5×5. It is on the
  critical path, not a follow-up.
- Track A remains the correctness baseline and the way to ship provably-correct
  **small** boards (2×2, 3×2, 3×3) immediately and to validate the auditor on
  regenerated artifacts.

## Finisher throughput: reuse vs sound (RETRO_CMP)

Build a board, then run the residue finisher twice on fresh certified tables —
fast (unsound) reuse path vs sound (writes-off) — and compare. Both fill 100%
of residue at these sizes (no budget-skips).

| board | reuse | sound | slowdown | nodes reuse→sound | worst root reuse→sound |
|---|---|---|---|---|---|
| 3×3 | 11 ms | 35 ms | 3.2× | 79k → 316k (4.0×) | 1.3k → 29k (22×) |
| 4×3 | 2.59 s | 31.1 s | 12× | 11.0M → 183.1M (16.6×) | 56k → 1.59M (28×) |

**The slowdown factor grows with board size** (3.2× → 12×), and the single
hardest root's node count blows up even faster (22× → 28×). The reuse the
auditor convicted is not merely an accelerant: it is what keeps the expensive
opening roots *under any fixed per-root budget*. Removing it (Track A) both
slows the whole finish and pushes the hardest roots over budget — so a
writes-off 4×4 is expected to leave more opening residue **unfilled** than the
reuse path did, not merely take longer. **Conclusion: Track B (Kishimoto–Müller
*sound* reuse) is on the critical path for a COMPLETE 4×4, not only for 5×5.**
Track A remains correct and complete for boards through ~4×3 and is the
validated baseline (small artifacts already regenerated and anchor-checked).

## Sparse fingerprints solve the memory wall — but a tractability wall remains

The dense per-slot fingerprint (44 GB at a useful width) is replaced by a
sparse per-root map (only the current root's live entries, cleared per root).
Measured on a clean deps-4×4 run (width 2048 bits, budget 500M/root): peak
**RSS 1.3 GB** — the memory problem is gone, and the fingerprint can be as wide
as precision needs.

**But sound reuse does not tame the capture-reopening roots.** Even at
near-terminal layer 15 (one empty point), a few residue roots blow the 500M
budget, each taking 3–6 minutes. These are capture-reopening tangles: filling
the last point captures a large group and reopens the board into a long
superko cycle. The *unsound* legacy reuse tamed them (it memoized across the
cycle regardless of history — fast, and mostly-but-not-always correct); *sound*
reuse cannot memoize across a history-dependent cycle, so the search explodes.
Raising the budget does not help — 500M already costs minutes, so billions
would be hours per root, across many roots.

**Consequence:** we cannot yet produce a *sound and complete* 4×4 by any method
in hand. Writes-off explodes worst; fingerprint-guarded deps explodes on the
capture-reopening roots; the unsound path completes but is wrong on ≤45-class
residue slots. This is the concrete frontier. Candidate ways forward (unproven):
- **Shrink the dependency set** D(P) from "all subtree positions" to only the
  positions that can actually recur (ko-relevant), so guarded reuse rejects far
  less and can tame the cycles while staying sound. Most promising.
- A dedicated **cycle/loop solver** for capture-reopening tangles (treat the
  strongly-connected ko component explicitly rather than by plain search).
- Accept per-root time and run a very long one-time generation (only viable if
  the hardest roots are finite and few).

## Dead-end: the stone-count dependency-set shrink is UNSOUND

Idea: since the finisher solves deepest-layer-first, assume every real ancestor
has <= L stones (L = root's stone count), and drop >L positions from each
value's dependency fingerprint (unsaturating it). Implemented and gated behind
`dep_layer_max`. It recovered reuse dramatically (4x3: 57M nodes vs sound 183M,
~3x fewer) — but `RETRO_DEPSVAL` **immediately proved it wrong**: deps diverged
from writes-off (empty 3x2 = -2 instead of 0; 38 mismatches on 3x2, 5268 on
4x3). Root cause: **deeper residue positions are re-searched, not leaves**
(Finding 2 — a FROM_FORWARD residue value must not seed the memo), so the search
recurses UP through higher-stone residue and those positions DO become real
ancestors. The premise "ancestors <= L stones" is false; for the empty root
(L=0) the shrink drops every position and reuse becomes unconditional = the
original bug. Reverted (dep_layer_max left at 255 = no shrink).

Lesson: the exact dependency set is the full subtree (equivalently, the
position's strongly-connected component under capture moves). Any sound shrink
must be SCC-aware, not stone-count-based. Recovering safe reuse in the
capture-reopening tangles therefore stays the open problem; the tempting
3x speedup was almost entirely unsafe reuse.

## The player is not history-perfect (separate from the table)

Observed in live 4x3 play: the engine lost by 12 where perfect play is Black
+4, because genmove picks moves from the FRESH-START table (+ a shallow
lookup), which is only correct on history-free (certified) positions. On
KO_SENSITIVE positions it is history-blind and misplays (the `HISTORY-DIVERGED`
log marks exactly these). The stored table is sound; the move-picker is not. A
history-perfect genmove needs a full history-exact search per move — the same
sound-reuse machinery, with the same capture-reopening tractability wall.

## Still to measure (next iterations)

- Writes-off finisher **throughput** on 3×3 and 4×4 (residue slots/sec, and the
  opening-tail cost distribution) — quantifies how badly reuse is needed.
- Distribution of the residue **bracket width** (H − L): many slots may have a
  narrow gap resolvable cheaply; a few wide ones may dominate.
- Compressibility of the 4×4 value table (RLE / layered) — projects real
  on-disk size.
- Out-of-core tiling dress rehearsal on **5×4** before attempting 5×5.
