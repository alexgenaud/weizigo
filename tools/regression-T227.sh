#!/bin/bash
# T227 regression tests — acceptance-check defect fixes
# A3: uses --store to isolate from the live kanban.
# Run: tools/regression-T227.sh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MANAGENT="$PROJECT_DIR/bin/managent"
FAILURES=0

red() { echo "  FAIL: $*"; FAILURES=$((FAILURES + 1)); }
green() { echo "  PASS: $*"; }

echo "=== T227 regression tests (isolated store) ==="
echo ""

# ── Byte-identity guard: the live kanban must not be mutated ──
LIVE_STORE="$PROJECT_DIR/docs/infra/managent/tasks.json"
LIVE_HASH=$(shasum -a 256 "$LIVE_STORE" | cut -d' ' -f1)

# ── Temporary isolated store ──
TEST_STORE=$(mktemp -t managent-regtest-XXXXXX.json)
# Initialise the test store as a minimal valid state
echo '{"_sys":{"next_id":900,"directive_next":1}}' > "$TEST_STORE"

# Each managent invocation uses MANAGENT_STORE to isolate
export MANAGENT_STORE="$TEST_STORE"
M="$MANAGENT"

# Helper: create a temp bundle file
make_bundle() {
    local slug="$1"
    local f="/tmp/managent-regtest-${slug}-$$.md"
    cat > "$f"
    echo "$f"
}

# Helper: create a test task from a pre-written bundle.
create_and_claim() {
    local bundle_path="$1"
    local id
    id=$($M add --auto --bundle "$bundle_path" --set A 2>&1 | grep -o 'T[0-9][0-9]*' | head -1)
    if [ -z "$id" ]; then
        echo "ERROR: could not create task from $bundle_path" >&2
        return 1
    fi
    $M claim "$id" >/dev/null 2>&1 || true
    echo "$id"
}

# ── Test 1: signal-killed acceptance command must be REJECTED ──
echo "--- Defect 1: signal-killed acceptance ---"

BUNDLE1=$(make_bundle "sigkill" << 'BUNDLEEOF'
<!--managent set=A deliverables=src/managent/main.zig acceptance=kill -9 $$-->
# test - signal kill acceptance
BUNDLEEOF
)

T1=$(create_and_claim "$BUNDLE1")
if [ -z "$T1" ]; then red "Could not create test task"; rm -f "$BUNDLE1" "$TEST_STORE"; exit 1; fi

if $M done "$T1" --status pass --agent DSPro 2>&1; then
    red "managent done accepted a signal-killed acceptance command (should have REJECTED)"
else
    green "managent done correctly REJECTED signal-killed acceptance command"
fi
rm -f "$BUNDLE1"

# ── Test 2: deliverables= must stop at next key= ──
echo ""
echo "--- Defect 2: deliverables= swallows key= tokens ---"

BUNDLE2=$(make_bundle "deliverables" << 'BUNDLEEOF'
<!--managent set=A deliverables=src/managent/main.zig acceptance=echo ok-->
# test - deliverables parsing
BUNDLEEOF
)

T2=$(create_and_claim "$BUNDLE2")
if [ -z "$T2" ]; then red "Could not create test task"; rm -f "$BUNDLE1" "$BUNDLE2" "$TEST_STORE"; exit 1; fi

if $M done "$T2" --status pass --agent DSPro 2>&1; then
    green "deliverables= correctly isolated from acceptance= key"
else
    red "deliverables= may have swallowed acceptance= (done rejected)"
fi
rm -f "$BUNDLE2"

# ── Test 3: --skip-acceptance requires non-empty reason ──
echo ""
echo "--- Defect 3: empty --skip-acceptance reason ---"

BUNDLE3=$(make_bundle "skipempty" << 'BUNDLEEOF'
<!--managent set=A deliverables=src/managent/main.zig acceptance=echo ok-->
# test - empty skip reason
BUNDLEEOF
)

T3=$(create_and_claim "$BUNDLE3")
if [ -z "$T3" ]; then red "Could not create test task"; rm -f "$BUNDLE1" "$BUNDLE2" "$BUNDLE3" "$TEST_STORE"; exit 1; fi

if $M done "$T3" --status pass --agent DSPro --skip-acceptance "" 2>&1; then
    red "managent done accepted empty --skip-acceptance reason (should have REJECTED)"
else
    green "managent done correctly REJECTED empty --skip-acceptance reason"
fi
rm -f "$BUNDLE3"

# ── Byte-identity assertion ──
echo ""
echo "--- Byte-identity guard ---"
LIVE_HASH_AFTER=$(shasum -a 256 "$LIVE_STORE" | cut -d' ' -f1)
if [ "$LIVE_HASH" = "$LIVE_HASH_AFTER" ]; then
    green "live kanban unchanged (byte-identical)"
else
    red "live kanban was MUTATED by regression test!"
fi

# Clean up
rm -f "$TEST_STORE"

# ── Summary ──
echo ""
echo "=== T227 regression: $FAILURES failures ==="
if [ "$FAILURES" -gt 0 ]; then
    exit 1
fi
exit 0
