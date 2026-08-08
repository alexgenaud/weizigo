# T434 — AUDIT of T428 Phase 3: `03-acceptance.md`

**VERDICT: PASS WITH FINDINGS** — Phase 4 may proceed; six non-blocking findings below. None block.

| | |
|---|---|
| Auditor | glm-5.2/T434 |
| Date | 2026-08-08 |
| Subject | `docs/infra/tool-consolidation/03-acceptance.md` (writer: deepseek-v4-pro/T428.2) |
| Landmark | gate for `T428 (tool consolidation sprint)` Phase 3 → Phase 4 |

Independence is the mechanism: I did not write the acceptance document, and I re-read the
Phase 2 scope doc (`02-scope.md`, audited PASS WITH FINDINGS by T433) before auditing, so a
test that does not match a scope decision is a finding, not an oversight. The Phase 3
question is *the tests that must pass, written BEFORE any design* — a test written after the
design tests the design, not the requirement. The whole point of ordering Phase 3 before
Phase 4.

The kanban claim of this row was blocked (dependency `T428` still `in_progress`, exactly as
the sibling Phase 2 audit T433 was); the human dispatched the audit directly and the document
under audit exists on disk, so the substantive work proceeded. That context is recorded
here so the Orchestrator can see it — same shape as T433, recorded for the same reason.

---

## 1. Phase 3 question answered — PASS

The document lists concrete, verifiable acceptance tests, each with an acceptance criterion
that names a command, an exit code, or an output a reader can run. §4 collapses them to a
22-row summary table; §5 names what Phase 7 must show for each (RED control result, GREEN
result, commit, script reuse). These are tests you could run, not aspirations. The
"Phase 3 before Phase 4 is deliberate and not negotiable" preamble is stated up front, and
§5 closes with the rule that a specifically-named test can be retired only after argued
review — the tests are the gate, not a wish list.

## 2. Scope coverage — PASS (every scope decision covered; OUT/ASSESS correctly untested)

Re-checked each Phase 2 scope decision (§4 summary table of `02-scope.md`) against the
acceptance tests:

| Phase 2 scope decision | scope action | acceptance coverage | verdict |
|---|---|---|---|
| `weizigo-claimlint` IN (merge with absorb) | one Zig binary, `verify`/`absorb` verbs | C1.1–C1.9 (9 tests) | covered |
| `weizigo-absorb` IN (merge with claimlint) | same binary, `absorb` verb | C1.1, C1.3, C1.4, C1.8, C1.9 | covered |
| `bin/subagent` IN (merge with ollama-subagent) | one Python script, `--provider` flag | C2.1–C2.7 (7 tests) | covered |
| `bin/ollama-subagent` IN (merge with subagent) | same script, `--provider ollama` | C2.1, C2.3, C2.4, C2.6, C2.7 | covered |
| `managent` OUT | no merge; may gain parser import in Phase 4 | **no test assumes managent merged** | correctly NOT tested |
| `argus` OUT | no merge; may consume parser output in Phase 4 | **no test assumes argus merged** | correctly NOT tested |
| `tools/gen-indices` ASSESS | may consume merged parser output in Phase 4 | **no test** (deferred to Phase 4) | correctly deferred |
| `tools/dispatch_verify.py` OUT | already shared; used as-is | C2.5 (verify it is still called for both paths) | covered |
| `tools/runner` OUT | orthogonal | no test | correct (orthogonal) |

`grep -niE 'gen-indices|managent|argus'` over the acceptance doc returns only C3.3's
reference to `docs/infra/managent/tasks.json` — and that reference is the *no-live-store*
guard (verify `tasks.json` byte-identical before/after), i.e. it protects managent's store
from disturbance, it does not assume managent was merged. No test treats managent or argus
as a merge target; no test assumes `gen-indices` was rewritten. The OUT/ASSESS handling is
clean.

## 3. RED-first discipline — PARTIAL (three controls unfalsifiable as written; one mislabeled)

The brief asks specifically: are any "RED first" tests actually unfalsifiable — they would
pass even without the fix? I read every RED-first control against the pre-merge state.

**Sound RED-first controls (falsifiable, named command/exit/output):**

- **C1.1** — `bin/weizigo-claimlint no-such-verb` pre-merge: the old claimlint has no verb
  system, so `no-such-verb` is read as a path argument and fails with a file-not-found error,
  not an "unknown verb" error. RED (no verb error) → GREEN (verb error). Falsifiable.
- **C1.3** — "with different CLAIMS.md copies, outputs differ." This is the right shape: it
  proves the diff/normalization harness can detect a real difference before the fix is
  trusted. Falsifiable.
- **C1.5** — `grep -c 'fn parseRegister' src/claimlint.zig` returns 1 pre-merge, 0
  post-merge. Concrete, runnable, falsifiable. The strongest control in the document.
- **C2.1** — `bin/subagent` without `--provider` pre-merge: the old script has no
  `--provider` flag and proceeds to dispatch (no "provider" error). RED (no provider
  error) → GREEN (provider error). Falsifiable.

**Findings on RED-first (non-blocking):**

- **F1 (RED-first unfalsifiable as written: C1.2, C2.2, C2.3).** These three controls are
  stated as "old vs merged differ (version)" / "old/new differ." But pre-merge the merged
  binary/script does not exist, so the comparison *cannot be run* before implementation — it
  is not that the control "passes without the fix," it is that it is a no-op until the fix
  exists. That is not a RED-first control; it is the GREEN test stated backwards. The
  falsifiable form is the one C1.3 already uses: plant a real difference (deliberately
  divergent inputs, or an unstripped version line) and show the diff harness catches it.
  C1.2/C2.2/C2.3 should reframe their RED-first as "the normalization/diff harness detects
  a planted difference," not "old vs merged differ." The underlying acceptance test
  (byte-identical after normalization) is sound; only the RED-first specification is
  circular.
- **F2 (RED-first mislabeled: C2.4).** "RED first: set `WEIZIGO_AGENT_DEPTH=3`, run
  `bin/subagent --provider ollama --dry-run T123` → exit ≠ 0, stderr says REFUSED." But
  depth-cap enforcement (`MAX_DEPTH = 3`, REFUSED on `depth >= MAX_DEPTH`) already exists
  in *both* old scripts at the scope's commit — T433's audit finding F2 verified the two
  scripts carry identical depth-cap logic. So this control is GREEN before the merge, not
  RED. It is a legitimate *invariant assertion* (the brief explicitly allows "assert the
  invariant instead" when a defect is already fixed and cannot be re-observed failing),
  but labeling it "RED first" is wrong. Phase 7 should report it as an invariant-assertion
  control, not a RED-first control, or the RED/GREEN distinction in §5 collapses.

**RED-first controls I accept as baseline assertions (the brief permits this):** C1.4,
C1.8, C2.6, C2.7 state "pre-merge each passes" / "old binary works" — these are GREEN
baselines, not RED controls. They are acceptable as invariant baselines (the pre-merge
suite is green; the old entry point works), but the summary table lists them in the
RED-first column. Minor framing; not a separate finding beyond F2's point.

## 4. Union-of-suites bar — PASS

A0 explicitly mandates: "The merged tool's regression suite count ≥ the sum of the
individual suites. No control removed unless it tests a retired entry point." The cutover
case is handled (a test that checked `bin/ollama-subagent` exists becomes a test that
`bin/subagent --provider ollama` works — a substitution, not a removal). §5 requires Phase 7
to "report exact before/after control counts and state which controls were retired and
why." The bar is present and crisp. (See F5 below for a counting ambiguity in the §0
baseline table that A0 measures against.)

## 5. The eight qualities — PARTIAL (one `−` under-tested)

The brief asks specifically whether the `−` entries from the Phase 2 eight-quality table
are tested:

- **Stability `−` (claimlint+absorb: 3,900-line binary, cutover wrappers) → C1.8.** The
  cutover-wrapper half is tested: C1.8 verifies `bin/weizigo-absorb` becomes a thin
  wrapper that calls `bin/weizigo-claimlint absorb "$@"`, emits a deprecation notice, and
  produces an identical result. The "3,900-line binary, concentration of failure" half is
  not directly testable as an acceptance property, but C1.9 (no silent success) is the
  structural mitigation: a parser defect that would have been silent now fails hard in
  both verbs. Reasonable. Covered.
- **Separation of concerns `−` (verify/transform in one binary) → C1.1.** **Partially
  covered — see F4.** Phase 2 scope §3.1 demanded the verb boundary keep verify and absorb
  distinct with "separate exit codes, separate stderr channels, and no shared mutable
  state between invocations." C1.1 tests verb existence + `--help` listing + unknown-verb
  error. C1.7 tests the stdout/stderr contract (data on stdout, diagnostics on stderr).
  But "separate exit codes per verb" and "no shared mutable state between invocations" are
  not tested. The `−` entry is only half-covered: the *existence* of the boundary is
  tested; the *crispness* of the boundary (the part scope §3.1 said Phase 4 must
  demonstrate) is not pinned down by an acceptance test.

## 6. Precedent compliance — PASS

The §10 "managent writes / argus reads" precedent (verified verbatim by T433 at
`docs/infra/assertion-ledger/spec.md` §10). No acceptance test assumes managent or argus
was merged. The only managent reference (C3.3) is the no-live-store guard, which *protects*
the managent store, it does not consume or merge it. Precedent honored.

## 7. No-live-store — PASS (mandate broad; verifiable gate narrower)

C3.3 states the mandate broadly — "Every exercise uses `MANAGENT_STORE`. Before and after
every exercise, `tasks.json` is verified byte-identical" — and gives a verifiable gate:
"Phase 7 includes a `sha256sum` of `docs/infra/managent/tasks.json` before and after the
test run. The two hashes match." The mandate covers every exercise; the *verifiable* gate
is the test-run sha256sum. That is the right shape for an acceptance test (a property the
shipped artifact must satisfy), and it directly prevents the T425 incident (16 fixture rows
written into the production store). The brief's item 7 is satisfied. Minor note (not a
finding): the verifiable gate is the test run only; the broader "every exercise" mandate
is a process rule Phase 6 (build) must enforce, not something Phase 7 can fully audit.

## 8. Completeness — gaps (one substantive, the rest minor)

- **F4 (substantive, separation-of-concerns boundary under-tested — already named in §5).**
  The scope §3.1 verb boundary contract ("separate exit codes, separate stderr channels,
  no shared mutable state") is only partially pinned by C1.1 + C1.7. Recommend a test that
  verifies `verify` and `absorb` return *distinct* exit codes on a known input and that
  running `verify` leaves no state that affects a subsequent `absorb` (e.g., the merged
  binary does not write a shared cache/temp file read by the other verb). This is the one
  gap I would ask Phase 4 to close before design rather than after.
- **F3 (C1.9 has no RED-first control — the central defect shape).** "No silent success"
  (C1.9) is the project's standing defect shape (the QA-023 chain; the 2026-08-07 tooling
  rule: "the tool reported success while doing nothing"). The acceptance test is present
  and correct (empty register → hard error, non-zero exit, stderr names the empty parse).
  But its RED-first column is "—". A RED-first is *available*: pre-merge, run the current
  `weizigo-claimlint` against a CLAIMS.md with 0 recognizable rows and observe whether it
  exits non-zero and names the empty parse. If the inline parser already hard-errors
  (T406 added the guard to the shared `claims_register.zig` path absorb uses, but
  claimlint's *inline* copy is the divergent one — that is the whole point of the merge),
  the RED control documents the pre-merge behavior; if it does not, the RED control is
  sharp. Either way the control is runnable and falsifiable, and it is the one test most
  aligned with the project's hardest-won lesson. Strongly recommend adding it.
- **Minor: cutover-wrapper *removal* is not an acceptance test.** Scope §5 said wrappers
  are "removed in a separate commit after every console has been updated." No test pins
  the eventual removal. This is correctly a Phase 5 (plan) / Phase 6 (build) step rather
  than an acceptance-test property — not a gap, noted for completeness.
- **Minor: C1.2 byte-identity requires the `verify` verb to equal the old default
  invocation.** The old `weizigo-claimlint` has no verb; its default mode is what `verify`
  must reproduce byte-for-byte. C1.2 states this implicitly ("verify produces byte-identical
  output to old weizigo-claimlint") but does not name the mapping (old-default →
  `verify`). Phase 7 should state the invocation mapping explicitly so the diff is
  apples-to-apples.

## 9. Process bars — PASS

- **Landmark line** — present (close): "Landmark: advances `L4 (the ledger is clean)`…"
- **Human summary** — present (close): "Human summary:" paragraph.
- **Header names writer and commit** — header table names Writer
  (`deepseek-v4-pro/T428.2`) and "Commit measured at `4134980`". The auditor slot is
  "pending — row to be registered and dispatched," which is correct (the auditor names
  themself in *this* audit doc, not in the subject doc).
- **22 tests claimed — counted accurately.** The §4 summary table has exactly 22 rows
  (`grep -E '^\| (A0|C[12]\.[0-9]|C3\.[0-9])'` → 22). Breakdown: A0 (1) + C1.1–C1.9 (9) +
  C2.1–C2.7 (7) + C3.1–C3.5 (5) = 22. The body sections §1–§3 contain exactly those tests,
  no more, no fewer. Accurate. Of the 22, 9 are marked "—" (no RED-first) in the summary
  table; 13 carry a RED-first marker. The 9 "—" are A0, C1.7, C1.9, C2.5, C3.1–C3.5 —
  consistent between the summary table and the body. Verified.

---

## Findings (none blocking)

- **F1 (non-blocking, RED-first unfalsifiable as written: C1.2, C2.2, C2.3).** These
  three "old vs merged differ" controls compare against a merged binary/script that does
  not exist pre-merge, so the control cannot be run before the fix — it is the GREEN test
  stated backwards, not a RED-first control. The falsifiable form is C1.3's: plant a real
  difference and show the diff/normalization harness catches it. Reframe these three
  RED-first controls as "the normalization/diff harness detects a planted difference."
  The underlying acceptance tests (byte-identical after normalization) are sound.
- **F2 (non-blocking, RED-first mislabeled: C2.4).** Depth-cap enforcement already
  exists in both old scripts (T433 F2 verified identical logic), so "depth=3 → REFUSED"
  is GREEN pre-merge, not RED. Acceptable as an invariant assertion (the brief permits
  this), but it should not be labeled "RED first" — Phase 7 should report it as an
  invariant-assertion control, or the RED/GREEN distinction in §5 collapses.
- **F3 (non-blocking, C1.9 missing its available RED-first).** The "no silent success"
  test — the project's standing central defect shape — has no RED-first control, though
  one is runnable: pre-merge `weizigo-claimlint` against a 0-row register and observe
  whether it hard-errors and names the empty parse. Recommend adding it; it is the test
  most aligned with the QA-023 lesson.
- **F4 (non-blocking, separation-of-concerns boundary under-tested).** Scope §3.1's
  verb-boundary contract ("separate exit codes, separate stderr channels, no shared
  mutable state between invocations") is only partially pinned by C1.1 (verb existence)
  + C1.7 (stdout/stderr). "Separate exit codes per verb" and "no shared mutable state"
  are not tested. Recommend an acceptance test that verifies `verify` and `absorb` return
  distinct exit codes on a known input and that a `verify` run leaves no state a
  subsequent `absorb` reads. This is the one finding I would ask Phase 4 to close before
  design rather than after.
- **F5 (non-blocking, §0 baseline table double-lists shared scripts).** The §0 baseline
  table lists `dispatch-verification` and `depth-enforcement` under *both* `ollama-subagent`
  ("2 (ollama-dispatcher, + shared dispatch-verification, depth-enforcement)") *and* a
  separate "shared | 2 (dispatch-verification, depth-enforcement)" row. If Phase 7 sums
  the individual-suite counts naïvely, the shared scripts are counted twice, inflating
  the A0 bar. Phase 7 must count shared scripts exactly once (the union, not the sum of a
  double-counted table). The §0 numbers are also marked "TBD in Phase 7," so this is
  fixable in Phase 7 without amending Phase 3 — but the double-listing should be
  reconciled so A0 is measured against a deduplicated baseline.
- **F6 (non-blocking, C1.6 RED-first in summary but not in body).** The §4 summary table
  lists a RED-first for C1.6 ("header says 'Used by claimlint'") but the C1.6 body has no
  RED-first section — only an acceptance line (`git show HEAD:src/claims_register.zig |
  head -25` shows updated header). The implied RED control (pre-merge the header is
  stale — verifiable by grep) is falsifiable, but the body should state it explicitly so
  the summary table and the body agree.

None of F1–F6 block Phase 4. The load-bearing properties — 22 concrete tests with
acceptance criteria (verified), scope coverage of every IN/OUT/ASSESS decision (verified),
union-of-suites bar A0 (present), no-live-store C3.3 (present), §10 precedent honored (no
test assumes managent/argus merged), landmark + human summary + writer/commit header
complete, 22-test count accurate — all hold. F4 is the most substantive because it is the
one `−` quality entry (separation of concerns) that the scope demanded Phase 4 demonstrate
and the acceptance suite does not yet pin down; F3 is the one most aligned with the
project's hardest-won lesson (no silent success) and is the cheapest to fix.

---

**Landmark:** advances `L4 (the ledger is clean)` — Phase 3 freezes 22 acceptance tests
before any design, so Phase 4 (design) cannot be tested against itself; scope coverage is
complete and the OUT/ASSESS tools are correctly untested. What remains: Phase 4 should
close F4 (the separation-of-concerns verb-boundary test) before design, and Phase 7
should reframe F1's three RED-first controls, relabel F2's as an invariant assertion, add
F3's missing RED-first for the no-silent-success test, and reconcile F5's double-counted
baseline so A0 measures against a deduplicated union.

**Human summary:** the Phase 3 acceptance suite passes audit with six non-blocking
findings — Phase 4 may proceed. I re-read the Phase 2 scope doc and checked every
acceptance test against it: all four IN merges are covered (claimlint+absorb by C1.1–C1.9;
subagent+ollama-subagent by C2.1–C2.7), managent/argus/gen-indices are correctly NOT tested
(OUT/ASSESS), the union-of-suites bar A0 and the no-live-store guard C3.3 are present, and
no test assumes the §10 registration/display precedent was broken. The 22-test count is
accurate. The notable findings: three RED-first controls (C1.2, C2.2, C2.3) compare against
a merged binary that does not exist pre-merge and so are unfalsifiable as written — they
should be reframed as "the diff harness catches a planted difference"; C2.4's "RED first"
is actually GREEN pre-merge (depth-cap already exists in both old scripts) and should be
relabeled an invariant assertion; and the separation-of-concerns `−` entry (the verb
boundary scope §3.1 demanded Phase 4 demonstrate) is only half-pinned by C1.1+C1.7 — the
"separate exit codes / no shared mutable state" half is not yet tested. The no-silent-
success test (C1.9), the project's standing central defect shape, is missing an available
RED-first control. None block design; F4 is the one I would close before Phase 4.