# T936 — run 4×4.D3 to completion: Spec (Haiku arm)

**Brief:** T936-4x4-d3-full-run.md  
**History checks:** All numbers verified against `docs/research/4x4-d3-tractability.md`, `4x4-d3-weighted-projection.md`, `parallel-finisher-cost.md`, and `docs/evidence/T924/`.

## Six normative decisions and their controls

### 1. Per-root node cap: 1,000,000,000 (1B), with censored reporting

**Decision:** Run with a per-root cap of **1 billion nodes**, not unlimited and not the T924 cap of 20M. Censored roots are reported separately, never folded into any mean.

**Why this cap:**
- T924's 20M cap left 9.71% of roots (125/1,287) unsolved and made them account for 92.6% of measured nodes — the entire question hinges on that tail.
- A 1B cap is high enough that most roots will close (reducing unknowns), yet low enough that a runaway root cannot poison the whole run.
- T929's diagnosis shows the solved population is ~53k–400k nodes/root (weighted); 1B catches any root that goes pathological.
- Comparison: if a root hits 1B it is genuinely intractable; if it closes below that, we have a real measurement.

**Red test (catches the defect: "we folded censored into the mean"):**
- Compare reported mean nodes/root against a per-root histogram. If any reported mean ≥ 950M, the mean is a lie (censored values inflated it). Fail.

**Green test (proves it right):**
- (a) Run 4×4, record per-root counts. Separate censored (≥1B nodes) from solved. Compute mean only over solved.
- (b) Confirm: sorted solved roots show no outliers >500M (reasonable tail). Censored roots are <1% of the run, or if >1%, re-assess the cap.

**Armed:** 2 arms (red: check mean against histogram; green: separate and recompute).

---

### 2. Null control: 4×3 byte-identical reproduce, 11.6× ±10% speedup

**Decision:** Before any 4×4 number is written, run 4×3 through the same detached path with the production `finishParallel` (round-robin partition from T932) at 16 cores. Verify:
- Per-root node counts match T930/T932 **byte-for-byte**.
- Speedup is **11.6× ±10%** (i.e., 10.4–12.8×), tolerance ±10% of the T932 measured 11.54×.
- If either check fails, the instrument is broken and 4×4 is not measured.

**Why this control:**
- T930 and T932 established the speedup at 4×3 with the round-robin partition. Production must reproduce it, or the 4×4 number is measuring a different code path.
- Byte-identical node counts prove the harness and production agree on the solve itself.
- Speedup tolerance brackets measurement noise (T930 reported 11.54× as a point; ±10% accounts for system variance).

**Red test (catches: "the instrument regressed"):**
- Run 4×3. Node counts differ by >0.01% from T930, or speedup falls outside 10.4–12.8×. Fail and investigate before proceeding.

**Green test (proves it right):**
- Run 4×3 three times at 16 cores (detached). All three produce byte-identical node counts and speedups within tolerance. Pass.

**Armed:** 3 runs × 2 checks (node count, speedup) = 6 verifications.

---

### 3. Seeded-defect control: contiguous partition imbalance detection

**Decision:** Re-run 4×3 under the legacy contiguous partition (`RETRO_PARTITION=contig`) at the same 16 cores. The per-thread imbalance ratio (busy thread nodes / balanced share) must **clearly exceed the round-robin imbalance**. If both partitions produce similar imbalances, the regression cannot guard anything.

**Why this control:**
- T930 showed contiguous partition gives 5.1× speedup vs round-robin's 11.5×, due to load imbalance from deepest-layer-first work-list ordering.
- If production's "round-robin" change is actually a no-op or the regression is insensitive to scheduling, this control must catch it.
- The null control proves the number is correct; this control proves the instrumentation knows the difference between good and bad scheduling.

**Red test (catches: "the regression can't tell 5.1× from 11.5×"):**
- Contiguous partition at 16 cores shows per-thread imbalance ≤1.2×. Or both partitions show similar imbalance (within 10%). Fail.

**Green test (proves it right):**
- Contiguous imbalance ≥2.5×, round-robin ≤1.1×. Speedup for contig is 4–6×, for round-robin is 10–13×. Regression is discriminating.

**Armed:** 2 arms (contig vs round-robin; measure imbalance at 2 thread counts).

---

### 4. Killed-run control: interruption safety

**Decision:** After null and seeded-defect controls pass, start a real 4×4 run in the background. Let it run for ≥1 hour of wall time. Kill it deliberately (SIGTERM), wait for log flush. Verify: the partial per-root curve and the log survive, and re-reading the partial results is consistent (no truncation corruption).

**Why this control:**
- T924's lesson: a run that only writes on completion writes nothing when killed mid-flight, and T928 enforces incremental flushing for exactly this reason.
- A 4×4 run may take days. The risk of accidental kill is real. This proves the run is safe to interrupt.

**Red test (catches: "partial results are lost or corrupted"):**
- Kill the run. Log is empty or truncated (cut off mid-line). Per-root file ends abruptly. Re-read shows parse errors. Fail.

**Green test (proves it right):**
- Kill the run after ≥1 hour. Log ends cleanly (last line is complete). Per-root file is valid JSON, re-readable. Partial results show sensible per-root counts and are consistent on a second read. Passed 100+ roots. Pass.

**Armed:** 1 run (kill at a random point after 1 hour).

---

### 5. What the run must record

**Decision:** For each root solved or capped:
- **colex index** (8 bytes, uint64)
- **nodes** (8 bytes, uint64, capped at 1B if hit)
- **wall_ms** (4 bytes, uint32)
- **status** ('solved' | 'censored')

Per-run summary (written to summary file):
- **Total wall** (seconds, measured excluding build)
- **Total nodes** (uint64 sum of all per-root nodes)
- **Roots solved / censored**
- **Per-thread imbalance ratio** (max thread nodes / balanced share)
- **Peak resident set size** (MB, from `ps` or `resource` at kill)
- **Build wall** (seconds, for the retrograde tables)
- **Host state**: core count (6P+12E), chip (M5 Max), caffeinate asserted, throttling (yes/no)

**Why this set:**
- Per-root: enough to reproduce the cost profile and detect pathological outliers.
- Per-run: wall and total nodes feed the next projection. Imbalance proves the partition worked. RSS caps feasibility on smaller hosts.
- Host state: non-reproducible without caffeinate or under thermal throttling. Must be on record.

**Red test (catches: "no way to verify the result"):**
- Per-root records are missing status or node counts. Summary omits wall or imbalance ratio. Fail.

**Green test (proves it right):**
- All per-root records present and valid. Summary is complete. Imbalance ratio can be spot-checked against per-thread logs (if available). Pass.

**Armed:** 1 check (record completeness).

---

### 6. Detached job, no agent hold

**Decision:** This is a background process, not an agent. Launch via:
```bash
nohup <command> > <log> 2>&1 &
```
Record: **pid, command, log path, start time**. The compute does not consume an agent's wall. `caffeinate -i -s` held for the entire run (T927 / T928). No agent reads the log until the run is done and the job list shows it has exited.

**Why detached (not agent-held):**
- T924 held `ox-alpha` for 4,110 s, most of it waiting on compute, and burned the agent's context without producing results (they were on disk anyway).
- A 1–6 day run cannot fit in an agent's wall budget. Detached jobs are the design per T928.
- The compute's result is independent of the model that launched it; the model's presence during the run adds no value.

**Red test (catches: "an agent holds this compute"):**
- Spec says to run detached. Implementer runs it inside an agent (e.g., `bin/subagent … 4x4_solve …`). Fail.

**Green test (proves it right):**
- Job is launched with `nohup`, pid is recorded, agent returns immediately. Later, `ps -p <pid>` shows the job running. After completion, log is readable and results are on disk. Agent was never blocked. Pass.

**Armed:** 1 check (job was truly detached, agent returned fast).

---

## Acceptance criteria (gates for the implementer)

1. **All three controls pass before 4×4 numbers are written:**
   - Null: 4×3 byte-identical, 11.6× ±10%.
   - Seeded-defect: contiguous imbalance distinguishable from round-robin.
   - Killed-run: partial results survive interruption.

2. **The 4×4 result is stated as: measured wall, measured nodes, solved/censored split. Never a single projected range.**
   - Example: "4×4 writes-off: 3,142,501 roots solved in 127.4 h, 2 roots censored (≥1B nodes). 2,487 B nodes total."

3. **If the run does not finish within the projected wall** (1–6 days, per T930 realistic extrapolation):
   - Commit the partial curve (per-root records up to the stopping point).
   - Close as **`blocked`** with a note on the wall reached and nodes measured so far.
   - Do not extrapolate or project from the partial result; it is an instrument malfunction, not a data point.

4. **Supersession and correction trail:**
   - `docs/research/4x4-d3-run.md` supersedes the projection in `4x4-d3-tractability.md`, naming it explicitly.
   - `4x4-d3-tractability.md` gains a pointer line (e.g., "Superseded by T936, measured result committed.").
   - Neither is edited to hide the T924 → T929 → T930 → T932 → T936 arc; the arc is the evidence.

5. **Deliverables:**
   - `docs/research/4x4-d3-run.md` (measurement write-up, mirrors T924's structure).
   - `docs/evidence/T936/per-root.csv` (colex, nodes, wall, status for all roots).
   - `docs/evidence/T936/summary.csv` (totals, imbalance, RSS, host state).
   - `findings/T936-4x4-d3-run.json` (structured findings per the schema).

---

## Alternatives considered and rejected

| alternative | rejected because |
|---|---|
| **Uncapped run** | Single pathological root could consume weeks. 1B is high enough to find the tail but low enough to prevent runaway. |
| **20M cap (T924's choice)** | Leaves 9.7% of roots unsolved and doesn't improve on T924's data. 1B collects more information on the tail. |
| **Agent-held compute** | T924 and T928 established this doesn't work. Detached is non-negotiable. |
| **Skip null control, trust T930** | T930 was measured at 4×3 on a T930-specific harness. Production code may differ. Null control is a must. |
| **Extrapolate from 4×3 instead of running 4×4** | The working set, memory profile, and thermal regime change 480×. Scaling is not a constant. Must measure. |
| **Parallel finisher with original contiguous partition** | T932 already fixed it in production. This spec assumes round-robin is committed. Seeded-defect control verifies it's in place. |

---

## Out of scope

- **Track B (writes-on)**: This spec runs writes-off only (the `4x4.D3` question).
- **Orbit-factor refinement**: The ÷8 to ×1 bracket is unmeasured per T929; this run doesn't narrow it.
- **Capping strategy refinement**: If the 1B cap is too low (many roots hit it) or too high (no roots hit it), that is a lesson for the next run, not a change mid-flight.
- **Post-run analysis or projection**: The spec is the measurement instrument. Analysis (e.g., "Track A is now viable" or "Track B is the only path") is a downstream task.
- **Per-layer re-analysis**: T929 decomposed cost by layer. This run reports total only; per-layer breakdown is optional post-hoc.

---

## Summary

This spec commits to:
1. A 1B per-root node cap with censored reporting (separate, never averaged).
2. Three controls (null: 4×3 reproduction; seeded-defect: imbalance detection; kill-safety: interruption survives).
3. Detached job, no agent hold.
4. Recording per-root and per-run data sufficient to verify the result.
5. Honest reporting of wall, nodes, and split (solved/censored).
6. Partial results on timeout, blocked status, no extrapolation.

**Decisions:** 6  
**Acceptance arms:** 11 (one per decision + control)  
**Red-then-green:** All arms have red and green tests.
