#!/bin/bash
# smoke suite — fast build-verification tests (A4.3)
# Runs on every build via `acceptance=` or CI.
# Regression suite is `zig build test` (full, all modules).
set -euo pipefail
cd "$(dirname "$0")/.."

FAIL=0

echo "=== smoke ==="

# 1. Differential harness: null control + seeded-defect + known-bad (3 tests, <0.1s)
echo -n "  differential: "
if zig test src/differential.zig 2>/dev/null; then
    echo "PASS"
else
    echo "FAIL"
    FAIL=1
fi

# 2. Rules area_score + neighbors dispatchers (2 tests, fast)
echo -n "  rules dispatchers: "
if zig test src/rules.zig --test-filter "areaScore runtime\|neighborsRt runtime" 2>/dev/null; then
    echo "PASS"
else
    echo "FAIL"
    FAIL=1
fi

# 3. Area score differential run: 2x2 exhaustive (81 boards, <0.2s)
echo -n "  area_score 2x2: "
OUT=$(tools/runner -- zig run src/differential.zig 2>&1) || true
if echo "$OUT" | grep -q "81/81 agree"; then
    echo "PASS"
else
    echo "FAIL"
    FAIL=1
fi

echo ""
if [ $FAIL -eq 0 ]; then
    echo "smoke: PASS"
else
    echo "smoke: FAIL"
    exit 1
fi
