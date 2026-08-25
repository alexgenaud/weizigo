# T975 — T936 run specification

**Author:** gpt-5.6-luna-pro/T975  
**Date:** 2026-08-25  
**Status:** sealed Race A arm; specification only  
**Landmark:** advances **L2 (proven 4×4 values)** by deciding how T936 can produce an
honest writes-off measurement rather than another projection.

## 1. Decision and success condition

T936 shall run the **complete 4×4 writes-off finisher** over every work item generated from
the full ko-sensitive region. “Full” means no sampled roots: the run must account for every
legal side-slot in the region and every orbit representative that `finishParallel` actually
solves. The 10,367,922 figure in the prior history is the ko-sensitive side-slot count
(5,183,961 per side), **not** the number of forward solves. The report must print and retain
the actual orbit-representative work-list count; it must not call side-slots “roots.”

The target mode is `memo_writes=false` (Track A / writes-off), bracket-guided, round-robin,
with 16 worker threads unless the host record justifies another fixed count. The run is a
measurement, not a claim that its resulting values are real-game PSK values. Any completed
value is a fresh-start value under the project's finisher semantics; the run does not settle
C2 history-independence or C3 real-game bounding.

The run is **PASS** only if all controls are green and every work item completes without
validation errors. If the declared stop is reached first, it is **BLOCKED**, not failed and
not “complete”: the partial checkpoint and a censored result report are the deliverable.

## 2. Normative decisions

### N1 — Full population, not a sample

Use the production work-list builder on the complete 4×4 table. Record both the total
ko-sensitive side-slots (B and W separately) and the deduplicated representative count
(B/W and total). The run must not substitute T924's 1,287-root sample or extrapolate from it.
Round-robin assignment is deterministic: work-list item `i` goes to thread `i mod 16`.

**Acceptance arm A1 (coverage):** red-first removes one known work item or replaces the
full iterator with a sample; the checker must fail because the manifest's expected
side-slot/representative counts do not match the run header. Green runs the unmodified
full iterator and records `attempted = completed + censored + not_attempted` against the
full manifest. **Catches:** T924's 1,287/10,367,922 sample being mistaken for a full run.

### N2 — No per-root node cap

Set `RETRO_PARALLEL_BUDGET=0`; in this engine zero means unlimited. Do not use the historical
20,000,000-node budget. The run's only planned stop is the global wall deadline in N6 or an
operator emergency. A root is never declared solved because a node budget expired.

**Acceptance arm A2 (budget):** red-first runs with the 20,000,000 budget against a fixture
containing a known budget-hitting root; the run checker must reject it as a purported
uncapped measurement and mark that root censored. Green's launch manifest contains the
literal zero budget and the log contains the mode assertion. **Catches:** the 125 T924 roots
whose true cost is unknown above the cap being silently treated as completed at the cap.

### N3 — Censoring is a separate set, never a mean input

Every representative has exactly one status: `completed`, `censored`, `not_attempted`, or
`single_ko` (the last is reported separately and has zero forward-search nodes). For each
completed representative record nodes and wall; for each censored representative record the
last known node count and why it was censored. A censored node count is a lower bound, not a
measurement of the root's full cost. No mean, total, speedup, or projection may replace a
censored value with its cap or with zero. The report must include the closed/censored/not-
attempted split and must say that any aggregate over completed roots excludes censored and
not-attempted roots.

**Acceptance arm A3 (censor semantics):** red-first mutates a fixture report so one capped
root is labelled `completed`, then so it is included in a mean at its last node count; the
validator must reject both forms. Green emits the explicit status split and either no
population mean or a mean explicitly labelled “completed roots only.” **Catches:** the
T924/T929 confusion in which 125 roots were described as excluded even though their cap
counts were included, and the resulting 7.585× projection error.

### N4 — Writes-off mode is observable and enforced

The launch must set `RETRO_SOUND=1`, must not set `RETRO_DEPS`, and must record the complete
environment in the run manifest. The mode line must say `memo_writes=false` / `sound`, not
merely infer it from an absent variable. Writes-on is not an acceptable substitute or
calibration result for T936.

**Acceptance arm A4 (mode):** red-first changes the launch to the default writes-on mode or
Track B and changes no output filename; the consumer must reject the result from the T936
lane by its manifest mode. Green has `RETRO_SOUND=1`, `RETRO_DEPS` absent, and a log line
confirming `finisher[parallel,sound]`. **Catches:** T912's demonstrated memo-reuse
soundness failure (170 of 378 3×2 ko-sensitive pairs differed).

### N5 — Null control before 4×4

Use the same detached executable and capture path for a 4×3 writes-off null arm first,
with 16 round-robin threads and the historical 20M per-root budget. It must reproduce the
committed T932 production reading byte-for-byte for the deterministic counts:

- 21,578 representative work items;
- 183,065,016 total nodes;
- zero bracket failures and zero orbit clashes.

Its finisher wall must be within ±10% of T932's 3,064 ms reading (2,758–3,370 ms) on the
same drained host discipline, and its measured speedup against its own one-thread run must
be within ±10% of 11.6× (10.44×–12.76×). Record if the host cannot satisfy comparable load;
do not silently accept an incomparable timing.

**Acceptance arm A5 (null):** red-first corrupts one expected count or runs a different
binary; the null verifier must fail byte identity before permitting any 4×4 result. Green
runs the exact production path and passes all three count checks plus the stated speed
window. **Catches:** a stale binary, changed move generation, changed writes-off semantics,
or a false claim that the 4×4 run measures the T932 finisher.

### N6 — Seeded scheduling-defect control

Still before 4×4, rerun the 4×3 arm with `RETRO_PARTITION=contig`, retaining all other
settings. The seeded-defect arm must be distinguishable from round-robin by per-thread
node totals: the contiguous arm has `max(thread_nodes)/mean(nonempty thread_nodes) > 1.40`,
and the round-robin null has that ratio ≤ 1.40. Both arms must retain the same deterministic
total node count. The ratio itself, every per-thread total, thread count, and partition
must be in the evidence.

**Acceptance arm A6 (seeded defect):** red-first flips the production default to contiguous
or disables per-thread totals; the control must fail to distinguish the arms (and therefore
fail the gate). Green detects the contiguous imbalance and passes the round-robin arm.
**Catches:** T930's 5.1× contiguous scheduling ceiling being mistaken for a 4×4 algorithmic
limit, or an instrument that cannot see its own partition defect.

### N7 — Interruptible, resumable partial result

After A5 and A6 are green, run a separate 4×3 killed-run control through the same detached
path. Send SIGINT while work is active. The handler must let workers stop at a safe root
boundary, merge finished results, write a readable checkpoint, and preserve the log. Reload
the checkpoint and verify that finished entries are not rerun and that a subsequent resume
continues from the recorded statuses. A hard SIGKILL is an emergency test only and cannot
be counted as a passing graceful-interruption result.

**Acceptance arm A7 (killed run):** red-first truncates/deletes the checkpoint or uses a
copy that does not flush before exit; the reload/resume checker must fail. Green shows the
surviving checkpoint hash, a log line identifying interruption, a nonzero finished partial,
and a resume with no duplicate completion count. **Catches:** T924's lane exiting 0 with
neither deliverable and any long run that loses all useful work on interruption.

### N8 — Declared stop and partial closure

Set a 72-hour finisher wall deadline, measured after the build and recorded independently
from build wall. At the deadline issue SIGINT and wait for the graceful checkpoint. If the
host is unhealthy, the operator may stop earlier, but the reason and actual monotonic wall
must be recorded. Do not extend the deadline silently. If a root is still active when the
stop is requested, its final status is censored unless it completes before the checkpoint;
roots never reached are `not_attempted`.

A complete run writes the final artifact only after reload, symmetry, bracket, orbit-clash,
and unfilled checks pass. A partial run writes no complete-oracle artifact; it writes the
checkpoint and a report usable for the next run. T936 closes `blocked` when the deadline or
an unrecoverable host stop occurs, with the partial curve committed in its research report.

**Acceptance arm A8 (stop policy):** red-first suppresses the stop marker or labels an
interrupted checkpoint “complete”; the report validator must reject it. Green exercises the
stop path on a disposable arm and produces either a complete artifact with all statuses
closed or an explicitly blocked partial with the split above. **Catches:** a successful
process exit being mistaken for a complete oracle and an unreported censored tail.

### N9 — Detached ownership and complete provenance

No agent owns the computation interactively. Build the executable under the guarded build
procedure, then run that fixed binary as a detached job admitted on the drained host:
`nohup` (or equivalent), a recorded PID, `caffeinate -i -s` held for its lifetime, stdout
and stderr redirected to durable paths, and a heartbeat/log monitor independent of the
launch shell. The 4×4 process must run directly under the host admission policy rather than
under the 4 GB `tools/runner` RSS kill ceiling; use the runner for compilation, not as an
unrecorded compute cap. There must be no competing finisher or memory-heavy job.

The launch manifest and final/partial report must contain: git commit, executable SHA-256,
exact build and launch commands, all environment variables, host model/core/RAM state,
start/stop timestamps, PID, checkpoint/output/log paths, checkpoint and artifact hashes,
thread count and partition, build wall, finisher wall, peak RSS, per-thread node totals,
representative and status counts, total nodes over completed roots, maximum completed-root
nodes, bracket failures, orbit clashes, and the host-sleep/caffeinate assertion. Use
Black-positive score conventions in any value dump; do not report a sign-flipped side as a
second score.

**Acceptance arm A9 (provenance):** red-first changes the executable after launch, removes
the PID/log/hash record, or leaves a required field empty; the consumer must refuse the
run report. Green reloads the recorded hashes and checks every required field against the
log and checkpoint. **Catches:** T924's agent-held bash call, untraceable tree state, stale
binaries, missing RSS/host context, and a result that cannot be checked by a non-runner.

**Armed acceptance count: 9 arms (A1–A9).** Each arm has a deliberate red condition,
a green production condition, and a named historical incident it would catch. The 4×4
number gate is closed unless A1–A7 are green; A8–A9 are required for the run's final
classification and report.

## 3. Run sequence

1. Freeze and record the clean source commit and host admission. Build one ReleaseFast
   executable with the guarded build command; hash it. No source edits occur during the run.
2. Launch A5's 4×3 round-robin null arm detached. Verify its deterministic counts, speed
   window, and host state.
3. Launch A6's 4×3 contiguous seeded-defect arm. Verify both imbalance ratios and equal
   node totals.
4. Launch A7's disposable 4×3 SIGINT/resume arm. Verify checkpoint survival and resume.
5. Only after those controls are pasted into the run report, launch the 4×4 arm with:

   ```sh
   RETRO_PARALLEL=1 RETRO_4X4=1 RETRO_SOUND=1 \
   RETRO_PARALLEL_THREADS=16 RETRO_PARALLEL_BUDGET=0 \
   RETRO_PARALLEL_PROGRESS=1000 RETRO_PARALLEL_CKPT=<run>/4x4.checkpoint.wzo \
   RETRO_PARALLEL_OUT=<run>/4x4.wzo <fixed-binary>
   ```

   The 4×4 output and checkpoint paths are run-local, never the committed `data/` paths.
   The process is detached and monitored; the build phase is timed separately.
6. At completion or the declared stop, reload the checkpoint/artifact, run all validators,
   calculate the status split and per-thread imbalance, hash every durable file, and write
   the research report. A complete result may be used for the subsequent #2 auditor; a
   partial result is explicitly blocked and remains a useful censored measurement.

## 4. Reporting rules

The final report must state the measured 4×4 result as **wall, completed-root nodes,
closed/censored/not-attempted split, per-thread imbalance, and peak RSS**. It must not quote
T924's 202.5–1,620 h or T929's 26.8–214.7 h as an expectation for this run. Those are
single-threaded sample projections/lower bounds, not a substitute for the measured wall.
For context only, the checked history is: T924 sampled 1,287 roots, with 125 capped at
20,000,001 nodes; T929 found those were 9.71% of samples but 92.6% of measured nodes and
corrected the population-weighted lower-bound projection to 26.8–214.7 h; T930 measured
11.54× round-robin scaling at 4×3; T932's production 4×3 reading is the null baseline
specified in A5. Every number in the T936 report must retain its denominator and source
(run log, checkpoint, or validator output).

The report must not call the output “the real-game value.” It is a fresh-start table or
partial fresh-start table under this ruleset, and any remaining L/H bracket is reported as
such. A completed finisher result still requires the mandatory independent #2 auditor
before claims about finisher soundness or a proven 4×4 table are promoted.

## 5. Alternatives rejected

- **20M per-root cap:** rejected because it censors the pathological tail and invites the
  exact T924 reporting error. A higher finite cap has the same semantic defect; no cap is
  the clean measurement, with global-stop censoring reported explicitly.
- **A sampled 4×4 run plus a weighted projection:** rejected because T929 already corrected
  the sampling arithmetic and still left the tail unmeasured. T936 exists to remove the
  sampling denominator.
- **Contiguous partition or serial execution:** rejected as the primary path. T930/T932
  measured the scheduling imbalance and the round-robin production fix; contiguous remains
  only as A6's known-bad control.
- **Writes-on or dependency-guarded reuse:** rejected because they answer a different,
  respectively unsound or Track B, question. They are not T936's writes-off measurement.
- **An interactive agent-held job:** rejected because T924 demonstrated that it can occupy
  a lane and exit without evidence. Detached ownership, durable logs, and checkpoints are
  required.
- **Running through the runner's default compute ceiling:** rejected because an RSS kill
  would be an undocumented censoring mechanism for the large 4×4 working set. Guarded
  compilation and separately admitted detached execution preserve observability.

## 6. Explicitly out of scope

This specification does not change `src/retro.zig`, implement a scheduler, run the solve,
perform a Track B comparison, prove finisher soundness, run the #2 auditor, promote an
artifact into `data/`, establish PSK/history-independent real-game values, infer orbit-size
distributions, or decide 5×5 feasibility. It also does not hide or rewrite the T924 → T929
→ T930 → T932 correction arc. Those are follow-on work or epistemic claims with their own
gates.
