Task: NARRATIVE-LAYER · Role: worker · Model: DSPro · Date: 2026-07-29

# The Through-Line — what weizigo tried, what failed, what's open, and what it means

**This file is the durable narrative hub.** It tells the story once, in order,
cite-tagged against `docs/epistemic/CLAIMS.md`. Every load-bearing sentence
carries an inline citation `[ID:STATUS]`, mechanically verified by
`bin/weizigo-claimlint` check C6. A reader who knows nothing about the project
can read this one file and learn what is known, what was tried, what failed,
what is open, and what it means.

**The other files:**
- `CLAIMS.md` — the ledger: every claim, its status, its evidence, its dependency edges. Machine-readable and machine-checked. This is where a status changes; this file only reflects those changes.
- `CURRENT.md` — tactical: who owns what file, what build is in flight, what to resume.
- `HANDOVER.md` — session continuity between agent shifts.
- `knowledge-ladder.md` — a PROPOSED framework separating epistemic strength from rule fidelity (not yet adjudicated by the user).

---

## 1. The project and the goal

`weizigo` set out to build a **provably-correct solver for small Go boards** —
a position-to-score table giving the game-theoretic score of every legal
position for either side to move, built by retrograde value iteration, then
extended to larger boards. The target was *provable knowledge*: not the
strongest player, not the best heuristic, but a verified account of the game
under a stated ruleset.

The rules: **Chinese (area) scoring, komi 0** `[GLOBAL.ADR0003-AREA:PROVEN]`.
Scores are Black-positive `[GLOBAL.INVSYM:PROVEN]`. The generation rule —
the rule the solver solves under — is **positional superko (PSK)** for the
existing artifacts and a **new-rule build** (basic ko + fixed-value tie) for
the intended near-term deliverable `[GLOBAL.REFRAME:CLAIMED]`.
Play-time can enforce any ko rule; the generation rule is chosen for
tractability, not fidelity `[GLOBAL.PSK-GAP:PROVEN]`.

Each board size is its own epistemic universe `[GLOBAL.ADR0016-INHERIT:CLAIMED]`.
A result at 2×2 says nothing about 3×3 unless a monotonicity theorem is
provided — and none exists in this project.

---

## 2. The foreclosures — what was tried and proved intractable

The project did not start with basic ko. It started with positional superko and
worked downward, foreclosing candidates by measurement. Each foreclosure below
is a **measured result about the problem**, not a failure of imagination.

### 2.1 Positional superko is intractable for exact solve `[GLOBAL.R1:PROVEN]`

Exact PSK solving — storing every encountered board position in the memo key to
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
solving from the empty board at 2×2 and 3×2. Every row hit the 200M-node
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
history* (C1: definition, not itself a testable claim — its per-board rows `[2x2.C1:PROVEN]` `[3x2.C1:PROVEN]` carry the verification). It does not store, and cannot store, the score
under the real PSK history of a game in progress.

### 3.1 C2 — the single-score region is not history-independent `[GLOBAL.C2:FALSE-AS-SCOPED]`

The L==H region — where the least and greatest fixpoints agree, covering
~66–79% of slots depending on board size — was called the "certified core"
and claimed to be history-independent. **T13 falsified this at 3×2**
(2026-07-26): 12 verified mismatches on 508 non-trivial PSK histories over
L==H slots, with 0/540 fresh-start sanity mismatches `[3x2.T13:PROVEN]`.
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
for an empty-board root, the finisher's own search path *is* a real game line,
so E2's falsifying histories are within the family ADR-0010 claims to cover.
ADR-0017 (2026-07-29) attempted to refute ADR-0015 and **failed** — T13's 12
pointwise mismatches at 3×2 ride exactly the finisher's search-shaped histories.
A three-seat blind review (QA-018-REVIEW, 2026-07-29) returned **unanimously**
that ADR-0017's verdict is sound `[GLOBAL.ADR0015-BURDEN:CLAIMED]`. ADR-0018
confirmed: the finisher remedy is a new task, not a brackets-off regen — a
brackets-off regen inherits the same premise through CERTCORE-dependent seeds.

**Consequence: every shipped ko-sensitive value is untrustworthy.** The 4×4 "+2"
anchor, every bracket value, and every ko-sensitive column in every artifact
was produced by a finisher whose soundness premise is orphaned. The 4×4
checkpoint (`data/oracle-4x4.checkpoint.wzo`) remains the only 4×4 artifact
with a filled root, and its ko-sensitive columns are **CLAIMED, not PROVEN**
`[4x4.F2:UNTESTED]`.

---

## 4. Basic ko + fixed tie — the first unforeclosed candidate

After foreclosing PSK, score-on-cycle, RETRO_PLY, and kill-X%, the project
turned to **basic ko + a fixed-value long-cycle verdict**: positions repeat
only under the basic ko rule (one illegal recapture point), and any longer
cycle that does repeat is scored as a constant tie value.

This was the first candidate not foreclosed by prior measurement. The
state-space census (EXP-3) returned GO: 51,419,046 reachable
(position, side, ko_point) triples at 4×4 = 177 MB, 1.057× the current PSK
slot count `[GLOBAL.H1-CENSUS:PROVEN]`. The representation is cheap.

### 4.1 The median pin rule and the kernel defect

The plan (F2-REMEDY) was to rebuild the L/H fixpoints by `converge` over
`(board, side, ko_point, passes)`, then compute the tie-pinned value as
`V = median(L, TIE, H)` — no forward finisher, no bracket cuts, no seed
inheritance `[GLOBAL.F2-REMEDY:CLAIMED]`.

`2B-PROBE-FIX` (DSPro, 2026-07-29) tested this at 3×2 against the project's
own reference semantics (first-revisit truncation: the game ends the moment
any state repeats, valued TIE). It reported four counterexample states where
`median(L,TIE,H)` pinned TIE=0 but the truncation value was +1, +3, or −6
`[QA-026:FALSE-AS-SCOPED]`.

**That falsification was itself based on a defective kernel.** Two independent
seats (Kimi-k3/PINRULE-SUFFICIENCY and Kimi-k2.7/QA023-KERNEL-AUDIT) found that
`fixpoint_kernel` never updated White-to-move states: the White branches updated
only on `best < L_tab` and `best > H_tab`, guards that could not fire because
`L_tab` was seeded −6 and `H_tab` to +6. All 878 White-to-move reachable
non-terminals kept (−6,+6), and `median(−6,TIE,+6) = 0` **by construction**
`[GLOBAL.LONGCYCLE:FALSE-AS-SCOPED]`. Every C2 counterexample was White-to-move.

### 4.2 On the corrected kernel — the verdict depends on the semantics

The corrected kernel was validated three ways: agrees with `smoke_fixpoint_2x2`,
Bellman residuals 0/0, colour-inversion violations 0.

- **Under history-conditioned semantics** (first-revisit truncation, ADR-0019):
  **the state is NOT sufficient at 3×2.** A concrete C1 witness exists:
  state `(178,0,6,0)`, board `[B,W,B,_,W,_]`, Black to move — two valid
  arrivals give truncation values −3 and −6 while the corrected fixpoint gives
  L=H=−6. `[GLOBAL.H1-COMPUTABLE:FALSE-AS-SCOPED]`

- **Under fresh-start (shortest-arrival) semantics**: the corrected tables
  remain consistent (396/396 agreements in PINRULE-SUFFICIENCY). This is a
  different object — it measures the value under the *first* arrival, not
  under all arrivals — and it remains **UNTESTED** rather than true. The
  ~22-node witness tree was not dumped and hand-verified `[QA-023:CLAIMED]`.

The distinction is the roadmap. The **state-sufficiency half** of QA-023 —
"is (board, side, ko_point, passes) sufficient for exact solving?" — is now
split into two rows `[GLOBAL.H1-MARKOV:UNTESTED]` `[GLOBAL.H1-COMPUTABLE:FALSE-AS-SCOPED]`.
Under truncation semantics, C1 is falsified at 3×2. Under fresh-start
semantics, C1 is untested. C2 — the claim that `median(L,TIE,H)` computes
the value — is falsified at 3×2 under truncation semantics
`[QA-026:FALSE-AS-SCOPED]`. The crack in the roadmap is real, and it was
discovered by measurement, not by giving up.

---

## 5. What survived — the verified machinery

Not everything is in crisis. The project's foundation is solid:

- **The colex address system** is a verified bijection through 4×4; position
  counts match OEIS A094777 through 4×4 `[GLOBAL.S1:PROVEN]` `[4x4.S3a:PROVEN]`
  `[4x3.S3a:PROVEN]`.
- **The L/H fixpoint iteration** (Knaster–Tarski on a finite lattice) converges
  in finitely many sweeps `[GLOBAL.FP1:PROVEN]` `[GLOBAL.FP3:PROVEN]`. The
  fixpoint machinery is sound; the question is what it computes.
- **Colour inversion** holds: `value(−pos,−side) == −value(pos,side)`, and
  dihedral transforms never change score or sign `[GLOBAL.INVSYM:PROVEN]`.
- **Benson's unconditional-life theorem** is implemented and falsification-
  confirmed at 3×3 `[3x3.S2-impl:PROVEN]`. Terminal detection by Benson +
  double-pass is sound under area scoring `[GLOBAL.ADR0004-TERM:PROVEN]`.
- **The writes-off finisher** (`memo_writes=false`) is self-consistent at 3×2
  (0 auditor violations) `[3x2.F3:PROVEN]` and the dependency-guarded memo
  (Kishimoto–Müller, `deps` mode) is validated at 3×2/3×3/4×3 `[GLOBAL.F4:PROVEN]`.
  The writes-on finisher (`ko_ref ≥ d`) is **unsound** — 45/378 auditor violations
  at 3×2 `[GLOBAL.F1:FALSE-AS-SCOPED]` `[3x2.F1:PROVEN]`.
- **The chainability census** shows the single-score (L==H) region is chainable
  — zero V0/V1 identity violations outside the KO_SENSITIVE flag at every size
  tested `[GLOBAL.CHAIN-LH:PROVEN]` `[GLOBAL.CHAIN-KO:PROVEN]`. Violations are
  exactly co-extensive with the flag; no unflagged slot ever violates.

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
| Eye-prune (ADR-0006) soundness | K4 | precondition of every forward search used as ground truth, validated on one position `[GLOBAL.ADR0006-EYE:CLAIMED]` |

**The certified-fraction metric is a K0-shaped instrument bolted to a K4
foundation.** "Certified" means the Bellman identity was verified at the node
under the table's own rule — self-consistency, not correctness
`[QA-027:CLAIMED]`.

---

## 7. What is open

### 7.1 State-sufficiency (C1) under basic ko

**The single most load-bearing open question.** Under fresh-start semantics:
untested. Under truncation semantics: falsified at 3×2. The ~22-node witness
tree for the C1 witness was not dumped and hand-verified — task
`QA023-C1-WITNESS`. This gates every new-rule build (EXP-4…EXP-8).

### 7.2 PINRULE-SUFFICIENCY

Can *any* pointwise function of `(L, TIE, H)` compute the correct value? If
two distinct states share the same `(L,TIE,H)` triple while having different
history-conditioned values, then every repair-by-substitution dies at once
and the state must carry more information.

### 7.3 The GTP player

The GTP player's move rule (`Session.choose` — extremum over stored child
values) is undefined in the ko-sensitive region, which on 4×4 includes the
empty board itself `[4x4.GTP-DEFECT:PROVEN]` `[4x4.M5:PROVEN]`. EXP-9 (Opus 5,
2026-07-29) shipped a mitigation: child-side refuse-on-divergence + settled-area
fallback; +6.8%/genmove; PARTIAL acceptance — the mechanism fires at ply 13 not
ply 7 `[GLOBAL.H5a-CHILD:CLAIMED]` `[GLOBAL.H5a-FALLBACK:CLAIMED]`.

### 7.4 The new-rule build (F2-REMEDY)

The median build is designed but gated on PINRULE-SUFFICIENCY and QA023-C1-WITNESS
`[GLOBAL.F2-REMEDY:CLAIMED]`. EXP-4/5/6/7/8 — the new-rule tables, certified
fraction measurement, and PSK-divergence measurement — are all blocked
behind these gates.

### 7.5 Other open items

- **4×4 writes-off regen** (D3): untested, the single gate on Track A
  `[4x4.D3:UNTESTED]`.
- **FP1 acceptance checks 1–2** (seed, zero-change at 4×4): untested but
  post-hoc read of existing build logs — the cheapest gap to close
  `[4x4.FP1-C1:UNTESTED]` `[4x4.FP1-C2:UNTESTED]`.
- **4×4 exhaustivity gaps**: S2-impl (Benson implementation at 4×4)
  `[4x4.S2-impl:UNTESTED]`, S3b (ko-legality under PSK history at 4×4)
  `[4x4.S3b:UNTESTED]`, S4 (area scoring at 4×4) `[4x4.S4:UNTESTED]`.
- **Eye-prune (ADR-0006)** has never had a direct falsification test; its only
  cited direct validation is a single position `[GLOBAL.ADR0006-EYE:CLAIMED]`.
  It is a precondition of every forward search used as ground truth
  `[GLOBAL.ADR0006-TEST:PROVEN]`.

---

## 8. What it means

### 8.1 The negative result is a contribution

Every bounded-history representation the project tested was foreclosed by
measurement: PSK `[GLOBAL.R1:PROVEN]`, score-on-cycle `[GLOBAL.R2:PROVEN]`,
RETRO_PLY `[GLOBAL.RPLY:PROVEN]`, kill-X% `[GLOBAL.R3:FALSE-AS-SCOPED]`.
**Basic ko + fixed tie was the first unforeclosed candidate** — and on the
corrected kernel, under truncation semantics, the state representation fails
at 3×2 `[GLOBAL.H1-COMPUTABLE:FALSE-AS-SCOPED]`. Under fresh-start semantics,
it remains untested `[QA-023:CLAIMED]`.

This is not a project failure. It is a result about the problem: *no tractable
Markovian representation has been found for any rule a human would call Go.*
The foreclosures are measured, not conjectured, and each one narrows the space
of what is possible. A negative result of this shape is publishable.

### 8.2 The honest deliverable

The near-term deliverable is a **fresh-start score table + CLAIMED [L,H] bracket**,
with the explicit non-promise that neither equals nor bounds the real-game PSK
score `[GLOBAL.REFRAME:CLAIMED]`. The longer-term target (if C1 holds under
fresh-start semantics) is **K2 on the knowledge ladder**: provably optimal play
under basic ko + a fixed-value long-cycle tie, with a measured divergence from
positional superko.

### 8.3 What not to say

- "The certified core is proven" — it is fresh-start exact, not real-game
  correct `[GLOBAL.C2:FALSE-AS-SCOPED]` `[GLOBAL.CERTCORE:FALSE-AS-SCOPED]`.
- "The bracket bounds the real-game score" — E2 refutes this at 3×3
  `[GLOBAL.C3:FALSE-AS-SCOPED]`.
- "The 4×4 +2 matches the literature under PSK" — MIGOS II plays basic ko +
  long-cycle ties, not PSK `[GLOBAL.MIGOS-RULE:PROVEN]`.
- "The finisher is sound" — its bracket-cut premise is orphaned
  `[GLOBAL.F2:CLAIMED]` `[QA-018:CLAIMED]`.
- "The table value is the real-game value" — the table stores fresh-start
  scores `[GLOBAL.C4:FALSE-AS-SCOPED]`.

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
- `../decisions/` — ADRs (append-only): 0015 (bracket orphan), 0018 (F2-REMEDY), 0019 (truncation semantics)
- `../engine/ARCHITECTURE.md` — module map
- `../../AGENTS.md` (repo root) — agent behaviour rules and foreclosures
