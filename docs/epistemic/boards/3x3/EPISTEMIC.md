# 3×3 epistemic tree

**Status:** smallest square board with meaningful Go gameplay. First board where C3 was falsified.

## Claims

| Claim | Status | Evidence |
|---|---|---|
| C1 — fresh-start correct | **CLAIMED** | Anchors match (Hayward +9, etc.), symmetry passes, but no exhaustive exact-solver ground truth. Not yet writes-off regen. |
| C2 — L==H history-independent | **UNKNOWN at 3×3** | Falsified at 3×2 (T13), but per-board independence applies. No 3×3 C2 probe run. |
| C3 — [L,H] bounds real PSK score | **FALSE-AS-SCOPED** | E2 (B06): 50/8000 leaks, max 12 pts. Promise +3 → final −9. |
| Colex addressing | **PROVEN** | Exhaustive round-trip |
| Benson-alive | **PROVEN** | Exhaustive falsification-confirmed |
| L fixpoint least-ness | **PROVEN** | Knaster-Tarski (B1): zero V0+V1 violations |

## Artifacts

- `artifacts/oracle-3x3.wzo` — `memo_writes=ON` (buggy path). C1 CLAIMED. 115 KB.
- Bracket: empty 3×3 = [2, 9] (22 wide). Published PSK anchor = +9 ✓ in-bracket.
- Ko-sensitive: 8,698 slots. No multi-ko (B23: 0% 2-ko+).
- Single-ko solver (B32): byte-identical to full finisher on 3×3.

## Open

- C1 at 3×3 needs writes-off regen + exact-solver ground truth
- C2 at 3×3 untested (per-board independence)
