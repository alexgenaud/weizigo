# DONE Audit Analysis (gemini arm — T950)

**Auditor Arm:** `gemini` (`gemini-3.7-flash` / `T950`)  
**Date:** 2026-08-25  
**Corpus Scope:** 24 Tasks (12 Shared Control Rows + 12 Disjoint Rows)  
**Landmark:** advances `L1 (the dashboard tells the truth)`

---

## 1. Executive Summary

This audit examined 24 completed tasks in the `weizigo` repository to determine whether recorded verdicts in `docs/infra/managent/tasks.json` reflect verifiable engineering reality. The sample consists of 12 shared control tasks with calibrated ground truths and 12 disjoint tasks assigned specifically to the Gemini audit arm.

Across the 24 audited tasks:
- **Work Actually Done:** 18 Complete (75.0%), 2 Partial (8.3%), 4 None (16.7%).
- **Verdict Accuracy:** 23 Accurate (95.8%), 1 Inaccurate (4.2% — `T943`).
- **Absorption Rate:** 18 Absorbed (75.0%), 2 Partial (8.3%), 4 Not Absorbed (16.7%).
- **Verification Status:** 24 Verified (100.0%) against git history, test suites, and empirical artifacts.
- **Usefulness:** 18 Useful (75.0%), 2 Mixed (8.3%), 4 Not Useful (16.7%).

The central finding of this audit is that **automated process gates (exit 0 + deliverable presence) mask silent functional failures and broken acceptance tests**. The repository's task store recorded zero `fail-found` outcomes not because the fleet never failed, but because failure modes were routed into auto-closed passes, post-hoc orchestrator rescues, or unclassified blocks.

---

## 2. Summary Census & Stratification Breakdown

### Aggregate Metrics Table (24 Tasks)

| Dimension | Category | Control (12) | Disjoint (12) | Total (24) | Percent (%) |
|---|---|---|---|---|---|
| **Work Actually Done** | Complete | 7 | 11 | 18 | 75.0% |
| | Partial | 2 | 0 | 2 | 8.3% |
| | None | 3 | 1 | 4 | 16.7% |
| **Verdict Accuracy** | Yes (Accurate) | 11 | 12 | 23 | 95.8% |
| | No (Inaccurate) | 1 | 0 | 1 | 4.2% |
| | Unverifiable | 0 | 0 | 0 | 0.0% |
| **Durable Absorption** | Yes (Absorbed) | 7 | 11 | 18 | 75.0% |
| | Partial | 2 | 0 | 2 | 8.3% |
| | No | 3 | 1 | 4 | 16.7% |
| **Verification Basis** | Verified | 12 | 12 | 24 | 100.0% |
| | Self-Reported | 0 | 0 | 0 | 0.0% |
| | Unverifiable | 0 | 0 | 0 | 0.0% |
| **Utility** | Yes (Useful) | 7 | 11 | 18 | 75.0% |
| | Mixed | 2 | 0 | 2 | 8.3% |
| | No (Not Useful) | 3 | 1 | 4 | 16.7% |

---

## 3. Analysis of Stratum D: Unconstrained / No-Acceptance Tasks

Stratum D isolates tasks that operated without machine-checked `acceptance=` commands in their bundle headers. Two Stratum D tasks fell into the Gemini disjoint slice:

### `T462` — Backlog Triage
- **Status:** Closed `pass-with-findings`.
- **Finding:** Fully productive and verified. Triaged all 25 live dispatchable rows into exactly four buckets (5 do-now, 3 background, 8 close-with-evidence, 10 ideas), written to `docs/status/backlog-2026-08-19.md` and ideas document.
- **Significance:** Without an automated acceptance command, the worker accurately catalogued the lack of a `retire` verb in managent and identified 8 phantom tasks that had been closed in the assertion ledger but remained dispatchable in the kanban.

### `T674` — Class C Evidence Triage
- **Status:** Closed `pass-with-findings` via T716 orphan backfill.
- **Finding:** Fully complete. Evaluated 68 uncited documents under `docs/evidence/` (all 56 requested + 12 additional), delivering structured rulings (31 ABSORB, 26 REJECT, 11 EXEMPT) with detailed justifications in `findings/T674-class-c-triage.json`.
- **Significance:** Demonstrates that high-rigor analytical tasks can achieve 100% completion and durable absorption even without mechanical gates, provided downstream consumers (here, T716 claims registration) verify the output.

---

## 4. Control Slice Calibration (12 Tasks)

The control slice evaluated 12 tasks with established ground truth:

1. **`T932` (Null Control 1):** Complete pass. Implemented round-robin partition in `finishParallel` (`src/retro.zig`), verified 11.6x speedup, delivered passing regression `tools/regression-finishparallel-partition.sh` (commit `cb5a307`). Highly useful.
2. **`T927` (Null Control 2):** Complete pass. Implemented `caffeinate -i -w` sleep guard in `tools/runner` and 4-arm regression test `tools/regression-sleep-guard.sh` (commit `41182d7`). Highly useful.
3. **`T894` (Work Real, Record Absent):** Worker implemented queue-head readiness ordering in `src/managent/main.zig` and regression test, but died before closing. Orchestrator seat (T935) absorbed the work and closed `pass-with-findings` (commit `b27c7f0`). Verdict accurate to current state.
4. **`T924` (Work Real, Headline Number 7.585x Wrong):** Ran 68-minute writes-off ladder probe generating 1,354-row CSV (`docs/evidence/T924/per-root.csv`), but computed an unweighted mean that distorted solve projections by 7.585x. Closed `pass-with-findings` on valid data; mathematical flaw corrected by T929.
5. **`T921` (True Negative Control):** Process killed mid-flight during cold-cache debug build; no deliverables written. Closed `abandoned`. Verdict completely accurate.
6. **`T943` (Flawed Auto-Close / Red Gate):** Delivered moving parts inventory and regression script, but regression test failed on Claude Code harness caffeinate. Auto-closed as `pass` by `tools/runner` on process evidence despite failing acceptance. **Verdict Inaccurate** (`pass` recorded on red gate).
7. **`T842` (Runaway Model):** Minimax-m3 consumed 790/792 Ollama requests in a 5-hour window, ran 2902s with zero deliverables. Closed `abandoned`. True failure mode.
8. **`T841` (Starved Lane):** Kimi-k2.7 starved by T842 (received only 1 request), ran 2909s without output. Closed `abandoned`. Infra contention failure.
9. **`T907` (Work Complete, Hook Blocked):** Worker completed all 233 claim adjudications, but commit was blocked by pre-commit hook tripping on an unrelated dirty file. Closed `blocked`; committed by seat at `594d860`. Highly useful.
10. **`T387` (Infinite Loop under ReleaseFast):** Solver suffered 14-hour infinite loop in `src/t387_budget.zig` due to `bitpos: u6` wrapping under ReleaseFast. DAG data salvaged into `findings/T387-capture-budget-dag.json`, but Bellman readings incomplete. Closed `blocked`.
11. **`T929` (High-Utility Analytical Correction):** Re-projected 4x4.D3 tractability using layer-population weights on T924 CSV data, correcting 7.585x distortion without compute (commit `8d5d163`). Complete and highly useful.
12. **`T421` (Historical Unconstrained Benchmark):** Repointed 283 `/tmp` citations, marked 43 dead citations EVIDENCE LOST, delivered claimlint C10 VOLATILE checker (commit `e5574d8`). Complete and highly useful.

---

## 5. Disjoint Slice Evaluation (12 Tasks)

1. **`T462` (`deepseek-v4-flash` / `pass-with-findings`):** Triaged 25 dispatchable tasks into 4 clear buckets; identified 8 phantom tasks; delivered backlog doc and ideas list (commits `84daa02`, `e17210e`). Complete, accurate, absorbed, useful.
2. **`T674` (`claude-opus-5` / `pass-with-findings`):** Triaged 68 uncited evidence documents (31 ABSORB, 26 REJECT, 11 EXEMPT) in `findings/T674-class-c-triage.json`. Complete, accurate, absorbed by T716, useful.
3. **`T519` (`deepseek-v4-flash` / `pass`):** Swept and repaired stale prose in `model-perf.md`, `bakeoff.md`, and `model-task-matrix.md` (commits `e09586d`, `60f4e47`). Complete, accurate, absorbed, useful.
4. **`T746` (`claude-opus-5` / `pass`):** Recovered 448 missing token readings (ledger coverage 20% -> 53%), delivered `tools/token-backfill.py`, fixed `oxalpha` registry appetite, and queued 6 tasks (commits `4d80d8c`, `32a4190`, `47b91c0`). Complete, accurate, absorbed, highly useful.
5. **`T514` (`deepseek-v4-flash` / `pass`):** Verified keeper logjam-flag lifecycle in `tools/fleet-keeper.sh`, ran 3 regression arms, delivered findings in `28fa9fe`. Complete, accurate, absorbed, useful.
6. **`T432` (`deepseek-v4-flash` / `pass-with-findings`):** Implemented assertion semantics for console liveness in `bin/argus` (missing assertion = UNKNOWN) and updated regression suite (commit `6e0c02d`). Complete, accurate, absorbed, useful.
7. **`T548` (`deepseek-v4-pro` / `pass`):** Added child process reaping to `tools/runner` on all exit paths, implemented `--reap-orphans` sweeper, and delivered 9-arm regression test (commit `f9acfe7`). Complete, accurate, absorbed, highly useful.
8. **`T702` (`deepseek-v4-pro` / `pass`):** Root-caused 4.9 MB `bin/managent` binary to bare Debug build default, pinned default to ReleaseSafe in `build.zig`, and added regression test (commit `29a5223`). Complete, accurate, absorbed, useful.
9. **`T872` (`deepseek-v4-pro` / `pass`):** Deleted 11 dead/vacuous test scripts per green-up specification, unwired them from `build.zig`, and verified clean test suite (commits `90b5e2c`, `3568ba5`). Complete, accurate, absorbed, useful.
10. **`T488` (`deepseek-v4-pro` / `pass`):** Added findings JSON parsing and schema validation to `tools/dispatch_verify.py` with test-first regression test (commit `12041b7`). Complete, accurate, absorbed, useful.
11. **`T326` (`glm-5.2` / `pass-with-findings`):** Implemented GTP handicap commands (`set_free_handicap`, `place_free_handicap`, `fixed_handicap`) in `src/gtp.zig` with 88/88 passing tests (commit `d5de1d9`). Complete, accurate, absorbed, useful.
12. **`T361` (`unattributed` / `abandoned`):** Console died before running old vs new engine matches; zero deliverables written; superseded by T509 (commit `8c1b780`). None done, accurate, not absorbed, not useful.

---

## 6. Recommended Task Re-Openings & Follow-ups

1. **`T943` — Moving parts acceptance test failure (Closed `pass` incorrectly):**
   - *Reason:* Auto-closed on process presence despite active failure of `sh tools/regression-moving-parts.sh`. While T952 subsequently addressed the caffeinate false-positive, `T943`'s close record is formally inaccurate.
   - *Recommendation:* Amend `T943` record notes to cite the auto-close failure and link to T952 as the remediating row.
2. **`T387` — Complete capture budget Bellman consistency reading:**
   - *Reason:* `T387` established DAG termination but crashed under ReleaseFast before producing Bellman value consistency readings on small boards.
   - *Recommendation:* Ensure successor task T405 / E2 tracks the missing Bellman bounds.

---

## 7. The Single Most Important Pattern

### The Pattern: Process-Presence Gates Mask Semantic Failures
**Automated auto-close gates that evaluate only exit code 0 and deliverable presence on disk structurally fail to verify semantic correctness, allowing red test gates and corrupted calculations to register as clean passes.**

Evidence:
1. **`T943`:** `tools/runner` auto-closed the task as `pass` because all three declared deliverables existed and exit was 0, completely ignoring that its declared acceptance script `sh tools/regression-moving-parts.sh` was failing on the test host.
2. **`T924`:** Deliverable presence checks passed because `docs/research/4x4-d3-tractability.md` was created, yet the headline solve projection was mathematically distorted by a factor of 7.585x due to unweighted arithmetic.
3. **`T894`:** A worker that implemented valid code and tests but exited without calling `managent done` or writing findings would have been lost entirely if not for human/orchestrator intervention.

### What Would Disprove This Pattern
The pattern would be disproved if:
1. A randomized sample of auto-closed tasks demonstrated a 0% rate of failing declared acceptance commands and 0% rate of mathematically corrupted headline conclusions.
2. Automated deliverable-presence checks were shown to catch logic and calculation errors at the same rate as human/auditor semantic review.
