# ADR-0020 — Loopy-game fixpoint semantics replaces first-revisit truncation

**Status:** ACCEPTED · **Date:** 2026-07-30 · **By:** DSPro/Orcha
**Supersedes:** ADR-0019 (first-revisit truncation as the rule)
**Evidence:** C1 witness at 3×2 (QA023-C1-WITNESS), EXP-4 (2×2/3×3 gates passed),
EXP-5 (3×3 +9 matches MIGOS II), PINRULE-SUFFICIENCY (no pointwise function of
(L,TIE,H) works for truncation semantics)

## Context

ADR-0019 chose first-revisit truncation as the rule: when a goban position
reappeared, the game terminated with a fixed tie value (TIE=0). That rule is
well-defined and human-playable, but it makes the game non-Markovian on
`(board, side, ko_point, passes)` — the value at a state depends on *how* the
state was reached, not just the state itself. Enlarging the state to recover
Markovianity was exhaustively attempted and foreclosed by measurement:

- PSK: 118M ban-set states at 2×2 (R1)
- Score-on-cycle: byte-identical state counts (R2)
- RETRO_PLY: memo key still requires full history (RPLY)
- kill-X%: made the ko-sensitive region worse (R3)
- No pointwise function of (L,TIE,H) works for truncation semantics
  (PINRULE-SUFFICIENCY)

The C1 witness at 3×2 — state (178,0,6,0), two valid arrivals yielding −3
and −6 — confirmed that truncation semantics is non-Markovian on the tuple.
A history-dependent exact solve is PSK-class and intractable at 4×4.

## Decision

**The deliverable is the loopy-game fixpoint table.** Under loopy-game
semantics, cycles do not terminate the game; both players may revisit
positions, and the value is the limit of the iterative Bellman operator
Φ(L,H) = (max over moves of opponent's H, min over moves of opponent's L).

This semantics is:

1. **Markovian** on `(board, side, ko_point, passes)` — the value is a
   function of the state alone.
2. **Tractable** — demonstrated at 3×3 (73,758 states, 16 sweeps, <1 minute).
3. **Convergent** by Knaster-Tarski on the complete lattice of bound vectors.
4. **Anchor-compatible** — matches every MIGOS II published anchor where the
   rule difference bites (2×2=0, 3×2=0, 3×3=+9).
5. **Internally consistent** — L=Φ(L), H=Φ(H), 0 Bellman failures, 0
   colour-inversion violations at all tested sizes.

First-revisit truncation is **demoted** from the rule to a reference probe. It
remains valuable: the 24 known 2×2 fixpoint-vs-truncation mismatch states
become a standing calibration fixture, measuring the semantic gap at every
build rather than forgetting it (per AUDIT-TRAJECTORY R2).

## Consequences

- ADR-0019 is superseded. The rule solved is loopy-game fixpoint semantics
  with basic ko, Tromp-Taylor area scoring, komi 0, fixed TIE=0 for cycles.
- EXP-4 and EXP-5 tables are the correct object under this rule. No rebuild
  needed.
- EXP-6 (4×4 build) proceeds under this semantics.
- The K2 deliverable narrows: *provably optimal 4×4 play under loopy-game
  fixpoint semantics with basic ko + TIE=0, with a measured divergence from
  positional superko.*
- The 24 2×2 mismatch states are a permanent calibration fixture. Every future
  build must report the semantic gap against truncation.
- `CLAIMS.md` rows scoped under ADR-0019's truncation semantics (QA-026,
  GLOBAL.H1-COMPUTABLE, GLOBAL.LONGCYCLE) remain FALSE-AS-SCOPED for
  truncation, and this ADR does not change their status — it changes which
  semantics the project *targets*, not which semantics those falsifications
  are about.

## Evidence

- QA023-C1-WITNESS: C1 witness verified node-for-node by two independent
  implementations (Zig + Python)
- EXP-4: 2×2 and 3×2 gates passed (both return 0, not +1 PSK)
- EXP-5: 3×3 root=+9, 73,758 states, 0 UNDEF, colour-symmetric
- PINRULE-SUFFICIENCY: no pointwise function of (L,TIE,H) works for
  history-conditioned semantics at 3×2
- AUDIT-TRAJECTORY (Fable 5): identified the fork, recommended adjudication
  before EXP-6
