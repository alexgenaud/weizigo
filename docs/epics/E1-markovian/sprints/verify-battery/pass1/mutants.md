# Mutation Catalogue — Waypoint 1 verify-battery

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
| **M1** T178 colex | — | — | n/a | — | — | — | — | n/a | — | n/a | — | — | **KILLED** (T530) | key-agreement¹ |
| **M2** T193 passes bit | — | — | n/a | — | — | — | — | n/a | — | n/a | — | — | **KILLED** (T530) | key-agreement¹ |
| **M3** T265 ko-too-broad | — | — | n/a | — | may³ | — | — | n/a | — | n/a | — | — | **KILLED** (T530) | key-agreement¹ |
| **M4** ACCEPT-KOKEY | — | — | n/a | — | — | — | — | n/a | — | n/a | — | — | **KILLED** (T530) | key-agreement¹ |
| **M5** GTP-LHSIDE | — | **✗** | n/a | — | — | — | — | n/a | — | n/a | — | — | **KILLED** | — |
| **M6** DTT-UNSET | — | — | n/a | — | — | — | **✗** | n/a | — | n/a | — | — | **KILLED** | — |
| **M7** INVSYM-BROKEN | — | **✗** | n/a | — | — | — | — | n/a | — | n/a | — | — | **KILLED** | — |
| **M8** T261 deleted-entry | — | — | n/a | — | — | — | — | n/a | — | n/a | — | — | **KILLED** (T363) | G2⁴ |
| **M9** BATTERY-STUBBED | — | — | — | — | — | — | — | — | — | — | — | — | **KILLED** | meta³ |
| **M10** alias-control | — | — | — | — | — | — | — | — | — | — | — | — | **KILLED** (T363) | —⁵ |

**Key:** `✗` = killed (invariant reports fail, test assertion verified) · `—` = not applicable (invariant doesn't test that property) · `n/a` = not applicable on WZO1 · `may³` = could catch in principle but the synthetic fixture does not trigger a kill (superseded: M3 now killed by key-agreement, T530) · `meta³` = killed by the BATT-HEALTH meta-check (`src/vb_health.zig`, T347), which enumerates every declared invariant by compile-time reflection over `vb.Invariant` and fails iff any returns `.skipped` · `¹` = killed by the key-agreement invariant (producer `rules.stateKey` vs consumer `vb_movegen.stateKey`, the T267/T345 machinery). Per-mutant red-then-green kill-verification fixtures for M1/M2/M3/M4 added by T530 at `src/vb_mutants.zig` (M1: producer index function swapped to the base-3 lexicographic rank, colex=10 vs rank=58 on the witness; M2: producer drops the passes bit, passes=1 encoded as passes=0; M3: producer uses the pre-T265 ko rule (any single-stone capture → ko) on a witness where the corrected rule says ko=NONE; M4: one consumer uses the pre-T265 ko rule while the other uses the corrected rule). The T345 KEY-4x4 exhaustive run (`src/differential.zig:1360`) remains the full-space reading. · `⁴` = M8 fixture lives at `src/vb_mutants.zig:486` (3×3 WZO2, deletes one entry from `data/oracle-3x3-v2.wzo2`); C-A1 `children_not_in_table` 0→2, C-A2 `reachable_not_in_table` 0→1, restore → 0/0. · `⁵` = M10 fixture at `src/vb_mutants.zig:536` exercises the I11 null control (kernel-vs-SMD1, both kernel) → 0/114 vacuous, AND the seeded-defect control (allows-suicide mutant) → 1/114, together proving the harness is sensitive to genuine disagreement; the meta² gap (no battery-integrated independent-reimplementation check) was the original framing and is now superseded — the I11 null + seeded-defect pair is wired into the battery.

**Kill rate: 10 / 10 (denominator: 10 mutants).** All ten catalogue mutants are killed by battery checks with red-then-green kill-verification fixtures.

Of the 10 mutants:
- **10 killed** by battery checks: M1 (key-agreement, T530), M2 (key-agreement, T530), M3 (key-agreement, T530 — inverted from SURVIVES), M4 (key-agreement, T530), M5 (I2 colour inversion), M6 (I7 DTT sanity), M7 (I2 colour inversion), M8 (C-A1/C-A2 closure, T363), M9 (BATT-HEALTH meta-check, T347), M10 (I11 null + seeded-defect, T363)

**Reconciliation (T475, 2026-08-19).** T363's note (`findings/T363-g3b-completion.json`) claimed
"SEVEN OF SEVEN mutants now asserted killed (M1-M4 KEY-4x4, M8 CLOSURE, M9 BATT-HEALTH, M10 I11-null)".
The run evidence at `zig build test` (T475, 2026-08-19) shows this was an overstatement: **only 6
mutants have kill-verified tests** (M5-M10 except M3); M3 still SURVIVES (`src/vb_mutants.zig:94`,
explicit comment "M3 survives", test asserts `I5Status.pass`); M1, M2, M4 have no per-mutant
kill-verification fixture — T345 KEY-4x4 calibration proves the machinery is sensitive to colex
bit-flip, but exhaustive key-agreement has not been red-then-green tested against the M1/M2/M4
fixtures specifically. The honest kill rate is **6/10**, not 7/10 or 4/10 (the pre-T347 figure).
The matrix above is the corrected record.

**Closure (T530, 2026-08-20).** The four remaining gaps are closed. M1/M2/M3/M4 now have
per-mutant red-then-green kill-verification fixtures in `src/vb_mutants.zig` (key-agreement
invariant: producer `rules.stateKey` vs consumer `vb_movegen.stateKey`). M3's test was inverted
from `[EXPECTED-GAP]` SURVIVES to KILLED: the input that exposes it is a 2×2 single-stone
capture where the capturing stone keeps >1 liberty — the pre-T265 rule spuriously sets ko there,
the corrected rule (liberties==1 && friendly==0) returns ko=NONE, and the keys disagree.
Kill rate is now **10/10**. The Amendment-2 mutation gate is satisfied as written (all mutants
killed). The G1/G3 key-agreement invariant is no longer a gap for the catalogue mutants; the
T345 KEY-4x4 exhaustive reading remains the full-space check.

M3 merits explanation. It has a *conceivable* killer in the current
battery (I5 SCC containment), but the synthetic fixture does not trigger
a kill: on the 2×2 all-legal graph, every legal state at passes=0 is
cycle-reachable. The proper killer is the T267 key-agreement invariant
(G1/G3), which does not exist yet. The test assertion for M3
expects `.pass` (survival), marked `[EXPECTED-GAP G1/G3]`. **When the Waypoint 2
kernel lands and key-agreement is runnable, invert this assertion** to
expect `.fail` — the fixture corruption is correct; only the check is
absent.

**Inverted on 2026-08-20 (T530):** the key-agreement invariant is now runnable and the M3
assertion is inverted to `.fail` — the fixture at `src/vb_mutants.zig` kills the mutant. The
witness input (2×2 board `[0,1,0,-1]`, Black plays cell 2) is a single-stone capture whose
capturing stone keeps two liberties: the old rule returns ko=3, the corrected rule returns
ko=NONE (4), and the producer/consumer keys disagree. The I5 vacuity note above remains the
explanation of why I5 cannot kill it on 2×2/3×2/4×3; the artifact-level 4×4 red-then-green
(spurious L!=H on a non-cycle-reachable entry) lives in `src/vb_scc_4x4.zig`.

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

### M1 (T178: colex vs combinatorial rank) — KILLED by key-agreement (T530)

**Fixturing:** the producer's index function is replaced by a different
bijection — the base-3 lexicographic rank (the class of "rank vs colex"
confusion T178 was). On the witness 2×2 board `[1,-1,0,0]` the two bijections
disagree (colex=10, rank=58). The producer key built with the rank disagrees
with the consumer key (which re-encodes the position via its own colex) →
key-agreement fires (red); with colex on both sides the keys agree (green).

**Killer:** key-agreement invariant (producer `rules.stateKey` vs consumer
`vb_movegen.stateKey`, the T267/T345 machinery).
**Test:** `src/vb_mutants.zig` `"M1-T178 colex-vs-rank KILLED by key-agreement (red, then green)"`.

### M2 (T193: passes bit dropped) — KILLED by key-agreement (T530)

**Fixturing:** the producer drops the passes bit — a passes=1 state (empty
board, White to move, ko=NONE, reachable by Black passing first) is encoded
with passes=0, landing at the passes=0 index. The producer key disagrees with
the consumer key on the passes field (red); with the bit kept the keys agree
(green). WZO1 has no passes dimension, so the fixture is at the key level.

**Killer:** key-agreement invariant (producer `rules.stateKey` vs consumer
`vb_movegen.stateKey`).
**Test:** `src/vb_mutants.zig` `"M2-T193 passes-bit KILLED by key-agreement (red, then green)"`.

### M4 (ACCEPT-KOKEY: old ko rule in one consumer) — KILLED by key-agreement (T530)

**Fixturing:** the pre-T265 ko rule (any single-stone capture → ko) is restored
in one consumer while the other uses the corrected rule. On the witness 2×2
board `[0,0,1,-1]`, Black plays cell 1 — a single-stone capture whose
capturing stone keeps two liberties: the old-rule consumer computes ko=3, the
corrected-rule consumer computes ko=NONE (4). The two consumers' keys disagree
(red); with both corrected the keys agree (green).

**Killer:** key-agreement invariant (two consumers of the same state).
**Test:** `src/vb_mutants.zig` `"M4-ACCEPT-KOKEY old-ko-consumer KILLED by key-agreement (red, then green)"`.

## 4a. Survival-verified mutant — CLOSED 2026-08-20 (T530)

The single survival-verified mutant (M3) was inverted to KILLED by T530; this
section is retained as the record of the pre-closure state. The assertion
inversion is in place (the fixture now expects `.fail`).

### M3 (T265: ko set too broadly) — KILLED (T530) by key-agreement

**Original fixturing:** The fb column is corrupted at colex index 40
([B,B,B,empty], Black side) — a position with no legal placement moves.
KO_SENSITIVE is spuriously set. I5 maps this to (colex=40, side=0, ko=NONE,
passes=0) and checks cycle-reachability. On the 2×2 all-legal graph, every
legal state at passes=0 is cycle-reachable (pass transitions alone guarantee
it), so I5 reports `ko_not_cr=0` → status `.pass`. That vacuity is why I5
cannot kill the mutant on 2×2/3×2/4×3; the artifact-level 4×4 red-then-green
(spurious L!=H on a non-cycle-reachable entry) lives in `src/vb_scc_4x4.zig`.

**T530 killer:** the key-agreement invariant (producer `rules.stateKey` vs
consumer `vb_movegen.stateKey`). The input that exposes M3: a 2×2 board
`[0,1,0,-1]` (B at 1, W at 3), Black plays cell 2 — a single-stone capture
whose capturing stone keeps two liberties. The pre-T265 rule (any single
capture → ko) returns ko=3; the corrected rule (liberties==1 && friendly==0,
`rules.koAfterCapture`) returns ko=NONE (4). The producer key built with the
old rule disagrees with the consumer key — the check fires (red) and agrees
when the producer uses the corrected rule (green).

**Test:** `src/vb_mutants.zig` `"M3-T265 ko-too-broad KILLED by key-agreement (red, then green)"`.

## 5. Survived mutants — gap assignments

### Gap G1/G3 — Z-R-STATE / Z-STATE-KEY (key agreement) — CLOSED 2026-08-20 (T530)

**Affected mutants:** M1 (T178), M2 (T193), M4 (ACCEPT-KOKEY) — all KILLED by T530.

Historical note: the battery had no check that the producer's state encoding
matches the consumer's. T267's key-agreement invariant — "run both encoders
on the same state space, count mismatches" — required both the producer
encoder (kernel `rules.stateKey`, T273) and the consumer encoder (R8
`vb_movegen.stateKey`, T340). **CLOSED by T530:** the producer encoder is
available in the kernel and the per-mutant red-then-green fixtures for
M1/M2/M3/M4 are wired into `zig build test` via `src/vb_mutants.zig`. The
T345 KEY-4x4 exhaustive reading (0 / 99,133,036 mismatches) remains the
full-space check.

M1 note (historical): I2 *may* incidentally catch a colex-vs-combinatorial-rank
scramble if the index mismatch produces enough inversion violations. But this
is coincidental — the intended killer is key-agreement. The T530 fixture kills
M1 deterministically: the producer's index function is replaced by the base-3
lexicographic rank (wrong bijection), the keys disagree (colex=10 vs rank=58
on the witness), and agree when the producer uses colex.

M2 note (historical): WZO1 has no passes dimension, so the passes-bit defect
cannot be fixtured on the artifacts the battery currently reads. The T530
fixture kills M2 at the key level: the producer encodes a passes=1 state with
the passes bit dropped (passes=0), the keys disagree, and agree when the bit
is kept.

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

**Gap G1/G3 — Z-R-STATE / Z-STATE-KEY (key agreement)** covered M1/M2/M3/M4. T345 KEY-4x4
calibration in `src/differential.zig:1554` demonstrates the key-agreement machinery is sensitive
to colex bit-flip (mutant → mismatch detected), and T345 KEY-4x4 exhaustive runs the
producer/consumer comparison over all 99,133,036 4×4 entries (`src/differential.zig:1360`).
Per-mutant kill-verification fixtures for M1/M2/M3/M4 were added by **T530 (2026-08-20)** in
`src/vb_mutants.zig`; the M3 test was inverted from SURVIVAL to KILLED. **Gap G1/G3 is closed**
for the catalogue mutants; the T345 KEY-4x4 exhaustive reading remains the full-space check.

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
| 2026-08-20 | **T530: kill rate 6/10 → 10/10.** M1 (colex-vs-rank), M2 (passes bit), M4 (ACCEPT-KOKEY) get per-mutant red-then-green kill-verification fixtures; M3 (ko-too-broad) is inverted from SURVIVES to KILLED. All four are killed by the key-agreement invariant (producer `rules.stateKey` vs consumer `vb_movegen.stateKey`, T267/T345 machinery): M1 swaps the producer's index function to the base-3 lexicographic rank; M2 drops the producer's passes bit; M3/M4 apply the pre-T265 ko rule (any single-stone capture → ko) to a witness where the corrected rule returns ko=NONE — the keys disagree (red) and agree when corrected (green). Gap G1/G3 closed for the catalogue mutants. The Amendment-2 mutation gate is now satisfied as written (all mutants killed). | deepseek-v4-flash/T530 |
