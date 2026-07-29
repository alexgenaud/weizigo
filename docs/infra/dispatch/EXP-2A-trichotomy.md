# EXP-2A-trichotomy — repair EXP-2 Part A's §4.3 trichotomy (the proof)

**This is a routing brief** for managent task `EXP-2` (Part A). The full spec is
in the two messages below + `EXP-2.md` Part A; this file exists so the dispatch
prompt `follow docs/infra/dispatch/EXP-2A-trichotomy.md` resolves.

**Capabilities:** reasoning: sustained, documents over implementation (DECISIONS D-7).
**Holds:** none (docs only). **Output:** a corrected proof document; no engine edits.
**Reviewer:** independent adversarial review — sees **only** the proof + the two foreclosures
+ *"find the flaw; assume one exists"* (not the brief, roadmap, or critique — all
argue for the conclusion).

## Read in this order
1. `untracked/msg/milestone-01-ko-reframe/STATE.md` (crash anchor).
2. `untracked/msg/milestone-01-ko-reframe/004-opus-to-pi.md` — the EXP-2 Part A
   verdict: **UNRESOLVED, one wrong theorem.** §4.3's `L < H ⇒ V = T` is false;
   the repair order (steps 1–3) is here.
3. `untracked/msg/milestone-01-ko-reframe/005-opus-to-glm.md` §"reasoning-intensive work policy" —
   your one surgical deliverable.
4. `docs/infra/dispatch/EXP-2.md` Part A — the original proof obligation (A1–A5)
   and `docs/evidence/QA-023/proof.md` (the proof with the broken §4.3).
5. The two foreclosures the reviewer will be given: `docs/research/ruleset-options.md`
   §RETRO_CYCLE and §RETRO_PLY.

## The one surgical deliverable
Resolve §4.3's trichotomy. `L < H` does **not** imply `L < T < H`; the orderings
`T < L < H` and `L < H < T` are unargued, and in `T < L < H` Black can secure
more than the tie without cycling, so pinning `V = T` is false. Resolve **all
three** orderings on **who can force the cycle**, and **separately establish
`true game value = V_A`** rather than assuming it (existence ≠ equality — F2).
Then **re-cost the reframe**: if the trichotomy needs an attractor computation,
§4.3's "one-line post-processing, no engine retraining" claim dies, and the cost
estimate for the whole reframe currently rests on that broken branch.

## Acceptance
- A corrected `docs/evidence/QA-023/proof.md` (or a successor) with all three
  orderings resolved + `true-value = V_A` earned.
- An honest re-cost of the reframe (does the new rule still need no finisher, or
  does the trichotomy force an attractor computation?).
- QA-023 status updated (PROVEN / FALSE / still CLAIMED) with the evidence in git.
- Heartbeat if any computation runs > 1 min (the 10h-thrash lesson).

## Do NOT
- Do not edit the engine (`retro/oracle/rules/solve`). Do not implement — documents
  only. Do not assume the conclusion. Tag the claim honestly.