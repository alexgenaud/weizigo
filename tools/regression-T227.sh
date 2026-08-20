#!/bin/bash
# regression-T227.sh — acceptance-check defect controls (T227), rewired for
# the post-T350/T390/T317 managent.  The 2026-08-01 original timed out (>120s)
# in zig build test; T352 diagnosed and fixed that here.
#
# Root cause of the timeout (T352 diagnosis): the pre-flock `lockStateDir`
# mkdir mutex retried in an infinite `while (true)` loop.  A `managent done`
# whose acceptance command failed exited via std.process.exit(1) — which skips
# Zig `defer` cleanup — while still holding the lock, leaking the lock dir.
# The next managent invocation hung forever trying to acquire it.  T337 S0
# replaced the mkdir mutex with flock(2) (kernel-released on any process death,
# bounded ~3.2s retry), so the infinite wait is gone.  What remained was
# bit-rot: the old script's `grep -o 'T[0-9][0-9]*'` captured the banner's
# build timestamp `T00:…` instead of the minted ID, `--agent DSPro` is now a
# non-canonical label, and claim-then-immediate-done trips the T390
# claim-at-close refusal.
#
# Fix: restructure to the proven seeded-store pattern (cf.
# regression-managent-done-two-phase.sh) — scratch git repo under
# /tmp/weizigo, task records seeded directly in_progress with an old claimed
# timestamp, and each `done` run under a wall-clock budget so a future hang
# fails fast instead of stalling the suite.
#
# Controls:
#   1  signal-killed acceptance command (kill -9 $$) must be REJECTED
#   2  deliverables= must stop at the next key= token (acceptance isolated)
#   3  empty --skip-acceptance reason must be REJECTED
#   g  byte-identity: the live kanban must not be mutated
#
# Task: T352 · Role: worker · Model: deepseek-v4-pro · Date: 2026-08-20

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
MG="$PROJECT/bin/managent"
FAIL=0

# T445: /tmp/weizigo decays (tmp sweeps, reboots).  Create it, and REFUSE to
# run if scratch creation fails — an empty scratch var once sent this suite's
# arms into the LIVE repo (2026-08-18 incident).
mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/regression-T227-XXXXXX)" || { echo "regression-T227.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
git init -q
git config user.email t227@test
git config user.name T227
mkdir -p docs/infra/managent untracked tools
STORE="$WORK/docs/infra/managent/tasks.json"
export MANAGENT_STORE="$STORE"

# Byte-identity guard: the live kanban must not be mutated.
LIVE_STORE="$PROJECT/docs/infra/managent/tasks.json"
LIVE_HASH=$(shasum -a 256 "$LIVE_STORE" | cut -d' ' -f1)

red() { echo "    FAIL: $*"; FAIL=1; }
green() { echo "    PASS: $*"; }

# Run a command under a wall-clock budget (portable; macOS has no GNU timeout).
# $1 = budget seconds; remaining args = the command.  Output flows to stdout.
# Returns the command's exit status, or 124 when the budget expired (SIGKILL).
run_budgeted() {
    local budget="$1"; shift
    local pid
    "$@" &
    pid=$!
    local elapsed=0
    while kill -0 "$pid" 2>/dev/null; do
        if [ "$elapsed" -ge "$budget" ]; then
            kill -9 "$pid" 2>/dev/null
            wait "$pid" 2>/dev/null
            echo "  (budget ${budget}s expired — killed pid $pid)" >&2
            return 124
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done
    wait "$pid"
}

seed() {  # $1 = JSON body of one or more task records (no trailing comma)
    printf '{\n  %s,\n  "_sys": {"next_id": 9000, "directive_next": 1}\n}\n' "$1" > "$STORE"
}

# One in_progress task record (bare "KEY":{...} pair): $1=id  $2=acceptance cmd  $3=bundle path
rec() {
    printf '"%s":{"status":"in_progress","agent":"deepseek-v4-pro","model":"deepseek-v4-pro","bundle":"%s","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"2026-08-01T00:00:01Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"verdict":null,"verdict_note":null,"acceptance":"%s","skip_acceptance_reason":null,"claim_count":1}' "$1" "$3" "$2"
}

echo "=== T227 regression tests (isolated store, seeded in_progress) ==="
echo ""

# ── Control 1: signal-killed acceptance command must be REJECTED ───────────
echo '  D1. signal-killed acceptance command (kill -9 $$) is REJECTED'
seed "$(rec D1 'kill -9 $$' 'untracked/D1-bundle.md')"
OUT=$(run_budgeted 20 "$MG" done D1 --status pass --agent deepseek-v4-pro 2>&1); RC=$?
if [ "$RC" -ne 0 ] \
   && echo "$OUT" | grep -q 'acceptance command killed by signal 9' \
   && echo "$OUT" | grep -q 'reverted D1 to in_progress'; then
    green "managent done correctly REJECTED signal-killed acceptance command"
else
    red "signal-killed acceptance was not rejected (RC=$RC): $OUT"
fi

# ── Control 2: deliverables= must stop at the next key= token ──────────────
echo ""
echo "  D2. deliverables= correctly isolated from acceptance= key"
# A committed deliverable in the scratch repo, plus a bundle whose meta header
# places acceptance= right after deliverables=.  If the deliverables parser
# swallowed the acceptance= token, the deliverable would be
# "tools/t227-deliverable.txt acceptance=echo ok" (missing) and done would fail.
echo "fixture deliverable" > tools/t227-deliverable.txt
git add tools/t227-deliverable.txt && git commit -qm "T227 deliverable fixture"
cat > untracked/D2-bundle.md << 'BUNDLEEOF'
<!--managent set=A deliverables=tools/t227-deliverable.txt acceptance=echo ok-->
# test - deliverables parsing
BUNDLEEOF
seed "$(rec D2 'echo ok' 'untracked/D2-bundle.md')"
OUT=$(run_budgeted 20 "$MG" done D2 --status pass --agent deepseek-v4-pro 2>&1); RC=$?
if [ "$RC" -eq 0 ] \
   && echo "$OUT" | grep -q 'acceptance: echo ok OK' \
   && echo "$OUT" | grep -q 'verdict: pass'; then
    green "deliverables= correctly isolated from acceptance= key"
else
    red "deliverables= may have swallowed acceptance= (done rejected, RC=$RC): $OUT"
fi

# ── Control 3: empty --skip-acceptance reason must be REJECTED ─────────────
echo ""
echo "  D3. empty --skip-acceptance reason is REJECTED"
seed "$(rec D3 'echo ok' 'untracked/D3-bundle.md')"
OUT=$(run_budgeted 20 "$MG" done D3 --status pass --agent deepseek-v4-pro --skip-acceptance "" 2>&1); RC=$?
if [ "$RC" -ne 0 ] \
   && echo "$OUT" | grep -q 'REJECTED: D3 --skip-acceptance requires a non-empty reason' \
   && "$MG" show D3 2>/dev/null | grep -q '  D3  in_progress'; then
    green "managent done correctly REJECTED empty --skip-acceptance reason"
else
    red "empty --skip-acceptance reason was not rejected (RC=$RC): $OUT"
fi

# ── Byte-identity assertion ────────────────────────────────────────────────
echo ""
echo "  g. live kanban unchanged"
LIVE_HASH_AFTER=$(shasum -a 256 "$LIVE_STORE" | cut -d' ' -f1)
if [ "$LIVE_HASH" = "$LIVE_HASH_AFTER" ]; then
    green "live kanban unchanged (byte-identical)"
else
    red "live kanban was MUTATED by regression test!"
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== T227 regression: ALL CONTROLS PASSED ==="
else
    echo "=== T227 regression: $FAIL FAILURE(S) ==="
fi
exit "$FAIL"
