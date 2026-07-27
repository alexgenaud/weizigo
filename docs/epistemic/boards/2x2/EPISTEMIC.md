# 2×2 epistemic tree

**Status:** tiny board, fully solved. Used as tooling validation, not Go knowledge.

## Claims

| Claim | Status | Evidence |
|---|---|---|
| C1 — fresh-start correct | **PROVEN** | History-aware exact solver match; byte-identical repro (B07-S3) |
| C2 — L==H history-independent | **N/A** | No non-trivial PSK histories exist on 2×2 (T12) |
| C3 — [L,H] bounds real PSK score | **N/A** | Cannot test — 2×2 has no reachable non-root cycles |
| Colex addressing | **PROVEN** | Exhaustive round-trip |
| Benson-alive | **PROVEN** | Trivial — all positions ≤4 stones |

## Artifacts

- `artifacts/oracle-2x2.wzo` — writes-off, C1 proven, 518 bytes
- Brackets only for ko-sensitive (all trivial)
