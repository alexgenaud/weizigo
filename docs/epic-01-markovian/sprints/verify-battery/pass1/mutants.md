# Mutation Catalogue — Phase 1 verify-battery

```
Task: T291 · Role: worker · Model: deepseek-v4-pro · Date: 2026-08-03
Status: DELIVERED — kill matrix with gaps, fixtures wired into zig build test
Parent: pass1/spec.md (T290) · Brief: untracked/T291-mutation-catalogue.md
Prior art: DeMillo, Lipton & Sayward (1978); Jia & Harman (2011)
```

## 1. Method

This is **mutation testing**. Each historical defect becomes a **synthetic mutant**
— a minimal, reversible corruption of a compliant artifact. A check **kills** the
mutant if it reports `fail` when fed the corrupted artifact and `pass` when fed
the clean original. A mutant that **survives** (no check fails it) means the
battery has a blind spot.

Mutants are synthetic (constructed in memory, never written to `data/` or
`artifacts/`) precisely so they outlive the repair of the live fault — the
argument from Amendment 1 and `DELEGATEE.md` §Principles.

Per T290's spec §2, three critical gaps (G1, G2, G3) have **no battery coverage**.
Mutants targeting those gaps will survive — and that is the expected, honest
result. A catalogue where every mutant dies is the result to distrust.

## 2. The mutants

| # | historical defect | claim ID / source | the mutation |
|---|---|---|---|
| M1 | colex vs combinatorial rank | T178 | Key built with the wrong index function on one side. One column's values are at combinatorial-rank indices instead of colex indices. |
| M2 | passes=1 rows encoded as passes=0 | T193 | The passes bit dropped in the key byte — passes=1 entries land at passes=0 indices. N/A on WZO1 (no passes dimension); the defect is in WZO2 encoding. |
| M3 | ko set on any single capture | T265, `CODE.GTP-KOKEY` | KO_SENSITIVE flag set without the `liberties==1 && friendly==0` test. The artifact tags states as ko-sensitive when they are not in any ko cycle. |
| M4 | second unfixed ko copy in the acceptance harness | `CODE.ACCEPT-KOKEY` | The pre-T265 ko rule (any single-stone capture → ko) restored in one consumer, while the other uses the corrected rule. Both consumers produce different keys for the same state. |
| M5 | bracket queried with the wrong side after a move | `CODE.GTP-LHSIDE` (T283) | Side not advanced before the lookup — the table is queried on Black's turn with White's values. The stored values have the wrong sign for their side. |
| M6 | DTT column never computed | `CODE.WZO1-DTT-UNSET` | DTT column overwritten with the initialiser (255 = DTT_FAR). Terminals show DTT=255 instead of DTT=0. |
| M7 | colour inversion violated on ~48% of positions | `4x4.V1-INVSYM-BROKEN` (T260) | Sign flipped on one side of the inversion: `V(-pos,-side) != -V(pos,side)`. |
| M8 | entries missing for one side | T261-as-described | A legitimate `passes=1` side-entry deleted — a reachable state has one side present and the other absent. (The ~6.77M incompleteness claim was refuted by T266/T277/T279; the mutant seeds the fault the defect was *mistaken for*.) |
| M9 | a check that returns `skipped` and reads as pass | `CODE.BATTERY-STUBBED` | One invariant stubbed to `skipped` status; the suite reports green because no meta-check verifies that every invariant returned a real verdict. |
| M10 | a control that compares a function with an alias of itself | GRAND-AUDIT §1a (T265's test) | The "independent" side replaced by an alias — two "implementations" are the same function registered twice, producing perfect agreement vacuously. |

## 3. Kill matrix

Each mutant fed through the battery. A `killed` verdict names the invariant that
fails. A `survived` verdict names the gap. **Kill-verification is the existence
of a red-then-green test asserting the killer (in `src/vb_mutants.zig` or
`src/differential.zig`); a passing killer reading on the live artifact alone is
calibration, not kill-verification.**

| mutant | I1 | I2 | I3 | I4 | I5 | I6 | I7 | I8 | I9 | I10 | I11 | I12 | verdict | gap |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **M1** T178 colex | — | — | n/a | — | — | — | — | n/a | — | n/a | — | — | **SURVIVED** | G1/G3¹ |
| **M2** T193 passes bit | — | — | n/a | — | — | — | — | n/a | — | n/a | — | — | **SURVIVED** | G1/G3¹ |
| **M3** T265 ko-too-broad | — | — | n/a | — | may³ | — | — | n/a | — | n/a | — | — | **SURVIVED** | G1/G3 |
| **M4** ACCEPT-KOKEY | — | — | n/a | — | — | — | — | n/a | — | n/a | — | — | **SURVIVED** | G1/G3¹ |
| **M5** GTP-LHSIDE | — | **✗** | n/a | — | — | — | — | n/a | — | n/a | — | — | **KILLED** | — |
| **M6** DTT-UNSET | — | — | n/a | — | — | — | **✗** | n/a | — | n/a | — | — | **KILLED** | — |
| **M7** INVSYM-BROKEN | — | **✗** | n/a | — | — | — | — | n/a | — | n/a | — | — | **KILLED** | — |
| **M8** T261 deleted-entry | — | — | n/a | — | — | — | — | n/a | — | n/a | — | — | **KILLED** (T363) | G2⁴ |
| **M9** BATTERY-STUBBED | — | — | — | — | — | — | — | — | — | — | — | — | **KILLED** | meta³ |
| **M10** alias-control | — | — | — | — | — | — | — | — | — | — | — | — | **KILLED** (T363) | —⁵ |

**Key:** `✗` = killed (invariant reports fail, test assertion verified) · `—` = not applicable (invariant doesn't test that property) · `n/a` = not applicable on WZO1 · `may³` = could catch in principle but the synthetic fixture does not trigger a kill (survival verified by test assertion) · `meta³` = killed by the BATT-HEALTH meta-check (`src/vb_health.zig`, T347), which enumerates every declared invariant by compile-time reflection over `vb.Invariant` and fails iff any returns `.skipped` · `¹` = T345 KEY-4x4 calibration in `src/differential.zig:1554` flips bit 0 of producer colex and asserts the key-agreement invariant catches it (proves the machinery is sensitive), but no per-mutant kill-verification fixture for M1/M2/M4 exists; the intended killer is the T345 KEY-4x4 exhaustive run, which has been wired but does not yet have the per-mutant red-then-green test. · `⁴` = M8 fixture lives at `src/vb_mutants.zig:269` (3×3 WZO2, deletes one entry from `data/oracle-3x3-v2.wzo2`); C-A1 `children_not_in_table` 0→2, C-A2 `reachable_not_in_table` 0→1, restore → 0/0. · `⁵` = M10 fixture at `src/vb_mutants.zig:319` exercises the I11 null control (kernel-vs-SMD1, both kernel) → 0/114 vacuous, AND the seeded-defect control (allows-suicide mutant) → 1/114, together proving the harness is sensitive to genuine disagreement; the meta² gap (no battery-integrated independent-reimplementation check) was the original framing and is now superseded — the I11 null + seeded-defect pair is wired into the battery.

**Kill rate: 6 / 10 (denominator: 10 mutants).** Six mutants are killed by existing/new battery checks; the remaining 4 survive.

Of the 10 mutants:
- **6 killed** by battery checks: M5 (I2 colour inversion), M6 (I7 DTT sanity), M7 (I2 colour inversion), M8 (C-A1/C-A2 closure, T363), M9 (BATT-HEALTH meta-check, T347), M10 (I11 null + seeded-defect, T363)
- **3 survive** due to **G1/G3** (Z-R-STATE / Z-STATE-KEY — key agreement, partial coverage by T345 KEY-4x4 calibration, no per-mutant kill-verification): M1, M2, M4
- **1 survives** due to **G1/G3** (I5 vacuity at 2×2 — every passes=0 slot is cycle-reachable; the proper killer is T267/T345 key-agreement which requires the Phase 2 kernel producer encoder): M3

**Reconciliation (T475, 2026-08-19).** T363's note (`findings/T363-g3b-completion.json`) claimed
"SEVEN OF SEVEN mutants now asserted killed (M1-M4 KEY-4x4, M8 CLOSURE, M9 BATT-HEALTH, M10 I11-null)".
The run evidence at `zig build test` (T475, 2026-08-19) shows this was an overstatement: **only 6
mutants have kill-verified tests** (M5-M10 except M3); M3 still SURVIVES (`src/vb_mutants.zig:94`,
explicit comment "M3 survives", test asserts `I5Status.pass`); M1, M2, M4 have no per-mutant
kill-verification fixture — T345 KEY-4x4 calibration proves the machinery is sensitive to colex
bit-flip, but exhaustive key-agreement has not been red-then-green tested against the M1/M2/M4
fixtures specifically. The honest kill rate is **6/10**, not 7/10 or 4/10 (the pre-T347 figure).
The matrix above is the corrected record.

M3 merits explanation. It has a *conceivable* killer in the current
battery (I5 SCC containment), but the synthetic fixture does not trigger
a kill: on the 2×2 all-legal graph, every legal state at passes=0 is
cycle-reachable. The proper killer is the T267 key-agreement invariant
(G1/G3), which does not exist yet. The test assertion for M3
expects `.pass` (survival), marked `[EXPECTED-GAP G1/G3]`. **When the Phase 2
kernel lands and key-agreement is runnable, invert this assertion** to
expect `.fail` — the fixture corruption is correct; only the check is
absent.

M5 is killed by I2 (column-wide vw negation triggers a colour-inversion
violation). This is a valid kill — I2 catches this specific sign-antisymmetry
break — but note that the T267 key-agreement check (G1/G3) would be the
comprehensive, reliable killer for all wrong-side manifestations, not just
those that happen to break sign symmetry.

## 4. Kill-verified mutants — fixture descriptions

### M5 (T283: wrong side after move) — KILLED by I2

**Fixturing:** The vw column is negated bytewise (`0 -% byte`). Column-wide
negation breaks the colour-inversion identity: the check `vb[i] == -vw[inv(i)]`
becomes `vb[i] == -(-original_vw) = original_vw`, which fails for every
non-zero-valued legal slot. I2 reports `violations > 0` → status `.fail`.

**Killer:** I2 (colour inversion, `vb_table.zig` `checkI2`).
**Test:** `src/vb_mutants.zig` `"M5-T283 wrong-side killed by I2"`.
**Caveat:** I2 catches this specific sign-antisymmetry corruption. The T267
key-agreement check (G1/G3) would be the comprehensive killer for all
wrong-side manifestations.

### M6 (DTT unset) — KILLED by I7

**Fixturing:** A synthetic 2×2 WZO1 artifact is constructed with the db
and dw columns set to 255 (DTT_FAR) on every slot. I7 checks: every terminal
must have DTT=0. Terminals with DTT=255 are flagged:
`terminals_with_dtt_neq_0 > 0` → status `.fail`.

**Killer:** I7 (DTT sanity, `vb_fixpoint.zig` `checkI7`).
**Test:** `src/vb_mutants.zig` `"M6-DTT-unset killed by I7"`.

### M7 (T260: colour inversion broken) — KILLED by I2

**Fixturing:** A synthetic 2×2 WZO1 artifact is constructed from a known-good
2×2 artifact. The vb column is left intact; the vw column is replaced with
a copy of the vb column (no negation). I2 checks `vb[idx] == -vw[invertIdx(idx)]`
— with vw = vb, this becomes `x == -x` which is false for all non-zero values.
Every legal slot with a non-zero value produces a violation.

**Killer:** I2 (colour inversion, `vb_table.zig` `checkI2`).
**Test:** `src/vb_mutants.zig` `"M7-T260 inversion-broken killed by I2"`.

## 4a. Survival-verified mutant — fixture description

This mutant has a synthetic fixture and test assertion, but the assertion
expects `.pass` (survival) because the battery has no check that kills it.
It is tied to its gap ID and marked `[EXPECTED-GAP]`. The assertion inverts
when Phase 2 closes the gap.

### M3 (T265: ko set too broadly) — SURVIVES (gap G1/G3)

**Fixturing:** The fb column is corrupted at colex index 40
([B,B,B,empty], Black side) — a position with no legal placement moves.
KO_SENSITIVE is spuriously set. I5 maps this to (colex=40, side=0, ko=NONE,
passes=0) and checks cycle-reachability. On the 2×2 all-legal graph, every
legal state at passes=0 is cycle-reachable (pass transitions alone guarantee
it), so I5 reports `ko_not_cr=0` → status `.pass`. The proper killer is
key-agreement (T267, G1/G3).

**Test:** `src/vb_mutants.zig` `"M3-T265 ko-too-broad SURVIVES (gap G1/G3)"`.
**Invert to `.fail` when:** Phase 2 kernel lands and key-agreement is runnable.
**Test:** `src/vb_mutants.zig` `"M7-T260 inversion-broken killed by I2"`.

## 5. Survived mutants — gap assignments

### Gap G1/G3 — Z-R-STATE / Z-STATE-KEY (key agreement)

**Affected mutants:** M1 (T178), M2 (T193), M4 (ACCEPT-KOKEY)

The battery has no check that the producer's state encoding matches the
consumer's. T267's key-agreement invariant — "run both encoders on the same
state space, count mismatches" — requires both the producer encoder (solver
kernel) and the consumer encoder (battery's own), per T290 spec §5. The
consumer encoder exists (R8: battery re-implements everything); the producer
encoder is in `src/exp6_solve.zig` and has not been extracted into the kernel.
**Runnable after Phase 2.**

M1 note: I2 *may* incidentally catch a colex-vs-combinatorial-rank scramble
if the index mismatch produces enough inversion violations. But this is
coincidental — the intended killer is key-agreement, and relying on I2 to
catch an encoding defect is not a calibrated check. Recorded as SURVIVED.

M2 note: WZO1 has no passes dimension, so the passes-bit defect cannot be
fixtured on the artifacts the battery currently reads. On WZO2, T267's
key-agreement check is the intended killer.

### Gap G2 — Z-STATE-REACH (closure C-A1/C-A2)

**Affected mutant:** ~~M8 (T261 deleted-entry)~~ — **CLOSED 2026-08-05 (T363)** by the C-A1/C-A2
closure checks (`src/vb_closure.zig` `ca1ForwardClosure` / `ca2BackwardClosure`). The 3×3 WZO2
fixture deletes one entry from `data/oracle-3x3-v2.wzo2`; forward closure finds
`children_not_in_table` 0→2, backward closure finds `reachable_not_in_table` 0→1, restore → 0/0.
Kill verified red-then-green in `src/vb_mutants.zig` `"M8-T261 deleted-entry killed by C-A1/C-A2
closure (red, then green)"`. **Gap G2 is closed at 3×3 WZO2 and 4×4 WZO2 (T363, gated
`WEIZIGO_CLOSURE_4X4_FULL=1` run); per the T383 corrected-decode re-run, 4×4 C-A1 = 0 / 616,030,190
children and C-A2 = 0 / 99,133,034 reachable, 32 sweeps (`findings/T383-ko-decode.json:48`).**

### Meta-gap — no battery-health check

**Affected mutants:** ~~M10 (alias-control)~~ — **CLOSED 2026-08-05 (T363)** by the I11 null
control + seeded-defect (`src/vb_i11.zig` `compareSmd1Null` + `compareDefective`). Kernel-vs-SMD1
(both kernel) reports 0/114 mismatches vacuously; the allows-suicide mutant reports 1/114,
together proving the comparison machinery is sensitive to genuine disagreement (not a tautology).
Kill verified red-then-green in `src/vb_mutants.zig` `"M10-ALIAS-CONTROL killed by I11 null control
(vacuous 0) + seeded-defect (> 0)"`. M9 (BATTERY-STUBBED) was **closed** on 2026-08-04 by the
BATT-HEALTH meta-check (`src/vb_health.zig`, T347).

M9 (CLOSED 2026-08-04, T347): The battery now has a meta-check that verifies
every invariant returns a real verdict (not `.skipped`). `src/vb_health.zig`
enumerates the declared invariants by compile-time reflection over
`vb.Invariant`, runs each via a comptime-complete runner registry (a new
`Invariant` variant without a registered runner is a *compile error*, so the
check cannot rot), and fails iff any returns `.skipped`. Kill verified
red-then-green in `src/vb_mutants.zig`. See the amendment log.

M10 (CLOSED 2026-08-05, T363): The I11 differential check (`src/vb_i11.zig`) is now the battery's
differential-comparison machinery, with the null control (kernel-vs-alias-of-kernel → 0 vacuously)
and the seeded-defect control (allows-suicide mutant → 1) wired into `zig build test`. The
"alias-of-self" pattern is no longer a battery-integrated meta-gap; the kill-verified test
establishes that the comparison infrastructure can both ignore an alias (vacuous 0) and detect a
real divergence (> 0).

**Gap G1/G3 — Z-R-STATE / Z-STATE-KEY (key agreement)** is the only remaining open gap, covering
M1/M2/M3/M4. T345 KEY-4x4 calibration in `src/differential.zig:1554` demonstrates the key-agreement
machinery is sensitive to colex bit-flip (mutant → mismatch detected), and T345 KEY-4x4 exhaustive
runs the producer/consumer comparison over all 99,133,036 4×4 entries (`src/differential.zig:1360`).
Per-mutant kill-verification fixtures for M1, M2, M4 do not yet exist; the M3 test
(`src/vb_mutants.zig:94`) explicitly asserts SURVIVAL on 2×2 (vacuous at that size: every passes=0
slot is cycle-reachable). Closing G1/G3 is the Phase 2 kernel producer-extraction deliverable.

## 6. Fixtures and kill-verification

Kill-verification tests live in `src/vb_mutants.zig` and are wired into
`zig build test` via `build.zig`. Each test:

1. Constructs a synthetic WZO1 artifact in memory (zero disk I/O, fully reversible)
2. Feeds it to the named invariant check
3. Asserts the check returns `.fail`
4. Prints an `EXPECTED` marker in its output

**No writes to `data/` or `artifacts/`.** Every mutant is constructed from
a clean artifact loaded into memory and corrupted in place.

## 7. What this catalogue does not cover

- **Mutants for I4 (Bellman), I8 (truncation-gap), I9 (anchors), I1 (pin census):**
  Not in the historical-defect catalogue. A complete mutation-testing suite
  would seed one mutant per invariant; this catalogue seeds one mutant per
  *historical defect*. The per-invariant mutants are specified in T290's A1
  acceptance criteria and belong to T292 (implementation).
- **Per-invariant synthetic mutants (A1a–A1l):** Those are T292's deliverable,
  not T291's. This catalogue is the historical-defect → gap mapping.
- **WZO2 mutants:** The battery currently reads only WZO1. Mutants that require
  the passes dimension (M2) or the bracket columns (I3, I10) are not fixturable
  until the battery supports WZO2.

## 8. Amendment log

| date | amendment | by |
|---|---|---|
| 2026-08-03 | Initial catalogue — T291 | deepseek-v4-pro/T291 |
| 2026-08-04 | M9 (BATTERY-STUBBED) inverted SURVIVED → **KILLED** by the BATT-HEALTH meta-check (`src/vb_health.zig`, T347). The check enumerates every declared invariant by compile-time reflection over `vb.Invariant`, runs each via a comptime-complete runner registry, and fails iff any returns `.skipped`. Kill verified red-then-green in `src/vb_mutants.zig` `"M9-BATTERY-STUBBED killed by BATT-HEALTH (red, then green)"`. Kill rate 3/10 → 4/10. M10 remains SURVIVED (meta-gap: independent-reimplementation check not yet integrated). | minimax-m3/T347 |
| 2026-08-05 | M8 (T261 deleted-entry) inverted SURVIVED → **KILLED** by the C-A1/C-A2 closure checks (`src/vb_closure.zig`, T342). Fixture deletes one entry from the 3×3 WZO2 artifact (`data/oracle-3x3-v2.wzo2`); forward closure finds `children_not_in_table` 0→2, backward closure finds `reachable_not_in_table` 0→1, restore → 0/0. M10 (alias-control) inverted SURVIVED → **KILLED** by the I11 null control + seeded-defect (`src/vb_i11.zig`, T346): kernel-vs-SMD1 (both kernel) → 0/114 vacuously, allows-suicide mutant → 1/114, together proving the comparison machinery is sensitive to genuine disagreement. Kill rate 4/10 → 6/10. (T363's note claimed "seven of seven"; run evidence at T475 showed that was an overstatement — M3 still SURVIVES in code, and M1/M2/M4 have no per-mutant kill-verification tests.) | deepseek-v4-flash/T363 |
| 2026-08-19 | T475 reconciliation: corrected the kill matrix to **6 / 10** (not the 4/10 originally recorded nor the 7/10 claimed by T363); added the T363 M8/M10 inversions and the kernel-successor C-A1/C-A2 corrected denominators (T383); flagged D8 (flagged 2026-08-06, unreconciled until now). The matrix is now the durable record; per-mutant M1/M2/M3/M4 kill-verification fixtures remain the gap G1/G3 debt. | kimi-k2.7/T475 |
