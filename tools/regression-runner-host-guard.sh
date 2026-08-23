#!/usr/bin/env bash
# regression-runner-host-guard.sh — controls for the declared-tenant host guard (T714, test-first).
#
# T626/T700 kill chain: the runner's host guard reads system-wide available
# memory and, below a danger floor derived from hw.memsize//8, SIGKILLs the
# largest member of its OWN process group.  The MLX/Ollama model server is a
# named, expected tenant OUTSIDE every group, so its ~15–20 GB makes the host
# read red while the kill lands on an innocent lane and frees ~454 MB against
# a 25 GB tenant (T715 records the incident).  The fix (T711) teaches the
# guard to recognize a DECLARED TENANT and subtract its reservation from the
# pressure calc, so "available" means available-to-the-fleet.
#
# This script is the CONTROLS, written BEFORE the fix (test-first):
#
#   null control      injected qwen-resident pressure WITH a declared-tenant
#                     reservation present — five concurrent guarded lanes must
#                     COMPLETE (the guard must not fire on a tenant we
#                     invited).  RED against HEAD (no tenant subtraction —
#                     the guard fires on the injected low reading and kills
#                     every lane); GREEN after T711.
#   seeded-defect     a true runaway allocation inside a lane's own process
#                     group still DIES with killed_by=rss (the per-group RSS
#                     cap still enforces the 2026-07-29 panic floor).  GREEN
#                     against HEAD and must stay green.
#
# CONTRACT this test-first script FIXES for T711 (spec of record until T711's
# own spec amends it):
#   * WEIZIGO_HOST_TENANT_RESERVATION_MB — declared-tenant reservation in MB.
#     When set, the runner adds it to the WEIZIGO_HOST_MEM_AVAIL_MB reading
#     (available-to-the-fleet = available + reservation) before comparing
#     against the danger floor; the host guard fires only when
#     available-to-the-fleet < floor.  Unset ⇒ production behaviour,
#     byte-identical to today.  (Parallel to the existing
#     WEIZIGO_HOST_MEM_AVAIL_MB injection hook — the floor is never tested
#     by exhausting the host.)
#
# Fixtures never exhaust the host: the red host reading is injected via
# WEIZIGO_HOST_MEM_AVAIL_MB and the tenant reservation via
# WEIZIGO_HOST_TENANT_RESERVATION_MB.  The floor is pinned explicitly with
# --host-mem-floor-mb so the arms are host-independent.
#
# Scratch under /tmp/weizigo — the live kanban, live untracked/ and the live
# repo are never touched (T512/F3: the closing check scans the LIVE
# heartbeat.jsonl for fixture markers).  MANAGENT_TASK_ID (env, not
# --task-id) names the fixture runs so no auto-claim touches any kanban.
#
# Task: T714 · Role: worker · Model: deepseek-v4-pro · Date: 2026-08-23

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
RUNNER="$PROJECT/tools/runner"
FAIL=0

# Host-independent floor/reading constants (see header contract).
FLOOR_MB=4096          # explicit --host-mem-floor-mb (host-independent)
AVAIL_MB=100           # injected qwen-resident pressure (red reading)
TENANT_MB=8000         # declared-tenant reservation covering the shortfall
RSS_CAP_MB=50          # seeded-defect: a 200 MB allocation must exceed this

mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/t714-host-guard-XXXXXX)" \
    || { echo "regression-runner-host-guard.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
REPO="$WORK/repo"
mkdir -p "$REPO/untracked" "$REPO/docs/infra/managent"
( cd "$REPO" && git init -q && printf 'untracked/\n' > .gitignore && git add -A && git commit -qm base )

# ── live-telemetry baseline + closing isolation (T512, audit F3) ────────
LIVE_HB="$PROJECT/untracked/heartbeat.jsonl"
LIVE_HB_BASE=$(wc -l < "$LIVE_HB" 2>/dev/null || echo 0)

check_isolation() {
    ISO_FAIL=0
    APPENDED=$(tail -n +$((LIVE_HB_BASE + 1)) "$LIVE_HB" 2>/dev/null)
    if [ -z "$APPENDED" ]; then
        echo "    PASS: live heartbeat.jsonl — no lines appended during the run"
    elif echo "$APPENDED" | grep -q "T714HG"; then
        echo "    FAIL: fixture heartbeat line(s) appended to the LIVE heartbeat.jsonl (F3 regression)"
        echo "$APPENDED" | grep -n "T714HG" | sed 's/^/    | /'
        ISO_FAIL=1
    else
        echo "    PASS: live heartbeat.jsonl — appended lines carry no fixture data"
    fi
    [ "$ISO_FAIL" -eq 0 ] || exit 1
}

cleanup() {
    # Kill any straggler whose argv carries the scratch path (a refused or
    # mid-flight lane), then drop the scratch tree and check isolation.
    if [ -n "${WORK:-}" ]; then
        pkill -CONT -f "$WORK" 2>/dev/null
        pkill -9 -f "$WORK" 2>/dev/null
    fi
    rm -rf "$WORK"
    check_isolation
}
trap cleanup EXIT

# ── null control: five concurrent guarded lanes must COMPLETE ─────────────
# Injected qwen-resident pressure (avail 100 MB < floor 4096 MB) WITH a
# declared-tenant reservation (8000 MB) present: available-to-the-fleet is
# 8100 MB > floor, so the guard must NOT fire — these lanes were invited and
# the resident tenant is accounted for.  Each lane is a real runner-wrapped
# guarded process (host guard ON, no --no-host-guard); it must exit 0 and
# print its completion marker.  RED against HEAD: the runner ignores
# WEIZIGO_HOST_TENANT_RESERVATION_MB, so avail 100 MB < floor fires the
# guard on every lane.
echo "=== regression-runner-host-guard: null — five guarded lanes complete (declared tenant) ==="
NULL_PIDS=""
for i in 1 2 3 4 5; do
    LANE_LOG="$WORK/null-lane$i.log"
    (
        cd "$REPO"
        WEIZIGO_HOST_MEM_AVAIL_MB="$AVAIL_MB" \
        WEIZIGO_HOST_TENANT_RESERVATION_MB="$TENANT_MB" \
        MANAGENT_TASK_ID="T714L$i" \
        "$RUNNER" --no-prepend-zig --host-mem-floor-mb "$FLOOR_MB" --max-wall 30 -- \
            python3 -c "import time; time.sleep(1); print('T714HG lane $i done')" \
            >"$LANE_LOG" 2>&1
        echo $? > "$WORK/null-lane$i.rc"
    ) &
    NULL_PIDS="$NULL_PIDS $!"
done
for p in $NULL_PIDS; do
    wait "$p" 2>/dev/null
done

NULL_OK=1
for i in 1 2 3 4 5; do
    RC=$(cat "$WORK/null-lane$i.rc" 2>/dev/null || echo "missing")
    if [ "$RC" != "0" ]; then
        echo "    FAIL: lane $i exited $RC (expected 0 — COMPLETE)"
        NULL_OK=0
    fi
    if ! grep -q "T714HG lane $i done" "$WORK/null-lane$i.log"; then
        echo "    FAIL: lane $i log missing the completion marker"
        NULL_OK=0
    fi
    if grep -q "host memory pressure" "$WORK/null-lane$i.log"; then
        echo "    FAIL: lane $i — host guard fired (it must NOT on a declared tenant)"
        NULL_OK=0
    fi
done
if [ "$NULL_OK" -eq 1 ]; then
    echo "    PASS: all five guarded lanes completed; the guard did not fire on the declared tenant"
else
    echo "    FAIL (RED expected today): the guard fires on injected qwen-resident pressure — HEAD has no tenant subtraction (T711)"
    FAIL=1
fi

# ── seeded-defect control: a true runaway still dies with killed_by=rss ────
# The 2026-07-29 panic floor stays in force: a genuine runaway inside a
# lane's own process group is still caught by the per-group RSS cap (not the
# host guard, which is disabled here) and the run record stamps the
# enumerated killed_by=rss.  GREEN against HEAD and must stay green.
echo ""
echo "=== regression-runner-host-guard: seeded-defect — runaway dies with killed_by=rss ==="
SEED_LOG="$WORK/seed.log"
( cd "$REPO" && MANAGENT_TASK_ID=T714SEED "$RUNNER" --no-prepend-zig --no-host-guard \
    --rss-cap-mb "$RSS_CAP_MB" --max-wall 60 -- \
    python3 -c "x = bytearray(200 * 1024 * 1024); import time; time.sleep(5)" \
    >"$SEED_LOG" 2>&1 )
SEED_EXIT=$?

SEED_OK=1
if [ "$SEED_EXIT" -ne 124 ]; then
    echo "    FAIL: expected exit 124 (RSS cap), got $SEED_EXIT"
    SEED_OK=0
fi
if ! grep -q "RSS cap $RSS_CAP_MB MB exceeded" "$SEED_LOG"; then
    echo "    FAIL: no 'RSS cap $RSS_CAP_MB MB exceeded' kill message"
    SEED_OK=0
fi
SEED_REC="$REPO/untracked/runs/T714SEED.json"
if [ -f "$SEED_REC" ]; then
    KB=$(python3 -c "import json; print(json.load(open('$SEED_REC')).get('killed_by'))" 2>/dev/null)
    if [ "$KB" = "rss" ]; then
        echo "    PASS: run record killed_by=rss (per-group RSS cap enforces the panic floor)"
    else
        echo "    FAIL: run record killed_by=$KB (expected rss)"
        SEED_OK=0
    fi
else
    echo "    FAIL: run record $SEED_REC missing"
    SEED_OK=0
fi
[ "$SEED_OK" -eq 1 ] || FAIL=1

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-runner-host-guard: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-runner-host-guard: FAILURES (null-control red is the expected state until T711 lands) ==="
    exit 1
fi
