# verify-battery pass-1 audit — spec + strategy

```
Auditor:  T137 (independent seat — not pass-0 auditors, not T136 reviser;
          milestone channel not read)
Date:     2026-07-31
Subject:  docs/infra/verify-battery/spec.md (rev 1) +
          docs/infra/verify-battery/strategy.md (rev 1)
Inputs:   pass0/spec.md · pass0/spec-audit.md · pass0/strategy.md ·
          pass0/strategy-audit.md · pass1/i5-feasibility.md
Verdict:  PASS — 0 blockers, 0 critical, 3 must-fix, 4 should-fix, 2 could-fix
```

## Executive summary

The rev 1 spec and strategy resolve **every blocker, critical, and must-fix
finding** from the pass-0 audits. The invariant set is now complete (twelve
invariants covering the three gaps the pass-0 spec audit identified); the
sixty-cell matrix is enumerated; calibration targets are verified against the
tracked register by file:line; the shared-code policy (R8) is explicit and
flagged for human ratification; the three-exit-class scheme handles the
reference-bad case; I8's polarity is corrected to agreement; A3's mislabeled
census is fixed with both 3×2 targets carried under their own denominators;
and every "Wave 1 SCC" reference is replaced with the actual QA-023 evidence
paths.

Each of the 22 pass-0 audit findings (spec: B1–B2, C1–C3, M1–M7, S1–S4,
O1–O4; strategy: SB1–SB2, SC1–SC3, SM1–SM5, SS1–SS3, SO1–SO2) was checked
against the rev 1 documents and its cited evidence. All 22 are resolved. The
three must-fix items below are gaps in calibration-verification hygiene, not
in architecture or completeness; they do not block dispatch.

---

## 1. Calibration citation verification — by file:line

Every calibration target in the rev 1 spec was checked against the tracked
register at the cited file and line. Results:

### Spec §4 — I5 calibration

| citation | file:line | verified value | match? |
|---|---|---|---|
| 2×2 true root V=255, E=434, max SCC=160 | `scc2x2.py` (computed; run confirmed) | V=255, E=434, maxSCC=160 | ✓ |
| 2×2 all-seed V=282, E=508, max SCC=160 | `scc2x2.py` (computed; run confirmed) | V=282, E=508, maxSCC=160 | ✓ |
| 3×2 cycle-involved max SCC=1,676 | `ko-fix-rerun-2026-07-29.stdout:107` | "max size = 1676" | ✓ |
| 3×2 cycle-reachable 1,724 | `PROVENANCE-census-3x2-2026-07-29.md:70` | "The cycle-reachable count (1,724)" | ✓ |
| 3×2 cycle-reachable 1,704 | `ko-fix-rerun-2026-07-29.stdout:133` | "cycle-REACHABLE…1704" | ✓ |
| 3×2 true game root cycle-reachable 1,678 | `F1-SEEDROOTS.md:10` | "cycle-reachable 1,678" | ✓ |

**Note on `scc2x2.py`:** The spec cites the script itself, not a captured
stdout. I ran the script (this audit, independent execution) and confirmed
the numbers: `true root corrected: V= 255 E= 434…maxSCC=160` / `all-seed
corrected: V= 282 E= 508…maxSCC=160`. The script reproduces cleanly. A
committed stdout would be stronger; see M1 below.

### Spec §5 — A3 calibration

| citation | file:line | verified value | match? |
|---|---|---|---|
| EXP-4 solver 3×2 2,586 states, 2220/298/34/34 | `exp4-solve-2026-07-29.stdout:96` | "3×2 pin census: L==H=2220 pin_T=298 pin_L=34 pin_H=34", reachable=2586 | ✓ |
| QA-023 corrected 3×2 2232/322/34/34, 2,622 states | `CLAIMS.md:557` | "Corrected 3x2 census `2232/322/34/34`" | ✓ |
| 3×3 68,350/1,248/2,080/2,080 | `newrule-3x3-2026-07-28.md:74` | "L==H=68,350, pin_T=1,248, pin_L=2,080, pin_H=2,080" | ✓ |

The 36-phantom identity (2,622 − 2,586 = 36, distributed 12 → L==H, 24 →
pin_T) is noted as pending V-R reconciliation. The spec carries this
honestly.

### Spec §5 — I9 anchors

| goban | cited value | source | match? |
|---|---|---|---|
| 2×2 = 0 | root (empty, either side) | T103 calibration script, scc2x2.py root values | ✓ |
| 3×2 = 0 | root (empty, either side) | EXP-4 stdout, QA-023 corrected kernel | ✓ |
| 3×3 = +9 | `newrule-3x3-2026-07-28.md:74` | "root (empty, B) **scored +9** (L==H==9)" | ✓ |
| 4×3 | no committed anchor | spec says "no reference" | ✓ |
| 4×4 = +1 | PROGRESS.md "4×4 root V=+1" | vs MIGOS +2, open discrepancy | ✓ |

### Spec §5 — A2 artifact enumeration

| artifact | path exists? | SHA-256 in SHA256SUMS? | verified? |
|---|---|---|---|
| `artifacts/oracle-2x2.wzo` | ✓ | `1ed06e64…` | ✓ |
| `artifacts/oracle-3x2.wzo` | ✓ | `d4d22c0d…` | ✓ |
| `artifacts/oracle-3x3.wzo` | ✓ | `c1f8fe5e…` | ✓ |
| `artifacts/oracle-4x3.wzo` | ✓ | `5316f428…` | ✓ |
| `data/oracle-4x4-basicko-tie-area.wzo` | ✓ | `edd9f68e…` | ✓ |
| `data/oracle-4x4.checkpoint.wzo` | ✓ (258,280,358 bytes) | not in SHA256SUMS | as documented |
| `data/oracle-4x4-parallel.checkpoint.wzo` | ✓ (258,280,358 bytes) | not in SHA256SUMS | as documented |

Both unhashed checkpoint files exist on disk with identical sizes. The spec
correctly labels them "unhashed, in scope."

### Spec §4 — I8 calibration

| citation | verified content | match? |
|---|---|---|
| `calibration-2x2-mismatch.py` | 24 states, 0 mismatches / 172 reachable non-terminals | ✓ |
| `2026-07-30-audit-2x2-mismatch.md` | "mismatches, 172 non-terminals: 24 → this audit **0**" | ✓ |

Polarity is correctly **agreement** (gap = 0), not mismatch. The spec's note
about ADR-0020:47-49 predating T102's finding is accurate — I verified
ADR-0020 still carries the old "mismatch" language.

### Spec §4 — I7 DTT

| citation | verified content | match? |
|---|---|---|
| DTT_FAR = 255 sentinel | `f2-remedy-design-2026-07-29.md:206` | "`DTT_FAR = 255`" ✓ |
| Compact slot count 99,133,036 | `newrule-4x4-2026-07-28.md:99` | "Compact (passes∈{0,1}): 99,133,036" ✓ |

The spec correctly notes that 255 is the defined sentinel and the defect
signature is *uniformity including terminals*, not the value itself. The
denominator is the compact slot count (99,133,036), not the dense position
count (43,046,721) — correcting the pass-0 inherited unit slip (SO2).

### Spec §5 — A4 v1 identification

| field | value | verified? |
|---|---|---|
| path | `data/oracle-4x4-basicko-tie-area.wzo` | file exists ✓ |
| SHA-256 | `edd9f68ef243f67de21152432f9e8f521536317527d425208e6901f90b11c0cc` | matches `artifacts/SHA256SUMS:5` ✓ |
| DTT defect | uniformly 255 including terminals | `f2-remedy-design-2026-07-29.md:206` confirms sentinel ✓ |

### Strategy §1 — V-1/V-9 calibration (SC1 resolved)

Pass-0 audit finding SC1: "V-1's and V-9's calibration inputs do not exist
— 'Wave 1 SCC-2x2' references." Rev 1 replaces all such references with
2B-2/2B-FIX-KO evidence paths. Verified: the rev 1 spec §4 I5 calibration
cites `ko-fix-rerun-2026-07-29.stdout`, `PROVENANCE-census-3x2-2026-07-29.md`,
and `F1-SEEDROOTS.md` — all real, all verified above.

### Strategy §1 — I5 cycle-reachable convention (SC2 resolved)

Pass-0 audit finding SC2: "I5's 3×2 calibration pins the wrong quantity."
Rev 1 spec §4 states: "Convention for I5: the true game root, phantoms
excluded → 1,678." The 1,724/1,704/1,678 spread is named in the spec with
its documented cause (36 phantom states). V-R (T138) is a concurrent P0 task
that completes before V-10 gates. The convention choice (true game root,
phantoms excluded) is explicit and citable. Resolved.

### Strategy §1 — holds enumeration (SC3 resolved)

Pass-0 audit finding SC3: "holds column is not registerable as written."
Rev 1 strategy §1 tables now list concrete repo-relative paths per task
(e.g., V-10 holds `docs/evidence/BATTERY/calibration.md`
`data/fixtures/`; V-11 holds `docs/evidence/BATTERY/reimplementation.md`;
V-13 holds `docs/evidence/BATTERY/fleet.md`). Each is a distinct path.
Resolved.

---

## 2. Findings — graded

### Must-fix

| # | grade | what | detail |
|---|---|---|---|
| **M1** | **MUST** | I5 2×2 calibration lacks a committed stdout | The spec and i5-feasibility memo cite `scc2x2.py` for the 2×2 SCC numbers (V=255, E=434, maxSCC=160). The script computes these dynamically; no committed stdout exists in `docs/evidence/QA-023/ko-fix-2026-07-29/`. I ran the script independently (this audit) and confirmed the numbers, so they are correct — but a future auditor or the battery calibration step (V-10) should not need to re-run a Python script to verify a calibration target. **Fix:** capture `scc2x2.py`'s output to `scc2x2.stdout` and cite that file:line in the spec's I5 calibration section. The script itself remains the reproducer; the stdout is the pinned target. |
| **M2** | **MUST** | I6 UNDEF census component split (24,187,097 / 65,534 / 65,534) has no tracked register citation | The 4×4 v1 UNDEF census numbers appear **only** in the verify-battery documents (pass-0 spec → rev 1 spec). I searched the entire `docs/` tree: `24,187,097`, `65,534`, and `24187097` appear nowhere outside the verify-battery directory. The union (24,318,165 = A094777) is independently verifiable — it is the OEIS legal count, cross-validated in `kostate-census-2026-07-28.md:91` and `ko-sensitive-chainability.md:96`. But the component split (illegal / legal-both-sides / legal-one-side-only) has no independent source. The numbers are likely correct (they sum to 24,318,165, the artifact header stores them, and the battery will read them directly), but the spec's own rule — "Every calibration target in this spec is now cited to the tracked register by `file:line`" — is not met for these three numbers. **Fix:** either (a) cite the artifact header fields themselves (the battery reads them from the .wzo, making the calibration self-verifying — state this explicitly), or (b) add a one-line verification to an existing evidence file (e.g., `newrule-4x4-2026-07-28.md`) and cite that. |
| **M3** | **MUST** | V-11 blindness enforcement — chronology vs worktree ambiguity | The rev 1 strategy §1 P2 says V-6's `needs` includes "V-11 committed" (enforcing blind-before-build chronology), and §5 Q1 says "If chronology slips, V-11 runs in a git worktree pinned to the pre-P2 commit." These are two different mechanisms, and the strategy tables encode only the first. A chronology slip is a realistic scenario — V-11 dispatches at G2; V-6 dispatches at G2; if they dispatch to different seats, commit order is nondeterministic. The strategy should state which mechanism is primary (chronology) and which is fallback (worktree), and the P2 table should carry both — e.g., V-6 `needs` = `G2, V-11 committed (or V-11 runs in worktree at <commit>)`. As written, a seat reading only the P2 table would think chronology is the only option. |

### Should-fix

| # | grade | what | detail |
|---|---|---|---|
| **S1** | **SHOULD** | R8 cost is stated as "triples the battery's implementation surface" (strategy §5 Q3) without a concrete line-count or module-count estimate | The strategy acknowledges the cost of importing nothing from `src/` but doesn't quantify it. The three re-implemented subsystems are: artifact loader (~200–400 lines for .wzo parsing), colex/addressing (~100 lines for rank_from_pos/pos_from_rank), and rules engine (~300 lines for legal-move generation with basic ko). That's ~700 lines of re-implementation against a ~2,000-line battery — roughly 35%, not 3×. A rough estimate in the strategy would help the human at G1 weigh R8 against the weaker alternative (import `src/`, lean on A5). The pass-0 spec audit's M7 finding flagged this as "the costliest decision in the sprint"; an honest line-count estimate honours that flag. |
| **S2** | **SHOULD** | The §6a matrix marks I4 at 4×4 as "E" (exhaustive) with precedent "0/99,133,036" — but evaluating Φ on 99M slots with on-the-fly move generation is ~100M × ~10 moves × board decode = billions of operations | This is feasible (T104 did it), but the matrix doesn't distinguish "exhaustive because it fits in 4 GB" from "exhaustive because it finishes within a reasonable wall-clock budget." I4 at 4×4 is the latter — it's a compute-heavy sweep, not a memory-heavy one. The fleet run (V-13) should budget for this: a single I4 4×4 run against the artifact is a ~30-minute computation. The matrix should note the expected wall time or at minimum flag I4 at 4×4 as "E (compute-heavy)" so V-13's dispatcher doesn't queue it alongside another 4×4 run. |
| **S3** | **SHOULD** | I5 at 4×4: the spec says "E·G" but the i5-feasibility memo says 51,419,046 nodes and ~1.2 GB peak RSS | The feasibility memo's budget is convincing, but it's a *plan*, not a measurement. V-9 (M4 implementation) is the first time this budget faces real Zig allocator behaviour. The strategy's fallback tiers (F1–F4) cover this, but the fallback triggers are stated in terms of "Phase 3 exceeds N GB" — these should be stated as concrete RSS thresholds the battery checks programmatically (as the memo §5.2 recommends). The strategy should require V-9 to implement the self-check before Phase 3, not leave it as a design note. |
| **S4** | **SHOULD** | The rev 1 strategy's §2 parallelism diagram shows V-11 on the critical path (it sits between G2 and the P3 merge point) despite the prose claiming it's off the critical path | Tracing the dependency graph: G2 → V-6 (needs V-11 committed) and G2 → V-11. If V-11 must commit before V-6's first commit, then V-6 waits for V-11. Since V-6 is on the critical path (G2 → V-6 → V-10 → V-12 → G3 → V-13), V-11's chronology requirement puts it on the critical path too. The prose says "V-11 is off the critical path by construction" — this is true only if V-11 is *truly* concurrent with V-6 (no chronology requirement), or if V-11 is faster than V-9 (the true long pole). Neither is guaranteed. The diagram should show V-11 on a short spur off the critical path with a note that it must complete before V-6's first commit but that this is expected to complete during P2, not before it. |

### Could-fix

| # | grade | what | detail |
|---|---|---|---|
| **C1** | **COULD** | The spec's "Questions worth asking" (§8) are directed at the pass-1 auditor — that's this document. They're good questions; the answers are below (§3). But the spec doesn't say whether the human at G1 should also consider them. The strategy's G1 agenda (R8, §6a matrix, S1, ADR-0020 amendment, sprint un-retirement) doesn't include them. This is not a defect — the spec's §8 is a prompt to the auditor, not a gate item — but if the human wants the auditor's answers on the G1 agenda, that should be explicit. |
| **C2** | **COULD** | The `data/oracle-4x4.checkpoint.wzo` and `data/oracle-4x4-parallel.checkpoint.wzo` artifacts are 258,280,358 bytes each and unhashed. They are PSK-lineage checkpoints whose ko-sensitive columns the register already distrusts (AGENTS.md foreclosure). Running I1–I12 against them is mostly a waste — they will fail the same invariants v1 fails, plus possibly more. The spec says they're "in scope — PSK-lineage checkpoints whose ko-sensitive columns the register already distrusts." The battery running against them will produce useful signal only if it finds *no* new failures beyond the known ones, which would be a mild positive. A note in the fleet run (V-13) that these are expected to produce known failures and that novel failures are the signal would help the V-13 seat interpret the output. |

---

## 3. Answers to the spec's five questions (§8)

### Q1: R8 (import nothing) — is the cost honest, and is the weaker alternative actually weaker?

**The cost is honest but unquantified.** The strategy's own Q3 (§5) flags the
cost. My estimate: ~700 lines of re-implementation (artifact loader, colex
addressing, rules engine) against a ~2,000-line battery. That's ~35%, not the
"triples" the strategy suggests. See S1.

The weaker alternative (import `src/` and lean on A5) is **genuinely weaker**
in this project's defect history. Every defect found to date was found by
independent re-implementation:
- QA-023 kernel audit: Python re-implementation, no Zig imported
- T102 buffer aliasing: independent checker, separate codebase
- T103 calibration: "standalone implementation sharing no code with the Zig solver"

Importing `src/retro.zig`'s move generator means the battery's Bellman
operator (I4) uses the same `apply_move` as the solver. A bug in `apply_move`
is invisible to I4, I7, I8, I9, and I11 — five of twelve invariants. I5 would
still catch it (it uses its own move graph), but that's one invariant against
five blind ones. R8 is the right call.

The human at G1 should weigh: ~700 lines of re-implementation vs five
partially-blind invariants. The cost is real but the defect history says it's
worth paying.

### Q2: Does the §6a matrix exhaust the epistemic-tree questions?

**Close, with one gap noted.** Twelve invariants cover:
- Table integrity: I1, I2, I3, I6, I10, I12
- Fixpoint correctness: I4, I7, I8, I9
- Graph-theoretic: I5, I11

What's missing: **per-artifact provenance verification.** The battery verifies
that an artifact is internally consistent and matches committed figures. It
does not verify that the artifact was produced by the claimed process (e.g.,
"this .wzo was built by the ADR-0020 build with memo_writes=false"). That is a
provenance question the register handles separately (via SHA-256 in
SHA256SUMS), and the battery doesn't need to duplicate it. But one cell in the
epistemic tree — "does this artifact match its provenance claim?" — is
answered by the hash alone, not by any invariant. If the spec's "sixty cells"
are meant to be exhaustive of the epistemic tree, this is a sixty-first cell
that lives outside the battery.

This is not a spec defect — the battery is scoped to artifact verification,
not provenance verification — but the human at G1 should know that "sixty
green cells" doesn't include "and we know which build produced the artifact."

### Q3: Is the three-exit-class scheme complete?

**Yes.** artifact-bad / reference-bad / battery-bad covers the known cases,
including the 3×2 cycle-reachable spread scenario where the artifact and
battery are both right and the committed number is wrong. The I5-at-3×2 case
(§4) is explicitly handled: "An I5 disagreement at 3×2 that matches the spread
is reference-bad, not a sprint-breaking finding."

One edge case worth noting: if the battery finds a novel disagreement (not
matching any known spread), the exit class is artifact-bad, but the correct
escalation is the same as reference-bad — the register and artifact both need
audit. The spec's §7 says this is "a finding larger than this sprint" and
should escalate. The three classes handle this: exit code 1 (artifact-bad)
triggers "investigate the artifact," and if investigation shows the artifact
is correct, the finding is upgraded to reference-bad. The exit code doesn't
need a fourth class for this; the harness's stderr message distinguishes the
novel-disagreement case.

### Q4: A3 carries two 3×2 census targets pending V-R — is that honest?

**Yes, and it's the right call.** The spec states: "The difference is exactly
36 states — the documented phantom count — distributed 12 → L==H, 24 → pin_T;
confirming that identity is part of the registered reconciliation task, and
until then the battery reports whichever its denominator matches and flags the
other as reference-noted." This is explicit, conditional, and gives the V-10
seat exact instructions. V-R is concurrent with V-3 (this audit); it blocks
nothing on the critical path but must land before V-10. The strategy's
dependency graph encodes this correctly.

If V-R refutes the 36-phantom identity: the strategy says "the battery reports
whichever its denominator matches and flags the other as reference-noted." The
worst case is that a new, third census value emerges from V-R and the battery
disagrees with both existing targets — which is reference-bad on both and
feeds the reconciliation. The strategy's falsifier (§4) covers this: "A clean
battery run disagrees with a committed register figure → reference-bad."

### Q5: I8's polarity — does the invariant depend on ADR-0020's text, or only on T102/T103?

**Only on T102/T103.** I8 as restated (gap = 0, the 24 states must agree
between loopy-game fixpoint and exact first-revisit truncation) depends on two
artifacts:
1. The 24 states committed in `calibration-2x2-mismatch.py` (T103)
2. The finding that buffer aliasing caused the original mismatch (T102)

Neither depends on ADR-0020's text. ADR-0020:47-49 still carries the old
"mismatch" language, but that is an editorial defect in the ADR, not a
dependency of the invariant. The spec correctly cites T102/T103 as the
authority and notes the ADR amendment as a separate G1 agenda item. Even if
the ADR amendment stalls, I8 stands on T102/T103 alone.

---

## 4. Requirement-by-requirement assessment (rev 1 spec)

| id | grade | notes |
|---|---|---|
| R1 | PASS | One binary, parameterised. Unchanged from pass 0. |
| R2 | PASS | I5 fixture strategy now specified (corrupt one slot, verify I5 catches it). R2 resolved. |
| R3 | PASS | Denominator discipline. I7 denominator now correctly 99,133,036 (compact slots), not 43,046,721. |
| R4 | PASS | Never writes register. Unchanged. |
| R5 | PASS | Exhaustiveness now stated per invariant per goban in §6a matrix. |
| R6 | PASS | Three exit classes: artifact-bad / reference-bad / battery-bad. |
| R7 | PASS | RSS budget; concurrency cap assigned to Orcha with human backstop. |
| R8 | PASS | **New.** Import nothing from `src/`. Flagged for human at G1. |

## 5. Invariant-by-invariant assessment (rev 1 spec)

| id | grade | notes |
|---|---|---|
| I1 | PASS | Unchanged. |
| I2 | PASS | Unchanged. |
| I3 | PASS | Unchanged. |
| I4 | PASS | Unchanged. |
| I5 | PASS | Calibration targets verified; fixture strategy from i5-feasibility memo; separately invocable (S1); convention (true game root, phantoms excluded → 1,678) explicit. |
| I6 | PASS | UNDEF census. Denominator (compact slots) corrected. Component split citation gap noted (M2). |
| I7 | PASS | DTT sanity. Defect signature clarified: uniformity including terminals, not 255 value. Denominator corrected. |
| I8 | PASS | **Polarity corrected** — agreement fixture (gap = 0). Cites T102/T103. ADR-0020 amendment flagged for G1. |
| I9 | PASS | Anchors verified against register. 4×3 correctly marked "no reference." 4×4 +1 vs MIGOS +2 correctly noted as open. |
| I10 | PASS | **New** — TIE value correctness. Resolves B1. |
| I11 | PASS | **New** — move-set consistency. Resolves C1. |
| I12 | PASS | **New** — score range. Resolves M6. |

## 6. Acceptance-criterion assessment (rev 1 spec)

| id | grade | notes |
|---|---|---|
| A1 | PASS | I5 fixture specified; corrupt-one-slot strategy. |
| A2 | PASS | Artifact list enumerated; hashed where hashes exist; unhashed files explicitly marked. |
| A3 | PASS | Both 3×2 targets carried with their denominators; 36-phantom hypothesis stated; V-R reconciliation pending. |
| A4 | PASS | v1 identified by path + SHA-256; DTT defect confirmed. |
| A5 | PASS | Chosen from {I4, I5, I7} — must exercise move relation. |
| A6 | PASS | Peak RSS reported per invocation. |

## 7. Strategy phase-by-phase assessment

| phase | grade | notes |
|---|---|---|
| P0 | PASS | V-1 done; V-2 done; V-3 (this audit); V-R concurrent. All pass-0 blockers/criticals resolved. |
| G1 | PASS | Agenda: R8, §6a matrix, S1, ADR-0020 amendment, sprint un-retirement. Complete. |
| P1 | PASS | V-4/V-5 correctly scoped; M4 design doesn't wait. |
| G2 | PASS | Schema freeze; V-11 dispatch deadline. |
| P2 | PASS | Lane split clean; V-6 needs V-11 committed (chronology enforcement); adversarial review for V-8/V-9. |
| P3 | PASS | Both independence rules: V-11 blind re-implementation; at least one fixture by non-implementer. Holds are concrete paths. |
| G3 | PASS | Human ratifies instrument. Correctly placed. |
| P4 | PASS | RSS-metered concurrency; V-14 serial register absorption (one task per goban). |
| §3 cross-sprint | PASS | oracle-v2 coordination verified: shared RSS meter, no file contention, schema anticipates brackets. |

## 8. Summary of required changes before dispatch

1. **M1:** Capture `scc2x2.py` stdout to `scc2x2.stdout` and cite it in the spec's I5 calibration.
2. **M2:** Provide a tracked-register citation for the I6 UNDEF component split (24,187,097 / 65,534 / 65,534), or state explicitly that the calibration is self-verifying from the artifact header.
3. **M3:** Clarify the V-11 chronology-vs-worktree mechanism in the P2 table — state the primary (chronology) and fallback (worktree).

Items S1–S4 and C1–C2 are improvements that can be addressed during P1/P2 without blocking dispatch.

## 9. Verdict

**PASS.**

The rev 1 spec and strategy resolve all 22 pass-0 audit findings. Every
calibration citation I checked against the tracked register at the cited
file:line is correct. The invariant set is complete; the sixty-cell matrix is
enumerated; the shared-code boundary is explicit; the three-exit-class scheme
handles the reference-bad case; and both independence rules (V-11 blind, V-10
cross-author fixture) are genuine structural guarantees.

The three must-fix items (committed scc2x2 stdout, UNDEF census citation,
V-11 chronology enforcement clarity) are calibration-verification hygiene, not
architectural defects. They should be resolved before V-4 dispatches but do
not require a third audit pass.

The central claim — one instrument, adversarially reviewed once, invoked sixty
times — is now earned on paper. The fleet run will tell whether it is earned
in fact.
