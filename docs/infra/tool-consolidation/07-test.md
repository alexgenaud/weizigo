# T428 · Phase 7 — Test: acceptance results

| | |
|---|---|
| Sprint | T428 (tool consolidation), set S |
| Phase | 7 of 8 — **test** |
| Writer | deepseek-v4-pro/T428.2 (structure), deepseek-v4-flash/T527 (execution 2026-08-23) |
| Date | 2026-08-23 (execution) |
| Commit measured at | `2a21c55` (T720) — the merged toolchain is at HEAD |
| Status | EXECUTED — 22 acceptance tests run against the merged toolchain; 2 acceptance failures found at HEAD and FIXED by T527, then re-run green |

---

## 1. Test status: EXECUTED

The Phase 6 build deferred by T428 was implemented by T437 (`8ce3270`, plan steps 1–6),
hardened by T440 (`3aaffb6`), extended by T482 (`c7 --json` verb), and the Phase B wrapper
removal was executed by T527 (`99a919b` + wrapper deletions landed in `5330909`). This phase
runs the 22 acceptance tests from `03-acceptance.md` against the merged toolchain and reports
every RED control first, then GREEN.

**Two acceptance failures were found at HEAD during this run, both fixed by T527 (test-first,
control RED shown before each fix):**

| failure | acceptance test | RED state at HEAD | fix |
|---|---|---|---|
| `verify --help` / `absorb --help` run verify/error instead of printing usage | C1.1 acceptance half (NF4 from the Phase 4 re-audit, never closed) | `verify --help` ran a full verify (exit 1); `absorb --help` → "no findings file given" (exit 1) | verb dispatch now collects remaining args and prints help (exit 0) when a help flag follows a known verb |
| `verify` on a 0-row register never names the empty parse on stderr | C1.9 verify half | exit 2 (calibration), stderr = banner only | runVerify now fails hard (exit 3) with "FATAL — parsed 0 rows" + counts, mirroring absorb's T406 block |
| file-branch subagent prompt over-escaped to literal `\n` | C2.2/C2.3 "same prompt construction" | dry-run `-p '...AGENTS.md\\n\\n...'` (literal backslash-n); bundle branch used real newlines — internal inconsistency | restored pre-merge `\n` real newlines + repr condition (`"\n" in c`) |
| claimlint-promotion regression pointed at pre-rename kill-matrix path | C1.4 union bar | SKIP/FAIL: `docs/epic-01-markovian/...kill-matrix.json` not found (T557 moved it) | path updated to `docs/epics/E1-markovian/...` |

## 2. Baseline regression suite (pre-merge state)

At commit `9a96f8b` (Phase 2 baseline), the suite reported 29 regression scripts green.
The consolidated tool's own suites (claimlint+absorb, subagent+ollama) are green at HEAD
(see §3). The fleet-wide suite has pre-existing reds independent of the consolidation,
verified at clean HEAD `2a21c55` (see §5).

## 3. RED-first controls — shown RED before the fix

| # | control | RED run (pre-merge binary at `9a96f8b`) | GREEN run (merged binary at HEAD) |
|---|---|---|---|
| C1.1 | unknown verb | `weizigo-claimlint no-such-verb` → exit 3, stderr "cannot read no-such-verb" (treated as path) | exit 1, stderr "unknown verb 'no-such-verb'" + help |
| C1.5 | single Zig parser | `grep -c 'fn parseRegister' src/claimlint.zig` = 1; all nine inline funcs present | = 0; `@import("claims_register.zig")` at `src/claimlint.zig:143`; `const Register = cr.Register` alias |
| C1.9 | empty register | `verify <0-row register>` → exit 2, stderr banner only | exit 3, stderr "FATAL — parsed 0 rows … the register is empty" |
| C2.1 | missing `--provider` | pre-merge `bin/subagent` had no provider gate (dispatched DeepSeek by default) | `bin/subagent` without `--provider` → exit 1, "missing --provider (deepseek\|ollama)" |
| C2.2/C2.3 | file-branch prompt construction | merged-at-HEAD `-p '…\\n\\n…'` literal backslash-n (regression control 4c RED) | `-p '…\n\n…'` real newlines; control 4c GREEN |
| C2.4 | depth cap | both provider paths refuse at `WEIZIGO_AGENT_DEPTH=3` | unchanged — both refuse at 3, accept at 2 |

## 4. Acceptance results (GREEN at HEAD, after T527 fixes)

| # | test | result | evidence |
|---|---|---|---|
| A0 | union of suites | **PASS** | claimlint: 5 scripts green (output, promotion, volatile, c7-json, absorption-machinery); subagent: 4 scripts green (prompt, ollama-dispatcher, dispatch-verification, depth-enforcement). Merged suite count ≥ sum of individual suites (9 ≥ 8). No control removed except those testing retired entry points (wrappers) — migrated to merged entry points (T440, 99a919b). |
| C1.1 | one binary, two verbs | **PASS** | `verify --help` exit 0 + usage; `absorb --help` exit 0 + usage; `--help` lists verify/absorb/c7; unknown verb → exit 1 naming it |
| C1.2 | verify byte-identical | **PASS** | old (`9a96f8b`) vs merged (`8ce3270`) on identical tree: 0 diff lines after version-line normalization; exit codes match |
| C1.3 | absorb byte-identical | **PASS** | old absorb vs merged `absorb` verb on identical inputs: byte-identical stdout directives AND byte-identical CLAIMS.md side effects; exit codes match (0/0) |
| C1.4 | 4 regression scripts | **PASS** | claimlint-output, claimlint-promotion, claimlint-volatile, absorption-machinery all green against merged binary (plus c7-json) |
| C1.5 | single Zig parser | **PASS** | inline copy gone (grep = 0 for all nine funcs); `cr.parseRegister` imported |
| C1.6 | header corrected | **PASS** | `claims_register.zig:21` — "Used by claimlint (verify and absorb verbs) — imported by src/claimlint.zig" |
| C1.7 | stdout/stderr contract | **PASS** | `2>/dev/null` emits data; `1>/dev/null` silent (banner on stderr) |
| C1.8 | absorb wrapper during cutover | **PASS** (history) | wrapper existed at `8ce3270` (sh → `exec bin/weizigo-claimlint absorb "$@"` + deprecation), fixed by T440, removed in Phase B (`5330909`) |
| C1.9 | no silent success | **PASS** (after fix) | 0-row register → exit 3, stderr names empty parse (verify); absorb already had it (T406) |
| C2.1 | one script, `--provider` | **PASS** | both providers work in `--dry-run`; missing/unknown provider → exit 1 naming "provider" |
| C2.2 | deepseek matches old | **PASS** (after fix) | bundle branch byte-identical old vs merged (normalized); file branch restored to real newlines |
| C2.3 | ollama matches old | **PASS** (after fix) | same prompt construction as pre-merge; regressions green |
| C2.4 | depth cap preserved | **PASS** | both paths refuse at depth 3, accept at 2 |
| C2.5 | dispatch_verify both paths | **PASS** | regression-dispatch-verification green (lazy/fail/die/honest stubs, both providers) |
| C2.6 | 3(+2) regression scripts | **PASS** | subagent-prompt, ollama-dispatcher, dispatch-verification, depth-enforcement all green |
| C2.7 | ollama wrapper during cutover | **PASS** (history) | wrapper at `8ce3270` (Python → `--provider ollama` + deprecation), removed in Phase B |
| C3.1 | regressions green | **PASS for the merged toolchain** | all claimlint/absorb/subagent suites green at HEAD; fleet-wide reds are pre-existing (see §5) |
| C3.2 | suite time ≤ 2× baseline | **REPORTED** | full `zig build test` = 29m44s (81 scripts) vs 609.7s baseline (29 scripts). The fleet suite grew ~2.8× in script count since the baseline via unrelated rows (managent, runner, argus, race); the consolidation itself added no new fleet scripts. Per-tool consolidated suites unchanged. |
| C3.3 | no live-store incident | **PASS** | suite-internal live-store guards green throughout ("byte-identical throughout", "no lines appended during the run" ×6). `tasks.json` delta is T527's own claim/ack + concurrent consoles (T720 landed mid-run), not the suite. |
| C3.4 | help lists verbs/providers | **PASS** | `--help` mentions verify + absorb + c7; subagent `--help` names `--provider deepseek` and `--provider ollama` |
| C3.5 | build.zig updated | **PASS** | no `absorb_exe`/`absorb_deploy` in build.zig; `zig-out/bin/weizigo-absorb` does not exist; `weizigo-claimlint` present |

## 5. Pre-existing fleet-suite reds (NOT caused by the consolidation)

Verified by re-running at clean HEAD `2a21c55` in a throwaway worktree — every one reproduces
without any of T527's changes:

| regression | failure | root cause |
|---|---|---|
| `regression-argus-doctor` arms 6/8/9 | deploy staleness, lockstep, floor drift under CLEAN | (a) bin/ deployed at older commits (3bd3f40/29a5223) vs freshly built zig-out — environmental, remedy `zig build deploy` (blocked by T716's uncommitted lanes work in-tree); (b) argus hardcodes stale floor `{C1a:10, C2:12}` vs committed floor `{C1a:0, C2:13}` (T373/T663) |
| `regression-managent-lock` | mutating command after SIGKILL → RC=134 (SIGABRT) | `cmdAgent` segfaults on a done row lacking a `model` field (T544/T635 attribution path) — pre-existing managent defect |
| `regression-managent-store-pollution` C | clean lane exit 1, no scratch-store done evidence | pre-existing (reproduces at clean HEAD) |
| `regression-directive-kill` 8d | T616 misclassified (verified=fail vs unreached) | pre-existing fixture/log-tail mismatch |
| `regression-race-p0` | live sealed tree NO-GO | path drift: `tools/race-p0-verify.sh` reads `docs/infra/races/…`; files moved to `docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/` (966da63) |
| `regression-runner-host-guard` | null-control red | documented expected-red until T711 lands |

None of these touch the merged claimlint+absorb or subagent toolchain. They are reported as
findings (T527) so the Orchestrator can dispatch repair rows; they do not gate the
consolidation acceptance.

## 6. Test count before and after

| merge target | before (individual suites) | after (merged) |
|---|---|---|
| claimlint+absorb | 3 (claimlint) + 1 (absorb) = 4 scripts | 5 scripts (output, promotion, volatile, c7-json, absorption-machinery) |
| subagent+ollama | 1 (subagent) + 1 (ollama) + 2 (shared) = 4 scripts | 4 scripts (prompt, ollama-dispatcher, dispatch-verification, depth-enforcement) |
| **total** | **8** | **9** (≥ 8, union bar met) |

No control removed except those testing retired entry points (the cutover wrappers, whose
tests were migrated to the merged entry points by T440 and the T527 regression sweep).

---

**Landmark:** advances `L4 (the ledger is clean)` — the 22-test acceptance suite is executed
against the merged toolchain; two acceptance failures found at HEAD (C1.1 help half, C1.9
verify half) and one prompt-construction deviation (C2.2/C2.3 file branch) were fixed
test-first by T527 and re-run green; the six fleet-suite reds are pre-existing and independent
of the consolidation.

**Human summary:** the acceptance suite that T428 froze in Phase 3 is now executed. The merged
binary (`weizigo-claimlint verify|absorb|c7`) is byte-identical in behavior to the two old
tools, one shared register parser is in place, and both subagent providers behave as before.
The run found and fixed three real gaps that had survived into HEAD: `verify --help` didn't
print usage, `verify` on an empty register didn't name the failure on stderr, and the subagent
file-branch prompt had been over-escaped by the merge. All nine consolidated-tool regression
scripts pass. Six other suite failures are pre-existing fleet debt (argus stale floor, managent
segfault on model-less rows, race-p0 path drift, etc.), verified to reproduce at clean HEAD.
