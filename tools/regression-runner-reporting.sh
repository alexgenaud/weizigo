#!/bin/sh
# regression-runner-reporting.sh — controls for tools/runner reporting (T311).
#
# Three arms:
#   null control:    a short command produces exactly one walker-selection
#                    line and a peak-RSS line on exit.
#   seeded control:  zero 'linux walker failed' lines (the darwin noise that
#                    T311 fixed — was per-poll at 250 ms, ~4 lines/s).
#   guard bite:      a memory-eating command under a low --rss-cap-mb is
#                    still SIGKILLed (exit 124) and reports why.
#
# Task: T311 · Role: worker · Model: deepseek-v4-pro · Date: 2026-08-03

set -e

RUNNER="tools/runner"
cd "$(git rev-parse --show-toplevel)"

echo "=== regression-runner-reporting: null — walker announced exactly once ==="
WALKER_COUNT=$("$RUNNER" --no-prepend-zig -- sleep 1 2>&1 | grep -c '\[runner\] process walker:' || true)
if [ "$WALKER_COUNT" -eq 1 ]; then
    echo "PASS: null — exactly one walker-selection line (got $WALKER_COUNT)"
else
    echo "FAIL: null — expected exactly 1 walker line, got $WALKER_COUNT"
    exit 1
fi

echo ""
echo "=== regression-runner-reporting: null — peak RSS reported without --log-rss ==="
"$RUNNER" --no-prepend-zig -- sleep 0.5 2>&1 | grep -q '\[runner\] peak RSS by PID'
echo "PASS: null — peak RSS reported with --log-rss off"

echo ""
echo "=== regression-runner-reporting: seeded — no linux-walker-failed noise ==="
# The pre-T311 runner emitted "linux walker failed (FileNotFoundError),
# falling back to ps" on every poll (250 ms) on darwin.  T311 detects the
# platform once at startup, so this noise is gone.  SKIP on Linux where
# /proc is available and the old code never emitted it either.
if [ "$(uname -s)" = "Linux" ]; then
    echo "SKIP: on Linux /proc platform (noise is darwin-only defect)"
else
    NOISE_COUNT=$("$RUNNER" --no-prepend-zig -- sleep 2 2>&1 | grep -c 'linux walker failed' || true)
    if [ "$NOISE_COUNT" -eq 0 ]; then
        echo "PASS: seeded — zero 'linux walker failed' lines (was ~8/2s before T311)"
    else
        echo "FAIL: seeded — found $NOISE_COUNT 'linux walker failed' lines, expected 0"
        exit 1
    fi
fi

echo ""
echo "=== regression-runner-reporting: seeded — -Doptimize=ReleaseSafe survives ==="
# The pre-T311 runner used exact token equality "-Doptimize" in argv, which
# never matches "-Doptimize=ReleaseSafe".  The fix uses startswith.  SKIP
# when zig is not available (the test runs under zig build test, so zig
# is normally present, but be robust).
if ! command -v zig >/dev/null 2>&1; then
    echo "SKIP: zig not found"
else
    ARGV_LINE=$("$RUNNER" -- zig build -Doptimize=ReleaseSafe --help 2>&1 | grep 'argv =' || true)
    case "$ARGV_LINE" in
        *ReleaseFast*)
            echo "FAIL: seeded — ReleaseFast injected despite -Doptimize=ReleaseSafe"
            echo "  argv: $ARGV_LINE"
            exit 1
            ;;
        *ReleaseSafe*)
            echo "PASS: seeded — ReleaseSafe preserved, ReleaseFast NOT injected"
            ;;
        *)
            echo "FAIL: seeded — unexpected argv line: $ARGV_LINE"
            exit 1
            ;;
    esac
fi

echo ""
echo "=== regression-runner-reporting: guard — RSS cap still bites ==="
# The primary safety property: the guard must still kill on RSS breach.
# Use a low cap (50 MB) and a Python one-liner that allocates 200 MB.
# set +e / set -e because the runner exits 124 on purpose (that IS the pass).
set +e
"$RUNNER" --rss-cap-mb 50 --no-prepend-zig -- python3 -c "
x = bytearray(200 * 1024 * 1024)
import time
time.sleep(5)
" 2>&1 >/dev/null
EXIT_CODE=$?
set -e
if [ "$EXIT_CODE" -eq 124 ]; then
    echo "PASS: guard — RSS cap kill (exit 124)"
else
    echo "FAIL: guard — expected exit 124, got $EXIT_CODE"
    exit 1
fi

echo ""
echo "=== regression-runner-reporting: all controls passed ==="
