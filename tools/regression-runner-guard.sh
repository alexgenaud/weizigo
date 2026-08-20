#!/bin/sh
# regression-runner-guard.sh — fleet-aware memory guard controls (T362).
#
# The runner's RSS cap is per-process and absolute: it bounds ONE worker
# and says nothing about five at once.  T362 adds a host-pressure guard
# that reads system-wide available memory and, below a danger floor
# derived from hw.memsize, SIGKILLs the LARGEST member of the process
# group — naming the process, its RSS, and the free-memory figure.
#
# Four arms:
#   null control:     a small job runs untouched with plenty of free mem.
#   seeded control:   two processes that each stay under the per-process
#                     cap but (via an injected host reading) cross the
#                     danger floor together — the host guard fires and
#                     kills the larger; the per-process cap does NOT.
#   seeded control:   a job under the floor that stops producing output
#                     is still killed by the progress watchdog, proving
#                     that guard is unchanged.
#   guard-bite:       the per-process cap still bites (regression of the
#                     secondary bound, now generously defaulted).
#
# The danger floor is NEVER tested by actually exhausting host memory.
# The host available-memory reading is INJECTED via
# WEIZIGO_HOST_MEM_AVAIL_MB so the composition case is reproducible and
# safe on any host.
#
# Task: T362 · Role: worker · Model: glm-5.2 · Date: 2026-08-20

set -e

RUNNER="tools/runner"
cd "$(git rev-parse --show-toplevel)"

echo "=== regression-runner-guard: null — small job untouched with free mem ==="
set +e
"$RUNNER" --no-prepend-zig --no-host-guard -- sleep 1 >/tmp/weizigo/t362-null.log 2>&1
NULL_EXIT=$?
set -e
if [ "$NULL_EXIT" -eq 0 ]; then
    if grep -q 'host memory pressure' /tmp/weizigo/t362-null.log; then
        echo "FAIL: null — host guard fired on a small job with free memory"
        cat /tmp/weizigo/t362-null.log
        exit 1
    fi
    echo "PASS: null — small job exit 0, no host-guard fire"
else
    echo "FAIL: null — expected exit 0, got $NULL_EXIT"
    cat /tmp/weizigo/t362-null.log
    exit 1
fi

echo ""
echo "=== regression-runner-guard: seeded — host guard fires on the composition case ==="
# Two children, distinct RSS, BOTH under the per-process cap (8192 MB).
# Inject a host available-memory reading far below the danger floor
# (derived from hw.memsize ≈ 6 GB on a 48 GB host).  The per-process cap
# must NOT fire (neither child is anywhere near 8 GB); the host guard
# MUST fire, kill the largest member, and name the free-memory figure.
# --max-wall 15 is a backstop so a buggy (non-firing) guard fails fast
# instead of hanging on the 120 s sleeps.
set +e
WEIZIGO_HOST_MEM_AVAIL_MB=100 \
"$RUNNER" --no-prepend-zig --rss-cap-mb 8192 --max-wall 15 --no-prepend-zig -- \
    python3 -c "
import subprocess, sys, time
subprocess.Popen([sys.executable, '-c', 'import time; x=bytearray(60*1024*1024); time.sleep(120)'])
subprocess.Popen([sys.executable, '-c', 'import time; x=bytearray(30*1024*1024); time.sleep(120)'])
x = bytearray(10*1024*1024)
time.sleep(120)
" >/tmp/weizigo/t362-seed.log 2>&1
SEED_EXIT=$?
set -e
if [ "$SEED_EXIT" -ne 124 ]; then
    echo "FAIL: seeded — expected exit 124 (guard), got $SEED_EXIT"
    cat /tmp/weizigo/t362-seed.log
    exit 1
fi
if ! grep -q 'host memory pressure' /tmp/weizigo/t362-seed.log; then
    echo "FAIL: seeded — no 'host memory pressure' message"
    cat /tmp/weizigo/t362-seed.log
    exit 1
fi
if ! grep -q 'killed largest member' /tmp/weizigo/t362-seed.log; then
    echo "FAIL: seeded — no 'killed largest member' message"
    cat /tmp/weizigo/t362-seed.log
    exit 1
fi
if ! grep -q 'avail 100 MB' /tmp/weizigo/t362-seed.log; then
    echo "FAIL: seeded — kill message does not name the injected free-memory figure (avail 100 MB)"
    cat /tmp/weizigo/t362-seed.log
    exit 1
fi
if grep -q 'RSS cap .* exceeded' /tmp/weizigo/t362-seed.log; then
    echo "FAIL: seeded — per-process cap fired (it must NOT; each member is under the cap)"
    cat /tmp/weizigo/t362-seed.log
    exit 1
fi
echo "PASS: seeded — host guard fired, killed largest member, named avail figure; per-process cap did not fire"

echo ""
echo "=== regression-runner-guard: seeded — progress watchdog still bites (unchanged) ==="
# A child under the floor (injected high avail) that emits one [progress]
# line then goes silent must be killed by the progress watchdog, NOT the
# host guard.  This proves the host guard did not shadow stuck-detection.
set +e
WEIZIGO_HOST_MEM_AVAIL_MB=48000 \
"$RUNNER" --no-prepend-zig --progress-timeout 2 --max-wall 30 -- \
    python3 -c "
import sys, time
sys.stderr.write('[progress] start\n'); sys.stderr.flush()
time.sleep(30)
" >/tmp/weizigo/t362-prog.log 2>&1
PROG_EXIT=$?
set -e
if [ "$PROG_EXIT" -ne 124 ]; then
    echo "FAIL: progress — expected exit 124, got $PROG_EXIT"
    cat /tmp/weizigo/t362-prog.log
    exit 1
fi
if ! grep -q 'progress timeout' /tmp/weizigo/t362-prog.log; then
    echo "FAIL: progress — no 'progress timeout' message"
    cat /tmp/weizigo/t362-prog.log
    exit 1
fi
if grep -q 'host memory pressure' /tmp/weizigo/t362-prog.log; then
    echo "FAIL: progress — host guard fired under the floor (should not)"
    cat /tmp/weizigo/t362-prog.log
    exit 1
fi
echo "PASS: progress — progress watchdog killed the silent child; host guard did not fire"

echo ""
echo "=== regression-runner-guard: guard-bite — per-process cap still bites ==="
# The secondary bound is still a guard: a runaway allocation under a low
# cap is SIGKILLed (exit 124).  Uses the real (high) host available memory,
# so the host guard does not fire — the per-process cap does.
set +e
"$RUNNER" --no-prepend-zig --rss-cap-mb 50 -- \
    python3 -c "
x = bytearray(200 * 1024 * 1024)
import time
time.sleep(5)
" >/tmp/weizigo/t362-cap.log 2>&1
CAP_EXIT=$?
set -e
if [ "$CAP_EXIT" -eq 124 ] && grep -q 'RSS cap .* exceeded' /tmp/weizigo/t362-cap.log; then
    echo "PASS: guard-bite — per-process cap kill (exit 124)"
else
    echo "FAIL: guard-bite — expected exit 124 with 'RSS cap ... exceeded', got $CAP_EXIT"
    cat /tmp/weizigo/t362-cap.log
    exit 1
fi

echo ""
echo "=== regression-runner-guard: all controls passed ==="