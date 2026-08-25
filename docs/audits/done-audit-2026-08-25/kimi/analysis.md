# DONE audit — kimi arm (T948) analysis

**Auditor:** `kimi-k2.7` / T948  
**Date:** 2026-08-25  
**Rows audited:** 24 (12 control + 12 disjoint)

## Mechanical summary

| | count / fraction |
|---|---|
| Rows with a run record | 22 / 24 |
| Rows with a findings file at HEAD | 20 / 24 |
| Rows with all declared deliverables in git | 19 / 24 |
| Rows killed by runner/watchdog | 2 / 24 (T643, T921) |

## Judgement summary

| dimension | yes / complete | partial / mixed | no / none |
|---|---|---|---|
| `work_actually_done` (vs brief) | 17 | 4 | 3 |
| `verdict_accurate` | 23 | — | 1 |
| `absorbed` | 17 | 3 | 4 |
| `self_reported_or_verified` | verified 20 | partial 1 | self-reported 3 |
| `useful` | 16 | 5 | 3 |

**Important caveat:** this sample deliberately over-indexes failures, blocked/abandoned rows, and unconstrained tasks. The raw store has only 3.6% failure verdicts; this slice has 29.2% (7/24). Do not quote these fractions as the fleet-wide rate.

## Verdict accuracy

23 of 24 recorded verdicts match what actually happened.

The single inaccurate verdict is **T943**, which the store records as `pass` even though its own acceptance command (`sh tools/regression-moving-parts.sh`) was actively red on a clean host whenever Claude Code’s `caffeinate` was running. The row’s deliverables are in git, but the automated close was a false green.

## Absorption

17 rows reached durable artifacts that downstream readers can find (commits, register rows, cited docs). 3 rows are partially absorbed (deliverables committed but the active value is damaged or incomplete), and 4 rows produced nothing durable.

Notable absorption cases:

- **T421** — no machine acceptance existed, yet every re-pointed citation and the C10 checker are committed and now enforced. This is the positive control for the unconstrained stratum.
- **T683** — produced a complete 152-row landmark backfill, but the brief explicitly forbade the worker from editing the store or `MILESTONES.md`. No later commit applies these inferences, so the result is currently write-only.
- **T894** — the worker left without writing findings; the Orchestrator seat wrote them post-hoc and committed the code. The work is absorbed, but the close relied on seat rescue.
- **T924** — the doc and per-root CSV are committed and were used by **T929**, but the headline 7.585x projection was wrong until T929 corrected it.

## Verification vs self-report

20 rows have outcomes that something other than the worker’s own assertion established (git artifacts, downstream use, independent audit, or acceptance scripts).

3 rows are self-reported:
- **T683** — 152 landmark inferences with no downstream use.
- **T924** — wrong projection was the worker’s own unweighted mean; only corrected later by T929.
- **T943** — runner exit 0 on a broken acceptance script.

1 row is partially verified: **T387** (findings committed, but the key measurement was reproduced/repaired by T397 after the hang).

## Usefulness

16 rows would clearly leave the project worse off if they had never run. 3 are not useful (T842, T841, T921 — no output). 5 are mixed:
- **T387** — documented the bug and partial budget analysis; definitive measurements came from T397.
- **T643** — documented the watchdog defect and partial design; fix incomplete.
- **T683** — useful UNKNOWN census, but inferences are unabsorbed.
- **T924** — produced the data T929 needed, but published a misleading number.
- **T943** — inventory is useful; false-positive regression damages the suite.

## No-acceptance stratum in this slice

Two rows belong to the unconstrained/no-acceptance stratum:
- **T421** — fully verified and absorbed despite no machine acceptance.
- **T683** — complete deliverable, but only self-reported and not absorbed.

This is exactly the divergence the stratum was designed to surface: absence of an acceptance command does not preclude a good result, and presence of deliverables does not preclude a write-only one.

## Rows to re-open

**T943** should be re-opened. Its own acceptance command was failing at close, so a `pass` verdict is not defensible. The inventory doc is sound, but the regression script needs to be fixed before the row can claim success. The false-positive also contaminates `zig build test` whenever a Claude console is active.

**T643** is already `abandoned`; it does not need re-opening, but a successor task should finish the per-harness progress watchdog. The partial findings and regression script rescued by the seat provide a starting point.

## Single most important pattern

**A green runner exit and an in-git deliverable do not prove a row is good.** The most damaging case is T943: `tools/runner` recorded exit 0 and `managent done` closed the row `pass`, yet the acceptance test it declared was red on a clean host. The same pattern appears more benignly in T924, where deliverable-presence masked a 7.585x arithmetic error until T929 independently corrected it.

**What would disprove this pattern:** finding that T943’s acceptance was in fact green at close, or auditing the remaining `pass` rows and showing none have a broken acceptance command / a headline number that later had to be corrected.

The mechanical collector used for this audit is committed as `docs/audits/done-audit-2026-08-25/kimi/collector.py`.
