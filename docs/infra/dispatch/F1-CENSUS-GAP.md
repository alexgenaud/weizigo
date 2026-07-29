<!--managent set=E-->
# F1-CENSUS-GAP — trace the residual +3 in the corrected 3×2 census

**Opened by:** the kernel auditor, which spotted it while reading `F1-SEEDROOTS` and flagged it unprompted: *"census V: 2,622 → 2,586. A residual +3 gap vs the Python-port true-root prediction of 2,583 is softly reconciled but not traced."* ANALYSIS, read-only.

## Why bother with three states

Because **the last four defects in this chain were all small numeric discrepancies nobody traced.** `pin_L=142` vs `pin_H=0` was printed in every run for a day and read by no one; it was the whole kernel bug. A "softly reconciled" +3 is the same shape: an explanation that sounds plausible and was never checked.

Two independent predictions of the corrected true-root reachable count disagree:

| source | V |
|---|---|
| `2B-FIX-KO`'s Python port, corrected ko rule + single true root | **2,583** |
| `F1-SEEDROOTS` (in-tree Zig, seeds 42 → 4) | **2,586** |

Three states. Either the Python port over-trimmed, or the Zig still seeds something unreachable, or the two are counting different sets (e.g. terminals, or `passes` variants). **Name the three states.**

## The task

1. **Enumerate both reachable sets and diff them.** Print the symmetric difference as explicit `(board, side, ko, passes)` tuples — decoded to boards, not just ranks.
2. **For each of the three, decide reachability from first principles**: is there a legal move sequence from the empty-board root under the corrected ko rule reaching it? Show the sequence, or show why none exists.
3. **Say which count is right**, and correct the other side — or state that they measure different sets and define both.
4. **Check whether the discrepancy touches any published number.** The corrected census feeds `B-VACUITY`, the cycle counts, the pin census and `PINRULE-SUFFICIENCY`'s group structure. If three states move a headline figure, say which.
5. **State the wrong-answer pass rate of your own check**, and whether a "softly reconciled" discrepancy of this size could hide a systematic error rather than three isolated states.

## Acceptance

- The three tuples, decoded, with a reachability verdict and evidence each.
- A ruling on which count is authoritative.
- The list of published numbers affected, or an explicit "none".

## Deliverable

`docs/evidence/QA-023/f1-census-gap-<date>.md`. **Read-only on `src/`** — if you need a diff harness, put it in a new file and say so. Do not edit `CLAIMS.md` or any deliverable.

**Suggested seat:** the kernel auditor — it found the gap, it already holds the census context, and this is **not** self-review (`F1-SEEDROOTS` was a different worker's work). A good use of a seat that is otherwise idle behind a blocked `EXP-4`.

**Read first:** `docs/evidence/QA-023/f1-seedroots-2026-07-29.md`, `docs/evidence/QA-023/ko-fix-rerun-2026-07-29.md` §7 (the 2,583 prediction), `docs/audits/2b-2-census-audit-opus5-2026-07-29.md` (finding F1).
