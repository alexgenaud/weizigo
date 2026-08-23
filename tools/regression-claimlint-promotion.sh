#!/bin/sh
# regression-claimlint-promotion.sh — mutation-adequacy promotion gate (T308).
#
# Task: T308 · Role: worker · Model: deepseek-v4-pro · Date: 2026-08-03
#
# DIRECTION Amendment 2 edge 5: a claim about a kernel function may not be
# promoted past CLAIMED until the battery kills the mutants covering it.
# This script runs claimlint and verifies:
#   1. The C8 count matches the expected starting value (0).
#   2. Calibration PASS — the seeded control proves the check CAN be non-zero.
#
# The C8 check itself is report-only (does not fail the run). This regression
# script ensures the count cannot silently rise — if someone promotes a kernel
# claim to PROVEN without closing the G1/G3 gaps, this script fails.
#
# Expected baseline (2026-08-03):
#   C8 violations: 0 — T273's kernel claims are CLAIMED, not PROVEN.
#   Calibration:   PASS
#
# To become gating: the G1/G3 key-agreement gap must close (Phase 2 kernel),
# mutants M1–M4 must be killed, then the floor can be set to 0 in
# tools/hooks/claimlint-floor.json and this check can move from report-only
# to fail-the-run.

set -e

CLAIMLINT="zig-out/bin/weizigo-claimlint"

cd "$(git rev-parse --show-toplevel)"

echo "=== regression-claimlint-promotion: pre-flight ==="
if ! test -x "$CLAIMLINT"; then
    echo "SKIP: $CLAIMLINT not found — build with 'zig build' first"
    exit 0
fi
echo "  $CLAIMLINT is executable"

# Verify the kill matrix exists — the check is blind without it.
KILL_MATRIX="docs/epics/E1-markovian/sprints/verify-battery/pass1/kill-matrix.json"
if ! test -f "$KILL_MATRIX"; then
    echo "SKIP: $KILL_MATRIX not found — check is blind"
    exit 1
fi
echo "  $KILL_MATRIX present"

echo ""
echo "=== regression-claimlint-promotion: C8 baseline ==="
echo "Starting violation count must be 0 — T273's kernel claims are CLAIMED."

# Run claimlint, capture output
OUT=$("$CLAIMLINT" 2>/dev/null) || true

# Extract the C8 violation count
C8_COUNT=$(echo "$OUT" | grep "^  C8 mutation-adequacy violations: " | sed 's/.*: //')
if [ -z "$C8_COUNT" ]; then
    echo "FAIL: could not parse C8 count from claimlint output"
    exit 1
fi

echo "  C8 violation count: $C8_COUNT"

# Starting count is 0 — no PROVEN kernel-function claims with unkilled mutants.
EXPECTED=0
if [ "$C8_COUNT" -ne "$EXPECTED" ]; then
    echo "FAIL: C8 violation count is $C8_COUNT, expected $EXPECTED"
    echo "  This means a kernel-function claim has been promoted to PROVEN without"
    echo "  closing the mutation gaps. Promotions past CLAIMED require G1/G3"
    echo "  (key-agreement, Phase 2 kernel) to close first."
    echo ""
    echo "  Affected rows:"
    echo "$OUT" | grep -A2 "  VIOLATION"
    exit 1
fi
echo "PASS: C8 baseline — $C8_COUNT violations (expected $EXPECTED)"

echo ""
echo "=== regression-claimlint-promotion: calibration ==="
# Verify calibration is PASS — the seeded control proves the check CAN be non-zero.
if ! echo "$OUT" | grep -q "calibration: PASS"; then
    echo "FAIL: calibration did not PASS"
    echo "  A calibration failure means the C8 check is broken — the seeded control"
    echo "  (GLOBAL.CAL-KERNEL-UNKILLED at PROVEN with survived mutant) was not caught,"
    echo "  or the null control (GLOBAL.CAL-KERNEL-KILLED at PROVEN with all killed)"
    echo "  was falsely flagged."
    exit 1
fi
echo "PASS: calibration — seeded control caught, null control silent"

echo ""
echo "=== regression-claimlint-promotion: C8 control detail ==="
# Verify the seeded control is explicitly CAUGHT
if ! echo "$OUT" | grep -A1 "known-bad 11" | grep -q "CAUGHT"; then
    echo "FAIL: known-bad 11 (seeded PROVEN + unkilled) was not CAUGHT"
    exit 1
fi
echo "  known-bad 11: CAUGHT (seeded PROVEN kernel claim with unkilled mutant)"

# Verify the null control is explicitly SILENT
if ! echo "$OUT" | grep -A1 "known-good 9 (C8" | grep -q "SILENT"; then
    echo "FAIL: known-good 9 (null PROVEN + all killed) was not SILENT"
    exit 1
fi
echo "  known-good 9: SILENT (null PROVEN kernel claim with all mutants killed)"

# Verify the CLAIMED-silence control is SILENT
if ! echo "$OUT" | grep -A1 "known-good 9b" | grep -q "SILENT"; then
    echo "FAIL: known-good 9b (CLAIMED + unkilled) was not SILENT"
    exit 1
fi
echo "  known-good 9b: SILENT (CLAIMED kernel claim — only PROVEN triggers)"

echo ""
echo "=== regression-claimlint-promotion: all controls passed ==="
echo "C8 mutation-adequacy check is deployed report-only. Starting count: 0."
echo "No kernel-function claim is PROVEN with unkilled mutants."
echo "To gate: close G1/G3 (key-agreement), kill mutants M1–M4, then set the floor."
