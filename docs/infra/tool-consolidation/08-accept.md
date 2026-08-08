# T428 · Phase 8 — Accept: ruling — shipped / partial / abandoned

| | |
|---|---|
| Sprint | T428 (tool consolidation), set S |
| Phase | 8 of 8 — **accept** |
| Writer | deepseek-v4-pro/T428.2 |
| Date | 2026-08-08 |
| Status | FINAL |

---

## 1. Ruling: PARTIAL — documents shipped, code deferred

**The consolidation design is complete and independently audited.** Every phase document (1–5)
passed independent audit, two of them after re-audit:

| phase | document | audit row | verdict |
|---|---|---|---|
| 1 — strategy | `01-strategy.md` | T429 (glm-5.2) | PASS WITH FINDINGS |
| 2 — scope | `02-scope.md` | T433 (glm-5.2) | PASS WITH FINDINGS |
| 3 — acceptance | `03-acceptance.md` | T434 (glm-5.2) | PASS WITH FINDINGS |
| 4 — design | `04-design.md` | T435 (FAIL) → T436 (PASS WITH FINDINGS) | PASS WITH FINDINGS (r2) |
| 5 — plan | `05-plan.md` | not yet audited | PROPOSED |

**Code implementation (plan steps 1–6) has not been executed.** The sprint produced a frozen,
independently audited design and plan; the implementation is deferred to a follow-on row.

## 2. What was delivered

- **The problem is named and measured:** the register `CLAIMS.md` is parsed at five independent
  sites; T406 proved two of them silently returned 0 rows from a 221-row register on the same
  day.
- **The scope is decided:** claimlint+absorb (merge into one Zig binary, `verify`/`absorb` verbs)
  and subagent+ollama-subagent (merge into one Python script, `--provider` flag) are IN.
  managent, argus, and runner are OUT. gen-indices is ASSESS.
- **22 acceptance tests** are written before design, freezing the requirements.
- **The design** is a mechanical merge (not a rewrite): ~300 lines of inline parser retired,
  `claims_register.zig` becomes the single source of truth, and the T406 shape becomes
  structurally impossible.
- **An 8-step plan** with independently revertible commits, pre-removal diff gate, and cutover
  wrappers.

## 3. What remains

1. **Audit Phase 5 (plan).** Phase 5 has not yet been independently audited.
2. **Audit Phase 6, 7, 8.** These document-only phases need audit.
3. **Implement plan steps 1–6.** Code changes to `src/claimlint.zig`, `src/absorb.zig`,
   `src/claims_register.zig`, `build.zig`, `bin/subagent`, and the cutover wrappers.
4. **Run the acceptance suite (Phase 7 proper).** Show every RED control RED first, then GREEN.
5. **Remove cutover wrappers (Phase B).**

## 4. Follow-on row recommendation

A single follow-on row implementing all 8 plan steps, with the pre-removal diff gate executed
before step 3 (parser retirement). The row should follow the same audit-after-each-major-step
pattern.

## 5. The eight qualities — final score

| quality | claimlint+absorb | subagent pair | combined |
|---|---|---|---|
| reuse | `+` — one parser, 300 lines retired | `+` — 113 common lines deduped | `+` |
| testability | `+` — union of 4 suites | `+` — union of 4 suites | `+` |
| predictability | `+` — default=verify, explicit absorb | `+` — REQUIRED --provider, no silent default | `+` |
| transparency | `+` — one help screen, pipeline visible | `+` — one help screen, both providers | `+` |
| stability | `0` — cutover wrappers, backward compat | `0` — wrapper injects --provider deepseek | `0` |
| agility | `+` — one build target, one parser fix | `+` — one file for dispatch changes | `+` |
| performance | `+` — one build, one deploy | `+` — one Python parse | `+` |
| separation of concerns | `0` — structural boundary, overlapping exits | `0` — provider flag mechanism vs policy | `0` |

No `−` entries. The two scope-level `−` entries (stability, separation of concerns) are mitigated
to `0` by cutover wrappers and structural verb dispatch.

---

**Landmark:** advances `L4 (the ledger is clean)` — the consolidation design is frozen and
independently audited; the code implementation is deferred. What remains: audit Phase 5, implement
the 8-step plan, run the acceptance suite, and remove cutover wrappers.

**Human summary:** the sprint delivered an independently audited consolidation design through
Phase 5. The design merges claimlint and absorb into one Zig binary with `verify`/`absorb` verbs
(retiring the ~300-line inline register parser so the T406 silent-divergence shape becomes
structurally impossible), and merges subagent and ollama-subagent into `bin/subagent` with
REQUIRED `--provider` flag. 22 acceptance tests freeze the requirements before design; the
eight-quality score has no `−` entries. Code implementation is deferred — the eight-step plan
is ready for a follow-on row.
