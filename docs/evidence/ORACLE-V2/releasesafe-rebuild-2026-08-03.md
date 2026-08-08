# ReleaseSafe rebuild-invariance — WZO2 4×4 builder, full run (T313)

Task: T313 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-03

**Headline: the WZO2 4×4 builder produces byte-identical artifact bytes under
`ReleaseSafe` (safety checks on) and `ReleaseFast`. Zero safety-check panics
across the entire pipeline — the 4,390,765,542-entry census, all 31 fixpoint
sweeps, DTT, and the 518 MB write. This is the strongest of the three outcomes
the brief named: byte-identity plus a clean run is UB-independence evidence at
this optimization level that a second ReleaseFast run cannot provide.**

An earlier version of this document (commit `564acf2`, 2026-08-03 15:29) recorded
the first T313 attempt as NOT EXECUTED, blocked by T312's concurrent uncommitted
refactor of the builder source. That history is preserved in git; this document
supersedes it with the executed full run.

---

## 1. The comparison: three artifacts, one SHA-256

Command used (both files, same invocation):

```
shasum -a 256 untracked/v03/oracle-4x4-v2.wzo2 untracked/oracle-v2/oracle-4x4-v2.wzo2
```

| file | mode | bytes | SHA-256 (full) |
|---|---|---|---|
| `untracked/v03/oracle-4x4-v2.wzo2` (this run, ReleaseSafe, HEAD `d070833`) | ReleaseSafe | 518,123,097 | `0c3366f07fb33c6f2838ead48ad3080b64dbe55935b87af4f140d81a29e4e15a` |
| `untracked/v02/oracle-4x4-v2.wzo2` (T310 rebuild, 2026-08-03 05:30, ReleaseFast) | ReleaseFast | 518,123,097 | `0c3366f07fb33c6f2838ead48ad3080b64dbe55935b87af4f140d81a29e4e15a` |
| `untracked/oracle-v2/oracle-4x4-v2.wzo2` (prior, T212 2026-08-01, comparison target) | ReleaseFast | 518,123,097 | `0c3366f07fb33c6f2838ead48ad3080b64dbe55935b87af4f140d81a29e4e15a` |

**Byte-identical across optimization levels.** The ReleaseSafe artifact equals the
ReleaseFast artifacts byte-for-byte. Because the hashes match, no structural diff
is needed — the files are the same 518 MB of bytes.

## 2. The run, for the record

Binary: `weizigo-oracle-v2-build d070833-dirty built 2026-08-03T13:57:06Z zig
0.16.0` at `/tmp/weizigo/safe-build-full/bin/weizigo-oracle-v2-build` — EVIDENCE LOST (path was /tmp, destroyed before rescue on 2026-08-08) — built
2026-08-03 ~16:08 local from HEAD `d070833` (post-T312, pre-T308; the builder
sources `exp6_solve.zig`/`oracle_v2_build.zig` last changed at `663effd` T312,
15:46:32; none of the six later commits touch the builder path). The "dirty"
flag reflects `docs/infra/managent/tasks.json`, which managent rewrites on every
claim/done.

Build command (separate prefix + cache; `tools/runner` post-T311 honors the
explicit `-Doptimize=ReleaseSafe` — no ReleaseFast injection):

```
tools/runner --max-wall 43200 --max-cpu 172800 --progress-timeout 5400 --rss-cap-mb 5120 \
  -- zig build --prefix /tmp/weizigo/safe-build-full --cache-dir /tmp/weizigo/safe-build-full/cache -Doptimize=ReleaseSafe
# EVIDENCE LOST (path was /tmp, destroyed before rescue on 2026-08-08) — the ReleaseSafe build prefix above is gone (the cache dir was never evidence)
```

Run command (full window per the 2026-08-03 machine-time grant; `--threads 1`
selects T312's exact serial Gauss-Seidel path — the control row, and the only
path on which the T184/T310 trajectory and byte comparisons are valid):

```
MANAGENT_TASK_ID=T313 tools/runner --max-wall 21600 --max-cpu 172800 --progress-timeout 5400 \
  --rss-cap-mb 5120 --log-rss -- \
  /tmp/weizigo/safe-build-full/bin/weizigo-oracle-v2-build --threads 1
# EVIDENCE LOST (path was /tmp, destroyed before rescue on 2026-08-08) — the ReleaseSafe-built binary above is gone
```

- log: `untracked/releasesafe-rebuild-full-2026-08-03.log` (this record's copy:
  `docs/evidence/ORACLE-V2/releasesafe-rebuild-full-T313-2026-08-03.log`,
  SHA-256 `1d78aa2233e210c97096f1522cef521e2c7e9753f2b178a02781b4da34ed561c`)
- output: `untracked/v03/oracle-4x4-v2.wzo2` + `untracked/v03/manifest.json`
  (`untracked/VERSION` was 3 before the write phase; the builder incremented it
  to 4 after — per `src/oracle_v2_build.zig` `readVersionCounter`/
  `incrementVersionCounter`). No write over `untracked/oracle-v2/` or
  `untracked/v02/`; both untouched (verified by mtime and re-hash).
- runner trailer (the bar's source, not estimated): wall **4,997.0 s**, CPU
  **4,991.28 s** (99.9% of wall — one core), **peak RSS 3,984 MB**, `exit 0`
  (RUNNER_RC=0 — no ceiling, no kill, no panic).

## 3. Confirming the binary was actually ReleaseSafe

Four signals, the last decisive (the brief's own test):

1. **Size:** 601,896 bytes vs the ReleaseFast binary's 571,464 (same source,
   `zig-out/bin/weizigo-oracle-v2-build`, rebuilt by the acceptance run).
2. **sha256:** `1d7cfec2d802ead633e87c50b88d3f64428f963b98dafb43d68f33b13ef4ab3b`
   vs ReleaseFast `2e3292da7349a20ac1f44b388cd77a59c99dc587090d4e83657ce3e32dae5240`
   — different binaries.
3. **Panic strings present in ReleaseSafe, absent in ReleaseFast** (ReleaseFast
   strips them because those paths are `unreachable`):
   `strings <bin> | grep -c 'integer overflow'` → 1 (ReleaseSafe) / 0 (ReleaseFast);
   `grep -c 'index out of bounds'` → 1 (ReleaseSafe) / 0 (ReleaseFast).
4. The runner's argv line shows a single `-Doptimize=ReleaseSafe` with no
   injected ReleaseFast (T311's optimize-flag detection fix, committed 6f9bedf).

## 4. Safety checks: zero panics through the full pipeline

The run reached the write phase and exited 0. Every safety-sensitive phase was
exercised clean at the scale `zig build test` never reaches:

| phase | what was exercised | ReleaseSafe outcome |
|---|---|---|
| gate chain (2×2, 3×2, 3×3 census + fixpoint) | small-goban full passes | PASS — 2×2 B=0 W=0, 3×2 B=0 W=0, 3×3 B=+9 W=−9 |
| 4×4 census | `encodeState4` 40-bit packing into `u64`, 4,390,765,542-entry space, 548,845,696-byte bitset, 32 BFS sweeps | clean — TOTAL4=4,390,765,542, ReachWords4=68,605,712, total reachable 147,638,298 |
| 4×4 fixpoint | 99,133,036-entry hash map, 31 sweeps over L/H tables | clean — converged: true, sweep 31 L_changed=0 H_changed=0 |
| DTT | iterative relaxation (max 254 sweeps) | clean — 10 DTT sweeps, terminal flags 516,242 |
| artifact build + write | 518,123,097-byte build, SHA-256 self-check, chunked write | clean — "SHA-256 verified", written to `untracked/v03/` |

No `integer overflow` and no `index out of bounds` panic in the entire log.

## 5. Trajectory: 31/31 agree, digit-for-digit, against both references

`sh untracked/watch-rebuild.sh untracked/releasesafe-rebuild-full-2026-08-03.log`
(two invocations, two references):

- vs `docs/evidence/ORACLE-V2/build-T184-2026-08-01.stdout`: **31 agree, 0 diverge**
- vs `untracked/oracle-v2-rebuild-2026-08-03.log` (T310's ReleaseFast run):
  **31 agree, 0 diverge**

Every per-sweep `L_changed`/`H_changed` matches the recorded reference values,
sweep 1 (`L=24,365,875 H=24,365,875`) through sweep 31 (`L=0 H=0`). Roots at
convergence: `root_B(L=1,H=16)`, `root_W(L=-16,H=-1)` — matching T310's record.
The watcher has a null control (31 agree on the completed ReleaseFast log) and a
seeded control (a one-digit change at sweep 5 is caught), both run before it was
trusted (see the brief).

**Corollary:** T312's serial path (`--threads 1`, "exactly the original
Gauss-Seidel") is behaviour-preserving on this path — the post-T312 serial
ReleaseSafe run reproduces the pre-T312 T184/T310 trajectory digit-for-digit and
the artifact byte-for-byte. This is consistent with T312's own race-control
agreement tests, now confirmed at full 4×4 scale under safety checks.

## 6. Resource envelope

| metric | ReleaseSafe (this run) | ReleaseFast (T310) | delta |
|---|---|---|---|
| wall | 4,997.0 s (83.3 min) | 3,789.4 s (63.2 min) | +1.32× |
| CPU | 4,991.28 s (99.9% of wall) | 3,786.08 s (99.9%) | +1.32× |
| peak RSS | **3,984 MB** | 3,887 MB | +97 MB |

Peak RSS 3,984 MB is 78% of the raised 5,120 MB cap and under the standing
4,096 MB cap — reported as required, **no cap change proposed**. ReleaseSafe's
small RSS premium over ReleaseFast is consistent with the safety checks' bookkeeping.

## 7. What this does and does not establish

**Establishes:**
- The WZO2 4×4 builder is **UB-independent at the ReleaseSafe optimization level
  on this input**: with integer-overflow and bounds checks on, the entire pipeline
  (census packing, 4.39 B-entry indexing, fixpoint arithmetic, DTT, write) ran
  clean, and the output is byte-identical to the ReleaseFast output. The class of
  bug this detects — silent UB shared by two ReleaseFast runs — is absent.
- T312's serial fixpoint path is behaviour-preserving (corollary, §5).

**Does NOT establish (scoped out, unchanged from the brief):**
- Nothing about the parallel Jacobi path (`--threads > 1`, the builder's new
  default) — this run used `--threads 1` deliberately. The trajectory and byte
  bars only exist for the serial path. Parallel-path invariance is untested here.
- Nothing about **value correctness (G3b)** — reproducibility is not correctness;
  a deterministic builder reproduces its bugs exactly.
- Nothing about the extracted kernel (the builder's ko rule is its own inline
  copy, per T310's scope note), nor about WZO1 artifacts.
- No safety check tripped, so there is no defect location to record — and none
  was expected; the point is that a wrong assumption would have produced one.

## 8. Baseline comparison — the 19-minute partial run

The brief's prior evidence (baseline, not deliverable): `untracked/
releasesafe-rebuild-2026-08-03.log`, RUNNER_RC=124 (the designed 19-min wall cap,
the *correct* ending for a time-boxed run). Pre-T312 binary `46bc8c1-dirty built
2026-08-03T11:59:50Z` (600,376 bytes, sha256 `a284523cd514420bae438df9ff8a20b8c7210
faad7e687d4d6b6a4f78c17c239` — the partial-run binary, left untouched at
`/tmp/weizigo/safe-build/bin/` — EVIDENCE LOST (path was /tmp, destroyed before rescue on 2026-08-08)). It established: gate chain PASS, full 4×4 census
clean, 8/8 fixpoint sweeps agreeing with T184, peak RSS 3,241 MB, before the wall
cap. The full run confirms the partial run's early evidence and extends it through
sweeps 9–31, DTT, artifact build, and write — the phases the cap could not reach.

## 9. Process notes

- A **concurrent T314 run** (`zig-out/bin/weizigo-oracle-v2-build --threads 1`,
  ReleaseFast, under its own runner, log `docs/evidence/PARALLEL-FIXPOINT-T314/t314-threads-1.log`) was
  executing during this run (observed from ~12:33 elapsed at ~17:00 local). It
  shares no state with this run (separate binary, separate process, deterministic
  single-threaded computation; host has 18 cores / 48 GB). Noted for the record;
  it does not affect this run's validity. The watcher's `process:` line may name
  either builder — it takes the first `ps` match by comm.
- `zig build test` (the acceptance bar) ran green under `tools/runner` before the
  build (exit 0, 36.1 s), confirming the needs-T312 edge: the tree compiles at
  HEAD post-T312.
- `untracked/v03/` did not exist before this run; it now holds the artifact and
  manifest. `untracked/VERSION` advanced 3 → 4 as designed.
