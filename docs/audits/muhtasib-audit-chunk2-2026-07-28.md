# Muhtasib audit — Chunk 2: claim-graph audit

**Auditor:** Kimi-k2.7 Auditor (Muhtasib role).  
**Date:** 2026-07-28  
**Scope:** trace the current epistemic claims in `docs/epistemic/PROGRESS.md`, `docs/status/leak-crisis.md`, `docs/decisions/0013-sound-finisher-and-dependency-guarded-memo.md`, and the QA-023 Part A package (`proof-v2`, `audit-opus`, `qa023-basicko-markovian`) against their evidence. Look for status-overreach, definition-shifts, and fresh-start/real-game conflation.

## Method

Read the documents directly, not via summaries. Compare each strong claim against the evidence cited for it. Mark each audited claim VERIFIED / NEEDS REPAIR / BLOCKED / FALSE-AS-STATED.

## Audited claims and verdicts

### 1. C1: "Fresh-start scores correct as fresh-start scores at 2×2, 3×2" — status PROVEN

**Source:** `docs/status/leak-crisis.md` (top table).  
**Verdict: VERIFIED as stated.** The document does not claim 2×2/3×2 real-game correctness; it explicitly restricts the claim to "vs history-aware exact solver." No overreach found.

### 2. C2: "Single-score (L==H) positions are history-independent" — status FALSE-AS-SCOPED at 3×2

**Source:** `docs/status/leak-crisis.md`; evidence T13.  
**Verdict: VERIFIED as FALSE-AS-SCOPED.** The wording is careful: it is not "false everywhere" but "falsified at 3×2," and the honest deliverable is explicitly reframed as fresh-start-only. No overreach.

### 3. C3: "The range `[L,H]` bounds the real-game score" — status CLAIMED, falsified at 3×3

**Source:** `docs/status/leak-crisis.md`; evidence E2.  
**Verdict: VERIFIED as CLAIMED/FALSE-AS-SCOPED.** The document records the 3×3 leak (25/4000 games, promise +3 → final −9) and explains why (a) cycle-pessimism vs PSK move-removal survives. It does not promote C3 to PROVEN.

### 4. C4: "Fresh-start score == real-game score" — status FALSE

**Source:** `docs/status/leak-crisis.md`.  
**Verdict: VERIFIED as FALSE.** The document gives the correct structural reason for both regions (ko-sensitive by the leak; single-score because C2 is falsified at 3×2). No overreach.

### 5. "The only proven claim about the table's content is C1"

**Source:** `docs/status/leak-crisis.md`, end of "Resolution of the (a)/(b) axis."  
**Verdict: VERIFIED as an honest framing.** The sentence correctly excludes C2/C3/C4 from PROVEN status.

### 6. ADR-0013: "Committed ko-sensitive scores (`data/oracle-4x4.wzo`, 2×2/3×2/3×3) are NOT trustworthy until Track A regenerates them"

**Source:** `docs/decisions/0013-sound-finisher-and-dependency-guarded-memo.md`, Consequences section.  
**Verdict: NEEDS REPAIR — stale scope.** The ADR says the "certified `L==H` core is unaffected and remains correct." This is consistent with the ADR's own scope (fresh-start correctness), but it is **now known** from T13 (2026-07-26) that the `L==H` region is not history-independent. The ADR was written 2026-07-23, before T13. The ADR does not claim the `L==H` core is real-game correct, but it uses the word "correct" without the fresh-start qualifier in several places. In the current project state, a reader may still read "correct" as "real-game correct."

**Required repair:** add an explicit fresh-start/real-game qualifier to the Consequences section and anywhere else the ADR says "correct." The `L==H` core is fresh-start correct (C1), not real-game correct (C2 falsified).

### 7. ADR-0013: "The history-perfect genmove (GTP player) shares this machinery; it inherits the fix automatically once the finisher config is corrected"

**Source:** `docs/decisions/0013-sound-finisher-and-dependency-guarded-memo.md`, final line.  
**Verdict: FALSE-AS-STATED in the current codebase.** `docs/research/ko-sensitive-chainability.md`, `docs/status/HANDOVER.md`, and `docs/research/corrections-2026-07-27.md` all record that `Session.choose` in `src/gtp.zig` does **table lookups only** and never searches/finisher machinery. This ADR line is false and is listed as a known-unsound statement in the corrections doc.

**Required repair:** the ADR's final line should be struck or corrected. It has been superseded by the 2026-07-27 finding.

### 8. QA-023 Part A: status after proof-v2

**Sources:** `docs/evidence/QA-023/proof-v2-2026-07-28.md`, `docs/evidence/QA-023/audit-opus-2026-07-28.md`, `docs/research/qa023-basicko-markovian-2026-07-28.md`.

The documents are internally consistent. The proof-v2 text:
- Corrects v1's false rule (`L < H ⇒ V = T`) to `V = max(L, min(T, H)) = median(L, T, H)`.
- Proves determinacy and value from finite-graph first principles (no external theorem load-bearing), fixing the audit's F2 (existence-is-not-equality).
- Runs an adversarial review with independence condition and records the verbatim verdict: REPAIRABLE-GAPS.
- Records all six findings, repairs them in place, and states none changes a theorem.
- Explicitly labels QA-023 overall as **CLAIMED**, not PROVEN, pending EXP-2B.

**Verdict: VERIFIED as a well-scoped, honestly tagged CLAIMED package.** The proof is an argument; the project does not mark it PROVEN; the gate (EXP-2B) is named; the sub-claims QA-023.M1/M2 are flagged UNTESTED.

### 9. Whether QA-023 Part A has been silently promoted from REPAIRABLE-GAPS to PROVEN

**Checked in:** `docs/research/qa023-basicko-markovian-2026-07-28.md` §3, `docs/status/CURRENT.md`, `docs/evidence/QA-023/proof-v2-2026-07-28.md` §9 item 1.

**Verdict: VERIFIED — not silently promoted.** All three documents keep QA-023 at **CLAIMED** overall. `qa023-basicko-markovian` says "Part A repaired+reviewed" but immediately adds "Gate still requires EXP-2B." The CURRENT.md entry (read during planning) likewise says "QA-023 status: CLAIMED — Part A repaired+reviewed; gate still needs EXP-2B." No PROVEN upgrade.

### 10. "Chainability of the single-score region" — status PROVEN in PROGRESS.md

**Source:** `docs/epistemic/PROGRESS.md` ("Chainability (2026-07-27)" bullet).  
**Verdict: VERIFIED in scope.** The claim says zero violations outside the flag at 2×2/3×2/3×3/4×3 (exhaustive) and 4×4 (sample); and it carries the explicit caveat "the shipped `vb`/`vw` columns only, not the `lo`/`hi` bracket tables." This matches the chainability finding. The 4×4 exhaustive run (2026-07-28) supersedes the sample, but the documented claim is not false — it is conservative.

### 11. "The single-score (L==H) region satisfies the history-free Bellman identity with zero violations" — stronger wording in `docs/epistemic/GLOSSARY.md`

**Source:** `docs/epistemic/GLOSSARY.md` (term **chainable**).  
**Verdict: VERIFIED.** The GLOSSARY text explicitly says "at 4×4 that is 0 out-of-flag violations over all 48,599,962 non-settled (position, side) slots, for the shipped `vb`/`vw` columns (the `lo`/`hi` bracket-table form of the check is still untested)." It is honest about scope.

### 12. The "one mismatch, not five problems" interpretation in PROGRESS.md

**Source:** `docs/epistemic/PROGRESS.md`, section "One mismatch, not five problems (CLAIMED — an interpretation, not a theorem)."  
**Verdict: VERIFIED as a properly scoped interpretation.** The document itself labels it "CLAIMED" and "an interpretation, not a theorem." It does not overstate.

### 13. The 4×4 "central partition" wording in PROGRESS.md

**Source:** `docs/epistemic/PROGRESS.md`, "The central partition."  
**Verdict: NEEDS REPAIR — one stale sentence.** The section says: "Where L==H the score was *claimed* history-independent (a single integer score)." This is correct post-T13. However, the next sentence says: "~66 / 74 / 79% of slots at 3×3 / 4×3 / 4×4." The percentages are fresh-start single-score fractions, not "history-independent" fractions. The wording "was *claimed* history-independent" repairs the conceptual status, but the percentages could be misread as "the share that is history-independent." A clearer phrasing would be: "~66 / 74 / 79% of slots at 3×3 / 4×3 / 4×4 are L==H; these are fresh-start exact, not history-independent (C2 falsified at 3×2)."

**Required repair:** one sentence in PROGRESS.md's central-partition section to prevent the percentage from being read as a history-independence claim.

### 14. "The 4×4 artifact and the GTP player are both still PSK" — status in PROGRESS.md

**Source:** `docs/epistemic/PROGRESS.md` ("The PSK gap").  
**Verdict: VERIFIED.** The claim is consistent with HANDOVER.md, CURRENT.md, and the chainability finding. No overreach.

### 15. The 5×5 anchor "known Black +25" in GLOSSARY.md / PROGRESS.md

**Source:** `docs/epistemic/GLOSSARY.md` ("Board-size facts"), `docs/epistemic/PROGRESS.md` ("What the project is").  
**Verdict: VERIFIED as stated, with caveats carried.** Both documents note that the 5×5 anchor is under a "simpler repetition rule" / "different ruleset" and that 5×5 is not yet reached here. No overreach.

## Summary table

| claim | location | verdict | note |
|---|---|---|---|
| C1 PROVEN at 2×2/3×2 | `leak-crisis.md` | VERIFIED | properly scoped |
| C2 FALSE-AS-SCOPED at 3×2 | `leak-crisis.md` | VERIFIED | properly scoped |
| C3 CLAIMED, falsified at 3×3 | `leak-crisis.md` | VERIFIED | properly scoped |
| C4 FALSE | `leak-crisis.md` | VERIFIED | properly scoped |
| `L==H` core "remains correct" | `ADR-0013.md` | NEEDS REPAIR | needs fresh-start qualifier |
| GTP player inherits finisher fix | `ADR-0013.md` | FALSE-AS-STATED | known-unsound; corrections doc lists it |
| QA-023 Part A status | proof-v2 / research doc | VERIFIED | stays CLAIMED, gate named |
| Chainability PROVEN | `PROGRESS.md`, `GLOSSARY.md` | VERIFIED | scope caveat carried |
| "One mismatch" interpretation | `PROGRESS.md` | VERIFIED | explicitly CLAIMED |
| Single-score percentages | `PROGRESS.md` central partition | NEEDS REPAIR | one sentence can misread as history-independence |
| PSK gap | `PROGRESS.md` | VERIFIED | consistent across docs |
| 5×5 +25 anchor | `GLOSSARY.md`, `PROGRESS.md` | VERIFIED | caveats carried |

## Blocked items

- The `lo`/`hi` bracket-table chainability check is **BLOCKED** by artifact format (WZO1 carries no bracket columns). This is acknowledged in the docs; no false claim found.
- QA-023 overall remains **BLOCKED** on EXP-2B. This is honestly stated in the docs; no false claim found.

## Overall chunk verdict

The claim graph is **mostly honest and well-scoped**, but two **NEEDS REPAIR** items were found in committed/accepted docs:

1. **`docs/decisions/0013-sound-finisher-and-dependency-guarded-memo.md`** — the final line claiming the GTP player inherits the finisher fix is **false** in the current codebase and is already listed in `docs/research/corrections-2026-07-27.md`. The ADR should be corrected or annotated.
2. **`docs/decisions/0013-sound-finisher-and-dependency-guarded-memo.md`** — the Consequences section says the `L==H` core "remains correct" without the fresh-start qualifier. T13 falsified history-independence at 3×2; the ADR should say "remains fresh-start correct" or similar.
3. **`docs/epistemic/PROGRESS.md`** — the central-partition single-score percentages are juxtaposed with "claimed history-independent" in a way that could be misread. One sentence should be tightened.

No FALSE-AS-STATED claims were found outside the already-known ADR-0013 GTP line. QA-023 Part A is **not** silently promoted; it remains CLAIMED with a named gate.
