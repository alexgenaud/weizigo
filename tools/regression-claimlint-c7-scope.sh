#!/bin/sh
# regression-claimlint-c7-scope.sh — controls for `c7 --findings-scope-file`
# (T710): the committing-path scope the pre-commit C7-nonconforming floor
# leans on.
#
# KD-12 (T696 new_rows[3]): a sibling lane's malformed findings file tripped
# the shared C7 floor and blocked the whole fleet during a race. The fix
# scopes the C7 scan to the committing path — the hook writes the staged
# findings paths to a scope file and asks `c7 --findings-scope-file` for the
# count. These arms prove the claimlint half end-to-end with the REAL binary
# and the REAL register, without depending on the live tree being clean:
# every arm names its own scope, so unrelated in-progress findings files are
# excluded by construction.
#
# Four arms, all run from the repo root (the binary reads findings/ and
# docs/epistemic/CLAIMS.md relative to cwd):
#   scope-empty    an EMPTY scope file scans nothing — non-conforming 0,
#                  exit 0, even when the live tree carries a non-conforming
#                  file (the empty scope is the "no findings staged" case)
#   scope-good     a scope naming a conforming findings file reports 0 and
#                  exits 0
#   scope-bad      a scope naming a malformed findings file reports 1 and
#                  exits 1 (the floor must be able to see the slip)
#   scope-json     `--json` + `--findings-scope-file` combine: exactly one
#                  per-file entry, conforming true
#
# The two fixtures are added and removed in place; a SIGKILL trap (T448
# pattern) wipes them on every exit.
#
# Task: T710 · Role: worker · Model: deepseek-v4-pro · Date: 2026-08-23

set -e

CLAIMLINT="zig-out/bin/weizigo-claimlint"
GOOD="findings/T710-SCOPE-GOOD.json"
BAD="findings/T710-SCOPE-BAD.json"

cd "$(git rev-parse --show-toplevel)"

echo "=== regression-claimlint-c7-scope: pre-flight ==="
if ! test -x "$CLAIMLINT"; then
    echo "SKIP: $CLAIMLINT not found — build with 'zig build' first"
    exit 0
fi
echo "  $CLAIMLINT is executable"

# T448: refuse to run if a previous run was killed mid-fixture.
if [ -f "$GOOD" ] || [ -f "$BAD" ]; then
    echo "SKIP: a previous (killed) run left $GOOD or $BAD behind — refusing to run; rm -f them and re-run"
    exit 2
fi

TMPDIR=$(mktemp -d)
trap 'rm -f "$GOOD" "$BAD" 2>/dev/null || true; rm -rf "$TMPDIR"' INT TERM HUP EXIT

# The two fixtures: one conforming, one malformed (missing the required
# `claims` key). `c7` reads them from the working tree's findings/ dir, not
# from git, so untracked fixtures are fine (the T482 pattern).
printf '{"task_id": "T710-SCOPE-GOOD", "date": "2026-08-23", "model": "test", "claims": []}\n' > "$GOOD"
printf '{"foo": 1}\n' > "$BAD"

nonconf_of() {  # $1 = scope file path; prints the non-conforming count
    "$CLAIMLINT" c7 --findings-scope-file "$1" 2>/dev/null | grep '^  non-conforming:' | sed 's/.*non-conforming: *//' | awk '{print $1}'
}

echo ""
echo "=== regression-claimlint-c7-scope: scope-empty ==="
printf '' > "$TMPDIR/scope-empty.txt"
N=$(nonconf_of "$TMPDIR/scope-empty.txt")
"$CLAIMLINT" c7 --findings-scope-file "$TMPDIR/scope-empty.txt" >/dev/null 2>&1 && RC=0 || RC=$?
if [ "$N" = "0" ] && [ "$RC" -eq 0 ]; then
    echo "    PASS: empty scope scans nothing — non-conforming=0, exit 0 (live tree's other files excluded)"
else
    echo "    FAIL: N=$N RC=$RC"
    exit 1
fi

echo ""
echo "=== regression-claimlint-c7-scope: scope-good ==="
printf 'findings/T710-SCOPE-GOOD.json\n' > "$TMPDIR/scope-good.txt"
N=$(nonconf_of "$TMPDIR/scope-good.txt")
"$CLAIMLINT" c7 --findings-scope-file "$TMPDIR/scope-good.txt" >/dev/null 2>&1 && RC=0 || RC=$?
if [ "$N" = "0" ] && [ "$RC" -eq 0 ]; then
    echo "    PASS: conforming file in scope reports non-conforming=0, exit 0"
else
    echo "    FAIL: N=$N RC=$RC"
    exit 1
fi

echo ""
echo "=== regression-claimlint-c7-scope: scope-bad ==="
printf 'findings/T710-SCOPE-BAD.json\n' > "$TMPDIR/scope-bad.txt"
N=$(nonconf_of "$TMPDIR/scope-bad.txt")
"$CLAIMLINT" c7 --findings-scope-file "$TMPDIR/scope-bad.txt" >/dev/null 2>&1 && RC=0 || RC=$?
if [ "$N" = "1" ] && [ "$RC" -eq 1 ]; then
    echo "    PASS: malformed file in scope reports non-conforming=1, exit 1 (the floor can see the slip)"
else
    echo "    FAIL: N=$N RC=$RC"
    exit 1
fi

echo ""
echo "=== regression-claimlint-c7-scope: scope-json ==="
printf 'findings/T710-SCOPE-GOOD.json\n' > "$TMPDIR/scope-json.txt"
"$CLAIMLINT" c7 --json --findings-scope-file "$TMPDIR/scope-json.txt" 2>/dev/null > "$TMPDIR/scope-json.out" || true
python3 - "$TMPDIR/scope-json.out" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
if not isinstance(data, list) or len(data) != 1:
    print(f"FAIL: scope-json — expected exactly one entry, got {len(data) if isinstance(data, list) else 'non-list'}")
    sys.exit(1)
e = data[0]
if e["path"] != "T710-SCOPE-GOOD.json":
    print(f"FAIL: scope-json — path is {e['path']!r}, expected the scoped file")
    sys.exit(1)
if not e["conforming"]:
    print(f"FAIL: scope-json — conforming fixture reported non-conforming: {e['conforming_reason']!r}")
    sys.exit(1)
print(f"PASS: scope-json — one per-file entry, the scoped file, conforming")
PYEOF

echo ""
echo "=== regression-claimlint-c7-scope: all controls passed ==="
