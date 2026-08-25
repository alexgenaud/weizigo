# T980 — Race B fail-transparency (dsflash): resolution of audit-1's five blockers

**Task:** T980 · **Arm:** Race B fail-transparency, dsflash · **Author:** deepseek-v4-flash/T980
**Date:** 2026-08-25 · **Inputs:** `docs/epics/E1-markovian/L1-dashboard/T963/spec.md` (spec under
audit), `untracked/L1/T963/spec/audit-1.md` (VERDICT: BLOCKERS (5), three red flags, two notes),
`docs/epics/E1-markovian/L1-dashboard/S10-failure-transparency/spec.md` §1/§2.1/§2.2/§4 (ratified),
the T963 bundle (`untracked/T963-close-contract-spec.md`).
**Landmark:** advances `L1 (the dashboard tells the truth)`.

This is a **sealed arm** of Race B. I did not read any sibling arm's output
(`untracked/races/B-failtrans/` outside my own directory, or the sibling dspro arm). Every factual
claim below was checked against the repository: the T963 bundle, the S10 spec, the T963 spec, and
the live store (`docs/infra/managent/tasks.json`) at both spec-commit time (`2c3608b`,
2026-08-25T15:07:48Z, 585 rows) and audit-1 time (`b39b20c`, 2026-08-25T16:23:33Z, 587 rows).

**Method:** for each blocker I (1) restated it, (2) re-derived the underlying fact myself from the
repository rather than trusting the auditor, (3) ruled whether the auditor is right (all five are —
but three needed independent re-derivation, which is what I did), and (4) wrote exact replacement
text, mapped to the spec's sections. Then the three red flags, then the two notes. I reached all
of it; nothing is left unreached.

## Summary of rulings

| # | blocker | auditor right? | core fix |
|---|---|---|---|
| 1 | missing reporting field → "refused" contradicts the brief and S10 | **yes** | missing field is **recorded as not-provided**, close lands, verdict computed from acceptance — §6.4's own treatment, made uniform across both doors |
| 2 | measured pass rate misstated (92% vs 96%) | **yes** | bundle measured **502 of 521 (96%)**; 444/92% is S10's 2026-08-24 number, labelled as such |
| 3 | fail-found exemplar wrong | **yes** | the one fail-found row is **T959**, not T948 (T948 is pass-with-findings) |
| 4 | T940 was not auto-closed | **yes** | T940 is worker-closed (note + impression present, no auto-close marker); delete the auto-close attribution; T943 alone carries the argument |
| 5 | armed count wrong and inconsistent | **yes** | **25 cited + 16 new = 41**; stated once, ledger lists all of S10's arms including S10-ATTEMPT and S10-STORE |

The auditor is right on all five. I found no blocker where the auditor's correction was itself
wrong. One audit *note* (the "clean host" note) misattributes a phrase to §0 that is actually the
bundle's — see Notes, B.

---

# BLOCKER 1 — §3.1 / §3.5 / §6.3: missing reporting field → "refused" contradicts the brief and S10

## Statement

The spec decides each missing reporting field (`delivered`, `confidence`, `deferred`, `followups`,
`retrospective`) is **refused** (§3.1 table "what missing does"; §6.3 "A missing required field
refuses the close"). The T963 bundle's decision 4 says the opposite: *"a refused close strands, so
a missing field cannot simply refuse."* The bundle's ratified direction (carried in the spec's own
§2) is *"the close is never refused except where deliverables are declared and absent."* S10 §1.2
measured the refusal failure twice on 2026-08-23: T818 complete-but-unclosed read as orphaned for
two hours; sixteen tasks read as in flight while zero were alive. §3.5's "reconciliation" —
"refusal with an available path is not stranding … it is `in_progress` with a clear instruction" —
is the exact argument S10 §1.2 falsified. The spec is also internally inconsistent: §6.4 gives the
auto-close door a *different* treatment (missing field → "record[ed] … as not-provided", close
lands with the computed verdict), so a worker whose `done` is refused can simply exit and be
auto-closed with the gap recorded — the refusal achieves one round-trip and nothing else.

## My fact-check (not the auditor's word)

1. **The bundle's decision 4** (`untracked/T963-close-contract-spec.md`): *"Decide which are
   required, which are optional, and what a missing one costs — **a refused close strands, so a
   missing field cannot simply refuse**."* — verified, verbatim.
2. **The bundle's ratified direction** (same file): *"the close is never refused except where
   deliverables are declared and absent."* — verified, verbatim.
3. **S10 §1.2** (`S10-failure-transparency/spec.md`): *"A refused close leaves the task
   `in_progress`, which is indistinguishable from a live worker. Measured twice on 2026-08-23 —
   T818 complete-but-unclosed read as orphaned for two hours, and sixteen tasks read as in flight
   while zero were alive. **A verdict that cannot be recorded becomes a lie of a different kind.**
   So: **always close, never strand — but close honestly.**"* — verified, verbatim.
4. **S10 §1 decision D**: *"the close computes what it can, records `unverified` for what it
   cannot, and never refuses to record an outcome except where there is nothing to record it
   about."* — the refusal carve-out is deliverables-absent (mechanically unambiguous) and, per
   S10-CLOSE-2, a *verified-failed* acceptance. A missing reporting field is in neither.
5. **The internal inconsistency** — §6.4 (verified in the spec): a missing field on the auto-close
   door is "record[ed] … as not-provided" and the close lands with the computed verdict; §3.1/§6.3
   refuse it on the worker door. Same gap, two opposite costs.

## Verdict

**The auditor is right.** The refusal is a direct contradiction of the bundle's decision 4 and of
S10's always-close-never-strand; the §3.5 "reconciliation" is relabelling, and §6.4 already proves
a coherent non-refusal treatment exists in the same document. The fix is to make §6.4's treatment
(the close lands; the missing field is recorded as not-provided on the row; the verdict is computed
from acceptance) the uniform contract for both doors, and to keep refusal only for S10's two
mechanically/empirically unambiguous cases: deliverables absent from git (narrow-A, already works)
and a verified-failed acceptance (S10-CLOSE-2). The operator's honest-close intent — "not just 'I
did a thing'" — is served by the gap being *visible and never silently defaulted*, not by refusal;
silence-as-recorded-gap is not silence-as-pass.

## Replacement text (drop-in)

### §3.1 — replace the "what missing does" column and the `delivered` row

The original table's `delivered` row conflates the narrative report field with the
deliverables-in-git mechanical gate. They are different things and must not share a cell. Replace
the whole table with:

| field | required on | verdict-affecting? | what missing does |
|---|---|---|---|
| **`delivered`** (report field: what was produced, per acceptance condition) | all closes | **no** — the verdict comes from the checked acceptance conditions (S10-CLOSE-2), never from the report | **recorded as not-provided on the row**; the close lands with the verdict computed from the acceptance. (The *deliverable files absent from git* gate is separate: mechanically unambiguous, already enforced by `managent done`, and refused — S10 §1.3 narrow-A. A missing `delivered` *report* is not that gate.) |
| **`confidence`** | all closes | no | **recorded as not-provided**; on `pass`/`pass-with-findings`/`fail-found` an explicit "no concerns — here is what I checked" satisfies it; on `blocked`/`abandoned` a reason in `verdict_note` satisfies it until the T490 concern channel lands (S10-CONCERN-1), then ≥1 concern record via that channel (§7) |
| **`deferred`** | all closes | no | **recorded as not-provided**; explicit "none" satisfies it |
| **`followups`** | all closes | no | **recorded as not-provided**; explicit "none" satisfies it |
| **`retrospective`** | all closes | no | **recorded as not-provided**; one or two sentences satisfies it |

Follow with:

**Why these are required and not optional:** the operator's 2026-08-23 ruling (T816 §0) is explicit —
*"Perhaps an honest evaluation, concerns, follow-up suggestions, retrospective, deferred items should
be required."* The measured hole (T816 §1) is that 21% of closed tasks carry no verdict note at all
and only 29% carry a model impression. Optional fields default to silence; silence is the disease.
Required fields with an explicit escape ("none, because…") are the cure.

**Why a missing field is not a refusal (the reconciliation, §3.5):** a missing field is a gap the
worker *could* have filled, but the close cannot wait for it — the worker may already be gone
(T943's worker exited before the auto-close; the auto-close door is one of the two close doors,
T816 §5). Refusing the close over a missing field strands it in `in_progress`, indistinguishable
from a live worker — measured twice on 2026-08-23 (S10 §1.2). So the close lands, computes the
verdict from the acceptance, and records the missing field as **not-provided** on the row: visible,
never silently defaulted, never a clean `pass` unless the acceptance met. This satisfies S10's
"always close, never strand" *and* the operator's honest-close intent: a close with a recorded
reporting gap is honest in a way a silent `pass` is not.

### §3.3 — replace "What this spec adds to the computed close"

Replace:

> A close that has all acceptance conditions met but is missing `retrospective` is **refused**
> (missing reporting field), not `unverified` (the acceptance was checkable — it was met). The two
> mechanisms compose: acceptance conditions determine the verdict; reporting fields determine
> whether the close is honest enough to record. A close can have a computed `pass` verdict and
> still be refused for a missing `retrospective` — the verdict is available, but the close is not
> honest. The worker adds the field and re-closes; the verdict stands.

with:

> A close that has all acceptance conditions met but is missing `retrospective` is **closed with
> the computed verdict and `retrospective` recorded as not-provided on the row** — not refused
> (the worker may be gone; refusal strands, S10 §1.2) and not `unverified` (the acceptance was
> checkable — it was met). The two mechanisms compose: acceptance conditions determine the
> verdict; reporting fields determine what is **recorded** — a missing field is recorded as
> not-provided, never silently defaulted. A close can have a computed `pass` verdict and a
> recorded reporting gap; the verdict is computed, the close is honest, and the gap is visible.

### §3.5 — replace the situation/outcome table and the principle paragraph

Replace the table with:

| situation | mechanism | outcome |
|---|---|---|
| Acceptance condition `failed` (exit non-zero) | S10-CLOSE-2 narrow-A | **refused** — names the condition + exit; worker can fix and re-close, or close `blocked`/`abandoned` with a reason (`verdict_note` now; T490 concern once the channel lands) |
| Acceptance condition `unverified` (kind `uncheckable`) | S10-CLOSE-2 | verdict = **`unverified`** — no refusal, the close records honestly; the worker cannot make it checkable |
| Acceptance condition `cannot-run` (infra fault) | S10-CLOSE-2 | verdict = **`unverified`** — same as uncheckable; the fault is recorded, not the worker's |
| Reporting field missing (`delivered`, `confidence`, `deferred`, `followups`, `retrospective`) | this spec §6.1 | **recorded as not-provided on the row**; close lands with the verdict computed from the acceptance; never silently defaulted; never a clean `pass` unless the acceptance met |
| Deliverable absent from git | existing gate (S10 §1.3) | **refused** — mechanically unambiguous; this is S10's narrow-A that already works |

Replace the principle paragraph with:

**The principle:** refusal is for *verified negatives and mechanically unambiguous gaps* — a failed
acceptance (the work demonstrably failed its own bar) and an absent deliverable (nothing to record
the work about). `Unverified` is for *gaps no one at close time can fill* (acceptance declared
uncheckable, or an infrastructure fault preventing the run). A missing reporting field is *a gap
the close must not wait for*: the worker may have exited, and refusing strands (S10 §1.2, measured
twice). The close lands, computes the verdict, and records the gap as not-provided — visible on the
row, never silent. S10's "always close, never strand" applies to every close; the reporting
contract is satisfied by *recording*, and the operator's "not just 'I did a thing'" is served by a
computed verdict plus a visible reporting gap, not by refusal.

Replace the edge-case paragraph with:

**Edge case — a close that is both gap-marked (missing field) and would be unverified (acceptance
uncheckable):** both land — the row is closed with verdict `unverified` and the missing field
recorded as not-provided. There is no refusal to precede it. This is the honest path: the missing
field is a recorded reporting gap, the uncheckable acceptance is the verdict modifier.

### §6.1 — replace the five "Missing → refused" consequences

For each of the five fields, replace "**Missing → refused.**" with:

> **Missing → recorded as not-provided on the row.** The close lands; the verdict is computed from
> the checked acceptance conditions. Explicit "none" satisfies the field.

(The `delivered` row keeps the pointer that *deliverable files absent from git* is the separate
narrow-A refusal, unchanged.)

### §6.3 — replace in full

Replace:

> A missing required field **refuses the close**, naming the missing field and giving the path to
> satisfy it (add the field, re-close). This is **not stranding** (§3.5): the worker can always
> clear the gate. The refusal is loud, specific, and actionable — not a silent default to `pass`.

> **This is the reconciliation with S10's "always close, never strand":** S10's "never strand"
> applies to the verdict — a row must always receive a verdict, even if that verdict is
> `unverified`. T963's "refuse missing fields" applies to the reporting contract — a close must
> always record the five fields. These are different gates on different things. A row can be
> closed with verdict `unverified` (S10's "never strand" satisfied) while its reporting fields are
> all present (T963's contract satisfied). A row whose reporting field is missing is `in_progress`
> with a clear instruction — not stranded, because the path to close is explicit and short.

with:

> A missing required field is **recorded as not-provided on the row**; the close lands with the
> verdict computed from the acceptance. The cost of a missing field is **visibility** — the gap is
> recorded and rendered, never silently defaulted to a clean `pass`. A worker that fills all five
> fields (or their explicit "none" escapes) closes clean; a worker that omits one closes with a
> visible gap and a computed verdict. Refusal is reserved for S10's two cases: a verified-failed
> acceptance (S10-CLOSE-2) and an absent deliverable (S10 §1.3) — both mechanically/empirically
> unambiguous, neither a reporting field.

> **This is the reconciliation with S10's "always close, never strand":** S10's "never strand"
> applies to the verdict — a row must always receive a verdict, even if that verdict is
> `unverified`. The reporting contract applies to the record — a close must always record the five
> fields, and record what it could not collect as not-provided. These are different things, and
> neither refuses the close over a reporting field. A row with an uncheckable acceptance is closed
> `unverified` (S10's "never strand" satisfied); a row with a missing `retrospective` is closed
> with the computed verdict and the gap recorded (the reporting contract satisfied honestly). The
> only refused closes are the two S10 refusals, and neither strands: a failed acceptance has the
> two failure verdicts always available, and an absent deliverable is a verified negative.

### §10.3 — replace the rejected-option reasoning

The rejected option is a **silent** best-effort default. The adopted option is a **visible**
recorded gap. Replace the last two sentences of §10.3:

> A "best-effort" default that silently fills missing fields with empty strings would reproduce the
> disease under a new name. Required fields with an explicit "none" escape are the cure: silence is
> refused, but the worker can always satisfy the gate with an explicit statement.

with:

> A "best-effort" default that silently fills missing fields with empty strings would reproduce the
> disease under a new name. Required fields with an explicit "none" escape, and a missing field
> recorded **as not-provided** (never silently defaulted), are the cure: silence becomes a visible
> reporting gap on the row, and the verdict is still computed from the checked acceptance — the
> close is honest even when the record is incomplete.

### §9.2 — TC-1..TC-5 "must" columns

Replace each "**refused**, names `X` as missing; store unmutated" with:

> close **lands**; verdict computed from the checked acceptance; `X` **recorded as not-provided**
> on the row; the row is not a clean `pass` unless the acceptance met

per field: TC-1 `delivered`, TC-2 `confidence`, TC-3 `deferred`, TC-4 `followups`, TC-5
`retrospective`. The "would have caught" columns stay (the "I did a thing" close now lands with a
visible gap instead of a clean pass — the honest-close intent is still caught and now also served).
TC-6 (all fields present) is unchanged. TC-8's gating is handled under red flag 2 below.

### §9.4 — SMOKE-T963-2 assert column

Replace:

> close refused, names the missing field, worker re-closes with it and the close lands

with:

> close lands with the verdict computed from the acceptance and `retrospective` recorded as
> not-provided; the reporting gap is visible on the row; the worker (if reachable) can amend the
> field

---

# BLOCKER 2 — §0 / §5.2: the measured pass rate is misstated (92% vs 96%)

## Statement

The T963 bundle's measured baseline is *"521 closes: 275 `pass`, 227 `pass-with-findings`, 12
`blocked`, 7 `abandoned`"* — i.e. **502 of 521 = 96%**, not 92%. The spec's §0 table puts **"444
(92% of closes)"** in the "bundle/S10 number" column and §5.2 calls the Epoch 1 figure **"92%
(bundle time)"**. 444/92% is S10's 2026-08-24 measurement, not the bundle's. The bundle never says
444 or 92% as a measurement (its only "92%" is rhetorical: *"It cuts against us if the honest
close rate turns out to be far below 92%"*).

## My fact-check

1. **The bundle's numbers** (`untracked/T963-close-contract-spec.md`): "521 closes: **275 `pass`,
   227 `pass-with-findings`, 12 `blocked`, 7 `abandoned`**. `fail-found`: zero." — verified,
   verbatim. 275+227 = 502; 502/521 = **96.35% → 96%**.
2. **S10's numbers** (S10 §0): "closed `pass` / `pass-with-findings` | **444** (92% of all
   closes)" — that is S10's 2026-08-24 measurement, and the spec's "bundle/S10 number" column is
   where the bundle's numbers live (the same column holds "12 of 45", "123 / 573 (21%)", "0 in the
   store at bundle time" — all bundle figures).
3. **The live store** at spec-commit time (`2c3608b`): 536 done rows, 516 pass/pass-with-findings
   = **96.3%**; at audit time (`b39b20c`): 544 done, 524 pass/pwf = **96.3%**. The live figure is
   96%, consistent with the bundle's 96% — both columns should read 96%. (The spec's live "515 of
   535" was its own earlier read; it rounds to 96% either way.)
4. **The bundle's only "92%"**: the Landmark line — *"It cuts against us if the honest close rate
   turns out to be far below 92%."* — rhetorical, not a measurement. Verified.

## Verdict

**The auditor is right.** The bundle measured 502/521 = 96%; the spec mis-cites 444/92% into the
bundle column and labels it "bundle time" in §5.2. This is load-bearing because §5.2 anchors the
Epoch 1 boundary (S10-VERDICT-4) to a number the bundle did not measure.

## Replacement text (drop-in)

### §0 table, row 1

Replace:

> | closed `pass` / `pass-with-findings` | 444 (92% of closes) | 515 of 535 closed (96%) |

with:

> | closed `pass` / `pass-with-findings` | 502 of 521 (96%) — the bundle's measured baseline (275 `pass` + 227 `pass-with-findings`). S10's 2026-08-24 measurement (444, 92%) is a different epoch and is not the bundle's number | 516 of 536 closed (96%) |

### §0 item 1

Replace "**The 92%-pass surface is mostly self-report.**" with "**The 96%-pass surface is mostly
self-report.**" (the sentence and the rest of the paragraph are unchanged; the point — most closed
rows read as a pass, self-graded — holds at 96% at least as strongly).

### §3.4 S10-VERDICT-4 citation

Replace:

> **S10-VERDICT-4 (cited, extended in §5):** the 92%-pass baseline is redefined with a dated epoch note.

with:

> **S10-VERDICT-4 (cited, extended in §5):** S10's 92%-pass baseline (its own 2026-08-24
> measurement; the T963 bundle's is 96% — 502 of 521) is redefined with a dated epoch note.

### §5.2 Epoch 1 label

Replace:

> Pass-rate = (pass + pass-with-findings) / total closes. **This is the 92% (bundle time) / 96%
> (live) figure.** It is a measurement of self-report, not of verified completion.

with:

> Pass-rate = (pass + pass-with-findings) / total closes. **This is the 96% figure — 502 of 521
> (96%) at bundle time, 96% live (516 of 536 at spec writing).** It is a measurement of
> self-report, not of verified completion. (S10's 444/92% was its own 2026-08-24 measurement — a
> different epoch; it must never be labelled "bundle time".)

### §9.4 SMOKE-T963-5 "would have caught" column

Replace "the 92%-pass surface hiding unverified and self-reported work (S10-VERDICT-4; §5.2)" with
"the 96%-pass surface hiding unverified and self-reported work (S10-VERDICT-4; §5.2)".

---

# BLOCKER 3 — §0: the fail-found exemplar is wrong (T948 is not fail-found)

## Statement

The spec's §0 table says `fail-found`, all time: "1 (`T948`)". The single `fail-found` row in the
store is **T959** (the T953 spec audit round 1, verdict `fail-found`). T948 is
`pass-with-findings`. The count "1" is right; the exemplar is wrong.

## My fact-check

From `docs/infra/managent/tasks.json` at both spec-commit time (`2c3608b`) and audit time
(`b39b20c`):

- Exactly one row has `verdict: fail-found`: **T959**. Its `verdict_note`: "T953 spec audit round 1:
  BLOCKERS (3) — title-gate row false (already compliant), assign --exclude needs a decision
  change, ollama arm already green". Its attempt started 2026-08-25T13:44:57Z (audit says closed
  13:55:34Z — before this spec was committed at 15:07:48Z).
- **T948** has `verdict: pass-with-findings` (title "DONE audit arm (kimi)"); `verdict_note`:
  "24 rows audited; T943 closed pass while its own acceptance command was red." Its attempt
  started 2026-08-25T14:36:30Z — after T959 closed. T948 is a DONE-audit arm, not a fail-found row.

## Verdict

**The auditor is right.** The count is correct; the exemplar is wrong. (Note: the T963 spec's own
findings file repeats the same T948 mistake — the error is not the auditor's invention.)

## Replacement text (drop-in)

### §0 table, row 2

Replace:

> | `fail-found`, all time | 0 in the store at bundle time | 1 (`T948`) |

with:

> | `fail-found`, all time | 0 in the store at bundle time | 1 (`T959`) |

and append after the table:

> The single `fail-found` row is **T959** (the T953 spec audit, round 1, closed 2026-08-25). T948
> is `pass-with-findings` — a DONE-audit arm (24 rows audited, T943's close among them), not a
> fail-found.

---

# BLOCKER 4 — §0 / §6.4 / §7 / §10.6: T940 was not auto-closed

## Statement

The spec states *"A second row, T940 (closed 2026-08-25T10:20:04Z, `acceptance: sh
tools/regression-no-key-env-guard.sh`, verdict `pass`), was auto-closed the same way — exit 0,
deliverables present, acceptance command never run."* That is false: T940 was closed by its worker.
The claim is repeated as fact in §6.4, §7, §10.6, and SMOKE-T963-3.

## My fact-check

From the store at audit time (`b39b20c`):

- **T940**: `verdict_note` = "Removed DEEPSEEK_API_KEY env guard; keys resolve in pi";
  `impression` = "Clean removal of obsolete env guards; test-first red->green on all providers
  without env keys"; `note` = null; **no auto-close marker**. Attempt: gemini-3.7-flash, start
  2026-08-25T10:09:17Z, wall 658.6s (exit ~10:20:14Z — the worker closed near its own process end,
  consistent with the spec's 10:20:04Z).
- **T943** (the row that was auto-closed): `verdict_note` = "tools/runner auto-close: worker exited
  0 without closing; all declared deliverables present; the worker reported no status and no
  impression — this c…" — the auto-close marker. Same marker on T786, T880, T872, T906, T904,
  T933, T908, T796, T926, T912, T798. **Not on T940.**
- The T963 bundle names only **T943** for the failing-acceptance claim ("T943 shipped a gate that
  is red on a clean host"); it never names T940. The spec's §0 invented the T940 attribution.
- Whether T940's acceptance was *run* at close time is not recorded anywhere — under the old
  contract the close did not run acceptance commands, so this is true of every old-contract close
  (including T943's if it had been worker-closed). It is a contract-wide property being fixed, not
  a property of the auto-close door.

## Verdict

**The auditor is right.** T940 was a normal worker close under the old contract. T943 alone fully
carries the auto-close-door argument; nothing downstream changes except the false data point.

## Replacement text (drop-in)

### §0 — replace the T940 paragraph

Replace:

> A second row, **T940** (closed 2026-08-25T10:20:04Z, `acceptance: sh
> tools/regression-no-key-env-guard.sh`, verdict `pass`), was auto-closed the same way — exit 0,
> deliverables present, acceptance command never run.

with:

> (The bundle counted a second row — T940, closed 2026-08-25, `acceptance: sh
> tools/regression-no-key-env-guard.sh`, verdict `pass` — but T940 was **not** auto-closed: it was
> closed by its worker, with a real verdict note and impression and no auto-close marker. It is an
> old-contract worker close whose acceptance was never *computed* at close time — the
> contract-wide property this spec fixes, not an auto-close-door defect. T943 alone demonstrates
> the auto-close failure mode.)

### §6.4 — first sentence and closing line

Replace "T943 and T940 were auto-closed by `tools/runner` on exit 0 + deliverables present,
**without running the acceptance command and without collecting the reporting fields.**" with
"T943 was auto-closed by `tools/runner` on exit 0 + deliverables present, **without running the
acceptance command and without collecting the reporting fields.** (T940, the bundle's second
counted row, was worker-closed — an old-contract close whose acceptance was never computed; it
shows the contract-wide gap, not the auto-close door.)"

Replace "**This is the direct fix for the T943/T940 incident:**" with "**This is the direct fix for
the T943 incident:**".

### §7 — sequencing note

Replace "T943 and T940 are live evidence that the auto-close door produces false `pass` verdicts
today." with "T943 is live evidence that the auto-close door produces a false `pass` verdict
today."

### §10.6 — first sentence

Replace "T943 and T940 are the evidence that exemption fails." with "T943 is the evidence that
exemption fails."

### §9.4 — SMOKE-T963-3 "would have caught" column

Replace "T943/T940 — the auto-close door producing false `pass` on a failing acceptance (§0, §6.4)"
with "T943 — the auto-close door producing a false `pass` on a failing acceptance (§0, §6.4)".
SMOKE-T963-4's column already cites only T943's amendment — unchanged.

### §11 — "Rejected arms" first bullet

Replace "A separate arm for **"two rows closed pass with failing acceptance" (T943/T940):**" with
"A separate arm for **"a row closed pass with a failing acceptance" (T943):**".

---

# BLOCKER 5 — §9.2 / §9.4 / §11: the armed count is wrong and internally inconsistent

## Statement

The bundle's acceptance #2 requires "the armed count is stated and correct." It is not. Correct
count from S10's own ledger and this spec's tables: S10 cited = 21 unit arms (A1–A21) + 4 smoke
(SMOKE-1..4) = **25**; this spec new = 8 (TC-1..8) + 3 (TW-1..3) + 5 (SMOKE-T963-1..5) = **16**;
**total = 41**. The spec states three mutually inconsistent numbers: §9.4 "38 total, of which 13
are new" (omits TW-1..TW-3); §11 total row "32 cited + 16 new = 38" (32+16 is 48; "32 cited" is
wrong — S10 has 25; the ledger omits S10-ATTEMPT A11–A15 and S10-STORE A16–A19); §11 note "S10's
32 + this spec's 16 … 38 of 38".

## My fact-check

1. **S10's own ledger** (S10 §6, "S10-ARM-LEDGER"): S10-ACCEPT 3 (A1–A3) + S10-CLOSE 3 (A4–A6) +
   S10-VERDICT 4 (A7–A10) + S10-ATTEMPT 5 (A11–A15) + S10-STORE 4 (A16–A19) + S10-CONCERN 2
   (A20–A21) = **21** unit arms; plus S10 §5 SMOKE-1..4 = **4**; total **25**. Verified.
2. **This spec's new arms**: TC-1..TC-8 (§9.2) = 8; TW-1..TW-3 (§9.3) = 3; SMOKE-T963-1..5 (§9.4)
   = 5; total **16**. Verified by counting the tables.
3. **Total = 41.** The spec's §9.4 arithmetic (21+4+8+5 = 38) is internally consistent but **omits
   TW-1..TW-3 from both totals** — 38 should be 41, and "13 new" (8+5) should be 16 (8+3+5).
4. **§11 total row**: "32 cited + 16 new = 38" — 32+16 = 48, not 38; "32 cited" is wrong (S10 has
   25); the ledger table's cited rows sum to 16 (3+3+4+2+4), omitting S10-ATTEMPT (5) and
   S10-STORE (4) — 16+5+4 = 25. Verified.
5. **§11 note**: "S10's 32 + this spec's 16 … 38 of 38" — same two errors (32 wrong, 32+16≠38).
6. **Coverage**: the auditor found the *coverage* claim fine — no unarmed new normative id in
   §3–§6 — and I agree after re-reading: the five fields are TC-1..5, grandfathering TC-7,
   blocked-no-concern TC-8, close-stops-worker TW-1..3, epochs SMOKE-T963-5, auto-close
   SMOKE-T963-3/4; §3.2–§3.4 ride the cited S10 arms A1–A10. Only the *count* is broken.

## Verdict

**The auditor is right.** One number, stated once: **25 cited + 16 new = 41**.

## Replacement text (drop-in)

### §9.4 — replace the "Armed count" paragraph

Replace:

> **Armed count:** S10's 21 arms (A1–A21, cited) + S10's 4 smoke tests (SMOKE-1..4, cited) + this
> spec's 8 new arms (TC-1..TC-8) + this spec's 5 new smoke tests (SMOKE-T963-1..5) = **38 total
> arms, of which 13 are new to this spec.** The armed count equals the normative id count — every
> id in §3, §4, §5, §6 carries ≥1 arm, and no id is left as prose.

with:

> **Armed count: 41 total** — S10's 21 unit arms (A1–A21, cited) + S10's 4 smoke tests
> (SMOKE-1..4, cited) + this spec's 8 new arms (TC-1..TC-8) + this spec's 3 new arms (TW-1..TW-3)
> + this spec's 5 new smoke tests (SMOKE-T963-1..5) = **41 total arms, of which 16 are new to this
> spec.** Every normative id in §3, §4, §5, §6 carries ≥1 arm, and no id is left as prose. (Prior
> text omitted TW-1..TW-3 from both totals, stating 38/13; corrected here.)

### §11 — replace the arm ledger table and the total row

Replace the ledger table with the complete one (S10's full ledger, including the two prefixes the
original omitted):

| id prefix | what it covers | arms | source |
|---|---|---|---|
| `S10-ACCEPT-` | acceptance schema/gate/migration | 3 (A1–A3) | S10 §4 — cited |
| `S10-CLOSE-` | computed close — run/compute/one-door | 3 (A4–A6) | S10 §4 — cited |
| `S10-VERDICT-` | unverified class | 4 (A7–A10) | S10 §4 — cited |
| `S10-ATTEMPT-` | kill/attempt history | 5 (A11–A15) | S10 §4 — cited |
| `S10-STORE-` | store-loss detection | 4 (A16–A19) | S10 §4 — cited |
| `S10-CONCERN-` | concern channel (blocked/abandoned) | 2 (A20–A21) | S10 §4 — cited |
| `S10-SMOKE-` | end-to-end smoke | 4 (SMOKE-1..4) | S10 §5 — cited |
| `TC-` | T816 close-contract consolidation — reporting fields | 8 (TC-1..TC-8) | this spec §9.2 — new |
| `TW-` | T909 close-stops-worker | 3 (TW-1..TW-3) | this spec §9.3 — new |
| `SMOKE-T963-` | T963 consolidation smoke | 5 (SMOKE-T963-1..5) | this spec §9.4 — new |
| **total** | | **25 cited + 16 new = 41** | |

Replace the "Armed count" paragraph after it:

> **Armed count: 41 — 25 cited (S10's A1–A21 + SMOKE-1..4) + 16 new to this spec.** S10's 25 arms
> cover its 21 normative ids (some ids carry multiple arms — S10 §6); this spec's 16 arms cover
> every new normative id in §3–§6. No id in §3, §4, §5, §6 is left as prose. An id with no arm is
> a wish; this spec has none.

---

# RED FLAG 1 — §4.5: decision 3's "how" is deferred without naming the ruling needed

## Statement

The bundle's decision 3 is "whether the close stops the worker, **and how** — signal, wait,
escalate; and what happens when it cannot." The spec's §4.2/§4.3 decide the contract (holds
survive until runner exit; state visible; conflict caught) but §4.5 defers "the exact mechanism for
detecting runner exit — reaper, liveness poll, SIGCHLD handler, or the close path checking PID" to
the implementation row without saying whether a ruling is needed and from whom. Bundle acceptance
#3 says decisions are decided, not deferred.

## My analysis

Two different "how" questions are entangled:

1. **The bundle's "how — signal, wait, escalate"** is *decided* by the spec's adoption of option
   3+4: the close does **none** of the three. It does not signal the worker to stop, does not wait
   for it, does not escalate a refusal — it records the verdict immediately, keeps the holds held
   ("held-by-closed-runner"), and the reaper/close-path owns visibility. "What happens when it
   cannot [stop the worker]" is answered: it does not stop it; the state is visible ("done —
   runner alive, holds held") and the guard stays on (TW-1, TW-3). That part is decided.
2. **The residual question** — which mechanism detects runner exit — is genuinely a
   design-phase choice, and the spec already asserts the right reason it can be one: §4.5 says
   "This spec's acceptance arms (§9.3) assert the contract, not the mechanism."

What §4.5 fails to do is draw the conclusion the bundle's acceptance #3 demands: *no ruling is
needed, and here is why*. TW-1..TW-3 assert observable behavior (holds survive until exit; no
spurious report; conflict caught). Every candidate mechanism — reaper, liveness poll, SIGCHLD
handler, close-path PID check — can be implemented to satisfy all three arms identically; the
choice changes no observable behavior the arms measure. That is exactly the category S10 §2.1
already relegated to the design phase ("the exact encoding is a design-phase decision; the shape
and behavior are normative here"). The one hard constraint the implementation row must honour is
TW-3 (the arm that matters), and the spec already says so.

## Decision (replacement text for §4.5)

Replace the §4.5 paragraph "The exact mechanism for detecting runner exit … decides the mechanism"
with:

> The exact mechanism for detecting runner exit — reaper process, liveness poll, SIGCHLD handler,
> or the close path checking the caller's PID — is **implementation, and this is a decision, not a
> deferral: the mechanism is a design-phase choice for the implementation row, and no operator
> ruling is needed.** Why the contract is sufficient: TW-1..TW-3 (§9.3) assert the contract's
> observable requirements — holds survive until the runner exits, the "done — runner alive, holds
> held" state is visible, and the dangerous-window conflict is caught — and every candidate
> mechanism satisfies all three identically; the choice changes no observable behavior the arms
> measure. This is the same category S10 §2.1 already relegates to the design phase ("the exact
> encoding is a design-phase decision; the shape and behavior are normative here"). The
> implementation row owns the choice, constrained by the arms: it must show TW-1 red before its
> green, and a mechanism that fails TW-3 has not fixed the bug.

The bundle's "how — signal, wait, escalate" was decided in §4.2 (option 3+4: none of the three),
and "what happens when it cannot" is decided in §4.3 (the state is visible; the guard stays on).
With the sentence above, no part of decision 3 remains undeclared.

---

# RED FLAG 2 — §7: the blocked/abandoned concern requirement has no available path today

## Statement

§3.1/§6.1 and TC-8 require a concern record on `blocked`/`abandoned`, but the concern channel is
unimplemented: §7 itself records that `managent concern` has zero occurrences in
`src/managent/main.zig` and `docs/infra/managent/concerns.jsonl` does not exist. As written, every
`blocked`/`abandoned` close is refused for a missing concern with **no mechanism to satisfy it** —
a stranding path, exactly the failure the direction exists to avoid. §7 flags this but does not
decide the interim.

## My fact-check

- `grep -c concern src/managent/main.zig` → 1 hit, and it is a comment: line 673, "// annotation —
  model selection is the operator's concern, T954". No `managent concern` command exists.
- `docs/infra/managent/concerns.jsonl` does not exist (`ls` confirms; the directory holds
  `archive.json`, `directives.jsonl`, `spec.md`, `store-census.json`, `tasks.json`, and others —
  no concerns file).
- S10 §7 sequencing 3 says the concern channel "lands with or after the computed close … otherwise
  a refused close strands" — S10 itself anticipates the interim gap.

## Decision (replacement text for §7's sequencing note)

Replace the sequencing note "The concern channel (T490) must land with or before the computed
close … This spec does not build the channel; it cites S10-CONCERN-1 as the normative mechanism and
flags that it is unimplemented today." with:

> **Sequencing note — the concern channel (T490) must land with or before the computed close.**
> S10-CONCERN-1 (cited) specifies that the `blocked`/`abandoned` concern requirement is wired
> through T490's channel. The channel is not implemented today (verified: `managent concern` has
> zero occurrences in `src/managent/main.zig`; `docs/infra/managent/concerns.jsonl` does not
> exist). **Decided — the interim, so the requirement cannot strand: until the T490 channel lands,
> a `blocked`/`abandoned` close is allowed with the reason recorded in `verdict_note` (the
> existing field); it is NOT refused for a missing structured concern — there is no mechanism to
> file one, and refusing would strand the worker, the exact failure this direction exists to avoid
> (S10 §1.2, measured twice). The structured-concern requirement — and TC-8's refusal arm —
> activate in the same release as the T490 channel lands with the computed close (S10 §7
> sequencing 3). This is not a softening of S10-CONCERN-1; it is S10's own sequencing ("lands with
> or after the computed close … otherwise a refused close strands") made explicit as a decision
> rather than a flag.**

Consequent edits, so the spec stays internally consistent:

- §3.1 `confidence` row: append "(until T490 lands, a `verdict_note` reason satisfies it — see
  §7)".
- TC-8 (§9.2) "must" column: replace "**refused**, names the missing concern; refusal contains the
  copy-pasteable `managent concern` line" with "**refused** — **gated: binds from the release the
  T490 concern channel lands**; until then a `blocked` close with a `verdict_note` reason is
  allowed (refusing without a mechanism strands — S10 §1.2). When binding, the refusal contains the
  copy-pasteable `managent concern` line".

---

# RED FLAG 3 — §6.4 / §6.1: reporting-field encoding is never specified

## Statement

The spec names five fields but never specifies their encoding — CLI flags, a JSON payload, field
names, or a single `--report` blob — and makes no parallel statement to S10 §2.1's "the exact
encoding is a design-phase decision" for acceptance. §6.4's "prompt for them (if the worker is
still reachable)" is likewise unspecified (what mechanism prompts a dead worker's runner?).

## My analysis

S10 §2.1 handled exactly this for acceptance conditions: it gave the logical schema, declared the
shape and behavior normative, and explicitly delegated the exact encoding to the design phase. T963
should make the identical statement for the reporting fields — that closes the gap without
inventing an encoding the spec is not equipped to pin down. The "prompt for them" mechanism is the
same category: the contract is that the auto-close never silently defaults to a clean `pass`; how
it reaches a dead worker's runner (if it can at all) is design-phase.

## Decision (replacement text — add to §6.1, after the five fields)

> **Encoding — decided (parallel to S10 §2.1):** the exact encoding of the five reporting fields —
> individual CLI flags, a single `--report` payload, or a JSON document — is a design-phase
> decision for the implementation row; the shape and behavior are normative here: five required
> elements at every close, each with an explicit "none" escape, a missing element recorded as
> not-provided on the row, never silently defaulted. The auto-close's "prompt for them" mechanism
> (how a dead worker's runner is reached, if it is reachable at all) is likewise design-phase; the
> contract is that the auto-close records what it can and marks the rest not-provided — it never
> asserts a clean `pass` over a gap it could not collect.

---

# NOTES from the audit — addressed

## NOTE A — §9.1 reliance table is a subset

Verified: §9.1 lists 11 of S10's 21 unit arms (A1–A10, A20). It is presented as a reliance table,
not the full set, but sits next to "S10 §4 specifies 21 arms" and is easy to misread. **Fix (one
sentence, add to §9.1):** "The remaining S10 arms (A11–A19, A21) are out of this spec's scope and
still bind the implementation row." — the auditor's suggested sentence is correct and sufficient.

## NOTE B — §0's "red on a clean host"

The auditor says §0's "clean host" phrasing overstates T943's amendment. **The auditor
misattributes the phrase: the spec's §0 says "red on the live host" (verified, line 21 of §0) —
matching T943's amendment verbatim ("Its own regression is RED on the live host…").** The "clean
host" phrasing is the *bundle's* ("T943 shipped a gate that is red on a clean host"), not the
spec's. The underlying point stands and is worth one precision sentence in §0: T943's amendment
says the gate is red because Arm A flags `caffeinate -i -t 300` whose parent is the Claude Code
harness binary itself — *"a legitimate, unavoidable condition"* — not because it is red on a
pristine host. **Optional fix, §0:** after "records the failure explicitly", add: "(the gate fails
on a legitimate, unavoidable condition of the live host — a Claude console's `caffeinate` flagged
by ancestry — not on a pristine host; the fix was registered as T952)." The substantive point
(T943 closed `pass` over a failing acceptance) is untouched.

---

# What I did not reach

None. All five blockers were fact-checked and resolved, all three red flags were decided, and both
notes were addressed. The auditor is right on all five blockers; one audit note (B) misattributes a
phrase to §0 that belongs to the bundle, and the correction is a precision sentence rather than a
change to any number.
