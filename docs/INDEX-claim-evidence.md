# INDEX — claim-to-evidence cross-reference (generated)

```
Task: n/a · Role: generator · Model: n/a · Date: 2026-08-02
Source: docs/epistemic/CLAIMS.md (303 claims)
```

**Generated from `docs/epistemic/CLAIMS.md`.** Reproduce with:

    python3 tools/gen-indices

---

## How to use this

1. Find your claim ID below
2. Status + evidence paths are listed directly
3. For the full dependency graph (edges to parent/child claims), see [INDEX-claim-deps.md](INDEX-claim-deps.md)
4. For task→claim mapping, see [INDEX-claim-task.md](INDEX-claim-task.md)
5. Run `bin/weizigo-claimlint` for machine-readable dependency analysis

---

## Claim → evidence

| claim ID | status | evidence |
|---|---|---|
| `2x2.B1` | CLAIMED | `leak-crisis.md:86-101`. **No durable evidence file — primary evidence (`untracked/T02-minimax.md`) lost; only a prose summary survives. Downgraded PROVEN→CLAIMED 2026-07-29 (evidence-integrity sweep).** |
| `2x2.BASICKO-TIE` | MEASUREMENT | `docs/evidence/QA-026/PROVENANCE.md`; `docs/evidence/QA-026/exp4-solve-2026-07-29.stdout`; `docs/audits/2026-07-30-audit-2x2-mismatch.md` |
| `2x2.C1` | PROVEN | `leak-crisis.md:24`; `PROGRESS.md:126` |
| `2x2.C3` | MEASUREMENT | `leak-crisis.md:72` |
| `2x2.EXACT` | MEASUREMENT | `retrograde-3x3.md:74-82` |
| `2x2.F2` | MEASUREMENT | `retrograde-3x3.md:197-203` |
| `2x2.M4` | MEASUREMENT | `ko-sensitive-chainability.md:50` (`bin/weizigo-chainability artifacts/oracle-2x2.wzo`) |
| `2x2.R1` | MEASUREMENT | `ruleset-options.md:91,163`; `retrograde-3x3.md:44-49` |
| `2x2.R3` | MEASUREMENT | `ruleset-options.md:91,98` |
| `2x2.T12` | MEASUREMENT | `4x4/EPISTEMIC.md:255-257,287-288` |
| `3x2.B1` | CLAIMED | `leak-crisis.md:86-101`. **No durable evidence file — primary evidence (`untracked/T02-minimax.md`) lost; only a prose summary survives. Downgraded PROVEN→CLAIMED 2026-07-29 (evidence-integrity sweep).** |
| `3x2.BASICKO-TIE` | MEASUREMENT | `docs/evidence/QA-026/PROVENANCE.md`; `docs/evidence/QA-026/exp4-solve-2026-07-29.stdout`; `docs/audits/2026-07-30-audit-2x2-mismatch.md` |
| `3x2.C1` | PROVEN | `leak-crisis.md:24`; `c2-falsification-3x2.md:56-57` (0/540 L==H fresh-start mismatches) |
| `3x2.C3` | MEASUREMENT | `leak-crisis.md:73` |
| `3x2.EXACT` | MEASUREMENT | `retrograde-3x3.md:50-52,141` |
| `3x2.F1` | PROVEN (falsification) | `consistency-audit.md:25-34`; `0013:15-19`; `4x4/EPISTEMIC.md:49-52` |
| `3x2.F3` | PROVEN (necessary condition) | `consistency-audit.md:30`; `0013:15-19` |
| `3x2.F4` | PROVEN | `0013:88-91` (3×2/3×3/4×3 group) |
| `3x2.I5-CAL` | MEASUREMENT (with the not-reproduced verdicts stated) | `docs/epic-01-markovian/sprints/verify-battery/archive/T171-final.md`; `docs/epic-01-markovian/sprints/verify-battery/archive/T171-audit.md`; `src/vb_graph.zig:988-1015` |
| `3x2.M4` | MEASUREMENT | `ko-sensitive-chainability.md:51` |
| `3x2.R1` | MEASUREMENT | `ruleset-options.md:92,164` |
| `3x2.R3` | MEASUREMENT | `ruleset-options.md:92,99-101` |
| `3x2.T13` | PROVEN (falsification) | `docs/evidence/T13/probe-reimplementation-2026-07-30.md` §4,§8; `docs/evidence/T13/t13_probe.py`, `zig_t13_replay.zig`; `docs/research/c2-falsification-3x2.md:15-16,45-95` |
| `3x3.ANCHOR` | MEASUREMENT | `retrograde-3x3.md:183-185`; `0008:45-47` |
| `3x3.B1` | CLAIMED | `leak-crisis.md:56-61,86-101`; `4x4/EPISTEMIC.md:60-62`. **No durable evidence file — primary evidence (`untracked/T02-minimax.md`) lost; only a prose summary survives. Downgraded PROVEN→CLAIMED 2026-07-29 (evidence-integrity sweep).** |
| `3x3.BASICKO-TIE` | MEASUREMENT | `docs/evidence/QA-026/3x3/PROVENANCE.md`; `docs/evidence/QA-026/3x3/exp5-solve-2026-07-29.stdout`; `docs/audits/2026-07-30-audit-2x2-mismatch.md` |
| `3x3.BRACKET` | MEASUREMENT | `retrograde-3x3.md:102-110`; `ruleset-options.md:211` |
| `3x3.C1` | CLAIMED | `PROGRESS.md:210` |
| `3x3.C2` | UNTESTED | `PROGRESS.md:212-213` |
| `3x3.C3` | PROVEN (falsification) | `leak-crisis.md:36,74-79`; `4x4/EPISTEMIC.md:55-66` |
| `3x3.E2-RUN1` | MEASUREMENT | `leak-crisis.md:36,74`; `4x4/EPISTEMIC.md:58`; `open-hypotheses:289` |
| `3x3.E2-RUN2` | MEASUREMENT | `PROGRESS.md:128`; the D-1 ruling, recorded in §6-D1 of this file. **No run log is committed** — the 8,000-game output exists nowhere in git, so this row is C3-class debt: the number survives, the run does not |
| `3x3.E3` | PROVEN | `leak-crisis.md:54-55` |
| `3x3.F2` | MEASUREMENT | `retrograde-3x3.md:181-196` |
| `3x3.F4` | PROVEN | `0013:88-91` |
| `3x3.FWD-SPOT` | MEASUREMENT | `retrograde-3x3.md:128-135` |
| `3x3.H1-CENSUS` | PROVEN | `docs/evidence/GLOBAL.H1-CENSUS/3x3-standard.txt`; `docs/evidence/GLOBAL.H1-CENSUS/PROVENANCE.md`; `kostate-census-2026-07-28.md:21,201-218`; calibration at 3×3: `3x3-ko-disabled.txt`, `3x3-broken-every_capture.txt` (+60%), `3x3-broken-every_move.txt` (+84%) |
| `3x3.M1` | MEASUREMENT | `ruleset-options.md:211`; `retrograde-3x3.md:66` |
| `3x3.M4` | MEASUREMENT | `ko-sensitive-chainability.md:52` |
| `3x3.S2-impl` | PROVEN | `PROGRESS.md:203` |
| `4x3.BRACKET` | MEASUREMENT | `4x3/EPISTEMIC.md:43-44`; `ruleset-options.md:212` |
| `4x3.C1` | CLAIMED | `4x3/EPISTEMIC.md:32` |
| `4x3.C2` | UNTESTED | `4x3/EPISTEMIC.md:33` |
| `4x3.C3` | UNTESTED | `4x3/EPISTEMIC.md:34` |
| `4x3.F1` | CLAIMED | `4x3/EPISTEMIC.md:35,48-50` |
| `4x3.F2` | UNTESTED | `4x3/EPISTEMIC.md:36` |
| `4x3.F4` | PROVEN | `0013:88-91` |
| `4x3.FP1` | CLAIMED | `4x3/EPISTEMIC.md:30` |
| `4x3.FP3` | PROVEN | `4x3/EPISTEMIC.md:31` |
| `4x3.H1-CENSUS` | PROVEN | `docs/evidence/GLOBAL.H1-CENSUS/4x3-standard.txt`; `docs/evidence/GLOBAL.H1-CENSUS/PROVENANCE.md`; `kostate-census-2026-07-28.md:22,220-226` |
| `4x3.M1` | MEASUREMENT | `4x3/EPISTEMIC.md:40`; `ruleset-options.md:212` |
| `4x3.M2` | MEASUREMENT | `4x3/EPISTEMIC.md:41` |
| `4x3.M3` | MEASUREMENT | `4x3/EPISTEMIC.md:42` |
| `4x3.M4` | MEASUREMENT | `ko-sensitive-chainability.md:53` |
| `4x3.S1` | PROVEN | `4x3/EPISTEMIC.md:24` |
| `4x3.S2` | PROVEN | `4x3/EPISTEMIC.md:25` |
| `4x3.S2-impl` | UNTESTED | `4x3/EPISTEMIC.md:26` |
| `4x3.S3a` | PROVEN | `4x3/EPISTEMIC.md:27` (the caveat is definitional — A094777 is an n-by-n sequence; recorded by T143 finding M5, encoded as the nullable oeis_legal_reference field in the verify-battery M1 design) |
| `4x3.S3b` | UNTESTED | `4x3/EPISTEMIC.md:28` |
| `4x3.S4` | UNTESTED (`⬜ᴵᴺᴴ`) | `4x3/EPISTEMIC.md:29` |
| `4x3.TANGLE` | MEASUREMENT | `ruleset-options.md:228-230` |
| `4x4.A-1` | FALSE-AS-SCOPED | `corrections:19-62`; commit `753584f`. **Remediated:** `regressions/README.md` now carries the corrected wording (verified 2026-07-28; `corrections:60-62`'s line-21 citation is stale) |
| `4x4.A-2` | FALSE-AS-SCOPED (category error — every blundering node is KO_SENSITIVE, i.e. outside C2's scope) | `corrections:66-96` |
| `4x4.A-3` | FALSE-AS-SCOPED (the player is not fresh-start-perfect in the ko-sensitive region: node's own V0 = −3, chosen child = −16) | `corrections:99-132`; `regressions/4x4-black-win-after-ko.txt:74`. **Remediated:** `src/gtp.zig:42` now states "neither history-perfect NOR fresh-start-perfect" and `regressions/README.md:72,81` carries the correction (verified 2026-07-28; `corrections:107,130-132`'s `gtp.zig:37` citation is stale) |
| `4x4.ANCHOR` | MEASUREMENT | `retrograde-4x4.md:74-84` |
| `4x4.B16-GAME` | MEASUREMENT | `retrograde-4x4.md:103-152` |
| `4x4.B39` | FALSE-AS-SCOPED (measurement artifact) | `arena-4x4-undef.md:4-8,27-44` |
| `4x4.B43` | MEASUREMENT | `arena-4x4-undef.md:57-91` |
| `4x4.B43-DIV` | MEASUREMENT | `arena-4x4-undef.md:87-91` |
| `4x4.BASICKO-TIE` | MEASUREMENT | `docs/evidence/QA-026/4x4/PROVENANCE.md`; `docs/evidence/QA-026/4x4/exp6-solve-2026-07-29.stdout` |
| `4x4.BRACKET` | MEASUREMENT | `4x4/EPISTEMIC.md:249`; `ruleset-options.md:213` |
| `4x4.C1` | UNTESTED | `4x4/EPISTEMIC.md:141-147`; `PROGRESS.md:210-211` |
| `4x4.C2` | UNTESTED (status conflict, §6-D3) | `4x4/EPISTEMIC.md:46,98-110`; `PROGRESS.md:212-213`; `arena-4x4-undef.md:87-91` |
| `4x4.C3` | UNTESTED (status conflict, §6-D2) | `4x4/EPISTEMIC.md:55-66` |
| `4x4.COMPLETE-2026-07-21` | FALSE-AS-SCOPED | `retrograde-4x4.md:1-13`; retracted by `PROGRESS.md:267-270`, `0013:126-128`, `AGENTS.md:54-57` |
| `4x4.CYCLE-INSENS` | CLAIMED | `retrograde-4x4.md:77-80` |
| `4x4.D3` | UNTESTED | `4x4/EPISTEMIC.md:175-183,328` |
| `4x4.DRIVER` | MEASUREMENT | `retrograde-4x4.md:36-62` |
| `4x4.F1` | CLAIMED | `4x4/EPISTEMIC.md:27-28,49-52` |
| `4x4.F2` | UNTESTED | `4x4/EPISTEMIC.md:127-132` |
| `4x4.F3` | UNTESTED | `4x4/EPISTEMIC.md:111-126` |
| `4x4.F4` | UNTESTED | `4x4/EPISTEMIC.md:168-174` |
| `4x4.FP1` | UNTESTED (checks 1–2); check 3 PASSES | `4x4/EPISTEMIC.md:69-97` |
| `4x4.FP1-C1` | UNTESTED | `4x4/EPISTEMIC.md:71-73` |
| `4x4.FP1-C2` | UNTESTED | `4x4/EPISTEMIC.md:74-75` |
| `4x4.FP1-C3` | PROVEN (as scoped) | `4x4/EPISTEMIC.md:76-88`; `ko-sensitive-chainability.md:60-69` |
| `4x4.FP3` | UNTESTED (`⬜ᴵᴺᴴ`) | `4x4/EPISTEMIC.md:37-43` |
| `4x4.G-CENSUS` | MEASUREMENT | `docs/evidence/GLOBAL.H1-CENSUS/4x4-standard.txt`; `docs/evidence/GLOBAL.H1-CENSUS/4x4-ko-disabled.txt`; `docs/epic-01-markovian/sprints/oracle-v2/pass0/design-M1.md` (§F2 byte-budget derivation) |
| `4x4.GREEDY-BIAS` | CLAIMED | `PROGRESS.md:160-164`; `ko-sensitive-chainability.md:151-158` |
| `4x4.GTP-DEFECT` | PROVEN | `PROGRESS.md:148-167`; `ko-sensitive-chainability.md:141-150` |
| `4x4.HISTPERF-CHEAP` | MEASUREMENT | `retrograde-4x4.md:147-151` |
| `4x4.I5-FEAS` | CLAIMED (projection; the calibration section is MEASUREMENT) | `docs/epic-01-markovian/sprints/verify-battery/archive/i5-feasibility.md`; `docs/evidence/QA-023/census-reconciliation.md` |
| `4x4.KO-CENSUS` | MEASUREMENT | `docs/research/ko-composition-census-2026-07-30.md`; `src/ko_cycle_census.zig` |
| `4x4.KO-RULE-NULL` | PROVEN (these two games) | `ko-sensitive-chainability.md:102-118`; `4x4/EPISTEMIC.md:202-205` |
| `4x4.M1` | MEASUREMENT | `4x4/EPISTEMIC.md:186`; `ruleset-options.md:116` |
| `4x4.M2` | MEASUREMENT | `4x4/EPISTEMIC.md:246-247`; `retrograde-4x4.md:21` |
| `4x4.M3` | MEASUREMENT | `4x4/EPISTEMIC.md:248`; `retrograde-4x4.md:23-25,33-34` |
| `4x4.M4` | MEASUREMENT | `4x4/EPISTEMIC.md:187-198`; `ko-sensitive-chainability.md:54,45` |
| `4x4.M5` | PROVEN | `4x4/EPISTEMIC.md:199-205`; `ko-sensitive-chainability.md:126-140` |
| `4x4.M6` | MEASUREMENT | `4x4/EPISTEMIC.md:206-245`; `ko-sensitive-chainability.md:163-197` |
| `4x4.M6-EXCESS` | CLAIMED | `4x4/EPISTEMIC.md:227-231`; `ko-sensitive-chainability.md:213-234` |
| `4x4.M6-FLOOR` | PROVEN (on the swept artifact) | `4x4/EPISTEMIC.md:222-226`; `ko-sensitive-chainability.md:198-211` |
| `4x4.M6-SCREEN` | CLAIMED | `4x4/EPISTEMIC.md:232-235`; `ko-sensitive-chainability.md:236-244` |
| `4x4.P3` | MEASUREMENT | `4x4/EPISTEMIC.md:53-54` |
| `4x4.PARALLEL` | MEASUREMENT | `arena-4x4-undef.md:20-26`; `PROGRESS.md:211,244-245` |
| `4x4.R1` | CLAIMED | `4x4/EPISTEMIC.md:22` |
| `4x4.R3` | PROVEN (falsification) | `ruleset-options.md:107-127`; `4x4/EPISTEMIC.md:23,47-48` |
| `4x4.REGR-CLIFF` | MEASUREMENT | `ko-sensitive-chainability.md:126-140` |
| `4x4.REGR-SYM` | PROVEN | `ko-sensitive-chainability.md:121-124` |
| `4x4.S1` | PROVEN | `4x4/EPISTEMIC.md:17` |
| `4x4.S2-impl` | UNTESTED | `4x4/EPISTEMIC.md:158-167` |
| `4x4.S3a` | PROVEN | `4x4/EPISTEMIC.md:18-22`; `retrograde-4x4.md:20,28` |
| `4x4.S3b` | UNTESTED | `4x4/EPISTEMIC.md:135-140` |
| `4x4.S4` | UNTESTED (`⬜ᴵᴺᴴ`) | `4x4/EPISTEMIC.md:31-36` |
| `4x4.SINGLE` | MEASUREMENT | `4x4/EPISTEMIC.md:250`; `ruleset-options.md:213` |
| `4x4.TANGLE` | MEASUREMENT | `ruleset-options.md:216-218` |
| `4x4.V1-INVSYM-BROKEN` | PROVEN (independent re-implementation, deduplicated count) | `docs/evidence/BATTERY/triage-T260.md`; `findings/T260-fleet-triage.json` |
| `4x4.VALBATTERY` | MEASUREMENT | `retrograde-4x4.md:86-88` |
| `4x4.WRITESOFF` | MEASUREMENT | `4x4/EPISTEMIC.md:236-242`; `ko-sensitive-chainability.md:246-254` |
| `CODE.ADR0011-DTT` | CLAIMED | `0011:63-65`; `0009:138-146` |
| `CODE.ADR0011-FMT` | PROVEN | `0011:21-37`; `corrections:153-158`; `src/artifact.zig:23-53` |
| `CODE.ADR0011-GATE` | PROVEN | `0011:39-46` |
| `CODE.BATTERY-STUBBED` | PROVEN (source inspection + the stub output files) | `docs/evidence/BATTERY/fleet.md`; `findings/T258-context.json` |
| `CODE.GTP-KOKEY` | PROVEN (root cause read in source, fix verified by transcript replay) | `docs/evidence/ORACLE-V2/ko-key-mismatch-T265.md`; `docs/evidence/ORACLE-V2/human-game-{1,2}.gtp`; `src/gtp.zig` (`626ec55`) |
| `CODE.M4A-HARNESS` | PROVEN (by inspection) | `src/oracle_v2_accept.zig:19-20,493,628,682-700`; `build.zig:172-180` |
| `CODE.S4-XVAL` | MEASUREMENT | `0008:63-66` |
| `CODE.UNDEF` | PROVEN | `arena-4x4-undef.md:20-56`; `0011:30-35` |
| `CODE.VB-BLINDGAPS` | PROVEN (blind-reimplementation audit, committed) | `docs/evidence/CODE.VB-BLINDGAPS/T172-blind-analysis.md`; `src/vb_fixpoint.zig:545-547` |
| `CODE.VB-STUBS` | PROVEN (by inspection) | `src/verify_battery.zig:26-27,357-373`; `src/vb_fixpoint.zig:502-547`; `docs/epic-01-markovian/sprints/verify-battery/archive/T168-notes.md` |
| `CODE.WZO1-DTT-UNSET` | PROVEN (I7 across four gobans + independent spot-check + positive contrast artifact) | `docs/evidence/BATTERY/triage-T260.md`; `docs/evidence/BATTERY/fleet.md` |
| `CODE.WZO2-CHAINSHORT` | PROVEN (by inspection; the code is committed) | `src/gtp.zig:286-288` |
| `CODE.WZO2-INCOMPLETE` | PROVEN (direct artifact scan + self-play contradiction) | `findings/T261-m4b-triage.json`; `docs/evidence/ORACLE-V2/m4b-triage-T261.md`; `docs/evidence/ORACLE-V2/human-games-2026-08-02.md` |
| `CODE.WZO2-PASSBIT` | PROVEN (measured, both failing checks reproduced with counts; root cause read in the source and fixed) | `docs/evidence/ORACLE-V2/m4a-accept-T193-2026-08-01.md`; `docs/evidence/ORACLE-V2/m4a-accept-T193-2026-08-01.stdout`; `src/oracle_v2_build.zig:387` (`5deec6b`) |
| `CODE.WZO2-UNRUN` | PROVEN (by inspection, as of 2026-08-01 P2 delivery; **overtaken by events the same day** — the artifact was built and M4a ran, see `CODE.WZO2-PASSBIT`. The register has no status for "true when written, obsolete now"; the supersession is carried in the claim text) | `src/oracle_v2_build.zig:188,240,469`; `src/artifact2.zig:42,177,316-319` |
| `GLOBAL.ADR0002-SEQ` | UNTESTED | `0002:36-38`; `0005:127-130` |
| `GLOBAL.ADR0003-AREA` | PROVEN | `0003:13-16,21-24` |
| `GLOBAL.ADR0004-P1` | PROVEN | `0004:20`; `0003:17-20` |
| `GLOBAL.ADR0004-TERM` | PROVEN | `0004:16-19,31-34` |
| `GLOBAL.ADR0005-CACHE` | FALSE-AS-SCOPED | `0005:90-93`; downgraded `0008:32-38`; falsified `0013:20-44` |
| `GLOBAL.ADR0005-DBLPASS` | CLAIMED (argued, not machine-checked) | `0005:61-63` |
| `GLOBAL.ADR0005-PASS` | PROVEN | `0005:47-50` |
| `GLOBAL.ADR0005-SUBBOARD` | PROVEN | `0005:5-9`; `AGENTS.md:80-81` |
| `GLOBAL.ADR0006-EYE` | CLAIMED | `0006:27-49`; `docs/audits/2026-07-30-eye-prune-validation.md` |
| `GLOBAL.ADR0006-LEMMAS` | PROVEN (per goban listed) | `2026-07-30-eye-prune-validation.md` §8 (0 violations; 1,362,424 eyes at 4×4) |
| `GLOBAL.ADR0006-PRED` | PROVEN | `2026-07-30-eye-prune-validation.md` §3 (17/17 fixtures; 0/3,999,936 cross-impl mismatches) |
| `GLOBAL.ADR0006-PRUNEALL` | PROVEN (per goban listed) | `2026-07-30-eye-prune-validation.md` §4, §J |
| `GLOBAL.ADR0006-TEST` | PROVEN (executed 2026-07-30, scoped) | `2026-07-30-eye-prune-validation.md` §6 |
| `GLOBAL.ADR0007-AB` | PROVEN | `0007:25-28` |
| `GLOBAL.ADR0007-BACKEDGE` | PROVEN | `0007:30-33`; `0009:41-46` |
| `GLOBAL.ADR0007-TENSION` | CLAIMED (open in ADR-0007; resolved by `GLOBAL.ADR0009-NOEYE`, never recorded as such in ADR-0007) | `0007:37-43` |
| `GLOBAL.ADR0008-HOLE` | PROVEN (as a statement about the argument) | `0008:32-38` |
| `GLOBAL.ADR0009-DTT` | PROVEN | `0009:138-146` |
| `GLOBAL.ADR0009-HONESTY` | PROVEN (as a statement about the argument) | `0009:78-89` |
| `GLOBAL.ADR0009-NOEYE` | PROVEN | `0009:109-124`; `AGENTS.md:83-84` |
| `GLOBAL.ADR0009-SUCC` | PROVEN (design argument) | `0009:28-46` |
| `GLOBAL.ADR0010-CUT` | CLAIMED | `0010:29-30,16-18`; `docs/decisions/0015-bracket-cut-soundness-search-vs-real-history.md` |
| `GLOBAL.ADR0010-SOUND` | PROVEN (as a statement about the argument) | `0010:70-81` |
| `GLOBAL.ADR0012-5X5` | CLAIMED (projection; ADR status is *proposed*, measurements pending) | `0012:3,124-131` |
| `GLOBAL.ADR0012-GATE` | CLAIMED (orphaned — depends on the retracted `4x4.COMPLETE-2026-07-21`; re-point to the Track A writes-off artifact when complete. T128 triage §C1a-8) | `0012:157-159`; `0012:46-49` |
| `GLOBAL.ADR0012-LAYER` | PROVEN (arithmetic) | `0012:91-95` |
| `GLOBAL.ADR0012-PAR` | CLAIMED | `0012:160-166` |
| `GLOBAL.ADR0012-V1` | PROVEN | `0012:99-102` |
| `GLOBAL.ADR0014-DEAD` | CLAIMED | `0014:37-38,42-48,68-71` |
| `GLOBAL.ADR0014-PURE` | PROVEN | `0014:16-25,65-71` |
| `GLOBAL.ADR0015-BURDEN` | CLAIMED | `docs/decisions/0015-bracket-cut-soundness-search-vs-real-history.md`; `docs/decisions/0017-bracket-cut-refutation-attempt-failed.md`; `docs/decisions/0018-bracket-cut-confirmed-unanimous-review-f2-remedy-is-new-task.md`; `untracked/msg/milestone-01-ko-reframe/025-fable-to-all.md`; `0010:16-18,70-93`; `src/retro.zig:464`; `critique-2026-07-28.md:376` |
| `GLOBAL.ADR0016-INHERIT` | CLAIMED (adopted rule — a decision, not a fact) | `docs/decisions/0016-per-board-independence-empirical-vs-structural.md`; `critique-2026-07-28.md:373` |
| `GLOBAL.ANCHOR-DELTA` | CLAIMED | `retrograde-3x3.md:234-238` |
| `GLOBAL.AUDITOR` | PROVEN | `consistency-audit.md:6-23`; `AGENTS.md:63-67`; `0013:117-122`; `docs/evidence/GLOBAL-AUDITOR/PROVENANCE.md`; `docs/evidence/GLOBAL-AUDITOR/consist-3x2-2026-07-30.log` |
| `GLOBAL.AXIOM-AREA` | CLAIMED | `docs/epic-01-markovian/AXIOMS.md` §2 |
| `GLOBAL.AXIOM-BASICKO` | CLAIMED | `docs/epic-01-markovian/AXIOMS.md` §2 |
| `GLOBAL.AXIOM-BELLMAN` | CLAIMED | `docs/epic-01-markovian/AXIOMS.md` §2 |
| `GLOBAL.AXIOM-BRACKET` | CLAIMED | `docs/epic-01-markovian/AXIOMS.md` §2 |
| `GLOBAL.AXIOM-CAPTURE` | CLAIMED | `docs/epic-01-markovian/AXIOMS.md` §2 |
| `GLOBAL.AXIOM-FRESHSTART` | CLAIMED | `docs/epic-01-markovian/AXIOMS.md` §2 |
| `GLOBAL.AXIOM-GEOM` | CLAIMED | `docs/epic-01-markovian/AXIOMS.md` §2 |
| `GLOBAL.AXIOM-KOPASS` | CLAIMED | `docs/epic-01-markovian/AXIOMS.md` §2 |
| `GLOBAL.AXIOM-KOSTATE` | CLAIMED | `docs/epic-01-markovian/AXIOMS.md` §2 |
| `GLOBAL.AXIOM-LH` | CLAIMED | `docs/epic-01-markovian/AXIOMS.md` §2 |
| `GLOBAL.AXIOM-PASS` | CLAIMED | `docs/epic-01-markovian/AXIOMS.md` §2 |
| `GLOBAL.AXIOM-PASSSTATE` | CLAIMED | `docs/epic-01-markovian/AXIOMS.md` §2 |
| `GLOBAL.AXIOM-SCORESIGN` | CLAIMED | `docs/epic-01-markovian/AXIOMS.md` §2 |
| `GLOBAL.AXIOM-STATE` | CLAIMED | `docs/epic-01-markovian/AXIOMS.md` §2 |
| `GLOBAL.AXIOM-STONE` | CLAIMED | `docs/epic-01-markovian/AXIOMS.md` §2 |
| `GLOBAL.AXIOM-SUICIDE` | CLAIMED | `docs/epic-01-markovian/AXIOMS.md` §2 |
| `GLOBAL.AXIOM-TERMINAL` | CLAIMED | `docs/epic-01-markovian/AXIOMS.md` §2 |
| `GLOBAL.AXIOM-TIE` | CLAIMED | `docs/epic-01-markovian/AXIOMS.md` §2 |
| `GLOBAL.B-1` | FALSE-AS-SCOPED (as of the code at 2026-07-27) | `corrections:136-171`; `0013:129-130`; `src/gtp.zig:154-196,90-93,121-132`; `src/artifact.zig:23-53,140,181` |
| `GLOBAL.B1-AUDIT` | PROVEN | `leak-crisis.md:99-101`; `4x4/EPISTEMIC.md:90-97`; `CONCEPTS.md:29-30` |
| `GLOBAL.B1-MULTIFIX` | MEASUREMENT | `leak-crisis.md:93-99` |
| `GLOBAL.B15` | CLAIMED | `artifacts/SHA256SUMS` |
| `GLOBAL.BRUTE-ALIASING` | FALSE (methodological) | `docs/audits/2026-07-30-audit-2x2-mismatch.md` §1,§6; `docs/audits/2026-07-30-audit-2x2-mismatch.py` |
| `GLOBAL.C-1` | FALSE-AS-SCOPED | `corrections:175-201` |
| `GLOBAL.C1` | — (definition) | `CONCEPTS.md:50-53`; `leak-crisis.md:24` |
| `GLOBAL.C2` | FALSE-AS-SCOPED (at 3×2) | `leak-crisis.md:25`; `PROGRESS.md:127`; `AGENTS.md:68-73` |
| `GLOBAL.C3` | FALSE-AS-SCOPED (at 3×3) | `leak-crisis.md:26`; `PROGRESS.md:128`; `CONCEPTS.md:57-61` |
| `GLOBAL.C4` | FALSE-AS-SCOPED | `leak-crisis.md:27`; `PROGRESS.md:129`; `4x4/EPISTEMIC.md:26` |
| `GLOBAL.CALIB-LESSON` | PROVEN (methodological) | `corrections:197-201` |
| `GLOBAL.CERTCORE` | FALSE-AS-SCOPED | `0009:65-67` |
| `GLOBAL.CHAIN-DEF` | — (definition) | `ko-sensitive-chainability.md:24-33` |
| `GLOBAL.CHAIN-KIND` | PROVEN | `ko-sensitive-chainability.md:71-79,198-211`; `corrections:175-201` |
| `GLOBAL.CHAIN-KO` | PROVEN | `ko-sensitive-chainability.md:70-71`; `PROGRESS.md:86-92` |
| `GLOBAL.CHAIN-LH` | PROVEN (on the audited artifacts) | `ko-sensitive-chainability.md:60-69`; `PROGRESS.md:72-82,192-197` |
| `GLOBAL.E1` | PROVEN (methodological) | `leak-crisis.md:164-168` |
| `GLOBAL.E2-POLICY` | PROVEN (bug + fix) | `leak-crisis.md:81-83` |
| `GLOBAL.E2-SANITY` | PROVEN | `leak-crisis.md:48-52` |
| `GLOBAL.E2-VERDICT` | CLAIMED | `leak-crisis.md:38-42,66,172-175` |
| `GLOBAL.F1` | FALSE-AS-SCOPED | `0013:20-44`; `consistency-audit.md:25-34`; `CONCEPTS.md:109` |
| `GLOBAL.F2` | CLAIMED | `CONCEPTS.md:110-112`; `0010:14-38,70-81`; `docs/decisions/0015-bracket-cut-soundness-search-vs-real-history.md` |
| `GLOBAL.F2-REMEDY` | CLAIMED | `docs/research/f2-remedy-design-2026-07-29.md`; `docs/evidence/QA-023/proof-v2-2026-07-28.md`; `docs/decisions/0018-bracket-cut-confirmed-unanimous-review-f2-remedy-is-new-task.md` |
| `GLOBAL.F3` | CLAIMED | `0013:50-65`; `consistency-audit.md:42-51` |
| `GLOBAL.F4` | PROVEN (argument) + MEASUREMENT | `0013:67-116` |
| `GLOBAL.F4-COST` | MEASUREMENT | `0013:92-108` |
| `GLOBAL.FIN-BRACKET` | MEASUREMENT | `retrograde-3x3.md:165-179` |
| `GLOBAL.FIN-NEARTERM` | MEASUREMENT | `retrograde-3x3.md:84-100` |
| `GLOBAL.FIXPOINT-VS-SEARCH` | CLAIMED | `docs/epic-01-markovian/AXIOMS.md` §4 |
| `GLOBAL.FP1` | PROVEN (as mathematics) | `CONCEPTS.md:25-30`; `0009:53-61`; `docs/evidence/GLOBAL-FP1/proof-2026-07-30.md` |
| `GLOBAL.FP2` | CLAIMED | `CONCEPTS.md:31-32`; `0009:65-67,78-89` |
| `GLOBAL.FP2-bounded` | FALSE-AS-SCOPED (at 3×2) | `CONCEPTS.md:33-37` |
| `GLOBAL.FP2-general` | INTRACTABLE (possibly unprovable by finite methods) | `CONCEPTS.md:38-42`; `4x4/EPISTEMIC.md:148-157` |
| `GLOBAL.FP3` | PROVEN | `CONCEPTS.md:43-46`; `4x3/EPISTEMIC.md:31` |
| `GLOBAL.FWD-INTRACT` | PROVEN | `retrograde-3x3.md:17-21,39-58` |
| `GLOBAL.H1-CENSUS` | PROVEN | `docs/evidence/GLOBAL.H1-CENSUS/4x4-standard.txt`; `docs/evidence/GLOBAL.H1-CENSUS/PROVENANCE.md`; `kostate-census-2026-07-28.md:23,228-241`; calibration at 4×4: `4x4-ko-disabled.txt` (known-good), `4x4-broken-every_capture.txt` (known-bad, +91%) |
| `GLOBAL.H1-COMPUTABLE` | FALSE-AS-SCOPED | `docs/evidence/QA-023/probe-fix-2026-07-29.md`; `docs/audits/2026-07-29-2b-6-full-review.md`; `docs/epistemic/qa023-c2-adjudication-2026-07-29.md`; `docs/audits/2026-07-29-qa023-kernel-audit.md`; `docs/evidence/QA-023/pinrule-sufficiency-2026-07-29.md` |
| `GLOBAL.H1-MARKOV` | UNTESTED | `open-hypotheses:30-118`; `PROGRESS.md:169-183`; `docs/audits/2b-3-audit-*.md`; `docs/epistemic/qa023-c2-adjudication-2026-07-29.md` §3 |
| `GLOBAL.H2` | UNTESTED | `open-hypotheses:122-166` |
| `GLOBAL.H3` | UNTESTED | `open-hypotheses:170-214` |
| `GLOBAL.H3-LOWERBOUND` | MEASUREMENT | `open-hypotheses:172-182`; `ko-sensitive-chainability.md:269-274` |
| `GLOBAL.H4` | CLAIMED (partial) | `open-hypotheses:217-261`; `PROGRESS.md:77-81,221-223` |
| `GLOBAL.H4a` | UNTESTED | `open-hypotheses:224-228,233-235` |
| `GLOBAL.H4b` | UNTESTED | `open-hypotheses:229-231,236-239` |
| `GLOBAL.H5` | CLAIMED | `open-hypotheses:265-313` |
| `GLOBAL.H5a` | CLAIMED | `open-hypotheses:274-279` |
| `GLOBAL.H5a-CHILD` | CLAIMED | ruling D-3, 2026-07-28; EXP-9 2026-07-29 (`docs/research/h5a-player-mitigation-2026-07-28.md`); `corrections:99-132`; `regressions/4x4-black-win-after-ko.txt:74`; `open-hypotheses:274-279` |
| `GLOBAL.H5a-FALLBACK` | CLAIMED | ruling D-3, 2026-07-28; EXP-9 2026-07-29 (`docs/research/h5a-player-mitigation-2026-07-28.md`); `open-hypotheses:281-284` (the H5(b) history-free-by-theorem argument this reuses); `0004:16-19,31-34` |
| `GLOBAL.H5b` | CLAIMED | `open-hypotheses:281-284` |
| `GLOBAL.H5c` | PROVEN (as an implication) | `open-hypotheses:286-291`; `ko-sensitive-chainability.md:276-281` |
| `GLOBAL.H5d` | CLAIMED | `open-hypotheses:288-289`; `ko-sensitive-chainability.md:288-289`; `AGENTS.md:71-73` |
| `GLOBAL.INVSYM` | PROVEN | `0009:102-107,148-157`; `0008:48-51,54-60`; `AGENTS.md:75-77`; `docs/evidence/GLOBAL-INVSYM/proof-2026-07-30.md` |
| `GLOBAL.LEAK` | PROVEN | `leak-crisis.md:9-14`; `PROGRESS.md:110-121` |
| `GLOBAL.LONGCYCLE` | FALSE-AS-SCOPED | `docs/evidence/QA-023/probe-fix-2026-07-29.md`; `docs/audits/2026-07-29-2b-6-full-review.md`; `docs/epistemic/qa023-c2-adjudication-2026-07-29.md`; `open-hypotheses:92-103` |
| `GLOBAL.MAXGAP` | CLAIMED | `ko-sensitive-chainability.md:94-100`; `PROGRESS.md:98-102` |
| `GLOBAL.MEMO-XROOT` | PROVEN (falsification) | `retrograde-3x3.md:23-37`; `0010:63-66` |
| `GLOBAL.MIGOS-RULE` | PROVEN | `retrograde-3x3.md:222-241` |
| `GLOBAL.ONEMISMATCH-CURE` | FALSE-AS-SCOPED | `AUDIT-DSPro` §2.3; `docs/evidence/QA-023/probe-fix-2026-07-29.md` |
| `GLOBAL.ONEMISMATCH-DIAG` | CLAIMED | `PROGRESS.md:169-183` |
| `GLOBAL.ONEWRITER` | CLAIMED | `AGENTS.md:96-97,150-171` |
| `GLOBAL.P1` | FALSE-AS-SCOPED | `CONCEPTS.md:123`; `4x4/EPISTEMIC.md:24` |
| `GLOBAL.P2` | PROVEN (as scoped) | `CONCEPTS.md:124` |
| `GLOBAL.P3` | FALSE-AS-SCOPED | `CONCEPTS.md:125`; `4x4/EPISTEMIC.md:25` |
| `GLOBAL.PASS-NOKO` | PROVEN (code + independent re-derivation) | `src/exp6_solve.zig:964`; `docs/epic-01-markovian/sprints/oracle-v2/pass0/design-M1.md` (§2.5 invariant) |
| `GLOBAL.PSK-GAP` | PROVEN | `PROGRESS.md:178-181,224-228`; `open-hypotheses:56-61` |
| `GLOBAL.R1` | PROVEN (structural) | `CONCEPTS.md:129`; `AGENTS.md:47-49`; `ruleset-options.md:95-97` |
| `GLOBAL.R2` | PROVEN (argument) + MEASUREMENT | `ruleset-options.md:156-181`; `AGENTS.md:52-53` |
| `GLOBAL.R3` | FALSE-AS-SCOPED | `CONCEPTS.md:130`; `AGENTS.md:50-51` |
| `GLOBAL.REFRAME` | CLAIMED (adopted decision) | `PROGRESS.md:135-146,235-241`; `leak-crisis.md:150-154`; `AGENTS.md:59-62` |
| `GLOBAL.RELEASEFAST` | PROVEN | `AGENTS.md:110-111` |
| `GLOBAL.RNPLY-FORBID` | PROVEN | `ruleset-options.md:42-51` |
| `GLOBAL.RPLY` | PROVEN (falsification) | `ruleset-options.md:53-71` |
| `GLOBAL.RPLY-RETRO` | CLAIMED | `ruleset-options.md:73-81` |
| `GLOBAL.RPLY-TRAP` | PROVEN (argument) | `ruleset-options.md:62-71` |
| `GLOBAL.S1` | PROVEN | `4x4/EPISTEMIC.md:17`; `4x3/EPISTEMIC.md:24` |
| `GLOBAL.S2` | PROVEN | `CONCEPTS.md:10-12`; `4x3/EPISTEMIC.md:25`; `docs/evidence/GLOBAL-S2/PROVENANCE.md` |
| `GLOBAL.S3a` | PROVEN (as scoped) | `CONCEPTS.md:14-16`; `4x4/EPISTEMIC.md:18-22` |
| `GLOBAL.S3b` | CLAIMED | `CONCEPTS.md:17-21` |
| `GLOBAL.S4` | PROVEN | `CONCEPTS.md:20-21`; `0003:13-16`; `docs/evidence/GLOBAL-S4/PROVENANCE.md`; `docs/evidence/GLOBAL-S4/scorer-2026-07-30.py`; `docs/evidence/GLOBAL-S4/verify-2026-07-30.log` |
| `GLOBAL.SWEEPS` | MEASUREMENT | `retrograde-4x4.md:21-22,30-32` |
| `GLOBAL.T06` | MEASUREMENT | `PROGRESS.md:114-115` |
| `GLOBAL.T14.1` | CLAIMED | `PROGRESS.md:238-240` |
| `GLOBAL.TIE-MIGOS` | CLAIMED | `docs/epic-01-markovian/AXIOMS.md` §4 |
| `GLOBAL.UD-1` | CLAIMED | `PROGRESS.md:238-240` → `untracked/SUBAGENTS.md` (**not in git; see §7**) |
| `GLOBAL.UD-2` | CLAIMED | `PROGRESS.md:238-240`; `4x4/EPISTEMIC.md:35,326-327` |
| `GLOBAL.UD-3` | CLAIMED | `PROGRESS.md:238-240` |
| `GLOBAL.Z` | CLAIMED | `docs/epic-01-markovian/AXIOMS.md` §1 |
| `QA-001` | FALSE | `critique-2026-07-28.md:359`; `ko-sensitive-chainability.md:70-71` |
| `QA-002` | FALSE | `critique-2026-07-28.md:360`; `regressions/4x4-black-win-after-ko.txt:74` |
| `QA-003` | FALSE | `critique-2026-07-28.md:361`; `corrections:66-96` |
| `QA-004` | FALSE | `critique-2026-07-28.md:362`; `4x4/EPISTEMIC.md:249` |
| `QA-005` | FALSE | `critique-2026-07-28.md:363`; `ko-sensitive-chainability.md:54` |
| `QA-006` | FALSE | `critique-2026-07-28.md:364`; `ko-sensitive-chainability.md:163-197` |
| `QA-007` | CLAIMED | `critique-2026-07-28.md:365`; `4x4/EPISTEMIC.md:227-231` |
| `QA-008` | UNTESTED | `critique-2026-07-28.md:366`; `4x4/EPISTEMIC.md:236-242` |
| `QA-009` | FALSE | `critique-2026-07-28.md:367`; ruling D-1, 2026-07-28, recorded in §6-D1 of this file |
| `QA-010` | CLAIMED | `critique-2026-07-28.md:368`; `PROGRESS.md:169-183` |
| `QA-011` | CLAIMED | `critique-2026-07-28.md:369`; `open-hypotheses:30-118` |
| `QA-012` | UNTESTED | `critique-2026-07-28.md:370`; `roadmap-2026-07-28.md:302-307`; `docs/research/psk-divergence-2026-07-29.md`; `docs/evidence/QA-012/` |
| `QA-013` | FALSE-AS-SCOPED | `docs/evidence/QA-023/probe-fix-2026-07-29.md`; `docs/audits/2026-07-29-2b-6-full-review.md`; `docs/epistemic/qa023-c2-adjudication-2026-07-29.md`; `critique-2026-07-28.md:371`; `open-hypotheses:92-103` |
| `QA-014` | UNTESTED | `critique-2026-07-28.md:372`; `ko-sensitive-chainability.md:24-33` |
| `QA-015` | CLAIMED (**DECIDED 2026-07-28** — D-2, Opus + GLM; the rule now lives in ADR-0016, and `mixed` was **not** ruled on) | `critique-2026-07-28.md:373`; `docs/decisions/0016-per-board-independence-empirical-vs-structural.md` |
| `QA-016` | FALSE | `critique-2026-07-28.md:374`; `arena-4x4-undef.md:20-26` |
| `QA-017` | CLAIMED | `critique-2026-07-28.md:375`; `reachable-kosensitivity-2026-07-28.md` |
| `QA-018` | CLAIMED | `critique-2026-07-28.md:376`; `0010:16-18`; `src/retro.zig:464`; `docs/decisions/0015-bracket-cut-soundness-search-vs-real-history.md`; `docs/decisions/0017-bracket-cut-refutation-attempt-failed.md`; `docs/decisions/0018-bracket-cut-confirmed-unanimous-review-f2-remedy-is-new-task.md`; `untracked/msg/milestone-01-ko-reframe/025-fable-to-all.md` |
| `QA-019` | FALSE | `critique-2026-07-28.md:377`; `src/retro.zig:2407` |
| `QA-020` | FALSE | `critique-2026-07-28.md:378`; `reachable-kosensitivity-2026-07-28.md`; `docs/evidence/QA-027/4x4/PROVENANCE.md` |
| `QA-021` | PROVEN | `critique-2026-07-28.md:379`; `ko-sensitive-chainability.md:109,116` |
| `QA-022` | FALSE | `docs/evidence/README.md`; `critique-2026-07-28.md:380`; §7 of this file |
| `QA-023` | CLAIMED | `roadmap-2026-07-28.md:302`; `docs/evidence/QA-023/proof.md` (Part A; the computational half is 2×2-only, which `EXP-2-AUDIT-PREREG.md` rejects outright as INCOMPLETE). EXP-2A done 2026-07-28 (Fable 5; REPAIRABLE-GAPS→repaired); EXP-2B (the 3×2 computational half) COMPLETE 2026-07-29 via 2B-0…2B-6. **DO NOT MARK THIS ROW FALSE. The computational half SPLITS: C1 (this row's actual assertion — state-sufficiency) is UNTESTED-FOR-WANT-OF-CONTRAST, because the history generator misses the shortest arrival in 93% of states and its histories share ~62% of prefixes (`2B-3-AUDIT`); C2 (that the common value equals `median(L,TIE,H)`) is FALSIFIED — but C2 is `QA-026`'s content, NOT this row's. C2's failure is not evidence against state-sufficiency: on every eligible state all within-budget histories agree, including on the six C2 counterexamples. The reference-semantics §1 restatement conjoins C1 and C2, so §1-as-a-whole is false; that is a fact about the restatement. Adjudicated by 2B-6 (independent) confirming the Orchestrator: `docs/epistemic/qa023-c2-adjudication-2026-07-29.md`.** **⚠ 2026-07-29 (night) — SCOPE SPLIT. `fixpoint_kernel`'s White-branch defect is VERIFIED by two independent seats (`Kimi-k3/PINRULE-SUFFICIENCY` found it; `Kimi-k2.7/QA023-KERNEL-AUDIT` reproduced all three evidence lines from scratch in Python, no Zig imported). Corrected kernel validated three ways: agrees with `smoke_fixpoint_2x2`, Bellman residuals 0/0, colour-inversion violations 0. Corrected 3x2 census `2232/322/34/34` replaces the buggy `948/1532/142/0`. **T138 (2026-07-31, `docs/evidence/QA-023/census-reconciliation.md`) confirmed the +36-state delta vs EXP-4's `2220/298/34/34` is exactly the 36 empty-goban-with-ko-point phantom seeds (12 into L==H, 24 into pin_T); the cycle-reachable spread 1,724/1,704/1,678 reduces to the same phantom convention, with 1,678 the true-game-root value.** **On the CORRECTED kernel the verdict differs by semantics:** for the **history-conditioned** rule (first-revisit truncation, ADR-0019) this is **FALSE at 3x2** — C1 witness `(178,0,6,0)`, goban `[B,W,B,_,W,_]`, Black to move: two valid arrivals give truncation values **-3** and **-6** while the corrected fixpoint gives `L=H=-6`. For **fresh-start (shortest-arrival)** semantics the corrected tables remain consistent (`396/396` agreements in PINRULE-SUFFICIENCY; spot-checked independently) — a different object, and **UNTESTED** rather than true. Remaining gap, named by the auditor itself: the ~22-node witness tree was **not dumped and hand-verified** — task `QA023-C1-WITNESS`. Evidence: `docs/audits/2026-07-29-qa023-kernel-audit.md`, `docs/evidence/QA-023/pinrule-sufficiency-2026-07-29.md`.** Note also that the 2B-4 probe numbers (390/1080) were artefacts of a σ-in-arrival defect, 1,133/1,133 collisions (`docs/evidence/QA-023/probe-defect-2026-07-29/`) |
| `QA-024` | CLAIMED | `roadmap-2026-07-28.md:303`; `psk-binding-rate-2026-07-28.md:366-380` (EXP-1: consistent at exactly zero, with a recommended re-scoping); `docs/research/psk-divergence-2026-07-29.md` (EXP-8: harness built, value half blocked) |
| `QA-025` | PROVEN | `roadmap-2026-07-28.md:304`; `retrograde-3x3.md:222-241` |
| `QA-026` | FALSE-AS-SCOPED | `docs/evidence/QA-023/probe-fix-2026-07-29.md`; `docs/audits/2026-07-29-2b-6-full-review.md`; `docs/epistemic/qa023-c2-adjudication-2026-07-29.md`; `roadmap-2026-07-28.md:305`; `docs/research/f2-remedy-design-2026-07-29.md`; `docs/evidence/QA-023/proof-v2-2026-07-28.md` |
| `QA-027` | FALSE-AS-SCOPED (at 4×4; 3×3 measured 100.00%) | `roadmap-2026-07-28.md:306`; `docs/research/newrule-certified-fraction-4x4-2026-07-31.md`; `docs/evidence/QA-027/4x4/PROVENANCE.md` |
| `QA-028` | FALSE | `roadmap-2026-07-28.md:307`; `ruleset-options.md:42-71` |
| `SPRINT-M4a-ACCEPT` | PROVEN (measured, denominators stated) | `docs/evidence/ORACLE-V2/m4a-accept-T212-2026-08-01.md` |
| `WZO2-4X4-VALID` | FALSE-AS-SCOPED (as "valid"; the artifact is usable and internally consistent, but not a verified perfect oracle) | `findings/T261-m4b-triage.json`; `docs/evidence/ORACLE-V2/human-games-2026-08-02.md` |

*303 claims indexed.*