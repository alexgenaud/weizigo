# D18 cross-check: BFS unsupported

**Date:** 2026-07-29 (evidence-integrity sweep). **Task:** EVIDENCE-INTEGRITY set N.

## What was needed

CLAIMS.md §6-D18 records that EXP-3's calibration 2 was disputed by its own
dispatch, and the cross-check that resolved it — an independent depth-parity
BFS — was written to `/tmp/test_census_pure.zig` and **deliberately not
committed** ("a sanity throwaway").

The BFS established that the dispatch's expected reachable counts (25,350 at
3×3, 643,378 at 4×3, 48,636,330 at 4×4) were the **total addressable**
`(position, side)` space, while the census walk counts **reachable from the
empty goban under alternating play** — two different denominators. The BFS
produced the reconciling number (3×3 has only 11,109 `(position, side)` pairs
reachable from `(empty, B-to-move)`), which explained the mismatch.

## Attempted re-derivation

The file `/tmp/test_census_pure.zig` **does not exist on disk** (checked
2026-07-29). It cannot be re-derived from any committed source, because it was
a throwaway written and deleted in the course of a single debugging session.

## Status

**The dismissal of the calibration mismatch is UNSUPPORTED.** The census
numbers themselves are PROVEN without the BFS — the alternative calibrations
(ko-disabled, broken-every-capture, broken-every-move known-bads) independently
validate the walk. What is unsupported is the **explanation** for why the
dispatch's expected figures were wrong: the "different denominators" argument
rests on a measurement that cannot be reproduced.

The D18 discrepancy and this note are cross-referenced from CLAIMS.md §6-D18
and the PROVENANCE.md in this directory.

## Recommendation

Whoever can still reproduce the BFS should commit it here. Until then, any
reader of `kostate-census-2026-07-28.md:104-144` or §6-D18 of CLAIMS.md
should treat the calibration-2 explanation as CLAIMED (plausible, not
reproducible), not as PROVEN.
