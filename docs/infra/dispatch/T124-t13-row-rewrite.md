<!--managent set=A holds=docs/epistemic/CLAIMS.md-->
# T124 — `3x2.T13` says CANNOT REPRODUCE. It was reproduced.

**Type:** register edit · **Holds:** `docs/epistemic/CLAIMS.md` · **Needs:** T123
(same file)

## The defect

`docs/epistemic/CLAIMS.md:270` carries:

> **⚠ CANNOT REPRODUCE — probe source (`untracked/c2pilot_3x2.zig`) and raw
> output (`untracked/T13-minimax.md`) are lost … the reproduction block cannot
> be executed. 2026-07-29 evidence-integrity sweep.**

This is false as of 2026-07-30. T110 re-implemented the probe **from the method
description rather than porting the lost code** — which makes it independent
evidence, not a copy — and re-executed all 12 recorded mismatches exactly, with
three independent routes agreeing on 5,868/5,868 table cells
(`docs/evidence/T13/probe-reimplementation-2026-07-30.md:16`). T110 also found
T13 was never truly lost: only the driver script was, and `retro.ab_solve` was
committed the whole time. T119 struck T13 from the ADR-0006 contamination list.

The stale warning sits on the register's most load-bearing falsification —
`3x2.T13` feeds `GLOBAL.C2`, `GLOBAL.C4`, `4x4.C2`, `GLOBAL.REFRAME`,
`GLOBAL.H1`.

## The second, larger correction

The row's claim text — "12 verified mismatches on 508 non-trivial reachable PSK
histories" — is the **weak form of its own result**. T110 §8 measures the
order-independent version: testing every distinct history rather than one per
slot gives **154 of the 508 reachable L==H slots — 30.3% — history-sensitive,
with 4,432 falsifying pairs**. Twelve is the pointwise count under one
arrival-per-slot; it understates by more than 10×.

## Task

Rewrite the `3x2.T13` row:

- Strike the CANNOT REPRODUCE block.
- Cite `docs/evidence/T13/probe-reimplementation-2026-07-30.md` and the
  committed driver sources (`docs/evidence/T13/solve_history.zig`,
  `src/t13_solve_history.zig`).
- Restate the measurement as 154/508 (30.3%), 4,432 falsifying pairs, with 12
  identified as the pointwise one-arrival-per-slot subset. Keep both numbers —
  the 12 is what every downstream document cites today.
- Check the rows that inherit from it. If any restates "12 mismatches" as the
  full result, flag it; do not silently rewrite downstream claim text.

Then run `bin/weizigo-claimlint`.

## Deliverable

Edited row, list of downstream rows whose wording now understates, claimlint
output.
