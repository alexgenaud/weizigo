# PROVENANCE — `GLOBAL.MIGOS-RULE` · MIGOS II plays basic ko + long-cycle ties, not superko

**Author:** minimax-m3/T825 (C3 buckets reconciliation wave)
**Date:** 2026-08-25
**Claim closed:** `GLOBAL.MIGOS-RULE` — "MIGOS II (van der Werf & Winands, ICGA 2009) plays basic
ko + long-cycle-ties, **not** superko; the two rulesets legitimately disagree on cycle-dominated
gobans."
**Status:** PROVEN (literature claim — quote-bearing reading of the primary source) —
**unchanged by this repoint.**
**Repointed from:** `retrograde-3x3.md:222-241` (claimlint C3 flagged: no path under
`docs/evidence/`).

---

## 1. The establishing artifact — a quote-bearing reading of the primary source

`docs/research/retrograde-3x3.md:222-241` carries the verbatim primary-source quote and the
project's reading. The critical sentence (line 226-227):

> **MIGOS II does NOT use superko** — the paper states "since superko is not used, balanced
> long-cycle repetition … is scored as a long-cycle-tie" (basic ko in the hash, cycle ties
> handled specially). weizigo plays POSITIONAL SUPERKO, where those cycles are banned moves
> instead of ties.

The quoted phrase is from van der Werf & Winands, "Solving Go for Rectangular Gobans" (ICGA
Journal 2009), §3.3 (cycle handling under basic ko).

## 2. Independent corroboration

`docs/evidence/GLOBAL-TIE-MIGOS/tie-experiment-T274.md` re-derived the MIGOS long-cycle
resolution independently, from the van der Werf 2005 PhD thesis (full text obtained 2026-08-02
from the Maastricht repository, DOI 10.26481/dis.20050127ew):

- **Thesis Appendix A §A.4 ("Repetition" — the MIGOS rules):** the long-cycle resolution rule
  (repetition ends the game; balanced cycle = draw; unbalanced cycle = the player who passed
  more wins) — a rule, not a search-constant choice.
- **Thesis §5.3.2 and the 2009 paper §3.2–3.3:** MIGOS's long-cycle tie value is **0** —
  identical to our `TIE=0`. The thesis Table 5.1 lists MIGOS's own basic-ko 4×4 result as
  **+1**, identical to our fresh-start reading.

The two sources agree on the rules and on the value, and they both quote the primary. The
project's reading is corroborated by an independent re-derivation rather than a single
quote-bearing reading of one paper.

## 3. What the claim establishes (and what it does not)

The claim is a literature reading: **MIGOS II's ruleset is basic ko + long-cycle-ties, not
superko**, and the two rulesets legitimately disagree on cycle-dominated toy gobans. It
establishes only this proposition. It does **not** establish:

- That MIGOS's 4×4 +2 anchor is the right anchor for our PSK + TIE=0 ruleset — the +1 vs +2 gap
  is a **different game** (per the thesis Appendix A §A.4 pass-difference cycle resolution;
  `GLOBAL.TIE-MIGOS` is FALSE-AS-SCOPED), not a defect in either solver.
- The MIGOS source is archived at `docs/evidence/van-der-werf-sources/ssgo.pdf` (the 2003 paper
  "Solving Go on Small Boards", glyph-encoded — does not aid text extraction) and the 2009
  paper is in the open literature. Neither is in conflict with the committed reading.

## 4. Scope limit (the load-bearing scope line)

The row's claim about "the two rulesets legitimately disagree on cycle-dominated gobans" applies
**only** to cycle-dominated toy gobans. On gobans where long cycles do not arise (or are bounded
by the move set), the rulesets agree: 3×3 = +9 matches exactly (per the same section, line 235);
2×2 = 0, 2×3 = 0, 3×4 = +4, 3×5 = +15, 4×5 = +20, 5×5 = +25 are all anchor positions where the
score does not hinge on long cycles.
