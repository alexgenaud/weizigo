# Human play against the 4×4 oracle — two games, one defect

```
Date:     2026-08-02 · Human = Black, weizigo-gtp = White
Artifact: untracked/oracle-v2/oracle-4x4-v2.wzo2, SHA-256 0c3366f0… (M4a 4/4, T212)
Replay:   bin/weizigo-gtp <artifact> < human-game-{1,2}.gtp
```

**The human won both games.** A human at a 4×4 goban found, in twenty moves, a
defect that M4a's four acceptance checks, the 60-cell verify-battery fleet run,
and the differential agreement matrix all missed.

## What was observed

Game 2, move 4 — the engine had been playing perfectly, brackets narrowing
`[L=-16,H=-1]` → `[L=-16,H=-16]` with `dtt` counting 9, 7, 5:

```
lookup-miss — colex=1023353 side=1 ko=12 passes=0 not in artifact, fell back to area score -2
W -> A4  child-value=0 stored-v0=-1 (UNCHAINABLE — refused V0 comparison; played history-free fallback)
```

From there White collapsed: `[L=-16,H=-16]` (winning by the maximum) →
`[L=6,H=6]` → `[L=16,H=16]` (losing by the maximum). It then passed while a
capture was available — correct behaviour once the outcome is fixed, since
every continuation loses identically, but the loss came from the two fallback
moves. In game 1 the same collapse ended with White filling its own two-point
eye, which is what a greedy no-lookahead heuristic does.

## Root cause

`src/gtp.zig` `koAfterCapture` set a ko point on **any** single-stone capture.
`src/exp6_solve.zig:285,575` sets one only when the capturing stone is itself
in atari with no friendly neighbours (`liberties == 1 and friendly == 0`) —
the real ko shape. The engine therefore built lookup keys the solver never
enumerated, missed the table, fabricated an area-score row, failed the Bellman
comparison, refused, and played the greedy fallback.

One wrong ko determination puts the game **off-manifold**: every later lookup
misses regardless of its own ko field. That is why misses appeared at `ko=0`
and even at `ko=16` (KO_NONE) with `passes=1` — states with no ko at all. A
single root cause explains all of them.

## Before and after (T265 fix)

| | game 1 | game 2 |
|---|---|---|
| misses before | ~14 | 12 |
| UNCHAINABLE refusals before | 2 | 2 |
| **misses after** | **0** | **0** |
| **fallbacks after** | **0** | **0** |
| lookups after | 305 | 312 |
| engine moves after | 10 | 10 |

White's losing move in game 2 (`A4`, a fallback) becomes `B1` from the table.

## Why no automated check caught it

M4a verifies the table is internally consistent. The battery verifies
invariants within an artifact. The differential harness compares
implementations of one operation. **None asks whether the consumer looks up the
key the producer wrote** — and this is the third defect of that family, after
T178 (exp6 rank vs colex) and T193 (passes bit encoded as 0).

The missing invariant: for positions reachable by real play, the key the engine
constructs must equal the key the builder would write.

## Instrumentation earned its place

Every miss printed its exact state, `UNCHAINABLE` announced each refusal, and
`weizigo-stats` counted them. The diagnosis took one reading of the transcript.
Without those counters — nearly dismissed as redundant the same evening — this
would have been "the engine plays badly sometimes".
