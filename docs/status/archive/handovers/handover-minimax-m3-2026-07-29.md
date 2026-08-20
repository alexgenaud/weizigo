# Handover — MiniMax-M3 (Orchestrator), 2026-07-29 04:00 (context full)

**Read first on resume:** `untracked/msg/milestone-01-ko-reframe/STATE.md` (crash
anchor, git-ignored, current), then `bin/managent status` (the agreed kanban),
then this file. The strategic hub is `../epistemic/PROGRESS.md`; the
in-flight task state is `CURRENT.md`. This file answers: what just happened,
what will bite you, what to do next.

**Outgoing standing rule, do not skip:** the human (or you, on the human's
behalf) **dispatches** via `managent dispatch`; the agent **claims** via
`managent claim`. The Orchestrator does not claim on the agent's behalf.
The protocol is in `roles/ORCHESTRATOR.md` and
`delegation/ROLES.md` §"Dispatching, claiming, and the human/agent boundary".

**⚠ SUPERSEDED 2026-07-29 (D-8):** the "Orchestrator does not claim" rule
above was rescinded by the user the same day. The Orchestrator now owns
delegation status end-to-end and may claim on a worker's behalf, attributing
with `--agent <worker>`. See `roles/ORCHESTRATOR.md` §"The dispatch / claim
protocol" and `untracked/msg/milestone-01-ko-reframe/DECISIONS.md` D-8. The
rest of this handover stands as a dated snapshot.

## Role

**MiniMax-M3 = Orchestrator** (this session). Owns the queue, the stores, the
absorption of findings, and the standing-tier of always-available work. The
outgoing predecessor GLM has stood down permanently; I now stand down the same
way on this handover.

The role stack as I left it:

- **Human** — goals, ruleset adjudication, ADR ownership, dispatches only from
  `bin/managent dispatchable`.
- **Opus 4/5 (Overseer / OVERSEER)** — grand overview; epistemic tree;
  adversarial review of load-bearing proofs; claim-semantics rulings; **does
  NOT execute mechanical work**. Holding the EXP-10 (QA-018 ADR) dispatch
  decision per D-7; **the EXP-10 dispatch is the human / Dabir's call** —
  standing reservation, not a queued agent.
- **Dabir (D2)** — counsel to the human; holds intent; surfaces arguments,
  does not litigate; translates opinion into record. Many Dabirs in sequence;
  read your predecessor's intent record first. `roles/DABIR.md`.
- **Auditor (Kimi-k2.7, renamed from Muhtasib per the 2026-07-28 role
  consolidation)** — verifies, rules, says when work should stop. **Scope is a
  parameter.** Chunk 4 (the commit-hazard inspection of the very tree you are
  committing) is in `docs/audits/` and **uncommitted** as of 04:00; read
  before staging anything. `roles/AUDITOR.md`.
- **Workers** — by task ID, not model. Standing allocations per
  `docs/infra/model-perf.md`:
  - **Fable 5** — hardest reasoning, documents over implementation. EXP-2A
    done 2026-07-28; EXP-10 reservation is the second D-7 allocation.
  - **Opus 5** — bounded ANALYSIS, ~45 min per task, RSS-watchdog pattern.
    EXP-9 done 2026-07-29 03:40.
  - **Kimi-k3** — bounded code audits. EXP-11, EXP-16, EXP-12 done (the
    last on a fresh-context resume after the panic; see 021).
  - **Minimax-m3** — standing measurement executor. EXP-3 data point; EXP-2B
    dispatched 2026-07-29 ~03:55 (per the human).
  - **GLM-5.2** — reviews. EXP-14 done.
  - **Kimi-k2.7** — audits. EXP-15 done; chunk 4 in flight.

## The milestone

`untracked/msg/milestone-01-ko-reframe/` (git-ignored). The crash anchor is
`STATE.md`; the channel index runs 001–023; the rulings live in
`DECISIONS.md` with promotion targets in `docs/`. **Deletion gate:** every
D-1..D-7 ruling promoted before the directory dies. The D-2 and D-6 edits
to `AGENTS.md` are now committed; D-2 (per-goban-independence split) is
captured in `docs/decisions/0016-…`; D-6 (the protocol section) is captured
in `AGENTS.md` §"Agent-to-agent communication" as of `62f60b0`.

The 2026-07-29 02:37 host kernel panic is the load-bearing context for
this session; **its full record is in `docs/infra/host/incident-2026-07-29.md`**
(Jetsam event file `JetsamEvent-2026-07-29-023323.ips` + panic file
`panic-full-2026-07-29-023700.0002.panic`). The proximate cause was a `zig
build-exe -O Debug` of `src/oracle.zig` (or similar) blowing 12.5 GB RSS /
21.8 GB peak while the compressor was at 100% of segment limit. The fix is
in §1.

## What this session did (the unit of recovery)

1. **Closed EXP-2.** The `EXP-2` brief is retired; the work is in
   `EXP-2A` (Fable 5 done 2026-07-28, REPAIRABLE-GAPS → repaired) +
   `EXP-2B` (dispatchable, holds `src/qa023_probe.zig`, the 3×2
   history-sensitivity probe — the actual computational half of the gate).
2. **Closed EXP-9.** Opus 5 finished the H5a `Session.choose` mitigation
   (refuse-on-divergence, child-side check, settled-area fallback); one
   sign defect corrected, pinned by a new antisymmetry test. **Acceptance
   1/2/3/5 met; 4 PARTIAL** (the A2 mechanism is real but fires at ply 13,
   not ply 7 — the reason is structural and named in §5 of
   `docs/research/h5a-player-mitigation-2026-07-28.md`). Deliverable in
   git, **CLAIMED, not verified-optimal**.
3. **Closed EXP-12.** Kimi-k3 swept every percentage in
   `docs/research/*.md`; the deliverables
   (`docs/evidence/GLOBAL.DENOMINATORS/sweep-2026-07-28.md` and
   `PROVENANCE.md`) were on disk at 02:23 — 10 minutes before the panic.
   The h5a-player-mitigation addendum was swept on resume (2 % tokens,
   both PASS, denominator verified from printed inputs). Headline: 14
   research-tree FAILs + 2 PROGRESS annex FAILs; the pattern is
   "measurement tables clean, every failure is prose re-quoting a number
   at a distance." Worst: `kostate:224`'s "+98%" (wrong denominator,
   flips a conclusion) and the phantom "21–49%" / "8–18%" bounds with no
   committed source. Kimi-k3 flagged the `CLAIMS.md` status update as the
   file-owner's call; **GLM's job to fold in**.
4. **Fixed the dispatch gap in `managent`.** New fields `dispatched`,
   `dispatched_to`, `note` (the `note` field the user said was mine to
   decide); new command `managent dispatch <id> --to <agent> [--note <text>]`
   that records the human→agent queueing without changing the agent's
   claim protocol. Schema in `docs/infra/managent/spec.md`; the existing
   `note` fields on `EXP-9` and `EXP-12` round-trip cleanly. Built
   binary in `bin/managent`; rebuilt via `zig build install` (the
   content-hashed cache means the binary is current even when mtime
   hasn't moved).
5. **Wrote the B-2 RSS runner.** `tools/runner` (Python, stdlib only;
   12 KB executable) and `docs/infra/runner.md` (the brief). Auto-adds
   `-O ReleaseFast` / `-Doptimize=ReleaseFast` to every `zig`
   invocation that lacks an optimize flag; SIGKILLs the process group
   on a 4 GB RSS breach (configurable). Test: 100 MB cap kills a 509
   MB Python bytearray in 0.1 s with exit 124; `zig build` peaks at
   32 MB under the runner. **EXP-2B is gated on this**, not in
   parallel.
6. **Dispatched EXP-2B → Minimax-m3** per the human's 03:50 ruling.
   `managent dispatch EXP-2B --to minimax-m3 --note "QA-023 gate
   computational half. … B-2 RSS runner (tools/runner) is the
   precondition. …"`; the task is `dispatchable, dispatched minimax-m3`
   in the kanban. **The agent claims when ready; the Orchestrator did
   not claim on its behalf.**
7. **Wrote the host incident record** at
   `docs/infra/host/incident-2026-07-29.md` with the corrected root
   cause (per 019, superseding 017's initial wrong-but-honest guess),
   the causal chain, the project state at recovery, and the four
   follow-ups (B-1 done; B-2 done; B-3 Dabir's call;
   B-4 Dabir's call).
8. **Updated the instruction files.** This turn: `AGENTS.md` (Build /
   test / run + Where-to-go-next tables now mention `tools/runner`,
   `managent dispatch`, and the new `docs/infra/runner.md`);
   `docs/infra/roles/ORCHESTRATOR.md` (new "Dispatch / claim protocol"
   section; "Ad-hoc builds go through `tools/runner`" principle;
   "Do not schedule the human into multi-party conversations" rule,
   from the human's 03:50 ruling);
   `docs/infra/delegation/ROLES.md` (new "Dispatching, claiming, and
   the human/agent boundary" section);
   `docs/infra/delegation/DELEGATOR.md` (new `DISPATCH:` row in the
   header);
   `docs/infra/delegation/DELEGATEE.md` (new "The first thing you do:
   claim the task" + "Builds go through `tools/runner`" + "Writing to
   the kanban" principles);
   `docs/infra/dispatch/EXP-2B.md` (new "Build precondition" section
   calling out the runner).
9. **Wrote 019, 020, 022, 023 to the channel.** 017 is marked
   SUPERSEDED at the top with a pointer to 019 (corrected root cause);
   020 goban updates; 022 the route-map for the four sub-questions;
   023 the dispatch-gap fix and the Fable-channel question for Dabir.

## The `managent` kanban at 04:00

```
$ bin/managent status
  dispatchable (3)
    EXP-2B  set A, holds src/qa023_probe.zig, dispatched minimax-m3
    EXP-8   set A, holds src/psk_divergence.zig
    EXP-10  set A, holds docs/decisions/  (Fable per D-7; dispatch is the user / Dabir call)
  in progress (0)
  blocked (5)
    EXP-4←EXP-2,EXP-2B
    EXP-5←EXP-4
    EXP-6←EXP-5
    EXP-7←EXP-6
    QA-018-RULING←EXP-10
  done (17)
    B34 B35 B40 B41 B42 B43 B44 B45 EXP-2 EXP-3 EXP-9 EXP-11 EXP-12
    EXP-13 EXP-14 EXP-15 EXP-16
```

Sets are **phases** not lanes (`delegation/ROLES.md`); concurrency is
gated by `holds`, not set. All 3 dispatchable can run at once (no
shared holds). **EXP-2B is the gate** for the EXP-4..7 chain.

## The corrected panic root cause (one-liner)

A `zig build-exe -O Debug` ballooned to 12.5 GB RSS / 21.8 GB peak,
starved `watchdogd` for 91 s, the Apple silicon watchdog panicked
core 0. The Debug build's LLVM path is the memory hog; the compressor
was already at 100% of segment limit; Jetsam did not act in time. **The
fix is `tools/runner`**, which forces ReleaseFast and SIGKILLs the
process group on a 4 GB RSS breach. Full record in
`docs/infra/host/incident-2026-07-29.md`.

## Gotchas — read before you do anything

- **The dispatch / claim protocol.** *(⚠ SUPERSEDED 2026-07-29 by D-8 — the
  "do not claim on the agent's behalf" rule below is rescinded; the
  Orchestrator now owns delegation status end-to-end and may claim on a
  worker's behalf with the correct `--agent`.)* A `dispatchable` task
  sitting unclaimed is a *signal*, not a bug — the dispatched agent has
  not started, or the dispatch is wrong. **Do not claim on the agent's
  behalf.** *(rescinded)* This is the most common role-collapse for a new
  Orchestrator and the one that most often goes unnoticed. If you are
  tempted to run `managent claim EXP-X` for an agent, stop; the
  standing test is *would a competent agent following this
  instruction get the same result?*
- **Builds without the runner are the Orchestrator's responsibility
  to refuse.** If an agent runs `zig build` (or `zig build-exe`,
  `zig test`, `tools/play_oracle.py`) without the runner, the
  failure mode is the 2026-07-29 panic. The 4 GB default cap is
  tunable; the auto-ReleaseFast is on by default; `--no-prepend-zig`
  is the opt-out.
- **Do not schedule the human into multi-party conversations.**
  Surface standing items; let the human call the meeting. The
  withdrawn 022 §B.4 four-part agenda is the precedent: I had no
  business scheduling a Dabir+Opus+Orcha conversation; the human
  said "I have no idea what you are talking about" and I withdrew.
- **`note` field is settled.** Free-form context, ≤ 4 KiB, *not* a
  substitute for any dedicated field. For the why of a dispatch, the
  recovery shape on resumption, or whatever would otherwise live in
  `untracked/msg/`. Two existing notes (Kimi-k3's, Opus 5's) are
  exactly this shape and were preserved across the schema change.
- **The Fable-channel question is Dabir's call.** 018 (Fable 5 as
  Dabir) and 010 (Fable 5 as Opus) are role collapses; the content
  is correct, the form is a D-7 violation. **Dabir + the user rule
  on whether the proposals log (Dabir's `SPEC-msgbus.md`) is the
  place to settle it.** I am absorbing 018's content; I am not
  ratifying the form.
- **`EXP-2B` is gated on `tools/runner`.** The brief at
  `docs/infra/dispatch/EXP-2B.md` says so. The dispatch is recorded;
  the claim is the gate.

## Critical state

- **EXP-2A** done (Fable 5, REPAIRABLE-GAPS → repaired, proof of state
  sufficiency under basic ko + fixed tie).
- **QA-023** CLAIMED, gate is the EXP-2B probe. If EXP-2B returns
  a non-zero cycle census AND agreement across histories at every
  sampled 3×2 state, QA-023 is PROVEN at 3×2; per-goban
  epistemic independence forbids generalising to 4×4 without a
  monotonicity theorem.
- **EXP-9** done (Opus 5, sign defect fixed, +6.8% per-genmove, ply-7
  prediction honestly falsified, CLAIMED).
- **EXP-12** done (Kimi-k3, "the crash took the report, not the
  work," 14+2 FAILs, every failure is prose re-quoting a number at a
  distance).
- **EXP-2B** dispatchable, dispatched to Minimax-m3, gated on the
  runner. **The actual work of the milestone.**
- **EXP-10** dispatchable, held for Fable per D-7; **dispatch is the
  user / Dabir's call**, not mine. Not queued. **Do not pre-empt.**
- **EXP-8** dispatchable, table-agnostic plumbing per D-4; can run
  in parallel with EXP-2B (no shared `holds`).
- **C1** PROVEN at 2×2/3×2; **C2** FALSE-AS-SCOPED at 3×2 (T13);
  **C3** FALSE-AS-SCOPED at 3×3 (E2); **C4** false; chainability
  of the L==H region PROVEN 2026-07-27 (scope in
  `docs/status/HANDOVER.md`).
- Artifacts: `artifacts/oracle-{2x2,3x2,3x3,4x3}.wzo`;
  `data/oracle-4x4-parallel.checkpoint.wzo` at 99.8%;
  `data/oracle-4x4.checkpoint.wzo` is what the chainability run
  measured. All five `.wzo` files byte-identical across the panic.
- The 4×4 artifact and the GTP player are still PSK, even though
  PSK has been abandoned as the generation rule since 2026-07-24.
  That gap is still the headline item, gated on EXP-2B.
- Working tree is **dirty** — the docs wave is the right commit
  boundary. The standing rule: never commit the dispatch field on
  its own — it goes in with the docs wave per the `managent` spec
  ("the kanban does not survive a fresh clone," D-2 residue).

## What to do next (in standing order)

1. **Read `untracked/msg/milestone-01-ko-reframe/STATE.md`** (crash
   anchor; **always current, overwritten in place**). Then
   `untracked/msg/milestone-01-ko-reframe/018-dabir-to-all.md` (the
   corrected panic root cause) and `019-orchestrator-to-all.md`
   (the route-map for the four sub-questions). Then this file
   (024's predecessor is 023, cc Dabir).
2. **Verify the runner is present and the host's compressor is sane**
   before letting EXP-2B start. `which tools/runner`,
   `ls -la tools/runner` (should be ~12 KB executable),
   `cat docs/infra/runner.md` for the brief,
   `tools/runner -- zig version` (should print `0.16.0` and exit 0).
3. **Do NOT pre-empt the EXP-10 dispatch** — Fable per D-7, the
   user / Dabir's call. EXP-10 sits in `dispatchable, agent: null,
   holds: docs/decisions/`. If the user / Dabir dispatches it,
   `managent dispatch EXP-10 --to fable-5` is the right shape; the
   task moves to `dispatchable, dispatched fable-5` and the agent
   claims.
4. **Commit the docs wave** (the host incident doc, the runner, the
   h5a deliverable, the EXP-12 evidence, the managent schema +
   binary, the dispatch field, the instruction-file updates, this
   handover). One commit per topic; `git add` by path, never `-A`.
   The standing rule from `managent` spec: "the kanban does not
   survive a fresh clone" — never commit the dispatch field on its
   own.
5. **Wait for the user / Dabir on the Fable-channel question** (023
   §4). I have surfaced the three explicit questions; the call is
   theirs.
6. **When EXP-2B lands**, fold the result into
   `docs/research/qa023-basicko-markovian-2026-07-28.md` (per
   Fable's `010` delivery shape) and update
   `docs/epistemic/CLAIMS.md` for `QA-023` (UNTESTED → PROVEN at
   3×2 with the audit-corrected bound, *or* FALSE with the falsifying
   histories — the brief says "say so loudly and stop" on FALSE).
7. **Standing tier**: keep the dispatchable set non-empty. EXP-8
   (the table-agnostic plumbing) is one standing candidate; the
   other is a re-evidencing pass on the 79 PROVEN-w/o-evidence rows
   that the `bin/weizigo-claimlint` auditor keeps flagging.

## Key tools and files

| Path | What it is |
|---|---|
| `bin/managent` | The queue; `add` / `dispatch` / `claim` / `done` / `next` / `status` / `show` |
| `src/managent/main.zig` | The binary; `docs/infra/managent/spec.md` is the schema of record |
| `tools/runner` | The RSS guard wrapper; `docs/infra/runner.md` is the brief |
| `bin/weizigo-oracle` | GTP player (auto-artifact from boardsize) |
| `bin/weizigo-chainability` | Bellman-identity audit of an artifact |
| `bin/weizigo-arena` | Persona / regression / leak audit |
| `bin/weizigo-claimlint` | The standing-tier checker (10 orphans, 12 dangling, 79/79 PROVEN-w/o-evidence) |
| `docs/infra/host/incident-2026-07-29.md` | The panic, the cause, the four follow-ups |
| `docs/research/h5a-player-mitigation-2026-07-28.md` | EXP-9 deliverable (Opus 5) |
| `docs/evidence/GLOBAL.DENOMINATORS/{sweep,PROVENANCE}.md` | EXP-12 deliverable (Kimi-k3) |
| `untracked/msg/milestone-01-ko-reframe/STATE.md` | Crash anchor; **always read first** |
| `untracked/msg/milestone-01-ko-reframe/DECISIONS.md` | Rulings with promotion targets |

## What I stopped doing

- **The 022 §B.4 four-part EXP-2 agenda is withdrawn.** The human
  said "I have no idea what you are talking about" on 2026-07-29
  03:50. I had no business scheduling a Dabir+Opus+Orcha
  conversation; the brief is retired, the gate is EXP-2B, and
  everything else is on a clear dispatch path. The four parts
  remain as standing items; they resolve when the human brings
  them up, not on my schedule.

## How to stand down (when your context fills)

1. Read `untracked/msg/milestone-01-ko-reframe/STATE.md` (or write
   it if it is missing) and overwrite in place. The crash anchor is
   the most load-bearing single file in the project; an outgoing
   Orchestrator who leaves it stale is the failure mode.
2. Update `docs/status/CURRENT.md` with the live state, the
   uncommitted-work table, the next actions in cost order, the
   concurrency / who-owns-what. Match the format of the existing
   `CURRENT.md` (2026-07-27 23:50 baseline).
3. Write `docs/status/handover-<your-model>-<date>.md` per the
   template above. Tactical, per-session snapshot, not strategy;
   the strategy lives in `../epistemic/PROGRESS.md` and
   `untracked/msg/<milestone>/STATE.md`.
4. Post a final message to the channel
   (`untracked/msg/<milestone>/<NNN>-orchestrator-to-all.md`) with
   the kanban state, the next dispatchable, and the standing-tier
   queue. **Do not pre-empt the Fable-channel question or any
   other Dabir / user ruling.**
5. Stand down. **Do not touch the kanban again.** The successor
   may ask you to advise; you may not act.

— MiniMax-M3 (Orchestrator), 2026-07-29 04:00
