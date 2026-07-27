# Ko census — multi-ko frequency on 3×3 and 4×4

**Date:** 2026-07-26  **Source:** B23 (`untracked/B23-kocensus.md`)

## Results

| board | total-legal (slots) | ko-sensitive | 0-ko | 1-ko | 2-ko | 3-ko | 4-ko+ |
|---|---|---|---|---|---|---|---|
| 3×3 | 25,350 | 8,698 | 7,010 (80.6%) | 1,688 (19.4%) | 0 | 0 | 0 |
| 4×4 | 48,636,330 | 10,367,922 | 6,741,026 (65.0%) | 3,415,640 (32.9%) | 211,000 (2.0%) | 256 (0.0025%) | 0 |

## Key findings

1. **65% of ko-sensitive positions on 4×4 have zero basic ko shapes.** Their L<H
   gap comes from multi-stone capturing races or first-move advantage, not from
   basic ko recapture.

2. **2-ko appears in 2% of the 4×4 ko-sensitive region** (~211,000 positions).
   3-ko is vanishingly rare (256 positions, 0.0025%). No positions with 4+
   simultaneous independent kos.

3. **3×3 has no multi-ko positions at all.** All ko-sensitive positions are
   0-ko or 1-ko.

4. **Multi-ko handling would affect at most ~0.4% of all 4×4 positions**
   (2% of 21% ko-sensitive). Whether this is worth engineering depends on
   whether those 211,000 positions are commonly reached in play.

## Method

Standalone tool `src/ko_census.zig` — reads a `.wzo` artifact, scans all
ko-sensitive positions, counts independent ko points per position. A ko
point is a single-stone capture where the capturing stone could itself be
immediately recaptured under basic ko.
