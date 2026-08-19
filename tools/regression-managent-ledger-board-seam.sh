#!/usr/bin/env bash
# regression-managent-ledger-board-seam.sh
# T446 regression: the board and `next` must render what the assertion ledger
# asserts — a `closed` assertion supersedes tasks.json's status, so finished
# work is neither shown dispatchable nor handed out by `next`.
#
# Arms:
#   A. dispatchable + `closed` assertion → renders done (asserted), not dispatchable
#   B. in_progress  + `closed` assertion → renders done (asserted), no live claim
#   C. `next` never hands out a closed-asserted row (single dispatchable seed)
#   D. null arm: no ledger file → dispatchable rendering and `next` unchanged
#
# Every arm runs against a scratch store + scratch ledger in /tmp/weizigo —
# never the live docs/infra/managent/tasks.json (T445).
#
# Usage:  tools/regression-managent-ledger-board-seam.sh [--build]
#   --build: rebuild managent from source + deploy before testing

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
MG="$PROJECT/bin/managent"
FAIL=0

if [ "${1:-}" = "--build" ]; then
    echo "  rebuilding managent (guarded, ReleaseSafe) and deploying..."
    (cd "$PROJECT" && "$PROJECT/tools/runner" --no-prepend-zig -- zig build -Doptimize=ReleaseSafe 2>&1)
    "$PROJECT/tools/deploy.sh" "$PROJECT/zig-out/bin/managent" "$MG"
fi

# T445: /tmp/weizigo decays (tmp sweeps, reboots). Create it, and REFUSE to run
# if scratch creation fails — an empty scratch var once sent this suite's arms
# into the LIVE repo (2026-08-18 incident). cd "" succeeds silently; never rely
# on it.
mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/managent-ledger-seam-XXXXXX)" || { echo "regression-managent-ledger-board-seam.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
git init -q
git config user.email t446@test
git config user.name T446
mkdir -p docs/infra/managent docs/infra/assertion-ledger untracked
STORE="$WORK/docs/infra/managent/tasks.json"
LEDGER="$WORK/docs/infra/assertion-ledger/assertions.jsonl"
export MANAGENT_STORE="$STORE"

seed() {  # $1 = JSON body of one or more task records (no trailing comma)
    printf '{\n  %s,\n  "_sys": {"next_id": 9000, "directive_next": 1, "assertion_next": 1}\n}\n' "$1" > "$STORE"
}

# dispatchable task record: $1=id
rec_disp() {
    printf '"%s":{"status":"dispatchable","agent":null,"model":null,"bundle":"untracked/%s-bundle.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":null,"done":null,"dispatched":null,"dispatched_to":null,"note":null,"verdict":null,"verdict_note":null,"acceptance":null,"skip_acceptance_reason":null,"claim_count":0}' "$1" "$1"
}

# in_progress task record claimed by a named agent: $1=id  $2=agent
rec_inprog() {
    printf '"%s":{"status":"in_progress","agent":"%s","model":"%s","bundle":"untracked/%s-bundle.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"2026-08-01T00:00:01Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"verdict":null,"verdict_note":null,"acceptance":null,"skip_acceptance_reason":null,"claim_count":1}' "$1" "$2" "$2" "$1"
}

# Append a `closed` assertion line to the scratch ledger: $1=assertion-id $2=row
assert_closed() {
    printf '{"id":"%s","ts":"2026-08-18T17:10:20Z","actor":"test","verb":"asserted","object":"%s","basis":"performed","meta":{"status":"closed","note":"seeded regression"}}\n' "$1" "$2" >> "$LEDGER"
}

echo "=== T446 ledger/board seam regression ==="

# ── Arm A/B: status rendering consults the ledger ───────────────────────
echo "  A. dispatchable + closed assertion renders done (asserted), not dispatchable"
echo "  B. in_progress + closed assertion renders done (asserted), no live claim"

seed "$(rec_disp T430),$(rec_disp T431),$(rec_inprog T440 claude-opus-5)"
: > "$LEDGER"
assert_closed A0005 T430
assert_closed A0012 T440

STATUS_TEXT=$("$MG" status 2>/dev/null)
STATUS_JSON=$("$MG" status --json 2>/dev/null)

# A: T430 moved out of dispatchable and into done with the (asserted) marker.
if echo "$STATUS_TEXT" | grep -q '(asserted: A0005)'; then
    echo "    PASS: T430 rendered with (asserted: A0005) marker"
else
    echo "    FAIL: T430 marker missing from status text:"
    echo "$STATUS_TEXT"
    FAIL=1
fi

# B: T440 rendered with the (asserted) marker and no live claim (agent suppressed).
if echo "$STATUS_TEXT" | grep -q '(asserted: A0012)' && ! echo "$STATUS_TEXT" | grep -q 'claude-opus-5'; then
    echo "    PASS: T440 rendered (asserted: A0012) with no live claim"
else
    echo "    FAIL: T440 did not render asserted with claim suppressed:"
    echo "$STATUS_TEXT"
    FAIL=1
fi

# Structural checks via --json: asserted-closed rows report status done + asserted.
JSON_CHECK=$(python3 - "$STATUS_JSON" <<'PYEOF'
import sys, json
data = json.loads(sys.argv[1])
by_id = {d["id"]: d for d in data}
fails = []
t430 = by_id.get("T430")
t440 = by_id.get("T440")
t431 = by_id.get("T431")
if t430 is None or t430.get("status") != "done" or t430.get("asserted") != "A0005":
    fails.append("T430 should be status=done asserted=A0005, got %r" % t430)
if t440 is None or t440.get("status") != "done" or t440.get("asserted") != "A0012":
    fails.append("T440 should be status=done asserted=A0012, got %r" % t440)
if t431 is None or t431.get("status") != "dispatchable" or "asserted" in t431:
    fails.append("T431 control should stay dispatchable with no asserted, got %r" % t431)
if t430 is not None and "identifier" in t430:
    fails.append("T430 asserted-closed must not show a live identifier, got %r" % t430.get("identifier"))
if t440 is not None and "identifier" in t440:
    fails.append("T440 asserted-closed must not show a live identifier, got %r" % t440.get("identifier"))
if fails:
    for f in fails:
        print("    FAIL: " + f)
    sys.exit(1)
print("    PASS: JSON reports T430/T440 done+asserted, T431 dispatchable, no live identifiers")
PYEOF
)
if [ $? -eq 0 ]; then
    echo "$JSON_CHECK"
else
    echo "$JSON_CHECK"
    FAIL=1
fi

# ── Arm C: `next` never hands out a closed-asserted row ─────────────────
echo "  C. next never hands out a closed-asserted row"

seed "$(rec_disp T430)"
: > "$LEDGER"
assert_closed A0005 T430

NEXT_OUT=$("$MG" next 2>&1); RC=$?
if [ "$RC" -eq 0 ] && ! echo "$NEXT_OUT" | grep -q 'claimed'; then
    echo "    PASS: next refused to hand out closed-asserted T430 (nothing claimed)"
else
    echo "    FAIL: next handed out a closed-asserted row: $NEXT_OUT"
    FAIL=1
fi

# ── Arm D: null arm — no ledger file → behaviour unchanged ─────────────
echo "  D. null arm: no ledger file → dispatchable rendering and next unchanged"

rm -f "$LEDGER"
seed "$(rec_disp T431)"

NULL_STATUS=$("$MG" status 2>/dev/null)
if echo "$NULL_STATUS" | grep -q 'T431' && ! echo "$NULL_STATUS" | grep -q 'asserted'; then
    echo "    PASS: T431 renders dispatchable with no asserted marker (no ledger)"
else
    echo "    FAIL: null arm status misrendered:"
    echo "$NULL_STATUS"
    FAIL=1
fi

NULL_NEXT=$("$MG" next 2>&1); RC=$?
if [ "$RC" -eq 0 ] && echo "$NULL_NEXT" | grep -q 'claimed T431'; then
    echo "    PASS: next hands out T431 with no ledger (unchanged behaviour)"
else
    echo "    FAIL: null arm next did not claim T431: $NULL_NEXT"
    FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "  T446 ledger/board seam: ALL CHECKS PASS"
else
    echo "  T446 ledger/board seam: SOME CHECKS FAILED"
fi
exit "$FAIL"
