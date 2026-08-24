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
#   K. T823: data-rich frame fills the screen — 35 rows shown, frame 38.
#   N. T823: exact fill at 24/40/60 x two section mixes; no (more) line.
#   O. T823: rate column = output tokens per wall second; UNKNOWN, never 0,
#      never a reading older than the current claim.
#   P. T823: holder column comes from the store's `agent`, not the brief text.
#   L. T799/T804: footer is the terminal's last line — one blank above it,
#      nothing below (cleanup's exit newline only); cursor hidden, restored on q.
#   M. T799: cursor restored on the ^C trap path (exit 130).
#   Q. T839: the in-flight transcript drives the rate (field 5) and the
#      freshness age (field 6); no usage -> UNKNOWN + fresh, no transcript
#      -> UNKNOWN + "-".
#   R. T839: freshness_of() arithmetic — Ns/Nm/Nh/Nd, STALE across the
#      15-min-to-1h band, "-" for no mtime; 5-char slot, nothing leaks.
#   S. T839: CONCERNS never accuses — fresh transcript 'lived', exit-0 run
#      record 'finished' (the T818 shape), only the dead+unclosed 'orphaned'.
#   T. T839: the always-UNKNOWN rate is broken — 1 of 3 fixtures with a
#      transcript renders a rate; no blank rate or freshness field.
#
# Usage:  tools/regression-watch-fleet.sh [--build]

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
MG="$PROJECT/bin/managent"
# T856: the S10 store-loss census (T848) goes stale whenever a fixture writes
# a scratch tasks.json directly (bypassing managent). weizigo_reset_census
# (T855, tools/lib/scratch-repo.sh) clears the stale census after every such
# write so the store returns to the honest "no census yet" state. Without it,
# arms that re-stage a store with FEWER rows than the last managent-mediated
# write trip the detector and the next status call REFUSES with an empty frame
# — arms C and N were red for exactly this since T848 landed (this script was
# missed by T855's sweep).
source "$PROJECT/tools/lib/scratch-repo.sh"
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
    weizigo_reset_census "$STORE"   # T856/T855: direct write bypasses the census; see tools/lib/scratch-repo.sh
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
weizigo_reset_census "$STORE2"   # T856: direct write bypasses the census
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
weizigo_reset_census "$STORE3"   # T856: direct write bypasses the census
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
seed4() { printf '{\n  %s,\n  "_sys": {"next_id": 9900, "directive_next": 1, "assertion_next": 1}\n}\n' "$1" > "$STORE4"; weizigo_reset_census "$STORE4"; }   # T856: direct write bypasses the census
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
weizigo_reset_census "$STOREI"   # T856: direct write bypasses the census
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
weizigo_reset_census "$STOREI"   # T856: direct write bypasses the census
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
weizigo_reset_census "$STOREJ"   # T856: direct write bypasses the census
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

# ── Arm K: T739/T799/T804 ruling 2 — recovered vertical space becomes visible rows ─
# Operator ruling 2026-08-23: T738 removed the banner and the empty sections
# but the layout reserve kept the pre-T738 budget (2k+6), so a data-rich frame
# left blank lines while DONE/OPEN still had rows to show. T739 recovered 2
# rows (16+16=32 shown, 37-line one-shot frame). T799 removed the footer's
# trailing newline and dropped the spare: 17+17=34 rows (39-line one-shot
# frame; interactive = 40 exactly, footer on the last line). T804 restored the
# footer's leading blank (the operator's "missing blank between OPEN rows and
# footer") and fixed the (more)-reserve/print mismatch, so one line moved from
# a data row to the separator: 16+17=33 rows (38-line one-shot frame;
# interactive = 40 exactly, footer on the last line, blank above it). T823
# deletes the "(more: N)" line AND its reserve (operator: "I do not think we
# need the '(more: 187)' line, which would give us a row or two more to fill
# with task data rows"), so the two rows the reserve spent on "(more)" become
# data rows: 17+18=35 shown, the SAME 38-line one-shot frame. Red against the
# pre-T823 live file: 16+17=33 rows plus two "(more)" lines. One-shot piped
# output must also stay escape-free — the T799 hide/restore are tty-guarded so
# a pipe stays clean for the line-anchored arms above.
echo "  K. data-rich frame fills the screen — 35 rows shown, frame 38 (live file)"
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
weizigo_reset_census "$STOREK"   # T856: direct write bypasses the census
FRAME_K=$(env -u WATCH_FLEET_SOURCE MANAGENT_STORE="$STOREK" FLEET_LINES=40 FLEET_COLS=200 sh "$LIVE_COPYK" </dev/null 2>/dev/null)
k_fail=0
K_DONE=$(printf '%s\n' "$FRAME_K" | sed -n '/^DONE/,/^OPEN/p' | grep -c '^  T9')
K_OPEN=$(printf '%s\n' "$FRAME_K" | sed -n '/^OPEN/,$p' | grep -c '^  T9')
K_LINES=$(printf '%s\n' "$FRAME_K" | wc -l | tr -d ' ')
[ "$K_DONE" = "17" ] && [ "$K_OPEN" = "18" ] || {
    echo "    FAIL: want 17 DONE + 18 OPEN rows shown (T823 pin, 35 total), got ${K_DONE}+${K_OPEN}"; k_fail=1; }
printf '%s\n' "$FRAME_K" | grep -q '(more' && { echo "    FAIL: '(more' line still printed (T823 removed it)"; k_fail=1; }
[ "$K_LINES" = "38" ] || {
    echo "    FAIL: data-rich one-shot frame should be 38 lines (interactive +blank+footer = 40 exactly), got $K_LINES"; k_fail=1; }
[ "$K_LINES" -le "40" ] || { echo "    FAIL: frame $K_LINES lines overflows the 40-row terminal"; k_fail=1; }
case "$FRAME_K" in
    *'[?25l'*|*'[?25h'*) echo "    FAIL: one-shot piped frame leaks cursor escapes"; k_fail=1;;
esac
if [ "$k_fail" = "1" ]; then FAIL=1; else echo "    PASS"; fi
rm -rf "$WORKK"

# ── Arm N: T804 — exact fill + (more) accounting (LIVE file) ─────────────
# The invariant that IS the deliverable: printed lines == ROWS exactly. The
# two footer bugs (T739's +1 spare, T799's dropped blank) and the pre-T738
# banner budget were the same defect three times — a reserve constant that no
# longer matched what the frame prints. T804 restores the blank above the
# footer and reserves "(more)" rows only for sections the slot split actually
# truncates: the old reserve charged a row on nd/no > MIN_ROWS, but show()
# prints "(more)" on tot > slots — a section given enough slots to show every
# row was charged a line it never printed, and the frame came up a line short
# (the blank the operator saw at the bottom). One-shot frames omit the
# interactive-only blank-above-footer + footer, so exact fill is FLEET_LINES
# - 2 lines there (interactive = FLEET_LINES exactly). Asserted at three
# heights x two section mixes. T823 deletes the "(more: N)" line and its
# reserve together (T804 had already found the two disagreeing), so the
# accounting sub-cases invert: NO frame prints a "(more)" line at any height
# or mix, and the rows the reserve used to spend on it are data rows — a
# truncated section and an exactly-fitting section now render the same shape
# (18 DONE + 17 OPEN at height 40, either way). Red against the pre-T823 live
# file: 2 "(more)" lines at every height and mix, 17 DONE rows where 18 fit.
echo "  N. exact fill at 24/40/60 x two mixes; no (more) line (live file)"
WORKN=$(mktemp -d /private/tmp/weizigo/wf-fill-XXXXXX)
mkdir -p "$WORKN/bin" "$WORKN/untracked" "$WORKN/docs/infra/managent" \
         "$WORKN/untracked/bakeoff/fake/fresh-lane"
ln -s "$MG" "$WORKN/bin/managent"
git -C "$WORKN" init -q
git -C "$WORKN" config user.email t804@test
git -C "$WORKN" config user.name T804
cp "$PROJECT/docs/infra/model-registry.md" "$WORKN/docs/infra/model-registry.md" 2>/dev/null
STORE_N="$WORKN/docs/infra/managent/tasks.json"
CONCSTATE_N="$WORKN/concerns.tsv"
LIVE_COPY_N="$WORKN/untracked/watch-fleet-live.sh"
cp "$LIVE" "$LIVE_COPY_N" 2>/dev/null
# all-five mix: PROGRESS (1 live worker T901) + CONCERNS (T902, no process)
# + RECENT (fresh killed lane) + DONE (40) + OPEN (40)
python3 - "$STORE_N" "$WORKN" <<'PYN'
import json,sys
store,wk=sys.argv[1],sys.argv[2]
d={"_sys":{"next_id":9900,"directive_next":1,"assertion_next":1}}
def rec(i,status,done):
    t="T9%02d"%i
    open("%s/untracked/%s-row%02d.md"%(wk,t,i),"w").write("# %s — row %02d\n\nBody.\n"%(t,i))
    d[t]={"status":status,"agent":"x","model":"x","bundle":"untracked/%s-bundle.md"%t,"set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"2026-08-22T00:00:00Z","done":done,"dispatched":None,"dispatched_to":None,"note":None,"verdict":"pass","verdict_note":None,"acceptance":None,"skip_acceptance_reason":None,"claim_count":1}
rec(1,"in_progress",None)                                   # T901 PROGRESS (worker below)
rec(2,"in_progress",None)                                   # T902 CONCERNS (no process)
for i in range(3,43):  rec(i,"done","2026-08-19T09:%02d:00Z"%i)      # T903..T942 DONE
for i in range(43,83): rec(i,"dispatchable",None)                     # T943..T982 OPEN
json.dump(d,open(store,"w"))
PYN
weizigo_reset_census "$STORE_N"   # T856: direct write bypasses the census
printf '' > "$WORKN/untracked/bakeoff/fake/fresh-lane/out.md"
printf 'exit 120\n' > "$WORKN/untracked/bakeoff/fake/fresh-lane/trailer.log"
printf 'T902\t%s\n' "$(date +%s)" > "$CONCSTATE_N"
bash -c "cd '$WORKN' && exec -a 'pi --provider ollama --model glm-5.2 Follow untracked/T901-row01.md' sleep 120" &
PN1=$!
sleep 0.5   # arms F/G race: a frame drawn within ms of spawn misses the worker
n_fail=0
frame_n() {  # $1 = FLEET_LINES
    env -u WATCH_FLEET_SOURCE MANAGENT_STORE="$STORE_N" FLEET_CONC_STATE="$CONCSTATE_N" \
        FLEET_LINES="$1" FLEET_COLS=200 sh "$LIVE_COPY_N" </dev/null 2>/dev/null
}
for H in 24 40 60; do
    FR=$(frame_n "$H")
    NL=$(printf '%s\n' "$FR" | wc -l | tr -d ' ')
    NM=$(printf '%s\n' "$FR" | grep -c 'more:')
    [ "$NL" = "$((H - 2))" ] || { echo "    FAIL: all-five mix at height $H: want $((H-2)) lines (exact fill minus the interactive-only blank+footer), got $NL"; n_fail=1; }
    [ "$NM" = "0" ] || { echo "    FAIL: all-five mix at height $H: the (more) line is gone (T823), want 0, got $NM"; n_fail=1; }
done
kill "$PN1" 2>/dev/null; wait "$PN1" 2>/dev/null
rm -rf "$WORKN/untracked/bakeoff"
# DONE+OPEN-only mix: worker killed, bakeoff gone, store rewritten with no
# in_progress rows -> no PROGRESS/CONCERNS/RECENT sections
python3 - "$STORE_N" "$WORKN" <<'PYN'
import json,sys
store,wk=sys.argv[1],sys.argv[2]
d={"_sys":{"next_id":9900,"directive_next":1,"assertion_next":1}}
def rec(i,status,done):
    t="T9%02d"%i
    open("%s/untracked/%s-row%02d.md"%(wk,t,i),"w").write("# %s — row %02d\n\nBody.\n"%(t,i))
    d[t]={"status":status,"agent":"x","model":"x","bundle":"untracked/%s-bundle.md"%t,"set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"2026-08-22T00:00:00Z","done":done,"dispatched":None,"dispatched_to":None,"note":None,"verdict":"pass","verdict_note":None,"acceptance":None,"skip_acceptance_reason":None,"claim_count":1}
for i in range(3,43):  rec(i,"done","2026-08-19T09:%02d:00Z"%i)      # T903..T942 DONE
for i in range(43,83): rec(i,"dispatchable",None)                     # T943..T982 OPEN
json.dump(d,open(store,"w"))
PYN
weizigo_reset_census "$STORE_N"   # T856: direct write bypasses the census
for H in 24 40 60; do
    FR=$(frame_n "$H")
    NL=$(printf '%s\n' "$FR" | wc -l | tr -d ' ')
    NM=$(printf '%s\n' "$FR" | grep -c 'more:')
    [ "$NL" = "$((H - 2))" ] || { echo "    FAIL: DONE+OPEN mix at height $H: want $((H-2)) lines (exact fill minus blank+footer), got $NL"; n_fail=1; }
    [ "$NM" = "0" ] || { echo "    FAIL: DONE+OPEN mix at height $H: the (more) line is gone (T823), want 0, got $NM"; n_fail=1; }
done
# The row given back to data (T823), at height 40: a section with more rows
# than slots and a section with exactly enough slots render the SAME shape —
# 18 DONE + 17 OPEN, no "(more)" line in either. Pre-T823 the truncated case
# spent one of those 18 lines on "(more: 23)" and showed 17 rows.
python3 - "$STORE_N" "$WORKN" <<'PYN'
import json,sys
store,wk=sys.argv[1],sys.argv[2]
d={"_sys":{"next_id":9900,"directive_next":1,"assertion_next":1}}
def rec(i,status,done):
    t="T9%02d"%i
    open("%s/untracked/%s-row%02d.md"%(wk,t,i),"w").write("# %s — row %02d\n\nBody.\n"%(t,i))
    d[t]={"status":status,"agent":"x","model":"x","bundle":"untracked/%s-bundle.md"%t,"set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"2026-08-22T00:00:00Z","done":done,"dispatched":None,"dispatched_to":None,"note":None,"verdict":"pass","verdict_note":None,"acceptance":None,"skip_acceptance_reason":None,"claim_count":1}
for i in range(3,43):  rec(i,"done","2026-08-19T09:%02d:00Z"%i)      # 40 DONE (truncated)
for i in range(43,60): rec(i,"dispatchable",None)                     # 17 OPEN (all shown)
json.dump(d,open(store,"w"))
PYN
weizigo_reset_census "$STORE_N"   # T856: direct write bypasses the census
FR=$(frame_n 40)
NL=$(printf '%s\n' "$FR" | wc -l | tr -d ' ')
NM=$(printf '%s\n' "$FR" | grep -c 'more')
ND=$(printf '%s\n' "$FR" | sed -n '/^DONE/,/^OPEN/p' | grep -c '^  T9')
NO=$(printf '%s\n' "$FR" | sed -n '/^OPEN/,$p' | grep -c '^  T9')
[ "$NL" = "38" ] || { echo "    FAIL: 40 DONE + 17 OPEN at height 40: want 38 lines, got $NL"; n_fail=1; }
[ "$NM" = "0" ] || { echo "    FAIL: 40 DONE + 17 OPEN: no '(more' text anywhere (T823), got $NM line(s)"; n_fail=1; }
[ "$ND" = "18" ] && [ "$NO" = "17" ] || { echo "    FAIL: 40 DONE + 17 OPEN: the freed (more) row must become a DONE data row — want 18+17, got ${ND}+${NO}"; n_fail=1; }
python3 - "$STORE_N" "$WORKN" <<'PYN'
import json,sys
store,wk=sys.argv[1],sys.argv[2]
d={"_sys":{"next_id":9900,"directive_next":1,"assertion_next":1}}
def rec(i,status,done):
    t="T9%02d"%i
    open("%s/untracked/%s-row%02d.md"%(wk,t,i),"w").write("# %s — row %02d\n\nBody.\n"%(t,i))
    d[t]={"status":status,"agent":"x","model":"x","bundle":"untracked/%s-bundle.md"%t,"set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"2026-08-22T00:00:00Z","done":done,"dispatched":None,"dispatched_to":None,"note":None,"verdict":"pass","verdict_note":None,"acceptance":None,"skip_acceptance_reason":None,"claim_count":1}
for i in range(3,21):  rec(i,"done","2026-08-19T09:%02d:00Z"%i)      # 18 DONE (all shown)
for i in range(43,60): rec(i,"dispatchable",None)                     # 17 OPEN (all shown)
json.dump(d,open(store,"w"))
PYN
weizigo_reset_census "$STORE_N"   # T856: direct write bypasses the census
FR=$(frame_n 40)
NL=$(printf '%s\n' "$FR" | wc -l | tr -d ' ')
NM=$(printf '%s\n' "$FR" | grep -c 'more')
ND=$(printf '%s\n' "$FR" | sed -n '/^DONE/,/^OPEN/p' | grep -c '^  T9')
NO=$(printf '%s\n' "$FR" | sed -n '/^OPEN/,$p' | grep -c '^  T9')
[ "$NL" = "38" ] || { echo "    FAIL: 18 DONE + 17 OPEN at height 40: want 38 lines, got $NL"; n_fail=1; }
[ "$NM" = "0" ] || { echo "    FAIL: 18 DONE + 17 OPEN: no '(more' text anywhere, got $NM line(s)"; n_fail=1; }
[ "$ND" = "18" ] && [ "$NO" = "17" ] || { echo "    FAIL: 18 DONE + 17 OPEN: want 18+17 rows shown, got ${ND}+${NO}"; n_fail=1; }
if [ "$n_fail" = "1" ]; then FAIL=1; else echo "    PASS"; fi
rm -rf "$WORKN"

# ── Arm O: T823 — rate column (output tokens per wall second) ───────────
# The fifth PROGRESS column was `ps -o time= | awk -F: '{print $NF}'`, which
# keeps only the LAST colon-separated field of cumulative CPU time: a real
# 1:20.93 rendered as 20.93, so 80.9 s displayed as 20.9 and two rows were not
# comparable at all. And a correct CPU number would still be the wrong metric —
# these are API-driven workers whose measured CPU utilisation is 6.9% (T817),
# 9.7% (T801), 8.1% (T808): local CPU tracks how a model chose to search, not
# how much work it did. T823 replaces it with output tokens per wall second,
# the rate we actually have (untracked/tokens/tokens.jsonl `tokens_out`, over
# `ps` elapsed). Two halves:
#   unit  — rate_of(tokens_out, elapsed) is exposed under the WATCH_FLEET_SOURCE
#           guard (as nap_for_age is) so the arithmetic is pinned exactly, on
#           the three live readings the operator measured.
#   frame — a task WITH a reading renders a labelled rate; a task whose meter
#           wrote no usage renders UNKNOWN (never 0); a task whose only reading
#           predates its current claim renders UNKNOWN (never a stale value —
#           that reading belongs to a previous run of the same id).
# Red against the pre-T823 live file: rate_of undefined, and the column shows
# a bare CPU number with no label and no UNKNOWN.
echo "  O. rate column = output tokens/wall second; UNKNOWN never 0, never stale (live file)"
o_fail=0
if [ ! -f "$LIVE" ]; then
    echo "    FAIL: live file not found at $LIVE"; o_fail=1
else
    WATCH_FLEET_SOURCE=1 . "$LIVE" 2>/dev/null
    ocheck() {  # $1=expected  $2=actual  $3=label
        if [ "$1" != "$2" ]; then echo "    FAIL $3: expected '$1' got '$2'"; o_fail=1; fi
    }
    if ! command -v rate_of >/dev/null 2>&1; then
        echo "    FAIL rate_of: undefined (live file not patched)"; o_fail=1
    else
        # the three readings measured 2026-08-23 (tokens_out / claimed->done seconds)
        ocheck "103.6/s" "$(rate_of 127683 1232)" "rate_of dsflash T817 127683/1232"
        ocheck "72.8/s"  "$(rate_of 157457 2162)" "rate_of dspro   T801 157457/2162"
        ocheck "119.7/s" "$(rate_of 407129 3400)" "rate_of dsflash T808 407129/3400"
        # missing reading -> UNKNOWN, and specifically NOT 0
        ocheck "UNKNOWN" "$(rate_of '' 100)"      "rate_of '' 100 (no reading)"
        ocheck "UNKNOWN" "$(rate_of 12000 0)"     "rate_of 12000 0 (no elapsed yet)"
        ocheck "UNKNOWN" "$(rate_of 12000 '')"    "rate_of 12000 '' (no elapsed)"
        case "$(rate_of '' 100)" in *0*) echo "    FAIL rate_of: a missing reading must never render a 0"; o_fail=1;; esac
        # a number is never truncated to fit the 8-char column (the defect this
        # column replaced was exactly a silently-dropped digit group): one
        # decimal below 1000/s, none at or above, so any plausible rate fits.
        ocheck "999.0/s" "$(rate_of 999 1)"       "rate_of 999 1 (below 1000: one decimal)"
        ocheck "1000/s"  "$(rate_of 1000 1)"      "rate_of 1000 1 (at 1000: no decimal)"
        ocheck "12000/s" "$(rate_of 12000 1)"     "rate_of 12000 1 (outlier still fits 8)"
        for probe in "$(rate_of 999 1)" "$(rate_of 1000 1)" "$(rate_of 12000 1)" "$(rate_of 127683 1232)" UNKNOWN; do
            [ "${#probe}" -le 8 ] || { echo "    FAIL rate_of: '$probe' is ${#probe} chars, overflows the 8-char column"; o_fail=1; }
        done
    fi
fi
WORKO=$(mktemp -d /private/tmp/weizigo/wf-rate-XXXXXX)
mkdir -p "$WORKO/bin" "$WORKO/untracked/tokens" "$WORKO/docs/infra/managent"
ln -s "$MG" "$WORKO/bin/managent"
cp "$PROJECT/docs/infra/model-registry.md" "$WORKO/docs/infra/model-registry.md" 2>/dev/null
git -C "$WORKO" init -q
git -C "$WORKO" config user.email t823@test
git -C "$WORKO" config user.name T823
STORE_O="$WORKO/docs/infra/managent/tasks.json"
LIVE_COPY_O="$WORKO/untracked/watch-fleet-live.sh"
cp "$LIVE" "$LIVE_COPY_O" 2>/dev/null
recO() {  # $1=id $2=claimed
    printf '"%s":{"status":"in_progress","agent":"deepseek-v4-flash","model":"deepseek-v4-flash","bundle":"untracked/%s-bundle.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"%s","done":null,"dispatched":null,"dispatched_to":null,"note":null,"verdict":null,"verdict_note":null,"acceptance":null,"skip_acceptance_reason":null,"claim_count":1}' "$1" "$1" "$2"
}
for id in T950 T951 T952; do
    printf '<!--managent -->\n# %s — rate fixture\n\n**Landmark:** L1 (the dashboard tells the truth)\n' "$id" > "$WORKO/untracked/$id-bundle.md"
done
printf '{\n  %s,\n  %s,\n  %s,\n  "_sys":{"next_id":9900,"directive_next":1,"assertion_next":1}\n}\n' \
    "$(recO T950 2026-08-23T10:00:00Z)" "$(recO T951 2026-08-23T10:00:00Z)" "$(recO T952 2026-08-23T10:00:00Z)" > "$STORE_O"
weizigo_reset_census "$STORE_O"   # T856: direct write bypasses the census
# T950: a reading inside the current claim -> a rate.
# T951: the meter wrote but carried no usage (tokens_out null) -> UNKNOWN.
# T952: the only reading predates the claim (previous run of the same id) -> UNKNOWN.
cat > "$WORKO/untracked/tokens/tokens.jsonl" <<'JSONL'
{"task":"T950","tokens_out":300,"tokens_in":50,"ts":"2026-08-23T10:20:00Z","model":"deepseek-v4-flash","rc":0}
{"task":"T951","tokens_out":null,"tokens_in":null,"ts":"2026-08-23T10:20:00Z","missing_reason":"no structured usage in process output (pi/ollama lane)","rc":0}
{"task":"T952","tokens_out":99999,"tokens_in":50,"ts":"2026-08-22T09:00:00Z","model":"deepseek-v4-flash","rc":0}
JSONL
for id in T950 T951 T952; do
    bash -c "cd '$WORKO' && exec -a 'pi --provider deepseek --model deepseek-v4-flash Follow untracked/$id-bundle.md' sleep 90" &
    eval "PO_$id=\$!"
done
sleep 2   # arms F/G race: a frame drawn within ms of spawn misses the worker, and the rate needs a non-zero ps etime (T856: sleep 0.5 raced it — a frame drawn inside the worker's first second rendered UNKNOWN, flaking arm O red)
FRAME_O=$(env -u WATCH_FLEET_SOURCE MANAGENT_STORE="$STORE_O" FLEET_COLS=200 sh "$LIVE_COPY_O" </dev/null 2>/dev/null)
kill $PO_T950 $PO_T951 $PO_T952 2>/dev/null; wait $PO_T950 $PO_T951 $PO_T952 2>/dev/null
orate() {  # $1 = task id -> the rate field of its PROGRESS row
    # by FIELD, not by column slice: a slice would hide an overflowing value,
    # which is the class of defect this column replaced. Alignment (the rate
    # starts at column 30) is asserted separately below.
    printf '%s\n' "$FRAME_O" | awk -v t="  $1 " 'index($0,t)==1 {print $5; exit}'
}
for id in T950 T951 T952; do
    printf '%s\n' "$FRAME_O" | grep -q "^  $id " || { echo "    FAIL: $id missing from PROGRESS"; o_fail=1; }
done
# T950 has a reading: a labelled rate (ends in /s), not blank, not UNKNOWN, not 0
case "$(orate T950)" in
    UNKNOWN|'') echo "    FAIL: T950 has a token reading — rate column should show a rate, got '$(orate T950)'"; o_fail=1;;
    *[0-9]/s)   ;;
    *)          echo "    FAIL: T950 rate column must be a labelled rate ('NNN.N/s'), got '$(orate T950)'"; o_fail=1;;
esac
[ "$(orate T951)" = "UNKNOWN" ] || { echo "    FAIL: T951 (meter wrote no usage) must render UNKNOWN, got '$(orate T951)'"; o_fail=1; }
[ "$(orate T952)" = "UNKNOWN" ] || { echo "    FAIL: T952 (reading predates the claim) must render UNKNOWN, never the stale 99999 rate, got '$(orate T952)'"; o_fail=1; }
# the stale reading must not leak anywhere in the frame
printf '%s\n' "$FRAME_O" | grep -q '99999' && { echo "    FAIL: the pre-claim reading (99999) leaked into the frame"; o_fail=1; }
# alignment: the rate starts at column 30, where the CPU column used to
for id in T950 T951 T952; do
    row=$(printf '%s\n' "$FRAME_O" | grep "^  $id " | head -1)
    [ "$(printf '%s' "$row" | cut -c29-30 | sed 's/^ //')" = "$(printf '%s' "$(orate "$id")" | cut -c1)" ] \
        || { echo "    FAIL: $id rate column does not start at col 30: '$row'"; o_fail=1; }
done
# the elapsed column (T591 alignment, cols 23-28) still holds a duration, and
# no PROGRESS row carries a colon-duration
PROG_O=$(printf '%s\n' "$FRAME_O" | sed -n '/^PROGRESS/,$p')
printf '%s' "$(printf '%s\n' "$PROG_O" | grep '^  T950 ' | head -1)" | cut -c23-28 | grep -q '[0-9]' \
    || { echo "    FAIL: elapsed column (23-28) lost its duration"; o_fail=1; }
printf '%s\n' "$PROG_O" | grep '^  T95' | grep -q ':' && { echo "    FAIL: PROGRESS row contains a colon-duration"; o_fail=1; }
if [ "$o_fail" = "1" ]; then FAIL=1; else echo "    PASS"; fi
rm -rf "$WORKO"

# ── Arm P: T823 — the holder comes from the store, not the brief ─────────
# T771 renders as "orchestration oversight seat (fable)" while its `agent`
# field says claude-opus-5: the seat was handed over and the brief was written
# for the previous holder. desc() derives its text from the brief body, which
# is stale by design — a display asserting something the store contradicts.
# T823 adds a holder column sourced from the task's `agent` field (short-named
# through the ONE registry table, T739) and keeps the brief-derived text for
# WHAT the task is. The column goes AFTER the times column so the T591
# alignment contract (every row type carries HH:MM at cols 23-28, arm H) is
# untouched. Fixtures mirror T771: a brief naming fable, a store saying
# claude-opus-5. Red against the pre-T823 live file: no holder anywhere, the
# only who-text in the row is the brief's "(fable)".
echo "  P. holder column comes from the store's agent, not the brief text (live file)"
WORKP=$(mktemp -d /private/tmp/weizigo/wf-holder-XXXXXX)
mkdir -p "$WORKP/bin" "$WORKP/untracked" "$WORKP/docs/infra/managent"
ln -s "$MG" "$WORKP/bin/managent"
cp "$PROJECT/docs/infra/model-registry.md" "$WORKP/docs/infra/model-registry.md" 2>/dev/null
git -C "$WORKP" init -q
git -C "$WORKP" config user.email t823@test
git -C "$WORKP" config user.name T823
STORE_P="$WORKP/docs/infra/managent/tasks.json"
CONCSTATE_P="$WORKP/concerns.tsv"
LIVE_COPY_P="$WORKP/untracked/watch-fleet-live.sh"
cp "$LIVE" "$LIVE_COPY_P" 2>/dev/null
# T940: the T771 shape — brief says fable, store says claude-opus-5.
# T941: no agent in the store -> the holder must not be invented.
printf '<!--managent -->\n# T940 — orchestration oversight seat (fable)\n\nBody.\n' > "$WORKP/untracked/T940-oversight-seat.md"
printf '<!--managent -->\n# T941 — holderless row\n\nBody.\n' > "$WORKP/untracked/T941-bundle.md"
recP() {  # $1=id $2=agent (JSON value: quoted label or null)
    printf '"%s":{"status":"in_progress","agent":%s,"model":%s,"bundle":"untracked/%s-bundle.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"2026-08-23T12:58:30Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"verdict":null,"verdict_note":null,"acceptance":null,"skip_acceptance_reason":null,"claim_count":1}' "$1" "$2" "$2" "$1"
}
printf '{\n  %s,\n  %s,\n  "_sys":{"next_id":9900,"directive_next":1,"assertion_next":1}\n}\n' \
    "$(recP T940 '"claude-opus-5"')" "$(recP T941 null)" > "$STORE_P"
weizigo_reset_census "$STORE_P"   # T856: direct write bypasses the census
# both rows are claimed with NO live process -> CONCERNS; pin first-seen so the
# times column is deterministic (as arm H does)
EPOCH_P=$(date -j -f "%Y-%m-%d %H:%M:%S" "2026-01-01 00:00:00" +%s 2>/dev/null)
[ -z "$EPOCH_P" ] && EPOCH_P=$(python3 -c "import time;print(int(time.mktime(time.strptime('2026-01-01 00:00:00','%Y-%m-%d %H:%M:%S'))))")
printf 'T940\t%s\nT941\t%s\n' "$EPOCH_P" "$EPOCH_P" > "$CONCSTATE_P"
FRAME_P=$(env -u WATCH_FLEET_SOURCE FLEET_CONC_STATE="$CONCSTATE_P" MANAGENT_STORE="$STORE_P" \
    FLEET_COLS=200 sh "$LIVE_COPY_P" </dev/null 2>/dev/null)
p_fail=0
CONC_P=$(printf '%s\n' "$FRAME_P" | sed -n '/^CONCERNS/,$p')
prow940=$(printf '%s\n' "$CONC_P" | grep '^  T940 ' | head -1)
prow941=$(printf '%s\n' "$CONC_P" | grep '^  T941 ' | head -1)
[ -n "$prow940" ] || { echo "    FAIL: T940 missing from CONCERNS"; p_fail=1; }
[ -n "$prow941" ] || { echo "    FAIL: T941 missing from CONCERNS"; p_fail=1; }
hold940=$(printf '%s' "$prow940" | cut -c30-37 | tr -d ' ')
hold941=$(printf '%s' "$prow941" | cut -c30-37 | tr -d ' ')
[ "$hold940" = "opus" ] || { echo "    FAIL: T940 holder must be the store's agent short-named ('opus'), got '$hold940' in: '$prow940'"; p_fail=1; }
[ "$hold941" = "-" ]    || { echo "    FAIL: T941 has no agent — holder must render '-', not an invented one, got '$hold941'"; p_fail=1; }
# the brief-derived description survives (what the task is), and the stale
# who-text is no longer the only who on the row
printf '%s' "$prow940" | grep -q 'oversight seat (fable)' \
    || { echo "    FAIL: brief-derived description lost from the T940 row: '$prow940'"; p_fail=1; }
# T591 alignment: the times column is still at 23-28 (the holder went after it)
[ "$(printf '%s' "$prow940" | cut -c23-28)" = "00:00 " ] \
    || { echo "    FAIL: times column moved — cols 23-28 of the T940 row are '$(printf '%s' "$prow940" | cut -c23-28)', want '00:00 '"; p_fail=1; }
if [ "$p_fail" = "1" ]; then FAIL=1; else echo "    PASS"; fi
rm -rf "$WORKP"

# ── Arm L: T799/T804 — footer is last line; one blank above; cursor hide/restore ──
# Operator ruling 2026-08-23: "Missing blank between OPEN rows and footer. But
# unnecessary blank after, at the bottom." T799 removed BOTH blanks; T804 puts
# the leading one back — the footer is a separator from the data, so the line
# directly above it is blank and the line above that is data. Nothing below:
# the only newline after the footer text is cleanup's exit newline (the fresh
# prompt line), and the cursor is hidden (^[[?25l) while the watcher runs and
# restored (^[[?25h) by cleanup on exit. Data-rich store: the interactive
# frame must fill FLEET_LINES=24 exactly (footer on line 24 — arm N pins the
# same invariant one-shot). Red against the pre-T804 live file: the line above
# the footer was data (no blank) and the frame came up a line short.
echo "  L. footer is last line; one blank above; cursor hidden, restored on q (live file)"
WORKL=$(mktemp -d /private/tmp/weizigo/wf-footer-XXXXXX)
mkdir -p "$WORKL/bin" "$WORKL/untracked" "$WORKL/docs/infra/managent"
ln -s "$MG" "$WORKL/bin/managent"
cp "$PROJECT/docs/infra/model-registry.md" "$WORKL/docs/infra/model-registry.md" 2>/dev/null
git -C "$WORKL" init -q
git -C "$WORKL" config user.email t804@test
git -C "$WORKL" config user.name T804
STORE="$WORKL/docs/infra/managent/tasks.json"
LIVE_COPYL="$WORKL/untracked/watch-fleet-live.sh"
cp "$LIVE" "$LIVE_COPYL" 2>/dev/null
# 30 done + 9 open rows: enough data that the 24-row interactive frame is
# data-rich (exact fill) AND the last section (OPEN) shows every row, so the
# line above the blank-above-footer is a data row, not a "(more)" line.
python3 - "$STORE" "$WORKL" <<'PYL'
import json,sys
store,wk=sys.argv[1],sys.argv[2]
d={"_sys":{"next_id":9900,"directive_next":1,"assertion_next":1}}
def rec(i,status,done):
    t="T9%02d"%i
    open("%s/untracked/%s-row%02d.md"%(wk,t,i),"w").write("# %s — row %02d\n\nBody.\n"%(t,i))
    d[t]={"status":status,"agent":"x","model":"x","bundle":"untracked/%s-bundle.md"%t,"set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"2026-08-22T00:00:00Z","done":done,"dispatched":None,"dispatched_to":None,"note":None,"verdict":"pass","verdict_note":None,"acceptance":None,"skip_acceptance_reason":None,"claim_count":1}
for i in range(1,31):  rec(i,"done","2026-08-19T09:%02d:00Z"%i)      # T901..T930 DONE
for i in range(31,40): rec(i,"dispatchable",None)                     # T931..T939 OPEN
json.dump(d,open(store,"w"))
PYL
weizigo_reset_census "$STORE"   # T856: direct write bypasses the census
OUT_L=$( (sleep 0.5; printf 'q') | script -q /dev/null env -u WATCH_FLEET_SOURCE \
    MANAGENT_STORE="$STORE" FLEET_LINES=24 FLEET_COLS=80 sh "$LIVE_COPYL" 2>/dev/null )
l_fail=0
case "$OUT_L" in
    *'[?25l'*) ;;
    *) echo "    FAIL: no cursor-hide sequence (^[[?25l) in interactive output"; l_fail=1;;
esac
case "$OUT_L" in
    *'[?25h') ;;
    *) echo "    FAIL: output must END with the cursor-restore sequence (^[[?25h)"; l_fail=1;;
esac
# no trailing blank below the footer: the only bytes between the footer text
# and the restore are cleanup's exit newline (CR-LF through the pty) — a
# second newline is the parked-cursor blank T799 removed and T804 must not
# bring back. (strip CR first; the double command-substitution upstream
# strips trailing newlines, so the raw OUT is the only place this is visible)
case "$(printf '%s' "$OUT_L" | tr -d '\r')" in
    *'10s'$'\n'$'\x1b[?25h') ;;
    *) echo "    FAIL: footer tail must be '10s' + exactly one exit newline + restore (blank below footer)"; l_fail=1;;
esac
# strip clear + private-mode-25 escapes and CR (pty ONLCR) to recover the frame
S_L=$(printf '%s' "$OUT_L" | sed $'s/\x1b\[[?0-9;]*[A-Za-z]//g' | tr -d '\r')
# the footer is the last line that matches the footer shape; the frame must
# fill FLEET_LINES exactly, so the footer sits on the terminal's last row.
F_N=$(printf '%s\n' "$S_L" | grep -n -E '^  [0-9][0-9]:[0-9][0-9]:[0-9][0-9] . q or .C quits . another key to refresh 10s$' | tail -1 | cut -d: -f1)
[ -n "$F_N" ] || { echo "    FAIL: footer line not found; frame: '$(printf '%s' "$S_L" | tr '\n' '|')'"; l_fail=1; }
[ "$F_N" = "24" ] || { echo "    FAIL: data-rich interactive frame must fill FLEET_LINES=24 exactly (footer on the last row), footer at line $F_N"; l_fail=1; }
PREV=""
[ -n "$F_N" ] && PREV=$(printf '%s\n' "$S_L" | sed -n "$((F_N - 1))p")
[ -z "$PREV" ] || { echo "    FAIL: line directly above the footer must be BLANK (the restored separator), got: '$PREV'"; l_fail=1; }
PREV2=""
[ -n "$F_N" ] && PREV2=$(printf '%s\n' "$S_L" | sed -n "$((F_N - 2))p")
printf '%s\n' "$PREV2" | grep -q '^  T9' || { echo "    FAIL: line above the blank must be a data row, got: '$PREV2'"; l_fail=1; }
if [ "$l_fail" = "1" ]; then FAIL=1; else echo "    PASS"; fi
rm -rf "$WORKL"

# ── Arm M: T799 — cursor restored on the ^C trap path (exit 130) ────────
# The ^C path is the restore that gets forgotten: the INT trap must go
# through cleanup so the cursor is restored (^[[?25h as the LAST bytes) and
# the exit code is 130. Red against the pre-T799 live file: no hide, no
# restore anywhere.
echo "  M. cursor restored on the ^C trap path; exit 130 (live file)"
WORKM=$(mktemp -d /private/tmp/weizigo/wf-int-XXXXXX)
mkdir -p "$WORKM/bin" "$WORKM/untracked" "$WORKM/docs/infra/managent"
ln -s "$MG" "$WORKM/bin/managent"
cp "$PROJECT/docs/infra/model-registry.md" "$WORKM/docs/infra/model-registry.md" 2>/dev/null
git -C "$WORKM" init -q
git -C "$WORKM" config user.email t799@test
git -C "$WORKM" config user.name T799
STORE="$WORKM/docs/infra/managent/tasks.json"
LIVE_COPYM="$WORKM/untracked/watch-fleet-live.sh"
cp "$LIVE" "$LIVE_COPYM" 2>/dev/null
printf '<!--managent -->\n# T996 — trap path row\n\nBody.\n' > "$WORKM/untracked/T996-bundle.md"
printf '{\n  "T996":{"status":"done","agent":"x","model":"x","bundle":"untracked/T996-bundle.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"2026-08-22T00:00:00Z","done":"2026-08-19T09:00:00Z","dispatched":null,"dispatched_to":null,"note":null,"verdict":"pass","verdict_note":null,"acceptance":null,"skip_acceptance_reason":null,"claim_count":1},\n  "_sys":{"next_id":9900,"directive_next":1,"assertion_next":1}\n}\n' > "$STORE"
weizigo_reset_census "$STORE"   # T856: direct write bypasses the census
# ^C after one frame: the INT trap must fire mid-watch (footer already
# rendered), restore the cursor and exit 130.
OUT_M=$( (sleep 1; printf '\003') | script -q /dev/null env -u WATCH_FLEET_SOURCE \
    MANAGENT_STORE="$STORE" FLEET_LINES=24 FLEET_COLS=80 sh "$LIVE_COPYM" 2>/dev/null )
RC_M=$?
m_fail=0
[ "$RC_M" = "130" ] || { echo "    FAIL: ^C exit should be 130, got $RC_M"; m_fail=1; }
case "$OUT_M" in
    *'[?25l'*) ;;
    *) echo "    FAIL: no cursor-hide sequence on the trap path"; m_fail=1;;
esac
case "$OUT_M" in
    *'[?25h') ;;
    *) echo "    FAIL: trap path must END with the cursor-restore sequence (^[[?25h)"; m_fail=1;;
esac
printf '%s' "$OUT_M" | grep -q 'another key to refresh' || { echo "    FAIL: no footer rendered before the ^C (trap fired too early)"; m_fail=1; }
if [ "$m_fail" = "1" ]; then FAIL=1; else echo "    PASS"; fi
rm -rf "$WORKM"


# ── Arm Q: T839 — the in-flight transcript drives the rate and the freshness ─
# tokens.jsonl is written at completion, so a running task had no reading and
# the rate column rendered UNKNOWN forever (T823's column was honest and
# useless). T839 adds the second source: the harness transcript — pi appends
# to untracked/tokens/sessions/<task>.<ts>.<pid>.<n>.jsonl continuously, and
# claude writes under $WEIZIGO_CLAUDE_TRANSCRIPT_DIR (same <task>.* naming).
# A task with a transcript renders a labelled rate (field 5) and a freshness
# age (field 6); a task whose transcript has no usage-bearing turn yet
# renders UNKNOWN (never 0 — rate_of's rule) but STILL renders the freshness,
# because the liveness IS the point: a working console must not look dead;
# a task with no transcript renders UNKNOWN and "-". Fixtures: Q1's session
# started 30 s before the process — the LIVE shape, where a worker claims
# after pi launches so the session start routinely precedes the claim (T822:
# session 06:44:25Z, claim 07:12:03Z) and staleness must be judged against
# the PROCESS start, not the claim. Red against the pre-T839 live file:
# every rate UNKNOWN and no sixth column at all.
echo "  Q. transcript -> labelled rate + freshness; no usage -> UNKNOWN + fresh; none -> UNKNOWN/- (live file)"
WORKQ=$(mktemp -d /private/tmp/weizigo/wf-tx-XXXXXX)
mkdir -p "$WORKQ/bin" "$WORKQ/untracked/tokens/sessions" "$WORKQ/docs/infra/managent"
ln -s "$MG" "$WORKQ/bin/managent"
cp "$PROJECT/docs/infra/model-registry.md" "$WORKQ/docs/infra/model-registry.md" 2>/dev/null
git -C "$WORKQ" init -q
git -C "$WORKQ" config user.email t839@test
git -C "$WORKQ" config user.name T839
STORE_Q="$WORKQ/docs/infra/managent/tasks.json"
LIVE_COPY_Q="$WORKQ/untracked/watch-fleet-live.sh"
cp "$LIVE" "$LIVE_COPY_Q" 2>/dev/null
for pair in "T970:tx-fresh" "T971:tx-no-usage" "T972:tx-none"; do
    id=${pair%%:*}; slug=${pair##*:}
    printf '<!--managent -->\n# %s — %s\n\n**Landmark:** L1 (the dashboard tells the truth)\n' "$id" "$slug" > "$WORKQ/untracked/$id-$slug.md"
done
NOW_Q=$(date +%s)
CLAIM_Q=$(date -u -r $((NOW_Q - 3600)) '+%Y-%m-%dT%H:%M:%SZ')
recQ() { printf '"%s":{"status":"in_progress","agent":"deepseek-v4-flash","model":"deepseek-v4-flash","bundle":"untracked/%s-bundle.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"%s","done":null,"dispatched":null,"dispatched_to":null,"note":null,"verdict":null,"verdict_note":null,"acceptance":null,"skip_acceptance_reason":null,"claim_count":1}' "$1" "$1" "$2"; }
printf '{\n  %s,\n  %s,\n  %s,\n  "_sys":{"next_id":9900,"directive_next":1,"assertion_next":1}\n}\n' \
    "$(recQ T970 "$CLAIM_Q")" "$(recQ T971 "$CLAIM_Q")" "$(recQ T972 "$CLAIM_Q")" > "$STORE_Q"
weizigo_reset_census "$STORE_Q"   # T856: direct write bypasses the census
# Q1: current-run transcript — session header 30 s old, one assistant turn
# with usage.output=1200 (the LIVE late-claim shape: session start precedes
# the claim, so it must be judged against the process, and 30 s < the 120 s
# slack means it is the current run).
TS_Q1=$(date -u -r $((NOW_Q - 30)) '+%Y-%m-%dT%H:%M:%S.000Z')
cat > "$WORKQ/untracked/tokens/sessions/T970.1700000000.1.0.jsonl" <<EOF
{"type":"session","version":3,"id":"q1","timestamp":"$TS_Q1","cwd":"$WORKQ"}
{"type":"message","id":"m1","parentId":"q1","timestamp":"$TS_Q1","message":{"role":"assistant","content":"ok","usage":{"input":50,"output":1200,"cacheRead":0,"cacheWrite":0,"reasoning":0,"totalTokens":1250}}}
EOF
# Q2: current-run transcript, header only (no usage-bearing turn yet)
TS_Q2=$(date -u -r $((NOW_Q - 30)) '+%Y-%m-%dT%H:%M:%S.000Z')
cat > "$WORKQ/untracked/tokens/sessions/T971.1700000000.2.0.jsonl" <<EOF
{"type":"session","version":3,"id":"q2","timestamp":"$TS_Q2","cwd":"$WORKQ"}
EOF
# Q3: no transcript at all
for id in T970 T971 T972; do
    bash -c "cd '$WORKQ' && exec -a 'pi --provider deepseek --model deepseek-v4-flash Follow untracked/$id-$slug.md' sleep 90" &
    eval "PQ_$id=\$!"
done
sleep 2   # arms F/G race: a frame drawn within ms of spawn misses the worker
FRAME_Q=$(env -u WATCH_FLEET_SOURCE MANAGENT_STORE="$STORE_Q" FLEET_COLS=200 sh "$LIVE_COPY_Q" </dev/null 2>/dev/null)
kill $PQ_T970 $PQ_T971 $PQ_T972 2>/dev/null; wait $PQ_T970 $PQ_T971 $PQ_T972 2>/dev/null
q_fail=0
qrow() { printf '%s\n' "$FRAME_Q" | awk -v t="  $1 " 'index($0,t)==1 {print; exit}'; }
qfield() { qrow "$1" | awk -v f="$2" '{print $f; exit}'; }
for id in T970 T971 T972; do
    printf '%s\n' "$FRAME_Q" | grep -q "^  $id " || { echo "    FAIL: $id missing from PROGRESS"; q_fail=1; }
done
# Q1: a fresh transcript with usage -> a labelled rate, not UNKNOWN, not 0
case "$(qfield T970 5)" in
    UNKNOWN|'') echo "    FAIL: T970 has a transcript with usage -> rate should be labelled, got '$(qfield T970 5)'"; q_fail=1;;
    *[0-9]/s) ;;
    *) echo "    FAIL: T970 rate must be 'NNN.N/s', got '$(qfield T970 5)'"; q_fail=1;;
esac
# Q1 freshness: a seconds-age marker (the file was just written)
case "$(qfield T970 6)" in
    *s) ;;
    *) echo "    FAIL: T970 freshness must be a seconds-age, got '$(qfield T970 6)'"; q_fail=1;;
esac
# Q2: transcript but no usage -> UNKNOWN rate (never 0), freshness still rendered
[ "$(qfield T971 5)" = "UNKNOWN" ] || { echo "    FAIL: T971 (no usage) -> rate UNKNOWN, got '$(qfield T971 5)'"; q_fail=1; }
case "$(qfield T971 6)" in
    *s|STALE|-) ;;
    *) echo "    FAIL: T971 freshness must still render, got '$(qfield T971 6)'"; q_fail=1;;
esac
# Q3: no transcript -> UNKNOWN rate, "-" freshness
[ "$(qfield T972 5)" = "UNKNOWN" ] || { echo "    FAIL: T972 (no transcript) -> rate UNKNOWN, got '$(qfield T972 5)'"; q_fail=1; }
[ "$(qfield T972 6)" = "-" ] || { echo "    FAIL: T972 (no transcript) -> freshness '-', got '$(qfield T972 6)'"; q_fail=1; }
# every PROGRESS row carries at least 6 fields: task landmark model elapsed rate fresh desc
for id in T970 T971 T972; do
    nf=$(qrow "$id" | awk '{print NF}')
    [ "$nf" -ge 6 ] || { echo "    FAIL: $id row has $nf fields, want >= 6"; q_fail=1; }
done
# the elapsed column (23-28) still holds a duration and no PROGRESS row has a colon-duration
PROG_Q=$(printf '%s\n' "$FRAME_Q" | sed -n '/^PROGRESS/,/^CONCERNS/p')
printf '%s' "$(printf '%s\n' "$PROG_Q" | grep '^  T970 ' | head -1)" | cut -c23-28 | grep -q '[0-9]' \
    || { echo "    FAIL: elapsed column (23-28) lost its duration"; q_fail=1; }
printf '%s\n' "$PROG_Q" | grep '^  T97' | grep -q ':' && { echo "    FAIL: a PROGRESS row carries a colon-duration"; q_fail=1; }
if [ "$q_fail" = "1" ]; then FAIL=1; else echo "    PASS"; fi
rm -rf "$WORKQ"

# ── Arm R: T839 — freshness_of() arithmetic (live file) ───────────────────
# Expose freshness_of the way rate_of is exposed (arm O mirrors this pattern
# for the rate arithmetic): mtime (epoch seconds) -> a 5-char age marker.
# Buckets: seconds under a minute, minutes up to the 15-min heal horizon
# (900 s), STALE across the 15-min-to-1h ambiguity band (901..3600), hours
# up to a day, days beyond. Pinned at every bucket boundary; the 5-char slot
# is the deliverable (STALE fills it exactly — a 4-char cap would make STALE
# overflow and push the description, the jitter this column exists to avoid).
echo "  R. freshness_of returns Ns/Nm/Nh/Nd | STALE | - (live file)"
r_fail=0
if [ ! -f "$LIVE" ]; then
    echo "    FAIL: live file not found at $LIVE"; r_fail=1
else
    WATCH_FLEET_SOURCE=1 . "$LIVE" 2>/dev/null
    if ! command -v freshness_of >/dev/null 2>&1; then
        echo "    FAIL freshness_of: undefined (live file not patched)"; r_fail=1
    else
        # T856: freshness_of re-reads the wall clock per call, so a boundary
        # pinned against a reference second captured earlier races the bucket
        # edge — a 3600 s input lands in the hour bucket once a second has
        # elapsed (observed flake: "expected 'STALE' got ' 1h'"). Pin the
        # clock instead: shadow `date` with a fixed second for this block so
        # every bucket edge is exact and deterministic. Undone before arm S.
        FAKE_NOW=$(date +%s)
        date() { if [ "${1:-}" = "+%s" ]; then printf '%s' "$FAKE_NOW"; else command date "$@"; fi; }
        export -f date
        NOW_R=$FAKE_NOW
        rcheck() {  # $1=expected  $2=actual  $3=label
            if [ "$1" != "$2" ]; then echo "    FAIL $3: expected '$1' got '$2'"; r_fail=1; fi
        }
        rcheck "-"     "$(freshness_of '')"         "freshness_of '' (no mtime)"
        rcheck "-"     "$(freshness_of 0)"          "freshness_of 0 (no mtime)"
        rcheck " 0s"   "$(freshness_of "$NOW_R")"   "freshness_of now (0s old)"
        rcheck " 1s"   "$(freshness_of $((NOW_R-1)))" "freshness_of 1s"
        rcheck "59s"   "$(freshness_of $((NOW_R-59)))" "freshness_of 59s"
        rcheck " 1m"   "$(freshness_of $((NOW_R-60)))" "freshness_of 60s (crosses into minutes)"
        rcheck "15m"   "$(freshness_of $((NOW_R-900)))" "freshness_of 900s (still minutes)"
        rcheck "STALE" "$(freshness_of $((NOW_R-901)))" "freshness_of 901s (past the 15-min horizon)"
        rcheck "STALE" "$(freshness_of $((NOW_R-3600)))" "freshness_of 3600s (1h, also STALE)"
        rcheck " 1h"   "$(freshness_of $((NOW_R-3601)))" "freshness_of 3601s (past the STALE band: age again)"
        rcheck "23h"   "$(freshness_of $((NOW_R-82800)))" "freshness_of 23h"
        rcheck " 1d"   "$(freshness_of $((NOW_R-86400)))" "freshness_of 24h (crosses into days)"
        rcheck " 7d"   "$(freshness_of $((NOW_R-604800)))" "freshness_of 7d"
        # the 5-char slot: nothing over 5 chars leaks (STALE is the widest)
        for probe in "$(freshness_of "$NOW_R")" "$(freshness_of $((NOW_R-59)))" "$(freshness_of $((NOW_R-900)))" "$(freshness_of $((NOW_R-901)))" "$(freshness_of $((NOW_R-86400)))" "$(freshness_of '')"; do
            [ "${#probe}" -le 5 ] || { echo "    FAIL freshness_of: '$probe' is ${#probe} chars, overflows the 5-char column"; r_fail=1; }
        done
        unset -f date; unset FAKE_NOW   # the pinned clock must not leak into arms S/T
    fi
fi
if [ "$r_fail" = "1" ]; then FAIL=1; else echo "    PASS"; fi

# ── Arm S: T839 — CONCERNS never accuses work that is alive or finished ──
# Operator ruling: "CONCERNS must not accuse a finished task" (T818 was
# complete — 12 of 12 chunks committed — and failed only the nonce echo;
# calling it orphaned trained the reader to ignore the section). The label
# is now one of three truthful ones: 'lived' (a transcript written within
# the last 15 min — the heal horizon — proves the console is healthy even
# when pgrep cannot see it: qwen/T824's 573 KB transcript across 25 bash
# calls while its log sat at 2,951 bytes), 'finished' (the latest run record
# shows a clean exit — the work is done, the task just was not closed),
# and 'orphaned' only for a genuinely dead, unclosed task. Fixtures: S1
# fresh transcript -> lived; S2 transcript stale past the horizon -> orphaned
# (a silent transcript IS an orphan); S3 exit-0 run record (the T818 shape)
# -> finished; S4 nothing -> orphaned. Red against the pre-T839 live file:
# every fixture 'orphaned'.
echo "  S. CONCERNS labels: lived / finished / orphaned, no false accusation (live file)"
WORKS=$(mktemp -d /private/tmp/weizigo/wf-conc-XXXXXX)
mkdir -p "$WORKS/bin" "$WORKS/untracked/tokens/sessions" "$WORKS/untracked/runs" "$WORKS/docs/infra/managent"
ln -s "$MG" "$WORKS/bin/managent"
cp "$PROJECT/docs/infra/model-registry.md" "$WORKS/docs/infra/model-registry.md" 2>/dev/null
git -C "$WORKS" init -q
git -C "$WORKS" config user.email t839@test
git -C "$WORKS" config user.name T839
STORE_S="$WORKS/docs/infra/managent/tasks.json"
CONCSTATE_S="$WORKS/concerns.tsv"
LIVE_COPY_S="$WORKS/untracked/watch-fleet-live.sh"
cp "$LIVE" "$LIVE_COPY_S" 2>/dev/null
for id in T980 T981 T982 T983; do
    printf '<!--managent -->\n# %s — concern label\n\n**Landmark:** L1 (the dashboard tells the truth)\n' "$id" > "$WORKS/untracked/$id-bundle.md"
done
recS() { printf '"%s":{"status":"in_progress","agent":"deepseek-v4-flash","model":"deepseek-v4-flash","bundle":"untracked/%s-bundle.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"2026-08-22T00:00:00Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"verdict":null,"verdict_note":null,"acceptance":null,"skip_acceptance_reason":null,"claim_count":1}' "$1" "$1"; }
printf '{\n  %s,\n  %s,\n  %s,\n  %s,\n  "_sys":{"next_id":9900,"directive_next":1,"assertion_next":1}\n}\n' \
    "$(recS T980)" "$(recS T981)" "$(recS T982)" "$(recS T983)" > "$STORE_S"
weizigo_reset_census "$STORE_S"   # T856: direct write bypasses the census
NOW_S=$(date +%s)
# S1: FRESH transcript (last write 30 s ago) -> lived
TS_S1=$(date -u -r $((NOW_S - 30)) '+%Y-%m-%dT%H:%M:%S.000Z')
cat > "$WORKS/untracked/tokens/sessions/T980.1700000000.1.0.jsonl" <<EOF
{"type":"session","version":3,"id":"s1","timestamp":"$TS_S1","cwd":"$WORKS"}
{"type":"message","id":"m1","parentId":"s1","timestamp":"$TS_S1","message":{"role":"assistant","content":"ok","usage":{"input":10,"output":50,"cacheRead":0,"cacheWrite":0,"reasoning":0,"totalTokens":60}}}
EOF
# S2: STALE transcript (last write 17 min ago, past the 15-min horizon) -> orphaned
TS_S2=$(date -u -r $((NOW_S - 1000)) '+%Y-%m-%dT%H:%M:%S.000Z')
cat > "$WORKS/untracked/tokens/sessions/T981.1700000000.2.0.jsonl" <<EOF
{"type":"session","version":3,"id":"s2","timestamp":"$TS_S2","cwd":"$WORKS"}
EOF
python3 -c "import os,time; os.utime('$WORKS/untracked/tokens/sessions/T981.1700000000.2.0.jsonl', (int(time.time())-1000,)*2)"
# S3: no transcript, run record with a clean exit (the T818 shape) -> finished
printf '{"task":"T982","attempt":1,"exit":0,"reap_ok":true,"end":"2026-08-23T22:09:20Z","wall":1509.2}\n' > "$WORKS/untracked/runs/T982.json"
# S4: no transcript, no run record -> orphaned
EPOCH_S=$(date -j -f "%Y-%m-%d %H:%M:%S" "2026-01-01 00:00:00" +%s 2>/dev/null)
[ -z "$EPOCH_S" ] && EPOCH_S=$(python3 -c "import time;print(int(time.mktime(time.strptime('2026-01-01 00:00:00','%Y-%m-%d %H:%M:%S'))))")
printf 'T980\t%s\nT981\t%s\nT982\t%s\nT983\t%s\n' "$EPOCH_S" "$EPOCH_S" "$EPOCH_S" "$EPOCH_S" > "$CONCSTATE_S"
# no live workers — all four tasks go to CONCERNS
FRAME_S=$(env -u WATCH_FLEET_SOURCE FLEET_CONC_STATE="$CONCSTATE_S" MANAGENT_STORE="$STORE_S" FLEET_COLS=200 sh "$LIVE_COPY_S" </dev/null 2>/dev/null)
s_fail=0
CONC_S=$(printf '%s\n' "$FRAME_S" | sed -n '/^CONCERNS/,$p')
crow() { printf '%s\n' "$CONC_S" | grep "^  $1 " | head -1; }
case "$(crow T980)" in *lived*) ;; *) echo "    FAIL: T980 fresh transcript -> label 'lived', got: '$(crow T980)'"; s_fail=1;; esac
case "$(crow T981)" in *orphaned*) ;; *) echo "    FAIL: T981 transcript past the horizon -> 'orphaned', got: '$(crow T981)'"; s_fail=1;; esac
case "$(crow T982)" in *finished*) ;; *) echo "    FAIL: T982 exit-0 run record -> 'finished', got: '$(crow T982)'"; s_fail=1;; esac
case "$(crow T983)" in *orphaned*) ;; *) echo "    FAIL: T983 nothing -> 'orphaned', got: '$(crow T983)'"; s_fail=1;; esac
# T591 alignment preserved: times at 23-28; holder at 30-37 from the store (arm P contract)
for prow in "$(crow T980)" "$(crow T981)" "$(crow T982)" "$(crow T983)"; do
    [ -n "$prow" ] || continue
    [ "$(printf '%s' "$prow" | cut -c23-28)" = "00:00 " ] || { echo "    FAIL: times column moved in CONCERNS row: '$prow'"; s_fail=1; }
    [ "$(printf '%s' "$prow" | cut -c30-37 | tr -d ' ')" = "dsflash" ] || { echo "    FAIL: holder must come from the store (arm P): '$prow'"; s_fail=1; }
done
if [ "$s_fail" = "1" ]; then FAIL=1; else echo "    PASS"; fi
rm -rf "$WORKS"

# ── Arm T: T839 — the always-UNKNOWN failure mode is broken (live file) ──
# The whole point: mid-flight every running task used to render UNKNOWN
# because tokens.jsonl is written at completion. This arm exercises the
# integration — a fleet of 3 fixtures, 1 with a transcript-with-usage, must
# show exactly 1 non-UNKNOWN rate (not 0), and no rate or freshness field
# may be blank (the silent-zero case the brief calls the failure mode).
echo "  T. live transcript breaks the always-UNKNOWN rate (live file)"
# rows under PROGRESS only (awk: start at the PROGRESS heading, stop at the
# next all-caps section heading — no CONCERNS heading means the sed range
# would run to EOF and swallow later sections' rows; and a heading line's
# empty field would count as a blank). BSD grep's BRE `\|` degenerates when
# one branch matches the empty string (`^UNKNOWN$\|^$` matched nothing), so
# the field tests are awk, not grep.
T_ROWS=$(printf '%s\n' "$FRAME_Q" | awk '/^PROGRESS$/{p=1;next} p && /^[A-Z][A-Z]+$/{p=0} p && /^  T9/{print}')
T_TOTAL=$(printf '%s\n' "$T_ROWS" | wc -l | tr -d ' ')
T_NONEMPTY=$(printf '%s\n' "$T_ROWS" | awk '$5!="" && $5!="UNKNOWN"{n++} END{print n+0}')
T_BLANK=$(printf '%s\n' "$T_ROWS" | awk '$5==""{n++} END{print n+0}')
T_FBLANK=$(printf '%s\n' "$T_ROWS" | awk '$6==""{n++} END{print n+0}')
t_fail=0
[ "$T_TOTAL" = "3" ] || { echo "    FAIL: want 3 PROGRESS rows, got $T_TOTAL"; t_fail=1; }
[ "$T_NONEMPTY" = "1" ] || { echo "    FAIL: exactly 1 transcript-with-usage -> want 1 non-UNKNOWN rate, got $T_NONEMPTY"; t_fail=1; }
[ "$T_BLANK" = "0" ] || { echo "    FAIL: $T_BLANK blank rate field(s) — silent zero is the failure mode"; t_fail=1; }
[ "$T_FBLANK" = "0" ] || { echo "    FAIL: $T_FBLANK blank freshness field(s)"; t_fail=1; }
if [ "$t_fail" = "1" ]; then FAIL=1; else echo "    PASS"; fi


if [ "$FAIL" = "1" ]; then
    echo "=== T466 watch-fleet regression: FAIL ==="
    exit 1
fi
echo "=== T466 watch-fleet regression: PASS ==="
exit 0
