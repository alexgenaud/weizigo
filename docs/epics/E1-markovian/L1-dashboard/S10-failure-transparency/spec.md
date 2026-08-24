# S10 — failure transparency: honest close, fault recovery (spec)

**Task:** T846 · **Author:** deepseek-v4-pro · **Date:** 2026-08-24
**Landmark:** advances L1 (the dashboard tells the truth) — a task's recorded outcome stops being
a self-report.
**Inputs:** the T846 bundle (operator problem statement + ratified direction, 2026-08-24);
`docs/infra/concern-channel-spec.md` (T490, 2026-08-19 — *specification, not implementation*);
T816 (the close contract), T798 (kill visible in kanban), T716 (unregistered-lanes root cause);
`src/managent/main.zig` (cmdDone, cmdLanes);
`tools/dispatch_verify.py` (T629 `KILLED_BY_VALUES`), `tools/runner` (T629 `_killed_by`);
`tools/model-profiles.py` (verdict→correctness map).

This is a spec. It does not implement. Every deliverable below is a *definition* — of a contract,
a schema, a verdict computation, a detector, and the arms that would have caught each named
incident — concrete enough that a following pass can dispatch it as a row without re-deriving the
shape. The operator reviews it before pass 1.

## 0. The honest reading, stated first because the bundle demands it

The measured baseline (cited, not re-derived — from the T846 bundle):

| fact | number |
|---|---|
| closed `pass` / `pass-with-findings` | **444** (92% of all closes) |
| `fail-found`, all time | **4** in 573 tasks |
| tasks with acceptance criteria recorded | **123 / 573 (21%)** |
| tasks with neither acceptance nor a stated reason | **383 (67%)** |
| declared deliverable paths absent from git | **65 of 429** — 37 one unrepointed directory rename, 5 gitignored binaries, ~20 genuinely questionable |
| tasks lost to a stale-snapshot store revert, 2026-08-24 | **59**, discovered only because a worker logged `FAIL kanban: task T836 not found` |
| `killed_by` occurrences | **18 in `tools/runner`, 0 in the kanban schema** |
| harness kills, all time | 86 tasks, **1,476 events**, in gitignored working state; the one tracked kill ledger (`docs/infra/dispatch-heals.jsonl`) holds **zero** |

Deliverable-presence largely works — `managent done` already refuses a close whose declared
deliverables are not cleanly in git, and it refused the oversight seat twice on 2026-08-23. What
does not exist is any way to detect **partial** completion — and for 67% of tasks there is nothing
to check completeness *against*. The gap is not leniency; it is that **the worker grades itself.**
`--status` defaults to `pass` (`src/managent/main.zig:4358`), so the path of least resistance
passes; `acceptance` is an optional field, so the path of least resistance omits it. The verdict
is an assertion, and the only thing ever checked against it is whether the files exist.

## 1. The ratified direction — D, emitting C

Four options were weighed by the oversight seat, 2026-08-24:

- **A. Strict refusal** — cannot verify, cannot close; forced to `blocked`.
- **B. Lenient** — close permitted, mandatory list of what could not be verified.
- **C. A distinct verdict class** — `unverified` first-class, propagated everywhere.
- **D. Computed verdict** — the harness determines the verdict from checked conditions; the
  worker does not assert it.

**Decision: D, emitting C, with A only where it is mechanically unambiguous.** The reasoning,
which this spec carries and must not soften:

1. **A, B and C all still ask the worker to characterise its own work.** Strictness that rests on
   self-report is not strict. D removes self-report from the determination for anything checkable.
2. **A's failure mode is disqualifying:** a refused close leaves the task `in_progress`, which is
   indistinguishable from a live worker. Measured twice on 2026-08-23 — T818 complete-but-unclosed
   read as *orphaned* for two hours, and sixteen tasks read as in flight while zero were alive.
   **A verdict that cannot be recorded becomes a lie of a different kind.** So: **always close,
   never strand — but close honestly.**
3. **A does apply narrowly and already works:** declared deliverables absent from git is
   mechanically unambiguous, and `managent done` already refuses it. Keep that.
4. **Every soft gate in this repository has been routed around** — five dispatch doors, two close
   doors, appetite read only by `assign`, caps read only by the keeper. A gate that can be
   satisfied by assertion will be.

So: **the close computes what it can, records `unverified` for what it cannot, and never refuses
to record an outcome except where there is nothing to record it about.**

The verdict space after this spec has six outcomes, but they are not peers — three are *asserted
claims*, one is *computed*, two are *asserted failures with a mandatory reason*:

| outcome | who produces it | meaning |
|---|---|---|
| `pass`, `pass-with-findings` | worker **claims**, harness **confirms** | every acceptance condition verified met; deliverables in git |
| `fail-found` | worker claims, harness confirms via findings + absorption gate | a successful falsification with full deliverables |
| `unverified` | **harness emits, worker cannot assert** | ≥1 acceptance condition could not be checked |
| `blocked`, `abandoned` | worker asserts, **concern required** (§2.6) | cannot proceed / gave up — the reason is structured, not free text |

A worker's `--status pass` is a claim, not a verdict. The harness computes the verdict from the
conditions. This is the whole mechanism; the rest of the spec is its parts.

## 2. The five capabilities (normative)

### 2.1 Computed close

**S10-ACCEPT-1 — acceptance is a structured list, authored by the specifier before dispatch, never
by the worker at close.** A task's acceptance is a list of conditions, not a single shell command.
Logical schema (the exact encoding is a design-phase decision; the shape and behavior are
normative here):

```
acceptance_conditions: [
  { id: "<short>", kind: "command",     spec: "<shell command run at close; exit 0 = met>" }
  { id: "<short>", kind: "uncheckable", spec: "<what would need checking>",
    reason: "<why the specifier declared it uncheckable — recorded, never silent>" }
]
```

Authorship is the mitigation for concern 5 (workers writing trivially-checkable conditions to earn
a clean computed pass): acceptance lives in the bundle meta header, written by whoever mints the
brief. The close reads it **only from the bundle**; any worker-supplied `--acceptance` flag on
`managent done` is refused — acceptance is not a close-time input.

**S10-ACCEPT-2 — acceptance gated at dispatch, with the 383 grandfathered and counted.** A task
cannot be *dispatched* without acceptance conditions or an explicit `--skip-acceptance <reason>`.
Gate at dispatch, not registration (minting a placeholder is legitimate; running work against an
unstated bar is not). The 383 tasks that already exist with neither are **grandfathered**: on the
date the gate lands, the open subset is snapshotted and published as a count; those tasks close
under the pre-S10 rule (worker-asserted verdict, deliverables gate only) with a marker
`acceptance: grandfathered`, and **no new task may join the set** — the dispatch gate closes it.
This is concern 3's resolution: the `unverified` class is not flooded by a backlog it can no
longer prevent, and it remains a meaningful signal going forward. (T816 specifies the dispatch
gate; S10 absorbs it — see §7.)

**S10-ACCEPT-3 — migration, never silent.** The 123 existing tasks whose `acceptance=` is a single
command are treated as a one-condition list (`kind: command`). A task with no acceptance at all
and no skip reason is `unverified`-eligible, not exempt — the harness cannot check what was never
written, and it must say so rather than pass it.

**S10-CLOSE-1 — the close runs each condition and records the outcome.** For a `pass` /
`pass-with-findings` claim, the close runs each `command` condition via the existing
`/bin/sh -c` path and records, per condition, one of: `met` (exit 0) · `failed` (non-zero exit,
with the code) · `cannot-run` (exit 126/127 or spawn failure — an infrastructure fault, the T295
distinction already in the code, not a task failure) · `unverified` (kind `uncheckable`, carrying
the specifier's declared reason). `fail-found` remains exempt from the acceptance run, as today:
its bar is the findings file and the absorption gate, which are already mechanical
(`refuseIfUnabsorbed`).

**S10-CLOSE-2 — the verdict follows from the conditions, not from the worker's summary.**

- all conditions `met`, deliverables in git → the worker's `pass` / `pass-with-findings` is
  confirmed and recorded.
- any condition `unverified` or `cannot-run` → the recorded verdict is **`unverified`**, with the
  per-condition reasons stored (the worker's pass is overridden; the reason is the conditions, not
  the worker's word).
- any condition `failed` (exit non-zero) → the close is **refused**, naming the condition and its
  exit status. This is the narrow-A carve-out: a *verified negative* is not "cannot verify", it is
  "the work demonstrably failed its own bar", and recording `pass` over it is the exact self-grade
  this sprint exists to end. The worker's honest paths are: fix and re-close, or close `blocked` /
  `abandoned` with a concern naming the failing condition (§2.6). The refusal is not stranding —
  it is loud, it names the condition, and the two failure verdicts are always available to record
  an honest outcome.

*Decided, not deferred:* there is no seventh `fail` verdict. "My work does not meet its own bar"
is already covered by `blocked` (precondition/tooling) and `abandoned` (gave up), both of which
must carry a concern — a structured reason is what a verified failure needs, not a new enum value
the bundle did not ask for.

**S10-CLOSE-3 — one door.** `lanes --backfill` (which reimplements the close today and minted 9
tasks with no model at the identical timestamp `2026-08-23T02:18:53`) must call the same gated
close rather than reimplementing it. Where the gate demands something the backfill cannot supply,
the backfill supplies the explicit escape (`--model-unknown <reason>`, reason
"recovered by lanes --backfill from <findings path>") — never a silent null. One door for closing
a task, the same door for every caller.

### 2.2 A distinct, propagated outcome class

**S10-VERDICT-1 — `unverified` is first-class and never assertable.** It joins the valid-verdict
enum (`src/managent/main.zig:202`), but `managent done --status unverified` is **refused** — the
harness emits it, the worker does not claim it. The only way a row reads `unverified` is a
computed close (§2.1) that found a condition it could not check.

**S10-VERDICT-2 — propagated and countable.** `unverified` renders distinctly in `status`, `show`,
`resume`, `audit`, and the dashboard — never lumped with `pass`. The query "how much of our done
is unverified" is one count: rows where `verdict == "unverified"`. The per-condition detail (which
condition, why) is stored on the row so the aggregate does not hide the reason.

**S10-VERDICT-3 — the model-profiles mapping lands in the same change, atomically (concern 1).**
`tools/model-profiles.py` grades `verdict` → correctness (`pass=2`, `pass-with-findings=1`,
`fail-found=1`, `blocked=0`, `abandoned=0`, `model-profiles.py:253-259`). `unverified` must not
corrupt that: it is **not a model-quality datum** (it says nothing about the model's work, only
that the acceptance could not be checked), so it is **excluded from the correctness grade** — the
same present-and-labeled treatment the T629 census gives harness-killed rows (Ruling 32) — and
counted in a separate `unverified` column. A close that emits `unverified` must never surface as a
clean quality pass, and must never throw an unknown-verdict error in a scorer. The mapping change
and the verdict change are one commit, or neither lands.

**S10-VERDICT-4 — the 92%-pass baseline is redefined with a dated epoch note, never silently
(concern 2).** The pass-rate comparison breaks the moment `unverified` splits the pass bucket. The
same discipline the model epoch rules already impose (T525, `model-profiles.py:102-118`): record a
dated epoch boundary, state the before/after of the `pass`-rate definition, and stop comparing
across it. Post-S10 "pass" means "computed pass", and any pre-S10 number quoted beside it is
labelled as a different epoch.

### 2.3 Kill and attempt history on the task (absorbs T798)

**S10-ATTEMPT-1 — per-attempt history on the row, append-only.** Each attempt records at least:
attempt number, model, start, wall, exit, and `killed_by` — the T629 enumerated vocabulary
(`KILLED_BY_VALUES` = `none, provider-limit, provider-auth, provider-connection, directive, wall,
cpu, rss, liveness, watchdog, harness-error`; `tools/dispatch_verify.py:793`). Do not invent a
second vocabulary. Attempt history is append-only, like the amendment list.

**S10-ATTEMPT-2 — the close is honest about a kill, without refusing or downgrading.** `managent
done` on a task with any killed attempt states the kill in the record — print it, store it, let
the verdict stand. A harness kill is a fleet-reliability datum, never a quality datum, and the
work may well have landed (all 19 audited kill-over-pass cases had a deliverable on disk).

**S10-ATTEMPT-3 — an empty verdict note over a killed attempt is refused.** T616 and T638 are the
worked examples (and T530 the sharpest: three kills, then pass, read as first-try). A pass over a
kill needs one sentence saying why it stands.

**S10-ATTEMPT-4 — a derived count on the surfaces.** `managent status`/`resume` show
attempts-and-kills for a task, so a reader sees "passed on attempt 3" without opening a gitignored
directory. A task whose run records are gone renders **UNKNOWN, never zero**.

**S10-ATTEMPT-5 — backfill what is recoverable, labelled as backfill.** The 32 reconstructible
tasks from `untracked/runs/` are written in with a provenance marker (the store already makes the
recovered-vs-first-hand distinction); tasks whose run records are gone stay UNKNOWN — never zero
kills. Backfill is idempotent.

### 2.4 Store-loss detection (the highest-severity item)

**S10-STORE-1 — a committed census, maintained on every store write.** A tracked file (proposed:
`docs/infra/managent/store-census.json`) records, updated atomically with every `managent`
mutation of `tasks.json`: the live row count, a digest of the store content, and the command that
wrote it. The census rides the same docs wave as the store, so a `git checkout` of a wave gets a
consistent pair.

**S10-STORE-2 — write-time check: an unexplained shrink refuses and alarms.** Every mutating
`managent` command re-reads the store, recomputes count+digest, and compares against the census
*before* its own write. If the live store is smaller than the census and the difference is not
explained by this write's own retirement bookkeeping (§2.4, S10-STORE-4), the write is **refused**
(fail-closed — committing on top of a reverted store makes the loss harder to reconstruct, which
is exactly what made the T771 repair painful), and it alarms loudly, naming the count, the missing
ids it can identify, and the census path. An explicit escape (`reconcile-store-loss <reason>`
or the `--force`-with-reason pattern) records the shrinkage by fiat rather than silently
accepting it — the reasoned-bypass discipline, never a silent skip.

**S10-STORE-3 — read-time check: the read-only surfaces alarm too.** `orient`, `status`, `resume`,
and `audit` also verify count-vs-census on read, and alarm on stderr when the live store is
smaller than the census. The 59-task loss was discovered only because a running worker logged
`FAIL kanban: task T836 not found` — a read-time check makes it the very next `orient`, not the
next lucky error.

**S10-STORE-4 — retirement bookkeeping, so a legitimate shrink is not a false alarm.** `purge` and
`archive` record the ids they retire, and the census updates to match. A shrink with a retirement
record naming those ids is explained (no alarm); a shrink without one is the alarm. Without this,
the detector's own false positives would teach the bypass that ends it — the same failure mode
§1.4 names for every soft gate.

*Known limitation, stated honestly:* a wholesale `git checkout` of an old commit reverts the
store and the census together, and the pair is internally consistent — the census cannot see it.
That is a deliberate full-repo rollback, visible in git history, and distinct from the silent
single-file revert that lost the 59 tasks (where the working tree's `tasks.json` was reverted but
the census would not have been). The detector catches the silent single-file revert — the measured
failure — and does not claim to catch a deliberate repo-wide rollback.

### 2.5 Store-loss note on T716

T716 named "an ID can never again exist without a row" and fixed the *unregistered-lanes* class
(mint atomic with dispatch). It did **not** fix the *registered-then-lost* class — the store
itself silently shrinking — which is this spec's capability 4. The two are adjacent but distinct:
T716 closes the gap between findings and rows; S10-STORE closes the gap between the store and its
own committed history. Named here so the two are not conflated, and so T716's "not fixed" half is
explicitly carried, not lost.

### 2.6 The concern channel — wired, not re-invented (concern 6, resolved by inspection)

The bundle asked: establish whether either existing mechanism is implemented before specifying a
third. The answer, verified this session:

- **`docs/infra/concern-channel-spec.md` (T490, 2026-08-19) is a specification, not an
  implementation.** `managent concern` has **zero** occurrences in `src/managent/main.zig`;
  `docs/infra/managent/concerns.jsonl` does not exist; none of its §10's seven implementation
  tasks was ever registered. It is exactly the right mechanism — a structured verb for a worker
  that cannot close cleanly, mandatory on `blocked`/`abandoned`, with a disposition read side —
  and it is unimplemented.
- **`docs/infra/assertion-ledger/` is retired** (its own README, 2026-08-19). `managent assert`
  survives only as a thin status-correction power tool, not a concern channel. It is not a surface
  to resurrect.

**S10-CONCERN-1 — wire T490's concern channel; do not specify a third mechanism.** The failure
half of the close contract *is* the concern channel: a `blocked`/`abandoned` close requires a
recorded concern (presence checked, never disposition — no close ever waits on an answer, per
T490's founding constraint), and the concern's `found` first line becomes the `verdict_note` when
`--note` is absent. T490 §10's seven implementation tasks fold into S10's implementation pass as
their own rows, or are referenced as the task list they already are. The one amendment this spec
makes to T490: the concern channel and the computed close are two halves of one contract (§2.1's
verified-failed refusal routes to `blocked`+concern), so they land as one atomic change to the
close path — not two independent trains.

**S10-CONCERN-2 — no fourth kill-record surface.** There are four surfaces today (run records
`untracked/runs/`, runner logs, `untracked/tokens/tokens.jsonl`, and `docs/infra/dispatch-heals.jsonl`,
which holds zero). The task row's attempt history (§2.3) becomes **the** tracked surface; the
gitignored ones remain as raw provenance, never as the place a verdict reader must look.
`dispatch-heals.jsonl` is either folded into the attempt history or declared read-only — not
maintained as a fifth, emptier sibling.

## 3. Concerns, side-effects and gaps — each resolved, none parked

| # | concern (surfaced against the decision) | resolution (this spec) |
|---|---|---|
| 1 | `tools/model-profiles.py` grades on verdict values; a new class corrupts model-quality data unless its mapping lands in the same change | S10-VERDICT-3 — `unverified` excluded from the correctness grade, counted in its own column, one atomic commit |
| 2 | the 92%-pass baseline becomes non-comparable | S10-VERDICT-4 — dated epoch note, same discipline as the model epoch rules (T525) |
| 3 | 67% have no acceptance → all `unverified` overnight, class useless | S10-ACCEPT-2 — 383 grandfathered with a published count; dispatch gate (T816) stops the set growing |
| 4 | the bulk path must obey the same contract | S10-CLOSE-3 — `lanes --backfill` calls the same gated close; one door |
| 5 | workers write trivial conditions to earn a clean pass | S10-ACCEPT-1 — acceptance is authored by the specifier before dispatch, never by the worker at close |
| 6 | a concern channel exists on paper; don't add a third mechanism or a fourth kill surface | §2.6 — T490's channel is wired (not implemented today), the assertion ledger stays retired, the task row is the one tracked kill surface |

## 4. Acceptance tests — one arm per normative id, stated armed count

Every arm is a seeded-or-null control on a scratch store (`MANAGENT_STORE`), the T427 isolation
rule, shown red before its green is believed. Every arm names the real incident it would have
caught. The armed count equals the id count — an id with no control is a wish, and the S06 audit's
16-of-31 unarmed is exactly the debt this table exists to prevent.

| id | arm | setup | must (red-then-green) | would have caught |
|---|---|---|---|---|
| S10-ACCEPT-1 | A1 | `done` with `--acceptance "true"` on a task whose bundle has its own acceptance | **refused** — acceptance comes from the bundle only; store unmutated. Null: bundle acceptance read and run correctly | concern 5 — a worker grading its own bar |
| S10-ACCEPT-2 | A2 | dispatch a bundle with no acceptance and no skip reason | **refused**; with `--skip-acceptance <reason>` → allowed and recorded. Null: a grandfathered task still closes under the old rule | the 383-with-nothing-to-check gap (67% of all tasks) |
| S10-ACCEPT-3 | A3 | an existing single-command `acceptance=` task closes | the command runs, exit recorded, one-condition list | silent breakage of the 123 tasks on upgrade |
| S10-CLOSE-1 | A4 | task with `[command: exit 0, uncheckable: "reason X"]` | command `met`; uncheckable recorded `unverified` with reason X; verdict `unverified` | a worker asserting "acceptance met" for a command never run |
| S10-CLOSE-2 | A5 | a `command` condition exits non-zero | close **refused**, names the condition + exit; then the same task closes `blocked` with a concern → allowed. Null: all `met` → pass confirmed | the self-graded pass (work that failed its own bar reading as pass) |
| S10-CLOSE-3 | A6 | fixture orphan-findings: model present → backfilled row carries it; model absent → carries explicit `--model-unknown` reason, never null | both directions | the 9 lost models (T674–T693, identical timestamp) |
| S10-VERDICT-1 | A7 | `done --status unverified` | **refused** — not assertable. Null: a computed close with an uncheckable condition records `unverified` | the worker re-asserting its own verdict (decision D's point) |
| S10-VERDICT-2 | A8 | `status`/`audit` on a mixed store | `unverified` rendered distinctly, not lumped with pass; one count returns the unverified-total | the 92%-pass surface hiding unverifiable work |
| S10-VERDICT-3 | A9 | a graded row with `verdict: unverified` | no correctness grade assigned, counted in the unverified column, no unknown-verdict error | concern 1 — a new class corrupting model-quality data |
| S10-VERDICT-4 | A10 | the epoch note exists | dated; states the pass-rate before/after; pre/post numbers never compared silently | concern 2 — a silently redefined baseline |
| S10-ATTEMPT-1 | A11 | fixture run record with a kill | attempt recorded with the T629 `killed_by` enum; a second attempt appends; backfill idempotent | the 1,476 kills living only in gitignored state |
| S10-ATTEMPT-2 | A12 | task with a killed attempt + a deliverable in git | close succeeds, verdict unchanged, kill stated in the record | T697/T661 "work committed; row never closed" |
| S10-ATTEMPT-3 | A13 | pass over a kill, empty note | **refused**; with a one-line note → allowed | T530/T616/T638 empty-note passes over kills |
| S10-ATTEMPT-4 | A14 | multi-attempt task | `status` shows "passed on attempt 3"; a task with no run records renders UNKNOWN, not zero | a three-kill-then-pass task reading as first-try |
| S10-ATTEMPT-5 | A15 | backfill the recoverable set | written with provenance marker; missing-record tasks stay UNKNOWN; idempotent | the "first census said 32" undercount (read only `untracked/runs/`) |
| S10-STORE-1 | A16 | any store mutation | census (count+digest) updates atomically with the write | the census going stale so detection cannot fire |
| S10-STORE-2 | A17 | store reverted to fewer rows, then attempt a write | **refused**, alarms, names count + missing ids + census. Null: a `purge` naming its retired ids → allowed, census updated | the 2026-08-24 59-task loss (refused at the next write) |
| S10-STORE-3 | A18 | reverted store, run `orient` | loud stderr alarm naming the gap; exit non-zero on a shrink | the 59-task loss surfacing only via "FAIL kanban: T836 not found" |
| S10-STORE-4 | A19 | `purge`/`archive` record the removed ids | shrink is explained (no alarm); a shrink with no retirement record alarms | a legitimate purge misread as loss (the false-positive that teaches bypass) |
| S10-CONCERN-1 | A20 | `managent concern` appends a record; `blocked` close with no concern → refused, with concern → allowed | both directions; presence checked, disposition never | the 124 write-only context dumps / reasonless blocked closes (T490's measured hole) |
| S10-CONCERN-2 | A21 | a kill in the run record | reflected on the task row (one tracked surface); `dispatch-heals.jsonl` folded in or declared read-only | "the one tracked kill ledger holds zero" (four surfaces, none authoritative) |

**Armed count: 21 of 21 normative ids carry ≥1 arm** (A1–A21). No id in §2 is left as prose.

## 5. Smoke tests — end-to-end, named separately from the unit arms

Each is a whole scenario against a fixture repo or scratch store — **never the live one** —
because every scenario below kills processes, mutates a store, or fakes a worker. The 2026-08-23
guard incident was caught by no unit arm and would have been caught by a smoke test; these four
are the same shape applied to this sprint's failure modes.

**SMOKE-1 — a worker produces nothing and claims success.** Dispatch a lane whose bundle names a
deliverable and an acceptance command; the worker reads nothing, writes nothing, and calls
`done --status pass`. **Assert:** the close is refused (deliverable absent) — and even if the
worker forges the deliverable path, the acceptance command fails or is `unverified`, so the row
can never read a clean `pass` without the harness having verified it. **Would have caught:** the
worker-grades-itself baseline (444 passes, 383 with nothing to check against) — the 92% figure
this sprint exists to make comparable.

**SMOKE-2 — a worker produces deliverables but cannot close (the T818 case).** A lane writes its
deliverable to git, then dies before echoing the close (nonce never echoed, process exits). 
**Assert:** the row does not read `in_progress` indistinguishable from a live worker — the
liveness/reap path marks it orphaned with its delivered work visible and healable, and the attempt
history records the death. **Would have caught:** T818 (complete-but-unclosed read as orphaned for
two hours) and the sixteen-tasks-read-as-in-flight-with-zero-alive confusion — the A-failure-mode
that motivated decision D.

**SMOKE-3 — a worker killed mid-flight after flushing its work.** A lane writes its deliverable,
then is SIGKILLed. **Assert:** the kill is on the task's attempt history with the T629 `killed_by`
enum; the deliverable is preserved; the subsequent close states the kill and (with a one-line
note) records the verdict unchanged — never a silent first-try pass. **Would have caught:**
T697/T661, T530 (three kills then pass), and the 1,476 invisible kills.

**SMOKE-4 — a store write that loses rows.** A store is reverted to a stale snapshot (fewer rows,
stale digest), then a `managent` mutation is attempted and `orient` is run. **Assert:** both the
write and the read alarm loudly, name the count and the census, and the write is refused until
reconciled with a reason. **Would have caught:** the 2026-08-24 59-task store loss, which today
surfaced only because a worker happened to log `FAIL kanban: task T836 not found`.

## 6. Arm ledger (S10-ARM-LEDGER)

| id prefix | capability | acceptance arms | smoke arms | total |
|---|---|---|---|---|
| `S10-ACCEPT-` | computed close — schema/gate/migration | 3 (A1–A3) | — | 3 |
| `S10-CLOSE-` | computed close — run/compute/one-door | 3 (A4–A6) | — | 3 |
| `S10-VERDICT-` | unverified class | 4 (A7–A10) | — | 4 |
| `S10-ATTEMPT-` | kill/attempt history | 5 (A11–A15) | — | 5 |
| `S10-STORE-` | store-loss detection | 4 (A16–A19) | — | 4 |
| `S10-CONCERN-` | concern channel | 2 (A20–A21) | — | 2 |
| `S10-SMOKE-` (cross-cutting) | end-to-end | — | 4 (SMOKE-1..4) | 4 |
| **total normative arms this spec defines** | | **21** | **4** | **25** |

Every id above carries ≥1 arm and names an incident it would have caught (§4) or is a smoke
scenario naming its incident (§5). The single-command→structured migration (S10-ACCEPT-3) is
counted separately from the dispatch gate (S10-ACCEPT-2) deliberately: the former is a
compatibility obligation, the latter is the close-the-set gate — conflating them would hide that
one can ship without the other.

## 7. Sequencing and dependencies

S10 is an umbrella spec; its implementation is the existing one-writer chain plus new rows. Order
argued, not asserted:

1. **T798 → T815 → T816** is the existing `src/managent/main.zig` one-writer chain already queued,
   and it carries capability 2.3 (attempt history), 2.1's dispatch gate, and the one-door rule.
   S10 does not fork it; it absorbs it (S10-ATTEMPT-*, S10-ACCEPT-2, S10-CLOSE-3 are the spec-side
   of exactly those rows).
2. **The computed close + `unverified` class** (S10-ACCEPT-1/3, S10-CLOSE-1/2, S10-VERDICT-*) is a
   single change to `cmdDone` + `model-profiles.py` + the epoch note — one atomic commit per
   concern 1, and it needs the T816 dispatch gate to land first (so the `unverified` class is not
   flooded by the ungated backlog).
3. **The concern channel** (S10-CONCERN-1) lands with or after the computed close, so the
   verified-failed refusal (§2.1) has its honest failure path (`blocked`+concern) in the same
   release — otherwise a refused close strands.
4. **Store-loss detection** (S10-STORE-*) is independent of the close path and can land in
   parallel; it holds `src/managent/main.zig` and joins the chain, but it does not block or wait on
   the verdict work.
5. **The concern channel and store-loss arms** extend the existing regression battery and wire
   into `zig build test`, per the standing tooling pipeline rule — every arm in §4 is shown red
   first, then green.

## 8. Bookend

**No genuine fork remains for the operator.** The direction was already ratified (D, emitting C),
the four capabilities were named by the bundle, and every open point this spec encountered was
decided on recorded doctrine rather than deferred: the verified-failed close refuses and routes to
`blocked`/`abandoned`+concern (no seventh `fail` verdict); `unverified` is a computed verdict
value, not an orthogonal flag; the store-loss detector fails closed with a reasoned escape; the
concern channel is wired rather than re-invented; and the 383 tasks are grandfathered with a
published count. The only genuinely operator-owned questions — spend and scope — are already
answered by the bundle itself ("write the spec; build nothing"). Pass 1 can start on this spec.
