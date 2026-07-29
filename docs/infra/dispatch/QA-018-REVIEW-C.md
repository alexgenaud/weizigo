<!--managent set=A needs=EXP-10 caps=reasoning:sustained-->
# QA-018-REVIEW-C — panel seat C: Kimi-k2.7 adversarial review of ADR-0017

**You are seat C of a three-seat blind panel.** Read, in this order:

1. `docs/infra/dispatch/QA-018-REVIEW-PANEL.md` — the panel protocol
   (blindness, write isolation, the two calibration defences, run stats).
2. `docs/infra/dispatch/QA-018-REVIEW.md` — the core brief: framing, the
   question, the three 025 findings to grade, packet read order, acceptance,
   Do-NOTs. It applies verbatim except where the panel protocol overrides it
   (deliverable paths and board bookkeeping).

**Closes:** nothing directly. **Enables:** `QA-018-RULING` (with seats A/B).
**KIND:** ANALYSIS — writes exactly two files, nothing shared.

## Seat identity

- Model: **Kimi-k2.7**, in a console **separate from the EXP-8 worker** (that
  console holds `src/psk_divergence.zig`; this seat holds no source paths and
  the two must not share session state). There is no `holds` conflict — the
  core brief's KIND: ANALYSIS parallelises with EXP-8 without limit.
- Your writes, and only these (panel protocol §2):
  - `docs/evidence/QA-018/review-c-kimi-k27/report.md` (+ `PROVENANCE.md`
    beside it)
  - `untracked/msg/milestone-01-ko-reframe/029-kimi-review-to-all.md`
- Do not run `managent`; the Orchestrator records your claim/done (D-8).

## Seat C note

The ledger (`docs/infra/model-perf.md`) credits your line as the standing
ruthless auditor of foundational claims — the Knaster–Tarski conviction of
(a′) is the house style this seat expects: convict or acquit with the exact
lemma, not a vibe. The one place ADR-0017 leans on game theory rather than
code is its Defence-2 claim that a policy player can leak without any
pointwise bracket violation (the chaining step breaking under PSK bans) —
verify that argument as carefully as you verified the fixpoint crux, and
check the T13 mismatches actually have the search-path shape ADR-0017 says
they have.
