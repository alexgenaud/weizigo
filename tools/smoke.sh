#!/bin/bash
# smoke suite — fast build-verification tests (A4.3)
# Runs on every build via `acceptance=` or CI.
# Regression suite is `zig build test` (full, all modules).
set -euo pipefail
cd "$(dirname "$0")/.."

FAIL=0

echo "=== smoke ==="

# 1. Differential harness: null control + seeded-defect + known-bad (3 tests, ~1s)
# Filtered per STATE rule 7: unfiltered `zig test src/differential.zig` pulls the
# import graph and runs qa023_brute_2x2's explosive smoke test (T360 fail-fast aborts
# it, reddening this step for the wrong reason). The pass condition asserts the exact
# test count: zig exits 0 on a filter that matches nothing ("All 0 tests passed"),
# which made step 2 below a vacuous green until 2026-08-05.
printf '  differential: '
OUT=$(zig test src/differential.zig \
    --test-filter "null control: same impl twice" \
    --test-filter "seeded-defect control: mutant caught" \
    --test-filter "known-bad fixture" 2>&1) || true
if echo "$OUT" | grep -q "All 3 tests passed"; then
    echo "PASS"
else
    echo "FAIL"
    FAIL=1
fi

# 2. Rules area_score + neighbors dispatchers (2 tests, fast)
# --test-filter is a substring match, one flag per test; the old single-string
# `\|` alternation matched zero tests and passed vacuously. Count asserted.
printf '  rules dispatchers: '
OUT=$(zig test src/rules.zig --test-filter "areaScore runtime" --test-filter "neighborsRt runtime" 2>&1) || true
if echo "$OUT" | grep -q "All 2 tests passed"; then
    echo "PASS"
else
    echo "FAIL"
    FAIL=1
fi

# 3. Area score differential run: 2x2 exhaustive (81 boards, <0.2s)
printf '  area_score 2x2: '
OUT=$(tools/runner -- zig run src/differential.zig 2>&1) || true
if echo "$OUT" | grep -q "81/81 agree"; then
    echo "PASS"
else
    echo "FAIL"
    FAIL=1
fi

# 4. Deployed binaries: bin/ matches committed source (T268 + T289) ──────
# T268 built the check as bin/ == zig-out/; T289 found the hole that
# mattered: nothing RAN it. T286 deleted the read-first surface while its
# replacement lived only in zig-out/, and the project had no read-first
# surface at all until Orcha deployed by hand. This suite run is what makes
# the check run — wired into `zig build test` from build.zig.
#
# Ordering-trap ruling (T289): staleness is judged against COMMITTED source
# history, NOT against zig-out/ — a bin/ tool is stale iff committed changes
# since its embedded build commit touched its sources (the tool's src,
# tools/gen-version.sh, build.zig). Uncommitted edits never trip it (HEAD is
# unchanged), so a normal edit-test cycle does not break; the guard bites
# exactly when a cold reader could be misled (T286's shape: source change
# committed, deploy skipped). A missing/unstamped binary, or one whose build
# commit is not an ancestor of HEAD, is ALSO a failure — a guard that cannot
# prove currency is the same silence.
#
# T295 ruling (§5): a stale bin/ is NOT VERIFIED rather than BROKEN — the
# tools are known-stale but not known-wrong. A stale binary still prints a
# loud STALE line, but the suite exits 0. The property T289 established
# (genuinely stale → must still fail loudly) is preserved: every stale
# binary reports its staleness and the command to fix it. A missing binary,
# wrong-tool binary, or unverifiable provenance is still a FAIL.
# Run 'zig build deploy' (remove-copy-sign) to refresh bin/.
echo "  deployed vs committed source:"

# Extract '<tool> <sha>[-dirty]' from a tool's version banner (stderr, any exit code).
# The tool name is part of the compared token: a wrong-tool binary with the
# same sha must also fail (negative control, T268).
stamp_of() {
    local bin="$1"; shift
    "$bin" "$@" 2>&1 | grep -oE '[a-z][a-z0-9-]* [0-9a-f]{7,}(-dirty)? built' | head -1 | sed 's/ built$//' || true
}

HEAD_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "")

deploy_check() {
    local tool="$1"; shift
    local srcs="$1"; shift
    local deployed toolname built_sha touched
    deployed=$(stamp_of "bin/$tool" "$@")
    if [ -z "$deployed" ]; then
        echo "    FAIL: $tool: bin/$tool missing or unstamped — run 'zig build deploy'"
        FAIL=1
        return
    fi
    toolname=${deployed%% *}
    built_sha=${deployed##* }
    built_sha=${built_sha%-dirty}
    if [ "$toolname" != "$tool" ]; then
        echo "    FAIL: $tool: bin/$tool reports itself as '$toolname' — wrong-tool binary (negative control, T268)"
        FAIL=1
        return
    fi
    if [ -z "$HEAD_SHA" ]; then
        echo "    FAIL: $tool: cannot resolve git HEAD — cannot verify bin/$tool is current"
        FAIL=1
        return
    fi
    if ! git merge-base --is-ancestor "$built_sha" HEAD 2>/dev/null; then
        echo "    FAIL: $tool: bin/$tool built from $built_sha, which is not an ancestor of HEAD ($HEAD_SHA) — provenance unverifiable; run 'zig build deploy'"
        FAIL=1
        return
    fi
    touched=$(git log --oneline "$built_sha..HEAD" -- $srcs 2>/dev/null | head -1)
    if [ -n "$touched" ]; then
        # T295: staleness is NOT VERIFIED, not broken. Print a loud warning
        # but do not increment FAIL — a stale binary from a build.zig-only
        # change should not redden a suite where 380/380 tests pass.
        echo "    STALE: $tool: bin/$tool built from $built_sha; committed source changes since then (HEAD $HEAD_SHA) — run 'zig build deploy'"
    else
        echo "    PASS: $tool: bin/$tool current (built from $built_sha; no committed source change since)"
    fi
}

# Per-tool source scope: the tool's own sources + the version generator +
# build.zig (a build.zig change can alter any binary's build or deploy).
MANAGENT_SRC="src/managent/ tools/gen-version.sh build.zig"
# T527: absorb.zig and claims_register.zig compile INTO weizigo-claimlint
# since the T437 merge — a change to either must flag a stale deployed
# claimlint (the old CLAIMLINT_SRC missed them).
CLAIMLINT_SRC="src/claimlint.zig src/absorb.zig src/claims_register.zig tools/gen-version.sh build.zig"
GTP_SRC="src/gtp.zig tools/gen-version.sh build.zig"
CHAIN_SRC="src/chainability.zig tools/gen-version.sh build.zig"
EVSE_SRC="src/engine-vs-engine.zig tools/gen-version.sh build.zig"
REACH_SRC="src/reachcensus.zig tools/gen-version.sh build.zig"

# managent: --version prints the banner and exits 0.
deploy_check managent "$MANAGENT_SRC" --version
# weizigo-absorb: retired. T437 consolidated absorb into `weizigo-claimlint
# absorb`; T527 removed the compat alias entirely. The tool it delegated to
# IS still checked (weizigo-claimlint, below).
# weizigo-claimlint: --version prints banner then scans the register (exit 0).
deploy_check weizigo-claimlint "$CLAIMLINT_SRC" --version
# weizigo-gtp: --version prints banner (stderr) then fails to load the artifact.
deploy_check weizigo-gtp "$GTP_SRC" --version
# Research tools: --version prints banner (stderr) then errors on the bad
# artifact path; the banner is what we compare.
deploy_check weizigo-chainability "$CHAIN_SRC" --version
deploy_check weizigo-engine-vs-engine "$EVSE_SRC" --version
deploy_check weizigo-reachcensus "$REACH_SRC" --version

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
