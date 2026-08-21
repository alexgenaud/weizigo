# P0 build audit
Auditor: DSPro/T254 · Date: 2026-08-01
Verdict: PASS

## Defect 1 — signal-killed acceptance
- Status: FIXED
- Evidence: Traced `cmdDone` in `src/managent/main.zig` (lines ~1760–1788). Before the fix (commit 64809e6), the code checked `acc_result.term.exited != 0` — accessing the `.exited` field of the `Child.Term` tagged union when `.signal` was the active variant. For a SIGKILLed child, the raw memory at `.exited` reads 0, making `0 != 0` → `false` → not rejected → silently PASS. After the fix (commit 39d57eb), the code uses `switch (acc_result.term)` dispatching on the active variant: only `.exited == 0` passes; `.signal`, `.stopped`, `.unknown` all report REJECTED with a diagnostic identifying the signal number. End-to-end trace confirmed by regression test (tools/regression-T227.sh Test 1): `kill -9 $$` as acceptance command → REJECTED with `"killed by signal 9"` → exit code 1.

## Defect 2 — deliverables= truncation
- Status: FIXED
- Evidence: Traced `parseDeliverablesFromBundle` (lines ~1521–1560). Before the fix, `dl_value` was extracted from `deliverables=` to `-->` without stopping at subsequent `key=` tokens. For meta line `deliverables=src/managent/main.zig acceptance=echo ok`, the pre-fix value was `src/managent/main.zig acceptance=echo ok`, and splitting on commas produced `src/managent/main.zig` and `src/managent/main.zig acceptance=echo ok` — the second token swallowed the `acceptance=` key. After the fix, a scan loop walks `dl_value` looking for whitespace followed by a token containing `=` (the signature of a subsequent key=value pair), truncating at the space position: `src/managent/main.zig`. Regression test Test 2 confirms: a bundle with both `deliverables=` and `acceptance=` → `managent done` succeeds (acceptance runs independently, deliverables parsed correctly).

## Defect 3 — empty skip-acceptance
- Status: FIXED
- Evidence: Traced `cmdDone` (lines ~1739–1743). Before the fix, `--skip-acceptance ""` was accepted silently. After the fix, `if (reason.len == 0)` triggers immediate rejection with exit code 1 and the diagnostic `"REJECTED: ... --skip-acceptance requires a non-empty reason"`. Regression test Test 3 confirms: `--skip-acceptance ""` → REJECTED.

## Defect 4 — acceptance serialization
- Status: FIXED
- Evidence: Traced `serializeState` and `parseStateJson`. The `TaskState` struct always had `acceptance` and `skip_acceptance_reason` fields (added in commit 64809e6, T217). `parseStateJson` read them. But `serializeState` did not write them before the fix — the fields were lost on every write/read cycle (the `add`→claim→done`→serialize` lifecycle). After the fix (commit 39d57eb), `serializeState` writes both fields as JSON (`"acceptance": "..."` / `null` and `"skip_acceptance_reason": "..."` / `null`). Confirmed: `rg '"acceptance"' docs/infra/managent/tasks.json` shows the field present in the live store with non-null values for tasks that have acceptance commands. `freeState` also frees both fields.

## Verdict rationale
All four defects are confirmed fixed by end-to-end code tracing and by passing regression tests (0 failures in `tools/regression-T227.sh` with isolated store). The `switch (acc_result.term)` dispatch correctly prevents signal-killed commands from reporting PASS. The `deliverables=` truncation scan correctly stops at the next `key=` boundary. Empty `--skip-acceptance` is rejected. Both acceptance fields survive serialize/parse round-trips. No live-kanban mutation. PASS.
