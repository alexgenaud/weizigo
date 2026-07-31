# oracle-v2 M1 design rev 2 — Re-audit

```
Auditor:  DSPro/T150 · Role: worker · Date: 2026-07-31
Target:   docs/design/oracle-v2/pass1/design-M1.md (PROPOSED rev 2, T148/DSPro, 2026-07-31)
Against:  docs/design/oracle-v2/pass1/design-M1-audit-rev1.md (T146/Opus 5, 2026-07-31)
          docs/infra/oracle-v2/spec.md (pass 1, ratified G1)
Verdict:  NEEDS-FIX
```

## Verdict

**NEEDS-FIX.** The three DTT defects the previous audit identified
(NEW-2/3/4) are properly resolved, and the DTT definition is now correct.
The two cosmetic items the design claims to fix (NEW-7, NEW-8) are fixed.
However, the open **NEW-1 (CRITICAL)** — §7.1's A-series not matching spec
§4 — was not addressed and blocks G2, and **NEW-5 (MUST)** — the §5.3 unit
violation — remains. NEW-9's three loose ends remain. The design's header
states "T146 re-audit addressed" but lists only NEW-2/3/4/7/8 under §11;
it does not claim to have addressed NEW-1, NEW-5, NEW-6, or NEW-9. Of
those, NEW-1 and NEW-5 stop the gate.

The core design (§§1, 2, 4, 5, 6, 8) is sound and the DTT column is now
well-defined. REDO is not warranted.

---

## Disposition of T146 (rev 1) findings

| finding | rev 1 grade | rev 2 claimed | verified | note |
|---|---|---|---|---|
| **NEW-1** — §7.1 A-series ≠ spec §4 | CRITICAL | not claimed | ❌ **OPEN** | §7.1 still maps A1=pin(spec A4), A2=colour(spec A3), A3=L≤H(not an A), A4=Bellman(spec A2), A7=UNDEF(spec A7 is gate chain). Spec A1 (refusal rate) and A7 (gate chain) absent. Not fixed. |
| **NEW-2** — DTT min/max by colour | MUST | Fixed (§11) | ✅ **RESOLVED** | §3.1 step 3: `1 + min_{c ∈ VP}` — no colour distinction. Invariant list, A8, I7 all use mover-minimises. Colour-inversion invariant satisfied. |
| **NEW-3** — VP test wrong bound | MUST | Fixed (§11) | ✅ **RESOLVED** | §3.1 step 2: Black `L(c) ≥ L(s)`, White `H(c) ≤ H(s)`. Correct bounds. Non-emptiness traced to Bellman fixpoint. |
| **NEW-4** — FAR contradiction; 255 overload | MUST | Fixed (§11) | ✅ **RESOLVED** | Mover-minimises resolves the FAR/max contradiction. Writer clamps at 254; 255 strictly cycle sentinel. `1+254=255` clamped to 254. Encoding table, step 5, DTT maximum paragraph all agree. |
| **NEW-5** — MB/MiB in §5.3 | MUST | not claimed | ❌ **OPEN** | §5.3: "N × 4 ≈ 378 MB" — 99,133,036 × 4 = 396,532,144 = 396.5 MB (10⁶), not 378. 378 is MiB. Violates the §5-level declaration "MB = 10⁶ bytes throughout." |
| **NEW-6** — A6 unsatisfiable for zeroed-DTT | SHOULD | not claimed | ⚠️ **CARRIED** | Escalation to Orchestrator — not an M1 fix. The design's §7.1 A6 routes zeroed-DTT to I7, which is correct in substance. Spec still says "fails A1–A5." Not resolved, not M1's to resolve. |
| **NEW-7** — duplicate `reserved` field name | COULD | Fixed (§11) | ✅ **RESOLVED** | Header offsets: 15 = `reserved0`, 72 = `reserved1`. |
| **NEW-8** — `rules_id` u16 vs u8 | COULD | Fixed (§11) | ✅ **RESOLVED** | §4.1 and §10.4: header stores u16, low byte from `artifact.zig`'s `u8` constant, high byte zero. Reader validates low byte only. |
| **NEW-9** — three loose ends | COULD | not claimed | ❌ **OPEN** | All three sub-items still present (see below). |

**Score: 4 resolved (NEW-2/3/4/7/8), 3 open (NEW-1, NEW-5, NEW-9), 1 carried (NEW-6).**

---

## NEW-9 sub-items — detailed

| # | sub-item | status |
|---|---|---|
| 9.1 | §3: i8 range "through 5×5 (n=25)" — misleading given §2.1's 20-cell format ceiling | ❌ Unchanged. Still says "through 5×5 (n=25)" with no cross-reference to the format ceiling. |
| 9.2 | §4.3: load validation omits `ko_bits == ceil(log₂(w·h+1))` and `hdr_flags` bit 0 | ❌ Unchanged. §4.3 steps 1–8 do not include these two checks, though §7.2 lists both as format-level. |
| 9.3 | Appendix A: `terminalRow(colex, side)` takes `side` — §2.3 established it is irrelevant | ❌ Unchanged. Pseudocode still calls `terminalRow(colex, side)`. |

---

## DTT definition — independent verification

I traced the full DTT recurrence (§3.1) end-to-end against the fixpoint
contract and the colour-inversion requirement. **It is correct.**

| component | text | assessment |
|---|---|---|
| Base case | passes=2 → DTT=0 | ✓ — absorbing terminal, not stored |
| VP test (Black) | `L(c) ≥ L(s)` | ✓ — the argmax children of the fixpoint satisfy this; pass is excluded when a placement strictly improves L |
| VP test (White) | `H(c) ≤ H(s)` | ✓ — the argmin children satisfy this; symmetric |
| Recurrence (placements) | `1 + min_{c ∈ VP}` | ✓ — mover-minimises, colour-inversion invariant |
| No-legal-placement | pass is only child; value-preserving by fixpoint (`L(s)=L(pass_child)`) | ✓ — DTT ≥ 1, not 0 |
| Cycle sentinel | 255 = FAR; writer clamps at 254 | ✓ — no arithmetic collision with FAR |
| Invariants | DTT=0 ⇔ passes=2; non-terminal non-FAR: 0 < DTT ≤ 254 | ✓ — consistent with encoding table |

The pass–pass collapse (BLOCKER-2's original defect) does not return under
the strict VP test: if Black can improve L by playing, the pass has
`L(pass_child) < L(s)` and is excluded from VP. Step 4's special case
triggers only for `terminal=1` states (no legal placements), where pass is
trivially value-preserving by the Bellman fixpoint. ✓

One open question carried forward from both previous audits: **the true DTT
maximum is unknown** — whether the 254 clamp binds cannot be answered before
the solve runs. The design is honest about this (§9.2). Not a defect; a
known unknown.

---

## Brief-mandated checks

| check | result |
|---|---|
| **Byte budget ≤ 600 MB** | **PASS.** 515.5–518.1 MB, re-derived by T146 and confirmed against `4x4-standard.txt:37,41` and `exp6_solve.zig:1113`. 82–84 MB headroom. No change from rev 1 — the F2 gate remains cleared. |
| **Key encoding uses the full key, passes NOT folded** | **PASS.** `(colex, side, ko, passes)` all on disk; passes=0 and passes=1 are distinct keys. The passes=2 omission is R10's terminal contract, not a projection. |
| **Column schema stores L/H separately** | **PASS.** i8 columns, reader-side convention. `terminal` in key_byte LSB. KO_SENSITIVE = `L != H`. DTT definition now correct. |
| **Header layout** | **PASS with cosmetic items.** Offsets close to 128; u64s 8-byte aligned; `reserved0`/`reserved1` fixed. NEW-9.2 (two missing load checks) and NEW-9.3 (terminalRow parameter) remain. |
| **Naming convention** | **PASS.** Matches spec §4 F9. |

**All five brief checks PASS.** The F2 gate — the sprint blocker — is cleared
and has been since rev 1.

---

## What I could not establish

1. **Whether the §7.1 A-numbering collision will cause M4a to build fixtures
   against the wrong criteria.** M4a's scope (spec `:170`) is "A3, A5, A6
   fixtures, A9 recipe." Under the spec, A3 = colour inversion; under the
   design's §7.1, A3 = L ≤ H. The design doesn't claim to have fixed this,
   and it has not been fixed. If M4a has already been briefed, its A-numbers
   should be re-read against the spec before it starts.
2. **The true DTT maximum** — unchanged, and correctly carried in §9.2.
3. **The exact distinct goban count G under M2b's walk** — unchanged,
   correctly carried in §9.3. The bracket (23.80M–24.32M) is safe.

---

## New findings

### RV2-1 (MUST) — passes=2 DTT contract omission in the non-stored rationale

§2.3 states "L = H = genericAreaScore(goban)" and "DTT = 0" for passes=2
terminals. §3.1 step 1 confirms DTT=0 for passes=2. The invariant list
and the encoding table repeat it. **But the statement that DTT=0 for
passes=2 is not repeated in §2.3, where the reader determining "what is a
passes=2 terminal?" looks first.** Currently §2.3 says DTT=0 only implicitly
(one could infer it from §3.1), while the `terminal` flag is stated
explicitly as 1. Add "DTT=0" to §2.3's bullet list so the terminal contract
is self-contained. One bullet point.

---

## Summary

| Grade | Count | IDs |
|-------|-------|-----|
| **CRITICAL** | 1 | NEW-1 (§7.1 A-series ≠ spec §4 — open from rev 1) |
| **MUST** | 2 | NEW-5 (§5.3 "378 MB" → 397 MB — open from rev 1), RV2-1 (§2.3 omits DTT=0 — new) |
| **SHOULD** | 1 | NEW-6 (A6 spec escalation — carried from rev 1) |
| **COULD** | 1 | NEW-9 (three loose ends — open from rev 1) |

**NEEDS-FIX — one more revision, narrowly scoped.** The substantive
technical content (DTT, F2 budget, key encoding, header layout) is solid.
The remaining work:
- Rewrite §7.1's `criterion` column against `spec.md:118-126` (NEW-1)
- Fix §5.3: "378 MB" → "397 MB" (NEW-5)
- Add "DTT=0" to §2.3's bullet list (RV2-1)
- Optionally fix NEW-9's three loose ends (COULD)

Sections 1, 2, 3, 4, 5, 6, and 8 are sound and should not be reopened.
§7.2 and §7.3 are correct and need only the rows §7.1 sheds.

**For the Orchestrator.** Two items do not belong to M1: NEW-6 (spec A6's
corruption list — the "fails A1–A5" wording should read "fails A1–A5 or A8")
and the NEW-1 collision with M4a's dispatched scope. If M4a has been
briefed against the design's A-numbering rather than the spec's, its
A-numbers should be re-read before it starts. The M2b start gate is clear
on budget grounds — F2 passed in rev 1 and no budget-affecting change has
occurred in rev 2.
