# C2 falsified at 3×2

**Date:** 2026-07-26  
**Source:** T13 C2-pilot-3×2 (`untracked/T13-minimax.md`)  
**Status:** PROVEN FALSE-AS-SCOPED

> **⚠ CANNOT REPRODUCE — the probe source is lost.** Added 2026-07-29 by the
> Orchestrator (Opus 5); `EVIDENCE-INTEGRITY` placed this banner on the
> `3x2.T13` register row, and it belongs here too, because this file — not the
> row — is what a reader reaches.
>
> The `Source:` line above points at `untracked/T13-minimax.md`, which is
> **gone**: `untracked/` is git-ignored and was swept. The numbers in this file
> are the durable record and the claim stands on them, but **the experiment
> cannot be re-executed** — the probe that produced the 12 mismatches no longer
> exists. If a future result contradicts T13, the project cannot settle it by
> re-running the original.
>
> This matters more than most lost evidence: T13 is the falsification the entire
> current strategy rests on. It is the origin of the `AGENTS.md` rule *evidence
> in git, or the claim is not proven*, which was adopted **after** this loss.
> See `CLAIMS.md` §7 and `docs/status/evidence-integrity-2026-07-29.md`.

## Claim

**C2:** the single-score (L==H) region of the retrograde table is
history-independent — i.e., for any legal position P with L(P,s)==H(P,s), the
score v(P,s) is the same under every reachable game history.

## Result

**C2 is false at 3×2.** The probe found 12 L==H positions whose score under a
reachable non-trivial PSK history differs from the stored fresh-start L==H
score.

## Method

Standalone probe `untracked/c2pilot_3x2.zig`:

1. Build the 3×2 L/H retrograde tables (`Retro(3,2).seed/converge/finalize`).
2. Identify all L==H slots: 540 slots (30 settled + 189 B ko-sensitive + 189 W
   ko-sensitive, 489 legal positions total).
3. Enumerate short PSK-legal placement-only game lines up to 10 ply starting
   from every legal start position, with a global line budget of 2,000,000
   nodes.
4. For each line ending at an L==H position (P, side), run the history-aware
   solver `retro.ab_solve` with:
   - `memo=false` — no memo reads/writes, eliminating GHI risk;
   - `brackets=false` — no history-free L/H cuts, so the solver returns the
     true score under the current history;
   - full alpha-beta window `[-127, 127]`;
   - an `O.History` pre-populated with every board of the line (including P
     as the most recent element, so basic ko and all PSK repeats are
     forbidden).
5. Compare the returned score with the stored L==H score.
6. Fresh-start sanity check: run the same solver with history seeded only
   with the root on every L==H slot.

Alpha-beta without memo and without brackets is exact: it evaluates the full
game tree up to alpha-beta pruning, which does not change the score.

## Measurements

| metric | value |
|---|---|
| Board | 3×2 |
| Legal positions | 489 |
| Settled positions | 30 |
| Ko-sensitive slots | 189 B / 189 W |
| L==H slots | 540 |
| Game lines examined | 153,613 |
| Non-trivial histories tested | 508 |
| History-aware mismatches | **12** |
| Fresh-start sanity mismatches | 0 |
| Budget-unreachable histories | 0 |
| Wall time | ~200 ms |

### Ban-set size distribution (positions in line, size 1 = fresh-start)

| size | count |
|---|---|
| 1 | 32 |
| 2 | 21 |
| 3 | 74 |
| 4 | 84 |
| 5 | 83 |
| 6 | 48 |
| 7 | 36 |
| 8 | 40 |
| 9 | 45 |
| 10 | 45 |

### Contradictions

```
idx=314 side=B depth=9 expected=+6 got=-6  history=0 2 26 40 110 278 57 154 314
idx=413 side=B depth=9 expected=+6 got=+1  history=0 2 26 40 110 278 57 211 413
idx=410 side=B depth=9 expected=+6 got=-6  history=0 4 15 32 102 244 45 122 410
idx=459 side=B depth=9 expected=+6 got=-6  history=0 4 15 32 102 244 45 147 459
idx=267 side=B depth=9 expected=+6 got=-6  history=0 4 22 60 159 327 37 107 267
idx=433 side=B depth=9 expected=+6 got=-6  history=0 4 22 60 159 327 37 205 433
idx=237 side=B depth=9 expected=+6 got=-6  history=0 6 62 48 127 423 29 99 237
idx=273 side=B depth=9 expected=+6 got=+1  history=0 6 62 48 127 423 29 141 273
idx=359 side=W depth=10 expected=-6 got=-1 history=1 19 77 325 105 253 477 64 167 359
idx=346 side=B depth=9 expected=+6 got=+1  history=2 16 84 112 260 500 61 162 346
idx=398 side=W depth=10 expected=+6 got=+1  history=2 16 84 112 260 500 61 162 346 398
idx=347 side=B depth=9 expected=+6 got=+1  history=4 24 172 128 263 567 25 91 347
```

Every mismatch is on a position whose stored L==H score is ±6. The
history-aware score is sometimes the sign-reversed score (−6 vs +6) and
sometimes an intermediate score (+1 or −1).

## Interpretation

The L==H fixpoint scores are correct as **fresh-start** scores (C1). The
fresh-start sanity check passed on all 540 L==H slots. But they are **not**
real-game scores: when the same position is reached after a non-trivial PSK
line, optimal play can produce a different score.

This falsifies the framing of the L==H region as history-independent and
provably correct for real games (the old "certified core" framing). The honest status of
the table is:

- **fresh-start correct** (C1, PROVEN at 2×2/3×2),
- **not history-independent** (C2, FALSE at 3×2),
- **the [L,H] bracket does not bound real-game scores** (C3, FALSE at 3×3 by E2).

## Consequences

1. The core-only deliverable collapses as a claim of real-game correctness.
2. The leak crisis (fresh-start player under-delivering in real games) is now
   explained structurally: the table scores are not real-game scores for either
   region.
3. The honest shippable, if any, is a fresh-start oracle plus an `[L,H]`
   bracket, both explicitly labelled as fresh-start scores / claimed bounds,
   not proven real-game scores.
4. C2-4×4 and all work predicated on a real-game core (T14.2, T14.3,
   T17-impl) are blocked pending a reframe.

## Reproduction

```
zig build-exe -O ReleaseSafe --dep retro -Mmain=untracked/c2pilot_3x2.zig -Mretro=src/retro.zig -femit-bin=/tmp/c2pilot_3x2
/tmp/c2pilot_3x2
```

## Files

- Probe: `untracked/c2pilot_3x2.zig`
- Task record: `untracked/T13-minimax.md`
- Durable finding: `docs/research/c2-falsification-3x2.md` (this file)
