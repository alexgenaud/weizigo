---
**Model of record:** DeepSeek-Pro (DSPro), acting as Auditor.
**Date:** 2026-07-29.
**Scope:** task 2B-6 — full-chain auditor review of 2B-2 through 2B-5,
the Orchestrator's C1/C2 adjudication, and independent verification
of the four C2 counterexamples.
**Role:** Auditor (read-only) per `docs/infra/roles/AUDITOR.md`.
No edits to `src/`, `CLAIMS.md`, or any 2B-N deliverable.
---

# 2B-6 — Full-chain auditor review

## Verdict summary

| item | verdict |
|---|---|
| Orchestrator's adjudication (C1 survives, C2 falls) | **CORRECT** — the reasoning holds and is the right reading of `CLAIMS.md` |
| DSPro's proposal to mark `QA-023` FALSIFIED | **INCORRECT** — it conflates the §1 restatement's conjunction with the CLAIMS.md row's assertion |
| C2 counterexample (586,1,6,1) | **VERIFIED** — area_score = +1 = truncated value |
| C2 counterexample (534,1,6,1) | **VERIFIED** — area_score = +1 = truncated value |
| C2 counterexample (302,1,6,1) | **VERIFIED by hand computation** — area_score = +1 = truncated value; not in committed stdout |
| C2 counterexample (146,1,6,1) | **FLAGGED** — area_score = +1 per hand computation but probe reports truncated = +3; not in committed stdout; needs re-check |
| 2B-2 census | **STANDS** — corrected numbers from 2B-FIX-KO are canonical; the ko fix closes F5 |
| 2B-3 history-pair generator | **STANDS with caveat** — functionally correct but biased (2B-3-AUDIT §4) |
| 2B-4 probe deliverable | **INVALID** — every number is an artefact; the probe never ran |
| 2B-5 calibration | **STANDS** — both NEG and POS pass; but POS exercises a parallel code path and did not cover the 2B-4 defect |
| 2B-FIX-KO ko fix | **STANDS** — the fix is correct; the probe re-run numbers in §4 are INVALID (same σ-in-arrival defect) |
| 2B-PROBE-FIX | **STANDS** — both defects independently confirmed and fixed; re-measurement valid |

---

## 1. Audit of the Orchestrator's adjudication

### 1.1 The disagreement

- **DSPro** (`probe-fix-2026-07-29.md` §8) proposes marking `QA-023` **FALSIFIED**.
- **Orchestrator** (`qa023-c2-adjudication-2026-07-29.md` §3) argues `QA-023` **must not** be marked FALSIFIED — only `QA-026` and `GLOBAL.LONGCYCLE` fell.

### 1.2 What `QA-023`'s CLAIMS.md row actually asserts

```
QA-023: Under basic ko + a fixed-value long-cycle verdict,
(board, side_to_move, ko_point, passes) is a sufficient
Markovian state for exact solving
```

This asserts **C1 (state-sufficiency)**: the value is a function of the state tuple. It does **not** assert that the function is `median(L, TIE, H)`. That is `QA-026`'s content.

### 1.3 What the reference-semantics §1 restates it as

```
V(σ|h₁) = V(σ|h₂) (C1) — and this common value equals
median(L(σ), TIE, H(σ)) (C2)
```

This is a **conjunction** of C1 and C2. The conjunction is false because C2 is false. But the CLAIMS.md row asserts only C1.

### 1.4 The evidence

Every within-budget evaluation at every eligible state — including the four counterexample states — returns the **same value across all arrival histories tested**. On (586,1,6,1), eight distinct histories all yield truncated = +1. On (534,1,6,1), four distinct histories all yield truncated = +1. The value is invariant in the arrival history — it looks like a function of the state.

The fixpoint says the value is TIE = 0. The truncated evaluator says the value is +1 or +3. The disagreement is about **which number** is the value, not about **whether** the value depends on the arrival history.

### 1.5 Verdict

**The Orchestrator is correct.** `QA-023`'s CLAIMS.md row asserts state-sufficiency (C1). C2's failure is a failure of `QA-026` and `GLOBAL.LONGCYCLE`, not of `QA-023`. Marking `QA-023` FALSIFIED would tell every future reader the representation is dead when the evidence points the opposite way.

**But `QA-023` is not passing.** Per `2B-3-AUDIT` §4, the history generator systematically misses short arrival paths (93% of states) and collected histories share ~62% of their prefixes. The probe has only tested that histories from a narrow, correlated stratum agree — not that short and long histories agree. C1 is **UNTESTED-FOR-WANT-OF-CONTRAST**, not unrefuted, not confirmed. The honest row status remains **CLAIMED**, with the C1/C2 split recorded and the generator-bias caveat attached.

### 1.6 What DSPro's proposal got right

DSPro is correct that the **§1 restatement** is falsified — it is a conjunction and its second half is false. The error is in mapping that falsification onto the CLAIMS.md row, which asserts only the first half. This is a scope error, not a factual one: DSPro read "QA-023" as the conjunction from §1; the Orchestrator read it as the CLAIMS.md row. The CLAIMS.md row is the authoritative statement, so the Orchestrator's reading prevails.

---

## 2. Independent verification of the four C2 counterexamples

### 2.1 State (586,1,6,1) — VERIFIED

Goban colex 586 on 3×2 (base-3, cells 0–5):

```
586 = 2·3⁵ + 1·3⁴ + 0·3³ + 2·3² + 0·3¹ + 1·3⁰
    = 2·243 + 1·81 + 0·27 + 2·9 + 0·3 + 1·1
cell 5=W, cell 4=B, cell 3=␣, cell 2=W, cell 1=␣, cell 0=B
```

Goban layout (3 cols × 2 rows, 0–2 top, 3–5 bottom):

```
B ␣ W   (top)
␣ B W   (bottom)
```

Black stones: cells 0, 4 = 2. White stones: cells 2, 5 = 2.
Empty cells: 1, 3.

- Cell 1 neighbours: 0(B), 2(W), 4(B) → dame (touches both colours).
- Cell 3 neighbours: 0(B), 4(B) → Black territory.

Black: 2 stones + 1 territory = **3**. White: 2 stones + 0 territory = **2**.
**`area_score = +1`** = truncated value. ✓

Side = White (1), passes = 1, ko = 6 (none). White's only legal move is pass
(two empty cells but both placements are suicide — cell 1 joins a White chain
with 0 liberties and no captures; cell 5 has no friendly neighbours and touches
only Black stones with other liberties). White passes → passes = 2 → terminal
→ area_score = +1. The evaluator returns +1. **The evaluator is right; the
fixpoint's TIE pin is wrong.**

Orchestrator's hand-check confirmed. Eight distinct arrival histories, all
yield truncated = +1. **C1 holds on this state; C2 fails.**

### 2.2 State (534,1,6,1) — VERIFIED

```
534 = 2·3⁵ + 0·3⁴ + 1·3³ + 2·3² + 1·3¹ + 0·3⁰
cell 5=W, cell 4=␣, cell 3=B, cell 2=W, cell 1=B, cell 0=␣
```

```
␣ B W   (top)
B ␣ W   (bottom)
```

Black: cells 1, 3 = 2. White: cells 2, 5 = 2.
Empty: 0, 4.

- Cell 0 neighbours: 1(B), 3(B) → Black territory.
- Cell 4 neighbours: 1(B), 3(B), 5(W) → dame.

Black: 2 + 1 = **3**. White: 2 + 0 = **2**.
**`area_score = +1`** = truncated value. ✓

Same mechanism: White to move, passes = 1, only pass is legal. **Verified.**

### 2.3 State (302,1,6,1) — VERIFIED by hand computation; not in committed stdout

```
302 = 1·3⁵ + 0·3⁴ + 2·3³ + 0·3² + 1·3¹ + 2·3⁰
cell 5=B, cell 4=␣, cell 3=W, cell 2=␣, cell 1=B, cell 0=W
```

```
W B ␣   (top)
W ␣ B   (bottom)
```

Black: cells 1, 5 = 2. White: cells 0, 3 = 2.
Empty: 2, 4.

- Cell 2 neighbours: 1(B), 5(B) → Black territory.
- Cell 4 neighbours: 1(B), 3(W), 5(B) → dame.

Black: 2 + 1 = **3**. White: 2 + 0 = **2**.
**`area_score = +1`** = truncated value (per deliverable §4). ✓

**Not independently reproducible from committed stdout.** The committed
`probe-fix-2026-07-29.stdout` (256 samples, seed 0x2B4DA7A) shows disagreements
only on states 586 and 534, both truncated = +1. State 302 appears only in the
deliverable's per-state table (§4), attributed to a 512-sample run whose stdout
is not committed. The area_score computation checks out.

### 2.4 State (146,1,6,1) — FLAGGED

```
146 = 0·3⁵ + 1·3⁴ + 2·3³ + 1·3² + 0·3¹ + 2·3⁰
cell 5=␣, cell 4=B, cell 3=W, cell 2=B, cell 1=␣, cell 0=W
```

```
W ␣ B   (top)
W B ␣   (bottom)
```

Black: cells 2, 4 = 2. White: cells 0, 3 = 2.
Empty: 1, 5.

- Cell 1 neighbours: 0(W), 2(B), 4(B) → dame.
- Cell 5 neighbours: 2(B), 4(B) → Black territory.

Black: 2 + 1 = **3**. White: 2 + 0 = **2**.
**`area_score = +1`**.

**The deliverable reports `truncated = +3` for this state.** My hand computation
gives area_score = +1. If White (minimizer) passes, the game ends at +1. Both
White placements (cells 1 and 5) are suicide: cell 1 joins the {0,1,3} White
chain with 0 liberties and no captures; cell 5 has no friendly neighbours and
touches only Black stones with other liberties. White's only legal move is pass
→ +1. The truncated value should be +1, not +3.

**Three possibilities, in order of likelihood:**

1. **The state's truncated value is genuinely +1 and the +3 in the deliverable
   is a transcription error.** The 256-sample committed stdout shows only
   truncated = +1 disagreements. The +3 appears only in the uncommitted
   512-sample run's table. A copy-paste error moving numbers from a depth-24
   run into the §4 table is the most common failure mode in this chain.

2. **I decoded the goban incorrectly.** The `unrank_board` function in
   `qa023_probe.zig` may use a different colex ordering (e.g. cell-major rather
   than position-major, or reversed digit significance). If the actual goban
   differs from my decoding, the area_score could be +3. This would make the
   counterexample valid but for a different goban than the one I computed.

3. **The evaluator found a non-pass continuation at depth > 1 where Black
   forces a higher score.** This is unlikely given the suicide analysis but
   cannot be ruled out without running the evaluator step-by-step on this
   state.

**Recommendation:** re-run the 512-sample probe and dump the arrival sequences
for (146,1,6,1) to verify the goban encoding and the evaluator's continuation
tree. Also verify `unrank_board` produces the goban I decoded above. **Do not
cite (146,1,6,1) as a C2 counterexample until this discrepancy is resolved.**

### 2.5 Summary of counterexample verification

| state | area_score | truncated | committed stdout? | verdict |
|---|---|---|---|---|
| (586,1,6,1) | +1 | +1 | yes (8×) | ✓ VERIFIED |
| (534,1,6,1) | +1 | +1 | yes (4×) | ✓ VERIFIED |
| (302,1,6,1) | +1 | +1 | no | ✓ hand-checked |
| (146,1,6,1) | +1 | **+3** | no | ⚠ FLAGGED |

**The C2 falsification stands on (586,1,6,1) and (534,1,6,1) alone** — two
states, twelve within-budget evaluations, zero C1 failures, committed stdout,
independently verified. Two counterexamples are enough to falsify a universal
claim. The 146 discrepancy is worth resolving but does not affect the verdict.

The Orchestrator hand-checked only (586,1,6,1). That was sufficient for the
adjudication — one genuine counterexample falsifies — but the other three
should not be quoted as "verified" on that basis.

---

## 3. Grade of which 2B-N conclusions survive

### 3.1 2B-2 (census): STANDS, corrected numbers canonical

**Status banners correct? YES.** The `census-3x2-2026-07-29.md` banner correctly
flags superseded numbers from the ko-rule defect (F5) and points to
`ko-fix-rerun-2026-07-29.md` for corrected figures. The `PROVENANCE` banner is
also correct.

**What survives:**

- The cycle census conclusion: 3×2 hosts cycles → non-vacuous test surface.
  **Robust to the ko fix** — more cycles, not fewer (216,176 vs 143,760).
- The SCC structural analysis: one non-trivial SCC, all-even cycle lengths.
  Independently reproduced by two auditors (kimi-k2.7 and opus-5).
- **The corrected numbers from `ko-fix-rerun-2026-07-29.md` §3 are canonical:**
  V = 2,622, E = 5,668, cycle-involved = 1,676, cycle-reachable = 1,704,
  216,176 cycles at cap 14.

**What does not survive:**

- The "honest caveats" about caps 16/18/20 hitting the cycle cap — all false
  (F2). Cap 22 completes naturally at 132,966,392 cycles.
- The 2×2 no-cycle assertion (F6) — 2×2 basic ko has a 144-vertex SCC under
  the old rule and 160 under the corrected rule. `2x2.T12` is PSK-scoped and
  does not transfer.
- The "42-seed" reachable count of 2,682 (F1) — 36 phantom states. The true
  game-root count is 2,583. Not load-bearing for any conclusion.

**Grade: VERIFIED with corrected numbers.** The core machinery is solid and
doubly independently reproduced. The documentation caveats need repair (F2,
F3, F4, F6) but the underlying claim does not.

### 3.2 2B-3 (history-pair generator): STANDS with caveat

**Status banner correct? YES.** Flags superseded numbers from ko rule and
correctly points to the re-run (102/102, 2,563/2,563).

**What survives:**

- The generator is functionally correct. All histories are legal, reachable,
  simple paths with correctly computed visit-sets. Independently reproduced
  by `2B-3-AUDIT` (Python, different sampling, different DFS).
- The vacuity guard passes: 102/102 multi-history states have visit-set-distinct
  histories. The QA-023 probe has genuinely different inputs.
- Both author-found bugs (pass detection, placed-cell detection) are correctly
  identified and correctly fixed.

**Caveat that limits downstream use:**

- The DFS-only collector systematically misses short arrival paths (93% of
  states). Collected histories average depth 14.8 vs shortest-path 5.1, and
  share ~62% of their prefixes pairwise (`2B-3-AUDIT` §4). A "no C1 failure"
  result from this generator means "no failure among histories sharing 62%
  of their prefixes" — not "no failure among all histories."

**Grade: VERIFIED functionally, PARTIAL as a C1 instrument.** The generator
is correct at what it does; what it does not do (collect short, maximally
contrasting histories) limits the probe's C1 detection power. This is a
design limitation, not an implementation defect.

### 3.3 2B-4 (probe): INVALID — every number is an artefact

**Status banner correct? YES.** The banner reads "⛔ SUPERSEDED — EVERY NUMBER
IN THIS FILE IS INVALID" and correctly identifies the σ-in-arrival defect.

**What does not survive:**

- **390 disagreements / 1,080 (36.1%)**: artefact. The evaluator returned TIE
  on its first node for every evaluation. "Disagreements" counted states whose
  fixpoint value ≠ 0.
- **"QA-023 FALSIFIED"**: withdrawn. The probe never tested QA-023.
- **Perturbation test "116/177"**: never executed. The code path is unreachable
  when every evaluation returns TIE (§6.1 of ko-fix-rerun). The "116" and "177"
  were misread from `cycle_census_states: 116` and `samples evaluated: 177`.
- **"TIE is on the optimal line"**: unsupported. No perturbation was measured.
- **Every number in the three-way split**: the split was `{0, 690, 390}` where
  it should have been `{45, 20, 12}` with 1,056 budget-exhausted.

**Grade: WRONG.** This is not a superseded-number situation where the
conclusions shifted — the measurement never happened. The deliverable should
carry the INVALID banner it has and serve only as a warning to future readers.

### 3.4 2B-5 (calibration): STANDS, both calibrations pass

**Status banner: none present.** The deliverable carries no superseded banner
and does not need one — both calibrations exercise code paths unaffected by
the σ-in-arrival defect.

**NEG calibration: VERIFIED.** The `calibrate-neg` mode perturbs L[s0] from
1 to 2 on the synthetic four-state gadget, producing exactly 1 divergence vs
the unperturbed baseline (0 → 1). The probe correctly detects the planted
wrong value. Committed stdout (`calibration-neg-2B5.stdout`) confirms.

**POS calibration: VERIFIED.** The PSK probe (`probe-psk-3x2`) detects 48–68
PSK disagreements in two seeded runs, exceeding T13's 12 mismatches by a
factor of 4–5.7. The probe is sensitive enough to detect known
history-sensitivity at 3×2 under PSK semantics.

**Critical caveat (not in the deliverable):** the POS calibration exercises a
**parallel code path** — `psk_exact_value` and `psk_collect_histories` instead
of `truncated_value` and `collect_histories_dfs_impl`. The PSK evaluator does
not share the defective `:1721` call site. So **POS passing did not validate
the basic-ko arm** — it validated that the *concept* of a history-conditioned
evaluator can detect disagreements, not that this particular evaluator was
correct. The `probe-defect-2026-07-29/README.md` §7 notes this gap; the 2B-5
deliverable does not. This should be added to the deliverable as a caveat.

**Grade: VERIFIED for calibration claims; PARTIAL as coverage of the basic-ko
instrument.** The calibrations prove the probe *concept* works; they did not
prove the probe *implementation* worked, and the distinction mattered.

### 3.5 2B-FIX-KO (ko fix): STANDS for the fix; probe re-run INVALID

**Status banner correct? PARTIALLY.** The banner correctly flags the probe
re-run numbers (§4) as INVALID and points to the defect README. The ko fix
itself (§1–§3) and the 2×2 cycle finding (§6.2) are correctly marked as
standing.

**What survives:**

- The ko fix itself: one conjunct (`friendly == 0`) added to `apply_place` in
  both `qa023_probe.zig` and `qa023_brute_2x2.zig`. Correctly implements the
  single-stone ko capture rule from `proof-v2` §1.1. Independently verified
  against a Python implementation stating the condition differently, with the
  census predictions matching to the digit.
- Corrected census numbers (§3): **these are the canonical 3×2 figures.**
- The 2×2 cycle finding (§6.2): `2x2.T12` is false for basic ko under both
  the old and corrected rule. The 2×2 reachable graph has a non-trivial SCC.
- The unreachable perturbation branch (§6.1): correctly identified; same root
  cause as the σ-in-arrival defect.

**What does not survive:**

- **454 disagreements / 1,133 (40.1%)**: INVALID — same σ-in-arrival defect
  as 2B-4. The count rose from 390 because the ko fix changed the pin census,
  not because of any history-sensitivity measurement.
- **"The falsification is not a wrong-rule artefact"**: UNSUPPORTED. Both
  sides of the comparison were pinned to TIE.
- **All 12 seed × depth runs**: INVALID for the same reason.

**Grade: VERIFIED for the fix; INVALID for the probe re-run.** These two
halves must be cited separately — the fix is solid, the re-run is an artefact.

### 3.6 2B-PROBE-FIX: STANDS

**Status: no superseded banner needed — this IS the fix.**

Both defects independently confirmed (1,133/1,133 σ-in-arrival collisions
before fix, 0 after). Three-way split now discriminates: 45 value-agreements,
20 TIE, 12 disagreements, 1,056 budget-exhausted, 0 scratch-overflow.
`--node-budget` flag added. C1/C2 split reported separately.

**One documentation issue:** the deliverable's §4 per-state table lists four
states from a 512-sample run whose stdout is not committed. The committed
stdout (256 samples, seed 0x2B4DA7A) shows only states 586 and 534. The
256-sample run is reproducible; the 512-sample run is not. §8 proposes marking
`QA-023` FALSIFIED, which this audit disagrees with (see §1).

**Grade: VERIFIED for the fix and re-measurement.** The C1/C2 split is the
right structure. The proposed claim-status change for `QA-023` should be
overridden per §1 of this audit.

---

## 4. The audit process: five links, four passed the artefact through

### 4.1 The chain

| # | audit link | scope | caught the σ-in-arrival defect? |
|---|---|---|---|
| 1 | 2B-2-AUDIT (kimi-k2.7) | census numbers | no — census is a separate code path |
| 2 | 2B-2-AUDIT-OPUS (opus-5) | census + ko rule | no — found F5 (ko rule) but didn't trace to probe call site |
| 3 | 2B-3-AUDIT (DSPro) | history generator | no — reviewed collector code up to but not including the `truncated_value` call at :1721 |
| 4 | 2B-5 POS calibration (DSPro) | PSK sensitivity | no — exercised parallel `psk_exact_value` path, not the defective `truncated_value` call |
| 5 | Orchestrator absorption check (opus-5) | whole probe pipeline | **YES** — read the call site, found σ-in-arrival |

Link 4 is the structural failure: a positive calibration that passes a
**parallel implementation** of the concept provides zero coverage of the
instrument under test. It is like calibrating a thermometer by testing a
different thermometer of the same design — it proves the design can work, not
that this unit is wired correctly.

Link 3 is the proximity failure: the `2B-3-AUDIT` traced `collect_histories`
and `visit_set_of_arrival` in detail but stopped one function call short of
`truncated_value`. The defect was at the boundary between the generator
(which 2B-3-AUDIT verified) and the evaluator (which it didn't). Auditing
the generator without auditing what consumes its output is verifying the
fuel without checking the engine.

### 4.2 What should change

**1. An auditor reviewing a measurement pipeline must trace one complete
evaluation end-to-end.** Not just the input generator, not just the output
statistics — the full call chain from sampled state to reported number. A
single hand-traced example would have caught this: pick one state, hand-compute
the arrival, hand-compute the area_score, hand-trace `truncated_value`, compare
to the reported output. The Orchestrator's §4 worked counterexample is exactly
this discipline, applied after the fact.

**2. A positive calibration must exercise the instrument under test, not a
parallel implementation.** If the calibration passes a different code path, it
calibrates the *design*, not the *implementation*. This audit recommends:
whenever a task ships a calibration, the brief should require the calibrator to
state which code path it exercises, and the auditor should verify that path
overlaps the measurement path. A calibration on a parallel path should be
labelled "design calibration", not "instrument calibration".

**3. The `probe-defect` README should become a standing test.** Add a
hardcoded test case to `qa023_probe.zig` that evaluates a state of known value
(like the §4 worked counterexample: goban 586, White to move, passes=1,
expects +1 not TIE). Run it in `zig test`. A probe that returns TIE on that
state is broken. This would have caught the defect in CI, not in an absorption
check at the promotion gate.

**4. The committed stdout for 2B-PROBE-FIX should include the 512-sample run**
whose per-state table is cited in §4. Two of the four counterexample states
(302 and 146) are not independently reproducible from the committed evidence.

---

## 5. Proposed claim-status lines (for `EVIDENCE-INTEGRITY`)

| claim | proposed status | reason |
|---|---|---|
| `QA-023` | **remains CLAIMED** | C1 (state-sufficiency) untested-for-want-of-contrast. C2 failure is `QA-026`'s content, not this row's. Attach note: "C2 falsified at 3×2; this is not evidence against C1." |
| `QA-026` | **FALSE-AS-SCOPED at 3×2** | `median(L, TIE, H)` over-pins TIE on states whose history-conditioned value is +1. Four counterexample states; 12 within-budget disagreements; independently verified on two of the four. |
| `QA-013` / `GLOBAL.LONGCYCLE` | **FALSE-AS-SCOPED at 3×2** | "Long cycles … resolved as a loopy-game fixpoint with loops pinned to the tie value." The pin rule is falsified. |
| `3x2.QA023.B-PROBE` | **SPLIT** into `…B-PROBE-C1` (UNTESTED) and `…B-PROBE-C2` (FALSE-AS-SCOPED) | Per `probe-fix-2026-07-29.md` §5. |
| `3x2.QA023.B-VACUITY` | **PROVEN** | Corrected census: 216,176 cycles at cap 14, 1,676 cycle-involved, independently reproduced by two auditors. |
| `3x2.QA023.B-CAL-NEG` | **PROVEN** | `calibrate-neg` catches the planted perturbation. Committed stdout. |
| `3x2.QA023.B-CAL-POS` | **PROVEN** | PSK probe detects 48–68 disagreements, exceeding T13's 12. Caveat: exercises parallel code path — design calibration, not basic-ko instrument calibration. |
| `2x2.T12` | **rescope to PSK** | False for basic ko under both old and corrected rule (160-vertex SCC). True and trivial under PSK. |
| `GLOBAL.F2-REMEDY` | **remains CLAIMED**, annotated | The `median(L,T,H)` pin rule is falsified at 3×2. The design needs a replacement value rule. Tractability estimate (tens of minutes at 4×4) no longer supported — a proper loopy-game solution may need dependency-set machinery. |

---

## 6. Calibration note — this auditor's own check

**Calibration question:** would a still-broken probe (defect 1 unfixed) have
passed this audit's checks?

| check | broken probe would report | would this audit catch it? |
|---|---|---|
| Hand-compute area_score at (586,1,6,1) | TIE, not +1 | **YES** — the area_score hand-computation disagrees with the reported TIE, which is flagged |
| Three-way split: value-agreements = 0 | reported as 0 | **YES** — 0 value-agreements on a graph with known terminal states is a signature |
| Budget-exhausted = 0 / 1,133 | reported as 0 | **YES** — 0 exhaustion on a densely cyclic graph is implausible, as the defect README notes |
| σ-in-arrival collision counter | 1,133/1,133 | **YES** — the counter was added by 2B-PROBE-FIX and is part of the re-measurement |

A broken probe would fail all four checks. **This audit's wrong-answer pass rate
is low** — the checks are discriminating. The one gap: if I had not read the
defect README and had instead audited 2B-4 cold, I might have stopped at "the
numbers are internally consistent" without tracing the call site. The §4.2
recommendation (trace one complete evaluation end-to-end) is the guard against
that.

---

## 7. What this audit did not do

- No edits to `src/`, `CLAIMS.md`, or any 2B-N deliverable.
- Did not re-run the probe (read-only audit — the committed stdout + hand
  computation is the verification method).
- Did not adjudicate the (146,1,6,1) +3 discrepancy beyond flagging it.
- Did not verify the depth-sweep numbers in `probe-fix-2026-07-29.md` §3
  against committed stdout (the depth-sweep stdout is not committed).
- Did not verify the 512-sample run cited in `probe-fix-2026-07-29.md` §4
  (stdout not committed).

## 8. Files

- `docs/audits/2026-07-29-2b-6-full-review.md` — this file.
- No evidence files produced — read-only audit. Verification by hand
  computation and source-code review, not by re-measurement.
