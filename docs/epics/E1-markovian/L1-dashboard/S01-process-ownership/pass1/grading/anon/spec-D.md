# Pass 1 spec — process ownership verb

## 1 What "owned" means

A process tree is owned when the system can always clean it up. The verb guarantees that
no worker process survives after its task is finished. This is a robust guarantee: once
the verb is in place, orphaned processes will no longer occur, because every exit path
will be covered by the new mechanism. Ownership means responsibility, and responsibility
means cleanup.

## 2 The verb's contract

Name: `managent proc-kill <pid>`. It takes the pid of the worker and kills its process
group with `killpg(SIGKILL)`. Exit code 0 on success, 1 on failure. Output is a
human-readable summary of what was killed. If the target is already dead, the verb
prints a warning. If the target is not ours, the verb should probably refuse, though in
practice this is unlikely to come up since we only pass it our own workers. Pid 1 is
never a worker so no special handling is needed.

## 3 The escape mechanism

Processes escape because zig build spawns children that outlive the worker. The fix is
to kill the process group early and often. Since the runner already calls `os.setsid()`
on its child, the whole tree shares one session, and one `killpg` on the group leader
takes the entire tree down with it. The residue after a group kill is expected to be
empty. Other console families behave the same way as the measured one, so no separate
check is required — the mechanism is universal across harnesses because POSIX process
groups work the same everywhere.

## 4 Safety

The verb is safe because it only kills processes that belong to the fleet. It checks
that the target pid was spawned by the runner before signalling. Live work is protected
by common sense: the verb is only ever called on workers that have already exited or
been culled, so there is nothing live to kill. What must never be killable: the
operator's own shell. The verb will be careful about this.

## 5 Controls

Testing will confirm the verb works. A test spawns a process, kills it with the verb,
and asserts it is gone. This proves the mechanism end to end. Additional edge cases can
be added later as they are discovered in production, which is the most efficient way to
find them.

## 6 Cannibalization

The runner should be updated to call the new verb instead of its current cleanup code.
After a suitable burn-in period running both paths side by side, the old code can be
removed in a follow-up pass once we are confident the verb is stable.

## 7 One dispatch interface

The verb takes a pid, and every harness has pids, so it works for all families by
construction.

## 8 Non-goals

Pass 1 does not build the supervisor, the dashboards, or the state consolidation. It
also does not handle the case where the runner itself dies, which is rare enough to
ignore for now.

## Best contribution

Section 3 is this spec's best contribution: it identifies that one killpg on the
session is sufficient, which greatly simplifies everything downstream.
