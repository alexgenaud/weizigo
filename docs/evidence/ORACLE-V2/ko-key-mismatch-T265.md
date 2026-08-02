# T265 — ko key mismatch between engine and solver

```
Found:    human play, 2026-08-02 (docs/evidence/ORACLE-V2/human-games-2026-08-02.md)
Fixed:    626ec55 · Verified: both human games replay 0 misses, 0 fallbacks
```

## The divergence

| | rule | source |
|---|---|---|
| **Solver** | ko exists only when the capturing stone is itself in atari with no friendly neighbours (`liberties == 1 and friendly == 0`) | `exp6_solve.zig:285`, `:575` |
| **Engine** (before) | ko exists on **any** single-stone capture | `gtp.zig` `koAfterCapture` |

Capturing a lone stone with a solid multi-stone group creates no ko. The engine
disagreed, built a key the solver never enumerated, missed the table,
fabricated an area-score row, failed the Bellman comparison, refused, and
played the greedy history-free fallback.

**Off-manifold propagation.** One wrong ko determination makes every later
lookup in that game miss regardless of its own ko field — which is why misses
appeared at `ko=0` and at `ko=16` (KO_NONE) with `passes=1`. A single root
cause; confirmed by replay.

## Verification

| | game 1 | game 2 |
|---|---|---|
| misses before / after | ~14 / **0** | 12 / **0** |
| UNCHAINABLE refusals before / after | 2 / **0** | 2 / **0** |
| lookups after | 305 | 312 |

Fixtures: `human-game-1.gtp`, `human-game-2.gtp` — pipe into `weizigo-gtp`.

## The family, and the invariant still owed

Third defect of one kind:

| task | mismatch |
|---|---|
| T178 | exp6 rank vs combinatorial colex |
| T193 | passes=1 rows encoded with passes=0 |
| **T265** | ko point set on any capture vs only on the ko shape |

**Every one is a lookup key built differently by producer and consumer, and
nothing tests that they agree.** M4a verifies the table is internally
consistent; the battery verifies invariants within an artifact; the
differential harness compares implementations of one operation. None asks
whether the consumer looks up the key the producer wrote.

**Owed:** a key-agreement operation in `src/differential.zig` — for positions
reachable by real play, the key the engine constructs must equal the key the
builder would write, checked at every goban size. That check would have caught
all three. Not delivered by this task.

## Not the whole story

The ko fix does not make the artifact correct. T261's scan found ~27.9% of
sampled 4×4 groups carry `passes=1` entries for only one side (~6.77M of
~48.6M missing), and oracle self-play ends `W+2` against a root recorded as
`L=+1 H=+16`. The artifact is incomplete independently of this defect.
