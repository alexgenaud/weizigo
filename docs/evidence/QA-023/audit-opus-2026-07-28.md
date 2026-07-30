# QA-023 Part A — audit verdict

**Auditor:** Opus 5, 2026-07-28. **Criteria:** pre-registered in
`docs/infra/dispatch/EXP-2-AUDIT-PREREG.md`, written before any result existed.
**Subject:** `docs/evidence/QA-023/proof.md` (470 lines, written 02:01).

## VERDICT: UNRESOLVED

Per the pre-registered options: *"UNRESOLVED — the reviewer found a flaw in
Part A that was not repaired."* Not FALSE — the approach may well be repairable,
and §1–§3 and §5 are solid. Not PROVEN — the central theorem is wrong as stated.

Three findings, in order of severity.

---

## F1 — §4.3's case analysis is incomplete, and the theorem is false as stated

The load-bearing theorem is `V_A = V_B`, i.e. that L/H-with-tie-pinning
(Algorithm B) computes the same value as the threshold-attractor decomposition
(Algorithm A). Its `L < H` branch opens:

> Let `L = L_B(S) < T < H = H_B(S)`. (If `L < T` is not the case, then `L = T`
> and we're done; the L < H case for `L ≥ T` is symmetric.)

**`L < H` does not imply `L < T < H`.** Three orderings are possible:

| ordering | meaning |
|---|---|
| `L < T < H` | the case actually argued |
| `T < L < H` | **not argued.** Black's cycle-free guarantee already *exceeds* the tie |
| `L < H < T` | **not argued.** White's cycle-free guarantee already beats the tie |

The parenthetical claims that if `L < T` fails then `L = T`. That is false: `L`
may be strictly greater than `T`.

**Why this breaks the theorem, not just the write-up.** Take `T < L < H`. `L` is
(per the proof's own reading) Black's guarantee under cycle-free play, so Black
can secure `L > T` *without ever cycling* — Black will never accept the tie.
Pinning `V = T` there is simply wrong. Whether the true value is `T` depends on
whether **White can force the cycle**, and that is precisely what the attractor
computation determines and what `L` and `H` alone do not record.

**The general statement of the gap:** `L < H` tells you the value is
cycle-dependent. It does **not** tell you *which way the dependence resolves* —
that turns on which player can force a cycle, and neither fixpoint carries that
information. So `L < H ⇒ V = T` is not a theorem.

**Credit where it is due:** the author flagged this area himself, as review point
**R4** — *"the case `L < T < H` requires a careful argument… This is the
load-bearing step; if it's wrong, the equivalence fails."* He identified the
right step. My finding is strictly stronger: the problem is not that the
`L < T < H` case is under-argued, it is that the other two cases are **absent**,
and in one of them the conclusion is false.

## F2 — existence is not equality (pre-registered reject condition #5)

The pre-registration says: *"an argument that establishes only 'a fixpoint exists
on a finite graph' does NOT establish QA-023. The claim is that the fixpoint
equals the true game value. Existence is not equality."*

§4.3 proves `V_A = V_B` — that **two algorithms agree with each other**. It does
not prove that either equals the true game value under the rule. Algorithm A is
taken to be the game value via "the threshold-attractor characterization," which
is **cited but not proved for this game class**. So the chain

    true game value  =  V_A  =  V_B
                     ↑
              unproven link

has an unproven first link, and QA-023 is a claim about the first link.

Relatedly, the "Crucial lemma" is asserted rather than proved: *"by
Knaster–Tarski, `L(S)` is the least fixed point, which corresponds to 'consider
only cycle-free plays.'"* Knaster–Tarski gives the **existence** of a least
fixpoint. It does not identify that fixpoint with the value of cycle-free play.
That identification is exactly the step this project has been burned by before —
C3 assumed an operational reading of `L` and was falsified at 3×3.

## F3 — the adversarial review was never performed — AND THAT IS A BRIEF DEFECT, NOT A CONSOLE FAILURE

*(Reclassified 2026-07-28 after re-reading my own brief. The original wording of
this finding scored it against the console; that was unfair and is retracted.)*

§8.1 reads `*[Filled in by reviewer.]*`. The checklist (R1–R5) was written; no
review was run, so Part A entered this audit unreviewed and R4 — the item that
pointed straight at the real defect — was never actioned.

But `EXP-2.md` says only: *"**A second agent must attempt to refute** the proof
before Part B is trusted."* **Passive voice, no owner named.** It never says
whether the console spawns the reviewer, whether GLM routes one, or whether the
user dispatches it separately. Writing the R1–R5 checklist and leaving §8.1 for
someone else to fill is a *correct* reading of that sentence.

**Fix owed by me:** every brief that requires a review must name who dispatches
it, and must say whether the gated step may proceed while the review is pending.
Filed against the dispatch template, not against the console.

## Part B — void, and my fault not the console's

Part B ran `src/qa023_brute_2x2.zig` for 10h22m wall / 237min CPU at 100% on a
four-point goban and produced nothing. `DEPTH_LIMIT = 64`, no memoization, DFS
over **paths** carrying full history. Killed 2026-07-28 12:2x.

It was thrashing, not hung, and the design was unsatisfiable as I specified it:
enumerate paths → exponential; memoize on `(state, history)` → the PSK blowup we
are trying to escape; memoize on `state` → assumes the conclusion. The brief has
been corrected to a **history-sensitivity probe** modelled on T13 (reach the same
state via different histories; disagreement falsifies). Additionally the check
was at 2×2, which admits no reachable non-root cycles and so cannot test QA-023
at all.

## The convenient conclusion, and why I distrust it most

§4.3 concludes: *"No new fixpoint, no threshold iteration, no retraining of the
retrograde engine… only its interpretation needs the one-line post-processing
rule."* That is the maximally convenient answer — it would mean the existing
engine already computes the new rule's values for free.

My pre-registration anticipated exactly this: *"A result that is convenient gets
more scrutiny than one that is not."* **F1 lands squarely on it.** If resolving
the trichotomy requires knowing who can force a cycle, then a genuine attractor
computation is needed, and the "one-line post-processing" cost story does not
survive. **The cost estimate for the whole reframe currently rests on the broken
branch of the proof.**

## What would repair it

1. **Do the trichotomy properly.** All three orderings, with the `T < L < H` and
   `L < H < T` cases resolved on who can force the cycle. Expect this to require
   an attractor/who-can-force-a-cycle computation — and if so, say so, and
   re-cost the reframe honestly.
2. **Prove, or properly cite for this exact class, that the attractor
   characterization gives the game value.** Then `true value = V_A` is earned
   rather than assumed.
3. **Prove the crucial lemma** or drop the cycle-free reading of `L` and argue
   directly.
4. **Run the review**, with the independence condition, on the repaired proof.
5. **Then** Part B, as a history-sensitivity probe at 3×2, not 2×2.

## What survives

§1 (state space), §2 (A2 — the two basic-ko formalisations, examined and a choice
made), §3 (A3 — reference class), §5 (A5 — value domain, including the
`TIE = -128` vs `UNDEF` collision, correctly caught) are careful and stand. A2
and A5 both flag genuine ADR-worthy decisions. This is good work with one wrong
theorem in it, not a bad proof.

**QA-023 status: unchanged — CLAIMED, untested.** The gate is not passed and
EXP-4…EXP-8 remain held.
