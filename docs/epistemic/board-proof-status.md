# Board proof status — where each goban is proven, where it is only optimal, where it is unknown

**Task:** T836 (where is each board actually proven) · **Worker:** claude-opus-5/T836 · **Date:** 2026-08-24
**Landmark:** advances **L2 (proven 4×4 values)** — this is the precondition for any claim about
solving 4×4, and it is the *knowing* half of the operator's 2026-08-24 ruling:

> *"I would like us to prove smaller boards and prepare to perfectly solve 4x4 (or know exactly
> where it's perfectly proven and where it's only optimal, and where the unknowns are)."*

**This file proves nothing new.** It is a census. It states, with committed citations and per rule
set, what is proven, what is best-found-but-unverified, what is unknown, and what is untrustworthy,
for every solved goban size. **No claim status was changed and none is proposed** — status changes
need an auditor under the D2 audit policy, and a census is not a ruling. Where the register or the
documents contradict themselves, both readings are recorded with their citations and neither is
picked.

**Read alongside, not instead of:**
`docs/epistemic/CLAIMS.md` (the register — what we believe is *true*) ·
`docs/epistemic/SOLUTION-TREE.md` (T415 — what the table's *construction* rests on) ·
`docs/epistemic/boards/{2x2,3x2,3x3,4x3,4x4}/EPISTEMIC.md` (per-goban trees) ·
`archives/register/INDEX.md` (the 132 rows triaged out on 2026-08-05 — the disowned half of the record) ·
`docs/audits/2026-08-02-grand-audit/DIRECTION.md` (ratified direction: complete epic-01 in place,
strictly k=1, doubt all claims including the falsifications).

---

## 0. Method, vocabulary, and the two things that make a status meaningless without them

### 0.1 The status vocabulary of this census

These five labels are **this file's** vocabulary. They are deliberately *not* the register's status
set (`PROVEN` · `CLAIMED` · `MEASUREMENT` · `UNTESTED` · `FALSE-AS-SCOPED` · `FALSE` · `INTRACTABLE`
· `SUPERSEDED`). Where they disagree with a register status, the disagreement is the finding — §3
lists every instance — and the register row is unchanged.

| label | meaning |
|---|---|
| `PROVEN` | the result **plus a check that would catch it being wrong**: a committed, re-runnable, non-vacuous falsifier (a `src/` test with a denominator, a `docs/evidence/` probe, or — for a theorem — a stated mathematical refutation route) |
| `OPTIMAL-NOT-PROVEN` | best-found, unfalsified, **not** exhaustively verified by any check that exists today. The result may well be right; nothing committed would tell us if it were not |
| `PARTIAL` | proven over a named sub-domain with the remainder open, and the sub-domain's denominator is stated |
| `UNKNOWN` | no live claim, or a live claim with no measurement. **Required where true; a census that resolves everything is not a census** |
| `UNTRUSTWORTHY` | positively known or recorded to be wrong, or produced by a mechanism recorded as unsound. Distinct from `UNKNOWN`: §4 separates them |

### 0.2 The falsifier rule, applied strictly

**`PROVEN` requires a falsifier that exists today.** A result verified once, whose probe and output
were never committed, has no falsifier: nothing would catch a regression, and no one can re-derive
it. `weizigo-claimlint` check **C3 UNBACKED** already makes this distinction machine-readable —
Tier A = probe committed under `docs/evidence/`; Tier B = committed prose only; Tier C = nothing
resolves. At HEAD: **42 of 66 `PROVEN` register rows are Tier B, 0 are Tier C, 24 are Tier A.** The
brief predicted "expect several" downgrades. There are **fourteen** board-scoped ones (§3).

Two refinements the brief's rule needs, both applied and both declared:

1. **A committed `src/` test counts as a falsifier even though C3 does not look there.** C3 scans
   `docs/evidence/` only. A `zig build test` rung with a denominator is a better falsifier than a
   one-shot script, and the project's own doctrine is instruments over documents. Where a Tier-B row
   nonetheless has a committed test at its own size, this census grades it `PROVEN` and names the
   test. Where the test exists but at a *smaller* size than the claim, that is `PARTIAL`, not
   `PROVEN` — and this is where most of the downgrades come from.
2. **A theorem needs no probe.** `GLOBAL.S2` (Benson) and `GLOBAL.FP1`/`FP3` (Knaster–Tarski on a
   finite lattice) are mathematics; their falsifier is a counterexample, and the register already
   keeps the theorem and its implementation as separate rows (`S2` vs `S2-impl`). That separation is
   the single best epistemic habit in the register and it is why the theorem rows survive this pass
   intact.

### 0.3 The rule sets — a result without one is meaningless

The project solves **configurable** rules. Two rule sets are in play, they are not
interchangeable, and **they give different values on the same empty goban**:

| tag | rules | where it lives |
|---|---|---|
| **R_PSK** | Chinese area scoring, komi 0, **positional superko**, Benson/double-pass terminal (`rules_id = 1`; ADR-0003) | WZO1 artifacts: `artifacts/oracle-{2x2,3x2,3x3,4x3}.wzo`; `data/oracle-4x4.checkpoint.wzo`, `data/oracle-4x4-parallel.checkpoint.wzo` |
| **R_BK0** | area scoring, komi 0, **basic ko (k = 1)**, loopy-game fixpoint with **TIE = 0** (`ADR-0020`; `docs/epics/E1-markovian/AXIOMS.md` §1–§2) | WZO2 artifacts: `data/oracle-3x3-v2.wzo2`, `data/oracle-4x4-v2.wzo2`. **At 2×2, 3×2 and 4×3 no R_BK0 artifact is persisted** — those tables exist only inside `docs/evidence/QA-026/` and inside T394's in-memory closure |

**R_BK0 is the deliverable.** R_PSK exact solve is a standing foreclosure — intractable at
118,475,182 ban-set states on the **empty 2×2** (`AGENTS.md`; `docs/research/ruleset-options.md`),
and score-on-cycle is provably as hard. Anything labelled "the 4×4 value" without a rule set is
therefore not a claim; it is an ambiguity.

**The empty-goban root, per size, per rule set — the worked demonstration:**

| goban | R_PSK root | R_BK0 root | live status of the R_BK0 reading |
|---|---|---|---|
| 2×2 | **+1** (`SOLUTION-TREE.md:20`) | **0 (TIE)**, bracket **[−4,+4]** | `2x2.BASICKO-TIE` MEASUREMENT; independently re-implemented (`docs/evidence/QA-023/ko-fix-2026-07-29/fix2x2.py`) |
| 3×2 | **+1** (`SOLUTION-TREE.md:21`) | **0 (TIE)**, bracket **[−6,+6]** | `3x2.BASICKO-TIE` MEASUREMENT |
| 3×3 | **+9** | **+9** (L == H) | `3x3.BASICKO-TIE` MEASUREMENT; matches the MIGOS II anchor under aligned rules |
| 4×3 | bracket **[−1,+12]** (`boards/4x3/EPISTEMIC.md:43` — and `4x3.BRACKET` is **ARCHIVED**) | bracket **[+4,+12]** (`docs/research/force-life-classifier-2026-08-06.md:118`) | **no register row exists** — §5 C-9 |
| 4×4 | **+2** claimed in the retracted era — **UNTRUSTWORTHY**, §4 U2 | **L = +1, H = +16** | `4x4.BASICKO-TIE` MEASUREMENT; H = +16 verified genuine, 0 violations / 99,133,036 |

Two rule sets give **different** roots at 2×2 and 3×2 (+1 vs 0) and at 4×3 ([−1,+12] vs [+4,+12]).
Neither difference is an error. Both are invisible to a reader handed the number alone — which is
precisely the operator's point, and it is why every row below carries a rule-set cell.

### 0.4 Goban naming

The brief names the sizes `2x2, 2x3, 3x3, 3x4, 4x4`. The register scopes, the `boards/`
directories and the artifact filenames all use **width × height**: `2x2, 3x2, 3x3, 4x3, 4x4`. Same
five gobans (4, 6, 9, 12 and 16 points). This census uses the register spelling so every ID resolves.

### 0.5 The questions

Eleven questions, taken from what the register and the per-goban trees actually track, asked of all
five sizes — **55 rows**. Presented as one census partitioned by size for legibility; the column set
is identical throughout.

| # | question | register families |
|---|---|---|
| **Q1** | Addressing and enumeration — is the index a bijection, is the legal-position count right? | `S1`, `S3a` |
| **Q2** | Rules kernel — move, capture, suicide, ko legality | `S3a`, `AXIOM-BASICKO` (B1) |
| **Q3** | Terminal detection and scoring | `S2`, `S2-impl`, `S4`, `ADR0004-TERM`, `AXIOM-AREA` |
| **Q4** | Root game value of the empty goban | `BASICKO-TIE`, `ANCHOR`, `MIGOS-RULE` |
| **Q5** | Whole-table fresh-start value correctness | `C1` |
| **Q6** | L/H fixpoint and bracket semantics | `FP1`, `FP1-C1/C2/C3`, `FP3`, `B1`, `AXIOM-LH`, `AXIOM-BRACKET` |
| **Q7** | Optimal play — the KO_SENSITIVE column and the finisher | `F1`, `F2`, `F3`, `F4`, `D3` (Track A) |
| **Q8** | Real-game correctness — history-independence and bracket bounding | `C2`, `C3`, `C4`, `T12`, `T13`, `LEAK` |
| **Q9** | Life and death | `S2`, `TWO-LIFE-ONSET`, `ROOT-SINGLE-IFF-FORCIBLE-LIFE`, `LIFE-CERTIFIES` |
| **Q10** | Ko and cycle structure | `H1-CENSUS`, `I5-SCC-CONTAIN`, `OPTIMAL-CYCLE`, `LOOPY-TAXONOMY` |
| **Q11** | Artifact and battery integrity | `ADR0011-FMT/GATE`, `WZO2-*`, `WZO1-DTT-UNSET`, `VB-STUBS` |

---

## 1. The census

Legend for the evidence cell: **[M]** machine-checkable and re-runnable today · **[P]** committed
prose only · **[X]** the evidence is recorded lost or archived.

### 1.1 — 2×2 (4 points; 57 legal positions/side)

| # | status | rule set | evidence | falsifier (if PROVEN) / gap (if not) |
|---|---|---|---|---|
| Q1 | **PROVEN** | rule-independent | `GLOBAL.S1` PROVEN [P]; `src/colex.zig:256` exhaustive bijection at 2×2 [M] (run 2026-08-24: 5/5 pass); `GLOBAL.S3a` PROVEN-as-scoped, `docs/evidence/GLOBAL-S3a/probe_legal_count_2026_08_20.py` [M] | **Falsifier:** `zig test src/colex.zig` — any collision or round-trip mismatch over all 3⁴ = 81 raw slots fails; re-run the legal-count probe, a count ≠ 57 falsifies |
| Q2 | **PROVEN** | R_BK0 (ko); rule-independent (move/capture/suicide) | `docs/evidence/GLOBAL-S3a/probe_kernel_2x2_gtp_2026_08_20.py` — 0/570 kernel violations at 2×2 [M]; `src/rules.zig:1217` exhaustive 2×2 ko agreement with the solver [M]; `src/rules.zig:1357` **seeded-defect control** — the old buggy rule *does* disagree [M] | **Falsifier:** `zig test src/rules.zig`. The seeded-defect control is what makes this a proof rather than a green light: the check is demonstrated able to fail |
| Q3 | **PARTIAL** | rule-independent | theorem: `GLOBAL.S2` PROVEN [M] `docs/evidence/GLOBAL-S2/PROVENANCE.md`; scoring: `GLOBAL.S4` PROVEN [M] independent Python Tromp–Taylor scorer, 0 disagreements / 120 gobans; `GLOBAL.ADR0004-TERM` PROVEN [P] | **Sub-domain proven:** the theorem, and area scoring on the 120-goban sample. **Gap:** no 2×2-scoped `S2-impl` or `S4` row exists and the committed Benson theorem rung (`src/rules.zig:655`) runs at 3×3, not 2×2. 2×2 is trivially inside ≤ 4 stones, but nothing records it |
| Q4 | R_PSK: **OPTIMAL-NOT-PROVEN** · R_BK0: **PROVEN** | both | R_PSK +1: `SOLUTION-TREE.md:20` [P], finisher-produced. R_BK0 0 (TIE), [−4,+4]: `2x2.BASICKO-TIE` MEASUREMENT, `docs/evidence/QA-026/PROVENANCE.md` + `exp4-solve-2026-07-29.stdout` [M]; corroborated by `GLOBAL.ROOT-SINGLE-IFF-FORCIBLE-LIFE` and `GLOBAL.ADR0020-LH-CORRECT` PROVEN | **R_BK0 falsifier:** re-run `docs/evidence/QA-023/ko-fix-2026-07-29/fix2x2.py` — an **independent Python re-implementation**; a root ≠ [−4,+4] falsifies. This is the only root value in the project with a committed independent re-implementation. **R_PSK gap:** +1 came off the KNOWN-WRONG writes-ON finisher and is rescued only by `2x2.C1`, itself downgraded (§3) |
| Q5 | R_PSK: **OPTIMAL-NOT-PROVEN** (register says PROVEN) · R_BK0: **PROVEN** as fixpoint-correctness, **PARTIAL** as least/greatest-ness | both | R_PSK: `2x2.C1` PROVEN, C3 **Tier B** [P]. R_BK0: `GLOBAL.ADR0020-LH-CORRECT` PROVEN — 0 Bellman violations, 0 L > H, 0 colour-inversion violations over **all 1,620 non-terminals**; `docs/audits/adr0020-gap-adjudication.md` §2–4; `src/retro.zig` tests at :4575, :4594 [M] | **R_PSK gap:** §6-**D9** records that the "exhaustive ground truth" was **8 of 114 roots** at 2×2; no re-runnable exact-solver comparison is committed. **R_BK0 falsifier:** `fix2x2.py` + the two `retro.zig` tests. **Named limit:** Bellman residual 0 proves it is *a* fixpoint; least-ness rests on `GLOBAL.FP1` (mathematics) plus seeding, and the 2×2 *instance* row `2x2.B1` is CLAIMED with its primary evidence **deleted** [X] |
| Q6 | theorem **PROVEN** · instance **PARTIAL** · bracket meaning **PROVEN** | R_BK0 | `GLOBAL.FP1` PROVEN-as-mathematics [M] `docs/evidence/GLOBAL-FP1/proof-2026-07-30.md`; `GLOBAL.FP3` PROVEN [M] `docs/evidence/GLOBAL-FP3/probe_fp3_finite_lattice_2026_08_22.zig`; `GLOBAL.AXIOM-LH` / `AXIOM-BRACKET` **CLAIMED — axioms, not theorems**; `2x2.B1` CLAIMED, evidence lost [X] | **Theorem falsifier:** a monotone map on a finite lattice with no finite convergence. **Bracket falsifier:** `GLOBAL.ADR0020-LH-CORRECT` PROVEN establishes that the 716 L ≠ H gaps at 2×2 (44% of Cartesian non-terminals, 62% of genuinely reachable) are the **correct** output of the loopy-game fixpoint, not a defect. **Gap:** no committed least-ness witness at 2×2 — and `GLOBAL.B1-AUDIT` PROVEN says explicitly that the re-converge-from-+N check *is not* one |
| Q7 | R_PSK: **UNTRUSTWORTHY** · R_BK0: **N/A** | both | R_PSK: `GLOBAL.F1` FALSE-AS-SCOPED (the `ko_ref ≥ d` cross-branch memo guard, ADR-0013); `AGENTS.md` foreclosure names the 2×2 column unverified. R_BK0: no finisher in the ADR-0020 construction — the bracket **is** the fixpoint output | **Gap:** no committed #2-auditor run at 2×2 under either rule set. **Contradiction, unresolved:** §6-**D10** cites `PROGRESS.md:238-240,244-245` "Track A 2×2/3×2 regen complete (B15, byte-identical)" against `SOLUTION-TREE.md:63` "Track A never ran at 2×2" — §5 C-1 |
| Q8 | C2: **UNKNOWN** (R_BK0), vacuous (R_PSK) · C3: **OPTIMAL-NOT-PROVEN** | both | `2x2.T12` **FALSE-AS-SCOPED** (T731, 2026-08-23): "2×2 admits no reachable non-root cycles" is **false** under basic ko — a **144-vertex** non-trivial SCC (160 under the corrected rule), root-free, `docs/evidence/QA-023/ko-fix-2026-07-29/scc2x2.py` [M]. `2x2.C3` MEASUREMENT — range-aware player leak-free 0/4000 games [P] | **Gap (C2):** the vacuity at 2×2 is a **ban effect**, not the absence of cyclic structure; under R_BK0 no C2 probe has been run. **Gap (C3):** 0/4000 is a screen. `critique-2026-07-28.md` §3 records bracket containment as one of three validations a **wrong answer passes 40–70% of the time**; the row's wrong-answer-pass-rate is `?`. **Stale doc:** `boards/2x2/EPISTEMIC.md` still asserts the falsified statement as the reason C2/C3 are "N/A" — §5 C-4 |
| Q9 | theorem **PROVEN** · censuses **OPTIMAL-NOT-PROVEN** | rule-independent (position predicates) | `GLOBAL.S2` PROVEN [M]. `GLOBAL.TWO-LIFE-ONSET` MEASUREMENT — coexisting unconditional life **0 / 57** at 2×2. `GLOBAL.ROOT-SINGLE-IFF-FORCIBLE-LIFE` MEASUREMENT — root [−4,+4] not single, **neither** player can force a Benson-alive chain; the iff holds **5/5** sizes. `GLOBAL.DRAWLOOP-CONFINED` — 0 exceptions / 92. `GLOBAL.NEITHER-FORCE-MOSTLY-DECISIVE` — 12.9% of that class decisive (124) | **Theorem falsifier:** exhibit a finite goban where a Benson-certified chain is capturable. **Gap (censuses):** single-instrument (`src/t393_*`, `src/t394_force_life.zig`) with internal V1 controls but **no independent re-implementation** at 2×2. `boards/2x2/EPISTEMIC.md` grades Benson-alive PROVEN on the argument "trivial — all positions ≤ 4 stones"; that is an argument, not a probe |
| Q10 | SCC **PROVEN** · state-space denominators **PARTIAL** | R_BK0 | SCC: 144/160-vertex non-trivial SCC witnessed, Zig and Python agreeing, `scc2x2.py` [M]. Denominators in committed docs: **258** reachable states (`2x2.BASICKO-TIE`), **172** closure vertices (`force-life-classifier-2026-08-06.md` §4), **255** I5 nodes (`3x2.I5-CAL`), **1,620** non-terminals + 716 gaps (`GLOBAL.ADR0020-LH-CORRECT`) | **SCC falsifier:** re-run `scc2x2.py`; a trivial-SCC-only result falsifies. **Gap:** four 2×2 state-space counts across four committed documents, differing by state definition (terminals in/out, pass states in/out, true-root vs 42-seed convention). Only *some* pairs carry a reconciliation — `3x2.BASICKO-TIE` documents the +36 phantom-seed reconciliation at 3×2; the 2×2 set has none. §5 C-10 |
| Q11 | R_PSK: **PARTIAL** · R_BK0: **UNKNOWN** | both | R_PSK: `CODE.ADR0011-FMT` PROVEN, `CODE.ADR0011-GATE` PROVEN (both **Tier B** [P]); battery was **stubbed before T258** (`CODE.VB-STUBS` PROVEN); I7 **known-fail** — `CODE.WZO1-DTT-UNSET` PROVEN, the DTT column is the `@memset` initialiser [P]; I9 anchor 0 (basic ko) / +1 (PSK) | **Gap (R_PSK):** format and gate are PROVEN on argument and inspection, not on a re-runnable probe; the DTT column is *known* uncomputed. **Gap (R_BK0):** **no artifact is persisted at 2×2** (`SOLUTION-TREE.md:65`) — the current-rule deliverable is unshippable at 2×2 without a rebuild, and there is nothing on disk to verify |

### 1.2 — 3×2 (6 points; 489 legal positions/side, 978 slots)

| # | status | rule set | evidence | falsifier / gap |
|---|---|---|---|---|
| Q1 | **PROVEN** | rule-independent | `GLOBAL.S1` PROVEN [P]; `src/colex.zig:256` **includes `verify(3,2)`** — the "rectangle" rung [M], run 2026-08-24; `probe_legal_count_2026_08_20.py` reproduces all six sizes [M] | **Falsifier:** `zig test src/colex.zig`; a legal count ≠ 489 from the probe falsifies. 3×2 is the **only** rectangle with a committed exhaustive bijection rung |
| Q2 | **PROVEN** | R_BK0 (ko) | `src/rules.zig:1263` exhaustive 3×2 ko agreement with the independent solver [M]; `src/rules.zig:1511` `Z-R-MOVE-B1-EQUIV` old-window predicate at 3×2 [M]; `src/rules.zig:1357` seeded-defect control [M] | **Falsifier:** `zig test src/rules.zig`. Exhaustive at this size with a control that fires |
| Q3 | **PARTIAL** | rule-independent | theorem `GLOBAL.S2` PROVEN [M]; `GLOBAL.S4` PROVEN [M]; `boards/3x2/EPISTEMIC.md` grades Benson-alive PROVEN on "exhaustive falsification" [P] | **Gap:** no `3x2.S2-impl` row and no committed 3×2 rung of `benson_theorem_check`; the board file's "exhaustive falsification" has no committed probe or denominator |
| Q4 | R_PSK: **UNKNOWN (contradicted)** · R_BK0: **OPTIMAL-NOT-PROVEN** | both | R_PSK: **three values for one slot** — +1 (`0011:50-51`, `retrograde-3x3.md:220`), **−2** (`consistency-audit.md:32-34`, `0013:20-21`), 0 (published 2×3). §6-**D8**, unresolved. R_BK0: 0 (TIE), [−6,+6], 2,586 reachable states, 10 sweeps — `3x2.BASICKO-TIE` MEASUREMENT [M] | **R_PSK: no status is available** — the register records the conflict and does not resolve it; §5 C-6. **R_BK0 gap:** MEASUREMENT with committed stdout, and its brute-force cross-check was **withdrawn** (T102 buffer aliasing, `GLOBAL.BRUTE-ALIASING`); no independent re-implementation exists at 3×2 as one does at 2×2 |
| Q5 | L == H half: **PARTIAL** · ko-sensitive half: **UNTRUSTWORTHY** | R_PSK | `3x2.C1` PROVEN, **Tier A** — `docs/evidence/T13/probe-reimplementation-2026-07-30.md`, **0/540** L == H fresh-start mismatches [M]; `3x2.EXACT` MEASUREMENT — history-exact ground truth on **68 of 600** roots | **Sub-domain proven:** all **540** L == H slots, with a committed re-implementation. **Gap:** the 189 + 189 ko-sensitive slots are **silent** in that check (§6-D9's "partial mitigation" note), and `3x2.F1` PROVEN measures **45 of 378** ko-sensitive slots violating the minimax identity *as committed*. So 3×2 is the cleanest size for the single-score region and the **worst** for the bracketed one |
| Q6 | theorem **PROVEN** · instance **OPTIMAL-NOT-PROVEN** | R_BK0 | `GLOBAL.FP1`/`FP3` PROVEN [M]; `3x2.B1` CLAIMED — same T02 evidence deletion as 2×2 [X]; 10 sweeps measured | **Gap:** the instance rests on a prose summary whose primary evidence was deleted. No least-ness witness at 3×2 either |
| Q7 | **UNTRUSTWORTHY — and here it is measured, not merely suspected** | R_PSK | `3x2.F1` **PROVEN**: the writes-ON finisher violates the minimax identity at **45 of 378** ko-sensitive slots; writes-off gives **0** (`3x2.F3` PROVEN, necessary condition). `consistency-audit.md:25-34`; `0013:15-19` [P] | **This is the project's calibrated red-then-green rung.** 3×2 is the smallest goban where the finisher's unsoundness produces *measurable wrongness*, so any Track A campaign must run 3×2 **first** as its control. **Gap:** the committed artifact has never been regenerated writes-off — every ko-sensitive reading of `artifacts/oracle-3x2.wzo` is wrong as committed |
| Q8 | C2: **FALSE-AS-SCOPED — and this is a proof** · C3: **OPTIMAL-NOT-PROVEN** | R_PSK | `3x2.T13` **PROVEN (falsification), Tier A**: **154 of 508** reachable L == H slots (30.3%, over 132 distinct positions) have a reachable PSK history whose exact value differs; **4,432** falsifying pairs. `docs/evidence/T13/probe-reimplementation-2026-07-30.md` §4, §8; `t13_probe.py`, `zig_t13_replay.zig` [M]. `3x2.C3` MEASUREMENT 0/4000 [P] | **Falsifier of the falsification:** re-run `t13_probe.py` / `zig_t13_replay.zig`; zero mismatches would rehabilitate C2. **This is the strongest single result in the project** — an exhaustive, independently re-implemented, committed refutation. The whole "fresh-start only" reframe (`GLOBAL.REFRAME`) hangs on it via an `n:` edge, and `claimlint` C1b alarms if it is ever withdrawn. **Gap (C3):** 0/4000 is a screen, per Q8 at 2×2 |
| Q9 | theorem **PROVEN** · censuses **OPTIMAL-NOT-PROVEN** | rule-independent | `GLOBAL.TWO-LIFE-ONSET` — **0 / 489**; `GLOBAL.ROOT-SINGLE-IFF-FORCIBLE-LIFE` — [−6,+6] not single, neither can force; `GLOBAL.DRAWLOOP-CONFINED` — 0 exceptions / 298; `GLOBAL.NEITHER-FORCE-MOSTLY-DECISIVE` — 39.8% decisive (608) | **Gap:** single-instrument, as at 2×2 |
| Q10 | **PARTIAL** | R_BK0 | `3x2.I5-CAL` **MEASUREMENT with the not-reproduced verdicts stated**: T171's Tarjan reproduces the committed I5 calibration references **only PARTIALLY** — node counts exact (2×2 V = 255, 3×2 V = …), edge and max-SCC figures **not** reproduced; later adjudicated a `vb_graph` defect pair, not a reference problem (`CODE.I5-INSTRUMENT-ADJUDICATION`). `src/i5_differential.zig` carries a **permanent 3×2 rung with four seeded-defect controls that demonstrably fire** [M] | **Falsifier:** the 3×2 I5 differential with its firing controls — the best-instrumented cell at this size. **Gap:** 3×2 is **vacuous in the full-graph model** (G3b §3.1) — the spec's premise that 3×2 is the first non-vacuous rung is false; the first genuine red-then-green rung is 4×4. A spec-premise finding awaiting disposition |
| Q11 | R_PSK: **PARTIAL** · R_BK0: **UNKNOWN** | both | `CODE.ADR0011-FMT`/`GATE` PROVEN [P]; battery stubbed pre-T258; I4 runs at 3×2; I7 known-fail (DTT unset) | **Gap:** as 2×2 — and **no R_BK0 artifact is persisted at 3×2** |

### 1.3 — 3×3 (9 points; 12,675 legal positions/side; 49,428 WZO2 entries)

| # | status | rule set | evidence | falsifier / gap |
|---|---|---|---|---|
| Q1 | **PROVEN** | rule-independent | `GLOBAL.S1` PROVEN [P]; `src/colex.zig:256` exhaustive bijection at 3×3 [M]; legal count 12,675 = OEIS A094777, cross-validated; `probe_legal_count_2026_08_20.py` [M] | **Falsifier:** `zig test src/colex.zig`; a count ≠ 12,675 from the probe, or a mismatch against A094777, falsifies. External attestation exists here (square goban) — the strongest Q1 cell of the five |
| Q2 | **PARTIAL** | R_BK0 | I11 move-set consistency **0 / 25,350** at 3×3 (G3b) [P]; T380 F-2 ban-set invariants **0/784 exhaustive** [P]; `src/rules.zig:1646` corrected `Z-R-MOVE-B1-EQUIV` predicate **exhaustive 3×3, 0 violations** [M]; `src/rules.zig:1656` **old wording falsified 152/784** — a negative control [M]; `src/rules.zig:1666` seeded mutant [M]; `src/rules.zig:1308` ko agreement — **3×3 sample, not exhaustive** [M] | **Sub-domain proven:** the recapture-identity lemma, exhaustive over 784 with a 152/784 negative control (T573). **Gap:** the ko-agreement rung at 3×3 is a **sample**; 2×2 and 3×2 have exhaustive rungs, 3×3 does not. Cheap to close |
| Q3 | **PARTIAL** (register says PROVEN) | rule-independent | `3x3.S2-impl` **PROVEN** — "exhaustively falsification-confirmed at 3×3", **Tier B** [P]. Committed rung: `src/rules.zig:655` `benson_theorem_check(3,3,**5**)` — ≤ 5 stones [M]. The full-goban check (≤ 9) exists as `src/rules.zig` `main()`, reachable only via `zig run` — **not in `zig build test`** | **Downgrade, §3-D3.** **Sub-domain proven:** all 3×3 positions with ≤ 5 stones, with an `expect(tested > 0)` anti-vacuity guard. **Gap:** the word "exhaustive" in the register row is not what the suite runs. **The remedy already exists in the repo** — wire `main()`'s ≤ 9 rung into the suite |
| Q4 | **PROVEN** | R_BK0 | `3x3.BASICKO-TIE` MEASUREMENT: root **+9** (L == H == 9), 73,758 reachable states, 0 UNDEF, 16 sweeps, colour-symmetric; `docs/evidence/QA-026/3x3/PROVENANCE.md` + stdout [M]; **matches the MIGOS II anchor** under aligned rules (`GLOBAL.MIGOS-RULE` PROVEN) | **Falsifier:** re-run the EXP-5 solve; a root ≠ +9, or a break in colour symmetry, falsifies. **Independent external agreement:** van der Werf & Winands's own basic-ko 3×3 result. This is the **only** root value in the project with third-party attestation under the *same* rule set — and `GLOBAL.MIGOS-RULE` PROVEN is the row that made the comparison legitimate (MIGOS plays basic ko, **not** superko). **Caveat:** `docs/epistemic/GLOSSARY.md:424` mislabels this same +9 as "(PSK, matches van der Werf & Winands)" — §4 U2 |
| Q5 | **UNKNOWN** | R_BK0 | **The register has no live row.** `3x3.C1` was **ARCHIVED as BOGUS / falsified-foundation** on 2026-08-05 (`archives/register/INDEX.md:17`): its foundation (finisher soundness via `GLOBAL.F2` → `GLOBAL.C3`) is falsified at the very goban. **Nothing live replaced it** | **This is the census's most consequential UNKNOWN.** Three committed documents still describe the claim as live-and-CLAIMED — `SOLUTION-TREE.md:113`, `boards/3x3/EPISTEMIC.md`, and `CLAIMS.md:358` (`GLOBAL.F1`'s dependents column cites `3x3.C1`, an ID with no row). `claimlint` **C4 GHOST-IDS does not flag it** (49 ghosts listed, this is not among them) because the archive index resolves it — so the linter is correct and the *prose* is stale. **Gap:** mint a live R_BK0 value-correctness row at 3×3, or record explicitly that none is claimed |
| Q6 | theorem **PROVEN** · instance **OPTIMAL-NOT-PROVEN** | R_BK0 | `GLOBAL.FP1`/`FP3` PROVEN [M]; `3x3.B1` CLAIMED, evidence lost [X]; 16 sweeps measured; **I4 differential** — `src/i4_differential.zig`, R8 vs kernel, **both exhaustive, 0 / 49,428**, non-vacuous n_set = 5,408 (T395) [M]; `WZO2.I2-CLEAN` MEASUREMENT 0 / 49,428 independent re-implementation [M] | **Strongest instrument at any size:** the I4 differential is two independent engines, both exhaustive, with a stated non-vacuity figure. **What it proves:** the table **is** a fixpoint. **What it does not:** least/greatest-ness. **Gap:** `3x3.B1`'s primary evidence is deleted; no least-ness witness |
| Q7 | R_BK0: **N/A** · R_PSK: **UNTRUSTWORTHY** | both | R_BK0: T380 F-8 — `oracle_v2_build` reads the exp6 fixpoint directly, **no finisher ran** [P]. R_PSK: `3x3.F2` **MEASUREMENT** — the bracket-guided finisher *completed* all 622 ko-sensitive orbit reps and the anchors PIN and MATCH — **completion is not soundness** (`CLAIMS.md` §1 says so explicitly) | **The register's own best sentence.** `3x3.F2` was the row that taught the project to distinguish a measurement from a proof, and §1 uses it as the worked example of why a `d:` edge must never point at a MEASUREMENT row. **Gap (R_PSK):** the ko-sensitive column of `artifacts/oracle-3x3.wzo` is unverified; `3x3.F4` PROVEN records `deps` mode as 0 auditor violations and byte-identical to writes-off, but **the committed artifact was not rebuilt with it** |
| Q8 | C2: **UNKNOWN** · C3: **FALSE-AS-SCOPED** | R_PSK | `3x3.C2` **UNTESTED** — falsified at 3×2 but per-goban independence forbids inheritance (ADR-0016). `3x3.C3` **PROVEN (falsification), Tier B**: range-aware self-play leaked, promise **+3 → final −9**, a 12-point leak; `3x3.E2-RUN1` 25/4,000 and `3x3.E2-RUN2` 50/8,000 (0.625% both, max 12 pts — an **independent replication**, ruling D-1). `3x3.E3` PROVEN — the leaking game is a valid PSK game, 0 illegal moves in 17 plies. `GLOBAL.E2-SANITY` PROVEN — with trivial bounds the same policy is leak-free everywhere, so the harness is wired right | **C3's falsifier is the only one of its class that is *complete*:** a null control (`E2-SANITY` — trivial bounds, no leak), a validity control (`3x3.E3` — the leaking game is legal), and a replication (RUN2). That is the project's own "null control + seeded-defect control" doctrine satisfied in full — and it is why C3's falsification survives at PROVEN despite being Tier B. **Debt:** RUN2's 8,000-game output was **never committed**; its numbers survive only in `PROGRESS.md:128` (D-1's own open item). **Gap (C2):** no 3×3 C2 probe has been run under either rule set |
| Q9 | theorem **PROVEN** · `LIFE-CERTIFIES` **PROVEN-as-scoped** · censuses **OPTIMAL-NOT-PROVEN** | R_BK0 | `GLOBAL.LIFE-CERTIFIES` — no entry containing a Benson-alive chain for either colour falls in **any** bracketed class: 0 over all **49,428** entries; 0 of the 624 positions holding a straddling entry; converse slice 0 of 1,248 pin_0 draw-by-loop entries. `GLOBAL.TWO-LIFE-ONSET` — **0 / 12,675**, *independently confirmed* by a second seat. `3x3.LIFE-NO-CENTRE` — 206 of 1,766 Benson-alive 3×3 positions have the alive colour with **no stone at the centre**: the operator's shape claim is **refuted**. `GLOBAL.ROOT-SINGLE-IFF-FORCIBLE-LIFE` — 3×3 is the **only** size of the five where the root is single (+9) **and** a player (Black) can force life | **Falsifier:** exhaustive over the whole 3×3 WZO2 table with stated denominators, so any counterexample entry falsifies. `TWO-LIFE-ONSET`'s 3×3 row is the one census cell with a **second seat's independent confirmation**. **The operator's loss, recorded:** `3x3.LIFE-NO-CENTRE` refutes the centre-stone shape claim, and it cuts toward unconditional life being a *rule-independence* property, not a territory property |
| Q10 | **PROVEN** for the census; **PROVEN** for the cycle structure | R_BK0 | `3x3.H1-CENSUS` **PROVEN, Tier A** — exact: **22,736** reachable (position, side, ko_point) triples, 13,997 distinct; `docs/evidence/GLOBAL.H1-CENSUS/3x3-standard.txt` [M]. `3x3.OPTIMAL-CYCLE` MEASUREMENT — the optimal-move subgraph **contains cycles**, exhaustive over 47,456 states / 76,244 edges [M]. `3x3.LOOPY-TAXONOMY` MEASUREMENT — full loopy-child partition, **exhaustive over 47,456 non-terminal parents** [M]. `3x3.BRACKET-NOT-KO` MEASUREMENT — brackets are **not** ko-derived at 3×3, exhaustive over the whole graph, 827 SCCs with one non-trivial of size 48,602 [M] | **Falsifier:** all four are exhaustive with committed artifacts and stated denominators; a differing count falsifies. **3×3 is the size where the cycle structure is genuinely known.** Every 4×4 counterpart of these four is a declared sample (§1.5 Q10) — 3×3 is their control. **Denominator note:** 12,675 legal positions, 49,428 WZO2 entries, 73,758 basic-ko reachable states and 22,736 H1 triples are four different state definitions; unlike the 2×2 set, these are individually documented |
| Q11 | R_BK0: **PARTIAL** · R_PSK: **PARTIAL** | both | R_BK0: `CODE.WZO2-PASSBIT` PROVEN, **Tier A** — the 3×3 artifact was the **passing control** that confined the 4×4 passes-bit defect to 4×4 [M]; `WZO2.I2-CLEAN` MEASUREMENT 0 / 49,428 [M]; A7 gate chain reproduces +9 before any 4×4 build. **Caveats carried:** the M4a-era A5 stride-97 sample was **never verified coprime** to group sizes (`SPRINT-M4a-ACCEPT`), and A6 fixture (c) was a **broken positive control** — it called the check on the *uncorrupted* slice (`CODE.M4A-HARNESS` PROVEN) | **3×3 earns its keep as the control size**, and it is the one artifact whose format integrity has a demonstrated defect-catching record. **Gap:** two of its acceptance rungs are recorded defective (A5 sample never validated, A6 positive control broken) and **no row records A6 fixture (c) being fixed** — `SOLUTION-TREE.md:270` lists it as UNDETERMINED |

### 1.4 — 4×3 (12 points; 321,689 legal positions/side, 643,378 slots)

| # | status | rule set | evidence | falsifier / gap |
|---|---|---|---|---|
| Q1 | **OPTIMAL-NOT-PROVEN** (register says PROVEN) | rule-independent | `4x3.S1` **PROVEN** — but the row's own evidence is a **structural-inheritance argument**: "the mixed-radix layout is size-generic and has been exhaustively round-tripped through 4×4; 4×3 raw space is smaller and inherits the same structural proof" [P]. `src/colex.zig:256` verifies **2×2, 3×3, 3×2 — not 4×3** [M]. `4x3.S3a` **PROVEN with a caveat, Tier A**: `legal_count = 321,689` is the project's **own** ground truth — OEIS A094777 is defined for **square** gobans only, and the "= OEIS" framing is **withdrawn**; independently reproduced internally by `4x3.H1-CENSUS` | **Downgrade, §3-D1.** **Gap:** no committed re-runnable bijection check at 4×3 (3¹² = 531,441 raw slots — smaller than the 3×3 rung is *not* true; 3⁹ = 19,683, so 4×3 is ~27× the 3×3 work and trivially affordable). **Second gap:** the legal count has **no external attestation** at any non-square size |
| Q2 | **PROVEN** | R_BK0 | I11 **0 / 643,378** at 4×3 (G3b/T363) [P]; key agreement **0 / 643,378** (T363) [P]; T380 F-9 ko-cluster census over **all 321,689** legal positions, 0 mismatches, max 2 clusters [P] | **Falsifier:** three independent table-exhaustive checks with stated denominators; any nonzero count falsifies. 4×3 is the **largest size where the move generator is checked exhaustively** — at 4×4 the same rung is a 0.05% sample (§1.5 Q2). This asymmetry is the single sharpest argument for 4×3 as 4×4's control |
| Q3 | **UNKNOWN** | rule-independent | theorem PROVEN (`GLOBAL.S2`, `4x3.S2` PROVEN — but `4x3.S2` is **Tier B** and is the theorem restated at a size, not a measurement). `4x3.S2-impl` **UNTESTED** — the comptime `rules.zig` Benson code validated at 3×3 is **not** re-verified at 4×3; structural inheritance argued, not registered. `4x3.S4` **UNTESTED (`⬜ᴵᴺᴴ`)** — self-declared inheritance | **Gap:** terminal detection and scoring at 4×3 rest on **inheritance alone**. A size-dependent regression here would be invisible to every committed check — and the project has a recorded instance of exactly that class (the `i < 25` lurking-bound scenario written out in `src/rules.zig:1024-1027` as the *reason* the 4×4 regression test exists). The 4×4 test exists; the 4×3 one does not |
| Q4 | R_PSK: **OPTIMAL-NOT-PROVEN** · R_BK0: **OPTIMAL-NOT-PROVEN, and unregistered** | both | R_PSK: bracket **[−1,+12]**, `boards/4x3/EPISTEMIC.md:43` — and that value is `4x3.BRACKET`, **ARCHIVED** as old-artifact ("the k=1 bracket is a different measurement"). Published anchor **+4** for Black, in-bracket. R_BK0: bracket **[+4,+12]**, `docs/research/force-life-classifier-2026-08-06.md:118` (rules_id 3, reachable-from-empty closure, V = 1,293,848) | **There is no `4x3.BASICKO-TIE` row.** The register carries basic-ko root rows for 2×2, 3×2, 3×3 and 4×4 and **skips 4×3** — so the live 4×3 root value has no register home and is carried only by a research doc. **Gap:** single instrument, **explicitly not independently audited** (`GLOBAL.ROOT-SINGLE-IFF-FORCIBLE-LIFE` scope note; flagged for audit in three separate handover documents and never done). **Not a contradiction — a labelling failure:** [−1,+12] and [+4,+12] are two rule sets, and neither statement carries its rule set at the point of use (§5 C-9) |
| Q5 | **UNKNOWN** | R_BK0 | **The register has no live row.** `4x3.C1` was **ARCHIVED as BOGUS / falsified-foundation** on 2026-08-05 (`archives/register/INDEX.md:21`): the same buggy finisher path (`GLOBAL.F1`); "the 4×3 k=1 table's correctness waits on the #2 auditor on the k=1 build" | Same shape as 3×3 Q5: `SOLUTION-TREE.md:131` and `boards/4x3/EPISTEMIC.md` both still carry a CLAIMED C1 at 4×3, and `CLAIMS.md:358` cites `4x3.C1` as a dependent of `GLOBAL.F1`. **Gap:** mint a live R_BK0 row or record that none is claimed |
| Q6 | theorem **PROVEN** · instance **UNKNOWN** | R_BK0 | `4x3.FP3` **PROVEN, Tier B** — but the row is Knaster–Tarski restated at a size; the 17 sweeps measured is `4x3.M2` MEASUREMENT, "**not** the theorem" (the row says so). `4x3.FP1` **CLAIMED** — "a post-hoc 4×3 V0/V1 check is **not separately recorded**" | **Theorem falsifier:** mathematical. **Gap:** there is **no** `4x3.B1` row at all, and no post-hoc fixpoint check on the committed 4×3 artifact. `boards/4x3/EPISTEMIC.md` lists exactly this as an open item and calls it **cheap — no new build**. It has not been done |
| Q7 | **UNTRUSTWORTHY** | R_PSK | `4x3.F1` **CLAIMED** — the committed artifact was produced by the same unsound writes-ON path (`3x2.F1` PROVEN is the evidence); **no Track A regen at 4×3**. `4x3.F4` **PROVEN, Tier B** — `deps` mode gives 0 auditor violations and is byte-identical to writes-off at 4×3 — **but the committed artifact was not rebuilt with it**. I4 at 4×3: **0 / 463,024 examined, 170,276 KO_SENSITIVE slots excluded** | **The clearest instance of the project's characteristic failure shape: every check passes *around* the column it cannot certify.** 170,276 of 643,378 slots (26.47%) are excluded from I4 by the WZO1 format boundary. **Gap:** a Track A regen, or a WZO2 build at 4×3 — 4×3 is the smallest size with **no** WZO2 artifact, and `SOLUTION-TREE.md:117` records why (the WZO2 bracket check cannot read WZO1) |
| Q8 | C2: **UNKNOWN** · C3: **UNKNOWN** | R_PSK | `4x3.C2` **UNTESTED** and `4x3.C3` **UNTESTED** — both rows say **explicitly** that they are *not* inherited from the 3×2 and 3×3 falsifications, per ADR-0016 per-goban independence | **Correctly UNKNOWN, and the register deserves credit for it.** `boards/4x3/EPISTEMIC.md` states the rule twice and in the imperative ("Do not inherit the 3×2 falsification as a 4×3 result"). 4×3 is the size where per-goban independence is **applied**; 4×4 is the size where the same inference is **taken** (§5 C-2, C-3). Two goban files apply opposite rules to the same inheritance and the register records it unresolved |
| Q9 | theorem **PROVEN** · censuses **OPTIMAL-NOT-PROVEN** | rule-independent | `GLOBAL.TWO-LIFE-ONSET` — **coexisting unconditional life begins at 4×3**: **2 / 321,689** (a colour-inverse pair), against 0 at every smaller size. `GLOBAL.ROOT-SINGLE-IFF-FORCIBLE-LIFE` — root [4,12] not single, **neither** can force. `GLOBAL.DRAWLOOP-CONFINED` — **32 exceptions** at 4×3 (99.88% hold) — the first size where confinement is not exact. `GLOBAL.NEITHER-FORCE-MOSTLY-DECISIVE` — 70.7% decisive (315,762) | **The onset result is the sharpest life/death finding in the census: two-colour unconditional life is a 12-point phenomenon.** **The operator's loss, recorded:** at 4×3 the root is decisive for Black (L = +4) although **neither** player can force a Benson-alive chain — territory-denial does not explain the win, and the timestamped prediction to the contrary was recorded **before** the measurement and falsified by it. **Gap:** 4×3 rows come from the **WZO1** artifact (no WZO2 exists), labelled as such; single instrument |
| Q10 | **PROVEN** for the ko census; **PARTIAL** for cycle structure | R_BK0 | `4x3.H1-CENSUS` **PROVEN, Tier A** — exact: **638,266** reachable triples, **375,281** distinct; `docs/evidence/GLOBAL.H1-CENSUS/4x3-standard.txt` [M]. `GLOBAL.I5-SCC-CONTAIN` — ko_not_cr = **0 / 170,181** at 4×3; the T344 "24 natural violations" were **fabricated by an instrument defect** (descending vs ascending component order) and the true reading is 0 (`CODE.I5-INSTRUMENT-ADJUDICATION`) | **Falsifier (census):** re-run the census enumerator; a differing triple count falsifies. **The 24-violation retraction is the census's best cautionary datum:** a battery *failure* was fabricated by the instrument, found only by a **third route** (exact reverse-BFS). **Gap:** the 4×3 I5 cross-instrument differential is **env-gated for RSS** (`WEIZIGO_I5_DIFF_4X3=1`) — it is not in the default suite. No optimal-cycle or loopy-taxonomy measurement exists at 4×3 (3×3 and 4×4 have both) |
| Q11 | **PARTIAL** | R_PSK | `CODE.ADR0011-FMT`/`GATE` PROVEN [P]; I4 passes around the excluded column (Q7); I5 0 / 170,181; I7 **known-fail** (DTT unset) | **Gap:** every 4×3 battery reading passes around the ko-sensitive column. **No R_BK0 artifact exists at 4×3**, so the current-rule table cannot be verified on disk at all — `SOLUTION-TREE.md:249` lists persisting the WZO2 gate-chain tables at 2×2/3×2/4×3 as outstanding |

### 1.5 — 4×4 (16 points; 24,318,165 legal positions/side; 99,133,036 WZO2 entries)

**The G3b discharge set `CLAIMED` as the ceiling in its own words — "nothing here is PROVEN"
(`docs/epics/E1-markovian/sprints/g3b-value-correctness/pass0/accept.md`, signed ruling
2026-08-05).** This section does not contradict that; it locates it question by question.

| # | status | rule set | evidence | falsifier / gap |
|---|---|---|---|---|
| Q1 | bijection **OPTIMAL-NOT-PROVEN** (register says PROVEN) · legal count **PROVEN** | rule-independent | `4x4.S1` **PROVEN** — "colex bijection verified by exhaustive round-trip through 4×4", **Tier B** [P]; `src/colex.zig:256` does **not** include 4×4 [M]. `4x4.S3a` **PROVEN, Tier A** — **24,318,165** legal positions/side = **OEIS A094777**, cross-validated; `docs/evidence/GLOBAL-S3a/probe_legal_count_2026_08_20.py` reproduces it [M] | **Downgrade, §3-D2.** **Gap:** the 4×4 round-trip was run once and is not in the suite; 3¹⁶ = 43,046,721 raw slots, ~2,200× the committed 3×3 rung, so it belongs as a ReleaseFast or opt-in rung rather than a debug-suite default. **Falsifier (count):** re-run the probe; a count ≠ 24,318,165 or a break from A094777 falsifies — this cell has **external attestation**, the strongest thing at 4×4 |
| Q2 | **PARTIAL — and this is the largest single scope limit at 4×4** | R_BK0 | I11 at 4×4 is a **50,000-state sample of 99,133,036 — 0.05%**, the one non-exhaustive G3b condition (`4x4.C1` scope limit 1) [P]. Table-exhaustive elsewhere: T345 key agreement **0 / 99,133,036**; C-A1 closure **0 / 600,763,414** children; T380 F-2 successor agreement 0 / 266,779 random states, ban-set invariants over 3,222,855 states | **Gap, stated in the register's own words:** "a move-generator defect in the unsampled 99.95% would pass every committed check — the T178/T193/T265 family (three producer/consumer key defects) shows the class is real" (`SOLUTION-TREE.md:147`). **And the class has no battery cell at all** (`GLOBAL.BATTERY-GAPS` G1/G3): the T345 and T267 differentials exist **outside** the battery, so the project's most expensive bug class cannot be caught by a battery run |
| Q3 | terminal detection **PARTIAL** (register says UNTESTED) · scoring **UNKNOWN** | rule-independent | `4x4.S2-impl` **UNTESTED** in the register — but two committed rungs exist: `src/rules.zig:1019` `benson_alive_regression_check(4,4,**5**)` and `:1034` at **≤ 8 stones**, each comparing `rules.benson_alive` against an **independently structured** reference (reverse iteration order, different neighbour representation, separate boundary logic) with `pa_mismatches == 0` **and** `immediate_capture_violations == 0` [M]. `4x4.S4` **UNTESTED (`⬜ᴵᴺᴴ`)** — self-declared inheritance | **The register *understates* this cell — the only such case in the census.** Sub-domain proven: 4×4 Benson at ≤ 8 of 16 stones (11,876,097 candidate positions before the legality filter, 60 s debug budget). **Gap:** 9–16 stones, exactly where a 16-cell-specific bound error would bite; and the test's own header names that scenario as its reason for existing. **Gap (scoring):** `GLOBAL.S4`'s independent Python scorer ran on 120 random gobans and has **never been pointed at 4×4** |
| Q4 | **OPTIMAL-NOT-PROVEN** | R_BK0 | `4x4.BASICKO-TIE` MEASUREMENT: root **+1**, bracket **[+1,+16]**, 147M states, 31 sweeps; T104 verified **H = +16 genuine** — 0 violations / 99,133,036, 0 map misses, exhaustive inversion clean [M]. `GLOBAL.FIXPOINT-VS-SEARCH` CLAIMED: under aligned rules our fixpoint (+1) and MIGOS's search (+1, thesis Table 5.1) **agree** | **Gap:** the agreement rests on **one seat's primary-source reading** (T274) absorbed by T279, and "our own +1 still awaits the #2 auditor" — the row says so. **The +2 anchor is a different game**, not a discrepancy: `GLOBAL.TIE-MIGOS` **FALSE-AS-SCOPED** — MIGOS's long-cycle-tie value *is* 0, identical to ours, and the +2 comes from the pass-difference cycle-resolution rule (thesis Appendix A §A.4). **The +2 acceptance criterion in `roadmap-2026-07-28.md:227-232` is not met by R_BK0 and cannot be.** See §4 U2 — this is still asserted as current elsewhere |
| Q5 | **OPTIMAL-NOT-PROVEN, with four registered scope limits** | R_BK0 | `4x4.C1` **CLAIMED by the G3b discharge**: value-correctness verified by closure + Bellman on the WZO2 table; `.../g3b-value-correctness/pass0/accept.md` (signed ruling, six conditions with declared scope limits) [P] | **Gap, enumerated:** (1) I11's **0.05%** sample; (2) the **KO_SENSITIVE column distrusted** pending Track A; (3) mutation adequacy missing for the exhaustive acceptance sweeps; (4) the WZO1/WZO2 format boundary at 4×3. **No exhaustive exact-solver ground truth is possible at 4×4** — the exact solver is intractable from empty, so `4x4.C1` has no cheap experiment; §4.2 folds it into the C2-probe harness. **This is the honest ceiling on "perfectly solved":** the deliverable's central claim is CLAIMED and its accept document says so in those words |
| Q6 | fixpoint property **PROVEN-as-measured** · least/greatest **OPTIMAL-NOT-PROVEN** · seed/termination **UNKNOWN** | R_BK0 | `4x4.FP1` **CLAIMED** — I4 Bellman residual **0 / 95,677,624** KO_SENSITIVE-clear entries [P]; A2 exhaustive **0 / 99,133,036** (`4x4.WZO2-A2-EXHAUSTIVE`, held at CLAIMED per DIRECTION Amendment 2 edge 5) [M]. `4x4.FP1-C3` **PROVEN (as scoped), Tier B** — V0/V1 identities hold at every non-settled slot, on a **1:37 sample** [P]. `4x4.FP1-C1` and `4x4.FP1-C2` **UNTESTED** — seed-from-±N and final zero-change sweeps. 31 sweeps, `converged: true`, per-sweep deltas digit-identical across rebuilds | **Downgrade, §3-D4** (`4x4.FP1-C3` is PROVEN on a declared 1:37 sample — a sample is not a proof, and A2's exhaustive 0/99,133,036 supersedes it as evidence while itself being held at CLAIMED). **Gap:** `FP1-C1`/`FP1-C2` are **post-hoc reads of committed build logs — no new build** (§4.2 rank 3) and remain undone; they close the `Z-CONVERGE-SEED` gap that **no battery invariant covers**. Least/greatest-ness at 4×4 rests on `GLOBAL.FP1` mathematics plus a CLAIMED instance, and there is **no least-ness witness at any size** |
| Q7 | **UNTRUSTWORTHY (the KO_SENSITIVE column) · N/A (the WZO2 construction)** | both | R_BK0: T380 F-8 — **no finisher ran**; the table is a pure fixpoint. **But** the KO_SENSITIVE column — **3,455,412 entries, 3.49% of the table, including the root's own bracket** — is **distrusted pending Track A**: the checks pass *around* it (I4 on KO_SENSITIVE-set entries is 0 / 3,455,412, **held as measurement, not a pass**). `4x4.D3` (writes-off regen) **UNTESTED** — the single Track A gate; `4x4.F2`/`F3`/`F4` all UNTESTED. R_PSK checkpoints: **KNOWN-WRONG** (`GLOBAL.F1`; `4x4.F1` CLAIMED — same guard, structural bug) | **The single largest open item in the project.** Until Track A runs and the #2 auditor passes on a writes-off build, **no ko-sensitive value at 4×4 is quotable, and that includes the root bracket [+1,+16] — the most important datum in the table.** **Gap the census adds:** T571 found the two `untracked/` writes-off 4×4 checkpoints are (i) **byte-identical** to `data/oracle-4x4-parallel.checkpoint.wzo` (sha256 `28afa11b…`) and (ii) `rules_id = 1` (**PSK**) — so neither can cross-check the basic-ko table, and the 2026-07-27 "writes-OFF 1.67% vs writes-ON 4.08%" comparison was **one build under two names**, confounded. A Track A regen at 4×4 must be a **basic-ko** build; the PSK-era files do not discharge it |
| Q8 | C2: **status conflict, unresolved** · C3: **status conflict, unresolved** · C4: **FALSE-AS-SCOPED** | both | `4x4.C2` status cell reads **UNTESTED (status conflict, §6-D3)**; `4x4.C3` reads **UNTESTED (status conflict, §6-D2)**. Both conflicts are three-document disagreements the register records and refuses to resolve. `GLOBAL.C4` (fresh-start == real-game) **FALSE-AS-SCOPED**; `GLOBAL.LEAK` **PROVEN**; `GLOBAL.FP2-general` **INTRACTABLE (possibly unprovable by finite methods)** | **Both readings, neither picked — §5 C-2 and C-3.** Reading A: "4×4 falsification is analogy-expected, **not** an open hypothesis"; "No further C2-probe needed at 4×4" (`boards/4x4/EPISTEMIC.md:46,98,329-331`). Reading B: **untested**, per-goban independence prevents inheritance (`PROGRESS.md:212-213`), and `boards/4x3/EPISTEMIC.md:33` applies the opposite rule at the adjacent size. **What is settled either way:** the bracket's real-game reading is a **non-claim (NC2)**, and `4x4.A-2` is FALSE-AS-SCOPED as a category error |
| Q9 | theorem **PROVEN** · `LIFE-CERTIFIES` **PROVEN-as-scoped** · censuses **OPTIMAL-NOT-PROVEN** | R_BK0 | `GLOBAL.LIFE-CERTIFIES` — Z-and-either-alive = **0 over all 99,133,036 entries**, 0 over the fresh-start slice (48,505,262), 0 of the 507,484 positions holding a straddling entry; converse 0 of 895,216 pin_0 draw-by-loop entries. `GLOBAL.TWO-LIFE-ONSET` — **324 / 24,318,165** (0.0013%, one in ~75,000), cross-checked **identically 324** on the WZO1 checkpoint **and** the WZO2 table. `GLOBAL.ROOT-SINGLE-IFF-FORCIBLE-LIFE` — [1,16] not single, neither can force; the iff holds 5/5 | **Falsifier:** exhaustive over the table with denominators; one alive-and-bracketed entry falsifies. The 324 figure is the census's only **cross-artifact** agreement at 4×4 — the same count on two independently built tables under different rule families, which works because legality and Benson aliveness are rule-family-independent position predicates. **Scope carried in the row:** the L < H columns are the distrusted ko-sensitive region, but the finding's force is categorical. **Explicit non-claim, and it must not be dropped:** `GLOBAL.NEITHER-FORCE-MOSTLY-DECISIVE` — **85.3%** of the neither-can-force class at 4×4 is **decisive** (19,518,338 of 22,885,430), so "nobody can force life" is **not** a draw oracle; a search pruning on it would abandon 19.5 million decisively-valued states |
| Q10 | **PARTIAL — every 4×4 cycle measurement is a declared sample** | R_BK0 | `GLOBAL.I5-SCC-CONTAIN` — ko_not_cr **0 / 3,455,412**; maxSCC 47,429,504 = **47.9% of entries in one giant SCC**; cycle-reachable 97,689,592 = 98.5% [P]. `4x4.KO-CLUSTER-MAX-2` MEASUREMENT — max independent ko-cluster count is **TWO**, exhaustive over all 24,318,165 legal positions [M]. `4x4.BRACKET-NOT-KO` MEASUREMENT — brackets are **not** predominantly ko-derived; **92.6%** of bracket-valued positions carry no ko shape, exhaustive over the table [M]. **Samples:** `4x4.OPTIMAL-CYCLE` — contains cycles on a **150,001-node BFS sample of 99,133,036 ≈ 0.15%**; `4x4.LOOPY-TAXONOMY` — **200,000 of 98,616,794 ≈ 0.20%**, "every count is a sample statistic", depth-3 forced 4,867 is a **sample lower bound** and the exhaustive forced-cycle status at 4×4 is **OPEN** | **Falsifier (exhaustive cells):** re-run over the full table. **Gap:** the two cells that describe *optimal play's* relationship to cycles are 0.15% and 0.20% samples with 3×3 as their exhaustive control — the register labels this correctly and in the row text, which is the practice this census wants to see more of. `GLOBAL.PASS-NOKO` **PROVEN (code + independent re-derivation)** is what makes cycle-reachability on the `(board, side, ko)` projection sound: a pass edge **cannot** close a cycle |
| Q11 | **PARTIAL — the format's own history is the defect catalogue** | R_BK0 | `CODE.WZO2-PASSBIT` **PROVEN** — the **first 518 MB artifact was invalid**: passes = 1 encoded with passes = 0, A3 failed on 16.5%, A9 on 24.3M rows; one-character fix `5deec6b`, rebuild. `CODE.WZO2-PASS1-LAW` PROVEN — the 131,068 absent entries are **provably unreachable** single-colour gobans. `WZO2.I2-CLEAN` MEASUREMENT 0 / 99,133,036 independent re-implementation. `4x4.WZO2-A2/A5/A8-EXHAUSTIVE` — **0 / 99,133,036 each**, all three **held at CLAIMED**, deliberately. `src/keybyte_differential.zig` pins decode over all 256 bytes × ko_bits {3,4,5} after T383 F-7 fixed a `kb >> 1` vs `kb >> 2` defect. `CODE.ACCEPT-KOKEY` PROVEN — A1/A2/A8 were originally measuring an **off-manifold walk**: the acceptance harness carried its **own divergent ko rule** | **Why the three exhaustive sweeps are still CLAIMED, and the census agrees:** DIRECTION Amendment 2 edge 5 — **exhaustive measurement is not mutation adequacy**. A sweep that is 0/99,133,036 tells you nothing if the check cannot fail. And the kill matrix that would establish adequacy **disagrees with itself across three records** (`mutants.md` vs `vb_mutants.zig` vs T363's "7/7", T388 D8), while `CODE.M4A-HARNESS` PROVEN records A6 fixture (c) as a **broken positive control** with no row recording a fix. **This — not compute — is the real gate on the word "proven" at 4×4** |

---

## 2. What the census shows, in one page

| | 2×2 | 3×2 | 3×3 | 4×3 | 4×4 |
|---|---|---|---|---|---|
| `PROVEN` cells | 4 | 4 | 5 | 3 | 1 |
| `PARTIAL` | 3 | 3 | 4 | 2 | 5 |
| `OPTIMAL-NOT-PROVEN` | 3 | 3 | 1 | 3 | 4 |
| `UNKNOWN` | 2 | 1 | 2 | 4 | 1 |
| `UNTRUSTWORTHY` | 1 | 2 | 1 | 1 | 1 |
| register `PROVEN` rows at this size | 1 | 5 | 5 | 5 | 4 |
| …of which C3 **Tier A** (committed probe) | 0 | 2 | 1 | 2 | 2 |

*(Cells are counted once per question; where a question splits by rule set the stronger label is
counted and the weaker appears in §3 or §4. Totals per size sum to more than 11 where a question
carries two rule-set readings.)*

**The shape is the same one `SOLUTION-TREE.md` §9 found from the construction side, and it is worth
stating that two independent passes agree:** the PROVEN fraction falls monotonically with size, and
the table the project ships is the one whose foundations are least proven. This census adds the
reason: **the falsifiers were built at the control sizes and never carried up.** `src/colex.zig`
verifies 2×2/3×3/3×2 and stops. `benson_theorem_check` runs at 3×3 and stops. The exhaustive ko
agreement runs at 2×2/3×2 and becomes a sample at 3×3 and nothing at 4×3/4×4. Each individual stop
was reasonable; the cumulative effect is that **the deliverable size has one PROVEN cell out of
eleven.**

---

## 3. Downgrades — register says `PROVEN`, no falsifier found

Fourteen board-scoped rows. Each is named as the brief requires. **None of these rows is asserted
wrong** — the claim may well be true; the point is that nothing committed would catch it if it were
not, so this census cannot grade it `PROVEN`.

| # | row | register status | why downgraded | remedy, and whether it is cheap |
|---|---|---|---|---|
| D1 | `4x3.S1` | PROVEN | Its evidence is a **structural-inheritance argument**, not a 4×3 measurement; `src/colex.zig:256` covers 2×2/3×3/3×2 only | Add `verify(4,3)` — 3¹² = 531,441 raw slots. **Cheap** |
| D2 | `4x4.S1` | PROVEN | "Exhaustive round-trip through 4×4" was run once; Tier B; not in the suite | Add `verify(4,4)` — 3¹⁶ = 43,046,721. **Cheap in ReleaseFast**, likely too slow for the debug default |
| D3 | `3x3.S2-impl` | PROVEN | "Exhaustively falsification-confirmed at 3×3": the suite rung is `benson_theorem_check(3,3,**5**)`; the ≤ 9 full-goban rung exists only in `main()` under `zig run` | Wire the existing `main()` rung into `zig build test`. **Free — the code is written** |
| D4 | `4x4.FP1-C3` | PROVEN (as scoped) | The V0/V1 identity check is a declared **1:37 sample** | Superseded in substance by A2's exhaustive 0/99,133,036 — which is itself held at CLAIMED. **Free to re-point; the promotion is gated on §6 step 8** |
| D5 | `2x2.C1` | PROVEN | Tier B; §6-**D9** records the "exhaustive ground truth" as **8 of 114 roots** | Re-run and commit the history-aware exact solver over all 82 slots. **Cheap** |
| D6 | `3x2.F1` | PROVEN (falsification) | Tier B — a 45/378 measurement with no committed probe or output | Re-run the auditor writes-ON at 3×2 and commit it. **Cheap, and it doubles as the Track A control (§6 step 6)** |
| D7 | `3x2.F3` | PROVEN (necessary condition) | Tier B; and the row's own label concedes it is a *necessary* condition, not soundness | As D6 |
| D8 | `3x2.F4` | PROVEN | Tier B (`0013:88-91`, a grouped 3×2/3×3/4×3 citation with no per-size probe) | Commit the `deps`-mode auditor output per size. **Cheap** |
| D9 | `3x3.F4` | PROVEN | As D8 | As D8 |
| D10 | `4x3.F4` | PROVEN | As D8 — and the committed 4×3 artifact **was not rebuilt** with the validated mode | As D8, plus the rebuild |
| D11 | `3x3.C3` | PROVEN (falsification) | Tier B; and `3x3.E2-RUN2`'s 8,000-game output was **never committed** | **Retain the PROVEN grade in §1.3 Q8 as an exception, declared here:** C3 is the one Tier-B row with a *complete* control set — null control (`GLOBAL.E2-SANITY`), validity control (`3x3.E3`), and an independent replication. Commit RUN2's output to close the debt |
| D12 | `3x3.E3` | PROVEN | Tier B — "0 illegal moves in 17 plies" on one game, no committed replay | Commit the replay. **Cheap** |
| D13 | `4x3.S2` | PROVEN | The theorem restated at a size; the row carries no 4×3 measurement, and `4x3.S2-impl` is UNTESTED | Nothing to prove — but the row invites the misreading that *the implementation* is proven at 4×3. It is not |
| D14 | `4x3.FP3` | PROVEN | As D13 — Knaster–Tarski restated at a size; 17 sweeps is `4x3.M2` MEASUREMENT and the row says so | As D13 |

**One row goes the other way** — the register is *more* pessimistic than the code:

| row | register status | census status | why |
|---|---|---|---|
| `4x4.S2-impl` | **UNTESTED** | **PARTIAL** | Two committed suite rungs compare `rules.benson_alive` against an independently structured reference at 4×4 for ≤ 5 and ≤ 8 stones, asserting `pa_mismatches == 0` and `immediate_capture_violations == 0` (`src/rules.zig:1019`, `:1034`). The register credits none of it |

---

## 4. `UNTRUSTWORTHY` — positively known or recorded wrong

**This list is separate from §1's `UNKNOWN` and `OPTIMAL-NOT-PROVEN` cells by design.** Unproven
means we do not know. These are things we know are wrong, or know were produced by a mechanism
recorded as unsound. Quoting one is not optimism; it is an error.

| # | what | why | live risk |
|---|---|---|---|
| **U1** | `data/oracle-4x4.checkpoint.wzo` and `data/oracle-4x4-parallel.checkpoint.wzo` — the ko-sensitive column | Writes-ON PSK builds under the `ko_ref ≥ d` guard, `GLOBAL.F1` **FALSE-AS-SCOPED** (ADR-0013). `AGENTS.md`: the checkpoint "is the writes-**ON** build, it is the only 4x4 artifact whose root is filled, and **every headline 4x4 number to date came from it**" | High — it is the provenance of the historical 4×4 story |
| **U2** | The **+2 empty-4×4 value**, and its framing as "matches anchor" | `4x4.ANCHOR` **ARCHIVED** (old-artifact: "the anchor is a different game's value"); `GLOBAL.TIE-MIGOS` **FALSE-AS-SCOPED** — MIGOS's own basic-ko 4×4 result is **+1 = ours**; the +2 comes from the pass-difference cycle-resolution rule, a **different game**. The live value is **+1, bracket [+1,+16]** | **Live and uncorrected.** `docs/epistemic/GLOSSARY.md:424` — a file whose own header reads "**Status: living reference. [Current.]**" and which the register lists under "Not swept" — still states "**4x4: +2 (PSK, matches anchor)**" and "3x3: +9 (**PSK**, matches van der Werf & Winands)", the exact mislabel `GLOBAL.MIGOS-RULE` PROVEN was minted to correct, and "4x3: +4 (**perfect**)" against a live [+4,+12] bracket. **This is the single most dangerous stale statement found in the census** |
| **U3** | `4x4.COMPLETE-2026-07-21` — "the complete, validated 4×4 oracle" — and `4x4.VALBATTERY` | Both **ARCHIVED**. The archive's own note on VALBATTERY: "every check passed on a table whose values were later retracted" | The project's own worked example of *never trust a green test*. Cite it as the lesson, never as a result |
| **U4** | `data/oracle-4x4-basicko-tie-area.wzo` (v1 basic-ko WZO1) | `4x4.V1-INVSYM-BROKEN` **PROVEN, Tier A** — **11,658,047** deduplicated violations of `V(−pos,−side) == −V(pos,side)`, roughly **half its positions**; found by independent re-implementation (T260/T270) | Moderate — a superseded artifact still on disk |
| **U5** | The ko-sensitive column of **every** WZO1 artifact — 2×2, 3×2, 3×3, 4×3 | `GLOBAL.F1` FALSE-AS-SCOPED. At 3×2 the wrongness is **measured, not suspected**: `3x2.F1` PROVEN, **45 of 378** slots violate the minimax identity as committed | High at 3×2 (known wrong); unverified at the other three |
| **U6** | The **DTT column** of every WZO1 artifact, all sizes | `CODE.WZO1-DTT-UNSET` **PROVEN** — it is the `@memset` initialiser, never computed. Battery I7 is a **known-fail** at every WZO1 size | Any distance-to-terminal reading off a WZO1 file is meaningless |
| **U7** | The old-artifact census and cost family: `2x2.M4`, `3x2.M4`, `3x3.M1`, `3x3.M4`, `4x3.M1`, `4x3.M3`, `4x3.M4`, `4x4.M1`, `M3`, `M4`, `M5`, `M6`, `M6-EXCESS`, `M6-FLOOR`, `M6-SCREEN`, `4x4.SINGLE`, `4x4.TANGLE`, `4x3.TANGLE`, `3x3.BRACKET`, `4x3.BRACKET`, `4x4.BRACKET`, `3x3.ANCHOR`, `4x4.KO-CENSUS`, `4x4.CYCLE-INSENS` | All **ARCHIVED** as old-artifact, measured on tables the project has disowned. `4x4.M4` is flagged in the archive as "the project's most-cited datum, on an artifact…" | High by citation volume — these are the most-quoted numbers in the older docs. The live ko-sensitive fraction at 4×4 is **3.49%** (3,455,412 / 99,133,036), **not** the archived 21.32% |
| **U8** | The 2026-07-27 "writes-OFF 1.67% vs writes-ON 4.08%" misprice comparison | **Confounded** — T571 found the two files **byte-identical** (sha256 `28afa11b…`), i.e. one build family under two names, not a writes-flag measurement | It is the most cited corroboration of the writes-off remedy, and it measures nothing |
| **U9** | `2x2.T12` as stated — "2×2 admits no reachable non-root cycles" | **FALSE-AS-SCOPED** (T731, 2026-08-23) — a 144-vertex non-trivial SCC under basic ko (160 corrected). True only of **PSK-legal** reachability | **Live and uncorrected** in `boards/2x2/EPISTEMIC.md`, where it is the stated reason C2 and C3 are "N/A" at 2×2. §5 C-4 |

**Boundary case, deliberately not in the list.** `3x3.E2-RUN2` (50/8,000 leaks) has **no committed
output**; its numbers survive only in `PROGRESS.md:128`. The *result* is corroborated — RUN1 is an
independent run at the identical rate and maximum — so this is **evidence debt, not
untrustworthiness**. Ruling D-1 records it as an open item and this census leaves it there.

---

## 5. Where the record contradicts itself — both readings, neither picked

| # | subject | reading A | reading B | register's own note |
|---|---|---|---|---|
| **C-1** | Track A at 2×2/3×2 | **Complete** — "Track A 2×2/3×2 regen complete (B15, byte-identical)", `PROGRESS.md:238-240,244-245` | **Never ran** — `SOLUTION-TREE.md:63` ("ADR-0013's Track A never ran at 2×2"); `AGENTS.md` lists the 2×2/3×2 columns as unverified | §6-**D10** records the tension and names a candidate mechanism — "either the auditor tests the search rather than the table, or the two statements are in tension" — without ruling. **A byte-identical table after turning off a flag that changes 45 slots of search behaviour is the thing to explain** |
| **C-2** | C2 at 4×4 | "Falsification is **analogy-expected, not an open hypothesis**"; "No further C2-probe needed at 4×4" — `boards/4x4/EPISTEMIC.md:46,98,329-331` | **Untested**, per-goban independence prevents inheritance — `PROGRESS.md:212-213`; and `boards/4x3/EPISTEMIC.md:33` applies the opposite rule at the adjacent size | §6-**D3**: "Three documents, three positions." The row `4x4.C2` carries the conflict inside its own status cell |
| **C-3** | C3 at 4×4 | Filed under **Falsifications** — "analogy-expected falsified at 4×4 (NOT an open hypothesis)", `boards/4x4/EPISTEMIC.md:55-66` | Per-goban independence forbids the identical inference — `boards/4x3/EPISTEMIC.md:34` | §6-**D2**; and `boards/CONCEPTS.md:57-61` states **both at once** in a sentence the register calls "a merge artifact" that "does not parse" |
| **C-4** | 2×2 cyclic structure | "2×2 has no reachable non-root cycles" — `boards/2x2/EPISTEMIC.md`, used to declare **both** C2 and C3 "N/A" | **False under basic ko** — 144/160-vertex non-trivial SCC, `2x2.T12` FALSE-AS-SCOPED, witnessed and mechanized in `docs/evidence/QA-023/ko-fix-2026-07-29/scc2x2.py` | The register's resolution is dated **2026-08-23**; the board file predates it and was not updated. By the project's own rule that a status carries an author and a timestamp and later supersedes earlier, the register reading is the later assertion — **but updating the board file is that file owner's call, not this census's** |
| **C-5** | "Exhaustive ground truth at 2×2/3×2" | C1's proof method is "**exhaustive** comparison vs independent exact solver" — `boards/CONCEPTS.md:50-52`; `0009:90-93` ("of EVERY legal (position, side)") | "Only the near-terminal roots complete (2×2: **8 of 114**; 3×2: **68 of 600**)" — `retrograde-3x3.md:50-52,141` | §6-**D9**, unresolved. **This is the contradiction that decides whether `2x2.C1` and `3x2.C1` are proven** (§3-D5). The register notes a partial mitigation the C1 rows do not carry: 0 mismatches on all **540** L == H slots at 3×2, silent on the 189 + 189 ko-sensitive ones |
| **C-6** | The empty 3×2 Black-to-move score | **+1** — `0011:50-51`, `retrograde-3x3.md:220` | **−2** — `consistency-audit.md:32-34`, `0013:20-21`; and **0** as "the published 3×2 score" | §6-**D8**: three values for the same slot in the same generation, and two documents disagree on whether 0 is the *target* or *a different ruleset's answer PSK is expected to beat by a point*. Unresolved |
| **C-7** | Value correctness at 3×3 and 4×3 | **Archived BOGUS** — `3x3.C1` and `4x3.C1` moved to `archives/register/` on 2026-08-05 as *falsified-foundation*; no live row replaced either | **Live and CLAIMED** — `SOLUTION-TREE.md:113,131`; `boards/3x3/EPISTEMIC.md`; `boards/4x3/EPISTEMIC.md`; and `CLAIMS.md:358` cites both IDs in `GLOBAL.F1`'s dependents column | Not recorded as a discrepancy anywhere. `claimlint` C4 correctly resolves both via the archive index, so the linter is right and **the prose is stale**. The consequence is §1.3 Q5 / §1.4 Q5: **the two middle sizes have no live claim about whether their tables are correct** |
| **C-8** | `CLAIMS.md` §4.2's load-bearing-unknowns ranking | Rank 4 is `4x4.S3b` UNTESTED with 5 dependents, "the only top-5 entry with no experiment on paper"; rank 2's list names `4x4.M6-EXCESS` | Both rows are **ARCHIVED** — `4x4.S3b` as *ruleset-choice* ("the k=1 game's ko legality is B1"), `4x4.M6-EXCESS` as *old-artifact* | Not recorded. §4.2 is stale against the 2026-08-05 triage; its live entries (ranks 1–3) still stand |
| **C-9** | The 4×3 empty-goban bracket | **[−1,+12]** — `boards/4x3/EPISTEMIC.md:43` | **[+4,+12]** — `force-life-classifier-2026-08-06.md:118` | **Resolvable, and recorded here as the worked example rather than as a contradiction:** A is R_PSK/WZO1 (and *is* `4x3.BRACKET`, ARCHIVED), B is R_BK0 (rules_id 3 closure). Neither statement carries its rule set at the point of use. **This is exactly why every row in §1 carries a rule-set cell** |
| **C-10** | The 2×2 state-space denominator | **258** reachable states (`2x2.BASICKO-TIE`) · **172** closure vertices (`force-life-classifier-2026-08-06.md` §4) · **255** I5 nodes (`3x2.I5-CAL`) · **1,620** non-terminals (`GLOBAL.ADR0020-LH-CORRECT`) | — | Four counts across four committed documents, differing by state definition (terminals in/out, pass states in/out, true-root vs 42-seed convention). Only *some* pairs carry a reconciliation: `3x2.BASICKO-TIE` documents the analogous +36 phantom-seed reconciliation at 3×2 (12 → L == H, 24 → pin_T). **The 2×2 set has none.** Not a contradiction in itself — an unreconciled denominator family, which is how the 4×3 "24 natural violations" fabrication went undetected for a day |

**One structural note, not a contradiction.** `GLOBAL.ADR0020-LH-CORRECT` — the strongest 2×2
result in the register and one of only two board-relevant Tier-A `PROVEN` rows below 3×3 — carries
the `GLOBAL.` prefix while its goban column reads **2×2**. §1 of the register reserves `GLOBAL` for
size-generic claims. Multi-size rows do the same (`GLOBAL.I5-SCC-CONTAIN` is "3×2/4×3/4×4",
`GLOBAL.LIFE-CERTIFIES` is "3×3/4×4"), so the practice is established for *several* sizes; a
**single**-size row under `GLOBAL` is the odd case, and its effect is that a reader working the 2×2
scope will not find the best 2×2 result.

---

## 6. The shortest honest path to a perfectly-solved 4×4

Dependency-ordered, **smallest board first**, because small boards are cheap and their proofs are
the larger boards' controls. Each step states what it proves, what it costs (**known** or
**guess**, labelled), and what it unblocks. **No schedule and no estimate that cannot be defended
from a committed measurement.** Where a step needs an instrument that does not exist, it says so.

### Step 0 — what "perfectly solved at 4×4" can mean, decided before anything is built

It can mean: **the fresh-start [L, H] table under R_BK0 is exactly right, and a committed check
would catch it if it were not.** It cannot mean the real-game PSK value. `GLOBAL.C2` is
FALSE-AS-SCOPED at 3×2, `GLOBAL.C3` at 3×3, `GLOBAL.C4` outright, and `GLOBAL.FP2-general` is
`INTRACTABLE (possibly unprovable by finite methods)`. PSK exact solve is a standing foreclosure —
118,475,182 ban-set states on the **empty 2×2** — and score-on-cycle is provably as hard. **Cost:
none, it is a definition.** **Unblocks: everything, by preventing the wrong target.** Any 4×4
"perfect solve" announcement must carry non-claims NC1–NC5.

### Steps 1–3 — free, and they remove live wrong statements (no compute at all)

| step | what it does | proves | cost | unblocks |
|---|---|---|---|---|
| **1** | Correct `docs/epistemic/GLOSSARY.md:423-424`: it asserts the retracted **+2** 4×4 value as current, labels the 3×3 **+9** as PSK when `GLOBAL.MIGOS-RULE` PROVEN says MIGOS plays basic ko, and calls 4×3 **+4 "(perfect)"** against a live [+4,+12] bracket | Nothing new — it stops the retracted result being quoted as current from a file headed "Status: living reference. [Current.]" | **Known: minutes.** Also add GLOSSARY to the register's "Sources swept" list; it is currently declared **not swept**, which is how this survived | Nothing technical. Prevents §4 U2 recurring |
| **2** | Correct `boards/2x2/EPISTEMIC.md` (asserts the FALSE-AS-SCOPED `2x2.T12` statement as the reason C2/C3 are N/A) and `boards/4x3/EPISTEMIC.md:43` (states the **archived** PSK bracket without its rule set or its archive label) | Nothing new | **Known: minutes** | §5 C-4, C-9 |
| **3** | Mint the three missing register rows: a live R_BK0 value-correctness row at **3×3** and at **4×3** (the old `C1` rows are archived BOGUS and nothing replaced them), and a **`4x3.BASICKO-TIE`** root row | Nothing new — it makes the two middle sizes' status *statable*. Today the register has **no live claim** about whether the 3×3 or 4×3 tables are correct, while three documents describe one | **Known: minutes.** Needs an auditor under D2 if any row is minted above CLAIMED | **This is the true blocker on "prove smaller boards"** — you cannot prove a claim the register does not carry |

### Steps 4–8 — cheap, mechanical, and each one closes a falsifier this census could not find

All five are mutually independent and all are independent of Track A. Smallest first.

| step | what it does | proves | cost | unblocks |
|---|---|---|---|---|
| **4** | Add `verify(4,3)` then `verify(4,4)` to `src/colex.zig:256` | `4x3.S1` and `4x4.S1` — the two rows asserted PROVEN on a one-shot run and an inheritance argument (§3-D1, D2) | **Known for 4×3** (3¹² = 531,441 raw slots; the committed 3×3 rung is 3⁹ = 19,683 and the whole 5-test file runs in well under a second). **4×4 is 3¹⁶ = 43,046,721** — same algorithm, ~2,200× the 3×3 work; budget it as a ReleaseFast or env-gated rung, not a debug-suite default | Q1 at both sizes; every address in the 518 MB artifact |
| **5** | Wire the existing full-goban Benson rung into the suite: `src/rules.zig` `main()` already runs `benson_theorem_check(3,3,9)`; the suite runs `(3,3,5)` | `3x3.S2-impl`'s "exhaustive at 3×3" wording (§3-D3) — and 3×3 is the **control** for the 4×4 terminal-detection rung | **Free — the code exists.** Only the wiring is missing | Step 6, which needs a trusted 3×3 rung to compare against |
| **6** | Raise `benson_alive_regression_check(4,4,k)` from **k ≤ 8** to **k ≤ 16** | `4x4.S2-impl` — currently UNTESTED in the register although ≤ 8 is already committed. Closes the 9–16-stone range, i.e. **exactly where a 16-cell-specific bound error would bite**, which the test's own header names as its reason for existing | **Guess, bounded.** k ≤ 8 is 11,876,097 candidate positions with a stated 60 s debug budget; the full candidate space Σ C(16,k)·2ᵏ to k = 16 is 43,046,721, so under 4× the candidate count, less after the legality filter. Feasible; treat as an opt-in ReleaseFast rung | Q3 at 4×4; terminal detection stops resting on inheritance |
| **7** | Point the committed independent Tromp–Taylor scorer (`docs/evidence/GLOBAL-S4/scorer-2026-07-30.py`) at 4×3 and 4×4 terminals, with a stated denominator | `4x3.S4` and `4x4.S4`, both **UNTESTED (`⬜ᴵᴺᴴ`)** — self-declared inheritance | **Known-small** — the instrument exists and ran 0 disagreements / 120 gobans. Exhaustive over *settled* positions is the honest target | Q3 scoring at the two largest sizes |
| **8** | Read `4x4.FP1-C1` and `4x4.FP1-C2` **post-hoc out of T104's committed audit output** — seed-from-±N, final zero-change sweeps | The two UNTESTED thirds of `4x4.FP1`'s acceptance set; the third condition already passes | **Known: no build, a read.** §4.2 ranks it the cheapest way to finish an acceptance test that is two-thirds done | Closes the `Z-CONVERGE-SEED` gap that **no battery invariant covers** |

### Step 9 — Track A, the single largest open item, run smallest-first with 3×2 as its control

**What it is:** regenerate each artifact with `memo_writes = false` and pass the **#2
self-consistency auditor** (zero minimax-identity violations). `4x4.D3` UNTESTED is the gate; it
carries the highest dependent count in the register (§4.2 rank 1: 7 dependents) and gates
`4x4.F2`, `F3`, `F4` and artifact promotion.

**Order, and why:**

1. **3×2 first — it is the calibrated red-then-green rung.** `3x2.F1` PROVEN measures **45 / 378**
   violations writes-ON and `3x2.F3` PROVEN measures **0 / 378** writes-off. That is a check
   demonstrated able to fail and then to pass — the one thing the project's doctrine requires
   before a reading counts. Running 3×2 first also settles §5 C-1 (complete vs never-ran) by
   observation instead of by document archaeology.
2. **2×2 second** — no committed #2-auditor run exists at 2×2 under either rule set, and 2×2 is
   where `fix2x2.py` already gives an independent re-implementation to compare against.
3. **3×3, then 4×3.** At 4×3 this is the only route to the **170,276 KO_SENSITIVE slots (26.47%)**
   that I4 currently **excludes**; `4x3.F4` PROVEN already validated `deps` mode there (0 auditor
   violations, byte-identical to writes-off) and the committed artifact was simply never rebuilt
   with it. That makes 4×3 the cheapest real conversion in the list.
4. **4×4 last.**

**Cost:** **known through 4×3** — the 4×3 writes-ON solve is ~4.7 s and ~31 s with the sound
dependency guard (`4x3.M3`, and note that row is archived as old-artifact cost data, so treat it as
an order-of-magnitude anchor, not a budget). **A guess at 4×4** — `4x4.D3`'s "≤ 8 h wall, ≤ 32 GB"
is recorded **as a placeholder, explicitly unconfirmed with the operator**, and the register's own
label on the row is "a measurement, not a truth claim". Cheap proxies are already specified: a
D3-4×3 pilot and a `RETRO_ONE_SWEEP=1` per-sweep unit × 19.

**Two instrument gaps this census must flag before anyone starts:**

- **The PSK-era writes-off files do not discharge Track A at 4×4.** T571 found the two `untracked/`
  writes-off 4×4 checkpoints are byte-identical to `data/oracle-4x4-parallel.checkpoint.wzo` and are
  `rules_id = 1` (**PSK**), so neither can cross-check the basic-ko WZO2 table. **A Track A regen at
  4×4 must be a basic-ko build.** The 1.67%-vs-4.08% corroboration everyone cites is confounded
  (§4 U8).
- **No committed basic-ko writes-off builder run exists at any size.** The instrument may exist; a
  run of it does not. Confirm before scheduling 4×4.

**Unblocks:** every ko-sensitive value at every size — including **the 4×4 root bracket [+1,+16]**,
3.49% of the table and the single most important datum in it, whose promotion is blocked today.

### Step 10 — the exhaustive I11 at 4×4

**What it proves:** that the move generator agrees with the reference over the whole table, closing
the **0.05%** sample (50,000 of 99,133,036) that is the one non-exhaustive G3b condition and
`4x4.C1`'s largest scope limit. It also closes the class — T178, T193, T265 — that produced the
project's three most expensive defects.

**Cost: a guess, but an anchored one.** The C-A1 closure check already walked **600,763,414**
children at 4×4, so work of that order is known feasible; that it is env-gated
(`WEIZIGO_CLOSURE_4X4_FULL=1`) is the evidence it is expensive but bounded.

**Do it together with step 11** — an exhaustive I11 that is not mutation-adequate buys a bigger
denominator, not a proof.

### Step 11 — mutation adequacy, and the reason it, not compute, is the gate on the word "proven"

`4x4.WZO2-A2-EXHAUSTIVE`, `-A5-`, and `-A8-` are each **0 / 99,133,036** and each is held at
**CLAIMED on purpose**: DIRECTION Amendment 2 edge 5 — **exhaustive measurement is not mutation
adequacy**. A check that cannot fail tells you nothing at any denominator.

**And the instrument that would establish adequacy does not exist in a trustworthy form:**

- the kill matrix **disagrees with itself across three records** — `mutants.md` vs `vb_mutants.zig`
  vs T363's "7/7" (T388 D8);
- `CODE.M4A-HARNESS` **PROVEN** records A6 fixture (c) as a **broken positive control** — it called
  the check on the *uncorrupted* slice — and **no row records a fix**; `SOLUTION-TREE.md:270`
  carries it as UNDETERMINED;
- the A5 stride-97 sample was **never verified coprime** to the group sizes (`SPRINT-M4a-ACCEPT`).

**Cost: unknown, and it is a tooling cost, not a compute cost.** Reconciling the kill matrix and
repairing the positive control must come first; until they do, **no exhaustive sweep at 4×4 can be
promoted, however many entries it covers.** This is the honest answer to "what stands between us
and a proven 4×4": not machine time.

**Unblocks:** the promotion of every exhaustive acceptance sweep, and therefore `4x4.C1` itself.

### Step 12 — two structural gaps that no size closes on its own

| step | what | why it matters | cost | instrument exists? |
|---|---|---|---|---|
| **12a** | A battery invariant for **producer/consumer key agreement** (`GLOBAL.BATTERY-GAPS` G1/G3) | The T178/T193/T265 family is the project's most expensive bug class and has **zero battery coverage**; the T345 exhaustive (0 / 99,133,036) and T267 game-sampled differentials live **outside** the battery, so the class can recur unnoticed | **Known-small** — wire existing instruments | **Yes** — only the wiring is missing |
| **12b** | A **least-ness witness** at any size, starting at 2×2 | `GLOBAL.FP1` is PROVEN **as mathematics**; every per-size instance row (`2x2.B1`, `3x2.B1`, `3x3.B1`) is **CLAIMED with its primary evidence deleted**; and `GLOBAL.B1-AUDIT` **PROVEN** states that the re-converge-from-+N check **is not** a least-ness witness. So "L is the *least* fixpoint" has **no committed instance witness at any size** — while L is half of the deliverable | **Guess — smallest-first is 2×2**, 1,620 non-terminals, where `fix2x2.py` already re-implements the fixpoint independently | **No.** This instrument does not exist. Say so before the operator is told L is proven |

### The dependency graph, in one block

```
Step 0  (define the target)
  └─ Steps 1,2,3  (free; fix wrong statements; make 3x3/4x3 status statable)
       ├─ Step 4   colex verify(4,3) -> verify(4,4)          [independent]
       ├─ Step 5   wire full-goban Benson at 3x3  ──> Step 6  Benson k<=16 at 4x4
       ├─ Step 7   independent scorer at 4x3, 4x4            [independent]
       ├─ Step 8   post-hoc FP1-C1 / FP1-C2 read              [independent]
       ├─ Step 9   TRACK A:  3x2 (control) -> 2x2 -> 3x3 -> 4x3 -> 4x4
       │              └─ unblocks the KO_SENSITIVE column and the root bracket [+1,+16]
       ├─ Step 11  reconcile the kill matrix + repair A6 fixture (c)   <-- the real gate
       │              └─ Step 10  exhaustive I11 at 4x4
       │                    └─ promotion of A2/A5/A8 and of 4x4.C1
       └─ Step 12a battery cell for key agreement · 12b least-ness witness at 2x2
```

**Steps 1–8 and 12a need no new instrument.** Step 9 needs a confirmed basic-ko writes-off build.
Steps 11 and 12b need instruments that **do not exist**, and step 11 is on the critical path to the
word *proven*.

---

## 7. `UNKNOWN` — stated because it is true

The brief requires this list, and a census that resolved everything would be worthless.

1. **Whether the 3×3 table is value-correct.** No live register row (§1.3 Q5, §5 C-7).
2. **Whether the 4×3 table is value-correct.** No live register row (§1.4 Q5).
3. **The empty 3×2 R_PSK score.** Three committed values, §6-D8 unresolved (§1.2 Q4).
4. **Whether Track A ran at 2×2/3×2.** Two committed readings, §6-D10 unresolved (§5 C-1).
5. **C2 at 3×3, 4×3, 4×4.** Untested at the first two by per-goban independence; a three-document
   status conflict at 4×4 (§6-D3).
6. **C3 at 4×3, and at 4×4.** Untested at 4×3; status conflict at 4×4 (§6-D2).
7. **Terminal detection and area scoring at 4×3.** No `S2-impl` measurement, `S4` inherited.
8. **Area scoring at 4×4.** `4x4.S4` inherited; the independent scorer has never run there.
9. **Least-ness of L at every size.** Mathematics proven, instance witness absent everywhere.
10. **The exhaustive forced-cycle status at 4×4.** `4x4.LOOPY-TAXONOMY` says so in the row: the
    depth-3 forced count is a **sample lower bound** and the question is OPEN.
11. **Whether A6 fixture (c) — a broken positive control — was ever fixed.** No row records it.
12. **The cost of a 4×4 writes-off regen.** `4x4.D3`'s budget is a placeholder, unconfirmed.
13. **Whether a 4×3 `S2-impl` regression exists at all.** Nothing has looked.

---

## 8. Method, coverage, and what this census did not do

**Rule applied:** `PROVEN` requires a committed, re-runnable, non-vacuous falsifier at the claim's
own size and rule set, or a theorem with a stated refutation route. Every judgement call was biased
**downward** and named (§3). No claim status was changed and none is proposed. `docs/epistemic/CLAIMS.md`
was read, not edited.

**Instruments actually run for this census:** `bin/weizigo-claimlint` (C0–C10 at HEAD: rows parsed
231, C1a/C1b/C2 all 0, C3 42 Tier B / 0 Tier C / 24 Tier A of 66 PROVEN, 49 C4 ghost IDs) and
`zig test src/colex.zig` (5/5 pass — which is how the 4×4 and 4×3 bijection gaps in §3-D1/D2 were
established rather than inferred).

**Read:** `docs/epistemic/CLAIMS.md` (§1–§8, all live rows); `docs/epistemic/SOLUTION-TREE.md`;
`docs/epistemic/boards/{2x2,3x2,3x3,4x3,4x4}/EPISTEMIC.md`; `docs/epistemic/GLOSSARY.md`;
`archives/register/INDEX.md`; `docs/epistemic/register-triage-2026-08-04.md`; `AGENTS.md`
foreclosures; `docs/epics/E1-markovian/AXIOMS.md` §1–§2 and §7; `docs/epics/E1-markovian/LANDMARKS.md`;
`docs/audits/2026-08-02-grand-audit/DIRECTION.md`; `docs/decisions/` (0003, 0009, 0011, 0013, 0016,
ADR-0020, ADR-0022); `docs/research/force-life-classifier-2026-08-06.md`;
`docs/evidence/T571-SINGLE-POSITION-LEAK/PROVENANCE.md`; `docs/infra/property-ownership.md`;
`docs/infra/instrument-coverage.md`; `src/colex.zig`, `src/rules.zig`, `src/claimlint.zig`.

**Not done, and named so the gap is honest:**

- **No artifact was opened.** Every figure here is a citation, not a re-measurement. The 4×4 table
  is 518 MB and re-deriving its counts is the work of §6, not of a census.
- **`src/retro.zig`, `src/exp6_solve.zig`, `src/oracle_v2_accept.zig` and the `vb_*` battery
  modules were not read.** Their register rows and the T395 ownership table were taken as given.
  A cell graded `PARTIAL` on a battery reading might move either way on direct inspection.
- **`docs/epistemic/PROGRESS.md` was read only through the register's citations of it.** Several
  contradictions in §5 have `PROGRESS.md` on one side; the line references come from the register's
  own quotations, which are pinned to the 2026-07-28 sweep and may have drifted.
- **The five `2x2`/`3x2` sub-questions with no register row at all** (a 2×2 `S2-impl`, a 3×2
  `S2-impl`, a `4x3.B1`, a `4x3.BASICKO-TIE`, a live C1 at 3×3/4×3) are reported as `UNKNOWN`
  rather than minted. Minting is step 3 of §6 and needs an auditor under the D2 policy.

**Close, in one line.** Two boards are genuinely well proven and neither is the one we ship: **3×2
carries the project's strongest result** (`3x2.T13`, an exhaustive independently-re-implemented
committed refutation) **and its worst artifact** (45 of 378 ko-sensitive slots wrong as committed);
**3×3 is the only size with third-party agreement under our own rule set** (+9, basic ko) **and has
no live claim that its table is correct**; and at **4×4 one of eleven questions is proven, the gate
on the rest is a broken positive control and a self-contradicting kill matrix rather than machine
time, and the retracted +2 value is still stated as current in the project's own glossary.**

---

*Companion findings: `findings/T836-board-proof-census.json`. This file is a census and carries no
authority to change a status; §3, §4 and §5 are reports for the Orchestrator and the auditors, not
rulings.*
