# ReleaseSafe rebuild-invariance attempt — NOT EXECUTED, blocked by T312 (T313)

Task: T313 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-03

**Headline: the T313 experiment (does the WZO2 4×4 builder produce the same
bytes under `ReleaseSafe`?) could not be run. The builder's source is being
rewritten, uncommitted, by the concurrently-dispatched task T312
(`parallel-4x4-fixpoint`), and the working tree did not compile in *any*
optimization mode during the entire window of this task. No ReleaseSafe run
occurred; no safety-check evidence was gathered; no byte-identity claim is
made. Verdict: blocked.**

This is a negative result and a full deliverable: the evidence is *why* the run
was impossible, so the Orchestrator can re-dispatch cleanly once the tree is
stable. Nothing in this document should be read as a statement about the 4×4
builder's behaviour under ReleaseSafe.

---

## 1. What the task was

T313 asked: build the WZO2 4×4 builder with `zig build -Doptimize=ReleaseSafe`
(into a separate prefix/cache) and run the 4×4 build for a time-boxed window
(`--max-wall 1140`, 19 min, human constraint: no background build beyond
20 min), watching the fixpoint trajectory sweep-for-sweep against the T184/T310
reference. The prize: a tripped integer-overflow or bounds check in the census
(4,390,765,542-entry space, 40-bit `encodeState4` packing) or the fixpoint hot
loop would be a latent defect found for free; a clean, on-trajectory partial run
would be evidence of UB-independence.

The 19-min window is not what stopped this task. The source tree was.

## 2. Timeline (local times, 2026-08-03)

| time | event |
|---|---|
| ~15:20:58 | T312 claimed (`deepseek-v4-pro/T312`, `parallel-4x4-fixpoint`) — refactors `src/exp6_solve.zig` (+284/−91) and `src/oracle_v2_build.zig` to parallelize the 4×4 fixpoint (Jacobi, `--threads N`, default `cpu_count-2`). Kanban: holds none, needs T310 only. **No `needs: T312` edge on T313; both tasks were in_progress in set A simultaneously.** |
| 15:21 | T313 claimed. Read the brief chain (T313, T310, DELEGATEE.md, incident record, runner doc, watch-rebuild.sh, runner source, findings schema, `oracle_v2_build.zig` output-path logic). Confirmed: `untracked/VERSION` = 3 (builder would write `untracked/v03/`, absent — expected for a capped run); pre-commit gate installed; the builder emits no `[progress]` lines (0 in T310's log), so the runner's fallback wall ceiling is the effective cap. |
| 15:22 | **ReleaseSafe build attempt** under `tools/runner` (separate prefix `/tmp/weizigo/safe-build`, cache `/tmp/weizigo/safe-build/cache`, explicit `-Doptimize=ReleaseSafe`). Runner argv verified: no ReleaseFast injection. Failed in 13 s: `src/exp6_solve.zig:1273:13: error: use of undeclared identifier 'runJacobiSweep'`, reported for all 4 exes that import the file. |
| 15:24–15:25 | `src/exp6_solve.zig` mtime advanced 15:24:13 → 15:25:17 — the file was still being edited while I diagnosed. |
| 15:26 | **ReleaseFast probe build** (separate prefix `/tmp/weizigo/probe`) — to test whether the failure was mode-specific. Also failed, on a *different* error: `src/oracle_v2_build.zig:53:37: error: root source file struct 'process' has no member named 'argsAlloc'` (`std.process.argsAlloc` does not exist in Zig 0.16). Same tree, different mode, different error → the breakage is the moving tree, not the optimization mode. |
| 15:28 | Decision: stop and report. The tree is non-compiling in all modes and still mutating; a ReleaseSafe run against it would be unreproducible and meaningless. Wrote this record, the findings file, and the context dump; committed; closed as blocked. |

## 3. The evidence, verbatim

### 3.1 The 15:22 ReleaseSafe attempt (`releasesafe-attempt-T313-2026-08-03.log` in this directory; SHA-256 `92bf4001c807adb9848550a7fa8dd9bf0735f6fcc2f8c553f9127d372f768f94`)

```
[runner] argv = zig build --prefix /tmp/weizigo/safe-build --cache-dir /tmp/weizigo/safe-build/cache -Doptimize=ReleaseSafe
...
install
+- install weizigo-oracle-v2-build
   +- compile exe weizigo-oracle-v2-build ReleaseSafe native 1 errors
src/exp6_solve.zig:1273:13: error: use of undeclared identifier 'runJacobiSweep'
            runJacobiSweep(gpa, nt, chunk_size, compact_count, compact_list.items, &map, L_tab, H_tab, L_next, true, &child_indices);
            ^~~~~~~~~~~~~~
error: 1 compilation errors
```

Two observations that identify this as a mid-edit snapshot, not a ReleaseSafe defect:

- The error snippet text matches a `runJacobiSweep` call that sits at **line 1385**
  of the file as read minutes later — the file grew ~112 lines between the failed
  compile and the read (the definition `fn runJacobiSweep`, now at line 1150, was
  not yet saved when the calls were).
- The identical breakage class reproduces in ReleaseFast (below). `use of undeclared
  identifier` is a mode-independent semantic error.
- The compile error output confirms the build *was* ReleaseSafe (`compile exe
  weizigo-oracle-v2-build ReleaseSafe native 1 errors`), and the runner argv line
  shows a single `-Doptimize=ReleaseSafe` with no injected ReleaseFast.

### 3.2 The 15:26 ReleaseFast probe (`releasesafe-probe-T313-2026-08-03.log` in this directory; SHA-256 `aa55ce012c8809654eea9e4628c712abc7ff589d92973245373e94a429d72f7f`)

```
install
+- install weizigo-oracle-v2-build
   +- compile exe weizigo-oracle-v2-build ReleaseFast native 1 errors
src/oracle_v2_build.zig:53:37: error: root source file struct 'process' has no member named 'argsAlloc'
        const args = try std.process.argsAlloc(gpa);
                         ~~~~~~~~~~~^~~~~~~~~~
error: 1 compilation errors
```

`std.process.argsAlloc` is the Zig ≤0.15 API; it does not exist in Zig 0.16 (the
repo's pinned toolchain). T312's in-progress `--threads` parsing in the builder
uses it. This is T312's transient state, recorded here only to prove mode-
independence of the breakage.

## 4. Why the task stopped — the structural collision

- T312's deliverables *are* `src/exp6_solve.zig` and `src/oracle_v2_build.zig` —
  the exact source T313 must build and run. Both tasks were dispatched
  concurrently (both in_progress in set A at 15:21), with **no serialization**
  (`needs:` edge absent on T313, `holds:` none on either).
- `src/exp6_solve.zig` and `src/oracle_v2_build.zig` are **not** in the
  one-writer-per-engine-file holds list (which names `retro.zig`, `oracle.zig`,
  `rules.zig`, `solve.zig`). Nothing in the process declared a writer for the
  two files T312/T313 collided on.
- Even after T312 commits, the task as briefed needs adjustment: T312's default
  (`getCpuCount()-2` threads, parallel Jacobi) changes the fixpoint sweep trace —
  T312's own brief states "31 sweeps is not a bar" — so the T184/T310 trajectory
  comparison only remains valid if the builder is run with `--threads 1` (T312's
  serial control path, documented as exactly the original Gauss-Seidel).

## 5. What this task did NOT establish (explicit non-claims)

- **No** ReleaseSafe run happened: no safety-check trip, and no clean pass through
  the 4×4 census or any fixpoint sweep.
- **No** trajectory agreement/divergence was observed (nothing ran).
- **No** peak RSS or wall-clock from a runner trailer for the builder.
- **No** artifact, and no SHA-256: `untracked/v03/` does not exist (expected for a
  capped run; the write phase was never reachable).
- **No** UB-independence claim, byte-identity claim, or any claim about the
  builder under ReleaseSafe. The only ReleaseSafe-specific observation is
  *negative*: the one compile failure my build hit was mode-independent and is
  not evidence of a ReleaseSafe-only defect.
- Acceptance (`zig build test`) was **not** run: the fleet's shared gate currently
  fails on T312's transient code (the 15:26 probe is direct evidence), so running
  it would record T312's breakage as T313's result and could race T312's own
  acceptance.

## 6. Process observations for the Orchestrator (recorded, not acted on)

1. **Dispatch gap:** T313 has no `needs: T312` edge despite both tasks targeting
   the same builder source. Two writers on one file with no holds declaration is
   the exact failure mode AGENTS.md's one-writer rule exists to prevent; the rule
   just does not cover `exp6_solve.zig`/`oracle_v2_build.zig`.
2. **T311's runner fix is uncommitted.** The committed `tools/runner` checks
   `"-Doptimize" in argv` by exact token equality, which never matches
   `-Doptimize=ReleaseSafe` — it would have silently injected `-Doptimize=ReleaseFast`
   (last flag wins) and answered the wrong question. The working tree carries T311's
   fix; T313's build relied on it and verified the flag survived. Until T311 commits,
   any ReleaseSafe/Debug build through the runner depends on a dirty tree.
3. **Brief-internal contradictions in the T313 brief** (all moot, but noted): the
   run command in "How to run it" shows `--max-wall 43200` while TIME-BOXED says
   "deliberately capped with `--max-wall 1140`"; and a stale "What a 55-minute run
   can conclude" paragraph survives next to the 19-minute cap. The 1140 value is
   the one that matches the human constraint and I resolved toward it.

## 7. Recommendation for re-dispatch

Re-dispatch T313 after T312 commits and the tree is clean. Then:

1. Build with the *committed* `tools/runner` (or confirm T311 landed) to the
   separate prefix, verifying the ReleaseSafe flag survives (argv line + binary
   differs from the ReleaseFast one).
2. Run the builder with **`--threads 1`** to keep the serial control path and the
   T184/T310 trajectory bars valid — or, if the task's intent is to test the
   parallel path, re-base the trajectory reference on T312's own baseline run and
   say so in the report. `sh untracked/watch-rebuild.sh <log> <reference>` takes
   an explicit reference.
3. Everything else in the brief stands: 19-min cap, census-as-prize, N stated,
   peak RSS/wall from the runner trailer, panic-outranks-all.
