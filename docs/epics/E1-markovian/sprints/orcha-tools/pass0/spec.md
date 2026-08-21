# Orcha-tools — managent improvements for Orchestrator reliability

Revision: 1 · Status: PROPOSED · Tier: task (D-9 ladder)

## Requirements

| ID | Requirement |
|---|---|
| R1 | `managent suggest <slug>` prints next available T-ID, creates `untracked/T<id>-<slug>.md` bundle, outputs formatted prompt line: `You are <model>/T<id>. ...` |
| R2 | `managent done <id>` verifies declared deliverables exist on disk before closing. Refuses with message if missing. |
| R3 | `managent audit` flags done tasks whose deliverable paths are not cited in CLAIMS.md or PROGRESS.md |

## Acceptance

- A1: `managent suggest my-task` → prints T-ID, file created, prompt line on stdout
- A2: `managent done <id>` with missing deliverable → exits non-zero, task stays in_progress
- A3: `managent audit` finds T129's QA-027 finding not cited in PROGRESS.md → flags it
