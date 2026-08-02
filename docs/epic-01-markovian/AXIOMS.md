# AXIOMS — epic-01-markovian: theorem, axioms, and requirement tree

Task: T271 · Role: worker · Model: deepseek-v4-pro · Date: 2026-08-02
Amended by T275 (deepseek-v4-pro) and the Orchestrator — see the amendment log, §7.

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
| `GLOBAL.AXIOM-AREA` | **C2 — Area scoring.** At a terminal position, the score for Black is: Black stones on the goban + empty points in Black's surrounded territory. White's score is computed symmetrically. The game score is Black's score minus White's score. Territory is defined by Benson's unconditional-life theorem `[GLOBAL.S2:PROVEN]`. Stone count alone is insufficient — dead stones are removed before scoring and this axiom delegates to Benson for the definition of "alive." |
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
  - C2 Area scoring — delegates to Benson `[GLOBAL.S2:PROVEN]`, `[GLOBAL.ADR0003-AREA:PROVEN]`, `[GLOBAL.S4:PROVEN]`
  - [F]: a terminal position where area_score disagrees with the Benson +
    Tromp–Taylor definition.
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
  T267 (key-agreement invariant, outstanding).
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
    the table's own root value. `[CODE.WZO2-INCOMPLETE:PROVEN]` (estimated
    6.77M missing at 4×4 WZO2).
- **Z-COMPLETE-PASSES:** The passes dimension is fully enumerated.
  `[CODE.WZO2-INCOMPLETE:PROVEN]` — passes=1 entries missing for one side.

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

## 4. MIGOS tie-semantics adjudication

### 4.1 The contradiction

`4x4.BASICKO-TIE` (CLAIMS.md) explains the +1-vs-+2 miss against the MIGOS II
anchor as "a ruleset difference (basic ko vs PSK), not a bug." The register's
own PROVEN row `GLOBAL.MIGOS-RULE` establishes that MIGOS II plays **basic ko**
+ long-cycle-ties, NOT PSK. `4x4.ANCHOR` already records a prior correction for
exactly this conflation. A basic-ko build disagreeing with a basic-ko anchor
cannot be explained by "basic ko vs PSK."

`PROGRESS.md` repeats the same contradicted explanation at two locations:
the gate-chain table (§4.2) and the immediately following prose.

### 4.2 Candidate causes

The audit names two candidates. Each gets a register row.

#### Candidate 1: TIE=0 vs MIGOS tie semantics

Our build uses TIE=0 — every cycle is a draw. MIGOS II uses basic ko +
long-cycle-ties, but the *value* assigned to a long cycle is implementation
defined and not necessarily 0. If MIGOS resolves a long cycle with a value
other than 0, the two builds legitimately differ even though both use basic ko.

- **What our ruleset does on a tie:** Under loopy-game fixpoint semantics
  (ADR-0020), every cycle has value TIE=0. The fixpoint is the limit of Φ
  where: Black child value = max over moves of White's H; White child value
  = min over moves of Black's L. Cycles are not detected; the constant tie
  value emerges as the fixpoint on cyclic subgraphs. At 4×4 the root is
  bracket-valued [L=+1, H=+16] — the TIE=0 constant is consistent with L=+1
  but not forced by it.
- **What MIGOS does on a tie:** MIGOS II's ruleset is basic ko + long-cycle
  ties. The exact tie value is implementation-specific: MIGOS II is a
  *program*, not a ruleset `[GLOBAL.MIGOS-RULE:PROVEN]`. Van der Werf's PhD
  thesis (§6.4) records the 4×4 empty-goban value as +2. The +2 result is
  the output of a proof-number search with a specific long-cycle resolution.
  Both our build and MIGOS use basic ko; the difference is in how cycles
  beyond basic ko are valued.

**Register row:** `GLOBAL.TIE-MIGOS` — CLAIMED.

> The +1 (our TIE=0 build) vs +2 (MIGOS II) difference on the empty 4×4
> is a genuine ruleset difference in *tie resolution*, not in the ko rule.
> Both rulesets use basic ko (k=1); MIGOS's long-cycle tie value is not
> guaranteed to be 0 and is implementation-dependent. The "basic ko vs PSK"
> explanation in `4x4.BASICKO-TIE` and `PROGRESS.md` §4.2 is incorrect —
> MIGOS does not play PSK.

#### Candidate 2: Fixpoint vs search

Our build computes the loopy-game fixpoint by Bellman iteration. MIGOS II
uses proof-number search (PNS) on a game tree. These are different
computational methods applied to different (if similar) game definitions.

- **Loopy-game fixpoint:** The value at every state is the limit of Φ,
  defined simultaneously for all states. The Bellman operator iterates until
  zero-change; the result is the unique least/greatest fixpoint `[GLOBAL.FP1:PROVEN]`.
- **Proof-number search:** MIGOS II searches a single game tree from the
  root, with transpositions detected and long cycles resolved to ties.
  PNS proves bounds on the root value by search, not by global fixpoint
  iteration.

Under identical rules (basic ko, same tie value), a fixpoint and a search
should agree on the game-theoretic value. Since they disagree (+1 vs +2),
either: (a) the tie semantics differ, bringing us back to Candidate 1; or
(b) one of the two implementations does not compute its own declared value
correctly. Candidate 2 is therefore a **secondary** cause — it only explains
the gap if the tie semantics are first aligned.

**Register row:** `GLOBAL.FIXPOINT-VS-SEARCH` — CLAIMED.

> Fixpoint vs search is a computational-method difference, not a ruleset
> difference. Under identical rulesets, fixpoint and search must agree on
> game-theoretic values. The observed +1 vs +2 is therefore primarily
> explained by tie-semantics (Candidate 1), with fixpoint vs search as a
> secondary possible contributor only if both methods are verified correct
> under aligned tie rules.

### 4.3 Adjudication

**The +1-vs-+2 miss is unexplained.**

The "basic ko vs PSK" explanation in `4x4.BASICKO-TIE` and `PROGRESS.md` §4.2
is **falsified by the register's own PROVEN row** `GLOBAL.MIGOS-RULE`. MIGOS
plays basic ko, not PSK. Both our build and MIGOS play basic ko, so "basic ko
vs PSK" cannot explain a basic-ko-vs-basic-ko discrepancy.

The **leading hypothesis** is tie semantics: our TIE=0 differs from MIGOS's
implementation-specific long-cycle-tie value `[GLOBAL.TIE-MIGOS:CLAIMED]`.
The **live alternative** is a defect in our build — one of the two
implementations does not compute its own declared value correctly — which is
Candidate 2's branch (b) `[GLOBAL.FIXPOINT-VS-SEARCH:CLAIMED]`. Neither
hypothesis has been eliminated; the miss has not been explained.

The roadmap's **+2 acceptance criterion is not met**
(`roadmap-2026-07-28.md:227-232`): +2 was the condition for a "finally
legitimate comparison," and the 4×4 root is +1, not +2. Until the gap is
explained, the build does not pass its own acceptance gate.

**Falsification test for `GLOBAL.TIE-MIGOS`** (registered as T274, not run
here): re-run the 4×4 root with only the tie constant changed, and read van
der Werf's thesis §6.4 for MIGOS's actual long-cycle resolution. If a
different tie constant reproduces +2, the tie-semantics hypothesis is
confirmed. If no tie value reproduces +2, Candidate 2(b) — a defect —
is what remains.

The statement "not a bug" is withdrawn from both `PROGRESS.md` locations. It
rested on `GLOBAL.TIE-MIGOS:CLAIMED` as if CLAIMED were PROVEN, repeating
exactly the shape GRAND-AUDIT §1d objected to. A CLAIMED hypothesis does not
support a "not a bug" disposition.

### 4.4 Disposition of PROGRESS.md lines 213, 218

**Corrected by T271 (2026-08-02):** the "basic ko vs PSK" explanation was
replaced with the tie-resolution explanation and `GLOBAL.TIE-MIGOS` /
`GLOBAL.FIXPOINT-VS-SEARCH` citations.

**Further corrected by T275 (2026-08-02, Amendment 1):** "not a bug" is
withdrawn — it rested on `GLOBAL.TIE-MIGOS:CLAIMED` as if CLAIMED were PROVEN.
The miss is now recorded as unexplained, with the leading hypothesis and live
alternative both stated. The +2 acceptance criterion is noted as unmet (T274).

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
| `GLOBAL.AXIOM-BASICKO` | all | B1 — Basic ko rule (k=1) | CLAIMED | this file §2 |
| `GLOBAL.AXIOM-KOSTATE` | all | B2 — Ko state encoding | CLAIMED | this file §2 |
| `GLOBAL.AXIOM-KOPASS` | all | B3 — Ko–pass interaction | CLAIMED | this file §2 |
| `GLOBAL.AXIOM-TERMINAL` | all | C1 — Termination (double-pass) | CLAIMED | this file §2 |
| `GLOBAL.AXIOM-AREA` | all | C2 — Area scoring (delegates to Benson) | CLAIMED | this file §2; `[GLOBAL.S2:PROVEN]` `[GLOBAL.ADR0003-AREA:PROVEN]` |
| `GLOBAL.AXIOM-TIE` | all | C3 — Tie value TIE=0 | CLAIMED | this file §2 |
| `GLOBAL.AXIOM-SCORESIGN` | all | C4 — Score sign convention (Black-positive) | CLAIMED | this file §2; `[GLOBAL.INVSYM:PROVEN]` |
| `GLOBAL.AXIOM-STATE` | all | D1 — State tuple | CLAIMED | this file §2 |
| `GLOBAL.AXIOM-FRESHSTART` | all | D2 — Fresh-start root | CLAIMED | this file §2 |
| `GLOBAL.AXIOM-PASSSTATE` | all | D3 — Pass-state invariant | CLAIMED | this file §2; `[GLOBAL.PASS-NOKO:PROVEN]` |
| `GLOBAL.AXIOM-BELLMAN` | all | E1 — Bellman operator | CLAIMED | this file §2 |
| `GLOBAL.AXIOM-LH` | all | E2 — L/H fixpoint | CLAIMED | this file §2; `[GLOBAL.FP1:PROVEN]` `[GLOBAL.FP3:PROVEN]` |
| `GLOBAL.AXIOM-BRACKET` | all | E3 — Bracket semantics | CLAIMED | this file §2 |
| `GLOBAL.TIE-MIGOS` | all | The +1 vs +2 gap vs MIGOS II is a tie-resolution difference (TIE=0 vs MIGOS's long-cycle-tie), not a ko-rule difference | CLAIMED | this file §4; `[GLOBAL.MIGOS-RULE:PROVEN]` refutes the "basic ko vs PSK" explanation |
| `GLOBAL.FIXPOINT-VS-SEARCH` | all | Fixpoint vs search is a computational-method difference, not a ruleset difference; only explains the gap if tie semantics are first aligned | CLAIMED | this file §4 |

**Status convention:** All freshly-minted axiom claim IDs are CLAIMED, not
PROVEN — a written axiom is not proven by writing it. The two MIGOS
adjudication rows are CLAIMED pending independent verification.

---

## 6. Scope boundaries

- **In scope for epic-01-markovian:** the theorem Z, axioms A1–E3, the
  requirement tree nodes Z through Z-COMPLETE, the MIGOS adjudication.
- **Explicitly out of scope (this task):** mapping all 282 register rows onto
  the tree (follows in its own task); any code change, battery, or kernel
  extraction (Phases 1–4); re-auditing the register; claimlint fix (separate);
  regenerating claimlint calibration (baseline recorded before edits).

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
   leading hypothesis is tie semantics `[GLOBAL.TIE-MIGOS:CLAIMED]`, the live
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
