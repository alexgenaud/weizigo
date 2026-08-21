# Subagent harness — consistent dispatch, findings, and absorption

Revision: 1 · Status: PROPOSED · Tier: sprint

## Problem

Subagents spawned via `odeeppi -p` have no standard workflow. They don't claim
tasks, write findings inconsistently, and findings never reach CLAIMS.md. The
builder (T173) succeeded but left findings in ad-hoc `untracked/T*-notes.md`
files with no path to the register.

## Requirements

| ID | Requirement |
|---|---|
| R1 | **Prompt wrapper.** Every `odeeppi -p` or `oflashpi -p` dispatch auto-prepends: claim task, read brief, write findings file, done task |
| R2 | **Findings schema.** JSON, one file per task at `untracked/T<id>-findings.json`. Fields: task_id, date, claims_touched (array of IDs), proposed_status, evidence_path, model, summary (one line) |
| R3 | **Manager brief template.** Builder brief includes: task list with IDs, concurrency limit, findings collection instruction, absorption summary format, flag-gaps instruction |
| R4 | **Manager absorption handoff.** Builder writes one `untracked/absorption-<date>.json` aggregating all subagent findings. Claimlint can diff against CLAIMS.md |

## Deliverable

Three files, no code changes:
1. `docs/infra/agents/subdelegation.md` — updated with prompt wrapper, findings schema, claim/done instruction
2. `docs/infra/agents/findings-schema.json` — the machine-readable schema
3. `docs/infra/agents/manager-brief-template.md` — reusable template

## Acceptance

- A1: A subagent dispatched with the wrapper automatically claims its task and writes a findings file
- A2: The findings file passes JSON schema validation
- A3: A manager brief generates T173-equivalent coordination with standardized outputs
- A4: Existing `untracked/T169-notes.md` and `untracked/T172-blind-analysis.md` can be retrofitted to the schema by hand as proof

## Non-goals

- No `src/` code changes (no managent, no claimlint — those are knowledge-capture sprint)
- No CLI tooling (that's knowledge-capture)
- No retroactive conversion of T168-T172 findings (manual retrofit for A4 only)
