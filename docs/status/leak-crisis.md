# The leak crisis

**Status (2026-07-26: T13 falsified C2 at 3×2.)** The (a)/(b) axis is
resolved. C2 — the last load-bearing claim — is now **false** at the smallest
board where a non-trivial PSK history exists. Condensed from the long
E1/E2/E3/T13 narrative;
history is in git. The active follow-up is the **C2-probe** (see §"Next").

## What "leak" means

At each position where the audited player is to move, the table's stored
fresh-start score is treated as a **promise**. If the game's final score
falls short of the *strongest* promise made anywhere in that game, that
game **leaks** (`research/arena-audit.md`). This measures a critical error
in the player's reasoning (or in the table — we now separate the claims).

## The claims, separated

The leak is consistent with several distinct failures; we name them so we
can test each.

| # | claim | status | how to prove / falsify |
|---|---|---|---|
| C1 | Fresh-start scores correct as fresh-start scores (2×2, 3×2) | **PROVEN** (vs history-aware exact solver) | already done |
| C2 | Single-score (L==H) positions are history-independent | **FALSE-AS-SCOPED at 3×2** (falsified by T13; see below) | T13 `untracked/T13-minimax.md` |
| C3 | The range `[L,H]` bounds the real-game score for any history, any cycle rule in [−n,n] | **CLAIMED, falsified at 3×3** | E2 (below): 3×3 leaks with promise +3 → final −9 |
| C4 | Fresh-start score == real-game score | **FALSE** for *both* regions. Ko-sensitive: false by the leak. Single-score: false because C2 is falsified at 3×2 (T13) — fresh-start ≠ real-game even where L==H. | consequence of C2 + T13 |

The overclaim: "proven core" was being used as if it meant "proven final
game score" when it meant "proven fresh-start score." C2 and C3 — the
claims that would actually let us call something a proven final score or
a true range — were not established. C2 is falsified; the certified-core framing is dead. The honest deliverable is **the fresh-start score table + the `[L,H]` bracket, both labelled as *fresh-start* properties**, with the explicit non-promise that neither equals nor bounds the real-game PSK score (C2 false at 3×2; C3 false at 3×3). C1 (fresh-start correctness) is the only proven claim about the table's content.

## Resolution of the (a)/(b) axis

E2 found 3×3 leaks (25/4000 games: promise +3 → final −9, 12-pt leak).
Three failure modes were possible:

- **(a) C3 is genuinely false** — the L fixpoint does not bound real PSK
  scores because the fixpoint pessimises cycle *resolutions* (scoring
  repeats) while PSK *removes* the move; removing a good move can push
  the real score below the fixpoint.
- **(b) `converge` is mis-computed** — `lo=2` is not the true least fixpoint
  on 3×3.
- **(c) E2 player/PSK-mechanics bug.**

**Ruled out by E2 sanity (trivial bounds):** (c). The same range-aware
policy with `lo=−N, hi=+N` is leak-free on 2×2/3×2/3×3 — move selection,
promise tracking, PSK legality, and the leak comparison are all wired
correctly. (Caveat: trivial bounds cannot catch a PSK-mechanics bug; that
needed E3.)

**Ruled out by E3 (PSK-legality replay):** the 3×3 leaking game is a VALID
PSK game (0 illegal moves in 17 plies). The leak is not an invalid game.

**Ruled out by B1 + Kimi audit (least-fixpoint):** on 2×2/3×2/3×3 the
canonical `lo` IS the true least fixpoint of the L map (V0 AND V1 Bellman
equations hold, zero violations; canonical produced by monotone iteration
from `−N`; the L map is entrywise monotone → Knaster–Tarski). `converge`
is not buggy. The re-converge-from-`+N` tests *multiple fixpoints*, not
least-ness — that variation (a′) is unsound; discarded.

**Survivor: (a) C3 false on 3×3.** The bracket [2,9] for empty 3×3 does
NOT contain the real-game score (−9 lies below the lower bound 2). The
range-aware player is therefore NOT leak-free. The only candidate sound
deliverable is the **certified core (`lo==hi`)**, contingent on C2.

## E2 findings (the decisive leak)

| board | games | leaks (range-aware) | leaks (trivial bounds sanity) | verdict |
|---|---|---|---|---|
| 2×2 | 4000 | 0 | 0 | C3 supported on explored lines |
| 3×2 | 4000 | 0 | 0 | C3 supported on explored lines |
| 3×3 | 4000 | **25** (promise +3 → final −9; some −2) | 0 | **C3 falsified** (or lo bug — but B1 ruled that out) |

The 3×3 leak signature: audited B, promise +3 (from root lo=2 path), final
−9 (White annihilates). The +3 line becomes PSK-illegal as the game
proceeds; Black is forced into −9. Exactly the cycle-pessimism-vs-PSK-
move-removal gap the semantics predicts.

E2 policy correctness (recorded): Black maximizes `lo[child]`; White
minimizes `hi[child]`. The first run used `lo` for both colours — wrong
for White (minimizer secures its ceiling `hi`, not its floor `lo`). Fixed.

## B1 findings (least-fixpoint, ruled out (b))

B1 (Minimax `RETRO_B1_LOFIX` probe, plus Kimi independent audit) on
2×2/3×2/3×3:

- **Fixpoint equation holds (zero violations)**: V0 and V1 Bellman
  equations hold at every legal non-settled (i, side) on all three boards.
  The canonical `converge` is producing a true fixpoint of the L map.
- **Re-converge from `−N+1` lands ABOVE canonical** on all three boards
  (2×2: −3 vs −4 canonical; 3×2: −5 vs −6; 3×3: +2 vs +2 — equal).
  Re-converge from `+N` lands further above (2×2: +4; 3×2: +6; 3×3: +9).
  Both re-converges report zero-change — they reach genuine fixpoints, not
  "didn't converge yet." Interpretation: the L map has multiple fixpoints
  (Gauss-Seidel — the map reads oppV0, updated in the same sweep);
  canonical IS a fixpoint, but not the *least* under re-converge-from-`+N`.
- **Knaster–Tarski applies**: monotone-from-`−N` iteration IS the least
  fixpoint. Canonical is least. → (b) ruled out.

Audit details: `untracked/T02-minimax.md` (results) and
`untracked/T02-audit-kimi.md` (Kimi audit convicting the (a′) variation).

## T13 findings (2026-07-26)

The C2-probe ran on 3×2 (`untracked/T13-minimax.md`). 3×2 is the smallest
board that admits reachable non-trivial PSK histories. Result:

- **508 non-trivial histories** tested on L==H positions.
- **12 verified mismatches** between the stored L==H score and the
  history-aware alpha-beta score (memo=false, brackets=false).
- Fresh-start sanity check on all 540 L==H slots: **0 mismatches**,
  confirming the solver setup is sound.
- Example mismatch: position idx=314, Black to move, fresh-start score +6,
  score after history `[0,2,26,40,110,278,57,154,314]` is −6.

**Verdict: C2 is falsified at 3×2.** The single-score region is correct as
fresh-start scores (C1), but it is **not** history-independent.

## C2 — the load-bearing claim, collapsed (falsified 2026-07-26)

C2 was the only claim whose truth was required for the project to have a sound shippable deliverable. T13 falsified it at 3×2. The fresh-start single-score region was the candidate; the range-aware player is NOT sound (E2); the fresh-start player is NOT sound (E1/arena). The core's soundness reduced to C2, and C2 is now false.

**What the C2-probe did** (highest value, next):
- Pick a sample of `lo==hi` positions on 2×2/3×2 (tractable, exact solvable).
- For each: run the history-aware exact solver with several different ban
  sets (e.g. empty history, history = [this position], history = [position
  + N other positions]).
- If ALL return the stored score: C2 supported at the sample (necessary,
  not sufficient; bound by sample).
- If ANY returns a different score: C2 falsified → even the core is unsound
  → no sound shippable deliverable.

Open questions:
- C2 is CLAIMED, not a theorem. If it isn't either proven (E1/C2-probe)
  or made a theorem, every shippable artifact carries an unverified
  assumption.
- A theorem would need a lattice argument: e.g. prove that for `lo==hi`
  positions, the lattice `L` and `H` bounds collapse to a single
  history-independent score. (Unbuilt.)

## Next (requires user decision)

> **Reframed by B05 (`untracked/B05-glm.md` subtask 2):** fresh-start exact
> score oracle + CLAIMED `[L,H]` bracket, explicit non-promise re real-game
> PSK. Pending user sign-off on UD-1/UD-2/UD-3 (see B05 subtask 2).

1. **Reframe the deliverable** (default, scoped by B05): accept that the table scores are
   **fresh-start scores only** (C1). The honest shippable is a fresh-start
   oracle + an honest `[L,H]` bracket labelled CLAIMED (not proven). The
   "certified core" cannot be called history-independent or real-game
   correct; it is fresh-start correct only.
2. **Investigate weaker properties**: is there a restricted class of
   histories under which L==H positions are stable? Is there a different
   cycle rule (e.g., basic ko with bounded history) where C2 holds?
3. **Continue the 4×4 work only under the reframing**: T14.2/T14.3 and the
   KM-dependency track are still valid as infrastructure for fresh-start
   tables, but they no longer validate a "proven real-game core.

## Lessons (for the doc-as-epistemic-tree method)

- **E1 was confounded**: as first written, E1 read the fresh-start child's
  fresh-start score, which is not the true real-history score. So E1 is a
  diagnostic of *where the fresh-start plan breaks*, not a falsifier of C2.
  The decisive experiment turned out to be E2 (range-aware outcome check).
- **"Sound by construction" needs a falsifiable auditor**: the `ko_ref >= d`
  guard looked sound and was unsound (3×2: 45/378 violations). The #2
  auditor (parent's score vs best independent child under same history)
  is the standing gate. A claim without an auditor run is INSUFFICIENT.
- **The semantics gap (lo pessimises *cycle resolutions*; PSK *removes
  the move*) is a structural reason C3 might be false**, not an
  implementation accident. (a) is favored a priori, not as a fluke finding.

## Pointer index

- E1/E2/E3 full narrative + the bug-fix history: git commits (the
  "epistemic reset" series; 2026-07-25).
- B1 results: `untracked/T02-minimax.md`; Kimi audit: `untracked/T02-audit-kimi.md`.
- C2-probe design: `untracked/plan4x4-master.md` (B5/C2), `../epistemic/boards/4x4/EPISTEMIC.md`.
- Names propagation: `../epistemic/names.md`.
- Per-claim status: `../epistemic/boards/4x4/EPISTEMIC.md` (4×4 is the focus;
  C2/C3 status is *claimed*, not *proven*, at every size).
