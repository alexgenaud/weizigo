# Orchestration layer — spec sketch (discussion; not ratified)

**Status:** DISCUSSION SKETCH · **Owner:** deepseek-v4-pro/T557 · **Date:** 2026-08-21 · **Sits on:**
pass 2 (`docs/epics/E1-markovian/L1-dashboard/S01-process-ownership/pass2/spec.md`).

Goal in one line: **queue a task once; the fleet dispatches it when conditions clear; the dashboard
tells the truth; the operator steers spec/verification/direction and never relays.**

## 1. Ownership — the model

A running task is **owned**: a supervisor holds the child's handle and observes its death directly
(`waitpid`), and reaps its tree with `treekill`. Nothing scans `ps` or polls the kanban to re-derive who
owns what. The inference window (between spawn and observation) is the root cause of every orphan,
duplicate dispatch, and misattribution this month; held ownership closes it by construction.

## 2. Supervision — `managent supervise <id> <model>` (pass 2)

The held-handle supervisor. Contract already spec'd in pass 2: six HOLD assertions (no-detach, direct
waitpid death observation, treekill containment, foreground, single-instance, single-writer). Not
re-spec'd here — this is the foundation the rest sits on, and the queue/dashboard are inert without it.

## 3. Queue — the scheduler (the "wise agent")

One loop, long-lived (or triggered). Each cycle:

1. Read **dispatchable** rows.
2. Evaluate **conditions** — all must hold:
   - **holds clear** — no writer conflict on the row's files;
   - **needs satisfied** — its dependencies are done;
   - **appetite permits** — methodology §1 (Claude CONSERVE, Fable RESERVED, DS SPEND, local PROBE);
   - **fleet quiet** — load/memory below floor, host guard not firing;
   - **discharge known** — it has an acceptance command (done is gate-able).
3. Pick **one** (ordering: roadmap priority, then FIFO).
4. Dispatch `managent supervise <id> <model>` — model and harness both from the **data table**, never
   code.
5. On child death: reap (`treekill`), write the run record with reap fields, then **re-dispatch or
   record-fail** per policy (backoff, escalate after N).

**Discharge condition:** a row is done only when its acceptance command exits 0 **and** its deliverables
are committed **and** its verdict is recorded. Done is the only success; everything else is re-dispatch
or escalation — a queue that reports success while doing nothing is the named recurring defect.

**Overnight semantics:** a run budget (stop after N closes, like the duty counter), a wall ceiling, and a
"stop if any dashboard gauge crosses X" — so an unattended night terminates cleanly and reports.

## 4. Dashboard — the truth

Gauges, each **reproducible by the command the doc names** (L1's bar): dispatchable / in_progress / done
counts, per-task liveness (heartbeat age), fleet load + host memory, claimlint floor, last-close latency.
No gauge that cannot be re-derived from disk by hand. A gauge that cannot be re-derived is decoration.

## 5. Verification

- **Ownership / supervision:** pass 2's HOLD controls — each assertion has a seeded control.
- **Queue:** seeded — (a) a dispatchable row with holds clear → auto-dispatches; (b) a hold set → does
  NOT dispatch; (c) a failed lane → re-dispatch with backoff, no silent loss; (d) budget exhausted →
  stops and reports. Correctness = "the fleet drains itself and nothing is lost silently."
- **Dashboard:** every gauge re-derived by hand from disk equals the dashboard; the acceptance is the
  "three clean days" bar (zero process-relays).

## 6. Ordering

Pass 2 (supervision) first — the queue and dashboard sit on top and are inert without it. Design the
queue **now**, calmly, ahead of build; build it after pass 2's supervisor holds its first child.
Dashboard polish finishes L1.

## 7. Resolved — operator rulings, 2026-08-21 (consolidated with T557's leanings)

1. **Ordering** — aging-priority. Default 50/99; a blocked task's priority climbs each block; when the
   next task is blocked, drop the parallel cap so logjammed tasks eventually run. FIFO is approximated by
   "lowest-priority-in-queue minus 1, all bump one on each pop". **Conditions are non-negotiable** — they
   must be satisfied before any dispatch, regardless of priority. (This logic existed in the old shell
   scripts and worked; the design phase must recover and re-spec it.)
2. **Appetite** — a spectrum, not one gate. Hard: forbid a model/family outright. Soft: subtle or strong
   back-pressure. Fable RESERVED is hard; CONSERVE is soft; SPEND is none.
3. **One dispatch (data vs code)** — open; delegate to design + audit to settle. Lean: fully data (a
   hardcoded family branch is what pass 1 deleted), but the design must prove it.
4. **Overnight** — conservative: reduced parallelization, higher tolerances for long-running processes
   (table/engine builds must not time out prematurely). **Mandatory progress reports + heartbeats — no
   silent processes** (zombie vs productive must be visible). Stop budget: all three, cheapest-first (wall,
   then closes, then gauge).
5. **Pre-ratification / recursion** — sprints MAY queue additional tasks or defer tasks, but every queued
   task must be well-specified, unique, justified, and provably NOT recursive / replicating / self-DoS.
   This needs a dedicated safety analysis (a task that mints tasks needs a cap + lineage + a justification
   field) — delegated below.

## 7b. Resolved — operator rulings, 2026-08-22 (recorded by Fable at the operator's console; veto window open until the pass-2 build commits)

6. **Standalone `tools/runner` disposition (pass-2 spec §11.1): fold into managent.** The build-guard
   role becomes a `managent` verb in a later pass; the Python runner is transitional and gets a
   ratified deletion when the verb ships — no silent deletion. HOLD-6a's path partition is
   **transitional**, not permanent.
7. **Nested-dispatch exemption (pass-2 spec §11.2): coarse refusal accepted.** Nested dispatches stay
   refused by the G6 protected-set guard. Coherent with the 2026-08-20 stand-down ruling (one
   dispatcher, cap 1). Re-open only when a real workflow needs nesting — register a row then, don't
   pre-build.
8. **`measurement-methodology.md` §3 (record shape) + §5 (grading/independence gates): ratified as
   written.** The race JSONL schema builds against them.
9. **L1 declaration bar: ratified as written** (ROADMAP-2026-08-20 §operator's frame): acceptance PASS
   three consecutive days, zero operator process-relays, duties current by the gate not by grace,
   fleet display accurate against `ps`, every gauge reproducible by its named command — then
   `managent landmark L1 --declare`, independently audited before believed. The clock has not
   started (all three duties due at 2026-08-22 00:50).
10. **Dashboard home confirmed** (operator's words, 2026-08-22: "I expect bin/managent to produce a
    dashboard with full task transparency. Written in Zig, fully tested, and reliable."). This
    confirms §4 of this doc and the S03 queue-layer spec's placement in `src/managent/main.zig`;
    `watch-fleet.sh` remains a spot-check viewer only — no further investment.

Still owed operator **numbers** (not direction; spec defaults hold meanwhile): appetite constants
(pass-2 spec §4.5) and `D_max`/mint budget (§5, `K` default 5).

## 8. Delegation (the thorough pass)

The sketch is the starting point; the full pipeline is delegated per the pass protocol: research (recover
and re-spec the old bash queue logic) → spec → scope → design → audit → plan → build. Field: Opus (design),
Flash (research), Sonnet + Haiku (audit), DSPro (author/consolidator).

## 9. Artifact-state invariant (operational, non-negotiable)

A lane's work is **LOST only when it exists in no location** — not in the tree, not in `untracked/`,
not in `/tmp/weizigo/`, not in `~/.claude/projects/*/` (Claude session transcripts), not in git history.
Everything else is a **location**: untracked, uncommitted, 0-byte-stdout, session-transcript — all
recoverable, none "lost".

A lane's deliverable lands in one (or more) of three places, and the runner/discharge must name which:
(a) an in-tree file edit (Edit/Write tool — the file is in the repo, `git status` shows it);
(b) the lane's stdout (forwarded by the runner); or
(c) the Claude session transcript (`~/.claude/projects/<slug>/<uuid>.jsonl`).

Before any claim about an artifact's fate, run the three checks mechanically, in order:
1. `git status --porcelain <path>` — committed / untracked / modified.
2. `ls -la <path>` and check size — on-disk / 0-byte / absent.
3. `ls -lat ~/.claude/projects/*/` and grep the brief text — session transcript on disk.

A 0-byte runner stdout is NOT a lost run if the lane's deliverable was an in-tree edit (T557's own
error, 2026-08-21, repeated). "Lost" is reserved for "in no location."
