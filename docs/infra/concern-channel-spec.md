# Concern channel — the outbound half of the worker channel

**Task:** T490 · **Author:** Fable seat (claude-fable-5) · **Date:** 2026-08-19
**Landmark:** `L4 (the ledger is clean)`, completing the absorption program (T481)
**Status:** SPECIFICATION — for operator and Orchestrator review. This document
implements nothing. Its implementation tasks are listed in §10.

## 0. The answer in one paragraph

A worker that cannot close cleanly — findings rejected, register contradicting it,
machinery refusing, brief unsatisfiable — gets one structured verb: `managent concern`,
appending a machine-readable **concern record** (severity, what was found, evidence,
suggestion, related rows) to a tracked ledger, `docs/infra/managent/concerns.jsonl`,
the mirror-image sibling of the inbound `directives.jsonl`. Writing is always one
command and always succeeds; it is **mandatory on `blocked`/`abandoned` closes**
(replacing the free-text `--note` those verdicts already require) and optional
everywhere else. **No close ever waits on a concern being answered.** The read side is
a standing trigger: `managent` joins the ledger against row status, and any
un-dispositioned concern of a **closed** task past a deadline — or any `crisis`
concern at all — registers `STANDING-CONCERNS` as dispatchable seat work; the seat
dispositions each concern **accepted** (names the task that will carry it),
**rejected** (reason mandatory), or **absorbed** (names where it already landed).
The ledger lives outside `findings/`, so claimlint's C7 census structurally cannot
count a concern as an unabsorbed proposal — placement, not an exemption rule.

## 1. The measured hole

The operator and Orchestrator settled the requirement on 2026-08-19 after measuring
the failure (`untracked/T490-concern-channel-spec.md:10`): 8 wall-kills with no
output, 5 orphans the operator noticed before any instrument
(T448/T450/T452/T466/T475, `tools/dispatch_verify.py:242-244`), two `blocked` closes
carrying no reason, and 124 context dumps nothing reads. Gate by gate, what exists
today:

- **The note requirement exists and leaks.** `managent done` already refuses a
  non-`pass` verdict without `--note` (`src/managent/main.zig:2403-2406`) — but the
  `--fail` backward-compat path fabricates the note first
  (`src/managent/main.zig:2398-2402`), which is exactly how T387 closed `blocked`
  with `verdict_note: "--fail (no note provided)"`
  (`docs/infra/managent/tasks.json:2960,2976`). And a note, when present, is free
  text in one field: nothing can triage it by severity, route it, or verify it was
  ever answered.
- **The dead never speak; observers speak for them.** T379's `verdict_note` is a
  post-mortem written by whoever found the corpse — "console died with no work in
  tree… The operator noticed before any instrument did"
  (`docs/infra/managent/tasks.json:4294,4310`). The worker's own account is
  permanently gone: the T440 lesson, extract while the accountable party is alive
  (`docs/infra/absorption-spec.md:98-109`).
- **The context dump is write-only.** Every console is asked to write
  `findings/<task-id>-context.json` before it dies
  (`docs/infra/delegation/DELEGATEE.md:236-261`; the `kill` directive requires it,
  `DELEGATEE.md:91`; the delegator asks for it by exact path, `DELEGATOR.md:38`).
  124 such dumps exist today (`ls findings/*-context.json | wc -l`). Their payload
  key is `notes` — and `src/claimlint.zig` never reads a `notes` key at all (zero
  occurrences); claimlint sees dumps only as findings files whose `claims[]` must
  stay empty to avoid double-counting (`DELEGATEE.md:247-254`;
  `docs/infra/dispatch/STANDING-ABSORB.md:25-28` treats them as noise to
  disposition). The only machine that touches the payload channel counts it as
  pollution. Nothing routes it anywhere.
- **The worker channel is inbound-only.** `tell`/`inbox`/`ping` carry court→worker
  control (`docs/infra/agent-identity-and-worker-channel.md:117-125`;
  `src/managent/main.zig:6781`). A worker *can* post a `question` directive back,
  but `--from` defaults to `"unknown"` unvalidated (`main.zig:6793`), the record is
  read-once (ack clears it, `main.zig:6900-6907`), it carries no severity and no
  disposition, and no court seat has an inbox-reading obligation — a concern sent
  that way has exactly the readership the 124 dumps have.
- **T481 left the door open on purpose.** The absorption spec exempts
  `blocked`/`abandoned` closes from the coherence gate
  (`docs/infra/absorption-spec.md:58`, §9 at `:265-286`), same as the deliverable
  check (`src/managent/main.zig:2480`) and dispatch verification
  (`tools/dispatch_verify.py:208-215`). Right exemption — a worker reporting "I
  could not do this" must not be gated on paperwork about work that did not happen —
  but the exempted payload currently has nowhere structured to go. This spec is that
  room.

## 2. The record — schema and home

**Home: `docs/infra/managent/concerns.jsonl`** — tracked, append-only JSON-Lines,
written only by `managent` (flock + counter, same discipline as `directives.jsonl`,
`src/managent/main.zig:6795-6820`). It rides docs waves with the kanban store; no
worker ever authors or commits the file directly, so a dying console's concern costs
one command, not a file-plus-commit at the worst possible moment.

Two record kinds share the file; later records supersede or answer earlier ones —
append-only, "who asserts what when":

```json
{"kind":"concern","id":"CN001","task":"T379","from":"deepseek-v4-flash",
 "ts":"2026-08-19T18:00:00Z","severity":"gap",
 "found":"brief requires the old engine's kifu writer; it was deleted in <sha>",
 "evidence":"src/old_engine.zig:1 (deleted, see git log)","suggest":"re-scope to new engine or resurrect as fixture",
 "related":["T361"]}

{"kind":"disposition","concern":"CN001","as":"accepted","by":"claude-opus-5",
 "ts":"2026-08-20T09:00:00Z","task":"T495","reason":null}
```

Fields, concern record: `id` (minted `CN<nnn>`, counter in `_sys` like `D<nnn>`,
`src/managent/main.zig:6799`); `task` (must resolve against `tasks.json` **or**
`archive.json` — concerns about archived rows are legal); `from` (validated against
the canonical model list at point of write, the `cmdDone --agent` pattern,
`src/managent/main.zig:2367-2376`, plus the two non-model writers `dispatcher` and
`operator`); `severity` ∈ `crisis` (stop-the-line: live-tree damage, register
corruption, a wrong PROVEN) | `defect` (something is concretely wrong: code, doc,
register, brief) | `gap` (the brief is unsatisfiable as written: missing
information, tooling, or precondition — the T387 class) | `suggestion`
(improvement, no defect); `found` (required, the payload); `evidence` (path or
`file:line`, optional but the refusal text asks for it); `suggest` (optional);
`related` (optional task/claim ids). Text fields capped at 4 KiB like `--note`
(`src/managent/main.zig:1554`), newline-escaped like every JSONL writer
(`src/managent/main.zig:7076`).

Disposition record: `concern` (the CN id); `as` ∈ `accepted` (a `task` id is
mandatory — register the row first, then disposition, so acceptance can never point
into a void) | `rejected` (`reason` mandatory — symmetric with
`findings/rejections.json`'s reason-bearing dispositions,
`docs/infra/absorption-spec.md:34-37`; "duplicate" is a rejection whose reason names
the earlier CN) | `absorbed` (a `task` id names where the substance already landed);
`by`; `ts`. A disposition is itself an assertion; a later disposition supersedes an
earlier one, nothing is ever edited in place.

**How claimlint's C7 treats concerns: it never sees them.** The ledger is outside
`findings/`, which is C7's entire scan surface, so a concern **cannot** be counted
as an unabsorbed proposal — the T290/T468 double-count class is excluded by
placement, not by an exemption rule inside claimlint. The alternative (a `concerns[]`
key in findings files that C7 must skip) adds a negative rule to the exact scraper
ecology that has already silently broken twice (`docs/infra/absorption-spec.md`
§7; the T356 marker rename, `src/managent/main.zig:6330-6336`), and the context-dump
precedent proves convention-based exemption fails in practice — the 2026-08-03
C7=21 reading was 11 phantom dump entries (`src/managent/main.zig:6236-6237`).
Visibility for the read side needs no claimlint change either: `managent` reads its
own ledger and joins against row status it already owns, the same
kanban-stays-out-of-claimlint split the closed partition uses
(`docs/infra/absorption-spec.md:248-251`).

**Relation to context dumps:** unchanged and complementary. The dump stays the bulk
narrative asked at kill (`DELEGATEE.md:236-261`); a concern is the indexed,
routed, answer-guaranteed extract, and its `evidence` field may cite the dump. The
124 existing dumps get the epitaph treatment, not a retro-triage
(`docs/infra/absorption-spec.md:339-345` precedent): their two known live payloads
already resolved elsewhere (T379 re-registered as T389 and delivered; T387's brief
stands in the backlog), and reconstruction of the rest is T440-class archaeology
that costs more than it returns. The operator may commission one bounded sweep as a
separate ruling; this spec does not.

## 3. The write side

**Who writes:** primarily the worker holding the task; also the dispatcher (§ heal,
below), the seat, or the operator — any party with a canonical identity. Writing
never consults row status: a concern about an open, closed, or archived task is
legal at any time. Late realization is a feature, not a violation.

**The verb:**

```
managent concern <task-id> --severity <crisis|defect|gap|suggestion>
                 --found <text> [--evidence <path|file:line>]
                 [--suggest <text>] [--related <ids>] [--from <who>]
```

**When it is mandatory — `blocked` and `abandoned` closes.** `cmdDone` refuses those
verdicts unless at least one concern record for the closing task exists. This lands
adjacent to the `--note` check it strengthens (`src/managent/main.zig:2398-2407`),
before the phase-1 write, so a refused close mutates nothing (the T350 two-phase
discipline). In the same change the `--fail` auto-note
(`src/managent/main.zig:2400-2402`) is retired: `--fail` keeps mapping to `blocked`
but no longer fabricates a reason — the T387 "no note" class dies at its source.
For continuity of every status display, when `--note` is absent on these verdicts,
`managent` copies the concern's `found` first line into `verdict_note`.

To keep the mandatory path at one command for a dying console, `done` accepts the
concern inline as sugar: `managent done T### --status blocked --severity gap
--found "..." [--evidence ...]` appends the record and then closes. The presence
check covers workers who wrote their concern earlier in the session.

`pass`, `pass-with-findings`, and `fail-found` closes: concern **optional**, always
available, never checked. (`fail-found` is a *successful* falsification with full
deliverables — `tools/dispatch_verify.py:208-210` — its channel for register-visible
content is the findings file; a concern is for what the findings schema cannot say.)

**The refusal text teaches.** Two placements:

1. The `blocked`/`abandoned` refusal in `cmdDone` prints a copy-pasteable, prefilled
   command:

   ```
   REJECTED: verdict 'blocked' requires a recorded concern — the reason you could
   not proceed, structured so it gets answered instead of archived.
     managent concern T487 --severity gap --found "<what stopped you>" --evidence "<file:line or path>"
   Then re-run this done. Your concern cannot block your close and is guaranteed
   a disposition (accepted / rejected-with-reason / absorbed).
   ```

   The guarantee sentence is load-bearing: a worker who believes the channel is
   write-only will route around it, and 124 dumps prove workers learn that fast.

2. Every existing refusal a stuck worker can hit — the deliverable gate
   (`src/managent/main.zig:2513-2521`), the acceptance failure, the T485 absorption
   refusal when it lands — gains one trailing line: `If you cannot satisfy this,
   record why: managent concern <id> --severity gap --found "..."`. One line, no
   protocol essay; the principle is the worker-channel one — attach the read (here,
   the teaching) to the tool the worker cannot avoid
   (`docs/infra/agent-identity-and-worker-channel.md:94-110`).

**The failure-path payload — the T477 heal carries the concern forward.** When
`heal_dispatch` reopens a row it watched die (`tools/dispatch_verify.py:235-310`),
it additionally appends a concern on the dead worker's behalf:
`--from dispatcher --severity defect --found "worker <model> died rc=<n> after
<s>s; row reopened by dispatcher; context dump findings/<task>-context.json
<present|absent>"`. Best-effort and loud on failure, never failing the heal — the
same posture as the perf ledger (`tools/dispatch_verify.py:313-337`). The forward
carry into the next brief is mechanical, not editorial: **`managent claim` prints
the claimed task's un-dispositioned concerns**, exactly where it already prints
pending directives (`src/managent/main.zig:1841,7239-7260`) — the re-claiming
worker cannot start without seeing how its predecessor died and what it flagged.
This is the T440 extraction rule applied to death: what the accountable party knew
is captured at the moment the process that knows it is still running.

## 4. The read side — the mechanism, not a hope

**The join.** `managent` computes, from `concerns.jsonl` × `tasks.json` ×
`archive.json` (archived rows included, same join the closed partition makes,
`docs/infra/absorption-spec.md:248-251`):

- **open partition** — un-dispositioned concerns of open tasks: informational, any
  count healthy, no alarm. The owning task is alive; its close or its worker will
  carry them.
- **closed partition** — un-dispositioned concerns of `done`/`failed`/archived
  tasks: these are the channel's whole reason to exist, and each has a deadline.

**The trigger.** A sixth standing template, `STANDING-CONCERNS`
(`src/managent/main.zig:6245-6251` gets one row; brief at
`docs/infra/dispatch/STANDING-CONCERNS.md`), registered by `managent standing` when
either holds:

- any `crisis` concern is un-dispositioned — fires immediately, regardless of the
  owning task's status (a crisis does not wait for a close, and certainly not for a
  deadline);
- any closed-partition concern has aged past the deadline: **5 task closes** since
  its task closed (or since the concern was written, whichever is later). Paced by
  closes, not the clock, for the duty-scheduling reason — clock triggers fire on an
  idle fleet and sleep through a burst (`docs/infra/duties.md:30-32`); 5 matches
  the duty default and the session-sized-job calibration
  (`src/managent/main.zig:6239-6240`). `managent` counts closes natively; no scraper.

The trigger must land after (or carry) T486's re-fire fix — a standing row that is
`done`/`failed` re-registers — or it inherits the defect that killed STANDING-ABSORB
(`docs/infra/orcha-doctor-2026-08-08.md:44`; fix ruled at
`docs/infra/absorption-spec.md:252-254`).

**The disposition verb and the accountable party.**

```
managent disposition <CN-id> --as accepted --task <T-id>
managent disposition <CN-id> --as rejected --reason <text>
managent disposition <CN-id> --as absorbed --task <T-id>
```

The **Orchestrator seat** is accountable: it is the party that runs `standing`, owns
task registration (an `accepted` disposition *is* "register a row and name it"), and
holds the cross-register authority a worker lacks. Note the deliberate asymmetry
with T481: absorption is the **closer's** job because the proposal's context dies
with the console; a concern's *record* preserves its context by construction, so its
disposition tolerates latency — which is exactly why the close never needs to wait
for it. Absorb-or-reject-with-reason is the same shape in both mechanisms; only the
clock and the owner differ, each matched to where the context lives.

**Surfacing:** `managent audit` gains the closed-partition table (CN id, task,
severity, `from`, age in closes); `bin/argus --mode doctor` gains a read-only
report line for the same numbers (dashboard truth, `L1` — DARGUS then covers it,
`docs/infra/duties.md:27`), but the standing row is the single actor; the doctor
line is visibility, never a second owner.

**Teeth without a close-block.** An alarm nobody must answer is ceremony. The
deadline binds at the same place duties bind: **a waypoint or landmark may not be
declared while a `crisis` concern is un-dispositioned or the closed-partition
deadline is breached** — the identical gate shape already ruled for overdue duties
(`docs/infra/duties.md:37-44`). Claims of arrival wait; workers' closes never do.

## 5. Composition with T481 — precisely

The two gates in `cmdDone` partition the verdict space; no verdict is double-gated
and neither gate ever reads dispositions:

| verdict | absorption gate (T481 §4 / T485) | concern gate (this spec) |
|---|---|---|
| `pass`, `pass-with-findings`, `fail-found` | required — findings conforming and absorbed | optional, never checked |
| `blocked`, `abandoned` | exempt (`docs/infra/absorption-spec.md:265-271`) | required — ≥ 1 concern record |

Ordering inside `cmdDone`: the concern presence check sits with the verdict/note
validation (`src/managent/main.zig:2398-2407`), i.e. before locks and mutation; the
absorption gate sits after the deliverable check per T481 §4. Both refuse
pre-mutation. The composition closes T481's open door: §9's exemption no longer
opens onto an empty room — the exempted verdicts are exactly the ones this channel
makes mandatory, so **every** close now either proves coherence (success paths) or
records why it cannot (failure paths). And in the other direction, T481's promise
is preserved verbatim: closing is never blocked by an *unanswered* concern —
presence is checked, disposition never is. The gate cannot recreate the hang it
exists to prevent.

Sequencing with the absorption implementation train (T482–T489, T491): independent
in logic (disjoint verdict sets), shared in surface (`cmdDone`, standing templates,
the drained-fleet single-deployment constraint,
`docs/infra/absorption-spec.md:326-329`). Land the concern gate with or after T485,
and STANDING-CONCERNS with or after T486.

## 6. What must NOT be gated

- **Any close, on an un-dispositioned concern.** Never, any verdict. (Brief
  property 2; the mechanism's founding constraint.)
- **Success-path closes, on having concerns at all.** Optional means optional; a
  worker with nothing to flag owes nothing.
- **Concern content.** No quality gate, no dedup gate, no minimum-evidence gate at
  write time — schema validity, a resolvable task id, and a canonical `from` only.
  A junk concern costs the seat one `rejected` disposition with a reason; a quality
  gate at write time teaches workers that silence is the cheap path, which is the
  disease this channel treats. (Same reasoning that keeps rejection-with-reason
  first-class in absorption, `docs/infra/absorption-spec.md:274-277`.)
- **Other tasks' closes.** The concern gate is scoped to the closing task; one
  console's flagged crisis must not wedge the fleet's closes. The *landmark* gate
  (§4) is global on purpose — arrival claims are where global coherence is owed.
- **Writing, ever** — including after close, about archived rows, by any validated
  identity. Late knowledge is knowledge.
- **Commits.** Nothing new at pre-commit; the ledger is managent-written and rides
  docs waves like `tasks.json`. The operator's unlabelled-commit path is untouched.
- **The heal.** A failed concern-append warns loudly and the heal stands
  (`tools/dispatch_verify.py` posture at `:313-337`); reopening the row is the
  safety-critical half.
- **Duty chunks.** Duty findings (`findings/<UID>-<date>.json`,
  `docs/infra/duties.md:51`) stay out of scope, as in the absorption spec's §9; a
  duty chunk that hits a wall may of course *write* a concern against any task.

## 7. Controls

Every arm on a scratch store (`MANAGENT_STORE`) with a `WEIZIGO_CONCERNS` path
override (the `WEIZIGO_DISPATCH_HEALS` precedent, `tools/dispatch_verify.py:236,294`),
per the T427 isolation rules. Home: new `tools/regression-concern-channel.sh`, wired
into `zig build test`; the heal arm extends
`tools/regression-dispatch-verification.sh`, which already owns the die-stub
(T477 arm 5). Every seeded arm is shown red before its green is believed.

| arm | setup | must |
|---|---|---|
| seeded 1 | `done --status blocked`, no concern for the task | refused; refusal contains the copy-pasteable `managent concern` line; store unmutated |
| seeded 2 | `done --status abandoned`, no concern; also legacy `--fail` | refused both ways (the auto-note hole is proven shut) |
| seeded 3 | `crisis` concern on an **open** task, un-dispositioned | next `managent standing` registers STANDING-CONCERNS naming the CN id |
| seeded 4 | concern on a task, task closes, 5 fixture closes follow | deadline fires; `managent audit` lists the CN with age 5 |
| seeded 5 | die-stub worker (rc≠0, row `in_progress`) | heal reopens **and** appends the dispatcher concern; a subsequent `managent claim` of the row prints it |
| null 1 | `done --status pass`, no concern | passes; no trigger |
| null 2 | `blocked` close **with** a concern present | passes — the gate reads presence, never disposition |
| null 3 | concern dispositioned `rejected` with reason before the deadline | trigger stays quiet (rejection is a full answer) |
| null 4 | open task carries 3 `gap` concerns across many closes | no fire (partition control) |
| null 5 | `bin/weizigo-claimlint` run before and after 10 concern appends | byte-identical summary — the no-double-count control, C7 blind to the ledger by construction |

## 8. Cost, stated for the record

- **Schema change:** one new tracked JSONL plus a `_sys` counter; the kanban row
  schema is untouched (concerns are joined by task id, never stored on the row —
  "keep it derived; a stored duplicate would drift",
  `docs/infra/agent-identity-and-worker-channel.md:51-55`).
- **Close-path ceremony:** on `blocked`/`abandoned`, one structured record replaces
  the free-text `--note` those verdicts already require — net new typing is a
  `--severity` flag and, honestly, better prose; the one-command sugar on `done`
  keeps the dying-console path flat. Success-path closes: zero added cost.
- **The standing trigger** is real recurring seat work — deliberately: five
  dispositions per firing is a minutes-scale chunk, and it is the read that 124
  write-only dumps never had. Weigh it against two reasonless `blocked` rows, five
  operator-noticed orphans, and eight silent wall-kills in the measurement window.
- **Named risk, no mechanical fix proposed:** severity inflation (everything filed
  `crisis`). Counter-pressure is the seat's `rejected`-with-reason disposition and
  the model-perf ledger making per-model concern quality visible; if inflation
  materializes, a calibration rule is a follow-up ruling, not pre-built ceremony.
- **Deployment:** rides the same drained-fleet, single-deployment constraint as the
  T478/T485 managent changes (`docs/infra/absorption-spec.md:326-329`).

## 9. Alternatives argued

- **Extend the findings schema with `concerns[]`** — rejected. It puts concerns on
  C7's scan surface and demands an exemption rule inside claimlint, joining a
  scraper ecology that has broken silently twice (§2); it collides with findings
  immutability (`findings/README.md:12-14` — a disposition is a post-hoc mark, so
  either the file mutates or a side registry appears anyway); and it makes the
  mandatory case a committed file authored by a blocked or dying worker — the exact
  paperwork-at-death T481 §9 and the deliverable exemption
  (`src/managent/main.zig:2480`) exist to avoid.
- **A sibling file `findings/<task>-concerns.json`** — rejected for the same scan
  and commit-at-death reasons, plus it manufactures more per-task files in the
  directory whose 124 unread files are the presenting symptom.
- **Reuse `tell`/`inbox` (a `question` directive to the seat)** — the closest
  existing machinery, and the ledger deliberately mirrors `directives.jsonl` so the
  channel's two halves stay symmetric. Rejected as the mechanism itself: a
  directive is read-once control (ack clears it, `src/managent/main.zig:6900-6907`)
  with an unvalidated `--from` (`:6793`), no severity, no disposition record, and no
  seat obligation to read — readership equal to the dumps'. A concern is
  answered-once with a durable audit trail; the lifecycles are different objects.
- **Auto-register a task per concern** — rejected. Registration is a seat decision;
  `accepted` *is* that decision, made at triage. Auto-rows flood the kanban with
  unratified work, and giving the write side registration authority would force a
  quality gate onto it — killing the writing-is-free property that makes workers
  use the channel at all.
- **Keep prose notes / discipline** — the status quo, measured: T387's mandatory
  note said nothing (`tasks.json:2976`), T379's was written by the coroner
  (`tasks.json:4310`), and the standing doctrine has already ruled that prose is
  not a remedy for a mechanism failure.

## 10. Implementation tasks (to register; none executed under T490)

| # | work | surface |
|---|---|---|
| 1 | `concerns.jsonl` + `CN` counter + `managent concern` verb (+ `WEIZIGO`-style path override) | `src/managent/main.zig` |
| 2 | done gate: `blocked`/`abandoned` presence check + inline sugar; retire the `--fail` auto-note; teaching refusal lines on cmdDone and the deliverable/acceptance refusals | `src/managent/main.zig` (cmdDone) |
| 3 | `managent disposition` verb; open/closed partition join (incl. `archive.json`); `managent audit` table | `src/managent/main.zig` |
| 4 | `STANDING-CONCERNS` template + brief + crisis/deadline trigger + landmark gate (after T486's re-fire fix) | `src/managent/main.zig`, `docs/infra/dispatch/STANDING-CONCERNS.md` |
| 5 | heal payload + claim-time concern print | `tools/dispatch_verify.py`, `src/managent/main.zig` (claim path) |
| 6 | controls (§7), red first | `tools/regression-concern-channel.sh`, `tools/regression-dispatch-verification.sh`, `build.zig` |
| 7 | prose in the same commits: DELEGATEE.md reporting section gains the verb; DELEGATOR.md kill checklist points dumps' live items at concerns; absorption-spec §9 cross-references the closed door | docs |
