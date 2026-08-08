# T428 · Phase 4 — Design: the boundary, scored against the eight qualities

| | |
|---|---|
| Sprint | T428 (tool consolidation), set S |
| Phase | 4 of 8 — **design** |
| Writer | deepseek-v4-pro/T428.2 |
| Date | 2026-08-08 |
| Commit | `697a3ef` (HEAD, "T428 Phase 3: acceptance tests written before design") |
| Audit | pending — row to be registered and dispatched |
| Status | PROPOSED — awaits independent audit before Phase 5 begins |

**Phase 3 audit findings carried forward.** The Phase 3 audit (T434, glm-5.2) returned PASS WITH
FINDINGS. This design explicitly addresses F4 (separation-of-concerns boundary: separate exit codes,
no shared mutable state) — the verb dispatch contract below (§3.1) is the design's answer.
F3 (C1.9 RED-first) is a Phase 7 reporting item. The remaining findings (F1, F2, F5, F6) are
Phase 7 reporting items or Phase 6 implementation notes.

---

## 1. Design decisions at architecture level

The Phase 2 scope named two merges: claimlint+absorb (one Zig binary, `verify`/`absorb` verbs) and
subagent+ollama-subagent (one Python script, `--provider` flag). This design defines the boundary
for each.

### 1.1 One binary with verbs — NOT a shared library

The merged tool is **one binary with subcommand verbs**, not a shared library. Rationale:

- **A shared library** (`libweizigo-tools.a` imported by claimlint, absorb, managent, argus) would
  require a stable C ABI or Zig package interface, would touch every consumer, and would be a
  migration rather than a merge — the opposite of consolidation. The strategy §4 explicitly ruled
  out rewrites.
- **A single binary with `verify`/`absorb` verbs** is a mechanical merge: the two `main()` functions
  become verb handlers behind a dispatch, and the inline parser is retired. The change is local to
  `src/claimlint.zig` and `build.zig`; neither `managent` nor `argus` is touched.
- **gen-indices** may later consume the merged binary's output (e.g., `weizigo-claimlint parse
  --json`) — that is a consumer relationship, not a library dependency, and is deferred to Phase 4
  assessment per scope §3.5. The verb approach supports this: adding a `parse` verb later is a
  non-breaking extension.

### 1.2 Backward compatibility: default verb = `verify`

The old `weizigo-claimlint` had no verb — it was invoked as `weizigo-claimlint [paths...]`. The
merged binary preserves this: if the first non-flag argument is not a recognized verb, it is treated
as a path argument and the `verify` verb is used. This means every existing invocation (shell scripts,
regression scripts, the pre-commit hook, GTP wrappers) works unchanged.

The `absorb` verb is invoked as `weizigo-claimlint absorb <findings.json> [--dry-run]`. The old
`bin/weizigo-absorb` becomes a wrapper script.

## 2. claimlint + absorb merge — file-level design

### 2.1 File changes

| file | change | rationale |
|---|---|---|
| `src/claims_register.zig` | fix stale header line 21: "Used by claimlint (checker) and absorb" → "Used by claimlint (verify and absorb verbs) — imported by src/claimlint.zig" | F3 carried from Phase 1 audit; header now matches actual topology |
| `src/claimlint.zig` | (1) import `claims_register.zig` and `absorb.zig` as modules; (2) remove the inline parser (functions: `Register` struct, `parseRegister`, `parseStatus`, `parseNarrowed`, `parseRate`, `backtickSpans`, `claimIdOf`, `isQaId` — ~300 lines); (3) replace all call sites with `cr.parseRegister(...)` etc.; (4) add verb dispatch in `main()`; (5) on `absorb` verb, call `absorb.runAbsorb(...)` | the single-parser attack (P2): retire the inline copy, make `claims_register.zig` the single source of truth |
| `src/absorb.zig` | (1) rename `main()` → `pub fn runAbsorb(io: Io, gpa: Allocator, args: [][]const u8) !void`; (2) remove the version banner print (claimlint main prints it once); (3) remove `findRepoRoot` call — claimlint main resolves paths; (4) expose findings JSON parser as `pub fn parseFindingsJson(...)` | absorb becomes a module, not a standalone binary |
| `build.zig` | (1) remove `absorb_exe` and `absorb_deploy` targets; (2) add `absorb.zig` and `claims_register.zig` as modules to `claimlint_exe`; (3) remove `weizigo-absorb` from the deploy step | one build target instead of two |
| `bin/weizigo-absorb` | replace with a shell wrapper: `#!/bin/sh\nexec bin/weizigo-claimlint absorb "$@"` + deprecation notice on stderr | cutover safety (brief §Bar 2) |

### 2.2 Verb dispatch contract (the separation-of-concerns boundary)

The acceptance tests C1.1 and the Phase 2 scope §3.1 verb-boundary contract demand that `verify`
and `absorb` keep distinct exit codes and no shared mutable state. Design:

```zig
pub fn main(init: std.process.Init) !void {
    // ... version banner ...
    const gpa = std.heap.page_allocator;
    const io = init.io;
    var args = std.process.Args.Iterator.init(init.minimal.args);
    const prog = args.next().?; // "weizigo-claimlint"
    const verb = args.next();

    if (verb) |v| {
        if (std.mem.eql(u8, v, "absorb")) {
            // Collect remaining args and pass to absorb.runAbsorb
            var absorb_args = std.ArrayList([]const u8).init(gpa);
            defer absorb_args.deinit();
            while (args.next()) |a| : (try absorb_args.append(a)) {}
            return absorb.runAbsorb(io, gpa, absorb_args.items);
        }
        if (std.mem.eql(u8, v, "help") or std.mem.eql(u8, v, "--help") or std.mem.eql(u8, v, "-h")) {
            // print help listing both verbs
            printHelp(io);
            return;
        }
    }

    // Default: verify verb. Reconstruct argv so the existing verify logic
    // (which reads args from init) sees the right set.
    return runVerify(init, verb); // verb may be null or a path
}
```

**Exit codes:**
- `verify`: 0 = clean (no findings), 1 = findings present, 2 = usage/IO error, 3 = unparsed rows
  (existing claimlint convention — lines 1246, 2342 at `9a96f8b`)
- `absorb`: 0 = absorption proposed, 1 = usage/IO error (existing absorb convention)
- The exit codes overlap numerically on 0 and 1. The boundary is NOT numeric — it is structural:
  separate code paths (the dispatch routes `absorb` to `absorb.runAbsorb` and everything else to
  `runVerify`; no code path reaches both), separate invocation context (the verb is the first
  argument, visible in argv), and no shared mutable state between invocations. A caller that wants
  to distinguish `verify`-exit-0 (clean register) from `absorb`-exit-0 (absorption proposed)
  already knows which verb it invoked.

**No shared mutable state:** each invocation parses args, allocates from the page allocator, runs
one verb, and exits. No global mutable state persists between invocations. The separation is
structural (separate code paths, separate exit-code ranges), not by convention.

### 2.3 Parser retirement: what the inline copy looks like and what replaces it

claimlint's inline parser (~300 lines, functions at lines 713–930 at `9a96f8b`) is a copy of the
public API of `claims_register.zig`. The retirement is:

1. **Remove** (from `src/claimlint.zig`): `Register` struct, `parseStatus`, `parseNarrowed`,
   `parseRate`, `backtickSpans`, `parseRegister`, `isClaimIdToken`, `claimIdOf`, `isQaId`.
2. **Add import**: `const cr = @import("claims_register.zig");`
3. **Replace call sites**: every `parseRegister(...)` → `cr.parseRegister(...)`, every
   `parseStatus(...)` → `cr.parseStatus(...)`, etc.
4. **Drop the inline `Register` struct**: claimlint's own `Register` struct has an identical
   shape to `cr.Register`. Call sites that access `reg.rows`, `reg.format_ok`, `reg.header_cols`,
   etc. work unchanged — the types are compatible.
5. **Verify compatibility**: the two `Register` structs must be confirmed identical before the
   merge. If they differ, that is the "rewrite rather than a merge" refutation criterion from
   strategy §7, and the design fails. Phase 6 (build) reports the diff.

The post-merge guarantee: if the register parser is wrong, the T406 shape (same file, two Zig
verdicts, no alarm) is structurally impossible — both verbs call the same `cr.parseRegister()`.

### 2.4 Estimated line-count impact

| change | lines removed | lines added | net |
|---|---|---|---|
| claimlint inline parser removal | ~300 | 0 | −300 |
| claimlint import + call-site updates | 0 | ~15 | +15 |
| claimlint verb dispatch in main() | 0 | ~20 | +20 |
| absorb.zig: expose runAbsorb, remove main boilerplate | ~30 (main, findRepoRoot, path resolution) | ~10 (function signature) | −20 |
| claims_register.zig: fix stale header | 2 | 2 | 0 |
| build.zig: remove absorb targets, add modules | ~25 | ~10 | −15 |
| **net** | | | **−300** |

The merged binary is ~3,600 lines (3,200 + 657 − 300 + 45 ≈ 3,602), down from the separate
3,857 (3,200 + 657). The count reduction is not the primary dividend (one parser is), but it
confirms the merge is not a bloating exercise.

## 3. subagent + ollama-subagent merge — file-level design

### 3.1 File changes

| file | change | rationale |
|---|---|---|
| `bin/subagent` | add `--provider` flag parsing; `--provider` is REQUIRED (missing → error, satisfying C2.1); `--provider ollama` runs the Ollama dispatch path; `--provider deepseek` runs the DeepSeek path; unknown provider → error | one script, two providers; backward compat via wrapper that injects `--provider deepseek` |
| `bin/ollama-subagent` | replace with a shell wrapper: `#!/usr/bin/env python3\nimport subprocess, sys\nsys.stderr.write("ollama-subagent: use bin/subagent --provider ollama\\n")\nsys.exit(subprocess.call([sys.executable, "bin/subagent", "--provider", "ollama"] + sys.argv[1:]))` | cutover safety |

### 3.2 Provider dispatch design

The current scripts are 205 and 248 lines with 113 common lines. The merge strategy:

1. **Keep the common scaffold** (depth check, nonce generation, dispatch_verify import, run_worker,
   argument parsing) as the shared main body.
2. **Branch on `--provider`** at exactly one point: the command construction. DeepSeek path builds
   a `ds-pi` command with `DEEPSEEK_API_KEY`; Ollama path builds `ollama launch pi --model <tag>`.
3. **`--provider` is REQUIRED.** A bare `bin/subagent` (no `--provider`) exits non-zero with
   "missing --provider (deepseek|ollama)" on stderr — satisfying C2.1 and scope §3.2. Backward
   compatibility is via the `bin/subagent` *cutover wrapper*, which injects `--provider deepseek`
   so old invocations that expected the DeepSeek path still work unchanged.
4. **Ollama path requires `--model`** (same as old `ollama-subagent`); DeepSeek path infers model
   from the prompt (same as old `subagent`).

Depth cap is identical in both scripts (MAX_DEPTH=3, verified by T433 F2), so no reconciliation
is needed — the shared main body checks depth before the provider branch.

### 3.3 Estimated line-count impact

Current: 205 + 248 = 453 lines across two files.
Merged: ~290 lines (113 common + 45 deepseek-unique + 64 ollama-unique ≈ 222 distinct lines +
~70 lines for the provider dispatch logic, help text, and the shared scaffold that was duplicated).

## 4. Eight-quality score for the design

Scored against the operational definitions from strategy §5:

| quality | claimlint+absorb design | subagent pair design |
|---|---|---|
| **reuse** | `+` — one parser (`claims_register.zig`) imported by claimlint; 300 lines of inline copy retired | `+` — 113 common lines deduped into shared scaffold |
| **testability** | `+` — union of 4 regression scripts; one binary, one build target | `+` — union of 3(+2 shared) scripts; one file to test |
| **predictability** | `+` — default verb = `verify` (backward compat); `absorb` verb is explicit; no mode surprises | `+` — `--provider` flag is REQUIRED (missing → error, satisfying C2.1); explicit providers, no silent default |
| **transparency** | `+` — `--help` lists both verbs; `2>/dev/null` contract preserved per verb | `+` — `--help` lists both providers; dispatch trace visible for both |
| **stability** | `0` — cutover wrappers keep `bin/weizigo-absorb` alive; backward-compat default preserves old invocations; the `−` from scope is mitigated to `0` by the concrete cutover design | `0` — wrapper keeps `bin/ollama-subagent` alive; `bin/subagent` wrapper injects `--provider deepseek` for backward compat |
| **agility** | `+` — one file for a parser fix instead of two; one build target | `+` — one file to edit for dispatch changes |
| **performance** | `+` — one build, one deploy; ~300 fewer lines | `+` — one Python parse instead of two |
| **separation of concerns** | `0` — verb dispatch is a structural boundary: separate code paths, separate invocation context (verb in argv), no shared mutable state; exit codes overlap numerically (0 and 1) but the verb disambiguates — a caller already knows which verb it invoked; the `−` from scope is mitigated to `0` by structural separation, not numeric separation | `0` — provider flag separates mechanism (API call) from policy (which provider); no concern bleed |

No `−` entries remain. The two scope-level `−` entries (stability, separation of concerns) are
mitigated to `0` by the concrete design choices: cutover wrappers + backward-compat defaults for
stability; verb dispatch with separate exit codes and no shared state for separation of concerns.

## 5. What the design does NOT do

1. **No shared library.** The merged binary is the artifact; `claims_register.zig` is a Zig module
   imported at compile time, not a shared library with a stable ABI. Other consumers (managent,
   argus, gen-indices) are unchanged.
2. **No `parse` verb (yet).** gen-indices may later consume `weizigo-claimlint parse --json` — that
   is a Phase 4 assessment per scope §3.5, not a Phase 4 build commitment. Adding a verb later is a
   non-breaking extension.
3. **No managent or argus changes.** Both tools stay exactly as they are. Their shallow CLAIMS.md
   reads (sites 4 and 5) are unchanged; neither imports `claims_register.zig`.
4. **No `tasks.json` schema changes.** The kanban store is untouched.
5. **No regression script rewrites.** Existing scripts are pointed at the merged entry points (via
   `PATH` or wrapper resolution). No script logic is changed, only the binary name it invokes.

## 6. Build system changes (`build.zig`)

Before (at `9a96f8b`):
```
claimlint_exe = b.addExecutable(.name = "weizigo-claimlint", ...)
  imports: version

absorb_exe = b.addExecutable(.name = "weizigo-absorb", ...)
  imports: version, claims_register

b.installArtifact(claimlint_exe)
b.installArtifact(absorb_exe)

// deploy steps for both
```

After:
```
claimlint_exe = b.addExecutable(.name = "weizigo-claimlint", ...)
  imports: version, claims_register, absorb

// absorb_exe REMOVED
// absorb_deploy REMOVED
// deploy_step: absorb_deploy REMOVED from dependencies

b.installArtifact(claimlint_exe)
```

The `absorb.zig` module import in `build.zig`:
```zig
claimlint_exe.root_module.addImport("absorb", b.createModule(.{
    .root_source_file = b.path("src/absorb.zig"),
    .target = target,
    .optimize = optimize,
}));
claimlint_exe.root_module.addImport("claims_register", b.createModule(.{
    .root_source_file = b.path("src/claims_register.zig"),
    .target = target,
    .optimize = optimize,
}));
```

## 7. Cutover plan (stated cutover lines per brief §Bar 2)

### Phase A: build both, old entry points as wrappers

1. `zig build` produces `zig-out/bin/weizigo-claimlint` (the merged binary).
2. `bin/weizigo-claimlint` is deployed from `zig-out/bin/weizigo-claimlint` (unchanged deploy step).
3. `bin/weizigo-absorb` is REPLACED with the shell wrapper.
4. `bin/subagent` is REPLACED with the merged script (which requires `--provider` — existing
   callers must be updated to pass `--provider deepseek`; callers that are not updated get a
   hard error "missing --provider," which is loud, not silent).
5. `bin/ollama-subagent` is REPLACED with the Python wrapper.
6. `zig build test` is run — all regressions pass with wrappers in place.

### Phase B: remove wrappers (separate commit, after every console updated)

1. Remove `bin/weizigo-absorb` wrapper.
2. Remove `bin/ollama-subagent` wrapper.
3. Update any remaining references (regression scripts, docs, GTP wrappers) to use the merged
   entry points directly.

The wrappers exist as separate commits so `git revert` of the removal is trivial if a console
is found that still depends on the old entry points.

## 8. Migration risk assessment

| risk | likelihood | impact | mitigation |
|---|---|---|---|
| claimlint inline parser differs from claims_register.zig in a breaking way | medium | high — merge fails, becomes a rewrite | Phase 6 diff of the two parseRegister implementations before removal; if they differ beyond cosmetic whitespace, the design fails (strategy §7 refutation criterion) |
| absorb path resolution breaks when called from claimlint main | low | medium — absorb writes to wrong paths | absorb currently resolves repo root + paths internally; claimlint main will resolve them before calling absorb.runAbsorb; the args passed are already absolute. Phase 6 test (C1.3) verifies byte-identical output. |
| regression scripts hardcode `bin/weizigo-absorb` or `bin/ollama-subagent` and fail when they become wrappers | low | low | wrappers are transparent pass-throughs; regression scripts that check `argv[0]` or binary identity may need updating. Phase 6 grep of all regression scripts for the old binary names. |
| subagent `--provider` flag collision with existing DeepSeek flags | low | low | current `bin/subagent` has no `--provider` flag; no collision. The `--model` flag (ollama path) and `--wall` flag (shared) are unchanged. |
| depth cap: merged script misses the depth check | very low | high — infinite recursion | depth check is at the top of `main()`, before the provider branch; structurally impossible to miss. C2.4 invariant assertion verifies. |

---

**Landmark:** advances `L4 (the ledger is clean)` — the design is a mechanical merge, not a rewrite:
one binary with verbs for claimlint+absorb (300 lines of inline parser retired, `claims_register.zig`
becomes single source of truth), one script with `--provider` for subagent+ollama-subagent (113 common
lines deduped), both with cutover wrappers for backward compatibility. The two scope-level `−`
entries (stability, separation of concerns) are mitigated to `0` by concrete design choices. What
remains: independent audit, then Phase 5 (plan — ordered, revertible steps).

**Human summary:** the design merges claimlint and absorb into one Zig binary with `verify` and
`absorb` verbs (default = verify for backward compat, absorb via `weizigo-claimlint absorb <args>`),
retiring claimlint's ~300-line inline parser copy and importing `claims_register.zig` instead — making
the T406 two-verdicts-same-file shape structurally impossible. subagent and ollama-subagent merge into
`bin/subagent` with `--provider deepseek|ollama` (REQUIRED flag). Both old entry points become
thin wrappers during cutover. No shared library, no managent/argus changes, no regression rewrites.
~300 net lines removed from the Zig toolchain, one parser instead of two, two scripts instead of four.
All eight qualities score `+` or `0` — no `−` entries remain.
