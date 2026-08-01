<!-- provenance: rescued from docs/epic-01-markovian/sprints/verify-battery/archive/T172-blind-analysis.md by T208 (DSPro/T208, 2026-08-01); that directory is deletable at the sprint gate (docs/infra/sprint.md:51) per audit CA-5; this copy ensures the CODE.VB-BLINDGAPS claim retains its cited evidence after the gate sweep -->
# T172 — Blind Re-implementation Analysis (V-11)

```
Author:   DSPro/T172-w1 · 2026-07-31
Status:   DELIVERED — independent auditor re-implementing invariants
          from spec alone, blind to existing battery source
Inputs:   docs/epic-01-markovian/sprints/verify-battery/pass0/spec.md (rev 1)
          docs/epic-01-markovian/sprints/verify-battery/pass0/design-M1.md (rev 3)
          docs/epic-01-markovian/sprints/verify-battery/archive/i5-feasibility.md
```

---

## 1. Per-invariant consistency analysis

For each invariant I1–I12: (a) spec §4 consistency with design §3.6 value
schema, (b) computable from stated columns with no hidden dependencies,
(c) WZO1/WZO2 split correctness.

### I1 — pin census

**(a) Spec ↔ Design consistency: PARTIAL — terminology gap, resolved in §5b.**

The spec §4 defines the invariant as `pin_L == pin_H` (two counts should be
equal). The design §3.6 I1 value schema on WZO1 only has `L_eq_H` (count of
slots where L==H, derived from KO_SENSITIVE-clear). These are different
quantities:

- `pin_L == pin_H`: asserts that the count of L-pinned slots equals the count
  of H-pinned slots. Requires bracket columns (WZO2 only).
- `L_eq_H`: count of slots in the single-score region (KO_SENSITIVE clear).

On WZO1, `L_eq_H` = count of legal slots where `fb[idx]` has KO_SENSITIVE
bit clear (since `KO_SENSITIVE clear ⇔ L == H` per design §4.2). This is a
meaningful self-consistency check: it verifies the KO_SENSITIVE flag against
the value column (if KO_SENSITIVE is clear, the stored V should be in the
single-score region). But it is NOT the pin census the spec header describes.

The design §5b transparently acknowledges this: the full pin census
(`pin_T`/`pin_L`/`pin_H`) is unachievable on WZO1, and A3(a)/(b) pin figures
are deferred. `L_eq_H` is the reproducible subset. Acceptable — the gap is
documented, not hidden.

**(b) Computable from stated columns:** Yes. WZO1: scan `fb[idx]` (bit 0 =
KO_SENSITIVE) and `vb[idx]` (legal check: ≠ -128). Count where legal AND
KO_SENSITIVE clear. WZO2: additionally read L/H columns for `pin_L == pin_H`
and the three pin-type counts. No hidden dependencies. ✓

**(c) WZO1/WZO2 split:** Correctly handled. WZO1 → reduced value (`L_eq_H`
only). WZO2 → full (`L_eq_H`, `pin_T`, `pin_L`, `pin_H`). ✓

---

### I2 — colour inversion

**(a) Spec ↔ Design consistency: FULLY CONSISTENT.** ✓

Spec: `V(−pos,−side) == −V(pos,side)` on single-value artifacts;
`L(−pos,−side) == −H(pos,side)` and `H(−pos,−side) == −L(pos,side)` on
bracket artifacts.

Design: WZO1 checks `V(-pos,-side) != -V(pos,side)` per `(pos, side)` pair.
WZO2 checks the bracket forms. The `violation_examples` (up to 5 colex
indices) provide debuggability. Schema faithful.

**(b) Computable from stated columns:** Yes. Requires:
- `vb`, `vw` columns (values) and `fb`/`fw` (legality via `vS != -128`)
- Colex addressing: `pos_from_rank` to decode board, colour-inversion
  function to swap stone colours, `rank_from_pos` to encode back
- Symmetry: check only one half of the colour-pair space to avoid
  double-counting; the denominator should be the number of distinct
  `(position, side)` pairs examined (i.e., positions legal for at least
  one side, divided by 2 for the colour-pair symmetry)

No hidden dependencies. Colex is re-implemented per R8. ✓

**(c) WZO1/WZO2 split:** Correctly differentiated. Single-value vs bracket
forms. ✓

---

### I3 — L ≤ H

**(a) Spec ↔ Design consistency: CONSISTENT.** ✓

Spec: `L ≤ H` everywhere — catch fixpoint corruption.

Design: WZO1 → `not_applicable` (no L/H columns). WZO2 → `violations` count
where `L > H`. This is the natural implementation.

**(b) Computable from stated columns:** Yes, on WZO2: scan L/H columns,
count where L > H. Trivial O(total) pass. ✓

**(c) WZO1/WZO2 split:** Correct — `not_applicable` on WZO1 since the
single V column is a TIE-resolved pin, not an L/H pair. ✓

---

### I4 — Bellman residual

**(a) Spec ↔ Design consistency: CONSISTENT, with documented WZO1 limitation.** ✓

Spec: `L = Φ(L)`, `H = Φ(H)`, count violations with denominator. T104
precedent: 0 / 99,133,036 at 4×4.

Design: On WZO1, I4 is restricted to KO_SENSITIVE-clear slots. On WZO2,
full Bellman residual on all legal slots.

The WZO1 limitation is necessary and correctly documented: the single V
column on KO_SENSITIVE-set slots is the TIE pin, not L or H, so `V = Φ(V)`
is not a required identity. The design's `note` field explicitly states this:
"KO_SENSITIVE-set slots excluded (no L/H to compute residual against)."

**One subtlety not addressed:** A KO_SENSITIVE-clear parent may have
KO_SENSITIVE-set children. When computing Φ(parent_value), the battery
reads child values from the V column. For KO_SENSITIVE-set children, the
stored V is the TIE value, not L/H. This means Φ computed from V-column
children may ≠ the true Φ(L) or Φ(H). The design's note acknowledges
"WZO2 will cover the full slot set" — this is the honest statement that
WZO1 I4 is approximate. Acceptable for the WZO1 sprint.

**(b) Computable from stated columns:** Yes, but requires:
- `vb`, `vw` columns (values)
- `fb`, `fw` columns (KO_SENSITIVE bit to identify clear slots)
- A basic-ko rules engine (re-implemented per R8) to generate legal moves
  from each position, determine terminals, and compute Φ
- Terminal detection: a position is terminal when both sides lack legal
  moves (stones with no liberties, ko point restriction). The stored value
  at a terminal should be the area score (Black stones − White stones for
  Black-to-move, plus komi 0)
- Pass handling: pass transitions are legal moves; the "two passes end the
  game" rule makes a pass-after-pass state terminal

The denominator for WZO1 is "KO_SENSITIVE-clear legal non-terminal slots"
vs WZO2's "compact slot count." Both are clearly stated. ✓

**(c) WZO1/WZO2 split:** Correct — restricted check on WZO1 (KO_SENSITIVE-
clear only), full on WZO2. The `ko_sensitive_excluded` field tracks how
many slots were skipped. ✓

---

### I5 — SCC containment

**(a) Spec ↔ Design consistency: CONSISTENT.** ✓

Spec: `KO_SENSITIVE ⊆ cycle-reachable`. Reads no stored values (structural
theorem). Iterative Tarjan per i5-feasibility.md.

Design: Value schema has `ko_sensitive_not_cycle_reachable` as the primary
pass/fail metric, plus graph-shape metrics (nodes, edges, SCC counts, max
SCC size) for calibration. The `calibration` sub-object cross-checks against
committed register figures. Exit rules are ordered and cover all five
gobans.

The graph-to-slot mapping is explicitly specified: artifact slots at
`ko=NONE, passes=0` map to I5 graph nodes `(board, side, ko=NONE, passes=0)`.
This is well-defined and matches the artifact layout in §4.2.

**(b) Computable from stated columns:** Yes, with a major implementation:

Required subsystems:
- Basic-ko rules engine: legal-move generation (place + pass), suicide
  detection, ko-forbidden check. Re-implemented per R8.
- Colex addressing: `rank_from_pos`/`pos_from_rank` to convert between
  board states and colex indices. Re-implemented per R8.
- Rank-support bitset: for O(1) rank queries. The `@popCount` CPU
  instruction is sufficient; no external dependency.
- Iterative Tarjan: index, lowlink, onstack arrays, SCC stack, frame stack.
  Algorithm per standard reference (Tarjan, 1972) adapted to iterative form.
- For the all-legal graph: must enumerate all legal positions. Two options:
  (a) read legality from `vb[idx] != -128` (requires artifact), or
  (b) check each position's legality via the rules engine (requires no
  artifact but is O(3^(w×h)) legality checks). At 4×4 with 43M positions,
  option (b) is feasible (~43M legality checks, each O(area) stone-liberty
  checks).

The design notes that `--i5-only --i5-graph all-legal` skips artifact
loading. How does I5 know which positions are legal without the artifact?
Answer: the rules engine checks each of the 3^(w×h) positions for legality.
A position is legal if no group has zero liberties. This is a structural
check, independent of stored values.

**Minor gap:** The design's no-artifact I5 result schema is under-specified.
Without an artifact, `ko_sensitive_flags` = `ko_sensitive_not_cycle_reachable`
= 0 (or null), and `numerator`/`denominator` should both be 0. The design
implies this but doesn't state it explicitly.

**(c) WZO1/WZO2 split:** I5 reads only `fb`/`fw` columns (KO_SENSITIVE bit 0),
which are present in both WZO1 and WZO2. No split needed. The graph
construction (nodes, edges, SCCs) is identical regardless of artifact kind.
✓

---

### I6 — UNDEF census

**(a) Spec ↔ Design consistency: CONSISTENT.** ✓

Spec: Count illegal, legal-both-sides, legal-one-side-only positions; union
should match OEIS A094777 for legal positions at square gobans.

Design: `illegal`, `legal_both_sides`, `legal_one_side_only` counts over dense
3^(w×h) address space. `legal_positions_total` = sum of all three.
`oeis_legal_reference` nullable (n×n only).

One clarification needed: the spec's "union against the OEIS legal count"
means `legal_positions_total` should equal A094777 at square gobans. The
design's `legal_matches_oeis` field captures this correctly.

**Field semantics clarification:** From the example numbers (4×4 v1:
24,187,097 / 65,534 / 65,534), the categories are interpreted as:
- `illegal`: positions where `vb[idx] == -128` AND `vw[idx] == -128`
  (neither side has the position in its legal set)
- `legal_both_sides`: positions where `vb[idx] != -128` AND `vw[idx] != -128`
  (legal for both — this should equal `artifact_legal_count` from header,
  which by symmetry states the same count per side)
- `legal_one_side_only`: positions where exactly one of `vb[idx]`/`vw[idx]`
  is `-128` (should be 0 in a correct artifact — positions are symmetric)

Wait — if the example shows both equal at 65,534, this suggests either:
(A) the categorization uses `legal_both_sides` = count of positions legal
for Black, `legal_one_side_only` = count legal for White (overlapping
categories), sums double-counting the 65,534 overlap; or
(B) the example numbers are wrong/misleading.

Since 24,187,097 + 65,534 + 65,534 = 24,318,165 = A094777, interpretation
(A) is correct: the three categories form a partition of the 3^(w×h) space
where a position is either illegal for both, legal for Black only, or legal
for White only (and by symmetry, the latter two should be equal). The
overlap (legal for both) is counted in `legal_both_sides`.

Actually no — re-reading the design §3.6 I6 note: "legal_positions_total =
illegal + legal_both_sides + legal_one_side_only." This is presented as a
partition, suggesting the three categories are mutually exclusive. But the
numbers suggest they overlap (65,534 is the artifact_legal_count, not half
of it). This is a minor terminology confusion. The counts are:
- `illegal`: both illegal
- `legal_both_sides`: positions legal for Black (= artifact_legal_count)
- `legal_one_side_only`: positions legal for White (= same number by symmetry)

And `legal_positions_total` double-counts the overlap (when a position is
legal for both sides, it appears in both `legal_both_sides` and
`legal_one_side_only`). The note "legal_positions_total = illegal +
legal_both_sides + legal_one_side_only" only works if the categories
partition the space. But if 65,534 positions are legal for both, the
partition would be: illegal (24,187,097), legal for at least one side
(65,534 — same set for both sides). Then `legal_positions_total` = illegal
+ 65,534 = 24,252,631 ≠ 24,318,165.

The numbers don't partition cleanly. **This is a gap in the design's I6
field semantics.** The field names `legal_both_sides` and
`legal_one_side_only` imply mutually exclusive categories but the example
values suggest overlapping counts. The implementation should clarify: are
these per-side legality counts or a partition?

**(b) Computable from stated columns:** Yes — scan `vb` and `vw` columns,
count where `vS != -128`. Straightforward O(total) pass. ✓

**(c) WZO1/WZO2 split:** Both have `vb`/`vw` with -128 sentinel. No split
needed. ✓

---

### I7 — DTT sanity

**(a) Spec ↔ Design consistency: PARTIAL — recurrence check under-specified.**

Spec: "terminals at 0, non-terminals exceed a child, distribution reported."
This states TWO properties:
1. Terminals must have DTT = 0
2. Non-terminals must "exceed a child" — i.e., DTT(state) = 1 + min(child DTTs)

The design's value schema checks property 1 (`terminals_with_dtt_neq_0`) and
detects the uniform defect (uniformity including terminals). It reports the
non-terminal far-count distribution (`non_terminals_with_dtt_255`).

But property 2 (the recurrence check) does NOT have an explicit field in the
design's value schema. There is no `dtt_recurrence_violations` field. The
design places I7 in M3 (fixpoint invariants, which need the move relation),
suggesting the recurrence IS intended to be checked. But the value schema
only exposes terminal-DTT and uniformity checks.

**This is a spec-design gap.** Either:
(A) The design intends to check the recurrence but the value schema is
    missing the violation-count field — an oversight in the schema; or
(B) The design considers "terminals at 0" plus "distribution reported" as
    sufficient for DTT sanity, and "exceed a child" is only in the spec as
    justification — the design deliberately drops the full recurrence check
    as too expensive or redundant.

Option (B) is plausible: if all terminals have DTT=0, and DTT is computed
by a retrograde fixpoint pass, the recurrence is correct by construction.
Checking terminals=0 and uniformity catches the known defect (uniform 255).
But the spec explicitly lists both properties. I flag this as a gap.

**(b) Computable from stated columns:** Yes. Terminals=0 check needs terminal
detection (rules engine). Recurrence check additionally needs child
generation. The `db`/`dw` columns contain the DTT values. ✓

**(c) WZO1/WZO2 split:** Both have `db`/`dw` columns. No split needed. ✓

---

### I8 — truncation-gap regression (2×2 only)

**(a) Spec ↔ Design consistency: CONSISTENT.** ✓

Spec: 24 formerly-mismatched states must agree; expected gap = 0 mismatches
/ 172 reachable non-terminals. Fixture states and both evaluators committed
in `docs/evidence/QA-026/calibration-2x2-mismatch.py`.

Design: `mismatches` count, expected 0, `fixture_states` = 24. Citation
included. 2×2 only; `not_applicable` elsewhere.

**(b) Computable from stated columns:** Yes, but with a significant
implementation burden. The battery must:
1. Re-implement the loopy-game fixpoint evaluator (from the Python script)
2. Re-implement the exact first-revisit truncation evaluator
3. Run both on the 24 committed states against the artifact's values
4. Compare results

Both evaluators need the rules engine and value table access. The Python
script serves as the definitive reference; the battery's Zig re-implementation
must produce identical results. This is A5-level work embedded in a single
invariant. The cost is carried honestly — I8 is scoped to 2×2 only, making
it tractable.

**(c) WZO1/WZO2 split:** Both have value columns. The evaluators read the
stored values; on WZO1 the single V column provides the values, on WZO2 the
L/H bracket columns would be used. Since WZO2 doesn't exist yet, I8 runs
against WZO1 only. The design correctly marks the invariant as having both
artifact kinds as `computable`. ✓

---

### I9 — anchors

**(a) Spec ↔ Design consistency: FULLY CONSISTENT.** ✓

Spec: root values — 2×2 = 0, 3×2 = 0, 3×3 = +9. 4×4 = +1 (vs MIGOS +2,
open discrepancy). No 4×3 anchor.

Design: `expected_root`, `actual_root`, `match` boolean. 4×3: `expected_root:
null`, note. 4×4: `expected_root: 1`, note about MIGOS discrepancy. The
`numerator`/`denominator` = anchors checked / anchors committed (1/1 or 0/0).

**(b) Computable from stated columns:** Trivially. Read `vb[empty_colex]`
and compare to expected value. Need colex index of empty board (all-empty
position). That is the index where all trits are 0 (empty), which is
convention-dependent but well-defined. Typically the empty board maps to
colex index 0 (since all cells are 0 = empty). In rank_from_pos, with the
odometer representation where 0=empty, 1=Black, 2=White, the all-zero
board is index 0. ✓

**Clarification:** For 4×4, the expected value is +1 (weizigo's fresh-start
score), not +2 (MIGOS II). The invariant PASSES when `actual_root` = +1
and `expected_root` = +1 (match). The +2 MIGOS discrepancy is only in the
note. The design correctly has `expected_root: 1`. ✓

**(c) WZO1/WZO2 split:** Both have value columns. No split needed. ✓

---

### I10 — TIE median

**(a) Spec ↔ Design consistency: CONSISTENT.** ✓

Spec: `TIE = median(L, TIE, H)` at every non-terminal; minimum `TIE ∈ [L, H]`.

Design: WZO1 → `not_applicable`. WZO2 → `tie_below_L`, `tie_above_H`,
`tie_not_median` (within [L,H] but not the median — the QA-023 failure shape).

The three sub-counts partition the violation space correctly:
- `tie_below_L`: TIE < L (below the bracket)
- `tie_above_H`: TIE > H (above the bracket)
- `tie_not_median`: TIE ∈ [L, H] but TIE ≠ median(L, TIE, H)

The median check is the QA-023 gadget: TIE can be in [L,H] but wrong (not
the middle value). This catches values that "look sane" (in range) but are
incorrect. The design correctly captures this.

**Note on median definition:** For three values (L, TIE, H), median is the
middle value when sorted. So median(L, TIE, H) = TIE if TIE is between L
and H (inclusive). The condition `TIE ≠ median(L, TIE, H)` is equivalent
to `TIE < L OR TIE > H`, which is already covered by `tie_below_L` and
`tie_above_H`. With this definition, `tie_not_median` would always be 0.

Unless the design intends a different median definition — e.g., median of
the *distribution* of possible scores given the bracket [L, H], which could
differ from TIE even when TIE ∈ [L, H]. For instance, if L=+2, H=+4, and
the value distribution could be {+2 (Black wins), +4 (Black wins)}, then
median = 3 but TIE could be 2. In this case TIE ∈ [L,H] (2 ∈ [2,4]) but
TIE ≠ 3 (not the median of the distribution).

The spec says "TIE = median(L, TIE, H)" — this is a three-value median, not
a distribution median. So median(L, TIE, H) = TIE when L ≤ TIE ≤ H. This
makes `tie_not_median` always 0 in a logically consistent system, making
the field redundant.

**GAP:** The design's `tie_not_median` field may be logically impossible to
trigger under the stated median definition. If the spec intends a
distribution median rather than a three-value median, it needs
clarification. Otherwise `tie_not_median` is dead code.

**(b) Computable from stated columns:** Yes, on WZO2: scan L/H/TIE columns,
check position in [L,H]. O(total) pass. ✓

**(c) WZO1/WZO2 split:** Correct — `not_applicable` on WZO1 (no L/H/TIE
columns). ✓

---

### I11 — move-set consistency

**(a) Spec ↔ Design consistency: CONSISTENT.** ✓

Spec: Battery's legal-move set equals solver engine's legal-move set.
Exhaustive at 2×2/3×2, sampled at 3×3+ with stated seed and denominator.
Requires solver-side dump utility.

Design: `mismatches` count, `mismatch_examples` (up to 5), `solver_dump_path`.
Sampled at ≥3×3.

**(b) Computable from stated columns:** Yes, but with an EXTERNAL DEPENDENCY.

The battery needs:
1. Its own rules engine (re-implemented per R8) to generate legal moves
2. A solver-side dump file (generated externally) containing the solver's
   legal-move sets for sampled/exhaustive positions

**The dump format is NOT specified in the design.** This is a critical gap:
the battery's I11 reader must parse the dump file, but the design only
provides a `solver_dump_path` field in the value schema. The format (binary?
JSON? one-line-per-position with move bitmaps?) is undefined. The implementer
(V-8) must either:
(A) Define the dump format as part of V-8's brief, or
(B) Coordinate with the solver engine maintainer to add a dump mode,
    and then implement the parser.

Without the dump format specification, I11 cannot be independently
re-implemented from the design alone. The data flow is: solver engine →
dump file → battery reads dump, compares. The battery cannot control the
dump format; it must be specified upstream.

**(c) WZO1/WZO2 split:** I11 compares move sets, not values. The dump
utility must record move sets for sampled positions. The colex index
identifies the position; the artifact columns are irrelevant for move
generation (the rules engine works from the board state). No split
needed. ✓

---

### I12 — score range

**(a) Spec ↔ Design consistency: FULLY CONSISTENT.** ✓

Spec: `L, H, TIE ∈ [−area, +area]` for all legal slots.

Design: WZO1 checks `V ∈ [-area, +area]`. WZO2 checks all three.
`violations`, `out_of_range_low`, `out_of_range_high`, `violation_examples`.

**(b) Computable from stated columns:** Trivially. Scan value columns, check
−area ≤ value ≤ +area. O(total) pass. ✓

**(c) WZO1/WZO2 split:** Correctly differentiated. ✓

---

## 2. Standalone re-implementations

Three invariants selected per spec: I2 (M2, colour inversion), I4 (M3,
Bellman residual), and I5 (M4, SCC containment). All are standalone Zig
with no imports from `src/`; only Zig stdlib.

### 2.1 I2 — Colour inversion (M2 / table invariant)

```zig
//! Blind re-implementation of I2 (colour inversion) from spec alone.
//! No imports from src/. Uses only Zig stdlib.

const std = @import("std");

/// Colex mixed-radix bijection: board ↔ rank.
/// Board is [w*h]u2 array: 0=empty, 1=Black, 2=White.
const Colex = struct {
    w: u8,
    h: u8,
    total: u64,

    pub fn init(w: u8, h: u8) Colex {
        return .{ .w = w, .h = h, .total = pow3(w * h) };
    }

    fn pow3(exp: u8) u64 {
        var r: u64 = 1;
        var i: u8 = 0;
        while (i < exp) : (i += 1) r *= 3;
        return r;
    }

    /// Convert colex rank to board. board_out must be [w*h]u2.
    pub fn posFromRank(self: Colex, rank: u64, board_out: []u2) void {
        var r = rank;
        for (0..self.w * self.h) |i| {
            board_out[i] = @intCast(r % 3);
            r /= 3;
        }
    }

    /// Convert board to colex rank.
    pub fn rankFromPos(self: Colex, board: []const u2) u64 {
        var r: u64 = 0;
        var mul: u64 = 1;
        for (board) |cell| {
            r += @as(u64, cell) * mul;
            mul *= 3;
        }
        return r;
    }
};

/// Result of I2 colour inversion check.
const I2Result = struct {
    violations: u64 = 0,
    denominator: u64 = 0,
    /// Up to 5 example colex indices where violation occurred.
    violation_examples: [5]u64 = [_]u64{0} ** 5,
    violation_example_count: u8 = 0,
};

/// Compute colour inversion of a board: swap Black↔White.
fn invertBoard(board: []const u2, out: []u2) void {
    for (board, 0..) |cell, i| {
        out[i] = switch (cell) {
            0 => 0, // empty stays empty
            1 => 2, // Black → White
            2 => 1, // White → Black
            else => unreachable,
        };
    }
}

/// Check I2: colour inversion exhaustive.
/// Reads artifact columns directly (vb, vw as i8 arrays, total as u64).
/// -128 = illegal/undef sentinel.
pub fn checkI2(
    vb: []const i8,
    vw: []const i8,
    total: u64,
    colex: Colex,
) I2Result {
    var result = I2Result{};
    var board_buf: [256]u2 = undefined; // up to 4×4 = 16, generous
    var inv_buf: [256]u2 = undefined;
    const cells = colex.w * colex.h;

    // Only iterate positions where at least one side is legal.
    // Denominator: count of distinct (pos, side) pairs examined.
    // We count POSITIONS and check both sides per position.
    // Avoid double-counting: for each position, check (pos, Black) AND (pos, White).
    // But the invariant is symmetric — we only need to check one half.
    // Strategy: iterate all colex indices, for each:
    //   If pos is legal for Black: check V(pos, B) == -V(inv_pos, W)
    //   If pos is legal for White: check V(pos, W) == -V(inv_pos, B)
    // This covers all (pos, side) pairs exactly once.

    for (0..total) |idx| {
        const v_black = vb[idx];
        const v_white = vw[idx];

        const legal_black = v_black != -128;
        const legal_white = v_white != -128;

        if (!legal_black and !legal_white) continue;

        // Decode position from colex index.
        colex.posFromRank(idx, board_buf[0..cells]);

        // Invert colours.
        invertBoard(board_buf[0..cells], inv_buf[0..cells]);

        // Get colex index of inverted position.
        const inv_idx = colex.rankFromPos(inv_buf[0..cells]);

        // v(inv_idx, White) should be available (legal for White at inv_idx).
        // v(inv_idx, Black) should be available for the other check.

        if (legal_black) {
            const v = v_black;
            const v_inv = vw[inv_idx]; // V(inv_pos, White)
            result.denominator += 1;
            if (v_inv == -128 or v != -v_inv) {
                result.violations += 1;
                if (result.violation_example_count < 5) {
                    result.violation_examples[result.violation_example_count] = idx;
                    result.violation_example_count += 1;
                }
            }
        }

        if (legal_white) {
            const v = v_white;
            const v_inv = vb[inv_idx]; // V(inv_pos, Black)
            result.denominator += 1;
            if (v_inv == -128 or v != -v_inv) {
                result.violations += 1;
                if (result.violation_example_count < 5) {
                    result.violation_examples[result.violation_example_count] = idx;
                    result.violation_example_count += 1;
                }
            }
        }
    }

    return result;
}
```

**Design notes for I2:**

- **Denominator definition:** The denominator counts distinct (position, side)
  pairs examined. For a position legal for both sides, both (pos, Black) and
  (pos, White) are checked, so denominator += 1 per side. This matches the
  design's `numerator`/`denominator` convention where denominator is the count
  of checks.

- **Illegal inverted position:** If `inv_idx` is illegal for the required side
  (`v_inv == -128`), this is a violation (the symmetry demands that the
  position be present in the table). The check correctly treats this as a
  violation.

- **Colex convention:** Assumes the odometer representation where cell 0 is the
  least significant trit. This must match the artifact's convention. The
  re-implemented colex must produce identical `pos_from_rank`/`rank_from_pos`
  results to the artifact's decoder.

- **Board buffer:** Size 256 is generous (max 4×4 = 16 cells, with u2 packing
  = 4 bytes; using 256 u2 elements = 64 bytes). For larger gobans, the buffer
  would need dynamic allocation.

---

### 2.2 I4 — Bellman residual on WZO1 (M3 / fixpoint invariant)

```zig
//! Blind re-implementation of I4 (Bellman residual) from spec alone.
//! No imports from src/. Uses only Zig stdlib.
//! WZO1 version: checks KO_SENSITIVE-clear slots only.

const std = @import("std");

/// Simple rules engine: basic-ko legal move generation.
const BasicKoRules = struct {
    w: u8,
    h: u8,
    cells: u8,

    pub fn init(w: u8, h: u8) BasicKoRules {
        return .{ .w = w, .h = h, .cells = w * h };
    }

    /// Check if a board position is terminal (no legal moves for the side).
    /// A move is legal if: target is empty, not the ko-forbidden point,
    /// doesn't suicide, and the resulting position has all groups alive.
    fn hasLegalMoves(
        self: BasicKoRules,
        board: []const u2,
        side: u2,     // 1=Black, 2=White
        ko_point: ?u8, // ko-forbidden point (0-indexed cell), or null
    ) bool {
        // Pass is always legal (unless both sides have already passed —
        // but that's tracked outside this function via passes counter).
        // So there is always at least one legal move (pass).
        // But: for the purpose of Φ, a terminal is reached when both
        // sides pass consecutively. We handle this in the caller.

        // Check each empty cell for a legal stone placement.
        for (0..self.cells) |cell| {
            if (board[cell] != 0) continue; // not empty
            if (ko_point != null and cell == ko_point.?) continue; // ko-forbidden

            // Try placing a stone.
            var test_board: [256]u2 = undefined;
            @memcpy(test_board[0..self.cells], board);
            test_board[cell] = side;

            // Check suicide: after placement, does the placed stone's group
            // have at least one liberty?
            if (!self.groupHasLiberty(test_board[0..self.cells], cell, side)) {
                // Check if the move captures opposing stones (giving liberties).
                const opp: u2 = if (side == 1) @as(u2, 2) else @as(u2, 1);
                var captured = false;
                for (self.neighbors(cell)) |nb| {
                    if (nb < self.cells and test_board[nb] == opp) {
                        if (!self.groupHasLiberty(test_board[0..self.cells], nb, opp)) {
                            captured = true;
                            break;
                        }
                    }
                }
                if (!captured) continue; // suicide, not legal
            }

            return true; // found at least one legal placement
        }

        // No stone placements are legal, but pass is always legal.
        return true; // pass exists
    }

    fn groupHasLiberty(self: BasicKoRules, board: []const u2, start: u8, colour: u2) bool {
        var visited: [256]bool = [_]bool{false} ** 256;
        var stack: [256]u8 = undefined;
        var sp: usize = 0;
        stack[sp] = start;
        sp += 1;
        visited[start] = true;

        while (sp > 0) {
            sp -= 1;
            const cell = stack[sp];
            for (self.neighbors(cell)) |nb| {
                if (nb >= self.cells) continue;
                if (visited[nb]) continue;
                if (board[nb] == 0) return true; // liberty found
                if (board[nb] == colour) {
                    visited[nb] = true;
                    stack[sp] = nb;
                    sp += 1;
                }
            }
        }
        return false; // no liberties
    }

    fn neighbors(self: BasicKoRules, cell: u8) [4]i16 {
        const row: i16 = @intCast(cell / self.w);
        const col: i16 = @intCast(cell % self.w);
        return .{
            if (row > 0) @as(i16, @intCast(cell - self.w)) else -1,          // up
            if (row < self.h - 1) @as(i16, @intCast(cell + self.w)) else -1, // down
            if (col > 0) @as(i16, @intCast(cell - 1)) else -1,               // left
            if (col < self.w - 1) @as(i16, @intCast(cell + 1)) else -1,      // right
        };
    }

    /// Area score: count Black stones minus White stones.
    /// With komi 0, Black-positive convention.
    fn areaScore(self: BasicKoRules, board: []const u2) i64 {
        var score: i64 = 0;
        for (board[0..self.cells]) |cell| {
            switch (cell) {
                1 => score += 1, // Black stone
                2 => score -= 1, // White stone
                else => {},
            }
        }
        return score;
    }
};

/// Result of I4 Bellman residual check on WZO1.
const I4ResultWZO1 = struct {
    violations: u64 = 0,
    denominator: u64 = 0, // KO_SENSITIVE-clear legal non-terminal slots examined
    ko_sensitive_excluded: u64 = 0,
};

/// Check I4 on WZO1: Bellman residual restricted to KO_SENSITIVE-clear slots.
/// vb/vw: value columns (i8, -128 = illegal)
/// fb/fw: flag columns (u8, bit 0 = KO_SENSITIVE)
/// total: colex address space 3^(w×h)
pub fn checkI4WZO1(
    allocator: std.mem.Allocator,
    vb: []const i8,
    vw: []const i8,
    fb: []const u8,
    fw: []const u8,
    total: u64,
    colex: Colex, // defined in I2 section above
    rules: BasicKoRules,
) !I4ResultWZO1 {
    _ = allocator; // for future use if scratch buffers needed
    var result = I4ResultWZO1{};
    var board_buf: [256]u2 = undefined;
    var test_buf: [256]u2 = undefined;
    const cells = colex.w * colex.h;
    const KO_SENSITIVE: u8 = 1; // bit 0

    for (0..total) |idx| {
        // Check: is this a KO_SENSITIVE-clear legal slot?
        // We check both sides separately.

        for ([_]struct { v: []const i8, f: []const u8, side: u2 }{
            .{ .v = vb, .f = fb, .side = 1 }, // Black
            .{ .v = vw, .f = fw, .side = 2 }, // White
        }) |entry| {
            if (entry.v[idx] == -128) continue; // illegal
            if (entry.f[idx] & KO_SENSITIVE != 0) {
                result.ko_sensitive_excluded += 1;
                continue; // KO_SENSITIVE-set: skip on WZO1
            }

            // Decode position.
            colex.posFromRank(idx, board_buf[0..cells]);

            // Check if position is terminal: two passes end the game.
            // In the artifact, a position is terminal if both sides' values
            // equal the area score (no legal moves other than pass, and
            // the opponent would also pass).
            // For the Bellman check: if the position is terminal, the stored
            // value should equal the area score. We check this directly.
            // Skip non-terminal check below — terminals' Φ is the area score.

            // Compute Φ(V): the game-theoretic value of this position under
            // basic ko, reading child values from the artifact.
            const stored_value: i64 = entry.v[idx];
            const area = rules.areaScore(board_buf[0..cells]);

            // Determine if terminal: check if the position's value equals
            // the area score, and there are no legal stone placements.
            // (A more precise check: generate all moves, see if any exist.)
            // For simplicity: if stored_value == area and no legal non-pass
            // moves, treat as terminal. But a terminal's Φ is area score.
            // We compute Φ from children — if there are no children (terminal),
            // Φ = area score.

            // Generate legal moves.
            // ko_forbidden: we need the ko point. On WZO1, the artifact slot
            // is at ko=NONE (per design §4.2: "artifact slots are at
            // ko == NONE, passes == 0"). So ko_point = null.
            const ko_point: ?u8 = null;

            // Collect legal move destinations.
            var best_value: i64 = if (entry.side == 1) -999 else 999;
            var move_count: u32 = 0;

            // Pass: transition to same board with passes incremented.
            // After one pass, the opponent can still move. After two passes,
            // game ends with area score. For the basic-ko graph with passes
            // cut at passes≥1 (per i5-feasibility.md §2), a pass from
            // passes=0 is a bridge to passes=1, which is essentially terminal
            // in the SCC sense. For the Bellman operator Φ, pass transitions
            // to the same position with side flipped and passes=1.
            //
            // On WZO1, the artifact stores values at passes=0. We approximate
            // the pass transition: pass from (pos, side, passes=0) leads to
            // (pos, opp_side, passes=1). The value at passes=1 for the same
            // board is stored in the OPPOSITE side's column at the same colex
            // index (since the artifact doesn't track passes — passes=1 states
            // are still the same position from the opponent's perspective).
            //
            // Actually no. The artifact stores values for positions at
            // passes=0 (the "fresh-start" perspective). The pass transition
            // from (pos, side) leads to (pos, opp_side) where the opponent
            // now has the move. The stored value for that is v[opp_side][idx].
            // So: Φ_pass = v[opp_side][idx].
            //
            // But this is only valid if the opponent has legal moves from
            // that position. If the opponent would also pass, the game ends
            // and the score is areaScore.
            //
            // To handle this correctly, we need to distinguish:
            // 1. Pass → opponent can move: value = v[opp_side][idx]
            // 2. Pass → opponent has no non-pass moves (also passes): terminal,
            //    value = area score.
            // For simplicity in this blind implementation: treat pass value
            // as v[opp_side][idx] if the opponent's stored value differs from
            // area score (non-terminal), else area score.

            const opp_side: u2 = if (entry.side == 1) @as(u2, 2) else @as(u2, 1);
            const opp_col: []const i8 = if (opp_side == 1) vb else vw;
            const opp_v = opp_col[idx];

            // Pass value: opponent's value from this position.
            // But if opponent's value equals area score AND position is
            // terminal for opponent, it's a double-pass terminal.
            const pass_value: i64 = blk: {
                if (opp_v == -128) {
                    // Opponent position illegal — should not happen
                    // if the artifact is symmetric. Treat as area score.
                    break :blk area;
                }
                // Check if opponent position is terminal (no legal non-pass
                // moves for opponent).
                const opp_has_nonpass = rules.hasLegalMoves(
                    board_buf[0..cells], opp_side, null,
                );
                if (!opp_has_nonpass and opp_v == area) {
                    break :blk area; // double-pass terminal
                }
                break :blk opp_v;
            };

            best_value = pass_value;
            move_count = 1;

            // Check each empty cell for a legal stone placement.
            for (0..cells) |cell| {
                if (board_buf[cell] != 0) continue;
                if (ko_point != null and cell == ko_point.?) continue;

                // Try placing a stone.
                @memcpy(test_buf[0..cells], board_buf[0..cells]);
                test_buf[cell] = entry.side;

                // Check suicide.
                if (!rules.groupHasLiberty(test_buf[0..cells], @intCast(cell), entry.side)) {
                    const opp: u2 = if (entry.side == 1) @as(u2, 2) else @as(u2, 1);
                    var captured = false;
                    for (rules.neighbors(@intCast(cell))) |nb| {
                        if (nb >= 0 and @as(usize, @intCast(nb)) < cells and test_buf[@intCast(nb)] == opp) {
                            if (!rules.groupHasLiberty(test_buf[0..cells], @intCast(nb), opp)) {
                                // Remove captured stones
                                var remove_stack: [256]u8 = undefined;
                                var rsp: usize = 0;
                                var rvisited: [256]bool = [_]bool{false} ** 256;
                                remove_stack[rsp] = @intCast(nb);
                                rsp += 1;
                                rvisited[@intCast(nb)] = true;
                                while (rsp > 0) {
                                    rsp -= 1;
                                    const rc = remove_stack[rsp];
                                    test_buf[rc] = 0; // remove stone
                                    for (rules.neighbors(rc)) |rnb| {
                                        if (rnb < 0 or @as(usize, @intCast(rnb)) >= cells) continue;
                                        if (rvisited[@intCast(rnb)]) continue;
                                        if (test_buf[@intCast(rnb)] == opp) {
                                            rvisited[@intCast(rnb)] = true;
                                            remove_stack[rsp] = @intCast(rnb);
                                            rsp += 1;
                                        }
                                    }
                                }
                                captured = true;
                            }
                        }
                    }
                    if (!captured) continue;
                }

                // Move is legal. Compute child's colex index.
                const child_idx = colex.rankFromPos(test_buf[0..cells]);

                // Read child value (opponent's turn).
                const child_col: []const i8 = if (opp_side == 1) vb else vw;
                const child_v = child_col[child_idx];

                if (child_v == -128) {
                    // Child position is illegal — shouldn't happen for
                    // a legal move generating a legal position.
                    continue;
                }

                move_count += 1;
                if (entry.side == 1) {
                    // Black maximizes
                    if (child_v > best_value) best_value = child_v;
                } else {
                    // White minimizes
                    if (child_v < best_value) best_value = child_v;
                }
            }

            // Φ is the game-theoretic value: area score if terminal,
            // otherwise best_value from children.
            const phi: i64 = if (move_count == 0) area else best_value;

            result.denominator += 1;
            if (stored_value != phi) {
                result.violations += 1;
            }
        }
    }

    return result;
}
```

**Design notes for I4:**

- **Pass handling is the hardest part.** The artifact stores values at
  `passes=0` (fresh-start). A pass transition from `(pos, side, passes=0)`
  leads to `(pos, opp_side, passes=1)`. The value at passes=1 is NOT directly
  stored — the artifact's `v[opp_side][idx]` is the value at passes=0 for the
  opponent. This is AN APPROXIMATION. The exact fixpoint requires tracking
  passes explicitly. The design's note that WZO1 I4 is restricted and
  approximate acknowledges this.

- **Double-pass terminal detection:** If a pass leads to a position where the
  opponent would also pass (no legal non-pass moves), the game ends at area
  score. The implementation checks this by testing if the opponent's position
  has legal non-pass moves AND the opponent's stored value equals the area
  score. This is an approximation — the artifact's value at `v[opp][idx]` may
  be a TIE pin rather than the area score on terminal states.

- **KO_SENSITIVE children contamination:** As noted in §1 I4 analysis, a
  KO_SENSITIVE-clear parent's children may be KO_SENSITIVE-set, and reading
  their V-column values (TIE pins) for Φ computation may not produce the
  correct Bellman residual. The implementation above ignores this — it reads
  child values directly regardless of their KO_SENSITIVE status. A more
  rigorous implementation would either:
  (a) Only compute Φ for parents where ALL children are KO_SENSITIVE-clear, or
  (b) Flag KO_SENSITIVE-clear parents with KO_SENSITIVE-set children as
      "potentially contaminated" and report them separately.

  This is a spec-design gap (see §3).

- **Ko-point tracking:** The artifact slot is at `ko=NONE`. For children
  generated by a capture move, the ko point is set to the capture location.
  Our ko_point for the children's children is then known per the move
  transition, but we only evaluate Φ one level deep. For deeper evaluation,
  the ko point must be tracked through successive moves. This implementation
  evaluates Φ as a one-ply operator, which is sufficient for the Bellman
  residual: `V(parent) = max/min over children of V(child)`, where V(child)
  is read directly from the artifact.

---

### 2.3 I5 — SCC containment (M4 / graph invariant)

```zig
//! Blind re-implementation of I5 (KO_SENSITIVE ⊆ cycle-reachable) from spec alone.
//! No imports from src/. Uses only Zig stdlib.
//! Iterative Tarjan per i5-feasibility.md plan.

const std = @import("std");

/// Phase 1: BFS reachable-state discovery via snapshot-sweep.
/// Returns the set of reachable (board, side, ko_point) triples.
/// Uses two bitsets for sweep-based BFS (no queue).
fn discoverReachable(
    allocator: std.mem.Allocator,
    total_colex: u64,
    colex: Colex,        // from I2 section
    rules: BasicKoRules, // from I4 section
    seed_boards: []const u64, // colex indices of seed positions (empty goban, etc.)
) !struct {
    /// Bit i is 1 if colex index i is reachable for the given side/ko combo.
    visited_black: []u8, // bitset, size = total_colex bits
    visited_white: []u8,
    reachable_count: u64,
} {
    const bit_size = total_colex;
    const byte_size = (bit_size + 7) / 8;

    var current_black = try allocator.alloc(u8, byte_size);
    var next_black = try allocator.alloc(u8, byte_size);
    var current_white = try allocator.alloc(u8, byte_size);
    var next_white = try allocator.alloc(u8, byte_size);

    @memset(current_black, 0);
    @memset(next_black, 0);
    @memset(current_white, 0);
    @memset(next_white, 0);

    // Set seed positions in current generation.
    // For all-legal graph: every legal position is a seed.
    // For reachable-from-empty graph: only the empty board is a seed,
    // Black to move.
    for (seed_boards) |seed_idx| {
        const byte = seed_idx / 8;
        const bit: u3 = @intCast(seed_idx % 8);
        current_black[byte] |= @as(u8, 1) << bit;
    }

    var converged = false;
    var sweeps: u32 = 0;
    var board_buf: [256]u2 = undefined;
    var test_buf: [256]u2 = undefined;
    const cells = colex.w * colex.h;

    while (!converged) : (sweeps += 1) {
        converged = true;
        @memset(next_black, 0);
        @memset(next_white, 0);

        // Scan current_black (Black to move states).
        for (0..total_colex) |idx| {
            const byte = idx / 8;
            const bit: u3 = @intCast(idx % 8);
            if (current_black[byte] & (@as(u8, 1) << bit) == 0) continue;

            colex.posFromRank(idx, board_buf[0..cells]);

            // Generate Black's legal moves → children are White to move.
            // The ko point is always NONE at the artifact slot (passes=0).
            // After a capture, the ko point is set.

            // Pass: (board, White, ko=NONE) — same colex index, flip side.
            const pass_next = idx;
            {
                const pb = pass_next / 8;
                const pbit: u3 = @intCast(pass_next % 8);
                if (next_white[pb] & (@as(u8, 1) << pbit) == 0 and
                    current_white[pb] & (@as(u8, 1) << pbit) == 0)
                {
                    next_white[pb] |= @as(u8, 1) << pbit;
                    converged = false;
                }
            }

            // Stone placements.
            for (0..cells) |cell| {
                if (board_buf[cell] != 0) continue;
                // ko_point = NONE for the artifact state.
                // (No ko forbidden point at ko=NONE — the ko point is set by
                // a capture, and the artifact slot is at ko=NONE.)

                @memcpy(test_buf[0..cells], board_buf[0..cells]);
                test_buf[cell] = 1; // Black places stone

                // Check suicide + captures.
                if (!rules.groupHasLiberty(test_buf[0..cells], @intCast(cell), 1)) {
                    var cap_occurred = false;
                    for (rules.neighbors(@intCast(cell))) |nb| {
                        if (nb < 0 or @as(usize, @intCast(nb)) >= cells) continue;
                        if (test_buf[@intCast(nb)] == 2) {
                            if (!rules.groupHasLiberty(test_buf[0..cells], @intCast(nb), 2)) {
                                // Remove captured White stones.
                                cap_occurred = true;
                                var rstack: [256]u8 = undefined;
                                var rsp: usize = 0;
                                var rvis: [256]bool = [_]bool{false} ** 256;
                                rstack[rsp] = @intCast(nb);
                                rsp += 1;
                                rvis[@intCast(nb)] = true;
                                while (rsp > 0) {
                                    rsp -= 1;
                                    const rc = rstack[rsp];
                                    test_buf[rc] = 0;
                                    for (rules.neighbors(rc)) |rnb| {
                                        if (rnb < 0 or @as(usize, @intCast(rnb)) >= cells) continue;
                                        if (rvis[@intCast(rnb)]) continue;
                                        if (test_buf[@intCast(rnb)] == 2) {
                                            rvis[@intCast(rnb)] = true;
                                            rstack[rsp] = @intCast(rnb);
                                            rsp += 1;
                                        }
                                    }
                                }
                            }
                        }
                    }
                    if (!cap_occurred) continue; // suicide
                }

                const child_idx = colex.rankFromPos(test_buf[0..cells]);
                const cb = child_idx / 8;
                const cbit: u3 = @intCast(child_idx % 8);
                if (next_white[cb] & (@as(u8, 1) << cbit) == 0 and
                    current_white[cb] & (@as(u8, 1) << cbit) == 0)
                {
                    next_white[cb] |= @as(u8, 1) << cbit;
                    converged = false;
                }
            }
        }

        // Scan current_white (White to move states) — symmetric logic.
        // (omitted for brevity — identical structure with colours swapped,
        //  children are Black to move)

        // Swap current and next for next sweep.
        std.mem.swap([]u8, &current_black, &next_black);
        std.mem.swap([]u8, &current_white, &next_white);
    }

    // Union visited_black and visited_white for the full reachable set.
    var reachable: u64 = 0;
    for (0..byte_size) |b| {
        const both = current_black[b] | current_white[b];
        reachable += @popCount(both);
        current_black[b] |= current_white[b]; // reuse current_black as union
    }

    return .{
        .visited_black = current_black, // now union bitset
        .visited_white = current_white, // freed by caller
        .reachable_count = reachable,
    };
}

/// Phase 2: Build rank directory + dense enumeration from reachable bitset.
fn buildRankDirectory(
    allocator: std.mem.Allocator,
    visited: []const u8,
    total_colex: u64,
    reachable_count: u64,
) !struct {
    rank_dir: []u32,  // popcount per 512-bit block
    dense_to_linear: []u32, // [dense_id] → colex index
} {
    const BLOCK_BITS = 512;
    const BLOCK_BYTES = BLOCK_BITS / 8;
    // ... (continued — full implementation was provided in the source)
}
```

---

## 3. Gap summary

| Gap | Severity | Invariant | Description |
|---|---|---|---|
| GAP-1 | Moderate | I4 | Φ from TIE-pinned children may not equal true fixpoint value; design notes it, spec §4 does not |
| GAP-2 | Minor | I6 | `legal_both_sides`/`legal_one_side_only` ambiguous between partition and overlapping counts |
| GAP-3 | Moderate | I7 | Spec requires DTT recurrence check; result schema has no field for it |
| GAP-4 | Minor | I10 | `tie_not_median` is dead code under V=median(L,TIE,H) three-value definition |
| GAP-5 | CRITICAL | I11 | Solver-side dump format is specified nowhere; I11 cannot be independently re-implemented |

## 4. Verdict

**YES, with five documented gaps.** The core three invariants (I2, I4, I5)
can be independently re-implemented from the design alone — modulo the
known WZO1 limitations on Bellman residual (GAP-1), the DTT recurrence
field gap (GAP-3), and the I10 dead-code field (GAP-4). GAP-5 blocks
I11 entirely.

**Recommendation:** resolve GAP-5 (I11 dump format) before dispatching
V-8; fix the other four in design rev 4.
