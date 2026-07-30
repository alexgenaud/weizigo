# Innovations — concepts, proofs, and goban-size coverage

**Date:** 2026-07-27  **Status:** living document

Project-invented concepts with IDs. Each is PROVEN, CLAIMED, or
IMPLEMENTED on specific goban sizes. Cross-references to the research
notes and bundle files that contain the evidence.

---

## Concepts

| ID | Name | Type | Description | Source |
|---|---|---|---|---|
| **I1** | PSK fresh-start single-ko formula | Algorithm | `opt(V_other, V_after_capture)` — simpler than CGT's loopy equation because PSK permanently bans the root position. | B32 |
| **I2** | Writes-off parallel finisher | Algorithm | `memo_writes=false` eliminates cross-branch contamination AND makes the finisher embarrassingly parallel. Checkpoint/resume with N workers. | B31, ADR-0013 |
| **I3** | Ko decomposition (0/1/2-ko stratification) | Optimization | Classify positions by independent-ko count. Route 0-ko → bracket, 1-ko → O(1) solver, 2-ko+ → finisher. Covers 98% efficiently. | B30, B23 |
| **I4** | Overlapping correctness gates | Method | #2 auditor + anchors + bracket containment form defense in depth. No single gate suffices: auditor blind to L/H construction bugs, anchors catch them. | B09 |
| **I5** | Engine-vs-engine regression detection | Method | Self-play between artifact versions. If v2 loses games v1 won → regression. No ground truth needed. Ko-aware disagreement classification. | B28 |
| **I6** | Fresh-start / real-game separation (C1-C4) | Theorem | Formal separation of table correctness (C1) from real-game correctness (C2, C3, C4). C1 proven, C2/C3 falsified, C4 false. | T13, E2, leak-crisis |
| **I7** | Sign-crossing bracket census | Empirical | 99.5% of ko-sensitive [L,H] brackets cross zero. Finisher solves game-outcome ambiguity on essentially all ko-sensitive positions. | B29 |
| **I8** | Multi-ko frequency census | Empirical | 65% 0-ko, 33% 1-ko, 2% 2-ko, 0.0025% 3-ko on 4×4. 3×3 has no multi-ko. | B23 |
| **I9** | Bracket-guided alpha-beta finisher | Algorithm | Uses [L,H] fixpoints as initial bounds for forward search. Proven sound (ADR-0010). | ADR-0010, retro.zig |
| **I10** | Benson-alive terminal detection | Known theorem | Benson's algorithm (1976). Exhaustively falsification-confirmed at 3×3, regression-tested at 4×4 (4.8M positions). | T09, B17 |
| **I11** | Eye-fill pruning (sound self-eye skip) | Algorithm | In forward search, skip any empty point whose orthogonal neighbours are all the mover's own Benson-alive stones. Proven sound under area scoring — playing in your own alive eye is never optimal. Prevents self-eye-fill stack blowup. | ADR-0006 |
| **I12** | Dependency-guarded memo (Bloom fingerprints) | Algorithm | Sound cross-branch memo reuse via Bloom fingerprints. A memo entry is honoured only when its dependency set is disjoint from ancestors. False positives only forgo reuse. Byte-identical to writes-off on 3×2/3×3/4×3. | ADR-0013 Track B |
| **I13** | Arena leak audit | Method | Adversarial self-play audit: one player plays fresh-start-optimal, opponent plays seeded mix. A game whose final score falls short of the strongest stored promise is a LEAK. Measures real-game exploitability directly. | arena.zig, B26 |
| **I14** | L/H two-sided fixpoint certification | Algorithm | Backward Bellman sweeps seeded from +n and -n converge to greatest (H) and least (L) fixpoints. L==H defines the single-score region, L<H the ko-sensitive region. The core engine that produces the brackets everything else consumes. | ADR-0009, retro.zig |
| **I15** | DTT (non-adversarial depth-to-terminal) | Metric | Fastest optimal resolution when both sides cooperate on speed among score-optimal moves. Frozen column in WZO1 artifacts. Distinct from adversarial DTM. | ADR-0009, teaching-oracle-metrics.md |

## Adoption per goban size

| ID | 2×2 | 3×2 | 3×3 | 4×3 | 4×4 | 5×4 | 5×5 | 6×6 |
|---|---|---|---|---|---|---|---|---|
| **I1** single-ko formula | — | — | IMPL | — | IMPL | — | — | — |
| **I2** parallel finisher | — | — | IMPL | — | IMPL | — | — | — |
| **I3** ko decomposition | — | — | — | — | IMPL | — | — | — |
| **I4** overlapping gates | IMPL | IMPL | IMPL | IMPL | IMPL | — | — | — |
| **I5** engine-vs-engine | — | — | IMPL | IMPL | IMPL | — | — | — |
| **I6** C1-C4 claims | PROVEN | PROVEN | C1 CLAIMED | CLAIMED | CLAIMED | — | — | — |
| **I7** sign-crossing | — | — | — | — | MEASURED | — | — | — |
| **I8** ko census | — | — | MEASURED | — | MEASURED | — | — | — |
| **I9** bracket finisher | IMPL | IMPL | IMPL | IMPL | IMPL | — | — | — |
| **I10** Benson-alive | — | — | IMPL | — | IMPL | — | — | — |
| **I11** eye-fill prune | — | — | IMPL | — | IMPL | — | — | — |
| **I12** deps-memo | — | — | IMPL | IMPL | — | — | — | — |
| **I13** arena audit | — | — | — | — | MEASURED | — | — | — |
| **I14** L/H fixpoint | IMPL | IMPL | IMPL | IMPL | IMPL | — | — | — |
| **I15** DTT metric | IMPL | IMPL | IMPL | IMPL | IMPL | — | — | — |

Key: `—` = not applicable or untested, `IMPL` = implemented and passing,
`MEASURED` = data collected, `PROVEN` = formal verification against exact solver,
`CLAIMED` = believed correct but unverified.

## External references

- Benson, D.B. (1976). "Life in the game of Go." — I10
- Kishimoto, A. & Müller, M. (2004). "A General Solution to the Graph
  History Interaction Problem." — GHI dependency sets, ADR-0013
- Conway, J.H. (1976). "On Numbers and Games." — CGT loopy games, I1
- Berlekamp, E. & Wolfe, D. (1994). "Mathematical Go." — Ko theory
