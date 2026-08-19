#!/bin/sh
# regression-claimlint-c7-json.sh — controls for the `c7 --json` verb (T482).
#
# Three checks, all run from the repo root:
#   c7-json-shape     the JSON output parses as a JSON array; every entry has
#                     the eight spec fields (path, task_id, conforming,
#                     conforming_reason, claims_total, new_rows_total,
#                     unabsorbed, dispositioned); unabsorbed + dispositioned
#                     are arrays
#   c7-json-counts    the per-file `unabsorbed`/`dispositioned` array lengths
#                     equal the aggregate unabsorbed/dispositioned counts in
#                     the human-readable C7 block (the spec §7 round-trip —
#                     one count, one implementation)
#   c7-nonconf-exits  a non-conforming file in findings/ makes `c7 --json`
#                     exit 1 by itself — the spec §6.1 promotion that
#                     prevented the T454 illusion (malformed file → 0
#                     unabsorbed, run said nothing was wrong). The fixture
#                     is added and removed in place; a SIGKILL trap wipes
#                     it on every exit (T448 pattern).
#
# Task: T482 · Role: worker · Model: minimax-m3 · Date: 2026-08-19

set -e

CLAIMLINT="zig-out/bin/weizigo-claimlint"
FIXTURE="findings/T482-NONCONFORM-FIXTURE.json"

cd "$(git rev-parse --show-toplevel)"

echo "=== regression-claimlint-c7-json: pre-flight ==="
if ! test -x "$CLAIMLINT"; then
    echo "SKIP: $CLAIMLINT not found — build with 'zig build' first"
    exit 0
fi
echo "  $CLAIMLINT is executable"

# T448: refuse to run if a previous run was killed mid-fixture. Same
# pattern as regression-claimlint-volatile.sh — a SIGKILLed run would
# leave the fixture behind and a subsequent run would see it as a real
# non-conforming file, false-positiving the c7-nonconf-exits arm.
if [ -f "$FIXTURE" ]; then
    echo "SKIP: $FIXTURE from a previous (killed) run is still present — refusing to run; rm -f $FIXTURE and re-run"
    exit 2
fi

# T448: trap wipes the fixture on every exit (INT/TERM/HUP/EXIT). The
# fixture is created inside the c7-nonconf-exits arm so the start-up
# check + the trap together make this SIGKILL-safe: any escape path
# either is caught by the start-up check (next run refuses) or wiped
# by the trap (clean exit).
trap 'rm -f "$FIXTURE" 2>/dev/null || true' INT TERM HUP EXIT

echo ""
echo "=== regression-claimlint-c7-json: c7-json-shape ==="
echo "Verify the JSON output parses, has the eight fields, and the array shapes match the spec..."

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"; rm -f "$FIXTURE" 2>/dev/null || true' INT TERM HUP EXIT

if ! "$CLAIMLINT" c7 --json 2>/dev/null > "$TMPDIR/c7-json.out"; then
    RC=$?
    echo "FAIL: c7 --json exited $RC on the live tree (expected 0)"
    exit 1
fi

python3 - "$TMPDIR/c7-json.out" <<'PYEOF'
import json, sys
path = sys.argv[1]
try:
    with open(path) as f:
        data = json.load(f)
except Exception as e:
    print(f"FAIL: c7-json-shape — JSON parse failed: {e}")
    sys.exit(1)

if not isinstance(data, list):
    print(f"FAIL: c7-json-shape — top-level is not a JSON array (got {type(data).__name__})")
    sys.exit(1)

required_keys = {"path", "task_id", "conforming", "conforming_reason",
                 "claims_total", "new_rows_total", "unabsorbed", "dispositioned"}
for i, entry in enumerate(data):
    if not isinstance(entry, dict):
        print(f"FAIL: c7-json-shape — entry {i} is not an object (got {type(entry).__name__})")
        sys.exit(1)
    missing = required_keys - set(entry.keys())
    if missing:
        print(f"FAIL: c7-json-shape — entry {i} missing required keys: {sorted(missing)}")
        sys.exit(1)
    if not isinstance(entry["unabsorbed"], list):
        print(f"FAIL: c7-json-shape — entry {i} unabsorbed is not an array")
        sys.exit(1)
    if not isinstance(entry["dispositioned"], list):
        print(f"FAIL: c7-json-shape — entry {i} dispositioned is not an array")
        sys.exit(1)
    if entry["conforming"]:
        if entry["conforming_reason"] is not None:
            print(f"FAIL: c7-json-shape — entry {i} conforming but conforming_reason is not null: {entry['conforming_reason']!r}")
            sys.exit(1)
    else:
        if not entry["conforming_reason"]:
            print(f"FAIL: c7-json-shape — entry {i} non-conforming but conforming_reason is empty")
            sys.exit(1)
print(f"PASS: c7-json-shape — {len(data)} entries, all 8 keys present, unabsorbed/dispositioned are arrays, conforming_reason invariant holds")
PYEOF

echo ""
echo "=== regression-claimlint-c7-json: c7-json-counts ==="
echo "Verify the per-file JSON counts aggregate to the human-readable counts..."

# Extract the aggregate counts from the human-readable c7 path.
"$CLAIMLINT" c7 2>/dev/null > "$TMPDIR/c7-human.out" || true
HR_UNABS=$(grep -E '^  unabsorbed:' "$TMPDIR/c7-human.out" | sed 's/.*: //' | head -1)
HR_DISP=$(grep -E '^  dispositioned:' "$TMPDIR/c7-human.out" | sed 's/.*: //' | head -1)
HR_NONCONF=$(grep -E '^  non-conforming:' "$TMPDIR/c7-human.out" | sed 's/.*: //' | sed 's/ .*//' | head -1)
echo "  human-readable: unabsorbed=$HR_UNABS dispositioned=$HR_DISP non-conforming=$HR_NONCONF"

# Sum the per-file counts from the JSON.
python3 - "$TMPDIR/c7-json.out" <<PYEOF
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
json_unabs = sum(len(e["unabsorbed"]) for e in data)
json_disp = sum(len(e["dispositioned"]) for e in data)
json_nonconf = sum(1 for e in data if not e["conforming"])
print(f"  json: unabsorbed={json_unabs} dispositioned={json_disp} non-conforming={json_nonconf}")
hr_unabs = int("$HR_UNABS")
hr_disp = int("$HR_DISP")
hr_nonconf = int("$HR_NONCONF")
fail = False
if json_unabs != hr_unabs:
    print(f"FAIL: c7-json-counts — unabsorbed disagrees: json={json_unabs} human={hr_unabs}")
    fail = True
if json_disp != hr_disp:
    print(f"FAIL: c7-json-counts — dispositioned disagrees: json={json_disp} human={hr_disp}")
    fail = True
if json_nonconf != hr_nonconf:
    print(f"FAIL: c7-json-counts — non-conforming disagrees: json={json_nonconf} human={hr_nonconf}")
    fail = True
if fail:
    sys.exit(1)
print(f"PASS: c7-json-counts — all three counts agree (unabsorbed, dispositioned, non-conforming)")
PYEOF

echo ""
echo "=== regression-claimlint-c7-json: c7-nonconf-exits ==="
echo "Verify a non-conforming file alone makes c7 --json exit 1 (spec §6.1)..."

echo '{"foo": 1}' > "$FIXTURE"
# Capture the binary's exit code in a variable BEFORE the if-test — `if`
# evaluates the command and `RC=$?` after `fi` returns 0 when the body
# is skipped (the binary's actual exit code is lost in the if-then-else
# structure). A wrapper function holds the exit code across the if.
binary_exit=0
"$CLAIMLINT" c7 --json 2>/dev/null > "$TMPDIR/c7-with-fixture.out" || binary_exit=$?
if [ "$binary_exit" -eq 0 ]; then
    echo "FAIL: c7-nonconf-exits — c7 --json exited 0 with a non-conforming file present"
    exit 1
fi
if [ "$binary_exit" -ne 1 ]; then
    echo "FAIL: c7-nonconf-exits — c7 --json exited $binary_exit, expected 1"
    exit 1
fi
# The fixture must appear in the output and report non-conforming with
# a reason — proves the file is the one being reported (not some other
# state).
python3 - "$TMPDIR/c7-with-fixture.out" "$FIXTURE" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
basename = sys.argv[2].split("/")[-1]
for entry in data:
    if entry["path"] == basename:
        if entry["conforming"]:
            print(f"FAIL: c7-nonconf-exits — fixture reported as conforming")
            sys.exit(1)
        if not entry["conforming_reason"]:
            print(f"FAIL: c7-nonconf-exits — fixture conforming_reason is empty")
            sys.exit(1)
        print(f"PASS: c7-nonconf-exits — fixture reported as non-conforming with reason (RC=1)")
        sys.exit(0)
print(f"FAIL: c7-nonconf-exits — fixture {basename} not in output")
sys.exit(1)
PYEOF

echo ""
echo "=== regression-claimlint-c7-json: all controls passed ==="
