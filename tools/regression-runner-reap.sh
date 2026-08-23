#!/usr/bin/env bash
# regression-runner-reap.sh — T548 controls: dead workers must not leak suite children
#
# On 2026-08-20 the fleet measured the leak four times in one day: 6 orphaned
# processes in the morning (DARGUS), ~4.5 GB at 15:40, **9.1 GB** at 16:51
# (free memory 0.06 GB, swap 2.9/4 GB), and 2.8-2.9 GB repeatedly at 17:08
# while free memory was HEALTHY.  Every one traced to an ancestry ending at
# init with no live worker: a worker's `zig build test` descendants survive
# the worker's death, reparented to launchd, holding multi-GB RSS.
#
# The 2026-08-20 RED: the runner killed only its process group (`SIGKILL
# pgid`), and `zig build`'s children escaped it (new sessions via setsid,
# or the build daemon outlived the signal) — nothing reaped them.  T557
# (pass-1 process ownership) replaced the pgid kill with `managent treekill`
# (a full descendant-tree walk) on every exit path; T548 adds the sweeper
# (`tools/runner --reap-orphans`) for orphans that already exist, because
# the runner cannot retroactively collect what earlier crashes stranded.
#
# Controls (test-first, per the standing tooling rule):
#
#   A1 seeded (the brief's first control): a stub worker spawns a
#        long-lived child AND a session-ESCAPING child (setsid — the shape
#        the pgid kill could never reach), then the worker is killed by the
#        RSS cap.  Both children must be gone.  RED against the 2026-08-20
#        killpg code (the escapee survived); GREEN today via treekill.
#   A2a seeded: same via the WALL ceiling (silent child, --max-wall) → child
#        reaped.
#   A2b seeded: same via the RSS cap → child reaped.
#   A2c seeded: same via the DECLARED-NEED OVERRUN STOP (--ram-mb sizes
#        --rss-cap-mb to ceil(ram_mb * 1.25), INV-4) → child reaped.  T821
#        (docs/infra/host/ram-policy.md) deletes the host floor this arm
#        used to trip; the overrun stop is its replacement as "a
#        memory-pressure-shaped kill, not the plain RSS cap of A2b."
#   A2d seeded: same via the DIRECTIVE kill (managent-style kill directive
#        written to a scratch directives.jsonl mid-run) → child reaped.
#   A3  null: a LIVE worker with a live suite-shaped child — two sweeps
#        must leave the child untouched (the worker-marker guard), and the
#        runner's normal exit must then reap it (C2).
#   A4  seeded: a pre-existing orphan and a live runner-owned child side by
#        side — the sweeper takes the orphan only.
#   A5  seeded: a process orphaned for ONE pass only is NOT reaped (the
#        two-pass guard; --orphan-pass-min is injectable for the test).
#   A6  seeded (hardening earned on 2026-08-22): an orphan-SHAPED suite
#        binary attached to a LIVE non-worker session (a console/shell, the
#        shape `pi` consoles and nohup'd terminals take) is NOT reaped.
#        The brief's literal guard list (subagent / claude -p / runner /
#        fleet-keeper) misses these — three live suite binaries on this
#        host had no worker marker in their chain, and a reaper that kills
#        live work is far worse than the leak.
#
# Everything runs from a scratch git repo under /tmp/weizigo — the live
# kanban, live untracked/ and the live repo are never touched (T512/F3:
# the closing check scans the LIVE heartbeat.jsonl for fixture commands).
# MANAGENT_TASK_ID (env, not --task-id) names the fixture runs so no
# auto-claim touches any kanban.
#
# Task: T548 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-22

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
RUNNER="$PROJECT/tools/runner"
FAIL=0
LEFTOVERS=""

mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/t548-reap-XXXXXX)" || { echo "regression-runner-reap.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
REPO="$WORK/repo"
mkdir -p "$REPO/untracked" "$REPO/docs/infra/managent"
( cd "$REPO" && git init -q && printf 'untracked/\n' > .gitignore && git add -A && git commit -qm base )

# ── live-telemetry baseline + closing isolation (T512, F3) ────────────────
LIVE_HB="$PROJECT/untracked/heartbeat.jsonl"
LIVE_HB_BASE=$(wc -l < "$LIVE_HB" 2>/dev/null || echo 0)

check_isolation() {
    ISO_FAIL=0
    APPENDED=$(tail -n +$((LIVE_HB_BASE + 1)) "$LIVE_HB" 2>/dev/null)
    if [ -z "$APPENDED" ]; then
        echo "    PASS: live heartbeat.jsonl — no lines appended during the run"
    elif echo "$APPENDED" | grep -q "t548-reap-"; then
        echo "    FAIL: fixture heartbeat line(s) appended to the LIVE heartbeat.jsonl (F3 regression)"
        echo "$APPENDED" | grep -n "t548-reap-" | sed 's/^/    | /'
        ISO_FAIL=1
    else
        echo "    PASS: live heartbeat.jsonl — appended lines carry no fixture data"
    fi
    [ "$ISO_FAIL" -eq 0 ] || exit 1
}

cleanup() {
    # SIGCONT first (a refused-rollback control may leave stopped pids), then
    # kill everything whose argv carries the scratch path, then leftovers.
    if [ -n "${WORK:-}" ]; then
        pkill -CONT -f "$WORK" 2>/dev/null
        pkill -9 -f "$WORK" 2>/dev/null
    fi
    if [ -n "$LEFTOVERS" ]; then
        for p in $LEFTOVERS; do
            kill -CONT "$p" 2>/dev/null
            kill -9 "$p" 2>/dev/null
        done
    fi
    rm -rf "$WORK"
    check_isolation
}
trap cleanup EXIT

# ── fixture helpers ────────────────────────────────────────────────────
# A suite binary is a `.zig-cache/o/<hash>/test` process.  The real ones
# are zig test binaries; the fixtures are small python scripts with a
# shebang named `test` under a fake `.zig-cache/o/<hash>/` path — the
# sweeper matches the command line, and a python fixture has no children
# of its own (killing it is a complete kill, no sleep stragglers).

mk_suite_fixture() {  # <dir>  ->  creates dir/.zig-cache/o/<hash>/test
    local d="$1" hash="$2"
    mkdir -p "$d/.zig-cache/o/$hash"
    cat > "$d/.zig-cache/o/$hash/test" <<'PYEOF'
#!/usr/bin/env python3
import time
time.sleep(1000)
PYEOF
    chmod +x "$d/.zig-cache/o/$hash/test"
}

pid_of() {  # grep pattern -> first pid (the pattern must be unique enough)
    ps -axo pid=,command= | grep -F "$1" | grep -v grep | awk '{print $1}' | head -1
}

alive() { [ -n "$1" ] && ps -p "$1" >/dev/null 2>&1; }

# The worker fixture: spawn <n> long-lived children (writing their pids to
# the tag file), optionally one session-escaping (setsid), wait so the
# runner's polls observe the full tree (seed completeness), then hog memory
# to trip a low RSS cap.  The marker T548REAPFIX rides in the children's
# argv so the F3 isolation scan can find any leaked heartbeat.
cat > "$WORK/worker.py" <<'PYEOF'
import os, subprocess, sys, time
tag = sys.argv[1]
esc = len(sys.argv) > 2 and sys.argv[2] == "escape"
code = "import time; time.sleep(1000)  # T548REAPFIX"
pids = []
pids.append(subprocess.Popen([sys.executable, "-c", code]).pid)
if esc and hasattr(os, "setsid"):
    pids.append(subprocess.Popen([sys.executable, "-c", code], start_new_session=True).pid)
open(tag, "w").write(" ".join(str(p) for p in pids))
time.sleep(2)                      # let the poll observe the full tree
x = bytearray(200 * 1024 * 1024)   # trip the RSS cap (200 MB > any arm's cap)
time.sleep(120)
PYEOF

# A spawner that holds a suite-shaped child via an env var (no fixture path
# in ITS command line — used by the live-session arm so the chain is
# fixture -> live non-zig session, cleanly).
cat > "$WORK/holder.py" <<'PYEOF'
import os, subprocess, time
subprocess.Popen([os.environ["T548FIXTURE"]])
time.sleep(float(os.environ.get("T548HOLD", "15")))
PYEOF

SWEEP() {  # sweep with a scratch state; $1 = log file; $2 = state file; rest = extra args
    local log="$1" state="$2"; shift 2
    python3 "$RUNNER" --reap-orphans --orphan-state-file "$state" \
        --orphan-pass-min 1 --orphan-log "$WORK/sweep-reap.log" "$@" \
        >"$log.out" 2>"$log.err"
}

# ── A1: the brief's first control — worker killed, BOTH children gone ─────
echo "=== regression-runner-reap: A1 — worker killed (RSS cap); child AND setsid-escapee reaped ==="
TAG="$WORK/a1.tag"
( cd "$REPO" && MANAGENT_TASK_ID=T548A1 "$RUNNER" --no-prepend-zig --no-host-guard \
    --rss-cap-mb 50 --max-wall 60 -- \
    sh -c "python3 '$WORK/worker.py' '$TAG' escape" >/dev/null 2>"$WORK/a1.run.log" )
RC=$?
CHILDREN=$(cat "$TAG" 2>/dev/null || echo "")
A1_OK=1
[ "$RC" -eq 124 ] || { echo "    FAIL: expected exit 124 (RSS cap), got $RC"; A1_OK=0; }
grep -q 'survivors=0' "$WORK/a1.run.log" || { echo "    FAIL: reap line missing survivors=0"; A1_OK=0; }
for c in $CHILDREN; do
    if alive "$c"; then echo "    FAIL: child $c survived the worker's death"; A1_OK=0; LEFTOVERS="$LEFTOVERS $c"; fi
done
if [ "$A1_OK" -eq 1 ]; then
    echo "    PASS: exit 124, treekill survivors=0, both the normal child and the setsid escapee are dead"
else
    FAIL=1
    grep 'reap:' "$WORK/a1.run.log" | tail -2 | sed 's/^/    | /'
fi

# ── A2a: wall ceiling ─────────────────────────────────────────────────────
echo "=== regression-runner-reap: A2a — wall ceiling kills worker AND child ==="
TAG="$WORK/a2a.tag"
( cd "$REPO" && MANAGENT_TASK_ID=T548A2A "$RUNNER" --no-prepend-zig --no-host-guard \
    --max-wall 3 --progress-timeout 0 -- \
    sh -c "python3 '$WORK/worker.py' '$TAG'" >/dev/null 2>"$WORK/a2a.run.log" )
RC=$?
CHILDREN=$(cat "$TAG" 2>/dev/null || echo "")
A2A_OK=1
[ "$RC" -eq 124 ] || { echo "    FAIL: expected exit 124 (wall ceiling), got $RC"; A2A_OK=0; }
grep -q 'wall ceiling' "$WORK/a2a.run.log" || { echo "    FAIL: no wall-ceiling kill message"; A2A_OK=0; }
grep -q 'survivors=0' "$WORK/a2a.run.log" || { echo "    FAIL: reap line missing survivors=0"; A2A_OK=0; }
for c in $CHILDREN; do
    if alive "$c"; then echo "    FAIL: child $c survived the wall kill"; A2A_OK=0; LEFTOVERS="$LEFTOVERS $c"; fi
done
[ "$A2A_OK" -eq 1 ] && echo "    PASS: wall ceiling killed the worker and reaped the child (survivors=0)" || FAIL=1

# ── A2b: RSS cap ──────────────────────────────────────────────────────────
echo "=== regression-runner-reap: A2b — RSS cap kills worker AND child ==="
TAG="$WORK/a2b.tag"
( cd "$REPO" && MANAGENT_TASK_ID=T548A2B "$RUNNER" --no-prepend-zig --no-host-guard \
    --rss-cap-mb 50 --max-wall 60 -- \
    sh -c "python3 '$WORK/worker.py' '$TAG'" >/dev/null 2>"$WORK/a2b.run.log" )
RC=$?
CHILDREN=$(cat "$TAG" 2>/dev/null || echo "")
A2B_OK=1
[ "$RC" -eq 124 ] || { echo "    FAIL: expected exit 124 (RSS cap), got $RC"; A2B_OK=0; }
grep -q 'RSS cap' "$WORK/a2b.run.log" || { echo "    FAIL: no RSS-cap kill message"; A2B_OK=0; }
grep -q 'survivors=0' "$WORK/a2b.run.log" || { echo "    FAIL: reap line missing survivors=0"; A2B_OK=0; }
for c in $CHILDREN; do
    if alive "$c"; then echo "    FAIL: child $c survived the RSS kill"; A2B_OK=0; LEFTOVERS="$LEFTOVERS $c"; fi
done
[ "$A2B_OK" -eq 1 ] && echo "    PASS: RSS cap killed the worker and reaped the child (survivors=0)" || FAIL=1

# ── A2c: declared-need overrun stop (T821 — the host floor this arm used
#         to trip is DELETED, docs/infra/host/ram-policy.md; INV-4's
#         overrun stop is the new memory-pressure-shaped kill trigger) ────
echo "=== regression-runner-reap: A2c — declared-need overrun stop kills worker AND child (T821) ==="
TAG="$WORK/a2c.tag"
( cd "$REPO" && MANAGENT_TASK_ID=T548A2C \
    "$RUNNER" --no-prepend-zig --ram-mb 100 --max-wall 60 -- \
    sh -c "python3 '$WORK/worker.py' '$TAG'" >/dev/null 2>"$WORK/a2c.run.log" )
RC=$?
CHILDREN=$(cat "$TAG" 2>/dev/null || echo "")
A2C_OK=1
[ "$RC" -eq 124 ] || { echo "    FAIL: expected exit 124 (overrun stop), got $RC"; A2C_OK=0; }
grep -q 'RSS cap 125 MB exceeded' "$WORK/a2c.run.log" || { echo "    FAIL: no overrun-stop kill message (rss cap sized to ceil(100*1.25))"; A2C_OK=0; }
grep -q "overrunning its OWN declared need" "$WORK/a2c.run.log" || { echo "    FAIL: no INV-4 overrun note"; A2C_OK=0; }
grep -q 'survivors=0' "$WORK/a2c.run.log" || { echo "    FAIL: reap line missing survivors=0"; A2C_OK=0; }
for c in $CHILDREN; do
    if alive "$c"; then echo "    FAIL: child $c survived the overrun-stop kill"; A2C_OK=0; LEFTOVERS="$LEFTOVERS $c"; fi
done
[ "$A2C_OK" -eq 1 ] && echo "    PASS: declared-need overrun stopped the worker and reaped the child (survivors=0)" || FAIL=1

# ── A2d: directive kill (mid-run poll reads the scratch directives.jsonl) ─
echo "=== regression-runner-reap: A2d — kill directive stops the worker AND reaps the child ==="
TAG="$WORK/a2d.tag"
( cd "$REPO" && MANAGENT_TASK_ID=T548A2D "$RUNNER" --no-prepend-zig --no-host-guard \
    --max-wall 60 --directive-poll-s 1 -- \
    sh -c "python3 '$WORK/worker.py' '$TAG'" >/dev/null 2>"$WORK/a2d.run.log" ) &
RPID=$!
sleep 2
printf '{"id": "D548", "target": "T548A2D", "directive": "kill", "from": "regression-runner-reap", "read": false, "ts": "%s"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$REPO/docs/infra/managent/directives.jsonl"
wait "$RPID"
RC=$?
CHILDREN=$(cat "$TAG" 2>/dev/null || echo "")
A2D_OK=1
[ "$RC" -eq 124 ] || { echo "    FAIL: expected exit 124 (directive kill), got $RC"; A2D_OK=0; }
grep -q 'directive D548 KILL' "$WORK/a2d.run.log" || { echo "    FAIL: no directive-kill message"; A2D_OK=0; }
grep -q 'survivors=0' "$WORK/a2d.run.log" || { echo "    FAIL: reap line missing survivors=0"; A2D_OK=0; }
for c in $CHILDREN; do
    if alive "$c"; then echo "    FAIL: child $c survived the directive kill"; A2D_OK=0; LEFTOVERS="$LEFTOVERS $c"; fi
done
[ "$A2D_OK" -eq 1 ] && echo "    PASS: directive kill stopped the worker and reaped the child (survivors=0)" || FAIL=1

# ── A3: null — live worker with a live child is untouched by sweeps ───────
echo "=== regression-runner-reap: A3 — live worker's suite child survives two sweeps ==="
mk_suite_fixture "$WORK/live" feedface
FIX_LIVE="$WORK/live/.zig-cache/o/feedface/test"
( cd "$REPO" && MANAGENT_TASK_ID=T548A3 "$RUNNER" --no-prepend-zig --no-host-guard \
    --max-wall 30 -- \
    sh -c "python3 -c 'import subprocess,time; subprocess.Popen([\"$FIX_LIVE\"]); time.sleep(12)'" \
    >/dev/null 2>"$WORK/a3.run.log" ) &
RPID=$!
sleep 3
LIVE_CHILD=$(pid_of "$WORK/live/.zig-cache/o/feedface/test")
alive "$LIVE_CHILD" || { echo "    FAIL: live child never came up"; FAIL=1; LEFTOVERS="$LEFTOVERS $RPID"; }
SWEEP "$WORK/a3s1" "$WORK/a3.state"
SWEEP "$WORK/a3s2" "$WORK/a3.state"
sleep 1
if alive "$LIVE_CHILD"; then
    echo "    PASS: live runner-owned child survived two sweeps (worker-marker guard)"
else
    echo "    FAIL: live runner-owned child was reaped by the sweeper — live work killed"
    FAIL=1
fi
wait "$RPID"
# The runner's NORMAL exit must now reap its own tree (C2) — the same child
# that survived the sweeps dies the moment the worker exits.
if alive "$LIVE_CHILD"; then
    echo "    FAIL: child survived the runner's normal exit — C2 reap missing"
    FAIL=1
    LEFTOVERS="$LEFTOVERS $LIVE_CHILD"
else
    echo "    PASS: runner's normal exit reaped its own tree (C2)"
fi

# ── A4: sweeper seeded — orphan + live-owned side by side, orphan only ────
echo "=== regression-runner-reap: A4 — pre-existing orphan reaped; live-owned untouched ==="
mk_suite_fixture "$WORK/orphan" deadbeef
FIX_ORPHAN="$WORK/orphan/.zig-cache/o/deadbeef/test"
# orphan: launch in a subshell that exits at once → reparented to launchd
( sh -c "exec '$FIX_ORPHAN'" & ) 2>/dev/null
sleep 1
ORPHAN_PID=$(pid_of "$WORK/orphan/.zig-cache/o/deadbeef/test")
PPID_OF=$(ps -o ppid= -p "$ORPHAN_PID" 2>/dev/null | tr -d ' ')
if [ "$PPID_OF" != "1" ]; then
    echo "    FAIL: orphan fixture did not reparent to init (ppid=$PPID_OF)"
    FAIL=1
fi
# live-owned: a real runner-wrapped worker holding the same fixture shape
( cd "$REPO" && MANAGENT_TASK_ID=T548A4 "$RUNNER" --no-prepend-zig --no-host-guard \
    --max-wall 30 -- \
    sh -c "python3 -c 'import subprocess,time; subprocess.Popen([\"$WORK/live/.zig-cache/o/feedface/test\"]); time.sleep(12)'" \
    >/dev/null 2>"$WORK/a4.run.log" ) &
RPID=$!
sleep 3
LIVE_CHILD=$(pid_of "$WORK/live/.zig-cache/o/feedface/test")
SWEEP "$WORK/a4s1" "$WORK/a4.state"
if alive "$ORPHAN_PID"; then
    echo "    PASS: pass 1 tracks, does not reap (two-pass guard)"
else
    echo "    FAIL: orphan reaped on pass 1 — two-pass guard broken"
    FAIL=1
fi
sleep 2
SWEEP "$WORK/a4s2" "$WORK/a4.state"
A4_OK=1
if alive "$ORPHAN_PID"; then
    echo "    FAIL: orphan survived pass 2 — sweeper did not reap it"
    A4_OK=0
fi
if alive "$LIVE_CHILD"; then
    echo "    PASS: live-owned child untouched alongside the orphan"
else
    echo "    FAIL: live-owned child was reaped — collateral damage"
    A4_OK=0
    LEFTOVERS="$LEFTOVERS $RPID"
fi
grep -q 'orphan-sweep: REAP' "$WORK/a4s2.err" || { echo "    FAIL: pass 2 logged no REAP"; A4_OK=0; }
[ "$A4_OK" -eq 1 ] && echo "    PASS: sweeper took the orphan only" || FAIL=1
wait "$RPID" 2>/dev/null

# ── A5: two-pass guard — one pass alone never reaps ───────────────────────
echo "=== regression-runner-reap: A5 — one-pass orphan is NOT reaped (two-pass guard) ==="
mk_suite_fixture "$WORK/onepass" beadedba
FIX_ONEPASS="$WORK/onepass/.zig-cache/o/beadedba/test"
( sh -c "exec '$FIX_ONEPASS'" & ) 2>/dev/null
sleep 1
ONEPASS_PID=$(pid_of "$WORK/onepass/.zig-cache/o/beadedba/test")
PPID_OF=$(ps -o ppid= -p "$ONEPASS_PID" 2>/dev/null | tr -d ' ')
if [ "$PPID_OF" != "1" ]; then
    echo "    FAIL: one-pass orphan fixture did not reparent to init (ppid=$PPID_OF)"
    FAIL=1
fi
# pass 1 with a FRESH state: observes, tracks, must NOT reap
SWEEP "$WORK/a5s1" "$WORK/a5.state"
alive "$ONEPASS_PID" || { echo "    FAIL: reaped on the FIRST pass — two-pass guard broken"; FAIL=1; }
# pass 2 with ANOTHER fresh state: still a first observation → must NOT reap
SWEEP "$WORK/a5s2" "$WORK/a5.state.2"
sleep 2
if alive "$ONEPASS_PID"; then
    echo "    PASS: two first-passes (fresh state each) reaped nothing — one pass is never enough"
else
    echo "    FAIL: a single-pass observation was reaped — two-pass guard broken"
    FAIL=1
fi
# pass 3 reusing the pass-2 state: now a SECOND observation ≥1s old → reap
SWEEP "$WORK/a5s3" "$WORK/a5.state.2"
if alive "$ONEPASS_PID"; then
    echo "    FAIL: second observation (≥1s apart) did not reap"
    FAIL=1
    LEFTOVERS="$LEFTOVERS $ONEPASS_PID"
else
    echo "    PASS: second orphaned pass ≥1s later reaped it"
fi

# ── A6: live-session guard — orphan-SHAPED but attached to a live session ─
echo "=== regression-runner-reap: A6 — session-attached suite child is NOT reaped ==="
mk_suite_fixture "$WORK/session" cafebabe
FIX_SESSION="$WORK/session/.zig-cache/o/cafebabe/test"
# the session holder is a LIVE non-worker process (a console/shell stand-in);
# its child looks exactly like an orphaned suite binary but is attached work.
T548FIXTURE="$FIX_SESSION" T548HOLD=12 python3 "$WORK/holder.py" &
HPID=$!
sleep 2
SESSION_CHILD=$(pid_of "$WORK/session/.zig-cache/o/cafebabe/test")
SWEEP "$WORK/a6s1" "$WORK/a6.state"
sleep 2
SWEEP "$WORK/a6s2" "$WORK/a6.state"
if alive "$SESSION_CHILD" && alive "$HPID"; then
    echo "    PASS: session-attached child survived two sweeps (live-session guard)"
else
    echo "    FAIL: session-attached child was reaped — live work killed"
    FAIL=1
    LEFTOVERS="$LEFTOVERS $SESSION_CHILD $HPID"
fi
kill "$HPID" 2>/dev/null

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-runner-reap: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-runner-reap: FAILURES ==="
    exit 1
fi
