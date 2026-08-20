# Pass 1 spec — `managent kill-tree`: process-tree ownership by inherited token

## 0. The one design decision (read this first)

The measured mechanism (2026-08-20, this repo, production chain) is that the console
harness starts every tool command in a **new session**, and zig creates no groups of its
own (`std/process.zig:397` — `SpawnOptions.pgid` defaults null). Escapees are therefore
**session leaders**, and once their intermediate parents exit they **reparent to init**,
severing the ppid chain. Two consequences fall out and everything below builds on them:

1. **Topology is not membership.** pgid, sid, and ppid are all forgeable-by-accident and
   all measured to fail here. No walk of the process table rooted at the worker's pid can
   find a tree whose middle has already died.
2. **The only marker that survives reparenting is one the process carries with it.** The
   spec therefore defines membership by an **inherited environment token**: the spawner
   sets `MANAGENT_TREE=<token>` in the child's environment; every descendant inherits it
   across fork/exec unless it deliberately scrubs its environment; the verb enumerates
   the whole process table and selects by token — via the `KERN_PROCARGS2` sysctl (per-pid
   argv+environ, readable for same-uid processes on macOS), not by parsing `ps`.

This is family-agnostic by construction: nothing in the verb knows what a "console
family" is, which is what makes it servable behind one dispatch interface later (§7).

**Claimed best contribution of this spec:** this section plus §4's kill algorithm
(token-scan ∪ descendant-closure, SIGSTOP fixpoint, then SIGKILL) — the only mechanism in
reach on macOS (no cgroups) that provably reaches session-leader escapees after
reparenting — and the **leaked-token guard** in §5 (G2), which closes the one way this
design can go catastrophically wrong.

## 1. "Owned", testably

A spawned child's tree is **owned** iff all five conditions hold, each assertable by a
control:

- **O1 Completeness.** One invocation of the verb terminates every process that is a
  fork-descendant of the spawned child, regardless of its current ppid/pgid/sid.
  *Assert:* post-kill member scan (token ∪ descendant closure) is empty on two scans 1 s
  apart; zombies excluded (they hold no memory and cannot be signaled).
- **O2 Precision.** No process outside the member set receives any signal.
  *Assert:* a live sibling tree under a different token is bit-identical in `ps -axo
  pid,ppid,stat` before/after (modulo the verb's own pid).
- **O3 Idempotence.** A second invocation with the same token exits 0 and signals nothing.
- **O4 Exit-path totality.** The verb is invoked on the ceiling-kill path, the
  normal-exit path, and the host-guard cull path of `tools/runner`.
  *Assert:* `grep -n killpg tools/runner` returns nothing after the pass (§6).
- **O5 Convergence under fork race.** A tree that forks continuously during the reap is
  still fully terminated within the bounded fixpoint (§4).

## 2. The verb's contract

One verb, no proliferation (operator constraint). Name chosen to avoid the word "reap",
which already means kanban-row cleanup in this repo
(`tools/regression-orphan-reaper.sh`, from T364) — the brief's own warning that one word
with two meanings hid this gap for months.

```
managent kill-tree --token <T> [--plan]
```

- `--token <T>`: the value of `MANAGENT_TREE` minted by the spawner. Opaque string,
  **minimum 16 hex characters of entropy enforced** (G2). Minting stays in the caller —
  a token is just a unique string; a `managent mint` verb would be a moving part with no
  behaviour.
- `--plan`: enumerate and print the member set, signal nothing, exit 0. This is both the
  operator's dry-run and the controls' measurement instrument.

**Output shape** (project convention: data on stdout, diagnostics on stderr):
one line per member on stdout, space-separated: `pid ppid disposition`, where
disposition ∈ `killed | already-dead | skipped-foreign | excluded | plan`. Nothing else
on stdout. Progress, warnings, and refusal reasons go to stderr. Callers rely on the
exit code; stdout exists for controls and audits.

**Exit codes:**

| code | meaning | edge cases it covers |
|---|---|---|
| 0 | member set empty after run (killed everything, or nothing matched) | target already dead; token never issued; second run (O3) |
| 1 | usage error | empty token, token under minimum length, unknown flag |
| 3 | survivors remain | non-convergence, env-scrubbed evader found by closure but unkillable, foreign-uid member skipped |
| 4 | refused by guard, **nothing was signaled** | member set would include pid 0/1, self, or an ancestor of self; token present in the verb's own environment |

"Already dead" is success (0), not an error: every runner exit path calls this verb
unconditionally, so the common case on the normal-exit path is an empty or small set.
"Not ours" (uid mismatch) is never signaled and forces exit 3 — a foreign process
carrying our token is an anomaly the caller must see, not a silent skip. "Is pid 1" is
exit 4 with zero signals sent, unconditionally, before any other logic.

## 3. Membership and the measured mechanism's residue

**Member set** = least fixpoint of: (processes whose environment contains
`MANAGENT_TREE=<T>`, read via `KERN_PROCARGS2` over `proc_listallpids`) ∪ (all
ppid-descendants of any member). The closure term catches children that scrubbed their
environment but whose matched parent is still alive; the token term catches
session-leader escapees whose parent chain is gone — the measured leak shape (trees
reparented to init holding gigabytes, observed at 6 orphans, ~4.5 GB, 9.1 GB, and a
recurring 2.8 GB **with 25–27 GB free**, i.e. continuous, not crisis-driven).

**Per-family residual check (required before seeded controls are finalized).** The
session-leader measurement covers `claude -p` only. Once per other console family
([SELF-IDENTIFICATION REDACTED] CLI, `ollama-subagent`), run as a tool command inside that family's harness:

```
ps -o pid,ppid,pgid -p $$ ; python3 -c 'import os; print(os.getsid(0))'
```

(`getsid` via python because macOS `ps -o sess` prints 0.) Compare the reported sid
against the console process's own sid (`os.getsid(<console-pid>)` works same-uid). If
the tool command is a session leader (pid == sid), the family escapes like `claude -p`
and the same seeded arm applies; if not, its escape shape is "children die with severed
dispatch ownership" (`bin/dispatch:301`, `start_new_session=True`) and its seeded arm
seeds *that* shape. **The verb's design does not change either way** — token membership
is topology-blind — only the controls' seeding recipe does. Record each family's result
in the control doc before G3.

## 4. Kill algorithm (spec level, no code)

1. Compute member set (§3). Apply exclusions (G1). If a guard fires, exit 4 now.
2. `SIGSTOP` every member. A stopped process cannot fork.
3. Rescan; `SIGSTOP` any new members. Repeat until two consecutive scans add nothing,
   bounded at 10 iterations; non-convergence → exit 3 with survivors listed.
4. Under `--plan`: `SIGCONT` everything stopped, print set, exit 0. Otherwise `SIGKILL`
   every member (SIGKILL is delivered to stopped processes; no CONT needed).
5. Verify: rescan twice, 1 s apart, zombies excluded. Empty → 0, else 3.

Fixpoint soundness: once all *found* members are stopped, only an unfound member can
create new processes; the token scan finds every extant carrier, so the only evader is a
process that scrubbed its environment **and** whose ancestors up to a carrier are all
dead. That residue is stated honestly in §9 and measured by seeded arm S5.

No graceful-TERM mode: both existing call sites already SIGKILL
(`tools/runner:1432`, `:1505`); adding a grace knob is a moving part with no measured
need.

## 5. Guards, each with its control

The 2026-08-20 seat ran an untested reaper with three hand-reasoned guards. Every guard
below therefore names the arm that proves it, and per this project's instrument doctrine
each control needs a null **and** a seeded-defect arm before its first reading counts.

- **G1 Hard exclusions.** pid 0, pid 1, the verb's own pid, and every ancestor of the
  verb (walked via ppid at startup) are removed from the member set before step 2; if
  the removal was non-empty, exit 4 and signal nothing — an exclusion firing means the
  token has leaked somewhere structural. *Control:* arm C-G1 runs the verb from a shell
  that deliberately exports the token; the shell must survive and the exit be 4.
- **G2 Token hygiene / leaked-token refusal.** Refuse (exit 1) tokens that are empty or
  under 16 hex chars — an empty token matches every process on the machine. Refuse
  (exit 4) if `MANAGENT_TREE` with the same value is present in the verb's **own**
  environment: that means the token escaped into a profile or a parent shell and the
  member set is meaningless. *Controls:* C-G2a empty token → exit 1, zero signals;
  C-G2b own-env token → exit 4, zero signals.
- **G3 Membership only by token-or-closure.** Never by command-name, path, or pattern —
  pattern guards are exactly the hand-reasoned kind that failed before. This is a
  design invariant, asserted by code review plus the precision arm N2.
- **G4 uid guard.** Only same-euid processes are ever signaled. *Control gap, stated:*
  seeding a foreign-uid carrier needs root or a second local user; this control is
  operator-assisted or discharged by review — an honest open question, not a claim.
- **Never killable, ever:** pid 1, the managent process itself, its ancestor chain
  (which includes the calling runner and the operator's console), and any process not
  owned by our uid.

## 6. Cannibalization — the pass is done when the old path is deleted

- `tools/runner` **spawn site** (the `os.setsid()` preexec at `tools/runner:1161`): add
  `MANAGENT_TREE=<token>` to the child's environment, token minted per task (suggested:
  `<task-id>.<128-bit-hex>`). The `setsid` itself stays — it is harmless and still
  correct for the direct child.
- `tools/runner:1505` (ceiling kill): the `os.killpg` call is **deleted** and replaced
  by an invocation of `managent kill-tree --token <T>`.
- **Normal-exit path**: the runner's supervise loop calls the verb after observing child
  exit. Today that path reaps nothing (checkable: the only kill-family call sites in the
  runner are lines 1432 and 1505); the exact insertion line is implementation detail,
  but the acceptance check is O4's grep.
- `tools/runner:1432` (host-guard single-pid SIGKILL): also routed through the verb.
  This is one more call-site swap of the same verb, and it is the exact path that culled
  12 workers on 2026-08-20 and leaked their trees — leaving it as a bare `kill` would
  preserve the incident.
- **Acceptance:** `grep -n 'killpg\|SIGKILL' tools/runner` shows no direct
  process-killing outside the verb invocation wrapper. The verb existing is not done;
  the old code being gone is done.

## 7. Shape for the one-dispatch-interface future

The verb's interface carries **no knowledge of harness, model, flags, or console
family** — it consumes a token and nothing else. Ownership is established by one line at
any spawner (set one env var) and exercised by one command at any exit path. When a
later pass builds the operator's single dispatch command ("shallow common interface
hides deep functionality"), that command mints the token and calls this same verb for
every family; `bin/dispatch:301`'s severed-at-spawn detach becomes fixable by the same
one-line minting without touching the verb. Nothing here is `claude -p`-shaped.

## 8. Controls (named, not written; tests before implementation)

Null arms:
- **N1 never-issued token:** verb with a fresh token → exit 0, empty stdout, full
  `ps` snapshot unchanged.
- **N2 live sibling:** two trees, tokens A and B; kill A; tree B untouched (O2's assert).

Seeded arms:
- **S1 escaped deep tree (per family):** spawn through the production chain a fake test
  suite of nested sleepers; let intermediates exit so leaves reparent to init as session
  leaders (or the family's measured shape per §3); verb finds and kills all; O1 assert.
- **S2 fork race:** a tree fork-bombing slowly during the reap; O5 assert.
- **S3 already dead / double invoke:** exit 0 twice; O3 assert.
- **S4 guard arms:** C-G1, C-G2a, C-G2b from §5.
- **S5 env-scrubbing evader:** a child that execs with a clean environment. Expected
  outcome: caught while its parent lives (closure), *escapes* if seeded to orphan itself
  first — this arm **measures the design's stated residue** rather than asserting zero.

Seeded-defect arms for the instruments themselves: each assert above must be shown
capable of failing (e.g., S1's survivor-scan run against a deliberately not-killed tree
must go red) before its first green counts.

## 9. Non-goals and uncertainties

**Non-goals (pass 1):** no daemon, no supervisor, **no new supervisory process of any
kind** — the fix is that the mechanism works, not that something watches it fail.
Runner-death reaping (a SIGKILLed runner reaps nothing) is T548's sweep and later the
supervisor's held handles. `bin/dispatch:301` console-level ownership, the unified
dispatch command, state consolidation, dashboards, ledger attribution of guard culls
(the "recorded as model failures" corruption), and graceful-TERM semantics are all later
passes.

**Uncertainties, stated:**
1. `KERN_PROCARGS2` truncates at `sysctl kern.argmax`; a process whose argv+environ
   exceed it may be unreadable. Believed rare; S1 on the real chain measures it.
2. A process that scrubs its environment *and* orphans itself evades the scan (S5
   measures the size of this hole). No stronger same-uid marker survives both exec and
   reparenting on macOS without a held resource; an inherited-fd tether enumerated via
   `lsof` was considered and rejected as slower and more fragile — revisit only if S5
   shows real leakage on the production chain.
3. Whether zig's build children inherit the parent environment by default is assumed
   (standard exec inheritance) but must be confirmed on the production chain — S1 is the
   confirmation.
4. G4's foreign-uid control cannot be seeded without a second user (§5).
5. The runner's normal-exit line number is unverified from here; O4's grep is the check
   that does not depend on it.

**Scope verdict:** pass 1 is the right first bite, with one caveat made explicit —
because dispatch-level severance (`bin/dispatch:301`) is out of scope, consoles
themselves remain unowned after this pass and the measured console-harness leak is only
closed for **runner-spawned** trees. That is acceptable precisely because the token
design lets the later pass close the rest by adding minting, not by rewriting the verb.
