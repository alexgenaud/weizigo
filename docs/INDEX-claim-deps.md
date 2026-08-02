# INDEX — claim dependency tree (generated)

```
Task: n/a · Role: generator · Model: n/a · Date: 2026-08-02
Source: docs/epistemic/CLAIMS.md edges (147 d:, 19 n:, 173 e:)
```

**Generated from `docs/epistemic/CLAIMS.md` edge columns.**
Answers "what else falls if X is false" in one hop.

---

## How to use this

- **Parents** — claims this one depends on (if any parent is FALSE, this claim is orphaned)
- **Children** — claims that depend on this one (if this is FALSE, all children are orphaned)
- `d:` = derives-from (logical consequence)
- `n:` = derives-from-negation (justified by parent being FALSE)
- `e:` = evidenced-by

---

## Claims with dependencies (254 of 303)

| claim ID | status | parents (why this depends) | children (what depends on this) |
|---|---|---|---|
| `GLOBAL.S2` | PROVEN | — | `e:3x3.S2-impl` · `e:4x4.S2-impl` · `e:4x3.S2-impl` · `d:4x3.S2` · `d:GLOBAL.ADR0006-EYE` · `e:GLOBAL.ADR0006-PRED` · `e:GLOBAL.ADR0006-LEMMAS` · `d:GLOBAL.ADR0004-TERM` · `d:GLOBAL.AXIOM-AREA` · `d:GLOBAL.H5a-FALLBACK` · `d:GLOBAL.H5b` · `d:GLOBAL.ADR0014-PURE` · `d:GLOBAL.ADR0014-DEAD` |
| `GLOBAL.INVSYM` | PROVEN | — | `e:3x3.C1` · `e:4x3.C1` · `e:4x4.C1` · `d:GLOBAL.E2-POLICY` · `e:2x2.F2` · `e:GLOBAL.MEMO-XROOT` · `d:GLOBAL.P2` · `e:4x4.REGR-SYM` · `d:GLOBAL.AXIOM-SCORESIGN` · `e:2x2.EXACT` · `e:2x2.BASICKO-TIE` · `e:3x2.BASICKO-TIE` · `e:3x3.BASICKO-TIE` |
| `4x4.M4` | MEASUREMENT | `e:4x4.PARALLEL` | `e:4x4.FP1` · `e:4x4.FP1-C3` · `e:4x4.M5` · `e:4x4.REGR-CLIFF` · `e:GLOBAL.CHAIN-LH` · `e:GLOBAL.CHAIN-KO` · `e:GLOBAL.MAXGAP` · `e:4x4.M6` · `e:4x4.A-3` · `e:QA-005` · `e:QA-017` · `e:QA-021` |
| `GLOBAL.FP1` | PROVEN (as mathematics) | `d:GLOBAL.FP3` | `e:2x2.B1` · `e:3x2.B1` · `e:3x3.B1` · `d:GLOBAL.B1-AUDIT` · `d:4x4.FP1` · `d:4x3.FP1` · `d:GLOBAL.FP2` · `d:GLOBAL.AXIOM-LH` · `e:GLOBAL.FIXPOINT-VS-SEARCH` · `d:GLOBAL.ADR0012-PAR` |
| `GLOBAL.C3` | FALSE-AS-SCOPED (at 3×3) | `d:GLOBAL.FP2` · `d:GLOBAL.ADR0009-HONESTY` | `d:4x3.C3` · `d:4x4.C3` · `d:GLOBAL.F2` · `d:GLOBAL.ADR0010-CUT` · `d:4x4.F2` · `d:GLOBAL.F3` · `n:GLOBAL.REFRAME` · `n:GLOBAL.H1-MARKOV` · `d:GLOBAL.H5c` · `n:GLOBAL.ADR0015-BURDEN` |
| `GLOBAL.S4` | PROVEN | — | `d:4x4.S4` · `d:4x3.S4` · `d:GLOBAL.ADR0006-EYE` · `e:GLOBAL.ADR0006-LEMMAS` · `d:GLOBAL.ADR0004-TERM` · `d:GLOBAL.ADR0005-DBLPASS` · `d:GLOBAL.AXIOM-AREA` |
| `GLOBAL.F1` | FALSE-AS-SCOPED | `d:GLOBAL.ADR0005-CACHE` | `d:4x3.C1` · `d:4x4.C1` · `n:4x4.F1` · `n:4x3.F1` · `e:4x4.M3` · `d:4x4.COMPLETE-2026-07-21` · `n:GLOBAL.H3` |
| `GLOBAL.MIGOS-RULE` | PROVEN | — | `d:GLOBAL.ANCHOR-DELTA` · `e:GLOBAL.TIE-MIGOS` · `e:GLOBAL.FIXPOINT-VS-SEARCH` · `d:4x4.CYCLE-INSENS` · `e:3x3.BASICKO-TIE` · `e:4x4.BASICKO-TIE` · `d:QA-025` |
| `GLOBAL.C4` | FALSE-AS-SCOPED | `d:GLOBAL.C2` · `d:GLOBAL.P3` | `n:GLOBAL.LEAK` · `d:GLOBAL.P1` · `d:GLOBAL.P3` · `e:4x4.B16-GAME` · `n:GLOBAL.REFRAME` · `n:GLOBAL.H1-MARKOV` |
| `4x4.M6` | MEASUREMENT | `e:4x4.M4` · `e:4x4.WRITESOFF` | `e:4x4.F2` · `e:4x4.F3` · `e:4x4.M6-FLOOR` · `e:4x4.M6-EXCESS` · `d:4x4.M6-SCREEN` · `e:QA-006` |
| `GLOBAL.S3a` | PROVEN (as scoped) | — | `e:4x4.S3a` · `e:4x3.S3a` · `e:GLOBAL.H1-CENSUS` · `e:3x3.H1-CENSUS` · `e:4x4.G-CENSUS` |
| `3x3.B1` | CLAIMED | `e:GLOBAL.FP1` | `e:GLOBAL.B1-MULTIFIX` · `e:3x3.C3` · `d:GLOBAL.E2-VERDICT` · `e:3x3.F2` · `e:3x3.BRACKET` |
| `GLOBAL.FP3` | PROVEN | — | `d:GLOBAL.FP1` · `d:4x4.FP3` · `d:4x3.FP3` · `d:GLOBAL.AXIOM-LH` · `d:GLOBAL.ADR0012-PAR` |
| `GLOBAL.C2` | FALSE-AS-SCOPED (at 3×2) | `d:GLOBAL.FP2-bounded` | `d:GLOBAL.C4` · `n:GLOBAL.REFRAME` · `n:GLOBAL.CHAIN-KIND` · `n:GLOBAL.H1-MARKOV` · `n:GLOBAL.H5d` |
| `GLOBAL.AUDITOR` | PROVEN | — | `e:3x2.F1` · `e:3x2.F3` · `e:3x2.F4` · `e:3x3.F4` · `e:4x3.F4` |
| `GLOBAL.ADR0006-EYE` | CLAIMED | `d:GLOBAL.S2` · `d:GLOBAL.S4` | `e:2x2.C1` · `e:3x2.C1` · `d:GLOBAL.F2` · `d:GLOBAL.F3` · `d:GLOBAL.ADR0006-PRUNEALL` |
| `GLOBAL.S1` | PROVEN | — | `e:4x4.S1` · `d:4x3.S1` · `d:GLOBAL.AXIOM-STATE` · `d:CODE.ADR0011-FMT` |
| `GLOBAL.FP2` | CLAIMED | `d:GLOBAL.FP1` | `d:GLOBAL.FP2-bounded` · `d:GLOBAL.FP2-general` · `d:GLOBAL.CERTCORE` · `d:GLOBAL.C3` |
| `GLOBAL.FP2-bounded` | FALSE-AS-SCOPED (at 3×2) | `d:GLOBAL.FP2` | `d:GLOBAL.C2` · `d:3x3.C2` · `d:4x3.C2` · `d:4x4.C2` |
| `3x2.C1` | PROVEN | `e:3x2.EXACT` · `e:GLOBAL.ADR0006-EYE` | `e:3x2.T13` · `e:4x4.P3` · `e:GLOBAL.T06` · `e:GLOBAL.ANCHOR-DELTA` |
| `GLOBAL.F2` | CLAIMED | `d:GLOBAL.C3` · `d:GLOBAL.ADR0009-HONESTY` · `d:GLOBAL.ADR0006-EYE` | `d:3x3.C1` · `d:4x3.F2` · `d:4x4.F2` · `d:QA-018` |
| `GLOBAL.F3` | CLAIMED | `d:GLOBAL.C3` · `d:GLOBAL.ADR0006-EYE` · `d:GLOBAL.CERTCORE` | `d:4x4.F3` · `d:GLOBAL.F4` · `d:GLOBAL.B15` · `e:QA-019` |
| `4x4.M5` | PROVEN | `e:4x4.M4` · `e:4x4.BRACKET` | `e:4x4.GTP-DEFECT` · `e:GLOBAL.H5a` · `e:QA-004` · `e:QA-020` |
| `GLOBAL.CHAIN-LH` | PROVEN (on the audited artifacts) | `e:2x2.M4` · `e:4x4.M4` | `d:GLOBAL.H5a` · `e:GLOBAL.H5a-CHILD` · `d:QA-014` · `e:QA-020` |
| `GLOBAL.CHAIN-KO` | PROVEN | `e:2x2.M4` · `e:4x4.M4` | `d:GLOBAL.H1-MARKOV` · `e:4x4.A-2` · `e:QA-001` · `e:QA-017` |
| `2x2.M4` | MEASUREMENT | — | `e:GLOBAL.CHAIN-LH` · `e:GLOBAL.CHAIN-KO` · `e:GLOBAL.MAXGAP` · `e:GLOBAL.C-1` |
| `4x4.BRACKET` | MEASUREMENT | `e:4x4.FP1` | `e:4x4.M5` · `e:4x4.TANGLE` · `e:4x4.BASICKO-TIE` · `e:QA-004` |
| `4x4.D3` | UNTESTED | `e:4x3.M3` | `d:4x4.F2` · `d:4x4.F3` · `d:4x4.F4` · `d:GLOBAL.H4a` |
| `QA-023` | CLAIMED | — | `d:GLOBAL.F2-REMEDY` · `d:QA-012` · `d:QA-026` · `d:QA-027` |
| `GLOBAL.S3b` | CLAIMED | — | `d:4x4.S3b` · `d:4x3.S3b` · `d:GLOBAL.R1` |
| `GLOBAL.ADR0009-HONESTY` | PROVEN (as a statement about the argument) | — | `d:GLOBAL.C3` · `d:GLOBAL.F2` · `d:GLOBAL.ADR0010-SOUND` |
| `2x2.C1` | PROVEN | `e:2x2.EXACT` · `e:GLOBAL.ADR0006-EYE` | `e:4x4.P3` · `e:GLOBAL.T06` · `e:GLOBAL.ANCHOR-DELTA` |
| `GLOBAL.BRUTE-ALIASING` | FALSE (methodological) | — | `n:2x2.BASICKO-TIE` · `n:3x2.BASICKO-TIE` · `n:3x3.BASICKO-TIE` |
| `GLOBAL.E2-SANITY` | PROVEN | — | `d:GLOBAL.E2-VERDICT` · `e:3x3.E2-RUN1` · `e:3x3.E2-RUN2` |
| `4x4.B43` | MEASUREMENT | `e:CODE.UNDEF` · `e:4x4.PARALLEL` | `e:4x4.B43-DIV` · `e:4x4.GREEDY-BIAS` · `e:GLOBAL.H2` |
| `4x4.GTP-DEFECT` | PROVEN | `d:4x4.CHAIN-KO` · `e:4x4.M5` · `e:4x4.KO-RULE-NULL` | `d:4x4.GREEDY-BIAS` · `d:GLOBAL.H5` · `e:QA-014` |
| `GLOBAL.R1` | PROVEN (structural) | `d:GLOBAL.S3b` · `e:2x2.R1` · `e:3x2.R1` | `d:4x4.R1` · `d:GLOBAL.PSK-GAP` · `d:GLOBAL.FWD-INTRACT` |
| `2x2.R1` | MEASUREMENT | — | `e:GLOBAL.R1` · `e:4x4.R1` · `e:GLOBAL.R2` |
| `GLOBAL.REFRAME` | CLAIMED (adopted decision) | `n:GLOBAL.C2` · `n:GLOBAL.C3` · `n:GLOBAL.C4` · `n:` | `d:GLOBAL.UD-1` · `d:GLOBAL.UD-2` · `d:GLOBAL.UD-3` |
| `GLOBAL.AXIOM-PASS` | CLAIMED | — | `d:GLOBAL.AXIOM-KOSTATE` · `d:GLOBAL.AXIOM-KOPASS` · `d:GLOBAL.AXIOM-TERMINAL` |
| `4x4.M1` | MEASUREMENT | `e:4x4.S3a` · `e:GLOBAL.ADR0009-NOEYE` | `e:4x4.R3` · `e:4x4.KO-CENSUS` · `e:4x4.SINGLE` |
| `4x4.PARALLEL` | MEASUREMENT | — | `e:4x4.B43` · `e:4x4.M4` · `e:QA-016` |
| `GLOBAL.PASS-NOKO` | PROVEN (code + independent re-derivation) | — | `d:GLOBAL.AXIOM-PASSSTATE` · `d:4x4.I5-FEAS` · `d:CODE.WZO2-PASSBIT` |
| `GLOBAL.LONGCYCLE` | FALSE-AS-SCOPED | `d:GLOBAL.R2` | `d:GLOBAL.H1-COMPUTABLE` · `d:QA-013` · `d:QA-026` |
| `4x4.S3a` | PROVEN | `e:GLOBAL.S3a` · `e:4x4.S1` | `e:4x4.C1` · `e:4x4.M1` |
| `4x3.S3a` | PROVEN | `e:GLOBAL.S3a` | `e:4x3.M1` · `e:4x3.H1-CENSUS` |
| `2x2.B1` | CLAIMED | `e:GLOBAL.FP1` | `e:GLOBAL.B1-MULTIFIX` · `e:2x2.C3` |
| `3x2.B1` | CLAIMED | `e:GLOBAL.FP1` | `e:GLOBAL.B1-MULTIFIX` · `e:3x2.C3` |
| `3x2.T13` | PROVEN (falsification) | `e:3x2.C1` · `e:3x2.EXACT` | `e:4x4.C2` · `e:QA-022` |
| `3x3.C3` | PROVEN (falsification) | `e:3x3.B1` · `e:3x3.E3` · `e:3x3.E2-RUN1` · `e:3x3.E2-RUN2` | `e:4x4.C3` · `e:GLOBAL.ADR0015-BURDEN` |
| `3x3.E3` | PROVEN | — | `e:3x3.C3` · `d:GLOBAL.E2-VERDICT` |
| `GLOBAL.E2-POLICY` | PROVEN (bug + fix) | `d:GLOBAL.INVSYM` | `e:3x3.E2-RUN1` · `e:3x3.E2-RUN2` |
| `3x3.E2-RUN1` | MEASUREMENT | `e:GLOBAL.E2-POLICY` · `e:GLOBAL.E2-SANITY` | `e:3x3.C3` · `e:QA-009` |
| `3x3.E2-RUN2` | MEASUREMENT | `e:GLOBAL.E2-POLICY` · `e:GLOBAL.E2-SANITY` | `e:3x3.C3` · `e:QA-009` |
| `GLOBAL.ADR0005-CACHE` | FALSE-AS-SCOPED | — | `n:GLOBAL.ADR0008-HOLE` · `d:GLOBAL.F1` |
| `3x2.F1` | PROVEN (falsification) | `e:GLOBAL.AUDITOR` | `e:4x4.F1` · `e:4x3.F1` |
| `GLOBAL.ADR0010-CUT` | CLAIMED | `d:GLOBAL.C3` | `e:4x4.HISTPERF-CHEAP` · `e:GLOBAL.FIN-BRACKET` |
| `3x3.F2` | MEASUREMENT | `e:3x3.B1` · `e:3x3.ANCHOR` | `e:3x3.C1` · `e:3x3.ANCHOR` |
| `GLOBAL.F4` | PROVEN (argument) + MEASUREMENT | `d:GLOBAL.F3` | `d:4x4.F4` · `e:GLOBAL.F4-COST` |
| `GLOBAL.ADR0009-NOEYE` | PROVEN | — | `d:GLOBAL.ADR0006-TEST` · `e:4x4.M1` |
| `GLOBAL.ADR0004-TERM` | PROVEN | `d:GLOBAL.S2` · `d:GLOBAL.S4` | `d:GLOBAL.H5a-FALLBACK` · `d:GLOBAL.H5b` |
| `GLOBAL.ADR0003-AREA` | PROVEN | — | `d:GLOBAL.AXIOM-AREA` · `d:GLOBAL.ADR0014-PURE` |
| `GLOBAL.P2` | PROVEN (as scoped) | `d:GLOBAL.INVSYM` | `e:4x4.VALBATTERY` · `d:CODE.ADR0011-GATE` |
| `4x4.KO-RULE-NULL` | PROVEN (these two games) | — | `e:4x4.GTP-DEFECT` · `e:4x4.A-1` |
| `CODE.UNDEF` | PROVEN | — | `e:4x4.B43` · `e:QA-016` |
| `3x2.R1` | MEASUREMENT | — | `e:GLOBAL.R1` · `e:GLOBAL.R2` |
| `GLOBAL.R2` | PROVEN (argument) + MEASUREMENT | `e:2x2.R1` · `e:3x2.R1` | `d:GLOBAL.RPLY-TRAP` · `d:GLOBAL.LONGCYCLE` |
| `4x4.WRITESOFF` | MEASUREMENT | — | `e:4x4.M6` · `e:QA-008` |
| `4x4.M2` | MEASUREMENT | — | `e:4x4.FP1` · `e:4x4.FP1-C2` |
| `4x4.ANCHOR` | MEASUREMENT | `e:GLOBAL.P1` | `e:4x4.C1` · `e:4x4.CYCLE-INSENS` |
| `3x3.ANCHOR` | MEASUREMENT | `e:3x3.F2` | `e:3x3.C1` · `e:3x3.F2` |
| `2x2.EXACT` | MEASUREMENT | `e:GLOBAL.INVSYM` | `e:2x2.C1` · `e:2x2.T12` |
| `3x2.EXACT` | MEASUREMENT | — | `e:3x2.C1` · `e:3x2.T13` |
| `GLOBAL.H1-CENSUS` | PROVEN | `e:GLOBAL.S3a` | `e:4x4.G-CENSUS` · `e:4x4.I5-FEAS` |
| `4x4.A-3` | FALSE-AS-SCOPED (the player is not fresh-start-perfect in the ko-sensitive region: node's own V0 = −3, chosen child = −16) | `e:4x4.M4` | `n:GLOBAL.H5a-CHILD` · `d:QA-002` |
| `CODE.WZO2-PASSBIT` | PROVEN (measured, both failing checks reproduced with counts; root cause read in the source and fixed) | `d:GLOBAL.PASS-NOKO` | `d:SPRINT-M4a-ACCEPT` · `d:CODE.WZO2-INCOMPLETE` |
| `4x4.S1` | PROVEN | `e:GLOBAL.S1` | `e:4x4.S3a` |
| `4x4.FP1` | UNTESTED (checks 1–2); check 3 PASSES | `d:GLOBAL.FP1` · `e:4x4.M4` · `e:4x4.M2` | `e:4x4.BRACKET` |
| `4x4.FP1-C3` | PROVEN (as scoped) | `e:4x4.M4` | `d:GLOBAL.H4` |
| `4x3.FP1` | CLAIMED | `d:GLOBAL.FP1` | `e:4x3.BRACKET` |
| `GLOBAL.CERTCORE` | FALSE-AS-SCOPED | `d:GLOBAL.FP2` | `d:GLOBAL.F3` |
| `GLOBAL.C1` | — (definition) | — | `d:4x4.COMPLETE-2026-07-21` |
| `GLOBAL.LEAK` | PROVEN | `n:GLOBAL.C4` | `e:GLOBAL.P3` |
| `4x4.F1` | CLAIMED | `n:GLOBAL.F1` · `e:3x2.F1` | `d:4x4.M6-EXCESS` |
| `4x3.F2` | UNTESTED | `d:GLOBAL.F2` | `d:4x3.C1` |
| `4x4.F2` | UNTESTED | `d:GLOBAL.F2` · `d:GLOBAL.C3` · `d:4x4.D3` · `e:4x4.M6` | `d:4x4.C1` |
| `4x4.F3` | UNTESTED | `d:GLOBAL.F3` · `d:4x4.D3` · `e:4x4.M6` | `d:4x4.F4` |
| `GLOBAL.F4-COST` | MEASUREMENT | `e:GLOBAL.F4` | `d:GLOBAL.ADR0012-5X5` |
| `GLOBAL.ADR0005-PASS` | PROVEN | — | `d:GLOBAL.ADR0012-V1` |
| `GLOBAL.P1` | FALSE-AS-SCOPED | `d:GLOBAL.C4` | `e:4x4.ANCHOR` |
| `GLOBAL.P3` | FALSE-AS-SCOPED | `d:GLOBAL.C4` · `e:GLOBAL.LEAK` | `d:GLOBAL.C4` |
| `4x4.GREEDY-BIAS` | CLAIMED | `d:4x4.GTP-DEFECT` · `e:4x4.B43` | `d:GLOBAL.H2` |
| `GLOBAL.RPLY` | PROVEN (falsification) | — | `e:QA-028` |
| `GLOBAL.RPLY-TRAP` | PROVEN (argument) | `d:GLOBAL.R2` | `e:QA-028` |
| `GLOBAL.AXIOM-BASICKO` | CLAIMED | — | `d:GLOBAL.AXIOM-KOSTATE` |
| `GLOBAL.AXIOM-KOSTATE` | CLAIMED | `d:GLOBAL.AXIOM-BASICKO` · `d:GLOBAL.AXIOM-PASS` | `d:GLOBAL.AXIOM-KOPASS` |
| `GLOBAL.AXIOM-TERMINAL` | CLAIMED | `d:GLOBAL.AXIOM-PASS` | `d:GLOBAL.AXIOM-BELLMAN` |
| `GLOBAL.AXIOM-AREA` | CLAIMED | `d:GLOBAL.S2` · `d:GLOBAL.ADR0003-AREA` · `d:GLOBAL.S4` | `d:GLOBAL.AXIOM-BELLMAN` |
| `GLOBAL.AXIOM-LH` | CLAIMED | `d:GLOBAL.FP1` · `d:GLOBAL.FP3` | `d:GLOBAL.AXIOM-BRACKET` |
| `GLOBAL.TIE-MIGOS` | CLAIMED | `e:GLOBAL.MIGOS-RULE` · `e:4x4.BASICKO-TIE` | `e:4x4.BASICKO-TIE` |
| `GLOBAL.CHAIN-KIND` | PROVEN | `n:GLOBAL.C2` | `d:4x4.M6-FLOOR` |
| `3x2.M4` | MEASUREMENT | — | `e:GLOBAL.C-1` |
| `4x4.M6-FLOOR` | PROVEN (on the swept artifact) | `d:GLOBAL.CHAIN-KIND` · `e:4x4.M6` | `e:QA-019` |
| `4x4.M6-EXCESS` | CLAIMED | `d:4x4.F1` · `e:4x4.M6` | `d:QA-007` |
| `4x4.COMPLETE-2026-07-21` | FALSE-AS-SCOPED | `d:GLOBAL.F1` · `d:GLOBAL.C1` | `d:GLOBAL.ADR0012-GATE` |
| `4x3.M3` | MEASUREMENT | — | `e:4x4.D3` |
| `4x3.BRACKET` | MEASUREMENT | `e:4x3.FP1` | `e:4x3.TANGLE` |
| `GLOBAL.SWEEPS` | MEASUREMENT | — | `d:GLOBAL.ADR0012-5X5` |
| `GLOBAL.FIN-BRACKET` | MEASUREMENT | `e:GLOBAL.ADR0010-CUT` | `e:GLOBAL.H5c` |
| `4x4.BASICKO-TIE` | MEASUREMENT | `e:GLOBAL.MIGOS-RULE` · `e:GLOBAL.TIE-MIGOS` · `e:4x4.BRACKET` | `e:GLOBAL.TIE-MIGOS` |
| `GLOBAL.H1-MARKOV` | UNTESTED | `n:GLOBAL.C2` · `n:GLOBAL.C3` · `n:GLOBAL.C4` · `d:GLOBAL.CHAIN-KO` | `d:QA-011` |
| `GLOBAL.H1-COMPUTABLE` | FALSE-AS-SCOPED | `d:GLOBAL.LONGCYCLE` | `d:GLOBAL.ONEMISMATCH-CURE` |
| `GLOBAL.H3` | UNTESTED | `n:GLOBAL.F1` | `d:GLOBAL.H5b` |
| `GLOBAL.H5b` | CLAIMED | `d:GLOBAL.S2` · `d:GLOBAL.ADR0004-TERM` · `d:GLOBAL.H3` | `e:GLOBAL.H5a-FALLBACK` |
| `GLOBAL.ONEMISMATCH-DIAG` | CLAIMED | — | `d:QA-010` |
| `4x4.A-2` | FALSE-AS-SCOPED (category error — every blundering node is KO_SENSITIVE, i.e. outside C2's scope) | `e:GLOBAL.CHAIN-KO` | `d:QA-003` |
| `CODE.ADR0011-GATE` | PROVEN | `d:GLOBAL.P2` | `e:4x4.VALBATTERY` |
| `4x4.I5-FEAS` | CLAIMED (projection; the calibration section is MEASUREMENT) | `d:GLOBAL.PASS-NOKO` · `e:GLOBAL.H1-CENSUS` | `e:3x2.I5-CAL` |
| `CODE.WZO2-INCOMPLETE` | PROVEN (direct artifact scan + self-play contradiction) | `d:CODE.WZO2-PASSBIT` | `d:WZO2-4X4-VALID` |
| `GLOBAL.ADR0007-BACKEDGE` | PROVEN | — | `d:GLOBAL.ADR0009-SUCC` |
| `GLOBAL.ADR0016-INHERIT` | CLAIMED (adopted rule — a decision, not a fact) | `e:QA-015` | `d:4x3.H1-CENSUS` |
| `GLOBAL.ADR0015-BURDEN` | CLAIMED | `n:GLOBAL.C3` · `e:3x3.C3` · `e:QA-019` | `e:QA-018` |
| `QA-014` | UNTESTED | `d:GLOBAL.CHAIN-LH` · `e:4x4.GTP-DEFECT` | `e:GLOBAL.H5a-CHILD` |
| `QA-015` | CLAIMED (**DECIDED 2026-07-28** — D-2, Opus + GLM; the rule now lives in ADR-0016, and `mixed` was **not** ruled on) | — | `e:GLOBAL.ADR0016-INHERIT` |
| `QA-019` | FALSE | `e:GLOBAL.F3` · `e:4x4.M6-FLOOR` | `e:GLOBAL.ADR0015-BURDEN` |
| `QA-026` | FALSE-AS-SCOPED | `d:QA-023` · `d:GLOBAL.LONGCYCLE` · `e:docs/evidence/QA-023/proof-v2-2026-07-28.md` | `d:QA-012` |
| `4x3.S1` | PROVEN | `d:GLOBAL.S1` | — |
| `3x3.S2-impl` | PROVEN | `e:GLOBAL.S2` | — |
| `4x4.S2-impl` | UNTESTED | `e:GLOBAL.S2` | — |
| `4x3.S2-impl` | UNTESTED | `e:GLOBAL.S2` | — |
| `4x3.S2` | PROVEN | `d:GLOBAL.S2` | — |
| `4x4.S3b` | UNTESTED | `d:GLOBAL.S3b` | — |
| `4x3.S3b` | UNTESTED | `d:GLOBAL.S3b` | — |
| `4x4.S4` | UNTESTED (`⬜ᴵᴺᴴ`) | `d:GLOBAL.S4` | — |
| `4x3.S4` | UNTESTED (`⬜ᴵᴺᴴ`) | `d:GLOBAL.S4` | — |
| `GLOBAL.B1-MULTIFIX` | MEASUREMENT | `e:2x2.B1` · `e:3x2.B1` · `e:3x3.B1` | — |
| `GLOBAL.B1-AUDIT` | PROVEN | `d:GLOBAL.FP1` | — |
| `4x4.FP1-C2` | UNTESTED | `e:4x4.M2` | — |
| `GLOBAL.FP2-general` | INTRACTABLE (possibly unprovable by finite methods) | `d:GLOBAL.FP2` | — |
| `4x4.FP3` | UNTESTED (`⬜ᴵᴺᴴ`) | `d:GLOBAL.FP3` | — |
| `4x3.FP3` | PROVEN | `d:GLOBAL.FP3` | — |
| `3x3.C1` | CLAIMED | `d:GLOBAL.F2` · `e:3x3.F2` · `e:3x3.ANCHOR` · `e:GLOBAL.INVSYM` | — |
| `4x3.C1` | CLAIMED | `d:4x3.F2` · `d:GLOBAL.F1` · `e:4x3.ANCHOR` · `e:GLOBAL.INVSYM` | — |
| `4x4.C1` | UNTESTED | `d:4x4.F2` · `d:GLOBAL.F1` · `e:4x4.ANCHOR` · `e:GLOBAL.INVSYM` · `e:4x4.S3a` | — |
| `2x2.T12` | MEASUREMENT | `e:2x2.EXACT` | — |
| `3x3.C2` | UNTESTED | `d:GLOBAL.FP2-bounded` | — |
| `4x3.C2` | UNTESTED | `d:GLOBAL.FP2-bounded` | — |
| `4x4.C2` | UNTESTED (status conflict, §6-D3) | `d:GLOBAL.FP2-bounded` · `e:3x2.T13` · `e:4x4.ARENA-DIV` | — |
| `2x2.C3` | MEASUREMENT | `e:2x2.B1` | — |
| `3x2.C3` | MEASUREMENT | `e:3x2.B1` | — |
| `4x3.C3` | UNTESTED | `d:GLOBAL.C3` | — |
| `4x4.C3` | UNTESTED (status conflict, §6-D2) | `d:GLOBAL.C3` · `e:3x3.C3` | — |
| `GLOBAL.E2-VERDICT` | CLAIMED | `d:3x3.B1` · `d:3x3.E3` · `d:GLOBAL.E2-SANITY` | — |
| `GLOBAL.ADR0008-HOLE` | PROVEN (as a statement about the argument) | `n:GLOBAL.ADR0005-CACHE` | — |
| `4x3.F1` | CLAIMED | `n:GLOBAL.F1` · `e:3x2.F1` | — |
| `GLOBAL.ADR0010-SOUND` | PROVEN (as a statement about the argument) | `d:GLOBAL.ADR0009-HONESTY` | — |
| `2x2.F2` | MEASUREMENT | `e:GLOBAL.INVSYM` | — |
| `3x2.F3` | PROVEN (necessary condition) | `e:GLOBAL.AUDITOR` | — |
| `3x2.F4` | PROVEN | `e:GLOBAL.AUDITOR` | — |
| `3x3.F4` | PROVEN | `e:GLOBAL.AUDITOR` | — |
| `4x3.F4` | PROVEN | `e:GLOBAL.AUDITOR` | — |
| `4x4.F4` | UNTESTED | `d:GLOBAL.F4` · `d:4x4.F3` · `d:4x4.D3` | — |
| `GLOBAL.MEMO-XROOT` | PROVEN (falsification) | `e:GLOBAL.INVSYM` | — |
| `GLOBAL.ADR0006-PRED` | PROVEN | `e:GLOBAL.S2` | — |
| `GLOBAL.ADR0006-LEMMAS` | PROVEN (per goban listed) | `e:GLOBAL.S2` · `e:GLOBAL.S4` | — |
| `GLOBAL.ADR0006-TEST` | PROVEN (executed 2026-07-30, scoped) | `d:GLOBAL.ADR0009-NOEYE` | — |
| `GLOBAL.ADR0006-PRUNEALL` | PROVEN (per goban listed) | `d:GLOBAL.ADR0006-EYE` · `e:4x4` | — |
| `GLOBAL.ADR0005-DBLPASS` | CLAIMED (argued, not machine-checked) | `d:GLOBAL.S4` | — |
| `4x4.P3` | MEASUREMENT | `e:2x2.C1` · `e:3x2.C1` | — |
| `GLOBAL.T06` | MEASUREMENT | `e:2x2.C1` · `e:3x2.C1` | — |
| `4x4.B43-DIV` | MEASUREMENT | `e:4x4.B43` | — |
| `4x4.REGR-SYM` | PROVEN | `e:GLOBAL.INVSYM` | — |
| `4x4.REGR-CLIFF` | MEASUREMENT | `e:4x4.M4` | — |
| `4x4.B16-GAME` | MEASUREMENT | `e:GLOBAL.C4` | — |
| `4x4.HISTPERF-CHEAP` | MEASUREMENT | `e:GLOBAL.ADR0010-CUT` | — |
| `4x4.R1` | CLAIMED | `d:GLOBAL.R1` · `e:2x2.R1` | — |
| `4x4.R3` | PROVEN (falsification) | `e:4x4.M1` | — |
| `GLOBAL.ANCHOR-DELTA` | CLAIMED | `d:GLOBAL.MIGOS-RULE` · `e:2x2.C1` · `e:3x2.C1` | — |
| `GLOBAL.UD-1` | CLAIMED | `d:GLOBAL.REFRAME` | — |
| `GLOBAL.UD-2` | CLAIMED | `d:GLOBAL.REFRAME` | — |
| `GLOBAL.UD-3` | CLAIMED | `d:GLOBAL.REFRAME` | — |
| `GLOBAL.PSK-GAP` | PROVEN | `d:GLOBAL.R1` | — |
| `GLOBAL.AXIOM-KOPASS` | CLAIMED | `d:GLOBAL.AXIOM-PASS` · `d:GLOBAL.AXIOM-KOSTATE` | — |
| `GLOBAL.AXIOM-SCORESIGN` | CLAIMED | `d:GLOBAL.INVSYM` | — |
| `GLOBAL.AXIOM-STATE` | CLAIMED | `d:GLOBAL.S1` | — |
| `GLOBAL.AXIOM-PASSSTATE` | CLAIMED | `d:GLOBAL.PASS-NOKO` | — |
| `GLOBAL.AXIOM-BELLMAN` | CLAIMED | `d:GLOBAL.AXIOM-TERMINAL` · `d:GLOBAL.AXIOM-AREA` | — |
| `GLOBAL.AXIOM-BRACKET` | CLAIMED | `d:GLOBAL.AXIOM-LH` | — |
| `GLOBAL.FIXPOINT-VS-SEARCH` | CLAIMED | `e:GLOBAL.FP1` · `e:GLOBAL.MIGOS-RULE` | — |
| `GLOBAL.MAXGAP` | CLAIMED | `e:2x2.M4` · `e:4x4.M4` | — |
| `4x4.M6-SCREEN` | CLAIMED | `d:4x4.M6` | — |
| `4x4.KO-CENSUS` | MEASUREMENT | `e:4x4.M1` | — |
| `4x4.M3` | MEASUREMENT | `e:GLOBAL.F1` | — |
| `4x4.SINGLE` | MEASUREMENT | `e:4x4.M1` | — |
| `4x4.TANGLE` | MEASUREMENT | `e:4x4.BRACKET` | — |
| `4x4.CYCLE-INSENS` | CLAIMED | `d:GLOBAL.MIGOS-RULE` · `e:4x4.ANCHOR` | — |
| `4x4.VALBATTERY` | MEASUREMENT | `e:GLOBAL.P2` · `e:CODE.ADR0011-GATE` | — |
| `4x3.M1` | MEASUREMENT | `e:4x3.S3a` | — |
| `4x3.TANGLE` | MEASUREMENT | `e:4x3.BRACKET` | — |
| `3x3.BRACKET` | MEASUREMENT | `e:3x3.B1` | — |
| `GLOBAL.FWD-INTRACT` | PROVEN | `d:GLOBAL.R1` | — |
| `2x2.BASICKO-TIE` | MEASUREMENT | `e:GLOBAL.INVSYM` · `n:GLOBAL.BRUTE-ALIASING` | — |
| `3x2.BASICKO-TIE` | MEASUREMENT | `e:GLOBAL.INVSYM` · `n:GLOBAL.BRUTE-ALIASING` | — |
| `3x3.BASICKO-TIE` | MEASUREMENT | `e:GLOBAL.INVSYM` · `e:GLOBAL.MIGOS-RULE` · `n:GLOBAL.BRUTE-ALIASING` | — |
| `3x3.H1-CENSUS` | PROVEN | `e:GLOBAL.S3a` | — |
| `4x3.H1-CENSUS` | PROVEN | `e:4x3.S3a` · `d:GLOBAL.ADR0016-INHERIT` | — |
| `4x4.G-CENSUS` | MEASUREMENT | `e:GLOBAL.H1-CENSUS` · `e:GLOBAL.S3a` | — |
| `GLOBAL.H2` | UNTESTED | `d:4x4.GREEDY-BIAS` · `e:4x4.B43` | — |
| `GLOBAL.H4` | CLAIMED (partial) | `d:4x4.FP1-C3` | — |
| `GLOBAL.H4a` | UNTESTED | `d:4x4.D3` | — |
| `GLOBAL.H5` | CLAIMED | `d:4x4.GTP-DEFECT` | — |
| `GLOBAL.H5a` | CLAIMED | `d:GLOBAL.CHAIN-LH` · `e:4x4.M5` | — |
| `GLOBAL.H5a-CHILD` | CLAIMED | `n:4x4.A-3` · `e:GLOBAL.CHAIN-LH` · `e:QA-014` | — |
| `GLOBAL.H5a-FALLBACK` | CLAIMED | `d:GLOBAL.S2` · `d:GLOBAL.ADR0004-TERM` · `e:GLOBAL.H5b` | — |
| `GLOBAL.H5c` | PROVEN (as an implication) | `d:GLOBAL.C3` · `e:GLOBAL.FIN-BRACKET` | — |
| `GLOBAL.H5d` | CLAIMED | `n:GLOBAL.C2` | — |
| `GLOBAL.ONEMISMATCH-CURE` | FALSE-AS-SCOPED | `d:GLOBAL.H1-COMPUTABLE` | — |
| `4x4.A-1` | FALSE-AS-SCOPED | `e:4x4.KO-RULE-NULL` | — |
| `GLOBAL.C-1` | FALSE-AS-SCOPED | `e:2x2.M4` · `e:3x2.M4` | — |
| `CODE.ADR0011-FMT` | PROVEN | `d:GLOBAL.S1` | — |
| `GLOBAL.ADR0012-GATE` | CLAIMED (orphaned — depends on the retracted `4x4.COMPLETE-2026-07-21`; re-point to the Track A writes-off artifact when complete. T128 triage §C1a-8) | `d:4x4.COMPLETE-2026-07-21` | — |
| `GLOBAL.ADR0012-PAR` | CLAIMED | `d:GLOBAL.FP1` · `d:GLOBAL.FP3` | — |
| `GLOBAL.ADR0012-5X5` | CLAIMED (projection; ADR status is *proposed*, measurements pending) | `d:GLOBAL.SWEEPS` · `d:GLOBAL.F4-COST` | — |
| `3x2.I5-CAL` | MEASUREMENT (with the not-reproduced verdicts stated) | `e:4x4.I5-FEAS` | — |
| `SPRINT-M4a-ACCEPT` | PROVEN (measured, denominators stated) | `d:CODE.WZO2-PASSBIT` | — |
| `WZO2-4X4-VALID` | FALSE-AS-SCOPED (as "valid"; the artifact is usable and internally consistent, but not a verified perfect oracle) | `d:CODE.WZO2-INCOMPLETE` | — |
| `GLOBAL.ADR0012-V1` | PROVEN | `d:GLOBAL.ADR0005-PASS` | — |
| `GLOBAL.ADR0009-SUCC` | PROVEN (design argument) | `d:GLOBAL.ADR0007-BACKEDGE` | — |
| `GLOBAL.ADR0014-PURE` | PROVEN | `d:GLOBAL.ADR0003-AREA` · `d:GLOBAL.S2` | — |
| `GLOBAL.F2-REMEDY` | CLAIMED | `d:QA-023` · `d:QA-023.M1` | — |
| `GLOBAL.ADR0014-DEAD` | CLAIMED | `d:GLOBAL.S2` | — |
| `GLOBAL.B15` | CLAIMED | `d:GLOBAL.F3` | — |
| `QA-001` | FALSE | `e:GLOBAL.CHAIN-KO` | — |
| `QA-002` | FALSE | `d:4x4.A-3` | — |
| `QA-003` | FALSE | `d:4x4.A-2` | — |
| `QA-004` | FALSE | `e:4x4.M5` · `e:4x4.BRACKET` | — |
| `QA-005` | FALSE | `e:4x4.M4` | — |
| `QA-006` | FALSE | `e:4x4.M6` | — |
| `QA-007` | CLAIMED | `d:4x4.M6-EXCESS` | — |
| `QA-008` | UNTESTED | `e:4x4.WRITESOFF` | — |
| `QA-009` | FALSE | `e:3x3.E2-RUN1` · `e:3x3.E2-RUN2` | — |
| `QA-010` | CLAIMED | `d:GLOBAL.ONEMISMATCH-DIAG` | — |
| `QA-011` | CLAIMED | `d:GLOBAL.H1-MARKOV` | — |
| `QA-012` | UNTESTED | `d:QA-023` · `d:QA-026` | — |
| `QA-013` | FALSE-AS-SCOPED | `d:GLOBAL.LONGCYCLE` | — |
| `QA-016` | FALSE | `e:4x4.PARALLEL` · `e:CODE.UNDEF` | — |
| `QA-017` | CLAIMED | `e:GLOBAL.CHAIN-KO` · `e:4x4.M4` | — |
| `QA-018` | CLAIMED | `d:GLOBAL.F2` · `e:GLOBAL.ADR0015-BURDEN` | — |
| `QA-020` | FALSE | `e:4x4.M5` · `e:GLOBAL.CHAIN-LH` | — |
| `QA-021` | PROVEN | `e:4x4.M4` | — |
| `QA-022` | FALSE | `e:3x2.T13` | — |
| `QA-025` | PROVEN | `d:GLOBAL.MIGOS-RULE` | — |
| `QA-027` | FALSE-AS-SCOPED (at 4×4; 3×3 measured 100.00%) | `d:QA-023` | — |
| `QA-028` | FALSE | `e:GLOBAL.RPLY` · `e:GLOBAL.RPLY-TRAP` | — |

## Isolated claims (49 of 303)

These claims have no recorded edges. They are either foundational
(nothing they depend on, nothing depends on them) or their edges
have not been recorded in the register.

| claim ID | status |
|---|---|
| `2x2.R3` | MEASUREMENT |
| `3x2.R3` | MEASUREMENT |
| `3x3.FWD-SPOT` | MEASUREMENT |
| `3x3.M1` | MEASUREMENT |
| `3x3.M4` | MEASUREMENT |
| `4x3.M2` | MEASUREMENT |
| `4x3.M4` | MEASUREMENT |
| `4x4.B39` | FALSE-AS-SCOPED (measurement artifact) |
| `4x4.DRIVER` | MEASUREMENT |
| `4x4.FP1-C1` | UNTESTED |
| `4x4.V1-INVSYM-BROKEN` | PROVEN (independent re-implementation, deduplicated count) |
| `CODE.ADR0011-DTT` | CLAIMED |
| `CODE.BATTERY-STUBBED` | PROVEN (source inspection + the stub output files) |
| `CODE.GTP-KOKEY` | PROVEN (root cause read in source, fix verified by transcript replay) |
| `CODE.M4A-HARNESS` | PROVEN (by inspection) |
| `CODE.S4-XVAL` | MEASUREMENT |
| `CODE.VB-BLINDGAPS` | PROVEN (blind-reimplementation audit, committed) |
| `CODE.VB-STUBS` | PROVEN (by inspection) |
| `CODE.WZO1-DTT-UNSET` | PROVEN (I7 across four gobans + independent spot-check + positive contrast artifact) |
| `CODE.WZO2-CHAINSHORT` | PROVEN (by inspection; the code is committed) |
| `CODE.WZO2-UNRUN` | PROVEN (by inspection, as of 2026-08-01 P2 delivery; **overtaken by events the same day** — the artifact was built and M4a ran, see `CODE.WZO2-PASSBIT`. The register has no status for "true when written, obsolete now"; the supersession is carried in the claim text) |
| `GLOBAL.ADR0002-SEQ` | UNTESTED |
| `GLOBAL.ADR0004-P1` | PROVEN |
| `GLOBAL.ADR0005-SUBBOARD` | PROVEN |
| `GLOBAL.ADR0007-AB` | PROVEN |
| `GLOBAL.ADR0007-TENSION` | CLAIMED (open in ADR-0007; resolved by `GLOBAL.ADR0009-NOEYE`, never recorded as such in ADR-0007) |
| `GLOBAL.ADR0009-DTT` | PROVEN |
| `GLOBAL.ADR0012-LAYER` | PROVEN (arithmetic) |
| `GLOBAL.AXIOM-CAPTURE` | CLAIMED |
| `GLOBAL.AXIOM-FRESHSTART` | CLAIMED |
| `GLOBAL.AXIOM-GEOM` | CLAIMED |
| `GLOBAL.AXIOM-STONE` | CLAIMED |
| `GLOBAL.AXIOM-SUICIDE` | CLAIMED |
| `GLOBAL.AXIOM-TIE` | CLAIMED |
| `GLOBAL.B-1` | FALSE-AS-SCOPED (as of the code at 2026-07-27) |
| `GLOBAL.CALIB-LESSON` | PROVEN (methodological) |
| `GLOBAL.CHAIN-DEF` | — (definition) |
| `GLOBAL.E1` | PROVEN (methodological) |
| `GLOBAL.FIN-NEARTERM` | MEASUREMENT |
| `GLOBAL.H3-LOWERBOUND` | MEASUREMENT |
| `GLOBAL.H4b` | UNTESTED |
| `GLOBAL.ONEWRITER` | CLAIMED |
| `GLOBAL.R3` | FALSE-AS-SCOPED |
| `GLOBAL.RELEASEFAST` | PROVEN |
| `GLOBAL.RNPLY-FORBID` | PROVEN |
| `GLOBAL.RPLY-RETRO` | CLAIMED |
| `GLOBAL.T14.1` | CLAIMED |
| `GLOBAL.Z` | CLAIMED |
| `QA-024` | CLAIMED |

*303 claims total; 254 with edges; 49 isolated.*