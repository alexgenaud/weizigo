# Argus checklist registry

```
registry_version: "1.0.0"
updated: "2026-08-01T04:00:00Z"
updated_by: "20260801T040000Z-checklist"
```

## Growth rule (R11)

A slug is added only after the issue has recurred, with both instances cited.
One occurrence is a task for Orcha, not a checklist item.

## Slugs

| slug | check | baseline | baseline_date | baseline_run | grade | first_seen | citations |
|---|---|---|---|---|---|---|---|
| stale-in-progress | `bin/managent liveness` + `bin/managent status` — count in_progress tasks | 0 tasks in_progress | 2026-08-01 | `20260801T040000Z-checklist` | must | 2026-07-31 | spec §4; 067-dabir-to-orchestrator.md |
| artifact-loadable | `bin/weizigo-oracle <path>` each .wzo under artifacts/ and data/ | 7 artifacts checked, all pass | 2026-08-01 | `20260801T040000Z-checklist` | critical | 2026-07-31 | spec §4 |
| orphan-gate | `bin/managent audit` — record exit code and finding count | exit=0, findings=1 | 2026-08-01 | `20260801T105502Z-checklist` | must | 2026-07-31 | spec §4; T211 re-baseline (T211 in_progress, no heartbeat — known self) |
| ephemera-creep | `du -sh untracked/` + files >10 MB not SHA256SUMS-pinned | 989M, 3 >10MB (all SHA256SUMS-pinned: oracle-v2/oracle-4x4-v2.wzo2 494MB, writesoff-bracket.wzo 246MB, writesoff-checkpoint.wzo 246MB) | 2026-08-01 | `20260801T105502Z-checklist` | should | 2026-07-31 | spec §4; T211 retention rule (SHA256SUMS-pinned artifacts exempt); all large files now pinned |
