# ADR-0019 — First-revisit truncation is the rule; the median pin rule is falsified

**Date:** 2026-07-29
**Status:** ACCEPTED **as a ruleset decision** · **its measurement premise is WITHDRAWN 2026-07-29 (later)**

> **⚠ The factual premise of this ADR — that `median(L,TIE,H)` was falsified at 3×2 — is withdrawn.**
> `Kimi-k3/PINRULE-SUFFICIENCY` found, and the Orchestrator confirmed at the code, that
> `fixpoint_kernel` never updates White-to-move states: `L_tab` is seeded to −6 and `H_tab` to +6
> (`src/qa023_probe.zig:881-885`), while the White branches update only on `best < L_tab` (`:961`)
> and `best > H_tab` (`:1020`) — guards that cannot fire. All 878 White-to-move reachable
> non-terminals therefore keep (−6,+6), and `median(−6,TIE,+6) = 0` **by construction**. Every C2
> counterexample was White-to-move. `QA-026`, `QA-013` and `GLOBAL.LONGCYCLE` are reverted to their
> prior statuses; **C2 is UNKNOWN pending re-measurement**. Audit: `QA023-KERNEL-AUDIT`.
>
> **What still stands: the ruleset decision.** §Decision's choice — first-revisit truncation *is*
> the rule, and the loopy-game fixpoint value is not permitted to define the rule by construction —
> was a semantics ruling, not a measurement, and the reasoning in §"Why not the alternative" is
> unaffected. **What lapses:** consequence 1 (the three falsifications), consequence 3 (EXP-3's
> tractability estimate is unsupported), and consequence 4's premise that a replacement value rule
> is required. `EXP-4` stays gated on `PINRULE-SUFFICIENCY` regardless — its input tables came
> through the defective kernel.
**Decider:** the user (ruleset adjudication). Recorded by the Orchestrator (Opus 5) under
explicit delegation — the user, having read the fork as posed in
`docs/epistemic/qa023-c2-adjudication-2026-07-29.md` §6, directed that the decision be
recorded as he would decide it. **If this misstates his intent, this ADR is the thing to
correct, not the work built on it.**
**Supersedes:** nothing. **Constrains:** `GLOBAL.F2-REMEDY`, EXP-4…EXP-8, any future value rule.

## Context

`2B-PROBE-FIX` (DSPro, 2026-07-29), independently confirmed by `2B-6` (DSPro) and
hand-verified by the Orchestrator, falsified `V = median(L, TIE, H)` at 3×2. Six states —
all White-to-move at `passes == 1` with no ko point — have `median(L,TIE,H) = TIE = 0`
while the history-conditioned value under first-revisit truncation is the static pass-out
`area_score`: +1, +3, or −6. Every counterexample satisfies `truncated == area_score(board)`
exactly, with `L < 0 < H`.

This exposed a fork the project had never stated, because two different objects had been
treated as one:

- **First-revisit truncation** (`reference-semantics-2026-07-29.md` §1): the game ends the
  moment any state repeats within the game line, valued `TIE`. History-conditioned.
- **The loopy-game L/H fixpoint with a pointwise pin rule**: a position-indexed value with
  no notion of *when* a repeat occurred. This is what the median build computes.

`QA-026` and proof-v2 Thm 5.1 asserted these coincide. They do not.

## Decision

**First-revisit truncation is the rule.** It is the semantics the project is solving for.
The median pin rule is a *failed attempt to compute it*, not a competing definition of it.

Consequences accepted:

1. **`QA-026`, `QA-013` and `GLOBAL.LONGCYCLE` are FALSE-AS-SCOPED at 3×2.** Promoted in
   `CLAIMS.md` 2026-07-29. proof-v2 Thm 5.1 is false as stated.
2. **`QA-023` is NOT falsified.** Its row asserts Markovian state-*sufficiency*, which the
   counterexamples do not touch — every within-budget history at every eligible state agrees,
   including at the six counterexamples. C1 is **UNTESTED-FOR-WANT-OF-CONTRAST** (`2B-3-AUDIT`:
   the generator misses the shortest arrival in 93% of states, ~62% shared prefixes).
3. **The tractability estimate is no longer supported.** EXP-3's "tens of minutes at 4×4"
   assumed two `converge` sweeps plus a pointwise `median`. Without the pin rule, the
   candidate is dependency-set machinery (Kishimoto–Müller) whose cost is what made PSK
   intractable. **C2's failure re-opens the tractability question EXP-3 was thought to have
   closed.** No 4×4 build proceeds on the old estimate.
4. **A replacement value rule is required** before `GLOBAL.F2-REMEDY` can be built. Open
   question, gated on `PINRULE-SUFFICIENCY`: can *any* pointwise function of `(L, TIE, H)`
   be correct? If two states share that triple and differ in value, every repair-by-
   substitution dies at once and the state must carry more information.

## Why not the alternative

The alternative was to **declare the loopy-game fixpoint value to be the rule** — which
would make the fixpoint correct by definition and the probe wrong by construction. Rejected:

- It defines the ruleset as *whatever the project's algorithm computes*. That is precisely
  the mechanism that produced the fresh-start-oracle retreat — relaxation item 3 in
  `docs/epistemic/knowledge-ladder.md`, one of the three nobody decided.
- First-revisit truncation is the semantics closer to how real Go handles repetition. Moving
  away from it trades rule fidelity (axis B of the knowledge ladder) for a cheap
  implementation, which is the trade this project exists to stop making.
- It would convert a genuine negative result into an apparent success. The negative result is
  a contribution; the apparent success would be K4 dressed as K0.

## The honest position this leaves

Under the knowledge ladder, the project's target remains **K2** — *provably optimal play
under basic ko + a fixed-value long-cycle verdict, with a measured divergence from positional
superko* — and it is now **further from it than before 2026-07-29**, because the cheap route
to computing that value is gone.

The finding itself is publishable and should be stated once, plainly: PSK is intractable for
exact solve (R1); score-on-cycle is equivalent in hardness (R2); RETRO_PLY likewise (RPLY);
kill-X% made it worse (R3); and the tie-pinned loopy-game fixpoint — the first unforeclosed
candidate — **does not compute the truncation value** (this ADR). That is a real result about
the problem, not a failure of the project. Whether it is the *final* answer depends on
`PINRULE-SUFFICIENCY` and on whether dependency-set machinery is affordable at 4×4.

## Follow-ups

- `PINRULE-SUFFICIENCY` — can any pointwise `(L,TIE,H)` rule work? Includes the concrete
  repair hypothesis: clamp to the pass-out bound (`at passes==1 the mover can always take
  area_score`), which fits all six known counterexamples.
- `EVIDENCE-INTEGRITY` — carry the `CLAIMS.md` consequences, including the 14 orphans this
  promotion created. **`GLOBAL.H1` and `GLOBAL.ONEMISMATCH` are now orphaned**, and `H1`
  conjoins the same two halves as QA-023 (a Markovian state *and* computability by converge)
  — it should be **split into its conjuncts**, not marked false whole. Same for `QA-011`.
- A narrative telling the through-line once, cite-tagged and lint-verified (`NARRATIVE-LAYER`).
