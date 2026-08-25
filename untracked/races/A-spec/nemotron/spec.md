# T976 — Race A spec (nemotron)

**This is a sealed arm of Race A. Other models are answering this identical brief. Do not read
`untracked/races/A-spec/` outside your own directory. Yours is
`untracked/races/A-spec/nemotron/`.**

**Landmark:** advances `L2 (proven 4x4 values)` — the spec that decides whether the 4×4 run
is worth starting.

## Normative Decisions

### 1. Node cap: capped at 20,000,000 with explicit censored reporting

**Decision:** Impose a hard node cap of 20,000,000 per root. Roots that hit the cap are
reported as **censored** — the exact count and the cap value are recorded. Censored roots are
**never folded into a projected mean**. The headline result reports the closed/censored split.

**Green must (post-run):** Every root either (a) closed naturally within the cap, or (b) was
recorded as censored with its final node count and the cap value. No root's outcome is
unknown.

**Red incident caught:** A previous spec (T924) folded the censoring bound into a mean,
producing a headline 7.585× too high. The correction (T929) reweighted by population and
identified that 9.71% of roots were uncapped and carried 92.6% of measured nodes.

**Alternative considered & rejected — no cap, report all results as "unknown above cap":**
 would make the headline result uninterpretable — the entire point of the row is to measure
 the 4×4 writes-off finisher, and hiding behind "unknown" defeats that. Rejected.

**Alternative considered & rejected — fixed cap at 10M:** The brief's measured cap is 20M; 10M
would censor ~15% of roots (extrapolating from T924's 9.71% at 20M) and increase the
censored fraction's node share beyond 92.6%. Rejected — cap must be consistent with the
measurement infrastructure.

**Out of scope:** Any per-root cap higher than 20M, or any projection of "expected total nodes
above cap." The row records what is measured; unknown above cap is not estimated.

**Armed count:** 1 (one normative decision with armed green/red guard.)

### 2. Censored root reporting: split, never projected

**Decision:** The run reports **two numbers**: (a) the wall-clock time, and (b) the number of
roots closed naturally. Censored roots are counted separately and their total node count is
reported **without projection into a mean**. The closed + censored root counts sum to the
total ko-sensitive root population (10,367,922).

**Green must (post-run):** The output file records `closed_roots`, `censored_roots`,
`closed_nodes`, `censored_nodes`, and the total `ko_sensitive_roots`. The censored node
count is a raw count, not a projected mean.

**Red incident caught:** If any code path folds a censored node count into a projected mean
(like T924's 7.585× inflation), the row is invalidated.

**Alternative considered & rejected — projected mean with censoring bound:** Would repeat
the T924 error. Rejected.

**Out of scope:** Any estimated "total project cost" incorporating censored roots.

**Armed count:** 1 (one armed guard.)

### 3. Controls: null, seeded-defect, killed-run — all three mandatory before 4×4

**Decision:** Three controls must pass before any 4×4 number is written:

- **Null control:** Re-run 4×3 through the same detached path. Must reproduce
  T930/T932's node counts **byte-for-byte** and a speedup within a stated tolerance of
  11.6× (round-robin, contiguous partition). If 4×3 does not reproduce, 4×4 is not
  measuring what this brief says it measures, and the row stops there.

- **Seeded-defect control:** The same 4×3 arm under the legacy contiguous partition
  (`RETRO_PARTITION=contig`) must be **distinguishable** by the per-thread node-count
  imbalance ratio. If the instrument cannot tell 5.1× from 11.5×, it cannot certify the
  4×4 arm either.

- **Killed-run control:** Kill the detached job mid-flight once, on purpose, and show that
  the partial results and the log survive it. A long run that cannot be interrupted safely
  is a run that will be lost.

**Green must (post-controls):** All three controls pass as described. The imbalanced
speedup is recorded (expected ~11.6× round-robin).

**Red incident caught:** If any control fails, the 4×4 arm does not run. A failed control
that proceeds to 4×4 without being recorded is a silent regression.

**Alternative considered & rejected — two controls only:** The brief explicitly requires
three. Rejected — the seeded-defect control is the only way to verify the instrument's
partition bias measurement capability.

**Out of scope:** Running 4×4 before all three controls pass.

**Armed count:** 2 (null control + killed-run control; seeded-defect is a verification
tier, not an armed guard in the same sense, but must pass.)

### 4. When to stop: partial result if uncapped run cannot finish

**Decision:** If the run cannot finish within the agent's wall (2700 s / ~45 min), the row
closes **`blocked`** with the **partial curve committed** — i.e., whatever roots have been
processed so far are recorded with their closed/censored split at that point. A censored run
honestly reported is a result; a finished-looking number that hides a cap is not.

**Green must (post-run):** If the run finishes, acceptance criterion #4 is met. If blocked,
the partial results file is committed with a `blocked: true` flag, the wall time, and the
split of closed vs. censored roots at the point of interruption.

**Red incident caught:** T924 exited 0 having written neither deliverable because it held
the lane for 4,110 s and wrote nothing on completion. If a run writes nothing when killed,
it produces zero result.

**Alternative considered & rejected — silent finish with projected range:** Would produce a
finished-looking number that hides the cap, repeating T924's error. Rejected.

**Out of scope:** Any "estimated completion time" derived from partial results.

**Armed count:** 1 (the blocked vs. finished guard.)

### 5. What to record: wall, nodes, per-thread imbalance, peak RSS

**Decision:** The run must record **four measured values**:
- **Wall time** (seconds, measured via start/end timestamps)
- **Node count** (total nodes searched, measured via the finisher's counter)
- **Per-thread imbalance ratio** (ratio of fastest to slowest thread node counts)
- **Peak RSS** (peak resident set size, measured via host state assertion)

**Green must (post-run):** All four values are present in the output, with wall and node count
as integers, imbalance ratio as a float, and RSS as bytes.

**Red incident caught:** If any of the four values is projected or estimated rather than
measured, the row is invalidated.

**Alternative considered & rejected — only wall + nodes:** The brief explicitly requires
imbalance ratio and peak RSS as verification that the host state and partition are
correct. Rejected.

**Out of scope:** Any normalized or per-capacity metrics.

**Armed count:** 1 (the four-value guard.)

## Acceptance Summary

| # | Decision | Armed |
|---|---|---|
| 1 | Node cap: 20M with censored split | 1 |
| 2 | Censored reporting: split, not projected | 1 |
| 3 | Controls: null + seeded-defect + killed-run | 2 |
| 4 | When to stop: partial result or `blocked` | 1 |
| 5 | What to record: 4 measured values | 1 |

**Total armed count: 6**

## Out-of-scope list

- Any per-root node cap higher than 20,000,000
- Projected "expected total nodes above cap"
- Estimated "completion time" from partial results
- Running 4×4 before all three controls pass
- Any projection of censored roots into a mean
- Per-capacity normalization

## Execution model

- **Detached:** Run via `nohup … > log 2>&1 &`; record pid, command, log path, start time.
- **Partition:** round-robin (production default).
- **Host state asserted:** Peak RSS, host configuration recorded at start.
- **Incremental write:** Results written incrementally — T924's lesson is that a run which
  writes only on completion writes nothing when killed.
- **Kill-survivable:** Partial results and log must survive a mid-flight kill (verified by the
  killed-run control).