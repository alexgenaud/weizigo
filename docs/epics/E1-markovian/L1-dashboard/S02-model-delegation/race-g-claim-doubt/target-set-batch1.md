# Race G — batch 1: the sealed target set

**Sealed before dispatch.** This enumeration IS the ruling-35 denominator: thoroughness on this
race is coverage of *these* claims, and a lane that rules on 20 of 25 is at 20/25 however good
the 20 are. Do not add claims to the batch mid-race; a claim discovered to be missing is a
finding for batch 2.

**Selection rule, stated so the batch is checkable rather than chosen.** From the 231 parsed
rows of `docs/epistemic/CLAIMS.md`, deterministically:

- **Tier A — cascade risk:** the 10 claims with the most dependents. A wrong status here
  propagates furthest, which is exactly what the register's dependency edges exist to expose.
- **Tier B — load-bearing proofs:** the next 8 `PROVEN*` claims carrying at least one dependent.
  The Direction presumes proofs doubtful too, and a proof nothing depends on can wait.
- **Tier C — falsifications:** the next 7 `FALSE*` claims carrying at least one dependent. A
  *wrong falsification* wrongly kills downstream work, and nothing in this project has ever
  checked that direction of error.

Ties broken by claim ID, ascending. Re-running the rule against the register at this commit
reproduces the list exactly.

## Tier A cascade-risk (top dependent count)

### G01 — `GLOBAL.H1-MARKOV`  ·  status **UNTESTED**  ·  dependents 9

- **goban:** all
- **claim as registered:** The state-representation half of the former conjoined `GLOBAL.H1`: under simple ko + a fixed-value long-cycle verdict, the state `(position, side, ko_point, passes)` is **Markovian** (sufficient for exact solving). **Split 2026-07-29 per `CLAIMS-SPLIT-CONJUNCTS`** — the computational half (`GLOBAL.H1-COMPUTABLE`) is a separate row because it depends on `GLOBAL.LONGCYCLE` (now FALSE-AS-SCOPED). **UNTESTED.** C1 has never been tested with contrasting histories: the history generator misses the shortest arrival in 93% of states with ~62% shared prefixes (`2B-3-AUDIT`). Cross-reference `QA-023`: the Markovian claim survives; the value formula fell (`qa023-c2-adjudication-2026-07-29.md` §3).
- **evidence cited:** `open-hypotheses:30-118`; `PROGRESS.md:169-183`; `docs/audits/2b-3-audit-*.md`; `docs/epistemic/qa023-c2-adjudication-2026-07-29.md` §3
- **depends on:** `n:GLOBAL.C2`, `n:GLOBAL.C3`, `n:GLOBAL.C4` (the pivot is motivated by their falsity) — re-pointed 2026-08-06 T373: the `d:GLOBAL.CHAIN-KO` edge left the register with the triage

### G02 — `GLOBAL.ADR0006-EYE`  ·  status **CLAIMED**  ·  dependents 6

- **goban:** all
- **claim as registered:** Forbidding a player from filling its own Benson-alive true eye does not change the game score (weak dominance under area scoring)
- **evidence cited:** `0006:27-49`; `docs/audits/2026-07-30-eye-prune-validation.md`
- **depends on:** `d:GLOBAL.S2`, `d:GLOBAL.S4`

### G03 — `GLOBAL.F1`  ·  status **FALSE-AS-SCOPED**  ·  dependents 6

- **goban:** all
- **claim as registered:** The writes-on finisher (`ko_ref ≥ d` cross-branch memo guard) is sound
- **evidence cited:** `0013:20-44`; `consistency-audit.md:25-34`; `CONCEPTS.md:109`
- **depends on:** `d:GLOBAL.ADR0005-CACHE`

### G04 — `3x2.T13`  ·  status **PROVEN (falsification)**  ·  dependents 5

- **goban:** 3×2
- **claim as registered:** C2 falsified at 3×2: **154 of the 508 reachable L==H slots (30.3%, over 132 distinct positions) have at least one reachable PSK history whose exact value differs from the stored fresh-start value** — 4,432 falsifying (slot, history) pairs of 134,504 tested (all reachable histories, order-independent). The 2026-07-26 run sampled one history per slot and recorded **12** of these; that count is traversal-dependent and understates by >10×. 0/540 fresh-start sanity mismatches.
- **evidence cited:** `docs/evidence/T13/probe-reimplementation-2026-07-30.md` §4,§8; `docs/evidence/T13/t13_probe.py`, `zig_t13_replay.zig`; `docs/research/c2-falsification-3x2.md:15-16,45-95`
- **depends on:** `e:3x2.C1`, `e:3x2.EXACT`

### G05 — `4x4.D3`  ·  status **UNTESTED**  ·  dependents 5

- **goban:** 4×4
- **claim as registered:** Writes-off 4×4 tractability — **a measurement, not a truth claim**. Target wall ≤ 8 h, memory ≤ 32 GB (placeholder, unconfirmed with the user)
- **evidence cited:** `4x4/EPISTEMIC.md:175-183,328`
- **depends on:** — (re-pointed 2026-08-06 T373: `e:4x3.M3` left the register with the triage)

### G06 — `GLOBAL.ADR0015-BURDEN`  ·  status **CLAIMED**  ·  dependents 5

- **goban:** all
- **claim as registered:** **ADR-0015 (D-5, 2026-07-28):** ADR-0010's premise that the `[L,H]` bracket "holds under ANY arrival history" is **refuted as stated** — for an empty-goban root the finisher's own search path *is* a real game line, so E2's falsifying histories lie inside the family ADR-0010 claims to cover. `GLOBAL.F2` stays orphaned; the burden is on ADR-0010 and is **undischarged**. A ruling about an *argument*, not a new measurement: it does not establish that the bracket fails at any goban other than 3×3. **Challenge attempted and FAILED (EXP-10, Fable 5, 2026-07-29 — ADR-0017):** the search-path family is **not** exempt — T13's 12 pointwise mismatches at 3×2 ride exactly the finisher's search-shaped histories (8/12 empty-rooted); ADR-0015 **stands, strengthened.** A three-seat blind review (`QA-018-REVIEW-A/B/C`: GLM-5.2, DeepSeek Pro, Kimi-k2.7) returned **unanimously** that ADR-0017's 'refutation failed' verdict is SOUND; all three convicted the two planted calibration defences (6 MTD self-verification, 7 `bracket_fail` gate) as WRONG. **Confirmed by ADR-0018 (the human's `QA-018-RULING`, 2026-07-29): ADR-0015 stands; F2 remains orphaned.** The finisher remedy is a new task (`F2-REMEDY`) — not a brackets-off regen, which inherits the same premise through CERTCORE-dependent seeds.
- **evidence cited:** `docs/decisions/0015-bracket-cut-soundness-search-vs-real-history.md`; `docs/decisions/0017-bracket-cut-refutation-attempt-failed.md`; `docs/decisions/0018-bracket-cut-confirmed-unanimous-review-f2-remedy-is-new-task.md`; `0010:16-18,70-93` (re-pointed 2026-08-06 T373: the untracked 025-fable-to-all.md citation dropped — the committed decisions 0015/0017/0018 are the durable record); `src/retro.zig:464`; `critique-2026-07-28.md:376`
- **depends on:** `n:GLOBAL.C3` (the ruling is justified by C3 being FALSE; if C3 were rehabilitated ADR-0010's premise would stand and this ADR would lose its reason to exist), `e:3x3.C3`, `e:QA-019`

### G07 — `GLOBAL.AUDITOR`  ·  status **PROVEN**  ·  dependents 5

- **goban:** all
- **claim as registered:** The `RETRO_CONSIST` self-consistency auditor is the standing pre-commit gate; passing is **necessary, not sufficient** (a solver can be self-consistent at a wrong fixpoint)
- **evidence cited:** `consistency-audit.md:6-23`; `AGENTS.md:63-67`; `0013:117-122`; `docs/evidence/GLOBAL-AUDITOR/PROVENANCE.md`; `docs/evidence/GLOBAL-AUDITOR/consist-3x2-2026-07-30.log`
- **depends on:** —

### G08 — `GLOBAL.BRUTE-ALIASING`  ·  status **FALSE (methodological)**  ·  dependents 5

- **goban:** all
- **claim as registered:** T102 audit (2026-07-30): a successor-buffer aliasing defect in `brute_value_2x2` (`src/exp4_solve.zig:555-594`) invalidates **every brute-force cross-check in the EXP-4 → EXP-7 chain**. All 24 EXP-4 2×2 "mismatches" were an artifact of the checker, not a divergence in the thing checked; fixpoint and FRT agree on all 172 reachable non-terminal 2×2 states. The same defect pattern recurs in `exp4_solve.zig` (3×2), `exp5_solve.zig` (3×3), `exp6_solve.zig` (4×4), and `exp6_hchain_audit.zig` — none re-verified. **Stands:** fixpoint results, independently verified by T102 (2×2), T104's Python kernel (2×2/3×2/3×3), and the MIGOS II anchor at 3×3. **Withdrawn:** brute-force cross-check as corroboration anywhere in the EXP chain
- **evidence cited:** `docs/audits/2026-07-30-audit-2x2-mismatch.md` §1,§6; `docs/audits/2026-07-30-audit-2x2-mismatch.py`
- **depends on:** —

### G09 — `GLOBAL.C3`  ·  status **FALSE-AS-SCOPED (at 3×3)**  ·  dependents 5

- **goban:** all
- **claim as registered:** The bracket `[L,H]` bounds the real-game score for any history, any cycle rule in `[−n,n]`
- **evidence cited:** `leak-crisis.md:26`; `PROGRESS.md:128`; `CONCEPTS.md:57-61`
- **depends on:** `d:GLOBAL.FP2`, `d:GLOBAL.ADR0009-HONESTY`

### G10 — `QA-023`  ·  status **CLAIMED**  ·  dependents 5

- **goban:** all
- **claim as registered:** Under basic ko + a **fixed-value** long-cycle verdict, `(board, side_to_move, ko_point, passes)` is a sufficient **Markovian** state for exact solving — the score-on-cycle path-dependence does not apply, because a constant verdict is not a function of *which* goban repeated. **Load-bearing for the whole roadmap.** Its central obligation is to distinguish itself from `GLOBAL.R2` (score-on-cycle ≡ PSK) and `GLOBAL.RPLY-TRAP` (the cycle terminal drags history back into the key); **no `depends-on` edge is written deliberately** — writing one would prejudge which of those two it stands or falls with, and EXP-2 Part A is what decides
- **evidence cited:** `roadmap-2026-07-28.md:302`; `docs/evidence/QA-023/proof.md` (Part A; the computational half is 2×2-only, which `EXP-2-AUDIT-PREREG.md` rejects outright as INCOMPLETE). EXP-2A done 2026-07-28 (Fable 5; REPAIRABLE-GAPS→repaired); EXP-2B (the 3×2 computational half) COMPLETE 2026-07-29 via 2B-0…2B-6. **DO NOT MARK THIS ROW FALSE. The computational half SPLITS: C1 (this row's actual assertion — state-sufficiency) is UNTESTED-FOR-WANT-OF-CONTRAST, because the history generator misses the shortest arrival in 93% of states and its histories share ~62% of prefixes (`2B-3-AUDIT`); C2 (that the common value equals `median(L,TIE,H)`) is FALSIFIED — but C2 is `QA-026`'s content, NOT this row's. C2's failure is not evidence against state-sufficiency: on every eligible state all within-budget histories agree, including on the six C2 counterexamples. The reference-semantics §1 restatement conjoins C1 and C2, so §1-as-a-whole is false; that is a fact about the restatement. Adjudicated by 2B-6 (independent) confirming the Orchestrator: `docs/epistemic/qa023-c2-adjudication-2026-07-29.md`.** **⚠ 2026-07-29 (night) — SCOPE SPLIT. `fixpoint_kernel`'s White-branch defect is VERIFIED by two independent seats (`Kimi-k3/PINRULE-SUFFICIENCY` found it; `Kimi-k2.7/QA023-KERNEL-AUDIT` reproduced all three evidence lines from scratch in Python, no Zig imported). Corrected kernel validated three ways: agrees with `smoke_fixpoint_2x2`, Bellman residuals 0/0, colour-inversion violations 0. Corrected 3x2 census `2232/322/34/34` replaces the buggy `948/1532/142/0`. **T138 (2026-07-31, `docs/evidence/QA-023/census-reconciliation.md`) confirmed the +36-state delta vs EXP-4's `2220/298/34/34` is exactly the 36 empty-goban-with-ko-point phantom seeds (12 into L==H, 24 into pin_T); the cycle-reachable spread 1,724/1,704/1,678 reduces to the same phantom convention, with 1,678 the true-game-root value.** **On the CORRECTED kernel the verdict differs by semantics:** for the **history-conditioned** rule (first-revisit truncation, ADR-0019) this is **FALSE at 3x2** — C1 witness `(178,0,6,0)`, goban `[B,W,B,_,W,_]`, Black to move: two valid arrivals give truncation values **-3** and **-6** while the corrected fixpoint gives `L=H=-6`. For **fresh-start (shortest-arrival)** semantics the corrected tables remain consistent (`396/396` agreements in PINRULE-SUFFICIENCY; spot-checked independently) — a different object, and **UNTESTED** rather than true. **`QA023-C1-WITNESS` COMPLETED 2026-07-29** (`docs/evidence/QA-023/c1-witness-handcheck-2026-07-29.md`): the (178,0,6,0) witness was hand-verified with two independent implementations, node-for-node agreement — the C1 first-revisit falsification at 3×2 is hand-verified; what still blocks the fresh-start reading is the contrast generator (93% miss rate), not the witness. Evidence: `docs/audits/2026-07-29-qa023-kernel-audit.md`, `docs/evidence/QA-023/pinrule-sufficiency-2026-07-29.md`.** Note also that the 2B-4 probe numbers (390/1080) were artefacts of a σ-in-arrival defect, 1,133/1,133 collisions (`docs/evidence/QA-023/probe-defect-2026-07-29/`)
- **depends on:** — (deliberate — see the claim)

## Tier B load-bearing proofs (PROVEN, >=1 dependent)

### G11 — `3x2.F1`  ·  status **PROVEN (falsification)**  ·  dependents 4

- **goban:** 3×2
- **claim as registered:** Writes-on finisher unsound at 3×2: **45 of 378** ko-sensitive slots violate the minimax identity; writes-off gives **0**
- **evidence cited:** `consistency-audit.md:25-34`; `0013:15-19`; `4x4/EPISTEMIC.md:49-52`
- **depends on:** `e:GLOBAL.AUDITOR`

### G12 — `CODE.VB-BLINDGAPS`  ·  status **PROVEN (blind-reimplementation audit, committed)**  ·  dependents 4

- **goban:** n/a
- **claim as registered:** **T172's blind reimplementation of the verify-battery design found five specification gaps** (verdict: "YES, with five documented gaps"; analysis rescued to the sprint archive). **GAP-5, CRITICAL: invariant I11 (move-set consistency) requires a solver-side dump file whose format is specified NOWHERE** — the design schema names `solver_dump_path` but never defines the format, and design §5's L/H-dump paragraph defines itself circularly as "the same shape as I11's dump"; I11 cannot be independently re-implemented. T172's on-record recommendation "resolve GAP-5 before dispatching V-8" was **not honoured** — V-8/T170 shipped `checkI11()` as a permanent `not_applicable` stub, silently converting a critical spec gap into dead scope. The remaining four: GAP-3 (moderate — spec I7 requires a DTT-recurrence check the result schema has no field for), GAP-1 (moderate — I4's Φ from TIE-pinned children may not equal the true fixpoint value; design notes it, spec §4 does not), GAP-4 (minor — I10 `tie_not_median` is dead code under V=median(L,TIE,H)), GAP-2 (minor — I6 `legal_both_sides`/`legal_one_side_only` ambiguous between partition and overlapping counts). GAP-5 also blocks the WZO1 L/H-dump option in the pending human bracket-verification decision
- **evidence cited:** `docs/evidence/CODE.VB-BLINDGAPS/T172-blind-analysis.md`; `src/vb_fixpoint.zig:545-547`
- **depends on:** —

### G13 — `CODE.WZO2-PASSBIT`  ·  status **PROVEN (measured, both failing checks reproduced with counts; root cause read in the source and fixed)**  ·  dependents 4

- **goban:** 4×4
- **claim as registered:** **The first 4×4 WZO2 artifact was invalid: the builder encoded `passes=1` entries with `passes=0` in the key_byte.** `src/oracle_v2_build.zig:387` (pinned `f851102`) passed `0` where the pass count belongs, so `passes=0` and `passes=1` rows for the same `(board, side, ko = KO_NONE)` shared one sort key. M4a acceptance against the 518.1 MB artifact `a892d689…` (T193, instrument `src/oracle_v2_accept.zig` as wired by T182) **FAILED two of four checks**: A3 colour inversion 16,314,978 violations / 99,133,036 checked (16.5%), A9 reproducibility 24,252,631 entry-order violations; A5 round-trip PASS (0 / 1,021,991 sampled, stride 97) and A6 calibration PASS (all 3 fixtures caught). **Control: the 3×3 WZO2 artifact passes all four checks**, confining the defect to the 4×4 path and distinguishing a builder bug from a harness bug. One-character fix committed `5deec6b`; the artifact must be rebuilt and M4a re-run (T212) before oracle-v2 G3. Note the interaction with `GLOBAL.PASS-NOKO`: because `passes ≥ 1 ⇒ ko = none`, the collision is confined to the `KO_NONE` key bytes (0x40/0x42) — which is why exactly one violation per `(board, side)` appears in A9, ≈24.3M of them. Minted 2026-08-01 (Orcha/T193 absorption)
- **evidence cited:** `docs/evidence/ORACLE-V2/m4a-accept-T193-2026-08-01.md`; `docs/evidence/ORACLE-V2/m4a-accept-T193-2026-08-01.stdout`; `src/oracle_v2_build.zig:387` (`5deec6b`)
- **depends on:** `d:GLOBAL.PASS-NOKO`

### G14 — `GLOBAL.S1`  ·  status **PROVEN**  ·  dependents 4

- **goban:** all
- **claim as registered:** The colex mixed-radix index is a collision-free bijection over the 3^(w·h) goban space
- **evidence cited:** `4x4/EPISTEMIC.md:17`; `4x3/EPISTEMIC.md:24`
- **depends on:** —

### G15 — `QA-021`  ·  status **PROVEN**  ·  dependents 4

- **goban:** 4×4
- **claim as registered:** FP1 acceptance check 3 passes **exhaustively** at 4×4 on the shipped `vb`/`vw` columns: 48,599,962 slots, 422,990 violations, **all** KO_SENSITIVE, **zero** outside, 87 s. Upgrades `4x4.FP1-C3`'s 1:37 sample. Does **not** cover `lo`/`hi` — WZO1 has no bracket columns
- **evidence cited:** `critique-2026-07-28.md:379`; `ko-sensitive-chainability.md:109,116`
- **depends on:** — (re-pointed 2026-08-06 T373: `e:4x4.M4` left the register with the triage)

### G16 — `2x2.C1`  ·  status **PROVEN**  ·  dependents 3

- **goban:** 2×2
- **claim as registered:** Fresh-start scores correct at 2×2 vs the history-aware exact solver
- **evidence cited:** `leak-crisis.md:24`; `PROGRESS.md:126`
- **depends on:** `e:2x2.EXACT`, `e:GLOBAL.ADR0006-EYE`

### G17 — `3x2.C1`  ·  status **PROVEN**  ·  dependents 3

- **goban:** 3×2
- **claim as registered:** Fresh-start scores correct at 3×2 vs the history-aware exact solver
- **evidence cited:** `leak-crisis.md:24`; `c2-falsification-3x2.md:56-57` (0/540 L==H fresh-start mismatches)
- **depends on:** `e:3x2.EXACT`, `e:GLOBAL.ADR0006-EYE`

### G18 — `3x3.C3`  ·  status **PROVEN (falsification)**  ·  dependents 3

- **goban:** 3×3
- **claim as registered:** C3 falsified at 3×3: range-aware self-play leaked (promise +3 → final −9, 12-pt leak)
- **evidence cited:** `leak-crisis.md:36,74-79`; `4x4/EPISTEMIC.md:55-66`
- **depends on:** `e:3x3.B1`, `e:3x3.E3`, `e:3x3.E2-RUN1`, `e:3x3.E2-RUN2`

## Tier C falsifications (FALSE*, >=1 dependent)

### G19 — `GLOBAL.C2`  ·  status **FALSE-AS-SCOPED (at 3×2)**  ·  dependents 4

- **goban:** all
- **claim as registered:** Single-score (L==H) positions are history-independent
- **evidence cited:** `leak-crisis.md:25`; `PROGRESS.md:127`; `AGENTS.md:68-73`
- **depends on:** `d:GLOBAL.FP2-bounded`

### G20 — `CODE.WZO2-INCOMPLETE`  ·  status **FALSE-AS-SCOPED (the stated claim is wrong as measured; the artifact's structural completeness is established but value-correctness is not)**  ·  dependents 3

- **goban:** 4×4
- **claim as registered:** **REFUTED (T266, verified independently by T277, absorbed T279) — the artifact is NOT incomplete in the way claimed.** The T261 scan's ~6.77M figure was 51.7× overstated: the absent `passes=1` side-entries are exactly the **131,068 single-colour gobans** (65,534 all-Black + 65,534 all-White) and are **provably unreachable** — a single-colour goban can only arise from a placement by the opposite colour, which would leave at least one stone of that colour. Exhaustive scan over all 24,318,165 groups (T266; independently re-derived by T277): zero counter-examples in either direction, instrument calibrated with a seeded shift mutant. The W+2 self-play contradiction was the pre-T265 GTP ko rule + the display-path defect (`CODE.GTP-LHSIDE`), not missing entries — self-play at HEAD ends B+1. The artifact is **structurally complete at the entry level**; the passes=1 pass clause (`CODE.WZO2-PASS1-LAW`) and the single-colour-side law hold with zero exceptions. **The artifact is still not verified**: closure (C-A1/C-A2) and L/H value-correctness remain untested. **(Term "monochrome" superseded by "single-colour goban" per glossary, T285, 2026-08-03.)**
- **evidence cited:** `docs/evidence/ORACLE-V2/incompleteness-T266.md`; `docs/evidence/ORACLE-V2/incompleteness-verify-T277.md`; `findings/T266-incompleteness.json`; `findings/T277-verify-refutation.json`
- **depends on:** `d:CODE.WZO2-PASSBIT` (the passes-bit bug was real; the artifact is accessible to all reachable entries)

### G21 — `GLOBAL.C4`  ·  status **FALSE-AS-SCOPED**  ·  dependents 3

- **goban:** all
- **claim as registered:** Fresh-start score == real-game score
- **evidence cited:** `leak-crisis.md:27`; `PROGRESS.md:129`; `4x4/EPISTEMIC.md:26`
- **depends on:** `d:GLOBAL.C2` (single-score half), `d:GLOBAL.P3` (ko-sensitive half)

### G22 — `GLOBAL.CERTCORE`  ·  status **FALSE-AS-SCOPED**  ·  dependents 3

- **goban:** all
- **claim as registered:** Where L==H the score "cannot depend on any cycle rule … equals the mid-game score under ANY ban set" — the ADR-0009 *certification* decision
- **evidence cited:** `0009:65-67`
- **depends on:** `d:GLOBAL.FP2`

### G23 — `GLOBAL.TIE-MIGOS`  ·  status **FALSE-AS-SCOPED (the minted mechanism is contradicted; the +2 anchor is a different game, not a different tie)**  ·  dependents 3

- **goban:** all
- **claim as registered:** **MIGOS tie adjudication, Candidate 1 — REFUTED by primary sources (T274, absorbed T279).** The hypothesis that the +1-vs-+2 gap is a *tie-value* difference (TIE=0 vs MIGOS's long-cycle-tie value) is contradicted: MIGOS's documented long-cycle-tie value **is 0** (thesis §5.3.2; ICGA 2009 §3.3 "typically 0"), identical to our TIE=0, and MIGOS's own basic-ko 4×4 result is **+1 = ours** (thesis Table 5.1). The +2 arises from the pass-difference cycle-resolution **rule** (thesis Appendix A §A.4: repetition ends the game, scored by pass-difference; or SSK), a different game definition — not a different tie constant. Empirically confirmed by T274: no flat TIE constant reproduces the colour-symmetric (+2,−2) anchor at 4×4 (analytic from the measured bracket [L=+1,H=+16]/[−16,−1]; the small-goban sweep confirms L/H tables are TIE-independent and V=clamp(TIE,[L,H]) exactly). The register's `4x4.ANCHOR` citation 'thesis §6.4' was wrong — the 4×4 solve is thesis §5.4.1 (Table 5.1) + Appendix A §A.4. **The +2 acceptance criterion in `roadmap-2026-07-28.md:227-232` is not met by ruleset R and cannot be — the +2 anchor is a different game**
- **evidence cited:** `docs/evidence/GLOBAL-TIE-MIGOS/tie-experiment-T274.md`; `findings/T274-tie-experiment.json`; `findings/T274-context.json`
- **depends on:** — (the hypothesis was its own claim, refuted by primary-source reading; no derivation edge)

### G24 — `QA-019`  ·  status **FALSE**  ·  dependents 3

- **goban:** all
- **claim as registered:** "ADR-0013 Track A (`memo_writes=false`) escapes `QA-018`" — refuted: `bracketed` and `memo_writes` are independent and `saveArtifact` hardcodes `bracketed=true`; the 1.67% writes-off floor is **also** bracket-derived
- **evidence cited:** `critique-2026-07-28.md:377`; `src/retro.zig:2407`
- **depends on:** — (re-pointed 2026-08-06 T373: `e:GLOBAL.F3` and `e:4x4.M6-FLOOR` left the register with the triage)

### G25 — `QA-022`  ·  status **FALSE**  ·  dependents 3

- **goban:** n/a
- **claim as registered:** "Load-bearing evidence for T13, T02/B1, T07 and B05 is retrievable" — refuted: all four were cited under git-ignored `untracked/`, all deleted, none ever in git. T13's numbers survive; its probe source does not
- **evidence cited:** `docs/evidence/README.md`; `critique-2026-07-28.md:380`; §7 of this file
- **depends on:** `e:3x2.T13`
