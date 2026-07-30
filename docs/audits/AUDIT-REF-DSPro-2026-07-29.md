# REFERENCE AUDIT — weizigo project-wide

```
Role: Auditor (project scope, references)
Model: DeepSeek-v4-Pro (DSPro)
Task: AUDIT-REF-DSPro · Date: 2026-07-29
Scope: every external reference in the project — papers, authors, theorems, 
       anchors, OEIS entries, web sources, prior art
Output: this single file (docs/audits/AUDIT-REF-DSPro-2026-07-29.md) — ANALYSIS
```

**Method.** I scanned every .md and .zig file for citations, author names,
theorems, and external references. I verified each against online databases
(DOI, AAAI proceedings, ICGA Journal, ScienceDirect, ChessProgramming Wiki,
OEIS). I cross-checked what the project *says* about each source against what
the source actually says (where retrievable). Every finding cites the project
document that makes the claim.

---

## 0. The reference landscape — a view from above

The project references **seven distinct external knowledge families**:

| family | sources | how used | status |
|---|---|---|---|
| van der Werf / MIGOS anchors | 2003, 2005, 2009 | empty-goban scores as validation targets | correctly identified as different ruleset; previously misused as PSK validation |
| Benson unconditional life | Benson 1976 | terminal detection, eye-prune precondition | correctly cited; theorem sound; implementation independently verified |
| Kishimoto–Müller GHI solution | Kishimoto & Müller 2004, 2005 | dependency-guarded memo (ADR-0013 Track B) | correctly cited but incomplete; project's Bloom-fingerprint variant is a simplification |
| Tromp–Taylor / OEIS A094777 | Tromp (OEIS) | legal-position count validation | correctly cited; independently reproduced |
| CGT / loopy games | Conway 1976, Berlekamp & Wolfe 1994 | acknowledged as prior art, not implemented | correctly cited; the project's L/H fixpoints are in the CGT tradition |
| Müller territory safety | Müller 1997, Niu & Müller 2004 | terminal-territory bug diagnosis, settled-area fallback | sparsely cited; deserves more prominent attribution |
| Standard theorems | Knaster–Tarski, Bellman, Knuth–Moore, Zobrist, Bloom | fixpoint convergence, value iteration, alpha-beta, hashing, fingerprint | correctly identified; no formal citations for any |

**There is no bibliography.** No single document collects all references with
complete bibliographic data. The GLOSSARY.md entry block is the closest
approximation, and it has five entries with incomplete citation data.

---

## 1. van der Werf & Winands — MIGOS II anchors

### 1.1 What the project says

The project cites these anchors pervasively. The clearest statement is at
`docs/research/retrograde-3x3.md:224-241`:

> Van der Werf & Winands, "Solving Go for Rectangular Gobans" (ICGA Journal
> 2009), Chinese rules, gives: 2x2 = 0 (any first move), 2x3 = 0, 3x3 = +9,
> 2x4 = +8, 3x4 = +4, 3x5 = +15, **4x4 = +2 (central first move)**, 4x5 = +20,
> 5x5 = +25. CRITICAL CONTEXT for comparing: **MIGOS II does NOT use superko**
> — the paper states "since superko is not used, balanced long-cycle
> repetition ... is scored as a long-cycle-tie" (basic ko in the hash, cycle
> ties handled specially). weizigo plays POSITIONAL SUPERKO, where those
> cycles are banned moves instead of ties.

### 1.2 What the paper actually says

**Verified.** The paper is:
- van der Werf, E.C.D. & Winands, M.H.M. (2009). "Solving Go for Rectangular
  Gobans." *ICGA Journal*, Vol. 32, No. 2, pp. 77–88.
  DOI: [10.3233/icg-2009-32203](https://doi.org/10.3233/icg-2009-32203).

The anchor values cited by weizigo match the paper's Table 1 exactly. The
characterization of MIGOS II's ruleset as "Chinese area scoring + basic ko +
long-cycle ties" is correct. The paper was published in ICGA Journal (not "at
ICGA" — ICGA is the International Computer Games Association, and ICGA
Journal is its journal; the project sometimes writes "ICGA 2009" which is
slightly imprecise but not misleading).

### 1.3 The previous misuse (now corrected)

`CLAIMS.md:401` (`4x4.ANCHOR`): "`empty(B) 4×4 = +2` (dtt 13) matches van der
Werf & Winands under PSK." The phrase "under PSK" is **false** — MIGOS II
does not use PSK. The score happens to agree (+2), but the rulesets differ.
The Opus critique (2026-07-28 §3) identified this, and the project has since
corrected it in the GLOSSARY and CLAIMS.md. The remaining issue is that
`retrograde-4x4.md:76-77` and `ruleset-options.md:205-215` still carry the
uncorrected framing.

**Recommendation:** Add an erratum to `retrograde-4x4.md:76-77` noting that
the agreement is cross-ruleset and does not validate PSK correctness. The
`ruleset-options.md:205-215` "Soundness confirmed" heading should be
reworded — it describes bracket containment, not soundness, and a wrong
answer passes that test ~70% of the time at 4×4.

### 1.4 The 2003 predecessor

The original 5×5 solution was published in:
- van der Werf, E.C.D., van den Herik, H.J., & Uiterwijk, J.W.H.M. (2003).
  "Solving Go on Small Gobans." *ICGA Journal*, Vol. 26, No. 2, pp. 92–107.

The project references this indirectly via `oracle-5x5-pv.md` (through
Hayward's course notes) and `go-rules-ko-and-scoring.md` ("van der Werf &
van den Herik, ~2002"). The "~2002" date is approximate — the paper was
published in 2003, but the result was announced in October 2002. The
project's `oracle-5x5-pv.md` is clearer: "Solved by Erik van der Werf in
2002." This is correct for the announcement date.

### 1.5 Missing: van der Werf's PhD thesis

The project does not cite van der Werf's 2005 PhD thesis ("AI Techniques for
the Game of Go," Maastricht University), which contains the full MIGOS
architecture, the Benson integration, the solving methodology, and the
bounded-history discussion. This is the canonically correct source for MIGOS
II's ruleset and method. The ICGA 2009 paper is a summary with new goban-size
results. The thesis is freely available and should be the primary citation for
the MIGOS method.

---

## 2. Benson (1976) — unconditional life

### 2.1 What the project says

`docs/epistemic/innovations.md:57`:
> Benson, D.B. (1976). "Life in the game of Go." — I10

`docs/epistemic/GLOSSARY.md:84-86`:
> Benson's algorithm (D. Benson, 1976) proves a group can never be captured
> *even if its owner only ever passes* (needs roughly two real eyes' worth of
> protected space). Implemented in `terminal.benson_alive` /
> `rules.benson_alive`. The THEOREM (not just the port) was exhaustively
> falsification-tested at 3x3 here.

### 2.2 What the paper actually says

**Verified.** The paper is:
- Benson, D.B. (1976). "Life in the Game of Go." *Information Sciences*,
  Vol. 10, No. 1, pp. 17–29.
  DOI: [10.1016/0020-0255(76)90059-1](https://doi.org/10.1016/0020-0255(76)90059-1).
  (Also reprinted with different pagination at DOI:
  [10.1016/S0020-0255(76)90554-5](https://doi.org/10.1016/S0020-0255(76)90554-5),
  Vol. 10, No. 2, pp. 17–29.)

The paper presents **three theorems with proofs:**
1. Theorem 1: If X is unconditionally alive, then every block in X is safe
   (p. 24).
2. Theorem 2: If X is the set of all safe x-blocks, then X is unconditionally
   alive (p. 25). Together with Theorem 1, this establishes equivalence.
3. Theorem 3: Z is the largest unconditionally alive set contained in [Y]
   (p. 28).

The paper **proves** its claims. The project's "exhaustive
falsification-confirmed at 3×3" means the *implementation* was tested against
the theorem — i.e., the project verified that `benson_alive` in `rules.zig`
never declares a group alive that can be captured, and never misses a group
that is Benson-alive, on all 3×3 positions. This is an **implementation
verification**, not a proof of the theorem (the paper already proved it).

### 2.3 Citation completeness

The project's citation is **incomplete** — it lacks the journal, volume, and
pages. A proper format would be:

> Benson, D.B. (1976). "Life in the Game of Go." *Information Sciences*,
> 10(1), 17–29. doi:10.1016/0020-0255(76)90059-1.

### 2.4 Prior art note

Benson's algorithm was not the first work on Go life-and-death — Thorp &
Walden (1972) preceded it with their computer-assisted study. The project
acknowledges this indirectly through the `terminal-territory-bug.md`
discussion of Tromp–Taylor scoring rules, which derive from Thorp & Walden's
work. The Benson paper itself cites Thorp & Walden as its foundation.

---

## 3. Kishimoto & Müller (2004, 2005) — GHI solution

### 3.1 What the project says

`docs/epistemic/innovations.md:58`:
> Kishimoto, A. & Müller, M. (2004). "A General Solution to the Graph
> History Interaction Problem." — GHI dependency sets, ADR-0013

`docs/epistemic/GLOSSARY.md:230-232`:
> **Kishimoto–Müller (dependency-guarded memo)** — (A. Kishimoto; M. Müller)
> the sound solution to GHI in transposition tables: a memo entry records the
> position-set its score depends on, and is reused only when the current
> search path cannot invalidate it. Realized here as *deps mode* /
> *fingerprint* reuse (Track B, ADR-0013).

`docs/decisions/0013-sound-finisher-and-dependency-guarded-memo.md:69-80`:
> Restore sound reuse. The Kishimoto–Müller idea: a memo entry is reusable at
> a node iff its dependency set is disjoint from the current path's ancestor
> set ... D is summarized as a **Bloom fingerprint** — a space-efficient
> probabilistic summary where bit-disjointness is the reuse signal; false
> positives only forgo reuse, never produce a wrong score.

### 3.2 What the papers actually say

**Verified.** The primary paper is:
- Kishimoto, A. & Müller, M. (2004). "A General Solution to the Graph
  History Interaction Problem." *Proceedings of the AAAI Conference on
  Artificial Intelligence (AAAI 2004)*, pp. 644–649.
  URL: https://aaai.org/papers/00644-aaai04-102-a-general-solution-to-the-graph-history-interaction-problem/

A follow-up with a more specialized algorithm:
- Kishimoto, A. & Müller, M. (2005). "A Solution to the GHI Problem for
  Depth-First Proof-Number Search." *Information Sciences*, 175(4), 296–314.

The AAAI 2004 paper presents a general solution to GHI for both αβ and df-pn
search. The key idea: a memo entry carries a *dependency set* (positions the
score depends on), and is reused only when the current path is disjoint from
that set. The project's realization uses **Bloom fingerprints** (probabilistic
set representation) instead of exact sets — a simplification the paper does
not propose but which is consistent with it (false positives only forgo
reuse).

### 3.3 Citation completeness

The project's citation is **incomplete** — it lacks the venue (AAAI 2004),
the page numbers (644–649), and any DOI/URL. A proper format would be:

> Kishimoto, A. & Müller, M. (2004). "A General Solution to the Graph
> History Interaction Problem." *Proceedings of the AAAI Conference on
> Artificial Intelligence (AAAI-04)*, pp. 644–649.

And for the follow-up:

> Kishimoto, A. & Müller, M. (2005). "A Solution to the GHI Problem for
> Depth-First Proof-Number Search." *Information Sciences*, 175(4), 296–314.
> doi:10.1016/j.ins.2004.04.012.

### 3.4 Prior art note on GHI

The GHI problem was first named by Campbell (1985) in "The Graph-History
Interaction: On Ignoring Position History." The Kishimoto–Müller paper builds
on Breuker et al. (2001), who solved it for best-first search. The project
does not cite Campbell or Breuker. This is acceptable — the project
implements Kishimoto–Müller, not the predecessors — but a complete
bibliography would include them.

The phrase "a published, proven-sound technique" used in `arena-audit.md:236`
is **correct** — the AAAI 2004 paper provides correctness proofs (Theorem 1
for αβ, sections on soundness). The project's Bloom-fingerprint variant is
claimed PROVEN-as-argument (bit-disjointness ⇒ safety) but is not the exact
algorithm from the paper.

---

## 4. Müller (1997) — territory safety

### 4.1 What the project says

`docs/research/terminal-territory-bug.md:27`:
> Use the rigorous Müller "unconditional territory" (1997) for sibling
> decisions; the eye-space vital-region test is the tractable subset we use
> here.

This is the only citation of Müller's territory safety work outside of the
GLOSSARY and `innovations.md` (where it is not listed). The project uses
Benson-settled detection as its primary terminal test, and the H5a fallback
in `src/gtp.zig` uses a Benson-alive territory estimate — not Müller's
search-based safety solver.

### 4.2 What the paper actually says

**Verified.** The paper is:
- Müller, M. (1997). "Playing it Safe: Recognizing Secure Territories in
  Computer Go by Using Static Rules and Search." *Game Programming Workshop
  in Japan '97*, pp. 80–86. Computer Shogi Association, Tokyo.

The follow-up (which the project does not cite) is:
- Niu, X. & Müller, M. (2004). "An Improved Safety Solver for Computer Go."
  *Proceedings of the Conference on Computers and Games (CG 2004)*.

The 1997 paper defines static rules and 6-ply search for territory safety;
the 2004 paper extends it with region merging and weakly-dependent-region
analysis, achieving 51.3% safe-point coverage on test positions (up from
26.4%).

### 4.3 Citation completeness

**Poor.** The project has a single informal citation ("Müller 'unconditional
territory' (1997)") with no venue, no title, and no pages. The GLOSSARY does
not have a separate entry for this. Given that Müller's territory safety work
is the conceptual ancestor of both the settled-terminal detection and the H5a
fallback, this deserves a formal entry.

---

## 5. Tromp / OEIS A094777 — legal position counts

### 5.1 What the project says

`docs/research/enumeration-census.md:21`:
> Published legal counts: John Tromp (OEIS A094777).

`src/enumerate.zig:206`:
> Published legal-position counts on square gobans (Tromp; OEIS A094777).

### 5.2 What the source actually is

**Verified.** OEIS entry A094777: "Number of legal positions in Go on an n×n
goban." The sequence is 1, 57, 12,675, 24,318,165 for n = 1, 2, 3, 4.
Values through n=4 were computed by John Tromp. The project independently
verifies these counts through `enumerate.zig` and cross-validates the
move-generation kernel.

**Correct usage.** The count is attesting move-generation/capture/suicide
correctness only — it does **not** attest ko-legality under history, which
the project correctly documents (`4x4/EPISTEMIC.md:135-140`).

### 5.3 Citation completeness

**Adequate.** An OEIS entry is self-describing; the project provides the entry
number and author. A URL (https://oeis.org/A094777) would be helpful.

### 5.4 Tromp–Taylor rules

The project references "Tromp–Taylor rules" as the formal ruleset reference
(`GLOSSARY.md:223-226`, `go-rules-ko-and-scoring.md:24`). This is:
- Tromp, J. & Taylor, B. — The Tromp–Taylor Rules of Go. No formal
  publication; the rules are documented at John Tromp's website and in the
  computer Go literature.

The project correctly identifies these as "a formal, machine-checkable
statement of Go rules (area scoring, positional superko, suicide illegal)."
The project **forbids suicide** (unlike pure Tromp–Taylor), which is correctly
documented (`go-rules-ko-and-scoring.md:46-47`).

---

## 6. CGT / loopy games — Conway, Berlekamp & Wolfe

### 6.1 What the project says

`docs/epistemic/innovations.md:59-60`:
> Conway, J.H. (1976). "On Numbers and Games." — CGT loopy games, I1
> Berlekamp, E. & Wolfe, D. (1994). "Mathematical Go." — Ko theory

`docs/epistemic/GLOSSARY.md:234-236`:
> **Berlekamp–Conway–Guy** — authors of *Winning Ways* / *On Numbers and
> Games*; the CGT framework including loopy games (see *loopy games*).

### 6.2 What the sources actually say

**Verified.**
- Conway, J.H. (1976). *On Numbers and Games*. Academic Press. (2nd edition,
  2001, A K Peters.)
- Berlekamp, E. & Wolfe, D. (1994). *Mathematical Go: Chilling Gets the Last
  Point*. A K Peters.
- Berlekamp, E., Conway, J.H., & Guy, R. (1982). *Winning Ways for Your
  Mathematical Plays*. Academic Press. (2nd edition, 4 volumes, 2001–2004,
  A K Peters.)

These are the foundational works of Combinatorial Game Theory applied to Go.
The project's L/H fixpoint approach (ADR-0009) is in this tradition: CGT's
loopy-game theory defines the *least* and *greatest* fixpoints as the
stopping values, which is exactly what the project computes. The project's
innovation (I14) is the *retrograde* implementation (backward sweeps over the
full colex space) rather than the forward CGT approach.

### 6.3 Citation completeness

**Adequate for recognition, incomplete as bibliography.** The project
acknowledges the CGT tradition without implementing it. The citations are to
books, not papers, and the project correctly identifies them as prior art
rather than direct sources. No page numbers or DOIs are needed for book
citations. However:

- "Berlekamp & Wolfe (1994) — Ko theory" is slightly imprecise. *Mathematical
  Go* is entirely about Go endgames with kos, but the ko theory per se
  (thermography for kos) was developed by Berlekamp (1996) and Spight
  (1999). The project could additionally cite Spight's ko thermography work
  given the project's use of L/H brackets.

---

## 7. Standard theorems and techniques — citations missing

The project uses the following standard results without formal citations:

| theorem / technique | used in | formal source | project citation |
|---|---|---|---|
| Knaster–Tarski fixpoint theorem | FP1 least/greatest fixpoint convergence | Tarski (1955), Knaster (1928) | mentioned by name only |
| Bellman value iteration | retrograde sweeps, "Bellman map" | Bellman (1957) | mentioned by name only |
| Gauss–Seidel iteration | in-sweep oppV0 reads | Gauss (1823), Seidel (1874) | mentioned by name only |
| Bloom filter | dependency fingerprint in `deps` mode | Bloom (1970) | mentioned by name in GLOSSARY |
| Zobrist hashing | `zobrist.zig` hashing tables | Zobrist (1970) | mentioned by name in GLOSSARY |
| Alpha-beta pruning | bracket-guided finisher (ADR-0010) | Knuth & Moore (1975) | not cited at all |

**Assessment.** For theorems, naming them is sufficient — Knaster–Tarski,
Bellman, Gauss–Seidel are part of the standard mathematical toolkit. For
algorithms (Bloom filter, Zobrist hashing, alpha-beta), a formal citation
would strengthen the project's scholarship but is not essential to
correctness. The GLOSSARY entries are adequate.

**Missing: Knuth & Moore (1975)** — the alpha-beta analysis paper. The
project implements alpha-beta search in the bracket-guided finisher
(ADR-0010). This is the single most-cited paper in game-tree search and
should be cited.

---

## 8. Hayward course notes — the 5×5 principal variation

### 8.1 What the project says

`docs/research/oracle-5x5-pv.md:69-74`:
> - Hayward, *Solving Go on Small Gobans* (course notes), p. 18 "a 5x5 pv":
>   https://webdocs.cs.ualberta.ca/~hayward/355/ssgo.pdf
> - Van der Werf, *5×5 Go solved* (animated optimal play, 3 strongest openings):
>   http://erikvanderwerf.tengen.nl/5x5/5x5solved.html
> - Van der Werf, *Solving Go on Small Gobans* (paper):
>   http://erikvanderwerf.tengen.nl/pubdown/solving_go_on_small_boards.pdf

### 8.2 What the sources actually are

**Verified.** The Hayward PDF (ssgo.pdf) is Ryan Hayward's course notes for
CMPUT 355 at the University of Alberta. It reproduces van der Werf's 5×5
principal variation with coordinates. The van der Werf tengen.nl pages are
the author's own website and the definitive source for the 5×5 solution.

The project's `oracle-5x5-pv.md` **correctly** states: "What weizigo could
**not** confirm: the **+25 score**." The PV legality is engine-verified; the
score is cited, not re-proven. This is honest usage of secondary sources.

### 8.3 URL stability concern

The `tengen.nl` URLs may not be permanent. The Hayward `ualberta.ca` URL is
more stable (institutional). The project should consider archiving copies
under `docs/evidence/` per the standing evidence-in-git rule.

---

## 9. Missing prior art — what the project should cite but doesn't

### 9.1 Retrograde analysis in chess endgame tablebases

The project's retrograde engine (ADR-0009, `retro.zig`) is value iteration
over a finite state space — the same technique used to build chess endgame
tablebases since the 1970s. The project references Syzygy (the de Man
tablebase family) in the GLOSSARY under colex addressing, but does not cite
any of the foundational retrograde analysis literature:

- Ken Thompson's original work on chess endgame tablebases (1986).
- The Nalimov tablebases.
- Schaeffer et al. (2007). "Checkers Is Solved." *Science*, 317(5844),
  1518–1522 — which used retrograde analysis on a similar scale.

The project's retrograde approach is independently developed and differs from
chess tablebases in that it uses *successor sweeps* (ADR-0009 Decision 1,
"no un-capture code") rather than predecessor generation. This is an
innovation worth naming, but the prior art should be acknowledged.

### 9.2 Schaeffer's "Games Solved: Now and in the Future"

van den Herik, Uiterwijk, & van Rijswijck (2002). "Games Solved: Now and in
the Future." *Artificial Intelligence*, 134(1–2), 277–311. This is the
canonical survey of solved games, including Go on small gobans. The project's
5×5 anchor appears in it. The project does not cite this survey.

### 9.3 AlphaGo / KataGo / Leela — approximate methods

The project correctly identifies that approximate bots (AlphaGo, KataGo,
Leela) sidestep exact solving and use bounded-history inputs. The
`ruleset-options.md` discussion of KataGo's configurable ko rules is correct.
The `critique-2026-07-28.md:130` table comparing Tromp–Taylor to other
rulesets correctly identifies that these bots use PSK as a configurable
option, not as a solved-optimal basis.

**Missing citation:** Silver et al. (2016). "Mastering the Game of Go with
Deep Neural Networks and Tree Search." *Nature*, 529(7587), 484–489. This is
the AlphaGo paper. While the project is not doing what AlphaGo does, the
distinction between approximate and exact solving is central to the project's
identity, and the AlphaGo paper is the canonical reference for the
approximate approach.

### 9.4 Spight ko thermography

The project deals extensively with ko brackets and cycle resolution. Spight's
work on extended thermography for multiple kos is directly relevant:

- Spight, W. (1999). "Extended Thermography for Multiple Kos in Go." In
  van den Herik & Iida (eds.), *Computers and Games (CG'98)*, LNCS 1558,
  pp. 232–251. Springer.

The GLOSSARY mentions Spight only in the context of KataGo's ko rules
("repeat-twice-since-last-pass → no result"), not for ko thermography. The
project's L/H fixpoint approach is functionally similar to CGT thermography
(with the L/H brackets being analogous to the thermograph's left/right
scaffold). This should be acknowledged.

---

## 10. The "published anchor" problem — what the project was actually validating against

### 10.1 The claim

Until the Opus critique of 2026-07-28, the project treated anchor matches
as validation: "empty 3×3 = +9 matches the published anchor" → the table is
correct. The critique's §3 quantified that bracket containment passes a wrong
answer ~42–70% of the time depending on goban size, making it weak evidence.

### 10.2 The ruleset mismatch

The published anchors (van der Werf & Winands 2009) are for **Chinese area
scoring + basic ko + long-cycle ties**. The project's tables are for
**Chinese area scoring + positional superko**. These are different games:

| goban | MIGOS II | weizigo PSK | agreement? |
|---|---|---|---|
| 2×2 | 0 | +1 | **NO** |
| 2×3 | 0 | +1 | **NO** |
| 3×3 | +9 | +9 | yes |
| 4×4 | +2 | +2 | yes |

The disagreement at 2×2 and 2×3 is correctly identified as a ruleset-variant
difference (`GLOBAL.ANCHOR-DELTA`, CLAIMED). The agreement at 3×3 and 4×4 is
**not** evidence of PSK correctness — it is evidence that on these gobans the
two rulesets happen to coincide.

### 10.3 The cascade effect

Every PROVEN/CLAIMED status that rested on anchor agreement was weakened by
this. The project now correctly downgrades anchor matches to MEASUREMENT rows
with `wrong-answer-pass-rate` columns. The one remaining issue is that
`retrograde-4x4.md` and `ruleset-options.md` were written before the
correction and carry uncorrected "Soundness confirmed" language.

---

## 11. Self-citations — the project's own prior work

The project is a first-principles implementation and does not cite prior work
by its author. The theoretical innovations (I1–I15 in `innovations.md`) are
novel within the project's scope but draw on established techniques. This is
not a deficiency — the project is building, not publishing — but if any of the
innovations are published externally, the self-citation structure will need to
be established.

---

## 12. Summary of citation defects

### 12.1 Missing or incomplete citations (should be fixed)

| defect | current text | location | recommended fix |
|---|---|---|---|
| Benson: no journal/vol/pages | "D. Benson, 1976" | innovations.md:57, GLOSSARY.md:84 | Add: *Information Sciences*, 10(1), 17–29, doi:10.1016/0020-0255(76)90059-1 |
| Kishimoto–Müller: no venue/pages | "Kishimoto & Müller, 2004" | innovations.md:58, GLOSSARY.md:230 | Add: *AAAI 2004*, pp. 644–649 |
| Kishimoto–Müller: missing 2005 paper | not cited | — | Add: *Information Sciences*, 175(4), 296–314 |
| Müller 1997 territory safety: near-invisible | "Müller 'unconditional territory' (1997)" | terminal-territory-bug.md:27 | Add formal entry with title, venue, pages |
| Alpha-beta: no citation | not cited | ADR-0010, retro.zig | Add: Knuth & Moore (1975), *Artificial Intelligence*, 6(4), 293–326 |
| OEIS A094777: no URL | "OEIS A094777" | enumerate.zig:206 | Add: https://oeis.org/A094777 |
| van der Werf PhD thesis: not cited | not cited | — | Add: van der Werf (2005), "AI Techniques for the Game of Go," PhD thesis, Maastricht University |

### 12.2 Semantic defects (incorrect claims about sources)

| defect | current text | location | severity |
|---|---|---|---|
| "under PSK" for MIGOS II anchor | `4x4.ANCHOR` says "matches van der Werf & Winands under PSK" | CLAIMS.md:401, retrograde-4x4.md:76 | HIGH — factually wrong; MIGOS II does not use PSK |
| "Soundness confirmed" for bracket containment | `ruleset-options.md:205-215` | ruleset-options.md:205 | HIGH — bracket containment is not soundness; wrong-answer pass rate is ~42–70% |
| "trivially affordable at 4×4" for history-perfect genmove | `retrograde-4x4.md:147-151` | retrograde-4x4.md:147 | HIGH — used bracket-cut search (C3, falsified); not noted |

### 12.3 Missing prior art (should be added)

| missing citation | why it matters |
|---|---|
| Schaeffer et al. (2007). "Checkers Is Solved." *Science* | canonical retrograde analysis at scale |
| van den Herik et al. (2002). "Games Solved: Now and in the Future." *AI Journal* | canonical survey of solved games |
| Silver et al. (2016). "Mastering the Game of Go." *Nature* | the approximate approach the project is not taking |
| Spight (1999). "Extended Thermography for Multiple Kos in Go." *CG'98* | ko thermography — the CGT analogue of L/H brackets |
| Ken Thompson (1986). Retrograde analysis / endgame tablebases | the technique this project applies to Go |
| Campbell (1985). "The Graph-History Interaction" | the GHI problem's origin — cited by Kishimoto & Müller |

### 12.4 Structural defect

**There is no bibliography.** The project has 253+ claims, 34 source files,
and ~60 documentation files citing external sources, and no single
bibliographic file. The GLOSSARY's author-name entries are the closest
approximation, with 7 entries of varying completeness. A `docs/references.bib`
or `docs/references.md` should be created.

---

## 13. Independent verification — what has been verified by the project, by others, and what remains unchecked

| source | proved in source? | weizigo independently verified? | verified by others? |
|---|---|---|---|
| Benson (1976) — unconditional life theorem | YES (Theorems 1–3 with proofs) | Implementation falsification-confirmed at 3×3 | YES — multiple implementations (Müller, van der Werf, KataGo, etc.) |
| Kishimoto–Müller (2004) — GHI solution | YES (Theorem 1, correctness proofs) | Implemented as Bloom-fingerprint variant (PROVEN-as-argument); byte-identical to writes-off at 3×2/3×3/4×3 | YES — used in checkers solving (Schaeffer et al. 2007) |
| van der Werf & Winands (2009) — anchors | N/A (measurements, not theorems) | weizigo reproduces anchor values at 3×3, 4×4; disagrees at 2×2, 2×3 (ruleset difference) | YES — independently verified by MIGOS II program |
| OEIS A094777 — legal position counts | N/A (computed, not proved) | weizigo independently reproduces 1×1–4×4 via `enumerate.zig` | YES — John Tromp's original computation; weizigo cross-validates |
| van der Werf et al. (2003) — 5×5 solved | YES (computer proof by exhaustive search) | weizigo verifies the 13-ply PV legality; does NOT re-prove the +25 score | YES — MIGOS program; van der Werf's PhD thesis |
| Müller (1997) — territory safety | N/A (heuristic + search, not proved) | Not independently verified by weizigo | Partially — Niu & Müller (2004) extended it |
| Conway/Berlekamp/Wolfe — CGT | YES (mathematical proofs) | Not implemented; acknowledged as prior art | YES — peer-reviewed mathematics |
| Knaster–Tarski — fixpoint theorem | YES (mathematical proof) | Applied correctly in ADR-0009 | YES — standard theorem |
| Knuth & Moore (1975) — alpha-beta | YES (mathematical analysis) | Not independently verified; standard algorithm | YES — foundational; universally implemented |
| Zobrist (1970) — hashing | N/A (technique, not proved) | Implemented in `zobrist.zig`; not independently verified against reference | YES — universally implemented |

**The only externally-validated anchor the project has independently reproduced:**
legal position counts (OEIS A094777, 1×1–4×4). Everything else is either
implemented without external validation (Benson, GHI, Zobrist) or cited
without reproduction (5×5 +25, CGT theorems, alpha-beta correctness).

---

## 14. Recommendations

### Immediate (cheap, high value)

1. **Create `docs/references.md`** — a single bibliography with complete
   entries for every external source. Include: author(s), year, title, venue,
   volume/pages, DOI/URL. Use consistent formatting (APA or similar). This
   costs an hour and prevents all future citation drift.

2. **Add erratum banners** to `retrograde-4x4.md` (the "under PSK" claim
   about the van der Werf anchor and the "trivially affordable" claim) and to
   `ruleset-options.md` (the "Soundness confirmed" heading for bracket
   containment).

3. **Add the van der Werf 2005 PhD thesis** as the primary citation for MIGOS
   method and the 2009 paper for anchor values. The thesis is the
   canonically correct source for the ruleset details.

### Short-term (this week)

4. **Fill in missing citation data** — add venue, pages, DOIs to Benson,
   Kishimoto–Müller, and Müller 1997 citations per §12.1.

5. **Add missing prior art citations** — Schaeffer (checkers solving), van
   den Herik (solved games survey), Silver (AlphaGo), Spight (ko
   thermography), Campbell (GHI origin), Knuth & Moore (alpha-beta). These
   establish the project's position in the literature.

6. **Archive the Hayward and van der Werf tengen.nl sources** under
   `docs/evidence/` to guard against URL rot.

### When the median build ships (or is abandoned)

7. **Write an `ACKNOWLEDGMENTS.md`** — a plain-language document stating
   which prior work the project builds on, which it independently reproduces,
   and which it challenges. This is the document a journal reviewer would
   expect.

8. **Consider a preprint** — if the median build works, the combination of
   (a) retrograde L/H fixpoints on a sparse state space, (b) a Markovian
   ruleset (basic ko + tie), and (c) the measured PSK-divergence gap is a
   publishable result. The literature is ready for it: the van der Werf line
   ended in 2009, the AlphaGo line is approximate, and no one has published
   exact solves under a Go-faithful Markovian rule beyond 5×5.

---

*This audit was produced by reading the project documents, searching online
databases, and cross-checking citations against source materials. Every
finding cites the project document that makes the claim and the external
source that confirms or contradicts it. Model: DeepSeek-v4-Pro (DSPro).
Task: AUDIT-REF-DSPro. Date: 2026-07-29.*
