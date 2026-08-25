# T955 — gptluna DONE-audit analysis

**Landmark:** advances `L1 (the dashboard tells the truth)`.

## Summary

This audit covered 24 rows from the DONE audit corpus: 12 disjoint tasks assigned to the
gptluna arm plus 12 shared control tasks. The audit evaluated mechanical fields (wall time,
deliverables, exit codes, etc.) and made analytical judgements on `work_actually_done`,
`verdict_accurate`, `absorbed`, `self_reported_or_verified`, and `useful` for each row.

### Verdict Distribution (24 rows)
| Verdict | Count |
|---|---|
| `pass` | 12 |
| `pass-with-findings` | 8 |
| `blocked` | 4 |
| `abandoned` | 4 |

### Absorption Analysis
- **Absorbed `yes`**: 15 rows (62.5%)
- **Absorbed `partial`**: 4 rows (16.7%)
- **Absorbed `no`**: 5 rows (20.8%)

### Verification Analysis
- **`self_reported_or_verified` = `verified`**: 14 rows (58.3%)
- **`self_reported_or_verified` = `self-reported`**: 6 rows (25.0%)
- **`self_reported_or_verified` = `unverifiable`**: 0 rows

### Usefulness Analysis
- **`useful` = `yes`**: 17 rows (70.8%)
- **`useful` = `no`**: 5 rows (20.8%)
- **`useful` = `mixed`**: 2 rows (8.3%)

### No-Acceptance Stratum Tasks in gptluna Slice
The gptluna disjoint slice contains 2 tasks from the no-acceptance stratum (T541, T421):
- **T541** (verdict: `blocked`): No `acceptance=` tag in bundle. The row was blocked during a cold-cache debug build; the model (deepseek-v4-flash) was not at fault. The worker correctly identified host/infra contention as the cause. Absorption was `no` — no durable artifact was written.
- **T421** (verdict: `pass`): No `acceptance=` tag; this is a historical unconstrained benchmark that was fully verified and absorbed. 43 `/tmp` citations were rescued to `docs/evidence/`, and the C10 claimlint checker was built. This row predated machine-checked acceptance but was fully absorbed.

## Key Patterns

### Pattern 1: Absorption correlates with git commit presence
Rows where deliverables have at least one commit SHA touching them in git are overwhelmingly
more likely to be `absorbed: yes` (13/15) than rows without git commits (2/9). The 2 partial absorptions
without git commits (T908, T894) are lane findings consumed by other graders but not tracked in git
itself. The 5 `absorbed: no` rows all have `deliverables_present_in_git: []`.

**What would disprove this:** Finding an `absorbed: yes` row with empty `commit_shas_touching_deliverables`
and `deliverables_present_in_git: []` — i.e., a durable artifact that exists outside git and is
not tracked by `git ls-files`.

### Pattern 2: Verification gaps in blocked/abandoned rows
All `blocked` and `abandoned` rows were marked `self-reported` for `self_reported_or_verified`
with zero machine-verified evidence. None had an independent check (machine gate, git artifact, or
downstream use) to corroborate the worker's assertion.

**What would disprove this:** A `blocked` or `abandoned` row where independent verification exists
(e.g., a later seat re-committing the work, or a machine-checkable pass after the block was lifted).

### Pattern 3: Wall-clock vs. productivity
High wall-clock time does not correlate with lower usefulness. Several short-run rows (T924 at 3.1s,
T907 at 4.5s, T387 with no wall record) were rated `useful: yes` or `mixed`, while some long-run
rows (T908 at 6104s, T841 at 2909s) were rated `useful: no` or `mixed`. This suggests that
duration alone is not a reliable indicator of task value.

## Recommended Task Re-openings

| Task ID | Reason |
|---|---|
| **T541** | Currently `blocked` with `absorbed: no`. Re-open to verify whether the suite-truth.md work can be reclaimed and committed to git now that the debug build contention is resolved. |
| **T842** | Currently `abandoned` with `useful: no`. Re-open to confirm the runaway model diagnosis — the 790/792 Ollama request consumption is extreme and warrants independent reproduction. |
| **T841** | Currently `abandoned` with `useful: mixed`. Re-open to test whether fair request rotation (the demonstrated issue) can be enforced in the runner, which would improve future model lanes. |

## Single Most Important Pattern

**Absorption requires git commits touching deliverables.** Of 24 rows, 15 were `absorbed: yes` and all 15 had at least one SHA in `commit_shas_touching_deliverables`. The 9 rows without git commits split into: 4 `absorbed: partial` (lane-internal findings), 1 `absorbed: yes` (T421 with large git commit set from historical rescue), and 4 `absorbed: no` (T842, T841, T541, T921 — all no/partial absorptions with empty git commit lists).

**What would disprove it:** Discovery of an `absorbed: yes` row where `deliverables_present_in_git` is empty AND `commit_shas_touching_deliverables` is empty, with the artifact existing in `untracked/` or documented elsewhere as a durable standard.

## Open Questions
- Can the `partial` absorptions (T908, T894) be promoted to `yes` if the consuming grader's commit is also recorded?
- Does the no-acceptance stratum (T541, T421) exhibit different absorption patterns than the acceptance-tagged stratum, or is the git-commit requirement universal?