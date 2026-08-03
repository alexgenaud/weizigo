#!/bin/sh
# regression-precommit.sh — controls for the pre-commit hook (T272/T280).
#
# Three checks, all run from the repo root:
#   installed-ness:  core.hooksPath MUST be set to tools/hooks
#   null control:    the hook MUST pass on the current tree
#   seeded-defect:   the hook MUST refuse a commit with a seeded orphan
#
# Neither touches any tracked file. The seeded-defect control operates
# on a copy in /tmp.
#
# Task: T280 · Role: worker · Model: deepseek-v4-pro · Date: 2026-08-02
# Based on T272's original; rewritten to exercise the hook (not claimlint
# directly) for the seeded-defect control per GRAND-AUDIT §1a.

set -e

HOOK="tools/hooks/pre-commit"
CLAIMLINT="bin/weizigo-claimlint"

cd "$(git rev-parse --show-toplevel)"

echo "=== regression-precommit: installed-ness check ==="
# GRAND-AUDIT §1c (2026-08-02): a mechanism nobody installed is prose.
# The next clone must fail loudly until someone runs the install command.
INSTALLED=$(git config core.hooksPath 2>/dev/null || echo "")
if [ "$INSTALLED" != "tools/hooks" ]; then
    echo "FAIL: core.hooksPath is not set to 'tools/hooks' (current: '${INSTALLED:-unset}')"
    echo "  Install with: git config core.hooksPath tools/hooks"
    exit 1
fi
echo "  core.hooksPath = $INSTALLED — installed"

echo ""
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

# Measure the baseline C1a so we can report the real delta.
BASELINE_C1A=$("$CLAIMLINT" 2>&1 | grep '^  C1a orphans / C1b alarms' | grep 'FAILS' | awk '{print $6}')
echo "  baseline C1a=$BASELINE_C1A"

# Build a seeded CLAIMS.md with one extra PROVEN row depending on
# GLOBAL.C3 (FALSE-AS-SCOPED). Exactly one new orphan is created (the
# seeded row itself; the cascade that T272's version produced was an
# insertion-loop bug — the single-use flag now prevents it).
#
# Unlike T272's version, this control exercises the hook itself, not just
# claimlint — a positive control must exercise the instrument under test,
# not a parallel one (AGENTS.md:146-148; GRAND-AUDIT §1a).
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

cp docs/epistemic/CLAIMS.md "$TMPDIR/CLAIMS.md"

# Seeded row: PROVEN, depends on GLOBAL.C3 (FALSE-AS-SCOPED). Exactly one
# orphan — the seeded row itself. Inserted once as the first data row in §2.
SYNTH_ROW='| `GLOBAL.T280-CTRL-SEEDED` | — | all | synthetic: seeded-defect control for pre-commit hook (T280). PROVEN with d:GLOBAL.C3 (FALSE-AS-SCOPED) — exactly one C1a orphan. | PROVEN | `AGENTS.md:1` | `d:GLOBAL.C3` | — | 0 | ? | Z-AUDIT |'

python3 -c "
import sys
lines = open('$TMPDIR/CLAIMS.md').readlines()
in_sec2 = False
past_header = False
inserted = False
out = []
for line in lines:
    if line.startswith('## 2. The register'):
        in_sec2 = True
    elif in_sec2 and line.startswith('## 3.'):
        in_sec2 = False
    if in_sec2 and past_header and not inserted and line.startswith('|') and not line.startswith('|---'):
        out.append('$SYNTH_ROW\n')
        inserted = True
    if in_sec2 and line.startswith('|---'):
        past_header = True
    out.append(line)
open('$TMPDIR/CLAIMS.md', 'w').writelines(out)
"

# Verify claimlint can parse the seeded register and confirm the orphan count.
SEEDED_C1A=$("$CLAIMLINT" "$TMPDIR/CLAIMS.md" 2>&1 | grep '^  C1a orphans / C1b alarms' | grep 'FAILS' | awk '{print $6}')
if [ -z "$SEEDED_C1A" ]; then
    echo "FAIL: seeded-defect control — could not parse C1a from seeded claims (claimlint may have rejected the format)"
    exit 1
fi
echo "  seeded C1a=$SEEDED_C1A (baseline=$BASELINE_C1A, delta=+$((SEEDED_C1A - BASELINE_C1A)))"

echo "Running pre-commit hook with CLAIMS_PATH pointing to the seeded register..."
# Run the hook with the seeded register. Exit 0 = hook PASSED = control FAILED.
if CLAIMS_PATH="$TMPDIR/CLAIMS.md" "$HOOK"; then
    echo "FAIL: seeded-defect control — hook allowed a commit with seeded orphan(s)"
    exit 1
else
    HOOK_EXIT=$?
    echo "PASS: seeded-defect control — hook blocked the commit (exit $HOOK_EXIT)"
fi

echo ""
echo "=== regression-precommit: all controls passed ==="
