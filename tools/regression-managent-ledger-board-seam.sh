#!/usr/bin/env bash
# regression-managent-ledger-board-seam.sh
# T446 → T464 → T497 regression: ONE status source — the kanban store.
#
# T446 first let a `closed` assertion supersede tasks.json; T464 generalised
# that to BOTH directions (the assertion ledger was authoritative over the
# stored status for every status it can assert). T497 reverses T464's
# generalisation: status has exactly ONE source — tasks.json (the kanban
# store), written only by managent verbs. The assertion ledger remains an
# append-only event log of console-lifecycle facts; its latest entry on a row
# renders as an ANNOTATION (history) in status/show output, never as the
# effective status. The live defect was A0017 (T452 dispatchable) overriding a
# live in_progress kanban — a stale event log overrode a live kanban truth.
#
# Arms:
#   A. dispatchable + `closed` assertion → renders DISPATCHABLE (kanban) with
#      an (asserted) annotation — the assertion does NOT make it done.
#   B. in_progress  + `closed` assertion → renders IN_PROGRESS (kanban) with
#      an (asserted) annotation AND the live claim (identifier) shown — the
#      assertion does NOT suppress the live claim.
#   C. `next` hands out a dispatchable row even with a `closed` assertion
#      (the row is dispatchable in the kanban; the assertion is history only).
#   D. null arm: no ledger file → dispatchable rendering and `next` unchanged.
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
git config user.email t497@test
git config user.name T497
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

# Append an assertion line to the scratch ledger: $1=assertion-id $2=row $3=status
assert_status() {
    printf '{"id":"%s","ts":"2026-08-18T17:10:20Z","actor":"test","verb":"asserted","object":"%s","basis":"performed","meta":{"status":"%s","note":"seeded regression"}}\n' "$1" "$2" "$3" >> "$LEDGER"
}

echo "=== T497 ledger/board seam regression (one status source: the kanban store) ==="

# ── Arm A/B: status rendering comes from the kanban store; the ledger annotates ──
echo "  A. dispatchable + closed assertion renders DISPATCHABLE (kanban) + annotation"
echo "  B. in_progress + closed assertion renders IN_PROGRESS (kanban) + annotation + live claim"

seed "$(rec_disp T430),$(rec_disp T431),$(rec_inprog T440 claude-opus-5)"
: > "$LEDGER"
assert_status A0005 T430 closed
assert_status A0012 T440 closed

STATUS_TEXT=$("$MG" status 2>/dev/null)
STATUS_JSON=$("$MG" status --json 2>/dev/null)

# A: T430 stays dispatchable (kanban) and gains an (asserted: A0005) annotation.
if echo "$STATUS_TEXT" | grep -q 'asserted: A0005'; then
    echo "    PASS: T430 rendered with (asserted: A0005) annotation"
else
    echo "    FAIL: T430 annotation missing from status text:"
    echo "$STATUS_TEXT"
    FAIL=1
fi

# B: T440 stays in_progress (kanban) WITH its live claim (claude-opus-5) shown —
# the closed assertion annotates but does NOT suppress the live claim.
if echo "$STATUS_TEXT" | grep -q 'asserted: A0012' && echo "$STATUS_TEXT" | grep -q 'claude-opus-5'; then
    echo "    PASS: T440 rendered (asserted: A0012) AND kept its live claim"
else
    echo "    FAIL: T440 did not render asserted+live-claim together:"
    echo "$STATUS_TEXT"
    FAIL=1
fi

# Structural checks via --json: status comes from the KANBAN store; asserted is
# an informational annotation field; the live identifier still renders.
JSON_CHECK=$(python3 - "$STATUS_JSON" <<'PYEOF'
import sys, json
data = json.loads(sys.argv[1])
by_id = {d["id"]: d for d in data}
fails = []
t430 = by_id.get("T430")
t440 = by_id.get("T440")
t431 = by_id.get("T431")
# A: dispatchable in kanban, closed assertion → still dispatchable + asserted.
if t430 is None or t430.get("status") != "dispatchable" or t430.get("asserted") != "A0005":
    fails.append("T430 should be status=dispatchable asserted=A0005, got %r" % t430)
# B: in_progress in kanban, closed assertion → still in_progress + asserted + live identifier.
if t440 is None or t440.get("status") != "in_progress" or t440.get("asserted") != "A0012":
    fails.append("T440 should be status=in_progress asserted=A0012, got %r" % t440)
if t440 is not None and t440.get("identifier") is None:
    fails.append("T440 must still show its live identifier, got %r" % t440)
# Control: no assertion → dispatchable, no asserted field.
if t431 is None or t431.get("status") != "dispatchable" or "asserted" in t431:
    fails.append("T431 control should stay dispatchable with no asserted, got %r" % t431)
if fails:
    for f in fails:
        print("    FAIL: " + f)
    sys.exit(1)
print("    PASS: JSON reports T430 dispatchable+asserted, T440 in_progress+asserted+identifier, T431 dispatchable")
PYEOF
)
if [ $? -eq 0 ]; then
    echo "$JSON_CHECK"
else
    echo "$JSON_CHECK"
    FAIL=1
fi

# ── Arm C: `next` hands out a dispatchable row even with a `closed` assertion ──
# T497: a closed assertion is history only; a dispatchable row in the kanban is
# handed out. (T464 dropped it; T497 restores the kanban as the single source.)
echo "  C. next hands out a dispatchable row despite a closed assertion"

seed "$(rec_disp T430)"
: > "$LEDGER"
assert_status A0005 T430 closed

NEXT_OUT=$("$MG" next 2>&1); RC=$?
if [ "$RC" -eq 0 ] && echo "$NEXT_OUT" | grep -q 'claimed T430'; then
    echo "    PASS: next handed out T430 (kanban dispatchable wins over closed assertion)"
else
    echo "    FAIL: next refused a dispatchable row because of a closed assertion: $NEXT_OUT"
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
    echo "  T497 ledger/board seam: ALL CHECKS PASS"
else
    echo "  T497 ledger/board seam: SOME CHECKS FAILED"
fi
exit "$FAIL"