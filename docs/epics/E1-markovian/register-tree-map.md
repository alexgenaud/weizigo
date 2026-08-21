# register-tree-map — every register row mapped onto the requirement tree

Task: T305 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-03

## What this is

The deferred Phase 0 deliverable (DIRECTION §5, `DIRECTION.md:102-104`; AXIOMS.md §6;
the T271 brief): every row of `docs/epistemic/CLAIMS.md` mapped onto the requirement
tree of AXIOMS.md §3. Rows that map nowhere are **proposed-retired** — dispositions, not
deletions; the human rules on retirements (this file proposes). Tree nodes with no row
are listed under §5 as new work.

## The lintable convention

Each register row now carries its tree node in an 11th column, `tree`, appended after
`wrong-answer-pass-rate` (this is the only place the mapping lives inside the register;
this document is the human rendering and is mechanically cross-checked by claimlint's
C9 — row set and per-row node must match the register exactly, so this document cannot
silently cover a subset and cannot drift from the rows).

**C9 check added by T305:** `src/claimlint.zig` now validates (a) every `tree` cell is
a known node or a disposition marker (`RETIRED`), and (b) the mapping document's row set
== the register's row set, per-row node equal. Gated: floor `C9: 0` in
`tools/hooks/claimlint-floor.json`, enforced by `tools/hooks/pre-commit`.

## Conventions used for the mapping

- **Axioms map to the Z-R child the tree enumerates them under** (AXIOMS §3.2: A1–A5, B1–B3 →
  Z-R-MOVE; C1/C2 → Z-R-SCORE; C3 → Z-R-TIE; C4 → Z-R-SIGN; D1–D3 → Z-R-STATE).
- **E1–E3 are not placed in §3.2**; this mapping puts E1 (Bellman) and E2 (L/H fixpoint) under
  Z-CONVERGE and E3 (bracket semantics) under Z-TABLE, which are the nodes they define.
- **Old-world rows** (PSK-era foreclosures, writes-on-artifact measurements, finisher-era
  design, player-side defects, process rules) map nowhere: the theorem is stated for a fixed
  ruleset R (k=1 basic ko, TIE=0) and asserts nothing about the old generation, the player,
  or the ruleset's alternatives. They are proposed-retired with the reason stated per family.
- **Non-claims NC1–NC5 are first-class**: the C2/C3/C4 falsification family, the leak family,
  and the per-goban-independence rulings map to Z-NONCLAIMS — the negative half of Z is as
  load-bearing as the positive half.
- **Measurements map to the node they evidence** (e.g. `4x4.M2` 19 sweeps → Z-CONVERGE-FINITE,
  `2x2.BASICKO-TIE` root value → Z-TABLE), not to a node of their own.

## 1. The mapping — 226 rows (matches the register; count printed by claimlint C0). The 132 rows triaged out on 2026-08-06 (T373) live in archives/register/INDEX.md — see §2.

| ID | tree node | note |
|---|---|---|
| `2x2.B1` | Z-CONVERGE-FIX | true least fixpoint at 2x2; also bears on MONO via monotone-from-−N |
| `2x2.BASICKO-TIE` | Z-TABLE | fresh-start value under exactly R at 2x2; also evidences FINITE (4 sweeps) and FIX (0 failures) |
| `2x2.C1` | Z-TABLE-FAITHFUL | fresh-start values verified vs exact solver |
| `2x2.C3` | Z-NONCLAIMS | NC2: leak-free measurement at 2x2 |
| `2x2.EXACT` | Z-TABLE-FAITHFUL | history-exact ground truth for the 2x2 values |
| `2x2.F2` | Z-TABLE-FAITHFUL | finisher agreement at 2x2 |
| `2x2.T12` | Z-NONCLAIMS | NC1: C2-pilot at 2x2 tautological (no cycles) |
| `3x2.B1` | Z-CONVERGE-FIX | true least fixpoint at 3x2 |
| `3x2.BASICKO-TIE` | Z-TABLE | fresh-start value under exactly R at 3x2; 10 sweeps |
| `3x2.C1` | Z-TABLE-FAITHFUL | fresh-start values verified vs exact solver |
| `3x2.C3` | Z-NONCLAIMS | NC2: leak-free measurement at 3x2 |
| `3x2.EXACT` | Z-TABLE-FAITHFUL | history-exact ground truth for the 3x2 values |
| `3x2.F1` | Z-TABLE-FAITHFUL | 45/378 minimax-identity violations, writes-off gives 0 |
| `3x2.F3` | Z-TABLE-FAITHFUL | writes-off self-consistent at 3x2 |
| `3x2.F4` | Z-TABLE-FAITHFUL | deps mode validated at 3x2 |
| `3x2.I5-CAL` | Z-AUDIT | T171's I5 reproduction partial — instrument calibration state |
| `3x2.T13` | Z-NONCLAIMS | NC1: C2 falsified at 3x2 — 154/508 L==H slots history-sensitive |
| `3x3.B1` | Z-CONVERGE-FIX | true least fixpoint at 3x3 |
| `3x3.BASICKO-TIE` | Z-TABLE | fresh-start value under exactly R at 3x3; root +9, 16 sweeps |
| `3x3.C2` | Z-NONCLAIMS | NC1 at 3x3 — UNTESTED |
| `3x3.C3` | Z-NONCLAIMS | NC2: C3 falsified at 3x3 (12-pt leak) |
| `3x3.E2-RUN1` | Z-NONCLAIMS | NC2: 25/4000 leak measurement |
| `3x3.E2-RUN2` | Z-NONCLAIMS | NC2: 50/8000 replication |
| `3x3.E3` | Z-NONCLAIMS | NC2: the 3x3 leaking game is a valid game |
| `3x3.F2` | Z-TABLE-FAITHFUL | finisher completes all 622 reps at 3x3 |
| `3x3.F4` | Z-TABLE-FAITHFUL | deps mode validated at 3x3 |
| `3x3.FWD-SPOT` | Z-TABLE-FAITHFUL | forward re-solve of 105 sampled roots, 105/105 matched |
| `3x3.H1-CENSUS` | Z-STATE-REACH | 22,736 reachable triples at 3x3 |
| `3x3.S2-impl` | Z-R-SCORE | Benson implementation falsification-confirmed |
| `4x3.C2` | Z-NONCLAIMS | NC1 at 4x3 — UNTESTED |
| `4x3.C3` | Z-NONCLAIMS | NC2 at 4x3 — UNTESTED |
| `4x3.F1` | Z-TABLE-FAITHFUL | inherited unsoundness at 4x3 |
| `4x3.F2` | Z-TABLE-FAITHFUL | UNTESTED |
| `4x3.F4` | Z-TABLE-FAITHFUL | deps mode validated at 4x3 |
| `4x3.FP1` | Z-CONVERGE-FIX | CLAIMED |
| `4x3.FP3` | Z-CONVERGE-FINITE | PROVEN |
| `4x3.H1-CENSUS` | Z-STATE-REACH | 638,266 reachable triples at 4x3 |
| `4x3.M2` | Z-CONVERGE-FINITE | 17 sweeps at 4x3 |
| `4x3.S1` | Z-STATE-LEGAL | inherited structural proof |
| `4x3.S2` | Z-R-SCORE | Benson theorem at 4x3 |
| `4x3.S2-impl` | Z-R-SCORE | UNTESTED — size-specific Benson impl |
| `4x3.S3a` | Z-STATE-LEGAL | legal count 321,689, project ground truth |
| `4x3.S4` | Z-R-SCORE | UNTESTED at 4x3 |
| `4x4.A-2` | Z-NONCLAIMS | C2-scope category error — every blundering node is ko-sensitive, outside NC1's scope |
| `4x4.B16-GAME` | Z-NONCLAIMS | NC4: in-the-wild real-game ≠ fresh-start (GHI divergence) |
| `4x4.B39` | Z-NONCLAIMS | NC4: 45.3% leak — superseded measurement artifact |
| `4x4.B43` | Z-NONCLAIMS | NC4: 3.4% clean leak with UNDEF guard |
| `4x4.B43-DIV` | Z-NONCLAIMS | NC4: 476 real divergence events survive the guard |
| `4x4.BASICKO-TIE` | Z-TABLE | fresh-start value under exactly R at 4x4; root +1, bracket [+1,+16], 31 sweeps |
| `4x4.C1` | Z-TABLE-FAITHFUL | UNTESTED — 'supported, not proven' |
| `4x4.C2` | Z-NONCLAIMS | NC1 at 4x4 — UNTESTED (status conflict §6-D3) |
| `4x4.C3` | Z-NONCLAIMS | NC2 at 4x4 — UNTESTED (status conflict §6-D2) |
| `4x4.D3` | Z-TABLE-FAITHFUL | writes-off 4x4 tractability — feasibility of the faithful generation, UNTESTED |
| `4x4.F1` | Z-TABLE-FAITHFUL | inherited unsoundness at 4x4 |
| `4x4.F2` | Z-TABLE-FAITHFUL | UNTESTED — needs writes-off regen |
| `4x4.F3` | Z-TABLE-FAITHFUL | UNTESTED at 4x4 |
| `4x4.F4` | Z-TABLE-FAITHFUL | UNTESTED at 4x4 |
| `4x4.FP1` | Z-CONVERGE-FIX | three-check acceptance |
| `4x4.FP1-C1` | Z-CONVERGE-SEED | seeded from −N/+N, per build logs — UNTESTED |
| `4x4.FP1-C2` | Z-CONVERGE-FINITE | zero-change final sweeps — UNTESTED |
| `4x4.FP1-C3` | Z-CONVERGE-FIX | V0/V1 Bellman identities — PASSES on sample |
| `4x4.FP3` | Z-CONVERGE-FINITE | UNTESTED |
| `4x4.G-CENSUS` | Z-COMPLETE-ENUM | group-count bracket — the artifact's board address space covers the reachable boards |
| `4x4.I5-FEAS` | Z-STATE-REACH | battery I5 cycle-reachability feasibility — the reachable-graph check |
| `4x4.M2` | Z-CONVERGE-FINITE | 19 sweeps to fixpoint at 4x4 |
| `4x4.P3` | Z-NONCLAIMS | NC4: 8–16% leak measurement |
| `4x4.S1` | Z-STATE-LEGAL | round-trip through 4x4 |
| `4x4.S2-impl` | Z-R-SCORE | UNTESTED — size-specific Benson impl |
| `4x4.S3a` | Z-STATE-LEGAL | legal count 24,318,165 = OEIS A094777 |
| `4x4.S4` | Z-R-SCORE | UNTESTED at 4x4 |
| `4x4.V1-INVSYM-BROKEN` | Z-TABLE-CONSISTENCY | the consistency check catches the v1 artifact's inversion failure |
| `4x4.WZO2-A2-EXHAUSTIVE` | Z-CONVERGE-FIX | A2 Bellman identity on all 99,133,036 entries, exhaustive |
| `4x4.WZO2-A5-EXHAUSTIVE` | Z-TABLE-ROUNDTRIP | A5 round-trip on all entries, exhaustive — closes the stride-97 sampling gap |
| `4x4.WZO2-A8-EXHAUSTIVE` | Z-TABLE-CONSISTENCY | A8 DTT consistency on all entries, exhaustive |
| `CODE.ACCEPT-KOKEY` | Z-STATE-KEY | accept checker's second ko-rule copy — fourth producer/consumer key disagreement |
| `CODE.ADR0011-FMT` | Z-TABLE | WZO1 format: six frozen columns, no lo/hi — determines what the artifact can carry |
| `CODE.ADR0011-GATE` | Z-TABLE-CONSISTENCY | saveArtifact refuses to write unless consistency checks pass |
| `CODE.BATTERY-STUBBED` | Z-AUDIT | the battery was stubbed — instrument validity |
| `CODE.CLAIMLINT-C7-NEWROWS` | Z-AUDIT | claimlint C7 parser defect — the audit instrument's validity |
| `CODE.GTP-KOKEY` | Z-STATE-KEY | GTP ko-rule mismatch — third producer/consumer key disagreement (T265) |
| `CODE.KEY-AGREEMENT` | Z-STATE-KEY | 3.3 Z-STATE-KEY cites T267 — key-agreement invariant wired into tests |
| `CODE.M4A-HARNESS` | Z-AUDIT | M4a harness orphaned and part-defective — instrument validity |
| `CODE.S4-XVAL` | Z-R-SCORE | cross-validation measurement of rules.zig scorer |
| `CODE.VB-BLINDGAPS` | Z-AUDIT | five spec gaps including the I11 dump format — battery spec |
| `CODE.VB-STUBS` | Z-AUDIT | verify-battery not wired to invariants — instrument validity |
| `CODE.WZO2-BUILD-REPRO` | Z-TABLE-CONSISTENCY | builder reproduces the artifact byte-for-byte — reproducibility |
| `CODE.WZO2-INCOMPLETE` | Z-COMPLETE-ENUM | 3.6 cites this row — the refuted incompleteness claim; structural completeness established |
| `CODE.WZO2-PASS1-LAW` | Z-COMPLETE-PASSES | 3.6 Z-COMPLETE-PASSES: the single-colour-side law |
| `CODE.WZO2-PASSBIT` | Z-STATE-KEY | passes-bit key collision — the T193 producer/consumer key disagreement |
| `GLOBAL.ADR0003-AREA` | Z-R-SCORE | area score a pure function of the terminal snapshot |
| `GLOBAL.ADR0004-TERM` | Z-R-SCORE | Benson-terminal leaf scores are the true game score |
| `GLOBAL.ADR0005-CACHE` | Z-TABLE-FAITHFUL | the refuted ko_ref ≥ d memo rule — why old artifacts are not faithful |
| `GLOBAL.ADR0005-DBLPASS` | Z-R-SCORE | area score exact at double pass (Tromp–Taylor) |
| `GLOBAL.ADR0005-PASS` | Z-R-MOVE | pass always legal (A5) — the 'no children' case is subsumed |
| `GLOBAL.ADR0006-EYE` | Z-AUDIT | eye-prune weak dominance — soundness of the forward cross-check instruments |
| `GLOBAL.ADR0006-LEMMAS` | Z-AUDIT | six eye-prune premises verified per goban |
| `GLOBAL.ADR0006-PRED` | Z-AUDIT | eye-prune predicate validation (17/17 fixtures) |
| `GLOBAL.ADR0006-PRUNEALL` | Z-AUDIT | prune-all positions valued identically |
| `GLOBAL.ADR0006-TEST` | Z-AUDIT | eye-pruned forward search vs unpruned retrograde agreement |
| `GLOBAL.ADR0007-TENSION` | Z-COMPLETE-ENUM | eye-prune-vs-coverage tension resolved by ADR-0009 |
| `GLOBAL.ADR0008-HOLE` | Z-TABLE-FAITHFUL | retraction of the cacheability 'theorem' |
| `GLOBAL.ADR0009-HONESTY` | Z-NONCLAIMS | NC1: certification argument's unproven step |
| `GLOBAL.ADR0009-NOEYE` | Z-COMPLETE-ENUM | retrograde uses the full legal move set — coverage total |
| `GLOBAL.ADR0010-SOUND` | Z-TABLE-FAITHFUL | ADR-0010 bracket claim closed empirically |
| `GLOBAL.ADR0012-PAR` | Z-TABLE-CONSISTENCY | byte-identical under threads — reproducibility |
| `GLOBAL.ADR0014-PURE` | Z-NONCLAIMS | score.zig consults no oracle values — the NC-honesty in the scoring UI |
| `GLOBAL.ADR0015-BURDEN` | Z-TABLE-FAITHFUL | ADR-0010's bracket premise refuted — the finisher stays orphaned |
| `GLOBAL.ADR0016-INHERIT` | Z-NONCLAIMS | NC3: per-goban independence policy |
| `GLOBAL.ADR0020-LH-CORRECT` | Z-TABLE | 2x2 L<H gaps are the correct bracket output (E3 semantics) |
| `GLOBAL.ADR0020-VERIFY-PASS` | Z-CONVERGE-FIX | defines ADR-0020 verification = 0 Bellman violations + fixture agreement |
| `GLOBAL.AUDITOR` | Z-AUDIT | 3.7 Z-AUDIT; also NC5 (gate before 'verified') |
| `GLOBAL.AXIOM-AMEND1` | Z-R-MOVE | axiom-change event for A5/B1 (and TIE-MIGOS registration) |
| `GLOBAL.AXIOM-AMEND2` | Z-R-MOVE | axiom-change event for B1's derivation |
| `GLOBAL.AXIOM-AMEND4` | Z-R-SCORE | axiom-change event for C2 — scoring restated as Tromp-Taylor as-stands, no removal at the terminal (T400) |
| `GLOBAL.AXIOM-AREA` | Z-R-SCORE | 3.2 C2 under Z-R-SCORE |
| `GLOBAL.AXIOM-BASICKO` | Z-R-MOVE | 3.2 B1 under Z-R-MOVE |
| `GLOBAL.AXIOM-BELLMAN` | Z-CONVERGE | E1 defines Φ — the operator Z-CONVERGE asserts converges; E-axioms not placed in 3.2 (finding) |
| `GLOBAL.AXIOM-BRACKET` | Z-TABLE | E3 defines the bracket semantics of stored values |
| `GLOBAL.AXIOM-CAPTURE` | Z-R-MOVE | 3.2 A3 under Z-R-MOVE |
| `GLOBAL.AXIOM-FORCEDPASS` | Z-R-MOVE | A6 not enumerated in 3.2's A1–A5 list — tree amendment needed (finding) |
| `GLOBAL.AXIOM-FRESHSTART` | Z-R-STATE | 3.2 D2 under Z-R-STATE |
| `GLOBAL.AXIOM-GEOM` | Z-R-MOVE | 3.2 A1 under Z-R-MOVE |
| `GLOBAL.AXIOM-KOPASS` | Z-R-MOVE | 3.2 B3 under Z-R-MOVE (register dependents column says Z-R-TIE — grouping discrepancy, finding) |
| `GLOBAL.AXIOM-KOSTATE` | Z-R-MOVE | 3.2 B2 under Z-R-MOVE (register dependents column says Z-R-STATE — grouping discrepancy, finding) |
| `GLOBAL.AXIOM-LH` | Z-CONVERGE | E2 defines the fixpoints and seeds |
| `GLOBAL.AXIOM-PASS` | Z-R-MOVE | 3.2 A5 under Z-R-MOVE |
| `GLOBAL.AXIOM-PASSSTATE` | Z-R-STATE | 3.2 D3 under Z-R-STATE |
| `GLOBAL.AXIOM-SCORESIGN` | Z-R-SIGN | 3.2 C4 under Z-R-SIGN |
| `GLOBAL.AXIOM-STATE` | Z-R-STATE | 3.2 D1 under Z-R-STATE |
| `GLOBAL.AXIOM-STONE` | Z-R-MOVE | 3.2 A2 under Z-R-MOVE |
| `GLOBAL.AXIOM-SUICIDE` | Z-R-MOVE | 3.2 A4 under Z-R-MOVE |
| `GLOBAL.AXIOM-TERMINAL` | Z-R-SCORE | 3.2 C1 under Z-R-SCORE |
| `GLOBAL.AXIOM-TIE` | Z-R-TIE | 3.2 C3 under Z-R-TIE |
| `GLOBAL.B1-AUDIT` | Z-CONVERGE-MONO | re-converge check is not a least-ness witness |
| `GLOBAL.B1-MULTIFIX` | Z-CONVERGE-MONO | multi-fixpointedness measurement |
| `GLOBAL.BATTERY-GAPS` | Z-AUDIT | battery coverage gaps across six nodes (G1 Z-R-STATE, G2 Z-STATE-REACH, G3 Z-STATE-KEY, G4 Z-TABLE-ROUNDTRIP, G5 Z-CONVERGE-SEED, G6 Z-CONVERGE-MONO) |
| `GLOBAL.BATTERY-PASS1-ACCEPTANCE` | Z-AUDIT | Phase 1 acceptance criteria re-based on Amendment 1 |
| `GLOBAL.BRUTE-ALIASING` | Z-AUDIT | checker defect invalidated brute-force corroboration — audit-instrument doctrine |
| `GLOBAL.C1` | Z | definition of fresh-start correctness — the theorem's core definition |
| `GLOBAL.C2` | Z-NONCLAIMS | NC1: single-score history-independence FALSE-AS-SCOPED at 3x2 |
| `GLOBAL.C3` | Z-NONCLAIMS | NC2: bracket bounds real-game — FALSE-AS-SCOPED at 3x3 |
| `GLOBAL.C4` | Z-NONCLAIMS | NC4: fresh-start == real-game FALSE-AS-SCOPED |
| `GLOBAL.CALIB-LESSON` | Z-AUDIT | a self-consistency check needs a passing calibration case — auditor doctrine |
| `GLOBAL.CERTCORE` | Z-NONCLAIMS | NC1: certified-core real-game claim FALSE-AS-SCOPED |
| `GLOBAL.E1` | Z-NONCLAIMS | NC1/NC2 methodology: E1 confounded, diagnoses not falsifies |
| `GLOBAL.E2-POLICY` | Z-NONCLAIMS | NC2: range-aware policy correctness |
| `GLOBAL.E2-SANITY` | Z-NONCLAIMS | NC2: E2 harness wiring verified |
| `GLOBAL.E2-VERDICT` | Z-NONCLAIMS | NC2: structural-reason hypothesis for the C3 falsification |
| `GLOBAL.F1` | Z-TABLE-FAITHFUL | writes-on finisher unsound — finisher-built tables not faithful |
| `GLOBAL.F2-REMEDY` | Z-TABLE-FAITHFUL | the median build — how a faithful table is generated without the finisher |
| `GLOBAL.FIXPOINT-VS-SEARCH` | Z-TABLE-FAITHFUL | fixpoint (+1) agrees with MIGOS search (+1) under aligned rules |
| `GLOBAL.FP1` | Z-CONVERGE-MONO | Knaster–Tarski monotone map; 3.4 Z-CONVERGE-MONO cites FP1 |
| `GLOBAL.FP2` | Z-NONCLAIMS | NC1: L==H history-independence explicitly NOT a theorem |
| `GLOBAL.FP2-bounded` | Z-NONCLAIMS | NC1: FALSE-AS-SCOPED at 3x2 |
| `GLOBAL.FP2-general` | Z-NONCLAIMS | NC1: INTRACTABLE beyond finite ban sets |
| `GLOBAL.FP3` | Z-CONVERGE-FINITE | 3.4 Z-CONVERGE-FINITE cites FP3 |
| `GLOBAL.H1-CENSUS` | Z-STATE-REACH | 3.3 Z-STATE-REACH cites H1-CENSUS — 51,419,046 reachable triples at 4x4 |
| `GLOBAL.H1-COMPUTABLE` | Z-R-TIE | old long-cycle-tie computation falsified — bears on cycle resolution semantics |
| `GLOBAL.H1-MARKOV` | Z-R-TIE | 3.2 C3's [F]: the constant tie makes the state Markovian — UNTESTED |
| `GLOBAL.H4` | Z-CONVERGE-FIX | FP1 acceptance check 3 residual gaps (lo/hi never checked; 1:37 sample) |
| `GLOBAL.H4a` | Z-CONVERGE-FIX | V0/V1 on the in-memory lo/hi quads — UNTESTED |
| `GLOBAL.H4b` | Z-CONVERGE-FIX | exhaustive stride-1 chainability sweep — discharged by QA-021 |
| `GLOBAL.INVSYM` | Z-SYM | 3.7 Z-SYM cites INVSYM; also C4 under Z-R-SIGN |
| `GLOBAL.LEAK` | Z-NONCLAIMS | NC4: the fresh-start player leaks on PSK histories |
| `GLOBAL.LONGCYCLE` | Z-R-TIE | long-cycle tie semantics falsified at 3x2 — bears on cycle resolution (C3) |
| `GLOBAL.MEMO-XROOT` | Z-TABLE-FAITHFUL | cross-root memo reuse unsound — finisher/memo soundness |
| `GLOBAL.MIGOS-RULE` | Z-TABLE-FAITHFUL | licenses the MIGOS basic-ko anchor as external attestation of the k=1 fresh-start values |
| `GLOBAL.ONEMISMATCH-CURE` | Z-R-TIE | the falsified simple-ko-table cure — bears on cycle-resolution machinery |
| `GLOBAL.P1` | Z-NONCLAIMS | NC2-family: an anchor match does not attest real-game correctness |
| `GLOBAL.P2` | Z-AUDIT | symmetry PASS necessary-not-sufficient — validation doctrine |
| `GLOBAL.P3` | Z-NONCLAIMS | NC4: the fresh-start player does not play the real-game score |
| `GLOBAL.PASS-NOKO` | Z-R-STATE | the D3 invariant's PROVEN parent — passes ≥ 1 ⇒ ko_point = none |
| `GLOBAL.REFRAME` | Z | adopted deliverable scope — the fresh-start-only framing that Z's §1.2 NCs encode |
| `GLOBAL.S1` | Z-STATE-LEGAL | colex bijection; 3.3 Z-STATE-LEGAL cites S1; also D1 under Z-R-STATE |
| `GLOBAL.S2` | Z-R-SCORE | Benson theorem — load-bearing for terminal detection (`is_settled`), the ADR-0006 eye-prune and resign logic; NOT C2 scoring (amended T400) |
| `GLOBAL.S3a` | Z-STATE-LEGAL | move/capture/suicide kernel + legal counts; 3.3 cites S3a |
| `GLOBAL.S4` | Z-R-SCORE | area scoring implementation; 3.2 C2 → Z-R-SCORE |
| `GLOBAL.T06` | Z-NONCLAIMS | NC4: arena baseline leak band 8–18% |
| `GLOBAL.TIE-MIGOS` | Z-TABLE-FAITHFUL | refuted tie explanation licenses the +1 anchor agreement (external attestation) |
| `GLOBAL.Z` | Z | the theorem |
| `QA-001` | Z-CONVERGE-FIX | the one-ply Bellman-identity claim refuted at ko-sensitive slots — [F] of FIX |
| `QA-003` | Z-NONCLAIMS | alias of 4x4.A-2 |
| `QA-004` | Z-TABLE | the root is bracket-valued, not L==H — E3 bracket semantics confirmed |
| `QA-009` | Z-NONCLAIMS | NC2: the E2 leak counts are two runs, not a discrepancy |
| `QA-011` | Z-R-TIE | alias of the H1 pair (both halves Z-R-TIE) |
| `QA-012` | Z-NONCLAIMS | NC1-family: the ko-history dial quantifies residual history-dependence — blocked, UNTESTED |
| `QA-013` | Z-R-TIE | alias of GLOBAL.LONGCYCLE |
| `QA-015` | Z-NONCLAIMS | NC3: the per-goban-independence ruling that became ADR-0016 |
| `QA-019` | Z-TABLE-FAITHFUL | Track A does not escape the bracket-derived finisher premise |
| `QA-021` | Z-CONVERGE-FIX | FP1 check 3 exhaustive on vb/vw — 0 violations outside KO_SENSITIVE |
| `QA-022` | Z-AUDIT | evidence-retrievability refuted — evidence-integrity doctrine |
| `QA-023` | Z-R-TIE | Markovian state-sufficiency under a constant tie — the roadmap's load-bearing claim, UNTESTED-for-want-of-contrast |
| `QA-025` | Z-TABLE-FAITHFUL | alias of GLOBAL.MIGOS-RULE |
| `QA-026` | Z-CONVERGE-FIX | median(L,TIE,H) V-derivation falsified at 3x2 |
| `QA-027` | Z-CONVERGE-FIX | certified fraction 100%-by-construction falsified at 4x4 — the V-derivation, not state-sufficiency |
| `SPRINT-M4a-ACCEPT` | Z-TABLE-CONSISTENCY | A3/A9 internal consistency (A5 round-trip covered separately); scope caveat: not completeness |
| `WZO2-4X4-VALID` | Z-COMPLETE-ENUM | closure untested — the artifact is not a verified perfect oracle |
| `WZO2.I2-CLEAN` | Z-TABLE-CONSISTENCY | I2 colour-inversion exhaustive on both WZO2 artifacts |
| `GLOBAL.Z-R-MOVE-B1-EQUIV` | Z-R-MOVE | B1 shape-rule equivalence lemma (T306, absorbed T337 S4) |
| `CODE.T312-PARALLEL-FIXPOINT` | Z-TABLE-CONSISTENCY | parallel fixpoint solver with race controls (T312, T337 S4) |
| `CODE.WZO2-RELEASESAFE-INV` | Z-TABLE-CONSISTENCY | ReleaseSafe rebuild byte-identical (T313, T337 S4) |
| `CODE.PARALLEL-FIXPOINT-MEASURED` | Z-TABLE-CONSISTENCY | parallel fixpoint speedup measurement (T314, T337 S4) |
| `GLOBAL.I5-SCC-CONTAIN` | Z-STATE-REACH | I5 SCC cycle-reachability containment passes at 3x2/4x3/4x4 (T344, STANDING-ABSORB 2026-08-05) |
| `4x4.NEW-ENGINE-MIRROR` | RETIRED | family player (§2.3): T375 mirror measurement — new engine vs its own table's brackets, engine-play consistency; serves L3, not the theorem (T384) |
| `4x4.THIRD-PARTY-ZERO` | RETIRED | family player (§2.3): T381 third-party cross-check (GNU Go/Pachi/Fuego); engine-play measurement, serves L3, not the theorem (T384) |
| `4x4.BRACKET-NOT-KO` | Z-TABLE | T380 Q4/F-5: brackets not predominantly ko-derived — bracket-vs-ko-shape correlation census over the whole 4x4 table; evidences bracket semantics (T384) |
| `4x4.KO-CLUSTER-MAX-2` | Z-R-MOVE | T380 Q3/F-4+F-9: max independent ko clusters = 2 (4x4, 4x3) — census under the production ko-shape definition, the B1/B2 family (T384) |
| `GLOBAL.PATHOLOGY-GRADIENT` | Z-NONCLAIMS | T382: pathology is a gradient, no defensible threshold; smallest realistic-ko board 3x2 — NC1 family (history dependence across sizes, siblings 2x2.T12/3x2.T13) (T384) |
| `CODE.I5-INSTRUMENT-ADJUDICATION` | Z-AUDIT | T391: I5 instrument pair adjudicated — vb_graph defects A/B, vb_scc_4x4 Defect C (fabricated the "24 natural violations"); instrument-validity family, sibling 3x2.I5-CAL (T396) |
| `CODE.INSTRUMENT-COVERAGE` | Z-AUDIT | T388: instrument coverage map + nine divergences (D1–D9); which instrument runs which check at which size — instrument-validity family (T396) |
| `3x3.BRACKET-NOT-KO` | Z-TABLE | T385 corr3x3: 93.8% of 3x3 bracketed entries ko-free anywhere; SCC membership and ko-reachability fail to predict the bracket — evidences bracket semantics (E3), mirror of 4x4.BRACKET-NOT-KO (T396) |
| `4x4.SELF-PLAY-BRACKET-CONSISTENT` | RETIRED | family player (§2.3): T389 self-play trajectory consistency — the engine honours its own brackets at engine-chosen plies (0/1027, 0/1191, 0/1161); engine-play measurement, serves L3, not the theorem (T396) |
| `GLOBAL.PSK-GRAFT-COHERENT` | Z-TABLE | T386/ADR-0021: PSK graft coherent — diverges from the fixpoint only at L<H, never at L==H, never outside [L,H]; evidences bracket semantics and the cycle-resolution route (T396) |
| `GLOBAL.LIFE-CERTIFIES` | Z-TABLE | T393: alive chains never co-occur with a non-T bracket — unconditional life certifies L==H in the stored tables; evidences bracket/certification semantics (T404) |
| `GLOBAL.TWO-LIFE-ONSET` | Z-R-SCORE | T393: coexisting unconditional life begins at 4x3 (2/321,689), 324 at 4x4 — Benson-alive census completing the T382 zero-alive series (T404) |
| `3x3.LIFE-NO-CENTRE` | Z-R-SCORE | T393: unconditional life at 3x3 exists without a centre stone (206/1,766, diamond) — Benson aliveness at 3x3, sibling of 3x3.S2-impl (T404) |
| `GLOBAL.CAPTURE-BUDGET-DAG` | Z-CONVERGE-FINITE | T387: capture budget makes the move graph acyclic (0 back-edges at 3x3/4x3 B=8, control fires) — the budgeted game's value iteration is finite; says nothing about Bellman consistency (T404) |
| `GLOBAL.ROOT-SINGLE-IFF-FORCIBLE-LIFE` | Z-TABLE | T394: root single-valued iff canForceLife (5/5 sizes) — evidences when the bracket collapses at the root; 4x3 root [4,12] not independently audited (T404) |
| `GLOBAL.DRAWLOOP-CONFINED` | Z-TABLE | T394: draw-by-loop confined to the neither-can-force class (exact ≤3x3; 98.95% at 4x4, witnessed exceptions) — bracket/draw structure; converse NOT a draw certificate (T404) |
| `GLOBAL.NEITHER-FORCE-MOSTLY-DECISIVE` | Z-TABLE | T394: neither-can-force class is mostly decisive (85.3% at 4x4) — decisive-vs-draw structure, refutes draw-pruning framing (T404) |
| `CODE.PROPERTY-OWNERSHIP` | Z-AUDIT | T395: one production implementation per property, differential per surviving pair, seeded-defect controls red-then-green — instrument discipline (T404) |
| `3x3.OPTIMAL-CYCLE` | Z-R-TIE | T416: the optimal-move subgraph CONTAINS-CYCLES at 3×3 — exhaustive, 54 cyclic SCCs, 12 FORCED — cycle resolution (C3) is load-bearing under optimal play; value constant on all 54 cycles (0 bad); not a real-game claim (T418) |
| `4x4.OPTIMAL-CYCLE` | Z-R-TIE | T416: sampled positive — cycles exist at 4×4 (6 SCCs in the declared 150,001-node / ≈0.15% sample); '0 forced in the sample' is a lower bound, not a general negative; sibling of 3x3.OPTIMAL-CYCLE, per-goban independence (T418) |
| `3x3.LOOPY-TAXONOMY` | Z-R-TIE | T419: full loopy-child partition at 3×3 — exhaustive over 47,456 non-terminal parents; optimal play declines reachable loops at 9,480 of 15,008 loopy-holding positions (63%), depth-3 forced 3,656 ≥ T416's 80 forced-cycle states — how often cycle resolution (C3) is load-bearing under optimal play; sibling of 3x3.OPTIMAL-CYCLE (T422) |
| `4x4.LOOPY-TAXONOMY` | Z-R-TIE | T419: loopy-child partition on T412's declared 200,000-sample of 98,616,794 — 23,459 decline-reachable loops, depth-3 forced 4,867 is a sample lower bound; sampled census of when cycle resolution (C3) matters under optimal play; sibling of 4x4.OPTIMAL-CYCLE, per-goban independence (T422) |
| `CODE.RESOLVER-INTERFACE` | Z-AUDIT | ADR-0022: pluggable resolver interface, none authoritative — instrument architecture (T402, absorbed T418) |
| `CODE.RESOLVER-BUDGET-QUARANTINE` | Z-AUDIT | capture budget demoted to a named pluggable resolver whose registration metadata records its measured non-convergence — instrument validity; sibling GLOBAL.CAPTURE-BUDGET-DAG; CLAIMED not PROVEN at absorption (T402, absorbed T418) |
| `CODE.RESOLVER-CONTROLS` | Z-AUDIT | harness null + seeded controls fire at all 23,420 3×3 positions — instrument-control discipline, re-verified at absorption (T402, absorbed T418) |
| `GLOBAL.REACH-P4-CENSUS` | Z-STATE-REACH | T507: reachable (board, side, ko, passes) state census at all solved sizes — totals 258 / 2,586 / 73,758 / 1,929,038 / 147,638,298; cross-checks WZO2 headers + t386 + an independent Python re-implementation; evidences state-reachability (3.3 Z-STATE-REACH), the L7 sizing datum |

## 2. Adopted retirements — 132 rows moved to archives/register/, by family

**ADOPTED 2026-08-06 (T373, executing `docs/epistemic/register-triage-2026-08-04.md`;
Orchestrator ruling 2026-08-05).** 132 rows — 106 ARCHAEOLOGY + 16 NOTE + 10 BOGUS —
moved out of the live register into `archives/register/` in full, with epitaphs
("archive, never delete"). 122 of them carried the `RETIRED` disposition here; the
10 BOGUS rows were mapped to nodes (they are the falsified-foundation family in the
archive — the finisher soundness chain). The family tables below list the moved rows;
the prose epitaphs live in `archives/register/families/`. Nothing was deleted; the
live register went 339 → 207.

### 2.1 ruleset-choice — 21 rows

Evidences the choice of ruleset R (k=1 basic ko over PSK / score-on-cycle / bounded-history options) by foreclosing the alternatives. The foreclosures are recorded decisions (AGENTS.md, AXIOMS.md §4), not requirements of Z under the fixed R; no tree node states them. Propose retirement; the human rules.

| ID | note |
|---|---|
| `2x2.R1` | 118,475,182 ban-set states |
| `2x2.R3` | kill-50 at 2x2 |
| `3x2.R1` | 116,114,272 states |
| `3x2.R3` | kill-50 at 3x2 |
| `4x3.S3b` | PSK-history ko-legality at 4x3 |
| `4x4.KO-RULE-NULL` | PSK binding rate in two games — evidences the k=1 choice |
| `4x4.R1` | structural; measured at 2x2 |
| `4x4.R3` | kill-X% census |
| `4x4.S3b` | PSK-history ko-legality at 4x4 |
| `GLOBAL.ADR0004-P1` | superko-era finiteness rationale; the k=1 game is finite by construction (D1) |
| `GLOBAL.ANCHOR-DELTA` | PSK-era anchor reconciliation; superseded by the k=1 anchor agreements (BASICKO-TIE rows) |
| `GLOBAL.PSK-GAP` | transitional statement about the old PSK artifact |
| `GLOBAL.R1` |  |
| `GLOBAL.R2` | score-on-cycle ≡ PSK intractability |
| `GLOBAL.R3` | kill-X% foreclosure |
| `GLOBAL.RNPLY-FORBID` | forbid-only N-ply does not terminate |
| `GLOBAL.RPLY` | exact N-ply superko sweep intractable |
| `GLOBAL.RPLY-RETRO` | bounded-history retrograde route |
| `GLOBAL.RPLY-TRAP` | bounded-history score-on-cycle trap |
| `GLOBAL.S3b` | ko-legality under PSK history — evidences the k=1 choice, not a requirement under R (the k=1 ko legality is B1 → Z-R-MOVE) |
| `QA-024` | PSK binding rate — evidences the k=1 choice |

### 2.2 old-artifact — 45 rows

Measured or diagnosed the old writes-on PSK-era artifact(s). The theorem's table requirements are verified on the k=1 builds by the acceptance battery (I2/A2/A3/A5/A8/A9) and the Bellman-identity checks, not by this measurement. Historical record; no tree node. Propose retirement; the human rules.

| ID | note |
|---|---|
| `2x2.M4` |  |
| `3x2.M4` |  |
| `3x3.ANCHOR` | finisher-era anchor verification |
| `3x3.BRACKET` |  |
| `3x3.M1` |  |
| `3x3.M4` |  |
| `4x3.BRACKET` |  |
| `4x3.M1` |  |
| `4x3.M3` | writes-on solve cost — old generation |
| `4x3.M4` |  |
| `4x3.TANGLE` |  |
| `4x4.ANCHOR` | +2 anchor is a different game's value; superseded by the TIE-MIGOS adjudication |
| `4x4.BRACKET` | old root bracket [−6,+16]; the k=1 root bracket is in 4x4.BASICKO-TIE → Z-TABLE |
| `4x4.COMPLETE-2026-07-21` | the retracted completeness claim |
| `4x4.CYCLE-INSENS` | cycle-insensitivity claim refuted by the +1-vs-+2 gap |
| `4x4.KO-CENSUS` | single-ko census of the old artifact — generation-strategy input |
| `4x4.M1` | 21.32% ko-sensitive exhaustive on the old checkpoint |
| `4x4.M3` | finisher cost on the writes-on config — old generation |
| `4x4.M4` | 21.27% ko-sensitive, 4.08% misprice — the most-cited old-artifact datum |
| `4x4.M5` | old-artifact root-bracket/player diagnostic (16/19 plies flagged) |
| `4x4.M6` | writes-off misprice halving on old artifacts |
| `4x4.M6-EXCESS` | the ADR-0013 excess on old artifacts |
| `4x4.M6-FLOOR` | definitional floor on old artifacts |
| `4x4.M6-SCREEN` | misprice screen for old artifacts |
| `4x4.PARALLEL` | parallel checkpoint artifact |
| `4x4.SINGLE` | old single-score fraction |
| `4x4.TANGLE` | old width-32 bracket count |
| `4x4.VALBATTERY` | 2026-07-21 validation of the retracted COMPLETE artifact |
| `4x4.WRITESOFF` | uncommitted writes-off checkpoint state |
| `CODE.ADR0011-DTT` | DTT best-effort on WZO1 — play-time aid on the old format |
| `CODE.WZO1-DTT-UNSET` | DTT column never computed on WZO1 — play-time aid, old format |
| `CODE.WZO2-CHAINSHORT` | chainability instrument short-circuit — SUPERSEDED; crisis diagnostic |
| `GLOBAL.C-1` | transient chainability-violations attribution — crisis diagnostic |
| `GLOBAL.CHAIN-DEF` | chainability definition — used only by the retired crisis diagnostics |
| `GLOBAL.CHAIN-KIND` | definitional-in-kind analysis of old-artifact violations |
| `GLOBAL.CHAIN-KO` | ko-sensitive region not chainable — old-artifact diagnostic |
| `GLOBAL.CHAIN-LH` | L==H chainability measured on old artifacts |
| `GLOBAL.MAXGAP` | worst misprice = 2n regularity on old artifacts |
| `GLOBAL.T14.1` | 2026-07-27 bracket-only artifact — historical |
| `QA-005` | KO_SENSITIVE-flag semantics on the old artifact |
| `QA-006` | definitional-vs-excess violations — old-artifact M6 family |
| `QA-007` | alias of 4x4.M6-EXCESS |
| `QA-008` | writes-off checkpoint completion — old-artifact family |
| `QA-016` | parallel checkpoint cannot state the answer — old artifact |
| `QA-017` | engine steers into the unchainable region — crisis diagnostic |

### 2.3 player — 24 rows

The GTP player and play-time search are consumers of the table; the theorem asserts nothing about them. No tree node. Propose retirement; the human rules.

| ID | note |
|---|---|
| `4x4.A-1` | PSK-era causal attribution corrected to the player defect |
| `4x4.A-3` | fresh-start-perfect player claim — player-side scope correction |
| `4x4.GREEDY-BIAS` | greedy extremum bias — player-side |
| `4x4.GTP-DEFECT` | player move rule undefined at 4x4 — a consumer defect |
| `4x4.HISTPERF-CHEAP` | play-time history-perfect search feasibility — player-side |
| `4x4.REGR-CLIFF` | ply-16 collapse — old-artifact/player diagnostic |
| `4x4.REGR-SYM` | regression games identical up to mirror — player diagnostics |
| `CODE.GTP-LHSIDE` | wrong-side bracket display — display-path defect, player/telemetry |
| `CODE.UNDEF` | UNDEF sentinel convention for incomplete checkpoint artifacts; the k=1 table is complete by construction |
| `GLOBAL.ADR0009-DTT` | DTT = fastest optimal resolution — a play-time aid, not a theorem requirement |
| `GLOBAL.ADR0014-DEAD` | scoring-UI heuristics — consumer-side; the theorem's scoring is Benson-exact (Z-R-SCORE) |
| `GLOBAL.B-1` | ADR-0013 consequences bullet on the history-perfect genmove — player-side |
| `GLOBAL.H2` | greedy-player loss-rate ordering — player-side |
| `GLOBAL.H3` | play-time history-exact search affordability — player-side |
| `GLOBAL.H3-LOWERBOUND` | search performance lower bound — player-side |
| `GLOBAL.H5` | player fix without resolving open questions — consumer-side |
| `GLOBAL.H5a` | chainable-region steering — player-side |
| `GLOBAL.H5a-CHILD` | child-side identity check — player-side |
| `GLOBAL.H5a-FALLBACK` | history-free fallback — player-side |
| `GLOBAL.H5b` | history-exact search to settled horizon — player-side |
| `GLOBAL.H5d` | bounded-history route to a real-game claim — future work, not a requirement of this Z |
| `QA-002` | alias of 4x4.A-3 |
| `QA-014` | per-node Bellman check for the player — consumer-side |
| `QA-020` | self-certification rate — player-side |

### 2.4 process — 14 rows

Process rule, user decision, or superseded-status record; not a theorem requirement. No tree node. Propose retirement; the human rules.

| ID | note |
|---|---|
| `CODE.STANDING-ABSORB` | kanban standing-trigger mechanism — infra |
| `CODE.STANDING-C3-DEAD` | dead standing trigger — infra |
| `CODE.STANDING-STATE-FRAGILE` | standing priors lost on kanban writes — infra |
| `CODE.WZO2-UNRUN` | SUPERSEDED status record — the artifact has since been built |
| `GLOBAL.ONEWRITER` | one-writer-per-engine-file rule — process |
| `GLOBAL.RELEASEFAST` | ReleaseSafe discipline — measurement methodology, process |
| `GLOBAL.UD-1` | user decision record |
| `GLOBAL.UD-2` | user decision record |
| `GLOBAL.UD-3` | user decision record |
| `CODE.MANAGENT-MODEL-VALIDATION` | canonical model label validation in managent — infra (T317, T337 S4) |
| `CODE.MANAGENT-LOST-UPDATE` | lost-update safety in store — infra (T317, T337 S4) |
| `CODE.MANAGENT-AMEND` | append-only amendment path — infra (T317, T337 S4) |
| `CODE.MANAGENT-ARCHIVE` | kanban archive command — infra (T319, T337 S4) |
| `CODE.REGRESSION-WIRING` | orphaned regression scripts wired — infra (T322, T337 S4) |

### 2.5 design — 14 rows

Design rationale for the engine or a 5xN scaling projection; the theorem's requirements hold or fail independently of it. No tree node. Propose retirement; the human rules.

| ID | note |
|---|---|
| `4x4.DRIVER` | finisher driver saga — old generation design |
| `GLOBAL.ADR0002-SEQ` | collision-size bounds for 5×5 forward search — out of scope |
| `GLOBAL.ADR0005-SUBBOARD` | search-method foreclosure (full-goban only); the state IS the full goban by D1 |
| `GLOBAL.ADR0007-AB` | alpha-beta cannot populate an oracle — method rationale |
| `GLOBAL.ADR0007-BACKEDGE` | captures create back-edges — why the fixpoint iterates; convergence stands on FP1/FP3 |
| `GLOBAL.ADR0009-SUCC` | successor-sweep propagation — design rationale |
| `GLOBAL.ADR0012-5X5` | 5×5 feasibility projection — out of Z's goban scope |
| `GLOBAL.ADR0012-LAYER` | 5×N layer size — out of Z's goban scope |
| `GLOBAL.ADR0012-V1` | V1 recomputed inline — RAM-lean design rationale |
| `GLOBAL.F4-COST` | memory-for-reuse tradeoff — 5xN scaling projection, out of Z's goban scope |
| `GLOBAL.FIN-BRACKET` | bracket cutoffs collapse the finisher — finisher-era design |
| `GLOBAL.FIN-NEARTERM` | plain finisher rescues near-terminal slots — finisher-era design |
| `GLOBAL.FWD-INTRACT` | forward filling intractability — method rationale |
| `GLOBAL.SWEEPS` | sweep-growth/ko-fraction trend — a 5xN projection input |

### 2.6 crisis-diagnostic — 3 rows

Crisis-era diagnostic framing, refuted hypothesis, or withdrawn option; its role is historical. No tree node. Propose retirement; the human rules.

| ID | note |
|---|---|
| `GLOBAL.ONEMISMATCH-DIAG` | organising interpretation, not a theorem |
| `QA-010` | alias of GLOBAL.ONEMISMATCH-DIAG |
| `QA-028` | Reading-A history-window ladder — withdrawn |

### 2.7 absorption — 1 row

New-absorption measurements folded in by the standing pass; a consumer with no tree node.

| ID | note |
|---|---|
| `GLOBAL.SYM-FOLD` | symmetry-fold census over the raw 3^n space — legal AND illegal (T359, STANDING-ABSORB 2026-08-05) |

### 2.8 falsified-foundation — 10 rows

Claims whose foundation was falsified (the triage's BOGUS class): they were mapped to
nodes, not `RETIRED`, and the mapping could not say what the register now says — the
foundation fell. Full epitaphs in `archives/register/families/falsified-foundation.md`.

| ID | note |
|---|---|
| `3x3.C1` | fresh-start correctness at 3×3 — foundation falsified (d:GLOBAL.F2 → GLOBAL.C3) |
| `4x3.C1` | fresh-start correctness at 4×3 — foundation falsified (d:GLOBAL.F1) |
| `GLOBAL.F2` | bracket-guided finisher sound — ADR-0015 refutes the justification (D-5) |
| `GLOBAL.ADR0010-CUT` | bracket cutoffs valid under any ban set — ADR-0015 supersedes |
| `GLOBAL.F3` | writes-off finisher sound — rests on the falsified bracket validity |
| `GLOBAL.F4` | KM dependency-guarded memo sound — parent GLOBAL.F3 fell |
| `GLOBAL.H5c` | bracket-cut search sound — cutting under real history IS claim C3 |
| `GLOBAL.ADR0012-GATE` | sha256 gate — target was the retracted COMPLETE artifact |
| `GLOBAL.B15` | Track A regen byte-identical — action stands, premise fell |
| `QA-018` | alias of GLOBAL.F2 — the orphan stands (ADR-0017/0018) |

## 3. Row counts — the denominator bar

| surface | count | produced by |
|---|---|---|
| register rows | **228** | `bin/weizigo-claimlint` C0 (`rows parsed: 228`) — live count on every run, after T373's triage adoption (was 339) + 10 T384/T396 absorptions + 8 T404 absorptions + 5 T418 absorptions + 2 T422 absorptions |
| mapping rows (this doc §1) | **228** (225 mapped to a node + 3 RETIRED) | claimlint C9 cross-check (row set equality) |
| moved rows (§2) | **132** (122 RETIRED + 10 BOGUS) | same run + the triage sheet's classification |
| unmapped without disposition | **0** | C9a (empty/invalid `tree` cell fails the run) |

### 3.1 Retirement count — four-way reconciliation (T318, 2026-08-03)

The retirement count was reported three different ways by the Orchestrator on 2026-08-03.
Re-measured against the ground truth (the table itself), all four sources agree at **116**. Each
figure is printed with the command that produced it; a count without its command is not a
measurement.

| source | figure | command (run from repo root) |
|---|---|---|
| §2 header line | **116** | `grep -oE "Proposed retirements — [0-9]+ rows" docs/epics/E1-markovian/register-tree-map.md` |
| sum of the six §2.x family subtotals | **116** (21+45+24+9+14+3) | `grep -oE '^### 2\.[0-9]+ [a-z-]+ — [0-9]+ rows' docs/epics/E1-markovian/register-tree-map.md` |
| actual `RETIRED` cells in the §1 table | **116** | `awk '/^## 1\./{f=1} /^## 2\./{f=0} f' docs/epics/E1-markovian/register-tree-map.md \| grep -cE '^\|.*RETIRED'` |
| `findings/T305-tree-map.json` structured `tree_map` | **116** | `python3 -c "import json; d=json.load(open('findings/T305-tree-map.json')); print(sum(1 for v in d['tree_map'].values() if v['tree']=='RETIRED'))"` |

**Which was wrong and why.**

- The **“117”** figure (reported as “actual `RETIRED` cells in the §1 table”) was a measurement
  artifact, not a content error. It came from the *unscoped* command `grep -c '^\|.*RETIRED'
  <file>` (BSD grep reads `\|` as a literal pipe), which matches **116** §1 table cells **plus one
  §3 prose row** — line 538, `| mapping rows (this doc §1) | **323** (207 mapped to a node + 116
  RETIRED) | …`, which contains the word `RETIRED` inside a prose cell. Scoped to §1 (the `awk`
  command above), the count is 116. The §1 table content was always 116; nothing in the table
  needed changing.
- The **“118”** figure lived only in the `notes` prose string of `findings/T305-tree-map.json`.
  The structured `tree_map` object in that same file has exactly **116** entries with
  `tree == "RETIRED"`. The 118 was a prose typo with no structural backing; T318 corrected the
  `notes` string to 116 (see the correction note appended to that field).
- The §2 header (**116**) and the six §2.x family subtotals (**116**) were correct as written;
  no edit was needed to either.

**The whole-file `grep -c RETIRED` trap — do not “fix” it back.** `grep -c RETIRED
docs/epics/E1-markovian/register-tree-map.md` over-counts the table cells because the word
`RETIRED` also appears in prose. Before T318’s reconciliation block was added, the whole-file
count was **119** = 116 §1 table cells + 3 prose mentions: (a) the vocabulary description at
line 22 (`a known node or a disposition marker (\`RETIRED\`)`), (b) the §2 lead at line 372
(`The register column carries \`RETIRED\` for each`), and (c) the §3 row at line 538
(`207 mapped to a node + 116 RETIRED`). The T318 brief’s own “117” came from subtracting only
two of these three (it missed the line-538 §3 row) — which is exactly what produced the bogus
figure. After T318 this reconciliation block itself adds several more prose mentions of
`RETIRED`, so the whole-file count is now higher than 119 and is meaningless as a cell count.
**The robust table-cell count is the §1-scoped command above = 116**, not the whole-file
count; do not reduce 116 to match any whole-file number.

No row’s mapping or retirement proposal was altered to make the arithmetic work; the four
sources already agreed at 116 once the two measurement errors above were corrected.

## 4. Discrepancies found while mapping (tree vs register)

1. **AXIOMS §3.2 Z-R-MOVE enumerates `A1–A5, B1–B3` but not A6** (`GLOBAL.AXIOM-FORCEDPASS`, added
   Amendment 3). This mapping places A6 under Z-R-MOVE; the tree text needs an amendment.
2. **E1–E3 have no home in §3.2** — see the conventions above; AXIOMS should place them explicitly.
3. **B2/B3 grouping: the tree lists them under Z-R-MOVE, the register's dependents columns say
   Z-R-STATE (B2) and Z-R-TIE (B3).** This mapping follows the tree; the discrepancy is recorded
   for adjudication, not silently resolved.
4. **`GLOBAL.BATTERY-GAPS` spans six nodes** (G1 Z-R-STATE, G2 Z-STATE-REACH, G3 Z-STATE-KEY,
   G4 Z-TABLE-ROUNDTRIP, G5 Z-CONVERGE-SEED, G6 Z-CONVERGE-MONO); the column carries its primary
   (Z-AUDIT, the battery's coverage as an instrument); the six are listed here so the coverage
   statement survives.

## 5. Tree nodes with no row — new work

What the theorem needs that nobody has evidenced yet. These are the honest gaps; the brief's
point 3 is this list. (Nodes whose children fully cover them — Z-STATE, Z-CONVERGE, Z-TABLE,
Z-COMPLETE — are covered by their children and are not listed.)

1. **Z-R — joint well-definedness.** No row asserts the axioms *collectively* define a
   self-consistent, computable ruleset. Its [F] — 'a position where two interpretations of the
   axioms disagree on legality' — is not mechanized anywhere. Closest seed: T273's differential
   ko run (one function, one transcription family); the seventeen-copy comparison AXIOMS §2
   promises is not what T273 delivered (phase0-execution-audit F4).
2. **Z-STATE-KEY under adversarial move selection.** `CODE.KEY-AGREEMENT`'s own caveat:
   first-legal-move self-play under-covers cycle-intensive ko positions; full four-component
   key parity under adversarial selection is unverified.
3. **Z-CONVERGE-SEED at 2×2/3×2/3×3.** The only seeding row is `4x4.FP1-C1` and it is UNTESTED;
   the other sizes have no seeding-provenance evidence. Accepted as a gap (G5) by
   `GLOBAL.BATTERY-GAPS`, but still: no row evidences it.
4. **Z-R-TIE's Markovian-sufficiency test.** `QA-023`'s C1 (state-sufficiency) is
   UNTESTED-for-want-of-contrast — the history generator misses the shortest arrival in 93% of
   states (2B-3-AUDIT). The node's [F] (a state where Markovianity fails) is untested.
5. **Z-COMPLETE-ENUM at 4×4 — closure under the kernel move generator (C-A1/C-A2).**
   `WZO2-4X4-VALID` states closure is untested; `GLOBAL.BATTERY-GAPS` G2 is the same gap.
6. **Z-AUDIT / Z-TABLE-FAITHFUL at 4×4 on the k=1 build.** The #2 auditor on a completed
   writes-off 4×4 regen is still owed (`4x4.F3`, `4x4.D3` UNTESTED; T274's residue 'our own +1
   still awaits the #2 auditor').

## 6. What T305 did not do

- Did **not** add a claimlint check to anything but the tree-mapping convention: `src/claimlint.zig`
  gained C9 (parse the 11th column, cross-check this document); no other check changed; C1a/C1b/C2/C6
  counts are unchanged (floor not raised).
- Did **not** change any row's status, evidence, or edges. The `tree` column is additive, per §1's
  additive-column convention.
- Did **not** delete or edit any retired row; retirement is proposed here for the human to rule.

## 7. Disposition of the brief's bars

- Row count in the mapping == row count in CLAIMS.md: **323 == 323**, produced by claimlint C0 and
  enforced by C9 (both printed on every run).
- Zero unmapped rows without a disposition: C9a fails the run on an empty/invalid `tree` cell; the
  count is 0.
- claimlint at or below floor, calibration PASS: verified at close; C9 added to the floor at 0.
- `zig build test` green: verified at close.
