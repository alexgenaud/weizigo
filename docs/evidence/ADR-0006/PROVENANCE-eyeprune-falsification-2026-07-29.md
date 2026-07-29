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
