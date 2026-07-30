<!--managent set=P needs=2B-2-->
# 2B-3-AUDIT — audit the history-pair generator (an unaudited input to every probe result)

**Opened by:** the Orchestrator's handover (msg 037) named this and it was never registered; the Orchestrator is registering it because `2B-PROBE-FIX` will consume this generator's output. ANALYSIS — read-only, no file conflicts.

## Why

2B-3 (`docs/evidence/QA-023/history-pairs-3x2-2026-07-29.md`) generates the arrival histories every probe evaluation depends on. Its author **found and fixed two bugs in it during the task**. It has never been audited. A defect in that fix corrupts whatever `2B-PROBE-FIX` measures — and the probe it fed has already produced one round of invalid numbers for an unrelated reason (`probe-defect-2026-07-29/README.md`), so this input deserves the scrutiny the output just got.

## The task

Read-only audit of the history-pair generation path in `src/qa023_probe.zig` (`collect_histories`, `collect_histories_dfs_impl`, the visit-set construction) and of the 2B-3 deliverable:

1. **Are the collected histories legal and reachable?** Each must be a real move sequence from the empty-goban root under the corrected (post-`2B-FIX-KO`) ko rule.
2. **Are they *simple* paths, and is that the intended semantics?** Reference-semantics §1 keys on the visit-**set**; check what the code actually guarantees and whether duplicates or self-intersections can occur.
3. **Are the pairs genuinely visit-set-distinct?** The deliverable claims 93/93 (102/102 corrected). Reproduce independently — a different implementation, not a re-run.
4. **What is the sampling bias?** The collector is a DFS with a budget that takes the first K paths it finds. Quantify: how correlated are the K histories for one state (shared prefixes), and does the collector systematically miss short arrivals? This bears directly on whether the probe can ever detect C1 (history-dependence), since detecting it requires *contrasting* histories at the same state.
5. **The two bugs the author fixed** — identify them, confirm each fix, and state what a wrong fix would have produced.

## Acceptance

- An independent reproduction of the distinctness count (or a discrepancy).
- A stated bias characterisation for the sampler, with numbers.
- Per-item verdict: VERIFIED / PARTIAL / WRONG.
- One line: **can `2B-PROBE-FIX`'s C1 test rest on this generator, or does the generator need to be replaced to produce deliberately contrasting histories?** That is the decision this audit exists to inform.
- The wrong-answer pass rate of your own check.

## Deliverable

`docs/audits/2b-3-history-pairs-audit-<date>.md`. **Do not edit `src/`, `CLAIMS.md`, or any 2B-N deliverable.** Read-only.

**Read first:** `history-pairs-3x2-2026-07-29.md` (note its superseded-numbers banner), `reference-semantics-2026-07-29.md` §1, `probe-defect-2026-07-29/README.md` (what a vacuous probe looked like from the outside).
