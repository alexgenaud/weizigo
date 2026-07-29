# `GLOBAL.HYPOTHESES` — provenance

**Task:** EXP-15 · **Role:** worker · **Model:** Kimi K2.7 · **Date:** 2026-07-28

**Claim ID(s) addressed.** This evidence closes the standing-tier audit request for `docs/research/open-hypotheses-2026-07-27.md`. It updates the status tags of the following claim rows in `docs/epistemic/CLAIMS.md`:

- `GLOBAL.H1`, `GLOBAL.H1-CENSUS`, `GLOBAL.LONGCYCLE`
- `GLOBAL.H2`
- `GLOBAL.H3`, `GLOBAL.H3-LOWERBOUND`
- `GLOBAL.H4`, `GLOBAL.H4a`, `GLOBAL.H4b`
- `GLOBAL.H5`, `GLOBAL.H5a`, `GLOBAL.H5a-CHILD`, `GLOBAL.H5a-FALLBACK`, `GLOBAL.H5b`, `GLOBAL.H5c`, `GLOBAL.H5d`

**Acceptance criterion.** One file `docs/evidence/GLOBAL.HYPOTHESES/reality-check-2026-07-28.md` containing:
1. a per-hypothesis table (`| id | hypothesis | verdict | evidence pointer | remediation |`),
2. total and by-verdict counts,
3. a "what to dispatch next" section for every OPEN / IN PROGRESS hypothesis,
4. a "what to close" section for every CLOSED / REJECTED hypothesis.

The deliverable file above meets all four items.

**Commit used as "now":** `eebe3c2` (per dispatch brief).

**Run command.** None — this task is an analysis of already-committed documents and evidence. No executable was run and no artifact was generated or modified.

**Files read (the input chain).**

| file | why it was read |
|---|---|
| `AGENTS.md` | Foreclosures, agent behavior, one-writer rule, evidence-in-git rule. |
| `docs/infra/delegation/DELEGATEE.md` | Worker identity and reporting conventions. |
| `docs/infra/dispatch/EXP-15-hypotheses-reality-check.md` | The task brief and acceptance criteria. |
| `docs/status/CURRENT.md` | In-flight task state and the 2026-07-28 tactical picture. |
| `docs/status/HANDOVER.md` | Session continuity and the chainability finding summary. |
| `docs/epistemic/PROGRESS.md` | Strategic state, the PSK gap, and the reframe decision. |
| `docs/INTENT.md` | Human purpose to anchor "what is consequential". |
| `docs/research/open-hypotheses-2026-07-27.md` | The hypotheses register being audited. |
| `docs/research/ko-sensitive-chainability.md` | The chainability measurements (source of H4b closure). |
| `docs/research/kostate-census-2026-07-28.md` | The H1-CENSUS result and evidence pointers. |
| `docs/research/arena-4x4-undef.md` | The B43 3.4% clean leak figure used by H2. |
| `docs/research/corrections-2026-07-27.md` | D-3 H5(a) corrections (child-check and fallback). |
| `docs/epistemic/CLAIMS.md` | Canonical claim statuses and dependency edges. |
| `docs/epistemic/boards/4x4/EPISTEMIC.md` | 4×4 FP1 / M-facts and the H4a/H4b context. |
| `docs/evidence/README.md` | Evidence-directory conventions and PROVENANCE.md format. |
| `docs/evidence/GLOBAL.H1-CENSUS/PROVENANCE.md` | Evidence format model. |

**Calibration case.** A checker must pass a known-good and catch a known-bad. The known-good used to validate the verdict logic here is the **chainability finding**: the single-score (L==H) region is chainable with zero out-of-flag violations at every size tested, and this is already committed in `docs/research/ko-sensitive-chainability.md`. A reality-check table that tagged that finding as OPEN would be wrong. This file tags H4b **CLOSED**, satisfying the calibration check.

The known-bad is the **old "4×4 was a 1:37 sample" statement** in `docs/research/open-hypotheses-2026-07-27.md`: it is now stale because the exhaustive 4×4 sweep exists. This file flags H4b as CLOSED and lists the corresponding doc edit under "what to close".

**Notes.** No source document was edited. All status tags are derived from the committed documents listed above. `untracked/` was not read or cited as evidence.
