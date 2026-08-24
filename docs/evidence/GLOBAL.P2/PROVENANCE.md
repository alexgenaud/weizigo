# PROVENANCE — `GLOBAL.P2` · symmetry PASS is necessary, not sufficient

**Author:** deepseek-v4-pro/T901 (repoint wave)
**Date:** 2026-08-24
**Claim closed:** `GLOBAL.P2` — a symmetry PASS implies correctness — **necessary, not
sufficient**.
**Status:** PROVEN (as scoped) — **unchanged by this repoint.**
**Acceptance criterion:** a committed note pinning the committed methodology text the claim is
*about*, per `docs/epistemic/c3-evidence-triage.md` §3 row 18.

---

## 1. The committed text

`docs/epistemic/boards/CONCEPTS.md:123` (the register cites `:124`; the quoted text is the
durable locator, and the line has drifted by one — the register header pre-declares such drift):

> - **P2** symmetry PASS implies correctness. (Necessary, not sufficient.)

The register claim is this line with the parenthetical promoted to a scope qualifier:
"necessary, not sufficient" is exactly the claim's own content.

## 2. Why this is a logical statement, not a measurement

The claim asserts a *modality* about the committed methodology — that a symmetry/colour-inversion
PASS can be produced by a wrong solver (e.g. a solver that is internally symmetric but converged
to a wrong fixpoint), so the PASS is a screen, not a witness. That is a logical statement about
what the text says, established by the text itself. (Its parent `GLOBAL.INVSYM` — the colour
inversion *identity* — is proven separately; the "not sufficient" half is what makes this a
narrowed row, `narrowed = 1`.)

## 3. Scope limits

This note pins the text and the modality. It does not assert any particular validation summary
is correct; it asserts the opposite — that a green symmetry summary is not, by itself,
sufficient.
