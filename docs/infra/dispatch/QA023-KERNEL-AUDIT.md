<!--managent set=B-->
# QA023-KERNEL-AUDIT — verify the fixpoint-kernel bug that withdrew the C2 falsification

**Opened by:** `PINRULE-SUFFICIENCY`'s interim finding (`docs/evidence/QA-023/pinrule-sufficiency-2026-07-29.md` HEADLINE 1), confirmed by the Orchestrator at the code and reverted in `CLAIMS.md` the same turn. **Verify-then-promote applies to this finding too** — reverting an unsupported falsification was the conservative action and needed no gate; asserting *"the kernel is broken and here is the corrected table"* does. ANALYSIS, read-only, no file conflicts.

## The claim to verify

`fixpoint_kernel` in `src/qa023_probe.zig` seeds `L_tab = -6` and `H_tab = +6` (`:881-885`). Its **White** branches update only on `best < L_tab[li]` (`:961`) and `best > H_tab[hi]` (`:1020`) — guards that can never fire against the seed. Consequence claimed: all **878** White-to-move reachable non-terminals keep `(-6,+6)`, so `median(-6, TIE, +6) = 0` **by construction**, and every C2 "counterexample" was White-to-move.

Three lines of evidence already on the table, each to be checked independently:

1. **The code** — the Orchestrator read `:940-965` and `:1006-1022` and agrees. Read it yourself; do not take either of us on trust.
2. **The invariant** — `pin_L=142` vs `pin_H=0` in every published run. `AGENTS.md:46` states `L(-pos,-side) == -H`; on an inversion-symmetric reachable set that forces `pin_L == pin_H`. Confirm the reach set *is* inversion-symmetric — that is the premise the argument rests on, and it is the one nobody has checked.
3. **The seven counterexamples** — claimed to be forced-single-successor (only legal move = pass to own terminal), so correct Bellman forces `L == H == area_score`, matching the hand-verified `+1,+1,+1,+1,+3,-6,-6`. Verify the single-successor property directly from `moves()`.

## The task

1. **Reproduce or refute** each of the three, independently — your own implementation for the census, not a re-run of the PINRULE-SUFFICIENCY worker's.
2. **Check the corrected kernel against a trusted reference.** `src/retro.zig` carries an EXP-11-verified side-keyed operator and `smoke_fixpoint_2x2` an unconditional monotone Gauss-Seidel. The PINRULE-SUFFICIENCY worker cites both as the correct pattern; confirm that its corrected kernel agrees with one of them on a shared instance.
3. **Grade the residual diagnostics**: Bellman residual as-shipped (L=58, H=453) → corrected (0/0); inversion violations 453 → 0; the bug-compatible port reproducing the published census exactly (948/1532/142/0). A port that reproduces a buggy census exactly is strong evidence the bug is understood — **say whether you agree that inference is sound.**
4. **Then rule on C2.** With a correct kernel, is `median(L,TIE,H)` falsified at 3×2 or not? This is the question `QA-026` / `GLOBAL.LONGCYCLE` / `QA-013` hang on; all three were reverted to their prior statuses pending this.
5. **State what else the bug contaminates.** `fixpoint_kernel` fed the 2×2 smoke, the pin census quoted in several deliverables, and `2B-PROBE-FIX`'s comparison baseline. Enumerate every published number that came through it.

## Acceptance

- Per-item VERIFIED / PARTIAL / WRONG on the three evidence lines.
- An explicit C2 verdict on a corrected kernel, or an explicit statement that it remains unmeasured and why.
- The contamination list.
- **The wrong-answer pass rate of your own check** — and note that this is the third time an instrument defect has been mistaken for a result in this chain (σ-in-arrival, the mis-transcribed table row, now the kernel guards). Say what would catch the fourth.

## Deliverable

`docs/audits/qa023-kernel-audit-<date>.md`. **Do not edit `src/`, `CLAIMS.md`, or any deliverable.** Read-only; propose only.

**Read first:** `docs/evidence/QA-023/pinrule-sufficiency-2026-07-29.md`, `src/qa023_probe.zig:880-1070`, `docs/epistemic/qa023-c2-adjudication-2026-07-29.md` (the adjudication now under challenge), `docs/decisions/0019-*.md`, `AGENTS.md:46`.
