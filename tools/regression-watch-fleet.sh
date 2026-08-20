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

# The script under test for arms A–D is the FROZEN T469 contract, not the
# live working-tree file and not HEAD: T492 (ba5df89, 2026-08-19) committed
# the operator's live iteration of watch-fleet.sh, which dropped the
# WATCH_FLEET_ONCE / WATCH_FLEET_SOURCE / etime_secs / cpu_secs test hooks
# and the opt-in heal that arms A–D exercise. Pinning to the T469 contract
# commit (333b855) keeps those controls deterministic against the contract
# they were written for; arm E (T492) sources the LIVE file for the new
# schedule helpers. Re-pinned from HEAD to 333b855 because the change made
# the HEAD pin impossible (HEAD no longer carries the T469 hooks).
SCRIPT="$WORK/untracked/watch-fleet.sh"
git -C "$PROJECT" show 333b855:untracked/watch-fleet.sh > "$SCRIPT" || {
    echo "regression-watch-fleet.sh: FATAL — 333b855 has no untracked/watch-fleet.sh; the pinned T469 contract is gone" >&2
    exit 1
}
if ! grep -q "WATCH_FLEET_ONCE" "$SCRIPT"; then
    echo "regression-watch-fleet.sh: FATAL — pinned script lacks the test hooks (WATCH_FLEET_ONCE); T469 contract changed" >&2
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

# ── Arm E: schedule escalation + keypress reset (T492, LIVE file) ───────
# Unlike arms A–D (which pin the COMMITTED contract via `git show HEAD`),
# this arm sources the LIVE working-tree file untracked/watch-fleet.sh and
# exercises the schedule helpers extracted by T492. The live file defines
# nap_for_age(age) -> 10|60|3600 and reset_schedule() (which reassigns START
# to now); a non-quit keypress calls reset_schedule so the escalation
# restarts at 10s. Red-first: the arms below fail until the live file
# exposes those helpers under the WATCH_FLEET_SOURCE=1 guard.
echo "  E. nap_for_age escalates 10/60/3600; keypress resets the schedule (live file)"
LIVE="$PROJECT/untracked/watch-fleet.sh"
e_fail=0
if [ ! -f "$LIVE" ]; then
    echo "    FAIL: live file not found at $LIVE"; e_fail=1
else
    WATCH_FLEET_SOURCE=1 . "$LIVE" 2>/dev/null
    echeck() {  # $1=expected  $2=actual  $3=label
        if [ "$1" != "$2" ]; then echo "    FAIL $3: expected '$1' got '$2'"; e_fail=1; fi
    }
    echeck 10    "$(nap_for_age 30 2>/dev/null)"   "nap_for_age 30"
    echeck 60    "$(nap_for_age 120 2>/dev/null)"  "nap_for_age 120"
    echeck 3600  "$(nap_for_age 4000 2>/dev/null)" "nap_for_age 4000"
    # red-first: a keypress must reset the schedule so escalation restarts.
    # Plant a stale START (age ~ hours), reset, and confirm START moved AND
    # the post-reset nap is 10s again — the defect was a keypress leaving the
    # hourly nap in place after the first hour.
    START=1000000
    before=$START
    reset_schedule 2>/dev/null || { echo "    FAIL reset_schedule: undefined (live file not patched)"; e_fail=1; }
    if [ -n "$before" ] && [ "$before" = "$START" ]; then
        echo "    FAIL reset_schedule: START unchanged ($before == $START) — keypress would not restart escalation"; e_fail=1
    fi
    age=$(( $(date +%s) - START ))
    echeck 10 "$(nap_for_age "$age" 2>/dev/null)" "post-reset nap_for_age"
fi
if [ "$e_fail" = "1" ]; then FAIL=1; else echo "    PASS"; fi

# ── Arm F: process-filter collision (T493 change 5, LIVE file) ────────
# The live file skips any candidate whose command contains the substring
# "watch-fleet" — meant to hide the script's own invocation, but it also
# hides a WORKER whose bundle path contains "watch-fleet" (e.g.
# T492-watch-fleet-keypress-reset.md). Red-first: a seeded worker with
# that bundle path must be SHOWN; a worker whose command contains the
# script path "watch-fleet.sh" must still be HIDDEN. The fix matches the
# script's own path (.sh) rather than the bare substring.
# NB: a PHYSICAL scratch path (under /private/tmp, not the /tmp symlink)
# is required because the live file sets REPO=$(pwd) of `dirname "$0")/..`
# and compares it to lsof's resolved cwd — a /tmp path would mismatch the
# worker's /private/tmp cwd and hide every worker, the way the real
# (non-symlinked) repo does not.
echo "  F. watch-fleet bundle-path worker shown; script invocation hidden (live file)"
WORK2=$(mktemp -d /private/tmp/weizigo/wf-live-XXXXXX)
mkdir -p "$WORK2/bin" "$WORK2/untracked" "$WORK2/docs/infra/managent"
ln -s "$MG" "$WORK2/bin/managent"
STORE2="$WORK2/docs/infra/managent/tasks.json"
printf '{"_sys":{"next_id":9900,"directive_next":1,"assertion_next":1}}\n' > "$STORE2"
LIVE_COPY="$WORK2/untracked/watch-fleet-live.sh"
cp "$LIVE" "$LIVE_COPY" 2>/dev/null
# brief whose slug contains "watch-fleet" (line 2 = the desc source); a long
# title also makes the PROGRESS row wide enough for arm G's trimming check.
printf '<!--managent -->\n# T492 — watch-fleet keypress resets the refresh schedule and a long description here\n\n**Landmark:** L1 (the dashboard tells the truth)\n' > "$WORK2/untracked/T492-watch-fleet-keypress-reset.md"
[ -n "$DUMMY_PID" ] && kill "$DUMMY_PID" 2>/dev/null
# worker whose bundle path contains "watch-fleet" (the bug) — must be SHOWN
bash -c "cd '$WORK2' && exec -a 'pi --provider ollama --model glm-5.2 Follow untracked/T492-watch-fleet-keypress-reset.md' sleep 90" &
P492=$!
# worker whose command contains the script path "watch-fleet.sh" — must stay HIDDEN
bash -c "cd '$WORK2' && exec -a 'pi --provider ollama --model glm-5.2 Follow untracked/T991-watch-fleet.sh' sleep 90" &
P991=$!
FRAME_F=$(MANAGENT_STORE="$STORE2" FLEET_COLS=200 sh "$LIVE_COPY" </dev/null 2>/dev/null)
kill "$P492" "$P991" 2>/dev/null; wait "$P492" "$P991" 2>/dev/null
f_fail=0
if ! printf '%s\n' "$FRAME_F" | grep -q '^  T492 '; then
    echo "    FAIL: T492 (bundle path with watch-fleet) should be SHOWN in PROGRESS"; f_fail=1
fi
if printf '%s\n' "$FRAME_F" | grep -q '^  T991 '; then
    echo "    FAIL: T991 (command with watch-fleet.sh) should be HIDDEN"; f_fail=1
fi
if [ "$f_fail" = "1" ]; then FAIL=1; else echo "    PASS"; fi
rm -rf "$WORK2"

# ── Arm G: terminal size re-read per frame (T493 change 4, LIVE file) ─
# Control: the live file must read COLS freshly each frame and not cache a
# hardcoded width. Two one-shot frames with FLEET_COLS=20 and =200 must trim
# the same wide PROGRESS row differently — proving COLS drives layout on
# every run. (The script re-reads stty size / FLEET_COLS at the top of each
# loop iteration; one-shot mode draws one frame, so per-invocation freshness
# is the observable proxy for per-frame freshness. Code inspection confirms
# no size variable survives across loop iterations.)
echo "  G. FLEET_COLS read per frame — wide row trims at 20, not at 200 (live file)"
WORK3=$(mktemp -d /private/tmp/weizigo/wf-size-XXXXXX)
mkdir -p "$WORK3/bin" "$WORK3/untracked" "$WORK3/docs/infra/managent"
ln -s "$MG" "$WORK3/bin/managent"
STORE3="$WORK3/docs/infra/managent/tasks.json"
printf '{"_sys":{"next_id":9900,"directive_next":1,"assertion_next":1}}\n' > "$STORE3"
LIVE_COPY3="$WORK3/untracked/watch-fleet-live.sh"
cp "$LIVE" "$LIVE_COPY3" 2>/dev/null
printf '<!--managent -->\n# T492 — watch-fleet keypress resets the refresh schedule and a long description here\n\n**Landmark:** L1 (the dashboard tells the truth)\n' > "$WORK3/untracked/T492-watch-fleet-keypress-reset.md"
bash -c "cd '$WORK3' && exec -a 'pi --provider ollama --model glm-5.2 Follow untracked/T492-watch-fleet-keypress-reset.md' sleep 90" &
P492=$!
g_fail=0
FRAME_20=$(MANAGENT_STORE="$STORE3" FLEET_COLS=20 sh "$LIVE_COPY3" </dev/null 2>/dev/null)
FRAME_200=$(MANAGENT_STORE="$STORE3" FLEET_COLS=200 sh "$LIVE_COPY3" </dev/null 2>/dev/null)
kill "$P492" 2>/dev/null; wait "$P492" 2>/dev/null
row20=$(printf '%s\n' "$FRAME_20" | grep '^  T492 ' | head -1)
row200=$(printf '%s\n' "$FRAME_200" | grep '^  T492 ' | head -1)
len20=${#row20}; len200=${#row200}
if [ -z "$row20" ] || [ -z "$row200" ]; then
    echo "    FAIL: T492 row missing (20:${row20:-<none>} 200:${row200:-<none>})"; g_fail=1
elif [ "$len20" -gt 20 ]; then
    echo "    FAIL: at COLS=20 row should be <=20 chars, got $len20: '$row20'"; g_fail=1
elif [ "$len200" -le 20 ]; then
    echo "    FAIL: at COLS=200 row should be >20 chars, got $len200: '$row200'"; g_fail=1
fi
if [ "$g_fail" = "1" ]; then FAIL=1; else echo "    PASS"; fi
rm -rf "$WORK3"

if [ "$FAIL" = "1" ]; then
    echo "=== T466 watch-fleet regression: FAIL ==="
    exit 1
fi
echo "=== T466 watch-fleet regression: PASS ==="
exit 0
