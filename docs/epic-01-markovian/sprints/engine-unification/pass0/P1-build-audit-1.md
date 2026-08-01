# P1 build audit
Auditor: DSFlash/T256 · Date: 2026-08-01
Verdict: PASS

## Test results
- zig test: PASS
- zig run: PASS
- known-bad recalibration: PASS — the test fails when the mutant is removed
- null control: PASS
- seeded-defect: PASS

## Evidence (each run reported as executed)

### 1. `zig test src/differential.zig`
```
1/3 differential.test.null control: same impl twice → perfect agreement...OK
2/3 differential.test.seeded-defect control: mutant caught with witnesses...OK
3/3 differential.test.known-bad fixture: three impls, one disagrees, witnesses correct...OK
All 3 tests passed.
```
Exit 0. All three tests pass as authored.

### 2. `tools/runner -- zig run src/differential.zig`
Runner guards active: RSS 4096 MB, progress-timeout 600 s. Output:
```
area_score @ 2x2: 81/81 agree — ALL AGREE
area_score @ 3x2: 729/729 agree — ALL AGREE
[runner] exit 0 in 3.6 s
[runner] peak RSS: 286 MB
```
Denominators are exhaustive: 81 = 3^4 boards on 2×2, 729 = 3^6 boards on 3×2.
Both operations report ALL AGREE over the full enumeration; zero disagreements.

### 3. Known-bad recalibration (anti-vacuity)
Made a temporary copy `src/differential_t256.zig` (committed files untouched; copy
deleted afterwards, `git status` verified clean for `src/differential.zig` vs HEAD)
and changed only:
```zig
fn alwaysOne(_: Board(4)) i8 { return 0; } // mutant: now identical to alwaysZero
```
Result with the mutant removed:
```
1/3 null control...OK
2/3 seeded-defect control...expected 0, found 1
3/3 known-bad fixture...expected 0, found 2
1 passed; 0 skipped; 2 failed.
```
The known-bad test FAILED exactly as the brief predicts: with all three impls
agreeing (values 0/0/0) the fixture reports 2 agreements and 0 disagreements,
so `expectEqual(0, result.agreements)` fails. The test is therefore not passing
vacuously — it genuinely detects the synthetic disagreement. The seeded-defect
control failing in the same run is a bonus: it shows the mutant-catch is
specific to the one-character mutation, and the null control still passing
shows the harness's agreement logic itself is sound. Reverted immediately; the
temp file was removed and the working tree restored.

### 4. Null control
`null control: same impl twice → perfect agreement` passes in the unmodified
run (3/3 boards agree, 0 disagreements) and — independently — also passes in
the mutant run above (it is unaffected by `alwaysOne`, which it does not use).

### 5. Seeded-defect control
`seeded-defect control: mutant caught with witnesses` passes in the unmodified
run and asserts the exact witness values: `values[0] == 0` and `values[1] == 1`
on the single board, i.e. the disagreement records each implementation's value,
not just the fact of disagreement. (Its failure under the mutation — both
impls returning 0 → 1 agreement — confirms it does not pass vacuously either.)

## Verdict rationale
All five acceptance points verified by direct execution: unit tests 3/3 PASS;
harness reports 81/81 and 729/729 ALL AGREE with exact denominators; the
known-bad fixture provably fails when its mutant is removed (no vacuous pass);
null control passes; seeded-defect catches the mutant with the correct witness
values. Note (not a defect): T252's original measurement recorded
19/81 and 129/729 disagreements at 2×2 and 3×2; the current all-agree result is
the expected post-fix state per pass0's A1+A2 remediation, and this audit
verifies the harness build rather than re-adjudicating the disagreement counts.
No committed file was modified. PASS.
