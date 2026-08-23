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
cp "$PROJECT/docs/infra/model-registry.md" "$WORK2/docs/infra/model-registry.md" 2>/dev/null
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
cp "$PROJECT/docs/infra/model-registry.md" "$WORK3/docs/infra/model-registry.md" 2>/dev/null
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

# ── Arm H: T591 — times column + 24h RECENT + model aliases (LIVE file) ─
# The LIVE file must render an HH:MM times column at the same column as
# PROGRESS's elapsed column on CONCERNS (first seen), RECENT (trailer
# mtime) and DONE (store `done`, local) rows; age RECENT to a 24 h window;
# and map the --dsflash/--dspro subagent startup aliases to a model (a
# lane's argv during startup has no --model, so the model column renders
# empty until the runner spawns). First-seen state is scrubbed via
# FLEET_CONC_STATE so the assertion is deterministic and the live fleet's
# /tmp state is never touched. Red against the pre-T591 live file, green
# after.
echo "  H. times column HH:MM aligned with PROGRESS elapsed; RECENT 24h; --dsflash/--dspro model (live file)"
WORK4=$(mktemp -d /private/tmp/weizigo/wf-times-XXXXXX)
mkdir -p "$WORK4/bin" "$WORK4/untracked" "$WORK4/docs/infra/managent" \
         "$WORK4/untracked/bakeoff/fake/fresh-lane" "$WORK4/untracked/bakeoff/fake/old-lane"
ln -s "$MG" "$WORK4/bin/managent"
cp "$PROJECT/docs/infra/model-registry.md" "$WORK4/docs/infra/model-registry.md" 2>/dev/null
# managent's findRepoRoot walks up from ITS cwd and hard-exits without a .git;
# arms F/G never touch the store so they never hit this — arm H needs the store.
git -C "$WORK4" init -q
git -C "$WORK4" config user.email t591@test
git -C "$WORK4" config user.name T591
STORE4="$WORK4/docs/infra/managent/tasks.json"
CONCSTATE4="$WORK4/concerns.tsv"
LIVE_COPY4="$WORK4/untracked/watch-fleet-live.sh"
cp "$LIVE" "$LIVE_COPY4" 2>/dev/null
# briefs: line 2 drives desc(); the Landmark line drives lm()
printf '<!--managent -->\n# T960 — alias model worker\n\n**Landmark:** L1 (the dashboard tells the truth)\n' > "$WORK4/untracked/T960-bundle.md"
printf '<!--managent -->\n# T961 — concern time test\n\nBody.\n' > "$WORK4/untracked/T961-bundle.md"
printf '<!--managent -->\n# T962 — done time test\n\nBody.\n' > "$WORK4/untracked/T962-bundle.md"
rec4() {  # $1=id $2=status $3=done (null | quoted ISO)
    printf '"%s":{"status":"%s","agent":"x","model":"x","bundle":"untracked/%s-bundle.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"2026-08-22T00:00:00Z","done":%s,"dispatched":null,"dispatched_to":null,"note":null,"verdict":"pass","verdict_note":null,"acceptance":null,"skip_acceptance_reason":null,"claim_count":1}' "$1" "$2" "$1" "$3"
}
seed4() { printf '{\n  %s,\n  "_sys": {"next_id": 9900, "directive_next": 1, "assertion_next": 1}\n}\n' "$1" > "$STORE4"; }
seed4 "$(rec4 T960 in_progress null),$(rec4 T961 in_progress null),$(rec4 T962 done '"2026-01-02T03:04:05Z"')"
# one killed lane with a fresh trailer (RECENT must show it, with its mtime),
# one with a trailer older than 24 h (RECENT must age it out)
printf '' > "$WORK4/untracked/bakeoff/fake/fresh-lane/out.md"
printf 'exit 120\n' > "$WORK4/untracked/bakeoff/fake/fresh-lane/trailer.log"
printf '' > "$WORK4/untracked/bakeoff/fake/old-lane/out.md"
printf 'exit 120\n' > "$WORK4/untracked/bakeoff/fake/old-lane/trailer.log"
OLD2D=$(date -v-2d +%Y%m%d%H%M 2>/dev/null) || OLD2D="202608190000"
touch -t "$OLD2D" "$WORK4/untracked/bakeoff/fake/old-lane/trailer.log"
# first-seen for T961 pinned to local midnight 2026-01-01 -> the CONCERNS
# row must show 00:00, not "now" (proves persistence, not per-frame freshness)
EPOCH_0000=$(date -j -f "%Y-%m-%d %H:%M:%S" "2026-01-01 00:00:00" +%s 2>/dev/null)
[ -z "$EPOCH_0000" ] && EPOCH_0000=$(python3 -c "import time;print(int(time.mktime(time.strptime('2026-01-01 00:00:00','%Y-%m-%d %H:%M:%S'))))")
printf 'T961\t%s\n' "$EPOCH_0000" > "$CONCSTATE4"
# alias-model worker: subagent startup argv (--dsflash, no --model)
bash -c "cd '$WORK4' && exec -a 'bin/subagent --provider deepseek --dsflash T960 Follow untracked/T960-bundle.md' sleep 90" &
P960=$!
sleep 0.5   # arms F/G race: a frame drawn within ms of spawn misses the worker
# env -u WATCH_FLEET_SOURCE: arms A/E source the fleet file under
# WATCH_FLEET_SOURCE=1, and macOS sh (bash POSIX mode) EXPORTS assignments
# to the special builtin `.`, so the leaked export would make the live
# copy exit at its source-guard with an empty frame. Scrub it here.
FRAME_H=$(env -u WATCH_FLEET_SOURCE FLEET_CONC_STATE="$CONCSTATE4" MANAGENT_STORE="$STORE4" FLEET_COLS=200 sh "$LIVE_COPY4" </dev/null 2>/dev/null)
kill "$P960" 2>/dev/null; wait "$P960" 2>/dev/null
h_fail=0
PROG_H=$(printf '%s\n' "$FRAME_H" | sed -n '/^PROGRESS/,/^CONCERNS/p')
CONC_H=$(printf '%s\n' "$FRAME_H" | sed -n '/^CONCERNS/,/^RECENT/p')
REC_H=$(printf '%s\n' "$FRAME_H" | sed -n '/^RECENT/,/^DONE/p')
DONE_H=$(printf '%s\n' "$FRAME_H" | sed -n '/^DONE/,/^OPEN/p')
prow=$(printf '%s\n' "$PROG_H" | grep '^  T960 ' | head -1)
crow=$(printf '%s\n' "$CONC_H" | grep '^  T961 ' | head -1)
rrow=$(printf '%s\n' "$REC_H" | grep 'fresh-lane' | head -1)
drow=$(printf '%s\n' "$DONE_H" | grep '^  T962 ' | head -1)
# every PROGRESS row must have a model (col 13-20 non-blank)
while IFS= read -r pr; do
    case "$pr" in
        '  T'*) mc=$(printf '%s' "$pr" | cut -c13-20 | tr -d ' ')
               [ -z "$mc" ] && { echo "    FAIL: empty model column in PROGRESS row: '$pr'"; h_fail=1; };;
    esac
done <<EOF
$PROG_H
EOF
# the alias worker (--dsflash, no --model) must render model `dsflash` (T739 ruling 1)
if [ -z "$prow" ]; then
    echo "    FAIL: T960 (--dsflash alias worker) missing from PROGRESS"; h_fail=1
elif [ "$(printf '%s' "$prow" | cut -c13-20 | tr -d ' ')" != "dsflash" ]; then
    echo "    FAIL: T960 model column should be 'dsflash', row: '$prow'"; h_fail=1
fi
# each of the four row types carries a time at PROGRESS's elapsed column (23-28)
DHM=$(python3 -c "import calendar,time;print(time.strftime('%H:%M',time.localtime(calendar.timegm(time.strptime('2026-01-02T03:04:05','%Y-%m-%dT%H:%M:%S')))))")
RTM=$(date -r "$WORK4/untracked/bakeoff/fake/fresh-lane/trailer.log" +%H:%M)
for probe in "$prow" "$crow" "$rrow" "$drow"; do
    [ -n "$probe" ] || { echo "    FAIL: a times row is missing (prow/crow/rrow/drow)"; h_fail=1; continue; }
    col=$(printf '%s' "$probe" | cut -c23-28 | tr -d ' ')
    [ -n "$col" ] || { echo "    FAIL: no time at col 23-28 in '$probe'"; h_fail=1; }
done
if [ "$(printf '%s' "$crow" | cut -c23-28)" != "00:00 " ]; then
    echo "    FAIL: CONCERNS first-seen should be the pinned 00:00, row: '$crow'"; h_fail=1
fi
printf '%s' "$crow" | grep -q 'orphaned' || { echo "    FAIL: CONCERNS label missing: '$crow'"; h_fail=1; }
if [ "$(printf '%s' "$drow" | cut -c23-28)" != "$DHM " ]; then
    echo "    FAIL: DONE completed time should be local $DHM of 03:04Z, row: '$drow'"; h_fail=1
fi
if [ "$(printf '%s' "$rrow" | cut -c23-28)" != "$RTM " ]; then
    echo "    FAIL: RECENT time should be trailer mtime $RTM, row: '$rrow'"; h_fail=1
fi
if printf '%s\n' "$REC_H" | grep -q 'old-lane'; then
    echo "    FAIL: old-lane (trailer > 24 h) should be aged out of RECENT"; h_fail=1
fi
if [ "$h_fail" = "1" ]; then FAIL=1; else echo "    PASS"; fi
rm -rf "$WORK4"

# ── Arm I: T738 — banner dropped, zero-row sections print nothing (LIVE file) ─
# Operator ruling 2026-08-23 (interim until watch-fleet becomes a managent
# subcommand): remove the "=== weizigo ..." banner and print NOTHING for a
# section with zero rows — no heading, no "(none)". Red against the pre-T738
# live file (banner + "(none)" markers + all five headings always rendered);
# green after. Two frames: one with a single PROGRESS row (the other four
# sections empty -> their headings must not appear), one with an empty store
# (-> the whole frame is empty once the `clear` escape is stripped).
echo "  I. banner dropped; zero-row sections print nothing (live file)"
WORKI=$(mktemp -d /private/tmp/weizigo/wf-trim-XXXXXX)
mkdir -p "$WORKI/bin" "$WORKI/untracked" "$WORKI/docs/infra/managent"
ln -s "$MG" "$WORKI/bin/managent"
cp "$PROJECT/docs/infra/model-registry.md" "$WORKI/docs/infra/model-registry.md" 2>/dev/null
git -C "$WORKI" init -q
git -C "$WORKI" config user.email t738@test
git -C "$WORKI" config user.name T738
STOREI="$WORKI/docs/infra/managent/tasks.json"
LIVE_COPYI="$WORKI/untracked/watch-fleet-live.sh"
cp "$LIVE" "$LIVE_COPYI" 2>/dev/null
printf '<!--managent -->\n# T970 — single surface row\n\n**Landmark:** L1 (the dashboard tells the truth)\n' > "$WORKI/untracked/T970-bundle.md"
printf '{\n  "T970":{"status":"in_progress","agent":"x","model":"x","bundle":"untracked/T970-bundle.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"2026-08-22T00:00:00Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"verdict":null,"verdict_note":null,"acceptance":null,"skip_acceptance_reason":null,"claim_count":1},\n  "_sys":{"next_id":9900,"directive_next":1,"assertion_next":1}\n}\n' > "$STOREI"
bash -c "cd '$WORKI' && exec -a 'pi --provider ollama --model glm-5.2 Follow untracked/T970-bundle.md' sleep 90" &
PI970=$!
sleep 0.5   # arms F/G race: a frame drawn within ms of spawn misses the worker
# env -u WATCH_FLEET_SOURCE: arms A/E source the fleet file under
# WATCH_FLEET_SOURCE=1 and macOS sh exports the assignment, so the live copy
# would exit at its source-guard with an empty frame. Scrub it (as arm H does).
FRAME_I=$(env -u WATCH_FLEET_SOURCE MANAGENT_STORE="$STOREI" FLEET_COLS=200 sh "$LIVE_COPYI" </dev/null 2>/dev/null)
kill "$PI970" 2>/dev/null; wait "$PI970" 2>/dev/null
i_fail=0
# `clear` is skipped when stdout is not a tty (T738), so the frame should be
# escape-free already; strip defensively in case a future change reintroduces
# them (bash $'...' so BSD sed never sees the \x1b escape).
STRIP_I=$(printf '%s' "$FRAME_I" | sed $'s/\x1b\[[0-9;]*[A-Za-z]//g')
if printf '%s' "$STRIP_I" | grep -q '=== weizigo'; then
    echo "    FAIL: banner '=== weizigo' still rendered"; i_fail=1
fi
if printf '%s' "$STRIP_I" | grep -q '(none)'; then
    echo "    FAIL: '(none)' marker still rendered"; i_fail=1
fi
# a heading must sit at column 0: a literal '\\n' anywhere means a separator
# was printed as two chars instead of a newline (the %s-vs-%b sep bug, T738)
if printf '%s' "$STRIP_I" | grep -q '\\n'; then
    echo "    FAIL: literal '\\n' sequence rendered (sep bug):"; printf '%s' "$STRIP_I" | grep -n '\\n' | head -3; i_fail=1
fi
for sec in CONCERNS RECENT DONE OPEN; do
    if printf '%s' "$STRIP_I" | grep -Eq "^$sec$"; then
        echo "    FAIL: empty section '$sec' still prints a heading"; i_fail=1
    fi
done
printf '%s' "$STRIP_I" | grep -q '^PROGRESS$' || { echo "    FAIL: PROGRESS heading missing from a non-empty frame"; i_fail=1; }
printf '%s' "$STRIP_I" | grep -q '^  T970 ' || { echo "    FAIL: T970 row missing from PROGRESS:"; printf '%s\n' "$STRIP_I"; i_fail=1; }
# empty store -> the entire frame must be empty (no heading, no '(none)' stub)
printf '{"_sys":{"next_id":9900,"directive_next":1,"assertion_next":1}}\n' > "$STOREI"
FRAME_I2=$(env -u WATCH_FLEET_SOURCE MANAGENT_STORE="$STOREI" FLEET_COLS=200 sh "$LIVE_COPYI" </dev/null 2>/dev/null)
STRIP_I2=$(printf '%s' "$FRAME_I2" | sed $'s/\x1b\[[0-9;]*[A-Za-z]//g' | tr -d ' \t\n')
if [ -n "$STRIP_I2" ]; then
    echo "    FAIL: all-empty dashboard should print nothing, got: '$(printf '%s' "$STRIP_I2" | head -c 120)'"; i_fail=1
fi
if [ "$i_fail" = "1" ]; then FAIL=1; else echo "    PASS"; fi
rm -rf "$WORKI"

# ── Arm J: T739 ruling 1 — short model names only, via the registry ─────
# Operator ruling 2026-08-23: every human surface renders SHORT names only —
# opus, sonnet, haiku, fable, dspro, dsflash, glm, minimax, kimi, qwen,
# oxalpha. The mapping lives in ONE table (docs/infra/model-registry.md);
# watch-fleet must render through it, holding no second mapping. A worker's
# argv can carry the canonical label (--model deepseek-v4-flash), a serving
# tag (--model glm-5.2:cloud / stealth/ox-alpha) or a startup alias
# (--dsflash); every form renders its short name, and the model column never
# shows a hyphen/colon/slash form. Red against the pre-T739 live file, which
# rendered `flash` (not dsflash), leaked `stealth/ox-alpha` raw, and carried
# its own hardcoded case.
echo "  J. short model names only, via the registry table (live file)"
WORKJ=$(mktemp -d /private/tmp/weizigo/wf-short-XXXXXX)
mkdir -p "$WORKJ/bin" "$WORKJ/untracked" "$WORKJ/docs/infra/managent"
ln -s "$MG" "$WORKJ/bin/managent"
LIVE_COPYJ="$WORKJ/untracked/watch-fleet-live.sh"
cp "$LIVE" "$LIVE_COPYJ" 2>/dev/null
cp "$PROJECT/docs/infra/model-registry.md" "$WORKJ/docs/infra/model-registry.md" 2>/dev/null
STOREJ="$WORKJ/docs/infra/managent/tasks.json"
printf '{"_sys":{"next_id":9900,"directive_next":1,"assertion_next":1}}\n' > "$STOREJ"
# one brief per worker so desc() resolves; each argv carries a different model form
for pair in "T980:canonical-flash" "T981:serving-glm" "T982:alias-flash" "T983:stealth-ox" "T984:canonical-sonnet"; do
    id=${pair%%:*}; slug=${pair##*:}
    printf '<!--managent -->\n# %s — %s\n\nBody.\n' "$id" "$slug" > "$WORKJ/untracked/$id-$slug.md"
done
bash -c "cd '$WORKJ' && exec -a 'pi --provider deepseek --model deepseek-v4-flash Follow untracked/T980-canonical-flash.md' sleep 90" & PJ1=$!
bash -c "cd '$WORKJ' && exec -a 'pi --provider ollama --model glm-5.2:cloud Follow untracked/T981-serving-glm.md' sleep 90" & PJ2=$!
bash -c "cd '$WORKJ' && exec -a 'bin/subagent --provider deepseek --dsflash T982 Follow untracked/T982-alias-flash.md' sleep 90" & PJ3=$!
bash -c "cd '$WORKJ' && exec -a 'pi --provider openrouter --model stealth/ox-alpha Follow untracked/T983-stealth-ox.md' sleep 90" & PJ4=$!
bash -c "cd '$WORKJ' && exec -a 'pi --provider claude --model claude-sonnet-5 Follow untracked/T984-canonical-sonnet.md' sleep 90" & PJ5=$!
sleep 0.5   # arms F/G race: a frame drawn within ms of spawn misses the worker
FRAME_J=$(env -u WATCH_FLEET_SOURCE MANAGENT_STORE="$STOREJ" FLEET_COLS=200 sh "$LIVE_COPYJ" </dev/null 2>/dev/null)
# no second mapping: retag glm in the REGISTRY COPY and capture a second frame
# WHILE THE WORKERS ARE STILL ALIVE (a later frame would miss them); the frame
# must follow the table, not a hardcoded case in watch-fleet.
python3 - "$WORKJ/docs/infra/model-registry.md" <<'PYJ'
import sys
p=sys.argv[1]
s=open(p).read()
assert '| `glm` |' in s
open(p,'w').write(s.replace('| `glm` |','| `GLM` |'))
PYJ
FRAME_J2=$(env -u WATCH_FLEET_SOURCE MANAGENT_STORE="$STOREJ" FLEET_COLS=200 sh "$LIVE_COPYJ" </dev/null 2>/dev/null)
kill "$PJ1" "$PJ2" "$PJ3" "$PJ4" "$PJ5" 2>/dev/null; wait "$PJ1" "$PJ2" "$PJ3" "$PJ4" "$PJ5" 2>/dev/null
j_fail=0
jm() {  # $1 = task id -> model column (cols 13-20) of its PROGRESS row
    printf '%s' "$(printf '%s\n' "$FRAME_J" | grep "^  $1 " | head -1)" | cut -c13-20 | tr -d ' '
}
jm2() {  # same, for the retagged frame
    printf '%s' "$(printf '%s\n' "$FRAME_J2" | grep "^  $1 " | head -1)" | cut -c13-20 | tr -d ' '
}
[ "$(jm T980)" = "dsflash" ]  || { echo "    FAIL: T980 canonical deepseek-v4-flash -> '$(jm T980)' want dsflash"; j_fail=1; }
[ "$(jm T981)" = "glm" ]      || { echo "    FAIL: T981 serving glm-5.2:cloud -> '$(jm T981)' want glm"; j_fail=1; }
[ "$(jm T982)" = "dsflash" ]  || { echo "    FAIL: T982 alias --dsflash -> '$(jm T982)' want dsflash"; j_fail=1; }
[ "$(jm T983)" = "oxalpha" ]  || { echo "    FAIL: T983 serving stealth/ox-alpha -> '$(jm T983)' want oxalpha"; j_fail=1; }
[ "$(jm T984)" = "sonnet" ]   || { echo "    FAIL: T984 canonical claude-sonnet-5 -> '$(jm T984)' want sonnet"; j_fail=1; }
# every PROGRESS model column is short-name shaped: no hyphen, colon or slash
while IFS= read -r pr; do
    case "$pr" in
        '  T98'*) mc=$(printf '%s' "$pr" | cut -c13-20 | tr -d ' ')
               case "$mc" in *[-:/]*)
                   echo "    FAIL: model column shows a canonical/serving form '$mc' in '$pr'"; j_fail=1;; esac;;
    esac
done <<EOF
$(printf '%s\n' "$FRAME_J" | sed -n '/^PROGRESS/,/^CONCERNS/p')
EOF
[ "$(jm2 T981)" = "GLM" ] || { echo "    FAIL: registry retag glm->GLM not rendered ('$(jm2 T981)') — watch-fleet keeps a second mapping"; j_fail=1; }
if [ "$j_fail" = "1" ]; then FAIL=1; else echo "    PASS"; fi
rm -rf "$WORKJ"

# ── Arm K: T739 ruling 2 — recovered vertical space becomes visible rows ─
# Operator ruling 2026-08-23: T738 removed the banner and the empty sections
# but the layout reserve kept the pre-T738 budget (2k+6), so a data-rich frame
# left blank lines while DONE/OPEN still had rows to show. Red against the
# pre-T739 live file: a 40-row terminal with 20 DONE + 20 OPEN rows shows
# 15+15=30 data rows (35-line frame); green after: 16+16=32 rows (37-line
# frame). NB one-shot frames exit before the footer (all arms parse them), so
# the interactive frame would add the 2-line footer: 39 <= 40 with the spare.
echo "  K. data-rich frame fills the screen — 32 rows shown, frame 37 (live file)"
WORKK=$(mktemp -d /private/tmp/weizigo/wf-fill-XXXXXX)
mkdir -p "$WORKK/bin" "$WORKK/untracked" "$WORKK/docs/infra/managent"
ln -s "$MG" "$WORKK/bin/managent"
git -C "$WORKK" init -q
git -C "$WORKK" config user.email t739@test
git -C "$WORKK" config user.name T739
STOREK="$WORKK/docs/infra/managent/tasks.json"
LIVE_COPYK="$WORKK/untracked/watch-fleet-live.sh"
cp "$LIVE" "$LIVE_COPYK" 2>/dev/null
# 20 DONE (T901..T920, done timestamps) + 20 dispatchable (T921..T940) rows
python3 - "$STOREK" "$WORKK" <<'PYK'
import json,sys
store,wk=sys.argv[1],sys.argv[2]
d={"_sys":{"next_id":9900,"directive_next":1,"assertion_next":1}}
def rec(i,status,done):
    t="T9%02d"%i
    open("%s/untracked/%s-row%02d.md"%(wk,t,i),"w").write("# %s — row %02d\n\nBody.\n"%(t,i))
    d[t]={"status":status,"agent":"x","model":"x","bundle":"untracked/%s-bundle.md"%t,"set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"2026-08-22T00:00:00Z","done":done,"dispatched":None,"dispatched_to":None,"note":None,"verdict":"pass","verdict_note":None,"acceptance":None,"skip_acceptance_reason":None,"claim_count":1}
for i in range(1,21):  rec(i,"done","2026-08-19T09:%02d:00Z"%i)        # T901..T920 DONE
for i in range(21,41): rec(i,"dispatchable",None)                      # T921..T940 OPEN
json.dump(d,open(store,"w"))
PYK
FRAME_K=$(env -u WATCH_FLEET_SOURCE MANAGENT_STORE="$STOREK" FLEET_LINES=40 FLEET_COLS=200 sh "$LIVE_COPYK" </dev/null 2>/dev/null)
k_fail=0
K_DONE=$(printf '%s\n' "$FRAME_K" | sed -n '/^DONE/,/^OPEN/p' | grep -c '^  T9')
K_OPEN=$(printf '%s\n' "$FRAME_K" | sed -n '/^OPEN/,$p' | grep -c '^  T9')
K_LINES=$(printf '%s\n' "$FRAME_K" | wc -l | tr -d ' ')
[ "$K_DONE" = "16" ] && [ "$K_OPEN" = "16" ] || {
    echo "    FAIL: want 16 DONE + 16 OPEN rows shown (recovered space = rows), got ${K_DONE}+${K_OPEN}"; k_fail=1; }
[ "$K_LINES" = "37" ] || {
    echo "    FAIL: data-rich one-shot frame should be 37 lines (interactive +footer = 39 <= 40), got $K_LINES"; k_fail=1; }
[ "$K_LINES" -le "40" ] || { echo "    FAIL: frame $K_LINES lines overflows the 40-row terminal"; k_fail=1; }
if [ "$k_fail" = "1" ]; then FAIL=1; else echo "    PASS"; fi
rm -rf "$WORKK"

if [ "$FAIL" = "1" ]; then
    echo "=== T466 watch-fleet regression: FAIL ==="
    exit 1
fi
echo "=== T466 watch-fleet regression: PASS ==="
exit 0
