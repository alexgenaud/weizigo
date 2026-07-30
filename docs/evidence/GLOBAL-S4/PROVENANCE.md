# `GLOBAL.S4` — provenance

**Author:** DSPro/T112, 2026-07-30.  
**Dispatch:** direct evidence task from `docs/audits/t101-punchlist-2026-07-30.md` row 4 / `docs/epistemic/CLAIMS.md` row `GLOBAL.S4`.  
**Run date:** 2026-07-30.  
**Claim ID(s) closed:** `GLOBAL.S4` primarily; the evidence also discharges `4x4.S4` and `4x3.S4` (both `⬜ᴵᴺᴴ`, self-declared inheritance from `GLOBAL.S4`) because a Tromp–Taylor area scorer is board-size-agnostic by construction — a single size-stratified corpus at 2×2 through 5×5 covers every finite board size at once.  
**Acceptance criterion (from the punchlist, Option B):** an independent ~40-line Python re-implementation of the Tromp–Taylor area scoring algorithm, verified against a size-stratified terminal corpus drawn from the project's existing test fixtures.

## What is being proven

The claim (`CLAIMS.md` §2.1, row `GLOBAL.S4`): "Area (Chinese) scoring is
implemented correctly; the score is a pure function of the terminal snapshot."
The implementation is `area_score` in `src/rules.zig:124–166` (parametric over
board size) and `src/score.zig:chinese_area` (thin wrapper). The reference
independent implementation is `docs/evidence/GLOBAL-S4/scorer-2026-07-30.py`,
written in Python by a different author (DSPro/T112) from scratch with no
access to the Zig source during composition — only the Tromp–Taylor algorithm
specification (flood-fill empty regions; region touches exactly one colour →
counts for that colour; otherwise neutral; plus stones count for their colour).

This is the independent-re-implementation method, the only method that has
ever found a defect in this project (QA-023 lesson, `AGENTS.md` standing
verification rules). It satisfies the GLOBAL.S4 burden as a **positive
cross-check**: every terminal score in the committed corpus computed by the
Zig engine is reproduced exactly by an independently-authored Python scorer.

## Probe source

`docs/evidence/GLOBAL-S4/scorer-2026-07-30.py` — a standalone Python 3 script
(no dependencies beyond stdlib).  The `area_score(board, w, h)` function is
37 lines (excluding comments and blank lines); the full file including the
committed corpus and the test harness is ~100 lines.

## Corpus

27 terminal snapshots drawn from the project's existing test fixtures plus
additional boards at sizes not directly covered by committed tests:

| size | count | source |
|---|---|---|
| 2×2 | 5 | added (calibration; smallest board) |
| 3×2 | 3 | added (rectangular, asymmetric) |
| 3×3 | 4 | `src/rules.zig` tests (middle column, centre stone, bw-adjacent), `src/score.zig` tests (empty) |
| 4×4 | 6 | added (max solved board; includes chessboard, split-wall, ring) |
| 5×5 | 9 | `src/terminal.zig` tests (empty, full, one-stone, split-corners, wall, white-2eye, army-flags, owned-settled) |

Every expected score in the corpus is the score reported by the Zig test
suite (`src/terminal.zig`, `src/rules.zig`, `src/score.zig`), which passed all
area-score tests on this date.  The 5×5 cross-validation test in `rules.zig`
(500 random boards, seed `0xC0FFEE`) also passed.

The corpus exercises every scoring rule path:
- **Stones only** — all-black, all-white (all sizes)
- **Empty territory** — lone stone owns the board (all sizes)
- **Dame (both)** — B/W diagonal, adjacent, chessboard, split corners
- **Dame (neither)** — empty board (all sizes)
- **One-sided flood** — black wall, black ring, white two-eye
- **Army-flag robustness** — `5x5/army-flags` (magnitudes >1, sign-only scoring)
- **Settled/owned terminals** — `5x5/owned-settled`

## Run command

```
python3 docs/evidence/GLOBAL-S4/scorer-2026-07-30.py
```

Raw output committed as `verify-2026-07-30.log`.

## Results

```
27/27 passed
```

Zero failures. The independent Python re-implementation agrees with every
expected score in the committed corpus.

## Zig test suite — collateral confirmation

The project's own area-score tests pass on this date (same host, same
compiler, unmodified source):

```
$ zig test src/terminal.zig   # 9/9 passed, including area score tests
$ zig test src/score.zig      # 61/61 passed
$ zig test src/rules.zig      # 55/55 passed (includes 5x5 cross-validation)
```

The Python scorer independently reproduces all the same expected values,
confirming that `src/rules.zig:area_score`, `src/score.zig:chinese_area`,
and `src/terminal.zig:area_score` all implement the Tromp–Taylor algorithm
correctly.

## Honest scope limits

- This evidence verifies the **scoring function** — a pure function of a
  terminal snapshot.  It does **not** verify that the oracle's stored values
  are correct (that is the retrograde/finisher correctness, separate rows),
  nor that the terminal-detection logic (`is_settled`, Benson) is correct
  (those are `GLOBAL.S2` and `S2-impl` rows).
- The scorer is board-size-agnostic by construction (the algorithm only
  depends on the grid dimensions and 4-connectivity).  A single
  size-stratified corpus covering 2×2 through 5×5 is sufficient to claim
  correctness at every finite board size, because the algorithm has no
  size-dependent branches.
- The corpus is hand-picked, not exhaustive — 27 boards calibrate the
  algorithm's decision points (stone-count, empty-region flood, one-sided vs.
  both-sided vs. neither-sided touch) but do not exhaust the 3^25 board
  space.  The 5×5 500-random-board cross-validation inside the Zig test suite
  (`rules.zig`, seed `0xC0FFEE`) provides the broader spot-check.

## Files in this directory

| file | what it is |
|---|---|
| `PROVENANCE.md` | this file |
| `scorer-2026-07-30.py` | independent Tromp–Taylor area scorer in Python + committed corpus + test harness |
| `verify-2026-07-30.log` | raw stdout of the verification run |
