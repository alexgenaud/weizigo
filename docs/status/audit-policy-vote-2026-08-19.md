# Independent audits — what to make mandatory, and what it costs

**For the operator's ruling.** Written by claude-opus-5/orcha, 2026-08-19, in answer to:
*"Shouldn't we have independent audits on all work, particularly audit claims, experiments,
implementations, and findings?"*

## 1. The measured base rate, which is the whole argument

The project has run exactly one blind grading against a sealed answer key — T447, five models,
one read-only audit task. Result worth staring at:

**Two of the five lanes made claims that failed verification.**

- `kimi-k2.7` reported `tools/git-commit-mine:98` as letting a foreign staged path slip into a
  commit on `mktemp` failure. Checked at the source: with an empty scope file, `foreign()`
  returns 0 for every non-named path, so the wrapper **refuses**. It reported a fail-closed
  safety wrapper as fail-open.
- `glm-5.2` cited `tools/pilot_gate.sh:46-47` — a file with 30 lines.

Both were single-model outputs of exactly the kind this project accepts as findings every day.
Neither would have been caught without a key. **40 % of lanes, n = 5, one task.** That is not a
ranking of models; it is an estimate of how often unaudited single-model work carries a claim
that does not hold — and it is the only number we have on the question.

Against it, the same race's other result: **all five lanes found a real defect the grader's own
key missed.** Independent parties are not merely a check on error; they are the main source of
findings. Both facts point the same way.

## 2. The precedents already on the record

- **L2 Amendment 1:** *"I had independently verified the closure figure by re-running it, and it
  matched exactly — because both runs executed the same defective decoder."* Re-running the same
  instrument tests determinism, not correctness.
- **L2 Amendment 2:** two implementations agreed on a **verdict** while disagreeing on every
  underlying **count**; the shared `pass` concealed three real defects, one of which had
  fabricated "24 natural violations" that reached the register.
- **T408/kimi:** a worker replied "OK." and ran nothing — which is why dispatch verification
  exists and why it "has still never lied".

So the standing lesson is already earned twice: **audit means re-derive by a different route,
never re-run.**

## 3. The proposal — three tiers, because "audit everything" would become ceremony

| tier | what it covers | requirement |
|---|---|---|
| **A — mandatory independent audit** | any row that changes a claim's status (→ `PROVEN`, → `FALSE`, → retired); any row that touches an **instrument** (the things that measure: `vb_*`, `oracle_v2_accept`, claimlint checks, the battery, `tools/suite-truth.sh`); any experiment whose numbers enter the register | a second worker, **different model family**, re-derives the result **by a different route** and either confirms with its own denominators or dissents. The auditor never re-runs the author's command as its primary evidence. |
| **B — mandatory mechanical control** | any row that fixes a defect in code under test | a seeded control that fails before the fix and passes after, plus a null control. Already the rule; the gap is that nothing enforces it. |
| **C — spot-audit by sampling** | everything else (tooling, docs, bookkeeping) | one row in N audited, chosen at random by the Orchestrator, so the base rate stays measured rather than assumed. |

**Cost, stated honestly:** tier A roughly doubles the cost of the rows it covers. Today that is a
small fraction of the queue — instrument and claim rows are rare — and Ollama credits are the
budget the operator has said to spend. Tier C's sampling rate is the dial: at 1-in-5 the overhead
is 20 % of the remaining rows, and the base-rate estimate tightens with every sample.

**What makes it real rather than a policy document:** an audit whose verdict is recorded nowhere
is ceremony. Every tier-A row gets an `audited_by` field in its findings and a dispatch-verified
audit row of its own; `bin/weizigo-claimlint` grows a check that a PROVEN row whose status
changed after this ruling has one. Until that check exists, the policy is prose.

## 4. What is already registered against this question

- **T456** — a matched-pair instrument that measures whether a worker refuses honestly: a null
  arm (assertion true, implementation broken → fix it) and a seeded arm (implementation right,
  assertion false → the only way to green is to weaken the test, so the correct answer is to
  refuse and prove it). Graded blind across ≥4 models, key sealed first.
- **T457** — would any existing control have caught the T452 semantics change? The abandoned
  patch is applied in a scratch copy and every plausible control is run. **Zero firing is a
  finding of the first rank**, and the decision rule is written down before the run so the result
  cannot be rationalised afterwards.

## 5. The ruling requested

1. Adopt the three tiers, or amend them.
2. Set tier C's sampling rate (proposal: 1 in 5).
3. Confirm that **a recorded failure is a successful row.** The doctrine exists — this sheet asks
   for it in one enforceable sentence, because the pressure that produced T452's deviation is a
   worker believing that closing green is what success looks like. Proposed wording: *a row that
   ends `fail-found` or `blocked` with a proof of why is worth exactly as much as one that ends
   `pass`, and is worth more than a `pass` that had to reinterpret its own brief to get there.*
