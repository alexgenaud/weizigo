<!--managent set=K needs=2B-2-AUDIT-OPUS holds=src/qa023_brute_2x2.zig,src/qa023_probe.zig-->
# 2B-FIX-KO — fix the single-stone ko-capture rule (audit F5), re-run census + probe

**Opened by:** the audit of 2B-2 (`docs/audits/2026-07-29-2b-2-census-audit.md`), finding F5. **This is the gate on whether 2B-4's QA-023 falsification is real or a wrong-rule artefact.**

## The bug (F5)

`apply_place` (in `src/qa023_brute_2x2.zig`, reused by `src/qa023_probe.zig`) sets the ko point when one stone is captured and the played cell has one empty neighbour — but it never checks that the **played stone is a lone stone**, which proof-v2 §1.1's "single-stone ko capture" requires. 56 reachable edges are banned that basic ko does not ban. Under the corrected rule the 3×2 census becomes **1,676 / 1,704 / 216,176** (vs the measured 1,696 / 1,724 / 143,760).

## The task

1. **Fix `apply_place`** — add the single-stone (lone-stone) check before setting the ko point, per proof-v2 §1.1. Keep the existing tests passing (or update them if they encoded the wrong rule).
2. **Re-run the 3×2 census** (the 2B-2 mode) under the corrected rule; confirm the predicted 1,676 / 1,704 / 216,176 (or report the actual).
3. **Re-run the 3×2 probe** (the 2B-4 mode) under the corrected rule. **Report whether the 390 disagreements (36.1%, QA-023 FALSIFIED) hold, shrink, or disappear.**

## Acceptance

- The fix + its justification (cite proof-v2 §1.1).
- The corrected census numbers.
- The corrected probe result + a one-line headline: **QA-023 falsified under the corrected rule / falsification was a wrong-rule artefact / something else.**
- Calibration (the 2B-5 perturbation + PSK-sensitivity check) re-run under the corrected rule if the probe still runs.

## Deliverable

`docs/evidence/QA-023/ko-fix-rerun-2026-07-29.md` (+ stdout). **Do not edit `CLAIMS.md`** — propose the QA-023 status change; the owner folds it in once the audit chain agrees.

**Holds:** `src/qa023_brute_2x2.zig`, `src/qa023_probe.zig`. **Build/run:** through `tools/runner`; node budget + heartbeat; never unfiltered `zig test` (use `--test-filter`).

**Read first:** `docs/audits/2026-07-29-2b-2-census-audit.md` (F5), `docs/evidence/QA-023/reference-semantics-2026-07-29.md` (2B-0), the 2B-2 + 2B-4 deliverables.