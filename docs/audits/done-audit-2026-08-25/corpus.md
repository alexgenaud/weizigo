# DONE Audit Corpus and Auditor Protocol (2026-08-25)

**Landmark:** advances `L1 (the dashboard tells the truth)` — establishes whether the project's
reported throughput, task completions, and self-reported verdicts reflect verifiable reality.

## 1. Overview & Purpose

The task store (`docs/infra/managent/tasks.json`) records 525 closes: **278 `pass`, 228
`pass-with-findings`, 12 `blocked`, 7 `abandoned`, and `fail-found` zero.** A fleet that never
records a failure is not measuring failure; it is likely measuring the absence of verification.

As observed by the operator (2026-08-25):
> *"Perhaps you are trusting the tools and records too much. Perhaps it would be better to spawn a
> diligent agent (or a race of models) to review a large set of 'DONE' tasks for ACTUAL task
> completion, ACTUAL absorption, ACTUAL model performance evaluation, ACTUAL fault tolerance,
> visibility, recovery… largely a data collection exercise (with some thinking analysis required
> to determine whether the task was actually productive and/or the final status was accurate and
> useful)."*

The DONE audit evaluates 120 completed tasks across the fleet using nine independent auditor
models (`dspro`, `dsflash`, `kimi`, `haiku`, `gemini`, `gptluna`, `qwencloud`, `nemotron`,
`solarpro`).

This document provides the sampling corpus, stratification definitions, slice assignments,
the sealed control key protocol, and the evaluation schema for all auditors.

---

## 2. Corpus Stratification & Census

The 120-task corpus is drawn from all `status: done` tasks in `docs/infra/managent/tasks.json`
(525 tasks total). To ensure the sample does not flatter the fleet, the corpus is stratified
across four primary dimensions:

### Stratum A: Verdict Distribution
The sample reflects all close verdicts, with deliberate inclusion of failure and blocked modes.

| Verdict | Population (525) | Population % | Sample Count (120) | Sample % | Control Slice (12) | Disjoint Slices (108) |
|---|---|---|---|---|---|---|
| `pass` | 278 | 53.0% | 56 | 46.7% | 4 | 52 |
| `pass-with-findings` | 228 | 43.4% | 54 | 45.0% | 3 | 51 |
| `abandoned` | 7 | 1.3% | 6 | 5.0% | 3 | 3 |
| `blocked` | 12 | 2.3% | 4 | 3.3% | 2 | 2 |
| **Total** | **525** | **100.0%** | **120** | **100.0%** | **12** | **108** |

### Stratum B: Model / Agent Representation
Every model active in the fleet's history is represented in proportion to its contribution.

| Model / Agent | Population (525) | Sample Count (120) | Control Slice (12) | Disjoint Slices (108) |
|---|---|---|---|---|
| `deepseek-v4-flash` | 155 | 33 | 3 | 30 |
| `deepseek-v4-pro` | 144 | 31 | 1 | 30 |
| `glm-5.2` | 50 | 11 | 1 | 10 |
| `claude-opus-5` | 39 | 9 | 1 | 8 |
| `claude-sonnet-5` | 35 | 8 | 1 | 7 |
| `minimax-m3` | 21 | 5 | 1 | 4 |
| `claude-fable-5` | 18 | 4 | 1 | 3 |
| `claude-haiku-4-5-20251001` | 17 | 4 | 0 | 4 |
| `oxalpha` | 16 | 4 | 1 | 3 |
| `kimi-k2.7` | 15 | 3 | 1 | 2 |
| `unassigned` (orphan backfills) | 9 | 4 | 0 | 4 |
| `gemini-3.7-flash` | 3 | 2 | 1 | 1 |
| `qwen3.8:27b-mlx` | 3 | 2 | 0 | 2 |
| **Total** | **525** | **120** | **12** | **108** |

### Stratum C: Temporal Epochs
Tasks span the entire lifecycle from early unconstrained epochs to recent high-cadence races.

| Epoch Range | Description | Population (525) | Sample Count (120) | Control (12) | Disjoint (108) |
|---|---|---|---|---|---|
| `T300-T450` | Early sprint epoch (2026-08-04 to 2026-08-08) | 124 | 19 | 2 | 17 |
| `T451-T650` | Mid-sprint expansion (2026-08-09 to 2026-08-22) | 183 | 41 | 0 | 41 |
| `T651-T800` | Harness transition & race epoch (2026-08-23 to 2026-08-24) | 99 | 29 | 0 | 29 |
| `T801-T944` | Current sprint epoch (2026-08-24 to 2026-08-25) | 118 | 31 | 10 | 21 |
| `Other` | Non-numbered duties/tombstones | 1 | 0 | 0 | 0 |
| **Total** | | **525** | **120** | **12** | **108** |

### Stratum D: Unconstrained / No-Acceptance Stratum (20 Rows)
A dedicated stratum of exactly **20 tasks** was drawn from tasks with no machine-checked
`acceptance=` command (and including all tasks with no declared `deliverables=` in bundle headers
or orphan backfills). In the population, 388 tasks (74%) had no `acceptance=` tag. This stratum
specifically evaluates tasks that operated without automated close gates:

- **Tasks (20):** `T674`, `T679`, `T683`, `T685`, `T491`, `T533`, `T916`, `T462`, `T804`,
  `T677`, `T848`, `T464`, `T627`, `T908`, `T470`, `T640`, `T792`, `T751`, `T900`, `T459`
- **Breakdown:** 12 `pass-with-findings`, 8 `pass`.
- **Distribution:** Distributed across all 9 disjoint auditor slices (2 to 3 tasks per slice).

---

## 3. Slice Assignments (`slices.json`)

The 120 rows are partitioned into:
1. **1 Shared Control Slice (12 tasks):** Audited by **all 9 auditors** to measure inter-auditor
   agreement and grade against the sealed answer key.
2. **9 Disjoint Slices (12 tasks each = 108 tasks total):** Assigned to individual auditors for
   broad coverage across the population. No disjoint slice shares any task with another disjoint
   slice or with the control slice.

Each auditor evaluates exactly **24 rows** (12 control rows + 12 assigned disjoint rows).

### Auditor Slice Table
| Auditor ID | Task ID | Model | Assigned Disjoint Tasks (12) | Shared Control Tasks (12) | Total |
|---|---|---|---|---|---|
| `dspro` | T946 | `deepseek-v4-pro` | T900, T685, T804, T810, T580, T779, T564, T396, T426, T903, T901, T330 | `control` (12) | 24 |
| `dsflash` | T947 | `deepseek-v4-flash` | T459, T470, T916, T730, T853, T619, T624, T793, T777, T555, T944, T884 | `control` (12) | 24 |
| `kimi` | T948 | `kimi-k2.7` | T627, T683, T614, T440, T835, T625, T800, T732, T643, T728, T516, T482 | `control` (12) | 24 |
| `haiku` | T949 | `claude-haiku-4-5-20251001` | T464, T751, T467, T755, T701, T409, T411, T478, T930, T707, T412, T750 | `control` (12) | 24 |
| `gemini` | T950 | `gemini-3.7-flash` | T462, T674, T519, T746, T514, T432, T548, T702, T872, T488, T326, T361 | `control` (12) | 24 |
| `gptluna` | T955 | `gpt-5-luna` | T491, T908, T646, T360, T541, T473, T408, T710, T764, T586, T494, T818 | `control` (12) | 24 |
| `qwencloud` | T956 | `qwen3.8-27b` | T792, T679, T618, T803, T648, T365, T799, T537, T573, T582, T506, T754 | `control` (12) | 24 |
| `nemotron` | T957 | `nemotron-49b` | T640, T848, T598, T621, T638, T652, T913, T403, T507, T742, T862, T465 | `control` (12) | 24 |
| `solarpro` | T958 | `solar-pro` | T533, T677, T447, T920, T917, T628, T789, T657, T711, T336, T378, T824 | `control` (12) | 24 |

---

## 4. The Sealed Answer Key Protocol

The control slice contains twelve tasks with verified ground truth. The key is sealed to prevent
contamination of auditor runs.

### Control Tasks (12)
`T932`, `T927`, `T894`, `T924`, `T921`, `T943`, `T842`, `T841`, `T907`, `T387`, `T929`, `T421`

### Summary of Control Row Ground Truths

1. **T932 (Null Control 1):** Fully productive clean pass. Implemented round-robin partition in
   `finishParallel` (`src/retro.zig`), verified reproduction of 11.6x speedup, delivered passing
   regression script `tools/regression-finishparallel-partition.sh`, and closed cleanly. An
   auditor that flags this is over-reading.
2. **T927 (Null Control 2):** Fully productive clean pass. Implemented caffeinate guard in
   `tools/runner` and 4-arm regression test `tools/regression-sleep-guard.sh`. Clean execution.
3. **T894 (Work Real, Record Absent):** Worker delivered code in `src/managent/main.zig` and
   regression test, but exited without writing a findings file or calling `managent done`. The close
   is honest **only because the orchestrator seat (T935) stepped in**, wrote findings post-hoc, and
   closed it `pass-with-findings`. An auditor reading only the task store sees a clean close.
4. **T924 (Work Real, Headline Number 7.585x Wrong):** Ran 68 min ladder, hit 429s, deliverables
   recovered from transcript by seat; its published solve projection was **7.585x too high** due
   to unweighted mean calculation (corrected by T929). Deliverable-presence checking alone misses
   this mathematical defect.
5. **T921 (True Negative Control):** Killed mid-flight during cold-cache debug build; no deliverables
   written; closed `abandoned`. True negative.
6. **T943 (Flawed Automated Close / Red Gate):** Delivered moving parts inventory and regression,
   but regression test had a false-positive on Claude Code harness caffeinate, causing `zig build test`
   to fail whenever Claude console was open. The row closed `pass` automatically via `tools/runner`
   even though its own declared acceptance test was actively RED on a clean host.
7. **T842 (Runaway Model):** Minimax-m3 consumed 790/792 Ollama requests in a 5-hour window, ran
   2902s, produced zero deliverables and no patch. Closed `abandoned` on evidence.
8. **T841 (Starved Lane):** Kimi-k2.7 starved by T842 (received only 1 Ollama request), ran 2909s
   without output. Closed `abandoned` due to host/infra contention, not model incompetence.
9. **T907 (Work Complete, Commit Refused by Git Hook):** Worker completed all 233 claim
   adjudications, but git commit failed due to pre-commit hook tripping on an unrelated dirty file
   from another console. Closed `blocked` despite work being 100% complete in tree; later committed
   at `594d860` by seat.
10. **T387 (Infinite Loop Bug under ReleaseFast):** Worker wrote `src/t387_budget.zig` with `bitpos: u6`
    and `while (bitpos < 64)` which wrapped under ReleaseFast, spinning for 14 hours. DAG readings
    salvaged into T397, but Bellman consistency reading was never taken. Closed `blocked`.
11. **T929 (High-Utility Analytical Correction):** Re-projected 4x4.D3 tractability using
    layer-population weights on committed CSV data, correcting T924's 7.585x error without compute.
    Closed `pass-with-findings`.
12. **T421 (Historical Unconstrained Benchmark):** Rescued 43 volatile `/tmp` citations to
    `docs/evidence/`, established "evidence in git" standard, built C10 claimlint checker. From the
    no-acceptance stratum (predated machine-checked acceptance), but fully verified and absorbed.

### Sealed Key Verification
- **Storage Location:** Project-local untracked store (`done-audit-2026-08-25-answer-key.json` under untracked directory).
- **SHA-256 Checksum:** `440451bc1fd60711bc676374bd3b727e22f7f39d8d30f740d0726eea792e993e`
- **Access Authority:** Held sealed until opened exclusively by the **Judge seat (T951)**.
  No auditor arm may inspect the key prior to completing their audit.

---

## 5. Auditor Record Schema

Every auditor must output `records.json` containing an array of records matching the following
exact schema:

### Mechanical Fields (Machine-Collectible)
Auditors should write a collector script to gather these fields from `tasks.json`,
`untracked/runs/`, `findings/`, and `git log`:

- `task_id` (string): e.g. `"T932"`
- `model` (string or null): Canonical model label (e.g. `"deepseek-v4-pro"`)
- `verdict` (string): `"pass"` | `"pass-with-findings"` | `"blocked"` | `"abandoned"` | `"fail-found"`
- `wall` (float or null): Wall-clock execution time in seconds from run record
- `deliverables_declared` (array of strings): Deliverables listed in bundle metadata or `## Deliverables`
- `deliverables_present_in_git` (array of strings): Deliverables present in git tree at HEAD
- `findings_file_exists` (boolean): `true` if a findings file exists in `findings/`
- `findings_file_bytes` (integer or null): Size in bytes of the primary findings file
- `acceptance_declared` (string or null): Command string if `acceptance=` was specified
- `run_record_exists` (boolean): `true` if run JSON exists in `untracked/runs/`
- `run_record_exit` (integer or null): Process exit code from run record
- `attempts` (integer): Number of recorded dispatch/claim attempts
- `killed` (boolean): `true` if process was terminated by runner watchdog or SIGKILL
- `tokens_out` (integer or null): Total completion tokens from run record
- `commit_shas_touching_deliverables` (array of strings): List of commit SHAs touching the deliverables

### Judgement Fields (Analytical / Thinking Half)
Each judgement field requires an evaluation value and a one-line concise justification citing
observed evidence:

1. **`work_actually_done`**: `"complete"` | `"partial"` | `"none"`
   - Evaluated **against the row's brief / prompt**, not against the verdict and not against the
     deliverable list. A task that produced declared files but answered a different question is
     `partial`.
   - `work_actually_done_reason` (string): One-line explanation citing what was delivered vs asked.
2. **`verdict_accurate`**: `"yes"` | `"no"` | `"unverifiable"`
   - Is the recorded task store verdict accurate with respect to what actually occurred?
   - `verdict_accurate_reason` (string): One-line explanation.
3. **`absorbed`**: `"yes"` | `"no"` | `"partial"`
   - Did the result reach a durable artifact (code commit, register promotion, cited doc), or did
     it stop at a write-only findings file that nothing references?
   - `absorbed_reason` (string): One-line explanation.
4. **`self_reported_or_verified`**: `"verified"` | `"self-reported"` | `"unverifiable"`
   - Did anything other than the worker's own assertion establish the outcome? (Machine acceptance
     pass, git artifact, downstream use, independent check).
   - `self_reported_or_verified_reason` (string): One-line explanation.
5. **`useful`**: `"yes"` | `"no"` | `"mixed"`
   - *Would the project be worse off if this row had never run?* A task can be 100% complete and
     correct, yet completely useless.
   - `useful_reason` (string): One-line explanation.

---

## 6. Auditor Deliverables & Execution Rules

Each auditor (`T946`–`T950`, `T955`–`T958`) delivers:
1. `docs/audits/done-audit-2026-08-25/<arm>/records.json`: Complete records for all 24 assigned rows.
2. `docs/audits/done-audit-2026-08-25/<arm>/analysis.md`: Narrative analysis including:
   - Summary census (accurate verdicts, absorption rate, verification rate, usefulness).
   - Analysis of the no-acceptance stratum tasks in their slice.
   - Recommended task re-openings with reasons.
   - The single most important pattern discovered and what would disprove it.
3. `findings/<TASK_ID>-done-audit-<arm>.json`: Conforming findings file per `findings/README.md`.

---

## 7. Epistemic Assessment: Potential Sample Misleading Factor

### The One Thing Most Likely to Mislead Us
**Over-representation of failure modes and unconstrained tasks:**
In the natural population of 525 tasks, failure verdicts (`blocked` + `abandoned`) constitute only
3.6% (19/525), and 96.4% of tasks are recorded as `pass` or `pass-with-findings`. In this sample,
we deliberately over-indexed failures in the control set (41.7% failures) and isolated a 20-row
unconstrained/no-acceptance stratum (16.7% of corpus).

If a reader calculates an unweighted aggregate failure or unverified rate across this sample, it
will show higher failure and unverified rates than the raw store distribution.

### Why We Built It Anyway
A uniform random sample of 120 tasks would contain at most 3-4 failures and almost exclusively
benign passes, providing virtually zero statistical power to calibrate whether auditor models can
distinguish real accomplishments from empty self-reports, runaway loops, or masked errors. By
anchoring the evaluation against known hard cases and unconstrained rows, we measure genuine
auditor sensitivity and prevent the audit from simply rubber-stamping the status quo.
