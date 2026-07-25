# Forward full-solve of empty 5x5: measured intractable (2026-07-16)

First instrumented attempt at the empty-board 5x5 full solve using the existing
**forward exhaustive minimax + transposition table** (`solve.zig`), via the
`main.zig` driver (`FULL = true`). This was TODO #1-followup: wire + size a TT
into the FULL path and measure.

## Setup
- Build: `-Doptimize=ReleaseSafe` (bounds panics live).
- Root: empty board, Black to move, komi 0.
- TT: two dense `[1<<25]u32` blind arrays (256 MB total) + a `2 GB` `SeqScore`
  seq pool (`1<<29` slots). Resident set ~2.3 GB.
- Solve on a dedicated 256 MB-stack thread; main thread samples the existing
  `history.max_len` and `Table.next` counters (no instrumentation added to the
  hot `solve` path).

## Observations
- `max_ply` (deepest game line) climbed **steadily to 200-210 plies**, then
  plateaued around 200-210 while the process kept grinding.
- `tt_blocks` (= `Table.next`) **stayed at 1 the entire time** — i.e. the TT
  allocated **zero** blocks: nothing was cached.
- No completion after minutes; killed. (Did not reach the `MAX_LINE = 4096`
  panic, so this run gives a lower bound on line depth, not the true maximum.)

## Interpretation
1. **Line length ≫ stone count, confirmed empirically.** The DFS reaches 200+
   plies on a board that never holds more than ~20 stones — captures let a line
   keep changing without net growth. So recursion depth is a *ply count*, and
   `MAX_LINE = 4096` is not obviously excessive. (The earlier skepticism that
   even 50 plies is unbelievable is refuted: 200+ occurs immediately.)
2. **The TT gets zero traction in the opening.** `tt_blocks` never leaving 1
   means no node the search finished was cacheable. The most likely dominant
   cause is **GHI taint**: under positional superko the opening is full of
   repetition bans that reference ancestor plies (`ko_ref < d`), and such nodes
   are deliberately not cached for soundness (ADR-0005). (The 16-stone hash
   cutoff and "not yet unwound to a cacheable node" also contribute; this run
   did not isolate the exact mix — that would need a per-node cache-miss-reason
   counter.)
3. **Therefore the forward exhaustive solve does not converge** on the empty
   5x5 board and is not, by itself, a route to the oracle — as the strategy doc
   anticipated ("current exhaustive forward minimax = least efficient").

## Conclusion (feeds ADR-0007)
Strong empirical support for the **retrograde / enumeration** direction:
propagate values from terminals over an *enumerated* canonical position set,
handling history-independence *structurally* (GHI bucketing) rather than by the
forward search's "don't cache if tainted" — which here caches nothing.

`solve.zig` remains valid and valuable as a **correctness reference on small /
near-terminal positions** (validated: `dead_white` -> Black +25 both sides,
colour symmetry, TT == no-TT). It just cannot produce the 5x5 oracle from empty.

## Reproduce
Set `main.FULL = true`, `zig build run -Doptimize=ReleaseSafe`. Watch
`max_ply` / `tt_blocks`. Default is `false` (the fast demo).

## Follow-ups (optional, low priority vs. building the retrograde engine)
- Per-node cache-miss-reason counters (tainted vs >16 stones vs pass-layer) to
  quantify why the TT stays empty.
- A current-depth gauge (not just max) to distinguish "still descending" from
  "backtracking through uncacheable nodes".
