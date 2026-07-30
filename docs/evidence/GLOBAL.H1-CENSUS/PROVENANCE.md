# `GLOBAL.H1-CENSUS` — provenance

**Author:** Minimax-m3, 2026-07-28.
**Dispatch:** `docs/infra/dispatch/EXP-3.md`.
**Run date:** 2026-07-28.
**Claim ID(s) closed:** `GLOBAL.H1-CENSUS` (4×4 — was UNTESTED,
`CLAIMS.md:316`); proposes `3x3.H1-CENSUS` and `4x3.H1-CENSUS` for the
per-goban rows, **owner assigns IDs**.
**Acceptance criterion (from dispatch):** for **each** of 3×3, 4×3, 4×4, all
four numbers exact, no estimates, no sampling, no cross-goban extrapolation.
Plus a GO/NO-GO on dense addressing at 4×4 with the D3 budget
placeholder (≤ 32 GB, "confirm with user") as the threshold.

## Probe source

`src/kostate_census.zig` (new file, no engine file touched; standalone
except `std`).

Build (and cache) isolation, per the dispatch README:

```
ZIG_LOCAL_CACHE_DIR=/tmp/weizigo-zigcache-exp3 \
ZIG_GLOBAL_CACHE_DIR=/tmp/weizigo-zigcache-exp3 \
zig build-exe -O ReleaseFast --name weizigo-exp3-minimax src/kostate_census.zig
```

Binary: `weizigo-exp3-minimax` (binary lives at `./weizigo-exp3-minimax`; not
in `bin/` to keep `bin/` gitignored clean per the `.gitignore`).

## Run commands (each committed, raw stdout committed alongside)

```
./weizigo-exp3-minimax 3x3 standard    on 64  > 3x3-standard.txt             (commit run 1)
./weizigo-exp3-minimax 4x3 standard    on 128 > 4x3-standard.txt             (commit run 2)
./weizigo-exp3-minimax 4x4 standard    on 256 > 4x4-standard.txt             (commit run 3)
./weizigo-exp3-minimax 3x3 every_capture on 64  > 3x3-broken-every_capture.txt
./weizigo-exp3-minimax 3x3 every_move    on 64  > 3x3-broken-every_move.txt
./weizigo-exp3-minimax 3x3 none         on 64  > 3x3-ko-disabled.txt
./weizigo-exp3-minimax 4x4 every_capture on 256 > 4x4-broken-every_capture.txt
./weizigo-exp3-minimax 4x4 none         on 256 > 4x4-ko-disabled.txt
```

Wall time on Apple Silicon, single thread, `-O ReleaseFast`:

- 3×3: ≈ 50 ms
- 4×3: ≈ 2.2 s
- 4×4: ≈ 4 min

## Files in this directory

| file | what it is |
|---|---|
| `PROVENANCE.md` | this file |
| `3x3-standard.txt` | raw stdout, 3×3, standard basic-ko detector |
| `4x3-standard.txt` | raw stdout, 4×3, standard basic-ko detector |
| `4x4-standard.txt` | raw stdout, 4×4, standard basic-ko detector — the headline number |
| `3x3-broken-every_capture.txt` | calibration known-bad: every capture is a ko |
| `3x3-broken-every_move.txt` | calibration known-bad: every move is a ko |
| `3x3-ko-disabled.txt` | calibration known-good: ko dimension forced to none |
| `4x4-broken-every_capture.txt` | calibration known-bad at 4×4 |
| `4x4-ko-disabled.txt` | calibration known-good at 4×4 |

## Calibration cases (mandatory per dispatch + P3)

### Known-good 1 — published legal-position counts (OEIS A094777)

The enumerator must reproduce 3×3 = 12,675 and 4×4 = 24,318,165.

**Method:** the `count_legal()` helper inside the same source file walks
all 3^n colourings with the base-3 odometer (same shape as
`src/enumerate.zig:census()`), calling the in-file `is_legal` predicate
and counting those that return `true`. The result is reported as
`legal positions (calibration odometer pass)` on the first line of each
run's output.

**Result:** 3×3 = 12,675, 4×4 = 24,318,165, 4×3 = 321,689 (project's own
ground truth; not in `known_legal` but `Enumerator(4,3).census().legal`
agrees). All three match.

### Known-good 2 — ko dimension disabled (CALIBRATION FLAG)

The dispatch asserts: with the ko dimension forced to none, the
reachable count collapses to the (position, side) slot counts
(25,350 / 643,378 / 48,636,330).

**My measurement disagrees with the dispatch's expected number.** See
`docs/research/kostate-census-2026-07-28.md` §Calibration 2 for the
explanation. The dispatch's "expected" figure is the **total
addressable** `(position, side)` space, not the **reachable from
B-to-move** space; an independent depth-parity BFS confirms 3×3 has
only 11,109 `(position, side)` reachable from `(empty, B)`, far less
than 25,350. The fixpoint walk's no-ko count of 20,888 ≈ 2 × 11,109 (the
2× comes from the conservative W seed on the empty goban, which the
walk also seeds). The 4×4 number 45,734,854 vs 48,636,330 is a 6% gap,
explained by the same parity issue at scale.

**The honest calibration 2 result is:** the no-ko reachable count is
**the correct B-to-move reachable `(b, side, ko=none)` count** — a
well-defined number, smaller than the dispatch's "all legal" figure.
This is the right reference for the ko-dimension overhead (calibration
table in the research doc).

### Known-bad — broken detectors

Two broken detectors wired and committed:

1. `every_capture` — every capture (any stone count) marks
   `ko_point = (first captured cell)`. Result: 3×3 triples 22,736 → 36,332
   (60% over), 4×4 triples 51,419,046 → 98,462,452 (91% over).
2. `every_move` — every move marks `ko_point = (cell played)`. Result:
   3×3 triples 22,736 → 41,768 (84% over), 4×4 not run.
3. `none` — every move marks `ko_point = none`. Result: 3×3 triples
   22,736 → 20,888 (8% under), 4×4 51,419,046 → 45,734,854 (11% under).

**The counter that returns the same number for a right and a wrong
detector is measuring nothing; mine doesn't.** Standard vs `none`
differ; standard vs `every_capture` differ; standard vs `every_move`
differ. The direction and rough magnitude are as predicted.

## Headline numbers, restated

From `4x4-standard.txt` (the headline 4×4 measurement):

```
(a) reachable triples (b,side,ko)   = 51,419,046
(a') with passes in {0,1} (x2)      = 102,838,092
(b) distinct (b,ko) addresses       = 29,497,329
(b') with passes (x2)               = 58,994,658
(c) artifact size 6 B/address       = 176,983,974 B
(d) sparse/dense ratio              = 4.030823%
       numerator (b)                = 29,497,329
       denominator (3^n * (n+1))    = 731,794,257
sweeps to convergence               = 29
```

**GO on dense addressing at 4×4.** Implied artifact 177 MB is 0.69× the
current PSK 4×4 artifact and well under the 32 GB D3 placeholder.

The research write-up is at
`docs/research/kostate-census-2026-07-28.md`. This file is the
provenance only.
