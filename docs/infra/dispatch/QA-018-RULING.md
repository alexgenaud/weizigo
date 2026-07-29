<!--managent set=A needs=EXP-10-->

# QA-018-RULING — the human rules on bracket-cut soundness

**Closes:** `QA-018` / `QA-019`. **Blocked by:** EXP-10 (done — the
refutation ADR-0017) **and** `QA-018-REVIEW` (the third-party adversarial
review — dispatch it first; this ruling is not ready to be made until it
lands).

Not an agent task. This is the human's decision, on the board so that it is
**visible rather than an invisible manual gate**.

**The question.** ADR-0010 justifies the finisher's cuts on brackets holding
"under ANY arrival history". The OVERSEER ruled (ADR-0015) that this is refuted as
stated: for an empty-board root the finisher's search path *is* a real game line,
so E2's falsifying histories lie inside the family ADR-0010 claims to cover.
EXP-10 attempts to refute that ruling.

**Two outcomes.** Either ADR-0010's justification is too strong — `GLOBAL.F2`
stays orphaned and every shipped ko-sensitive value rests on an undischarged
argument — or the search-path family is genuinely exempt, and EXP-10 shows why.

**Note:** the OVERSEER cannot review EXP-10. He made the ruling; the ruling party
defending his ruling is not a review. Route the verdict to a third party —
that third-party review is registered as `QA-018-REVIEW`

**Done when** the ruling is recorded in an ADR superseding 0015, and `CLAIMS.md`
statuses reflect it.
