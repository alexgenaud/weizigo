# Coherence audit — 2026-08-01

```
Role: Auditor (unowned msg 073 commission, picked up at human's request)
Model: claude-fable-5 · Date: 2026-08-01 · HEAD: bb8029e
Commission: untracked/msg/milestone-01-ko-reframe/073-dabir-to-all.md
  (Dabir anticipated filename coherence-audit-2026-07-31.md; executed 2026-08-01)
Inputs: msg 074 §5 findings; four parallel read scans (process docs,
  epistemic tree, tooling, staleness) + direct kanban/CLI probes.
Method: read-only except ONE mitigation applied during the audit —
  docs/infra/managent/tasks.json _sys.next_id 203 → 204 (see CA-1).
  (A `managent sync orcha` probe also wrote a seat read-cursor as a
  side effect — reverted; recorded as CA-19.)
```

Verdict in one line: **the epistemic core is sound; the orchestration
shell around it is stale and, in one place, armed to destroy data.**
Claim→evidence→task chains resolve, claimlint's calibration is real, the
epic tree restructure landed cleanly — but the kanban had a live
data-loss bug re-armed, every "read-first" status surface described a
board from hours or days ago, and the newest tooling (absorb, runner
integration, Argus routing) has gaps exactly at the seams between tools.

---

## 0. Ranked findings

| # | Sev | Area | Finding (one line) |
|---|-----|------|--------------------|
| CA-1 | CRITICAL | kanban | `suggest`/`add --auto` mint `T{next_id}` with no existence check; store had `next_id=203` with T203 live — next `suggest` would clobber T203's record and truncate its bundle. **Mitigated: next_id hand-set to 204 during this audit. Root cause unfixed.** |
| CA-2 | HIGH | status | The three read-first surfaces were all false: `STATE.md` (T192 "in flight"; it's done), `docs/status/CURRENT.md` ("no .wzo2 artifact exists"; 518.1 MB artifact landed f851102), `docs/INDEX.md:223` (routes sprint.md as "RETIRED"; it's the live ratified process doc). |
| CA-3 | HIGH | process | No stand-down handover file: ORCHESTRATOR.md:5 mandates `docs/status/handover-<model>-<date>.md`; DSPro/Orcha's 2026-08-01 stand-down produced none — substance lives only in git-ignored msg 074. |
| CA-4 | HIGH | tooling | Findings-schema fork: `docs/infra/agents/{findings-schema.json,manager-brief-template.md,subdelegation.md}` tell workers to write `untracked/T<id>-findings.json` in one schema; absorb + claimlint C7 consume only `findings/*.json` in the `findings/README.md` schema. Harness-produced findings silently bypass absorption. |
| CA-5 | HIGH | evidence | Register-cited PROVEN evidence sits in a deletable directory: CLAIMS.md:503 (CODE.VB-BLINDGAPS) cites `sprints/verify-battery/archive/T172-blind-analysis.md`, and sprint.md:51 deletes archive/ at gate — the untracked/-loss mechanism rebuilt one level up. |
| CA-6 | HIGH | tooling | `tools/runner` calls `managent claim`/`done` with output captured and return code ignored (runner:534, 660) — a deliverable-REJECTED `done` is indistinguishable from success; auto-claim failure is equally silent. |
| CA-7 | MED | kanban | Commit 62c36cc says "Purge phantom T201/T202" but also deleted T198/T199/T200 records and added T203, leaving `next_id` colliding with T203 (the CA-1 trigger). Work was absorbed (a20ad8f, 1582294) but the done-record audit trail is gone and the message misstates the change. |
| CA-8 | MED | kanban | T203's prerequisite is unsatisfiable as written: "sprint.md rev 5 must be RATIFIED" — rev 5 was superseded by 200b974 into D-16…D-20; nothing remains to ratify. Pass1 go/no-go is a human ruling, not a ratification wait. |
| CA-9 | MED | retrieval | `tools/gen-indices:207` regex requires a dot-suffix, so every scope-free `QA-nnn` claim is dropped from INDEX-claim-task.md — QA-023, the roadmap's load-bearing claim, has no task mapping. |
| CA-10 | MED | retrieval | `docs/INDEX.md:44` routes evidence lookups to `docs/evidence/INDEX.md`, which does not exist (generation deferred per project-restructure pass0 accept.md); `findings/` + the C7 gate appear nowhere in INDEX.md. |
| CA-11 | MED | watchdog | Argus works and ran today, but nothing routes its findings: live CRITICAL (`artifacts/oracle-3x2.wzo` fails to load, exit 124) sits unread in `untracked/watchdog-summary.md`; no cadence in any role doc runs Argus (STATE.md:18's "step 0" direction was never promoted into ORCHESTRATOR.md). |
| CA-12 | MED | process | Concurrency rules contradict across four docs: sprint.md:126 + subdelegation.md:26 flat "max two"; ROLES.md:74-79 analysis-unlimited; manager-brief-template.md:22 cites ROLES.md for a DeepSeek-only cap ROLES.md doesn't contain. subdelegation.md rule 3 ("subagents never touch tasks.json") contradicts its own mandatory claim/done wrapper (:59-66). |
| CA-13 | MED | process | Channel split-brain: channel.md calls the same directory "frozen historical record" (:31) and "live epic channel" (:76); AGENTS.md/ORCHESTRATOR.md/DABIR.md still use retired `<milestone>` paths; `untracked/msg/E1-markovian/` has never been created. |
| CA-14 | MED | status | Six sprint phase docs frozen at "PROPOSED … awaiting ratification" while G1/G2 cleared and ~5,000 lines shipped against them (oracle-v2 + verify-battery spec/plan/design-M1). |
| CA-15 | MED | tooling | claimlint kept its private CLAIMS.md parser after claims_register.zig was extracted for absorb — two parsers of one format (plus two findings-JSON parsers) can drift silently. |
| CA-16 | MED | docs | Dead-layout references survive the restructure in LIVING docs: `docs/design/foo/...` examples in subdelegation.md:32 + manager-brief-template.md:67,74; DABIR-INTENT.md paths/roles predate the epic tree and Orcha stand-down; DECISIONS.md D-11/D-14 not annotated "(superseded by D-20)"; DELEGATOR.md:22 cites a ROLES.md section as "goban" that is titled "kanban". |
| CA-17 | LOW | tooling | `weizigo-absorb` builds to zig-out/bin only (not deployed to bin/ like siblings); absorb is cwd-sensitive (hardcoded relative paths, no repo-root walk); `managent agent` verb missing from help text. |
| CA-18 | LOW | hygiene | `untracked/managent/tasks.json` is a dead EXP-era store shadowing the live `docs/infra/managent/tasks.json`; manager-brief-template.md:165 self-contradicts on where absorption files go; "not yet built" status lines on SPEC-msgbus.md:3 and agent-identity-and-worker-channel.md:2 (both are built); evidence dir naming contradicts evidence/README.md:218. |
| CA-19 | LOW | kanban | `managent sync <role>` is not read-only: it writes a `_sync` read-cursor for that seat into tasks.json — any probe (this audit's included; reverted) forges the seat's channel-read state. Fix: a `--peek` flag, or document that sync asserts seat identity. |

## 1. What is healthy (verified, not assumed)

- **Claim→evidence→task retrievability resolves.** 3/3 traced chains
  (QA-027, CODE.VB-BLINDGAPS, 2x2.BASICKO-TIE) reach evidence with
  provenance headers and task attribution. Register parses 274/274 rows.
- **The findings pipeline is connected, not a write-only sink.** Both
  existing findings files are absorbed into the register verbatim;
  claimlint C7 gates unabsorbed findings (0 outstanding) and its
  embedded calibration (6 known-bads) passes every invocation — the
  strongest-tested tool in the set.
- **claimlint debt matches the accepted floor** (C2=12, C1a=10, per
  T128 triage) — known debt, no regression.
- **The epic-tree restructure landed clean.** No stragglers: docs/design/
  gone, all 7 sprints follow `sprints/<sprint>/pass0/` (+archive), moves
  were `git mv`, D-16…D-20 substance matches sprint.md as rewritten.
- **Channel/directive machinery works.** `sync` exit semantics correct
  (exit 1 when a write is owed), inbox/liveness/ping functional, runner's
  directive path matches managent's, heartbeat plumbing consistent.
- **Argus itself is sound** — checklist matches the build, baselines from
  real runs, ran today. The failure is routing (CA-11), not the tool.

## 2. Kanban and dispatch substrate

The live store is `docs/infra/managent/tasks.json` (3 tasks: T192 done,
T193 + T203 dispatchable). Flags:

- **CA-1 (CRITICAL, mitigated).** Both mint paths trust `_sys.next_id`
  blindly: `cmdSuggest` (src/managent/main.zig:1300, 1352-54) and
  `add --auto` (:935, :968) do `state.put()` with no existence check —
  put overwrites — and suggest additionally `createFile`-truncates any
  existing bundle of the minted name. The T108 retry-on-verify cannot
  catch a clobber (it only checks `contains(id)`, true after overwrite).
  The only duplicate guard is on the explicit-ID `add` path (:1015).
  This is T196's A1 FAIL, still unfixed, and 62c36cc re-armed it.
  **Root fix (small):** in `parseStateJson`, after loading, set
  `sys_next_id = max(sys_next_id, max(parsed T<N>)+1)` — one pass over
  keys. Add a `next_id <= max(T-IDs)` check to `managent audit`, which
  today reports "clean" while sitting on the collision.
- **CA-7.** 62c36cc's message describes ~40% of its diff. Deleting done
  records (T198-T200) instead of retaining them also breaks
  `managent why` provenance for anything they produced.
- **CA-8.** T203 waits on a ratification that can never happen. Reword
  the prerequisite to "human go on pass1 (pass0 accept.md D1; rev-5
  substance = D-16…D-20)". Pass1 is currently ON HOLD per the human —
  the kanban should say `blocked` (human gate), not `dispatchable`.
- **CA-18.** Delete or clearly tombstone `untracked/managent/tasks.json`
  (EXP-era snapshot; anyone reading it reconstructs July's board).
- Test coverage: managent's 22 subcommands are covered by one 8-check
  shell script exercising `audit`/`status` output shape only. suggest,
  done-verification, tell/inbox, ping/liveness, standing, purge: zero.

## 3. Orchestration & absorption tooling seams

| tool | tested? | wired in? | consumed by? |
|---|---|---|---|
| bin/managent | audit/status only | build.zig; runner, argus, humans | runner, argus, agents |
| weizigo-absorb | none | build.zig; **not in bin/** | Orcha ratifies its JSONL by hand; **nothing produces its input automatically** |
| claims_register.zig | none | module for absorb only | absorb only — claimlint doesn't use it (CA-15) |
| weizigo-claimlint | embedded calibration (good) | bin/ | Argus, humans, gates |
| tools/runner | none | invoked by agents | heartbeat → liveness; claim/done (CA-6) |
| bin/argus | none | ARGUS.md role; ran today | **nobody mechanically** (CA-11) |

The pattern: each tool works in isolation; the defects are all at
handoffs — worker findings never reach absorb (CA-4), runner never
reports managent rejections (CA-6), Argus findings never reach the
kanban (CA-11), absorb's log goes to git-ignored `untracked/absorption.md`
(the loss mechanism evidence/README.md exists to prevent).

## 4. Process-doc contradictions (smallest fixes)

- **CA-12:** name ROLES.md the concurrency authority; scope "max two"
  to DeepSeek pi-subagents (rate limit); reword subdelegation rule 3 to
  "never edit shared state *directly*; kanban writes only via
  `bin/managent`".
- **CA-13:** declare channel.md the channel authority; delete "frozen
  historical record" at channel.md:31; sweep `<milestone>` → `<epic>` in
  AGENTS.md:115,193,198, ORCHESTRATOR.md:13,24, DABIR.md:15.
- **CA-16:** repoint docs/design/ examples in subdelegation.md:32,
  manager-brief-template.md:67,74; annotate DECISIONS.md D-11/D-14
  "(superseded by D-20)"; one-word DELEGATOR.md:22 goban→kanban;
  rewrite DABIR-INTENT.md at next Dabir session (it predates the epic
  tree, the stand-down, and says "Fable: retired 2026-07-30" while
  Fable wrote msgs 064–074).
- **CA-14:** six one-line header updates (both sprints' spec/plan/
  design-M1 → RATIFIED with gate + built-through note).
- ORCHESTRATOR.md: add Argus as cadence step 0 (promoting STATE.md:18);
  fix `<milestone>` paths; note `managent agent` in help.

## 5. Evidence & retrieval fixes

- **CA-5:** copy `T172-blind-analysis.md` into
  `docs/evidence/CODE.VB-BLINDGAPS/` and repoint CLAIMS.md:503; add one
  sentence to sprint.md: register-cited archive files must be promoted
  to docs/evidence/ before gate deletion (claimlint C2 then enforces it).
- **CA-9:** widen gen-indices:207 regex to
  `QA-\d+(?:\.[A-Za-z0-9_-]+)?` and regenerate; drop the embedded kanban
  snapshot (stale within hours) and the uniform relationship column.
- **CA-10:** annotate INDEX.md:44 "(not yet generated — use
  INDEX-claim-evidence.md)"; add a findings/ routing line; fix the
  sprint.md attic row (INDEX.md:223).
- CURRENT.md and STATE.md rewrites are CA-2 (below, P0).

## 6. Dogfoods (msg 074 §6, folded in as directed)

- **Dogfood #1** (blind conversion): PASS with one minor finding
  (i5-feasibility.md initially landed in pass0/, corrected in the epic
  commit). Concur with Navigator: close, no separate report.
- **Dogfood #2** (delegated-builder chain): happened unscored as
  T189→T195 and T190→T197 under subdelegation.md. Retrospective verdict
  from this audit's evidence: the chain **worked** (both builds landed,
  briefs were self-contained) but exhibited exactly the seams above —
  findings written to the wrong schema/location (CA-4) and runner-
  silenced kanban writes (CA-6). Score it PASS-WITH-FINDINGS; a designed
  re-test is unnecessary — fixing CA-4/CA-6 and watching the next real
  dispatch is the better experiment. Close both dogfoods.

## 7. Suggested sequence

**P0 — before any dispatch (hours, mostly one-liners):**
1. ~~Disarm next_id~~ — done during this audit (203→204, uncommitted).
2. Root-fix CA-1 (parseStateJson max-reconcile + audit check) — small,
   register as a task; it is the dispatch substrate's integrity.
3. Rewrite STATE.md snapshot + CURRENT.md top block (CA-2).
4. Backfill `docs/status/handover-dspro-2026-08-01.md` from msg 074 +
   DECISIONS.md (CA-3).
5. Register tasks for: CA-1 root fix, CA-4 schema unification (doc-only),
   CA-6 runner returncode check (~4 lines), CA-11 Argus routing + the
   live oracle-3x2.wzo CRITICAL, CA-5 evidence promotion.
   (Use explicit-ID `add` until CA-1's root fix lands, out of caution.)

**P1 — first Orcha shift:** dispatch T193 (unblocked M4a run); the CA-5/
CA-9/CA-10 retrieval fixes; CA-12/CA-13/CA-14/CA-16 doc sweep as one
batched low-risk task; re-status T203 as human-gated (CA-8).

**P2 — opportunistic:** CA-15 parser unification; absorb deployment +
repo-root walk (CA-17); evidence naming normalization at pass1 (CA-18);
managent test coverage for suggest/done/tell/inbox.

## 8. Orcha reactivation — when and who

**When: after P0 items 2–4, i.e. about one working session from now.**
Not before: an Orcha's first acts are reading STATE.md (false until
fixed) and minting tasks (data-destroying until CA-1's root fix, or at
minimum with the mitigation + explicit-ID discipline). Reactivating on a
repaired substrate costs half a day; reactivating now re-runs the July
31 failure mode where paper and reality diverge within hours.

**Who: DSPro.** Rationale: (a) the model-allocation policy delegates
sustained coordination to DSPro/DSFlash by default, reserving Fable for
deep holistic work (this audit being the archetype) and Opus for sparing
use; (b) DSPro just held the seat through T165–T200 — 36 tasks, two
sprints to M4a/P3-H, one CRITICAL caught (colex) — so continuity of
seat-knowledge is real; (c) the stand-down defects (missing handover
file, mislabeled purge) are process gaps this audit now documents, not
capability gaps. The ratified 2026-07-29 allocation named GLM=Orcha;
that remains the alternative if the human prefers seat separation
(DeepSeek already holds Dabir, and one model family holding both ears
(Dabir) and hands (Orcha) weakens the counsel/executor split). Decision
is the human's; this audit's recommendation is DSPro with GLM fallback.

**First-shift brief for the incoming Orcha:** read msg 074, this audit,
and DECISIONS.md D-16…D-20; execute P0 items 3–5; adopt Argus as cadence
step 0; then dispatch T193. Human rulings still outstanding and NOT
Orcha's to make: pass1 go/no-go (T203), ADR-0020 fork, WZO1-brackets,
rule-mismatch rulings, and closure of the two dogfoods (§6 recommends
closing both).

— Fable, coherence audit, 2026-08-01
