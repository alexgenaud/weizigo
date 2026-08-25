# Spec — T936: run 4x4.D3 to completion

**Author:** oxalpha/T978 (sealed Race A arm; 2026-08-25)
**Executes:** `untracked/T936-4x4-d3-full-run.md` · **Landmark:** advances `L2 (proven 4×4 values)`
**Status of this document:** normative for T936. Every number in §1 was re-derived from the
committed evidence during this spec's writing, not copied from the brief.

## 1. The measured ground (verified against the repository)

| fact | value | how it was checked here |
|---|---|---|
| ko-sensitive population at 4×4 | **10,367,922** slots | `docs/research/4x4-d3-tractability.md` line 34 |
| T924 sample | 1,287 valid writes-off roots; **125 capped**, all at exactly **20,000,001** nodes | recounted from `docs/evidence/T924/per-root.csv`: 1,351 rows − 64 known 3×2 selftest contaminations (T929 §2) = 1,287; 125 rows with col-7 = 20000001 |
| censored dominance | capped roots hold **2,500,000,125 / 2,700,272,692 nodes = 92.6%**; 125/1,287 = **9.71%** | summed per-root.csv myself: 2,700,317,476 raw − 44,784 contamination = 2,700,272,692 ✓ |
| weighted projection | mean **282,104.8** nodes/root → **26.8–214.7 h** single-threaded lower bound (264.29 ns/node, orbit factor ÷8…×1); **7.585×** below T924's unweighted headline | arithmetic reproduced: 10,367,922 × 282,104.8 × 264.29e−9 s = 214.8 h; ÷8 = 26.8 h ✓ |
| parallel scaling | round-robin **11.54× @ 16 threads**, contig **5.10× @ 18** (4×3, T930); production reproduces **11.6×**, node totals byte-identical (`cb5a307`) | `docs/research/parallel-finisher-cost.md`; `docs/evidence/T932/per-thread-16.txt`: total 183,065,016; slowest/mean rr **1.20**, contig **3.05** |
| naive parallel wall | 2.3–18.7 h — **not an expectation anywhere in this row** | 26.8/11.5 and 214.7/11.5; forbidden as a headline by the brief |
| host | **18 cores, 48 GiB RAM** | measured on this host while writing this spec (`hw.ncpu`, `hw.memsize`) |
| empty 4×4 root | exceeds **500 M nodes (146 s)** — cost above that is unknown | `src/retro.zig` comment, MEASURED 2026-07-21 |

Two consequences I draw from these numbers before deciding anything:

- **The tail is extrapolable but bounded-unfriendly.** Applying each sampled layer's cap rate to
  its population (T929's recovery) projects roughly **2–3×10⁴ censored roots** after a 20 M bulk
  pass — my extrapolation, not a measurement; layer samples are ≤97. A design that gives every
  one of them a huge single budget can be forced arbitrarily wide by a handful of empty-root-like
  cases.
- **The finisher solves orbit representatives only** (`finishParallel`, `src/retro.zig`: work list
  is unique reps under dihedral × colour-inversion), so "work items" ≠ slots; both projection
  bracket ends already cover this. No decision hangs on it for a *measured* run — but any
  implementer who compares rep counts to 10,367,922 and panics should not; the counts will differ
  by up to ~an order of magnitude, by design.

## 2. Decisions

### D1 — Node cap: staged ladder, never one uncapped run, never one flat cap

The default budget is 20 M (`RETRO_PARALLEL_BUDGET`, `src/retro.zig`). At that budget ~9.7% of
sampled roots do not close, and their true cost above 20 M is *unknown*, with the one probe above
the cap (the empty root, >500 M) suggesting the tail is deep. Therefore:

- **Pass B (bulk).** Full population once, `RETRO_PARALLEL_BUDGET=20000000` — identical censoring
  conditions to T924, so the pass doubles as the population-scale check of the sample projection.
- **Passes T1..T3 (tail escalation).** After Pass B, enumerate the still-censored set and re-solve
  exactly those roots at budgets ×8 each pass: **160 M → 1.28 B → 10.24 B**. Escalation gates:
  - T1 always runs.
  - T2 runs only if T1 closed ≥ 50% of its entrants **and** ≤ 5,000 remain censored.
  - T3 runs only if ≤ 200 remain censored.
  - Any pass whose entrants are all still censored ends the ladder (zero marginal yield).
- **Global deadline: 240 h from job start.** If it fires mid-pass, stop escalating and report
  (§D5): the deadline is a reporting boundary, never a reason to fold caps into a mean.
- The final artifact must go to a **new path** (`RETRO_PARALLEL_OUT=data/oracle-4x4-writesoff-T936.wzo`,
  checkpoint likewise). Never overwrite a committed `.wzo` (AGENTS.md).

Consequence if ignored: a single 20 M run reproduces T924's censoring at population scale and
answers nothing new about the tail; a single uncapped run inherits the empty-root behaviour and
has no termination argument. The ladder buys measured knowledge of where between 20 M and ∞ the
tail actually closes, at worst-case pass costs ≈ 17.6 h (T1), ≈ 140 h (T2), gated so T3 cannot be
entered unless the remaining set is small enough to afford (~45 min serial/root worst case).

### D2 — Censored reporting: split always, means never touch capped roots

The row's deliverable statistic is the one T936 acceptance demands: **measured wall, measured
nodes, closed/censored split.** Rules:

1. A root that exhausts any pass budget is **censored**, reported at its last-tried budget, and is
   excluded from every mean, rate, and total presented as a cost estimate. Capped-at-cap means are
   how T924's headline came out 7.585× high (T929 §4).
2. Each pass reports its own node sum over its own closures. Cross-pass aggregation is by listing,
   not averaging.
3. If any root remains censored when the ladder stops, the doc states the count, their colex
   indices + sides, and the highest budget each survived — a censored result honestly reported is
   a result (T936 acceptance 3).
4. No projected range appears in `docs/research/4x4-d3-run.md`. The only numbers there are
   measured ones plus pointers to the superseded projections.

### D3 — Controls: three, all green (and demonstrably able to go red) before any 4×4 number

| control | arm | green criterion | what it catches | how red is shown |
|---|---|---|---|---|
| null | full 4×3 writes-off run through the identical detached path, rr, 16 threads, 20 M | total nodes **byte-for-byte 183,065,016** (T932); slowest/mean imbalance ≈ **1.20**; speedup within [9.3×, 13.9×] (11.6 ±20%) | wrong env flags (writes accidentally ON), partition regression, host misconfiguration — anything that would make 4×4 measure a different instrument | flip the arm to contig: the imbalance detector must reject it (that failure is the demonstrated red) |
| seeded defect | same 4×3 arm with `RETRO_PARTITION=contig` | checker reads slowest/mean ≥ 2.5 (measured 3.05) vs rr ≤ 1.35 (measured 1.20) and flags DEFECT | an instrument blind to the exact effect T930 found — it could not certify the 4×4 arm either | this arm *is* the positive control; it goes green precisely when the seeded defect is detected |
| killed run | SIGKILL the bulk pass mid-flight once, deliberately | relaunch resumes from checkpoint; per-layer completed-layer hashes unchanged; no lost layers | write-only-at-completion behaviour — the T924 near-loss mode | kill first, then show resume; a run that cannot survive this fails before burning days |

Ordering is mandatory: null → seeded-defect → killed-run → Pass B. A 4×4 number written before all
four have fired is void.

### D4 — Detached, supervised, sleep-proofed

Per T936 sequencing and the T928 convention: the compute is `nohup … &` with pid/command/log/
started_at recorded via the `job_start` function in `docs/infra/host/detached-jobs.md`. No agent
holds the lane. Two deliberate deviations-from-default, argued:

- **Wrap in `tools/runner --rss-cap-mb 32768`.** The docs say don't wrap by default; this run is
  the exception the same document names: 480× more work items than the measured 4×3 rung, an
  unmeasured memory profile at that scale, and a kernel-panic precedent on this host. 32 GiB cap
  on a 48 GiB host leaves headroom; SIGKILL-on-breach is survivable because checkpoints are
  per-finished-layer and flushed incrementally (and D3 proves it).
- **`caffeinate -i -s` inside the job command**, covering the whole run (T927: nothing in this
  repo calls caffeinate; 2026-08-24 slept 24 times and every wall from that day is suspect).

Shape (illustrative, paths fixed by the implementer):

```
job_start tools/runner --rss-cap-mb 32768 -- caffeinate -i -s sh -c \
  'zig build -Doptimize=ReleaseFast && \
   RETRO_SOUND=1 RETRO_PARALLEL=1 RETRO_4X4=1 RETRO_PARTITION=rr \
   RETRO_PARALLEL_THREADS=16 RETRO_PARALLEL_BUDGET=20000000 \
   RETRO_PARALLEL_OUT=data/oracle-4x4-writesoff-T936.wzo \
   RETRO_PARALLEL_CKPT=data/oracle-4x4-writesoff-T936.checkpoint.wzo \
   ./zig-out/bin/retro'
```

(`RETRO_SOUND=1` and no `RETRO_DEPS` is the writes-off configuration — verified against
`runParallel`'s flag logic, `src/retro.zig`.) Threads **16**, not 18: T930 measured rr peaking at
16 (11.54×) and degrading at 18 (10.87×) via contention.

### D5 — Stopping and partial results

- Ladder gates (D1) + zero-marginal-yield rule + global 240 h deadline.
- On any stop, short of completion: the row closes **blocked** with the partial curve committed —
  per-pass table (entrants, closures, nodes, wall), the censored-root list (§D2.3), and the
  checkpoint hash. Per T936 acceptance 3 this is a legitimate close; an unfinished-looking number
  that hides a cap is not.

### D6 — Recording: what a non-runner needs to check the answer

Committed under `docs/evidence/T936/` with a PROVENANCE.md:

1. jobs.jsonl lines for every pass (pid, command, log path, started_at) — execution trace.
2. Per-pass summary CSV: entrants, solved, censored, node sum, wall, max/root, per-thread node
   counts (the imbalance ratio is derivable from them, as in T932).
3. The censored-root list: colex index, side, last-tried budget (small; commit even if long-ish).
4. Per-layer histogram of root node counts, log-bucketed — enough to recompute the closed/censored
   split without the 600 MB-class raw per-root dump, which stays on disk, hashed but not committed.
5. SHA256 of the final artifact and of each checkpoint consumed.
6. Host-state assertion per pass: cores busy, RSS peak (runner record), caffeinate present in the
   process tree at launch, start/end timestamps absolute.

Supersession bookkeeping per T936 acceptance 4: `4x4-d3-run.md` names the projections it
supersedes (T924's 202.5–1,620 h, T929's 26.8–214.7 h lower bound) and why; the two older docs
gain pointer lines; no correction history is edited away.

## 3. Acceptance arms (red-then-green, armed counts)

Test-first per the standing tooling rule; each arm ships its checker before the run starts.

| # | arm | red-then-green must | incident it would have caught | armed count |
|---|-----|--------------------|--------------------------------|-------------|
| A1 | null-control gate | checker run on the contig 4×3 fixture FAILS (red), then on the production rr rerun PASSES byte-identical (green) | T930's finding invisible → 4×4 launched on a mis-partitioned finisher believing it balanced | 1 fixture pair, 1 assertion set |
| A2 | imbalance detector thresholds | synthetic per-thread vectors at 1.20 and 3.05 straddle the [1.35, 2.5] band: low→PASS, high→DEFECT | threshold drift making the seeded-defect control vacuous | 2 synthetic vectors |
| A3 | censored-accounting unit test | fixture with one known capped root: reporter outputs it in the censored section and excludes it from means; a variant that folds it into a mean is flagged | T924's 7.585× error, reintroduced at population scale | 1 good fixture + 1 poisoned |
| A4 | resume-integrity check | after the deliberate SIGKILL, completed-layer hashes match pre-kill hashes; relaunch does not redo closed layers | checkpoint corruption / lost-work silent mode | 1 hash manifest |
| A5 | flag-config assert | launcher refuses to start unless `RETRO_SOUND=1 ∧ !RETRO_DEPS ∧ OUT/CKPT are fresh paths ∧ THREADS=16` | a week-long run with memo_writes ON — the untrustworthy-column defect, rediscovered post-hoc | 1 static check at launch |

All five arms fire before Pass B; A3/A5 additionally gate every tail pass. Total armed: 5 arms /
7 checks. **No 4×4 number exists until all arms are green; the green runs are pasted into
`docs/research/4x4-d3-run.md`.**

## 4. Alternatives considered and rejected

- **One uncapped run** (some sibling briefs' instinct): rejected — no termination argument; the
  only datum above 20 M (empty root >500 M) points the wrong way, and 92.6%-of-nodes censored
  roots become an unbounded tail rather than a measured one. The ladder measures the tail; the
  uncapped run hopes about it.
- **Flat huge cap (e.g. 10B) for everyone:** rejected — pays 10B-node worst-case pricing on the
  whole population's stragglers up front instead of discovering the actual frontier pass by pass;
  also makes the bulk and tail passes incomparable to T924/T929 conditions.
- **Sampled 4×4 again at bigger budgets:** rejected — T936's entire premise is that sampling
  weights are gone; a sample reintroduces exactly the error class T929 corrected.
- **Agent-held lane with heartbeats:** rejected — T924 held ox-alpha 4,110 s and wrote neither
  deliverable; T928's ruling is explicit.
- **Unsupervised bare nohup:** rejected for this run specifically — unmeasured RSS profile at
  480× the measured scale on a host with a compressor-incident history; supervision is the
  documented exception path and is invoked with reasons, not habit.
- **Track B (deps) comparison arm:** out of scope (below); mixing it into this row doubles the
  blast surface of a multi-day run for a question this row does not ask.

## 5. Out of scope

- Track B / dependency-guarded reuse at 4×4; any writes-ON regeneration (the checkpoint column
  distrust stays until Track A regenerates with `memo_writes=false` — which is what this row is).
- Any real-game or PSK reading of the results: outputs are **fresh-start (C1)** values; C2 is
  falsified at 3×2, and no table value may be quoted as a real-game score (foreclosures).
- 5×4, 5×5, sub-goban restriction (unsound by standing rule), eye-prune changes.
- Measuring the orbit factor, per-layer ns/node, or thermal throttling beyond what the per-pass
  records happen to expose.
- Promoting the artifact to replace any committed `.wzo`, and the #2 auditor battery — that is
  the consuming row's gate, not T936's.

## 6. What this spec deliberately leaves out (wall accounting)

Written inside a 2700 s wall; roughly half of it went to verifying §1's numbers against evidence
files and `src/retro.zig` flag logic. Left out, with the consequence accepted: exact disk-size
forecast for the raw per-root stream (bounded above by ~600 MB, hashed not committed); a
thermal-throttle monitor (caffeinate + runner record bound the damage); automation glue for the
tail passes (they are three manual launches with recorded pids — ceremony-free per T928).
