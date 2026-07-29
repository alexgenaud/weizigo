Task: 2B-4 · Role: worker · Model: MiniMax-M3 · Date: 2026-07-29

# PROVENANCE — probe-3x2-2026-07-29

## Artifacts

| file | SHA-256 |
|---|---|
| `probe-3x2-2026-07-29.stdout` | `828bdb5bfcaac9acadc8f45be4d11297f8357a9292d9ac37f19f4c169235508b` |
| `probe-3x2-2026-07-29.md` | `49fb19997899693a81671296a2bc7203cbf86eac2110922db1d1e298c802eb68` |
| `src/qa023_probe.zig` | `91c3e21ecfae6ce1565c17879d6b7ae50999024406989553cfe68f11ecd716d5` |

## Build

```sh
tools/runner -- zig build-exe src/qa023_probe.zig -femit-bin=/tmp/qa023_probe_2B4
```

Zig 0.16.0, -O ReleaseFast (auto-added by runner). Peak RSS: 356 MB during
compilation, <2 MB at runtime.

## Commands

```sh
# Full probe run (headline numbers)
tools/runner -- /tmp/qa023_probe_2B4 probe-3x2 \
    --seed 0x2B4DA7A --n-samples 256 --k-histories 8 --history-depth 16

# Smoke (unchanged from 2B-1)
tools/runner -- /tmp/qa023_probe_2B4 smoke-2x2

# Calibration (unchanged)
tools/runner -- /tmp/qa023_probe_2B4 calibrate

# Fixpoint (unchanged)
tools/runner -- /tmp/qa023_probe_2B4 fixpoint-3x2
```

## Code change

`ProbeOutcome` extended with `n_value_agreements` and `n_tie_valued` to
report the three-way split (value / TIE / budget-exhausted per
reference-semantics §2). Per-disagreement dump for the first 5
disagreements: state (board, side, ko, passes), V_fixpoint, truncated value,
arrival move sequence.

## Dependencies

- 2B-0: `docs/evidence/QA-023/reference-semantics-2026-07-29.md` (adjudication rule)
- 2B-2: `docs/evidence/QA-023/census-3x2-2026-07-29.md` (cycle census + vacuity)
- 2B-3: `docs/evidence/QA-023/history-pairs-3x2-2026-07-29.md` (history-pair vacuity)
- 2B-1: `docs/infra/dispatch/2B-1.md` (smoke rewire, B1 fix)
