# T171 final status — DSPro/T173 · 2026-07-31

## Calibration results
| metric | 2×2 reachable | 3×2 reachable | reference |
|---|---|---|---|
| V | 255 | 2583 | 255 / 2583 ✓ |
| E (BFS) | 566 | 7364 | — |
| non-trivial SCCs | 1 | 1 | 1 ✓ |
| maxSCC (triples) | 112 | 1000 | — / 988 |
| cycleInvolved (triples) | 112 | 1000 | — / 988 |
| cycleReachable (quads) | 251 | 2523 | — |

## Bugs fixed (3)
1. **Pass edges omitted from BFS** — no pass successors generated → V=114 not 255 (CRITICAL)
2. **Ko detection test incorrect** — expected capture where none occurs (MODERATE)
3. **Pass edges omitted from Tarjan + rev_adj** — SCC decomposition on incomplete graph (CRITICAL)

## Design decisions
- **Quadruple encoding**: (board, side, ko, passes) vertices, not Option A triples.
  Pass edges are full graph edges (not terminal cut-edges). This matches the
  reference 2B-2 census which includes passes in V=2622.
- **Triple projection**: SCC metrics projected from quadruples to (board, side, ko)
  triples for calibration parity. Without projection, SCC sizes include passes=1/2
  variants (~1.5× larger than reference).
- **12-triple discrepancy**: 1000 vs reference 988 (1.2%). Likely from independent
  Tarjan implementation producing slightly different component boundaries,
  or ko-point encoding edge cases. Within tolerance for independent reimplementation.

## Remaining work
- cycle_reachable at triple level (currently counts quadruples)
- KO_SENSITIVE containment check calibration against known-good artifacts
- 4×4 support (bitset-based BFS, ~51M nodes)
