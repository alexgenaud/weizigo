# 0010 — Bracket-guided alpha-beta finishing of the ko-sensitive residue

Date: 2026-07-21 · Status: **accepted** (design); 3x3 measurement this session

ADR-0009 left one open frontier: the deep-OPENING residue. The finisher —
plain minimax with the memo pre-seeded by certified values — pins
near-terminal residue but was measured unable to reach opening roots
(Finding 6: empty 3x3 exceeded 2.0e9 nodes seeded with all 8,326 certified
values). Cause: memo cuts fire only when the search REACHES a certified
position, and from the opening everything reachable early is itself residue.
The acceptance test for this ADR: the 3x3 published anchors must PIN
(empty = +9, 1.B side = +3, 1.B corner = −9), not merely bracket.

## Decision: use the [L, H] brackets as cutoffs INSIDE the residue

The L/H tables assign every node — certified AND residue, V0 and V1 — a value
bracket that holds under ANY arrival history (the same structural claim as
ADR-0009 certification; measured directly in Finding 3: every history-exact
value at 2x2/3x2 fell inside its bracket). The finisher's forward solve
becomes fail-soft alpha-beta, and the brackets supply three things the plain
finisher lacked:

1. **Bracket cutoffs at every node.** At a node with bracket [lo, hi] and
   window (alpha, beta): if `hi <= alpha` the node cannot influence the
   parent — return `hi` (an upper bound) WITHOUT expanding; symmetrically
   `lo >= beta` returns `lo`. If `lo == hi` the node is certified — return
   the exact value. These cuts are valid under any ban set (the bracket is),
   so they fire deep inside the ko-tangled opening where certified-memo cuts
   cannot — precisely the Finding-6 wall. They carry `ko_ref = KO_CLEAN`.
2. **Bracket-driven move ordering.** Children (including the pass edge) are
   tried best-first by bracket midpoint (descending for Black, ascending for
   White). Alpha-beta's power is move ordering; the retrograde tables are a
   free, sound ordering heuristic.
3. **Aspiration window from the root bracket.** The root value lies in
   [L, H], so the root search runs with window (L−1, H+1) and returns exact.

No cross-root sharing is introduced: brackets are global-but-history-free
(sound to share by construction); the exact-value memo stays per-root with
the ko_ref discipline (Finding 2 stands: NEVER share ko_ref-clean memo
across roots).

## Interaction of alpha-beta with the memo (exactness discipline)

Fail-soft alpha-beta returns bounds, not always exact values. A memo write
now requires ALL of:

- `passes == 0` and `ko_ref >= d` (the validated solve.zig discipline), and
- **exactness**: `entry_alpha < best < entry_beta` (a fail-low/high result is
  a bound and must not be stored as an exact value).

Memo reads are unchanged (stored values are exact and clean). Bound-valued
returns are never memoized; if measurement shows heavy re-search, a per-root
bound memo (lower/upper columns) is the known extension — not needed until
measured needed.

ko_ref through a cutoff is sound: an early beta-cutoff means unexplored
siblings could only improve the returned bound; the bound's history
dependence is that of the EXPLORED subtree, which is what ko_ref tracked.

## Why not the alternatives first

- **Iterated finishing** (re-seed with finished residue values): a finished
  residue value is a FRESH-START value of a history-sensitive position;
  using it as a memo cut under another root's ban set is exactly the
  Finding-2 unsoundness. Rejected as primary route.
- **Kishimoto–Müller dependency buckets**: sound and exact but a large new
  kernel (dependency-set tracking through the memo); kept as the fallback if
  bracket-guided finishing fails the anchor acceptance test.

## Soundness status (inherits the ADR-0009 honesty clause)

The bracket claim ("value under any ban set lies in [L, H]") is the same
strong-structural-evidence-not-theorem as certification, and is covered by
the same empirical closure: exhaustive ground truth at 2x2/3x2 (every slot
of the alpha-beta-finished table must equal the history-exact value), the
plain-vs-bracketed finisher must produce IDENTICAL tables where both
complete, the standing symmetry/orbit/bracket battery, and the 3x3 anchors.
This is not alpha-beta smuggling ADR-0007's scrapped goal back in: alpha-beta
here resolves SINGLE residue roots exactly (aspiration window inside the
known bracket); the oracle bulk is still populated by value iteration +
orbit propagation.

## Consequences

- `retro.finish` gains a comptime `bracketed` switch; the plain path is kept
  as the cross-check engine (engine-vs-engine doctrine).
- If the 3x3 residue sweep completes under budget, the 3x3 oracle is COMPLETE
  (first board where certification + finishing covers every slot beyond 2x2).
- 4x4/5x5 scaling of the finisher becomes a measurable quantity again
  (nodes per opening root with bracket cuts, vs Finding 6's blowup).
- DTT-through-finisher (open question 2) remains separate; V1 finishing now
  has a tractable engine if wanted.
