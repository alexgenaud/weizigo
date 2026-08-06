# AXIOMS — epic-01-markovian: theorem, axioms, and requirement tree

Task: T271 · Role: worker · Model: deepseek-v4-pro · Date: 2026-08-02
Amended by T275 (deepseek-v4-pro), the Orchestrator, and T400 (flash) — see the amendment log, §7.

**This file gates all later decomposition.** It states the theorem (Z), the
ruleset axioms (A) from which Z is derived, the requirement tree from Z down to
the axioms, and the MIGOS tie-semantics adjudication required by DIRECTION §3
(GRAND-AUDIT prescription 5). Nothing in Phases 1–4 may be decomposed into tasks
until this file exists.

Axioms are **working, not stone.** An axiom change is a recorded event: a dated
entry here plus a register row in `docs/epistemic/CLAIMS.md`. Never a silent
edit.

---

## 1. The theorem (Z)

> For each goban size g ∈ {2×2, 3×2, 3×3, 4×4}, under ruleset R (area scoring,
> komi 0, basic ko with k=1, pass/termination rules as specified in §2, loopy-game
> fixpoint semantics with TIE=0), the table produced by retrograde Bellman
> iteration on the state space S = (position, side, ko_point, passes) gives the
> exact game-theoretic fresh-start [L,H] bracket for every legal (position,
> side), with L==H where achieved.
>
> **The fresh-start root is the empty goban, Black to move, no ko point, 0
> passes.** Fresh-start = the value under optimal play from that root without
> prior history. The bracket [L,H] is the least and greatest fixpoint of the
> Bellman operator Φ on the complete lattice of valuation vectors seeded from
> (−N, +N), with L = Φ(L) and H = Φ(H). The value V at a state is the loopy-game
> fixpoint: under a fixed constant-tie cycle verdict, the Bellman limit exists
> uniquely by Knaster–Tarski on a finite lattice.

### 1.1 Falsifiability

Z is falsified at goban size g if any of these holds:

- **(Z1) State omission.** A legal (position, side) reachable from the
  fresh-start root under ruleset R is absent from the table.
- **(Z2) Bellman violation.** At any table slot, L ≠ Φ(L) or H ≠ Φ(H), where Φ
  is the Bellman operator of R.
- **(Z3) Seeding violation.** The table's root values do not match a build
  seeded from (−N, +N) and converged to zero-change.
- **(Z4) Colour-inversion violation.** L(−pos, −side) ≠ −H(pos, side) or
  H(−pos, −side) ≠ −L(pos, side) at any position.
- **(Z5) Monotonicity violation.** The fixpoint iteration does not converge
  monotonically from the declared seeds.

### 1.2 Explicit non-claims (what Z does NOT assert)

These are part of the theorem statement, not footnotes — a falsification of Z
on these grounds is a mistake by the challenger, not a defence of Z:

- **NC1 — No real-game PSK value.** Z asserts nothing about the score under
  positional superko or any arrival history other than the fresh-start root.
  C2 (history-independence of L==H scores) is FALSE-AS-SCOPED at 3×2
  `[3x2.T13:PROVEN]`.
- **NC2 — No bracket-bounds-real-game.** The [L,H] bracket does not bound the
  real-game score under an arbitrary arrival history. C3 is FALSE-AS-SCOPED at
  3×3 `[3x3.C3:PROVEN]`.
- **NC3 — No cross-size inheritance.** A result at one goban size is not
  evidence at another, absent a monotonicity theorem. Per-goban epistemic
  independence `[GLOBAL.ADR0016-INHERIT:CLAIMED]`.
- **NC4 — Fresh-start only.** The table stores fresh-start values. It is not a
  real-game oracle `[GLOBAL.C4:FALSE-AS-SCOPED]`.
- **NC5 — Not a verified perfect oracle until proven.** The table is CLAIMED
  until the acceptance battery passes and the #2 auditor returns zero
  violations at every goban size in Z's scope `[GLOBAL.AUDITOR:PROVEN]`.

---

## 2. Ruleset R — axioms

Each axiom is a single sentence that can be checked against code. Every axiom
carries a claim ID from birth; statuses are recorded in `docs/epistemic/CLAIMS.md`.
A freshly written axiom is CLAIMED, not PROVEN, until verified end-to-end.

### A — Goban, stones, and moves

| ID | axiom |
|---|---|
| `GLOBAL.AXIOM-GEOM` | **A1 — Goban geometry.** The goban is a rectangular grid of w×h points. Each point is empty, Black, or White. |
| `GLOBAL.AXIOM-STONE` | **A2 — Stone placement and alternation.** Black and White alternate placing stones on empty points. Black plays first from the fresh-start root. Komi is 0. |
| `GLOBAL.AXIOM-CAPTURE` | **A3 — Capture.** After a stone is placed, any opposing group with zero liberties is removed from the goban. Liberties are empty orthogonally adjacent points. A group is a maximal connected set of same-colour stones. |
| `GLOBAL.AXIOM-SUICIDE` | **A4 — Suicide prohibition.** A move is illegal if, after capture, the placed stone's own group has zero liberties. ("Capture" in A3 is applied first.) |
| `GLOBAL.AXIOM-PASS` | **A5 — Pass.** A player may pass instead of placing a stone. Pass is always legal. A pass does not change the goban, does not capture. A pass clears the ko point (sets it to `none`). Pass is exempt from ko restrictions. |
| `GLOBAL.AXIOM-FORCEDPASS` | **A6 — Forced pass.** A player with no legal placement passes (forced pass). A forced pass is indistinguishable from a voluntary one: it clears the ko point, increments the pass count, and counts toward double-pass termination. At 4×4, 516,242 entries carry the terminal bit for one side (build T184, 2026-08-01, `docs/evidence/ORACLE-V2/build-T184-2026-08-01.stdout:162`). |

### B — Basic ko (k=1)

| ID | axiom |
|---|---|
| `GLOBAL.AXIOM-BASICKO` | **B1 — Basic ko rule (k=1).** A move is illegal if it would capture exactly one opposing stone AND the capturing stone would itself have exactly one liberty after capture AND the resulting goban position would be identical to the goban position two plies earlier — the position before the opponent's capture that created the ko shape (the ko point is the point of the captured stone). |
| `GLOBAL.AXIOM-KOSTATE` | **B2 — Ko state encoding.** The ko point is the forbidden recapture point, or `none`. It is set to the point of the single captured stone when B1 fires; it is cleared (set to `none`) on every pass and on every non-ko-capture move. |
| `GLOBAL.AXIOM-KOPASS` | **B3 — Ko–pass interaction.** A pass clears the ko point. Since pass is always legal (A5) and pass clears ko, a player can always break a ko cycle by passing — the opponent then faces no ko restriction. |

#### Why B1 says *two* plies — the derivation, written out

B1's ply count was "one ply earlier" as first written (T271) and is "two plies
earlier" as amended (T275). Neither version showed its work, so the sequence is
recorded here and anyone may check it against these three positions:

| ply | position | contents at the two ko points `a`, `b` |
|---|---|---|
| P₀ | before the opponent's capture | Black stone at `a`; `b` empty |
| P₁ | after White captures at `b` | `a` empty (Black's stone removed); White stone at `b` |
| P₂ | after Black recaptures at `a` | Black stone at `a`; `b` empty (White's stone removed) |

P₂ = P₀, and P₀ is **two** plies before P₂. P₁ — the position one ply earlier — is
the position Black is moving *from*; a capture changes the goban, so P₂ ≠ P₁
always, and a one-ply test would forbid nothing. Hence two.

**This derivation is prose, and prose is what rots here.** The mechanized check is
T273: the production ko function is written against B1 and then run differentially
against the seventeen existing hand-written copies of the ko condition. If B1 as
stated disagrees with what the solver has always done, that run says so — which is
the only kind of agreement this project counts.

### C — Termination, scoring, and tie

| ID | axiom |
|---|---|
| `GLOBAL.AXIOM-TERMINAL` | **C1 — Termination.** The game ends when both players pass consecutively (double-pass). A game may also reach a terminal position where both sides have no legal moves except pass; the value is the area score of that position. |
| `GLOBAL.AXIOM-AREA` | **C2 — Area scoring.** At a terminal position, the score for Black is: Black stones on the goban + empty points in Black's surrounded territory. White's score is computed symmetrically. The game score is Black's score minus White's score. This is Tromp-Taylor area scoring, stones as they stand: every stone on the goban counts for its colour, and an empty region counts for a colour only when it borders exactly one colour (neutral otherwise). Nothing is removed at the terminal — dead-stone removal happens by play before the terminal (the defender captures, or the region stays contested), never by adjudication at it. Benson's unconditional-life theorem `[GLOBAL.S2:PROVEN]` is NOT part of terminal scoring (amended 2026-08-06, T400, §7 Amendment 4); it is load-bearing only where dead-stone status is decided: the ADR-0006 eye-prune, `is_settled` terminal *detection* (which positions get scored — never how; the WZO2 builder's seed phase and the forward search both use it), and resign logic. |
| `GLOBAL.AXIOM-TIE` | **C3 — Tie value.** Under loopy-game fixpoint semantics, the value of a cycle is the tie constant TIE = 0 (Black-positive: a draw scores 0). The tie value is a constant, not a function of which positions repeat — this distinguishes it from score-on-cycle and makes the state Markovian. |
| `GLOBAL.AXIOM-SCORESIGN` | **C4 — Score sign convention.** All scores are Black-positive. Side-to-move picks the array, never the sign. Black maximizes; White minimizes. Colour inversion: value(−pos, −side) == −value(pos, side). For bound tables: L(−pos, −side) == −H(pos, side). |

### D — State representation

| ID | axiom |
|---|---|
| `GLOBAL.AXIOM-STATE` | **D1 — State tuple.** The game state is the four-tuple (position, side, ko_point, passes), where: position is the goban colouring encoded by colex index `[GLOBAL.S1:PROVEN]`; side ∈ {Black, White}; ko_point ∈ {0…w·h−1} ∪ {none}; passes ∈ {0, 1, 2}. |
| `GLOBAL.AXIOM-FRESHSTART` | **D2 — Fresh-start root.** The fresh-start root is the unique state (empty goban, Black, ko=none, passes=0). All values in the table are the game-theoretic values from this root under optimal play. |
| `GLOBAL.AXIOM-PASSSTATE` | **D3 — Pass-state invariant.** passes ≥ 1 ⇒ ko_point = none. A pass captures nothing, so no ko point can accompany a nonzero pass count `[GLOBAL.PASS-NOKO:PROVEN]`. Consequence: the pass-dimension adds at most 3× the ko-point-free slots, not 3× the full state space. |

### E — Game-theoretic semantics

| ID | axiom |
|---|---|
| `GLOBAL.AXIOM-BELLMAN` | **E1 — Bellman operator.** The value of a non-terminal state is defined by the Bellman equations: Black to move: V = max over legal moves of V(child); White to move: V = min over legal moves of V(child). Terminal states (double-pass or no legal goban moves) have V = area_score. |
| `GLOBAL.AXIOM-LH` | **E2 — L/H fixpoint.** L is the least and H the greatest fixpoint of Φ seeded from (−N, +N), where N = w·h is the maximum possible score. L(s) = Φ(L)(s), H(s) = Φ(H)(s) at every state s in the reachable state graph. Convergence in finitely many sweeps is guaranteed by Knaster–Tarski on a finite lattice `[GLOBAL.FP1:PROVEN]` `[GLOBAL.FP3:PROVEN]`. |
| `GLOBAL.AXIOM-BRACKET` | **E3 — Bracket semantics.** At every state, L(s) ≤ H(s). Where L(s) = H(s) the state has a unique game-theoretic fresh-start value. Where L(s) < H(s) the state is bracket-valued: the value depends on information not in the state (history beyond k=1). The bracket [L(s), H(s)] is the range of possible values consistent with the state alone. |

---

## 3. Requirement tree

Derived top-down from Z. Each node states what it asserts, what would falsify
it, and any existing claim ID that plausibly occupies it (mapped, not verified).

**Notation:** `[F]` = falsification criterion. `→` = "depends on". Existing
claim IDs in brackets.

### 3.1 Root — Z (the theorem)

**Z:** The fresh-start table under R gives exact [L,H] brackets for all legal
states. `[GLOBAL.Z:CLAIMED]`
- [F]: any of Z1–Z5 in §1.1.

Z depends on:
- **Z-R:** The ruleset R is well-defined (axioms A1–E3).
- **Z-STATE:** The state space S is finite and correctly enumerated.
- **Z-CONVERGE:** Φ converges to unique L,H fixpoints.
- **Z-TABLE:** The table faithfully represents those fixpoints.
- **Z-COMPLETE:** Every legal state reachable from the fresh-start root is in
  the table.

### 3.2 Z-R — Ruleset well-defined

**Z-R:** Every axiom in §2 is self-consistent and permits computation of legal
moves and terminal scores for any state.

- **Z-R-MOVE:** Move legality is decidable. A1–A5, B1–B3.
  - A1 Goban geometry `[GLOBAL.AXIOM-GEOM:CLAIMED]`
  - A2 Stone placement `[GLOBAL.AXIOM-STONE:CLAIMED]`
  - A3 Capture `[GLOBAL.AXIOM-CAPTURE:CLAIMED]`
  - A4 Suicide `[GLOBAL.AXIOM-SUICIDE:CLAIMED]`
  - A5 Pass `[GLOBAL.AXIOM-PASS:CLAIMED]`
  - B1 Basic ko `[GLOBAL.AXIOM-BASICKO:CLAIMED]`
  - B2 Ko state `[GLOBAL.AXIOM-KOSTATE:CLAIMED]`
  - B3 Ko–pass `[GLOBAL.AXIOM-KOPASS:CLAIMED]`
  - [F]: a position where two interpretations of the axioms disagree on legality.
- **Z-R-SCORE:** Terminal scoring is decidable.
  - C1 Termination `[GLOBAL.AXIOM-TERMINAL:CLAIMED]`
  - C2 Area scoring — Tromp-Taylor as-stands, no removal at the terminal `[GLOBAL.ADR0003-AREA:PROVEN]`, `[GLOBAL.S4:PROVEN]` (amended 2026-08-06, T400 — Benson no longer named for territory; see §7 Amendment 4)
  - Terminal detection (when to score) uses Benson — `is_settled` and the ADR-0006 eye-prune `[GLOBAL.S2:PROVEN]`, `[GLOBAL.ADR0004-TERM:PROVEN]`; detection only, not scoring
  - [F]: a terminal position where area_score disagrees with the Tromp-Taylor as-stands definition.
- **Z-R-TIE:** Cycle resolution is well-defined.
  - C3 TIE=0 `[GLOBAL.AXIOM-TIE:CLAIMED]`
  - [F]: a cycle whose fixpoint value under TIE=0 is not uniquely determined,
    or a state where C1 (Markovian) fails.
- **Z-R-STATE:** State encoding is correct.
  - D1 State tuple, colex `[GLOBAL.S1:PROVEN]`
  - D2 Fresh-start root `[GLOBAL.AXIOM-FRESHSTART:CLAIMED]`
  - D3 Pass invariant `[GLOBAL.PASS-NOKO:PROVEN]`
  - [F]: two distinct states mapping to the same key (producer/consumer
    disagreement — the T178/T193/T265 defect family).
- **Z-R-SIGN:** Score convention is consistent.
  - C4 Black-positive, colour inversion `[GLOBAL.INVSYM:PROVEN]`
  - [F]: a position where value(−pos, −side) ≠ −value(pos, side).

### 3.3 Z-STATE — State space correctly enumerated

**Z-STATE:** The reachable state graph under R is correctly enumerated per
goban size.

- **Z-STATE-LEGAL:** Legal position counts match the colex bijection.
  `[GLOBAL.S1:PROVEN]`, `[4x4.S3a:PROVEN]`, `[4x3.S3a:PROVEN]`
  - [F]: a position within the colex range that is not a legal goban position,
    or a legal goban position outside the range.
- **Z-STATE-REACH:** The reachable set from the fresh-start root is correctly
  computed.
  `[GLOBAL.H1-CENSUS:PROVEN]` (at 3×3, 4×4), `[3x3.H1-CENSUS:PROVEN]`,
  `[4x3.H1-CENSUS:PROVEN]`, `[4x4.G-CENSUS:MEASUREMENT]`
  - [F]: a state reachable under R that is absent from the census, or a
    census state unreachable by any legal sequence.
- **Z-STATE-KEY:** Producer and consumer compute identical keys.
  T267 (key-agreement invariant) — **closed 2026-08-02 20:43Z** (`pass`): the
  test half wires `differential.zig` into `zig build test`; the production
  `koAfterCapture`/`stateKey` is T273's kernel extraction (Phase 2).
  - [F]: a (board, side, ko, passes) where the solver's key ≠ the consumer's
    key. The family: T178 (colex vs rank), T193 (passes bit), T265 (ko key).

### 3.4 Z-CONVERGE — Fixpoint convergence

**Z-CONVERGE:** Φ converges from (−N, +N) to the least and greatest fixpoints.

- **Z-CONVERGE-MONO:** Φ is monotone on the lattice of valuation vectors.
  `[GLOBAL.FP1:PROVEN]` (Knaster–Tarski; the proof is mathematical.)
  - [F]: a counterexample — two vectors A ≤ B where Φ(A) ≰ Φ(B).
- **Z-CONVERGE-FINITE:** Convergence occurs in finitely many sweeps.
  `[GLOBAL.FP3:PROVEN]` (finite lattice, monotone map.)
  - [F]: a run on a finite goban that does not reach zero-change.
- **Z-CONVERGE-SEED:** The table was seeded from (−N, +N).
  `[4x4.FP1-C1:UNTESTED]`, `[4x4.FP1-C2:UNTESTED]`
  - [F]: build provenance showing different seeds.
- **Z-CONVERGE-FIX:** The output satisfies L = Φ(L) and H = Φ(H).
  `[4x4.FP1-C3:PROVEN]` (sample-based), `[GLOBAL.H4:CLAIMED]` (partial)
  - [F]: a slot where L ≠ Φ(L) or H ≠ Φ(H).

### 3.5 Z-TABLE — Table faithfully represents the fixpoint

**Z-TABLE:** The artifact on disk matches the in-memory fixpoint.

- **Z-TABLE-ROUNDTRIP:** Write then read reproduces values.
  `[SPRINT-M4a-ACCEPT:PROVEN]` (A5 round-trip on WZO2)
  - [F]: a slot where the reloaded value ≠ the written value.
- **Z-TABLE-FAITHFUL:** Every table entry comes from the Bellman fixpoint,
  not from a finisher or fallback.
  - For loopy-game fixpoint builds (ADR-0020): satisfied by construction —
    the table is the fixpoint, no finisher. `[ADR-0020:CLAIMED]`
  - For finisher-based builds: `[GLOBAL.F2:CLAIMED]` (orphaned via
    `[GLOBAL.C3:FALSE-AS-SCOPED]`).
  - [F]: a slot whose stored value disagrees with the fixpoint value of the
    state.
- **Z-TABLE-CONSISTENCY:** Internal consistency checks pass.
  Colour inversion `[GLOBAL.INVSYM:PROVEN]`, reproducibility, no entry-order
  violations. `[SPRINT-M4a-ACCEPT:PROVEN]` (A3/A9), `[4x4.V1-INVSYM-BROKEN:PROVEN]`
  (v1 artifact fails).
  - [F]: any A3 or A9 violation.

### 3.6 Z-COMPLETE — Every legal state is in the table

**Z-COMPLETE:** No reachable legal state is absent.

- **Z-COMPLETE-ENUM:** Every state reachable from the fresh-start root under R
  is present in the table.
  - [F]: a reachable state whose lookup misses, or self-play divergence from
    the table's own root value. `[CODE.WZO2-INCOMPLETE:FALSE-AS-SCOPED]` (the
    claimed 6.77M missing was 51.7× overstated; the artifact is structurally
    complete — T266/T277/T279).
- **Z-COMPLETE-PASSES:** The passes dimension is fully enumerated.
  `[CODE.WZO2-INCOMPLETE:FALSE-AS-SCOPED]` — the passes=1 entries are
  provably unreachable (single-colour gobans); structurally complete per
  T266/T277/T279.

### 3.7 Cross-cutting concerns

- **Z-SYM:** Colour inversion and dihedral symmetry hold.
  `[GLOBAL.INVSYM:PROVEN]`
- **Z-AUDIT:** The #2 self-consistency auditor passes.
  `[GLOBAL.AUDITOR:PROVEN]` (gate, not verification)
- **Z-NONCLAIMS:** Each non-claim NC1–NC5 is independently verified as
  false-as-scoped (the negative half of the theorem is as load-bearing as the
  positive half).
  - NC1: `[3x2.T13:PROVEN]` — C2 false at 3×2
  - NC2: `[3x3.C3:PROVEN]` — C3 false at 3×3
  - NC3: `[GLOBAL.ADR0016-INHERIT:CLAIMED]` — policy
  - NC4: `[GLOBAL.C4:FALSE-AS-SCOPED]`, `[GLOBAL.LEAK:PROVEN]`
  - NC5: role of the auditor and the acceptance battery

---

## 4. MIGOS tie-semantics adjudication — RESOLVED (T274, absorbed T279)

**The +1-vs-+2 miss is now explained.** T274 (2026-08-02) obtained the primary
sources (van der Werf 2005 PhD thesis, DOI 10.26481/dis.20050127ew; van der Werf &
Winands, ICGA 2009) and read them in full. The findings:

### 4.1 What the primary sources say

- **MIGOS's long-cycle-tie value is 0** — identical to our TIE=0. Thesis §5.3.2:
  "In practice we use 0 as the value for a draw." ICGA 2009 §3.3: "Normally,
  there is no need to distinguish long-cycle-ties from heuristic scores, so
  MIGOS II simply assigns a value in the heuristic range (typically 0)."
- **MIGOS's basic-ko 4×4 result is +1** — identical to our +1. Thesis §5.4.1
  (Table 5.1): under basic ko, the 4×4 result is **+1**. Thesis text: "Under
  basic ko Black does not win the 4×4 board by two points."
- **The +2 arises from a different cycle-resolution rule.** Thesis Appendix A
  §A.4: repetition ends the game; balanced cycle = draw; unbalanced cycle =
  the player who passed more wins. Under this pass-difference rule (or SSK),
  the 4×4 score is +2 — a seki that White cannot escape via a balanced cycle.
  This is a different game definition, not a different tie constant.

### 4.2 What this means

- **`GLOBAL.TIE-MIGOS` (Candidate 1) is FALSE-AS-SCOPED.** The minted mechanism
  — "TIE=0 vs MIGOS's implementation-specific long-cycle-tie value" — is
  contradicted: MIGOS's tie value is 0, same as ours. The +2 is not a different
  tie value; it's a different game.
- **`GLOBAL.FIXPOINT-VS-SEARCH` (Candidate 2) is CLAIMED with corrected content:**
  under aligned rules (basic ko, flat TIE=0), weizigo fixpoint (+1) and MIGOS
  search (+1) agree. The +1-vs-+2 gap is a ruleset difference, not a
  fixpoint-vs-search discrepancy. A defect in our build (Candidate 2(b)) is not
  needed to explain the gap — though our value for our own game still awaits
  the #2 auditor.
- **The +2 acceptance criterion is moot.** `roadmap-2026-07-28.md:227-232` set +2
  as the target for a "finally legitimate comparison"; the target was the wrong
  anchor — MIGOS's own basic-ko result is +1, and our +1 matches it.
- **The "thesis §6.4" citation is wrong.** `4x4.ANCHOR` and the prior §4 text
  cited "thesis §6.4" for the 4×4 solve; §6.4 is "Learning connectedness."
  The correct location is §5.4.1 (Table 5.1) + Appendix A §A.4.

### 4.3 Empirical confirmation (T274, small-goban sweep)

T274's empirical half (D014 descope: 2×2, 3×2, 3×3; 4×4 analytic-only) confirmed:
- L/H tables are bit-identical across five TIE values {0, +2, −2, +16, −16} at
  every goban size — the fixpoint is TIE-free by construction, now empirically
  confirmed on every state of three gobans.
- V = clamp(TIE, [L,H]) exactly at every root and every state; violations=0.
- At 4×4 (analytic): V_B(TIE) = clamp(TIE, [1,16]), V_W(TIE) = clamp(TIE,
  [−16,−1]). Only TIE=+2 gives V_B=+2, at which V_W=−1 ≠ −2 — no single flat
  TIE reproduces the colour-symmetric (+2,−2) anchor. The anchor requires a
  per-side tie (or a different rule), which is what MIGOS's pass-difference
  cycle resolution provides.

### 4.4 Disposition

**Corrected 2026-08-03 (T279 absorption):** `GLOBAL.TIE-MIGOS` → FALSE-AS-SCOPED;
`GLOBAL.FIXPOINT-VS-SEARCH` → CLAIMED with corrected content. `4x4.BASICKO-TIE`
and `PROGRESS.md` §4.2 were already corrected by T271/T275; the "not a bug"
withdrawal stands. The prior "basic ko vs PSK" explanation was refuted by
`GLOBAL.MIGOS-RULE`; the replacement "tie-resolution" explanation was refuted
by the primary sources; the surviving explanation is that the +2 anchor is a
different game (cycle resolution by pass-difference or SSK).

**The 4×4 fresh-start root under our ruleset (basic ko, flat TIE=0) is +1.**
This agrees with MIGOS's basic-ko result. The #2 auditor gate is still owed
for our own value.

---

## 5. Register rows minted by this file

| ID | scope | claim | status | evidence |
|---|---|---|---|---|
| `GLOBAL.Z` | all | The theorem as stated in §1 | CLAIMED | this file |
| `GLOBAL.AXIOM-GEOM` | all | A1 — Goban geometry | CLAIMED | this file |
| `GLOBAL.AXIOM-STONE` | all | A2 — Stone placement and alternation | CLAIMED | this file |
| `GLOBAL.AXIOM-CAPTURE` | all | A3 — Capture | CLAIMED | this file §2 |
| `GLOBAL.AXIOM-SUICIDE` | all | A4 — Suicide prohibition | CLAIMED | this file §2 |
| `GLOBAL.AXIOM-PASS` | all | A5 — Pass | CLAIMED | this file §2 |
| `GLOBAL.AXIOM-FORCEDPASS` | all | A6 — Forced pass | CLAIMED | this file §2, Amendment 3; `docs/evidence/ORACLE-V2/build-T184-2026-08-01.stdout:162` |
| `GLOBAL.AXIOM-BASICKO` | all | B1 — Basic ko rule (k=1) | CLAIMED | this file §2 |
| `GLOBAL.AXIOM-KOSTATE` | all | B2 — Ko state encoding | CLAIMED | this file §2 |
| `GLOBAL.AXIOM-KOPASS` | all | B3 — Ko–pass interaction | CLAIMED | this file §2 |
| `GLOBAL.AXIOM-TERMINAL` | all | C1 — Termination (double-pass) | CLAIMED | this file §2 |
| `GLOBAL.AXIOM-AREA` | all | C2 — Area scoring (Tromp-Taylor as-stands; amended 2026-08-06, T400) | CLAIMED | this file §2; this file §7 Amendment 4; `[GLOBAL.ADR0003-AREA:PROVEN]` `[GLOBAL.S4:PROVEN]` |
| `GLOBAL.AXIOM-TIE` | all | C3 — Tie value TIE=0 | CLAIMED | this file §2 |
| `GLOBAL.AXIOM-SCORESIGN` | all | C4 — Score sign convention (Black-positive) | CLAIMED | this file §2; `[GLOBAL.INVSYM:PROVEN]` |
| `GLOBAL.AXIOM-STATE` | all | D1 — State tuple | CLAIMED | this file §2 |
| `GLOBAL.AXIOM-FRESHSTART` | all | D2 — Fresh-start root | CLAIMED | this file §2 |
| `GLOBAL.AXIOM-PASSSTATE` | all | D3 — Pass-state invariant | CLAIMED | this file §2; `[GLOBAL.PASS-NOKO:PROVEN]` |
| `GLOBAL.AXIOM-BELLMAN` | all | E1 — Bellman operator | CLAIMED | this file §2 |
| `GLOBAL.AXIOM-LH` | all | E2 — L/H fixpoint | CLAIMED | this file §2; `[GLOBAL.FP1:PROVEN]` `[GLOBAL.FP3:PROVEN]` |
| `GLOBAL.AXIOM-BRACKET` | all | E3 — Bracket semantics | CLAIMED | this file §2 |
| `GLOBAL.TIE-MIGOS` | all | The +1 vs +2 gap vs MIGOS II is a tie-resolution difference (TIE=0 vs MIGOS's long-cycle-tie) — **REFUTED by primary sources (T274, absorbed T279): MIGOS's long-cycle-tie value is 0 = ours (thesis §5.3.2; ICGA 2009 §3.3), and MIGOS's own basic-ko 4×4 result is +1 = ours (thesis Table 5.1); the +2 anchor is a different game (pass-difference cycle resolution, thesis Appendix A §A.4), not a different tie constant** | FALSE-AS-SCOPED | this file §4; T274/T279; `[GLOBAL.MIGOS-RULE:PROVEN]` refutes the "basic ko vs PSK" explanation |
| `GLOBAL.FIXPOINT-VS-SEARCH` | all | Fixpoint vs search is a computational-method difference, not a ruleset difference; only explains the gap if tie semantics are first aligned | CLAIMED | this file §4 |

**Status convention:** All freshly-minted axiom claim IDs are CLAIMED, not
PROVEN — a written axiom is not proven by writing it. Of the two MIGOS
adjudication rows, `GLOBAL.TIE-MIGOS` is FALSE-AS-SCOPED (refuted by primary
sources, T274, absorbed T279 — §4.2/§4.4 above and CLAIMS.md:421 agree) and
`GLOBAL.FIXPOINT-VS-SEARCH` is CLAIMED pending independent verification.

---

## 6. Scope boundaries

- **In scope for epic-01-markovian:** the theorem Z, axioms A1–E3 (now A1–A6),
  the requirement tree nodes Z through Z-COMPLETE, the MIGOS adjudication.
- **Explicitly out of scope (this task):** mapping all 282 register rows onto
  the tree (follows in its own task); any code change, battery, or kernel
  extraction (Phases 1–4); re-auditing the register; claimlint fix (separate);
  regenerating claimlint calibration (baseline recorded before edits).
- **Explicitly out of scope (model):** handicap stones and arbitrary-start
  positions. The census seeds only the empty goban, for either side, at
  `passes=0` (`src/exp6_solve.zig:964-969`, pinned `082433e`). There is no
  mechanism for a non-empty starting position and no handicap concept. This
  is a decided scope boundary, not an oversight: the model solves the complete
  game from the natural fresh-start root, and non-standard starts were
  considered and excluded.

---

## 7. Amendment log

### Amendment 1 — 2026-08-02 (dspro/T275, Orcha verification)

Three defects found by reading the axioms against each other and against the
register. Fixes:

1. **A5 — "does not affect ko" → "clears the ko point."** A5 contradicted
   B2/B3, which correctly state that a pass clears ko
   `[GLOBAL.PASS-NOKO:PROVEN]`. A5 now says a pass clears the ko point (sets
   it to `none`).
2. **B1 — "one ply earlier" → "two plies earlier."** A basic-ko recapture
   recreates the goban position from two plies earlier (before the opponent's
   capture), not one. The ko-defect precedent (ADR-0013) makes this class of
   error load-bearing.
3. **§4.3 — "not a bug" withdrawn.** The +1-vs-+2 miss is unexplained; the
   leading hypothesis was tie semantics `[GLOBAL.TIE-MIGOS:FALSE-AS-SCOPED]`, the live
   alternative is a defect `[GLOBAL.FIXPOINT-VS-SEARCH:CLAIMED]` candidate
   (b). The +2 acceptance criterion is not met. Falsification test registered
   as T274.

### Amendment 2 — 2026-08-02 (`Orchestrator`, verification of Amendment 1)

Amendment 1's items 1 and 3 are accepted as made. Item 2 — B1's ply count — was
changed to "two plies" **without a derivation**, on the amending seat's authority
rather than on shown work. The conclusion is right (the sequence is now written out
under §2's B-block), but agreeing with a dispatcher is not verifying, and an axiom
that later phases are built on may not rest on that. Two corrections here:

1. **The B1 derivation is written into §2** — P₀/P₁/P₂ named, so the ply count can
   be checked by reading rather than by trusting. The mechanized check remains
   T273's differential run against the seventeen existing ko copies.
2. **The identity line is restored to the prescribed template**, and the
   Orchestrator's earlier criticism of it is withdrawn. T271 wrote
   `Model: not stated at dispatch`, which is **exactly** what
   `docs/infra/delegation/DELEGATEE.md` prescribes when a worker was not told its
   model — correct, not a lapse. Amendment 1 then replaced it with
   "Model: DSPro/T271", which puts an *identifier* in a *model* field. The model
   is now known and normalized: `deepseek-v4-pro` (the labels `dspro`, `DSPro`,
   `DeepSeek-Pro`, `DeepSeek-v4-Pro` all denote it; `dsflash` and friends denote
   `deepseek-v4-flash`). Human's ruling, 2026-08-02.

Also noted, not fixed here: T275 closed `pass` without the
`findings/T275-*.json` its brief required, and nothing refused the close — the
deliverable check only knew about `AXIOMS.md`. Future briefs list the findings file
in `deliverables=` so `managent done` enforces it.

### Amendment 3 — 2026-08-03 (deepseek-v4-pro/T285)

Two additions, both raised by T266 after its own task closed:

1. **A6 — Forced pass.** A player with no legal placement passes, and that
   forced pass is indistinguishable from a voluntary one: it clears the ko
   point, increments the pass count, and counts toward double-pass termination.
   This is a rules choice — rulesets differ on whether a player unable to place
   must pass — and is the choice made at `src/exp6_solve.zig:926-929` (pinned
   `082433e`), which emits the pass edge unconditionally. The axiom was always
   implicit in the code but unstated in the document. Added as A6, claim ID
   `GLOBAL.AXIOM-FORCEDPASS`. The artifact records 516,242 terminal-bit states
   at 4×4 where a side cannot place (build T184, 2026-08-01,
   `docs/evidence/ORACLE-V2/build-T184-2026-08-01.stdout:162`).

2. **Scope statement — handicap and arbitrary-start.** The census seeds only the
   empty goban for either side (see §6). The model has no handicap concept and no
   arbitrary-start concept. This was a decided exclusion, not an oversight; it is
   now stated explicitly in §6.

### Amendment 4 — 2026-08-06 (flash/T400)

**C2's prose described a different terminal-scoring function than the one solved.** The
axiom text ended *"Stone count alone is insufficient — dead stones are removed before
scoring and this axiom delegates to Benson for the definition of 'alive.'"* The code the
tables were built with does no such thing: `area_score` (`src/rules.zig:126`, port of
`terminal.area_score`) is pure Tromp-Taylor — every stone counts for its colour, an
empty region counts only when it borders exactly one colour, nothing is removed, Benson
is never called. The retrograde builder scores C1 double-pass terminals with exactly
this function (`src/retro.zig:1862`), ADR-0020 states the solved rule as "Tromp-Taylor
area scoring", and a committed test asserts the as-stands behaviour ("area counts it
regardless", `src/rules.zig`). The operator's question 2026-08-06 ("Does Benson-life/
death still apply at the end?") surfaced the gap. **Adjudicated option (a): the code is
the game** — nobody believes the shipped tables scored the wrong function (option (b));
the prose is the odd one out, not the values: the tables cross-validate against MIGOS
anchors, ADR-0020 names the solved rule, and the committed tests assert as-stands
scoring. C2 now states the Tromp-Taylor as-stands reading and names where Benson IS
load-bearing instead: the ADR-0006 eye-prune, `is_settled` terminal detection (which
positions get scored — never how; the WZO2 builder's seed phase, the forward search,
and GTP all use it), and resign logic. Scoring semantics
only — no values change (optimal lines already remove dead stones by play before
consenting to the terminal). Pinned by a new C2-contract regression test in
`src/rules.zig` ("C2 terminal scoring is Tromp-Taylor as-stands: no dead-stone
removal"): a terminal with an obviously-dead invader counts the invader's stone and
neutralises the shared empty region — no removal.
