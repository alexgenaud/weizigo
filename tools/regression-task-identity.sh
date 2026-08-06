#!/usr/bin/env bash
# regression-task-identity.sh — controls for task-identity propagation (T370).
#
# The defect (2026-08-05, found by the incoming Orcha seat): every real run
# fell to the runner/<pid> identity fallback, so `managent liveness` could
# not attribute beats and `managent tell <id>` directives could not reach a
# running worker.  This regression pins the fix:
#
#   1. loud fallback — a run with NO identity warns that liveness and
#      directives are disabled (a degraded mode nobody can see is how the
#      fleet ran blind);
#   2. heartbeat attribution — MANAGENT_TASK_ID on the child lands beats
#      under the task;
#   3. liveness states — never beat / beats stopped / beating are distinct;
#   4. killed mid-run reads dead within one interval (real SIGKILL);
#   5. directive lands at launch (seeded) and mid-run (seeded), and a
#      directive for a DIFFERENT task does not fire (null control).
#
# Everything runs in a temp repo (/tmp/weizigo — disposable): the runner
# finds the repo root by walking up from cwd, and managent reads the same
# store, so the real untracked/heartbeat.jsonl is never touched.
#
# Requires a freshly deployed bin/managent (run `zig build deploy` first —
# the liveness state controls exercise the deployed binary).
#
# Task: T370 · Role: worker · Model: flash · Date: 2026-08-06

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
RUNNER="$PROJECT/tools/runner"
MG="$PROJECT/bin/managent"

# T370's own identifier for the heartbeat-attribution control.
CTL_TASK="T370CTL"

# ── setup: temp repo ─────────────────────────────────────────────────────────
TMP="$(mktemp -d /tmp/weizigo/t370-identity-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

git init -q "$TMP"
mkdir -p "$TMP/docs/infra/managent" "$TMP/untracked"

seed_store() {
    # $1 = JSON body of tasks (without _sys); adds _sys.
    cat > "$TMP/docs/infra/managent/tasks.json" <<EOF
{$1,
  "_sys": {"next_id": 370, "directive_next": 1}
}
EOF
}

seed_heartbeats() {
    # $1 = lines to append to the temp heartbeat file
    cat >> "$TMP/untracked/heartbeat.jsonl" <<EOF
$1
EOF
}

tick_script="$TMP/tick.py"
cat > "$tick_script" <<'PYEOF'
import sys, time
for i in range(200):
    print("[progress] tick", i, file=sys.stderr, flush=True)
    time.sleep(0.4)
PYEOF
# Short ticker for the null control (must COMPLETE normally, exit 0).
short_tick_script="$TMP/short-tick.py"
cat > "$short_tick_script" <<'PYEOF'
import sys, time
for i in range(4):
    print("[progress] tick", i, file=sys.stderr, flush=True)
    time.sleep(0.4)
PYEOF

FAIL=0
note() { echo "$*"; }
pass() { echo "    PASS: $*"; }
fail() { echo "    FAIL: $*"; FAIL=1; }

echo "=== regression-task-identity (T370) ==="

# ── 1. loud fallback: no identity warns, degraded mode is visible ────────────
echo "  1. loud fallback"
OUT=$(cd "$TMP" && env -u MANAGENT_TASK_ID "$RUNNER" --no-prepend-zig -- sleep 0.2 2>&1 || true)
if echo "$OUT" | grep -q "WARNING: no task identity"; then
    pass "no-identity run warns loudly"
else
    fail "no-identity run did not warn: $OUT"
fi
if echo "$OUT" | grep -q "heartbeats will land under 'runner/"; then
    pass "warning names the runner/<pid> fallback"
else
    fail "warning did not name the fallback identity"
fi
if echo "$OUT" | grep -q "export MANAGENT_TASK_ID=<task-id>"; then
    pass "warning names the fix (export MANAGENT_TASK_ID)"
else
    fail "warning did not name the fix"
fi

# ── 2. heartbeat attribution: env identity lands under the task ──────────────
echo "  2. heartbeat attribution"
seed_store '"T370B": {"status":"in_progress","agent":"test","bundle":"untracked/T370B-x.md","set":"G","holds":[],"needs":[],"caps":[],"added":"2026-08-06T00:00:00Z","claimed":"2026-08-06T01:00:00Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"claim_count":1}'
(cd "$TMP" && MANAGENT_TASK_ID="$CTL_TASK" "$RUNNER" --no-prepend-zig -- sleep 0.3 >/dev/null 2>&1)
if grep -q '"task": "'"$CTL_TASK"'"' "$TMP/untracked/heartbeat.jsonl"; then
    pass "heartbeat landed under $CTL_TASK"
else
    fail "no heartbeat for $CTL_TASK in $TMP/untracked/heartbeat.jsonl"
fi

# ── 3. liveness distinguishes the three states ───────────────────────────────
echo "  3. liveness states"
seed_store '"T370A": {"status":"in_progress","agent":"test","bundle":"untracked/T370A-x.md","set":"G","holds":[],"needs":[],"caps":[],"added":"2026-08-06T00:00:00Z","claimed":"2026-08-06T01:00:00Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"claim_count":1},
  "T370B": {"status":"in_progress","agent":"test","bundle":"untracked/T370B-x.md","set":"G","holds":[],"needs":[],"caps":[],"added":"2026-08-06T00:00:00Z","claimed":"2026-08-06T01:00:00Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"claim_count":1},
  "T370C": {"status":"in_progress","agent":"test","bundle":"untracked/T370C-x.md","set":"G","holds":[],"needs":[],"caps":[],"added":"2026-08-06T00:00:00Z","claimed":"2026-08-06T01:00:00Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"claim_count":1}'
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
OLD="2026-08-04T00:00:00Z"
seed_heartbeats "{\"identifier\":\"test/T370B\",\"task\":\"T370B\",\"ts\":\"$NOW\",\"command\":\"echo live\",\"wall\":1.0,\"cpu\":0.1,\"rss_mb\":5}
{\"identifier\":\"test/T370C\",\"task\":\"T370C\",\"ts\":\"$OLD\",\"command\":\"echo dead\",\"wall\":10.0,\"cpu\":1.0,\"rss_mb\":50}"

LIVE_OUT=$(cd "$TMP" && "$MG" liveness 2>/dev/null)
if echo "$LIVE_OUT" | grep -q "T370A  \[never beat since dispatch"; then
    pass "never-beat state (no heartbeat since claim)"
else
    fail "T370A should read 'never beat since dispatch': $LIVE_OUT"
fi
if echo "$LIVE_OUT" | grep -q "T370B  \[beating\]"; then
    pass "beating state (recent beat)"
else
    fail "T370B should read 'beating': $LIVE_OUT"
fi
if echo "$LIVE_OUT" | grep -q "T370C  \[beats stopped"; then
    pass "beats-stopped state (old beat)"
else
    fail "T370C should read 'beats stopped': $LIVE_OUT"
fi
if echo "$LIVE_OUT" | grep -q "(1 beats)\|(2 beats)"; then
    pass "beat count shown for the task"
else
    fail "beat count missing: $LIVE_OUT"
fi

# ── 4. killed mid-run reads dead within one interval (real SIGKILL) ──────────
# NOTE: `exec` inside the paren subshell so $! is the RUNNER's pid, not a
# wrapper shell — kill -9 must remove the process that emits heartbeats.
echo "  4. killed mid-run reads dead within one interval"
seed_store '"T370K": {"status":"in_progress","agent":"test","bundle":"untracked/T370K-x.md","set":"G","holds":[],"needs":[],"caps":[],"added":"2026-08-06T00:00:00Z","claimed":"2026-08-06T01:00:00Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"claim_count":1}'
(cd "$TMP" && exec env MANAGENT_TASK_ID=T370K "$RUNNER" --no-prepend-zig -- python3 "$tick_script") >/dev/null 2>&1 &
RUNPID=$!
sleep 2
PRE=$(grep -c '"task": "T370K"' "$TMP/untracked/heartbeat.jsonl" || true)
if [ "$PRE" -eq 0 ]; then
    fail "no progress beats landed before the kill — runner heartbeat emission broken"
else
    pass "progress beats landed before kill ($PRE beats)"
fi
kill -9 "$RUNPID" 2>/dev/null || true
sleep 1
if (cd "$TMP" && LIVENESS_STALE_MIN=0.05 "$MG" liveness 2>/dev/null) | grep -q "T370K  \[beating\]"; then
    pass "still beating immediately after kill (within interval)"
else
    fail "T370K should still read beating right after kill"
fi
sleep 4
if (cd "$TMP" && LIVENESS_STALE_MIN=0.05 "$MG" liveness 2>/dev/null) | grep -q "T370K  \[beats stopped"; then
    pass "reads dead within one interval of the kill"
else
    fail "T370K should read 'beats stopped' after one interval"
fi
wait "$RUNPID" 2>/dev/null || true
# the child ticker (separate session) may outlive the killed runner; reap it
pkill -f "$tick_script" 2>/dev/null || true

# ── 5. directive lands at launch (seeded) ────────────────────────────────────
echo "  5. directive at launch"
seed_store '"T370L": {"status":"in_progress","agent":"test","bundle":"untracked/T370L-x.md","set":"G","holds":[],"needs":[],"caps":[],"added":"2026-08-06T00:00:00Z","claimed":"2026-08-06T01:00:00Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"claim_count":1}'
(cd "$TMP" && "$MG" tell T370L kill --from regression-t370 >/dev/null 2>&1)
set +e
(cd "$TMP" && MANAGENT_TASK_ID=T370L "$RUNNER" --no-prepend-zig -- sleep 0.5 >/dev/null 2>&1)
RC=$?
set -e
if [ "$RC" -eq 124 ]; then
    pass "runner exits 124 when a kill directive is pending at launch"
else
    fail "expected exit 124 for pending kill, got $RC"
fi

# ── 6. directive lands in a RUNNING runner (seeded) + null control ───────────
echo "  6. directive mid-run"
seed_store '"T370M": {"status":"in_progress","agent":"test","bundle":"untracked/T370M-x.md","set":"G","holds":[],"needs":[],"caps":[],"added":"2026-08-06T00:00:00Z","claimed":"2026-08-06T01:00:00Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"claim_count":1},
  "T370N": {"status":"in_progress","agent":"test","bundle":"untracked/T370N-x.md","set":"G","holds":[],"needs":[],"caps":[],"added":"2026-08-06T00:00:00Z","claimed":"2026-08-06T01:00:00Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"claim_count":1}'

# seeded: pause lands while T370M's runner is executing
(cd "$TMP" && exec env MANAGENT_TASK_ID=T370M "$RUNNER" --no-prepend-zig --directive-poll-s 1 -- python3 "$tick_script") >/dev/null 2>&1 &
RUNPID=$!
sleep 1.5
(cd "$TMP" && "$MG" tell T370M pause --from regression-t370 >/dev/null 2>&1)
set +e
wait "$RUNPID" 2>/dev/null
RC=$?
set -e
if [ "$RC" -eq 124 ]; then
    pass "pause directive landed mid-run (runner exit 124)"
else
    fail "expected mid-run pause to exit 124, got $RC"
fi
pkill -f "$tick_script" 2>/dev/null || true

# null: a directive for a DIFFERENT task must not stop T370N's run
(cd "$TMP" && exec env MANAGENT_TASK_ID=T370N "$RUNNER" --no-prepend-zig --directive-poll-s 1 -- python3 "$short_tick_script") >/dev/null 2>&1 &
RUNPID=$!
sleep 0.7
(cd "$TMP" && "$MG" tell T370OTHER pause --from regression-t370 >/dev/null 2>&1)
set +e
wait "$RUNPID" 2>/dev/null
RC=$?
set -e
if [ "$RC" -eq 0 ]; then
    pass "null control: directive for another task did not stop the run"
else
    fail "null control: expected exit 0, got $RC"
fi

# ── 7. claim instructs the worker to export identity ─────────────────────────
echo "  7. claim export hint"
seed_store '"T370C2": {"status":"dispatchable","agent":null,"model":"glm-5.2","bundle":"untracked/T370C2-x.md","set":"G","holds":[],"needs":[],"caps":[],"added":"2026-08-06T00:00:00Z","claimed":null,"done":null,"dispatched":null,"dispatched_to":null,"note":null,"claim_count":0}'
echo "# T370C2 — claim hint" > "$TMP/untracked/T370C2-x.md"
CLAIM_OUT=$(cd "$TMP" && "$MG" claim T370C2 --agent glm-5.2 2>&1 || true)
if echo "$CLAIM_OUT" | grep -q "export MANAGENT_TASK_ID=T370C2"; then
    pass "claim prints the export instruction"
else
    fail "claim did not print the export instruction: $CLAIM_OUT"
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "regression-task-identity: ALL CONTROLS PASSED"
else
    echo "regression-task-identity: FAILURES"
    exit 1
fi
