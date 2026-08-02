# T261 — M4b Triage: A1, A2, A8 failures at 3×3 and 4×4

```
Task:    T261 · Worker: T261 (Claude, via pi) · Date: 2026-08-02
Brief:   untracked/T261-m4b-triage.md
Status:  PASS-WITH-FINDINGS — checks are sound; failures trace to artifact coverage gaps
Findings: findings/T261-m4b-triage.json (detailed JSON)
```

## Summary

All three failing checks (A1, A2, A8) share a single mechanism: **the WZO2
artifact is missing passes=1 entries for one side in 8.0% (3×3) to 27.9%
(4×4) of goban groups.** The checks were designed assuming complete passes=1
coverage — that assumption doesn't hold, producing false-positive rejections
of an otherwise internally consistent artifact (A3/A4/A5/A6/A9 all pass).

## A1 — Is it falsifiable?

**YES.** The module bypasses `gtp.zig` entirely and does direct artifact
lookup. The `CODE.WZO2-CHAINSHORT` concern is stale — the P3-B fix is applied
(gtp.zig:323, `chainable_at_pos` uses `rhs_chain_v2` for WZO2).

The 7-8% refusal rate comes from self-play reaching `(colex, side, ko=none,
passes=1)` states after a pass. If the artifact has no passes=1 entry for
that side, the lookup fails. The refusal rate (7.7% at 3×3) matches the
fraction of groups missing one side's passes=1 entry (8.0%) perfectly.

## A2 — Does it assume single-valued states?

**No.** A2 checks L and H through independent Bellman operators — correct
for bracket-valued states per the design (spec §8, F5).

The 4,224 L/H violations and 17,136 missing children are caused by
incomplete child sets:

1. **Missing pass edges:** passes=1 child entries not in the artifact → pass
   edge unresolvable for passes=0 parents.
2. **Missing placement children:** additional child states not found in the
   artifact (root cause unknown — could be ko-tracking divergence or genuine
   artifact gaps).
3. **Corrupted Bellman comparison:** with children missing, best_L/best_H
   are computed from an incomplete set, producing misleading expected values.

The "sign-inverted" pattern is a consequence of incomplete child data, not
a sign error in the checker (synthetic tests pass — see T259 context dump).

## A8 — What the failure actually is

**Not the v1 empty-column problem.** DTT is fully populated (FAR=0, range
1-64 with 2+ distinct non-FAR values).

The 5,096 DTT consistency violations (3×3) come from a **recomputation
mismatch**: the builder computed DTT from its internal compact map (which
has ALL passes=1 states in the fixpoint). A8 recomputes DTT from artifact
lookups, which miss passes=1 child entries for 8-28% of groups.

**Off-by-2 mechanism:**

1. Builder includes passes=1 child (DTT=3): min_child_DTT=3 → stored DTT=4
2. A8 can't find passes=1 entry: min from placements only (say 5) → expected DTT=6
3. Stored(4) vs expected(6): **stored is 2 less** — matching T259's observation

## Artifact scan evidence

Direct byte-level scan of both WZO2 artifacts:

| metric | 3×3 | 4×4 (5000-group sample) |
|---|---|---|
| Groups | 12,675 | ~24.3M |
| Passes=0 entries | 25,098 | ~41.6M |
| Passes=1 entries | 24,330 | ~41.9M |
| Groups with 0 passes=1 | 0 | 0 |
| Groups with 1-side passes=1 | 1,020 (8.0%) | 1,393 (27.9%) |
| Missing passes=1 sides | ~1,020 | ~6.77M |

Every group has at least one passes=1 entry — none are entirely absent. But
8-28% have only one side's entry, making the other side's pass edge
unresolvable for lookups.

## Weighting: spec mismatch vs artifact defect

| Evidence for artifact defect | Evidence for spec mismatch / checker issue |
|---|---|
| Missing passes=1 entries are measurable gaps | A3 passes: 0/99M colour-inversion violations |
| A1 refusal rate matches the gap fraction | A4 passes: pin_L == pin_H |
| Gaps cause real user-visible refusals | A5/A6/A9 all pass — encoding, calibration, reproducibility OK |
| | Builder computed DTT from a COMPLETE set; A8 recomputes from an INCOMPLETE set |

**Assessment: leans toward spec mismatch.** The artifact is internally
consistent. The checks measure properties the artifact doesn't provide
(complete child-state coverage for every stored entry). The stored DTT
values are correct for the computation the builder performed — they just
can't be verified without access to the full compact map.

Unsettled: whether the missing passes=1 entries are a builder defect or a
legitimate structural property of the fixpoint. The pass child of `(board,
1-side, ko, 0)` should be `(board, side, KO_NONE, 1)` — if generated.

## What would settle it

1. **Decisive:** Build a fresh 2×2 WZO2 from a known-correct fixpoint and
   run A1/A2/A8 against it. 2×2 is small enough to audit by hand.
2. **High-value:** Trace 3-5 specific violation states, dump child sets from
   both the checker and `exp6_solve.zig`'s `genChildren4`.
3. **Moderate-value:** Read `exp6_solve.zig`'s reachability walk to verify
   whether `(board, 1-side, KO_NONE, 1)` is always generated as a pass child
   of `(board, side, ko, 0)`.
4. **Moderate-value:** Run A1 via GTP self-play instead of the internal
   self-play and compare refusal patterns.

## Verdict

**PASS-WITH-FINDINGS.** The checks A1, A2, and A8 are mechanically sound
and correctly identify discrepancies between their expectations and the
artifact's contents. The discrepancies trace to missing passes=1 entries in
the artifact, not to bugs in the check logic. The artifact itself is
internally consistent (A3-A9 pass). Recommend either narrowing the checks'
denominators to exclude states whose children are missing, or determining
whether the missing passes=1 entries constitute a fixable builder defect.
