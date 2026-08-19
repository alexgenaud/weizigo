#!/usr/bin/env bash
# regression-watch-fleet.sh
# T466 controls for the fleet surface (untracked/watch-fleet.sh) and its
# opt-in self-heal. Every arm runs against a scratch git repo + scratch
# kanban store in /tmp/weizigo — never the live tasks.json (T445), and
# never the live assertion ledger.
#
# Arms:
#   A. dur()/etime_secs()/cpu_secs() obey the operator rule (2026-08-19):
#      a DURATION never contains a colon — 4h28 | 19'48 | 48s | 12.34.
#   B. surface truth: one row per claimed task; a task with a live process
#      shows its pid, a task with none renders `-` (does not vanish, does
#      not lie); no colon-duration in the table.
#   C. heal fires: claimed + no process + claim older than 15 min is
#      reopened (WATCH_FLEET_HEAL=1) with an assertion recording why.
#   D. heal does NOT fire wrongly: live process, fresh claim, and a
#      non-in_progress row are all left alone, with no assertion written.
#
# Usage:  tools/regression-watch-fleet.sh [--build]

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
MG="$PROJECT/bin/managent"
FAIL=0

if [ "${1:-}" = "--build" ]; then
    echo "  rebuilding managent (guarded, ReleaseSafe) and deploying..."
    (cd "$PROJECT" && "$PROJECT/tools/runner" --no-prepend-zig -- zig build -Doptimize=ReleaseSafe 2>&1)
    "$PROJECT/tools/deploy.sh" "$PROJECT/zig-out/bin/managent" "$MG"
fi

# T445: scratch must exist and be created — an empty scratch var once sent a
# suite's arms into the LIVE repo (2026-08-18 incident).
mkdir -p /tmp/weizigo || { echo "regression-watch-fleet.sh: FATAL — cannot mkdir /tmp/weizigo" >&2; exit 2; }
WORK="$(mktemp -d /tmp/weizigo/watch-fleet-XXXXXX)" || { echo "regression-watch-fleet.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
DUMMY_PID=""
cleanup() {
    [ -n "$DUMMY_PID" ] && kill "$DUMMY_PID" 2>/dev/null
    rm -rf "$WORK"
}
trap cleanup EXIT

cd "$WORK"
git init -q
git config user.email t466@test
git config user.name T466
mkdir -p docs/infra/managent docs/infra/assertion-ledger untracked bin
ln -s "$MG" bin/managent
STORE="$WORK/docs/infra/managent/tasks.json"
LEDGER="$WORK/docs/infra/assertion-ledger/assertions.jsonl"
export MANAGENT_STORE="$STORE"

# The script under test is the COMMITTED contract (HEAD), not the live
# working-tree file: the live file is co-owned (T469 landed the four-section
# layout; the operator's console has since been iterating on it). Pinning to
# HEAD keeps the controls deterministic; re-pin when the script settles.
SCRIPT="$WORK/untracked/watch-fleet.sh"
git -C "$PROJECT" show HEAD:untracked/watch-fleet.sh > "$SCRIPT" || {
    echo "regression-watch-fleet.sh: FATAL — HEAD has no untracked/watch-fleet.sh; the pinned contract is gone" >&2
    exit 1
}
if ! grep -q "WATCH_FLEET_ONCE" "$SCRIPT"; then
    echo "regression-watch-fleet.sh: FATAL — committed script lacks the test hooks (WATCH_FLEET_ONCE); contract changed" >&2
    exit 1
fi

# claimed timestamps relative to now (macOS date; fixed fallback)
OLD=$(date -u -v-2H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null) || OLD="2026-08-19T09:00:00Z"
FRESH=$(date -u -v-5M +%Y-%m-%dT%H:%M:%SZ 2>/dev/null) || FRESH="2026-08-19T11:25:00Z"

seed() {  # $1 = JSON body of task records (no trailing comma)
    printf '{\n  %s,\n  "_sys": {"next_id": 9900, "directive_next": 1, "assertion_next": 1}\n}\n' "$1" > "$STORE"
}
rec_inprog() {  # $1=id $2=agent $3=claimed
    printf '"%s":{"status":"in_progress","agent":"%s","model":"%s","bundle":"untracked/%s-bundle.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"%s","done":null,"dispatched":null,"dispatched_to":null,"note":null,"verdict":null,"verdict_note":null,"acceptance":null,"skip_acceptance_reason":null,"claim_count":1}' "$1" "$2" "$2" "$1" "$3"
}
rec_done() {  # $1=id
    printf '"%s":{"status":"done","agent":"%s","model":"%s","bundle":"untracked/%s-bundle.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"%s","done":"2026-08-19T10:00:00Z","dispatched":null,"dispatched_to":null,"note":null,"verdict":"pass","verdict_note":null,"acceptance":null,"skip_acceptance_reason":null,"claim_count":1}' "$1" "$2" "$2" "$1" "$OLD"
}
bundle() {  # $1=id $2=title
    printf '# T%s — %s\n\nBody.\n' "${1#T}" "$2" > "untracked/$1-bundle.md"
}
spawn_dummy() {  # $1 = argv marker (e.g. "Follow untracked/T902-")
    bash -c "exec -a '$1-bundle.md' sleep 30" &
    DUMMY_PID=$!
}

echo "=== T466 watch-fleet regression ==="

# ── Arm A: duration formatting (operator rule) ──────────────────────────
echo "  A. durations never contain a colon (4h28 | 19'48 | 48s | 12.34)"
WATCH_FLEET_SOURCE=1 . "$SCRIPT"
a_fail=0
check() {  # $1=expected  $2=actual  $3=label
    if [ "$1" != "$2" ]; then echo "    FAIL $3: expected '$1' got '$2'"; a_fail=1; fi
}
check "0.46" "$(dur 0.46)" "dur(0.46)"
check "12.35" "$(dur 12.345)" "dur(12.345)"
check "48s"   "$(dur 48)"     "dur(48)"
check "59.90" "$(dur 59.9)"   "dur(59.9)"
check "6'26"  "$(dur 386)"    "dur(386)"
check "59'59" "$(dur 3599)"   "dur(3599)"
check "4h28"  "$(dur 16080)"  "dur(16080)"
check "25h02" "$(dur 90120)"  "dur(90120)"
check "35"    "$(etime_secs 00:35)"    "etime_secs 00:35"
check "3723"  "$(etime_secs 01:02:03)" "etime_secs 01:02:03"
check "90061" "$(etime_secs 1-01:01:01)" "etime_secs 1-01:01:01"
check "386.84" "$(cpu_secs 6:26.84)"   "cpu_secs 6:26.84"
check "3723"  "$(cpu_secs 1:02:03)"    "cpu_secs 1:02:03"
if [ "$a_fail" = "1" ]; then FAIL=1; else echo "    PASS"; fi

# ── Arm B: surface truth — PROGRESS rows, CONCERNS dashes, no colons ───
echo "  B. PROGRESS shows live rows with pid; CONCERNS shows processless rows; no colon in durations"
bundle T901 "surface row with live process"
bundle T902 "surface row with no process"
seed "$(rec_inprog T901 glm-5.2 "$OLD"),$(rec_inprog T902 kimi-k2.7 "$OLD")"
spawn_dummy "Follow untracked/T901"
FRAME=$(WATCH_FLEET_ONCE=1 sh "$SCRIPT" 2>/dev/null)
PROG=$(printf '%s\n' "$FRAME" | sed -n '/^PROGRESS/,/^CONCERNS/p')
CONC=$(printf '%s\n' "$FRAME" | sed -n '/^CONCERNS/,/^DONE/p')
b_fail=0
if ! printf '%s\n' "$PROG" | grep -Eq "T901 +- +[0-9]+s? +[0-9.]+s? +$DUMMY_PID +glm"; then
    echo "    FAIL: PROGRESS should show T901 with the live pid $DUMMY_PID:"; printf '%s\n' "$PROG"; b_fail=1
fi
if ! printf '%s\n' "$CONC" | grep -Eq "T902 +claimed, no process"; then
    echo "    FAIL: CONCERNS should list T902 as claimed with no process:"; printf '%s\n' "$CONC"; b_fail=1
fi
if printf '%s\n' "$PROG" | grep -q ':'; then
    echo "    FAIL: PROGRESS table contains a colon-duration:"; printf '%s\n' "$PROG" | grep ':'; b_fail=1
fi
if ! printf '%s\n' "$FRAME" | grep -q "surface row with live process"; then
    echo "    FAIL: TASK elaboration missing bundle short name"; b_fail=1
fi
if [ "$b_fail" = "1" ]; then FAIL=1; else echo "    PASS"; fi
kill "$DUMMY_PID" 2>/dev/null; DUMMY_PID=""

# The heal asserts to the assertion ledger via `managent assert`, whose
# ledger path derives from the CWD repo root, NOT MANAGENT_STORE (defect
# recorded in findings/T466: scratch isolation is store-only). Arms C/D
# therefore run the scratch copy of the script (its `cd $(dirname $0)/..`
# lands in $WORK) so the assertion goes to the scratch ledger — never the
# live one.
SCRATCH_SCRIPT="$SCRIPT"

# ── Arm C: heal fires (positive control) ────────────────────────────────
echo "  C. claimed + no process + old claim -> reopened with assertion (WATCH_FLEET_HEAL=1)"
bundle T903 "heal me"
seed "$(rec_inprog T903 minimax-m3 "$OLD")"
: > "$LEDGER"
FRAME=$(WATCH_FLEET_ONCE=1 WATCH_FLEET_HEAL=1 sh "$SCRATCH_SCRIPT" 2>/dev/null)
STATUS_JSON=$("$MG" status --json 2>/dev/null)
c_fail=0
if ! printf '%s\n' "$STATUS_JSON" | grep -q '"id":"T903","status":"dispatchable"'; then
    echo "    FAIL: T903 should be dispatchable after heal: $(printf '%s\n' "$STATUS_JSON" | grep T903)"; c_fail=1
fi
if ! grep -q "watch-fleet auto-reopen" "$LEDGER"; then
    echo "    FAIL: no assertion recording the auto-reopen in the scratch ledger"; c_fail=1
fi
if ! printf '%s\n' "$FRAME" | grep -q "HEAL: T903"; then
    echo "    FAIL: frame should report the heal action"; c_fail=1
fi
if [ "$c_fail" = "1" ]; then FAIL=1; else echo "    PASS"; fi

# ── Arm D: heal does not fire wrongly (negative controls) ───────────────
echo "  D. heal leaves alone: live process / fresh claim / done row"
bundle T904 "do not heal — live process"
bundle T905 "do not heal — fresh claim"
bundle T906 "do not heal — done row"
seed "$(rec_inprog T904 glm-5.2 "$OLD"),$(rec_inprog T905 kimi-k2.7 "$FRESH"),$(rec_done T906 deepseek-v4-pro)"
: > "$LEDGER"
spawn_dummy "Follow untracked/T904"
WATCH_FLEET_ONCE=1 WATCH_FLEET_HEAL=1 sh "$SCRATCH_SCRIPT" >/dev/null 2>&1
STATUS_JSON=$("$MG" status --json 2>/dev/null)
d_fail=0
for id in T904 T905 T906; do
    if printf '%s\n' "$STATUS_JSON" | grep -q "\"id\":\"$id\",\"status\":\"dispatchable\""; then
        echo "    FAIL: $id should NOT have been reopened"; d_fail=1
    fi
done
if [ -s "$LEDGER" ]; then
    echo "    FAIL: no assertion should have been written (ledger non-empty)"; d_fail=1
fi
if [ "$d_fail" = "1" ]; then FAIL=1; else echo "    PASS"; fi

if [ "$FAIL" = "1" ]; then
    echo "=== T466 watch-fleet regression: FAIL ==="
    exit 1
fi
echo "=== T466 watch-fleet regression: PASS ==="
exit 0
