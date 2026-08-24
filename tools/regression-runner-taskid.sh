#!/usr/bin/env bash
# regression-runner-taskid.sh — T515 controls: run records are task-id-named,
# never pid-named (Course row A5 / F6).
#
# The defect (2026-08-20, reconciled by ORCHA-flash): run records landed under
# `untracked/runs/runner_<pid>.json` whenever a launch site forgot to propagate
# a task identity (no --task-id, no MANAGENT_TASK_ID). 30 such stragglers
# accumulated in untracked/runs/ and were archived to archive-2026-08-20/.
# `managent reap` keys records to rows by the `task` field, so a
# `runner/<pid>` record matches no row — pure noise that recurs until the
# source stops emitting it.
#
# The fix (T515): tools/runner stamps a task id on every record it WRITES. A
# degraded run (no identity) is unattributable, so it writes NO run record at
# all — eliminating pid-named records at the source. Heartbeats still land
# under the loud `runner/<pid>` fallback (T370's visibility fix, unchanged);
# the brief is about run records, not heartbeats.
#
# Controls (test-first, per the standing tooling rule):
#
#   A. task-id-named record (env var): a run with MANAGENT_TASK_ID set writes
#      untracked/runs/<task>.json (not runner_<pid>.json) and the record's
#      `task` field is the task id.
#   B. no pid-named record in degraded mode (the whole point): a run with
#      NO identity writes NO runner_*.json file in untracked/runs/.
#   C. degraded run still warns loudly (T370 preserved): the no-identity run
#      prints the WARNING and names the runner/<pid> heartbeat fallback.
#   D. --task-id flag names the record too (same naming path): SKIP when no
#      managent binary is available (auto-claim/done need it); otherwise seed
#      a dispatchable task and assert <task>.json lands.
#
# Everything runs in a scratch repo under /tmp/weizigo — the live kanban, live
# untracked/ and the live repo are never touched. The claimlint floor is
# untouched by design (no doc or claim changes).
#
# Binary resolution for arm D: $MANAGENT_BIN → zig-out/bin/managent →
# bin/managent, same convention as regression-orphan-reaper.sh.
#
# Task: T515 · Role: worker · Model: glm-5.2 · Date: 2026-08-20

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
RUNNER="$PROJECT/tools/runner"
FAIL=0

# T849: scratch repo via the ONE isolated helper (unset GIT_DIR… before git
# init); safe to run outside the pre-commit hook. T445 refuse-on-failure is
# preserved by the helper.
. "$PROJECT/tools/lib/scratch-repo.sh"

cleanup() {
    [ -n "${WORK:-}" ] && rm -rf "$WORK"
}
trap cleanup EXIT

# T445: /tmp/weizigo decays; refuse to run if scratch creation fails (an
# empty scratch var once sent a suite's arms into the LIVE repo).
weizigo_scratch_repo t515-taskid WORK   # T849: isolated scratch repo
cd "$WORK"
git config user.email t515@test
git config user.name T515
echo base > README.md
mkdir -p docs/infra/managent untracked
printf 'untracked/\n' > .gitignore
git add README.md .gitignore
git commit -qm base

# ── managent binary resolution (arm D only) ───────────────────────────────
MG="${MANAGENT_BIN:-}"
if [ -z "$MG" ]; then
    if [ -x "$PROJECT/zig-out/bin/managent" ]; then
        MG="$PROJECT/zig-out/bin/managent"
    elif [ -x "$PROJECT/bin/managent" ]; then
        MG="$PROJECT/bin/managent"
    fi
fi
HAVE_MG=0
if [ -n "$MG" ] && [ -x "$MG" ]; then
    HAVE_MG=1
fi

note() { echo "$*"; }
pass() { echo "    PASS: $*"; }
fail() { echo "    FAIL: $*"; FAIL=1; }

echo "=== regression-runner-taskid (T515) ==="

# ── A. task-id-named record (env var) ──────────────────────────────────────
echo "  A. env identity: record is task-id-named, not pid-named"
export MANAGENT_TASK_ID=T515A
"$RUNNER" --no-prepend-zig --no-host-guard --max-wall 20 -- sh -c 'echo hi; sleep 0.1' >/dev/null 2>&1
RC=$?
unset MANAGENT_TASK_ID
if [ "$RC" -ne 0 ]; then
    fail "env run exited $RC (expected 0)"
else
    pass "env run exited 0"
fi
if [ -f untracked/runs/T515A.json ]; then
    TASK_FIELD=$(python3 -c 'import json;print(json.load(open("untracked/runs/T515A.json")).get("task",""))' 2>/dev/null || true)
    if [ "$TASK_FIELD" = "T515A" ]; then
        pass "record task field is T515A"
    else
        fail "record task field is '$TASK_FIELD', expected T515A"
    fi
else
    fail "no untracked/runs/T515A.json written"
fi
# the defect: a pid-named file must NOT appear alongside it
PID_FILES=$(ls untracked/runs/runner_*.json 2>/dev/null || true)
if [ -z "$PID_FILES" ]; then
    pass "no pid-named runner_*.json created"
else
    fail "pid-named record created (the F6 defect): $PID_FILES"
fi

# ── B. degraded run writes NO pid-named record (the whole point) ────────────
echo "  B. degraded: no identity → no pid-named run record"
# clear the runs dir so any leftover from arm A is not counted
rm -f untracked/runs/*.json
env -u MANAGENT_TASK_ID "$RUNNER" --no-prepend-zig --no-host-guard --max-wall 20 -- sh -c 'echo hi; sleep 0.1' >/dev/null 2>&1
RC=$?
if [ "$RC" -ne 0 ]; then
    fail "degraded run exited $RC (expected 0 — runner stays general-purpose)"
else
    pass "degraded run still exits 0 (general-purpose wrapper preserved)"
fi
ANY_RECORD=$(ls untracked/runs/*.json 2>/dev/null || true)
if [ -z "$ANY_RECORD" ]; then
    pass "degraded run wrote NO run record (no pid-named noise)"
else
    fail "degraded run wrote a record (the F6 defect): $ANY_RECORD"
fi
PID_FILES=$(ls untracked/runs/runner_*.json 2>/dev/null || true)
if [ -z "$PID_FILES" ]; then
    pass "degraded run wrote NO runner_*.json"
else
    fail "degraded run wrote a pid-named record: $PID_FILES"
fi

# ── C. degraded run still warns loudly (T370 preserved) ────────────────────
echo "  C. degraded: T370 loud warning preserved (heartbeats still land under runner/<pid>)"
OUT=$(env -u MANAGENT_TASK_ID "$RUNNER" --no-prepend-zig --no-host-guard --max-wall 20 -- sh -c 'sleep 0.1' 2>&1 || true)
if echo "$OUT" | grep -q "WARNING: no task identity"; then
    pass "no-identity run warns loudly"
else
    fail "no-identity run did not warn"
fi
if echo "$OUT" | grep -q "heartbeats will land under 'runner/"; then
    pass "warning names the runner/<pid> heartbeat fallback (T370)"
else
    fail "warning did not name the heartbeat fallback"
fi
if echo "$OUT" | grep -q "export MANAGENT_TASK_ID=<task-id>"; then
    pass "warning names the fix"
else
    fail "warning did not name the fix"
fi
# T515 addition: the warning must say NO run record is written
if echo "$OUT" | grep -qi "no run record"; then
    pass "warning states no run record is written (F6/T515)"
else
    fail "warning did not state the no-record behavior"
fi

# ── D. --task-id flag names the record (same naming path, auto-claim/done) ─
echo "  D. --task-id flag: record is task-id-named (needs managent; SKIP if absent)"
if [ "$HAVE_MG" -eq 0 ]; then
    note "    SKIP: no managent binary available (auto-claim/done need it)"
else
    STORE="$WORK/docs/infra/managent/tasks.json"
    export MANAGENT_STORE="$STORE"
    cat > "$STORE" <<EOF
{"T515D": {"status":"dispatchable","agent":null,"model":"glm-5.2","bundle":"untracked/T515D-x.md","set":"G","holds":[],"needs":[],"caps":[],"added":"2026-08-20T00:00:00Z","claimed":null,"done":null,"dispatched":null,"dispatched_to":null,"note":null,"claim_count":0},
  "_sys": {"next_id": 515, "directive_next": 1}
}
EOF
    echo "# T515D bundle" > untracked/T515D-x.md
    # clear stale records from arms B/C so the pid-named check is clean
    rm -f untracked/runs/*.json
    # the runner's auto-claim resolves bin/managent relative to repo_root
    # (the temp repo), so expose the resolved binary there.
    mkdir -p bin
    ln -sf "$MG" bin/managent
    export PI_MODEL=glm-5.2
    # --task-id triggers the runner's auto-claim (T515D is dispatchable) and
    # auto-done on exit 0; the runner claims the row itself.
    set +e
    "$RUNNER" --no-prepend-zig --no-host-guard --max-wall 20 --task-id T515D -- sh -c 'echo hi; sleep 0.1' >/dev/null 2>&1
    RC=$?
    set -e
    unset PI_MODEL MANAGENT_STORE
    if [ -f untracked/runs/T515D.json ]; then
        TASK_FIELD=$(python3 -c 'import json;print(json.load(open("untracked/runs/T515D.json")).get("task",""))' 2>/dev/null || true)
        if [ "$TASK_FIELD" = "T515D" ]; then
            pass "--task-id record is T515D-named with task field T515D"
        else
            fail "--task-id record task field is '$TASK_FIELD', expected T515D"
        fi
    else
        fail "no untracked/runs/T515D.json written"
    fi
    PID_FILES=$(ls untracked/runs/runner_*.json 2>/dev/null || true)
    if [ -n "$PID_FILES" ]; then
        fail "--task-id run also wrote a pid-named record: $PID_FILES"
    fi
fi

# ── E. degraded claude lane still forwards text (T566) ──────────────────────
# The 2026-08-22 race-#1 defect: _forward_claude_text was gated on token
# capture, and token capture was gated on record_root — so a claude
# --output-format json lane with no task identity produced 0-byte stdout.
# Pin: text must always forward; only recording is gated on identity.
echo "  E. degraded claude lane forwards text (no silent 0-byte)"
cat > "$WORK/claude_env.py" <<'PYEOF'
import json
print(json.dumps({"result": "degraded lane text",
                  "usage": {"input_tokens": 5, "output_tokens": 3,
                            "cache_read_input_tokens": 0, "cache_creation_input_tokens": 0}}))
PYEOF
set +e
env -u MANAGENT_TASK_ID "$RUNNER" --no-prepend-zig --no-host-guard --max-wall 20 -- \
    python3 "$WORK/claude_env.py" --output-format json \
    > "$WORK/t566.stdout" 2> "$WORK/t566.stderr"
set -e
if [ -s "$WORK/t566.stdout" ] && grep -q "degraded lane text" "$WORK/t566.stdout"; then
    pass "degraded claude lane text forwarded (not 0-byte)"
else
    fail "degraded claude lane text not forwarded: stdout='$(cat "$WORK/t566.stdout" 2>/dev/null)'"
fi
if grep -q "WARNING: no task identity" "$WORK/t566.stderr"; then
    pass "degraded claude lane warns loudly on stderr"
else
    fail "degraded claude lane did not warn"
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "regression-runner-taskid: ALL CONTROLS PASSED"
else
    echo "regression-runner-taskid: FAILURES"
    exit 1
fi