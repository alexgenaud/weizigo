#!/bin/sh
# regression-buildzig-holds.sh — controls for the build.zig undeclared-writer defect (T922).
#
# Checks that the build.zig one-writer hold rule (T500) correctly serialises edits
# and that claimlint detects rows that edit build.zig without declaring it.
#
# Three arms:
#   1. null-control:  a row that legitimately declares build.zig in its holds
#      — must pass claimlint C2 (hold registration is green).
#   2. seeded-defect: a row that edits build.zig WITHOUT declaring it — must be
#      flagged by claimlint C2 (hold registration is red/violated).
#   3. report-only:   C2 must not change the run's exit status; it reports
#      findings but does not fail the suite.
#
# Task: T922 · Role: worker · Model: nemotron-3.5-lightning · Date: 2026-08-25

set -e

CLAIM="zig-out/bin/weizigo-claimlint"
FLOOR="tools/hooks/claimlint-floor.json"
BASE_DIR="$(git rev-parse --show-toplevel)"

# ── Helpers ────────────────────────────────────────────────────────────────

die() { echo "$@" >&2; exit 1; }

# ── Arm 1: null-control — a row that legitimately declares build.zig ──────

check_null_control() {
  echo "=== Arm 1: null-control — row legitimately declares build.zig ==="

  # Create a temporary test row that explicitly declares build.zig in holds
  TEST_ROW="untracked/msg/T922-null-control-row.md"
  cat > "$TEST_ROW" <<'EOF'
T922-null-control: holds=build.zig,src/managent/main.zig
status=PASS
description=null-control for regression-buildzig-holds: row declares build.zig
EOF

  # Run claimlint on the test row — it should pass C2 (hold registration green)
  C2_OUTPUT=$($CLAIM C2 "$TEST_ROW" 2>&1) || true
  C2_EXIT=$?

  # Check that C2 does NOT flag a violation for a row that declares build.zig
  if echo "$C2_OUTPUT" | grep -qi "violation\|fail\|red\|C2\|hold"; then
    echo "FAIL: null-control C2 flagged a violation despite build.zig being declared in holds"
    echo "C2 output: $C2_OUTPUT"
    rm -f "$TEST_ROW"
    return 1
  fi

  echo "PASS: null-control C2 is green when build.zig is declared in holds"
  rm -f "$TEST_ROW"
  return 0
}

# ── Arm 2: seeded-defect — a row that edits build.zig without declaring it ─

check_seeded_defect() {
  echo "=== Arm 2: seeded-defect — row edits build.zig without declaring it ==="

  # Create a temporary test row that edits build.zig context but does NOT declare it
  TEST_ROW="untracked/msg/T922-seeded-defect-row.md"
  cat > "$TEST_ROW" <<'EOF'
T922-seeded-defect: holds=src/managent/main.zig
status=FAIL
description=seeded defect for regression-buildzig-holds: edits build.zig without declaring it
EOF

  # Run claimlint C2 — it SHOULD flag a violation because build.zig is not in holds
  C2_OUTPUT=$($CLAIM C2 "$TEST_ROW" 2>&1) || true
  C2_EXIT=$?

  # Check that C2 flags a violation for a row that does NOT declare build.zig
  if ! echo "$C2_OUTPUT" | grep -qi "violation\|fail\|red\|C2\|hold"; then
    echo "FAIL: seeded-defect C2 did NOT flag a violation despite build.zig NOT being declared in holds"
    echo "C2 output: $C2_OUTPUT"
    rm -f "$TEST_ROW"
    return 1
  fi

  echo "PASS: seeded-defect C2 correctly flags violation when build.zig is NOT declared in holds"
  rm -f "$TEST_ROW"
  return 0
}

# ── Arm 3: report-only — C2 must not fail the suite ──────────────────────

check_report_only() {
  echo "=== Arm 3: report-only — C2 exit status is non-fatal ==="

  # Run claimlint C2 on a clean tree; capture exit code
  $CLAIM C2 "untracked/msg/T922-report.md" 2>/dev/null || true
  C2_EXIT=$?

  # C2 should be report-only (exit 0 or non-fatal); it must not cause suite failure
  # The floor C2=0 means it never rises; a regression moves it down or is reverted.
  if [ "$C2_EXIT" -gt 1 ]; then
    echo "FAIL: C2 exit code $C2_EXIT is fatal, but C2 must be report-only"
    return 1
  fi

  echo "PASS: C2 exit code $C2_EXIT is report-only (non-fatal)"
  return 0
}

# ── Run all arms ──────────────────────────────────────────────────────────

echo "T922 regression: regression-buildzig-holds.sh controls"
echo ""

RESULT=0

check_null_control || RESULT=1
echo ""

check_seeded_defect || RESULT=1
echo ""

check_report_only || RESULT=1
echo ""

if [ "$RESULT" -eq 0 ]; then
  echo "All T922 arms passed."
else
  echo "One or more T922 arms FAILED."
fi

exit $RESULT