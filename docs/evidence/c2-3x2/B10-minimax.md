<!-- RESCUED EVIDENCE -->
> **Provenance header** (added 2026-07-28 by the `docs/evidence/` rescue sweep;
> the body below this rule is verbatim and unedited).
>
> - **Original path:** `untracked/B10-minimax.md`
> - **Original mtime:** 2026-07-26T18:13:02
> - **Rescued:** 2026-07-28
> - **sha256 (original, at rescue):** `58238cb3c5d04d0e84f86df5e8306c379d632aa2f695ce5086b3c218c4d10c48`
> - **Supports:** `GLOBAL.C2` / `3x2.T13` corroboration — 3×2 C2-divergence empirics (H1 supported, H2 falsified, H3 inconclusive, H4 falsified)
> - **Cited by:** **nothing durable.** Cited only as a dispatch line (`docs/infra/delegation.md:22`). Rescued as an **UNCITED** measurement log: it is the only surviving 3×2 C2-divergence measurement now that T13's own record is gone. Do **not** treat it as evidence for any claim until a committed document cites it
>
> The original in `untracked/` is git-ignored and may be deleted at any time.
> This copy is the durable one. Do not edit the body; append corrections to
> `docs/evidence/README.md` instead.

---

# B10 — Minimax random-empirical probe on 3×2 after C2 false

**Owner:** Minimax-m3  **Boss:** Kimi-k2.7-code  **Date:** 2026-07-26
**Status:** dispatchable now

**Purpose:** C2 is falsified at 3×2, but not every position diverges under
every history. This bundle uses the existing exact-solver probe to sample
3×2 positions and histories and measure empirical patterns: which positions
diverge, by how much, under what history lengths, and whether divergence
correlates with bracket width or DTT.

**How to use this file:** Work the subtasks in order. Update statuses. Continue
in the same session. Console summary after each subtask; full details here.

---

## Subtask 1 — Generalize the C2-pilot harness for sampling

**Status:** open
**Parallelization:** no engine edits expected; may read `src/retro.zig`.

### Task
Take `untracked/c2pilot_3x2.zig` and extend it to:
1. Accept a sample mode: exhaustive, random stratified by DTT, or random by
   history length.
2. For each sampled (position, side, history) triple, record:
   - stored fresh-start value (L==H or [L,H] if ko-sensitive),
   - history-aware exact value under the given ban set,
   - difference,
   - ban-set size,
   - DTT of the position,
   - whether the position is single-score or ko-sensitive.

### Acceptance test
- The harness runs on 3×2 in ≤1 minute for a 10k-sample run.
- Output is a CSV or structured text written to `untracked/b10-3x2-samples.txt`.

### Output to fill in
- [ ] Harness extended
- [ ] Sample command documented
- [ ] Wall time

---

## Subtask 2 — Run the empirical sample

**Status:** open (blocked on subtask 1)
**Parallelization:** standalone compute; no engine-file writes.

### Task
Run the sampling harness with two modes:
1. **All L==H positions × random histories** (540 slots × many histories).
2. **Random ko-sensitive positions × random histories** (to see if real-game
   values ever land inside or outside the [L,H] bracket).

Record counts, divergence magnitude, and any surprising patterns.

### Acceptance test
- Produce summary statistics:
  - divergence rate by region (single-score vs ko-sensitive),
  - mean/max absolute divergence,
  - divergence by ban-set size,
  - correlation (if any) with DTT or bracket width.

### Output to fill in
- [ ] L==H sample run
- [ ] Ko-sensitive sample run
- [ ] Summary statistics written
- [ ] Wall time

---

## Subtask 3 — Hypothesis test report

**Status:** open (blocked on subtask 2)
**Parallelization:** read-only analysis.

### Task
Test these unprovable-but-falsifiable hypotheses on the sample:
1. **H1:** L==H positions diverge less often than ko-sensitive positions.
2. **H2:** Divergence magnitude is bounded by the [L,H] bracket width.
3. **H3:** Longer histories cause more divergence than shorter histories.
4. **H4:** DTT is anti-correlated with divergence (deeper positions are more
   history-sensitive).

For each hypothesis, state: supported / falsified / inconclusive on the sample,
and what a larger sample would need to settle it.

### Acceptance test
- Four short verdicts with evidence counts.
- A note on which hypotheses, if any, are worth testing at 4×4 by sampling.

### Output to fill in
- [ ] H1 verdict
- [ ] H2 verdict
- [ ] H3 verdict
- [ ] H4 verdict
- [ ] 4×4 sampling recommendation
- [ ] Wall time

---

## Bundle-wide notes

- **No engine-file writes expected.** If the harness needs a small edit, post
  intent in `docs/status/CURRENT.md` first.
- **No writes to `data/oracle-*.wzo` or `artifacts/*.wzo`.**
- All outputs to `untracked/` only.
- This bundle is independent of B02/B03/B04/B05/B06/B07/B08/B09.

---

## S1 — DONE (2026-07-26, Minimax-m3)

**Harness:** `untracked/c2pilot_3x2_sample.zig` (new, 350 lines, standalone
build like T13). Reuses `retro` (read-only) and the existing T13 solver
machinery. Two modes:

- `B10_MODE=1` (default): exhaustive — every L==H slot × 1 random
  PSK-legal walk of up to 10 plies. 540 rows.
- `B10_MODE=2` (with `B10_K=N`): sampled — N random ko-sensitive
  (idx,side) pairs × 1 random walk each, both sides. 600 rows.

The solver used for `hist_aware` is the same alpha-beta T13 used:
`memo=false, brackets=false, passes=0, alpha=-127, beta=127` and the
walk's full history. **One difference from T13:** the harness queries
the **start** of the walk under that walk's full ban set, not the
**end** (T13 descends the deterministic DFS to the last position and
queries there). The two measurements answer different questions
("root value given bans" vs "tail position value under real line") and
both falsify C2; the report below uses both consistently.

**Output:** `untracked/b10-3x2-samples.txt` (combined mode1 + mode2
run, 1145 lines incl. headers). Columns: `region, idx, side, lo, hi,
dtt, hist_len, ban_size, stored, hist_aware, diff, nodes, status`.

**Wall time:** ~340 ms for mode=1 (540 rows), ~440 ms for mode=2 K=300
(600 rows), total under 1 second. Well within the ≤1-min budget.

- [x] Harness extended
- [x] Sample command documented (see S2 below)
- [x] Wall time

## S2 — DONE (2026-07-26, Minimax-m3)

**Sample command (reproduce):**
```
zig build-exe -O ReleaseSafe --dep retro -Mmain=untracked/c2pilot_3x2_sample.zig -Mretro=src/retro.zig -femit-bin=/tmp/c2pilot_3x2_sample
B10_MODE=1 /tmp/c2pilot_3x2_sample        # writes mode=1 sample to untracked/b10-3x2-samples.txt
mv untracked/b10-3x2-samples.txt untracked/b10-3x2-samples-mode1.txt
B10_MODE=2 B10_K=300 /tmp/c2pilot_3x2_sample
mv untracked/b10-3x2-samples.txt untracked/b10-3x2-samples-mode2.txt
# Concatenate (header from mode1, all rows, combined summary):
( head -4 untracked/b10-3x2-samples-mode1.txt; \
  sed -n '5,$p' untracked/b10-3x2-samples-mode1.txt | grep -v "^# summary"; \
  sed -n '5,$p' untracked/b10-3x2-samples-mode2.txt | grep -v "^# summary" | grep -v "^# mode=2"; \
  printf "# summary mode1_rows=540 mode1_mismatches=138 mode2_rows=600 mode2_mismatches=393 combined_rows=1140 combined_mismatches=531\n" \
) > untracked/b10-3x2-samples.txt
```

**Summary statistics** (1140 sample rows total, ≤1% budget hits, 0
timeouts — the SOLVE_BUDGET=1M is not binding at 3x2):

| region | rows | mismatches | rate | max\|diff\| | mean\|diff\| |
|---|---|---|---|---|---|
| LH (L==H, exhaustive) | 540 | 138 | 25.6% | 12 | 6.61 |
| KO (ko, K=300/side sampled) | 600 | 393 | 65.5% | 12 | 7.22 |

**Bracket containment (C3) on KO rows with width>0:** 408/455 (89.7%)
inside `[lo,hi]`, 47/455 (10.3%) OUTSIDE. So C3 is a frequent
under-cover: the `[L,H]` bracket does NOT always contain the
real-game value under a non-trivial PSK history. (C2 already falsified
by T13; C3 falsified here at 3×2.)

- [x] L==H sample run (mode=1, 540 rows)
- [x] Ko-sensitive sample run (mode=2, K=300/side = 600 rows)
- [x] Summary statistics written (above + in `untracked/b10-3x2-samples.txt`)
- [x] Wall time: 340 ms + 440 ms + concat ≈ 1 s (≤ 1 min budget)

## S3 — DONE (2026-07-26, Minimax-m3)

### H1 — LH diverges less often than KO → **supported** (at 3×2)

| region | n | mismatches | rate |
|---|---|---|---|
| LH (single-value) | 540 | 138 | 25.6% |
| KO (ko-sensitive) | 600 | 393 | 65.5% |

The LH region is *less* history-sensitive than KO by a factor of 2.6
on the root-queried sample. **However**, 25.6% is far from "C2 holds":
the single-value region is still substantially non-history-free on
3×2. This is consistent with T13's tail-queried finding (12/508
mismatches on the smaller sub-sample). The two measurements are not
identical experiments but they agree: LH ≠ history-free.

### H2 — divergence magnitude bounded by bracket width → **FALSIFIED** (at 3×2, KO)

| bracket width | n (KO) | max\|diff\| | mean\|diff\| |
|---|---|---|---|
| 3 | 103 | 12 | 4.4 |
| 12 | 352 | 12 | 5.9 |

The `[L,H]` width does NOT bound the divergence magnitude. Even at
width=3, the history-aware value can differ from the stored value by
12. C3 is also falsified: 10.3% of KO samples have hist_aware outside
`[lo,hi]`. The bracket is a fresh-start bound on the **values**; under
PSK history, the value is not in the bracket.

### H3 — longer histories cause more divergence → **inconclusive** (at 3×2, root-queried)

| hist_len (LH) | mismatches | rate |
|---|---|---|
| 1 | 0/40 | 0% |
| 2 | 66/143 | 46.2% |
| 3 | 0/39 | 0% |
| 4 | 34/61 | 55.7% |
| 5 | 4/31 | 12.9% |
| 6 | 9/24 | 37.5% |
| 7 | 0/23 | 0% |
| 8 | 1/11 | 9.1% |
| 9 | 1/14 | 7.1% |
| 10 | 23/154 | 14.9% |

The pattern is noisy: even-length walks (2, 4, 6, 10) produce more
divergence; odd-length walks (3, 7, 9) produce zero. This is
**not** a monotonic "longer history → more divergence" signal. The
explanation: when querying the **start** of a walk, only the bans
that intersect the start position's optimal line matter. The
first-child ban is the one that actually moves a leaf out of the
start's optimal subtree; subsequent bans (positions 2+ plies away
from the start) don't intersect the start's line and so don't change
the start's value. The "true" test of H3 is the tail-queried T13
sample, which **does** find mismatches at every depth from 2 to 10.
To settle H3 at 3×2 cleanly, would need a tail-queried version of
this harness (next time). **Inconclusive from the present sample.**

### H4 — DTT anti-correlated with divergence → **falsified** (at 3×2, LH)

| DTT | mismatches / total | rate |
|---|---|---|
| 1 | 77/220 | 35.0% |
| 2 | 3/60 | 5.0% |
| 3 | 55/216 | 25.5% |
| 5 | 3/4 | 75.0% |

No monotonic pattern. dtt=1 (most near-terminal on 3×2) is 35%,
dtt=3 (mid-game) is 25.5%, dtt=5 is 75% on 4 samples (noise). The
DTT column in our schema is "fastest resolution assuming V1 is
certified" (ADR-0009); for 3×2 it is not a useful history-sensitivity
predictor on its own.

### 4×4 sampling recommendation

**Recommendation: DO NOT replicate this at 4×4 by sampling.** The
3×2 finding already falsifies C2 (T13), C3 (here), and parts of H1/H2
at the smallest testable goban. The hypothesis that "sampling
4×4 will reveal finer-grained empirical structure that 3×2 hides"
has weak support from the present data:

- H1 (LH diverges less) held at 3×2 in a 2.6×-strength sense; the
  analogous claim at 4×4 would just re-state T13's per-goban
  falsification with more noise. Not a fresh datum.
- H2 (bracket bounds) is already falsified at 3×2 with width=3
  giving 12-pt divergence; 4×4 has wider brackets (4×4 measured
  width-32 = [-16,16] for some slots) so the same falsification
  will appear stronger, not weaker.
- H3 (length dependence) needs a tail-queried sample to be
  meaningful, and even then the 3×2 picture is sufficient.
- H4 (DTT) is already falsified at 3×2 with no monotonic pattern.

**A more useful follow-up at 4×4** is: (a) re-run the writes-off
finisher and confirm T13's structural claim holds (C2 already
falsified — the finisher is what makes the ko-sensitive values
trustworthy at 4×4, so the 4×4 deliverable's value rests on
that), or (b) sample only the BOUNDARY positions (DTT=1, DTT=3,
width=2-4) at 4×4, where the failure modes concentrate. **Do not**
spend the wall time on broad sampling.

- [x] H1 verdict: **supported** (LH 25.6% vs KO 65.5%; supports but does
      not rescue C2)
- [x] H2 verdict: **FALSIFIED** (max|diff|=12 at width=3, 10.3% of KO
      outside [L,H])
- [x] H3 verdict: **inconclusive** (root-queried; tail-queried would
      match T13's per-depth findings; needs a separate harness
      variant to settle)
- [x] H4 verdict: **falsified** (no monotonic DTT pattern)
- [x] 4×4 sampling recommendation: **do not** broadly sample 4×4;
      pick a higher-leverage follow-up (writes-off finisher, or
      boundary-position sampling only)

---

## Bundle-wide notes (final)

- No engine files were edited; the harness reuses T13's solver and
  Retro/Exact.
- No `data/oracle-*.wzo` or `artifacts/*.wzo` were written.
- All outputs are under `untracked/`.
- This bundle is independent of B02/B03/B04/B05/B06/B07/B08/B09.
- **The fresh-start single-value table is the sound deliverable**;
  neither the ko-sensitive values nor the real-game values are
  trustworthy. The bracket `[L,H]` is **not** a sound real-game
  bound; it's a fresh-start value bound.
