# INDEX — claim-to-task cross-reference (generated)

```
Task: n/a · Role: generator · Model: n/a · Date: 2026-08-02
Source: docs/infra/dispatch/*.md briefs + docs/epistemic/CLAIMS.md
```

**Generated from `docs/infra/dispatch/*.md` briefs and `docs/epistemic/CLAIMS.md`.**
Reproduce with:

    python3 tools/gen-indices

Each entry maps a claim ID to the task(s) that close it, bear on it, or
produced its evidence. Status is from the kanban (`./bin/managent status`).

---

## Claim → task mapping

| claim ID | task(s) | task status |
|---|---|---|
| `2x2.B1` | EVIDENCE-INTEGRITY | see kanban |
| `2x2.BASICKO-TIE` | EXP-4 | see kanban |
| `2x2.T12` | EXP-2-AUDIT-PREREG, EXP-2 | see kanban |
| `2x2.brute_value` | EXP-2, EXP-2B | see kanban |
| `2x2.value` | 2B-0, 2B-1 | see kanban |
| `2x2.wzo` | EXP-4 | see kanban |
| `2x2.zig` | 2B-FIX-KO, EXP-2 | see kanban |
| `3x2.B1` | EVIDENCE-INTEGRITY | see kanban |
| `3x2.BASICKO-TIE` | EXP-4 | see kanban |
| `3x2.QA023` | 2B-0, 2B-2, 2B-6, 2B-PROBE-FIX | see kanban |
| `3x2.T13` | EVIDENCE-INTEGRITY, EXP-8, T124-t13-row-rewrite | see kanban |
| `3x2.md` | 2B-5, EVIDENCE-INTEGRITY, EXP-10, EXP-2, EXP-8 … (+2) | see kanban |
| `3x2.wzo` | EXP-4 | see kanban |
| `3x2.zig` | T124-t13-row-rewrite | see kanban |
| `3x3.B1` | EVIDENCE-INTEGRITY | see kanban |
| `3x3.BASICKO-TIE` | T125-basicko-tie-and-aliasing | see kanban |
| `3x3.H1-CENSUS` | EXP-3 | see kanban |
| `3x3.md` | EXP-2-AUDIT-PREREG, EXP-2, EXP-2B, EXP-4, EXP-5 … (+2) | see kanban |
| `3x3.wzo` | EXP-5, EXP-7, EXP-8 | see kanban |
| `4x3.H1-CENSUS` | EXP-3 | see kanban |
| `4x3.wzo` | EXP-7 | see kanban |
| `4x4.ANCHOR` | EVIDENCE-INTEGRITY, NARRATIVE-LAYER, REFERENCES | see kanban |
| `4x4.BASICKO-TIE` | T125-basicko-tie-and-aliasing | see kanban |
| `4x4.BRACKET` | REFERENCES | see kanban |
| `4x4.C2` | T124-t13-row-rewrite | see kanban |
| `4x4.COMPLETE-2026-07-21` | EXP-6 | see kanban |
| `4x4.D3` | EXP-3, EXP-6 | see kanban |
| `4x4.M4` | EXP-7 | see kanban |
| `4x4.PARALLEL` | EXP-6 | see kanban |
| `4x4.WRITESOFF` | EXP-6 | see kanban |
| `4x4.checkpoint` | EXP-6, EXP-7-4x4-rerun, EXP-7, EXP-8 | see kanban |
| `4x4.md` | EVIDENCE-INTEGRITY, EXP-6, REFERENCES | see kanban |
| `4x4.wzo` | EXP-6 | see kanban |
| `CODE.ADR0011-FMT` | EXP-3 | see kanban |
| `GLOBAL.ADR0006-EYE` | T123-absorb-adr0006-rows | see kanban |
| `GLOBAL.ADR0006-LEMMAS` | T123-absorb-adr0006-rows | see kanban |
| `GLOBAL.ADR0006-PRED` | T123-absorb-adr0006-rows | see kanban |
| `GLOBAL.ADR0006-PRUNEALL` | T123-absorb-adr0006-rows | see kanban |
| `GLOBAL.ADR0006-TEST` | T123-absorb-adr0006-rows | see kanban |
| `GLOBAL.ADR0007-BACKEDGE` | EXP-3 | see kanban |
| `GLOBAL.ADR0010-CUT` | REFERENCES | see kanban |
| `GLOBAL.ADR0015-BURDEN` | QA-018-REVIEW | see kanban |
| `GLOBAL.C1` | EXP-8 | see kanban |
| `GLOBAL.C2` | NARRATIVE-LAYER, T124-t13-row-rewrite | see kanban |
| `GLOBAL.C3` | EXP-5, EXP-6, NARRATIVE-LAYER | see kanban |
| `GLOBAL.C4` | T124-t13-row-rewrite | see kanban |
| `GLOBAL.CALIB-LESSON` | QA-018-REVIEW | see kanban |
| `GLOBAL.CLAIMLINT` | EXP-13-claimlint-rerun, T128-claimlint-dangling-retire | see kanban |
| `GLOBAL.CORRECTIONS` | EXP-14-corrections-cross-check | see kanban |
| `GLOBAL.DENOMINATORS` | EXP-12-denominator-sweep | see kanban |
| `GLOBAL.E1` | T125-basicko-tie-and-aliasing | see kanban |
| `GLOBAL.F2` | EXP-10, F2-REMEDY, NARRATIVE-LAYER, QA-018-REVIEW, QA-018-RULING | see kanban |
| `GLOBAL.F2-REMEDY` | F2-REMEDY | see kanban |
| `GLOBAL.H1` | CLAIMS-SPLIT-CONJUNCTS, EXP-3, T124-t13-row-rewrite | see kanban |
| `GLOBAL.H1-CENSUS` | EVIDENCE-INTEGRITY, EXP-3, EXP-6 | see kanban |
| `GLOBAL.H1-COMPUTABLE` | CLAIMS-SPLIT-CONJUNCTS | see kanban |
| `GLOBAL.H1-MARKOV` | CLAIMS-SPLIT-CONJUNCTS | see kanban |
| `GLOBAL.HYPOTHESES` | EXP-15-hypotheses-reality-check | see kanban |
| `GLOBAL.LONGCYCLE` | CLAIMS-SPLIT-CONJUNCTS, NARRATIVE-LAYER, QA023-KERNEL-AUDIT | see kanban |
| `GLOBAL.ONEMISMATCH` | CLAIMS-SPLIT-CONJUNCTS | see kanban |
| `GLOBAL.ONEWRITER` | EXP-6 | see kanban |
| `GLOBAL.R1` | NARRATIVE-LAYER | see kanban |
| `GLOBAL.R2` | F2-REMEDY, NARRATIVE-LAYER | see kanban |
| `GLOBAL.R3` | NARRATIVE-LAYER | see kanban |
| `GLOBAL.REFRAME` | T124-t13-row-rewrite | see kanban |
| `GLOBAL.RPLY` | NARRATIVE-LAYER | see kanban |
| `GLOBAL.RPLY-TRAP` | F2-REMEDY | see kanban |
| `GLOBAL.S1` | EXP-3 | see kanban |
| `GLOBAL.SESSION-CHOOSE` | EXP-16-session-choose-audit | see kanban |
| `QA-002` | EXP-9 | see kanban |
| `QA-010` | EXP-8 | see kanban |
| `QA-011` | CLAIMS-SPLIT-CONJUNCTS, EXP-3 | see kanban |
| `QA-012` | EXP-8 | see kanban |
| `QA-013` | QA023-KERNEL-AUDIT | see kanban |
| `QA-016` | EXP-4, EXP-6 | see kanban |
| `QA-018` | EXP-10, EXP-13-claimlint-rerun, EXP-6, F2-REMEDY, NARRATIVE-LAYER … (+6) | see kanban |
| `QA-019` | EXP-10, EXP-6, QA-018-REVIEW, QA-018-RULING | see kanban |
| `QA-020` | EXP-7-4x4-rerun, EXP-7 | see kanban |
| `QA-021` | EXP-7 | see kanban |
| `QA-023` | 2B-0, 2B-2-AUDIT, 2B-2, 2B-3-AUDIT, 2B-3 … (+24) | see kanban |
| `QA-023.M2` | 2B-0 | see kanban |
| `QA-024` | EXP-8 | see kanban |
| `QA-025` | EVIDENCE-INTEGRITY, EXP-5, EXP-6, REFERENCES | see kanban |
| `QA-026` | 2B-PROBE-FIX, CLAIMS-SPLIT-CONJUNCTS, EXP-2, EXP-4, EXP-5 … (+6) | see kanban |
| `QA-027` | EXP-7-4x4-rerun, EXP-7 | see kanban |

*85 claims mapped to tasks.*