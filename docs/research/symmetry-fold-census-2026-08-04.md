# Symmetry-fold census (2026-08-04, T359)

**Status: MEASUREMENT (analysis only — no encoding, format, or artifact changed).**
**Worker/identifier:** glm-5.2/T359. **Run:** `tools/runner -- zig run -O ReleaseFast src/symcensus.zig`
(19.2 s wall, ~4 MB peak RSS; full output committed at
`docs/evidence/T359-SYM-FOLD/run.txt`). **Instrument:** `src/symcensus.zig`,
a standalone census that reuses the symmetry permutations and legality test of
`src/enumerate.zig` and the layered colex address of `src/colex.zig`.

The `src/colex.zig:57-62` comment names the unbuilt optimisation: the current
encoding is **RAW** (it addresses illegal *and* non-canonical positions), and
the anticipated folds are **legality ~2×** and **canonical/symmetry ~16×**,
together taking 5×5 from 847 GB raw to ~26 GB. Nobody had measured whether
those factors are real. This row measures them, over the full RAW 3ⁿ space
(legal **and** illegal colourings), for 2×2, 3×2, 3×3, 4×3, 4×4.

The symmetry group used is **spatial symmetry × colour inversion**: D4×2 = **16**
elements on a square, D2×2 = **8** on a rectangle (the Klein four-group of
identity / flip-x / flip-y / 180°, times colour inversion). This matches the
`enumerate.zig` canonicalisation and the project's value-inversion convention
`value(−pos, −side) = −value(pos, side)`. The orbit of a position is the set of
distinct positions reached by the group; the **canonical set** is one
representative per orbit; the **fold factor** is raw ÷ |orbits|.

## Q1 — what does folding actually save?

| goban | group | raw (3ⁿ) | legal | orbits (raw) | **fold raw÷canon** | predicted | canon-legal | fold legal÷canon | **fold raw÷canon-legal** |
|-------|------|----------|-------|--------------|---------------------|-----------|-------------|------------------|---------------------------|
| 2×2 | 16 | 81 | 57 | 13 | **6.23×** | 16 | 8 | 7.13× | 10.13× |
| 3×2 | 8 | 729 | 489 | 116 | **6.28×** | 8 | 78 | 6.27× | 9.35× |
| 3×3 | 16 | 19 683 | 12 675 | 1 444 | **13.63×** | 16 | 924 | 13.72× | 21.30× |
| 4×3 | 8 | 531 441 | 321 689 | 67 625 | **7.86×** | 8 | 40 997 | 7.85× | 12.96× |
| 4×4 | 16 | 43 046 721 | 24 318 165 | 2 700 373 | **15.94×** | 16 | 1 524 805 | 15.95× | 28.23× |

**The symmetry fold converges to the group order as the goban grows** — exactly
as the enumeration census (`docs/research/enumeration-census.md`) saw for the
*legal* positions, now confirmed over the full RAW space. By 4×4 the measured
fold is **15.94/16 = 99.6%** of the predicted 16× (square) and **7.86/8 = 98.2%**
of the predicted 8× (rectangle). The shortfall is the small fraction of
positions fixed by a non-identity symmetry, which have short orbits (see the
distribution below). The legality fold is ~1.77× on 4×4 (43.0M / 24.3M); the
**combined raw→canonical-legal fold is 28.23×** on 4×4, the number the 5×5 plan
actually rides on. Extrapolating the 16× to 5×5 (raw 847 GB): canonical-raw
~53 GB, and with the ~2× legality fold, canonical-legal ~26 GB — matching the
strategy doc's "tens of GB."

The canonical-legal counts (8 / 78 / 924 / 40 997 / 1 524 805) reproduce the
published `enumeration-census.md` figures exactly — that reproduction is a
cross-check on the canonicaliser (see Controls).

### Orbit-size distribution (size : number of orbits)

| goban | size 1 | size 2 | size 4 | size 8 | size 16 | self-consistency Σ(size·count) |
|-------|--------|--------|--------|--------|---------|--------------------------------|
| 2×2 | 1 | 2 | 3 | 6 | 1 | = 81 (raw) ✓ |
| 3×2 | 1 | 10 | 33 | 72 | — | = 729 (raw) ✓ |
| 3×3 | 1 | 15 | 35 | 347 | 1 046 | = 19 683 (raw) ✓ |
| 4×3 | 1 | 88 | 2 256 | 65 280 | — | = 531 441 (raw) ✓ |
| 4×4 | 1 | 28 | 302 | 19 402 | 2 680 640 | = 43 046 721 (raw) ✓ |

`Σ(size · orbit_count) = raw` holds for every goban — the orbit partition covers
the RAW space exactly once. The bulk (99.3% of 4×4 orbits) sit at the full group
order 16; the short orbits are the symmetric minority that pulls the fold below
16.

### Positions fixed by ≥ 1 non-identity symmetry

| goban | count | % of raw |
|-------|-------|----------|
| 2×2 | 65 | 80.2% |
| 3×2 | 153 | 21.0% |
| 3×3 | 2 947 | 15.0% |
| 4×3 | 9 201 | 1.7% |
| 4×4 | 156 481 | 0.36% |

These are the positions whose orbit is smaller than the group order; their
fraction shrinks as the goban grows, which is why the fold converges upward to
the group order. (2×2 is small enough that most positions hit some symmetry.)

### Anomalies — orbits of size 1 or 2 (named)

A size-1 orbit is a position fixed by **all** group elements — only the empty
goban (colour inversion fixes a position iff every cell is empty). A size-2
orbit is a position fixed by **all** spatial symmetries but not by colour
inversion; its orbit is exactly `{p, −p}`. These are the highly-symmetric
patterns. The complete list (every size-1 and size-2 orbit, since the counts are
small) is in `docs/evidence/T359-SYM-FOLD/run.txt`; the headline examples on 4×4:

- **size 1, k=0:** the empty goban (`..../..../..../....`, colex 0).
- **size 2, k=16:** the monochrome orbit `{WWWW/WWWW/WWWW/WWWW (colex 42 981 185),
  BBBB/BBBB/BBBB/BBBB (colex 43 046 720)}`. Min colex = 42 981 185 = 3⁴²⁵⁻²⁴ =
  99.848% of the range — the expected counter-example, **confirmed**.
- 27 other size-2 orbits on 4×4 (k = 4, 8, 12, 16): four-fold-symmetric stone
  patterns such as `..../.WW./.WW./....` (k=4), `.WW./W..W/W..W/.WW.` (k=8),
  `WWWW/WBBW/WBBW/WWWW` (k=12). All are `{p, −p}` pairs.

The monochrome orbit is the **extreme** (k = n, the very top of colex) but **not
the only family**: every spatially-symmetric pattern gives a size-2 `{p, −p}`
orbit, and — more importantly for Q2 — *every* orbit whose stone count k is high
sits at the top of the colex range, whether or not it is an anomaly.

## Q2 — is the canonical set a colex prefix? (No.)

The operator's hypothesis was that a symmetric partner lives in the earliest
6.25 / 12.5 / 25 / 50% of the colex table, which would allow **truncation**
rather than indexed folding. It is **refuted**.

**Cumulative fraction of orbits whose minimum colex falls below each threshold:**

| goban | 6.25% | 12.5% | 25% | 50% | 75% | 100% |
|-------|-------|-------|-----|-----|-----|------|
| 2×2 | 15.4% | 23.1% | 46.2% | 69.2% | 69.2% | 100% |
| 3×2 | 12.9% | 20.7% | 31.9% | 65.5% | 87.9% | 100% |
| 3×3 | 11.5% | 15.8% | 34.5% | 61.9% | 84.6% | 100% |
| 4×3 | 6.7% | 17.6% | 35.2% | 60.6% | 81.3% | 100% |
| 4×4 | 11.1% | 12.7% | 26.3% | 60.9% | 83.4% | 100% |

Only ~61% of orbits have a representative in the first half of the colex range on
4×4. **Truncating at 50% is lossy**, losing 39.1% of the canonical set:

| goban | orbits lost at 50% truncation | % of canonical set |
|-------|--------------------------------|--------------------|
| 2×2 | 4 | 30.8% |
| 3×2 | 40 | 34.5% |
| 3×3 | 550 | 38.1% |
| 4×3 | 26 636 | 39.4% |
| 4×4 | 1 055 164 | 39.1% |

### Why truncation fails — orbits are stone-count-locked

Spatial symmetries permute cells, preserving the **set** of occupied cells'
size; colour inversion preserves which cells are occupied. **Every orbit lives
inside a single stone-count layer k.** The colex address is layered by k in
increasing order (`colex.zig` layout), so an orbit's minimum colex is always
within layer k — low-k orbits at the bottom, high-k orbits at the top. The
truncation cut point falls *inside* one layer and leaves every higher layer
uncovered. On 4×4 the 50% cut (21 523 360) lands in layer k=11; **every orbit in
layers k = 12..16 is lost entirely**:

| k | layer offset | cumfrac of range |
|---|--------------|------------------|
| 11 | 19 502 913 | 0.4531 (50% cut falls here) |
| 12 | 28 448 577 | 0.6609 |
| 13 | 35 903 297 | 0.8341 |
| 14 | 40 490 817 | 0.9406 |
| 15 | 42 456 897 | 0.9863 |
| 16 | 42 981 185 | 0.9985 (monochrome orbit lives here) |

### What the loss costs

The lost region is **not scattered noise** — it is the entire high-stone-count
(endgame) region of the table. On 4×4 that is every position with 12–16 stones
plus the upper part of the 11-stone layer: positions a real game reaches in
late endgame and capturing races. **The loss is a predictable, exploitable
weakness** — an opponent who can steer play into the unscored high-stone region
wins by absence of a value, exactly the class of defect this project refuses
elsewhere. It is the opposite of "scattered noise that an opponent cannot aim
at": it is a contiguous, structure-determined hole at exactly the part of the
game that matters most.

**Conclusion.** Truncation is refuted as a compression route; the symmetry fold
must be done by **indexed canonicalisation** (compute the orbit minimum on
lookup, store one value per canonical rep), never by truncating the address
range. The ~16× symmetry fold and ~2× legality fold are real and match
prediction to within the symmetric-position shortfall; the 5×5 ~26 GB target
stands, but it is reachable only via the indexed fold, not a prefix cut.

## Controls

**Null control — colex-min vs lex-min orbit count.** Two independent
canonicalisers were run side-by-side: the main one takes the orbit's
**colex minimum** (the address the oracle table would use), the brute-force
one takes the **lexicographically-least** position string (the
`enumerate.zig` canonicaliser). They must agree on the orbit count, and they do
on every goban:

| goban | colex-min orbits | lex-min orbits | verdict |
|-------|------------------|----------------|---------|
| 2×2 | 13 | 13 | AGREE |
| 3×2 | 116 | 116 | AGREE |
| 3×3 | 1 444 | 1 444 | AGREE |
| 4×3 | 67 625 | 67 625 | AGREE |
| 4×4 | 2 700 373 | 2 700 373 | AGREE |

**Seeded control — perturbed canonicalisation.** The rot90 permutation
(index 5 in `enumerate.zig`'s square layout) was corrupted by swapping two
destination entries, so it is no longer a symmetry, and the orbit count was
recomputed. A correct census must detect the corruption (the orbit count must
change):

| goban | correct orbits | perturbed orbits | verdict |
|-------|-----------------|------------------|---------|
| 2×2 | 13 | 12 | DETECTED |
| 3×3 | 1 444 | 1 431 | DETECTED |
| 4×4 | 2 700 373 | 2 700 228 | DETECTED |

(Rectangles 3×2 / 4×3 have no rot90 to perturb — the D2 group is identity /
flip-x / flip-y / 180° — so the seeded control is square-only by construction.)

**External cross-check.** The canonical-legal counts (8 / 78 / 924 / 40 997 /
1 524 805) reproduce `docs/research/enumeration-census.md` and the Tromp
legal-count column (57 / 489 / 12 675 / 321 689 / 24 318 165 reproduces OEIS
A094777), which the existing `src/enumerate.zig` already validated. This census
re-derives those numbers through an independent colex-min path, not by reading
them.

## What this census is not

- It is a **structure census over the RAW space**, not a value census; it
  assigns no scores and changes no encoding, format, or artifact (per the
  brief). A fold is a format change and needs its own sprint.
- It does not address positional superko or ko-sensitive regions — those are
  unaffected by the symmetry fold, which is a pure address-space compression.
- The 5×5 fold factor (16×) is **extrapolated**, not measured: 5×5 has 3²⁵ =
  847 B positions and was not enumerated. Per the per-goban-independence rule,
  the 4×4 convergence to 15.94× is not *proof* of the 5×5 factor — it is a
  well-motivated extrapolation that the 5×5 build will confirm or refute.
- Per-goban epistemic independence holds: every number above is scoped to its
  own goban; no status at one size is evidence at another, absent a
  monotonicity theorem (not claimed here).

## Deliverable files

- `src/symcensus.zig` — the census instrument (standalone; not wired into
  `build.zig`; run with `tools/runner -- zig run -O ReleaseFast src/symcensus.zig`).
- `docs/evidence/T359-SYM-FOLD/run.txt` — the full program output.
- `findings/T359-symmetry-fold.json` — proposed register row (`GLOBAL.SYM-FOLD`).
- `findings/T359-context.json` — session-context dump.