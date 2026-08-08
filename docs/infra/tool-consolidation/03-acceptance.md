# T428 · Phase 3 — Acceptance: the tests that must pass, written BEFORE any design

| | |
|---|---|
| Sprint | T428 (tool consolidation), set S |
| Phase | 3 of 8 — **acceptance** |
| Writer | deepseek-v4-pro/T428.2 |
| Date | 2026-08-08 |
| Commit measured at | `4134980` (HEAD, "T428 Phase 2: fix audit findings F1-F5") |
| Audit | pending — row to be registered and dispatched |
| Status | PROPOSED — awaits independent audit before Phase 4 begins |

**Phase 3 before Phase 4 is deliberate and not negotiable.** These tests are written against the
*requirements* (the scope decisions of Phase 2), not against any design. A test that passes only
after the design is chosen tests the design, not the requirement. Every control below must be shown
RED in Phase 7 before the fix that makes it green.

---

## 0. Pre-existing regression suites — the union bar

The brief mandates: *"Every tool touched keeps its regressions green, and any merged tool inherits
the union of both test suites — not a rewritten subset. Report the test count before and after."*

Baseline (committed trees at `9a96f8b`):

| tool | regression scripts | controls within (grep for `echo "PASS\|echo "FAIL\|exit_code\|assert`) |
|---|---|---|
| `weizigo-claimlint` | 3 (`claimlint-output`, `claimlint-promotion`, `claimlint-volatile`) | TBD in Phase 7 (precise control count from the scripts) |
| `weizigo-absorb` | 1 (`absorption-machinery`) | TBD |
| `subagent` | 1 (`subagent-prompt`) | TBD |
| `ollama-subagent` | 2 (`ollama-dispatcher`, + shared `dispatch-verification`, `depth-enforcement`) | TBD |
| **shared** | 2 (`dispatch-verification`, `depth-enforcement`) | TBD |

**Acceptance criterion A0 (union bar):** The merged tool's regression suite count ≥ the sum of the
individual suites. No control removed unless it tests a retired entry point (e.g., a test that
explicitly checks `bin/ollama-subagent` exists → becomes a test that `bin/subagent --provider ollama`
works). The Phase 7 `07-test.md` must report exact before/after control counts and state which
controls were retired and why.

---

## 1. claimlint + absorb merge — acceptance tests

### C1.1 — One binary, two verbs

The merged binary `bin/weizigo-claimlint` supports subcommand verbs `verify` and `absorb`.

**Positive control (RED first):** `bin/weizigo-claimlint no-such-verb` → exit code ≠ 0, stderr
names the unknown verb.

**Acceptance:** `bin/weizigo-claimlint verify --help` and `bin/weizigo-claimlint absorb --help`
both exit 0 and print usage. `bin/weizigo-claimlint --help` lists both verbs.

### C1.2 — `verify` produces byte-identical output to old `weizigo-claimlint`

Run the old binary and the merged binary's `verify` verb against an identical CLAIMS.md +
findings/ tree. Output (stdout) is byte-identical. Exit code matches.

**RED first:** pre-merge, the old binary and the merged binary's output differ (different builds,
different timestamps in version strings — the control must strip or normalize version lines, or
else the RED test confirms they *can* differ and the GREEN test confirms they match after
normalization).

**Acceptance:** `diff <(old-claimlint) <(merged verify)` is empty after stripping version/built-at
lines. Exit codes match.

### C1.3 — `absorb` produces byte-identical side effects to old `weizigo-absorb`

Run the old binary and the merged binary's `absorb` verb against an identical CLAIMS.md +
findings/ tree. The CLAIMS.md modifications produced are byte-identical. Exit code matches.

**RED first:** with different CLAIMS.md copies, outputs differ. With identical inputs after
normalization, they match.

**Acceptance:** `diff <(old-absorb CLAIMS.md findings/) <(merged absorb CLAIMS.md findings/)` is
empty. CLAIMS.md modified identically.

### C1.4 — All 4 regression scripts pass against merged binary

The 3 claimlint scripts + 1 absorption-machinery script = 4 scripts. All pass when pointed at
the merged binary.

**Acceptance:** `zig build test` is green with all 4 scripts passing. No script SKIPs because
the binary name changed (scripts that hardcode `bin/weizigo-claimlint` must still resolve).

### C1.5 — `claims_register.zig` is the single Zig parser

After merge, `src/claimlint.zig` no longer contains an inline copy of `parseRegister`,
`parseStatus`, `parseNarrowed`, `parseRate`, `backtickSpans`, `claimIdOf`, `isQaId`, or the
`Register` struct. It imports `claims_register.zig` instead.

**RED first:** pre-merge, `grep -c 'fn parseRegister' src/claimlint.zig` returns 1.

**Acceptance:** post-merge, `grep -c 'fn parseRegister' src/claimlint.zig` returns 0 AND
`grep '@import.*claims_register' src/claimlint.zig` returns a match.

### C1.6 — `claims_register.zig` header corrected

The stale header at line 21 ("Used by claimlint (checker) and absorb (knowledge-capture tool)")
is updated to reflect the actual topology: claimlint now imports it.

**Acceptance:** `git show HEAD:src/claims_register.zig | head -25` shows updated header.

### C1.7 — stdout/stderr contract

Both verbs satisfy: `2>/dev/null` emits data on stdout when there are results; `1>/dev/null` is
silent when there are no errors (diagnostics only on stderr).

**Acceptance:** `bin/weizigo-claimlint verify CLAIMS.md 2>/dev/null | head -1` is non-empty;
`bin/weizigo-claimlint verify CLAIMS.md 1>/dev/null` is empty or stderr-only.

### C1.8 — Cutover: old `bin/weizigo-absorb` still works during transition

During the transition, `bin/weizigo-absorb` is a thin wrapper that calls
`bin/weizigo-claimlint absorb "$@"` and emits a deprecation notice on stderr.

**RED first:** before wrapper deployment, `bin/weizigo-absorb` is the old binary (and works).

**Acceptance:** `bin/weizigo-absorb` calls `bin/weizigo-claimlint absorb` with the same
arguments, emits deprecation warning on stderr, and produces identical result to the old
binary on the same input.

### C1.9 — No silent success (the P3 attack)

The defect shape "reports success while doing nothing" must be structurally impossible after merge.
Specifically: if the register parser returns 0 rows, both verbs fail hard with a non-zero exit code
and a message on stderr naming the empty parse.

**Acceptance:** run the merged binary against a CLAIMS.md with 0 recognizable rows. Exit code ≠ 0.
stderr contains "empty" or "no rows" or "0 rows".

---

## 2. subagent + ollama-subagent merge — acceptance tests

### C2.1 — One script, `--provider` flag

`bin/subagent --provider deepseek` dispatches via DeepSeek; `bin/subagent --provider ollama`
dispatches via Ollama. No flag or an unknown provider is a hard error.

**RED first:** `bin/subagent` without `--provider` → exit code ≠ 0, stderr says "provider".

**Acceptance:** `bin/subagent --provider deepseek --dry-run T123` prints the DeepSeek command.
`bin/subagent --provider ollama --dry-run T123` prints the Ollama command. `bin/subagent --provider xyz` → exit ≠ 0.

### C2.2 — `--provider deepseek` matches old `bin/subagent` behavior

The DeepSeek path in the merged script is byte-identical in behavior to the old script: same
environment variables read, same API endpoint, same prompt construction.

**Acceptance:** old `bin/subagent --dry-run T123` output matches merged
`bin/subagent --provider deepseek --dry-run T123` after normalizing version/built-at lines.

### C2.3 — `--provider ollama` matches old `bin/ollama-subagent` behavior

**Acceptance:** old `bin/ollama-subagent --dry-run T123` output matches merged
`bin/subagent --provider ollama --dry-run T123` after normalizing.

### C2.4 — Depth cap preserved (MAX_DEPTH = 3 for both paths)

Both provider paths increment `WEIZIGO_AGENT_DEPTH` and refuse at MAX_DEPTH = 3.

**RED first:** set `WEIZIGO_AGENT_DEPTH=3`, run `bin/subagent --provider ollama --dry-run T123`
→ exit ≠ 0, stderr says "REFUSED" or "delegation cap".

**Acceptance:** both paths refuse at depth 3, accept at depth 2. The refusal message names the
provider.

### C2.5 — `dispatch_verify.py` still called for both paths

After worker completion, both provider paths call `dispatch_verify.verify_dispatch()` with the
nonce, stdout, and deliverables.

**Acceptance:** dispatch verification checks (nonce in stdout, deliverables exist, kanban state)
fire for both `--provider deepseek` and `--provider ollama`. A worker that replies "OK." without
the nonce fails verification for both providers.

### C2.6 — All 3(+2 shared) regression scripts pass against merged script

The subagent-prompt + ollama-dispatcher + shared dispatch-verification + shared depth-enforcement
scripts all pass when pointed at the merged script.

**Acceptance:** `zig build test` is green with all scripts passing.

### C2.7 — Cutover: old `bin/ollama-subagent` still works during transition

Same as C1.8: `bin/ollama-subagent` becomes a thin wrapper calling
`bin/subagent --provider ollama "$@"` with a deprecation notice.

**Acceptance:** wrapper passes through arguments, emits deprecation on stderr, identical result.

---

## 3. Cross-cutting acceptance tests

### C3.1 — Regressions green at every commit

`zig build test` is green at every commit in the sprint. No commit is pushed with a red suite.

**Acceptance:** Phase 7's `07-test.md` lists every commit with suite status.

### C3.2 — Suite time does not regress beyond 2× baseline

Baseline suite time is ~609.7 s (T406 measurement). The merged tool suite time must not exceed
~1,200 s (2×) after consolidation. Performance is one of the eight qualities; a regression here
is a `−` on the performance row.

**Acceptance:** Phase 7 reports wall-clock time for full `zig build test` and compares to baseline.

### C3.3 — No live-store incident (T425 prevention)

Every exercise uses `MANAGENT_STORE`. Before and after every exercise, `tasks.json` is verified
byte-identical.

**Acceptance:** Phase 7 includes a `sha256sum` of `docs/infra/managent/tasks.json` before and
after the test run. The two hashes match.

### C3.4 — Help text lists all verbs/providers

Running the merged binary with no arguments or `--help` lists all available subcommands/providers.

**Acceptance:** `bin/weizigo-claimlint --help` mentions `verify` and `absorb`.
`bin/subagent --help` mentions `--provider deepseek` and `--provider ollama`.

### C3.5 — build.zig updated, old build targets removed or aliased

`zig build` no longer produces `weizigo-absorb` as a separate binary. `zig build` produces the
merged `weizigo-claimlint` and `bin/subagent`. Deploy steps are updated.

**Acceptance:** `ls zig-out/bin/weizigo-absorb` does not exist (or is a symlink to
weizigo-claimlint). `ls zig-out/bin/weizigo-claimlint` exists.

---

## 4. Test summary

| # | test | RED-first control | acceptance gate |
|---|---|---|---|
| A0 | union of suites | — | merged suite count ≥ sum of individual suites |
| C1.1 | one binary, two verbs | unknown verb → error | help lists verify + absorb |
| C1.2 | verify byte-identical | old vs merged differ (version) | diff empty after normalization |
| C1.3 | absorb byte-identical | old vs merged differ | diff empty after normalization |
| C1.4 | 4 regression scripts pass | pre-merge each passes | all 4 pass against merged binary |
| C1.5 | single Zig parser | grep finds inline parseRegister | inline copy gone; import present |
| C1.6 | stale header corrected | header says "Used by claimlint" | header accurate |
| C1.7 | stdout/stderr contract | — | 2>/dev/null data, 1>/dev/null silent |
| C1.8 | absorb wrapper during cutover | old binary works | wrapper calls merged, deprecates |
| C1.9 | no silent success | — | empty register → hard error |
| C2.1 | --provider flag | missing → error | both providers work |
| C2.2 | deepseek matches old | old/new differ | diff empty after normalization |
| C2.3 | ollama matches old | old/new differ | diff empty after normalization |
| C2.4 | depth cap | depth=3 → REFUSED | both paths refuse at 3 |
| C2.5 | dispatch_verify called | — | nonce check fires for both |
| C2.6 | 3(+2) regression scripts pass | pre-merge each passes | all pass against merged script |
| C2.7 | ollama wrapper during cutover | old script works | wrapper passes through, deprecates |
| C3.1 | regressions green every commit | — | every commit green |
| C3.2 | suite time ≤ 2× baseline | — | wall clock reported, ≤ ~1200 s |
| C3.3 | no live-store incident | — | tasks.json hash unchanged |
| C3.4 | help lists all verbs/providers | — | --help complete |
| C3.5 | build.zig updated | — | old targets gone or aliased |

**Total: 22 acceptance tests.** A0 is the union-of-suites bar; C1.1–C1.9 cover the
claimlint+absorb merge; C2.1–C2.7 cover the subagent pair merge; C3.1–C3.5 cover cross-cutting
concerns.

---

## 5. What Phase 7 must show

Phase 7 (`07-test.md`) must report, for every test above:

1. The RED control result (command, exit code, key output line).
2. The GREEN acceptance result (command, exit code, key output line).
3. The commit at which GREEN was first observed.
4. Whether a regression script was added or an existing one was reused.

Tests marked "RED-first" above must be shown RED *before* the fix in the Phase 7 report. Tests
marked "—" are specifications that need no RED control (they are pass/fail properties of the
shipped artifact).

---

**Landmark:** advances `L4 (the ledger is clean)` — Phase 3 freezes the acceptance tests before
any design, so Phase 4 cannot be tested against itself. What remains: an independent audit of
this document, then Phase 4 (design) with the tests as the gate.

**Human summary:** 22 acceptance tests written before design — 9 for the claimlint+absorb merge
(one binary with verify/absorb verbs, byte-identical outputs, one Zig parser, no silent success,
cutover wrapper), 7 for the subagent pair merge (--provider flag, behavior match, depth cap,
dispatch verification, cutover wrapper), and 5 cross-cutting (regressions green, suite time
bounded, no live-store incidents, help text, build.zig updated). Every RED-first control is named;
Phase 7 must show each RED before the fix. Phase 4 design must satisfy every test here or argue
why the test should be retired — the tests are not negotiable, but the retirement of a
specifically-named test after argued review is.
