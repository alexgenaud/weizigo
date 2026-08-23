# T428 · Phase 8 — Accept: ruling — shipped / partial / abandoned

| | |
|---|---|
| Sprint | T428 (tool consolidation), set S |
| Phase | 8 of 8 — **accept** |
| Writer | deepseek-v4-pro/T428.2 (original), deepseek-v4-flash/T527 (final ruling 2026-08-23) |
| Date | 2026-08-23 (final) |
| Status | FINAL — **SHIPPED** |

---

## 1. Ruling: SHIPPED

The original Phase 8 ruling was PARTIAL — documents shipped, code deferred. The code has now
been implemented (T437/T440/T482/T527), the 22-test acceptance suite executed with every
RED-first control shown RED then GREEN, and the cutover wrappers removed. **The consolidation
is shipped.**

| phase | document | audit row | verdict |
|---|---|---|---|
| 1 — strategy | `01-strategy.md` | T429 (glm-5.2) | PASS WITH FINDINGS |
| 2 — scope | `02-scope.md` | T433 (glm-5.2) | PASS WITH FINDINGS |
| 3 — acceptance | `03-acceptance.md` | T434 (glm-5.2) | PASS WITH FINDINGS |
| 4 — design | `04-design.md` | T435 (FAIL) → T436 (PASS WITH FINDINGS, r2 ×2) | PASS WITH FINDINGS |
| 5 — plan | `05-plan.md` | audited via T436 r2 §7 | PASS WITH FINDINGS |
| 6 — build | `06-build.md` | — | EXECUTED (T437/T440/T482/T527) |
| 7 — test | `07-test.md` | — | EXECUTED (T527) |
| 8 — accept | this document | — | SHIPPED (T527) |

## 2. What shipped

- **One Zig binary with verbs:** `weizigo-claimlint verify|absorb|c7` — default verb `verify`
  (backward compatible), `absorb <findings.json> [--dry-run]`, `c7 [--json]`. `weizigo-absorb`
  no longer exists as a separate binary or entry point.
- **One register parser:** `claims_register.zig` is the single source of truth; claimlint's
  ~300-line inline copy was retired. The T406 shape — same file, two Zig verdicts, no alarm —
  is structurally impossible: both verbs call `cr.parseRegister()`.
- **One subagent script:** `bin/subagent --provider deepseek|ollama|claude` (REQUIRED flag);
  `bin/ollama-subagent` and `bin/subagent-ds` removed.
- **Wrappers:** deployed during cutover, removed in Phase B. Nothing replaced without the old
  entry point working first (T440 verified the wrappers; regressions migrated before removal).
- **Two acceptance gaps closed by T527 at HEAD:** `verify --help`/`absorb --help` now print
  usage (C1.1, NF4); `verify` on a 0-row register fails hard naming the empty parse on stderr
  (C1.9). Plus the subagent file-branch prompt restored to pre-merge bytes (C2.2/C2.3) and the
  claimlint-promotion regression re-pointed after the T557 path move.

## 3. Acceptance summary (full detail in `07-test.md`)

22/22 tests pass after the T527 fixes; every RED-first control was shown RED before its fix:

- **C1.x (claimlint+absorb):** 9/9 — one binary two verbs, byte-identical verify and absorb
  outputs, single Zig parser, header corrected, stdout/stderr contract, cutover wrapper,
  no-silent-success hard error.
- **C2.x (subagent pair):** 7/7 — REQUIRED `--provider`, byte-identical provider behavior,
  depth cap preserved, dispatch verification both paths, 3(+2) scripts green, cutover wrapper.
- **C3.x (cross-cutting):** 5/5 — union of suites met (9 ≥ 8 scripts), suite time reported
  (fleet suite grew via unrelated rows; consolidated tool suites unchanged), no live-store
  incident, help lists all verbs/providers, build.zig targets removed.

## 4. What remains (fleet debt, NOT consolidation blockers)

Six pre-existing suite reds at clean HEAD, itemized in `07-test.md` §5 and
`findings/T527-t428-console.json`: argus stale hardcoded floor (C1a 10 / C2 12 vs committed
0 / 13), argus/deploy staleness arms (environmental; remedy blocked by T716's uncommitted
lanes work), managent `cmdAgent` segfault on model-less rows, store-pollution clean-lane
arm, directive-kill T616 misclassification, race-p0 path drift, runner-host-guard
(expected-red until T711). None touch the consolidated toolchain.

## 5. The eight qualities — final score (unchanged from Phase 8 original)

| quality | claimlint+absorb | subagent pair | combined |
|---|---|---|---|
| reuse | `+` — one parser, ~300 lines retired | `+` — common scaffold deduped | `+` |
| testability | `+` — union of suites, one build target | `+` — one file to test | `+` |
| predictability | `+` — default=verify, explicit absorb | `+` — REQUIRED --provider | `+` |
| transparency | `+` — one help screen | `+` — one help screen, both providers | `+` |
| stability | `0` — wrappers bridged the cutover, then removed by stated Phase B | `0` — same | `0` |
| agility | `+` — one parser fix, one build | `+` — one dispatch file | `+` |
| performance | `+` — one build, one deploy | `+` — one Python parse | `+` |
| separation of concerns | `0` — structural verb boundary, overlapping exit codes, no shared state | `0` — provider flag separates mechanism from policy | `0` |

No `−` entries.

---

**Landmark:** advances `L4 (the ledger is clean)` — the tool consolidation is shipped: the
T406 silent-divergence shape is structurally impossible (one register parser), the 
claimlint+absorb and subagent+ollama merges are live at HEAD, all 22 acceptance tests pass,
and the cutover wrappers are gone. What remains is unrelated fleet debt, itemized for the
Orchestrator.

**Human summary:** the consolidation the T428 sprint designed is now shipped and tested. One
Zig binary (`weizigo-claimlint verify|absorb|c7`) replaces claimlint + absorb with a single
shared register parser; one `bin/subagent --provider …` replaces subagent +
ollama-subagent. All 22 acceptance tests pass — including the three gaps the acceptance run
found and fixed at HEAD (help verb handling, the verify-side empty-register hard error, and
an over-escaped subagent prompt). The cutover wrappers were deployed, verified, and removed.
Six unrelated fleet-suite failures (argus stale floor, a managent segfault, race-p0 path
drift, etc.) are documented as pre-existing debt for separate repair rows.
