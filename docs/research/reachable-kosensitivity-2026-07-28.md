# How much of the engine's own play is certifiable? — the reachable ko-sensitivity census (4×4, 4×3, 3×3)

**Date:** 2026-07-28. **Gobans:** 4×4, 4×3, 3×3, each measured independently.
**Tool:** `bin/weizigo-reachcensus` (new; `src/reachcensus.zig`, build target
`weizigo-reachcensus`). **Status of every claim tagged inline.** Every number
cites its command and seed.

## The question

The user's goal is *"play the optimal game of go; know when the play is optimal
and when it's not; shrink the suboptimal play toward zero."* That makes the
headline metric the **certified fraction**: over the positions the engine
actually *reaches in play*, what share are ones where its move-selection rule is
even well-defined?

Move selection (`Session.choose`, `src/gtp.zig`) is a one-ply extremum over
stored child values. That is a meaningful minimax only on the **chainable**
region, measured 2026-07-27 to be exactly the non-KO_SENSITIVE (L==H) region:
zero Bellman-identity violations outside the flag at 2×2/3×2/3×3/4×3/4×4 —
exhaustively at every size, 4×4 included as of 2026-07-28 (0 out-of-flag
violations over all 48,599,962 non-settled 4×4 slots), for the shipped
`vb`/`vw` columns
(`docs/research/ko-sensitive-chainability.md`, Measurement 1). So

> **certified fraction = 1 − (KO_SENSITIVE fraction over reached decision nodes)**

and the whole question is which denominator to use.

There was a large unexplained gap in the existing data:

- **slot-uniform** ko-sensitivity at 4×4 is **21.33%** — 10,367,922 /
  48,599,962, denominator = **non-settled (position, side) slots**, exhaustive
  (`bin/weizigo-chainability data/oracle-4x4.checkpoint.wzo --examples 0`,
  2026-07-28). Over **all legal slots** (48,636,330 — the converge-census
  denominator) the same numerator gives **21.32%**. An earlier revision of this
  note quoted **21.27%**, the superseded 1:37 colex-stride *sample* estimate of
  the 21.33% figure; see the reconciliation table in
  `ko-sensitive-chainability.md` (end of Measurement 1);
- but along the two saved regression games, **16 of 19 plies (84%)** are
  KO_SENSITIVE (same doc, Measurement 3).

**Slot-uniform figures in this note use the 21.33% form** (non-settled
denominator, exhaustive), because that is the quantity the chainability sweep
measures and the one the sample was estimating. The 0.01 pp gap to the census
form changes nothing below.

Uniform-over-slots is simply the wrong denominator for a player: it weights
every legal (position, side) equally, and the table is overwhelmingly made of
crowded late-game positions a game rarely visits. A player walks lines from the
empty goban. This note measures that measure.

## Term

**Decision node** *[project term]* — the `(position, side-to-move)` pair standing
at one ply of a played game, observed *before* the move is made. One decision
node = one opportunity for the engine to be right or wrong. The census
denominator is decision nodes, not table slots.

## The instrument

`src/reachcensus.zig` loads a `.wzo` artifact, plays complete games from the
empty goban, and reports the KO_SENSITIVE fraction (bit 0 of `fb`/`fw`, i.e.
L < H) over the decision nodes visited. Goban size comes from the artifact
header and dispatches 2×2/3×2/3×3/4×3/4×4 exactly as `src/chainability.zig`
does. It reads the artifact only — no search, no reference solver.

- **Legality is the real thing.** Positional superko is enforced against the
  actual game history (every position that has occurred, empty goban included,
  mirroring `Session.reset`), plus `rules.Rules(w,h)` occupancy/suicide. No
  eye-prune — neither player uses one.
- **Termination:** two consecutive passes, a settled position (`R.is_settled`),
  or a hard ply cap (default 256, reported loudly; see the censoring check
  below).
- **Determinism:** one `std.Random.DefaultPrng` per policy, seeded from a
  master `--seed` with a per-policy offset so that adding or removing a policy
  cannot perturb another's numbers. Seed and game count are printed in the
  header of every run. No unseeded randomness anywhere.
- **UNDEF handling:** unfilled slots hold the sentinel −128 (`src/gtp.zig`). A
  KO_SENSITIVE flag on an UNDEF slot is meaningless, so **any game that visits
  an UNDEF decision node is excluded wholesale from the belief statistics** and
  counted separately (`games touching UNDEF`, plus a raw `UNDEF nodes seen`
  count). Exclusion never changes play — the oracle rule reads *children*, not
  the node itself — it only drops games from the statistics.

### The four policies

The measure depends on who is playing, so four are reported:

| policy | Black | White |
|---|---|---|
| `oracle` | engine rule | engine rule |
| `oracle-rt` | engine rule, random tie-break | same |
| `random` | uniform over PSK-legal moves, 5% pass | same |
| `mixed` | alternates by game index: engine / random, then random / engine | |

**What `oracle` mirrors of `Session.choose`:** the extremum over PSK-legal
children's *stored* values; the pass edge as a candidate, valued
`v1_from_table` at `passes==0` and `area_score` at `passes>=1`; the full
`(value, MORE captures, SMALLER DTT)` tie-break ordering, incumbent-keeps on a
full tie (cell order); UNDEF children dropped from candidacy; and the early-game
"always play the opening" override (`own < area/4 and total < area/2`).
**What it does not mirror:** resign — the sustained-loss / two-eye / settled
backstop policy that `src/gtp.zig` applies *above* `choose`, and its
`vals_b`/`vals_w` bookkeeping. Resign only ends games early; it does not change
a single move choice, so its absence lengthens some lines and cannot alter which
region a chosen move sits in.

**Mirror validated move-for-move (PROVEN, these three gobans, 2026-07-28).**
The census `oracle` line was compared against the real GTP player built from the
working-tree `src/gtp.zig` (`zig build-exe -O ReleaseFast src/gtp.zig`, then
alternating `genmove b` / `genmove w`):

| goban | census `--trace 1` line | real GTP player |
|---|---|---|
| 4×4 | B3 C2 C3 B2 A2 A3 A4 D3 B1 C4 C1 D2 pass pass | identical, 14 plies |
| 4×3 | B2 C2 C3 C1 D2 B3 A3 B1 A2 pass pass | identical, 11 plies |
| 3×3 | B2 A3 B3 C3 A2 pass C2 | identical prefix, 7 plies |

(The 3×3 census stops at ply 7 because the position is settled there; the GTP
player has no settled-stop and plays on. See the censoring check.)

`oracle-rt` exists only because plain `oracle` is **deterministic**: N games are
N copies of one line. The tool counts distinct game lines in every run so this
cannot be misread — `distinct game lines: 1` appears on every `oracle` row
below.

## Results

All runs 2026-07-28, `zig build -Doptimize=ReleaseFast`, **2,000 games per
policy**, **master seed 20260728**, ply cap 256, random pass probability
50/1000, settled-stop on.

```
bin/weizigo-reachcensus data/oracle-4x4.checkpoint.wzo --games 2000
bin/weizigo-reachcensus artifacts/oracle-4x3.wzo       --games 2000
bin/weizigo-reachcensus artifacts/oracle-3x3.wzo       --games 2000
```

Artifact SHA-256 (first 16): `data/oracle-4x4.checkpoint.wzo` `a2174fedd6a0591d`;
`artifacts/oracle-4x3.wzo` `5316f428ad821c79`; `artifacts/oracle-3x3.wzo`
`c1f8fe5edac9a427`.

### 4×4 — `data/oracle-4x4.checkpoint.wzo`

| policy | games | distinct lines | mean plies | nodes | **KO_SENS, node-wtd** | KO_SENS, game-wtd | engine-to-move | UNDEF games |
|---|---|---|---|---|---|---|---|---|
| `oracle`    | 2000 | **1**   | 14.00 | 28,000 | **100.00%** | 100.00% | 100.00% (28,000) | 0 |
| `oracle-rt` | 2000 | 144     | 13.93 | 27,865 | **100.00%** | 100.00% | 100.00% (27,865) | 0 |
| `random`    | 2000 | 1993    | 42.60 | 85,200 | **28.90%**  | 31.84%  | n/a | 0 |
| `mixed`     | 2000 | 2000    | 22.25 | 44,504 | **34.41%**  | 34.75%  | **21.72%** (4,941/22,750) | 0 |

Slot-uniform reference for the same artifact: **21.33%** (exhaustive;
10,367,922 / 48,599,962 non-settled slots. Over all 48,636,330 legal slots:
21.32%).

By ply index (node-weighted KO_SENSITIVE %):

| ply | 0–3 | 4–7 | 8–11 | 12–15 | 16–19 | 20–23 | 24–27 | 28–31 | 32+ |
|---|---|---|---|---|---|---|---|---|---|
| `oracle` | 100.00 | 100.00 | 100.00 | 100.00 | — | — | — | — | — |
| `random` | 86.30 | 50.72 | 36.23 | 18.41 | 9.27 | 9.32 | 14.94 | 26.51 | 20.98 |
| `mixed`  | 86.79 | 52.94 | 31.08 | 14.77 | 4.46 | 2.39 | 2.73 | 29.41 | 13.04 |

### 4×3 — `artifacts/oracle-4x3.wzo`

| policy | games | distinct lines | mean plies | nodes | **KO_SENS, node-wtd** | KO_SENS, game-wtd | engine-to-move | UNDEF games |
|---|---|---|---|---|---|---|---|---|
| `oracle`    | 2000 | **1** | 11.00 | 22,000 | **100.00%** | 100.00% | 100.00% (22,000) | 0 |
| `oracle-rt` | 2000 | 24    | 11.00 | 22,000 | **100.00%** | 100.00% | 100.00% (22,000) | 0 |
| `random`    | 2000 | 1994  | 29.32 | 58,645 | **38.11%**  | 39.56%  | n/a | 0 |
| `mixed`     | 2000 | 1981  | 14.68 | 29,362 | **40.01%**  | 40.01%  | **31.49%** (4,780/15,178) | 0 |

Slot-uniform reference: **26.60%** (chainability sweep, exhaustive,
denominator = **non-settled** slots). The 4×3 converge census reports 26.47%
over **all legal** slots; that 0.13 pp gap is the 4×3 row of `CLAIMS.md`
discrepancy D7 and is **NOT reconciled** — only the 4×4 row has been.

### 3×3 — `artifacts/oracle-3x3.wzo`

| policy | games | distinct lines | mean plies | nodes | **KO_SENS, node-wtd** | KO_SENS, game-wtd | engine-to-move | UNDEF games |
|---|---|---|---|---|---|---|---|---|
| `oracle`    | 2000 | **1** | 7.00  | 14,000 | **42.86%** | 42.86% | 42.86% (6,000/14,000) | 0 |
| `oracle-rt` | 2000 | 753   | 8.15  | 16,306 | **41.38%** | 42.00% | 41.38% (6,747/16,306) | 0 |
| `random`    | 2000 | 1994  | 20.20 | 40,407 | **52.14%** | 51.59% | n/a | 0 |
| `mixed`     | 2000 | 1505  | 10.97 | 21,933 | **48.45%** | 47.58% | **38.76%** (4,433/11,437) | 0 |

Slot-uniform reference: **35.04%** (chainability sweep, exhaustive,
denominator = **non-settled** slots). The 3×3 converge census reports 34.3%
over **all legal** slots; that gap is the 3×3 row of `CLAIMS.md` discrepancy D7
and is **NOT reconciled**.

## What this means for the user's metric

**PROVEN (4×4, on `data/oracle-4x4.checkpoint.wzo`, 2026-07-28, seed 20260728,
2,000 games/policy):**

- **In engine-vs-engine play at 4×4 the certified fraction is exactly ZERO.**
  All 14 plies of the engine's single self-play line are KO_SENSITIVE
  (28,000/28,000 nodes; `distinct game lines: 1`). Randomising tie-breaks
  (`oracle-rt`, 144 distinct lines) does not find a single certifiable node
  either: 27,865/27,865. The engine starts the 4×4 game inside the region where
  its own rule is undefined — the empty goban is flagged in 2000/2000 games —
  and, playing itself, **never leaves it**. This is the reachable-measure
  restatement of Measurement 3's "it starts the game there."
- **The same holds at 4×3** (100.00%, 22,000/22,000, both oracle policies).
  At **3×3** it does not: the engine's 7-ply line is 42.86% KO_SENSITIVE, and
  the flag clears completely from ply 4 onward (bucket 4–7 is 0.00%).
  Per-goban independence: these are three separate results, not a trend.
- **The 21.33% slot-uniform figure badly understates the player's exposure**
  under every policy measured, at every goban measured: 4×4 21.33% → 28.90%
  (random) / 34.41% (mixed) / 100% (oracle); 4×3 26.60% → 38.11 / 40.01 / 100;
  3×3 35.04% → 52.14 / 48.45 / 42.86. It is a fine artifact statistic and a
  misleading player statistic. (Slot-uniform figures over non-settled slots;
  reachable figures over **decision nodes visited** — two different
  denominators, which is the entire point of this note.)

**Sanity check — PASSED.** The pre-registered check was that at 4×4 the
`random` policy's reachable fraction must be closer to the slot-uniform
figure than `oracle`'s. It is, by an order of magnitude: |28.90 − 21.33| =
7.57 pp versus |100.00 − 21.33| = 78.67 pp. (The check was pre-registered
against the then-current 21.27% sample estimate, giving 7.63 pp vs 78.73 pp;
substituting the exhaustive 21.33% moves both by 0.06 pp and changes no
verdict.) **Reported honestly: the check
inverts at 3×3** (random 52.14% is 17.10 pp from slot-uniform 35.04%, oracle
42.86% is 7.82 pp), because the 3×3 oracle line settles in 7 plies and leaves
the flagged region, while random play wanders in it for 20. The check was
specified at 4×4 and is a property of that goban's policies, not a law.

### The headline number, and why it is not one number

> **What fraction of its own moves can the current 4×4 engine certify as
> optimal?** Against itself: **0%** — all 14 plies of its self-play line are
> KO_SENSITIVE. Against a uniformly random opponent: **78.3%** of its own moves
> (`mixed` policy, 21.72% flagged = 4,941 / 22,750 **engine-to-move decision
> nodes**). Along the two saved regression games against a human,
> **16%** of plies are unflagged (16 of 19 flagged — that count is over *all*
> plies of those games, both sides, not the engine's moves alone; the per-side
> split was not recorded). The honest answer is a **range from 0% to ~78%,
> policy-dependent**, and the two real recorded games sit near the bottom of it.

**Do not quote the `mixed` 78.3% as "the" certified fraction against human
opponents.** Three reasons, all load-bearing:

1. **It is policy-dependent by construction.** The number *is* a property of the
   opponent distribution. A different opponent gives a different number, and
   the spread here is 0%–78%.
2. **A uniformly random opponent is a weak proxy for a human.** Random play
   scatters the game off the contested lines quickly; the ply-index breakdown
   shows `mixed` at 86.79% flagged in plies 0–3 collapsing to 2.39% by plies
   20–23. The two saved regression games — an actual human opponent — measured
   **84% flagged over 19 plies**, i.e. far closer to `oracle` (100%) than to
   `mixed` (34.41% over all nodes). **CLAIMED:** a competent opponent keeps the
   game in the contested region much longer than a random one does, so `mixed`
   is a **lower bound** on the engine's real exposure against a human, not an
   estimate of it. Evidence: two games. That is thin, and it is all there is.
3. **`oracle` self-play is a strict upper bound on exposure (100%), `mixed` a
   loose lower bound (21.72%), and the honest interval is the whole span.**

### Secondary finding — the engine steers *into* the unchainable region

**CLAIMED (2026-07-28, all three gobans, `mixed` policy).** Splitting the
`mixed` nodes by who is to move:

| goban | engine-to-move nodes flagged | opponent-to-move nodes flagged |
|---|---|---|
| 4×4 | 21.72% (4,941/22,750) | **47.68%** (10,373/21,754) |
| 4×3 | 31.49% (4,780/15,178) | **49.13%** (6,969/14,184) |
| 3×3 | 38.76% (4,433/11,437) | **59.00%** (6,193/10,496) |

An opponent-to-move node is precisely the position the engine's *own last move*
created. So the engine's chosen children are KO_SENSITIVE roughly **twice as
often** as the random opponent's are, at 4×4. This is exactly what Measurement 3
of `ko-sensitive-chainability.md` predicts: *"the greedy pick systematically
selects the child whose false premise is most flattering,"* and the flattering
values live in the flagged region. **This is not proof** — the sides are
balanced by alternating the engine's colour by game index, but games end
slightly more often after an engine move (22,750 engine nodes vs 21,754
opponent nodes at 4×4, ≈0.5 extra per game), and those terminal-adjacent nodes
are the least flagged. Correcting for that at the extreme (attributing all 996
excess engine nodes to unflagged late play) moves 21.72% to 22.72% — nowhere
near closing a 26 pp gap. A cleaner test would fix the engine's colour and
compare parity-matched plies; not run.

### Censoring and robustness checks

**Ply cap.** At 4×4 with the default cap 256, the `random` policy hit the cap in
1 of 2,000 games (0.05%); every other policy/board hit it zero times. Re-running
random at cap 1024 (independent seed stream):
`bin/weizigo-reachcensus data/oracle-4x4.checkpoint.wzo --games 2000 --ply-cap 1024 --policy random`
→ 0 cap hits, mean 41.67 plies (max 198), **29.03%** vs 28.90%. Censoring is
immaterial and the two independent seed streams agree to 0.13 pp.

**Settled-stop truncation.** Stopping at `R.is_settled` is a truncation the real
GTP player does not perform — it plays on, capturing dead stones, until pass is
optimal. Since late plies are the *least* flagged, this biases the fraction
*upward*. Measured at 4×4:
`bin/weizigo-reachcensus data/oracle-4x4.checkpoint.wzo --games 2000 --ply-cap 1024 --no-settled-stop`

| policy | with settled-stop | without (two-pass only) |
|---|---|---|
| `oracle` | 100.00% | 100.00% (never fired: 2000/2000 already end in two passes) |
| `random` | 28.90% | 26.67% (mean plies 42.60 → 115.40) |
| `mixed` node-wtd | 34.41% | 30.64% |
| `mixed` engine-to-move | 21.72% | **19.66%** |

The bias is real and modest (≈2 pp on the headline `mixed` figure), it points
the direction predicted, and it changes no conclusion. The 0% oracle result is
completely unaffected.

**Seed robustness (4×4, 2,000 games/policy):**

| seed | `random` | `mixed` node-wtd | `mixed` engine-to-move | `oracle` |
|---|---|---|---|---|
| 20260728 | 28.90% | 34.41% | 21.72% | 100.00% |
| 1        | 29.26% | 34.73% | 22.06% | 100.00% |
| 999331   | 28.91% | 34.86% | 22.29% | 100.00% |

Spread ≤0.6 pp on every randomised statistic; `oracle` is seed-invariant by
construction.

**UNDEF.** Zero UNDEF nodes on all three artifacts above, so no game was
excluded and the belief statistics use 100% of games. The UNDEF path was
exercised on the *other* 4×4 artifact,
`data/oracle-4x4-parallel.checkpoint.wzo`: **100.00% of games touch UNDEF, 0
clean games, statistics undefined.** `--trace 1` shows why — the **empty-goban
root slot itself is UNDEF** on that artifact (`BA4?` at ply 0). **PROVEN
(2026-07-28, that artifact):** the parallel checkpoint supports no belief
statistic at all from the empty goban, and a player using it steers from move
one with no stored value at the root. That artifact is not used for any number
in this note.

## Caveats — all load-bearing

- **This measures reachability under these four policies, not over all legal
  play.** There is no claim about the measure induced by any other opponent,
  and in particular none about strong human play beyond the two-game regression
  evidence cited above.
- **Per-goban independence (AGENTS.md).** 4×4, 4×3 and 3×3 are three separate
  results. The 4×4 "0% certified in self-play" says nothing about 5×5, and the
  fact that 3×3 escapes the flagged region by ply 4 while 4×4 never does is
  precisely why extrapolation is forbidden here. No monotonicity argument is
  offered.
- **The census does not check whether the flagged values are *wrong*** — only
  whether the engine's selection rule is *defined* there. Whether a given
  flagged value is also mispriced is the chainability sweep's question
  (4×4: **4.08% of flagged non-settled slots** on the committed artifact —
  422,990 / 10,367,922, exhaustive 2026-07-28; **1.67%** on a writes-off regen,
  which is a stride-37 *sample* figure on an artifact confirmed incomplete;
  `ko-sensitive-chainability.md` Measurements 1 and 4).
- **The committed 4×4 ko-sensitive values are not trustworthy** (AGENTS.md
  foreclosure). Nothing here quotes a ko-sensitive *score*; only the flag is
  read, and the flag is an L<H bracket property, not a score.
- **Scores are Black-positive throughout; no score is reported in this note.**
- **`oracle` is one line.** 2,000 `oracle` games at 4×4 are 2,000 copies of one
  14-ply game. `oracle-rt`'s 144 distinct lines are the evidence that the single
  line is not a fluke of the cell-order tie-break; they are not independent
  samples of anything else.
- **No engine change was made.** This is a measurement; the deliverable fork
  (restrict the player to the chainable region, vs. bounded-history state, vs.
  ship as-is) is the open decision recorded at the end of
  `ko-sensitive-chainability.md`, and it is the user's call.

## Reproduce

```
ZIG_LOCAL_CACHE_DIR=/tmp/weizigo-zigcache ZIG_GLOBAL_CACHE_DIR=/tmp/weizigo-zigcache \
  zig build -Doptimize=ReleaseFast
cp zig-out/bin/weizigo-reachcensus bin/          # bin/ is gitignored

# the three headline runs (seed 20260728, 2000 games/policy)
bin/weizigo-reachcensus data/oracle-4x4.checkpoint.wzo --games 2000
bin/weizigo-reachcensus artifacts/oracle-4x3.wzo       --games 2000
bin/weizigo-reachcensus artifacts/oracle-3x3.wzo       --games 2000

# censoring / robustness
bin/weizigo-reachcensus data/oracle-4x4.checkpoint.wzo --games 2000 --ply-cap 1024 --policy random
bin/weizigo-reachcensus data/oracle-4x4.checkpoint.wzo --games 2000 --ply-cap 1024 --no-settled-stop
bin/weizigo-reachcensus data/oracle-4x4.checkpoint.wzo --games 2000 --seed 1
bin/weizigo-reachcensus data/oracle-4x4.checkpoint.wzo --games 2000 --seed 999331

# UNDEF path, and the parallel checkpoint's UNDEF root
bin/weizigo-reachcensus data/oracle-4x4-parallel.checkpoint.wzo --games 2000
bin/weizigo-reachcensus data/oracle-4x4-parallel.checkpoint.wzo --games 1 --policy oracle --trace 1

# mirror validation against the real GTP player
bin/weizigo-reachcensus data/oracle-4x4.checkpoint.wzo --games 1 --policy oracle --trace 1
zig build-exe -O ReleaseFast src/gtp.zig    # then: genmove b / genmove w, alternating
```

Each 4×4 run is ~0.7 s wall for all four policies at 2,000 games (the cost is
dominated by loading the 258 MB artifact).

## Cross-references

- `docs/research/ko-sensitive-chainability.md` — the 2026-07-27 finding this
  quantifies: the chainable region is exactly the non-KO_SENSITIVE region
  (Measurement 1, exhaustive at 4×4 as of 2026-07-28), the **21.33%**
  slot-uniform figure over non-settled slots and its reconciliation with the
  census's 21.32% over all legal slots and the superseded 21.27% sample
  estimate, the 16-of-19-plies regression
  observation (Measurement 3), the greedy-optimism mechanism this note's
  engine-vs-opponent asymmetry corroborates, and the deliverable fork.
- `src/chainability.zig` — the slot-uniform instrument; `src/reachcensus.zig` is
  its reachable-measure counterpart and shares its dispatch and its
  artifact-only discipline.
- `src/gtp.zig` — `Session.choose` (the rule mirrored) and the UNDEF sentinel.
- `docs/research/arena-4x4-undef.md` — the arena's random-persona leak rate,
  which Measurement 3 argued is a lower bound for a greedy player; the
  engine-steers-into-the-region asymmetry above is independent support for that
  argument.
