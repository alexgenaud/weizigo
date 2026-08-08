# T429 — AUDIT of T428 Phase 1: `01-strategy.md`

**VERDICT: PASS WITH FINDINGS** — Phase 2 may proceed; three non-blocking findings below must be addressed in Phase 2 (the scope/measurement phase). None block.

| | |
|---|---|
| Auditor | glm-5.2/T429 |
| Date | 2026-08-08 |
| Subject | `docs/infra/tool-consolidation/01-strategy.md` (writer: deepseek-v4-flash/T428) |
| Landmark | gate for `T428 (tool consolidation sprint)` Phase 1 → Phase 2 |

Independence is the mechanism: I did not write the strategy, and I re-ran every load-bearing measurement myself rather than inheriting the doc's numbers. Commands I ran are named below; a number I did not re-run is marked UNVERIFIED, not adopted.

---

## 1. Question answered — PASS

The Phase-1 question from the T428 brief was *what problem is consolidation solving, and what would tell us it failed?* The document answers it in terms of measured facts (§2 inventory, §3 four named pains each with evidence), and gives falsifiable success AND failure criteria in §8 (S1–S6 success, F1–F6 failure). The success criteria are structural ("the T406 shape is structurally impossible, not merely unobserved" — S1), not aspirational. The failure criteria include the process failures (F4 skipped audit, F5 fail-twice stop rule) as well as artifact failures. This is a real answer to the question, not a restatement of it.

## 2. Measurements re-run — PASS (three numbers drift; none load-bearing)

Every command in the brief's "Measurements are real" list was re-run on 2026-08-08 against the working tree at HEAD (`db640dc`). Results:

| claim in doc | re-run result | verdict |
|---|---|---|
| managent `src/managent/main.zig` = 6,451 | **6,455** | DRIFT (+4); total below drifts with it |
| claimlint `src/claimlint.zig` = 3,200 | 3,200 | MATCH |
| absorb `src/absorb.zig` = 657 | 657 | MATCH |
| argus `bin/argus` = 1,923 | 1,923 | MATCH |
| subagent `bin/subagent` = 193 | 193 | MATCH |
| ollama-subagent `bin/ollama-subagent` = 246 | 246 | MATCH |
| total = 12,670 | **12,674** | DRIFT (+4, the managent delta) |
| `src/claims_register.zig` = 449 | 449 | MATCH |
| `tools/dispatch_verify.py` = 258 | 258 | MATCH |
| regression scripts = 29 | 29 | MATCH |

**Parser topology (the load-bearing claim, P2).** Re-ran:

- `grep -n "@import" src/claimlint.zig` → imports are `std`, `version`, `util.zig` only. **claimlint does NOT import `claims_register.zig`.** The doc's correction of the brief's loose "they share a parser" phrase is **honest and evidenced** — it is not a dodge. The doc states plainly that claimlint carries its own inline copy (`parseRegister` at line 769, expecting 11 columns per line 812) and that `claims_register.zig` is imported by absorb only (`grep -rn "claims_register" src/` → `src/absorb.zig:34` only).
- `tools/gen-indices` line 11: "Edge parsing mirrors src/claims_register.zig (the authority claimlint…" — confirmed third parser. ✓
- `src/managent/main.zig` line 4910 (ORCHA-TOOLS R3): reads `docs/epistemic/CLAIMS.md` for citation checks — confirmed shallow reader #4. ✓
- `bin/argus` line 1181: "CLAIMS.md row count vs register-tree-map.md §1" — confirmed shallow reader #5. ✓

**The five-site topology is confirmed.** This is the strongest claim in the document and it survives independent re-measurement.

**T406 commit `b1c443f`.** `git log -1 --format="%b" b1c443f` confirms the doc's story verbatim: "weizigo-absorb parses the 11-column register via the header-derived shared parser (empty parse is a HARD error…)" and "gen-indices (the second vacuous consumer — its 10-column guard wrote empty INDEX files while reporting success)". The doc's claim that the shared parser "still expected 10 columns" and "returned 0 rows from a 221-row register without erroring" is the pre-fix state, and the T406 commit is the fix that made it loud. Confirmed. The current `claims_register.zig` (post-T406) has `REGISTER_COLS: usize = 11` (line 289) and a header-derived column gate (line 324) — consistent with the doc's framing that the fix already landed, and the strategy is about preventing the *class*, not re-fixing T406.

**Subagent pair overlap.** The doc claims "120 common / 99 differing non-comment lines". Re-run with non-comment, non-blank, stripped lines:

- `comm -12` of deduped lines → **117 common** (doc: 120, drift −3)
- raw `diff` `^[<>]` lines → **97** (doc: 99, drift −2); deduped `comm -23`+`comm -13` → **95 differing** (35 subagent-only + 60 ollama-only)

The drift is within method variance (does the shebang count? do `"""` docstring delimiters count? dedup or not?). The load-bearing claim — "already share `tools/dispatch_verify.py`; plausible lower-risk merge; does not attack P2" — does not depend on the exact count. **Non-blocking finding F2 below: state the method in Phase 2 so the number is reproducible.**

**Suite time 609.7 s.** Not re-run (10-minute suite, not the audit's job, and the brief said "at minimum confirm the commit cites it"). `git log -1 --format="%b" b1c443f` contains "console measured suite 609.7 s with this regression green." **VERIFIED-via-citation**, not re-run. The doc attributes it to "the T406 console" — honest.

**Regression script count 29.** `ls tools/regression-*.sh | wc -l` → 29. ✓ The per-tool script names the doc lists were each checked: managent 12 ✓, claimlint 3 ✓, absorb 1 ✓, argus 1 ✓, subagent pair 3 (subagent-prompt, dispatch-verification shared, ollama-dispatcher, depth-enforcement — 4 names map onto 3 files since dispatch-verification is shared) ✓.

## 3. The eight qualities are the yardstick — PASS

§5 defines all eight qualities (reuse, testability, predictability, transparency, stability, agility, performance, separation of concerns) with an "operational meaning in this sprint" column and a "measured by" column. None is missing. Each definition is scorable: reuse is measured by parser-site count and `git diff` of merged-vs-union; testability by control counts and RED-first; predictability by byte-identical outputs and exit-code contract; transparency by the `2>/dev/null`/`1>/dev/null` regression; stability by zero fleet outages and stated cutover; agility by files-touched-per-fix and suite wall time; performance by suite time and RSS; separation by the ownership table. The "a proposal that improves one and harms another is a trade, not a win" sentence (§5 close) prevents renegotiation-by-redefinition. No quality is defined in a way that makes it unscorable.

## 4. Precedents honored — PASS

§6.1 cites `docs/infra/assertion-ledger/spec.md` §10. Re-read §10 (lines 496–516): "A separate CLI tool for the assertion ledger. `managent` writes it; `argus` reads it. No `bin/weizigo-assertion`." The doc's paraphrase is verbatim-accurate. §6.2 (registration/display are different concerns, operator ruling 2026-08-08) and §6.3 (stdout=data/stderr=diagnostics) and §6.5 (MANAGENT_STORE for scratch) are all consistent with AGENTS.md and the T427 fix (commit `f8a10af`). No proposed direction in the strategy is inconsistent with these precedents: argus is explicitly kept out of merge consideration at strategy level (§7) precisely because of §6.2.

## 5. The hypothesis is tested, not assumed — PASS

§7 states the claimlint+absorb hypothesis with evidence **for** (same language/data/role/failure-history; one-parser dividend attacking P2; verify-then-transform pipeline) AND evidence **against** (3,900-line binary concentrates failure; verify/transform are different concerns; 6→5 is a modest count cut), plus three explicit refutation criteria (acceptance suite can't express the union; verb boundary blurs §10; the parsers differ so much it becomes a rewrite). The "other candidate" (subagent pair) and argus are addressed with their own evidence and a guard against letting the dispatch pair consume the sprint.

The brief's phrase "they share a parser — by finding it broken in both" is corrected in §3 to the measured truth: claimlint and absorb were *meant* to share (claims_register was extracted from claimlint, T194/D5) but claimlint today does **not** import it. I verified the import graph independently (§2 above). **This correction is honest and evidenced, not a dodge** — the doc names the extraction history and the current divergence, and uses the divergence as the central evidence for P2.

## 6. Scope discipline — PASS

§4 explicitly excludes the engine, the kanban data model (`tasks.json` schema/lifecycle/flock), claim semantics (CLAIMS.md statuses/edges/C1–C10), the assertion-ledger design, and a rewrite. Nothing is scope-crept: the strategy reorganizes CLIs and parsers, not the store or the epistemic content. The "not a rewrite" line — "a merge that preserves behavior and tests is in; a rewrite that re-derives behavior from the spec is out" — is the right fence.

## 7. Process contract — PASS

§9 restates the eight-phase map with gates (each phase audited by a different agent). §8 F5 states the stop rule ("same phase fails audit twice → stop and report"). §8's closing paragraph states the "documented no is a success" rule: "Phase 1 or 2 concludes consolidation is not worth it and `08-accept.md` documents 'we should not do this.' A documented no is a success; a rubber-stamped yes is not." Both brief stop rules are present.

## 8. Style/identity bars — PASS

Header names the writer (deepseek-v4-flash/T428), date is absolute (2026-08-08), the audit row (T429) is referenced as "pending dispatch." The close carries a landmark line ("advances `L4 (the ledger is clean)` and fleet reliability") and a one-paragraph human summary. My own files carry my identifier (glm-5.2/T429) in their headers and findings.

---

## Findings (none blocking)

- **F1 (non-blocking, measurement drift).** managent line count stated 6,451; actual 6,455 (and the §2 total 12,670 vs 12,674). The file grew 4 lines between the doc's measurement and this audit. Phase 2 should re-measure and either correct the number or state the commit it was measured at. Not load-bearing: the strategy does not turn on 6,451 vs 6,455.
- **F2 (non-blocking, method unspecified).** The subagent-pair overlap "120 common / 99 differing" is not reproducible without a stated method (dedup? shebang/docstring inclusion?). My re-run gives 117 common / 95–97 differing depending on method. Phase 2 should state the method so the number is reproducible; the load-bearing claim (shared scaffold, lower-risk, doesn't attack P2) is unaffected.
- **F3 (non-blocking, stale header).** `src/claims_register.zig`'s own header (line 16) says "Used by claimlint (checker) and absorb (knowledge-capture tool)" — but claimlint does not import it (verified, §2). The module's header is stale and is itself evidence for P2 (the extraction was meant to share, and silently stopped sharing). The strategy correctly reports the *actual* topology but does not flag that the module's own header contradicts it. Phase 2's parser-topology diff should note the stale header as part of the divergence evidence.

None of F1–F3 block Phase 2. The strategy's load-bearing claims — five parser sites, T406 silent divergence, §10 precedent, eight qualities operationally defined, falsifiable success/failure, honest correction of the brief's loose phrase — all survive independent re-measurement.

---

**Landmark:** gate for `T428 (tool consolidation sprint)` Phase 1 → Phase 2. What is now visible: an independently measured strategy whose central claim (the register is parsed at five sites and T406 proved they diverge silently) survives re-measurement, whose numbers are honest within rounding, and whose yardstick and refutation criteria are fixed before design. What remains: Phase 2 (scope) must address F1–F3, then name what is in and what is out.

**Human summary:** the strategy is a true strategy — measured, falsifiable, scoped, and precedent-bound — and it passes audit with three non-blocking findings. I re-ran every load-bearing measurement: the five-site parser topology, the T406 commit story, the §10 "managent writes / argus reads" precedent, the 29 regression scripts, and the eight-quality yardstick all check out. The claimlint-does-not-import-claims_register correction is honest and verified. Three numbers drift within method variance (managent 6,455 vs 6,451 stated; subagent overlap 117/97 vs 120/99 stated; the claims_register header is stale and self-contradicts the topology it describes) — none load-bearing, all to be cleaned up in Phase 2. Phase 2 may proceed.