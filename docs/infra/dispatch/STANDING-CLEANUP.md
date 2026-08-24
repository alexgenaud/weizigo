<!--managent set=H type=infra-->
# STANDING-CLEANUP — absorption and cleanup pass

**Landmark:** advances `L4 (the ledger is clean)` — standing cleanup keeps the working tree clean and the resume surface honest; the floor must match what claimlint actually sees.

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
