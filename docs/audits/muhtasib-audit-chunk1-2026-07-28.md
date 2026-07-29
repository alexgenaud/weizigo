# Muhtasib audit — Chunk 1: `weizigo-chainability` reproduction

**Date:** 2026-07-28  
**Auditor:** Kimi-k2.7 Auditor (Muhtasib role)  
**Scope:** reproduce the `bin/weizigo-chainability` measurements that support the 2026-07-27/28 claim that the single-score (L==H) region is chainable with zero out-of-flag violations.

## What was checked

| artifact | board | legal/side | non-settled positions | slots checked | violations (BOTH) | all flagged? | outside-flag violations | ko-sensitive % of checked | within-flag misprice | max gap |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|
| `artifacts/oracle-2x2.wzo` | 2×2 | 57 | 53 | 106 | 16 | yes | 0 | 77.36% | 19.51% | 2 |
| `artifacts/oracle-3x2.wzo` | 3×2 | 489 | 459 | 918 | 72 | yes | 0 | 41.18% | 19.05% | 12 |
| `artifacts/oracle-3x3.wzo` | 3×3 | 12,675 | 12,413 | 24,826 | 688 | yes | 0 | 35.04% | 7.91% | 18 |
| `artifacts/oracle-4x3.wzo` | 4×3 | 321,689 | 320,055 | 640,110 | 6,092 | yes | 0 | 26.60% | 3.58% | 24 |
| `data/oracle-4x4.checkpoint.wzo` | 4×4 | 24,318,165 | 24,299,981 | 48,599,962 | 422,990 | yes | 0 | 21.33% | 4.08% | 32 |

## Commands run

```bash
cd /Users/alex/Project/Zig/weizigo
zig build -Doptimize=ReleaseFast
bin/weizigo-chainability artifacts/oracle-2x2.wzo
bin/weizigo-chainability artifacts/oracle-3x2.wzo
bin/weizigo-chainability artifacts/oracle-3x3.wzo
bin/weizigo-chainability artifacts/oracle-4x3.wzo
bin/weizigo-chainability data/oracle-4x4.checkpoint.wzo --examples 0
```

The 4×4 run completed inside the 180 s timeout; I did not record a precise wall-clock measurement.

## Source inspection

Read `src/chainability.zig` to confirm the verdict logic:

- Settled positions are exempt from the identity check (`V0 = area_score` by definition there), but their flags are still counted.
- A violation is counted only if it occurs under **both** the full move set and the eye-pruned move set.
- The verdict is `PASS` iff `bad_both - bad_both_ko == 0`, i.e. **all** violations carry the `KO_SENSITIVE` flag.
- `UNDEF` slots (`vb == UNDEF and vw == UNDEF`) are skipped.

The implementation matches the documented semantics.

## Verdicts on specific claims

### Claim A: "Zero Bellman-identity violations outside the `KO_SENSITIVE` flag"

**Status: VERIFIED** at 2×2, 3×2, 3×3, 4×3, and 4×4 on the audited artifacts. Every run reported `violations OUTSIDE ko-sensitive: 0` and `verdict: PASS`.

### Claim B: "Violations are exactly co-extensive with the `KO_SENSITIVE` flag"

**Status: VERIFIED.** At every size the count of "violations under BOTH" equals "of which KO_SENSITIVE-flagged". Specifically:

- 2×2: 16/16
- 3×2: 72/72
- 3×3: 688/688
- 4×3: 6,092/6,092
- 4×4: 422,990/422,990

### Claim C: "4×4 exhaustive sweep: 48,599,962 non-settled slots checked, 422,990 violations, 21.33% ko-sensitive"

**Status: VERIFIED.** Reproduced exactly: 48,599,962 slots checked, 422,990 violations, 10,367,922 / 48,599,962 = 21.3332%, within-flag misprice 4.08%, max gap 32 points.

### Claim D: "No settled slot is `KO_SENSITIVE`-flagged at 4×4"

**Status: VERIFIED.** Output reported `settled (exempt): 18184 (0 of their slots are KO_SENSITIVE-flagged)`.

### Claim E: "The single-score region is chainable; the ko-sensitive region is not"

**Status: VERIFIED for the `vb`/`vw` single-value columns.** The first clause is demonstrated by the zero out-of-flag violations. The second clause is demonstrated by the nonzero in-flag violations and the tool's own documentation that such violations are expected by design. The claim is **not** proven for the separate `lo`/`hi` bracket tables (see Caveat 1).

## Caveats and blocked items

1. **Scope caveat — `lo`/`hi` bracket form is not tested.** WZO1 carries no bracket columns, so the `lo`/`hi` form of FP1 check 3 remains **BLOCKED / UNVERIFIED**. The reproduction confirms only the shipped `vb`/`vw` columns. This caveat is load-bearing and is faithfully recorded in `docs/research/ko-sensitive-chainability.md` and `docs/epistemic/boards/4x4/EPISTEMIC.md`.

2. **This is a table self-consistency check, not a ground-truth check.** It confirms that the stored single-score values agree with their stored children. It does **not** verify that those values equal the true fresh-start game-theoretic score (that is C1, which remains unproven at 4×4).

3. **The tool's verdict logic was verified by source inspection, but no independent test of the tool itself was run.** I did not, for example, inject a deliberately inconsistent artifact to confirm it would report FAIL. This is acceptable for a fast first audit, but a deeper audit could add a synthetic failure-mode test.

4. **Per-board independence applies.** Verification at these five sizes does not imply anything about 5×5 or any other board.

## Overall chunk verdict

The chainability claim — **"the single-score (L==H) region is chainable with zero out-of-flag violations, and violations are exactly co-extensive with the `KO_SENSITIVE` flag, for the shipped `vb`/`vw` columns"** — is **VERIFIED** on the committed artifacts at every size tested.

The remaining caveat (untested `lo`/`hi` bracket form) is explicitly scoped and does not invalidate the verified part.
