# Step 6 census — hardcoded assertions in priority docs

**Date:** 2026-08-19 · **Task:** T495 (correction sprint, step 6)

The operator asked: *"We seem to be hardcoding many assertions that will
obviously become stale. Can we prevent these silly assertions from being
written at all?"* Per step 6 of the brief, this is the **census** for the
priority files agents read on startup; no edits made here.

## Sweep

Files inspected (AGENTS.md, ORCHESTRATOR.md, DELEGATOR.md, DELEGATEE.md,
INTENT.md, README.md, status/decision docs). Findings:

| file | hardcoded count or assertion | re-point or leave |
|---|---|---|
| `docs/INTENT.md` | none | — |
| `AGENTS.md` | none in prose; `claimlint C10 VOLATILE` is named, not the count | — |
| `docs/infra/roles/ORCHESTRATOR.md` | none | — |
| `docs/infra/delegation/DELEGATOR.md` | none | — |
| `docs/infra/delegation/DELEGATEE.md` | none | — |
| `docs/infra/agents/subdelegation.md` | one historical "19/19 tests passing" in a worker finding note (line 276) | leave — finding note, not a held claim |
| `docs/status/orcha-decisions-2026-08-19.md` | none — every count is a one-shot measurement in the alternatives | — |
| `docs/status/handover-orcha-flash-2026-08-19.md` | point-in-time scorecard numbers (24/34 = 71%, 33/53 = 62%) | leave — scorecard is a snapshot by construction; the correction note added in T495 step 4 names any future staleness |

## Already re-pointed in T495

- `docs/epistemic/CLAIMS.md:213-216` — "274 rows" → re-point at claimlint (rows parsed). Done in T495 step 5.
- `docs/infra/suite-truth.md:120,141` — "228 rows" → re-point at claimlint. Done in T495 step 5.
- `docs/infra/absorption-spec.md` — the spec is its own dated-correctness note; it already names the failure mode and re-points. Leave as-is.

## Files outside the priority set, by design

Per the brief, "do not chase every number in every doc":

- `docs/audits/2026-08-05-handover/LANDMARKS.md` — historical handover doc; counts are dated.
- `docs/status/archive/handovers/*` — historical handovers; counts are dated.
- `docs/evidence/*/PROVENANCE.md` — measurement provenance; counts are the proof, must be held.
- `findings/<id>-*.json` — per-task findings; counts are the proof, must be held.

## The rule for the future (already in `docs/INTENT.md`)

*"A number a tool already prints is not held in prose; the prose re-points at
the tool."* This sprint's census found no priority file still violating that
rule that is in scope to edit. Future sprints should hold the rule at
write-time, not patch it after the fact.
