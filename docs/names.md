# Canonical names

**Status: DECIDED 2026-07-25 (single-score side) — pending propagation.** The
user accepted non-overclaiming names now; "proven" is deferred until E2 (see
`status/leak-crisis.md`) supports C2/C3. The ko-sensitive side's value is a
*claimed* bound, also pending E2. Propagation checklist at the bottom is the
remaining `TODO`.

## NOTES (this discussion, 2026-07-25)

- The user's proposals: **"proven scores"**, **"ko-sensitive ranges"**,
  **"scores"**, **"position-to-score table"**.
- **Tension:** "proven scores" assumes the single-score region is *proven*
  history-independent (Claim C2 in `status/leak-crisis.md`). C2 is **not yet
  verified**. Calling unverified values "proven" repeats the exact scope
  overclaim that caused the leak crisis.
- **Two honest options:**
  1. **Earn the name.** Use a non-overclaiming name now ("single-value scores"
     or "core scores"), and rename to "proven scores" **only after E1 passes**
     (C2 supported). The name becomes a badge that the proof was earned.
  2. **Aspirational name, flagged.** Adopt "proven scores" now but mark its
     epistemic status as UNPROVEN in every chapter until E1 passes.
- **Recommendation:** option 1. Use **"single-value scores"** for the
  region's values and **"the single-value region"** for the region, until E1
  earns "proven." Honest now; upgrade later.
- "ko-sensitive ranges": "ko-sensitive" names the cause (history/cycle
  dependence) and is fine; but "ranges" are *claimed* bounds, not yet the
  *true* range (C3 unverified). Recommend **"ko-sensitive ranges"** as the
  label, with the caveat recorded (the range is a claimed bound pending E2).
- "position-to-score table": honest and descriptive; does not overclaim
  "oracle." Recommend adopting it as the logical-table name. The on-disk
  artifact format `.wzo` ("weizigo oracle", WZO1) stays as the file/format
  name for compatibility; the *concept* is the position-to-score table.
- "scores": correct — the values are deterministic area scores, not win
  rates. Keep.

## Proposed canonical set (recommendation, pending sign-off)

| # | thing | recommended name | note |
|---|---|---|---|
| 1 | the table (concept) | **position-to-score table** | honest, descriptive; `.wzo` stays as the file/format name |
| 2 | the values (general) | **scores** | game-theoretic area scores, Black-positive, komi 0; not win rates |
| 2a | single-score-region value | **single scores** (→ "proven scores" if/when E2 supports C2) | a single integer; epistemic status: unproven history-independence |
| 2b | ko-sensitive-region value | **ko-sensitive ranges** | a claimed bound `[L,H]`; epistemic status: unverified as true range (pending E2) |
| 3 | the single-score region | **the single score region** (→ "proven core" if/when E2 supports C2) | deprecated synonym "certified core" |
| 4 | the ko-sensitive region | **the ko-sensitive region** | deprecated synonym "residue"; code flag `KO_SENSITIVE` matches |

## Why "scores" and not "win rates"

The values are deterministic final scores under perfect play — integers in
[−n, +n] for an n-point board. A win rate would be a probability/expectation
over stochastic play; we have none. The ko-sensitive `[L,H]` is a **range of
possible scores**, not a confidence interval or expectation.

## Propagation checklist (`TODO` once names are confirmed)

- [ ] `GLOSSARY.md` — adopt the names; mark old terms ("certified core",
      "residue") as deprecated synonyms; add "leak" (see leak-crisis.md).
- [ ] `AGENTS.md` — update foreclosures to the canonical names.
- [ ] `decisions/` ADRs — leave historical text; cross-reference the rename
      in the next ADR.
- [ ] Code comments — update prose; `KO_SENSITIVE` already matches the
      ko-sensitive name, so no symbol sweep, only comments/docs.
- [ ] `research/` notes — update on next touch; do not bulk-rewrite history.
