# T549 · fleet-repair pass 1 — Spec: what do we want?

| | |
|---|---|
| Sprint | `fleet-repair`, pass 1 (owner: Orchestrator seat, `docs/infra/fleet-repair/CYCLE.md`) |
| Phase | 1 of 8 — **Spec** (bookend) |
| Writer | deepseek-v4-flash/T549.2 |
| Date | 2026-08-20 |
| Audit | T550 (different model — this document is not accepted until its audit PASSes) |
| Status | PROPOSED — Revision 1. Becomes RATIFIED only after its audit gate and the sprint owner's ruling; the author does not ratify their own spec |
| Landmark | L1 (the dashboard tells the truth) |

Protocol: `docs/infra/sprint.md` ("The ladder", "Bookends", "Phases", "Audit gates",
"Audit loop"). Worked example of the cycle: `docs/infra/tool-consolidation/`.
Every claim below cites the file, line, or commit it was read from; nothing here is a
design decision — the Design and Test phases own those.

---

## 1. The problem, stated once

On 2026-08-20 the fleet was run hard and the tooling failed in **seventeen catalogued
ways** (`docs/status/tooling-defects-2026-08-20.md`, section D — the durable inventory,
discovery deliberately CLOSED at 17 per the operator's direction). The day's response
was to hand-patch and to stack supervisors on a supervisor — a reaper, a watchdog, a
monitor watching the watchdog — which was scaffolding around an untested foundation,
not engineering, and is **withdrawn** (`ec72cdb` "Stand down the supervisory sprawl:
one dispatcher, cap 1, no reaper, no watchdog, no monitor"). This sprint replaces that
response with one properly specified, audited, tested repair, and the repair is *that
the underlying mechanisms work*, not that something watches them.

The inventory's own closing note names the recurring shape: *the measurement apparatus
quietly producing the answer it assumed* — a verdict counting only FAIL, a counter that
only rises, refusals scored as failures, an invariant comparing empty sets, an
allocation default starving the alternative it was meant to be tested against. Section 2
tests that diagnosis against all 17 and refines it.

### 1.1 The 17 defects, with their current owner

Status key: **OPEN** = no row owns it yet · **ROW** = registered kanban row (state
verified 2026-08-20 ~16:10Z via `bin/managent show`) · **DONE** = fix already landed.

| # | defect (inventory) | evidence (path:line, verified 2026-08-20) | owner |
|---|---|---|---|
| D1 | `pause` is `kill` — no graceful suspend; a `pause` directive SIGKILLs the worker and discards context | `tools/runner:316` — `stops = [d for d in pending if d.get("directive") in ("pause", "kill")]`; `tools/runner:1221-1222` — `exit 124 (directive: pause/kill pending)` | OPEN |
| D2 | No resource-aware admission — a suite row is worth ~7.0 GB, a text edit ~60 MB, and the cap counts workers, not weight | commit `add986c` (measured 16:56: T524 held three live test binaries, 2918+2915+1156 MB); runner host floor `hw.memsize // 8` = 6144 MB (`tools/runner:18-22`) | OPEN |
| D3 | `rc=124` is unclassifiable — the classifier keys on provider error text only, so host-pressure kills score as model failures | `tools/dispatch_verify.py:66-98` — `PROVIDER_REFUSAL_SIGNATURES` (429/401/403 text patterns); no host-memory pattern exists | OPEN |
| D4 | `bin/dispatch` writes neither `model` nor `dispatched_to`; the store keeps whatever was last set | `bin/dispatch` (whole file, read 2026-08-20): prints `dispatched {id} → {canon}` at line 279 and returns; **no store write anywhere in the file** | ROW: T544 (dispatchable) |
| D5 | `bin/subagent` hardcoded `--output-format text` for Claude lanes → no usage envelope, tokens lost at dispatch | **FIXED** by T521, commit `784235a`; current `bin/subagent:257-264` emits `--output-format json` | DONE |
| D6 | Orphaned suite runs survive their console (reparented to init), doctor detects but nothing prevents/reaps | inventory §D6; `docs/status/tooling-defects-2026-08-20.md` | ROW: T548 (dispatchable) |
| D7 | A malformed findings JSON halts the entire fleet's commits — C7-nonconforming floor is 0, so one bad file blocks every pre-commit | `tools/hooks/claimlint-floor.json` — `"C7-nonconforming": 0` | OPEN |
| D8 | `managent tell` reports success for a directive that never landed | **Root cause FIXED** by T545 — `findings/T545-store-clobber.json` (five writers, all now lock→read→modify→write→unlock) | DONE (verify, don't rebuild) |
| D9 | Directive IDs collide with historical ones — D041/D042/D043 exist twice with different targets | inventory §D9; consequence of T545's lost updates, now fixed at the root; the *existing* duplicates need reconciliation | OPEN (reconciliation) |
| D10 | No check anywhere that a dispatch's bundle `holds` matches the store; the seat dispatched into a live holder twice | `bin/dispatch` (read in full 2026-08-20) has no holds check; the *warning* exists only in managent (`src/managent/main.zig:854-865` `effectiveHolds`, `:2138-2143`) | OPEN |
| D11 | The keeper silently inherits `WEIZIGO_AGENT_DEPTH` and can refuse every dispatch while looking healthy | `tools/fleet-keeper.sh` — no depth guard or exemption; refusals logged as ordinary lines | OPEN |
| D12 | No memory-weighted admission (same gap as D2, specific trap: documented cap safe, effective cap not) | inventory §D12; cap stopgapped to 3 | OPEN (folded into D2) |
| D13 | Logjam-pressure shrinks the cap even when the anchor is file-blocked, not slot-starved — starves conflict-free work | `tools/fleet-keeper.sh:679-684` pressure bookkeeping; `untracked/fleet-keeper.pressure.json` | OPEN |
| D14 | The keeper has no preconditions; `requires_drained_fleet` is inexpressible, so T541 was dispatched into a full fleet | `tools/fleet-keeper.sh` eligibility: status + needs + bundle + model + holds only (read 2026-08-20) | OPEN |
| D15 | Concurrent workers share one git index; stage→commit has no lock, so disjoint holders corrupt each other's authorship | **FIXED** by T547, commits `4ed5ab2`/`1fbea69`; `tools/git-commit-mine:146-148` (mutex, fd 9), `:258+` (holds check) | DONE |
| D16 | Killed workers orphan multi-GB suite children; leak is continuous, not crisis-only | inventory §D16 (refined hypothesis 17:08); `untracked/T548-orphan-suite-reaper.md` | ROW: T548 (dispatchable) |
| D17 | A `blocked` close satisfies a dependency — refusing work counts as having done it | `src/managent/main.zig:1538-1544` — `needsMet` requires only `status == .done`, never looks at `verdict` | OPEN |

The four registered rows' state at writing: **T544** (model attribution) — dispatchable,
holds `src/managent/main.zig`; **T546** (aspect races round 2) — done (commits
`2b57a5d`, `8d15020`; 20 pass, 2 infra, 22 tokens); **T547** (commit index mutex) —
done; **T548** (orphan suite reaper) — dispatchable, holds `tools/runner`. T545 (store
locking) — done. T546 is race *work*, not a defect, and is out of this sprint's scope
(§5).

### 1.2 What is already resolved (so the sprint does not re-build it)

Three of the 17 are resolved as of this spec's writing, and the Test phase must prove
each with a control rather than re-implementing it:

- **D5** — T521 landed token capture at dispatch (`784235a`); the live proof is T546's
  17/17 lanes with token readings (commit `0f8ea6c`).
- **D15** — T547 landed the commit mutex + holds refusal (`4ed5ab2`, `1fbea69`), with
  the worktree-vs-mutex judgment recorded in `findings/T547-index-mutex.json`
  (mutex chosen; reasons: cost, the shared coordination surfaces, merge-step
  attribution ambiguity).
- **D8** — T545 landed locking for all five store writers (`findings/T545-store-clobber.json`).

After collapsing the duplicate entries (D2=D12; D6=D16) and the resolved three, the
sprint's genuinely open surface is **12 distinct defects in 4 groups** (§2).

### 1.3 Adjacent defects still live (context, not scope)

The inventory's section C items were "owned by T540", which closed pass-with-findings —
but its deferrals mostly did not land. Verified live on 2026-08-20 (safe probes only):

- **C1 unknown flags** — `MANAGENT_STORE=<scratch copy> bin/managent next --T540-BOGUS`
  silently claimed a row, exit 0, against the current binary (`fbbc793`). T540
  deferred this to T539; it is not fixed.
- **C7 blank lines** — `docs/infra/managent/directives.jsonl` is **54/157 blank**
  (measured 2026-08-20); T540's data compaction was re-dirtied, and the writer fix
  (cmdInbox ack-rewrite) was deferred.
- **C2 keeper model list** — `tools/fleet-keeper.sh:286-290` still hardcodes
  `["kimi-k2.7", "minimax-m3", "deepseek-v4-flash", "deepseek-v4-pro", "glm-5.2"]` with
  no Claude labels (the inventory cites `:247`; the line has drifted — see §7.1).

These are stated as context because they interact with the D-items (C2 is a reader that
T544 must fix; C1 is the same "silent acceptance" family as D10). They are **not** this
sprint's scope unless the Plan phase folds them in with a stated reason.

## 2. A defensible grouping

**Grouping criterion:** defects are the same defect when they share the *mechanism that
must change* — the same fix surface, file hold, or instrument contract — and are
distinct when a change to one would not touch the other. Grouping by symptom
("memory", "attribution") is rejected because it would split one file-change across
groups; grouping by file alone is rejected because one mechanism (the runner's exit
paths) owns several distinct defects.

The 17 entries collapse to **15 distinct defects** (D2=D12 and D6=D16 are the same
defect written twice from different angles — the inventory itself says so: §D12 "same
gap as D2", §D16 vs §D6 same reaping gap, refined hypothesis). Those 15 fall into four
groups:

### G1 — Memory lifecycle: the fleet cannot account for or control its own memory

| defect | what must change |
|---|---|
| D6/D16 — orphan reaping (T548) | `tools/runner` descendant-reaping on every exit path + a periodic sweeper; the runner's `os.setsid()` child (`tools/runner:1161`) survives `os.killpg` (`:1503-1505`) for reasons T548 must establish |
| D2/D12 — weight-aware admission | the keeper's admission must know a suite row ≈ 7.0 GB and a text row ≈ 60 MB (`add986c`), plus a mutex on concurrent full-suite runs |
| D3 — rc=124 unclassifiable | `tools/dispatch_verify.py` classifier gains the runner's `[runner] KILL: host memory pressure` line (`tools/runner:1435`) → `verified=unreached reason=host-memory-pressure` |
| D1 — pause is kill | `tools/runner:316` — either real suspend/resume, or the directive renamed so it cannot be mistaken; the operator asked for graceful suspend on 2026-08-20 and it does not exist |

One sentence: **the runner must reap what it kills, admit what fits, name why it
killed, and suspend when asked to suspend.** Without reaping, admission is meaningless
("admission control alone will not help if dead workers keep their memory" —
`untracked/T548-orphan-suite-reaper.md`, Notes); without honest death classification,
every admission failure is scored against a model that did nothing wrong.

### G2 — Attribution integrity: who did what cannot be trusted

| defect | what must change |
|---|---|
| D4 — dispatch writes no model (T544) | `bin/dispatch` writes `model` + `dispatched_to` into the store at dispatch; the close path requires an attributed `--agent` or an explicit `--model-unknown <reason>` (never a silent null) |
| D15 — shared git index (T547) | **done** — commit mutex + holds refusal; residual work is verification, plus the recorded worktree judgment as precedent |
| D9 — directive-ID collisions | uniqueness on the write path (refuse a new directive whose ID collides) + reconcile the existing D041/D042/D043 duplicates |

One sentence: **every committed fact — dispatch, close, directive — must carry its
author, and the audit trail must not silently mix them.** D15's fix landed first
because its *record* (mixed authorship on 2026-08-20, documented in T547's findings) is
input to T544's backfill conflict rule ("prefer telemetry over the store" must note
that commit authorship is unreliable for that date — `untracked/T547-commit-index-mutex.md`, Notes).

### G3 — Row-lifecycle semantics: the kanban's 1-bit status lies

| defect | what must change |
|---|---|
| D17 — blocked satisfies needs | `src/managent/main.zig:1538-1544` — `needsMet` must require `status == .done` **and** `verdict ∈ {pass, pass-with-findings}`; a row that declined its work must not discharge a dependent |
| D14 — no preconditions | a real precondition field the keeper evaluates (`requires_drained_fleet` or a general predicate), replacing the fake `needs` edge |
| D13 — pressure misdiagnoses holder-block | the pressure state machine shrinks the cap only when the anchor is slot-queued with free holds; a live holder's wait is bounded by the holder, and conflict-free candidates stay admitted at full cap |
| D11 — keeper inherits depth | the depth guard exempts the keeper (it is a scheduler, not a delegating worker), and a keeper that cannot dispatch prints a loud `KEEPER CANNOT DISPATCH: <reason>` instead of refusals that read like queue chatter |

One sentence: **the row's stored state must distinguish "did the work" from "declined
the work", the keeper must know what it cannot do and say so, and its pressure
machinery must act on the real blocker.** D17 is the only one of the four that is
actively misrepresenting the graph today (see §4.2).

### G4 — Instrument honesty: reports success while doing nothing, or cannot report its own failure

| defect | what must change |
|---|---|
| D7 — malformed findings JSON halts the fleet | validate-on-write in the duty/findings harness: the writer rejects a nonconforming file naming the file and line, before claimlint's global floor ever sees it |
| D10 — dispatch holder-check gap | `bin/dispatch` warns or refuses when a bundle declares `holds` the store does not carry, and refuses when a declared hold belongs to a different in_progress row (mirrors the managent-side warning at `src/managent/main.zig:854-865`) |
| D5 — Claude token capture | **done** (T521) — verify with a control, do not rebuild |
| D8 — tell success without landing | **root done** (T545) — verify the write is now locked and the runner's directive read sees it; residual is that `tell` must exit non-zero if the write fails |

One sentence: **a tool must either do what its name says, or fail loudly saying what it
did instead — never succeed silently.** D5/D8 are here as verification obligations, not
build work.

### 2.1 Verdict on the Orchestrator's grouping hypothesis

The hypothesis — *most reduce to instruments that cannot report their own failure* —
is **confirmed in shape, with three refinements**, and the count is defensible:

- **12 of 15 distinct defects fit the family** once "cannot report" is extended to
  "cannot represent": D2/D12 and D14 are *missing-representation* (the instrument has
  no concept of resource weight or precondition, so it cannot even represent the
  failure, let alone report it); D3, D11, D13, D17, D4, D6/D16, D7, D9, D10 are
  *mis-reporting or non-reporting* (wrong verdict, chatter that reads as health, a
  1-bit status overloading two meanings, stale data read as truth, a monitor reading
  free memory while orphans hold 2.8 GB, a gate that blocks the whole fleet for one
  writer's mistake, a duplicate ID with no alarm, a check that exists nowhere).
- **Two refute the strong form.** D1 is not "cannot report its own failure" — the
  runner *does* report `[runner] KILL: directive D047 PAUSE`; the defect is that the
  **name** (`pause`) promises what the mechanism (SIGKILL) does not deliver. That is a
  verb-contract violation, distinguishable from instrument honesty. D15 is a
  **shared-mutable-state** (concurrency) defect — its cost (mixed authorship) corrupts
  a reporting surface, but the defect is the missing lock, not a lying instrument.
- **One is residue:** D9 is a data-integrity scar of T545's lost updates; the root is
  fixed, the existing duplicates remain to be reconciled.

The inventory's own pattern sentence ("the measurement apparatus quietly producing the
answer it assumed") survives as the *best* description of the family's core, but the
spec's grouping is by mechanism (fix surface), not by the pattern — because the fix
for "cannot report its own failure" is different in each group: G1 builds the missing
mechanism, G2 records the missing author, G3 adds the missing state, G4 adds the
missing check.

## 3. What "fixed" means, in testable terms

Each condition below is a statement a control can check; the Test phase builds the
fixtures from these. The rows' briefs already specify controls for T544/T547/T548 —
they are incorporated here by reference, not restated from memory.

### G1 — Memory lifecycle

- **Reaping (D6/D16, T548).** `tools/regression-runner-reap.sh`: a stub worker spawns a
  long-lived child, then the worker dies by **each** exit path (normal, wall, RSS cap,
  host floor, directive kill) → the child is gone in every case. A live worker with a
  live child → child untouched. A pre-existing orphan and a live-owned process side by
  side → the sweeper takes the orphan only. A process orphaned for one pass only → NOT
  reaped (the two-pass guard, 45 s apart). Every reap logged with pid, RSS, reason —
  a silent kill is a failed control.
- **Weight-aware admission (D2/D12).** Given two admission slots and one suite-weight
  row plus one text-weight row, the suite row admits and the second suite row is
  refused or deferred with a reason; the text row admits alongside either. The full-suite
  mutex: two concurrent suite runs → the second blocks (flock), never doubles the suite
  footprint. The numbers are inputs, not guesses: a suite row ≈ 7.0 GB (measured,
  `add986c`), a text row ≈ 60 MB; admission must state which weight each admitted row
  drew and the running fleet RSS.
- **Honest death classification (D3).** A log containing `[runner] KILL: host memory
  pressure` and rc=124 → the perf ledger records `verified=unreached
  reason=host-memory-pressure`, **not** `verified=fail`. A provider 429 still classifies
  as today (no regression). The wall-kill path (`rc==124` with a wall reason,
  `tools/dispatch_verify.py:662-666`) stays distinct from the host-pressure path.
- **Pause semantics (D1).** Either: a `pause` directive suspends the worker (SIGSTOP
  or equivalent), the run record says `suspended` not `killed`, and a later `resume`
  continues it with context intact — the operator's asked-for capability exists. Or, if
  real suspend is out of scope for this pass: the `pause` name is gone, the runner
  refuses `pause` with "not implemented" (exit non-zero naming the reason) rather than
  silently treating it as `kill`, and the seat's `T544`-destroying mistake is
  structurally impossible. The Accept gate takes **either** branch, but not a third.

### G2 — Attribution integrity

- **T544's controls** (from its brief, restated as the bar): close with no `--agent` →
  refused (or recorded `--model-unknown <reason>`); bogus label → refused naming the
  canonical list; backfill over a fixture with 2 recoverable + 1 unrecoverable row → 2
  filled with source tags, 1 marked `unattributed-pre-T544`, second run a no-op;
  conflicting sources → conflict recorded, no value chosen; an already-attributed row →
  untouched. Live end-state: **0 null-model closed rows after the fix**, 56 backfilled
  with sources, 96 explicitly marked — every future aggregation can exclude them by
  name.
- **D15 (T547) verification.** `tools/regression-commit-concurrency.sh`: two concurrent
  `git-commit-mine` runs staging different paths → both land, each containing only its
  own paths; a path held by a different in_progress row → refused naming the holder;
  the same with `--explicit` → allowed with a loud recorded escape; quiet-repo single
  commit → unchanged behavior. The worktree-vs-mutex judgment stands as recorded
  (`findings/T547-index-mutex.json`).
- **D9.** No two lines of `docs/infra/managent/directives.jsonl` share a directive ID;
  a write that would collide refuses (or re-issues with a disambiguated ID) before
  landing; the existing D041/D042/D043 duplicates are reconciled with a documented
  decision (re-issue or tombstone) — an ID is a reference, and a duplicated one breaks
  the audit trail.

### G3 — Row-lifecycle semantics

- **D17.** Close a row `blocked` (or `fail-found`/`abandoned`) that a dependent `needs`
  → the dependent stays `blocked`; close the same row `pass-with-findings` → the
  dependent becomes `dispatchable`. The exact T541→T535 shape (a refused row silently
  unblocking the Stage-4 spec) must be impossible; the regression asserts it by name.
- **D14.** A row whose bundle declares `requires_drained_fleet` (or the general
  predicate) + a non-empty in_progress set → the keeper refuses to dispatch it and the
  refusal names the precondition; with in_progress(0) → dispatched. The seat's fake
  `needs` edge is removed once the field exists.
- **D13.** Anchor in_progress-blocked on a held file + a conflict-free candidate
  dispatchable → the candidate is admitted at the full cap (pressure file shows no drop
  for the holder-blocked case); anchor slot-queued with free holds → the cap drops as
  today. The T544/T545 16:07 shape (cap 3→1 while T521 sat dispatchable) cannot recur.
- **D11.** A keeper started from a shell at `WEIZIGO_AGENT_DEPTH=3` dispatches normally
  (the guard exempts the keeper); a keeper that can dispatch nothing prints a loud
  `KEEPER CANNOT DISPATCH: <reason>` line once per iteration, not refusals that read
  like ordinary chatter.

### G4 — Instrument honesty

- **D7.** A findings JSON with a literal newline inside a string (the DARGUS-chunk
  shape) is rejected by the duty/findings harness write path — file and line named —
  before claimlint's C7-nonconforming floor is ever consulted; the repo pre-commit is
  not the enforcement point. A valid findings file passes untouched.
- **D10.** A bundle declaring `holds=` the store does not carry → `bin/dispatch` warns
  (or refuses) naming the gap before spawning anything; a declared hold belonging to a
  different in_progress row → refused. This is the dispatch-side mirror of the
  managent-side warning (`src/managent/main.zig:854-865`) and of the claim-time warning
  this very spec received ("T549 declares holds in its bundle but the store row has
  none", 2026-08-20 16:00Z).
- **D5/D8 verification.** A claude-lane dispatch produces a `_trailer_token_reading`
  / usage envelope (the T546 17/17 readings are the live proof); a `tell` whose store
  write fails exits non-zero with the reason and does not print success.

## 4. Ordering with stated dependencies

**Dependency principle:** *memory before accounting; write-path before backfill; cheap
honesty before expensive machinery; one file, one hold.* Each arrow below names the
reason.

### 4.1 Verdict on the Orchestrator's suggested order (T548 → T547 → T544)

**Confirmed in shape, with T547 already landed and two refinements.**

1. **T548 (reaping) first — agree, and it is not close.** D2/D12 admission is
   meaningless until dead workers stop keeping their memory: the 16:51 cull left 9.1 GB
   orphaned while free memory was 0.06 GB, and the 17:08 detections prove the leak is
   continuous, so "free memory is healthy" is not evidence the leak is absent
   (`untracked/T548-orphan-suite-reaper.md`). Reaping is the upstream of every memory
   crisis this sprint names.
2. **T547 before T544 — agree; the point is moot because T547 is done.** What remains
   load-bearing is T547's *record*: T544's backfill conflict rule must know that commit
   authorship is unreliable for 2026-08-20 (`untracked/T547-commit-index-mutex.md`,
   Notes). T544 is correctly sequenced after that documentation.
3. **Refinement A — batch the runner-file changes.** D1 (pause) and T548 (reaping)
   both mutate `tools/runner`; the one-writer rule (AGENTS.md, `holds=`) makes them
   serial anyway, and they share the exit-path logic (a suspend path and a reap path
   are the same state machine). They should be one hold, one row, one regression file
   if the Plan phase can justify the merge — otherwise T548 first, D1 immediately
   after, never concurrent.
4. **Refinement B — D17 is cheaper and more urgent than the memory work for one
   specific reason.** It is the only defect *actively misrepresenting the dependency
   graph right now*: T535's `needs` includes T541, which closed `blocked`, and only the
   still-open T544/T548 keep T535 gated today (`bin/managent show T535`, verified
   2026-08-20). The moment those close blocked, T535 unblocks wrongly. D17 is a
   ~15-line change at `src/managent/main.zig:1538-1544`; it must land before T544's
   close-path work because both touch that file and D17's fix is a precondition for
   T544's "verdict at close" semantics to mean anything.

### 4.2 The ordering, stated as a sequence

| order | work | why here |
|---|---|---|
| 1 | D17 — `needsMet` requires a success verdict | cheapest live lie in the graph; unlocks honest `needs` for everything after; same file as T544, so it serializes before it |
| 2 | T548 + D1 — runner reaping + pause semantics, one hold on `tools/runner` | memory upstream; the crisis the operator named; D1 rides the same file and exit paths |
| 3 | D3 — rc=124 host-pressure classification | makes the culls T548 still produces score honestly; independent file (`tools/dispatch_verify.py`), may run parallel to 2 under the analysis-parallel rule |
| 4 | D2/D12 — weight-aware admission + suite mutex | depends on 2 (admission is pointless while orphans keep memory) and on 3 (admission's refusals must be scored honestly); keeper-side |
| 5 | T544 — attribution write-path + backfill | depends on T547's authorship record (done) and on D17 (verdict semantics); holds `src/managent/main.zig` after 1 clears |
| 6 | D14 — precondition field | depends on 1 (eligibility semantics); needed before T541's quiet re-run can be re-gated honestly and the fake `needs` edge removed |
| 7 | D13, D11 — keeper pressure + depth | keeper-internal, independent of 6 but shares `tools/fleet-keeper.sh` — batch under one hold |
| 8 | D7, D10, D9, D5/D8-verify | small, independent, each a separate row; D9's reconciliation wants T545's root fix (done) and a quiet moment |

T547 (verification of the landed mutex) and the D5/D8 verification controls can run
anywhere in the sequence; they are audit obligations, not dependencies.

## 5. Explicit non-goals

1. **The torn-down supervisory stack must not return as a deliverable.** No reaper
   process watching workers, no watchdog, no monitor watching the watchdog, no
   new "army of monitors" — the operator's words, 2026-08-20; `CYCLE.md` rule 4; commit
   `ec72cdb`. The fix is that the runner and keeper mechanisms work. **The one nuance,
   drawn testably:** T548's brief explicitly wants a *periodic sweeper* for orphans
   that already exist (`untracked/T548-orphan-suite-reaper.md`, "What to build" §2) —
   this sprint treats the sweeper as a **resource collector, not a supervisor**: it is
   in scope iff (a) it watches only for orphaned `.zig-cache/o/*/test` trees, never
   worker health; (b) it keeps the three conservative guards from the seat's stopgap
   (match pattern, ancestry walk that skips live chains, two-pass 45 s confirmation);
   and (c) it grows no state and no sibling processes. A sweeper that starts watching
   workers is a supervisor and is out. This judgment is flagged for the audit; if the
   auditor disagrees, the sweeper is descoped and reaping is runner-only.
2. **No retro-splitting of `784235a`/`081b673`.** The mixed authorship of 2026-08-20 is
   a recorded known fact (`findings/T547-index-mutex.json`); rewriting history to fix
   it is a larger risk than the misattribution it corrects (T547's Notes).
3. **No engine, ruleset, or epistemic work.** `src/retro.zig`, `oracle.zig`,
   `rules.zig`, `solve.zig`, CLAIMS.md semantics, and the register are untouched; this
   sprint repairs the delegation toolchain only.
4. **No race re-runs.** T546 is done (22/22 owed lanes with token readings); the races
   are not this sprint's work.
5. **Discovery stays closed at 17.** An 18th defect found in passing goes to a findings
   file, never into the spec or the scope.
6. **T541's quiet suite re-run is a consumer, not this sprint's work.** This sprint
   builds the precondition mechanism (D14) that lets it be gated honestly; the re-run
   itself is a separate dispatch on a drained fleet.
7. **No new cap guesses.** The stopgap cap of 3 is a workaround, not a fix
   (inventory §D12); admission replaces the guess — the fix must not add a second
   hardcoded number alongside it.

## 6. Success condition for the sprint as a whole

The Accept bookend is graded against these, with denominators stated per item. A
condition is met only when its control was shown RED first (standing rule: a test first
seen green proves nothing; `sprint.md` Test phase; the 2B-5 positive-control scar).

- **S1 — every one of the 15 distinct defects has a disposition at Accept:** fixed with
  a RED-first control quoted, fixed by the T544/T548 rows' close, already-resolved
  (D5/D8/D15) with a verification control, or explicitly non-goaled with a reason.
  Denominator: 17 inventory entries = 15 distinct defects = 12 open + 3 resolved.
- **S2 — memory:** a fleet of ≥2 suite-weight rows runs under the runner's 6144 MB host
  floor with zero host-pressure culls attributable to admission; the post-run orphan
  census is zero; the sweep log accounts for every reaped pid with reason. Denominator:
  all runs in the sprint's verify phase.
- **S3 — death accounting:** every infrastructure death during the sprint (guard kill,
  host pressure, provider refusal, wall) is recorded `verified=unreached reason=<actual>`
  and none as a model failure. Denominator: every `dispatch-verify` ledger line the
  sprint produced; 0 seeded misclassifications.
- **S4 — attribution:** 0 null-model closed rows after T544; 56 backfilled with a
  recorded source, 96 marked `unattributed-pre-T544`; every per-model aggregator states
  its denominator and distinguishes attributed/backfilled/unattributed. Denominator:
  `docs/infra/managent/tasks.json`, closed partition.
- **S5 — dependency graph:** zero cases where a `blocked`/`fail-found`/`abandoned`
  close satisfies a `needs` edge; T535's gating is honest at Accept (blocked iff any
  needed row is not successfully done). Denominator: every needs edge in the store.
- **S6 — instrument honesty:** no fleet-wide commit lock from a malformed findings
  file (D7 write-path control green); directive IDs unique; `bin/dispatch` refuses or
  warns on a holds/store mismatch before spawning. Denominator: seeded fixtures, one
  per control.
- **S7 — no supervisor returns.** The diff at Accept adds no worker-watching process;
  the sweeper (if built) satisfies the three-guard testable line in §5.1. A new
  supervisor is a spec violation and fails Accept regardless of other results.
- **S8 — every phase gate passes with every finding dispositioned** (fixed /
  rejected-with-reason / escalated); the two-round audit cap is respected; each gate is
  a different model from its phase author (`CYCLE.md` model-assignment rule).
- **S9 — the ladder runs to bookend:** `spec → plan → scope → design → test → build →
  verify → accept`, one phase in flight (`CYCLE.md` rule 2), tests written before
  implementation, controls shown RED before the fix.

## 7. Honest open questions (survive the audit or be answered)

1. **Is one pass enough for 12 open defects?** This spec's honest read: G1+G3-L1
   (memory lifecycle + the D17 graph-lie) is a coherent pass; G2 (T544 backfill) and
   G4 (instrument honesty) are a second pass. The ladder's one-phase-in-flight rule and
   the serial holds on `src/managent/main.zig` and `tools/runner` make all four groups
   in one pass long. Recommendation: **pass1 = D17 + T548/D1 + D3 + D2/D12 + D14;
   pass2 = T544 + D13/D11 + D7/D10/D9 + the D5/D8 verification**. Escalation, not
   failure — the Plan phase owns the final split.
2. **Does the sweeper violate the no-supervisor rule?** Stated judgment in §5.1 with a
   testable line; the audit is invited to rule.
3. **Grandfathering of old verdicts.** Rows closed before the `verdict` field
   (pre-T213) may carry `verdict: null`; D17's `needsMet` must decide whether a null
   verdict on a done row satisfies (treat as pass) or blocks. Design-phase decision;
   the spec requires only that `blocked`/`fail-found`/`abandoned` never satisfy.
4. **D1's branch choice.** Real suspend/resume vs renaming the directive — the spec
   accepts either at the Accept gate; the Test phase cannot write both.
5. **T540's C-items.** They are catalogued but mostly unfixed (§1.3). If the Plan
   phase folds C1 (unknown flags) into the D10 work and C2 (keeper model list) into the
   T544 readers' work, the fleet gets them nearly free; otherwise they remain a
   standing debt census. Stated as a decision for Plan, not assumed here.
6. **Model assignment drift.** `CYCLE.md`'s model table assigns T549 to `dspro`
   (long-form authoring is where DS-Pro has least data), but the dispatch line and this
   row's `agent` field carry `deepseek-v4-flash`. Recorded in the findings file; the
   ledger comparison the table was designed for should know which model actually wrote
   this spec.

### 7.1 Note on citation drift

The inventory's line citations are a snapshot: `fleet-keeper.sh:247` (C2) is now line
286 in the tree, and `bin/subagent:260` (D5) is line 257-264 after T521's edit. This
spec cites the lines verified on 2026-08-20; a later reader should re-verify rather
than trust either document blindly — the L1 bar ("every gauge number reproducible by
the command the doc names") applies to this spec too.

---

**Landmark:** advances `L1 (the dashboard tells the truth)` — the spec that will be
judged by whether the fleet's instruments can report their own failure (D3 honest
deaths, D17 honest dependencies, D4 honest authors, D7 honest writes) and whether the
memory lifecycle (T548 reaping, D2 admission) keeps the fleet under its floor without
a single watcher process. What remains: an independent audit (T550), then the Plan
phase that owns the pass split and the file-hold schedule.

**Human summary:** the 17 catalogued tooling failures of 2026-08-20 collapse to 15
distinct defects in four groups — memory lifecycle (reaping, admission, honest death
classification, pause semantics), attribution (dispatch writes no model, directive-ID
collisions), row-lifecycle semantics (blocked closes satisfy dependencies, no
preconditions, misdiagnosed pressure, keeper depth), and instrument honesty (findings
validate-on-write, dispatch holder-checks). Three of the 17 are already fixed
(token capture, commit mutex, store locking); the sprint's open surface is 12 defects,
and the spec proposes a pass split (memory + dependency-graph honesty first, then
attribution + instrument honesty), with "fixed" defined as controls a Test phase can
build, not as prose. The torn-down supervisory stack stays torn down — the sweeper, if
built, is scoped as a resource collector with a testable line against becoming a
supervisor.
