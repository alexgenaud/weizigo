# T436 — RE-AUDIT of T428 Phase 4: `04-design.md` (round 2)

**VERDICT: PASS WITH FINDINGS** — all three round-1 findings (F1, F2, F3) are genuinely fixed at
their load-bearing core; Phase 5 (plan) may proceed. Three new non-blocking findings remain
(NF1, NF2, NF3) that the writer should reconcile in the Phase 5 plan — two are cutover/dispatch
mechanism inconsistencies the plan must pin down, and one is the same shape as the F1 fix but on
the claimlint half (lower severity: the exit-code half of the control already holds).

| | |
|---|---|
| Auditor | glm-5.2/T436 |
| Date | 2026-08-08 |
| Subject | `docs/infra/tool-consolidation/04-design.md` (writer: deepseek-v4-pro/T428.2, round-1 commit `956a34f`, fix commit `3beda47`) |
| Landmark | gate for `T428 (tool consolidation sprint)` Phase 4 → Phase 5 (re-audit after F1/F2/F3 fixes) |

Independence is the mechanism: I did not write the design or the round-1 audit. I re-read the
Phase 2 scope (`02-scope.md`, audited PASS WITH FINDINGS by T433), the Phase 3 acceptance
(`03-acceptance.md`, audited PASS WITH FINDINGS by T434), and the round-1 audit
(`04-design-audit.md`, T435, FAIL), then re-verified the design's concrete claims against the
source at HEAD (`3beda47`) and the round-1 fix commit. The round-1 audit returned FAIL on three
findings (F1 blocking, F2 blocking, F3 non-blocking); the writer's fix commit `3beda47` claims all
three fixed. This re-audit verifies each fix independently, then re-checks the full design against
Phase 2 scope and Phase 3 acceptance — the brief's two-step bar.

The kanban claim of this row was blocked (dependency `T428` still `in_progress`, same shape as the
sibling audits T433/T434/T435); the human dispatched the re-audit directly and the document under
audit (with its fix commit `3beda47`) exists on disk, so the substantive work proceeded. That
context is recorded here so the Orchestrator can see it — same shape as T433/T434/T435, recorded
for the same reason.

---

## 1. F1 re-audit — `--provider` default vs C2.1 — FIXED

**Round-1 finding (T435 F1, BLOCKING):** the design defaulted `--provider` to deepseek when the
flag was absent, directly contradicting frozen acceptance test C2.1 (`bin/subagent` without
`--provider` → exit ≠ 0, stderr says "provider") and scope §3.2. The fix proposed: make
`--provider` REQUIRED and have a cutover wrapper inject `--provider deepseek` for backward compat.

**Verified fixed at the load-bearing core.** The revised design makes `--provider` REQUIRED on the
merged script itself:

- §3.1 file-change row: "`--provider` is REQUIRED (missing → error, satisfying C2.1)".
- §3.2 pt 3: "A bare `bin/subagent` (no `--provider`) exits non-zero with 'missing --provider
  (deepseek\|ollama)' on stderr — satisfying C2.1 and scope §3.2."
- §4 predictability row: "`--provider` flag is REQUIRED (missing → error, satisfying C2.1)".

The merged script's own behavior now satisfies C2.1's RED-first control (missing flag → hard
error naming "provider"). I verified the "before" state at HEAD: `bin/subagent` (205 lines) has
no `--provider` flag today — it dispatches via DeepSeek using `--dspro`/`--dsflash` model flags
(line 45) and builds a `ds-pi` command (line 178); `bin/ollama-subagent` (248 lines) is the separate
Ollama dispatcher. Line counts (205 + 248 = 453) match the design's §3.3 "before" figure. So the
REQUIRED-`--provider` behavior is a genuine new behavior, not a restatement of the status quo.

**The C2.1 contradiction is gone.** A frozen acceptance test no longer disagrees with the design
on a one-line behaviour. F1 is fixed at its core. (A residual inconsistency in *how* backward
compat is achieved during cutover — the "bin/subagent cutover wrapper" — is tracked as NF2 below;
it does not touch C2.1, which is satisfied by the merged script directly.)

## 2. F2 re-audit — separation-of-concerns "separate exit-code ranges" hand-waving — FIXED at core (one stale phrase remains — NF1)

**Round-1 finding (T435 F2, BLOCKING):** §2.2 proposed `verify` ∈ {0,1,2} and `absorb` ∈ {0,1}
(ranges overlapping on 0 and 1) yet claimed "separate exit-code ranges" and "no exit-code
collision." The brief's question 4 asked whether the design specifies "separate exit-code ranges"
concretely; the round-1 audit found the "separate / no collision" language hand-waving.

**Verified fixed in the load-bearing places.** The revised §2.2 Exit-codes block now states the
overlap plainly and reframes the boundary as structural, not numeric:

> "The exit codes overlap numerically on 0 and 1. The boundary is NOT numeric — it is structural:
> separate code paths …, separate invocation context (the verb is the first argument, visible in
> argv), and no shared mutable state between invocations. A caller that wants to distinguish
> `verify`-exit-0 … from `absorb`-exit-0 … already knows which verb it invoked."

And §4 separation-of-concerns row is now consistent with that: "exit codes overlap numerically (0
and 1) but the verb disambiguates … the `−` from scope is mitigated to `0` by structural
separation, not numeric separation." So the brief's question 4 is now answered honestly: the
boundary is by-verb-meaning, not by disjoint numeric ranges, and the design says so where it
counts (§2.2 main block + §4 row). F2 is fixed at its core.

**The F3 secondary point (round-1 audit also asked to include `verify` exit code 3) is also
fixed:** §2.2 now lists `verify`: 0/1/2/3 with line citations ("existing claimlint convention —
lines 1246, 2342 at `9a96f8b`"). I verified those codes exist at HEAD: the design's exit-set
{0,1,2,3} for `verify` matches the real claimlint convention. (The round-1 audit mis-cited this
as a §2.3 correction; the exit-code list actually lives in §2.2, where the fix was correctly
applied.)

**Residual (NF1, non-blocking):** one stale phrase was not cleaned. §2.2's closing sentence
still reads "The separation is structural (separate code paths, **separate exit-code ranges**),
not by convention." — the "separate exit-code ranges" clause contradicts the corrected block two
paragraphs above ("overlap numerically on 0 and 1 … NOT numeric"). It is a copy-paste leftover of
the exact phrase F2 flagged. It does not change the design's actual behaviour (the main block
governs), but a reader hits the contradiction before reaching the §4 row that resolves it. See
NF1.

## 3. F3 re-audit — parser-retirement list omits `isClaimIdToken` — FIXED

**Round-1 finding (T435 F3, non-blocking):** §2.3's removal list named 8 functions but omitted
`isClaimIdToken`, a verified duplicate of `claims_register.zig`'s `pub fn isClaimIdToken`, exactly
the silent-divergence shape the merge retires.

**Verified fixed.** §2.3 step 1 now lists `isClaimIdToken`:
"Remove (from `src/claimlint.zig`): `Register` struct, `parseStatus`, `parseNarrowed`,
`parseRate`, `backtickSpans`, `parseRegister`, `isClaimIdToken`, `claimIdOf`, `isQaId`."

I re-verified against source at HEAD that the duplicate is real:
- `src/claimlint.zig:880` — `fn isClaimIdToken(tok: []const u8) bool` (inline), called at lines 907
  and 1115.
- `src/claims_register.zig:252` — `pub fn isClaimIdToken(tok: []const u8) bool`.

So `isClaimIdToken` is a genuine duplicate of an exported public function with two live call
sites in claimlint — exactly the silent-divergence shape the single-parser retirement exists to
eliminate. The design now retires it. (The round-1 audit already confirmed `isPathChar`
(line 923) is correctly NOT listed — it is C2 path-token logic, not a register-parser function,
and `claims_register.zig` does not export it; the revised design keeps that correctly out.)
The §2.3 line-range note ("functions at lines 713–930") remains slightly over-inclusive (it
sweeps in `isPathChar`/pathTokens, which stay) but the net-line estimate (~300) is in the right
neighbourhood. F3 is fixed.

## 4. Full re-check against Phase 2 scope — PASS (no scope decision newly uncovered)

Re-checked each Phase 2 scope decision against the revised design. The F1/F2/F3 fixes did not
drop or newly violate any scope decision:

| Phase 2 scope decision | design coverage (round 2) | verdict |
|---|---|---|
| `weizigo-claimlint` IN (merge, `verify`/`absorb` verbs) | §1.1, §2.1–§2.4 | covered |
| `weizigo-absorb` IN (`absorb` verb) | §2.1 (runAbsorb rename, wrapper), §2.2 | covered |
| `bin/subagent` IN (`--provider` flag) | §3.1–§3.3 — `--provider` REQUIRED (C2.1 satisfied) | covered |
| `bin/ollama-subagent` IN (`--provider ollama`) | §3.1 wrapper | covered |
| `managent` OUT | §5.3 | non-interference stated |
| `argus` OUT | §5.3 | non-interference stated |
| `tools/gen-indices` ASSESS | §1.1, §5.2 (deferred; `parse` verb non-breaking future extension) | correctly deferred |
| `tools/dispatch_verify.py` OUT | §3.2 ("shared scaffold," `dispatch_verify` import preserved) | non-interference stated |
| `tools/runner` OUT | not touched | fine (orthogonal) |

No IN tool lacks a concrete design; every OUT/ASSESS has a non-interference statement. The
parser-retirement list now covers every duplicated register-parser function (F3 closed).

## 5. Full re-check against Phase 3 acceptance tests — PASS WITH FINDINGS (NF3)

Re-checked the design against every Phase 3 acceptance test. The C2.1 conflict (F1) is resolved.
The C1.2/C1.3 (byte-identical output) and C1.5 (single parser) tests are supported by the
retirement design. C1.8/C2.7 (cutover wrappers) are supported, with the subagent half's
mechanism internally inconsistent (NF2). One acceptance-test tension newly noticed (NF3) on the
claimlint half — it is the same *shape* as F1 but lower severity, because the exit-code half of
the control already holds; only the error-message wording does not. Detail in §6/NF3.

## 6. New findings (all non-blocking; reconcile in the Phase 5 plan)

### NF1 (non-blocking — stale F2 wording in §2.2)

§2.2's closing sentence reads "The separation is structural (separate code paths, **separate
exit-code ranges**), not by convention." The "separate exit-code ranges" clause is the exact
phrase F2 flagged as hand-waving and contradicts the corrected block two paragraphs above ("The
exit codes overlap numerically on 0 and 1. The boundary is NOT numeric"). It is a copy-paste
leftover; the main block and §4 row are correct. **Must change (Phase 5 plan or a design wording
patch):** drop "separate exit-code ranges" from that sentence, e.g. "The separation is structural
(separate code paths, separate invocation context, no shared mutable state), not by convention."

### NF2 (non-blocking — subagent backward-compat mechanism is internally inconsistent)

The design gives two incompatible accounts of how old `bin/subagent` (DeepSeek) callers keep
working during cutover:

- **"There is a wrapper" (§3.1, §3.2 pt 3, §4):** §3.1 rationale column — "backward compat via
  wrapper that injects `--provider deepseek`"; §3.2 pt 3 — "Backward compatibility is via the
  `bin/subagent` *cutover wrapper*, which injects `--provider deepseek` so old invocations … still
  work unchanged"; §4 stability row — "`bin/subagent` wrapper injects `--provider deepseek` for
  backward compat."
- **"There is no wrapper" (§7 Phase A step 4):** "`bin/subagent` is REPLACED with the merged script
  (which requires `--provider` — existing callers must be updated to pass `--provider deepseek`;
  callers that are not updated get a hard error 'missing --provider,' which is loud, not silent)."

The "bin/subagent cutover wrapper" that §3.1/§3.2/§4 rely on does not appear as a file change
anywhere (the §3.1 row for `bin/subagent` is "add `--provider` flag parsing" = it becomes the
merged script, not a wrapper), and §7 step 4 explicitly says it does not exist. So the §4
subagent stability `0` partly rests on a phantom wrapper. This is the same *kind* of issue as F2
(a `−`→`0` / `0` quality claim that does not fully survive a read of the relevant section), but
the subagent stability was scored `0` (not a scope `−` mitigation), and the actual gate (C2.1) is
satisfied by the merged script directly, so it does not block. **Must change (Phase 5 plan must
pick one):** either (a) define the deepseek-injecting wrapper as a real file change (e.g. a
`bin/subagent` wrapper that calls a merged script located at a new path, mirroring the
`bin/ollama-subagent` wrapper) so §4's stability claim holds; or (b) drop the "wrapper injects
--provider deepseek" language from §3.1/§3.2/§4 and state plainly that old DeepSeek callers must
pass `--provider deepseek` during cutover (consistent with §7 step 4's "loud, not silent"), and
re-score the subagent stability honestly. The Phase 5 plan needs a single cutover mechanism; the
design currently describes two.

### NF3 (non-blocking — C1.1 RED-first control vs §1.2 default-verb=verify, on the claimlint half)

C1.1's RED-first positive control is: *"`bin/weizigo-claimlint no-such-verb` → exit code ≠ 0,
stderr names the unknown verb."* §1.2's backward-compat rule is: "if the first non-flag argument
is not a recognized verb, it is treated as a path argument and the `verify` verb is used." Under
§1.2, `weizigo-claimlint no-such-verb` runs `verify` on the path `no-such-verb` → `verify` errors
on a missing path (exit ≠ 0, stderr "no such file" or similar). So:

- **"exit code ≠ 0"** — satisfied (verify errors on the missing path).
- **"stderr names the unknown verb"** — **NOT** satisfied (stderr names the missing path, not
  "unknown verb: no-such-verb").

This is the same *shape* as F1 (a design behaviour vs a frozen acceptance test's required
control), but on the claimlint half — the half the F1 fix did not touch. The writer applied the
C2.1 lesson to the subagent half (make the flag required; unknown → hard error) but not the
parallel C1.1 case on the claimlint half (default-verb=verify swallows unknown verbs as paths).
It is **lower severity than F1** because the two sides agree the tool errors loudly (exit ≠ 0
holds; no silent success — this is C1.9 territory, satisfied); they disagree only on the
error-message wording ("unknown verb" vs "no such file"). The full behaviour contradiction that
made F1 blocking (success vs error) is absent here.

**Must change (Phase 5 plan must pick one):** either (a) refine §1.2's dispatch so a first
non-flag argument that is neither a recognized verb *nor an existing path* errors with
"unknown verb <arg>" (existing paths still run `verify` unchanged → backward compat preserved,
C1.1 satisfied) — a small clause the plan adds; or (b) refine C1.1's RED control to accept the
path-not-found error ("`no-such-verb` → exit ≠ 0" without requiring "names the unknown verb"),
argued-for in the Phase 5 plan since the merged binary never silently succeeds on a non-verb.
Either reconciles the design with C1.1 before Phase 6 build.

## 7. Bars — PASS

- **Landmark line** — present (close): "Landmark: advances `L4 (the ledger is clean)` …".
- **Human summary** — present (close): "Human summary:" paragraph.
- **Header** — names auditor (`glm-5.2/T436`), subject (round-2 re-audit of `04-design.md`, fix
  commit `3beda47`), date (2026-08-08), landmark. Complete.
- **Independence** — stated (§0 of this report); the auditor did not write the design or the
  round-1 audit, and re-read scope + acceptance + round-1 audit before verifying against source.

---

## Verdict summary

All three round-1 findings are genuinely fixed at their load-bearing core:

- **F1 (was BLOCKING): FIXED.** `--provider` is REQUIRED on the merged `bin/subagent`; a bare
  invocation exits non-zero naming "provider" — C2.1 is satisfied. Verified the "before" state at
  HEAD (no `--provider` flag today).
- **F2 (was BLOCKING): FIXED at core.** §2.2 and §4 now state the boundary as structural (overlap
  on 0/1, by-verb-meaning), not "separate numeric ranges." One stale phrase "separate exit-code
  ranges" survives in §2.2's closing sentence (NF1, non-blocking). The F3 secondary (verify exit
  code 3) is also fixed, with line citations.
- **F3 (was non-blocking): FIXED.** `isClaimIdToken` is in the §2.3 removal list; verified it is a
  genuine duplicate (`claimlint.zig:880` ↔ `claims_register.zig:252`, called at claimlint 907/1115).

Three new non-blocking findings remain, all reconcilable in the Phase 5 (plan) phase:

- **NF1** — §2.2 closing sentence still says "separate exit-code ranges" (stale F2 wording).
- **NF2** — subagent backward-compat mechanism is internally inconsistent: §3.1/§3.2/§4 reference
  a "bin/subagent cutover wrapper" injecting `--provider deepseek`, but §7 Phase A step 4 says
  `bin/subagent` is the merged script and old callers must update or get a hard error. No such
  wrapper is a file change. The plan must pick one mechanism.
- **NF3** — C1.1's RED-first control (`weizigo-claimlint no-such-verb` → stderr "names the unknown
  verb") is not satisfied by §1.2's default-verb=verify (a non-verb is treated as a path → verify
  errors on the missing path, naming the path not the verb). Same shape as F1 but lower severity
  (exit ≠ 0 already holds; only the error wording differs). The plan must reconcile (refine the
  dispatch to error on a non-verb non-path, or refine the C1.1 control).

**Phase 5 may proceed.** The design decides the boundary (one binary with verbs, not a shared
library; `bin/subagent` with REQUIRED `--provider`), retires claimlint's inline parser, and gives
concrete build/cutover plans. The three round-1 blocking/non-blocking findings are fixed. The
three new findings are non-blocking cutover/dispatch and wording details that the Phase 5 *plan*
exists to pin down — NF2 and NF3 are exactly "ordered, revertible steps" decisions, and NF1 is a
one-phrase wording patch.

---

**Landmark:** advances `L4 (the ledger is clean)` — the Phase 4 design passes re-audit: the three
round-1 findings (F1 `--provider` default vs C2.1; F2 exit-code-range hand-waving; F3
`isClaimIdToken` omission) are all genuinely fixed at their load-bearing core. What remains: the
Phase 5 plan reconciles three new non-blocking findings — a stale "separate exit-code ranges"
phrase (NF1), an inconsistent subagent backward-compat mechanism (wrapper-vs-must-update, NF2),
and a C1.1↔§1.2 tension on the claimlint half (NF3, the F1 shape applied to the verb dispatch) —
all small, all cutover/dispatch decisions the plan phase exists to settle.

**Human summary:** the Phase 4 design PASSES re-audit (pass with findings) — Phase 5 may proceed.
All three round-1 findings are real fixes: `--provider` is now REQUIRED on `bin/subagent`
(satisfying frozen test C2.1), the exit-code boundary is now stated as structural with overlap
on 0/1 (not "separate numeric ranges"), and `isClaimIdToken` is in the parser-retirement list (a
verified duplicate). Three new non-blocking findings for the Phase 5 plan: (NF1) one stale
"separate exit-code ranges" phrase survives in §2.2's closing sentence; (NF2) the subagent
backward-compat story is internally inconsistent — §3.1/§3.2/§4 claim a "bin/subagent cutover
wrapper" injecting `--provider deepseek` but §7 step 4 says there is no wrapper and old callers
must update or get a hard error (no such wrapper is a file change); (NF3) the claimlint half has
the F1 shape the writer fixed on the subagent half — C1.1's RED control wants
`weizigo-claimlint no-such-verb` to name "the unknown verb," but §1.2's default-verb=verify
treats a non-verb as a path, so the error names the missing path instead (lower severity than
F1: exit ≠ 0 already holds, only the wording differs). All three are small plan-phase decisions;
none blocks.