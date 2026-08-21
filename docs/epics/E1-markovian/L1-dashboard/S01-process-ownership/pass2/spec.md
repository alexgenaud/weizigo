# Pass 2 — spec: `managent supervise`, one supervisor + one dispatch interface

**Artifact type: SPEC** (`docs/infra/sprint.md` — a spec says what we want, testably,
for one pass). **Owner:** deepseek-v4-pro/pass2-spec · **Rev 2 author:**
`claude-opus-5`/pass2-spec-fix · **Date:** 2026-08-21 · **Status:** PROPOSED (rev 2 —
audit disposition closed, awaiting re-audit); not a worker brief, not a plan, no code.

**Citation pinning (F11).** Every `file:line` in this document is pinned to commit
`56b9cf1`. `docs/infra/managent/tasks.json`, `tools/regression-suite-surfaces.sh` and
`tools/suite-truth.sh` were dirty at authoring time; no line-numbered citation is taken
from them. A citation that no longer resolves at `56b9cf1` is a spec defect, not a
reader's problem.

**Inputs:** the seed brief `docs/status/refactor-roadmap-2026-08-20.md` (target + the
"held, not inferred" root cause + the cannibalization pattern); the pass-1 spec
`pass1/spec.md` (treekill contract, §7 one-dispatch-interface shaping, §6 kill sites
C1–C6, §8 non-goals); the deferred register in `docs/status/ROADMAP-2026-08-21.md`
(B-7..B-11 + `ollama stop`); `pass1/audit-build-disposition.md` (B-7..B-11 verbatim);
`pass2/audit-disposition.md` (F1–F11, all ACCEPT — the rev-2 mandate);
`docs/status/orchestration-layer-spec.md` §7.2 and §7.5 (the operator's own words on
appetite-as-a-spectrum and mint safety);
`S02-model-delegation/measurement-methodology.md` §1 (the appetite table this pass
replaces the *levels* of, not the *numbers* in).

**Scope.** One long-lived mode of the existing binary — `managent supervise` — that
**holds** every worker it dispatches as a direct child and never detaches, replacing
`tools/fleet-keeper.sh`, `bin/dispatch`, `bin/subagent`, `tools/runner` (dispatch role),
`tools/dispatch_verify.py`, and `tools/fleet-cooldown.sh`. Plus: the one dispatch
interface (pass-1 §7) — Pi and Claude dispatch through the same command; the per-family
**appetite dial** (§4); **runaway/recursion safety** (§5); the `ollama stop` per-family
release (Could, §6); and the pass-1 deferred treekill findings B-7..B-11 (§7).
This document is the spec; controls are named, not written; no code.

---

## Changelog — rev 1 → rev 2

Rev 2 closes `pass2/audit-disposition.md` F1–F11 (all ACCEPT) and folds the two operator
refinements. HOLD-1..5 are **unchanged in force**; the audit verified them sound and rev 2
does not weaken them. What changed:

| # | change | where |
|---|---|---|
| F1, F2 | HOLD-6 was false as written — `tools/runner` still writes run records and heartbeats (`task_identity` from `MANAGENT_TASK_ID`, `tools/runner:1385`), so single-writer is a **path** property, not a parenthood property. HOLD-6 is split into **HOLD-6a** (path-partitioned dispatch run records), **HOLD-6b** (single-writer read-modify-write state), **HOLD-6c** (enumerated append-only writers, atomicity asserted). The seed's Pass-5 store migration stays a non-goal and is now stated as a **deferral, not a claim** | §1, §9 |
| F3 | DP-4's "no family-specific verify branch" forbade the one branch the tree needs — the claude JSON usage envelope. New **DP-5** adopts the flag-keyed seam by name (`tools/runner:1041-1051`, "by the flag pair, not the binary name"): decoding keys on the launch template's `output_format` field, never on family | §3 |
| F4 | `tools/fleet-keeper.sh:286-287` holds 5 of the 10 canonical labels (the F7/T503 defect). DP-2 now pins `canonical_models[]` (`src/managent/main.zig:115-126`) as the single source, and **DP-6** is a gate that fails on a *second* list — with the residual non-dispatch holders enumerated and count-pinned, so a new list is red | §3 |
| F5 | DP-3's gate was **exclusive** (grep everything minus the data tables), which inverts pass-1's *inclusive* sentinel sweep — the form that shipped and works (T556 acceptance, `pass1/plan.md:173-174`). DP-3 now uses the inclusive `awk`-region form, strips comment lines (so `\bpi\b` cannot trip prose), and carries a seeded-defect control | §3 |
| F6 | The launch-template table did not exist. It is now written out per family — argv, `output_format`, release path, launched-tag rule — transcribed from `bin/subagent:247-272`. It **is** the data-not-code deliverable | §3 |
| F7 | Arm B-7 passed via a pass-1 **G3** refusal, not the downward rule. Refuse-vs-exclude is now pinned (**exclude-and-report** for a third-party upward seed; **exit 4** stays only for the verb's own ancestry, G3 unchanged) and the seed is constructed outside the verb's ancestry | §7 |
| F8 | `tools/fleet-keeper.sh` has **six** state files; rev 1 migrated one. All six are now enumerated with their after-state, and `tools/regression-fleet-keeper.sh` is cited as the golden-master characterize arm | §2.4, Controls |
| F9 | S9 did not pin the tag. The release now asserts the **launched** tag (`ollama launch pi --model glm-5.2:cloud` ⇒ `ollama stop glm-5.2:cloud`), not the canonical label, with the `ollama ps` route named as the pinned fallback | §6 |
| F10 | HOLD-1's "no detach anywhere" cannot hold for ollama — the model is daemon-owned. HOLD-1 is scoped to the **supervisor's own spawn mechanics**; daemon-owned residency is a named exception discharged by §6 | §1 |
| F11 | Rev 1's cannibalization set collided with pass-1 §6's kill sites C1–C6. Renamed **CAN-1..CAN-7**; all citations commit-pinned | §8, header |
| op. (a) | **Appetite is a 0–99 dial per family**, replacing the static `OFF/PROBE/CONSERVE/SPEND/RESERVED` levels. 0 = hard forbid, 99 = full spend, everything between is mechanized back-pressure. Who may turn it and how a window reset is *observed* are both specified. New **Must** | §4 |
| op. (b) | **Runaway/recursion safety** — mint-delta check, one-author-per-mint, lineage + justification on every queued row, enforced at the store write. New **Must** | §5 |

**Owed follow-up (not this deliverable).** `pass2/scope.md`'s MoSCoW table predates §4 and
§5 and must gain two Must rows; its cut order must gain the never-cut entries from §10.
Flagged rather than silently edited — scope.md is a separate artifact and the rev-2
mandate names spec.md.

**Section numbering is stable where it is cited.** `S03-queue-layer/spec.md` cites this
document's §2.1, §2.5 and §3; all three keep their numbers. §4 and §5 are inserted after
§3, pushing the former §4–§9 down by two.

---

## 1. What "held" means, testably

Pass 1 defined "owned" as a *verb* (`treekill`): ownership asserted by process-table
observation after the fact. Pass 2 defines "held" as a *relationship that exists from
spawn*, so nothing has to be re-inferred afterwards. The root cause the seed names is
that today ownership is **inferred** — `bin/dispatch:301` detaches (`start_new_session=True`),
prints "dispatched", and every downstream component re-establishes ownership by scanning
`ps`, polling the kanban, and writing run records. Inference has an unclosable window
between spawn and observation. "Held" closes it by construction: the supervisor is the
**parent**, so the child's death is a `waitpid`/`SIGCHLD` event, not a poll.

Assertions, each assertable by a control (§Controls) with an oracle independent of the
supervisor's own counters:

- **HOLD-1 (no detach on the supervisor's spawn path).** Every process the supervisor
  *itself spawns* is a direct child — `ppid(worker) == supervisor_pid` — and shares the
  supervisor's session (`getsid(worker) == getsid(supervisor)`). No `setsid`, no
  `start_new_session`, no `nohup`, no double-fork anywhere on the dispatch path. → Arm S1.

  **Named exception (F10): daemon-owned family residency.** HOLD-1 is a property of the
  supervisor's spawn mechanics, not a claim about every process a family's work causes to
  exist. The ollama family's heavy process — the resident model — lives in the
  pre-existing `ollama serve` daemon and is never a descendant of anything the supervisor
  spawns; the supervisor's direct child is the `ollama launch pi` client
  (`bin/subagent:271-272`). HOLD-1 therefore asserts *no detach primitive on the spawn
  path* and *direct parenthood of every spawned process*; it does not assert that the
  family's whole resource footprint is inside the held tree. That footprint is released
  by §6, and §6's absence is a *measured leak*, not a HOLD-1 failure. The distinction is
  load-bearing: conflating them is what made rev 1's HOLD-1 unfalsifiable for one family.
- **HOLD-2 (direct death observation).** The supervisor learns of a worker's exit through
  `waitpid`/`SIGCHLD`, never by polling `ps`/`pgrep`. Mechanized: the death-observation
  path contains no `ps`/`pgrep`/process-table read; and a killed worker's run record is
  finalized within a bounded latency (≤ 2 s) after the kill. → Arm S2 (both prongs).
- **HOLD-3 (containment).** On every worker exit — normal, guard-kill, exception — the
  supervisor invokes `treekill --anchor <worker pid> --kill --seed <last poll walk>
  --since <spawn epoch>`, and pass-1's OWN-1..5 hold for the supervisor's kill paths.
  The seed list is the supervisor's own poll walk (today `tools/runner`'s
  `_descendant_pids_ps` at `tools/runner:629`, selected into `_WALKER_FN` at `:667`,
  called at `:1559` — drifted from pass-1's `:609`/`:1402` as the tree moved), promoted
  to persist past the poll loop — the same property pass-1 §6 C2 required of the runner,
  now owned by the supervisor.
  → Arms S3, S4.
- **HOLD-4 (the supervisor itself never detaches).** `managent supervise` runs foreground:
  `ppid(supervisor) == its launcher`, no new session, no double-fork. There is no "run the
  supervisor detached" flag; a caller that wants it detached runs it under `tools/runner`
  or `nohup` itself. → Arm N3.
- **HOLD-5 (single instance).** A second `managent supervise` while one is live exits
  non-zero naming the holder (an `flock` on a lock file, the same primitive `treekill`
  N4 and managent's store lock already use). → Arm N2.

### 1.1 HOLD-6 — single writer, corrected (F1, F2)

Rev 1 asserted: *"Every run record, heartbeat line, perf line, and heal record is written
by the one supervisor process… because the supervisor holding all children makes it the
only writer."* **That inference is false, and the audit is right to call it a must.**
Parenthood does not confer write exclusivity. `tools/runner` survives this pass in its
standalone build-guard role (§10.1) and that role *still writes*: it derives
`task_identity` from `--task-id` or `MANAGENT_TASK_ID` (`tools/runner:1385`), writes
`untracked/runs/<sanitized-identity>.json` (`_run_record_path`, `tools/runner:368-369`;
`_write_run_record`, `:372-382`; `_finalize_run_record`, `:398-458`), and appends
heartbeats to `untracked/heartbeat.jsonl` (`_emit_heartbeat`, `:463`, called at `:983`,
`:1419`, `:1752`, `:1771`, `:1805`). An agent running `tools/runner --task-id T557 -- zig
build` in-session writes the *same path* a supervisor holding a T557 dispatch would write.
Single-writer is a **path** property.

HOLD-6 is therefore split into three claims, each with its own control, and each claiming
only what its mechanism holds:

- **HOLD-6a (dispatch run records: single writer by path partition).** The supervisor is
  the only writer of `untracked/runs/<T-id>.json` for any `<T-id>` that is a kanban row.
  The residual writer is partitioned *by path*, not by convention: the standalone
  build-guard role writes under `untracked/runs/build/<sanitized-identity>.json`. The
  permitted-writer set is **closed and enumerated** — {the supervisor, for dispatch
  identities; `tools/runner`'s build-guard role, for build identities} — and a third
  writer is a spec violation, not a surprise. → Arm S6a: run a supervisor-held dispatch
  for `T<n>` and an in-session `tools/runner --task-id T<n> -- <stub build>` concurrently;
  assert **two distinct files**, both well-formed and both finalized, and that neither
  path is ever opened by the other writer (mechanized: an `fs_usage`-free check —
  each writer's own path prefix is a compile-time constant, gated by grep).
- **HOLD-6b (read-modify-write state: genuinely single writer).** The T545 class — *"5 of
  24 writers unlocked; a counter observed running backwards"* — is a **read-modify-write**
  defect, and read-modify-write state is where exclusivity actually matters. Every one of
  the six fleet state files (§2.4) is written by the one supervisor process and by nothing
  else, because the only other writer, `tools/fleet-keeper.sh`, is deleted (CAN-5).
  → Arm S6b: two supervisors race for the lock (HOLD-5 admits one); the survivor's
  pressure/attempts counters advance monotonically; the mutation control (disable the
  `flock`) drives a counter backwards, red.
- **HOLD-6c (append-only shared logs: writers enumerated, atomicity asserted).**
  `untracked/heartbeat.jsonl` and `docs/infra/dispatch-heals.jsonl` remain **multi-writer
  by design** — the supervisor plus the residual build-guard runner. Exclusivity is not
  claimed. What *is* claimed and controlled: every write is a single `O_APPEND` `write(2)`
  of one newline-terminated line under the platform's atomic-append threshold, so
  concurrent appenders can interleave *lines* but never *within* a line. → Arm S6c: N
  concurrent appenders (supervisor + runner + a stub) emit K lines each; assert
  `N×K` lines, every line independently JSON-parseable, zero torn records. A torn line is
  a FAIL. This arm is the null control that says *what multi-writer costs us* — the
  honest answer being "line order", which no reader depends on.

**What HOLD-6 no longer claims (F2).** The seed's Pass 5 — moving run records and
heartbeats *into* the store, under the store lock — is **deferred and stays deferred**
(§9). Rev 1 substituted an assertion for that migration; rev 2 does not. HOLD-6a/b/c hold
by path partition, by deleting the competing writer, and by append atomicity — three
mechanisms that are each cheap and each testable. They do **not** deliver
single-lock-serialized durability, and the difference is exactly the deferred pass. Stated
here so no later reader mistakes the partition for the migration.

"Held" is asserted by process-table observation and by the *absence of inference code
paths*, never by the supervisor's own counters (standing rule: impossibly clean counters
are red flags).

**Non-condition.** "No orphans on the host, ever." A SIGKILLed supervisor reaps nothing —
nothing downstream of it runs. Its children reparent to init and are orphans, exactly as
pass-1 scoped the runner-death case to T548. Held handles close the *unowned-detach*
window; they do not make the supervisor immortal. Stated, not hidden (§9).

---

## 2. The supervisor's contract

**Name: `managent supervise`.** One verb, two shapes — the long-lived loop (no job
argument) and the oneshot dispatch (a job argument). Both are the one dispatch interface
(§3). Not "fleet-keeper", not "daemon", not "reaper" — the seed's own words: *one
supervisor*.

```
managent supervise                           # long-lived: hold the fleet, keep it full
managent supervise --once                    # one scheduling iteration, then exit (test hook;
                                             #   = tools/fleet-keeper.sh --once today)
managent supervise <id> <model> [flags]      # oneshot: hold ONE worker to completion,
                                             #   verify the work, exit with the verdict
managent supervise cooldown on|off|status    # graceful stop control (replaces fleet-cooldown.sh)
managent supervise stop                      # hard stop: treekill every held child, then exit
managent supervise status [--json]           # the held-children list (NOT the full fleet view —
                                             #   that is a later read-only pass)
managent appetite <family> [<0-99>]          # read / set the appetite dial (§4; operator-only write)
managent appetite --window <family> <record> # assert an observed credit window (§4.3)
```

The `<id> <model>` form is the dispatch interface (§3). The no-argument form is the
fleet-fill loop that replaces `tools/fleet-keeper.sh`. One binary, two modes — the seed's
target line verbatim: "`supervise` is long-lived; every other verb stays a short-lived
CLI against the same store, lock and code."

### 2.1 The loop it runs (fleet-fill, replacing fleet-keeper)

Carried from `tools/fleet-keeper.sh` with **no behaviour invention** — the eligibility
ordering (waiting=1 first, then priority desc, then `added` ascending), the one-writer
invariant (never dispatch a task whose `holds` intersect a running task's `holds`), the
logjam-PRESSURE state machine (anchor / drops / effective cap), the heal-cooldown
(T504), the pre-claim-death backoff + per-model lane circuit breaker (T536), and the
model allow/deny window (D022/D036). What changes is **only** the mechanism underneath:
instead of `fire()` shelling out to `bin/dispatch` (which detaches and prints a pid), the
loop *spawns the worker as its own child and holds the handle*. The "at cap" / "cooldown"
/ "no conflict-free candidate" branches are unchanged in meaning; they now simply do not
spawn.

**Two new admission gates, evaluated before any spawn** (both are Musts folded in rev 2,
both are *gates on an existing decision point*, not new policy machinery):

1. the **appetite dial** for the candidate's family (§4) — hard-forbid at 0, lane share
   and dispatch spacing in between;
2. the **runaway/recursion checks** for the candidate row (§5) — lineage depth,
   justification present, mint-delta breaker not tripped.

Every refusal carries a **named reason string** (`appetite-forbid`,
`appetite-lanes-exhausted`, `appetite-spacing`, `mint-breaker`, `lineage-depth`,
`lineage-cycle`, `no-justification`, plus the carried `holds-conflict`, `at-cap`,
`cooldown`, `backoff`, `lane-down`, `heal-cooldown`). Reason strings are the observable
the controls read — a refusal that reports no reason is indistinguishable from a bug, and
a queue that reports success while doing nothing is the named recurring defect
(`docs/status/orchestration-layer-spec.md` §3).

**The one bug this mode is specified to make unexpressible** (the seed's Red): the keeper
re-fired a row 80 times in 3.5 minutes because it could not see its own in-flight work —
the window between `bin/dispatch` printing `dispatched` and the worker's `claim` writing
the store. A held supervisor knows its children from spawn; a row it is already holding
is excluded from eligibility by the in-memory child set, *before* the store moves. → Arm
S5 (a stub worker that claims slowly; assert the row is fired exactly once).

### 2.2 The guards it runs (replacing tools/runner's dispatch role)

The supervisor runs the same guards `tools/runner` runs today for a dispatched worker.
Post-pass-1 the runner already kills via `treekill` at its C1–C4 sites, so the kill
primitive is *inherited, not re-invented* — the supervisor calls `treekill --anchor
<held child pid> --kill --seed <its poll walk> --since <spawn>` exactly as the runner
does. What pass 2 changes is **where the guard loop lives and what it holds**: it moves
out of the detached, unowned Python runner and into the supervisor — the process that is
the worker's parent — and the worker is held as a direct child in the supervisor's
session, not a `setsid`'d session-leader child of an intermediary.

**The one red the guard loop as a whole makes testable** (carried from the seed): the
guards today run in a process that is itself detached and unowned — `bin/dispatch`
nohups `bin/subagent`, which runs `tools/runner`, and `bin/dispatch` then exits, leaving
the whole guard-and-worker chain reparented to init. A runner death leaves the worker
unguarded *and* unowned, and there is no held parent to observe it. In the supervisor
that state is unexpressible: the supervisor is the parent (HOLD-2); if it dies, SUP-STOP-2
kills the worker or SUP-STOP-3 counts it. → Arm S2.

| guard | today (runner, post-pass-1) | after (supervisor) |
|---|---|---|
| RSS cap | poll; `treekill --anchor <child> --kill` at the cap | poll its held child; same `treekill` |
| host-memory floor | `treekill --anchor <largest_pid> --kill` (pass-1 C4) | same |
| wall / CPU ceiling | `treekill` on breach | same |
| progress watchdog | `treekill` on silence | same |
| directive poll (`tell <id> pause\|kill`) | read `directives.jsonl`; `treekill` its child | read the same; `treekill` its held child |
| heartbeat | `_emit_heartbeat` → `untracked/heartbeat.jsonl` (`tools/runner:463`) | supervisor appends the same lines; the runner's build-guard role keeps appending too — **enumerated multi-writer, HOLD-6c** |
| dispatch run record | `untracked/runs/<identity>.json` (`tools/runner:368-369`) | supervisor is the sole writer of `untracked/runs/<T-id>.json`; the build-guard role moves to `untracked/runs/build/` — **HOLD-6a path partition** |

The `zig` ReleaseFast injection and the `--sweep` listing stay with the Python runner:
they belong to an agent's *in-session* `tools/runner -- zig build`, not to a dispatch
(§9). The supervisor's held worker is a harness process (`pi` / `claude` / `ollama launch
pi`), never a bare `zig` command.

### 2.3 Verify + heal (replacing dispatch_verify + bin/subagent's postlude)

The T411 verification — nonce echo, declared deliverables exist, kanban row left closed,
findings parse — runs **inside the supervisor, in the same held process**, immediately
after the worker exits, on the captured stdout. The T538 provider-refusal classifier and
the T520 wall-kill advisory are carried unchanged. The T477 heal (reopen a row the
supervisor watched die with `rc != 0`) is carried unchanged, with its sole-owner marker
(`healed_by = "dispatcher"`; the supervisor is now that sole owner — T513).

**One decode step precedes verification, and it is not family-keyed** — see DP-5 (F3).
The captured stdout of a lane that declared `output_format = json-envelope` is unwrapped
to its text payload *before* the nonce/deliverables checks run; every lane's checks then
run on text. The unwrap is selected by the launch template's field, never by a family
token, so DP-3's gate still passes over the region.

The red this closes: today verification is a *separate detached process* (`bin/subagent`
is the nohup'd child of `bin/dispatch`); a crash between worker-exit and verify loses the
verify. Held inline, the verify is the same process that watched the worker — there is
no gap to crash into. → Arm S6 (a stub worker that echoes the nonce but leaves the row
open → verify fails, heal fires, all in one process).

### 2.4 Cooldown and the six state files (F8)

`tools/fleet-keeper.sh` keeps **six** pieces of state, not one. Rev 1 migrated the
cooldown flag and was silent on the other five — a behaviour-preserving swap that drops
five files is not behaviour-preserving. All six, with their after-state:

| # | file (`tools/fleet-keeper.sh` pin) | today | after |
|---|---|---|---|
| 1 | `untracked/fleet-keeper.cooldown` (`:136`) | file flag toggled by `tools/fleet-cooldown.sh` | store/directive field, read atomically; `managent supervise cooldown on\|off\|status` |
| 2 | `untracked/fleet-keeper.pressure.json` (`:139`) | logjam anchor / drops / `waiting_since` | supervisor-owned state, same schema, same transitions (T500's algorithm is the authority) |
| 3 | `untracked/fleet-keeper.logjam.flag` (`:140`) | operator-visible logjam signal | supervisor-owned; surfaced by `supervise status` |
| 4 | `untracked/fleet-keeper.heal.json` (`:145`) | T504 per-row heal cooldown | supervisor-owned, unchanged semantics |
| 5 | `untracked/fleet-keeper.attempts.json` (`:149`) | T536 pre-claim backoff, per row and per model | supervisor-owned, unchanged semantics |
| 6 | `untracked/fleet-keeper.lane-down.json` (`:150`) | T536 benched-lane census (telemetry) | supervisor-owned, unchanged semantics |

`docs/infra/dispatch-heals.jsonl` (`:146`) is **not** in this list: it is T477's shared
append-only heal record, and it stays multi-writer under HOLD-6c. `untracked/log/fleet-keeper.log`
(`:137-138`) becomes the supervisor's own log; log rotation is out of scope.

Files 2–6 are read-modify-write state — the HOLD-6b class, and the reason HOLD-6b is the
claim that carries weight. Migration is behaviour-preserving: **same schema, same
transitions, same file paths** unless a rename is separately justified, so
`tools/regression-fleet-keeper.sh` (1,262 lines, the tested asset) can serve as the
golden-master characterize arm without being rewritten (Controls, arm G1).

Cooldown semantics preserved: cooldown-on dispatches nothing new, running workers finish;
cooldown-off resumes. The dead-man's switch (missing `untracked/` → treat as cooldown) is
**retired**: it was a property of inference-by-scanning, and a held supervisor has no
scanning to fail closed on — but its *fail-safe direction* is preserved as: an unreadable
store ⇒ dispatch nothing (loud), never a free-for-all.

### 2.5 Shutdown semantics — three cases, all testable

- **SUP-STOP-1 (graceful).** `cooldown on`, then wait: no new spawns; each held child
  runs to completion; when the last child exits the supervisor exits 0. → Arm S7.
- **SUP-STOP-2 (hard).** SIGTERM/SIGINT, or `managent supervise stop`: `treekill` every
  held child (anchor = each child pid), settle, exit 0. Zero live descendants of any held
  child afterwards. → Arm S8.
- **SUP-STOP-3 (crash).** SIGKILL: nothing runs; children reparent to init and are
  orphans. Residual, counted by the sweep (T548), not healed here — the exact pass-1
  runner-death non-goal, restated for the supervisor. → Arm N1 documents the shape only.

---

## 3. One dispatch interface (pass-1 §7, built)

Operator requirement (2026-08-20): Pi harness and Claude Code dispatch through **the
exact same command**. Pass 1 shaped it (family-independent inputs; the anchor is the
interface; variation in data; multi-root composition). Pass 2 builds it. The command is
`managent supervise <id> <model>`.

- **DP-1 (one command, no per-harness scripts).** `bin/dispatch` and `bin/subagent` are
  reduced to, then removed as, dispatch paths. The only dispatch command is
  `managent supervise <id> <model> [--wall N] [--rss-cap-mb N] ...`. The same argv,
  spelling, and exit codes for a DeepSeek, an Ollama, and a Claude worker.
- **DP-2 (one canonical model list; family variation is data, not code).** The canonical
  labels are the single source: `canonical_models[]` at `src/managent/main.zig:115-126`,
  exposed by `managent models` (`src/managent/main.zig:334-337`, `:5161-5190`). Every
  other consumer **queries the verb or reads the fenced region — it never restates the
  labels.** The launch template (§3.1) is keyed by the label and lives in its own fenced
  data region beside it. A new family or model is a table row, not a branch and not a
  second list.
- **DP-3 (mechanized family-token gate — inclusive sentinel form, F5).** Rev 1 specified
  an *exclusive* gate (grep the file, minus the data tables). That inverts the form that
  shipped and works. The T556 acceptance predicate (`pass1/plan.md:173-174`) is
  **inclusive**: `awk` selects the region *between two sentinel comments*, and the grep
  runs on that selection only:

  ```sh
  awk '/^\/\/ ── supervise: dispatch\/input region/,/^\/\/ ── end supervise dispatch\/input/' \
      src/managent/main.zig |
    grep -v '^[[:space:]]*//' |
    grep -qiE 'claude|deepseek|ollama|qwen|glm|minimax|kimi|(^|[^a-z])pi([^a-z]|$)' && exit 1 || true
  ```

  Three properties rev 1 lacked: (i) the region is *selected in*, so a token outside it is
  irrelevant by construction and the gate cannot be defeated by moving code; (ii)
  `grep -v '^[[:space:]]*//'` strips comment lines, so `\bpi\b` in prose cannot trip the
  gate while `pi` as an argv literal still does — the audit's exact objection; (iii) the
  region is delimited by **emitted sentinel comments**, the same primitive pass-1 §7.1
  already pinned for `treekill`, so `canonical_models[]` and the launch-template table sit
  *outside* the selection and need no exclusion clause. The two pass-1 treekill sentinels
  stay as they are. **Control:** arm D1 seeds a family branch inside the region and
  asserts the gate goes red; arm D1-null asserts the gate is green on the shipped tree.
  A gate that has never gone red has not been read (never trust a green test).
- **DP-4 (same verification for every family).** The §2.3 verify logic runs identically
  whatever the family: the nonce is in the shared prompt, the deliverables and the kanban
  row are family-independent ground truth. No family-specific *verification* branch is
  permitted. Rev 1 stopped here and thereby forbade the one branch the tree needs; DP-5
  is the correction.
- **DP-5 (the decode seam is flag-keyed, not family-keyed — F3).** Verification runs on
  **text**. One family's harness does not emit text: `claude -p … --output-format json`
  emits a usage envelope that must be unwrapped first (`bin/subagent:266-269`). The seam
  is already solved in the tree, by name, and pass 2 adopts that design rather than
  inventing one: `tools/runner:1041-1051`, `_json_output_lane(argv)` —

  > *"Detection is by the flag pair (`--output-format json`), not the binary name, so any
  > shim or future claude driver that emits the envelope is captured; a lane that does not
  > opt in is teed but never parsed."*

  In pass 2 the flag pair is not sniffed out of argv — it is **declared** by the launch
  template's `output_format` field (§3.1), which is the same seam made explicit: the
  decoder is selected by a data field whose domain is `{text, json-envelope}`. Adding a
  family that emits an envelope is a table row. Adding a *third* envelope shape is a new
  domain value plus one decoder — a bounded, named extension point, not a family branch.
  DP-3's gate passes over the decode code because it contains no family token. **Controls:**
  arm D2 (a `json-envelope` stub lane: nonce found *after* unwrap, token counts and the
  T552 session handle captured); arm D3 (a `text` stub lane declaring `json-envelope`:
  decode fails **loudly** with a named reason, never silently falls through to a
  nonce-not-found verdict — the two failures must be distinguishable); arm D4 (mutation:
  force the decoder to `text` for every lane ⇒ D2 goes red).
- **DP-6 (a gate that fails on a second model list — F4).** DP-2 is a claim; DP-6 is what
  makes it hold. The measured state at `56b9cf1` is worse than "four definitions": seven
  non-test files carry two or more canonical labels as literals —
  `src/managent/main.zig` (canonical, 10 labels), `bin/dispatch:76-88` + `:91-94` (`MODELS`/`ALIASES`,
  10), `bin/subagent:57-62` + `:69-80` (`CLAUDE_MODELS` + `OLLAMA_TAG_TO_CANONICAL`, 10),
  `tools/fleet-keeper.sh:286-287` (**5 of 10** — the F7/T503 defect: a "known canonical
  set" that silently omits every Claude label and `qwen3.8:27b-mlx`, so T503's
  exploration-first chooser can never pick them), `tools/token-capture.py:82…` (10),
  `tools/model-profiles.py:136…` (10), `tools/bakeoff.sh:112…` (10).

  Pass 2 deletes three of them — `bin/dispatch` (CAN-2), `bin/subagent` (CAN-3),
  `tools/fleet-keeper.sh` (CAN-5) — which is the whole dispatch path. The other three are
  outside this pass's scope (`token-capture.py` is the runner's token parser;
  `model-profiles.py` and `bakeoff.sh` are measurement tooling, the seed's Pass 4
  territory). The gate is therefore an **enumerated, count-pinned allowlist**, not a
  blanket ban:

  ```sh
  # Every file holding ≥2 canonical labels as literals must be in the allowlist.
  # Allowlist at 56b9cf1 after pass 2: src/managent/main.zig (the source),
  #   tools/token-capture.py, tools/model-profiles.py, tools/bakeoff.sh (Pass-4 debt,
  #   registered), plus tools/regression-*.sh fixtures (test data, not definitions).
  ```

  Three predicates, all mechanized: (i) the allowlist is exact — a file outside it holding
  ≥ 2 labels is a FAIL; (ii) each allowlisted residual holder's label count is **pinned**,
  so adding a label to a copy fails until the pin is updated with a reason (the
  `_WALKER_FN`-count discipline from `pass1/plan.md:171-172`, reused); (iii) the three
  deleted copies are asserted **gone**, not merely unused. **Control:** arm D5 seeds a
  new 3-label list in a fresh file and asserts the gate goes red; arm D5-null asserts
  green on the post-pass tree. The Pass-4 debt is *registered, not hidden*: three residual
  holders, named, with the pass that closes them.

  This is the honest form. A gate claiming "exactly one list exists" would be false on the
  first run and would be disabled by the second week.

### 3.1 The launch-template table (F6) — the data-not-code deliverable

Rev 1 promised this table and did not write it. It is the deliverable, not an add-on: DP-2
is unfalsifiable without it. Transcribed from `bin/subagent:247-272` at `56b9cf1`, one row
per family. `<prompt>` is the single shared prompt builder's output (nonce + orient
preamble + deliverables + inbox loop, exactly as `bin/subagent` assembles it today);
`<m>` is the canonical label; `<tag>` is the family's launched tag (see the tag rule).

| field | deepseek | claude | ollama |
|---|---|---|---|
| `family` | `deepseek` | `claude` | `ollama` |
| `labels` | `deepseek-v4-pro`, `deepseek-v4-flash` | `claude-opus-5`, `claude-sonnet-5`, `claude-fable-5`, `claude-haiku-4-5-20251001` | `glm-5.2`, `minimax-m3`, `kimi-k2.7`, `qwen3.8:27b-mlx` |
| `argv` | `pi --provider deepseek --model <m> -p <prompt>` | `claude -p <prompt> --model <m> --allowedTools <tools> --output-format json` | `ollama launch pi --model <tag> -y -- -p <prompt>` |
| `argv source` | `bin/subagent:247-251` | `bin/subagent:266-269` | `bin/subagent:271-272` |
| `output_format` | `text` | `json-envelope` (DP-5) | `text` |
| `launched tag rule` | tag == label | tag == label | tag ≠ label: the launched tag is the raw `--model` value (`glm-5.2:cloud`), mapped to the canonical label for the ledger by the table's `tag → label` column (today `OLLAMA_TAG_TO_CANONICAL`, `bin/subagent:69-80`) |
| `preflight` | `DEEPSEEK_API_KEY` present (`bin/subagent:237-239`) | none | tag resolvable |
| `release` (§6) | none | none | `ollama stop <launched tag>` |
| `env` | `MANAGENT_TASK_ID`, `WEIZIGO_AGENT_DEPTH+1` | same | same |

Three properties the table must have, each gate-able: the `argv` column is a **template
string**, so a family is added by appending a row (arm D6: add a synthetic 4th family row
pointing at a stub binary; assert a dispatch through it works with **zero** source changes
outside the table); the `tag → label` map is **in the table**, so the `:cloud` suffix
never appears in ledger or store rows (arm D7); and the table lives in its own
sentinel-fenced region, outside DP-3's selection.

---

## 4. Appetite — a 0–99 dial per family (operator refinement (a); **Must**)

**Operator requirement (2026-08-21):** *"Appetite — a spectrum, not one gate. Hard: forbid
a model/family outright. Soft: subtle or strong back-pressure"*
(`docs/status/orchestration-layer-spec.md` §7.2), with the intent: **slow down with Claude
and speed up with Ollama as token/credit windows approach and reset.**

The static levels `OFF < PROBE < CONSERVE < SPEND < RESERVED`
(`S02-model-delegation/measurement-methodology.md:23`) are **replaced** by a continuous
integer dial per family. The levels' defect is not that they were wrong; it is that a
five-valued enum cannot express "a bit less than yesterday", so every real adjustment
became a doc edit, and one of the five values (`RESERVED`) was never on the same axis at
all (§4.5).

### 4.1 The dial

`appetite(f) ∈ {0, 1, …, 99}`, one integer per **family** (not per label — families share
a credit pool, which is the thing being rationed). Families at `56b9cf1`: `claude`,
`claude-fable` (a separate pool by the 200 k boundary), `deepseek`, `ollama-cloud`,
`local`.

- **`0` = hard forbid.** Checked *first*, before any arithmetic, and refused with reason
  `appetite-forbid`. Not back-pressure, not a small number — a floor.
- **`99` = full spend.** No spacing, full lane cap. No back-pressure of any kind.
- **`1..98` = mechanized back-pressure**, never a disguised off (§4.2).

**The extremes are the safety property.** `0` must be unliftable by any automatic process
(§4.4) and `99` must be reachable only by an operator assertion. Everything between is
policy; the ends are structure.

### 4.2 What the dial mechanically does

Two effects, both monotone in the dial, both computed from operator-set per-family
constants (`lane_cap(f)`, `spacing_max(f)`), both observable in the store:

```
lanes(f)   = 0                                  if appetite(f) == 0
           = max(1, round(appetite(f) * lane_cap(f) / 99))    otherwise
spacing(f) = round(spacing_max(f) * (99 - appetite(f)) / 98)  seconds, for appetite(f) >= 1
```

- `lanes(f)` caps the family's concurrent held children. It is a **second cap**, below the
  fleet-wide effective cap; the lower of the two binds. Refusal reason
  `appetite-lanes-exhausted`.
- `spacing(f)` is the minimum wall time between two consecutive dispatches to the family.
  At 99 it is 0 s; at 1 it is the full `spacing_max`. Refusal reason `appetite-spacing`.
- `max(1, …)` is deliberate: any nonzero dial permits **at least one lane**. A dial of 1
  means "one lane, maximally spaced" — visibly throttled, not silently off. The only off
  is `0`, and it says so.

No randomised admission. The dial must not perturb the eligibility *ordering* — ordering
is S03's concern (`S03-queue-layer/spec.md` §2.1) and a probabilistic gate would make
S03's aging property untestable. The dial changes *how many* and *how often*, never
*which*.

### 4.3 How a window reset is **observed** (not inferred)

The standing rule: a status carries an author and a timestamp, later supersedes earlier,
and **the absence of an assertion is UNKNOWN, not "none"**. Applied to credit windows:

Each family carries a window record: `{kind: rolling|weekly|none, resets_at, remaining_frac,
observed_at, author, source}`. Three states, and the clamp each implies:

| state | when | `appetite_auto(f)` |
|---|---|---|
| `OBSERVED` | an assertion exists with `observed_at` inside the current window | computed from `remaining_frac` by the operator-set curve |
| `ASSUMED_RESET` | wall clock passed `resets_at`, no fresh assertion since | **held at the pre-reset value** — the machine does not speed up on a prediction |
| `UNKNOWN` | last `observed_at` older than one window length, or never | clamped to `appetite_floor(f)`, an operator-set conservative default — **not 0** (that would be inferring non-existence) and **not 99** |

Two admissible observation sources, both dated and authored:

1. **an operator assertion** — `managent appetite --window <family> <record>`, author =
   the operator, `source = operator`;
2. **a provider-reported figure captured at dispatch** — the `json-envelope` usage payload
   DP-5 already decodes carries the numbers; the supervisor records them with
   `observed_at = <the dispatch's exit time>`, `source = envelope`, `author = <the held
   worker's identity>`. This is why DP-5 and §4 are one pass: the decode seam is the
   observation channel.

**Wall-clock crossing `resets_at` is a prediction, never an observation.** It moves the
family to `ASSUMED_RESET` and changes nothing else. A window that "should have reset" and
did not is exactly the case that burns credits, and it is unobservable from the clock.

→ Arms A3, A4, A5.

### 4.4 Who may turn the dial

Three writers, strictly ordered:

- **The operator sets `appetite_operator(f)`.** The authority. Any value 0–99. Every
  write is a record with author + timestamp; the previous value is superseded, not
  overwritten silently.
- **The supervisor computes `appetite_auto(f)`** from the window state (§4.3) and may
  **only reduce**: `appetite_effective(f) = min(appetite_operator(f), appetite_auto(f))`.
  The machine can throttle and can restore *toward* the operator's number as a window is
  observed to reset — it can never exceed it. `appetite_operator(f) = 0` therefore means
  hard-forbid that no automatic process can lift, which is the whole point of the `0`
  extreme.
- **No worker may write either value.** Mechanized: the `managent appetite <family> <n>`
  write path refuses when the caller's environment marks it a held worker
  (`MANAGENT_TASK_ID` present, or the supervisor's held-child marker set), exit non-zero,
  named reason. A worker that could raise its own family's appetite is a runaway vector
  and belongs to §5's threat model as much as to this section.

→ Arms A1, A2, A6.

### 4.5 Migration from the levels, and what `RESERVED` actually was

Default dial values, so the S02 table is superseded rather than orphaned (operator to
ratify the numbers; the *mapping* is the spec's claim, the numbers are the operator's):

| family | old level | dial | note |
|---|---|---|---|
| `deepseek` | `SPEND` | 90 | the workhorse |
| `claude` | `CONSERVE` | 45 | weekly ≈70 % used at 2026-08-21 |
| `claude-fable` | `RESERVED` | 60 **+ reservation predicate** | see below |
| `ollama-cloud` | `SPEND` | 90 | the "speed up" side of the operator's ask |
| `local` | `PROBE` | 15 | costs the machine, not credits |

`RESERVED` was **not a point on the appetite axis** — it is a *task-type predicate*
("deep holistic review · gate-holder verification · spec/design adjudication; never
one-off/general", `measurement-methodology.md:30`). Rev 1 inherited it as a fifth level
and thereby made the axis incoherent: a family could be simultaneously "most eager" and
"almost never dispatchable". The dial separates the two: Fable has a **mid dial** (it may
spend when it is the right lane) **and** a hard reservation predicate (it is the right
lane rarely). The predicate is a separate hard gate, evaluated with the appetite check,
refusal reason `reservation-mismatch`. Making this separation visible is a genuine finding
of the refinement, not bookkeeping.

---

## 5. Runaway and recursion safety (operator refinement (b); **Must**)

**Operator requirement (2026-08-21):** *"sprints MAY queue additional tasks or defer
tasks, but every queued task must be well-specified, unique, justified, and provably NOT
recursive / replicating / self-DoS… a task that mints tasks needs a cap + lineage + a
justification field"* (`docs/status/orchestration-layer-spec.md` §7.5).

This is a **Must** and it is enforced **at the store write**, not in the supervisor's
prose. A worker can write the store directly (`managent add`); a check that lives only in
the supervisor's dispatch loop is bypassed by the first worker that mints a row itself.
Prose is not a remedy for a mechanism failure.

Five assertions:

- **RUN-1 (mint delta — the runaway detector).** Define `open(t)` = the count of rows in
  the store whose status is not closed, sampled at time `t`. On every close the supervisor
  records `Δ = open(after) − open(before)`. `Δ > 0` is legal — a sprint that discovers
  work *should* queue it. What is illegal is **sustained** growth: if `Δ > 0` for `K`
  consecutive closes (`K` operator-set, default 5), or if the sum of `Δ` over a window
  exceeds a per-window mint budget, the **mint circuit breaker** trips: dispatch nothing
  new, loudly, with reason `mint-breaker`, until an operator clears it. The breaker is the
  same shape as T536's per-model lane breaker, so its behaviour is already understood.
  The instrument is the *derivative*, not the level — a queue of 200 rows that is shrinking
  is healthy; a queue of 12 that grows every close is a runaway.
- **RUN-2 (one author per mint).** Every row minted by a worker carries `minted_by` =
  exactly one identity `{task_id, model, supervisor_pid}`. A row written with zero authors
  (an anonymous mint) or with a second author appended is **rejected at write time**, not
  reconciled later. This is the same sole-owner discipline as T477's `healed_by`
  (§2.3) and it exists so the lineage in RUN-3 has exactly one parent to walk.
- **RUN-3 (lineage + justification, both required).** Every queued row carries:
  - `lineage`: the ordered chain of task ids from the root **human-authored** row to this
    row. A row an operator adds has `lineage = [self]`. A minted row's lineage is its
    minter's lineage plus its own id.
  - `justification`: non-empty free text naming the finding, gate, or condition the row
    discharges. Empty is not dispatchable.

  Two hard checks on lineage: **depth** — `len(lineage) ≤ D_max` (operator-set), refusal
  reason `lineage-depth`; and **acyclicity** — a row whose own id already appears in its
  lineage is a cycle, rejected with `lineage-cycle`.

  **`D_max` is not `MAX_DEPTH`.** `bin/subagent:46` caps *process* nesting at 3
  (`WEIZIGO_AGENT_DEPTH`, `:45`) — how many harnesses deep a live call chain runs. `D_max`
  caps *provenance* depth — how far a row is from a human decision. A single-level fleet
  of workers each minting one child forever has process depth 2 forever and unbounded
  lineage depth. Both caps must exist; they measure different runaways, and conflating
  them is how a flat replicator gets past a depth guard.
- **RUN-4 (uniqueness — the replicant check).** A minted row that collides with an
  existing open row on `(holds, justification-key)` is rejected as a replicant, reason
  `duplicate-mint`. This is the "unique" half of the operator's requirement and the
  cheapest of the five: a self-replicating worker's first duplicate is refused before the
  breaker ever needs to trip.
- **RUN-5 (a parked row is reported, never dropped).** A row refused by RUN-3 or RUN-4 is
  **parked with its reason recorded and surfaced** by `supervise status`, not discarded.
  Silent rejection would make the queue lie about what it was asked to do — the same
  defect class as a queue reporting success while doing nothing.

**Threat model, stated so the controls can seed it.** The runaway this section exists to
stop is: a worker whose close mints a copy of its own row (or two), each of which
dispatches, each of which mints again — bounded by neither the process depth cap (depth
stays flat) nor the fleet cap (rows are legitimate) nor appetite (the family is allowed).
RUN-4 refuses the first exact copy; RUN-3's depth cap bounds a mutating chain; RUN-1's
breaker catches a replicator that evades both by varying its rows. Three independent
mechanisms, because a single one is a single point of failure for a defect whose cost is
the whole fleet plus the credit pool.

→ Arms R1–R6.

---

## 6. `ollama stop` (Could) — the per-family release call site

Pass-1 scope.md §4 measured: the ollama family's heavy process (the model) is
daemon-owned, so `treekill` cannot reach it by pid — killing the dispatched tree leaves
the model resident. This is HOLD-1's named exception (§1), and this section is its
discharge. **Decision, carried:** the supervisor's ollama call sites invoke the release
after the worker exits. This is a **Could**: pass-1's stated harm (the compile-suite leak)
is already closed by the verb, and local-model dispatch is currently idle (the D036 Ollama
quota deny). Severable — first cut if the pass must slim.

**The release route and tag are pinned (F9).** Rev 1 said "`ollama stop <model>` (or the
daemon-owned runner pid from `ollama ps`, whichever the topology record shows)" — an
unpinned disjunction, and it quoted the wrong tag. The launch is
`ollama launch pi --model <raw tag> …` (`bin/subagent:271-272`), where the raw tag is what
the operator passes and what the daemon serves — `glm-5.2:cloud`, not the canonical
`glm-5.2` (`bin/subagent:69-80`; `tools/bakeoff.sh:17` — *"the tag is what is served"*).
Therefore:

1. **Primary route:** `ollama stop <launched tag>` — the exact string from the launch
   template's launched-tag field (§3.1), byte-for-byte the value passed to
   `ollama launch pi --model`. `ollama stop glm-5.2` where the launch used
   `glm-5.2:cloud` is a **no-op that reports success**, which is the failure mode rev 1
   could not have caught.
2. **Pinned fallback, not an alternative:** if and only if the launched tag is absent from
   `ollama ps` output, the release targets the daemon-owned runner pid that `ollama ps`
   reports for the family. Fallback taken ⇒ recorded with a reason. A disjunction with no
   selection rule is not a spec.

Testable, not just promised (the T-tooling rule: a defect that only prose enforces is
enforced on whoever reads it): arm S9 dispatches an ollama stub worker through the
supervisor, exits it, and asserts the release fired **exactly once with the launched tag**
— via a stub `ollama` on `PATH` in the scratch root (the same inject-don't-exhaust shape
as `RUNNER_TEST_RAISE` / `WEIZIGO_HOST_MEM_AVAIL_MB`). The stub records the invocation and
its argv; the control reads the stub's record, never the supervisor's word. A release that
fails to fire, fires twice, or fires with the canonical label instead of the launched tag
is a FAIL. Arm S9-tag is the discriminating case: launch with `glm-5.2:cloud`, assert the
stub saw `stop glm-5.2:cloud`.

---

## 7. B-7..B-11 — the pass-1 deferred treekill findings, folded in

Each is a finding against the now-shipped `managent treekill`, deferred from pass 1's
build audit (`pass1/audit-build-disposition.md`). They ride pass 2 because the supervisor
is the next `treekill` caller, and a caller that seeds session leaders or runs from a
bare directory must not inherit the traps. Dispositions are the audit's own, restated
with a control each (a fix without a control is not a fix):

| id | sev | finding (verbatim sense) | disposition | control |
|---|---|---|---|---|
| B-7 | should | a seeded session-leader escalates the closure upward past D-19 | **downward-test seeds, semantics pinned (F7): exclude-and-report, not refuse.** A `--seed` pid that is an ancestor or sibling of the anchor is **excluded** from the closure, **named in the summary line**, and the exit code comes from survivors as usual. The seed list is a *floor hint* and a stale hint must not abort an otherwise-correct reap. **Pass-1 G3 is unchanged**: a seed that is the verb's own self / ancestor / session leader is still exit 4 (`pass1/spec.md:145`, `:307`) — that is self-harm, a different class. The contract change is both halves: document the caller contract *and* enforce it | arm B7 — **the seed must be constructed outside the verb's own ancestry** (a third-party session leader above the anchor: a `setsid`'d fixture process in an unrelated session), because rev 1's arm passed via G3's refusal and never exercised the downward rule at all. Assert: the seed is *excluded and named*, zero upward claims, exit reflects survivors, and the run is **not** exit 4. Companion arm B7-g3 seeds the verb's own session leader and asserts exit 4 — the two arms together pin which mechanism fired |
| B-8 | should | downward constraint enforced on the pgid edge only; sid edge correct by construction, untested | add a **mutation control for the sid-edge downwardness** — the instrument-mutation rule: delete the sid-edge downward check ⇒ a seeded sid-escalation arm must fail red | arm B8 — the mutation; a sid-keyed edge reaching upward is rejected, not followed |
| B-9 | should | the verb exits 1 when cwd has no `.git` above it, outside its own exit-code table | **degrade to an empty protected set**: `treekill` needs the repo root only for G6's run-record scan; no `.git` ⇒ protected set empty + a stderr diagnostic, exit code still from the 0/2/3/4/5 table | arm B9 — run `treekill` from `/tmp` (no `.git`); assert the exit code is in {0,4,5} per the anchor, never 1 |
| B-10 | could | `--anchor -1` exits 2, where `pid ≤ 1` ⇒ exit 4 | **distinguish the missing-anchor sentinel from a parsed negative**: a token that parses to an integer ≤ 1 (including −1) is exit 4 (refused); a token that does not parse as a decimal integer (or is absent) is exit 2 (usage) | arm B10 — `--anchor -1` → 4; `--anchor 0` → 4; `--anchor 1` → 4; `--anchor abc` → 2; missing → 2 |
| B-11 | could | G4's live-path `etime`→epoch arithmetic has no control | add a **live-path control**: a live anchor with a known start time → the G4 floor (anchor's own start, `since` default) matches `lstart`/`etime`-derived epoch within a tolerance, and a member older than the floor is excluded | arm B11 — spawn a live anchor, compute its true start via `lstart`, run read-only, assert the floor line is correct and an older-than-floor member is `report`ed-but-excluded |

B-9's exit-1 comes from the repo-root walk failing *outside* treekill's own exit table —
the load-bearing point is that `treekill`'s exit codes are a contract (§2 of pass-1), and
a host process-killing verb may not leak a `1` that its own caller can read as neither
refusal nor convergence.

---

## 8. Cannibalization sites — done means the old path is deleted

Each site names today's code, the after-state, and a mechanized predicate (a grep a
queue can run, not a reviewer's read — pass-1 §6's convention). **Renamed CAN-1..CAN-7
(F11)**: rev 1 called these C1–C7, colliding with pass-1 §6's `C1–C6`, which are
`treekill` **kill sites** in `tools/runner` — a different set of things entirely, and both
sets appear in this pass's own controls. Where this document says C1–C6 unqualified
(§2.2, §1 HOLD-3) it means pass-1's kill sites.

| # | site (current tree, `56b9cf1`) | today | after | mechanized gate |
|---|---|---|---|---|
| CAN-1 | `tools/runner`'s dispatch-role guards (post-pass-1 they already kill via `treekill`; `killpg` is gone) | the guards run in a detached, unowned process (runner = `bin/dispatch`'s nohup'd grandchild) | the supervisor runs the guards itself and `treekill`s its held child; the Python runner keeps only the standalone build-guard role | the supervisor's guard code contains no `killpg`/`setsid`/`start_new_session` on the dispatch path; `grep -c killpg tools/runner` is 0 (already true) and stays 0 |
| CAN-2 | `bin/dispatch:301` `start_new_session=True` + `nohup`; `MODELS` at `:76-88` / `ALIASES` at `:91-94` | detaches, prints "dispatched"; holds a 10-label model list | deleted. The one dispatch command is `managent supervise <id> <model>`; if a thin wrapper survives for muscle memory it is one line calling the verb | `grep -n start_new_session bin/dispatch` returns nothing; `grep -n "bin/subagent" bin/dispatch` returns nothing; DP-6 sees no label list here |
| CAN-3 | `bin/subagent` provider branches (`:247-272`); `CLAUDE_MODELS` `:57-62`; `OLLAMA_TAG_TO_CANONICAL` `:69-80` | three per-family command builders + two label maps | deleted; the launch template is data (§3.1), the prompt builder one shared function, the tag map a table column | `grep -nE "provider" bin/subagent` returns nothing (file deleted or emptied to a one-line forwarder); DP-6 sees no label list here |
| CAN-4 | `tools/dispatch_verify.py` (`verify_dispatch`, `heal_dispatch`, `record_perf`, `provider_refusal_reason`) | post-dispatch verify as a separate Python module | the same logic inside the supervisor's held process (Zig); the Python module is deleted or reduced to the `--dry-run` findings gate | `grep -nE "verify_dispatch|heal_dispatch" tools/dispatch_verify.py` returns nothing, or the file is gone |
| CAN-5 | `tools/fleet-keeper.sh` (the loop + `fire()`); the six state files (§2.4); `canon` at `:286-287` | shells out to `bin/dispatch`; holds **5 of 10** canonical labels | deleted; the loop is §2.1 inside the supervisor; all six state files supervisor-owned | `grep -n "bin/dispatch" tools/fleet-keeper.sh` returns nothing; DP-6 sees no label list here; arm G1 (golden master) green |
| CAN-6 | `tools/fleet-cooldown.sh` + the `untracked/fleet-keeper.cooldown` file flag | a file flag toggled by a script | deleted; `managent supervise cooldown on\|off\|status` | `grep -n "fleet-keeper.cooldown" tools/*.sh` returns nothing |
| CAN-7 | the run-record / heartbeat / heal writers split across runner, subagent, dispatch_verify | multiple writers (T545 class) | **HOLD-6a/b/c**: dispatch run records path-partitioned to the supervisor; the six state files supervisor-only; heartbeat and heal logs enumerated multi-writer with atomicity asserted | `grep -rl "untracked/runs/\|heartbeat.jsonl\|dispatch-heals.jsonl" tools/ bin/` returns **only** the supervisor's source and `tools/runner` (the enumerated residual), and the two writers' path prefixes are disjoint constants (`untracked/runs/<T-id>` vs `untracked/runs/build/`) |

CAN-7's gate is narrower than rev 1's ("returns only the supervisor's source") because
rev 1's version was **unsatisfiable while `tools/runner` survives** — it asserted the
deletion of a writer this pass explicitly keeps (§10.1). The corrected gate asserts what
is true and testable: an *enumerated* writer set and *disjoint* paths.

**Dogfood, per site, in the same pass** (the seed's step 5 — a pass is not done when the
verb exists, it is done when the old script calls it and the old code is deleted). The
cutover is **one task at a time**, old path still available, until a full day runs on the
new supervisor — the seed's Pass-5 dogfood instruction, applied to the whole remainder.

---

## 9. Explicit non-goals

Pass 2 does **not**: build the full fleet view (`managent fleet` — the seed's Pass 2)
or absorb `watch-fleet.sh`, `argus`, `orcha-acceptance.sh`, `model-profiles.py` (read-only
views, later); retire `docs/infra/model-perf.md` for structured rows (the seed's Pass 4 —
the supervisor appends the same lines it appends today, and the three residual model-list
holders DP-6 allowlists close with that pass); delete the Python `tools/runner`
standalone build-guard role (ReleaseFast injection + `--sweep` — see Open question 1);
handle supervisor-crash orphans (SUP-STOP-3 → T548's sweep); add a second supervisory
process of any kind (the fix is that the mechanism holds, not that something watches it);
own the queue *ordering* policy (aging, conditions, overnight budgets — that is
`S03-queue-layer/spec.md`; this pass owns the appetite dial's data shape and enforcement
point, not the ordering it feeds); claim Linux (macOS only is measured); kill cross-uid
processes or elevate; re-open the nested-dispatch exemption (Open question 2, carried); or
relitigate the pass-1 foreclosures (PSK, C2 falsified, single-score region — untouched).

**The one deferral that must be stated, not implied (F2).** Moving run records and
heartbeats *into* the store, under the store lock, is **the seed's Pass 5 and it remains
deferred**. Rev 1 listed this as a non-goal *and* let HOLD-6 claim the property the
deferred pass would deliver. HOLD-6a/b/c (§1.1) now claim only what path partition,
writer deletion, and append atomicity hold. The residual gap, named: two processes append
to `untracked/heartbeat.jsonl` and to `docs/infra/dispatch-heals.jsonl`, so **line
ordering across writers is not guaranteed** and a reader that depends on it is depending
on something this pass does not provide. Arm S6c measures exactly that gap rather than
denying it.

---

## 10. Scoping verdict

Pass 2 as briefed, plus the rev-2 corrections, is the right remainder.

### 10.1 Corrections adopted from the field

1. **"Replaces runner" means the dispatch role, not the standalone build guard.** The
   supervisor's held worker is a harness process; the ReleaseFast injection and `--sweep`
   are in-session build tooling, not orchestration. Deleting them would break
   `AGENTS.md`'s "ad-hoc builds run under tools/runner" rule for no held-handle gain. The
   seed's "three programs instead of fourteen" holds — runner's *orchestration* half is
   gone; its *research-tool* half stays until a `managent run` verb is separately scoped.
   **Consequence rev 1 did not follow through (F1):** the surviving half is a *writer*, so
   HOLD-6 had to become a path property (§1.1). Keeping the runner and claiming single
   parenthood-based writership were incompatible, and the incompatibility was the finding.
2. **The fleet-fill loop is behaviour-preserving, not a redesign.** The keeper's
   eligibility/pressure/backoff/cooldown logic is the tested asset (T500/T504/T536); the
   pass swaps the *mechanism* (detach-and-print → hold-a-handle), not the policy. A spec
   that said "rewrite the keeper's policy" would be re-litigating decisions already
   made under load. **Consequence (F8):** behaviour-preserving means all six state files,
   with the existing `tools/regression-fleet-keeper.sh` as the golden master.
3. **The dispatch interface needs a decode seam and it already exists (F3).** "No family
   branches" and "one family emits a JSON envelope" are both true; the reconciliation is a
   declared data field, not a compromise on either. The tree solved this at
   `tools/runner:1041-1051` and pass 2 adopts that solution by name.

### 10.2 Cut order if the pass must slim

1. `ollama stop` (Could, §6) · 2. the `supervise status` held-children listing (fold into
the later fleet view) · 3. CAN-7's cross-writer grep gate (still worth having, no longer
"cosmetic once HOLD-6 holds" — HOLD-6 is a *path* property, so CAN-7's disjoint-prefix
predicate is now the thing that enforces it; cut it last).

**Never cut:** HOLD-1..5, HOLD-6a/b/c, the guard table, verify + heal, DP-1..DP-6 and the
§3.1 launch-template table, **§4 (appetite dial)**, **§5 (runaway/recursion safety)**,
B-7..B-11 (all five — cheap, each closes a named trap the supervisor would otherwise
inherit), CAN-1..CAN-6.

§4 and §5 are never-cut because both are hard-forbid mechanisms: an appetite floor that can
be lifted by the machine and a mint path with no lineage are the two ways this pass could
make things *worse* than the scripts it replaces. A supervisor that holds its children
perfectly while spending the credit pool or replicating rows is not the deliverable.

---

## 11. Open questions / rulings

1. **Standalone `tools/runner` disposition.** Fold the build-guard role into a `managent
   run` verb (a later pass), or keep the Python runner as research tooling forever? The
   seed's "three programs" implies the former; this spec keeps the Python until that pass
   exists. Needs an operator/Orchestrator ruling — no silent deletion. **Rev-2 note:** the
   answer determines whether HOLD-6a's path partition is permanent or transitional.
   **RULED 2026-08-22 (operator): fold into managent.** Python transitional, ratified deletion
   when the verb ships; HOLD-6a's partition is transitional. Record:
   `docs/status/orchestration-layer-spec.md` §7b item 6.
2. **Nested-dispatch exemption** — carried unchanged from pass-1 Open question 1. The
   supervisor's held-child set + the existing G6 protected-set guard make a nested
   dispatch's runner pid (now a nested supervisor's pid) land inside an outer closure and
   trip total refusal; the coarser-than-ideal interim remains. Not resolved here.
   **RULED 2026-08-22 (operator): coarse refusal accepted.** Nested dispatch stays refused;
   re-open only when a real workflow needs it. Record:
   `docs/status/orchestration-layer-spec.md` §7b item 7.
3. **Seed-window residue size (r4)** — carried from pass-1 Open question 2; the
   supervisor's poll-walk seed list has the same r4 gap the runner's had. Unchanged.
4. **How the supervisor is launched.** Foreground (operator console holds it) vs. under
   `tools/runner` (held but guarded) is a launch-time choice, not a spec change; both
   satisfy HOLD-4. Default in the dogfood: launch it under `tools/runner` so the topmost
   process is itself guarded, exactly as the keeper is today (`fleet-keeper.log`).
5. **Enumeration cost** — carried from pass-1 Open question 3 (`ps` + `getsid` per round);
   the supervisor polls per child every `--poll-ms` (default 250) and the cost of N
   concurrent poll walks is unmeasured. Design-phase measurement; if it measures badly,
   `sysctl(KERN_PROC_ALL)` is the same escape pass 1 named.
6. **Appetite constants need operator ratification (§4.5).** The *mapping* from levels to
   a dial, the 0/99 extremes, the reduce-only rule, and the three window states are the
   spec's claims. The per-family default dial values, `lane_cap(f)`, `spacing_max(f)`,
   `appetite_floor(f)`, and the `remaining_frac → appetite_auto` curve are the operator's
   numbers and are unratified. Nothing in §4 is blocked on them: the controls exercise the
   mechanism at chosen values.
7. **`D_max` and the mint budget (§5).** `D_max` (lineage depth cap), `K` (consecutive
   positive-Δ closes before the breaker trips, default 5), and the per-window mint budget
   need operator numbers. Unratified. The `MAX_DEPTH = 3` process cap
   (`bin/subagent:46`) is **not** a precedent for `D_max` — different quantity (§5, RUN-3).
8. **Where the appetite dial and window records live.** The store (under its lock, visible
   to `managent` verbs) vs. a config file. Lean: the store, because §4.4's
   worker-cannot-write rule then rides the store's existing lock and audit trail rather
   than filesystem permissions. Design-phase choice; the spec's claims hold either way.

---

## Controls — named, not written

New file `tools/regression-supervise.sh` (not folded into the T364/treekill scripts —
different concern; skip-loudly while the verb is absent, red-first once it exists, per the
pass-1 conventions). Scratch tree under `/tmp/weizigo`; `MANAGENT_STORE` scratch isolation
(A3); the `--test-worker=<cmd>` stub hook carried from `bin/dispatch`/`bin/subagent` so
every arm runs a stub worker, never an LLM.

**Instrument-mutation controls** (every instrument gets a null control and a seeded-defect
control before its first reading counts): disable the no-detach invariant ⇒ S1 red;
disable the seed list ⇒ S4 red; disable the store `flock` ⇒ S6b red; force every lane's
decoder to `text` ⇒ D2 red; delete a sentinel comment ⇒ DP-3's gate must fail *loudly*
(an empty `awk` selection greps clean and would otherwise pass — the gate must assert its
selection is non-empty); delete the sid-edge downwardness check ⇒ B8 red; disable the
release call ⇒ S9 red; remove the `appetite == 0` short-circuit ⇒ A1 red; remove the
write-path worker refusal ⇒ A2 red; remove the mint-delta accumulator ⇒ R1 red; remove the
lineage cycle check ⇒ R3 red.

| arm | kind | seed | asserts |
|---|---|---|---|
| N1 | null | `--once` on an empty scratch store | no spawn, exit 0, one parseable report line; documents SUP-STOP-3 shape only |
| N2 | null, single-instance | start a supervisor, start a second | second exits non-zero naming the holder (HOLD-5) |
| N3 | null | launch `managent supervise`; inspect it | ppid == launcher, no new session (HOLD-4) |
| S1 | seeded, held | stub worker via `--test-worker` | `ppid == supervisor`, same session, exit 0, run record finalized, verify passed (HOLD-1) |
| S2 | seeded, death | SIGKILL the worker mid-run | run record `signal` present within 2 s; zero live descendants; death path contains no `ps`/`pgrep` (HOLD-2, HOLD-3) |
| S3 | seeded, ceiling | memory-hungry stub, low `--rss-cap-mb` | whole tree dead, `killed=` recorded, exit 124 semantics preserved |
| S4 | seeded, escape | the pass-1 session-escaping tree under the worker | treekill reaches the escapee via the supervisor's seed list; zero survivors (HOLD-3) |
| S5 | seeded, fleet-fill | N eligible rows + a slow-claiming stub | exactly one fire per row (no re-fire), ordering and one-writer invariant held (§2.1 red) |
| S6 | seeded, verify/heal | a stub that echoes the nonce but leaves the row open | verify fails + heal fires **in one process**; run record finalized (§2.3) |
| S6a | seeded, writer partition | a held dispatch for `T<n>` **concurrently with** in-session `tools/runner --task-id T<n> -- <stub build>` | two distinct files (`untracked/runs/T<n>.json`, `untracked/runs/build/T<n>.json`), both well-formed and finalized; each writer's path prefix is a pinned constant (HOLD-6a) |
| S6b | seeded, single-writer state | two supervisors race for the lock; drive pressure/attempts transitions | one holder; counters advance monotonically, never backwards (HOLD-6b); mutation (no `flock`) drives a counter backwards, red |
| S6c | seeded, append atomicity | N concurrent appenders (supervisor + runner + stub) × K lines to `heartbeat.jsonl` | exactly `N×K` lines, every line independently JSON-parseable, zero torn records; line *order* explicitly not asserted (HOLD-6c, §9) |
| S7 | seeded, graceful | `cooldown on`, a finishing stub | no new spawns; child finishes; supervisor exits 0 (SUP-STOP-1) |
| S8 | seeded, hard stop | SIGTERM the supervisor mid-worker | every held child's tree dead; supervisor exits 0 (SUP-STOP-2) |
| S9 | seeded, ollama release | ollama stub dispatch, then exit | release fired exactly once, argv read from the stub's record (§6) |
| S9-tag | seeded, launched tag | launch with `--model glm-5.2:cloud` | the stub saw `stop glm-5.2:cloud`, **not** `stop glm-5.2`; canonical-label release is a FAIL (F9) |
| G1 | golden master | `tools/regression-fleet-keeper.sh` (existing, 1,262 lines) run against the supervisor's fleet-fill mode | every arm that passes against `tools/fleet-keeper.sh` passes against `managent supervise`; a divergence is a behaviour change and must be justified or reverted (F8) |
| D1 | seeded, drift gate | a family branch inside the sentinel-fenced dispatch/input region | DP-3's gate goes red; **D1-null**: gate green on the shipped tree; **D1-empty**: a deleted sentinel makes the gate fail loudly, not pass vacuously |
| D2 | seeded, decode | a stub lane declaring `output_format = json-envelope`, emitting an envelope around the nonce | nonce found after unwrap; token counts and the T552 session handle captured (DP-5) |
| D3 | seeded, decode failure | a `text`-emitting stub declaring `json-envelope` | decode fails with a **named** reason, distinguishable from `nonce-not-found`; the two verdicts are never conflated (DP-5) |
| D4 | mutation | force every lane's decoder to `text` | D2 red |
| D5 | seeded, second list | a fresh file holding 3 canonical labels as literals | DP-6 red; **D5-null**: green on the post-pass tree; **D5-pin**: adding an 11th label to an allowlisted residual holder is red until the pin is updated (F4) |
| D6 | seeded, data-not-code | append a synthetic 4th family row pointing at a stub binary | a dispatch through it works with **zero** source changes outside the table (§3.1) |
| D7 | seeded, tag mapping | dispatch an ollama tag with a `:cloud` suffix | no `:cloud` string reaches any store row or ledger line; the canonical label does (§3.1) |
| A1 | seeded, hard forbid | `appetite(claude) = 0`, an eligible claude row | zero dispatches, reason `appetite-forbid`; mutation (remove the `== 0` short-circuit) ⇒ red (§4.1) |
| A2 | seeded, write authority | a held worker attempts `managent appetite claude 99` | refused non-zero with a named reason; the stored value is unchanged; an operator write of the same value succeeds (§4.4) |
| A3 | seeded, reduce-only | `appetite_operator = 40`, supervisor computes `appetite_auto = 90` | `appetite_effective == 40`; the machine never exceeds the operator's number (§4.4) |
| A4 | seeded, window states | drive one family through `OBSERVED` → wall clock past `resets_at` → `ASSUMED_RESET` → a fresh assertion | `ASSUMED_RESET` holds the pre-reset dial (**no speed-up on a prediction**); the fresh assertion lifts it; a stale-beyond-one-window record yields `UNKNOWN` clamped to `appetite_floor`, never 99 (§4.3) |
| A5 | seeded, envelope observation | a `json-envelope` stub lane carrying a usage payload | the window record is written with `source = envelope`, `observed_at`, and the worker's identity as author (§4.3) |
| A6 | seeded, dial arithmetic | sweep `appetite ∈ {0, 1, 45, 98, 99}` with fixed `lane_cap`/`spacing_max` | `lanes`/`spacing` match §4.2 exactly; `lanes ≥ 1` for every nonzero dial; `spacing == 0` at 99; refusal reasons distinguish `appetite-lanes-exhausted` from `appetite-spacing` (§4.2) |
| R1 | seeded, runaway | a stub whose every close mints 2 **distinct** rows | the mint breaker trips within `K` closes, reason `mint-breaker`, dispatch stops, total queued work stops growing; mutation (remove the Δ accumulator) ⇒ red (RUN-1) |
| R1-null | null | a stub whose close mints nothing, run 3× `K` closes | breaker never trips; Δ recorded as ≤ 0 each close (RUN-1) |
| R2 | seeded, authorship | a mint written with no author; a second write appending a second author | both rejected **at write time**; the store is unchanged (RUN-2) |
| R3 | seeded, lineage | (a) a chain minting to depth `D_max + 1`; (b) a row whose lineage contains its own id | (a) refused `lineage-depth`; (b) refused `lineage-cycle`; mutation (remove the cycle check) ⇒ (b) red (RUN-3) |
| R4 | seeded, depth independence | a **flat** replicator: process depth stays 2, lineage depth grows | `WEIZIGO_AGENT_DEPTH`'s `MAX_DEPTH = 3` does **not** fire; `D_max` does. Proves the two caps are independent (RUN-3) |
| R5 | seeded, replicant | a stub minting an exact copy of its own row (same `holds`, same justification key) | refused `duplicate-mint` on the first copy, before the breaker is needed (RUN-4) |
| R6 | seeded, parked visibility | rows refused by R3 and R5 | each is parked with its reason and appears in `supervise status`; none is silently discarded (RUN-5) |
| B7, B7-g3, B8–B11 | seeded, treekill | per §7 | per §7's control column |

Acceptance also includes one hand-traced end-to-end audit of a single dispatch — spawn to
verify to heal, pid followed from spawn to death (the pass-1 standing rule).

---

## Provenance and rejected alternatives

Adopted aspects → source:

| aspect | source |
|---|---|
| "held, not inferred" root cause; "killpg covers one group, macOS has no cgroups"; the three-program target; the cannibalization 5-step pattern; the one-task-at-a-time cutover | seed brief (`refactor-roadmap-2026-08-20.md`) |
| treekill contract, §6 kill sites C1–C6, §7 one-dispatch-interface shaping, OWN-1..5, guard naming, exit-code discipline, the **inclusive** sentinel grep-gate convention (`pass1/plan.md:173-174`) | `pass1/spec.md`, `pass1/plan.md` |
| B-7..B-11 dispositions (downward-test seeds; sid-edge mutation control; empty protected set; anchor-sentinel vs negative; live-path floor control) | `pass1/audit-build-disposition.md` |
| F1–F11 — the rev-2 mandate, all ACCEPT | `pass2/audit-disposition.md` (lanes: Opus 11, Flash 6, Sonnet 2, Haiku 3) |
| the flag-keyed decode seam, adopted by name (DP-5) | `tools/runner:1041-1051` (`_json_output_lane`) |
| the launch-template argv, per family (§3.1) | `bin/subagent:247-272`; tag map `:69-80`; claude allowed-tools `:65` |
| the six fleet state files (§2.4) | `tools/fleet-keeper.sh:136-150` |
| the residual run-record / heartbeat writer (HOLD-6a/c) | `tools/runner:368-369`, `:372-382`, `:398-458`, `:463`, `:1385` |
| `ollama stop` as a per-family release, severable Could; the launched-tag rule | `pass1/scope.md` §4; `bin/subagent:271-272`; `tools/bakeoff.sh:17` |
| appetite as a **spectrum** (hard forbid vs soft back-pressure); mint safety needing "a cap + lineage + a justification field"; "well-specified, unique, justified, provably NOT recursive" | operator, `docs/status/orchestration-layer-spec.md` §7.2, §7.5 |
| the level→dial migration baseline and the `RESERVED` reservation predicate | `S02-model-delegation/measurement-methodology.md:23-32` |
| fleet-fill eligibility/pressure/backoff/cooldown carried behaviour-preserving; the 80× re-fire as the keeper's Red; the golden-master arm | `tools/fleet-keeper.sh`, `docs/infra/fleet-keeper-design.md`, `tools/regression-fleet-keeper.sh` |
| nonce/deliverables/row-state verify; heal sole-owner; provider-refusal; wall-advisory | `tools/dispatch_verify.py`, `bin/subagent` |
| guards (RSS/wall/CPU/host-floor/progress/directives/heartbeat/run-record) | `tools/runner`, `docs/infra/runner.md` |
| the process depth cap, and why it is *not* the lineage cap | `bin/subagent:45-46` (`WEIZIGO_AGENT_DEPTH`, `MAX_DEPTH = 3`) |

Rejected major alternatives, one line each:

| rejected | reason |
|---|---|
| the supervisor as a detached daemon (double-fork, setsid) | directly contradicts "holds its children and never detaches"; HOLD-1/HOLD-4 would fail by construction |
| re-implementing the keeper's policy (new ordering, new cap logic) | the policy is the tested asset; the pass swaps the mechanism, not the decisions |
| keeping `bin/dispatch`/`bin/subagent` as thin per-harness wrappers long-term | DP-1 demands exactly one command; a wrapper is a second definition and re-opens the F7/T503 drift |
| **rev 1's HOLD-6 (parenthood ⇒ sole writer)** | false: `tools/runner` survives in its build-guard role and still writes run records and heartbeats (`tools/runner:1385`, `:368-369`, `:463`). Single-writer is a path property — F1 |
| **pulling the seed's Pass 5 (run records into the store) into this pass** | it is a store-schema change with its own concurrency tests; the honest alternative is a path partition plus a stated deferral, which is what §1.1 and §9 do — F2 |
| **rev 1's exclusive family-token gate** (grep everything minus the data tables) | inverts the inclusive sentinel sweep that shipped and works; unscoped it can never pass, and `\bpi\b` trips prose — F5 |
| **a gate asserting "exactly one model list exists"** | false on the first run (three residual holders outside this pass's scope) and disabled by the second week; DP-6 enumerates and count-pins instead — F4 |
| **DP-4 alone, with no decode seam** | forbids the claude JSON envelope the tree actually needs; a family-independent *declared* `output_format` field is the reconciliation — F3 |
| **keeping the static `OFF..RESERVED` appetite levels** | a five-valued enum cannot express "a bit less than yesterday", so every adjustment is a doc edit; and `RESERVED` was a task-type predicate misfiled as an appetite level — operator refinement (a) |
| **letting the supervisor raise its own appetite** | a machine that can lift its own credit ceiling has no ceiling; reduce-only with an operator-set maximum keeps the `0` extreme unliftable — §4.4 |
| **treating a wall-clock `resets_at` crossing as an observed reset** | a window that should have reset and did not is exactly the case that burns credits, and it is invisible from the clock; absence of an assertion is UNKNOWN, not "reset" — §4.3 |
| **relying on `MAX_DEPTH = 3` for recursion safety** | it caps *process* nesting; a flat replicator has constant process depth and unbounded lineage depth. Different quantity, different cap — §5 RUN-3, arm R4 |
| **enforcing mint safety in the supervisor's dispatch loop only** | a worker can write the store directly; the checks belong at the store write or they are prose — §5 |
| `ollama stop` as a Must | local-model dispatch is idle (D036 quota deny) and pass-1's harm is already closed by the verb; severable |
| deleting `tools/runner` wholesale | breaks the standalone build-guard rule for no held-handle gain; disposition is Open question 1 |
