#!/usr/bin/env bash
# regression-managent-lock.sh — T337 S0 controls for the flock-based store lock
#
# The mkdir mutex (lockStateDir) leaked on every std.process.exit(1) after
# lock acquisition — cmdClaim alone has 9 exit paths after the lock, and any
# of them orphaned the mutex permanently.  The fix (lockStore/unlockStore)
# uses flock(2): the kernel releases the lock when the holder's fd is closed,
# which happens on ANY process termination.
#
#   control 1  rejection path: run a command that acquires the lock then
#              hits a rejection exit — assert the lock is released (the
#              next command succeeds immediately).
#   control 2  kill -9: start a holder, SIGKILL it, assert the next command
#              completes within a bound instead of hanging.
#
# All fixtures use a temp store at /tmp/weizigo — never the live kanban.
#
# Task: T337 · Role: sprint console · Model: deepseek-v4-pro · Date: 2026-08-04

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/.."
MANAGENT="$ROOT/bin/managent"
FAIL=0
# T445: /tmp/weizigo decays (tmp sweeps, reboots). Create it, and REFUSE to run
# if scratch creation fails — an empty scratch var once sent this suite's arms
# into the LIVE repo (2026-08-18 incident: live kanban wiped, claimlint.zig and
# CLAIMS.md clobbered by fixtures). cd "" succeeds silently; never rely on it.
mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/managent-lock-test-XXXXXX)" || { echo "regression-managent-lock.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
STORE="$WORK/tasks.json"

echo "=== managent-lock regression ==="

# ── control 1: rejection path releases the lock ─────────────────────────
echo "  1. rejection path: lock released after cmdClaim rejects (task not found)"
# Seed a minimal store
printf '{"_sys": {"next_id": 200}}' > "$STORE"

OUT=$(MANAGENT_STORE="$STORE" "$MANAGENT" claim T999 2>&1)
RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "not found"; then
    echo "    PASS: cmdClaim rejected (RC=$RC) — task not found as expected"
else
    echo "    FAIL: expected rejection, got RC=$RC: $(echo "$OUT" | head -2)"
    FAIL=1
fi

# Immediately run another command — must succeed without hanging
OUT2=$(MANAGENT_STORE="$STORE" "$MANAGENT" status 2>&1)
RC2=$?
if [ "$RC2" -eq 0 ]; then
    echo "    PASS: subsequent command succeeded (RC=0) — lock released on rejection"
else
    echo "    FAIL: subsequent command hung or failed RC=$RC2"
    FAIL=1
fi

# Verify no lockfile left with an active holder
LOCKFILE="$STORE.lockfile"
if [ -f "$LOCKFILE" ]; then
    # Lockfile exists on disk (cosmetic — PID+timestamp) but must NOT be
    # actively locked.  Prove by acquiring our own lock on it.
    if python3 -c "
import fcntl, os, sys
fd = os.open('$LOCKFILE', os.O_RDWR | os.O_CREAT, 0o644)
try:
    fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    fcntl.flock(fd, fcntl.LOCK_UN)
    os.close(fd)
    sys.exit(0)
except BlockingIOError:
    os.close(fd)
    sys.exit(1)
" 2>/dev/null; then
        echo "    PASS: lockfile present but NOT locked — flock acquired by test process"
    else
        echo "    FAIL: lockfile still locked — orphaned flock!"
        FAIL=1
    fi
else
    echo "    NOTE: lockfile not present (process cleaned up fd)"
fi

# ── control 2: SIGKILL releases the lock ────────────────────────────────
echo "  2. SIGKILL: killed holder releases the lock"
# Start a managent command that holds the lock briefly, then kill -9 it.
# Use 'managent add' with a pipe stall — stdin read blocks while holding lock.
# Simpler: start a process that acquires the lock and sleeps, then kill it.
printf '{"_sys": {"next_id": 200}}' > "$STORE"

# Seed a task in the store so we can test with a mutating command
printf '{"_sys":{"next_id":201},"T200":{"status":"done","bundle":"T200-test.md","set":"C","holds":[],"needs":[],"caps":[],"amendments":[],"added":"2026-08-04T00:00:00Z","claimed":null,"done":"2026-08-04T00:01:00Z","agent":"test","verdict":"pass"}}' > "$STORE"

# Launch a background process that acquires the lock and sleeps
python3 -c "
import fcntl, os, time
lockfile = '$LOCKFILE'
fd = os.open(lockfile, os.O_RDWR | os.O_CREAT, 0o644)
fcntl.flock(fd, fcntl.LOCK_EX)
os.write(fd, f'pid={os.getpid()} since=test'.encode())
os.ftruncate(fd, os.lseek(fd, 0, os.SEEK_CUR))
time.sleep(30)
" &
HOLDER_PID=$!
sleep 0.5  # Let holder acquire lock

# Verify the lock IS held by trying to acquire it ourselves
if python3 -c "
import fcntl, os, sys
fd = os.open('$LOCKFILE', os.O_RDWR)
try:
    fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    os.close(fd)
    sys.exit(1)  # Lock was free — holder didn't acquire it
except BlockingIOError:
    os.close(fd)
    sys.exit(0)  # Lock held — correct
" 2>/dev/null; then
    echo "    PASS: holder acquired lock (flock EX|NB blocked)"
else
    echo "    FAIL: holder did not acquire lock"
    kill $HOLDER_PID 2>/dev/null
    FAIL=1
fi

# Kill the holder
kill -9 $HOLDER_PID 2>/dev/null
wait $HOLDER_PID 2>/dev/null
sleep 0.2  # Let kernel release the flock

# Now a mutating command must succeed within a bound (the lock was released by SIGKILL)
START=$(python3 -c 'import time; print(time.time())')
OUT3=$(MANAGENT_STORE="$STORE" "$MANAGENT" agent T200 deepseek-v4-pro 2>&1)
RC3=$?
END=$(python3 -c 'import time; print(time.time())')
ELAPSED=$(python3 -c "print($END - $START)")

if [ "$RC3" -eq 0 ]; then
    echo "    PASS: mutating command after SIGKILL succeeded (RC=0) in ${ELAPSED}s"
else
    echo "    FAIL: mutating command after SIGKILL failed RC=$RC3 after ${ELAPSED}s: $(echo "$OUT3" | head -2)"
    FAIL=1
fi

# Verify the elapsed time is under 5s (bounded, not hanging)
if python3 -c "exit(0 if float($ELAPSED) < 5.0 else 1)" 2>/dev/null; then
    echo "    PASS: completed in ${ELAPSED}s (< 5s bound)"
else
    echo "    FAIL: took ${ELAPSED}s — exceeded 5s bound (possible hang)"
    FAIL=1
fi

# Clean up holder
kill $HOLDER_PID 2>/dev/null || true

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-managent-lock: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-managent-lock: FAILURES ==="
    exit 1
fi
