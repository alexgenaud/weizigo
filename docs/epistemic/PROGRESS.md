Task: NARRATIVE-LAYER · Role: worker · Model: DSPro/T127 · Date: 2026-07-31

**Refreshed 2026-07-31 by T127 to absorb the T100–T126 wave** (32 tasks, 7 models).
T129 (EXP-7 4×4, QA-027 falsified) absorbed 2026-07-31 by Fable/Consul.
Every load-bearing sentence carries `[ID:STATUS]`, verified by `bin/weizigo-claimlint` C6.

# The Through-Line — what weizigo tried, what failed, what's open, and what it means

**This file is the durable narrative hub.** It tells the story once, in order,
cite-tagged against `docs/epistemic/CLAIMS.md`. Every load-bearing sentence
carries an inline citation `[ID:STATUS]`, mechanically verified by
`bin/weizigo-claimlint` check C6. A reader who knows nothing about the project
can read this one file and learn what is known, what was tried, what failed,
what is open, and what it means.

**The other files:**
- `CLAIMS.md` — the ledger: every claim, its status, its evidence, its dependency edges. Machine-readable and machine-checked. This is where a status changes; this file only reflects those changes.
- `CURRENT.md` — retired 2026-08-03 (T286); the resume surface is `bin/managent resume`, composed at read time (`docs/infra/resume-surface.md`).
- `HANDOVER.md` — session continuity between agent shifts.
- `knowledge-ladder.md` — a PROPOSED framework separating epistemic strength from rule fidelity (not yet adjudicated by the user).

---

## 1. The project and the goal

`weizigo` set out to build a **provably-correct solver for small Go gobans** —
a position-to-score table giving the game-theoretic score of every legal
position for either side to move, built by retrograde value iteration, then
extended to larger gobans. The target was *provable knowledge*: not the
strongest player, not the best heuristic, but a verified account of the game
under a stated ruleset.

The rules: **Chinese (area) scoring, komi 0** `[GLOBAL.ADR0003-AREA:PROVEN]`.
Scores are Black-positive `[GLOBAL.INVSYM:PROVEN]`. The generation rule —
the rule the solver solves under — is **positional superko (PSK)** for the
existing artifacts and a **new-rule build** (basic ko + fixed-value tie) for
the intended near-term deliverable `[GLOBAL.REFRAME:CLAIMED]`.
Play-time can enforce any ko rule; the generation rule is chosen for
tractability, not fidelity `[GLOBAL.PSK-GAP:PROVEN]`.

Each goban size is its own epistemic universe `[GLOBAL.ADR0016-INHERIT:CLAIMED]`.
A result at 2×2 says nothing about 3×3 unless a monotonicity theorem is
provided — and none exists in this project.

---

## 2. The foreclosures — what was tried and proved intractable

The project did not start with basic ko. It started with positional superko and
worked downward, foreclosing candidates by measurement. Each foreclosure below
is a **measured result about the problem**, not a failure of imagination.

### 2.1 Positional superko is intractable for exact solve `[GLOBAL.R1:PROVEN]`

Exact PSK solving — storing every encountered goban position in the memo key to
distinguish identical positions reached via different histories — exceeds a
200M-node budget even on the **empty** 2×2 board: 118,475,182 ban-set states
at 2×2 `[2x2.R1:MEASUREMENT]`, 116,114,272 at 3×2 `[3x2.R1:MEASUREMENT]`.
The state-space explosion is not a conjecture; it is measured. PSK was
abandoned as the generation rule on 2026-07-24 `[GLOBAL.PSK-GAP:PROVEN]`.

### 2.2 Score-on-cycle is equivalent in hardness `[GLOBAL.R2:PROVEN]`

An alternative to PSK: let the game loop, and resolve the score on a cycle to
reflect which side has more at stake. The state counts are **byte-identical**
to PSK: 118,475,182 at 2×2, 116,114,272 at 3×2. This is not a coincidence; it
is a structural equivalence — the cycle terminal drags the whole history back
into the memo key `[GLOBAL.RPLY-TRAP:PROVEN]`. No free lunch.

### 2.3 Bounded N-ply superko is intractable for every N `[GLOBAL.RPLY:PROVEN]`

The RETRO_PLY probe tested every N from 1 (basic ko) up through PSK on exact
solving from the empty goban at 2×2 and 3×2. Every row hit the 200M-node
budget. Bounded-history N-ply is bounded only for *legality*; the score
terminal re-introduces the full history into the key. A forbid-only variant
(ban the last N positions, no cycle scoring) does not terminate — a cycle
longer than N remains legal `[GLOBAL.RNPLY-FORBID:PROVEN]`.

### 2.4 kill-X% made the ko-sensitive region worse `[GLOBAL.R3:FALSE-AS-SCOPED]`

kill-X% was tested as a ko-sensitive-region shrinker: rule a group dead if it
cannot live in more than X% of continuations. At 4×4 the ko-sensitive fraction
went from 21.32% to **25.01%** as the threshold dropped from 50% to 30%
`[4x4.R3:PROVEN]`. Reducing the threshold *expanded* the region whose value
was uncertain. kill-X% remains an optional play rule only.

---

## 3. The shipped oracle is not a real-game oracle

The project shipped a 4×4 position-to-score table, compared it to published
anchors, and claimed success. The table is a **fresh-start oracle**: it stores,
for each position, the game-theoretic score under optimal play *from an empty
history* (C1: definition, not itself a testable claim — its per-goban rows `[2x2.C1:PROVEN]` `[3x2.C1:PROVEN]` carry the verification). It does not store, and cannot store, the score
under the real PSK history of a game in progress.

### 3.1 C2 — the single-score region is not history-independent `[GLOBAL.C2:FALSE-AS-SCOPED]`

The L==H region — where the least and greatest fixpoints agree, covering
~66–79% of slots depending on goban size — was called the "certified core"
and claimed to be history-independent. **T13 falsified this at 3×2**
(2026-07-26; re-implemented and reproduced 2026-07-30 by T110): 154 of the
508 reachable L==H slots (30.3%, over 132 distinct positions) have at least
one reachable PSK history whose exact value differs from the stored fresh-start
value — 4,432 falsifying (slot, history) pairs of 134,504 tested, with
0/540 fresh-start sanity mismatches. The original 2026-07-26 run sampled one
history per slot and recorded 12 of these; the correct order-independent
measurement is 154 (30.3%) `[3x2.T13:PROVEN]`.
The L==H scores are fresh-start exact (C1), not real-game exact. The
"certified core" framing is withdrawn `[GLOBAL.CERTCORE:FALSE-AS-SCOPED]`.

### 3.2 C3 — the bracket does not bound the real-game score `[GLOBAL.C3:FALSE-AS-SCOPED]`

The [L,H] bracket was claimed to bound the real-game score under any arrival
history. **E2 falsified this at 3×3**: a range-aware self-play policy leaked
in 25 of 4,000 games (0.625%), with a worst-case 12-point leak — the player
promised +3 and delivered −9, outside the bracket entirely
`[3x3.C3:PROVEN]`. An independent replication produced the same rate on 8,000
games `[3x3.E2-RUN2:MEASUREMENT]`. C3 is falsified at 3×3.

### 3.3 C4 — fresh-start ≠ real-game `[GLOBAL.C4:FALSE-AS-SCOPED]`

C4 is false by construction on ko-sensitive (L<H) positions: a fresh-start
value is defined under an empty history, and a real PSK game carries a
nonempty ban set. The fresh-start player leaks 8–18% of games even on
proven-correct 2×2/3×2 tables `[GLOBAL.T06:MEASUREMENT]`. On 4×4 the clean
leak rate (excluding games touching unfilled slots) is 3.4%, max 32 pts
`[4x4.B43:MEASUREMENT]`.

### 3.4 The bracket premise is orphaned `[GLOBAL.F2:CLAIMED]` `[QA-018:CLAIMED]`

The bracket-guided finisher (ADR-0010) — the forward search that fills
ko-sensitive slots by cutting on [L,H] — rests on the claim that the bracket
holds under *any* arrival history. That claim **is** C3, which is
FALSE-AS-SCOPED at 3×3. The orphan was confirmed by ADR-0015 (2026-07-28):
for an empty-goban root, the finisher's own search path *is* a real game line,
so E2's falsifying histories are within the family ADR-0010 claims to cover.
ADR-0017 (2026-07-29) attempted to refute ADR-0015 and **failed** — T13's 12
pointwise mismatches at 3×2 ride exactly the finisher's search-shaped histories.
A three-seat blind review (QA-018-REVIEW, 2026-07-29) returned **unanimously**
that ADR-0017's verdict is sound `[GLOBAL.ADR0015-BURDEN:CLAIMED]`. ADR-0018
confirmed: the finisher remedy is a new task, not a brackets-off regen — a
brackets-off regen inherits the same premise through CERTCORE-dependent seeds.

**Consequence: every shipped ko-sensitive value in the PSK checkpoint is untrustworthy.** The 4×4 "+2"
anchor, every bracket value, and every ko-sensitive column in every PSK artifact
was produced by a finisher whose soundness premise is orphaned. The 4×4
PSK checkpoint (`data/oracle-4x4.checkpoint.wzo`) remains the only 4×4 PSK artifact
with a filled root, and its ko-sensitive columns are **CLAIMED, not PROVEN**
`[4x4.F2:UNTESTED]`.

The new-rule artifact (`data/oracle-4x4-basicko-tie-area.wzo`, T113,
2026-07-30) was built without a finisher — pure fixpoint convergence under
ADR-0020 loopy-game semantics — and does not inherit this defect
`[4x4.BASICKO-TIE:MEASUREMENT]`.

---

## 4. Basic ko + loopy-game fixpoints — the chosen semantics

After foreclosing PSK, score-on-cycle, RETRO_PLY, and kill-X%, the project
turned to **basic ko + a fixed-value long-cycle verdict**: positions repeat
only under the basic ko rule (one illegal recapture point), and any longer
cycle that does repeat is scored as a constant tie value.

This was the first candidate not foreclosed by prior measurement. The
state-space census (EXP-3) returned GO: 51,419,046 reachable
(position, side, ko_point) triples at 4×4 = 177 MB, 1.057× the current PSK
slot count `[GLOBAL.H1-CENSUS:PROVEN]`. The representation is cheap.

### 4.1 ADR-0019 (first-revisit truncation) → ADR-0020 (loopy-game fixpoints)

The project's first attempt at a semantics for basic ko was **first-revisit
truncation** (ADR-0019): when a goban position reappeared, the game terminated
with a fixed tie value (TIE=0). That rule is well-defined and human-playable,
but it makes the game non-Markovian on `(board, side, ko_point, passes)` —
the value at a state depends on *how* the state was reached, not just the
state itself. A concrete C1 witness exists at 3×2: state `(178,0,6,0)`, two
valid arrivals giving truncation values −3 and −6 `[GLOBAL.H1-COMPUTABLE:FALSE-AS-SCOPED]`.

ADR-0019 was **superseded on 2026-07-30 by ADR-0020**: the deliverable is the
**loopy-game fixpoint table**. Under loopy-game semantics, cycles do not
terminate the game; both players may revisit positions, and the value is the
limit of the iterative Bellman operator Φ(L,H) = (max over moves of opponent's
H, min over moves of opponent's L). This semantics is:

1. **Markovian** on `(board, side, ko_point, passes)` — the value is a
   function of the state alone `[ADR-0020:CLAIMED]`.
2. **Tractable** — demonstrated at 3×3 (73,758 states, 16 sweeps, <1 minute),
   4×4 (147M states, 31 sweeps) `[3x3.BASICKO-TIE:MEASUREMENT]` `[4x4.BASICKO-TIE:MEASUREMENT]`.
3. **Convergent** by Knaster–Tarski on the complete lattice of bound vectors
   `[GLOBAL.FP1:PROVEN]`.
4. **Anchor-compatible** — matches every MIGOS II published anchor where the
   rule difference bites (2×2=0, 3×2=0, 3×3=+9) `[3x3.BASICKO-TIE:MEASUREMENT]`.
5. **Internally consistent** — L=Φ(L), H=Φ(H), 0 Bellman failures, 0
   colour-inversion violations at all tested sizes.

First-revisit truncation is **demoted** from the rule to a reference probe. The
24 known 2×2 fixpoint-vs-truncation mismatch states become a standing
calibration fixture, measuring the semantic gap at every build rather than
forgetting it.

### 4.2 The EXP-4→7 gate chain — loopy-game results at every goban

The full gate chain resolved under loopy-game fixpoint semantics (EXP-4 through
EXP-6, DSPro, 2026-07-29/30):

| goban | root | L==H? | bracket | states | sweeps | note |
|---|---|---|---|---|---|---|
| 2×2 | **0** | TIE | L=−4, H=+4 | 258 | 4 | gate |
| 3×2 | **0** | TIE | L=−6, H=+6 | 2,586 | 10 | gate |
| 3×3 | **+9** | YES | — | 73,758 | 16 | matches MIGOS II `[GLOBAL.MIGOS-RULE:PROVEN]` |
| 4×4 | **+1** | NO | [+1,+16] | 147M | 31 | **+1, matching MIGOS's own basic-ko result** (thesis Table 5.1) — the +2 anchor is a different game (pass-difference cycle resolution), not a tie constant and not a build defect `[GLOBAL.TIE-MIGOS:FALSE-AS-SCOPED]`; weizigo fixpoint and MIGOS search agree under aligned rules `[GLOBAL.FIXPOINT-VS-SEARCH:CLAIMED]`; the +2 acceptance criterion is unmet and cannot be met by ruleset R |

T104 (Kimi-k3, 2026-07-30) verified H=+16 genuine — 0 violations over
99,133,036 states, 0 map misses, exhaustive inversion clean
`[4x4.BASICKO-TIE:MEASUREMENT]`. The +2 gap vs the MIGOS II anchor is **explained**
(T274 primary sources, absorbed T279): MIGOS's long-cycle-tie value is 0 = ours (thesis
§5.3.2; ICGA 2009 §3.3), MIGOS's own basic-ko 4×4 result is +1 = ours (thesis Table 5.1),
and the +2 anchor is a different game — pass-difference cycle resolution (thesis Appendix
A §A.4) — not a different tie constant and not a defect in our build
`[GLOBAL.TIE-MIGOS:FALSE-AS-SCOPED]`; under aligned rules, weizigo fixpoint and MIGOS
search agree `[GLOBAL.FIXPOINT-VS-SEARCH:CLAIMED]`. The roadmap's +2 acceptance criterion
(`roadmap-2026-07-28.md:227-232`) is not met and cannot be — the +2 anchor is a different
game; our +1 for our own game still awaits the #2 auditor. **Corrected 2026-08-02 (T271): the prior 'basic ko vs PSK' explanation was contradicted by `GLOBAL.MIGOS-RULE` (MIGOS plays basic ko, not PSK). Further corrected 2026-08-02 (T275): 'not a bug' withdrawn — it rested on a CLAIMED hypothesis as if PROVEN, repeating the GRAND-AUDIT §1d shape. T279 (absorbed 2026-08-03): TIE-MIGOS refuted by primary sources (T274) — FALSE-AS-SCOPED.**

**⚠ Brute-force corroboration withdrawn (T102, 2026-07-30).** A successor-buffer
aliasing defect in `brute_value_2x2` (`src/exp4_solve.zig:555-594`) invalidates
every brute-force cross-check in the EXP-4→EXP-7 chain. All 24 EXP-4 2×2
"mismatches" were an artifact of the checker, not a divergence in the thing
checked; fixpoint and truncation agree on all 172 reachable non-terminal 2×2
states. **Stands:** the fixpoint results, independently verified by T102 (2×2),
T104's Python kernel (2×2/3×2/3×3), and the MIGOS II anchor at 3×3.
**Withdrawn:** brute-force cross-check as corroboration anywhere in the EXP
chain `[GLOBAL.BRUTE-ALIASING:FALSE]`.

### 4.3 The .wzo artifact

T113 (DSFlash, 2026-07-30) wrote the first basic-ko + TIE=0 WZO artifact:
`data/oracle-4x4-basicko-tie-area.wzo` — 258,280,358 bytes, SHA-256
`edd9f68ef243f67de21152432f9e8f521536317527d425208e6901f90b11c0cc` (verified by
T126, 2026-07-31). Rules ID 2, 48.5M fresh-start states from 99M compact
fixpoint, 31 sweeps, ~1 h at 3.6 GB peak RSS. Root values: vb[0]=+1 (L=+1,
H=+16), vw[0]=−1 (L=−16, H=−1). Recorded in `artifacts/SHA256SUMS`
`[4x4.BASICKO-TIE:MEASUREMENT]`.

---

## 5. What survived — the verified machinery

Not everything is in crisis. The project's foundation is solid, and the
T100–T126 wave (2026-07-30) strengthened it substantially:

- **The colex address system** is a verified bijection through 4×4; position
  counts match OEIS A094777 through 4×4 `[GLOBAL.S1:PROVEN]` `[4x4.S3a:PROVEN]`
  `[4x3.S3a:PROVEN]`.
- **The L/H fixpoint iteration** (Knaster–Tarski on a finite lattice) converges
  in finitely many sweeps `[GLOBAL.FP1:PROVEN]` `[GLOBAL.FP3:PROVEN]`. Proof
  note committed by T105 (Kimi-k3, 2026-07-30). The fixpoint machinery is sound;
  the question is what it computes.
- **Colour inversion** holds: `value(−pos,−side) == −value(pos,side)`, and
  dihedral transforms never change score or sign `[GLOBAL.INVSYM:PROVEN]`. Proof
  note committed by T111 (Kimi-k3, 2026-07-30).
- **Benson's unconditional-life theorem** is cited from the literature, its
  finite-goban scope argument committed by T107 (DSPro, 2026-07-30)
  `[GLOBAL.S2:PROVEN]`. Implementation falsification-confirmed at 3×3
  `[3x3.S2-impl:PROVEN]`. Terminal detection by Benson + double-pass is sound
  under area scoring `[GLOBAL.ADR0004-TERM:PROVEN]`.
- **Area scoring** is implemented correctly; independently cross-validated by
  T112 (DSPro, 2026-07-30) with a Python Tromp–Taylor area scorer on 120
  random gobans (seed 0xC0FFEE, stratified 2×2–5×5), 0 disagreements
  `[GLOBAL.S4:PROVEN]`; the 500-goban run is the separate Zig-vs-Zig
  self-test at 5×5 (`src/rules.zig:404`) — cross-validation and self-test
  are different evidence.
- **The writes-off finisher** (`memo_writes=false`) is self-consistent at 3×2
  (0 auditor violations) `[3x2.F3:PROVEN]` and the dependency-guarded memo
  (Kishimoto–Müller, `deps` mode) is validated at 3×2/3×3/4×3 `[GLOBAL.F4:PROVEN]`.
  The writes-on finisher (`ko_ref ≥ d`) is **unsound** — 45/378 auditor violations
  at 3×2 `[GLOBAL.F1:FALSE-AS-SCOPED]` `[3x2.F1:PROVEN]`.
- **The auditor** (`RETRO_CONSIST`) was re-run at 3×2 by T106 (Kimi-k2.7,
  2026-07-30): 0 minimax-identity violations, committed stdout at
  `docs/evidence/GLOBAL.AUDITOR/` `[GLOBAL.AUDITOR:PROVEN]`.
- **The chainability census** shows the single-score (L==H) region is chainable
  — zero V0/V1 identity violations outside the KO_SENSITIVE flag at every size
  tested `[GLOBAL.CHAIN-LH:PROVEN]` `[GLOBAL.CHAIN-KO:PROVEN]`. Violations are
  exactly co-extensive with the flag; no unflagged slot ever violates.
- **The 4×4 ko-sensitive region is 99.997% single-ko** — only ~250 side-positions
  (0.0025% of 10,367,922) are multi-ko, all in the 3-ko category. Verified
  byte-identical against the B23 static census with a dynamic cycle classifier
  sampling 1,500+ positions `[4x4.KO-CENSUS:MEASUREMENT]`. This converts the
  open question from "can we handle 10.4M ko-sensitive slots?" into "can we
  certify a single-ko sub-solver?"

---

## 6. What the knowledge ladder says about where we sit

`docs/epistemic/knowledge-ladder.md` (PROPOSED, not yet adjudicated by the user)
proposes six rungs separating *epistemic strength* from *rule fidelity* —
the project's characteristic failure is a high score on the first reported as
settling the second:

| what | rung | why |
|---|---|---|
| Legal position counts (OEIS A094777) | K0 — Certified | externally published and independently reproduced |
| Knaster–Tarski fixpoint convergence | K0 | mathematics, not measurement |
| Move/capture/suicide kernel, colex bijection | K0 | kernel matches A094777; bijection has a checker |
| 3×2 reachable-graph structure | K1 — Proven-as-scoped | reproduced twice independently |
| **The 4×4 "+2" oracle and every shipped ko-sensitive value** | **K4 — Best available, uncertified** | rests on ADR-0010's bracket premise = C3, FALSE-AS-SCOPED at 3×3; and it is fresh-start PSK, which C2 falsified as a real-game oracle `[GLOBAL.C2:FALSE-AS-SCOPED]` `[GLOBAL.C3:FALSE-AS-SCOPED]` |
| GTP player in the ko-sensitive region | K5 — Guess | defective by design; H5a mitigates, does not solve `[4x4.GTP-DEFECT:PROVEN]` `[GLOBAL.H5a-CHILD:CLAIMED]` |
| Eye-prune (ADR-0006) soundness | K3 — Validated-as-scoped | not falsified; 6 premises hold exhaustively at 4×4 (1,362,424 eyes, 0 violations); forward-search agreement on 4,212 slots; 96 live PRUNE-ALL 4×4 pairs all clean `[GLOBAL.ADR0006-EYE:CLAIMED]` `[GLOBAL.ADR0006-PRED:PROVEN]` `[GLOBAL.ADR0006-LEMMAS:PROVEN]` `[GLOBAL.ADR0006-TEST:PROVEN]` |

**The certified-fraction metric is a K0-shaped instrument bolted to a K4
foundation.** "Certified" means the Bellman identity was verified at the node
under the table's own rule — self-consistency, not correctness. And at 4×4
the new-rule table fails even that: the median-pinned V violates its own
Bellman identity at 89.29% of visited fresh-start nodes (T129, 2026-07-31)
`[QA-027:FALSE-AS-SCOPED]`.

---

## 7. What is open

### 7.1 State-sufficiency (C1) under basic ko — RESOLVED by ADR-0020

Under loopy-game fixpoint semantics (ADR-0020), the state `(board, side,
ko_point, passes)` **is** Markovian — the fixpoint value is a function of
the state alone. Under truncation semantics (ADR-0019, superseded), C1 is
falsified at 3×2 `[GLOBAL.H1-COMPUTABLE:FALSE-AS-SCOPED]`. The ~22-node
witness tree is committed in `docs/audits/2026-07-29-qa023-kernel-audit.md`.
ADR-0020 changes which semantics the project targets; it does not change the
falsification status of the truncation rows.

### 7.2 PINRULE-SUFFICIENCY — SUPERSEDED by ADR-0020

Under loopy-game fixpoint semantics, the value *is* the fixpoint itself —
no pinning function is needed. The question "can any pointwise function of
(L,TIE,H) compute the correct value?" was asked under truncation semantics
and is moot under ADR-0020. The corrected kernel's 396/396 agreement
remains as evidence that the fixpoint is self-consistent.

### 7.3 The GTP player

The GTP player's move rule (`Session.choose` — extremum over stored child
values) is undefined in the ko-sensitive region, which on 4×4 includes the
empty goban itself `[4x4.GTP-DEFECT:PROVEN]` `[4x4.M5:PROVEN]`. EXP-9 (Opus 5,
2026-07-29) shipped a mitigation: child-side refuse-on-divergence + settled-area
fallback; +6.8%/genmove; PARTIAL acceptance — the mechanism fires at ply 13 not
ply 7 `[GLOBAL.H5a-CHILD:CLAIMED]` `[GLOBAL.H5a-FALLBACK:CLAIMED]`.

### 7.4 The new-rule build — COMPLETE through 4×4

EXP-4/5/6 (the new-rule tables at 2×2/3×2/3×3/4×4) completed 2026-07-29/30
under loopy-game fixpoint semantics `[2x2.BASICKO-TIE:MEASUREMENT]`
`[3x2.BASICKO-TIE:MEASUREMENT]` `[3x3.BASICKO-TIE:MEASUREMENT]`
`[4x4.BASICKO-TIE:MEASUREMENT]`. The .wzo artifact was written (T113).
The PSK-divergence measurement (EXP-8, Kimi-k2.7, 2026-07-29) built the
harness but is blocked on new-rule tables — which now exist. The
certified-fraction measurement (EXP-7) **completed at 4×4** (DSPro/T129,
2026-07-31): certified fraction **10.71%** (3,000/28,000 fresh-start nodes),
falsifying QA-027 at that goban `[QA-027:FALSE-AS-SCOPED]` — the L/H
fixpoint converged but the pinned `V = median(L, TIE, H)` does not satisfy
the V-domain Bellman identity at bracket-valued states (the empty-goban root
`[L=+1, H=+16]` violates directly). At 3×3, where the root is single-valued,
the fraction is 100.00%. Evidence: `docs/evidence/QA-027/4x4/`,
`docs/research/newrule-certified-fraction-4x4-2026-07-31.md`.
Brute-force cross-check is withdrawn across the entire chain (T102)
`[GLOBAL.BRUTE-ALIASING:FALSE]`; fixpoint results stand independently.

### 7.4a Oracle-v2 / verify-battery P2 (2026-07-31) — code-complete, RUN-PENDING

The post-G2 build lanes (T165–T172) delivered ~5,000 lines of committed,
compiling code and **zero executions**. Absorbed 2026-08-01 (Fable/T177):

- **Oracle-v2** (M2b builder, M3 GTP wiring, M4a acceptance harness): no
  `.wzo2` artifact exists; the builder compiled but never ran; the
  spec-mandated `docs/evidence/ORACLE-V2/` directory was never created.
  Every register prediction — the G bracket, the F2 byte budget, the DTT
  254-clamp question — remains untested `[CODE.WZO2-UNRUN:SUPERSEDED]`.
  Two defects are visible by inspection: the WZO2 GTP path short-circuits
  the chainability check to `true`, making the refusal rate unmeasurable by
  construction `[CODE.WZO2-CHAINSHORT:SUPERSEDED]`, and the acceptance harness
  is orphaned from the build graph with a broken A6 positive control
  `[CODE.M4A-HARNESS:PROVEN]`.
  **Overtaken 2026-08-01 (later the same day):** the artifact was built
  (T192, 518.1 MB, peak RSS 3887 MB — the memory hazard discharged) and M4a
  finally ran (T193). It **failed**: the builder encoded `passes=1` entries
  with `passes=0` in the key_byte, colliding both pass classes at one sort
  key, so A3 colour inversion failed on 16.5% of 99,133,036 checks and A9
  reported 24,252,631 entry-order violations `[CODE.WZO2-PASSBIT:PROVEN]`.
  The 3×3 artifact passes all four checks, which is what localises the
  defect to the 4×4 builder rather than the harness. One character, fixed
  at `5deec6b`; rebuild and re-run are T212, and oracle-v2 G3 is unreachable
  until they pass. The row that predicted this — "kanban *done* here means
  code written, not run" — was right, and cost 518 MB to confirm.

- **2026-08-02 — the artifact is valid-looking and structurally complete.** M4a passes 4/4
  on the rebuilt artifact `[SPRINT-M4a-ACCEPT:PROVEN]`, and it is still not a
  verified perfect oracle: a direct scan found `passes=1` entries present for
  only one side in ~27.9% of sampled 4×4 groups, but the absent entries are exactly the
  131,068 single-colour gobans and are provably unreachable
  `[CODE.WZO2-INCOMPLETE:FALSE-AS-SCOPED]` `[CODE.WZO2-PASS1-LAW:PROVEN]`.
  The W+2 self-play was the pre-T265 ko rule + the display-path defect
  `[CODE.GTP-LHSIDE:PROVEN]`, not missing entries. T212's proposal that the
  artifact is valid is recorded and refuted on corrected grounds `[WZO2-4X4-VALID:FALSE-AS-SCOPED]`.
  **Passing every check we had did not make it correct, because no check we had
  tested completeness or value-correctness.** Corrected 2026-08-03 (T279 absorption).
- **A human playing the engine found what the checks could not.** The GTP
  engine set a ko point on any single-stone capture while the solver sets one
  only on the real ko shape, so it built keys the solver never enumerated and
  fell back to a greedy heuristic — losing two games and filling its own eye
  `[CODE.GTP-KOKEY:PROVEN]`. Third defect of one family after the colex and
  passes-bit mismatches; **no test asserts that consumer and producer derive
  the same key.**
- **Two instruments were reporting on nothing.** The verify-battery had never
  actually run — every output before 2026-08-02 came from a stub returning
  `skipped` `[CODE.BATTERY-STUBBED:PROVEN]`. And the DTT column of every WZO1
  artifact is the `@memset` initialiser, never computed
  `[CODE.WZO1-DTT-UNSET:PROVEN]`, while the v1 4×4 basic-ko artifact violates
  colour inversion on ~48% of positions `[4x4.V1-INVSYM-BROKEN:PROVEN]`.
- **Verify-battery** (harness + three invariant modules): 36 unit tests
  (module-local, not reachable from `zig build test`), harness not wired to
  any invariant module — every check is a stub, zero verification runs
  `[CODE.VB-STUBS:SUPERSEDED]`. T171's I5 Tarjan calibration is **partial**:
  node counts exact, edge counts +30–34% off the committed references, and
  the 3×2 test gate is self-calibrated against an uncommitted number
  `[3x2.I5-CAL:MEASUREMENT]`. T172's blind reimplementation found five spec
  gaps, one critical: **the I11 solver-dump format is specified nowhere**,
  and V-8 shipped I11 as a permanent not-applicable stub instead of
  resolving it `[CODE.VB-BLINDGAPS:PROVEN]`.
- The lesson of the wave: **"done" in the kanban meant code-written, not
  code-run.** Nothing in P2 can support a PROVEN claim about any artifact
  until the builder runs, the acceptance harness joins the build graph, and
  the battery is wired end-to-end. Run logs and the blind analysis were
  rescued from git-ignored `untracked/` into the sprint archive before they
  could repeat the B44 evidence loss.

### 7.5 Other open items

- **4×4 writes-off regen** (D3): untested. Track A's `memo_writes=false`
  KO_SENSITIVE-column regeneration is **not registered** — the WZO2 column was
  discharged by provenance (T472, `findings/T472-track-a-ruling.json`): it is the
  ADR-0020 pure loopy-game fixpoint bracket, never the finisher — so D3 is no
  longer 'the single gate on Track A'. D3 still gates the finisher-based artifacts
  (the writes-on checkpoint `data/oracle-4x4.checkpoint.wzo`'s ko-sensitive values
  stay untrusted) and the #2 auditor
  `[4x4.D3:UNTESTED]`.
- **FP1 acceptance checks 1–2** (seed, zero-change at 4×4): can be read
  post-hoc from T104's audit output `[4x4.FP1-C1:UNTESTED]`
  `[4x4.FP1-C2:UNTESTED]`.
- **4×4 exhaustivity gaps**: S2-impl (Benson implementation at 4×4)
  `[4x4.S2-impl:UNTESTED]`, S3b (ko-legality under PSK history at 4×4)
  `[4x4.S3b:UNTESTED]`.
- **Eye-prune (ADR-0006)** was validated considerably further by T114 (Opus 5,
  2026-07-30) — NOT falsified. Six premises hold exhaustively at 4×4
  (1,362,424 eyes, 0 violations); 17/17 fixture predicates correct; 4,212
  forward-search slots agree with unpruned retrograde table, 0 disagreements;
  96 live 4×4 PRUNE-ALL pairs all clean. Three prior evidence errors corrected
  (inflated denominator, unsound control arm, wrong calibration model).
  Residual risk: ko-sensitive region and 5×5 `[GLOBAL.ADR0006-EYE:CLAIMED]`
  `[GLOBAL.ADR0006-PRED:PROVEN]` `[GLOBAL.ADR0006-LEMMAS:PROVEN]`
  `[GLOBAL.ADR0006-TEST:PROVEN]`.

### 7.6 Legacy engine backlog — absorbed from the engine TODO (T704, 2026-08-23)

The legacy engine TODO (self-declared SUPERSEDED, 17 KB) was archived to
`docs/engine/archive/TODO.md`. Its open items were triaged; the bulk is DONE
or superseded by the ADR-0009 retrograde engine and the ADR-0020 loopy-game
fixpoint build `[GLOBAL.ADR0020-VERIFY-PASS:CLAIMED]`. Triage:

- **Superseded, no action** (history only): the forward-search scaling track
  (line-length/recursion-depth bounding, `collision_size`/`seq_table_size`
  sizing, `measure.zig` re-runs, per-node redundant-recompute, geometry/flood
  consolidation) — superseded by retrograde value iteration; the 5×5
  density-fold projections — foreclosed until a working representation is
  demonstrated at 4×4 (ADR-0012 carries its own erratum).
- **Retired as moot**: index-0 sentinel (lived in the deleted `minimax.zig`);
  Kishimoto–Müller dependency-set caching (the L/H fixpoint handles ko
  structurally); captured-stone / Japanese-scoring tracking (path-dependent
  and out of scope under area scoring `[GLOBAL.ADR0003-AREA:PROVEN]`).
- **Still-live long-tail ideas (unscheduled — recorded as prose, not kanban
  rows)**: (a) the goal-bounded query engine + WHY explanations
  (`docs/research/query-engine-and-explanations.md`); (b) provable dominance
  prunes beyond the eye-prune (super-Benson) `[GLOBAL.ADR0006-EYE:CLAIMED]`;
  (c) an endgame database of settled terminals; (d) gzip/entropy coding of the
  score column.

---

## 8. What it means

### 8.1 The result is a contribution — and it is no longer only negative

Every bounded-history representation the project tested was foreclosed by
measurement: PSK `[GLOBAL.R1:PROVEN]`, score-on-cycle `[GLOBAL.R2:PROVEN]`,
RETRO_PLY `[GLOBAL.RPLY:PROVEN]`, kill-X% `[GLOBAL.R3:FALSE-AS-SCOPED]`.
**Basic ko was the first unforeclosed candidate** — and under truncation
semantics, the state representation failed at 3×2
`[GLOBAL.H1-COMPUTABLE:FALSE-AS-SCOPED]`.

**ADR-0020 changed the semantics and the outcome.** Under loopy-game fixpoint
semantics, `(board, side, ko_point, passes)` **is** Markovian, the fixpoint
converges, and the tables are internally consistent at every tested size
through 4×4. The 4×4 artifact is **structurally complete, value-unverified**
— the G3 gate is split (`WAYPOINTS.md`, 2026-08-03): G3a structural completeness
is discharged `[CODE.WZO2-PASS1-LAW:PROVEN]`, G3b value correctness is
untouched. The measurements that are real stand: root V=+1 under basic-ko +
TIE=0, H=+16 verified genuine, 99.997% single-ko
`[4x4.BASICKO-TIE:MEASUREMENT]` `[4x4.KO-CENSUS:MEASUREMENT]` — but the
closure checks C-A1/C-A2 are specified and unrun (they need the Waypoint 2
kernel), and the acceptance harness that was meant to check the values had
its own divergent ko rule, so A1/A2/A8 were measuring their own off-manifold
walk `[CODE.ACCEPT-KOKEY:SUPERSEDED]`. The foreclosures remain measured, not
conjectured, and the 154/508 (30.3%) C2 falsification at 3×2
`[3x2.T13:PROVEN]` is stronger evidence than ever (T110, 2026-07-30).

This is a result about the problem: *a tractable Markovian representation
exists under loopy-game fixpoint semantics with basic ko.* The foreclosures
narrow what is possible; ADR-0020 says what works.

### 8.2 The honest deliverable

The near-term deliverable is a **loopy-game fixpoint score table under basic ko
+ TIE=0** `[ADR-0020:CLAIMED]`. This is a well-defined mathematical object —
the limit of the Bellman operator on `(board, side, ko_point, passes)` — and
it has been computed through 4×4. It is NOT a real-game PSK oracle; C2 is
falsified at 3×2 (30.3% of the L==H region is history-sensitive,
4,432 falsifying pairs) `[3x2.T13:PROVEN]`. The bracket does not bound the
real-game score `[GLOBAL.C3:FALSE-AS-SCOPED]`. The honest framing: **provably
optimal play under loopy-game fixpoint semantics with basic ko + TIE=0, with a
measured divergence from positional superko.**

### 8.3 What not to say

- "The certified core is proven" — it is fresh-start exact, not real-game
  correct `[GLOBAL.C2:FALSE-AS-SCOPED]` `[GLOBAL.CERTCORE:FALSE-AS-SCOPED]`.
- "The bracket bounds the real-game score" — E2 refutes this at 3×3
  `[GLOBAL.C3:FALSE-AS-SCOPED]`.
- "The 4×4 +2 matches the literature under PSK" — MIGOS II plays basic ko +
  long-cycle ties, not PSK `[GLOBAL.MIGOS-RULE:PROVEN]`.
- "The finisher is sound" — its bracket-cut premise is orphaned
  `[GLOBAL.F2:CLAIMED]` `[QA-018:CLAIMED]`.
- "The table value is the real-game value" — the table stores loopy-game
  fixpoint values, not real-game PSK scores `[GLOBAL.C4:FALSE-AS-SCOPED]`
  `[ADR-0020:CLAIMED]`.

---

## 9. Verification rules — how we know what we know

The QA-023 chain (2026-07-29) earned these standing rules, recorded here
because they govern every claim in this document `[GLOBAL.CALIB-LESSON:PROVEN]`:

- **Verify-then-promote.** A load-bearing claim moves to FALSE or PROVEN only
  after an independent seat agrees, not on one model's report.
- **Trace one datum end-to-end.** Reviewing inputs, outputs and structure is not
  the same as following one datum from entry to verdict.
- **A positive control must exercise the instrument under test, not a
  parallel one.**
- **Impossibly clean counters are red flags.** `budget-exhausted: 0` on a
  harness whose honest cost is exponential.
- **Independent re-implementation is the only thing that has ever found a
  defect in this project.** The audit that found the ko bug (F5) rewrote the
  algorithm in Python; document review found nothing.
- **State every denominator, including the within-budget one.**

---

## 10. Document map

- `CLAIMS.md` — the claim register and dependency graph (machine-readable)
- `GLOSSARY.md` — project terms
- `knowledge-ladder.md` — proposed framework: epistemic strength × rule fidelity
- `boards/CONCEPTS.md` — cross-size concept inventory
- `boards/4x4/EPISTEMIC.md` — 4×4 epistemic tree
- `boards/4x3/EPISTEMIC.md` — 4×3 epistemic tree
- `../status/leak-crisis.md` — the crisis record
- `../research/ko-sensitive-chainability.md` — why the GTP player loses
- `../research/ruleset-options.md` — foreclosures (PSK, score-on-cycle, kill-X%)
- `../research/open-hypotheses-2026-07-27.md` — the simple-ko hypothesis
- `../research/corrections-2026-07-27.md` — corrections to earlier claims
- `../research/ko-composition-census-2026-07-30.md` — 4×4 ko-sensitive region is 99.997% single-ko
- `../decisions/` — ADRs (append-only): 0015 (bracket orphan), 0018 (F2-REMEDY), 0019 (truncation semantics — superseded), **0020 (loopy-game fixpoint semantics — ACTIVE)**
- `../engine/ARCHITECTURE.md` — module map
- `../../AGENTS.md` (repo root) — agent behaviour rules and foreclosures
