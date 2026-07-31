# I5 feasibility memo — iterative Tarjan under 4 GB RSS

```
Author:   DSPro/T134 (V-1) · 2026-07-31
Status:   DELIVERED — for V-2 (spec revision, resolves B2 and C2)
Brief:    untracked/T134-i5-feasibility.md
Inputs:   `docs/epic-01-markovian/sprints/verify-battery/pass0/plan.md` §P0 (V-1) · `docs/epic-01-markovian/sprints/verify-battery/archive/spec.audit-0.md` (B2, C2) — links updated at the 2026-07-31 epic move (originals were relative to the pre-move tree)
          Wave 1 SCC-2x2 (scc2x2.py) · SCC-3x2 (2B-2 corrected, F1-SEEDROOTS)
          EXP-3 kostate census (51,419,046 triples)
```

---

## 1. The problem

I5 (`KO_SENSITIVE ⊆ cycle-reachable`) requires computing the strongly-connected
components of the basic-ko legal-move graph over reachable `(board, side,
ko_point)` triples. At 4×4 this is **51,419,046 nodes** `[GLOBAL.H1-CENSUS:PROVEN]`.
Iterative Tarjan must run within the `tools/runner` 4 GB RSS cap.

This memo is audit finding B2 resolved: a concrete memory plan, fallback if
breached, and fixture strategy for C2. It is the seed for M4 design; it does
not specify the exact Zig data structures (that is V-9's brief), but it names
the approach and the budget line-items that must hold.

---

## 2. Graph definition

**Vertices:** the set of reachable `(board, side, ko_point)` triples from
`src/kostate_census.zig`/EXP-3. At 4×4 under the basic-ko detector:
51,419,046 reachable triples. The representation is Markovian under
loopy-game fixpoint semantics `[ADR-0020:CLAIMED]`.

**Edges:** for each vertex, legal moves (place + pass) under basic ko. A
place move is legal iff the target cell is empty, not the ko-forbidden point,
the move does not suicide, and the resulting position is legal (no group has
zero liberties). A pass increments `passes`; `passes=2` is terminal (no
outgoing edges). **Pass moves change `passes` but not `ko_point`** — the
graph over `(b,side,ko)` *only* (without passes folded) is not closed under
pass transitions. This memo folds passes into the vertex key for closure:

**Effective vertices for I5:** `(board, side, ko_point, passes)` where
`passes ∈ {0, 1}`. `passes=2` states are terminal (sink-only, no cycles).
With the full `passes ∈ {0, 1, 2}` the reachable set is 102,838,092
`[GLOBAL.H1-CENSUS:PROVEN]`, but `passes=2` states have out-degree zero
and contribute only trivial SCCs. The non-trivial structure is in the
`passes ∈ {0, 1}` subgraph of ≈ 99,133,036 vertices (the compact count)
`[4x4.BASICKO-TIE:MEASUREMENT]`.

**Wait — the 51,419,046 figure is (b, side, ko) WITHOUT passes.** The spec
and strategy both cite 51,419,046 as the node count for I5. But a `pass`
move transitions `passes = 0 → 1 → 2`, so a graph over `(b, side, ko)` alone
would lose the pass dimension. The resolution is that the artifact's
`KO_SENSITIVE` flag is a per-`(position, side)` property; the graph must
ensure pass transitions are represented. Two options:

| option | vertices | edges closed under pass? | memory budget |
|---|---|---|---|
| **A: `(b, side, ko)` triples** | 51,419,046 | passes modelled as terminal-only (no passes=0→1→2 path, just direct-to-terminal) | the number in the spec |
| **B: `(b, side, ko, passes∈{0,1,2})`** | 102,838,092 | fully closed | 2× option A |

**Recommendation: option A, with a structural note.** The pass dimension adds
no cycles (passes always increase, never decrease), so every non-trivial SCC
lives entirely within passes=0 and every pass=0→1 edge is a bridge. Running
Tarjan on `(b, side, ko)` triples with pass-edges treated as **terminal
out-edges** (cutting the graph at passes≥1) preserves the cycle-reachable
classification: a state is cycle-reachable iff it can reach a cycle, and
pass-only paths never reach a cycle. The node budget in the spec is
51,419,046.

**Validation gate at 3×2:** run both options and confirm identical cycle-
reachable sets. V=2,583 (true root); trivial to cross-validate.

---

## 3. Calibration data

### 3.1 SCC-2x2 (Wave 1, `scc2x2.py`)

```
true root corrected: V= 255 E= 434 SCCs= 96 non-trivial=1 maxSCC=160 cycle-involved=160
all-seed  corrected: V= 282 E= 508 SCCs=123 non-trivial=1 maxSCC=160 cycle-involved=160
```

- The 2×2 reachable graph has **one non-trivial SCC** (160 vertices out of 255 reachable).
- Self-loops: 0 (no move returns to the exact same state).
- Trivial SCCs: 95 (true root) / 122 (all-seed) — these are cycle-free dags leading into the SCC.
- Under the corrected ko rule: V=255, maxSCC=160 (vs old rule V=263, maxSCC=144).

### 3.2 SCC-3x2 (2B-2, corrected + F1-SEEDROOTS)

| metric | 42-seed (old census root) | true game root (corrected) |
|---|---|---|
| reachable V | 2,622 | **2,583** |
| directed edges E | 5,668 | 5,510 |
| SCCs total | 987 | — |
| non-trivial SCCs | 1 | 1 |
| max SCC size | **1,676** | **1,676** |
| cycle-involved | 1,676 | 1,676 |
| cycle-reachable | 1,704 | **1,678** |

The core SCC is 1,676 vertices regardless of seed convention. The
cycle-reachable count differs slightly (1,704 vs 1,678) because phantom
ko-point roots add 26 reachable states that feed into the SCC.

**These are the calibration targets for V-9.** The battery's iterative
Tarjan on 3×2 must reproduce max SCC = 1,676 (true root) or 1,676
(42-seed). Disagreement means the implementation is wrong — the `index`/
`lowlink` slip precedent (2B-2's first Tarjan reported 7).

### 3.3 2×2 vs the structural theorem

The theorem `KO_SENSITIVE ⊆ cycle-reachable` (Navigator, 054 §2) predicts
that states with `L < H` must be cycle-reachable. The 2×2 all-legal slots
have 72% `KO_SENSITIVE` while the true-root reachable graph has maxSCC=160.
This implies the **all-legal graph** (all legal positions solved as
independent roots) has a much larger cyclic component than the
**reachable-from-empty graph**. I5 must run on **both graphs**:

| graph | what it measures | I5 relevance |
|---|---|---|
| **reachable-from-empty** (true game root) | the real-game cycle structure | directly maps to the artifact's stored `KO_SENSITIVE` flags on reachable slots |
| **all-legal** (every legal position as root) | the full table's cycle structure | maps to ALL `KO_SENSITIVE` flags in the table |

**The strategy brief says "run once per goban" (S1). This memo recommends
two runs per goban** — reachable-from-empty for real-game interpretation,
all-legal for full-table verification. The reachable-from-empty run
calibrates against the committed 3×2 figure (1,676/1,678); the all-legal
run is the one that tests I5 end-to-end against every `KO_SENSITIVE` flag
in the artifact.

If only one run is budgeted, default to all-legal — that is the graph I5
tests against every stored flag. The reachable-from-empty run is smaller
(and at 4×4, likely *much* smaller — the 5:1 ratio of legal vs reachable
at 3×2 suggests the reachable 4×4 graph may be tens of millions rather
than 51M, which would be a finding in itself).

---

## 4. Memory plan — iterative Tarjan on 51,419,046 nodes

### 4.1 Design strategy: rank-support bitset + on-the-fly adjacency

Iterative Tarjan, generate adjacency on the fly (no stored edge list). The
key insight: we do NOT need a forward mapping (linear_id → dense_id) hash
table. A **rank-support bitset** answers `rank(linear_id) = dense_id` in
O(1) with only 6.25% overhead over the raw bitset.

### 4.2 Phase 1 — BFS reachable-state discovery

| structure | size | calculation |
|---|---|---|
| `visited` bitset | **175 MB** | total linear address space = 3¹⁶ × 2 × 17 = 1,463,588,514 bits ÷ 8 |
| BFS queue (u64 × V) | **~412 MB** (peak) | 51,419,046 × 8 bytes; double-buffered or chunked to reduce |
| reachable count + metadata | negligible | counters, seeds |

**BFS queue optimisation:** use a ring buffer over a fixed-capacity chunk
or use the bitset as an iterator (scan-and-expand sweeps, the classical
Bellman fixpoint). The EXP-3 census already does this in 29 sweeps at 4×4
`[GLOBAL.H1-CENSUS:PROVEN]` with a bitset and no queue. **Adopt the
snapshot-sweep approach:** each sweep scans the bitset linearly, expands
all newly-marked nodes, and records children into the *next* bitset copy.
This eliminates the BFS queue entirely at the cost of O(sweeps) passes
over the bitset.

- 2 bitsets (current + next): 2 × 175 MB = **350 MB**
- Sweeps at 4×4: 29 (per EXP-3); each sweep is a linear 175 MB scan
- Wall time: ~4 min (EXP-3 census time)

**Phase 1 peak: 350 MB** (two bitsets).

### 4.3 Phase 2 — rank directory + dense enumeration

After reachability converges, build the rank-support structure:

| structure | size | calculation |
|---|---|---|
| `visited` bitset (retained) | **175 MB** | the reachable marker |
| rank directory | **11 MB** | u32 per 512-bit block: 175 MB ÷ 64 × 4 |
| `dense_to_linear[]` (index → linear_id) | **206 MB** | 51,419,046 × 4 bytes (u32) |

The rank directory is a standard popcount index: `rank[i] = popcount[0..i*512)`.
Lookup `rank(linear_id)` = `rank[linear_id / 512] + popcount(block up to bit)`.
Popcount of a u64 is a single CPU instruction (`@popCount` in Zig).
This gives O(1) `linear_id → dense_id` with **~11 MB** overhead.

**Phase 2 peak: 175 + 11 + 206 = 392 MB.**

### 4.4 Phase 3 — iterative Tarjan

Core Tarjan arrays, per dense vertex:

| structure | bytes/node | total (51,419,046 nodes) |
|---|---|---|
| `index[dense_id]` — discovery order, -1 = unvisited | 4 (i32) | **206 MB** |
| `lowlink[dense_id]` — lowest reachable index | 4 (u32) | **206 MB** |
| `onstack[dense_id]` — boolean | 1 (bool) | **51 MB** |
| Tarjan SCC stack (dense_ids) | 4 (u32) per entry, worst-case V deep | **206 MB** (peak) |
| Iterative frame stack `(dense_id, child_idx)` | 8 per frame, depth-bounded | **~16 MB** (see §4.5) |
| Adjacency buffer (per-node child list) | variable, reused | **~1 MB** |

**Subtotal: 206 + 206 + 51 + 206 + 16 + 1 = 686 MB.**

Plus retained structures from Phase 2:

| structure | size |
|---|---|
| `visited` bitset (for rank lookups) | 175 MB |
| rank directory | 11 MB |
| `dense_to_linear` | 206 MB |

**Phase 3 peak: 686 + 392 = 1,078 MB ≈ 1.05 GB.**

### 4.5 Frame stack size bound

The iterative Tarjan frame stack holds `(dense_id, next_child_idx)` for
each active DFS path. The maximum depth is bounded by the longest simple
path in the graph. At 3×2 the max cycle length is 14, and paths leading
into the SCC are short. At 4×4 the worst case is unknown, but:

- Each frame is 8 bytes (u32 dense_id + u32 child_idx)
- Even allowing a **2 million frame** stack (pathological): 16 MB
- A tighter bound: the longest possible simple path cannot exceed the
  number of distinct goban states (24,318,165 legal positions), but in
  practice DFS depth on the basic-ko graph is bounded by stone-placement
  (max 16 stones) and pass transitions (max 2 passes), giving a
  structural bound of ~18 plies. However, captures can remove stones,
  extending path length. The 3×2 graph has path lengths ≥ 14. Budget
  **16 MB** for the frame stack (2 million frames); this is generous.

### 4.6 Peak RSS summary

| phase | peak allocation | dominant structures |
|---|---|---|
| 1 — BFS discovery | **350 MB** | two 175 MB bitsets |
| 2 — rank + dense map | **392 MB** | bitset + rank + dense_to_linear |
| 3 — Tarjan | **1,078 MB** | all of Phase 2 + Tarjan arrays + stacks |
| **Phase 3 (de-allocation after Phase 2)** | **~1.2 GB** | with Zig allocator overhead |

After Phase 2, the second bitset is freed; the rank directory and
`dense_to_linear` stay for Phase 3 adjacency generation. The Tarjan arrays
dominate Phase 3.

**Estimated peak RSS: 1.2–1.5 GB**, well under the 4 GB runner cap. This
leaves >2.5 GB headroom for Zig runtime, adjacency generation scratch
space, and the rank-support popcount table.

### 4.7 Edge generation — on the fly

During Tarjan, for each vertex `v` (dense_id), we:
1. Look up `linear_id = dense_to_linear[v]`
2. Decode `(board_idx, side, ko_point)` from the linear_id
3. Decompress board to a `[16]i8` array from colex/odometer index
4. Enumerate legal moves (place + pass) via the basic-ko rules engine
5. For each child: compute its `(board, side, ko)` → linear_id → `rank(linear_id)` = child_dense_id
6. If child_dense_id is within [0, V), yield it as an adjacency

Edge generation is the compute bottleneck, NOT the memory bottleneck. The
3×2 calibration (V=2,583) will complete in milliseconds; 4×4 (V=51M) is
the calibration target for wall time.

### 4.8 What could push RSS over budget

| risk | mitigation |
|---|---|
| Zig's default allocator fragmentation | Use `std.heap.page_allocator` for the large arrays; fixed-size arrays avoid fragmentation |
| 3× pass dimension instead of 2× | Phase 1 uses 2 bitsets; Phase 3 doesn't need a bitset (only rank) — free the second bitset after Phase 1 |
| `onstack` as full byte array (51 MB) | Pack to 1 bit per node (6.4 MB) — saves 44.6 MB |
| `index` as i32 (signed) | Use u32, with sentinel `0xFFFFFFFF` for unvisited — same size, cleaner |
| Frame stack blowup | Cap frame depth at a safe maximum; if exceeded, fall back to recursive (unlikely for basic-ko graph) |

---

## 5. Fallback — if budget is breached

### 5.1 Tiered fallback

| tier | action | trigger | what it loses |
|---|---|---|---|
| **F1 — pack onstack** | Pack `onstack` to 1 bit/node (6.4 MB vs 51 MB) | Phase 3 exceeds 3.5 GB | 44.6 MB saved, negligible perf cost |
| **F2 — drop dense_to_linear, regenerate** | During Tarjan, regenerate the board from the dense_id by scanning the bitset for the nth set bit. This is O(log V) with rank — or we can use the `dense_to_linear` but not both it AND the rank directory. | Phase 3 exceeds 3.8 GB | 206 MB saved; O(V) extra compute for edge generation |
| **F3 — sample-only** | Run Tarjan on a stratified random sample of the graph. Report SCC structure with the sample denominator. | Phase 3 exceeds 3.95 GB | I5 is no longer exhaustive; becomes a sampling claim |
| **F4 — size threshold** | Skip I5 at 4×4; run only on ≤3×3 where the graph fits trivially. I5 at 4×4 becomes a separate measurement. | F3 is invoked | 4×4 ko-sensitive containment not verified by the battery |

F1 and F2 are mechanical optimisations. F3 and F4 change the claim status
from exhaustive to sampled or out-of-scope. **The strategy states F3/F4 as
the last resort (§4: "If V-1 finds no ≤ 4 GB Tarjan plan and no acceptable
fallback: I5 leaves the battery").** This memo provides a ≤4 GB plan;
fallback exists only to guard against unexpected real-world RSS.

### 5.2 Verification that fallback has been crossed

The battery reports peak RSS per invocation (A6). If the runner kills the
process, the RSS at death is logged in the runner's stderr. **The battery
must check its own allocation sizes against the 4 GB cap before Phase 3**
and refuse to start Tarjan if the predicted allocation exceeds the
available headroom (reported by the OS). This prevents a SIGKILL and emits
a clean "I5: SKIPPED — memory budget exceeded, sample-only fallback"
message to stdout.

---

## 6. Fixture strategy for C2

### 6.1 The problem

R2 requires every invariant to have a known-bad fixture. I5
(`KO_SENSITIVE ⊆ cycle-reachable`) tests a structural containment. The
audit (C2) notes: "No obviously-constructable fixture exists." The fix:
**corrupt a known-good artifact at one non-cycle-reachable slot** by
setting its `KO_SENSITIVE` flag to ON, and assert I5 catches it.

### 6.2 Fixture construction at 3×2

The 3×2 true-root reachable graph has 2,583 vertices, of which 1,678 are
cycle-reachable and 905 are non-cycle-reachable non-terminals. Steps:

1. **Compute the cycle-reachable set** on the true-root graph (Tarjan →
   BFS reverse from cycle-involved set).
2. **Pick a non-cycle-reachable non-terminal state** — any state in the
   905 complement with out-degree > 0.
3. **Copy a known-good 3×2 artifact** (e.g., the new-rule oracle, or a
   synthetic minimal fixture).
4. **Flip `KO_SENSITIVE` ON** at exactly that one `(position, side)` slot.
5. Verify the corrupted artifact passes all OTHER invariants (I1–I4, I6–I9)
   — the only failure should be I5.
6. **The battery's I5 must report:** "FAIL: KO_SENSITIVE flag set at N
   non-cycle-reachable slots" with denominator (N=1).

### 6.3 Fixture construction at 2×2

Same approach, simpler graph. The true-root corrected graph has V=255,
maxSCC=160. The remaining 95 are trivial-SCC dags. Pick one with out-degree
> 0, flip its KO_SENSITIVE flag in a 2×2 artifact.

### 6.4 What about 4×4?

The fixture is NOT needed at 4×4 — the 3×2 fixture proves the invariant
works. Running I5 at 4×4 on a clean artifact is the production use.
Constructing a corrupted 4×4 artifact for fixture purposes would require
knowing the cycle-reachable set at 4×4, which is the very computation I5
performs. This is circular.

**The calibration at 2×2 and 3×2 is sufficient.** The structural theorem
is the same, the graph is the same formalism, and the fixed-point SCC
classification is the same algorithm. The size difference (255 vs 2,583
vs 51,419,046) tests only scaling, not correctness. The `2B-2` precedent
— max SCC of 7 instead of 1,676 — shows scaling bugs manifest at the
smallest non-trivial size.

### 6.5 Fixture validation checklist

| check | how |
|---|---|
| Corrupted artifact passes I1–I4, I6–I9 | Run the battery without I5 |
| Corrupted artifact fails I5 | Run I5 alone; exit code non-zero |
| I5 names the specific invariant | Output says "I5: KO_SENSITIVE ⊆ cycle-reachable FAILED" |
| I5 reports the violating slot count | Output says "1 violation / 508 non-settled slots" (or similar denominator) |
| Uncorrupted artifact passes I5 | Control — the original artifact returns exit 0 for I5 |

---

## 7. I5 vs the battery's two-exit-class scheme

The audit (M3) and strategy (M3-exit) require two failure classes:
*artifact-bad* (non-zero exit, the battery worked) and *battery-bad*
(harness error).

### 7.1 I5 at 3×2 — the larger-than-sprint scenario

If I5 at 3×2 finds `KO_SENSITIVE` flags outside the cycle-reachable set,
both sides are committed (the fixpoint kernel's pin census and the SCC
census). The spec §7 says: "**I5 contradicts the stored `KO_SENSITIVE`
flags at 3×2… that is a finding larger than this sprint.**"

In this case I5 MUST exit non-zero (R6 — failing invariant), but the exit
code class is **artifact-bad** (I5 worked; the artifact is suspect). The
battery's harness must convey: "I5 found a containment violation — this
is not a battery defect; both the artifact's KO_SENSITIVE flags and the
SCC census are committed and they disagree. This is a finding larger than
the verify-battery sprint."

Distinguish from *battery-bad*: "I5 could not complete — Tarjan exhausted
the frame stack" or "I5: SKIPPED — memory budget exceeded."

### 7.2 Proposed exit discipline for I5

| outcome | exit code | class |
|---|---|---|
| `KO_SENSITIVE ⊆ cycle-reachable` holds everywhere | 0 | — |
| Containment violated at ≥1 slot | 1 | artifact-bad (or larger-than-sprint) |
| Memory budget exceeded, skipped | 2 | battery-bad (resource) |
| Tarjan frame stack exceeded depth bound | 3 | battery-bad (bug) |
| Graph construction failed (OOM, etc.) | 4 | battery-bad (resource) |

---

## 8. Calibration targets for V-9

These must be reproduced by the battery's Tarjan before I5 at 4×4 is
trusted. All are committed evidence.

| target | graph | V | E | max SCC | source |
|---|---|---|---|---|---|
| SCC-2x2 true root | (b,side,ko,passes) | 255 | 434 | **160** | `scc2x2.py`, §3.1 |
| SCC-2x2 all-seed | (b,side,ko,passes) | 282 | 508 | **160** | `scc2x2.py`, §3.1 |
| SCC-3x2 true root | (b,side,ko,passes) | 2,583 | 5,510 | **1,676** | F1-SEEDROOTS, §3.2 |
| SCC-3x2 42-seed | (b,side,ko,passes) | 2,622 | 5,668 | **1,676** | 2B-2 corrected, §3.2 |
| cycle-reachable 3×2 true root | (b,side,ko,passes) | — | — | — | **1,678** (count) | F1-SEEDROOTS, §3.2 |

**The most sensitive calibration is max SCC at 3×2 = 1,676.** 2B-2's first
Tarjan reported 7. Any implementation that does not reproduce 1,676 has the
`index`/`lowlink` bug. This is the single most important gate before 4×4.

---

## 9. Summary — the plan in one table

| item | value |
|---|---|
| Nodes at 4×4 | 51,419,046 `(board, side, ko)` triples |
| Graph closure | pass transitions cut at passes≥1 (structural note §2) |
| Phase 1 — BFS | snapshot-sweep with 2 bitsets: 350 MB peak |
| Phase 2 — rank + dense map | bitset + rank directory + dense_to_linear: 392 MB peak |
| Phase 3 — Tarjan | index + lowlink + onstack + stacks: 686 MB |
| **Peak RSS (Phase 3)** | **~1.2 GB** (all structures retained) |
| Headroom under 4 GB | **~2.8 GB** (factor of 3.3×) |
| Fallback F1 (pack onstack) | saves 44.6 MB |
| Fallback F2 (drop dense_to_linear) | saves 206 MB |
| Fallback F3 (sample-only) | Tarjan on stratified sample; denominator reported |
| Fallback F4 (size threshold) | I5 at ≤3×3 only |
| Fixture | corrupted 3×2 artifact: one KO_SENSITIVE flag flipped outside cycle-reachable set (§6) |
| Calibration gate | max SCC at 3×2 true root = 1,676 (must reproduce exactly) |
| Exit classes | 0=pass, 1=artifact-bad/larger-than-sprint, 2/3/4=battery-bad (§7.2) |

---

## 10. What this means for V-2 (spec revision)

**B2 (blocker) → RESOLVED.** The memory plan fits under 4 GB with ~2.8 GB
headroom. Three fallback tiers handle unexpected blowup. The plan is
concrete enough for V-9 implementation (data structure names, sizes,
phase transitions) without being a full design doc — that is V-9's job.

**C2 (critical) → RESOLVED.** The fixture strategy is: corrupt a 3×2
artifact at one non-cycle-reachable slot, set `KO_SENSITIVE` ON, and
verify I5 catches it with the invariant named and denominator reported.

**Open for V-2 and the strategy:**
1. Does the pass-dimension structural note hold (§2), or should the graph
   include `passes ∈ {0, 1}` explicitly (doubling the node count to ~99M,
   still feasible)?
2. Should I5 run on the reachable-from-empty graph or the all-legal graph?
   This memo recommends both (§3.3) but acknowledges the strategy says
   "once per goban."
3. The exit-code class for "larger-than-sprint finding" (§7.1) straddles
   artifact-bad and battery-bad — the artifact disagrees with itself, and
   the battery correctly reports it. The V-2 reviser should decide whether
   this is exit code 1 with a distinct message or a separate exit code.

— DSPro/T134
