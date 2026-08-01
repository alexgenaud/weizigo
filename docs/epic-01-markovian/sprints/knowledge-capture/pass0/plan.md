# plan.md — knowledge-capture sprint build plan

Revision: 1 · Status: DRAFT · Tier: sprint · Author: DSPro/T188

## Scope

Build the mechanical scaffolding that keeps `docs/epistemic/CLAIMS.md` in sync
with subagent findings. The project has twice suffered from absorption lag:
T129 falsified QA-027 at 4×4 on 2026-07-31, evidence was committed, the
register was not — and nobody noticed until a dedicated message (msg 071)
called it out. This sprint makes that class of gap mechanically detectable
and fixes it with a tool rather than a manual protocol.

## Deliverables

| ID | What | Where | Kind |
|---|---|---|---|
| D1 | Standardized findings JSON schema | `findings/` | doc + example |
| D2 | claimlint C7 check — unabsorbed findings | `src/claimlint.zig` | code |
| D3 | Absorption tool | `src/absorb.zig` | code |
| D4 | Integration: absorption log auto-update | `src/absorb.zig` (same binary) | code |
| D5 | Calibration: T129 findings fixture | `findings/T129-qa027.json` | fixture |

## Task breakdown

### Phase 1 — findings format (D1)

- **T188-1a** Write the JSON schema. One file per task, named `<TASKID>-<slug>.json`.
  Fields: `task_id`, `date`, `model`, `claims[]` (each with `id`, `proposed_status`,
  `rationale`, `evidence_path`), `new_rows[]`, `notes`.
- **T188-1b** Create the `findings/` directory with a `README.md` documenting the
  format and expected workflow (task completes → writes findings JSON → Orchestrator
  runs absorption tool → CLAIMS.md updated).
- **T188-1c** Create the T129 calibration fixture: `findings/T129-qa027.json`.
  This is the "known-bad" — the finding that SHOULD have been absorbed but wasn't,
  and therefore MUST trip claimlint C7 when CLAIMS.md is reverted to pre-absorption
  state for calibration.

### Phase 2 — claimlint C7 (D2)

- **T188-2a** Add `checkC7(gpa, reg, findings_dir)` to `src/claimlint.zig`.
  Scans `findings/*.json`, for each file parses the claims array, looks up each
  claim ID in the register, and reports any where the register status differs from
  the proposed status.
- **T188-2b** Wire C7 into the main pipeline with exit-code impact: C7 failures
  exit non-zero (same tier as C1/C2/C6 — load-bearing checks).
- **T188-2c** Add a synthetic calibration case (like the existing C1b/C5/C6
  synthetic registers): a findings directory with a known-bad finding file that
  disagrees with a synthetic register. The check must catch it.
- **T188-2d** The C7 check treats `new_rows[]` entries as "row absent from
  register" — if a new-row claim ID is found in the register, it's still flagged
  (the finding proposed a new row but the register already has one, suggesting
  stale or duplicate work).

### Phase 3 — absorption tool (D3)

- **T188-3a** Write `src/absorb.zig` — a standalone binary that reads a findings
  JSON file and `docs/epistemic/CLAIMS.md`, computes the edits needed, and outputs
  a machine-readable diff.
- **T188-3b** The tool's output: for each claim whose register status differs,
  emit the exact `oldText`/`newText` pair for the status cell. For each new row,
  emit the complete markdown row and the insertion point (claim ID to insert
  after, or section name). Format: JSON Lines, one object per edit, so the
  Orchestrator can review (or pipe to a script).
- **T188-3c** The tool does NOT edit CLAIMS.md directly. It proposes; the
  Orchestrator ratifies. This is the mechanical-work-by-tool, judgment-by-agent
  split from R3.
- **T188-3d** Calibration: the tool must produce correct diffs for:
  1. T129/QA-027 status change (CLAIMED → FALSE-AS-SCOPED)
  2. T172/GAP-5 new-row addition (CODE.VB-BLINDGAPS)

### Phase 4 — absorption log integration (D4)

- **T188-4a** The absorption tool, on successful diff generation, appends one
  line to `untracked/absorption.md`: `<task_id> <date> <model> <claim-ids> CLAIMS:yes/no`.
  This replaces the manual logging step from msg 071; it is now a by-product
  of the tool run, not a separate action.
- **T188-4b** Add a `--dry-run` flag that generates the diff but does NOT append
  to the log. Default behaviour (no flag) appends.

## Build order and dependencies

```
Phase 1 (format) ──┐
                   ├──> Phase 2 (claimlint C7) ──> Integration test
                   │
Phase 1 (format) ──┼──> Phase 3 (absorb tool) ────> Phase 4 (log) ──> Acceptance
                   │
T129 fixture (D5) ─┘
```

Phase 1 must complete first (the format definition is the contract between all
components). Phases 2 and 3 can proceed in parallel. Phase 4 depends on 3.

## Acceptance mapping (from spec.md)

| Acceptance | How verified |
|---|---|
| A1 — T129 gap flagged by claimlint | C7 synthetic calibration: findings file + reverted CLAIMS.md → C7 reports QA-027 unabsorbed |
| A2 — Absorption tool correct diff for T172 GAP-5 | Run tool on `findings/T172-gap5.json` → diff matches the committed CLAIMS.md row for CODE.VB-BLINDGAPS |
| A3 — After absorption, claimlint exits 0 | Run claimlint on CLAIMS.md after the tool's edits are applied → C7 passes |

## Risks

- **Zig 0.16 JSON friction.** The verify-battery sprint abandoned `std.json` over
  Zig 0.16 churn (`CODE.VB-STUBS`). The findings format is simple enough (flat
  objects, no unions) that a hand-rolled parser is tractable if needed.
- **CLAIMS.md table cell precision.** claimlint already parses CLAIMS.md's
  markdown tables; C7 reuses that machinery. The absorption tool needs a
  *writer* that preserves exact formatting of surrounding rows — this is the
  harder half. A regex-based approach (match the row by claim ID, replace the
  status column) is safer than a full markdown AST.
- **Calibration without data loss.** The T129 calibration case requires showing
  C7 catches a gap. Since the real CLAIMS.md was already fixed for QA-027, the
  calibration must work against a synthetic register (as C1b/C5/C6 already do).
  This is consistent with existing claimlint practice.
