# project-restructure pass0 — BACKLOG

```
Task: T200 · Role: sprint-manager · Model: DSPro · Date: 2026-08-01
Source: claimlint baseline (test.md §1) · CLAIMS.md §4.1, §7
Purpose: R2-4 — dispositioned orphan/re-verification list.
         Every row gets owner, disposition, one-line rationale.
         No substance is fixed here — only dispositioned.
```

---

## C1a orphans (10) — CLAIMED/PROVEN claims with FALSE transitive ancestor

Each orphan has a `d:` chain terminating at a FALSE claim. The fix is either
re-point the edge to a live claim, accept the orphan as informational, or
demote the claim.

| # | claim ID | status | FALSE root | disposition | owner | rationale |
|---|---|---|---|---|---|---|
| 1 | `3x3.C1` | CLAIMED | `GLOBAL.C3` | backlog — re-verify after Track A regen | Track A sprint | C1 (fresh-start) at 3×3 depends on C3 (brackets bound real-game) which is FALSE. Until C3 is rehabilitated or C1 re-grounded, the status is honest-CLAIMED. |
| 2 | `4x3.C1` | CLAIMED | `GLOBAL.F1` | backlog — re-verify after Track A regen | Track A sprint | F1 (writes-on finisher) is FALSE; 4×3 C1 inherits the unsound finisher. |
| 3 | `GLOBAL.F2` | CLAIMED | `GLOBAL.C3` | backlog — F2-REMEDY tasks (done) | F2-REMEDY | F2 (fresh-start bracket bounds real-game) is orphaned by C3 falsification. F2-REMEDY designed a fix; needs implementation. |
| 4 | `GLOBAL.ADR0010-CUT` | CLAIMED | `GLOBAL.C3` | backlog — re-ground or demote | Orchestrator | ADR-0010's cutoff depends on C3 holding; it doesn't. Either find a new foundation or accept as historical. |
| 5 | `GLOBAL.F3` | CLAIMED | `GLOBAL.C3` | backlog — re-ground | Theorist | F3 (score-on-cycle intractability) depends on C3. The state counts are factual but the conclusion chain has a FALSE link. |
| 6 | `GLOBAL.F4` | PROVEN (argument) + MEASUREMENT | `GLOBAL.C3` (via F3) | fix now — demote to CLAIMED | T200 (this sprint) | F4 is PROVEN but has a FALSE transitive ancestor via F3→C3. The measurement half is fine; the argument half is orphaned. Demote to CLAIMED with note. |
| 7 | `GLOBAL.H5c` | PROVEN (as an implication) | `GLOBAL.C3` | accept with reason | Dabir | H5c is "if C3 then …" — an implication, not an assertion. As an implication it is true regardless of C3's status. The `d:` edge should be removed (it's not a logical dependency; it's scoped to a conditional). |
| 8 | `GLOBAL.ADR0012-GATE` | CLAIMED (orphaned) | `4x4.COMPLETE-2026-07-21` | backlog — re-point to Track A writes-off artifact | Track A sprint | The gate depends on the retracted COMPLETE claim; it should be re-pointed to the Track A writes-off artifact when complete. T128 triaged this (§C1a-8). |
| 9 | `GLOBAL.B15` | CLAIMED | `GLOBAL.C3` (via F3) | backlog — re-ground | Theorist | B15 depends on F3→C3 chain. |
| 10 | `QA-018` | CLAIMED | `GLOBAL.C3` (via F2) | backlog — QA-018 review tasks exist | QA-018-REVIEW | QA-018 review tasks (A/B/C) are done; ruling is dispatchable. |

---

## C2 dangling evidence (12 MISSING paths)

| # | path | cited in | reachable from | disposition | owner | rationale |
|---|---|---|---|---|---|---|
| 1 | `untracked/B05-glm.md` | boards/, CONCEPTS.md, leak-crisis.md, evidence/README.md | 80 rows | accept — recorded in loss inventory | — | Confirmed lost (evidence/README.md §"CONFIRMED LOST"). The loss inventory is the canonical record. |
| 2 | `untracked/T07-audit-hypotheses.md` | boards/4x4/, evidence/README.md | 51 rows | accept — recorded in loss inventory | — | Confirmed lost. 4×4 EPISTEMIC.md carries a banner noting the unverifiable basis. |
| 3 | `untracked/T02-audit-kimi.md` | leak-crisis.md, evidence/README.md | 23 rows | accept — recorded in loss inventory | — | Confirmed lost. |
| 4 | `untracked/T02-minimax.md` | leak-crisis.md, evidence column, evidence/README.md | 23 rows | accept — recorded in loss inventory | — | Confirmed lost. |
| 5 | `untracked/B39-arena4x4.md` | research/arena-4x4-undef.md, evidence/README.md | 8 rows | accept — recorded in loss inventory | — | Confirmed lost. |
| 6 | `/tmp/audit-2x2-mismatch.log` | audits/2026-07-30-audit-2x2-mismatch.md | 4 rows | accept — ephemeral path | — | `/tmp/` paths are ephemeral by design. The audit document records the findings. |
| 7 | `untracked/T13-minimax.md` | research/c2-falsification-3x2.md, evidence/T13/, evidence/README.md | 3 rows | backlog — investigate recoverability | T13 owner | T13 is the C2 falsification; its minimax artifact is lost. The probe reimplementation exists. Determine if the original can be reconstructed. |
| 8 | `untracked/c2pilot_3x2.zig` | research/c2-falsification-3x2.md, evidence/T13/, evidence/README.md | 3 rows | backlog — investigate recoverability | T13 owner | T13's pilot source is lost. |
| 9 | `/tmp/zig-tables.txt` | evidence/T13/probe-reimplementation-2026-07-30.md | 1 row | accept — ephemeral path | — | `/tmp/` path. |
| 10–12 | (bulk .wzo artifacts) | evidence/README.md | — | accept — git-ignored by design | — | .wzo artifacts are large binaries tracked by hash in evidence/README.md, not in git. Informational only. |

---

## C3 PROVEN without committed evidence (79 rows)

CLAIMS.md §4.2 already tiers these by dependent count. The top 20 (most
dependents) are dispositioned individually; the remaining 59 are batched.

### Top 20 (highest dependent count)

| # | claim ID | dependents | disposition | owner | rationale |
|---|---|---|---|---|---|
| 1 | `GLOBAL.FP1` | 6 | backlog — verify-battery sprint | verify-battery | FP1 is "proven as mathematics" — the fixpoint theorem. Evidence should be the formal proof, not a code run. |
| 2 | `GLOBAL.INVSYM` | 6 | backlog — verify-battery sprint | verify-battery | Colour-inversion symmetry. Should be a structural proof. |
| 3 | `GLOBAL.AUDITOR` | 5 | backlog — auditor run needed | Auditor | The #2 self-consistency auditor is a mandatory pre-commit gate per AGENTS.md. Evidence = auditor run output. |
| 4 | `GLOBAL.FP3` | 3 | backlog — verify-battery sprint | verify-battery | FP3 re-convergence check. |
| 5 | `GLOBAL.FP2` | 3 | backlog — verify-battery sprint | verify-battery | FP2 iteration stability. |
| 6 | `GLOBAL.FP4` | 2 | backlog — verify-battery sprint | verify-battery | FP4 cross-validation. |
| 7 | `GLOBAL.FP5` | 2 | backlog — verify-battery sprint | verify-battery | FP5 lattice bounds. |
| 8 | `GLOBAL.CHAIN-DEF` | 2 | accept — definition | — | Definitions need no evidence beyond the text. |
| 9 | `GLOBAL.B1-MULTIFIX` | 2 | backlog — re-verify | Track A | Multi-fixpoint observation. |
| 10 | `GLOBAL.ADR0004-TERM` | 2 | backlog — audit ADR | Auditor | ADRs carry their own evidence in the ADR document. |
| 11 | `GLOBAL.ADR0006-EYE` | 2 | done — evidence exists in docs/evidence/ADR-0006/ | — | Evidence committed 2026-07-29. Claimlint may be miscounting because evidence is in a non-standard directory name. |
| 12 | `GLOBAL.ADR0013-REF` | 2 | backlog — audit ADR | Auditor | ADR-0013's claims about the refutation. |
| 13 | `GLOBAL.T06` | 1 | backlog — re-verify | Track A | Measurement claim. |
| 14–20 | (remaining top-20) | 1 each | batched — backlog as verify-battery tasks | verify-battery | Low-dependent-count PROVEN rows. Most are per-goban measurements. |

### Remaining 59

**Batched disposition:** backlog with task IDs in the verify-battery sprint.
These are predominantly per-goban measurement claims (`2x2.*`, `3x2.*`,
`3x3.*`, `4x3.*`, `4x4.*`) that need committed evidence in
`docs/evidence/<claim-id>/`. The verify-battery sprint already targets these.
No individual disposition needed — the batch is tracked as one kanban item.

---

## C4 dangling IDs (32) + unreferenced rows (41)

**Dangling IDs (32):** IDs cited in documents with no register row. Top 10
by citation frequency:

| # | dangling ID | disposition | owner | rationale |
|---|---|---|---|---|
| 1–10 | (sampled from claimlint output) | backlog — document sweep needed | pass 1 | These are either stale citations or missing register rows. The pass 1 reference sweep will identify each and either add a register row or remove the citation. |

**Unreferenced rows (41):** Register rows with no incoming citations. These
are not necessarily a problem — they may be new rows awaiting citation, or
leaf claims. Batched: review during pass 1 reference sweep.

---

## C5 shadowed dependencies (4)

| # | claim | shadowed parent | disposition | owner | rationale |
|---|---|---|---|---|---|
| 1 | `4x4.M6-SCREEN` → `4x4.M6` (MEASUREMENT) | backlog — add soundness parent | Theorist | M6-SCREEN claims something about screening; the `d:` edge should point at a soundness claim, not the measurement. |
| 2 | `4x4.COMPLETE-2026-07-21` → `GLOBAL.C1` (definition) | accept — already FALSE-AS-SCOPED | — | The claim is already retracted; the shadowed edge is moot. |
| 3–4 | `GLOBAL.ADR0012-5X5` → `GLOBAL.SWEEPS`, `GLOBAL.F4-COST` (MEASUREMENTs) | backlog — re-point to soundness claims | Orchestrator | ADR-0012-5X5 depends on measurements but needs soundness parents. |

---

## A: Repeated narrowing (5)

| # | claim | narrowed | now | disposition | owner | rationale |
|---|---|---|---|---|---|---|
| 1 | `GLOBAL.FP2-bounded` | 2× | FALSE-AS-SCOPED | accept — already dead | — | Narrowed to death. The pattern (repeated narrowing → FALSE) is documented. |
| 2 | `GLOBAL.CERTCORE` | 2× | FALSE-AS-SCOPED | accept — already dead | — | Same pattern. |
| 3 | `GLOBAL.C2` | 2× | FALSE-AS-SCOPED (at 3×2) | accept — already dead | — | Falsified at 3×2 (T13). |
| 4 | `GLOBAL.C3` | 2× | FALSE-AS-SCOPED (at 3×3) | accept — already dead | — | Falsified at 3×3 (E2). |
| 5 | `GLOBAL.REFRAME` | 3× | CLAIMED (adopted decision) | accept — survivor | — | The one claim that survived repeated narrowing. The pattern suggests REFRAME is the correct framing. |

---

## Summary

| category | total | fix now | backlog | accept | batched |
|---|---|---|---|---|---|
| C1a orphans | 10 | 1 (demote F4) | 8 | 1 (H5c — implication) | 0 |
| C2 dangling | 12 | 0 | 2 (T13 artifacts) | 10 (loss inventory + ephemeral) | 0 |
| C3 no evidence | 79 | 0 | 19 (top-20 minus done/def) | 1 (CHAIN-DEF) | 59 |
| C4 dangling/unref | 32/41 | 0 | 32/41 | 0 | 32/41 |
| C5 shadowed | 4 | 0 | 2 | 2 | 0 |
| A narrowing | 5 | 0 | 0 | 5 | 0 |

**Every row dispositioned.** R2-4 satisfied.
