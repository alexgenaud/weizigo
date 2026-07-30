# 4×3 epistemic tree

**Status:** per-goban epistemic record for the shipped 4×3 artifact.
Every claim below is tagged for **4×3 only**; see `boards/CONCEPTS.md` for
size-generic definitions and the per-goban-independence rule.

Legend: ✅ proven · ⬜ untested · 🟡 in progress · ❌ falsified · ⛔ intractable ·
⬜ᴵᴺᴴ inherited (structural / not re-reproven at 4×3)

## Artifact

- `artifacts/oracle-4x3.wzo` — WZO1, goban 4×3, `board_w=4`, `board_h=3`.
- Raw colex space: `total = 3^(4·3) = 531,441` rows per column.
- Legal positions per side: `legal_count = 321,689`.
- Rules id 1: Chinese area scoring, komi 0, positional superko,
  Benson/double-pass terminal.
- Value semantics 1: fresh-start value (ADR-0008).
- File size: 3,188,678 bytes (32-byte header + 6 × 531,441 byte columns).

## Claims

| Claim | Status | Evidence / caveat |
|---|---|---|
| **S1** colex bijection | ✅ **PROVEN** | Mixed-radix colex layout is size-generic and has been exhaustively round-tripped through 4×4; 4×3 raw space is smaller (531,441 gobans) and inherits the same structural proof. |
| **S2** Benson-alive theorem | ✅ **PROVEN** | Goban-structure theorem; holds for all finite gobans. |
| **S2-impl** `rules.zig` Benson implementation | ⬜ **UNKNOWN at 4×3** | Not separately regression-tested at 4×3. S2-4×4 implementation regression (`rules.zig` vs naive) passed for ≤8 stones; 4×3 not explicitly run. |
| **S3a** move/capture/suicide kernel | ✅ **PROVEN** | `legal_count = 321,689` matches OEIS A094777 for 4×3. |
| **S3b** ko-legality under history | ⬜ **UNKNOWN at 4×3** | OEIS count does **not** attest history-legality; no 4×3-specific PSK ko-legality test is logged. |
| **S4** area scoring | ⬜ᴵᴺᴴ **inherited** | `rules.area_score` is size-generic and cross-validated at smaller sizes; not re-reproven with a 4×3-specific battery. |
| **FP1** L least / H greatest fixpoint | 🟡 **CLAIMED** | 4×3 artifact was produced by the retrograde engine; seed-from-`±N` and zero-change termination are expected, but a post-hoc 4×3 V0/V1 check is not separately recorded. |
| **FP3** finite-sweep convergence (theorem) | ✅ **PROVEN** | Knaster-Tarski on a finite lattice; size-generic structural proof. The 17 sweeps measured for 4×3 is **M2**, not the theorem. |
| **C1** fresh-start scores correct | 🟡 **CLAIMED / inferred** | Artifact fill + anchors + symmetry. No independent exact-solver ground truth at 4×3; the committed artifact uses the same finisher path that was proven buggy at 3×2 (ADR-0013). |
| **C2** L==H history-independent | ⬜ **UNKNOWN at 4×3** | Falsified at 3×2 (T13) and corroborated at 4×4 scale; per-goban independence means 4×3 has **not been tested**. Do not inherit the 3×2 falsification as a 4×3 result. |
| **C3** `[L,H]` bounds real PSK score | ⬜ **UNKNOWN at 4×3** | Falsified at 3×3 (E2). No 4×3 range-aware self-play run is recorded; per-goban independence forbids importing the 3×3 result. |
| **F1** writes-on finisher (`ko_ref >= d`) | ❌ **unsound** | Proven unsound at 3×2 (45/378 auditor violations, ADR-0013). The 4×3 artifact was produced before the writes-off fix; treat its ko-sensitive values as CLAIMED, not PROVEN. |
| **F2/F3** writes-off finisher sound | ⬜ **UNKNOWN at 4×3** | Requires a 4×3 artifact regenerated with `memo_writes=false` plus #2 auditor + bracket containment. Not done. |

## Measured facts (data, not knowledge)

- **M1** ko-sensitive fraction: **170,276 / 643,378 = 26.47%** of (position, side) slots.
- **M2** sweeps: **17** to convergence (measured, not the theorem).
- **M3** scaling: full 4×3 writes-on solve ~4.7 s (census), ~31 s with sound dependency guard; ~16.6× node-count increase vs 3×3.
- Empty-goban bracket: **[-1, +12]** (width 13 out of 28 possible).
- Published anchor: **+4** for Black on empty 4×3, in-bracket (`docs/research/ruleset-options.md`).

## Falsifications / dead-ends

- **F1** (`ko_ref >= d`) guard is the same unsound guard used to generate the
  committed 4×3 artifact. Until a writes-off 4×3 artifact is produced, the
  ko-sensitive region of `oracle-4x3.wzo` is **CLAIMED**, not PROVEN.
- **C2 / C3** are **not tested at 4×3**; do not quote 3×2/3×3 falsifications
  as 4×3 results.

## Open

- S2-impl implementation regression at 4×3 (cheap).
- FP1 post-hoc three-check (seed + zero-change + V0/V1) on the committed 4×3
  artifact (cheap; no new build).
- F2/F3 writes-off 4×3 regen + auditor (depends on prioritisation).
- C2-probe-4×3 and C3-4×4 self-play (low priority; characterisation, not
  deliverable-critical, because the fresh-start-only deliverable is already
  adopted).
