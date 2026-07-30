<!--managent set=C-->
# QA023-C1-WITNESS — hand-verify the one witness the whole C1 falsification rests on

**Opened by:** `QA023-KERNEL-AUDIT` naming its own remaining gap: *"The `(178,0,6,0)` arrival A tree is small enough to dump and hand-verify; **I did not dump it here.**"* ANALYSIS, read-only.

## Why this is worth a task

`QA-023` is being marked FALSE-AS-SCOPED on **one witness**: state `(178,0,6,0)` — goban `[B,W,B,␣,W,␣]`, Black to move, no ko, `passes=0` — where two valid arrivals give first-revisit-truncation values **−3** and **−6** while the corrected fixpoint gives `L=H=−6`.

Two independent implementations agree (`PINRULE-SUFFICIENCY` found it; the kernel auditor reproduced it from scratch in Python with no Zig imported), and the corrected kernel is validated three ways — against `smoke_fixpoint_2x2`, zero Bellman residuals, zero colour-inversion violations. That satisfies the two-seat rule.

**But this project has mistaken an instrument artefact for a result three times in one day** — σ-in-arrival, a mis-transcribed table row, and the kernel guards. Each survived because nobody traced a single evaluation end-to-end. The witness tree is ~22 nodes. **Dump it and read it.**

## Dispatch ruling (Orchestrator, 2026-07-29)

**Not to the PINRULE-SUFFICIENCY worker, which found the witness — and not for the reason it expects.** Its argument that the two-seat rule is already satisfied (the kernel auditor reproduced the witness from scratch in Python) is correct, so ordinary independence is not the objection. The objection is narrower and it is the failure mode that has burned this project three times today:

**the dump must not come from the harness that produced the finding.** The witness surfaced through `src/qa023_pinrule.zig` — K3's own file, which K3 wrote and holds. A dump from that harness reproduces the harness, not the truth. `2B-FIX-KO` re-ran a broken harness and confirmed it; `2B-3-AUDIT` verified everything around a defect and stopped one call short; four separate seats cited stdout containing `value-agreements: 0` without remarking on it.

So: **fresh seat, and the tree must be produced twice by independent paths.**

1. The **in-tree** evaluator — `truncated_value` in `src/qa023_probe.zig`, post-`2B-PROBE-FIX` (σ excluded, scratch sized, counters separated).
2. An **independent reimplementation** — your own, or the kernel auditor's Python verifier (`docs/audits/qa023-kernel-audit-2026-07-29.py`).

**They must agree node for node.** At ~22 nodes that is cheap, and it is precisely the check that would have caught all three earlier defects. Any disagreement is the finding.

Secondary reason: the PINRULE-SUFFICIENCY worker hit context exhaustion once already today, mid-`PINRULE-SUFFICIENCY`, and checkpointed under pressure. Handing it a second load is an avoidable risk on the task that decides `QA-023`.

## The task

1. **Dump the full arrival-A evaluation tree** for `(178,0,6,0)`: every node, its state tuple, whether it was scored as revisit / terminal / recursion, and the value returned. ~22 nodes; print all of them.
2. **Hand-check each leaf.** A revisit leaf must name the state it revisits *and* where that state entered the visit set (arrival prefix or continuation). A terminal leaf must show `passes == 2` and its `area_score`, computed by hand on the 3×2 geometry (`BOARD_W=3, BOARD_H=2`, row-major).
3. **Confirm both arrivals are legal and reachable** from the empty-goban root under the corrected ko rule, and that their visit-sets genuinely differ. Print both move sequences.
4. **Confirm the two values are within budget** — neither truncated by node budget nor by scratch overflow. The counters are separate since `2B-PROBE-FIX`; report both.
5. **Explain the mechanism in one paragraph.** Why does arrival A yield −3 where arrival B yields −6? The expected shape: A's visit-set makes some continuation a revisit (valued TIE=0) that B's does not, changing what Black can force. **If you cannot explain the difference mechanically, say so — an unexplained witness is not a falsification**, and that is the finding.
6. **State whether `−3` is reachable at all** under arrival A by an explicit line. `−6` is the fixpoint value and `0` would be a revisit; `−3` is neither, so it must come from a terminal. Name it.

## Acceptance

- The full tree, printed, with every leaf classified and hand-checked.
- Both arrival sequences, legality confirmed, visit-sets shown to differ.
- Within-budget confirmation on both, with both counters.
- A mechanical explanation of the −3 / −6 split, or an explicit statement that none was found.
- **The wrong-answer pass rate of your own check**, and: what would this check have caught in the three earlier defects?

## Deliverable

`docs/evidence/QA-023/c1-witness-handcheck-<date>.md` + the tree dump. **Do not edit `src/`, `CLAIMS.md`, or any deliverable.** If the witness fails to hold up, say so plainly and immediately — `QA-023`'s status, `ADR-0019`'s fork, and `EXP-4` all hang on it.

**Read first:** `docs/audits/qa023-kernel-audit-2026-07-29.md` §"C1 witness", `docs/evidence/QA-023/pinrule-sufficiency-2026-07-29.md`, `docs/evidence/QA-023/reference-semantics-2026-07-29.md` §1 (the recursion being evaluated).
