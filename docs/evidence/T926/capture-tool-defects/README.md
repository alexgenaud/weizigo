# T926 — capture tool defects (minimax-m3, 2026-08-25)

The three defects in `tools/goban-scaling-capture.sh` (T914, written
2026-08-25) fixed by T926, with the regression that guards them.

## Files

- `capture-fixed-post-T926.sh` — copy of the live
  `tools/goban-scaling-capture.sh` after the T926 fix (tree-RSS walker,
  EXIT-trap that always appends, regime-observed from RETRO_SOUND).
- `capture-broken-pre-T926.sh` — the pre-T926 shape, reconstructed
  by hand from the brief.  Used to confirm the regression is
  red-first: all four arms exit 1 on this script.
- `regression-red-first.log` — the regression run against
  `capture-broken-pre-T926.sh`.  All four arms fail with the exact
  defect symptoms.  Exit code: 1.
- `regression-green.log` — the regression run against
  `capture-fixed-post-T926.sh` (the live script).  All four arms
  pass.  Exit code: 0.

## Red-first summary

| arm | pre-T926 | post-T926 |
|---|---|---|
| A null (clean child) | PASS (row shape correct) | PASS |
| B tree RSS (parent+grandchild) | FAIL: peak=309 MB (only the parent) | PASS: peak=612 MB (parent+grandchild) |
| C killed run (SIGKILL) | FAIL: no row at all | PASS: rc=137, killed_by=signal, partial=true |
| D regime mismatch (claim writes-off, no RETRO_SOUND) | FAIL: KeyError on `regime_claimed` | PASS: regime_observed=memo-reuse, mismatch=true, stderr warns |
| **exit code** | **1** | **0** |

## Sibling evidence (oxalpha's T926 attempt, NOT this worker)

The parent `docs/evidence/T926/` directory carries oxalpha's
T926 lane-death evidence: `README.md`, `lane-death.log`,
`run-record.json`.  That was oxalpha's B4 analysis of the
T926 task having no claim/done recorded before this worker
(minimax-m3) took over the row.  Read together with the
`capture-tool-defects/` subdir it tells the lane-history:
oxalpha died at 37.4 s with no claim (429s upstream),
minimax-m3 was re-dispatched and the work completed.
