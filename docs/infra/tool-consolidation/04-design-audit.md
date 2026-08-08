# T435 — AUDIT of T428 Phase 4: `04-design.md`

**VERDICT: FAIL** — Phase 5 may NOT proceed; three must-change items below (one is a direct
contradiction of a frozen acceptance test; one is the F4 mitigation the brief specifically asked
about). The design is mostly sound and the fix is small, but it cannot be the basis for a plan as
written.

| | |
|---|---|
| Auditor | glm-5.2/T435 |
| Date | 2026-08-08 |
| Subject | `docs/infra/tool-consolidation/04-design.md` (writer: deepseek-v4-pro/T428.2, commit `956a34f`) |
| Landmark | gate for `T428 (tool consolidation sprint)` Phase 4 → Phase 5 |

Independence is the mechanism: I did not write the design, and I re-read the Phase 2 scope
(`02-scope.md`, audited PASS WITH FINDINGS by T433) and the Phase 3 acceptance (`03-acceptance.md`,
audited PASS WITH FINDINGS by T434) before auditing, then re-verified the design's concrete claims
against the source at HEAD (`956a34f`). The Phase 4 question is *the boundary — one binary with
verbs, not a shared library — scored against the eight qualities.* A design that contradicts a
frozen acceptance test, or that hand-waves the one `−` the brief named, is a finding, not a quibble.

The kanban claim of this row was blocked (dependency `T428` still `in_progress`, same shape as the
sibling audits T433/T434); the human dispatched the audit directly and the document under audit
exists on disk, so the substantive work proceeded. That context is recorded here so the
Orchestrator can see it — same shape as T433/T434, recorded for the same reason.

---

## 1. Design decision stated — PASS

§1.1 decides the boundary — **one binary with subcommand verbs, not a shared library** — with a
stated rationale: a shared library would require a stable C ABI / Zig package interface, would
touch every consumer, and would be a migration rather than a merge (which strategy §4 ruled out).
The verb approach is a mechanical merge local to `src/claimlint.zig` and `build.zig`. This is a
decision (§1.1 picks the verb approach and rejects the library with reasons), not "describes
approaches." §5.1 re-binds it ("No shared library"). Question 1 answered.

## 2. Every Phase 2 scope decision covered — PASS (one parser-retirement omission — see §3/F3)

Re-checked each Phase 2 scope decision against the design's file-level treatment:

| Phase 2 scope decision | design coverage | verdict |
|---|---|---|
| `weizigo-claimlint` IN (merge, `verify`/`absorb` verbs) | §2.1–§2.4 (file table, verb dispatch, parser retirement, line counts) | covered |
| `weizigo-absorb` IN (`absorb` verb) | §2.1 (runAbsorb rename, wrapper), §2.2 dispatch | covered |
| `bin/subagent` IN (`--provider` flag) | §3.1–§3.3 | covered (but see F1 — the default contradicts C2.1) |
| `bin/ollama-subagent` IN (`--provider ollama`) | §3.1 wrapper | covered |
| `managent` OUT | §5.3 ("No managent or argus changes") | non-interference stated |
| `argus` OUT | §5.3 | non-interference stated |
| `tools/gen-indices` ASSESS | §1.1, §5.2 (deferred; `parse` verb is a non-breaking future extension) | correctly deferred, not committed |
| `tools/dispatch_verify.py` OUT | §3.2 ("shared scaffold," `dispatch_verify` import preserved) | non-interference stated |
| `tools/runner` OUT | not restated, but not touched | fine (orthogonal) |

No IN tool lacks a concrete design; every OUT/ASSESS has a non-interference statement. The one
gap is a missing function in the parser-retirement list (F3), not a missing scope decision.

## 3. Parser retirement concrete — PARTIAL (one function omitted — F3)

The design's central claim is retiring claimlint's ~300-line inline parser and importing
`claims_register.zig`. §2.1 and §2.3 describe it concretely: which functions are removed
(`Register` struct, `parseStatus`, `parseNarrowed`, `parseRate`, `backtickSpans`, `parseRegister`,
`claimIdOf`, `isQaId`), what replaces them (`const cr = @import("claims_register.zig")`,
`cr.parseRegister(...)`), and how call sites are updated (every `parseRegister(...)` →
`cr.parseRegister(...)`).

I re-verified the removal list against the source at HEAD:

```
src/claimlint.zig inline fns (lines):            claims_register.zig pub fns:
  713  const Register = struct                      98   pub const Register = struct
  723  fn parseStatus                               161  pub fn parseStatus
  738  fn parseNarrowed                             191  pub fn parseNarrowed
  744  fn parseRate                                 197  pub fn parseRate
  753  fn backtickSpans                             208  pub fn backtickSpans
  769  fn parseRegister                             291  pub fn parseRegister
  880  fn isClaimIdToken  ← NOT in design list      252  pub fn isClaimIdToken
  903  fn claimIdOf                                 273  pub fn claimIdOf
  915  fn isQaId                                    246  pub fn isQaId
```

`isClaimIdToken` is a `pub fn` in `claims_register.zig` (line 252) AND a duplicate inline `fn` in
`claimlint.zig` (line 880, called at 907 and 1115). It is exactly the kind of silent-divergence
duplicate the merge exists to retire, and the design's removal list omits it. (Conversely,
`isPathChar` at line 923 is correctly NOT listed — it is C2 path-token logic, not a register-parser
function, and `claims_register.zig` does not export it; it must stay. The design gets that one
right.) The line-range claim "functions at lines 713–930" is slightly over-inclusive (it sweeps in
`isPathChar`/`pathTokens`, which are C2 logic that stays) but the net-line-count estimate (~300)
is in the right neighbourhood. See F3.

The post-merge guarantee (§2.3) — "if the register parser is wrong, the T406 shape is structurally
impossible" — is the right claim and is concretely argued (both verbs call the same
`cr.parseRegister()`). The §2.3 "verify the two `Register` structs are identical before removal,
else the design fails (strategy §7 refutation)" is the correct guard and is carried into §8 as a
risk. Sound.

## 4. Separation-of-concerns boundary (F4 from Phase 3 audit) — NOT DELIVERED (F2)

The Phase 3 audit (T434 F4) found the verb-boundary "separate exit codes, no shared mutable state"
under-tested and asked Phase 4 to specify the boundary concretely. §2.2 attempts this:

- **Separate code paths** — YES. The dispatch routes `absorb` to `absorb.runAbsorb` and everything
  else to `runVerify`; no code path reaches both.
- **No global mutable state** — YES, plausibly. "Each invocation parses args, allocates from the
  page allocator, runs one verb, and exits." The design asserts no shared mutable state persists
  between invocations. (The acceptance suite still does not test this — F4 in T434 was an
  acceptance-test gap; the design cannot close it, only Phase 3 can. But the design's structural
  argument is reasonable.)
- **Separate exit-code RANGES** — **NO.** §2.2 states: `verify` exits 0 (clean) / 1 (findings) /
  2 (usage/IO); `absorb` exits 0 (proposed) / 1 (usage/IO). These **overlap numerically** on 0 and
  1. The design then writes "The two sets of exit codes are disjoint in meaning; the verb is the
  scope… no exit-code collision." But there IS a numeric collision (both use 0; both use 1). The
  design's claim is "disjoint in meaning," which is true, but the brief's question 4 asked for
  "separate exit-code ranges" and the §4 separation-of-concerns row claims the `−` is "mitigated to
  0 by the concrete verb-dispatch contract." Overlapping ranges are not "separate ranges." See F2.

This is the one `−` quality the brief specifically asked about (question 7: "Is each mitigation
concretely described, or is this hand-waving?"). The mitigation is partly hand-waving: it claims
"separate exit-code ranges" and "no exit-code collision" while proposing ranges that share 0 and 1.

## 5. Backward compatibility — PARTIAL (the subagent half contradicts C2.1 — F1)

- **claimlint default verb = `verify` (§1.2):** sound. The old `weizigo-claimlint` had no verb; the
  merged binary treats a non-verb first argument as a path and runs `verify`. Existing invocations
  (shell scripts, pre-commit hook, regression scripts, GTP wrappers) work unchanged. Good.
- **`bin/weizigo-absorb` wrapper (§2.1):** `exec bin/weizigo-claimlint absorb "$@"` + deprecation on
  stderr. Matches C1.8. Good.
- **`bin/ollama-subagent` wrapper (§3.1):** Python passthrough to `bin/subagent --provider ollama`.
  Matches C2.7. Good.
- **subagent `--provider` default (§3.1, §3.2 pt 3, §4):** the design defaults to **deepseek when
  `--provider` is absent** ("backward compatibility with old `bin/subagent`"). This **directly
  contradicts frozen acceptance test C2.1**, whose RED-first control is: *"`bin/subagent` without
  `--provider` → exit code ≠ 0, stderr says 'provider'."* It also contradicts scope §3.2
  ("a user who runs `bin/subagent` without `--provider` should get an error, not a cryptic API
  failure"). The design chose backward-compat and silently violated C2.1 without acknowledging
  the conflict or arguing for C2.1's retirement. See F1 — this is the blocking finding.

## 6. Cutover plan — PASS

§7 states two cutover lines: Phase A (build merged binary; `bin/weizigo-absorb` and
`bin/ollama-subagent` become wrappers; `zig build test` green with wrappers in place), Phase B
(remove the wrappers in a separate commit after every console updated, so `git revert` of the
removal is trivial). These are stated cutover lines, not a surprise. Matches brief §Bar 2 and the
scope §5 cutover rule. (The Phase 3 audit noted wrapper *removal* is a Phase 5/6 step not an
acceptance test — the design correctly puts it in the plan, not the tests.)

## 7. Eight-quality score honest? — PARTIAL (one `−`-to-`0` is hand-waving — F2)

The scope had two `−` entries (stability, separation of concerns), both on the claimlint+absorb
merge. The design claims both mitigated to `0`:

- **Stability `−` → `0`:** the cutover half is concretely mitigated (wrappers + backward-compat
  default verb = `verify`). The "3,900-line binary, concentration of failure" half is addressed
  only by reference to C1.9 (no silent success) — which the Phase 3 audit accepted as the
  structural mitigation. Reasonable, though the design §4 stability row does not name C1.9; the
  reader has to infer it. Borderline-concrete.
- **Separation of concerns `−` → `0`:** NOT concretely delivered. The row claims mitigation by "a
  concrete verb-dispatch contract (§2.2)" with "separate exit codes" — but §2.2's exit codes
  overlap on 0 and 1, so the "separate" claim is loose. This is the F2 hand-waving. The `−` is
  arguably still a `−`, not a `0`.

No `−` is hidden (both are named and argued), which is honest in spirit; but one of the two
"mitigated to 0" claims does not survive a read of §2.2. Question 7 answered: partly hand-waving.

## 8. Migration risks assessed — PARTIAL (the load-bearing risk is the one that bites — F1)

§8 names five risks with likelihood/impact/mitigation. The strongest is row 1 (the two
`parseRegister` implementations differ → merge becomes a rewrite → strategy §7 refutation), which
is exactly the right load-bearing risk and is carried into §2.3 as a pre-removal guard. Good.

Risks NOT named that should be:

- **The `--provider` default-vs-C2.1 conflict itself (F1).** The design does not flag that its
  backward-compat choice violates a frozen acceptance test. This is the highest-impact omission:
  it is a contradiction with the gate, not merely a migration risk.
- **`verify` exit code 3.** The actual `claimlint.zig` uses exit code 3 (line 1246 usage error;
  line 2342 unparsed rows). §2.2's "verify: 0/1/2" omits 3, so the verb-dispatch contract
  under-states `verify`'s actual exit set. This matters for the "disjoint ranges" claim (the real
  `verify` set is {0,1,2,3}, even more overlapping with `absorb`'s {0,1}) and for any Phase 7
  control that asserts a specific exit code.
- **Default-verb path/verb collision.** §1.2 treats a non-verb first argument as a path. A
  findings directory or file literally named `absorb` or `help` would be intercepted as a verb.
  Low likelihood (no such path in the tree today) but the design does not acknowledge it.

## 9. Build system changes concrete — PASS

§6 shows actual `build.zig` changes: remove `absorb_exe` and `absorb_deploy`, add `absorb` and
`claims_register` as module imports on `claimlint_exe`, drop `weizigo-absorb` from deploy. I
verified the "before" state at HEAD: `claimlint_exe` imports only `version` (line 682);
`absorb_exe` imports `version` and `claims_register` (lines 697–698); `absorb_deploy` exists (line
708) and the `deploy-absorb` step (line 710) depends on it. The design's "after" matches what
would actually change. Concrete and accurate. (The design's `addImport` snippet uses
`b.createModule(.{ .root_source_file = ..., .target = target, .optimize = optimize })`, which
matches the existing pattern at line 698.) Question 9 answered.

## 10. Process bars — PASS

- **Landmark line** — present (close): "Landmark: advances `L4 (the ledger is clean)`…"
- **Human summary** — present (close): "Human summary:" paragraph.
- **Header** — names writer (`deepseek-v4-pro/T428.2`), phase (4 of 8 — design), date (2026-08-08),
  commit (`956a34f`). Complete.
- **"What the design does NOT do" (§5) vs scope OUTs** — largely matches: no shared library, no
  `parse` verb yet, no managent/argus changes, no `tasks.json` schema changes, no regression
  rewrites. The scope's OUT list also names the engine, claim semantics, and the assertion-ledger
  design; the design does not restate these three, but it does not touch them either. Minor
  framing gap, not a defect.

---

## Findings

- **F1 (BLOCKING — design contradicts frozen acceptance test C2.1).** §3.1, §3.2 pt 3, and §4
  default `--provider` to **deepseek when the flag is absent** ("backward compatibility with old
  `bin/subagent`"). C2.1's RED-first control is *"`bin/subagent` without `--provider` → exit ≠ 0,
  stderr says 'provider'"* and scope §3.2 says a bare `bin/subagent` "should get an error, not a
  cryptic API failure." The design silently chose backward-compat and violated C2.1 without
  acknowledging the conflict or arguing for C2.1's retirement (the acceptance doc allows retirement
  only "after argued review"). **Must change:** either (a) make `--provider` required and have the
  `bin/subagent` *cutover wrapper* inject `--provider deepseek` so old invocations still work
  (satisfies both C2.1 and backward-compat), or (b) explicitly argue for retiring/reframing C2.1's
  missing-flag-is-an-error control. As written, Phase 5 cannot plan the subagent merge because the
  design and the gate disagree on a one-line behaviour.
- **F2 (BLOCKING — the F4 separation-of-concerns mitigation is hand-waving).** The brief's
  question 4 asked whether the design specifies "separate exit-code ranges" concretely. §2.2
  proposes `verify` ∈ {0,1,2} and `absorb` ∈ {0,1} — these **overlap on 0 and 1** — yet §2.2 claims
  "no exit-code collision" and §4 claims the `−` is "mitigated to 0 by the concrete verb-dispatch
  contract." Overlapping numeric ranges are not "separate ranges," and "no exit-code collision" is
  false (0 and 1 collide). The real claim ("disjoint *meaning*, scoped by verb") is defensible, but
  the design overstates it as "separate ranges / no collision." **Must change:** either (a) give
  `absorb` a genuinely disjoint range (e.g. 10/11) so the boundary is numeric, not semantic, or
  (b) drop the "separate exit-code ranges / no collision" language and state plainly that the
  boundary is by-verb-meaning (and note that this leaves F4's "distinct exit codes" acceptance
  request unmet — which is Phase 3's gap to close, not the design's to假装-solve). As written the
  `−`→`0` claim does not survive a read of §2.2.
- **F3 (non-blocking — parser-retirement list omits `isClaimIdToken`).** §2.3's removal list names
  `Register`, `parseStatus`, `parseNarrowed`, `parseRate`, `backtickSpans`, `parseRegister`,
  `claimIdOf`, `isQaId` but omits `isClaimIdToken` (claimlint line 880), which is a verified
  duplicate of `claims_register.zig`'s `pub fn isClaimIdToken` (line 252) and is exactly the
  silent-divergence shape the merge retires. (`isPathChar`, line 923, is correctly NOT listed — it
  is C2 path-token logic, not a register-parser function, and `claims_register.zig` does not
  export it.) **Must change:** add `isClaimIdToken` to the §2.3 removal list and update its call
  sites (claimlint lines 907, 1115) to `cr.isClaimIdToken`. Also correct §2.3's "verify: 0/1/2" to
  include exit code 3 (claimlint uses 3 for usage error and unparsed rows — lines 1246, 2342).

The design is otherwise sound: the one-binary-with-verbs decision is decided (not described), the
parser-retirement intent is concrete, the cutover has stated lines, the build-system changes are
concrete and accurate against HEAD, and the OUT/ASSESS scope is respected. F1 and F2 are the two
that block: F1 is a direct contradiction of a frozen acceptance test, and F2 is the F4 mitigation
the brief specifically asked about, delivered as overlapping ranges labelled "separate." Both are
small fixes (F1 is a one-line behaviour + wrapper tweak; F2 is a wording or range choice), so a
revised design should clear Phase 5 quickly.

---

**Landmark:** advances `L4 (the ledger is clean)` — the Phase 4 design decides the boundary (one
binary with verbs, not a shared library) and is mostly concrete, but FAILS this gate on two items:
the subagent `--provider` default contradicts frozen acceptance test C2.1 (F1), and the F4
separation-of-concerns "separate exit-code ranges" mitigation is hand-waving — the proposed ranges
overlap on 0 and 1 (F2). A third non-blocking finding: the parser-retirement list omits
`isClaimIdToken`, a verified duplicate. What remains: the writer revises §2.2 (exit codes) and
§3.1/§3.2 (`--provider` default) to satisfy C2.1 and deliver a real boundary, adds `isClaimIdToken`
to §2.3, and re-submits for re-audit before Phase 5 (plan).

**Human summary:** the Phase 4 design FAILS audit — Phase 5 may not proceed yet. The design
correctly decides the boundary (one Zig binary with `verify`/`absorb` verbs, not a shared library;
`bin/subagent` with `--provider`), retires claimlint's inline parser in favour of
`claims_register.zig`, and gives concrete build/cutover plans. But two items block: (1) the design
defaults `--provider` to deepseek when the flag is missing, which directly contradicts frozen
acceptance test C2.1 (missing flag must be a hard error) and scope §3.2 — the design chose
backward-compat and silently violated the gate without arguing for C2.1's retirement; (2) the
separation-of-concerns `−` is claimed "mitigated to 0 by separate exit-code ranges" but the
proposed exit codes (`verify` 0/1/2, `absorb` 0/1) overlap on 0 and 1 — the "separate ranges / no
collision" claim is hand-waving, and this is the F4 mitigation the brief specifically asked
about. A third non-blocking finding: the parser-retirement list omits `isClaimIdToken`, a verified
duplicate of a `claims_register.zig` public function. All three are small fixes; a revised design
should clear Phase 5 on re-audit.