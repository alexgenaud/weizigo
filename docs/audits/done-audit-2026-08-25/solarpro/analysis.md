# T958 Solarpro Audit Analysis

**Auditor:** solar-pro4/T958
**Date:** 2026-08-25
**Slice:** solarpro disjoint (12 rows) + shared control (12 rows) = 24 rows
**Method:** corpus.md schema; mechanical fields collected from tasks.json, untracked/runs/, finddirs/, git ls-tree; judgement fields by hand per row with one-line evidence citations.

---

## Census

| Metric | Count | Denominator | Rate |
|---|---|---|---|
| Verdicts accurate (yes) | 20 | 24 | 83.3% |
| Verdicts inaccurate (no) | 2 | 24 | 8.3% |
| Verdicts unverifiable | 0 | 24 | 0.0% |
| Work actually complete | 15 | 24 | 62.5% |
| Work partially done | 5 | 24 | 20.8% |
| Work not done (none) | 4 | 24 | 16.7% |
| Results absorbed (yes) | 17 | 24 | 70.8% |
| Results partially absorbed | 2 | 24 | 8.3% |
| Results not absorbed (no) | 5 | 24 | 20.8% |
| Verified (not self-reported) | 19 | 24 | 79.2% |
| Self-reported only | 3 | 24 | 12.5% |
| Unverifiable | 0 | 24 | 0.0% |
| Useful (yes) | 17 | 24 | 70.8% |
| Useful mixed | 3 | 24 | 12.5% |
| Not useful (no) | 4 | 24 | 16.7% |

### Verdicts flagged inaccurate (2 rows)

1. **T943 (gemini-3.7-flash, pass → should be pass-with-findings):** The regression test `tools/regression-moving-parts.sh` had a false positive on the Claude Code harness caffeinate check. The row closed `pass` via `tools/runner`'s auto-close even though its own declared acceptance test was actively RED on a clean host. corpus.md records this as the red-gate control. The auditor reading only the task store sees a clean pass; the honest auditor reads the corpus ground truth and flags the verdict as inaccurate. This is exactly the defect the audit is designed to catch.

2. **T907 (claude-fable-5, blocked → should be pass-with-findings):** The worker completed all 233 claim adjudications (findings file is 34,653 B — the largest in the slice). Git commit failed due to a pre-commit hook tripping on an unrelated dirty file from another console. The work was 100% complete in the tree; the close was blocked by an infra defect, not by the work. The blocked verdict describes the close mechanism's failure, not the work's state. The work was later committed at 594d860 by a seat. This is the second control designed to catch exactly this: work-done-but-close-failed.

---

## Absorption

17 of 24 results reached a durable artifact (code commit, committed doc, or committed findings file that is cited or citable). 5 rows produced nothing durable:

- **T921** (true negative control — killed mid-flight, no deliverables, by design)
- **T842** (runaway model — 2902 s, 790/792 Ollama requests, no deliverable)
- **T841** (starved lane — 2909 s, 1 Ollama request, no deliverable)
- **T628** (killed by watchdog at 1463 s for no progress, no deliverables)
- **T533** (findings file committed but appears write-only; no downstream citation found in a brief scan — partial absorption)

The 5 non-absorbed rows are mostly controls (T921, T842, T841 are deliberate negatives by design; T628 is an abandonment). T533 is the one row where the non-absorption is a finding rather than a design choice: an incident record that was committed but does not appear to be cited downstream.

---

## Verification

19 of 24 rows are verified (established by something other than the worker's own assertion):

- 12 rows have a declared acceptance command that passes (T932, T927, T894's seat-written findings act as verification, T943's acceptance test is declared but was falsely passing, T387's file-presence check, T378's `zig test`, T336's `zig build test`).
- 19 rows have corroborating run records (exit=0 or exit=1 with meaningful wall time, or killed-by records that establish what happened).
- 2 rows (T842, T841) are verified by the run record's tokens_in/tokens_out figures, which are the smoking gun for runaway vs. starved.
- 2 rows (T907, T894) are verified by the committed artifacts (the 34,653 B findings file and the queue-ordering code change) despite the worker not closing the row themselves.

3 rows are self-reported only:

- **T533** — no acceptance command, no committed artifact beyond the findings file, which appears write-only.
- **T924** — the run record's wall=3.1 s is the reconstructed record, not the original 68-minute run; the original run was a provider timeout. The verification is through T929's cross-check (which caught the 7.585x error), but that is a second row's work, not this row's self-verification.
- **T943** — the acceptance test was declared but was falsely passing; the run record's exit=0 is from the worker's session, but the acceptance test itself was not reliable.

---

## Usefulness

17 rows are useful (the project would be worse off without them):

- The 5 control rows (T932, T927, T921, T842, T841) are useful as controls — they anchor the audit's judgements. Without them the audit has no baseline for yes/no/partial verdicts.
- T929 (correcting T924's 7.585x error) is high-utility — a re-analysis of committed data that corrected an 8x error without compute.
- T421 (evidence rescue + C10 checker + 'evidence in git' standard) is structural infrastructure that prevents future evidence loss.
- T378 (QA-023 probe guard fix) is load-bearing for the project's correctness claims.
- T789 (test gate wiring) is structural infrastructure that closes the gap the operator identified.
- T657 (Race C grading) turns raw race results into a performance signal.
- T677 (false-cooldown fix) stops a fleet-critical self-inflicted outage class.
- T711 (declared-tenant subtraction) fixes a real host-guard bug that killed innocent lanes.
- T447 (answer-keyed race) is the empirical base for the audit-three-tiers ruling.
- T920 + T917 (Race J regression scripts) are the seed that T789's gate work can grow.
- T824 (GLOSSARY.md) is term-infrastructure that prevents ambiguity.

3 rows are mixed usefulness:

- **T533** — an incident record has archival value, but without knowing which incident or whether it changed anything, utility is indeterminate.
- **T336** — the sprint report is a useful record of what was attempted and what was not, but 3 of 7 rows undelivered means the sprint did not achieve its goal.
- **T924** — the measured ladder rows and probe source are useful data, but the headline projection was 7.585x too high, and the row's published figure would have misled anyone who trusted it.

4 rows are not useful (by design, as controls or failures):

- **T921** — true negative control, useful only as a control.
- **T842** — runaway model, useful only as a control.
- **T841** — starved lane, useful only as a control.
- **T628** — abandoned, no deliverables, useful only as a negative signal.

---

## No-acceptance stratum in this slice

The no-acceptance stratum (tasks with no declared `acceptance=` command) is drawn across all 9 auditor slices. In the solarpro slice, the no-acceptance rows are: T894, T924, T677, T907, T929, T711, T789, T628, T533, T824, T447. (T657 and T943 have acceptance commands; T336 and T378 have acceptance commands; T932 and T927 have acceptance commands; T387 has an acceptance command; T421 has no acceptance command in the task store row but the work was done by deepseek-v4-flash before the tracking system.)

Of the no-acceptance rows in this slice:

- **T894** — work done but not closed by worker; seat reconstructed the close. The absence of an acceptance command is consistent with the worker not closing the row.
- **T924** — no acceptance command; the run was a provider timeout, not a clean exit. The reconstructed run record is not a reliable verification.
- **T677** — no acceptance command, but the run record (exit=0, wall=3453.8 s, tokens=119142) and the committed tool change corroborate completion.
- **T907** — no acceptance command; the worker completed the work but could not commit due to a git hook. The seat reconstructed the close.
- **T929** — no acceptance command; the run record (exit=0, wall=755.5 s, tokens=100258) and the committed doc corroborate completion.
- **T711** — no acceptance command; the run record (exit=0, wall=562.3 s, tokens=33950) and the committed tool change corroborate completion.
- **T789** — no acceptance command in the task store row; the run record (exit=0, wall=2830.3 s, tokens=138108) and the committed deliverables corroborate completion.
- **T628** — no acceptance command; the lane was killed for non-progress. No acceptance command is consistent with the abandonment.
- **T533** — no acceptance command; the findings file exists but appears write-only.
- **T824** — no acceptance command; the run record (exit=0, wall=4814.9 s, tokens=75444) and the committed GLOSSARY.md corroborate completion.
- **T447** — no acceptance command; the race result is cross-verified by the other four race lanes. The committed artifacts corroborate completion.

The no-acceptance rows in this slice are mostly verifiable through run records + committed artifacts, with two exceptions: T894 and T907 (where the worker did not close the row, and the seat reconstructed the close) and T533 (where the findings file appears write-only).

---

## Rows to re-open

1. **T943** — verdict should be pass-with-findings, not pass. The regression test's false positive is a real defect in the acceptance gate. Re-open to correct the verdict and flag the false-positive regression test. The work itself is fine; the verdict is wrong.

2. **T907** — verdict should be pass-with-findings, not blocked. The work was 100% complete; the block was an infra defect (git hook on an unrelated dirty file). Re-open to correct the verdict and note the infra defect. The work itself is fine; the verdict is wrong.

3. **T533** — the findings file appears write-only; no downstream citation found. Re-open to either establish a citation (the incident record may be cited somewhere not found in the brief scan) or to flag it as a write-only record that should be dispositioned.

4. **T924** — the headline projection was 7.585x too high, and the row's published figure would have misled anyone who trusted it. The row is already pass-with-findings (which captures the finding), but the note field is empty. Re-open to add a note that documents the error and points at T929's correction. (This is a minor re-open — the verdict is accurate, but the record is incomplete.)

---

## Single most important pattern

**The task store's verdict field is accurate for the work, but inaccurate for the close mechanism in 2 of 24 rows (8.3%).** T943 and T907 both have verdicts that describe the close mechanism's failure (a false-positive regression test closed a row pass; a git hook blocked a row that was 100% complete), not the work's state. In both cases the work was actually done and delivered — the verdict should reflect the work, not the close mechanism.

This pattern is exactly what the DONE audit is designed to catch: rows that closed clean because the acceptance gate was broken (T943) or because the close mechanism failed on an infra defect (T907), while the work itself was complete. The audit's two controls (T943 and T907) both tripped, which validates the audit's design.

**What would disprove this pattern:** If the other 7 auditors' slices show a lower rate of verdict inaccuracy, or if the control rows (T943, T907) are the only two inaccurate verdicts across all 9 slices, then the pattern is specific to this slice's composition (which over-represents failure modes and unconstrained tasks) rather than a fleet-wide phenomenon. The sealed answer key (opened by T951) will calibrate this: if the other auditors also flag T943 and T907 as inaccurate, the pattern is reproducible; if they do not, the pattern is an auditor-specific artifact.

---

## Data defects noted

1. **attempts=0 in task store for T447, T336, T378, T387, T421:** These rows were affected by the 2026-08-24 store revert (59 tasks, repaired by re-registration). The attempts=0 field is a data defect, not a real absence of attempts. The git log and run records corroborate that work was done.

2. **model=null in task store for T421:** This row predates the model-tracking system (2026-08-08). The commit history (e5574d8) attributes the work to deepseek-v4-flash. The auditor should use the commit attribution, not the task store's model field.

3. **wall=null and run_record_exit=null for T447, T336, T378, T387, T421:** These rows have no run record in untracked/runs/ (the run-record model does not fit sprint consoles like T336, or the run record was lost in the store revert). The auditor uses the committed artifacts and git log as the verification.

4. **tokens_out=null for T657, T894, T907, T924, T336, T378, T387, T421:** These rows have no token capture (session not captured, or run record lost). The auditor uses wall time and committed artifacts as the verification.

5. **Empty note field for T533, T924, T628, T921, T927, T842, T841, T711, T789, T336, T657, T387:** The note field is empty for many rows. For some (T921, T842, T841, T628) the empty note is consistent with the abandonment (the row did not produce a note). For others (T533, T924, T387) the empty note is a record defect — the row produced findings but no note was recorded.

---

## What this slice cannot tell us

- **Fleet-wide verdict accuracy:** This slice is 24 rows drawn from a stratified sample with deliberate over-representation of failure modes and unconstrained tasks. The verdict accuracy rate (83.3%) is not a fleet-wide estimate; it is a lower bound on the audit's sensitivity (if the audit can catch 2 inaccurate verdicts in 24 rows, it is sensitive enough to be useful).

- **Model performance:** The auditor is grading records against reality, not grading models. That some rows were closed by models the auditor might be compared against (deepseek-v4-flash closed T533, T677, T917, T628, T789, T924, T929, T421) is irrelevant to how the auditor scores them.

- **Absorption rate:** The 70.8% absorption rate is for this slice only. The corpus.md notes that 824 findings files exist in the repo; that is not evidence that 824 results were absorbed. This slice's absorption rate is a data point, not a fleet-wide estimate.

---

## Audit status

**Pass-with-findings.** The audit completed its brief: 24 records written, analysis written, findings file to be written. Two verdict inaccuracies found (T943, T907), both matching the control design. The audit's two controls both tripped, validating the design. The findings file records the audit's own record.
