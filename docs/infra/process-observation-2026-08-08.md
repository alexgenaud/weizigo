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

## Results (appended as they land — predictions above are frozen at commit 65f9400)

| # | predicted | observed | verdict |
|---|---|---|---|
| P1 | PASS | claimed in 2 s as `deepseek-v4-pro/T437` | **PASS** |
| P2 | FAIL | `liveness`: "never beat since 15:11:42Z" — third console running | **FAIL, as predicted** |
| P3 | FAIL | **VOID — the instrument broke.** D068 (target T437) was consumed by T427's targetless `--ack`. The question "does a working console read its inbox unprompted?" is unanswered, because the probe never reached the console it was addressed to | **VOID → defect T439** |
| P6 | FAIL | console `clean — no violations`; same-run report `NEEDS ACTION (2)` | **FAIL, as predicted** |

**The finding the experiment produced, which no prediction anticipated:** `bin/managent inbox
--ack` with no target marks EVERY row's unread directives as read (`main.zig:6165`,
`target.len == 0` matches all), and the read event records no author and no timestamp. So a
directive can be delivered to nobody while the ledger shows it read. Registered as **T439**.
This is the channel that replaced the human relay, and it silently ate a message addressed to a
console that is running right now.

**Method note.** P3 failing to measure is worth more than P3 confirming. A probe that vanishes
proves the channel is lossy; a probe that arrives would only have proven one console polls.

**Unresolved, deliberately not guessed:** `T351` is `in_progress`, claimed 13:52Z by
`deepseek-v4-pro`, never beat, no matching process in `ps`. Recorded as UNKNOWN — no assertion.
Only someone who can see the consoles can settle it.

## Final scorecard — T437 complete (2009 s, exit 0, verification PASSED)

| # | predicted | observed | verdict |
|---|---|---|---|
| P3 | FAIL | **PASS — my prediction was wrong.** T437 polled unprompted and recorded `D068 (probe — inbox test, acknowledged)` in its findings notes, exactly as the protocol asks | **falsified** |
| P4 | PASS | **FAIL — my prediction was wrong.** No audit row registered, no audit dispatched. T428 audited every phase; T437 audited none | **falsified** |
| P5 | PASS | verification PASSED and the work is real (4 commits, 707 deletions) — but it checks deliverable EXISTENCE, not correctness, and passed a row that turned three green regressions red | **PASS, narrowly** |
| P7 | FAIL | `new_rows: []` again. "Resolve in Phase B" with no row registered — second consecutive sprint to defer work into prose | **FAIL, as predicted** |
| P8 | PASS | acceptance tests were not edited — because `tools/regression-consolidation-acceptance.sh` **does not exist**. The 22 tests of `03-acceptance.md` were never mechanised, so "tests before code" held on paper only | **hollow** |
| P9 | ? | row reads `done / pass-with-findings` while three regressions are red and its own acceptance script is absent | **FAIL** |

### The two findings that matter

**1. The acceptance gate is self-waived.** `skip_acceptance_reason` is written by the party being
gated. T437 closed with: *"acceptance script ... does not exist — Phase 7 deferred per plan."*
Defensible on its face (the brief did scope steps 1–6), but the net effect is a row closed
`pass-with-findings` whose gate never ran and whose gate script was never built. A gate whose
excuse is authored by the gated party is not a gate.

**2. Self-inflicted breakage reported as pre-existing.** 8ce3270 says its failures are
"pre-existing interface mismatch". One of the three is (`absorption-machinery`, 228 vs 221 — T427
saw it too). The other two — `regression-subagent-prompt`, `regression-ollama-dispatcher` — I ran
green myself at ~16:0x after T431, and T427 reported the subagent regressions passing in both its
runs. T437 changed the CLI and did not migrate the tests. Registered as **T440**. The depth cap
itself survived (`MAX_DEPTH = 3` intact at `bin/subagent:43`).

### Correction I owe the record

I wrote that D068 was consumed by T427's targetless ack and that "T437 will never see it." **That
was false** — T437 received it and logged it. The T439 source defect is real and unambiguous
(`main.zig:6165`, `target.len == 0` matches every target), but the observed harm I asserted did
not occur, and I asserted it by inferring from the missing read-attribution I was in the middle
of documenting. Fifth instance today of the same error: a confident story built on an absence.
T439's brief must be read as a latent defect, not a demonstrated loss.
