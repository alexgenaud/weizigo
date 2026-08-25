# 4×4.D3 — weighted re-projection of the writes-off finisher cost (T929)

**Task:** T929 (`deepseek-v4-flash`), 2026-08-25. **Short name:** *redo T924's projection
layer-population-weighted. No compute required.* **Landmark:** advances `L2 (proven 4×4 values)` —
this row either confirms T924's not-tractable ruling on a sound statistic or overturns it. It cuts
whichever way the arithmetic cuts.

**Answer up front:** the layer-population-weighted re-projection **confirms the not-tractable
verdict** (T924), but on a **7.6× narrower bracket**: **26.8 – 214.7 h** single-threaded wall
(lower bound) instead of 202.5 – 1,620 h. The correction moves the cost estimate by almost an
order of magnitude, reframes *where* the cost lives (a small tail of pathological roots, not the
bulk of the population), and materially strengthens the parallel-finisher follow-on.

No solve was run. Everything below is arithmetic on T924's committed evidence plus one datum the
lane transcript carried that the committed evidence did not: the per-layer stratification.

---

## 1. The defect, restated

T924's 4×4 projection used an **unweighted mean** of nodes per nontrivial root, 2,139,677.3, over
1,287 sampled roots (0.012% of the 10,367,922-slot ko-sensitive population). The probe samples each
stone-count layer to a cap of 48 roots per side (`src/t924_d3_probe.zig`, `walkLayers`). An
unweighted mean over a capped stratified sample over-weights small layers relative to their true
population share, and under this probe the small layers happen to be the expensive ones:

| layers | population | layer mean (nodes/root) | samples |
|---|---|---|---|
| 0–3 (0–3 stones) | 4,426 slots (0.04%) | 20.0M / 10.0M / 8.1M / 2.9M | 1+4+40+93 |
| 8–10 (8–10 stones) | 6,306,284 slots (60.8%) | 367k / 414k / 276k | 97 each |
| 13–15 (13–15 stones) | 220,096 slots (2.1%) | 1.4M / 9.3M / 10.1M | 97+95+88 |

The unweighted mean gives layers 0–3 (0.04% of the population) ~11% of the weight by sample count
and layers 13–15 (2.1%) ~22%, while layers 8–10 (60.8%) get ~23%. The population-weighted mean
fixes exactly that.

## 2. Recovering the stratification (deliverable 1)

**Layers.** The colex address space is layered by stone count (`src/colex.zig`): layer *k* holds all
positions with *k* occupied cells, size C(16,k)·2^k, offsets cumulative. The layer of any sampled
root is a pure function of its colex index — no solve needed.

**Per-layer populations — NOT in the committed evidence.** The per-root rows carry no population
counts, and `docs/evidence/T924/summary.csv` (T914's recovery) contains only the build/total/
projection lines — the probe's per-layer `T924,summary,writes-off,{layer},...` lines were printed
but not recovered into it. **The committed evidence alone cannot reconstruct the stratification**;
this is the brief's stated stopping condition, and it would have been the answer had the raw data
not survived elsewhere.

**Where it did survive:** the lane transcript log for T924 (host-local, the same source T914
recovered the totals from) contains the probe's own per-layer summary lines for the 4×4
writes-off run (run 2). They are reproduced verbatim and committed under git as
`docs/evidence/T929/per-layer-recovery.csv`, so the weighted projection is reproducible from git.
This is the same recovery path T914 used for the totals; the per-layer block was simply missed.

**Verification against `per-root.csv` (1,351 rows, all writes-off):**

- Layers 4–15: per-root aggregates match the transcript per-layer summary **exactly** (samples,
  solved, skipped, single_ko, node sums).
- Layers 0–3: per-root.csv carries **64 extra rows** (1, 7, 49, 7 in layers 0–3) — contamination
  from the 3×2 selftest runs that precede the 4×4 work (their roots live in the same colex layer
  indices). They total 44,784 nodes = 0.0017% of the 2.70 B measured, and the transcript summary
  (probe-computed) is authoritative for those layers.
- Totals: per-root.csv sums 2,700,317,476 nodes / 713,657 ms vs transcript run 2
  2,700,272,692 / 713,651 — consistent to the contamination.

## 3. Weighted projection (deliverable 2)

Same bracket as T924, so the two are directly comparable: projected wall = population × mean ×
ns/node × orbit factor, where the orbit factor brackets between ÷8 (every sampled slot's orbit is
maximal, so one solve per orbit) and ×1 (every orbit trivial). Only the mean changes — unweighted
→ population-weighted:

$$ \bar{m}_w = \frac{\sum_l pop_l \cdot \bar{m}_l}{\sum_l pop_l} $$

with $\bar{m}_l$ the probe's own per-layer mean (see §4 for what it does and does not contain) and
$pop_l = pop\_b_l + pop\_w_l$ the ko-sensitive slot counts from the recovery.

| figure | mean nodes/root | projected wall (single-threaded, 264.29 ns/node) |
|---|---|---|
| T924 unweighted (published, ns 262.90) | 2,139,677.3 | 202.5 – 1,620 h |
| T924 unweighted (recomputed, ns 264.29) | 2,139,677.3 | 203.6 – 1,628.6 h |
| **weighted, as measured (this row)** | **282,104.8** | **26.8 – 214.7 h** |
| weighted, 125 capped roots excluded (§4) | 52,976.1 | 5.0 – 40.3 h (diagnostic) |

**Ratio: the weighted figure is 7.585× lower than the unweighted one at both ends of the bracket.**
T924's headline numbers were inflated by the sampling distortion, not by the real cost profile.

**Where the weighted cost concentrates** (share of the population-weighted node sum): layer 9
(32.6%), layer 10 (22.6%), layer 8 (20.1%), layer 13 (9.3%), layer 14 (6.0%), layer 6 (4.2%),
layer 5 (2.0%), layer 15 (1.3%) — the top 8 layers hold 98.2%. Layers 8–10 alone (60.8% of the
population) hold 75.3%. The weighted mean is dominated by the *big* layers, whose measured means
(276k–414k nodes/root) are the honest middle of the cost curve.

**Second-order corrections, both small relative to the 8× bracket:** single-ko roots (25/1,287 =
1.94% of samples, 0 nodes) are counted as full-cost roots in T924's formula; correcting gives
~276,625 mean → 26.3 – 210.5 h (−1.9%). Per-layer ns/node is stable at 260–268 ns (vs the global
264.29), so layer-varying ns moves nothing material.

**Residual caveats, unchanged from T924:** the bracket still spans 8× (orbit sizes are unmeasured
per layer; the weighting does not touch the orbit factor), the projection remains a sample
extrapolation (0.012% of the population), and the means for the big layers rest on ~97 samples
each. None of these is made worse by the weighting.

## 4. The 125 censored roots (deliverable 3) — and a correction to T924's doc

**Correction first:** T924's doc (and the T929 brief) say the mean "excludes the 125 roots that
never finished". **It does not.** The probe's `sum_nodes` accumulator includes budget-exhausted
roots at their capped node count (20,000,001; `walkLayers`: `ls.sum_nodes += out.nodes`, and a
capped `measureRoot` returns `nodes = f.ctx.nodes` = 20,000,001). The per-layer mean divides that
sum by `samples − single_ko`, capped roots included. So the reported mean is *not* a mean of the
roots that finished; it is a mean that counts the 125 capped roots at the cap.

The **floor conclusion survives, via a different mechanism**: the true node count of every capped
root is ≥ 20,000,001, so the true mean (and true wall) is ≥ the measured one. 202 h — and the
weighted 26.8 – 214.7 h — are lower bounds on the true cost, not estimates.

**The censored roots dominate the measurement.** The 125 capped roots (9.71% of samples) account
for 2,500,000,125 of the 2,700,272,692 measured nodes — **92.6%**. Excluding them, the solved-root
mean is 176,141 unweighted (12.2× the writes-on mean, not the 148× the capped-inflated headline
suggests) and ~53k population-weighted.

Per-layer distribution of the 125 (none in layers 7, 11, 12):
layer 0: 1 · 1: 2 · 2: 15 · 3: 10 · 4: 4 · 5: 1 · 6: 1 · 8: 1 · 9: 2 · 10: 1 · 13: 6 · 14: 37 · 15: 44.

The tail is where the cost is. Layers 13–15 are the starkest example — their solved roots are
nearly free (mean 63 / 892 / 274,657 nodes excluding capped) while their layer means read 1.4M /
9.3M / 10.1M purely because of the capped roots counted at 20 M each:

| layer | pop | samples | solved | skipped | mean (as measured) | mean (capped excluded) |
|---|---|---|---|---|---|---|
| 13 | 197,368 | 97 | 91 (10 single-ko) | 6 | 1,379,369 | **63** |
| 14 | 19,000 | 95 | 58 (15 single-ko) | 37 | 9,250,480 | **892** |
| 15 | 3,728 | 88 | 44 | 44 | 10,137,329 | 274,657 |

**With them excluded:** the weighted projection treats the capped roots as costing nothing —
5.0 – 40.3 h. This is *not* a valid estimate; it is the diagnostic that shows the bulk of the
ko-sensitive population is cheap and the entire tractability question hangs on the tail.

**Defensible lower bound with them included:** counting each capped root at its minimum possible
cost (the cap) gives the as-measured **26.8 – 214.7 h** — a true lower bound, since their real
cost is ≥ the cap. How far above it lies is **unmeasured**: the "empty-root escalation ladder"
(pid 2538) ran at escalating budgets but its output was never captured — the transcript contains
only the `T924,empty,...` format strings, no results. Layer 0's single root (the empty goban) is
one of the capped roots, so the ladder would have bounded the single most important unknown, and
the lane died without reporting it.

## 5. Rule: does the weighted number change the verdict? (deliverable 4)

**No — it confirms it, on a much narrower margin.** T924 ruled 4×4 writes-off not tractable
(single-threaded, this host) on a 202.5 – 1,620 h projection plus a 9.7% root-failure rate at the
20 M cap. The weighted re-projection gives **26.8 – 214.7 h as a lower bound** on the same
quantity: the low end is ~1.1 days, the high end ~8.9 days of single-threaded wall, the bracket
still spans 8×, and the true cost is ≥ the bracket and could be far higher depending on the
unmeasured tail. The ≤ 8 h target in the register row (4×4.D3) is not met at any reading of the
bracket.

What *does* change: the margin. T924's 1,620 h high end was ~7.6× sampling distortion, not
reality; the honest single-threaded lower-bound estimate is ~1–9 days, and the cost profile (bulk
of the population at ~53k–400k nodes/root; a small tail of uncapped-exploding roots) is exactly
the shape a **parallel finisher** exists to absorb — 10.4 M independent roots over 18 cores is the
obvious geometry, and the tail roots can be given larger budgets or recorded as unsolved rather
than killing the run. T924's follow-on #2 (cost a parallel finisher before accepting 202 h) is
strengthened, not weakened: the honest number it would attack is 26.8 – 214.7 h (lower bound),
i.e. hours-to-a-day on 18 cores if the tail cooperates.

## 6. What this settles and what it does not

**Settles:** the population-weighted correction to T924's projection. The unweighted mean was
distorted by the per-layer caps, in the direction T924 itself suspected; the corrected bracket is
26.8 – 214.7 h (lower bound), 7.6× below the published one, and it **confirms the not-tractable
verdict under T924's criterion** (single-threaded, 20 M cap, 9.7% failure). T924's `4x4.D3`
"MEASURED — NOT TRACTABLE" reading stands.

**Does not settle, and must not be read as settled:**

1. **The true cost above the lower bound.** 92.6% of measured nodes sit in the 125 capped roots;
   their true cost is unmeasured and unbounded from this data (the empty-root ladder never
   reported). The bracket is a floor, not an estimate.
2. **The orbit factor.** The 8× bracket (÷8 maximal orbits to ×1 trivial) is untouched by the
   weighting; per-layer orbit sizes are unmeasured.
3. **Single-threaded.** The retrograde solve is not threaded; a parallel finisher is the natural
   next measurement and now looks materially more promising than T924's numbers suggested.
4. **Sample extrapolation.** 1,287 of 10,367,922 roots (0.012%); per-layer means on ≤97 samples.
5. **The 20 M cap is a choice**, and this row shows how much the answer depends on it.

## Follow-on, in the order that matters

1. **Cost a parallel finisher** (T930 is queued for exactly this) against the honest number —
   26.8 – 214.7 h single-threaded lower bound on 10.4 M independent roots.
2. **Bound the tail**: re-run the empty-root escalation ladder with output captured, and probe how
   far past 20 M the capped roots run — the single largest unknown in the projection.
3. Track B's dependency-guarded arm to 4×4, compared against this row's numbers.

## Evidence

- `docs/evidence/T924/per-root.csv`, `docs/evidence/T924/summary.csv` — T924's committed evidence.
- `docs/evidence/T929/per-layer-recovery.csv` — the recovered stratification, verbatim from the
  lane transcript (this row; the only committed copy of the per-layer populations).
- `src/t924_d3_probe.zig` — the instrument; column meaning and the sampling/capping mechanics
  read from source, not from guessed headers.
- `src/colex.zig` — layer offsets (combinatorial, no solve).

Provenance note: the per-layer populations exist nowhere in the committed T924 evidence (the
per-root rows carry no population counts; `summary.csv` has no per-layer lines). They survive
only in T924's host-local lane transcript log; they were copied verbatim into
`docs/evidence/T929/per-layer-recovery.csv` at commit time so this row's arithmetic is
reproducible from git. Until that file is absorbed upstream, a re-derivation from a fresh clone
cannot recover the stratification without re-running the probe (509 s build + 11.8 min sampling
per the T924 doc) — the brief's stated stopping condition, which would have been the answer had
the transcript not survived on this host.
