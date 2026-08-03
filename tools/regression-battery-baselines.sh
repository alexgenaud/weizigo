#!/bin/sh
# regression-battery-baselines.sh — T292: golden-master baseline comparison,
# fast path. Runs inside `zig build test` (wired in build.zig like
# regression-precommit.sh). Invokes the freshly-built verify-battery binary
# (passed as $1 by addArtifactArg — a compile dependency, so the binary is
# guaranteed fresh) on the four git-tracked WZO1 artifacts and compares the
# results against the committed baseline under exact equality.
#
# The slow full-artifact sweep (4x4 WZO1s + WZO2) is NOT here — it lives
# behind the explicit `zig build battery-sweep` step.
#
# Task: T292 · Role: worker · Model: not stated at dispatch · Date: 2026-08-03

set -e

cd "$(git rev-parse --show-toplevel)"

BATTERY="$1"
if [ -z "$BATTERY" ] || [ ! -x "$BATTERY" ]; then
    echo "FAIL: battery binary not provided/built (argv[1]='$BATTERY')"
    exit 1
fi

python3 tools/battery-baseline-compare.py \
    --battery "$BATTERY" \
    --mode fast \
    --baseline docs/evidence/BATTERY/baselines.json
