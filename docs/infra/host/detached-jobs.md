# Detached jobs

**Owner:** gpt-5.6-luna-pro/T928  
**Date:** 2026-08-25  
**Status:** operational convention, from the operator ruling in T928

## Decision

A long computation is a **job**, not an agent lane. The job is the process, its
PID, its command, its start time, and one redirected log. There is no kanban
row, claim, judgement, arbiter, daemon, or notification for a job. A human or
agent may later inspect the record and log and make a judgement in its own
row.

The state directory is the repository's durable ignored job-state directory,
selected by the operator because job records and logs are important across
sessions but are not source or epistemic evidence. Set `JOB_DIR` to that
directory before using the function. Do not cite a disposable log as evidence;
copy any load-bearing result into the appropriate committed evidence directory
before citing it.

## Launch and record (minimum mechanism)

Run this Bash function in the checkout after setting `JOB_DIR` to the
repository's durable ignored job-state directory. For example, replace the
placeholder with that directory:

```bash
export JOB_DIR="<durable-ignored-job-state-directory>"
```

It records one JSON object per job in `$JOB_DIR/jobs.jsonl`; the `command` is an
argument array, so spaces and shell metacharacters are not ambiguous. The
command must be an executable or script. For a pipeline or shell expression, explicitly invoke `sh -c` (or
`bash -c`) and quote that expression as one argument.

```bash
job_start() {
    local root=${JOB_DIR:?set JOB_DIR to the durable ignored job-state directory} record started_at log pid
    mkdir -p "$root"
    record="$root/jobs.jsonl"
    started_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    # Bash's PID and RANDOM make simultaneous starts in this shell distinct.
    log="$root/job-$(date -u +%Y%m%dT%H%M%SZ)-$$-$RANDOM.log"

    nohup "$@" >"$log" 2>&1 </dev/null &
    pid=$!

    # Use Python only to escape metadata correctly; it is not a supervisor.
    if ! python3 - "$record" "$pid" "$started_at" "$log" "$@" <<'PY'
import json
import sys

record, pid, started_at, log, *command = sys.argv[1:]
with open(record, "a", encoding="utf-8") as stream:
    stream.write(json.dumps({
        "pid": int(pid),
        "command": command,
        "log": log,
        "started_at": started_at,
    }, separators=(",", ":")) + "\n")
PY
    then
        kill "$pid" 2>/dev/null || true
        printf 'job was launched but could not be recorded: pid %s\n' "$pid" >&2
        return 1
    fi
    printf 'pid=%s log=%s started_at=%s\n' "$pid" "$log" "$started_at"
}
```

Example:

```bash
job_start zig run -O ReleaseFast src/retro.zig
# or, when a shell expression is intentional:
job_start sh -c './produce-output --all | tee result.txt'
```

The equivalent primitive, when the function is unnecessary, is:

```bash
nohup <command> >"$JOB_DIR/my-job.log" 2>&1 </dev/null &
echo "pid=$!; command=<command>; log=$JOB_DIR/my-job.log; started_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
```

The function is preferred because it writes the record rather than relying on
copying the terminal line. The record is append-only: never rewrite an old
line to mark a job complete. Completion is inferred from the process and log.
A job that exits before the metadata write is still represented (unless the
metadata write itself fails, in which case the function attempts to kill it
and returns failure).

## List, inspect, and read

The process is the liveness source. For every record, use `ps -p`; do not infer
liveness from an agent heartbeat:

```bash
python3 - <<'PY'
import json
import os
import subprocess

with open(os.path.join(os.environ["JOB_DIR"], "jobs.jsonl"), encoding="utf-8") as stream:
    for line in stream:
        if not line.strip():
            continue
        job = json.loads(line)
        probe = subprocess.run(
            ["ps", "-p", str(job["pid"]), "-o",
             "pid=,state=,etime=,command="],
            capture_output=True, text=True, check=False)
        process = probe.stdout.strip() or "finished (pid absent)"
        print(f"{job['pid']}  {job['started_at']}  {process}  log={job['log']}")
PY
```

For one job, the direct check is:

```bash
ps -p <pid> -o pid=,state=,etime=,command=
tail -n 100 "$JOB_DIR/<log-file>"
tail -f "$JOB_DIR/<log-file>"
```

A missing `ps` row means the process has finished (or the PID has been
reused; compare the recorded start time and command before treating a very old
record as live). The log is the completion output. There is no separate
`collect`, `status`, or notification protocol. If a result must survive log
rotation or cleanup, the job itself must flush/write it incrementally, and a
later judgement must copy it into committed evidence.

## Supervision is optional

Do **not** wrap every detached job in `tools/runner` by default. Direct
`nohup` is the smallest mechanism and is appropriate for a bounded,
understood computation whose output is flushed as it goes. The runner is worth
its cost when the command is untrusted or has a credible runaway risk, and an
RSS cap, progress watchdog, CPU ceiling, or directive polling is needed. In
that case supervise explicitly and record the runner PID and command:

```bash
job_start tools/runner --rss-cap-mb 4096 --max-wall 7200 -- <command> [args...]
```

The runner is still a process, not an agent; its log and PID are inspected in
the same way. A known high-memory build should have its required capacity
admitted and recorded by the operator rather than silently inheriting a cap
that guarantees failure. Detached execution does not remove the host RAM
policy or the need to choose a safe command.

## Boundaries

- Never give a job a `managent` row or close one on the job's behalf. A later
  analysis task owns the judgement and its declared deliverables.
- Never treat a dead PID as success: inspect the exit output and expected
  result. A dead PID only says that execution ended.
- Do not add a daemon, watcher, launchd service, polling loop, or notification
  channel. `ps -p` plus the log is the interface.
- Keep the record and log paths stable. If a result is load-bearing, promote
  the result to committed evidence; the detached log is an execution trace,
  not by itself a verified claim.
