# T428 · Phase 5 — Plan: ordered, revertible steps with migration risk

| | |
|---|---|
| Sprint | T428 (tool consolidation), set S |
| Phase | 5 of 8 — **plan** |
| Writer | deepseek-v4-pro/T428.2 |
| Date | 2026-08-08 |
| Commit | `3beda47` (HEAD, Phase 4 fix) |
| Audit | pending |
| Status | PROPOSED — awaits independent audit before Phase 6 begins |

**Phase 4 re-audit findings reconciled.** NF1 (stale "separate exit-code ranges" in §2.2 closing) —
fixed in this plan's step 1. NF2 (subagent wrapper inconsistency) — resolved in step 5: the
`bin/subagent` cutover wrapper is a real deployable artifact. NF3 (C1.1 tension) — resolved in step
2: the verb dispatch checks `--help`/`help`/`-h` before treating non-verbs as paths.

---

## 1. Ordering principle

Every step is independently revertible via `git revert`. No step depends on a prior step's side
effects being live — each commit compiles and passes `zig build test` on its own. The cutover
wrappers are deployed in step 6 (Phase A) and removed in step 8 (Phase B); between them, every
console can update at its own pace.

## 2. Steps

### Step 1: wording patch — NF1, stale exit-code phrase

**File:** `src/claimlint.zig` (verb dispatch comment — or `04-design.md` if the phrase is in the
design doc). Fix: drop "separate exit-code ranges" from §2.2 closing sentence.

**Revert:** `git revert <commit>` — one comment line.

### Step 2: verb dispatch — C1.1 fix + NF3 resolution

**File:** `src/claimlint.zig` main().

Add verb dispatch between the version banner and the existing verify logic:
- If argv[1] is `absorb` → call `absorb.runAbsorb()`
- If argv[1] is `help`/`--help`/`-h` → print help listing both verbs
- If argv[1] is a path that exists → run `verify` on it (backward compat)
- If argv[1] is neither a recognized verb nor an existing path → error: "unknown verb <arg>" (satisfying C1.1 RED-first control)
- No argv[1] → run `verify` with no path (backward compat)

This resolves NF3: the C1.1 control (`no-such-verb` → "unknown verb") is satisfied; existing
paths still work unchanged.

**Revert:** `git revert <commit>` restores the old no-verb main().

### Step 3: parser retirement — import claims_register, remove inline copy

**Files:** `src/claimlint.zig`, `src/claims_register.zig`, `build.zig`.

1. Fix `src/claims_register.zig` line 21 header: "Used by claimlint (checker) and absorb" →
   "Used by claimlint (verify and absorb verbs) — imported by src/claimlint.zig".
2. Add `const cr = @import("claims_register.zig");` to `src/claimlint.zig`.
3. Remove inline functions: `Register` struct, `parseStatus`, `parseNarrowed`, `parseRate`,
   `backtickSpans`, `parseRegister`, `isClaimIdToken`, `claimIdOf`, `isQaId` (~300 lines).
4. Replace all call sites with `cr.<function>(...)`.
5. Add `claims_register` as a module import in `build.zig` for `claimlint_exe`.

**Pre-removal guard:** diff the two `parseRegister` implementations before removal. If they differ
beyond cosmetic whitespace, STOP — the merge is a rewrite (strategy §7 refutation criterion) and
the sprint ends with `08-accept.md` documenting "we should not consolidate."

**Revert:** `git revert <commit>` restores the inline parser and removes the import.

### Step 4: absorb module — expose runAbsorb, wire into claimlint

**Files:** `src/absorb.zig`, `src/claimlint.zig`, `build.zig`.

1. Rename `main()` → `pub fn runAbsorb(io: Io, gpa: Allocator, args: [][]const u8) !void`.
2. Remove the version banner from runAbsorb (claimlint main prints it).
3. Remove `findRepoRoot` and path-resolution from runAbsorb (claimlint main resolves paths).
4. Add `absorb` as a module import in `build.zig` for `claimlint_exe`.
5. Wire the verb dispatch in claimlint main: `absorb` → `absorb.runAbsorb(io, gpa, remaining_args)`.

**Revert:** `git revert <commit>` restores absorb as a standalone binary.

### Step 5: subagent merge — one script with REQUIRED --provider

**File:** `bin/subagent` (rewritten; old `bin/subagent` saved as `bin/subagent.old` for reference).

Merge `bin/subagent` and `bin/ollama-subagent` into one script:
1. Shared scaffold: depth check, nonce generation, dispatch_verify, argument parsing.
2. `--provider deepseek` → DeepSeek dispatch path.
3. `--provider ollama` → Ollama dispatch path (requires `--model`).
4. Missing `--provider` → error: "missing --provider (deepseek|ollama)".
5. Unknown provider → error.

**Revert:** `git revert <commit>`; `bin/subagent.old` exists as a fallback.

### Step 6: Phase A cutover — wrappers deployed, build.zig updated

**Files:** `build.zig`, `bin/weizigo-absorb`, `bin/ollama-subagent`, `bin/subagent-ds` (new).

1. **build.zig:** remove `absorb_exe` and `absorb_deploy` targets. Keep `claimlint_exe` with
   `absorb` and `claims_register` modules. Remove `weizigo-absorb` from deploy.
2. **`bin/weizigo-absorb`** → shell wrapper:
   ```sh
   #!/bin/sh
   echo "weizigo-absorb: use weizigo-claimlint absorb" >&2
   exec bin/weizigo-claimlint absorb "$@"
   ```
3. **`bin/ollama-subagent`** → Python wrapper:
   ```python
   #!/usr/bin/env python3
   import subprocess, sys
   sys.stderr.write("ollama-subagent: use bin/subagent --provider ollama\n")
   sys.exit(subprocess.call([sys.executable, "bin/subagent", "--provider", "ollama"] + sys.argv[1:]))
   ```
4. **`bin/subagent-ds`** → NEW Python wrapper for backward compat (NF2 resolution):
   ```python
   #!/usr/bin/env python3
   import subprocess, sys
   sys.exit(subprocess.call([sys.executable, "bin/subagent", "--provider", "deepseek"] + sys.argv[1:]))
   ```
   This is the "bin/subagent cutover wrapper" the design references. Old scripts that called
   `bin/subagent` expecting DeepSeek are updated to call `bin/subagent-ds` during cutover, or
   pass `--provider deepseek` to the new `bin/subagent`.

5. **Run `zig build test`** — all regressions green with wrappers in place.

**Revert:** `git revert <commit>` restores old build.zig and old entry points.

### Step 7: test — run acceptance suite (Phase 7)

Run all 22 acceptance tests from `03-acceptance.md`. Show every RED control RED first, then
GREEN after the fix. Report exact before/after control counts. Verify `tasks.json` byte-identical.

**Revert:** N/A — this is a test run, not a code change.

### Step 8: Phase B cutover — remove wrappers (separate commit)

**Files:** `bin/weizigo-absorb`, `bin/ollama-subagent`, `bin/subagent-ds` — REMOVED.

Update any remaining references in regression scripts and docs to use merged entry points directly.

**Revert:** `git revert <commit>` restores wrappers.

---

## 3. Step dependency graph

```
Step 1 (wording) ──┐
                   ├── Step 2 (verb dispatch) ── Step 3 (parser) ── Step 4 (absorb module)
                   │                                                      │
                   └── Step 5 (subagent merge) ───────────────────────────┤
                                                                          │
                          Step 6 (cutover wrappers) ←─────────────────────┘
                                   │
                          Step 7 (test — Phase 7)
                                   │
                          Step 8 (remove wrappers)
```

Steps 1-4 (claimlint+absorb) and step 5 (subagent merge) are independent — they can be done in
either order. Steps 1 and 2 must precede 3 and 4. Step 6 depends on both 2-4 and 5. Step 7 runs
after 6. Step 8 is a separate commit after 7.

## 4. Migration risk

| risk | step | mitigation |
|---|---|---|
| parseRegister diff breaks the merge | 3 | pre-removal diff; if substantive differences, STOP (strategy §7) |
| absorb path resolution breaks | 4 | claimlint main resolves paths before calling runAbsorb; C1.3 verifies byte-identical output |
| regression scripts hardcode old binary names | 6 | Phase A wrappers are transparent pass-throughs; grep for old names in step 7 |
| subagent --provider collides with existing flags | 5 | current subagent has no --provider flag; no collision |
| depth cap missed in merged subagent | 5 | depth check at top of main(), before provider branch; C2.4 invariant assertion |
| live-store incident (T425) | 6, 7 | MANAGENT_STORE for all exercises; sha256sum tasks.json before/after |

## 5. Estimated effort

| step | files changed | estimated lines | risk |
|---|---|---|---|
| 1 — wording | 1 | 1 | trivial |
| 2 — verb dispatch | 1 | ~25 | low |
| 3 — parser retirement | 2-3 | ~300 removed, ~20 added | **medium** — the diff gate |
| 4 — absorb module | 2 | ~30 removed, ~15 added | low |
| 5 — subagent merge | 1 (rewrite) | ~220 removed, ~290 added | low |
| 6 — cutover wrappers | 4 | ~40 | low |
| 7 — test | 0 (run only) | 0 | **medium** — acceptance suite |
| 8 — remove wrappers | 3 | ~40 removed | trivial |

---

**Landmark:** advances `L4 (the ledger is clean)` — the plan orders 8 independently revertible
steps, resolves NF1/NF2/NF3 from the Phase 4 re-audit, and gates the highest-risk step (parser
retirement) on a pre-removal diff. What remains: independent audit, then Phase 6 (build).

**Human summary:** the plan has 8 steps: a wording patch (NF1), verb dispatch with C1.1 fix (NF3),
parser retirement with pre-removal diff gate, absorb module wiring, subagent merge with REQUIRED
`--provider`, Phase A cutover wrappers (including `bin/subagent-ds` for NF2 resolution), acceptance
suite run, and Phase B wrapper removal. Steps 1-4 for claimlint+absorb and step 5 for subagent are
independent. Every step is a single `git revert` from undone.
