# Position enumeration census (2026-07-16)

`src/enumerate.zig` — board-size-agnostic legal-position enumerator (STRUCTURE
only; ADR-0007). Validates against published counts, and produces the canonical
class counts the compressed-oracle data model needs.

Definitions: **legal** = every chain has >= 1 liberty (Tromp-Taylor). **canonical**
= lexicographically-least board over dihedral symmetries x colour inversion
(16 variants on a square board; 8 on a rectangle).

## Results (exhaustive base-3 odometer, ReleaseFast, ~6 s total through 4x4)

| board | raw 3^n | legal | vs published | canonical classes | legal/canon ratio |
|-------|---------|-------|--------------|-------------------|-------------------|
| 1x1 | 3 | 1 | PASS | 1 | 1.0 |
| 2x2 | 81 | 57 | PASS | 8 | 7.1 |
| 3x3 | 19_683 | 12_675 | PASS | 924 | 13.7 |
| 4x4 | 43_046_721 | 24_318_165 | PASS | 1_524_805 | 15.95 |
| 5x5 | 8.47e11 | 414_295_148_741 (published) | deferred | ~2.6e10 (est., /16) | -> ~16 |

Published legal counts: John Tromp (OEIS A094777). The canonical counts are
NEW measurements (not published anywhere we know of).

- The legal/canonical ratio converges to ~16 as boards grow (few symmetric
  boards), so **5x5 canonical ~ 414.3e9 / 16 ~ 25.9e9 classes**.
- At ~1 byte per (canonical position, side): **~52 GB** for a full 5x5 value
  oracle before compression — matching the strategy doc's "tens of GB; disk is
  not the constraint".

## Per-stone-count layers (legal/canonical)

3x3: `0:1/1 1:18/3 2:144/16 3:664/53 4:1912/145 5:3478/245 6:3832/270 7:2224/158 8:402/33`
(max layer at 6 stones; no legal 9-stone position — a full board has no liberty.)

4x4: `0:1/1 1:32/3 2:480/42 3:4472/295 4:28896/1900 5:136888/8652 6:489848/30988
7:1343728/84293 8:2836180/178128 9:4578504/286694 10:5560004/348615
11:4925600/308320 12:3017716/189330 13:1159264/72613 14:226040/14270 15:10512/661`
(max layer at 10 of 16 cells ~ 62% full; no legal 16-stone position.)

The bell shape peaking around ~60-65% occupancy tells us where the bulk of the
oracle's storage and the retrograde fixpoint's work will live on 5x5
(~15-17 stones).

## 5x5 plan (deferred)

The odometer would need 3^25 = 8.5e11 iterations (rough extrapolation from 4x4:
~30 h single-threaded ReleaseFast; parallelizable by fixing the top cells).
Better: **layered enumeration** — choose the k occupied cells (C(25,k)), then
the 2^k colourings, streaming per layer; this is also the natural shape for the
combinatorial-ranking index and the retrograde solver's layer order. Next step
on this track: rank/unrank (position <-> dense index) so the census needs no
stored list at all.

## Layered colex index (2026-07-17) — the address system, VERIFIED

`src/colex.zig` — `colex_from_pos(pos) -> u64` and `pos_from_colex(u64) -> pos`
(naming per the state.zig `x_from_y` idiom; the term "rank" is avoided — in Go
it means kyu/dan). A collision-free bijection (a minimal perfect hash with an
inverse) between boards and 0..3^n-1:

    idx  = layer_offset[stones]
         + subset_idx(occupied cells) * 2^k    // combinatorial number system
         + colour_bits                         // bit j = j-th cell asc, 1=black

- **Exhaustively verified as a dense bijection** over every board of 2x2 (81),
  3x2 (729), 3x3 (19,683) and 4x4 (43,046,721): zero collisions, all
  round-trip. ~5 s ReleaseFast.
- **5x5 addressing works arithmetically now** (no enumeration): total =
  847_288_609_443 = 3^25 exactly; largest layer k=17 (141.8e9 slots, ~68%
  occupancy — matching the census bell). Sanity: tengen-only board = idx 26
  (= offset 1 + cell 12 * 2 + black 1).
- An index is an ADDRESS (which board), never a score. The score (-25..+25 i8,
  Black-positive) is what the oracle later STORES at `values[idx]`.
- An equally valid bijection is the literal base-3 number (= state.zig's u40
  `view`); the layered form is preferred because stone count = retrograde
  processing order and the subset component is where the density folds attach.
- RAW = includes illegal + non-canonical slots. Sufficient for the full
  retrograde prototype on 3x3 (19,683 slots) / 4x4 (43 MB); the legality (~2x)
  and symmetry (~16x) folds are later density upgrades behind the same
  two-function interface, needed only for 5x5 (raw = 847 GB at 1 B/slot).
- FORMAT CONTRACT: the layout defines where every stored value lives on disk;
  version it in the persist header before writing real oracle data.

### Canonical forms lean EARLY in colex space (measured 2026-07-17)

User conjecture: canonical representatives cluster toward the early index
space. Measured on all 1,524,805 canonical-legal 4x4 boards (layer-relative
position within each layer):

    65% in the first half; decile histogram 13,14,13,12,11,10,8,7,5,2 (%).

So: a real, monotone early bias — but a slope, not a wall (the last decile
still holds 2%), so the space cannot be truncated. The bias helps VALUE-FILE
COMPRESSION (sparse tails) rather than addressing. Cause: canonicalization
picks the lexicographically-least variant, which biases stones toward
low-numbered cells and white (=0 colour bits) early — both lower the index.

Note: the CELL NUMBERING is a free parameter of the scheme. Row-major today;
an L-shell numbering (cells of the k x k sub-board = a prefix of the
(k+1) x (k+1) numbering) would make smaller boards' positions a geometric
prefix of larger boards' index space — worth considering before the format
contract is frozen (relevant to the 6x6/7x7 ambition).

## Notes

- `enumerate.zig` is deliberately standalone (no state.zig / zobrist.zig
  imports): usable for any w x h, testable per-module, no dyld-mega-binary risk.
- Rectangles use the 4-element symmetry group (tested on 3x2).
- REACHABILITY: these are LEGAL positions; whether every legal position is
  reachable from the empty board under positional superko is a separate
  question (not needed yet — the oracle can safely target the legal superset).
