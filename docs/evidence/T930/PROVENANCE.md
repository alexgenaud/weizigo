# T930 evidence — parallel finisher cost

**Task:** T930 · **Worker:** deepseek-v4-pro/T930 · **Date:** 2026-08-25

## Files

- `sweep.csv` — the 4×3 scaling sweep (contig = production `finishParallel`, rr = round-robin).
- `imbalance.txt` — per-thread node counts proving the contig load imbalance.
- `src/t930_parallel_finisher_cost.zig` — the throwaway harness (committed in-tree).

## How it was produced

```sh
# build the harness (throwaway; NOT a production change)
tools/runner --ram-mb 4608 -- zig build-exe -O ReleaseFast -femit-bin=/tmp/weizigo/t930_cost \
  src/t930_parallel_finisher_cost.zig

# one rung point — e.g. 4x3, round-robin, 16 threads
caffeinate -i -s T930_THREADS=16 T930_W=4 T930_H=3 T930_PARTITION=rr /tmp/weizigo/t930_cost
```

- `T930_PARTITION=contig` reproduces `finishParallel`'s contiguous-chunk partitioning; the
  production `finishParallel` was also run directly and the two contig walls agree to <1%.
- `T930_PARTITION=rr` is round-robin (root *i* → thread *i* mod *N*).
- The per-root solve is byte-equivalent to `retro.zig`'s `worker()` in writes-off mode
  (`memo_writes=false` → the journal is empty → the revert is a no-op). This is a costing
  harness, not a production finisher.

## Host state at each run

- Fleet drained; arbiter admitted **only T930** (4 608 MB) — `tools/runner --arbiter-status`.
- `caffeinate -i -s` asserted around every sweep (the host sleeps unless prevented — T927).
- Load average 2.4–2.6 (the agent's own session), no other lanes in the arbiter ledger.

## Cross-checks

- Determinism: every run reported the identical 21,578 roots / 183,065,016 nodes / 0 bracket-fail /
  0 orbit-clash, so the sweep compares walls only.
- Serial fidelity: harness 4×3 serial = 33.5–34.0 s vs T924's 35.2 s (`docs/evidence/T924/summary.csv`).
- 3×2 calibration: harness reproduces the production finisher exactly (57 roots, 39,496 nodes,
  max_root 4,528) before any 4×3 work.
- CPU-seconds (via `/usr/bin/time -l`, user time): 38.4 s serial / 40.0 s contig-6 / 43.1 s
  contig-18 / 40.3 s rr-6 / 45.0 s rr-16 — flat, the memory-latency signature.
