# PROVENANCE — EXP-8 PSK-divergence harness (set A)

**Task:** EXP-8 · **Agent:** kimi-k2.7 · **Date:** 2026-07-29  
**Model:** Kimi K2.7 · **Role:** worker  
**Claim IDs touched:** `QA-012`, `QA-024` (value half) — **not closed**, see blocker note in the research note.

## What this directory contains

| file | what it is |
|---|---|
| `run-2x2-oracle-rt-20260729.txt` | Frame A, 2×2, `oracle-rt` policy, 200 games, raw stdout |
| `run-2x2-random-20260729.txt` | Frame A, 2×2, `random` policy, 200 games, raw stdout |
| `run-2x2-mixed-20260729.txt` | Frame A, 2×2, `mixed` policy, 100 games, raw stdout |
| `run-3x2-random-20260729.txt` | Frame A, 3×2, `random` policy, 20 games, max-empties 1, raw stdout |
| `calibrate-bad-2x2-vb0.txt` | Known-bad calibration: 2×2 `random`, 10 games, `vb[0]` perturbed from +1 → 0 |
| `SHA256SUMS` | SHA-256 of the artifacts read by the runs |

The harness source itself is at `src/psk_divergence.zig` (this task owns it).

## Build command

```sh
tools/runner -- zig build-exe -Mmain=src/psk_divergence.zig \
  -femit-bin=/tmp/weizigo-psk-divergence
# EVIDENCE LOST (path was /tmp, destroyed before rescue on 2026-08-08) — the probe binary above is gone
```

All builds run under the B-2 RSS runner (`tools/runner`) per `AGENTS.md` and
`docs/infra/runner.md`.  Peak compile RSS was ~388 MB; runtime RSS stayed
under the 4 GB cap.

## Artifact hashes

```
1ed06e648561995005a16489dcf6c4205c5aa11f427da81cceca40d3cab62abf  artifacts/oracle-2x2.wzo
d4d22c0d9f1d771bfcb1d99fc43a4f19f652205113ff599123b189097b3bb523  artifacts/oracle-3x2.wzo
c1f8fe5edac9a42710f57056c87e80b66b5bae5a8af610ba2b256af1e2805685  artifacts/oracle-3x3.wzo
a2174fedd6a0591dc66b0b42ef1f52bdc28b97c448dbc5b043d96de3a3b1e118  data/oracle-4x4.checkpoint.wzo
```

## Exact PSK reference used

The harness uses `retro.Retro(w,h).O.solve` with:

- `memo = false` (no cross-history memo reuse),
- `brackets = false` (no history-free L/H cuts),
- the actual game history pre-populated in `O.History`.

This is the same history-exact discipline as the 3×2 C2 falsification probe
(`docs/research/c2-falsification-3x2.md`).  It is **not** `retro.Exact` fresh-start
root solving; fresh-start exact PSK on non-terminal small gobans exceeded the
available 4 GB RSS cap even at 2×2/1-empty (see research note).

## Calibration

- **Known-bad (synthetic):** perturb `vb[0]` (empty goban, Black to move) from
  the known PSK value +1 to 0.  The harness reports increased value divergence,
  confirming it detects table-vs-PSK mismatches.
- **Known-good:** a fresh-start exact-PSK known-good run on L==H slots could not
  be completed within the runner's 4 GB RSS cap for any non-terminal sampled
  position.  This is itself the central intractability result and is discussed
  in the research note.

## Limitation / blocker

The delivered runs compare the **existing PSK tables** against history-exact
PSK, not a new-rule table against PSK.  New-rule (basic-ko + long-cycle tie)
tables do not yet exist on disk — EXP-4/5/6 are blocked.  The research note
states what would need to be re-run once those tables are available.

No files in `data/` or `artifacts/` were written.
