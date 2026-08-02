# verify-battery — Phase 1 SPEC

```
Task:   T290 · Role: worker · Model: deepseek-v4-pro · Date: 2026-08-03
Status: DRAFT — gates Phase 1 (T291, T292 blocked)
Parent: pass0 spec (docs/epic-01-markovian/sprints/verify-battery/pass0/spec.md)
Inputs: AXIOMS.md §3 (requirement tree) · DIRECTION.md §5 + Amendment 1 (ratified 2026-08-03) ·
        ADR-0020 gap adjudication (T287) · pass0 spec (12 invariants, 6 acceptance criteria)
```

**This spec decides what the battery checks and how each check can fail.** It is prose
and tables, no code. T291 (design) and T292 (implementation) are blocked on it.

---

## 1. Check → Node: which tree node does each invariant actually test?

The tree is `AXIOMS.md` §3. An invariant that maps to no node is either testing
something the theorem does not claim, or the tree is missing a node.

| check | maps to node(s) | assessment |
|---|---|---|
| **I1** pin census (`pin_L == pin_H`) | `Z-CONVERGE-FIX` | Catches inverted branch guards inside the fixpoint kernel. A summary measurement — not a direct falsification of any single tree node — but its diagnostic value is the structural invariant `pin_L == pin_H` (a solver that disagrees with itself about what is pinned has a classification defect). Maps most cleanly to fixpoint integrity. |
| **I2** colour inversion | `Z-R-SIGN`, `Z-SYM` | Direct test of C4 (Black-positive, colour inversion). Exhaustive: `L(−pos,−side) == −H(pos,side)`. One of the strongest checks in the battery — independent of the move relation, purely a property of the stored values. |
| **I3** `L ≤ H` | `Z-CONVERGE-FIX`, `Z-TABLE-CONSISTENCY` | Direct test of E3 (bracket semantics: L(s) ≤ H(s) at every state). A single `L > H` is a genuine fixpoint corruption. |
| **I4** Bellman residual | `Z-CONVERGE-FIX` | Direct test of E1+E2: `L = Φ(L)` and `H = Φ(H)`. The strongest fixpoint check — 0 violations means the table IS a fixpoint. |
| **I5** SCC containment (`KO_SENSITIVE ⊆ cycle-reachable`) | `Z-CONVERGE-FIX`, `Z-STATE` | Structural theorem: a state whose value is history-dependent (KO_SENSITIVE) must be in a cycle, otherwise its value would be determined by its acyclic children. Cross-checks the value table against the move graph without reading stored values. |
| **I6** UNDEF census | `Z-STATE-LEGAL`, `Z-COMPLETE-ENUM` | Verifies legal position counts against OEIS. Partial coverage of completeness — catches serialisation holes and off-by-one errors in the position enumeration, but does not verify reachability. |
| **I7** DTT sanity | `Z-TABLE-FAITHFUL`, `Z-CONVERGE-FINITE` | Tests that the DTT column was actually computed: terminals must have DTT=0, non-terminals must satisfy recurrence. A uniformly-initialised DTT column (v1's 255) is a schema-present/data-empty defect. |
| **I8** truncation-gap regression | `Z-TABLE-FAITHFUL` | Specific fixture: 24 formerly-mismatched 2×2 states must show fixpoint-vs-truncation agreement. Catches semantic drift and buffer-aliasing regression (T102). Narrow scope — 24 states, one goban — but the underlying defect class (buffer aliasing) is load-bearing. |
| **I9** anchors | `Z` (the theorem root) | Root-value comparison against committed references. Only a few cells have anchors (2×2=0, 3×2=0, 3×3=+9, 4×4=+1). Absent anchors report "no reference," not failure. |
| **I10** TIE median (`TIE ∈ [L, H]`) | `Z-R-TIE` | Verifies C3: the stored TIE value is consistent with the bracket at every non-terminal. A wrong TIE with a sane histogram (QA-023's defect shape) is caught here and nowhere else. |
| **I11** move-set consistency | `Z-R-MOVE` | Independent re-implementation of the move generator vs. the solver's — the only check that tests whether the move relation used by I4 is itself correct. A wrong move set can leave I4 passing vacuously. |
| **I12** score range | `Z-R-SCORE` | Bounds check: L, H, TIE ∈ [−area, +area]. Catches sign-extension/overflow defects that no other invariant would flag — e.g. +127 on a 2×2 goban. No other invariant bounds the magnitude of values. |

**Findings from the Check→Node mapping:**

- **No invariant tests Z-R-STATE** (state encoding correctness). The key-agreement invariant (T267) — that producer and consumer compute identical keys — is not among I1–I12. This is the T178/T193/T265 defect family, and the battery has no check for it.
- **No invariant tests Z-STATE-REACH** (reachable set correctness). I6 tests legal position counts, not reachability. A reachable state absent from the table can only be caught by the C-A1/C-A2 closure checks (specified in T266, not runnable today).
- **No invariant tests Z-CONVERGE-MONO** (monotonicity of Φ). This is mathematical (Knaster–Tarski on a finite lattice) — a counterexample would manifest as a Bellman violation in I4, but there is no explicit monotonicity probe.
- **No invariant tests Z-CONVERGE-SEED** (seeding provenance). The battery does not verify that the table was built from (−N, +N) seeds. A table built from different seeds could still satisfy I4 (Bellman) and I3 (L≤H) while being the wrong fixpoint.
- **No invariant tests Z-TABLE-ROUNDTRIP** (write-then-read fidelity). The artifact is loaded once; there is no write-back-and-reread check to catch serialisation defects.
- **I1 is a measurement, not a falsification node.** It reports pin counts and the `pin_L == pin_H` invariant; it does not directly falsify any tree node. It is valuable diagnostics but could be retired from the "invariant" list and reclassified as a measurement report.

---

## 2. Node → Check: which tree nodes have no check?

These are the Phase 1 gaps — the reason this task exists. For each uncovered node,
state what a check would have to measure.

| tree node | covered by | gap? | what a check would measure |
|---|---|---|---|
| `Z-R-MOVE` | I11 | **covered** (independent re-implementation) | — |
| `Z-R-SCORE` | I12 | **thin** — I12 bounds values within [−area, +area] but does not verify that terminal scores are correct per C2 (Benson/Tromp–Taylor) | A check would compute area_score independently at every terminal and compare to the table's terminal values. Requires an independent Benson implementation. |
| `Z-R-TIE` | I10 | **covered** | — |
| `Z-R-STATE` | — | **GAP** — no check for state-key correctness. The T178/T193/T265 defect family (producer/consumer key mismatch) has no battery coverage. | T267's key-agreement invariant: for every (position, side, ko, passes), the producer's key equals the consumer's key. Requires both implementations; only one exists today. |
| `Z-R-SIGN` | I2 | **covered** | — |
| `Z-STATE-LEGAL` | I6 | **covered** (OEIS census) | — |
| `Z-STATE-REACH` | — | **GAP** — no check that the reachable set is correctly computed. I6 verifies legal positions, not reachability. | C-A1/C-A2 closure checks (T266): every child of a reachable state is reachable (forward closure), and every state reachable from the root is in the table (backward closure). Needs Phase 2 kernel. |
| `Z-STATE-KEY` | — | **GAP** — T267's key-agreement invariant is specified but not runnable: it needs both the producer implementation (solver kernel) and the consumer (battery's own encoder) to exist. Currently only the solver-side encoder exists; the battery re-implements its own per R8, making this a differential check. | Run both encoders on the same state space; count mismatches. Requires the Phase 2 kernel to provide the production encoder. |
| `Z-CONVERGE-MONO` | — | **GAP** — no explicit monotonicity probe, though the property is mathematical (Knaster–Tarski) and a violation would likely manifest as a Bellman violation in I4. | A check would construct two valuation vectors A ≤ B and verify Φ(A) ≤ Φ(B) at every state. Impractical at 4×4 scales; the mathematical proof `[GLOBAL.FP1:PROVEN]` is the defence. This gap is acknowledged and accepted. |
| `Z-CONVERGE-FINITE` | I4, I7 | **indirect** — I4 passing means convergence was achieved; I7 passing means DTT is finite-valued. No explicit sweep-count or non-convergence test. | A check would verify the build's sweep count and confirm that the final sweep produced zero changes. For existing artifacts, the sweep count is embedded in provenance, not in the artifact itself — this is a build-provenance check, not a battery check. |
| `Z-CONVERGE-SEED` | — | **GAP** — no check that the table was seeded from (−N, +N). A table from different seeds could pass I3 and I4 while being the wrong fixpoint. | A check would verify build provenance (command-line flags, seed vectors). This is a build-documentation check, not something the artifact itself records — the artifact is the converged fixpoint, not the seeds. Accepted gap: seeded from wrong values, the fixpoint would differ from the true one, but there is no independent oracle to compare against except I9 (anchors) and the #2 auditor. |
| `Z-CONVERGE-FIX` | I3, I4, I5 | **covered** (strong) | — |
| `Z-TABLE-ROUNDTRIP` | — | **GAP** — no write-then-read check. The battery reads the artifact; it does not write it back and verify round-trip fidelity. | A check would: load artifact, write to a temp file, reload, compare bit-for-bit. Needs the Phase 2 kernel's artifact I/O module (the only writer). |
| `Z-TABLE-FAITHFUL` | I7, I8, I9 | **partial** — I7/I8 test specific failure modes; I9 tests a few root values. No general check that every slot's stored value equals the fixpoint value. | For loopy-game fixpoint builds, I4 IS this check — if L=Φ(L) and H=Φ(H) everywhere, the stored values ARE the fixpoint. For finisher-based builds, this would require re-running the finisher and comparing. The ADR-0020 path makes this gap moot: the table IS the fixpoint. |
| `Z-TABLE-CONSISTENCY` | I1, I2, I3, I12 | **covered** | — |
| `Z-COMPLETE-ENUM` | I6 | **thin** — I6 checks legal positions, not whether all reachable states are in the table. The C-A1/C-A2 closure checks are specified but not runnable. | C-A1 (forward): for every state in the table, every child reachable by a legal move is also in the table. C-A2 (backward, root-reachable): every state reachable from the fresh-start root is in the table. Needs Phase 2 kernel. |
| `Z-COMPLETE-PASSES` | — | **GAP** — the passes dimension enumeration is currently checked only indirectly via I6 (which tests legal positions, not passes-dimension completeness). The passes=1 structural incompleteness claim was refuted (T266/T277/T279), but no positive check verifies the passes dimension. | A check would verify that for every (position, side, ko) where passes=0 is present, the appropriate passes=1 and passes=2 slots also exist. Requires understanding the state encoding's pass-dimension layout. |
| `Z-SYM` | I2 | **covered** (colour inversion). Dihedral symmetry is not independently checked but is implied by the colex index scheme. | — |
| `Z-AUDIT` | — | **GAP — by design.** The #2 self-consistency auditor is a separate gate specified in `AGENTS.md`, not a battery invariant. The battery's job is to check the artifact; the auditor's job is to check the solver that produced it. | — |
| `Z-NONCLAIMS` | — | **GAP — by design.** NC1–NC5 are non-claims: they assert what the theorem does NOT say. The battery tests positive claims; verifying non-claims (e.g. that C2 is indeed FALSE-AS-SCOPED at 3×2) is an epistemic task, not a mechanised check. | — |

**Summary of gaps requiring new battery checks (for T291/T292):**

| gap ID | tree node | severity | required for Phase 2? |
|---|---|---|---|
| G1 | `Z-R-STATE` (key agreement) | **critical** — the T178/T193/T265 defect family is the project's most expensive bug class | needs kernel (producer encoder) |
| G2 | `Z-STATE-REACH` (closure C-A1/C-A2) | **critical** — an incomplete table is a false Z | needs kernel (move generator) |
| G3 | `Z-STATE-KEY` (key agreement, consumer side) | **critical** — same defect family as G1, different direction | needs kernel |
| G4 | `Z-TABLE-ROUNDTRIP` | **should** — serialisation defects are rare but catastrophic | needs kernel (artifact I/O) |
| G5 | `Z-CONVERGE-SEED` | **could** — build provenance, not artifact property | needs build documentation |
| G6 | `Z-CONVERGE-MONO` | **could** — mathematical proof covers it; impractical to test at scale | not needed (accepted gap) |

---

## 3. Pass conditions — and which ones are themselves defects

For each check: what it measures, what value is a **violation**, and what value is merely a
**measurement**. Per T287: a pass condition that requires the solver to contradict an axiom
is itself a defect.

### 3.1 Pass condition analysis

| check | measures | violation | measurement | defect in pass condition? |
|---|---|---|---|---|
| **I1** | pin classification consistency: `pin_L == pin_H` and pin census counts | `pin_L ≠ pin_H` (the solver disagrees with itself about which states are pinned) | the pin counts themselves (L==H count, pin_T count, etc.) — these characterise the state space but have no "correct" value | **No.** The structural invariant is sound. But pass0's A3 requires reproducing specific pin counts — those are measurements, not violations, and a mismatch is **reference-bad** (the register figure may be wrong), not **artifact-bad**. |
| **I2** | `L(−pos,−side) == −H(pos,side)` | any violation (count > 0) | violation count (should be 0) | **No.** Sound. |
| **I3** | `L(s) ≤ H(s)` everywhere | any `L > H` (count > 0) | count of L<H states (bracket rate) — a measurement, not a defect per E3 | **No — but see I8 note below.** The pass condition is `L > H` violations, not L<H. L<H is expected under E3. Any check that demands L==H everywhere contradicts E3 and is a defect. |
| **I4** | `L = Φ(L)`, `H = Φ(H)` at every non-terminal | any Bellman violation (count > 0) | violation count (should be 0) | **No.** Sound. The WZO1 caveat (KO_SENSITIVE children may contaminate Φ) is an implementation detail, not a defect in the condition. |
| **I5** | `KO_SENSITIVE(s) ⇒ s is in a cycle` | any KO_SENSITIVE slot not cycle-reachable | count of KO_SENSITIVE slots, cycle-reachable count | **No.** Sound. |
| **I6** | legal position census vs OEIS | union count ≠ OEIS reference | the census distribution itself | **No.** Sound, though the "violation" is only meaningful as a discrepancy from the known OEIS counts. |
| **I7** | DTT recurrence: terminals=0, non-terminals satisfy DTT = 1+min(children) | any terminal with DTT≠0, or any non-terminal where DTT ≠ 1+min(children) | DTT distribution | **No.** Sound. The v1 artifact's uniform-255 DTT is a genuine violation. |
| **I8** | fixpoint-vs-truncation agreement on the 24-fixture states (T102/T103) | any mismatch (gap ≠ 0 on the 172 reachable non-terminals) | the number of states tested (172) | **No — but scope-limited and potentially misleading.** T287 showed that the 24-fixture measures fixpoint-vs-truncation agreement, not L==H within the fixpoint. The fixture passes (0 mismatches) while the full 2×2 state space has 716 L<H states. **The fixture is valid for what it measures; it is not valid as evidence that L==H holds generally.** A reader who interprets gap=0 as "the fixpoint is single-valued" is making a category error that the spec must prevent — see §3.2. |
| **I9** | root values vs committed anchors | anchor mismatch at a goban where an anchor is committed | "no reference" at gobans without anchors | **No, with one correction from pass0.** Pass0's I9 says "4×4 is +1 vs MIGOS +2 and is an open discrepancy, not a failure." T274 showed MIGOS's basic-ko 4×4 is **+1**, identical to ours. The +2 is a different game (pass-difference cycle resolution). **The anchor should expect +1, note that MIGOS basic-ko agrees at +1, and record the +2 as a different-ruleset reference, not a discrepancy.** If pass0's "+1 vs MIGOS +2" language were read as "our +1 is wrong, it should be +2," that would be a defect in the pass condition. |
| **I10** | `TIE ∈ [L, H]` at every non-terminal | any state where TIE ∉ [L, H] | count of states where TIE is at the boundary vs interior | **No.** Sound. |
| **I11** | battery's legal-move set == solver's legal-move set | any state where move sets differ | mismatch count, denominator (sample size for sampled gobans) | **No.** Sound. |
| **I12** | `L, H, TIE ∈ [−area, +area]` | any value outside the valid range | none — the range is fixed by goban geometry | **No.** Sound. |

### 3.2 The I8 caveat — written so it is not misread

T287 adjudicated that the 716 L<H states at 2×2 are the **expected** output of ADR-0020's
loopy-game fixpoint semantics. E3 explicitly allows bracket-valued states. Demanding L==H
on all reachable non-terminals contradicts E3.

I8 tests a different property: **fixpoint-vs-truncation agreement on a specific 24-state
fixture**. It does NOT test L==H, and a gap=0 result does NOT imply the fixpoint is
single-valued. The 24 states are the ones that hit a buffer-aliasing defect in EXP-4
(T102); they happen to be states where the fixpoint median and the truncation value agree.
The 716 L<H states are elsewhere in the state space.

**Rule for Phase 1:** I8's pass condition remains "0 mismatches on the 24-fixture / 172
reachable non-terminals." The spec must state explicitly that this is a **regression test
for buffer aliasing**, not a single-valuedness claim. The bracket rate (716/1620 L<H at
2×2, 106/170 on the genuinely reachable set) is a **measurement** reported by I3, not a
violation.

### 3.3 I5 and the three-way 3×2 spread — handled honestly

Pass0 §4 records a three-way spread for the 3×2 cycle-reachable count: 1,724 / 1,704 /
1,678. The spread's root cause (36 empty-goban-with-ko phantom seed states) is documented
and a reconciliation task is registered. Until it lands:

- I5 reports whichever count its denominator matches
- A disagreement within the known spread is **reference-bad**, not artifact-bad
- A disagreement outside the spread is an escalation

---

## 4. Acceptance criteria — re-based on Amendment 1

Amendment 1 (ratified 2026-08-03) separates two instruments that pass0's A1–A6 conflate:

- **Known-bad = synthetic mutant, must fail** (mutation testing: DeMillo/Lipton/Sayward 1978;
  Jia & Harman 2011). Synthetic so it survives the repair of the live fault.
- **Regression input = live artifact, must not newly fail** (golden master / characterization
  testing: Feathers 2004). Pass condition is *unchanged from baseline*.

Below, pass0's A1–A6 are rewritten under this separation. Each criterion states whether it
tests a synthetic mutant or a regression artifact.

| id | criterion | instrument type | what a wrong answer scores |
|---|---|---|---|
| **A1** | Every invariant fails its **synthetic known-bad mutant**. Each invariant ships with at least one mutant fixture constructed by corrupting a known-good artifact: (a) I1: a table with `pin_L` and `pin_H` incremented on one slot — the `pin_L==pin_H` invariant must catch it; (b) I2: a table with one colour pair inverted; (c) I3: a table with one slot set to `L > H`; (d) I4: a table with one Bellman-violating value; (e) I5: a table with `KO_SENSITIVE` flipped ON at one non-cycle-reachable slot (per `i5-feasibility.md` §6), all other invariants still pass, I5 alone fails; (f) I6: a table with one legal position changed to UNDEF; (g) I7: a table with the DTT column zeroed (mimicking the v1 defect as a synthetic mutant); (h) I8: a table with one of the 24-fixture states altered; (i) I9: a table with one anchor value changed; (j) I10: a table where TIE is shifted outside [L,H] on one slot; (k) I11: a table whose stored child edges are altered (this is the hardest mutant to construct — it may need a companion dump file); (l) I12: a table with one value outside the score range. The failure must name the invariant. A mutant that survives the check is a blind spot and the invariant is not calibrated. | mutation | an instrument that never fails is indistinguishable from one that always passes. A mutant that is killed proves the check is sensitive; a mutant that survives is a defect in the check, not the mutant. |
| **A2** | Runs to completion on all **regression artifacts** — every in-scope artifact enumerated in pass0 A2: `artifacts/oracle-2x2.wzo`, `artifacts/oracle-3x2.wzo`, `artifacts/oracle-3x3.wzo`, `artifacts/oracle-4x3.wzo` (all four hashed in `artifacts/SHA256SUMS`), `data/oracle-4x4-basicko-tie-area.wzo` (hashed), `data/oracle-4x4.checkpoint.wzo` and `data/oracle-4x4-parallel.checkpoint.wzo` (unhashed, in scope). **The pass condition for each regression artifact is: no NEW failure beyond the documented baseline.** The documented baseline is recorded in this spec's appendix (§7) at ratification time and updated only when a change is adjudicated. Exit codes and denominators recorded per invocation. | regression | a new failure on a regression artifact means either the artifact changed, the battery changed, or the world changed — all three are findings. |
| **A3** | **Reproduces committed register figures (golden master).** The battery's measurements — pin census, bracket rate, UNDEF distribution, DTT distribution, SCC counts — must match the committed register values at each goban size where a register value exists. Pass0 A3's targets carry forward: (a) 3×2 pin census over two denominators (2,586 and 2,622, with the 36-phantom hypothesis documented); (b) 3×3 `L==H=68,350, pin_T=1,248, pin_L=2,080, pin_H=2,080`; (c) 4×4 v1 UNDEF census. No 2×2 pin census is committed — that cell reports measurements with no pass/fail. **A mismatch with the register is reference-bad** (exit code 3) — the register figure goes to audit, not the artifact. | regression | a tool that cannot reproduce a committed number is not measuring the same thing. A mismatch that is within a known spread (3×2 cycle-reachable) is reference-bad and feeds the reconciliation task, not an escalation. |
| **A4** | **v1 artifact (`data/oracle-4x4-basicko-tie-area.wzo`) is a regression input.** Under Amendment 1, v1 is NOT a known-bad fixture. Its current I7 failure (DTT uniformly 255) is the **documented baseline** — the battery must still report it, but as a known characteristic, not a calibration gate. **The DTT-unset defect becomes a synthetic mutant (A1g): a table with the DTT column zeroed, which must fail I7.** Similarly, `0c3366f0` (the artifact formerly certified-defective for incompleteness per DIRECTION §5) is a regression input — its completeness claim was refuted (T266/T277/T279) and it must not newly fail any completeness check. | both | if A4 were "v1 must fail I7" (pass0's wording), then the moment v1's DTT column is repaired, A4 silently tests nothing. The synthetic mutant (A1g) is the permanent calibration; v1 is a snapshot whose behaviour is documented. |
| **A5** | Independent re-implementation of **two** invariants — chosen by the acceptance auditor from {I4, I5, I7, I11}, and at least one must exercise the move relation — agrees with the battery's implementation. (Pass0 required one; the QA-023 chain's lesson — five audit links, four passed the artefact through — justifies raising to two. One re-implementation can be wrong in the same way; two in different languages by different authors is the bar this project's defect history demands.) | both | the only instrument that has found a defect in this project is independent re-implementation. Comparing two integers from the same table (I1) would pass while covering nothing — the `2B-3-AUDIT` failure shape. |
| **A6** | Peak RSS reported per invocation; no invocation exceeds 4 GB. | both | R7. |

### 4.1 What changed from pass0 — explicit diff

| pass0 | pass1 (this spec) | reason |
|---|---|---|
| A1: "Every invariant fails its known-bad fixture" — known-bads drawn from live artifacts (v1 for I7, `0c3366f0` for completeness) | A1: synthetic mutants for every invariant. A1g is the DTT-zeroed mutant; v1 becomes a regression input in A4. | Amendment 1: live faults get fixed and the check silently tests nothing. Synthetic mutants are permanent. |
| A4: "v1 must fail I7" | A4: v1 is a regression input; its I7 failure is the documented baseline. The DTT-zeroed mutant is in A1g. | Same. |
| A5: one invariant re-implemented | A5: two invariants, at least one exercising the move relation | QA-023 chain: five audit links, four passed the artefact through; one re-implementation can share the same blind spot. |
| I9: "4×4 is +1 vs MIGOS +2 and is an open discrepancy" | I9: 4×4 anchor is +1; MIGOS basic-ko agrees at +1; the +2 is a different game (pass-difference cycle resolution), not a discrepancy with our value | T274: MIGOS's basic-ko 4×4 is +1, same as ours. The +2 is a different ruleset. |
| No documented regression baseline | §7 records the regression baseline — every known characteristic of every regression artifact | Without a baseline, "no new failure" is undefined. |

---

## 5. Runnability — which checks can run now, and which need the Phase 2 kernel

Phase 1 is battery-before-code: the spec is written now, the kernel comes in Phase 2.
Mark each check honestly.

| check | runnable now? | needs kernel? | needs artifact we don't have? | notes |
|---|---|---|---|---|
| **I1** pin census | yes | no | no | Reads stored L/H values only. |
| **I2** colour inversion | yes | no | no | Reads stored L/H values only. |
| **I3** L ≤ H | yes | no | no | Reads stored L/H values only. |
| **I4** Bellman residual | yes (with battery's own Φ) | no — but needs the battery's independent move generator (per R8) | no | The battery re-implements Φ. This is the point of R8. |
| **I5** SCC containment | yes (with battery's own move graph) | no — but needs the battery's independent move generator | no | Reads no stored values; derives from move graph alone. Memory plan in `i5-feasibility.md`. |
| **I6** UNDEF census | yes | no | no | Reads stored UNDEF flags only. |
| **I7** DTT sanity | yes | no | no | Reads stored DTT values only; recurrence check uses battery's own move generator. |
| **I8** truncation-gap regression | yes (at 2×2 only; n/a at larger gobans) | no — uses the committed Python fixtures (T102/T103) | no | The 24-state fixture and both evaluators are committed in `docs/evidence/QA-026/calibration-2x2-mismatch.py`. |
| **I9** anchors | yes | no | no | Reads stored root values only. Anchors are committed in AXIOMS.md §4.4 and pass0 §4. |
| **I10** TIE median | yes | no | no | Reads stored L/H/TIE values only. |
| **I11** move-set consistency | **NO** | **yes — needs Phase 2 kernel's move generator and the solver-side dump utility (SMD1)** | no | The battery's independent move generator (per R8) is needed, AND the solver must dump its move set for comparison. The SMD1 binary format is specified in pass0 design §4.6 but does not exist. Without the solver-side dump, I11 can only compare the battery against itself — vacuously true. |
| **I12** score range | yes | no | no | Reads stored values only; range is fixed by goban geometry. |
| **C-A1/C-A2** closure | **NO** | **yes — needs Phase 2 kernel for the move generator and the full state graph** | no | Specified in T266; requires computing the forward/backward closure of the reachable set. |
| **Key agreement** (G1, G3) | **NO** | **yes — needs Phase 2 kernel's production state-key encoder to compare against the battery's own** | no | T267's invariant: run both encoders on the same state space, count mismatches. Currently only the solver-side encoder exists. |

**Summary:** 10 of 12 invariants are specifiable now and runnable with the battery's own
re-implementations (per R8). I11 and the closure checks (C-A1/C-A2) are **specified now,
runnable after Phase 2**. The key-agreement check (G1/G3) is specified now, runnable after
Phase 2. This is honest: a check specified and unrunnable is a deliverable; a check quietly
not run is the `CODE.BATTERY-STUBBED` failure.

---

## 6. Exit code discipline — refined from pass0

Pass0 R6 specifies three exit classes. The refinement: **add a fourth for measurement-only
invocations**, and name the classes precisely so T291's design does not invent new ones.

| exit code | class | meaning | example |
|---|---|---|---|
| 0 | `pass` | all invariants evaluated; no violations found | I3: 0 L>H violations on artifact X |
| 1 | `artifact-bad` | at least one invariant found a violation in the artifact | I7: DTT uniformly 255 on v1; I4: Bellman violation count > 0 |
| 2 | `battery-bad` | the battery could not complete: OOM, load error, stack overflow, unhandled state space | artifact file not found; 4 GB RSS exceeded; unsupported goban size |
| 3 | `reference-bad` | invariants evaluated cleanly but a measurement disagrees with a committed register figure — the register entry goes to audit, not the artifact | 3×2 pin census mismatch within the known 36-phantom spread; I5 cycle-reachable count matches 1,704 but register says 1,724 |
| 4 | `measurement-only` | invocation requested measurements only (no pass/fail); exit code is always 0 unless battery-bad | I1 pin census report with no register target; bracket-rate report |

**Rule for T291:** exit codes 1–3 are failures (non-zero); exit code 4 is success (zero)
but carries no pass/fail verdict. The `--measurement-only` flag suppresses all violation
checks and reports measurements. The default mode (no flag) enforces all pass conditions
and exits 0–3.

---

## 7. Regression baseline — the documented characteristics of every regression artifact

Per Amendment 1, a regression artifact's pass condition is "no NEW failure." This requires
a recorded baseline. The baseline below records **every known characteristic** — pass and
fail — of each artifact at the time this spec is ratified. A change from baseline is a finding
to adjudicate; it is not automatically a failure.

| artifact | goban | known characteristics |
|---|---|---|
| `artifacts/oracle-2x2.wzo` | 2×2 | All invariants expected to pass. Pin census: measurement only (no register target). Bracket rate (I3 measurement): expected L<H > 0 per E3. I8: 0 mismatches on the 24-fixture / 172 reachable non-terminals. |
| `artifacts/oracle-3x2.wzo` | 3×2 | All invariants expected to pass. Pin census: matches either 2,586 (EXP-4 denominator) or 2,622 (QA-023 denominator) — the spread is documented. I5 cycle-reachable count within known 1,678–1,724 spread. |
| `artifacts/oracle-3x3.wzo` | 3×3 | All invariants expected to pass. Pin census: `L==H=68,350, pin_T=1,248, pin_L=2,080, pin_H=2,080`. Anchors: root=+9. |
| `artifacts/oracle-4x3.wzo` | 4×3 | All invariants expected to pass. No anchor committed. Measurements only for pin census and bracket rate. |
| `data/oracle-4x4-basicko-tie-area.wzo` | 4×4 | **I7: FAILS — DTT uniformly 255 including terminals (documented, expected).** All other invariants: expected to pass (I4 on KO_SENSITIVE-clear slots per pass0; I3, I2, I12 pass; I6 UNDEF census matches 24,318,165 = A094777; I10 TIE ∈ [L,H] passes). Anchors: root=+1. **The I7 failure is the documented baseline — it is not a new finding.** Pin census and bracket rate are measurements. |
| `data/oracle-4x4.checkpoint.wzo` | 4×4 | KO_SENSITIVE column distrusted (foreclosure). I3, I2, I12 expected to pass. I10 TIE median expected to pass. I4 Bellman: run on KO_SENSITIVE-clear slots per pass0; KO_SENSITIVE-set children may contaminate — violations in the ko-sensitive region are documented characteristics, not new findings. Pin census and bracket rate are measurements. |
| `data/oracle-4x4-parallel.checkpoint.wzo` | 4×4 | Same characteristics as `oracle-4x4.checkpoint.wzo`. |

**Process:** the baseline is updated when an adjudication changes the expected behaviour
of an artifact (e.g. v1's DTT column is repaired). The update is a commit to this spec with
a dated entry in the amendment log (§8). The old baseline is preserved in the amendment log,
not silently overwritten.

---

## 8. Amendment log

| date | amendment | by |
|---|---|---|
| 2026-08-03 | Initial spec — T290 | deepseek-v4-pro/T290 |

---

## 9. Scope and handoff

- **This spec gates T291 (design) and T292 (implementation).** T291 reads this spec and
  produces `design.md` — the implementation language, output format, invariant algorithms,
  SMD1 binary format for I11, and the synthetic mutant construction method. T292 reads
  T291's design and implements the battery.
- **Gaps G1–G6 (§2) are specified here.** T291 decides which to include in the Phase 1
  battery as "specified, runnable after Phase 2" and which to defer to a later sprint.
- **The §6a matrix from pass0 carries forward unchanged** — twelve invariants × five gobans
  = sixty cells, with the exhaustiveness declarations (E/S/G/n/a) as written. The matrix is
  not reproduced here to avoid drift; T291 copies it from pass0.
- **Pass0's R8 (shared-code policy: import nothing from `src/`) carries forward.** This spec
  does not reopen that decision; it was flagged for the human at G1 and ratified.
- **I5's memory plan and calibration targets** are in `pass1/i5-feasibility.md` (to be written
  by T291 or a preceding task if not already present at `archive/i5-feasibility.md`).

**Out of scope for this spec:** implementation language, output format, invariant algorithms,
SMD1 binary format, mutant construction method, fleet-run logistics, claim-row format.
Those are T291.
