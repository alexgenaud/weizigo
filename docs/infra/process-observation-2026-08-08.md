# Process observation — predictions recorded BEFORE the run (2026-08-08)

The subject is not the code. It is the **process machinery**: the manager console, the dispatch
tools, the kanban status surface, the inbox, and the watchdog. T437 (implement the audited
consolidation plan) is the workload; this document is the instrument.

**Why predictions first:** the Orchestrator was wrong repeatedly today by narrating causes after
the fact. A prediction written before the measurement can be falsified; a story told afterwards
cannot. If a prediction below is wrong, that is the finding — do not quietly reinterpret it.

Recorded at commit time, before `bin/subagent T437` is run. Observer: claude-opus-5/orcha.

| # | prediction | expect | why |
|---|---|---|---|
| P1 | The console claims T437 | PASS | the dispatch tool injects the claim as the first instruction |
| P2 | `managent liveness` shows "never beat" for T437 | **FAIL** | heartbeats need a volunteered `MANAGENT_TASK_ID`; T428 and T427 both never beat. This is the T432 gap |
| P3 | A directive sent mid-run is acked without prompting | **FAIL** | the inbox is pull-based; T427 left D065/D067 unread for 3 h. I will send one and check |
| P4 | The console dispatches its own audit, no human relay | PASS | T431 made it possible and T428 did it four times |
| P5 | `dispatch_verify` verdict matches reality (nonce, exit, row state) | PASS | it correctly failed T430 (rc=124, no nonce, row still dispatchable) |
| P6 | `argus --mode doctor` console line reads "clean" despite NEEDS ACTION | **FAIL** | the T430 bug is unfixed; reproduced at 16:5x — console "clean", report "NEEDS ACTION (2)" |
| P7 | Deferred work is registered as a row, not just described in prose | **FAIL** | T428 wrote "deferred to a follow-on row" with `new_rows: []` and registered none |
| P8 | The 22 acceptance tests are run, not edited into passing | PASS | the bar is explicit in the T437 brief; watch the diff on `03-acceptance` tests |
| P9 | Row status after close matches what actually exists on disk | ? | genuinely unknown — T428 closed `pass-with-findings` while its own bundle path for T433 pointed at a missing file |

**Known contention, declared up front:** a `zig build test` from the T427 console is running
during this dispatch with two binaries at 100% CPU. Any wall-clock figure taken here is
contaminated and must not be quoted as a suite-cost measurement.

**Separate finding, already established without this run** — the documented 618 s suite baseline
is contradicted by three direct observations today (~35 min, ~44 min, and one in progress past
37 min), and by the week-close audit's 52-minute run with an UNRESOLVED verdict. The 618 s figure
carried in the handover should not be quoted again until re-measured on an idle machine.
