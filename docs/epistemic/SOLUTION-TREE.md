# The Solution Tree — what the construction of each goban table rests on

**Task:** T415 (does every construction step have a stated basis?) · **Worker:** deepseek-v4-flash/T415 · **Date:** 2026-08-08
**Landmark:** advances `L4 (the ledger is clean)` and the direction itself — the operator's 2026-08-07 ask: *"What steps do we take to build the pos-score-table, which are based on proof (and generate provably perfect scores), and which are based on best-guesses or hypothesized-but-unproven claims or even proven-suboptimal?"*

**This file is the construction tree.** `CLAIMS.md` records what we believe about the game (the *epistemic* tree: what is true). This file records how the table was built — which construction steps are PROVED, which are CLAIMED, which are HYPOTHESISED, which are KNOWN-SUBOPTIMAL, which are KNOWN-WRONG-and-retained, and which could not be determined from committed evidence. The epistemic trees under `boards/` say *what is true*; this tree says *what our construction rests on*. A step marked "hypothesised, unproven" is either a proof waiting to be attempted or a plugin to be swapped and compared.

**Method and bias rule.** Each step's basis was determined from committed evidence only (ADRs, register rows, evidence dirs, source headers, run logs). The rule from the brief, applied strictly: **PROVED requires a citation** — a mathematical argument or an exhaustive verification with a denominator. "It passed every test" is CLAIMED, not PROVED. On every judgement call the basis was biased downward and the call is named. Where committed evidence could not determine a step's basis, the step is marked **`UNDETERMINED — needs archaeology`** and what was looked at is listed. No new claims were made and no `CLAIMS.md` edits were performed; register rows are cited, not adjudicated.

**Per-goban independence is load-bearing here too.** A step sound at 3×3 is not thereby sound at 4×4 (foreclosure; `GLOBAL.ADR0016-INHERIT`). Each size below is its own tree; structural (code/mathematics) steps may inherit *with the argument written down*, empirical steps never do.

**Terminology** follows `docs/epistemic/GLOSSARY.md` and `docs/epistemic/names.md`: the table holds **fresh-start scores** under the generation rule; **single-score region** where L==H; **bracket / ko-sensitive region** where L<H; the **finisher** is the forward solver that fills ko-sensitive slots in the WZO1-era construction; "certified core" is deprecated. "Retrograde" means **successor-sweep value iteration** — sweep order, not un-play (`src/retro.zig:19-26` reads forward successors only; no un-move code exists).

---

## 0. The artifacts per size — what each tree is about

| goban | canonical artifact(s) on disk | ruleset / generation rule | builder | root value |
|---|---|---|---|---|
| 2×2 | `artifacts/oracle-2x2.wzo` (518 B) | WZO1, rules_id=1, PSK, writes-ON finisher | `retro.zig` (ADR-0009/0010/0011) | empty(B) = **+1** (PSK fresh-start; verified) |
| 3×2 | `artifacts/oracle-3x2.wzo` (4,406 B) | WZO1, PSK, writes-ON finisher | `retro.zig` | empty(B) = **+1** (PSK) |
| 3×3 | `artifacts/oracle-3x3.wzo` (118,130 B) · `data/oracle-3x3-v2.wzo2` (261,215 B) | WZO1 PSK / **WZO2 basic-ko + TIE=0 (ADR-0020)** | `retro.zig` / `oracle_v2_build.zig` | **+9** (both; +9 is also the MIGOS II anchor) |
| 4×3 | `artifacts/oracle-4x3.wzo` (3,188,678 B) | WZO1, PSK, writes-ON finisher | `retro.zig` | root bracket **[+4,+12]** (measured; not independently audited — `GLOBAL.ROOT-SINGLE-IFF-FORCIBLE-LIFE`) |
| 4×4 | **`data/oracle-4x4-v2.wzo2` (518,123,097 B)** — the current deliverable · `data/oracle-4x4.checkpoint.wzo` + `-parallel.checkpoint.wzo` (PSK checkpoints, writes-ON) · `data/oracle-4x4-basicko-tie-area.wzo` (v1 basic-ko WZO1, defects recorded) | WZO2 basic-ko + TIE=0 (ADR-0020) / PSK / basic-ko | `oracle_v2_build.zig` (exp6 fixpoint, no finisher) / `retro.zig` | empty(B) **L=+1, H=+16** (WZO2); +2-era checkpoint values are a different game (`GLOBAL.TIE-MIGOS`) |

Hashes in `artifacts/SHA256SUMS` and `data/`; the WZO2 4×4 rebuild is byte-identical across runs (`CODE.WZO2-BUILD-REPRO`).

The trees below cover the **canonical current artifact per size** (WZO2 where it exists: 3×3, 4×4; WZO1 PSK elsewhere: 2×2, 3×2, 4×3), and note where a second artifact at the same size rests on weaker steps. The brief's step families:

1. Position enumeration (colex indexing, legality, no-sub-goban)
2. Move generation (incl. ADR-0006 eye-prune — forward search only — and pass rules)
3. Terminal detection & scoring (`is_settled`, `area_score`; T400 ruling)
4. The retrograde sweep (successor-sweep Bellman iteration)
5. The L/H two-sided fixpoint (least/greatest; what the bracket does and does not mean)
6. The KO_SENSITIVE finisher (its actual basis today)
7. Artifact format and the reader (WZO1→WZO2, key-byte decode)
8. Verify-battery invariants (I4, I5, I7, I9, A1–A8)

---

## 1. 2×2 — `artifacts/oracle-2x2.wzo`

Construction: colex space (81 raw slots, 9 orbit reps), successor sweeps, L/H fixpoints, writes-ON finisher, WZO1 write + reload verify.

| # | step | basis | evidence (register rows, files) | if wrong | owner |
|---|---|---|---|---|---|
| 1 | Colex enumeration + legality | **PROVED** | `GLOBAL.S1` (PROVEN — collision-free bijection, exhaustive round-trip through 4×4); `GLOBAL.S3a` (PROVEN — kernel + OEIS A094777) | every address, every artifact, everything downstream | colex.zig, enumerate.zig |
| 2 | Move generation | **PROVED** | `GLOBAL.S3a` (PROVEN as scoped); `CODE.S4-XVAL` (1000 random moves vs Gen-1 state.zig, exact match); 2×2 exhaustively exercised by the ground-truth battery (`2x2.EXACT`, `2x2.C1` PROVEN) | fixpoint sweeps compute wrong values | rules.zig |
| 3a | Terminal detection (`is_settled` via Benson + double pass) | **PROVED** | `GLOBAL.S2` (Benson theorem, literature + finite-goban scope, `docs/evidence/GLOBAL-S2/`); `GLOBAL.ADR0004-TERM` (PROVEN); exercised exhaustively at 2×2 by `2x2.C1` (PROVEN — 0 mismatches vs history-aware exact solver) | settled positions scored wrong → leaf scores wrong → whole table wrong | terminal.zig / rules.zig |
| 3b | Area scoring | **PROVED** | `GLOBAL.S4` (PROVEN — independent Python Tromp–Taylor scorer, 0 disagreements on 120 random gobans, `docs/evidence/GLOBAL-S4/`) | every terminal score wrong | rules.zig |
| 4 | Retrograde sweep | **CLAIMED** (instance) | mathematics PROVED: `GLOBAL.FP1`, `GLOBAL.FP3` (Knaster–Tarski, finite lattice, monotone, finite sweeps; proof notes committed). Instance: `2x2.B1` **CLAIMED — primary evidence lost** (`untracked/T02-minimax.md` deleted; downgraded PROVEN→CLAIMED 2026-07-29 evidence-integrity sweep) | converges to the wrong fixpoint | `2x2.B1` row |
| 5 | L/H fixpoint (bracket) | **CLAIMED** | `GLOBAL.FP1` (PROVEN math); `GLOBAL.AXIOM-LH`/`AXIOM-BRACKET` (CLAIMED axioms); `2x2.T12` (C2-pilot at 2×2 **tautological** — no reachable non-root cycles, so the single-score region is trivially history-free at 2×2); `GLOBAL.CERTCORE` FALSE-AS-SCOPED globally (do not read L==H as real-game-correct) | the L==H reading of scores is over-claimed | axiom owners |
| 6 | KO_SENSITIVE finisher (writes-ON) | **KNOWN-WRONG** (mechanism), outputs **rescued by exhaustive ground truth** | `GLOBAL.F1` FALSE-AS-SCOPED (the `ko_ref ≥ d` cross-branch memo guard; ADR-0013); ADR-0013's Track A (writes-off regen) never ran at 2×2. Rescue: `2x2.C1` PROVEN — the stored values match the history-aware exact solver slot-for-slot | if the rescue were absent, every ko-sensitive value would be suspect; at 2×2 the rescue covers it | Track A regen (ADR-0013) |
| 7 | Artifact format + reader | **PROVED** | `CODE.ADR0011-FMT` (PROVEN — WZO1 header + six frozen columns, reader refuses on mismatch); `CODE.ADR0011-GATE` (PROVEN — refuse-to-write unless battery passed, reload byte-verify) | every value read from disk is the wrong address | artifact.zig |
| 8 | Verify battery at 2×2 | **CLAIMED** | battery was **stubbed before T258** (`CODE.VB-STUBS` PROVEN); post-T258 read-only checks (I2/I3/I6/I12) run on WZO1; I7 known-fail (DTT column unset, `CODE.WZO1-DTT-UNSET` PROVEN); I9 anchors ruleset-aware (2×2 basic-ko anchor = 0; PSK fresh-start = +1 — both correct for their rules) | a battery pass at 2×2 is not a fresh independent certification | battery owner |

**Three weakest links at 2×2:**
1. **The finisher mechanism is KNOWN-WRONG** (writes-ON, `GLOBAL.F1`) — the artifact was built with it, and it survives only because 2×2 admits an exhaustive exact-solver ground truth that happens to verify the outputs (`2x2.C1`). The construction method itself is invalid and remains in the codebase's history as the WZO1-era default.
2. **`2x2.B1` (least fixpoint at 2×2) is CLAIMED, not PROVEN — its primary evidence was deleted** (`untracked/T02-minimax.md`). The mathematics (FP1/FP3) is PROVEN; the *instance* rests on a prose summary.
3. **No basic-ko artifact is persisted at 2×2.** The EXP-4 table (root 0, 258 states, 4 sweeps) exists only in `docs/evidence/QA-026/`; the only artifact on disk is the PSK WZO1. The current-rule deliverable is unshippable at 2×2 without a rebuild+persist.

Count: 9 sub-steps identified · **5 PROVED** (1, 2, 3a, 3b, 7) · 3 CLAIMED (4, 5, 8) · 1 KNOWN-WRONG (6).

---

## 2. 3×2 — `artifacts/oracle-3x2.wzo`

Same construction as 2×2; the differences are the load-bearing ones.

| # | step | basis | evidence | if wrong | owner |
|---|---|---|---|---|---|
| 1 | Colex enumeration + legality | **PROVED** | `GLOBAL.S1`, `GLOBAL.S3a`; 3×2 legal counts match OEIS series | as 2×2 | colex.zig |
| 2 | Move generation | **PROVED** | `GLOBAL.S3a`; `CODE.S4-XVAL`; exercised by `3x2.C1` (PROVEN — 0/540 L==H fresh-start mismatches) and `3x2.EXACT` (68/600 roots history-exact, 0 mismatches, all in-bracket) | as 2×2 | rules.zig |
| 3a | Terminal detection | **PROVED** | `GLOBAL.S2`, `GLOBAL.ADR0004-TERM`; exercised by the 3×2 ground-truth batteries (settled positions are single-score, inside the verified region) | as 2×2 | rules.zig |
| 3b | Area scoring | **PROVED** | `GLOBAL.S4` | as 2×2 | rules.zig |
| 4 | Retrograde sweep | **CLAIMED** (instance) | `GLOBAL.FP1`/`FP3` PROVEN; `3x2.B1` **CLAIMED — primary evidence lost** (same T02 downgrade as 2×2) | as 2×2 | `3x2.B1` row |
| 5 | L/H fixpoint | **CLAIMED** | `GLOBAL.FP1` math; `GLOBAL.AXIOM-LH`/`BRACKET` CLAIMED; **`GLOBAL.C2` FALSE-AS-SCOPED at 3×2** (`3x2.T13` PROVEN — 154/508 reachable L==H slots have a PSK history whose exact value differs; 4,432 falsifying pairs) | the single-score region is fresh-start exact, NOT real-game exact — a real-game reading is a category error | C2 rows |
| 6 | KO_SENSITIVE finisher (writes-ON) | **KNOWN-WRONG**, outputs **not rescued** | `3x2.F1` **PROVEN** — the writes-ON finisher violates the minimax identity at **45 of 378** ko-sensitive slots; writes-off gives 0 (`3x2.F3` PROVEN necessary condition). The committed artifact's ko-sensitive column is wrong as committed | the artifact's ko-sensitive values are known-wrong; do not quote them | Track A regen (mandatory at 3×2) |
| 7 | Artifact format + reader | **PROVED** | `CODE.ADR0011-FMT`, `CODE.ADR0011-GATE` | as 2×2 | artifact.zig |
| 8 | Verify battery at 3×2 | **CLAIMED** | battery stubbed pre-T258 (`CODE.VB-STUBS`); post-T258 I4 0/… at 3×2; I5 reference calibrated — `3x2.I5-CAL` MEASUREMENT (node counts exact; edge/max-SCC discrepancy **reconciled by T391** — `CODE.I5-INSTRUMENT-ADJUDICATION`: it was a `vb_graph` defect pair, not a reference problem); I7 known-fail (DTT unset) | battery cells at 3×2 are instrument-adjudicated readings, not fresh proofs | battery owner |

**Three weakest links at 3×2:**
1. **The committed artifact's ko-sensitive values violate the minimax identity (45/378, `3x2.F1` PROVEN).** 3×2 is the smallest goban where the writes-ON finisher's unsoundness produces measurable wrongness, and the artifact has never been regenerated writes-off (Track A). Every ko-sensitive reading of `artifacts/oracle-3x2.wzo` is wrong as committed.
2. **`3x2.B1` CLAIMED with lost primary evidence** (same T02 deletion as 2×2).
3. **C2 is falsified at 3×2** (`3x2.T13`, 30.3% of the reachable single-score region is history-sensitive) — the strongest real-game caveat in the whole project lives at this size, and the artifact's L==H values are fresh-start exact, not real-game exact.

Count: 9 sub-steps · **5 PROVED** · 3 CLAIMED · 1 KNOWN-WRONG (with the worst measured consequences of any size).

---

## 3. 3×3 — `data/oracle-3x3-v2.wzo2` (canonical, WZO2 basic-ko) · `artifacts/oracle-3x3.wzo` (WZO1 PSK)

3×3 is the first size with two artifacts on different constructions. The WZO2 table is the ADR-0020 pure loopy-game fixpoint — **no finisher** (T380 F-8: `oracle_v2_build` reads the exp6 fixpoint directly; the 3×3 artifact was the control that confined the 4×4 passes-bit defect to 4×4).

| # | step | basis | evidence | if wrong | owner |
|---|---|---|---|---|---|
| 1 | Colex enumeration + legality | **PROVED** | `GLOBAL.S1`; `GLOBAL.S3a`; 3×3 legal count 12,675 = OEIS A094777 (cross-validated, `enumerate.zig`) | as above | colex.zig |
| 2 | Move generation | **PROVED** | `GLOBAL.S3a`; I11 move-set consistency **0 / 25,350** at 3×3 (G3b); T380 F-2 ban-set invariants **0/784 exhaustive** at 3×3; kernel-vs-production successor agreement | as above | rules.zig / exp6_solve.zig |
| 3a | Terminal detection | **PROVED** | `3x3.S2-impl` **PROVEN** — the `rules.zig` Benson implementation is exhaustively falsification-confirmed at 3×3; `GLOBAL.S2` (theorem); `GLOBAL.ADR0004-TERM` | as above | rules.zig |
| 3b | Area scoring | **PROVED** | `GLOBAL.S4` (independent Python scorer, 0/120 disagreements) | as above | rules.zig |
| 4 | Retrograde sweep | **CLAIMED** (instance) | `GLOBAL.FP1`/`FP3` PROVEN; `3x3.B1` CLAIMED (evidence lost — T02); 16 sweeps measured (`3x3.BASICKO-TIE` MEASUREMENT) | as above | `3x3.B1` row |
| 5 | L/H fixpoint | **CLAIMED** | root **L==H==+9** (`3x3.BASICKO-TIE` MEASUREMENT — matches the MIGOS II anchor under aligned rules, `GLOBAL.MIGOS-RULE` PROVEN); `GLOBAL.AXIOM-LH`/`BRACKET` CLAIMED; **`GLOBAL.C3` FALSE-AS-SCOPED at 3×3** (`3x3.C3` PROVEN — E2: 25/4000 + 50/8000 games leak, promise +3 → final −9); `3x3.C2` UNTESTED | the bracket does **not** bound the real-game score at 3×3 — any real-game reading of [L,H] is a non-claim (NC2) | C3 rows |
| 6 | KO_SENSITIVE finisher | **NOT IN THE WZO2 CONSTRUCTION**; **KNOWN-WRONG where used (WZO1)** | T380 F-8 (WZO2 = pure fixpoint, I4-verified); WZO1: `GLOBAL.F1` FALSE-AS-SCOPED; `3x3.F2` MEASUREMENT — finisher *completed* all 622 orbit reps and anchors PIN, but **completion is not soundness** (register §1 explicitly) | (WZO2) none — not in the path; (WZO1) the ko-sensitive column is unverified | Track A |
| 7 | Artifact format + reader | **PROVED** (WZO1) / **CLAIMED** (WZO2) | WZO1: `CODE.ADR0011-FMT`/`GATE`. WZO2: `CODE.WZO2-PASSBIT` PROVEN used the 3×3 artifact as the passing control (all four M4a-era checks pass); `WZO2.I2-CLEAN` MEASUREMENT — I2 0 / 49,428, independent re-implementation; the M4a-era A5 stride-97 sample was never verified coprime (`SPRINT-M4a-ACCEPT` caveat) and A6 fixture (c) was a broken positive control (`CODE.M4A-HARNESS` PROVEN) — bias downward | a WZO2 reader defect at 3×3 would have hidden the passes-bit defect | artifact2.zig |
| 8 | Verify battery at 3×3 | **CLAIMED** | I4 **differential** at 3×3 WZO2 — `src/i4_differential.zig`, R8 vs kernel, both exhaustive, 0 / 49,428 (T395); I2 exhaustive 0 / 49,428; I9 anchor +9; I7 (WZO1) known-fail | the differential is the strongest 3×3 instrument; a battery pass elsewhere is weaker | battery owner |

**Three weakest links at 3×3:**
1. **`3x3.C1` is CLAIMED, not PROVEN** — there is no exhaustive exact-solver ground truth at 3×3 (the finisher-era `3x3.FWD-SPOT` completed only 105 of 400 sampled roots; 295 exceeded budget). The +9 anchor match and the battery are strong, but "fresh-start correct at 3×3" has no exhaustive verification with a denominator.
2. **C3 is falsified at 3×3** — the bracket does not bound the real-game score (12-point leak). Since 3×3 is the smallest goban with a *meaningful* opening, this is the first size where the bracket's real-game reading must be refused outright.
3. **The WZO1 PSK artifact's ko-sensitive column rests on the KNOWN-WRONG writes-ON finisher** (`3x3.F2` measures completion only); anyone citing `artifacts/oracle-3x3.wzo` ko-sensitive values must cite the distrust, and the WZO2 table is the better object.

Count: 9 sub-steps (WZO2 construction) · **4 PROVED** (1, 2, 3a, 3b) · 4 CLAIMED (4, 5, 7, 8) · 1 N/A (finisher not in construction; KNOWN-WRONG in the WZO1 sibling).

---

## 4. 4×3 — `artifacts/oracle-4x3.wzo`

4×3 is the smallest size with **no WZO2 artifact** (the G3b I4 rung at 4×3 runs the WZO1 instrument because the WZO2 bracket check cannot read WZO1 — a format boundary, `4x4.C1` scope limit 2). Construction is the WZO1 PSK writes-ON path.

| # | step | basis | evidence | if wrong | owner |
|---|---|---|---|---|---|
| 1 | Colex enumeration + legality | **PROVED** | `4x3.S1` (PROVEN — mixed-radix layout is size-generic, structural inheritance with argument: 4×3 raw space is smaller than 4×4's exhaustive round-trip); `4x3.S3a` **PROVEN with a caveat** — 321,689 legal positions is the project's **own** ground truth (OEIS A094777 is n×n only; the "= OEIS" framing is withdrawn), independently reproduced by the census enumerator (`4x3.H1-CENSUS` PROVEN) | at 4×3 the count is self-derived, not externally attested | enumerate.zig |
| 2 | Move generation | **PROVED** | `GLOBAL.S3a`; I11 **0 / 643,378** at 4×3 (G3b/T363); key agreement **0 / 643,378** (T363 retroactive rung); T380 F-9 ko-cluster census over all 321,689 legal positions (0 mismatches, max 2 clusters) | as above | rules.zig / exp6 |
| 3a | Terminal detection | **CLAIMED** (impl inherited, not re-verified) | theorem PROVED (`GLOBAL.S2`, `4x3.S2`); **`4x3.S2-impl` UNTESTED** — the comptime `rules.zig` Benson code validated at 3×3 is not re-verified at 4×3; structural inheritance argued (same code), not registered as re-verified | terminal misclassification at 4×3 is unmeasured | `4x3.S2-impl` row |
| 3b | Area scoring | **CLAIMED** (inherited, not re-verified) | `GLOBAL.S4` PROVEN elsewhere; **`4x3.S4` UNTESTED (`⬜ᴵᴺᴴ`)** — self-declared inheritance, not re-proven at 4×3 | a size-dependent scoring regression at 4×3 is unmeasured | `4x3.S4` row |
| 4 | Retrograde sweep | **CLAIMED** | `4x3.FP1` CLAIMED; `GLOBAL.FP1`/`FP3` PROVEN math; 17 sweeps measured (`4x3.M2` MEASUREMENT) | as above | `4x3.FP1` row |
| 5 | L/H fixpoint | **CLAIMED** | `GLOBAL.AXIOM-LH`/`BRACKET` CLAIMED; **`4x3.C2` UNTESTED and `4x3.C3` UNTESTED** — explicitly NOT inherited from the 3×2/3×3 falsifications (per-goban independence); root **[+4,+12]** not single (`GLOBAL.ROOT-SINGLE-IFF-FORCIBLE-LIFE` MEASUREMENT, not independently audited) | the 4×3 bracket's real-game status is genuinely open, not analogy-closed | C2/C3 rows at 4×3 |
| 6 | KO_SENSITIVE finisher (writes-ON) | **KNOWN-WRONG** (mechanism); outputs unverified | `4x3.F1` CLAIMED — the committed 4×3 artifact was produced by the same unsound writes-ON path (inherited, `3x2.F1` PROVEN as the evidence); no Track A regen at 4×3; the `deps` (Track B) mode was validated at 4×3 (`4x3.F4` PROVEN — 0 auditor violations, byte-identical to writes-off) but the committed artifact was not rebuilt with it | the artifact's ko-sensitive values are unverified and the producing mechanism is known-unsound | Track A regen |
| 7 | Artifact format + reader | **PROVED** | `CODE.ADR0011-FMT`/`GATE` | as above | artifact.zig |
| 8 | Verify battery at 4×3 | **CLAIMED** | I4 at 4×3: **0 / 463,024 examined, 170,276 KO_SENSITIVE slots excluded** (WZO1 boundary — the check passes *around* the distrusted column); I5: **0 / 170,181** (`GLOBAL.I5-SCC-CONTAIN`, true-root convention; the T344 "24 natural violations" were **fabricated by an instrument defect** — `CODE.I5-INSTRUMENT-ADJUDICATION`; true reading 0); I7 known-fail (DTT unset) | the 4×3 battery readings all pass *around* the ko-sensitive column — the column itself is unverified | battery owner |

**Three weakest links at 4×3:**
1. **The artifact's ko-sensitive values rest on the KNOWN-WRONG writes-ON finisher** (`4x3.F1` CLAIMED) and there is no WZO2, no Track A regen, and no exhaustive ground truth at 4×3. The I4 check explicitly excludes the 170,276 KO_SENSITIVE slots — the checks pass around the column they cannot certify.
2. **`4x3.S2-impl` and `4x3.S4` are UNTESTED** — terminal detection and scoring at 4×3 are inherited from size-generic code without 4×3-specific re-verification. A size-dependent regression here would be invisible to every committed check.
3. **The 4×3 legal count is the project's own ground truth** (321,689 — no OEIS entry for non-square), independently reproduced internally but not externally attested; and the root bracket [+4,+12] is measured, not independently audited (`GLOBAL.ROOT-SINGLE-IFF-FORCIBLE-LIFE` scope note).

Count: 9 sub-steps · **3 PROVED** (1, 2, 7) · 5 CLAIMED (3a, 3b, 4, 5, 8) · 1 KNOWN-WRONG (6).

---

## 5. 4×4 — `data/oracle-4x4-v2.wzo2` (the deliverable)

The brief's starting point. Work outward from the artifact and ask of each stage *what justifies this?* The answer at 4×4 is the honest one: **the construction is CLAIMED at almost every stage — the G3b discharge set CLAIMED as the ceiling ("nothing here is PROVEN", accept.md signed ruling 2026-08-05), and the four scope limits ride with `4x4.C1`.**

| # | step | basis | evidence | if wrong | owner |
|---|---|---|---|---|---|
| 1 | Colex enumeration + legality | **PROVED** | `4x4.S1` (PROVEN — exhaustive round-trip through 4×4); `4x4.S3a` (PROVEN — 24,318,165 legal positions/side = OEIS A094777, cross-validated) | every address in the 518 MB artifact is wrong | colex.zig |
| 2 | Move generation | **CLAIMED** (bias downward: the exhaustive rung is missing) | kernel `GLOBAL.S3a` PROVEN; **I11 at 4×4 is a 50,000-state sample of 99,133,036 — 0.05%** (the one non-exhaustive G3b condition, `4x4.C1` scope limit 1); T345 key agreement **0 / 99,133,036** (table-exhaustive); T380 F-2 successor agreement **0 / 266,779** random states + ban-set invariants over 3,222,855 states; C-A1 closure 0 / 600,763,414 children | a move-generator defect in the unsampled 99.95% would pass every committed check — the T178/T193/T265 family (three producer/consumer key defects) shows the class is real | `GLOBAL.BATTERY-GAPS` G1/G3 |
| 3a | Terminal detection | **CLAIMED** | theorem PROVED (`GLOBAL.S2`); **`4x4.S2-impl` UNTESTED** — the Benson implementation is not exhaustively falsification-confirmed at 4×4; T400 ruling recorded (Tromp-Taylor as-stands at the terminal; Benson load-bearing for *status*, never for *scoring* — `GLOBAL.AXIOM-AREA` CLAIMED) | a terminal misclassification at 4×4 is unmeasured; the T400 ruling means the terminal scores exactly as stones stand | `4x4.S2-impl` row |
| 3b | Area scoring | **CLAIMED** (inherited) | `GLOBAL.S4` PROVEN elsewhere; **`4x4.S4` UNTESTED (`⬜ᴵᴺᴴ`)** — self-declared inheritance, not re-proven at 4×4 | a size-dependent scoring regression at 4×4 is unmeasured | `4x4.S4` row |
| 4 | Retrograde sweep | **CLAIMED** | `4x4.FP1` CLAIMED via the G3b discharge: I4 Bellman residual **0 / 95,677,624** KO_SENSITIVE-clear entries (verifies the fixpoint property); **`4x4.FP1-C1`/`C2` UNTESTED** (seed provenance from −N/+N and final zero-change sweeps — readable post-hoc from T104's audit output, never registered); 31 sweeps, `converged:true`, per-sweep L/H deltas digit-identical across rebuilds (`CODE.WZO2-BUILD-REPRO`) | the fixpoint converges to *a* fixpoint — least/greatest-ness rests on the PROVEN math plus the registered CLAIMED instance | `4x4.FP1`/`FP1-C1`/`FP1-C2` rows |
| 5 | L/H fixpoint (bracket) | **CLAIMED** | `4x4.C1` CLAIMED (G3b, four scope limits); root **L=+1, H=+16** (`4x4.BASICKO-TIE` MEASUREMENT; H=+16 verified genuine by T104 — 0 violations / 99,133,036 states); **the KO_SENSITIVE column (3,455,412 entries, 3.49%) is distrusted pending Track A** — the checks pass *around* it, not *on* it (I4 on KO_SENSITIVE-set entries: 0/3,455,412, held as measurement); `4x4.C2`/`4x4.C3` UNTESTED (analogy-expected falsified, NOT open hypotheses); bracket is mostly **not** ko-driven (T380 F-5: 92.6% of bracket-valued positions carry no ko shape) | the bracket's real-game reading is a non-claim (NC2); the KO_SENSITIVE column cannot be promoted while distrusted | Track A, C1/C2/C3 rows |
| 6 | KO_SENSITIVE finisher | **NOT IN THE WZO2 CONSTRUCTION** — and that is a *difference from the WZO1 era* | T380 F-8: `oracle_v2_build` reads the exp6 fixpoint directly; no finisher ran; I4 verifies L=Φ(L), H=Φ(H) at all 99,133,036 entries with an independent engine. The old checkpoints (`data/oracle-4x4.checkpoint.wzo`, `-parallel`) DID use the writes-ON finisher — KNOWN-WRONG (`GLOBAL.F1`; `4x4.F1` CLAIMED — same guard, structural bug); their ko-sensitive values are untrustworthy (foreclosure); `4x4.D3` (writes-off regen) UNTESTED — the single Track A gate; `4x4.F2`/`F3`/`F4` UNTESTED | (WZO2) none — the step is absent; (old checkpoints) every ko-sensitive reading is untrustworthy; a Track A regen would be needed to promote any of them | Track A / `4x4.D3` |
| 7 | Artifact format + reader | **CLAIMED** (bias downward: the format's own history is the defect catalog) | `CODE.WZO2-PASSBIT` PROVEN (first 518 MB artifact invalid — passes=1 encoded with passes=0, A3 failed on 16.5%, A9 on 24.3M rows; one-character fix `5deec6b`, rebuild); `CODE.WZO2-PASS1-LAW` PROVEN (the 131,068 absent entries are provably unreachable single-colour gobans — nothing to fill); `WZO2.I2-CLEAN` MEASUREMENT (0 / 99,133,036, independent re-implementation); `SPRINT-M4a-ACCEPT` PROVEN (4/4 on the rebuilt artifact); `4x4.WZO2-A2/A5/A8-EXHAUSTIVE` CLAIMED (0 / 99,133,036 each, held at CLAIMED per DIRECTION Amendment 2 edge 5 — exhaustive acceptance is measurement, not mutation adequacy); `CODE.WZO2-BUILD-REPRO` CLAIMED (byte-identical rebuild); **key-byte decode: T383 F-7 fixed the `kb >> 1` vs `kb >> 2` defect and T380 F-7 corrected the closure counts computed with the wrong decode (verdicts survived; 20,378-entry reachability difference); `src/keybyte_differential.zig` now pins decode(closure vs contract) over all 256 bytes × ko_bits {3,4,5}** | a key-byte defect changes which slot a value is read from — the exact defect class that produced three separate producer/consumer failures; the format is now pinned by a differential, which is the point | artifact2.zig / keybyte_differential.zig |
| 8 | Verify battery at 4×4 | **CLAIMED** | I4 0 / 95,677,624 clear (0 / 3,455,412 KO_SENSITIVE-set as measurement); I5 0 / 3,455,412 (`GLOBAL.I5-SCC-CONTAIN` — instrument adjudicated `CODE.I5-INSTRUMENT-ADJUDICATION`; cross-size differential wired `src/i5_differential.zig`); I7→A8 0 / 99,133,036 exhaustive (`4x4.WZO2-A8-EXHAUSTIVE`); I9 anchor **+1** — matches MIGOS's own basic-ko result (T274 primary sources; the +2 anchor is a different game, `GLOBAL.TIE-MIGOS` FALSE-AS-SCOPED); A1/A2/A8 were originally measuring an off-manifold walk — the acceptance harness carried its own divergent ko rule (`CODE.ACCEPT-KOKEY` PROVEN, fixed T273); the general battery returns battery-bad for 4×4 I4/I5/I7 (T388 D-divergences; size-specific instruments carry those cells) | a battery pass at 4×4 is a CLAIMED reading with instrument-adjudication history, not an independent certification | battery owner / T388 demotion proposals |

**Three weakest links at 4×4:**
1. **The KO_SENSITIVE column (3,455,412 entries — 3.49% of the table, including the root's bracket) is distrusted pending Track A.** Every check passes *around* it, not *on* it; `4x4.D3` (the writes-off regen) is UNTESTED. Until Track A runs and the #2 auditor passes on a writes-off build, no ko-sensitive value at 4×4 is quotable, and the root's bracket [1,16] — the single most important datum in the table — remains a CLAIMED fixpoint interval whose promotion is blocked.
2. **`4x4.C1` is CLAIMED with four registered scope limits** — the largest being I11's 0.05% sample and the KO_SENSITIVE distrust; nothing at 4×4 is PROVEN, and the G3b accept.md says so in those words. The exhaustive acceptance sweeps (A2/A5/A8) are held at CLAIMED because exhaustive *measurement* is not mutation *adequacy* (DIRECTION Amendment 2 edge 5).
3. **Terminal detection and scoring at 4×4 are inherited, not re-verified** (`4x4.S2-impl` and `4x4.S4` UNTESTED) — and the producer/consumer key-agreement family (T178/T193/T265 + GTP/ACCEPT ko-key defects) has **no battery invariant** (G1/G3); the three worst defects of the project's P2 wave lived exactly there.

Count: 9 sub-steps (WZO2 construction) · **1 PROVED** (1) · 7 CLAIMED (2, 3a, 3b, 4, 5, 7, 8) · 1 N/A (finisher absent; KNOWN-WRONG in the sibling checkpoints).

---

## 6. The dependency structure (ASCII) — the 4×4 WZO2 construction

```
data/oracle-4x4-v2.wzo2  (99,133,036 entries, root L=+1 H=+16)
│
├─ written by oracle_v2_build.zig  [CLAIMED: CODE.WZO2-BUILD-REPRO]
│    └─ reads exp6_solve.zig fixpoint tables (ADR-0020 loopy-game, basic ko, TIE=0)
│         └─ L/H fixpoint sweeps [CLAIMED: 4x4.FP1 via G3b I4 0/95,677,624]
│              └─ Bellman operator over the (position, side, ko_point, passes) graph
│                   ├─ move generator [CLAIMED: I11 0/50,000 sampled; T345 0/99,133,036 keys;
│                   │                  T380 F-2 0/266,779 successors]
│                   │    └─ rules.zig kernel [PROVED: GLOBAL.S3a]  ← the only PROVED rung
│                   ├─ terminals: is_settled (Benson) + double pass [CLAIMED: 4x4.S2-impl UNTESTED]
│                   │    └─ GLOBAL.S2 Benson theorem [PROVED]
│                   ├─ scores: area_score, Tromp-Taylor as-stands (T400) [CLAIMED: 4x4.S4 UNTESTED]
│                   │    └─ GLOBAL.S4 [PROVED elsewhere; 4×4 inheritance not registered]
│                   └─ colex addressing [PROVED: 4x4.S1, 4x4.S3a]
│
├─ verified by the battery (G3b discharge, CLAIMED ceiling):
│    I4 Bellman residual 0/95,677,624 clear (+0/3,455,412 KO_SENSITIVE-set, measurement)
│    I5 KO_SENSITIVE ⊆ cycle-reachable 0/3,455,412
│    C-A1 closure 0/600,763,414 children · C-A2 0/99,020,312 reachable
│    A2/A5/A8 exhaustive 0/99,133,036 each (CLAIMED: measurement ≠ mutation adequacy)
│    key agreement 0/99,133,036 (T345) · I11 0/50,000 (sampled)
│    └─ every invariant has its own instrument; I4/I5 have cross-engine differentials
│       (i4_differential, i5_differential, keybyte_differential — T395)
│
└─ NOT in the construction: the finisher. T380 F-8: the WZO2 table is pure fixpoint.
     The finisher fills only the old PSK checkpoints' KO_SENSITIVE column, where it is
     KNOWN-WRONG as committed (GLOBAL.F1) and Track A (4x4.D3, writes-off) is the gate.
```

The same spine — enumeration → moves → terminals → scores → sweep → brackets → artifact → battery — is the spine at every size; the per-goban tables above differ only in which rungs are PROVED and which are CLAIMED.

---

## 7. The verify-battery invariants — what each establishes, and whether its instrument has a differential

T395's ownership table (`docs/infra/property-ownership.md`) is the input; this section restates it in solution-tree terms: **what each check actually establishes, and whether the check could be wrong without anyone noticing.** The T388 coverage map (`docs/infra/instrument-coverage.md`) is the source for the divergence inventory.

| check | what it establishes (AXIOMS tree node) | production instrument (per T395) | independent differential? | size-specific state today |
|---|---|---|---|---|
| **I4** Bellman residual (L=Φ(L), H=Φ(H)) | Z-CONVERGE-FIX — the table IS a fixpoint | WZO1 ≤4×3: `vb_fixpoint.checkI4`; WZO2 4×4: `oracle_v2_accept.checkA2` (kernel) — with `vb_bellman_4x4` (R8) a **duplicate** (demotion pending, T395 §4) | **YES** — `src/i4_differential.zig`: R8 vs kernel on 3×3 WZO2, both exhaustive, 0/49,428, non-vacuous n_set=5,408 | 4×4: 0/95,677,624 clear (CLAIMED, G3b); 0/3,455,412 KO_SENSITIVE-set as measurement; 4×3: 0/463,024 (170,276 excluded — WZO1 boundary) |
| **I5** SCC containment (KO_SENSITIVE ⊆ cycle-reachable) | Z-CONVERGE-FIX + Z-STATE — a history-dependent slot must be in a cycle | `vb_graph` (≤3×3) / `vb_scc_4x4` (4×3/4×4, adjudicated correct by T391) | **YES** — `src/i5_differential.zig` (3×2 permanent, 4×3 env-gated for RSS), with four seeded-defect controls that demonstrably fire (T395 §2) | 4×4: 0/3,455,412 (CLAIMED); 4×3: 0/170,181; 3×2 vacuous in the full-graph model (G3b §3.1) |
| **I7** DTT sanity | Z-TABLE-FAITHFUL + Z-CONVERGE-FINITE — the DTT column was computed, not initialised | WZO1: `vb_fixpoint.checkI7`; WZO2: `oracle_v2_accept.checkA8` | **NO same-artifact differential** — WZO1 and WZO2 are different builds with different ko conventions; the two formats can never share a cell (T388 D4; T395 §4 proposal: adopt A8's recurrence as the single definition) | **WZO1: known-fail** — the DTT column of every WZO1 artifact is the `@memset` initialiser (`CODE.WZO1-DTT-UNSET` PROVEN); WZO2 4×4: A8 exhaustive 0/99,133,036 (CLAIMED) |
| **I9** anchors | Z (the theorem root) — root values match committed references | `vb_fixpoint.checkI9` (size-parametric) | none needed (already parametric) | 2×2=0, 3×2=0, 3×3=+9, 4×4=+1 **for the basic-ko tables**; ruleset-aware per `GLOBAL.MIGOS-RULE` (MIGOS plays basic ko, not PSK); the +2 anchor is a different game (`GLOBAL.TIE-MIGOS` FALSE-AS-SCOPED, T274 primary sources) |
| **A1** refusal rate | Z-COMPLETE (headline) — every reachable state has an entry | `oracle_v2_accept.checkA1` (self-play) | — | **originally off-manifold**: the acceptance harness carried its own divergent ko rule (`CODE.ACCEPT-KOKEY` PROVEN) — A1/A2/A8 were measuring their own walk; fixed T273 |
| **A2** Bellman residual after round-trip decode | Z-CONVERGE-FIX + Z-TABLE | `oracle_v2_accept.checkA2` (kernel engine) | `vb_bellman_4x4` (R8) + `i4_differential` | 4×4: 0/99,133,036 exhaustive (`4x4.WZO2-A2-EXHAUSTIVE` CLAIMED) |
| **A3** colour inversion (exhaustive) | Z-SYM | `oracle_v2_accept.checkA3` | `WZO2.I2-CLEAN` — independent re-implementation (T270) | 4×4: 0/99,133,036 both instruments; 3×3: 0/49,428; **v1 basic-ko artifact fails ~48%** (`4x4.V1-INVSYM-BROKEN` PROVEN) |
| **A4** pin census (L==H vs L<H, pin_T/L/H) | Z-CONVERGE-FIX (I1) | `oracle_v2_accept.checkA4` | none needed | measurement (no pass/fail on counts); `pin_L == pin_H` is the structural invariant |
| **A5** round-trip identity (decode(encode(x))==x) | Z-TABLE-ROUNDTRIP | `oracle_v2_accept.checkA5` | `4x4.WZO2-A5-EXHAUSTIVE` | 4×4: 0/99,133,036 exhaustive (CLAIMED); the original stride-97 sample was never verified coprime to group sizes (T215 — materially weaker) |
| **A6** known-bad calibration (mutants) | Z-AUDIT (mutation) | `oracle_v2_accept.checkA6` (three corruptions) | mutation corpora duplicated across WZO1/WZO2 (T388 D8) | 3 fixtures; **fixture (c) is a broken positive control** (`CODE.M4A-HARNESS` PROVEN — calls the check on the uncorrupted slice) |
| **A7** gate chain reproduced through the format | Z-TABLE-FAITHFUL (I9 at small gobans) | anchors read back through WZO2 | none needed | 2×2=0, 3×2=0, 3×3=+9 reproduced before any 4×4 build (builder gate) |
| **A8** DTT non-constant | Z-TABLE-FAITHFUL | `oracle_v2_accept.checkA8` | none same-artifact (see I7) | 4×4: 0/99,133,036 exhaustive (`4x4.WZO2-A8-EXHAUSTIVE` CLAIMED) |
| **A9** reproducibility (deterministic bytes) | Z-TABLE (determinism contract) | `oracle_v2_accept.checkA9` — **implemented as embedded-hash self-consistency, relaxed vs spec** (`CODE.M4A-HARNESS`) | `CODE.WZO2-BUILD-REPRO` (byte-identical rebuild across six intervening commits) | 4×4: 0 entry-order violations (`SPRINT-M4a-ACCEPT`); rebuild CLAIMED |
| *(not in the I/A list but load-bearing)* **key agreement** (producer kernel vs consumer R8 keys) | Z-R-STATE + Z-STATE-KEY | `differential.zig` T267 game-sampled form (all sizes) + T345 table-exhaustive form (4×4, 4×3) | two forms of one instrument; exhaustive only at 4×4/4×3 (T388 D6) | 4×4: 0/99,133,036; **no battery cell** (G1/G3 gap — the T178/T193/T265 family has zero battery coverage; `GLOBAL.BATTERY-GAPS`) |

**The pattern the table exposes:** every check that *measures the artifact against itself* (I1–I3, I6, I10, I12, and the A-series round-trips) is sound but could pass while the table is wrong — the T380 lesson "internal consistency is not external agreement" (ADR-0022). The checks with independent differentials — I4 (R8 vs kernel), I5 (general vs size-specific), key-byte decode (closure vs contract), key agreement (producer vs consumer) — are the ones that have actually found defects (T391, T383 F-7, T265/T266). T395's rule is the standing one: **a property with two implementations needs a differential that demonstrably fires; a differential never shown to fail is not evidence.**

---

## 8. What is left to prove — ordered by how much risk each proof removes

**(a) Proofs outstanding, most-risk-reducing first.** Each is a construction step whose basis today is CLAIMED or worse.

1. **Track A — the 4×4 writes-off finisher regen + the #2 auditor** (`4x4.D3` UNTESTED; gates `4x4.F2`/`F3`/`F4`, artifact promotion). The single largest open item: the KO_SENSITIVE column (3.49% of the 4×4 table) cannot be promoted while distrusted, and every WZO1-era ko-sensitive value (2×2/3×2/3×3/4×3/4×4 checkpoints) shares the writes-ON taint. Proving the writes-off build self-consistent (auditor: 0 minimax violations, 3×2 exhaustive + deepest-N 4×4 sample) converts the region from "distrusted" to "CLAIMED-with-auditor".
2. **`4x4.C1`'s promotion conditions**: (i) mutation adequacy for the exhaustive acceptance runs (DIRECTION Amendment 2 edge 5 — exhaustive measurement is not mutation adequacy; the kill matrix must cover the checked functions); (ii) an **exhaustive I11 at 4×4** (closing the 0.05% sample — the one non-exhaustive G3b condition; 600M children makes it scale-expensive but it is the only missing denominator).
3. **`4x4.S2-impl` (Benson implementation at 4×4) and `4x4.S4` (area scoring at 4×4)** — both UNTESTED, both cheap to close (the 3×3 falsification sweep rerun at 4×4; the independent Python scorer rerun at 4×4). Without them, terminal detection and scoring at 4×4 rest on inheritance alone.
4. **`4x4.FP1-C1`/`C2` (seed provenance from −N/+N; final zero-change sweeps at 4×4)** — readable post-hoc from T104's audit output; closes the Z-CONVERGE-SEED gap that no battery invariant covers (spec §2, accepted gap).
5. **Re-derivation of `GLOBAL.Z-R-MOVE-B1-EQUIV`** — the corrected recapture-identity lemma is CLAIMED (matching the code is not a proof; T384), and the `rules.zig:1385,1446` tests still mechanize the **falsified** old predicate (152/784 falsifications at 3×3, 36,446/344,996 at 4×4 — T380 F-3). A re-derivation converts a corrected-but-unproven lemma into a theorem; re-mechanized tests at 3×3+ stop a known-wrong predicate from passing silently.
6. **A battery invariant for producer/consumer key agreement (G1/G3)** — the T178/T193/T265 family is the project's most expensive bug class and has zero battery coverage; the T345/T267 differentials exist but live outside the battery. Proving this cell means the class cannot recur unnoticed.
7. **Per-goban C2/C3 probes at 3×3, 4×3, 4×4** — 3×3.C2 and 4×3.C2/C3 are genuinely open (UNTESTED, not inherited); 4×4 C2/C3 are analogy-expected-falsified (NOT open hypotheses per the 4×4 tree) — a 4×4 probe would be characterisation, not a decision. Lowest priority for the deliverable, highest for the real-game story.
8. **The 3×2/4×3 I5 seeded-defect vacuity** (G3b §3.1) — the spec's premise that 3×2 is the first non-vacuous rung is false in the full-graph model; the first genuine red-then-green rung is 4×4. A spec-premise finding awaiting disposition, not a code defect.

**(b) What is left to write, test, or re-verify.** The tree's second payoff: steps that are CLAIMED because the *instrument* was never written, run, or wired.

1. **Re-mechanize the B1 recapture-identity tests at 3×3+** (`src/rules.zig:1385,1446` — old falsified predicate; T384 recorded the debt, no row has fixed it).
2. **Wire or delete the dead battery stubs**: `vb_fixpoint.checkI11` and `checkI8` are permanent not-applicable stubs (`CODE.VB-BLINDGAPS`, `CODE.VB-STUBS`); the battery's RSS field returns null (`4x4.I5-FEAS` projection unvalidated — no run has measured memory at any size).
3. **Persist the WZO2 gate-chain tables at 2×2/3×2/4×3** — the builder computes the gate anchors (0/0/+9) but writes no artifact below 3×3; the current-rule deliverable at those sizes exists only in evidence.
4. **Close the format split on I7** (T395 §4 proposal 3 / T388 §3): adopt A8's DTT recurrence as the single definition and port I7's terminal checks into the WZO2 path — or explicitly document the WZO1 DTT column as the known-unset baseline per artifact (`CODE.WZO1-DTT-UNSET`).
5. **Run the gated scale cells**: C-A1/C-A2 closure at 4×4 (env `WEIZIGO_CLOSURE_4X4_FULL=1`), I5 cross-instrument 4×3 cell (`WEIZIGO_I5_DIFF_4X3=1`), and add the T345 exhaustive key-agreement rung at 3×3 WZO2 (cheap, 49,428 entries — T395 §4 proposal 5).
6. **Reconcile the mutation kill matrix** (T388 D8): `mutants.md` vs `vb_mutants.zig` vs T363's "7/7" disagree — a prerequisite to any mutation-adequacy promotion of the exhaustive acceptance runs.
7. **Regenerate and re-hash the old PSK checkpoints with `memo_writes=false`** (ADR-0013 Track A consequence) — writes-off checkpoints exist in `untracked/` (`oracle-4x4-writesoff-*.wzo`) but are neither committed nor audited. **Corrected 2026-08-22 (T571):** they *are* hashed — `docs/evidence/README.md:165-166` records both sha256s and T571 reproduced them — and two provenance findings change what a regen is for. (i) `untracked/oracle-4x4-writesoff-checkpoint.wzo` is **byte-identical** to `data/oracle-4x4-parallel.checkpoint.wzo` (sha256 `28afa11b…`, same payload CRC), so the 2026-07-27 "writes-OFF 1.67 % vs writes-ON 4.08 %" comparison (`ko-sensitive-chainability.md:255-300`) was one file against another build of the *same* family under two names — confounded, not a writes-flag measurement. This also settles the D16 open note (`CLAIMS.md:1069-1072`) for that pair. (ii) both `untracked/` files are `rules_id = 1` (PSK), so neither can cross-check the basic-ko + TIE=0 WZO2 table at all. Evidence: `docs/evidence/T571-SINGLE-POSITION-LEAK/{leak-resolution-2026-08-22.md,PROVENANCE.md}`.
8. **Decide the 5×4/5×5 sizing question on the measured ledger**: the G3b I5 memory ledger is measured at ~3.7 GB of in-memory arrays at 4×4 (2.3×–3.4× the plan's forecast) — the scale decision is a write/test/plan item, not a proof.
9. **The bracket-resolution problem (ADR-0022)**: the honest deliverable is bracket + resolver proposals; every resolver so far (capture budget, truncation, median-pin, finisher, PSK graft) is measured wanting — "internal consistency is not external agreement." The comparison harness and baselines exist; a resolver that beats them does not.

---

## 9. Counts and method

| goban | sub-steps identified | PROVED | CLAIMED | KNOWN-WRONG / N/A | weakest-link summary |
|---|---|---|---|---|---|
| 2×2 | 9 | **5** | 3 | 1 KNOWN-WRONG (finisher; outputs rescued by ground truth) | finisher mechanism, lost B1 evidence, no persisted basic-ko artifact |
| 3×2 | 9 | **5** | 3 | 1 KNOWN-WRONG (finisher; **45/378 violations as committed**) | wrong ko-sensitive column, lost B1 evidence, C2 falsified |
| 3×3 | 9 (WZO2) | **4** | 4 | 1 N/A (finisher absent; KNOWN-WRONG in WZO1 sibling) | C1 not exhaustive, C3 falsified, WZO1 ko-sensitive column unverified |
| 4×3 | 9 | **3** | 5 | 1 KNOWN-WRONG (finisher; outputs unverified) | finisher taint + no WZO2, S2-impl/S4 untested, self-derived legal count |
| 4×4 | 9 (WZO2) | **1** | 7 | 1 N/A (finisher absent; KNOWN-WRONG in checkpoints) | KO_SENSITIVE column distrusted (Track A), C1 CLAIMED with four scope limits, terminal/scoring inherited + no key-agreement battery cell |
| **total** | **45** | **18** | 22 | 5 | — |

**Denominators stated:** per-size counts are over the nine sub-steps of the brief's family list (step 3 split into 3a/3b for precision); the total row is the sum (45 = 5×9). 18 of 45 steps are PROVED — **40%** — and the PROVED fraction falls monotonically with size (5/9 → 5/9 → 4/9 → 3/9 → 1/9 at 4×4). That monotone fall is itself the finding: **the table the project ships is the one whose construction is least proved.**

**What was looked at** (the archaeology list, in case a step's basis needs re-examination): `docs/epistemic/CLAIMS.md` (register, all live rows), `docs/epistemic/PROGRESS.md`, `docs/engine/ARCHITECTURE.md`, `docs/decisions/` (0003–0013, 0015–0021, ADR-0020, ADR-0022), `docs/epics/E1-markovian/AXIOMS.md` (§1–§3), the verify-battery spec (`sprints/verify-battery/pass1/spec.md`), the G3b accept (`sprints/g3b-value-correctness/pass0/accept.md`), the oracle-v2 design/spec (`sprints/oracle-v2/`), T395's ownership table (`docs/infra/property-ownership.md`), T388's coverage map (`docs/infra/instrument-coverage.md`), T380's ko-review findings, the per-goban epistemic trees (`boards/{2x2,3x2,3x3,4x3,4x4}/EPISTEMIC.md`), `retro.zig` and `oracle_v2_build.zig` headers, `artifacts/SHA256SUMS`, and the `data/` inventory.

**UNDETERMINED — needs archaeology (none found for the eight families, three marginal items):** (i) whether the 2×2/3×2 WZO1 artifacts were written by the writes-ON or writes-off finisher build — ADR-0011/0013 imply writes-ON (the Track A regen was ordered for "every artifact (2×2..4×4)") but no build log survives; graded KNOWN-WRONG-mechanism with the ground-truth rescue at 2×2, consistent with both readings. (ii) Whether A6 fixture (c) (broken positive control, `CODE.M4A-HARNESS`) was fixed by T273 — no row records a fix; graded as recorded. (iii) The exact 4×4 sweep count of the *checkpoint* (19, `4x4.M2`) vs the *WZO2* build (31, `CODE.WZO2-BUILD-REPRO`) — two different tables, both measured; no contradiction.

**Close:** the operator's two lists are §8(a) and §8(b). The tree's headline, in one line: **every size's construction is proved exactly where the epistemic register is strongest (enumeration, kernel moves, Benson theorem, area scoring) and claimed exactly where it is weakest (finisher, bracket meaning, per-size re-verification) — and the gap widens with size, so the 4×4 deliverable is the size whose construction is least proven.**

---

*Cross-references: this file is the construction twin of the epistemic trees in `boards/`; register rows are cited by ID throughout; the instrument ownership table is `docs/infra/property-ownership.md`; the coverage map is `docs/infra/instrument-coverage.md`; the ruleset the WZO2 tables solve under is `docs/epics/E1-markovian/AXIOMS.md` §1–§2 (ADR-0020).*
