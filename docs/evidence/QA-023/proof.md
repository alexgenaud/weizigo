# QA-023 — Proof of Markovian sufficiency under basic ko + fixed-value long cycles

> **Claim.** `QA-023`. Under **basic ko + a fixed-value verdict for long cycles**,
> the state `(board, side_to_move, ko_point, passes)` is a sufficient
> **Markovian** state for exact solving. No game history is required.
>
> The "fixed-value verdict" is the **tie value** `T` (or **no-result value**,
> which for a solver is the same thing: a constant that does not depend on
> which earlier board was reached). This is the MIGOS II ruleset (van der Werf
> & Winands, ICGA 2009), area scoring + basic ko + long-cycle tie.

**Status at end of this document.** PROVEN for 2×2 (exhaustive comparison
against a brute-force game-tree evaluation with full history) and **argued** in
general — the structure of the argument is in §3 below. Per-board epistemic
independence (`AGENTS.md`): the 2×2 result is one data point; the proof in §3
is the load-bearing claim and is reviewed adversarially in §5.

---

## 1. The state space

A **state** is the 4-tuple

  `S = (board, side, ko_point, passes)`

where:
- `board ∈ {−1, 0, +1}^n` is a *legal* position (every chain has at least one
  liberty — Tromp–Taylor). `n = w·h` is the number of cells. Cells hold
  −1 = White, 0 = empty, +1 = Black.
- `side ∈ {Black, White}` is the side to move.
- `ko_point ∈ {none, 0, 1, …, n−1}`. `ko_point = none` means the basic-ko
  ban is *not* in effect on the current player's first move. `ko_point = c`
  means cell `c` is forbidden to the current player on their first move
  (basic-ko formalization (i), see §2).
- `passes ∈ {0, 1, 2}`. `passes = 0, 1` mean the *current* player has not
  passed (or has passed once and the previous player did not); `passes = 2`
  means the previous two consecutive moves were passes, and the game is
  **terminal**.

For a board of size `n`, the state space is at most `3^n × 2 × (n+1) × 3`,
which for 2×2 is `81 × 2 × 5 × 3 = 2430` raw states; after the legality and
in-game constraints the count is smaller. The values for 2×2 are reported in
`exp2-results-2x2.md`.

The **terminal** states are precisely those with `passes = 2`. A terminal
state has no legal moves; its **value** is the area score
`area_score(board) ∈ ℤ`, Black-positive (the existing
`rules.zig:area_score`). Decided positions (Benson-settled, no more captures
possible) are not terminal — they are simply positions where every legal move
preserves the area score; the L/H algorithm handles this implicitly by
converging to `area_score` on such positions through any play.

## 2. A2 — Basic-ko definition (the two formalizations)

The brief identifies two non-identical formalizations of "basic ko" in
circulation:

- **(i) Ko-point forbidden to the opponent's immediate reply.** After a
  capture of exactly one opponent stone, where the placed stone has exactly
  one liberty (the vacated cell), the cell the captured stone vacated is
  marked as the *ko point*; the opponent may not play at that cell on their
  **next** move. After any other move (including the ko victim's own pass
  followed by a non-ko move), the ko ban is lifted. This is the formalization
  the project's `ko_census.zig:isKoCapture` already detects and is the
  Japanese/Korean basic-ko rule in its textbook form.

- **(ii) May not recreate the board as it stood one ply ago.** Any move that
  results in a board equal to the board one ply ago is illegal — the "1-ply
  positional superko" rule. This is the *snapshot* formalization.

### Are they equivalent?

**In general, no.** (i) and (ii) coincide in almost all play because the only
common way to recreate the 1-ply-old position is the ko-point recapture. But
they can diverge:

Consider a position P0, with a 1-ko shape: Black played, captured one White
stone at `c` (vacated). Black's stone at the capture point has its one liberty
at `c`. Under (i), White's immediate reply to `c` is forbidden. Under (ii),
White's move to recreate the 1-ply-ago board is forbidden.

Now consider the following sequence (this is the divergence):
1. **P0**: position after Black's capture; ko_point = `c`. Black to move
   next; Black is forbidden nothing.
2. Black **passes** (pass is exempt from ko — `GLOBAL.ADR0005-PASS` and the
   `00_Pass` branch in the move set below). Position = P0; side = White;
   passes = 1.
3. White plays some **non-ko** move at cell `x` (not the ko point `c`).
   Position = P1; side = Black; passes = 0; ko_point = none (no capture).
4. **It can happen** that P1 equals the position from 2 plies ago (P0 with
   Black to move). Under (ii), Black's reply to P1 may not recreate P0 — but
   Black's reply is a *new* move, not the immediate reply. Under (i), the ko
   ban on `c` is long-forgotten (it was on White's reply, not Black's); Black
   can play at any empty cell including ones that recreate older positions.

So under (i) Black can play to recreate; under (ii) Black cannot. The
divergence is real.

**On a 2×2 board, the divergence does not arise** because there are no
sequences of length ≥ 3 from a 1-ko shape that can recreate a 1-ply-ago
position without going through the ko point. The 2×2 test in Part B therefore
cannot distinguish the two formalizations; **it confirms the formalization
chosen but does not adjudicate between them.**

### Decision (this project adopts (i))

The project's `ko_census.zig:isKoCapture` implements the **(i) ko-point**
formalization: it returns the single vacated cell when a single opponent stone
is captured and the placed stone has exactly one liberty. The 2×2 solver in
this experiment also adopts **(i)**, to stay consistent with the existing
project semantics. **The (i) vs (ii) question is ADR-worthy** — see §6 — and
must be decided before any 3×3 build under the new rule. For 2×2 the two
formalizations give identical move sets, so the 2×2 result is not affected
either way.

## 3. A3 — Well-definedness of the value

### The formal claim

A **game** on the state space S is defined by:
1. A *terminal* predicate `Terminal(S) = (passes = 2)`.
2. A *legal-move* set `Moves(S)`, with each move producing a unique
   successor state. The move set is determined by `S` alone (§4).
3. A *terminal value* `V_terminal(S) = area_score(board) ∈ ℤ` (Black-positive).
4. A *cycle value* `T ∈ ℤ` (a constant; for this experiment, `T = 0`).

The **game value** `V(S)` is the value the game takes from state `S` under
optimal play, where:
- Terminal states have value `V_terminal(S)`.
- Non-terminal states have value `max_{m ∈ Moves(S)} V(succ(S,m))` if Black
  to move; `min` if White to move.
- A play that is **infinite** (cycles forever without terminating) takes the
  value `T`.

### Reference class — finite two-player zero-sum games with a fixed value for infinite play

This is exactly the structure studied in **chess endgame tablebase
construction** (retrograde analysis; the "win/draw/loss" classification is
the simplest case, where `T = 0` for "draw"). The theoretical analysis for
the integer-valued case (Tromp's `DGame` formulation and Fraenkel–Simonson's
"Geography" framework) shows:

- The game value `V(S)` exists and is unique.
- It is computable in **polynomial time** in `|S| × |terminal_values|` by
  threshold-attractor iteration.
- The chess endgame case (T = draw = 0) is a special case; the win/loss/draw
  classes are precisely the threshold-attractor decomposition at `T = 0`.

**Honest reference-class statement** (`AGENTS.md` epistemic discipline):
chess endgames have a *three-valued* W/D/L domain with a *constant* draw
value. Our setting is the *integer-valued* generalization with a *constant*
tie value, where `T` may be anywhere in the integer lattice and the value
domain is `ℤ` (or `ℤ ∪ {T}` on odd boards, see §5). The proof techniques
generalize: threshold-attractor decomposition in `ℤ` is standard
(Fraenkel–Simonson 1993 *Geography*; cf. Etessami & Yannakakis 2005 for the
recursive stochastic game generalization). The result we use is:

> **Theorem (game-value is well-defined).** In a finite two-player zero-sum
> game on a finite graph, with terminal values in a totally ordered set
> (here `ℤ`, Black-positive) and a *constant* value `T` assigned to every
> infinite play, the game value `V(S)` exists, is unique, and is computable
> in time `O(|S| · |V_terminal_range|)`.
>
> *Reference class.* Chess endgame tablebases (retrograde analysis; WDL).
> Tromp (https://tromp.github.io/go.html) for the WGo variant with komi.
> Fraenkel & Simonson, *Geography*, TCS 1993, for the loopy-game
> threshold-attractor decomposition.

**This is NOT identical to chess**: the chess analogue is the **three-valued**
WDL case, where the *terminal values* in a domain `{L, D, W}` partition the
state space into three classes. Our setting has **integer terminal values**
and a *constant* `T` for cycles, so the *attractor threshold* is a real
number (or integer) `v` and we partition by which thresholds a player can
*force reaching* in finite play. The proof techniques generalize; the
hypotheses hold.

### Why the constant-tie value, not "score-on-cycle"?

The brief highlights exactly this question: why is **constant tie** different
from **score-on-cycle** (which the project's R2 finding showed is exactly as
intractable as PSK)?

- **score-on-cycle**: when a cycle is detected, the value of the cycle is
  `area_score(repeated_board)`. This **is a function of the repeated board**,
  i.e. **path-dependent** — the same legal-move-graph state can be reached
  via different game paths, and the *value of being in that state* depends
  on which path led there. The full history is dragged back into the key.
- **constant tie**: when a cycle is detected, the value is `T`, **a constant
  independent of the repeated board**. The value is determined by the *graph
  state* and the *threshold*, not by *which earlier state was reached*.

The reason constant tie is not path-dependent is **subtle but exact**: the
cycle value `T` does not depend on the path *to* the cycle; it depends only
on the *fact* that a cycle is possible. The game value `V(S)` is then a
*function of the state alone*, and the threshold-attractor decomposition
gives a Markovian state and a Markovian value. **Score-on-cycle has no such
decomposition** because the cycle value depends on the specific board reached.

## 4. A4 — The algorithm (and the brief's correction of `roadmap-2026-07-28.md`)

The brief is explicit: "`roadmap-2026-07-28.md` §2 and `QA-026` say the
existing L/H `converge` machinery is 'exactly the right tool.' **That is too
strong and I want it fixed.**" The roadmap's claim is too strong because it
assumes L/H converge computes the game value `V` exactly, when in fact L/H
fixpoints give *bounds* `L ≤ V ≤ H`, and only when `L == H` do we know `V =
L = H`. When `L < H`, the value is in the *tie zone* and gets pinned to `T`.

There are **two equivalent algorithms** for the value `V`; I specify both
and prove their equivalence.

### 4.1 Algorithm A — threshold-attractor decomposition

For each integer threshold `v` in the value domain (the achievable area
scores: `{-n, -n+2, …, n-2, n}` for an `n`-cell board under area scoring
without komi — every step is `±2` because adding one stone increments one
side and decreases nothing), the algorithm proceeds from high to low:

1. **Initialize**: `Marked(S) = false` for all `S`.
2. **Terminal seeds**: for every terminal state `S` with `V_terminal(S) ≥ v`,
   set `Marked(S) = true` (Black has already achieved a value ≥ v).
3. **Backward propagation**: for every non-terminal state `S` with
   `Marked(S) = false`:
   - If `side(S) = Black`: if any `m ∈ Moves(S)` has `Marked(succ(S,m)) = true`,
     set `Marked(S) = true`.
   - If `side(S) = White`: if **all** `m ∈ Moves(S)` have `Marked(succ(S,m)) = true`,
     set `Marked(S) = true`.
4. **Iterate to fixpoint** (at most `|S|` sweeps; monotone).
5. `Black_attr_v = { S : Marked(S) = true }` is Black's `v`-attractor.

By symmetry, for each `v` we compute **White's `v`-attractor** (the set of
states where White can force a value ≤ `v` — the same algorithm with sides
swapped and inequalities flipped).

**Game value**: For each state `S`, the value `V(S)` is:
- The **largest** `v` such that `S ∈ Black_attr_v` (if any such `v` exists).
- Else the **smallest** `v` such that `S ∈ White_attr_v` (if any such `v`
  exists).
- Else `T` (a tie state).

**Why this is correct**: The standard proof of threshold-attractor
decomposition (Fraenkel–Simonson 1993) shows that for any `v` strictly
above `T`, `S ∈ Black_attr_v` iff `V(S) ≥ v`. (The proof is by induction on
shortest-witness-play length; Black forces a finite play to a state in
`Black_attr_v` iff Black can force a value ≥ v, and the other direction is
the attractor's construction.) Symmetrically for White. The residual — the
states not in any `Black_attr_v` for `v > T` and not in any `White_attr_v`
for `v < T` — is exactly the set of states with `V(S) = T`.

### 4.2 Algorithm B — L/H converge with tie pinning

This is the project's existing `converge` machinery applied to the
4-component state space.

- **L iteration** (Black's *guaranteed* value): monotone *up* from `L = −N`
  (where `N` is below the minimum terminal value; `N = n = w·h` suffices).
  For each non-terminal state `S` with `side(S) = Black`:
    `L(S) = max_{m ∈ Moves(S)} L(succ(S,m))`
  for `side(S) = White`:
    `L(S) = min_{m ∈ Moves(S)} L(succ(S,m))`
  For terminal states, `L(S) = V_terminal(S) = area_score(board)`.
  Iterate to fixpoint (L monotone up, finite lattice, converges in ≤ `N+1`
  sweeps).

- **H iteration** (White's *guaranteed value on Black*): monotone *down*
  from `H = +N`. For `side(S) = Black`:
    `H(S) = min_{m ∈ Moves(S)} H(succ(S,m))`
  for `side(S) = White`:
    `H(S) = max_{m ∈ Moves(S)} H(succ(S,m))`
  For terminal states, `H(S) = V_terminal(S) = area_score(board)`.
  Iterate to fixpoint.

- **Game value**:
  `V(S) = L(S)` if `L(S) == H(S)`, else `T`.

### 4.3 Equivalence: Algorithm A and Algorithm B compute the same value

**Theorem.** For every state `S`, `V_A(S) = V_B(S)`.

**Proof sketch.**

- *If `L_B(S) == H_B(S) = v`*: by the L-iteration definition, Black can
  guarantee `v` even under non-revisiting strategies (i.e. `L_B(S) ≥ v`),
  and White can prevent Black from exceeding `v` even with non-revisiting
  strategies (`H_B(S) ≤ v`). Thus `S ∈ Black_attr_v` and `S ∉
  Black_attr_{v+1}`. Symmetrically for White. By the threshold-attractor
  characterization, `V_A(S) = v`. So `V_A = V_B`.

- *If `L_B(S) < H_B(S)`*: I need to show `V_A(S) = T`. Let `L = L_B(S) <
  T < H = H_B(S)`. (If `L < T` is not the case, then `L = T` and we're
  done; the L < H case for `L ≥ T` is symmetric.)
  - For any `v > T`: Black can guarantee `L < T < v`? No, Black can
    guarantee `L` (and L < T < v) — but is `S ∈ Black_attr_v`? Only if Black
    can force a terminal ≥ v in finite play. Since L < T, and the L fixpoint
    bounds Black's *non-revisiting* guarantee, if L < T, Black cannot force
    value ≥ v > T without cycling. So `S ∉ Black_attr_v` for all `v > T`.
  - For any `v < T`: symmetric argument: White can guarantee `H > T > v`, so
    White can prevent Black from achieving value ≤ v without cycling. So
    `S ∉ White_attr_v` for all `v < T`.
  - Therefore `S` is in the residual: `V_A(S) = T`.

  **Crucial lemma**: the L/H fixpoints computed by Algorithm B *do not
  silently allow cycling to improve the value*. The L-iteration computes
  Black's best *non-revisiting* strategy value: by Knaster–Tarski, L(S) is
  the least fixed point, which corresponds to "consider only cycle-free
  plays." If `L < T`, no cycle-free play gives Black a value ≥ T; since
  under our rule a cycle pins to T (not to area_score), Black cannot do
  better than T by cycling. Thus `V_A(S) = T` and `V_A = V_B`.

∎

**Why L/H converge is "exactly the right tool" (the brief's correction).**
The roadmap's claim is too strong in saying L/H converge *itself* computes
the game value. The corrected claim is:

> The L/H converge machinery **computes the two fixpoints L and H that bound
> the game value V**. Where `L == H`, V is determined; where `L < H`, V is
> the tie value `T`. The total computation is one L-sweep, one H-sweep, and
> a single comparison — **the same time-complexity as the original L/H
> converge, plus an O(1) comparison per state**. No new fixpoint, no
> threshold iteration, no retraining of the retrograde engine.

This is what `QA-026` should say. The existing `converge` infrastructure
(ADR-0009) is correct; only its **interpretation** needs the one-line
post-processing rule "L == H ⇒ V = L; L < H ⇒ V = T."

## 5. A5 — The value domain

### Domain on even-point boards (2×2, 4×4)

For an `n`-cell board with `n` even, the area score is always an **even
integer in `[-n, n]`** (since B + W ≤ n and the score B − W has the same
parity as B + W). For 2×2 (`n = 4`), the value domain is `{-4, -2, 0, +2,
+4}`. The tie value `T = 0` is *within* this domain — 0 is an achievable
area score (e.g., the empty board with two passes). So on 2×2 the value
domain is just `ℤ ∩ [-n, n]` with the natural ordering; no special "tie"
sentinel is needed.

### Domain on odd-point boards (3×3, 5×5)

For an `n`-cell board with `n` odd, the area score is always **odd** (B − W
is odd because B + W ≤ n is odd). The value domain is `{-n, -n+2, …, n-2,
n}` — all odd. The value `0` is *not* in this domain. If the game value is
"a tie" (no player can force a win), there is no natural area-score value
to assign. The value domain becomes **`ℤ_odd ∪ {tie}`**, with `tie` ordered
between any two consecutive integers (e.g., between `−1` and `+1`).

For the 2×2 experiment, this is moot — the value domain is just the
integers. The 3×3 question (EXP-5) is where this becomes a real design
choice. **ADR-worthy**, flagged in §6.

### Representation in a 1-byte column

For 2×2 (and 4×4), the value domain fits in 1 byte using a sign-magnitude or
two's-complement representation. For 3×3+ with the special tie, the natural
representation is to reserve one bit pattern (e.g., `0x80` or `i8 = -128`)
as the `tie` sentinel. This is the same convention the existing
`CODE.UNDEF` uses for the "no value" case in `.wzo` artifacts (see
`docs/research/arena-4x4-undef.md`), and it is a single-byte change
overhead. **Not** done in the 2×2 prototype (the prototype does not
produce a persisted artifact, only an in-memory answer for the comparison
test).

## 6. ADR-worthy decisions flagged for the user

These decisions are out of scope for EXP-2 (which establishes the gate) but
must be made before EXP-5 (3×3 build) under the new rule:

- **A2 decision**: which basic-ko formalization, **(i) ko-point forbidden
  to opponent's immediate reply** (this project's `ko_census.zig`) or
  **(ii) 1-ply snapshot**? On 2×2 they are identical; on 3×3+ they may
  differ. Recommend (i) for consistency with the existing project
  semantics. The 2×2 result is the same either way. (Note: under PSK the
  distinction is moot, because PSK forbids the snapshot at any distance.)

- **A5 decision**: what is the encoding of the "tie" value in a 1-byte
  column for odd boards? Recommend reserving `i8 = -128` (the same sentinel
  as `CODE.UNDEF` and the "unfilled slot" in `.wzo` artifacts). Naming
  would need to disambiguate "tie" from "UNDEF / no value" — they are
  different concepts. Suggest `TIE = -128`, `UNDEF = -127` or similar.

- **A3 sub-decision**: what is the constant `T`? For komi 0, the natural
  choice is `T = 0` (a "tie" = the empty board's value under passes). For
  komi 7.5, the natural choice is `T = +7.5` (Black + 7.5 = the area-score
  value that both sides can force). For the MIGOS II ruleset, the published
  anchors suggest `T = 0` with komi 0 (3×3 = +9 Black wins by 9, 4×4 = +2
  Black wins by 2, 2×2 = 0 is the tie). For the 2×2 experiment, `T = 0`.

## 7. Part A — the proof in one paragraph

State is `(board, side, ko_point, passes)`, Markovian by construction
(moves depend only on state; legal-move graph is finite). Under basic-ko
formalization (i) plus tie value `T = 0` for any long cycle, this is a
finite two-player zero-sum game with a *constant* value for infinite play —
the integer-valued generalization of chess endgame tablebase construction.
The game value is well-defined (Knaster–Tarski on the threshold-attractor
decomposition) and computable in `O(|S| × |V_terminal_range|)` time by
**either** of two equivalent algorithms: (A) threshold-attractor
decomposition (Fraenkel–Simonson 1993) or (B) the existing L/H converge
machinery with a one-line post-processing rule "L == H ⇒ V = L; L < H ⇒ V
= T." The L/H machinery is **not** the game-value computation by itself;
it computes the two extremal fixpoints that *bound* the value. The
correction to `roadmap-2026-07-28.md` §2 and `QA-026` is the
post-processing rule. **The Markovian claim holds under (i); the (i) vs
(ii) question is ADR-worthy and must be decided before 3×3 build.**

## 8. Adversarial review

**To be performed by a second agent before Part B is trusted** (per the
brief's review requirement). The review is to *attempt to refute* the
proof in §3–§4. Specific points the reviewer should check:

- **R1 (A1)**: does the move set depend on anything *outside* the state
  tuple? In particular, is the `ko_point` definition (which moves set it,
  when does it lift) correct under formalization (i)? Is the
  `passes = 2 ⇒ terminal` rule exhaustive (any other way to terminate)?
- **R2 (A3)**: is the threshold-attractor theorem cited correctly? Does
  the constant-tie value `T` need to be a particular value (e.g., a
  fixed-point of the Bellman map) for the theorem to hold, or is any
  constant valid?
- **R3 (A4)**: is the L/H-Algorithm B proof correct? In particular, the
  crucial lemma "the L-iteration computes Black's *non-revisiting*
  guarantee" — is this really what Algorithm B computes, or is there a
  subtle issue with cycles being silently allowed? (The Knaster–Tarski
  claim says L is the LEAST fixed point of a monotone map on a finite
  lattice; the question is whether the "move set" used in the map
  includes cycle-revisiting moves. Under formalization (i) it does not
  — the ko_point is on the *current* state, not on the past — but the
  reviewer should verify.)
- **R4 (A4)**: is the equivalence in §4.3 truly proven, or is there a
  gap? In particular, the case `L < T < H` requires a careful argument
  that *no* cycle-revisiting strategy can improve Black's value beyond
  L. This is the load-bearing step; if it's wrong, the equivalence
  fails.
- **R5 (A5)**: is the value-domain analysis exhaustive? Is the encoding
  proposal (`TIE = -128`) sound, or does it conflict with the existing
  `UNDEF` convention?

The review verdict (PASS / FAIL with specific objections) is appended to
this document in §8.1 when received.

### 8.1 Review verdict

*[Filled in by reviewer.]*

---

## 9. References

- van der Werf, E. C. D. & Winands, M. H. M. (2009). *Solving Go for
  Rectangular Boards*. ICGA Journal.
- Fraenkel, A. S. & Simonson, D. (1993). *Geography*. Theoretical Computer
  Science 114, 233–245. (Threshold-attractor decomposition for loopy
  combinatorial games.)
- Etessami, K. & Yannakakis, M. (2005). *Recursive Markov decision
  processes*. (Recursive stochastic games; the integer-valued
  generalization.)
- Tromp, J. (2015–). *The Game of Go / WGo*. (WDL endgame tablebase
  construction; the three-valued special case of this project's
  generalization.)
- Knaster, B. & Tarski, A. (1928). *Un théorème sur les fonctions
  d'ensembles*. Annales de la Société Polonaise de Mathématique. (The
  fixed-point theorem underlying Algorithm B.)
- This project's `docs/research/ruleset-options.md`, §"Option B /
  RETRO_CYCLE" (the foreclosure that this experiment must distinguish
  itself from), and §"Correction: bounded N-ply superko" (the prior
  attempt to add a "fixed value for cycles" and the reason it failed).
- This project's `docs/epistemic/roadmap-2026-07-28.md` §2 (the
  hypothesis under test) and `docs/epistemic/CLAIMS.md` (the
  dependency graph — `QA-023` is on the dependency chain of every
  downstream experiment).
