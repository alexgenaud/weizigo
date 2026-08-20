# Spec — process ownership (pass 1 of the orchestration refactor)

## 0. Scope in one paragraph

Add two `managent` verbs — `snapshot-tree` and `kill-tree` — that let a caller capture and
then reliably terminate an entire process descendant tree, and use them to replace the
`killpg` call in `tools/runner:1505` and to fill the reap-nothing gap on the normal-exit
path. No daemon, no new supervisory process, no change to `bin/dispatch`. Everything below
is testable before a line of the verb is written.

---

## 1. What "owned" means, testably

A root pid `R` is **owned** at the moment of a `kill-tree R` call if and only if:

> For every pid that was a live descendant of `R` in a single process-table snapshot taken
> at (or before, per §3) the start of the call, a post-call re-scan finds that pid either
> (a) absent, or (b) present but with a different process-start-time than the snapshot
> recorded (i.e. it is a different process that reused the pid).

This is a closed, checkable predicate — a control can assert it by taking two `ps`
snapshots and diffing a pid set, with no judgment calls about "robustness." It has three
consequences that shape the rest of this spec:

- **Ownership is a property of a call, not a standing state.** Pass 1 does not track
  ownership between calls; the caller must have a way to hand the verb a tree it can no
  longer discover live (see the normal-exit case in §3 and §6).
- **"Escaped and already dead" and "escaped and still alive" must both read as owned.**
  The predicate is about final state, not about whether a signal was sent.
- **Non-membership must be provable too**, for the "live tree survives" control (§5,
  N2): a pid *not* in the snapshot must be untouched, checked the same way (still present,
  same start-time).

## 2. The verbs' contract

Two verbs, not one, because the escape mechanism (§3) creates a case — the normal-exit
path — where the root pid is already gone by the time anyone can ask about it. A verb that
only takes a live pid cannot serve that call site.

### `managent snapshot-tree <pid>`

- **Purpose**: emit the current transitive descendant closure of `pid`, computed from one
  process-table read, so a caller can hand it to `kill-tree` later even if `pid` dies
  first.
- **Output (stdout = data, per the project convention already in force at
  `src/managent/main.zig:44-49`)**: one line per member, `<pid> <ppid> <pgid> <start_epoch>
  <comm>`, root included.
- **stderr = diagnostics** (`src/managent/main.zig:51-53`): nothing on success; a note if
  `pid` itself is already gone (empty member list is not an error).
- **Exit codes**: `0` always, except `1` for usage error (missing/non-numeric arg). A
  vanished or childless root is a valid, successful snapshot of zero or one member — a
  caller checks the *content*, not the exit code, for "found nothing."

### `managent kill-tree (<pid> | --from-snapshot <path>) [--signal TERM|KILL] [--grace-ms N]`

- **Live-pid mode**: takes its own snapshot first (so `kill-tree R` alone is always safe
  to call — it never requires a prior `snapshot-tree`).
- **Snapshot mode**: uses a snapshot captured earlier by `snapshot-tree`, for a root that
  may no longer be discoverable live (§3, §6).
- **Output**: stdout one line per member — `killed <pid> <ppid> <comm> sig=<N>` or `skip
  <pid> reason=<already-dead|start-time-mismatch|not-owned>` — then a summary line
  `summary root=<pid> members=<n> killed=<n> skipped=<n> residue=<n>`. Residue > 0 is the
  one line a caller must check before assuming success.
- **Exit codes**: `0` fully owned (§1) including the no-op case; `1` usage error; `2`
  ownership guard refused — see §4; `3` absolute-refusal guard tripped (pid 1 or another
  entry on the never-kill list, §4); `4` signaled but residue remains after grace + one
  retry — a partial failure must not read as success.
- **Already dead**: exit `0`, `members=0` or all `skip already-dead` — idempotent, because
  §6 requires calling this on *every* exit path, including ones where nothing escaped.
- **Not ours**: exit `2`, nothing signaled.
- **pid 1**: exit `3`, unconditionally, before any other check runs.

Precedent for the stdout/stderr split and for a conservative-on-doubt liveness probe
already exists in this binary: `processAlive()` at `src/managent/main.zig:6180-6189` treats
any error other than `ProcessNotFound` from `kill(pid, 0)` as "alive," with the comment "the
reaper never closes a row it cannot prove dead." The same principle should govern
`kill-tree`'s residue determination — a pid whose status is ambiguous is reported as
residue, never silently as killed.

## 3. The measured escape mechanism, and its residue

Taken as given (measured 2026-08-20, this repo, production chain, not re-derived here):
the [SELF-IDENTIFICATION REDACTED] console harness starts every tool command in a new session; zig 0.16 creates
none. Independently confirmed in this session: `SpawnOptions.pgid` defaults `null` at
`std/process.zig:397` (zig 0.16.0, installed at
`/opt/homebrew/Cellar/zig/0.16.0_1/lib/zig/std/process.zig`), and a `grep` of that file for
`setsid`/`setpgid` returns zero matches — the build path creates no session or group of its
own at any point, not just at line 397.

**Consequence the verb design must absorb, and which I believe no other reading of this
brief states as sharply: the root pid is not always live when `kill-tree` is called.**
`tools/runner`'s poll loop breaks out at `tools/runner:1311` the instant `proc.poll()`
reports the direct child has exited, and falls through — with nothing in between — to
`ret = proc.wait()` at `tools/runner:1538`. Standard POSIX/Darwin semantics reparent an
exited process's surviving children to the nearest subreaper (init/launchd) *synchronously
at that exit*, not on a delay. So by the time anything downstream of line 1311 could call a
kill-tree verb, the tree's children have already lost the ppid link back to the dead root —
a *live*-pid enumeration from the root finds nothing, not because nothing escaped but
because the discovery mechanism was severed by the very event that triggers the call.
**I have not independently reproduced this reparenting-timing claim in this repo this
session — it is standard OS behavior, not a repo-local measurement, and I flag it in §9 as
the first thing the Design/Test phase should verify with a two-line fork/exit/ps probe
before relying on it.**

This is exactly why §2 specifies two verbs: `tools/runner` must call `snapshot-tree` while
the direct child is still alive — its poll loop already samples on a cadence
(`poll_s` at `tools/runner:1139`, printed at `tools/runner:1180`) that is a natural, already
existing hook — and hand the *last snapshot before exit*, not the bare pid, to `kill-tree`
on the normal-exit path (§6). A spec or plan that says only "call kill-tree(pid) on normal
exit too" has not closed the gap it thinks it closed.

**Race inside the walk itself** (a parent dying *during* the snapshot, not before it): a
single process-table read is not perfectly atomic across all pids, but membership is
determined once, from that one read, and killed by pid+start-time thereafter — a target
that reparents to init between snapshot and signal is still in the kill set, because
nothing after the initial read re-derives membership via ppid. This is what makes the
predicate in §1 attainable rather than aspirational.

**Per-family residual check (owed, not yet run).** The measurement above covers `claude
-p` only. Before the seeded controls in §5 are finalized, run, once per other console
family ([SELF-IDENTIFICATION REDACTED] CLI, ollama-subagent), against a live tool-command invocation of that
family:

```
ps -o pid,ppid,pgid -p <tool-command-pid>
```

plus a `getsid` check on the same pid (not `ps -o sess` — macOS prints `0` there
unconditionally per the brief's own measurement, so that column is not evidence). Compare
the tool-command's `pgid`/session id to its parent console's. If they match, that family's
tool commands do **not** escape their console's session — `killpg` against the console
would already reach them, and `kill-tree` is a safe superset (it does not use pgid/session
at all, so it does not care either way). If they differ, that family exhibits the same
escape shape as `claude -p` and needs the same tree-walk. **This check has not been run in
this session** — I did not have another console family's live tool-command pid to sample
against.

## 4. Safety

This verb kills processes on a live, shared machine. The seat ran an untested reaper on
2026-08-20 with three hand-reasoned guards — that is exactly the failure mode to not
repeat: a guard is not safe until a seeded control proves it fires and a null control
proves it doesn't over-fire.

| Guard | Statement | Control (see §5) |
|---|---|---|
| **G1 — ownership/provenance** | Refuse any target the caller cannot demonstrate it spawned. Pid number alone is not proof — pids recycle. Provenance must include the process's actual start-time, captured by the caller at spawn and passed to `kill-tree`, checked against the live process's start-time at signal-time. | S5 (not-ours), S7 (pid-reuse) |
| **G2 — absolute refusal list** | pid 1 is refused unconditionally, before any other check. This is a hard-coded, not a configurable, refusal. | S6 |
| **G3 — uid boundary** | A member whose uid differs from the caller's is never signaled, ownership claims notwithstanding (shared-host safety). | (implied by S5; make explicit in Design) |
| **G4 — downward-only walk** | Enumeration is strictly ppid-transitive-descendant. The console harness, the runner, and `managent` itself can only enter the kill set if passed *directly* as the root — walking never goes sideways or upward, so this is a structural property of the algorithm, not a checklist item, and should be asserted as an invariant test on the walk itself, independent of any specific pid guard. | N2 |
| **G5 — no silent partial success** | A `kill-tree` call that cannot verify every member dead exits `4` and reports `residue=<n>` on stdout. Callers (including `tools/runner`) must treat exit `4` as failure, not as "close enough." | S3, S8 |
| **G6 — idempotent by construction** | Calling `kill-tree` on an already-fully-dead tree, or calling it twice concurrently on the same root, returns `0`/no-op rather than erroring — required because §6 calls it on *every* exit path unconditionally, including the common case where nothing escaped. | S4 |

**A guard the existing codebase has that does *not* cover this verb, and which I think is
worth flagging explicitly:** `src/managent/main.zig:218-223` lists `mutating_verbs` and
`refuseLiveWrite` (`main.zig:225-230`) refuses to let a test/fixture write the *live kanban
store* unless `MANAGENT_STORE` points at a scratch path. That guard protects kanban state.
It does nothing for a verb that kills real host processes — a test invoked against
`MANAGENT_STORE=/tmp/scratch/tasks.json` gets zero protection from accidentally
`kill-tree`-ing a real, unrelated live process if its test fixture passes the wrong pid.
G1+G4 above are the actual guard for that risk (ownership provenance + downward-only walk,
which together mean a test can only ever kill trees it *itself* spawned), and the seeded
controls should include one that spawns a fixture tree, calls `kill-tree` on it, and
separately asserts an *unrelated* live process (not spawned by the test, e.g. the test
runner's own shell) is untouched — this is N2, and it is doing safety work the existing
`refuseLiveWrite` mechanism was never designed to do.

**Never killable, regardless of ownership claims**: pid 1 (G2); any pid whose uid does not
match the caller's (G3); the `managent` process's own pid and the calling `tools/runner`
process's own pid, as an explicit deny-list entry, not merely an accident of G4's
downward-only walk (belt-and-suspenders — G4 makes this structurally near-impossible, the
deny-list makes it impossible even if the ownership check is ever loosened later).

## 5. Controls, named not written

Following the shape already established by `tools/regression-orphan-reaper.sh` (T364:
seven named null/seeded arms, kanban orphans) — this is its process-orphan counterpart and
should live in its own file, not be folded into that one, precisely because the brief's
own finding is that "orphan" already means two unrelated things in this codebase.

| ID | Arm | Asserts |
|---|---|---|
| N1 | null | `snapshot-tree` on a live, childless process → exactly one member, exit 0 |
| N2 | null (**required**) | a live, unrelated process tree not named as root is byte-for-byte untouched (same pids, same start-times) after a `kill-tree` call elsewhere — the "live tree must survive" control the brief requires at minimum |
| S1 | seeded (**the point**) | a ≥3-generation tree built to escape by the measured mechanism (§3): `kill-tree` on the live root leaves zero live members within grace+timeout |
| S2 | seeded | reparenting mid-walk: an intermediate node is made to exit between snapshot and signal; the reparented grandchild still dies, because it was captured by the initial snapshot, not re-derived from live ppid |
| S3 | seeded (**the point, §3/§6**) | the normal-exit case: let the root exit naturally so its live children reparent to init *before* any kill-tree call; assert live-pid mode on the (now-dead) bare root finds nothing (documents the gap), and `kill-tree --from-snapshot` using a snapshot captured *before* the root's exit finds and kills them |
| S4 | seeded | idempotency: two back-to-back `kill-tree` calls on the same already-dead root both exit 0, no error on the second |
| S5 | seeded | not-ours: target not spawned by the caller (no valid provenance) → exit 2, untouched |
| S6 | seeded | pid 1 → exit 3, unconditionally |
| S7 | seeded | pid-reuse: a snapshot entry's recorded start-time is made to mismatch the live process at that pid → skipped, reported `start-time-mismatch`, not signaled |
| S8 | integration | run `tools/runner` end-to-end over a fixture that forks an escaping tree and exits normally (not via the ceiling); assert zero residual processes system-wide after the runner exits — the actual cannibalization proof, not just a unit test of the verb |

## 6. The cannibalization step

Pass 1 is not done when the verb exists. Two call sites, both required:

1. **`tools/runner:1505`** — `os.killpg(proc.pid, signal.SIGKILL)` is deleted and replaced
   with a live-pid `managent kill-tree <proc.pid> --signal KILL` call. This path already
   has a live, known-good pid at the moment it fires, so live-pid mode is sufficient here;
   no snapshot needed. (`os.setsid()` at `tools/runner:1161` becomes non-load-bearing for
   the kill itself once this lands — it may still be worth keeping for diagnostics, but
   that is a cleanup call for Design, not this spec.)
2. **The normal-exit path** — currently `tools/runner:1298-1311` breaks out of the poll
   loop on ordinary completion and falls straight through to `ret = proc.wait()` at
   `tools/runner:1538`, reaping only the direct child. This must become: (a) the existing
   poll-loop cadence (`tools/runner:1139`, `1180`) periodically calls `snapshot-tree` on
   the direct child and keeps the latest snapshot; (b) immediately after the break at
   `tools/runner:1311`, unconditionally call `managent kill-tree --from-snapshot
   <last-snapshot>` before falling through to line 1538. "Unconditionally" matters — per G6,
   the common case where nothing escaped is a zero-cost no-op, so there is no need to
   special-case "did anything escape."

A pass-1 acceptance check: `grep -n killpg tools/runner` returns nothing, and every exit
path in `tools/runner` (ceiling-kill, normal-exit) reaches a `kill-tree` call before the
function returns.

## 7. One dispatch interface for every harness

The operator's requirement is that one command work correctly for every console family
without per-family branching. `kill-tree`/`snapshot-tree` satisfy this **by construction,
not by additional design**: both verbs operate purely on the OS process table — pid, ppid,
uid, start-time — and never inspect pgid, session id, or anything else that varies by
which harness or model spawned the tree. §3 already established that the escape shape
(new session vs. not) differs by family; the verb doesn't need to know which shape it's
looking at, because ppid-transitive enumeration finds the tree either way. A family whose
tool commands stay inside the console's session gets a strict superset of what `killpg`
already did for it; a family that escapes like `claude -p` gets the tree-walk it needs.
**The one thing this spec asks the next pass to preserve**: do not let a future call site
pass session- or pgid-derived information into these verbs as a shortcut for a particular
family — that would silently reintroduce per-family branching through the back door.

## 8. Explicit non-goals

- **The runner-death case** — a SIGKILLed `tools/runner` reaps nothing, because nothing
  downstream of it ever runs. Stated non-goal for pass 1; that is `T548`'s sweep, and later
  the supervisor's held handles.
- **No new supervisory process.** Nothing in this spec watches `tools/runner` or
  `managent`; the fix is that the mechanism works on every exit path already reachable in
  `tools/runner`, not that something external notices when it doesn't.
- **`managent` does not become a daemon.** Both verbs are short-lived, single-shot CLI
  invocations, matching the binary's existing shape.
- **`bin/dispatch` is untouched.** Its `start_new_session=True` at `bin/dispatch:301` is
  the top-level detach, a separate concern from `tools/runner`'s child management; pass 1
  does not revisit it.
- **The one-dispatch-interface unification itself** (§7) is a later pass. This spec only
  constrains the *shape* of the ownership verb so that pass doesn't have to redo it.
- **State consolidation and dashboards** are later passes, per the registered ladder.

## 9. Uncertainties

- **Reparenting-at-exit timing (§3)** is standard POSIX/Darwin behavior, not something I
  measured in this repo this session. It is the load-bearing assumption behind the
  two-verb contract and should be the very first thing verified in Design/Test — a
  two-line fork/exit/`ps`-the-child's-ppid probe, cheap enough to be its own null control.
- **Per-family residual check (§3)** for [SELF-IDENTIFICATION REDACTED] CLI and ollama-subagent has not been
  run; I had no live tool-command pid from those families to sample. This spec names the
  exact command; it does not report a result.
- **Provenance mechanism for G1** — I specify the requirement (start-time-backed proof of
  spawn, not bare pid equality) but leave the exact plumbing (how `tools/runner` captures
  and passes its child's start-time) to Design; several equally-valid mechanisms exist.
- **Snapshot atomicity under load** — whether a single process-table read is fast/atomic
  enough under the measured OOM conditions (9.1 GB, 0.06 GB free) to avoid missing a
  reparenting event inside its own read window is not established; may need a
  fixed-point double-read in Design.
- **Scope check**: I believe pass 1 as scoped here is right-sized — it is bounded to two
  verbs and two call sites, has a concrete cannibalization criterion (§6's grep check), and
  does not require touching `bin/dispatch` or building a daemon. The one place I'd push
  back if asked to shrink further: dropping `snapshot-tree` and only shipping `kill-tree`
  would look smaller but would silently fail to close the normal-exit gap (§3), which is
  half of what pass 1 was asked to fix (§6, item 6 of the brief).

## Best contribution (self-assessed)

§3's finding that **the root pid is not always live when `kill-tree` is called** — because
`tools/runner`'s normal-exit path (`tools/runner:1298-1311` → `1538`) only reaches a kill
call *after* the parent-death reparenting that severs the ppid discovery link has already
happened — and the resulting two-verb contract (§2) and its dedicated control (S3, §5) are
the parts of this spec I'd most want carried into consolidation even if nothing else
survives. A design that says "call kill-tree(pid) on normal exit too" without this
distinction will pass every test where the escaping tree is still alive and silently fail
the exact case (§6, item 6) pass 1 was asked to close.
