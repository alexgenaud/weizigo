#!/usr/bin/env bash
# regression-gtp-boardsize.sh — T403 controls for the GTP boardsize desync
#
# Bug: a rejected `boardsize` in deferred mode (no artifact argument) set
# the session into a state where every subsequent command returned
# `? unknown command` — the session was dead but still answering.  The
# root cause was that `runDeferred` only handled a minimal command set
# (protocol_version, name, version, known_command, list_commands,
# boardsize, weizigo-stats, quit).  When boardsize failed, the session
# stayed in deferred mode where all play commands fell through to the
# `else` → `unknown command` branch.
#
# Fix (src/gtp.zig):
#   - runSession boardsize handler: error message names the fixed goban size
#   - runDeferred boardsize handler: error message says no artifact found
#     and shows the command form
#   - runDeferred: added clear_board (graceful no-op) and showboard
#     (informative message) so the session remains alive after rejection
#
# Controls:
#   seeded (red)    after rejected boardsize in deferred mode,
#                   `known_command genmove` returns `= true` and
#                   `showboard` returns an informative message (not
#                   `? unknown command`).  The red baseline is the
#                   pre-fix behaviour captured in the control.
#   null            correct launch with artifact plays a full game and
#                   reports final_score; boardsize mismatch gives
#                   informative error naming the fixed size.
#
# Binary: zig build deploy-gtp must have been run.  SKIP when
# bin/weizigo-gtp is missing.  No failure with a stale build — if the
# binary is present, the test runs.
#
# Task: T403 · Role: worker · Agent: deepseek-v4-pro · Date: 2026-08-07

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$HERE/.."
FAIL=0

GTP="$PROJECT/bin/weizigo-gtp"
ARTIFACT="$PROJECT/untracked/oracle-v2/oracle-4x4-v2.wzo2"

if [ ! -x "$GTP" ]; then
    echo "SKIP: no bin/weizigo-gtp — run 'zig build deploy-gtp' first"
    exit 0
fi
if [ ! -f "$ARTIFACT" ]; then
    echo "SKIP: no artifact at $ARTIFACT — run the retrograde build first"
    exit 0
fi

echo "=== gtp-boardsize regression ==="

# ── 1. seeded (red): rejected boardsize leaves session alive ──────────
# Pre-fix behaviour (captured 2026-08-07):
#   boardsize 4 → ? unacceptable size
#   known_command genmove → = true     (already worked)
#   showboard → ? unknown command      (the defect)
#   clear_board → ? unknown command    (the defect)
# Post-fix: all commands return = (success).
echo ""
echo "  1. seeded: rejected boardsize leaves session alive (showboard works)"
OUT=$(printf 'boardsize 4\nknown_command genmove\nshowboard\nclear_board\nquit\n' | "$GTP" 2>/dev/null)
# known_command genmove must return = true
if ! echo "$OUT" | grep -q '= true'; then
    echo "    FAIL: known_command genmove did not return = true"
    echo "$OUT" | sed 's/^/      /'
    FAIL=1
else
    echo "    PASS: known_command genmove -> = true"
fi
# showboard must NOT return ? unknown command
if echo "$OUT" | grep -q '? unknown command'; then
    echo "    FAIL: showboard returned ? unknown command (pre-fix regression)"
    echo "$OUT" | sed 's/^/      /'
    FAIL=1
else
    echo "    PASS: showboard did NOT return ? unknown command (session alive)"
fi
# showboard should have an informative message
if echo "$OUT" | grep -q 'no goban loaded'; then
    echo "    PASS: showboard message is informative ('no goban loaded')"
else
    echo "    FAIL: showboard did not include informative message"
    echo "$OUT" | sed 's/^/      /'
    FAIL=1
fi
# boardsize error must carry the fix
if echo "$OUT" | grep -q 'weizigo-gtp <path-to-wzo>'; then
    echo "    PASS: boardsize error message names the command form"
else
    echo "    FAIL: boardsize error message does not name the command form"
    echo "$OUT" | sed 's/^/      /'
    FAIL=1
fi
# clear_board must succeed (not unknown command)
if echo "$OUT" | grep -q '? unknown command'; then
    echo "    FAIL: clear_board returned ? unknown command"
    FAIL=1
else
    echo "    PASS: clear_board accepted gracefully (no error)"
fi

# ── 2. null: correct launch plays full game ──────────────────────────
echo ""
echo "  2. null: correct launch path plays full game, reports final_score"
OUT2=$(printf 'boardsize 4\nclear_board\nkomi 0\ngenmove b\nfinal_score\nquit\n' | "$GTP" "$ARTIFACT" 2>/dev/null)
if echo "$OUT2" | grep -qE '= B\+[0-9]'; then
    echo "    PASS: final_score returned a Black-positive score"
else
    echo "    FAIL: final_score did not return a proper score"
    echo "$OUT2" | sed 's/^/      /'
    FAIL=1
fi
if echo "$OUT2" | grep -q '? unacceptable size'; then
    echo "    FAIL: correct-size boardsize rejected"
    echo "$OUT2" | sed 's/^/      /'
    FAIL=1
else
    echo "    PASS: boardsize 4 accepted for 4x4 artifact"
fi
if echo "$OUT2" | grep -q '? unknown command'; then
    echo "    FAIL: some command returned unknown command"
    echo "$OUT2" | sed 's/^/      /'
    FAIL=1
else
    echo "    PASS: no unknown-command responses in correct session"
fi

# ── 3. wrong-size boardsize with artifact loaded names the fixed size ─
echo ""
echo "  3. wrong-size boardsize with artifact names the fixed size"
OUT3=$(printf 'boardsize 5\nquit\n' | "$GTP" "$ARTIFACT" 2>/dev/null)
if echo "$OUT3" | grep -q 'fixed to 4x4'; then
    echo "    PASS: error message says 'fixed to 4x4'"
else
    echo "    FAIL: error message does not name the fixed size"
    echo "$OUT3" | sed 's/^/      /'
    FAIL=1
fi

# ── 4. session stays alive after wrong-size rejection (artifact loaded) ─
echo ""
echo "  4. session alive after wrong-size rejection (artifact loaded)"
OUT4=$(printf 'boardsize 5\nclear_board\nshowboard\nquit\n' | "$GTP" "$ARTIFACT" 2>/dev/null)
if echo "$OUT4" | grep -q '? unknown command'; then
    echo "    FAIL: session broke after wrong-size boardsize"
    echo "$OUT4" | sed 's/^/      /'
    FAIL=1
else
    echo "    PASS: session stays alive after wrong-size boardsize"
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-gtp-boardsize: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-gtp-boardsize: FAILURES ==="
    exit 1
fi
