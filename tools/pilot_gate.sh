#!/bin/sh
# Pilot gate (ADR-0012): every engine change must reproduce the recorded
# small-board artifacts BYTE-IDENTICALLY before any big-board run.
#
#   sh tools/pilot_gate.sh          # fast: 2x2 + 3x2 + 3x3 (~seconds)
#   sh tools/pilot_gate.sh --full   # also 4x4 (~20 min, checks recorded sha256)
#
# Exits non-zero on ANY divergence. Determinism is the foundation: same
# engine semantics => same bytes; a changed hash means changed semantics.
set -e
cd "$(dirname "$0")/.."

echo "pilot gate: rebuilding 2x2/3x2/3x3 artifacts..."
RETRO_SAVE=1 zig run -O ReleaseFast src/retro.zig >/dev/null 2>&1
shasum -a 256 -c artifacts/SHA256SUMS
git diff --exit-code -- artifacts/ >/dev/null || {
    echo "pilot gate: FAIL — regenerated artifacts differ from committed"; exit 1; }

if [ "$1" = "--full" ]; then
    echo "pilot gate: rebuilding 4x4 (this takes ~20 min)..."
    rm -f data/oracle-4x4.checkpoint.wzo
    mv data/oracle-4x4.wzo data/oracle-4x4.wzo.prev 2>/dev/null || true
    RETRO_4X4=1 zig run -O ReleaseFast src/retro.zig >/dev/null 2>&1
    WANT="b42c3371db9c800c6a76fc29b842e8be6f8b0af35731f5a88e2ba24b5551655f"
    GOT=$(shasum -a 256 data/oracle-4x4.wzo | cut -d' ' -f1)
    [ "$GOT" = "$WANT" ] || { echo "pilot gate: FAIL — 4x4 sha256 $GOT != $WANT"; exit 1; }
    echo "pilot gate: 4x4 sha256 OK"
fi

echo "pilot gate: PASS"
