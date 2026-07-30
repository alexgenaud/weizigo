<!--managent set=Q holds=src/qa023_probe.zig needs=2B-PROBE-FIX-->
# F1-SEEDROOTS — the census seeds 42 roots, not 4; three published numbers move

**Opened by:** the audit of 2B-2, finding **F1** — explicitly left open by `2B-FIX-KO` §7 as out of its scope, and never registered since.

## The defect

`seed_roots` in `src/qa023_probe.zig` seeds **42** states rather than the four true game roots (empty goban × side × passes). The extra 36 are **empty-goban-with-a-ko-point** states, which no legal game can reach: a ko point can only be created by a capture, and the empty goban has no stones. They are inside every published reachable count.

Measured (by 2B-FIX-KO, corrected ko rule, single true root): **V = 2,583, E = 5,510, real-ko states 24, cycle-involved 1,676, cycle-reachable 1,678** — versus the 2,622 / 5,668 / 60 / 1,676 / 1,704 currently published.

**The SCC is identical either way**, so no verdict changes; F1 trims a phantom tail. But it moves three published numbers, and it should land **before** the 2B-2 / 2B-3 / 2B-4 figures are re-issued rather than after, or the project will publish a third set.

## The task

1. **Fix `seed_roots`** to seed only genuinely reachable roots, and state the rule you used (a ko point requires a preceding capture; justify the reachability argument, don't just hardcode 4).
2. **Re-run** the census, the history-pair guard, and the fixpoint; report the corrected figures.
3. **Say explicitly whether any verdict moves.** The expectation is none — `B-VACUITY` PASS, same SCC. If something does move, that is the finding.
4. Check whether the same phantom-seed pattern exists in any other census in the tree (`src/reachcensus.zig`, `src/kostate_census.zig`, `src/ko_census.zig` are the candidates) — a one-line grep answer per file is enough, but **do check**: EXP-3's 4×4 census is load-bearing for the median build's tractability claim.

## Acceptance

- The fix, with the reachability argument for which roots are legitimate.
- Corrected V / E / SCC / cycle-involved / cycle-reachable / real-ko counts.
- An explicit "no verdict moves" (or the verdict that does).
- The other-census check.

## Deliverable

`docs/evidence/QA-023/f1-seedroots-<date>.md` + stdout + `PROVENANCE-*.md`, and superseded-numbers banners updated on the affected evidence docs. **Do not edit `CLAIMS.md`** — propose the number changes.

**Sequencing:** `needs 2B-PROBE-FIX` and holds the same file, so it lands after the probe fix; that ordering is deliberate — the probe defect is the higher-value fix and this one changes the same numbers.

**Build/run:** through `tools/runner`; never unfiltered `zig test src/qa023_probe.zig`.
