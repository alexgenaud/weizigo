# PROVENANCE — QA-018 panel seat C (Kimi-k2.7)

| field | value |
|---|---|
| Claim ID | `QA-018` (adversarial review of ADR-0017 / EXP-10) |
| Acceptance criterion | Falsifiable verdict (A or B) with named exemption argument; per-finding grades (SOUND/OVERSTATED/WRONG) on the three 025 findings; calibration; Defence-6 and Defence-7 adjudication |
| Date | 2026-07-29 |
| Model | not stated at dispatch (Kimi-k2.7, seat C) |
| Console | read-only review console; no source paths held |
| Run command | N/A (analysis only; no code was executed) |
| Artifact | None produced |
| Calibration | Planted-defence detection: Defence 6 graded WRONG (MTD convergence ≠ correctness, a categorical fallacy), Defence 7 graded OVERSTATED (bracket_fail=0 is necessary but not sufficient; the check is against the same brackets the cuts use). Falsifying case for the verdict: a clean T13 re-run with eye-pruned move generator showing zero mismatches, or an exhaustive 3×2 cut-site audit with zero fired-cut violations |
| Sources read | AGENTS.md, QA-018-REVIEW-C.md, QA-018-REVIEW-PANEL.md, QA-018-REVIEW.md, README.md, DELEGATEE.md, 0017-bracket-cut-refutation-attempt-failed.md, QA-018/refutation-attempt-2026-07-29.md, 025-fable-to-all.md, 0015-bracket-cut-soundness-search-vs-real-history.md, 0010-bracket-guided-finishing.md, c2-falsification-3x2.md, CLAIMS.md §§2.3-4.1, retro.zig (read-only, lines 460-500,535-585,638-663,995-1025,1085-1135,2395-2415) |
| One file not found | `docs/decisions/0009-certified-region.md` — read the honesty clause through secondary citations (ADR-0010:70-81, CLAIMS.md:255) |
