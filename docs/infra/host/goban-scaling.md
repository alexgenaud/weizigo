# Goban scaling — measured resource cost per board size

**Ledger:** `docs/infra/host/goban-scaling.jsonl` (append-only, one row per solve).
**Capture:** `tools/goban-scaling-capture.sh <rows> <cols> <regime> <task> -- <command>`.

Every row is **measured**. A field that could not be read is `null`, never estimated — the
claims register carries 85 PROSE-ONLY rows because guesses were written down as facts.

## Why this exists

Asked on 2026-08-25 how RAM, cores, time and disk scale from 2×2 through 5×5, the honest
answer was: **state counts and disk scale predictably and are known; time and solve-RAM have
never been recorded anywhere.** This ledger closes that gap by capturing the cost of each
solve as it happens, so the next answer is measured rather than interpolated.

## Known before this ledger (not from it)

Legal-position counts, `src/enumerate.zig:207` (Tromp A094777); 3×2 re-measured by T912.

| board | points | legal positions | artifact | bytes/position |
|---|---|---|---|---|
| 2×2 | 4 | 57 | ~0 | — |
| 3×2 | 6 | 489 | ~0 | — |
| 3×3 | 9 | 12,675 | 0.11 MB | 9.1 |
| 4×3 | 12 | 321,689 | 3.04 MB | 9.9 |
| 4×4 | 16 | 24,318,165 | not on disk | — |
| 5×5 | 25 | 414,295,148,741 | — | — |

**Disk is the one axis that already extrapolates well** — ~10 bytes/position holds across a 25×
jump. That projects 4×4 ≈ 240 MB and **5×5 ≈ 4.1 TB, which does not fit this machine's 1.6 TB
free**. 5×5 is a storage refusal before it is a compute problem. 5×4 is not in the square-only
table; ~2.95×/point interpolation gives ~1.9 × 10⁹ positions ≈ 19 GB — **an estimate, and
labelled as one until a row here replaces it.**

**Solve RAM, one real data point:** T912 measured the history-exact solver at 3×2 — 74 bytes/node,
**0.541 new states per node, flat across five doublings with no plateau** (the memo barely reuses,
because nearly every path is a distinct ban set). Extrapolating 400 M nodes gave ~29.6 GB.

**Cores: 18 (6P + 12E), and the retrograde solve is single-threaded.** Threading exists in
`arena.zig`, `differential.zig`, `exp6_solve.zig` — harness and differential tooling, not the
solve. Any wall recorded here is a one-core wall until that changes.

**Build cost is separate and must not be confused with solve cost** (T921, this host):
cold Debug `zig build test` peaks **11,237 MB**, warm **1,821 MB**. A build can land on the same
host as a solve, and the admission arbiter does not track builds.

## Regimes

Record which one produced the row — they are not comparable:

- `writes-off` — no search results written to the transposition table; the regime T912 vindicated
  and the one `4x4.D3` asks about.
- `memo-reuse` — cross-branch reuse; **known unsound under superko** (differs from writes-off on
  170 of 378 ko-sensitive 3×2 pairs).
- `deps-guarded` — Kishimoto–Müller dependency fingerprints (Track B).
- `history-exact` — ground truth; completes on only 68 of 600 roots at 3×2.

## Reading the ledger

    python3 -c "import json;[print(json.loads(l)) for l in open('docs/infra/host/goban-scaling.jsonl')]"

Compare only within a regime, and state the core count and whether the solve was threaded.
