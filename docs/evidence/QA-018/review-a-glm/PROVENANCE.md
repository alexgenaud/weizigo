# PROVENANCE — QA-018 seat A review

- **File:** `docs/evidence/QA-018/review-a-glm/report.md`
- **Claim ID:** `QA-018` (adversarial review of `ADR-0017`, the refutation
  attempt of `ADR-0015`); bears on `QA-018`, `QA-019`, `GLOBAL.F2`,
  `GLOBAL.ADR0015-BURDEN`, `GLOBAL.C3`, `GLOBAL.CERTCORE`, ADR-0010, ADR-0015,
  ADR-0017.
- **Task:** `QA-018-REVIEW-A` (panel seat A; brief `docs/infra/dispatch/QA-018-REVIEW-A.md`).
- **Panel protocol:** `docs/infra/dispatch/QA-018-REVIEW-PANEL.md` (three-seat
  blind; write isolation §2; calibration defences §3; run-stats §4;
  independence §5).
- **Core brief:** `docs/infra/dispatch/QA-018-REVIEW.md` (applies verbatim
  except the deliverable spec, overridden by panel §2).
- **Agent:** GLM-5.2, fresh worker console (NOT the Orchestrator instance —
  panel §5 bars the role-instance; this seat is advisory input to the human
  ruling, per the 2026-07-29 user directive).
- **Model (per `DELEGATEE.md`):** GLM-5.2, as stated at dispatch.
- **Date:** 2026-07-29.
- **Verdict:** SOUND — ADR-0017's "refutation failed" verdict is SOUND;
  ADR-0015 STANDS. In-family pointwise strengthening OVERSTATED only to the
  extent of the un-re-verifiable eye-prune caveat (`QA-022`), which ADR-0017
  discloses; the verdict survives the caveat.
- **Per-finding grades:** Finding 1 SOUND; Finding 2 SOUND (wording caveat);
  Finding 3 SOUND.
- **Calibration defences (panel §3):** Defence 6 (MTD self-verification) WRONG;
  Defence 7 (`bracket_fail` gate) WRONG. Both judged on merits; the planted
  case is not identified.
- **Source files read (read-only):** `src/retro.zig` (lines ~449-600, 630-720,
  990-1130, and grep across the file), `src/oracle.zig` (lines ~180-330),
  `docs/decisions/0010/0015/0017`, `docs/decisions/0009*`, `docs/research/c2-falsification-3x2.md`,
  `docs/evidence/QA-018/refutation-attempt-2026-07-29.md`, `docs/evidence/README.md`,
  `untracked/msg/milestone-01-ko-reframe/025-fable-to-all.md`, `AGENTS.md`,
  `docs/infra/delegation/DELEGATEE.md`, `docs/infra/dispatch/README.md`,
  `QA-018-REVIEW-A.md`, `QA-018-REVIEW-PANEL.md`, `QA-018-REVIEW.md`.
- **NOT read (blindness, panel §1):** seats B/C dispatch briefs and
  deliverable directories, and any milestone message numbered ≥026.
- **Writes (this seat, panel §2 — exactly two files):**
  - `docs/evidence/QA-018/review-a-glm/report.md` (this file's sibling)
  - `untracked/msg/milestone-01-ko-reframe/027-glm-review-to-all.md`
- **No edits to:** `CLAIMS.md`, any ADR, `src/`, `data/`, `artifacts/`, the
  core brief, the panel protocol, other seats' paths, `docs/status/*`, or
  `tasks.json`. No `managent` invocation (panel §2/D-8 — the Orchestrator
  records claim/done).