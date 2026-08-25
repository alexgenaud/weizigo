#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# tools/regression-max-wall.sh — T968: --max-wall is declared and not enforced
# ═══════════════════════════════════════════════════════════════════════════════
# Measured 2026-08-25T21:11Z (the brief): two dispatched lanes were still
# running at 4h57m and 4h53m against a declared --max-wall 7200 (2h). Both had
# wall_budget: 7200 in their run records. Nothing killed them, nothing flagged
# them. Root cause: T214 demoted --max-wall to a SILENT-CHILD-ONLY fallback —
# the wall check sits in the `else` branch of the watchdog, reachable only when
# NO [progress] line / agent-lane output has ever been seen. A producing lane
# is exempt from its own declared budget FOREVER. That was nobody's decision
# (the brief): the budget is the operator's cost control, not a stuck-detector
# guess — that is what --progress-timeout and the liveness fuses are for.
#
# Controls (test-first per the standing tooling rule — this file was RED
# against the pre-T968 runner on 2026-08-25, all three seeded arms):
#
#   A seeded (pi-shaped producing lane):   a stub `pi` emitting stdout every
#        0.5 s for 30 s, --max-wall 5 → terminated ~5 s (rc 124), run record
#        carries killed_by:"wall" + "wall ceiling" (T629 vocabulary). RED
#        before the fix (ran the full 30 s, exit 0).
#   B seeded (per-provider, ollama-shaped): same shape via a stub `ollama`.
#        If only one provider's path honours the wall, that is the finding.
#   C seeded ([progress]-line producing lane, non-agent): a fixture emitting
#        "[progress]" on stderr every second for 30 s, --max-wall 5 → killed
#        ~5 s. This is the exact path T214 broke.
#   D null: --max-wall 30 on a 5 s command completes untouched, exit 0, no
#        kill fields in the run record.
#   E surface (watch-fleet): a lane PAST its budget must be visible even if a
#        future defect stops the kill again — the over-wall flag renders both
#        numbers (elapsed vs budget); under-budget renders nothing. Known-good
#        AND known-bad asserted against the sourced helper.
#
# Scratch everything under /tmp/weizigo; the live store, live heartbeat.jsonl
# and live untracked/runs are never touched.
# Task: T968 · Role: worker · Model: ox-alpha · Date: 2026-08-25

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
RUNNER="$PROJECT/tools/runner"
FAIL=0

mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/t968-maxwall-XXXXXX)" || {
    echo "regression-max-wall.sh: FATAL — scratch mktemp failed" >&2; exit 2; }
REPO="$WORK/repo"
mkdir -p "$REPO/untracked" "$REPO/untracked/runs" "$REPO/docs/infra/managent" "$WORK/bin"
( cd "$REPO" && git init -q && printf 'untracked/\n' > .gitignore \
    && git add -A && git commit -qm base )

cleanup() {
    [ -n "${WORK:-}" ] && pkill -9 -f "$WORK" 2>/dev/null
    rm -rf "$WORK"
}
trap cleanup EXIT

# ── fixtures ───────────────────────────────────────────────────────────────
# Agent-lane stubs: basename must be pi/ollama/claude for _is_agent_lane.
# Emit stdout every 0.5 s (any stdout byte flips progress_seen for an agent
# lane) and stay alive 30 s.
for name in pi ollama claude; do
cat > "$WORK/bin/$name" <<PYEOF
#!/usr/bin/env python3
import sys, time
end = time.time() + 30.0
while time.time() < end:
    print("$name stub alive", flush=True)   # stdout = liveness signal (T586)
    time.sleep(0.5)
PYEOF
chmod +x "$WORK/bin/$name"
done

# Non-agent producing fixture: "[progress]" markers on stderr every 1 s, 30 s life.
cat > "$WORK/bin/prog30" <<'PYEOF'
#!/usr/bin/env python3
import sys, time
end = time.time() + 30.0
while time.time() < end:
    print("[progress] t=%d" % int(30 - (end - time.time())), file=sys.stderr, flush=True)
    time.sleep(1.0)
PYEOF
chmod +x "$WORK/bin/prog30"

# ── helpers ────────────────────────────────────────────────────────────────
rec_field() {  # <repo> <task> <python expr over d>
    python3 -c "
import json,sys
try: d=json.load(open('$1/untracked/runs/$2.json'))
except Exception: print('MISSING-RECORD'); sys.exit()
print(eval(sys.argv[1], {'d': d}))" "$3"; }

# Seeded wall-kill arm: $1 label, $2 task id, $3 child command (exec'd in repo)
seeded_arm() {
    local label="$1" task="$2"; shift 2
    echo "=== regression-max-wall: $label ==="
    local t0=$(date +%s)
    ( cd "$REPO" && MANAGENT_TASK_ID="$task" "$RUNNER" --no-prepend-zig \
        --no-host-guard --max-wall 5 -- "$@" >/dev/null 2>"$WORK/$task.err" )
    local rc=$?
    local dt=$(( $(date +%s) - t0 ))
    local kb kmsg
    kb=$(rec_field "$REPO" "$task" 'd.get("killed_by")')
    kmsg=$(rec_field "$REPO" "$task" 'str(d.get("killed"))')
    local ok=1
    # ~5 s budget: generous 15 s upper bound so a loaded host cannot flake,
    # while still proving the 30 s child did NOT run to completion.
    if [ "$rc" != "124" ]; then
        echo "    FAIL: expected exit 124 (wall kill), got $rc after ${dt}s"; ok=0
    fi
    if [ "$dt" -ge 15 ]; then
        echo "    FAIL: lane survived ${dt}s against --max-wall 5 (the T968 defect)"; ok=0
    fi
    if [ "$kb" != "wall" ]; then
        echo "    FAIL: killed_by='$kb', expected 'wall' (T629 vocabulary)"; ok=0
    fi
    case "$kmsg" in
        *"wall ceiling"*) : ;;
        *) echo "    FAIL: killed message lacks 'wall ceiling': '$kmsg'"; ok=0 ;;
    esac
    if [ "$ok" = "1" ]; then
        echo "    PASS: killed at ${dt}s (budget 5s), rc=$rc, killed_by=wall, reason recorded"
    else
        sed -n '1,5p' "$WORK/$task.err" 2>/dev/null | sed 's/^/      | /'
        FAIL=1
    fi
}

# ── A. seeded: pi-shaped producing lane (openrouter dispatch shape) ────────
seeded_arm "A. seeded: pi/openrouter producing lane killed at --max-wall 5" \
    T968A "$WORK/bin/pi" --provider openrouter --model ox-alpha --mode json \
          -p "Follow untracked/T968A.md"

# ── B. seeded: per-provider control — ollama-shaped lane ───────────────────
seeded_arm "B. seeded: ollama producing lane killed at --max-wall 5" \
    T968B "$WORK/bin/ollama" launch pi --model glm-5.2:cloud -y -- \
          -p "Follow untracked/T968B.md"

# ── C. seeded: [progress]-emitting non-agent lane (the exact T214 path) ────
seeded_arm "C. seeded: [progress]-producing lane killed at --max-wall 5" \
    T968C "$WORK/bin/prog30"

# ── D. null: well-within-budget run completes untouched ────────────────────
echo "=== regression-max-wall: D. null: --max-wall 30 on a 5s command completes clean ==="
( cd "$REPO" && MANAGENT_TASK_ID=T968D "$RUNNER" --no-prepend-zig \
    --no-host-guard --max-wall 30 -- sleep 5 >/dev/null 2>"$WORK/t968d.err" )
DRC=$?
D_KB=$(rec_field "$REPO" T968D 'd.get("killed_by")')
D_EXIT=$(rec_field "$REPO" T968D 'd.get("exit")')
if [ "$DRC" = "0" ] && [ "$D_KB" = "None" ] && [ "$D_EXIT" = "0" ]; then
    echo "    PASS: exit 0, no killed_by, run record clean"
else
    echo "    FAIL: rc=$DRC killed_by=$D_KB exit=$D_EXIT — a clean run must carry no kill"
    FAIL=1
fi

# ── E. surface: watch-fleet flags a lane past its budget (both numbers) ────
echo "=== regression-max-wall: E. surface: watch-fleet over-wall flag ==="
if [ ! -f "$PROJECT/untracked/watch-fleet.sh" ]; then
    echo "    SKIP: untracked/watch-fleet.sh absent"
else
    WF_OUT=$(cd "$PROJECT" && WATCH_FLEET_SOURCE=1 sh -c '
        . ./untracked/watch-fleet.sh >/dev/null 2>&1
        over_wall 17800 7200
        over_wall 100 7200' 2>/dev/null)
    BAD_LINE=$(printf '%s\n' "$WF_OUT" | sed -n '1p')
    GOOD_LINE=$(printf '%s\n' "$WF_OUT" | sed -n '2p')
    E_OK=1
    # 17800 s renders as 4h56, 7200 s as 2h00 — both numbers visible in the flag.
    case "$BAD_LINE" in
        *"OVER-WALL"*"4h56"*"2h00"*) : ;;
        *) echo "    FAIL: past-budget lane not flagged with BOTH numbers, got: '$BAD_LINE'"; E_OK=0 ;;
    esac
    [ "$GOOD_LINE" = "" ] || { echo "    FAIL: under-budget lane flagged: '$GOOD_LINE' (known-bad: flagging correct lanes trains the operator to ignore the marker)"; E_OK=0; }
    if [ "$E_OK" = "1" ]; then
        echo "    PASS: over-budget renders 'OVER-WALL(elapsed/budget)', under-budget renders nothing"
    else
        FAIL=1
    fi
fi

# ── verdict ────────────────────────────────────────────────────────────────
if [ "$FAIL" = "0" ]; then
    echo "=== regression-max-wall: all controls passed ==="
    exit 0
else
    echo "=== regression-max-wall: FAILURES (see above) ==="
    exit 1
fi
