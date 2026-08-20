# T436 — RE-AUDIT of T428 Phase 4: `04-design.md` (round 2, independent re-audit)

**VERDICT: PASS WITH FINDINGS** — all three round-1 findings (F1, F2, F3) are genuinely fixed at
their load-bearing core; Phase 5 may proceed. Seven non-blocking findings remain (NF1–NF7): three
corroborate the prior round-2 audit (glm-5.2/T436, `8d2ab81`) and are already reconciled in the
Phase 5 plan and the implementation; four are new to this audit (NF4–NF7) — all doc-precision or
plan-step details, none blocking.

| | |
|---|---|
| Auditor | deepseek-v4-flash/T436 |
| Date | 2026-08-20 |
| Subject | `docs/infra/tool-consolidation/04-design.md` (writer: deepseek-v4-pro/T428.2; round-1 commit `956a34f`, fix commit `3beda47`) |
| Landmark | gate for `T428 (tool consolidation sprint)` Phase 4 → Phase 5 (re-audit after F1/F2/F3 fixes) |

**Provenance and independence.** A round-2 audit of the same subject already exists by
glm-5.2/T436 (`8d2ab81`, 2026-08-08), committed as this file's prior content; that row was never
closed on the kanban (claim blocked on `T428 in_progress`; the audit proceeded on the on-disk
document). This row was re-dispatched 2026-08-20 to close the gate through the kanban. This is an
**independent re-audit**: I did not read the prior round-2 audit's conclusions before deriving my
own (I verified each fix from source first), then compared. Where I agree, that is corroboration
by a second auditor; where I differ or add, the difference is named. The glm-5.2 audit text is
preserved in git at `8d2ab81`.

Method: re-read the Phase 2 scope (`02-scope.md`, audited PASS WITH FINDINGS by T433), the Phase 3
acceptance (`03-acceptance.md`, audited PASS WITH FINDINGS by T434), and the round-1 FAIL audit
(T435, `57f56de`), then re-verified the design's concrete claims against the source at `3beda47`
(the fix commit; it touches only `04-design.md`, 24+/17−) and at the cited `9a96f8b`. I also
checked the downstream state — the Phase 5 plan (`05-plan.md`) and the implemented artifact at
HEAD — because the round-2 audit's residual findings were to be reconciled there; the design doc
itself is byte-identical to `3beda47` at HEAD.

---

## 1. F1 re-audit — `--provider` default vs C2.1 — FIXED

**Round-1 finding (T435 F1, BLOCKING):** the design defaulted `--provider` to deepseek when the
flag was absent, directly contradicting frozen acceptance test C2.1 (`bin/subagent` without
`--provider` → exit ≠ 0, stderr says "provider") and scope §3.2. The fix commit claims
`--provider` is now REQUIRED, with backward compat via a wrapper that injects
`--provider deepseek`.

**Verified fixed at the load-bearing core.** The revised design makes `--provider` REQUIRED on the
merged script itself, in three places:

- §3.1 file-change row: "`--provider` is REQUIRED (missing → error, satisfying C2.1)".
- §3.2 pt 3: "A bare `bin/subagent` (no `--provider`) exits non-zero with 'missing --provider
  (deepseek\|ollama)' on stderr — satisfying C2.1 and scope §3.2."
- §4 predictability row: "`--provider` flag is REQUIRED (missing → error, satisfying C2.1);
  explicit providers, no silent default".

C2.1 is satisfied by the merged script's own behavior — no silent default anywhere. I re-verified
the "before" state at the fix commit: `bin/subagent` at `3beda47` is 205 lines and has no
`--provider` flag parser (the only match is the `ds-pi` subcommand's own `--provider deepseek`
argument at line 178 — a different thing). Line counts 205/248 match the design's §3.3 "before"
figure. So REQUIRED-`--provider` is a genuine new behavior, not a restatement of the status quo.

**F1 is fixed.** The one residual is not about C2.1 (which the merged script satisfies directly):
the *mechanism* of backward compat — a "bin/subagent cutover wrapper" that injects
`--provider deepseek` — is described in §3.1/§3.2/§4 but never defined as a file change, and §7
Phase A step 4 says there is no wrapper. That is NF2 below (corroborated; resolved in the plan
and implementation via `bin/subagent-ds`).

## 2. F2 re-audit — separation-of-concerns "separate exit-code ranges" hand-waving — FIXED at core (two residues: NF1, NF5)

**Round-1 finding (T435 F2, BLOCKING):** §2.2 proposed `verify` ∈ {0,1,2} and `absorb` ∈ {0,1}
(ranges overlapping on 0 and 1) yet claimed "separate exit-code ranges" and "no exit-code
collision"; the F4 mitigation the brief specifically asked about was hand-waving. The round-1
audit also asked (as its F3 secondary) that `verify` exit code 3 be included.

**Verified fixed in the load-bearing places.** The revised §2.2 Exit-codes block states the overlap
plainly and reframes the boundary as structural, not numeric:

> "The exit codes overlap numerically on 0 and 1. The boundary is NOT numeric — it is structural:
> separate code paths …, separate invocation context (the verb is the first argument, visible in
> argv), and no shared mutable state between invocations."

And §4's separation-of-concerns row is now consistent: "exit codes overlap numerically (0 and 1)
but the verb disambiguates … the `−` from scope is mitigated to `0` by structural separation, not
numeric separation." The brief's question 4 is now answered honestly.

**The exit-code *set* is right and the code-3 omission is fixed.** §2.2 now lists `verify`:
0/1/2/3 with the citation "lines 1246, 2342 at `9a96f8b`". I verified the set against source:
`9a96f8b:src/claimlint.zig` has exactly `exit(3)` at 1246 and 2342, `exit(2)` at 2343, `exit(1)`
at 2344, `exit(0)` at 2345. So {0,1,2,3} is the real convention and the design now includes all of
it. The `absorb` half (0 = proposed, 1 = error) is verified: all non-zero exits in
`9a96f8b:src/absorb.zig` are `exit(1)` (lines 469/475/497/504/531), success = 0.

**Residue 1 (NF1, corroborated):** §2.2's closing sentence (line 113) still reads "The separation
is structural (separate code paths, **separate exit-code ranges**), not by convention." — the exact
phrase F2 flagged, contradicting the corrected block two paragraphs above. Copy-paste leftover; the
main block and §4 row govern. Reconciled in plan step 1 (wording patch) — which was never applied
to the design doc (see §6).

**Residue 2 (NF5, new — the per-code *meanings* are misattributed):** the table labels "2 = usage/
IO error" and "3 = unparsed rows (lines 1246, 2342)". Verified against the cited source: **exit 2
is calibration failure** (`!cal_ok`, line 2343), not usage/IO error; and line 1246 — cited under
"3 = unparsed rows" — is the read/IO error ("cannot read {path}"), which *also* exits 3. So:
"2 = usage/IO error" is wrong (2 = calibration), and the 1246 citation belongs under the read/IO
meaning, not under "unparsed rows". The set {0,1,2,3} is correct; the meanings of 2 and the 1246
attribution are wrong. Practical risk: a Phase 7 control author who asserts "bad path → exit 2"
per the design would fail against the real binary (exit 3). (T435's round-3 audit independently
found the same — its F-1 — which corroborates this.) Detail in §6/NF5.

## 3. F3 re-audit — parser-retirement list omits `isClaimIdToken` — FIXED (one gate gap: NF7)

**Round-1 finding (T435 F3, non-blocking):** §2.3's removal list named 8 functions but omitted
`isClaimIdToken`, a verified duplicate of `claims_register.zig`'s `pub fn isClaimIdToken` — exactly
the silent-divergence shape the merge retires.

**Verified fixed.** §2.3 step 1 (line 121) now lists `isClaimIdToken` between `parseRegister` and
`claimIdOf`. I re-verified the duplicate is real at the fix commit:

- `src/claimlint.zig:880` — `fn isClaimIdToken(tok: []const u8) bool` (inline), called at 907 and
  1115.
- `src/claims_register.zig:252` — `pub fn isClaimIdToken(tok: []const u8) bool`.

Nine-function removal list now matches the verified duplicate set (claimlint 713–915:
`Register`, `parseStatus`, `parseNarrowed`, `parseRate`, `backtickSpans`, `parseRegister`,
`isClaimIdToken`, `claimIdOf`, `isQaId` — all nine are duplicated in `claims_register.zig` at
98/161/191/197/208/291/252/273/246). `isPathChar` (line 923) is correctly still NOT listed — it is
C2 path-token logic and is not exported by `claims_register.zig`. F3 is fixed. (Downstream: the
implementation at HEAD has retired all nine — `grep` for each inline `fn` returns 0; only the
`const Register = cr.Register` alias at line 486 remains. See §7.)

**Gate gap (NF7, new):** the frozen acceptance test that gates this very claim — C1.5 — enumerates
the duplicate set as "`parseRegister`, `parseStatus`, `parseNarrowed`, `parseRate`,
`backtickSpans`, `claimIdOf`, `isQaId`, or the `Register` struct" — **still omitting
`isClaimIdToken`** (as does scope §2.1's inventory at `02-scope.md`, which lists lines 713–915 but
skips 880, sitting between `backtickSpans`@753 and `claimIdOf`@903). The F3 fix repaired the
design's list (and the plan's step 3 and the implementation), but C1.5's named control
(`grep -c 'fn parseRegister'` = 0 + import present) would not detect `isClaimIdToken` staying
inline. Phase 7 should extend C1.5's grep to `fn isClaimIdToken` → 0 (an argued one-line addition
to the frozen test, which the acceptance doc permits). Detail in §6/NF7.

## 4. Full re-check against Phase 2 scope — PASS (no scope decision newly uncovered)

Re-checked every Phase 2 scope decision against the revised design. The F1/F2/F3 fixes did not
drop or newly violate any scope decision:

| Phase 2 scope decision | design coverage (round 2) | verdict |
|---|---|---|
| `weizigo-claimlint` IN (merge, `verify`/`absorb` verbs) | §1.1, §2.1–§2.4 | covered |
| `weizigo-absorb` IN (`absorb` verb) | §2.1 (runAbsorb rename, wrapper), §2.2 | covered |
| `bin/subagent` IN (`--provider` flag) | §3.1–§3.3 — `--provider` REQUIRED (C2.1 satisfied) | covered |
| `bin/ollama-subagent` IN (`--provider ollama`) | §3.1 wrapper | covered |
| `managent` OUT | §5.3; scope §3.3's "assess parser import" question answered: one binary, NOT a library (§1.1) — the Phase 4 decision scope asked for | non-interference stated |
| `argus` OUT | §5.3 (may consume parser output later via a `parse` verb — §5.2, deferred) | non-interference stated |
| `tools/gen-indices` ASSESS | §1.1, §5.2 (deferred; `parse` verb is a non-breaking future extension) | correctly deferred |
| `tools/dispatch_verify.py` OUT | §3.2 ("shared scaffold," `dispatch_verify` import preserved) | non-interference stated |
| `tools/runner` OUT | not touched | fine (orthogonal) |

No IN tool lacks a concrete design; every OUT/ASSESS has a non-interference statement or the
assessed decision. The parser-retirement list now covers every duplicated register-parser function
(F3 closed). Scope's two `−` quality entries (stability, separation of concerns) are mitigated to
`0` by concrete design choices — the mitigation is real for stability (wrappers, backward-compat
default verb) and for separation of concerns the boundary is now honestly stated as structural with
numeric overlap (F2 fixed at core; the residual NF1/NF5 are wording/precision, not scope).

## 5. Full re-check against Phase 3 acceptance tests — PASS WITH FINDINGS (NF3, NF4, NF7)

Re-checked the design against every Phase 3 acceptance test:

- **C2.1** (missing/unknown `--provider` → hard error): **resolved** by F1 (REQUIRED flag) — this
  was the blocking conflict.
- **C1.1 RED control** (`no-such-verb` → exit ≠ 0, stderr names the unknown verb): the design's
  §1.2 default-verb=verify still treats a non-verb as a path, so the error names the missing path
  ("cannot read no-such-verb", verified exit 3 at `9a96f8b:1246`) — **NF3** (corroborated). The
  exit-≠-0 half holds; only the "names the unknown verb" wording does not. Reconciled in plan
  step 2 and implemented (HEAD dispatch errors "unknown verb {v}" when the arg is neither a known
  verb nor an existing path — verified `src/claimlint.zig` HEAD lines ~1024–1031).
- **C1.1 acceptance** (`verify --help` / `absorb --help` → exit 0 and print usage; `--help` lists
  both verbs): **new finding NF4** — the design's dispatch (§2.2) recognizes only `absorb` and the
  help forms as verbs; `verify` is never a dispatched verb (it is the implicit default), so
  `weizigo-claimlint verify --help` treats "verify" as a path and errors, and `absorb --help`
  delegates `["--help"]` to `absorb.runAbsorb`, whose `--help` handling is unspecified (old
  `absorb` at `9a96f8b` has no help handling at all). Plan step 2 has the same gap (its
  recognized-verb set is {absorb, help forms}; `verify --help` → "unknown verb verify"). The
  implementation closed it by recognizing `verify` (and `c7`) as verbs. Detail in §6/NF4.
- **C1.2/C1.3** (byte-identical output): supported — same entry points, same code paths, paths
  resolved before dispatch (§8 risk 2); the plan's step 4 wires absorb identically.
- **C1.5** (single Zig parser): supported by the retirement design — with gate gap **NF7**
  (C1.5's enumerated list omits `isClaimIdToken`).
- **C1.6** (header corrected): §2.1 names exactly the stale line (`claims_register.zig:21`,
  verified: "Used by claimlint (checker) and absorb (knowledge-capture tool)" at `3beda47`) and
  the replacement wording. Covered.
- **C1.7** (stdout/stderr contract): preserved per verb (§4 transparency row; design §2.2 keeps
  `util.out`/`util.note` separation). Covered.
- **C1.8/C2.7** (cutover wrappers): `bin/weizigo-absorb` shell wrapper (§2.1) and
  `bin/ollama-subagent` Python wrapper (§3.1) match the acceptance tests; the subagent half's
  backward-compat mechanism is internally inconsistent — **NF2** (corroborated; resolved in plan
  step 6.4 as `bin/subagent-ds`, implemented at HEAD).
- **C1.9** (no silent success): supported — §2.3's post-merge guarantee ("if the register parser
  is wrong … structurally impossible") plus the T406 empty-parse hard error cited in scope §3.1.
  Covered.
- **C2.2/C2.3** (byte-identical provider behavior): design preserves each path's env vars, model
  handling (`--model` for ollama, inferred for deepseek), prompt construction (§3.2 pt 4). Covered
  at design level; plan step 5 executes the merge.
- **C2.4** (depth cap): shared main-body depth check before the provider branch (§3.2 pt 4:
  "checks depth before the provider branch") — structurally impossible to miss. Covered.
- **C2.5** (dispatch_verify for both paths): preserved ("shared scaffold … `dispatch_verify`
  import preserved", §3.2 pt 1). Covered.
- **C2.6** (3+2 regression scripts pass): plan step 5–6 keeps entry points resolvable. Covered at
  plan level.
- **C3.1–C3.3** (green commits, suite time, live-store): plan steps 6/7 (test run, tasks.json
  sha256). Covered at plan level.
- **C3.4** (help lists verbs/providers): design `printHelp` lists both verbs (§2.2); subagent
  `--help` lists both providers (§4 transparency row). Covered — with the NF4 dispatch caveat.
- **C3.5** (build.zig: old targets removed/aliased): §6 removes `absorb_exe`/`absorb_deploy`,
  verified against the `9a96f8b` before-state (`build.zig:688–711, 847`). Covered.

The C2.1 conflict (F1) is resolved; the remaining acceptance tensions are the three named above
(NF3 wording, NF4 help-reachability, NF7 gate list), all non-blocking and all already or readily
resolvable in the plan / Phase 7.

## 6. Findings

### Corroborated from the prior round-2 audit (re-verified independently)

- **NF1 (non-blocking — stale F2 wording, §2.2:113).** "The separation is structural (separate
  code paths, **separate exit-code ranges**), not by convention." — the exact phrase F2 flagged,
  contradicting the corrected block at §2.2 ("overlap numerically on 0 and 1 … NOT numeric").
  Plan step 1 (wording patch) reconciles it but was never applied to the design doc — the plan
  says "src/claimlint.zig (verb dispatch comment — or 04-design.md if the phrase is in the design
  doc)", and the phrase lives in the design doc, so step 1 as written targets the wrong file.
  **Worth one line in the plan:** patch `04-design.md` §2.2, not the code comment.
- **NF2 (non-blocking — subagent backward-compat mechanism internally inconsistent).** §3.1/§3.2/§4
  rely on a "bin/subagent cutover wrapper" injecting `--provider deepseek`; §7 Phase A step 4 says
  `bin/subagent` IS the merged script and old callers must update or get a hard error; and no such
  wrapper is a file change in §3.1's table. **Resolved downstream:** plan step 6.4 defines
  `bin/subagent-ds` as the real wrapper (verified present at HEAD, injecting
  `--provider deepseek`). The design text and the plan name different mechanisms; the artifact
  resolves the intent. Remaining nit: the design's §4 stability row cites "bin/subagent wrapper
  injects --provider deepseek" — the name should be `bin/subagent-ds` to match the plan.
- **NF3 (non-blocking — C1.1 RED control vs §1.2 default-verb=verify).** Design §1.2: "if the
  first non-flag argument is not a recognized verb, it is treated as a path argument and the
  `verify` verb is used." C1.1's RED control wants `no-such-verb` → stderr "names the unknown
  verb"; under §1.2 the error names the missing path instead (exit 3, "cannot read {path}").
  Lower severity than F1 (exit ≠ 0 already holds; only the wording differs). **Resolved
  downstream:** plan step 2 adds "neither a recognized verb nor an existing path → error 'unknown
  verb <arg>'"; implementation confirms (HEAD dispatch). The design doc's §1.2 text still lacks
  the "nor an existing path" clause — same family as NF1: plan/implementation correct, design text
  stale.

### New to this audit

- **NF4 (non-blocking — C1.1 acceptance half is not satisfiable from the design's dispatch:
  `verify --help` / `absorb --help` can't reach a usage screen).** C1.1's acceptance requires
  `bin/weizigo-claimlint verify --help` and `... absorb --help` to exit 0 and print usage. The
  design's §2.2 dispatch recognizes only `absorb` and the help forms as verbs; `verify` is the
  implicit default, so `verify --help` is read as "verify the path `verify`" → read error
  (exit 3, "cannot read verify"). `absorb --help` collects `["--help"]` and hands it to
  `absorb.runAbsorb`, whose `--help` handling the design never specifies — and old absorb at
  `9a96f8b` has no `--help` handling at all. Plan step 2 has the same gap: its recognized-verb
  set is {absorb, help/--help/-h}, so `verify --help` → "unknown verb verify" (error, not usage).
  The implementation closed it by adding `verify` (and later `c7`) to the recognized-verb set
  (`isKnownVerb`, HEAD `src/claimlint.zig`), so `verify --help` reaches the verify path with
  remaining flags. **Must change (plan step 2 needs one clause):** add "`verify` → run verify,
  passing remaining args" to the dispatch list, so `verify --help` exits 0 with usage — the
  acceptance test is currently satisfiable only by the implementation, not by the design+plan
  trail a Phase 6 builder would follow.
- **NF5 (non-blocking — §2.2 exit-code meanings misattributed; the set is right, the labels are
  wrong for 2 and partially for 3).** Design: "`verify`: 0 = clean, 1 = findings present,
  2 = usage/IO error, 3 = unparsed rows (lines 1246, 2342 at `9a96f8b`)". Verified: exit 2 at
  `9a96f8b` is **calibration failure** (`!cal_ok`, line 2343) — no usage/IO path exits 2; and the
  read/IO error ("cannot read {path}", line 1246) exits **3**, so the design's own cited line 1246
  belongs under "3 = read error", not "3 = unparsed rows" (2342 is unparsed rows). Correct table:
  `verify`: 0 clean, 1 findings, 2 calibration failure, 3 read/IO error or unparsed rows. Risk: a
  Phase 7 control asserting "unreadable path → exit 2" per the design would fail against the real
  binary (exit 3). (Independently corroborated by T435's round-3 F-1, which verified the same
  against both `9a96f8b` and the current tree.)
- **NF6 (non-blocking — §2.4 line-count prose disagrees with its own table by 45 lines).** Prose
  (§2.4): "3,200 + 657 − 300 + 45 ≈ 3,602"; table (§2.4): per-row nets −300/+15/+20/−20/0/−15,
  summing to **−300**, with the non-parser changes netting **0** → merged ≈ 3,557, not 3,602. The
  "+45" is the sum of the three positive-addition rows (imports 15 + verb dispatch 20 + absorb
  signature 10), omitting the countervailing removals (absorb boilerplate −30, build.zig −15 net,
  header 0). Cosmetic (both round to "~3.6k") but an internal arithmetic inconsistency of exactly
  the kind the F1–F3 fixes were about. Correct formula: 3,200 + 657 − 300 = 3,557.
- **NF7 (non-blocking — the F3 fix is not gated by the frozen acceptance test that owns it).**
  C1.5's duplicate-function enumeration omits `isClaimIdToken` (as does scope §2.1's inventory at
  `02-scope.md`, which skips line 880 between `backtickSpans`@753 and `claimIdOf`@903). The F3 fix
  landed in the design (§2.3), the plan (step 3), and the implementation (grep = 0 at HEAD), but
  C1.5's named control (`grep -c 'fn parseRegister'` = 0 + import match) would not detect
  `isClaimIdToken` regressing to an inline copy. **Must change (Phase 7):** extend C1.5's grep
  list with `fn isClaimIdToken` → 0 — a one-line argued addition to the frozen test, per the
  acceptance doc's amendment path.

## 7. Downstream corroboration (design → plan → artifact)

Because the sprint has since run Phases 5–8 and the consolidation was implemented (T437, hardened
T440, extended T482), I checked whether the design's decisions survived to the artifact — this
does not replace the design audit but it confirms the design was buildable:

- verb dispatch live at HEAD (`src/claimlint.zig`: help/absorb/c7/verify, unknown-verb error) —
  NF3 and NF4 resolved in code;
- parser retirement live (all nine inline functions gone; `cr`/`absorb` imports at
  `src/claimlint.zig:106–107`) — C1.5/C1.6 realized, F3's intent realized;
- `bin/subagent` REQUIRED `--provider` live (docstring "A bare call exits non-zero naming
  'provider' (C2.1)") — F1 realized;
- wrappers live: `bin/weizigo-absorb` (sh), `bin/ollama-subagent` (Python), `bin/subagent-ds`
  (NF2 realized);
- `build.zig` has no `absorb_exe`/`absorb_deploy`; `absorb`/`claims_register` are module imports —
  C3.5 realized in source (a stale pre-merge `zig-out/bin/weizigo-absorb` binary remains in the
  build output — T435 round-3 F-5; out of this gate's scope).

## 8. Bars — PASS

- **Landmark line** — present (close): "Landmark: advances `L4 (the ledger is clean)` …".
- **Human summary** — present (close): "Human summary:" paragraph.
- **Header** — names auditor (`deepseek-v4-flash/T436`), subject (round-2 re-audit of
  `04-design.md`, fix commit `3beda47`), date (2026-08-20), landmark. Complete.
- **Independence** — stated (§0): did not write the design or either prior audit; re-read scope +
  acceptance + round-1 audit; verified every fix from source at `3beda47`/`9a96f8b` before
  comparing to the prior round-2 audit.
- **Findings file** — `findings/T436-phase4-reaudit.json` (this audit's notes; prior auditor's
  version preserved in git at `8d2ab81`); context dump `findings/T436-context.json`.

---

## Verdict summary

All three round-1 findings are genuinely fixed at their load-bearing core:

- **F1 (was BLOCKING): FIXED.** `--provider` is REQUIRED on the merged `bin/subagent`; a bare
  invocation exits non-zero naming "provider" — C2.1 is satisfied by the script's own behavior.
  Verified the before-state at `3beda47` (205 lines, no `--provider` flag).
- **F2 (was BLOCKING): FIXED at core.** §2.2 and §4 state the boundary as structural (overlap on
  0/1, by-verb-meaning), not "separate numeric ranges"; the full exit set {0,1,2,3} is present
  with line citations. Two residues: NF1 (one stale "separate exit-code ranges" phrase survives at
  §2.2:113) and NF5 (the per-code meanings of 2 and the 1246 citation are misattributed — 2 is
  calibration, not usage/IO; 1246 is the read error, not unparsed rows).
- **F3 (was non-blocking): FIXED.** `isClaimIdToken` is in the §2.3 removal list (line 121);
  verified a genuine duplicate (`claimlint.zig:880` ↔ `claims_register.zig:252`, called at
  claimlint 907/1115). One gate gap: C1.5's frozen enumeration still omits it (NF7).

Seven non-blocking findings, none blocking Phase 5:

- **NF1** — stale "separate exit-code ranges" phrase (§2.2:113); plan step 1 targets the wrong
  file (the phrase is in the design doc).
- **NF2** — subagent backward-compat mechanism inconsistent in the design text (§3.1/§3.2/§4
  wrapper vs §7 step 4 no-wrapper); resolved downstream as `bin/subagent-ds` (plan step 6.4,
  implemented).
- **NF3** — C1.1 RED-control wording vs §1.2 default-verb=verify (design text); resolved
  downstream (plan step 2, implemented).
- **NF4** (new) — C1.1 *acceptance* half not satisfiable from the design+plan dispatch:
  `verify --help` / `absorb --help` can't reach a usage screen ("verify" is never a dispatched
  verb); implementation closed it; plan step 2 needs the `verify` clause.
- **NF5** (new) — verify exit-code meanings misattributed (2 = calibration, not usage/IO; 1246 =
  read error, not unparsed rows); set correct; Phase 7 controls must not assert "bad path → exit
  2".
- **NF6** (new) — §2.4 prose formula "+45" disagrees with its own table (net −300 → 3,557, not
  3,602); cosmetic.
- **NF7** (new) — C1.5's duplicate-function enumeration omits `isClaimIdToken`; the F3 fix is not
  gated by its own acceptance test; Phase 7 should extend the grep.

**Phase 5 may proceed.** The design decides the boundary (one binary with verbs, not a shared
library; `bin/subagent` with REQUIRED `--provider`), retires claimlint's inline parser, and gives
concrete build/cutover plans. All three round-1 findings are fixed at their core; the seven
residual findings are wording, attribution, arithmetic, or plan-step details — and the three
corroborated from the prior audit (NF1–NF3) are already resolved in the plan and the artifact.

---

**Landmark:** advances `L4 (the ledger is clean)` — the Phase 4 design passes re-audit (round 2,
independent): the three round-1 findings (F1 `--provider` default vs C2.1; F2 exit-code-range
hand-waving; F3 `isClaimIdToken` omission) are all genuinely fixed at their load-bearing core.
This audit corroborates the prior round-2 verdict (glm-5.2, `8d2ab81`) and adds four new
non-blocking findings: the C1.1 *acceptance* half is unsatisfiable from the design+plan dispatch
(`verify --help` can't reach usage — NF4), the verify exit-code meanings are misattributed
(2 = calibration, 1246 = read error — NF5), §2.4's prose arithmetic disagrees with its table
(NF6), and C1.5's gate omits `isClaimIdToken` (NF7). The corroborated NF1–NF3 are resolved in the
plan and the artifact. What remains: the Phase 5 plan absorbs NF4 (add the `verify` verb clause)
and NF1 (patch the design doc, not the code comment); Phase 7 extends C1.5's grep (NF7) and does
not assert exit 2 for IO errors (NF5).

**Human summary:** the Phase 4 design PASSES re-audit (pass with findings) — Phase 5 may proceed.
All three round-1 findings are real fixes, verified from source: `--provider` is now REQUIRED on
`bin/subagent` (frozen test C2.1 satisfied), the exit-code boundary is honestly stated as
structural with numeric overlap, and `isClaimIdToken` is in the parser-retirement list. This
independent re-audit agrees with the earlier round-2 audit (glm-5.2) and adds four small
non-blocking findings: (1) C1.1's other half — `verify --help`/`absorb --help` should print usage,
but the design (and the plan's step 2) never dispatch `verify` as a verb, so those invocations
error as path lookups (the implemented binary already fixed it); (2) the design's exit-code table
mislabels 2 as "usage/IO error" — in the real claimlint, 2 is calibration failure and read errors
exit 3; (3) §2.4's line-count prose (+45) disagrees with its own table (net −300, so ~3,557 not
3,602); (4) the frozen test that gates the single-parser claim (C1.5) omits `isClaimIdToken` from
its grep list, so the F3 fix isn't gated by it. The three findings the earlier audit raised are
all resolved in the Phase 5 plan and the shipped code. None of the seven blocks.
