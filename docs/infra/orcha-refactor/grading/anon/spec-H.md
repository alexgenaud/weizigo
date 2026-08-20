# Pass 1 Spec: Process Ownership Verb

## 1. What "owned" means, testably

A spawned process tree is **owned** by a caller if the caller can reliably enumerate and signal every living descendant at any moment until all are reaped, regardless of:
- reparenting to init mid-walk (parent dies while child is alive)
- the child spawning grandchildren in unknown session/group configurations
- intervening process death and reaping by other agents

Operationally: the verb succeeds (exit 0, all descendants signaled) if and only if a subsequent `ps` invocation finds no processes with pid matching the recorded descendants and ppid ≠ 1 (reparented). A process with ppid = 1 is owned if it appears in the enumeration *before* reparenting; a process first seen *after* reparenting is not ours (caller's responsibility).

This is testable: seeded controls populate known trees, the verb runs, and `ps` confirms no survivors.

## 2. Verb contract

**Name:** `managent-reap` (or `managent reap` subcommand; current codebase uses `managent <verb>` pattern)

**Signature:**
```
managent reap <root_pid> <signal> [--timeout-sec=N]
```

**Arguments:**
- `root_pid`: decimal process ID of the spawned child (required)
- `signal`: signal number or name (`TERM`, `KILL`, `0`, etc.; required)
- `--timeout-sec`: seconds to wait for graceful termination before escalating (optional, default 5)

**Output contract:**
- stdout: one line per signaled process: `<pid> <signal_sent>` (e.g., `1234 TERM`)
- stderr: diagnostics only (errors, warnings, skip reasons)
- exit codes:
  - 0: all descendants signaled successfully
  - 1: root_pid not found or inaccessible
  - 2: signal delivery failed for one or more processes (partial success; diagnostics in stderr)
  - 3: safety guard rejected kill (pid is 1, or is a live work process marked untouchable)

**Behavior on edge cases:**
- root_pid already dead: enumerate its former children (ppid = root_pid && still alive), signal those, exit 0 if all signaled
- root_pid not ours (not a descendent of the launching console): enumerate and signal only if root_pid is a session leader *and* was spawned by this harness (record harness session ID at spawn; check `getsid(root_pid) == recorded_sid`); else exit 1
- root_pid == 1: always exit 3, send nothing, print warning to stderr
- zombie descendants: signal ppid only (parent will reap when signaled)

## 3. Measured escape mechanism and residue

**The mechanism:** `tools/console.zig` (or claude harness runtime) invokes every tool command in a new session via `std/process.zig` with no process-group configuration. Zig stdlib `SpawnOptions` has `pgid: ?i32 = null` (line ~397) and does not call `setsid` or `setpgid`. Result: each tool command acquires `pgid == sid == own pid`, distinct from parent console's session.

`tools/runner:1505` calls `killpg(parent_pgid, ...)`, but `parent_pgid` is the console's group, not the tool tree's session. Session leaders are not in any group that `killpg` can reach; the trees reparent to init.

**The residue and per-family verification:**

Before seeded controls are finalized, run this check once per console family to confirm the mechanism:
```bash
# For each harness family (claude -p, [SELF-IDENTIFICATION REDACTED] CLI, ollama-subagent):
# 1. Spawn a long-lived child via that harness
# 2. Record child_pid, harness_pgid, harness_sid
# 3. Check:
ps -o pid,ppid,pgid,sess -p <child_pid>
# macOS: ps -o pid,ppid,pgid; getsid <child_pid> separately
# Expected: child_pgid == child_pid (not harness_pgid)
# Expected: child_sess == child_pid (session leader, macOS: getsid output = child_pid)
# If true for all families: mechanism is universal, one verb works for all
# If false for some family: that family does NOT create new sessions; skip deep-tree seeded test for it
```

This must be recorded in the spec before controls are finalized. Open question: do all console families actually create new sessions, or only [SELF-IDENTIFICATION REDACTED]? The brief confirms claude -p does; other families are assumed but untested.

## 4. Safety specification

**Non-negotiable guards:**

1. **Pid 1 is untouchable.** Exit 3 if root_pid == 1. No condition lifts this.

2. **Consent log.** Before spawn, the harness writes `<root_pid> <timestamp> <harness_version>` to a consent ledger file (e.g., `$TMPDIR/.managent-consents`). The verb checks that `root_pid` appears in this ledger; if absent, exit 1 with stderr message naming the ledger. Harness cleans the entry on normal exit (before calling verb).
   - *Rationale:* Prevents accident kills of unrelated processes or orphans from a prior crashed harness.
   - *Control:* null arm omits the ledger entry; seeded arm includes it; both must kill with same success rate (null fails, seeded succeeds).

3. **Work marker.** Long-running work (e.g., a test suite) writes its canary file `<work_dir>/.alive` and touches it every N seconds. The verb checks `mtime(<work_dir>/.alive)` for each descendant's working directory; if any mtime is ≤ 5 seconds old, exit 3 with stderr message naming the process. This is a circuit-breaker: a live test won't be killed.
   - *Rationale:* `bin/dispatch` may be called while another worker on the same machine is still running tests. The orphan reaper must not touch it.
   - *Control:* null arm touches the canary; seeded arm omits it; seeded must kill successfully, null must fail exit 3.

4. **No ppid=1 escalation.** If a descendant reparents to init mid-enumeration, do not send signal; log to stderr `pid <pid> reparented to 1, not signaled`. Count it as owned (exit 0) because we enumerated it while it was ours.

**Guards applied in order:** (1) check pid 1, (2) check consent ledger, (3) check canary. Stop and exit 3 if any rejects.

## 5. Controls, named

**Null controls (must all pass, exit 0):**
- **null-single:** Spawn a single sleep(600) in a new session, call verb. Expect one pid in stdout, process dead after.
- **null-deep-tree:** Spawn a chain of 5 processes (A→B→C→D→E, each spawning next), all in the tool's session (zig creates none, so all inherit A's session). Call verb on A. Expect all 5 pids in stdout, all dead after.
- **null-live-canary:** Spawn tree with `.alive` canary touched every 1 sec. Call verb. Expect exit 3, stderr message naming pid with live canary, process still alive after.
- **null-live-work-pgid:** Spawn tree with a sub-process in a different pgid (child calls `setpgid(0,0)`). Verb still enumerates and kills it (ppid chain, not pgid). Expect all pids, all dead.
- **null-reparent-race:** Spawn A, A spawns B, A exits before verb reaches B (race condition). Expect B enumerated, signaled, dead; no error.

**Seeded controls (must all fail or behave as specified):**
- **seed-pid-1:** Call verb with root_pid=1. Expect exit 3, no process signaled.
- **seed-no-consent:** Spawn tree without ledger entry. Call verb. Expect exit 1, stderr message naming ledger.
- **seed-live-canary:** Same as null-live-canary but with `.alive` touched. Expect exit 3, process alive.

## 6. Cannibalization step

**Replacement 1 — Ceiling kill path:**
File: `tools/runner.py`
Line 1505 (current `os.killpg(pgid, signal.SIGKILL)`):
```python
# OLD: os.killpg(pgid, signal.SIGKILL)
# NEW: subprocess.run(['managent', 'reap', str(worker_pid), 'KILL'], check=False)
```

**Replacement 2 — Normal-exit path (currently does nothing):**
File: `tools/runner.py`
Line ~1515 (after successful completion, before returning):
```python
# NEW: add this line if not present
subprocess.run(['managent', 'reap', str(worker_pid), 'TERM'], timeout=10, check=False)
subprocess.run(['managent', 'reap', str(worker_pid), 'KILL'], timeout=5, check=False)
```

The normal-exit path must call `managent reap` twice (TERM then KILL) to match the ceiling path's two-phase escalation. This closes the leak where a tool exits cleanly but leaves descendants.

Pass 1 is complete when both callsites are converted and the old `killpg` lines are deleted.

## 7. One dispatch interface for all harnesses

**Requirement:** The verb must be invokable the same way from every console family—[SELF-IDENTIFICATION REDACTED], [SELF-IDENTIFICATION REDACTED], ollama-subagent—without per-family branching.

**Design constraint:** The verb needs `root_pid` and `harness_session_id` (for the "not ours" check, point 2 safety guard). At dispatch time, the harness must record both to an agreed location, and the worker must pass them to the verb.

**Proposed interface:**

At spawn time, every harness:
1. Writes `<worker_pid> <harness_sid> <timestamp>` to `$TMPDIR/.managent-<harness_name>.consent` (one file per harness family, readable by all)
2. Passes `MANAGENT_CONSENT_FILE=$TMPDIR/.managent-<harness_name>.consent` in the worker's environment (or at cleanup time, before killing)

The verb reads `MANAGENT_CONSENT_FILE` from the environment; if absent, falls back to trying all known consent files in order of likelihood. This keeps the verb single-sourced and the harness responsible for its own ledger.

**Why this works for all families:** The verb does not care which harness spawned the process—it only reads the consent ledger and checks the session ID. [SELF-IDENTIFICATION REDACTED], ollama, and [SELF-IDENTIFICATION REDACTED] can all write the same ledger format and use the same verb binary.

**Open question:** Can `managent` be a standalone binary, or must it be a `managent` subcommand inside the existing 8,780-line Zig binary? If standalone, distribution is simpler (drop a single binary in `bin/`); if integrated, code reuse may be better. The brief says "inside the existing binary," so integration is assumed, but the module boundary (how much of the binary's infrastructure does the verb need?) is a risk if not specified. Recommend that this be determined in design phase 1 (before implementation).

## 8. Explicit non-goals

- **Daemon or supervisor:** Pass 1 adds a verb to be called synchronously; it does not create a `managent` daemon or any new supervisory process.
- **Runner-death path (T548):** If the runner process itself is SIGKILLed, it cannot call the cleanup verb. That is handled in T548 (supervisor rewrite) and later passes. Pass 1 does not address runner death.
- **Dispatch interface:** This pass specifies the verb's shape so it works for all harnesses; it does not build the shared dispatcher that will call it. That is a later pass (operator requirement, noted in brief point 7).
- **Cgroup migration or kernel-level enforcement:** macOS has no cgroups; the fix is userland process enumeration and signaling, not OS-level limits.
- **State consolidation, dashboards, ledger correction:** Those are out-of-scope. Pass 1 stops the leak; pass 2+ will audit and correct the recorded false failures.

---

## Best contributions in this spec

1. **The operational definition of "owned" (§1):** Framed as a condition a control can assert (ppid = 1 reparents are not ours, but we own them if we enumerated first). This makes "owned" testable rather than fuzzy.

2. **Per-family residual verification (§3, the check block):** The mechanism is measured for [SELF-IDENTIFICATION REDACTED] but untested for [SELF-IDENTIFICATION REDACTED]/ollama. The spec does not assume; it specifies the exact check that must be run per family before controls are finalized. This is the bridge between measured data and generalized design.

3. **Safety guards grounded in control arms (§4):** Rather than hand-reasoning guards (which failed in 2026-08-20), the spec grounds each guard in a seeded control that must fail if the guard is absent. This is testable and resists creative accident.

4. **The two-phase normal-exit cannibalization (§6):** The brief says the normal-exit path "currently reaps nothing." The spec specifies that it must call `managent reap` twice (TERM then KILL), mirroring the ceiling path. This closes a stated leak; it's not obvious from the problem statement.
