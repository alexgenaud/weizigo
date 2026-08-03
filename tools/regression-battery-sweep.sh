#!/bin/sh
# regression-battery-sweep.sh — T292: golden-master baseline comparison, slow
# full-artifact path. Runs behind the explicit `zig build battery-sweep` step
# (never inside `zig build test`). Covers the three data/ 4x4 WZO1 artifacts
# and the WZO2 artifact (untracked/oracle-v2/oracle-4x4-v2.wzo2) via the
# oracle-v2-accept binary. Host-only artifacts that are absent SKIP loudly.
#
# Every invocation runs under tools/runner (RSS cap 4096 MB per PID) and
# sequentially — one sweep at a time, never concurrently (GRAND-AUDIT §3).
#
# Task: T292 · Role: worker · Model: not stated at dispatch · Date: 2026-08-04

set -e

cd "$(git rev-parse --show-toplevel)"

BATTERY="$1"
ACCEPT="$2"
if [ -z "$BATTERY" ] || [ ! -x "$BATTERY" ]; then
    echo "FAIL: battery binary not provided/built (argv[1]='$BATTERY')"
    exit 1
fi

python3 tools/battery-baseline-compare.py \
    --battery "$BATTERY" \
    --accept "$ACCEPT" \
    --mode sweep \
    --baseline docs/evidence/BATTERY/baselines.json
