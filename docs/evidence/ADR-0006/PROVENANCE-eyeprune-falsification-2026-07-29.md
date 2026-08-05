# PROVENANCE — ADR0006 eye-prune falsification (3×3 exhaustive)

- **Claim:** ADR-0006
- **Board:** 3×3 (exhaustive)
- **Total eye-positions:** 1050
- **(position, side) pairs checked:** 1050
- **Disagreements:** 0
- **Total search nodes (with prune):** 34496888
- **Total search nodes (without prune):** 150286500
- **Calibration wrong-prune pass rate:** 16/71
- **Date:** 2026-07-29
- **Model:** not stated at dispatch
- **Task:** ADR0006-FALSIFY set M
- **Source:** src/eyeprune_falsify.zig
- **Ko rule:** positional superko (matches oracle.zig)
- **Scoring:** area (Chinese), Black-positive
- **Terminal:** double pass or is_settled

## ERRATA (2026-07-30 — T114 battery)

- **Denominator:** 1,050 pairs → 824 live (226 settled, vacuous).
- **Control arm:** Not the unpruned game value — the always-cache memo is unsound under superko.
- **Calibration:** Random-cell prune (22.5% pass rate) does not model real defects.
  See `docs/audits/2026-07-30-eye-prune-validation.md` §4–§7.

The numbers above are **retained as originally published**.
