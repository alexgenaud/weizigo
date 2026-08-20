# T434 — AUDIT of T428 Phase 3: `03-acceptance.md`

**VERDICT: PASS WITH FINDINGS** — Phase 4 may proceed. Six findings (N1–N6), none blocking.

| | |
|---|---|
| Auditor | deepseek-v4-flash/T434 |
| Date | 2026-08-20 |
| Subject | `docs/infra/tool-consolidation/03-acceptance.md` (writer: deepseek-v4-pro/T428.2; header commit measured at `4134980`) |
| Prior audit | glm-5.2/T434, 2026-08-08, committed `7f6f40a` — preserved in git history; **this is an independent re-audit**, not a review of that one |
| Landmark | gate for `T428 (tool consolidation sprint)` Phase 3 → Phase 4 |

**Provenance note (why this file is being rewritten).** The deliverable path already held the
2026-08-08 audit by glm-5.2/T434; that row was never closed in the kanban and was re-dispatched to
me (deepseek-v4-flash/T434) on 2026-08-20. The prior audit remains fully recoverable at commit
`7f6f40a`. I did not read that audit before forming my verdict; where my findings agree with its
F-numbers I say so with my own evidence. The brief's header template said "glm-5.2/T434"; the
kanban's recorded identity for this row is `deepseek-v4-flash/T434`, which is what I use.

**Method.** Every pre-merge claim in the acceptance document was re-derived at the doc's own
measured commit `4134980` via `git show 4134980:<path>` — the merge has since been implemented
(T437, `8ce3270`; T440 `3aaffb6`; T482 `ec7c3b7`), so the current working tree is *not* the state
the document describes, and judging the document against it would be anachronistic. Where a
later-phase consequence is cited (N4), it is cited as consequence evidence only, at commit
`3beda47` (design) / `f3ee909` (plan) / HEAD.

---

## 1. Phase 3 question answered — PASS

The document lists 22 concrete acceptance tests (§4 table), each with an acceptance gate naming a
command, an exit code, or an observable output, and most with a named RED-first control. The
preamble ("Phase 3 before Phase 4 is deliberate and not negotiable… written against the
*requirements*, not against any design") is the correct statement of the phase's purpose, and §5
makes Phase 7's reporting obligations explicit (RED result, GREEN result, first-green commit,
script reuse/retirement). These are tests you could run, not aspirations. The RED-first
*discipline* is imperfect in detail (N1–N3, §3) but the load-bearing property — a frozen,
named, runnable suite before design — holds.

## 2. Scope coverage — PASS (every scope decision covered; OUT/ASSESS correctly untested)

Each row of the Phase 2 §4 summary table (`02-scope.md`, audited by T433) checked against the
acceptance doc:

| Phase 2 scope decision | scope action | acceptance coverage | verdict |
|---|---|---|---|
| `weizigo-claimlint` IN | one Zig binary, `verify`/`absorb` verbs | C1.1–C1.9 (9 tests) | covered |
| `weizigo-absorb` IN | same binary, `absorb` verb | C1.1, C1.3, C1.4, C1.8, C1.9 | covered |
| `bin/subagent` IN | one Python script, `--provider` flag | C2.1–C2.7 (7 tests) | covered |
| `bin/ollama-subagent` IN | same script, `--provider ollama` | C2.1, C2.3, C2.4, C2.6, C2.7 | covered |
| `managent` OUT | no merge; may gain parser import in Phase 4 (assess) | no test assumes managent merged — only C3.3's `tasks.json` hash, which *protects* the store | correctly NOT tested |
| `argus` OUT | no merge; may consume parser output in Phase 4 (assess) | **zero mentions** of argus in the acceptance doc (grep-verified) | correctly NOT tested |
| `tools/gen-indices` ASSESS | may consume merged parser output in Phase 4 | **zero mentions** (grep-verified); deferred to Phase 4 | correctly deferred |
| `tools/dispatch_verify.py` OUT | already shared; used as-is | C2.5 (still called for both paths) | covered |
| `tools/runner` OUT | orthogonal | no test | correct (orthogonal) |

`grep -niE 'managent|argus|gen-indices' docs/infra/tool-consolidation/03-acceptance.md` returns
only lines 213/216 — the C3.3 no-live-store guard. No test treats managent, argus, or
gen-indices as a merge target. The OUT/ASSESS handling is clean.

## 3. RED-first discipline — PARTIAL (four controls mislabeled or circular; nine "—" correctly specified)

The §4 summary table carries 13 RED-first markers and 9 "—" entries (A0, C1.7, C1.9, C2.5,
C3.1–C3.5) — re-derived by grep, consistent between summary and body. I read every RED-first
control against the pre-merge state at `4134980`.

**Sound RED-first controls (falsifiable, named, runnable pre-merge):**

- **C1.1** — verified: pre-merge `main()` (`src/claimlint.zig:1232`) has no verb system; any
  non-`--` argument is assigned to `claims_path`, so `bin/weizigo-claimlint no-such-verb`
  fails with `claimlint: cannot read no-such-verb` (exit 3), *not* an unknown-verb error. RED
  (no verb error) → GREEN (verb error). Sound.
- **C1.3** — the planted-difference shape ("with different CLAIMS.md copies, outputs differ"):
  this tests the *diff harness* detects a real difference, runnable pre-merge with the old
  binaries alone. The right shape for RED-first. Sound.
- **C1.5** — verified: `git show 4134980:src/claimlint.zig | grep -c 'fn parseRegister'` returns
  **1**, and its imports are `std`/`version`/`util.zig` only (no `claims_register.zig`). The
  strongest control in the document. Sound.
- **C1.6** — the RED is in the summary table only, not the body (N6); the implied control is
  falsifiable and verified: at `4134980` the header reads "Used by claimlint (checker) and
  absorb (knowledge-capture tool)" — stale.

**Findings on RED-first:**

- **N1 (circular: C1.2, C2.2, C2.3 — agrees with the 2026-08-08 audit's F1).** Each is stated as
  "old vs merged differ." But Phase 3 precedes Phase 4 by the document's own preamble — *no merged
  artifact exists* at the point these tests are written, and none exists "before the fix" that
  Phase 7 is supposed to show RED against. As written, the control is the GREEN test stated
  backwards: it can be demonstrated only after the merge exists, at which point a correct merge
  produces *no* diff, so the RED can never be shown unless a deliberately broken intermediate is
  constructed. The falsifiable form is the one C1.3 already uses: plant a real difference (a
  deliberately divergent input, or an unstripped version line) and show the normalization/diff
  harness catches it. (Fairness: a charitable reading — "first merged build before the
  version-line normalization fix" — is executable at Phase 7, but then the RED demonstrates
  build-identity noise, not merge correctness, and the doc never says this is the intended
  sequence.) The underlying acceptance properties (byte-identity after normalization) are sound;
  only the RED-first specification is circular.
- **N2 (green-before-fix mislabeled: C2.4 — agrees with F2).** Verified at `4134980`: *both* old
  scripts carry `MAX_DEPTH = 3` and the REFUSED exit; and `tools/regression-depth-enforcement.sh`
  (seeded-1/2/3) already asserts the refusal on both paths. The behavior C2.4's "RED first"
  claims to demonstrate is GREEN pre-merge — the test passes without the merge. The test has a
  real cutover purpose (the invocation spelling changes to `--provider`), but it is an invariant
  assertion, not a RED-first control; labeling it "RED first" collapses the RED/GREEN
  distinction §5 depends on. Phase 7 should report it as an invariant assertion (the brief
  explicitly permits this).
- **N3 (C1.9 — the project's central defect shape — missing its available RED; agrees with F3,
  sharpened).** C1.9 ("no silent success") is the standing defect shape (QA-023 chain; the
  2026-08-07 tooling rule: "the tool reported success while doing nothing"), yet its RED-first
  column is "—". A RED is not merely available — it is sharp. Verified at `4134980`: claimlint's
  *inline* `parseRegister` has **no empty-register hard error** — a register with a header and 0
  data rows parses to `rows = .empty, unparsed = .empty`, and `main` exits 3 only when
  `unparsed > 0`; an empty register exits **0**. So pre-merge, `weizigo-claimlint <0-row
  register>` is a silent success — the exact T406 shape the merge is supposed to kill. Phase 7
  can show this RED on the current pre-merge binary right now. This is the single cheapest and
  most load-bearing control in the suite, and the document leaves its RED implicit.

**Green baselines mislabeled as RED in the summary table (minor framing, folded into N2's
point):** C1.4, C1.8, C2.6, C2.7 state "pre-merge each passes" / "old binary works" — these are
baseline assertions, not RED controls. Acceptable as invariants; the table should not list them
in the RED-first column.

## 4. Union-of-suites bar — PASS (A0 present and crisp; baseline arithmetic muddled — N5)

A0 explicitly mandates: merged suite count ≥ sum of the individual suites; no control removed
unless it tests a retired entry point; the cutover case is a *substitution* (a test that checked
`bin/ollama-subagent` exists becomes a test that `bin/subagent --provider ollama` works); §5
requires Phase 7 to report exact before/after counts and justify retirements. The bar is present
and crisp. The baseline it measures against is not: the §0 table double-lists the two shared
scripts (see N5), so "the sum" is ambiguous without Phase 7 deduplication — and the sibling
Phase 7 stub (`07-test.md` at `f3ee909`) shows the ambiguity propagating (it deduplicates to 4
for the subagent pair but writes ollama's row as "2 (1 own + 1 shared)" when the shared set has
2 scripts). The A0 *mechanism* is sound; the *baseline* needs one deduplicated statement.

## 5. The eight qualities — PARTIAL (one `−` under-pinned: separation of concerns)

The brief asks specifically whether the Phase 2 eight-quality `−` entries are tested:

- **Stability `−` (claimlint+absorb: 3,900-line binary, cutover wrappers) → C1.8 + C1.9.** The
  cutover-wrapper half is tested (C1.8: `bin/weizigo-absorb` becomes a thin wrapper calling
  `bin/weizigo-claimlint absorb "$@"` with a deprecation notice on stderr and identical result).
  The "3,900-line binary, concentration of failure" half is not directly testable as an
  acceptance property, but C1.9 (no silent success) is the structural mitigation — a parser
  defect now fails hard in both verbs. Covered, reasonably.
- **Separation of concerns `−` (verify/transform in one binary) → C1.1 + C1.7 — PARTIAL, see
  N4.** Phase 2 §3.1 made the merge's acceptability conditional on a crisp verb boundary:
  "separate exit codes, separate stderr channels, and no shared mutable state between
  invocations." C1.1 tests verb existence + help; C1.7 tests the stdout/stderr contract — but
  only for the `verify` verb (its gate names `verify` twice; the prose claims "both verbs"). The
  boundary's *existence* is pinned; its *crispness* — separate exit codes per verb, no shared
  mutable state — is not. And the consequence has already materialized: `04-design.md` §3.1
  chose numerically *overlapping* exit codes (0/1) with a structural justification, a choice the
  scope's "separate exit codes" clause would have prohibited had any test pinned it (N4).

## 6. Precedent compliance — PASS

The §10 "managent writes / argus reads" precedent (assertion-ledger spec; registration/display
boundary). No acceptance test assumes managent or argus was merged — the only managent reference
(C3.3) is the no-live-store guard, which *protects* the store rather than consuming or merging
it, and argus/gen-indices appear zero times. Precedent honored.

## 7. No-live-store — PASS

C3.3 states the mandate broadly ("every exercise uses `MANAGENT_STORE`; before and after every
exercise, `tasks.json` verified byte-identical") and gives a verifiable gate: Phase 7 includes a
`sha256sum` of `docs/infra/managent/tasks.json` before/after the test run; the hashes match. The
verifiable gate is the test-run hash; the broader "every exercise" mandate is a Phase 6 process
rule, not something Phase 7 can fully audit. Right shape; directly prevents the T425 shape. (Minor
note M2.)

## 8. Completeness — gaps (one substantive, the rest minor)

- **N4 (substantive: the verb-boundary contract from scope §3.1 is only half-pinned).** Scope
  §3.1's "separate exit codes, separate stderr channels, no shared mutable state" — C1.1 +
  C1.7 cover verb existence and (for `verify` only) the stdout/stderr channel. "Separate exit
  codes per verb" and "no shared mutable state between invocations" are not acceptance-tested.
  Consequence evidence: `04-design.md` §3.1 (commit `3beda47`) explicitly relaxes exit-code
  separation — "The exit codes overlap numerically on 0 and 1. The boundary is NOT numeric — it
  is structural" — and cites F4 by name ("This design explicitly addresses F4"). The acceptance
  suite's silence is what made that relaxation free: the design had to argue nothing, because no
  test existed to contradict it. Whether the structural reading is acceptable is Phase 4's call
  (it passed audit in T436); the audit point here is that the acceptance suite did not carry the
  scope's own condition into a test, so the condition was negotiable-by-absence rather than
  negotiable-by-argument. This is the one gap I would have asked Phase 3 to close before design.
- **N3 (C1.9's missing RED) — see §3.** The most important test in the suite lacks its RED
  specification although the RED is runnable today.
- **Minor M1: "old binary" provenance.** C1.2/C1.3/C2.2/C2.3 compare against "the old binary"
  at Phase 7, after the merge has replaced it in place (same path names). The doc never states
  how the old binaries are obtained; the answer is trivially available (rebuild from the
  committed pre-merge tree — the doc's own §0 names `9a96f8b`/`4134980` as the baseline) but
  should be stated so Phase 7's comparison is apples-to-apples.
- **Minor M2: C3.3's verifiable gate is the test run only.** See §7. Process note, not a gap.
- **Minor M3: wrapper *removal* is not pinned.** Scope §5 says the cutover wrappers are "removed
  in a separate commit after every console has been updated." C1.8/C2.7 pin the transition state
  (wrappers work and deprecate); nothing pins the eventual removal. This is correctly a Phase
  5/6 step rather than an acceptance property — noted for completeness, not a finding.

## 9. Process bars — PASS

- **Landmark line** — present (close): "Landmark: advances `L4 (the ledger is clean)`…".
- **Human summary** — present (close): "Human summary:" paragraph.
- **Header names writer and commit** — names Writer (`deepseek-v4-pro/T428.2`); "Commit measured
  at `4134980`" verified to exist and to be the Phase 2 audit-fix commit. The Audit slot reads
  "pending — row to be registered and dispatched," which is correct: the auditor names themself
  in *this* audit doc.
- **22 tests claimed — counted accurately.** §4 has exactly 22 rows (`grep -cE '^\| (A0|C[12]\.[0-9]|C3\.[0-9])'` → 22): A0 (1) + C1.1–C1.9 (9) + C2.1–C2.7 (7) + C3.1–C3.5 (5). 13 carry a RED-first marker, 9 are "—" (A0, C1.7, C1.9, C2.5, C3.1–C3.5), consistent between summary and body. One arithmetic caveat inside C2.6's heading — see N5.

---

## Findings

- **N1 (non-blocking; RED-first circular as written: C1.2, C2.2, C2.3).** "Old vs merged differ"
  cannot be demonstrated before the fix because the merged artifact does not exist at Phase 3 or
  pre-fix Phase 7; it is the GREEN test stated backwards. Reframe as C1.3's planted-difference
  form ("the normalization/diff harness detects a planted difference"), or state the
  first-merge-build-before-normalization sequence explicitly. Underlying acceptance properties
  (byte-identity after normalization) are sound. (Agrees with prior audit F1.)
- **N2 (non-blocking; RED-first mislabeled: C2.4).** Depth-cap REFUSED exists in both old scripts
  at `4134980` and is already regression-tested (`regression-depth-enforcement.sh` seeded-1/2/3);
  the test is green pre-merge. Legitimate as an invariant-assertion control (the brief permits
  this) but must not be reported as RED-first in Phase 7, or the RED/GREEN distinction in §5
  collapses. (Agrees with F2.)
- **N3 (non-blocking; C1.9's missing RED-first — the central defect shape).** Pre-merge claimlint
  exits 0 on a 0-row register (verified: no empty-register guard in the inline parser; exit 3
  only on `unparsed > 0`). A sharp, runnable RED exists today: run the current pre-merge
  `weizigo-claimlint` against a 0-row register and observe the silent success the merge must kill.
  Recommend adding it to the RED-first column; it is the test most aligned with the QA-023
  lesson. (Agrees with F3, sharpened with source-level evidence.)
- **N4 (non-blocking but the most substantive; separation-of-concerns `−` under-pinned).** The
  scope §3.1 verb-boundary contract — "separate exit codes, separate stderr channels, no shared
  mutable state between invocations" — is only partially pinned: C1.1 (verb existence) + C1.7
  (stdout/stderr, and C1.7's gate exercises only `verify`). "Separate exit codes per verb" and
  "no shared mutable state" are untested, and the design (`04-design.md` §3.1) has already
  relaxed exit-code separation as a direct consequence. Recommend: a test that `verify` and
  `absorb` return their documented distinct outcomes on a known input and that a `verify` run
  leaves no state a subsequent `absorb` reads; and extend C1.7's gate to the `absorb` verb.
  (Agrees with F4; adds the design-consequence evidence and the C1.7-verify-only observation.)
- **N5 (non-blocking; §0 baseline double-lists shared scripts; C2.6 heading arithmetic off).** The
  §0 table lists `dispatch-verification`/`depth-enforcement` under ollama-subagent ("2
  (ollama-dispatcher, + shared …)") *and* again as "shared | 2" — and the ollama row names three
  scripts under "2". C2.6's heading "3(+2 shared)" contradicts both the doc's own prose (four
  named scripts) and Phase 2's scope math ("1+1+2 shared = 4"). If Phase 7 sums the table
  naively, A0's baseline is inflated and the union bar is measured against a double-count.
  Phase 7 must state the deduplicated baseline (the sibling `07-test.md` stub already dedups to 4
  for the subagent pair, inconsistently). Fix the table and the heading; the tests themselves are
  unaffected. (Agrees with F5; adds the C2.6-heading arithmetic and the 07-test.md propagation.)
- **N6 (non-blocking; C1.6 RED-first in summary but not in body).** The summary lists "header
  says 'Used by claimlint'" as C1.6's RED-first; the body has no RED-first section, only the
  acceptance line. The implied control is falsifiable (and the header is verified stale at
  `4134980`), but the body should state it so summary and body agree. (Agrees with F6.)

None of N1–N6 block Phase 4. The load-bearing properties — 22 concrete tests with acceptance
criteria (count verified), full scope coverage of every IN/OUT/ASSESS decision (verified), A0
union bar present (modulo N5's baseline arithmetic), C3.3 no-live-store present, §10 precedent
honored (no test assumes managent/argus merged), landmark + human summary + writer/commit header
complete — all hold. N4 is the most substantive because it is the `−` quality entry whose scope
condition the suite failed to carry, and the design's exit-code relaxation is its visible
consequence; N3 is the most aligned with the project's hardest-won lesson (no silent success)
and the cheapest to fix.

---

**Landmark:** advances `L4 (the ledger is clean)` — Phase 3 freezes 22 named acceptance tests
before any design, and this independent re-audit confirms the freeze covers every IN/OUT/ASSESS
scope decision, so Phase 4 cannot be tested against itself. What remains: Phase 4 should close
N4 (pin the verb-boundary exit-code/no-shared-state contract and extend C1.7 to `absorb`) — a
gap whose consequence (overlapping exit codes) is already visible in the design — and Phase 7
should reframe N1's three RED-first controls, relabel N2 as an invariant assertion, add N3's
runnable RED for the no-silent-success test, and state a deduplicated A0 baseline (N5).

**Human summary:** the Phase 3 acceptance suite passes this independent audit with six
non-blocking findings — Phase 4 may proceed. I re-read the Phase 2 scope doc and checked every
acceptance test against it at the pre-merge commit the document itself measures: all four IN
merges are covered (claimlint+absorb by C1.1–C1.9; subagent+ollama-subagent by C2.1–C2.7),
managent/argus/gen-indices are correctly NOT tested (OUT/ASSESS), the union-of-suites bar and
the no-live-store guard are present, no test assumes the §10 registration/display precedent was
broken, and the 22-test count is accurate. The findings: three RED-first controls (C1.2, C2.2,
C2.3) compare against a merged binary that cannot exist before the fix and are circular as
written; C2.4's "RED first" is actually green pre-merge (the depth cap exists in both old
scripts and is already regression-tested) and should be relabeled an invariant assertion; the
no-silent-success test — the project's central defect shape — is missing its RED control even
though pre-merge claimlint silently exits 0 on an empty register, demonstrable today; and the
separation-of-concerns `−` entry is only half-pinned — the scope's "separate exit codes / no
shared mutable state" condition was never made a test, and the design has already relaxed the
exit codes as a result. A prior audit of this document (glm-5.2/T434, 2026-08-08) reached the
same verdict with the same findings; this audit was conducted independently and corroborates
them.
