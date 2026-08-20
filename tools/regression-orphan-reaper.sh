#!/usr/bin/env bash
# regression-orphan-reaper.sh — T364 controls: parent-side exit records + `managent reap`
#
# On 2026-08-04 three dispatched rows ended without committing or closing
# (T355/T356 had NO exit heartbeat at all — the runner was SIGKILLed in a
# load-16 sweep — and T361 hit its own wall guard).  Their rows sat
# in_progress for hours with nothing alive behind them.  Two structural
# gaps: a SIGKILLed runner cannot write its own exit heartbeat, and nothing
# reconciled the kanban against the process table.
#
# Controls (test-first, per the standing tooling rule):
#
#   A. exit record — null:        a clean run writes a launch record AND a
#                                 completed record (exit, wall, rss).
#   B. exit record — seeded (the whole point): launch a worker in a temp
#                                 store, `kill -9` its CHILD, assert the run
#                                 record exists with signal=9 despite the
#                                 SIGKILL (the parent wrote it) and the exit
#                                 heartbeat landed.
#   C. exit record — seeded:      `kill -9` the RUNNER itself — the launch
#                                 record remains with NO exit fields (the
#                                 next reap/resume can read "killed
#                                 mid-flight").
#   D. reap — seeded (the whole point): a row whose worker's run is over
#                                 (dead pid + completed record) and a row
#                                 whose runner was killed mid-flight are
#                                 reported ORPHAN and `reap --close` closes
#                                 them `abandoned` with the evidence in the
#                                 note.
#   E. reap — null:               a live worker (real sleeping process backs
#                                 the row) is reported BACKED and is NEVER
#                                 reaped, even with --close.
#   F. reap — seeded:             a row whose worker is alive but idle is
#                                 reported alive, not reaped — stalled is the
#                                 progress watchdog's job, not the reaper's.
#   G. reap — heartbeat-backed:   a row with a fresh heartbeat but no run
#                                 record is never reaped.
#   H. resume surface:            an orphaned row is flagged where the
#                                 operator already looks; with no orphans the
#                                 section says so.
#
# D-H need a managent binary carrying `reap` — SKIP loudly when absent
# (the Orchestrator's main.zig integration lands them; the runner arms A-C
# always run).  Everything runs in a scratch repo under /tmp/weizigo — the
# live kanban, live untracked/ and the live repo are never touched.  The
# claimlint floor is untouched by design (no doc or claim changes).
#
# Binary resolution: $MANAGENT_BIN → zig-out/bin/managent → bin/managent,
# same convention as regression-managent-resume.sh.
#
# Task: T364 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-20

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
RUNNER="$PROJECT/tools/runner"
FAIL=0
LEFTOVERS=""

cleanup() {
    # kill any processes this run left behind (orphaned children whose
    # runners we SIGKILLed are reparented, not dead); wait consumes the
    # background-job status so bash does not print "Killed" chatter.
    if [ -n "$LEFTOVERS" ]; then
        for p in $LEFTOVERS; do
            kill -9 "$p" 2>/dev/null
            kill -9 -- "-$p" 2>/dev/null  # the process group, if any
            wait "$p" 2>/dev/null
        done
    fi
    [ -n "${WORK:-}" ] && rm -rf "$WORK"
}
trap cleanup EXIT

mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/orphan-reaper-XXXXXX)" || { echo "regression-orphan-reaper.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
cd "$WORK"
git init -q
git config user.email t364@test
git config user.name T364
echo base > README.md
mkdir -p docs untracked docs/infra/managent
printf 'untracked/\n' > .gitignore
git add README.md .gitignore
git commit -qm base

STORE="$WORK/docs/infra/managent/tasks.json"
export MANAGENT_STORE="$STORE"

# ── managent binary resolution ────────────────────────────────────────────
MG="${MANAGENT_BIN:-}"
if [ -z "$MG" ]; then
    if [ -x "$PROJECT/zig-out/bin/managent" ]; then
        MG="$PROJECT/zig-out/bin/managent"
    elif [ -x "$PROJECT/bin/managent" ]; then
        MG="$PROJECT/bin/managent"
    fi
fi
HAVE_REAP=0
if [ -n "$MG" ] && "$MG" help 2>&1 | grep -q "managent reap"; then
    HAVE_REAP=1
fi
if [ "$HAVE_REAP" -eq 0 ]; then
    echo 'NOTE: managent binary does not carry the reap command (${MG:-no binary}) — arms D-H SKIP;'
    echo '      the Orchestrator main.zig integration lands them.  Runner arms A-C run.'
fi

echo "=== regression-orphan-reaper ==="

# ── A. exit record, null: clean run writes launch + completed record ──────
echo "  A. null: clean run leaves a completed run record"
export MANAGENT_TASK_ID=TRNULL
"$RUNNER" --no-prepend-zig --no-host-guard --max-wall 20 -- sh -c 'echo hi; sleep 0.2' >/dev/null 2>&1
if [ -f untracked/runs/TRNULL.json ] && grep -q '"exit": 0' untracked/runs/TRNULL.json && \
   grep -q '"start"' untracked/runs/TRNULL.json && grep -q '"wall"' untracked/runs/TRNULL.json; then
    echo "    PASS: launch + completed record (exit=0, wall) present"
else
    echo "    FAIL: run record missing or incomplete:"
    cat untracked/runs/TRNULL.json 2>/dev/null | sed 's/^/      /'
    FAIL=1
fi

# ── B. exit record, seeded (the whole point): child SIGKILL → record survives
echo "  B. seeded: SIGKILL the child — the parent's record survives with signal=9"
export MANAGENT_TASK_ID=TRKILL
"$RUNNER" --no-prepend-zig --no-host-guard --max-wall 20 -- sh -c 'sleep 120' >/dev/null 2>&1 &
RPID=$!
for _ in $(seq 1 25); do [ -f untracked/runs/TRKILL.json ] && break; sleep 0.2; done
if [ ! -f untracked/runs/TRKILL.json ]; then
    echo "    FAIL: no launch record appeared"
    FAIL=1
else
    CHILD_PID=$(python3 -c 'import json;print(json.load(open("untracked/runs/TRKILL.json"))["pgid"])')
    kill -9 "$CHILD_PID"
    wait "$RPID" 2>/dev/null
    if [ -f untracked/runs/TRKILL.json ] && grep -q '"signal": 9' untracked/runs/TRKILL.json && \
       grep -q '"end"' untracked/runs/TRKILL.json; then
        echo "    PASS: exit record exists despite the SIGKILL (signal=9, end)"
    else
        echo "    FAIL: record missing signal/end after child SIGKILL:"
        cat untracked/runs/TRKILL.json 2>/dev/null | sed 's/^/      /'
        FAIL=1
    fi
    # the exit heartbeat must also have landed
    if grep -q '"task": "TRKILL"' untracked/heartbeat.jsonl; then
        echo "    PASS: exit heartbeat landed under TRKILL"
    else
        echo "    FAIL: no heartbeat for TRKILL"
        FAIL=1
    fi
fi

# ── C. exit record, seeded: runner itself SIGKILLed → launch record, no exit
echo "  C. seeded: SIGKILL the runner — launch record remains, no exit fields"
export MANAGENT_TASK_ID=TRKILLR
"$RUNNER" --no-prepend-zig --no-host-guard --max-wall 20 -- sh -c 'sleep 120' >/dev/null 2>&1 &
RPID=$!
for _ in $(seq 1 25); do [ -f untracked/runs/TRKILLR.json ] && break; sleep 0.2; done
if [ ! -f untracked/runs/TRKILLR.json ]; then
    echo "    FAIL: no launch record appeared"
    FAIL=1
else
    RUNNER_PID=$(python3 -c 'import json;print(json.load(open("untracked/runs/TRKILLR.json"))["pid"])')
    PGID=$(python3 -c 'import json;print(json.load(open("untracked/runs/TRKILLR.json"))["pgid"])')
    LEFTOVERS="$LEFTOVERS $PGID"
    kill -9 "$RUNNER_PID"
    wait "$RPID" 2>/dev/null
    if [ -f untracked/runs/TRKILLR.json ] && ! grep -q '"exit"' untracked/runs/TRKILLR.json && \
       ! grep -q '"signal"' untracked/runs/TRKILLR.json && grep -q '"pid"' untracked/runs/TRKILLR.json; then
        echo "    PASS: launch record survives with pid/start, no exit fields (killed mid-flight)"
    else
        echo "    FAIL: record after runner SIGKILL:"
        cat untracked/runs/TRKILLR.json 2>/dev/null | sed 's/^/      /'
        FAIL=1
    fi
fi

# ── D-H: need a managent binary carrying reap ─────────────────────────────
if [ "$HAVE_REAP" -eq 1 ]; then

# Seed the kanban: four in_progress rows matching the four incident shapes.
cat > "$STORE" <<'JSONEOF'
{
  "TORPH1": {"status":"in_progress","agent":"deepseek-v4-flash","model":"deepseek-v4-flash","bundle":"untracked/T364-bundle.md","set":"G","holds":[],"needs":[],"caps":[],"added":"2026-08-20T02:00:00Z","claimed":"2026-08-20T02:00:00Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"claim_count":1},
  "TORPH2": {"status":"in_progress","agent":"glm-5.2","model":"glm-5.2","bundle":"untracked/T364-bundle.md","set":"G","holds":[],"needs":[],"caps":[],"added":"2026-08-20T02:00:00Z","claimed":"2026-08-20T02:00:00Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"claim_count":1},
  "TORPH3": {"status":"in_progress","agent":"glm-5.2","model":"glm-5.2","bundle":"untracked/T364-bundle.md","set":"G","holds":[],"needs":[],"caps":[],"added":"2026-08-20T02:00:00Z","claimed":"2026-08-20T02:00:00Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"claim_count":1},
  "TALIVE": {"status":"in_progress","agent":"deepseek-v4-flash","model":"deepseek-v4-flash","bundle":"untracked/T364-bundle.md","set":"G","holds":[],"needs":[],"caps":[],"added":"2026-08-20T02:00:00Z","claimed":"2026-08-20T02:00:00Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"claim_count":1},
  "TBEATHB": {"status":"in_progress","agent":"deepseek-v4-flash","model":"deepseek-v4-flash","bundle":"untracked/T364-bundle.md","set":"G","holds":[],"needs":[],"caps":[],"added":"2026-08-20T02:00:00Z","claimed":"2026-08-20T02:00:00Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"claim_count":1},
  "_sys": {"next_id": 9000, "directive_next": 1}
}
JSONEOF

# A real sleeping worker backs TALIVE (idle-but-alive, bar F).
sleep 300 & ALIVE_PID=$!
LEFTOVERS="$LEFTOVERS $ALIVE_PID"
mkdir -p untracked/runs
cat > untracked/runs/TALIVE.json <<EOF
{"command": "sh -c 'sleep 300'", "launcher_pid": 1, "pgid": $ALIVE_PID, "pid": $ALIVE_PID, "start": "2026-08-20T02:50:00Z", "task": "TALIVE"}
EOF
# TORPH1: dead runner, completed record — run ended, row never closed.
cat > untracked/runs/TORPH1.json <<'EOF'
{"command": "zig build test", "cpu": 1.0, "end": "2026-08-20T02:51:00Z", "exit": 0, "launcher_pid": 1, "pgid": 999991, "pid": 999991, "rss_mb": 5, "signal": null, "start": "2026-08-20T02:50:00Z", "task": "TORPH1", "wall": 60.0}
EOF
# TORPH2: dead runner, launch record only — killed mid-flight (arm C's shape).
cat > untracked/runs/TORPH2.json <<'EOF'
{"command": "sh -c 'sleep 120'", "launcher_pid": 1, "pgid": 999992, "pid": 999992, "start": "2026-08-20T02:50:00Z", "task": "TORPH2"}
EOF
# TORPH3: no record at all, never beat.
# TBEATHB: fresh heartbeat, no run record (bar G).
NOWTS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cat > untracked/heartbeat.jsonl <<EOF
{"command": "zig build", "cpu": 0.0, "identifier": "TBEATHB", "rss_mb": 1, "task": "TBEATHB", "ts": "$NOWTS", "wall": 0.5}
EOF

echo "  D. seeded reap report: exactly the three orphans are named, the live rows are not"
OUT=$("$MG" reap 2>/dev/null)
RC=$?
if [ "$RC" -ne 0 ]; then
    echo "    FAIL: reap exit $RC"
    FAIL=1
else
    for t in TORPH1 TORPH2 TORPH3; do
        if echo "$OUT" | grep -q "\[ORPHAN\]" && echo "$OUT" | grep -q "$t"; then :; else
            echo "    FAIL: orphan $t not reported"
            FAIL=1
        fi
    done
    if echo "$OUT" | grep -q "TORPH1.*no live process" && \
       echo "$OUT" | grep -q "TORPH2.*killed mid-flight" && \
       echo "$OUT" | grep -q "TORPH3.*never beat"; then
        echo "    PASS: evidence names each failure class (run ended / killed mid-flight / never beat)"
    else
        echo "    FAIL: evidence missing; output:"
        echo "$OUT" | sed 's/^/      /'
        FAIL=1
    fi
    # bars E/F/G: the live and heartbeat rows are reported alive, never reaped
    if echo "$OUT" | grep -q "TALIVE.*BACKED" && echo "$OUT" | grep -q "TBEATHB.*BACKED"; then
        echo "    PASS: live worker (TALIVE) and heartbeat-backed row (TBEATHB) reported BACKED"
    else
        echo "    FAIL: a live row was not reported BACKED; output:"
        echo "$OUT" | sed 's/^/      /'
        FAIL=1
    fi
    if echo "$OUT" | grep -qE "TALIVE.*ORPHAN|TBEATHB.*ORPHAN"; then
        echo "    FAIL: an alive/beating row shows ORPHAN — the null control is broken"
        FAIL=1
    fi
fi

echo "  E/F/G. seeded reap --close: only the orphans close; the live rows survive"
OUT=$("$MG" reap --close 2>/dev/null)
if echo "$OUT" | grep -q "closed 3 orphan(s)"; then :; else
    echo "    FAIL: --close did not close 3 orphans; output:"
    echo "$OUT" | sed 's/^/      /'
    FAIL=1
fi
python3 - "$STORE" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
for t in ("TORPH1", "TORPH2", "TORPH3"):
    ts = d[t]
    if ts.get("status") != "done" or ts.get("verdict") != "abandoned":
        print(f"    FAIL: {t} not closed abandoned: {ts.get('status')}/{ts.get('verdict')}")
        sys.exit(1)
    note = ts.get("verdict_note") or ""
    if not note.startswith("reaped:") or "no live process" not in note:
        print(f"    FAIL: {t} note lacks the evidence: {note}")
        sys.exit(1)
for t in ("TALIVE", "TBEATHB"):
    if d[t].get("status") != "in_progress":
        print(f"    FAIL: live row {t} was reaped! status={d[t].get('status')}")
        sys.exit(1)
print("    PASS: 3 orphans closed abandoned with evidence in the note; TALIVE/TBEATHB still in_progress")
PYEOF
[ $? -ne 0 ] && FAIL=1

echo "  H. resume surface: the orphan is flagged; with none left, the section says so"
# Re-open TORPH1 to give resume an orphan to show (TALIVE is still alive/backed).
python3 - "$STORE" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
d["TORPH1"]["status"] = "in_progress"; d["TORPH1"]["done"] = None
d["TORPH1"]["verdict"] = None; d["TORPH1"]["verdict_note"] = None
json.dump(d, open(sys.argv[1], "w"), indent=1)
PYEOF
OUT=$("$MG" resume 2>/dev/null)
if echo "$OUT" | grep -q "fleet stalls" && echo "$OUT" | grep -q "TORPH1.*ORPHAN"; then
    echo "    PASS: resume flags the orphaned row"
else
    echo "    FAIL: resume does not flag the orphan:"
    echo "$OUT" | sed -n '/fleet stalls/,+4p' | sed 's/^/      /'
    FAIL=1
fi
"$MG" reap --close >/dev/null 2>&1
OUT=$("$MG" resume 2>/dev/null)
if echo "$OUT" | grep -q "fleet stalls" && echo "$OUT" | grep -q -- "-- none --"; then
    echo "    PASS: with no orphans the section says -- none --"
else
    echo "    FAIL: resume section does not say -- none -- after closing:"
    echo "$OUT" | sed -n '/fleet stalls/,+4p' | sed 's/^/      /'
    FAIL=1
fi

else
    echo '  D-H: SKIP (no managent binary carrying the reap command — Orchestrator integration)'
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-orphan-reaper: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-orphan-reaper: FAILURES ==="
    exit 1
fi
