# Orchestration refactor — SEED BRIEF (cannibalization strategy)

**Artifact type: SEED BRIEF.** Not a spec, not a plan, not a worker brief — the repo
uses those words with fixed meanings (`docs/infra/sprint.md`: a brief instructs one
worker; a spec says what we want, testably, for one sprint; a plan is the builder's
strategy for a pass). This document is *upstream* of all three: it frames the problem,
states the vision, and proposes the development pattern. It **seeds** sprints; it is
never itself a phase document and must not be cited as one. (T428 called the equivalent
artifact "01-strategy".) Named at the operator's prompting, 2026-08-20 — the seat had
called it a "roadmap", which was loose.

**Status:** PROPOSED by the Orchestrator seat, 2026-08-20. **Awaits the operator's
ratification** — he is the sprint owner and did not write this.
**Protocol for every pass:** `docs/infra/sprint.md` (spec → audit → scope/acceptance →
audit → plan → audit → test-red → build → test-green → audit → verify/smoke → audit →
absorb → lessons → perf stats → commit). No exceptions, per the operator's direction.

## The target, agreed 2026-08-20

Three programs instead of fourteen (~16,000 lines of orchestration measured across 14
programs in 3 languages):

1. **`managent`** — the store and all state. One database, one lock, one writer.
   *Improve, not rewrite* — 8,780 tested lines of Zig are the asset.
2. **One supervisor** — `managent supervise`: a single long-lived process that **holds**
   its children and never detaches. Replaces `fleet-keeper`, `dispatch`, `subagent`,
   `runner`, `dispatch_verify`, `fleet-cooldown`. *Rewrite from scratch.*
3. **Read-only views** — `managent status/resume/orient/fleet`. Absorbs
   `watch-fleet.sh`, `argus`, `orcha-acceptance`, `model-profiles`.

One binary, two modes: `supervise` is long-lived; every other verb stays a short-lived
CLI against the same store, lock and code.

## Why the supervisor is a rewrite and managent is not

The measured root cause of every 2026-08-20 failure is one design choice:
**ownership is inferred, not held.** `bin/dispatch:301` detaches
(`start_new_session=True`) and prints "dispatched"; everything downstream re-establishes
ownership by scanning `ps`, polling the kanban, and writing run records. Inference has
an unclosable window between spawn and observation — so orphans, duplicate dispatch,
misattribution and lost directives are *consequences of the design*, not bugs in it.

`tools/runner:1161` already does the right thing as far as one boundary allows —
`os.setsid()` on its child, `killpg()` at every exit. It still loses grandchildren,
because **`killpg` covers exactly one process group** and `zig build`'s descendants
create their own. macOS has no cgroups, so there is no kernel-level "kill everything
below this". That boundary cannot be patched; it has to be replaced by holding handles.

## How passes and phases actually work (operator, 2026-08-20)

A pass is **not** a fixed repeat of every phase. Each pass *potentially* contains all of
spec, research, design, scope, plan, implementation, verification — but in practice:

- the spec may be written once and **scope reduced** on each later pass;
- **research findings accumulate** across passes rather than being redone;
- scope may be **triaged forward**, and a verification failure in pass N becomes scope in
  pass N+1;
- scope may be **split in two**, and the second half skips spec/research/design entirely
  because they were already done.

So the ladder is a menu, not a treadmill. The plan for each pass states which phases it
runs and which it inherits.

## What the races are actually for

Not to crown a winner. **To build a skill matrix per model per phase**, so that work can
be routed and over-spending stopped. The operator's aim, recorded: *"I hope we'll find
strengths and weaknesses early and reduce the model participation in subsequent phases in
later passes. We may learn that some models are great at free-thinking and writing and
planning but not implementation and other models are the opposite. Or we may decide that
some models are overqualified for tasks that any model can handle equally and
sufficiently well."*

Two consequences:

1. **Participation shrinks as evidence accumulates.** Early phases run wide; later phases
   run only the lanes the matrix says are worth it.
2. **"Overqualified" is a measurable claim**, not an impression — quality delta against
   tokens spent. Token capture landed 2026-08-20 (`T521`), so cost per phase is now a
   real number for the first time.

## Consolidation: by aspect, not by winner

Corrected from the seat's earlier proposal, which was winner-takes-all with grafts. The
operator's mechanism:

> *"These races are not winner-takes-all. We are evaluating all models on skill
> dimensions. We are selecting aspects of documents and consolidating into the best one
> results. Yes, it's by committee, but each model does all of his own work independently
> — same inputs — different outputs. All outputs are inputs again to all independent
> models."*

So: same inputs, independent outputs, then **all outputs become inputs to another
independent round**. Consolidation selects the best *aspects* across documents rather
than electing one document.

**Two risks the seat flags, with proposed mitigations — the operator and Fable to rule:**

- **Incoherence.** A document assembled from the best paragraphs of seven can contradict
  itself; parts optimised separately do not necessarily compose. *Mitigation:* aspect
  selection is followed by a single **coherence pass owned by one author** (Fable, per the
  adjudication ruling) whose job is internal consistency, not further selection. Committee
  chooses the parts; one hand makes them agree.
- **Convergence to mush.** If every output is fed back to every model, round two may
  anchor on round one and lose the diversity that made the exercise valuable.
  *Mitigation:* cap the rounds (the audit loop is already capped at two), and **measure
  divergence between rounds** — if round-two documents converge sharply, that is itself a
  finding about the method, not a success.
- **Premature lock-in.** Reducing participation on n=1 or n=2 evidence is exactly the
  folklore this project is trying to replace ("race, don't decide"). *Mitigation:* narrow
  a phase's roster only after a stated number of observations, and re-test periodically —
  models change under the same label, and the epoch mechanism already exists to record it.

## The cannibalization pattern

Each pass extracts **one responsibility** into a `managent` verb, then **edits the old
script to call it.** The kludge shrinks; the new code is in production the same day;
the system never stops working. No big-bang cutover.

Every pass has the same five steps:

| step | what | why it is not optional |
|---|---|---|
| 1 | **Characterize** — write a test that passes against the CURRENT code | we must know what we are replacing before we replace it; this is the golden master |
| 2 | **Red** — extend that test to the case the current code gets WRONG, and watch it fail | a test never seen red proves nothing |
| 3 | **Build** the replacement verb in Zig | one language, real handles, no shell quoting |
| 4 | **Green** — both tests pass against the new verb | behaviour preserved AND defect fixed |
| 5 | **Dogfood** — edit the old script to call the verb, in the same pass | the replacement earns its place in production immediately |

## The passes, in dependency order

**Pass 1 — process ownership (`proc_tree`).** The smallest, most valuable unit.
New: a Zig module + `managent proc tree <pid>` / `managent proc kill <pid>` that walks
and signals a full descendant tree.
Cannibalizes: `tools/runner`'s `killpg` call site.
Characterize: current `killpg` kills a one-level child (passes today).
Red: a 3-deep tree where a grandchild creates its own process group survives today.
Dogfood: `runner` calls the verb on every kill path. Deletes the need for any reaper.
*Open experiment, to be answered first:* do `zig build`'s children escape via a new
**session** or merely a new **process group**? That decides whether tree-walking
suffices. ~20 lines, seeded.

**Pass 2 — the fleet view (`managent fleet`).** Read-only, built on pass 1's walker.
Cannibalizes: `watch-fleet.sh`, and the fleet checks inside `orcha-acceptance.sh`.
Characterize: what watch-fleet.sh reports today, on a fixture tree.
Red: today's `ps | grep -c` idiom **overcounts** when command lines wrap — it reported 3
watchdogs when 1 was running (observed 2026-08-20). The verb must count processes, not
lines.
Dogfood: the seat and the dashboards stop using ad-hoc `ps` pipelines.

**Pass 3 — run records and heartbeats into the store.**
New: `managent run record|get` verbs, written under the existing store lock.
Cannibalizes: `untracked/runs/*.json`, `untracked/heartbeat.jsonl` (2.5 MB), and the
readers in `dispatch_verify` / `token-capture`.
Red: concurrent writers currently lose updates (the `T545` class — 5 of 24 writers were
unlocked; a counter was observed running *backwards*).
Dogfood: verification and token capture read through the verb.

**Pass 4 — retire the Markdown database.**
New: `managent perf record|query` over structured rows.
Cannibalizes: `docs/infra/model-perf.md` — a 316 KB Markdown file that tools append to
and grep back out.
Red: today's ledger records provider refusals and memory culls as *model failures*, and
`DO NOT SCORE` corrections are prose that no reader enforces. Structured fields make
exclusion mechanical.
Dogfood: races and dashboards query it; `T544`'s attribution fix lands here.

**Pass 5 — the supervisor (`managent supervise`).**
By now ownership, views, run records and perf are verbs, so the supervisor is mostly
glue over tested parts.
Cannibalizes: `fleet-keeper.sh`, `bin/dispatch`, `bin/subagent`, `tools/runner`,
`fleet-cooldown.sh`.
Red: the keeper re-fired a row 80 times in 3.5 minutes because it could not see its own
in-flight work; a held-handle supervisor cannot express that bug.
Dogfood: cut over **one task at a time**, old path still available, until a full day
runs on the new supervisor.

**Pass 6 — verification into the binary.** `dispatch_verify.py` → `managent verify`.
Cannibalizes the last Python in the dispatch path.

## What we deliberately do NOT do

- **We do not scrap the old fleet first.** We need it to dispatch the work that replaces
  it; scrapping first leaves only the seat hand-coding, which is the failure mode this
  whole plan exists to end. The old path stays, capped at 1, deliberately boring.
- **We do not add supervisory processes.** The 2026-08-20 reaper/watchdog/monitor stack
  is torn down and barred from returning as a deliverable. The fix is that the mechanism
  works, not that something watches it fail.
- **We do not patch seams we are about to delete.** `fleet-repair`'s spec phase is
  redirected from *patch the 17 defects* to *triage the 17 by destination*: fix in
  managent / obsoleted by the supervisor rewrite / folds into dashboards. Cheap, and it
  stops us doing work twice.
- **We do not reopen discovery.** The list is closed at 17
  (`docs/status/tooling-defects-2026-08-20.md`).

## The risk this plan is most exposed to

`T428` was a complete, twice-audited 8-phase consolidation design from 2026-08-08 that
was **never built**. A design existing is not a design landing. Therefore every pass
here names its dogfood step as a deliverable — a pass is not done when the verb exists,
it is done when the old script calls it and the old code is deleted.
