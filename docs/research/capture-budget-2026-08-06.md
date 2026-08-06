# The capture budget: does bounding total captures make the game finite, and at what cost?

**Task: T387 · Role: worker · Model: flash (dispatch line `flash/T387`) · Date: 2026-08-06**
**Set: M · Landmark: advances `L2 (proven 4×4 values)` by establishing whether the capture-budget
rule is a viable foundation for a single-score table.**

**Row history (must be stated):** T387 was closed as failed under D054 (a `u6` loop counter hung
the value mode for 14 h; the Orchestrator's diagnosis was correct). The fix, the red-then-green
control, and the full measurement set were completed on the follow-up row **flash/T397**, which
the Orchestrator explicitly offered. The numbers below are all from the fixed binary
(`src/t387_budget.zig`, sha `5dbfd551`). The DAG half was already credited to T387 by the
Orchestrator (`findings/T387-capture-budget-dag.json`); the rest is reported here.

**This is a ruleset investigation, not a ruleset change.** No engine, artifact, or axiom was
edited; any budget defines a new game and must be declared as one (the MIGOS `+2` epitaph) — the
Orchestrator rules. Measurement instrument only: `src/t387_budget.zig` (additive).

---

## 0. The premise, corrected (as the brief demanded)

The operator's framing was that a game can cycle *without* returning to exactly the same goban.
It cannot: the goban has finitely many positions (3^16 at 4×4), so by pigeonhole any infinite
play must revisit positions infinitely often. The cycles are repetitions. Basic ko permits
repetition that is not immediate (take, play elsewhere, retake) and longer capture-exchange
loops (T382 witnessed the basic-ko-legal 7-state cycle at 2×2, reproduced in §7). Infinite play
is always repetition; the ruleset question is only which repetitions to forbid.

That strengthens the proposal: a capture budget is not competing with an exotic infinity, only
with a class of loops.

## 1. The termination argument — VERIFIED, and strengthened to a theorem

The brief's sketch: if total captures are bounded by `B`, then after `B` captures no capture is
legal; from there stones are only added, the goban strictly fills, and the game terminates. The
suspicious step was "stones are only added" (passes, suicide, forced-pass positions).

**The strengthened claim (machine-verified): the budget-augmented game graph is a DAG — no
directed cycles at all.** Proof sketch: the budget is monotone non-decreasing along every play
(captures increase it, everything else leaves it), so a directed cycle would need constant
budget; on a constant-budget cycle no capture occurs, so placements strictly increase the stone
count and the goban can never repeat — no placement lies on the cycle; a pass-only cycle hits
`passes=2` and terminates. Hence every play terminates from *every* state, and **L == H
everywhere** — the bracket collapses structurally, with no fixpoint ambiguity and no finisher.

Machine check (back-edges counted by a status-on-stack DFS over the whole closure; denominator
= closure size):

| graph | states | back-edges |
|---|---|---|
| 3×3, budget B=8 | 423,922 | **0** |
| 4×3, budget B=8 | 10,636,928 | **0** |
| 3×3, base rules (control) | — | **135,512** (cycles exist without the budget) |
| 4×3, base rules (control) | — | **4,929,916** (cycles exist without the budget) |

(The Orchestrator-saved `135,494` for the 3×3 base graph was the single-root DFS; the re-run
uses the both-roots convention that matches the t386 census exactly. Both are "> 0" — the
seeded control fires.)

**Game length bound:** ≤ 2(N+B)+1 plies (placements ≤ N+B, captures ≤ B, passes ≤ non-pass+1).
Exact longest games measured in §5.

## 2. The state-space cost — cheap, dense addressing preserved

The budget is one small integer counter in the state key: `(board, side, ko, passes, budget)`.

| goban | base reachable | B=0 | B=1 | B=2 | B=3 | B=8 | B=16 |
|---|---|---|---|---|---|---|---|
| 3×3 | 73,758 | 72,990 | — | 138,302 | — | 423,922 | — |
| 4×3 | 1,929,038 | 1,905,570 | — | 3,922,394 | — | 10,636,928 | 25,707,312 |
| 4×4 | 147,638,298 | 145,515,786 | 239,332,920 | 320,070,400 | 403,353,354 | (extrapolated ≈ 6×) | — |

(B=0 is the capture-free subset of the base reachable set, as designed — `B0 ⊂ base` holds at
every size. Base = raw key space reachable from both fresh-start roots, matching the t386
census exactly; the published 98,999,934 (T380 §10.1a) is the table-entry count, a different
measure.)

- **Dense key-space multiplier: exactly (B+1)** — the engine's table grows by exactly this
  factor. At 4×4 the current table is 396.5 MB (99,133,036 entries × 4 B); with the budget in
  the key: **B=8 → 3.57 GB; B=24 → 9.9 GB**.
- **Reachable multiplier** (measured): 4×4 grows roughly linearly — 1.62× at B=1, 2.17× at
  B=2, 2.73× at B=3, with a marginal ≈ 85 M states per extra budget level (≈ 0.64× per unit
  B); 3×3/4×3 at B=8 are ≈ 5.7×/5.5×.
- Against PSK's ban-set explosion (118 M states on the *empty* 2×2, GLOBAL.R1) and the sparse
  window that defeats dense colex (GLOBAL.RPLY-RETRO): the counter preserves dense addressing
  and multiplies the table by a tunable (B+1), not by an unbounded history set.

## 3. The hypothesis test at 3×3 — half true, and the false half is the finding

> **Hypothesis:** a capture budget resolves exactly the bracketed region and leaves the
> determined region unchanged.

**Framing.** For every legal position × side, `V'(p)` = the budget-rule value of the subgame
starting at `p` with the budget untouched (fresh-start semantics — the same comparison class as
T380 Q5). Compared against `data/oracle-3x3-v2.wzo2` fresh-start (L,H). Null gate first: the
t386 engine reproduces the trusted table entry-for-entry — **0 mismatches over 49,428**, 16
sweeps, converged.

| B | L==H moved / 21,126 | L<H inside bracket | L<H outside | root V' |
|---|---|---|---|---|
| 0 | 20,780 (98.4%) | 1,208 | 1,996 | 1 |
| 2 | 16,812 (79.6%) | 888 | 2,316 | 2 |
| 4 | 8,704 (41.2%) | 1,508 | 1,696 | 6 |
| 6 | 4,878 (23.1%) | 1,980 | 1,224 | 9 |
| 8 | 2,298 (10.9%) | 2,364 | 840 | 9 |
| 16 | 592 (2.8%) | 2,756 | 448 | 9 |
| **24** | **0 (0.0%)** | **3,204** | **0** | 9 |
| **32** | **0 (0.0%)** | **3,204** | **0** | 9 |

**Half 1 (true, in the limit): the determined region is preserved.** At B ≥ 24, zero of 21,126
L==H slots move — the budget is non-binding on everything already determined. (At small B it is
massively binding: at B=0, 98.4% move, because B=0 forbids *all* captures, not just cycles.)

**Half 2 (false, and this is the finding): the bracketed region is not resolved — it is
relocated.** Every L<H slot collapses to a single value (the DAG theorem), and for B ≥ 24 all
3,204 land inside the old bracket. But the individual values are **B-dependent and
non-convergent**:

| comparison | slots whose value changed (all at L<H) |
|---|---|
| B=24 vs B=32 | 1,252 (39% of the bracket) |
| B=32 vs B=48 | 1,252 |
| B=48 vs B=64 | 1,648 (51%) |

The budget replaces the honest [L,H] bracket with a number that depends on the arbitrarily
chosen B. The bracket's ambiguity did not vanish; it became B-parametric.

**PSK overlap.** At B=24, `V'` matches the PSK oracle on 22,350/24,330 slots (91.9%); 100% of
the L==H slots match (mismatch 0), but only 1,224 of the 3,204 L<H slots (38.2%) — fewer than
the pinned basic-ko value's 78.8% (T380 Q5). The budget game is genuinely a different game on
the bracketed region.

## 4. The root value curves — where the curve flattens, and where it never does

| B | 0 | 1 | 2 | 3 | 4 | 6 | 8 | 12 | 16 | 24 | 32 | 48 | 64 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 3×3 root V' | 1 | 1 | 2 | 6 | 6 | 9 | 9 | 9 | 9 | 9 | 9 | — | — |
| 4×3 root V' | 1 | 0 | 2 | 0 | 1 | 7 | 12 | 7 | 9 | 7 | 12 | 7 | 9 |

- **3×3**: the root stabilizes at **+9** for B ≥ 6 — and the 3×3 table's own fresh-start
  empty-root entry is L==H==9, so the budget reproduces the determined value exactly.
- **4×3**: the root **oscillates forever** in {0,1,2,7,9,12}. The base bracket is [−1,12] and
  the PSK truth is +4 (RETRO_BRACKET); the budget value never converges and never equals +4.
  "Where the curve flattens is the real answer to what is absurd" — **at 4×3 there is no B at
  which it flattens.** The absurdity is not removed; it is moved into a budget-exhaustion race.

## 5. Capture counts along optimal lines, and the longest games

**Capture counts (root, min/max over optimal lines):**

| B | 3×3 min | 3×3 max | 4×3 min | 4×3 max |
|---|---|---|---|---|
| 8 | 0 | 8 | 0 | 8 |
| 16 | 0 | 16 | 16 | 16 |
| 24 | 0 | 24 | 23 | 24 |
| 48 | — | — | 47 | 48 |
| 64 | — | — | 64 | 64 |

- 3×3: a **zero-capture** optimal line exists at every B ≥ 6 (value +9 without any capture),
  so the budget is never binding on the *value* at 3×3 once B ≥ 6 — but optimal lines using
  every capture count up to B also exist.
- 4×3: **at large B the optimal lines consume the entire budget** (min = max = B at B = 16,
  24, 48, 64). "If optimal play never exceeds K captures then any B > K is non-binding" is
  **false at 4×3** — optimal play's capture count grows with the budget it is given.

**Longest games (exact, budget rule):** 3×3: 18 plies (B=0) → 78 (B=32). 4×3: 24 (B=0) → 146
(B=64).

**What actually happens in the long lines — the operator's picture, confirmed literally.** The
long lines are capture-and-rebuild wars: **White captures 1, Black captures 2, alternating for
tens of plies**, each player rebuilding the stones the other captured. The 4×3 B=64 line runs
the 1,2 rhythm for 85 plies (14–90), then bursts (+4, +2), then double-pass; the final goban
`BBBB/BBBB/BW.B` scores +9 with the budget exhausted 64/64. Boards at the key moments
(4×3, row-major):

```
ply 14 (budget 3):   BBBW    ply 90 (budget 58):  BBBB    ply 91: W captures 4:  BBBB
                     BBW.                         BBWB                          BB.B
                     .WW.                         .WWW                          B...
ply 92: B replays:   BBBB    ply 95: W captures 2: BBBB    ply 98 (terminal):    BBBB
                     BB.B                          BBBB                          BBBB
                     B.W.                          B..B                          BW.B
```

This is exactly "clumping up, filling own eyes, being captured, repeat" — with the budget as
the exhaustible resource that finally ends it. Under the base rules the same positions are
cycles (the 3×3 base graph: 135,512 re-visits in one DFS; the 2×2 T382 7-state
capture-exchange cycle, reproduced in §7).

## 6. The scoring asymmetry — confirmed

- **Chinese area scoring is a function of the final goban alone.** A capture-and-rebuild round
  trip that returns to the same goban is score-neutral by definition — which is precisely why
  the cycling feels absurd: under area scoring it genuinely gains nothing.
- **Japanese territory + prisoners is not a board function.** Prisoners accumulate and are not
  recoverable from the final goban. Demo: the T382 2×2 cycle returns to its start (area −4 →
  −4, neutral; prisoners 3–3, so Japanese −3 → −3 too). The asymmetry appears with net
  prisoners: goban {B@1,B@3} reached via the cycle (2 B prisoners) vs directly (0 prisoners) —
  **area identical (+4), Japanese 4 vs 2, differing by exactly the prisoner count.**

So the operator's intuition is area-specific: it is the area ruleset that makes capture loops
score-neutral and therefore absurd.

## 7. Controls ledger (every instrument, per AGENTS.md)

| control | reading |
|---|---|
| null: base-fixpoint gate | t386 engine vs `data/oracle-3x3-v2.wzo2`: **0 mismatches / 49,428** (16 sweeps, converged) |
| null: minimax identity | recompute-from-children on sampled states: **0 mismatches** — 3×3: 486–14,705 checked per B; 4×3: 12,703–793,619 checked per B |
| null: colour inversion | v(empty, White) == −v(empty, Black) at every B, both gobans |
| null: reach B=0 | B=0 reachable ⊂ base reachable at all three sizes (capture-free subset, as designed) |
| seeded: dag base graph | back-edges 135,512 (3×3) / 4,929,916 (4×3) — the cycle detector fires |
| seeded: planted budget | budget consumed by every placement: 3×3 B=8 root V' 1 vs 9; every hypothesis-sweep row changes — the instrument is sensitive |
| red-then-green (T397) | `zig test -O ReleaseFast src/t387_budget.zig`: u6 planted → the test FAILS loudly (bounded, no hang); u7 → 78/78 pass |
| defect-class sweep | all loops audited for "counter type cannot reach its bound": exactly one instance (the fixed u6); none else |

The T382 2×2 7-state cycle (reproduced): `{W@0} B@1 {W@0,B@1} W@2 {W@0,B@1,W@2} B@3(cap 2)
{B@1,B@3} W@0 {W@0,B@1,B@3} B@2(cap 1) {B@1,B@2,B@3} W@0(cap 3) {W@0}` — basic-ko legal,
PSK-illegal at the final re-creation; the budget rule cuts it like every other cycle.

## 8. Verdict and recommendation

1. **Termination: VERIFIED, and strengthened.** The budget game is a DAG — finite without any
   repetition rule; L == H everywhere; no finisher, no fixpoint ambiguity.
2. **State cost: cheap.** One small integer in the key; dense addressing preserved; table ×
   (B+1) exactly (4×4: 3.57 GB at B=8, 9.9 GB at B=24). This is the cheapest termination
   rule this project has measured — but cheapness is not the question the operator asked.
3. **The hypothesis is HALF true.** The determined region is preserved (3×3: 0/21,126 moved at
   B ≥ 24). The bracketed region collapses to single values *inside the old bracket* — but the
   values are B-dependent and **non-convergent** (39–51% of the 3,204 bracket slots still
   change value between B=24 and B=64; the 4×3 root oscillates {0,1,2,7,9,12} forever, never
   reaching the PSK truth +4).
4. **The operator's absurdity is not removed; it is relocated.** Under the budget rule the
   absurdity becomes a budget-exhaustion race: at 4×3 the optimal lines consume the entire
   budget (min=max=B), and the value depends on exactly how many captures the arbitrary cap
   allows. The bracket was the honest statement that the value is not well-defined; the budget
   replaces it with a well-defined value that depends on an arbitrary knob.
5. **Recommendation (for the Orchestrator to rule):** the capture budget is a legitimate,
   cheaply-solvable *new game* if declared as one — its exact values are computable at 4×4 by a
   straightforward (B+1)×-sized retrograde build — but it does **not** supply the missing
   single scores the operator hoped for at the ko-sensitive positions, and any chosen B is
   arbitrary. As a generation rule for the single-score table it is not recommended; the honest
   deliverable remains the fresh-start single-score region + the [L,H] bracket. As a *play*
   rule that bounds game length it is sound and simple — that half of the operator's instinct
   is correct.

**Landmark:** advances `L2 (proven 4×4 values)` — the capture-budget route to a single-score
table is now costed and ruled out as a resolution mechanism (bracket values are B-arbitrary,
non-convergent), and confirmed cheap as a *termination* rule; what a human can now see that
they could not before is the full cost/benefit table for the operator's idea (DAG theorem +
exact state multipliers + value curves + the capture-war transcripts); what remains is the
Orchestrator's decision on whether the budget's exact-but-B-arbitrary values are acceptable for
any purpose, and the L2 route to single scores stays the fresh-start region + bracket.

— flash/T387 (report completed on flash/T397), 2026-08-06
