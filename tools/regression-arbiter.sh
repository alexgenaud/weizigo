#!/usr/bin/env bash
# regression-arbiter.sh — T821 controls: the one admission/pressure arbiter
# that replaced the T362/T711 host-pressure guard and the T713 memory gate.
#
# docs/infra/host/ram-policy.md is the mandate: the `total // 8` host floor
# and its largest-member kill are DELETED (16 of 20 recorded kills were
# futile, 0 of 20 were both necessary and effective).  In their place:
#   L2 admission  — tools/runner --ram-mb / --arbiter-admit / --arbiter-preview
#                   checks a declared need against what is already admitted
#                   BEFORE a child is spawned (ORC-GD-3/INV-3).  Refuse =
#                   nothing is ever spawned, the row stays dispatchable.
#   L0 overrun stop — --rss-cap-mb, sized to ceil(declared * 1.25) unless
#                   explicit, is the ONLY remaining stop a running task can
#                   suffer, and it is always that task's OWN overrun
#                   (INV-1/INV-4) — never a stranger's memory.
#   L3 alarm       — a sustained kernel pressure reading (never a hand-rolled
#                   fraction of hw.memsize) ALARMS, names the real host-wide
#                   consumer, and never kills (§4.3-4.4).
#
# The five controls this file's brief names, each RED (against the
# committed pre-T821 tools/runner, extracted from git HEAD) before GREEN
# (against the working tree):
#   1. REAL CO-LAUNCH   a resident-model-shaped lane and three cloud-shaped
#                        lanes launch together reading the REAL host avail
#                        (no WEIZIGO_HOST_MEM_AVAIL_MB injection) — assert
#                        no lane dies.  "Real" means the memory READING is
#                        live, not that this script drives an actual LLM
#                        inference call (that is every other harness
#                        regression script's job, e.g.
#                        tools/regression-runner-pi-session-liveness.sh);
#                        what T821 changes is what the arbiter DOES with a
#                        real reading, and that is what this control drives
#                        live.
#   2. FUTILE-KILL      injected shortfall, the only process group member
#                        smaller than it — assert NOTHING is killed.
#   3. EFFECTIVE-KILL   one member over ITS OWN declared need by >125% —
#                        assert exactly that member is stopped, labeled.
#   4. REFUSAL          declared need does not fit what is already admitted
#                        — assert refused, row stays dispatchable, NO
#                        process spawned, nothing running touched.
#   5. NULL             ample avail, ample declared fit — nothing refused,
#                        nothing killed, no behaviour change.
#
# The RED baseline is pinned to `git show HEAD:tools/runner` (the committed,
# pre-T821 file), extracted to a disposable copy INSIDE tools/ so its
# sibling imports (directive_policy, model_tags) still resolve, and cleaned
# up on exit.  Everything runs from a scratch git repo under /tmp/weizigo —
# the live kanban, live untracked/ and the live repo are never touched
# (T512/F3: the closing check scans the LIVE heartbeat.jsonl for fixture
# markers).  MANAGENT_TASK_ID (env, not --task-id) names every fixture run
# so no auto-claim touches any kanban, and every arbiter ledger uses its
# own --arbiter-state-file so no fixture ever reads or writes the live
# untracked/arbiter-state.json.
#
# Task: T821 · Role: worker · Model: claude-sonnet-5 · Date: 2026-08-24

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
NEW_RUNNER="$PROJECT/tools/runner"
OLD_RUNNER="$PROJECT/tools/.regression-arbiter-old-runner.tmp"
FAIL=0

mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/t821-arbiter-XXXXXX)" \
    || { echo "regression-arbiter.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
REPO="$WORK/repo"
mkdir -p "$REPO/untracked" "$REPO/docs/infra/managent"
( cd "$REPO" && git init -q && printf 'untracked/\n' > .gitignore && git add -A && git commit -qm base )

# ── the RED baseline: the committed pre-T821 runner, pinned by git ────────
# Extracted INSIDE tools/ (not /tmp) so `import directive_policy` /
# `import model_tags` resolve exactly as they do for the live file — same
# directory, same sys.path[0] trick python gives every script run by path.
git -C "$PROJECT" show HEAD:tools/runner > "$OLD_RUNNER" 2>/dev/null \
    || { echo "regression-arbiter.sh: FATAL — could not extract HEAD:tools/runner" >&2; exit 2; }
chmod +x "$OLD_RUNNER"

# ── live-telemetry baseline + closing isolation (T512, F3) ────────────────
LIVE_HB="$PROJECT/untracked/heartbeat.jsonl"
LIVE_HB_BASE=$(wc -l < "$LIVE_HB" 2>/dev/null || echo 0)

check_isolation() {
    ISO_FAIL=0
    APPENDED=$(tail -n +$((LIVE_HB_BASE + 1)) "$LIVE_HB" 2>/dev/null)
    if [ -z "$APPENDED" ]; then
        echo "    PASS: live heartbeat.jsonl — no lines appended during the run"
    elif echo "$APPENDED" | grep -q "T821ARB"; then
        echo "    FAIL: fixture heartbeat line(s) appended to the LIVE heartbeat.jsonl (F3 regression)"
        echo "$APPENDED" | grep -n "T821ARB" | sed 's/^/    | /'
        ISO_FAIL=1
    else
        echo "    PASS: live heartbeat.jsonl — appended lines carry no fixture data"
    fi
    [ "$ISO_FAIL" -eq 0 ] || exit 1
}

cleanup() {
    if [ -n "${WORK:-}" ]; then
        pkill -CONT -f "$WORK" 2>/dev/null
        pkill -9 -f "$WORK" 2>/dev/null
    fi
    rm -f "$OLD_RUNNER"
    [ -n "${T821ARB_KEEP_WORK:-}" ] && cp -r "$WORK" "${T821ARB_KEEP_WORK}"
    rm -rf "$WORK"
    check_isolation
}
trap cleanup EXIT

# Live avail/total, sampled once so a fixture can reason about real numbers.
REAL_AVAIL_MB=$(WEIZIGO_HOST_MEM_AVAIL_MB= python3 -c "
import sys; sys.path.insert(0, '$PROJECT/tools')
import importlib.util
from importlib.machinery import SourceFileLoader
loader = SourceFileLoader('runner', '$NEW_RUNNER')
spec = importlib.util.spec_from_loader('runner', loader)
mod = importlib.util.module_from_spec(spec)
loader.exec_module(mod)
b = mod._host_avail_bytes()
print(b // (1024*1024) if b is not None else '')
")
if [ -z "$REAL_AVAIL_MB" ]; then
    echo "regression-arbiter.sh: FATAL — could not read real host avail memory (needed for controls 1/5)" >&2
    exit 2
fi
echo "(real host avail sampled once: ${REAL_AVAIL_MB} MB — controls 1 and 5 reason about this number)"
echo ""

# ═══════════════════════════════════════════════════════════════════════
# Control 2 — FUTILE-KILL: shortfall injected, every member smaller than it
# ═══════════════════════════════════════════════════════════════════════
echo "=== control 2 — futile-kill: no member's RSS covers the shortfall ==="

echo "  RED (pre-T821, HEAD): the floor's largest-member selector kills the"
echo "  lone (small) member anyway — the 2026-08-23 15:19:09 incident's own"
echo "  shape (three lanes of 251/133/129 MB killed for a 383 MB shortfall)."
RED_LOG="$WORK/c2-red.log"
( cd "$REPO" && WEIZIGO_HOST_MEM_AVAIL_MB=100 MANAGENT_TASK_ID=T821ARB-C2-RED \
    "$OLD_RUNNER" --no-prepend-zig --host-mem-floor-mb 4096 --max-wall 10 -- \
    python3 -c "import time; time.sleep(0.2); print('T821ARB small member alive')" \
    >"$RED_LOG" 2>&1 )
RED_RC=$?
if [ "$RED_RC" -eq 124 ] && grep -q "host memory pressure" "$RED_LOG"; then
    echo "    RED confirmed: pre-T821 killed the lone small member (exit $RED_RC)"
else
    echo "    WARN: pre-T821 arm did not reproduce the expected RED (rc=$RED_RC) — proceeding to GREEN regardless"
fi

echo "  GREEN (working tree): no host-condition kill exists at all — the"
echo "  member survives to completion whatever the injected reading says."
GREEN_LOG="$WORK/c2-green.log"
( cd "$REPO" && WEIZIGO_HOST_MEM_AVAIL_MB=100 MANAGENT_TASK_ID=T821ARB-C2-GREEN \
    "$NEW_RUNNER" --no-prepend-zig --host-mem-floor-mb 4096 --max-wall 10 -- \
    python3 -c "import time; time.sleep(0.2); print('T821ARB small member alive')" \
    >"$GREEN_LOG" 2>&1 )
GREEN_RC=$?
C2_OK=1
[ "$GREEN_RC" -eq 0 ] || { echo "    FAIL: expected exit 0, got $GREEN_RC"; C2_OK=0; }
grep -q "T821ARB small member alive" "$GREEN_LOG" || { echo "    FAIL: member never printed — something killed it"; C2_OK=0; }
grep -q "^\[runner\] KILL:" "$GREEN_LOG" && { echo "    FAIL: a KILL line appeared — nothing may be killed by host pressure"; C2_OK=0; }
[ "$C2_OK" -eq 1 ] && echo "    PASS: nothing killed; the futile-kill class is now structurally impossible" || FAIL=1
echo ""

# ═══════════════════════════════════════════════════════════════════════
# Control 3 — EFFECTIVE-KILL: one member over ITS OWN declared need
# ═══════════════════════════════════════════════════════════════════════
echo "=== control 3 — effective overrun-stop: over its OWN declared need ==="

echo "  RED (pre-T821, HEAD): --ram-mb does not exist — there is no declared-"
echo "  need overrun stop to trigger; the flag is simply refused."
RED_LOG="$WORK/c3-red.log"
( cd "$REPO" && MANAGENT_TASK_ID=T821ARB-C3-RED \
    "$OLD_RUNNER" --no-prepend-zig --ram-mb 100 --max-wall 10 -- \
    python3 -c "print('unreachable')" >"$RED_LOG" 2>&1 )
RED_RC=$?
if [ "$RED_RC" -ne 0 ] && grep -qi "unrecognized arguments" "$RED_LOG"; then
    echo "    RED confirmed: pre-T821 has no --ram-mb / overrun-stop mechanism at all (rc=$RED_RC)"
else
    echo "    WARN: pre-T821 arm did not reproduce the expected RED (rc=$RED_RC) — proceeding to GREEN regardless"
fi

echo "  GREEN (working tree): declares 100 MB, allocates 200 MB (> 125 MB =="
echo "  ceil(100*1.25)) — the cap stops exactly this task for its OWN overrun."
GREEN_LOG="$WORK/c3-green.log"
STATE3="$WORK/arbiter-c3.json"
( cd "$REPO" && MANAGENT_TASK_ID=T821ARB-C3-GREEN \
    "$NEW_RUNNER" --no-prepend-zig --ram-mb 100 --arbiter-state-file "$STATE3" --max-wall 10 -- \
    python3 -c "import time; x = bytearray(200*1024*1024); time.sleep(5)" \
    >"$GREEN_LOG" 2>&1 )
GREEN_RC=$?
C3_OK=1
[ "$GREEN_RC" -eq 124 ] || { echo "    FAIL: expected exit 124, got $GREEN_RC"; C3_OK=0; }
grep -q "RSS cap 125 MB exceeded" "$GREEN_LOG" || { echo "    FAIL: no overrun-stop kill message"; C3_OK=0; }
grep -q "overrunning its OWN declared need" "$GREEN_LOG" || { echo "    FAIL: no INV-4 note naming the OWN overrun"; C3_OK=0; }
REC3="$REPO/untracked/runs/T821ARB-C3-GREEN.json"
if [ -f "$REC3" ]; then
    KB=$(python3 -c "import json; print(json.load(open('$REC3')).get('killed_by'))" 2>/dev/null)
    [ "$KB" = "rss" ] || { echo "    FAIL: run record killed_by=$KB (expected rss)"; C3_OK=0; }
else
    echo "    FAIL: run record $REC3 missing"; C3_OK=0
fi
# the ledger entry must have been released on exit — no leaked reservation
if grep -q '"T821ARB-C3-GREEN"' "$STATE3" 2>/dev/null; then
    echo "    FAIL: arbiter ledger still holds the stopped task's reservation (leak)"; C3_OK=0
fi
[ "$C3_OK" -eq 1 ] && echo "    PASS: exactly the over-declaring member is stopped, labeled killed_by=rss, and released" || FAIL=1
echo ""

# ═══════════════════════════════════════════════════════════════════════
# Control 4 — REFUSAL: declared need does not fit what is already admitted
# ═══════════════════════════════════════════════════════════════════════
echo "=== control 4 — refusal at admission: nothing spawned, row stays dispatchable ==="

echo "  RED (pre-T821, HEAD): no admission concept exists — a tight-avail"
echo "  launch runs unconditionally; the marker proves a process WAS spawned."
RED_MARKER="$WORK/c4-red.marker"
rm -f "$RED_MARKER"
( cd "$REPO" && WEIZIGO_HOST_MEM_AVAIL_MB=5000 MANAGENT_TASK_ID=T821ARB-C4-RED \
    "$OLD_RUNNER" --no-prepend-zig --host-mem-floor-mb 100 --max-wall 10 -- \
    python3 -c "open('$RED_MARKER','w').write('spawned')" >"$WORK/c4-red.log" 2>&1 )
if [ -f "$RED_MARKER" ]; then
    echo "    RED confirmed: pre-T821 spawned the worker despite the caller's own tight-budget intent (no refusal exists to prevent it)"
else
    echo "    WARN: pre-T821 marker missing — proceeding to GREEN regardless"
fi

echo "  GREEN (working tree): avail is INJECTED here (20000 MB) — unlike"
echo "  control 1, this control's point is the admission arithmetic itself,"
echo "  not a real reading, and this live host's avail drifts by thousands"
echo "  of MB across tens of seconds (a resident model's RSS is genuinely"
echo "  non-monotone, ram-policy.md §2.1/ORC-G9) — a fixture racing that"
echo "  drift would be flaky for a reason that has nothing to do with the"
echo "  arbiter.  A competitor is admitted first (15000 of the fixed 20000"
echo "  MB); the second task then declares enough to breach RESERVE_MB."
STATE4="$WORK/arbiter-c4.json"
FIX_AVAIL4=20000
COMPETITOR_MB=15000
WEIZIGO_HOST_MEM_AVAIL_MB="$FIX_AVAIL4" "$NEW_RUNNER" --arbiter-admit --arbiter-id T821ARB-C4-COMPETITOR \
    --ram-mb "$COMPETITOR_MB" --arbiter-state-file "$STATE4" >"$WORK/c4-competitor.log" 2>&1
COMPETITOR_RC=$?
GREEN_MARKER="$WORK/c4-green.marker"
rm -f "$GREEN_MARKER"
GREEN_LOG="$WORK/c4-green.log"
( cd "$REPO" && WEIZIGO_HOST_MEM_AVAIL_MB="$FIX_AVAIL4" MANAGENT_TASK_ID=T821ARB-C4-GREEN \
    "$NEW_RUNNER" --no-prepend-zig --ram-mb 4608 --arbiter-state-file "$STATE4" --max-wall 10 -- \
    python3 -c "open('$GREEN_MARKER','w').write('spawned')" >"$GREEN_LOG" 2>&1 )
GREEN_RC=$?
C4_OK=1
[ "$COMPETITOR_RC" -eq 0 ] || { echo "    FAIL: competitor admit setup failed (rc=$COMPETITOR_RC) — fixture is not meaningful"; C4_OK=0; }
[ "$GREEN_RC" -eq 3 ] || { echo "    FAIL: expected exit 3 (admission refused), got $GREEN_RC"; C4_OK=0; }
grep -q "ARBITER REFUSED" "$GREEN_LOG" || { echo "    FAIL: no ARBITER REFUSED line"; C4_OK=0; }
grep -q "row stays dispatchable" "$GREEN_LOG" || { echo "    FAIL: refusal did not name 'row stays dispatchable'"; C4_OK=0; }
if [ -f "$GREEN_MARKER" ]; then
    echo "    FAIL: the marker file exists — a process WAS spawned despite the refusal"; C4_OK=0
fi
[ "$C4_OK" -eq 1 ] && echo "    PASS: refused before spawn; nothing ran; the row is untouched (still dispatchable)" || FAIL=1
"$NEW_RUNNER" --arbiter-release --arbiter-id T821ARB-C4-COMPETITOR --arbiter-state-file "$STATE4" >/dev/null 2>&1
echo ""

# ═══════════════════════════════════════════════════════════════════════
# Control 5 — NULL: ample avail, ample declared fit — no behaviour change
# ═══════════════════════════════════════════════════════════════════════
echo "=== control 5 — null: ample fit, nothing refused, nothing killed ==="
echo "  avail is INJECTED (20000 MB), same reasoning as control 4: this is a"
echo "  fixed-arithmetic check, not a real-reading demonstration (control 1"
echo "  is), and this live host's avail is not stable enough across tens of"
echo "  seconds to found a should-always-be-green control on."
STATE5="$WORK/arbiter-c5.json"
GREEN_LOG="$WORK/c5-green.log"
( cd "$REPO" && WEIZIGO_HOST_MEM_AVAIL_MB=20000 MANAGENT_TASK_ID=T821ARB-C5 \
    "$NEW_RUNNER" --no-prepend-zig --ram-mb 512 --arbiter-state-file "$STATE5" --max-wall 10 -- \
    python3 -c "print('T821ARB null control alive')" >"$GREEN_LOG" 2>&1 )
RC=$?
C5_OK=1
[ "$RC" -eq 0 ] || { echo "    FAIL: expected exit 0, got $RC"; C5_OK=0; }
grep -q "T821ARB null control alive" "$GREEN_LOG" || { echo "    FAIL: worker output missing"; C5_OK=0; }
grep -q "ARBITER ADMITTED" "$GREEN_LOG" || { echo "    FAIL: no admission line — did the arbiter even run?"; C5_OK=0; }
grep -qE "ARBITER REFUSED|^\[runner\] KILL:|^\[runner\] ALARM:" "$GREEN_LOG" && { echo "    FAIL: unexpected refuse/kill/alarm noise on a null control"; C5_OK=0; }
if grep -q '"T821ARB-C5"' "$STATE5" 2>/dev/null; then
    echo "    FAIL: arbiter ledger still holds the completed task's reservation (leaked, not released)"; C5_OK=0
fi
[ "$C5_OK" -eq 1 ] && echo "    PASS: admitted, ran, completed, released — no behaviour change" || FAIL=1
echo ""

# ═══════════════════════════════════════════════════════════════════════
# Control 1 — REAL CO-LAUNCH: a resident-model-shaped lane + 3 cloud-shaped
#             lanes, concurrent, reading the REAL (uninjected) host avail
# ═══════════════════════════════════════════════════════════════════════
echo "=== control 1 — real co-launch: resident-model + 3 cloud lanes, live avail ==="
echo "  Historical RED: the 2026-08-23 15:19:09 incident is this exact shape"
echo "  under the pre-T821 floor — three cloud lanes (T780/T781/T782, RSS"
echo "  251/133/129 MB) were SIGKILLed for a resident qwen tenant's real"
echo "  footprint (docs/infra/host/ram-policy.md §1, §8, and S08 spec §1.1 —"
echo "  the incident record itself, not re-triggered live here: the tenant's"
echo "  actual size varies run to run and forcing a repeat OOM to prove a"
echo "  historical fact would be reckless on a shared host)."
echo "  GREEN (working tree, no injected numbers): the real host avail"
echo "  sampled above (${REAL_AVAIL_MB} MB) drives every admission decision."
STATE1="$WORK/arbiter-c1.json"
CLOUD_LOGS=()
CLOUD_PIDS=()
for i in 1 2 3; do
    LOG="$WORK/c1-cloud$i.log"
    CLOUD_LOGS+=("$LOG")
    ( cd "$REPO" && MANAGENT_TASK_ID="T821ARB-C1-CLOUD$i" \
        "$NEW_RUNNER" --no-prepend-zig --ram-mb 1024 --arbiter-state-file "$STATE1" --max-wall 15 -- \
        python3 -c "import time; time.sleep(1); print('T821ARB cloud lane $i done')" \
        >"$LOG" 2>&1 ) &
    CLOUD_PIDS+=($!)
done
LOCAL_LOG="$WORK/c1-local.log"
( cd "$REPO" && MANAGENT_TASK_ID="T821ARB-C1-LOCAL" \
    "$NEW_RUNNER" --no-prepend-zig --ram-mb 18432 --arbiter-state-file "$STATE1" --max-wall 15 -- \
    python3 -c "import time; time.sleep(1); print('T821ARB local-model lane done')" \
    >"$LOCAL_LOG" 2>&1 ) &
LOCAL_PID=$!

for p in "${CLOUD_PIDS[@]}" "$LOCAL_PID"; do
    wait "$p" 2>/dev/null
done

# INV-1's actual bar is "never killed for a process it does not conflict
# with" — a REFUSED lane (real avail was tight this run) is a legitimate,
# non-fatal admission outcome for EITHER class of lane; a KILLED lane
# never is.  Match the runner's own line prefixes, not bare substrings —
# "killed=0" in every reap-accounting summary line and "never kills" in
# the guards banner would otherwise false-positive every single run.
C1_OK=1
for i in 1 2 3; do
    LOG="${CLOUD_LOGS[$((i-1))]}"
    if grep -q "^\[runner\] KILL:" "$LOG"; then
        echo "    FAIL: cloud lane $i was KILLED — no lane may die for host pressure"; C1_OK=0
    elif grep -q "T821ARB cloud lane $i done" "$LOG"; then
        : # completed normally — the expected case
    elif grep -q "ARBITER REFUSED" "$LOG"; then
        echo "    NOTE: cloud lane $i was REFUSED at admission (real avail was tight this run) — not a death, which is the invariant that matters (INV-1):"
        sed -n 's/^/    | /p' "$LOG" | tail -3
    else
        echo "    FAIL: cloud lane $i neither completed nor was cleanly refused (see $LOG)"; C1_OK=0
    fi
done
if grep -q "^\[runner\] KILL:" "$LOCAL_LOG"; then
    echo "    FAIL: the local-model lane was KILLED — no lane may die for host pressure"; C1_OK=0
elif grep -q "T821ARB local-model lane done" "$LOCAL_LOG"; then
    : # admitted and completed
elif grep -q "ARBITER REFUSED" "$LOCAL_LOG"; then
    echo "    NOTE: the local-model lane was REFUSED at admission (real avail — ${REAL_AVAIL_MB} MB — could not cover the 18432 MB registry figure this run) — not a death:"
    sed -n 's/^/    | /p' "$LOCAL_LOG" | tail -3
else
    echo "    FAIL: the local-model lane neither completed nor was cleanly refused (see $LOCAL_LOG)"; C1_OK=0
fi
[ "$C1_OK" -eq 1 ] && echo "    PASS: no lane died; admission ran on the real, uninjected host reading" || FAIL=1
echo ""

echo "=========================================================================="
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-arbiter: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-arbiter: FAILURES ==="
    exit 1
fi
