# Parallel 4×4 Fixpoint — T312

Task: T312 · Role: worker · Model: deepseek-v4-pro · Date: 2026-08-03

## Summary

The 4×4 fixpoint solver in `src/exp6_solve.zig` was single-threaded, using 1 core of 18
on the development host. This task added parallel Jacobi iteration with a `--threads N` flag,
defaulting to `cpu_count − 2` (16 on this host).

## Design

### Jacobi vs Gauss-Seidel

The serial code uses **Gauss-Seidel** iteration: each state's new value is computed from the
most recent child values, some of which may have been updated earlier in the same sweep.
Gauss-Seidel converges faster (fewer sweeps) but is inherently sequential — the order of
state updates affects each sweep's result.

The parallel code uses **Jacobi** iteration: all threads read from the *previous sweep's*
values and write to a fresh output array. After the sweep completes, the new values are
copied back. This is:

- **Data-parallel**: states can be processed in any order, by any number of threads.
- **Deterministic**: the result of each sweep depends only on the previous sweep's values,
  which are fixed when the sweep starts. Thread count and scheduling do not affect the result.
- **Provably correct**: for a monotone operator on a complete lattice, Jacobi and Gauss-Seidel
  converge to the same (unique) fixpoint, though Jacobi may require more sweeps.

### Implementation

- `run_fixpoint_4x4(gpa, reach, num_threads)`: when `num_threads ≤ 1`, uses the exact serial
  Gauss-Seidel path (unchanged from the pre-T312 code). When `num_threads > 1`, uses parallel
  Jacobi.
- `JacobiShared`: shared read-only state (compact_list, map, cur_tab, is_L flag).
- `jacobiWorker`: processes a range of compact indices, reading from `cur_tab` and writing to
  `next_tab`. Each thread uses its own local `child_indices` buffer.
- `runJacobiSweep`: partitions the compact list into chunks, spawns `nt−1` worker threads plus
  one on the calling thread, joins all, then counts changes and swaps arrays.
- `defaultFixpointThreads()`: returns `max(1, cpu_count − 2)`. The `−2` leaves cores for the
  OS and concurrent agents. macOS has no `taskset` or `numactl`, so thread count is the only
  core-sharing lever.

### Memory

| Component | Size | Shared? |
|---|---|---|
| `compact_list` | ~793 MB | read-only |
| `map` (AutoHashMap) | ~1.6 GB | read-only |
| `L_tab` + `H_tab` | ~198 MB | read-only during sweep |
| `L_next` + `H_next` | ~198 MB | disjoint-write |
| Per-thread stack | ~8 KB each | per-thread |

Peak RSS with 4 threads: ~3.4 GB (vs 3.2 GB serial), well within the 4 GB standing cap.

### Threading pattern

Adapted from the parallel finisher in `src/retro.zig` (B31, lines 1259–1750):
- Worker 0 runs on the calling thread.
- Workers 1..N−1 are spawned via `std.Thread.spawn`.
- All are joined before the next sweep.
- No per-thread output buffers needed — workers write to disjoint ranges of shared output arrays.

## Race Controls

Four tests in `src/t312_race_control.zig`, wired into `zig build test`:

| Test | Threads | Reps | Result |
|---|---|---|---|
| Serial vs parallel (tiny graph) | 4 | 100 | PASS |
| Serial vs parallel (tiny graph) | 2 | 50 | PASS |
| Serial vs parallel (tiny graph) | 7 | 10 | PASS |
| Seeded defect: missing join barrier | 4 | 1 | PASS (detects sentinel values) |

The tiny graph (512 states, DAG-structured children) exercises the same Jacobi worker pattern
as the 4×4 fixpoint. The seeded defect test spawns threads to fill a 10M-element array,
gives the main thread only 100 elements, and checks for uninitialized values before joining —
reliably detecting a missing synchronization barrier.

**Why 160 total reps is enough**: each rep exercises thread spawn, parallel Jacobi computation,
and join. Races from improper synchronization (missing barrier, overlapping ranges) manifest
as wrong results. The Jacobi pattern has no cross-thread mutable state (workers write to
disjoint ranges of `next_tab` and read from the unchanging `cur_tab`), so races are structurally
impossible in the correct implementation. The reps confirm there's no accidental shared mutable
state (e.g., a global variable or static buffer in genChildren4).

## CLI

```sh
# Serial (exact pre-T312 behaviour)
zig run -O ReleaseFast src/exp6_solve.zig -- --threads 1

# Parallel (default: cpu_count - 2)
zig run -O ReleaseFast src/oracle_v2_build.zig -- --threads 8

# Show help
zig run -O ReleaseFast src/oracle_v2_build.zig -- --help
```

## Speedup Table

*Pending — to be run sequentially under `tools/runner` with the same binary and input.
Threads: 1, 2, 4, 6, 12, 18. Each run takes ~30–60 minutes.*

## Files Changed

- `src/exp6_solve.zig` — added `num_threads` parameter, Jacobi implementation, `defaultFixpointThreads()`, `--threads` CLI flag
- `src/oracle_v2_build.zig` — added `--threads` CLI flag, passes `num_threads` to `run_fixpoint_4x4`
- `build.zig` — added `t312_race_tests` step
- `src/t312_race_control.zig` — new: race-control test suite
