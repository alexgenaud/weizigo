<!--managent set=D-->
# T129 — re-register the EXP-7 4×4 re-run

**Type:** BUILD · **Needs:** T126 (the artifact's provenance must exist first)

## Why this task exists

`EXP-7` was marked **failed** and was purged from the kanban by T120 along with
the completed tasks. Its work is not done and its brief already exists:

> **`docs/infra/dispatch/EXP-7-4x4-rerun.md`** — written by T116, ready since
> 2026-07-30.

Purging a failed task removes the *record*, not the *obligation*. This re-entry
is the obligation.

## The history, so it is not repeated

EXP-7 was marked done having tested **only at 3×3**. The 4×4 arm could not run
because EXP-6 closed without writing its `.wzo` — `exp6_solve.zig` had no save
code and the runner SIGTERM'd at 30 minutes — and the Orchestrator absorbed the
commit message rather than checking the disk. T113 has since written the
artifact:

```
data/oracle-4x4-basicko-tie-area.wzo   258,280,358 bytes
edd9f68ef243f67de21152432f9e8f521536317527d425208e6901f90b11c0cc
```

**Verify that file's digest against T126's `SHA256SUMS` before you start.** If
it does not match, stop — that is a bigger finding than EXP-7.

## Task

Follow `docs/infra/dispatch/EXP-7-4x4-rerun.md`. Two constraints on top of it:

1. **All builds through `tools/runner`.** No unguarded `zig run`. The 2026-07-29
   kernel panic came from an unguarded 12.5 GB Debug compile.
2. **Do not report a partial run as complete.** If the budget is exhausted,
   report exhaustion with what was covered. That is a useful result; a
   completion claim covering 3×3 only is not.

## Acceptance

State the census at 4×4 with its denominator, or state that the run did not
finish and what it reached. Either is acceptable. Silence about which one
happened is not.

## Deliverable

Per the T116 brief, plus a PROVENANCE recording the artifact digest the run
actually consumed.
