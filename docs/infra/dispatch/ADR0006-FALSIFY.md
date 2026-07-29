<!--managent set=M-->
# ADR0006-FALSIFY — a direct falsification test for the eye-prune

**Opened by:** `docs/audits/AUDIT-DSPro-2026-07-29.md` §2.6, adopted by the Orchestrator. ANALYSIS task — no engine file is modified, so it runs alongside anything.

## Why this matters

ADR-0006 claims that forbidding a player from filling their own Benson-alive true eye does not change the game score (weak dominance under area scoring). **Every forward search the project uses as ground truth applies this prune** — the 2×2/3×2 exact solver, the finisher, T13, E2. If ADR-0006 is wrong, every C1 proof, every C2 probe and every finisher-produced value is contaminated, and the blast radius includes the falsifications the current strategy rests on.

The only direct validation on record is a **single position** (`dead_white`, Black +25, `0006:59-61`). The standing indirect test (ADR-0009:118-123, retrograde-vs-forward disagreement) has never fired — but the forward searches use the prune and the retrograde does not, and they agree only *where both have been run* (small boards, near-terminal). Agreement on the tested subset is not soundness on the untested superset. This is standing rule 4: ask what a wrong answer would have scored.

## The task

Exhaustive at 3×3 (cheap — minutes):

1. Enumerate every position with at least one Benson-alive true eye.
2. Compute the game-theoretic score **with** and **without** the eye-prune.
3. Report every disagreement, with the position, both scores, and the line.

If 3×3 is exhaustively clean, state the result **as scoped to 3×3** and give the cost of the same test at 4×4. Do not generalise beyond what was enumerated — the project has been bitten by exactly that (C3 held at 2×2/3×2 and failed at 3×3).

## Acceptance

- The enumeration count (how many positions had a Benson-alive true eye), stated as an explicit denominator.
- Zero disagreements, or the disagreeing positions in full.
- **A calibration case**: plant a synthetic wrong prune (e.g. also forbid filling a non-eye) and confirm the harness reports it. A checker without calibration is not evidence — this is a standing project rule, and the linter caught its own calibration going stale this way.
- One line on the wrong-answer pass rate of the test.

## Deliverable

`docs/evidence/ADR-0006/eye-prune-falsification-<date>.md` + stdout + `PROVENANCE-*.md`, and a proposed `CLAIMS.md` row for the eye-prune (it currently has none — the audit found it CLAIMED on one position). **Do not edit `CLAIMS.md`.**

**Build/run:** through `tools/runner`. New source file only (suggest `src/eyeprune_falsify.zig`); do not modify `src/rules.zig`, `src/retro.zig`, `src/oracle.zig` or any engine file — read them.

**Read first:** `docs/decisions/0006-*.md` (the claim and its one test), ADR-0009:118-123 (the indirect gate), `AUDIT-DSPro-2026-07-29.md` §2.6.
