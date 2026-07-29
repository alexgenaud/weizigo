# Reconciliation evidence — partial rescue, 2026-07-28

**Status: PARTIALLY RECOVERED. The source is permanently lost.**

## What happened

EXP-3's calibration disagreed with its own dispatch brief (`CLAIMS.md` §6-D18):
the brief expected 25,350 / 643,378 / 48,636,330 for 3×3 / 4×3 / 4×4; the census
measured different figures. The console wrote an independent breadth-first search
to reconcile the two — a **depth-parity BFS** — and judged the brief wrong.

That reconciling program was written to `/tmp/test_census_pure.zig` and **never
committed**. By the time it was flagged, `/tmp` had been cleared and the source
was gone. This is the **T13 mechanism repeating** — the same failure that
destroyed `untracked/c2pilot_3x2.zig`, the probe behind the falsification the
whole project strategy rests on (`docs/evidence/README.md`) — and it happened on
the best-calibrated experiment in the project.

## What was recovered, and from where

The compiled artefact survived in the experiment's Zig cache:

| file | source | note |
|---|---|---|
| `test_census_pure.bin` | `/private/tmp/weizigo-zigcache-exp3/o/4a1e974bc7957bf767ed23984b123048/test_census_pure` | the compiled binary; **still runs** |
| `zig-cache-manifest.txt` | `/private/tmp/weizigo-zigcache-exp3/h/26e612db720d67ed47c6fcff35f7311c.txt` | the Zig cache manifest recording the compilation inputs |
| `output-recovered-2026-07-28.txt` | re-running the binary on 2026-07-28 | its actual output, captured before the cache is cleared too |

**The Zig cache is also in `/tmp` and will be cleared.** The binary copied here is
the only surviving executable form; treat it as an artefact of unknown internals,
not as reproducible code.

## The recovered result, and why it matters

```
Reachable from empty (BFS, depth parity):
  B-only:   5712
  W-only:   5397
  both:     0
  neither:  8574
  total reachable positions:        11109
  total (position, side) reachable: 11109
```

**`both: 0` is the finding.** At 3×3, no legal position is reachable with *both*
sides to move. Stone-count parity fixes whose turn it is, so `5712 + 5397 = 11,109`
and reachable `(position, side)` pairs equal reachable **positions** — not twice
them.

That is the mechanism behind D18: a dispatch brief that assumed
`legal positions × 2 sides` was counting a denominator the game cannot reach. The
census was right and the brief was wrong, and this BFS is what showed it.

**Status of the finding: CLAIMED, not PROVEN.** The result is recovered; the
*method* is not. Nobody can now read the BFS and confirm it implements depth
parity correctly, so the number is an artefact of a program we can run but not
inspect.

## What is owed

1. **Rewrite the depth-parity BFS from scratch** and commit it here. It is a
   small program and the recovered output above is a check target — if a fresh
   implementation reproduces `5712 / 5397 / 0 / 8574`, the finding is re-earned
   properly and this row can go PROVEN.
2. **Extend it to 4×3 and 4×4**, since the denominator question applies there too
   and only 3×3 output survived.
3. Until (1), cite this directory as *recovered evidence with lost method*.

## The lesson, for the fourth time

`docs/evidence/README.md` records seven files lost this way. `arena-4x4-undef.md`
records the same failure a sprint earlier and drew the right conclusion — *write
durable findings straight to git* — which was then not applied. `AGENTS.md` now
carries it as a standing rule, and `DELEGATEE.md` repeats it.

**It still happened.** The rule is not the fix; the *habit* is. A program that
produces a number cited in a claim belongs under `docs/evidence/` **at the moment
it is written**, not when someone notices.
