# T936 spec — run 4×4.D3 (writes-off finisher, full population) to completion

**Author:** deepseek-v4-flash/T970 (Race A sealed arm, dsflash). **Date:** 2026-08-25.
**Landmark:** advances `L2 (proven 4x4 values)` — the row that converts three rows of projection
into one measurement. **Question:** *what is the 4×4 writes-off finisher's real wall, and does it
close every ko-sensitive root?*

This document is the executable spec for T936. Every number below was checked against this
repository (sources cited inline). **Do not trust any number here that does not survive a re-check
against those sources; if one fails, stop and record it.** Decisions are made, not deferred; the
implementer executes, does not re-decide. Armed count: **6 acceptance arms** (§7), one per
normative decision.

---

## 1. Measured history the spec is built on (all verified 2026-08-25)

| row | measured | source |
|---|---|---|
| T924 | 4×4 writes-off: 125 of 1,287 sampled roots unsolved at a 20,000,001-node cap; **202.5–1,620 h** single-threaded projection (unweighted mean 2,139,677.3 nodes/root, 262.90 ns/node) | `docs/evidence/T924/summary.csv` (`samples=1287,solved=1162,skipped=125,max_root=20000001`; `projected_wall_h=[202.502,1620.020]`) |
| T929 | population-weighted mean **282,104.8 nodes/root, 7.585× lower → 26.8–214.7 h** single-threaded (lower bound). The 125 capped roots are **9.71% of samples but 92.6% of measured nodes** (2,500,000,125 of 2,700,272,692) | `docs/research/4x4-d3-weighted-projection.md` §3; arithmetic checked: 125/1287 = 9.71%, 2,500,000,125/2,700,272,692 = 92.58% |
| T930 | `finishParallel` scales **5.10× at 18 cores contiguous, 11.54× at 16 round-robin**; cause is a deepest-first work list piling cheap roots onto low thread ids (contig@16 busiest/mean = 3.05, rr@16 = 1.20); residual loss is memory latency; **4×4 realistically ~1–6 days** | `docs/research/parallel-finisher-cost.md`; `docs/evidence/T930/sweep.csv`, `imbalance.txt` |
| T932 | round-robin landed in `src/retro.zig` (commit `cb5a307`); **production reproduces 11.64× at 4×3** (rr@16 3,064 ms vs serial 35,670 ms); node counts **byte-identical** across 1/16/18 threads: 21,578 roots, 183,065,016 nodes, 0 bracket-fail, 0 orbit-clash | `docs/evidence/T932/production-4x3.csv`, `PROVENANCE.md`; `git show cb5a307` |

**Work-list size at 4×4 is a measurement, not the slot count.** T924's population `pop=10367922`
is the ko-sensitive *slot* count (5,183,961 per side × 2). The finisher's work list is
orbit-representatives: at 4×3, 170,276 slots → **21,578 orbit reps** (~7.9× dedup). The brief's
"480× more work items" is 10,367,922/21,578 = 480.4 — a slot-vs-rep comparison, **not** the
work-item ratio. The 4×4 orbit-rep count is unknown until the run prints
`finishParallel: partition=... (N orbit reps -> M threads)`; by the 4×3 ratio expect
**~1.3M orbit reps**. The run records the printed N; no assumption.

**Memory:** T930 estimates 4×4 tables ~0.8 GB + ~0.5 GB per-thread context → ~10 GB at 18 threads
plus per-thread output buffers (16 × 4 × 43,046,721 B ≈ 2.75 GB). Declare **16 GB** for admission
and RSS ceiling. Host: Apple M5 Max, 18 cores (6P+12E), 48 GB, drained (arbiter admits only T936).

---

## 2. Normative decisions

### D1. Node cap: NONE (`RETRO_PARALLEL_BUDGET=0`)

The 20 M cap was a choice, not a wall of nature; T929 showed the true cost of the 125 capped roots
is **unknown above the cap**, and folding the cap into a mean inflated T924's headline 7.585×.
Any finite cap re-creates the censoring this row exists to remove, and "a cap high enough that it
is not reached" is unprovable in advance. **Decision: no per-root node cap.** The engine semantics
are confirmed in `src/retro.zig` (`if (ctx.budget != 0 and ctx.nodes > ctx.budget) return
error.Budget;` — budget 0 = never capped; set `RETRO_PARALLEL_BUDGET=0`).

**Consequence:** a pathological root runs until it closes or the run is stopped by the wall rule
(D4). Its true cost is then *measured*, never assumed. If a root is still open at the stop point it
is **censored by wall**, not by node budget, and reported per D2.

### D2. Censored-root reporting: closed/censored split, never a folded mean

**Decision:** the run's result is stated as **measured wall, measured nodes, and the
closed/censored split** — never a single projected range (T936 acceptance §2). A censored root
(open at the stop point) is reported as a **count + per-layer distribution**, never folded into
any mean or projection; any projection derived from the run is explicitly labeled a lower bound
with its denominator. This is the exact correction T929 applied to T924 (7.585×).

### D3. Controls prove the instrument before any 4×4 number is believed

Three controls, all on the 4×3 rung through the **same detached driver** the 4×4 run uses, all
green before the 4×4 job launches (T936 acceptance §1):

1. **Null control** — 4×3, `RETRO_SOUND=1` (writes-off), round-robin (default), 16 threads,
   `RETRO_PARALLEL_BUDGET=0` (the exact 4×4 env). Must reproduce T930/T932's node counts
   **byte-for-byte** (21,578 roots, 183,065,016 nodes, 0 bracket-fail, 0 orbit-clash) and a
   speedup of **11.6× ± 10%** ([10.4, 12.8]) at 16 threads. *What it catches:* engine regression
   since `cb5a307`, env misconfiguration (wrong board/sound/threads/budget), host-state
   contamination, a broken detached path (driver, caffeinate, logging).
2. **Seeded-defect control** — same 4×3 arm with `RETRO_PARTITION=contig`. Must be
   **distinguishable** by the per-thread node-count imbalance ratio: rr ≤ 1.5 vs contig ≥ 2.5
   (measured 1.20 vs 3.05; threshold 1.60, the T932 regression's approach). *What it catches:* an
   instrument that cannot tell 5.1× from 11.5× — it would certify the wrong partition for 4×4.
3. **Killed-run control** — SIGINT the detached 4×3 job mid-finisher once, on purpose. Must show:
   the process exits 0 with `INTERRUPTED — checkpoint saved`; the checkpoint file exists with the
   finished count advanced; the log survives with per-thread lines; a relaunch resumes and the
   final totals are byte-identical to the uninterrupted arm. *What it catches:* flush-on-completion
   (T924's exact defect: exited 0 having written nothing), a missing/broken SIGINT handler, a
   corrupting resume path.

### D4. When to stop: 120 h finisher wall, then checkpoint and close blocked with the partial curve

T930's honest 4×4 estimate is **~1–6 days** (17.5–140 h optimistic at 11.54×, degraded by the
larger working set). **Decision: total finisher wall budget = 120 h** (sum of the `({d}ms)` solve
walls across segments, build excluded — the T930 convention), with a calendar ceiling of ~132 h
including segment builds. At the budget: send SIGINT, wait for the checkpoint, then **close
`blocked` with the partial curve committed** (T936 acceptance §3). If the finisher completes
earlier (`artifact OK` + `reload IDENTICAL`, skipped=0), close normally with the artifact.

**Incremental flush is mandatory, not optional** (T924's lesson: a run that writes only on
completion writes nothing when it is killed; T927: every wall from a sleeping host is suspect).
The production engine checkpoints only on completion or SIGINT, so **the run is segmented**: the
driver SIGINTs the finisher every **6 h of solve wall**, verifies the checkpoint advanced, and
relaunches (the engine's resume path loads the checkpoint and skips `FLAG_FROM_FORWARD` roots).
Per-segment overhead = the 509 s build (measured, `docs/evidence/T924/summary.csv`:
`build,4x4,...,ms=509191`) → ~20 segments × 509 s ≈ 2.8 h ≈ 2.3% of 120 h. A hard kill loses at
most one 6-h segment. `caffeinate -i -s` is held for the entire run (asserted, T927); the driver
records `sleeps_during_run` from `pmset -g log`; any sleep found marks the affected wall suspect.

### D5. What the run must record (checkable by someone who did not run it)

Per T928 the job record lives in `$JOB_DIR/jobs.jsonl`: **pid, command (arg array), log path,
started_at**. In addition, the driver emits one **machine-readable summary line per segment**
(stdout = data): segment #, UTC start/end, solve wall ms, `solved/filled/skipped/single_ko/nodes/
max_root`, per-thread max/mean imbalance ratio, checkpoint sha256. The final report records:

- **git commit of `src/retro.zig`** and the build command + binary sha256 (built once under
  `tools/runner` before launch, per AGENTS.md ad-hoc build rule);
- the full env: `RETRO_PARALLEL=1 RETRO_SOUND=1 RETRO_PARALLEL_THREADS=16 RETRO_PARALLEL_BUDGET=0
  RETRO_PARALLEL_PROGRESS=1000 RETRO_PARALLEL_CKPT=<untracked path> RETRO_PARALLEL_OUT=<untracked
  path>` (`RETRO_PARTITION` unset = round-robin; `RETRO_DEPS` unset = Track A);
- measured **wall** (finisher solve ms, summed), **nodes**, **closed/censored split** (from the
  final checkpoint census + segment summaries), **per-thread imbalance ratio**, **peak RSS**
  (driver samples `ps -o rss=` every 60 s; ceiling 16,384 MB), **host state asserted** (arbiter
  ledger snapshot showing only T936, caffeinate held, load average, `sleeps_during_run`);
- the work-list size (the partition line's orbit-rep count) — a measurement, per §1;
- **the final artifact + checkpoint hashes** and their paths.

All load-bearing numbers are **promoted into `docs/evidence/T936/`** (run record, per-segment
summaries, log, hashes, PROVENANCE) and cited from there — never from the disposable log (T928:
"do not cite a disposable log as evidence").

### D6. Detached, not agent-held

**Decision: the run is a detached job per T928** (T936's brief: "needs T928", "No agent holds
this compute"). A driver script (the job) is launched with the T928 `job_start` convention:
`nohup bash tools/t936-4x4-driver.sh > $JOB_DIR/job-t936.log 2>&1 &`, pid + command + log +
started_at recorded in `$JOB_DIR/jobs.jsonl`; liveness is `ps -p`; the log is the output. **No
agent lane blocks on the finisher** — T924 held a lane for 4,110 s and exited 0 having written
neither deliverable; that failure mode is the reason this decision exists. When the job's pid is
gone, the write-up (deliverables §8) is done from the promoted evidence.

---

## 3. Driver contract (the only new artifact)

`tools/t936-4x4-driver.sh` (~60 lines bash): (1) assert host drained — `tools/runner
--arbiter-status` shows only T936, no sweep; (2) hold `caffeinate -i -s`; (3) admit
`tools/runner --arbiter-admit --ram-mb 16384 --arbiter-id T936` (release at end); (4) loop:
launch the finisher with the §D5 env; run until 6 h solve wall or child exit; on wall → SIGINT
the finisher pid (never the group); wait for exit; verify checkpoint mtime/hash advanced and the
log carries `INTERRUPTED — checkpoint saved`; emit the segment summary line; relaunch to resume;
(5) stop when the finisher exits 0 with `artifact OK` and `reload IDENTICAL` (success), or total
finisher wall ≥ 120 h (SIGINT, checkpoint, close blocked with partial curve); (6) sample RSS
every 60 s; if > 16,384 MB, SIGINT and record (graceful, never SIGKILL a checkpointed run); (7)
record `sleeps_during_run` from `pmset -g log` at exit. The driver is committed under
`docs/evidence/T936/` with the run record (evidence in git). Its SIGINT/resume behavior is
proven by the killed-run control (D3.3) before the 4×4 job launches.

---

## 4. Sequence of execution

1. Build `src/retro.zig` at HEAD under `tools/runner` (`zig build-exe -O ReleaseFast`); record
   commit + binary sha256.
2. Null control (D3.1) on 4×3 through the driver. **Green required.**
3. Seeded-defect control (D3.2) on 4×3. **Green required.**
4. Killed-run control (D3.3) on 4×3. **Green required.**
5. Launch the 4×4 detached job (D6). Do not block; poll `ps -p` and the log.
6. On completion or wall-stop: promote evidence to `docs/evidence/T936/`, write deliverables (§8).

---

## 5. Host state and safety

- Host must be **drained**: arbiter ledger admits only T936 (`tools/runner --arbiter-status`);
  no fleet lanes, no sweep. Check, do not assume (T930 discipline).
- `caffeinate -i -s` held for the whole run (T927); `sleeps_during_run` recorded; a non-zero
  sleep count marks the affected wall suspect in the report.
- RSS ceiling 16,384 MB (declared for admission and enforced by the driver's sampling) — the
  2026-07-29 panic precedent (`docs/infra/host/incident-2026-07-29.md`) is why the ceiling exists.
- The job never writes to `data/` or `artifacts/` (no silent writes; no `.wzo` overwrite).
  Checkpoint and out paths are explicit, under `untracked/`, hashed into `docs/evidence/T936/`.

---

## 6. Out of scope (deliberately)

- **No engine changes.** The run uses `src/retro.zig` as committed; the driver script is the only
  new artifact. No new seams in the finisher (the #2 auditor gate applies to finisher changes;
  none are made).
- No Track B (`RETRO_DEPS`) comparison — a follow-on row, per T924's follow-on list.
- No writes-on arm (T912: unsound under superko; it was a calibration control in T924 only).
- No 5×N, no ground-truth, no #2 auditor run (no finisher/memo change to audit).
- No re-derivation of the projection or orbit-factor measurement (the run's orbit-rep count and
  wall replace them by measurement).
- No `docs/epistemic/CLAIMS.md` edits — that is the row's absorption step, not this spec.

---

## 7. Acceptance arms (armed count: 6)

One arm per normative decision. Each: RED = what fails the arm; GREEN = what passes; incident =
the historical defect the arm exists to catch.

**Arm 1 (D1, node cap).** RED: any segment reports `skipped > 0`, or the report states a per-root
cap value. GREEN: `RETRO_PARALLEL_BUDGET=0` asserted in the recorded env; all segments report
skipped=0; censored set (if any) is wall-caused, not cap-caused. *Incident:* T924's 20 M cap
censoring 125 roots carrying 92.6% of measured nodes.

**Arm 2 (D2, censored reporting).** RED: the report states a single wall/node number with no
closed/censored split, or folds a censored root into a mean or projection. GREEN: measured wall +
measured nodes + closed/censored split, censored roots as count + per-layer distribution, any
projection labeled lower bound with denominator. *Incident:* T924's 202.5–1,620 h headline from a
7.585×-inflated unweighted mean.

**Arm 3 (D3, controls).** RED: any control fails and a 4×4 number is written anyway. GREEN: null
= byte-for-byte 21,578/183,065,016/0/0 + speedup ∈ [10.4, 12.8]; seeded = imbalance rr ≤ 1.5 vs
contig ≥ 2.5; killed = checkpoint + log survive SIGINT, resume byte-identical — all pasted into
the run doc before the 4×4 section. *Incident:* an instrument that cannot tell 5.1× from 11.5×
(T930's partition bug); T924 exiting 0 with neither deliverable.

**Arm 4 (D4, stop rule).** RED: run exceeds 120 h finisher wall without a checkpoint, or the row
closes without the partial curve committed. GREEN: at 120 h → SIGINT → checkpoint → partial curve
committed → close `blocked`; or completes earlier with `artifact OK`. *Incident:* T924 lane held
4,110 s and exited 0 having written neither deliverable; T927's 24 sleeps corrupting walls.

**Arm 5 (D5, recording).** RED: a load-bearing number cited only from the disposable log;
checkpoint/artifact hashes missing; job record (pid/command/log/started_at) missing. GREEN:
jobs.jsonl entry; `docs/evidence/T936/` holds run record, per-segment summaries, log, hashes,
host-state snapshot; every headline number traceable to a committed artifact. *Incident:* T13's
evidence destroyed in untracked/; the 43 volatile `/tmp` citations.

**Arm 6 (D6, detached).** RED: an agent lane blocks on the finisher. GREEN: job launched via
`job_start`, liveness via `ps -p`, no lane waits on it, write-up from promoted evidence after the
pid is gone. *Incident:* T924 (the worked example this arm exists to prevent).

---

## 8. Deliverables (T936)

1. `docs/research/4x4-d3-run.md` — measured wall, measured nodes, closed/censored split, host
   state, controls pasted green, the correction arc T924 → T929 → T930 → T932 → this row named and
   preserved. **Supersedes the projection in `4x4-d3-tractability.md` by naming it**, and
   `4x4-d3-tractability.md` gains a pointer line. Neither is edited to hide the correction
   history (T936 acceptance §4).
2. `findings/T936-4x4-d3-run.json` — schema per `findings/README.md`, with the run's measured
   values and evidence paths.
3. `docs/evidence/T936/` — driver, run record, per-segment summaries, log, checkpoint/artifact
   hashes, PROVENANCE.

If the run does not finish in budget, the row closes **`blocked` with the partial curve
committed** — a censored run honestly reported is a result; a finished-looking number that hides
a cap is not (T936 acceptance §3).
