# Arena 4×4 UNDEF leak — the 45.3% was a sentinel-poisoning artifact

**Date:** 2026-07-27
**Provenance:** B39 (original 4×4 parallel-artifact arena audit) measured a
45.3% leak rate / max 144 pts and attributed it to UNDEF slots. B43 (arena
UNDEF guard) re-measured at **3.4% clean / max 32 pts**, proving the 45.3%
was manufactured by the arena's own unguarded `v0` reads, not (only) a play
defect. This note records both and the honest interpretation.

> **Recovery note (Boss, 2026-07-27):** B43's S4 was specified to append its
> re-measure section to the B39 arena bundle in `untracked/` scratch. B43 and B44 (cleanup)
> were dispatched in parallel; B44's S3 deleted `B39-arena4x4.md` as a
> folded-done bundle, colliding with B43's S4 write. The appended note was
> lost. The data below was recovered verbatim from the B43 bundle
> (`untracked/B43-arena-undef.md` S3) and promoted to this durable git note —
> its proper home per the "findings move from untracked scratch to git docs
> once they stabilize" rule. The lesson (serialize or protect S4 targets when
> a cleanup bundle runs in parallel) is recorded at the end.

## The artifact

`data/oracle-4x4-parallel.checkpoint.wzo` (4×4, writes-off finisher,
99.8% filled). 83K slots are UNDEF (2-ko+ positions) and store the sentinel
`-128`. The GTP player (B40) and the arena (B43) must both treat `-128` as
"no fresh-start belief," never as a real score.

## The bug (pre-fix arena, B39's 45.3%)

`src/arena.zig` read `s.v0(...)` raw in three places in the per-ply loop:

1. Move enumeration: `vals[cnt] = s.v0(&child, -side)` stored `-128` as a
   real child value.
2. Promise tracking: `stored = s.v0(&s.pos, side)`, then
   `if (audited_color > 0) { if (stored > promise) promise = stored }`
   `else if (stored < promise) promise = stored`. For **White-audited**, a
   UNDEF `stored` set `promise = -128`.
3. Divergence tally: `if (best != stored)` fired spuriously when `best`
   (derived from UNDEF children) or `stored` was UNDEF.

The leak formula `leak = score - promise` (White-audited) then yielded
`score - (-128) ≈ 112–144` — the exact B39 signature. This was a
**measurement artifact**, independent of which move the player actually
played. B40 (which only fixed `src/gtp.zig`) therefore could NOT move this
number on its own.

## The fix (B43, `src/arena.zig`)

- Skip UNDEF children in move enumeration (mirror `gtp.choose`).
- Do not update `promise` when `stored == UNDEF`; mark the game
  `undef_tainted` instead.
- Do not count a divergence when `stored` or `best` is UNDEF-derived;
  count it as a tainted ply.
- Report `undef_tainted_games` / `undef_tainted_events` separately from
  `leaks`; do not fold tainted games into the leak rate. Tainted-game leaks
  are bucketed as `undef_tainted_leaks` / `undef_tainted_max_leak`.

## Re-measure (B43, post-fix)

`bin/weizigo-arena data/oracle-4x4-parallel.checkpoint.wzo 100` (same as
B39: 100 seeds × 6 personas × 2 colours × 3 handicaps = 3600 games).

| persona | games | CLEAN-LEAKS | max | clean-leak% | UNDEF-tainted | tainted-leaks | div single | div ko |
|---|---|---|---|---|---|---|---|---|
| optimal | 600 | 10 | 32 | 1.7% | 200 | 0 | 1 | 25 |
| winning-any | 600 | 26 | 19 | 4.3% | 200 | 0 | 52 | 53 |
| winning-slop | 600 | 46 | 28 | 7.7% | 200 | 0 | 26 | 119 |
| dan | 600 | 11 | 32 | 1.8% | 200 | 0 | 22 | 20 |
| kyu | 600 | 18 | 32 | 3.0% | 192 | 0 | 38 | 45 |
| novice | 600 | 12 | 32 | 2.0% | 178 | 1 (max 3) | 37 | 38 |
| **TOTAL** | **3600** | **123** | **32** | **3.4%** | **1170** | **1** | **176** | **300** |

Sanity (S2): on the fully-filled 3×3 artifact the guard is inert — every
summary number is byte-identical to pre-fix; only the column label changed
(`LEAKS` → `CLEAN-LEAKS`).

## Honest interpretation

- **The 4×4 parallel artifact's real (non-UNDEF) leak rate is 3.4%, max
  32 pts** — within and slightly better than the T06 baseline band of
  8–18%. The 45.3% / 144-pt pre-fix number was a sentinel-poisoning
  artifact of the measurement tool, not a property of the artifact's
  filled region.
- **32.5% of audited games (1170/3600) touch a UNDEF slot.** These are
  OUT OF SCOPE of the belief audit: a UNDEF slot holds no fresh-start
  belief, so there is nothing to leak. Only 1 of 1170 tainted games
  "leaked" (3 pts, novice) — noise.
- **E1 / C2 falsification is unchanged.** 176 single-score + 300
  ko-sensitive REAL divergence events remain (down 16× from 7825
  pre-fix; the 7,349 removed were UNDEF counter-fires, not real
  divergences). C2 remains falsified at 3×2 (T13) and corroborated at
  4×4 scale; per-goban epistemic independence holds.

## Lesson (process, Boss dispatch)

Dispatching B43 (writes its S4 to the B39 arena bundle in `untracked/` scratch) and B44
(deletes folded-done `untracked/` bundles) in parallel was NOT fully
parallel-safe: both operated on the `untracked/` scratch namespace, and
B44's deletion swept B43's S4 target. Two fixes for future parallel
dispatch:
1. A task that appends to an existing bundle file must list that file in
   its `holds=` (or in the cleanup bundle's PROTECTED list) so a parallel
   deletion cannot race it.
2. Prefer writing durable findings to git `docs/research/` directly, not
   by appending to untracked scratch — which is where this note now lives.