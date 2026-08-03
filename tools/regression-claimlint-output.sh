#!/bin/sh
# regression-claimlint-output.sh — controls for the claimlint redirect fix (T307).
#
# T307 diagnosed: each util.out() call created a new File.Writer with pos=0.
# For regular files, positional pwritev wrote at offset 0 each time, overwriting
# previous data — resulting in a 491-byte fragment from the middle of the output.
# Pipes survived because positional writes fail with Unseekable, triggering
# a per-writer fallback to streaming mode.
#
# Three checks, all run from the repo root:
#   null-identity: pipe and file redirects produce byte-identical output
#   null-summary:  both contain the "== SUMMARY ==" block
#   seeded-defect: the recorded short fixture (491 bytes from the old buggy
#                  binary) must differ from the real output AND must NOT
#                  contain "== SUMMARY ==" — proving the control catches
#                  the defect when it is present.
#
# Task: T307 · Role: worker · Model: deepseek-v4-pro · Date: 2026-08-03

set -e

CLAIMLINT="zig-out/bin/weizigo-claimlint"
SHORT_FIXTURE="tools/claimlint-redirect-short.fixture"

cd "$(git rev-parse --show-toplevel)"

echo "=== regression-claimlint-output: pre-flight ==="
if ! test -x "$CLAIMLINT"; then
    echo "SKIP: $CLAIMLINT not found — build with 'zig build' first"
    exit 0
fi
echo "  $CLAIMLINT is executable"

if ! test -f "$SHORT_FIXTURE"; then
    echo "SKIP: $SHORT_FIXTURE not found (seeded-defect fixture)"
    exit 1
fi
echo "  $SHORT_FIXTURE present ($(wc -c < "$SHORT_FIXTURE") bytes)"

echo ""
echo "=== regression-claimlint-output: null-identity ==="
echo "Verify pipe and file redirect produce byte-identical output..."

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Run via direct file redirect (stdout is a regular file)
"$CLAIMLINT" > "$TMPDIR/file_out" 2>/dev/null || true

# Run via pipe (stdout is a pipe to cat, which writes to a file)
"$CLAIMLINT" 2>/dev/null | cat > "$TMPDIR/pipe_out" || true

PIPE_SIZE=$(wc -c < "$TMPDIR/pipe_out")
FILE_SIZE=$(wc -c < "$TMPDIR/file_out")

if [ "$PIPE_SIZE" -ne "$FILE_SIZE" ]; then
    echo "FAIL: sizes differ — pipe=$PIPE_SIZE file=$FILE_SIZE"
    exit 1
fi
echo "  sizes match: $PIPE_SIZE bytes"

if ! cmp -s "$TMPDIR/pipe_out" "$TMPDIR/file_out"; then
    echo "FAIL: content differs between pipe and file redirect"
    echo "  first difference:"
    cmp -l "$TMPDIR/pipe_out" "$TMPDIR/file_out" | head -5
    exit 1
fi
echo "PASS: null-identity — pipe and file redirect are byte-identical"

echo ""
echo "=== regression-claimlint-output: null-summary ==="
echo "Verify both outputs contain the '== SUMMARY ==' block..."

for label in pipe file; do
    F="$TMPDIR/${label}_out"
    if ! grep -q '^== SUMMARY ==' "$F"; then
        echo "FAIL: '== SUMMARY ==' block absent from $label output"
        exit 1
    fi
    # Verify the key counts consumers need are present
    for key in "C1a orphans" "C2 dangling" "C6 cite-tag" "calibration"; do
        if ! grep -q "$key" "$F"; then
            echo "FAIL: '$key' count absent from $label output"
            exit 1
        fi
    done
done
echo "PASS: null-summary — both outputs contain the SUMMARY block and key counts"

echo ""
echo "=== regression-claimlint-output: seeded-defect ==="
echo "Verify the recorded short fixture is caught as a defect..."

# The fixture is 491 bytes from the old buggy binary. To prove the control
# catches the defect, we verify:
# 1. The fixture is much smaller than real output (491 vs ~31KB)
# 2. The fixture does NOT contain "== SUMMARY ==" (the consumer-facing symptom)
# 3. The fixture does NOT start with the banner (starts mid-output)
# 4. The real output passes all checks

FIXTURE_SIZE=$(wc -c < "$SHORT_FIXTURE")
echo "  fixture size: $FIXTURE_SIZE bytes"
echo "  real output size: $PIPE_SIZE bytes"

if [ "$FIXTURE_SIZE" -eq "$PIPE_SIZE" ]; then
    echo "FAIL: seeded-defect — fixture size equals real output size (bug not caught)"
    exit 1
fi

if cmp -s "$SHORT_FIXTURE" "$TMPDIR/pipe_out"; then
    echo "FAIL: seeded-defect — fixture is identical to real output (bug not caught)"
    exit 1
fi

if grep -q '^== SUMMARY ==' "$SHORT_FIXTURE"; then
    echo "FAIL: seeded-defect — fixture contains SUMMARY (the truncation symptom is absent)"
    exit 1
fi

if [ "$FIXTURE_SIZE" -gt "$PIPE_SIZE" ]; then
    echo "FAIL: seeded-defect — fixture is larger than real output (unexpected)"
    exit 1
fi

# Positive proof: the fixture starts with a fragment from the middle
# (the old bug produced output starting with "  calibration" not
# "weizigo-claimlint — ")
if head -1 "$SHORT_FIXTURE" | grep -q '^weizigo-claimlint'; then
    echo "FAIL: seeded-defect — fixture starts with the banner (not the truncation symptom)"
    exit 1
fi

echo "PASS: seeded-defect — fixture ($FIXTURE_SIZE bytes, no SUMMARY) is correctly"
echo "      detected as the truncation defect; real output ($PIPE_SIZE bytes, with"
echo "      SUMMARY) passes all checks. A control that has been red."
echo ""
echo "=== regression-claimlint-output: all controls passed ==="
