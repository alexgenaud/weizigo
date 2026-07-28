# How often does positional superko actually forbid a move that basic ko allows? — EXP-1

**Date:** 2026-07-28. **Boards:** 4×4, 4×3, 3×3, each measured independently.
**Task:** EXP-1 of `docs/epistemic/roadmap-2026-07-28.md` §3; the claim under test
is **QA-024**.
**Tool:** `bin/weizigo-reachcensus --psk-binding` (new flag; source
`src/reachcensus.zig`, build target `weizigo-reachcensus`).
**Every claim is tagged. Every number cites its command, artifact and seed.**

## The question, and why it is decision-relevant

Positional superko (PSK) — "no whole-board position may ever recur" — is a
*computer* convention. Japan and Korea play basic ko and give **no result** for
long cycles; China adjudicates rather than mechanically enforcing; the AlphaGo
matches were Chinese rules, not PSK (`docs/research/ruleset-options.md:9-20`,
`docs/epistemic/roadmap-2026-07-28.md` §1). The project has spent months on
PSK's intractability (ADR-0013; 118M ban-set states on the empty 2×2).

So the prior question is not *can PSK be solved* but **does PSK ever actually
bind?** — how often does it forbid a move that basic ko would allow, and when it
does, is the repetition one a human player or judge would recognise?

This note measures that. It does **not** recommend a ruleset. Whether PSK stays
the target is the user's and Opus's call; this is the rate, and it is reported
without preference for either answer.

## Definitional choices — these are choices, state them

The measurement is only as meaningful as its definitions, and several are
judgement calls. All of them are implemented exactly as written here
(`src/reachcensus.zig`, `scanNode` / `matchPly` / `repForbidden`).

1. **History is indexed by ply.** Ply 0 is the empty board. A pass re-records
   the unchanged board at the next ply index, so `bply[k]` is always "the board
   after k plies". (The legality history the players use, `hist`, only grows on
   stone placements; the two describe the same *set* of boards, so legality is
   unaffected — the ply index exists only so distances are in plies.)
2. **A candidate move at a node where `k` plies have been played** produces a
   child board that would sit at ply index `k+1`.
3. **Distance `d` = `(k+1) − j`**, where `j` is the **most recent** ply index
   whose board equals the child. Most-recent is chosen deliberately: it
   *minimises* `d`, so it moves events out of the long-range bucket and into the
   short one. The headline "silent long-range" count is therefore a **lower
   bound** under this convention. `d = 1` is impossible (a move always changes
   the board), so `d ≥ 2` always.
4. **Basic ko** = forbid exactly the recreation of the position one ply ago,
   i.e. exactly `d == 2`. (This is the definition the task specifies. It is
   *positional* one-ply repetition, not the "ko point" formulation; on these
   boards the two coincide for the recapture case.)
5. **PSK** = forbid any `d ≥ 2`.
6. **PSK-BINDING** = PSK-illegal **and** `d ≥ 3`: legal under basic ko, illegal
   under PSK. Buckets:
   - `d == 2` — **ko-cycle repeat.** Basic ko already forbids it. *Not binding.*
   - `3 ≤ d ≤ 6` — **short-cycle repeat.** Double/triple-ko territory; still
     visible at the board.
   - `d > 6` — **silent long-range repeat.** The category that matters.
7. **"Not part of a recognisable cycle"** has no clean formal definition, so the
   tool reports an explicit **proxy** rather than pretending to one: a `d > 6`
   event is **ISOLATED** when no `d ≤ 6` repeat was available at the same node
   *or* at any node in the previous 6 plies of the same game. This is a
   heuristic. It is reported alongside the raw `d > 6` count, never instead of
   it, and no claim below depends on it.

### Two populations, because they answer different questions

- **(A) All candidates.** Every rules-legal (occupancy/suicide) move at every
  decision node, whether or not the policy would pick it. *"How much of the move
  space does PSK remove?"*
- **(B) The chosen move.** A **one-ply counterfactual**: at the same node, the
  same policy is re-run with **basic-ko legality only**, and we ask whether the
  move it then picks is PSK-illegal. *"Does PSK actually change what gets
  played?"* This is one ply deep — it is **not** a full basic-ko playout, and no
  claim here is about how a basic-ko game would have continued.

The counterfactual draws from a **separate random stream** and the real game
always continues under real PSK, so `--psk-binding` cannot perturb a single
played move. **Verified:** the 3×3 run with and without the flag is
byte-identical on every pre-existing statistic
(`bin/weizigo-reachcensus artifacts/oracle-3x3.wzo --games 2000` vs the same
with `--psk-binding`, diffed after stripping the new section).

### Denominator

Rates are **per 1,000 plies played, over all games** (`plies played (all
games)`). Legality reads no artifact slot, so — unlike the ko-sensitivity
statistics in `reachable-kosensitivity-2026-07-28.md` — no game is excluded for
touching an UNDEF slot. A secondary per-1,000-candidates rate is also printed.

**Built-in invariant, checked in every run reported below:** `rules-legal
candidates − basic-ko-legal candidates` must equal the `d == 2` count. It does,
exactly, in all 24 policy runs (e.g. 4×4 random: 522,867 − 521,944 = 923 = the
`d==2` tally).

## Verification before any number was believed

### Check 1 — hand-verified 14-ply deterministic line (PASSED)

`bin/weizigo-reachcensus data/oracle-4x4.checkpoint.wzo --games 1 --policy oracle --psk-binding --trace 1`

```
trace game 0: BB3* WC2* BC3* WB2* BA2* WA3* BA4* WD3* BB1* WC4* BC1* WD2* Bpass* Wpass*   [two passes]
  rules-legal candidates:   132   (basic-ko-legal 132)
  PSK-repeat candidates:    0   = d==2 0 | d 3-6 0 | d>6 0   (max d = 0)
```

The tool reports **zero** whole-board repeats available at any of the 14
decision nodes. Hand trace confirming it (Black-positive convention is
irrelevant here — no score is read):

- The 12 stone placements are on 12 **distinct** cells (B3, C2, C3, B2, A2, A3,
  A4, D3, B1, C4, C1, D2), so a repeat can only arise via a capture.
- **Exactly one capture occurs in the whole game: ply 7, `B A4`.** At that point
  White `A3` (played ply 6) is a one-stone group whose only liberties are A4,
  A2 (Black, ply 5) and B3 (Black, ply 1) — so A4 fills its last liberty and A3
  is removed.
- Every other move is non-capturing, so the stone count is
  0,1,2,3,4,5,6,**6**,7,8,9,10,11,11,11 after plies 0…14 (the two trailing
  passes leave it at 11). A repeat requires equal stone counts.
- Node-by-node: plies 1–6 have no group in atari for the side to move, so every
  child has a strictly new (larger) stone count — no earlier board can match.
  At ply 7 the only capturing move is `B A4`; its child has 6 stones, the only
  earlier 6-stone board is the ply-6 board `{B3,C3,A2 | C2,B2,A3}`, and the
  child is `{B3,C3,A2,A4 | C2,B2}` — different. At ply 8 the one move that could
  recreate the ply-6 board, `W A3`, is **suicide** (its neighbours A4, A2, B3
  are all Black and it captures nothing) and so is not even a rules-legal
  candidate. At plies 9–14 no group of the opponent has fewer than two
  liberties, so no capturing move exists and every child again has a strictly
  new stone count.

**PASSED.** The zero is correct and explicable, not a silent instrument failure.

### Check 2 — the two saved regression games (PASSED)

`docs/research/ko-sensitive-chainability.md` Measurement 2 documents **exactly
one PSK ban per game, at ply 14**, for both saved 4×4 regression games. A
`--replay` mode was added that replays a fixed GTP transcript and prints every
PSK ban with its distance (no policy, no randomness, no artifact slot read).

```
bin/weizigo-reachcensus data/oracle-4x4.checkpoint.wzo \
  --replay regressions/4x4-history-blunder.gtp \
  --replay <scratch>/4x4-black-win-after-ko.gtp
```

```
== replay: regressions/4x4-history-blunder.gtp (4x4) ==
  ply 14 (W to move): 1 PSK ban(s): D3 d=2 [ko-cycle, basic ko forbids it too]
  TOTAL over 21 plies: 1 PSK ban(s) at 1 ply/plies -- d==2 1 | d 3-6 0 | d>6 0
  PSK-BINDING (basic-ko-legal but PSK-illegal): 0

== replay: <scratch>/4x4-black-win-after-ko.gtp (4x4) ==
  ply 14 (W to move): 1 PSK ban(s): A3 d=2 [ko-cycle, basic ko forbids it too]
  TOTAL over 21 plies: 1 PSK ban(s) at 1 ply/plies -- d==2 1 | d 3-6 0 | d>6 0
  PSK-BINDING (basic-ko-legal but PSK-illegal): 0
```

**PASSED — agreement is exact:** one ban, ply 14, both games. Two further
consistency facts fall out: the banned vertex is `D3` in one game and `A3` in
the other, which is the vertical mirror `c ↦ 3−c` documented in
`regressions/README.md`; and the ban is at **`d = 2`**, i.e. it is an ordinary
ko recapture that **basic ko forbids as well**. So in the project's only two
recorded human-vs-engine games, PSK bound beyond basic ko **zero** times.

(`4x4-history-blunder.gtp` is committed. The second game exists only as a
`genmove` log, `regressions/4x4-black-win-after-ko.txt`; its 19 moves were
transcribed into a scratch `.gtp` — B B3, W C2, B B2, W C3, B C1, W B4, B B1,
W C4, B A4, W A3, B A2, W D2, B A4, W D1, B D3, W D4, B D3, W B4, B C4 — and
the transcription is corroborated by the exact mirror relation above. No file
was added to `regressions/`.)

## Runs

All 2026-07-28, `zig build -Doptimize=ReleaseFast`, **2,000 games per policy**,
**master seed 20260728** (each policy gets a fixed derived offset so adding or
removing a policy cannot perturb another's numbers), ply cap 256, random pass
probability 50/1000, settled-stop **on**.

```
bin/weizigo-reachcensus data/oracle-4x4.checkpoint.wzo --games 2000 --psk-binding
bin/weizigo-reachcensus artifacts/oracle-4x3.wzo       --games 2000 --psk-binding
bin/weizigo-reachcensus artifacts/oracle-3x3.wzo       --games 2000 --psk-binding
```

Artifact SHA-256 (first 16): `data/oracle-4x4.checkpoint.wzo` `a2174fedd6a0591d`;
`artifacts/oracle-4x3.wzo` `5316f428ad821c79`; `artifacts/oracle-3x3.wzo`
`c1f8fe5edac9a427`. Repository at `753584f`.

Policies are those already in the tool (`oracle` = both sides the engine rule,
deterministic; `oracle-rt` = same with random tie-breaks; `random` = uniform over
PSK-legal moves with 5% pass; `mixed` = engine vs random, colours alternating by
game index). See `docs/research/reachable-kosensitivity-2026-07-28.md` for their
definitions and for the move-for-move validation of the `oracle` mirror against
the real GTP player.

### (A) All candidates — rate per 1,000 plies

**PROVEN** for each board separately (these artifacts, this seed, these
policies, 2026-07-28). Counts are raw event counts; rates are per 1,000 plies.

#### 4×4 — `data/oracle-4x4.checkpoint.wzo`

| policy | plies | candidates | `d==2` | `d` 3–6 | `d>6` | **binding /1k plies** | **silent (`d>6`) /1k plies** | games with ≥1 silent |
|---|---|---|---|---|---|---|---|---|
| `oracle`    | 28,000 | 264,000 | 0 | 0 | 0 | **0** | **0** | 0/2000 |
| `oracle-rt` | 27,865 | 261,660 | 0 | 0 | 0 | **0** | **0** | 0/2000 |
| `random`    | 85,200 | 522,867 | 923 | 85 | 28 | **1.326** | **0.329** | 26/2000 (1.300%) |
| `mixed`     | 44,504 | 341,172 | 619 | 42 | 1 | **0.966** | **0.022** | 1/2000 (0.050%) |

#### 4×3 — `artifacts/oracle-4x3.wzo`

| policy | plies | candidates | `d==2` | `d` 3–6 | `d>6` | **binding /1k plies** | **silent /1k plies** | games with ≥1 silent |
|---|---|---|---|---|---|---|---|---|
| `oracle`    | 22,000 | 154,000 | 0 | 0 | 0 | **0** | **0** | 0/2000 |
| `oracle-rt` | 22,000 | 153,142 | 0 | 0 | 0 | **0** | **0** | 0/2000 |
| `random`    | 58,645 | 284,872 | 665 | 81 | 83 | **2.797** | **1.415** | 71/2000 (3.550%) |
| `mixed`     | 29,362 | 187,027 | 594 | 46 | 2 | **1.635** | **0.068** | 2/2000 (0.100%) |

#### 3×3 — `artifacts/oracle-3x3.wzo`

| policy | plies | candidates | `d==2` | `d` 3–6 | `d>6` | **binding /1k plies** | **silent /1k plies** | games with ≥1 silent |
|---|---|---|---|---|---|---|---|---|
| `oracle`    | 14,000 | 88,000  | 0 | 0 | 0 | **0** | **0** | 0/2000 |
| `oracle-rt` | 16,306 | 94,274  | 0 | 0 | 0 | **0** | **0** | 0/2000 |
| `random`    | 40,407 | 157,370 | 511 | 124 | 220 | **8.513** | **5.445** | 166/2000 (8.300%) |
| `mixed`     | 21,933 | 106,077 | 404 | 40 | 39 | **3.602** | **1.778** | 39/2000 (1.950%) |

Isolated share of the `d>6` events (the cycle proxy, §Definitions item 7):
4×4 random 26/28, 4×4 mixed 1/1; 4×3 random 77/83, 4×3 mixed 0/2; 3×3 random
201/220, 3×3 mixed 18/39.

Share of **all** PSK bans that are plain `d == 2` ko recaptures — i.e. the share
basic ko already handles: 4×4 89.1% (random) / 93.5% (mixed); 4×3 80.2% / 92.5%;
3×3 59.8% / 83.6%.

### (B) The chosen move — did PSK change what got played?

One-ply counterfactual, separate RNG. A `d == 2` event can never appear here
because the counterfactual itself enforces basic ko.

| board | policy | counterfactual nodes | chosen move PSK-illegal | of which `d` 3–6 / `d>6` | **rate /1k plies** | games where PSK changed ≥1 played move |
|---|---|---|---|---|---|---|
| 4×4 | `oracle`    | 28,000 | 0   | 0 / 0 | **0** | 0/2000 (0.000%) |
| 4×4 | `oracle-rt` | 27,865 | 0   | 0 / 0 | **0** | 0/2000 (0.000%) |
| 4×4 | `random`    | 85,200 | 39  | 27 / 12 | **0.458** | 36/2000 (1.800%) |
| 4×4 | `mixed`     | 44,504 | 14  | 13 / 1  | **0.315** | 14/2000 (0.700%) |
| 4×3 | `oracle`    | 22,000 | 0   | 0 / 0 | **0** | 0/2000 (0.000%) |
| 4×3 | `oracle-rt` | 22,000 | 0   | 0 / 0 | **0** | 0/2000 (0.000%) |
| 4×3 | `random`    | 58,645 | 68  | 32 / 36 | **1.160** | 62/2000 (3.100%) |
| 4×3 | `mixed`     | 29,362 | 20  | 19 / 1  | **0.681** | 19/2000 (0.950%) |
| 3×3 | `oracle`    | 14,000 | 0   | 0 / 0 | **0** | 0/2000 (0.000%) |
| 3×3 | `oracle-rt` | 16,306 | 0   | 0 / 0 | **0** | 0/2000 (0.000%) |
| 3×3 | `random`    | 40,407 | 137 | 48 / 89 | **3.391** | 123/2000 (6.150%) |
| 3×3 | `mixed`     | 21,933 | 41  | 20 / 21 | **1.869** | 41/2000 (2.050%) |

### Repeat-distance shape

The `d == 2` spike dominates everywhere. Beyond it the distances are **bimodal**:
a `d = 3` cluster (the other half of a double-ko-ish exchange) and then, for
`random` play only, a broad tail at `d ≈ 11–40+`. 4×4 random, candidate-level:
`d=2` 923, `d=3` 60, `d=4` 11, `d=5` 9, `d=6` 5, `d=7` 3, `d=9` 1, then singles
and pairs at `d = 21,22,23,27,28,29,30,32,35,36,37` and 4 events at `d ≥ 40`
(max observed `d = 97`). 3×3 random: `d=2` 511, `d=3` 105, small counts at 4–10,
then a large tail 11–40+ (max `d = 56`). 4×4 `mixed`: `d=2` 619, `d=3` 39,
`d=5` 3, and a **single** event at `d = 30`.

There is no middle ground: a repeat is either an immediate recapture, or it is
tens of plies away. **CLAIMED (these runs):** the mechanism is that only mass
capture can undo enough stones to revisit an old board, and on these boards mass
capture happens only after the board has filled and been wiped — which random
play does repeatedly and the engine does never.

### What a silent long-range repeat actually looks like

From `bin/weizigo-reachcensus artifacts/oracle-3x3.wzo --games 40 --policy random --psk-binding --trace 40`,
game index 1 (39 plies, 3×3, random both sides):

```
BA1 WC1 BA3 WC2 BB2 WB1 BC3 WB1 BB3 WC1 BC2 WB1 BA2 WC1 BC3 WC2 BB2 WA3
BB3 WA1 BA2 WC1 BA3 Wpass BC2 WB1 BA1 WC1{B1:d=15} BB1 WC1 BB2{A1:d=29} WC2 ...
```

At ply 28 (White to move) the move `B1` would recreate the whole-board position
of **ply 13**, fifteen plies earlier. At ply 31 (Black to move) the move `A1`
would recreate the position of **ply 2** — **twenty-nine plies earlier**. Both
are isolated by the §7 proxy. **These are exactly the events no human player or
judge would notice.** They are also embedded in a game where a 9-point board has
been captured out and refilled repeatedly — a position where Japanese/Korean
practice would already have declared *no result* and Chinese practice would have
adjudicated (`ruleset-options.md:9-20`). **Flagged as judgement, not
measurement.**

## Robustness

### Settled-stop truncation — the one that matters

`reachcensus` stops at `R.is_settled`, a truncation the real GTP player does not
perform. Silent repeats are a **late-game** phenomenon, so unlike the
ko-sensitivity fraction (which the truncation biases *up*) this truncation biases
the binding rate **down**. Measured
(`--games 2000 --psk-binding --no-settled-stop --ply-cap 1024`, same master seed):

| board | policy | mean plies (on → off) | binding /1k (on → off) | silent /1k (on → off) | games with ≥1 silent (on → off) |
|---|---|---|---|---|---|
| 4×4 | `oracle`    | 14.00 → 14.00   | 0 → **0** | 0 → **0** | 0 → **0**/2000 |
| 4×4 | `oracle-rt` | 13.93 → 13.93   | 0 → **0** | 0 → **0** | 0 → **0**/2000 |
| 4×4 | `random`    | 42.60 → 115.40  | 1.326 → **4.394** | 0.329 → **3.518** | 1.30% → **25.25%** |
| 4×4 | `mixed`     | 22.25 → 25.35   | 0.966 → **0.651** | 0.022 → **0.039** | 0.05% → **0.10%** |
| 4×3 | `oracle`    | 11.00 → 11.00   | 0 → **0** | 0 → **0** | 0 → **0**/2000 |
| 4×3 | `oracle-rt` | 11.00 → 11.00   | 0 → **0** | 0 → **0** | 0 → **0**/2000 |
| 4×3 | `random`    | 29.32 → 98.44   | 2.797 → **12.059** | 1.415 → **10.692** | 3.55% → **42.65%** |
| 4×3 | `mixed`     | 14.68 → 17.82   | 1.635 → **1.431** | 0.068 → **0.028** | 0.10% → **0.05%** |
| 3×3 | `oracle`    | 7.00 → 9.00     | 0 → **0** | 0 → **0** | 0 → **0**/2000 |
| 3×3 | `oracle-rt` | 8.15 → 13.72    | 0 → **0** | 0 → **0** | 0 → **0**/2000 |
| 3×3 | `random`    | 20.20 → 75.71   | 8.513 → **35.310** | 5.445 → **32.847** | 8.30% → **61.05%** |
| 3×3 | `mixed`     | 10.97 → 14.02   | 3.602 → **2.817** | 1.778 → **1.105** | 1.95% → **1.55%** |

**This is the most important robustness result in the note, and it cuts both
ways.** Removing the truncation multiplies the `random` silent rate by 7–11×
(4×4: 0.329 → 3.518 per 1k plies; 3×3: 5.445 → 32.847). But it does so by
letting random games run to a mean of **75–115 plies on boards of 9–16 points** —
a regime in which the board is captured out and refilled many times over. It
changes the two engine-driven policies almost not at all (`oracle`/`oracle-rt`
stay at exactly **zero**; `mixed` moves by ≤0.7 pp on the games-with-silent
figure and the 4×4 `mixed` silent count goes from 1 event to 2). **The
divergence between "policies that try to finish the game" and "policies that do
not" is the whole finding**, and it is robust to the truncation choice.

### Seed robustness (settled-stop on, 2,000 games/policy)

| board | policy | seed 20260728 | seed 1 | seed 999331 |
|---|---|---|---|---|
| 4×4 | `random` binding / silent | 1.326 / 0.329 | 1.331 / 0.312 | 1.324 / 0.274 |
| 4×4 | `mixed` binding / silent  | 0.966 / 0.022 | 0.895 / 0.000 | 0.703 / 0.000 |
| 3×3 | `random` binding / silent | 8.513 / 5.445 | 7.830 / 4.894 | 8.270 / 5.295 |
| 3×3 | `mixed` binding / silent  | 3.602 / 1.778 | 3.289 / 1.690 | 3.776 / 1.638 |

`oracle` and `oracle-rt` are 0 at every seed and every board. The `random`
figures are stable to ≲8% relative. The 4×4 `mixed` silent figure is 0–1 events
in 2,000 games and is **not** a stable estimate — read it as "at most about one
event per 44,000 plies", not as 0.022.

### Ply cap and UNDEF

Zero cap hits in every `--psk-binding` run reported here except 4×4 `random`
with the default cap 256 (1 game of 2,000, 0.05%); the `--ply-cap 1024`
re-runs above hit the cap zero times. UNDEF is irrelevant to this measurement —
legality reads no artifact slot — so no game is excluded and all statistics use
2,000/2,000 games.

## The answer

> **Does PSK bind beyond basic ko in real play, and if so, is it in ways a human
> would notice?**
>
> **In engine self-play on all three boards measured, no — not once, in 130,171
> plies and 1,015,076 candidate moves: PSK forbade nothing that basic ko allowed,
> and forbade nothing at all. In the project's two recorded human-vs-engine
> games, PSK bound zero times (its single ban per game is an ordinary `d = 2` ko
> recapture that basic ko forbids too). Against a uniformly random opponent it
> does bind — 1.3 (4×4) to 8.5 (3×3) times per 1,000 plies, of which 0.3 (4×4) to
> 5.4 (3×3) per 1,000 plies are silent long-range repeats no human would notice —
> but essentially all of those occur in games where the small board has already
> been captured out and refilled, exactly the regime a human judge would have
> ruled *no result* long before.**

Restated against **QA-024** ("PSK binds beyond basic ko at a negligible rate in
real play, for repeats that are not ko cycles"):

- **CONSISTENT WITH QA-024, and at the strongest possible value (exactly zero),
  for the engine's own play**: `oracle` and `oracle-rt` at 4×4, 4×3 and 3×3,
  under both settled-stop settings, with the 4×4 line additionally hand-verified.
  **PROVEN for those policies on those artifacts.**
- **CONSISTENT WITH QA-024 for the two recorded human-vs-engine games.**
  **PROVEN** (exhaustive over both games' 19 plies).
- **NOT established for arbitrary play.** Random self-play falsifies "negligible"
  as an unconditional statement: 220 silent long-range events in 40,407 plies at
  3×3, rising to 4,974 in 151,429 plies when the settled-stop is removed.
  Whether random play counts as "real play" is a judgement; it plainly is not
  competent play, and the engine-driven policies are the ones that resemble a
  game being played to a finish. **QA-024 should be re-scoped to state the
  policy class it holds over rather than left as an unqualified claim.**

The mechanism behind the split is visible in the data and is worth stating
because it is the thing that would or would not survive to a larger board:
**a whole-board repeat requires undoing stones, which requires mass capture.**
Play that is trying to finish the game captures once or twice and then fills;
play that is not recycles the board indefinitely. The 4×4 `oracle` line contains
exactly **one** capture in 14 plies and therefore cannot repeat anything.

## Caveats — all load-bearing

- **This measures these policies on these boards with these artifacts.** There
  is no claim about any other opponent distribution, and in particular none
  about strong human play beyond the two recorded games — which is two games.
- **Per-board independence (AGENTS.md).** 4×4, 4×3 and 3×3 are three separate
  results. Note that they do **not** even move in the same direction as size:
  the silent rate under `random` is 0.329 (4×4), 1.415 (4×3), 5.445 (3×3) per
  1,000 plies — *smaller* boards bind *more*. Nothing here licenses a statement
  about 5×5 or 19×19, in either direction, and no monotonicity argument is
  offered.
- **OPEN QUESTION, explicitly not answered here.** On larger boards, games are
  longer (more plies, more chances for a repeat) but also have more points, more
  stones, and far more ways for the position to diverge irreversibly. Those two
  effects push opposite ways and this measurement cannot distinguish them. The
  observed *smaller-board-binds-more* ordering is a hint in the second
  direction and nothing more; the honest position is that the larger-board rate
  is unmeasured.
- **The counterfactual in (B) is one ply deep.** It answers "would PSK have
  forbidden the move this policy picks *here*", not "how would a basic-ko game
  have gone". A full basic-ko playout comparison is a different experiment.
- **The `d > 6` "isolated" flag is a proxy**, not a definition of "cycle" (§7).
  Every conclusion above is stated in terms of the raw `d > 6` count; the
  isolated count is context.
- **The most-recent-match distance convention under-counts long-range events**
  (§3). The silent-repeat rates are lower bounds under that convention.
- **`oracle` is one line per board.** 2,000 `oracle` games at 4×4 are 2,000
  copies of one 14-ply game (`distinct game lines: 1`). `oracle-rt` (144
  distinct lines at 4×4, 753 at 3×3) is the evidence that the zero is not an
  artifact of the cell-order tie-break; it is not an independent sample of
  anything else.
- **No score, and no ko-sensitive value, is quoted anywhere in this note.**
  Legality is pure rules; the artifact is loaded only so the `oracle` policies
  can play. Scores are Black-positive by project convention; none is reported.
- **No recommendation is made about the ruleset.** This note reports a rate.
  The decision about whether PSK remains the provable target belongs to the user
  and to Opus, informed by this and by EXP-2.

## Reproduce

```
ZIG_LOCAL_CACHE_DIR=/tmp/weizigo-zigcache ZIG_GLOBAL_CACHE_DIR=/tmp/weizigo-zigcache \
  zig build -Doptimize=ReleaseFast
cp zig-out/bin/weizigo-reachcensus bin/          # bin/ is gitignored

# headline runs (seed 20260728, 2000 games/policy, settled-stop on)
bin/weizigo-reachcensus data/oracle-4x4.checkpoint.wzo --games 2000 --psk-binding
bin/weizigo-reachcensus artifacts/oracle-4x3.wzo       --games 2000 --psk-binding
bin/weizigo-reachcensus artifacts/oracle-3x3.wzo       --games 2000 --psk-binding

# truncation sensitivity
bin/weizigo-reachcensus <artifact> --games 2000 --psk-binding --no-settled-stop --ply-cap 1024

# seed robustness
bin/weizigo-reachcensus <artifact> --games 2000 --psk-binding --seed 1
bin/weizigo-reachcensus <artifact> --games 2000 --psk-binding --seed 999331

# verification check 1 -- the hand-verified 14-ply 4x4 oracle line
bin/weizigo-reachcensus data/oracle-4x4.checkpoint.wzo --games 1 --policy oracle --psk-binding --trace 1

# verification check 2 -- the fixed regression line
bin/weizigo-reachcensus data/oracle-4x4.checkpoint.wzo --replay regressions/4x4-history-blunder.gtp

# the flag does not perturb play (diff after stripping the new section)
bin/weizigo-reachcensus artifacts/oracle-3x3.wzo --games 2000
bin/weizigo-reachcensus artifacts/oracle-3x3.wzo --games 2000 --psk-binding
```

Each 4×4 run is ~1 s wall for all four policies at 2,000 games; the cost is
dominated by loading the 258 MB artifact.

## Cross-references

- `docs/epistemic/roadmap-2026-07-28.md` §1 and §3 (EXP-1), claim **QA-024**.
- `docs/research/ruleset-options.md:9-20` — which traditions use which
  repetition rule; the source of the "PSK is a computer convention" framing.
- `docs/research/ko-sensitive-chainability.md` Measurement 2 — the one-ban-per-
  game ground truth this note's `--replay` mode reproduces exactly.
- `docs/research/reachable-kosensitivity-2026-07-28.md` — the sibling measure on
  the same instrument (policy definitions, the `oracle` mirror validation
  against the real GTP player, the UNDEF and settled-stop discussion).
- `src/reachcensus.zig` — the instrument. `--psk-binding` and `--replay` are the
  new surfaces; the header comment carries the definitions above.
- `regressions/README.md` — the two saved games and the mirror relation used to
  corroborate the second game's transcription.
