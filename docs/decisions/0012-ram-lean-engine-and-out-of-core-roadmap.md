# 0012 — RAM-lean engine (5x4 in 48 GB) and the out-of-core road to 5x5

Date: 2026-07-23 · Status: **proposed** (design; measurements pending)

The user requirement: reach 5x4, then 5x5. The machine: 48 GB RAM. The naive
current layout needs ~66-90 GB for 5x4 (3^20 = 3.49e9 slots x 19 B/slot
tables + ~14 B/slot finisher scratch). Analysis shows most of that is
unnecessary; this ADR fixes the layout and stages the road to 5x5.

## What RAM actually holds, and what it must hold

The table stores VALUES (iteration state during convergence, static after),
never moves — children are recomputed on the fly (CPU is cheap, ~O(n^2) per
slot per sweep, dwarfed by memory latency). RAM vs disk is purely a speed
question: sweeps make random reads into distant layers (capture back-edges)
and the finisher's DFS wanders the whole space; random 1-byte reads cost
~1000x on NVMe. Sequential phases stream fine from disk.

## Decision 1: minimal converge working set (~8.5 B/slot; 5x4 ~= 30 GB)

- Converge holds ONLY the L/H bracket quads: 8 x i8 per slot (or 4 if L and
  H run as separate passes). Nothing else is read in the hot loop that
  cannot be derived:
  - legal: 1 bit/slot, packed (0.44 GB at 5x4), computed once at seed.
  - settled: 1 bit/slot, packed (Benson is too costly to recompute per sweep).
  - score: RECOMPUTED on the fly (area_score is O(n), cheaper than the move
    loop already run per slot). Optional i8 column if profiling disagrees.
- Final columns (vb/vw/fb/fw/db/dw) are written to DISK during finalize
  (sequential stream), never RAM-resident. Certified values need no column
  at all mid-pipeline: certified iff L==H, value = L — derive, don't store.
- 5x4 converge peak: 8 x 3.49 GB + bits ~= 28.8 GB. FITS in 48 GB.

## Decision 2: sparse per-root finisher scratch (hash maps, not arrays)

The finisher allocates ~14 B/slot of full-table per-root scratch (memo
copies, baselines, bounds, tried) yet each root touches 10^3-10^5 slots
(the journal already proves the touched-set is tiny). Replace with:
- per-root exact memo + bounds memo: hash maps keyed by (idx, side),
  cleared per root (no journal revert needed — clearing IS the revert).
- baseline: derived from L/H directly (no base_vb/base_cb arrays).
- tried/skip marks: hash set over residue reps only.
Finisher RAM: L/H quads (kept for bracket cuts) + O(touched) maps ~= same
~29 GB peak. The u32 journal encoding (idx < 2^30) dies with the arrays;
anything sparse is keyed u64.

CROSS-CHECK REQUIREMENT (conditional-assumptions doctrine): the lean engine
must reproduce the 4x4 artifact BYTE-IDENTICAL (sha256 recorded in
research/retrograde-4x4.md) and the 2x2/3x2 exhaustive ground truth before
any 5x4 run is trusted.

## Decision 3: 5x4 = the lean in-RAM engine. 5x5 = out-of-core, staged.

5x4 (3^20) needs ONLY decisions 1-2 — no I/O architecture. Expected wall
time: build hours-scale (19->? sweeps, 80x the 4x4 slot count), finisher
similar order; artifact ~21 GB to data/ (checkpointed, resumable).
Published anchor to hit: 4x5 = B+20 (van der Werf & Winands 2009).

5x5 (3^25 = 847G slots) additionally requires, in order:
1. **Density folds** (colex_layout v2, ADR-0011 contract bump): legal-only
   ranking (~2.5x) + canonical fold (dihedral+colour, ~8-16x) -> table on
   disk at ~tens-to-hundreds of GB per column set.
2. **Tiled out-of-core sweeps**: single 5x5 layers exceed RAM (largest
   ~C(25,12)*2^12 slots), so sweeps process (source-tile, target-tile)
   pairs; colex is subset-major, so no-capture children of a subset-tile
   cluster in few target tiles; capture back-edges enumerate per tile-pair
   (the endgame-tablebase literature's standard staging).
3. **Best-effort publication** (already supported by the format): the
   certified core streams out first; the residue finisher refines the
   artifact incrementally by layer, checkpointed, forever resumable.
   A partial 5x5 oracle (certified core + bracketed residue) is a real,
   publishable artifact long before the finisher completes.

## Test ladder (user requirement: prove RAM strategies on small boards first)

1. Lean engine on 3x3/4x4: byte-identical artifacts, identical stats.
2. 6x3 (in flight on the fat engine) re-run lean: identical artifact —
   the first same-board fat-vs-lean engine-vs-engine comparison at scale.
3. 5x4 on the lean engine (the 48 GB proof).
4. Fold + tiling prototypes measured at 4x4/5x4 densities before 5x5.

## Consequences

- gtp/arena load multi-GB artifacts: switch artifact.load to mmap for
  play/analysis (random lookups page in on demand; no RAM constraint).
- The Kishimoto-Muller dependency-guard work (history-perfect player) is
  orthogonal and proceeds in parallel; both touch the finisher memo, so
  land the hashmap refactor FIRST (the guard then keys naturally on the
  sparse map).

## Addendum (same day): layer sizes, compression catalog, revised 5x5 numbers

**Are the biggest layers too big for RAM? Yes, raw** — 5x5's peak layer is
k=17: C(25,17) x 2^17 ~= 1.42e11 slots = 142 GB at even 1 B/slot, ~3x RAM.
Layered streaming alone does not save 5x5; the folds below do.

**Compression / optimization catalog** (generation may be slow; runtime
lookup must stay fast):

1. **V1 is never stored.** V1(pos,s) = opt(children V0, score) — during a
   slot's own update both sides' children are already enumerated, so V1 is
   recomputed inline. Quad shrinks 4 -> 2 values per fixpoint per slot.
2. **L and H as separate runs** halves the live set again: 2 B/slot per run.
   (5x4 converge: 2 B x 3.49e9 = 7 GB. Trivial.)
3. **Canonical fold AT GENERATION, not by ranking**: sweep only canonical
   representatives (dihedral x colour ~= /16); canonicalize each CHILD
   before lookup (min over 8 transforms, O(n) each — pure CPU, the resource
   we have). No legal-ranking math needed anywhere: keep raw colex
   addressing and let BLOCK COMPRESSION make illegal/non-canonical slots
   cost ~0 bits on disk.
4. **Out-of-core capture edges by bucketing**: stream a layer sequentially;
   no-capture children hit the adjacent layer (resident); capture updates
   are emitted as (target, value) records bucketed by target tile and
   applied per tile — sequential I/O only (classic external-memory value
   iteration).
5. **Active-set (dirty-tile) sweeps**: L is monotone up, H monotone down —
   converged tiles stop being swept. Late sweeps touch a collapsing
   fraction (instrument at 6x3/5x4).
6. **Runtime lookup path**: canonicalize position (O(n)) -> mmap'd
   block-compressed column (Syzygy-style fixed blocks + index) -> one block
   decode. Microseconds per probe, no RAM constraint. Value entropy is low
   (histograms dominated by +-n), so the 5x5 oracle plausibly lands
   10-50 GB on disk.

**Revised 5x5 feasibility on 48 GB / typical SSD**: canonical-legal slots
~= 3^25/16 ~= 53e9; working files at 2 B/slot ~= 106 GB per fixpoint
(disk); RAM = tiles + buckets (configurable, <= 40 GB); compute ~= 53e9
slots x ~30 sweeps x ~2 us (incl. canonicalization) ~= 37 single-threaded
days => ~4-6 days on 10 cores + dirty-set savings. GENERATION: days-scale,
acceptable. LOOKUP: microseconds. 5x5 on this hardware is a real plan, not
a wish. 5x4 first (lean in-RAM engine, no I/O machinery) remains the
proving step; 6x3 (in flight) doubles as the fat-vs-lean cross-check.

## Operational requirements for long generation runs (user requirements, 2026-07-23)

Big-board generation must be INTERRUPTIBLE, VERIFIABLE IN PARTS, and
FAIL-FAST — never boil the pond for days before a logic error surfaces.

1. **The unit of work is the (fixpoint, sweep, tile)**: tile files on disk
   ARE the state. Commit discipline: write-new, fsync, atomic rename, then
   update a manifest (sweep number, per-tile checksums). Crash / power cut /
   forced shutdown resumes at the last committed tile; laptop sleep merely
   pauses the process. A polite stop (SIGTERM or a time budget) finishes
   the current tile and exits cleanly resumable.
2. **Every part is independently verifiable**: tile headers carry layer,
   sweep, fixpoint id, checksum (the WZO discipline extended to working
   files). Determinism makes any tile recomputable and diffable in
   isolation.
3. **Fail-fast invariant gates, checked DURING generation, abort on first
   violation**:
   - monotonicity per tile at write time: L never decreases, H never
     increases between sweeps (catches logic errors at sweep 1-2, not day 4);
   - L <= H streamed during the H run against the L file;
   - settled-seed and symmetry spot samples per sweep;
   - changes-per-sweep trend on the heartbeat (should decay geometrically;
     anomaly = stop and look).
4. **Pilot-board regression gate before every big run**: any engine change
   must first reproduce the recorded sha256 artifacts end-to-end on
   3x3 / 4x4 / 6x3 (minutes). No green gate, no big board.
5. **Parallelism unit = the tile** (a dozen+ cores). Note: parallel tiles
   relax Gauss-Seidel to Jacobi-ish ordering, so INTERMEDIATE sweeps are
   schedule-dependent — but the least/greatest fixpoints are unique, so the
   CONVERGED tables are byte-identical regardless of thread schedule
   (chaotic-iteration convergence of monotone maps). Final-hash
   verification therefore survives parallelism; intermediate checkpoints
   need not match across runs.
