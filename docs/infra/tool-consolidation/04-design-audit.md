# T435 — RE-AUDIT of T428 Phase 4: `04-design.md` (round 3)

**VERDICT: PASS WITH FINDINGS** — the design's substance is sound and, unlike either prior
audit, verifiable against the *implemented artifact*: the consolidation was built (T437,
`8ce3270`; hardened T440; extended T482) and every load-bearing design claim survives contact
with the real code. Phase 5 may proceed. Five non-blocking findings remain — three are
design-text residues (two are T436's own NF1/NF3, never applied to the document), one is a new
exit-code-table inaccuracy, one is header staleness, one is a cutover-plan gap re: a stale
built artifact. None blocks; all are small patches.

| | |
|---|---|
| Auditor | deepseek-v4-flash/T435 |
| Date | 2026-08-20 |
| Subject | `docs/infra/tool-consolidation/04-design.md` (writer: deepseek-v4-pro/T428.2; original commit `956a34f`, fix commit `3beda47`) |
| Landmark | gate for `T428 (tool consolidation sprint)` Phase 4 → Phase 5 |

Independence is the mechanism: I did not write the design, the round-1 audit, or the round-2
re-audit. I re-read the Phase 2 scope (`02-scope.md`, re-audited PASS WITH FINDINGS by T433 on
2026-08-20) and the Phase 3 acceptance (`03-acceptance.md`), the round-1 audit (`04-design-audit.md`
superseded by this document; T435, FAIL, three findings), and the round-2 re-audit
(`04-design-audit-r2.md`, T436, PASS WITH FINDINGS, three new non-blocking findings), then
re-verified the design's concrete claims against the source at `9a96f8b` and — the step no
prior audit could take — against the **implemented** consolidation in the current tree
(`src/claimlint.zig`, `src/absorb.zig`, `src/claims_register.zig`, `build.zig`, `bin/subagent`,
`bin/subagent-ds`, `bin/ollama-subagent`, `bin/weizigo-absorb`). A design whose claims are
checkable against its own shipped artifact is auditable at full strength; that is the standard
this audit holds.

**Sprint reality at audit time.** `08-accept.md` (2026-08-08) ruled the sprint PARTIAL with code
deferred; the follow-on row T437 then implemented the 8-step plan (`8ce3270`, "implement
consolidation plan steps 1-6"), T440 repaired the three wrappers, and T482 extended the merged
binary with a `c7` verb. Phases 6–8 documents remain in their pre-implementation "deferred"
wording and are stale against the tree; that is out of scope here (this audit is the Phase 4
gate), noted so the Orchestrator can see the phase-doc lag is known. The kanban claim of this row
was blocked on dependency `T428` in the same shape as T433/T434; the document under audit exists
on disk and the audit proceeded — recorded for the same reason the sibling audits recorded it.

---

## 1. Design decision stated? — PASS

§1.1 decides the boundary — **one binary with subcommand verbs, not a shared library** — with a
stated rationale: a shared library would require a stable C ABI or Zig package interface, would
touch every consumer (managent, argus, gen-indices), and would be a migration rather than a merge
(which strategy §4 ruled out). The verb approach is "a mechanical merge" local to
`src/claimlint.zig` and `build.zig`. §5.1 re-binds it ("No shared library"). This is a decision,
not a survey of approaches. The gen-indices assessment is correctly deferred (§1.1, §5.2: a
consumer relationship via a later `parse` verb, non-breaking). Question 1 answered.

**Verified against the artifact:** the implementation is exactly one binary with verbs — claimlint
`main()` dispatches `absorb` → `absorb.runAbsorb`, `c7` → `runC7`, everything else → `runVerify`,
with help listing the verbs (claimlint.zig:642, 980–1060). No library was built; `managent` and
`argus` are untouched by the merge.

## 2. Every Phase 2 scope decision covered? — PASS

Re-checked each Phase 2 scope decision against the design (the F1/F2/F3 fixes did not drop or
newly violate any):

| Phase 2 scope decision | design coverage | verdict |
|---|---|---|
| `weizigo-claimlint` IN (merge, `verify`/`absorb` verbs) | §1.1, §2.1–§2.4 | covered — concrete file table, verb dispatch, parser retirement, line counts |
| `weizigo-absorb` IN (`absorb` verb) | §2.1 (runAbsorb rename, wrapper), §2.2 | covered |
| `bin/subagent` IN (`--provider` flag) | §3.1–§3.3 — `--provider` REQUIRED (C2.1 satisfied) | covered |
| `bin/ollama-subagent` IN (`--provider ollama`) | §3.1 wrapper | covered |
| `managent` OUT | §5.3 ("No managent or argus changes") | non-interference stated |
| `argus` OUT | §5.3 | non-interference stated |
| `tools/gen-indices` ASSESS | §1.1, §5.2 (deferred; `parse` verb non-breaking later) | correctly deferred, not committed |
| `tools/dispatch_verify.py` OUT | §3.2 ("shared scaffold," `dispatch_verify` import preserved) | non-interference stated |
| `tools/runner` OUT | not touched | fine (orthogonal) |

No IN tool lacks a concrete design; every OUT/ASSESS has a non-interference statement. Verified
against the tree: absorb's `dispatch_verify` usage survives in the merged `bin/subagent`;
`managent`/`argus`/`runner`/`gen-indices` are unchanged by the merge.

## 3. Parser retirement concrete? — PASS

§2.1 (file table) and §2.3 (retirement steps) describe it concretely: the nine-function removal
list (`Register` struct, `parseStatus`, `parseNarrowed`, `parseRate`, `backtickSpans`,
`parseRegister`, `isClaimIdToken`, `claimIdOf`, `isQaId` — **`isClaimIdToken` now included**, the
round-1 F3 fix), the `const cr = @import("claims_register.zig")` import, the call-site
replacement (`parseRegister(...)` → `cr.parseRegister(...)`), the `Register`-struct compatibility
check with a pre-removal diff gate (strategy §7 refutation criterion, carried into §8 risk 1),
and the post-merge guarantee: if the parser is wrong, the T406 two-verdicts-same-file shape is
structurally impossible because both verbs call the same `cr.parseRegister()`.

**Verified against the artifact — the strongest form of this check:**
- `grep -c "fn parseRegister\|fn parseStatus\|fn parseNarrowed\|fn parseRate\|fn backtickSpans\|fn claimIdOf\|fn isQaId\|fn isClaimIdToken" src/claimlint.zig` → **0** (all nine retired; round-1 F3's `isClaimIdToken` duplicate is genuinely gone).
- `src/claimlint.zig:106–107` imports `claims_register.zig` and `absorb.zig`.
- `src/claims_register.zig:21` header corrected: "Used by claimlint (verify and absorb verbs) — imported by src/claimlint.zig" (the stale "Used by claimlint (checker) and absorb" is gone; the design's §2.1 line-21 citation is correct — the sibling scope doc's 18–19 citation was the wrong one, per T433 F-a).
- `src/absorb.zig:448` is `pub fn runAbsorb(io, gpa, args)` (was `pub fn main` at 449 at `9a96f8b`); the version banner moved to claimlint's main (printed once).
- **One §2.1 file-change item was NOT executed as written:** the design's absorb.zig row (3) says "remove `findRepoRoot` call — claimlint main resolves paths." The implementation kept `findRepoRoot` inside `runAbsorb` (absorb.zig:42, called at ~line 459). Outcome-equivalent and arguably more robust (absorb still resolves its own repo root; the design's §8 risk-2 mitigation was simply not the one adopted) — recorded here as an undocumented implementation deviation, not a finding, since C1.3 (byte-identical absorb side effects) is the gate that actually governs and the paths resolve identically.
- `isPathChar` (claimlint.zig, C2 path-token logic) correctly remains — it is not a register-parser function and `claims_register.zig` does not export it; both prior audits flagged this as correctly NOT in the removal list, and the implementation agrees.

The §2.3 line-range note ("functions at lines 713–930 at `9a96f8b`") is slightly over-inclusive
(it sweeps in `isPathChar` at 923, which stays) but the removal *list* is precise and the ~300-line
estimate is in the right neighbourhood. Not a finding — same note as both prior audits.

## 4. Separation-of-concerns boundary (F4 from Phase 3 audit) — PASS at core, one table inaccuracy (F-1)

The Phase 3 audit (T434 F4) found the verb-boundary "separate exit codes, no shared mutable state"
under-tested and asked Phase 4 to specify it concretely. The round-1 audit found the answer
hand-waving (overlapping ranges labelled "separate"); the fix commit `3beda47` corrected it, and
the corrected §2.2 is the design's answer:

- **Separate code paths** — YES. The dispatch routes `absorb` to `absorb.runAbsorb` and everything
  else to `runVerify`; no code path reaches both. Verified in the implementation (claimlint.zig
  1000–1060: the verb is consumed once, the remainder is passed to exactly one handler).
- **Separate invocation context** — YES. The verb is the first argument, visible in argv.
- **No shared mutable state** — YES, plausibly and structurally: one verb per process, page
  allocator, no global mutable state persists between invocations.
- **Exit codes overlap numerically on 0 and 1 — and the design now says so plainly.** §2.2:
  "The exit codes overlap numerically on 0 and 1. The boundary is NOT numeric — it is structural."
  §4 row: "mitigated to `0` by structural separation, not numeric separation." The round-1
  hand-waving is gone where it counts.

**The residual defect is in the table's semantics labels, not the boundary claim — F-1.**
§2.2's exit-code block reads: "`verify`: 0 = clean (no findings), 1 = findings present,
2 = usage/IO error, 3 = unparsed rows (existing claimlint convention — lines 1246, 2342 at
`9a96f8b`)". The real convention — verified at `9a96f8b` **and** in the current tree — is:

| exit | real meaning (`9a96f8b`) | real meaning (current tree) |
|---|---|---|
| 0 | clean | clean |
| 1 | findings present (c1/alarms/c2/c6/c7/c9) | findings present (incl. c7 nonconforming) |
| 2 | **calibration FAIL** (line 2343) | **calibration FAIL** (line 2249) |
| 3 | unparsed rows **OR cannot-read IO** (lines 1246, 2342) | unparsed rows **OR cannot-read IO** (lines 1053, 2248) |

The design labels 2 as "usage/IO error" — but exit 2 is calibration failure, and the IO error
(cannot read the claims path) exits **3** at the design's own cited line 1246. The design's cited
evidence contradicts its own label. The table also omits the calibration exit entirely. The
implementation preserved the real convention (the merge did not touch exit semantics), so this is
a documentation defect, not a behavioural one — but the table is the design's answer to the
brief's question 4 and a Phase 7 test author reading it would assert "IO error → 2" against a
binary that exits 3. See F-1.

## 5. Backward compatibility — PASS (two design-text residues: F-2, F-3)

- **Default verb = `verify` (§1.2):** sound. The old `weizigo-claimlint` had no verb; the merged
  binary treats a first non-flag argument as a path and runs `verify`. Verified live:
  `bin/weizigo-claimlint docs/epistemic/CLAIMS.md` runs verify; a *missing* path yields a
  cannot-read error, not a crash.
- **`bin/weizigo-absorb` wrapper (§2.1):** implemented. `#!/bin/sh` wrapper exec'ing
  `weizigo-claimlint absorb "$@"` with a deprecation notice on stderr — and hardened by T440 to
  resolve from its own directory (the first version exec'd a relative `bin/weizigo-claimlint` and
  worked only from the repo root). Matches C1.8.
- **`bin/ollama-subagent` wrapper (§3.1):** implemented — Python passthrough to
  `bin/subagent --provider ollama` with a deprecation notice, cwd-safe since T440. Matches C2.7.
- **DeepSeek backward compat (the round-1 F1 fix):** `--provider` is REQUIRED on the merged
  script (verified live: `bin/subagent` → exit 1, stderr "subagent: missing --provider
  (deepseek|ollama)"; unknown provider → exit 1 naming the providers) — C2.1 satisfied by the
  merged script directly. Old DeepSeek callers are served by the **real** wrapper
  `bin/subagent-ds` (T437 created, T440 hardened), which injects `--provider deepseek` — this is
  T436's NF2 option (a), realized. Direct un-updated callers get the loud error §7 Phase A step 4
  promises. **NF2 is closed by the artifact.**

**Residues (both were T436 findings, fixed in the plan and in the implementation but never applied
to the design document):**

- **F-3 (T436 NF3, design text):** §1.2 still says "if the first non-flag argument is not a
  recognized verb, it is treated as a path argument and the `verify` verb is used." As written
  this conflicts with frozen acceptance test C1.1, whose RED control is
  `weizigo-claimlint no-such-verb` → exit ≠ 0 **and stderr names the unknown verb** — a non-verb
  treated as a path errors on the missing path, not the verb. The implementation resolved it
  exactly as the Phase 5 plan's step 2 specified ("if argv[1] is neither a recognized verb nor an
  existing path → error: 'unknown verb <arg>'"; claimlint.zig:1024–1031) — verified live:
  `bin/weizigo-claimlint no-such-verb` → "claimlint: unknown verb 'no-such-verb'", exit 1. But the
  design's §1.2 text was never patched with the "nor an existing path" clause. Lower severity than
  round-1 F1 (exit ≠ 0 held even under the old text; only the error wording differed) and now moot
  in the artifact — but the design document, as the durable Phase 4 record, still contradicts C1.1
  on paper.
- **F-2 (T436 NF1, design text):** §2.2's closing sentence still reads "The separation is
  structural (separate code paths, **separate exit-code ranges**), not by convention." — the exact
  phrase the round-1 audit flagged as hand-waving, contradicting the corrected block two paragraphs
  above ("overlap numerically on 0 and 1 … NOT numeric"). T436 called this must-change; the Phase 5
  plan's step 1 (wording patch to the design doc) was never executed against the document.

## 6. Cutover plan — PASS (Phase A executed; Phase B correctly deferred)

§7 states two cutover lines: Phase A (build the merged binary; `bin/weizigo-absorb` and
`bin/ollama-subagent` become wrappers; `zig build test` green with wrappers in place) and Phase B
(remove the wrappers in a separate commit after every console has been updated, so `git revert` of
the removal is trivial). These are stated lines, not a surprise — and they match the brief's §Bar 2
and the scope's §5 cutover rule.

**Status against reality:** Phase A executed (T437/T440: merged binary built and deployed,
wrappers live and cwd-safe, four regression scripts migrated to `--provider` by T440). Phase B not
executed — all three wrappers (`bin/weizigo-absorb`, `bin/ollama-subagent`, `bin/subagent-ds`) are
still in the tree. This is consistent with the design's own gate: Phase B is "after every console
has been updated," the fleet still references the old entry points, and T440's hardening work
implies the wrappers are a live compatibility surface. Keeping them is the design's safety
position, not a violation.

**Gap (F-5):** the design's Phase A has no "clean the stale built artifact" step. `zig-out/bin/
weizigo-absorb` — a Mach-O from 2026-08-08 17:23, i.e. the pre-merge binary — still sits in the
working build output, so acceptance test C3.5 ("`ls zig-out/bin/weizigo-absorb` does not exist or
is a symlink to weizigo-claimlint") **fails against the current `zig-out/`**. `zig build` install
does not clean the output directory, so a fresh build does not remove it either. Phase 7, run
against the implemented tree, must clean `zig-out` first or C3.5 cannot pass; the design could
have named this in §7 Phase A. See F-5.

## 7. Eight-quality score honest? — PASS (the two `−`→`0` mitigations hold; one table caveat)

The scope had two `−` entries (stability, separation of concerns), both on the claimlint+absorb
merge. The design claims both mitigated to `0`:

- **Stability `−` → `0`:** concretely delivered. The cutover wrappers exist and work (verified:
  `bin/weizigo-absorb` exec's the merged binary with `$@` passthrough and a stderr deprecation;
  `bin/ollama-subagent` and `bin/subagent-ds` likewise; T440 made all three cwd-safe), and the
  default-verb = `verify` backward compat is live. The "3,900-line binary, concentration of
  failure" half is answered by C1.9 (no silent success — the empty-parse hard error, which
  pre-existed via T406 and survives in runAbsorb's refusal path) plus the union-of-suites bar.
  Honest.
- **Separation of concerns `−` → `0`:** the mitigation is structural, not numeric, and the design
  says so where it counts (§2.2 main block, §4 row). Two caveats, both documentation-level: the
  §2.2 closing sentence still carries the stale "separate exit-code ranges" phrase (F-2), and the
  exit-code *semantics* table is inaccurate (F-1). Neither changes the actual boundary (the
  implementation matches the corrected structural understanding), but a reader hits the
  contradiction in §2.2 before reaching §4's resolution. Same assessment T436 gave NF1: the `0`
  survives the governing block, not the stale sentence.

No `−` is hidden (both are named and argued). The subagent stability `0` rests on the wrapper
story, which is now backed by real files (NF2 closed). The eight-quality table is honest at the
level that governs the gate.

## 8. Migration risks assessed? — PASS (one gap: F-5; one doc risk not named: F-1)

§8 names five risks with likelihood/impact/mitigation. Row 1 — the two `parseRegister`
implementations differ in a breaking way → merge becomes a rewrite → strategy §7 refutation — is
the right load-bearing risk, and the design carries it into §2.3 as a pre-removal diff gate.
The other four (absorb path resolution, hardcoded old binary names in regression scripts,
`--provider` flag collision, depth-cap regression) are each concrete with a Phase 6 verification
(and the depth-cap risk is structurally impossible to miss: the check sits at the top of
`main()`, before the provider branch — verified in the merged `bin/subagent`).

Risks NOT named that should be:

- **Stale built artifact surviving cutover (F-5).** Nothing in §7 Phase A removes
  `zig-out/bin/weizigo-absorb`; C3.5 fails against the current output directory. The design could
  have made "clean `zig-out` / confirm no stale absorb binary" an explicit Phase A step.
- **The exit-code-table semantics drift (F-1).** A documentation risk: the table's "2 =
  usage/IO error" mislabel would propagate into Phase 7 assertions and future maintainer
  readings. The implementation is immune (it preserved the real convention), which is why this is
  non-blocking — but the table is cited evidence and it is wrong.
- The round-1 audit's other two additions (default-verb path/verb collision — a path literally
  named `absorb`/`help` — and the design's own F1 conflict) are now moot: the implementation's
  unknown-verb guard (non-verb non-path → error) resolves the collision concern for the C1.1
  case, and `verify`'s exit set {0,1,2,3} is what the table's range claims. The collision of a
  findings *file* named `absorb` is still theoretically possible (a path that exists AND is named
  like a verb is consumed as the verb), but no such path exists in the tree and the failure would
  be loud (absorb would reject a non-findings JSON or find no findings file). Not a new finding;
  noted for completeness.

## 9. Build system changes concrete? — PASS

§6 shows actual `build.zig` changes: remove `absorb_exe` and `absorb_deploy`, add `absorb` and
`claims_register` as module imports on `claimlint_exe`, drop `weizigo-absorb` from the deploy
step. I verified the "before" state at `9a96f8b` (claimlint_exe imports only `version`;
absorb_exe imports `version` and `claims_register`; `absorb_deploy` and the `deploy-absorb` step
exist) and the "after" state in the current tree: **no `absorb_exe`, no `absorb_deploy`, no
deploy-absorb in `build.zig`**; `claimlint_exe.root_module.addImport("absorb", ...)` at
build.zig:855–856; `b.installArtifact(claimlint_exe)` at 860; no `installArtifact` for
weizigo-absorb. The design's `addImport` snippet (`b.createModule(.{ .root_source_file = ...,
.target = target, .optimize = optimize })`) matches the codebase pattern. Concrete and accurate.
Question 9 answered.

## 10. Process bars — PASS (header staleness: F-4)

- **Landmark line** — present (close): "Landmark: advances `L4 (the ledger is clean)` — the
  design is a mechanical merge, not a rewrite: …".
- **Human summary** — present (close): "Human summary: the design merges claimlint and absorb
  into one Zig binary …".
- **Header** — names writer (`deepseek-v4-pro/T428.2`), phase (4 of 8 — design), date
  (2026-08-08). Two staleness defects: the "Commit" line says `697a3ef` ("T428 Phase 3: acceptance
  tests written before design") — that is the Phase 3 acceptance commit, not the design's; the
  design's content corresponds to `956a34f` (original) → `3beda47` (fix), and "(HEAD, …)" has been
  false since 2026-08-08. The "Audit | pending" line is also stale: round-1 (T435, FAIL) and
  round-2 (T436, PASS WITH FINDINGS) audits exist and are committed. Same family as T433's F-f on
  the scope doc. See F-4.
- **"What the design does NOT do" (§5) vs scope OUTs** — matches. §5 names no shared library, no
  `parse` verb yet, no managent/argus changes, no `tasks.json` schema changes, no regression
  rewrites. The scope's OUT list also names the engine, claim semantics, and the assertion-ledger
  design; the design does not restate those three, but neither does it touch them. Same minor
  framing gap the round-1 audit noted; not a defect.

---

## Findings

- **F-1 (non-blocking — §2.2 exit-code table mislabels `verify`'s real convention).** The table
  says "2 = usage/IO error, 3 = unparsed rows (existing claimlint convention — lines 1246, 2342 at
  `9a96f8b`)". The real convention (verified at `9a96f8b` and in the current tree): **2 =
  calibration FAIL** (claimlint.zig:2343 at `9a96f8b`, :2249 current); **3 = unparsed rows OR
  cannot-read IO** — the design's own cited line 1246 is the cannot-read `exit(3)`, contradicting
  its "2 = usage/IO error" label. The calibration exit is omitted entirely. The implementation
  preserved the real convention (the merge did not change exit semantics), so the artifact is
  correct and this is documentation-level — but the table is the design's answer to brief Q4 and
  a Phase 7 test author would write "IO error → 2" assertions against a binary that exits 3.
  **Must change:** relabel the table to the real convention (2 = calibration fail; 3 = unparsed
  rows / IO error), or drop the semantics column and cite the code.
- **F-2 (non-blocking — T436 NF1 residue in the design text).** §2.2's closing sentence still
  reads "The separation is structural (separate code paths, **separate exit-code ranges**), not
  by convention." — the exact phrase T436 flagged, contradicting the corrected block above it
  ("overlap numerically on 0 and 1 … NOT numeric"). The Phase 5 plan's step 1 (wording patch to
  this document) was never applied. **Must change:** drop "separate exit-code ranges" from that
  sentence (the plan already specifies the replacement wording).
- **F-3 (non-blocking — T436 NF3 residue in the design text).** §1.2 still says a non-verb first
  argument "is treated as a path argument and the `verify` verb is used," which as written
  conflicts with frozen acceptance test C1.1 (RED control requires stderr to name the unknown
  verb). The implementation resolved it (unknown verb unless the path exists — verified live:
  "claimlint: unknown verb 'no-such-verb'", exit 1) and the Phase 5 plan specified it (step 2),
  but the design text was never updated. **Must change:** add the "nor an existing path" clause
  to §1.2.
- **F-4 (non-blocking — header staleness).** Header "Commit | `697a3ef` (HEAD, 'T428 Phase 3:
  acceptance tests written before design')" names the Phase 3 acceptance commit, not the design's
  (content corresponds to `956a34f` → fix `3beda47`); "(HEAD)" is false; "Audit | pending" is
  false (round-1 and round-2 audits exist). Same family as T433 F-f. **Must change:** update the
  header to the design's actual commit(s) and audit status.
- **F-5 (non-blocking — cutover-plan gap: stale built artifact fails C3.5).** `zig-out/bin/
  weizigo-absorb` (Mach-O, 2026-08-08 17:23, the pre-merge binary) still exists in the working
  build output; acceptance test C3.5 ("`ls zig-out/bin/weizigo-absorb` does not exist or is a
  symlink") is currently FALSE. `zig build` install does not clean `zig-out`, and §7 Phase A has
  no "clean stale artifacts" step. **Must change:** Phase 7 must clean `zig-out` before the C3.5
  check (or the design/plan gains an explicit Phase A cleanup step).

**Resolved positively (verified against the artifact, the step no prior audit could take):**

- Round-1 F1 (was BLOCKING): FIXED — `--provider` is REQUIRED on the merged `bin/subagent`
  (verified live: missing → exit 1 naming "provider"; C2.1 satisfied), and old DeepSeek callers
  are served by the real `bin/subagent-ds` wrapper.
- Round-1 F2 (was BLOCKING): FIXED at core — §2.2/§4 state the boundary as structural with the
  overlap acknowledged; the implementation's dispatch matches (verb → exactly one handler; no
  shared mutable state). Residual: the stale "separate exit-code ranges" phrase (F-2) and the
  exit-code table labels (F-1).
- Round-1 F3 (was non-blocking): FIXED — `isClaimIdToken` is in the §2.3 removal list and is
  actually retired in the tree (`grep` for all nine inline parser functions returns 0).
- T436 NF2: RESOLVED by the artifact — `bin/subagent-ds` exists (T437, hardened T440); the
  design's §4 subagent-stability-`0` claim now rests on a real file.
- The design's extensibility claim (§5.2 "adding a verb later is a non-breaking extension") was
  exercised: the implementation added a third verb, `c7` (T482), without disturbing the boundary
  — the architecture held.
- The T406 structural-impossibility guarantee is realized: one Zig parser, both verbs call
  `cr.parseRegister()`, `grep -c 'fn parseRegister' src/claimlint.zig` = 0.
- Line-count direction held: pre-merge claimlint+absorb 3,857 → current 3,382 (claimlint) + 650
  (absorb) = 4,032, a net −475 vs the design's predicted −300 (later features such as `c7`
  added lines back); the merge is not a bloating exercise.

---

## Verdict summary

All three round-1 findings (F1/F2/F3) are genuinely fixed — now verified not just against the
pre-merge source but against the shipped implementation. The design's load-bearing claims all
survive contact with the artifact: one binary with verbs (dispatch verified), the parser retired
(nine inline functions gone, single import), `--provider` REQUIRED (C2.1 live), cutover wrappers
real and cwd-safe (NF2 closed), build.zig reduced to one target, and the extensibility path
exercised by the later `c7` verb. Five non-blocking findings remain, all documentation-level:

- **F-1** — §2.2 exit-code table mislabels `verify`'s semantics (2 = calibration FAIL, not
  usage/IO; IO errors exit 3, at the design's own cited line 1246). New finding.
- **F-2** — T436's NF1 residue: "separate exit-code ranges" still in §2.2's closing sentence;
  plan step 1 (wording patch) never applied to the document.
- **F-3** — T436's NF3 residue: §1.2 still lacks the "nor an existing path" clause that
  reconciles it with C1.1 (implementation has it; the document does not).
- **F-4** — header staleness: "Commit" names `697a3ef` (the Phase 3 acceptance commit, not the
  design's); "Audit | pending" is false.
- **F-5** — cutover-plan gap: the stale `zig-out/bin/weizigo-absorb` artifact fails C3.5 against
  the current build output; §7 Phase A has no cleanup step.

F-2 and F-3 are T436 findings the plan and implementation already reconciled — only the design
document's text lags, which is exactly the kind of stale-record debt this audit series exists to
sweep. F-1 is the one genuinely new defect and it is small (a table relabel or a "see the code"
pointer). F-4 and F-5 are hygiene. None blocks Phase 5.

---

**Landmark:** advances `L4 (the ledger is clean)` — the Phase 4 design passes re-audit with the
strongest available evidence: the consolidation is implemented (T437/T440/T482) and every
load-bearing design claim checks out against the shipped artifact — one binary with verbs, the
inline parser retired in favour of `claims_register.zig`, `--provider` REQUIRED with a real
DeepSeek wrapper, cwd-safe cutover wrappers, one build target, and the later `c7` verb exercising
the design's stated non-breaking-extension path. What remains: five non-blocking documentation
patches — two are T436's NF1/NF3 residues the design text never received (F-2, F-3), one is a new
exit-code-table inaccuracy (F-1), one is header staleness (F-4), one is a stale built artifact the
cutover plan did not sweep (F-5). None blocks; all are small.

**Human summary:** the Phase 4 design PASSES re-audit (pass with findings) — and unlike the two
earlier audits, this one could check the design against the code that was actually built (T437
implemented the consolidation after the sprint closed). Every load-bearing claim holds: the
claimlint+absorb merge is one binary with `verify`/`absorb` verbs (a `c7` verb was added later
without breaking the design, as promised), the ~300-line inline parser is genuinely retired in
favour of `claims_register.zig`, `--provider` is REQUIRED with a working `bin/subagent-ds`
backward-compat wrapper, and the cutover wrappers are real and cwd-safe. Five non-blocking
findings, all documentation-level: (1) the design's exit-code table mislabels `verify`'s exit 2 —
it is calibration failure, not "usage/IO error," and IO errors actually exit 3 (the design's own
cited line proves it); (2) a stale "separate exit-code ranges" phrase survives in §2.2 (flagged
by the last audit, never patched in the document); (3) §1.2 still lacks the "unknown verb" clause
that reconciles it with acceptance test C1.1 (the implementation has it, the document doesn't);
(4) the header names the wrong commit and says "Audit: pending" when two audits exist; (5) a
stale pre-merge binary still sits in `zig-out/bin/weizigo-absorb`, which would fail acceptance
test C3.5 unless `zig-out` is cleaned. Phase 5 may proceed — it already did, and the artifact
vindicates the design.
