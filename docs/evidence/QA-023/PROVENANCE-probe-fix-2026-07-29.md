Task: 2B-PROBE-FIX · Role: worker · Model: DeepSeek-Pro (DSPro) · Date: 2026-07-29

# PROVENANCE — 2B-PROBE-FIX

## Build

```sh
tools/runner -- zig build-exe src/qa023_probe.zig -femit-bin=/tmp/probe-fixed -Doptimize=ReleaseFast
```

Target: `src/qa023_probe.zig` at HEAD + 2B-PROBE-FIX edits (set L, single writer).

## Runs

### Primary measurement
```sh
tools/runner -- /tmp/probe-fixed probe-3x2 --seed 0x2B4DA7A --n-samples 256 --k-histories 8 --history-depth 16 --node-budget 100000
```
Stdout: `docs/evidence/QA-023/probe-fix-2026-07-29.stdout`

### Defect reproduction (before fix)
```sh
tools/runner -- zig build-exe src/qa023_probe.zig -femit-bin=/tmp/probe-defect-repro -Doptimize=ReleaseFast
tools/runner -- /tmp/probe-defect-repro probe-3x2 --seed 0x2B4DA7A --n-samples 256 --k-histories 8 --history-depth 16
```
Result: 0 value-agreements, 679 TIE, 0/1133 budget-exhausted, 454 disagreements — matches evidence README.

### Depth sweep
```sh
for d in 4 8 12 16 20 24; do
  tools/runner -- /tmp/probe-fixed probe-3x2 --seed 0x2B4DA7A --n-samples 128 --k-histories 8 --history-depth $d --node-budget 100000
done
```
Results in probe-fix-2026-07-29.md §3 table.

## Edits to src/qa023_probe.zig

1. `truncated_value`: added `scratch_full: *bool` and `collision_count: *u64` params
2. `truncated_value`: σ-in-arrival collision detection (top-level only, `scratch_top.* == 0`)
3. Two call sites: `arrival_len` → `arrival_len - 1`, added `scratch_full`/`collision_count` vars
4. Null-handling: check `scratch_full` flag to distinguish budget vs scratch exhaustion
5. Scratch/arrival_buf sizing: `params.history_depth + 4` → `4096`
6. `ProbeOutcome`: added `n_scratch_overflow`, `n_c1_failures`, `n_c2_failures`, `n_c1_eligible`, `n_c2_eligible`, `sigma_in_arrival_collisions`
7. Per-sample C1/C2 tracking: `c1_first_val`, `c1_all_agree`, `c1_within_budget_count`
8. Verdict output: within-budget denominator, scratch overflow, C1/C2 split with 2B-3-AUDIT caveat
9. `--node-budget` flag in `probe-3x2` argument parsing
10. Progress output: added scratch overflow counter
11. Usage string updated
12. Disagreement dump limit: 5 → 100

## Rules not touched
`apply_place`, `apply_pass`, `moves` unchanged — the 2B-FIX-KO correction stands.
