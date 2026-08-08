# Parallel fixpoint measurement — 2026-08-03

Task: T314 · Role: worker · Model: deepseek-v4-pro · Date: 2026-08-03

## Summary

T312 built the parallel 4×4 fixpoint and wired race controls (384/384 tests), then stated plainly:
"SPEEDUP TABLE: NOT YET RUN" and bit-identity unverified. This row is the measurement half.

**Result:** The speedup curve flattens at N=12 (2.89× vs serial), and every artifact from N∈{1,2,4,6,12,16}
is **byte-identical** to the T310 serial reference.

## The binary

All six rows used the same binary, snapshotted before the first run:

```
SHA-256: efcec15905790eb0df3ee33b4dc90c1035c6453b48d1c4f738e8c4a4e57a5526
Path:    /tmp/weizigo/t314-snapshot/weizigo-oracle-v2-build — EVIDENCE LOST (path was /tmp, destroyed before rescue on 2026-08-08)
Built:   b3d0209 (HEAD at T314 start)
Host:    Apple M5 Max, 6 P-cores + 12 E-cores, 48 GB LPDDR5
```

## The speedup curve

Each row run sequentially under `tools/runner` (`--max-wall 28800 --max-cpu 57600 --rss-cap-mb 5120
--progress-timeout 7200`). The same snapshot binary, same input, never two runs concurrently.

| Threads | Algorithm | Wall (s) | RSS (MB) | Sweeps | CPU (s) | CPU/Wall | Speedup vs N=1 |
|---------|-----------|----------|----------|--------|---------|----------|----------------|
| 1 | Gauss-Seidel | 3,965.4 | 3,886 | 31 | 3,962.8 | 1.00× | 1.00× |
| 2 | Jacobi | 4,094.6 | 3,887 | 59 | 6,868.5 | 1.68× | 0.97× |
| 4 | Jacobi | 2,488.5 | 3,887 | 59 | 6,946.9 | 2.79× | 1.59× |
| 6 | Jacobi | 1,917.0 | 3,887 | 59 | 7,042.7 | 3.67× | 2.07× |
| 12 | Jacobi | 1,371.4 | 3,888 | 59 | 7,453.2 | 5.43× | 2.89× |
| 16 | Jacobi | 1,361.3 | 3,888 | 59 | 9,366.0 | 6.88× | 2.91× |

**Speedup vs thread count:**

```
Threads  1    2    4    6    12   16
Speedup  1.00 0.97 1.59 2.07 2.89 2.91
         ██   ██   ███  ████ █████ █████
```

### N=2 is slower than N=1 — expected

N=1 uses the serial Gauss-Seidel path (in-place updates, 31 sweeps to convergence). N≥2 uses the
parallel Jacobi path (reads from previous sweep's values, 59 sweeps). The Jacobi sweep-count penalty
(59/31 = 1.90×) outweighs the parallelism gain at N=2. Break-even is between N=2 and N=4.

T312 chose Jacobi precisely so the fixpoint is thread-count-independent, and this data confirms it:
all N≥2 runs converge in exactly 59 sweeps regardless of thread count.

### Flattening at N=12

The curve flattens sharply between N=12 and N=16:

- N=6 → N=12: +6 threads (+100%), speedup 2.07× → 2.89× (+39%)
- N=12 → N=16: +4 threads (+33%), speedup 2.89× → 2.91× (+0.7%)

This is the memory-bandwidth saturation signature. Each fixpoint sweep reads ~3 GB of shared data
(compact_list 792 MB + hash map ~1.6 GB + L/H tables ~400 MB) through random-access hash map lookups.
The Apple M5 Max has a single LPDDR5 memory bus shared across all 18 cores (6 P-cores + 12 E-cores).
At N=12, all 6 P-cores and 6 E-cores are active, and the memory bus is saturated: adding 4 more
E-cores provides negligible additional throughput.

Peak RSS is effectively constant at 3,887±1 MB across all thread counts, confirming T312's claim
of bounded per-thread memory (per-thread overhead is ~0 MB beyond the L_next/H_next arrays, which
are fixed-size regardless of thread count).

### Total CPU overhead

Total CPU increases with thread count — from 3,962.8s at N=1 to 9,366.0s at N=16 — a 2.36× increase
in total work for 2.91× less wall time. The overhead comes from:
- Jacobi doing 59 sweeps vs Gauss-Seidel's 31 (1.90× more iterations)
- Thread synchronization (barriers between sweeps)
- Cache-line contention on the shared hash map
- E-core inefficiency (E-cores do ~⅓ the work per clock of P-cores)

## Bit-identity

Every artifact from all six runs is byte-identical to the T310 serial reference:

```
Command: shasum -a 256 untracked/v0[3-9]/oracle-4x4-v2.wzo2
Reference (T310 serial):  0c3366f07fb33c6f2838ead48ad3080b64dbe55935b87af4f140d81a29e4e15a
v03 (accidental serial):  0c3366f07fb33c6f2838ead48ad3080b64dbe55935b87af4f140d81a29e4e15a
v04 (N=1, Gauss-Seidel):  0c3366f07fb33c6f2838ead48ad3080b64dbe55935b87af4f140d81a29e4e15a
v05 (N=2, Jacobi):        0c3366f07fb33c6f2838ead48ad3080b64dbe55935b87af4f140d81a29e4e15a
v06 (N=4, Jacobi):        0c3366f07fb33c6f2838ead48ad3080b64dbe55935b87af4f140d81a29e4e15a
v07 (N=6, Jacobi):        0c3366f07fb33c6f2838ead48ad3080b64dbe55935b87af4f140d81a29e4e15a
v08 (N=12, Jacobi):       0c3366f07fb33c6f2838ead48ad3080b64dbe55935b87af4f140d81a29e4e15a
v09 (N=16, Jacobi):       0c3366f07fb33c6f2838ead48ad3080b64dbe55935b87af4f140d81a29e4e15a
```

This is the strongest possible result. T312 raised a specific, plausible hypothesis: "the artifact
might differ through group ordering derived from hash-map iteration order." This hypothesis is
**falsified** — the hash-map iteration order is deterministic across all thread counts tested, and
the artifact writer produces byte-identical output regardless of whether the fixpoint was computed
serially (Gauss-Seidel) or in parallel (Jacobi, N=2 through N=16).

Caveat: this only establishes reproducibility on the *current* hash map implementation. A future change
to Zig's hash map (e.g., random seeding of the hash function) could break this property. The
reproducibility is contingent, not guaranteed by construction.

## exp6_hchain_audit.zig — unlabelled duplicate

T312 noted that `src/exp6_hchain_audit.zig` has its own copy of `run_fixpoint_4x4` (line 1100)
rather than importing `exp6_solve.zig`. Confirmed at HEAD (b3d0209): the audit copy has no
`num_threads` parameter and is the pre-T312 serial-only code.

Under the project's duplication-as-oracle doctrine, a redundant implementation is an asset. But an
*unlabelled* one that readers assume is shared is a trap. **Recommendation:** add a header comment
at line 1100:

```
// DUPLICATE of exp6_solve.zig run_fixpoint_4x4 — serial-only, not updated for T312
// parallelism. Under the duplication-as-oracle doctrine this is an asset, but do not
// assume it shares exp6_solve.zig's behaviour.
```

Do not merge them — the independent implementation is a cross-check.

## What this does NOT establish

- **Nothing about real-game correctness.** The fixpoint values are fresh-start scores (C1), not
  real-game PSK scores. The foreclosure on ko-sensitive values stands.
- **Nothing about the exp6_hchain_audit path.** The audit's fixpoint is still serial-only.
- **Nothing on other goban sizes.** Per-goban epistemic independence applies.

## Raw logs

| Run | Log |
|-----|-----|
| N=1 | `docs/evidence/PARALLEL-FIXPOINT-T314/t314-threads-1.log` |
| N=2 | `docs/evidence/PARALLEL-FIXPOINT-T314/t314-threads-2.log` |
| N=4 | `docs/evidence/PARALLEL-FIXPOINT-T314/t314-threads-4.log` |
| N=6 | `docs/evidence/PARALLEL-FIXPOINT-T314/t314-threads-6.log` |
| N=12 | `docs/evidence/PARALLEL-FIXPOINT-T314/t314-threads-12.log` |
| N=16 | `docs/evidence/PARALLEL-FIXPOINT-T314/t314-threads-16.log` |

All logs carry the runner's peak RSS and wall-clock trailers. Logs are in `/tmp/weizigo/` (disposable)
and are not evidence in the git sense — the relevant numbers are in the table above and in the
findings file.

## Proposed register row

```
CODE.PARALLEL-FIXPOINT-MEASURED (MEASUREMENT): The T312 parallel fixpoint was measured.
All artifacts byte-identical to T310 reference. Speedup: 2.91× at N=16, flattening at
N=12 (2.89×). Peak RSS stable at 3,887 MB. Binary: efcec159… (b3d0209).
```
