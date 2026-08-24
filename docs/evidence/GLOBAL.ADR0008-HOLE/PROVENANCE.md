# PROVENANCE — `GLOBAL.ADR0008-HOLE` · the `ko_ref ≥ d` retraction

**Author:** deepseek-v4-pro/T901 (repoint wave)
**Date:** 2026-08-24
**Claim closed:** `GLOBAL.ADR0008-HOLE` — the `ko_ref ≥ d` rule is "a sound-in-practice
compromise, not a theorem" — explicit retraction of ADR-0005's proof claim.
**Status:** PROVEN (as a statement about the argument) — **unchanged by this repoint.**
**Acceptance criterion:** a committed note pinning the ADR text the claim is *about*, per
`docs/epistemic/c3-evidence-triage.md` §3 row 25.

---

## 1. The committed retraction

`docs/decisions/0008-*.md:32-38`:

> The `ko_ref >= d` caching rule prevents reusing scores that DEPENDED on ancestor bans, but
> cannot know that a *new* context's ancestors would have banned a line the original search
> explored freely … the rule is a sound-in-practice compromise, not a theorem.

The register claim is a direct restatement of this passage, including the scare-quoted phrase
"sound-in-practice compromise, not a theorem" verbatim. The claim is *about* what ADR-0008 says
(it records the retraction of ADR-0005's theorem-strength claim); the ADR text is therefore the
establishing artifact.

## 2. Scope limits

This row records the retraction, not the later falsification. The falsification is the separate
row `GLOBAL.F1` (FALSE-AS-SCOPED, via `0013:20-44`); this note does not bear on that.
