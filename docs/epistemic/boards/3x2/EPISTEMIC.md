# 3×2 epistemic tree

**Status:** smallest goban with non-trivial PSK histories. First goban where C2 was falsified.

## Claims

| Claim | Status | Evidence |
|---|---|---|
| C1 — fresh-start correct | **PROVEN** | History-aware exact solver match; byte-identical repro (B07-S3) |
| C2 — L==H history-independent | **FALSE-AS-SCOPED** | T13 (2026-07-26): 12/508 mismatches under reachable PSK histories |
| C3 — [L,H] bounds real PSK score | **SUPPORTED on explored lines** | E2: 0/4000 leaks |
| Colex addressing | **PROVEN** | Exhaustive round-trip |
| Benson-alive | **PROVEN** | Exhaustive falsification |

## Artifacts

- `artifacts/oracle-3x2.wzo` — writes-off, C1 proven, 4 KB
- Bracket: empty 3×2 = [-6, 6]
- Ko-sensitive: 378 slots (38.65% of 978 legal)
