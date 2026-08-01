#!/bin/bash
# T227 regression tests — acceptance-check defect fixes
# Run: tools/regression-T227.sh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MANAGENT="$PROJECT_DIR/bin/managent"
FAILURES=0

red() { echo "  FAIL: $*"; FAILURES=$((FAILURES + 1)); }
green() { echo "  PASS: $*"; }

echo "=== T227 regression tests ==="
echo ""

# Helper: create a test task from a pre-written bundle.
# Uses managent add --auto to register, then claims it.
create_and_claim() {
    local bundle_path="$1"
    local id
    id=$("$MANAGENT" add --auto --bundle "$bundle_path" --set A 2>&1 | grep -o 'T[0-9][0-9]*' | head -1)
    if [ -z "$id" ]; then
        echo "ERROR: could not create task from $bundle_path" >&2
        return 1
    fi
    "$MANAGENT" claim "$id" >/dev/null 2>&1 || true
    echo "$id"
}

# ── Test 1: signal-killed acceptance command must be REJECTED ──
echo "--- Defect 1: signal-killed acceptance ---"

BUNDLE1="$PROJECT_DIR/untracked/T227-regtest-sigkill-bundle.md"
cat > "$BUNDLE1" << 'BUNDLEEOF'
<!--managent set=A deliverables=src/managent/main.zig acceptance=kill -9 $$-->
# test - signal kill acceptance
BUNDLEEOF

T1=$(create_and_claim "$BUNDLE1")
if [ -z "$T1" ]; then red "Could not create test task"; rm -f "$BUNDLE1"; exit 1; fi

if "$MANAGENT" done "$T1" --status pass --agent DSPro 2>&1; then
    red "managent done accepted a signal-killed acceptance command (should have REJECTED)"
else
    green "managent done correctly REJECTED signal-killed acceptance command"
fi
rm -f "$BUNDLE1"

# ── Test 2: deliverables= must stop at next key= ──
echo ""
echo "--- Defect 2: deliverables= swallows key= tokens ---"

BUNDLE2="$PROJECT_DIR/untracked/T227-regtest-deliverables-bundle.md"
cat > "$BUNDLE2" << 'BUNDLEEOF'
<!--managent set=A deliverables=src/managent/main.zig acceptance=echo ok-->
# test - deliverables parsing
BUNDLEEOF

T2=$(create_and_claim "$BUNDLE2")
if [ -z "$T2" ]; then red "Could not create test task"; rm -f "$BUNDLE2"; exit 1; fi

if "$MANAGENT" done "$T2" --status pass --agent DSPro 2>&1; then
    green "deliverables= correctly isolated from acceptance= key"
else
    red "deliverables= may have swallowed acceptance= (done rejected)"
fi
rm -f "$BUNDLE2"

# ── Test 3: --skip-acceptance requires non-empty reason ──
echo ""
echo "--- Defect 3: empty --skip-acceptance reason ---"

BUNDLE3="$PROJECT_DIR/untracked/T227-regtest-skipempty-bundle.md"
cat > "$BUNDLE3" << 'BUNDLEEOF'
<!--managent set=A deliverables=src/managent/main.zig acceptance=echo ok-->
# test - empty skip reason
BUNDLEEOF

T3=$(create_and_claim "$BUNDLE3")
if [ -z "$T3" ]; then red "Could not create test task"; rm -f "$BUNDLE3"; exit 1; fi

if "$MANAGENT" done "$T3" --status pass --agent DSPro --skip-acceptance "" 2>&1; then
    red "managent done accepted empty --skip-acceptance reason (should have REJECTED)"
else
    green "managent done correctly REJECTED empty --skip-acceptance reason"
fi
rm -f "$BUNDLE3"

# ── Summary ──
echo ""
echo "=== T227 regression: $FAILURES failures ==="
if [ "$FAILURES" -gt 0 ]; then
    exit 1
fi
exit 0
