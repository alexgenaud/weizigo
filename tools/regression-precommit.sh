#!/bin/sh
# regression-precommit.sh — controls for the pre-commit hook (T272).
#
# Two controls, both run from the repo root:
#   null control:   the hook MUST pass on the current tree
#   seeded-defect:  adding one synthetic orphan MUST increase C1a
#
# Neither touches any tracked file. Both operate on copies in /tmp.
#
# Task: T272 · Role: worker · Model: deepseek-v4-pro · Date: 2026-08-02

set -e

HOOK="tools/hooks/pre-commit"
CLAIMLINT="bin/weizigo-claimlint"

cd "$(git rev-parse --show-toplevel)"

echo "=== regression-precommit: null control ==="
echo "Running pre-commit hook on current tree (must pass — floor is not exceeded)..."
if "$HOOK"; then
    echo "PASS: null control — hook allowed the commit (at or below floor)"
else
    echo "FAIL: null control — hook blocked a commit that should be allowed"
    exit 1
fi

echo ""
echo "=== regression-precommit: seeded-defect control ==="
if ! test -x "$CLAIMLINT"; then
    echo "SKIP: $CLAIMLINT not found — build with 'zig build && cp zig-out/bin/weizigo-claimlint bin/'"
    exit 0
fi

# Get the current C1a from the summary
CURRENT_C1A=$("$CLAIMLINT" 2>&1 | grep '^  C1a orphans / C1b alarms' | grep 'FAILS' | awk '{print $6}')
FLOOR_C1A=$(python3 -c "import json; print(json.load(open('tools/hooks/claimlint-floor.json'))['floor']['C1a'])")
echo "  current C1a=$CURRENT_C1A, floor C1a=$FLOOR_C1A"

# Create a temporary copy of CLAIMS.md with one extra orphan row.
# GLOBAL.CALORPHAN-REGRESS: PROVEN, depends on GLOBAL.C3 (FALSE-AS-SCOPED).
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

cp docs/epistemic/CLAIMS.md "$TMPDIR/CLAIMS.md"

# Insert a synthetic orphan row right after the first data row in §2.
# We find the line after the separator line (|---|...) and insert before the
# first real data row.
SYNTH_ROW='| `GLOBAL.CALORPHAN-REGRESS` | — | all | synthetic: seeded-defect control for pre-commit hook (T272). This row is PROVEN with d:GLOBAL.C3, which is FALSE-AS-SCOPED — so it creates one extra C1a orphan. | PROVEN | `AGENTS.md:1` | `d:GLOBAL.C3` | — | 0 | ? |'

python3 -c "
import sys
lines = open('$TMPDIR/CLAIMS.md').readlines()
in_sec2 = False
past_header = False
out = []
for line in lines:
    if line.startswith('## 2. The register'):
        in_sec2 = True
    elif in_sec2 and line.startswith('## 3.'):
        in_sec2 = False
    if in_sec2 and past_header and line.startswith('|') and not line.startswith('|---'):
        out.append('$SYNTH_ROW\n')
        past_header = False  # only insert once
    if in_sec2 and line.startswith('|---'):
        past_header = True
    out.append(line)
open('$TMPDIR/CLAIMS.md', 'w').writelines(out)
"

MOD_C1A=$("$CLAIMLINT" "$TMPDIR/CLAIMS.md" 2>&1 | grep '^  C1a orphans / C1b alarms' | grep 'FAILS' | awk '{print $6}')
echo "  modified-claims C1a=$MOD_C1A"

if [ -z "$MOD_C1A" ]; then
    echo "FAIL: seeded-defect control — could not parse C1a from modified claims"
    exit 1
fi

if [ "$MOD_C1A" -gt "$CURRENT_C1A" ]; then
    echo "PASS: seeded-defect control — C1a increased ($CURRENT_C1A → $MOD_C1A), adding an orphan is detected"
else
    echo "FAIL: seeded-defect control — C1a did not increase ($CURRENT_C1A → $MOD_C1A)"
    exit 1
fi

echo ""
echo "=== regression-precommit: all controls passed ==="
