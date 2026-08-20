# GLOBAL.REACH-P4-CENSUS — provenance

**Task:** T507 (deepseek-v4-pro/T507) · **Date:** 2026-08-20 · **Landmark:** `L7 (the 5×5 decision, costed)`.

## What was measured

The reachable-state census over the full state tuple `(board, side, ko, passes)` —
the same key the WZO2 artifacts store (`passes=2` omitted) — from the fresh-start
roots (empty board, both sides to move, `ko=none`, `passes=0`; the 3×2/3×3 wrappers
additionally seed the provably redundant `passes=1` roots). Four goban sizes: 2×2, 3×2,
3×3, 4×3. The 4×4 row is read from the committed artifact headers + the battery's
`accept.md`/`capture-budget` measurements (a fresh 4×4 census would need a
4.4-billion-slot dense bitset and was deliberately not re-paid — the census quantifies
that cost).

## Instruments (committed in `da60c87`)

- `src/t358_census_2x2.zig` — clean 2×2 BFS, seeds the two real roots only.
- `src/t358_census_3x2.zig` — wraps `exp6_solve.run_census_3x2`.
- `src/t358_census_3x3.zig` — wraps `exp6_solve.run_census_3x3`.
- `src/t358_census_4x3.zig` — independent 4×3 BFS over `exp6_solve` move primitives.

## Runs

`tools/runner -- zig run -O ReleaseFast src/t358_census_<size>.zig` (all four exit 0,
`ReleaseFast`, single thread, Apple-silicon host, 48 GB). Captured:

- `census-2x2.stdout` / `.stderr`
- `census-3x2.stdout` / `.stderr`
- `census-3x3.stdout` / `.stderr`
- `census-4x3.stdout` / `.stderr`

## Independent re-implementation

`crosscheck.py` — a from-scratch Python BFS over the same state tuple (no Zig imports),
stdlib only. It reproduces the 2×2 and 3×3 instruments exactly, and demonstrates the
two root-seeding conventions (`passes∈{0}` vs `passes∈{0,1}`) produce identical reachable
sets — i.e. the 3×2/3×3 wrappers' `passes∈{0,1}` seeding is a redundant over-seed, not a
wrong one. Output: `crosscheck.stdout`.

## Cross-checks against independent sources

| this census | independent source | agreement |
|---|---|---|
| 3×3 non-terminal 49,428 | `data/oracle-3x3-v2.wzo2` header `n_entries` | exact |
| 3×3 legal 12,675 | same header `n_groups` | exact |
| 4×3 total 1,929,038 | `docs/research/capture-budget-2026-08-06.md` §2 (t386 census) | exact |
| 4×4 non-terminal 99,133,036 | `data/oracle-4x4-v2.wzo2` header `n_entries` | exact |
| legal column 57/489/12,675/321,689/24,318,165 | `docs/research/scaling-census.md` (RETRO_CENSUS) | exact, all five |
| 2×2 / 3×2 totals | `crosscheck.py` re-implementation | exact |

## Known pre-existing discrepancy (not a defect of this census)

The I5 Tarjan-SCC instrument reports 4×3 `V = 1,929,035` (`accept.md` §3.1) vs this
census's 1,929,038 — a 3-state difference between the SCC instrument and the reachability
census. This census's headline is its exact agreement with t386's 1,929,038 and the WZO2
headers.
