# PROVENANCE — `GLOBAL.ADR0009-HONESTY` · the honesty clause

**Author:** deepseek-v4-pro/T901 (repoint wave)
**Date:** 2026-08-24
**Claim closed:** `GLOBAL.ADR0009-HONESTY` — the certification argument has one unproven step
(the memoryless-strategy leak); `L ≤ fresh-start ≤ H` and `L==H ⇒ exact` are strong structural
evidence, not a theorem.
**Status:** PROVEN (as a statement about the argument) — **unchanged by this repoint.**
**Acceptance criterion:** a committed note pinning the ADR text that the claim is *about*,
per `docs/epistemic/c3-evidence-triage.md` §3 row 6.

---

## 1. The claim is about the ADR's own argument

This row does not assert the certification argument is *true*; it asserts the argument has
one named unproven step. The establishing artifact is therefore the ADR text itself,
`docs/decisions/0009-*.md:78-89`:

> The certification argument has one unproven step. Sketch of the sound part: a
> memoryless strategy achieving L forces termination, so no NODE repeats along its plays
> … The leak: the strategy may want to create a position the opponent created earlier …
> So `L ≤ fresh-start ≤ H` and the `L==H ⇒ exact` claim are **strong structural evidence,
> not a theorem** …

The register claim is a restatement of these lines, number-for-number.

## 2. Scope limits

The row is deliberately scoped "as a statement about the argument" — it is not evidence
for or against the proposition itself (`GLOBAL.FP2` / `GLOBAL.C2`, which are falsified
elsewhere by `3x2.T13`). This note pins the text, nothing more.
