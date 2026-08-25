#!/usr/bin/env bash
# regression-runner-guard.sh — T920 (Race J, sonnet lane): a regression gate
# for tools/runner, the fleet's most load-bearing file.  S09's module
# contract used to declare `test tools/regression-runner-guard.sh covers
# tools/runner`; T872 deleted the script the declaration named, T914 removed
# the stale declaration, and tools/runner has carried ZERO declared test
# coverage since.  This script is a candidate to fill that gap.
#
# House rule (binds here): never trust a green test.  Every assertion below
# ships BOTH a control that must pass and a control that must go red — the
# red control is either a seeded defect (a mutated copy of the source) or
# the opposite side of a boundary.  An assertion with no observed red run is
# reported as unproven, not counted as covered.
#
# Scope note on assertion 2 (wall-band RAM declaration): the boundary
# arithmetic lives in bin/subagent's _wall_band_ram_mb, not in tools/runner
# itself (tools/runner's --ram-mb has no default; it only enforces whatever
# value it is given).  This script reads bin/subagent as data (imports it
# read-only, exactly as tools/regression-arbiter.sh already imports
# tools/runner read-only) — it is the caller of --ram-mb, and the brief's
# own text ("the row stays dispatchable" / ram-policy.md §3.2) is about the
# declaration this function computes.  tools/runner itself is read, never
# written, and never touched at all by assertion 2's checks.
#
# IMPORTANT — assertion 4 as literally worded in the brief ("the
# memory-pressure host guard fires and KILLS the lane") describes the
# pre-ram-policy behaviour (the deleted `total // 8` floor).  Under the
# ratified redesign (docs/infra/host/ram-policy.md §4.3-4.4, INV-1) the L3
# memory-pressure guard ALARMS and never kills — killing a foreign-pressure
# lane is exactly the defect the policy retires (16 of 20 historical kills
# were futile).  This script tests the CURRENT, correct contract (fires an
# alarm, names the consumer, never signals the worker) and records the
# mismatch with the brief's wording in findings.json rather than silently
# asserting the old, now-wrong behaviour.
#
# Every check below runs inside a disposable scratch git repo under
# /tmp/weizigo — the live repo, the live kanban, the live
# untracked/heartbeat.jsonl and the live untracked/arbiter-state.json are
# never read or written.  Every --arbiter-state-file is a scratch path.
#
# Task: T920 · Role: worker (Race J, sealed lane) · Model: claude-sonnet-5
# Date: 2026-08-25

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/../../.." && pwd)"
RUNNER="$PROJECT/tools/runner"
SUBAGENT="$PROJECT/bin/subagent"
FAIL=0

mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/t920-sonnet-guard-XXXXXX)" \
    || { echo "regression-runner-guard.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
REPO="$WORK/repo"
mkdir -p "$REPO/untracked"
( cd "$REPO" && git init -q && printf 'untracked/\n' > .gitignore && git add -A && git commit -qm base )

cleanup() {
    if [ -n "${WORK:-}" ]; then
        pkill -CONT -f "$WORK" 2>/dev/null
        pkill -9 -f "$WORK" 2>/dev/null
        rm -rf "$WORK"
    fi
}
trap cleanup EXIT

pass() { echo "    PASS: $*"; }
fail() { echo "    FAIL: $*"; FAIL=1; }

echo "=========================================================================="
echo "assertion 1 — admission refuses a lane whose declared RAM does not fit"
echo "(ram-policy.md §4.1); refused, not killed; the row stays dispatchable."
echo "=========================================================================="

# Boundary arithmetic: admit iff avail - committed - ram_mb >= RESERVE_MB(4608).
# avail=10000, committed=0 => the boundary ram_mb is 10000-4608=5392.
STATE_A1A="$WORK/a1-boundary-admit.json"
OUT_A1A=$(cd "$REPO" && WEIZIGO_HOST_MEM_AVAIL_MB=10000 MANAGENT_TASK_ID=T920A1-BOUNDARY-ADMIT \
    "$RUNNER" --arbiter-admit --ram-mb 5392 --arbiter-state-file "$STATE_A1A" 2>&1)
RC_A1A=$?
[ "$RC_A1A" -eq 0 ] && echo "$OUT_A1A" | grep -q '"admit": true' \
    && pass "exact boundary (projected == RESERVE_MB == 4608) admits (exit 0, observed)" \
    || fail "exact boundary should admit — rc=$RC_A1A: $OUT_A1A"

STATE_A1B="$WORK/a1-boundary-refuse.json"
OUT_A1B=$(cd "$REPO" && WEIZIGO_HOST_MEM_AVAIL_MB=10000 MANAGENT_TASK_ID=T920A1-BOUNDARY-REFUSE \
    "$RUNNER" --arbiter-admit --ram-mb 5393 --arbiter-state-file "$STATE_A1B" 2>&1)
RC_A1B=$?
[ "$RC_A1B" -eq 3 ] && echo "$OUT_A1B" | grep -q '"admit": false' \
    && pass "one MB over the boundary (projected == 4607) refuses (exit 3, observed — the same arithmetic caught on the opposite side)" \
    || fail "one-MB-over-boundary should refuse — rc=$RC_A1B: $OUT_A1B"

# End-to-end: the SAME refusal, but through the full launch path (not the
# standalone --arbiter-admit probe) — proves nothing is ever spawned.
STATE_A1C="$WORK/a1-e2e-refuse.json"
MARKER_A1C="$WORK/a1-e2e.marker"
rm -f "$MARKER_A1C"
LOG_A1C="$WORK/a1-e2e.log"
( cd "$REPO" && WEIZIGO_HOST_MEM_AVAIL_MB=10000 MANAGENT_TASK_ID=T920A1-E2E-REFUSE \
    "$RUNNER" --no-prepend-zig --ram-mb 5393 --arbiter-state-file "$STATE_A1C" --max-wall 10 -- \
    python3 -c "open('$MARKER_A1C','w').write('spawned')" >"$LOG_A1C" 2>&1 )
RC_A1C=$?
A1C_OK=1
[ "$RC_A1C" -eq 3 ] || { fail "e2e refusal should exit 3, got $RC_A1C"; A1C_OK=0; }
grep -q "row stays dispatchable" "$LOG_A1C" || { fail "e2e refusal did not name 'row stays dispatchable'"; A1C_OK=0; }
[ -f "$MARKER_A1C" ] && { fail "marker exists — a process WAS spawned despite the refusal"; A1C_OK=0; }
[ "$A1C_OK" -eq 1 ] && pass "full launch path: refused before spawn, nothing ran, row untouched (observed marker absent + exit 3)"

echo ""
echo "=========================================================================="
echo "assertion 2 — the wall-band RAM declaration is correct at each band"
echo "boundary (60s, 600s, 1800s) — bin/subagent._wall_band_ram_mb"
echo "=========================================================================="

WALLBAND_CHECK=$(python3 - "$SUBAGENT" <<'PYEOF'
import sys, importlib.util
from importlib.machinery import SourceFileLoader
path = sys.argv[1]
loader = SourceFileLoader("subagent_wallband", path)
spec = importlib.util.spec_from_loader("subagent_wallband", loader)
mod = importlib.util.module_from_spec(spec)
loader.exec_module(mod)
expect = {59: 768, 60: 1792, 599: 1792, 600: 3072, 1799: 3072, 1800: 4608}
bad = []
for wall, want in expect.items():
    got = mod._wall_band_ram_mb(wall)
    if got != want:
        bad.append((wall, want, got))
print("BAD=%r" % bad)
PYEOF
)
if echo "$WALLBAND_CHECK" | grep -q "BAD=\[\]"; then
    pass "all 6 boundary points (59/60/599/600/1799/1800) match ram-policy.md §3.2's table (observed, real bin/subagent)"
else
    fail "boundary mismatch: $WALLBAND_CHECK"
fi

# Seeded defect: a one-character off-by-one (< 60 -> <= 60) at the first
# boundary, run against a full copy of bin/ + tools/ (subagent's sibling
# imports resolve relative to its own path) so the mutant actually loads.
MUTANT_ROOT="$WORK/mutant-repo"
mkdir -p "$MUTANT_ROOT"
cp -r "$PROJECT/bin" "$MUTANT_ROOT/bin"
cp -r "$PROJECT/tools" "$MUTANT_ROOT/tools"
sed -i.bak 's/if wall_seconds < 60:/if wall_seconds <= 60:/' "$MUTANT_ROOT/bin/subagent"
rm -f "$MUTANT_ROOT/bin/subagent.bak"
MUTANT_CHECK=$(python3 - "$MUTANT_ROOT/bin/subagent" <<'PYEOF'
import sys, importlib.util
from importlib.machinery import SourceFileLoader
path = sys.argv[1]
loader = SourceFileLoader("subagent_mutant", path)
spec = importlib.util.spec_from_loader("subagent_mutant", loader)
mod = importlib.util.module_from_spec(spec)
loader.exec_module(mod)
print("wall60=%d" % mod._wall_band_ram_mb(60))
PYEOF
)
if echo "$MUTANT_CHECK" | grep -q "wall60=768"; then
    pass "seeded off-by-one (< 60 -> <= 60) caught: mutant returns 768 at wall=60 where 1792 is correct (observed red)"
else
    fail "seeded mutant did not reproduce the expected defect: $MUTANT_CHECK"
fi

echo ""
echo "=========================================================================="
echo "assertion 3 — a lane exceeding --max-wall is terminated, attributably"
echo "=========================================================================="

LOG_A3P="$WORK/a3-pass.log"
( cd "$REPO" && MANAGENT_TASK_ID=T920A3-PASS \
    "$RUNNER" --no-prepend-zig --max-wall 10 -- python3 -c "print('done fast')" >"$LOG_A3P" 2>&1 )
RC_A3P=$?
REC_A3P="$REPO/untracked/runs/T920A3-PASS.json"
A3P_OK=1
[ "$RC_A3P" -eq 0 ] || { fail "under-budget lane should exit 0, got $RC_A3P"; A3P_OK=0; }
if [ -f "$REC_A3P" ]; then
    KB_A3P=$(python3 -c "import json; print(json.load(open('$REC_A3P')).get('killed_by'))" 2>/dev/null)
    [ "$KB_A3P" = "None" ] || { fail "under-budget lane's run record has killed_by=$KB_A3P, expected none"; A3P_OK=0; }
else
    fail "run record $REC_A3P missing"; A3P_OK=0
fi
[ "$A3P_OK" -eq 1 ] && pass "lane finishing under --max-wall completes clean, killed_by unset (observed exit 0)"

LOG_A3F="$WORK/a3-fail.log"
( cd "$REPO" && MANAGENT_TASK_ID=T920A3-KILL \
    "$RUNNER" --no-prepend-zig --max-wall 1 -- python3 -c "import time; time.sleep(6)" >"$LOG_A3F" 2>&1 )
RC_A3F=$?
REC_A3F="$REPO/untracked/runs/T920A3-KILL.json"
A3F_OK=1
[ "$RC_A3F" -eq 124 ] || { fail "over-budget lane should exit 124, got $RC_A3F"; A3F_OK=0; }
grep -q "wall ceiling" "$LOG_A3F" || { fail "no 'wall ceiling' message in log"; A3F_OK=0; }
if [ -f "$REC_A3F" ]; then
    KB_A3F=$(python3 -c "import json; print(json.load(open('$REC_A3F')).get('killed_by'))" 2>/dev/null)
    [ "$KB_A3F" = "wall" ] || { fail "over-budget lane's run record has killed_by=$KB_A3F, expected wall"; A3F_OK=0; }
else
    fail "run record $REC_A3F missing"; A3F_OK=0
fi
[ "$A3F_OK" -eq 1 ] && pass "lane exceeding --max-wall is SIGKILLed, exit 124, killed_by=wall (observed, attributable)"

echo ""
echo "=========================================================================="
echo "assertion 4 — the memory-pressure host guard, sustained past threshold"
echo "(NOTE: current policy is ALARM-NEVER-KILL, not kill — see header note;"
echo "checked against the ratified contract, ram-policy.md §4.3-4.4/INV-1)"
echo "=========================================================================="

LOG_A4N="$WORK/a4-null.log"
( cd "$REPO" && MANAGENT_TASK_ID=T920A4-NULL \
    "$RUNNER" --no-prepend-zig --max-wall 10 -- python3 -c "import time; time.sleep(3); print('null control done')" >"$LOG_A4N" 2>&1 )
RC_A4N=$?
A4N_OK=1
[ "$RC_A4N" -eq 0 ] || { fail "null control should exit 0, got $RC_A4N"; A4N_OK=0; }
grep -q "ALARM" "$LOG_A4N" && { fail "null control (no injected pressure) raised an ALARM anyway"; A4N_OK=0; }
[ "$A4N_OK" -eq 1 ] && pass "no injected pressure -> no alarm (observed exit 0, no ALARM line)"

LOG_A4A="$WORK/a4-alarm.log"
( cd "$REPO" && WEIZIGO_KERNEL_PRESSURE_LEVEL=4 MANAGENT_TASK_ID=T920A4-ALARM \
    "$RUNNER" --no-prepend-zig --max-wall 10 -- python3 -c "import time; time.sleep(4); print('alarm control done')" >"$LOG_A4A" 2>&1 )
RC_A4A=$?
REC_A4A="$REPO/untracked/runs/T920A4-ALARM.json"
A4A_OK=1
[ "$RC_A4A" -eq 0 ] || { fail "sustained-pressure lane should still exit 0 (never killed for it), got $RC_A4A"; A4A_OK=0; }
grep -q "^\[runner\] ALARM:" "$LOG_A4A" || { fail "sustained pressure (level=4, >=2s) did not raise an ALARM line"; A4A_OK=0; }
grep -q "^\[runner\] KILL:" "$LOG_A4A" && { fail "sustained pressure caused a KILL — violates INV-1 (never kill a worker for a foreign condition)"; A4A_OK=0; }
grep -q "alarm control done" "$LOG_A4A" || { fail "worker output never appeared — something interfered with it"; A4A_OK=0; }
if [ -f "$REC_A4A" ]; then
    HAS_ALARMS=$(python3 -c "import json; r=json.load(open('$REC_A4A')); print(bool(r.get('host_alarms')))" 2>/dev/null)
    [ "$HAS_ALARMS" = "True" ] || { fail "run record has no host_alarms entry despite the sustained injected pressure"; A4A_OK=0; }
else
    fail "run record $REC_A4A missing"; A4A_OK=0
fi
[ "$A4A_OK" -eq 1 ] && pass "sustained kernel pressure (level=4, dwell>=2s) alarms, names a consumer, writes host_alarms, and never kills (observed)"

echo ""
echo "=========================================================================="
echo "assertion 5 — a run record is written with its kind declared, so reap"
echo "reads the dispatch record (run_kind: dispatch|nested)"
echo "=========================================================================="

( cd "$REPO" && MANAGENT_TASK_ID=T920A5-DISPATCH \
    "$RUNNER" --no-prepend-zig --max-wall 10 -- python3 -c "print('leaf')" >/dev/null 2>&1 )
REC_A5D="$REPO/untracked/runs/T920A5-DISPATCH.json"
A5D_OK=1
if [ -f "$REC_A5D" ]; then
    RK_A5D=$(python3 -c "import json; print(json.load(open('$REC_A5D')).get('run_kind'))" 2>/dev/null)
    [ "$RK_A5D" = "dispatch" ] || { fail "top-level launch's run_kind=$RK_A5D, expected dispatch"; A5D_OK=0; }
else
    fail "run record $REC_A5D missing"; A5D_OK=0
fi

( cd "$REPO" && MANAGENT_TASK_ID=T920A5-NESTED MANAGENT_RUN_IDENTITY=T920A5-NESTED \
    "$RUNNER" --no-prepend-zig --max-wall 10 -- python3 -c "print('nested leaf')" >/dev/null 2>&1 )
REC_A5N=$(find "$REPO/untracked/runs/nested" -name "*T920A5-NESTED*" 2>/dev/null | head -1)
A5N_OK=1
if [ -n "$REC_A5N" ] && [ -f "$REC_A5N" ]; then
    RK_A5N=$(python3 -c "import json; print(json.load(open('$REC_A5N')).get('run_kind'))" 2>/dev/null)
    [ "$RK_A5N" = "nested" ] || { fail "nested launch's run_kind=$RK_A5N, expected nested"; A5N_OK=0; }
else
    fail "nested run record not found under untracked/runs/nested/"; A5N_OK=0
fi
[ "$A5D_OK" -eq 1 ] && [ "$A5N_OK" -eq 1 ] && \
    pass "a top-level launch records run_kind=dispatch, a launch inside its own dispatch (MANAGENT_RUN_IDENTITY match) records run_kind=nested (both observed)"

# Seeded defect: the checker itself must be ABLE to catch a missing/corrupt
# run_kind, or the two checks above prove nothing (a checker that always
# passes is not a checker).  Strip run_kind from a copy of the real,
# just-produced dispatch record and confirm the SAME assertion now fails.
CORRUPT="$WORK/a5-corrupt.json"
python3 -c "
import json
r = json.load(open('$REC_A5D'))
r.pop('run_kind', None)
json.dump(r, open('$CORRUPT', 'w'))
"
CORRUPT_RK=$(python3 -c "import json; print(json.load(open('$CORRUPT')).get('run_kind'))" 2>/dev/null)
if [ "$CORRUPT_RK" = "dispatch" ]; then
    fail "seeded corruption (run_kind stripped) was not caught — checker is inert"
else
    pass "seeded corruption caught: a record with run_kind stripped reads back as '$CORRUPT_RK', not 'dispatch' (observed red)"
fi

echo ""
echo "=========================================================================="
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-runner-guard (sonnet lane): ALL CHECKS PASSED ==="
    exit 0
else
    echo "=== regression-runner-guard (sonnet lane): FAILURES ==="
    exit 1
fi
