#!/bin/sh
# regression-runner-claude-liveness.sh — T634 controls: per-harness liveness fuse.
#
# The startup-liveness fuse (T586) keys on stdout.  That is correct for
# pi/ollama (streaming) and WRONG for claude: headless `claude -p` buffers
# its output to the end, so a claude lane is silent for its whole run.  The
# 600 s fuse killed finished jobs — T616 (600.8 s, 43 KB already on disk)
# vs T615's 598.8 s pass.  Two seconds separated a pass from a failure.
#
# T634 replaces the stdout sensor for claude lanes with an mtime fuse: a
# claude lane is "alive" while its declared deliverables and/or session
# transcript move mtime; the fuse kills only when neither moves for the
# derived threshold (3 x p95 of observed claude wall; n=29, p95=1543.5 s =>
# 4631 s default).  The kill is marked kill_class=liveness so the ledger can
# refuse to attribute it to the model (T629 killed_by).
#
# Arms:
#   survives (seeded)  a claude-named stub that emits NO stdout/stderr for
#                      longer than the OLD startup timeout, while writing a
#                      deliverable + transcript -> SURVIVES (exit 0).  The
#                      T616 shape.  RED (pre-T634): killed at startup-timeout.
#   hung (seeded)      a claude-named stub with no stdout AND no mtime
#                      movement anywhere -> killed with "liveness timeout",
#                      exit 124, run record kill_class=liveness.
#   fast (null)        a claude-named stub that writes its deliverable and
#                      exits immediately -> untouched (exit 0).
#   pi (null)          covered by regression-runner-startup-liveness.sh — the
#                      stdout sensor for pi/ollama is unchanged (T586).
#
# All fixtures are synthetic and run in a scratch git repo under /tmp/weizigo
# — never the live repo.  The runner resolves repo_root from CWD, so the
# scratch cd IS the isolation.  MANAGENT_TASK_ID (not --task-id) makes the
# runner write a run record WITHOUT the auto-claim/auto-done side effects.
#
# Task: T634 · Role: worker · Model: deepseek-v4-pro · Date: 2026-08-22

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
RUNNER="$PROJECT/tools/runner"

mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/t634-claude-XXXXXX)" || { echo "regression-runner-claude-liveness.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
cd "$WORK"
git init -q

# The run record is written under repo_root (this scratch repo), so the live
# repo is never touched.  The closing check is belt-and-braces (F3 class).
LIVE_HB="$PROJECT/untracked/heartbeat.jsonl"
LIVE_HB_BASE=$(wc -l < "$LIVE_HB" 2>/dev/null || echo 0)

check_isolation() {
    ISO_FAIL=0
    APPENDED=$(tail -n +$((LIVE_HB_BASE + 1)) "$LIVE_HB" 2>/dev/null)
    if [ -n "$APPENDED" ] && echo "$APPENDED" | grep -qE 't634-claude-|T9999'; then
        echo "    FAIL: fixture heartbeat line(s) appended to the LIVE heartbeat.jsonl (F3 regression)"
        echo "$APPENDED" | grep -nE 't634-claude-|T9999' | sed 's/^/    | /'
        ISO_FAIL=1
    else
        echo "    PASS: live heartbeat.jsonl — no fixture lines appended during the run"
    fi
    [ "$ISO_FAIL" -eq 0 ] || exit 1
}
trap 'rm -rf "$WORK"; check_isolation' EXIT

# ── bundle: declares the deliverable the runner's fuse watches ────────────
mkdir -p "$WORK/untracked/runs"
cat > "$WORK/untracked/T9999-claude-fuse.md" <<'BUNDLE'
<!--managent set=A deliverables=deliverable.txt priority=99-->
# T9999 — synthetic claude-liveness fixture bundle (regression only)
BUNDLE

# ── fixture: a claude-named stub (argv[0] basename == "claude") ────────────
# The per-harness detector keys on the child binary's basename, so the stub
# must be named `claude` to exercise the real mtime fuse without an LLM.
# The three behaviours are selected by the first argument.  `work` emits NO
# stdout/stderr (the buffering harness shape) while writing a deliverable and
# appending to the transcript — exactly what a working claude lane does.
cat > "$WORK/claude" <<'STUB'
#!/bin/sh
mode="${1:-fast}"
DELIV="deliverable.txt"
TDIR="${WEIZIGO_CLAUDE_TRANSCRIPT_DIR:-/tmp/weizigo-claude-sessions}"
case "$mode" in
  work)
    mkdir -p "$TDIR"
    echo "work" > "$DELIV"
    i=0
    while [ "$i" -lt 5 ]; do
        echo "turn $i" >> "$TDIR/session.jsonl"
        i=$((i+1))
        sleep 1
    done
    ;;
  hung)
    sleep 60
    ;;
  fast)
    echo "fast" > "$DELIV"
    ;;
esac
exit 0
STUB
chmod +x "$WORK/claude"

SESS="$WORK/claude-sessions"
FAIL=0

echo "=== regression-runner-claude-liveness: survives — buffered lane writing work ==="
# The OLD fuse (startup-timeout 2s) would kill this lane at 2s of silence; the
# NEW mtime fuse must let it run its full 5s and exit 0.
set +e
MANAGENT_TASK_ID=T9999 WEIZIGO_CLAUDE_TRANSCRIPT_DIR="$SESS" \
    "$RUNNER" --no-prepend-zig --no-host-guard --startup-timeout 2 \
    --claude-liveness-timeout 10 --max-wall 60 -- ./claude work \
    >"$WORK/work.out" 2>"$WORK/work.err"
WORK_EXIT=$?
set -e
if [ "$WORK_EXIT" -eq 0 ] && [ -f "$WORK/deliverable.txt" ]; then
    if grep -qE 'startup liveness timeout|liveness timeout' "$WORK/work.err"; then
        echo "FAIL: survives — a liveness fuse fired on a lane that was writing its deliverable + transcript"
        cat "$WORK/work.err" | sed 's/^/    | /'
        FAIL=1
    else
        echo "PASS: survives — buffered claude lane (no stdout, 5s) was not killed; exit 0, deliverable on disk"
    fi
else
    echo "FAIL: survives — expected exit 0 with the deliverable written, got $WORK_EXIT"
    cat "$WORK/work.err" | sed 's/^/    | /'
    FAIL=1
fi

echo ""
echo "=== regression-runner-claude-liveness: hung — no stdout, no mtime movement ==="
set +e
MANAGENT_TASK_ID=T9999 WEIZIGO_CLAUDE_TRANSCRIPT_DIR="$SESS" \
    "$RUNNER" --no-prepend-zig --no-host-guard --claude-liveness-timeout 3 \
    --max-wall 60 -- ./claude hung \
    >"$WORK/hung.out" 2>"$WORK/hung.err"
HUNG_EXIT=$?
set -e
HUNG_REC="$WORK/untracked/runs/T9999.json"
if [ "$HUNG_EXIT" -eq 124 ] && grep -q 'liveness timeout' "$WORK/hung.err"; then
    if [ -f "$HUNG_REC" ] && grep -q '"kill_class": "liveness"' "$HUNG_REC"; then
        echo "PASS: hung — claude lane with no mtime movement killed at liveness-timeout (exit 124, kill_class=liveness)"
    else
        echo "FAIL: hung — killed, but the run record does not carry kill_class=liveness"
        cat "$HUNG_REC" 2>/dev/null | sed 's/^/    | /'
        FAIL=1
    fi
else
    echo "FAIL: hung — expected exit 124 with 'liveness timeout', got $HUNG_EXIT"
    cat "$WORK/hung.err" | sed 's/^/    | /'
    FAIL=1
fi

echo ""
echo "=== regression-runner-claude-liveness: fast — untouched ==="
set +e
MANAGENT_TASK_ID=T9999 WEIZIGO_CLAUDE_TRANSCRIPT_DIR="$SESS" \
    "$RUNNER" --no-prepend-zig --no-host-guard --claude-liveness-timeout 5 \
    --max-wall 60 -- ./claude fast \
    >"$WORK/fast.out" 2>"$WORK/fast.err"
FAST_EXIT=$?
set -e
if [ "$FAST_EXIT" -eq 0 ] && ! grep -q 'liveness timeout' "$WORK/fast.err"; then
    echo "PASS: fast — quick claude lane (deliverable written immediately) untouched"
else
    echo "FAIL: fast — expected exit 0 with no liveness kill, got $FAST_EXIT"
    cat "$WORK/fast.err" | sed 's/^/    | /'
    FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-runner-claude-liveness: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-runner-claude-liveness: FAILURES ==="
    exit 1
fi
