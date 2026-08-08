# CODE.RESOLVER — provenance for the pluggable bracket-resolver rows

**Written:** 2026-08-08 by `deepseek-v4-flash/T418` (absorption of `findings/T402-capture-budget-pluggable.json`).
**Serves:** register rows `CODE.RESOLVER-INTERFACE`, `CODE.RESOLVER-BUDGET-QUARANTINE`, `CODE.RESOLVER-CONTROLS`
(renamed at absorption from the proposed `RESOLVER.*` per the T418 brief — `RESOLVER.` is not an
established ID prefix; `CODE.` is, and these are code claims).
**Sources:** `src/resolver.zig` (615 lines), `src/resolver_harness.zig` (293 lines),
`docs/decisions/ADR-0022-bracket-resolvers-pluggable.md`, `findings/T387-capture-budget.json`,
`docs/research/capture-budget-2026-08-06.md`, `findings/T402-capture-budget-pluggable.json`.

This directory exists so the three resolver rows cite evidence under `docs/evidence/` (claimlint C3
tier A). It records what the verification actually was — code inspection, the unit tests, and the
artifact-backed harness run — with denominators.

## What the subsystem is (from reading `src/resolver.zig` and ADR-0022)

- `Resolver` is a pluggable struct: `name`, `metadata`, a `resolve` function pointer, and an opaque
  `self_ctx`. `propose(rc)` calls `resolve`. `ResolveContext` carries `(colex, side, L, H)`.
  `Resolution` is `value` or `no_opinion` (`src/resolver.zig:70-95`).
- Registered resolvers (`src/resolver.zig:28-36`): `none` (null control), `bracket_low`,
  `bracket_high`, `bracket_mid` (baselines), `deliberately_wrong` (seeded control — proposes L−1,
  "MUST be caught", `src/resolver.zig:162`), `capture_budget(B)` (`src/resolver.zig:216-243`).
- ADR-0022 (`docs/decisions/ADR-0022-bracket-resolvers-pluggable.md`): resolvers are pluggable and
  **none is authoritative** — output is never promoted without independent agreement. "Internal
  consistency is not external agreement" (the file header, from T387/T397).
- `capture_budget(B)`'s registration metadata records the measured non-convergence of the budget
  rule (4×3 root oscillates in {0,1,2,7,9,12}, never equals the PSK truth +4 — the datum itself is
  T387's single-instrument reading; see the BUDGET-QUARANTINE row's downgrade note).

## Verification performed

1. **Unit tests — `zig test src/resolver.zig`, 2026-08-08 (this absorption): 11 passed, 0 failed,
   1 skipped.** The 12 tests cover: each resolver's contract (none / bracket_low / bracket_high /
   bracket_mid / deliberately_wrong / capture_budget), and the comparison harness's counters —
   null control (none proposes nothing), bracket_low 100% on L==H, bracket_mid containment on L<H,
   **deliberately_wrong IS REFUTED on L==H**, all-resolvers-together. The 12th test
   ("artifact-backed comparison — 3x3 WZO2") is a deliberate `return error.SkipZigTest;` — the
   artifact-backed comparison is the harness binary, not a unit test. The T402 findings' "11/11
   tests pass" counts the 11 passing tests; the skip is by design.
2. **Harness re-run — `src/resolver_harness.zig` rebuilt ReleaseSafe and run at 3×3 on
   `data/oracle-3x3-v2.wzo2`, seed 42, 2026-08-08 (this absorption), reproduced the T402 figures
   exactly:**
   - enumerated **23,420 positions** (L==H: 20,216, L<H: 3,204) — all non-terminal entries at
     ko=NONE, passes=0 in the 3×3 WZO2 table
   - null control: `none` proposed **0/23,420** — PASS
   - seeded control: `deliberately_wrong` proposed L−1, **REFUTED at 20,216/20,216** L==H
     disagreements (first witness colex=0, side=1, L=H=9, proposed=8) — PASS
   - `capture_budget(8)`: proposed **20,216/23,420** (all L==H entries), abstained **3,204/23,420**
     (all L<H entries), L==H agree 20,216/20,216
   - baselines: bracket_low/high/mid propose 23,420/23,420, agree 20,216/20,216 on L==H, all
     3,204/3,204 L<H proposals inside [L,H]
3. **The 0/21,126-at-B≥24 figure** in the CONTROLS row is T387's budget-mode datum (the budget rule
   preserves the determined region at sufficient B), cited from `findings/T387-capture-budget.json`
   and `docs/research/capture-budget-2026-08-06.md`; it was **not** re-derived by this absorption
   and is not part of the PROVEN core — it is attributed to T387 in the row text.

## What is and is not claimed PROVEN here

- **PROVEN (as claims about code):** the interface contract (definitional — it is what
  `src/resolver.zig` says, verified by the tests above); the two controls firing over all 23,420
  3×3 harness positions (exhaustive within the harness; re-verified by the run above); the
  capture_budget partial-implementation behavior at 3×3 (propose L on all 20,216 L==H, abstain all
  3,204 L<H).
- **CLAIMED (downgraded from PROVEN at absorption):** the BUDGET-QUARANTINE compound — the
  demotion, registration and metadata are code/process facts (verified by inspection), but the
  load-bearing measured non-convergence (4×3 root oscillation, never +4) is a single-instrument
  T387 datum of the same provenance class as `GLOBAL.CAPTURE-BUDGET-DAG` (held at MEASUREMENT for
  exactly that reason, T404). No second seat has adjudicated the oscillation; verify-then-promote
  (QA-023 chain) bars PROVEN on the compound.
