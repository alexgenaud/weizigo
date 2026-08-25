#!/usr/bin/env bash
# regression-live-rate.sh — T908 controls for the fleet dashboard's live rate.
#
# The defect this row was opened for: a deepseek lane rendered UNKNOWN in the
# rate column while its live session file held 170,271 readable output tokens
# — the most of any lane in the fleet. Three seat hypotheses were falsified by
# measurement (provider difference, event shape, process staleness) before the
# verified root cause held: the dashboard had TWO sources of truth for one
# table. The row list came from live processes (pgrep); the token-reading set
# came from the store's in_progress rows. A lane whose store status was `done`
# while its worker was still alive (T786: the worker closed its own row and
# kept working) was LISTED by the process scan but NEVER READ — so the rate
# column said UNKNOWN about a lane that had a reading, which is the S11 defect
# class exactly: a surface reporting "I cannot determine" when what it means
# is "I was not asked".
#
# The fix (untracked/watch-fleet.sh): the reading set is now store-in_progress
# UNION the live process set, so every PROGRESS row has its transcript read
# (the row list and the reading set share one source). A live process whose
# store row is NOT in_progress — the closed-but-alive state — renders the
# stated reason `closed` in the rate slot (not a number: the store says this
# run is over, and quoting its tokens/s as live progress would be the
# fabricated figure the S11 contract forbids) and STILL renders the transcript
# freshness (the worker IS still writing — the incident signal). rate_of's
# "never 0" rule is unchanged for in_progress rows.
#
# Arms (each runs the LIVE untracked/watch-fleet.sh against a scratch repo +
# scratch kanban store under /tmp/weizigo — never the live tasks.json):
#   A. Per-provider rate (deepseek-real, ollama-real fixtures): a live worker
#      whose transcript is the captured real session renders a labelled rate
#      EQUAL to rate_of(true_total, elapsed) — proving the extractor reads each
#      provider's real shape AND sums it to the hand-computed true total (no
#      over-count, no under-count). This is the mechanised smoke (acceptance 4):
#      a live lane of each provider, rate column pasted by assertion.
#   B. Null control: a session with no usage blocks renders UNKNOWN, never 0,
#      never blank (rate_of's rule, gated by the meter's `if toks>0`).
#   C. Over-count control: the real fixtures are per-turn (non-monotonic output
#      sequence), so the sum IS the correct arithmetic and arm A already proves
#      sum == true total. The cumulative-synthetic fixture (output monotonic,
#      true total 1300, naive sum 3000) proves the over-count risk is REAL in
#      the sum arithmetic — and that it does NOT arise on any real provider
#      (correction 2 verified all four live lanes are per-turn; both real
#      fixtures here are non-monotonic). No cumulative-detection heuristic is
#      added: correction 2 says no real stream is cumulative, and a heuristic
#      that mis-classifies a coincidentally-non-decreasing per-turn stream as
#      cumulative would UNDER-count it — "confidently incorrect", the worse
#      failure mode. The boundary is documented, not papered over.
#   D. Closed-but-alive (the incident): a row whose store status is `done`
#      while its process is alive renders `closed` in the rate slot (NOT
#      UNKNOWN, NOT a number) and a fresh transcript age in the freshness slot
#      (the worker is still writing). This is the arm the incident asks for.
#   E. Appears-on-refresh: a dashboard frame drawn BEFORE a lane exists shows
#      no row for it; a frame drawn AFTER the worker spawns shows the row with
#      a labelled rate — proving the reading set is re-derived per frame (no
#      stale caching of the row set). The correction-1 arm.
#
# Fixtures live in tools/fixtures/live-rate-sessions/ and are FAITHFUL EXTRACTS
# of real pi session files (the load-bearing usage structure preserved verbatim;
# message text elided to "..."). deepseek-real.jsonl is from T786's live session
# (id 01a03583-..., 2026-08-24T20:43:56Z); ollama-real.jsonl is from T764's live
# session (id 01a03592-..., 2026-08-24T20:59:54Z). They are the two provider
# shapes that exist in the live session corpus; correction 2 found no third
# (all four live lanes are pi-jsonl, deepseek or ollama — there is no
# openrouter/claude lane with a live session to capture, and WEIZIGO_CLAUDE_TRANSCRIPT_DIR
# is unset on this host), so no third real fixture is synthesised.
#
# Usage:  tools/regression-live-rate.sh

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
MG="$PROJECT/bin/managent"
source "$PROJECT/tools/lib/scratch-repo.sh"
FAIL=0

mkdir -p /tmp/weizigo || { echo "regression-live-rate.sh: FATAL — cannot mkdir /tmp/weizigo" >&2; exit 2; }
WORK="$(mktemp -d /private/tmp/weizigo/live-rate-XXXXXX)" || { echo "regression-live-rate.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
PIDS=""
cleanup() {
    for p in $PIDS; do kill "$p" 2>/dev/null; done
    wait 2>/dev/null
    rm -rf "$WORK"
}
trap cleanup EXIT

LIVE="$PROJECT/untracked/watch-fleet.sh"
FIX="$PROJECT/tools/fixtures/live-rate-sessions"
[ -f "$LIVE" ] || { echo "FATAL: live file not found at $LIVE" >&2; exit 2; }
[ -f "$FIX/deepseek-real.jsonl" ] || { echo "FATAL: deepseek fixture missing" >&2; exit 2; }

# scratch repo skeleton shared by every arm
mkscratch() {  # $1 = var name for the dir
    local d="$WORK/$1"
    mkdir -p "$d/bin" "$d/untracked/tokens/sessions" "$d/docs/infra/managent"
    ln -s "$MG" "$d/bin/managent"
    cp "$PROJECT/docs/infra/model-registry.md" "$d/docs/infra/model-registry.md" 2>/dev/null
    git -C "$d" init -q
    git -C "$d" config user.email t908@test
    git -C "$d" config user.name T908
    printf '%s\n' "$d"
}

# true_total <fixture> -> sum of per-turn usage.output across assistant turns
true_total() {  # $1 = fixture name (no .jsonl)
    python3 - "$FIX/$1.jsonl" <<'PY'
import json,sys
n=0
for line in open(sys.argv[1]):
    line=line.strip()
    if not line: continue
    try: d=json.loads(line)
    except Exception: continue
    if d.get("type")=="message" and isinstance(d.get("message"),dict):
        m=d["message"]
        if m.get("role")=="assistant" and isinstance(m.get("usage"),dict):
            n+=int(m["usage"].get("output") or 0)
print(n)
PY
}

# monotonic <fixture> -> "per-turn" | "cumulative" | "empty"  (output sequence shape)
output_shape() {  # $1 = fixture name
    python3 - "$FIX/$1.jsonl" <<'PY'
import json,sys
outs=[]
for line in open(sys.argv[1]):
    line=line.strip()
    if not line: continue
    try: d=json.loads(line)
    except Exception: continue
    if d.get("type")=="message" and isinstance(d.get("message"),dict):
        m=d["message"]
        if m.get("role")=="assistant" and isinstance(m.get("usage"),dict):
            outs.append(int(m["usage"].get("output") or 0))
if not outs: print("empty")
elif len(outs)>1 and all(outs[i]<=outs[i+1] for i in range(len(outs)-1)): print("cumulative")
else: print("per-turn")
PY
}

# place_fixture <dir> <task> <fixture>: copy a fixture into the sessions dir
# with a FRESH session timestamp (now), so the per-row staleness drop (session
# start > 2 min before the process start) does not discard it as a previous
# run's leftover. Only the session line's timestamp drives the staleness check;
# the per-turn usage.output values (the load-bearing structure) are preserved
# verbatim from the real capture.
place_fixture() {  # $1=dir $2=task $3=fixture
    local dir="$1" t="$2" fx="$3"
    local now_ts; now_ts=$(date -u '+%Y-%m-%dT%H:%M:%S.000Z')
    python3 - "$FIX/$fx.jsonl" "$dir/untracked/tokens/sessions/$t.1700000000.1.0.jsonl" "$now_ts" "$dir" <<'PY'
import json,sys
src,dst,ts,cwd=sys.argv[1],sys.argv[2],sys.argv[3],sys.argv[4]
out=open(dst,"w")
for line in open(src):
    line=line.rstrip("\n")
    if not line: continue
    try: d=json.loads(line)
    except Exception: out.write(line+"\n"); continue
    if d.get("type")=="session" and isinstance(d.get("timestamp"),str):
        d["timestamp"]=ts
    if d.get("type")=="session" and "cwd" in d:
        d["cwd"]=cwd
    out.write(json.dumps(d)+"\n")
out.close()
PY
    # touch the file so its mtime is now (freshness age ~0s)
    touch "$dir/untracked/tokens/sessions/$t.1700000000.1.0.jsonl"
}

# dur_to_secs <duration col> -> seconds  (e.g. "0'02" -> 2, "1'30" -> 90, "4h28" -> 16080)
dur_to_secs() {
    awk -F"'" '
        function hm(s,   h,m){ if (index(s,"h")) { split(s,a,"h"); return a[1]*3600 + a[2]*60 } \
                               else { split(s,b,"'\''"); return b[1]*60 + b[2] } }
        { if (NF==2) print $1*60+$2; else if (index($0,"h")) print hm($0); else print $0+0 }' <<<"$1"
}

# wait_worker <task>: poll until pgrep sees the worker (removes the
# spawn-to-detect race that flaked arm O in the sibling regression — a frame
# drawn inside the worker's first second misses it). Then sleep 1 so ps etime
# is non-zero (rate_of needs elapsed > 0, else UNKNOWN).
wait_worker() {  # $1 = task id
    local t="$1" i
    for i in $(seq 1 50); do
        pgrep -f "Follow untracked/$t-" >/dev/null 2>&1 && { sleep 1; return 0; }
        sleep 0.1
    done
    return 1
}

# wait_prog_row <store> <live-copy> <task>: run one-shot frames until the task's
# PROGRESS row appears, then echo it. The per-row loop's lsof cwd check can
# return nothing on a given frame (the F/G race in the sibling regression), so
# a single frame is not a reliable witness that a detectable worker is shown;
# polling the frame gives lsof another shot. Times out after ~5 s -> echoes ''.
wait_prog_row() {  # $1=store $2=live-copy $3=task
    local store="$1" cp="$2" t="$3" i row
    for i in $(seq 1 25); do
        row=$(prog_row "$(frame "$store" "$cp")" "$t")
        [ -n "$row" ] && { printf '%s' "$row"; return 0; }
        sleep 0.2
    done
    return 1
}

# rate_matches <true_total> <esec_row> <actual_rate>: the dashboard computes the
# rate from an internal esec (one ps etime call) and renders the row's elapsed
# from a SECOND ps etime call; the two can straddle a second boundary, so the
# row's elapsed and the rate's denominator differ by ±1 s. Accept the rate if
# it equals rate_of(true_total, e) for some e in {esec_row-1, esec_row, esec_row+1}.
rate_matches() {  # $1=true_total $2=esec_row $3=actual_rate
    local tt="$1" e="$2" r="$3" cand d ee
    for d in -1 0 1; do
        ee=$(( e + d )); [ "$ee" -lt 1 ] && continue
        cand=$(rate_of "$tt" "$ee")
        [ "$r" = "$cand" ] && return 0
    done
    return 1
}

# run a one-shot dashboard frame; $1=store, $2=live-copy-path, [extra env]
frame() {  # stdin consumed; prints frame to stdout
    env -u WATCH_FLEET_SOURCE MANAGENT_STORE="$1" FLEET_COLS=200 sh "$2" </dev/null 2>/dev/null
}
# prog_row <frame> <task> -> the task's PROGRESS row (scoped to the PROGRESS
# section so a DONE/DISPATCHABLE row with the same task id is not mistaken
# for it — the T971 incident: a `done` row's verdict column read as a rate).
prog_row() {  # $1=frame $2=task
    printf '%s\n' "$1" | awk -v t="  $2 " '/^PROGRESS$/{p=1;next} p && /^[A-Z][A-Z]+$/{p=0} p && index($0,t)==1 {print; exit}'
}
field5() { printf '%s' "$1" | awk '{print $5; exit}'; }
field6() { printf '%s' "$1" | awk '{print $6; exit}'; }

echo "=== T908 live-rate regression ==="

# ── Arm A: per-provider rate (real fixtures) ─────────────────────────────
echo "  A. deepseek-real & ollama-real transcripts -> rate == rate_of(true_total, elapsed)"
WATCH_FLEET_SOURCE=1 . "$LIVE" 2>/dev/null   # expose rate_of for the expected-value check
a_fail=0
for pair in "T950:deepseek-real:deepseek-v4-flash" "T951:ollama-real:glm-5.2"; do
    id=${pair%%:*}; rest=${pair#*:}; fx=${rest%%:*}; mdl=${rest##*:}
    d=$(mkscratch "a-$id")
    STORE="$d/docs/infra/managent/tasks.json"
    CP="$d/untracked/watch-fleet-live.sh"; cp "$LIVE" "$CP"
    printf '<!--managent -->\n# %s — %s fixture\n\n**Landmark:** L1 (the dashboard tells the truth)\n' "$id" "$fx" > "$d/untracked/$id-bundle.md"
    NOW=$(date +%s); CLAIM=$(date -u -r $((NOW-60)) '+%Y-%m-%dT%H:%M:%SZ')
    printf '{"%s":{"status":"in_progress","agent":"%s","model":"%s","bundle":"untracked/%s-bundle.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"%s","done":null,"dispatched":null,"dispatched_to":null,"note":null,"verdict":null,"verdict_note":null,"acceptance":null,"skip_acceptance_reason":null,"claim_count":1},"_sys":{"next_id":9900,"directive_next":1,"assertion_next":1}}\n' "$id" "$mdl" "$mdl" "$id" "$CLAIM" > "$STORE"
    weizigo_reset_census "$STORE"
    place_fixture "$d" "$id" "$fx"
    tt=$(true_total "$fx")
    bash -c "cd '$d' && exec -a 'pi --provider ollama --model $mdl Follow untracked/$id-bundle.md' sleep 90" &
    PIDS="$PIDS $!"; wp=$!
    wait_worker "$id" || { echo "    FAIL: $id ($fx) worker never appeared in pgrep"; a_fail=1; continue; }
    row=$(wait_prog_row "$STORE" "$CP" "$id")
    [ -z "$row" ] && { echo "    FAIL: $id ($fx) never appeared in PROGRESS"; a_fail=1; continue; }
    rate=$(field5 "$row")
    eld=$(printf '%s' "$row" | awk '{print $4; exit}')
    esec=$(dur_to_secs "$eld")
    printf '    %s %s: true_total=%s elapsed=%s(%ss) rate=%s\n' "$id" "$fx" "$tt" "$eld" "$esec" "$rate"
    rate_matches "$tt" "$esec" "$rate" || { echo "    FAIL: $id rate '$rate' not in rate_of($tt, esec±1) — extractor did not sum to the true total"; a_fail=1; }
    case "$rate" in UNKNOWN|''|0*) echo "    FAIL: $id rate must be a labelled non-zero number, got '$rate'"; a_fail=1;; esac
done
if [ "$a_fail" = "1" ]; then FAIL=1; else echo "    PASS"; fi

# ── Arm B: null control — no usage blocks -> UNKNOWN, never 0 ────────────
echo "  B. empty-no-usage transcript -> UNKNOWN (never 0, never blank)"
d=$(mkscratch "b"); STORE="$d/docs/infra/managent/tasks.json"; CP="$d/untracked/watch-fleet-live.sh"; cp "$LIVE" "$CP"
id=T960
printf '<!--managent -->\n# %s — null control\n\n**Landmark:** L1 (the dashboard tells the truth)\n' "$id" > "$d/untracked/$id-bundle.md"
NOW=$(date +%s); CLAIM=$(date -u -r $((NOW-60)) '+%Y-%m-%dT%H:%M:%SZ')
printf '{"%s":{"status":"in_progress","agent":"glm-5.2","model":"glm-5.2","bundle":"untracked/%s-bundle.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"%s","done":null,"dispatched":null,"dispatched_to":null,"note":null,"verdict":null,"verdict_note":null,"acceptance":null,"skip_acceptance_reason":null,"claim_count":1},"_sys":{"next_id":9900,"directive_next":1,"assertion_next":1}}\n' "$id" "$id" "$CLAIM" > "$STORE"
weizigo_reset_census "$STORE"
place_fixture "$d" "$id" "empty-no-usage"
bash -c "cd '$d' && exec -a 'pi --provider ollama --model glm-5.2 Follow untracked/$id-bundle.md' sleep 90" & PIDS="$PIDS $!"; wait_worker "$id" || { echo "    FAIL: $id worker never appeared"; b_fail=1; }
row=$(wait_prog_row "$STORE" "$CP" "$id")
rate=$(field5 "$row")
b_fail=0
[ "$rate" = "UNKNOWN" ] || { echo "    FAIL: empty-no-usage -> rate should be UNKNOWN, got '$rate'"; b_fail=1; }
case "$rate" in 0*) echo "    FAIL: empty-no-usage -> rate must never be 0, got '$rate'"; b_fail=1;; esac
[ -z "$rate" ] && { echo "    FAIL: empty-no-usage -> rate must not be blank"; b_fail=1; }
if [ "$b_fail" = "1" ]; then FAIL=1; else echo "    PASS"; fi

# ── Arm C: over-count control ───────────────────────────────────────────
echo "  C. real fixtures are per-turn (sum == true total); cumulative fixture documents the boundary"
c_fail=0
# C1: the real fixtures are per-turn (non-monotonic) — so the sum is the
# correct arithmetic. Arm A already proved sum == true total for both; here we
# pin the SHAPE that makes the sum correct, so a future capture that is
# cumulative would surface instead of silently over-counting.
for fx in deepseek-real ollama-real; do
    shape=$(output_shape "$fx")
    [ "$shape" = "per-turn" ] || { echo "    FAIL: $fx shape='$shape' — expected per-turn (correction 2: all real lanes are per-turn)"; c_fail=1; }
    printf '    %s: shape=%s\n' "$fx" "$shape"
done
# C2: the cumulative-synthetic fixture's true total (last value) is LESS than
# its naive sum — the over-count risk is real in the sum arithmetic. Assert it
# to pin the boundary: the extractor sums, so a cumulative stream WOULD
# over-count. No real provider emits one (C1), so the risk does not arise on
# real data; no heuristic is added (it would under-count a coincidentally-
# non-decreasing per-turn stream — "confidently incorrect", the worse mode).
cshape=$(output_shape "cumulative-synthetic")
csum=$(true_total "cumulative-synthetic")
clast=$(python3 - "$FIX/cumulative-synthetic.jsonl" <<'PY'
import json,sys
last=0
for line in open(sys.argv[1]):
    line=line.strip()
    if not line: continue
    try: d=json.loads(line)
    except Exception: continue
    if d.get("type")=="message" and isinstance(d.get("message"),dict):
        m=d["message"]
        if m.get("role")=="assistant" and isinstance(m.get("usage"),dict):
            last=int(m["usage"].get("output") or 0)
print(last)
PY
)
printf '    cumulative-synthetic: shape=%s naive_sum=%s true_total(last)=%s\n' "$cshape" "$csum" "$clast"
[ "$cshape" = "cumulative" ] || { echo "    FAIL: cumulative-synthetic shape='$cshape' — expected cumulative"; c_fail=1; }
[ "$csum" -gt "$clast" ] || { echo "    FAIL: cumulative naive sum ($csum) should exceed true total ($clast) — the over-count risk"; c_fail=1; }
# C3: the closed-but-alive path renders `closed` (a reason, not a number), so
# the fix itself cannot over-count — it never quotes a token figure for a run
# the store has closed. (Exercised fully by arm D; here we state the invariant.)
if [ "$c_fail" = "1" ]; then FAIL=1; else echo "    PASS"; fi

# ── Arm D: closed-but-alive (the incident) ───────────────────────────────
echo "  D. store status done + live worker -> rate 'closed' (not UNKNOWN), freshness shows alive"
d=$(mkscratch "dd"); STORE="$d/docs/infra/managent/tasks.json"; CP="$d/untracked/watch-fleet-live.sh"; cp "$LIVE" "$CP"
# an in_progress sibling proves the normal lane still renders a rate alongside
printf '<!--managent -->\n# T970 — normal live lane\n\n**Landmark:** L1 (the dashboard tells the truth)\n' > "$d/untracked/T970-bundle.md"
printf '<!--managent -->\n# T971 — closed but alive\n\n**Landmark:** L1 (the dashboard tells the truth)\n' > "$d/untracked/T971-bundle.md"
NOW=$(date +%s); CLAIM=$(date -u -r $((NOW-600)) '+%Y-%m-%dT%H:%M:%SZ'); DONE=$(date -u -r $((NOW-120)) '+%Y-%m-%dT%H:%M:%SZ')
python3 - "$STORE" "$CLAIM" "$DONE" <<'PY'
import json,sys
d={"_sys":{"next_id":9900,"directive_next":1,"assertion_next":1}}
d["T970"]={"status":"in_progress","agent":"deepseek-v4-flash","model":"deepseek-v4-flash","bundle":"untracked/T970-bundle.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":sys.argv[2],"done":None,"dispatched":None,"dispatched_to":None,"note":None,"verdict":None,"verdict_note":None,"acceptance":None,"skip_acceptance_reason":None,"claim_count":1}
d["T971"]={"status":"done","agent":"ollama/glm-5.2","model":"glm-5.2","bundle":"untracked/T971-bundle.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":sys.argv[2],"done":sys.argv[3],"dispatched":None,"dispatched_to":None,"note":None,"verdict":"pass","verdict_note":None,"acceptance":None,"skip_acceptance_reason":None,"claim_count":1}
json.dump(d,open(sys.argv[1],"w"))
PY
weizigo_reset_census "$STORE"
place_fixture "$d" "T970" "deepseek-real"
place_fixture "$d" "T971" "ollama-real"
bash -c "cd '$d' && exec -a 'pi --provider deepseek --model deepseek-v4-flash Follow untracked/T970-bundle.md' sleep 90" & PIDS="$PIDS $!"
bash -c "cd '$d' && exec -a 'pi --provider ollama --model glm-5.2 Follow untracked/T971-bundle.md' sleep 90" & PIDS="$PIDS $!"
wait_worker T970 || { echo "    FAIL: T970 worker never appeared"; dd_fail=1; }
wait_worker T971 || { echo "    FAIL: T971 worker never appeared"; dd_fail=1; }
# poll the frame for the closed-but-alive row (the lsof cwd race can drop it
# on a single frame); judge the rate-vs-UNKNOWN verdict on the row we get.
row971=$(wait_prog_row "$STORE" "$CP" T971)
dd_fail=0
r971=$(field5 "$row971")
f971=$(field6 "$row971")
row970=$(wait_prog_row "$STORE" "$CP" T970)
r970=$(field5 "$row970")
[ -n "$row970" ] || { echo "    FAIL: T970 (in_progress) never appeared in PROGRESS"; dd_fail=1; }
[ -n "$row971" ] || { echo "    FAIL: T971 (closed-but-alive) never appeared in PROGRESS"; dd_fail=1; }
case "$r970" in *[0-9]/s) ;; *) echo "    FAIL: T970 in_progress rate should be a labelled number, got '$r970'"; dd_fail=1;; esac
[ "$r971" = "closed" ] || { echo "    FAIL: T971 closed-but-alive rate should be 'closed', got '$r971'"; dd_fail=1; }
# the rate slot must NOT be UNKNOWN (the defect) and NOT a number (no fabricated figure)
[ "$r971" != "UNKNOWN" ] || { echo "    FAIL: T971 must not render the bare UNKNOWN the incident showed"; dd_fail=1; }
case "$r971" in *[0-9]*) echo "    FAIL: T971 rate must not be a number (the store closed this run), got '$r971'"; dd_fail=1;; esac
# freshness: the worker IS alive and writing — the incident signal. A seconds
# age marker proves the transcript was read (the reading set covered the live
# process) and the worker is not dead.
case "$f971" in
    *s) printf '    T971 freshness=%s (worker alive, transcript read)\n' "$f971";;
    *)  echo "    FAIL: T971 freshness should be a seconds-age (worker alive), got '$f971'"; dd_fail=1;;
esac
if [ "$dd_fail" = "1" ]; then FAIL=1; else echo "    PASS"; fi

# ── Arm E: appears-on-refresh (no stale row-set caching) ─────────────────
echo "  E. frame before spawn shows no row; frame after spawn shows a labelled rate"
d=$(mkscratch "e"); STORE="$d/docs/infra/managent/tasks.json"; CP="$d/untracked/watch-fleet-live.sh"; cp "$LIVE" "$CP"
id=T980
printf '<!--managent -->\n# %s — appears on refresh\n\n**Landmark:** L1 (the dashboard tells the truth)\n' "$id" > "$d/untracked/$id-bundle.md"
NOW=$(date +%s); CLAIM=$(date -u -r $((NOW-60)) '+%Y-%m-%dT%H:%M:%SZ')
printf '{"%s":{"status":"in_progress","agent":"deepseek-v4-flash","model":"deepseek-v4-flash","bundle":"untracked/%s-bundle.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"%s","done":null,"dispatched":null,"dispatched_to":null,"note":null,"verdict":null,"verdict_note":null,"acceptance":null,"skip_acceptance_reason":null,"claim_count":1},"_sys":{"next_id":9900,"directive_next":1,"assertion_next":1}}\n' "$id" "$id" "$CLAIM" > "$STORE"
weizigo_reset_census "$STORE"
place_fixture "$d" "$id" "deepseek-real"
# frame 1: no worker yet -> no row for T980
FR1=$(frame "$STORE" "$CP")
e_fail=0
if printf '%s\n' "$FR1" | awk '/^PROGRESS$/{p=1;next} p && /^[A-Z][A-Z]+$/{p=0} p' | grep -q '^  T980 '; then
    echo "    FAIL: T980 should be ABSENT before its worker spawns"; e_fail=1
fi
# spawn the worker; frame 2 -> T980 appears with a labelled rate
bash -c "cd '$d' && exec -a 'pi --provider deepseek --model deepseek-v4-flash Follow untracked/$id-bundle.md' sleep 90" & PIDS="$PIDS $!"
wait_worker "$id" || { echo "    FAIL: T980 worker never appeared"; e_fail=1; }
row2=$(wait_prog_row "$STORE" "$CP" "$id")
r980=$(field5 "$row2")
[ -n "$row2" ] || { echo "    FAIL: T980 should appear in PROGRESS after spawn"; e_fail=1; }
case "$r980" in
    *[0-9]/s) printf '    T980 post-spawn rate=%s\n' "$r980";;
    *) echo "    FAIL: T980 post-spawn rate should be a labelled number, got '$r980'"; e_fail=1;;
esac
if [ "$e_fail" = "1" ]; then FAIL=1; else echo "    PASS"; fi

# ── Arm F: claude lane (run-record session_id -> ~/.claude transcript) ────
# D094: the claude lane has no --session; its transcript is the Claude Code
# harness JSONL at <claude_dir>/<session_id>.jsonl, session_id from the run
# record. The dashboard opens ONLY that file (the dir holds every claude
# session on the machine) and dedups by message.id (claude session lines
# repeat per content block — naive sum over-counts 3x here). A null
# session_id (a running or killed lane whose envelope has not been emitted)
# leaves the rate UNKNOWN, the honest answer. This arm proves the dashboard
# reads the claude transcript location and dedups correctly; the running-lane
# gap (session_id is null until the runner finalizes) is documented in the
# findings and needs a runner-side live session_id write to close.
echo "  F. claude lane: run-record session_id -> claude transcript, deduped by message.id"
d=$(mkscratch "f"); STORE="$d/docs/infra/managent/tasks.json"; CP="$d/untracked/watch-fleet-live.sh"; cp "$LIVE" "$CP"
id=T990; SID="fake-claude-session-0001"
printf '<!--managent -->\n# %s — claude lane\n\n**Landmark:** L1 (the dashboard tells the truth)\n' "$id" > "$d/untracked/$id-bundle.md"
NOW=$(date +%s); CLAIM=$(date -u -r $((NOW-60)) '+%Y-%m-%dT%H:%M:%SZ')
printf '{"%s":{"status":"in_progress","agent":"claude-opus-5","model":"claude-opus-5","bundle":"untracked/%s-bundle.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"%s","done":null,"dispatched":null,"dispatched_to":null,"note":null,"verdict":null,"verdict_note":null,"acceptance":null,"skip_acceptance_reason":null,"claim_count":1},"_sys":{"next_id":9900,"directive_next":1,"assertion_next":1}}\n' "$id" "$id" "$CLAIM" > "$STORE"
weizigo_reset_census "$STORE"
mkdir -p "$d/untracked/runs"
# run record with the session_id (the shape a FINALIZED claude lane carries)
python3 - "$d/untracked/runs/$id.json" "$id" "$SID" "$CLAIM" <<'PY'
import json,sys
json.dump({"task":sys.argv[2],"run_kind":"dispatch","model":"claude-opus-5",
  "pid":1,"pgid":1,"launcher_pid":1,"start":sys.argv[4],"start_epoch":0,
  "command":"claude -p Follow untracked/%s-bundle.md" % sys.argv[2],
  "session_id":sys.argv[3]}, open(sys.argv[1],'w'))
PY
# the claude transcript: the captured real fixture (dedup shape), placed at
# <claude_dir>/<session_id>.jsonl with a fresh session timestamp.
CDIR="$d/claude-sessions"; mkdir -p "$CDIR"
now_ts=$(date -u '+%Y-%m-%dT%H:%M:%S.000Z')
python3 - "$FIX/claude-real.jsonl" "$CDIR/$SID.jsonl" "$now_ts" <<'PY'
import json,sys
src,dst,ts=sys.argv[1],sys.argv[2],sys.argv[3]
o=open(dst,"w")
for line in open(src):
    d=json.loads(line)
    if isinstance(d.get("timestamp"),str): d["timestamp"]=ts
    m=d.get("message")
    if isinstance(m,dict) and isinstance(m.get("timestamp"),str): m["timestamp"]=ts
    o.write(json.dumps(d)+"\n")
o.close()
PY
touch "$CDIR/$SID.jsonl"
# true total = deduped sum (242+215=457); naive sum = 1371 (3x over-count)
ctt=$(python3 - "$FIX/claude-real.jsonl" <<'PY'
import json,sys
seen=set(); tot=0
for line in open(sys.argv[1]):
    d=json.loads(line)
    if d.get("type")=="assistant":
        m=d["message"]; mid=m.get("id")
        if mid in seen: continue
        seen.add(mid); tot+=int(m.get("usage",{}).get("output_tokens") or 0)
print(tot)
PY
)
naive=$(python3 -c "import json; print(sum(json.loads(l)['message']['usage']['output_tokens'] for l in open('$FIX/claude-real.jsonl') if json.loads(l).get('type')=='assistant'))")
bash -c "cd '$d' && exec -a 'claude --model claude-opus-5 -p Follow untracked/$id-bundle.md' sleep 90" & PIDS="$PIDS $!"
wait_worker "$id" || { echo "    FAIL: $id worker never appeared"; f_fail=1; }
FR=$(env -u WATCH_FLEET_SOURCE MANAGENT_STORE="$STORE" WEIZIGO_CLAUDE_TRANSCRIPT_DIR="$CDIR" FLEET_COLS=200 sh "$CP" </dev/null 2>/dev/null)
row=$(prog_row "$FR" "$id")
f_fail=0
[ -n "$row" ] || { echo "    FAIL: $id (claude) never appeared in PROGRESS"; f_fail=1; }
rate=$(field5 "$row"); eld=$(printf '%s' "$row" | awk '{print $4; exit}'); esec=$(dur_to_secs "$eld")
printf '    %s claude-real: dedup_true_total=%s naive_sum=%s elapsed=%s(%ss) rate=%s\n' "$id" "$ctt" "$naive" "$eld" "$esec" "$rate"
[ "$naive" -gt "$ctt" ] || { echo "    FAIL: claude naive sum ($naive) should exceed dedup total ($ctt) — the over-count the dedup prevents"; f_fail=1; }
rate_matches "$ctt" "$esec" "$rate" || { echo "    FAIL: $id rate '$rate' not in rate_of($ctt, esec±1) — claude dedup did not yield the true total"; f_fail=1; }
case "$rate" in UNKNOWN|''|0*) echo "    FAIL: $id rate must be a labelled non-zero number, got '$rate'"; f_fail=1;; esac
if [ "$f_fail" = "1" ]; then FAIL=1; else echo "    PASS"; fi

if [ "$FAIL" = "1" ]; then
    echo "=== T908 live-rate regression: FAIL ==="
    exit 1
fi
echo "=== T908 live-rate regression: PASS ==="
exit 0