> # ⚠ SUPERSEDED NUMBERS — the verdict stands, the figures do not
>
> **Added 2026-07-29 by the Orchestrator (Opus 5).**
>
> Computed under the pre-`2B-FIX-KO` ko rule (audit finding F5: `apply_place`
> did not require the played stone to be a lone stone). Re-run under the
> corrected rule: **102/102** sampled multi-history states have visit-set-distinct
> arrival histories, **2,563/2,563** pairs distinct — the 93/93 below becomes
> 102/102. **VACUITY-GUARD PASS is unaffected.**
> Source: `ko-fix-rerun-2026-07-29.md` §4.2.
>
> **Not yet audited.** This generator had two bugs found and fixed by its own
> author, and it is an input to the probe; a defect in that fix would corrupt
> whatever `2B-PROBE-FIX` measures. Task: **`2B-3-AUDIT`**.

Task: 2B-3 · Role: worker · Model: DeepSeek-Pro · Date: 2026-07-29

# QA-023 Part B — history-pair generation at 3×2

**Status: CLAIMED** (run data below).  Promotes `3x2.QA023.B-VACUITY` to
**PROVEN** — the 3×2 goban is non-vacuous for history-sensitivity probing.

## 1. What was asked

Per `docs/infra/dispatch/2B-3.md` and `docs/infra/dispatch/EXP-2B.md`:
enumerate up to K distinct bounded arrival histories for each of N sampled
3×2 states.  Compare visit-sets pairwise.  If no state has ≥2 histories with
different visit-sets, the QA-023 probe cannot detect history-dependence
(the same trap that killed 2×2) — escalate.

## 2. What was done

Extended `src/qa023_probe.zig` with a new mode `history-pairs-3x2` that:

1. Builds the 3×2 reachable-state census (same `census_sweep` as the probe).
2. Runs the ADR-0009 two-fixpoint (L least, H greatest, same Bellman
   operator) over the full state-tuple reachable set.
3. Samples N states (biased 70% pin_T / 15% L==H / 7.5% each pin_L/pin_H).
4. For each sampled state, collects up to K distinct simple-path arrival
   histories via DFS (reuses `collect_histories`), with fixes:
   - Pass detection: `child.board == state.board` (not `child.passes !=
     state.passes` — the latter misidentifies place moves after a pass as
     passes, because a place move resets `passes` to 0, matching the
     parent's `passes=1` to `child.passes=0`).
   - Cell detection: finds the cell changing from empty→occupied (the
     placed stone), not the first differing cell (captures also differ,
     and can appear before the placed stone in iteration order).
5. Replays each move sequence via `visit_set_of_arrival` (same replay
   logic as `play_arrival`), collecting the sorted+deduplicated set of
   visited (board, side, ko, passes) linear indices.
6. Compares all history-pairs for each state; reports visit-set difference
   counts.

**Bug fixes to pre-existing code** (all in `collect_histories_dfs_impl`):
- **Pass detection** (line ~1330): replaced `child.passes != state.passes`
  with `child.board == state.board`.  A pass never changes the goban
  index; a place move always does.  The old heuristic fails when
  `state.passes == 1` and a place move resets passes to 0.
- **Placed-cell detection** (line ~1340): replaced "first differing cell"
  scan with a scan for the cell that changed from `0` (empty) to non-zero
  (occupied).  Captures change non-zero to `0`; the placed stone is the
  only `0 → non-zero` transition.

**Build:** `zig build-exe -O ReleaseFast src/qa023_probe.zig` under
`tools/runner`.  Peak RSS 348 MB during compilation, <2 MB at runtime.

**Reproduction:**
```
tools/runner -- zig build-exe -O ReleaseFast src/qa023_probe.zig -femit-bin=/tmp/qa023_probe_2B3
tools/runner -- /tmp/qa023_probe_2B3 history-pairs-3x2
```

## 3. Results

Run of 2026-07-29 (seed = 0x2B3DA7A, 3×2, basic ko, TIE = 0, `n_samples = 128`,
`k_histories = 8`, `history_depth = 16`):

| metric | count |
|---|---|
| states sampled | 128 |
| states with ≥2 histories | 93 (72.7%) |
| states with visit-set-different histories | **93** (100% of multi-history) |
| total history-pairs compared | 2275 |
| total visit-set-different pairs | **2275** (100%) |

**Supporting diagnostics** (from the same run):

- 3×2 reachable non-terminal states: pin_T = 1592, L==H = 82, pin_L = 142,
  pin_H = 0.  Total non-terminal reachable = 1816.
- Fixpoint converged in 2 sweeps (terminal seeding sufficient for 3×2).
- L==H states: 948; L<H&pin_T: 1592; L<H&pin_L: 142; L<H&pin_H: 0.
- 2×2 smoke: all five anchors pass (empty B = 0 ≠ PSK's +1; full B = +4).
- Calibration gadget: PASS (v2 median = 1, v1 L<H⇒T = 0 on the §5.3 graph).

## 4. Acceptance

**PASS** — the second vacuity guard is satisfied:

- **93 states** (all multi-history states) have ≥2 visit-set-distinct
  arrival histories.
- **Every one** of 2275 history-pairs has different visit-sets.
- The QA-023 history-sensitivity probe at 3×2 is **non-vacuous**: different
  histories to the same state carry genuinely different visit-sets, so any
  agreement in their truncated values carries evidential weight.

No escalate recommendation needed.

## 5. What could not be established

- Whether the visit-set differences are "meaningful" (i.e., whether the
  different visit-sets produce different truncated values) — that is the
  probe's job (2B-4 or the full `probe-3x2` run).
- Whether `pin_H = 0` is genuine or a bug in the fixpoint (unlikely: the
  operator is Black-max/White-min in both L and H; pin_H = L<H & T>H, which
  would mean H < T = 0 for Black-positive values, possible only with
  negative scores, which are reachable on 3×2 with area scoring).

## 6. What to check next

- Run `probe-3x2` with the fixed collector to produce the history-sensitivity
  check proper (2B-4).  The probe currently uses the same `collect_histories`
  function — it benefits from the fixes delivered here.
- Verify the #2 auditor on 3×2 exhaustive after this code change (the probe
  shares `apply_place`/`apply_pass`/`moves` with the engine — changes here
  do not touch those, but the passes-identification fix is in collector code
  only, not in rules).
