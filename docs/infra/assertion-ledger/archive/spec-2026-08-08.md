# Assertion ledger — specification

**Row:** T426 · **Identifier:** deepseek-v4-pro/T426 · **Date:** 2026-08-08
**Status:** SPEC ONLY — no implementation. Design and build are separate rows,
gated on a ruling on this spec.

**Landmark:** advances `L1 (the dashboard tells the truth)` and `L4 (the ledger
is clean)` — gives `argus --mode doctor` a structured substrate so it reports
what happened rather than inferring it, and makes the operator's most-asked
question ("can I close this console?") answerable without asking the
Orchestrator.

---

## 1. The diagnosis — why this exists

**`managent` tracks rows. The operator manages consoles. Nothing tracks
consoles.** Every question he has had to ask repeatedly this week — *should I
follow up? can I close this console? has it been absorbed?* — is a question
about a **console**, an entity the system has no representation of. The
kanban's `status: done` says the row is done; it says nothing about whether the
findings were absorbed, whether the Orchestrator recommended close, or whether
the human closed the console.

Second: **`tasks.json` stores derived state.** `status: done` is a *stored
assertion about the world* that can silently disagree with the world — which is
how five rows this week were worked and committed while reading `dispatchable`
(T392, T395, T400, T404, T419). Aspiration and actuality are confusable
**because the schema lets them be stored as the same thing.**

Third: **attribution is reconstructible but not queryable.** Who claimed T423?
When was T404 absorbed? The data exists — in `tasks.json` timestamps, in git
log, in the Orchestrator's commit messages — but answering the question means
reading three sources and correlating them. The operator cannot ask "show me
every assertion the Orchestrator made today" without reading the Orchestrator's
entire console transcript.

---

## 2. The assertion record — data model

### 2.1 Format

JSON Lines, one assertion per line, append-only. Stored at
`docs/infra/assertion-ledger/assertions.jsonl`.

```json
{
  "id": "A0001",
  "ts": "2026-08-08T12:00:00Z",
  "actor": "Opus/Orcha",
  "verb": "dispatched",
  "object": "T426",
  "basis": "performed",
  "supersedes": null,
  "meta": {}
}
```

### 2.2 Fields

| field | required | meaning |
|---|---|---|
| `id` | yes | opaque monotonic identifier (`A0001`, `A0002`, …). Assigned by the writer; never reused. |
| `ts` | yes | ISO-8601 UTC timestamp with seconds. |
| `actor` | yes | who made the assertion — a seat identifier per `docs/infra/agent-identity-and-worker-channel.md`: `<model>/<role>` for court seats (`Opus/Orcha`, `deepseek-v4-pro/Dabir`), `<model>/<task-id>` for workers (`minimax-m3/T425`), `<model>/argus` for the watchdog, or `human`. Never bare. |
| `verb` | yes | what happened — a controlled vocabulary (see §2.3). |
| `object` | yes | what the assertion is about — a task ID (`T426`), a file path, a console identifier, or `*` for project-wide assertions. |
| `basis` | yes | how the actor knows — `performed` (the actor did it), `observed` (the actor saw it in the world), `reported-by` (the actor is relaying what another party said). **This is the field that separates aspiration from actuality.** |
| `supersedes` | no | assertion ID this one corrects or replaces. When set, this is a correction; the original assertion remains in the log, readable and immutable (§3). |
| `meta` | no | free-form object for verb-specific detail (§2.4). Never carries information that belongs in a dedicated field. |

### 2.3 Verb vocabulary

**Row lifecycle verbs** — assert a row's state changed:

| verb | meaning | who may assert | basis |
|---|---|---|---|
| `dispatched` | human queued the task to an agent | human, Orchestrator (on human's behalf) | `performed` |
| `claimed` | agent claimed the task | agent, Orchestrator (on agent's behalf) | `performed` |
| `completed` | agent reported done (verdict attached in `meta`) | agent, Orchestrator (on agent's behalf) | `performed` |
| `reopened` | task reopened to dispatchable | Orchestrator | `performed` |
| `amended` | post-close correction appended | Orchestrator, agent | `performed` |
| `purged` | task removed from kanban | Orchestrator | `performed` |

**Console lifecycle verbs** — assert a console's state changed:

| verb | meaning | who may assert | basis |
|---|---|---|---|
| `absorbed` | Orchestrator absorbed findings into durable docs | Orchestrator | `performed` |
| `recommended-close` | Orchestrator recommends the human close the console | Orchestrator | `performed` |
| `closed` | human closed the console | human | `performed` |
| `killed` | console was terminated (crash, kill directive, runner guard) | Orchestrator, runner | `observed` |

**Observational verbs** — assert a fact about the world:

| verb | meaning | who may assert | basis |
|---|---|---|---|
| `observed` | actor observed a fact in the world (git, filesystem, process table, claimlint output) | any | `observed` |
| `refused` | an action was refused by a gate | the gate's owner | `performed` |
| `superseded` | an earlier assertion is corrected | any (but only about own prior assertions, or by Orchestrator about any) | `performed` |

**Meta verbs** — project-wide state:

| verb | meaning | basis |
|---|---|---|
| `deployed` | binaries deployed to `bin/` | `performed` |
| `swept` | argus ran a mode | `performed` |

### 2.4 The `meta` field — verb-specific detail

The `meta` object carries detail that is specific to the verb. It is **never**
a substitute for a dedicated field — if a value is needed by two different
verbs, it belongs in a top-level field.

| verb | `meta` keys | meaning |
|---|---|---|
| `completed` | `verdict` (required), `verdict_note` | terminal verdict and explanation |
| `completed` | `skip_acceptance_reason` | why acceptance was skipped |
| `completed` | `force` (bool) | true when `--force` was used (T390 close window) |
| `dispatched` | `to` | agent name (informational) |
| `dispatched` | `note` | free-form dispatch note |
| `observed` | `source` | command or path that produced the observation |
| `observed` | `value` | the observed value (string or number) |
| `refused` | `reason` | why the action was refused |
| `refused` | `action` | what action was attempted |
| `amended` | `post_close` (bool) | true if post-close amendment (T424) |
| `amended` | `verdict` | new verdict if verdict correction |
| `amended` | `note` | amendment text |
| `absorbed` | `claims_count` | number of claims absorbed |
| `absorbed` | `new_rows_count` | number of new register rows |
| `killed` | `reason` | why the console died |
| `deployed` | `from`, `to` | zig-out path → bin/ path |
| `swept` | `mode` | which argus mode ran |
| `swept` | `findings_count` | number of findings emitted |

---

## 3. Append-only — corrections never delete

**Assertions are never mutated or deleted.** A correction is a **new assertion
superseding** an earlier one, and both remain readable — the same principle
`managent amend` already uses for verdicts, generalised.

A correcting assertion carries `supersedes: "A0004"`. The original assertion
`A0004` stays in the log. A reader that encounters a chain of superseding
assertions derives the current state from the **most recent** assertion in the
chain, while the full history remains visible for audit.

**Who may supersede:**
- An actor may supersede its own prior assertions.
- The Orchestrator may supersede any assertion (kanban ownership, D-8).
- Argus never supersedes — it only observes.

**Example:**

```json
{"id":"A0010","ts":"...","actor":"deepseek-v4-flash/T423","verb":"completed","object":"T423","basis":"performed","meta":{"verdict":"pass"}}
{"id":"A0012","ts":"...","actor":"Opus/Orcha","verb":"superseded","object":"A0010","basis":"performed","supersedes":"A0010","meta":{"reason":"verdict was pass-with-findings, not pass"}}
{"id":"A0013","ts":"...","actor":"Opus/Orcha","verb":"amended","object":"T423","basis":"performed","meta":{"verdict":"pass-with-findings","note":"D064 arrived post-close; re-pointing landed in commit 4330ef2"}}
```

The current verdict for T423 is `pass-with-findings` (from A0013), not `pass`
(from A0010). The correction trail is preserved: A0010 → superseded by A0012 →
corrected by A0013.

---

## 4. Status is DERIVED, never stored

**The display utility computes current state from the assertion log plus the
observable world** (git, filesystem, process table). It does not store a
`status` field. **If a derived status disagrees with an assertion, the utility
shows the disagreement rather than picking a winner** — that disagreement is
the most valuable output the whole system can produce.

### 4.1 What "derived" means — worked example

**Question:** "Can the operator close the T423 console?"

**Derivation, step by step:**

1. Read the assertion log for T423. Find the most recent non-superseded assertion of each verb.
2. Derive the console's current state from the sequence:
   - `dispatched` (A0001) → `claimed` (A0002) → `completed` (A0013, corrected to pass-with-findings) → `absorbed` (A0020) → `recommended-close` (A0021) → **`closed` is missing**
3. Cross-check against the observable world:
   - `git log --oneline` shows the absorption commit → `absorbed` assertion confirmed.
   - `findings/T423-*.json` conforms → `completed` assertion confirmed.
   - `bin/managent status --json` shows T423 `done` → kanban agrees with `completed`.
   - But: no `closed` assertion exists.
4. **Derived status: `recommended-for-close`, waiting on `closed`.** The console is closable — all prerequisites are met — but the `closed` assertion is missing.

**If a derived status disagrees with an assertion:**

- Suppose A0021 says `recommended-close` but the doctor finds no `absorbed` assertion and no absorption commit in git.
- The doctor reports: **"T423: recommended-close asserted (A0021, Opus/Orcha) but NO absorbed assertion and no absorption commit — gap between completed and recommended-close."**
- This is a NEEDS ACTION — the Orchestrator asserted a close recommendation without absorbing first.

### 4.2 Rules for derivation

1. For each object (row, console), collect all non-superseded assertions.
2. Order by `ts`.
3. Derive current state as the last `performed` assertion of each lifecycle verb.
4. Cross-check `performed` assertions against `observed` assertions and the observable world.
5. Report disagreements; never resolve them silently.

---

## 5. The console as a first-class entity

The console has its own lifecycle, distinct from the row's. A row's lifecycle is
`dispatchable → in_progress → done`. A console's lifecycle is:

```
dispatched → working → reported → absorbed → recommended-for-close → closed
```

The row lifecycle says *what the task's status is*. The console lifecycle says
*what the human should do about the terminal window*. A row can be `done` while
its console is still open (waiting for absorption); a row can be `purged` while
evidence of its console's close remains in the assertion log.

### 5.1 Transitions, and who may assert each

| transition | verb | who may assert | basis |
|---|---|---|---|
| → `dispatched` | `dispatched` | human (or Orchestrator on human's behalf) | `performed` |
| `dispatched` → `working` | `claimed` | agent (or Orchestrator on agent's behalf) | `performed` |
| `working` → `reported` | `completed` | agent (or Orchestrator on agent's behalf) | `performed` |
| `reported` → `absorbed` | `absorbed` | **Orchestrator ONLY** | `performed` |
| `absorbed` → `recommended-for-close` | `recommended-close` | **Orchestrator ONLY** | `performed` |
| `recommended-for-close` → `closed` | `closed` | **human ONLY** | `performed` |

**`absorbed` and `recommended-for-close` are Orchestrator assertions — that is
where the accountability the operator asked for actually lands.** The
Orchestrator cadence (`ORCHESTRATOR.md` §"Cadence") already prescribes
absorption at step 4; the assertion log makes it checkable.

### 5.2 Console identifier

A console is identified by its row ID (`T426`). One row = one console. Reopens
create a second console for the same row — the assertion log records both,
distinguished by `claimed` timestamps.

### 5.3 Console state derived from assertions

At any point, a console's derived state is the **last performed verb in the
lifecycle sequence, provided all prior verbs exist.** Missing verbs = gap (see
§6).

---

## 6. The anti-skip property

**For every step: is it *refused* when out of order, or does skipping leave a
*visible gap*? One or the other, never neither.**

### 6.1 Refused transitions (hard gates)

These actions are mechanically refused when attempted out of order:

| action | refused when | enforced by | precedent |
|---|---|---|---|
| `claim` | `needs` unmet or `holds` locked | `managent claim` — BLOCKED / REJECTED | built-in since day 1 |
| `done` | `agent` unset (attribution not recorded) | `managent done` — refuses, exits non-zero | ORCHA-AUTOMATION §3 |
| `done` | claim-at-close window (T390: < 10s since claim) | `managent done` — refuses unless `--force`; forced close appends amendment | T390, T424 |
| `git-commit-mine` | row is not `in_progress` | `tools/git-commit-mine` — refuses | T424 |
| `dispatch` | task already `in_progress` or `done` | `managent dispatch` — **warns, not refuses** (audit trail priority; see spec.md) | built-in |

### 6.2 Visible-gap transitions (soft — reported by the doctor)

These steps are not mechanically gated, but their absence produces a visible gap
in the assertion log that `argus --mode doctor` reports:

| missing assertion | what the doctor reports | under which group |
|---|---|---|
| No `claimed` after `dispatched` | "T4xx dispatched but never claimed — did the agent start?" | WATCH |
| No `completed` after `claimed` + heartbeat stopped | "T4xx in_progress, no heartbeat for N min" | WATCH |
| No `completed` after `claimed` + row still `in_progress` | "T4xx in_progress, no heartbeat" | WATCH |
| No `absorbed` after `completed` | "T4xx completed but not absorbed — findings not in register" | NEEDS ACTION |
| No `recommended-close` after `absorbed` | "T4xx absorbed but not recommended for close — Orchestrator owes recommendation" | NEEDS ACTION |
| No `closed` after `recommended-close` | "T4xx recommended for close but console not closed" | CAN CLOSE (informational — the operator reads this line to know which consoles to close) |
| `absorbed` asserted but no absorption commit in git | "T4xx absorbed asserted (A00NN) but no absorption commit found" | NEEDS ACTION |
| `completed` asserted but findings non-conforming | "T4xx completed but findings non-conforming — cannot absorb" | NEEDS ACTION |

### 6.3 Gap classification — design rule

A step is a candidate for "refused" when:
- The enforcing system (managent, git-commit-mine) can check the precondition
  mechanically at the moment of the action.
- The refusal changes the actor's behaviour (they must fix the precondition
  before retrying).

A step is a "visible-gap" when:
- No single system sees both the precondition and the action (e.g., absorption
  happens across git + CLAIMS.md + the assertion log — no single tool gates it).
- The check requires correlating multiple sources (assertions + git + filesystem).
- The cost of a false refusal is higher than the cost of a visible gap (e.g.,
  refusing `closed` because `absorbed` is missing would block the human from
  closing a console where absorption was done but not recorded — the gap is
  better).

**Any step that is neither refused nor visible-gap is a design defect.**
This spec enumerates every step above; a step missing from both tables is an
open finding against this spec.

---

## 7. Display, not narration

**The utility prints facts and their sources. It does not summarise, does not
editorialise, does not conclude.** If it says a console can be closed, it must
be able to show the assertions that make that true. **Prose is the
Orchestrator's job; the tool's job is to make the Orchestrator's prose
checkable.**

### 7.1 argus --mode doctor IS the display utility

**The operator's own guess was correct.** `argus --mode doctor` (T425) already
does what he described — a one-screen report grouped by what he should DO
(NEEDS ACTION / CAN CLOSE / WATCH / CLEAN). It already names its evidence and
the fix command. It already says "CAN CLOSE" when a row is done, committed,
findings-conforming, and nothing is owed.

**The assertion ledger gives it a better substrate.** Today the doctor derives
status by running `managent status --json`, `managent liveness`,
`bin/weizigo-claimlint`, `git status`, and `ps`, then inferring what state each
console is in. With the assertion ledger:

1. The doctor reads the assertion log directly.
2. For each row, it derives console state from assertions (§5.3).
3. It cross-checks against the observable world (§4.2).
4. Disagreements are surfaced under the existing NEEDS ACTION / WATCH groups.
5. CAN CLOSE becomes: rows whose derived state is `recommended-for-close` and
   whose cross-checks are clean.

**No new tool. No new output format.** The operator already reads
`untracked/doctor-report.md`. The assertion ledger makes the same report
checkable rather than inferred.

### 7.2 What the doctor does NOT do

- Does NOT write prose that summarises or concludes. The operator's request: *"a
  utility that simply displays status — it does not presume nor narrate."*
- Does NOT pick a winner when assertions disagree — shows the disagreement.
- Does NOT mutate state — read-only per Argus's authority (ARGUS.md §Authority).
- Does NOT recommend actions beyond naming the fix command (already in the
  existing doctor: `managent claim <id>`, `zig build deploy`, etc.).

---

## 8. Mistake patterns as data

**The operator asked to log recurring mistake patterns *and* their
remediation.** The minimal shape proposed here is an assertion about a pattern,
not a separate artifact:

### 8.1 Pattern record

A pattern is recorded as an assertion with `verb: "observed"` and a
`meta.pattern` object:

```json
{
  "id": "A0100",
  "ts": "2026-08-08T14:00:00Z",
  "actor": "deepseek-v4-pro/argus",
  "verb": "observed",
  "object": "*",
  "basis": "observed",
  "meta": {
    "pattern": {
      "id": "worked-without-claiming",
      "description": "row completed/committed while still dispatchable",
      "occurrences": 5,
      "latest": ["T392", "T395", "T400", "T404", "T419"],
      "detected_by": "argus --mode doctor (worked-without-claiming check, T425)"
    }
  }
}
```

When a pattern is remediated, a new assertion records it:

```json
{
  "id": "A0101",
  "ts": "2026-08-08T14:30:00Z",
  "actor": "Opus/Orcha",
  "verb": "observed",
  "object": "*",
  "basis": "observed",
  "meta": {
    "pattern": {
      "id": "worked-without-claiming",
      "status": "remediated",
      "remediated_by": "T424: git-commit-mine refuses when row is not in_progress",
      "since": "2026-08-07",
      "occurrences_since": 0
    }
  }
}
```

### 8.2 Why assertions, not a separate patterns register

- One less artifact to maintain.
- Patterns are discovered by argus (which already has verb `observed`).
- The same append-only / superseding semantics apply — a pattern's status
  can be corrected.
- Query: "show me every pattern assertion" is a filter on `meta.pattern`
  existing, which is a single jq invocation.

### 8.3 Pattern vocabulary (non-exhaustive — discovered, not prescribed)

| pattern ID | description | first detected |
|---|---|---|
| `worked-without-claiming` | row completed/committed while still dispatchable | T392 (2026-08-07) |
| `dead-console` | in_progress with no heartbeat for > 30 min | T387 (2026-08-06) |
| `non-conforming-findings` | findings file missing required fields | T392 (2026-08-07) |
| `volatile-evidence` | citation to /tmp or absolute-outside-tree path | T421 (2026-08-08) |
| `stale-deploy` | deployed bin/ older than zig-out | T425 (2026-08-08) |
| `absorption-backlog` | C7 unabsorbed findings ≥ threshold | standing tier (2026-07-30) |
| `forced-close` | `done --force` used to bypass claim-at-close window | T390 (2026-08-06) |
| `unattributed-close` | `done` attempted with `agent` unset | ORCHA-AUTOMATION §3 (2026-07-30) |

---

## 9. Migration — honest costs and risks

### 9.1 What changes

| artifact | change | risk |
|---|---|---|
| `docs/infra/assertion-ledger/assertions.jsonl` | **NEW.** Created empty; appended to by managent and argus. | Low — new file, no existing data to corrupt. |
| `src/managent/main.zig` | Every state-changing verb appends an assertion after completing its current write. | Medium — managent is the kanban's single source of truth. Regression risk in existing verbs. Mitigation: the existing test suite covers every verb; add an assertion-log check to each test case. |
| `bin/argus` | Doctor mode reads the assertion log for console lifecycle derivation; adds cross-check against observable world. | Low — argus is Python, well-tested, read-only. The doctor already reads `managent status --json`; adding assertion log parsing is a new data source, not a rewrite. |
| `tools/git-commit-mine` | Optionally appends an assertion when it refuses a commit (T424 `refused` verb). | Low — one new append. |

### 9.2 What does NOT change

- **`tasks.json` is untouched.** The assertion log is additive, not a replacement. The kanban continues as the operational store; the assertion log is the audit trail. Both are authoritative — `tasks.json` for current operational state, the assertion log for history.
- **No migration of existing data.** We do not replay git history or `tasks.json` into assertions. The log starts at the point of deployment; prior history stays in git.
- **No new binary.** managent writes assertions; argus reads them. No `bin/weizigo-assertion` tool.

### 9.3 The two-sources-of-truth problem

During the transition period (and indefinitely — `tasks.json` and the assertion
log are two records of the same events), they may disagree. Resolution:

1. **For current operational state** (what is the kanban showing right now?):
   `tasks.json` is authoritative. The kanban is the kanban.
2. **For history** (who claimed this row, when, and was it absorbed?): the
   assertion log is authoritative. The log is append-only; `tasks.json` can be
   corrupted.
3. **When they disagree:** `argus --mode doctor` reports the disagreement under
   NEEDS ACTION. The fix is to amend or correct the assertion (append a
   `superseded`), never to silently reconcile.

### 9.4 What could go wrong

| failure mode | consequence | detection | recovery |
|---|---|---|---|
| managent writes assertion but atomically renames `tasks.json` before the assertion append crashes | assertion missing, kanban correct | doctor reports gap between kanban state and assertion log | Orchestrator appends a corrective `observed` assertion |
| assertion log grows unbounded (thousands of assertions per sprint) | file size, parse time | argus parse time degrades; doctor reports it | implement log rotation (compact assertions older than N days into a summary record; TBD — not in this spec) |
| concurrent assertion appends from two processes | corrupted line (partial write) | JSON parse failure on that line | argus skips unparseable lines, reports under NEEDS ACTION; the writer retries |
| `tasks.json` corrupted (again) | kanban wrong, assertion log intact | kanban/assertion disagreement reported by doctor | restore tasks.json from git; re-derive from assertion log if needed (manual, Orchestrator) |
| assertion written for a verb but missing `basis` | assertion is valid but less useful | doctor reports `basis` missing as a non-conforming assertion | correct with a superseding assertion |

### 9.5 Concurrency — assertion writes

`managent` already uses `flock` on `tasks.json` for every read and write. The
assertion log uses the same lock — managent acquires the lock, writes
`tasks.json`, appends the assertion, releases the lock. No new concurrency
primitive.

`argus` only reads the assertion log — no lock needed for reads (atomic append
means a partial line at EOF is the only corruption mode, handled by skipping
unparseable lines).

### 9.6 Cost estimate

| work item | effort | risk |
|---|---|---|
| managent: add assertion append to claim/done/dispatch/reopen/amend/purge/tell | ~200 lines of Zig | Medium — every verb test gets an assertion check |
| managent: add assertion append to `done --force` (forced close) | ~20 lines | Low |
| argus: parse assertion log, derive console state | ~150 lines of Python | Low |
| argus: cross-check derived state against observable world | ~100 lines of Python | Low |
| argus: report disagreements in doctor output | ~50 lines of Python | Low |
| tools/git-commit-mine: append `refused` assertion | ~20 lines of bash | Low |
| Test suite: extend each managent verb test with assertion-log check | ~100 lines of Zig | Low |
| **Total** | **~640 lines** | **Medium** |

---

## 10. What this spec explicitly does NOT build

1. **A separate CLI tool for the assertion ledger.** `managent` writes it;
   `argus` reads it. No `bin/weizigo-assertion`. The operator's request was for
   a display utility he already has.

2. **A migration that replaces `tasks.json`.** The assertion log is additive.
   `tasks.json` remains the kanban's operational store. Replacing it would be a
   separate ADR with its own risk assessment — this spec does not propose it.

3. **A schema that stores derived state.** The whole point is that status is
   derived, never stored. An assertion says "Opus/Orcha absorbed T423 at
   12:00"; the derived state "T423 console is in `absorbed` state" is never
   written to disk.

4. **Prose generation.** The tool displays facts and sources. The Orchestrator
   writes the prose. A tool that writes "T426 is ready to close" is a tool that
   narrates; this spec forbids it.

5. **A looping console.** The operator explicitly excluded this (T425 brief):
   *"Do NOT build the looping console. Make argus --mode doctor correct and
   fast; a loop around a trustworthy one-liner is then trivial."* The assertion
   ledger is the substrate that makes the one-liner trustworthy.

6. **Real-time push notifications.** The assertion log is polled, not pushed.
   argus runs on demand; a cron or `watch` loop polls it. A push mechanism
   (inotify, filesystem events) is a separate concern.

7. **Assertion log for argus sweep/checklist modes.** Those modes have their
   own log (`untracked/watchdog.md`). The assertion log is for row and console
   lifecycle; watchdog findings stay in the watchdog log. The boundary: the
   assertion log records *what happened* (state changes); the watchdog log
   records *what argus found* (drift detections).

8. **Schema migration for `tasks.json`.** No new fields, no format change. The
   assertion log is a new file alongside the kanban, not inside it.

---

## 11. Minimal subset to ship first

**Recommendation: ship Phase 1. Phase 2 is specified here so the design is
complete, but it should be a separate row, ruled on after Phase 1 has run for
at least one sprint.**

### Phase 1 (this spec recommends shipping first)

1. **The assertion record format** (§2) — the JSONL schema, the controlled
   vocabulary, the `basis` field.
2. **managent appends assertions** on its existing state-changing verbs:
   `claim`, `done`, `dispatch`, `reopen`, `amend`, `purge`, `tell`. Every verb
   writes one assertion after completing its current write.
3. **argus --mode doctor** adds one new check: **console lifecycle gaps** (§6.2).
   The doctor reads the assertion log, derives each row's console state, and
   reports missing transitions under the existing NEEDS ACTION / WATCH groups.
4. **tools/git-commit-mine** appends a `refused` assertion when it refuses a
   commit (the T424 gate).

**What Phase 1 gives the operator:** the doctor's CAN CLOSE line becomes
checkable. Today it says "no CAN CLOSE candidates" (or lists rows that look
closeable based on git+kanban heuristics). After Phase 1, it says "T423: all
assertions present (dispatched → working → reported → absorbed →
recommended-for-close) — ready to close." The operator reads the line, finds
the assertions backing it, and closes the console. No asking the Orchestrator.

### Phase 2 (separate row, after Phase 1 has run)

1. **Console lifecycle as first-class entity** (§5) — console state derived
   entirely from assertions, row state from kanban, disagreements surfaced.
2. **Mistake patterns as data** (§8) — argus appends pattern observations;
   Orchestrator appends remediation assertions.
3. **argus derives ALL status from the assertion log** — the current
   command-output-parsing approach becomes the cross-check, not the primary
   source.

---

## 12. Acceptance criteria — what "done" means for this spec

This row delivers a specification. The acceptance criteria are about the spec,
not about implementation:

1. **The diagnosis is stated** (§1) — why the assertion ledger exists, what
   problem it solves, why `tasks.json` alone is insufficient.
2. **The assertion record is fully specified** (§2) — fields, vocabulary,
   `basis`, `meta`, with examples.
3. **Append-only semantics are defined** (§3) — corrections as superseding
   assertions, who may supersede.
4. **Derived status is defined** (§4) — how the doctor computes state from the
   log, what cross-checks it performs, how disagreements are surfaced.
5. **Console lifecycle is defined** (§5) — distinct from row lifecycle, who may
   assert each transition, how state is derived.
6. **The anti-skip property is enumerated** (§6) — every step classified as
   refused or visible-gap, with the enforcing mechanism named. No step is
   neither.
7. **The relationship with T425 is evaluated honestly** (§7) — argus --mode
   doctor IS the utility; the ledger is a better substrate. No new tool.
8. **Mistake patterns are specified** (§8) — a minimal queryable shape, using
   the assertion log rather than a separate register.
9. **Migration is costed honestly** (§9) — what changes, what does not, what
   could go wrong, the two-sources-of-truth problem, effort estimate.
10. **What is NOT built is explicit** (§10) — seven explicit exclusions, so the
    next reader does not rediscover the boundaries.
11. **Minimal subset is recommended** (§11) — Phase 1 first, Phase 2 later,
    with what each phase gives the operator.
12. **Findings file conforming** — `findings/T426-assertion-spec.json` with
    `task_id`, `date`, `model`, `claims`.
13. **Landmark line and human summary** per `AGENTS.md` §"Closing report."

---

## A. Design decisions recorded

### A.1 Why JSON Lines, not a SQLite database

- Append-only, human-readable with `tail -1`, no schema migration tooling.
- The project already uses JSON Lines (`untracked/heartbeat.jsonl`,
  `untracked/watchdog.md`).
- A database would need a migration path, a schema version, and a query
  interface — all of which are a second row's worth of work. JSON Lines is the
  smallest thing that closes the operator's pain.

### A.2 Why no separate patterns register

- Patterns are discovered by argus, which is already an observer.
- A separate artifact duplicates the append-only / superseding semantics.
- A query like "show me every pattern" is `jq 'select(.meta.pattern)'`.
- If patterns grow complex enough to need their own schema, that is a finding
  to address then — not a reason to build one now.

### A.3 Why `basis` is mandatory, not optional

The operator's core request: *"So that we don't confuse aspirations and
actualities."* The `basis` field is what separates "I did this" from "I saw
this" from "someone told me this." Making it optional would allow it to be
omitted, which is the same thing as allowing aspiration and actuality to be
confusable. A missing `basis` is a non-conforming assertion — the doctor reports
it under NEEDS ACTION.

### A.4 Why the doctor does not pick a winner

The operator: *"a utility that simply displays status — it does not presume nor
narrate."* When an assertion disagrees with the observable world, both are facts:
the assertion was made (that is a fact), and the world says something else (that
is also a fact). The doctor reports both. The Orchestrator resolves the
disagreement — by appending a superseding assertion, or by fixing the world
(committing, deploying, absorbing). A tool that picks a winner is a tool that
narrates.

### A.5 Why `absorbed` and `recommended-close` are Orchestrator-only

The operator: *"Orcha is responsible for doing so, and for updating the status.
Thus Orcha is accountable."* If an agent could assert `absorbed`, the assertion
would be an aspiration — the agent hopes its work was absorbed. Only the
Orchestrator knows whether absorption actually happened (it is the Orchestrator's
cadence step 4). Similarly, only the Orchestrator can recommend close — it is
the Orchestrator's judgement that nothing is owed. A worker asserting its own
absorption or close recommendation is the exact confusion of aspiration and
actuality this ledger exists to prevent.
