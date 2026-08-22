#!/bin/sh
# regression-runner-agent-progress.sh — T643 controls: per-harness progress watchdog.
#
# The progress watchdog (T214) fired at a flat --progress-timeout (600 s)
# without a [progress] line.  T634 fixed the identical defect in the STARTUP
# fuse for claude; T643 fixes it in the PROGRESS fuse for pi/ollama: a
# deepseek lane does normal long work (p95 wall 2445.05 s, n=66) and its
# stream goes quiet during long reasoning stretches while it writes its
# deliverable, so a 600 s fuse killed finished lanes (T526 1129.6 s, T635
# 1732.6 s, T638 1901.3 s — all three BELOW the family p95).  Two fixes,
# mirroring T634:
#   1. the progress sensor adds the declared deliverables' mtime — a lane
#      writing its deliverable is making progress, whatever its stream says;
#   2. the threshold is derived, not chosen: 3 x p95 wall per family
#      (pi/deepseek 7336 s, ollama 6766 s; --agent-progress-timeout overrides).
# Kills are unscoreable: the reason still starts "progress timeout", which the
# runner stamps killed_by=watchdog (T629's vocabulary — no second enum).
#
# Arms:
#   survives (seeded) a pi-named stub that emits one liveness line then writes
#                     its declared deliverable steadily with NO [progress] line
#                     -> SURVIVES.  The T638 shape.  RED (pre-T643): the flat
#                     progress-timeout killed it for a quiet stream.
#   stalled (seeded)  a pi-named stub that emits once then produces NO output
#                     and NO deliverable mtime movement -> killed with
#                     "progress timeout", exit 124, run record
#                     killed_by=watchdog (unscoreable).
#   silent (null)     a pi-named stub that emits NOTHING since launch ->
#                     killed at --startup-timeout (T586's protection stays).
#   non-agent (null)  a NON-agent child that emits a [progress] line then goes
#                     quiet -> still killed by --progress-timeout (T214 path
#                     unchanged for generic builds).
#   derived (null)    the per-family threshold is printed for pi (7336 s) and
#                     ollama (6766 s) when --agent-progress-timeout is unset.
#
# All fixtures are synthetic and run in a scratch git repo under /tmp/weizigo
# — never the live repo.  The runner resolves repo_root from CWD, so the
# scratch cd IS the isolation.  MANAGENT_TASK_ID (not --task-id) makes the
# runner write a run record WITHOUT the auto-claim/auto-done side effects.
#
# Task: T643 · Role: worker · Model: deepseek-v4-pro · Date: 2026-08-22

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
RUNNER="$PROJECT/tools/runner"

mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/t643-agentprog-XXXXXX)" || { echo "regression-runner-agent-progress.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
cd "$WORK"
git init -q

# ── live-telemetry baseline + closing isolation (T512, audit F3) ────────
LIVE_HB="$PROJECT/untracked/heartbeat.jsonl"
LIVE_HB_BASE=$(wc -l < "$LIVE_HB" 2>/dev/null || echo 0)

check_isolation() {
    ISO_FAIL=0
    APPENDED=$(tail -n +$((LIVE_HB_BASE + 1)) "$LIVE_HB" 2>/dev/null)
    if [ -z "$APPENDED" ]; then
        echo "    PASS: live heartbeat.jsonl — no lines appended during the run"
    elif echo "$APPENDED" | grep -qE 't643-agentprog-|T9999'; then
        echo "    FAIL: fixture heartbeat line(s) appended to the LIVE heartbeat.jsonl (F3 regression)"
        echo "$APPENDED" | grep -nE 't643-agentprog-|T9999' | sed 's/^/    | /'
        ISO_FAIL=1
    else
        echo "    PASS: live heartbeat.jsonl — appended lines carry no fixture data"
    fi
    [ "$ISO_FAIL" -eq 0 ] || exit 1
}
trap 'rm -rf "$WORK"; check_isolation' EXIT

# ── bundle: declares the deliverable the runner's progress sensor watches ──
mkdir -p "$WORK/untracked/runs"
cat > "$WORK/untracked/T9999-agent-progress.md" <<'BUNDLE'
<!--managent set=A deliverables=deliverable.txt priority=99-->
# T9999 — synthetic agent-progress fixture bundle (regression only)
BUNDLE

# ── fixture: a pi-named stub (argv[0] basename == "pi") ──────────────────
# The agent-lane detector keys on the child binary's basename, so the stub
# must be named `pi` to exercise the real pi/ollama progress watchdog without
# an LLM.  `work` replays T638's shape: one liveness line (progress_seen=True),
# then the declared deliverable is written steadily with NO further stdout and
# no [progress] line.  `stall` emits once then stalls with no mtime movement.
# `silent` never emits (T586 startup fuse).  `fast` writes and exits.
cat > "$WORK/pi" <<'STUB'
#!/bin/sh
mode="${1:-fast}"
case "$mode" in
  work)
    echo "started"
    i=0
    while [ "$i" -lt 5 ]; do
        echo "verdict $i" >> deliverable.txt
        i=$((i+1))
        sleep 1
    done
    ;;
  stall)
    echo "started"
    sleep 60
    ;;
  silent)
    sleep 60
    ;;
  fast)
    echo "done" > deliverable.txt
    ;;
esac
exit 0
STUB
chmod +x "$WORK/pi"
# Same stub under an ollama name — family detection is by basename, so a
# symlink exercises the ollama derived threshold without a second file.
ln -s pi "$WORK/ollama"

FAIL=0

echo "=== regression-runner-agent-progress: survives — lane writing its deliverable ==="
# The OLD flat progress-timeout (3 s here) would kill this lane at 3 s of
# quiet stream; the NEW sensor counts the deliverable mtime as progress.
set +e
MANAGENT_TASK_ID=T9999 \
    "$RUNNER" --no-prepend-zig --no-host-guard --startup-timeout 2 \
    --agent-progress-timeout 4 --max-wall 60 -- ./pi work \
    >"$WORK/work.out" 2>"$WORK/work.err"
WORK_EXIT=$?
set -e
if [ "$WORK_EXIT" -eq 0 ] && [ "$(wc -l < deliverable.txt 2>/dev/null || echo 0)" -eq 5 ]; then
    if grep -q 'progress timeout' "$WORK/work.err"; then
        echo "FAIL: survives — the progress watchdog fired on a lane that was writing its deliverable"
        cat "$WORK/work.err" | sed 's/^/    | /'
        FAIL=1
    else
        echo "PASS: survives — pi lane writing its deliverable (no [progress]) was not killed; exit 0, 5 verdicts on disk"
    fi
else
    echo "FAIL: survives — expected exit 0 with 5 deliverable lines, got $WORK_EXIT"
    cat "$WORK/work.err" | sed 's/^/    | /'
    FAIL=1
fi

echo ""
echo "=== regression-runner-agent-progress: stalled — no output, no mtime movement ==="
set +e
MANAGENT_TASK_ID=T9999 \
    "$RUNNER" --no-prepend-zig --no-host-guard --agent-progress-timeout 3 \
    --max-wall 60 -- ./pi stall \
    >"$WORK/stall.out" 2>"$WORK/stall.err"
STALL_EXIT=$?
set -e
STALL_REC="$WORK/untracked/runs/T9999.json"
if [ "$STALL_EXIT" -eq 124 ] && grep -q 'progress timeout' "$WORK/stall.err"; then
    if [ -f "$STALL_REC" ] && grep -q '"killed_by": "watchdog"' "$STALL_REC"; then
        echo "PASS: stalled — pi lane with no output and no mtime movement killed at agent-progress-timeout (exit 124, killed_by=watchdog)"
    else
        echo "FAIL: stalled — killed, but the run record does not carry killed_by=watchdog"
        cat "$STALL_REC" 2>/dev/null | sed 's/^/    | /'
        FAIL=1
    fi
else
    echo "FAIL: stalled — expected exit 124 with 'progress timeout', got $STALL_EXIT"
    cat "$WORK/stall.err" | sed 's/^/    | /'
    FAIL=1
fi

echo ""
echo "=== regression-runner-agent-progress: silent — T586 startup fuse unchanged ==="
set +e
MANAGENT_TASK_ID=T9999 \
    "$RUNNER" --no-prepend-zig --no-host-guard --startup-timeout 3 --max-wall 60 \
    -- ./pi silent >"$WORK/silent.out" 2>"$WORK/silent.err"
SILENT_EXIT=$?
set -e
if [ "$SILENT_EXIT" -eq 124 ] && grep -q 'startup liveness timeout' "$WORK/silent.err"; then
    echo "PASS: silent — pi lane emitting nothing since launch killed at startup-timeout (T586 stays)"
else
    echo "FAIL: silent — expected exit 124 with 'startup liveness', got $SILENT_EXIT"
    cat "$WORK/silent.err" | sed 's/^/    | /'
    FAIL=1
fi

echo ""
echo "=== regression-runner-agent-progress: non-agent [progress] watchdog unchanged ==="
set +e
MANAGENT_TASK_ID=T9999 \
    "$RUNNER" --no-prepend-zig --no-host-guard --progress-timeout 3 --max-wall 60 \
    -- python3 -c "import sys,time; sys.stderr.write('[progress] start\n'); sys.stderr.flush(); time.sleep(60)" \
    >"$WORK/prog.out" 2>"$WORK/prog.err"
PROG_EXIT=$?
set -e
if [ "$PROG_EXIT" -eq 124 ] && grep -q 'no \[progress\]' "$WORK/prog.err"; then
    echo "PASS: non-agent — a [progress]-emitting child that stops is still killed at --progress-timeout (T214 path)"
else
    echo "FAIL: non-agent — expected exit 124 with 'no [progress]', got $PROG_EXIT"
    cat "$WORK/prog.err" | sed 's/^/    | /'
    FAIL=1
fi

echo ""
echo "=== regression-runner-agent-progress: derived per-family thresholds ==="
set +e
MANAGENT_TASK_ID=T9999 \
    "$RUNNER" --no-prepend-zig --no-host-guard --max-wall 30 -- ./pi fast \
    >"$WORK/dpi.out" 2>"$WORK/dpi.err"
DPI_EXIT=$?
MANAGENT_TASK_ID=T9999 \
    "$RUNNER" --no-prepend-zig --no-host-guard --max-wall 30 -- ./ollama fast \
    >"$WORK/doll.out" 2>"$WORK/doll.err"
DOLL_EXIT=$?
set -e
if [ "$DPI_EXIT" -eq 0 ] && grep -q 'timeout 7336s' "$WORK/dpi.err" \
   && [ "$DOLL_EXIT" -eq 0 ] && grep -q 'timeout 6766s' "$WORK/doll.err"; then
    echo "PASS: derived — pi lane prints timeout 7336s, ollama lane prints timeout 6766s (3 x p95 per family)"
else
    echo "FAIL: derived — expected pi=7336s and ollama=6766s in the startup banner"
    echo "--- pi ---"; cat "$WORK/dpi.err" | sed 's/^/    | /'
    echo "--- ollama ---"; cat "$WORK/doll.err" | sed 's/^/    | /'
    FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-runner-agent-progress: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-runner-agent-progress: FAILURES ==="
    exit 1
fi
