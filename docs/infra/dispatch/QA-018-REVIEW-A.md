<!--managent set=A needs=EXP-10 caps=reasoning:sustained-->
# QA-018-REVIEW-A — panel seat A: adversarial review of ADR-0017

**You are seat A of a three-seat blind panel.** Read, in this order:

1. `docs/infra/dispatch/QA-018-REVIEW-PANEL.md` — the panel protocol
   (blindness, write isolation, the two calibration defences, run stats).
2. `docs/infra/dispatch/QA-018-REVIEW.md` — the core brief: framing, the
   question, the three 025 findings to grade, packet read order, acceptance,
   Do-NOTs. It applies verbatim except where the panel protocol overrides it
   (deliverable paths and goban bookkeeping).

**Closes:** nothing directly. **Enables:** `QA-018-RULING` (with seats B/C).
**KIND:** ANALYSIS — writes exactly two files, nothing shared.

## Seat identity

- Model: as assigned at dispatch, in a **fresh worker console** — explicitly NOT the
  Orchestrator instance (panel protocol §5; you must have no Orchestrator
  session state, no goban ownership, and no prior QA-018 context this session).
- Your writes, and only these (panel protocol §2):
  - `docs/evidence/QA-018/review-a/report.md` (+ `PROVENANCE.md` beside it)
  - `untracked/msg/milestone-01-ko-reframe/027-review-a-to-all.md`
- Do not run `managent`; the Orchestrator records your claim/done (D-8).

## Seat A note

This seat's line in the ledger is credited with catching the
E2 V1-equation bug and the least-fixpoint crux — subtle-theory strengths.
The standing-suspicion rule still applies: a review that agrees the
refutation failed is a result matching what the brief hoped for. Attack
hardest where ADR-0017 is most confident — the Defence-2 claim-semantics
split (does E2 really exhibit no pointwise violation?) and the T13
family-membership argument (is every one of the 12 histories genuinely
search-shaped, given the eye-prune caveat ADR-0017 itself records?).
