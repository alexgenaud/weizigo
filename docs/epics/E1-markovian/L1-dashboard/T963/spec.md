# T963 — spec: the close contract

**Task:** T963 · **Author:** solar-pro4 · **Date:** 2026-08-25
**Landmark:** advances `L1 (the dashboard tells the truth)` — a task's recorded outcome stops
being a self-report.
**Inputs:** this bundle; `docs/epics/E1-markovian/L1-dashboard/S10-failure-transparency/spec.md`
(ratified — §2.1, §2.2, §4 are normative input); the T816 bundle (close contract);
the T909 bundle (close must stop the worker).
**Scope:** specification only. No code, no build.

---

## 0. The honest reading — open with the sharpest evidence

**T943 closed `pass` on 2026-08-25T11:17:50Z while its own declared acceptance command was failing
and was never run at close time.**

T943's bundle declared `acceptance: sh tools/regression-moving-parts.sh`. That gate is red on the live
host — it flags `caffeinate -i -t 300` as a prohibited timed caffeinate whose parent is the Claude Code
harness binary, not any project script (`git show 35fd322`). The worker exited 0 without calling
`managent done`; `tools/runner` auto-closed the row as `pass` on process evidence (exit 0 + deliverables
present), without executing the acceptance command. T943's own amendment (2026-08-25T11:26:23Z)
records the failure explicitly: *"Its own regression is RED on the live host and it is wired into
zig build test… Closed pass with a failing acceptance."*

A second row, **T940** (closed 2026-08-25T10:20:04Z, `acceptance: sh tools/regression-no-key-env-guard.sh`,
verdict `pass`), was auto-closed the same way — exit 0, deliverables present, acceptance command never run.

**This is the failure mode the whole sprint exists to end:** a row's verdict was asserted (by the
auto-closer, on behalf of the worker) without the acceptance being checked. Under the computed close
(S10-CLOSE-1/2, §2.1 below) the acceptance command would have run; T943's would have failed and the
close would have been refused. The auto-close path is one of the two close doors (T816 §5) and must
satisfy the same contract.

The baseline numbers that frame the problem (cited from S10's measured baseline and the T963 bundle;
live store counts noted where they have grown):

| fact | bundle/S10 number | live store (2026-08-25) |
|---|---|---|
| closed `pass` / `pass-with-findings` | 444 (92% of closes) | 515 of 535 closed (96%) |
| `fail-found`, all time | 0 in the store at bundle time | 1 (`T948`) |
| tasks with acceptance criteria recorded | 123 / 573 (21%) | 94 of 535 closed + 40 dispatchable (17%) |
| dispatchable rows with `acceptance=` | 12 of 45 | 7 of 40 |
| dispatchable rows without `acceptance=` | 33 of 45 | 33 of 40 — **blocked from dispatch by the gate** |
| closed `blocked` / `abandoned` | 12 / 7 | 12 / 7 (unchanged) |

Two things are worth stating before any decision:

1. **The 92%-pass surface is mostly self-report.** 515 of 535 closed rows read as a pass of some kind.
   For 33 of 40 dispatchable rows there is no acceptance to check against, and for most closed rows the
   acceptance was never run. The worker — or the auto-closer acting for it — grades itself. This is not
   a discipline problem; it is a missing gate (T816 §1).

2. **A close does not stop the worker** (T909's incident, §4 below). T943's worker kept running after
   its auto-close and committed a fixture edit 8 minutes later. The file guard is off during that window
   because the close released holds.

---

## 1. What this row consolidates

Three rows were retired into T963 on 2026-08-25. Read all three; they are the requirements.

| retired | brought here | what it contributes |
|---|---|---|
| **T816** — the close contract | the whole row | what a close must record; why a self-graded close is not evidence; the five required close fields; acceptance gated at dispatch |
| **T909** — a closed row with a live worker | the close-must-stop-worker requirement | the incident (T786 closed itself, kept running 35 min, committed after close, holds released while live); the decision options; the dangerous-window arm |
| S10 §2.1, §2.2, §4 (ratified) | the computed-close direction and the `unverified` class | S10-ACCEPT-1/2/3, S10-CLOSE-1/2/3, S10-VERDICT-1/2/3/4, and the 21 arms A1–A21 — cited, not re-derived |

**What this spec adds beyond S10:** S10 specifies *how the verdict is computed* from acceptance
conditions. T816 specifies *what a close must record* (the reporting contract). T909 specifies
*what happens to the worker after close*. S10 does not address the reporting contract or the worker
lifecycle. This spec carries T816's reporting contract and T909's worker-stopping requirement, decides
their shape, and reconciles them with S10's computed-verdict direction — in particular, the tension
between T816's "refuses without" and S10's "always close, never strand."

---

## 2. The ratified direction — cited, not re-derived

S10 §1 weighed four options (A: strict refusal; B: lenient; C: distinct verdict class; D: computed
verdict) and **ratified D, emitting C, with A only where it is mechanically unambiguous.** The reasoning,
which this spec carries and must not soften:

1. **A, B, and C all still ask the worker to characterise its own work.** Strictness that rests on
   self-report is not strict. D removes self-report from the determination for anything checkable.
2. **A's failure mode is disqualifying:** a refused close leaves the task `in_progress`, indistinguishable
   from a live worker — measured twice on 2026-08-23. **A verdict that cannot be recorded becomes a lie of
   a different kind.** So: **always close, never strand — but close honestly.**
3. **A does apply narrowly and already works:** declared deliverables absent from git is mechanically
   unambiguous, and `managent done` already refuses it. Keep that.
4. **Every soft gate in this repository has been routed around.** A gate that can be satisfied by
   assertion will be.

**The verdict space after S10 has six outcomes, but they are not peers:**

| outcome | who produces it | meaning |
|---|---|---|
| `pass`, `pass-with-findings` | worker **claims**, harness **confirms** | every acceptance condition verified met; deliverables in git |
| `fail-found` | worker claims, harness confirms via findings + absorption gate | a successful falsification with full deliverables |
| `unverified` | **harness emits, worker cannot assert** | ≥1 acceptance condition could not be checked |
| `blocked`, `abandoned` | worker asserts, **concern required** | cannot proceed / gave up — the reason is structured, not free text |

A worker's `--status pass` is a claim, not a verdict. The harness computes the verdict from the
conditions. This is the whole mechanism; the rest is its parts.

**This spec's relationship to S10:** S10 §2.1 (computed close), §2.2 (unverified class), and §4 (arms
A1–A21) are ratified and are normative input. This spec **does not re-derive or re-write them.** It
cites them and specifies what they do not cover: the T816 reporting contract (§3), the T909
worker-stopping requirement (§4), and the reconciliation between T816's refusal gates and S10's
unverified class (§3.5).

---

## 3. The close contract — T816 carried and decided

### 3.1 The five required reporting fields

T816 requires five fields at close. This spec carries that requirement, decides which are
verdict-affecting and which are reporting-required, and reconciles the refusal behavior with S10's
"always close, never strand."

| field | required on | verdict-affecting? | what missing does |
|---|---|---|---|
| **`delivered`** | all closes | **yes** | refused — nothing to match the acceptance against; this is S10's narrow-A carve-out (mechanically unambiguous: the work either is or isn't there) |
| **`confidence`** | all closes | **yes** (on failure verdicts) | refused — the operator's "honest evaluation"; silence is not an honest close. On `pass`/`pass-with-findings`/`fail-found`: an explicit "no concerns — here is what I checked" satisfies it. On `blocked`/`abandoned`: ≥1 concern record via the T490 channel (S10-CONCERN-1) satisfies it — this is already ratified, cited not re-written |
| **`deferred`** | all closes | no (reporting) | refused — a deferred item left unnamed is how a spec quietly shrinks to what was convenient; explicit "none" satisfies it |
| **`followups`** | all closes | no (reporting) | refused — the operator named follow-up suggestions as required; explicit "none" satisfies it |
| **`retrospective`** | all closes | no (reporting) | refused — the operator's *"what would have made this task go better"*; one or two sentences; this is the field that feeds process change |

**Why these are required and not optional:** the operator's 2026-08-23 ruling (T816 §0) is explicit —
*"Perhaps an honest evaluation, concerns, follow-up suggestions, retrospective, deferred items should be
required."* The measured hole (T816 §1) is that 21% of closed tasks carry no verdict note at all and
only 29% carry a model impression. Optional fields default to silence; silence is the disease. Required
fields with an explicit escape ("none, because…") are the cure.

**Why missing-field refusal is not stranding (the reconciliation, §3.5):** every missing-field refusal
names the missing field and gives the path to satisfy it (add the field, re-close). The worker can always
clear the gate. This is refusal **with an available honest path** — categorically different from
`unverified`, where no path exists (the acceptance condition cannot be checked, and the worker cannot
make it checkable at close). The distinction is the heart of the reconciliation.

### 3.2 Where acceptance comes from — who may set it

**S10-ACCEPT-1 (cited, not re-written):** acceptance is a structured list authored by the specifier
before dispatch, living in the bundle meta header. The close reads it **only from the bundle**; any
worker-supplied `--acceptance` flag on `managent done` is refused — acceptance is not a close-time input.
This is the mitigation for workers writing trivially-checkable conditions to earn a clean computed pass.

**S10-ACCEPT-2 (cited, not re-written):** acceptance gated at dispatch. A task cannot be *dispatched*
without acceptance conditions or an explicit `--skip-acceptance <reason>`. Gate at dispatch, not
registration. **The 33 dispatchable rows without `acceptance=` are blocked from dispatch by this gate.**
They are **not** grandfathered — the gate is forward-looking, and these rows must acquire acceptance or a
skip reason before they can be dispatched.

**S10-ACCEPT-3 (cited, not re-written):** the 123 (live: 94) existing tasks whose `acceptance=` is a
single command are treated as a one-condition list (`kind: command`). A task with no acceptance at all
and no skip reason is `unverified`-eligible, not exempt.

**Decision — what happens to the 33 dispatchable rows with no acceptance:** blocked from dispatch until
they acquire acceptance or a skip reason. This is not a new decision; it is S10-ACCEPT-2 applied to the
live store. The spec states it explicitly because the bundle asks "Say what happens to the 33 rows that
have none — grandfathered with a published count, or blocked." **Answer: blocked, not grandfathered.**
Grandfathering applies to *already-closed* rows (the ~521 closed under the old contract, §5); these 33
are still dispatchable and the dispatch gate closes the set going forward.

### 3.3 The computed close — S10 §2.1 cited

**S10-CLOSE-1 (cited):** for a `pass`/`pass-with-findings` claim, the close runs each `command`
acceptance condition via the existing `/bin/sh -c` path and records per condition: `met` (exit 0),
`failed` (non-zero exit, with code), `cannot-run` (exit 126/127 or spawn failure — an infrastructure
fault, the T295 distinction already in the code), or `unverified` (kind `uncheckable`, carrying the
specifier's declared reason). `fail-found` is exempt from the acceptance run — its bar is the findings
file and the absorption gate, already mechanical.

**S10-CLOSE-2 (cited):** the verdict follows from the conditions, not the worker's summary. All conditions
`met` + deliverables in git → the worker's claim is confirmed. Any condition `unverified` or
`cannot-run` → recorded verdict is **`unverified`**, overriding the worker's pass. Any condition `failed`
→ close **refused**, naming the condition and its exit status — the narrow-A carve-out: a verified
negative is not "cannot verify," it is "the work demonstrably failed its own bar." The worker's honest
paths: fix and re-close, or close `blocked`/`abandoned` with a concern naming the failing condition
(§2.6 of S10 — the concern channel, cited).

**S10-CLOSE-3 (cited):** `lanes --backfill` must call the same gated close, not reimplement it. One door.

**What this spec adds to the computed close:** the reporting fields (§3.1) are checked *in addition to*
the acceptance conditions. A close that has all acceptance conditions met but is missing `retrospective`
is **refused** (missing reporting field), not `unverified` (the acceptance was checkable — it was met).
The two mechanisms compose: acceptance conditions determine the verdict; reporting fields determine
whether the close is honest enough to record. A close can have a computed `pass` verdict and still be
refused for a missing `retrospective` — the verdict is available, but the close is not honest. The worker
adds the field and re-closes; the verdict stands.

### 3.4 The unverified class — S10 §2.2 cited

**S10-VERDICT-1 (cited):** `unverified` is first-class and never assertable. `managent done --status
unverified` is refused. The only way a row reads `unverified` is a computed close that found a condition
it could not check.

**S10-VERDICT-2 (cited):** `unverified` renders distinctly in `status`, `show`, `resume`, `audit`, and
the dashboard — never lumped with `pass`. The per-condition detail (which condition, why) is stored on the
row.

**S10-VERDICT-3 (cited):** `unverified` is excluded from the correctness grade in `tools/model-profiles.py`
— it is not a model-quality datum — and counted in a separate `unverified` column. The mapping change and
the verdict change are one commit or neither lands.

**S10-VERDICT-4 (cited, extended in §5):** the 92%-pass baseline is redefined with a dated epoch note.

### 3.5 Refusal vs unverified — the reconciliation

This is the one thing S10 does not fully resolve and T816's "refuses without" creates tension with.

**The distinction, decided:**

| situation | mechanism | outcome |
|---|---|---|
| Acceptance condition `failed` (exit non-zero) | S10-CLOSE-2 narrow-A | **refused** — names the condition + exit; worker can fix and re-close, or close `blocked`/`abandoned`+concern |
| Acceptance condition `unverified` (kind `uncheckable`) | S10-CLOSE-2 | verdict = **`unverified`** — no refusal, the close records honestly; the worker cannot make it checkable |
| Acceptance condition `cannot-run` (infra fault) | S10-CLOSE-2 | verdict = **`unverified`** — same as uncheckable; the fault is recorded, not the worker's |
| Reporting field missing (`delivered`, `confidence`, `deferred`, `followups`, `retrospective`) | this spec §3.1 | **refused** — names the missing field; worker adds it and re-closes; the verdict (once computed) stands |
| Deliverable absent from git | existing gate (S10 §1.3) | **refused** — mechanically unambiguous; this is S10's narrow-A that already works |

**The principle:** refusal is for *gaps the worker can fill* (missing field, failed acceptance, absent
deliverable). `Unverified` is for *gaps no one at close time can fill* (acceptance declared uncheckable,
or an infrastructure fault preventing the run). Refusal with an available path is not stranding; S10's
"always close, never strand" applies to the verdict, not to the reporting contract. A row whose close is
refused for a missing `retrospective` is not stranded — it is `in_progress` with a clear instruction:
*"add the retrospective and re-close; the verdict is ready."* A row whose acceptance is `unverified` is
closed with verdict `unverified` — the close landed, honestly.

**Edge case — a close that is both refused (missing field) and would be unverified (acceptance
uncheckable):** the refusal takes precedence (the close cannot land at all until the field is provided).
When the field is provided and re-close runs, the acceptance is re-checked and may yield `unverified`.
The row passes through refusal → closed-`unverified`, not refusal → closed-`pass`. This is the honest
path: the missing field is a transient gate, the uncheckable acceptance is a permanent verdict modifier.

---

## 4. Close stops the worker — T909 decided

### 4.1 The incident (T909 §1, cited)

T786 called `managent done` on itself at 21:24:02Z, status `done`, verdict `pass`. Its worker kept
running for 35 more minutes, committed a fixture edit 8 minutes after its own close, had its `holds`
released by the close while still editing, and `src/managent/main.zig` was handed to T906 running
concurrently — two live workers, one file, no guard, because one was officially finished. The seat stopped
the process by hand. **Nothing in the system would have.** The fleet dashboard rendered a working lane as
`UNKNOWN` for 35 minutes (T908, the symptom; this row is the cause).

### 4.2 The decision

The T909 brief offers four options. This spec **rejects option 1 (close means stop)** and **option 2
(close refused while caller's runner is alive)** and **adopts option 3 (holds survive until the process
exits) implemented through option 4 (the reaper owns visibility).**

**Rejected — option 1 (close means stop):** `managent done` signals the worker's runner to wind up.
Risk: a worker that closes and then legitimately finishes a commit is cut off mid-write — worse than the
disease if the commit is partial. The T943 incident is exactly this: the auto-closer closed T943, and the
worker's subsequent commit (8 minutes later) was legitimate work that should not have been killed. A kill
on close would have destroyed that commit.

**Rejected — option 2 (refuse close while caller's own runner is alive):** a worker may not declare itself
done before it is done. Risk: how does a worker close at all, given it *is* the live process? This is
unworkable — the worker IS the process calling `done`; refusing its own close because it is alive is a
paradox. The close would never land, and the row would strand (the exact A-failure-mode S10 rejected).

**Adopted — option 3 + option 4:** **holds survive until the caller's runner exits, not until the close.**
The verdict lands immediately (no stranding — S10's "always close, never strand" is preserved), but the
file guard stays on for the whole dangerous window. A reaper — or the close path itself, checking process
liveness — reports the state *"row X closed, runner still alive"* as a named, visible state. Holds are
released when the runner process actually exits. The guard is on while the worker is live, and the queue is
honest.

**Why this is the right shape:** it preserves the close's immediate verdict (the row is not stranded —
S10's core requirement), it keeps the file guard on during the dangerous window (the T786/T906 conflict
cannot recur), and it makes the state visible (the 35-minute invisibility is closed). It does not kill the
worker (option 1's defect) and it does not refuse the close (option 2's paradox).

### 4.3 What "holds survive until exit" means concretely

The close records the verdict and the `done` timestamp immediately. The row's `holds` are marked
"held-by-closed-runner" rather than released. The file-conflict guard treats a "held-by-closed-runner"
hold as live — a second worker attempting to hold the same file is refused, exactly as if the first worker
were still `in_progress`. When the runner process exits (detected by the reaper or by the close path
checking liveness), the hold is released and the row's status reflects "closed, runner exited."

**The visible state:** a `done` row whose runner is still alive is reported distinctly in `status`,
`show`, `resume`, and `orient` — not as `in_progress` (that would be the stranding S10 forbids) and not
as a clean `done` with holds released (that would be the T786 bug). The label is something like
"`done` — runner alive, holds held." The dangerous window is named, not silent.

### 4.4 The dangerous-window arm (T909 §3, decided)

The arm that matters is the one that reproduces the actual incident: **close a row whose runner is alive,
then attempt to dispatch a second row holding the same file — assert the conflict is caught.** This is the
failure that actually occurred (T786's `holds` released, T906 handed the same file, both live). The arm is
specified in §9.3.

### 4.5 What this spec does NOT decide (deferred to the implementation row)

The exact mechanism for detecting runner exit — reaper process, liveness poll, SIGCHLD handler, or the
close path checking the caller's PID — is implementation. This spec specifies the **contract**: holds
survive until the runner exits, the state is visible, and the dangerous-window conflict is caught. The
implementation row (which lands against this spec) decides the mechanism. This spec's acceptance arms
(§9.3) assert the contract, not the mechanism.

**What this spec also does NOT widen into:** the directive-delivery work (T892) and the dashboard fix
(T908) are explicitly out of scope per T909's constraint. One defect: the gap between a row closing and
its worker stopping. This spec addresses that defect's contract; T908 (dashboard rendering) and T892
(directive delivery) are separate rows.

---

## 5. Migration and epochs — S10-VERDICT-4 cited and decided

### 5.1 The 521 pre-S10 closes are grandfathered, not re-rated

The ~521 rows closed under the old contract (worker-asserted verdict, deliverables gate only, no computed
acceptance check, no required reporting fields) **stay as they are.** They cannot be retroactively given a
computed verdict or required fields they were never asked for. They are grandfathered with a published
count and a marker `acceptance: grandfathered` (S10-ACCEPT-2), and **no new task may join the set** — the
dispatch gate (§3.2) closes it going forward.

### 5.2 Pre-S10 and post-S10 pass-rates are not comparable — decided

**S10-VERDICT-4 (cited):** the pass-rate comparison breaks the moment `unverified` splits the pass bucket.
The same discipline the model epoch rules already impose (T525): record a dated epoch boundary, state the
before/after of the pass-rate definition, and stop comparing across it.

**This spec decides the epoch boundary and the labeling:**

- **Epoch 1 (pre-close-contract):** all closes before the close contract lands. Verdict is worker-asserted
  (or auto-asserted). No computed acceptance check. No required reporting fields. Pass-rate = (pass +
  pass-with-findings) / total closes. **This is the 92% (bundle time) / 96% (live) figure.** It is a
  measurement of self-report, not of verified completion.
- **Epoch 2 (post-close-contract):** closes after the contract lands. Verdict is computed from checked
  acceptance conditions. `Unverified` is a first-class outcome. Required reporting fields enforced.
  Pass-rate = (computed pass + computed pass-with-findings) / total closes, where "computed" means the
  harness ran the acceptance and it met. **This is a different quantity.** It is not comparable to Epoch 1.

**The dashboard must label each close with its epoch.** A reader must be able to ask "how much of our done
is computed-pass" and get a count that excludes Epoch 1 and excludes `unverified`. Pre-S10 numbers quoted
beside post-S10 numbers must be labelled as a different epoch. **This is not a one-time note; it is a
labeling discipline on every close surface.**

### 5.3 The 33 dispatchable rows without acceptance — decided

These are **not** grandfathered (§3.2). They are dispatchable, not yet dispatched, and the dispatch gate
blocks them until they acquire acceptance or a skip reason. They are the visible face of the gate working.
A reader of the dashboard should see "33 dispatchable rows awaiting acceptance" as a count, not as a
silent backlog. This count is part of the Epoch 2 landscape — it is the gate doing its job, not a defect.

---

## 6. What an honest close records — decided

The operator named five things an honest close should record (T816 §0, T963 bundle §1). This spec decides
which are required, which are optional, and what a missing one costs.

### 6.1 Required on every close

1. **`delivered`** — what was actually produced, against each acceptance condition, each marked met / not
   met / not attempted. "I did a thing" fails this by construction because there is nothing to match it
   against. **Missing → refused.**

2. **`confidence`** — the worker's confidence state. On `pass`/`pass-with-findings`/`fail-found`: an
   explicit "no concerns — here is what I checked" satisfies it. On `blocked`/`abandoned`: ≥1 concern
   record via the T490 channel (S10-CONCERN-1, cited). **Missing → refused.** This is the operator's
   "honest evaluation" — the field that feeds process change and the model-perf ledger.

3. **`deferred`** — what was in scope and consciously not done, each with a reason. Anything deferred and
   unnamed is how a spec quietly shrinks to what was convenient. Explicit "none" satisfies it.
   **Missing → refused.**

4. **`followups`** — the tasks that should exist now, or an explicit none. The operator named follow-up
   suggestions as required. **Missing → refused.**

5. **`retrospective`** — one or two sentences: what would have made this task go better. This is the
   operator's *"honest evaluation"* and it is the field that feeds process change. **Missing → refused.**

### 6.2 Optional on every close

- **Concern records (T490 channel) on `pass`/`pass-with-findings`/`fail-found`:** optional. A worker with
  nothing to flag owes nothing beyond the "no concerns" statement in `confidence`. The channel is available
  for genuine concerns on success-path closes, but not required.

### 6.3 What a missing field costs — decided

A missing required field **refuses the close**, naming the missing field and giving the path to satisfy it
(add the field, re-close). This is **not stranding** (§3.5): the worker can always clear the gate. The
refusal is loud, specific, and actionable — not a silent default to `pass`.

**This is the reconciliation with S10's "always close, never strand":** S10's "never strand" applies to
the verdict — a row must always receive a verdict, even if that verdict is `unverified`. T963's
"refuse missing fields" applies to the reporting contract — a close must always record the five fields.
These are different gates on different things. A row can be closed with verdict `unverified` (S10's "never
strand" satisfied) while its reporting fields are all present (T963's contract satisfied). A row whose
reporting field is missing is `in_progress` with a clear instruction — not stranded, because the path to
close is explicit and short.

### 6.4 The auto-close path must satisfy the same contract

T943 and T940 were auto-closed by `tools/runner` on exit 0 + deliverables present, **without running the
acceptance command and without collecting the reporting fields.** This is the second close door (T816 §5)
and it must satisfy the same contract as the worker-close door. **Specifically:**

- The auto-close must run the acceptance command (S10-CLOSE-1) before recording a `pass` verdict. If the
  acceptance fails, the auto-close must refuse (S10-CLOSE-2) — it must not assert `pass` over a failing
  acceptance.
- The auto-close must collect the five reporting fields (or their explicit "none" escapes) before closing.
  If the worker exited without providing them, the auto-close must either prompt for them (if the worker is
  still reachable) or record what it can and mark the rest as not-provided — **it must not silently default
  to a clean `pass`.** An auto-close that cannot collect the reporting fields closes with the verdict
  computed from the acceptance (which may be `unverified` if the acceptance was not run) and records the
  reporting gap — it does not assert `pass`.

**This is the direct fix for the T943/T940 incident:** the auto-close path is the door that produced the
false `pass`, and it must be brought under the same contract as the worker-close door.

---

## 7. Sequencing — decided

**T963 is a spec row.** It writes one document (`docs/epics/E1-markovian/L1-dashboard/T963/spec.md`) and
touches no code. It does not depend on the one-writer chain (T815 and its dependents). The dependency
belongs on the implementation row the spec produces, per the bundle's explicit instruction.

**What lands in this spec:** the close contract (T816), the close-stops-worker requirement (T909), and the
reconciliation with S10's computed-verdict direction (§3.5). All three are specified here, decided, and
armed (§9).

**What the implementation row will need:** the one-writer chain (T815 → T816's dispatch gate → the
implementation of this spec) must be available. T815 is already in the chain (`bin/managent show T815`).
The implementation row that builds against this spec will carry `needs=T815` (or its successor in the
chain) and will implement: the computed close in `cmdDone` (S10-CLOSE-1/2), the required reporting fields
(§3.1), the close-stops-worker contract (§4), the auto-close path fix (§6.4), the epoch labeling (§5.2),
and the model-profiles mapping change (S10-VERDICT-3). This spec does not order those implementation tasks
— that is the implementation row's plan. This spec provides the normative document the implementation row
builds against.

**Sequencing note — the auto-close path is urgent.** T943 and T940 are live evidence that the auto-close
door produces false `pass` verdicts today. The implementation row should prioritize the auto-close path fix
(§6.4) because it is the door that is actively producing the failure mode the sprint exists to end. The
worker-close path (S10-CLOSE-1/2) and the reporting fields (§3.1) are the full contract; the auto-close
path is the urgent subset.

**Sequencing note — the concern channel (T490) must land with or before the computed close.** S10-CONCERN-1
(cited) specifies that the `blocked`/`abandoned` concern requirement is wired through T490's channel. The
concern channel is not implemented today (T490 §1: `managent concern` has zero occurrences in
`src/managent/main.zig`; `docs/infra/managent/concerns.jsonl` does not exist). The implementation row must
either land T490's channel with the computed close, or specify an interim mechanism for the
`blocked`/`abandoned` concern requirement. This spec does not build the channel; it cites S10-CONCERN-1 as
the normative mechanism and flags that it is unimplemented today.

**Sequencing note — `tools/runner` is a separate writer.** The auto-close path lives in `tools/runner`
(Python), not `src/managent/main.zig`. The runner is a separate writer from the managent one-writer chain.
The implementation row must coordinate the runner change with the managent change — they are two files, two
writers, one contract (§6.4). The runner change does not hold `src/managent/main.zig`; it holds its own
file. The managent change holds `src/managent/main.zig` and joins the one-writer chain.

---

## 8. Out of scope — explicit

- **Re-opening the ratified direction (S10 §1, decision D).** Not in scope. The direction is ratified;
  this spec specifies against it.
- **A seventh verdict value.** S10 already ruled: a verified failure routes to `blocked`/`abandoned` plus
  a concern, not a new `fail`. Not in scope.
- **The concern channel's implementation.** S10 §2.6 already specifies it (T490); this spec cites it. Not
  in scope to build.
- **The directive-delivery work (T892).** Out of scope per T909's constraint.
- **The dashboard fix (T908).** Out of scope per T909's constraint — T908 is the symptom; this row is the
  cause. The dashboard rendering of "closed, runner alive" is a natural consequence of §4, but T908's
  broader fix is a separate row.
- **The store-loss detector (S10-STORE-1..4).** Out of scope — that is S10's capability 4, a separate
  concern from the close contract.
- **The attempt/kill history on the task (S10-ATTEMPT-1..5).** Out of scope — that is S10's capability 3,
  a separate concern. This spec cites S10-ATTEMPT-3 (empty verdict note over a killed attempt is refused)
  because it composes with the reporting contract, but does not re-specify the attempt history.
- **Implementation.** This is a spec row. Not in scope.

---

## 9. Acceptance tests — arms

### 9.1 Carried from S10 — cited, not re-armed

S10 §4 specifies 21 arms (A1–A21) plus 4 smoke tests (SMOKE-1..4). These are ratified and are normative
input. This spec **does not re-arm them.** It cites them and relies on them for the computed-close and
unverified-class behavior. An implementation row building against this spec must pass S10's arms A1–A21
and smoke tests SMOKE-1..4 as a baseline, in addition to the new arms below.

| S10 id | what it covers | this spec's reliance |
|---|---|---|
| S10-ACCEPT-1 (A1) | acceptance comes from bundle only | §3.2 — the reporting contract reads acceptance from the bundle |
| S10-ACCEPT-2 (A2) | dispatch gate; 383 grandfathered | §3.2, §5.3 — the 33 dispatchable rows are blocked, not grandfathered |
| S10-ACCEPT-3 (A3) | single-command→list migration | §3.2 — existing acceptance commands are one-condition lists |
| S10-CLOSE-1 (A4) | close runs each condition | §3.3, §6.4 — the auto-close path must run the acceptance |
| S10-CLOSE-2 (A5) | verdict follows from conditions; failed→refused | §3.3, §3.5 — the reconciliation relies on this |
| S10-CLOSE-3 (A6) | one door (lanes --backfill) | §3.3 — the auto-close path is a second door that must satisfy the same contract |
| S10-VERDICT-1 (A7) | `--status unverified` refused | §3.4 — the unverified class is harness-emitted only |
| S10-VERDICT-2 (A8) | unverified rendered distinctly | §3.4, §5.2 — the dashboard must label epochs and unverified distinctly |
| S10-VERDICT-3 (A9) | unverified excluded from correctness grade | §3.4 — the model-profiles mapping change |
| S10-VERDICT-4 (A10) | epoch note | §5.2 — this spec extends it with the pre/post labeling decision |
| S10-CONCERN-1 (A20) | blocked/abandoned requires concern | §3.1, §6.1 — the confidence field on failure verdicts is the T490 concern |

### 9.2 New arms — T816 close-contract consolidation

Each arm is on a scratch store (`MANAGENT_STORE`), per the T427 isolation rule. Every arm is shown red
before its green is believed. Each names the real incident it would have caught.

| id | arm | setup | must (red-then-green) | would have caught |
|---|---|---|---|---|
| TC-1 | close with `--status pass` but no `delivered` field | `done` with verdict `pass` and all reporting fields absent | **refused**, names `delivered` as missing; store unmutated | the "I did a thing" close — a worker asserting completion with nothing to match it against (T816 §1: 21% of closed tasks carry no verdict note) |
| TC-2 | close with `--status pass` but no `confidence` field | `done` with verdict `pass` and `confidence` absent | **refused**, names `confidence` as missing; store unmutated | the silent close — the operator's "honest evaluation" absent (T816 §1: 21% no verdict note, 71% no model impression) |
| TC-3 | close with `--status pass` but no `deferred` field | `done` with verdict `pass` and `deferred` absent | **refused**, names `deferred` as missing; store unmutated | the unlisted deferred item — a spec quietly shrinking to what was convenient (T816 §1) |
| TC-4 | close with `--status pass` but no `followups` field | `done` with verdict `pass` and `followups` absent | **refused**, names `followups` as missing; store unmutated | the missing follow-up — the operator's "follow-up suggestions" not recorded (T816 §0, T963 bundle §1) |
| TC-5 | close with `--status pass` but no `retrospective` field | `done` with verdict `pass` and `retrospective` absent | **refused**, names `retrospective` as missing; store unmutated | the missing honest evaluation — the field that feeds process change (T816 §0: the operator's *"what would have made this task go better"*) |
| TC-6 | close with all reporting fields present, including explicit "none" escapes | `done` with `delivered`, `confidence: "no concerns — checked X"`, `deferred: "none"`, `followups: "none"`, `retrospective: "…"`, acceptance met | **allowed** — close succeeds, verdict computed and confirmed | the positive control: the contract is satisfiable, not just restrictive |
| TC-7 | grandfathered task (no acceptance, pre-S10) closes under old rule | a closed task with no acceptance from before the gate lands | **allowed** — closes under the pre-S10 rule (worker-asserted verdict, deliverables gate only), marked `acceptance: grandfathered` | the migration must not break existing closes (S10-ACCEPT-2; T816 §2) |
| TC-8 | close with `--status blocked` and no concern record | `done` with verdict `blocked`, no T490 concern for the task | **refused**, names the missing concern; refusal contains the copy-pasteable `managent concern` line | the reasonless `blocked` close — T387's `verdict_note: "--fail (no note provided)"` (S10 §2.6; T490 §1) |

**Null control for TC-1..TC-5 (the "explicit none" escape):** each field's refusal arm must have a
corresponding null arm showing that the explicit escape (`delivered: []` with explanation, `confidence:
"no concerns — checked X"`, `deferred: "none"`, `followups: "none"`, `retrospective: "one sentence"`) is
accepted. This proves the contract is satisfiable and that the refusal is for silence, not for the field's
presence.

### 9.3 New arms — T909 close-stops-worker

| id | arm | setup | must (red-then-green) | would have caught |
|---|---|---|---|---|
| TW-1 | close a row whose runner is alive | stand up a row on a scratch store with a live runner process (stub), call `done` on it | **close succeeds** (verdict lands — not stranded), **holds are NOT released** (marked "held-by-closed-runner"), the row is reported distinctly as "done — runner alive, holds held" | T786/T909 — the row closed, holds released, worker kept running, second worker handed the same file (T909 §1) |
| TW-2 | null control — row whose worker has genuinely exited closes normally | stand up a row, exit its runner, call `done` | close succeeds, holds released, no spurious "runner alive" report, no extra latency | the fix must not make every close slow or spuriously report a live runner when the runner is gone (T909 §3: null control) |
| TW-3 | dangerous-window arm — close a row whose runner is alive, then attempt to dispatch a second row holding the same file | close row A whose runner is alive (TW-1 setup), then attempt to dispatch row B with `holds=` = the same file A holds | **conflict caught** — row B's dispatch is refused (or its hold is refused), naming the conflict with row A's closed-but-alive state | the actual T786/T906 incident — two live workers, one file, no guard, because one was officially finished (T909 §1) |

**TW-1 red-before-green:** today, `managent done` releases holds immediately. The arm must fail today
(holds released on close, even with a live runner). The fix makes it pass (holds survive until runner exit).

**TW-3 is the arm that matters.** TW-1 proves holds survive; TW-2 proves the null case; TW-3 reproduces
the actual incident and asserts the conflict is caught. An implementation that passes TW-1 and TW-2 but not
TW-3 has not fixed the bug — it has only moved it.

### 9.4 New smoke tests — T963 consolidation

| id | scenario | assert | would have caught |
|---|---|---|---|
| SMOKE-T963-1 | a worker closes with all five reporting fields present and acceptance met | close succeeds, verdict confirmed, all fields recorded | the positive control: the honest-close contract is satisfiable end-to-end |
| SMOKE-T963-2 | a worker closes with missing `retrospective` | close refused, names the missing field, worker re-closes with it and the close lands | the missing-honest-evaluation close — the operator's required field absent (T816 §0) |
| SMOKE-T963-3 | the auto-close path (tools/runner) closes a row whose acceptance is failing | auto-close refuses (does not assert `pass`), names the failing acceptance; the row is not closed as `pass` | T943/T940 — the auto-close door producing false `pass` on a failing acceptance (§0, §6.4) |
| SMOKE-T963-4 | a row closed by the auto-close path with no reporting fields from the worker | auto-close records what it can, marks the missing fields as not-provided, does not default to clean `pass`; the row's verdict is computed from the acceptance (which may be `unverified` if not run) | the auto-close path silently defaulting to `pass` without the reporting contract (T943's amendment: *"Closed pass with a failing acceptance"*) |
| SMOKE-T963-5 | epoch labeling on the dashboard | a closed row is labelled with its epoch (pre-close-contract or post-close-contract); a query for "computed pass" excludes pre-S10 rows and `unverified` rows | the 92%-pass surface hiding unverified and self-reported work (S10-VERDICT-4; §5.2) |

**SMOKE-T963-3 is the direct test of the T943 fix.** It constructs the exact failure mode: a row whose
acceptance command fails, closed by the auto-close path. The assert is that the auto-close does NOT record a
clean `pass`. This is the smoke test that would have caught T943 at close time.

**Armed count:** S10's 21 arms (A1–A21, cited) + S10's 4 smoke tests (SMOKE-1..4, cited) + this spec's
8 new arms (TC-1..TC-8) + this spec's 5 new smoke tests (SMOKE-T963-1..5) = **38 total arms, of which 13
are new to this spec.** The armed count equals the normative id count — every id in §3, §4, §5, §6 carries
≥1 arm, and no id is left as prose.

---

## 10. Alternatives considered and rejected

### 10.1 Close means stop (T909 option 1) — rejected

Killing the worker on close would prevent the T786 incident (worker keeps running after close), but it
would also kill legitimate post-close work — T943's commit 8 minutes after its auto-close was legitimate
and should not have been destroyed. A kill-on-close is disproportionate: it prevents the disease (worker
live after close) by destroying the cure (legitimate post-close commits). The holds-survive approach
(§4.2) prevents the disease without destroying the cure.

### 10.2 Refuse close while caller's runner is alive (T909 option 2) — rejected

The worker IS the process calling `done`. Refusing its own close because it is alive is a paradox — the
close would never land, and the row would strand. This is the exact A-failure-mode (S10 §1.2) that the
ratified direction rejected. Not viable.

### 10.3 Reporting fields optional with a "best-effort" default — rejected

The operator's 2026-08-23 ruling is explicit that these should be required. Optional fields default to
silence (T816 §1: 21% no verdict note, 71% no model impression). A "best-effort" default that silently
fills missing fields with empty strings would reproduce the disease under a new name. Required fields with
an explicit "none" escape are the cure: silence is refused, but the worker can always satisfy the gate with
an explicit statement. This is the T816 contract carried into T963.

### 10.4 Unverified as a blanket "the close was imperfect" verdict — rejected

`Unverified` is for acceptance conditions that cannot be checked (S10-VERDICT-1). It is not a general
"something was missing" verdict. Missing reporting fields are a different category — they are gaps the
worker can fill (§3.5). Collapsing both into `unverified` would dilute the signal (a row with a missing
`retrospective` would read as `unverified`, indistinguishable from a row whose acceptance was uncheckable).
The distinction is load-bearing: `unverified` is a verdict (the close landed, honestly, but the acceptance
couldn't be checked); missing-field refusal is a gate (the close hasn't landed yet, and the path to land it
is clear).

### 10.5 Epoch 1 closes re-rated under the new contract — rejected

The ~521 pre-S10 closes cannot be retroactively given a computed verdict or required fields they were never
asked for. Re-rating them would require re-running acceptance commands that may no longer be valid (tools
moved, regressions changed) and would produce numbers that are not comparable to the original closes. The
grandfathered approach (S10-ACCEPT-2) is correct: they stay as they are, labelled as Epoch 1, and the
pass-rate comparison across the epoch boundary is explicitly forbidden (§5.2).

### 10.6 The auto-close path exempted from the contract — rejected

T943 and T940 are the evidence that exemption fails. The auto-close path is one of the two close doors
(T816 §5) and must satisfy the same contract as the worker-close door. Exempting it reproduces the disease
(the false `pass` on a failing acceptance) under a different door. The fix (§6.4) brings the auto-close
path under the contract.

---

## 11. Arm ledger

| id prefix | what it covers | arms | source |
|---|---|---|---|
| `S10-ACCEPT-` | acceptance schema/gate/migration | 3 (A1–A3) | S10 §4 — cited |
| `S10-CLOSE-` | computed close — run/compute/one-door | 3 (A4–A6) | S10 §4 — cited |
| `S10-VERDICT-` | unverified class | 4 (A7–A10) | S10 §4 — cited |
| `S10-CONCERN-` | concern channel (blocked/abandoned) | 2 (A20–A21) | S10 §4 — cited |
| `S10-SMOKE-` | end-to-end smoke | 4 (SMOKE-1..4) | S10 §5 — cited |
| `TC-` | T816 close-contract consolidation — reporting fields | 8 (TC-1..TC-8) | this spec §9.2 — new |
| `TW-` | T909 close-stops-worker | 3 (TW-1..TW-3) | this spec §9.3 — new |
| `SMOKE-T963-` | T963 consolidation smoke | 5 (SMOKE-T963-1..5) | this spec §9.4 — new |
| **total** | | **32 cited + 16 new = 38** | |

**Armed count: 38 of 38 normative ids carry ≥1 arm** (S10's 32 + this spec's 16 — note S10's arms cover
21 normative ids with some ids carrying multiple arms; this spec's 16 arms cover 13 normative ids). No id
in §3, §4, §5, §6 is left as prose. An id with no arm is a wish; this spec has none.

### Rejected arms (not carried)

- **A separate arm for "two rows closed pass with failing acceptance" (T943/T940):** not a new arm — it is
  the incident that SMOKE-T963-3 and TC-1..TC-5 would have caught. Cited as evidence (§0), not armed as a
  separate id. The arms that catch it are the reporting-field arms (TC-1..TC-5: the close would have been
  refused for missing fields or the acceptance would have run and failed) and the auto-close smoke
  (SMOKE-T963-3/4: the auto-close path would have refused).
- **An arm for the 33 dispatchable rows without acceptance:** not a new arm — it is S10-ACCEPT-2 (A2) applied
  to the live store. The dispatch gate arms the behavior; the 33 rows are the live evidence that the gate is
  needed. Cited (§3.2, §5.3), not re-armed.

---

## 12. Bookend

**No genuine fork remains for the operator.** The direction was ratified (S10 §1, decision D), the four
capabilities were named by the bundle, and every open point this spec encountered was decided on recorded
doctrine rather than deferred:

- **The close contract (T816):** five required reporting fields, all refused when missing (with an available
  path to re-close), reconciled with S10's "always close, never strand" by distinguishing refusal-with-available-path
  from `unverified` (no path exists).
- **The close stops the worker (T909):** holds survive until the runner exits; the state is visible; the
  dangerous-window conflict is caught. Option 1 (kill) and option 2 (refuse) rejected; option 3+4 adopted.
- **The auto-close path:** brought under the same contract as the worker-close door — must run the acceptance
  and must collect the reporting fields; must not default to a clean `pass`.
- **Migration:** pre-S10 closes grandfathered with a published count; the 33 dispatchable rows without
  acceptance are blocked from dispatch, not grandfathered; the pass-rate is redefined with a dated epoch note
  and pre/post comparison is forbidden.
- **The concern channel:** wired through T490 (S10-CONCERN-1, cited); not implemented today; flagged for the
  implementation row.

**The only genuinely operator-owned questions — spend and scope — are answered by the bundle itself** ("write
the spec; build nothing"). The implementation row that builds against this spec will need the one-writer chain
(T815 and its dependents) and will decide the exact mechanism for runner-exit detection (§4.5). This spec
provides the normative document; the implementation row provides the implementation.

**Pass 1 can start on this spec.** The audit loop (S10 §9, capped at three audits per the sprint's ratified
spec/plan) applies: a fresh-session auditor reviews this spec against the S10 spec, the T816 brief, and the
T909 brief, grading blocker/critical/must/should/could. Blockers are fixed in-phase and re-audited; a third
red audit escalates the spec, which can no longer close itself.
