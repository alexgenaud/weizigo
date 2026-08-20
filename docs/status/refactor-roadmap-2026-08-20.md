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
