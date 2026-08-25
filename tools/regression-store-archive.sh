#!/usr/bin/env bash
# regression-store-archive.sh — T965 bulk-archive controls (live store keeps every closed row)
#
# The 2026-08-24 59-task loss makes any bulk move between the live store and
# the archive a load-bearing operation.  These arms pin the contract:
#
#   A1 (null):             an archive run that moves NOTHING changes no bytes —
#                          tasks.json and store-census.json are byte-identical
#                          before/after, no detector noise, exit 0.
#   A2 (legit shrink):     a BULK archive (not just retire) registers as an
#                          explained shrink (A19): the census is rewritten with
#                          the surviving ids and "retired: <ids>", no alarm,
#                          orient stays silent.
#   A3 (seeded defect):    after the bulk move, a stale writer that rewrites
#                          tasks.json and drops a LIVE row (not one of the
#                          archived rows) is caught: the next mutation is
#                          REFUSED naming the missing id + census, and the
#                          read surface ALARMS.  The reasoned escape
#                          (--reconcile-store-loss) proceeds.
#   A4 (resolution):       `show <id>` resolves a row wherever it lives and
#                          names WHICH store answered (archive vs live); a
#                          nowhere id still exits non-zero.
#   A5 (round trip):       archive a row, unarchive it, tasks.json is
#                          BYTE-IDENTICAL to the pre-archive snapshot; the
#                          archive no longer carries the id; unarchive of a
#                          non-archived id and of a live-colliding id refuse.
#   A6 (guards):           both pre-existing store-loss regressions
#                          (regression-store-census.sh, regression-store-loss.sh)
#                          stay green after the archive changes.
#
# All fixtures are synthetic and run in /tmp/weizigo — the live kanban and
# live repo are never touched.  MANAGENT_STORE points at a scratch kanban and
# the command is invoked from the scratch repo, so findRepoRoot resolves
# there (same discipline as T848/T944).
#
# Task: T965 · Role: worker · Model: qwen3.8-27b · Date: 2026-08-25

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
FAIL=0

. "$PROJECT/tools/lib/scratch-repo.sh"

# ── the GIT_DIR leak guard is load-bearing, not style (T848) ───────────────
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
    echo "SKIP: no managent binary found — build with 'zig build' or deploy (zig build deploy-managent)"
    exit 0
fi
if ! "$MG" help 2>&1 | grep -q "managent orient"; then
    echo "SKIP: $MG does not carry the orient command — rebuild from src/managent/main.zig"
    exit 0
fi

mkdir -p /tmp/weizigo
weizigo_scratch_repo managent-store-archive WORK   # T849: isolated scratch repo
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
git config user.email t965@test
git config user.name T965
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
row_count() {
    python3 -c "import json; d=json.load(open('$STORE')); print(len([k for k in d if not k.startswith('_')]))"
}
archive_ids() {
    python3 -c "import json; d=json.load(open('$ARCHIVE')); print(' '.join(sorted(k for k in d if not k.startswith('_'))))" 2>/dev/null || echo ""
}
census_field() {
    python3 -c "import json; d=json.load(open('$CENSUS')); print(d.get('$1','NOTFOUND'))" 2>/dev/null || echo NOTFOUND
}
mkbundle() { # $1 = id  $2 = slug
    printf '<!--managent set=A type=infra-->\n# %s — %s\n**Landmark:** none directly; unblocks T9000\n' "$1" "$2" > "untracked/$1-$2.md"
}
detector_noise() { # any store-loss-detector output in $1 → non-zero
    grep -E "store-loss detector|ALARM|REFUSED|census:" "$1" >/dev/null 2>&1
}
# Flip row statuses in place — ids and _sys untouched, so the committed census
# stays consistent (count + ids) while the rows become archivable.
flip_done() { # $@ = ids to mark done
    python3 - "$STORE" "$@" <<'PY'
import json,sys
p=sys.argv[1]; ids=set(sys.argv[2:])
d=json.load(open(p))
for i in ids: d[i]['status']='done'
json.dump(d,open(p,'w'),indent=2)
PY
}

echo "=== regression-store-archive: T965 bulk-archive controls ==="

# ══════════════════════════════════════════════════════════════════════════
# A1 — null control: an archive run that moves nothing changes no bytes
# ══════════════════════════════════════════════════════════════════════════
echo "  1. A1 (null): archive moving nothing changes no bytes, no noise"
mkbundle T9001 a
"$MG" add T9001 --bundle untracked/T9001-a.md >/dev/null 2>&1   # dispatchable → not archivable
cp "$STORE" "$WORK/s1.store"; cp "$CENSUS" "$WORK/s1.census"
"$MG" archive >/dev/null 2>"$WORK/a1.err"
rc=$?
if [ "$rc" -eq 0 ] && cmp -s "$STORE" "$WORK/s1.store" && cmp -s "$CENSUS" "$WORK/s1.census" && \
   ! detector_noise "$WORK/a1.err" && [ "$(row_count)" = "1" ]; then
    echo "    PASS: no-op archive — store+census byte-identical, rc=0, no detector noise (A1)"
else
    echo "    FAIL: no-op archive rc=$rc rows=$(row_count); byte-diff or noise below:"
    diff "$WORK/s1.store" "$STORE" | sed 's/^/      /' | head -5
    diff "$WORK/s1.census" "$CENSUS" | sed 's/^/      /' | head -5
    sed 's/^/      /' < "$WORK/a1.err"
    FAIL=1
fi

# ══════════════════════════════════════════════════════════════════════════
# A2 — legitimate bulk shrink under the census (A19, bulk edition)
# ══════════════════════════════════════════════════════════════════════════
echo "  2. A2 (legit shrink): bulk archive registers as an EXPLAINED shrink"
mkbundle T9002 b
"$MG" add T9002 --bundle untracked/T9002-b.md >/dev/null 2>&1
mkbundle T9003 c
"$MG" add T9003 --bundle untracked/T9003-c.md >/dev/null 2>&1
# T9001 stays live; flip T9002/T9003 to done (ids unchanged → census intact)
flip_done T9002 T9003
"$MG" archive >/dev/null 2>"$WORK/a2.err"
rc=$?
ARCIDS=$(archive_ids)
if [ "$rc" -eq 0 ] && [ "$(row_count)" = "1" ] && [ "$(census_field row_count)" = "1" ] && \
   [ "$ARCIDS" = "T9002 T9003" ] && grep -q "retired:" "$CENSUS" && \
   grep -q "T9002" "$CENSUS" && grep -q "T9003" "$CENSUS" && \
   ! detector_noise "$WORK/a2.err" && census_field ids | grep -q "T9001" && \
   ! census_field ids | grep -q "T9002"; then
    echo "    PASS: 2 rows moved to archive; census row_count=1 records 'retired:' with both ids; zero alarm (A2/A19)"
else
    echo "    FAIL: archive rc=$rc rows=$(row_count) census=$(census_field row_count) arcids='$ARCIDS':"
    sed 's/^/      /' < "$WORK/a2.err"
    FAIL=1
fi
"$MG" orient >/dev/null 2>"$WORK/a2.orient.err"
rc=$?
if [ "$rc" -eq 0 ] && ! detector_noise "$WORK/a2.orient.err"; then
    echo "    PASS: orient silent (rc=0) after the explained bulk shrink (A2)"
else
    echo "    FAIL: orient rc=$rc after bulk archive:"
    sed 's/^/      /' < "$WORK/a2.orient.err"
    FAIL=1
fi

# ══════════════════════════════════════════════════════════════════════════
# A3 — seeded defect: a stale writer drops a LIVE row after the bulk move
# ══════════════════════════════════════════════════════════════════════════
echo "  3. A3 (seeded defect): a move that drops a live row is caught and refused"
# Stale writer shape: tasks.json reappears WITHOUT the one live row (T9001),
# while the census still records it.
python3 - "$STORE" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
d.pop('T9001',None)
json.dump(d,open(sys.argv[1],'w'),indent=2)
PY
mkbundle T9005 e
"$MG" add T9005 --bundle untracked/T9005-e.md >/dev/null 2>"$WORK/a3.add.err"
rc_add=$?
if [ "$rc_add" -ne 0 ] && grep -q "REFUSED: store-loss detector" "$WORK/a3.add.err" && \
   grep -q "T9001" "$WORK/a3.add.err" && grep -q "census:" "$WORK/a3.add.err" && \
   [ "$(row_count)" = "0" ]; then
    echo "    PASS: mutation REFUSED (rc=$rc_add) naming dropped live row T9001 + census; store unmutated (A3)"
else
    echo "    FAIL: add rc=$rc_add rows=$(row_count); expected REFUSED:"
    sed 's/^/      /' < "$WORK/a3.add.err"
    FAIL=1
fi
"$MG" orient >/dev/null 2>"$WORK/a3.orient.err"
rc=$?
if [ "$rc" -ne 0 ] && grep -q "ALARM: store-loss detector" "$WORK/a3.orient.err" && grep -q "T9001" "$WORK/a3.orient.err"; then
    echo "    PASS: orient ALARMS (rc=$rc) naming T9001 before any worker acts (A3)"
else
    echo "    FAIL: orient rc=$rc; expected ALARM naming T9001:"
    sed 's/^/      /' < "$WORK/a3.orient.err"
    FAIL=1
fi
# Reasoned escape — restores the census/store relationship for the later arms.
"$MG" add T9005 --bundle untracked/T9005-e.md --reconcile-store-loss "T965 A3 seeded defect" >/dev/null 2>"$WORK/a3.rec.err"
rc=$?
if [ "$rc" -eq 0 ] && [ "$(row_count)" = "1" ] && grep -q "reconcile-store-loss: T965 A3 seeded defect" "$CENSUS"; then
    echo "    PASS: reasoned escape proceeded (rows=1) and recorded its reason (A3)"
else
    echo "    FAIL: escape rc=$rc rows=$(row_count):"
    sed 's/^/      /' < "$WORK/a3.rec.err"
    FAIL=1
fi

# ══════════════════════════════════════════════════════════════════════════
# A4 — resolution: show resolves a row wherever it lives, names the store
# ══════════════════════════════════════════════════════════════════════════
echo "  4. A4 (resolution): show <id> names which store answered"
"$MG" show T9002 >"$WORK/a4.arch.out" 2>&1
rc=$?
if [ "$rc" -eq 0 ] && grep -q "T9002" "$WORK/a4.arch.out" && \
   grep -qi "archive" "$WORK/a4.arch.out"; then
    echo "    PASS: show T9002 (archived) rc=0, names the archive store (A4)"
else
    echo "    FAIL: show T9002 rc=$rc (expected archive resolution):"
    sed 's/^/      /' < "$WORK/a4.arch.out"
    FAIL=1
fi
"$MG" show T9005 >"$WORK/a4.live.out" 2>&1
rc=$?
if [ "$rc" -eq 0 ] && grep -q "T9005" "$WORK/a4.live.out" && grep -q "tasks.json" "$WORK/a4.live.out"; then
    echo "    PASS: show T9005 (live) rc=0, names the live store (A4)"
else
    echo "    FAIL: show T9005 rc=$rc (expected live-store naming):"
    sed 's/^/      /' < "$WORK/a4.live.out"
    FAIL=1
fi
"$MG" show T9099 >"$WORK/a4.miss.out" 2>&1
rc=$?
if [ "$rc" -ne 0 ]; then
    echo "    PASS: show T9099 (nowhere) rc=$rc (A4)"
else
    echo "    FAIL: show T9099 rc=0 — an unknown id must exit non-zero"
    FAIL=1
fi

# ══════════════════════════════════════════════════════════════════════════
# A5 — round trip: archive, unarchive, byte-identical store
# ══════════════════════════════════════════════════════════════════════════
echo "  5. A5 (round trip): archive -> unarchive is byte-identical"
mkbundle T9006 f
"$MG" add T9006 --bundle untracked/T9006-f.md >/dev/null 2>&1
flip_done T9006
# Normalize before the snapshot: managent's T204 self-heal rewrites _sys.next_id
# on EVERY read+write cycle (next_id <= max T-ID is healed to max+1), and its
# serializer owns the file's exact shape (incl. the trailing newline).  A
# no-op `set` write puts the file in that canonical post-heal form, so a whole-
# file byte comparison afterwards tests the ARCHIVE move, not the pre-existing
# heal (which happens on any verb: add, claim, set, ...).
"$MG" set T9005 A >/dev/null 2>&1
cp "$STORE" "$WORK/s5.store"          # pre-archive snapshot (canonical form)
"$MG" archive >/dev/null 2>"$WORK/a5.arch.err"
rc=$?
if [ "$rc" -eq 0 ] && [ "$(row_count)" = "1" ] && archive_ids | grep -q "T9006"; then
    echo "    PASS: archive moved T9006 (rows=1)"
else
    echo "    FAIL: archive rc=$rc rows=$(row_count) arcids='$(archive_ids)':"
    sed 's/^/      /' < "$WORK/a5.arch.err"
    FAIL=1
fi
"$MG" unarchive T9006 >"$WORK/a5.un.out" 2>&1
rc=$?
if [ "$rc" -eq 0 ] && cmp -s "$STORE" "$WORK/s5.store" && ! archive_ids | grep -q "T9006" && \
   grep -q "T9006" "$WORK/a5.un.out"; then
    echo "    PASS: unarchive T9006 rc=0; tasks.json BYTE-IDENTICAL to pre-archive; archive clean (A5)"
else
    echo "    FAIL: unarchive rc=$rc; byte-diff or archive residue:"
    diff "$WORK/s5.store" "$STORE" | sed 's/^/      /' | head -10
    echo "      archive ids now: $(archive_ids)"
    sed 's/^/      /' < "$WORK/a5.un.out"
    FAIL=1
fi
"$MG" unarchive T9099 >/dev/null 2>"$WORK/a5.nota.err"
if [ $? -ne 0 ]; then
    echo "    PASS: unarchive T9099 (not archived) refused (A5)"
else
    echo "    FAIL: unarchive of a non-archived id succeeded"
    FAIL=1
fi
# Collision: T9006 is live again; archiving and then attempting a second
# live row with the same id is impossible via the store, but a direct
# collision (unarchive while the id already lives) must refuse.
flip_done T9006 >/dev/null 2>&1   # make it archivable again
"$MG" archive >/dev/null 2>&1
cp "$STORE" "$WORK/s5b.store"
"$MG" unarchive T9006 >/dev/null 2>&1   # now live again
"$MG" unarchive T9006 >/dev/null 2>"$WORK/a5.coll.err"
if [ $? -ne 0 ] && ! cmp -s "$STORE" "$WORK/s5b.store"; then
    echo "    PASS: unarchive over a live id refused; store left as the live store (A5)"
else
    echo "    FAIL: double-unarchive of live T9006 did not refuse:"
    sed 's/^/      /' < "$WORK/a5.coll.err"
    FAIL=1
fi

# ══════════════════════════════════════════════════════════════════════════
# A6 — guards: the pre-existing store-loss regressions stay green
# ══════════════════════════════════════════════════════════════════════════
echo "  6. A6 (guards): both store-loss regressions stay green"
for g in regression-store-census.sh regression-store-loss.sh; do
    if "$PROJECT/tools/$g" >/dev/null 2>&1; then
        echo "    PASS: $g green"
    else
        echo "    FAIL: $g not green"
        FAIL=1
    fi
done

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-store-archive: ALL 6 ARMS PASSED (A1..A6) ==="
    exit 0
else
    echo "=== regression-store-archive: FAILURES ==="
    exit 1
fi
