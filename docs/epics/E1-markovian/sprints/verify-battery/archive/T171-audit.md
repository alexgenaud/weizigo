# T171 audit — DSPro/T173 · 2026-07-31

## Method
Compared vb_graph.zig BasicKo against Python ground truth (`ko2x2.py`,
`fix2x2.py`, `scc2x2.py`) line-by-line. Three findings.

## Finding 1: Pass edges omitted from BFS (CRITICAL)
**Location:** `src/vb_graph.zig:590-592`
```zig
// Pass edge: NOT followed (Option A — terminal cut-edge).
// A pass would go to (pos, other_side, NONE) but does not contribute
// to SCC cycles and is omitted from the graph.
```
**Ground truth:** `fix2x2.py:successors()` line `out = [(b, 1 - side, KO_NONE, passes + 1)]`
**Analysis:** Option A (i5-feasibility.md) says pass edges are "terminal cut-edges" —
INCLUDED in the graph but their destinations have no outgoing placement edges
if passes≥2. The subagent interpreted this as "omit entirely." Without pass
edges, states with passes>0 are unreachable, truncating the graph to ~40% of
its true size (V=114 vs V=282 at 2×2). The encodeNode function includes a
passes field (passes∈{0,1,2}), so the data model is correct; only the BFS is
wrong.
**Fix:** Generate pass successors in the BFS loop. Pass from (board, side, ko,
passes) → (board, 1-side, KO_NONE, passes+1). States with passes≥2 have zero
outgoing placement edges (already handled by the ko_forbidden check).

## Finding 2: Ko detection test expectation is wrong (MODERATE)
**Location:** `src/vb_graph.zig:931-932`
```zig
try std.testing.expectEqual(@as(i8, 0), after.pos[1]);
```
**Analysis:** Board {1,-1,0,0} (B,W,.,.) — Black plays at cell 2. White at
cell 1 retains liberty at cell 3, so it is NOT captured. The test expects
pos[1]=0 (captured) but the correct result is pos[1]=-1 (alive). The
apply_move function correctly returns pos[1]=-1; the TEST is wrong.
**Fix:** Rewrite the ko detection test with a true ko-triggering position
(e.g. {1,0,-1,0} B plays at 1 → captures W at 2 after surround check).

## Finding 3: Ko detection algorithm matches Python reference (PASS)
The `apply_move` ko detection logic (lines 344-375) is a faithful
transcription of `ko2x2.py:ko_after()` corrected rule:
1. Count opponent stones before/after ✓
2. If exactly 1 captured: check empty_nbrs==1 and friendly_nbrs==0 ✓
3. Ko point = captured cell ✓

No algorithmic defect found. The function is correct; Finding 2's test was
the false positive.

## Verdict
ONE bug (Finding 1). The BasicKo engine is structurally correct. Fixing the
BFS to include pass edges should recover the full graph: V=282 not 114 at
2×2, V≈2583 not 795 at 3×2, maxSCC=160 not 40 at 2×2.
