# NEXT STEP: the #2 self-consistency auditor — SUPERSEDED

**Status: superseded.** Built, ran, and reported in `consistency-audit.md`.

**What it is.** A self-consistency check: under one fixed history, a
solver's own outputs must obey the minimax identity (a maximizer's node
score never strictly below its best child's score, and a minimizer mirror).
A violation PROVES a bug; passing is necessary-not-sufficient.

**Where the full intent, the implementation note, and the expected outcomes
are now recorded.** See `docs/research/consistency-audit.md` for the result
(3×2 exhaustive: 45/378 violations ON, 0/378 OFF → the cross-branch
bounds-memo writes are the bug; 3×2 + 4×4 = `RETRO_CONSIST` /
`RETRO_CONSIST4` env gates). The auditor is the standing pre-commit gate
for any change to the finisher, memo logic, or ko/GHI handling.
