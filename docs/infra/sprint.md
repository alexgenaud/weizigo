# Sprint — RETIRED 2026-07-28 (tool-building rules kept below)

The sprint machinery — three ratified checkpoints (spec / strategy / acceptance), the
pass0-directory layout, the per-phase files (`scope.md`, `design.md`, `plan.md`, `build.md`,
`test.md`) and the audit-gate relay — is retired. Its live equivalents:
**`docs/infra/delegation/DELEGATOR.md`** (the nine-line brief header: acceptance, calibration,
named reviewer, evidence path) and **`docs/infra/delegation/DELEGATEE.md`** (execution and
reporting). The one sprint that used this file, `managent`, is specified in
`docs/infra/managent/spec.md`.

Two things below are documented **only here**.

## Engineering rules for a standalone tool (`bin/weizigo-*`)

1. **One state file.** If the tool needs mutable state, use a single JSON file under
   `untracked/<project>/`. Never write to `docs/`, `src/` (except the tool's own sources),
   `data/`, or `artifacts/`.
2. **Callable from anywhere.** The tool discovers its project root (walk up looking for `.git`)
   and resolves relative paths from there.
3. **Concurrency-safe.** `flock` any state file; multiple shells may invoke it at once. No
   corruption, no races.
4. **Independent.** A standalone binary that does not import unrelated project modules.
5. **Shallow interface.** Few commands, few flags. Prefer parsing structured metadata from input
   files over many CLI flags; if in doubt, collapse two flags into one smarter behaviour.

## Audit-finding grades

An auditor grades each finding **blocker / critical / must / should / could** and returns a
verdict of **PASS / NEEDS-FIX / REDO**. The auditor must be a fresh session with no shared
context (see `DELEGATOR.md` rule 5 — give the reviewer less than you gave the worker).
