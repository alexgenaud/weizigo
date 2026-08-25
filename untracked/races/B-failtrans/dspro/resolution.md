# T979 — Race B fail-transparency (dspro): resolution of the T963 spec audit (round 1)

**Author:** deepseek-v4-pro/T979 · **Date:** 2026-08-25 · **Nonce:** NONCE-2753ff4996527ee9
**Landmark:** advances `L1 (the dashboard tells the truth)`.
**Sealed arm:** this document is the resolution of the five blockers and three red flags raised by
`untracked/L1/T963/spec/audit-1.md` against `docs/epics/E1-markovian/L1-dashboard/T963/spec.md`.
I read nothing outside my own arm directory; I wrote nothing outside it and `findings/`.

## Verdict on the audit

**The auditor is right on all five blockers.** I re-checked each fact against the repository (store
and bundle), not the audit's word. Four of the five are factual errors the auditor caught by
checking; blocker 1 is a divergence from the bundle's explicit instruction ("a refused close
strands, so a missing field cannot simply refuse") and S10 §1.2's measured refusal=stranding.

**The auditor is wrong on one NOTE.** NOTE 2 attributes the phrase "red on a clean host" to the spec;
the spec actually says "red on the live host" (twice: its own sentence and T943's amendment quote).
That phrasing is *accurate* — T943's amendment is exactly that the gate is red on the live host
because a Claude console's `caffeinate` is flagged, a legitimate unavoidable condition. The
substantive point the NOTE gestures at is already satisfied by the committed text; no change needed.

The three red flags are real and each is resolved below with a decision, not a deferral.

---

## Blocker 1 — missing reporting field → "refused" contradicts the brief and S10

**Auditor's claim:** §3.1/§3.5/§6.3 decide that a missing `delivered`/`confidence`/`deferred`/
`followups`/`retrospective` **refuses** the close. The T963 bundle's decision 4 says the opposite:
*"…what a missing one costs — a refused close strands, so a missing field cannot simply refuse."*
S10 §1.2 already falsified "refusal with an available path is not stranding" (T818, sixteen
in-flight-zero-alive rows). §3.5's "reconciliation" is relabelling, not reconciliation.

**What I checked:** the bundle `untracked/T963-close-contract-spec.md` decision 4 reads verbatim
*"a refused close strands, so a missing field cannot simply refuse."* S10 §1 point 2 reads *"a
refused close leaves the task `in_progress`, which is indistinguishable from a live worker.
Measured twice on 2026-08-23 — T818 complete-but-unclosed read as *orphaned* for two hours…"* The
spec's §3.5 does exactly what S10 §1.2 says is falsified. **Auditor right.**

**Replacement — §3.1 table.** Replace the "verdict-affecting?" and "what missing does" columns of
the five-field table:

| field | required on | verdict-affecting? | what missing does |
|---|---|---|---|
| **`delivered`** | all closes | no (reporting; the mechanical deliverable-present gate is separate and already refuses) | close lands; field recorded `not-provided`; row marked `reporting-gap: delivered` |
| **`confidence`** | all closes | no (reporting) | same — recorded `not-provided`, row marked `reporting-gap: confidence` |
| **`deferred`** | all closes | no (reporting) | same — `reporting-gap: deferred` |
| **`followups`** | all closes | no (reporting) | same — `reporting-gap: followups` |
| **`retrospective`** | all closes | no (reporting) | same — `reporting-gap: retrospective` |

Replace the paragraph "**Why these are required and not optional:**" with:

> **Why these are required and not optional:** the operator's 2026-08-23 ruling (T816 §0) is
> explicit — an honest evaluation, concerns, follow-up suggestions, retrospective, and deferred
> items should be required. "Required" means: the close must carry the field or a named gap for
> it. A missing field is **recorded** (`not-provided`) and the row is marked `reporting-gap:
> <field>` — loud, counted on the dashboard, never silent. It is **not a refusal** and **not a
> strand**: the verdict is computed from acceptance conditions and lands regardless. This is
> S10's "always close, never strand" applied to the reporting contract: the gap is surfaced,
> the row is honest, and the worker is not left `in_progress` indistinguishable from a live
> worker.

**Replacement — §3.5.** Replace the reconciliation table and principle with:

| situation | mechanism | outcome |
|---|---|---|
| Acceptance condition `failed` (exit non-zero) | S10-CLOSE-2 narrow-A | **refused** — names the condition + exit; worker can fix and re-close, or close `blocked`/`abandoned`+concern |
| Acceptance condition `unverified` (kind `uncheckable`) | S10-CLOSE-2 | verdict = **`unverified`** — close lands, records honestly |
| Acceptance condition `cannot-run` (infra fault) | S10-CLOSE-2 | verdict = **`unverified`** — fault recorded, not the worker's |
| Reporting field missing | this spec §3.1 | close lands with the computed verdict; field recorded `not-provided`; row marked `reporting-gap: <field>` |
| Deliverable absent from git | existing gate (S10 §1.3) | **refused** — mechanically unambiguous; this is S10's narrow-A that already works |

> **The principle:** refusal is reserved for *a verified negative* (acceptance `failed`) and for
> *nothing to record the close about* (declared deliverable absent). Everything else — an
> uncheckable or un-runnable acceptance, a missing reporting field — is a **recorded outcome**,
> never a refusal. The previous draft's "refusal with an available path is not stranding" is the
> exact argument S10 §1.2 measured false: the path existed for T818 too, and it still stranded,
> because `in_progress` reads as a live worker no matter how clear the instruction. A missing
> field is a *gap on an otherwise-recorded close*, not a gate in front of it.

Delete the paragraph "**Edge case — a close that is both refused (missing field) and would be
unverified…**" in §3.5 (the premise — a missing field refusing the close — no longer exists).

**Replacement — §3.3 "What this spec adds to the computed close"** (final paragraph):

> **What this spec adds to the computed close:** the reporting fields (§3.1) are checked *in
> addition to* the acceptance conditions. A close whose acceptance conditions are all met but
> which is missing `retrospective` **still lands** with the computed verdict; the missing field
> is recorded `not-provided` and the row carries `reporting-gap: retrospective`. The two
> mechanisms compose: acceptance conditions determine the verdict; reporting fields determine
> whether the close is clean. A computed `pass` with a reporting gap is a `pass` whose gap is
> named — honest, not silent, and not withheld.

**Replacement — §6.3 "What a missing field costs":**

> A missing required field **records the gap and lets the close land.** The field is written as
> `not-provided`, the row carries a `reporting-gap: <field>` marker, and the gap is counted on
> the dashboard. The refusal is loud, specific and actionable — replaced by a recorded gap that
> is loud, specific and visible. This is the reconciliation with S10's "always close, never
> strand": the verdict always lands (even `unverified`); the reporting contract always *records*
> — a present field or a named gap. Nothing is silently defaulted; nothing is stranded.

**Replacement — §9.2 arms TC-1..TC-5 "must" column.** Change each `**refused**, names <field> as
missing; store unmutated` to:

> **close lands** with the computed verdict; the field is recorded `not-provided`; the row is
> marked `reporting-gap: <field>` and the gap is surfaced on `status`/`show`/dashboard — never a
> refusal, never a silent default.

The null control (the "explicit none" escape) and its framing are unchanged and still correct:
the contract is satisfiable, and the *gap* fires only on silence.

---

## Blocker 2 — §0 / §5.2 misstate the bundle's measured pass rate (92% vs 96%)

**Auditor's claim:** the bundle's measured baseline is 521 closes = 275 `pass` + 227
`pass-with-findings` + 12 `blocked` + 7 `abandoned`, i.e. **502 of 521 = 96%**, not 92%. The
spec's §0 puts "444 (92% of closes)" in the "bundle/S10 number" column, and §5.2 calls the Epoch 1
figure "92% (bundle time)". 444/92% is S10's 2026-08-24 measurement, not the bundle's.

**What I checked:** the bundle's "Measured baseline" section reads verbatim *"521 closes: 275
`pass`, 227 `pass-with-findings`, 12 `blocked`, 7 `abandoned`. `fail-found`: zero."* 275+227=502;
502/521=96.4%. S10 §0's table reads *"closed `pass` / `pass-with-findings` | **444** (92% of all
closes)"*. The bundle's only "92%" is the rhetorical *"if the honest close rate turns out to be far
below 92%"*. So 444/92% is S10-era (2026-08-24), not the bundle. **Auditor right.**

**Replacement — §0 table rows 1 and the following sentence:**

| fact | bundle number | S10 number (2026-08-24) | live store (2026-08-25) |
|---|---|---|---|
| closed `pass` / `pass-with-findings` | 502 of 521 (96%) | 444 (92% of closes) | 515 of 535 closed (96%) |

And replace the first numbered item:

> 1. **The 96%-pass surface is mostly self-report.** 502 of 521 closed rows at bundle time (96%)
>    read as a pass of some kind; S10's earlier measurement was 444 (92%). For 33 of 40
>    dispatchable rows there is no acceptance to check against, and for most closed rows the
>    acceptance was never run. The worker — or the auto-closer acting for it — grades itself.
>    This is not a discipline problem; it is a missing gate (T816 §1).

**Replacement — §5.2 Epoch 1 bullet:**

> - **Epoch 1 (pre-close-contract):** all closes before the close contract lands. Verdict is
>   worker-asserted (or auto-asserted). No computed acceptance check. No required reporting
>   fields. Pass-rate = (pass + pass-with-findings) / total closes. **This is 96% (bundle time,
>   502 of 521) / 96% (live, 515 of 535).** The 92% figure is S10's earlier (2026-08-24)
>   measurement, a *different epoch*, and must not be cited as "bundle time". It is a
>   measurement of self-report, not of verified completion.

---

## Blocker 3 — §0: the `fail-found` exemplar is wrong (T948 is not `fail-found`)

**Auditor's claim:** the single `fail-found` row is **T959**, not T948. T948 is
`pass-with-findings`. The count "1" is right; the exemplar is wrong.

**What I checked:** `docs/infra/managent/tasks.json` — T948 `verdict: "pass-with-findings"`
(verdict_note "24 rows audited; T943 closed pass while its own acceptance command was red").
`docs/infra/managent/archive.json` — T959 `verdict: "fail-found"` (the T953 spec audit, closed
2026-08-25T13:55:34Z). The bundle says `fail-found: zero` at bundle time; the live count is 1, and
that one row is T959. **Auditor right.**

**Replacement — §0 table row 2:**

| `fail-found`, all time | 0 in the store at bundle time | 1 (`T959`) |

(Optionally drop the exemplar and keep the count; the exemplar is correct only as T959.)

---

## Blocker 4 — §0 / §6.4 / §7 / §10.6: T940 was **not** auto-closed

**Auditor's claim:** T940 was closed by its worker (real `verdict_note` and `impression`), not by
`tools/runner`. The auto-close marker appears on T943 and T786, not T940. T943 alone carries the
auto-close-door argument.

**What I checked:** `archive.json` T940: `verdict_note: "Removed DEEPSEEK_API_KEY env guard; keys
resolve in pi"`, `impression: "Clean removal of obsolete env guards; test-first red->green on all
providers without env keys"`, `note: null`. No "tools/runner auto-close" text. T943:
`verdict_note: "tools/runner auto-close: worker exited 0 without closing…"`, `impression: null`.
T786: same auto-close marker. So T940 was a **worker close**; its acceptance command
(`tools/regression-no-key-env-guard.sh`) was also never run at close time — but that is a property
of the *old contract* (no computed acceptance check on any close), not of the auto-close door.
**Auditor right.**

**Replacement — §0.** Delete the sentence *"A second row, **T940** (closed 2026-08-25T10:20:04Z,
`acceptance: sh tools/regression-no-key-env-guard.sh`, verdict `pass`), was auto-closed the same
way — exit 0, deliverables present, acceptance command never run."* and replace with:

> A second row, **T940** (closed 2026-08-25T10:20:04Z by its worker, `acceptance: sh
> tools/regression-no-key-env-guard.sh`, verdict `pass`), shows the *old contract's* property, not
> the auto-close door's: its acceptance command was also never run at close time. T940 is a
> worker-asserted pass under the pre-S10 rule — the same self-grade the computed close ends, via
> the worker-close door rather than the auto-close door.

**Replacement — §6.4 first sentence** ("T943 and T940 were auto-closed by `tools/runner`…"):

> T943 was auto-closed by `tools/runner` on exit 0 + deliverables present, **without running the
> acceptance command and without collecting the reporting fields.** T940 was worker-closed the
> same way in effect — its acceptance was also never run — under the old contract. Both are the
> failure mode this sprint exists to end; T943 is the auto-close door's instance of it, T940 the
> worker-close door's.

**Replacement — §6.4 final sentence** ("This is the direct fix for the T943/T940 incident…"):

> **This is the direct fix for the T943 incident:** the auto-close path is the door that produced
> the false `pass`, and it must be brought under the same contract as the worker-close door. T940
> is the same defect through the worker-close door, already fixed by the computed close
> (S10-CLOSE-1/2) that this spec carries.

**Replacement — §7 sequencing note** ("T943 and T940 are live evidence that the auto-close door
produces false `pass` verdicts today."):

> T943 is live evidence that the auto-close door produces a false `pass` verdict today; T940 is
> live evidence that the worker-close door produced the same false `pass` under the old contract.
> The implementation row should prioritize the auto-close path fix (§6.4) because that door is
> still open; the worker-close door is closed by the computed close this spec carries.

**Replacement — §10.6 and SMOKE-T963-3/4.** In §10.6 change "T943 and T940 are the evidence that
exemption fails" to "T943 is the evidence that exemption fails (T940 is the worker-close door's
instance of the same defect, fixed by the computed close, not by the auto-close fix)". In
SMOKE-T963-3's "would have caught" cell, drop "T940" (T943 alone). In §11's rejected-arms row
"two rows closed pass with failing acceptance (T943/T940)", keep the arm rejected but reword the
parenthetical to "(T943 via the auto-close door; T940 via the worker-close door under the old
contract)".

---

## Blocker 5 — §9.2 / §9.4 / §11: the armed count is wrong three ways

**Auditor's claim:** correct total is 25 cited (S10: 21 arms A1–A21 + 4 smoke) + 16 new (8 TC +
3 TW + 5 SMOKE-T963) = **41**. The spec states three mutually inconsistent numbers, and its §11
ledger omits S10-ATTEMPT (A11–A15) and S10-STORE (A16–A19).

**What I checked:** S10 §6 ledger: ACCEPT 3 + CLOSE 3 + VERDICT 4 + ATTEMPT 5 + STORE 4 + CONCERN
2 = 21 unit arms (A1–A21); SMOKE 4. Total 25. T963's new arms: §9.2 TC-1..TC-8 (8), §9.3
TW-1..TW-3 (3), §9.4 SMOKE-T963-1..5 (5) = 16. 25+16 = 41. The spec's §9.4 arithmetic
(21+4+8+5=38) silently omits TW-1..3; §11's "32 cited + 16 new = 38" is arithmetically wrong
(32+16=48) and "32 cited" is wrong; §11's ledger table lists only 16 cited rows (omitting
S10-ATTEMPT and S10-STORE). **Auditor right.**

**Replacement — §9.4 armed-count sentence:**

> **Armed count:** S10's 21 arms (A1–A21, cited) + S10's 4 smoke tests (SMOKE-1..4, cited) + this
> spec's 8 reporting-field arms (TC-1..TC-8) + this spec's 3 worker-stopping arms (TW-1..TW-3) +
> this spec's 5 new smoke tests (SMOKE-T963-1..5) = **41 total arms, of which 16 are new to this
> spec.** The armed count equals the normative id count — every id in §3, §4, §5, §6 carries ≥1
> arm, and no id is left as prose.

**Replacement — §11 ledger table** (state S10's ledger in full rather than a partial re-derivation,
then the new arms):

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

And replace the note sentence "S10's 32 + this spec's 16…" with: **"Armed count: 41 = 25 cited
(S10's 21 arms + 4 smoke) + 16 new (8 TC + 3 TW + 5 SMOKE-T963).**"

---

## Red flags

### Red flag 1 — §4.5 defers decision 3's "how" without naming the ruling needed

**Resolution.** §4.5 already decides the *contract* (holds survive until the runner exits; the
state is visible; the dangerous-window conflict is caught) and defers only the *mechanism* (reaper
vs. liveness poll vs. SIGCHLD vs. PID check). The mechanism is not a ruling that needs an owner —
it is an implementation choice whose correctness is fully determined by the contract, because arms
TW-1..TW-3 assert observable behavior, not mechanism. Add one sentence to §4.5:

> The mechanism for detecting runner exit is a **design-phase implementation decision owned by the
> implementation row**, not a ruling this spec owes. No operator or Orchestrator ruling is needed:
> the contract (holds survive until exit; state visible; conflict caught) determines all
> observable behavior, and arms TW-1..TW-3 assert exactly that observable behavior. Any mechanism
> that passes TW-1..TW-3 satisfies the contract; the spec does not prefer one.

### Red flag 2 — §7: `blocked`/`abandoned` concern requirement has no available path today

**Resolution.** The concern channel is unimplemented (I verified: `managent concern` has zero code
occurrences — the only hit is a comment at `src/managent/main.zig:673`; `concerns.jsonl` does not
exist). The spec must not refuse a `blocked`/`abandoned` close for a missing concern when no
mechanism exists to satisfy it — that is a stranding path. Decide it:

> **Interim decision (resolves §7's deferral):** the `blocked`/`abandoned` concern requirement
> (S10-CONCERN-1, TC-8) is **conditional on the concern channel landing** and takes effect in the
> same commit as it, per S10-CONCERN-1's atomicity ("the concern channel and the computed close are
> two halves of one contract"). Until that commit, `blocked`/`abandoned` closes land with the
> verdict and a `reporting-gap: concern` marker (the blocker-1 mechanism) — recorded, never
> refused. There is no interim in which a `blocked`/`abandoned` close is refused with no mechanism
> to satisfy it, because the requirement and its mechanism land together. TC-8 is armed against
> the same implementation commit as the concern channel, not before it.

### Red flag 3 — §6.4 / §6.1: reporting-field encoding is never specified

**Resolution.** Add to §3.1 (or §6.1) a statement parallel to S10 §2.1's for acceptance:

> The logical schema for the five reporting fields is normative; the exact encoding is a
> design-phase decision (S10 §2.1 makes the identical statement for acceptance). Shape: five named
> fields — `delivered`, `confidence`, `deferred`, `followups`, `retrospective` — each a string
> (or a structured value for `delivered`: per-acceptance-condition `met`/`not-met`/`not-attempted`),
> with the explicit escapes `"none"` / `"no concerns — here is what I checked"`. Whether these are
> CLI flags, one `--report` blob, or a JSON payload is the implementation row's design-phase
> choice, not a ruling this spec owes.

And replace §6.4's "prompt for them (if the worker is still reachable)" with:

> The auto-close must collect the five reporting fields (or their explicit "none" escapes) before
> closing. If the worker exited without providing them, the auto-close **records each missing
> field as `not-provided`** and marks the row with the corresponding `reporting-gap`. It does not
> prompt a dead worker (there is no mechanism to, and none is specified); the gap is the record.
> It must not silently default to a clean `pass`.

---

## Notes

### NOTE 1 — §9.1 reliance table is a subset and does not say so

**Accepted.** Add one sentence to §9.1: *"The remaining S10 arms (A11–A19, A21) are out of this
spec's scope and still bind the implementation row."*

### NOTE 2 — §0's "red on a clean host" overstates the T943 amendment

**Auditor wrong — no change needed.** The committed spec does not say "clean host" or "pristine".
It says "red on the live host" (line 18) and quotes T943's amendment "Its own regression is RED on
the live host" (line 23), and it states the parent is "the Claude Code harness binary, not any
project script" — exactly T943's amendment's own characterization of a legitimate, unavoidable
condition. The NOTE appears to quote the *bundle* ("red on a clean host") and attribute it to the
spec. The spec's phrasing is accurate as written.

---

## What I did and did not reach

All five blockers are resolved with verified facts and exact replacement text; all three red flags
are resolved with decisions; both notes are addressed (one accepted, one shown to be a misquote).
No new factual claim is introduced that I did not check against the store or the bundle. I did not
edit the spec itself (per the brief) and I did not read other Race B arm directories.
