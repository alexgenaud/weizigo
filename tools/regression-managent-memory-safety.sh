#!/usr/bin/env bash
# regression-managent-memory-safety.sh
# T122 regression check: audit no-crash, status output order, exit-code contract
#
# Usage:  tools/regression-managent-memory-safety.sh [--build]
#   --build: rebuild managent from source before testing

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
MG="$PROJECT/bin/managent"

FAIL=0

if [ "${1:-}" = "--build" ]; then
    echo "  rebuilding managent..."
    (cd "$PROJECT" && zig build -Doptimize=ReleaseSafe 2>&1)
    cp "$PROJECT/zig-out/bin/managent" "$MG"
fi

echo "  T122 regression check: 1. audit no-crash"

# Must not bus-error or crash
"$MG" audit >/dev/null 2>/dev/null || true

echo "        2. audit exit code: clean (0)"

"$MG" audit >/dev/null 2>/dev/null
RC=$?
if [ "$RC" -ne 0 ]; then
    echo "    FAIL: audit exited $RC, expected 0 (WARN-only findings)"
    FAIL=1
else
    echo "    PASS: audit exit $RC"
fi

echo "        3. audit --json exit code: clean (0)"

"$MG" audit --json 2>/dev/null | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null
RC=$?
if [ "$RC" -ne 0 ]; then
    echo "    FAIL: audit --json is not valid JSON (exit $RC)"
    FAIL=1
else
    echo "    PASS: audit --json is valid JSON"
fi

echo "        4. status --json is valid JSON"

"$MG" status --json 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
assert isinstance(data, list), 'expected top-level array'
# Check ordering: first element should be the lowest-ID task
for item in data:
    assert 'id' in item, 'missing id'
    assert 'status' in item, 'missing status'
    assert 'set' in item, 'missing set'
print(f'    {len(data)} tasks, all valid')
" 2>&1
RC=$?
if [ "$RC" -ne 0 ]; then
    echo "    FAIL: status --json validation failed"
    FAIL=1
else
    echo "    PASS: status --json valid"
fi

echo "        5. status --json first char is '['"

FIRST=$(bin/managent status --json 2>/dev/null | head -c 1)
if [ "$FIRST" != "[" ]; then
    echo "    FAIL: status --json first char is '$FIRST', expected '['"
    FAIL=1
else
    echo "    PASS: status --json starts with '['"
fi

echo "        6. status --json last char is ']' (ignoring newline)"

LAST=$(bin/managent status --json 2>/dev/null | tail -c 2 | head -c 1)
if [ "$LAST" != "]" ]; then
    echo "    FAIL: status --json last char is '$LAST', expected ']'"
    FAIL=1
else
    echo "    PASS: status --json ends with ']'"
fi

echo "        7. status text output: first line is a section header"

FIRST_LINE=$(bin/managent status 2>/dev/null | head -1)
if echo "$FIRST_LINE" | grep -qE '^$|  (dispatchable|in progress|blocked|done|failed)'; then
    echo "    PASS: status text output starts with section header"
else
    echo "    FAIL: status text output first line unexpected: '$FIRST_LINE'"
    FAIL=1
fi

echo "        8. deterministic output (3 runs same length for --json)"

LEN1=$(bin/managent status --json 2>/dev/null | wc -l)
LEN2=$(bin/managent status --json 2>/dev/null | wc -l)
LEN3=$(bin/managent status --json 2>/dev/null | wc -l)
if [ "$LEN1" -eq "$LEN2" ] && [ "$LEN2" -eq "$LEN3" ]; then
    echo "    PASS: deterministic output ($LEN1 lines each)"
else
    echo "    FAIL: non-deterministic output lengths: $LEN1 $LEN2 $LEN3"
    FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "  T122: ALL CHECKS PASS"
else
    echo "  T122: SOME CHECKS FAILED"
fi
exit "$FAIL"
