#!/usr/bin/env bash
# regression-run-record-scale.sh — T910 controls: the run-record scan is
# bounded by the in-progress set, and cold records archive off the hot path.
#
# The defect: untracked/runs/ holds ~2,755 run records, ~93% of them for rows
# that are not in progress (and 2,226 numbered attempt archives).  `readRunRecords`
# opened and JSON-parsed EVERY top-level .json on each call, and both `reap`
# and the `resume` fleet-stalls surface call it — 1.11 s per dashboard refresh
# on a directory that only ever grows.  Two fixes, in order:
#
#   FIX 1 (hot path): readRunRecords now takes the in-progress tids and only
#     opens files whose name could carry one of those rows' records
#     (<tid>.json or <tid>.<N>.json).  The question reap/resume answer is about
#     a handful of live rows, so the scan is bounded by the live set, not the
#     directory size.
#   FIX 2 (cold path): `managent archive-runs` moves cold records — task not
#     in_progress, pid dead, older than --min-age-days — into
#     untracked/runs/archive-<date>/.  Archive, never delete; atomic rename;
#     idempotent; a re-dispatch writes a fresh bare record, so the bare record
#     stays findable.
#
# Controls:
#   A. open bound (the red->green arm): 2000 cold records + 3 live rows; the
#      open count must be <= the live set (3), while the directory holds 2003.
#   B. null: an empty runs directory — reap reports no-evidence, liveness
#      reports UNKNOWN, never a false BACKED, never a crash.
#   C. correctness: the full verdict matrix is pinned — a faster reaper that
#      reaps differently is a regression, not an optimisation.
#   D. archive: in_progress and live-pid records stay; cold records move; the
#      move is idempotent; a re-dispatched row resolves from its fresh bare
#      record (the archived history does not confuse reap).
#
# Everything runs in a scratch repo under /tmp/weizigo (tools/lib/scratch-repo.sh);
# the live kanban, live untracked/ and the live repo are never touched.
#
# Overrides: MANAGENT_BIN (the managent under test; default zig-out then bin).
#
# Task: T910 · Role: worker · Model: deepseek-v4-pro · Date: 2026-08-25

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
FAIL=0
LEFTOVERS=""

cleanup() {
    if [ -n "$LEFTOVERS" ]; then
        for p in $LEFTOVERS; do
            kill -9 "$p" 2>/dev/null
            kill -9 -- "-$p" 2>/dev/null
            wait "$p" 2>/dev/null
        done
    fi
    [ -n "${WORK:-}" ] && rm -rf "$WORK"
}
trap cleanup EXIT

. "$PROJECT/tools/lib/scratch-repo.sh"
weizigo_scratch_repo t910-runscl WORK
cd "$WORK" || exit 2
git config user.email t910@test
git config user.name T910
echo base > README.md
mkdir -p docs/infra/managent untracked/runs
printf 'untracked/\n' > .gitignore
git add README.md .gitignore
git commit -qm base

STORE="$WORK/docs/infra/managent/tasks.json"
export MANAGENT_STORE="$STORE"

MG="${MANAGENT_BIN:-}"
if [ -z "$MG" ]; then
    if [ -x "$PROJECT/zig-out/bin/managent" ]; then MG="$PROJECT/zig-out/bin/managent"
    elif [ -x "$PROJECT/bin/managent" ]; then MG="$PROJECT/bin/managent"; fi
fi
if [ -z "$MG" ] || ! "$MG" help 2>&1 | grep -q "managent archive-runs"; then
    echo "regression-run-record-scale: FATAL — no managent carrying archive-runs (${MG:-none})"
    exit 2
fi

pass() { echo "    PASS: $*"; }
fail() { echo "    FAIL: $*"; FAIL=1; }
jget() { python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(d.get(sys.argv[2]))" "$1" "$2" 2>/dev/null; }

seed_store() {
    # Write the store directly (bypassing managent), then reset the S10 census
    # so the next managent write does not read a direct write as a shrink.
    python3 - "$STORE" "$1" <<'PYEOF'
import json, sys
store, status = sys.argv[1], sys.argv[2]
rows = {}
def mk(st, extra=None):
    r = {"status": st, "agent": "deepseek-v4-pro", "model": "deepseek-v4-pro",
         "bundle": "untracked/T910-bundle.md", "set": "A", "holds": [], "needs": [],
         "caps": [], "added": "2026-08-20T02:00:00Z", "claimed": None, "done": None,
         "dispatched": None, "dispatched_to": None, "note": None, "claim_count": 1}
    if st == "in_progress":
        r["claimed"] = "2026-08-25T02:00:00Z"
    elif st == "done":
        r["done"] = "2026-08-22T02:00:00Z"
    if extra:
        r.update(extra)
    return r
for tid, st in [l.split("=") for l in status.split(",") if l]:
    rows[tid] = mk(st)
rows["_sys"] = {"next_id": 9000, "directive_next": 1}
json.dump(rows, open(store, "w"), indent=1)
PYEOF
    weizigo_reset_census "$STORE"
}

write_record() { # $1=path $2=json-body
    cat > "untracked/runs/$1" <<EOF
$2
EOF
}

echo "=== regression-run-record-scale (T910) ==="
echo "    managent: $MG"

# ── A. open bound (red -> green) ───────────────────────────────────────────
echo "  A. open bound: 2000 cold records + 3 live rows -> opened <= 3, not 2003"
seed_store "TSCAL1=in_progress,TSCAL2=in_progress,TSCAL3=in_progress"
mkdir -p untracked/runs
for t in TSCAL1 TSCAL2 TSCAL3; do
    sleep 300 & p=$!
    LEFTOVERS="$LEFTOVERS $p"
    write_record "$t.json" "{\"command\": \"sh -c 'sleep 300'\", \"launcher_pid\": 1, \"pgid\": $p, \"pid\": $p, \"start\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"task\": \"$t\"}"
done
python3 - <<'PYEOF'
import json, os
os.makedirs("untracked/runs", exist_ok=True)
for i in range(2000):
    t = "TCOLD%d" % i
    rec = {"command": "zig build test", "cpu": 1.0, "end": "2026-08-20T02:51:00Z", "exit": 0,
           "launcher_pid": 1, "pgid": 999991, "pid": 999991, "rss_mb": 5,
           "start": "2026-08-20T02:50:00Z", "task": t, "wall": 60.0}
    with open("untracked/runs/%s.json" % t, "w") as f:
        json.dump(rec, f)
PYEOF
OUT=$(MANAGENT_RUN_RECORD_OPENS=1 "$MG" reap 2>&1)
LINE=$(echo "$OUT" | grep -o "run-records: opened [0-9]* of [0-9]* .json entries for [0-9]* in-progress row(s)" | head -1)
if [ -z "$LINE" ]; then
    fail "no open-count diagnostic emitted (MANAGENT_RUN_RECORD_OPENS=1 missing in the binary?)"
else
    N=$(echo "$LINE" | awk '{print $3}')
    M=$(echo "$LINE" | awk '{print $5}')
    if [ "$M" = "2003" ]; then pass "directory held 2003 .json entries (2000 cold + 3 live)"
    else fail "expected 2003 .json entries, saw '$M' (fixture under-seeded)"; fi
    if [ "$N" -le 3 ]; then pass "opened $N files (<= the 3 live rows), not the directory's $M"
    else fail "opened $N files — the scan is bounded by the directory, not the live set"; fi
fi

# ── B. null: empty runs directory ──────────────────────────────────────────
echo "  B. null: empty runs dir -> reap no-evidence, liveness UNKNOWN, no crash"
rm -rf untracked/runs && mkdir -p untracked/runs
seed_store "TEMPTY=in_progress"
OUT=$("$MG" reap 2>&1)
RC=$?
if [ "$RC" -eq 0 ]; then pass "reap exit 0 on an empty runs dir"
else fail "reap crashed on an empty runs dir (exit $RC)"; fi
if echo "$OUT" | grep -q "TEMPTY.*ORPHAN"; then pass "reap reports TEMPTY ORPHAN (no-evidence)"
else fail "reap did not report no-evidence: $(echo "$OUT" | grep TEMPTY)"; fi
if echo "$OUT" | grep "TEMPTY" | grep -q "BACKED"; then fail "reap falsely said BACKED on an empty dir"
else pass "reap never falsely says BACKED"; fi
OUT2=$("$MG" liveness 2>&1)
if echo "$OUT2" | grep "TEMPTY" | grep -q "UNKNOWN"; then pass "liveness reports UNKNOWN (no assertion, no heartbeat)"
else fail "liveness wrong on empty dir: $(echo "$OUT2" | grep TEMPTY)"; fi

# ── C. correctness: the verdict matrix is pinned ───────────────────────────
echo "  C. correctness: the verdict matrix is pinned (a faster reaper must reap identically)"
rm -rf untracked/runs && mkdir -p untracked/runs
seed_store "TCM1=in_progress,TCM2=in_progress,TCM3=in_progress,TCM4=in_progress,TCM5=in_progress"
sleep 300 & p=$!
LEFTOVERS="$LEFTOVERS $p"
write_record "TCM1.json" "{\"command\": \"sh -c 'sleep 300'\", \"launcher_pid\": 1, \"pgid\": $p, \"pid\": $p, \"start\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"task\": \"TCM1\"}"
write_record "TCM2.json" '{"command": "zig build test", "cpu": 1.0, "end": "2026-08-20T02:51:00Z", "exit": 0, "launcher_pid": 1, "pgid": 999992, "pid": 999992, "start": "2026-08-20T02:50:00Z", "task": "TCM2", "wall": 60.0}'
write_record "TCM3.json" '{"command": "sh -c sleep 120", "launcher_pid": 1, "pgid": 999993, "pid": 999993, "start": "2026-08-20T02:50:00Z", "task": "TCM3"}'
write_record "TCM5.json" '{"command": "zig build test", "end": "2026-08-20T03:00:10Z", "exit": 0, "launcher_pid": 1, "pgid": 999995, "pid": 999995, "run_kind": "nested", "run_kind_reason": "MANAGENT_RUN_IDENTITY=TCM5", "start": "2026-08-20T03:00:00Z", "task": "TCM5", "wall": 10.0}'
# TCM4: no record at all
OUT=$("$MG" reap 2>&1)
echo "$OUT" | grep -q "TCM1.*BACKED"   && pass "TCM1 (live pid, open record)   BACKED"  || fail "TCM1 not BACKED: $(echo "$OUT" | grep TCM1)"
echo "$OUT" | grep -q "TCM2.*ORPHAN"   && pass "TCM2 (dead pid, ended)         ORPHAN"  || fail "TCM2 not ORPHAN: $(echo "$OUT" | grep TCM2)"
echo "$OUT" | grep "TCM2" | grep -q "run ended exit=0" && pass "  TCM2 evidence names the ended run" || fail "TCM2 evidence changed: $(echo "$OUT" | grep TCM2)"
echo "$OUT" | grep -q "TCM3.*ORPHAN"   && pass "TCM3 (dead pid, mid-flight)    ORPHAN"  || fail "TCM3 not ORPHAN: $(echo "$OUT" | grep TCM3)"
echo "$OUT" | grep "TCM3" | grep -q "killed mid-flight" && pass "  TCM3 evidence names mid-flight" || fail "TCM3 evidence changed: $(echo "$OUT" | grep TCM3)"
echo "$OUT" | grep -q "TCM4.*ORPHAN"   && pass "TCM4 (no record)               ORPHAN"  || fail "TCM4 not ORPHAN: $(echo "$OUT" | grep TCM4)"
echo "$OUT" | grep -q "TCM5.*UNKNOWN"  && pass "TCM5 (nested-only)             UNKNOWN" || fail "TCM5 not UNKNOWN: $(echo "$OUT" | grep TCM5)"

# ── D. archive: cold records move; live/in-progress stay; idempotent ───────
echo "  D. archive: cold records move off the hot path, live records stay, idempotent"
rm -rf untracked/runs && mkdir -p untracked/runs
seed_store "TARC1=in_progress,TARC2=done,TARC3=done"
sleep 300 & p1=$!
LEFTOVERS="$LEFTOVERS $p1"
write_record "TARC1.json" "{\"command\": \"sh -c 'sleep 300'\", \"launcher_pid\": 1, \"pgid\": $p1, \"pid\": $p1, \"start\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"task\": \"TARC1\"}"
write_record "TARC2.json"   '{"command": "zig build test", "cpu": 1.0, "end": "2026-08-20T02:51:00Z", "exit": 0, "launcher_pid": 1, "pgid": 999902, "pid": 999902, "start": "2026-08-20T02:50:00Z", "task": "TARC2", "wall": 60.0}'
write_record "TARC2.1.json" '{"command": "zig build test", "cpu": 1.0, "end": "2026-08-19T02:51:00Z", "exit": 0, "launcher_pid": 1, "pgid": 999901, "pid": 999901, "start": "2026-08-19T02:50:00Z", "task": "TARC2", "wall": 60.0}'
sleep 300 & p3=$!
LEFTOVERS="$LEFTOVERS $p3"
write_record "TARC3.json"   "{\"command\": \"zig build test\", \"end\": \"2026-08-20T02:51:00Z\", \"exit\": 0, \"launcher_pid\": 1, \"pgid\": $p3, \"pid\": $p3, \"start\": \"2026-08-20T02:50:00Z\", \"task\": \"TARC3\", \"wall\": 60.0}"
OUT=$("$MG" archive-runs --min-age-days 0 --date 2026-08-25 2>&1)
RC=$?
if [ "$RC" -eq 0 ]; then pass "archive-runs exit 0"
else fail "archive-runs exit $RC: $OUT"; fi
if [ -f untracked/runs/TARC1.json ]; then pass "in_progress row's record NOT archived"
else fail "in_progress row's record was archived"; fi
if [ -f untracked/runs/TARC3.json ]; then pass "done row with a live pid NOT archived (T909 shape)"
else fail "live-pid record was archived"; fi
if [ ! -f untracked/runs/TARC2.json ] && [ -f untracked/runs/archive-2026-08-25/TARC2.json ]; then pass "cold done row's bare record archived"
else fail "cold bare record not archived"; fi
if [ ! -f untracked/runs/TARC2.1.json ] && [ -f untracked/runs/archive-2026-08-25/TARC2.1.json ]; then pass "cold numbered attempt archived"
else fail "cold numbered attempt not archived"; fi
OUT2=$("$MG" archive-runs --min-age-days 0 --date 2026-08-25 2>&1)
if [ -f untracked/runs/archive-2026-08-25/TARC2.json ] && [ -f untracked/runs/archive-2026-08-25/TARC2.1.json ] && [ ! -f untracked/runs/TARC2.json ]; then
    pass "second run idempotent (already-archived records stay put, none lost)"
else
    fail "idempotency broken: $(echo "$OUT2" | head -1)"
fi
# re-dispatch TARC2: a fresh bare record must resolve, the archived history must not confuse reap
python3 - "$STORE" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
d["TARC2"]["status"] = "in_progress"; d["TARC2"]["claimed"] = "2026-08-25T03:00:00Z"; d["TARC2"]["done"] = None
json.dump(d, open(sys.argv[1], "w"), indent=1)
PYEOF
weizigo_reset_census "$STORE"
sleep 300 & p2=$!
LEFTOVERS="$LEFTOVERS $p2"
write_record "TARC2.json" "{\"command\": \"sh -c 'sleep 300'\", \"launcher_pid\": 1, \"pgid\": $p2, \"pid\": $p2, \"start\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"task\": \"TARC2\"}"
OUT3=$("$MG" reap 2>&1)
if echo "$OUT3" | grep -q "TARC2.*BACKED"; then pass "re-dispatched row resolves from the fresh bare record (archived history does not confuse reap)"
else fail "re-dispatched row did not resolve: $(echo "$OUT3" | grep TARC2)"; fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-run-record-scale: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-run-record-scale: FAILURES ==="
    exit 1
fi
