# T985 — Race B fail-transparency resolution

**Author:** gpt-5.6-luna-pro/T985  
**Date:** 2026-08-26  
**Landmark:** advances `L1 (the dashboard tells the truth)` — T963 can be implemented without turning a missing report into an invisible orphan, and its factual baseline and arm ledger become checkable.

This is a resolution of T964's round-1 audit of T963. I did not edit T963 or re-open S10's ratified direction. Each blocker below was checked against the repository before the replacement text was written.

## Verification record

The T963 bundle says that the close corpus at bundle time was 521 closed rows: 275 `pass`, 227 `pass-with-findings`, 12 `blocked`, and 7 `abandoned`. The pass-like numerator is therefore 502 and `502 / 521 = 96.35%`, which rounds to 96%, not 92%.

The T963-era repository snapshot (`2c3608b`, 2026-08-25T17:07:48+02:00) contains 536 `done` rows, of which 284 are `pass` and 232 are `pass-with-findings`: 516/536 = 96.27%. That is a later denominator and is reported separately here rather than substituted for the bundle's 521-row measurement. The working tree is concurrently dirty, so this resolution does not call an unpinned live count "current."

At the same snapshot, the task rows establish the two exemplar facts directly:

- `T948` has `status: done`, `verdict: pass-with-findings`, and a worker verdict note.
- `T959` has `status: done`, `verdict: fail-found`, and the note `T953 spec audit round 1: BLOCKERS (3) ...`.
- `T940` has a worker verdict note and impression and no auto-close marker.
- `T943` has the explicit `tools/runner auto-close: worker exited 0 without closing...` verdict note and no impression; its amendment says its acceptance was red. Thus T943 is the auto-close evidence. T940 is not.

The arithmetic in T963's S10 arm ledger is also direct: S10 §4 defines 21 unit arms (`A1`–`A21`) and four smoke arms (`SMOKE-1`–`SMOKE-4`), for 25 cited arms. T963 adds 8 `TC` arms, 3 `TW` arms, and 5 `SMOKE-T963` arms, for 16 new arms. The total is 41.

## Blocker 1 — missing reporting fields must not refuse the close

### Finding

T964 is correct. T963 §3.1, §3.5, and §6.3 make a missing reporting field refuse the close, while §6.4 lets the auto-close path close with the gap recorded. That is two contracts and recreates S10 §1.2's stranding failure: a refused worker close leaves an apparently live `in_progress` row. The ratified direction is always close, never strand, except for mechanically unambiguous conditions such as an absent declared deliverable or a failed acceptance condition.

A missing *reporting field* is not the same as an absent deliverable. The former is a reporting gap; the latter is a mechanical failure of the declared work product and remains an existing refusal gate. A missing field must therefore be recorded, not used to refuse the close.

### Exact replacement for T963 §3.1's reporting-field table and following rationale

Replace the §3.1 table and the rationale immediately following it with:

> | field | required on | verdict-affecting? | what missing does |
> |---|---|---|---|
> | **`delivered`** | all closes | no | the harness records `not-provided` in `reporting_gaps`; declared deliverables are still checked by the existing deliverable gate |
> | **`confidence`** | all closes | no | the harness records `not-provided` in `reporting_gaps`; for `blocked`/`abandoned`, the separate concern requirement still applies |
> | **`deferred`** | all closes | no | the harness records `not-provided` in `reporting_gaps`; explicit `[]` means none |
> | **`followups`** | all closes | no | the harness records `not-provided` in `reporting_gaps`; explicit `[]` means none |
> | **`retrospective`** | all closes | no | the harness records `not-provided` in `reporting_gaps`; an explicit sentence means supplied |
>
> The five fields remain required reporting content, but omission is not a close refusal. The close stores a structured `reporting` object and a `reporting_gaps` list. Each omitted field is represented as `not-provided`, never silently replaced by an empty string and never silently treated as `none`. An explicit `none` value is valid content and is distinct from omission.
>
> This is the S10 reconciliation: the harness computes and records the acceptance verdict whenever it can, and it records a reporting gap whenever the worker did not supply a report. A missing reporting field cannot strand a row. The existing narrow-A refusals remain only for an absent declared deliverable and a command acceptance that demonstrably failed; those are mechanically checked facts about the work, not missing commentary about it.

### Exact replacement for T963 §3.5

Replace all of §3.5 with:

> ### 3.5 Reporting gaps do not refuse; mechanical failures still do
>
> | situation | mechanism | outcome |
> |---|---|---|
> | acceptance condition `failed` (exit non-zero) | S10-CLOSE-2 narrow-A | **refused**, naming the condition and exit; the worker can fix it or close `blocked`/`abandoned` with a concern |
> | acceptance condition `unverified` or `cannot-run` | S10-CLOSE-2 | computed verdict **`unverified`**, with the reason stored |
> | reporting field omitted | this spec's reporting contract | close proceeds; field is `not-provided` and named in `reporting_gaps` |
> | declared deliverable absent from git | existing deliverable gate | **refused**, because presence is mechanically unambiguous |
>
> The principle is: refusal is reserved for a mechanically verified condition that says the declared bar was not met, or for an absent work product. A report omission is not such a condition. It is a gap in the account of the work, and the account must say so while the row still receives its verdict.
>
> The worker-close and auto-close doors use the same rule. A worker that omits `retrospective` is closed with `retrospective: not-provided` and a corresponding reporting gap. An auto-closer that has no report does exactly the same thing. Neither door may default the field to `none` or silently turn the row into a clean pass. Acceptance computation remains independent: an acceptance failure is refused, an uncheckable acceptance is `unverified`, and met acceptance plus deliverables can confirm the claimed pass.
>
> This preserves S10's always-close-never-strand rule without weakening the reporting contract. The contract requires the field to be accounted for; it does not pretend that an absent field was supplied.

### Exact replacement for T963 §6.3

Replace all of §6.3 with:

> ### 6.3 What a missing field costs — decided
>
> Missing `delivered`, `confidence`, `deferred`, `followups`, or `retrospective` does **not** refuse the close. The harness writes `not-provided` for that field, appends its name to `reporting_gaps`, and continues through the one computed-close path. The verdict is determined from acceptance conditions and deliverable presence exactly as S10-CLOSE-1/2 require.
>
> The explicit escape values remain meaningful: `delivered: []` with an explanation, `confidence: "no concerns — checked X"`, `deferred: []`, `followups: []`, and a one-sentence `retrospective` all satisfy their reporting fields. They are not interchangeable with omission. A missing report is visible and countable, but it cannot leave the task stranded in `in_progress`.
>
> This rule does not relax the existing refusal for an absent declared deliverable or a failed acceptance command. Those are mechanically verified failures of the declared bar. A missing commentary field is not.

### Blocker disposition

**Fixed.** The worker and auto-close paths now have one non-refusing reporting-gap contract. T964's blocker is accepted; its proposed fix is adopted.

## Blocker 2 — the pass rate is 96%, not 92%, for the bundle measurement

### Finding

T964 is correct. The 92% figure belongs to the earlier S10 measurement, not to the T963 bundle's 521-close measurement. The repository check above independently recomputed the bundle numerator: 275 + 227 = 502; 502/521 = 96.35%.

### Exact replacement for T963 §0's baseline paragraph/table

Replace the baseline table in §0 with:

> The baseline numbers are epoch- and snapshot-specific. The T963 bundle measured 521 closes: 275 `pass`, 227 `pass-with-findings`, 12 `blocked`, and 7 `abandoned`. Thus **502 of 521 closes were pass-like (96.35%, reported as 96%)**. The earlier S10 measurement of 444 pass-like closes (92% of its then-denominator) is not the T963 bundle measurement and must not be labelled "bundle time."
>
> A later repository snapshot at T963's commit (`2c3608b`, 2026-08-25T17:07:48+02:00) contains 536 done rows and 516 pass-like rows (96.27%). It is a separately denominated snapshot, not a replacement for the bundle's 521-close baseline.

### Exact replacement for T963 §5.2's Epoch 1 paragraph

Replace the final paragraph of §5.2 with:

> **Epoch 1 (pre-close-contract):** closes before the close contract lands use the worker-asserted or auto-asserted verdict and the deliverables gate. The T963 bundle's Epoch-1 measurement is **502 pass-like closes out of 521 (96.35%, rounded to 96%)**. The earlier S10-era measurement of 444/its then-denominator (92%) is a different dated snapshot and must retain that attribution. Post-contract computed-pass rates exclude `unverified` and are not comparable with either pre-contract rate.

### Blocker disposition

**Fixed.** The incorrect bundle attribution is removed, the denominator is stated, and the 92% S10-era number is retained only with its proper attribution.

## Blocker 3 — the fail-found exemplar is T959

### Finding

T964 is correct. The checked task rows show `T948` is `pass-with-findings`; `T959` is the single `fail-found` row in the T963-era snapshot. The count of one is correct, but T963 named the wrong row.

### Exact replacement for T963 §0's fail-found row

Replace the `fail-found` row in the §0 baseline table and its surrounding statement with:

> | `fail-found`, all time | **1 (`T959`)** in the T963-era repository snapshot; `T948` is `pass-with-findings` |
>
> The `fail-found` exemplar is T959, the T953 spec audit closed on 2026-08-25T13:55:34Z. T948 is not a `fail-found` row and must not be used as its exemplar.

### Blocker disposition

**Fixed.** The exemplar is corrected to T959; the correction is independently established from `tasks.json`, not inherited from the auditor.

## Blocker 4 — T940 was worker-closed; T943 is the auto-close evidence

### Finding

T964 is correct. `T940` carries a worker verdict note and a worker impression and does not carry the `tools/runner auto-close` marker. `T943` carries the explicit auto-close marker and the post-close amendment that its acceptance was red. T940 therefore cannot be cited as a second auto-close incident.

T940 may be retained only as a separate example of a pre-contract worker close: its row has an acceptance command but no computed acceptance-result field. It does not establish what the auto-close path did.

### Exact replacement for T963 §0's second-incident paragraph

Replace the paragraph beginning `A second row, T940` with:

> **T943 is the verified auto-close incident.** Its row was auto-closed after the worker exited 0 with deliverables present; its acceptance command was not checked by that close, and its later amendment records that the acceptance was red on the live host. `T940` is not a second auto-close: its row contains a worker verdict note and worker impression and has no auto-close marker. T940 may illustrate the old worker-close contract, but it is not evidence about the auto-close door.

### Exact replacement for T963 §6.4

Replace the opening evidence paragraph and the two bullets in §6.4 with:

> ### 6.4 The auto-close path must satisfy the same contract
>
> T943 is the repository-checked auto-close incident. It was closed from `tools/runner` on exit 0 plus deliverables-present evidence, without running its declared acceptance and without a worker-supplied report. T940 was worker-closed and is not part of this auto-close evidence. The auto-close path is nevertheless a second close door and must satisfy the same contract as `managent done`:
>
> - It runs the bundle-authored acceptance conditions before confirming `pass` or `pass-with-findings`. A failed condition refuses the clean-pass close; an uncheckable or infrastructure condition records computed `unverified` as required by S10-CLOSE-2.
> - It reads the attempt-local close report when one exists. Missing report fields are recorded as `not-provided` and listed in `reporting_gaps`; they are not silently defaulted to a clean report or used to strand the row. If no report exists, all five fields are accounted for as `not-provided`, while the acceptance-derived verdict is still computed.
>
> This is the direct fix for T943. The auto-close path is not exempt, and T940 is not misdescribed as evidence for it.

### Exact replacement for T963 §7's auto-close sequencing note

Replace the paragraph beginning `Sequencing note — the auto-close path is urgent` with:

> **Sequencing note — the auto-close path is urgent.** T943 is live evidence that the auto-close door can produce a false `pass` when it relies on exit 0 plus deliverable presence without running acceptance. T940 is a normal worker-close row and is not counted as a second auto-close incident. The implementation row should fix the auto-close path first enough to run the same acceptance and reporting-gap accounting as the worker-close path; the full worker-close contract and runner-liveness contract still land against this spec.

### Exact replacement for T963 §10.6

Replace §10.6 with:

> ### 10.6 The auto-close path exempted from the contract — rejected
>
> Exemption fails: T943 was auto-closed on process evidence while its own acceptance was later shown red. T940 does not alter that conclusion because it was worker-closed, not auto-closed. The auto-close path is one of the two close doors and must run bundle-authored acceptance conditions, compute the verdict, and account for every reporting field. Exempting it would reproduce the false-pass disease under a different door.

### Exact replacement for T963 §9.4 smoke-test references

In `SMOKE-T963-3` and `SMOKE-T963-4`, replace each `T943/T940` reference with `T943`; use this text for the incident clause:

> **Would have caught:** T943 — the auto-close path recorded `pass` from process evidence while the acceptance was red and no worker report was present. T940 is excluded because it was worker-closed, not auto-closed.

### Blocker disposition

**Fixed.** All auto-close claims now point to T943, and T940 is accurately retained only as a worker-close row if the implementation discussion needs that contrast.

## Blocker 5 — the arm count is 41, and the ledger must include every cited family

### Finding

T964 is correct. T963 omitted `TW-1`–`TW-3` from one headline total, called 32 cited arms when S10 defines 25, and its ledger omitted S10's `S10-ATTEMPT` and `S10-STORE` families. The corrected count is:

- S10 cited: 21 unit arms + 4 smoke arms = **25**.
- T963 new: 8 `TC` + 3 `TW` + 5 `SMOKE-T963` = **16**.
- Total: **41 arms**.

### Exact replacement for T963 §9.4 armed-count paragraph

Replace the armed-count paragraph at the end of §9.4 with:

> **Armed count:** S10 defines 21 unit arms (`A1`–`A21`) and 4 smoke arms (`SMOKE-1`–`SMOKE-4`), for **25 cited arms**. This spec adds 8 `TC` arms, 3 `TW` arms, and 5 `SMOKE-T963` arms, for **16 new arms**. The corrected total is **41 arms (25 cited + 16 new)**. The `TC`, `TW`, and `SMOKE-T963` identifiers are all included; none is silently omitted from the total.

### Exact replacement for T963 §11 arm ledger

Replace all of §11 with:

> ## 11. Arm ledger
>
> | id prefix | what it covers | arms | source |
> |---|---|---:|---|
> | `S10-ACCEPT-` | acceptance schema, dispatch gate, migration | 3 (`A1`–`A3`) | S10 §4 |
> | `S10-CLOSE-` | computed close, condition outcomes, one door | 3 (`A4`–`A6`) | S10 §4 |
> | `S10-VERDICT-` | harness-emitted `unverified` | 4 (`A7`–`A10`) | S10 §4 |
> | `S10-ATTEMPT-` | kill and attempt history | 5 (`A11`–`A15`) | S10 §4 |
> | `S10-STORE-` | store-loss detection | 4 (`A16`–`A19`) | S10 §4 |
> | `S10-CONCERN-` | concern channel | 2 (`A20`–`A21`) | S10 §4 |
> | `S10-SMOKE-` | cross-cutting end-to-end scenarios | 4 (`SMOKE-1`–`SMOKE-4`) | S10 §5 |
> | `TC-` | T816 reporting-field contract | 8 (`TC-1`–`TC-8`) | this spec §9.2 |
> | `TW-` | close/runner lifecycle and hold survival | 3 (`TW-1`–`TW-3`) | this spec §9.3 |
> | `SMOKE-T963-` | T963 end-to-end consolidation | 5 (`SMOKE-T963-1`–`SMOKE-T963-5`) | this spec §9.4 |
> | **total cited** | | **25** | S10 |
> | **total new** | | **16** | T963 |
> | **grand total** | | **41** | 25 + 16 |
>
> The 25 cited S10 arms are binding even where §9.1's reliance table shows only the subset relevant to T963. The remaining S10 arms (`A11`–`A19` and `A21`) remain binding on the implementation row; they are not absent merely because this spec does not re-explain them. The 16 new T963 arms include all `TC`, `TW`, and `SMOKE-T963` arms. Every new normative requirement in §§3–6 is covered by at least one of those 16 arms.

### Exact replacement for T963 §9.1's reliance-table preface

Immediately after the §9.1 opening sentence, add:

> The table below is only the subset of S10 arms directly relied on by the T963 prose. It is not a census of S10's arms. S10's remaining arms (`A11`–`A19` and `A21`) remain normative for the implementation row and are counted in the §11 ledger.

### Blocker disposition

**Fixed.** The ledger now counts and names all 41 arms, including the previously omitted attempt and store families and the three runner-lifecycle arms.

## Red flags — decisions, not deferrals

### Red flag 1: the runner-liveness mechanism is decided

Replace T963 §4.5 with:

> ### 4.5 Runner-exit mechanism — decided
>
> The contract does not signal or wait for the caller at close. `managent done` records the computed verdict and close timestamp and returns; killing the runner would risk cutting off legitimate post-close work, and waiting for the caller would be a paradox.
>
> The runner owns a lease for each attempt containing the runner PID and a process-start identity token. The runner's normal exit path records an explicit exit marker and releases its `held-by-closed-runner` holds. A reaper is the recovery path: it polls the recorded PID plus start token, and releases the holds only after it has positive evidence that that exact runner has exited. PID reuse is not accepted as exit evidence. The reaper must not release a hold on a timeout, an unreadable process table, or an ambiguous identity.
>
> If liveness cannot be checked, the row remains closed but visibly `runner liveness unknown, holds held`; it is alarmed for repair rather than silently released. Thus the three required outcomes are decided: no signal, no wait, and no unsafe release. The implementation may choose the host-specific process API behind this contract, but it may not change these outcomes or treat an inability to check as an exit.

This is not an open implementation question. The host-specific process-reading call is an implementation detail; the close behavior, lease identity, positive-exit requirement, and unknown-liveness escalation are the normative decision.

### Red flag 2: blocked/abandoned gets an available interim concern path

The repository check confirms that the T490 concern channel is specified but not yet implemented, while the existing `managent done` path already requires a non-empty `--note` for `blocked` and `abandoned`. The implementation cannot make those rows wait for a nonexistent command.

Replace T963's concern sequencing note with:

> **Interim concern decision.** Until T490's append-only concern channel lands, `managent done <id> --status blocked|abandoned --note <non-empty concern>` is the concern path. The existing note is copied to `verdict_note` and tagged in the close record as `concern_source: inline-note-v1`; absence or an empty value remains refused for these two asserted failure outcomes. The close does not wait for a disposition. When T490 lands, its inline sugar consumes the same payload and writes the canonical concern record; no second semantic concern mechanism is introduced. The implementation row must include the compatibility tag and a migration/read rule, so old note-backed failure closes remain legible.

This makes TC-8 implementable today without stranding `blocked`/`abandoned` rows and without inventing a third concern system. The eventual T490 channel remains the canonical append-only surface; the inline note is its explicitly bounded compatibility path, not a new verdict or disposition protocol.

### Red flag 3: reporting-field encoding is decided

Replace T963 §6.1 with:

> ### 6.1 Reporting-field encoding
>
> The worker supplies one JSON report file through `managent done <id> --report <path>`. The file is read before the close mutation and must be a JSON object with this logical shape:
>
> ```json
> {
>   "delivered": ["<path or explicit delivered item>"],
>   "confidence": "<statement>",
>   "deferred": ["<item and reason>"],
>   "followups": ["<task or suggestion>"],
>   "retrospective": "<one or two sentences>"
> }
> ```
>
> `delivered`, `deferred`, and `followups` are arrays of strings; `confidence` and `retrospective` are strings. An empty array is the explicit `none` value for an array field. For a string field, an explicit statement such as `"none — ..."` is the `none` value. A missing key is `not-provided`, not `none`; malformed or unreadable report input is recorded as `report-unreadable` and all fields not recovered from it are `not-provided`. The row stores the parsed values under `reporting` and stores missing-field names under `reporting_gaps`.
>
> The runner creates an attempt-local `close-report.json` path and passes that path in the attempt metadata. A worker can use that path when its close command cannot conveniently carry a repository path. On auto-close, the runner reads that sidecar if present; if it is absent, it records all five fields as `not-provided` and still computes the acceptance verdict. There is no prompt-and-wait requirement for a dead worker.
>
> This encoding is deliberately separate from acceptance: acceptance remains bundle-authored and is never supplied by `--report`. `--note` remains the inline concern compatibility path for `blocked`/`abandoned` until T490 lands. The reporting schema is therefore fixed for the implementation row; no implementer has to choose between CLI flags, an opaque blob, and silent nulls.

### Red-flag disposition

**Fixed.** The runner-liveness contract, interim concern path, and reporting encoding are now decisions with explicit failure behavior. Only host-specific process API details remain implementation details, not unresolved policy.

## Overall disposition

**PASS-WITH-FINDINGS for the audit resolution.** All five blockers are resolved with repository-checked facts and exact replacement text. The original T963 spec should be amended by its owner rather than edited by this sealed arm. The resulting implementation work must carry the corrected 41-arm ledger, run the S10 cited arms as well as T963's 16 new arms, and preserve the non-stranding and visible-liveness rules above.

This task did not build code or run implementation tests; that is appropriate because the deliverable is a specification resolution. The implementation row must test the reporting-gap null controls, the T943 auto-close regression, the TW dangerous-window arm, and the interim blocked/abandoned concern path before it can claim the contract is green.
