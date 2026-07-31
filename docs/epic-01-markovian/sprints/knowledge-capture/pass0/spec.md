# Knowledge capture — subagent findings → epistemic register

Revision: 1 · Status: PROPOSED · Tier: sprint

## Requirements

| ID | Requirement |
|---|---|
| R1 | Standardized findings format: one file per task, machine-readable (JSON). Fields: task ID, date, claim IDs touched, proposed status, evidence path, model. |
| R2 | claimlint check: scans findings files, reports claims not reflected in CLAIMS.md. Exits non-zero on unabsorbed findings. |
| R3 | Absorption tool: reads findings file, proposes CLAIMS.md edits, outputs diff. Orcha reviews/ratifies — mechanical work by tool, judgment by agent. |
| R4 | Absorption log (msg 071) becomes by-product of tool, not separate manual step. |

## Acceptance

- A1: T129 gap (QA-027 falsified at 4×4, register says CLAIMED) flagged by claimlint
- A2: Absorption tool generates correct CLAIMS.md diff for T172 GAP-5
- A3: After absorption, claimlint exits 0 for that task's findings
