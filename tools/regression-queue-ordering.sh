#!/usr/bin/env bash
# regression-queue-ordering.sh — T894 controls for the queue-head lie
#
# `managent status` and `managent orient` sorted the dispatchable and blocked
# lists by task id — a lexicographic accident, not a readiness signal. The
# operator read the top of the list as "what is next"; it was not. A
# malformed `--bundle` row (a flag captured as a positional id), duties
# (DARGUS/DCLAIM/DRPLAY), and standing triggers (STANDING-ABSORB/CLEANUP)
# all sorted ahead of real, ready work because 'D'/'S'/'-' sort before 'T'.
# orient additionally never checked ts.duty at all, so duties leaked into
# its dispatchable bucket unfiltered.
#
# Fix (src/managent/main.zig):
#   - isDutyOrStanding: a duty (ts.duty) or a standing trigger (id begins
#     "STANDING-") never renders in the dispatchable/blocked buckets — own
#     section in both `status` and `orient`.
#   - dispatchLessThan: within the dispatchable bucket, ready-now (no holds
#     conflict against an in-flight row, and its bundle file exists on disk)
#     sorts before cold; id is the deterministic tiebreak within a tier.
#   - blockedLessThan: within the blocked bucket, fewer unmet needs (closer
#     to unblocking) sorts before more; id is the tiebreak.
#   - queueEstimateSuffix: one column — "est: <N>s (elapsed)" for a running
#     or done row, "est: <N>s (expected)" for one not yet dispatched (from
#     expected_wall_s), "est: UNKNOWN" when the input is absent. Never a
#     fabricated number.
#   - cmdAdd refuses a positional id that begins with '-' (the exact shape
#     that let `--bundle` in) before it ever reaches the store.
#
# Controls:
#   red (this file, run against pre-fix source)
#                       STANDING-FOO/DUTY1 sort ahead of a real ready row in
#                       both status and orient; cold rows (holds-conflicted
#                       or missing-brief) sort ahead of ready ones alpha-
#                       betically; blocked rows keep id order regardless of
#                       closeness — asserted below, fails on the old sort.
#   seeded-defect       `managent add --bundle <path>` (no id given) takes
#                       "--bundle" as the positional id under the old code;
#                       refused by name, never registered.
#   null control        a queue of only ready rows: every seeded id appears
#                       exactly once, none vanish (count in == count out).
#
# All fixtures are synthetic and run in /tmp/weizigo — the live kanban is
# never touched. MANAGENT_STORE points at a scratch kanban; the command runs
# from the scratch repo so findRepoRoot resolves there.
#
# Binary resolution: $MANAGENT_BIN → zig-out/bin/managent → bin/managent.
# SKIP (loudly) when neither carries the `orient` command.
#
# Task: T894 · Role: worker · Model: claude-sonnet-5 · Date: 2026-08-25

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
FAIL=0

# T849: the one isolated scratch-repo helper (unsets GIT_DIR et al. before
# `git init`), so this is safe to run outside the pre-commit hook too.
. "$PROJECT/tools/lib/scratch-repo.sh"

# ── binary resolution ─────────────────────────────────────────────────────
MG="${MANAGENT_BIN:-}"
if [ -z "$MG" ]; then
    if [ -x "$PROJECT/zig-out/bin/managent" ]; then
        MG="$PROJECT/zig-out/bin/managent"
    elif [ -x "$PROJECT/bin/managent" ]; then
        MG="$PROJECT/bin/managent"
    fi
fi
if [ -z "$MG" ]; then
    echo "SKIP: no managent binary found — build with 'zig build' (zig-out/bin/managent) or deploy (zig build deploy-managent)"
    exit 0
fi
if ! "$MG" help 2>&1 | grep -q "managent orient"; then
    echo "SKIP: $MG does not carry the orient command — rebuild from src/managent/main.zig"
    exit 0
fi

weizigo_scratch_repo queue-ordering WORK   # T849: isolated scratch repo
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
git config user.email t894@test
git config user.name T894
mkdir -p docs/infra/managent untracked
echo base > README.md
git add README.md
git commit -qm base

STORE="$WORK/docs/infra/managent/tasks.json"
export MANAGENT_STORE="$STORE"

# ── bundle fixtures (must exist on disk for the "ready-now" reading; the
#    content is irrelevant here — the store is written directly, bypassing
#    `add`'s title/landmark gates, which are not this row's concern) ───────
for id in TREADY TCOLDHOLDS TBLOCKZ TBLOCKA TNEED_DONE TNEED_OPEN TNEED_A TNEED_B TNEED_C TINPROG DUTY1 STANDING-FOO TESTWALL; do
    cat > "untracked/${id}-bundle.md" <<EOF
# ${id} — scratch queue-ordering fixture
EOF
done
# TCOLDBRIEF's bundle is deliberately never created — "whether a brief
# exists" is one of the three readiness inputs the brief names.

python3 - "$STORE" "$WORK" <<'PYEOF'
import json, sys
store, work = sys.argv[1], sys.argv[2]

def bundle(id):
    return f"{work}/untracked/{id}-bundle.md"

rows = {
    "_sys": {"next_id": 9000, "directive_next": 1},
    # ready-now: no needs, no holds, brief exists
    "TREADY": {"status": "dispatchable", "bundle": bundle("TREADY"), "set": "A",
               "holds": [], "needs": [], "caps": [], "added": "2026-08-25T00:00:00Z"},
    # cold: holds collide with TINPROG (in_progress) — cannot start now
    "TCOLDHOLDS": {"status": "dispatchable", "bundle": bundle("TCOLDHOLDS"), "set": "A",
                   "holds": ["shared/file.zig"], "needs": [], "caps": [], "added": "2026-08-25T00:00:00Z"},
    "TINPROG": {"status": "in_progress", "bundle": bundle("TINPROG"), "set": "A",
                "holds": ["shared/file.zig"], "needs": [], "caps": [],
                "added": "2020-01-01T00:00:00Z", "claimed": "2020-01-01T00:00:00Z",
                "agent": "claude-sonnet-5"},
    # cold: brief missing from disk — nothing at TCOLDBRIEF's bundle path
    "TCOLDBRIEF": {"status": "dispatchable", "bundle": f"{work}/untracked/TCOLDBRIEF-missing.md",
                   "set": "A", "holds": [], "needs": [], "caps": [], "added": "2026-08-25T00:00:00Z"},
    # blocked: 1 unmet need (TNEED_OPEN) — closer to unblocking
    "TBLOCKZ": {"status": "dispatchable", "bundle": bundle("TBLOCKZ"), "set": "A",
                "holds": [], "needs": ["TNEED_DONE", "TNEED_OPEN"], "caps": [], "added": "2026-08-25T00:00:00Z"},
    # blocked: 3 unmet needs — farther from unblocking, but alphabetically
    # BEFORE TBLOCKZ — the id-sort defect would have put this FIRST
    "TBLOCKA": {"status": "dispatchable", "bundle": bundle("TBLOCKA"), "set": "A",
                "holds": [], "needs": ["TNEED_A", "TNEED_B", "TNEED_C"], "caps": [], "added": "2026-08-25T00:00:00Z"},
    "TNEED_DONE": {"status": "done", "bundle": bundle("TNEED_DONE"), "set": "A",
                   "holds": [], "needs": [], "caps": [], "added": "2026-08-25T00:00:00Z",
                   "claimed": "2026-08-25T00:00:00Z", "done": "2026-08-25T00:00:01Z", "verdict": "pass"},
    "TNEED_OPEN": {"status": "dispatchable", "bundle": bundle("TNEED_OPEN"), "set": "A",
                   "holds": [], "needs": [], "caps": [], "added": "2026-08-25T00:00:00Z"},
    "TNEED_A": {"status": "dispatchable", "bundle": bundle("TNEED_A"), "set": "A",
                "holds": [], "needs": [], "caps": [], "added": "2026-08-25T00:00:00Z"},
    "TNEED_B": {"status": "dispatchable", "bundle": bundle("TNEED_B"), "set": "A",
                "holds": [], "needs": [], "caps": [], "added": "2026-08-25T00:00:00Z"},
    "TNEED_C": {"status": "dispatchable", "bundle": bundle("TNEED_C"), "set": "A",
                "holds": [], "needs": [], "caps": [], "added": "2026-08-25T00:00:00Z"},
    # a real duty and a real standing trigger — both sort ahead of "TREADY"
    # alphabetically ('D'/'S' < 'T'), which is exactly the T894 defect
    "DUTY1": {"status": "dispatchable", "bundle": bundle("DUTY1"), "set": "H",
              "holds": [], "needs": [], "caps": [], "added": "2026-08-19T00:00:00Z", "duty": True},
    "STANDING-FOO": {"status": "dispatchable", "bundle": bundle("STANDING-FOO"), "set": "H",
                     "holds": [], "needs": [], "caps": [], "added": "2026-08-19T00:00:00Z", "duty": False},
    # expected_wall_s present — the estimate column's "expected" reading
    "TESTWALL": {"status": "dispatchable", "bundle": bundle("TESTWALL"), "set": "A",
                 "holds": [], "needs": [], "caps": [], "added": "2026-08-25T00:00:00Z", "expected_wall_s": 1800},
}
json.dump(rows, open(store, "w"))
PYEOF

echo "=== managent queue-ordering regression (T894) ==="

STATUS_OUT=$("$MG" status 2>/dev/null)
ORIENT_OUT=$("$MG" orient 2>/dev/null)

line_of() { # $1=text $2=pattern -> first matching line number, or 0
    printf '%s\n' "$1" | grep -n "$2" | head -1 | cut -d: -f1
}
lt() { # numeric a < b, both required non-empty
    [ -n "${1:-}" ] && [ -n "${2:-}" ] && [ "$1" -lt "$2" ]
}

# ── 1. red: duty/standing never precede a ready row (status) ──────────────
echo "  1. status: a duty (DUTY1) and a standing trigger (STANDING-FOO) never precede a ready row (TREADY)"
R=$(line_of "$STATUS_OUT" "^    TREADY ")
D=$(line_of "$STATUS_OUT" "^    DUTY1 ")
S=$(line_of "$STATUS_OUT" "^    STANDING-FOO ")
if lt "$R" "$D" 2>/dev/null && lt "$R" "$S" 2>/dev/null; then
    echo "    PASS: TREADY (line $R) precedes DUTY1 (line $D) and STANDING-FOO (line $S)"
else
    echo "    FAIL: TREADY=$R DUTY1=$D STANDING-FOO=$S"
    FAIL=1
fi

# ── 2. red: duty/standing are absent from the dispatchable section itself ─
echo "  2. status: DUTY1/STANDING-FOO are excluded from the dispatchable section, not merely late"
DISPATCH_BLOCK=$(printf '%s\n' "$STATUS_OUT" | sed -n '/^  dispatchable (/,/^$/p')
if ! printf '%s\n' "$DISPATCH_BLOCK" | grep -q "DUTY1" && ! printf '%s\n' "$DISPATCH_BLOCK" | grep -q "STANDING-FOO"; then
    echo "    PASS: dispatchable section carries neither DUTY1 nor STANDING-FOO"
else
    echo "    FAIL: dispatchable section leaked a duty/standing row:"
    printf '%s\n' "$DISPATCH_BLOCK" | sed 's/^/      /'
    FAIL=1
fi

# ── 3. red: ready-now sorts before cold (status) ───────────────────────────
echo "  3. status: TREADY (ready-now) precedes TCOLDHOLDS and TCOLDBRIEF (cold) despite alphabetical order saying otherwise"
CH=$(line_of "$STATUS_OUT" "^    TCOLDHOLDS ")
CB=$(line_of "$STATUS_OUT" "^    TCOLDBRIEF ")
if lt "$R" "$CH" 2>/dev/null && lt "$R" "$CB" 2>/dev/null; then
    echo "    PASS: TREADY (line $R) precedes TCOLDHOLDS (line $CH) and TCOLDBRIEF (line $CB)"
else
    echo "    FAIL: TREADY=$R TCOLDHOLDS=$CH TCOLDBRIEF=$CB"
    FAIL=1
fi

# ── 4. red: blocked rows sort by closeness, not id (status) ────────────────
echo "  4. status: TBLOCKZ (1 unmet need) precedes TBLOCKA (3 unmet needs) though 'A' < 'Z'"
BZ=$(line_of "$STATUS_OUT" "^    TBLOCKZ ")
BA=$(line_of "$STATUS_OUT" "^    TBLOCKA ")
if lt "$BZ" "$BA" 2>/dev/null; then
    echo "    PASS: TBLOCKZ (line $BZ) precedes TBLOCKA (line $BA)"
else
    echo "    FAIL: TBLOCKZ=$BZ TBLOCKA=$BA"
    FAIL=1
fi

# ── 5. estimate column: UNKNOWN / expected / elapsed, never fabricated ─────
echo "  5. status: the estimate column reads UNKNOWN, expected, or elapsed — never a fabricated number"
OK=1
printf '%s\n' "$STATUS_OUT" | grep "^    TREADY " | grep -q ", est: UNKNOWN" || { echo "    FAIL: TREADY missing ', est: UNKNOWN'"; OK=0; }
printf '%s\n' "$STATUS_OUT" | grep "^    TESTWALL " | grep -q ", est: 1800s (expected)" || { echo "    FAIL: TESTWALL missing ', est: 1800s (expected)'"; OK=0; }
printf '%s\n' "$STATUS_OUT" | grep "^    TINPROG " | grep -qE ", est: [0-9]+s \(elapsed\)" || { echo "    FAIL: TINPROG missing ', est: <N>s (elapsed)'"; OK=0; }
[ "$OK" -eq 1 ] && echo "    PASS: UNKNOWN / expected / elapsed all read correctly"
[ "$OK" -eq 1 ] || FAIL=1

# ── 6. orient: same duty/standing separation (orient never checked ts.duty
#    at all — DARGUS/DCLAIM/DRPLAY leaked straight into its dispatchable
#    bucket) ──────────────────────────────────────────────────────────────
echo "  6. orient: DUTY1/STANDING-FOO excluded from the dispatchable list, present under duties & standing triggers"
ORIENT_DISPATCH=$(printf '%s\n' "$ORIENT_OUT" | sed -n '/^dispatchable (/,/^blocked (/p')
ORIENT_DUTIES=$(printf '%s\n' "$ORIENT_OUT" | sed -n '/^duties & standing triggers (/,/^$/p')
if ! printf '%s\n' "$ORIENT_DISPATCH" | grep -q "DUTY1" && \
   ! printf '%s\n' "$ORIENT_DISPATCH" | grep -q "STANDING-FOO" && \
   printf '%s\n' "$ORIENT_DUTIES" | grep -q "DUTY1" && \
   printf '%s\n' "$ORIENT_DUTIES" | grep -q "STANDING-FOO"; then
    echo "    PASS: excluded from dispatchable, present under duties & standing triggers"
else
    echo "    FAIL: dispatchable block:"
    printf '%s\n' "$ORIENT_DISPATCH" | sed 's/^/      /'
    echo "    duties block:"
    printf '%s\n' "$ORIENT_DUTIES" | sed 's/^/      /'
    FAIL=1
fi

# ── 7. orient: ready-now before cold, blocked by closeness ─────────────────
echo "  7. orient: readiness ordering matches status (ready before cold, blocked by closeness)"
OR=$(line_of "$ORIENT_OUT" "^  TREADY ")
OCH=$(line_of "$ORIENT_OUT" "^  TCOLDHOLDS ")
OCB=$(line_of "$ORIENT_OUT" "^  TCOLDBRIEF ")
OBZ=$(line_of "$ORIENT_OUT" "^  TBLOCKZ ")
OBA=$(line_of "$ORIENT_OUT" "^  TBLOCKA ")
if lt "$OR" "$OCH" 2>/dev/null && lt "$OR" "$OCB" 2>/dev/null && lt "$OBZ" "$OBA" 2>/dev/null; then
    echo "    PASS: TREADY=$OR before TCOLDHOLDS=$OCH/TCOLDBRIEF=$OCB; TBLOCKZ=$OBZ before TBLOCKA=$OBA"
else
    echo "    FAIL: TREADY=$OR TCOLDHOLDS=$OCH TCOLDBRIEF=$OCB TBLOCKZ=$OBZ TBLOCKA=$OBA"
    FAIL=1
fi

# ── 8. seeded-defect control: a leading-dash id is refused by name ─────────
echo "  8. seeded-defect control: 'managent add --bundle <path>' (no id) is refused, not registered as id '--bundle'"
ADD_OUT=$("$MG" add --bundle "untracked/TREADY-bundle.md" 2>&1)
ADD_RC=$?
if [ "$ADD_RC" -ne 0 ] && echo "$ADD_OUT" | grep -q -- "--bundle" && echo "$ADD_OUT" | grep -qi "flag"; then
    echo "    PASS: refused by name (RC=$ADD_RC)"
else
    echo "    FAIL: RC=$ADD_RC, output:"
    echo "$ADD_OUT" | sed 's/^/      /'
    FAIL=1
fi
if grep -q '"--bundle"' "$STORE"; then
    echo "    FAIL: '--bundle' was registered into the store anyway"
    FAIL=1
else
    echo "    PASS: store carries no '--bundle' key"
fi

# ── 9. null control: a queue of only ready rows — nothing vanishes ────────
echo "  9. null control: a queue of only ready rows is ordered sensibly and none vanish (count in == count out)"
NULLSTORE="$WORK/docs/infra/managent/tasks-null.json"
python3 - "$NULLSTORE" "$WORK" <<'PYEOF'
import json, sys
store, work = sys.argv[1], sys.argv[2]
rows = {"_sys": {"next_id": 9000, "directive_next": 1}}
for i in range(1, 6):
    tid = f"TN{i}"
    rows[tid] = {"status": "dispatchable", "bundle": f"{work}/untracked/TREADY-bundle.md",
                 "set": "A", "holds": [], "needs": [], "caps": [], "added": "2026-08-25T00:00:00Z"}
json.dump(rows, open(store, "w"))
PYEOF
NULL_OUT=$(MANAGENT_STORE="$NULLSTORE" "$MG" status 2>/dev/null)
SEEDED=5
FOUND=$(printf '%s\n' "$NULL_OUT" | grep -cE "^    TN[1-5] ")
HEADER_N=$(printf '%s\n' "$NULL_OUT" | grep -oE "^  dispatchable \([0-9]+\)" | grep -oE "[0-9]+")
if [ "$FOUND" -eq "$SEEDED" ] && [ "$HEADER_N" = "$SEEDED" ]; then
    echo "    PASS: seeded $SEEDED, header states $HEADER_N, $FOUND rows found — count in == count out"
else
    echo "    FAIL: seeded=$SEEDED header=$HEADER_N found=$FOUND"
    echo "$NULL_OUT" | sed 's/^/      /'
    FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-queue-ordering: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-queue-ordering: FAILURES ==="
    exit 1
fi
