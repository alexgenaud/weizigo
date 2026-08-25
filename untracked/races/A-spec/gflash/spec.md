# Specification for T936: Full 4×4.D3 Writes-Off Finisher Execution

**Author:** gemini-3.7-flash/T974  
**Date:** 2026-08-25  
**Task Under Specification:** T936 (`run 4x4.D3 to completion`)  
**Landmark:** Advances `L2 (proven 4x4 values)`  
**Scope:** Engineering specification and execution contract for running the production writes-off retrograde finisher on the full 4×4 goban.  

---

## 1. Executive Summary & Objective

The objective of T936 is to execute the production writes-off retrograde finisher (`memo_writes=false`) across the complete 4×4 ko-sensitive population (**10,367,922 roots**, comprising 5,183,961 slots per side) on a drained host to measure the exact wall-clock time, node consumption, thread load balance, and closed-versus-censored root distribution.

T936 converts three prior research tasks of sampling, re-weighting, and scheduler optimisation into an empirical ground-truth measurement. This specification establishes the non-negotiable operational architecture, pre-flight control gates, stopping criteria, telemetry schema, and statistical reporting rules required to guarantee that T936 produces trustworthy, reproducible, and uncorrupted results.

---

## 2. Historical Baseline & Measured Context

Every decision in this specification is calibrated against measured empirical history in this repository. Projections and historical measurements are summarized below:

| Milestone / Task | Scope & Method | Measured Metric / Result | Epistemic Status & Correction |
|---|---|---|---|
| **T924** (`oxalpha`) | 4×4 writes-off stratified sample (1,287 roots sampled at 20,000,001 node cap) | **1,162 solved / 125 unsolved (9.71%)**; 2,700,272,692 nodes measured; unweighted mean 2,139,677.3 nodes/root; projected **202.5 – 1,620 h** serial wall. | Mean was unweighted across layer caps; censored roots folded into sum at 20 M bound. Lane held for 4,110 s without writing deliverables. |
| **T929** (`dsflash`) | 4×4 layer-population-weighted re-projection (no solve) | **282,104.8 nodes/root (7.585× lower)**; projected **26.8 – 214.7 h** single-threaded lower bound. The 125 capped roots are **9.71% of samples but 92.6% of measured nodes** (2.50 B / 2.70 B). | Confirms not-tractable on single-thread, but reframes cost to a pathological tail over a cheap bulk (layers 8–10 hold 75.3% of weighted nodes; solved-only mean is ~53k nodes/root). |
| **T930** (`dspro`) | Parallel scaling sweep on 4×3 writes-off (21,578 orbit reps, 183,065,016 nodes) | Contiguous chunking scales **5.10× at 18 cores**; Round-Robin scales **11.54× at 16 cores** (2,903 ms vs 34,022 ms serial). | Proved 5.1× ceiling was a work-list load-imbalance bug (deepest-first sorting caused 3.34× thread node imbalance). Memory latency saturates at ~14–15 streams. |
| **T932** (`dspro`) | Production integration of round-robin in `src/retro.zig` (`cb5a307`) | Production 4×3 reproduces **11.64× at 16 threads** (3,064 ms vs 35,670 ms serial); byte-identical counts (183,065,016 nodes, 0 bracket fails). | Landed round-robin scheduling in production engine. Added regression test `tools/regression-finishparallel-partition.sh` with null and seeded-defect controls. |

### Critical Physical Distinctions Between 4×3 and 4×4
Arithmetic extrapolation from 4×3 (2.3–18.7 h) cannot be assumed for 4×4 for two structural reasons:
1. **Working Set and Memory Bus Pressure:** 4×3 tables require ~10 MB RAM and ~6 MB context per thread (cache-resident). 4×4 tables require ~0.8 GB RAM and ~0.5 GB context per thread (~10 GB at 18 threads), shifting execution heavily toward DRAM latency stalls and reducing multi-core parallel efficiency from ~11.5× to an expected ~6–9×.
2. **Pathological Tail Distribution:** 9.71% of sampled 4×4 roots did not close at 20 M nodes. Their exact cost above 20 M is unknown, not "20 M". An unbounded single run risks thread starvation on pathological roots.

---

## 3. Normative Decisions

This specification mandates six unambiguous architectural decisions. The implementer of T936 must follow these directives without substitution.

### Decision 1: Execution Mode — Strictly Detached Background Job
* **Ruling:** T936 must execute as an asynchronous detached daemon (`nohup ... > t936.log 2>&1 &`) protected by `caffeinate -i -s`. Under no circumstances may an agent console hold the execution of this compute job.
* **Mechanism:** The launching agent registers start timestamp, PID, host state, and log path to disk (`untracked/t936_run.meta`), detaches immediately, and exits. Monitoring is performed via lightweight, non-blocking polling jobs (`bin/managent`).
* **Rationale:** T924 held an active lane for 4,110 s, blocked on a synchronous child process, and exited with code 0 having written neither deliverable nor findings to disk (surviving only via ephemeral terminal transcripts). Detached execution isolates long-running compute from agent context window timeouts, process group kills, and harness crashes.

### Decision 2: Per-Root Node Cap & Two-Tier Execution Strategy
* **Ruling:** The full 4×4 population pass (Phase 1) must be executed with a mandatory per-root node cap of **20,000,000 nodes**. Uncapped evaluation is forbidden during the primary parallel sweep.
* **Mechanism:** If a root reaches 20,000,000 nodes without resolving to a minimax terminal value, the solver must halt search on that root, mark the root status as `CENSORED_BUDGET_EXHAUSTED`, record its lower-bound node count (20,000,001), preserve its conservative retrograde bounds `[L, H]`, and proceed immediately to the next root. Roots flagged as censored are appended to an explicit unresolved queue (`untracked/t936_censored_roots.bin`). Phase 2 (the tail escalation) is isolated to those specific roots.
* **Rationale:** 9.71% of roots hit 20 M in sampling. If an unbounded search is run in a static round-robin partition across 16 threads, a single root requiring billions of nodes will permanently stall one thread while others finish, degrading system efficiency to 1× serial execution for days. Capping at 20 M guarantees that 90.29% of roots complete, bounds the total Phase 1 compute time, and isolates the pathological tail.

### Decision 3: Censored Root Accounting & Statistical Separation
* **Ruling:** Censored roots must NEVER be folded into solved-root mean node counts, solved wall-clock averages, or reported as exact oracle solutions.
* **Mechanism:** The output telemetry and summary report must partition all metrics into two disjoint categories:
  1. **Closed Subset:** Exact count, exact node sum, exact mean nodes/root, median nodes/root, and wall time spent on fully resolved roots.
  2. **Censored Subset:** Exact count (censoring rate $R_c = N_{\text{censored}} / N_{\text{total}}$), floor node sum ($N_{\text{censored}} \times 20,000,001$), and per-layer censoring distribution.
  3. **Global Bound:** Global wall time and node counts must be reported strictly as a lower bound ($W_{\text{actual}} \ge W_{\text{measured}}$), with explicit attribution of the tail weight.
* **Rationale:** T924's initial headline projection was distorted by 7.585× because capped bounds were aggregated directly into sample means without population stratification or censoring separation. Conflating a timeout bound with an exact evaluation corrupts downstream oracles.

### Decision 4: Mandatory Pre-Flight Verification Controls
* **Ruling:** Before launching the 4×4 run, the detached harness must execute and pass three automated control gates in sequence. Failure of any control immediately halts execution before any 4×4 compute is initiated.
* **The Three Controls:**
  1. **Null Control (Determinism & Scaling):** Re-run the 4×3 writes-off rung under 16 threads round-robin (`RETRO_4X3=1 RETRO_PARALLEL=1 RETRO_PARALLEL_THREADS=16`). It must match T930/T932 ground truth **byte-for-byte**: exactly 21,578 orbit reps, 183,065,016 nodes, 0 bracket fails, 0 orbit clashes, symmetry PASS, and speedup $\ge 10.5\times$ relative to single-thread.
  2. **Seeded-Defect Control (Imbalance Detector Sensitivity):** Run 4×3 under legacy contiguous chunking (`RETRO_PARTITION=contig`). The harness must detect and assert load imbalance ratio ($\text{max\_thread\_nodes} / \text{mean\_thread\_nodes} > 1.40$).
  3. **Interruption & Resumption Control (Killed-Run Recovery):** Launch a 10-second test job on 3×3, issue `SIGTERM` mid-run, assert that the partial checkpoint file is uncorrupted and valid, and verify that restarting the job resumes from the checkpoint without duplicate work or node count discrepancy.
* **Rationale:** Guarantees that the exact binary, kernel, and scheduler build used for the multi-day 4×4 run is identical to the verified engine and capable of surviving host reboots or signal interrupts.

### Decision 5: Stop Conditions, Partial Flush, and Resource Limits
* **Ruling:** T936 must enforce strict resource boundaries and periodic state serialization. A terminated or partial run must produce committed, valid partial artifacts rather than empty outputs.
* **Stop Boundaries:**
  1. **Wall-Clock Hard Stop:** Maximum wall time for Phase 1 is **48.0 hours**. If elapsed wall reaches 48h, the runner flushes state and terminates cleanly with status `blocked` / `partial`.
  2. **Memory RSS Guard:** Peak RSS must not exceed **40.0 GB** (host physical RAM is 48 GB; safety margin is 8 GB). Exceeding 40 GB triggers an immediate checkpoint flush and graceful exit to prevent host kernel panic.
  3. **Incremental Serialization:** The finisher must write an atomic checkpoint (`.ckpt.tmp` renamed to `.ckpt`) every **10 minutes** or every **100,000 solved roots**, recording bitmasks of completed roots and accumulated node telemetry.
* **Rationale:** Prevents catastrophic loss of multi-day compute in the event of host reboot, power loss, or OOM. Preserves partial progression curves for scientific analysis if the run does not finish within 48 hours.

### Decision 6: Telemetry, Observability, and Audit Trail Manifest
* **Ruling:** T936 must generate a self-contained telemetry JSON manifest and CSV summary that allows independent verification without rerunning the solve.
* **Required Data Fields:**
  - **Host & Environment Assertions:** Host CPU model (Apple M5 Max, 6 Super + 12 Performance cores), OS kernel version, total RAM (48 GB), active thread count (16), active partition scheme (`round-robin`), and confirmation that `caffeinate -i -s` was active for the duration.
  - **Workload Summary:** Total legal positions (24,318,165), total ko-sensitive slots (10,367,922), unique orbit representatives processed, total retro build wall, and finisher wall.
  - **Decomposition:** Closed root count, single-ko fast-path count, censored root count, sum of closed nodes, sum of censored floor nodes.
  - **Per-Thread Diagnostics:** For each thread $t \in [0, 15]$: root count, node count, busy wall time, and thread imbalance ratio ($\max/\text{mean}$).
  - **Per-Layer Stratification Table:** For each stone count layer $k \in [0, 15]$: total roots, closed roots, censored roots, closed nodes sum, and censoring rate.
  - **Integrity Validation:** Final post-finisher verification report: `bracket-fails=0`, `orbit-clashes=0`, `symmetry=PASS`, `unfilled=0`.

---

## 4. Acceptance Arms (Armed Count: 6)

Every normative decision above corresponds to exactly one acceptance arm. Each arm specifies a red-first failure condition, a green-pass condition, and the historical incident or defect it prevents.

### Arm 1: Detached Process Lifecycle Guard
* **Requirement:** T936 executes detached in the background under `nohup` and `caffeinate -i -s`; no agent holds the active process group.
* **Red-then-Green Test:**
  - *Red:* If an agent runs T936 synchronously in a console session, or if `caffeinate` is omitted, the test fails.
  - *Green:* PID is verified running detached via `ps -p <pid>`, `caffeinate` is active in process tree, and metadata file `untracked/t936_run.meta` contains valid PID, start monotonic time, and output log path.
* **Incident Prevented:** T924 held an interactive lane for 4,110 s and exited 0 with empty deliverables; T927 lost 24 runs to host sleep on 2026-08-24.

### Arm 2: Per-Root 20M Node Cap Enforcement
* **Requirement:** Phase 1 solver terminates per-root search at 20,000,000 nodes and tags the root as censored rather than hanging indefinitely.
* **Red-then-Green Test:**
  - *Red:* Any individual root in Phase 1 reports nodes $> 20,000,001$, or an unresolved root blocks a worker thread past the budget threshold.
  - *Green:* All completed root records report $\text{nodes} \le 20,000,001$; roots with $\text{nodes} = 20,000,001$ are classified as `CENSORED_BUDGET_EXHAUSTED` and their orbit representatives are written to `untracked/t936_censored_roots.bin`.
* **Incident Prevented:** Prevents infinite / exponential recursion on pathological ko cycles from causing thread deadlocks during multi-core execution.

### Arm 3: Censored Data Statistical Isolation
* **Requirement:** Censored roots are segregated from solved-root metrics in all summaries, tables, and findings files.
* **Red-then-Green Test:**
  - *Red:* Summary statistics compute mean nodes/root by dividing total nodes (including 20M bounds) by total roots without partitioning.
  - *Green:* Telemetry JSON and research doc clearly distinguish `closed_mean_nodes` from `censored_floor_nodes`, reporting the global wall as a lower bound with censoring percentage $R_c$.
* **Incident Prevented:** T924's 7.585× headline distortion caused by unweighted folding of capped roots into population averages.

### Arm 4: Pre-Flight Control Suite Verification
* **Requirement:** Null control (4×3 16-thread round-robin match), seeded-defect control (contiguous imbalance $> 1.40$), and interruption checkpoint recovery pass before 4×4 starts.
* **Red-then-Green Test:**
  - *Red:* 4×3 node count differs from 183,065,016 by even 1 node, contiguous imbalance ratio is $\le 1.40$, or checkpoint resumption produces state divergence.
  - *Green:* All three pre-flight scripts emit `PASS` and log hashes to `docs/evidence/T936/preflight.log` prior to the 4×4 launch timestamp.
* **Incident Prevented:** QA-023 silent pass (1,133/1,133 fake ties passed because harness was never verified end-to-end); T930 partition regression.

### Arm 5: Bounded Stop & Incremental Checkpoint Recovery
* **Requirement:** Atomic checkpoint saved every 10 minutes or 100k roots; execution cleanly aborts at 48h wall or 40 GB RSS.
* **Red-then-Green Test:**
  - *Red:* Process crashes or is killed and leaves an empty or corrupt `.ckpt` file; or process exceeds 40 GB RSS / 48h wall without exiting.
  - *Green:* Sending `SIGTERM` to the running process causes it to flush the current buffer to disk within 10 seconds and exit with return code 0, leaving a valid `.ckpt` file containing exact completed root count.
* **Incident Prevented:** Multi-day compute loss on host crashes or power loss; host kernel panics due to memory overcommit (2026-07-29 incident).

### Arm 6: Audit Telemetry & Validation Completeness
* **Requirement:** Deliverables include full per-thread imbalance, per-layer stratification breakdown, and post-finisher mathematical validation.
* **Red-then-Green Test:**
  - *Red:* Validation output shows `bracket-fails > 0`, `orbit-clashes > 0`, `symmetry != PASS`, or missing per-layer stratification.
  - *Green:* `docs/research/4x4-d3-run.md` and `findings/T936-4x4-d3-run.json` contain complete per-thread, per-layer, and validation readings with `bracket-fails=0 orbit-clashes=0 symmetry=PASS unfilled=0`.
* **Incident Prevented:** Committing unverified or corrupt oracle tables to disk; unobservable thread starvation.

---

## 5. Alternatives Considered and Rejected

| Alternative Approach | Why Considered | Why Rejected & Defended Ruling |
|---|---|---|
| **1. Agent-Held Synchronous Execution** | Simple to orchestrate in a single session; direct output streaming. | **Rejected.** T924 demonstrated that interactive sessions exceed harness timeout thresholds, consume unnecessary agent tokens, and fail to write deliverables on disconnect. Detached daemon is mandatory. |
| **2. Unbounded Search (No Per-Root Node Cap)** | Would theoretically solve every root in one pass if finite. | **Rejected.** 9.71% of roots hit 20 M in sampling. An unbounded pathological root could require $10^{11}$ nodes, locking one thread of the 16-thread pool for months while other threads idle. Capped Phase 1 + segregated Phase 2 escalation prevents thread pool starvation. |
| **3. Writes-On Memo Reuse Fallback** | Runs ~100× faster (projected 1.94–15.5 h serial). | **Rejected.** Non-negotiable foreclosure. T912 proved that memo reuse across distinct ban-sets is unsound under superko (170/378 3×2 ko pairs differ from ground truth). Unsound speedups are forbidden. |
| **4. Contiguous Work-List Chunking** | Native baseline scheduler in legacy `finishParallel`. | **Rejected.** T930 measured contiguous chunking at only 5.1× scaling on 18 cores due to deepest-layer sorting causing 3.34× thread load imbalance. Round-robin achieves 11.54× and is already landed in production (`src/retro.zig`). |
| **5. Sub-Goban Search Heuristics** | Reduces search tree size on empty quadrants. | **Rejected.** Non-negotiable foreclosure (AGENTS.md). Restricting moves to a sub-goban is mathematically unsound because edge stones retain phantom liberties. Search must be full-goban only. |

---

## 6. Explicit Out-of-Scope Declarations

To maintain strict focus and prevent scope creep, the following areas are explicitly **OUT OF SCOPE** for T936:
1. **No Rulebook Modifications:** No changes to superko rules, scoring definitions (Black-positive), or retrograde iteration kernels.
2. **No Unsound Memo Approximations:** No enabling of writes-on (`memo_writes=true`) or unverified memo caching.
3. **No 5×5 Solving:** Restrict all operations strictly to 4×3 controls and the 4×4 rung.
4. **No Dynamic Work-Stealing Implementation:** T936 will use the production round-robin scheduler landed in T932 (`cb5a307`). Developing a dynamic lock-free work-stealing queue is a separate engineering task if round-robin proves insufficient.
5. **No PSK Table Generation:** The retrograde table records fresh-start exact scores (C1); real-game PSK path generation is out of scope.

---

## 7. Execution Runbook for the T936 Implementer

### Step 1: Pre-Flight Controls Execution
Execute the pre-flight verification script to confirm binary determinism and balance detection:
```bash
# Build production engine in ReleaseSafe for pre-flight assertions
zig build-exe -O ReleaseSafe -femit-bin=/tmp/weizigo/retro_preflight src/retro.zig

# Run null control on 4x3 (must output exactly 183,065,016 nodes, 0 bracket fails)
RETRO_4X3=1 RETRO_PARALLEL=1 RETRO_PARALLEL_THREADS=16 RETRO_SOUND=1 \
  /tmp/weizigo/retro_preflight 2> /tmp/weizigo/preflight_null.err

# Run seeded-defect control on 4x3 contiguous (must detect max/mean > 1.40)
RETRO_4X3=1 RETRO_PARALLEL=1 RETRO_PARALLEL_THREADS=3 RETRO_PARTITION=contig \
  /tmp/weizigo/retro_preflight 2> /tmp/weizigo/preflight_contig.err
```

### Step 2: Detached Production Launch
Compile production binary with `-O ReleaseFast` and launch under `caffeinate`:
```bash
# Compile optimized production engine
tools/runner --ram-mb 4608 -- zig build-exe -O ReleaseFast -femit-bin=/tmp/weizigo/retro_prod src/retro.zig

# Launch detached background job on drained host
caffeinate -i -s nohup env \
  RETRO_PARALLEL=1 \
  RETRO_PARALLEL_THREADS=16 \
  RETRO_SOUND=1 \
  RETRO_NODE_CAP=20000000 \
  RETRO_CKPT_INTERVAL=600 \
  RETRO_PARALLEL_CKPT=/tmp/weizigo/oracle-4x4-d3.ckpt \
  RETRO_PARALLEL_OUT=data/oracle-4x4-d3.wzo \
  /tmp/weizigo/retro_prod > /tmp/weizigo/t936_run.log 2>&1 &

# Record PID and metadata immediately
echo $! > untracked/t936_run.pid
echo "PID: $(cat untracked/t936_run.pid), START: $(date -u +%Y-%m-%dT%H:%M:%SZ)" > untracked/t936_run.meta
```

### Step 3: Monitoring & Checkpoint Inspection
Inspect non-intrusively via log tailing:
```bash
tail -n 20 /tmp/weizigo/t936_run.log
# Verify thread activity and RSS
ps -o pid,ppid,rss,etime,command -p $(cat untracked/t936_run.pid)
```

### Step 4: Finalization & Deliverable Emission
Upon process completion (or clean 48h timeout stop):
1. Format results into `docs/research/4x4-d3-run.md` superseding `4x4-d3-tractability.md`.
2. Commit raw run evidence to `docs/evidence/T936/`.
3. Emit findings file `findings/T936-4x4-d3-run.json` with status `pass` (if fully closed) or `pass-with-findings` / `blocked` (if censored tail remains).
