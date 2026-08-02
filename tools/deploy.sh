#!/bin/sh
# deploy.sh — remove-copy-sign deploy of a built binary into its runtime seat.
#
# T268 (2026-08-02): a bare `cp` over a LIVE signed binary on Apple Silicon
# invalidates the cached code signature and the kernel SIGKILLs the process
# (exit=137, no message — just silence). The repair is:
#
#     rm -f <dst> && cp <src> <dst> && codesign -s - <dst>
#
# rm first so the kernel never sees an overwritten-but-cached-signature file;
# ad-hoc re-sign after so the new bytes carry a fresh, valid signature.
# codesign is macOS-only; on other hosts the guard skips it (nothing to break).
#
# Single implementation shared by build.zig deploy steps and the regression
# scripts, so the recipe cannot drift between call sites.
#
# Usage: tools/deploy.sh <src> <dst>

set -e

if [ "$#" -ne 2 ]; then
    echo "usage: tools/deploy.sh <src> <dst>" >&2
    exit 2
fi

src="$1"
dst="$2"

rm -f "$dst"
cp "$src" "$dst"
if command -v codesign >/dev/null 2>&1; then
    codesign -s - "$dst"
fi
