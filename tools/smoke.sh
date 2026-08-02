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

# 4. Deployed binaries: bin/ == zig-out/ (T268) ─────────────────────────
# Nothing used to verify that what we ship (bin/) is what we built
# (zig-out/). Every tool's smoke test runs the DEPLOYED copy and compares
# its version stamp with the build's — a stale bin/ now fails the suite.
# Run 'zig build deploy' (remove-copy-sign) to refresh bin/.
echo "  deployed == built:"

# Extract '<tool> <sha>[-dirty]' from a tool's version banner (stderr, any exit code).
# The tool name is part of the compared token: a wrong-tool binary with the
# same sha must also fail (negative control, T268).
stamp_of() {
    local bin="$1"; shift
    "$bin" "$@" 2>&1 | grep -oE '[a-z][a-z0-9-]* [0-9a-f]{7}(-dirty)? built' | head -1 | sed 's/ built$//' || true
}

deploy_check() {
    local tool="$1"; shift
    local built deployed
    built=$(stamp_of "zig-out/bin/$tool" "$@")
    deployed=$(stamp_of "bin/$tool" "$@")
    if [ -z "$built" ]; then
        echo "    FAIL: $tool: no version stamp in zig-out/bin/$tool"
        FAIL=1
    elif [ -z "$deployed" ]; then
        echo "    FAIL: $tool: bin/$tool missing or unstamped — run 'zig build deploy'"
        FAIL=1
    elif [ "$built" = "$deployed" ]; then
        echo "    PASS: $tool bin/$deployed == zig-out/$built"
    else
        echo "    FAIL: $tool: deployed bin/$deployed != built zig-out/$built — bin/ is stale"
        FAIL=1
    fi
}

# managent: --version prints the banner and exits 0.
deploy_check managent --version
# weizigo-absorb: no-arg run prints banner + usage (exit 1); banner is what we need.
deploy_check weizigo-absorb
# weizigo-claimlint: --version prints banner then scans the register (exit 0).
deploy_check weizigo-claimlint --version
# weizigo-gtp: --version prints banner (stderr) then fails to load the artifact.
deploy_check weizigo-gtp --version
# Research tools: --version prints banner (stderr) then errors on the bad
# artifact path; the banner is what we compare.
deploy_check weizigo-chainability --version
deploy_check weizigo-engine-vs-engine --version
deploy_check weizigo-reachcensus --version

# Functional: the DEPLOYED managent must parse the live kanban (read-only).
if bin/managent status --json 2>/dev/null | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; then
    echo "    PASS: bin/managent status parses the live kanban"
else
    echo "    FAIL: bin/managent status failed against the live kanban"
    FAIL=1
fi

echo ""
if [ $FAIL -eq 0 ]; then
    echo "smoke: PASS"
else
    echo "smoke: FAIL"
    exit 1
fi
