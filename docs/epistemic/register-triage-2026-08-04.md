# Register triage — what is a claim, what is a note, what is archaeology

Task: T354 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-05
Commit: HEAD `f623a67` · register `docs/epistemic/CLAIMS.md` §2 lines 214–671 · claimlint `95b2eff` built 2026-08-05T11:07:17Z

**This is a proposal sheet. Nothing is moved, edited, promoted or demoted by
this task.** The Orchestrator rules on the sheet (same shape as T324's
retirement sheet, which worked). The register, the tree-map, the claimlint
floor and the calibration fixtures are all untouched by T354.

## The filter, applied mechanically first

`docs/epic-01-markovian/register-tree-map.md` maps every register row onto the
requirement tree descending from theorem Z. The machine-checked mapping
(claimlint C9, floor 0, PASS at HEAD) says: **334 rows — 211 mapped to a node,
123 carrying the disposition marker `RETIRED`**. A row that maps to no tree
node is not a claim. The 123 `RETIRED` rows were classified into
NOTE / ARCHAEOLOGY / BOGUS / DISPUTED; the 211 mapped rows are LIVE unless
their foundation was falsified (the C1a ORPHANED family) — those are BOGUS.

Denominators, each with its command:

| count | value | how measured |
|---|---|---|
| register rows | **334** | `bin/weizigo-claimlint` C0 (`rows parsed: 334`) at HEAD before this task |
| mapped to a node | **211** | claimlint C9 (register rows: 334 · mapping doc rows: 334 · node mismatches: 0) |
| `RETIRED` disposition | **123** | same C9 run (211 mapped + 123 RETIRED = 334) |
| C1a ORPHANED | **10** | same run (C1a orphans: 10) |
| C3 PROVEN w/o committed evidence | **76** | same run (76 of 100 PROVEN rows, Tier B) |
| C4 dangling IDs / unreferenced | **46 / 2** | same run (brief's 2026-08-04 figure was 39 / 2 — the register has grown 11 rows since; see Findings) |
| classified in this sheet | **334** | the table below — every row, one class each |

## 1. The classification — every register row

Columns: **class** · register **status** (as parsed at HEAD) · **rationale**.
For LIVE rows the evidence status is embedded in the rationale:
`ev committed` = a re-runnable probe or its output under `docs/evidence/`
(or a committed findings/audit record); `ev prose-only` = committed prose
records the result but no probe; `ev lost` = primary evidence was under
git-ignored `untracked/` and is gone (the row has already paid for it with a
demotion where applicable).

| ID | class | status | rationale |
|---|---|---|---|
| `GLOBAL.S1` | LIVE | PROVEN | Z-STATE-LEGAL · ev prose-only; grounds: trivial exhaustive colex round-trip probe |
| `4x4.S1` | LIVE | PROVEN | Z-STATE-LEGAL · ev prose-only; grounds: exhaustive round-trip probe through 4x4 |
| `4x3.S1` | LIVE | PROVEN | Z-STATE-LEGAL · ev prose-only; grounds: round-trip probe at 4x3 |
| `GLOBAL.S2` | LIVE | PROVEN | Z-R-SCORE · ev committed |
| `3x3.S2-impl` | LIVE | PROVEN | Z-R-SCORE · ev prose-only; grounds: re-run the Benson falsification-confirmation probe |
| `4x4.S2-impl` | LIVE | UNTESTED | Z-R-SCORE · ev prose-only |
| `4x3.S2-impl` | LIVE | UNTESTED | Z-R-SCORE · ev prose-only |
| `4x3.S2` | LIVE | PROVEN | Z-R-SCORE · ev prose-only; grounds: Benson theorem at 4x3 — inherits committed GLOBAL.S2 |
| `GLOBAL.S3a` | LIVE | PROVEN (as scoped) | Z-STATE-LEGAL · ev prose-only; grounds: census-enumerator re-run (OEIS A094777 known-good) |
| `4x4.S3a` | LIVE | PROVEN | Z-STATE-LEGAL · ev prose-only; grounds: census-enumerator re-run (24,318,165 = A094777) |
| `4x3.S3a` | LIVE | PROVEN | Z-STATE-LEGAL · ev prose-only; grounds: census-enumerator re-run (321,689, reproduced by 4x3.H1-CENSUS) |
| `GLOBAL.S3b` | ARCHAEOLOGY | CLAIMED | [ruleset-choice] ko-legality under PSK history — evidences the k=1 choice only |
| `4x4.S3b` | ARCHAEOLOGY | UNTESTED | [ruleset-choice] PSK-history ko-legality at 4×4 — evidences the k=1 choice |
| `4x3.S3b` | ARCHAEOLOGY | UNTESTED | [ruleset-choice] PSK-history ko-legality at 4×3 — evidences the k=1 choice |
| `GLOBAL.S4` | LIVE | PROVEN | Z-R-SCORE · ev committed |
| `4x4.S4` | LIVE | UNTESTED (`⬜ᴵᴺᴴ`) | Z-R-SCORE · ev prose-only |
| `4x3.S4` | LIVE | UNTESTED (`⬜ᴵᴺᴴ`) | Z-R-SCORE · ev prose-only |
| `CODE.S4-XVAL` | LIVE | MEASUREMENT | Z-R-SCORE · ev prose-only |
| `GLOBAL.Z-R-MOVE-B1-EQUIV` | LIVE | CLAIMED | Z-R-MOVE · ev committed |
| `GLOBAL.FP1` | LIVE | PROVEN (as mathematics) | Z-CONVERGE-MONO · ev committed |
| `2x2.B1` | LIVE | CLAIMED | Z-CONVERGE-FIX · primary evidence (untracked/T02-minimax.md) lost; already demoted PROVEN→CLAIMED 2026-07-29 |
| `3x2.B1` | LIVE | CLAIMED | Z-CONVERGE-FIX · same as 2x2.B1 |
| `3x3.B1` | LIVE | CLAIMED | Z-CONVERGE-FIX · same as 2x2.B1 |
| `GLOBAL.B1-MULTIFIX` | LIVE | MEASUREMENT | Z-CONVERGE-MONO · ev prose-only |
| `GLOBAL.B1-AUDIT` | LIVE | PROVEN | Z-CONVERGE-MONO · ev prose-only; grounds: commit the multi-fixpoint observation as a probe |
| `4x4.FP1` | LIVE | UNTESTED (checks 1–2); check 3 PASSES | Z-CONVERGE-FIX · ev prose-only |
| `4x4.FP1-C1` | LIVE | UNTESTED | Z-CONVERGE-SEED · ev prose-only |
| `4x4.FP1-C2` | LIVE | UNTESTED | Z-CONVERGE-FINITE · ev prose-only |
| `4x4.FP1-C3` | LIVE | PROVEN (as scoped) | Z-CONVERGE-FIX · ev prose-only; grounds: re-point to QA-021 (already the exhaustive upgrade) + commit log |
| `4x3.FP1` | LIVE | CLAIMED | Z-CONVERGE-FIX · ev prose-only |
| `GLOBAL.FP2` | LIVE | CLAIMED | Z-NONCLAIMS · ev prose-only |
| `GLOBAL.FP2-bounded` | LIVE | FALSE-AS-SCOPED (at 3×2) | Z-NONCLAIMS · ev prose-only |
| `GLOBAL.FP2-general` | LIVE | INTRACTABLE (possibly unprovable by finite m… | Z-NONCLAIMS · ev prose-only |
| `GLOBAL.FP3` | LIVE | PROVEN | Z-CONVERGE-FINITE · ev prose-only; grounds: finite-lattice argument + per-goban sweep records |
| `4x4.FP3` | LIVE | UNTESTED (`⬜ᴵᴺᴴ`) | Z-CONVERGE-FINITE · ev prose-only |
| `4x3.FP3` | LIVE | PROVEN | Z-CONVERGE-FINITE · ev prose-only; grounds: argument + 4x3.M2 sweep record |
| `GLOBAL.CERTCORE` | LIVE | FALSE-AS-SCOPED | Z-NONCLAIMS · ev prose-only |
| `GLOBAL.ADR0009-HONESTY` | LIVE | PROVEN (as a statement about the argument) | Z-NONCLAIMS · ev prose-only; grounds: commit a provenance note (statement about the ADR record) |
| `GLOBAL.INVSYM` | LIVE | PROVEN | Z-SYM · ev committed |
| `GLOBAL.ADR0020-LH-CORRECT` | LIVE | PROVEN | Z-TABLE · ev committed |
| `GLOBAL.ADR0020-VERIFY-PASS` | LIVE | CLAIMED | Z-CONVERGE-FIX · ev committed |
| `GLOBAL.C1` | LIVE | — (definition) | Z · ev prose-only |
| `2x2.C1` | LIVE | PROVEN | Z-TABLE-FAITHFUL · ev prose-only; grounds: promote the exact-solver comparison probe (T104 Python kernel) |
| `3x2.C1` | LIVE | PROVEN | Z-TABLE-FAITHFUL · ev prose-only; grounds: promote from docs/evidence/T13/zig_t13_replay.zig + verify log |
| `3x3.C1` | BOGUS | CLAIMED | foundation falsified: d: GLOBAL.F2 → GLOBAL.C3 [FALSE-AS-SCOPED] |
| `4x3.C1` | BOGUS | CLAIMED | foundation falsified: d: GLOBAL.F1 [FALSE-AS-SCOPED] |
| `4x4.C1` | LIVE | UNTESTED | Z-TABLE-FAITHFUL · ev prose-only |
| `GLOBAL.C2` | LIVE | FALSE-AS-SCOPED (at 3×2) | Z-NONCLAIMS · ev prose-only |
| `2x2.T12` | LIVE | MEASUREMENT | Z-NONCLAIMS · ev prose-only |
| `3x2.T13` | LIVE | PROVEN (falsification) | Z-NONCLAIMS · ev committed |
| `3x3.C2` | LIVE | UNTESTED | Z-NONCLAIMS · ev prose-only |
| `4x3.C2` | LIVE | UNTESTED | Z-NONCLAIMS · ev prose-only |
| `4x4.C2` | LIVE | UNTESTED (status conflict, §6-D3) | Z-NONCLAIMS · ev prose-only |
| `GLOBAL.C3` | LIVE | FALSE-AS-SCOPED (at 3×3) | Z-NONCLAIMS · ev prose-only |
| `2x2.C3` | LIVE | MEASUREMENT | Z-NONCLAIMS · ev prose-only |
| `3x2.C3` | LIVE | MEASUREMENT | Z-NONCLAIMS · ev prose-only |
| `3x3.C3` | LIVE | PROVEN (falsification) | Z-NONCLAIMS · ev prose-only; grounds: re-run the range-aware self-play with committed harness, commit stdout |
| `4x3.C3` | LIVE | UNTESTED | Z-NONCLAIMS · ev prose-only |
| `4x4.C3` | LIVE | UNTESTED (status conflict, §6-D2) | Z-NONCLAIMS · ev prose-only |
| `GLOBAL.C4` | LIVE | FALSE-AS-SCOPED | Z-NONCLAIMS · ev prose-only |
| `GLOBAL.LEAK` | LIVE | PROVEN | Z-NONCLAIMS · ev prose-only; grounds: run logs not committed; demote to CLAIMED or re-run |
| `GLOBAL.E1` | LIVE | PROVEN (methodological) | Z-NONCLAIMS · ev prose-only; grounds: demote to CLAIMED (methodological) |
| `GLOBAL.BRUTE-ALIASING` | LIVE | FALSE (methodological) | Z-AUDIT · ev committed |
| `3x3.E3` | LIVE | PROVEN | Z-NONCLAIMS · ev prose-only; grounds: commit the 17-ply game record |
| `GLOBAL.E2-SANITY` | LIVE | PROVEN | Z-NONCLAIMS · ev prose-only; grounds: re-run the trivial-bounds harness check, commit, or demote |
| `GLOBAL.E2-POLICY` | LIVE | PROVEN (bug + fix) | Z-NONCLAIMS · ev prose-only; grounds: demote to CLAIMED (bug+fix record) |
| `GLOBAL.E2-VERDICT` | LIVE | CLAIMED | Z-NONCLAIMS · ev prose-only |
| `3x3.E2-RUN1` | LIVE | MEASUREMENT | Z-NONCLAIMS · ev prose-only |
| `3x3.E2-RUN2` | LIVE | MEASUREMENT | Z-NONCLAIMS · ev prose-only |
| `GLOBAL.ADR0005-CACHE` | LIVE | FALSE-AS-SCOPED | Z-TABLE-FAITHFUL · ev prose-only |
| `GLOBAL.ADR0008-HOLE` | LIVE | PROVEN (as a statement about the argument) | Z-TABLE-FAITHFUL · ev prose-only; grounds: commit a provenance note (statement about the ADR record) |
| `GLOBAL.F1` | LIVE | FALSE-AS-SCOPED | Z-TABLE-FAITHFUL · ev prose-only |
| `3x2.F1` | LIVE | PROVEN (falsification) | Z-TABLE-FAITHFUL · ev prose-only; grounds: re-point to docs/evidence/GLOBAL-AUDITOR/consist-3x2-2026-07-30.log |
| `4x4.F1` | LIVE | CLAIMED | Z-TABLE-FAITHFUL · ev prose-only |
| `4x3.F1` | LIVE | CLAIMED | Z-TABLE-FAITHFUL · ev prose-only |
| `GLOBAL.F2` | BOGUS | CLAIMED | foundation falsified: d: GLOBAL.C3 [FALSE-AS-SCOPED] (justification refuted by ADR-0015; superseded by GLOBAL.F2-REMEDY) |
| `GLOBAL.ADR0010-CUT` | BOGUS | CLAIMED | foundation falsified: d: GLOBAL.C3 [FALSE-AS-SCOPED] (ADR-0015 supersedes the justification) |
| `GLOBAL.ADR0010-SOUND` | LIVE | PROVEN (as a statement about the argument) | Z-TABLE-FAITHFUL · ev prose-only; grounds: commit a provenance note (statement about the ADR record) |
| `2x2.F2` | LIVE | MEASUREMENT | Z-TABLE-FAITHFUL · ev prose-only |
| `3x3.F2` | LIVE | MEASUREMENT | Z-TABLE-FAITHFUL · ev prose-only |
| `4x3.F2` | LIVE | UNTESTED | Z-TABLE-FAITHFUL · ev prose-only |
| `4x4.F2` | LIVE | UNTESTED | Z-TABLE-FAITHFUL · ev prose-only |
| `GLOBAL.F3` | BOGUS | CLAIMED | foundation falsified: d: GLOBAL.C3 [FALSE-AS-SCOPED] |
| `3x2.F3` | LIVE | PROVEN (necessary condition) | Z-TABLE-FAITHFUL · ev prose-only; grounds: re-point to docs/evidence/GLOBAL-AUDITOR/consist-3x2-2026-07-30.log |
| `4x4.F3` | LIVE | UNTESTED | Z-TABLE-FAITHFUL · ev prose-only |
| `GLOBAL.F4` | BOGUS | PROVEN (argument) + MEASUREMENT | foundation falsified: d: GLOBAL.F3 → GLOBAL.C3 [FALSE-AS-SCOPED] |
| `3x2.F4` | LIVE | PROVEN | Z-TABLE-FAITHFUL · ev prose-only; grounds: re-point to the 3x2 auditor log; re-run for the group |
| `3x3.F4` | LIVE | PROVEN | Z-TABLE-FAITHFUL · ev prose-only; grounds: re-run RETRO_CONSIST at 3x3, commit log |
| `4x3.F4` | LIVE | PROVEN | Z-TABLE-FAITHFUL · ev prose-only; grounds: re-run RETRO_CONSIST at 4x3, commit log |
| `4x4.F4` | LIVE | UNTESTED | Z-TABLE-FAITHFUL · ev prose-only |
| `GLOBAL.F4-COST` | ARCHAEOLOGY | MEASUREMENT | [design] memory-for-reuse tradeoff — 5×N projection input |
| `GLOBAL.AUDITOR` | LIVE | PROVEN | Z-AUDIT · ev committed |
| `GLOBAL.MEMO-XROOT` | LIVE | PROVEN (falsification) | Z-TABLE-FAITHFUL · ev prose-only; grounds: commit the 116-failure reproduction as a probe |
| `GLOBAL.ADR0006-EYE` | LIVE | CLAIMED | Z-AUDIT · ev committed |
| `GLOBAL.ADR0006-PRED` | LIVE | PROVEN | Z-AUDIT · ev prose-only; grounds: promote docs/audits/2026-07-30-eye-prune-validation.md + .stdout to docs/evidence/ |
| `GLOBAL.ADR0006-LEMMAS` | LIVE | PROVEN (per goban listed) | Z-AUDIT · ev prose-only; grounds: same promotion |
| `GLOBAL.ADR0006-TEST` | LIVE | PROVEN (executed 2026-07-30, scoped) | Z-AUDIT · ev prose-only; grounds: same promotion |
| `GLOBAL.ADR0006-PRUNEALL` | LIVE | PROVEN (per goban listed) | Z-AUDIT · ev prose-only; grounds: same promotion |
| `GLOBAL.ADR0009-NOEYE` | LIVE | PROVEN | Z-COMPLETE-ENUM · ev prose-only; grounds: demote to CLAIMED or commit a code-citation probe |
| `GLOBAL.ADR0007-TENSION` | LIVE | CLAIMED (open in ADR-0007; resolved by `GLOB… | Z-COMPLETE-ENUM · ev prose-only |
| `GLOBAL.ADR0004-TERM` | LIVE | PROVEN | Z-R-SCORE · ev prose-only; grounds: demote to CLAIMED (argument) |
| `GLOBAL.ADR0004-P1` | ARCHAEOLOGY | PROVEN | [ruleset-choice] superko-era finiteness rationale; the k=1 game is finite by construction (D1) |
| `GLOBAL.ADR0005-SUBBOARD` | ARCHAEOLOGY | PROVEN | [design] full-goban-only search foreclosure — recorded decision (AGENTS.md) |
| `GLOBAL.ADR0005-DBLPASS` | LIVE | CLAIMED (argued, not machine-checked) | Z-R-SCORE · ev prose-only |
| `GLOBAL.ADR0005-PASS` | LIVE | PROVEN | Z-R-MOVE · ev prose-only; grounds: demote to CLAIMED (argument) |
| `GLOBAL.ADR0003-AREA` | LIVE | PROVEN | Z-R-SCORE · ev prose-only; grounds: demote to CLAIMED (argument; axioms are CLAIMED at birth by convention) |
| `GLOBAL.P1` | LIVE | FALSE-AS-SCOPED | Z-NONCLAIMS · ev prose-only |
| `GLOBAL.P2` | LIVE | PROVEN (as scoped) | Z-AUDIT · ev prose-only; grounds: demote to CLAIMED (validation doctrine) |
| `GLOBAL.P3` | LIVE | FALSE-AS-SCOPED | Z-NONCLAIMS · ev prose-only |
| `4x4.P3` | LIVE | MEASUREMENT | Z-NONCLAIMS · ev prose-only |
| `GLOBAL.T06` | LIVE | MEASUREMENT | Z-NONCLAIMS · ev prose-only |
| `4x4.B39` | LIVE | FALSE-AS-SCOPED (measurement artifact) | Z-NONCLAIMS · ev prose-only |
| `4x4.B43` | LIVE | MEASUREMENT | Z-NONCLAIMS · ev prose-only |
| `4x4.B43-DIV` | LIVE | MEASUREMENT | Z-NONCLAIMS · ev prose-only |
| `4x4.M5` | ARCHAEOLOGY | PROVEN | [old-artifact] empty 4x4 KO_SENSITIVE + 16/19 plies flagged — old-artifact/player diagnostic |
| `4x4.KO-RULE-NULL` | ARCHAEOLOGY | PROVEN (these two games) | [ruleset-choice] PSK binding rate in two games — evidences the k=1 choice |
| `4x4.GTP-DEFECT` | ARCHAEOLOGY | PROVEN | [player] player move rule undefined at 4×4 — consumer defect |
| `4x4.GREEDY-BIAS` | ARCHAEOLOGY | CLAIMED | [player] greedy extremum bias — player-side |
| `4x4.REGR-SYM` | ARCHAEOLOGY | PROVEN | [player] two regression games mirror-identical — player diagnostic |
| `4x4.REGR-CLIFF` | ARCHAEOLOGY | MEASUREMENT | [player] ply-16 collapse (−16 vs +16) — player diagnostic |
| `CODE.UNDEF` | ARCHAEOLOGY | PROVEN | [player] UNDEF sentinel convention for incomplete artifacts; the k=1 table is complete by construction |
| `4x4.B16-GAME` | LIVE | MEASUREMENT | Z-NONCLAIMS · ev prose-only |
| `4x4.HISTPERF-CHEAP` | ARCHAEOLOGY | MEASUREMENT | [player] history-perfect genmove "trivially affordable" — player-side measurement |
| `GLOBAL.R1` | ARCHAEOLOGY | PROVEN (structural) | [ruleset-choice] PSK exact-solve intractable — the ruleset foreclosure itself |
| `2x2.R1` | ARCHAEOLOGY | MEASUREMENT | [ruleset-choice] 118,475,182 ban-set states at 2×2 — the PSK intractability witness |
| `3x2.R1` | ARCHAEOLOGY | MEASUREMENT | [ruleset-choice] 116,114,272 ban-set states at 3×2 |
| `4x4.R1` | ARCHAEOLOGY | CLAIMED | [ruleset-choice] PSK intractable at 4×4 (inherited) |
| `GLOBAL.R2` | ARCHAEOLOGY | PROVEN (argument) + MEASUREMENT | [ruleset-choice] score-on-cycle ≡ PSK intractability (byte-identical counts) |
| `GLOBAL.R3` | ARCHAEOLOGY | FALSE-AS-SCOPED | [ruleset-choice] kill-X% foreclosure (makes the region worse) |
| `4x4.R3` | ARCHAEOLOGY | PROVEN (falsification) | [ruleset-choice] kill-X% census at 4×4 — region worsens as threshold drops |
| `2x2.R3` | ARCHAEOLOGY | MEASUREMENT | [ruleset-choice] kill-50 at 2×2 (trivial, score unchanged) |
| `3x2.R3` | ARCHAEOLOGY | MEASUREMENT | [ruleset-choice] kill-50 too lenient at 3×2 |
| `GLOBAL.RPLY` | ARCHAEOLOGY | PROVEN (falsification) | [ruleset-choice] exact N-ply superko sweep intractable for every N |
| `GLOBAL.RPLY-TRAP` | ARCHAEOLOGY | PROVEN (argument) | [ruleset-choice] bounded-history score-on-cycle trap |
| `GLOBAL.RPLY-RETRO` | ARCHAEOLOGY | CLAIMED | [ruleset-choice] bounded-history retrograde route — sparse state space |
| `GLOBAL.RNPLY-FORBID` | ARCHAEOLOGY | PROVEN | [ruleset-choice] forbid-only N-ply does not terminate |
| `GLOBAL.MIGOS-RULE` | LIVE | PROVEN | Z-TABLE-FAITHFUL · ev prose-only; grounds: commit the primary-source reading note (quotes exist in docs/evidence/van-der-werf-sources/) |
| `GLOBAL.ANCHOR-DELTA` | ARCHAEOLOGY | CLAIMED | [ruleset-choice] PSK-era anchor reconciliation — superseded by k=1 anchors |
| `GLOBAL.REFRAME` | LIVE | CLAIMED (adopted decision) | Z · ev prose-only |
| `GLOBAL.UD-1` | NOTE | CLAIMED | user decision record — a decision, not a claim; cites git-ignored untracked/SUBAGENTS.md (C2 dead link dies with it) |
| `GLOBAL.UD-2` | NOTE | CLAIMED | user decision record — a decision, not a claim |
| `GLOBAL.UD-3` | NOTE | CLAIMED | user decision record — a decision, not a claim |
| `GLOBAL.PSK-GAP` | ARCHAEOLOGY | PROVEN | [ruleset-choice] transitional statement about the old PSK artifact |
| `GLOBAL.Z` | LIVE | CLAIMED | Z · ev prose-only |
| `GLOBAL.AXIOM-GEOM` | LIVE | CLAIMED | Z-R-MOVE · ev prose-only |
| `GLOBAL.AXIOM-STONE` | LIVE | CLAIMED | Z-R-MOVE · ev prose-only |
| `GLOBAL.AXIOM-CAPTURE` | LIVE | CLAIMED | Z-R-MOVE · ev prose-only |
| `GLOBAL.AXIOM-SUICIDE` | LIVE | CLAIMED | Z-R-MOVE · ev prose-only |
| `GLOBAL.AXIOM-PASS` | LIVE | CLAIMED | Z-R-MOVE · ev prose-only |
| `GLOBAL.AXIOM-FORCEDPASS` | LIVE | CLAIMED | Z-R-MOVE · ev committed |
| `GLOBAL.AXIOM-BASICKO` | LIVE | CLAIMED | Z-R-MOVE · ev prose-only |
| `GLOBAL.AXIOM-KOSTATE` | LIVE | CLAIMED | Z-R-MOVE · ev prose-only |
| `GLOBAL.AXIOM-KOPASS` | LIVE | CLAIMED | Z-R-MOVE · ev prose-only |
| `GLOBAL.AXIOM-TERMINAL` | LIVE | CLAIMED | Z-R-SCORE · ev prose-only |
| `GLOBAL.AXIOM-AREA` | LIVE | CLAIMED | Z-R-SCORE · ev prose-only |
| `GLOBAL.AXIOM-TIE` | LIVE | CLAIMED | Z-R-TIE · ev prose-only |
| `GLOBAL.AXIOM-SCORESIGN` | LIVE | CLAIMED | Z-R-SIGN · ev prose-only |
| `GLOBAL.AXIOM-STATE` | LIVE | CLAIMED | Z-R-STATE · ev prose-only |
| `GLOBAL.AXIOM-FRESHSTART` | LIVE | CLAIMED | Z-R-STATE · ev prose-only |
| `GLOBAL.AXIOM-PASSSTATE` | LIVE | CLAIMED | Z-R-STATE · ev prose-only |
| `GLOBAL.AXIOM-BELLMAN` | LIVE | CLAIMED | Z-CONVERGE · ev prose-only |
| `GLOBAL.AXIOM-LH` | LIVE | CLAIMED | Z-CONVERGE · ev prose-only |
| `GLOBAL.AXIOM-BRACKET` | LIVE | CLAIMED | Z-TABLE · ev prose-only |
| `GLOBAL.TIE-MIGOS` | LIVE | FALSE-AS-SCOPED (the minted mechanism is con… | Z-TABLE-FAITHFUL · ev committed |
| `GLOBAL.FIXPOINT-VS-SEARCH` | LIVE | CLAIMED | Z-TABLE-FAITHFUL · ev committed |
| `GLOBAL.AXIOM-AMEND1` | LIVE | CLAIMED | Z-R-MOVE · ev prose-only |
| `GLOBAL.AXIOM-AMEND2` | LIVE | CLAIMED | Z-R-MOVE · ev prose-only |
| `GLOBAL.CHAIN-DEF` | NOTE | — (definition) | a definition, never a claim (register doctrine: definitions are d:-dead); the chainability concept died with the old-artifact era |
| `GLOBAL.CHAIN-LH` | ARCHAEOLOGY | PROVEN (on the audited artifacts) | [old-artifact] L==H chainable on the old audited artifacts |
| `GLOBAL.CHAIN-KO` | ARCHAEOLOGY | PROVEN | [old-artifact] ko-sensitive not chainable, co-extensive with the flag (old artifacts) |
| `GLOBAL.CHAIN-KIND` | ARCHAEOLOGY | PROVEN | [old-artifact] violations definitional in kind (old artifacts) |
| `GLOBAL.MAXGAP` | ARCHAEOLOGY | CLAIMED | [old-artifact] worst misprice = 2n on old artifacts |
| `2x2.M4` | ARCHAEOLOGY | MEASUREMENT | [old-artifact] 77.36% ko-sensitive census of the old PSK artifact |
| `3x2.M4` | ARCHAEOLOGY | MEASUREMENT | [old-artifact] 41.18% ko-sensitive census of the old PSK artifact |
| `3x3.M4` | ARCHAEOLOGY | MEASUREMENT | [old-artifact] 35.04% ko-sensitive census of the old PSK artifact |
| `4x3.M4` | ARCHAEOLOGY | MEASUREMENT | [old-artifact] 26.60% ko-sensitive census of the old PSK artifact |
| `4x4.M4` | ARCHAEOLOGY | MEASUREMENT | [old-artifact] 21.27%/4.08% — THE most-cited old-artifact datum; measured on the disowned writes-on checkpoint |
| `4x4.M6` | ARCHAEOLOGY | MEASUREMENT | [old-artifact] writes-off misprice halving measured on old artifacts (4.08%→1.67%) |
| `4x4.M6-FLOOR` | ARCHAEOLOGY | PROVEN (on the swept artifact) | [old-artifact] definitional floor 1.67% on the swept artifact |
| `4x4.M6-EXCESS` | ARCHAEOLOGY | CLAIMED | [old-artifact] the ADR-0013 excess on old artifacts |
| `4x4.M6-SCREEN` | ARCHAEOLOGY | CLAIMED | [old-artifact] misprice screen for old artifacts |
| `4x4.WRITESOFF` | ARCHAEOLOGY | MEASUREMENT | [old-artifact] uncommitted writes-off checkpoint — build completion never confirmed |
| `4x4.M1` | ARCHAEOLOGY | MEASUREMENT | [old-artifact] 21.32% ko-sensitive exhaustive on the old checkpoint |
| `4x4.KO-CENSUS` | ARCHAEOLOGY | MEASUREMENT | [old-artifact] single-ko census (99.997%) of the old artifact |
| `4x4.M2` | LIVE | MEASUREMENT | Z-CONVERGE-FINITE · ev prose-only |
| `4x4.M3` | ARCHAEOLOGY | MEASUREMENT | [old-artifact] finisher cost on the writes-on config |
| `4x4.BRACKET` | ARCHAEOLOGY | MEASUREMENT | [old-artifact] old root bracket [−6,+16]; the k=1 bracket lives in 4x4.BASICKO-TIE |
| `4x4.SINGLE` | ARCHAEOLOGY | MEASUREMENT | [old-artifact] 78.68% single-score fraction on the old artifact |
| `4x4.TANGLE` | ARCHAEOLOGY | MEASUREMENT | [old-artifact] width-32 bracket count on the old artifact |
| `4x4.ANCHOR` | ARCHAEOLOGY | MEASUREMENT | [old-artifact] +2 anchor is a different game's value (TIE-MIGOS adjudication) |
| `4x4.CYCLE-INSENS` | ARCHAEOLOGY | CLAIMED | [old-artifact] cycle-insensitivity claim refuted by the +1-vs-+2 gap |
| `4x4.VALBATTERY` | ARCHAEOLOGY | MEASUREMENT | [old-artifact] 2026-07-21 validation of the retracted COMPLETE artifact |
| `4x4.COMPLETE-2026-07-21` | ARCHAEOLOGY | FALSE-AS-SCOPED | [old-artifact] THE retracted completeness claim — the reason the project stopped trusting old artifacts |
| `4x4.PARALLEL` | ARCHAEOLOGY | MEASUREMENT | [old-artifact] writes-off parallel checkpoint, 99.8% filled, root UNDEF |
| `4x3.M1` | ARCHAEOLOGY | MEASUREMENT | [old-artifact] 26.47% ko-sensitive on the old build |
| `4x3.M2` | LIVE | MEASUREMENT | Z-CONVERGE-FINITE · ev prose-only |
| `4x3.M3` | ARCHAEOLOGY | MEASUREMENT | [old-artifact] writes-on solve cost — old generation |
| `4x3.BRACKET` | ARCHAEOLOGY | MEASUREMENT | [old-artifact] [−1,+12] on the old build |
| `4x3.TANGLE` | ARCHAEOLOGY | MEASUREMENT | [old-artifact] width-24 bracket count on the old build |
| `3x3.M1` | ARCHAEOLOGY | MEASUREMENT | [old-artifact] 34.3% ko-sensitive on the old build |
| `3x3.BRACKET` | ARCHAEOLOGY | MEASUREMENT | [old-artifact] [+2,+9] on the old build; all five published anchors in-bracket |
| `3x3.ANCHOR` | ARCHAEOLOGY | MEASUREMENT | [old-artifact] finisher-era anchor verification (PIN/MATCH) |
| `GLOBAL.SWEEPS` | ARCHAEOLOGY | MEASUREMENT | [design] sweep-growth trend — 5×N projection input |
| `2x2.EXACT` | LIVE | MEASUREMENT | Z-TABLE-FAITHFUL · ev prose-only |
| `3x2.EXACT` | LIVE | MEASUREMENT | Z-TABLE-FAITHFUL · ev prose-only |
| `3x3.FWD-SPOT` | LIVE | MEASUREMENT | Z-TABLE-FAITHFUL · ev prose-only |
| `GLOBAL.FWD-INTRACT` | ARCHAEOLOGY | PROVEN | [design] forward filling intractable — method rationale |
| `GLOBAL.FIN-NEARTERM` | ARCHAEOLOGY | MEASUREMENT | [design] plain finisher rescues near-terminal slots — finisher-era design |
| `GLOBAL.FIN-BRACKET` | ARCHAEOLOGY | MEASUREMENT | [design] bracket cutoffs collapse the finisher — finisher-era design |
| `4x4.DRIVER` | ARCHAEOLOGY | MEASUREMENT | [design] finisher driver saga — old-generation design |
| `2x2.BASICKO-TIE` | LIVE | MEASUREMENT | Z-TABLE · ev committed |
| `3x2.BASICKO-TIE` | LIVE | MEASUREMENT | Z-TABLE · ev committed |
| `3x3.BASICKO-TIE` | LIVE | MEASUREMENT | Z-TABLE · ev committed |
| `4x4.BASICKO-TIE` | LIVE | MEASUREMENT | Z-TABLE · ev committed |
| `GLOBAL.PASS-NOKO` | LIVE | PROVEN (code + independent re-derivation) | Z-R-STATE · ev prose-only; grounds: trivial property probe on the solver; commit, or demote |
| `GLOBAL.H1-MARKOV` | LIVE | UNTESTED | Z-R-TIE · ev committed |
| `GLOBAL.H1-COMPUTABLE` | LIVE | FALSE-AS-SCOPED | Z-R-TIE · ev committed |
| `GLOBAL.H1-CENSUS` | LIVE | PROVEN | Z-STATE-REACH · ev committed |
| `3x3.H1-CENSUS` | LIVE | PROVEN | Z-STATE-REACH · ev committed |
| `4x3.H1-CENSUS` | LIVE | PROVEN | Z-STATE-REACH · ev committed |
| `4x4.G-CENSUS` | LIVE | MEASUREMENT | Z-COMPLETE-ENUM · ev committed |
| `GLOBAL.LONGCYCLE` | LIVE | FALSE-AS-SCOPED | Z-R-TIE · ev committed |
| `GLOBAL.H2` | ARCHAEOLOGY | UNTESTED | [player] greedy-player loss-rate ordering — player-side |
| `GLOBAL.H3` | ARCHAEOLOGY | UNTESTED | [player] play-time history-exact search affordability — player-side |
| `GLOBAL.H3-LOWERBOUND` | ARCHAEOLOGY | MEASUREMENT | [player] search performance lower bound — player-side |
| `GLOBAL.H4` | LIVE | CLAIMED (partial) | Z-CONVERGE-FIX · ev prose-only |
| `GLOBAL.H4a` | LIVE | UNTESTED | Z-CONVERGE-FIX · ev prose-only |
| `GLOBAL.H4b` | LIVE | UNTESTED | Z-CONVERGE-FIX · ev prose-only |
| `GLOBAL.H5` | ARCHAEOLOGY | CLAIMED | [player] player fix without resolving open questions — consumer-side |
| `GLOBAL.H5a` | ARCHAEOLOGY | CLAIMED | [player] chainable-region steering — sound but weak — player-side |
| `GLOBAL.H5a-CHILD` | ARCHAEOLOGY | CLAIMED | [player] child-side Bellman check (D-3, EXP-9) — player-side |
| `GLOBAL.H5a-FALLBACK` | ARCHAEOLOGY | CLAIMED | [player] "refuse" must not mean pass (D-3, EXP-9) — player-side |
| `GLOBAL.H5b` | ARCHAEOLOGY | CLAIMED | [player] history-exact search to Benson horizon — player-side |
| `GLOBAL.H5c` | BOGUS | PROVEN (as an implication) | foundation falsified: d: GLOBAL.C3 [FALSE-AS-SCOPED] (bracket-cut-under-real-history IS claim C3) |
| `GLOBAL.H5d` | ARCHAEOLOGY | CLAIMED | [player] bounded-history route to a real-game claim — future work, not a requirement of this Z |
| `GLOBAL.ONEMISMATCH-DIAG` | NOTE | CLAIMED | opinion/interpretation — the row itself says "not a proved theorem"; never should have carried CLAIMED |
| `GLOBAL.ONEMISMATCH-CURE` | LIVE | FALSE-AS-SCOPED | Z-R-TIE · ev committed |
| `4x4.A-1` | ARCHAEOLOGY | FALSE-AS-SCOPED | [player] "with PSK history W A4 gave +16" — corrected to the player defect |
| `4x4.A-2` | LIVE | FALSE-AS-SCOPED (category error — every blun… | Z-NONCLAIMS · ev prose-only |
| `4x4.A-3` | ARCHAEOLOGY | FALSE-AS-SCOPED (the player is not fresh-sta… | [player] "engine is fresh-start-perfect" — FALSE at the chosen child (−3 vs −16) |
| `GLOBAL.B-1` | ARCHAEOLOGY | FALSE-AS-SCOPED (as of the code at 2026-07-27) | [player] history-perfect genmove inheritance claim — FALSE as of the code at 2026-07-27 |
| `GLOBAL.C-1` | ARCHAEOLOGY | FALSE-AS-SCOPED | [old-artifact] transient chainability-violations attribution — crisis diagnostic |
| `GLOBAL.CALIB-LESSON` | LIVE | PROVEN (methodological) | Z-AUDIT · ev prose-only; grounds: demote to CLAIMED (methodological ruling) |
| `CODE.ADR0011-FMT` | LIVE | PROVEN | Z-TABLE · ev prose-only; grounds: demote to CLAIMED or commit a reader round-trip test |
| `CODE.ADR0011-GATE` | LIVE | PROVEN | Z-TABLE-CONSISTENCY · ev prose-only; grounds: demote to CLAIMED or commit the gate conditions as a test |
| `CODE.ADR0011-DTT` | ARCHAEOLOGY | CLAIMED | [old-artifact] DTT best-effort on WZO1 — play-time aid on the old format |
| `GLOBAL.ADR0009-DTT` | ARCHAEOLOGY | PROVEN | [player] DTT = fastest optimal resolution — play-time aid, not a theorem requirement |
| `GLOBAL.ADR0012-GATE` | BOGUS | CLAIMED (orphaned — depends on the retracted… | foundation falsified: d: 4x4.COMPLETE-2026-07-21 [FALSE-AS-SCOPED] (re-point to the Track A writes-off artifact when it exists) |
| `GLOBAL.ADR0012-PAR` | LIVE | CLAIMED | Z-TABLE-CONSISTENCY · ev prose-only |
| `GLOBAL.ADR0012-5X5` | ARCHAEOLOGY | CLAIMED (projection; ADR status is *proposed… | [design] 5×5 feasibility projection — out of Z's goban scope |
| `4x4.I5-FEAS` | LIVE | CLAIMED (projection; the calibration section… | Z-STATE-REACH · ev committed |
| `3x2.I5-CAL` | LIVE | MEASUREMENT (with the not-reproduced verdict… | Z-AUDIT · ev prose-only |
| `CODE.WZO2-CHAINSHORT` | ARCHAEOLOGY | SUPERSEDED (2026-08-03, T269: true when writ… | [old-artifact] SUPERSEDED — true when written (T269); code fixed since |
| `CODE.WZO2-UNRUN` | ARCHAEOLOGY | SUPERSEDED (2026-08-03, T269: true when writ… | [process] SUPERSEDED status record — the artifact was built the same day |
| `CODE.WZO2-PASSBIT` | LIVE | PROVEN (measured, both failing checks reprod… | Z-STATE-KEY · ev committed |
| `SPRINT-M4a-ACCEPT` | LIVE | PROVEN (measured, denominators stated) | Z-TABLE-CONSISTENCY · ev committed |
| `WZO2-4X4-VALID` | LIVE | FALSE-AS-SCOPED (as "valid"; the artifact is… | Z-COMPLETE-ENUM · ev committed |
| `CODE.WZO2-INCOMPLETE` | LIVE | FALSE-AS-SCOPED (the stated claim is wrong a… | Z-COMPLETE-ENUM · ev committed |
| `WZO2.I2-CLEAN` | LIVE | MEASUREMENT | Z-TABLE-CONSISTENCY · ev committed |
| `CODE.WZO2-PASS1-LAW` | LIVE | PROVEN (derivation from source + exhaustive … | Z-COMPLETE-PASSES · ev committed |
| `CODE.ACCEPT-KOKEY` | LIVE | PROVEN (source comparison + checker's own re… | Z-STATE-KEY · ev committed |
| `CODE.GTP-LHSIDE` | ARCHAEOLOGY | PROVEN (reproduced at HEAD, four plies cross… | [player] wrong-side bracket display — display-path defect (fix T283) |
| `CODE.CLAIMLINT-C7-NEWROWS` | LIVE | PROVEN (A/B experiment on four-row findings … | Z-AUDIT · ev committed |
| `CODE.GTP-KOKEY` | LIVE | PROVEN (root cause read in source, fix verif… | Z-STATE-KEY · ev committed |
| `4x4.V1-INVSYM-BROKEN` | LIVE | PROVEN (independent re-implementation, dedup… | Z-TABLE-CONSISTENCY · ev committed |
| `CODE.WZO1-DTT-UNSET` | ARCHAEOLOGY | PROVEN (I7 across four gobans + independent … | [old-artifact] DTT column never computed on WZO1 (all 255) — old format |
| `CODE.BATTERY-STUBBED` | LIVE | PROVEN (source inspection + the stub output … | Z-AUDIT · ev committed |
| `CODE.M4A-HARNESS` | LIVE | PROVEN (by inspection) | Z-AUDIT · ev prose-only; grounds: accept as inspection record or demote — the harness itself is the finding |
| `CODE.VB-STUBS` | LIVE | PROVEN (by inspection) | Z-AUDIT · ev prose-only; grounds: accept as inspection record or demote |
| `CODE.VB-BLINDGAPS` | LIVE | PROVEN (blind-reimplementation audit, commit… | Z-AUDIT · ev committed |
| `GLOBAL.ADR0012-LAYER` | ARCHAEOLOGY | PROVEN (arithmetic) | [design] 5×5 layer RAM arithmetic — out of Z's goban scope |
| `GLOBAL.ADR0012-V1` | ARCHAEOLOGY | PROVEN | [design] V1 recomputed inline — RAM-lean design rationale |
| `GLOBAL.ADR0002-SEQ` | ARCHAEOLOGY | UNTESTED | [design] 5×5 collision-size bounds — out of Z's goban scope |
| `GLOBAL.ADR0007-AB` | ARCHAEOLOGY | PROVEN | [design] alpha-beta cannot populate an oracle — method rationale |
| `GLOBAL.ADR0007-BACKEDGE` | ARCHAEOLOGY | PROVEN | [design] captures create back-edges — why the fixpoint iterates |
| `GLOBAL.ADR0009-SUCC` | ARCHAEOLOGY | PROVEN (design argument) | [design] successor-sweep propagation — design rationale |
| `GLOBAL.ADR0014-PURE` | LIVE | PROVEN | Z-NONCLAIMS · ev prose-only; grounds: demote to CLAIMED (code-reading) |
| `GLOBAL.ADR0016-INHERIT` | LIVE | CLAIMED (adopted rule — a decision, not a fa… | Z-NONCLAIMS · ev prose-only |
| `GLOBAL.ADR0015-BURDEN` | LIVE | CLAIMED | Z-TABLE-FAITHFUL · ev prose-only |
| `GLOBAL.F2-REMEDY` | LIVE | CLAIMED | Z-TABLE-FAITHFUL · ev committed |
| `GLOBAL.ADR0014-DEAD` | ARCHAEOLOGY | CLAIMED | [player] scoring-UI heuristics — consumer-side |
| `4x4.D3` | LIVE | UNTESTED | Z-TABLE-FAITHFUL · ev prose-only |
| `GLOBAL.B15` | BOGUS | CLAIMED | foundation falsified: d: GLOBAL.F3 → GLOBAL.C3 [FALSE-AS-SCOPED] |
| `GLOBAL.T14.1` | ARCHAEOLOGY | CLAIMED | [old-artifact] 2026-07-27 bracket-only artifact — historical |
| `GLOBAL.ONEWRITER` | NOTE | CLAIMED | process rule (one writer per engine file) — a rule, not a claim; home is AGENTS.md |
| `GLOBAL.RELEASEFAST` | NOTE | PROVEN | measurement-methodology discipline — a rule, not a claim; home is AGENTS.md |
| `GLOBAL.BATTERY-GAPS` | LIVE | CLAIMED | Z-AUDIT · ev committed |
| `GLOBAL.BATTERY-PASS1-ACCEPTANCE` | LIVE | CLAIMED | Z-AUDIT · ev prose-only |
| `CODE.KEY-AGREEMENT` | LIVE | CLAIMED | Z-STATE-KEY · ev committed |
| `CODE.STANDING-ABSORB` | NOTE | PROVEN | infra mechanism record (T294) — the standing trigger is described and verified, but it is infra, not a claim about Z; home is docs/infra/ |
| `CODE.STANDING-C3-DEAD` | NOTE | PROVEN | infra defect record — dead trigger, reported for the Orchestrator; infra, not a claim about Z |
| `CODE.STANDING-STATE-FRAGILE` | NOTE | PROVEN | infra defect record — persisted priors fragile; infra, not a claim about Z |
| `4x4.WZO2-A2-EXHAUSTIVE` | LIVE | CLAIMED (exhaustive measurement; PROVEN prop… | Z-CONVERGE-FIX · ev committed |
| `4x4.WZO2-A5-EXHAUSTIVE` | LIVE | CLAIMED (exhaustive measurement; PROVEN prop… | Z-TABLE-ROUNDTRIP · ev committed |
| `4x4.WZO2-A8-EXHAUSTIVE` | LIVE | CLAIMED (exhaustive measurement; PROVEN prop… | Z-TABLE-CONSISTENCY · ev committed |
| `CODE.WZO2-BUILD-REPRO` | LIVE | CLAIMED | Z-TABLE-CONSISTENCY · ev committed |
| `CODE.T312-PARALLEL-FIXPOINT` | LIVE | CLAIMED | Z-TABLE-CONSISTENCY · ev committed |
| `CODE.WZO2-RELEASESAFE-INV` | LIVE | CLAIMED | Z-TABLE-CONSISTENCY · ev committed |
| `CODE.PARALLEL-FIXPOINT-MEASURED` | LIVE | MEASUREMENT | Z-TABLE-CONSISTENCY · ev committed |
| `CODE.MANAGENT-MODEL-VALIDATION` | NOTE | CLAIMED | infra implementation record (T317) — home is src/managent + tests |
| `CODE.MANAGENT-LOST-UPDATE` | NOTE | CLAIMED | infra implementation record (T317) — home is src/managent + tests |
| `CODE.MANAGENT-AMEND` | NOTE | CLAIMED | infra implementation record (T317) — home is src/managent + tests |
| `CODE.MANAGENT-ARCHIVE` | NOTE | CLAIMED | infra implementation record (T319) — home is src/managent + tests |
| `CODE.REGRESSION-WIRING` | NOTE | CLAIMED | infra implementation record (T322) — home is build.zig + tools/ |
| `GLOBAL.SYM-FOLD` | ARCHAEOLOGY | MEASUREMENT | [new-absorption] raw-space symmetry-fold census; Q2 refuted (no colex-prefix truncation); 5×5 input |
| `GLOBAL.I5-SCC-CONTAIN` | DISPUTED | CLAIMED | tree-map marks RETIRED with no stated family, but the row is the I5 battery PASS at three ladder rungs — the evidence G3 acceptance needs; its siblings (4x4.I5-FEAS → Z-STATE-REACH, 3x2.I5-CAL → Z-AUDIT) are mapped. Settles: Orchestrator adjudicates the mapping (re-map to Z-STATE-REACH/Z-AUDIT and keep, or confirm retirement). |
| `QA-001` | LIVE | FALSE | Z-CONVERGE-FIX · ev prose-only |
| `QA-002` | ARCHAEOLOGY | FALSE | [player] alias of 4x4.A-3 |
| `QA-003` | LIVE | FALSE | Z-NONCLAIMS · ev prose-only |
| `QA-004` | LIVE | FALSE | Z-TABLE · ev prose-only |
| `QA-005` | ARCHAEOLOGY | FALSE | [old-artifact] KO_SENSITIVE-flag semantics on the old artifact — refuted |
| `QA-006` | ARCHAEOLOGY | FALSE | [old-artifact] definitional-vs-excess on old artifacts — refuted |
| `QA-007` | ARCHAEOLOGY | CLAIMED | [old-artifact] alias of 4x4.M6-EXCESS |
| `QA-008` | ARCHAEOLOGY | UNTESTED | [old-artifact] writes-off checkpoint completion — never answered |
| `QA-009` | LIVE | FALSE | Z-NONCLAIMS · ev prose-only |
| `QA-010` | NOTE | CLAIMED | alias of GLOBAL.ONEMISMATCH-DIAG — opinion row |
| `QA-011` | LIVE | CLAIMED | Z-R-TIE · ev prose-only |
| `QA-012` | LIVE | UNTESTED | Z-NONCLAIMS · ev committed |
| `QA-013` | LIVE | FALSE-AS-SCOPED | Z-R-TIE · ev committed |
| `QA-014` | ARCHAEOLOGY | UNTESTED | [player] per-node Bellman check for the player — consumer-side |
| `QA-015` | LIVE | CLAIMED (**DECIDED 2026-07-28** — D-2, Opus … | Z-NONCLAIMS · ev prose-only |
| `QA-016` | ARCHAEOLOGY | FALSE | [old-artifact] parallel checkpoint cannot state the answer (root UNDEF) |
| `QA-017` | ARCHAEOLOGY | CLAIMED | [old-artifact] engine steers into the unchainable region — old-artifact diagnostic |
| `QA-018` | BOGUS | CLAIMED | foundation falsified: d: GLOBAL.F2 → GLOBAL.C3 [FALSE-AS-SCOPED] (alias of GLOBAL.F2) |
| `QA-019` | LIVE | FALSE | Z-TABLE-FAITHFUL · ev prose-only |
| `QA-020` | ARCHAEOLOGY | FALSE | [player] self-certification 0% (PSK) / 10.71% (k=1) — player-side |
| `QA-021` | LIVE | PROVEN | Z-CONVERGE-FIX · ev prose-only; grounds: commit the exhaustive vb/vw sweep run log |
| `QA-022` | LIVE | FALSE | Z-AUDIT · ev committed |
| `QA-023` | LIVE | CLAIMED | Z-R-TIE · ev committed |
| `QA-024` | ARCHAEOLOGY | CLAIMED | [ruleset-choice] PSK binding beyond basic ko — evidences the k=1 choice |
| `QA-025` | LIVE | PROVEN | Z-TABLE-FAITHFUL · ev prose-only; grounds: alias of GLOBAL.MIGOS-RULE — same treatment |
| `QA-026` | LIVE | FALSE-AS-SCOPED | Z-CONVERGE-FIX · ev committed |
| `QA-027` | LIVE | FALSE-AS-SCOPED (at 4×4; 3×3 measured 100.00%) | Z-CONVERGE-FIX · ev committed |
| `QA-028` | ARCHAEOLOGY | FALSE | [crisis-diagnostic] Reading-A history-window ladder — withdrawn before ever run |


## 2. Summary 1 — the C3 ratchet plan

C3 (PROVEN-without-committed-evidence) is **76 today, report-only**. Of those
76 Tier-B rows, **26 are already classified ARCHAEOLOGY/NOTE** (they leave the
register in step 0), **2 are BOGUS** (`GLOBAL.F4`, `GLOBAL.H5c` — they leave
too), and **48 are LIVE** and stay. The plan moves C3 from report-only to a
failing gate in four steps, each with its declared floor. A floor is declared
in `tools/hooks/claimlint-floor.json` **in the same commit that reaches it** —
never before, or the current 76 fails the gate on the way.

**Step 0 — triage adoption (C3 76 → 48; floor 48).** The Orchestrator rules on
this sheet; the 106 ARCHAEOLOGY + 16 NOTE + 10 BOGUS rows leave the live
register for `archives/register/` (§4). This is one atomic package, ordered so
the pre-commit gate never wedges:

1. **Re-base the claimlint calibration fixtures first** (`src/claimlint.zig`:
   `CAL_ORPHAN_CHILD`/`CAL_SHADOW_CLEAN` = `GLOBAL.F2`, `CAL_CITE_GOOD_A` =
   `GLOBAL.R1`). All three name rows this triage moves out; if the register
   edit lands first, calibration goes FAIL (known-bad 1 MISSED, known-good 5
   uncheckable, C6's synthetic good-tag unresolvable) and every commit after
   it is blocked. `GLOBAL.C3` stays (LIVE, Z-NONCLAIMS) so the C1a fixture can
   be re-based onto a synthetic pair that still exercises a FALSE ancestor.
2. **Register edit + tree-map edit together** (C9 row-set equality is a hard
   gate — the tree-map §1 and §3 must shed exactly the same rows as the
   register, or C9 fails at 0).
3. **Re-point surviving edges** off the leaving rows: `4x4.F2` (`d:GLOBAL.F2`,
   `d:GLOBAL.C3`), `4x4.F3`/`4x4.F4` (`d:GLOBAL.F3`, `d:GLOBAL.F4`), `4x3.F2`
   (`d:GLOBAL.F2`), `4x4.C1` (`d:4x4.F2`, `d:GLOBAL.F1`), `4x4.C3`/`4x3.C3`
   (`d:GLOBAL.C3`), `4x4.B43` (`e:CODE.UNDEF`, `e:4x4.PARALLEL`), `4x4.D3`
   (`e:4x3.M3`), `GLOBAL.ONEMISMATCH-CURE` (`untracked/AUDIT-DSPro-…`),
   `GLOBAL.ADR0015-BURDEN` (`untracked/msg/…/025-fable-to-all.md`). The C2
   dead-link count and C4 ghost count are re-measured in this same commit and
   the floor file updated to the new values (C1a 10 → 0; C2, C4 re-measured;
   C3 48; calibration PASS) — floors may only be lowered by the Orchestrator
   on evidence, and the triage adoption is that evidence.
4. **C4 archive resolution**: claimlint's C4 treats IDs resolvable via
   `archives/register/INDEX.md` as resolved, not dangling. Without this, the
   132 moved IDs become 132 new ghosts and drown the report-only signal.

**Step 1 — attach evidence where a probe already exists or is a trivial re-run
(C3 48 → 32; floor 32).** 16 rows: the S-family structural rows
(`GLOBAL.S1`, `4x4.S1`, `4x3.S1`, `GLOBAL.S3a`, `4x4.S3a`, `4x3.S3a` — colex
round-trips and legal-count re-runs, all cheap and deterministic), the Benson
rows (`3x3.S2-impl`, `4x3.S2`), the per-size auditor rows (`3x2.F1`,
`3x2.F3`, `3x2.F4`, `3x3.F4`, `4x3.F4` — the 3×2 log already exists at
`docs/evidence/GLOBAL-AUDITOR/consist-3x2-2026-07-30.log`, re-point and
re-run the rest), and `GLOBAL.FP3`/`4x3.FP3`/`GLOBAL.B1-AUDIT` (finite-lattice
argument + the sweep records, committed as probes).

**Step 2 — attach evidence from committed audits/findings (C3 32 → 18; floor
18).** 14 rows: the ADR-0006 validation family (`GLOBAL.ADR0006-PRED/LEMMAS/
TEST/PRUNEALL` — `docs/audits/2026-07-30-eye-prune-validation.md` + `.stdout`
exist, promotion is a copy under `docs/evidence/` plus a re-point), the
fresh-start-vs-exact comparisons (`2x2.C1`, `3x2.C1` — the T13 evidence dir
and T104's Python kernel), the 3×3 leak falsification (`3x3.C3`, `3x3.E3` —
re-run the committed E2 harness), the exhaustive vb/vw sweep (`QA-021`,
`4x4.FP1-C3` — commit the run log), and four statements-about-the-record rows
(`GLOBAL.ADR0008-HOLE`, `GLOBAL.ADR0009-HONESTY`,
`GLOBAL.ADR0010-SOUND`, `GLOBAL.MEMO-XROOT` — provenance notes).

**Step 3 — demote the irreducible residue (C3 18 → 0; floor 0).** The 18 rows
whose "evidence" is an argument, a source-reading or a methodological ruling
(`CODE.ADR0011-FMT`, `CODE.ADR0011-GATE`, `CODE.M4A-HARNESS`, `CODE.VB-STUBS`,
`GLOBAL.ADR0003-AREA`, `GLOBAL.ADR0004-TERM`, `GLOBAL.ADR0005-PASS`,
`GLOBAL.ADR0009-NOEYE`, `GLOBAL.ADR0014-PURE`, `GLOBAL.CALIB-LESSON`,
`GLOBAL.E1`, `GLOBAL.E2-POLICY`, `GLOBAL.E2-SANITY`, `GLOBAL.LEAK`,
`GLOBAL.MIGOS-RULE`, `GLOBAL.P2`, `GLOBAL.PASS-NOKO`, `QA-025`) are demoted
PROVEN → CLAIMED, per the register's own doctrine — *a written argument is not
proven by writing it* (the AXIOMS rows are CLAIMED at birth for exactly this
reason; C8 holds PROVEN hostage to mutation adequacy). Each demotion is an
Orchestrator ruling with an independent seat's agreement (verify-then-promote
applies in reverse). At floor 0, C3 fails on any future PROVEN row without
committed evidence — the intended end state, and the reason absorptions must
land with their evidence attached.

**Ordering rationale (why this does not wedge):** step 0 fixes the three
calibration fixtures before touching the register; the floor file moves only
in lockstep with the register; step 1 and 2 never raise any count (they only
convert prose to probes); step 3's demotions lower C3 monotonically. The only
counts that move at step 0 — C1a (10→0), C2 (14→lower), C4 (46→lower), C3
(76→48) — all move *down*, which no floor blocks.

## 3. Summary 2 — expected register size

**334 → 202 rows** (201 LIVE + 1 DISPUTED), by: 106 ARCHAEOLOGY + 16 NOTE +
10 BOGUS = **132 rows moved to `archives/register/`**. The 1 DISPUTED row
(`GLOBAL.I5-SCC-CONTAIN`) stays in the live register pending the Orchestrator's
mapping adjudication. Nothing is deleted; the count is the live-register
count only.

## 4. Summary 3 — the archive layout

Everything leaving the live register moves to `archives/register/`, preserved
in full (operator ruling 2026-08-04: move, never delete — this is why pruning
is safe):

```
archives/register/
  INDEX.md              ← reader's entry point: ID → class → epitaph → path
  families/             ← one prose epitaph per family (ruleset-choice,
                           old-artifact, player, process, design,
                           crisis-diagnostic, absorption): what was tried,
                           what it cost, why not to repeat it
  rows/<ID>.md          ← one file per moved row: the full 11-column register
                           row, the full claim text, the move reason, and
                           the row's epitaph (132 files)
```

- **Epitaph format** — one line, `<what was tried> — <what it cost> — <why not
  to repeat>`. Example, `4x4.M4`: *"Measured the ko-sensitive census on the
  writes-on checkpoint — the project's most-cited datum, on an artifact whose
  values are disowned; re-derive on the k=1 table, never this one."*
- **Reader path** — old prose cites `4x4.M4` → `archives/register/INDEX.md`
  → epitaph + `archives/register/rows/4x4.M4.md` for the full row. The live
  register carries one pointer line in §2 ("rows moved per
  `register-triage-2026-08-04.md` — see `archives/register/INDEX.md`"), so a
  reader never has to guess where a retired ID went.
- **claimlint integration** — C4 resolves IDs listed in `INDEX.md` (one-line
  change, §2 step 0.4), so archived IDs read as archived, not dangling.

## 5. Summary 4 — the three highest-value re-derivations (tree order from Z)

Scanned top-down from Z (AXIOMS.md §3), picking the nodes whose load-bearing
claims are unevidenced. Register order would re-derive dead ends; tree order
re-derives the spine.

1. **Z-R-TIE — the Markovian state-sufficiency test (`QA-023` C1;
   `GLOBAL.H1-MARKOV`).** §3.2's TIE node, the first node in tree order whose
   load-bearing claim is untested: C1 has never been run with *contrasting*
   histories — the history generator misses the shortest arrival in 93% of
   states with ~62% shared prefixes (2B-3-AUDIT). The witness hand-check
   (`QA023-C1-WITNESS`, complete 2026-07-29, two independent implementations,
   node-for-node agreement) closed the first-revisit-semantics falsification
   at 3×2; the fresh-start reading is still untested. Re-derivation: a
   contrast-rich history generator (shortest-arrival-first sampling) + the C1
   probe on the corrected kernel, probe and log committed under
   `docs/evidence/QA-023/`. The node's [F] — a state where Markovianity fails —
   is currently untested.
2. **Z-STATE-KEY — adversarial key parity (the G1/G3 gap).** §3.3's key
   node. `CODE.KEY-AGREEMENT`'s own caveat: first-legal-move self-play
   under-covers cycle-intensive ko positions; full four-component key parity
   under adversarial move selection is unverified. The T178/T193/T265
   producer/consumer key-disagreement family is the project's most expensive
   bug class, and `GLOBAL.BATTERY-GAPS` records zero battery coverage on
   Z-R-STATE/Z-STATE-KEY. Re-derivation: the T273 kernel extraction plus an
   adversarial move-selection differential harness (extend the 13 differential
   tests from first-legal-move to cycle-intensive lines).
3. **Z-CONVERGE-FIX at 4×4 — the #2 auditor on the writes-off k=1 build.**
   §3.4's fix node at the headline goban. `4x4.FP1` checks 1–2 UNTESTED, check
   3 sample-based; `4x4.F3`/`4x4.F2`/`4x4.D3` UNTESTED; and the standing
   AGENTS.md mandate — *a "sound by construction" claim without an auditor run
   is INSUFFICIENT: the last bug (`ko_ref >= d`) looked obviously correct and
   was wrong* — is exactly what the tree-map §5.6 calls the outstanding
   residue of T274. Re-derivation: `RETRO_CONSIST` + an exhaustive
   Bellman-identity sweep on the completed writes-off 4×4 regen, which also
   unblocks Z-TABLE-FAITHFUL (`4x4.C1`) and the deliverable itself.

**Standing first gap, noted not counted:** Z-R (joint well-definedness, §3.2
root) has *no row at all* (tree-map §5.1) — the axioms collectively defining a
self-consistent, computable ruleset was never evidenced. That is new work, not
a re-derivation, so it is listed here rather than in the three above.

## 6. Findings — things this triage surfaced that are not the triage itself

1. **C4 drift**: 46 dangling IDs today vs 39 in the brief (2026-08-04). The
   register grew 11 rows in between (T337 S4, T359, T344 absorptions). C3
   (76) and C1a (10) are stable. Every number above cites its run (the
   claimlint run at HEAD before this task).
2. **tree-map §3 denominator is stale**: it says 323 rows; §1 header and C9
   both say 334. The §3 table predates the absorptions; C9 is the authority
   and passes — the prose needs a refresh when the triage is executed.
3. **`QA-023` register prose is stale on the witness**: the row says task
   `QA023-C1-WITNESS` remains open, but it completed 2026-07-29 —
   `docs/evidence/QA-023/c1-witness-handcheck-2026-07-29.md` hand-verified the
   (178,0,6,0) witness with two independent implementations, node-for-node
   agreement. The C1 first-revisit falsification at 3×2 is hand-verified; what
   still blocks the fresh-start reading is the contrast generator (93% miss
   rate), not the witness.
4. **`GLOBAL.I5-SCC-CONTAIN` mapping inconsistency** (the DISPUTED row): the
   tree-map retires it with no stated family, yet it is the I5 battery PASS at
   3×2/4×3/4×4 that G3 acceptance needs, and its siblings are mapped
   (`4x4.I5-FEAS` → Z-STATE-REACH, `3x2.I5-CAL` → Z-AUDIT). Either the mapping
   is wrong or the retirement is; the Orchestrator rules.
5. **Calibration fixtures name moving rows** (§2 step 0.1): `GLOBAL.F2` (C1a
   known-bad, C5 known-good) and `GLOBAL.R1` (C6 synthetic good-tag) are
   compile-time constants in `src/claimlint.zig:183-184,192,206-207`. This is
   the one real wedge risk in the whole plan and it is handled by ordering.
6. **C4 will flood unless the archives index is wired** (§2 step 0.4): 132
   moved IDs are cited by old prose (historical narrative is *why* they were
   famous); without the resolution rule they become 132 ghost IDs.
7. **Pre-existing, untouched**: the working tree carries T366's uncommitted
   work (`findings/T366-engine-kifu.json` — the C7 non-conforming file,
   missing its `claims` key — plus `src/t366_evse.zig`,
   `src/vb_closure.zig`, `docs/evidence/ENGINE-VS-ENGINE/`). T354 does not
   touch any of it; `tools/git-commit-mine` commits only this task's files.
8. **The two C4-unreferenced rows** (`WZO2-4X4-VALID`, `WZO2.I2-CLEAN`) are
   LIVE (mapped) — unreferenced because recent absorptions. Recommended:
   the battery docs should cite `WZO2.I2-CLEAN` so the I2 cell's evidence is
   reachable.

## 7. Bars

- **Every row classified**: 334/334 in §1 — no skips.
- **No status promotions proposed**: the only status changes proposed are
  moves *out* of the register and demotions (PROVEN → CLAIMED, step 3);
  promotion is gated on mutation adequacy (DIRECTION Amendment 2 edge 5) and
  is not this row's business.
- **`claims: []` and `new_rows: []`** in both `findings/T354-*.json`.
- **claimlint floor unmoved**: this task edits neither the register nor the
  floor file; claimlint at HEAD before and after this task is byte-identical
  in every counter (334 rows; C1a 10; C2 14; C3 76; C4 46/2; C9 0;
  calibration PASS).
