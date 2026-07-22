# 0009 — Retrograde engine: successor-sweep value iteration with two-sided certification

Date: 2026-07-18 · Status: **accepted** (design); 3x3 prototype this session

The #6' design ADR (ADR-0007 made retrograde the engine; ADR-0008 fixed the
stored semantics; `research/oracle-3x3.md` measured forward filling intractable
even at 3x3). This ADR answers the two load-bearing questions: (a) how values
propagate backward (predecessor generation vs something else), and (b) how
ko/superko/GHI is represented without a history parameter. It also freezes the
oracle record schema and restates the sign conventions.

## The graph model

Game states are nodes `(position, side, passes ∈ {0,1})` over LEGAL positions.
Terminals: `is_settled(pos)` (value = `area_score(pos)`, any side/passes) and
the second consecutive pass (value = `area_score(pos)`). Edges: board moves
(to `(child, -side, 0)`) and pass (to `(pos, -side, passes+1)`). Pass nodes
are stored, not eliminated; the Bellman equations are

    V1(pos,s) = opt_s( { V0(child,-s) }, score(pos) )          // passes=1
    V0(pos,s) = opt_s( { V0(child,-s) }, V1(pos,-s) )          // passes=0

where `opt_s` = max for Black (s>0), min for White. The oracle's stored value
is `V0` — exactly ADR-0008's fresh-start query shape. **Superko does not appear
in the equations at all**; what it would have contributed is captured by the
certification below.

## Decision 1: successor sweeps, NOT predecessor generation

Values propagate by repeated Bellman sweeps over the colex space, computing
each node's update from its FORWARD successors (the ordinary move generator).
No un-move / un-capture code is ever written.

Why: predecessor generation in Go must invert captures — for every candidate
un-move, enumerate every subset of opponent stones the move might have removed,
then re-validate. That is a large new kernel with its own failure modes,
impossible to cross-validate against anything (nothing else generates
predecessors). The forward move generator, by contrast, is the most-validated
code in the repo (`rules.zig`, cross-checked move-for-move against Gen-1).
Captures make retrograde a fixpoint rather than a single layered pass EITHER
way (a move from layer k lands in layer k+1−c, c stones captured — back-edges),
so predecessor lists would not even buy a one-sweep guarantee.

Cost: sweeps × nodes × branching. Sweep order is stone-count DESCENDING
(children of no-capture moves are one layer up, so Gauss–Seidel picks up fresh
values within a sweep); iteration repeats until a full sweep changes nothing.
The sweep count is a MEASURED quantity (3x3 first, then 4x4) — it is the
scaling number for 5x5, where each sweep must stream layer blocks from disk.

## Decision 2: ko/GHI = two-sided fixpoint certification (L/H)

The Bellman operator on this cyclic graph has many fixpoints; the choice of
fixpoint IS the cycle rule. We compute two:

- **L (pessimistic)**: all non-terminals seeded −n (worst for Black), swept
  monotonically UP to the least fixpoint. Interpretation: every unresolved
  cycle is scored maximally anti-Black.
- **H (optimistic)**: seeded +n, swept DOWN to the greatest fixpoint: every
  cycle scored maximally pro-Black.

Both iterations are monotone (Bellman is monotone; seeds are below/above), so
convergence is guaranteed; each converged table is checkable by one
zero-change sweep.

**Certification: where `L == H`, the value cannot depend on any cycle rule —
in particular not on superko bans or arrival history — so it equals the
fresh-start value (and the mid-game value under ANY ban set).** These nodes
are the oracle's certified core. Where `L < H` (Black-favoring cycles and
White-favoring cycles resolve differently), the node is **ko-sensitive**:
flagged, bounded by `[L, H]`, and its exact fresh-start value is computed by
the **finisher** — a forward fresh-start solve (`oracle.zig`, full history +
`ko_ref` rule) whose memo is pre-seeded with every certified value. The
forward search then terminates the moment it leaves the ko-tangled region,
which is what makes it tractable where the cold forward build was not.

### The honesty clause (known theoretical leak)

The certification argument has one unproven step. Sketch of the sound part: a
memoryless strategy achieving L forces termination, so no NODE repeats along
its plays, so the strategy's own side never needs to recreate a position it
created before (recreating position q as Black always lands in node `(q,W,0)`
— a node repeat). Bans that bite the OPPONENT only help. The leak: the
strategy may want to create a position the opponent created earlier (landing
in a not-yet-visited node of the other parity), or the fresh-start seed
position itself — those moves are PSK-banned and the memoryless argument does
not cover them. So `L ≤ fresh-start ≤ H` and the `L==H ⇒ exact` claim are
**strong structural evidence, not a theorem** (this is the GHI problem's
irreducible core; Kishimoto–Müller dependency sets are the known exact-but-
expensive alternative). Per project doctrine the gap is closed EMPIRICALLY:

1. **Exhaustive ground truth at 2x2 and 3x2**: pure history-correct forward
   fresh-start solve of EVERY legal (position, side), no memo, compared to the
   full retrograde+finisher table — must be equal on every slot.
2. **3x3**: published anchors (empty = B+9 centre, 1.B side = +3, 1.B corner
   = −9 — deep, whole-tree checks); no-memo forward spot checks on ≥6-stone
   roots; the residue set itself spot-checked hardest.
3. `oracle.zig`'s standing battery: exhaustive colour-inversion + dihedral
   symmetry over the final table AND over the flags (ko-sensitivity is
   symmetric), memo-consistency during the finisher (a finisher memo write
   into a certified slot must agree — free cross-check every run).

### Symmetry of L and H under colour inversion

Negating colours swaps max/min roles, hence swaps the fixpoints:
`L(-pos, -side) == -H(pos, side)` — the exhaustive inversion check must pair
L with H, not L with itself. (Dihedral transforms stay within each table.)
The final certified/finished values satisfy the plain ADR-0008 identity.

## Decision 3: NO eye-prune in the retrograde graph

The retrograde move loop uses the FULL legal move set — `is_own_eye` is not
applied. Value iteration has no reopening problem (no DFS re-descends
anything; a capture back-edge is just a table read), so the ADR-0006 prune is
unnecessary for tractability here. Consequences:

- **Resolves the ADR-0007 eye-prune-vs-coverage tension: coverage is total.**
  Every legal (position, side) gets a slot and a value; the prune never
  removes positions from the oracle.
- The forward cross-checks (finisher, ground truth, spot checks) DO use the
  prune (they need it, per ADR-0006). Any value disagreement would therefore
  falsify ADR-0006's weak-dominance claim — the validation is also a standing
  empirical test of that ADR. A comptime diagnosis flag can re-enable the
  prune in retrograde to isolate any such mismatch.
- ADR-0006 itself is unchanged: forward searches still require it.

## Decision 4: record schema (the format-contract columns)

Per (position, side), columnar side-by-side arrays (colex-addressed, per
`research/teaching-oracle-metrics.md`):

    value: i8   exact score, Black-positive; UNDEF (-128) = illegal slot /
                unfinished residue
    dtt:   u8   depth-to-terminal, saturating at 255
    flags: u8   bit0 KO_SENSITIVE  (L != H at fixpoint; value from finisher)
                bit1 FROM_FORWARD  (finisher produced the value)
                bits 2..7 reserved

**DTT definition (chosen)**: the *fastest optimal resolution* — plies to a
terminal when BOTH sides play only value-optimal moves and, among those,
cooperate on speed (min over optimal edges). Computed by a monotone-decreasing
min-sweep after values are final; well-defined on the cyclic graph. This reads
as "this line can resolve in k plies without either side giving anything up" —
the teaching metric wanted. (The adversarial DTM-style variant — favored side
minimizes, unfavored maximizes — is a possible later column; DTT lives in a
side file precisely so it can be redefined without touching values.)
Residue/unfinished nodes: 255.

## Sign conventions (restated, mandatory — user has been bitten)

- Scores are **always Black-positive**, whoever is to move. Side-to-move picks
  the ARRAY (`vb`/`vw`), never the sign of the value.
- Black maximizes; White minimizes.
- Colour inversion: `value(-pos, -side) == -value(pos, side)`; for the bound
  tables specifically `L(-pos,-side) == -H(pos,side)` (see above).
- Dihedral transforms never change value or sign.
- The colour-symmetry checks are ported into the retrograde battery as
  EXHAUSTIVE table-level checks, not hand-picked cases.

## Implementation & validation plan

`src/retro.zig` — board-size-generic like the rest of Gen-2, standalone
`zig test`, `main` = build + full battery at 2x2 / 3x2 (exhaustive ground
truth) and 3x3 (anchors, symmetry, spot checks, residue stats, sweep counts,
finisher cost, DTT stats, value histogram). Results recorded in
`research/retrograde-3x3.md`. Engine-vs-engine (validation doctrine level 3):
forward and retrograde are the two independent algorithms; every comparison
above is that doctrine executed.

## Consequences / next

- 4x4 is the next scale (43M slots × the working arrays — hundreds of MB,
  still in-RAM; measures sweep-count growth and residue fraction growth).
- 5x5 needs the density folds (legal ~2x, canonical ~16x) AND disk-streamed
  sweeps; the layered colex layout was designed for exactly that access
  pattern (contiguous layer blocks).
- DTT comes essentially free at build time and is unrecoverable later without
  re-solving — hence schema-frozen now (ADR-0008's format-contract warning:
  version the layout in the persist header before writing real artifacts).
- The GHI residue fraction (ko-sensitive nodes) is now a first-class MEASURED
  quantity per board size — the number that decides whether history-aware
  extensions (Kishimoto–Müller bucketing) are ever needed for real play.
