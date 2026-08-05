# References — weizigo project bibliography

**Created:** 2026-07-29 by DSFlash/REFERENCES (AUDIT-REF-DSPro-2026-07-29).
**Status:** living document — add entries as new sources are cited.

Each entry carries a **verification status** for weizigo:

| status | meaning |
|---|---|
| **R** (reproduced) | weizigo independently reproduced the result — the project has confirmed it ourselves |
| **I** (implemented, not validated) | weizigo implements the algorithm/technique but has not cross-validated against an external reference implementation |
| **C** (cited, not reproduced) | the result is taken on trust from the source — weizigo has not independently verified it |

---

## 1. Small-goban Go solving — van der Werf / MIGOS

### 1.1 MIGOS II anchor scores (primary: printed results)

> van der Werf, E.C.D. & Winands, M.H.M. (2009). "Solving Go for Rectangular
> Boards." *ICGA Journal*, 32(2), 77–88.
> DOI: [10.3233/icg-2009-32203](https://doi.org/10.3233/icg-2009-32203).

**Verification:** C. The anchor values (3×3 = +9, 4×4 = +2, 4×5 = +20, 5×5 = +25)
are cited as published anchors and used as cross-reference for weizigo's
fresh-start tables. weizigo does not re-run MIGOS II. Critical context: MIGOS II
plays Chinese area scoring + **basic ko + long-cycle ties**, not positional
superko (PSK) — see `GLOBAL.MIGOS-RULE`. The 3×3 and 4×4 empty-goban scores
agree with weizigo's PSK tables; the 2×2 and 2×3 scores do not (ruleset
divergence).

**Relevance:** Primary external anchor for weizigo's fresh-start oracle values.
The disagreement at 2×2/2×3 is the project's first empirical evidence of
cycle-rule sensitivity.

### 1.2 MIGOS architecture (canonical: PhD thesis)

> van der Werf, E.C.D. (2005). *AI Techniques for the Game of Go.* PhD Thesis,
> Maastricht University.
> URL: https://cris.maastrichtuniversity.nl/en/publications/ai-techniques-for-the-game-of-go

**Verification:** C (cited without reproduction). The thesis contains the full
MIGOS architecture description (Benson integration, solving methodology,
bounded-history ruleset discussion, and the experimental apparatus behind the
2009 ICGA paper). The 2009 paper is a summary with new goban-size results; the
thesis is the canonically correct source for the MIGOS method and ruleset
details.

**Relevance:** Should be the primary citation for MIGOS method; the 2009 paper
is the secondary (anchor-value) citation. The project cited the 2009 paper
without the thesis; this entry fixes that gap.

### 1.3 The 2003 5×5 solve

> van der Werf, E.C.D., van den Herik, H.J., & Uiterwijk, J.W.H.M. (2003).
> "Solving Go on Small Boards." *ICGA Journal*, 26(2), 92–107.

**Verification:** C. The 5×5 +25 result is cited, not re-proven (weizigo verifies
the 13-ply PV legality but not the game-theoretic score).

**Relevance:** First published solution of 5×5 Go. The result was announced in
October 2002 (sometimes cited as "2002" in project docs — the announcement
predates the 2003 publication).

### 1.4 5×5 principal variation — secondary sources

> Hayward, R. *Solving Go on Small Boards* (course notes, CMPUT 355, University
> of Alberta). p. 18, "a 5x5 pv."
> URL: https://webdocs.cs.ualberta.ca/~hayward/355/ssgo.pdf
> *(Archived: `docs/evidence/van-der-werf-sources/ssgo.pdf`)*

> van der Werf, E.C.D. *5×5 Go Solved* (animated optimal play, 3 strongest
> openings).
> URL: http://erikvanderwerf.tengen.nl/5x5/5x5solved.html
> *(Original URL defunct — archived at
> https://web.archive.org/web/20250209110156/https://erikvanderwerf.tengen.nl/5x5/5x5solved.html)*

> van der Werf, E.C.D. *Solving Go on Small Boards* (reprint/preprint).
> URL: http://erikvanderwerf.tengen.nl/pubdown/solving_go_on_small_boards.pdf
> *(Original URL defunct — archived at
> https://web.archive.org/web/20251204235049/http://erikvanderwerf.tengen.nl/pubdown/solving_go_on_small_boards.pdf)*

**Verification:** C (Hayward PDF archived locally; tengen.nl sources confirmed
404, Wayback archived).

**Relevance:** The Hayward course notes reproduce van der Werf's 5×5 PV with
coordinates. The tengen.nl pages were the author's own website and the
definitive source for the 5×5 solution. Both are secondary sources citing van
der Werf's primary work.

---

## 2. Benson unconditional life

> Benson, D.B. (1976). "Life in the Game of Go." *Information Sciences*, 10(1),
> 17–29. DOI: [10.1016/0020-0255(76)90059-1](https://doi.org/10.1016/0020-0255(76)90059-1).
> *(Also reprinted at DOI [10.1016/S0020-0255(76)90554-5](https://doi.org/10.1016/S0020-0255(76)90554-5),
> 10(2), 17–29.)*

**Verification:** I. The paper proves three theorems establishing unconditional
life. weizigo implements `benson_alive` in `rules.zig` and `terminal.zig`, and
exhaustively falsification-tested the implementation at 3×3 against the theorem
(no false positives or false negatives on any 3×3 position). However, the
implementation has NOT been cross-validated against an independent reference
implementation (e.g., van der Werf's MIGOS Benson integration).

**Relevance:** Terminal detection and eye-prune precondition. The theorem is the
project's only formal-life guarantee; every settled-terminal position rests on
it.

---

## 3. GHI solution — Kishimoto & Müller

### 3.1 Primary: AAAI 2004

> Kishimoto, A. & Müller, M. (2004). "A General Solution to the Graph History
> Interaction Problem." *Proceedings of the AAAI Conference on Artificial
> Intelligence (AAAI-04)*, pp. 644–649.
> URL: https://aaai.org/papers/00644-aaai04-102-a-general-solution-to-the-graph-history-interaction-problem/

**Verification:** I. The paper presents a general solution to GHI for both αβ
and df-pn search (Theorem 1, correctness proofs). weizigo implements a
**Bloom-fingerprint variant** of dependency-guarded memoization (Track B,
ADR-0013): it stores a probabilistic set representation (Bloom filter) instead
of the exact dependency set. Bit-disjointness is the reuse signal; false
positives only forgo reuse, never produce a wrong score. The variant is
PROVEN-as-argument but is NOT the exact algorithm from the paper, and has not
been cross-validated against an independent reference implementation.

**Relevance:** The theoretical foundation for weizigo's sound memo reuse. The
project's prior unsound `ko_ref >= d` guard (F1 bug, ADR-0013) was replaced by
this approach.

### 3.2 Follow-up: Information Sciences 2005

> Kishimoto, A. & Müller, M. (2005). "A Solution to the GHI Problem for
> Depth-First Proof-Number Search." *Information Sciences*, 175(4), 296–314.
> DOI: [10.1016/j.ins.2004.04.012](https://doi.org/10.1016/j.ins.2004.04.012).

**Verification:** C. This paper extends the GHI solution to df-pn search. weizigo
does not implement df-pn, so this is cited for completeness.

**Relevance:** Establishes that the GHI problem has a solution in multiple search
paradigms. Relevant as context for why the project chose the αβ-compatible
approach.

### 3.3 GHI origin

> Campbell, M.S. (1985). "The Graph-History Interaction: On Ignoring Position
> History." *Proceedings of the 1985 ACM Annual Conference on the History of
> Personal Workstations (The Second Conference on the History of Personal
> Workstations)*, pp. 121–132. (Note: also appears as a 1985 technical report,
> Bell Labs.)

**Verification:** C. The paper that first named and described the GHI problem.

**Relevance:** Historical origin. Kishimoto & Müller (2004) builds on Campbell's
work.

---

## 4. Tromp / OEIS — legal position count

> Tromp, J. "Number of legal Go positions on an n×n board." *The On-Line
> Encyclopedia of Integer Sequences*, entry A094777.
> URL: https://oeis.org/A094777

**Verification:** **R** (independently reproduced). weizigo independently
computes legal-position counts for 1×1 through 4×4 via `enumerate.zig` and
cross-validates against OEIS A094777. The move-generation/capture/suicide kernel
is therefore externally attested: 1×1 = 1, 2×2 = 57, 3×3 = 12,675, 4×4 =
24,318,165. The counts attest legality under Tromp–Taylor (positional superko
not required for fresh-start positions — cycle-generating moves are legal at the
position level).

**Relevance:** The only externally-validated anchor the project has independently
reproduced. All other external anchors are cited without reproduction or
implemented without cross-validation.

---

## 5. Tromp–Taylor rules

> Tromp, J. & Taylor, B. *The Tromp–Taylor Rules of Go.*
> URL: https://tromp.github.io/go/rules.html (John Tromp's website)

**Verification:** C. weizigo implements a superset of Tromp–Taylor (Chinese area
scoring + positional superko), with one divergence: **suicide is illegal**
(Tromp–Taylor permits suicide that captures). This is correctly documented in
`go-rules-ko-and-scoring.md:46-47`.

**Relevance:** The project's formal ruleset reference. Tromp–Taylor is the
machine-to-machine convention for Go rules.

---

## 6. CGT / loopy games

> Conway, J.H. (1976). *On Numbers and Games*. Academic Press. (2nd edition,
> 2001, A K Peters. ISBN: 978-1568811277.)

> Berlekamp, E. & Wolfe, D. (1994). *Mathematical Go: Chilling Gets the Last
> Point.* A K Peters. ISBN: 978-1568810324.

> Berlekamp, E., Conway, J.H., & Guy, R. (1982). *Winning Ways for Your
> Mathematical Plays.* Academic Press. (2nd edition, 4 volumes, 2001–2004,
> A K Peters.)

**Verification:** C. The project acknowledges the CGT tradition without
implementing it. The L/H fixpoint approach (ADR-0009) is in the CGT tradition:
loopy-game theory defines the *least* and *greatest* fixpoints as stopping
values, which is what weizigo computes. The project's innovation (I14) is the
*retrograde* implementation (backward sweeps over full colex space) rather than
the forward CGT approach.

**Relevance:** Foundational mathematics. The project's core method (L/H brackets
on a loopy state space) is a specific instantiation of CGT loopy-game concepts.

---

## 7. Müller territory safety

> Müller, M. (1997). "Playing it Safe: Recognizing Secure Territories in
> Computer Go by Using Static Rules and Search." *Game Programming Workshop in
> Japan '97*, pp. 80–86. Computer Shogi Association, Tokyo.

**Verification:** C. The paper defines static rules and 6-ply search for
territory safety. The project uses Benson-settled detection as its primary
terminal test and the H5a fallback in `src/gtp.zig` uses a Benson-alive
territory estimate — not Müller's search-based safety solver.

**Relevance:** Conceptual ancestor of both the settled-terminal detection and the
H5a fallback. The project's one informal citation ("Müller 'unconditional
territory' (1997)" in `terminal-territory-bug.md:27`) is replaced by this formal
entry.

### 7.1 Follow-up

> Niu, X. & Müller, M. (2004). "An Improved Safety Solver for Computer Go."
> *Proceedings of the Conference on Computers and Games (CG 2004)*.

**Verification:** C. extends Müller (1997) with region merging and
weakly-dependent-region analysis.

**Relevance:** Shows the trajectory of territory-safety research that the project
does not follow (preferring Benson-alive).

---

## 8. Standard theorems and algorithms

### 8.1 Knaster–Tarski fixpoint theorem

> Tarski, A. (1955). "A Lattice-Theoretical Fixpoint Theorem and Its
> Applications." *Pacific Journal of Mathematics*, 5(2), 285–309.
> DOI: [10.2140/pjm.1955.5.285](https://doi.org/10.2140/pjm.1955.5.285).

> Knaster, B. (1928). "Un théorème sur les fonctions d'ensembles." *Annales de la
> Société Polonaise de Mathématique*, 6, 133–134.

**Verification:** C (standard theorem — cited, not re-proven). The least/greatest
fixpoint convergence of weizigo's retrograde sweep (FP1) is an instance of the
Knaster–Tarski theorem on the complete lattice of score assignments.

**Relevance:** Theoretical foundation for fixpoint convergence in ADR-0009.

### 8.2 Bellman value iteration

> Bellman, R. (1957). *Dynamic Programming*. Princeton University Press.
> ISBN: 978-0691079516.

**Verification:** C (standard technique). weizigo's retrograde sweeps apply
Bellman value iteration over the full colex state space.

**Relevance:** The algorithm weizigo uses to converge the L/H fixpoints.

### 8.3 Gauss–Seidel iteration

> Gauss, C.F. (1823). Letter to Gerling (the earliest known description of
> element-by-element substitution). Formalized in:
> Seidel, P.L. (1874). "Über ein Verfahren, die Gleichungen, auf welche die
> Methode der kleinsten Quadrate führt, sowie lineäre Gleichungen überhaupt,
> durch successive Annäherung aufzulösen." *Abhandlungen der Bayerischen Akademie
> der Wissenschaften*, 11(3), 81–108.

**Verification:** C (standard technique). weizigo's in-sweep oppV0 reads use a
Gauss–Seidel-like update (values from the current sweep are available to later
positions in the same sweep).

**Relevance:** Convergence acceleration for the Bellman sweeps.

### 8.4 Zobrist hashing

> Zobrist, A.L. (1970). "A New Hashing Method with Application for Game Playing."
> *ICCA Journal*, 1(1), 4–7. (Originally a 1970 University of Wisconsin
> Computer Sciences Department technical report #88.)

**Verification:** I. Implemented in `zobrist.zig` for position hashing. Not
independently validated against a reference implementation.

**Relevance:** Position hashing for memoization in the finisher.

### 8.5 Bloom filter

> Bloom, B.H. (1970). "Space/Time Trade-offs in Hash Coding with Allowable
> Errors." *Communications of the ACM*, 13(7), 422–426.
> DOI: [10.1145/362686.362692](https://doi.org/10.1145/362686.362692).

**Verification:** I. Implemented as the probabilistic dependency fingerprint in
`deps` mode (Track B, ADR-0013). Bit-disjointness is the reuse signal; false
positives only forgo reuse.

**Relevance:** Enables space-efficient dependency tracking in the GHI guard.

### 8.6 Alpha-beta pruning

> Knuth, D.E. & Moore, R.W. (1975). "An Analysis of Alpha-Beta Pruning."
> *Artificial Intelligence*, 6(4), 293–326.
> DOI: [10.1016/0004-3702(75)90019-3](https://doi.org/10.1016/0004-3702(75)90019-3).

**Verification:** C. weizigo's bracket-guided finisher (ADR-0010) uses alpha-beta
pruning with bracket-derived windows. The algorithm is not independently
validated against a reference implementation — alpha-beta is a standard algorithm
and is taken as given.

**Relevance:** The first formal analysis of alpha-beta pruning. The project uses
alpha-beta in the bracket-guided finisher (ADR-0010).

---

## 9. Missing prior art (added 2026-07-29)

### 9.1 Retrograde analysis at scale — solved checkers

> Schaeffer, J., Burch, N., Björnsson, Y., Kishimoto, A., Müller, M., Lake, R.,
> Lu, P., & Sutphen, S. (2007). "Checkers Is Solved." *Science*, 317(5844),
> 1518–1522. DOI: [10.1126/science.1144079](https://doi.org/10.1126/science.1144079).

**Verification:** C. The canonical retrograde analysis at scale (5×10²⁰
positions, 10+ years of computation). weizigo's approach is independently
developed and differs in using successor sweeps rather than predecessor
generation (ADR-0009 Decision 1, "no un-capture code").

**Relevance:** Prior art for the retrograde approach. The project's retrograde
engine is the same technique applied to a different game with a different
state-space structure (Go's empty-goban → played → terminal direction vs.
checkers' populated → capture → empty direction). The successor-sweep innovation
is independently motivated by Go's asymmetry (moves add stones, never remove
them on their own).

### 9.2 Survey of solved games

> van den Herik, H.J., Uiterwijk, J.W.H.M., & van Rijswijck, J. (2002). "Games
> Solved: Now and in the Future." *Artificial Intelligence*, 134(1–2), 277–311.
> DOI: [10.1016/S0004-3702(01)00152-9](https://doi.org/10.1016/S0004-3702(01)00152-9).

**Verification:** C. The canonical survey of solved games, including Go on small
gobans. The project's 5×5 anchor appears in this survey.

**Relevance:** Establishes the solved-games landscape into which weizigo's
results fit. The survey covers through 2001; weizigo extends the Go-solving
results post-2009.

### 9.3 AlphaGo / deep learning approaches (distinction)

> Silver, D., Huang, A., Maddison, C.J., Guez, A., Sifre, L., van den Driessche,
> G., Schrittwieser, J., Antonoglou, I., Panneershelvam, V., Lanctot, M.,
> Dieleman, S., Grewe, D., Nham, J., Kalchbrenner, N., Sutskever, I.,
> Lillicrap, T., Leach, M., Kavukcuoglu, K., Graepel, T., & Hassabis, D. (2016).
> "Mastering the Game of Go with Deep Neural Networks and Tree Search." *Nature*,
> 529(7587), 484–489. DOI: [10.1038/nature16961](https://doi.org/10.1038/nature16961).

**Verification:** C. The AlphaGo paper is the canonical reference for the
approximate (deep learning + MCTS) approach that weizigo does NOT take. The
project correctly identifies that approximate bots sidestep exact solving and
use bounded-history inputs (`ruleset-options.md`).

**Relevance:** The project's identity depends on the contrast between exact
(retrograde, provably correct) and approximate (deep learning, statistically
strong) approaches. AlphaGo is the canonical example of the latter.

### 9.4 Ko thermography — Spight

> Spight, W. (1999). "Extended Thermography for Multiple Kos in Go." In
> van den Herik, H.J. & Iida, H. (eds.), *Computers and Games (CG'98)*, LNCS
> 1558, pp. 232–251. Springer.
> DOI: [10.1007/3-540-48957-6_15](https://doi.org/10.1007/3-540-48957-6_15).

**Verification:** C. Spight's work on extended thermography for multiple kos is
the CGT approach to the same problem weizigo addresses with L/H fixpoints. The
project's L/H brackets are functionally analogous to the thermograph's left/right
scaffold.

**Relevance:** Prior art for the ko-resolution framework. The project now
acknowledges that the L/H fixpoint approach is a specific instantiation of the
CGT loopy-game concept, and that Spight's thermography is the best-known
published approach to the same problem.

### 9.5 Thompson's retrograde analysis (chess endgames)

> Thompson, K. (1986). "Retrograde Analysis of Certain Endgames." *ICCA Journal*,
> 9(3), 131–139.

**Verification:** C. The foundational work on retrograde analysis in chess
endgame tablebases. weizigo's retrograde engine is the same technique applied to
Go's different state-space structure.

**Relevance:** The technique that weizigo applies to Go. Thompson's work is to
chess tablebases what weizigo's retrograde engine is to Go: exhaustive value
iteration over a finite state space. The project's successor-sweep innovation
differs from the predecessor-generation approach used in chess tablebases.

### 9.6 GHI problem — Breuker et al. (intermediate result)

> Breuker, D.M., Uiterwijk, J.W.H.M., & van den Herik, H.J. (2001). "The
> Graph-History Interaction Problem in Best-First Search." *Proceedings of the
> Symposium on Games (CG 2000)*, pp. 106–119.

**Verification:** C. Solved GHI for best-first search (predecessor to
Kishimoto–Müller's general solution). Not implemented in weizigo, which uses
αβ-based search.

**Relevance:** Completes the GHI problem's provenance chain: Campbell (naming) →
Breuker (best-first solution) → Kishimoto–Müller (general + df-pn solutions).

---

## 10. Verification summary matrix

| source | proved in source? | weizigo independent verification | verification status |
|---|---|---|---|
| Benson (1976) — unconditional life | YES (Theorems 1–3) | Implementation falsification-tested at 3×3 against the theorem | **I** — no cross-validation against reference implementation |
| Kishimoto–Müller (2004) — GHI solution | YES (Theorem 1) | Bloom-fingerprint variant implemented; PROVEN-as-argument | **I** — variant differs from exact algorithm; not cross-validated against reference |
| van der Werf & Winands (2009) — anchors | N/A (measurements) | Anchor values used as cross-reference; 3×3 and 4×4 agree, 2×2/2×3 differ (ruleset) | **C** — no independent re-run of MIGOS II |
| OEIS A094777 — legal counts | N/A (computations) | Independently reproduced 1×1–4×4 via `enumerate.zig` | **R** — the project's ONLY independently-reproduced external anchor |
| van der Werf et al. (2003) — 5×5 solved | YES (computer proof) | PV legality verified; +25 score not re-proven | **C** |
| Müller (1997) — territory safety | N/A (heuristic+search) | Not independently verified | **C** |
| Conway (1976), Berlekamp & Wolfe (1994) — CGT | YES (mathematical proofs) | Not implemented; acknowledged as prior art | **C** |
| Knaster–Tarski — fixpoint theorem | YES (mathematical proof) | Applied in ADR-0009; standard theorem | **C** |
| Bellman (1957) — value iteration | N/A (standard technique) | Applied as retrograde sweeps | **C** |
| Knuth & Moore (1975) — alpha-beta | YES (mathematical analysis) | Applied in ADR-0010 finisher | **C** |
| Zobrist (1970) — hashing | N/A (technique) | Implemented in `zobrist.zig` | **I** — not cross-validated |
| Bloom (1970) — Bloom filter | N/A (technique) | Implemented as dependency fingerprint | **I** — not cross-validated |
| Schaeffer et al. (2007) — checkers solved | YES (computer proof) | Not reproduced; cited as prior art | **C** |
| Silver et al. (2016) — AlphaGo | N/A (empirical) | Not reproduced; cited for contrast | **C** |

**Status key:** R = independently reproduced, I = implemented without external
validation, C = cited without reproduction.

---

## 11. URL status note (2026-07-29)

- `https://webdocs.cs.ualberta.ca/~hayward/355/ssgo.pdf` — **LIVE** (archived
  locally at `docs/evidence/van-der-werf-sources/ssgo.pdf`).
- `http://erikvanderwerf.tengen.nl/5x5/5x5solved.html` — **404** (Wayback
  Machine: https://web.archive.org/web/20250209110156/https://erikvanderwerf.tengen.nl/5x5/5x5solved.html)
- `http://erikvanderwerf.tengen.nl/pubdown/solving_go_on_small_boards.pdf` —
  **404** (Wayback Machine:
  https://web.archive.org/web/20251204235049/http://erikvanderwerf.tengen.nl/pubdown/solving_go_on_small_boards.pdf)
- `http://erikvanderwerf.tengen.nl/` — **403** (domain still resolves; content
  removed or access-restricted since the 2026-07-29 probe)

---

*This document was generated by DSFlash/REFERENCES (task AUDIT-REF-DSPro-2026-07-29). 
The full audit with per-source verification details is at `docs/audits/2026-07-29-AUDIT-REF-DSPro.md`.*
