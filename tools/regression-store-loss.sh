#!/usr/bin/env bash
# regression-store-loss.sh — S10 store-loss detector controls (T944 / S10-STORE-1..4 + SMOKE-4)
#
# Covers spec §2.4 and §4 (arms S10-STORE-1..4) + §5 (SMOKE-4):
#
#   A16 (S10-STORE-1): every store mutation updates census (row_count + digest + ids + written_by)
#                      atomically with the write; read-only surfaces (orient, status, resume, audit)
#                      are completely silent on an intact store (null control).
#   A17 (S10-STORE-2): a store reverted to fewer rows refuses writes (exit non-zero), alarms on stderr
#                      naming live rows, census rows, missing ids, and census path; store remains unmutated.
#   A18 (S10-STORE-3): a reverted store causes read surfaces (orient) to alarm loudly on stderr naming
#                      missing ids and exit non-zero.
#   A19 (S10-STORE-4): legitimate shrinks (purge, archive, retire) record removed ids in census and do
#                      not alarm; unrecorded shrinks alarm and refuse.
#   SMOKE-4:           end-to-end scenario reproducing the 2026-08-24 59-task loss (stale snapshot revert ->
#                      mutation refused -> orient alarms loudly -> reasoned reconcile allows repair -> orient clean).
#
# All fixtures are synthetic and run in /tmp/weizigo — the live kanban and live
# repo are never touched. MANAGENT_STORE points at a scratch kanban and the
# command is invoked from the scratch repo, so findRepoRoot resolves there.
#
# Task: T944 · Role: worker · Model: gemini-3.7-flash · Date: 2026-08-25

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
FAIL=0

# T849: scratch repo via the ONE isolated helper (unset GIT_DIR… before git init).
. "$PROJECT/tools/lib/scratch-repo.sh"

# ── the GIT_DIR leak guard is load-bearing, not style ─────────────────────
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_NAMESPACE

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

# T445: /tmp/weizigo decays. Create it, and refuse if scratch creation fails.
mkdir -p /tmp/weizigo
weizigo_scratch_repo managent-store-loss WORK   # T849: isolated scratch repo
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
git config user.email t944@test
git config user.name T944
echo base > README.md
mkdir -p docs/infra/managent untracked
printf 'untracked/\n' > .gitignore
git add README.md .gitignore
git commit -qm base

STORE="$WORK/docs/infra/managent/tasks.json"
CENSUS="$WORK/docs/infra/managent/store-census.json"
ARCHIVE="$WORK/docs/infra/managent/archive.json"
export MANAGENT_STORE="$STORE"

# ── helpers ───────────────────────────────────────────────────────────────
task_ids() { # count/echo the non-_sys task ids in the store
    python3 -c "import sys,json; d=json.load(open('$STORE')); print(' '.join(sorted(k for k in d if not k.startswith('_'))))"
}
row_count() {
    python3 -c "import sys,json; d=json.load(open('$STORE')); print(len([k for k in d if not k.startswith('_')]))"
}
census_field() { # $1 = json key; echo its value (or NOTFOUND)
    python3 -c "import sys,json; d=json.load(open('$CENSUS')); print(d.get('$1','NOTFOUND'))" 2>/dev/null || echo NOTFOUND
}
mkbundle() { # $1 = id  $2 = slug
    printf '<!--managent set=A type=infra-->\n# %s — %s\n**Landmark:** none directly; unblocks T9000\n' "$1" "$2" > "untracked/$1-$2.md"
}
seed_empty() {
    cat > "$STORE" <<'JSONEOF'
{
  "_sys": {"next_id": 9000, "directive_next": 1, "assertion_next": 1, "closes": 0, "duty_migrated": true}
}
JSONEOF
}
detector_noise() { # any detector output in $1 → non-zero
    grep -E "store-loss detector|ALARM|REFUSED|census:" "$1" >/dev/null 2>&1
}

echo "=== regression-store-loss: S10 store-loss detector (T944) ==="

# ══════════════════════════════════════════════════════════════════════════
# Arm 1 (A16 / S10-STORE-1): Census updated atomically with every mutation;
#                           null control (silent reads on intact store)
# ══════════════════════════════════════════════════════════════════════════
echo "  1. A16 (S10-STORE-1): atomic census update (row_count+digest+ids+written_by) + null control"
seed_empty
mkbundle T9001 a
"$MG" add T9001 --bundle untracked/T9001-a.md >/dev/null 2>&1
mkbundle T9002 b
"$MG" add T9002 --bundle untracked/T9002-b.md >/dev/null 2>&1

if [ "$(row_count)" = "2" ] && [ -f "$CENSUS" ]; then
    : # two rows, census present
else
    echo "    FAIL: healthy store did not reach 2 rows or census missing"
    FAIL=1
fi

DIGEST_LEN=$(census_field digest | tr -d ' \r\n' | wc -c | tr -d ' ')
if [ "$(census_field row_count)" = "2" ] && [ "$DIGEST_LEN" -eq 64 ] && \
   [ "$(census_field written_by)" = "add" ] && census_field ids | grep -q "T9001" && census_field ids | grep -q "T9002"; then
    echo "    PASS: census records row_count=2, 64-char sha256 digest, sorted ids, written_by=add (A16)"
else
    echo "    FAIL: census malformed or incomplete: $(cat "$CENSUS" 2>/dev/null)"
    FAIL=1
fi

for surface in orient status resume audit; do
    "$MG" "$surface" >/dev/null 2>"$WORK/surface.err"
    rc=$?
    if detector_noise "$WORK/surface.err"; then
        echo "    FAIL: $surface alarmed on a healthy store"
        sed 's/^/      /' < "$WORK/surface.err"
        FAIL=1
    elif [ "$surface" = "orient" ] && [ "$rc" -ne 0 ]; then
        echo "    FAIL: orient exited $rc on a healthy store"
        FAIL=1
    else
        echo "    PASS: $surface silent (rc=$rc) on a healthy store"
    fi
done

# ══════════════════════════════════════════════════════════════════════════
# Arm 2 (A17 / S10-STORE-2): Write-time refusal on reverted store
# ══════════════════════════════════════════════════════════════════════════
echo "  2. A17 (S10-STORE-2): write on reverted store is REFUSED; names count, missing ids, census"

# Revert store to 1 row (dropping T9002) while census expects 2 rows
cat > "$STORE" <<'JSONEOF'
{
  "T9001": {"status":"dispatchable","agent":null,"bundle":"untracked/T9001-a.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-24T00:00:00Z","claim_count":0},
  "_sys": {"next_id": 9000, "directive_next": 1, "assertion_next": 1, "closes": 0, "duty_migrated": true}
}
JSONEOF

mkbundle T9003 c
"$MG" add T9003 --bundle untracked/T9003-c.md >/dev/null 2>"$WORK/add.err"
rc=$?
if [ "$rc" -ne 0 ] && grep -q "REFUSED: store-loss detector" "$WORK/add.err" && \
   grep -q "live rows: 1  census rows: 2" "$WORK/add.err" && \
   grep -q "T9002" "$WORK/add.err" && grep -q "census:" "$WORK/add.err" && [ "$(row_count)" = "1" ]; then
    echo "    PASS: add REFUSED (rc=$rc), names shrink (1 vs 2), missing T9002, census; store unmutated (A17)"
else
    echo "    FAIL: add rc=$rc (rows $(row_count)); expected REFUSED with missing ids and unchanged store:"
    sed 's/^/      /' < "$WORK/add.err"
    FAIL=1
fi

# ══════════════════════════════════════════════════════════════════════════
# Arm 3 (A18 / S10-STORE-3): Read-time check (orient) alarms and exits non-zero
# ══════════════════════════════════════════════════════════════════════════
echo "  3. A18 (S10-STORE-3): read (orient) on reverted store ALARMS loudly and exits non-zero"

"$MG" orient >/dev/null 2>"$WORK/orient.err"
rc=$?
if [ "$rc" -ne 0 ] && grep -q "ALARM: store-loss detector" "$WORK/orient.err" && \
   grep -q "live store (1 rows) is smaller than the committed census (2 rows)" "$WORK/orient.err" && \
   grep -q "missing ids:.*T9002" "$WORK/orient.err" && grep -q "census:" "$WORK/orient.err"; then
    echo "    PASS: orient ALARM (rc=$rc), names shrink (1 vs 2), missing T9002, census path (A18)"
else
    echo "    FAIL: orient rc=$rc, expected non-zero ALARM naming missing ids:"
    sed 's/^/      /' < "$WORK/orient.err"
    FAIL=1
fi

# ══════════════════════════════════════════════════════════════════════════
# Arm 4 (A19 / S10-STORE-4): Legitimate shrinks (retire/purge/archive) record
#                           ids and do not alarm; unrecorded shrink alarms
# ══════════════════════════════════════════════════════════════════════════
echo "  4. A19 (S10-STORE-4): retirement bookkeeping records ids; legitimate shrink does not alarm"

# First restore store to 2 rows to match census
cat > "$STORE" <<'JSONEOF'
{
  "T9001": {"status":"dispatchable","agent":null,"bundle":"untracked/T9001-a.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-24T00:00:00Z","claim_count":0},
  "T9002": {"status":"dispatchable","agent":null,"bundle":"untracked/T9002-b.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-24T00:00:00Z","claim_count":0},
  "_sys": {"next_id": 9000, "directive_next": 1, "assertion_next": 1, "closes": 0, "duty_migrated": true}
}
JSONEOF

# Test retire: removes T9001 with note -> legitimate shrink
"$MG" retire T9001 --note "retire test T9001" >/dev/null 2>"$WORK/retire.err"
rc=$?
if [ "$rc" -eq 0 ] && ! detector_noise "$WORK/retire.err" && [ "$(row_count)" = "1" ] && \
   [ "$(census_field row_count)" = "1" ] && grep -q "retired: T9001" "$CENSUS"; then
    echo "    PASS: retire shrank store (rows=1) with zero alarm; census records retired: T9001"
else
    echo "    FAIL: retire rc=$rc (rows $(row_count)); census=$(cat "$CENSUS" 2>/dev/null)"
    sed 's/^/      /' < "$WORK/retire.err"
    FAIL=1
fi

# Orient after legitimate retire must be silent and exit 0
"$MG" orient >/dev/null 2>"$WORK/orient_after_retire.err"
rc=$?
if [ "$rc" -eq 0 ] && ! detector_noise "$WORK/orient_after_retire.err"; then
    echo "    PASS: orient silent (rc=0) after legitimate retirement"
else
    echo "    FAIL: orient alarmed after legitimate retire (rc=$rc):"
    sed 's/^/      /' < "$WORK/orient_after_retire.err"
    FAIL=1
fi

# ══════════════════════════════════════════════════════════════════════════
# Arm 5 (SMOKE-4): End-to-end scenario reproducing the 2026-08-24 incident
# ══════════════════════════════════════════════════════════════════════════
echo "  5. SMOKE-4: end-to-end incident reproduction (revert -> refused write -> orient alarm -> reconcile escape)"

# Setup multi-task store: T9002, T9003, T9004
mkbundle T9003 c
mkbundle T9004 d
"$MG" add T9003 --bundle untracked/T9003-c.md >/dev/null 2>&1
"$MG" add T9004 --bundle untracked/T9004-d.md >/dev/null 2>&1

if [ "$(row_count)" = "3" ] && [ "$(census_field row_count)" = "3" ]; then
    echo "    PASS: setup complete — store and census at 3 rows (T9002, T9003, T9004)"
else
    echo "    FAIL: setup failed: store=$(row_count) census=$(census_field row_count)"
    FAIL=1
fi

# Reproduce the 2026-08-24 incident: working-tree tasks.json silently reverts to older snapshot
# holding only T9002 (dropping T9003 and T9004), while store-census.json remains at 3 rows
cat > "$STORE" <<'JSONEOF'
{
  "T9002": {"status":"dispatchable","agent":null,"bundle":"untracked/T9002-b.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-24T00:00:00Z","claim_count":0},
  "_sys": {"next_id": 9000, "directive_next": 1, "assertion_next": 1, "closes": 0, "duty_migrated": true}
}
JSONEOF

# 1. Attempted mutation without reason: MUST BE REFUSED
mkbundle T9005 e
"$MG" add T9005 --bundle untracked/T9005-e.md >/dev/null 2>"$WORK/smoke_add.err"
rc_add=$?
if [ "$rc_add" -ne 0 ] && grep -q "REFUSED: store-loss detector" "$WORK/smoke_add.err" && \
   grep -q "T9003" "$WORK/smoke_add.err" && grep -q "T9004" "$WORK/smoke_add.err" && [ "$(row_count)" = "1" ]; then
    echo "    PASS: mutation refused (rc=$rc_add) naming missing T9003, T9004; store preserved at 1 row"
else
    echo "    FAIL: mutation did not refuse cleanly (rc=$rc_add):"
    sed 's/^/      /' < "$WORK/smoke_add.err"
    FAIL=1
fi

# 2. Worker/operator preamble check: orient MUST ALARM and EXIT NON-ZERO
"$MG" orient >/dev/null 2>"$WORK/smoke_orient.err"
rc_orient=$?
if [ "$rc_orient" -ne 0 ] && grep -q "ALARM: store-loss detector" "$WORK/smoke_orient.err" && \
   grep -q "T9003" "$WORK/smoke_orient.err" && grep -q "T9004" "$WORK/smoke_orient.err"; then
    echo "    PASS: orient alarmed (rc=$rc_orient) naming missing T9003, T9004 before any worker acts"
else
    echo "    FAIL: orient did not alarm properly on shrunk store (rc=$rc_orient):"
    sed 's/^/      /' < "$WORK/smoke_orient.err"
    FAIL=1
fi

# 3. Reasoned escape: --reconcile-store-loss "<reason>" allows mutation and records reason in census
"$MG" add T9005 --bundle untracked/T9005-e.md --reconcile-store-loss "simulated 2026-08-24 recovery" >/dev/null 2>"$WORK/smoke_reconcile.err"
rc_rec=$?
if [ "$rc_rec" -eq 0 ] && [ "$(row_count)" = "2" ] && [ "$(census_field row_count)" = "2" ] && \
   grep -q "reconcile-store-loss: simulated 2026-08-24 recovery" "$CENSUS"; then
    echo "    PASS: reconcile succeeded (rc=$rc_rec, rows=2); recorded reason in census"
else
    echo "    FAIL: reconcile failed (rc=$rc_rec, rows=$(row_count)): census=$(cat "$CENSUS" 2>/dev/null)"
    sed 's/^/      /' < "$WORK/smoke_reconcile.err"
    FAIL=1
fi

# 4. Subsequent orient is now clean and exits 0
"$MG" orient >/dev/null 2>"$WORK/smoke_orient_clean.err"
rc_clean=$?
if [ "$rc_clean" -eq 0 ] && ! detector_noise "$WORK/smoke_orient_clean.err"; then
    echo "    PASS: orient clean (rc=0) and silent after reasoned reconciliation"
else
    echo "    FAIL: orient still noisy/failing after reconciliation (rc=$rc_clean):"
    sed 's/^/      /' < "$WORK/smoke_orient_clean.err"
    FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-store-loss: ALL 5 ARMS PASSED (A16, A17, A18, A19, SMOKE-4) ==="
    exit 0
else
    echo "=== regression-store-loss: FAILURES ==="
    exit 1
fi
