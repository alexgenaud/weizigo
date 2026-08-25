#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# tools/regression-kill-history.sh — T798: kills visible in the kanban
# ═══════════════════════════════════════════════════════════════════════════════
# Controls:
#   1. Seeded: fixture task + run record with kill -> close records it, verdict
#      unchanged, status shows attempt count and kill count.
#   2. Seeded: fixture with empty verdict note over a kill -> close REFUSED.
#   3. Null: task with clean attempt (no kills) -> rendering in status unchanged.
#   4. Idempotence: backfill-kills applied twice is a no-op (byte-identical).
#   5. Missing records: task whose run records are missing renders UNKNOWN, not 0.
#   6. One door: lanes --backfill extracts model from findings JSON, or sets
#      unattributed with explicit reason (never silent null).
# ═══════════════════════════════════════════════════════════════════════════════

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
FAIL=0

cleanup() { [ -n "${WORK:-}" ] && rm -rf "$WORK"; }
trap cleanup EXIT

. "$PROJECT/tools/lib/scratch-repo.sh"
weizigo_scratch_repo t798-kill-history WORK
cd "$WORK"
git config user.email t798@test
git config user.name T798
mkdir -p docs/infra/managent untracked untracked/runs bin findings
printf 'untracked/\n' > .gitignore
echo base > README.md
git add README.md .gitignore
git commit -qm base

# managent and claimlint binary resolution
MG="${MANAGENT_BIN:-}"
if [ -z "$MG" ]; then
    if [ -x "$PROJECT/zig-out/bin/managent" ]; then
        MG="$PROJECT/zig-out/bin/managent"
    elif [ -x "$PROJECT/bin/managent" ]; then
        MG="$PROJECT/bin/managent"
    else
        echo "FAIL: managent binary not found (run zig build)" >&2
        exit 1
    fi
fi

GATE_CL="$PROJECT/zig-out/bin/weizigo-claimlint"
[ -x "$GATE_CL" ] || GATE_CL="$PROJECT/bin/weizigo-claimlint"
if [ ! -x "$GATE_CL" ]; then
    echo "SKIP: no weizigo-claimlint binary (build with 'zig build')"
    exit 0
fi

cp "$GATE_CL" "$WORK/bin/weizigo-claimlint"
mkdir -p "$WORK/docs/epistemic"
cat > "$WORK/docs/epistemic/CLAIMS.md" <<'MDEOF'
# scratch register — T798 kill-history control

## 2. The register

| ID | legacy | goban | claim | status | evidence | depends-on | dependents | narrowed | wrong-answer-pass-rate | tree |
|---|---|---|---|---|---|---|---|---|---|---|
MDEOF
git add "$WORK/docs/epistemic/CLAIMS.md"
git commit -qm "add scratch register"

export MANAGENT_TEST=1
export MANAGENT_STORE="$WORK/docs/infra/managent/tasks.json"

echo "=== T798: kills visible in the kanban regression ==="

# ── 1. Seeded: close records kill, verdict unchanged, status shows attempts ────
echo " 1. seeded: close over killed attempt records attempt history & shows in status"
C1_OK=1

# Initialize empty store
echo "{}" > "$MANAGENT_STORE"

cat << 'EOF' > "$WORK/untracked/T1001-test.md"
<!--managent set=A type=infra acceptance=true holds= deliverables=findings/T1001-test.json-->
# T1001 — test task
**Landmark:** none directly; unblocks regression fixture
EOF

# Register task T1001
"$MG" add T1001 --bundle untracked/T1001-test.md --type infra >/dev/null

# Claim task T1001
"$MG" claim T1001 --agent deepseek-v4-pro >/dev/null

# Create run records for T1001: attempt 1 (killed by wall), attempt 2 (clean pass)
cat << 'EOF' > "$WORK/untracked/runs/T1001.1.json"
{"task": "T1001", "attempt": 1, "model": "deepseek-v4-pro", "start": "2026-08-25T01:00:00Z", "wall": 120.5, "exit": 124, "signal": 9, "killed_by": "wall", "killed": "wall ceiling 120s reached"}
EOF

cat << 'EOF' > "$WORK/untracked/runs/T1001.json"
{"task": "T1001", "attempt": 2, "model": "deepseek-v4-pro", "start": "2026-08-25T02:00:00Z", "wall": 45.2, "exit": 0, "killed_by": "none"}
EOF

# Write deliverable
echo '{"task_id":"T1001","claims":[],"new_rows":[],"model":"deepseek-v4-pro","date":"2026-08-25"}' > "$WORK/findings/T1001-test.json"
git add "$WORK/findings/T1001-test.json"
git commit -qm "deliverable for T1001"

# Close with note
CLOSE_OUT=$("$MG" done T1001 --status pass --agent deepseek-v4-pro --note "passed on retry after wall ceiling" --impression "good retry" --force 2>&1 || true)

# Assert verdict is pass
T1001_VERDICT=$(python3 -c "import json; print(json.load(open('$MANAGENT_STORE'))['T1001']['verdict'])" 2>/dev/null || echo "MISSING")
if [ "$T1001_VERDICT" != "pass" ]; then
    echo "    FAIL: verdict is $T1001_VERDICT (expected pass)"
    C1_OK=0
fi

# Assert attempts recorded in tasks.json
T1001_ATTS=$(python3 -c "import json; d=json.load(open('$MANAGENT_STORE'))['T1001'].get('attempts'); print(len(d) if d else 0)" 2>/dev/null || echo "0")
if [ "$T1001_ATTS" != "2" ]; then
    echo "    FAIL: attempts count in tasks.json is $T1001_ATTS (expected 2)"
    C1_OK=0
fi

# Assert status shows attempt count and kill count
STATUS_OUT=$("$MG" status 2>&1)
if echo "$STATUS_OUT" | grep "T1001" | grep -q "verdict=pass (attempt 2, 1 killed)"; then
    :
else
    echo "    FAIL: status does not show (attempt 2, 1 killed). Output:"
    echo "$STATUS_OUT" | grep "T1001" || echo "    (T1001 missing from status)"
    C1_OK=0
fi

# Assert show shows attempts list
SHOW_OUT=$("$MG" show T1001 2>&1)
if echo "$SHOW_OUT" | grep -q "attempts: 2 (1 killed)"; then
    :
else
    echo "    FAIL: show does not show 'attempts: 2 (1 killed)'"
    C1_OK=0
fi

[ "$C1_OK" -eq 1 ] && echo "    PASS: close records kill, verdict stands, status & show reflect attempt history" || FAIL=1


# ── 2. Seeded: empty verdict note over killed attempt is REFUSED ───────────────
echo " 2. seeded: empty verdict note over killed attempt is refused"
C2_OK=1

cat << 'EOF' > "$WORK/untracked/T1002-test.md"
<!--managent set=A type=infra acceptance=true holds= deliverables=findings/T1002-test.json-->
# T1002 — test task 2
**Landmark:** none directly; unblocks regression fixture
EOF

"$MG" add T1002 --bundle untracked/T1002-test.md --type infra >/dev/null
"$MG" claim T1002 --agent deepseek-v4-pro >/dev/null

cat << 'EOF' > "$WORK/untracked/runs/T1002.1.json"
{"task": "T1002", "attempt": 1, "model": "deepseek-v4-pro", "start": "2026-08-25T01:00:00Z", "wall": 50.0, "exit": 124, "signal": 9, "killed_by": "rss", "killed": "rss cap exceeded"}
EOF

cat << 'EOF' > "$WORK/untracked/runs/T1002.json"
{"task": "T1002", "attempt": 2, "model": "deepseek-v4-pro", "start": "2026-08-25T02:00:00Z", "wall": 20.0, "exit": 0, "killed_by": "none"}
EOF

echo '{"task_id":"T1002","claims":[],"new_rows":[],"model":"deepseek-v4-pro","date":"2026-08-25"}' > "$WORK/findings/T1002-test.json"
git add "$WORK/findings/T1002-test.json"
git commit -qm "deliverable for T1002"

# Close without note -> must fail
C2_ERR=$("$MG" done T1002 --status pass --agent deepseek-v4-pro --impression "ok" --force 2>&1 || true)

if echo "$C2_ERR" | grep -q "REJECTED: T1002 has .* killed attempt"; then
    :
else
    echo "    FAIL: done did not refuse empty note over kill. Output:"
    echo "$C2_ERR"
    C2_OK=0
fi

# Ensure T1002 status is still in_progress
T1002_STATUS=$(python3 -c "import json; print(json.load(open('$MANAGENT_STORE'))['T1002']['status'])" 2>/dev/null || echo "MISSING")
if [ "$T1002_STATUS" != "in_progress" ]; then
    echo "    FAIL: T1002 status is $T1002_STATUS (expected in_progress)"
    C2_OK=0
fi

[ "$C2_OK" -eq 1 ] && echo "    PASS: empty verdict note over killed attempt is refused" || FAIL=1


# ── 3. Null control: clean attempt gains no kill fields, rendering unchanged ───
echo " 3. null: task with no killed attempt leaves status rendering unchanged"
C3_OK=1

cat << 'EOF' > "$WORK/untracked/T1003-test.md"
<!--managent set=A type=infra acceptance=true holds= deliverables=findings/T1003-test.json-->
# T1003 — clean test task
**Landmark:** none directly; unblocks regression fixture
EOF

"$MG" add T1003 --bundle untracked/T1003-test.md --type infra >/dev/null
"$MG" claim T1003 --agent deepseek-v4-pro >/dev/null

cat << 'EOF' > "$WORK/untracked/runs/T1003.json"
{"task": "T1003", "attempt": 1, "model": "deepseek-v4-pro", "start": "2026-08-25T01:00:00Z", "wall": 25.0, "exit": 0, "killed_by": "none"}
EOF

echo '{"task_id":"T1003","claims":[],"new_rows":[],"model":"deepseek-v4-pro","date":"2026-08-25"}' > "$WORK/findings/T1003-test.json"
git add "$WORK/findings/T1003-test.json"
git commit -qm "deliverable for T1003"

"$MG" done T1003 --status pass --agent deepseek-v4-pro --impression "clean pass" --force >/dev/null 2>&1

STATUS_OUT3=$("$MG" status 2>&1)
T1003_LINE=$(echo "$STATUS_OUT3" | grep "T1003")

# Must have verdict=pass and NOT have "(attempt" or "killed"
if echo "$T1003_LINE" | grep -q "verdict=pass" && ! echo "$T1003_LINE" | grep -q "attempt"; then
    :
else
    echo "    FAIL: status line for clean task was modified: $T1003_LINE"
    C3_OK=0
fi

[ "$C3_OK" -eq 1 ] && echo "    PASS: clean task status rendering unchanged" || FAIL=1


# ── 4. Idempotence: backfill applied twice produces identical store ───────────
echo " 4. idempotence: backfill-kills is idempotent"
C4_OK=1

cat << 'EOF' > "$WORK/untracked/T1004-test.md"
<!--managent set=A type=infra acceptance=true holds= deliverables=findings/T1004-test.json-->
# T1004 — backfill test task
**Landmark:** none directly; unblocks regression fixture
EOF
"$MG" add T1004 --bundle untracked/T1004-test.md --type infra >/dev/null
cat << 'EOF' > "$WORK/untracked/runs/T1004.1.json"
{"task": "T1004", "attempt": 1, "model": "claude-opus-5", "start": "2026-08-25T01:00:00Z", "wall": 100.0, "exit": 124, "signal": 9, "killed_by": "wall"}
EOF
cat << 'EOF' > "$WORK/untracked/runs/T1004.json"
{"task": "T1004", "attempt": 2, "model": "claude-opus-5", "start": "2026-08-25T02:00:00Z", "wall": 30.0, "exit": 0, "killed_by": "none"}
EOF

# Run backfill once
"$MG" backfill-kills >/dev/null 2>&1
STORE_SNAP1=$(cat "$MANAGENT_STORE")

# Run backfill twice
"$MG" backfill-kills >/dev/null 2>&1
STORE_SNAP2=$(cat "$MANAGENT_STORE")

if [ "$STORE_SNAP1" = "$STORE_SNAP2" ]; then
    :
else
    echo "    FAIL: store changed on second backfill run"
    C4_OK=0
fi

[ "$C4_OK" -eq 1 ] && echo "    PASS: backfill-kills is idempotent" || FAIL=1


# ── 5. Missing run records render UNKNOWN, not zero ────────────────────────────
echo " 5. missing records: a task with no run records renders UNKNOWN"
C5_OK=1

cat << 'EOF' > "$WORK/untracked/T1005-test.md"
<!--managent set=A type=infra acceptance=true holds= deliverables=findings/T1005-test.json-->
# T1005 — no records task
**Landmark:** none directly; unblocks regression fixture
EOF
"$MG" add T1005 --bundle untracked/T1005-test.md --type infra >/dev/null

SHOW_OUT5=$("$MG" show T1005 2>&1)
if echo "$SHOW_OUT5" | grep -q "attempts: UNKNOWN"; then
    :
else
    echo "    FAIL: show did not output 'attempts: UNKNOWN'. Output:"
    echo "$SHOW_OUT5"
    C5_OK=0
fi

[ "$C5_OK" -eq 1 ] && echo "    PASS: missing run records render attempts: UNKNOWN" || FAIL=1


# ── 6. One door: lanes --backfill model attribution ───────────────────────────
echo " 6. one door: lanes --backfill captures model or explicit unknown reason"
C6_OK=1

# Fixture with model
cat << 'EOF' > "$WORK/findings/T1006-with-model.json"
{
  "task_id": "T1006",
  "claims": [],
  "new_rows": [],
  "model": "deepseek-v4-pro",
  "date": "2026-08-25"
}
EOF

# Fixture without model
cat << 'EOF' > "$WORK/findings/T1007-no-model.json"
{
  "task_id": "T1007",
  "claims": [],
  "new_rows": [],
  "date": "2026-08-25"
}
EOF

"$MG" lanes --backfill T1006 T1007 >/dev/null 2>&1

T1006_MODEL=$(python3 -c "import json; print(json.load(open('$MANAGENT_STORE'))['T1006']['model'])" 2>/dev/null || echo "MISSING")
T1006_SRC=$(python3 -c "import json; print(json.load(open('$MANAGENT_STORE'))['T1006']['model_source'])" 2>/dev/null || echo "MISSING")
if [ "$T1006_MODEL" != "deepseek-v4-pro" ] || [ "$T1006_SRC" != "findings" ]; then
    echo "    FAIL: T1006 model=$T1006_MODEL source=$T1006_SRC (expected deepseek-v4-pro / findings)"
    C6_OK=0
fi

T1007_MODEL=$(python3 -c "import json; print(json.load(open('$MANAGENT_STORE'))['T1007']['model'])" 2>/dev/null || echo "MISSING")
T1007_MUR=$(python3 -c "import json; print(json.load(open('$MANAGENT_STORE'))['T1007']['model_unknown_reason'])" 2>/dev/null || echo "MISSING")
if [ "$T1007_MODEL" != "unattributed" ] || [ -z "$T1007_MUR" ] || [ "$T1007_MUR" = "None" ]; then
    echo "    FAIL: T1007 model=$T1007_MODEL mur=$T1007_MUR (expected unattributed / non-empty reason)"
    C6_OK=0
fi

[ "$C6_OK" -eq 1 ] && echo "    PASS: lanes --backfill properly attributes model or explicit reason" || FAIL=1


# ── Final result ───────────────────────────────────────────────────────────────
if [ "$FAIL" -eq 0 ]; then
    echo "ALL CONTROLS PASSED."
    exit 0
else
    echo "REGRESSION FAILED."
    exit 1
fi
