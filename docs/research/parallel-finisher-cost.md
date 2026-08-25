# Parallel finisher cost — measured, not projected

**Task:** T930 · **Worker:** deepseek-v4-pro/T930 · **Date:** 2026-08-25
**Landmark:** `L2 (proven 4x4 values)` — decides whether T924's no-go on Track A is a
property of the method or of using one core.

## The question

T924 measured the 4×4 writes-off finisher at **202.5 – 1620 h** single-threaded and ruled it
"not tractable." That number is a one-core wall on an 18-core host (6 Super + 12 Performance,
Apple M5 Max, 48 GB). The retrograde solve is single-threaded; `finishParallel` exists in
`src/retro.zig` (B31) but had never been measured. This row measures it.

## Method

**Rung:** 4×3, writes-off (`memo_writes=false`), 21,578 orbit-representative ko-sensitive roots,
183,065,016 nodes, 20,000,000-node per-root budget — the same solver (`solveSingleKo` else
`ab_value_from_root`) and the same orbit-dedup work list as the production finisher. Work is
deterministic: every run in the sweep produced byte-identical node counts and 0 bracket-fails /
0 orbit-clashes.

**Harness:** `src/t930_parallel_finisher_cost.zig` (throwaway, NOT a production change). It builds
the L/H tables once, builds the same orbit-dedup work list `finishParallel` builds, then solves the
list under a configurable partition. Two partitions were compared:

- **contig** — contiguous chunks, exactly what `finishParallel` does. The work list is built
  deepest-layer-first, so cheap (deep) roots pile into the low thread ids and expensive (shallow)
  roots into the last chunk.
- **rr** — round-robin (root *i* → thread *i* mod *N*), load-balanced.

The per-root solve is byte-equivalent to the production `worker()` in writes-off mode (the journal
is empty there, so the revert is a no-op). The production `finishParallel` itself was also run
directly as the contig arm, and the two contig numbers agree to <1%.

**Host discipline:** fleet drained (arbiter admitted only T930), `caffeinate -i -s` held for the
whole sweep (asserted, T927), results flushed per core-count (T924's lesson), walls taken from
`clock_gettime(MONOTONIC)` around the solve only (build excluded).

## Results — 4×3 scaling curve

Serial finisher wall **34.0 s** (matches T924's 35.2 s to 3%). Speedup = serial / wall.

| threads | contig wall | contig speedup | rr wall | rr speedup | rr efficiency |
|---:|---:|---:|---:|---:|---:|
| 1 | 34 022 ms | 1.00× | 33 497 ms | 1.00× | 100% |
| 2 | 22 466 ms | 1.51× | 18 067 ms | 1.85× | 92.7% |
| 4 | 14 941 ms | 2.28× | 9 359 ms | 3.58× | 89.5% |
| 6 | 11 876 ms | 2.86× | 6 400 ms | 5.23× | 87.2% |
| 8 | 9 884 ms | 3.44× | 5 066 ms | 6.61× | 82.6% |
| 12 | 7 834 ms | 4.34× | 3 774 ms | 8.88× | 74.0% |
| 16 | 6 889 ms | 4.94× | 2 903 ms | **11.54×** | 72.1% |
| 18 | 6 671 ms | 5.10× | 3 083 ms | 10.87× | 60.4% |

## Where it stops scaling, and why

Three effects, measured and separated:

1. **Load imbalance (dominant, fixable).** The contiguous partition is badly imbalanced. Per-thread
   node counts (contig, total 183M): at 6 threads the busiest thread does 63.3M vs the 30.5M
   balanced share (**2.07×**); at 16 threads 34.8M vs 11.4M (**3.05×**); at 18 threads 34.0M vs
   10.2M (**3.34×**). Wall is set by the busiest thread, so contig's ceiling is ≈ 18/3.34 ≈ **5.4×** —
   which is exactly the measured 5.10×. Round-robin removes this: at 2 threads the split is
   89.1M / 93.9M (**1.05×**), and the curve jumps to 11.5× at 16.

2. **Memory latency (residual, not fixable).** Total CPU-seconds is flat across the whole sweep:
   38.4 s (serial) / 40.0 s (contig 6) / 43.1 s (contig 18) / 40.3 s (rr 6) / 45.0 s (rr 16).
   Adding cores never adds throughput — cores stall on cache/DRAM (the memo/table lookups are
   pointer-chases), so parallelism only overlaps stalls. Effective overlap saturates at **~14–15
   concurrent streams**: 16 threads reaches it (72% efficiency), 18 does not beat 16.

3. **E-core asymmetry (the bend).** Near-linear through the 6 Super cores (87% efficiency at 6),
   then the slope shallows across the 12 Performance cores (74% at 12), and the last two cores
   make it slightly *worse* (11.54× at 16 → 10.87× at 18) via added contention.

**Bottom line:** the existing `finishParallel`'s 5.1× is a *scheduling* ceiling, not a hardware
one. A round-robin (or work-stealing) partition recovers it to ~11.5×. The remaining loss is
memory latency, which no scheduler fixes.

## 4×4 extrapolation

Serial figure is T924's bracket, stated in its own convention for comparability.

| path | speedup | 4×4 wall (low end) | 4×4 wall (high end) |
|---|---|---|---|
| serial (T924) | 1× | 202.5 h | 1620 h |
| `finishParallel` as-is (contig, 18 cores) | 5.10× | 39.7 h | 318 h |
| load-balanced (rr, 16 cores) | 11.54× | **17.5 h** | **140 h** |

Two caveats make 11.54× an *upper* bound for 4×4, not an expectation:

- **Working set.** 4×3's tables are ~10 MB and the per-thread context ~6 MB (≈125 MB at 18
  threads), mostly cache-resident. 4×4's tables are ~0.8 GB and each thread's context ~0.5 GB
  (≈10 GB at 18 threads), so a far larger fraction of every memo lookup misses to DRAM. 4×4 is
  *more* memory-bound than the rung that already saturates at ~14 streams, so expect 6–9× rather
  than 11.5×, i.e. roughly **22–34 h at the optimistic end**.

- **Orbit factor.** T924's projection divides the ko-sensitive *slot* count by `num_syms` (8) for
  its low end, but the finisher's orbit dedup also exploits colour inversion — one solved root
  fills 2×`num_syms` slots. The 4×3 rung confirms it: T924's `/num_syms` low end predicts 42,569
  reps, the actual orbit-rep count is **21,578**. The true serial low end is therefore ≈ **101 h**
  (not 202.5 h), and the load-balanced 4×4 low end ≈ **9 h**.

## Verdict

**Parallelism does not make 4×4 writes-off an overnight job, and it does not reach `4x4.D3`'s
≤ 8 h target on any measured path.** But the "Track A is dead" reading is too strong: the 5.1× in
the shipped code is a partitioning bug, and a one-line scheduling change (round-robin) recovers it
to ~11.5×. Against T924's serial bracket, the honest parallel wall is **~17–140 h** (optimistic,
assuming 4×3's balanced scaling transfers) and more realistically **~1–6 days** once 4×4's larger
working set is accounted for. That is the difference between "Track A is dead" and "Track A is a
long weekend — but only after the partition is fixed, and it still needs a real work-stealing
scheduler, not the static chunks in `finishParallel`."

## Reproduction

```sh
# harness (throwaway; not a production change)
tools/runner --ram-mb 4608 -- zig build-exe -O ReleaseFast -femit-bin=/tmp/weizigo/t930_cost \
  src/t930_parallel_finisher_cost.zig
# one rung point (4x3, round-robin, 16 threads)
caffeinate -i -s T930_THREADS=16 T930_W=4 T930_H=3 T930_PARTITION=rr /tmp/weizigo/t930_cost
```

Raw sweep + per-thread imbalance data: `docs/evidence/T930/`.
