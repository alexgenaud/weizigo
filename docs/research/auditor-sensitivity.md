# Auditor sensitivity — synthetic bug injection results

**Date:** 2026-07-26  **Source:** B09 (`untracked/B09-kimi.md`)

Three synthetic bugs injected into `src/retro.zig` to test whether the
#2 self-consistency auditor catches them.

## Results

| Bug | Class | #2 Auditor | Anchors | Would bracket catch? |
|---|---|---|---|---|
| Always memoize (remove ko_ref guard) | GHI / unsound memo | **CAUGHT** (49/56 viol) | N/A | Maybe |
| Sign-flip settled terminal | Terminal value error | **CAUGHT** (new only) | Would catch | Would catch |
| Wrong column read in sweep | Value iteration error | **NOT CAUGHT** (0 KO_SENS nodes) | **CAUGHT** | Would catch |

## Key findings

1. **The #2 auditor effectively catches GHI/memo bugs** — its primary design
   target. The "deps" (Track B) variant also catches them.

2. **The auditor catches value errors only when they create cross-root
   inconsistency.** Symmetric value corruption (bug affects both parent and
   child searches equally) passes the auditor because the minimax identity
   still holds — at wrong values.

3. **The auditor is completely blind to L/H table construction bugs.**
   If the sweep/converge produces wrong but self-consistent tables (L==H
   everywhere at wrong values), the auditor finds zero KO_SENSITIVE nodes
   to check. Overlapping gate coverage (anchors, bracket containment) is
   essential.

4. **No single gate suffices.** Anchors caught the bug the auditor missed.
   Bracket containment would catch bugs the auditor missed. The three gates
   together provide defense in depth.

## Implications

- A passing #2 auditor is necessary, not sufficient.
- Always run anchors and bracket containment alongside the auditor.
- For structural engine changes (sweep logic, convergence), trust no single
  gate — require all three.
