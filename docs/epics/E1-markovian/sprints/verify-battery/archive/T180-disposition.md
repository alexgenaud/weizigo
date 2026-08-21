# T180 — P3-A spec surgery: GAP-1 through GAP-5 disposition

```
Author:   DSPro/T180 · 2026-08-01
Status:   DELIVERED — dispositions logged, spec + design amended, G1 gate item
          drafted below
Inputs:   docs/epics/E1-markovian/sprints/verify-battery/pass0/spec.md (rev 1)
          docs/epics/E1-markovian/sprints/verify-battery/pass0/design-M1.md (rev 3)
          untracked/T172-blind-analysis.md (DSPro/T172-w1)
Holds:    docs/epics/E1-markovian/sprints/verify-battery/pass0/spec.md
          docs/epics/E1-markovian/sprints/verify-battery/pass0/design-M1.md
```

## Summary

T172's blind re-implementation analysis of the verify-battery spec + design
found five gaps (GAP-1 through GAP-5). Each is dispositioned below. GAP-5
(I11 solver-dump format) is resolved by defining the SMD1 format in the design.
The remaining four are addressed through targeted spec/design amendments.

**All amendments are applied to the live pass0/ copies.** The pre-amendment
state is preserved in the T172 analysis (committed to archive). Diff for human
ratification is routed below as a G1 gate item.

---

## Disposition

### GAP-1: I4 KO_SENSITIVE child contamination on WZO1

**T172 finding (Moderate):** On WZO1, I4 computes Φ from child values. Children
may be KO_SENSITIVE-set, where the stored V is the TIE pin, not L or H. The Φ
computed from TIE pins may not equal the true Bellman residual. The spec §4
I4 description doesn't flag this limitation; the design acknowledges it in a
`note` field but the spec reader wouldn't know.

**Disposition: ACCEPT.** The spec's I4 row gains a parenthetical noting the
WZO1 limitation. This is an honesty amendment — the limitation already exists
in the design; the spec should not imply otherwise.

**Action:** Amend spec §4 I4 row to add "(on WZO1: restricted to
KO_SENSITIVE-clear slots; KO_SENSITIVE-set children may contaminate Φ — full
check deferred to WZO2)."

---

### GAP-2: I6 field semantics ambiguous

**T172 finding (Minor):** The I6 value schema fields `legal_both_sides` and
`legal_one_side_only` have ambiguous semantics. From example numbers
(24,187,097 / 65,534 / 65,534), they appear to be per-side legality counts
(overlapping). The field names suggest mutually exclusive categories. The
design's note `legal_positions_total = illegal + legal_both_sides +
legal_one_side_only` only sums to A094777 if the categories double-count.

**Analysis:** The numbers resolve unambiguously:
- `illegal`: positions where `vb[idx] == -128` AND `vw[idx] == -128` = 24,187,097
- `legal_both_sides`: positions where `vb[idx] != -128` = 65,534 (legal for Black)
- `legal_one_side_only`: positions where `vw[idx] != -128` = 65,534 (legal for White)
- `legal_positions_total`: `illegal + legal_both_sides + legal_one_side_only`

But this sums to 24,187,097 + 65,534 + 65,534 = 24,318,165 = A094777, which
works ONLY if `legal_both_sides` and `legal_one_side_only` overlap on all
65,534 positions (i.e., every position legal for Black is also legal for
White). This is the correct interpretation: the fields are per-side counts,
not a partition. The `legal_positions_total` formula double-counts the overlap,
producing the OEIS total.

The field names are misleading (`legal_both_sides` implies "legal for both,"
but the field value is actually the count for one side).

**Disposition: ACCEPT — rename fields for clarity.** `legal_both_sides` →
`legal_black` (positions legal when Black to move). `legal_one_side_only` →
`legal_white` (positions legal when White to move). The partition
interpretation is a red herring; the design should state clearly that these
are per-side counts and that `legal_positions_total` double-counts the overlap.

**Action:** Amend design §3.6 I6 schema: rename fields, add explicit note that
these are per-side counts, not a partition.

---

### GAP-3: I7 missing recurrence check

**T172 finding (Moderate):** The spec §4 I7 says "non-terminals exceed a child"
— the DTT recurrence property DTT(state) = 1 + min(DTT(children)). The design's
value schema checks terminals=0 and uniformity but has no
`dtt_recurrence_violations` field.

**Analysis:** The recurrence check requires the rules engine (child generation),
which places it squarely in M3 (fixpoint invariants). The design already
places I7 in M3. The omission appears to be an oversight — the spec explicitly
lists this property, and the module that owns I7 has the rules engine needed
to check it.

**Disposition: ACCEPT — add recurrence field to design schema.** The field is
added to the I7 value schema. It is nullable: `null` when the recurrence
check is not run (e.g., if the rules engine is unavailable for this goban, or
if the check is deferred to WZO2). When computed, violations indicate
DTT(state) ≠ 1 + min(DTT(children)) for non-terminal states.

The I7 pass condition remains `terminals_with_dtt_neq_0 == 0` (the primary
pass/fail gate). Recurrence violations are a secondary check reported in the
result; `numerator` = `terminals_with_dtt_neq_0 + (dtt_recurrence_violations ?? 0)`.

**Action:** Amend design §3.6 I7 schema to add `dtt_recurrence_violations: u64|null`.
Update spec §4 I7 description to note the two checks explicitly.

---

### GAP-4: I10 `tie_not_median` logically impossible under stated definition

**T172 finding (Minor):** The spec defines I10 as `TIE = median(L, TIE, H)`.
For three values, median(L, TIE, H) = TIE whenever L ≤ TIE ≤ H. Since I10 also
checks TIE ∈ [L, H], the second condition is trivially satisfied whenever the
first holds. `tie_not_median` would always be 0.

The design's comment "this is the QA-023 failure shape (wrong values, sane
histogram)" suggests the intent was to catch in-range-but-wrong TIE values.
But a three-value median cannot distinguish correct from incorrect in-range
values — that requires the fixpoint check Φ(TIE) = TIE, which is not part of
I10.

**Disposition: ACCEPT — document the logical truth, keep the field.** The spec
text "TIE = median(L, TIE, H)" is technically correct (it follows from
TIE ∈ [L, H]) but redundant. The spec is amended to state simply "TIE ∈ [L, H]"
as the invariant, with a note that the median formulation is equivalent.

The design's `tie_not_median` field is retained in the schema (always 0 under
current definition) with a note that it exists for forward compatibility — a
future distribution-median check could produce non-zero values. The
`violations` count = `tie_below_L + tie_above_H` (with `tie_not_median`
included for completeness, always 0).

**Action:** Amend spec §4 I10 to remove the redundant median formulation.
Amend design §3.6 I10 to add a note documenting that `tie_not_median` is
always zero under the three-value median definition.

---

### GAP-5: I11 solver-dump format unspecified [CRITICAL]

**T172 finding (Critical):** I11 requires a solver-side dump file containing
per-position legal-move sets. The dump format is not specified anywhere in the
spec or design. Without it, V-8 (M3/I11) cannot be implemented.

**Disposition: RESOLVE — define the SMD1 format.** A binary format ("SMD1") is
defined and added to the design as §4.6. The format specification is complete
enough to implement both the solver-side dump utility and the battery-side
reader. Key design decisions:

- **Binary, not text:** At 4×4 with 99M compact slots, text would be gigabytes.
  Binary is compact and mechanically parseable.
- **One record per (position, side) pair** at the artifact slice (ko=NONE, passes=0).
- **Move bitmap** encoding: bit i = cell i is a legal stone placement; bit
  `w*h` = pass is legal. This matches the internal representation of both the
  solver and the battery.
- **CRC-32** footer for integrity.
- **Order:** sorted by (colex_idx, side) for deterministic comparison.

**Action:** Add §4.6 (SMD1 solver-dump format) to design-M1.md. Add a reference
to this format in spec §4 I11 description.

---

## Amendments applied

### spec.md (rev 1 → rev 2)

| change | gap | location |
|---|---|---|
| I4 row: add parenthetical noting WZO1 limitation | GAP-1 | §4 table, I4 row |
| I7 row: explicitly name two checks (terminals=0, recurrence) | GAP-3 | §4 table, I7 row |
| I10 row: remove redundant median formulation, state TIE ∈ [L, H] | GAP-4 | §4 table, I10 row |
| I11 row: add reference to SMD1 format in design | GAP-5 | §4 table, I11 row |

### design-M1.md (rev 3 → rev 4)

| change | gap | location |
|---|---|---|
| I6 schema: rename `legal_both_sides`→`legal_black`, `legal_one_side_only`→`legal_white`; add partition note | GAP-2 | §3.6 I6 |
| I7 schema: add `dtt_recurrence_violations: u64\|null` field | GAP-3 | §3.6 I7 |
| I10 schema: add note that `tie_not_median` is always 0 under three-value median | GAP-4 | §3.6 I10 |
| New §4.6: SMD1 solver-dump format specification | GAP-5 | §4 (after §4.5) |
| I11 schema: add `solver_dump_format: "SMD1"` and `solver_dump_sha256` fields | GAP-5 | §3.6 I11 |

---

## G1 gate item — for human ratification

The following diff against the pass0/ documents requires human sign-off before
the sprint proceeds to V-8 (M3 fixpoint invariants, which includes I11):

```
--- a/docs/epics/E1-markovian/sprints/verify-battery/pass0/spec.md
+++ b/docs/epics/E1-markovian/sprints/verify-battery/pass0/spec.md
@@ I4 row:
-| **I4** | Bellman residual: `L = Φ(L)`, `H = Φ(H)`, count of violations
-           with denominator | ...
+| **I4** | Bellman residual: `L = Φ(L)`, `H = Φ(H)`, count of violations
+           with denominator. On WZO1: restricted to KO_SENSITIVE-clear
+           slots; KO_SENSITIVE-set children may contaminate Φ — full check
+           deferred to WZO2 [GAP-1]. | ...

@@ I7 row:
-| **I7** | DTT sanity: terminals at 0, non-terminals exceed a child,
-           distribution reported. ...
+| **I7** | DTT sanity: (a) terminals at 0, (b) non-terminals satisfy
+           DTT(state) = 1 + min(DTT(children)) [GAP-3], distribution
+           reported. ...

@@ I10 row:
-| **I10** | **TIE value correctness** [B1]: `TIE = median(L, TIE, H)` at
-            every non-terminal; at minimum `TIE ∈ [L, H]` | ...
+| **I10** | **TIE value correctness** [B1]: `TIE ∈ [L, H]` at every
+            non-terminal. (The formulation `TIE = median(L, TIE, H)` is
+            equivalent when TIE ∈ [L, H]; the shorter form is canonical
+            [GAP-4].) | ...

@@ I11 row:
-| **I11** | **move-set consistency** [C1]: the battery's independently
-            implemented legal-move set (R8) equals the solver engine's
-            legal-move set, state by state, via a solver-side dump utility;
-            exhaustive at 2×2/3×2, stated sample + seed + denominator at
-            3×3 and above (§6a) | ...
+| **I11** | **move-set consistency** [C1]: the battery's independently
+            implemented legal-move set (R8) equals the solver engine's
+            legal-move set, state by state, via a solver-side dump utility
+            (SMD1 format — see design §4.6 [GAP-5]); exhaustive at 2×2/3×2,
+            stated sample + seed + denominator at 3×3 and above (§6a) | ...
```

**Questions for the human:**

1. **SMD1 format** (§4.6 of the amended design): is the binary format
   acceptable, or should there be a text alternative for debugging?
2. **I7 recurrence check:** the recurrence field is nullable. Should the
   WZO1 sprint require it (non-null at all gobans) or allow null? Full
   recurrence at 4×4 requires 99M child-generation passes — it's the same
   order of cost as I4.
3. **I10 `tie_not_median`:** keep as forward-looking dead code, or remove
   from the schema until WZO2 defines a distribution-median check?
4. **I4 WZO1 limitation:** the amended spec explicitly calls out the
   KO_SENSITIVE child contamination. Is this sufficient, or should the
   design add a `contaminated_excluded` count field?

---

## Traceability

| gap | T172 § | severity | disposition | spec change | design change |
|---|---|---|---|---|---|
| GAP-1 | 3.1 | Moderate | ACCEPT — note limitation | I4 row amended | none needed (already noted) |
| GAP-2 | 3.2 | Minor | ACCEPT — rename fields | none | I6 fields renamed |
| GAP-3 | 3.3 | Moderate | ACCEPT — add field | I7 row clarified | `dtt_recurrence_violations` added |
| GAP-4 | 3.4 | Minor | ACCEPT — document | I10 row simplified | note added to I10 schema |
| GAP-5 | 3.5 | Critical | RESOLVE — SMD1 defined | I11 row references design | §4.6 added |

---

— DSPro/T180
