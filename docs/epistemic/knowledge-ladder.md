Author: Orchestrator (Opus 5, claude-opus-5[1m]) · Date: 2026-07-29
Status: **PROPOSED FRAMEWORK** — not adjudicated. The user owns ruleset
adjudication and claim semantics; this file is a structure for that decision,
not a ruling. Nothing here changes a `CLAIMS.md` status.

# The knowledge ladder — separating perfect from optimal from best from guess

Written to answer a question the project has never answered in one place: *what
kind of knowledge do we actually have, and about which game?* The register
(`CLAIMS.md`) tracks how well each claim is established. It does **not** track
what the claim is about — and the project's three worst episodes were all
confusions of the second kind, not the first.

## 1. Two axes, not one

Every value the project produces sits at an intersection:

**Axis A — epistemic strength.** How well do we know it? This is what
PROVEN / CLAIMED / UNTESTED / MEASUREMENT already encodes.

**Axis B — rule fidelity.** *Which game* is it the value of? Positional superko,
basic ko + fixed-value tie, fresh-start PSK, score-on-cycle — these are
different games. A value can be exact, certified, and reproducible on Axis A
while being the value of a game nobody plays on Axis B.

**The project's characteristic failure is a high Axis-A score reported as
though it settled Axis B.** `4x4.ANCHOR` is the miniature: weizigo computed +2
under PSK, MIGOS II published +2 under basic ko + ties, and the register wrote
"matches van der Werf & Winands **under PSK**". The arithmetic is right; the
sentence claims validation of a rule that was never tested. That is Axis B
leaking into an Axis A statement.

## 2. The ladder

Six rungs. Each requires everything above it plus one more thing.

| rung | name | requires | what you may say |
|---|---|---|---|
| **K0** | **Certified** | exact value under an **explicitly stated** rule · evidence committed to git · **independently reproduced by a different implementation** | "this is the value, and here is how to check it" |
| **K1** | **Proven-as-scoped** | exact under a stated rule, evidence committed, **one** implementation | "this is the value, on the gobans and positions enumerated" |
| **K2** | **Optimal under a different rule, gap measured** | exact under rule R′ while the game played is R · **the R↔R′ divergence is measured** | "optimal under R′, and it differs from R by *this much*" |
| **K3** | **Optimal under a different rule, gap unmeasured** | exact under R′, no measurement of how R′ differs from R | "optimal under R′. We cannot say how wrong that is for R." |
| **K4** | **Best available, uncertified** | a value from machinery whose premise is orphaned, falsified-as-scoped, or applied outside its validated scope | "our best number. It may be right. We cannot defend it." |
| **K5** | **Guess** | heuristic, or a table consulted outside the region it was validated in | "a move. Nothing more." |

Two rules of use:

- **K1 does not decay to K0 by repetition.** Re-running the same code is not
  independent reproduction. Four seats re-ran the QA-023 probe; the defect
  survived all four. The audit that found a real bug (F5) wrote the algorithm
  again in another language. **Independent re-implementation is the only thing
  that has ever moved a claim up this ladder in this project.**
- **Losing the evidence drops you a rung.** T13 is the falsification the whole
  strategy rests on and its probe source is deleted: PROVEN on Axis A, but
  unreproducible, so K1 at best and arguably below it.

## 3. Where the project actually sits

| what | rung | why |
|---|---|---|
| Legal position counts, 1×1–4×4 (OEIS A094777) | **K0** | externally published *and* independently reproduced — per `AUDIT-REF-DSPro`, **the only external anchor the project has both cited and reproduced** |
| Knaster–Tarski convergence of the L/H fixpoint | **K0** | mathematics, not measurement |
| Move/capture/suicide kernel, colex bijection | **K1**→K0 | kernel matches A094777 at 4×4; the bijection has a checker |
| 3×2 reachable-graph structure (census, SCC, cycles) | **K1** | reproduced twice independently, incl. a Python transposition — but the figures are **in flux** (ko fix applied, F1 still open) |
| Benson unconditional life; GHI dependency-guard; Zobrist | **K1** | implemented and used, **never cross-validated against an external source** (`AUDIT-REF-DSPro`) |
| **The 4×4 "+2" oracle and every shipped ko-sensitive value** | **K4** | rests on ADR-0010's bracket premise = claim **C3, FALSE-AS-SCOPED at 3×3**; and it is *fresh-start* PSK, which **C2** falsified as a real-game oracle. The number may well be right. The knowledge is not there. |
| Eye-prune (ADR-0006) soundness | **K4** | a precondition of *every* forward search used as ground truth, validated on **one position**. `ADR0006-FALSIFY` is registered to move it. |
| GTP player in the ko-sensitive region | **K5** | defective by design; H5a mitigates, does not solve |
| **QA-023 / the F2-REMEDY median build (the target)** | **not yet on the ladder** | C1 untested-but-unrefuted; C2 under active challenge. See §5. |

**The certified-fraction metric is a K0-shaped instrument bolted to a K4
foundation.** "Certified" means the Bellman identity was verified at the node
*under the table's own rule*. That is self-consistency — it says nothing about
optimality against an opponent playing a different rule. `QA-027` predicts 100%
certified "by construction" under a Markovian rule, and that prediction is
almost tautological: it measures internal coherence, not correctness. The 0%
certified fraction in 4×4 self-play is the honest reading, and the *measured
gap* to PSK (S2 / EXP-8) is the number that answers the user's actual question.

## 4. What has been relaxed — the honest inventory

Some of these were decisions. Some were discoveries. **The distinction matters:
a decision can be revisited; a discovery is a constraint.** Marked accordingly.

| # | relaxation | kind | cost |
|---|---|---|---|
| 1 | **Positional superko → basic ko + fixed-value long-cycle tie** | **decision, forced** by R1 (PSK intractable for exact solve) | Axis B fidelity. Recoverable *only* as a measured gap (EXP-8), which does not yet exist because it needs the new-rule tables. |
| 2 | **Score-on-cycle → constant tie value** | **decision, forced** by R2 (score-on-cycle ≡ PSK in hardness) | the value on a repetition is now a stipulation, not a computation |
| 3 | **Real-game oracle → fresh-start oracle** | **discovery, not chosen** — surfaced by C2/C3 falsification. The "three retreats." | the largest single loss, and it was *implicit* until caught |
| 4 | **5×5/6×6/7×7 → 4×4 only** | **decision** | fine — but `ARCHITECTURE.md` and `ADR-0012-5X5` still state the old ambition (erratum pending in `EVIDENCE-INTEGRITY`) |
| 5 | **All positions → root + a reachable subset** | **decision** (scope) | claims are per-goban and per-region; the register enforces this well |
| 6 | **Eye-prune soundness assumed** | **drift** — never explicitly agreed | contaminates every forward-search ground truth if wrong |
| 7 | **"Certified" redefined as self-consistency** | **drift** | a metric that cannot fail in the way a reader assumes it can |
| 8 | Komi 0, Tromp–Taylor area scoring | **decision** | benign, but it is a choice and belongs stated |

Items **3, 6 and 7 are the ones to worry about**: nobody decided them. Item 1
is the project's central, defensible trade — and it is only defensible *if the
gap is measured*, which is exactly what rung K2 requires and rung K3 denies.

## 5. So what are we marching toward?

**Not "perfect 4×4 Go."** The honest target, stated at the right rung:

> **Provably optimal 4×4 play under basic ko + a fixed-value long-cycle tie,
> with a measured divergence from positional superko.**

That is **K2**. It is a legitimate, defensible, publishable result — the
reference audit judges the literature ready for it. It is *not* perfect Go, and
the project should stop letting the two share a sentence.

The path there is three gates, and only the first is in flight:

1. **C1 — Markovian state-sufficiency.** Is `(board, side, ko_point, passes)`
   enough? **Untested but unrefuted.** Every observation to date is consistent
   with it holding; the probe that claimed to falsify it never ran
   (`probe-defect-2026-07-29/`). `2B-PROBE-FIX` tests it properly.
2. **C2 — the value rule.** Does `median(L, TIE, H)` compute the right value?
   **Under active challenge**: 12 candidate counterexamples, all in the
   *over-pinning* direction, on a graph where the median rule pins TIE at 1,532
   of 1,756 non-terminal states. This is a **formula**, and formulas are
   replaceable — the census and the L/H machinery survive its failure.
3. **The gap.** Measure basic-ko-optimal play against PSK. Without this the
   result is K3, not K2, and K3 is much less interesting.

**If C1 falls**, the honest deliverable is a negative result, and it is a real
one: *every* bounded-history representation the project tested was foreclosed by
measurement — PSK (R1), score-on-cycle (R2), RETRO_PLY (RPLY), kill-X% (R3) —
and basic ko + fixed tie was the first unforeclosed candidate. If it too fails,
the finding is "no tractable Markovian representation exists for any rule a
human would call Go," which is publishable and is *not* a failure of the
project. `AUDIT-DSPro` §2.2 is right that the retreats were a search, not a
weakness; that framing is what makes the negative result presentable.

## 6. How to use this file

When reporting any value, state **both** coordinates: the rung, and the rule.
"+2 at 4×4" is not a result. "K4: +2 at 4×4 under fresh-start PSK, on a premise
falsified-as-scoped at 3×3" is a result — an uncomfortable one, which is the
point.

Candidate follow-up, if the user ratifies this framework: add a **rung column**
to `CLAIMS.md` beside the status column, and a **rule column** beside it. The
linter could then mechanically catch the `4x4.ANCHOR` class of defect — a claim
whose stated rule differs from the rule of the evidence it cites. Today that
error is invisible to the linter because it lives in prose.
