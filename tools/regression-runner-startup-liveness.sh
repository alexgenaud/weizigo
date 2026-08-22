#!/bin/sh
# regression-runner-startup-liveness.sh — T586 controls: startup liveness check.
#
# The nonce-stall failure mode (T586): a dispatched pi/deepseek worker
# launched, claimed the row, then produced ZERO stdout/stderr for its whole
# run — its activity (model reasoning, tool calls) goes only to the
# per-session JSONL under ~/.pi/agent/sessions/, never to the captured
# streams.  tools/runner's progress watchdog keys on the captured streams,
# saw a "silent child", and SIGKILLed at the --max-wall ceiling (45 min).
# verify_dispatch then reported "FAIL nonce: the worker did not read the
# instruction bundle" — misleading: the bundle WAS read; the worker was
# killed mid-work.  The fix is two-fold and both halves are pinned here:
#
#   1. agent lanes (pi/claude/ollama) treat stdout output as a liveness
#      signal, so a streaming worker is never mis-classified "silent";
#   2. an agent lane that emits NOTHING within --startup-timeout of launch
#      is killed LOUDLY with a distinct reason — a 10-minute anomaly, not
#      a silent 45-minute burn.
#
# Arms:
#   red (seeded)   a pi-named stub that never reads the bundle (no output)
#                  is killed at --startup-timeout with "startup liveness".
#                  RED RUN (pre-T586): the same stub burned the full wall.
#   green (null)   a pi-named stub that echoes the nonce (any stdout) is
#                  NOT killed — the runner sees liveness and lets it exit.
#   scoping (null) a NON-agent command (sleep) that is silent past
#                  --startup-timeout is NOT killed — the check is scoped
#                  to agent lanes, so generic `zig build`-shaped runs are
#                  untouched.
#
# All fixtures are synthetic and run in a scratch git repo under
# /tmp/weizigo — never the live repo.  The runner resolves repo_root from
# CWD, so the scratch cd IS the isolation.  The closing check scans the
# LIVE heartbeat.jsonl for this suite's fixture commands (F3 defect class).
#
# Task: T586 · Role: worker · Model: deepseek-v4-pro · Date: 2026-08-22

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
RUNNER="$PROJECT/tools/runner"

mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/t586-startup-XXXXXX)" || { echo "regression-runner-startup-liveness.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
cd "$WORK"
git init -q

# ── live-telemetry baseline + closing isolation (T512, audit F3) ────────
# The live heartbeat.jsonl is append-only and the live fleet may
# legitimately append while this suite runs, so the closing check cannot
# byte-compare; it snapshots the line count and scans only the lines
# appended DURING the run for this suite's fixture commands.
LIVE_HB="$PROJECT/untracked/heartbeat.jsonl"
LIVE_HB_BASE=$(wc -l < "$LIVE_HB" 2>/dev/null || echo 0)

check_isolation() {
    ISO_FAIL=0
    APPENDED=$(tail -n +$((LIVE_HB_BASE + 1)) "$LIVE_HB" 2>/dev/null)
    if [ -z "$APPENDED" ]; then
        echo "    PASS: live heartbeat.jsonl — no lines appended during the run"
    elif echo "$APPENDED" | grep -qE 't586-startup-|T586STARTUP|stub-pi'; then
        echo "    FAIL: fixture heartbeat line(s) appended to the LIVE heartbeat.jsonl (F3 regression)"
        echo "$APPENDED" | grep -nE 't586-startup-|T586STARTUP|stub-pi' | sed 's/^/    | /'
        ISO_FAIL=1
    else
        echo "    PASS: live heartbeat.jsonl — appended lines carry no fixture data"
    fi
    [ "$ISO_FAIL" -eq 0 ] || exit 1
}
trap 'rm -rf "$WORK"; check_isolation' EXIT

# ── fixture: a pi-named stub (argv[0] basename == "pi") ──────────────────
# The agent-lane detector keys on the child binary's basename, so the stub
# must be named `pi` to exercise the real startup-liveness path without an
# LLM.  The two behaviours are selected by the first prompt argument.
cat > "$WORK/pi" <<'STUB'
#!/bin/sh
# stub pi: $1 == "silent" -> never reads the bundle (no output, sleep);
#          otherwise      -> echo the nonce line it was handed.
if [ "${1:-}" = "silent" ]; then
    sleep 60
else
    echo "$2"
fi
STUB
chmod +x "$WORK/pi"

FAIL=0

echo "=== regression-runner-startup-liveness: red — silent agent lane killed loud ==="
set +e
"$RUNNER" --no-prepend-zig --no-host-guard --startup-timeout 3 --max-wall 60 \
    -- ./pi silent >"$WORK/red.out" 2>"$WORK/red.err"
RED_EXIT=$?
set -e
if [ "$RED_EXIT" -eq 124 ] && grep -q 'startup liveness timeout' "$WORK/red.err"; then
    echo "PASS: red — silent pi lane killed at startup-timeout with 'startup liveness' reason (exit 124)"
else
    echo "FAIL: red — expected exit 124 with 'startup liveness', got $RED_EXIT"
    cat "$WORK/red.err" | sed 's/^/    | /'
    FAIL=1
fi

echo ""
echo "=== regression-runner-startup-liveness: green — agent lane with output untouched ==="
set +e
"$RUNNER" --no-prepend-zig --no-host-guard --startup-timeout 3 --max-wall 60 \
    -- ./pi go "NONCE-586green" >"$WORK/green.out" 2>"$WORK/green.err"
GREEN_EXIT=$?
set -e
if [ "$GREEN_EXIT" -eq 0 ] && grep -q 'NONCE-586green' "$WORK/green.out"; then
    if grep -q 'startup liveness timeout' "$WORK/green.err"; then
        echo "FAIL: green — startup liveness fired on a worker that produced output"
        cat "$WORK/green.err" | sed 's/^/    | /'
        FAIL=1
    else
        echo "PASS: green — worker that echoed the nonce was not killed (exit 0, output forwarded)"
    fi
else
    echo "FAIL: green — expected exit 0 with the nonce echoed, got $GREEN_EXIT"
    cat "$WORK/green.err" | sed 's/^/    | /'
    FAIL=1
fi

echo ""
echo "=== regression-runner-startup-liveness: scoping — non-agent silence untouched ==="
# A generic (non-agent) command that is silent past --startup-timeout must
# NOT be killed by the startup check — the check is scoped to agent lanes,
# so a long silent `zig build`-shaped run keeps its wall/CPU semantics.
set +e
"$RUNNER" --no-prepend-zig --no-host-guard --startup-timeout 1 --max-wall 60 \
    -- sleep 2 >"$WORK/scope.out" 2>"$WORK/scope.err"
SCOPE_EXIT=$?
set -e
if [ "$SCOPE_EXIT" -eq 0 ] && ! grep -q 'startup liveness timeout' "$WORK/scope.err"; then
    echo "PASS: scoping — non-agent silent for 2s > startup-timeout 1s was not killed"
else
    echo "FAIL: scoping — expected exit 0 with no startup-liveness kill, got $SCOPE_EXIT"
    cat "$WORK/scope.err" | sed 's/^/    | /'
    FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-runner-startup-liveness: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-runner-startup-liveness: FAILURES ==="
    exit 1
fi
