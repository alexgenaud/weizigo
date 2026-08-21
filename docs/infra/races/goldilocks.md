# Model-tier discovery - working hypotheses (NOT rules)

This is a scratchpad of assumptions to challenge, not a rulebook. Everything here is
revisable the moment data contradicts it.

## What we're confident about (so far)

- **Fable > Sonnet > Gemma**, across tasks. The extremes are the only confident rungs.
- The **middle is NOT ranked**: we have not established where DSPro, Opus, Flash, Qwen,
  Haiku sit relative to each other, for any general task type. Do not assume an order.

## Naive prior (assumed, to be challenged)

> Fable > DSPro > Opus > Flash > Sonnet > Qwen > Haiku > Gemma

This is a starting guess to organize the first races, nothing more. Adjacent rungs should
compete so a model can climb or fall; the prior exists to pick who races whom, not to
pre-judge the result.

## Provisional rules (v1, 2026-08-21 - revise when a race contradicts them)

- **R1 - Audit with a few diverse models.** `01-spec-audit-disposition.md`
- **R2 - Re-implement code independently with a different model and language than the
  implementor.** `07-build-audit-disposition.md`
- **R3 - Verify every model output on disk before accepting it.** `01-spec-audit-disposition.md` (gemma)
- **R4 - Delegate to models proven adequate for the task type; if unproven, race the target
  plus adjacent models (3-4 with data, 5-6 without).** this doc
- **R5 - Test local models (qwen, gemma) sparingly, and run them solo.** OWNER-LOG D12-D23

## Measurement approach (the one thing worth keeping)

For each **metric x task type**, score models on **correctness** and **actionability** (does
the output change a decision/fix?), then place each in one of:

- **underqualified** - output wrong or inadequate.
- **just right** - correct, and the task actually needs this model's capability (a
  less-capable model would be worse; its capability buys something HERE).
- **overqualified** - correct but not *actionably* better than the task requires: the
  model's extra capability buys nothing for THIS task (same result; more-but-noise;
  overengineering). Relative to task requirements, not to cost — Fable is overqualified
  to audit a Hello_World.zig program but just-right to audit the epistemic tree.

Cost is NOT part of overqualification, and it is not a race-test measurement: it is
variable and is factored in LATE and LAZY when choosing what to deploy. "All else equal, a
cheaper overqualified agent beats an expensive just-right agent" is a deployment choice,
not a result the race records.

## Primary field + the follow-up decision (working approach)

The core four - **DSPro ,  Opus ,  Flash ,  Sonnet** - is the primary field for most task
types: the likely goldilocks tier. What's open is their relative rank and who's
overqualified per task type. The core-four outcome decides the follow-up:

- **Sonnet is good enough** -> the boundary sits at/below Sonnet -> probe the **lower tier**
  (Qwen ,  Haiku ,  Gemma) for that task type.
- **DSPro or Opus struggle - or clearly dominate** -> the task is upper-tier territory ->
  probe the **upper tier** (add **Fable**).

So the core four is the probe that tells us which end to expand before we narrow.

## How to pick a race field (working approach, not a rule)

Pick an **assumed goldilocks target** for the task, then field the models ~2 rungs above
and ~2 below it on the naive ladder - strong enough to test the upper bound, weak enough
to test the lower bound. That's the "4-5 models" shape: target +/- 2.

The interleaved ladder has a useful property worth exploiting:

- **distance 1 = cross-family** (DSPro-Opus, Opus-Flash, Flash-Sonnet, Sonnet-Qwen ...)  - 
  these broaden the comparison and reveal distinguishing characteristics across families.
- **distance 2 = same-family** (Fable-Opus, DSPro-Flash, Opus-Sonnet, Sonnet-Haiku ...)  - 
  these reveal what the bigger sibling buys within a family.

So target +/- 2 naturally includes both kinds of comparison. And the confidence heuristic:
**3+ rungs apart, we're fairly confident stronger/weaker - if a model 3 rungs below beats
one 3 rungs above, that is itself an interesting finding** (the ladder is wrong there).
Adjacent neighbours (distance 1) are explicitly *not* ranked with confidence.

## Starting fields (suggested, narrow from either end after each ladder resolves)

| task size/scope | assumed target | starting field (target +/- 2) |
|---|---|---|
| surgical / mechanical / small | Flash | DSPro ,  Opus ,  Flash ,  Sonnet ,  Qwen ,  Haiku |
| design / architecture / deep audit | Opus | Fable ,  DSPro ,  Opus ,  Flash ,  Sonnet |
| cheap sweep / classification | Qwen | Flash ,  Sonnet ,  Qwen ,  Haiku ,  Gemma |

**Narrowing:** once the ladder for a specific task type is established, reduce from
*either* end - drop the overqualified top for easier instances, drop the underqualified
bottom for harder ones. No fixed participant cap; the field follows the resolved rungs.

## Working principle (strong preference, not a rule)

Fable races the upper tier (DSPro ,  Opus) and is not thrown into low-tier fields; Fable vs
Gemma/Qwen is not a comparison we expect to need. Gemma is re-probed only on task types it
hasn't already failed.
