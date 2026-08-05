# Race 5 · Packet R5-P1 — the MIGOS tie-semantics axiom set

*Exam item for EPISTEMIC-RACES race 5 (formal precision — seeded inconsistency audit). Audit the axiom set below for consistency. Output: a consistency audit document — CONSISTENT or INCONSISTENT; if inconsistent, name the minimal inconsistent subset and prove it; then state what the correct repair looks like. False alarms (claiming inconsistency where the set is consistent, or naming the wrong axioms) are counted against you.*

---

## The axiom set

A reconstruction of the register's statements about the MIGOS II 4×4 anchor and the
project's own build. Each axiom carries its provenance.

- **A1.** MIGOS II plays under the **basic ko** rule by default. *(Register row `GLOBAL.MIGOS-RULE`, PROVEN — the thesis's default ruleset is basic ko.)*
- **A2.** Under basic ko with long-cycle ties valued 0, the empty 4×4 fresh-start value is **+1** (Black wins by 1). *(van der Werf thesis Table 5.1; reproduced exactly by the project's own basic-ko build, which also uses tie value 0.)*
- **A3.** Under Japanese ko (repetition-scored), the empty 4×4 fresh-start value is **+2**. *(van der Werf thesis Table 5.1.)*
- **A4.** The +1-vs-+2 discrepancy between the project's basic-ko build and the published MIGOS 4×4 anchor arises because **the project's build enforces basic ko while MIGOS enforces positional superko (PSK)**. *(Proposed register row `4x4.BASICKO-TIE`, status PROVEN — this is the axiom under audit.)*

**Semantic note.** "The published MIGOS 4×4 anchor" in A4 refers to the +2 figure of A3's
row. Axioms A2 and A3 describe the same goban under two different rulesets.

## Task

Audit the set. Is it consistent? If not: which axioms form the minimal inconsistent subset,
and what is the contradiction? Then: what does the correct repair look like (which axiom
should be amended or withdrawn, and to what)?
