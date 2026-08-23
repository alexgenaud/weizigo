#!/usr/bin/env bash
# regression-managent-build-mode.sh
# T702 regression test: `bin/managent` must not be a Debug build.
#
# Root cause (T702, 2026-08-23): build.zig used
# `b.standardOptimizeOption(.{})` with no preferred release mode, so a bare
# `zig build` (and `zig build deploy`) produced Debug binaries. The deployed
# bin/managent (2026-08-22, 4,938,144 bytes) was a Debug build — ~4.5x the
# prior ReleaseFast root binary (1.1 MB). Debug's unoptimized __text is
# 3,348,804 bytes vs 1,107,408 in ReleaseSafe (measured by T702, arm64).
#
# The fix pins the default: `b.option(..., "optimize", ...) orelse .ReleaseSafe`
# — a bare build is now ReleaseSafe (asserts stay live, the correctness
# convention; AGENTS.md "Correctness runs use ReleaseSafe — asserts are no-ops
# in ReleaseFast"), never Debug. A caller can still override with
# -Doptimize=Debug/Fast/Small. (b.standardOptimizeOption's
# .preferred_optimize_mode field is NOT enough — in Zig 0.16 it only selects the
# mode for the legacy -Drelease flag; a bare build still returns .Debug.)
#
# Arms:
#   1. pin guard (static): build.zig's `const optimize = ...` falls back to
#      .ReleaseSafe (the decision this row made). A future edit that drops the
#      fallback — or switches it to Debug — fails.
#   2. artifact guard (behavioral): the deployed bin/managent is not a Debug
#      build. Debug is ~4.9 MB; ReleaseSafe ~1.5 MB, ReleaseFast ~1.66 MB,
#      ReleaseSmall ~0.64 MB. Threshold 3,000,000 bytes separates every
#      release mode from Debug with >2x margin. SKIPs loudly when no
#      bin/managent exists (fresh clone before deploy).
#
# Usage:  tools/regression-managent-build-mode.sh [--build]
#   --build: rebuild managent at ReleaseSafe + redeploy to bin/ first.
#
# Must be RED before the build.zig pin lands (arm 1: no preferred mode; arm 2:
# deployed binary is Debug), GREEN after the pin + redeploy.

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
MG="$PROJECT/bin/managent"
BUILDZIG="$PROJECT/build.zig"

# Debug is ~4.9 MB; ReleaseSafe ~1.5 MB, ReleaseFast ~1.66 MB, ReleaseSmall
# ~0.64 MB (T702 measurements, arm64). Every release mode is under 1.7 MB,
# so 3 MB is a >2x margin both ways.
DEBUG_SIZE_THRESHOLD=3000000

FAIL=0

if [ "${1:-}" = "--build" ]; then
    echo "  rebuilding managent (ReleaseSafe) + redeploying..."
    # --no-prepend-zig: keep ReleaseSafe (correctness convention); the runner
    # would otherwise auto-add -Doptimize=ReleaseFast and duplicate the flag.
    (cd "$PROJECT" && "$PROJECT/tools/runner" --no-prepend-zig -- zig build -Doptimize=ReleaseSafe 2>&1)
    "$PROJECT/tools/deploy.sh" "$PROJECT/zig-out/bin/managent" "$MG"
fi

echo ""
echo "  T702 regression: managent build mode (no Debug in bin/)"

# ── Arm 1: build.zig pins the default optimize mode to ReleaseSafe ───────────
echo "        1. build.zig optimize default falls back to .ReleaseSafe"
if [ ! -f "$BUILDZIG" ]; then
    echo "           FAIL: build.zig missing"
    FAIL=1
elif grep -qE 'const optimize = .*orelse[[:space:]]*\.ReleaseSafe' "$BUILDZIG"; then
    echo "           PASS: build.zig pins ReleaseSafe as the bare-build default"
else
    echo "           FAIL: build.zig does not default to .ReleaseSafe"
    echo "                 (bare 'zig build' would default to Debug — the T702 defect)"
    FAIL=1
fi

# ── Arm 2: the deployed binary is not a Debug build ──────────────────────────
echo "        2. deployed bin/managent is not a Debug build (< ${DEBUG_SIZE_THRESHOLD} bytes)"
if [ ! -x "$MG" ]; then
    echo "           SKIP: no bin/managent (deploy with 'zig build deploy' before this arm can run)"
else
    SIZE="$(wc -c < "$MG" | tr -d ' ')"
    if [ "$SIZE" -lt "$DEBUG_SIZE_THRESHOLD" ]; then
        echo "           PASS: bin/managent is $SIZE bytes (release mode; Debug is ~4.9 MB)"
    else
        echo "           FAIL: bin/managent is $SIZE bytes — a Debug build (release modes are < 1.7 MB)"
        echo "                 run 'tools/regression-managent-build-mode.sh --build' to rebuild ReleaseSafe"
        FAIL=1
    fi
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "  T702: ALL CHECKS PASS"
else
    echo "  T702: SOME CHECKS FAILED"
fi
exit "$FAIL"
