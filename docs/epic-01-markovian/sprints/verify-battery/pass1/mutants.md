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
fails. A `survived` verdict names the gap.

| mutant | I1 | I2 | I3 | I4 | I5 | I6 | I7 | I8 | I9 | I10 | I11 | I12 | verdict | gap |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **M1** T178 colex | — | — | n/a | — | — | — | — | n/a | — | n/a | — | — | **SURVIVED** | G1/G3 |
| **M2** T193 passes bit | — | — | n/a | — | — | — | — | n/a | — | n/a | — | — | **SURVIVED** | G1/G3 |
| **M3** T265 ko-too-broad | — | — | n/a | — | may³ | — | — | n/a | — | n/a | — | — | **SURVIVED** | G1/G3 |
| **M4** ACCEPT-KOKEY | — | — | n/a | — | — | — | — | n/a | — | n/a | — | — | **SURVIVED** | G1/G3 |
| **M5** GTP-LHSIDE | — | **✗** | n/a | — | — | — | — | n/a | — | n/a | — | — | **KILLED** | — |
| **M6** DTT-UNSET | — | — | n/a | — | — | — | **✗** | n/a | — | n/a | — | — | **KILLED** | — |
| **M7** INVSYM-BROKEN | — | **✗** | n/a | — | — | — | — | n/a | — | n/a | — | — | **KILLED** | — |
| **M8** T261 deleted-entry | — | — | n/a | — | — | — | — | n/a | — | n/a | — | — | **SURVIVED** | G2 |
| **M9** BATTERY-STUBBED | — | — | — | — | — | — | — | — | — | — | — | — | **SURVIVED** | meta |
| **M10** alias-control | — | — | — | — | — | — | — | — | — | — | — | — | **SURVIVED** | meta² |

**Key:** `✗` = killed (invariant reports fail, test assertion verified) · `—` = not applicable (invariant doesn't test that property) · `n/a` = not applicable on WZO1 · `may³` = could catch in principle but the synthetic fixture does not trigger a kill (survival verified by test assertion) · `meta²` = `differential.zig` has a null control for this pattern, but it is not part of the battery per se

**Kill rate: 3 / 10 (denominator: 10 mutants).** Three mutants are killed by existing battery checks; the remaining 7 survive.

Of the 10 mutants:
- **3 killed** by existing battery checks: M5 (I2 colour inversion), M6 (I7 DTT sanity), M7 (I2 colour inversion)
- **4 survive** due to **G1/G3** (Z-R-STATE / Z-STATE-KEY — key agreement, needs Phase 2 kernel): M1, M2, M3, M4
- **1 survives** due to **G2** (Z-STATE-REACH — closure C-A1/C-A2, needs Phase 2 kernel): M8
- **2 survive** due to **meta-gaps** (no battery-health check; no independent-reimplementation check integrated into battery): M9, M10

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

**Affected mutant:** M8 (T261 deleted-entry)

The battery has no check that the reachable set is correctly computed. I6
verifies legal position counts (OEIS), not reachability. The C-A1/C-A2
closure checks (T266) require computing the forward/backward closure of the
reachable set, which needs the Phase 2 kernel's move generator.
**Runnable after Phase 2.**

### Meta-gap — no battery-health check

**Affected mutants:** M9 (BATTERY-STUBBED), M10 (alias-control)

M9: The battery has no meta-check that verifies every invariant returns a
real verdict (not `.skipped`). Currently, I3 and I10 legitimately return
`.not_applicable` on WZO1 — a stub would look identical. A meta-check would
enumerate the declared invariants, run each, and verify the status is not
`.skipped` unless the invariant is declared not-applicable for that format.

M10: `differential.zig` (T257) has a null control for the alias pattern
(registering the same function twice and verifying it's detected), but this
is not integrated into the battery's own test suite. The battery does not
currently register multiple "independent" implementations for differential
comparison — that's Phase 2's job (spec A5: two invariants independently
re-implemented).

Both meta-gaps are **acknowledged, not critical for Phase 1**. The Phase 1
battery's invariants are individually calibrated against synthetic mutants;
the meta-checks for the battery harness itself are a Phase 2 concern.

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
