# Duties — beneficial work that never completes

**Operator ruling, 2026-08-19.** A **task** has a done condition. A **duty** does not: it is work
that is always beneficial, never critical, and cannot exhaustively finish — playing random games
to falsify an engine, verifying claims one at a time, checking the fleet for orphans. Before
this page such work was either dressed as a task (and rotted when it never closed) or left
undefined (and never ran).

## What a duty is

| property | duty | task |
|---|---|---|
| done condition | none by construction | required |
| identifier | stable 5–6 char UID (`DCLAIM`) | `T<nnn>` |
| unit of work | one **chunk** per invocation | whole deliverable |
| priority | always yields to a task | scheduled |
| completion | a chunk passes; the duty continues | closes with a verdict |

UIDs share a column with task ids so one display serves both.

## The four duties — DCLAIM, DRPLAY and DARGUS registered 2026-08-19; DFLEET added with the fleet keeper (T496)

| UID | erodes toward | one chunk = |
|---|---|---|
| `DCLAIM` | `L4 (the ledger is clean)` | verify **one** prose-only `PROVEN` claim: re-run its probe, or record NO-SUCH-PROBE naming what a probe would need. 48 of 69 `PROVEN` claims have no re-runnable probe; this is the only thing that moves that number. |
| `DRPLAY` | `L2 (proven 4×4 values)` | play **one** random or deliberately suboptimal 4×4 game against the oracle and check the predicted value against the played result. Cannot prove the table; can falsify it. A single disagreement is a crisis finding. |
| `DARGUS` | `L1 (the dashboard tells the truth)` | run `bin/argus --mode doctor` once and act on exactly what it reports: orphaned claims, stale binaries, gauges disagreeing with a fresh measurement. |
| `DFLEET` | `L1 (the dashboard tells the truth)` | run **one** iteration of `tools/fleet-keeper.sh`: read `bin/managent status --json`, and if a slot is free and a task is eligible, fire `bin/dispatch <id> <model>`. The dispatch algorithm — eligibility, the `waiting`/`priority`/`added` ordering, and the logjam-pressure state machine (the cap drops by one per completing task while a blocked "next" task waits, so it runs solo once its holds free) — is `docs/infra/fleet-keeper-design.md` (T500, which supersedes the oldest-by-`added` rule). The fleet must never sit idle with dispatchable work; PROGRESS must never stay empty for more than ten seconds. Chunk findings (`findings/DFLEET-<date>.json`) record the iteration's outcome — fired / cooldown / cap / nothing-eligible / logjam. |

## Scheduling — by work completed, not by clock

A duty becomes **due after N tasks close** (default N=5, per duty). Clock scheduling would fire
while the fleet is idle and skip a burst of activity; duties exist to keep pace with change.

A due duty runs **when no task needs the machine**. It yields: any dispatched task preempts a
running duty chunk, and a duty never holds a file a task may want.

## Duties gate landmarks — this is the point of them

**A waypoint or landmark may not be declared reached while any duty is overdue or its last chunk
failed.** Same shape as tests green before a push: the claim of arrival is exactly when the
housekeeping must be current, because that claim is what everything downstream trusts.

A failing duty **blocks** rather than annotates. An advisory duty is ceremony, and this project
has ruled that prose is not a remedy for a mechanism failure.

### `DFLEET` is exempt from the landmark gate

A dispatcher that gates the landmark it serves is circular: `DFLEET` erodes toward `L1 (the
dashboard tells the truth)`, but `L1` is *exactly* "PROGRESS never sits empty with dispatchable
work present" — so `DFLEET` being overdue is the condition `L1` describes, not a violation of it.
A dead fleet should be visible in PROGRESS (the dashboard showing the idle fleet is the truth),
not a block on declaring `L1`. `DFLEET` therefore never blocks a landmark declaration; the other
duties (`DCLAIM`, `DRPLAY`, `DARGUS`) gate as stated above. The keeper is launched by the
Orchestrator (or the human), and its cooldown flag (`tools/fleet-cooldown.sh`) is the graceful
shutdown — the duty exists to keep the fleet full, not to gate the landmark that fleet-fullness
*is*.

## What a chunk's pass means

Since a duty cannot complete, a chunk passes when all three hold:

1. the chunk was actually performed (evidence recorded, not "nothing to do"),
2. its findings are committed — `findings/<UID>-<date>.json`,
3. no regression against the duty's own last reading.

"Nothing to do" is a **fail**, not a pass: it means the duty could not find work, and a duty that
cannot find work is either finished (impossible by construction) or broken.

## The duty verbs (live — T478)

`managent` ships the duty mechanism since T478: `managent duty <UID> done --verdict
pass|fail --findings <path>` records one chunk (a duty never closes), `managent add --duty`
registers a duty, `managent landmark <Ln> --declare` gates a landmark declaration on duty
currency (overdue or last-failed blocks), and `managent status` renders duties in their own
section. Due-ness is by closes, not clock: a duty becomes due `due_after` task closes
(default 5) after its last chunk. Duties are no longer dispatched by hand.

## Naming note

The third duty is `DARGUS`, not `DOCTOR`: T427's fixture-marker guard refuses any id containing
`DOCTOR` on the live store, because regression harnesses use that word in fixture ids. The guard
is right and was not weakened for a naming preference.

## Resolved: STANDING-CLAIMVERIFY is DCLAIM (T533, 2026-08-23)

`STANDING-CLAIMVERIFY` (proposed 2026-08-19 in `docs/status/backlog-2026-08-19.md`, carried into
`docs/status/ROADMAP-2026-08-20.md` §1.3 as "register STANDING-CLAIMVERIFY (proposed 2026-08-19,
never registered)") is the **same duty as `DCLAIM`**: identical erodes-toward
(`L4 (the ledger is clean)`), identical one-chunk unit (verify one prose-only `PROVEN` claim:
re-run its probe, or record NO-SUCH-PROBE naming what a probe would need), identical pass rule
(reproduced | NO-SUCH-PROBE; fresh claimlint 2026-08-23: C3 UNBACKED 48 of 69 `PROVEN` rows),
and identical deliverable (a findings entry citing the claim id and the run). DCLAIM's brief
already carries STANDING-CLAIMVERIFY's "no register edits without a separate ruling" as "change
no claim status". The only nominal difference is the `STANDING-*` prefix versus a duty UID —
precisely the dressing-as-a-task the duties mechanism (T478) exists to retire.

**Merged: one duty, not two.** DCLAIM stands registered (`duty: true`, `due_after: 5` — due 5
task closes after its last chunk) and cycling (`findings/DCLAIM-2026-08-20.json`,
`-2026-08-22.json`, `-2026-08-22-FP3.json`, `DCLAIM-chunk3.json` — GLOBAL.S1 REPRODUCED). No
second registration; the ROADMAP §1.3 item is satisfied by this merge. Chunk-pass definition
for the merged duty: "What a chunk's pass means" above.
