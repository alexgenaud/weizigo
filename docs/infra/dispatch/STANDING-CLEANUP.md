<!--managent set=H-->
# STANDING-CLEANUP — absorption and cleanup pass

Auto-registered standing task. Trigger: working tree dirty across two consecutive turns.

## Task

Absorb all pending changes into durable docs:
- Commit or absorb findings into `CLAIMS.md`, `PROGRESS.md`, `model-perf.md`
  (the resume surface needs no absorbing — `bin/managent resume` derives it at read time)
- Clean up stale artifacts
- Ensure `tasks.json` is consistent with reality
- Run `bin/weizigo-claimlint` and ensure it passes

## Deliverable

Clean working tree. Each absorbed finding cited in its destination doc.
