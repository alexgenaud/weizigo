# T171 findings capture — DSPro/T173 · 2026-07-31

## What was produced
`src/vb_graph.zig` (1049 lines, DSPro/T171-w1) — iterative Tarjan SCC, colex bijection,
basic-ko rules engine, WZO1 artifact reader, I5 containment check.

## What works
- Colex round-trip (tests pass)
- Legal position detection (tests pass)
- Apply-move capture (tests pass)
- Encode/decode node round-trip (tests pass)

## What fails (calibration gate)

### 1. apply_move ko detection test
expected pos[1]=0, got -1. Ko detection logic bug in BasicKo.apply_move.

### 2. 2×2 all-legal graph calibration
- BFS: V=114 nodes, E=184 edges (expected V=282, E=508 from scc2x2.py)
- maxSCC=40 (expected 160)
- Root cause: only 57 legal positions found (expected more). Legal-move generator
  misses positions reachable via pass or ko variants.

### 3. 3×2 reachable graph calibration
- BFS: V=795, E=1658, maxSCC=654 (expected maxSCC=1676)
- Node count far too low — basic-ko engine not finding full state space.

## Assessment
The basic-ko rules engine (legal-move generation, ko detection) is incomplete.
The Tarjan implementation and graph infrastructure are structurally sound but
operate on an incomplete graph. Fixing requires reimplementing the basic-ko
engine against the spec's rules definition (design-M1 §4.2) with calibration
against the committed scc2x2.py numbers.

## Next step
Either: (a) fix BasicKo in-place to match calibration targets, or (b) re-dispatch
T171 to a fresh subagent with explicit Zig 0.16 guidance and calibration prior.
