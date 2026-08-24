#!/bin/sh
# regression-runner-brief-telemetry.sh — T520 controls: wall-kill telemetry.
#
# F8 (brief): 16/25 heals were exit-124 wall-kills — briefs too big for their
# wall.  The epidemic was anecdotal because nothing recorded the brief's
# size at dispatch, and nothing compared the chosen wall against the task
# class's observed need.  T520 ships two pieces:
#
#   1. tools/runner records `brief_bytes` (the bundle file size), `prompt_bytes`
#      (the `-p` argument the model ingests) and `wall_budget` (the --max-wall
#      fallback) in the run record (untracked/runs/<task>.json), so every
#      wall-kill is joinable to the brief that caused it.
#   2. tools/dispatch_verify.py carries per-task-class wall guidance
#      (spec/infra/verification/battery differ — sourced from the DELEGATOR
#      wall table) and a wall_advisory() that flags a wall budget below the
#      class recommendation for the brief it carried, surfaced as a
#      `[verify] wall-low:` detail at dispatch time.
#
# Controls (test-first, per the standing tooling rule):
#
#   A. runner records brief_bytes + prompt_bytes + wall_budget in the run
#      record (env identity, no managent needed).
#   B. WALL_GUIDANCE has spec/infra/battery as DISTINCT values, and
#      recommended_wall escalates one row when the brief is large.
#   C. classify_task_type classifies battery/verification/spec bundles by
#      keyword (battery > verification > spec > infra).
#   D. wall_advisory flags an inadequate wall and is silent on an adequate
#      one.
#   E. verify_dispatch surfaces the wall-low advisory as a detail when the
#      run record shows a too-low wall for the brief's class (hermetic
#      scratch store — no managent needed).
#
# Everything runs in a scratch git repo under /tmp/weizigo — the live kanban,
# live untracked/ and the live repo are never touched. The claimlint floor
# is untouched by design (no doc or claim changes).
#
# Task: T520 · Role: worker · Model: glm-5.2 · Date: 2026-08-20

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

weizigo_scratch_repo t520-brief WORK   # T849: isolated scratch repo
cd "$WORK"
git config user.email t520@test
git config user.name T520
echo base > README.md
mkdir -p docs/infra/managent untracked/runs
printf 'untracked/\n' > .gitignore
git add README.md .gitignore
git commit -qm base

note() { echo "$*"; }
pass() { echo "    PASS: $*"; }
fail() { echo "    FAIL: $*"; FAIL=1; }

echo "=== regression-runner-brief-telemetry (T520) ==="

PY="python3"
# Dispatch the python helper with the project tools/ on the path so it can
# import dispatch_verify without copying it.
pycmd() {
    PYTHONPATH="$PROJECT/tools:${PYTHONPATH:-}" "$PY" -c "$1"
}

# ── A. runner records brief_bytes + prompt_bytes + wall_budget ────────────
echo "  A. runner records brief_bytes/prompt_bytes/wall_budget in the run record"
# A 100-byte bundle for T5201.
mkdir -p untracked
"$PY" -c 'open("untracked/T5201-synth.md","wb").write(b"X"*100)'
export MANAGENT_TASK_ID=T5201
"$RUNNER" --no-prepend-zig --no-host-guard --max-wall 42 -- \
    "$PY" -c 'import sys;print("ok")' -p "hello brief" >/dev/null 2>&1
RC=$?
unset MANAGENT_TASK_ID
if [ "$RC" -ne 0 ]; then
    fail "arm A run exited $RC (expected 0)"
else
    pass "arm A run exited 0"
fi
if [ -f untracked/runs/T5201.json ]; then
    BRIEF=$("$PY" -c 'import json;d=json.load(open("untracked/runs/T5201.json"));print(d.get("brief_bytes"))' 2>/dev/null || echo MISS)
    PROMPT=$("$PY" -c 'import json;d=json.load(open("untracked/runs/T5201.json"));print(d.get("prompt_bytes"))' 2>/dev/null || echo MISS)
    WB=$("$PY" -c 'import json;d=json.load(open("untracked/runs/T5201.json"));print(d.get("wall_budget"))' 2>/dev/null || echo MISS)
    if [ "$BRIEF" = "100" ]; then pass "brief_bytes == 100 (bundle size)"; else fail "brief_bytes is '$BRIEF', expected 100"; fi
    # len(b"hello brief") == 11
    if [ "$PROMPT" = "11" ]; then pass "prompt_bytes == 11 (the -p argument)"; else fail "prompt_bytes is '$PROMPT', expected 11"; fi
    if [ "$WB" = "42" ]; then pass "wall_budget == 42 (the --max-wall fallback)"; else fail "wall_budget is '$WB', expected 42"; fi
else
    fail "no untracked/runs/T5201.json written"
fi

# ── B. WALL_GUIDANCE distinct + recommended_wall escalates on large brief ──
echo "  B. WALL_GUIDANCE: spec/infra/battery differ; recommended_wall escalates"
pycmd "
import dispatch_verify as d
g = d.WALL_GUIDANCE
assert g['spec'] != g['infra'] != g['battery'], 'spec/infra/battery must differ'
assert g['spec'] < g['infra'] < g['battery'], 'expected spec<infra<battery'
# small brief -> base
assert d.recommended_wall('spec', 100) == g['spec'], 'small spec brief -> base wall'
# large brief -> escalates one row
assert d.recommended_wall('spec', 100000) > g['spec'], 'large spec brief must escalate'
# battery is already the top row -> stays capped
assert d.recommended_wall('battery', 100000) == g['battery'], 'battery caps at top row'
print('OK B')
" && pass "WALL_GUIDANCE distinct + escalation" || fail "WALL_GUIDANCE/ recommended_wall contract broken"

# ── C. classify_task_type by keyword (battery > verification > spec > infra)
echo "  C. classify_task_type: keyword classifier"
mkdir -p untracked
: > untracked/T5202-battery-sweep.md
: > untracked/T5203-spec-design.md
: > untracked/T5204-infra-tooling.md
pycmd "
import dispatch_verify as d
assert d.classify_task_type('$WORK','T5202') == 'battery', 'T5202 -> battery'
assert d.classify_task_type('$WORK','T5203') == 'spec', 'T5203 -> spec'
assert d.classify_task_type('$WORK','T5204') == 'infra', 'T5204 -> infra (default)'
print('OK C')
" && pass "classify_task_type keyword rule" || fail "classify_task_type misclassified"

# ── D. wall_advisory flags inadequate, silent on adequate ───────────────────
echo "  D. wall_advisory: inadequate wall flagged, adequate silent"
# A large battery brief under a tiny wall.
"$PY" -c 'open("untracked/T5205-battery-sweep.md","wb").write(b"Z"*20000)'
pycmd "
import dispatch_verify as d
typ, rec, ok, line = d.wall_advisory('$WORK','T5205', wall_budget=1800, brief_bytes=20000)
assert typ == 'battery', typ
assert rec == d.WALL_GUIDANCE['battery'], rec
assert ok is False, 'wall 1800 < battery recommended must be inadequate'
assert 'wall-low' in line, 'advisory line must name wall-low'
typ2, rec2, ok2, line2 = d.wall_advisory('$WORK','T5205', wall_budget=d.WALL_GUIDANCE['battery'], brief_bytes=20000)
assert ok2 is True, 'adequate wall must be silent'
assert line2 == '', 'adequate wall must produce no line'
print('OK D')
" && pass "wall_advisory inadequate/adequate" || fail "wall_advisory contract broken"

# ── E. verify_dispatch surfaces wall-low as a detail (hermetic store) ──────
echo "  E. verify_dispatch: wall-low detail surfaced on a closed row"
# Scratch store: T5206 is done with verdict=pass.
mkdir -p docs/infra/managent
"$PY" - <<'PYEOF'
import json, os
store = {"T5206": {"status":"done","verdict":"pass",
                   "bundle":"untracked/T5206-battery-sweep.md"}}
json.dump(store, open("docs/infra/managent/tasks.json","w"))
# A large battery bundle + a run record with a too-low wall budget.
open("untracked/T5206-battery-sweep.md","wb").write(b"Q"*20000)
import json as j
rec = {"task":"T5206","brief_bytes":20000,"prompt_bytes":21000,
       "wall_budget":1800,"killed":"wall ceiling 1800s reached"}
j.dump(rec, open("untracked/runs/T5206.json","w"))
PYEOF
pycmd "
import dispatch_verify as d
import os
store_env = os.path.join('$WORK','docs','infra','managent','tasks.json')
rc, summ, details, perf = d.verify_dispatch(
    root='$WORK', task_id='T5206', model='glm-5.2', nonce='NONCE-X', stdout='NONCE-X done',
    rc=0, store_env=store_env, deliverables=[])
joined = '\n'.join(details)
assert 'wall-low' in joined, 'verify_dispatch must surface the wall-low detail; details=%r' % (details,)
print('OK E')
" && pass "verify_dispatch surfaces wall-low detail" || fail "verify_dispatch did not surface wall-low"

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "regression-runner-brief-telemetry: ALL CONTROLS PASSED"
    exit 0
else
    echo "regression-runner-brief-telemetry: FAILURES"
    exit 1
fi