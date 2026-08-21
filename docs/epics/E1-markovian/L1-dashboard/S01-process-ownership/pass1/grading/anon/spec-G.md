I have verified every load-bearing citation against the tree. Writing the spec now.

---

# Pass 1 spec — process ownership (`managent proc`)

**Scope.** Add two verbs, `managent proc tree` and `managent proc kill`, in Zig inside
`src/managent/main.zig` (8,780 lines; verb dispatch at `:362`, the `Writers` stdout=data /
stderr=diagnostics convention at `:33–51`). Pass 1 makes `managent` own a process tree by
*enumerating* it at the moment it must act — not by holding handles across a run. Held
handles are pass 5's supervisor (`docs/status/refactor-roadmap-2026-08-20.md`, "Pass 5").
This spec says what the verbs must do, testably; it does not say how.

---

## 1. What "owned" means, testably

**Owned (enumeration sense).** A pid `p` is *owned by* root `r` at an instant iff `p == r`
or there is a chain `p → ppid(p) → … → r` in the process table read at that instant.
`tree <r>` returns exactly that strict-descendant closure. This is assertable because it is
a pure function of the process table: a control seeds a chain, reads `tree`, and diffs
against the known pids.

**Owned (kill sense) — the load-bearing rule.** For `kill`, ownership is a **snapshot, not a
live relation**. The verb establishes the owned set in *one* enumeration pass, then signals
*that captured set*, then re-enumerates only to verify emptiness and report — never to
retarget. This is the requirement that makes the reparent race (§3) tractable: once captured,
a pid stays owned even if its parent dies and it reparents to init mid-walk. Corollary that a
control asserts: **the verb never reports a pid as killed that it did not observe in its own
snapshot**, and never expands the target set after the snapshot.

**Reach limit (stated, not hidden).** A descendant that reparented to init *before* the verb
was invoked is not in the live closure and is therefore unreachable by enumeration. The verb
must report this ("root gone, descendants unreachable") rather than claim success. This is not
a defect to paper over; it is the boundary between pass 1's verb and `T548`'s sweep (§6, §9).

---

## 2. The verb's contract

Two verbs, one shared walker. Namespaced under `proc` so the existing `reap` (kanban-row
orphans, `src/managent/main.zig:471`) is never conflated with process work.

| | `proc tree <pid>` | `proc kill <pid>` |
|---|---|---|
| effect | report-only; never signals | enumerate, then signal the captured tree |
| stdout (data) | one pid per line, sorted; `--json` → `{"root":R,"root_status":"alive"\|"gone","descendants":[…]}` | one-line summary `killed <n> signal=<S> root=<R>`; `--json` → full record (below) |
| stderr | nothing on success | refusal reasons, per-pid errors (human) |
| args | `--json` | `--json`, `--signal <name\|num>` (default `KILL`), `--grace <ms>` (only meaningful with a non-KILL signal) |

**Exit codes.** `0` success — for `kill`, every captured pid is signalled or confirmed gone.
`1` invocation error (bad pid syntax, unknown signal, unknown flag — consistent with the rest
of the binary, `src/managent/main.zig:489`). `2` **refusal** — a safety guard tripped; nothing
was signalled. `3` **partial** — some captured pids signalled, some vanished or were refused;
detail on stdout (`--json`) and stderr. `2` is deliberately distinct from `1` so a control can
tell *the guard fired* from *the mechanism broke* — the difference the untested 2026-08-20
reaper could not express.

**Dead target.** `tree <dead>` → exit 0, `root_status:"gone"`, empty descendant list. `kill
<dead>` → exit 0, `root_status:"gone"`, `signalled:[]`, and an explicit
`unreachable_note` naming that any descendants are already reparented and outside pass-1 reach.
Success code, but a *named* emptiness — never a bare "killed 0".

**Not ours.** `kill <pid>` where `<pid>` is alive but is **not a strict descendant of the
caller** (its ppid-chain does not reach the verb's parent) → refuse, exit 2, reason on stderr,
`{"root_status":"refused","reason":"not-ours"}` on stdout under `--json`. "Ours" is an
ancestry test, not a session or group test — deliberately, because §3 shows session/group are
the thing the escapees broke free of.

**Pid 1.** `kill 1` (and `kill 0`) → refuse, exit 2, before any enumeration or signal.

**Signal order and grace.** Signal descendants before the root (a child killed last cannot
reparent anything). Default `--signal KILL` preserves today's ceiling-kill behaviour
(`tools/runner:1505`); a non-KILL signal turns on the `--grace` two-phase (signal, wait, then
KILL survivors) so the golden-master behaviour is byte-comparable before the fix.

---

## 3. The measured escape mechanism, and its residue

The mechanism is measured, not conjectured (2026-08-20, this repo, production chain;
`docs/epics/E1-markovian/L1-dashboard/S01-process-ownership/pass1/00-brief-review.md` M1/M2):

- **M1 — zig creates no groups or sessions.** `std.process.SpawnOptions.pgid` defaults `null`
  (`std/process.zig:397`); nothing in the zig 0.16 build path calls `setsid`/`setpgid`.
- **M2 — the console harness setsids every tool command.** Measured chain: `tools/runner` →
  `claude -p` (the runner's `os.setsid()` child, `tools/runner:1161`) → `zsh` tool command with
  `pgid == sid == own pid`, distinct from the console's session. The tool command is a **new
  session leader**.

Two consequences the spec builds on, not re-derives:

1. **Group- and session-level kills are structurally insufficient.** `killpg` aimed at the
   console (`tools/runner:1505`) reaches the console's group but misses every tool-command tree,
   which is its own session leader and reparents to init holding gigabytes (the 9.1 GB at
   0.06 GB free, `docs/status/tooling-defects-2026-08-20.md` item 16). The verb therefore
   *enumerates the descendant tree and signals each member*, and must handle the race where a
   dying parent reparents children to init mid-walk — handled by §1's snapshot rule: the set is
   captured before any signal, so reparenting mid-walk cannot remove a pid from the set.
   Enumeration on macOS has no `/proc`; the primitive is libproc
   `proc_listchildpids` (recursive; `libproc.h:95`, present in Zig's bundled libc), with
   `proc_pidinfo` available for the pid-reuse check in §4.
2. **The mechanism is per-console-family.** M2 covers `claude -p`. Before the seeded controls
   are finalized, run once per other family ([SELF-IDENTIFICATION REDACTED] CLI, ollama-subagent) the check:
   `ps -o pid,ppid,pgid,comm` on the console pid and one of its tool-command pids, plus
   `getsid` for each — e.g. `python3 -c 'import os;print(os.getsid(PID))'` — because macOS
   `ps -o sess` prints 0 and is useless. Assert per family: does each tool command have
   `pgid == sid == own pid` distinct from the console's sid? If yes, the §5 escape control is
   seeded as-is; if a family does *not* setsid, its escape seed changes (group-escape) and its
   residual is smaller — but the verb is unaffected either way, since descendant enumeration is
   a superset of every group/session scheme.

---

## 4. Safety — what must never be killable, and the guards that enforce it

**Never-killable set (checked at the signal step, never in the read step).** Pid 0; pid 1; the
verb's own pid; the verb's parent (the caller) and every ancestor of the verb; any pid not in
the captured snapshot. Enforced per-pid, so even a malformed snapshot cannot cross the line.

**Guards, each with its control:**

- **G1 pid-0/1.** Refuse before any work. Control: `kill 1` and `kill 0` exit 2, nothing
  signalled (assert the refusal code and that no libproc signal call was reached).
- **G2 ours.** Root must be a strict descendant of the caller. Control: a seeded *sibling*
  tree (a live process that is not under the caller) invoked as root → exit 2, and that live
  tree is verified still running afterwards. This is the "live tree must survive" null control.
- **G3 snapshot-only signalling.** The signal set is the captured snapshot, frozen; no re-walk
  may add targets. Control: a seeded rapidly-forking tree; assert the kill's `--json`
  `signalled` list equals the pids captured in the immediately-preceding `tree`, and no pid
  outside that list is signalled.
- **G4 pid-reuse.** Before signalling a captured pid, re-verify it is the *same* process (via
  `proc_pidinfo` start time). A pid that vanished or was reused is *skipped and reported*, never
  signalled. Control: a race seed that kills a target out from under the verb while a fresh
  process claims its pid; assert the verb reports `vanished`/`refused` and does not signal the
  newcomer. (Stress control; bounded interpretation recorded in §10.)
- **G5 no silent success.** The verb reports what it did **not** reach (dead root → named
  emptiness; partial → exit 3 with the list). Control: the reach-limit seed (§5, C6) asserts the
  verb says "unreachable", never "killed 0, all clear".

These five are the hand-reasoned three of 2026-08-20 made *assertable*: G2 covers "is it
ours", G4 covers "is it still the same process", G5 covers "did we actually do anything".

---

## 5. The controls (named, not written)

Null arms must pass against today's code where the behaviour is preserved; seeded arms must be
shown RED first (standing rule, `AGENTS.md` §tooling). Every kill control records pid, signal,
reason — a silent kill is a failed control.

- **C1 null — closure.** Seed `r→a→b→c` (c in its own session/group); `tree r` returns exactly
  `{a,b,c}`, excludes a sibling `s` from a different tree. Asserts §1's definition.
- **C2 seeded — the measured escape.** `r→a→b` where `b` `setsid`s (the M2 mechanism) and spawns
  `c`; `kill r` terminates all of `a,b,c`; re-enumeration is empty. Asserts the verb beats the
  escape that `killpg` loses to. **This is the arm the per-family check (§3.2) conditions.**
- **C3 seeded — reparent mid-walk.** `r→a→b→c`; arrange `a` to die during the kill; assert `c`
  is still signalled (snapshot rule) — the pid is owned once captured.
- **C4 null — live tree survives.** `kill <root>` with a live, unrelated tree present; assert
  the unrelated tree is untouched (G2's arm, restated at the tree level).
- **C5 null — dead root honesty.** `kill <dead-pid>` → exit 0 with `root_status:"gone"` and a
  non-empty `unreachable_note`; `tree <dead-pid>` → empty closure. Asserts the verb never
  fabricates a kill.
- **C6 seeded — reach limit.** Seed `r→a→b`, kill `a` *before* invoking the verb (so `b`
  reparents to init), then `kill r`; assert the verb reports `b` unreachable, not killed. This
  pins the §1 reach limit — and is the control that names the normal-exit orphan as `T548`
  scope, not a pass-1 verb defect.
- **C7 null — guard refusal.** `kill 1`, `kill 0`, `kill <caller>`, `kill <sibling>` all exit 2;
  nothing signalled.
- **C8 null — data/diagnostic split.** `proc tree 2>/dev/null` emits only pids; `proc tree
  1>/dev/null` is silent. The `--json` records re-parse as JSON.

---

## 6. Cannibalization — the pass is not done until the old path is deleted

`docs/epics/E1-markovian/L1-dashboard/S01-process-ownership/pass1/LADDER.md` states it: cannibalization is the deliverable, not
the verb. Concretely:

1. **`tools/runner:1505`** — the `os.killpg(proc.pid, signal.SIGKILL)` on the ceiling-kill path
   is replaced by a call to `managent proc kill <proc.pid>`. The `killpg` line is deleted, not
   kept as a fallback.
2. **`tools/runner:1538`** — the normal-exit path (`ret = proc.wait()` today reaps nothing) gains
   a `managent proc kill <proc.pid>` call. Its honest reach is bounded (§1): it reaps whatever
   is still attached and *reports* the rest as unreachable, feeding `T548`'s sweep rather than
   pretending to reap it.
3. **`tools/runner:1432`** — the host-guard's single-pid `os.kill(largest_pid, SIGKILL)` is the
   same escape class (it kills one member, orphaning the rest) and is flagged as in-scope for the
   same replacement. If the Plan phase rules it out, it must be an explicit, recorded decision —
   not an unexamined survivor.
4. **Acceptance is deletion.** The pass closes only when a `grep` for `killpg`/bare `os.kill`
   in the runner's kill path returns nothing and the controls C1–C8 pass against the verb, with
   the runner's own regression suite (`tools/regression-runner-*.sh`) still green.

**Non-goal, stated:** a SIGKILLed runner reaps nothing (its verb call never runs). That is
`T548`'s sweep, and later the supervisor's held handles — not pass 1.

---

## 7. One interface for every harness

The verb takes a **pid and a signal**, and nothing else about the harness. No provider flag, no
family branch, no process-name matching, no session assumption — it reads only the process
table, which is family-independent. This is what makes it serve `claude -p`, [SELF-IDENTIFICATION REDACTED] CLI, and
ollama-subagent behind one command: the *caller* (today `tools/runner`, later the supervisor)
already knows the pid it spawned; the verb does not care what the pid is. A design that needed
a variant per family would encode the very session/group behaviour §3 shows is escape-shaped.
The residual per-family knowledge is quarantined where it belongs — in the *seed* of the C2
control (§3.2), not in the verb's interface.

---

## 8. Explicit non-goals

1. **No new supervisory process.** No reaper, watchdog, or monitor watching the verb. The
   mechanism works; nothing watches it fail (`docs/status/refactor-roadmap-2026-08-20.md`,
   "What we deliberately do NOT do").
2. **No daemon, no held handles.** `managent` stays a short-lived CLI. Holding a child across
   its run is pass 5.
3. **No runner-death reaping.** A SIGKILLed runner reaps nothing — `T548`'s sweep.
4. **No store work.** The verb touches no kanban row, no run record, no heartbeat. State
   consolidation and run-records-into-the-store are passes 3–4.
5. **No supervisor rewrite, no state consolidation, no dashboards** — passes 2–6.
6. **No `/proc`-or-Linux assumptions.** The verb is specified against the macOS process table
   (libproc); portability is not a pass-1 requirement.

---

## 9. Scoping verdict

Pass 1 is **right-sized for the kill path and mis-scoped only in one stated detail.** The
measured crisis — 9.1 GB orphaned at 0.06 GB free (`docs/status/tooling-defects-2026-08-20.md`
item 16) — is cull-driven, and the kill path is exactly where snapshot-then-signal works fully:
the root is alive at invocation, so the full descendant tree is capturable. That is the fix
worth building first.

The one detail to correct: requirement 6's "call the verb on the normal-exit path" cannot mean
"reap the normal-exit orphans" — by the time `ret = proc.wait()` returns (`tools/runner:1538`)
the child is gone and its tool-command children are already reparented to init, so no
point-in-time enumeration can reach them (this is C6). The normal-exit call is still worth
making (it reaps whatever remains attached and *reports* the rest), but the reparented
normal-exit orphan — the single 2828 MB orphan at 27.1 GB free, item 16 — is the **same class
as the runner-death orphan** and belongs with it in `T548`'s sweep. Pass 1 should be accepted
on the kill-path fix plus honest reach-reporting on normal exit, not on a promise the verb
structurally cannot keep.

---

## 10. Uncertainties

1. **C4/G4 pid-reuse is a stress control.** Its seed depends on winning a fork/reuse race that
   is not fully deterministic on macOS; a flaky red is expected. Record it as a bounded-interpretation
   control, and back it with a unit-level test of the pidinfo check so the invariant is pinned even
   if the race seed is not.
2. **Enumeration cost on huge trees.** `kill 1`-adjacent mistakes are refused by G1, but a caller
   that owns a very large tree makes `proc_listchildpids` recursion deep. Whether a depth cap is a
   safety guard or a failure mode is a Plan-phase decision; the spec requires only that a walk that
   cannot complete reports *incomplete* and signals nothing it did not capture.
3. **The [SELF-IDENTIFICATION REDACTED]/ollama residual check (§3.2) is unrun at spec time.** Until it runs, the C2
   seed is valid only for `claude -p`; the verb's correctness does not depend on it, but the
   control's does.
4. **`tools/runner:1432` inclusion.** I flag the host-guard single-pid kill as in-scope (§6.3);
   if Plan descopes it, that must be a recorded decision, because it is the same escape class as
   `:1505`.

---

## 11. Best contribution

The section I'd have quarried is **§1's ownership-as-snapshot rule together with §9's
reach-limit finding** — they are two sides of one claim: *the verb owns the set it captures,
and it must say so when it cannot capture.* That single rule makes the reparent race testable
(C3) instead of a design smell, and the reach-limit statement turns the normal-exit requirement
from an impossible promise into an honest boundary (C5/C6) that routes the residual orphan to
`T548` where it belongs. If nothing else survives consolidation, that distinction — between
"owns what it enumerated" and "claims to reap what it never saw" — is the part worth keeping.

---

**Landmark:** advances `L1 (the dashboard tells the truth)` and unblocks `T548` — after pass 1,
a cull can be said to have *reaped* its tree only if the verb's snapshot records it, and the
residual that remains is named, not silently scored as a model failure.

**Status of this document:** spec, not plan or design; every "must" is a control C1–C8 or a
guard G1–G5, every mechanism claim is cited by path:line, and the one place the brief over-promised
(§9) is flagged rather than smoothed over.
