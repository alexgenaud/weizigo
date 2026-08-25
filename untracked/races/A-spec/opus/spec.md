# Spec — T936: run 4×4.D3 to completion

**Line references are pinned to commit `9f5dd1a`** (`src/retro.zig`, `src/enumerate.zig`, `src/t924_d3_probe.zig` all clean at that commit).

**Row:** T936 (`4x4.D3` — writes-off 4×4 tractability). **Spec author:** claude-opus-5/T971, sealed
Race A arm. **Landmark:** `L2 (proven 4x4 values)`.

**Verdict up front: start the run.** Every number in the repository's projection chain is
individually correct and the chain as a whole is **2× pessimistic**, because T929 corrected the
mean while keeping T924's orbit factor and T930 corrected the orbit factor while keeping T924's
mean. Nobody has multiplied the two corrections together. Doing so (§0.3) gives **≈13.6 h
single-threaded and ≈1.2–2.3 h on 16 threads**, against `4x4.D3`'s ≤ 8 h target — with the whole
answer hostage to a tail that is 1.15 % of the work list and 81 % of the nodes. That tail is why
this row is a *measurement with a stop rule*, not a solve.

---

## 0. The numbers, re-checked against this repository

I re-derived every figure in the brief from committed evidence and from `src/retro.zig` /
`src/t924_d3_probe.zig`. **Three survive unchanged, two are wrong, and one is a straw man.**

### 0.1 Confirmed

| figure | source checked | verdict |
|---|---|---|
| 125 / 1,287 censored at a 20,000,001-node cap | `docs/evidence/T924/summary.csv` (`T924,total,writes-off,pop=10367922,samples=1287,solved=1162,skipped=125`); `grep -c 20000001 per-root.csv` = **125** | ✔ 9.712 % |
| 202.5 – 1,620 h unweighted | `summary.csv` projection line, `ns_per_node=262.90` | ✔ verbatim |
| 282,104.8 nodes/root, 7.585× lower, 26.8 – 214.7 h | `4x4-d3-weighted-projection.md` §3; 2,139,677.3 / 282,104.8 = 7.5847; recomputed off the `ns=264.29` bracket (203.576 / 7.585 = 26.84) | ✔ internally consistent |
| 92.6 % of measured nodes in the 125 | 2,500,000,125 / 2,700,272,692 = 92.584 % | ✔ |
| 5.10× contig @18, 11.54× rr @16 | `docs/evidence/T930/`, `parallel-finisher-cost.md` | ✔ |
| 11.64× production @16, byte-identical counts | `docs/evidence/T932/production-4x3.csv`: 21,578 roots / 183,065,016 nodes on every run | ✔ (brief says 11.6×; the file says 11.640×) |
| ko-sensitive population 10,367,922 = 2 × 5,183,961 | `summary.csv` build line, 4×4 | ✔ |

### 0.2 Defect 1 — the orbit factor is 2× wrong in *both* projections, and it is free to measure

`E.num_syms = 8` for a square goban (`src/enumerate.zig:57`). T924's low end divides the
**slot** population by `num_syms`. But `finishParallel`'s `worker()` (`src/retro.zig:1426-1446`)
fills, for each solved representative, the dihedral image **and** its colour inversion — `same_v[ti]`
and `swap_v[ii]`, `inline for (0..num_syms)`. One solve fills up to **2·num_syms = 16** slots, not 8.

T930 spotted this at 4×3 and stopped at T924's unweighted figure. The check reproduces: 170,276 / 4
= 42,569 predicted reps, **21,578 actual** — ratio 1.0138 above the 2·num_syms floor of 21,284.5.

Applied to 4×4: floor = 10,367,922 / 16 = **647,995 reps**; scaled by 4×3's 1.0138 symmetry
surplus, **≈ 656,900 reps expected**.

**Consequence: T929's published 26.8 h low end is 13.42 h.** The run measures the real number in
its first ~9 minutes, for free, and it is printed already
(`finishParallel: partition=round-robin ({d} orbit reps -> {d} threads)`, `src/retro.zig:1560`).

### 0.3 The corrected projection — the number this row is being started against

656,900 reps × 282,104.8 nodes/rep × 264.29 ns:

| reading | nodes | serial wall | @6× (memory-derated) | @11.64× (4×3-measured) |
|---|---|---|---|---|
| **as-measured (censored at cap; a floor)** | 1.853 × 10¹¹ | **13.61 h** | **2.27 h** | **1.17 h** |
| censored-as-zero (diagnostic only) | 3.480 × 10¹⁰ | 2.55 h | 0.43 h | 0.22 h |

The 6× derate is T930's own caution (4×4's ~10 GB working set vs 4×3's cache-resident ~125 MB);
11.64× is its measured ceiling. **Neither is an expectation — the run measures the speedup.**

### 0.4 Defect 2 — production and the T924 probe count nodes differently, and the numbers are
close enough to be cross-cited by accident

`worker()` accumulates `out.st.nodes += ctx.nodes` **only inside `if (solved)`**
(`src/retro.zig:1416-1418`); a budget-exhausted root increments `budget_skipped` and contributes
**zero** nodes. T924's probe does the opposite: `ls.sum_nodes += out.nodes` unconditionally, so a
capped root lands at 20,000,001 (this is exactly the mechanism T929 §4 had to correct T924's doc
for). **So production `nodes` and T924 `sum_nodes` are different quantities.** They must never be
divided by a root count and compared.

The trap is live: T924's 4×3 total is 183,442,515 and T932's production 4×3 total is 183,065,016 —
0.2 % apart, over different denominators (20,878 sampled slots vs 21,578 orbit reps, both
zero-censored). They agree by coincidence, not by construction.

### 0.5 Straw man — the 8× bracket

T929's bracket runs from "every orbit maximal" (÷8) to "every orbit trivial" (×1). The ×1 end is
unreachable: the finisher *always* fills the whole 2·num_syms orbit, and the 4×3 rung puts the real
value 1.4 % above the floor. **The 8× bracket is an artifact of an unmeasured constant, and this run
replaces it with a counted integer before it solves anything.** That is the cheapest evidence in the
row and it is deliverable #1.

### 0.6 Memory, derived not guessed

`total = 3¹⁶ = 43,046,721` slots. Per thread: `ctx.{vb,vw}` (2 × i8) + `{cb,cw}` (2 × bool) +
`{lbb,ubb,lbw,ubw}` (4 × i8) = 8 B/slot, plus `ThreadOut.{vb,vw,fb,fw}` = 4 B/slot → **517 MB per
thread**, allocated up front for all `nt`. At 16 threads: **8.26 GB** + ~0.8 GB of shared tables ≈
**9.1 GB peak**. Comfortably inside `4x4.D3`'s 32 GB budget; 18 threads would be 9.3 GB, so memory
is *not* the reason to prefer 16.

---

## 1. Decision — the node cap

**Decided: cap at 20,000,000 (the `RETRO_PARALLEL_BUDGET` default) for the primary run. Not
uncapped. Not raised.**

Uncapped is not an option, and this is not a matter of taste: layer 0's single root — the empty
goban — is one of the 125 censored roots (T929 §4 per-layer distribution, `layer 0: 1`), and the
2×2 measurement in `src/retro.zig:2195-2198` records that the empty root alone "exceeds 4e9 nodes /
3e7 exact states" for exact solving. **An uncapped 4×4 run does not terminate, and produces no
partial result either, because nothing is written until the finisher returns (§4).**

Raising the cap is not free and its cost is exactly computable: the wall is **linear** in how far
past the cap the tail runs. The censored share of the *population-weighted* node mass is
(282,104.8 − 52,976.1) / 20,000,001 = **1.1456 % of reps ≈ 7,530 reps**, carrying 81 % of the
projected nodes. If the true cost of a censored rep is X× the cap, total wall ≈ 2.55 h + 11.06·X h
serial. X = 10 puts the run at ~113 h; X = 100 at ~1,108 h. **The cap is the only thing standing
between this row and T924's fate.**

**Consequence, stated plainly:** the primary run returns a wall and a node count that are **lower
bounds**, and a censored set whose true cost is **unknown above 20 M** — not "the cap", not
"20 M", not folded into anything.

**Decided: the unknown is then bounded by a sampled, wall-capped escalation ladder** (§1a), not by
raising the primary cap. This is T929's follow-on #2 and the mechanism already exists:
`RETRO_PARALLEL_RETRY=1` clears `FLAG_TRIED_SKIP` on resume so censored roots are re-attempted at a
larger `RETRO_PARALLEL_BUDGET` (`src/retro.zig:3367-3374`).

### 1a. The escalation ladder — sampled and capped, because exhaustive is unaffordable

Exhaustive escalation of ~7,530 censored reps at 200 M would cost 7,530 × 2 × 10⁸ × 264.29 ns =
110 h serial. **Rejected.** Decided instead:

| rung | budget | sample | serial cost | wall cap |
|---|---|---|---|---|
| L1 | 200,000,000 | 200 censored reps, systematic stride over the censored colex list | 2.94 h | **30 min** @ ≥ 9× |
| L2 | 2,000,000,000 | 100 reps, the L1 survivors first | 14.7 h | **2 h** @ ≥ 9× |

The ladder's deliverable is a **survival curve** — *k* of *n* censored reps closed at 20 M / 200 M /
2 G — not a mean. If L1 closes ≥ 80 % of its sample, the tail is a factor-of-10 problem and the
follow-on is a re-run at 200 M. If L1 closes < 20 %, the tail is unbounded from this data and the
row says so. **The ladder is a separate detached job from the primary run, launched only after the
primary run's censored census exists.**

## 2. Decision — how a censored root is reported

**Decided: the censored set is reported as an addressable census, and every aggregate carries the
closed/censored split. No mean over roots is published at all.**

Three specific prohibitions, each traceable to a defect this repository already made:

1. **No single "mean nodes per root."** T924 published one; it counted 125 capped roots at their
   cap and read 148× the writes-on arm when the honest solved-root figure was 12.2× (T929 §4).
   The run reports `nodes_closed`, `reps_closed`, `reps_censored`, and `cap` as four separate
   numbers. Any mean is the reader's to compute, with the censoring in front of them.
2. **No projected range as the headline.** The primary run's headline is
   *measured wall, measured nodes, closed/censored split* (T936 acceptance §2). A single range is
   how 202.5 – 1,620 h and 26.8 – 214.7 h both became quotable.
3. **No aggregate that mixes production and probe node counts** (§0.4).

**The census is already durable and nobody has noticed.** `worker()` marks the whole orbit of a
budget-exhausted root with `FLAG_TRIED_SKIP` (`src/retro.zig:1452-1465`), and `fb`/`fw` are
persisted in the checkpoint artifact. **The identity of every censored root survives in the
checkpoint on disk.** T929 had to recover its stratification from a host-local lane transcript that
existed nowhere in git; this run does not need to, and the spec requires the census be *extracted*
(colex index, layer, side) rather than counted. **Deliverable: `docs/evidence/T936/censored.csv`.**

Per-root **node counts** are not recoverable — production records only per-thread aggregates. That
is an accepted loss for the primary run (see §7, out of scope); the ladder recovers the cost
distribution where it matters, on the censored set.

## 3. Decision — the controls, before any 4×4 number is believed

**Decided: four controls. Two are shipped and re-run; two are new. The 4×4 arm does not launch
until all four are pasted green.**

### C1 — null control (determinism), shipped

Re-run 4×3 through the **detached path**, writes-off, rr @16. Must reproduce
**21,578 reps / 183,065,016 nodes / 0 bracket-fail / 0 orbit-clash / symmetry PASS** byte-for-byte
(`docs/evidence/T932/production-4x3.csv`) and a speedup within **±10 %** of 11.640×.

*Catches:* a mis-built binary, a wrong `RETRO_SOUND`, a host under contention, an `-O Debug`
build. *Red arm:* the same command with `RETRO_SOUND` unset (writes-on) must produce a
**different** node count — if it does not, the writes-off switch is not wired and every number in
this row is measuring the unsound arm. **This red arm is the one T924 never ran.**

### C2 — seeded-defect control (instrument discrimination), shipped

`RETRO_PARTITION=contig` at 4×3 @16 must be **distinguishable** by per-thread node-count imbalance:
rr ≤ **1.40** max/mean, contig ≥ **1.40**. Measured values to reproduce:
rr **1.20**, contig **3.05** (`docs/evidence/T932/per-thread-16.txt`).
`tools/regression-finishparallel-partition.sh` already ships this control at 3×3 with the same 1.40
threshold — **run the shipped script, do not re-implement it.**

*Catches:* an instrument that cannot tell 5.1× from 11.5×, and therefore cannot certify that the
4×4 arm ran balanced.

### C3 — segmentation control (NEW; this is the one that has never been run)

Run 4×3 twice: once in one shot; once `kill -INT`-ed mid-finisher and resumed from its checkpoint.
**Segment totals must sum to identical `solved` / `budget_skipped` / `nodes`, and the final
artifact must be byte-identical to the one-shot artifact.**

This is sound by construction and the construction should be checked, not assumed: `worker()`
builds its certified baseline **excluding** `FLAG_FROM_FORWARD` slots
(`src/retro.zig:1344-1349`), so a resumed segment solves its remaining reps from exactly the
baseline a one-shot run would have used; and the interrupt `break`s at the **top** of the work loop
(`src/retro.zig:1370-1374`), so no partially-solved root contributes nodes.

*Red arm:* delete the checkpoint between segments — the resumed run must report
`resume: no checkpoint … starting fresh` and the final validate line must show `unfilled > 0` or a
different node total. If the red arm passes, resume is a no-op and the loss protection in §4 is
imaginary.

*Catches:* the entire §4 loss-protection mechanism. **No 4×4 run is launched on an unverified
resume path.**

### C4 — censored-census control (NEW)

At 4×3 with `RETRO_PARALLEL_BUDGET=100000` (forced censoring), the extracted census must be
non-empty and its orbit-representative count must **equal** the finisher's reported `skipped`. At
the production budget it must be **empty** (4×3 censors nothing).

*Catches:* a census tool that reads the flag wrong, double-counts orbit members, or silently
returns zero — which would report a censored 4×4 run as clean.

**Armed count: 12 acceptance arms across 6 decisions (§8).**

## 4. Decision — when to stop, and what survives

**Decided: a 6-hour hard wall on the primary finisher, enforced by SIGINT; one scheduled
checkpoint cycle at T+90 min; and `blocked` with the partial curve committed if the wall is hit.**

**The code has no incremental flush.** Per-thread outputs merge into the table only after every
thread joins (`src/retro.zig:1687-1720`), and the checkpoint is written only after `finishParallel`
returns (`src/retro.zig:3406-3412`). A `kill -9`, an OOM, or a power loss destroys the entire
elapsed wall. **`SIGINT` is different and it works**: `installParallelSigint`
(`src/retro.zig:2184-2191`) sets a flag, workers break, partials merge, the checkpoint saves, and
the run prints `INTERRUPTED — checkpoint saved. Re-run to resume.`

So the flush is implemented **by scheduled interrupt**, not by a code change:

- **T+90 min:** if still running, `kill -INT <pid>`, wait for `checkpoint: … written`, relaunch.
  Cost: one 509 s rebuild (~9 min, 6 % overhead against the 2.3 h expectation). Maximum loss
  bounded at 90 min.
- **Past T+4 h:** the §0.3 projection is falsified. Switch to hourly cycles — loss protection now
  dominates rebuild cost.
- **T+6 h:** `kill -INT`, save, **stop**. Close `blocked` with the checkpoint, the censored census,
  the segment walls, and the partial closed/censored split committed.

*Why not modify `finishParallel` to checkpoint periodically:* it is a held production file, a
mutation to the exact code path under measurement, and it would need its own null and
seeded-defect controls before its first reading counted. The interrupt path already exists and C3
proves it. **Rejected on those grounds, not on effort.**

**A censored run honestly reported is a result.** T924's failure was not that it ran out of time;
it was that it exited 0 with nothing on disk.

## 5. Decision — what the run must record

**Decided: one committed run record, `docs/evidence/T936/run-record.json`, written before the row
reports, plus `censored.csv` and the raw logs.** Fields, each because something was lost without it:

| field | why |
|---|---|
| `orbit_reps` (counted, from the partition line) | replaces the 8× bracket with an integer (§0.2) |
| `pop_slots`, and an explicit `denominator: "orbit_reps"` | T924's `pop` is slots and its `samples` are reps; the ambiguity is what made the ÷8 error invisible |
| `nodes_closed`, `reps_closed`, `reps_censored`, `cap` | four numbers, never one mean (§2) |
| `nodes_counter_semantics: "closed roots only"` | §0.4; blocks the cross-citation trap |
| `segments[]`: per segment wall_ms, nodes, solved, skipped, build_ms | totals must be summed across resumes, and rebuild time excluded from the finisher wall |
| `per_thread_nodes[]`, `imbalance_max_over_mean` | proves the run was balanced, i.e. that C2's certification transfers |
| `speedup_vs_serial` **or** an explicit `null` | 4×4 has no serial baseline; do not divide by 4×3's 11.64× and call it measured |
| `peak_rss_bytes` | `4x4.D3` carries a 32 GB budget; predicted 9.1 GB (§0.6) — an unrecorded RSS leaves the budget half of the row unanswered |
| `caffeinate_held`, `sleeps_during_run` | T927; 2026-08-24 slept 24 times and every wall from that day is suspect |
| `bracket_fail`, `orbit_clash`, `symmetry`, `unfilled` | the run can be fast and wrong; these are the soundness gates `parallelBoard` already prints |
| `job`: pid, argv, log path, started_at | T928 |
| `binary`: commit sha, `zig build-exe -O ReleaseFast` command | a wall from a Debug build is not this row's number |

**Checkability rule:** every number in `docs/research/4x4-d3-run.md` must be a line some log
printed, cited to the committed log or evidence file — the standard `4x4-d3-tractability.md` set
for itself ("Every number below is a line the probe printed; none is re-derived") and the standard
T929 could not meet, having to recover its stratification from a host-local transcript.

## 6. Decision — detached, not agent-held

**Decided: detached, per T928, using `job_start` from `docs/infra/host/detached-jobs.md`. No agent
lane holds this compute, and no agent's wall is the run's wall.**

```sh
export JOB_DIR=<durable ignored job-state dir>
zig build-exe -O ReleaseFast -femit-bin=/tmp/weizigo/retro_fast src/retro.zig
job_start caffeinate -i -s env \
  RETRO_PARALLEL=1 RETRO_4X4=1 RETRO_SOUND=1 \
  RETRO_PARALLEL_THREADS=16 RETRO_PARALLEL_PROGRESS=5000 \
  RETRO_PARALLEL_BUDGET=20000000 \
  RETRO_PARALLEL_CKPT=<dir>/4x4-d3.ckpt.wzo RETRO_PARALLEL_OUT=<dir>/oracle-4x4-d3.wzo \
  /tmp/weizigo/retro_fast
```

`RETRO_PARTITION` is **unset** — round-robin is the default since `cb5a307`. Setting it to anything
but `contig` also yields round-robin, so the safe expression of intent is omission plus asserting
`partition=round-robin` in the log.

**Threads: 16, not 18.** Both T930 (11.54× vs 10.87×) and T932 (11.640× vs 11.416×) measured 16
beating 18; memory is not the constraint (§0.6). Decided on the measurement, and the 4×4 arm
records its own per-thread imbalance so the choice is re-examinable, not re-litigated.

`caffeinate -i -s` wraps the binary so the assertion dies with the job (T927), and is inside
`job_start` so `nohup` covers both.

**The row's agent does not sit on this.** It launches, records, exits, and a later row or a later
invocation of the same row reads `ps -p` and the log. An agent that blocks on the compute has
converted a 2-hour job into a 2-hour lane hold, which is precisely T924.

---

## 7. Out of scope — explicit

1. **Track B (`RETRO_DEPS=1`, Kishimoto–Müller).** This row measures Track A only. The comparison
   is `4x4.F4`'s.
2. **Promoting the artifact.** `4x4.C1`, `4x4.F2`, `4x4.F3` are separate rows; this row produces a
   checkpoint and a wall, not a certified oracle. `parallelBoard` already refuses to write the
   artifact on `unfilled != 0` — with censored roots expected, **a PARTIAL result is the normal
   outcome**, and the row must not read that refusal as failure.
3. **Per-root node distribution over the closed population.** Recording it needs a production
   change to `worker()`; the ladder (§1a) covers the tail, which is where the distribution matters.
4. **Re-deriving T929's per-layer stratification.** Committed at
   `docs/evidence/T929/per-layer-recovery.csv`; this row does not re-audit it.
5. **The orbit-factor correction as a register claim.** §0.2 falsifies a published low end in two
   committed docs. That is a finding, not this row's deliverable; it should be a separate row
   against `4x4.D3`'s evidence chain.
6. **5×N and beyond.** T925's.

## 8. Acceptance arms — 12, one per normative decision or control

Each arm: the must, its red-then-green form, and the incident it would have caught.

| # | decision | must (green) | red | incident it catches |
|---|---|---|---|---|
| A1 | §1 cap | `finishParallel: partition=round-robin (N orbit reps -> 16 threads)` with **N ∈ [647,995, 680,000]** | at 4×3 the same line must read **exactly 21,578**; a build reporting 42,569 (= pop/num_syms) fails | T924/T929's ÷8 low end, 2× high, in two committed docs (§0.2) |
| A2 | §3 C1 | 4×3 detached: 21,578 / 183,065,016 / 0 / 0 / PASS, rr@16 within ±10 % of 11.640× | `RETRO_SOUND` unset must change the node count | a writes-on run reported as writes-off — the arm T924 never armed |
| A3 | §3 C2 | shipped `tools/regression-finishparallel-partition.sh` green; 4×3@16 imbalance rr ≤ 1.40 | `RETRO_PARTITION=contig` must read ≥ 1.40 (expect 3.05) | an instrument that cannot tell 5.1× from 11.5× (T930 → T932) |
| A4 | §3 C3, §4 | one-shot vs SIGINT-and-resume at 4×3: identical summed solved/skipped/nodes, byte-identical artifact | checkpoint deleted between segments → `starting fresh` and `unfilled > 0` | the loss protection being imaginary; T924 exiting 0 with nothing written |
| A5 | §2, §3 C4 | `docs/evidence/T936/censored.csv` lists colex/layer/side; its rep count **equals** the finisher's `skipped` | 4×3 at `BUDGET=100000` → census non-empty and matching; at 20 M → empty | T929 recovering stratification from a host-local transcript that was in no commit |
| A6 | §2 | run record carries `nodes_closed`/`reps_closed`/`reps_censored`/`cap` and `nodes_counter_semantics` | any single published "mean nodes per root", or any sum of production `nodes` with probe `sum_nodes`, fails review | T924's 148× headline, corrected twice (§0.4) |
| A7 | §5 | `caffeinate_held: true`, `sleeps_during_run: 0` in the run record | a record missing the field, or with sleeps > 0, is not a reading | 2026-08-24: 24 sleeps; every wall from that day suspect (T927) |
| A8 | §6 | `jobs.jsonl` record (pid, argv, log, started_at) exists before the row reports | a wall measured inside an agent's own bash call fails | T924 held `ox-alpha` 4,110 s and wrote neither deliverable |
| A9 | §4 | primary finisher ≤ 6 h, or `kill -INT` at 6 h with checkpoint + partial curve committed and the row closed `blocked` | a run past 6 h with nothing on disk fails | a 202 h projection nobody could act on |
| A10 | §1a | ladder reports *k*/*n* closed at 20 M / 200 M / 2 G on a stated sample, within its stated wall cap | an uncapped or exhaustive ladder is rejected: layer 0 is censored and unbounded (§1) | T929's "empty-root escalation ladder (pid 2538) ran and its output was never captured" |
| A11 | §5 | `peak_rss_bytes` recorded; ≤ 32 GB (`4x4.D3` budget); predicted 9.1 GB | an OOM, or an unrecorded RSS, leaves half the row's claim unanswered | `4x4.D3`'s memory clause has never been measured, only placeheld |
| A12 | §5 | `4x4-d3-run.md` **names** `4x4-d3-tractability.md` and `4x4-d3-weighted-projection.md` as superseded; both gain pointer lines; neither is edited to hide the correction | a rewrite that removes the T924 → T929 → T930 → T932 arc fails | the arc is the evidence (T936 acceptance §4) |

## 9. Alternatives considered and rejected

| alternative | rejected because |
|---|---|
| **No cap at all** (T936 scope §2's first option) | layer 0 — the empty goban — is already censored at 20 M, and the 2×2 measurement in `retro.zig:2195-2198` says the empty root does not close at 1000× a comparable budget. Non-termination *and* no partial, since nothing is written until the finisher returns. |
| **A cap high enough not to be reached** (scope §2's second option) | it does not exist. The wall is linear in the tail's true cost, and the tail's true cost is the unmeasured quantity. Choosing a cap "high enough" is choosing an unbounded wall on an unmeasured basis. |
| **Raise the cap to 200 M for the primary run** | 81 % of projected nodes are in the censored 1.15 %; a 10× cap is up to a 10× wall (≈ 113 h serial). Rejected in favour of the sampled ladder (§1a), which buys the same information for ≤ 2.5 h. |
| **Patch `finishParallel` to checkpoint every N reps** | a mutation to the exact code path under measurement, needing its own controls before its first reading counts (`never trust a green test`). The SIGINT path exists and C3 proves it, at 9 min per cycle. |
| **18 threads** | 16 beat 18 in two independent measurements (T930 10.87× vs 11.54×; T932 11.416× vs 11.640×). Memory is not the tiebreaker (§0.6). |
| **Hold the compute in an agent lane** | T928's ruling and T924's worked failure. |
| **Use `src/t924_d3_probe.zig` as the instrument** | it is a sampler with a different node-counter convention (§0.4). This row's whole point is that there is no sampling weight left to get wrong. Production, or nothing. |
| **Publish a single projected range as the headline** | 202.5 – 1,620 h and 26.8 – 214.7 h are both quotable, both wrong by 2×, and both are ranges. T936 acceptance §2 forbids it and so does this spec. |
| **Extrapolate 4×3's 11.64× to 4×4 and report a derived wall** | T930 explicitly calls 11.54× an upper bound for 4×4 (10 GB working set vs cache-resident). `speedup_vs_serial` is `null` unless a 4×4 serial baseline is actually run — and it is not, being ~13.6 h. |

## 10. What I left out, and why

Scoped to a 2,700 s wall, in this order of value:

- **No 4×4 serial baseline arm.** ~13.6 h to buy one ratio. The per-thread imbalance ratio (A6/A11
  path) certifies the parallel arm without it, and `speedup_vs_serial` is honestly `null`.
- **No per-root node census over the closed population** (§7.3) — a production change, and the
  ladder covers the part of the distribution that decides the answer.
- **No orbit-size distribution per layer.** It would sharpen the 656,900 prediction, but the run
  counts the reps directly in 9 minutes, so predicting them precisely has no value.
- **No re-audit of T929's per-layer recovery** — committed, and out of scope (§7.4).
- **The orbit-factor falsification (§0.2) is written as a finding here but not as a register-row
  proposal** — that belongs to a row that can cite a run, and this row's run will cite it.
