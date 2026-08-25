# T984 — Resolution: Close-Contract Spec (T963) Audit-1 Blockers & Red Flags

**Task:** T984 · **Agent:** gemini-3.7-flash · **Date:** 2026-08-26  
**Target Document:** `docs/epics/E1-markovian/L1-dashboard/T963/spec.md`  
**Audit Report:** `untracked/L1/T963/spec/audit-1.md` (T964, verdict: `BLOCKERS (5)`)  
**Landmark:** advances `L1 (the dashboard tells the truth)`  
**Normative Foundations:** `docs/epics/E1-markovian/L1-dashboard/S10-failure-transparency/spec.md` (§1, §2.1, §2.2, §4); T816 brief; T909 brief; T963 bundle.

---

## 1. Executive Summary & Audit Verification

This document provides a comprehensive, verified resolution to the five blockers, three red flags, and two notes identified in the round-1 audit (`untracked/L1/T963/spec/audit-1.md`) of `docs/epics/E1-markovian/L1-dashboard/T963/spec.md`.

Every underlying fact was independently checked against the live repository, store records (`tasks.json`, `archive.json`), git history, and the ratified S10 specification. All five auditor findings are factually accurate:
1. **Blocker 1 Verified:** Refusing a close due to missing reporting fields directly violates the S10 core principle ("always close, never strand") and T963 bundle decision 4. It also contradicted §6.4's auto-close logic.
2. **Blocker 2 Verified:** The bundle baseline measured 502 of 521 closes (96%) as pass/pass-with-findings, not 444 (92%), which was the earlier S10 (2026-08-24) baseline.
3. **Blocker 3 Verified:** `T948` is `pass-with-findings`. The sole `fail-found` task in the store at T963 authoring time was `T959`.
4. **Blocker 4 Verified:** `T940` was closed normally by its worker (`gemini-3.7-flash` with full `verdict_note` and `impression`), not auto-closed by `tools/runner`. `T943` remains the valid exemplar of the auto-close failure mode.
5. **Blocker 5 Verified:** The armed count had arithmetic errors and omitted TW arms and S10 capabilities. The exact count is **25 cited + 16 new = 41 total arms**.

The sections below present the statement, verification, decision, and exact replacement text for each blocker, followed by explicit resolutions for all red flags and notes, concluding with consolidated section replacements.

---

## 2. The Five Blockers: Analysis & Resolution

### Blocker 1: Missing Reporting Field Refusal (§3.1, §3.5, §6.3)

- **Auditor Finding:** §3.1, §3.5, and §6.3 specified that missing any required reporting field (`delivered`, `confidence`, `deferred`, `followups`, `retrospective`) results in a **refused** close. This contradicts T963 bundle decision 4 (*"a refused close strands, so a missing field cannot simply refuse"*) and S10 §1.2 (*"always close, never strand — but close honestly"*). Furthermore, §6.4 gave auto-close a different non-refusing treatment ("record not-provided... and close"), creating an internal contradiction.
- **Repository Verification:**
  - Checked `untracked/T963-close-contract-spec.md` (Decision 4): *"Decide which are required, which are optional, and what a missing one costs — a refused close strands, so a missing field cannot simply refuse."*
  - Checked `docs/epics/E1-markovian/L1-dashboard/S10-failure-transparency/spec.md` §1.2: Refusal leaves tasks stranded in `in_progress`, indistinguishable from live workers (measured in T818).
  - Checked S10 §1.3: Narrow-A refusal is strictly reserved for mechanically unambiguous gaps: declared deliverable files absent from git, and verified-failed acceptance commands.
- **Resolution:**
  - Missing reporting fields do **not** refuse the close or strand the worker.
  - The harness computes the acceptance verdict, records the close immediately, marks any missing reporting fields as `not-provided` (or `absent`), emits a loud warning on `stderr`, and sets a visible `reporting_gap: true` flag on the closed task row.
  - Required reporting fields remain mandatory in contract: workers are expected to supply them (or explicit "none" escapes), and model-grading surfaces count `reporting_gap` as non-compliant reporting without stranding the kanban.
  - Worker close and auto-close doors are unified: both record missing fields as `not-provided` rather than refusing.

---

### Blocker 2: Measured Pass Rate Misstated (§0, §5.2)

- **Auditor Finding:** §0 and §5.2 misstated the bundle's measured pass rate as 444 (92% of closes). The T963 bundle measured 275 `pass` + 227 `pass-with-findings` out of 521 closes = **502 of 521 (96%)**. 444 / 92% was S10's earlier measurement on 2026-08-24.
- **Repository Verification:**
  - Checked `untracked/T963-close-contract-spec.md` §"Measured baseline": *"521 closes: 275 pass, 227 pass-with-findings, 12 blocked, 7 abandoned. fail-found: zero."* Total passes = 275 + 227 = 502. 502 / 521 = 96.35% (96%).
  - Checked `docs/epics/E1-markovian/L1-dashboard/S10-failure-transparency/spec.md` §0: *"closed pass / pass-with-findings: 444 (92% of all closes)"* from 2026-08-24.
- **Resolution:**
  - Distinguish the historical baselines explicitly: S10 baseline (2026-08-24) was 444 (92%), T963 bundle baseline (2026-08-25) was 502 of 521 (96%), and live store at spec authoring time was 515 of 535 (96%).
  - Update §0 baseline table, §0 narrative, and §5.2 Epoch 1 definitions.

---

### Blocker 3: Wrong `fail-found` Exemplar Cited in Baseline (§0)

- **Auditor Finding:** §0 table cited `T948` as the single `fail-found` task. In reality, `T948` is `pass-with-findings`, while `T959` is the sole `fail-found` task in the store.
- **Repository Verification:**
  - Checked `docs/infra/managent/archive.json` / `tasks.json`:
    - `T948`: `status: done`, `verdict: pass-with-findings`, `agent: kimi-k2.7`, `verdict_note: 24 rows audited; T943 closed pass while its own acceptance command was red.`
    - `T959`: `status: done`, `verdict: fail-found`, `agent: deepseek-v4-pro`, closed 2026-08-25T13:55:34Z (`verdict_note: T953 spec audit round 1: BLOCKERS (3)...`).
- **Resolution:**
  - Replace `T948` with `T959` as the recorded `fail-found` exemplar in §0.

---

### Blocker 4: Factual Error Regarding T940 Auto-Close (§0, §6.4, §7, §10.6)

- **Auditor Finding:** The spec claimed `T940` was auto-closed by `tools/runner` over a failing acceptance. In reality, `T940` was closed by its worker (`gemini-3.7-flash`) with full worker verdict notes and impressions; it was never auto-closed.
- **Repository Verification:**
  - Checked `T940` in `tasks.json`:
    - `agent: gemini-3.7-flash`
    - `verdict_note: Removed DEEPSEEK_API_KEY env guard; keys resolve in pi`
    - `impression: Clean removal of obsolete env guards; test-first red->green on all providers without env keys`
    - `auto_closed: null` / `note: null`
  - Checked `T943`: carries `tools/runner auto-close: worker exited 0 without closing...` and was auto-closed over a failing acceptance.
- **Resolution:**
  - Remove all assertions that `T940` was auto-closed.
  - Reframe §0: `T943` is the sole and sufficient exemplar of the auto-close failure mode (auto-closed by `tools/runner` over a failing acceptance). `T940` is cited only as an example of the old worker-close contract where acceptance commands were never run at close time.
  - Clean up references in §6.4, §7, §9.4 (SMOKE-T963-3), §10.6, and §11.

---

### Blocker 5: Armed Count Inconsistent and Arithmetic Errors (§9.2, §9.4, §11)

- **Auditor Finding:** The armed count had internal contradictions:
  - §9.4 cited 38 total (13 new), omitting TW-1..TW-3.
  - §11 claimed "32 cited + 16 new = 38" (32+16=48; S10 actually defines 25 arms, and the ledger table omitted S10-ATTEMPT and S10-STORE).
- **Repository Verification:**
  - Recounted S10 cited arms from `docs/epics/E1-markovian/L1-dashboard/S10-failure-transparency/spec.md` §4 and §5:
    - S10-ACCEPT (A1–A3): 3 unit arms
    - S10-CLOSE (A4–A6): 3 unit arms
    - S10-VERDICT (A7–A10): 4 unit arms
    - S10-ATTEMPT (A11–A15): 5 unit arms
    - S10-STORE (A16–A19): 4 unit arms
    - S10-CONCERN (A20–A21): 2 unit arms
    - S10-SMOKE (SMOKE-1..4): 4 smoke arms
    - **Total S10 cited arms = 21 unit + 4 smoke = 25 arms.**
  - Recounted T963 new arms:
    - TC-1..TC-8: 8 unit arms
    - TW-1..TW-3: 3 unit arms
    - SMOKE-T963-1..5: 5 smoke arms
    - **Total T963 new arms = 11 unit + 5 smoke = 16 new arms.**
  - **Grand Total = 25 cited + 16 new = 41 total arms.**
- **Resolution:**
  - Correct the counts throughout §9.4, §11, and the arm ledger.
  - Include all S10 capabilities in the §11 ledger table to make cited and new arms completely transparent.

---

## 3. Red Flags & Notes: Concrete Decisions

### Red Flag 1 (§4.5): Decision 3's Deferred "How" (Runner Exit & Hold Release)
- **Problem:** §4.5 stated the contract (holds survive until runner exits) but deferred the detection mechanism to the implementer without stating the architectural choice.
- **Concrete Decision:**
  1. **Primary Mechanism (PID Liveness Check):** `managent done` records task status `done` and the computed verdict immediately. If the calling runner PID (or task runner PID recorded in runtime metadata) is still active, `managent done` marks the row's holds with a `held-by-closed-runner` status rather than clearing them.
  2. **Active Release Hook:** `tools/runner` executes a cleanup hook upon child process exit: `managent release-holds <task-id>`, clearing the held-by-closed-runner state.
  3. **Passive Sweeps:** `managent orient`, `status`, and background housekeeping check the PIDs of tasks with `held-by-closed-runner`. If the process is dead (`kill -0 <pid>` fails / errno ESRCH), the hold is cleared immediately.
  4. **Watchdog Escalation:** If a closed runner remains alive after a grace period of 60 seconds post-close, the runner supervisor / reaper sends `SIGTERM`, followed after 10 seconds by `SIGKILL`.

### Red Flag 2 (§7): Interim Mechanism for `blocked`/`abandoned` Concern Path
- **Problem:** TC-8 and §3.1 require a recorded concern on `blocked`/`abandoned`, but T490's concern channel (`managent concern`, `concerns.jsonl`) is not yet implemented in `main.zig`.
- **Concrete Decision:**
  - **Interim Mechanism (Pre-T490):** `managent done --status blocked` / `--status abandoned` requires `--note "<structured reason>"` (or `--concern "<text>"`). If the note is missing or empty, the close is refused with: `"blocked/abandoned close requires --note '<reason/concern>' to explain failure"`. If provided, the close succeeds and records the note as the concern.
  - **Target Mechanism (Post-T490):** When T490 lands, `managent done` checks for an existing concern in `concerns.jsonl` or automatically populates one from `--note`.
  - This prevents stranding in both interim and target states.

### Red Flag 3 (§6.1, §6.4): Reporting-Field Encoding & Auto-Close Extraction
- **Problem:** The syntax for passing the five reporting fields was unspecified.
- **Concrete Decision:**
  - **CLI Flags on `managent done`:**
    - `--delivered "<summary or itemized list>"`
    - `--confidence "<statement>"` (e.g., `"no concerns — acceptance verified"`)
    - `--deferred "<items or 'none'>"`
    - `--followups "<tasks or 'none'>"`
    - `--retrospective "<reflection statement>"`
  - **Findings JSON Fallback:** If CLI flags are omitted, `managent done` parses the declared findings JSON file (`findings/<task-id>-*.json`) for corresponding top-level keys (`delivered`, `confidence`, `deferred`, `followups`, `retrospective`).
  - **Auto-Close Extraction:** When `tools/runner` auto-closes an exiting worker, it reads the findings JSON. Any field not present in the findings JSON is recorded as `"not-provided"`, and the task row is flagged with `reporting_gap: true`.

### Note 1 (§9.1): S10 Reliance Table Scope
- Added an explicit note explaining that §9.1 lists the 11 unit arms directly relevant to the close contract (A1–A10, A20), while the remaining 14 arms from S10 (A11–A19, A21, and SMOKE-1..4) remain normative and bind the full S10 implementation row.

### Note 2 (§0): T943 Regression Phrasing
- Clarified that `sh tools/regression-moving-parts.sh` failed on the live host due to detecting a parent `caffeinate` process from the agent harness, accurately reflecting the T943 amendment.

---

## 4. Exact Replacement Sections for `T963/spec.md`

Below are the verbatim replacement sections to be applied to `docs/epics/E1-markovian/L1-dashboard/T963/spec.md`.

```markdown
<!-- ===================================================================== -->
<!-- REPLACEMENT SECTION 0                                                 -->
<!-- ===================================================================== -->

## 0. The honest reading — open with the sharpest evidence

**T943 closed `pass` on 2026-08-25T11:17:50Z while its own declared acceptance command was failing
and was never run at close time.**

T943's bundle declared `acceptance: sh tools/regression-moving-parts.sh`. That gate failed on the live
host — it flagged `caffeinate -i -t 300` as a prohibited timed caffeinate whose parent was the Claude Code
harness binary (`git show 35fd322`). The worker exited 0 without calling `managent done`; `tools/runner`
auto-closed the row as `pass` on process evidence (exit 0 + deliverables present), without executing the
acceptance command. T943's own amendment (2026-08-25T11:26:23Z) records the failure explicitly: *"Its own
regression is RED on the live host and it is wired into zig build test… Closed pass with a failing
acceptance."*

A standard worker close, **T940** (closed 2026-08-25T10:20:04Z, `acceptance: sh tools/regression-no-key-env-guard.sh`,
verdict `pass`), illustrates the parallel hole under the worker-close door: the worker called `done`,
provided notes, and the close landed without the acceptance command ever being executed.

**This is the failure mode the whole sprint exists to end:** a row's verdict was asserted (by the
auto-closer or by the worker) without the acceptance being checked. Under the computed close
(S10-CLOSE-1/2, §2.1 below) the acceptance command would have run; T943's would have failed and the
close would have been refused. The auto-close path is one of the two close doors (T816 §5) and must
satisfy the same contract.

The baseline numbers that frame the problem:

| fact | S10 baseline (2026-08-24) | T963 bundle baseline | live store (2026-08-25) |
|---|---|---|---|
| closed `pass` / `pass-with-findings` | 444 (92% of closes) | 502 of 521 (96%) | 515 of 535 closed (96%) |
| `fail-found`, all time | 4 (in 573 tasks) | 0 in store | 1 (`T959`) |
| tasks with acceptance criteria recorded | 123 / 573 (21%) | 123 / 521 (24%) | 94 of 535 closed + 40 dispatchable (17%) |
| dispatchable rows with `acceptance=` | — | 12 of 45 (27%) | 7 of 40 (18%) |
| dispatchable rows without `acceptance=` | — | 33 of 45 (73%) | 33 of 40 — **blocked from dispatch by gate** |
| closed `blocked` / `abandoned` | — | 12 / 7 | 12 / 7 (unchanged) |

Two things are worth stating before any decision:

1. **The 96%-pass surface is mostly self-report.** 515 of 535 closed rows read as a pass of some kind.
   For 33 of 40 dispatchable rows there is no acceptance to check against, and for most closed rows the
   acceptance was never run. The worker — or the auto-closer acting for it — grades itself. This is not
   a discipline problem; it is a missing gate (T816 §1).

2. **A close does not stop the worker** (T909's incident, §4 below). T943's worker kept running after
   its auto-close and committed a fixture edit 8 minutes later. The file guard is off during that window
   because the close released holds.

<!-- ===================================================================== -->
<!-- REPLACEMENT SECTION 3.1 & 3.5                                         -->
<!-- ===================================================================== -->

### 3.1 The five required reporting fields

T816 requires five fields at close. This spec carries that requirement, decides which are
verdict-affecting and which are reporting-required, and reconciles behavior with S10's
"always close, never strand."

| field | required on | verdict-affecting? | what missing does |
|---|---|---|---|
| **`delivered`** | all closes | **yes** (via git gate) | Declared deliverable paths absent from git → **refused** (narrow-A). If deliverable files are present in git but itemized `delivered` text breakdown is omitted → recorded as `not-provided`, flagged `reporting_gap: true`. |
| **`confidence`** | all closes | **yes** (on failure verdicts) | On `pass`/`pass-with-findings`/`fail-found`: missing → recorded as `not-provided`, flagged `reporting_gap: true`. On `blocked`/`abandoned`: missing note/concern → **refused** (names missing note/concern). |
| **`deferred`** | all closes | no (reporting) | Missing → recorded as `not-provided`, flagged `reporting_gap: true`. Explicit "none" satisfies. |
| **`followups`** | all closes | no (reporting) | Missing → recorded as `not-provided`, flagged `reporting_gap: true`. Explicit "none" satisfies. |
| **`retrospective`** | all closes | no (reporting) | Missing → recorded as `not-provided`, flagged `reporting_gap: true`. One/two sentences satisfies. |

**Why these are required and how gaps are handled:** The operator's 2026-08-23 ruling (T816 §0) is
explicit: *"Perhaps an honest evaluation, concerns, follow-up suggestions, retrospective, deferred items
should be required."* However, per S10 §1.2 and T963 bundle decision 4, a missing reporting field cannot
refuse the close because refusal leaves the task stranded in `in_progress`.

Instead, the contract enforces reporting honesty without stranding:
- If reporting fields are omitted, the close computes and records the verdict from acceptance conditions,
  records omitted fields as `"not-provided"`, emits a loud warning on `stderr`, and flags `reporting_gap: true`
  on the closed task.
- Performance and profile graders (`tools/model-profiles.py`) track reporting compliance; tasks with
  `reporting_gap: true` are penalized in reporting scores without stranding the kanban queue.

...

### 3.5 Refusal vs unverified vs reporting gaps — the reconciliation

The reconciliation between T816, S10, and worker lifecycle:

| situation | mechanism | outcome |
|---|---|---|
| Acceptance condition `failed` (exit non-zero) | S10-CLOSE-2 narrow-A | **refused** — names condition + exit code; worker fixes and re-closes, or closes `blocked`/`abandoned` with `--note <concern>` |
| Deliverable absent from git | existing gate (S10 §1.3) | **refused** — mechanically unambiguous (work is missing from disk/git) |
| `blocked`/`abandoned` close missing note/concern | S10-CONCERN-1 / §7 | **refused** — names missing reason/concern; worker supplies `--note` and re-closes |
| Acceptance condition `unverified` (kind `uncheckable`) | S10-CLOSE-2 | verdict = **`unverified`** — close records honestly; condition is not checkable |
| Acceptance condition `cannot-run` (infra fault) | S10-CLOSE-2 | verdict = **`unverified`** — infrastructure fault recorded; not worker failure |
| Reporting field missing (`delivered`, `confidence`, `deferred`, `followups`, `retrospective`) on success close | this spec §3.1, §6.3 | **closed with computed verdict** — missing fields marked `"not-provided"`, stderr warning, row flagged with `reporting_gap: true` |

**The principle:** Refusal is reserved exclusively for narrow-A: physically missing deliverables, failing
acceptance tests that contradict a `pass` claim, and reasonless `blocked`/`abandoned` claims. Missing
reporting commentary does not strand the task; it lands the computed verdict while visibly recording the
reporting gap.

<!-- ===================================================================== -->
<!-- REPLACEMENT SECTION 4.5                                               -->
<!-- ===================================================================== -->

### 4.5 Concrete mechanism for runner liveness and hold release (Decided)

To eliminate ambiguity, this spec decides the operational mechanism for option 3+4:

1. **Liveness Detection & Hold Preservation:**
   When `managent done` executes, it inspects the process table for the task's active runner PID (recorded
   in `untracked/runs/` or runtime metadata). If the runner process is still alive:
   - The task row is updated to `status: done` with its computed verdict and completion timestamp.
   - The task's `holds` are transitioned to a dedicated `held-by-closed-runner` status rather than being
     cleared.
   - Any attempt by another task to claim or dispatch with overlapping holds is refused by the conflict
     guard.

2. **Active Release Hook:**
   `tools/runner` executes a post-exit cleanup trap that calls `managent release-holds <task-id>` immediately
   after the worker child process terminates.

3. **Passive Sweep & Reaper:**
   Commands inspecting or mutating the store (`orient`, `status`, `dispatch`, `claim`) perform a passive
   liveness check on tasks marked `held-by-closed-runner`. If `kill -0 <pid>` confirms the process no
   longer exists, the holds are pruned immediately.

4. **Watchdog Escalation:**
   If a runner process remains active for >60 seconds after calling `done`, the runner supervisor sends
   `SIGTERM`, followed after 10 seconds by `SIGKILL` (matching standard runner watchdog behavior).

<!-- ===================================================================== -->
<!-- REPLACEMENT SECTION 5.2                                               -->
<!-- ===================================================================== -->

### 5.2 Pre-S10 and post-S10 pass-rates are not comparable — decided

**S10-VERDICT-4 (cited):** The pass-rate comparison breaks the moment `unverified` splits the pass bucket.
Record a dated epoch boundary, state the before/after of the pass-rate definition, and stop comparing across it.

- **Epoch 1 (pre-close-contract):** All closes before the close contract lands. Verdict is worker-asserted
  (or auto-asserted). No computed acceptance check. Pass-rate = (pass + pass-with-findings) / total closes.
  **This is the 96% baseline (502/521 at bundle time, 515/535 live).** It measures self-report.
- **Epoch 2 (post-close-contract):** Closes after the contract lands. Verdict is computed from checked
  acceptance conditions. `Unverified` is a first-class outcome. Pass-rate = (computed pass + computed
  pass-with-findings) / total closes. **This is a different quantity.** It is not comparable to Epoch 1.

The dashboard must label each close with its epoch. Pre-S10 numbers quoted beside post-S10 numbers must be
labelled as a different epoch.

<!-- ===================================================================== -->
<!-- REPLACEMENT SECTION 6.1, 6.3, 6.4                                     -->
<!-- ===================================================================== -->

### 6.1 Required on every close & encoding specification

The five reporting fields are supplied either via CLI arguments or in the declared findings JSON:

1. **`delivered`** — itemized summary against acceptance conditions (`--delivered "<text>"` or findings `delivered`).
2. **`confidence`** — worker confidence evaluation (`--confidence "<text>"` or findings `confidence`).
3. **`deferred`** — items consciously not done (`--deferred "<text>"` or findings `deferred`).
4. **`followups`** — suggested follow-up tasks (`--followups "<text>"` or findings `followups`).
5. **`retrospective`** — 1–2 sentences on task execution (`--retrospective "<text>"` or findings `retrospective`).

**Precedence:** CLI flags override findings JSON values. If neither is provided, the field defaults to
`"not-provided"` and triggers a reporting gap.

...

### 6.3 What a missing field costs — decided

A missing reporting field **does not refuse the close** (§3.1, §3.5). The close completes, the computed
verdict lands, missing fields are recorded as `"not-provided"`, and `reporting_gap: true` is stored on the
row. This adheres to "always close, never strand" while ensuring reporting gaps remain visible to model
profiling and audit tools.

...

### 6.4 The auto-close path must satisfy the same contract

T943 was auto-closed by `tools/runner` on exit 0 + deliverables present, **without running the acceptance
command.** This is the second close door (T816 §5) and must satisfy the same contract:

- The auto-close runs acceptance commands (S10-CLOSE-1). If acceptance fails, auto-close refuses `pass` and
  routes the task to `unverified` (or `blocked` with the runner failure note) — it never asserts `pass` over
  a failing command.
- The auto-close inspects the findings JSON for reporting fields. Missing fields are recorded as
  `"not-provided"` with `reporting_gap: true` set. Auto-close never hallucinates clean reporting.

<!-- ===================================================================== -->
<!-- REPLACEMENT SECTION 7                                                 -->
<!-- ===================================================================== -->

## 7. Sequencing & dependencies — decided

**T963 is a spec row.** It writes one document and touches no code. The dependency on T815 belongs on the
subsequent implementation row.

**Sequencing & Interim Concern Channel Decision:**
- S10-CONCERN-1 specifies that `blocked`/`abandoned` requires a recorded concern via T490 (`managent concern`).
- **Interim Rule (Pre-T490):** Because T490 is not yet implemented, `managent done --status blocked` /
  `--status abandoned` requires `--note "<reason>"` on the CLI. The close records the note as the concern.
  A close without `--note` is refused with: `"blocked/abandoned close requires --note '<reason>'."`
- **Target Rule (Post-T490):** When T490 lands, `managent done` validates `concerns.jsonl` presence or
  auto-populates it from `--note`.

<!-- ===================================================================== -->
<!-- REPLACEMENT SECTION 9.1, 9.2, 9.4                                     -->
<!-- ===================================================================== -->

### 9.1 Carried from S10 — cited, not re-armed

S10 §4 defines 21 unit arms (A1–A21) and 4 smoke tests (SMOKE-1..4) for a total of **25 cited arms**.
The table below highlights the 11 unit arms directly relied upon by the close contract. The remaining
14 arms (A11–A19, A21, and SMOKE-1..4) cover attempt history and store-loss detection; they remain normative
and bind the full S10 implementation row.

| S10 id | what it covers | this spec's reliance |
|---|---|---|
| S10-ACCEPT-1 (A1) | acceptance comes from bundle only | §3.2 — reporting contract reads acceptance from bundle |
| S10-ACCEPT-2 (A2) | dispatch gate; 383 grandfathered | §3.2, §5.3 — 33 dispatchable rows blocked, not grandfathered |
| S10-ACCEPT-3 (A3) | single-command→list migration | §3.2 — existing acceptance commands treated as 1-condition list |
| S10-CLOSE-1 (A4) | close runs each condition | §3.3, §6.4 — auto-close and worker close must run acceptance |
| S10-CLOSE-2 (A5) | verdict follows from conditions; failed→refused | §3.3, §3.5 — reconciliation relies on this |
| S10-CLOSE-3 (A6) | one door (lanes --backfill) | §3.3 — bulk path satisfies the same contract |
| S10-VERDICT-1 (A7) | `--status unverified` refused | §3.4 — unverified is harness-emitted only |
| S10-VERDICT-2 (A8) | unverified rendered distinctly | §3.4, §5.2 — dashboard labels epochs & unverified distinctly |
| S10-VERDICT-3 (A9) | unverified excluded from correctness grade | §3.4 — model-profiles mapping change |
| S10-VERDICT-4 (A10) | epoch note | §5.2 — epoch boundary definition |
| S10-CONCERN-1 (A20) | blocked/abandoned requires concern | §3.1, §6.1, §7 — interim --note / T490 concern requirement |

### 9.2 New arms — T816 close-contract consolidation

| id | arm | setup | must (red-then-green) | would have caught |
|---|---|---|---|---|
| TC-1 | close with `--status pass` and missing `delivered` field | `done` with verdict `pass`, deliverables present in git, `delivered` text omitted | **close succeeds** with computed verdict, `delivered` set to `"not-provided"`, row flagged `reporting_gap: true` | unitemized closes while preventing stranding |
| TC-2 | close with `--status pass` and missing `confidence` field | `done` with verdict `pass`, `confidence` omitted | **close succeeds** with computed verdict, `confidence` set to `"not-provided"`, row flagged `reporting_gap: true` | silent closes while preventing stranding |
| TC-3 | close with `--status pass` and missing `deferred` field | `done` with verdict `pass`, `deferred` omitted | **close succeeds** with computed verdict, `deferred` set to `"not-provided"`, row flagged `reporting_gap: true` | unlisted deferred items while preventing stranding |
| TC-4 | close with `--status pass` and missing `followups` field | `done` with verdict `pass`, `followups` omitted | **close succeeds** with computed verdict, `followups` set to `"not-provided"`, row flagged `reporting_gap: true` | missing follow-ups while preventing stranding |
| TC-5 | close with `--status pass` and missing `retrospective` field | `done` with verdict `pass`, `retrospective` omitted | **close succeeds** with computed verdict, `retrospective` set to `"not-provided"`, row flagged `reporting_gap: true` | missing retrospective while preventing stranding |
| TC-6 | close with all reporting fields present | `done` with all 5 reporting fields (or explicit "none"), acceptance met | **close succeeds**, computed verdict confirmed, `reporting_gap: false` | positive control: clean honest close |
| TC-7 | grandfathered task closes under old rule | closed task from pre-S10 era with no acceptance | **allowed** — closes under pre-S10 rule, marked `acceptance: grandfathered` | migration compatibility (S10-ACCEPT-2) |
| TC-8 | close `--status blocked` without note/concern | `done --status blocked` with no `--note` and no T490 concern | **refused**, names missing note/concern; re-close with `--note "<reason>"` succeeds | reasonless blocked closes (T387) |

...

### 9.4 New smoke tests — T963 consolidation

| id | scenario | assert | would have caught |
|---|---|---|---|
| SMOKE-T963-1 | worker closes with all 5 fields present and acceptance met | close succeeds, verdict confirmed, all fields recorded, `reporting_gap: false` | positive control end-to-end |
| SMOKE-T963-2 | worker closes with missing `retrospective` | close lands with computed verdict, `retrospective` marked `"not-provided"`, `reporting_gap: true` recorded | non-stranding reporting gap handling |
| SMOKE-T963-3 | auto-close path (tools/runner) closes row whose acceptance is failing | auto-close refuses `pass`, computes `failed`/`unverified`, names failing command | T943 false `pass` on failing acceptance |
| SMOKE-T963-4 | auto-close path closes row with no worker reporting fields | auto-close records fields as `"not-provided"`, flags `reporting_gap: true`, computes verdict from acceptance | auto-close silent default to clean pass |
| SMOKE-T963-5 | epoch labeling on dashboard | closed row labelled with epoch; computed pass queries exclude Epoch 1 and `unverified` | 96%-pass surface hiding unverified work |

**Armed count summary:** 25 cited arms (S10 A1–A21 + SMOKE-1..4) + 16 new arms (8 TC + 3 TW + 5 SMOKE-T963) = **41 total arms (32 unit arms + 9 smoke arms)**.

<!-- ===================================================================== -->
<!-- REPLACEMENT SECTION 10.6 & 11                                         -->
<!-- ===================================================================== -->

### 10.6 The auto-close path exempted from the contract — rejected

T943 is live evidence that exemption fails. The auto-close path is one of the two close doors (T816 §5)
and must satisfy the same contract as the worker-close door. Exempting it reproduces the disease (the false
`pass` on a failing acceptance). The fix (§6.4) brings the auto-close path under the contract.

---

## 11. Arm ledger

| id prefix | capability | unit arms | smoke arms | source |
|---|---|---|---|---|
| `S10-ACCEPT-` | computed close — schema/gate/migration | 3 (A1–A3) | — | S10 §4 (cited) |
| `S10-CLOSE-` | computed close — run/compute/one-door | 3 (A4–A6) | — | S10 §4 (cited) |
| `S10-VERDICT-` | unverified class | 4 (A7–A10) | — | S10 §4 (cited) |
| `S10-ATTEMPT-` | kill/attempt history | 5 (A11–A15) | — | S10 §4 (cited) |
| `S10-STORE-` | store-loss detection | 4 (A16–A19) | — | S10 §4 (cited) |
| `S10-CONCERN-` | concern channel | 2 (A20–A21) | — | S10 §4 (cited) |
| `S10-SMOKE-` | S10 end-to-end smoke | — | 4 (SMOKE-1..4) | S10 §5 (cited) |
| `TC-` | T816 close-contract reporting fields | 8 (TC-1..TC-8) | — | this spec §9.2 (new) |
| `TW-` | T909 close-stops-worker | 3 (TW-1..TW-3) | — | this spec §9.3 (new) |
| `SMOKE-T963-` | T963 consolidation smoke | — | 5 (SMOKE-T963-1..5) | this spec §9.4 (new) |
| **total** | **all capabilities (cited + new)** | **32 unit** | **9 smoke** | **41 total arms** |

**Armed count: 41 total arms (25 cited from S10 + 16 new to this spec).** Every normative id carries
≥1 unit or smoke arm.
```
