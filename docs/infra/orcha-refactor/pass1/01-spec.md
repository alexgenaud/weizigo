# Pass 1 — consolidated spec: `managent treekill`, a process-tree ownership verb

Consolidated from the eight anonymized tournament documents by aspect selection
(operator ruling: committee chooses the parts, one hand makes them agree). Provenance
table at the end. All file:line citations below were re-verified against the working
tree on 2026-08-20; `tools/runner` has drifted +49 lines since the tournament brief
was frozen (the brief's `killpg` at `:1505` is now at `tools/runner:1554`). The
brief's line numbers are not repeated here except as corrected.

**Scope.** One Zig verb inside `src/managent/main.zig` (the existing 8,780-line
binary), invoked as a short-lived CLI by the Python `tools/runner` on every exit
path. Given a spawned child — live or already dead — it enumerates and reliably
terminates every reachable descendant. Not a daemon. This document is the spec; the
controls are named, not written; no code.

---

## 1. What "owned" means, testably

**Definition.** The process tree rooted at pid R is *owned* by caller C iff C spawned
R and C can invoke the verb, at any time up to and including after R's own exit, to
terminate every live enumerable member of R's tree.

Five assertions, each assertable by a control (§5) with an oracle independent of the
verb's self-report:

- **OWN-1 (enumerability, live root).** From a live R, the verb's target set is a
  *superset* of the ppid-chain descendant walk of R — equal to it only on a
  churn-free, same-session tree — because the sid/pgid/seed edges reach descendants
  that changed process group or session, which the ppid-only walk cannot. → Arm S1.
- **OWN-2 (reach, dead root).** From a dead R that was a session leader, the verb
  reaches every surviving member with `sid == R`, including members reparented to
  init; with a seed list (§2), it also reaches members of nested sessions whose own
  leaders died. → Arms S2, S3. This is the assertion the measured leak demands.
- **OWN-3 (confinement).** After a kill, the set of newly-dead pids is a subset of
  (target set ∪ {R}), measured by a `ps` diff *scoped to* (target set ∪ {R})
  before/after — a pid outside that set is out of scope, not evidence either way;
  the diff is never host-wide (host processes we didn't touch are the untestable
  Non-condition above, not part of this oracle). → Arms N2, S1.
- **OWN-4 (exit-path totality).** The runner leaves zero live enumerable descendants
  of its spawn on its ceiling, normal-exit, and exception paths. → Arms I1, I2, I3
  (all three fail today: the normal-exit path after `tools/runner:1587` and the
  exception path at `:1588-1592` both reap nothing).
- **OWN-5 (closure-recompute postcondition).** After a settle window, recomputing the
  closure (§3's edges) over a *fresh* process-table snapshot from the claimed set —
  including the sid keys of every claimed session leader — yields zero live members.
  This is what catches a child forked after the verb's own snapshot; OWN-1..4 alone
  are what a naive implementation passes. → Arms S1, S4.

"Owned" is asserted by process-table observation, never by the verb's own counters:
every seeded arm cross-checks the verb's stdout numbers against an independent `ps`
scan, and a disagreement is a FAIL (standing rule: impossibly clean counters are red
flags).

**Non-condition.** "Robust", "reliable", "no orphans on the host". The host has
processes that are not ours; a spec that asserts anything about them is untestable
and unsafe.

---

## 2. The verb's contract

**Name: `treekill`.** Not `reap` — `managent reap` is the live T364 *kanban*-orphan verb
(`src/managent/main.zig:471`, listed in `mutating_verbs` at `:222`; its regression
script greps `managent help` for the string, `tools/regression-orphan-reaper.sh:99-101`).
Reusing the word would re-commit the exact one-word-two-meanings error the brief
names. The T364 verb, its name, and its script are untouched.

```
managent treekill --anchor <pid> [--kill] [--seed <pid,pid,...>] [--since <epoch>]
             [--protect <pid>]... [--rounds <n>] [--settle-ms <n>] [--ps-fixture <path>]
```

- `--anchor <pid>`: required; strictly decimal. The pid the caller spawned.
- `--kill`: the only mode that signals. **Read-only is the default**: without
  `--kill` the verb enumerates, prints, and exits — a mistyped invocation is inert,
  and the report mode is the controls' measurement instrument.
- `--seed <pids>`: additional closure roots — the caller's last known descendant
  list, for members of nested sessions whose leaders are already dead (§3). The
  runner already computes this list every poll (`tools/runner:1402`).
- `--since <epoch>`: start-time floor when the anchor is dead (the runner records
  spawn time in the run record it writes at launch, `tools/runner:1295-1305`; today
  that field is an ISO-8601 UTC string stamped *after* `Popen` at `:1304` — the
  runner must instead record, or `treekill` must parse, an epoch, and the runner must
  stamp it *before* `Popen`, or the floor can land strictly after the anchor's true
  start and G4 can exclude the anchor's own tree). Default when the anchor is live:
  the anchor's own start time. There is no default when the anchor is dead: the
  two dead-anchor call sites (C2, C3) must always pass the run record's `--since`
  explicitly — omitting it leaves G4, the only pid-reuse guard on the seed list,
  vacuous at exactly the call sites this pass exists to add.
- `--protect <pid>`: added to the never-kill set; repeatable.
- `--rounds <n>` (default 5): a single shared budget spent across both the closure
  fixpoint (§3 step 3) and the kill/verify loop (§3 step 6) — not two separate
  allowances. `--settle-ms <n>` (default 250): bounds.
- `--ps-fixture <path>`: canned process table for parser tests; **implies
  read-only** — `--kill --ps-fixture` is a usage error (guard G9). The fixture
  schema carries no sid column — `getsid(2)` is a live per-pid syscall, not
  fixture-substitutable — so fixture mode exercises the ppid/pgid/start-time edges
  only; the sid edge is untested in fixture mode (S7).

**Signal.** SIGKILL only. Both existing call sites already SIGKILL
(`tools/runner:1481`, `:1554`); a graceful-TERM knob is a moving part with no
measured need.

**Exit codes.** Distinct codes are load-bearing: a control cannot distinguish
"correctly refused" from "failed to kill" through a shared code. This deviates
from `managent`'s existing uniform `exit(1)` convention (e.g.
`src/managent/main.zig:225-230`'s `refuseLiveWrite` refusal): `treekill` kills real
host processes, so a control needs to tell refusal, internal failure, and
non-convergence apart on sight, which a single code cannot do.

| code | meaning |
|---|---|
| 0 | converged — report printed, or every claimed pid confirmed dead (OWN-5); includes the empty set. A dead anchor with nothing surviving is exit 0, `root=dead`, idempotent |
| 2 | usage error (missing/non-decimal `--anchor`; `--kill` with `--ps-fixture`) |
| 3 | internal failure — a `ps`/`getsid` read error or an allocation failure; never silently downgraded to an empty process table (D-31) or to exit 0 |
| 4 | refused by guard — **nothing was killed** (a frozen frontier may already have been SIGSTOPed before validation ran; it is resumed via SIGCONT, §4 G7); this is the *total-refusal* reading only — a same-closure other-uid member is excluded-and-counted, not a total refusal, and does not produce this code by itself (§4) |
| 5 | not converged — survivors remain after `--rounds`; each named on stdout; the loud failure |

There is no "anchor already dead" error. The dead anchor is the load-bearing case
(the measured leak shape), not an edge case: the closure proceeds from
`sid == anchor` and the seed list exactly as if the anchor were live.

**Output shape** (project convention: stdout = data, stderr = diagnostics;
`docs/infra/managent/spec.md` §Output streams, `AGENTS.md:128-131`; regression
check: `2>/dev/null` emits data, `1>/dev/null` is silent).

- stdout, one record per claimed pid, tab-separated:
  `pid ppid pgid sid start_epoch rss_kb action comm`
  where `action ∈ {report, killed, vanished, refused, survived, protected}`
  (`frozen` dropped: no mode ever emits it — read-only prints `report`, and
  `--kill` mode's SIGSTOP is transient/internal, never surfaced as its own action).
- stdout, final line, always:
  `treekill anchor=<pid> root=<live|dead> claimed=<n> killed=<n> refused=<n> survivors=<n> rounds=<r>`
  — the line the runner copies into the run record (§6 C6).
- stderr: `[treekill]`-prefixed diagnostics, refusal reasons, per-pid errors. Never data.

**Edge behaviour.**

| target | behaviour |
|---|---|
| anchor never existed / long dead, no session survivors | exit 0, `claimed=0 root=dead`; `ps` unchanged (Arm N1) |
| pid ≤ 1 | exit 4, refused before any enumeration; pid 1 is never claimable under any flag |
| anchor not ours (`uid != geteuid()`) | exit 4; other-uid *members* are never signaled, counted `refused` (§4 G8) |
| verb's own pid, or any ancestor of it | exit 4 (§4 G3) |
| pid reused since spawn | **not reliably excluded**: the `--since` floor is a lower bound — a pid recycled *after* spawn starts after the floor and passes it; such a bystander is indistinguishable residue (trust boundary, §4), not "never claimed" |
| two concurrent invocations on one tree | both exit 0; no error, no double-kill report (Arm N4) |

**Caller obligations.** The runner passes only pids it recorded at spawn or observed
in its own poll walk — never argv/env-derived input. Any nonzero exit, or the verb
dying by signal, is logged by the runner as a leak incident ("unknown-partial",
never "clean"), without blocking the runner's own exit.

---

## 3. The measured escape mechanism, its residue, and the per-family check

**Taken as given (measured 2026-08-20, this repo, production chain), restated only to
build on:** the console harness starts every tool command in a new session (shell
`pgid == sid == own pid`); zig 0.16 creates no process group or session for build
children (`SpawnOptions.pgid` defaults null, `std/process.zig:397` in the installed
0.16.0 tree at `/opt/homebrew/opt/zig/lib/zig`, and that file contains no
`setsid`/`setpgid` anywhere). Escapees are session leaders, so group- and
session-level kills are structurally insufficient; only descendant enumeration
reaches them. Observed: 6 orphans → ~4.5 GB → 9.1 GB (free 0.06 GB) → 2.8 GB
recurring at 25–27 GB free — continuous, not crisis-driven. macOS has no cgroups.

**Verified sharpenings from the current tree (each checked 2026-08-20):**

1. The runner's `setsid` is **spawn-time for every run** — preexec defined at
   `tools/runner:1210`, applied at the `Popen` at `:1290` — not ceiling-gated as the
   brief's phrasing suggests; only the `killpg` is ceiling-gated (`:1554`). So every
   runner child is a session leader with `sid == child pid`, and the dead-root
   catch-all needs **no spawn change**. The T364 run record, written before any exit
   path can run, already stores that identity (`"pgid": proc.pid` at
   `tools/runner:1302`) and the spawn time (`"start"`, `:1304`).
2. The runner **already enumerates the descendant tree every poll** for RSS
   accounting (`_descendant_pids_ps` at `tools/runner:609`, selected into
   `_WALKER_FN` at `:647`, used at `:1402`), and its `--sweep` mode exists "to help
   find orphaned zig processes" (`tools/runner:5`, `:51-52`). Descendant enumeration
   is proven in production here; the Zig verb re-implements the primitive and the
   Python walker becomes its differential oracle (§5 arm S6, §6 C5).
3. **`getsid` is absent from `std/c.zig`/`std/posix.zig`** — Zig 0.16's macOS entry
   points — though it is present in the Linux backend (`std/os/linux.zig:2157`)
   and simply not linked on this target; only `setsid` exists in `c.zig`
   (`std/c.zig:11015`). One `extern "c" fn getsid(pid: std.c.pid_t) std.c.pid_t;`
   declaration covers macOS. `ps` cannot substitute: macOS `ps -o sess` prints 0
   (measured).

**Closure and algorithm (freeze → fixpoint → validate → kill → verify).**

Member set = least fixpoint, over a fresh process-table read per round
(`ps -axo …` via the existing `runCommand` helper, `src/managent/main.zig:8731`,
plus `getsid(2)` per candidate — a `runCommand` result with a nonzero exit status
is an internal failure (exit 3), never read as an empty process table, since a
failed scan must never look like convergence), of same-uid processes P with
`start_time(P) ≥ since` and:

> `ppid(P)` ∈ set ∪ {anchor} — **or** — `sid(P)` ∈ {anchor} ∪ {pid of any claimed
> session leader} — **or** — `pgid(P)` ∈ {pgid of any member} — **or** — P ∈ seed
> list.

**Downward constraint (D-19):** a candidate is admitted only if it is a descendant
of the anchor or in the seed list; the sid/pgid edges reach *within* that descendant
set and never admit an ancestor or sibling of the anchor. A group- or session-keyed
edge that would reach upward is rejected, not followed.

1. **Identify.** Resolve the anchor (live: capture start time; dead: proceed — the
   sid term and seed list carry the closure).
2. **Freeze** (`--kill` only; skipped in read-only mode). SIGSTOP the current
   frontier. A stopped process cannot fork and cannot exit *spontaneously*, so it
   cannot reparent its children mid-walk — this converts the unbounded reparent race
   into one bounded by the fork latency of not-yet-stopped members. Read-only mode
   freezes nothing: the "inert, signals nothing" contract (G2, N3) is real, not
   aspirational. **Completion check:** before advancing to step 3, confirm each
   just-frozen pid shows `T` (stopped) state — the same observable N2 already
   checks — rather than assuming SIGSTOP delivery is instantaneous; a pid not yet
   stopped stays in the frontier and is re-frozen next round instead of being
   treated as settled.
3. **Close.** Re-snapshot; add new members by the edges above; repeat 2–3 until the
   set stops growing or `--rounds` is exhausted (loud exit 5).
4. **Validate.** The *whole* closure is checked against §4's guards before the first
   SIGKILL. On refusal: SIGCONT everything frozen, exit 4. Freezing precedes
   validation by necessity (the closure is unknown until the walk finishes), so the
   rollback is mandatory, not optional.
5. **Kill** (`--kill` only). SIGKILL every member — SIGKILL is delivered to stopped
   processes, no SIGCONT needed. Read-only mode never stopped anything (step 2
   skipped), so it prints the report and exits — nothing to SIGCONT.
6. **Verify.** Sleep `--settle-ms`, re-snapshot, assert OWN-5. Survivors → one more
   round if budget remains, else exit 5 with each survivor printed `action=survived`.

**Residue, stated:** (r1) reparent-to-init mid-walk — closed by the freeze plus the
fact that sid survives reparenting. (r2) dead session-leader root — closed by the
sid term with no spawn change. (r3) **nested sessions**: the console harness setsids
each tool command, so a build tree's members carry `sid == tool-shell pid`, not
`sid == runner-child pid`; once both the tool shell and the runner child are dead,
no live edge reaches them. Closed *at the runner's call sites* by `--seed` from the
last poll walk (`tools/runner:1402`) — members observed while alive stay claimable
by pid+start-time after every edge is severed. (r4) a child forked after the last
poll snapshot whose intermediate sessions all died before the verb ran, and a
descendant that daemonized via its own setsid after scrubbing every edge — genuinely
unreachable by any same-uid userland mechanism; **assumed zero, unmeasured**: no
control seeds a forked-after-snapshot case, so the production rate is a stated
unknown (OQ2), and if T548's sweep ever observes a nonzero count it is a finding
with its number. The runner-death case (nothing calls the verb) is a stated non-goal
→ T548.

**Per-family residual check (owed before the seeded controls are final for any
family).** The measurement covers `claude -p` (`bin/subagent:252`), but that
founding measurement carries no deposited artifact yet, unlike the other families
below — it is owed the same `docs/evidence/<claim-id>/` deposit this section
requires of everyone else, re-run through the probe below if the original run left
no record. The other live
families are the DeepSeek CLI (`pi --provider deepseek`, `bin/subagent:247-251`) and
ollama (`bin/subagent:270`). Once per family, run a probe command through that
family's harness while a real dispatched worker is mid-run:

```sh
ps -axo pid=,ppid=,pgid=,uid=,comm= > /tmp/treekill-snap-<family>.txt
python3 - <<'EOF'    # sid per pid; macOS `ps -o sess` prints 0 — getsid(2) is the only session reading
import os
for l in open("/tmp/treekill-snap-<family>.txt"):
    p = int(l.split()[0])
    try: print(p, os.getsid(p), os.getpgid(p))
    except ProcessLookupError: pass
EOF
```

Record per family: (a) is the tool-command root a session leader
(`pgid == sid == own pid`)? (b) is the runner's child a session leader at spawn
(expected yes, `tools/runner:1210`)? (c) does anything in the chain change session?
(d) how deep is the tree to the deepest compile child? Deposit under
`docs/evidence/<claim-id>/` with a per-family PROVEN/CLAIMED status. Gate: arms
S1–S3/I1/I2 are final for a family only after its record lands; until then they are
final only for `claude -p`. A family that does *not* setsid its tool commands needs
no design change — the sid term simply contributes no members, and that family's arm
proves the verb does not over-claim.

---

## 4. Safety

The seat ran an *untested* reaper on 2026-08-20 with three hand-reasoned guards.
Every guard below therefore names its control (§5); a guard without a control is not
a guard. Note the existing `refuseLiveWrite` mechanism
(`src/managent/main.zig:225`) protects the *kanban store* only — it does nothing for
a verb that kills real host processes; the guards below are that verb's actual
protection.

**Never signaled — two different consequences, not one:**

- **Excluded-and-continued** (this member is skipped, counted `refused`; the rest
  of the closure still proceeds): a same-closure member whose uid ≠ `geteuid()`
  (G8).
- **Refused-everything** (any one of these anywhere in the closure refuses the
  *whole* operation, nothing killed, exit 4): pid 0 and pid 1; kernel tasks; the
  verb's own pid and every pid on its ancestor chain (which includes the calling
  runner and the operator's console); the session leader of the verb's own
  session; every `--protect` pid; every pid in the protected set (G3, G5, G6).

There is no `--force` and no anchor-less "reap the host" mode.

| # | guard | failure mode it blocks | control |
|---|---|---|---|
| G1 | anchor must be > 1 and (if live) same-uid; refuse otherwise | killing init or someone else's work | S5 |
| G2 | read-only default; `--kill` is the only signaling path | a mistyped invocation being destructive | N3 |
| G3 | self/ancestor/own-session-leader exclusion | the verb killing its caller or the console | S5 |
| G4 | start-time monotonicity: never claim `start_time(P) < since` | excludes pre-spawn processes only; post-spawn pid reuse is a one-sided gap the floor cannot close — stated, not prevented (S7 tests the older-than-floor direction; the recycled-newer-than-floor direction is residue) | S7 |
| G5 | atomic pre-flight: the whole closure validates before the first SIGKILL; any violation refuses the whole operation | half-killed trees, worse than untouched ones | S8 |
| G6 | protected set: the `pgid` field (the anchor pid, `tools/runner:1302`) of every *other* row's run record (`untracked/runs/<task>.json`, written at `tools/runner:1295-1305`) whose record has no `exit`/finalize field yet (the in-progress discriminator) and is younger than an expiry TTL; intersection ⇒ exit 4 naming the task id. Known limits: a run record holds only the runner pid and `pgid`, no deeper descendants, so protection stops at that one pid per row; a degraded-identity run that wrote no record contributes nothing to the set; a record whose runner was SIGKILLed and never finalized is not protected forever — it expires. **Known property:** under the current flat dispatch topology this guard does not fire on any real closure (no other worker's pid lands in a closure by construction, and G4 already blocks recycled-pid matches) — it is defense-in-depth of uncertain value, exercised only by S8's fabricated overlap | one worker's cleanup killing another worker's recorded anchor pid (not its deeper descendants, and not an unrecorded or expired row) | S8 |
| G7 | rollback: refusal after freezing SIGCONTs every stopped pid before returning | a refused call leaving the fleet suspended — a silent, total outage | S8 |
| G8 | no elevation: a same-closure member with uid ≠ `geteuid()` is pre-filtered out *before* any signal is attempted (never signaled, never an EPERM round-trip) → counted `refused`, exit reflects survivors; never escalated, never silently skipped | cross-user kills; dishonest "clean" reports | S5 (environment-gated) |
| G9 | `--ps-fixture` implies read-only; `--kill --ps-fixture` = exit 2 | ever killing live pids from a canned table | S7 |
| G10 | bounded rounds and loud non-convergence (exit 5); no silent partial success — exit 0 iff OWN-5 holds by the verb's final scan *and* the control's independent scan | unbounded loops; leaks reported as success | S3, S4 |

**Known interference, stated not controlled:** SIGSTOP/SIGCONT is unowned global
process state, not scoped to an invocation. G7's rollback SIGCONTs *every* pid it
itself froze, which is safe in isolation, but a second concurrent invocation whose
closure overlaps the first's can have its own still-frozen frontier resumed by the
first invocation's rollback. N4 exercises only the both-`--kill` case; a concurrent
read-only-or-refused × freeze case is not controlled and is recorded here as a
known, unresolved interference rather than silently assumed safe.

**Trust boundary, stated not hidden:** when the anchor is dead, spawn-ancestry is
unverifiable; the kill set is then confined to the sid term, the seed list, and the
start-time floor, and the caller's assertion that it spawned the anchor is the
boundary. The verb defends against mis-targeting and accident, not against a
malicious caller — who could already run arbitrary commands as this user.

---

## 5. The controls, named but not written

New file `tools/regression-process-ownership.sh` — **not** folded into the T364
script (different concern; the name collision is documented in §2, not resolved by
renaming). Conventions per the T364 script: scratch tree under `/tmp/weizigo`,
`$MANAGENT_BIN → zig-out/bin/managent → bin/managent` resolution
(`tools/regression-orphan-reaper.sh:48`), skip-loudly when the verb is absent, FAIL
counter, exit 0/1. **Test-first:** the script is written and run before the verb
exists. Per the T364 skip-loudly convention: while `treekill` does not exist, every arm
that calls it skip-loudly, not fail — that is expected, not a red result. Once the
verb exists but is wrong, arms S2, S3, I1, I2, I3 must fail red; only then does the
verb get built out to green. Per-arm denominators (tree sizes, sleeps, settle) are
fixed in the script.

| arm | kind | seed | asserts |
|---|---|---|---|
| N1 | null | a pid that never existed (2^31−1) | exit 0, `claimed=0 root=dead`, one parseable stdout line, `ps` unchanged |
| N2 | null (the mandated survivor) | a second tree in its own session built by the same generator as S1, plus a fabricated in-progress run record for it (as S8 fabricates, not a live worker — the scratch-store rule keeps this off the live kanban) | after `--kill` on A's tree: every pid of tree B alive and unstopped (no `T` state), B's row untouched (OWN-3) |
| N3 | null | read-only invocation on a live tree | full report printed, nothing signaled, nothing stopped afterwards |
| N4 | null, concurrency | two concurrent `--kill` runs on one tree | both exit 0, no double-kill report |
| N5 | null, instrument | force `runCommand`'s `ps` read to fail (e.g. an unreadable `--ps-fixture` path, or the binary renamed away in a sandboxed run) | exit 3; never a bare exit 0 empty-set report |
| S1 | seeded, whole point #1 | deep tree (≥5 levels, ~15 pids) built as production builds it: harness → tool shell → runner → command → grandchild sleepers, with **two session boundaries** — level 2 (tool shell, harness-setsid, the console-harness mechanism of §3 "taken as given") and level 4 (command, runner-setsid at `tools/runner:1290`, the `treekill --anchor` target); `--anchor` names level 4 (`root` below); root live | every seeded pid dead by `ps` oracle; caller alive; zero collateral in the ps diff scoped to (target set ∪ {R}) per OWN-3; verb counters agree with the oracle; OWN-5 |
| S2 | seeded, whole point #2 | same tree, SIGKILL `root` (level 4), wait for reparent to ppid 1 (assert it — the measured leak shape), then `treekill --anchor <root>` | reparented members dead; no live pid with `sid == root` in the final scan; exit 0 |
| S3 | seeded, nested-session orphan | tool-shell level setsids and dies with the runner child, leaving a grandchild session orphaned; verb called with and without `--seed` | without `--seed`: **verb exits 0 (claims nothing — the orphan is invisible to the seedless closure)** and the independent `ps` scan counts it alive (*measures residue r3, the gap `--seed` closes*; the survivor is counted by the control, not the verb — G10's second prong); with `--seed` from a pre-death walk: zero survivors, exit 0. (r4 is not exercised by any arm — see §3.) |
| S4 | seeded, race | a spawner forking a new sleeper every 0.5 s during the reap; ≥20 iterations | zero survivors every iteration; wall bounded; a single pass proves nothing about a race |
| S5 | seeded, guards | `--anchor 1`, `--anchor $PPID`, a root-owned pid (each a *refused-everything* case) run separately from a same-closure other-uid member (sudo; skips loudly if unavailable; an *excluded-and-continued* case) | the three refused-everything anchors: exit 4, nothing killed, bystander unstopped; the other-uid-member case: the rest of the closure is still killed, the member is counted `refused`, exit reflects survivors (never conflated with the exit-4 cases) |
| S6 | seeded, differential oracle | churn-free tree; Zig closure vs the runner's own `_descendant_pids_ps` (`tools/runner:609`) on the same snapshot | identical pid sets — two implementations are mutual oracles |
| S7 | seeded, parser/reuse | `--ps-fixture` with a member older than `--since` | excluded (G4); `--kill --ps-fixture` exits 2 (G9); stream split per convention (`2>/dev/null` emits data, `1>/dev/null` silent) |
| S8 | seeded, protected set + rollback | a fabricated run record for another in-progress row whose pid sits inside the closure | exit 4, zero signals, diagnostic names the task id, and every frozen pid is running again afterwards (G5, G6, G7) |
| I1 | integration, normal exit | real `tools/runner` runs a command that backgrounds a sleeper and exits 0 | after the runner exits, the sleeper is dead — **fails today** (nothing after `:1587` reaps); red first |
| I2 | integration, ceiling | real `tools/runner`, low `--rss-cap-mb`, a command shaped like S1's generator (setsid'd session-leader descendants, not a plain non-escaping child) so the ceiling path is required to reach a session-escaping tree, not just a naive memory-hungry one | after exit 124, zero live descendants — pins the replacement as equivalent-or-better than today's `killpg` at `:1554` |
| I3 | integration, exception path | real `tools/runner` runs a command that backgrounds a sleeper and then the runner raises, forcing the exception path (`tools/runner:1588-1592`) | after the exception propagates, the sleeper is dead — **fails today** (C3 reaps nothing on this path); red first |

**Instrument controls — the arms that test the arms** (no instrument's first reading
counts before a seeded-defect control): freeze disabled ⇒ S4 must fail; start-time
filter disabled ⇒ S7 must fail; protected-set check disabled ⇒ S8 must fail;
rollback disabled ⇒ S8's running-again clause must fail. An arm that cannot be made
to fail by deleting the code it covers is decoration, not a control. Acceptance also
includes one hand-traced end-to-end audit of a single reap, pid from spawn to death.

---

## 6. The cannibalization step — done means the old path is deleted

| # | site (current tree) | today | after |
|---|---|---|---|
| C1 | `tools/runner:1554` | `os.killpg(proc.pid, signal.SIGKILL)` on the ceiling path; diagnostic `SIGKILL pgid` at `:1552` | deleted; replaced by `managent treekill --anchor <proc.pid> --kill` via a small `_reap_tree()` helper; the diagnostic becomes the verb's summary line; `proc.wait(timeout=2.0)` at `:1558` stays (it reaps the zombie) |
| C2 | normal exit, after `ret = proc.wait()` at `tools/runner:1587` | reaps nothing | `_reap_tree(proc.pid, seed=pids, since=<run start>)` immediately after `:1587`, before `_capture_tokens` — memory released before the token parse; `pids` is the poll loop's loop-local walker output (`tools/runner:1402`), promoted to persist past the loop — a new, small addition, not existing today — and initialized to `[]` so a run whose child exits before the first RSS poll (loop breaks at `:1349-1358`, before `:1402` ever runs) still seeds `_reap_tree` with an empty list rather than an unbound name; the sid term alone carries the closure in that case. `_reap_tree()` itself never raises — internal failures are caught inside it and logged as an unknown-partial leak incident (§2 caller obligations), never propagated — so its placement inside `tools/runner:1587`'s `try` block cannot mis-stamp `killed="runner exception"` on a genuine success |
| C3 | exception path, `tools/runner:1588-1592` | heartbeat + run record, reaps nothing | best-effort `_reap_tree(proc.pid, seed=pids, since=<run start>)` before `raise` — the third runner exit path; same empty-seed fallback as C2 |
| C4 | host guard, `tools/runner:1481` | `os.kill(largest_pid, SIGKILL)` — one pid, orphaning its subtree; the line whose cull class produced the 2026-08-20 harm | `treekill --anchor <largest_pid> --kill --since <run start>` — the culled member's subtree dies with it (D-19: the downward constraint keeps this to `largest_pid`'s descendants, not the run root or its siblings) |
| C5 | `_descendant_pids_ps` / `_WALKER_FN` (`tools/runner:609`, `:647`) | the runner's own working walker, used for RSS at `:1402` | kept for RSS and as the `--seed` source; **demoted to differential-oracle fixture** for arm S6, never a kill path (duplication is the oracle — not deleted) |
| C6 | run record finalize | records pid, pgid, start, exit, signal | plus `reap_claimed` / `reap_survivors` copied from the verb's summary line (old records lack the fields; readers `.get`). This is the stated harm: without it a host cull stays indistinguishable from a model failure in the ledger the project exists to build. T548 consumes it |

**Mechanized deletion gate, not prose:** two mechanical predicates, not a
reviewer's read. `grep -n killpg tools/runner` must return nothing (any match
fails the gate). `grep -n _WALKER_FN tools/runner` must return only the fixed,
enumerated set of RSS/seed-path line numbers pinned in the kanban acceptance
command when the gate is written (the `_descendant_pids_ps`/`_WALKER_FN`
definition, selection, and call — `:609`, `:647`, `:1402`, plus any other
occurrence such as a docstring mention, enumerated exhaustively at pin time) —
any line number outside that pinned set fails the gate automatically, not by a
reviewer deciding "that one's fine". Both greps belong in the pass-1 build row's
kanban acceptance command, enforced by the queue, not a reviewer's memory.

**Non-goal, restated:** a SIGKILLed runner reaps nothing — nothing downstream of it
runs. That is `T548`'s sweep, later the supervisor's held handles.

---

## 7. One dispatch interface for every harness (shaping only; built in a later pass)

Operator requirement (2026-08-20): Pi harness and Claude Code dispatch through the
exact same command; shallow common interface hides deep functionality. The verb is
shaped so the interface pass adds call sites, never variants:

1. **Inputs are family-independent:** a pid, a seed list, a time floor, policy
   flags — all process-table primitives. No model label, provider string, harness
   name, or per-family branch. Mechanized: `grep -nE
   "claude|deepseek|ollama|qwen|glm|minimax|kimi"` scoped to the `treekill` verb's own
   function region in `src/managent/main.zig` (not the whole file — the
   pre-existing recognized-models table at `:116-125` already contains every
   token, so an unscoped grep can never pass) returns nothing, and that scoped
   grep joins the acceptance command.
2. **The anchor is the interface.** Every family already routes through
   `tools/runner` (`bin/subagent:247-251`, `:252`, `:270`), which already records
   the anchor pid and start time at spawn (`tools/runner:1295-1305`). The future
   single dispatcher supplies nothing new; the verb's summary line is the "pid,
   child ps" half of the operator's telemetry list.
3. **Family variation lives in data, not code:** the per-family topology record
   (§3) and each family's seeded arm. A family that doesn't setsid contributes no
   sid-edge members — a null result, not a code branch. If a future family ever
   "needs its own guard", that is the drift alarm, not a feature request.
4. **Composition is multi-root, cheap, idempotent:** the nested-session consequence
   (§3 r3) means later console-side cleanup is several `treekill` calls driven by run
   records — a property of the callers the verb's idempotence (N1, N4) makes
   trivial.

---

## 8. Explicit non-goals

Pass 1 does **not**: make `managent` a daemon; introduce any supervisory process of
any kind — the fix is that the mechanism works, not that something watches it fail;
handle runner death (`T548`'s sweep, later the supervisor's held handles); build the
one-dispatch-interface command (later pass; §7 only constrains shape); do state
consolidation or dashboards (later passes); touch `bin/dispatch:301`'s
`start_new_session=True` — detachment is not the bug, unowned detachment is, and the
dispatcher belongs to the dispatcher pass; rename or edit the T364 kanban reaper or
its controls; patch zig's spawn behaviour; kill cross-uid processes or elevate; add
memory policy (RSS caps and host floors stay in `tools/runner`; the verb kills what
it is pointed at, never decides whether); claim Linux (macOS only is measured);
promise "every descendant ever" under adversarial spawning — the guarantee is every
*enumerable* member, with residue counted and the exit code honest.

---

## 9. Scoping verdict

Pass 1 as briefed is the right first bite, with three corrections adopted from the
field: the cannibalization list was one site short (the host-guard cull at
`tools/runner:1481` is the line class that produced the incident — C4); "every exit
path" means three of four (ceiling, normal, exception — runner death is T548's, and
saying "every" would make the non-goal unfalsifiable); and the normal-exit
requirement is only closeable because the sid catch-all needs no spawn change and
the seed list already exists in the runner's poll loop — a spec that says "call the
verb on normal exit too" without those two facts closes nothing. First thing to cut
if the pass must slim: the C6 run-record fields — argued in-scope because ledger
distinguishability is the stated harm, but severable.

---

## 10. Open questions

1. **Nested-dispatch exemption.** One document proposed exempting subtrees whose
   root carries a detach marker, so one worker's cleanup cannot kill a legitimately
   nested dispatch; the author conceded the scenario may not exist in the current
   fleet. Not implemented in pass 1; needs an operator/Orchestrator ruling. If
   nested dispatch mid-run is forbidden, the question dissolves. In the interim, G6
   already delivers most of this protection: a nested dispatch's runner pid landing
   inside an outer closure trips the protected-set guard, so today's behaviour is
   total refusal (exit 4) of the outer cleanup, not a selective skip of the nested
   subtree — a known, coarser-than-ideal interim, not a gap.
2. **Seed-window residue size.** Children forked after the last poll snapshot whose
   intermediate sessions died before the verb ran are unreachable (r4). Arm S3
   measures the shape; the production rate is unmeasured and expected ~0 for
   zig/clang trees.
3. **Enumeration cost.** One `ps` plus one `getsid(2)` per candidate per round is
   unmeasured; if it measures badly, `sysctl(KERN_PROC_ALL)` delivers ppid/sid/start
   in one syscall at the cost of a hand-written `kinfo_proc` layout (absent from
   Zig's std — verified). Design-phase decision.
4. **Start-time parsing.** `ps lstart` embeds spaces; `etime` is coarser but
   unambiguous. Design-phase choice; the contract only requires a monotonic floor.
5. **Runner-side vs console-side split of the leaked gigabytes** — unmeasured; T548
   will see it once residue is recorded per run (C6).
6. **Environment-token readability.** One lane's design rested on reading another
   process's environment via `KERN_PROCARGS2`; another lane measured that `ps eww`/
   `ps -E` print no environment for a same-uid child on this host. **Closed by D10:**
   the sysctl-level claim was measured dead at the kernel level, not merely unverified.
   Moot for this spec's design; recorded so the token approach is not retried without
   that measurement.
7. **Per-family topology** for the DeepSeek CLI and ollama families is unrun; their
   seeded arms are not final until the §3 records land.

---

## Provenance

Adopted aspects → source letter(s):

| aspect | source |
|---|---|
| Session-identity catch-all (`sid == root-pid` reaches dead-root escapees, no spawn change) and the two code-reading sharpenings (setsid at spawn; run record already holds the identity) | A/F |
| Nested-session residue analysis (r3) and multi-root composition consequence (§7.4) | A/F |
| OWN-1..4 with independent-oracle rule; arms N1/N2/N4/S1/S2/S4/S5/I1/I2 skeleton; caller-obligation clause; trust-boundary statement | A/F |
| Freeze → fixpoint → validate → kill → verify algorithm; mandatory SIGCONT rollback (G7); atomic pre-flight (G5); protected set from run records (G6); read-only default (G2); fixture interlock (G9); start-time monotonicity (G4) | C |
| OWN-5 closure-recompute postcondition; instrument-mutation controls ("disable X ⇒ arm Y must fail"); differential oracle vs the runner's walker (S6, C5); host-guard call site in scope (C4); "three of four exit paths"; mechanized grep gate in the kanban acceptance | C |
| Distinct refused/not-converged exit codes; deviation-from-`exit 1` rationale; run-record reap fields (C6); `treekill` name and reap-collision argument; `refuseLiveWrite`-gap observation (also E) | C, E |
| Root-not-always-live finding — the normal-exit kill fires after reparenting severs discovery — realized here as `--seed` from the runner's existing poll walk instead of a second verb; S3's with/without-seed arm shape | E |
| Ownership-as-snapshot corollary ("never signal a pid not observed in the captured set"), honest reach-reporting (survivors named, never silent), refusal-vs-partial distinction | G |
| SIGKILL-only, no grace knob (both live call sites already SIGKILL — measured-need argument) | B |
| Per-family residual check with `getsid(2)` (macOS `ps -o sess` prints 0) and evidence-deposit gating | A/F, C, E (convergent) |

Rejected major alternatives, one line each:

| rejected | reason |
|---|---|
| B's inherited-environment-token membership | its load-bearing readability claim is falsified (D10: measured dead at the kernel level, not merely unverified), one lane measured the `ps`-level equivalent absent on this host, and it adds a spawn change plus token minting against the fewer-moving-parts constraint |
| E's second verb (`snapshot-tree`) | the capability is real but the runner already computes the snapshot every poll (`tools/runner:1402`); `--seed` delivers it with zero new verbs |
| G's rescoping of normal-exit orphans to T548 as structurally unreachable | the sid catch-all plus the seed list reaches them; only the r4 residue goes to T548 |
| H's consent ledger and `.alive` canary | new hand-reasoned moving parts; the canary would refuse to kill exactly the live runaway suite the pass exists to kill |
| H's verb name `managent reap` | collides with the live T364 kanban verb — the one-word-two-meanings trap the brief names |
| H's `tools/console.zig` citation and `tools/runner.py`/"~1515" line references | phantom file (verified absent) and unverifiable lines; not imported |
| D's `killpg`-suffices design, universal-family assumption, and side-by-side burn-in | contradicts the measured mechanism on every load-bearing point; burn-in inverts the deletion requirement |
| A/F's TERM-then-KILL grace default | no measured need — both existing call sites SIGKILL (B's argument) |
| C's exit-3-stop on a dead anchor | the dead anchor is the measured leak shape, not an error; stopping there no-ops the exact normal-exit case the pass must close |
| C's delegated-detach exemption (its G8) | possibly invented scope by its own admission; moved to Open question 1 |
