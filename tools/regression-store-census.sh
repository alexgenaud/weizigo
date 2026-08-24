#!/usr/bin/env bash
# regression-store-census.sh — S10 store-loss detector controls (T848)
#
# Four arms, each shown red first then green (see findings/T848-store-loss-detector.json):
#
#   1. null control          a healthy, unchanged store produces NO alarm on any
#                            read-only surface (orient/status/resume/audit) and
#                            every store write updates the census (row_count +
#                            digest + ids + written_by) in the same wave.
#   2. seeded-defect control hand-revert a scratch store to a snapshot with fewer
#                            rows; prove the write-time check REFUSES (naming the
#                            count, the missing ids, and the census) and the
#                            read-time check ALARMS (orient exits non-zero).
#   3. legitimate-shrink     a recorded retirement (retire, the single-row archive
#                            — same retiring_ids path as purge/archive) shrinks the
#                            store and alarms NOTHING; the census updates to match.
#   4. escape control        --reconcile-store-loss "<reason>" records the reason
#                            and proceeds (the reasoned-bypass discipline).
#
# All fixtures are synthetic and run in /tmp/weizigo — the live kanban and live
# repo are never touched.  MANAGENT_STORE points at a scratch kanban and the
# command is invoked from the scratch repo, so findRepoRoot resolves there.
#
# T848 (S10 pass 1): the pre-commit hook unsets GIT_DIR for its own child git
# processes, but this script must NOT rely on that being true elsewhere — a
# hook-invoked child that git-inits without unsetting the leaked GIT_DIR is the
# mechanism that caused the 2026-08-24 59-task loss.  Unset every git redirect
# here, before any git init, unconditionally.
#
# Task: T848 · Role: worker · Model: deepseek-v4-pro · Date: 2026-08-24

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
FAIL=0

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

# T445: /tmp/weizigo decays.  Create it, and REFUSE to run if scratch creation
# fails — cd "" succeeds silently and once sent a suite's arms into the LIVE
# repo (2026-08-18 incident).  Never rely on an empty scratch var.
mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/managent-store-census-XXXXXX)" || { echo "regression-store-census.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
git init -q
git config user.email t848@test
git config user.name T848
echo base > README.md
mkdir -p docs/infra/managent untracked
printf 'untracked/\n' > .gitignore
git add README.md .gitignore
git commit -qm base

STORE="$WORK/docs/infra/managent/tasks.json"
CENSUS="$WORK/docs/infra/managent/store-census.json"
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
    printf '<!--managent set=A-->\n# %s — %s\n**Landmark:** none directly; unblocks T9000\n' "$1" "$2" > "untracked/$1-$2.md"
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

echo "=== regression-store-census: S10 store-loss detector (T848) ==="

# ══════════════════════════════════════════════════════════════════════════
# Arm 1 — null control: a healthy store alarms nothing; writes update the census
# ══════════════════════════════════════════════════════════════════════════
echo "  1. null control: healthy store → no alarm on any read surface; census tracks every write"
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
# A16: the census carries count + digest + ids + written_by, updated with the write.
if [ "$(census_field row_count)" = "2" ] && [ "$(census_field digest | wc -c | tr -d ' ')" -gt 40 ] && \
   [ "$(census_field written_by)" = "add" ] && census_field ids | grep -q "T9001" && census_field ids | grep -q "T9002"; then
    echo "    PASS: census records row_count=2 + digest + ids + written_by=add (A16)"
else
    echo "    FAIL: census malformed: $(cat "$CENSUS")"
    FAIL=1
fi

for surface in orient status resume audit; do
    "$MG" "$surface" >/dev/null 2>"$WORK/surface.err"
    rc=$?
    if detector_noise "$WORK/surface.err"; then
        echo "    FAIL: $surface alarmed on a healthy store"
        cat "$WORK/surface.err" | sed 's/^/      /'
        FAIL=1
    elif [ "$surface" = "orient" ] && [ "$rc" -ne 0 ]; then
        echo "    FAIL: orient exited $rc on a healthy store"
        FAIL=1
    else
        echo "    PASS: $surface silent (rc=$rc) on a healthy store"
    fi
done

# ══════════════════════════════════════════════════════════════════════════
# Arm 2 — seeded-defect control: a reverted store refuses writes and alarms reads
# ══════════════════════════════════════════════════════════════════════════
echo "  2. seeded-defect control: reverted store → write REFUSED, read ALARM (names missing ids)"

# Hand-revert the store to a snapshot with fewer rows (the 59-task failure shape).
cat > "$STORE" <<'JSONEOF'
{
  "T9001": {"status":"dispatchable","agent":null,"bundle":"untracked/T9001-a.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-24T00:00:00Z","claim_count":0},
  "_sys": {"next_id": 9000, "directive_next": 1, "assertion_next": 1, "closes": 0, "duty_migrated": true}
}
JSONEOF

# Read-time: orient must alarm on stderr and exit non-zero (A18).
"$MG" orient >/dev/null 2>"$WORK/orient.err"
rc=$?
if [ "$rc" -ne 0 ] && grep -q "ALARM" "$WORK/orient.err" && grep -q "store-loss detector" "$WORK/orient.err" && \
   grep -q "T9002" "$WORK/orient.err" && grep -q "census:" "$WORK/orient.err"; then
    echo "    PASS: orient alarmed (rc=$rc) naming T9002 + census path (A18)"
else
    echo "    FAIL: orient rc=$rc, expected ALARM naming T9002:"
    cat "$WORK/orient.err" | sed 's/^/      /'
    FAIL=1
fi

# Write-time: a mutation must refuse, name the missing ids + census, and not write (A17).
mkbundle T9003 c
"$MG" add T9003 --bundle untracked/T9003-c.md >/dev/null 2>"$WORK/add.err"
rc=$?
if [ "$rc" -ne 0 ] && grep -q "REFUSED" "$WORK/add.err" && grep -q "store-loss detector" "$WORK/add.err" && \
   grep -q "T9002" "$WORK/add.err" && grep -q "census:" "$WORK/add.err" && [ "$(row_count)" = "1" ]; then
    echo "    PASS: add refused (rc=$rc) naming T9002 + census; store still 1 row (A17)"
else
    echo "    FAIL: add rc=$rc (rows now $(row_count)); expected REFUSED with store unchanged:"
    cat "$WORK/add.err" | sed 's/^/      /'
    FAIL=1
fi

# ══════════════════════════════════════════════════════════════════════════
# Arm 3 — escape control: the reasoned escape records its reason and proceeds
# ══════════════════════════════════════════════════════════════════════════
echo "  3. escape control: --reconcile-store-loss \"<reason>\" records the reason and proceeds"
"$MG" add T9003 --bundle untracked/T9003-c.md --reconcile-store-loss "T9002 lost to a test revert" >/dev/null 2>"$WORK/esc.err"
rc=$?
if [ "$rc" -eq 0 ] && [ "$(row_count)" = "2" ] && grep -q "reconcile-store-loss: T9002 lost to a test revert" "$CENSUS"; then
    echo "    PASS: escape proceeded (rows=2) and recorded the reason in the census"
else
    echo "    FAIL: escape rc=$rc (rows $(row_count)); census=$(cat "$CENSUS")"
    FAIL=1
fi

# ══════════════════════════════════════════════════════════════════════════
# Arm 4 — legitimate-shrink control: a recorded retirement alarms nothing
# ══════════════════════════════════════════════════════════════════════════
echo "  4. legitimate-shrink control: retire records its id → no alarm, census updates (A19)"
"$MG" retire T9001 --note "synthetic T848 retirement" >/dev/null 2>"$WORK/retire.err"
rc=$?
if [ "$rc" -eq 0 ] && ! detector_noise "$WORK/retire.err" && [ "$(row_count)" = "1" ] && \
   [ "$(census_field row_count)" = "1" ] && grep -q "retired: T9001" "$CENSUS"; then
    echo "    PASS: retire shrank the store (rows=1) with no alarm; census records the retirement"
else
    echo "    FAIL: retire rc=$rc (rows $(row_count)); census=$(cat "$CENSUS")"
    cat "$WORK/retire.err" | sed 's/^/      /'
    FAIL=1
fi

# After the legitimate shrink, the next orient is silent and exits 0.
"$MG" orient >/dev/null 2>"$WORK/orient2.err"
rc=$?
if [ "$rc" -eq 0 ] && ! detector_noise "$WORK/orient2.err"; then
    echo "    PASS: orient silent after the explained shrink"
else
    echo "    FAIL: orient rc=$rc after legitimate shrink:"
    cat "$WORK/orient2.err" | sed 's/^/      /'
    FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-store-census: ALL 4 ARMS PASSED ==="
    exit 0
else
    echo "=== regression-store-census: FAILURES ==="
    exit 1
fi
