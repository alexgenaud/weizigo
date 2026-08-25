<!-- sealed arm: untracked/races/A-spec/dspro/spec.md · worker deepseek-v4-pro/T969 · Race A -->
# Spec — run 4×4.D3 to completion (T936)

**Worker:** deepseek-v4-pro/T969 · **Date:** 2026-08-25 · **Landmark:** advances `L2 (proven 4x4 values)`.
**Specifies:** T936 (`what is the 4×4 writes-off finisher's real wall, and does it close every
ko-sensitive root?`). This document is a spec — the implementer builds and runs; nothing here was run.

## Answer up front — every decision made

| # | decision | answer |
|---|---|---|
| D1 | node cap | **none** (`RETRO_PARALLEL_BUDGET=0`, which the engine reads as unlimited) |
| D2 | censored-root reporting | **set membership** (count + per-layer tally), never a node count, never folded into a mean |
| D3 | controls | null + seeded-defect + killed-run, all on the 4×3 rung, **all green before any 4×4 number exists** |
| D4 | when to stop | complete (`skipped==0 ∧ unfilled==0`) **or** a pre-declared **72 h finisher-wall** stop → partial |
| D5 | recording | full command + host-state assertion + the finisher's own emitted lines + closed/censored split + peak RSS |
| D6 | agent or detached | **detached** (T928 job: pid + command + log + start; `ps -p` is the only liveness signal) |

Thread count is **16** everywhere (measured optimum: 11.5× at 16 vs 10.9× at 18, T930/T932).

## 1. Numbers checked against the repository (and two the brief got wrong)

Every load-bearing figure below was re-derived from committed evidence, not copied from the brief.

| fact | value | source |
|---|---|---|
| T924 sampled roots, capped | 1,287 sampled · 1,162 solved · **125 capped** at 20,000,001 | `docs/evidence/T924/summary.csv` |
| T924 measured nodes | 2,700,272,692 (the 125 capped roots carry 2,500,000,125 = **92.6%**) | `docs/evidence/T924/summary.csv`, T929 §4 |
| T929 weighted mean / wall | 282,104.8 nodes/root → **26.8–214.7 h** single-threaded (7.585× below T924) | `docs/research/4x4-d3-weighted-projection.md` |
| T930 scaling | contig **5.10× @18** · round-robin **11.54× @16** | `docs/evidence/T930/sweep.csv` |
| T932 production | rr@16 **3,064 ms / 11.64×** · contig@16 6,985 ms / 5.11× | `docs/evidence/T932/production-4x3.csv` |
| T932 determinism | **21,578 roots / 183,065,016 nodes / 0 bracket-fail / 0 orbit-clash / symmetry PASS**, byte-identical 1/16/18 | `docs/evidence/T932/PROVENANCE.md` |
| T932 imbalance @16 | rr slowest/mean **1.20** · contig **3.05** | `docs/evidence/T932/per-thread-16.txt` |

**Correction 1 — the work list is orbit representatives, not slots.** `finishParallel` builds a
deduplicated orbit-rep list; at 4×3 the full ko-sensitive population is 170,276 (slot,side) and the
work list is **21,578 orbit reps** (a 7.89× reduction: `num_syms=4` for the non-square goban × 2 for
colour inversion, `src/enumerate.zig:57`). At 4×4 `num_syms=8`, so the reduction is ~16×: the 4×4
work list is **~6.5×10⁵ orbit reps, not 10,367,922**. The brief's "480× more work items" divides the
4×4 *slot* count by the 4×3 *orbit-rep* count — mixed denominators. The correct work-item ratio is
~30× (~648k ÷ 21,578), and the run measures the exact number (the `finishParallel: partition=…
(N orbit reps …)` line). This does **not** change any projected wall — those already carry the orbit
factor — it only corrects the "work items" claim.

**Correction 2 — `RETRO_4X4=1` is a trap.** The parallel finisher dispatches on `RETRO_PARALLEL=1`;
its sub-dispatch is `RETRO_3X3=1` → 3×3, else `RETRO_4X3=1` → 4×3, else **4×4** (`src/retro.zig:3284`).
`RETRO_4X4=1` is checked only in the *non-parallel* `main()` path and routes to the census
(`run4x4`), **not** the finisher. The run must set `RETRO_PARALLEL=1` and set *neither* `RETRO_3X3`
nor `RETRO_4X3`. The comment at `src/retro.zig:3246` is stale.

**Verified mechanics the decisions rest on:** (a) `ctx.budget==0` means *no* per-root budget —
`src/retro.zig:452` (`if (ctx.budget != 0 and ctx.nodes > ctx.budget)`), so `RETRO_PARALLEL_BUDGET=0`
is the uncapped mode, not an accident; (b) a SIGINT handler sets `parallel_interrupt`, workers stop
between roots, partial results merge, and **the checkpoint is saved after the merge**
(`src/retro.zig:2172–2190, 3414`); (c) the checkpoint is written *once*, after `finishParallel`
returns — there is **no incremental checkpoint during the finisher**, which is why D4 requires the
SIGINT-restart wrapper below; (d) skipped roots contribute **0** to `st.nodes` — the production
`finishParallel` already separates `solved` from `skipped`, so a censored root can never inflate a
node total the way T924's probe did (`src/retro.zig:1445–1465`).

## 2. The six normative decisions

### D1 — node cap: none. `RETRO_PARALLEL_BUDGET=0`.

The row's question is *"does it close every root?"* Any cap reintroduces node-censoring, which is
precisely what made T924's headline 7.585× high and made T929 spend a whole row un-folding it.
**Consequence, stated:** if any root diverges, the run does not self-terminate; the wall stop (D4)
is what bounds it, and the censoring unit becomes **wall**, not nodes. A root that runs away runs
on one thread while the other 15 finish and idle — the partial result is still complete for every
other root.

- *Alternatives rejected:* a "high enough not reached" cap (T936's other option) is a guess about
  the tail, and a guess that is wrong on the low side silently reproduces T924's defect; a 20M cap
  is rejected because it is the exact number that censored 9.71% of samples. There is no number that
  is both "definitely not reached" and "not a guess", because the tail's cost is the thing being
  measured.
- **Acceptance A1 (red→green):** the launched command contains `RETRO_PARALLEL_BUDGET=0`, and the
  report states "node cap: none." *Red:* a report whose node total or mean was computed with a cap
  folded in (T924's 202.5–1,620 h). *Green:* no cap present; the only censoring signal is wall (D4).
  *Incident it catches:* T924/T929 §4 — "their true cost is unknown above the cap, not 'the cap'."

### D2 — a censored root is a set member, never a node count, never a mean.

The production finisher already reports `solved` and `skipped` separately, and skipped roots add 0
nodes. The spec forbids the one downstream operation that undid T924: computing any
"mean nodes/root" over a closed+censored mixture. The headline is three numbers plus the exact
denominator: **closed = X, censored = C, nodes = Σ over closed only, of Y orbit reps** (Y is the
measured `orbit reps` figure, never an assumed population).

- **Acceptance A2 (red→green):** the report carries `closed`, `censored`, and `nodes-over-closed-only`
  as separate fields with the measured Y. *Red:* any mean whose denominator ≠ closed count
  (T924's 2,139,677.3 mean/root, which counted the 125 capped roots at their cap). *Green:* the three
  numbers separated; censored roots appear only in `censored` and in the per-layer tally.
  *Incident it catches:* T924's 7.585× headline inflation.

### D3 — three controls, all on the 4×3 rung, before any 4×4 number is written.

Each control runs through the *same* detached path and the *same* binary as the 4×4 run (§5), or it
is not a control for it.

**A3 · Null control** — 4×3, round-robin, 16 threads, `RETRO_PARALLEL_BUDGET=20000000`
(byte-for-byte T932's rung). Must reproduce **21,578 roots / 183,065,016 nodes / 0 bracket-fail /
0 orbit-clash / symmetry PASS** *byte-for-byte*, and a round-robin wall within **±5% of 11.6×**
(i.e. 11.02×–12.18× vs the 35,670 ms serial reference).
- *Red:* the same binary under `RETRO_PARTITION=contig` must **fail** the 11.6×±5% band (it gives
  ~5.1×) — proving the band discriminates. *Green:* rr reproduces the byte-identical counts and the
  band. *What it catches:* a broken build, a reverted round-robin partition, non-determinism, or a
  host that slept/throttled (wall outside band). *Incident:* QA-023 (a control that never goes red).

**A4 · Seeded-defect control** — the same 4×3 arm under `RETRO_PARTITION=contig`. Must be
**distinguishable** by the per-thread node-count imbalance ratio: contig slowest/mean **≥ 2.0**
(measured 3.05) and rr **≤ 1.5** (measured 1.20); the 2.0 threshold sits between the 3.05 and 1.20
with ~1.0 of margin on each side.
- *Red:* contig reads ≤ 1.5 — the instrument cannot tell 5.1× from 11.5× and is guarding nothing.
  *Green:* contig ≥ 2.0 while rr ≤ 1.5. *What it catches:* a partition change that silently reverts
  to contiguous, or a dead imbalance detector. *Incident:* T930's 3.34× busiest-thread imbalance
  shipping unnoticed.

**A5 · Killed-run control** — kill the detached 4×3 job mid-finisher **twice**, the two ways that
matter: (i) `SIGKILL` and (ii) `SIGINT`.
- *Red (the sensitivity leg):* `SIGKILL` leaves the checkpoint **unchanged** (only the pre-finisher
  state survives; the log's progress lines are all that remain of the finisher work) — proving
  durability is not automatic. *Green:* `SIGINT` merges the partial, writes the checkpoint, keeps the
  log, and a resume from that checkpoint completes with the byte-identical 21,578 / 183,065,016.
  *What it catches:* the "writes only on completion" defect, and any resume/merge bug. *Incident:*
  T924 (a run that exits 0 having written neither deliverable).

### D4 — when to stop.

- **Stop-success:** `skipped==0` **and** `unfilled==0` in the finisher's summary → artifact written,
  run complete. Answer to the row's question: **yes**.
- **Stop-wall:** a pre-declared **72 h of summed finisher wall** (build excluded). On reaching it the
  wrapper `SIGINT`s, the partial merges, the checkpoint is committed, and the row closes **`blocked`**
  with the partial curve. Answer: **no, not within 72 h** — with the censored set recorded (D2).
- The wall is **finisher wall only**, summed across the checkpoint-restart segments (§5). Build wall
  (~509 s × number of segments) is reported separately and never folded into the finisher wall.

The 72 h default is a **spend** constant, decided here with the reasoning stated and overridable by
the operator via one constant (no spec re-read): the measured single-threaded floor is 26.8 h, the
optimistic parallel low end ~9 h, the realistic (working-set-degraded) estimate ~1–6 days (T930).
72 h lets the realistic range finish while bounding the drained host. If the operator raises or
lowers it, nothing else in this spec changes.

- **Acceptance A6 (red→green):** every termination state — complete, wall-stop, or external kill —
  leaves a committed checkpoint + partial report + log; **no exit-0-with-nothing**. *Red:* T924 (held
  a lane 4,110 s, exited 0, wrote neither deliverable). *Green:* kill the job at any moment and the
  checkpoint + log + partial report are on disk and resumable. *Incident:* T924.

### D5 — what the run must record, so someone who did not run it can check it.

The report (`docs/research/4x4-d3-run.md`) and its evidence dir (`docs/evidence/T936/`) must contain,
for each phase: **(1)** binary git commit + sha256 + build command + zig version; **(2)** the full
command line including every env var; **(3)** pid, log path, start/stop from `jobs.jsonl`; **(4)** the
host-state assertion — `caffeinate -i -s` held, `sleeps_during_run` count (T927), fleet drained, load
average at start/end; **(5)** the finisher's own emitted lines verbatim (orbit-rep count, per-thread
`thread N: solved=… skipped=… nodes=…`, and the `solved=… filled=… skipped=… single-ko=… nodes=…
max/root=… (ms)` summary); **(6)** the per-thread imbalance ratio (slowest/mean); **(7)** the
closed/censored split **with the per-layer distribution of censored roots** — produced by a throwaway
checkpoint reader, not by editing the engine; **(8)** peak RSS (maximum resident set size, via
`/usr/bin/time -l` wrapped around the binary inside the detached command); **(9)** the summed finisher
wall across segments; **(10)** the partial curve (cumulative solved vs wall, from the progress lines).

- **Acceptance A7 (red→green):** a fresh clone can replay the null control from the recorded commit
  and recompute the closed/censored split from the committed checkpoint. *Red:* T929 §2 — the
  per-layer stratification existed **nowhere** in committed evidence and had to be recovered from a
  lane transcript. *Green:* every number in the report traces to a committed file or a replayable
  command. *Incident:* T929's stratification recovery.

### D6 — detached, per T928. No agent holds this compute.

The compute is a `nohup` job: pid + argument-array command + log + UTC start, appended to
`$JOB_DIR/jobs.jsonl` with `JOB_DIR=untracked/jobs` (the durable ignored job-state directory, per the
T928 findings note). Liveness is `ps -p <pid>`; completion is the pid being gone; the log is the
output. `caffeinate -i -s` is held for the whole run (T927). No kanban row, no judgement, no
notification for the job. The analysis row (T936's writer) is a **separate** agent that reads the log
after the job finishes and writes the report — exactly as T914 did for T924, minus the part where the
model sat blocked on the compute.

- **Acceptance A8 (red→green):** the job's wall never overlaps an agent lane; `jobs.jsonl` holds the
  record; `ps -p` is the only liveness signal. *Red:* T924 held ox-alpha 4,110 s on one bash call.
  *Green:* the record exists and no agent lane was open during the finisher wall. *Incident:* T924.

## 3. Phases and the exact commands

**Phase 0 — tail bound (cheap, gates Phase 2).** Re-run T924's never-reported empty-root escalation
ladder with output captured (`src/t924_d3_probe.zig` is committed): the empty-goban root (one of the
125 capped roots) at escalating budgets 20M → 100M → 1G, then wall-capped-unlimited. The top rung is
wall-capped at **24 h of that single root's solve** — hitting that cap is itself the answer ("the tail
diverges"), so it is a measurement, not an abandonment. This decides whether the full uncapped run is
worth starting and calibrates the D4 wall stop. **If Phase 0 shows divergence, the operator is told
*before* Phase 2 is launched** — that is a spend decision, and it is surfaced, not silently skipped.

**Phase 1 — controls (A3–A5) on 4×3.** All three green before Phase 2.

**Phase 2 — 4×4, uncapped, 16 threads.**

```
# one-time, once (record commit + sha256 in the report):
zig build-exe -O ReleaseFast -femit-bin=$JOB_DIR/retro-4x4 src/retro.zig

# 4x3 null control (A3) — round-robin:
RETRO_PARALLEL=1 RETRO_4X3=1 RETRO_SOUND=1 RETRO_PARALLEL_THREADS=16 \
RETRO_PARALLEL_BUDGET=20000000 RETRO_PARALLEL_PROGRESS=1000 \
RETRO_PARALLEL_CKPT=$JOB_DIR/null.ckpt.wzo RETRO_PARALLEL_OUT=$JOB_DIR/null.out.wzo \
$JOB_DIR/retro-4x4

# 4x3 seeded-defect control (A4) — contiguous:
#   same as above plus RETRO_PARTITION=contig, distinct ckpt/out paths

# 4x4 (Phase 2) — uncapped. NOTE: no RETRO_4X4, no RETRO_3X3, no RETRO_4X3:
RETRO_PARALLEL=1 RETRO_SOUND=1 RETRO_PARALLEL_THREADS=16 \
RETRO_PARALLEL_BUDGET=0 RETRO_PARALLEL_PROGRESS=1000 \
RETRO_PARALLEL_CKPT=$JOB_DIR/4x4.ckpt.wzo RETRO_PARALLEL_OUT=$JOB_DIR/oracle-4x4-sound.wzo \
$JOB_DIR/retro-4x4
```

`RETRO_SOUND=1` sets `memo_writes=false` (Track A writes-off, ADR-0013) — this is the regime the
whole T924→T929→T930→T932 arc measured; do not run the default reuse mode and label it writes-off.

**Durability wrapper (Phase 2 only).** Because the checkpoint is written only when `finishParallel`
returns, the implementer wraps Phase 2 in a loop that (a) launches the command detached under
`caffeinate -i -s` and `/usr/bin/time -l`; (b) after a **6 h finisher-wall interval** sends `SIGINT`
to the pid; (c) waits for the graceful merge + checkpoint + exit; (d) records the segment wall and
restarts from the checkpoint; (e) stops on stop-success or the 72 h stop-wall (D4). A hard kill at
any instant loses at most the finisher work since the last 6 h checkpoint — bounded loss, which is
the T924 lesson applied.

## 4. Acceptance (armed)

**Armed count: 8** — A1 (cap) · A2 (censored reporting) · A3 (null) · A4 (seeded-defect) ·
A5 (killed-run) · A6 (stop) · A7 (recording) · A8 (detached).

Ordering gate, binding: **A3, A4, A5 green before any 4×4 number is written down** (the brief's
acceptance #1). A 4×4 number produced with a red control is not a result, it is a QA-023.

Final acceptance mirrors T936's: (1) controls green first; (2) the 4×4 result is stated as measured
wall + measured nodes + closed/censored split, never a single projected range; (3) an unfinished run
closes `blocked` with the partial curve committed; (4) `docs/research/4x4-d3-run.md` supersedes
`4x4-d3-tractability.md` by naming it, and the older doc gains a pointer line — neither edits away the
T924 → T929 → T930 → T932 → T936 arc.

## 5. Out of scope

- Running the solve or building anything (this is a spec; the implementer does that).
- Track B (dependency-guarded reuse, `RETRO_DEPS=1`) — T936 is the writes-off arm only.
- The 5×5 decision, ground-truth, spot checks, and the `#2` minimax-identity auditor (those are
  separate rows; the run's determinism controls A3/A4 are the finisher's own guardrails here).
- Any change to `src/retro.zig`. The engine is used byte-for-byte at the recorded commit; the only
  new code is a throwaway checkpoint reader for the D5 per-layer tally.
- The `docs/research/4x4-d3-run.md` write-up itself and the findings JSON — that is the T936 writer's
  deliverable, produced *after* the job finishes, from the committed log and checkpoint.

## 6. Deliberately left out

A work-stealing scheduler (the static round-robin is taken as-is — changing the finisher is a
different row and triggers the #2 auditor gate); sub-hour checkpoint granularity (6 h bounds loss to
6 h of finisher work at ~2.5% restart overhead from the ~509 s rebuild); any "mean nodes/root" figure
in the headline (forbidden by D2, by design).
