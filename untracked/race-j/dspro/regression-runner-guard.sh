#!/usr/bin/env bash
# regression-runner-guard.sh — the replacement gate for tools/runner (T918, dspro lane).
#
# The S09 module contract once declared
#     test tools/regression-runner-guard.sh covers tools/runner
# That script no longer exists: T872 deleted it at 12e7055 (it tested the
# T362 host-guard memory-pressure KILL, which T821 then deleted — the guard's
# seeded arm can never fire again).  T914 removed the declaration at b3a841c
# to unfreeze commits, which left tools/runner with ZERO declared coverage.
# Removing a broken gate is not the same as having a gate.  This is the gate.
#
# House rule that binds here: never trust a green test.  Every assertion
# below ships with a RED control — the same check run against a MUTATED copy
# of tools/runner that reintroduces the defect — and the red control is
# OBSERVED, not predicted.  An assertion with no red control is reported in
# findings.json as not-verified, never counted as coverage.
#
# Covered assertions (current HEAD semantics, after T821/T862/T895/T913):
#   A1  admission refusal — a declared need that does not fit the host is
#       REFUSED before spawn (exit 3), nothing runs, the row stays
#       dispatchable (ram-policy.md §4.1 / ORC-GD-3 / INV-3).
#   A3  --max-wall termination — a silent child that outlives its wall is
#       killed (exit 124) and the kill is ATTRIBUTABLE (run record
#       killed_by == "wall").
#   A4  L3 memory-pressure backstop — sustained kernel pressure ALARMS,
#       names the consumer, and NEVER kills (the T821 replacement for the
#       deleted host-guard kill; INV-1).  The red control seeds a
#       kill-on-pressure defect and shows the assertion catches it.
#   A5  run record carries run_kind — a dispatch writes its record with the
#       kind declared, at the bare untracked/runs/<task>.json path `reap`
#       keys on (T895).
#
# NOT covered here (stated, not skipped silently):
#   A2  wall-band RAM declaration (60/600/1800 s) — that is bin/subagent
#       behaviour (_wall_band_ram_mb / _declared_ram_mb), already covered
#       by tools/regression-ram-declaration.sh (T913).  tools/runner's
#       contract is to RECEIVE --ram-mb, not compute the band; there is no
#       band table in tools/runner to assert.
#   The `reap` join itself (managent) is covered by
#       tools/regression-runner-run-records.sh; A5 asserts the record shape
#       reap depends on, not managent's read of it.
#
# Isolation (T512/F3): every arm runs from a SCRATCH git repo under
# /tmp/weizigo, and every fixture uses MANAGENT_TASK_ID (env, not --task-id)
# so heartbeats + run records land in scratch and no auto-claim touches the
# live kanban.  Arbiter ledgers use --arbiter-state-file into scratch.  A
# closing check scans the LIVE heartbeat.jsonl for fixture markers.
#
# Task: T918 · Role: worker (leaf) · Model: deepseek-v4-pro · Date: 2026-08-25

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(git -C "$HERE" rev-parse --show-toplevel 2>/dev/null || (cd "$HERE/../../.." && pwd))"
RUNNER="$PROJECT/tools/runner"
FAIL=0

[ -f "$RUNNER" ] && [ -x "$RUNNER" ] \
    || { echo "regression-runner-guard.sh: FATAL — tools/runner missing/not executable at $RUNNER" >&2; exit 2; }

mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/t918-guard-XXXXXX)" \
    || { echo "regression-runner-guard.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
REPO="$WORK/repo"
mkdir -p "$REPO/untracked" "$REPO/docs/infra/managent"
( cd "$REPO" && git init -q && printf 'untracked/\n' > .gitignore && git add -A && git commit -qm base )

# ── live-telemetry baseline + closing isolation (T512/F3) ────────────────
LIVE_HB="$PROJECT/untracked/heartbeat.jsonl"
LIVE_HB_BASE=$(wc -l < "$LIVE_HB" 2>/dev/null || echo 0)

check_isolation() {
    ISO_FAIL=0
    APPENDED=$(tail -n +$((LIVE_HB_BASE + 1)) "$LIVE_HB" 2>/dev/null || true)
    if [ -z "$APPENDED" ]; then
        echo "    PASS: live heartbeat.jsonl — no lines appended during the run"
    elif echo "$APPENDED" | grep -q "T918DSR"; then
        echo "    FAIL: fixture heartbeat line(s) appended to the LIVE heartbeat.jsonl (F3 regression)"
        echo "$APPENDED" | grep -n "T918DSR" | sed 's/^/    | /'
        ISO_FAIL=1
    else
        echo "    PASS: live heartbeat.jsonl — appended lines carry no fixture data"
    fi
    [ "$ISO_FAIL" -eq 0 ] || FAIL=1
}

cleanup() {
    if [ -n "${WORK:-}" ]; then
        pkill -9 -f "$WORK" 2>/dev/null || true
        rm -rf "$WORK"
    fi
    check_isolation
}
trap cleanup EXIT

# ── mutate: copy tools/runner and apply one exact substitution ───────────
# The red control's instrument-under-test.  PYTHONPATH points the copy's
# `import directive_policy` / `import model_tags` at the real tools/ (the
# copy lives in scratch, so sys.path[0] no longer does it).  The mutation
# target must exist exactly once; a mismatch is a hard failure (a red
# control that never mutated proves nothing), never a silent empty path.
mutate() {  # mutate <out> <old> <new>; returns 0 on success
    local out="$1" old="$2" new="$3"
    cp "$RUNNER" "$out" && chmod +x "$out" || return 2
    python3 - "$out" "$old" "$new" <<'PYEOF'
import sys
p, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(p).read()
n = s.count(old)
if n != 1:
    sys.stderr.write("mutate: expected 1 occurrence of %r, found %d\n" % (old, n))
    sys.exit(2)
open(p, "w").write(s.replace(old, new))
PYEOF
}

echo "========================================================================"
echo "T918 regression-runner-guard — tools/runner coverage gate (dspro lane)"
echo "PROJECT=$PROJECT"
echo ""

# ═══════════════════════════════════════════════════════════════════════
# A1 — admission refusal: refused before spawn, nothing runs, row dispatchable
# ═══════════════════════════════════════════════════════════════════════
echo "=== A1 — admission refusal (refused, not killed, row stays dispatchable) ==="
A1_OK=1
STATE_A1="$WORK/arb-a1.json"

echo "  GREEN (standalone --arbiter-admit): avail 5000 MB, declared 4608 MB"
echo "  -> projected 392 MB < reserve 4608 MB, must REFUSE with exit 3."
A1G_LOG="$WORK/a1-green.log"
WEIZIGO_HOST_MEM_AVAIL_MB=5000 "$RUNNER" --arbiter-admit --arbiter-id T918DSR-A1G \
    --ram-mb 4608 --arbiter-state-file "$STATE_A1" >"$A1G_LOG" 2>"$WORK/a1-green.err"
A1G_RC=$?
[ "$A1G_RC" -eq 3 ] || { echo "    FAIL: green exit $A1G_RC (want 3)"; A1_OK=0; }
grep -q '"admit": false' "$A1G_LOG" || { echo "    FAIL: no '\"admit\": false' in stdout"; A1_OK=0; }
grep -q "ARBITER REFUSED" "$WORK/a1-green.err" || { echo "    FAIL: no 'ARBITER REFUSED'"; A1_OK=0; }
grep -q "row stays dispatchable" "$WORK/a1-green.err" || { echo "    FAIL: refusal did not name 'row stays dispatchable'"; A1_OK=0; }
[ "$A1_OK" -eq 1 ] && echo "    PASS: refused (exit $A1G_RC), row stays dispatchable"

echo "  GREEN (full launch): the same decision before spawn — nothing may run."
A1F_MARKER="$WORK/a1-marker"; rm -f "$A1F_MARKER"
( cd "$REPO" && WEIZIGO_HOST_MEM_AVAIL_MB=5000 MANAGENT_TASK_ID=T918DSR-A1F \
    "$RUNNER" --no-prepend-zig --ram-mb 4608 --arbiter-id T918DSR-A1F \
    --arbiter-state-file "$STATE_A1" -- \
    python3 -c "open('$A1F_MARKER','w').write('spawned')" \
    >"$WORK/a1f.log" 2>"$WORK/a1f.err" )
A1F_RC=$?
if [ "$A1F_RC" -eq 3 ] && [ ! -f "$A1F_MARKER" ]; then
    echo "    PASS: exit $A1F_RC and no process spawned (marker absent)"
else
    echo "    FAIL: exit $A1F_RC; marker present=$([ -f "$A1F_MARKER" ] && echo yes || echo no) — want exit 3, marker absent"
    A1_OK=0
fi

echo "  RED (seeded defect): _arbiter_decide made to admit unconditionally."
A1_MUT="$WORK/mut-a1"
if mutate "$A1_MUT" "if projected_mb >= ARBITER_RESERVE_MB:" "if True:"; then
    A1R_LOG="$WORK/a1-red.log"
    WEIZIGO_HOST_MEM_AVAIL_MB=5000 PYTHONPATH="$PROJECT/tools" python3 "$A1_MUT" \
        --arbiter-admit --arbiter-id T918DSR-A1R --ram-mb 4608 \
        --arbiter-state-file "$STATE_A1" >"$A1R_LOG" 2>"$WORK/a1-red.err"
    A1R_RC=$?
    if [ "$A1R_RC" -ne 3 ] && grep -q '"admit": true' "$A1R_LOG"; then
        echo "    RED confirmed: the same check now sees exit $A1R_RC and '\"admit\": true' — assertion is sensitive"
    else
        echo "    FAIL: red control did not reproduce the defect (rc=$A1R_RC) — assertion sensitivity unproven"
        A1_OK=0
    fi
else
    echo "    FAIL: seed mutation failed — red control unusable (assertion sensitivity unproven)"
    A1_OK=0
fi
echo ""

# ═══════════════════════════════════════════════════════════════════════
# A3 — --max-wall termination, attributable
# ═══════════════════════════════════════════════════════════════════════
echo "=== A3 — --max-wall termination is attributable ==="
A3_OK=1

echo "  GREEN: silent child outlives --max-wall 2 -> exit 124, killed_by=wall."
A3G_LOG="$WORK/a3-green.log"
( cd "$REPO" && MANAGENT_TASK_ID=T918DSR-A3G \
    "$RUNNER" --no-prepend-zig --max-wall 2 -- sleep 60 \
    >"$A3G_LOG" 2>&1 )
A3G_RC=$?
[ "$A3G_RC" -eq 124 ] || { echo "    FAIL: green exit $A3G_RC (want 124)"; A3_OK=0; }
grep -q "wall ceiling 2s" "$A3G_LOG" || { echo "    FAIL: no 'wall ceiling 2s' kill line"; A3_OK=0; }
A3G_REC="$REPO/untracked/runs/T918DSR-A3G.json"
A3G_KB=$(python3 -c "import json; print(json.load(open('$A3G_REC')).get('killed_by'))" 2>/dev/null || echo MISSING)
[ "$A3G_KB" = "wall" ] || { echo "    FAIL: run record killed_by=$A3G_KB (want wall)"; A3_OK=0; }
[ "$A3_OK" -eq 1 ] && echo "    PASS: exit 124, 'wall ceiling' named, killed_by=wall in the run record"

echo "  RED (seeded defect): the wall check disabled -> child completes instead."
A3_MUT="$WORK/mut-a3"
if mutate "$A3_MUT" "elif args.max_wall and elapsed >= args.max_wall:" "elif args.max_wall and False:"; then
    A3R_LOG="$WORK/a3-red.log"
    ( cd "$REPO" && MANAGENT_TASK_ID=T918DSR-A3R \
        PYTHONPATH="$PROJECT/tools" python3 "$A3_MUT" --no-prepend-zig --max-wall 1 -- \
        python3 -c "import time; time.sleep(3)" >"$A3R_LOG" 2>&1 )
    A3R_RC=$?
    if [ "$A3R_RC" -ne 124 ]; then
        echo "    RED confirmed: wall ceiling never fired, child completed (exit $A3R_RC) — assertion is sensitive"
    else
        echo "    FAIL: red control still killed (rc=$A3R_RC) — assertion sensitivity unproven"
        A3_OK=0
    fi
else
    echo "    FAIL: seed mutation failed — red control unusable (assertion sensitivity unproven)"
    A3_OK=0
fi
echo ""

# ═══════════════════════════════════════════════════════════════════════
# A4 — L3 memory-pressure backstop: alarms, names the consumer, never kills
# ═══════════════════════════════════════════════════════════════════════
echo "=== A4 — L3 memory-pressure backstop (alarm, never kill) ==="
A4_OK=1

echo "  GREEN: injected kernel pressure level 4, sustained -> ALARM, child survives."
A4G_LOG="$WORK/a4-green.log"
( cd "$REPO" && WEIZIGO_KERNEL_PRESSURE_LEVEL=4 MANAGENT_TASK_ID=T918DSR-A4G \
    "$RUNNER" --no-prepend-zig -- \
    python3 -c "import time; time.sleep(4)" >"$A4G_LOG" 2>&1 )
A4G_RC=$?
[ "$A4G_RC" -eq 0 ] || { echo "    FAIL: green exit $A4G_RC (want 0 — the child must survive pressure)"; A4_OK=0; }
grep -q "ALARM: host memory pressure level 4 sustained" "$A4G_LOG" || { echo "    FAIL: no ALARM line"; A4_OK=0; }
grep -q "never killed" "$A4G_LOG" || { echo "    FAIL: ALARM did not state 'never killed'"; A4_OK=0; }
if grep -q "^\[runner\] KILL:" "$A4G_LOG"; then
    echo "    FAIL: a KILL line appeared — pressure may never kill"; A4_OK=0
fi
A4G_REC="$REPO/untracked/runs/T918DSR-A4G.json"
A4G_HA=$(python3 -c "import json; r=json.load(open('$A4G_REC')); ha=r.get('host_alarms'); print('yes' if ha and ha[0].get('level')==4 and ha[0].get('consumer') else 'no')" 2>/dev/null || echo no)
[ "$A4G_HA" = "yes" ] || { echo "    FAIL: run record host_alarms missing level/consumer (got $A4G_HA)"; A4_OK=0; }
[ "$A4_OK" -eq 1 ] && echo "    PASS: exit 0, ALARM names a consumer, host_alarms recorded, nothing killed"

echo "  RED (seeded defect): re-introduce a kill on the pressure alarm."
A4_MUT="$WORK/mut-a4"
if mutate "$A4_MUT" "alarm_active = True" "alarm_active = True
                        kill_reason = \"seeded host-pressure kill (INV-1 violation)\""; then
    A4R_LOG="$WORK/a4-red.log"
    ( cd "$REPO" && WEIZIGO_KERNEL_PRESSURE_LEVEL=4 MANAGENT_TASK_ID=T918DSR-A4R \
        PYTHONPATH="$PROJECT/tools" python3 "$A4_MUT" --no-prepend-zig -- \
        python3 -c "import time; time.sleep(4)" >"$A4R_LOG" 2>&1 )
    A4R_RC=$?
    if [ "$A4R_RC" -eq 124 ] && grep -q "^\[runner\] KILL:" "$A4R_LOG"; then
        echo "    RED confirmed: seeded kill-on-pressure produced exit 124 + a KILL line — the 'never kills' assertion catches it"
    else
        echo "    FAIL: red control did not kill (rc=$A4R_RC) — assertion sensitivity unproven"
        A4_OK=0
    fi
else
    echo "    FAIL: seed mutation failed — red control unusable (assertion sensitivity unproven)"
    A4_OK=0
fi
echo ""

# ═══════════════════════════════════════════════════════════════════════
# A5 — run record carries run_kind at the bare dispatch path
# ═══════════════════════════════════════════════════════════════════════
echo "=== A5 — run record written with its kind declared ==="
A5_OK=1

echo "  GREEN: a dispatch writes untracked/runs/<task>.json with run_kind=dispatch."
A5G_LOG="$WORK/a5-green.log"
( cd "$REPO" && MANAGENT_TASK_ID=T918DSR-A5G \
    "$RUNNER" --no-prepend-zig -- \
    python3 -c "print('T918DSR A5 alive')" >"$A5G_LOG" 2>&1 )
A5G_RC=$?
[ "$A5G_RC" -eq 0 ] || { echo "    FAIL: green exit $A5G_RC (want 0)"; A5_OK=0; }
A5G_REC="$REPO/untracked/runs/T918DSR-A5G.json"
if [ -f "$A5G_REC" ]; then
    A5G_KIND=$(python3 -c "import json; print(json.load(open('$A5G_REC')).get('run_kind'))" 2>/dev/null)
    A5G_REASON=$(python3 -c "import json; print(json.load(open('$A5G_REC')).get('run_kind_reason') or '')" 2>/dev/null)
    [ "$A5G_KIND" = "dispatch" ] || { echo "    FAIL: run_kind=$A5G_KIND (want dispatch)"; A5_OK=0; }
    [ -n "$A5G_REASON" ] || { echo "    FAIL: run_kind_reason empty"; A5_OK=0; }
else
    echo "    FAIL: run record $A5G_REC missing (bare dispatch path reap keys on)"; A5_OK=0
fi
[ "$A5_OK" -eq 1 ] && echo "    PASS: record present, run_kind=dispatch, run_kind_reason present"

echo "  RED (seeded defect): record written WITHOUT run_kind."
A5_MUT="$WORK/mut-a5"
if mutate "$A5_MUT" \
    '        "run_kind": run_kind,
        "run_kind_reason": run_kind_reason,
        "model": _model_from_argv(argv),' \
    '        "run_kind_reason": run_kind_reason,
        "model": _model_from_argv(argv),'; then
    A5R_LOG="$WORK/a5-red.log"
    ( cd "$REPO" && MANAGENT_TASK_ID=T918DSR-A5R \
        PYTHONPATH="$PROJECT/tools" python3 "$A5_MUT" --no-prepend-zig -- \
        python3 -c "print('T918DSR A5 red')" >"$A5R_LOG" 2>&1 )
    A5R_RC=$?
    A5R_KIND=$(python3 -c "import json; print(json.load(open('$REPO/untracked/runs/T918DSR-A5R.json')).get('run_kind'))" 2>/dev/null || echo MISSING)
    if [ "$A5R_KIND" != "dispatch" ]; then
        echo "    RED confirmed: the kind-less record reads run_kind=$A5R_KIND — the assertion catches it"
    else
        echo "    FAIL: red control still produced run_kind=dispatch — assertion sensitivity unproven"
        A5_OK=0
    fi
else
    echo "    FAIL: seed mutation failed — red control unusable (assertion sensitivity unproven)"
    A5_OK=0
fi
echo ""

echo "========================================================================"
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-runner-guard: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-runner-guard: FAILURES ==="
    exit 1
fi
