#!/usr/bin/env bash
# regression-runner-guard.sh — Runner guard and admission regression suite
#
# Regression test suite for tools/runner and admission/guard policies.
# Covers:
#   1. RAM admission refusal vs fit (docs/infra/host/ram-policy.md §4.1, ORC-GD-3/INV-3)
#   2. Wall-band RAM declaration at band boundaries (60 s, 600 s, 1800 s; §3.2)
#   3. Wall ceiling termination (--max-wall) and attribution (exit 124, killed_by="wall")
#   4. Memory overrun RSS cap kill (exit 124, killed_by="rss") and L3 kernel pressure alarm
#   5. Run record identity and kind declaration (dispatch vs nested; T895 reap integrity)
#   6. Default ReleaseFast optimization enforcement for Zig (2026-07-29 incident B-2)
#   7. Sleep guard (caffeinate -i -w) assertion and telemetry
#
# Task: T939 · Role: worker · Model: gemini-3.7-flash · Date: 2026-08-25

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/../../.." && pwd)"
RUNNER="$PROJECT/tools/runner"
SUBAGENT="$PROJECT/bin/subagent"

FAIL=0

mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/t939-guard-XXXXXX)" \
    || { echo "FATAL: scratch mktemp failed" >&2; exit 2; }

SCRATCH="$WORK/repo"
mkdir -p "$SCRATCH/untracked/runs/nested" "$SCRATCH/untracked/tokens/sessions" "$SCRATCH/bin" "$SCRATCH/docs/infra/managent"
( cd "$SCRATCH" && git init -q && printf 'untracked/\n' > .gitignore && git add -A && git commit -qm "init" )

# Symlink bin/managent for tools/runner helper invocations
ln -sf "$PROJECT/bin/managent" "$SCRATCH/bin/managent"

# Copy minimal docs needed for runner threshold fallbacks if any
mkdir -p "$SCRATCH/docs/infra"
if [ -f "$PROJECT/docs/infra/harness-p95.md" ]; then
    cp "$PROJECT/docs/infra/harness-p95.md" "$SCRATCH/docs/infra/"
fi

cleanup() {
    rm -rf "$WORK"
}
trap cleanup EXIT

echo "======================================================================"
echo "  T939 regression-runner-guard: tools/runner guard verification"
echo "======================================================================"

# ── Arm 1: RAM Admission Refusal vs Fit (ram-policy.md §4.1) ───────────────
echo ""
echo "── Arm 1: RAM Admission Refusal vs Fit (ram-policy.md §4.1) ────────"

# Scenario A: declared need exceeds host capacity (Avail - Committed - Need < 4608 Reserve)
# Avail=5000, Committed=0, Candidate=1000 -> Projected=4000 < 4608 -> MUST REFUSE (exit 3)
TOUCH_MARKER="$WORK/should_not_exist_arm1.txt"
rm -f "$TOUCH_MARKER"

set +e
(cd "$SCRATCH" && unset MANAGENT_RUN_IDENTITY && \
    WEIZIGO_HOST_MEM_AVAIL_MB=5000 \
    "$RUNNER" --ram-mb 1000 \
              --arbiter-state-file "$SCRATCH/untracked/arbiter-state.json" \
              -- touch "$TOUCH_MARKER") >/dev/null 2>&1
RC_REFUSE=$?
set -e

if [ "$RC_REFUSE" -eq 3 ] && [ ! -f "$TOUCH_MARKER" ]; then
    echo "  PASS 1a: declared RAM exceeding reserve is refused (exit 3, nothing spawned)"
else
    echo "  FAIL 1a: expected exit 3 and no child spawn; got exit $RC_REFUSE"
    FAIL=1
fi

# Scenario B: declared need fits host capacity (Avail - Committed - Need >= 4608 Reserve)
# Avail=10000, Committed=0, Candidate=1000 -> Projected=9000 >= 4608 -> MUST ADMIT (exit 0)
set +e
(cd "$SCRATCH" && unset MANAGENT_RUN_IDENTITY && \
    WEIZIGO_HOST_MEM_AVAIL_MB=10000 \
    "$RUNNER" --ram-mb 1000 \
              --arbiter-state-file "$SCRATCH/untracked/arbiter-state.json" \
              -- touch "$TOUCH_MARKER") >/dev/null 2>&1
RC_ADMIT=$?
set -e

if [ "$RC_ADMIT" -eq 0 ] && [ -f "$TOUCH_MARKER" ]; then
    echo "  PASS 1b: declared RAM fitting reserve is admitted (exit 0, child executed)"
else
    echo "  FAIL 1b: expected exit 0 and child execution; got exit $RC_ADMIT"
    FAIL=1
fi

# Scenario C: override admission allows execution even when capacity is tight
rm -f "$TOUCH_MARKER"
set +e
(cd "$SCRATCH" && unset MANAGENT_RUN_IDENTITY && \
    WEIZIGO_HOST_MEM_AVAIL_MB=5000 \
    "$RUNNER" --ram-mb 1000 \
              --override-admission="test-emergency-override" \
              --arbiter-state-file "$SCRATCH/untracked/arbiter-state.json" \
              -- touch "$TOUCH_MARKER") >/dev/null 2>&1
RC_OVERRIDE=$?
set -e

if [ "$RC_OVERRIDE" -eq 0 ] && [ -f "$TOUCH_MARKER" ]; then
    echo "  PASS 1c: --override-admission allows launch despite tight RAM (exit 0)"
else
    echo "  FAIL 1c: override admission failed; got exit $RC_OVERRIDE"
    FAIL=1
fi


# ── Arm 2: Wall-Band RAM Declaration at Band Boundaries ───────────────────
echo ""
echo "── Arm 2: Wall-Band RAM Declaration at Band Boundaries ─────────────"

check_wall_band() {
    local wall="$1"
    local expected="$2"
    local desc="$3"
    local got
    got=$(python3 -c "
import sys
sys.path.insert(0, '$PROJECT/tools')
from importlib.machinery import SourceFileLoader
subagent = SourceFileLoader('subagent', '$SUBAGENT').load_module()
print(subagent._declared_ram_mb('deepseek', 'deepseek-v4-flash', {}, $wall))
")
    if [ "$got" = "$expected" ]; then
        echo "  PASS 2: $desc (wall=${wall}s) -> $got MB (expected $expected MB)"
    else
        echo "  FAIL 2: $desc (wall=${wall}s) -> got $got MB, expected $expected MB"
        FAIL=1
    fi
}

check_wall_band 30   768  "< 60s band (interior: 30s)"
check_wall_band 59   768  "< 60s band (boundary below: 59s)"
check_wall_band 60   1792 "60-600s band (exact lower boundary: 60s)"
check_wall_band 300  1792 "60-600s band (interior: 300s)"
check_wall_band 599  1792 "60-600s band (boundary below: 599s)"
check_wall_band 600  3072 "600-1800s band (exact lower boundary: 600s)"
check_wall_band 1200 3072 "600-1800s band (interior: 1200s)"
check_wall_band 1799 3072 "600-1800s band (boundary below: 1799s)"
check_wall_band 1800 4608 ">= 1800s band (exact lower boundary: 1800s)"
check_wall_band 10800 4608 ">= 1800s band (long run incident case: 10800s)"

# Explicit --ram-mb override check
OVERRIDE_RAM=$(python3 -c "
import sys
sys.path.insert(0, '$PROJECT/tools')
from importlib.machinery import SourceFileLoader
subagent = SourceFileLoader('subagent', '$SUBAGENT').load_module()
print(subagent._declared_ram_mb('deepseek', 'deepseek-v4-flash', {'ram-mb': 8192}, 60))
")
if [ "$OVERRIDE_RAM" = "8192" ]; then
    echo "  PASS 2 (null): explicit --ram-mb=8192 overrides wall band default (got $OVERRIDE_RAM MB)"
else
    echo "  FAIL 2 (null): explicit --ram-mb override failed, got $OVERRIDE_RAM MB"
    FAIL=1
fi


# ── Arm 3: Wall Ceiling Termination (--max-wall) and Attribution ──────────
echo ""
echo "── Arm 3: Wall Ceiling Termination (--max-wall) and Attribution ────"

# Scenario A: child finishes within max-wall (pass control)
set +e
(cd "$SCRATCH" && unset MANAGENT_RUN_IDENTITY && \
    MANAGEMENT_TASK_ID=T939_WALL_PASS \
    "$RUNNER" --max-wall 5 -- sleep 0.1) >/dev/null 2>&1
RC_WALL_PASS=$?
set -e

if [ "$RC_WALL_PASS" -eq 0 ]; then
    echo "  PASS 3a: command within --max-wall exits cleanly (exit 0)"
else
    echo "  FAIL 3a: command within max-wall failed with exit $RC_WALL_PASS"
    FAIL=1
fi

# Scenario B: child exceeds max-wall (fail/termination control)
TASK_ID_WALL="T939_WALL_KILL"
set +e
(cd "$SCRATCH" && unset MANAGENT_RUN_IDENTITY && \
    MANAGENT_TASK_ID="$TASK_ID_WALL" \
    "$RUNNER" --max-wall 1 -- sleep 5) >/dev/null 2>&1
RC_WALL_KILL=$?
set -e

REC_WALL="$SCRATCH/untracked/runs/${TASK_ID_WALL}.json"
if [ "$RC_WALL_KILL" -eq 124 ] && [ -f "$REC_WALL" ]; then
    KILLED_BY=$(python3 -c "import json; d=json.load(open('$REC_WALL')); print(d.get('killed_by'))")
    SIGNAL=$(python3 -c "import json; d=json.load(open('$REC_WALL')); print(d.get('signal'))")
    if [ "$KILLED_BY" = "wall" ] && [ "$SIGNAL" = "9" ]; then
        echo "  PASS 3b: command exceeding --max-wall killed (exit 124, SIGKILL/signal 9, killed_by='wall')"
    else
        echo "  FAIL 3b: run record attribution mismatch (killed_by=$KILLED_BY, signal=$SIGNAL)"
        FAIL=1
    fi
else
    echo "  FAIL 3b: expected exit 124 and run record; got exit $RC_WALL_KILL"
    FAIL=1
fi


# ── Arm 4: Memory Overrun RSS Cap Kill & Pressure Alarm ───────────────────
echo ""
echo "── Arm 4: Memory Overrun RSS Cap Kill & Pressure Alarm ─────────────"

# Scenario A: process fits within RSS cap (pass control)
set +e
(cd "$SCRATCH" && unset MANAGENT_RUN_IDENTITY && \
    "$RUNNER" --rss-cap-mb 100 -- python3 -c "
import time
data = bytearray(10 * 1024 * 1024)
time.sleep(0.2)
") >/dev/null 2>&1
RC_RSS_PASS=$?
set -e

if [ "$RC_RSS_PASS" -eq 0 ]; then
    echo "  PASS 4a: process within RSS cap completes cleanly (exit 0)"
else
    echo "  FAIL 4a: process within RSS cap failed with exit $RC_RSS_PASS"
    FAIL=1
fi

# Scenario B: process exceeds RSS cap (overrun kill control)
TASK_ID_RSS="T939_RSS_KILL"
set +e
(cd "$SCRATCH" && unset MANAGENT_RUN_IDENTITY && \
    MANAGENT_TASK_ID="$TASK_ID_RSS" \
    "$RUNNER" --rss-cap-mb 30 -- python3 -c "
import time
data = bytearray(80 * 1024 * 1024)
time.sleep(3.0)
") >/dev/null 2>&1
RC_RSS_KILL=$?
set -e

REC_RSS="$SCRATCH/untracked/runs/${TASK_ID_RSS}.json"
if [ "$RC_RSS_KILL" -eq 124 ] && [ -f "$REC_RSS" ]; then
    KILLED_BY=$(python3 -c "import json; d=json.load(open('$REC_RSS')); print(d.get('killed_by'))")
    RSS_MB=$(python3 -c "import json; d=json.load(open('$REC_RSS')); print(d.get('rss_mb'))")
    if [ "$KILLED_BY" = "rss" ]; then
        echo "  PASS 4b: process exceeding RSS cap killed (exit 124, killed_by='rss', peak_rss=${RSS_MB}MB > 30MB)"
    else
        echo "  FAIL 4b: run record attribution mismatch (killed_by=$KILLED_BY)"
        FAIL=1
    fi
else
    echo "  FAIL 4b: expected exit 124 and run record; got exit $RC_RSS_KILL"
    FAIL=1
fi

# Scenario C: L3 kernel memory pressure alarm (INV-1: ALARMS, NEVER kills in-budget task)
ERR_OUTPUT="$WORK/arm4c_stderr.log"
set +e
(cd "$SCRATCH" && unset MANAGENT_RUN_IDENTITY && \
    WEIZIGO_KERNEL_PRESSURE_LEVEL=2 \
    "$RUNNER" -- python3 -c "import time; time.sleep(2.5)") >/dev/null 2>"$ERR_OUTPUT"
RC_PRESSURE=$?
set -e

if [ "$RC_PRESSURE" -eq 0 ] && grep -q "ALARM: host memory pressure level 2" "$ERR_OUTPUT" && grep -q "never killed" "$ERR_OUTPUT"; then
    echo "  PASS 4c: L3 kernel memory pressure emits ALARM without killing task (exit 0, INV-1 satisfied)"
else
    echo "  FAIL 4c: L3 pressure alarm failed or killed task (exit $RC_PRESSURE)"
    FAIL=1
fi


# ── Arm 5: Run Record Kind & Reap Safety (T895) ───────────────────────────
echo ""
echo "── Arm 5: Run Record Kind & Reap Safety (T895) ─────────────────────"

TASK_ID_DISPATCH="T939_DISPATCH_MAIN"
DISPATCH_REC="$SCRATCH/untracked/runs/${TASK_ID_DISPATCH}.json"

# Top-level dispatch launches a nested child runner with the same task ID
set +e
(cd "$SCRATCH" && unset MANAGENT_RUN_IDENTITY && \
    MANAGENT_TASK_ID="$TASK_ID_DISPATCH" \
    "$RUNNER" -- bash -c "
        # Inside the dispatch child: MANAGENT_RUN_IDENTITY is set by runner
        # Run a nested test runner under the same task ID
        MANAGENT_TASK_ID='$TASK_ID_DISPATCH' '$RUNNER' -- echo 'nested test run'
        sleep 0.2
") >/dev/null 2>&1
RC_DISPATCH=$?
set -e

if [ "$RC_DISPATCH" -eq 0 ] && [ -f "$DISPATCH_REC" ]; then
    DISPATCH_KIND=$(python3 -c "import json; d=json.load(open('$DISPATCH_REC')); print(d.get('run_kind'))")
    NESTED_COUNT=$(find "$SCRATCH/untracked/runs/nested" -type f -name "${TASK_ID_DISPATCH}.*.json" | wc -l | tr -d ' ')
    if [ "$DISPATCH_KIND" = "dispatch" ] && [ "$NESTED_COUNT" -ge 1 ]; then
        NESTED_KIND=$(python3 -c "
import json, glob
files = glob.glob('$SCRATCH/untracked/runs/nested/${TASK_ID_DISPATCH}.*.json')
d = json.load(open(files[0]))
print(d.get('run_kind'))
")
        if [ "$NESTED_KIND" = "nested" ]; then
            echo "  PASS 5: dispatch record preserved as run_kind='dispatch', nested run isolated to untracked/runs/nested/ (run_kind='nested')"
        else
            echo "  FAIL 5: nested run kind mismatch: $NESTED_KIND"
            FAIL=1
        fi
    else
        echo "  FAIL 5: dispatch kind is '$DISPATCH_KIND' (expected 'dispatch') or nested count $NESTED_COUNT < 1"
        FAIL=1
    fi
else
    echo "  FAIL 5: dispatch execution failed (exit $RC_DISPATCH) or record missing"
    FAIL=1
fi


# ── Arm 6: Zig Build Optimization Enforcement (ReleaseFast) ───────────────
echo ""
echo "── Arm 6: Zig Build Optimization Enforcement (ReleaseFast) ─────────"

# tools/runner must automatically prepend ReleaseFast for bare zig commands
ZIG_BUILD_TRANSFORM=$(python3 -c "
import sys, os
sys.path.insert(0, os.path.abspath('$PROJECT/tools'))
from importlib.machinery import SourceFileLoader
runner = SourceFileLoader('runner', '$RUNNER').load_module()
print(' '.join(runner.prepend_releasefast(['zig', 'build'])))
")
ZIG_RUN_TRANSFORM=$(python3 -c "
import sys, os
sys.path.insert(0, os.path.abspath('$PROJECT/tools'))
from importlib.machinery import SourceFileLoader
runner = SourceFileLoader('runner', '$RUNNER').load_module()
print(' '.join(runner.prepend_releasefast(['zig', 'run', 'src/retro.zig'])))
")

if [ "$ZIG_BUILD_TRANSFORM" = "zig build -Doptimize=ReleaseFast" ] && \
   [ "$ZIG_RUN_TRANSFORM" = "zig run -O ReleaseFast src/retro.zig" ]; then
    echo "  PASS 6: ReleaseFast prepended for zig build and zig run"
else
    echo "  FAIL 6: prepend_releasefast failed: build='$ZIG_BUILD_TRANSFORM', run='$ZIG_RUN_TRANSFORM'"
    FAIL=1
fi


# ── Arm 7: Sleep Guard Caffeinate Assertion ───────────────────────────────
echo ""
echo "── Arm 7: Sleep Guard Caffeinate Assertion ─────────────────────────"

TASK_ID_SLEEP="T939_SLEEP_GUARD"
set +e
(cd "$SCRATCH" && unset MANAGENT_RUN_IDENTITY && \
    MANAGENT_TASK_ID="$TASK_ID_SLEEP" \
    "$RUNNER" -- echo "testing sleep guard") >/dev/null 2>&1
RC_SLEEP=$?
set -e

REC_SLEEP="$SCRATCH/untracked/runs/${TASK_ID_SLEEP}.json"
if [ "$RC_SLEEP" -eq 0 ] && [ -f "$REC_SLEEP" ]; then
    SLEEP_PREV=$(python3 -c "import json; d=json.load(open('$REC_SLEEP')); print(d.get('sleep_prevented'))")
    if [ "$SLEEP_PREV" = "True" ] || [ "$SLEEP_PREV" = "true" ]; then
        echo "  PASS 7: sleep guard active and recorded (sleep_prevented=true)"
    else
        echo "  FAIL 7: sleep_prevented is '$SLEEP_PREV', expected true"
        FAIL=1
    fi
else
    echo "  FAIL 7: sleep guard run failed (exit $RC_SLEEP) or record missing"
    FAIL=1
fi

echo ""
echo "======================================================================"
if [ "$FAIL" -eq 0 ]; then
    echo "  ALL ARMS PASSED (0 failures)"
    exit 0
else
    echo "  FAILED ($FAIL arm(s) failed)"
    exit 1
fi
