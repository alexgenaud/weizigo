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

## 7c. Resolved — operator rulings, 2026-08-22 second batch (recorded by Fable at the operator's console; veto window open until the folding revs commit)

11. **Appetite dial is 0–9 per MODEL (short name), not 0–99 per family.** A single digit; values
    are read *relative to the current set*, not as absolute calibration. Family-level setting is a
    **bulk convenience only** ("all ollama-cloud credits are exhausted", "dial down all Claude for
    the next hour", "no local models while the 5x5 tables rebuild") — it writes the member models'
    dials, it is not the unit of record. Initial values (operator, 2026-08-22): ollama-cloud
    models 0 (CANNOT use at this time) · fable 2 (reserve for when Fable is most appropriate AND
    needed) · opus 4, qwen 4 (use when appropriate; perhaps an alternative exists) · sonnet 6,
    haiku 6, dspro 6, flash 6 (use liberally; the set's max never means must-use). Supersedes the
    0–99-per-family shape that pass-2 rev 3 §4 and S03 rev 2 §4 just reconciled to — both specs
    owe a fold; the §4 *mechanics* (0 = unliftable hard forbid, monotone back-pressure between,
    max = no back-pressure, operator-only raise, auto may only reduce) carry over unchanged.
12. **"Can use" vs "should use" are separate axes.** Appetite records only *can use* (permission +
    back-pressure on a spend pool). *Should use* is decided by model test data (the ladder) plus
    circumstantial appropriateness — including which mode the fleet is in: "get real work done"
    (exploit the ladder) vs "eager to race models where evidence is sparse" (explore). This
    ratifies and generalizes pass-2 §4.5's RESERVED finding: the reservation predicate was the
    first "should" leaking into the "can" axis; no others may leak in.
13. **Model retirement and short names.** Canonical model names are for the historic record only.
    Short names (`qwen`, `glm`, …) ALWAYS resolve to the latest actively used version of that
    line; "active" does not consider temporary credit freezes or hourly/weekly limits. Retiring a
    model re-points the short name; it never rewrites history.
14. **Escalation contract ratified** (S04 seed §6) **with two operator additions:** (a) a third
    escalation category — **a premise violated**: a long-running assumed hypothesis is falsified,
    or something believed possible proves impossible or astronomically difficult; (b) *irreversible*
    explicitly includes **more than eight hours of wasted work** (a day, a night).
15. **Runaway constants:** proposed values provisionally accepted (mint-streak trip 5, lineage
    depth 3; lane_cap deepseek 6 / ollama-cloud 5 / claude 3 / fable 1 / local 1), **conditional
    on**: (a) every constant gets a short *descriptive* name — `K`, `D_max`, `spacing_max` are
    illegible to the person who must ratify them; (b) a dedicated security analysis of the runaway
    surface before build. `spacing_max` itself is NOT yet ruled (not yet understood); explanation
    owed, then ratification.

    *Resolved 2026-08-22 (third batch, below): renames ratified (`runaway_streak` = 5,
    `lineage_depth` = 3); per-model spacing deleted (ruling 16).*

16. **Per-model spacing is DELETED; global spacing + failure backoff replace it.** Ruled after
    explanation: every dispatch is a fresh instance, so per-model spacing gated nothing real —
    its two jobs are already owned by `lane_cap` (concurrency) and the queue's failure-redispatch
    backoff (retry storms, the actual churn vector). One **global** dispatch gap remains as a
    stampede guard: default **10 s** between any two dispatches (operator's number; generous
    during development, tunable). The `cooldown_max` constant and the per-family spacing
    arithmetic (pass-2 §4.2, S03 §4) are struck at the next fold. A duplicated mechanism is
    ceremony (process doctrine).
17. **Dispatcher predicate (per-model, hard).** Separate from appetite and from "dispatch TO":
    *may this model act as a dispatcher/manager at all*. Some models can dispatch; others simply
    cannot — same shape as Fable's reservation predicate. The list is maintained from race
    evidence (T363 first data point), never from belief. Refusal reason `dispatcher-predicate`.
18. **Runaway constant renamed `runaway_streak` = 5.** Definition (plain): on every row close the
    store notes whether open rows INCREASED (the close minted more than it finished); five such
    growth-closes in an unbroken streak trips the breaker — no new dispatches, loudly, until the
    operator clears it. `lineage_depth` = 3 ratified. **Security Musts ratified:** (a) caller
    identity for store-write checks must be kernel-attested (parent-PID chain vs the supervisor's
    held-child table), never env-var self-declaration (`MANAGENT_TASK_ID` is spoofable by
    unsetting); (b) worker output is an injection surface into any reading agent — the verb
    boundary stays mechanical in managent precisely because persuasion must not matter.
19. **Escalation posture (supersedes the push/pull framing; operator's words 2026-08-22).**
    Fixable red flags are fixed and work continues. Serious irreversible blockers block — and a
    blocker is a research opportunity: the reconciler dispatches ONE bounded read-only
    investigation lane per blocker so the operator briefing is always "blocker + evidence +
    options forward with costs", never a bare halt. If unsure: investigate and research.
    Panic-halt is reserved for thrash — when investigation adds thrash and things spin out of
    control. Agents do the right thing: conservative, safe, diligent, transparent,
    evidence-based, proactive, progressive.
20. **The concern channel is first-class and always open.** Every agent — especially headless
    subagents — must be able to record a concern or finding when it, its tools, or the process
    fails (`managent assert` + findings file). Guard against protocol-skipping: a concern is
    input to the reconciler, never a discharge — it closes nothing, excuses nothing, and reaches
    the operator only after dedupe + contract check. An agent that asserts a concern still meets
    or fails its own acceptance gate.
21. **Closure is two-tier ("both"), and every phase runs a bounded audit loop.** Mechanical
    closure: rows with `gate: <command>` close on exit 0 + committed deliverables + recorded
    verdict — valid only if the gate was seen red first (red-first IS the gate's independent
    check; a second pair of eyes there verifies nothing the gate didn't). Audit-act closure:
    rows with `gate: audit` close only on an independent (non-same-family) audit verdict. Every
    row declares its gate at mint; neither gate declared = not dispatchable. **Audit loop, cap
    3:** each sprint phase is audited; red flags/blockers are addressed IN the phase, then
    re-audited; if the THIRD audit still raises red flags or blockers, the phase — and the
    sprint — blocks and escalates. Same at final verification/acceptance: the sprint may resolve
    findings inside the final audit loop, but past a third red audit it cannot close itself.
22. **Never idle; night and day are the same.** A process that halts ten minutes into an overnight
    run and sits idle is the named failure — not spend. Token/window limits (typically five-hour):
    wait with a scheduled resume, or redelegate to another model. Bugs: fix. Misbehaving tooling:
    fix, carefully. There is ALWAYS work — the **idle-work ladder** (standing fallback classes):
    play random games to falsify position scores; review code and clean up prose; optimize heavy
    algorithms; walk the epistemic claims tree — reverify, prove hypotheses, or propose
    alternative hypotheses. (STANDING-CLEANUP / STANDING-ABSORB / T533 STANDING-CLAIMVERIFY
    already exist; the queue falls back to standing rows when the priority pool is empty or
    gated.) No absolute overnight spend ceiling is set: appetite dials + provider limits are the
    spend control.
23. **No cheating (hard, mechanical).** An agent must never change a requirement it failed to
    fulfill — a lane cannot edit its own row's gate, brief, or acceptance; gate edits require an
    out-of-lane author (same enforcement family as the store-write security Musts). An agent that
    challenges epistemology MUST propose hypotheses that are testable and then actually tested —
    a challenge without a testable alternative discharges nothing.
24. **L2 start criterion (return to science) = AUTOPILOT-5H.** When operator + Fable are
    confident dispatching runs safely on autopilot for five hours — dogfooding actually works: no
    bugs biting, no orphans, no runaway agents or processes, no thrashing, no panics, no nervous
    moments — L2 and beyond begin. L1 perfection is NOT required. Concrete gate proposal: N
    consecutive unattended five-hour runs, zero orphans/runaways/breaker-trips, every lane
    accounted, real work produced each run. Until then, long runs are supervised trials.
25. **Token-window exhaustion is a first-class, testable failure mode.** The five-hour API limit
    is the most common unavoidable blocker. The handler must be **agent-free tooling** (an agent
    handler dies of the same cause) and/or **rotate across families**: Sonnet/Haiku, DS Flash,
    Ollama, local. Correction of record: **DeepSeek is NOT unlimited** — only the most reliable
    cloud family, with no five-hour limits. A local model may be the most network-failure-tolerant
    lane of all (possibly an EXCELLENT local-model niche — worth measuring). Testing: only by
    actually hitting limits — Ollama blocks NOW (free live test target); Claude limits are tested
    **constructively** every five hours (real work rides the window to exhaustion; never burn
    tokens purely to test failure; the operator will warn as limits approach). Appetite doubles
    as the spend/resource ceiling — including local compute (the 5x5 engine build is rationed by
    the same dial logic as tokens).
26. **AUTOPILOT-5H means ACTIVE autopilot.** Idle autopilot is no proof of stability. The five
    hours must contain real delegation, issue resolution, and closes — "safe active autopilot"
    is the bar that lets the operator do science in his dreams.
27. **Allocation policies are standing hypotheses, never permanent rules.** Any rotation scheme
    ("opus for analysis, sonnet for folds, DS for the pool") is a working policy under
    race-don't-decide, constantly challenged by evidence. BOTH evidence streams count:
    real-work closes are observational data (task type, model, verdict, cost at every close —
    T522 impression-or-waiver is the mechanism and should be prioritized) and multi-model races
    are the controlled experiments that adjudicate when observations conflict. Ollama models
    will often replace Claude/DS models as evidence directs.
28. **Appetite values are INITIAL and the dial is live.** Ruling 11's numbers are a starting
    point, not a constant. The operator adjusts in relative, family-bulk terms ("cool down on
    CC" = opus 4→3, sonnet/haiku 6→5, or similar) and temporarily: "increase CC for the next
    3 hours" requires a **mechanized TTL** — set-with-expiry that bumps now and auto-reverts
    later by tool, never by anyone remembering. The `managent appetite` verb gains relative ops
    (+n/-n, family bulk) and `--for <duration>`.
29. **Orchestrator work boundary.** The seat-holder personally does ONLY refinements, seed/spec
    updates, obvious one-liner bug fixes, configuration, absorption, sequencing, and dispatch.
    Everything else — real implementation, non-trivial diagnosis, substantive docs — goes
    through formal sprint rows under the pass protocol. No solo coding sessions at the seat.
30. **Seat succession, 2026-08-22.** Fable's advisory session and DSPro/T568 both retire and
    re-emerge as ONE fresh console (T612): orchestrator seat + operator's discussion surface,
    merged until the reconciler ships. Seats hand over BEFORE context fills (handover doc →
    commit → close own row with verdict → print successor paste line). Each successor's primary
    mission is shortening the seat's remaining life. T587 (store write fix + class regression)
    gates S04 build and AUTOPILOT-5H.

31. **A guard may stop a lane, but no guard may attribute.** (Operator + Fable, 2026-08-22,
    after three guards each produced a false model-failure in one afternoon: the directive gate
    killed T544 on a two-day-old pause, the refusal classifier both missed a real Claude limit
    and fired on a *quoted* 429, and the stdout-only liveness fuse killed T616 at 600.8 s with
    a finished 43 KB deliverable already on disk.) Stopping a lane is a harness decision;
    scoring a model is a measurement. The two must not share a code path. Mechanically:
    every verification record carries `killed_by` (an enumerated value written from the runner's
    own terminal record, never inferred from worker output, which is untrusted for this
    purpose), and **any row with `killed_by != none` is refused by every scorer**, which must
    state how many rows it skipped so the denominator stays visible. Hand-written DO NOT SCORE
    annotations are a symptom of this ruling's absence and are retired by T629.

32. **Liveness is per-harness, and its threshold is derived.** A fuse that reads silence as
    death is correct for a streaming `pi` lane and false for a Claude lane, which buffers to the
    end. Each harness gets a sensor appropriate to it — for Claude, mtime on deliverables,
    scratch and session transcript, not stdout — and the threshold is **≥ 3× the observed p95**
    for that harness, computed from the run records with n and the figure stated, never a
    constant someone chose. T615 survived at 598.8 s and T616 died at 600.8 s on identical work;
    a two-second margin deciding a ladder rung is a coin-flip wearing the clothes of a
    measurement. **T634 gates every further Claude lane.**

33. **Claude fan-out is capped at one race's worth of lanes — currently 3.** Seven concurrent
    Claude lanes at ~1.3 M input tokens each (T620 alone read 1,386,293) exhausted the five-hour
    window in roughly ten minutes on 2026-08-22. The interim cap was set at 2; the operator's
    2026-08-22 roster (race opus · sonnet · haiku · dspro · dsflash) needs 3 Claude seats, so the
    cap is **3, stated as a principle rather than a number: one race's Claude lanes may run
    concurrently, never two races at once, and never a fan-out plus unrelated Claude work.**
    A **RESERVED lane (Fable) never runs concurrently with a fan-out** — it runs alone or not at
    all, and Fable is not in the five-model roster. Both figures are interim, chosen to stop a
    known failure rather than measured; T628's rolling-window meter replaces them.

    **Amended 2026-08-22 17:2xZ — the cap applies to lanes that do NOT flush incrementally.**
    The cap exists to stop a wall destroying work, and evidence from the same day says that is
    now the wrong lever. Three lanes were killed mid-race (T616 liveness, T638 watchdog, T641
    protocol) and **all three left complete deliverables on disk**, because their briefs required
    a flush after every unit of work. A wall costs a flushing lane a *prefix*, not its output.
    So: a lane whose brief mandates incremental flushing, and whose work decomposes into units
    that can be flushed, may run beyond the cap; the cap binds lanes that hold their result to
    the end. The operator's standing instruction is to spend the Claude window productively, and
    an idle cap defended on a risk we have already mitigated is waste, not prudence. Every brief
    the seat writes from here mandates the flush — that requirement is now the price of the
    exemption, not a nicety.

34. **Liveness p95 is drawn from completed real work only.** (Operator, 2026-08-22.) T634 and
    T643 both computed the DeepSeek p95 wall and disagreed — **2340.9 s (n=113)** against
    **2445.05 s (n=66)** — because they drew from different populations, and both fuses now in
    `tools/runner` were derived from different figures. The population rule: **finalized,
    non-killed runs of real rows**; killed attempts are excluded (a killed attempt's wall
    measures when we stopped it, not how long the work takes, and feeding kills back into the
    threshold that caused them is a feedback loop that ratchets the fuse downward), and bakeoff
    gate sub-runs are excluded (they are harness scaffolding, not work). **One shared p95 table
    is published with the population rule stated on it, and every fuse recomputes from that
    table** — no fuse derives its own denominator privately again.

**Citing rulings — two registers, one convention.** `docs/infra/human-decisions.md` §Recently
ruled holds the operator's rulings verbatim and numbers them in its own sequence (32 census
denominators, 33 mechanized randomization, 34 solo/panel shapes, 35 thoroughness vs economy).
This section numbers its own sequence and has reached 33. **The two collide, and they are not
the same rulings.** Convention, from 2026-08-22: a bare "ruling N" means `human-decisions.md`;
an entry in this section is always cited **`§7c.N`**. Where this section restates an operator
ruling operationally — §7c.31 restates the guard ruling — it says so.

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
