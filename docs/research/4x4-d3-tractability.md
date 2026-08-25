# 4x4.D3 — is 4×4 tractable with memo writes off? Measured: no.

**Task:** T924 (`ox-alpha`), 2026-08-25. **Recovered by the T914 seat from the lane transcript**
— the lane ran the full ladder and both arms, then exited 0 without writing this file or its
findings. The runner's auto-close correctly declined (T862 ·3) and left the row open. Every number
below is a line the probe printed; none is re-derived.

**Instrument:** `src/t924_d3_probe.zig` (committed, `4a80255`). **Host:** 18 cores (6P+12E), 48 GB,
single-threaded solve. **Ledger:** `docs/infra/host/goban-scaling.jsonl`.

## Answer

**Not tractable.** At 4×4 the writes-off finisher projects to **202.5 – 1,620 hours** (8.4 – 67.5
days) of single-threaded wall, and **9.7% of sampled roots do not solve at all** within a
20,000,001-node cap. Per ADR-0013 this is the branch that was already ruled on: *"Track B becomes
blocking rather than a follow-up."*

The same probe's writes-on arm projects **1.94 – 15.52 hours** — a ~100× gap. **Writes-on is not
an escape**: T912 established it is unsound under superko (memo-reuse differs from writes-off on
170 of 378 ko-sensitive 3×2 pairs, and brackets plus symmetry accept both tables completely). It
is a calibration control here, and the row was right to run it as one.

## The ladder — writes-off completes cleanly through 4×3

| board | ko-sensitive pop | samples | solved | skipped | nodes | wall |
|---|---|---|---|---|---|---|
| 2×2 | 82 | 9 | 9 | **0** | 4,554 | 0 ms |
| 3×2 | 378 | 57 | 57 | **0** | 37,568 | 3 ms |
| 3×3 | 8,698 | 620 | 620 | **0** | 323,692 | 40 ms |
| 4×3 | 170,276 | 20,878 | 20,878 | **0** | 183,442,515 | 35.2 s |
| 4×4 | 10,367,922 | 1,287 | 1,162 | **125** | 2,700,272,692 | 709.9 s |

4×3 is exhaustive over its ko-sensitive region — 20,878 of 20,878, zero skips. **4×4 is the first
board where the method fails to close roots at all**, and it fails on roughly one root in ten.

## Build vs finish — the build is not the problem

| board | legal | sweeps | ko-sensitive/side | build wall |
|---|---|---|---|---|
| 2×2 | 57 | 2 | 41 | 0 ms |
| 3×3 | 12,675 | 12 | 4,349 | 117 ms |
| 4×3 | 321,689 | 17 | 85,138 | 4.9 s |
| 4×4 | 24,318,165 | 19 | 5,183,961 | **509 s** |

The retrograde build at 4×4 finishes in 8.5 minutes. The cost is entirely in the finisher over the
ko-sensitive region, which is **5,183,961 slots per side — 10.4 million (slot, side) roots.**

## The two arms at 4×4, side by side

| | writes-off | writes-on |
|---|---|---|
| solved / sampled | 1,162 / 1,287 | **1,287 / 1,287** |
| skipped (hit 20 M cap) | **125** | 0 |
| sum nodes | 2,700,272,692 | 18,240,863 |
| max nodes at one root | **20,000,001** (capped) | 252,205 |
| mean nodes / nontrivial root | **2,139,677.3** | 14,453.9 |
| ns per node | 262.90 | 372.84 |
| projected finisher nodes | 2.77 × 10¹² – 2.22 × 10¹³ | 1.87 × 10¹⁰ – 1.50 × 10¹¹ |
| **projected wall** | **202.5 – 1,620 h** | 1.94 – 15.52 h |

**148× more nodes per root**, and the writes-off arm is additionally *truncated* — its mean excludes
the 125 roots that never finished, so 202 hours is a floor, not an estimate of the true cost.

This is the mechanism T912 measured at 3×2 showing up at scale: 0.541 new states per node, flat
across five doublings with no plateau. Nearly every path is a distinct ban set, so the memo has
almost nothing to reuse. Writes-off does not lose a constant factor; it loses the transposition
table.

## What this settles and what it does not

**Settles:** `4x4.D3` is measured. Track A as specified — writes-off regeneration through 4×4 —
does not fit on this host. Track B (Kishimoto–Müller dependency-guarded reuse, already implemented)
becomes the blocking path rather than a follow-up, exactly as ADR-0013 anticipated.

**Does not settle, and must not be read as settled:**

1. **The projection is a sample extrapolation**, 1,287 roots of 10,367,922 (0.012%). The lane was
   mid-way through a layer-population-weighted re-estimate when it stopped, because unweighted
   means are distorted by per-layer sampling caps. The weighted number is not in hand.
2. **The bracketed range spans 8×** (2.77 × 10¹² – 2.22 × 10¹³). Nothing here narrows it.
3. **Single-threaded.** The retrograde solve is not threaded (`arena.zig`, `differential.zig`,
   `exp6_solve.zig` thread the harness, not the solve). 18 cores are idle. A parallel finisher is
   an unexplored order of magnitude and could move 202 h materially.
4. **The 20 M node cap is a choice**, not a wall of nature. 125 roots hit it; how far past it they
   would run is unmeasured.
5. **An "empty-root escalation ladder" was launched and never reported** (pid 2538 in the lane).

## Follow-on, in the order that matters

1. Re-do the projection **layer-population-weighted** from the committed per-root CSV rather than
   the unweighted mean. Cheap; the lane had already identified this as the correction needed.
2. Cost a **parallel finisher** before accepting 202 hours. 10.4 M independent roots on 18 cores is
   the obvious shape, and nobody has measured it.
3. Then take Track B's dependency-guarded arm to 4×4 and compare against this row's numbers.
