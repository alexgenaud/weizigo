# Canonical names

**Status: DECIDED 2026-07-25, propagated 2026-07-26.** The
user accepted non-overclaiming names now. C2 (history-independence of the
single-score region) was **falsified at 3×2 by T13** (see
`status/leak-crisis.md`); C3 ([L,H] bounds real-game score) was **falsified
at 3×3 by E2**. The ko-sensitive side's score is a *claimed* bound.
Propagation checklist below — completed 2026-07-26 (B13).

## NOTES (this discussion, 2026-07-25)

- The user's proposals: **"proven scores"**, **"ko-sensitive ranges"**,
  **"scores"**, **"position-to-score table"**.
- **Tension:** "proven scores" assumes the single-score region is *proven*
  history-independent (Claim C2 in `status/leak-crisis.md`). C2 is **not yet
  verified**. Calling unverified scores "proven" repeats the exact scope
  overclaim that caused the leak crisis.
- **Two honest options (pre-T13):**
  1. **Earn the name.** Use a non-overclaiming name now ("single-score scores"
     or "core scores"), and rename to "proven scores" **only after E1 passes**
     (C2 supported). The name becomes a badge that the proof was earned.
  2. **Aspirational name, flagged.** Adopt "proven scores" now but mark its
     epistemic status as UNPROVEN in every chapter until E1 passes.
- **Post-T13 update (2026-07-26):** C2 is **falsified at 3×2** (T13), so
  "proven scores" / "proven core" are off the table for real-game correctness.
  **Option 1 is permanent.** The canonical names are: **fresh-start single-score
  region** / **single-score scores** (the L==H region's scores); **fresh-start
  ko-sensitive bracket** / **ko-sensitive ranges** (the L<H region's `[L,H]`
  spread, a CLAIMED fresh-start property, NOT a real-game bound). "Certified
  core" and "residue" remain as deprecated historical synonyms only.
- "ko-sensitive ranges": "ko-sensitive" names the cause (history/cycle
  dependence) and is fine; but "ranges" are *claimed* bounds, not yet the
  *true* range (C3 now falsified at 3×3 by E2). Recommend **"ko-sensitive ranges"** as the
  label, with the caveat recorded (the range is a claimed bound pending E2).
- "position-to-score table": honest and descriptive; does not overclaim
  "oracle." Recommend adopting it as the logical-table name. The on-disk
  artifact format `.wzo` ("weizigo oracle", WZO1) stays as the file/format
  name for compatibility; the *concept* is the position-to-score table.
- "scores": correct — the scores are deterministic area scores, not win
  rates. Keep.

## Proposed canonical set (recommendation, pending sign-off)

| # | thing | recommended name | note |
|---|---|---|---|
| 1 | the table (concept) | **position-to-score table** | honest, descriptive; `.wzo` stays as the file/format name |
| 2 | the scores (general) | **scores** | game-theoretic area scores, Black-positive, komi 0; not win rates |
| 2a | single-score-region score | **single-score scores** | a single integer; epistemic status: **falsified at 3×2 (T13); untested at larger sizes** |
| 2b | ko-sensitive-region score | **ko-sensitive ranges** | a claimed bound `[L,H]`; epistemic status: **falsified as a true range at 3×3 (E2); untested at larger sizes** |
| 3 | the single-score region | **the fresh-start single-score region** | deprecated synonym "certified core"; C2 falsified at 3×2 by T13 |
| 4 | the ko-sensitive region | **the ko-sensitive region** | deprecated synonym "residue"; code flag `KO_SENSITIVE` matches |

## Why "scores" and not "win rates"

The scores are deterministic final scores under perfect play — integers in
[−n, +n] for an n-point board. A win rate would be a probability/expectation
over stochastic play; we have none. The ko-sensitive `[L,H]` is a **range of
possible scores**, not a confidence interval or expectation.

## Propagation checklist

Global replacement of "residue" → "ko-sensitive region" / "ko-sensitive"
performed 2026-07-26.

- [x] `GLOSSARY.md` — adopted canonical names; "certified core" and "residue"
      marked as deprecated synonyms where helpful.
- [x] `AGENTS.md` — foreclosures updated to canonical names.
- [x] Code comments — prose updated; `KO_SENSITIVE` symbol already canonical;
      identifiers `residue_b`/`residue_w`/`residueDiag` renamed to
      `ko_sensitive_b`/`ko_sensitive_w`/`koSensitiveDiag`.
- [x] `decisions/` ADRs and `research/` notes — updated in this pass per the
      explicit "replace globally" instruction (overriding the prior
      "update on next touch" plan). Historical reasoning remains intact; only
      terminology changed.
