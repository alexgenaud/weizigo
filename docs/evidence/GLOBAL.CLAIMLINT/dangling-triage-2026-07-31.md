# Dangling-triage: C2 evidence paths and C1a orphans

**Task:** T128 · **Role:** DSFlash · **Date:** 2026-07-31
**Classification basis:** T119 recoverability audit, T110 T13 re-implementation,
CLAIMS.md §4.1 orphan analysis, docs/evidence/README.md CONFIRMED LOST table.

---

## C2 — 8 unique missing evidence paths

### 1. `untracked/T13-minimax.md`

| field | value |
|---|---|
| **Classification** | **RECOVERED** |
| **What was lost** | Raw stdout of the T13 C2-pilot-3×2 probe (enumerated 12 contradictions, ban-set distribution, 153,613 game lines) |
| **Path to recovered content** | `docs/evidence/T13/` |
| **How** | T110 (2026-07-30) independently re-implemented the probe in Python (`t13_probe.py`, `probe-v2-2026-07-30.py`) and Zig (`zig_t13_replay.zig`, `zig_dump_3x2.zig`). All 12 recorded contradiction lines re-execute exactly; 5,868/5,868 cell values match between Python and Zig. The durable summary was never lost (survives at `docs/research/c2-falsification-3x2.md`). |
| **Recommended disposition** | Re-point citing rows from `untracked/T13-minimax.md` to `docs/evidence/T13/` and `docs/research/c2-falsification-3x2.md`. Update the `3x2.T13` evidence column in CLAIMS.md:272 to remove the "CANNOT REPRODUCE" warning — that note is now stale. |
| **Citing rows** | `2x2.B1`, `3x2.B1`, `3x3.B1`, `GLOBAL.B1-MULTIFIX` (via `leak-crisis.md`); `3x2.T13` (via `docs/research/c2-falsification-3x2.md`) |

### 2. `untracked/c2pilot_3x2.zig` (T13 probe source)

| field | value |
|---|---|
| **Classification** | **RECOVERED** |
| **What was lost** | The standalone Zig driver that called `retro.ab_solve` with the 2,000,000-node line budget and enumerated the 12 contradiction histories |
| **Path to recovered content** | `docs/evidence/T13/t13_probe.py`, `docs/evidence/T13/zig_t13_replay.zig`, `docs/evidence/T13/probe-v2-2026-07-30.py` |
| **How** | T110 (2026-07-30). The committed engine (`src/retro.zig`) was never lost — only the driver was. The re-implementations are strict supersets of the original: they dump and verify every contradiction line, cross-validate against the committed Zig tables, and the Python port is a completely independent implementation. |
| **Recommended disposition** | Re-point citing rows in `docs/research/c2-falsification-3x2.md` from `untracked/c2pilot_3x2.zig` to `docs/evidence/T13/`. Update the `3x2.T13` evidence column in CLAIMS.md to point at the committed reproduction. |
| **Citing rows** | `2x2.B1`, `3x2.B1`, `3x3.B1`, `GLOBAL.B1-MULTIFIX` (via `c2-falsification-3x2.md`); `3x2.T13` |

### 3. `untracked/T02-minimax.md` (B1 least-fixpoint results)

| field | value |
|---|---|
| **Classification** | **RECOVERABLE** |
| **What was lost** | Numerical results of the B1 least-fixpoint probe (violation counts at 2×2/3×2/3×3) |
| **What survives** | Method survives at `docs/evidence/b1-least-fixpoint/b1-spec.md` (the RETRO_B1_LOFIX specification, V0+V1 Bellman checks, the T02.1 `oppV0[child]` correction). Numbers survive only in `leak-crisis.md:86-101` prose. The committed `src/retro.zig` contains the probe machinery. |
| **Recovery cost** | **Moderate.** A driver that runs `RETRO_B1_LOFIX` at 2×2/3×2/3×3 with `memo_writes=false`. The numbers in `leak-crisis.md` (zero violations at all three sizes) are the verification target. Estimated < 1 hour of wall time. |
| **Recommended disposition** | Mark as RECOVERABLE with a clear path. Do not re-point citing rows yet — the raw output is still missing. A follow-up task (analogous to T110) should regenerate and commit the output under `docs/evidence/B1/`. |
| **Citing rows** | `2x2.B1`, `3x2.B1`, `3x3.B1` (24 rows reachable via the B1 chain) |

### 4. `untracked/T02-audit-kimi.md` (Kimi audit convicting the (a′) variation)

| field | value |
|---|---|
| **Classification** | **LOST** |
| **What was lost** | The Kimi audit document: the reasoning chain that convicted the (a′) variation (re-converge-from-`+N` check) as unsound. This was pure text — human reasoning, not code output. |
| **What survives** | Two-line paraphrase at `leak-crisis.md:99-101` + CLAIMS.md:132 (`GLOBAL.B1-AUDIT` row: "PROVEN" — the decision survives, the argument for it does not). |
| **Impact assessment** | The decision (remove the re-converge check from `4x4.FP1` acceptance) is the load-bearing output, and it is recorded. The reasoning chain that led to it would be relevant if someone later challenges the decision. |
| **Recommended disposition** | Accept as LOST. Do not re-point citing rows. The decision is documented; the audit's reasoning is gone. The cite is honest about what survives. The lint should continue to flag this path — the flag is not noise. |

### 5. `untracked/T07-audit-hypotheses.md` (~42 KB, eight findings)

| field | value |
|---|---|
| **Classification** | **LOST** |
| **What was lost** | ~42 KB document with the eight audit findings that rewrote the 4×4 epistemic tree. The findings themselves (which hypotheses were tested, rejected, and why) are gone. |
| **What survives** | The product: `docs/epistemic/boards/4x4/EPISTEMIC.md` *is* the rewritten tree. The eight [`T07-N`] tags are structural markers, not findings — each encodes that a decision was made, not the reasoning behind it. |
| **Impact assessment** | The rewritten tree is the output. The intermediate state (which hypotheses were rejected) is useful for future epistemic retrospective but not load-bearing for any current claim. |
| **Recommended disposition** | Accept as LOST. The lint flag is information, not noise. Consider adding a note in EPISTEMIC.md or the referencing rows that the eight findings are themselves lost. |

### 6. `untracked/B05-glm.md` (the reframe scope)

| field | value |
|---|---|
| **Classification** | **LOST** (DUURABLE SUMMARY EXISTS) |
| **What was lost** | The full argument for the reframe scope boundaries — the GLM discussion that settled what the honest deliverable should be. |
| **What survives** | CLAIMS.md:258 (`GLOBAL.REFRAME` row: "CLAIMED (adopted decision)" with full evidence chain); `leak-crisis.md:146` (the one-sentence reframe statement); PROGRESS.md:135-146,235-241; AGENTS.md:59-62. The reframe decision is documented end-to-end — the adopted claim, its justification, the negation edges that motivate it. |
| **Impact assessment** | The *decision* is fully documented and load-bearing. The discussion that shaped it is gone but not necessary for the decision's validity. |
| **Recommended disposition** | Accept as LOST-with-summary. Do not re-point citing rows — the citing rows already reference the decision properly. The lint flag is optional to silence if the decision is deemed durable enough. |

### 7. `untracked/B39-arena4x4.md` (B39 arena run)

| field | value |
|---|---|
| **Classification** | **RETRACTED — durable summary exists** |
| **What was lost** | The original B39 arena measurement: 45.3% leak rate, max 144 pts on the unguarded 4×4 parallel artifact. |
| **What survives** | The B39 finding is **retracted** — the 45.3% was a sentinel-poisoning artifact. The retraction and the corrected re-measurement (B43: 3.4% clean, max 32 pts) are fully documented at `docs/research/arena-4x4-undef.md:4-56,57-91`. The `4x4.B39` register row (CLAIMS.md:473) is marked FALSE-AS-SCOPED. |
| **Impact assessment** | B39 has no remaining load-bearing role. The claim it supported (`4x4.B39`, the 45.3% number) is FALSE-AS-SCOPED and superseded by `4x4.B43`. The B39 row itself is a historical record. |
| **Recommended disposition** | Accept as RETRACTED. The citing rows in `arena-4x4-undef.md` already record the deletion and retraction. The lint flag is informational — the missing file is the original measurement, and the finding it contained is both documented and retracted. Re-point the evidence column of `4x4.B39` to `arena-4x4-undef.md` and drop the `untracked/B39-arena4x4.md` cite. |

### 8. `/tmp/test_census_pure.zig` (EXP-3 calibration throwaway)

| field | value |
|---|---|
| **Classification** | **LOST** (function discharged) |
| **What was lost** | An independent sanity-check BFS throwaway that confirmed the EXP-3 dispatch's calibration was overstated — the no-ko reachable count is smaller than the total addressable space. |
| **What survives** | The calibration discrepancy is fully documented at `docs/research/kostate-census-2026-07-28.md` (Calibration 2, lines marked "My measurement does NOT match this expectation"). The function this throwaway served (confirming the calibration hypothesis was wrong) is now served by the three-calibrated-detector suite committed at `docs/evidence/GLOBAL.H1-CENSUS/`. |
| **Impact assessment** | The throwaway was a cross-check that confirmed the census tool was not buggy. The committed calibration suite — known-good (OEIS A094777), two known-broken detectors (every_capture, every_move), and none-detector baseline — now serves that function more thoroughly. |
| **Recommended disposition** | Accept as LOST. The citing document (`kostate-census-2026-07-28.md`) should remove the citation to `/tmp/test_census_pure.zig` since the throwaway is gone and its function is discharged. Replace with a pointer to the committed calibration suite. |

---

## C1a — 10 orphaned claims

All 10 orphans trace to **one of three root FALSE-AS-SCOPED claims**. The
CLAIMS-SPLIT-CONJUNCTS task (which split conjoined rows with a live half and a
dead half) correctly reduced the set from 14 to 10 — these 10 are the residue:
claims that are genuinely parentless, with no "live half" to split off.

### Root summary

| root | status | how many orphans trace here |
|---|---|---|
| `GLOBAL.C3` | FALSE-AS-SCOPED (3×3) | **9** (all except `4x3.C1`) |
| `GLOBAL.F1` | FALSE-AS-SCOPED (3×2) | **1** (`4x3.C1`) |
| `4x4.COMPLETE-2026-07-21` | FALSE-AS-SCOPED | **1** (`GLOBAL.ADR0012-GATE`) |

Note: `GLOBAL.F1` itself orphans `4x3.C1` directly; `4x4.COMPLETE-2026-07-21`
itself orphans `GLOBAL.ADR0012-GATE` directly.

### Claim-by-claim

#### Orphan 1: `3x3.C1` (CLAIMED) — fresh-start scores correct at 3×3

| field | value |
|---|---|
| **Orphan chain** | `3x3.C1` ⟵d `GLOBAL.F2` [CLAIMED] ⟵d `GLOBAL.C3` [FALSE-AS-SCOPED] |
| **Shape** | **Two-step orphan.** `GLOBAL.F2` is itself orphaned (O1 from §4.1). The intermediate is ALIVE (CLAIMED) but its only `d:` parent is FALSE-AS-SCOPED. |
| **Root goban match** | `GLOBAL.C3` was falsified at 3×3. `3x3.C1` is the **same goban**. This is the sharpest orphan in the register. |
| **Comparable to pre-split?** | Yes — this is the canonical orphan-of-C3 type. It was NOT a conjoined claim; splitting was not applicable. The live half (the measurement data at other gobans) is a separate row (`4x3.C1`, `4x4.C1`). This row's only contents are the dependency on a FALSE-AS-SCOPED claim. |
| **Recommended disposition** | CLAIMED-and-orphaned is the honest current status. F2's orphan status is acknowledged and confirmed by ADR-0015/0017/0018. No change to evidence column. |

#### Orphan 2: `4x3.C1` (CLAIMED) — fresh-start scores correct at 4×3

| field | value |
|---|---|
| **Orphan chain** | `4x3.C1` ⟵d `GLOBAL.F1` [FALSE-AS-SCOPED] |
| **Shape** | **Direct orphan.** The 4×3 artifact was produced by the same unsound writes-on (`ko_ref ≥ d`) finisher as the committed 4×4 artifact. The `4x3.C1` row in CLAIMS.md:261 already states this edge explicitly ("the same buggy finisher path"). |
| **Root goban match** | `GLOBAL.F1` was falsified at 3×2. `4x3.C1` is a **different goban** — per-goban epistemic independence applies. The F1 falsification at 3×2 does not prove F1 false at 4×3; it means the *same code* was buggy at the one size it was tested at. |
| **Comparable to pre-split?** | Yes — this is a pure dependency orphan. No conjoined halves to split. The anchor support (`4x3.ANCHOR`, +4 in-bracket) is `evidenced-by` not `derives-from` and survives as weak support only. |
| **Recommended disposition** | CLAIMED-and-orphaned. The register already records this correctly. |

#### Orphan 3: `GLOBAL.F2` (CLAIMED) — bracket-guided finisher is sound

| field | value |
|---|---|
| **Orphan chain** | `GLOBAL.F2` ⟵d `GLOBAL.C3` [FALSE-AS-SCOPED] |
| **Shape** | **Direct orphan.** This is O1 from §4.1 — the deepest orphan in the register and the one the project has acknowledged most thoroughly. ADR-0015 (D-5, 2026-07-28) confirmed the orphan is real; ADR-0017 (EXP-10, 2026-07-29) failed to refute it; ADR-0018 (human ruling, 2026-07-29) confirmed it. |
| **Goban** | GLOBAL (all gobans). The finisher uses the same logic at every size. |
| **Comparable to pre-split?** | Yes — pure dependency orphan. This was never a conjoined claim. The justification depended on C3; C3 fell; F2 remains CLAIMED because the finisher has not been proven *incorrect*, only its *justification* has been refuted. |
| **Recommended disposition** | CLAIMED-and-orphaned is correct. Track A (`memo_writes=false`) partially mitigates the practical concern — `3x2.F3` (0/378 auditor violations) shows the writes-off path is self-consistent at 3×2 — but the bracket-derived seed inheritance (CERTCORE) still depends on C3. The `F2-REMEDY` design (median build) is the cure path. |

#### Orphan 4: `GLOBAL.ADR0010-CUT` (CLAIMED) — bracket cutoffs valid under any ban set

| field | value |
|---|---|
| **Orphan chain** | `GLOBAL.ADR0010-CUT` ⟵d `GLOBAL.C3` [FALSE-AS-SCOPED] |
| **Shape** | **Direct orphan.** The bracket-cutoff premise is a sub-claim of C3: "bracket cutoffs are valid under any ban set (the bracket is)". When C3 fell, this claim implicitly fell too. ADR-0015 (2026-07-28) supersedes the justification: only one kind of cutoff (the score cutoff) needs the premise; bracket move ordering and the aspiration window survive as heuristics. |
| **Goban** | GLOBAL (all gobans). |
| **Comparable to pre-split?** | Yes — pure dependency orphan, never conjoined. The ADR-0015 ruling carved out the heuristic carve-out explicitly. |
| **Recommended disposition** | CLAIMED-and-orphaned. The ADR-0015 carve-out is already recorded in CLAIMS.md:213. The score-cutoff premise is the remaining orphan; the heuristic parts survive. |

#### Orphan 5: `GLOBAL.F3` (CLAIMED) — writes-off finisher is sound

| field | value |
|---|---|
| **Orphan chain** | `GLOBAL.F3` ⟵d `GLOBAL.C3` [FALSE-AS-SCOPED], ⟵d `GLOBAL.ADR0006-EYE` [CLAIMED], ⟵d `GLOBAL.CERTCORE` [FALSE-AS-SCOPED] |
| **Shape** | **Direct orphan** via `GLOBAL.C3`. F3 rests on three invariants: bracket validity (C3, FALSE-AS-SCOPED), eye-prune soundness (CLAIMED), and history-free certified seeds (CERTCORE, FALSE-AS-SCOPED). Two of three invariants are dead. |
| **Goban** | GLOBAL (all gobans). |
| **Comparable to pre-split?** | Yes — this is an orphan-of-C3 that was never conjoined. The `3x2.F3` measurement (0/378 auditor violations) is `evidenced-by` and survives as weak support (self-consistency, not soundness). |
| **Recommended disposition** | CLAIMED-and-orphaned. The `F2-REMEDY` design (median build) supersedes the bracket-dependent finisher logic. Until that build is done, F3 remains the best available finisher but its justification is refuted. |

#### Orphan 6: `GLOBAL.F4` (PROVEN (argument) + MEASUREMENT) — KM dependency-guarded memo

| field | value |
|---|---|
| **Orphan chain** | `GLOBAL.F4` ⟵d `GLOBAL.F3` [CLAIMED] ⟵d `GLOBAL.C3` [FALSE-AS-SCOPED] |
| **Shape** | **Two-step orphan** through F3. The KM dependency-guarded memo is PROVEN as an *argument* (the bit-disjointness proof is mathematical, not empirical) and by MEASUREMENT (0 auditor violations at 3×2/3×3/4×3). But it `derives-from` F3: "if the writes-off finisher is sound, the KM memo layer on top of it is also sound." |
| **Goban** | GLOBAL (all gobans). |
| **Comparable to pre-split?** | Yes. The PROVEN status for the argument and measurement is correct — those are sound *in their own right*. The `d:` edge makes it an orphan, but unlike the CLAIMED orphans, the PROVEN parts would survive if F3 were rehabilitated. |
| **Recommended disposition** | Keep as-is. The orphan status is structural (the `d:` edge); the PROVEN argument and measurements stand on their own. Do not downgrade to CLAIMED — the KM design is mathematically correct regardless of F3's status. The orphan flag is correct but not actionable. |

#### Orphan 7: `GLOBAL.H5c` (PROVEN (as an implication)) — bracket-cut search tractable but unsound

| field | value |
|---|---|
| **Orphan chain** | `GLOBAL.H5c` ⟵d `GLOBAL.C3` [FALSE-AS-SCOPED] |
| **Shape** | **Direct orphan.** This claim is PROVEN as an implication: "IF C3 were true (bracket bounds the real-game score), THEN bracket-cut search at play time would be tractable and sound." The PROVEN status correctly captures that the implication is true; the orphan status correctly captures that the premise is false. |
| **Goban** | 4×4 (scoped to 4×4 per the evidence). |
| **Comparable to pre-split?** | Yes — this is a conditional-implication orphan, never conjoined. The `PROVEN (as an implication)` status is the first correct use of that qualification in the register. |
| **Recommended disposition** | Keep as-is. The status is correct and the orphan is expected. This is what §4.1 O2 describes: "PROVEN in the sense that it says something true about the premise it was given." The text in the evidence column ("but NOT shippable as sound — cutting on `[L,H]` under a real history *is* claim C3") already states the orphan condition explicitly. |

#### Orphan 8: `GLOBAL.ADR0012-GATE` (CLAIMED) — reproduce sha256 artifacts end-to-end

| field | value |
|---|---|
| **Orphan chain** | `GLOBAL.ADR0012-GATE` ⟵d `4x4.COMPLETE-2026-07-21` [FALSE-AS-SCOPED] |
| **Shape** | **Direct orphan** from a retracted claim. The gate says: "any engine change must first reproduce the recorded sha256 artifacts end-to-end on 3×3/4×4/6×3." This references `4x4.COMPLETE-2026-07-21`, which claimed `data/oracle-4x4.wzo` was "the complete, validated 4×4 oracle." That claim was retracted when the F1 bug was confirmed — the committed artifact was writes-on (buggy), not writes-off. |
| **Goban** | 3×3/4×4/6×3. |
| **Comparable to pre-split?** | Yes — pure dependency orphan. The gate depends on the existence and validity of a reference artifact, which no longer exists. |
| **Recommended disposition** | This orphan is actionable: the gate needs to be **re-pointed** to the eventual writes-off artifact once Track A completes. Until then, CLAIMED-and-orphaned is correct. The ADR-0012 text should be updated to reference a placeholder or the future writes-off artifact rather than the retracted one. |

#### Orphan 9: `GLOBAL.B15` (CLAIMED) — Track A 2×2/3×2 regen byte-identical

| field | value |
|---|---|
| **Orphan chain** | `GLOBAL.B15` ⟵d `GLOBAL.F3` [CLAIMED] ⟵d `GLOBAL.C3` [FALSE-AS-SCOPED] |
| **Shape** | **Two-step orphan** through F3. The Track A regen at 2×2/3×2 was completed and verified byte-identical. But the claim "Track A regen is complete" depends on F3 (writes-off finisher soundness) because the regen used the writes-off path. |
| **Goban** | 2×2/3×2. |
| **Comparable to pre-split?** | Yes — this is a claim about a completed action (regen), not about correctness. The action was indeed completed. The orphan is structural: the F3-dependent registration means the *verification* chain is broken, even though the measurements were taken. |
| **Recommended disposition** | CLAIMED-and-orphaned is correct. The regen was done; the output is reproducible; the dependency is on F3's soundness as a registration decision. If an `evidenced-by` edge to the regen output files existed alongside the `d:` edge, the orphan would be less problematic. Consider adding an `e:` edge to the regen artifact or process document to decouple the action from the soundness premise. |

#### Orphan 10: `QA-018` (CLAIMED) — bracket-guided finisher is sound (alias of `GLOBAL.F2`)

| field | value |
|---|---|
| **Orphan chain** | `QA-018` ⟵d `GLOBAL.F2` [CLAIMED] ⟵d `GLOBAL.C3` [FALSE-AS-SCOPED] |
| **Shape** | **Two-step orphan** through F2. This is a **deliberate alias**: CLAIMS.md:910 "Alias of GLOBAL.F2." The `d:` edge goes to F2, not C3, so the orphan is tracked through F2. |
| **Goban** | all. |
| **Comparable to pre-split?** | Yes — as an alias, this row exists only to be a place for the Q&A register to point at. The orphan is the same orphan as `GLOBAL.F2`. |
| **Recommended disposition** | Keep as-is. The alias structure is correct. When F2's orphan is resolved (via `F2-REMEDY`), QA-018 resolves automatically. |

---

## Summary

### C2 paths

| path | classification | recommended action |
|---|---|---|
| `untracked/T13-minimax.md` | **RECOVERED** | Re-point to `docs/evidence/T13/` |
| `untracked/c2pilot_3x2.zig` | **RECOVERED** | Re-point to `docs/evidence/T13/` |
| `untracked/T02-minimax.md` | **RECOVERABLE** | Regenerate and commit; follow-up task needed |
| `untracked/T02-audit-kimi.md` | **LOST** | Accept; lint flag is information |
| `untracked/T07-audit-hypotheses.md` | **LOST** | Accept; lint flag is information |
| `untracked/B05-glm.md` | **LOST** (durable summary exists) | Accept; decision is documented |
| `untracked/B39-arena4x4.md` | **RETRACTED** | Re-point to `arena-4x4-undef.md` |
| `/tmp/test_census_pure.zig` | **LOST** (function discharged) | Remove cite; calibration suite replaces it |

### C1a orphans

| orphan | root | shape | disposition |
|---|---|---|---|
| `3x3.C1` | `GLOBAL.C3` | two-step via F2 | correct as-is |
| `4x3.C1` | `GLOBAL.F1` | direct | correct as-is |
| `GLOBAL.F2` | `GLOBAL.C3` | direct | correct as-is; ADR-0015/0017/0018 confirmed |
| `GLOBAL.ADR0010-CUT` | `GLOBAL.C3` | direct | ADR-0015 carve-out applies |
| `GLOBAL.F3` | `GLOBAL.C3` | direct | correct as-is; F2-REMEDY is cure path |
| `GLOBAL.F4` | `GLOBAL.C3` | two-step via F3 | PROVEN argument stands; orphan structural |
| `GLOBAL.H5c` | `GLOBAL.C3` | direct | PROVEN-as-implication; correct as-is |
| `GLOBAL.ADR0012-GATE` | `4x4.COMPLETE-2026-07-21` | direct | needs re-pointing to writes-off artifact |
| `GLOBAL.B15` | `GLOBAL.C3` | two-step via F3 | add `e:` edge to decouple action from premise |
| `QA-018` | `GLOBAL.C3` | two-step via F2 | alias of F2; resolves with F2 |

**All 10 orphans are structurally sound — none is a mis-classification or a
splitting error.** The CLAIMS-SPLIT-CONJUNCTS task correctly discharged 4 of
the original 14 by separating the live halves. These 10 are the legacy debt of
the C3/F1/FALSE-AS-SCOPED retractions.

The two orphans that are actionable without resolving C3:

- `GLOBAL.ADR0012-GATE` — re-point from the retracted `4x4.COMPLETE-2026-07-21` to the eventual writes-off artifact reference.
- `GLOBAL.B15` — add an `evidenced-by` edge to decouple the measurement from the soundness premise.

*Identifier: DSFlash/T128. No engine files modified.*
