<!--managent set=A needs=EXP-10 caps=reasoning:sustained-->
# QA-018-REVIEW-B — panel seat B: DeepSeek Pro adversarial review of ADR-0017

**You are seat B of a three-seat blind panel.** Read, in this order:

1. `docs/infra/dispatch/QA-018-REVIEW-PANEL.md` — the panel protocol
   (blindness, write isolation, the two calibration defences, run stats).
2. `docs/infra/dispatch/QA-018-REVIEW.md` — the core brief: framing, the
   question, the three 025 findings to grade, packet read order, acceptance,
   Do-NOTs. It applies verbatim except where the panel protocol overrides it
   (deliverable paths and board bookkeeping).

**Closes:** nothing directly. **Enables:** `QA-018-RULING` (with seats A/C).
**KIND:** ANALYSIS — writes exactly two files, nothing shared.

## Seat identity

- Model: **DeepSeek Pro**.
- Your writes, and only these (panel protocol §2):
  - `docs/evidence/QA-018/review-b-deepseek/report.md` (+ `PROVENANCE.md`
    beside it)
  - `untracked/msg/milestone-01-ko-reframe/028-deepseek-review-to-all.md`
- Do not run `managent`; the Orchestrator records your claim/done (D-8).

## Seat B note

You have **no prior entry in `docs/infra/model-perf.md`** — this run is your
first data point on this project, and the calibration defences (panel
protocol §3) carry extra weight for exactly that reason: with no track
record, a blessed planted flaw discounts your verdict entirely, while a
precisely-convicted one establishes it. Cite every claim as `file:line`; an
uncited conviction or acquittal scores as unsupported. The packet is
self-contained (~30–50k tokens); if anything does not fit your context, say
so in `## Run stats` rather than silently truncating.
