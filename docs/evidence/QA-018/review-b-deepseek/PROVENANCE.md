Task: QA-018-REVIEW-B · Role: panel seat B · Model: DeepSeek Pro · Date: 2026-07-29

# Provenance — QA-018-REVIEW-B

## What this document is

A third-party adversarial review of ADR-0017 (Fable 5, EXP-10), assessing whether its "refutation failed" verdict is sound. No code was executed; the review is textual/code-inspection only.

## Sources read

All files were read from the working tree at `/Users/alex/Project/Zig/weizigo` on 2026-07-29.

### Required by the panel protocol / core brief

1. `docs/infra/dispatch/QA-018-REVIEW-PANEL.md` — panel protocol (blindness, write isolation, calibration defences, head-to-head reporting).
2. `docs/infra/dispatch/QA-018-REVIEW.md` — core brief (framing, three 025 findings, read order, acceptance, Do-NOTs).
3. `docs/infra/dispatch/README.md` — dispatch overview.
4. `docs/infra/delegation/DELEGATEE.md` — worker role and reporting rules.
5. `docs/decisions/0017-bracket-cut-refutation-attempt-failed.md` — the ADR under review (Fable 5, 2026-07-29).
6. `docs/evidence/QA-018/refutation-attempt-2026-07-29.md` — verbatim source citations for ADR-0017.
7. `untracked/msg/milestone-01-ko-reframe/025-fable-to-all.md` — the three findings in context.
8. `docs/decisions/0015-bracket-cut-soundness-search-vs-real-history.md` — the ruling under review (Opus, 2026-07-28).
9. `docs/decisions/0010-bracket-guided-finishing.md` — the original bracket-cut ADR whose justification is in question.
10. `docs/research/c2-falsification-3x2.md` — the T13 falsification (12 pointwise mismatches at 3×2).
11. `src/retro.zig` — read-only inspection of the finisher / bracket-cut implementation at the line ranges cited in the report.

### Supporting context

- `docs/epistemic/CLAIMS.md` — claim graph, particularly `GLOBAL.C3`, `GLOBAL.CERTCORE`, `GLOBAL.F2`, `GLOBAL.F3`, `3x2.T13`, `3x3.C3`, and the O1 chain (`CLAIMS.md:601-622`).
- `docs/status/leak-crisis.md` — E2 leak definition and measurements.
- `docs/evidence/README.md` — evidence-durability rules.

## Method

1. Read ADR-0017 first, forming an independent view of whether its "refutation failed" verdict lands.
2. Read ADR-0015 second, checking whether the initial view survives the ruling.
3. Read the three 025 findings and the cited `src/retro.zig` sections, verifying each claim against the code.
4. Adjudicate the two panel-protocol calibration defences (Defences 6 and 7) on the merits.
5. Record the verdict, per-finding grades, the required exemption argument, and the calibration cases that would change the verdict.

## Deliverables

- `docs/evidence/QA-018/review-b-deepseek/report.md` (this review's substance).
- `docs/evidence/QA-018/review-b-deepseek/PROVENANCE.md` (this file).
- `untracked/msg/milestone-01-ko-reframe/028-deepseek-review-to-all.md` (panel message to all seats).

## What was not done

No `src/retro.zig` edits, no engine runs, no `data/` or `artifacts/` writes, no `managent` commands, no edits to `CLAIMS.md` or any ADR, and no reading of other panel seats' deliverables or messages numbered 026 or higher.
