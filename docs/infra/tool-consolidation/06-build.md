# T428 · Phase 6 — Build: what was built, against the plan, with deviations named

| | |
|---|---|
| Sprint | T428 (tool consolidation), set S |
| Phase | 6 of 8 — **build** |
| Writer | deepseek-v4-pro/T428.2 (structure), deepseek-v4-flash/T527 (execution 2026-08-23) |
| Date | 2026-08-23 (execution) |
| Status | EXECUTED — plan steps 1–6 implemented by T437/T440, extended by T482, Phase B by T527 |

---

## 1. Build status: EXECUTED

Phases 1–5 are complete and independently audited; the code steps (plan `05-plan.md` §2)
were implemented by follow-on rows and are live at HEAD:

| phase | document | audit | verdict |
|---|---|---|---|
| 1 — strategy | `01-strategy.md` | T429 (glm-5.2) | PASS WITH FINDINGS |
| 2 — scope | `02-scope.md` | T433 (glm-5.2) | PASS WITH FINDINGS |
| 3 — acceptance | `03-acceptance.md` | T434 (glm-5.2) | PASS WITH FINDINGS |
| 4 — design | `04-design.md` | T435 (FAIL) → T436 (PASS WITH FINDINGS, r2 ×2) | PASS WITH FINDINGS |
| 5 — plan | `05-plan.md` | audited via T436 r2 §7 (downstream corroboration) | PASS WITH FINDINGS |
| 6 — build | this document | — | EXECUTED |
| 7 — test | `07-test.md` | — | EXECUTED (T527) |
| 8 — accept | `08-accept.md` | — | SHIPPED (T527) |

## 2. What was built (code)

The plan's 8 steps, executed across T437/T440/T482/T527:

- **Step 1 (NF1 wording):** the stale "separate exit-code ranges" phrase in the design doc's
  §2.2 was patched by T527 (it had been reconciled in the plan but never applied to the
  design doc — the re-audit's NF1 called this exact gap).
- **Step 2 (verb dispatch):** `src/claimlint.zig` main() dispatches `verify` (default),
  `absorb`, `c7` (T482 extension), and help forms; unknown verbs error naming the verb (C1.1).
  T527 additionally closed the C1.1 acceptance half (NF4): a help flag after a known verb now
  prints usage and exits 0.
- **Step 3 (parser retirement):** the ~300-line inline register parser is gone from
  `src/claimlint.zig`; all nine duplicated functions (`Register`, `parseStatus`,
  `parseNarrowed`, `parseRate`, `backtickSpans`, `parseRegister`, `isClaimIdToken`,
  `claimIdOf`, `isQaId`) are removed and call sites use `cr.*` from `claims_register.zig`
  (single source of truth). The pre-removal diff gate (plan §2 step 3) passed: the two
  `parseRegister` implementations were behaviorally identical.
- **Step 4 (absorb module):** `src/absorb.zig` `main()` → `pub fn runAbsorb(io, gpa, args)`;
  version banner and repo-root resolution moved to claimlint's main; the findings-JSON parser
  is exposed. `build.zig` removes `absorb_exe`/`absorb_deploy` and imports `absorb` +
  `claims_register` as modules of `claimlint_exe`.
- **Step 5 (subagent merge):** `bin/subagent` handles `--provider deepseek|ollama` (REQUIRED,
  C2.1), plus the later `--provider claude` branch (T494).
- **Step 6 (Phase A cutover):** wrappers `bin/weizigo-absorb` (sh), `bin/ollama-subagent`
  (Python), `bin/subagent-ds` (Python) were deployed at `8ce3270`, hardened at `3aaffb6`
  (they only worked from repo root), and regression scripts migrated to the merged entry
  points.
- **Step 8 (Phase B):** the three wrappers were removed (deletions landed in `5330909`);
  regression scripts re-pointed to `bin/subagent --provider …` (T527 sweep `99a919b`).
- **T527 execution fixes (test-first, control RED before fix):** `verify --help`/`absorb
  --help` print usage (C1.1); `verify` on a 0-row register fails hard naming the empty parse
  on stderr (C1.9); subagent file-branch prompt restored to real newlines (C2.2/C2.3);
  claimlint-promotion regression re-pointed to the post-T557 kill-matrix path.

## 3. Deviations from plan

| plan step | deviation | named |
|---|---|---|
| Step 2 | `c7` verb added by T482 (after the merge) as a machine-readable C7 report — a non-breaking extension the design's verb approach explicitly supported | T482 |
| Step 2 | dispatch collects remaining args once and scans for help flags after a known verb (NF4 closure), rather than the plan's first-arg-only help handling | T527 |
| Step 7/8 | wrapper removal (Phase B) landed inside the mixed `5330909` commit rather than a standalone revertible commit, because it was swept up with a fleet protocol change; `git revert` of the deletions alone is still trivial | T527 note |
| Step 1 | the wording patch landed in the design doc (the phrase's actual home), not the code comment the plan had named | T527 (per NF1) |

## 4. Post-build verification

- `zig build -Doptimize=ReleaseSafe` green.
- All nine consolidated-tool regression scripts green (see `07-test.md`).
- Fleet-wide `zig build test` executed (29m44s, 81 scripts); six pre-existing reds unrelated
  to the consolidation are itemized in `07-test.md` §5 and findings.

---

**Landmark:** advances `L4 (the ledger is clean)` — the consolidation design is built: one
binary with `verify`/`absorb`/`c7` verbs and one shared register parser, one subagent script
with REQUIRED `--provider`, cutover wrappers deployed then removed. What remains: acceptance
results (`07-test.md`) and the accept ruling (`08-accept.md` / `accept.md`).

**Human summary:** the code the T428 design deferred was built by T437/T440 and extended by
T482; T527 executed the acceptance suite, closed the last two acceptance gaps (help verb
handling, empty-register hard error on verify), restored the subagent file-branch prompt the
merge had over-escaped, and removed the cutover wrappers. The merged binary is live at HEAD.
