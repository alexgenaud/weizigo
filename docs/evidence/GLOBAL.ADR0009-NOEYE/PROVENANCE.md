# PROVENANCE — `GLOBAL.ADR0009-NOEYE` · retrograde uses the full move set

**Author:** deepseek-v4-pro/T901 (repoint wave)
**Date:** 2026-08-24
**Claim closed:** `GLOBAL.ADR0009-NOEYE` — the retrograde graph uses the FULL legal move set
(no eye-prune); coverage is total.
**Status:** PROVEN — **unchanged by this repoint.**
**Acceptance criterion:** a committed note pinning the committed source constant and the ADR
decision text, per `docs/epistemic/c3-evidence-triage.md` §3 row 17.

---

## 1. The committed source constant

`src/retro.zig:96-98`:

```zig
/// eye-prune inside the retrograde move loop to isolate a
/// forward/retro mismatch. The sound default is the full move set.
pub const apply_eye_prune = false;
```

The retrograde sweep's move generation is gated on `apply_eye_prune`, which is `false` at
HEAD. The ADR-0009 Decision-3 rationale is the comment above it (the full move set is the
sound default; eye-prune is reserved for the forward cross-checks).

## 2. The ADR text and the independent control

- `docs/decisions/0009-*.md:109-124` records Decision 3 (the retrograde uses the full legal
  move set; coverage is total).
- `docs/evidence/ADR-0006/2026-07-30-eye-prune-validation.md` §6 uses the full-move retrograde
  table as its *sound unpruned control*, explicitly: "The retrograde value iteration
  (ADR-0009 Decision 3) uses the FULL legal move set."

## 3. Scope limits

This is a design fact, established by committed source + ADR text, not a run. It says the
retrograde *graph* is total; it does not by itself certify any particular artifact's
completeness (that is the `*`-coverage family of rows).
