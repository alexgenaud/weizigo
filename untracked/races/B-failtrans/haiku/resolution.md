# T983 — Race B fail-transparency resolution (Haiku)

**Auditor:** deepseek-v4-pro/T964 · **Spec author:** solar-pro4 · **Verified:** 2026-08-26

**Verdict:** five blockers confirmed as stated; three red flags require decision.

---

## BLOCKER 1 — §3.1/§3.5/§6.3: Missing reporting field → "refused" contradicts the bundle and S10

**Verification:** Confirmed. The T963 bundle (line 71) states explicitly: *"a missing field cannot simply refuse"* because *"a refused close strands"*. The S10 ratified direction (line 46-48 of T963 bundle) records: *"a refused close leaves the row in_progress, indistinguishable from a live worker — measured twice on 2026-08-23."* The spec's §3.1 (line 125) table and §6.3 (line 392) state that missing reporting fields are **refused**, contradicting this doctrine. Furthermore, §6.4 (line 413-416) gives the auto-close path a *different* treatment: missing fields are "recorded as not-provided" with the verdict computed anyway. A worker calling `managent done` will have its close refused for a missing field, but a runner auto-closing the same worker will land the close with the field marked absent. This inconsistency is load-bearing.

**Resolution:** The spec's refusal gates for missing reporting fields (§3.1, §6.3) must be retracted. Replace them with §6.4's model applied uniformly: a close with a missing reporting field records that field as "not-provided" (with a structured escape: `reported: false, reason: "worker did not provide"`) and computes the verdict from the acceptance conditions. The reporting contract is not enforced by refusal; it is enforced by visibility — missing fields are recorded and marked on the dashboard, visible to the operator and to future audits, enabling a retrospective enforcement decision rather than a prospective gate that strands. This preserves S10's "always close, never strand" and moves the enforcement point from close-time to audit-time, where the data is visible.

**Replacement text for §3.5:**

> **The distinction, decided:**
> 
> | situation | mechanism | outcome |
> |---|---|---|
> | Acceptance condition `failed` (exit non-zero) | S10-CLOSE-2 narrow-A | **refused** — names the condition + exit; worker can fix and re-close, or close `blocked`/`abandoned`+concern |
> | Acceptance condition `unverified` (kind `uncheckable`) | S10-CLOSE-2 | verdict = **`unverified`** — no refusal, the close records honestly; the worker cannot make it checkable |
> | Acceptance condition `cannot-run` (infra fault) | S10-CLOSE-2 | verdict = **`unverified`** — same as uncheckable; the fault is recorded, not the worker's |
> | Reporting field missing (`delivered`, `confidence`, `deferred`, `followups`, `retrospective`) | this spec §3.1 | **recorded as not-provided** — the close lands, the verdict is computed from acceptance, the missing field is visible and marked; the reporting gap is audit-visible, not close-refused |
> | Deliverable absent from git | existing gate (S10 §1.3) | **refused** — mechanically unambiguous; this is S10's narrow-A that already works |

**Replacement text for §6.3:**

> ### 6.3 What a missing field costs — decided
> 
> A missing required field **is recorded as `not-provided`**, with the close's verdict computed from the acceptance conditions. This is **not refusal** (§3.5): the close lands, the verdict stands, and the reporting gap is visible on the row for future audit. The missing field does not trigger stranding (the row receives a verdict, closing S10's "always close, never strand") and does not trigger auto-stranding by a prospective gate. The reporting contract is enforced by visibility: the dashboard and audit tools can filter for rows with unreported fields, and an operator review can require retrospective completion or can document why the gap is acceptable. This is the reconciliation with S10's doctrine: S10's "never strand" applies to the verdict; T963's "required fields are visible" applies to the reporting surface. A row can be closed with verdict `unverified` (S10's requirement) and with a missing `retrospective` (T963's visibility requirement), and neither one strands it.

---

## BLOCKER 2 — §0/§5.2: The measured pass rate is misstated (92% vs 96%)

**Verification:** Confirmed. The T963 bundle (line 52) states the measured baseline as: *"521 closes: 275 `pass`, 227 `pass-with-findings`, 12 `blocked`, 7 `abandoned`."* Arithmetic: 275 + 227 = 502 of 521 = **96.4%**, not 92%. The 92% figure comes from S10's 2026-08-24 measurement (per the audit), not from the T963 bundle. The spec's §0 table (line 40) incorrectly cites the bundle column as "444 (92% of closes)." This is load-bearing because §5.2 (line 336) anchors the Epoch 1 boundary and the pass-rate redefinition to "92% (bundle time)", embedding a false baseline into a normative decision.

**Replacement text for §0, line 40:**

| fact | bundle/S10 number | live store (2026-08-25) |
|---|---|---|
| closed `pass` / `pass-with-findings` | 502 of 521 (96%) | 515 of 535 closed (96%) |

**Replacement text for §5.2, Epoch 1 definition:**

> - **Epoch 1 (pre-close-contract):** all closes before the close contract lands. Verdict is worker-asserted (or auto-asserted). No computed acceptance check. No required reporting fields. Pass-rate = (pass + pass-with-findings) / total closes. **This was 96% at the T963 bundle baseline (521 closes: 502 of pass-or-findings class).** It is a measurement of self-report, not of verified completion.

---

## BLOCKER 3 — §0: The fail-found exemplar is wrong; T948 is not fail-found

**Verification:** Confirmed. The spec's §0 table (line 41) cites `fail-found` as "1 (`T948`)". Checking `bin/managent show T948`: T948 carries `verdict: pass-with-findings`, not `fail-found`. The audit identified the actual `fail-found` row as T959 (closed 2026-08-25T13:55:34Z). The count "1 for fail-found" is correct; the exemplar is wrong.

**Replacement text for §0, line 41:**

| fact | bundle/S10 number | live store (2026-08-25) |
|---|---|---|
| `fail-found`, all time | 0 in the store at bundle time | 1 (`T959`) |

---

## BLOCKER 4 — §0/§6.4/§7/§10.6: T940 was NOT auto-closed; the spec asserts false evidence

**Verification:** Confirmed. The spec claims (§0, line 26-27) that T940 "was auto-closed the same way — exit 0, deliverables present, acceptance command never run." The audit checked the store and found: T940 carries a real `verdict_note` ("Removed DEEPSEEK_API_KEY env guard; keys resolve in pi") and a real `impression` ("Clean removal of obsolete env guards; test-first red->green…"), indicating a worker-authored close, not an auto-close. The auto-close marker ("tools/runner auto-close: worker exited 0 without closing…") appears on T943 and T786, not T940. Git log confirms: commit `7d4c8a9` is titled "T940: API keys live in pi, remove env-var capability guards" — a worker commit, not a runner auto-close.

**Resolution:** T940 must be deleted from §0, §6.4, §7, and §10.6. It is not evidence for the auto-close failure mode. T943 alone carries the auto-close argument and is sufficient.

**Replacement text for §0 (§0 and footnote after line 56):**

Delete the sentence "A second row, **T940** (closed 2026-08-25T10:20:04Z, `acceptance: sh tools/regression-no-key-env-guard.sh`, verdict `pass`), was auto-closed the same way — exit 0, deliverables present, acceptance command never run." and the associated clause "T943 and T940 are live evidence that the auto-close-door argument" in §0.

Replace with: "T943 is live evidence that the auto-close door produces false `pass` verdicts."

**Replacement text for §6.4:**

Delete "T943 and T940" from the opening. Change to: "T943 was auto-closed by `tools/runner` on exit 0 + deliverables present, **without running the acceptance command and without collecting the reporting fields.** This is the second close door (T816 §5) and it must satisfy the same contract as the worker-close door. **Specifically:**"

(Remove the second sentence comparing T943 and T940, keeping only T943 as the worked example.)

**Replacement text for §10.6:**

Delete the T940 reference. Change the opening to: "T943 is the evidence that exemption fails. The auto-close path is one of the two close doors (T816 §5) and must satisfy the same contract as the worker-close door."

---

## BLOCKER 5 — §9.2/§9.4/§11: The armed count is wrong and internally inconsistent

**Verification:** Confirmed on the counts; the spec is arithmetically wrong in three places.

**Count verification:**
- S10 spec arms (from S10's §6 ledger): 21 unit (A1–A21) + 4 smoke (SMOKE-1..4) = **25 total**
- T963 spec arms (from T963's §9.2, §9.3, §9.4): 8 (TC-1..TC-8) + 3 (TW-1..TW-3) + 5 (SMOKE-T963-1..5) = **16 new**
- **Correct total: 25 + 16 = 41**

**Spec errors:**
1. §9.4 (line 559-560) states: "S10's 21 arms (A1–A21) + S10's 4 smoke (SMOKE-1..4) + this spec's 8 new arms (TC-1..TC-8) + this spec's 5 new smoke (SMOKE-T963-1..5) = **38 total**" — this **omits TW-1..TW-3** (3 arms). Should be 21 + 4 + 8 + 3 + 5 = **41**, not 38. The "13 new" figure is also wrong; should be **16 new**.
2. §11 (line 629) states: "**32 cited + 16 new = 38**" — mathematically 32 + 16 = 48, not 38. More fundamentally, S10's count is 25, not 32. The ledger table (lines 621-628) lists only 16 S10 arms (omitting S10-ATTEMPT-1..5 and S10-STORE-1..4), creating an undercounting error.

**Replacement text for §9.4 armed count:**

> **Armed count:** S10's 21 arms (A1–A21, cited) + S10's 4 smoke tests (SMOKE-1..4, cited) + this spec's 8 new arms (TC-1..TC-8) + this spec's 3 new arms (TW-1..TW-3) + this spec's 5 new smoke tests (SMOKE-T963-1..5) = **41 total arms, of which 16 are new to this spec.** The armed count equals the normative id count — every id in §3, §4, §5, §6 carries ≥1 arm, and no id is left as prose.

**Replacement text for §11 arm ledger:**

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

**Replacement text for §11 closing paragraph:**

> **Armed count: 41 of 41 normative ids carry ≥1 arm** (S10's 25 arms across 21 ids + this spec's 16 arms across 13 ids). No id in §3, §4, §5, §6 is left as prose. An id with no arm is a wish; this spec has none.

---

## RED FLAG — §4.5: Decision 3's "how" is deferred without naming the ruling needed

The bundle's decision 3 calls for deciding "whether the close stops the worker, **and how** — signal, wait, escalate; and what happens when it cannot." The spec's §4.5 decides the contract (holds survive until runner exit) but defers the mechanism: "the exact mechanism for detecting runner exit — reaper process, liveness poll, SIGCHLD handler, or the close path checking the caller's PID — is implementation."

**Issue:** The spec carries the contract but not the decision authority. Bundle acceptance #3 requires decisions to be decided, not deferred; where a deferral is genuine, the spec must name what ruling is needed and from whom.

**Guidance:** §4.5 should add a paragraph stating: *"The exact mechanism for detecting runner exit — reaper process, liveness poll, SIGCHLD handler, or close-path liveness check — is a design-phase decision for the implementation row, provided that the contract (holds survive until runner exit, state visible, dangerous-window conflict caught) is met. This is sufficient for the spec; the implementer inherits the decision."* This clarifies that the mechanism is implementation-scope, not spec-scope, without leaving the spec incomplete.

---

## RED FLAG — §7: The blocked/abandoned concern requirement has no available path today

The spec (§3.1, §6.1, TC-8) requires a concern record on `blocked`/`abandoned` closes. The spec's §7 (line 453-454) acknowledges: "The concern channel is not implemented today (`managent concern` has zero occurrences in `src/managent/main.zig`; `docs/infra/managent/concerns.jsonl` does not exist)."

As written, every `blocked`/`abandoned` close is refused for a missing concern with no mechanism to satisfy the refusal — a stranding path. §7 flags this deferral but does not decide the interim mechanism. Bundle acceptance #3 requires decisions to be decided.

**Guidance:** §7 should choose one of three paths:
1. **Gate TC-8 (concern-required) behind T490's landing** — `blocked`/`abandoned` does not require a concern until the T490 channel is implemented. Interim: TC-8 not armed until T490 lands.
2. **Specify an interim mechanism** — e.g., `--concern-note "reason text"` as a one-line escape on the `managent done` command, recorded and surfaced separately from the T490 channel, landing when the close lands.
3. **Keep TC-8 as a deferred implementation decision** — document that the implementer must choose between landing T490 in parallel or specifying an interim mechanism, and name what the implementation row is responsible for.

The spec should pick one, name it, and move from deferral to decision.

---

## RED FLAG — §6.4/§6.1: Reporting-field encoding is never specified

The spec names five fields (`delivered`, `confidence`, `deferred`, `followups`, `retrospective`) and requires them on every close, but never specifies their encoding or data schema. S10 §2.1 carefully states for acceptance: "the exact encoding is a design-phase decision." T963 makes no parallel statement for reporting fields.

**Issue:** An implementer does not know whether these are CLI flags (`--delivered`, `--confidence`, etc.), a JSON payload, field names in a structured format, or a single `--report` blob. §6.4's description of the auto-close path as "prompt for them (if the worker is still reachable)" is similarly unspecified — what mechanism prompts a dead worker's runner?

**Guidance:** Add a paragraph to §6.1 or §6.4 stating: *"The exact encoding of the five reporting fields — as CLI flags, structured JSON payload, a bundled `--report` argument, or other mechanism — is a design-phase decision for the implementation row, provided that: (1) the fields are present and validated on close, (2) missing-field visibility is recorded on the row, and (3) the fields are surfaced on the dashboard and audit outputs. For the auto-close path, the implementation must decide whether to prompt a live worker via a mechanism of the implementation's choice, or record the fields as not-provided if the worker is unreachable."*

---

## Summary

**Blockers verified and resolved:**
1. ✓ Refusal-on-missing-fields → record-as-not-provided + audit visibility
2. ✓ Pass rate corrected (96% not 92%)
3. ✓ fail-found exemplar corrected (T959 not T948)
4. ✓ T940 reference removed (was not auto-closed)
5. ✓ Armed count corrected (41 not 38; 25 cited + 16 new)

**Red flags addressed:**
- §4.5: Mechanism is implementation-scope, spec carries the contract
- §7: TC-8 gating decision needed (three options offered)
- §6.4/§6.1: Encoding is design-phase scope, spec carries the visibility requirement

**Recommendation to judge:** The spec's core architecture (close contract, close-stops-worker, computed verdict, refusal for absent deliverables only) is sound. The five blockers are correctable factual and arithmetic errors; the three red flags are deferral decisions that the spec should name clearly but can leave to the implementation row. Once these corrections land, the spec is ready for pass 1 (implementation row dispatch).
