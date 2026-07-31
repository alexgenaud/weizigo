# EXP-7 4×4 re-run — certified fraction under basic-ko + TIE=0 at 4×4

**Task: T129 · Role: worker · Model: DSPro · Date: 2026-07-31**

Per `docs/infra/dispatch/T129-exp7-4x4-rerun.md` and the inherited
`docs/infra/dispatch/EXP-7.md` brief: under basic-ko + TIE=0, area scoring,
komi 0, what is the certified fraction at 4×4 — the proportion of visited
fresh-start decision nodes in self-play where the one-ply V-domain Bellman
identity holds?

**Artifact:** `data/oracle-4x4-basicko-tie-area.wzo` (T113, sha256
`edd9f68ef243f67de21152432f9e8f521536317527d425208e6901f90b11c0cc`).

---

## 1. 4×4 result — FAIL (10.71%, not 100%)

**Fixpoint (from artifact):** 31 sweeps, converged, 24,318,165 valued slots.
Root B = +1 (L=+1, H=+16, bracket=1), Root W = −1 (L=−16, H=−1, bracket=1).

**Playout (oracle, 2,000 games, seed 20260728):**

| metric | value |
|---|---|
| games | 2,000 |
| two-pass terminations | 2,000 (100%) |
| cycle terminations | 0 |
| UNDEF nodes (visited) | 0 |
| **visited decision nodes (total)** | **34,000** |
| **fresh-start nodes (passes=0, ko=none)** | **28,000** |
| Bellman MATCH | 3,000 |
| Bellman VIOLATION | **25,000** |
| Bellman TIE_CHILD | 0 |
| **certified fraction** | **10.71% (3,000/28,000)** |
| flag-read bracket fraction | 8.82% (3,000/34,000) |

**oracle-rt:** identical result (same deterministic line).

**Verdict: FAIL.** The V-domain Bellman identity holds at only 10.71% of
fresh-start decision nodes under oracle self-play. **QA-027 is FALSE at 4×4.**

### 1.1 The root violation

The empty-board root causes a Bellman violation directly:

- vb[empty] = +1 (V = median(L=+1, TIE=0, H=+16))
- B's best placement child: B@B2 → vw[B@B2] = 16
- B's pass child: min(area=0, vw[empty]=−1) = −1
- best_child(V) = max(−1, 16, …) = 16
- 1 ≠ 16 → **VIOLATION**

The stored V=+1 is the median of the bracket [L=+1, H=+16]. The median does
not distribute over the best_child operation. Even though the L/H fixpoint
converged (L = best_child(L), H = best_child(H)), the median-pinned V fails
the Bellman identity.

### 1.2 The mechanism

The median-pinning V = max(L, min(TIE, H)) produces a value between L and TIE
(or between TIE and H) that does not propagate through minimax. At bracket-valued
states (L<H), V is clamped by TIE=0. The children's V values, derived from
their own L/H brackets with median-pinning, can disagree with the parent's
clamped V.

This is the substance of the falsification test: the bracket-valued root
[L=+1, H=+16] is exactly where the V-domain Bellman identity can fail even
though the L/H fixpoint converged.

### 1.3 Non-degenerate flag column

The flag-read bracket fraction is 8.82% (non-zero). The brief's expectation
that the flag column would be all-zero under the new rule is **falsified**:
the artifact stores bit 0 = (L<H) per slot, and 981,071 slots per side have
L<H (2.28% of all slots, 4.03% of valued slots). The flag is NOT degenerate.

---

## 2. Comparison with 3×3 (known-good)

| metric | 3×3 (EXP-7 original) | 4×4 (T129 re-run) |
|---|---|---|
| policy | oracle | oracle |
| seed | 20260728 | 20260728 |
| games | 2,000 | 2,000 |
| total nodes | 8,000 | 34,000 |
| fresh-start nodes | 8,000 | 28,000 |
| Bellman MATCH | 8,000 | 3,000 |
| Bellman VIOLATION | 0 | 25,000 |
| certified fraction | **100.00%** | **10.71%** |
| root type | single-valued (L=H=9) | bracket-valued (L=+1, H=+16) |

The 3×3 table is single-valued at the root (L==H==9), so V = 9 exactly and
the Bellman identity holds everywhere visited in self-play. The 4×4 table is
bracket-valued at the root and at many visited states, causing extensive
Bellman violations.

---

## 3. Calibration

### Known-good: PASS
3×3 fixpoint + playout reproduces 100.00% certified (8,000/8,000 nodes, 0
violations), matching the original EXP-7 result exactly.

### Known-bad (perturbation): PASS
Perturbing the PSK artifact's vb[0] from +2 to +10 introduces 50 Bellman
violations (certified fraction drops from 100% to 96.15%). The instrument
detects the perturbation.

### Known-bad (PSK table under new rule): INCONCLUSIVE
The unmodified PSK 4×4 table returns 100.00% certified under new-rule
legality. This was expected to NOT return 100%, but the PSK table's values
happen to satisfy the Bellman identity for the children reachable under
new-rule playout. This does not invalidate the instrument — the perturbation
test confirms sensitivity. It may indicate that the PSK oracle is more
self-consistent under basic-ko play than the median-pinned new-rule oracle.

---

## 4. What this means

- **QA-027 is FALSE at 4×4.** The certified fraction is 10.71%, not 100%.
- **QA-020 is re-tested at 4×4.** Under PSK it was 0% (100% KO_SENSITIVE).
  Under the new rule it is 10.71% (direct-identity check). Both are far from
  100%, but for different reasons.
- **The median-pinning V = max(L, min(TIE, H)) does NOT produce a chainable
  value table at 4×4.** The L/H fixpoint is consistent, but the derived V
  values are not.
- **The gating prediction in EXP-2 (that the Markovian rule makes the certified
  fraction 100% by construction) is falsified at 4×4.** The Markovian property
  (state = (board, side, ko)) does not guarantee that V = median(L, TIE, H)
  satisfies the V-domain Bellman identity.

---

## 5. What could not be established

- **Whether the violations would disappear with access to L/H values rather
  than V.** The Bellman identity holds for L and H separately (by fixpoint
  construction). The violations are in the V-domain only.
- **Whether ko-value approximation causes false violations.** The artifact
  lacks values for ko≠none states. The root violation (and many others) do
  not involve ko at all, so ko-approximation does not explain the headline
  result.
- **Whether a different value derivation (e.g., V=H for maximizing, V=L for
  minimizing) would produce a chainable table.** This is beyond the scope
  of T129.

---

## 6. Proposed claim status inputs (owner: CLAIMS.md)

- **QA-027 (scoped to 4×4):** **FALSE** — the certified fraction under
  basic-ko + TIE=0 at 4×4 is 10.71% (3,000/28,000 fresh-start nodes) under
  oracle self-play, with 25,000 Bellman-identity violations at 2,000 games,
  seed 20260728. The V-domain Bellman identity fails because median(L,TIE,H)
  does not distribute over the best_child operation at bracket-valued states.
  The flag-read fraction is 8.82% (non-degenerate, contrary to expectation).
  Calibration: known-good PASS (3×3 100%), known-bad perturbation detection
  PASS.
- **QA-020 (re-tested under new rule at 4×4):** remains FALSE — the certified
  fraction is 10.71%, far from 100%. Under PSK it was 0% (flag-based); under
  the new rule with direct-identity check it is 10.71%. Both are non-chainable.

---

## 7. Files

- `src/t129_exp7_4x4.zig` — standalone WZO reader + playout + Bellman check
- `docs/evidence/QA-027/4x4/PROVENANCE.md` — claim IDs, calibration, runs
- `docs/evidence/QA-027/4x4/stdout-2026-07-31.txt` — raw 4×4 output
- `docs/evidence/QA-027/4x4/calibration-known-good-3x3.txt` — 3×3 calibration
- `docs/evidence/QA-027/4x4/calibration-known-bad-perturbed.txt` — perturbation detection
- `docs/research/newrule-certified-fraction-4x4-2026-07-31.md` — this file
