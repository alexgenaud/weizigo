# NEXT STEP: the #2 self-consistency auditor (build this first)

Immediate task after context clear. Cheap bug-detector that needs no
external oracle and does NOT have to reach the ko-tangled residue by brute
force (that is #1, proven structurally dead — see arena-audit.md).

## The property being checked

Under ONE FIXED game history H (a real superko ban set), a correct solver's
own recursion outputs must satisfy the minimax identity at every node:

    V(P, side, H)  ==  opt_side( { V(child, -side, H+[P]) for legal child },
                                 pass-branch value )

i.e. a maximizer's node value is NEVER strictly below its best child's
value, and a minimizer's NEVER strictly above. A violation is an outright
PROOF of a bug in that solver (this is exactly the contradiction RETRO_CONTRA
already found: parent -1 with a +1 child, same position + prefix).

Necessary, not sufficient: passing does not prove correctness (a solver can
be self-consistent at a WRONG fixpoint), and it never yields the true value.
Use it to ELIMINATE buggy generations and as the standing acceptance test
for #3, not to crown a winner.

## Concrete implementation (retro.zig, env RETRO_CONSIST)

For each engine variant V in { new = ab_value_from_root(brackets=on,
memo_writes=ON), soundish = same but memo_writes=OFF }:
  - build 3x2 (converge + finalize) so L/H, KO_SENSITIVE flags, certified
    seeds exist;
  - for a sample of KO_SENSITIVE nodes P (all of 3x2 is cheap; sample 4x4):
      * fresh hist = [P]; parent_val = V(P, side, hist)
      * for each legal PSK-legal child c (skip if c already in hist):
          child_val = V(c, -side, hist+[P])   // history extended by P
        best = opt over children (and the pass branch) of child_val
      * FLAG if parent_val != best  (maximizer: parent_val < best is the
        smoking gun; minimizer mirror)
  - count violations per variant. ZERO = self-consistent (necessary
    condition met). >0 = that variant is PROVABLY BUGGY.

Key subtlety: parent and children MUST be solved under the SAME history
family (child solved with P pushed). That is the whole point — it is an
in-history check, not a fresh-start-table check. The fresh-start TABLE does
NOT satisfy naive Bellman on residue (GHI), so do NOT audit V0(P)==opt
V0(child) on the stored table — that would false-positive on correct values.

Tractable because it is ONE ply deep per node (parent + its direct
children), each solve using the existing bracket-guided search — NOT the
deep re-search that killed #1. Budget each solve modestly; budget-skips just
reduce coverage.

## Expected outcomes and reading

- new inconsistent, soundish consistent  -> strong evidence the bounds-memo
  (cross-branch write) generation is the buggy one; proceed to #3 to get the
  true values, confident the target is "match soundish's shape".
- both inconsistent -> the hole is deeper than cross-branch writes (brackets
  or certified seeds implicated); widen #3's guard scope.
- both consistent on sampled nodes -> inconclusive (consistency is weak);
  #3 is still required for truth. Do not over-read a pass.

## Then #3 (separate, larger)

Kishimoto-Muller dependency-guarded memo in the finisher: each memo entry
records the set of history positions its value depends on; reuse an entry
only when the current search path cannot invalidate that dependency set.
Sound by construction. Validate with: pilot gate determinism, bracket
containment, exhaustive symmetry, Exact agreement on reachable (non-residue)
slots, and ZERO violations from this #2 auditor. Then regenerate ALL
artifacts (2x2..4x4), re-hash, update research/retrograde-4x4.md sha256, and
run the arena for ZERO leaks (also the history-perfect-player acceptance).
