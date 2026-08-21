# Seed - measurement methodology v2 (refine t11 with the operator's concerns)

Design only; no implementation; edit nothing. This runs in parallel with T557's pass-1
execution. Read `t11-appetite-design/out.md` first - this
seed refines that design.

## 1. Epoch - roster-wide snapshot, unreliable under silent updates

The project's epoch is a roster-wide date (e.g. `2026-08-20b`). It tracks a model version
only where the NAME changes (Kimi K2.7 -> K3; Claude renames per version). For silent-update
models (DeepSeek V4, name constant across several updates), the epoch date is the only guard,
and it cannot detect a mid-epoch swap.

**Feedback:** keep epoch roster-wide (existing convention), but record per-row `serving_tag`
+ `as_of` (already in t11's schema), and treat same-name-across-epochs as suspicious - a
DeepSeek V4 score from June vs August may be different models. Never aggregate across epochs
(already the grand-race rule; keep it).

## 2. Scores are relative, not absolute - add a baseline anchor

A model's score is relative to the race field it competed in. Sonnet "good" vs Fable in a
high-tier race, then "excellent" vs Gemma in a low-tier race, inflates Sonnet's average.
Cross-race comparison needs a fixed anchor, not just per-race relative order.

**Feedback:** anchor every race on a small fixed set (Flash, optionally Sonnet) that appears
in EVERY race; record each model's score as delta-from-anchor, not absolute. Flash is the
natural anchor (cheap, fast, mid-tier, reliable). If a single baseline cannot always run,
the fixed anchor set is the fallback.

## 3. Machiavelli (The Prince, "protection against flattery") - reward verification, never penalize contrarians

Do not penalize a model for raising a concern against consensus. A contrarian finding that
VERIFIES is the most valuable output (our own qwen D-4 getsid catch: only qwen found it, it
verified). A contrarian finding that does NOT verify is worse than silence (gemma's
hallucinated "findings").

**Feedback:** add a `verification_rate` metric (claims verified on disk / claims made) and a
`unique_catch` signal (caught something others missed, and it verified). "Always verify
claims" is already rule R3 in `docs/infra/races/goldilocks.md` - carry it into the tier
computation so a model is rewarded for verified contrarianism and penalized for unverified
claims.

## 4. Sonnet's opinions (operator relayed) - adopt as candidates

Metrics to add where comparative scores are missing:
- citation-integrity / evidence-honesty as a standing metric (the round's own analysis named
  it the best discriminator found so far).
- uncertainty / scoping-honesty (highest-dispersion metric, only 2 proposers - re-propose).
- mechanized correctness gate (fixed acceptance script, not self-report) for
  implementation-bounded work.
- orchestration close-latency / close-completeness (most models have zero tasks of this type -
  an assignment gap, not a scoring gap).
- uniform token-usage instrumentation across lanes (Claude lanes drop usage data - a harness
  fix blocking every cost comparison).

Priority races:
1. T554 round 2, different topic, same 7-lane structure - tests whether the fable/dspro tier
   gap is a stable trait or one-topic artifact.
2. Replicate T447 (sealed-key audit race) across opus/sonnet/fable/haiku - they never ran it.
3. Same-task mechanized-acceptance implementation race across opus/sonnet/haiku/glm.
4. A real orchestration-seat trial for opus/sonnet/haiku/fable/glm.
5. Harness token-instrumentation fix, then run all 7 lanes on one shared task.

## Deliverable

Refine the t11 design with the above, as a concise v2 design doc (your final message, and
optionally a committed file if the operator asks):
1. Epoch + silent-update handling in the matrix schema.
2. Baseline-anchor scoring (delta-from-anchor, Flash as the default anchor).
3. Verification metrics (verification_rate, unique_catch) + the Machiavelli stance in the tier
   computation.
4. Fold Sonnet's 5 metrics and 5 races into the methodology.
5. Note what is implementable now vs deferred (e.g. the harness token fix is a T557/harness
   task; the races are future dispatches).
