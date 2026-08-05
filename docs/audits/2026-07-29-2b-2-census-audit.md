> Task: 2B-2-AUDIT · Role: Auditor · Model: kimi-k2.7-code:cloud · Date: 2026-07-29

# 2B-2-AUDIT — 3×2 cycle-census review

## Scope

Read-only audit of the 2B-2 deliverable `docs/evidence/QA-023/census-3x2-2026-07-29.md`
and its implementation in `src/qa023_probe.zig`.  This audit does **not** edit `src/`,
`docs/epistemic/CLAIMS.md`, or any 2B-N deliverable.

## Methods

1. **Re-ran the official command** through `tools/runner` at several caps and
captured stdout.
2. **Re-implemented the 3×2 legal-move graph from first principles** in
`docs/evidence/AUDIT-2B-2/independent_graph_check.py` (basic-ko formalization (i),
no engine imports) and ran Tarjan's SCC plus a reverse-BFS on it.
3. **Re-implemented the length-bounded directed simple-cycle enumerator**
in `docs/evidence/AUDIT-2B-2/bounded_cycle_count.py` and compared counts at
caps 12 and 14.

All evidence is committed under `docs/evidence/AUDIT-2B-2/`.

## Reproduction table

| cap | cycles (Zig) | cycles (Python) | time | not capped? | evidence |
|---|---:|---:|---|---|---|
| 12 | 37,376 | 37,376 | 0.3 s | yes | `census-cap12-rerun.stdout`, `bounded_cycle_count.py` output |
| 14 | 143,760 | 143,760 | 0.6 s | yes | `census-cap14-rerun.stdout`, `independent_check.stdout` |
| 18 | 3,288,800 | — | 7.8 s | yes (1B cap) | `census-cap18-rerun.stdout` |
| 20 | 16,192,056 | — | 40.8 s | yes (1B cap) | `census-cap20-rerun.stdout` |
| 22 | 70,777,276 | — | 228.7 s | yes (1B cap) | `census-cap22-rerun.stdout` |

The independent Python Tarjan check matched every headline structural number:

```
Reachable V = 2682
Directed edges E = 5744
Distinct legal boards = 489
Terminals (passes==2) = 866
By side: B=1341 W=1341
By ko: none=2562 real=120
SCCs total = 987
Non-trivial SCCs = 1
Largest SCC size = 1696
Cycle-involved vertices = 1696
Cycle-reachable vertices = 1724
Sample cycles length 6/8/14: VALID
```

(See `docs/evidence/AUDIT-2B-2/independent_check.stdout`.)

## Per-item verdicts

### 1. SCC / lowlink caveat — VERIFIED

The corrected iterative Tarjan in `src/qa023_probe.zig` uses `lowlink[v]` for
SCC-root tests and propagates the child's `lowlink` to the parent:

- Back-edge update: `src/qa023_probe.zig:2197` (`if (index_arr[w] < lowlink[v]) lowlink[v] = ...`).
- SCC-root pop: `src/qa023_probe.zig:2203` (`if (lowlink[v] == index_arr[v])`).
- Parent propagation: `src/qa023_probe.zig:2220` (`if (lowlink[v] < lowlink[parent]) lowlink[parent] = lowlink[v]`).

This is the standard textbook form.  The prior `index_arr[v]` parent-update bug
would indeed over-merge SCCs; the current code does not.

**Independent confirmation:** `independent_graph_check.py` builds the same graph
and runs a recursive Tarjan from scratch.  It reports exactly the same SCC
structure: total 987 SCCs, one non-trivial SCC of size 1,696, so the 1,696-vertex
SCC is correct.

### 2. Cycle count — VERIFIED (with a corrected caveat)

The headline 143,760 distinct simple directed cycles at cap 14 is reproducible
and independently confirmed:

- `census-cap14-rerun.stdout`: 143,760, max length 14, not capped.
- `bounded_cycle_count.py` (independent rank-based bounded DFS): 143,760 with
  identical length histogram (16 @6, 1,296 @8, 11,004 @10, 25,060 @12,
  106,384 @14).

The cap-artifact is real and correctly described in broad terms — longer caps
yield many more cycles — but the deliverable's specific parentheticals are
**inaccurate**:

- The deliverable says cap 18 is "3.3M (cap hit)".  With the documented 1B cap
  it is **3,288,800 and not capped**.
- The deliverable says cap 20 is "≥ 100 million (cycle cap hit)".  With the 1B
  cap it is **16,192,056 and not capped**.
- A cap-22 run with the 1B cap reaches **70,777,276**, still not capped.

So the honest lower bound on the unbounded simple-cycle count is at least
**70.8 million**, not "at least 3.3 million".  This does not weaken the headline;
it strengthens it.

The object — **distinct simple directed cycles in the reachable legal-move graph**
— is the right one for `3x2.QA023.B-VACUITY`: it is exactly the structure that
guarantees a state can be revisited via different move orders, i.e., that the
probe (2B-4) has a non-empty pool of multi-arrival states.  Downstream 2B-4
uses the 1,724 cycle-reachable states, not the raw cycle count, so the exact
enumeration number is a sanity check rather than a load-bearing input.

### 3. 1,724 cycle-reachable vertices — VERIFIED

The reverse-BFS from the 1,696 cycle-involved vertices finds 1,724 vertices
(`src/qa023_probe.zig:2361-2388`).  The independent Python reverse-BFS on the
same graph also reports **1,724**.  The 28-vertex tail (1,724 − 1,696) is the
set of positions that drain into the SCC but are not themselves on a cycle.
This is the population 2B-4 samples from.

### 4. Escalate decision — VERIFIED non-vacuous

`src/qa023_probe.zig:2449-2455` prints `PASS` because `cycles_found > 0`.  Both
the re-run and the independent Python check confirm cycles exist.  There is no
vacuity trap: 3×2 is a non-trivial test surface for QA-023, and 2B-4's
falsification can proceed without escalating to 3×3 on these grounds.

## Corrected cap-growth summary

| cap | simple directed cycles | capped? |
|---|---:|:---|
| 14 | 143,760 | no (1B cap) |
| 18 | 3,288,800 | no (1B cap) |
| 20 | 16,192,056 | no (1B cap) |
| 22 | 70,777,276 | no (1B cap) |

The unbounded simple-cycle count is therefore ≥ 70,777,276.

## One-line verdict

**VERIFIED:** the 3×2 cycle census is solid enough for 2B-4's falsification to
rest on it.  The SCC, the 1,696 cycle-involved / 1,724 cycle-reachable counts,
the 143,760 cap-14 cycle count, and the non-vacuous PASS verdict all reproduce
independently.  The only issue is a sloppy caveat: the cap-18/20/22 counts are
larger than the deliverable claimed and are not capped at 1B, which strengthens
rather than threatens the conclusion.

## Files produced

- `docs/audits/2026-07-29-2b-2-census-audit.md` (this file)
- `docs/evidence/AUDIT-2B-2/independent_graph_check.py`
- `docs/evidence/AUDIT-2B-2/bounded_cycle_count.py`
- `docs/evidence/AUDIT-2B-2/independent_check.stdout`
- `docs/evidence/AUDIT-2B-2/census-cap12-rerun.stdout`
- `docs/evidence/AUDIT-2B-2/census-cap14-rerun.stdout`
- `docs/evidence/AUDIT-2B-2/census-cap18-rerun.stdout`
- `docs/evidence/AUDIT-2B-2/census-cap20-rerun.stdout`
- `docs/evidence/AUDIT-2B-2/census-cap22-rerun.stdout`
