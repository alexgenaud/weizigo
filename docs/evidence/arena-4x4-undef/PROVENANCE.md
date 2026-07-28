# Provenance — `arena-4x4-undef/` raw arena run outputs

Added 2026-07-28 by the `docs/evidence/` rescue sweep. The `.txt` files in this
directory are **verbatim, unmodified** arena stdout captures; provenance is
recorded here rather than inside them so the run output stays byte-identical to
the original.

**Supports:** `4x4.B43` (3.4% clean leak, 123/3600, max 32 pts),
`4x4.B43-DIV` (176 single-score + 300 ko-sensitive real divergence events),
`4x4.B39` (the retracted 45.3% / max 144 pts measurement artifact),
`CODE.UNDEF`.

**Cited by:** `docs/research/arena-4x4-undef.md` (the durable note) via the
B43 bundle; the bundle itself names these files at
`B43-arena-undef.md:205` (3×3 pre/post-fix) and `B43-arena-undef.md:234`
(4×4 post-fix).

| file | original path | original mtime | bytes | sha256 (first 16) |
|---|---|---|---|---|
| `B43-arena-undef.md` | `untracked/B43-arena-undef.md` | 2026-07-27T18:19:58 | 12,396 | `1ed0d86d1c63879f` |
| `3x3-prefix.txt` | `untracked/B43-baselines/3x3-prefix.txt` | 2026-07-27T18:17:14 | 3,917 | `8be83433c6a0a1c9` |
| `3x3-postfix.txt` | `untracked/B43-baselines/3x3-postfix.txt` | 2026-07-27T18:18:39 | 4,421 | `067c502710be2e1b` |
| `4x4-postfix.txt` | `untracked/B43-baselines/4x4-postfix.txt` | 2026-07-27T18:18:46 | 26,163 | `f552a8a469ab3fba` |

Note: `B43-arena-undef.md` carries its own inline provenance header, so its
committed copy is **not** byte-identical to the original; the sha256 above is
the original's.

## What the runs are

- `3x3-prefix.txt` — arena on `artifacts/oracle-3x3.wzo`, 5 seeds × 2 colours ×
  3 handicaps, **before** the UNDEF-sentinel guard in `src/arena.zig`.
- `3x3-postfix.txt` — same configuration, **after** the guard. 3×3 is the
  calibration case: it has no UNDEF slots, so pre and post must agree.
- `4x4-postfix.txt` — arena on `data/oracle-4x4-parallel.checkpoint.wzo`,
  100 seeds × 2 colours × 3 handicaps, **after** the guard. This is the run the
  3.4% figure is computed from.

Each `LEAK` line carries persona, seed, audited colour, handicap,
`promise`/`final` (Black-positive), diverged-event count, and the full move
sequence — enough to replay a single game by hand.

## Reproduction

The 4×4 run needs `data/oracle-4x4-parallel.checkpoint.wzo`, which is **not in
git** (`data/` is git-ignored, `.gitignore:4`). The run is therefore not
reproducible from a clean clone. See `docs/evidence/README.md` §"Artifacts not
committed".
