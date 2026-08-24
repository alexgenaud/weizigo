#!/usr/bin/env bash
# regression-managent-duty.sh
# T478 regression: managent duty mechanism + landmark gate.
#
# Arms (scratch store only — never the live kanban, T445):
#   A. seeded — 5 task closes make a duty due
#   B. seeded — an overdue duty refuses a landmark declaration and names it
#              (also: the duty renders in the `duties` section, not dispatchable,
#               in both the text board and `status --json`)
#   C. null    — with no duties registered the declaration succeeds
#   D. null    — a duty chunk recorded resets its due-count (declaration then succeeds)
#   E. seeded  — `next` never hands out a duty in place of a task (task-only and duty-only)
#   F. seeded  — a duty whose last chunk failed blocks a landmark even when not due
#
# The binary under test defaults to the deployed bin/managent (as the other
# regressions do) but honours MANAGENT_BIN so a not-yet-deployed build can be
# exercised without touching the live binary (T478 is build-only).
#
# Usage:  tools/regression-managent-duty.sh [--build]
#   --build: rebuild managent from source + deploy before testing

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
MG="${MANAGENT_BIN:-$PROJECT/bin/managent}"
FAIL=0

if [ "${1:-}" = "--build" ]; then
    echo "  rebuilding managent (guarded, ReleaseSafe) and deploying..."
    (cd "$PROJECT" && "$PROJECT/tools/runner" --no-prepend-zig -- zig build -Doptimize=ReleaseSafe 2>&1)
    "$PROJECT/tools/deploy.sh" "$PROJECT/zig-out/bin/managent" "$PROJECT/bin/managent"
    MG="$PROJECT/bin/managent"
fi

# T849: scratch repo via the ONE isolated helper (unset GIT_DIR… before git
# init); safe to run outside the pre-commit hook. T445 refuse-on-failure is
# preserved by the helper.
. "$PROJECT/tools/lib/scratch-repo.sh"
weizigo_scratch_repo managent-duty WORK   # T849: isolated scratch repo
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
git config user.email t478@test
git config user.name T478
mkdir -p docs/infra/managent untracked
# T485: the absorption done-gate runs claimlint on every gated close; the
# scratch repo must carry a claimlint binary + a parseable (empty) register.
GATE_CL="$PROJECT/zig-out/bin/weizigo-claimlint"
[ -x "$GATE_CL" ] || GATE_CL="$PROJECT/bin/weizigo-claimlint"
if [ ! -x "$GATE_CL" ]; then
    echo "SKIP: no weizigo-claimlint binary (build with 'zig build') — the done-gate needs it"
    exit 0
fi
mkdir -p bin docs/epistemic
cp "$GATE_CL" bin/weizigo-claimlint
cat > docs/epistemic/CLAIMS.md <<'CLAIMS_EOF'
# scratch register — done-gate control (T485)

## 2. The register

| ID | legacy | goban | claim | status | evidence | depends-on | dependents | narrowed | wrong-answer-pass-rate | tree |
|---|---|---|---|---|---|---|---|---|---|---|
CLAIMS_EOF
STORE="$WORK/docs/infra/managent/tasks.json"
export MANAGENT_STORE="$STORE"

# Full duty record (all fields the current serializer writes): $1=id $2=closes $3=verdict
duty_rec() {
python3 - "$1" "$2" "$3" <<'PY'
import json, sys
uid, closes, verdict = sys.argv[1], int(sys.argv[2]), sys.argv[3]
v = None if verdict == "-" else verdict
print(json.dumps({uid: {
    "status": "dispatchable", "agent": None, "model": None,
    "bundle": f"untracked/{uid}.md", "set": "H", "holds": [], "needs": [], "caps": [],
    "added": "2026-08-01T00:00:00Z", "claimed": None, "done": None,
    "dispatched": None, "dispatched_to": None, "note": None,
    "verdict": None, "verdict_note": None, "claim_count": 0,
    "acceptance": None, "skip_acceptance_reason": None, "amendments": [], "epitaph": None,
    "duty": True, "due_after": 5, "last_chunk_closes": closes,
    "last_chunk_ts": None, "last_chunk_verdict": v, "last_chunk_findings": None,
}}))
PY
}

# Full task record (in_progress, old claim so `done` needs no --force): $1=id
task_inprog_rec() {
python3 - "$1" <<'PY'
import json, sys
uid = sys.argv[1]
print(json.dumps({uid: {
    "status": "in_progress", "agent": "deepseek-v4-pro", "model": None,
    "bundle": f"untracked/{uid}.md", "set": "A", "holds": [], "needs": [], "caps": [],
    "added": "2026-08-01T00:00:00Z", "claimed": "2026-08-01T00:00:00Z", "done": None,
    "dispatched": None, "dispatched_to": None, "note": None,
    "verdict": None, "verdict_note": None, "claim_count": 1,
    "acceptance": None, "skip_acceptance_reason": None, "amendments": [], "epitaph": None,
    "duty": False, "due_after": 5, "last_chunk_closes": 0,
    "last_chunk_ts": None, "last_chunk_verdict": None, "last_chunk_findings": None,
}}))
PY
}

# Write a store from comma-joined record JSON + a _sys value: $1=records $2=closes
seed_store() {
python3 - "$STORE" "$1" "$2" <<'PY'
import json, sys
store, records, closes = sys.argv[1], sys.argv[2], int(sys.argv[3])
doc = {}
for rec in records.split("__REC__"):
    if not rec.strip():
        continue
    r = json.loads(rec)
    doc[next(iter(r))] = r[next(iter(r))]
doc["_sys"] = {"next_id": 9000, "directive_next": 1, "assertion_next": 1, "closes": closes, "duty_migrated": True}
json.dump(doc, open(store, "w"), indent=1)
PY
weizigo_reset_census "$STORE"   # T855: direct write bypasses the census; see tools/lib/scratch-repo.sh
}

echo "=== T478 duty mechanism regression ==="

# ── Arm A: 5 task closes make a duty due ─────────────────────────────────
echo "  A. seeded: 5 task closes make a duty due"

RECS="$(duty_rec DCLAIM 0 -)__REC__$(task_inprog_rec T1)__REC__$(task_inprog_rec T2)__REC__$(task_inprog_rec T3)__REC__$(task_inprog_rec T4)__REC__$(task_inprog_rec T5)"
seed_store "$RECS" 0
for i in 1 2 3 4 5; do
    printf '<!--managent set=A deliverables=-->\n# T%s\n' "$i" > "untracked/T$i.md"
    "$MG" done "T$i" --status pass --impression "duty control" >/dev/null 2>&1
done

STATUS_JSON=$("$MG" status --json 2>/dev/null)
python3 - "$STATUS_JSON" <<'PY'
import sys, json
data = json.loads(sys.argv[1])
d = [r for r in data if r.get("id") == "DCLAIM"]
if not d or d[0].get("duty") is not True or d[0].get("due") is not True or d[0].get("status") != "duty":
    print("    FAIL: DCLAIM not due after 5 closes:", d)
    sys.exit(1)
print("    PASS: DCLAIM due after 5 task closes (status=duty, duty=true, due=true)")
PY
if [ $? -ne 0 ]; then FAIL=1; fi

# ── Arm B: overdue duty refuses a landmark declaration and names it ──────
echo "  B. seeded: overdue duty refuses a landmark declaration and names it"

seed_store "$(duty_rec DCLAIM 0 -)" 7

BOARD=$("$MG" status 2>/dev/null)
if echo "$BOARD" | grep -q "duties (1)" && echo "$BOARD" | grep -q "due (" && ! echo "$BOARD" | sed -n '/dispatchable/,/in progress/p' | grep -q "DCLAIM"; then
    echo "    PASS: DCLAIM renders in the duties section (due), not dispatchable"
else
    echo "    FAIL: DCLAIM misrendered:"
    echo "$BOARD"
    FAIL=1
fi

OUT=$("$MG" landmark L4 --declare 2>&1); RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "DCLAIM" && echo "$OUT" | grep -q "overdue"; then
    echo "    PASS: landmark refused (rc=$RC) and named DCLAIM as overdue"
else
    echo "    FAIL: landmark did not refuse/naming DCLAIM (rc=$RC): $OUT"
    FAIL=1
fi

# ── Arm C: no duties → declaration succeeds ──────────────────────────────
echo "  C. null: no duties registered → declaration succeeds"

seed_store "" 0

OUT=$("$MG" landmark L2 --declare 2>&1); RC=$?
if [ "$RC" -eq 0 ]; then
    echo "    PASS: landmark declared with no duties (rc=0)"
else
    echo "    FAIL: landmark refused with no duties (rc=$RC): $OUT"
    FAIL=1
fi

# ── Arm D: a duty chunk recorded resets its due-count ────────────────────
echo "  D. null: a duty chunk recorded resets its due-count"

seed_store "$(duty_rec DCLAIM 0 -)" 7

OUT=$("$MG" duty DCLAIM done --verdict pass --findings findings/DCLAIM-2026-08-19.json 2>&1); RC=$?
if [ "$RC" -ne 0 ]; then
    echo "    FAIL: duty done refused (rc=$RC): $OUT"
    FAIL=1
else
    OUT2=$("$MG" landmark L4 --declare 2>&1); RC2=$?
    if [ "$RC2" -eq 0 ]; then
        echo "    PASS: chunk reset due-count; landmark declared (rc=0)"
    else
        echo "    FAIL: chunk did not reset due-count (rc=$RC2): $OUT2"
        FAIL=1
    fi
fi

# ── Arm E: next never hands out a duty ───────────────────────────────────
echo "  E. next never hands out a duty in place of a task"

seed_store "$(duty_rec DCLAIM 0 -)__REC__$(python3 - <<'PY'
import json
print(json.dumps({"TASK1": {
    "status": "dispatchable", "agent": None, "model": None,
    "bundle": "untracked/TASK1.md", "set": "A", "holds": [], "needs": [], "caps": [],
    "added": "2026-08-01T00:00:00Z", "claimed": None, "done": None,
    "dispatched": None, "dispatched_to": None, "note": None,
    "verdict": None, "verdict_note": None, "claim_count": 0,
    "acceptance": None, "skip_acceptance_reason": None, "amendments": [], "epitaph": None,
    "duty": False, "due_after": 5, "last_chunk_closes": 0,
    "last_chunk_ts": None, "last_chunk_verdict": None, "last_chunk_findings": None,
}}))
PY
)" 0
printf '<!--managent set=A deliverables=-->\n# TASK1\n' > untracked/TASK1.md

OUT=$("$MG" next 2>&1); RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "claimed TASK1" && ! echo "$OUT" | grep -q "claimed DCLAIM"; then
    echo "    PASS: next claimed the task, not the duty"
else
    echo "    FAIL: next did not claim TASK1 (or claimed DCLAIM): $OUT"
    FAIL=1
fi

# Duty-only store: next must claim nothing.
seed_store "$(duty_rec DCLAIM 0 -)" 0
OUT2=$("$MG" next 2>&1); RC2=$?
if [ "$RC2" -eq 0 ] && ! echo "$OUT2" | grep -q "claimed"; then
    echo "    PASS: next refused to hand out a lone duty"
else
    echo "    FAIL: next handed out a duty: $OUT2"
    FAIL=1
fi

# ── Arm F: last chunk failed blocks a landmark even when not due ─────────
echo "  F. seeded: last chunk failed blocks a landmark (even when not due)"

seed_store "$(duty_rec DCLAIM 0 fail)" 0

OUT=$("$MG" landmark L2 --declare 2>&1); RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "DCLAIM" && echo "$OUT" | grep -q "last chunk failed"; then
    echo "    PASS: landmark refused, names last-chunk-failed DCLAIM"
else
    echo "    FAIL: last-chunk-failed did not block (rc=$RC): $OUT"
    FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "  T478 duty mechanism: ALL CHECKS PASS"
else
    echo "  T478 duty mechanism: SOME CHECKS FAILED"
fi
exit "$FAIL"
