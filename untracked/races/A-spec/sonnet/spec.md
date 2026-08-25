# Spec for T936 — run 4×4.D3 to completion

**Author:** claude-sonnet-5/T972 (sealed arm "sonnet" of Race A). **Date:** 2026-08-25.
**Landmark:** `L2 (proven 4×4 values)`. This document specifies; it does not build or run anything.

## Answer up front — the six decisions

| # | decision | value |
|---|---|---|
| 1 | node cap | **unchanged: 20,000,000/root** (`RETRO_PARALLEL_BUDGET` default). Every capped root is a **censored** observation, never a solved one. |
| 2 | censored reporting | a capped root's table slot stays `UNDEF`. No mean, no projection, no fill-value is written for it. The run's own summary reports `closed` and `censored` as two counts, never blended. |
| 3 | controls | null (4×3 byte-identity + speedup ≥ 10.5×), seeded-defect (round-robin vs `RETRO_PARTITION=contig` imbalance ratio, threshold 1.40, **measured at the 4×3 rung itself**, not the 3×3 CI proxy), killed-run (`kill -INT` only — the one signal the binary handles — followed by checkpoint-resume verification) |
| 4 | when to stop | run in **bounded segments** (§5), each closed by a deliberate `SIGINT`; hard stop at **240 h (10 days) of cumulative segment wall** without full closure → close `blocked` with the partial checkpoint committed |
| 5 | what to record | per-segment: wall, node count, per-thread imbalance ratio, tree-walked peak RSS, closed/censored split, host state, exact command, checkpoint identity (§6) |
| 6 | detached or agent-held | **detached**, per T928: `job_start` wrapping `tools/goban-scaling-capture.sh` wrapping the `retro` binary, itself under a segmenting loop (§5) that is *also* a detached process, not an agent. No agent holds any part of this wall. |

Ten acceptance arms follow, one per normative sub-decision. Armed count: **10**.

## 1. The measured history, checked against the repository

| row | claim in the brief | checked against | verdict |
|---|---|---|---|
| T924 | 125/1,287 roots unsolved at 20,000,001-node cap; 202.5–1,620 h projected | `docs/research/4x4-d3-tractability.md` §"Answer", §"two arms" table | **matches** |
| T929 | population-weighted mean 282,104.8 nodes/root, 7.585× lower → 26.8–214.7 h; 125 capped roots = 9.71% of samples / 92.6% of nodes | `docs/research/4x4-d3-weighted-projection.md` §3, §4 | **matches** |
| T930 | `finishParallel` 5.1× at 18 cores contiguous, 11.5× at 16 round-robin (measured 11.54×) | `docs/research/parallel-finisher-cost.md` §"Results" table | **matches** |
| T932 | round-robin landed in `src/retro.zig` (commit `cb5a307`), production reproduces 11.6× at 4×3 | `findings/T932-finishparallel-roundrobin.json`, `docs/evidence/T932/PROVENANCE.md`; production measured **11.64×** at 16 threads vs T930's harness 11.54×, contig **5.11×** vs T930's 5.10× | **matches**, and the production number is *slightly better* than the harness, not worse |

**One correction to the brief's own framing, checked against source, not assumed:** `RETRO_4X4=1` is documented in `src/retro.zig`'s header comment (line 3246) but is **never read** by `runParallel` (lines 3253–3291). Dispatch is: `RETRO_3X3` set → 3×3; else `RETRO_4X3` set → 4×3; else → **4×4 is the default**. Setting `RETRO_4X4=1` is harmless but does nothing; leaving both `RETRO_3X3` and `RETRO_4X3` unset is what actually selects 4×4. An implementer who searches for "the flag that selects 4×4" and sets only that flag, while also carrying over `RETRO_4X3=1` from a copy-pasted 4×3 control command, would silently re-run 4×3 believing they had launched 4×4. **Arm 0** below guards exactly this.

> **Arm 0 — dispatch selection.** Red: launch with `RETRO_PARALLEL=1 RETRO_4X4=1 RETRO_4X3=1` (a plausible copy-paste from the 4×3 control) → the run silently solves 4×3 (21,578 roots) with a 4×4-shaped log header (`==== parallel artifact 4x4 -> ... ====` is NOT printed; `4x3` is), and completes in ~3 s instead of running for hours. Green: launch with `RETRO_PARALLEL=1` and **neither** `RETRO_3X3` nor `RETRO_4X3` set → the startup line reads `==== parallel artifact 4x4 -> data/oracle-4x4-parallel.wzo ====`. The must: **grep the first log line for `4x4 ->` before trusting anything else the run reports.** Incident this catches: a multi-hour segment silently re-measuring 4×3 and reporting it as 4×4 progress — worse than T924's near-miss because it would look like slow-but-real 4×4 progress rather than an obvious early exit.

## 2. Decision 1 — the node cap

**20,000,000 nodes/root, unchanged.** Two alternatives considered and rejected:

- **Raise the cap** (e.g. 10×, to see if capped roots close). Rejected: T929 §4 shows the capped
  roots concentrate in layers 13–15, where *solved* roots are nearly free (mean 63–274,657 nodes)
  and *capped* ones hit the ceiling — a bimodal population, not a slow-but-finite one. There is no
  measurement suggesting 200M nodes closes what 20M did not; raising the cap only lengthens the
  segment that finds out, and the register's own `≤ 8 h` target is already unreachable at the
  current cap (T929 §5). Raising it trades a longer run for the same "not tractable" answer.
- **Drop the cap entirely** (`RETRO_PARALLEL_BUDGET` unset/huge). Rejected outright: the brief's own
  §"What is already known" states the empty root alone exceeded 500M nodes in 146 s at a smaller
  probe; an uncapped root can run indefinitely and there is no mechanism to distinguish "slow" from
  "the memo-free walk never terminates in practice" without one. An uncapped run is not bounded, and
  §"When to stop" (Decision 4) requires a bound.

**Keeping the cap identical to T924/T929/T930/T932's** is also what makes this run *comparable* to
the four rows that established the projection — a different cap would make `docs/research/
4x4-d3-run.md` a new, disconnected data point rather than the promised measurement that resolves
the projection's own uncertainty.

> **Arm 1 — cap unchanged.** Red: a run launched with any `RETRO_PARALLEL_BUDGET` value other than
> `20000000` (including unset-but-not-default, if the binary's default ever drifts) is not this
> row's data — reject it before recording anything. Green: the launch command contains
> `RETRO_PARALLEL_BUDGET=20000000` **explicitly** (do not rely on the source default; defaults
> drift, this line does not). Incident this catches: a future edit changes `src/retro.zig`'s
> hardcoded `20_000_000` and a run silently measures a different cap than every prior row, breaking
> comparability without anyone noticing until the numbers don't line up.

## 3. Decision 2 — how a censored root is reported

**A capped root's `vb`/`vw` slot stays `UNDEF`.** This is what the shipped code already does:
`finishParallel`'s `worker()` (retro.zig:1450–1466) treats a `Budget` error as `budget_skipped`
and marks `FLAG_TRIED_SKIP` — it does **not** write any value into `out.vb`/`out.vw` for that root's
orbit. The merge step (retro.zig:1696–1716) only fills `t.vb`/`t.vw` from non-`UNDEF` entries, so a
capped root's slots remain `UNDEF` in the table forever, and `undef_legal` (retro.zig:3423–3425)
counts them at validation time. **No code change is needed for this decision — it is already the
behavior; the failure mode T924 corrected (folding the cap into the mean) lived in the *reporting*,
not the table.**

What must not happen downstream: `docs/research/4x4-d3-run.md` reporting a single "mean nodes/root"
or a single "projected wall" number that divides total nodes by *all* attempted roots (closed +
censored) without separating them — that reproduces T924's exact defect (`docs/research/
4x4-d3-tractability.md` §"the mean was unweighted... T929 corrected it") one level downstream, on
real instead of sampled data.

> **Arm 2 — no blended mean.** Red: the run's summary states a single "mean nodes/root" figure
> computed as `total_nodes / (closed + censored)` and calls it representative of anything other
> than itself. Green: the summary reports **three** numbers separately — `closed` (count, sum
> nodes, mean nodes/closed-root), `censored` (count, each recorded at exactly the cap, 20,000,000 —
> stated as a **lower bound** on that root's true cost, never as its cost), and `total` (sum of
> both, labeled as a **floor**, matching T929 §4's "floor conclusion survives"). Incident this
> catches: T924's own headline defect, recurring in the write-up of real data after the run
> mechanism itself got it right.

## 4. Decision 3a — the null control (4×3 reproduction)

Reproduce T930/T932's 4×3 measurement through the **same detached path** this row will use for
4×4 (§5–§6), not a bespoke invocation — otherwise a discrepancy cannot tell "the path is wrong"
from "the measurement is wrong."

```sh
zig build-exe -O ReleaseFast -femit-bin=/tmp/weizigo/retro_4x4 src/retro.zig
tools/goban-scaling-capture.sh 4 3 writes-off T936-null -- \
  env RETRO_4X3=1 RETRO_PARALLEL=1 RETRO_PARALLEL_THREADS=16 RETRO_SOUND=1 \
      RETRO_PARALLEL_BUDGET=20000000 RETRO_PARALLEL_PROGRESS=0 \
      RETRO_PARALLEL_CKPT=/tmp/weizigo/t936-null.ckpt.wzo RETRO_PARALLEL_OUT=/tmp/weizigo/t936-null.wzo \
      /tmp/weizigo/retro_4x4
```

`tools/goban-scaling-capture.sh` (T926) is the wrapper of record here, not a bespoke script: it
already tree-walks RSS, holds `caffeinate`, and observes `RETRO_SOUND` against the claimed regime
rather than trusting the argument (T926.D3) — reuse it instead of re-deriving what it already
fixed.

**Tolerance, stated as a number, not deferred:** node/orbit counts must be **byte-identical** to
T930/T932 (21,578 orbit reps, 183,065,016 nodes — determinism is exact, writes-off has no shared
mutable memo, so there is no variance to tolerate). Wall-clock speedup at 16 threads must be
**≥ 10.5×** serial (10% under T932's measured 11.64×, giving margin for host variance without
loosening so far that a real regression — e.g. a partial revert to contiguous chunking — passes
unnoticed).

> **Arm 3 — null control.** Red: node/orbit counts differ from `183,065,016` / `21,578` by even one,
> or speedup < 10.5×. Green: exact count match and speedup ≥ 10.5×. The must, per the brief's own
> acceptance §1: **this arm is pasted, green, before any 4×4 number is written down anywhere,
> including a partial one.** Incident this catches: T936's brief states plainly — "If 4×3 does not
> reproduce, 4×4 is not measuring what this brief says it measures, and the row stops there."

## 5. Decision 3b — the seeded-defect control (partition imbalance)

`tools/regression-finishparallel-partition.sh` already implements this control, but at **3×3**
(622 roots) for `zig build test` speed — a CI proxy, not this row's rung. Reuse its exact method
and threshold (1.40 max/mean) but **run it at 4×3**, the null control's own rung, so the same
invocation that proves determinism also proves the imbalance detector isn't vacuous:

```sh
tools/goban-scaling-capture.sh 4 3 writes-off T936-seed-rr   -- env RETRO_4X3=1 RETRO_PARALLEL=1 RETRO_PARALLEL_THREADS=16 RETRO_SOUND=1 RETRO_PARALLEL_BUDGET=20000000 RETRO_PARALLEL_PROGRESS=0 RETRO_PARALLEL_CKPT=/tmp/weizigo/t936-rr.ckpt.wzo  RETRO_PARALLEL_OUT=/tmp/weizigo/t936-rr.wzo  /tmp/weizigo/retro_4x4
tools/goban-scaling-capture.sh 4 3 writes-off T936-seed-contig -- env RETRO_4X3=1 RETRO_PARALLEL=1 RETRO_PARALLEL_THREADS=16 RETRO_SOUND=1 RETRO_PARALLEL_BUDGET=20000000 RETRO_PARALLEL_PROGRESS=0 RETRO_PARTITION=contig RETRO_PARALLEL_CKPT=/tmp/weizigo/t936-contig.ckpt.wzo RETRO_PARALLEL_OUT=/tmp/weizigo/t936-contig.wzo /tmp/weizigo/retro_4x4
```

Read the `finishParallel: thread N: … nodes=X` stderr lines (one per thread; retro.zig:1680–1684)
and compute `max/mean` across threads, exactly as the wired regression does.

> **Arm 4 — seeded-defect control.** Red: `RETRO_PARTITION=contig` at 4×3/16 threads produces
> `max/mean ≤ 1.40`. Green: round-robin (default) produces `max/mean ≤ 1.40` **and**
> `RETRO_PARTITION=contig` produces `max/mean > 1.40` at the same rung. Both must hold — if the
> instrument cannot tell them apart at the rung that matters, it does not certify the 4×4 arm
> either (T936 brief, verbatim). Incident this catches: T930's own defect (5.1× ceiling from
> deepest-first contiguous chunking) reappearing at 4×4 undetected because the guard was only ever
> proven at the CI-speed 3×3 proxy.

## 6. Decision 3c — the killed-run control

**The binary handles exactly one signal for graceful shutdown: `SIGINT`.** `installParallelSigint`
(retro.zig:2184–2190) calls `std.posix.sigaction` only for `std.posix.SIG.INT`. There is no handler
for `SIGTERM` (the default signal sent by a bare `kill <pid>`) or `SIGHUP`. `SIGKILL` cannot be
handled by any process. **This is the single most consequential fact in this spec**, because the
brief's controls require showing partial results survive a kill, and two of the three ways an
agent instinctively kills a process (`kill`, `kill -9`) do **not** trigger the checkpoint save that
`kill -INT` does.

The mechanism, read from source: `parallel_interrupt` is a global atomic; each worker checks it
between root solves (retro.zig:1369–1373) and breaks; `finishParallel` joins all workers, **merges
whatever they had produced into `t`** (retro.zig:1686–1717 — this runs regardless of whether the
loop completed or was interrupted), and `parallelBoard` then writes **one** checkpoint
(retro.zig:3407–3412) covering everything merged so far, before returning. So `kill -INT` gives a
full, clean save of all progress up to that instant; anything else gives none.

> **Arm 5 — killed-run control, correct signal.** Red: `kill -TERM <pid>` (or plain `kill <pid>`)
> sent to a running 4×3 segment — the process exits immediately (no `INTERRUPTED — checkpoint
> saved` log line), and `RETRO_PARALLEL_CKPT`'s file is whatever existed before the run started
> (i.e., unchanged — this arm is run against a fresh ckpt path so "unchanged" means **absent**).
> Green: `kill -INT <pid>` sent to a running 4×3 segment — the log shows
> `finishParallel: INTERRUPTED — merging partial results.` followed by
> `INTERRUPTED — checkpoint saved. Re-run to resume.`, and the checkpoint file exists and is
> non-empty. The must: **every deliberate stop of this row's compute, for the rest of its life,
> is `kill -INT`, never bare `kill` or `kill -9`.** State this in the job's own record (§7) so a
> different operator/agent stopping it later does not silently discard a segment.

> **Arm 6 — checkpoint resume is real, not just present.** Red: re-launching against the same
> `RETRO_PARALLEL_CKPT` path re-solves roots already merged before the interrupt (visible as
> `solved` climbing past what Arm 5's segment reported, for roots that should already carry
> `FLAG_FROM_FORWARD`). Green: the resume log line (`resume: <path> loaded — N finished, N
> skip-marked`, retro.zig:3384) reports `N finished` matching Arm 5's `solved` count, and the
> second segment's own `finishParallel: solved=` total, added to the first segment's, matches a
> single uninterrupted run's total (compare against Arm 3's null-control baseline, same rung).
> Incident this catches: a checkpoint that is written but silently ignored on load (a path
> mismatch, a header-size-mismatch fallthrough at retro.zig:3385–3387) would make every segment
> after the first restart from zero — for a multi-day 4×4 run this is the difference between one
> stall costing a segment and one stall costing the entire run.

> **Arm 7 — the wrapper records the kill honestly.** Reuse T926's own regression arm C (child
> receives a fatal signal mid-run) at this row's actual invocation, not just its unit test: after
> Arm 5's `kill -INT`, the `tools/goban-scaling-capture.sh` row in the (scratch, per §"reproduction"
> below — never the live ledger during controls) ledger shows `killed_by` populated and
> `partial: true`. Green requires this because §7's segmenting loop uses this wrapper for every
> production segment, and a wrapper that loses the row on a graceful interrupt would silently erase
> this row's own audit trail of how many segments it took.

## 7. Decision 4 — when to stop, and the segmenting loop this requires

**The checkpoint is written once per segment, at the segment's end (interrupt or natural
completion) — never during it.** A `SIGKILL`, an OOM-kill, a panic, or a power loss at any point
inside a segment loses every root solved since that segment's start, because nothing inside
`finishParallel` persists incrementally (confirmed by reading it end to end, §6). At a 26.8–214.7 h
lower-bound wall (T929) this is not a corner case; over multiple unattended days it is close to
certain to matter at least once.

**Decision: the run is a sequence of bounded segments, each stopped deliberately by `kill -INT`
before it could be stopped by anything else.** This requires no code change — it is an operating
discipline built entirely from the existing checkpoint-resume path (§6, Arm 6), applied
repeatedly. **Segment length: 4 hours.** Rationale: short enough that a lost segment (the worst
case this scheme cannot prevent — a crash *inside* a segment, not caught by the deliberate
`SIGINT`) costs at most 4 h of a run measured in days; long enough that checkpoint save/reload
overhead (a few seconds for a table on the order of the ~0.8 GB T930 §"Working set" estimates for
4×4) is negligible against the segment.

The loop is itself the **detached job** (§8) — not an agent, not a human watching a clock:

```sh
# run-4x4.sh — the detached supervisor; launched once via job_start, then unattended.
SEGMENT_S=14400          # 4h
MAX_TOTAL_S=864000       # 240h / 10 days — Decision 4's hard stop
elapsed=0
while [ "$elapsed" -lt "$MAX_TOTAL_S" ]; do
    tools/goban-scaling-capture.sh 4 4 writes-off T936 -- env \
        RETRO_PARALLEL=1 RETRO_PARALLEL_THREADS=16 RETRO_SOUND=1 \
        RETRO_PARALLEL_BUDGET=20000000 RETRO_PARALLEL_PROGRESS=25000 \
        RETRO_PARALLEL_CKPT=data/oracle-4x4-parallel.checkpoint.wzo \
        RETRO_PARALLEL_OUT=data/oracle-4x4-parallel.wzo \
        /tmp/weizigo/retro_4x4 &
    child=$!
    sleep "$SEGMENT_S"
    if kill -0 "$child" 2>/dev/null; then kill -INT "$child"; fi
    wait "$child"
    elapsed=$((elapsed + SEGMENT_S))
    # stop early on natural completion: absence of "INTERRUPTED" in this
    # segment's log (goban-scaling-capture.sh's own log path) plus a
    # non-"PARTIAL"/non-"REFUSED" "artifact:" line means it finished.
done
```

(Shown as the exact command shape this decision requires, per the brief's "decide, do not hand the
implementer a menu" — not a script to write and commit; T936 builds nothing new either, per its own
brief, so this loop is launched by hand from this text, or is itself the one piece of glue T936's
worker is expected to type.)

**Hard stop: 240 h (10 days) of cumulative segment wall without full closure → close `blocked`**,
committing the last checkpoint and the segment log. 240 h is ~1.7–9× T930's "more realistically
~1–6 days" parallel estimate and ~1.1–9× T929's 26.8–214.7 h *lower bound* — generous enough to let
real variance (4×4's larger working set, per T930 §"Working set", is exactly the kind of thing that
could push wall past the optimistic end) play out without letting the row run indefinitely against
a target the register already states as `≤ 8 h` and which T929 already shows is unreachable at any
reading of the bracket.

> **Arm 8 — segment boundary is safe.** Red: a segment is allowed to run past `SEGMENT_S` with no
> `kill -INT` sent (the loop stalls on `sleep` past its own bound, or `kill -0` misreports a dead
> child as alive and skips the signal). Green: every segment in the run's log has a wall ≤
> `SEGMENT_S` + the bounded shutdown latency (≤ one root's remaining budget, §6), confirmed from
> the segment's own start/stop timestamps. Incident this catches: a segment silently becoming the
> unattended, unboundedly-long run this whole decision exists to prevent.

> **Arm 9 — the hard stop actually stops.** Red: cumulative segment wall exceeds `MAX_TOTAL_S` with
> the loop still launching new segments. Green: the loop's own log shows it exiting the `while` at
> or before 240 h, and `docs/research/4x4-d3-run.md` (if the row lands here) states `blocked`, not
> a bare absence of a doc. Incident this catches: the row silently consuming the host for weeks
> because nothing was watching the aggregate, only each segment.

## 8. Decision 6 — detached, and the shape of "detached" for a segmented run

**Detached, per T928, at two levels.** The `run-4x4.sh` loop (§7) is launched once via T928's
`job_start` (`docs/infra/host/detached-jobs.md`) — `nohup … > log 2>&1 &`, recording pid/command/
log/started_at in `$JOB_DIR/jobs.jsonl`. Each segment inside the loop is, in turn, wrapped by
`tools/goban-scaling-capture.sh`, which holds its own `caffeinate -i -w` for the segment's lifetime
(T927) and appends one ledger row per segment. **No agent holds any wall at any point** — not the
outer loop (a shell script, not a model), not a segment (the `retro` binary). An agent's
involvement is bounded to: launching the job once, and later reading `ps -p`, the log tail, and the
ledger rows to write up `docs/research/4x4-d3-run.md` — exactly T928's stated boundary
("Nothing about the analysis needed the model that ran the compute").

Why not agent-held: T924 is the worked example this row exists not to repeat — 4,110 s of one
lane's wall spent waiting on a single bash call, context spent by waiting alone, both deliverables
lost. A 4×4 run is 15–500× longer than T924's probe; holding it in an agent lane is not a smaller
version of that mistake, it is the same mistake at a scale that guarantees it.

## 9. What the run must record (Decision 5)

Per segment, in the `goban-scaling-capture.sh` ledger row (already emits most of this — T926) plus
the loop's own log:

- wall (segment), cumulative wall, start/stop timestamps, stop reason (`natural` | `interrupt-4h` |
  `interrupt-final`)
- `solved`, `budget_skipped` (censored), `single_ko`, `nodes`, `max_nodes` from the segment's
  `finishParallel:` summary line
- per-thread node counts (the `finishParallel: thread N:` lines) and their max/mean ratio
- `peak_rss_mb` (tree-walked, T926), `killed_by`, `partial` — straight from the wrapper
- host state: `caffeinate` held (wrapper-asserted), core/RAM (18/48 GB, `docs/infra/host/
  ram-policy.md`), fleet-drained assertion (arbiter admits only this job — record how that was
  confirmed, e.g. `bin/managent` kanban snapshot at segment start)
- exact command (the wrapper already stashes `CMDLINE_` including env assignments, T926 fix)
- checkpoint path + file size + mtime at each segment's end (a cheap proxy that the save actually
  happened and grew, without needing a full hash of a multi-hundred-MB file every 4 h)
- `src/retro.zig`'s git commit hash at build time (`zig build-exe` from a specific checkout — record
  it so a later re-run at a changed source is never mistaken for a repeat of this one)

At the run's end (closed or `blocked`): the closed/censored split by layer (readable from the
committed checkpoint via the same per-layer accounting T929 used, `src/colex.zig` layer offsets —
no solve needed to extract it), matching Decision 2's "never a blended mean."

## Out of scope

- **No code change to `src/retro.zig`.** Every control and every decision above is satisfiable with
  the binary as it stands at `cb5a307`. If a segment reveals the checkpoint/resume path is broken
  in a way Arm 6 would catch, that is a **new, separate row** — this spec does not pre-authorize a
  fix inside the run it is trying to measure.
- **Track B (dependency-guarded reuse) at 4×4.** Named in T924/T929's follow-ons as the next step
  after this row; out of scope here by the brief's own framing ("this row… converts three rows of
  projection into one measurement" — Track A only).
- **Raising or removing the node cap**, decided against in §2, not merely deferred.
- **A daemon, watchdog, or notification channel for the segmenting loop**, per T928's own boundary
  ("Do not build notification. A pid that is gone and a log that stopped growing is the signal.").
- **Automating the 240 h hard stop's `blocked` write-up.** The loop stopping is mechanical; deciding
  what the partial curve means is a judgement call for whoever closes T936, not this spec.
- **A precise wall-clock deadline for the *whole* row (T936) beyond the 240 h compute bound** — when
  the segments are scheduled (immediately, or after other host-drained work clears) is an operator/
  dispatch decision, not this spec's.

## Reproduction

Every command above uses scratch paths (`/tmp/weizigo/...`, `WEIZIGO_SCALING_LEDGER` unset only for
the real production segments in §7, which — by design — write to the live
`docs/infra/host/goban-scaling.jsonl`). Controls (§4–§6) MUST set `WEIZIGO_SCALING_LEDGER` to a
scratch path so their rows never land in the live ledger; only §7's production segments write
there, exactly as `tools/regression-finishparallel-partition.sh` and
`tools/regression-goban-scaling-capture.sh` already isolate their own test ledgers from it.
