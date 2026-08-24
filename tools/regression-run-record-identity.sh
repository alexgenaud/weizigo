#!/usr/bin/env bash
# regression-run-record-identity.sh — T895 controls: a run record must say
# WHICH KIND of run wrote it, and reap must read the row's DISPATCH record.
#
# The defect (caught twice on 2026-08-24): `managent reap` picked the NEWEST
# run record for a task id, with no notion of what kind of run produced it.
# A dispatched worker that invokes tools/runner for its OWN test runs does so
# under its OWN task id, so the test run wrote a newer record whose pid was a
# test script's.  That script exits in seconds; reap then read a dead pid with
# an exit field, classified the row `orphan_ended`, and offered `--close` on a
# worker that was alive and working (B57/B58; and T880 at 19:38, reported
# "[ORPHAN] ... runner pid dead" four minutes into its CPU time).
# untracked/runs/T880.*.json is the recorded shape.
#
# The fix has two halves, and this script controls both:
#   WRITER (tools/runner): a nested run is detected by the exported identity
#   marker MANAGENT_RUN_IDENTITY (layer 1) or by process-tree containment of a
#   live, un-finalized dispatch record's pid (layer 2).  It writes to
#   untracked/runs/nested/ and does NOT rotate the dispatch slot.
#   READER (managent reap): liveness over recency across ALL of an identity's
#   records; the DISPATCH record, never merely the newest; and UNKNOWN — never
#   ORPHAN — when records exist but none can be attributed to a dispatch.
#
# Controls:
#   A1 seeded (writer, layer 1): a nested run under a LIVE dispatch, marker
#      present -> record lands in untracked/runs/nested/, the dispatch record
#      is untouched (not rotated), and reap says BACKED.
#   A2 seeded (writer, layer 2): same, marker STRIPPED, nested runner launched
#      from inside the dispatch's process tree -> still nested.
#   A3 seeded (reader, the original blinding, legacy data): the T880 shape
#      hand-written with UNDECLARED kinds — a live dispatch launch record
#      displaced to <id>.1.json and a dead, completed test run in the bare
#      slot.  RED before this row: reap reported ORPHAN.  Now BACKED, and the
#      evidence names the record it read.
#   B1 null (dead worker): dead pid + completed record -> still ORPHAN.
#   B2 null (no record at all): -> still the no-evidence class, still ORPHAN.
#   B3 null (a real dispatch is still a dispatch): a plain top-level runner
#      invocation writes the BARE record with run_kind=dispatch, claims its
#      row and heartbeats.
#   C  UNKNOWN: an identity whose ONLY records are declared nested and dead ->
#      UNKNOWN, and `reap --close` does NOT close it.
#
# Everything runs in a scratch repo under /tmp/weizigo (tools/lib/scratch-repo.sh);
# the live kanban, live untracked/ and the live repo are never touched.
#
# Overrides for before/after evidence:
#   RUNNER_BIN   the tools/runner under test  (default: this checkout's)
#   MANAGENT_BIN the managent under test      (default: zig-out then bin)
#
# Task: T895 · Role: worker · Model: claude-opus-5 · Date: 2026-08-24

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
RUNNER="${RUNNER_BIN:-$PROJECT/tools/runner}"
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
weizigo_scratch_repo t895-runrec WORK
cd "$WORK" || exit 2
git config user.email t895@test
git config user.name T895
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
if [ -z "$MG" ] || ! "$MG" help 2>&1 | grep -q "managent reap"; then
    echo "regression-run-record-identity: FATAL — no managent carrying reap (${MG:-none})"
    exit 2
fi

# The runner's auto-claim path shells out to <repo>/bin/managent; the scratch
# repo needs that entry point to exist (arm B3 checks a real claim).
mkdir -p "$WORK/bin"
printf '#!/bin/sh\nexec "%s" "$@"\n' "$MG" > "$WORK/bin/managent"
chmod +x "$WORK/bin/managent"

pass() { echo "    PASS: $*"; }
fail() { echo "    FAIL: $*"; FAIL=1; }
jget() { python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(d.get(sys.argv[2]))" "$1" "$2" 2>/dev/null; }

seed_row() {
    python3 - "$STORE" "$1" <<'PYEOF'
import json, os, sys
store, tid = sys.argv[1], sys.argv[2]
d = json.load(open(store)) if os.path.exists(store) else {"_sys": {"next_id": 9000, "directive_next": 1}}
d[tid] = {"status": "in_progress", "agent": "claude-opus-5", "model": "claude-opus-5",
          "bundle": "untracked/T895-bundle.md", "set": "A", "holds": [], "needs": [], "caps": [],
          "added": "2026-08-24T02:00:00Z", "claimed": "2026-08-24T02:00:00Z", "done": None,
          "dispatched": None, "dispatched_to": None, "note": None, "claim_count": 1}
json.dump(d, open(store, "w"), indent=1)
PYEOF
}

echo "=== regression-run-record-identity (T895) ==="
echo "    runner:   $RUNNER"
echo "    managent: $MG"

# ── A1: nested via the exported marker (layer 1) ──────────────────────────
echo "  A1. seeded (writer, marker): a nested run never takes the dispatch slot"
seed_row TRID1
env -u MANAGENT_RUN_IDENTITY MANAGENT_TASK_ID=TRID1 \
    "$RUNNER" --no-prepend-zig --no-host-guard --max-wall 60 -- sh -c 'sleep 40' >/dev/null 2>&1 &
DISPATCH_JOB=$!
for _ in $(seq 1 40); do [ -f untracked/runs/TRID1.json ] && break; sleep 0.2; done
if [ ! -f untracked/runs/TRID1.json ]; then
    fail "no dispatch record appeared for TRID1"
else
    D_PID=$(jget untracked/runs/TRID1.json pid)
    D_PGID=$(jget untracked/runs/TRID1.json pgid)
    LEFTOVERS="$LEFTOVERS $D_PID $D_PGID"
    # the nested run: exactly what a dispatched worker's own test run looks
    # like — same task id, marker inherited from the dispatch.  The sleep puts
    # its `start` in a strictly later second than the dispatch's, so the
    # pre-T895 "newest record for the id" rule selects it (that is the
    # blinding), and no arm here can pass by a same-second tie.
    sleep 1.2
    MANAGENT_RUN_IDENTITY=TRID1 MANAGENT_TASK_ID=TRID1 \
        "$RUNNER" --no-prepend-zig --no-host-guard --max-wall 20 -- sh -c 'echo nested; sleep 0.2' >/dev/null 2>&1
    if [ "$(jget untracked/runs/TRID1.json pid)" = "$D_PID" ] && [ -z "$(jget untracked/runs/TRID1.json exit)" -o "$(jget untracked/runs/TRID1.json exit)" = "None" ]; then
        pass "the dispatch record still holds the dispatch (pid $D_PID, un-finalized)"
    else
        fail "the nested run took the dispatch slot: $(cat untracked/runs/TRID1.json)"
    fi
    if [ -f untracked/runs/TRID1.1.json ]; then
        fail "the nested run ROTATED the dispatch record to TRID1.1.json"
    else
        pass "no rotation — the dispatch record was not archived by a test run"
    fi
    NCOUNT=$(ls untracked/runs/nested/TRID1.*.json 2>/dev/null | wc -l | tr -d ' ')
    if [ "$NCOUNT" -ge 1 ]; then
        NF=$(ls untracked/runs/nested/TRID1.*.json | head -1)
        if [ "$(jget "$NF" run_kind)" = "nested" ] && [ "$(jget "$NF" exit)" = "0" ]; then
            pass "the nested run's own record is in untracked/runs/nested/ (run_kind=nested, exit=0)"
        else
            fail "nested record malformed: $(cat "$NF")"
        fi
    else
        fail "no nested record written under untracked/runs/nested/"
    fi
    OUT=$("$MG" reap 2>/dev/null)
    if echo "$OUT" | grep -q "TRID1.*BACKED"; then
        pass "reap reports TRID1 BACKED while the worker is alive"
    else
        fail "reap does not report TRID1 BACKED: $(echo "$OUT" | grep TRID1)"
    fi
    if echo "$OUT" | grep "TRID1" | grep -q "record TRID1.json"; then
        pass "the evidence names the record it read"
    else
        fail "the evidence does not name the record read: $(echo "$OUT" | grep TRID1)"
    fi
    kill -9 "$D_PID" 2>/dev/null; kill -9 "$D_PGID" 2>/dev/null; wait "$DISPATCH_JOB" 2>/dev/null
fi

# ── A2: nested via process-tree containment, marker stripped (layer 2) ─────
echo "  A2. seeded (writer, process tree): the marker is not the only signal"
seed_row TRID2
NESTED_LOG="$WORK/a2-nested.log"
env -u MANAGENT_RUN_IDENTITY MANAGENT_TASK_ID=TRID2 \
    "$RUNNER" --no-prepend-zig --no-host-guard --max-wall 60 -- \
    sh -c "sleep 1; env -u MANAGENT_RUN_IDENTITY MANAGENT_TASK_ID=TRID2 '$RUNNER' --no-prepend-zig --no-host-guard --max-wall 20 -- sh -c 'echo inner' > '$NESTED_LOG' 2>&1; sleep 30" >/dev/null 2>&1 &
DISPATCH_JOB2=$!
for _ in $(seq 1 60); do
    [ -f untracked/runs/TRID2.json ] && [ -s "$NESTED_LOG" ] && break
    sleep 0.3
done
sleep 1
if [ ! -f untracked/runs/TRID2.json ]; then
    fail "no dispatch record for TRID2"
else
    D2_PID=$(jget untracked/runs/TRID2.json pid)
    D2_PGID=$(jget untracked/runs/TRID2.json pgid)
    LEFTOVERS="$LEFTOVERS $D2_PID $D2_PGID"
    if [ -f untracked/runs/TRID2.1.json ]; then
        fail "the in-tree nested run rotated the dispatch record (layer 2 did not fire)"
    else
        pass "no rotation with the marker stripped — process-tree containment caught it"
    fi
    N2=$(ls untracked/runs/nested/TRID2.*.json 2>/dev/null | head -1)
    if [ -n "$N2" ] && [ "$(jget "$N2" run_kind)" = "nested" ]; then
        pass "nested record present ($(basename "$N2"))"
    else
        fail "no nested record for TRID2; nested/ holds: $(ls untracked/runs/nested/ 2>/dev/null | tr '\n' ' ')"
    fi
    OUT=$("$MG" reap 2>/dev/null)
    echo "$OUT" | grep -q "TRID2.*BACKED" && pass "reap reports TRID2 BACKED" || fail "reap does not report TRID2 BACKED: $(echo "$OUT" | grep TRID2)"
    kill -9 "$D2_PID" 2>/dev/null; kill -9 "$D2_PGID" 2>/dev/null; wait "$DISPATCH_JOB2" 2>/dev/null
fi

# ── A3: the reader's safety net on LEGACY (undeclared) records ─────────────
# This is the original blinding, reproduced from data alone: no run_kind
# anywhere, the dispatch record displaced into .1.json by a test run, and the
# test run — dead, exit 1, 4.2s — sitting in the bare slot.  That is exactly
# T880's shape at 19:38.
echo "  A3. seeded (reader, legacy shape): a displaced dispatch record is still evidence"
seed_row TRID3
sleep 300 & ALIVE=$!
LEFTOVERS="$LEFTOVERS $ALIVE"
cat > untracked/runs/TRID3.1.json <<EOF
{"attempt": 1, "command": "pi --provider deepseek --model deepseek-v4-flash -p 'Follow ...'", "launcher_pid": 1, "pgid": $ALIVE, "pid": $ALIVE, "start": "2026-08-24T17:38:55Z", "task": "TRID3"}
EOF
cat > untracked/runs/TRID3.json <<'EOF'
{"attempt": 13, "command": "./.zig-cache/o/de897c22285a4baf057716d1e22ccaf0/verify-battery 4x3 artifacts/oracle-4x3.wzo", "end": "2026-08-24T17:54:03Z", "exit": 1, "launcher_pid": 74131, "pgid": 999913, "pid": 999913, "start": "2026-08-24T17:53:59Z", "task": "TRID3", "wall": 4.2}
EOF
OUT=$("$MG" reap 2>/dev/null)
if echo "$OUT" | grep -q "TRID3.*BACKED"; then
    pass "reap reads the live displaced dispatch record — BACKED, not ORPHAN"
else
    fail "the original blinding survives: $(echo "$OUT" | grep TRID3)"
fi
if echo "$OUT" | grep "TRID3" | grep -q "record TRID3.1.json"; then
    pass "the evidence names TRID3.1.json (the record actually read)"
else
    fail "the evidence does not name the record read: $(echo "$OUT" | grep TRID3)"
fi

# ── B1/B2: null controls — the reaper still reaps ──────────────────────────
echo "  B1/B2. null: a genuinely dead worker is still ORPHAN; no record is still no evidence"
seed_row TRID4
cat > untracked/runs/TRID4.json <<'EOF'
{"attempt": 1, "command": "pi --provider deepseek -p 'Follow ...'", "cpu": 1.0, "end": "2026-08-24T02:51:00Z", "exit": 0, "launcher_pid": 1, "pgid": 999941, "pid": 999941, "rss_mb": 5, "run_kind": "dispatch", "signal": null, "start": "2026-08-24T02:50:00Z", "task": "TRID4", "wall": 60.0}
EOF
seed_row TRID5   # no record at all, never beat
OUT=$("$MG" reap 2>/dev/null)
echo "$OUT" | grep -q "TRID4.*ORPHAN" && pass "TRID4 (dead pid, completed record) still ORPHAN" || fail "TRID4 is no longer reported ORPHAN — the fix taught reap to say BACKED"
echo "$OUT" | grep "TRID4" | grep -q "run ended exit=0" && pass "TRID4 evidence still names the ended run" || fail "TRID4 evidence changed shape: $(echo "$OUT" | grep TRID4)"
echo "$OUT" | grep -q "TRID5.*ORPHAN" && pass "TRID5 (no record, never beat) still ORPHAN" || fail "TRID5 is no longer ORPHAN: $(echo "$OUT" | grep TRID5)"
echo "$OUT" | grep "TRID5" | grep -q "never beat" && pass "TRID5 evidence still the no-evidence class" || fail "TRID5 evidence changed: $(echo "$OUT" | grep TRID5)"

# ── B3: a real dispatch is still a dispatch (claim + heartbeat + bare slot) ─
echo "  B3. null: a plain top-level dispatch still claims, beats, and owns the bare record"
python3 - "$STORE" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
d["TRID6"] = {"status": "dispatchable", "agent": None, "model": None,
              "bundle": "untracked/T895-bundle.md", "set": "A", "holds": [], "needs": [], "caps": [],
              "added": "2026-08-24T02:00:00Z", "claimed": None, "done": None, "dispatched": None,
              "dispatched_to": None, "note": None, "claim_count": 0}
json.dump(d, open(sys.argv[1], "w"), indent=1)
PYEOF
env -u MANAGENT_RUN_IDENTITY PI_MODEL=claude-opus-5 \
    "$RUNNER" --no-prepend-zig --no-host-guard --max-wall 20 --task-id TRID6 -- sh -c 'echo work; sleep 0.2' >/dev/null 2>&1
if [ "$(jget untracked/runs/TRID6.json run_kind)" = "dispatch" ] && [ "$(jget untracked/runs/TRID6.json attempt)" = "1" ]; then
    pass "the dispatch wrote the BARE record with run_kind=dispatch, attempt=1"
else
    fail "dispatch record wrong: $(cat untracked/runs/TRID6.json 2>/dev/null)"
fi
[ -d untracked/runs/nested ] && ls untracked/runs/nested/TRID6.*.json >/dev/null 2>&1 && fail "a top-level dispatch was misread as nested" || pass "a top-level dispatch is not misread as nested"
if [ "$(python3 -c "import json;print(json.load(open('$STORE'))['TRID6']['status'])")" = "in_progress" ]; then
    pass "the dispatch claimed its row (status in_progress)"
else
    fail "the dispatch did not claim its row"
fi
grep -q '"task": "TRID6"' untracked/heartbeat.jsonl 2>/dev/null && pass "the dispatch heartbeats under its task id" || fail "no heartbeat for TRID6"

# ── B4: a leaf dispatched from inside a manager's console is a DISPATCH ────
# The marker's PRESENCE must never be the test — only its equality with this
# run's identity.  A manager holding T-manager that dispatches leaf TRID8
# carries MANAGENT_RUN_IDENTITY=TRIDMGR; that leaf owns its own dispatch slot.
echo "  B4. null: a leaf dispatched from inside another row's run is still a dispatch"
seed_row TRID8
MANAGENT_RUN_IDENTITY=TRIDMGR MANAGENT_TASK_ID=TRID8 \
    "$RUNNER" --no-prepend-zig --no-host-guard --max-wall 20 -- sh -c 'echo leaf' >/dev/null 2>&1
if [ "$(jget untracked/runs/TRID8.json run_kind)" = "dispatch" ]; then
    pass "the leaf's record is a dispatch in the bare slot (a foreign marker is not nesting)"
else
    fail "a leaf dispatch was misread: $(cat untracked/runs/TRID8.json 2>/dev/null | head -c 300)"
fi

# ── C: UNKNOWN — records exist, none is a dispatch record ─────────────────
echo "  C. UNKNOWN: nested-only records are not dispatch evidence, and are not closable"
seed_row TRID7
cat > untracked/runs/TRID7.json <<'EOF'
{"command": "zig build test", "end": "2026-08-24T03:00:10Z", "exit": 0, "launcher_pid": 1, "pgid": 999971, "pid": 999971, "run_kind": "nested", "run_kind_reason": "MANAGENT_RUN_IDENTITY=TRID7", "start": "2026-08-24T03:00:00Z", "task": "TRID7", "wall": 10.0}
EOF
OUT=$("$MG" reap 2>/dev/null)
if echo "$OUT" | grep -q "TRID7.*UNKNOWN"; then
    pass "TRID7 is UNKNOWN, not ORPHAN"
else
    fail "TRID7 not reported UNKNOWN: $(echo "$OUT" | grep TRID7)"
fi
"$MG" reap --close >/dev/null 2>&1
STATUS7=$(python3 -c "import json;print(json.load(open('$STORE'))['TRID7']['status'])")
if [ "$STATUS7" = "in_progress" ]; then
    pass "reap --close did NOT close the UNKNOWN row"
else
    fail "reap --close closed an UNKNOWN row (status=$STATUS7)"
fi
STATUS4=$(python3 -c "import json;print(json.load(open('$STORE'))['TRID4']['status'])")
[ "$STATUS4" = "done" ] && pass "the same --close still closed the genuine orphan TRID4" || fail "reap --close no longer closes orphans (TRID4 status=$STATUS4)"

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-run-record-identity: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-run-record-identity: FAILURES ==="
    exit 1
fi
