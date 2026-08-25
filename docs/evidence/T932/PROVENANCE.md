# T932 evidence — production round-robin partition + re-measurement

**Task:** T932 · **Worker:** deepseek-v4-pro/T932 · **Date:** 2026-08-25

## Files

- `production-4x3.csv` — the production `finishParallel` 4×3 re-measurement (post-round-robin),
  compared against T930's harness sweep.
- `per-thread-16.txt` — per-thread node counts from the production binary at 16 threads,
  round-robin vs contiguous, proving the imbalance is gone / present respectively.
- `tools/regression-finishparallel-partition.sh` — the wired regression (null + seeded-defect
  controls), committed in-tree.
- `src/retro.zig` — the change itself: `finishParallel` now partitions round-robin.

## The change

`RT.finishParallel` (src/retro.zig, B31) partitioned its deepest-first work list into **contiguous
chunks**, which T930 measured as load-imbalanced (busiest thread 3.34× the balanced share at 18
threads → 5.10× wall). T932 replaces that with **round-robin** (root *i* → thread *i* mod *N*),
ported from T930's throwaway harness, so each thread sees a decorrelated mix of cheap and expensive
roots.

Two small, deliberate seams (same file, no solver/orbit/writes-off change):

- `RETRO_PARTITION=contig` restores the legacy contiguous chunking — the seeded-defect control and
  A/B measurement use it. Default is round-robin.
- `finishParallel` now prints one `finishParallel: thread N: … nodes=X` line per thread (stderr);
  the regression's imbalance detector reads those. `RETRO_4X3=1` dispatches the production pipeline
  on 4×3 (the T930 rung) so the re-measurement exercises production, not the harness.

## How it was produced

```sh
zig build-exe -O ReleaseFast -femit-bin=/tmp/weizigo/retro_fast src/retro.zig

# production 4x3, writes-off (RETRO_SOUND=1), fresh ckpt/out per run, caffeinate held
caffeinate -i -s -- \
  RETRO_4X3=1 RETRO_PARALLEL=1 RETRO_PARALLEL_THREADS=16 RETRO_SOUND=1 \
  RETRO_PARALLEL_PROGRESS=0 RETRO_PARALLEL_CKPT=<tmp>/ck.wzo RETRO_PARALLEL_OUT=<tmp>/o.wzo \
  /tmp/weizigo/retro_fast
```

The wall is the `finishParallel: … (NNNms)` figure — `nowMs()` around the solve only, build
excluded (build ≈ 5.2 s). Runs were serial, caffeinate asserted, one at a time.

## Production re-measurement (the T930 rung)

| partition | threads | finish wall | speedup (vs 35 670 ms serial) | T930 harness |
|---|---:|---:|---:|---:|
| round-robin | 16 | 3 064 ms | **11.64×** | 2 903 ms / 11.54× |
| contiguous | 16 | 6 985 ms | 5.11× | 6 889 ms / 5.10× |
| round-robin | 18 | 3 124 ms | 11.42× | 3 083 ms / 10.87× |

Production reproduces T930's 11.5× within ~1% (round-robin 11.64× vs 11.54×) and the contiguous
5.1× essentially exactly (5.11× vs 5.10×). The harness number is now a production number.

## Determinism

Every run — 4×3 at 1 / 16 / 18 threads, and the regression's 3×3 at 1 / 4 threads — reported
byte-identical finisher counts: **21,578 roots / 183,065,016 nodes / 0 bracket-fail / 0
orbit-clash / symmetry PASS** at 4×3, and **622 roots / 315,484 nodes / 0 / 0 / PASS** at 3×3.
The per-root solve is independent in writes-off mode (the journal is empty), so the partition
cannot change the node count; the numbers confirm it.

## The ceiling (why not 18×)

11.5× at 16 threads on an 18-core box is not linear and never will be. T930 separated the cause:
total CPU-seconds is flat across 1→18 cores (~40–45 s), so adding cores never adds throughput —
cores stall on cache/DRAM pointer-chases and parallelism only overlaps the stalls. Effective
overlap saturates at ~14–15 concurrent streams: 16 threads reaches it (72% efficiency), 18 does not
beat 16 (11.42× here, 10.87× in T930). The 6 Super cores scale near-linearly (87% eff at 6), the 12
Performance cores add less each (74% at 12), and the last two cores are net-neutral via contention.
The residual loss is memory latency, which no scheduler fixes.

## Host state

- `caffeinate -i -s` held around every measurement run (the host sleeps unless prevented — T927).
- Runs serial, one at a time; no other solve lane admitted.
- Wall from `clock_gettime(MONOTONIC)` around the solve only (build excluded).
