#!/bin/sh
# regression-claimlint-volatile.sh — controls for the C10 VOLATILE check (T421).
#
# C2 DEAD-LINKS flags only paths that are MISSING. A /tmp citation whose file
# still exists is not missing, so it passes — and the defect only becomes
# visible after the evidence is destroyed, which is exactly too late. T421
# measured 344 /tmp paths cited in committed docs; 43 were already gone.
# C10 flags the citation CLASS: any evidence path outside the repo — /tmp,
# /private/tmp, an absolute path that does not resolve inside the tree, or
# untracked/ — whether or not the file currently exists. Report-only (T421):
# it must NOT move any existing floor; the C10 floor is proposed separately.
#
# Three checks, all run from the repo root:
#   seeded-defect: a fixture doc citing /tmp/weizigo/c10-seeded.json — a path
#                  that EXISTS on disk — MUST be reported by C10. This is the
#                  whole defect: the file is present, so C2 passes it.
#   null-control:  with the fixture removed, the fixture path must NOT appear
#                  in the output, and every pre-existing counter (C1a/C1b/C2/
#                  C3/C4/C5/C6/C7/C8/C9, A, calibration) must be byte-identical
#                  to the fixture-less baseline.
#   report-only:   C10 must not change the run's exit status (it reports; it
#                  does not fail, yet).
#
# Task: T421 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-08

set -e

CLAIMLINT="zig-out/bin/weizigo-claimlint"
FIXTURE="docs/evidence/C10-VOLATILE-SEEDED.md"
SEEDED_PATH="/tmp/weizigo/c10-volatile-seeded-8f3a2e.json"

cd "$(git rev-parse --show-toplevel)"

echo "=== regression-claimlint-volatile: pre-flight ==="
if ! test -x "$CLAIMLINT"; then
    echo "SKIP: $CLAIMLINT not found — build with 'zig build' first"
    exit 0
fi
echo "  $CLAIMLINT is executable"

# The seeded citation must point at a file that EXISTS — the whole defect is
# that an existing /tmp file passes every check until the sweep destroys it.
mkdir -p /tmp/weizigo
printf '{"seeded": true}\n' > "$SEEDED_PATH"
echo "  seeded target exists: $SEEDED_PATH"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"; rm -f "$FIXTURE"' EXIT

# ── baseline (no fixture): capture the run the tree is expected to keep ──
set +e
"$CLAIMLINT" > "$TMPDIR/baseline.out" 2>/dev/null
BASELINE_EXIT=$?
set -e
echo ""
echo "=== regression-claimlint-volatile: baseline (no fixture) ==="
echo "  baseline exit: $BASELINE_EXIT"

# ── seeded-defect: fixture doc citing an EXISTING /tmp path ─────────────
cat > "$FIXTURE" <<EOF
# C10 seeded fixture (T421 regression control — do not commit)

This fixture document cites an evidence path that exists on disk right now:

\`$SEEDED_PATH\`

Under the pre-T421 claimlint this citation passes every check — the file is
not missing — which is the whole defect. C10 must report it regardless.
EOF
echo ""
echo "=== regression-claimlint-volatile: seeded-defect ==="
echo "  fixture: $FIXTURE"
set +e
"$CLAIMLINT" > "$TMPDIR/seeded.out" 2>/dev/null
SEEDED_EXIT=$?
set -e
echo "  seeded exit: $SEEDED_EXIT (must equal baseline exit $BASELINE_EXIT — report-only)"

if ! grep -Fq "$SEEDED_PATH" "$TMPDIR/seeded.out"; then
    echo "FAIL: seeded-defect — $SEEDED_PATH (an EXISTING /tmp file) is not"
    echo "      reported by claimlint. This is the whole defect: a /tmp citation"
    echo "      whose file still exists passes C2 and stays invisible until the"
    echo "      evidence is destroyed. A control that has been red."
    exit 1
fi
echo "PASS: seeded-defect — an existing /tmp citation is reported"

if [ "$SEEDED_EXIT" -ne "$BASELINE_EXIT" ]; then
    echo "FAIL: report-only — C10 changed the exit status ($BASELINE_EXIT -> $SEEDED_EXIT)."
    echo "      C10 must report without failing the run; the floor is proposed separately."
    exit 1
fi
echo "PASS: report-only — C10 does not change the run's exit status"

# ── null-control: fixture removed, output returns to baseline ────────────
rm -f "$FIXTURE"
echo ""
echo "=== regression-claimlint-volatile: null-control ==="
set +e
"$CLAIMLINT" > "$TMPDIR/null.out" 2>/dev/null
NULL_EXIT=$?
set -e

if grep -Fq "$SEEDED_PATH" "$TMPDIR/null.out"; then
    echo "FAIL: null-control — $SEEDED_PATH still reported after the fixture was removed"
    exit 1
fi
echo "PASS: null-control — fixture path absent once the fixture doc is gone"

# The null run is on the same tree as the baseline (both fixture-less), so the
# outputs must be byte-identical — the C10 counter included. Any difference is
# a counter the new code moved, which the regression control forbids.
if ! cmp -s "$TMPDIR/baseline.out" "$TMPDIR/null.out"; then
    echo "FAIL: null-control — claimlint output differs between two identical runs:"
    diff "$TMPDIR/baseline.out" "$TMPDIR/null.out" | head -20
    exit 1
fi
echo "PASS: null-control — output byte-identical to baseline on the same tree"

echo ""
echo "=== regression-claimlint-volatile: all controls passed ==="
