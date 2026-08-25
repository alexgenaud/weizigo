#!/usr/bin/env bash
# regression-sleep-guard.sh — T927 controls: a run's wall clock is protected
# from host idle sleep, and the run record says so honestly either way.
#
# The defect (2026-08-25): nothing in the dispatch path called `caffeinate`,
# so the host could idle-sleep mid-measurement and silently inflate the
# wall figure. `tools/runner` computes wall as `end - start`, folding any
# sleep into the number with no signal in the record. 2026-08-24 slept 24
# times (765-900 s each) — any wall figure taken that day is suspect, and
# nothing marked it.
#
# The fix (T927): `tools/runner` holds a `caffeinate -i -w <runner-pid>`
# assertion for the child's lifetime (auto-released on every exit path,
# including a SIGKILL of the runner — caffeinate's -w detects the pid gone).
# The run record gains `sleep_prevented` (true|false — was the assertion
# held?) and `sleeps_during_run` (N — "Entering Sleep" entries from
# `pmset -g log` whose timestamp falls in the run window). A run that slept
# is MARKED, not discarded — the reader decides. `sleep_prevented` is
# stamped at LAUNCH (survives a runner SIGKILL before finalize); the sleep
# count is stamped at finalize.
#
# Controls (test-first, per the standing tooling rule):
#
#   A. null (guard ON, short run, no sleep): the record carries
#      sleep_prevented=true and sleeps_during_run=0, and BOTH fields are
#      present (a missing key is the seeded-defect symptom, not the null).
#      RED (pre-T927): the fields are absent.
#   B. seeded-defect (assertion deliberately NOT taken via --no-sleep-guard):
#      sleep_prevented=false. The regression must catch that the assertion
#      was not held — a field that is absent or true is the broken-guard
#      symptom. RED (pre-T927): the field is absent.
#   C. seeded-defect (assertion NOT taken via WEIZIGO_SLEEP_GUARD=0): same
#      expectation as B, exercising the operator env override (the route
#      the brief names for an unattended fleet night where holding idle
#      sleep off is a power/thermal decision).
#   D. field-presence on a killed run: a wall-killed child still leaves
#      sleep_prevented on the launch record (the field is stamped before
#      spawn, so a SIGKILL of the runner cannot erase it).
#
# Everything runs in a scratch git repo under /tmp/weizigo — the live
# kanban, live untracked/ and the live repo are never touched. caffeinate
# and pmset are host commands and work anywhere; on a non-darwin host
# caffeinate is absent and arm A expects sleep_prevented=false with a
# reason (the guard honestly reports it could not hold the assertion).
#
# Task: T927 · Role: worker · Model: glm-5.2 · Date: 2026-08-25

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
RUNNER="$PROJECT/tools/runner"
FAIL=0

. "$PROJECT/tools/lib/scratch-repo.sh"

cleanup() {
    [ -n "${WORK:-}" ] && rm -rf "$WORK"
}
trap cleanup EXIT

weizigo_scratch_repo t927-sleepguard WORK   # T849: isolated scratch repo
cd "$WORK"
git config user.email t927@test
git config user.name T927
echo base > README.md
mkdir -p docs/infra/managent untracked/runs
printf 'untracked/\n' > .gitignore
git add README.md .gitignore
git commit -qm base

note() { echo "$*"; }
pass() { echo "    PASS: $*"; }
fail() { echo "    FAIL: $*"; FAIL=1; }

# Whether caffeinate is available on this host (arm A's expectation keys on
# it: held=true on darwin-with-caffeinate, false with a reason elsewhere).
HAS_CAFFEINATE=0
if command -v caffeinate >/dev/null 2>&1; then HAS_CAFFEINATE=1; fi

echo "=== regression-sleep-guard (T927) ==="
note "host: $(uname -s); caffeinate: $([ "$HAS_CAFFEINATE" = 1 ] && echo present || echo absent)"

# A short run whose window cannot contain a sleep (sub-second). The guard is
# held for the child's lifetime; no "Entering Sleep" can fall in the window.
OK_RUN() {
    MANAGENT_TASK_ID="$1" "$RUNNER" --no-prepend-zig --no-host-guard --max-wall 20 \
        -- sh -c 'echo ok; sleep 0.3' >/dev/null 2>&1
    return $?
}
KILL_RUN() {
    MANAGENT_TASK_ID="$1" "$RUNNER" --no-prepend-zig --no-host-guard --max-wall 2 \
        -- sh -c 'sleep 30' >/dev/null 2>&1
    return $?
}

# ── A. null: guard ON, short run, no sleep -> fields present, true/0 ───────
echo "  A. null: guard ON, short run, no sleep -> sleep_prevented=true, sleeps_during_run=0"
OK_RUN T927A; RC=$?
if [ "$RC" -ne 0 ]; then fail "ok-run exited $RC (expected 0)"; fi
if [ ! -f untracked/runs/T927A.json ]; then
    fail "no run record untracked/runs/T927A.json"
else
    python3 - <<'PY'
import json, os
d = json.load(open("untracked/runs/T927A.json"))
# Both fields MUST be present — a missing key is the seeded-defect symptom.
assert "sleep_prevented" in d, ("sleep_prevented absent", d)
assert "sleeps_during_run" in d, ("sleeps_during_run absent", d)
sp = d["sleep_prevented"]
sd = d["sleeps_during_run"]
import shutil
has_caff = shutil.which("caffeinate") is not None
if has_caff:
    assert sp is True, ("expected sleep_prevented=true (caffeinate present)", sp, d)
    assert sd == 0, ("expected sleeps_during_run=0 (sub-second window)", sd, d)
    print("        sleep_prevented=true, sleeps_during_run=0 (guard held, no sleep)")
else:
    # Non-darwin / no caffeinate: the guard honestly reports it could not hold.
    assert sp is False, ("expected sleep_prevented=false (no caffeinate)", sp, d)
    assert "sleep_prevented_reason" in d, ("reason absent", d)
    print("        sleep_prevented=false (caffeinate absent — honest), reason present")
PY
    [ $? -eq 0 ] && pass "null control: fields present and correct" || fail "null control: fields wrong/absent"
fi

# ── B. seeded-defect: --no-sleep-guard -> sleep_prevented=false ───────────
echo "  B. seeded-defect: --no-sleep-guard -> sleep_prevented=false (assertion NOT taken)"
MANAGENT_TASK_ID=T927B "$RUNNER" --no-prepend-zig --no-host-guard --max-wall 20 \
    --no-sleep-guard -- sh -c 'echo ok; sleep 0.3' >/dev/null 2>&1
RC=$?
if [ "$RC" -ne 0 ]; then fail "no-guard run exited $RC (expected 0)"; fi
if [ ! -f untracked/runs/T927B.json ]; then
    fail "no run record untracked/runs/T927B.json"
else
    python3 - <<'PY'
import json
d = json.load(open("untracked/runs/T927B.json"))
# The regression MUST catch that the assertion was not taken: the field is
# present AND false. Absent or true is the broken-guard symptom.
assert "sleep_prevented" in d, ("sleep_prevented absent (defect not detectable)", d)
assert d["sleep_prevented"] is False, ("expected false (assertion not taken)", d["sleep_prevented"], d)
print("        sleep_prevented=false — assertion deliberately not taken, regression detects it")
PY
    [ $? -eq 0 ] && pass "seeded-defect (--no-sleep-guard): field reflects guard OFF" || fail "seeded-defect (--no-sleep-guard): field wrong/absent"
fi

# ── C. seeded-defect: WEIZIGO_SLEEP_GUARD=0 -> sleep_prevented=false ──────
echo "  C. seeded-defect: WEIZIGO_SLEEP_GUARD=0 -> sleep_prevented=false (operator env override)"
WEIZIGO_SLEEP_GUARD=0 MANAGENT_TASK_ID=T927C "$RUNNER" --no-prepend-zig --no-host-guard --max-wall 20 \
    -- sh -c 'echo ok; sleep 0.3' >/dev/null 2>&1
RC=$?
if [ "$RC" -ne 0 ]; then fail "env-off run exited $RC (expected 0)"; fi
if [ ! -f untracked/runs/T927C.json ]; then
    fail "no run record untracked/runs/T927C.json"
else
    python3 - <<'PY'
import json
d = json.load(open("untracked/runs/T927C.json"))
assert "sleep_prevented" in d, ("sleep_prevented absent", d)
assert d["sleep_prevented"] is False, ("expected false (env override OFF)", d["sleep_prevented"], d)
print("        sleep_prevented=false — env override WEIZIGO_SLEEP_GUARD=0 honored")
PY
    [ $? -eq 0 ] && pass "seeded-defect (env=0): field reflects guard OFF" || fail "seeded-defect (env=0): field wrong/absent"
fi

# ── D. field-presence on a wall-killed run ────────────────────────────────
echo "  D. wall-killed run still carries sleep_prevented on the launch record"
KILL_RUN T927D; RC=$?
if [ "$RC" -ne 124 ]; then fail "kill-run exited $RC (expected 124)"; fi
if [ ! -f untracked/runs/T927D.json ]; then
    fail "no run record untracked/runs/T927D.json"
else
    python3 - <<'PY'
import json, shutil
d = json.load(open("untracked/runs/T927D.json"))
assert "sleep_prevented" in d, ("sleep_prevented absent on killed run", d)
has_caff = shutil.which("caffeinate") is not None
if has_caff:
    assert d["sleep_prevented"] is True, ("guard held even on a kill path", d["sleep_prevented"], d)
# sleeps_during_run is stamped at finalize; the kill path finalizes too.
assert "sleeps_during_run" in d, ("sleeps_during_run absent on killed run", d)
print("        killed run: sleep_prevented present", ("=true (held)" if d["sleep_prevented"] else "=false"), "sleeps_during_run present")
PY
    [ $? -eq 0 ] && pass "killed run carries the sleep fields" || fail "killed run lost the sleep fields"
fi

echo
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-sleep-guard: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-sleep-guard: FAILED ==="
    exit 1
fi