#!/bin/sh
# regression-runner-pi-session-liveness.sh — T773 controls: the buffered-pi
# startup fuse (stdout + pi session JSONL liveness).
#
# The stdout-only startup fuse (T586) killed WORKING buffered lanes: `pi`
# buffers stdout to completion, so a lane that IS reading its bundle and
# working writes only to its session JSONL — under `--session <path>`, or
# ~/.pi/agent/sessions/<cwd-slug>/ when no --session was passed — and looks
# silent to a stdout sensor.  T735 attempt 2 (ox-alpha) was killed at
# 600.9 s with 40 assistant turns and 19,060 output tokens already in its
# session file; T616 (claude, Race F) died the same way with its 43 KB
# deliverable on disk.  T773: a liveness fuse for a buffered lane must not
# read stdout alone — the pi session file's mtime is the liveness signal
# (file growth under --session, or the cwd-slug session dir when no
# --session was passed — the same fallback T751 owes the token meter).  A
# lane writing its session is alive, whatever the stream says; and a kill
# note states what was measured, never a cause ("bundle never read?" is a
# causal claim about the model that the evidence refuted).
#
# Arms:
#   survives-session  a pi-named stub with NO stdout that appends to its
#                     --session file continuously, past the old --startup-
#                     timeout -> SURVIVES (exit 0).  The T735 shape with a
#                     dispatch-time session path.  RED (pre-T773): killed
#                     at startup-timeout.
#   survives-fallback a pi-named stub with NO stdout that writes into the
#                     cwd-slug session dir (WEIZIGO_PI_SESSIONS_DIR test
#                     hook) -> SURVIVES.  The no---session dispatch shape
#                     (T735 itself).
#   hung (seeded)     a pi-named stub with no stdout and no session writes
#                     anywhere -> killed at --startup-timeout; the kill note
#                     states measurements only (the "bundle never read?"
#                     string must be absent).
#   scoping (null)    a non-agent command silent past --startup-timeout is
#                     untouched — the check is scoped to agent lanes.
#
# All fixtures are synthetic and run in a scratch git repo under /tmp/weizigo
# — never the live repo.  The runner resolves repo_root from CWD, so the
# scratch cd IS the isolation.
#
# Task: T773 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-23

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
RUNNER="$PROJECT/tools/runner"

mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/t773-pisess-XXXXXX)" || { echo "regression-runner-pi-session-liveness.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
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
    elif echo "$APPENDED" | grep -qE 't773-pisess-|T773PISESS|stub-pi'; then
        echo "    FAIL: fixture heartbeat line(s) appended to the LIVE heartbeat.jsonl (F3 regression)"
        echo "$APPENDED" | grep -nE 't773-pisess-|T773PISESS|stub-pi' | sed 's/^/    | /'
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
# LLM.  Modes:
#   session <path>   append one JSONL line to <path> every second, no
#                    stdout (the buffered-harness shape with --session);
#   fallback <dir>   append one line to <dir>/session.jsonl every second,
#                    no stdout (the buffered-harness shape, cwd-slug dir);
#   hung             sleep, no stdout, no session writes anywhere.
cat > "$WORK/pi" <<'STUB'
#!/bin/sh
# The fixture must be a PURE session writer: any stdout or stderr would be
# a stream-liveness signal and the fuse would pass spuriously.  exec 2>/dev/null
# keeps the shell's own diagnostics (e.g. a missing dir) out of the streams
# the runner watches — only the session-file writes may signal liveness.
#
# The argv mirrors the real dispatch shapes:
#   ./pi --session <path>   (bin/subagent / bakeoff pass --session <file>)
#   ./pi fallback <dir>     (no --session: pi writes the cwd-slug session dir)
#   ./pi hung               (no stdout, no session writes anywhere)
exec 2>/dev/null
mode="$1"
case "$mode" in
  --session)
    target="$2"
    i=0
    while [ "$i" -lt 6 ]; do
        echo "{\"type\":\"message\",\"timestamp\":\"2026-08-23T00:00:0${i}Z\"}" >> "$target"
        i=$((i+1))
        sleep 1
    done
    ;;
  fallback)
    dir="$2"
    mkdir -p "$dir"
    i=0
    while [ "$i" -lt 6 ]; do
        echo "{\"type\":\"message\",\"timestamp\":\"2026-08-23T00:00:0${i}Z\"}" >> "$dir/session.jsonl"
        i=$((i+1))
        sleep 1
    done
    ;;
  hung)
    sleep 60
    ;;
esac
exit 0
STUB
chmod +x "$WORK/pi"

FAIL=0

echo "=== regression-runner-pi-session-liveness: survives-session — buffered lane writing its --session file ==="
# The OLD fuse (--startup-timeout 2) killed this lane at 2 s of silence; the
# NEW fuse must see the --session file growing and let it finish (exit 0).
set +e
"$RUNNER" --no-prepend-zig --no-host-guard --startup-timeout 2 --max-wall 60 \
    -- ./pi --session sess.jsonl >"$WORK/ss.out" 2>"$WORK/ss.err"
SS_EXIT=$?
set -e
if [ "$SS_EXIT" -eq 0 ] && [ -f "$WORK/sess.jsonl" ]; then
    if grep -qE 'startup liveness timeout' "$WORK/ss.err"; then
        echo "FAIL: survives-session — the startup fuse fired on a lane whose --session file was growing"
        cat "$WORK/ss.err" | sed 's/^/    | /'
        FAIL=1
    else
        echo "PASS: survives-session — buffered pi lane (no stdout, --session growing past startup-timeout) not killed; exit 0"
    fi
else
    echo "FAIL: survives-session — expected exit 0 with the session file written, got $SS_EXIT"
    cat "$WORK/ss.err" | sed 's/^/    | /'
    FAIL=1
fi

echo ""
echo "=== regression-runner-pi-session-liveness: survives-fallback — buffered lane writing the cwd-slug session dir ==="
# The T735 shape: no --session at dispatch, pi writes to the cwd-slug session
# dir.  WEIZIGO_PI_SESSIONS_DIR points the sensor at a scratch dir (the test
# hook, mirroring WEIZIGO_CLAUDE_TRANSCRIPT_DIR).
set +e
WEIZIGO_PI_SESSIONS_DIR="$WORK/sessions" \
    "$RUNNER" --no-prepend-zig --no-host-guard --startup-timeout 2 --max-wall 60 \
    -- ./pi fallback "$WORK/sessions" >"$WORK/sf.out" 2>"$WORK/sf.err"
SF_EXIT=$?
set -e
if [ "$SF_EXIT" -eq 0 ] && [ -f "$WORK/sessions/session.jsonl" ]; then
    if grep -qE 'startup liveness timeout' "$WORK/sf.err"; then
        echo "FAIL: survives-fallback — the startup fuse fired on a lane writing the session dir"
        cat "$WORK/sf.err" | sed 's/^/    | /'
        FAIL=1
    else
        echo "PASS: survives-fallback — buffered pi lane (no stdout, session-dir growing) not killed; exit 0"
    fi
else
    echo "FAIL: survives-fallback — expected exit 0 with the session-dir file written, got $SF_EXIT"
    cat "$WORK/sf.err" | sed 's/^/    | /'
    FAIL=1
fi

echo ""
echo "=== regression-runner-pi-session-liveness: hung — no stdout, no session writes anywhere ==="
set +e
"$RUNNER" --no-prepend-zig --no-host-guard --startup-timeout 3 --max-wall 60 \
    -- ./pi hung >"$WORK/hung.out" 2>"$WORK/hung.err"
HUNG_EXIT=$?
set -e
if [ "$HUNG_EXIT" -eq 124 ] && grep -q 'startup liveness timeout' "$WORK/hung.err"; then
    if grep -q 'bundle never read' "$WORK/hung.err"; then
        echo "FAIL: hung — the kill note still asserts the causal claim 'bundle never read?'"
        cat "$WORK/hung.err" | sed 's/^/    | /'
        FAIL=1
    else
        echo "PASS: hung — truly silent pi lane killed at startup-timeout (exit 124), note states measurements only"
    fi
else
    echo "FAIL: hung — expected exit 124 with 'startup liveness', got $HUNG_EXIT"
    cat "$WORK/hung.err" | sed 's/^/    | /'
    FAIL=1
fi

echo ""
echo "=== regression-runner-pi-session-liveness: scoping — non-agent silence untouched ==="
# A generic (non-agent) command that is silent past --startup-timeout must
# NOT be killed by the startup check — the check is scoped to agent lanes.
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
    echo "=== regression-runner-pi-session-liveness: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-runner-pi-session-liveness: FAILURES ==="
    exit 1
fi
