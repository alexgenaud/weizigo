# Scaling census — 2026-08-20 (T507)

**Author:** deepseek-v4-pro/T507 · **Date:** 2026-08-20 · **Landmark:** `L7 (the 5×5 decision, costed)` — this is the prerequisite measurement for the L7 costed go/no-go.

**Residue:** T358's worker (glm-5.2/T358.2) delivered four census instruments
(`src/t358_census_{2x2,3x2,3x3,4x3}.zig`) but exited before producing the declared
deliverable. T507 commits those instruments (da60c87), runs them, verifies their root
seeding, and writes the census. This doc supersedes the historical
`docs/research/scaling-census.md` (RETRO_CENSUS, 2026-07-16) for the reachable-state
column, which the old doc never measured; the old doc's fixpoint-sweep / build-time
columns are retained here, labelled as historical.

---

## 1. Method, and the root-seeding verification

The census is a reachability BFS over the full state tuple `(board, side, ko, passes)` —
the same state key the WZO2 artifacts store (with `passes=2` omitted). Legal moves are
`place` (with basic-ko ban, suicide rejection, capture) and `pass`. The graph is tiny
enough at every measured size to enumerate exhaustively.

**Root convention (the "census method").** The fresh-start game begins at
`(empty, Black-to-move, ko=none, passes=0)`. The census seeds the empty board for *both*
sides to move — Black and White — because the stored table holds both sides and the two
universes are colour-disjoint (a Black-first game can never reach an empty-White-to-move
state by legal play, and vice versa). This is the same both-roots convention the
capture-budget battery calls "matching the t386 census exactly" (`docs/research/capture-budget-2026-08-06.md` §2).

**Verification performed (T507):**

1. **2×2 and 4×3 instruments seed exactly the two real roots** — `(empty, B, none, 0)` and
   `(empty, W, none, 0)` — nothing else. Read from `src/t358_census_2x2.zig` (two-entry
   `roots` array) and `src/t358_census_4x3.zig` (the `for ([_]u8{0,1})` seed loop).
2. **3×2 and 3×3 instruments seed `passes∈{0,1}`** (four roots, via `exp6_solve.run_census_3x2/3x3`).
   This is a *redundant*, not a *wrong*, over-seed: the two `passes=1` empty-board roots are
   already reachable in one pass move from the `passes=0` roots (`(empty,W,none,1) = pass((empty,B,none,0))`
   and conversely). Confirmed empirically below — identical counts either way.
3. **The old `qa023_brute_2x2` main over-seeds `ko=cell-on-empty`** (30 roots: both sides ×
   passes 0/1/2 × ko ∈ {none,0,1,2,3}). That *is* a real over-seed — a ko point on an empty
   board is unreachable by any legal play — and is exactly why the clean 2×2 instrument was
   written. The four T358 instruments do not do this.

**Independent re-implementation cross-check** (Python, stdlib only,
`docs/evidence/GLOBAL.REACH-P4-CENSUS/crosscheck.py`): a from-scratch BFS over the same
state tuple reproduces the 2×2 and 3×2 Zig numbers exactly, and shows the two seeding
conventions produce identical reachable sets:

| size | seeds = `{0}` (2 roots) | seeds = `{0,1}` (4 roots) | Zig instrument |
|---|---|---|---|
| 2×2 | total 258 / p01 172 / p2 86 | 258 / 172 / 86 (identical) | 258 / 172 / 86 |
| 3×2 | total 2,586 / p01 1,732 / p2 854 | 2,586 / 1,732 / 854 (identical) | 2,586 / 1,732 / 854 |

**Conclusion:** all four instruments seed only the real roots (modulo the provably redundant
`passes=1` additions in the 3×2/3×3 wrappers); the numbers are trustworthy.

---

## 2. The measured table

Every number is measured or arithmetic; provenance per cell. Build mode `ReleaseFast`,
single thread, machine = this host (Apple silicon, 48 GB). Census runs executed under
`tools/runner` (the project's RSS-guarded wrapper).

| quantity | 2×2 | 3×2 | 3×3 | 4×3 | 4×4 |
|---|---|---|---|---|---|
| cells (n) | 4 | 6 | 9 | 12 | 16 |
| raw address space 3ⁿ (arithmetic) | 81 | 729 | 19,683 | 531,441 | 43,046,721 |
| legal positions (census) | 57 | 489 | 12,675 | 321,689 | 24,318,165 |
| reachable non-terminal `(pos,side,ko,p∈{0,1})` | 172 | 1,732 | 49,428 | 1,293,848 | 99,133,036 |
| reachable terminal `(p=2)` | 86 | 854 | 24,330 | 635,190 | 48,505,262 |
| reachable total (all passes) | 258 | 2,586 | 73,758 | 1,929,038 | 147,638,298 |
| BFS sweeps to converge (census) | — (DFS) | 12 | 18 | 15 | — |
| L/H fixpoint sweeps (historical RETRO_CENSUS) | 2 | 6 | 12 | 17 | 19 |
| artifact bytes on disk (`ls -l`) | 518 (wzo) | 4,406 (wzo) | 261,215 (wzo2) | 3,188,678 (wzo) | 518,123,097 (wzo2) |
| stored entries / groups (header) | 114 side-slots (wzo) | 978 side-slots (wzo) | 49,428 / 12,675 (wzo2) | 643,378 side-slots (wzo) | 99,133,036 / 24,318,165 (wzo2) |
| bytes per reachable state (derived) | — | — | 5.28 | — | 5.23 |

### Provenance of each cell

- **raw 3ⁿ** — arithmetic.
- **legal positions** — census run (2×2/3×2/3×3/4×3: T507 BFS; 4×4: WZO2 header `n_groups`).
  All five agree with the historical RETRO_CENSUS legal column (57/489/12,675/321,689/24,318,165).
- **reachable non-terminal / terminal / total** — 2×2/3×2/3×3/4×3: T507 census runs
  (`src/t358_census_*.zig`). 4×4 non-terminal = WZO2 header `n_entries`; 4×4 terminal =
  48,505,262 (accept.md §2.2, C-A1 "passes=2 children"); 4×4 total = 147,638,298
  (capture-budget §2 "base reachable", which states it matches the t386 census exactly).
- **BFS sweeps** — census runs (3×2/3×3/4×3). The 2×2 instrument uses an explicit DFS stack
  (no sweep count); 4×4 was not re-run (see §3).
- **L/H fixpoint sweeps** — `docs/research/scaling-census.md` (RETRO_CENSUS, 2026-07-16),
  *historical*: the history-free L/H iteration count, a different quantity from the BFS
  reachability sweeps. Do not conflate the two columns.
- **artifact bytes** — `ls -l` (sizes at HEAD). WZO1 files (`oracle-{2x2,3x2,3x3,4x3}.wzo`)
  store one score per `(colex, side)` = "side-slots" = legal × 2; WZO2 files
  (`oracle-3x3-v2.wzo2`, `oracle-4x4-v2.wzo2`) store one 4-byte entry per reachable
  `(colex, side, ko, passes∈{0,1})` state.
- **bytes per reachable state** — WZO2 only: `file_size / n_entries`. For 4×4 the file is
  *exactly* `128 + 5·n_groups + 4·n_entries` = 128 + 121,590,825 + 396,532,144 = 518,123,097,
  so the 5.23 B/entry is 4 B entry data + 1.23 B group-index overhead (23.5 %).

### Cross-check validation (independent of the instruments)

| check | result |
|---|---|
| 3×3 non-terminal (49,428) vs `data/oracle-3x3-v2.wzo2` header `n_entries` | **exact match** |
| 3×3 legal (12,675) vs same header `n_groups` | **exact match** |
| 4×3 total (1,929,038) vs capture-budget §2 "base reachable" (t386 census) | **exact match** |
| 4×4 non-terminal (99,133,036) vs `data/oracle-4x4-v2.wzo2` header `n_entries` | **exact match** |
| legal columns vs historical RETRO_CENSUS legal column | **exact match, all five sizes** |
| 2×2/3×2 vs independent Python re-implementation | **exact match** |

The one pre-existing discrepancy on record — I5's 4×3 vertex count of 1,929,035
(accept.md §3.1) vs the census/t386 count of 1,929,038 — is a 3-state difference between the
Tarjan-SCC instrument and the reachability census, *not* a defect in this census: the
instrument's headline is its exact agreement with t386's 1,929,038 and the WZO2 headers.

---

## 3. What was NOT re-measured, and why

- **4×4 was not rebuilt.** The WZO2 header answers the stored-entry and legal questions, and
  `accept.md` + `capture-budget` answer the terminal/total questions. A fresh 4×4 census
  would need a ~4.4-billion-slot dense bitset (549 MB × 2) and ~19+ fixpoint sweeps — the
  very cost this census is meant to *quantify*, not re-pay.
- **Build wall time and peak RSS per size.** Not re-measured at every size; the historical
  RETRO_CENSUS build column (0 ms / 2 ms / 138 ms / 4.74 s / 494.4 s) and the accept.md §3.3
  4×4 memory ledger (below) are quoted with their provenance. The T507 census runs themselves
  peak at ~275 MB RSS wall-clock ~4–9 s, dominated by the `zig` compiler, not the census —
  those are *not* build measurements and are not presented as such.

---

## 4. The growth fit, and the 5×4 / 5×5 projection

The load-bearing quantity is **reachable non-terminal states** (`n_entries`), because that is
what the WZO2 table stores (4 B each) and what the L/H fixpoint iterates over. Fitting its
growth:

- **Per-cell growth rate** (last two sizes, 4×3→4×4): `(99,133,036 / 1,293,848)^(1/4) = 2.959×`/cell.
  Earlier rungs: 3.17×, 3.06×, 2.97× — decaying toward ~2.96×, just under the raw 3× rate.
- **Log-linear fit** over all five sizes: `log10(n_entries) = 0.3505 + 0.4792·cells`
  (R² ≈ 0.9997). The slope 0.4792 ≈ `log10(3) = 0.4771` — i.e. `n_entries` tracks `3ⁿ`
  almost exactly, with a slowly shrinking multiplicative constant
  (`n_entries / 3ⁿ` = 2.12, 2.38, 2.51, 2.43, 2.30 — peaking at 3×3, then falling as the
  legal fraction falls).

**Two models, both stated so a later measurement can falsify them:**

| model | 5×4 (20 cells) n_entries | 5×4 table bytes | 5×5 (25 cells) n_entries | 5×5 table bytes |
|---|---|---|---|---|
| A — per-cell 2.959× (last rung) | 7.60×10⁹ | 4×7.6B + 5×1.8B ≈ **41 GB** | 1.72×10¹² | 4×1.72T + 5×0.40T ≈ **8.9 TB** |
| B — log-linear regression | 8.61×10⁹ | ≈ **45 GB** | 2.14×10¹² | ≈ **11 TB** |

Table bytes use the *measured* WZO2 file formula `4·n_entries + 5·n_groups + 128` with
`n_groups` = projected legal positions. Legal fraction falls ~linearly at ≈ 1.1 %/cell
(70.4 % → 56.5 % across 4→16 cells), giving 5×4 legal ≈ 1.80×10⁹ (51.7 %) and 5×5 legal
≈ 3.9×10¹¹ (46 %), the latter close to the literature's ~414-billion 5×5 legal count.

**Which resource binds first at 5×4 — RAM, in two forms:**

1. **The dense census bitset** (the method these instruments use): the full state space is
   `3ⁿ × 2 sides × (n+1) ko × 3 passes`. At 4×4 that is 4.39×10⁹ slots = 549 MB per bitset;
   at 5×4 it is **4.39×10¹¹ slots = 54.9 GB per bitset**, ×2 (reach + snapshot) = **≈110 GB**
   — over the host's 48 GB before the table even exists. This alone forecloses the naive
   dense census at 5×4.
2. **The value table + fixpoint working set** (if the census is made sparse/reachable-only,
   as the 4×4 build's C-A2 already does): `n_entries × (4 B table + 2×1 B L/H)` ≈
   7.6–8.6B × 6 B ≈ **46–52 GB**, again at/over the RAM ceiling.

Disk is second: the 5×4 WZO2 is ≈ 41–45 GB on disk, but you must *hold it (or its L/H working
form)* in RAM to build it. Wall time is third: the historical history-free 4×4 build was
8.24 min over 43 M raw slots; a 5×4 run is 81× more raw slots ≈ **~11 h** single-threaded
before the (much more expensive) ko-sensitive finisher is counted. **RAM is the first wall.**

---

## 5. colex.zig's projection as the competing model

`src/colex.zig` projects 5×5 as: raw `3²⁵ = 847 GB` at 1 B/slot, folded to **~26 GB** by
"legal-only ~2×" and "canonical-only ~16×" density folds.

**Where my fit agrees:** the raw space. `3²⁵ = 847,288,609,443` — identical, arithmetic, no
dispute.

**Where it disagrees, and why it matters:**

- colex's 26 GB is a *score-only* array — **1 byte per goban**, no side/ko/passes dimensions.
  The WZO2 artifacts actually store **4 bytes per reachable `(pos, side, ko, passes)` entry**,
  and `n_entries ≈ 2.4 × 3ⁿ` (measured §4), not `3ⁿ / 32`.
- The two folds are **not implemented** in the committed artifacts. The WZO2 `n_groups`
  equals the *raw* legal count (12,675 for 3×3; 24,318,165 for 4×4) — there is **no
  canonical/symmetry fold** in the stored index, and the legal fold is already "bought" in
  `n_groups`, not a further 2×.
- Consequently the current format costs ≈ `5.2 B × 2.4 × 3ⁿ = 12.5 × 3ⁿ` bytes ≈ **12.5 B per
  raw slot**, versus colex's assumed `1/32 B` per raw slot — a **~400×** divergence. At 5×5
  the measured-scaling model (§4) says **~9–11 TB** in the present WZO2 layout, not 26 GB.

The 26 GB figure is realizable *only* after the density upgrades colex names ("behind this
same two-function interface … only gate 5×5") are actually built — legal-only + canonical
groups, score-only slots, and a fold of the `(side, ko, passes)` dimensions. That work does
not exist yet. **For L7, the decision-relevant number is the ~9–11 TB / ~41–45 GB of the
current representation, with 26 GB as the *post-refactor* target, not the current state.**

---

## 6. Re-deriving T344's ~1.2 GB memory model error

The plan budgeted the 4×4 I5 (Tarjan SCC) run at **~1.2 GB**. Measured (accept.md §3.3):
**4,102 MB** pre-fix, **2,768 MB** post-fix (packed onstack, F1) — a **2.3×–3.4×** error.
The per-component ledger shows the plan counted only:

| what the plan counted | bytes |
|---|---|
| artifact file resident | 494 MB |
| Tarjan index + lowlink | 378 + 378 MB |
| onstack (packed) | 12 MB |
| **plan total** | **≈ 1.26 GB** |

| what it missed | bytes |
|---|---|
| SCC stack (u64, sized to V) | **756 MB** — the single largest item |
| comp (SCC id) array | 378 MB |
| entry_starts | 186 MB |
| comp_sizes | 197 MB |
| colex→group map | 164 MB |
| DFS frame stack | 124 MB |
| cycle-reachable marks | 95 MB |
| **missed total** | **≈ 1.90 GB** |

**What the ~1.2 GB estimate got wrong:** it budgeted the value arrays and forgot the
*graph-adjacency and per-SCC accounting* structures that a Tarjan run needs on top — an SCC
stack sized to the vertex count (756 MB), a per-vertex SCC id (378 MB), and the O(1)
child-lookup maps (`entry_starts`, `colex→group`). Summed, these are roughly *another full
copy (or two) of the entry table*. The lesson generalises to the 5×4 sizing: any graph pass
over the reachable entries must budget **~3–6 B per entry of auxiliary arrays on top of the
entry data itself**, not just the table.

---

## 7. Bottom line for L7

- The reachable-state column is now measured at all five sizes, and every instrument agrees
  with an independent source (WZO2 headers, t386, a Python re-implementation).
- The table scales as `n_entries ≈ c·3ⁿ` with `c` ≈ 2.4 and slowly falling; stored cost is
  `4·n_entries + 5·n_groups`.
- **5×4 is RAM-bound**: the dense census bitset is ~110 GB and the sparse path's
  table+fixpoint working set is ~46–52 GB — both over the 48 GB host. Disk ~41–45 GB, wall
  ~11 h history-free, both secondary.
- **5×5 is not buildable in the current WZO2 representation** (~9–11 TB); the 26 GB colex
  figure presumes the unimplemented legal+canonical density folds.
- The T344 1.2 GB forecast's error is now explained precisely: it omitted ~1.9 GB of
  graph-adjacency/per-SCC arrays. Use **~3.7 GB of in-memory arrays at 4×4 (plus the 494 MB
  artifact)** as the corrected baseline when sizing 5×4.

---

*Census runs (T507):* `tools/runner -- zig run -O ReleaseFast src/t358_census_{2x2,3x2,3x3,4x3}.zig`
(all four exit 0); captured under `docs/evidence/GLOBAL.REACH-P4-CENSUS/` (stdout/stderr +
`crosscheck.py` re-implementation + `PROVENANCE.md`). Artifact headers read directly from
`data/oracle-3x3-v2.wzo2` and `data/oracle-4x4-v2.wzo2` (magic `WZO2`, offsets per
`src/artifact2.zig`).
