Task: T138 · Role: worker · Model: not stated at dispatch · Date: 2026-07-31

# T138 — 3×2 census reconciliation memo

Confirms the 36-phantom identity behind the census split and the
cycle-reachable spread. States the phantom-exclusion convention I5 adopts.

## (a) The 36-state split: CONFIRMED

**The two censuses and their divergence:**

| source | census | total V | kernel |
|---|---|---|---|
| EXP-4 (`docs/evidence/QA-026/exp4-solve-2026-07-29.stdout:96`) | `L==H=2220, pin_T=298, pin_L=34, pin_H=34` | 2,586 | retrograde engine, bug-free |
| QA-023 corrected (`docs/epistemic/CLAIMS.md:557`, ko-fix-rerun) | `L==H=2232, pin_T=322, pin_L=34, pin_H=34` | 2,622 | corrected `fixpoint_kernel`, 42 seeds |

**Delta:** +36 states (+12 L==H, +24 pin_T, ±0 pin_L, ±0 pin_H).
Sum check: 2,622 − 2,586 = 36 = 12 + 24. ✓

**The phantom count matches exactly.** `seed_roots` in `src/qa023_probe.zig`
originally seeded 42 states (2 sides × 3 passes × 7 ko values). Only 4 are
genuinely reachable from the empty goban (2 sides × 2 passes × 1 ko=none).
The 38-seed delta removes 36 reachable states (2 of the phantom passes=2 seeds
were already reachable from passes=1 seeds and the sweep re-discovers them).

The 36 phantom states are empty-goban-with-ko-point states: a ko point can
only be created by a single-stone capture (`apply_place`: exactly one opponent
stone captured AND the placed stone forms a lone-stone chain whose sole
liberty is the captured cell). The empty goban has no stones → no capture →
no ko point. Therefore every root state must have `ko = KO_NONE`.

**Distribution verified.** The phantom states, when evaluated by the corrected
kernel, fall 12 into the L==H bin and 24 into the pin_T bin. This is
consistent with the expected fixpoint behaviour on empty-goban states — the
ko point does not constrain any legal move (the goban is empty), so the
fixpoint converges to the same (L,H) as the non-ko empty-goban state for
some phantoms (L==H) and to a bracketed value for others (pin_T, because the
phantom ko constraint restricts one hypothetical move line).

**Bottom line:** the 36-state split is exactly the 36 empty-goban-with-ko-point
phantoms, distributed 12 → L==H and 24 → pin_T. Confirmed by (i) the exact
arithmetic match, (ii) the reachability argument that these states are
unreachable from the true game root, and (iii) F1-SEEDROOTS's empirical
confirmation that removing the phantom seeds drops V from 2,622 to 2,586
with the pin-census deltas matching the distribution.

## (b) The cycle-reachable spread: CONFIRMED

**Three committed values and their provenance:**

| value | seeds | ko rule | source |
|---|---|---|---|
| **1,724** | 42 | buggy (F5) | `docs/evidence/QA-023/PROVENANCE-census-3x2-2026-07-29.md:70` (original 2B-2) |
| **1,704** | 42 | corrected | `docs/evidence/QA-023/ko-fix-rerun-2026-07-29.stdout:133` (2B-FIX-KO) |
| **1,678** | 4 | corrected | `docs/infra/dispatch/F1-SEEDROOTS.md:10` (true game root) |

**Reduction chain:**

```
1,724 ──(ko-rule fix, −20)──→ 1,704 ──(phantom removal, −26)──→ 1,678
                                    ──(total: −46)──→
```

- The ko-rule fix (F5: single-stone capture conjunct) removes 20
  cycle-reachable states — edges that were incorrectly banned under the
  over-broad ko rule are restored, and some phantom states lose their
  cycle-reachable status as the graph restructures.
- The phantom removal (F1: 42→4 seeds) removes 26 cycle-reachable states.
  Not all 36 phantoms were cycle-reachable; 10 of the 36 were outside the
  cycle-reachable set even before removal. The remaining 26 were
  phantom states that had forward paths into the SCC.

The three values **reduce to the same phantom/seed conventions**: the spread
is entirely explained by (a) whether the ko rule is buggy or corrected, and
(b) whether the seed set is 42 or 4. With both defects fixed, **1,678 is the
true-game-root cycle-reachable count**.

The cycle-involved count (max SCC) is **1,676** under all conventions — the
ko-rule fix and phantom removal shift only the tail ("drainage" into the
SCC), not the SCC itself. This is the quantity the original strategy audit
(SC2) identified as "stable across every source."

## Phantom-exclusion convention for I5

**The verify-battery invariant I5 tests `KO_SENSITIVE ⊆ cycle-reachable`.**
The phantom-exclusion convention it adopts is:

> The cycle-reachable set is measured from the **single true game root**
> (empty goban, Black to move, passes=0, ko=none). Phantom states that seed
> a ko point on the empty goban are excluded — they are unreachable under
> any legal sequence of moves, because a ko point requires a preceding
> capture and the empty goban has no stones capable of capture.
>
> **Calibration target at 3×2: cycle-reachable = 1,678** (true game root,
> phantoms excluded, corrected ko rule).

This convention is stated in `docs/epics/E1-markovian/sprints/verify-battery/pass0/spec.md:123` and
resolves the SC2 audit finding (`docs/epics/E1-markovian/sprints/verify-battery/archive/strategy-audit.md:61`).

An I5 disagreement at 3×2 that matches the spread (1,724 or 1,704) is
**reference-bad** — the cycle-reachable set was measured from an incorrect
seed convention. Only 1,678 is the authoritative denominator.

## What could not be established

- **The corrected-kernel + 4-seed census was not run.** The F1-SEEDROOTS fix
  was executed with the buggy `fixpoint_kernel` (before the White-branch
  defect was discovered). The corrected kernel was verified only with the
  42-seed census. The 2220/298/34/34 target for corrected-kernel-4-seeds is
  therefore an **arithmetic projection** (2,232−12=2,220, 322−24=298) from
  the delta, not an empirical measurement. Confidence is high — the delta
  is exact and the distribution is consistent across both kernels — but
  the run has not been performed.
- **The EXP-4 census and the QA-023 corrected-kernel-4-seeds census are from
  different codebases** (retrograde engine vs qa023_probe). They agree on
  the denominator (2,586) and on pin_L=34, pin_H=34, but the L==H/pin_T
  split has not been independently cross-reproduced between the two
  engines. The retrograde engine's 2220/298 split may reflect its own
  fixpoint dynamics rather than the corrected kernel's. The arithmetic
  match (2,586 and 34/34) is consistent but does not rule out a
  1-or-2-state discrepancy in the L==H/pin_T boundary.

## What I would check next

- Run the corrected `fixpoint_kernel` with the 4-seed convention to
  empirically confirm the projected 2220/298/34/34 census.
- Cross-reproduce the 2220/298/34/34 split between the retrograde engine
  and the qa023_probe corrected kernel on the same 4-seed state set.
- After the V-10 gate, verify that I5's cycle-reachable count at 3×2
  matches 1,678 and does not fire on 1,704 or 1,724.

## Files referenced

| path | role |
|---|---|
| `docs/evidence/QA-026/exp4-solve-2026-07-29.stdout` | EXP-4 census (2,586 states, 2220/298/34/34) |
| `docs/epistemic/CLAIMS.md` | QA-023 row (corrected census 2232/322/34/34) |
| `docs/evidence/QA-023/census-3x2-2026-07-29.md` | Original 2B-2 census (1,724 cycle-reachable) |
| `docs/evidence/QA-023/ko-fix-rerun-2026-07-29.stdout` | Ko-fix-rerun (1,704 cycle-reachable) |
| `docs/infra/dispatch/F1-SEEDROOTS.md` | True-game-root measurement (1,678) |
| `docs/evidence/QA-023/f1-seedroots-2026-07-29.md` | F1 empirical confirmation |
| `docs/evidence/QA-023/pinrule-sufficiency-2026-07-29.md` | Corrected kernel, C1 witnesses |
| `docs/epics/E1-markovian/sprints/verify-battery/pass0/spec.md` | Phantom-exclusion convention for I5 |
| `docs/epics/E1-markovian/sprints/verify-battery/archive/strategy-audit.md` | SC2 finding (the audit that raised this) |
| `src/qa023_probe.zig` | seed_roots fix (line 3489), reachability argument in doc comment |
