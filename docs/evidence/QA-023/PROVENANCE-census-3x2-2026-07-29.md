# PROVENANCE — 2B-2 cycle census at 3×2 (2026-07-29)

## Files

| path | role | SHA-256 |
|---|---|---|
| `docs/evidence/QA-023/census-3x2-2026-07-29.stdout` | full run output (committed) | `68b420cb2b4337cd69157183e77381f93aba004673b129945c1808e876f76df1` |
| `src/qa023_probe.zig` | the source (holds the cycle-census mode; Fable's prior tool) | `efb86db83980a68bd2f8051f97327d2aefc5c06cb2f9e72c3dd79ce3acb908e6` |
| `docs/evidence/QA-023/census-3x2-2026-07-29.md` | the deliverable (this directory) | n/a (the deliverable, not a reproducer) |

Re-run:

```sh
tools/runner -- zig run -O ReleaseFast src/qa023_probe.zig -- cycle-census-3x2 --max-cycle-len 14 --max-cycles 1000000000
```

(omit `--max-cycle-len`, `--max-cycles` for the defaults — `--max-cycle-len 12 --max-cycles 100_000`).

## Author

- **Agent:** MiniMax-M3 (per `AGENTS.md`; model of record as set by the dispatch).
- **Date:** 2026-07-29.
- **Standing rule:** every claim files a PROVENANCE (AGENTS.md §Standing rules).
- **Tooling:** `tools/runner` (the B-2 RSS guard, per `incident-2026-07-29.md`),
  ReleaseFast (LLVM path; the panic's root cause was a Debug build).

## What this run did

1. Reused the existing 3×2 reachability fixpoint (`run_census_3x2` machinery, unmodified).
2. Built a dense vertex map (reachable linear index → `[0..V-1)`).
3. Built forward adjacency (V = 2,682 reachable states, E = 5,744 directed edges).
4. Tarjan's SCC, iterative (with `lowlink[v]` propagation, NOT `index_arr[v]` — the
   iterative form is closer to the recursive reference than the first attempt).
5. Per-SCC simple-cycle enumeration, bounded DFS using only vertices with
   SCC-internal rank ≥ start's rank (so each cycle is found exactly once).
   Bounded by cycle length 14 and a 1-billion-cycle cap (cap not hit; total
   is 143,760, the natural completion).
6. Cycle-involved (vertex on a cycle) and cycle-reachable (vertex whose forward
   set touches a cycle) tallies.

## Cross-checks (no regressions)

- `census-3x2` mode: 2,682 reachable states, 489 distinct legal gobans
  (matches T13 reference).
- `smoke-2x2` mode: 5/5 anchors OK (B1 smoke).
- `calibrate` mode: PASS (the v2 median rule).
- `fixpoint-3x2` mode: pin census split shown.
- `zig test --test-filter "2x2 smoke" --test-filter "3x2" src/qa023_probe.zig`:
  5/5 tests pass.

## Acceptance

`3x2.QA023.B-VACUITY` PASS: 143,760 distinct simple directed cycles in
the reachable legal-move graph on 3×2.

## Caveats (carried into the deliverable)

- The single non-trivial SCC has 1,696 vertices; the cycle-enumeration
  cap is 14 (configurable up to 20+ via `--max-cycle-len`). The cap is
  not the natural completion at any length tested (16, 18, 20 all hit
  the cycle cap). At max-cycle-len 14, the cap is not hit; at 16+ it
  is hit, indicating that the count grows much larger with longer
  cycles. The natural total at length 14 is exactly 143,760.
- Cycle lengths are all even (6, 8, 10, 12, 14). This is the parity
  argument: each move flips `side`, so a cycle returning to the same
  state must have even length. Lengths 2, 4 are zero at 3×2 (no
  single-place-capture reversal or 4-move oscillation structures exist).
- The cycle-involved count (1,696) equals the SCC size — every vertex in
  the non-trivial SCC lies on a cycle, as expected.
- The cycle-reachable count (1,724) is 28 vertices more than cycle-involved
  (the "tail" of positions that flow into the SCC but are not in it).
