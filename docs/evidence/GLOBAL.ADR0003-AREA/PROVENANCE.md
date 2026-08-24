# PROVENANCE — `GLOBAL.ADR0003-AREA` · area purity vs Japanese path-dependence

**Author:** deepseek-v4-pro/T901 (repoint wave)
**Date:** 2026-08-24
**Claim closed:** `GLOBAL.ADR0003-AREA` — area score is a pure function of the terminal snapshot;
Japanese/territory score is path-dependent and NOT recoverable from a snapshot.
**Status:** PROVEN — **unchanged by this repoint.**
**Acceptance criterion:** a committed note pinning the ADR decision text, the committed
as-stands scoring tests, and the `score.zig` header, per
`docs/epistemic/c3-evidence-triage.md` §3 row 12.

---

## 1. The decision text (both halves)

`docs/decisions/0003-*.md:13-16`:

> Area score is a pure function of the terminal snapshot (each point counts for whoever's
> stones or sole-reaching territory it is), so no history is needed …

`docs/decisions/0003-*.md:21-24`:

> Territory score needs prisoner counts, which are path-dependent and NOT recoverable from a
> snapshot …

The register claim is a two-part restatement of these two passages, verbatim in substance.

## 2. The area-purity half is also backed by committed tests and the S4 evidence

- `src/rules.zig:469-470` — test `"C2 terminal scoring is Tromp-Taylor as-stands: no dead-stone
  removal"` (area is computed from the snapshot as the stones stand; nothing is removed).
- `src/score.zig:19-36` — header `BOARD-SNAPSHOT SCORING — pure geometry, no oracle, no history`.
- `docs/evidence/GLOBAL-S4/` — `PROVENANCE.md`, `scorer-2026-07-30.py`, `verify-2026-07-30.log`
  (the committed scorer cross-validation that area is a pure snapshot function).

## 3. Scope limits

The Japanese-path-dependence half is *definitional* (it follows from prisoner counts being
history, not snapshot): it is established by `0003:21-24`, not by any run. This note pins the
decision and the committed corroboration; it does not re-derive anything.
