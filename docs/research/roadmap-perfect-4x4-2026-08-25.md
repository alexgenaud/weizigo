# A roadmap to a compressed, provable 4×4 — the reasoning, not a plan of record

**Status: A roadmap, not THE roadmap.** Written 2026-08-25 by the orchestration seat at the
operator's request, to preserve a chain of conditional reasoning worked out in conversation before
it is lost. Most of what follows is *"if this holds, then that might hold"*. **Nothing below is a
ratified commitment and several links are explicitly unproven.** Where a step's premise fails, the
branch it leads to is abandoned, and that is the point of writing it down: the shape of the tree
matters more than the path we currently favour.

The operator's framing: *"It contains several 'if this is true then this might be true then
maybe...' as A ROADMAP. Not 'THE' single roadmap."*

---

## 0. Where we actually stand — established facts, each with its source

These are not conjecture. They bound everything downstream.

| fact | source |
|---|---|
| The 4×4 table has **99,133,036** entries; **95,677,624 are KO_SENSITIVE-clear** and **3,455,412 (3.5%) are ko-sensitive** | `docs/epistemic/CLAIMS.md` `4x4.FP1`, `4x4.C1` |
| On the clear region the **Bellman residual is 0 / 95,677,624** | same |
| Two independent methods agree on **every non-KO_SENSITIVE slot resolvable — 4,212 slots, 0 disagreements**, status PROVEN | `GLOBAL.ADR0006-TEST` |
| The writes-on finisher is recorded **FALSE-AS-SCOPED** — a *method* claim that is false, not merely unproven | `GLOBAL.F1` |
| The committed 4×4 and 4×3 artifacts were produced by that same writes-on path | `4x4.F1`, `4x3.F1` |
| At 3×2, **62 of 378** ko-sensitive (slot,side) pairs differ between writes-off and the committed table | `docs/research/arena-audit.md` |
| Root brackets: 2×2 `[−4,+4]`, 3×2 `[−6,+6]`, 3×3 `[+9,+9]`, 4×3 `[+4,+12]`, **4×4 `[+1,+16]`** | `docs/research/force-life-classifier-2026-08-06.md` |
| Every committed artifact is **`rules_id=3` — Chinese area, komi 0, basic ko, L/H bracket** | the oracle's own header |
| "Area score on an odd-point goban is always odd" is **false** — witness: 3×3, B a1 / W c3, rest empty, **scores 0**, because area scoring admits neutral regions | `docs/research/qa023-basicko-markovian-2026-07-28.md` §1.4, PROVEN |

**Two readings that follow immediately, and are worth stating because a summary got them wrong once:**

- **The doubt is narrow.** 96.5% of the table sits where independent methods agree perfectly and
  the fixpoint check is exact. Even inside the ko-sensitive region, the 3×2 measurement leaves 84%
  of it undisputed. *"The table is untrustworthy"* overstates it considerably.
- **The 4×4 root is a bracket, not a value.** `[+1,+16]`. Whatever else is true, we do not today
  possess a single number for the starting position.

---

## 1. The branch point: which generator is trustworthy? (waypoint 1)

Everything downstream assumes we know which of two disagreeing methods to believe. **We do not.**
The arena audit is explicit: *"at least two of the three methods are wrong on these slots, and
possibly all three… We CANNOT yet name the true score."* It is equally explicit that writes-off is
not automatically the winner — it *"still ASSUMES the L/H brackets and the certified seeds are
sound and that its own search logic is correct."*

**Waypoint 1** adjudicates the 62 disputed 3×2 pairs against the **history-exact** solver, which
keeps real superko history instead of a position-keyed memo and therefore does not share the
graph-history defect either generator might have. 3×2 is a six-point board; this is cheap.

Three outcomes, three different futures:

- **Writes-off wins** → Track A's premise holds → §2.
- **The committed table wins** → Track A as specified is the wrong plan, *and the existing
  artifacts are better than feared*. A good outcome that costs us a plan.
- **Both are wrong on any pair** → the L/H brackets or the certified seeds are unsound. Those sit
  *beneath* both generators, so this would invalidate far more than the 62. **Stop and re-found.**

**The risk inside waypoint 1:** history-exact ground truth exists on only **68 of 600 roots** at
3×2. If the overlap with the 62 is small, the adjudication is underpowered. Extending the
history-exact run at 3×2 is in scope. And the judge must be calibrated first — if it disagrees on
slots where the two generators *agree*, its verdicts on the disputed ones are worthless.

---

## 2. If writes-off is trustworthy — Track A

**"Memo writes off" means: stop writing search results into the transposition table.** The defect
is graph-history interaction: under superko a position's value depends on which earlier positions
are banned along the path that reached it, so a memo keyed on position alone stores a value
computed under one history and reuses it under another. ADR-0013: *"The entry, written as
history-free, is then reused where history matters."* With writes off, the only memo entries are
certified history-free seeds, and the search is plain bracket-guided alpha-beta over the real
superko history.

The cost is that writes-off forfeits the within-search bounds reuse that made the MTD probes
incremental — so **4×4 tractability under writes-off is itself unknown.** That is `4x4.D3`,
UNTESTED, and the register ranks it **#1 by dependents (7)**. It is a *measurement*, not a truth
claim.

- **Tractable** → regenerate 2×2…4×3 first (cheap, and any disagreement there indicts the method
  before 4×4 compute), then 4×4, gated on: zero auditor violations, bracket containment,
  exhaustive symmetry, published-anchor agreement, zero arena leaks.
- **Not tractable** → ADR-0013 already says what happens: *"Track B becomes blocking rather than a
  follow-up."* Track B is sound cross-branch reuse via dependency fingerprints (Kishimoto–Müller),
  and it is already implemented.

---

## 3. If a trusted score table exists — is it position-indexable?

This is the question the operator's goal actually turns on: *"a SINGLE provable score for every
legal position."*

Under positional superko a game cannot repeat, so it terminates, so **every (position, history)
pair has a single definite value.** That much is certain. But our table is indexed by *position*,
and in the ko-sensitive region the value may depend on history — two arrivals at the same position
under different ban sets can differ. No single number can then live at that index.

So the goal is reachable with an amendment: **a single provable score for every legal position
plus enough ko state to make it well-defined.** For 96.5% the position alone appears to suffice.
The open research question — tractable at 3×2 and 4×3 — is **what the minimal sufficient ko state
is** for the rest. If it is a few bits, a single indexed table remains possible.

**A caution recorded against the seat's own earlier reading:** the `[−4,+4]` root bracket at 2×2 is
labelled "(draw)" in the source, and the seat previously described it as a draw-by-loop *game
value*. That was an over-reading. L and H are the least and greatest fixpoints of a
**position-indexed** value function; `L ≠ H` marks where that indexing fails to determine a value.
The bracket is an epistemic bound. Whether the underlying game is genuinely drawn there is a
separate question this document does not settle.

---

## 4. If the score table is trusted — the compressed tables

Two derivations, neither requiring a re-solve:

- **Score table.** 33 values on 4×4 (`−16…+16`) → **log₂33 = 5.04 bits**, against 8 today.
- **WLD table.** Three values → **log₂3 = 1.585 bits**; five trits pack into a byte (3⁵ = 243 ≤ 256)
  for **1.6 bits/position**.
- **Komi 0.5 → exclusive win/loss, 1 bit.** The operator's point, and it is correct: since scores
  are integers, adding 0.5 to White makes a tie impossible, and **this is a pure relabelling of the
  komi-0 table — `win if score > 0` — not a different solve.** The komi-0 table stays the ground
  truth and the diff-against-committed validation survives intact. (An earlier seat objection that
  this "changes the game" applied only to *re-solving* under komi, and was withdrawn.)

**Symmetry** is a separate axis: D4 gives up to 8× on a square board, colour inversion another 2×
but it *negates the score* and interacts with ko state, so the ×2 is not free. Orbit reduction is
not unexplored here — `2x2.EXACT` records 9 orbit representatives expanding to 82 slots.

**These derivations are only meaningful after §2.** Compressing an unverified table yields a
smaller unverified table.

---

## 5. If both tables exist — the differential experiment

The operator's design, and it is the project's own doctrine that redundant implementations are
mutual oracles rather than waste.

Play the margin-knowing engine against the win/loss-only engine. Both should win every game they
enter from a winning position; only one knows by how much.

- **Falsifiable, direction 1:** the margin engine's predicted final score must equal the played
  result **exactly**, every game.
- **Falsifiable, direction 2:** the WLD engine must never lose a game it entered at `+1`.
- **Expected and not a bug:** the two engines choosing *different moves*. Margin-maximising and
  any-winning-move are different policies over the same value set.
- **A bug:** any divergence in *outcome*.

**Where it will be interesting:** exactly the ko-sensitive region. "Play any winning move and you
still win" holds for outcomes, but a randomly chosen winning move can walk into a repetition if the
WLD table is history-blind — the same GHI issue as §3. The experiment is therefore also a probe of
whether the compression preserved what §3 established.

Infrastructure partly exists: `bin/weizigo-engine-vs-engine`, `bin/weizigo-arena`, `bin/weizigo-gtp`.

---

## 6. What this roadmap does not know

Recorded so a later reader does not mistake confidence for evidence:

1. Whether the history-exact solver's 3×2 coverage is sufficient to adjudicate the 62.
2. Whether writes-off is tractable at 4×4 — the single gate on the whole of §2.
3. Whether `L ≠ H` regions correspond to genuinely drawn games or merely to a failure of position
   indexing (§3).
4. What the minimal sufficient ko state is, or whether it is small enough to be worth having.
5. Whether the L/H brackets and certified seeds — assumed by *every* generator discussed here —
   are themselves sound. Waypoint 1 is the first thing that could disturb this, and if it does,
   most of the tree above is void.

**The honest summary of the whole chain:** step 1 is cheap, decisive, and can invalidate everything
after it. That is why it goes first.
