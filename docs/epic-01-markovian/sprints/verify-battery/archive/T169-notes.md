# T169 — verify-battery V-7 M2 table invariants — NOTES

Author: DSPro/T169-w2 · 2026-07-31

## What was implemented

`src/vb_table.zig` — standalone module implementing invariants I1, I2, I3, I6, I10, I12 per
design-M1 §3.6 and spec §4.

Imports NOTHING from src/ (spec R8). Re-implements:
- WZO1 artifact loader (all 6 columns: vb, vw, fb, fw, db, dw)
- Runtime colex bijection (pos ↔ index, supports up to 4×4)
- `Colex.invertIdx()` — efficient colour-inversion without decode/encode

## Invariant implementations

### I1 — pin census (WZO1: L_eq_H only)
- Scans both Black and White columns
- L_eq_H = count of legal slots where KO_SENSITIVE bit (bit0) is clear
- denominator = total legal slots (vb legal + vw legal)
- 2×2 result: L_eq_H=32, denom=114 (16+16 per side, 57+57 legal slots)
- 3×2 result: L_eq_H=600, denom=978 (300+300 per side, 489+489 legal slots)
- NOTE: These are over ALL legal positions, not just reachable ones.
  The A3 pin census targets (2220/2232) are over reachable *game states*
  (with ko_point variants), which is a different state set. The artifact
  stores only (position, side) pairs.

### I2 — colour inversion
- Checks V(-pos,-side) == -V(pos,side) for all legal slots
- Uses Colex.invertIdx() for efficient colour-swap (O(1) per position)
- Checks both directions: vb[i] vs -vw[inv_i], vw[i] vs -vb[inv_i]
- denominator = legal_count (unique pairs checked)
- 2×2: 0 violations / 57 pairs ✓
- 3×2: 0 violations / 489 pairs ✓
- Synthetic violation fixture: PASSES (detects injected violation)

### I3 — L ≤ H
- Returns status=not_applicable on WZO1 (no L/H columns)
- Will be computable on WZO2 bracket artifacts

### I6 — UNDEF census
- Categories: illegal, legal_both_sides, legal_one_side_only
- denominator = 3^(w×h) dense address space
- 2×2: illegal=24, legal_both=57, legal_one=0, OEIS A094777=57 ✓
- 3×2: illegal=240, legal_both=489, legal_one=0, OEIS not applicable
- legal_positions_total matches artifact header legal_count at both sizes

### I10 — TIE median
- Returns status=not_applicable on WZO1 (no L/H/TIE columns)
- Will be computable on WZO2 bracket artifacts

### I12 — score range
- Checks V ∈ [-area, +area] for all legal slots (both sides)
- 2×2: 0 violations / 114 legal slots, area=4 ✓
- 3×2: 0 violations / 978 legal slots, area=6 ✓
- Synthetic violation fixtures: PASSES (detects both out-of-range-low and out-of-range-high)

## Tests

19 tests total, all passing:
- 2 artifact loader tests (2×2, 3×2)
- 4 colex tests (round-trip, exhaustive bijection, colors, invert)
- 2 I1 tests (2×2, 3×2)
- 3 I2 tests (2×2, 3×2, synthetic violation)
- 1 I3 test (not_applicable)
- 2 I6 tests (2×2, 3×2)
- 1 I10 test (not_applicable)
- 4 I12 tests (2×2, 3×2, 2 synthetic violations)

Real artifacts loaded at test runtime via std.Io.Threaded + std.Io.Dir.cwd().readFileAlloc.

## Merge notes for T168 (vb_common.zig)

When vb_common.zig ships, the following should be merged:
- GobanSize → vb_common
- VBArtifact → vb_common (or superseded by its ArtifactColumns)
- InvariantStatus → vb_common
- Colex → vb_common
- I1Result, I2Result, I3Result, I6Result, I10Result, I12Result → vb_common
- loadArtifact → vb_common (or superseded)
- pow3 → vb_common

## Per-R3 denominators

| invariant | denominator |
|---|---|
| I1 | legal slots (vb legal + vw legal) |
| I2 | legal_count (unique position-side pairs checked) |
| I3 | 0 (not_applicable) |
| I6 | 3^(w×h) dense address space |
| I10 | 0 (not_applicable) |
| I12 | legal slots (vb legal + vw legal) |
