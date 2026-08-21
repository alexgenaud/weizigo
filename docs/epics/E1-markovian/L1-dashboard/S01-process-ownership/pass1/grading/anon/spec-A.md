# Pass 1 spec — a process-tree ownership verb for `managent`

**Scope.** One Zig verb inside `src/managent/main.zig` (the existing 8,780-line binary named in the brief; the grand-race freeze rule in `docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/grand-race.md` §3 names that file as the fleet-toolchain home) that, given a spawned child, can enumerate and reliably terminate every descendant, on every exit path. Not a daemon. Not the plan, not the design, not code. This document is the spec; the controls are named, not written.

**This spec's best contribution: the session-identity catch-all.** The measured leak shape is session-leader escapees reparented to init. A pid-only design cannot reach them (a dead root has no ppid-chain); a session-match design (`sid == root-pid`) can — because reparenting preserves the session, and because the root's session identity is already recorded at spawn today (`tools/runner:1252`, run-record `"pgid"` == the setsid'd child's pid == its sid). Two smaller findings support it and are quarryable on their own: (a) `managent reap` is already a verb — the T364 **kanban** reaper (`tools/regression-orphan-reaper.sh:2`, `:100`) — so the new verb needs a different name, exactly the "assume nothing from names" trap the brief warns about; (b) the brief's phrasing "`os.setsid()` on its child … but only on its ceiling-kill path" is ambiguous — the code shows the setsid is at **spawn for every run** (`tools/runner:1161` defined, applied at `:1241`); only the `killpg` is ceiling-gated (`:1505`). Consequence: the dead-root catch-all works with **no spawn change**.

---

## 1. What "owned" means, testably

**Definition.** Process tree rooted at pid R is *owned* by caller C iff C spawned R and C can invoke the verb to terminate, on demand, every live process of R's tree — including after R itself has exited.

Four assertions, each of which a control (→ §5) can assert with an oracle independent of the verb:

- **OWN-1 (enumerability, live).** From a live R, the verb's target set equals the ppid-chain walk of R (every descendant, including descendants that changed process group). → Arm C.
- **OWN-2 (termination, dead root).** From a dead R that was a session leader, the verb reaches every surviving session member (`sid == R`), including members reparented to init. → Arm D. This is the assertion the measured leak demands; a verb that cannot pass it does not own trees, it guesses.
- **OWN-3 (confinement).** After a reap, the set of dead pids is a subset of (the target tree ∪ {R}); nothing outside it died, measured by a `ps` diff before/after. → Arms C, E.
- **OWN-4 (all exit paths).** The runner leaves zero live descendants of its spawn on its normal-exit and ceiling paths. → Arms I, J (both fail today: the normal-exit path at `tools/runner:1538-1597` reaps nothing).

"Owned" is therefore a condition a control asserts by process-table observation, never by the verb's self-report alone: every seeded arm cross-checks the verb's stdout numbers against an independent `ps` scan, and a disagreement is a FAIL (the standing rule that impossibly clean counters are red flags, QA-023 chain, AGENTS.md "Verification rules").

---

## 2. The verb's contract

**Name: `tree-kill`** (placeholder; the required property is no collision). `reap` is taken — the T364 kanban reaper is live in the binary (`tools/regression-orphan-reaper.sh:100` greps `managent help` for `"managent reap"` and uses it). `kill` reads like the directive `managent tell <id> kill`. `treekill`/`kill-tree`/`terminate` are acceptable alternatives; the contract below is name-independent.

```
managent tree-kill [--kill] [--grace <secs>] [--owner <pid>] <root-pid>
```

**Arguments.** `<root-pid>`: required, strictly a decimal integer. `--owner <pid>`: the process whose family the root must belong to; default: the verb's parent (the caller). `--kill`: immediate SIGKILL, no TERM, no grace (the ceiling path). `--grace <secs>`: TERM-to-KILL delay, default 2 (matches the runner's existing `proc.wait(timeout=2.0)` bound at `tools/runner:1507-1511`).

**Algorithm (bounded).** Round 1: full process-table scan (`sysctl KERN_PROC_ALL` or libproc `proc_listpids`; macOS syscall surfaces, no third-party deps — the exact API is an implementation detail, the controls are API-agnostic); build the target set = ppid-chain descendants of root ∪ processes with `sid == root-pid`; signal all by individual `kill(2)` (TERM, or KILL with `--kill`). Wait grace (default mode only). Round 2: re-scan (catches reparent-to-init stragglers — reparenting preserves sid — and late forks), KILL all found. Round 3: re-scan, count residual. Max 3 rounds; bounded wall ≈ grace + 3 scans. Never `killpg`, never a session broadcast (none exists on macOS anyway; and the brief's measurement says group- and session-level kills are structurally insufficient for session-leader escapees).

**Kills the root itself.** It is in the set (the runner's `killpg` at `:1505` includes the group leader, so this is the drop-in semantics). On the runner's normal-exit path the root is already dead — the set is then empty unless session members survive.

**Exit codes.** `0` = residual 0 and refused 0 (tree fully terminated, or nothing to do). `1` = residual > 0 (survivors after the final round; pids named on stderr). `2` = usage (missing/non-numeric pid). `3` = guard refusal (pid 1, self/ancestor root, root not ours) — nothing killed. `4` = internal (process-table scan failed). Exits 0/1/3 emit the data line; 2 and 4 are pre-scan failures with no data line.

**Output shape** (project convention, `docs/infra/managent/spec.md:48-57`: stdout = data, stderr = diagnostics; regression check `2>/dev/null` non-empty, `1>/dev/null` silent). stdout: exactly one line, stable fields:

```
residual=<n> killed=<n> refused=<n> root=<live|dead>
```

stderr: per-pid diagnostics (signals sent, rounds), the survivor/refusal names, and a note when `root=dead` — never on stdout.

**Already dead.** Root not in the process table: indistinguishable from "never existed"; both exit 0 with `root=dead` (idempotent — reaping a reaped tree exits 0; Arm A). If the dead root's session still has members (`sid == root-pid`), they are killed (Arm D) — this is the load-bearing behavior, not an edge case.

**Not ours.** If root is live and its ppid-chain does not reach `--owner` (default: the verb's parent), exit 3, nothing killed, reason on stderr (Arm E). If root is dead, ancestry is unverifiable; the kill set is confined to `sid == root-pid` members and the caller's assertion that it spawned root is the trust boundary — stated, not hidden (see §4, G7).

**Pid 1.** Root == 1 (or 0, or any pid < 2): exit 3, nothing killed. Root == the verb's own pid, or any ancestor of the verb (the caller is the verb's parent and must survive to report): exit 3, nothing killed. Root == `--owner`: refused (it would kill the owner).

**Caller obligations.** The runner treats any nonzero exit — or the verb itself being killed by signal — as a leak incident: loud stderr warning with pid and residual, never blocking the runner's own exit.

---

## 3. The measured escape mechanism, its residue, and the per-family check

**Mechanism (measured 2026-08-20, production chain, given in the brief — restated only to build on):** the console harness starts every tool command in a new session (shell `pgid == sid == own pid`); zig 0.16 creates no process group or session for build children (`std/process.zig:397`, `SpawnOptions.pgid` defaults null); the runner setsids its child at spawn (`tools/runner:1161`, applied at `:1241`) but killpgs only on the ceiling path (`:1505`); the host guard SIGKILLs one pid (`:1432`); the normal-exit path reaps nothing (`:1538-1597`); escapees are session leaders, so no group- or session-level kill reaches them — only descendant enumeration can; observed 6 orphans → 4.5 GB → 9.1 GB (free 0.06 GB, swap 2.9/4 GB) → 2.8 GB recurring with 25–27 GB free; macOS has no cgroups.

**Two verified sharpenings from reading the code (both in-repo, checkable):**
1. The setsid is **spawn-time for every run** (`tools/runner:1161` → `:1241`), so every runner child is a session leader with `sid == child pid`. The dead-root catch-all therefore needs no spawn change, and the T364 launch record — written before any exit path (`tools/runner:1246-1252`) — already stores the root's identity: `"pgid": proc.pid` == sid.
2. The runner **already enumerates the descendant tree every poll** for RSS accounting (`tools/runner:1353`, `pids = _WALKER_FN(proc.pid)`), and its `--sweep` mode exists "to help find orphaned zig processes" (`tools/runner:43-45`). Descendant enumeration is proven in production in this repo; the Zig verb re-implements the primitive, and the runner's walker is a candidate independent oracle for the controls.

**Residue the verb must handle:** (r1) children reparented to init mid-walk — handled by the 3-round re-scan plus the fact that sid survives reparenting; (r2) dead session-leader roots — handled by `sid == root-pid` matching; (r3) the **nested-session topology**: the tool shell is a session leader (measured), and the runner re-setsids its child inside it — so a console-side reap of the dead tool shell finds the shell's session (the runner) but *not* the nested build tree, whose members carry `sid == build-child-pid`. Consequence: the future console-side/T548 sweep is a **multi-root reap driven by run records** (`tree-kill <shell-pid>` and `tree-kill <pgid-from-run-record>`), which is exactly why the verb must be cheap and idempotent. (r4) a descendant that daemonizes via its own setsid escapes both passes once the chain breaks — **measured, never assumed zero**: the seeded arms count it; zig/clang are expected to contribute none on the production chain, and if a control observes one, that is a finding with its number, not a silent success.

**Per-family residual check (required before the seeded controls are finalized for any family):** the mechanism record covers `claude -p`. Once per other console family ([SELF-IDENTIFICATION REDACTED] CLI, ollama-subagent — both live dispatch providers per `bin/subagent`, referenced by `bin/dispatch`), run a probe command through that family's harness, then:

```
ps -o pid,ppid,pgid,comm -ax          # the one command: tree topology
python3 -c 'import os,sys;print(os.getsid(int(sys.argv[1])))' <pid>   # per pid
```

macOS caveat (brief, measured): `ps -o sess` prints 0 — do not use it; `getsid(2)` is the only session reading. Record per family: (a) is the tool-command root a session leader (`pgid==sid==own pid`)? (b) is the runner's child a session leader at spawn (expected: yes, `tools/runner:1161`)? (c) does anything in the chain change session? (d) do build grandchildren stay in the child's session? Deposit under `docs/evidence/<claim-id>/` in git with a per-family PROVEN/CLAIMED status (AGENTS.md evidence rules). Gate: arms C/D/I/J are final for a family only after that family's check is recorded; until then they are final only for `claude -p`.

---

## 4. Safety

The seat ran an *untested* reaper on 2026-08-20 with three hand-reasoned guards (given in the brief). Every guard below therefore has a named control (§5); a guard without a control is not a guard.

- **G1 — no broadcast.** Kill only individually-enumerated pids via `kill(2)`, never `killpg`/group/session semantics. Control: E.
- **G2 — never pid 1, pid 0, kernel tasks, the verb itself, or any ancestor of the verb** (the caller is the verb's parent and must survive to report). Control: E (arms: `tree-kill 1`, `tree-kill $PPID`).
- **G3 — ancestry.** Live root's ppid-chain must reach `--owner` (default: the verb's parent). A sibling tool tree under the same console does *not* reach the runner and is refused. Control: E.
- **G4 — session confinement.** Dead-root kills confined to `sid == root-pid` members; nothing else is ever signalled. Control: C's collateral diff + D.
- **G5 — idempotence and limits.** Empty or already-dead target exits 0 killing nothing; rounds ≤ 3; grace bounded; a tree that keeps spawning can make residual > 0 (exit 1) but cannot hang the verb. Control: A, F.
- **G6 — no silent partial success.** Exit 0 iff residual == 0 (and refused == 0), by the verb's own final scan *and* the control's independent scan. Survivors → exit 1 with names on stderr. A verb killed mid-reap → the caller logs "unknown-partial", never "clean". Control: G, plus the parity rule in §1.
- **G7 — caller surface.** The runner passes only the pid it stored at spawn (run record `"pgid"`), never argv/env-derived input; pid parsed strictly as decimal. Trust boundary, stated: the verb defends against mis-targeting and accident, not against a malicious or buggy caller — but a dead-root call is confined to the sid, so even a wrong pid cannot kill outside that session. Control: A (never-existed pid kills nothing).
- **G8 — no elevation.** A member of another uid (a `sudo` child) yields EPERM on `kill(2)`: counted refused, never escalated, never silently skipped. Control: G (environment-gated).

**Must never be killable:** pid 1 (launchd) and pid 0; kernel tasks; the verb; its ancestors; anything outside the enumerated target set; other-uid processes; the console harness and its other tool trees (enforced by G3/G4). The verb adds no privilege — a caller who can invoke it can already run arbitrary commands as the user.

---

## 5. The controls (named, not written)

`tools/regression-tree-kill.sh`, following the T364 script's proven pattern (scratch repo under `/tmp/weizigo`, `MANAGENT_BIN → zig-out/bin/managent → bin/managent` resolution per `tools/regression-orphan-reaper.sh:48-49`, skip-loudly when the verb is absent, FAIL counter, exit 0/1). Wired into `zig build test` (standing tooling rule, AGENTS.md). **Test-first:** the script is written and run before the verb exists — arms D, I, J must fail red — then the verb is implemented, then green. The T364 script is untouched (different concern; the name collision is documented, not resolved by renaming T364's verb).

| Arm | Kind | Seed | Assertion (independent oracle) |
|---|---|---|---|
| **A** | null | a pid that never existed (e.g. 2^31−1) | exit 0, `residual=0 killed=0 root=dead`, stdout one parseable line, stderr note, `ps` unchanged |
| **B** | null | one live leaf (`sleep 60` spawned by the harness) | root dies; nothing else dies; the harness (the caller) survives |
| **C** | seeded, whole point #1 | deep tree (depth 4, 15 pids) built exactly as production builds it: console harness → tool shell → `tools/runner` → command → grandchild sleepers; root live | every seeded pid dead (ps oracle); caller alive; ps diff shows zero collateral; verb's reported `killed`/`residual` agree with the oracle |
| **D** | seeded, whole point #2 | same tree, then SIGKILL the root and wait (assert children reparent to ppid 1 — the measured leak shape), then reap root-pid | reparented members dead; final ps finds no live pid with `sid == root-pid`; exit 0 |
| **E** | seeded, survive | sibling tool tree under the same console + an unrelated same-uid process + `tree-kill 1` + `tree-kill $PPID` | all exit 3 or leave the foreign pids untouched; nothing outside the target tree ever dies |
| **F** | seeded, race | a spawner node forking a new sleeper every 0.5 s until killed | all late forks dead; residual 0; verb wall bounded (≤ grace + 3 scans) |
| **G** | seeded, honesty | one member under another uid (`sudo`) | EPERM → refused, residual ≥ 1, exit 1, pid named on stderr; environment-gated (skips loudly if sudo unavailable) |
| **H** | null, concurrency | two concurrent reaps of one tree | both exit 0; no error; no double-kill report |
| **I** | integration, normal exit | real `tools/runner` runs a command that backgrounds a sleeper in the child's session and exits 0 | after the runner exits, the sleeper is dead. **Fails today** (`:1538-1597` reaps nothing) — red first |
| **J** | integration, ceiling | real `tools/runner`, low `--rss-cap-mb`, memory-hungry command | after exit 124, zero live descendants of the child; pins the `tree-kill --kill` replacement as equivalent-or-better than today's `killpg` at `:1505` |

Per-arm denominators are fixed in the script (tree sizes, sleeps, grace). Every seeded arm asserts the verb's numbers against the ps oracle; disagreement = FAIL. The acceptance also includes one hand-traced end-to-end audit of a reap (a pid from spawn to death), per the standing verify-then-promote rule that an auditor must trace one complete evaluation.

---

## 6. Cannibalization — the old code path is deleted, not wrapped

- **`tools/runner:1505`** — `os.killpg(proc.pid, signal.SIGKILL)` is deleted and replaced by `managent tree-kill --kill <proc.pid>` (via a small `_reap_tree(pid, kill_first=…)` helper using the runner's existing managent subprocess pattern, `tools/runner:1227` and `:1587`). The `SIGKILL pgid` diagnostic at `:1503` is replaced by the reap's stderr output. `proc.wait(timeout=2.0)` at `:1507-1511` stays (it reaps the child's zombie).
- **Normal-exit path** — after `ret = proc.wait()` (`tools/runner:1538`) and before the finalize at `:1571-1578`: `_reap_tree(proc.pid)` (default TERM-then-KILL mode), outcome logged on stderr and stamped into the run record via the existing `_finalize_run_record` call as one optional field, `reap_residual` (old records lack it; readers `.get` it). Justification for the field, not scope creep: the T364 record exists so a killed run "leaves the evidence" (`tools/runner:1246-1252`); a silent leak would otherwise be unobservable in the evidence store, violating G6. T548 consumes the field.
- **Exception path (recommended, beyond the brief's two mandated sites)** — in the `except` block at `tools/runner:1539-1543`, best-effort `_reap_tree(proc.pid)` before `raise`. One line via the same helper; the brief's own content requirement (§1 of the brief) is "on every exit path", and this is the third runner exit path.
- **Stays:** the host-guard one-pid SIGKILL at `:1432` (per-poll emergency relief, not the leak; its run always terminates in the ceiling path, where the reap now covers the whole tree).
- **Deleted, explicitly:** the `killpg` call site and the "only the ceiling kills" structure. The normal-exit path's "reaps nothing" is gone.
- **Runner-death case** (runner SIGKILLed → nothing calls the verb) is a stated **non-goal**: `T548`'s sweep, later the supervisor's held handles.

---

## 7. Shaping for the one dispatch interface (later pass)

The operator's requirement (2026-08-20): Pi harness and [SELF-IDENTIFICATION REDACTED] Code dispatch through the exact same command; shallow common interface, deep functionality. Pass 1 does not build it, but the verb is shaped so it cannot need a per-family variant:

1. **Inputs are family-independent:** `<root-pid>` + `--owner`, derived from process-table primitives only (ppid, sid). No family names, no flags, no shell or console assumptions anywhere in the contract.
2. **The per-family difference is confined to the topology check (§3)** — a recorded fact per family — and to the *caller's* spawn record (pid/sid), which the unified dispatcher will hold. The verb never changes per family; the interface pass is a call-site addition.
3. **Graceful degradation, not branching:** a family whose harness does not setsid its tool commands still gets live-root coverage (ppid-chain); it loses only dead-root coverage, and the check quantifies that loss — the interface pass should setsid at spawn (the runner's `:1161` is the reference implementation), not fork the verb.
4. **Stable, parseable contract for every caller language:** Python today (`tools/runner` subprocess), shell tomorrow (controls; possibly the interface itself), Zig later (T548's sweeper). One stdout line + exit codes serve all; the future interface folds `residual`/`killed` into its telemetry ("pid, child ps" half of the operator's list) and escalates residual > 0 to T548.
5. **The nesting consequence (§3, r3)** means the interface pass's cleanup is a multi-root reap from run records — a property of the callers, not of the verb; the verb's idempotence (Arm A) and dead-root support make that composition trivial.

---

## 8. Explicit non-goals

Pass 1 does **not**: make `managent` a daemon; introduce any supervisory process ("the fix is that the mechanism works, not that something watches it fail" — the brief); do the runner-death sweep (`T548`) or the supervisor's held handles; integrate the console harnesses or build the one-dispatch-interface command (later pass); do state consolidation or dashboards (later passes); patch zig's spawn behavior; kill cross-user processes or elevate; change the T364 kanban reaper or its name; alter the run-record schema beyond the one optional `reap_residual` field; promise "every descendant ever" under adversarial spawning — the guarantee is *every enumerated descendant*, with residual reported and exit code honest.

---

## 9. Scoping verdict

**Pass 1 as briefed is correctly scoped**, and the code reading shrinks it slightly: no spawn change is needed (setsid is already at spawn, `:1161`/`:1241`), and the root identity is already recorded (`:1252`). The two acceptance boundaries that must be written down: (i) the guarantee is over *enumerated* descendants — the seeded arms on the production chain assert residual 0, and the daemonized-descendant residue is measured, not assumed; (ii) the runner-side fix is complete at `:1505` + normal-exit + exception, while the console-side sweep and the runner-death case are genuinely later passes — the 9.1 GB event's runner-side vs console-side split is unmeasured and should be stated as open until T548 can see it. One possible over-scope is the `reap_residual` record field; it is argued as in-scope (G6, evidence-store continuity) but is the first thing to cut if the pass must slim.

---

## 10. Uncertainties (open questions)

1. **Enumeration API in Zig on macOS** (sysctl vs libproc) — implementation detail; controls are API-agnostic.
2. **Runner-side vs console-side split of the measured gigabytes** — unmeasured; T548 answers.
3. **Daemonized-descendant residue rate on the production chain** — expected 0 for zig/clang; Arm D/C measure it; not assumed.
4. **Pid-reuse within the reap window** — a recycled session leader with the same pid could be hit by the dead-root match; rare (runner calls the verb within seconds); the optional mitigation (`--sid`, already available from run records) is deferred unless a control observes it.
5. **Other console families' topology** — [SELF-IDENTIFICATION REDACTED] CLI and ollama-subagent checks are pending; their seeded arms are not final until recorded (§3).
6. **Exception-path reap** — recommended but beyond the brief's two mandated sites; flagged for the consolidator's judgment.
