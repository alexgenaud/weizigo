# The leak crisis

**Status: OPEN — the project's focus. Nothing here is asserted as proven; each
claim carries a verification status. This chapter was rewritten 2026-07-25
after an epistemic reset: the previous version still asserted "the proven core
and brackets remain solid," which is itself an unverified claim. That line is
withdrawn.**

## NOTES (this discussion, 2026-07-25)

- **The classification question (answered).** Is a position labelled
  "single-score" or "range" decided by the *previous* moves (empty → now) or
  by the *future* (paths toward terminals)? **Answer: the future.** The L/H
  fixpoints are value iteration over the forward move graph with cycle
  resolutions at extremes; L==H vs L<H is a property of a position's future
  game tree. It does **not** use the actual past moves of any game.
  - *But* the property it **claims** to detect is **past-independence** —
    "this position's value does not depend on the history used to reach it."
    So the classification is **future-computed** while making a **claim about
    the past**.
  - That past-independence claim is **unverified** (see Claim 2 below). The
    leak is consistent with the ko-sensitive side (real-game value *does*
    depend on the actual past there) but does **not** verify the single-score
    side.
- **Epistemic reset.** "Certified"/"proven" means, by our own definition, a
  proven minimal final score. That has turned out **not** to be established
  in the scope we implied. We are no longer asserting what is or is not a
  table bug, what is or is not true. Several things do not logically add up
  yet; the job is to design experiments that make them add up, not to pick a
  story. All "assertions of proof" are off the table until each claim below
  has a verification status of PROVEN.
- **Naming tension.** The proposed name "proven scores" **presupposes**
  Claim 2, which is unverified. See `names.md`. Either earn the name (pass
  E1) or use a non-overclaiming name now and rename when earned.

## What "leak" means

At each position where the audited player is to move, the table's stored
fresh-start score is treated as a **promise**. If the game's final score
falls short of the *strongest* promise made anywhere in that game, that game
**leaks** (`research/arena-audit.md`). The name is mild; it measures a
**critical error in the player's reasoning**, not necessarily a table bug —
but we are not yet asserting which side the error is on.

## The claims and their verification status

We separate the claims we have been implicitly bundling, and mark each.

| # | claim | status | how to prove / falsify |
|---|---|---|---|
| C1 | Fresh-start scores are correct as **fresh-start** values (2×2, 3×2) | PROVEN (vs history-aware exact solver) | already done |
| C2 | Single-score (L==H) positions are **history-independent**: their value is the same no matter the arrival history | CLAIMED, not a theorem; supported only indirectly (Exact-on-reachable, anchors, symmetry, auditor) | E1 below |
| C3 | The range `[L,H]` **bounds** the real-game score for any arrival history, for any cycle rule in [−n,n] | CLAIMED, **not directly verified** | E2 below |
| C4 | Fresh-start score == real-game score | FALSE for ko-sensitive (the leak refutes it); claimed TRUE for single-score **only if C2 holds** | consequence of C2 |

**The thing that does not add up:** the leak occurs on tables that are
"proven correct" (C1). That is not a contradiction — C1 proves correctness
*as fresh-start values*, and the leak shows fresh-start ≠ real-game. But it
exposes that "proven" was being used as if it meant "proven final score of
the game from this position," when it means "proven fresh-start score." The
overclaim is in scope, not (necessarily) in computation. C2 and C3 — the
claims that would actually let us call something a "proven final score" or a
"true range" — are **not** established. Until they are, we have no proven
final scores and no proven ranges; we have fresh-start values (C1) and
unverified bounds.

## The measured refutation (of C4 on ko-sensitive positions)

| board | table (C1) | leak rate | max leak |
|---|---|---|---|
| 2×2 | proven as fresh-start | 14–17% | 2 pts |
| 3×2 | proven as fresh-start | 39–46% | 12 pts |
| 3×3 | residue untrusted | 6–14% | 18 pts |
| 4×4 | residue untrusted | 7–18% | 32 pts |

Stronger opponents leak more (optimal ≈15.8%, novice ≈7.3%) — the failure is
exploitable. The arena's own line: "the leak class is entirely the player's
history-blindness, not the table's." **That line is itself a claim we are no
longer asserting; E1/E2 test it.**

## Experiments (intent, what we hope to discover, acceptance)

We document intent first, then run, then record findings here.

### E1 — does the single-score region ever diverge? (tests C2, the cheap decisive one)

- **Intent:** determine whether single-score (L==H) positions are truly
  history-independent, by checking whether the "promise becomes unkeepable"
  event (a *diverged* event: the best achievable child value under the real
  history differs from the stored value) ever occurs **at a single-score
  position**.
- **Why it is decisive:** if a single-score position diverges, its achievable
  value changed with history → C2 is **falsified** → we have no proven core,
  the single-number claim is false, and much prior work is unsound. If
  **no** single-score position ever diverges, C2 is **supported** (leaks come
  only from entering ko-sensitive children), and the partition holds.
- **Method:** instrument the arena to tag each diverged event with the
  position's region (single-score vs ko-sensitive) using the existing L==H
  flag. Re-run the arena.
- **Acceptance:** zero diverged events at single-score positions.
- **`TODO`:** implement the region tag; run; record counts here.

### E2 — does a range-aware player leak? (tests C3, the lower bound)

- **Intent:** test whether `L` is a true lower bound on the real-game score.
  Policy: enforce superko legality with the real history (cheap), then among
  legal moves pick the one maximizing the child's worst-case `L`. The player
  "promises" only `L`; if the real score is always ≥ `L`, the final never
  falls short → **zero leaks by construction**.
- **Why it is decisive:** zero leaks ⇒ C3's lower-bound half holds (and C2
  too, since single-score children have L=H and the player prefers the
  history-free child). Any leak ⇒ `L` is not a true lower bound → C3 is
  falsified → the range is not the true range.
- **Acceptance:** zero leaks across all boards and personas.
- **`TODO`:** implement range-aware `genmove` (maximin over the `L` column,
  legal moves filtered by real superko history); add a "range-aware promise"
  metric (promise = the `L` of the chosen move); run the arena; record here.

### Ordering

E1 is cheaper and isolates C2; run it first. E2 tests C2+C3 together and is
the sound-player experiment. Both findings go in this chapter.

## What is now suspect vs not-yet-earned (until E1/E2)

- **Not asserted:** "the single-score region is proven"; "the range is the
  true range"; "the table is correct as real-game values"; "the player plays
  perfectly / near-perfectly."
- **Still PROVEN (narrow):** C1 — fresh-start values match the exact solver
  at 2×2/3×2. This says nothing about real-game values.
- **The strategic fork is on hold** until E1/E2 settle C2/C3. Building a
  5×5 table on top of unverified C2/C3 would compound an unproven foundation.

## Open questions

- **`TODO` (E1):** run the single-score divergence test; record counts.
- **`TODO` (E2):** implement range-aware player; run zero-leak test.
- **`TODO`:** is C2 actually a theorem (a least/greatest-fixpoint lattice
  argument), or only empirical? If a theorem, write the proof; if not, E1 is
  the only evidence and must be run at every board size.
- **`TODO`:** is C3's lower bound a theorem, or only empirical?

## NOTES (2026-07-25, after reading the arena code — E1 is confounded)

The user's insight, recorded: under PSK a position can appear **once**; whether
it "did repeat before" or "will repeat after" are two faces of the same ban.
So one might assume every position could be the first or the only occurrence and
score it "as if it cannot repeat again." This is essentially what the L/H
fixpoint attempts. The user's stronger hypothesis: **all positions are
potentially ko-sensitive** — a single-value ("proven") score is not earned by
looking only at subsequent moves and assuming no repeats from before the
current position. That hypothesis is the right thing to be suspicious of.

**Analysis of that hypothesis.** It is too strong as stated: terminal / settled
positions have no moves whose legality changes anything, so their score is
genuinely history-independent — the single-value region is non-empty at least
there. But the *spirit* is correct and is exactly the open risk: the L/H
fixpoint classifies a position as single-value (L==H) by resolving cycles at
extremes over the forward graph, and we have **not** verified that this
correctly captures how the real, path-dependent ban set (positions seen before
the current position, not just cycles reachable from it) constrains the future.
That is C2, unverified. So "single-value" is a *claimed* label, not a fact.

**E1, as I first wrote it, is NOT a clean C2 test — corrected.** I described E1
as "does a single-value position's best achievable child value under real
history differ from stored." Reading `src/arena.zig`: the arena's `best` is
`max` of the **fresh-start child values** over PSK-legal children — that is the
**fresh-start player's belief**, not the true real-history achievable value. A
diverged event at a single-value position means only "the fresh-start player's
believed-optimal move was PSK-banned." That is **consistent with C2**: the
value may still be achievable via a different (possibly ko-sensitive) child
whose *real-history* value equals the stored value even though its fresh-start
value differs. So:
- E1 is a **diagnostic** of *where the fresh-start player's plan breaks* (which
  localizes the leak source), **not** a falsifier of C2. A non-zero single-value
  diverged count does NOT falsify C2; a zero count does NOT prove it.
- The clean C2 test needs the **true real-history value**, which is the
  intractable exact solve — so C2 is not directly tractably testable in general.

**E2 is the decisive *tractable* test.** A range-aware player (maximin over the
`L` column; promise = the `L` of the chosen move) uses the game **outcome** (the
final score is computable — the game ends), not the intractable true value.
Acceptance = **zero leaks** (final ≥ promised `L` across all boards/personas).
Zero leaks ⇒ `L` is a true lower bound on the real-game value (C3 supported)
and, since single-value children have `L=H`, C2 is supported too. Any leak ⇒ C3
is falsified. **Caveat: the artifact does not store the L/H columns** — it
stores final value + flags + dtt. So E2 must run against an **in-memory
converged table** (`retro.zig` `converge` keeps `lo`/`hi`), not an artifact.
Implementation: a `retro.zig` probe that converges a small board then self-plays
with a range-aware player reading `lo`/`hi`.

**Revised experiment plan:**
- **E1 (diagnostic, run now):** region-tag the arena's diverged events using the
  `KO_SENSITIVE` flag. Reports *where the fresh-start plan breaks*
  (single-value vs ko-sensitive). Not a C2 proof.
- **E2 (decisive, next):** in-memory range-aware player in `retro.zig`; zero-
  leak acceptance. The real crisis resolver.

**Naming decision (recorded 2026-07-25):** adopt **"single scores"** / **"single
score region"** (non-overclaiming); rename to "proven" only if E2 supports C2/C3.
See `names.md`.

## E1 findings (2026-07-25) — diagnostic run

**Run:** `./arena-e1 <artifact> <seeds>` (region-tagged diverged events, 6
personas × 2 colours × 3 handicaps). Flags from the committed artifacts'
converge phase (the sound part per ADR-0013; the finisher bug did not touch
flags — caveat: flags not independently re-verified this run).

| board | seeds | total diverged events (optimal persona) | single-score | ko-sensitive |
|---|---|---|---|---|
| 2×2 | 50 | 77 | **0** | 77 |
| 3×2 | 50 | 40 | 3 | 40 (others) |
| 3×3 | 30 | 19 | 1 | 19 (others) |

Across all personas (single-score diverged counts):
- **2×2: single-score diverged = 0 for every persona.** All divergences (71–87)
  are at ko-sensitive positions. On the smallest, fully-proven board, the
  fresh-start player's plan breaks **only** in ko territory.
- **3×2: single-score diverged = 3–13 per persona** (non-zero minority; e.g.
  winning-slop 13, novice 13). Majority still ko-sensitive (40–107).
- **3×3: single-score diverged = 1–11 per persona** (e.g. kyu 11). Minority.

**Interpretation (what this does and does not say):**
- It does **not** falsify C2. A single-score divergence means the fresh-start
  player's *believed*-optimal move was PSK-banned; the true value may still be
  achievable via a different (often ko-sensitive) child whose *real-history*
  value equals the stored value even though its fresh-start value differs. The
  arena reads fresh-start child values, so it cannot see that. Consistent with
  C2.
- It **does** pinpoint the leak mechanism: the fresh-start player leaks because
  it relies on **fresh-start child values**, which (a) break under PSK bans even
  at single-score parents, and (b) understate the real value of ko-sensitive
  children. So the player cannot find the value-preserving move. This is
  exactly why a **range-aware** player (E2) is the fix — it relies on the floor
  `L`, not on fresh-start child values.
- The non-zero single-score divergences at 3×2/3×3 (vs zero at 2×2) show the
  mechanism grows with board size, matching the rising leak rate (2×2 14–17% →
  3×2 39–46%).

**Caveat on the flags.** E1 trusts the committed artifacts' `KO_SENSITIVE`
flags (from converge). If a position is *mis-flagged* (actually ko-sensitive
but labelled single-score), a "single-score divergence" could be a mislabelled
ko-sensitive one. `TODO`: re-verify the flags via a clean converge regenerate
(cheap at 2×2/3×2/3×3) to confirm the single-score counts are not a flag bug.

**Conclusion of E1 (diagnostic):** the crisis is consistent with the theory —
leaks originate when the fresh-start player's fresh-start-child-value plan
collides with real PSK history, mostly in ko-sensitive territory and
increasingly at single-score parents as boards grow. It does not by itself
prove C2 or C3. **E2 (range-aware zero-leak) is the decisive next experiment.**

## E2 — intent (2026-07-25, before running)

**What:** a **range-aware** self-play player that uses the `lo` (lower-fixpoint)
column as a guaranteed floor, and checks whether the real game outcome ever
falls below that floor.

**Policy:** both players play the lo-game — Black maximizes `lo[child]`,
White minimizes `lo[child]` — with **real PSK legality** enforced by an actual
game-history stack (a move recreating any prior board is illegal). Random
tie-break among lo-optimal moves for line variety. The **audited** colour
records a **promise** = the lo-floor of the move it chose (the maximin
guarantee under the real history). A game **leaks** if the final score is
worse for the audited colour than its strongest promise.

**Why this tests C2+C3 (and is tractable):** it uses the game **outcome**
(the final area score, which is computable), not the intractable true
real-history value. If `lo` is a true lower bound on the real value for every
position under every history (C3) — and the single-score region is history-
free (C2, since there `lo==hi`) — then the audited player, playing the
maximin lo-game, can never be pushed below its promised floor by any
opponent ⇒ **zero leaks by construction**. Any leak ⇒ `lo` overstates the
real value somewhere ⇒ C3 falsified (and with it the "true range" claim).

**Acceptance:** zero leaks across 2×2 / 3×2 / 3×3 (in-memory converge, no
artifact — the artifact does not store `lo`/`hi`). Decisive for C3; indirect
support for C2.

**Caveat (what it does NOT prove):** a lo-based opponent is a *proxy* for the
true worst-case opponent (which would minimize the real value, not `lo`). So
zero leaks is strong support for C3, not a proof that no history exists where
real < lo. To strengthen detection, a random-opponent breadth pass is a
follow-up. Also: this trusts the converge `lo` computation itself (the
sound part per ADR-0013).

## E2 findings (2026-07-25) — CRITICAL, under investigation

**Run:** `RETRO_E2=1 ./retro-e2` (in-memory converge 2×2/3×2/3×3; 2000 seeds ×
2 colours = 4000 games each; both players range-aware).

**Bug fixed during the run (recorded):** my first E2 used the `lo` column for
*BOTH* colours. That is wrong for White: White (the minimizer) secures its
**ceiling** `hi`, not its floor `lo` (White can only *guarantee* the worst case
*for White* = best-for-Black = `hi`; promising `lo` = best-for-White is a hope,
not a guarantee). Fixed: Black maximizes `lo[child]`, White minimizes
`hi[child]`. This is exactly the sign/bound-direction subtlety the project has
been bitten by before.

**Results:**

| board | games | leaks | max leak | verdict (provisional) |
|---|---|---|---|---|
| 2×2 | 4000 | **0** | 0 | zero leaks — C3 supported on explored lines |
| 3×2 | 4000 | **0** | 0 | zero leaks — C3 supported on explored lines |
| 3×3 | 4000 | **25** | 12 | **leaks — C3 falsified OR a lo/player bug (UNRESOLVED)** |

**The 3×3 leak signature (alarming, and the reason not to assert yet):** every
leak is `audited B, promise +3, final -9` (a few `final -2`). Black's range-aware
floor from some position was **+3**, but actual play ended at **−9** (White
annihilates). If `lo` were a true lower bound, Black's max-`lo` strategy would
guarantee ≥ +3 against *any* opponent; reaching −9 means **`lo` was not a lower
bound at the leaking position** — i.e. either C3 is false on 3×3, or the 3×3
`lo` fixpoint is mis-computed, or the E2 policy has a 3×3-specific bug.

**Why this is consistent with the pattern, not a fluke:** 2×2 and 3×2 are the
two boards with **exhaustive ground truth** (every value checked vs the exact
solver); 3×3 is only anchor+symmetry+spot-checked. So a `lo` defect or a genuine
bound failure could first appear at 3×3. Also recall E1: single-score
divergences appeared at 3×2/3×3 but not 2×2 — 2×2 is the "cleanest" board.

**A theoretical reason C3 might actually be false (the user's worry, realized):
the lo fixpoint models "a cycle resolves worst-for-Black" (a *score* assigned
to a repeat), but PSK models "a repeat is *illegal* (the move is *removed*).**
These are different: removing a *good* move (PSK ban) can lower Black's value
below the lo fixpoint, which only pessimises the *cycle* moves, not the removal
of the best move. So `lo` may be an *upper* bound on the real PSK value in some
positions, not a lower bound. The 3×3 leak fits this failure mode exactly.

**What is NOT yet established:** whether the 3×3 leak is (a) a genuine C3
failure (the bracket does not bound real PSK values — a foundation-level
crisis), (b) a `lo`-computation bug on 3×3 (the converge is wrong on
ko-sensitive positions, undetected by the anchor battery which only checks
where lo==hi), or (c) an E2 policy/PSK-history bug. The binary prints "C3
falsified" — that label is **provisional** pending the cross-check below.

**E3 — the decisive cross-check (next):** on each 3×3 leak, dump the position
`P` where the promise was made, its `lo[P,B]` / `hi[P,B]`, and the actual ban
set; then run the **exact history-aware solver** (`Exact`) on `P` with that ban
set to get the TRUE real-history value. (3×3 from a mid/late position with a
specific ban set is likely tractable, unlike the empty board.)
- `true < lo` ⇒ C3 is genuinely false on 3×3 (or `lo` mis-computed; the exact
  solver is the ground truth, so `true` is authoritative) → the bracket is not a
  sound bound → foundation crisis confirmed.
- `true ≥ lo` but self-play reached less ⇒ E2 player/policy bug (the max-`lo`
  strategy failed to secure its own floor) → fix E2, not the theory.
This resolves (a) vs (c); (b) is implicated iff `true` disagrees with a
correct-by-construction `lo` (needs the C2/C3 theorem question settled first).

**`TODO`:** implement E3 (dump + exact-solver cross-check on the 3×3 leaks).

## Status after E2

- 2×2/3×2: range-aware player is leak-free on 4000 games each → C3 *supported*
  (not proven) there. The fresh-start player's leak on those boards is a
  *player-policy* problem (using fresh-start values), NOT a bound failure.
- 3×3: **unresolved leak** — the bracket may be unsound as a real-game bound.
  This is the live crisis. Nothing downstream (single-number oracle, 5×5)
  should be trusted until E3 resolves it.

## E2 policy sanity check (2026-07-25) — policy bug RULED OUT

**User framing (recorded):** 2×2 is the "hello world" of this project — it
tests wiring, not the game of Go. So zero-leak on 2×2/3×2 alone is weak; the
*policy itself* had to be checked independently of any game-theoretic value.

**Method:** `RETRO_E2SANITY` runs the **same** range-aware self-play policy but
feeds it **trivially-valid bounds**: `lo = -N`, `hi = +N` for every legal
position (no `converge`, no Go knowledge beyond "every area score lies in
[-N, N]"). A correct range-aware policy MUST be leak-free here, because the
promised floor is `-N` (Black) / ceiling `+N` (White) and the real score is
always inside `[-N, N]`. Any leak would be a pure policy/wiring bug.

**Result:**

| board | leaks (trivial bounds) |
|---|---|
| 2×2 | **0** |
| 3×2 | **0** |
| 3×3 | **0** |

**Conclusion:** the E2 policy is correctly wired — move selection, promise
tracking (max for Black / min for White), bound-per-side (Black `lo` / White
`hi`), PSK-legality filtering, and the leak comparison all behave correctly.
This **rules out possibility (c)** in the E2 findings (an E2 policy/PSK-history
bug). The 3×3 leak therefore comes from the **bounds** themselves, not the
policy: either (a) a genuine C3 failure (the bracket is not a sound real-game
bound) or (b) the `lo` fixpoint is mis-computed on 3×3 — both are about the
bound, and **E3 (exact-solver cross-check)** resolves them. The real-E2
regression is unchanged after the revert (2×2/3×2 zero, 3×3 25 leaks).

(Rebuild: `ZIG_GLOBAL_CACHE_DIR=/tmp/weizigo-zigcache ZIG_LOCAL_CACHE_DIR=/tmp/weizigo-zigcache zig build-exe -O ReleaseFast src/retro.zig -femit-bin=retro-e2`; run `RETRO_E2SANITY=1 ./retro-e2` or `RETRO_E2=1 ./retro-e2`.)

## E3 findings (2026-07-25) — exact-solver cross-check + PSK-legality

**Experiment:** on a leaking 3×3 self-play game, (i) replay the whole game and
verify every move was PSK-legal (no child recreated a prior board) — this
rules out a self-play/PSK mechanics bug that the trivial-bounds sanity check
could NOT detect (trivial bounds `−N` can never be violated, so they cannot
catch a PSK bug); (ii) walk the self-play line and, at each position, compare
the table's `lo` (claimed lower bound) to the TRUE value from the exact
history-aware PSK solver with the actual ban set. `true < lo` ⇒ the bracket is
not a sound real-game bound (C3 false) OR `lo` is mis-computed.

**Run:** `RETRO_E2=1 ./retro-e2` (first leaking 3×3 game analysed: seed 120,
audited B, promise 3, final −9, 17 plies).

### PROVEN: the leaking game is a VALID PSK game
`PSK-legality: 0 illegal moves in 17 plies -> VALID PSK game.` The self-play
`seen` filter and the independent bitset replay agree: no move recreated a
prior board. **This rules out the "self-play/PSK mechanics bug" possibility**
(the one the trivial-bounds sanity check could not detect). The leak is not an
invalid game.

### PROVEN (structure): `lo` drops along a valid PSK line
Walking the line, the table's `lo` per ply:
- plies 2–8: `lo=3, hi=9` (ko-sensitive, bracket [3,9])
- plies 9–10: `lo=−9, hi=−2` (bracket [−9,−2])
- plies 11–16: `lo=−9, hi=−9` (single-score, value −9)
- root (empty 3×3): `lo=2, hi=9` (bracket [2,9], from RETRO_BRACKET)
- final score: −9 (White annihilates Black)

So a **valid PSK game from the empty 3×3 board reaches −9**, while the table's
root lower bound is `lo=2`. The `lo` value itself collapses from 3 → −9 as the
line advances (the +3 continuations become PSK-illegal and drop out).

### INCONCLUSIVE: direct `true < lo` at the critical plies (intractable)
The exact solver exceeded a 2 000 000-node budget at **every** critical ply
(2–15); only the final ply (16) was tractable: `true=−9, lo=−9` → ok (no
violation there). This is the **known 3×3-exact wall**: 3×3 with few stones is
a huge tree even with a ban set, so the positions where the violation would
appear (early, few stones) are exactly the ones we cannot solve exactly.
**Catch-22:** the leaks occur on 3×3 (intractable to verify); the tractable
boards (2×2/3×2) do not leak. So a *direct* `true < lo` confirmation is not
available with the exact solver.

### NARROWED AMBIGUITY (the survivors)
PSK-mechanics (E3) and policy-wiring (E2-sanity) are both ruled out. The 3×3
leak therefore means: the range-aware player (max-`lo`) reached −9 from a root
whose table `lo=2`. **If `lo=2` were a true real-game lower bound, max-`lo`
would guarantee ≥ 2** (maximin against any opponent). It reached −9. So `lo` is
**not** a true real-game lower bound. Two survivors remain:

- **(a) C3 is genuinely FALSE** — the least-fixpoint `lo` does NOT bound real
  PSK-game values. Predicted by the semantics gap: the `lo` fixpoint models "a
  cycle *resolves* worst-for-Black" (a *score*), but PSK models "a repeat is
  *illegal* (the move is *removed*)". Removing a *good* move can push the real
  value below `lo`, which only pessimises *cycle* moves. The 3×3 leak fits this
  failure mode exactly (the +3 line becomes PSK-illegal → Black is forced to
  −9).
- **(b) a `lo`-computation (converge) bug** — `lo=2` was computed but the true
  least-fixpoint is ≤ −9.

**Why (a) is favored (not yet proof):**
- `lo=2` IS a genuine fixpoint — `converge` iterates monotonically from `−N`
  and stops at zero changes (the least fixpoint). So (b) would require a
  converge *implementation* error, not merely a wrong fixpoint.
- The cycle-pessimism-vs-PSK-move-removal gap *predicts* (a) a priori.
- 2×2/3×2 (tractable, exhaustively ground-truthed) do NOT leak under the
  range-aware player → C3 holds there (on explored lines); C3 failing first at
  3×3 (where ko tangles deepen) is consistent with (a), not with a random
  converge bug.

### IMPLICATION if (a) is confirmed
The L/H bracket is a valid **fresh-start fixpoint** but **NOT a sound real-game
bound under PSK**: the bracket [2,9] for empty 3×3 does not contain the real-
game value (−9 lies below the lower bound 2). This would be a **foundation-
level result** — the bracket methodology, the project's main claimed *sound*
deliverable (the "certified core + bracket"), does not bound real games. The
certified core (where `lo==hi`) may still be sound (a position whose value is
history-independent is unaffected), but the *bracket* for the ko-sensitive
region would be unsound as a real-game bound.

### NOT YET PROVEN (honesty)
No direct `true < lo` at a specific position (intractable). The conclusion is
an **inference**: (valid PSK game reaching −9) + (root `lo=2`) + (max-`lo`
reached −9) + (`lo` is a genuine fixpoint) ⇒ `lo` is not a true real-game lower
bound ⇒ C3 false or converge-bug, with (a) favored.

### NEXT (to remove the (a)-vs-(b) ambiguity) — `TODO`
1. **Verify `lo=2` is the true least fixpoint independently** — e.g. check the
   fixpoint equation `lo[P] = max_m lo[child]` holds at the empty board AND
   confirm no lower fixpoint exists (a second converge from a different start,
   or a hand argument). If `lo=2` is the true least fixpoint, (b) is ruled out
   ⇒ (a) C3 false is confirmed.
2. **Find a leaking game whose critical ply is exactly solvable** — the `−2`
   leaks (final −2, not −9) may transition at a deeper, more-stone, tractable
   ply; raise the budget and analyse one. A single `true < lo` would be
   decisive direct proof of (a).
3. If (a) holds: re-frame the deliverable — the *certified core* (`lo==hi`,
   history-free) may remain sound; the *bracket* does not bound real games.
   This reopens the live-play question (a range-aware player on an unsound
   bracket is not actually sound).

## B1 + audit RESOLUTION (2026-07-25) — (b) RULED OUT; (a) stands

**B1** (Minimax `RETRO_B1_LOFIX` probe) + **Kimi independent audit**
(`untracked/T02-audit-kimi.md`): on 2×2 / 3×2 / 3×3 the canonical `lo` IS the
**least fixpoint** of the L map — V0 AND V1 Bellman equations hold (zero
violations), the canonical was produced by monotone iteration from the lattice
bottom `−N`, and the map is entrywise monotone (Knaster–Tarski). Therefore:

- **(b) converge-bug is RULED OUT** on 2×2/3×2/3×3. `converge` is not buggy;
  `lo=2` (empty 3×3) is the true least fixpoint.
- **(a′) "canonical isn't the least" is UNSOUND** (Kimi Blocker). Re-converge
  from `+N` lands above canonical because it reaches the **greatest** fixpoint,
  which sits **above** the least by definition when the map is multi-fixpointed
  — the expected normal case, not a refutation of least-ness. Discarded.
- Minimax's `(a′)` / "B2 enumerate all fixpoints" recommendation is superseded.

**So the leak-crisis survivor is (a): C3 is genuinely FALSE.** The L fixpoint is
a valid *fresh-start* fixpoint but does **not bound real-game PSK values**.
E2 already showed a valid PSK game on 3×3 reaches `−9` while `lo=2` at the root;
B1 confirms `lo=2` is the true least fixpoint — so the fixpoint itself
genuinely undershoots the real-game value. The **bracket `[L,H]` is unsound as
a real-game bound.**

**Consequences (load-bearing):**
- The **range-aware player (promise `lo`) is NOT leak-free** — E2 leaks on 3×3
  because `lo` is not a real-game lower bound. It is **not** a sound live-play
  fix. (The earlier "range-aware player = sound resolution" idea is FALSE.)
- The **fresh-start player leaks** (E1/arena) — unchanged.
- The **only candidate sound shippable thing is the certified core (`lo==hi`,
  history-free)** — and that is sound **only if C2 holds** (single-score
  positions are genuinely history-independent). C2 is still **CLAIMED, not
  proven** (E1 was consistent but confounded; it is not a proof). **C2 is now
  the load-bearing unproven claim for the whole project's sound deliverable.**

**Next (to decide with the user — topic B):**
- **C2-probe** (highest value): prove/falsify that single-score positions are
  history-independent on the tractable boards (2×2/3×2) — i.e. for a
  `lo==hi` position, the exact solver returns the same value under many
  different ban sets. If C2 holds, the certified core is sound and shippable
  (the one honest deliverable). If C2 fails, even the core is unsound.
- **E3-2** (direct `true < lo` at a tractable critical ply) — catch-22'd (3×3
  leaks are intractable; 2×2/3×2 don't leak); lower priority now that (a) is
  well-supported by E2+B1.
- **Re-frame the deliverable**: core-only artifact (contingent on C2) + an
  explicit statement that the bracket/ko-sensitive region is unsound as a
  real-game bound (so no single-number residue, no sound range-aware player).

**Audit must-fix (deferred to a doc-hygiene pass; Kimi flagged):** retract
"inconclusive (b)"/"(a′)" in `untracked/T02-minimax.md` (Minimax's file —
Minimax to correct on next relay) and `CURRENT.md` (done here); correct
`b1-spec.md §3` (the `+N`/`-N+1` re-converge tests *multiple fixpoints*, not
least-ness). Plus the `untracked/doc-hygiene.md` backlog (AGENTS.md overclaim,
broken RISKS.md link, README numbering, GLOSSARY typo, stale HANDOVER).
