# INDEX — claim dependency tree (generated)

```
Task: INDEX-RETRIEVAL · Role: worker · Model: DSPro · Date: 2026-08-01
Sprint: project-restructure pass0 (T200)
Source: docs/epistemic/CLAIMS.md edges (97 d:, 11 n:, 91 e:)
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

## Claims with dependencies (222 of 274)

| claim ID | status | parents (why this depends) | children (what depends on this) |
|---|---|---|---|
| `GLOBAL.S2` | PROVEN | — | `e:3x3.S2-impl` · `e:4x4.S2-impl` · `e:4x3.S2-impl` · `d:4x3.S2` · `e:GLOBAL.ADR0006-PRED` · `d:GLOBAL.ADR0014-DEAD` |
| `GLOBAL.FP1` | PROVEN (as mathematics) | `d:GLOBAL.FP3` | `e:2x2.B1` · `e:3x2.B1` · `e:3x3.B1` · `d:GLOBAL.B1-AUDIT` · `d:4x3.FP1` · `d:GLOBAL.FP2` |
| `GLOBAL.INVSYM` | PROVEN | — | `d:GLOBAL.E2-POLICY` · `e:2x2.F2` · `e:GLOBAL.MEMO-XROOT` · `d:GLOBAL.P2` · `e:4x4.REGR-SYM` · `e:2x2.EXACT` |
| `GLOBAL.AUDITOR` | PROVEN | — | `e:3x2.F1` · `e:3x2.F3` · `e:3x2.F4` · `e:3x3.F4` · `e:4x3.F4` |
| `4x4.M4` | MEASUREMENT | `e:4x4.PARALLEL` | `e:4x4.FP1-C3` · `e:4x4.REGR-CLIFF` · `e:4x4.A-3` · `e:QA-005` · `e:QA-021` |
| `GLOBAL.F1` | FALSE-AS-SCOPED | `d:GLOBAL.ADR0005-CACHE` | `n:4x4.F1` · `n:4x3.F1` · `e:4x4.M3` · `n:GLOBAL.H3` |
| `GLOBAL.S3a` | PROVEN (as scoped) | — | `e:4x3.S3a` · `e:GLOBAL.H1-CENSUS` · `e:3x3.H1-CENSUS` |
| `GLOBAL.S4` | PROVEN | — | `d:4x4.S4` · `d:4x3.S4` · `d:GLOBAL.ADR0005-DBLPASS` |
| `GLOBAL.FP2` | CLAIMED | `d:GLOBAL.FP1` | `d:GLOBAL.FP2-bounded` · `d:GLOBAL.FP2-general` · `d:GLOBAL.CERTCORE` |
| `GLOBAL.FP2-bounded` | FALSE-AS-SCOPED (at 3×2) | `d:GLOBAL.FP2` | `d:GLOBAL.C2` · `d:3x3.C2` · `d:4x3.C2` |
| `GLOBAL.FP3` | PROVEN | — | `d:GLOBAL.FP1` · `d:4x4.FP3` · `d:4x3.FP3` |
| `GLOBAL.C2` | FALSE-AS-SCOPED (at 3×2) | `d:GLOBAL.FP2-bounded` | `d:GLOBAL.C4` · `n:GLOBAL.CHAIN-KIND` · `n:GLOBAL.H5d` |
| `GLOBAL.C3` | FALSE-AS-SCOPED (at 3×3) | `d:GLOBAL.FP2,` | `d:4x3.C3` · `d:GLOBAL.ADR0010-CUT` · `n:GLOBAL.ADR0015-BURDEN` |
| `GLOBAL.C4` | FALSE-AS-SCOPED | `d:GLOBAL.C2` | `n:GLOBAL.LEAK` · `d:GLOBAL.P1` · `e:4x4.B16-GAME` |
| `GLOBAL.REFRAME` | CLAIMED (adopted decision) | `n:GLOBAL.C2,` | `d:GLOBAL.UD-1` · `d:GLOBAL.UD-2` · `d:GLOBAL.UD-3` |
| `4x4.M1` | MEASUREMENT | `e:4x4.S3a,` | `e:4x4.R3` · `e:4x4.KO-CENSUS` · `e:4x4.SINGLE` |
| `GLOBAL.S1` | PROVEN | — | `e:4x4.S1` · `d:4x3.S1` |
| `4x3.S3a` | PROVEN | `e:GLOBAL.S3a` | `e:4x3.M1` · `e:4x3.H1-CENSUS` |
| `GLOBAL.S3b` | CLAIMED | — | `d:4x4.S3b` · `d:4x3.S3b` |
| `GLOBAL.ADR0005-CACHE` | FALSE-AS-SCOPED | — | `n:GLOBAL.ADR0008-HOLE` · `d:GLOBAL.F1` |
| `GLOBAL.F2` | CLAIMED | `d:GLOBAL.C3,` | `d:3x3.C1` · `d:4x3.F2` |
| `GLOBAL.ADR0010-CUT` | CLAIMED | `d:GLOBAL.C3` | `e:4x4.HISTPERF-CHEAP` · `e:GLOBAL.FIN-BRACKET` |
| `GLOBAL.F3` | CLAIMED | `d:GLOBAL.C3,` | `d:GLOBAL.F4` · `d:GLOBAL.B15` |
| `GLOBAL.R1` | PROVEN (structural) | `d:GLOBAL.S3b,` | `d:GLOBAL.PSK-GAP` · `d:GLOBAL.FWD-INTRACT` |
| `GLOBAL.R2` | PROVEN (argument) + MEASUREMENT | `e:2x2.R1,` | `d:GLOBAL.RPLY-TRAP` · `d:GLOBAL.LONGCYCLE` |
| `GLOBAL.CHAIN-KO` | PROVEN | `e:2x2.M4…e:4x4.M4` | `e:4x4.A-2` · `e:QA-001` |
| `4x4.M6` | MEASUREMENT | `e:4x4.M4,` | `d:4x4.M6-SCREEN` · `e:QA-006` |
| `GLOBAL.LONGCYCLE` | FALSE-AS-SCOPED | `d:GLOBAL.R2` | `d:GLOBAL.H1-COMPUTABLE` · `d:QA-013` |
| `4x4.A-3` | FALSE-AS-SCOPED (the player is not fresh-start-perfect in the ko-sensitive region: node's own V0 = −3, chosen child = −16) | `e:4x4.M4` | `n:GLOBAL.H5a-CHILD` · `d:QA-002` |
| `2x2.B1` | CLAIMED | `e:GLOBAL.FP1` | `e:2x2.C3` |
| `3x2.B1` | CLAIMED | `e:GLOBAL.FP1` | `e:3x2.C3` |
| `3x3.B1` | CLAIMED | `e:GLOBAL.FP1` | `e:3x3.BRACKET` |
| `4x4.FP1` | UNTESTED (checks 1–2); check 3 PASSES | `d:GLOBAL.FP1,` | `e:4x4.BRACKET` |
| `4x4.FP1-C3` | PROVEN (as scoped) | `e:4x4.M4` | `d:GLOBAL.H4` |
| `4x3.FP1` | CLAIMED | `d:GLOBAL.FP1` | `e:4x3.BRACKET` |
| `GLOBAL.ADR0009-HONESTY` | PROVEN (as a statement about the argument) | — | `d:GLOBAL.ADR0010-SOUND` |
| `3x2.T13` | PROVEN (falsification) | `e:3x2.C1,` | `e:QA-022` |
| `3x3.F2` | MEASUREMENT | `e:3x3.B1,` | `e:3x3.ANCHOR` |
| `GLOBAL.F4` | PROVEN (argument) + MEASUREMENT | `d:GLOBAL.F3` | `e:GLOBAL.F4-COST` |
| `GLOBAL.ADR0009-NOEYE` | PROVEN | — | `d:GLOBAL.ADR0006-TEST` |
| `GLOBAL.ADR0005-PASS` | PROVEN | — | `d:GLOBAL.ADR0012-V1` |
| `GLOBAL.P1` | FALSE-AS-SCOPED | `d:GLOBAL.C4` | `e:4x4.ANCHOR` |
| `GLOBAL.P2` | PROVEN (as scoped) | `d:GLOBAL.INVSYM` | `d:CODE.ADR0011-GATE` |
| `4x4.B43` | MEASUREMENT | `e:CODE.UNDEF,` | `e:4x4.B43-DIV` |
| `4x4.KO-RULE-NULL` | PROVEN (these two games) | — | `e:4x4.A-1` |
| `4x4.GTP-DEFECT` | PROVEN | `d:4x4.CHAIN-KO,` | `d:GLOBAL.H5` |
| `GLOBAL.MIGOS-RULE` | PROVEN | — | `d:QA-025` |
| `4x4.M6-EXCESS` | CLAIMED | `d:4x4.F1,` | `d:QA-007` |
| `4x4.WRITESOFF` | MEASUREMENT | — | `e:QA-008` |
| `4x4.M2` | MEASUREMENT | — | `e:4x4.FP1-C2` |
| `4x4.BRACKET` | MEASUREMENT | `e:4x4.FP1` | `e:4x4.TANGLE` |
| `4x4.COMPLETE-2026-07-21` | FALSE-AS-SCOPED | `d:GLOBAL.F1,` | `d:GLOBAL.ADR0012-GATE` |
| `4x4.PARALLEL` | MEASUREMENT | — | `e:4x4.M4` |
| `4x3.M3` | MEASUREMENT | — | `e:4x4.D3` |
| `4x3.BRACKET` | MEASUREMENT | `e:4x3.FP1` | `e:4x3.TANGLE` |
| `2x2.EXACT` | MEASUREMENT | `e:GLOBAL.INVSYM` | `e:2x2.T12` |
| `GLOBAL.PASS-NOKO` | PROVEN (code + independent re-derivation) | — | `d:4x4.I5-FEAS` |
| `GLOBAL.H1-MARKOV` | UNTESTED | `n:GLOBAL.C2,` | `d:QA-011` |
| `GLOBAL.H1-COMPUTABLE` | FALSE-AS-SCOPED | `d:GLOBAL.LONGCYCLE` | `d:GLOBAL.ONEMISMATCH-CURE` |
| `GLOBAL.ONEMISMATCH-DIAG` | CLAIMED | — | `d:QA-010` |
| `4x4.A-2` | FALSE-AS-SCOPED (category error — every blundering node is KO_SENSITIVE, i.e. outside C2's scope) | `e:GLOBAL.CHAIN-KO` | `d:QA-003` |
| `4x4.I5-FEAS` | CLAIMED (projection; the calibration section is MEASUREMENT) | `d:GLOBAL.PASS-NOKO` | `e:3x2.I5-CAL` |
| `GLOBAL.ADR0007-BACKEDGE` | PROVEN | — | `d:GLOBAL.ADR0009-SUCC` |
| `4x4.D3` | UNTESTED | `e:4x3.M3` | `d:GLOBAL.H4a` |
| `QA-015` | CLAIMED (**DECIDED 2026-07-28** — D-2, Opus + GLM; the rule now lives in ADR-0016, and `mixed` was **not** ruled on) | — | `e:GLOBAL.ADR0016-INHERIT` |
| `QA-023` | CLAIMED | — | `d:QA-027` |
| `4x4.S1` | PROVEN | `e:GLOBAL.S1` | — |
| `4x3.S1` | PROVEN | `d:GLOBAL.S1` | — |
| `3x3.S2-impl` | PROVEN | `e:GLOBAL.S2` | — |
| `4x4.S2-impl` | UNTESTED | `e:GLOBAL.S2` | — |
| `4x3.S2-impl` | UNTESTED | `e:GLOBAL.S2` | — |
| `4x3.S2` | PROVEN | `d:GLOBAL.S2` | — |
| `4x4.S3a` | PROVEN | `e:GLOBAL.S3a,` | — |
| `4x4.S3b` | UNTESTED | `d:GLOBAL.S3b` | — |
| `4x3.S3b` | UNTESTED | `d:GLOBAL.S3b` | — |
| `4x4.S4` | UNTESTED (`⬜ᴵᴺᴴ`) | `d:GLOBAL.S4` | — |
| `4x3.S4` | UNTESTED (`⬜ᴵᴺᴴ`) | `d:GLOBAL.S4` | — |
| `GLOBAL.B1-MULTIFIX` | MEASUREMENT | `e:2x2.B1,` | — |
| `GLOBAL.B1-AUDIT` | PROVEN | `d:GLOBAL.FP1` | — |
| `4x4.FP1-C2` | UNTESTED | `e:4x4.M2` | — |
| `GLOBAL.FP2-general` | INTRACTABLE (possibly unprovable by finite methods) | `d:GLOBAL.FP2` | — |
| `4x4.FP3` | UNTESTED (`⬜ᴵᴺᴴ`) | `d:GLOBAL.FP3` | — |
| `4x3.FP3` | PROVEN | `d:GLOBAL.FP3` | — |
| `GLOBAL.CERTCORE` | FALSE-AS-SCOPED | `d:GLOBAL.FP2` | — |
| `2x2.C1` | PROVEN | `e:2x2.EXACT,` | — |
| `3x2.C1` | PROVEN | `e:3x2.EXACT,` | — |
| `3x3.C1` | CLAIMED | `d:GLOBAL.F2` | — |
| `4x3.C1` | CLAIMED | `d:4x3.F2,` | — |
| `4x4.C1` | UNTESTED | `d:4x4.F2,` | — |
| `2x2.T12` | MEASUREMENT | `e:2x2.EXACT` | — |
| `3x3.C2` | UNTESTED | `d:GLOBAL.FP2-bounded` | — |
| `4x3.C2` | UNTESTED | `d:GLOBAL.FP2-bounded` | — |
| `4x4.C2` | UNTESTED (status conflict, §6-D3) | `d:GLOBAL.FP2-bounded,` | — |
| `2x2.C3` | MEASUREMENT | `e:2x2.B1` | — |
| `3x2.C3` | MEASUREMENT | `e:3x2.B1` | — |
| `3x3.C3` | PROVEN (falsification) | `e:3x3.B1,` | — |
| `4x3.C3` | UNTESTED | `d:GLOBAL.C3` | — |
| `4x4.C3` | UNTESTED (status conflict, §6-D2) | `d:GLOBAL.C3,` | — |
| `GLOBAL.LEAK` | PROVEN | `n:GLOBAL.C4` | — |
| `GLOBAL.E2-POLICY` | PROVEN (bug + fix) | `d:GLOBAL.INVSYM` | — |
| `GLOBAL.E2-VERDICT` | CLAIMED | `d:3x3.B1,` | — |
| `3x3.E2-RUN1` | MEASUREMENT | `e:GLOBAL.E2-POLICY,` | — |
| `3x3.E2-RUN2` | MEASUREMENT | `e:GLOBAL.E2-POLICY,` | — |
| `GLOBAL.ADR0008-HOLE` | PROVEN (as a statement about the argument) | `n:GLOBAL.ADR0005-CACHE` | — |
| `3x2.F1` | PROVEN (falsification) | `e:GLOBAL.AUDITOR` | — |
| `4x4.F1` | CLAIMED | `n:GLOBAL.F1` | — |
| `4x3.F1` | CLAIMED | `n:GLOBAL.F1` | — |
| `GLOBAL.ADR0010-SOUND` | PROVEN (as a statement about the argument) | `d:GLOBAL.ADR0009-HONESTY` | — |
| `2x2.F2` | MEASUREMENT | `e:GLOBAL.INVSYM` | — |
| `4x3.F2` | UNTESTED | `d:GLOBAL.F2` | — |
| `4x4.F2` | UNTESTED | `d:GLOBAL.F2,` | — |
| `3x2.F3` | PROVEN (necessary condition) | `e:GLOBAL.AUDITOR` | — |
| `4x4.F3` | UNTESTED | `d:GLOBAL.F3,` | — |
| `3x2.F4` | PROVEN | `e:GLOBAL.AUDITOR` | — |
| `3x3.F4` | PROVEN | `e:GLOBAL.AUDITOR` | — |
| `4x3.F4` | PROVEN | `e:GLOBAL.AUDITOR` | — |
| `4x4.F4` | UNTESTED | `d:GLOBAL.F4,` | — |
| `GLOBAL.F4-COST` | MEASUREMENT | `e:GLOBAL.F4` | — |
| `GLOBAL.MEMO-XROOT` | PROVEN (falsification) | `e:GLOBAL.INVSYM` | — |
| `GLOBAL.ADR0006-EYE` | CLAIMED | `d:GLOBAL.S2,` | — |
| `GLOBAL.ADR0006-PRED` | PROVEN | `e:GLOBAL.S2` | — |
| `GLOBAL.ADR0006-LEMMAS` | PROVEN (per goban listed) | `e:GLOBAL.S2,` | — |
| `GLOBAL.ADR0006-TEST` | PROVEN (executed 2026-07-30, scoped) | `d:GLOBAL.ADR0009-NOEYE` | — |
| `GLOBAL.ADR0006-PRUNEALL` | PROVEN (per goban listed) | `d:GLOBAL.ADR0006-EYE,` | — |
| `GLOBAL.ADR0004-TERM` | PROVEN | `d:GLOBAL.S2,` | — |
| `GLOBAL.ADR0005-DBLPASS` | CLAIMED (argued, not machine-checked) | `d:GLOBAL.S4` | — |
| `GLOBAL.P3` | FALSE-AS-SCOPED | `d:GLOBAL.C4,` | — |
| `4x4.P3` | MEASUREMENT | `e:2x2.C1,` | — |
| `GLOBAL.T06` | MEASUREMENT | `e:2x2.C1,` | — |
| `4x4.B43-DIV` | MEASUREMENT | `e:4x4.B43` | — |
| `4x4.M5` | PROVEN | `e:4x4.M4,` | — |
| `4x4.GREEDY-BIAS` | CLAIMED | `d:4x4.GTP-DEFECT,` | — |
| `4x4.REGR-SYM` | PROVEN | `e:GLOBAL.INVSYM` | — |
| `4x4.REGR-CLIFF` | MEASUREMENT | `e:4x4.M4` | — |
| `4x4.B16-GAME` | MEASUREMENT | `e:GLOBAL.C4` | — |
| `4x4.HISTPERF-CHEAP` | MEASUREMENT | `e:GLOBAL.ADR0010-CUT` | — |
| `4x4.R1` | CLAIMED | `d:GLOBAL.R1,` | — |
| `4x4.R3` | PROVEN (falsification) | `e:4x4.M1` | — |
| `GLOBAL.RPLY-TRAP` | PROVEN (argument) | `d:GLOBAL.R2` | — |
| `GLOBAL.ANCHOR-DELTA` | CLAIMED | `d:GLOBAL.MIGOS-RULE,` | — |
| `GLOBAL.UD-1` | CLAIMED | `d:GLOBAL.REFRAME` | — |
| `GLOBAL.UD-2` | CLAIMED | `d:GLOBAL.REFRAME` | — |
| `GLOBAL.UD-3` | CLAIMED | `d:GLOBAL.REFRAME` | — |
| `GLOBAL.PSK-GAP` | PROVEN | `d:GLOBAL.R1` | — |
| `GLOBAL.CHAIN-LH` | PROVEN (on the audited artifacts) | `e:2x2.M4…e:4x4.M4` | — |
| `GLOBAL.CHAIN-KIND` | PROVEN | `n:GLOBAL.C2` | — |
| `GLOBAL.MAXGAP` | CLAIMED | `e:2x2.M4…e:4x4.M4` | — |
| `4x4.M6-FLOOR` | PROVEN (on the swept artifact) | `d:GLOBAL.CHAIN-KIND,` | — |
| `4x4.M6-SCREEN` | CLAIMED | `d:4x4.M6` | — |
| `4x4.KO-CENSUS` | MEASUREMENT | `e:4x4.M1` | — |
| `4x4.M3` | MEASUREMENT | `e:GLOBAL.F1` | — |
| `4x4.SINGLE` | MEASUREMENT | `e:4x4.M1` | — |
| `4x4.TANGLE` | MEASUREMENT | `e:4x4.BRACKET` | — |
| `4x4.ANCHOR` | MEASUREMENT | `e:GLOBAL.P1` | — |
| `4x4.CYCLE-INSENS` | CLAIMED | `d:GLOBAL.MIGOS-RULE,` | — |
| `4x4.VALBATTERY` | MEASUREMENT | `e:GLOBAL.P2,` | — |
| `4x3.M1` | MEASUREMENT | `e:4x3.S3a` | — |
| `4x3.TANGLE` | MEASUREMENT | `e:4x3.BRACKET` | — |
| `3x3.BRACKET` | MEASUREMENT | `e:3x3.B1` | — |
| `3x3.ANCHOR` | MEASUREMENT | `e:3x3.F2` | — |
| `GLOBAL.FWD-INTRACT` | PROVEN | `d:GLOBAL.R1` | — |
| `GLOBAL.FIN-BRACKET` | MEASUREMENT | `e:GLOBAL.ADR0010-CUT` | — |
| `2x2.BASICKO-TIE` | MEASUREMENT | `e:GLOBAL.INVSYM,` | — |
| `3x2.BASICKO-TIE` | MEASUREMENT | `e:GLOBAL.INVSYM,` | — |
| `3x3.BASICKO-TIE` | MEASUREMENT | `e:GLOBAL.INVSYM,` | — |
| `4x4.BASICKO-TIE` | MEASUREMENT | `e:GLOBAL.MIGOS-RULE,` | — |
| `GLOBAL.H1-CENSUS` | PROVEN | `e:GLOBAL.S3a` | — |
| `3x3.H1-CENSUS` | PROVEN | `e:GLOBAL.S3a` | — |
| `4x3.H1-CENSUS` | PROVEN | `e:4x3.S3a` | — |
| `4x4.G-CENSUS` | MEASUREMENT | `e:GLOBAL.H1-CENSUS,` | — |
| `GLOBAL.H2` | UNTESTED | `d:4x4.GREEDY-BIAS,` | — |
| `GLOBAL.H3` | UNTESTED | `n:GLOBAL.F1` | — |
| `GLOBAL.H4` | CLAIMED (partial) | `d:4x4.FP1-C3` | — |
| `GLOBAL.H4a` | UNTESTED | `d:4x4.D3` | — |
| `GLOBAL.H5` | CLAIMED | `d:4x4.GTP-DEFECT` | — |
| `GLOBAL.H5a` | CLAIMED | `d:GLOBAL.CHAIN-LH,` | — |
| `GLOBAL.H5a-CHILD` | CLAIMED | `n:4x4.A-3` | — |
| `GLOBAL.H5a-FALLBACK` | CLAIMED | `d:GLOBAL.S2,` | — |
| `GLOBAL.H5b` | CLAIMED | `d:GLOBAL.S2,` | — |
| `GLOBAL.H5c` | PROVEN (as an implication) | `d:GLOBAL.C3,` | — |
| `GLOBAL.H5d` | CLAIMED | `n:GLOBAL.C2` | — |
| `GLOBAL.ONEMISMATCH-CURE` | FALSE-AS-SCOPED | `d:GLOBAL.H1-COMPUTABLE` | — |
| `4x4.A-1` | FALSE-AS-SCOPED | `e:4x4.KO-RULE-NULL` | — |
| `GLOBAL.C-1` | FALSE-AS-SCOPED | `e:2x2.M4,` | — |
| `CODE.ADR0011-GATE` | PROVEN | `d:GLOBAL.P2` | — |
| `GLOBAL.ADR0012-GATE` | CLAIMED (orphaned — depends on the retracted `4x4.COMPLETE-2026-07-21`; re-point to the Track A writes-off artifact when complete. T128 triage §C1a-8) | `d:4x4.COMPLETE-2026-07-21` | — |
| `GLOBAL.ADR0012-PAR` | CLAIMED | `d:GLOBAL.FP1,` | — |
| `GLOBAL.ADR0012-5X5` | CLAIMED (projection; ADR status is *proposed*, measurements pending) | `d:GLOBAL.SWEEPS,` | — |
| `3x2.I5-CAL` | MEASUREMENT (with the not-reproduced verdicts stated) | `e:4x4.I5-FEAS` | — |
| `GLOBAL.ADR0012-V1` | PROVEN | `d:GLOBAL.ADR0005-PASS` | — |
| `GLOBAL.ADR0009-SUCC` | PROVEN (design argument) | `d:GLOBAL.ADR0007-BACKEDGE` | — |
| `GLOBAL.ADR0014-PURE` | PROVEN | `d:GLOBAL.ADR0003-AREA,` | — |
| `GLOBAL.ADR0016-INHERIT` | CLAIMED (adopted rule — a decision, not a fact) | `e:QA-015` | — |
| `GLOBAL.ADR0015-BURDEN` | CLAIMED | `n:GLOBAL.C3` | — |
| `GLOBAL.F2-REMEDY` | CLAIMED | `d:QA-023,` | — |
| `GLOBAL.ADR0014-DEAD` | CLAIMED | `d:GLOBAL.S2` | — |
| `GLOBAL.B15` | CLAIMED | `d:GLOBAL.F3` | — |
| `QA-001` | FALSE | `e:GLOBAL.CHAIN-KO` | — |
| `QA-002` | FALSE | `d:4x4.A-3` | — |
| `QA-003` | FALSE | `d:4x4.A-2` | — |
| `QA-004` | FALSE | `e:4x4.M5,` | — |
| `QA-005` | FALSE | `e:4x4.M4` | — |
| `QA-006` | FALSE | `e:4x4.M6` | — |
| `QA-007` | CLAIMED | `d:4x4.M6-EXCESS` | — |
| `QA-008` | UNTESTED | `e:4x4.WRITESOFF` | — |
| `QA-009` | FALSE | `e:3x3.E2-RUN1,` | — |
| `QA-010` | CLAIMED | `d:GLOBAL.ONEMISMATCH-DIAG` | — |
| `QA-011` | CLAIMED | `d:GLOBAL.H1-MARKOV` | — |
| `QA-012` | UNTESTED | `d:QA-023,` | — |
| `QA-013` | FALSE-AS-SCOPED | `d:GLOBAL.LONGCYCLE` | — |
| `QA-014` | UNTESTED | `d:GLOBAL.CHAIN-LH,` | — |
| `QA-016` | FALSE | `e:4x4.PARALLEL,` | — |
| `QA-017` | CLAIMED | `e:GLOBAL.CHAIN-KO,` | — |
| `QA-018` | CLAIMED | `d:GLOBAL.F2,` | — |
| `QA-019` | FALSE | `e:GLOBAL.F3,` | — |
| `QA-020` | FALSE | `e:4x4.M5,` | — |
| `QA-021` | PROVEN | `e:4x4.M4` | — |
| `QA-022` | FALSE | `e:3x2.T13` | — |
| `QA-025` | PROVEN | `d:GLOBAL.MIGOS-RULE` | — |
| `QA-026` | FALSE-AS-SCOPED | `d:QA-023,` | — |
| `QA-027` | FALSE-AS-SCOPED (at 4×4; 3×3 measured 100.00%) | `d:QA-023` | — |
| `QA-028` | FALSE | `e:GLOBAL.RPLY,` | — |

## Isolated claims (52 of 274)

These claims have no recorded edges. They are either foundational
(nothing they depend on, nothing depends on them) or their edges
have not been recorded in the register.

| claim ID | status |
|---|---|
| `2x2.M4` | MEASUREMENT |
| `2x2.R1` | MEASUREMENT |
| `2x2.R3` | MEASUREMENT |
| `3x2.EXACT` | MEASUREMENT |
| `3x2.M4` | MEASUREMENT |
| `3x2.R1` | MEASUREMENT |
| `3x2.R3` | MEASUREMENT |
| `3x3.E3` | PROVEN |
| `3x3.FWD-SPOT` | MEASUREMENT |
| `3x3.M1` | MEASUREMENT |
| `3x3.M4` | MEASUREMENT |
| `4x3.M2` | MEASUREMENT |
| `4x3.M4` | MEASUREMENT |
| `4x4.B39` | FALSE-AS-SCOPED (measurement artifact) |
| `4x4.DRIVER` | MEASUREMENT |
| `4x4.FP1-C1` | UNTESTED |
| `CODE.ADR0011-DTT` | CLAIMED |
| `CODE.ADR0011-FMT` | vw\ |
| `CODE.M4A-HARNESS` | PROVEN (by inspection) |
| `CODE.S4-XVAL` | MEASUREMENT |
| `CODE.UNDEF` | PROVEN |
| `CODE.VB-BLINDGAPS` | PROVEN (blind-reimplementation audit, committed) |
| `CODE.VB-STUBS` | PROVEN (by inspection) |
| `CODE.WZO2-CHAINSHORT` | PROVEN (by inspection; the code is committed) |
| `CODE.WZO2-UNRUN` | PROVEN (by inspection) |
| `GLOBAL.ADR0002-SEQ` | UNTESTED |
| `GLOBAL.ADR0003-AREA` | PROVEN |
| `GLOBAL.ADR0004-P1` | PROVEN |
| `GLOBAL.ADR0005-SUBBOARD` | PROVEN |
| `GLOBAL.ADR0007-AB` | PROVEN |
| `GLOBAL.ADR0007-TENSION` | CLAIMED (open in ADR-0007; resolved by `GLOBAL.ADR0009-NOEYE`, never recorded as such in ADR-0007) |
| `GLOBAL.ADR0009-DTT` | PROVEN |
| `GLOBAL.ADR0012-LAYER` | PROVEN (arithmetic) |
| `GLOBAL.B-1` | FALSE-AS-SCOPED (as of the code at 2026-07-27) |
| `GLOBAL.BRUTE-ALIASING` | FALSE (methodological) |
| `GLOBAL.C1` | — (definition) |
| `GLOBAL.CALIB-LESSON` | PROVEN (methodological) |
| `GLOBAL.CHAIN-DEF` | — (definition) |
| `GLOBAL.E1` | PROVEN (methodological) |
| `GLOBAL.E2-SANITY` | PROVEN |
| `GLOBAL.FIN-NEARTERM` | MEASUREMENT |
| `GLOBAL.H3-LOWERBOUND` | MEASUREMENT |
| `GLOBAL.H4b` | UNTESTED |
| `GLOBAL.ONEWRITER` | CLAIMED |
| `GLOBAL.R3` | FALSE-AS-SCOPED |
| `GLOBAL.RELEASEFAST` | PROVEN |
| `GLOBAL.RNPLY-FORBID` | PROVEN |
| `GLOBAL.RPLY` | PROVEN (falsification) |
| `GLOBAL.RPLY-RETRO` | CLAIMED |
| `GLOBAL.SWEEPS` | MEASUREMENT |
| `GLOBAL.T14.1` | CLAIMED |
| `QA-024` | CLAIMED |

*274 claims total; 222 with edges; 52 isolated.*