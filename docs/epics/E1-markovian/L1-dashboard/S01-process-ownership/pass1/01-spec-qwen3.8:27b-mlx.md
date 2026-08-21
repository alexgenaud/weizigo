# Pass 1 — SPEC · process ownership: a `managent` verb that reaps an owned process tree

| | |
|---|---|
| Phase | P2 spec, grand-race process-ownership slice of the wave-2 fleet-toolchain consolidation |
| Landmark | L1 (the dashboard tells the truth) — via the upstream of every memory crisis, T548 (orphan suite reaping) |
| Status | ANONYMIZED PROPOSED. Citations verified 2026-08-21 against the live tree; line numbers drift (see §0). Does not ratify itself; audit + operator rule. |
| Scope of this slice | T548 (dead workers leak multi-GB suite children) — the reaping half of T549's G1. |

Protocol: `docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/grand-race.md` §5 (grader null/seeded controls; roster `2026-08-20b` → only **three** non-Claude graders, so any Claude-vs-Claude panel ordering is low-confidence and mechanical anchors outrank it). Prior art, built on not re-derived: `docs/infra/fleet-repair/pass1/spec.md` (T549), its `spec-audit.md` (T550, PASS-WITH-EDITS), `untracked/T548-orphan-suite-reaper.md` (T548 brief — the three guards + controls), `docs/infra/host/incident-2026-07-29.md` (the 12.5 GB `zig` compile that panicked the kernel).

---

## 0. Evidence and line drift — read before trusting any citation below

The brief and the T549/T550 pair cited runner lines that have **drifted** since 2026-08-20. This spec cites the **current** tree (re-verified 2026-08-21) and notes the drift, per the standing discipline T550's A7 and T549 §7.1 establish: *"a later reader should re-verify rather than trust either document blindly."* The T550 audit independently confirmed this failure mode — 2 of 30 spot-checked citations were live-census numbers that had drifted.

| claim | brief / T549 cited | **current (verified 2026-08-21)** | note |
|---|---|---|---|
| detachment | `bin/dispatch:301` `start_new_session=True` | `bin/dispatch:299-301` (Popen call spans 299–301) | **exact** — brief was right |
| runner makes child a session leader | `tools/runner:1161` `os.setsid` | `tools/runner:1210` (`preexec_fn=lambda: os.setsid()`), Popen at `:1290` | drifted +49 |
| ceiling-kill | `tools/runner:1505` `os.killpg` | `tools/runner:1554` `os.killpg(proc.pid, signal.SIGKILL)` | drifted +49 |
| host guard SIGKILLs one pid | `tools/runner:1432` | `tools/runner:1481` `os.kill(largest_pid, signal.SIGKILL)` | drifted +49 |
| normal-exit reaps nothing | (implied) | `tools/runner:1587` `ret = proc.wait()`; post-block (1597–) does token capture + heartbeat + finalize — **no walker call, no kill** | confirmed, not in brief |
| zig never starts a new session | `std/process.zig:397` `pgid` defaults null | `std/process.zig:397` `pgid: ?posix.pid_t = null`; no `setsid`/`setpgid` anywhere in `process.zig` (verified `grep`) | **exact** |
| managent size | "8,780-line binary" | `src/managent/main.zig` = **8780** lines | **exact** |
| `managent reap` **already exists** | not named in brief | `main.zig:471` dispatch, `:222` verb list, help `:5464` "reconcile in_progress rows (T364)" | **new — the collision, §2** |

Two load-bearing facts, verified on this host 2026-08-21 and not in the brief:
1. **`std/posix.zig:378` has `pub fn kill(pid, sig)` but NO `setsid`/`setpgid`/`getsetsid`/`getpgid`** (verified `grep` of `std/posix.zig`). The reaper's mechanism (per-pid signal over a walk) is available in the stdlib; creating a new session is not — consistent with the measured residue (§3).
2. **A live instance of the orphan class exists right now**: `ps` shows `bash tools/fleet-keeper.sh` (pid 99956, **ppid 1 — reparented to init**) holding a live descendant `sleep 30` (pid 69516). It is a **protected marker** (`fleet-keeper`, T548 guard b); this spec **did not disturb it**. It is evidence the leak is not hypothetical and that a `fleet-keeper` *itself* can be a reparented-to-init orphan.

---

## 1. What "owned" means — a condition a control can assert

Not "robust." A tree rooted at `r` owned by the caller is **owned-terminated** iff the verb's postcondition holds:

> **Postcondition P.** After `treekill r` returns 0, `D(r) = ∅`: for every pid `p` live and in the descendant set of `r` at call time, `p` is *not* in the process table post-call (dead or exit-ed and reaped), **and** pid 1 was not signalled.

Three properties make this *owned by enumeration, not inferred*, each asserted by a control (§5):

- **Inferred vs owned.** `D(r)` is the set the **process table** yields by walking `ppid` from `r` (`_WALKER_FN`, `tools/runner:581/609`). "Inferring" the target set from `r`'s *process group* (`killpg(r)`, `tools/runner:1554`) is the defect: `r`'s group does not contain a descendant that became its own session leader (§3), so a pgid-kill silently under-terminates while printing `SIGKILL pgid <n>` as if it succeeded. P asserts the *enumerated* set is empty, so under-termination is caught.
- **The fixed point.** Reliable termination means `D(r)=∅` is a **fixed point**, not one snapshot: killing a parent reparents its children to init (ppid→1) *between* the walk and the signal, so a single `ps` snapshot + kill misses what reparents mid-walk. P requires the verb to **iterate walk→signal→re-walk until `D` is stable-empty or bounded (§4 guard 3)**.
- **Idempotence and the protected set.** `P ∖ Protected = ∅`. A reaped tree, re-walked, returns empty (call twice → second is a no-op, exit 0). A **protected** live set — another worker's tree, the console harness, pid 1 — is asserted *untouched*: `Protected ⊆ alive-before = alive-after`. This is the "live tree that must survive" made testable as a non-vacuous inequality, not a promise.

**Ownership, asserted not assumed.** The verb is given `r` by the caller (the runner passes its own `proc.pid`). The verb **cannot** intrinsically know `r` is the caller's; it enforces three internal guards — refuse `r == 1`, `r == self`, `r == self.ppid` (§4 guard 0) — and the **caller contract** (the runner records `proc.pid` in the run record at launch, `tools/runner:~1300`, and passes only that pid) supplies the ownership attestation. `treekill` verifies `r` is a descendant of the calling process's `ppid` (the runner); a `r` that is not is "not ours" → refuse (§2, exit 3). The distinction — *internal guard* vs *caller attestation* — is stated because a verb that *claims* "I only kill my own" while accepting any pid is the exact silent-wrong-answer class this project exists to catch.

---

## 2. The verb's contract

**Name — new verb, deliberately not `reap`.** `managent reap` already exists (`main.zig:471`, help `:5464`): it reconciles in_progress **kanban rows** against the process table (T364). Naming the process-tree verb `reap` would be the **third** meaning of "reap/orphan" after kanban-rows and the T548 sweep, the one-word-two-meanings gap that hid for months. **Proposed primary: `managent treekill r [--grace=<s>] [--dry-run] [--max-rounds=N]`**; acceptable equivalents `killtree` / `reapproc`; **hard requirement: not `reap`, and not a kanban verb.** Spelling is a Design choice; collision-freedom is not. Wiring: one line in the verb list `main.zig:219-223`, one `else if (… std.mem.eql(u8, cmd, "treekill"))` arm in the dispatch table (runs `:416`–`:485`, after the `reap` arm at `:471`), one `cmdTreekill` function, one help line at `:5464`.

**Arguments.**
- `r` (required) — the root pid the **caller owns** (the runner's `proc.pid`). The verb enumerates `D(r)` and signals only `D(r) \ {self, ppid}`. It never invents pids and never walks *up*.
- `--grace=<s>` — SIGTERM, then wait `s`, then SIGKILL. SIGKILL is **always** the terminal step (reliability over courtesy). Default short (a few seconds); pass 1 may default `0` (SIGKILL only, matching the runner's current SIGKILL-by-design behaviour — `tools/runner:1481,1554` — so integration is behaviour-preserving on the kill paths). Decision item (§10.3).
- `--dry-run` — walk and list what *would* be killed to **stdout**, signal nothing. This is what makes every control below runnable without harming a live host, and the default for any interactive call.
- `--max-rounds=N` — the fixed-point bound (§4 guard 3). Default e.g. 10; if a *non-protected* descendant survives `N` rounds the verb SIGKILLs it and records it, not stalls.

**Exit codes** (data vs stderr per AGENTS.md):
| code | meaning | stdout (data) | stderr (diagnostic) |
|---|---|---|---|
| `0` | P holds (`D(r)=∅` post-call, or none were live) — **idempotent** | one line per terminated pid: `killed <pid> rss=<bytes> sig=SIGTERM\|SIGKILL round=<n> ppid=<q>`; empty set → one line `reaped 0 descendants of <r>` | walk method (`ps`/`/proc`), round count, escalations |
| `2` | usage error (bad/absent `r`) | — | the usage line |
| `3` | **refused**: `r` is pid 1 / self / `ppid`, or `r` is not a descendant of the caller's `ppid` (not ours), or a protected marker is in scope on a *sweep* mode (pass 1 has no sweep — see §4) | not attempted | the refusal reason, named |
| `1` | the walk itself failed (ps/proc unavailable) — a *report the verb cannot do its job* path, distinct from "nothing to do" | the pid(s) seen before failure | the failure |

**Behaviour at the three edge targets the brief names:**
- **already dead** → `D(r)=∅` → exit `0`, stdout `reaped 0 descendants of <r>`, no error, no hang. (Control C0.)
- **not ours** → `r` not a descendant of the calling `ppid` → refuse, exit `3`, name it, signal nothing. (Control C5.) This is the guard that makes "the reaper never touches a sibling worker" *load-bearing*, not asserted.
- **is pid 1** → refuse, exit `3`; the descent never climbs and pid 1 is never signalled. (Control C3.)

**Output discipline.** `stdout` is machine-parseable (the `killed`/`reaped` lines the runner and ledger can grep); `stderr` carries the walker name, round count, escalations, and every refusal reason. A **silent kill is a failed control** (T548 brief: "Silent process killing is unauditable, and today's whole problem was infrastructure deaths being invisible").

---

## 3. The measured escape mechanism and its residue — build on it, do not re-derive it

**Measurement (2026-08-20, this repo, production chain):** the escape is *per-console-harness* and was observed only under `claude -p`.

1. `bin/dispatch:299-301` spawns the worker with `subprocess.Popen(…, start_new_session=True)` — the **worker is a session leader** by design (ownership severed at spawn, `bin/dispatch:301`).
2. The `claude -p` console then starts **each tool command in a new session**: the command shell's `pgid == sid == own pid`, distinct from the console's session. (Measured via `ps` on the production chain; this spec does not re-derive it — it takes it as the given the brief hands over.)
3. Zig creates **no** session for build children (`std/process.zig:397`, no `setsid`) — so the tool-command tree does not self-correct; it inherits the new-session boundary and, when its parent dies, **reparents to init holding gigabytes**.

**Four occurrences, one day** (T548 brief table): 6 orphans → ~4.5 GB → **9.1 GB** (free 0.06 GB, swap 2.9/4 GB) → 2.8 GB recurring *while free memory was a healthy 25–27 GB* (the leak is **continuous, not crisis-only**; a monitor that reads *free* memory misses it, as the seat's first did at 8.2 GB while 2.8 GB sat orphaned). And on this host *today* a live `fleet-keeper` sits reparented to init (§0 fact 2).

**Residue, and the two consequences the spec must carry, not re-derive (brief item 3):**
- **(i) escapees are session leaders → group- and session-level kills are structurally insufficient.** Because an escapee is a session leader with `pgid == own pid` in its *own* group and session, a `killpg` aimed at the console's group or the runner's group **cannot reach it** — there is no group or session that contains both the killer's target and the escapee. The only reach is **descendant enumeration from a known live ancestor + per-pid signal** (`std/posix.zig:378` `kill`). The runner *already* does the enumeration — `_WALKER_FN(proc.pid)` at `tools/runner:1402`, walkers at `:581` (Linux `/proc`) and `:609` (macOS/BSD `ps -axo pid=,ppid=`) — but that set is used only to **sum RSS**, never to **kill** (the kill is pgid-bound at `:1554`, single-pid at `:1481`). §6 makes this the whole point of the cannibalization. And the **reparent-mid-walk race** is a direct consequence: killing a parent reparents its children to init between a snapshot and a signal, so termination must be iterated to the fixed point of §1, not done in one snapshot.
- **(ii) the mechanism is per-family → the residual check gates control finalization.** The measurement covers `claude -p`. **One command, run once per other console family before the seeded controls are finalized** (deepseek-CLI, ollama-subagent; later pi), to confirm that family's tool command is likewise a reparented session leader:
  > `ps -o pid,ppid,pgid <pid>` **and** a session id — where `getsid` exists.
  On **macOS this check degrades** (§10.1): `ps -o sess` prints **0** and there is **no `getsid` binary** (both verified on this host 2026-08-21), so the session id is not ps-readable. The brief's prescription names `getsid`; on macOS the *operational* check reduces to a **ps-only escape proxy** — `ppid == 1 ∧ pgid == own pid` (a reparented session leader), both columns ps-observable, sufficient to detect the *escape* even if it cannot certify session-leader-ness. Until a family is confirmed, its C1–C4 seed (below) is **scoped to `claude -p` only** and says so; a family whose tool command is *not* a new session has a *different* escape and a different seed. This is the one family-specific element in an otherwise family-agnostic design (§7), stated as an uncertainty, not assumed.

---

## 4. Safety — this verb kills on a live machine

The seat ran an **untested** session-local reaper on 2026-08-20 with **three hand-reasoned guards** and no controls (T548 brief §3, `scratchpad/orphan-reaper.sh`, which "dies with the session — do not treat it as the fix or as prior art beyond its three guards"). The directive: **specify the guards and their controls, do not repeat the hand-reasoning.** "A reaper that kills live work is far worse than the leak" (T548).

**The never-killable set, non-negotiable:** pid 1 (init/launchd); the calling process and its parent (the runner); **any live worker tree that is not the reaped `r`'s subtree.**

**The guards, each bound to a control (§5). The critical scoping move is which guards are the *verb's* and which are the *sweeper's* — conflating them either over-protects (refusing to reap its own tree) or under-protects:**

| guard | what it is | whose | control |
|---|---|---|---|
| **G0 boundary** | never signal pid 1; refuse `r ∈ {1, self, self.ppid}`; the walk is strictly **downward** from `r`, never climbs `ppid` | **verb** | **C3** pid-1; **C5** not-ours |
| **G1 strict scope** | the verb signals only `D(r) \ {self, ppid}`; it can never touch a sibling tree, an ancestor, or the console. **Ownership = `r` is a descendant of the caller's ppid** (internal check) **and** the runner passes only its attested `proc.pid` (caller contract) | **verb** | **C2** live-tree-survival; **C5** not-ours |
| **G2 terminal escalation** | SIGTERM → wait `--grace` → SIGKILL; SIGKILL is always reached, so a child that ignores SIGTERM is still terminated | **verb** | **C1**-escalation sub-case |
| **G3 fixed point** | iterate walk→signal→re-walk to a bounded fixed point so a reparent-mid-walk cascade is closed, not missed; `--max-rounds` bounds it | **verb** | **C4** reparent-mid-walk |
| ~~G-b marker skip~~ | *skip* chains containing `subagent`/`claude -p`/`runner`/`fleet-keeper` (T548 guard b) | **SWEEPER, not the verb** | — |
| ~~G-a pattern match~~ | match only `.zig-cache/o/*/test` (T548 guard a) | **SWEEPER** | — |
| ~~G-c two-pass 45 s~~ | re-confirm orphaned on two passes 45 s apart (T548 guard c) | **SWEEPER** | — |

**Why the T548 three guards must NOT be imported into the pass-1 verb:** the verb is **mode (i) — the owned-tree reap**, called by the runner on its *own* `proc.pid` after the child's fate is known. The thing it reaps *is* a `runner`/`subagent`/`claude` tree, so guard b ("skip anything whose chain contains those markers") would **refuse the very job**. The T548 three guards define **mode (ii) — the blind orphan sweep** (a collector of *pre-existing* orphans with no owning caller), which is a **non-goal for pass 1** (§8). The verb's safety is G0 + G1 + G2 + G3: strictly-downward scope + pid-1 boundary + escalation + fixed point, which together mean "only the reaped subtree dies, and it fully dies." The T548 three guards reappear **unchanged** in the deferred sweep (T548), and this spec's recommendation (§10.4) is that the sweep *imports the verb's walk* rather than writing a second one. **This guard-attribution table is load-bearing**: an auditor reading "no live-marker skip" in the verb must see it was a *deliberate boundary* (the verb owns its target), not an oversight — the same class of "omission that reads as a hole or a leak" the project keeps paying for.

**A live, on-host, protected instance exists (§0 fact 2): a `fleet-keeper` reparented to init holding a live `sleep`.** It is named here precisely so no control or integration step reaps it: under G1, a `fleet-keeper` that is *not* the reaped `r`'s subtree is protected; under the deferred sweep's G-b it is skipped. The pass-1 controls must include a "live `fleet-keeper` untouched" assertion, or the fleet keeps itself.

---

## 5. The controls — named, not written (test-first; red-first; a test seen green proves nothing)

Each is a fixture the Test phase builds; the brief asks for them *named*, and this section names the mechanism each exercises and the red it must show first.

| id | arm | mechanism exercised | red-first on current code |
|---|---|---|---|
| **C0** | null · already-dead | `treekill <dead-pid>` → exit 0, `reaped 0`, idempotent (call twice) | — (a no-op is the null) |
| **C1** | seeded · **deep escape** | a stub worker spawns a child that, on exit, is the parent of a deeper child that **reparents to init** (a reparent cascade, the §3(i) residue). The verb terminates `D(r)=∅`. | a **`killpg`-only** run (current `:1554`) leaves the reparented grandchild alive → **RED** |
| **C4** | seeded · **reparent mid-walk** | a child that, right after round 1, is reparented so a *single*-snapshot walk misses it. `--max-rounds` fixed point (G3) closes it; a one-shot walk does not. **Distinguishes "one `ps` snapshot" from "iterate."** | a single-snapshot killer leaves it → **RED** |
| **C3** | seeded · **pid 1** | a tree whose root ancestor is pid 1 → descendants reaped, pid 1 asserted alive and un-signalled (G0) | — (the boundary is the point) |
| **C2** | seeded · **live-tree survival** (the "untouched" arm) | two workers A, B start concurrent live children; reap A's `r` → B's tree **and** the console **and** pid 1 all still alive; also the live `fleet-keeper` (§0) untouched. (G1) | a killer that touches a sibling or climbs upward → **RED** |
| **C5** | seeded · **not ours** | `treekill <pid>` a *live unrelated* worker → refuse exit 3, worker untouched (G1 scope + the refusal contract) | a verb that kills any given pid → **RED** |
| **C6** | seeded · **normal-exit reaping** (the runner integration) | a stub worker exits **normally** with a live child → after the runner's normal-exit path (`tools/runner:1587` `proc.wait()`), the child is gone | current runner reaps nothing post-`wait()` → **RED** |
| **C7** | seeded · **every kill path** | via wall / RSS cap / host-floor / directive-kill → tree reaped in **every** case (T548 controls); a fix covering one path is not a fix | partial-path fix → **RED** |
| **C8** | seeded · **per-family pre-finalization** | for deepseek-CLI and ollama-subagent, run the §3(ii) one-command check (`ps -o pid,ppid,pgid` [+`getsid`], macOS ps-only proxy `ppid==1 ∧ pgid==pid`). **Gates finalization of C1–C4**: an unconfirmed family's seed is scoped to `claude -p` only | the check for a family not run → that family's C1–C4 stay PROPOSED, not finalized |
| **C9** | seeded · **harness-agnostic** | the *same* `treekill <pid>` reaps a tree spawned by two different families with no family-specific variant (§7) | a verb with a per-family branch/flag → **RED** |

**Grader-validity controls (grand-race §5) bind the *graders*, not these fixtures:** the null control (two near-identical specs within one rubric step) and the seeded control (a deliberately weakened spec that a grader placing in the top half fails). With only **three** non-Claude graders on roster `2026-08-20b`, any Claude-vs-Claude ordering rests on panel alone and is reported **low-confidence**; the mechanical anchors above (each C's red-first) outrank the panel where both exist.

---

## 6. The cannibalization step — which line stops, which starts; a pass is done when the old path is deleted

The verb is not done when it exists. It is done when the old code path that *infers* the target set is **deleted and routed through the verb on every exit path.**

**What stops (deleted, after C1/C4/C6/C7 red→green):**
- `tools/runner:1554` `os.killpg(proc.pid, signal.SIGKILL)` — the pgid-bound ceiling-kill that under-terminates the §3(i) escapees. **Replaced** by `subprocess.run([managent, "treekill", str(proc.pid), *grace], check=False)` (or the equivalent exec; §10.2). The `killpg` line is **removed**, not commented.
- `tools/runner:1481` `os.kill(largest_pid, signal.SIGKILL)` — the host-guard single-pid kill is the **same miss-class** (SIGKILLs one member of the tree, leaves the rest). Routed through the verb too (§10.3), or explicitly deferred with a reason. Leaving it is a second pgid-class leak the pass would otherwise ship.

**What starts (added, not replaced — the normal-exit path currently reaps nothing, confirmed at `tools/runner:1587`):**
- After `ret = proc.wait()` (`:1587`), **before** the token-capture/heartbeat/finalize block (`:1597`+), the runner calls the verb on `proc.pid` to terminate any still-live descendants. This is the primary fix: it is the **continuous** leak (§3, the 17:08 while-healthy case), not just the crisis kill.

**Fewer moving parts — do not build a fourth walker.** The enumeration **already exists**: `_WALKER_FN(proc.pid)` at `tools/runner:1402`, with `:581` (Linux `/proc`) and `:609` (macOS `ps -axo pid=,ppid=`). The defect is that this set is used to **sum RSS**, never to **kill** — enumeration and termination are decoupled, and termination is pinned to pgid. The pass therefore (a) moves the **authoritative** walk+terminal-kill into the Zig verb, (b) has the runner **call it** on the kill and normal-exit paths instead of `killpg`, and (c) **deletes** the pgid kill. The Python walkers stay for RSS measurement; if Design unifies, the verb's walk becomes the single source (flagged §10.2, not a pass-1 requirement).

**The runner-death case is a stated non-goal, not a silent gap.** A SIGKILLed runner cannot call the verb on its own behalf; that residue is T548's sweep (mode ii) and later the supervisor's held handles — §8. Pass 1 fixes the paths a *living* runner can run (kill paths + normal exit).

---

## 7. One dispatch interface for every harness (shape the verb to serve all families)

Operator requirement (2026-08-20): *Pi and Claude Code should dispatch to a model via the exact same script/command; shallow common interface, deep functionality.* Today there are **two dispatchers** — `bin/dispatch` (the fleet path) and `bin/subagent` (the provider bridge) — and **per-family branching** (`bin/dispatch:280` `if provider == "claude"`; a `claude`-only dry-run at `:280`). Unifying that interface is a **later pass** (the brief so scopes it); pass 1's only obligation is to **shape the ownership verb so the later unification is a call-site change, not a reaper rewrite.**

**The design property that achieves this: the verb's input is a pid + ownership, not a harness name.** Because it walks `ppid` ancestry (ps/proc, platform-agnostic) and per-pid signals (§3(i)), it *cannot tell* — and needn't — which console spawned the tree. The *same* `treekill <r>` terminates a `claude -p` subtree, a deepseek-CLI subtree, an ollama-subagent subtree, and a pi subtree identically. **No per-family variant, no per-family flag.** A reaper that branches on harness family (e.g. "if claude, kill the session; if deepseek, kill the group") is a design that must be rewritten next pass; a reaper that takes a pid does not. This is C9.

**The one family-specific element is the escape *measurement*, not the reaper** (§3(ii)/§5 C8): the *mechanism* was measured only for `claude -p`, so the *seed* that proves the reaper must be confirmed per family. The reaper is family-agnostic by construction; the confirmation is family-specific by measurement. Stating that asymmetry is the substance of this requirement for pass 1.

---

## 8. Explicit non-goals (pass 1 does not do these)

1. **No new supervisory process.** The verb is a short-lived CLI invoked by the runner's exit path; it is **not** a daemon, timer, or watcher. The fix is *the mechanism works*, not *something watches it fail* (brief item 8; T549 §5.1, the stood-down stack, commit `ec72cdb`). The T548 orphan **sweep** (mode ii, the collector for *pre-existing* orphans) is a **separate later pass** with its own three guards; pass 1 builds the primitive that sweep consumes, and adds **no new process.**
2. **The runner-death case** (a SIGKILLed runner reaps nothing) — T548's sweep + the supervisor's held handles. Deferred, stated (§6), not silenced.
3. **The supervisor rewrite, state consolidation, and dashboards** — grand-race Phase C, later passes.
4. **The other G1 defects** — weight-aware admission (D2/D12), rc=124 honest classification (D3), pause-vs-kill semantics (D1). T549 §4.2 Refinement A batches D1+T548 under one `tools/runner` hold; **pass 1 is the T548 (reaping) slice of that hold**, separate rows/decisions for the rest.
5. **The per-family check is a pre-finalization gate, not executed for every family now**; pass 1 finalizes the `claude -p` seed and *names* the residual families (deepseek-CLI, ollama-subagent) for the next lane.
6. **No engine, ruleset, or epistemic change** (T549 non-goal 3, inherited) — `src/retro.zig`, `oracle.zig`, `rules.zig`, `solve.zig`, the register, and CLAIMS.md are untouched.

---

## 9. Scope finding and best contribution

**Scope is right, with one refinement.** Pass 1 (verb + wire into kill and normal-exit + delete the pgid kill) is the correct first bite: it is the **upstream** of every memory crisis (T548 is first in T549 §4.1 — "reaping is the upstream of every memory crisis this sprint names"), it is **bounded** (one verb at three edit sites, one call-site deletion, one added call-site — §6), and it **defers** the hard cases (runner-death, the blind sweep) to T548 where they belong. **Refinement (§10.4):** design the verb's *walk* as the one primitive the deferred sweep imports, so pass 1 is not a one-off and mode (ii) does not write a second tree walker — the "fewer moving parts" obligation made concrete. If a lane concludes pass 1 is *too small* (e.g. it wants the normal-exit reap AND the sweep together), that is defensible but risks one pass touching both `tools/runner`'s exit paths *and* introducing a collector the no-supervisor rule constrains; this spec holds the line at reaping-only.

**Best contributions, stated plainly (the document is meant to be quarried, not just won):**
1. **§6 + §3(i): "kill the set you already compute."** The strongest, most non-obvious section. The runner *already enumerates the full descendant tree* every poll (`tools/runner:1402`) to sum RSS; the bug is that it kills by **pgid** (`:1554`/`:1481`) instead of by that set. The cannibalization is therefore not "build a reaper" but "wire the existing walk to the exit path and delete the pgid kill" — which simultaneously argues the fewer-moving-parts point and reframes the fix's size. A lane that reads "the walker at :581/:609 is dead code" is **wrong** (it is alive for RSS, `:1402`/`:1230`); a lane that builds a *fourth* walker is spending a moving part the tree already has.
2. **§2 / §4: the `reap` collision and the guard-attribution table.** `managent reap` is the **kanban** orphan reaper (`main.zig:471`); the new verb must not be `reap` (a third meaning), and the T548 three guards (marker-skip, pattern, two-pass) belong to the *sweep*, not the *verb* — importing them would make the verb refuse its own job. Naming this boundary prevents both a name collision and a false "missing-guard" audit finding.
3. **§3(ii) / §5 C8 / §10.1: the per-family + macOS `getsid` degradation.** The most *subtle-but-defensible* section. The brief prescribes `getsid`; this host shows `ps -o sess`≡0 and no `getsid` binary, so the operational check degrades to a ps-only escape proxy (`ppid==1 ∧ pgid==pid`). The reaper is family-agnostic; the *confirmation* is family-specific. This is the one asymmetry the "one interface for every harness" requirement lives or dies on.

---

## 10. Open questions and uncertainties (honest; survive audit or be answered)

1. **`getsid` on macOS.** `ps -o sess`≡0 and no `getsid` binary (verified 2026-08-21). Options: **(a)** ps-only escape proxy `ppid==1 ∧ pgid==self` for pass 1 (no new syscall surface — fewer moving parts); **(b)** add a raw `setsid`/`getsetsid` syscall — but `std/posix.zig` has `kill` (`:378`) and **no** `setsid`/`getsetsid`/`setpgid`/`getpgid`, so this is *new surface* (~a C shim or a Zig raw syscall), not a one-liner; **(c)** accept `pgid==pid` (group leader, necessary for session leader) as the proxy. **Recommendation: (a) for pass 1, (b) as an upgrade if a family's escape is indistinguishable from a non-escape by pgid alone.** Design rules; audit invited.
2. **A separate Zig binary vs an in-process terminator.** The brief mandates the verb in `managent` (Zig). The runner is **Python** (`tools/runner`, 76 KB) and **cannot link** a Zig object; its only non-shim route is to **shell out** to `bin/managent treekill <pid>` on the exit path — adding one process spawn per exit. Cost is real (a spawn on the hot path) but small vs the separation-of-concerns win (the verb is the *single authoritative terminator*, testable standalone, reused by the sweep). **Recommendation: shell out for pass 1.** If the audit prefers zero extra spawn, Design may instead have the runner `exec` a tiny Zig terminator in place — **same contract, different wiring**; the §2 contract is identical, which is the point.
3. **Does the host-guard single-pid kill (`:1481`) join pass 1?** It is the same miss-class as `killpg`. **Recommendation: route it through the verb for consistency (one killer, no second miss-class), keeping a short grace** so relief under memory crisis is not delayed by a multi-round walk. Open: a crisis path may want SIGKILL-only (`--grace 0`) while normal-exit wants a real grace; the `--grace` flag (§2) is there to carry both.
4. **Walk-as-shared-primitive (scope refinement).** The verb's `D(r)` walk and the runner's `:581/:609` walkers and the deferred sweep's tree walk are the *same* operation. Pass 1 should make the **verb the one implementation** and have the runner's RSS walk and the future sweep *call it*, not fork it. Flagged for Design; the risk of *not* doing it is the tree-walker duplication this project has paid for before (the two Python walkers already exist because the walk was not centralized).

---

*Provenance: anonymized P2 process-ownership spec. Citations re-verified 2026-08-21 against the live tree (drift table §0). Built on, not re-derived: T548 brief (`untracked/T548-orphan-suite-reaper.md`), T549/T550 (`docs/infra/fleet-repair/pass1/`), the 2026-07-29 kernel-panic root cause (`docs/infra/host/incident-2026-07-29.md`), and the 2026-08-20 production-chain escape measurement. No model or seat is named, per the race's blinding gate (G4).*
