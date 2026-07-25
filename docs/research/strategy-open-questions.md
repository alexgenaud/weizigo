# Strategy & open questions (2026-07-15)

Topics to consider — options kept OPEN, deliberately not decided yet. Revisit
before committing to an engine or data model (candidate for a future ADR).

## The goal fork — DECIDED 2026-07-16: (b), see ADR-0007
- (a) PROVE the value of NxN (just the number, e.g. 5x5 = B+25). Cheap;
  selective search suffices (van der Werf).
- (b) **CHOSEN.** Build a COMPRESSED PERFECT ORACLE / DAG: value of every
  (position, side). Expensive but reusable — handicaps, either side to move,
  middle-game entry, teaching. "A highly efficient compressed perfect NxN DAG."
Consequences (full write-up in ADR-0007): alpha-beta/PN is OUT (goal-(a) only,
cannot populate an oracle); engine = retrograde/layered fixpoint (or the current
exhaustive forward minimax+TT as reference); `persist.zig` is worth PORTING (the
oracle needs checkpointing); the eye-prune (ADR-0006) is in tension with full
coverage (open). Different goals need different engines — goal now fixed.

## Search paradigm
- Forward selective (alpha-beta + proof-number search) — proves the value
  visiting a tiny fraction of positions. Best for goal (a).
- Backward retrograde (layered tablebase) — build the oracle by propagating
  values from terminals. Best for goal (b).
- Current exhaustive forward minimax — least efficient; retire once (a)/(b)
  chosen.

## BFS / layered vs DFS (user's proposal — sound, with caveats)
- **Depth is a DFS path-artifact (user insight, 2026-07-16).** The measured
  200+-ply lines (forward-solve-scaling.md) are the SAME boards re-derived via
  long silly paths. A POSITION-INDEXED solver (BFS-layered / retrograde) visits
  each distinct board ONCE regardless of how deep some path to it is -- the
  "depth" problem dissolves; a mid-game board with dead clumps is just a config,
  reached directly by enumeration, not by replaying a 200-ply game (it looks like
  "several handicap games at once", which is fine -- it's one enumerable state).
  The optimal-line length stays double-digits (~13-ply PV). RESIDUAL: superko
  is the ONLY thing that resists collapsing a board to a single node (its value
  can depend on ko-history) -- that's the GHI problem below, and it is the make-
  or-break piece.
- Store BOTH sides per position (supports handicaps, passes, either-to-move).
  Good instinct for an oracle.
- Layered-by-stone-count is disk-friendly and reusable. BUT:
  - Captures create BACK-EDGES (k stones -> k-3): not a clean topological order
    -> needs FIXPOINT iteration, not a single forward sweep.
  - Superko makes it not a pure DAG (path-dependent legality, GHI) -> some
    values are history-conditional.
- STRUCTURE vs VALUES: enumerating positions + legal moves up to depth N is
  cheap, correct, reusable NOW. Correct VALUES at depth N are as hard as the
  whole game (must propagate from true terminals). "Start in the middle game"
  works for structure, not for correct values.

## Correctness prerequisites before persisting any VALUES
1. Fix the `is_settled` terminal bug (see terminal-territory-bug.md).
2. Superko / GHI clean-vs-tainted caching (ko_ref framework already in solve).
3. Chinese scoring: terminal score is history-independent (captures irrelevant)
   — OK. Japanese would need capture tracking (later).
Persist STRUCTURE freely; persist VALUES only after 1–3.

## Data model / compression (the potential innovation)
- Combinatorial ranking / minimal perfect hash: ~1 byte per canonical
  (position, side); the index IS the key (no stored keys).
- Storage ~tens of GB canonical for 5x5; hundreds of GB disk is ample -> disk is
  NOT the constraint. RAM manageable via layering.
- A "compressed perfect oracle" is a deliverable van der Werf did not produce ->
  genuine niche. Keep it out of git; regenerate + verify (see policy below).

## Disk / git policy (decided)
- Computed data (DB, checkpoints) = build artifacts: gitignore (like zig-out/).
  Commit the GENERATOR + a manifest/hash of expected output, not the blob.

## Ko / superko in the DAG
- Positional vs situational superko (project uses PSK). Affects legality and
  which values are history-independent.
- Empirically superko is common on 5x5 (see ghi-and-superko.md, ko-examples.md).

## Future idea: explainability & local evaluation (user goal, 2026-07-16)
- Complaint about go-AI: it scores a position but cannot say WHY (abandons
  groups for 1-point sente the human cannot follow). Want principled, local
  explanations: save/kill these stones, secure this corner, keep sente,
  "this area is bigger".
- A PERFECT oracle is the BEST substrate for this (everything is exact, unlike a
  neural net): per-move exact value deltas (which moves hold +25 vs drop);
  Benson already proves "these stones are unconditionally alive"; life/death of
  a group = a local solve. Endgame sente/gote has a rigorous theory:
  combinatorial game theory (CGT), Berlekamp-Wolfe "Mathematical Go" -- local
  game values + temperature explain "play the biggest first" = why keep sente.
- CAVEAT: naive sub-board solving is UNSOUND (edge stones keep phantom
  liberties -- see HANDOVER gotchas). Local evaluation must treat the boundary
  as settled/alive (the CGT endgame regime), not a raw sub-array.
- Research layer on TOP of the oracle; revisit after the value oracle works.

## Future idea: hybrid oracle + search for LARGE boards (9x9)
- For solvable boards (5x5/6x6/7x7) a shallow-perfect + search-below split does
  NOT give a perfect oracle: correct values propagate from TRUE terminals, so
  truncating at a ply-K frontier with search values is a strong estimate, not a
  proof. Use full retrograde there.
- For 9x9 (perfection out of reach): a perfect/near-perfect OPENING TABLEBASE
  (structure enumerated to ply K, values as deep as affordable) + ALPHA-BETA to
  termination past the frontier IS the pragmatic engine — alpha-beta returns
  here. A large-board tool, not needed for the solvable sizes. Revisit post-7x7.

## Board-size frontier (facts, corrected 2026-07-16)
- 5x5: SOLVED, B+25 = total annihilation (whole board Black).
- van der Werf rigorously solved rectangular boards up to 30 cells (i.e. up to
  5x6); **6x6 (36 cells) is NOT among them.** 6x6 is widely EXPECTED B+4 under
  area rules (vdW 2008 estimate) but not a rigorous solve-from-empty. B+4 on 36
  points => B 20 / W 16, so both colours survive.
- 7x7: fair komi ~9 (high confidence from strong-bot self-play); near-balanced
  at fair komi => both colours keep large territory. NOT rigorously solved.
- 8x8: unsolved; NOT realistic with known methods.
- Annihilation pattern: 5x5 is the largest SQUARE board confirmed to end with
  one colour owning everything; from 6x6 up both players live. (3x3 centre
  opening is also 9-0; the exact 4x4 margin is not reliably sourced -- literature
  conflates it with the 3x3 side result.)
- Realistic reach: correct + compressed 5x5, then attempt 6x6, aim at 7x7.
- **User goal (2026-07-16):** after solving 5x5, aim for 6x6 then 7x7. In the
  user's experience **7x7 is the minimal "interesting" board for actual play**;
  a perfect 5x5 oracle *may* be interesting but that's not yet certain. So 5x5
  is the correctness proving-ground; 6x6/7x7 are the payoff. Keep the engine and
  data model board-size-agnostic (parameterize N) so 6x6/7x7 need no rewrite.

## Learn from van der Werf / room to innovate
- Reuse: Benson life (have), symmetry + TT (have), endgame/LD databases,
  selective proof search, provably-correct pruning, ko handling.
- Beyond him: the compressed perfect ORACLE (not just the value); combinatorial
  ranking + retrograde on modern hardware; neural-guided proof search to push
  7x7; a handicap / any-side oracle.
- "Wasting effort with total coverage?" Only if the goal is just the value. If
  the goal is the oracle, coverage IS the point.
