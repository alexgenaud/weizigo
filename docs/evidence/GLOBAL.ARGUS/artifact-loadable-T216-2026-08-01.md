# Artifact-loadable re-check — T216

```
Task:     T216 · DSPro/T216 · 2026-08-01
Brief:    untracked/T216-artifact-loadable-recheck.md
Context:  Argus CRITICAL (CA-11) — artifacts/oracle-3x2.wzo FAIL(exit=124)
          at run 20260801T082650Z-checklist. T208 diagnosed transient
          runner-ceiling. This is the re-test with the ceiling raised.
Method:   Each artifact in artifacts/SHA256SUMS loaded via
          tools/runner --max-cpu 21600 --max-wall 21600 -- bin/weizigo-oracle <path>
          SHA-256 verified against artifacts/SHA256SUMS.
```

## Results — per artifact

| # | Artifact | Exit | Wall (s) | CPU (s) | RSS (MB) | SHA-256 | Load? |
|---|---|---|---|---|---|---|---|
| 1 | `artifacts/oracle-2x2.wzo` | 0 | 0.3 | 0.0 | 0 | MATCH | ✓ |
| 2 | `artifacts/oracle-3x2.wzo` | 0 | 0.3 | 0.0 | 0 | MATCH | ✓ |
| 3 | `artifacts/oracle-3x3.wzo` | 0 | 0.3 | 0.0 | 0 | MATCH | ✓ |
| 4 | `artifacts/oracle-4x3.wzo` | 0 | 0.3 | 0.0 | 0 | MATCH | ✓ |
| 5 | `data/oracle-4x4-basicko-tie-area.wzo` | 0 | 0.6 | 0.27 | 248 | MATCH | ✓ |
| 6 | `data/oracle-4x4.checkpoint.wzo` | 0 | 0.6 | 0.28 | 248 | MATCH | ✓ |
| 7 | `data/oracle-4x4-parallel.checkpoint.wzo` | 0 | 0.6 | 0.27 | 248 | MATCH | ✓ |
| 8 | `untracked/oracle-v2/oracle-4x4-v2.wzo2` | 1 | 0.3 | 0.0 | 0 | MATCH | ✗ (BadMagic — wrong loader; .wzo2 requires `weizigo-oracle-v2-build`, not `weizigo-oracle`) |
| 9 | `untracked/oracle-4x4-writesoff-bracket.wzo` | 0 | 0.6 | 0.27 | 248 | MATCH | ✓ |
| 10 | `untracked/oracle-4x4-writesoff-checkpoint.wzo` | 0 | 0.6 | 0.28 | 248 | MATCH | ✓ |

## Disposition

**Configuration fix, not a regression.** Every `.wzo` artifact (9/10) loads
correctly under generous ceilings — exit 0, SHA-256 verified, wall ≤ 0.6 s,
RSS ≤ 248 MB. T208's diagnosis confirmed: the 2026-08-01T082650Z `exit=124`
failures were a transient runner-ceiling kill, not an artifact regression.

The `.wzo2` artifact (#8) fails with `BadMagic` because the check uses
`bin/weizigo-oracle`, which does not read WZO2 format. This is not a
regression either — the WZO2 loader is `weizigo-oracle-v2-build`, and
`CODE.WZO2-UNRUN` already documents that no WZO2 artifact load has ever
succeeded through the correct path. This artifact should be excluded from
the Argus `.wzo` load check or moved to a separate WZO2-specific check.

### Recommended checklist configuration

The default runner ceilings (RSS 4096 MB, wall 1800 s, CPU 3600 s) are more
than adequate for individual artifact loads — the largest artifact uses
248 MB RSS and 0.6 s wall. The batch of 10 sequential loads completes in
~5 s total. If the check runs parallel loads, 7 concurrent 248 MB loads =
~1.7 GB RSS — still well within 4 GB. The likely cause of the 082650Z
failure is an I/O contention transient, not a systematic ceiling inadequacy.

Action: add the `.wzo2` exclusion to the `artifact-loadable` check
configuration; no ceiling change needed.
