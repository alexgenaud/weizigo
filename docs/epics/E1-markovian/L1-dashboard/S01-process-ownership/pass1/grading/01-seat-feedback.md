# Grading design — SEAT FEEDBACK, a separate proposal

**Author:** Orchestrator seat (`claude-opus-5`), 2026-08-20. Deliberately **not** merged
into the operator's proposal — blending destroys the independence the exercise measures,
and denies the adjudicator a clean choice (a lesson the seat learned by doing it wrong
earlier today). Fable may adopt, reject, or replace any of this.

**Weigh everything below against the operator's standing caution:** *"we are already
getting too deep into decide-by-committee. We need to learn from experience rather than
anticipate a clever tournament before trying."* Every item here is an anticipated problem.
"Run it once and see" is an acceptable ruling on all of them.

## What the seat thinks is strongest in the proposal

**Self-chosen metrics are a second signal, and it may be the more valuable one.** What a
grader chooses to measure reveals what it *values* — independent of how well it scores
anyone. A model that never proposes "economy" as a metric has told us something about
itself that no score of its own artifact would.

## S1 — metric incomparability (the main risk)

Seven graders inventing their own metrics produces up to 7×7×N cells with no shared axis.
Scores cannot be aggregated, and consolidation becomes arbitrary.

*Proposed mitigation:* two rounds. Round 1, free-form metric proposal only (discovery).
Round 2, score every artifact against a **curated union** so there is one common axis.
Costs a round; buys aggregability.

*Argument against:* the operator already anticipated this may be "too complicated", and
accumulation-only may be enough for now.

## S2 — self-serving importance weights, which are also measurable

A verbose model will likely rate "thoroughness" important; a terse one, "economy". That
bias is unavoidable — but it is **detectable**, and detecting it is free: check whether
each grader's importance weights correlate with its own artifact's strengths. A grader
whose weights track its own output is grading itself favourably by construction.

*Recommendation:* record it as a per-model statistic. This is a genuine finding about a
model's judgement, not a defect in the method.

## S3 — 0–10 scales compress

Graders cluster in 6–8 and the spread carries little information.

*Proposed mitigation:* require an **ordinal ranking alongside the cardinal scores** — best
to worst on each metric. Rankings are harder to fudge than scores and survive
recalibration between graders.

## S4 — report disagreement, not just means

A weighted average hides the most informative thing. **Where graders disagree sharply on
one artifact-metric cell, that disagreement is the finding** — the metric is ill-defined,
or the artifact is genuinely ambiguous. Report spread per cell; never collapse to a single
number without it.

## S5 — make it parseable or consolidation is manual

Seven graders × seven artifacts × N metrics, in prose, is not consolidatable by hand.
Require one table with fixed columns (`artifact, metric, score, importance, rank,
one-line justification`). The justification column is where the qualitative nuance the
operator wants — *"wordy without content"*, *"precise but overlooked critical findings"* —
should live.

## S6 — cost, stated plainly

Round 1 alone is 7 graders × 7 artifacts. Under the isolation ruling (document phases run
parallel, unique file per lane, no worktrees) that is minutes, not hours. A second scoring
round doubles it. Both are affordable on DeepSeek; the Claude lanes are the constrained
resource.
