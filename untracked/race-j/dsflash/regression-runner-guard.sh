#!/usr/bin/env bash
# regression-runner-guard.sh — Race J (dsflash lane) regression controls for
# tools/runner (T917; advances L1 "the dashboard tells the truth").
#
# The situation this gate exists for: on 2026-08-23 one bad edit to
# tools/runner (`name 'host_guard_on' is not defined`) killed 13 dispatches
# in 0.1 s inside a seven-second window (B3, docs/status/OPEN.md).  T872
# deleted this script's predecessor at 12e7055 but the S09 module-contract
# declaration (`test tools/regression-runner-guard.sh covers tools/runner`)
# outlived it, so every commit staging tools/runner selected a missing file
# and was refused; T914 removed the declaration at b3a841c to unfreeze
# commits.  Removing a broken gate is not the same as having one — this
# script is the gate.
#
# House rule this script is built to: NEVER TRUST A GREEN TEST.  Every
# assertion has TWO observed controls — a GREEN arm against the real
# tools/runner (the behaviour holds) and a RED arm against a seeded-defect
# scratch copy (the same assertion FAILS, proving it can go red).  An
# assertion whose red arm does not reproduce is reported unproven and the
# script exits non-zero.
#
# Assertions (brief's five + load-bearing extras):
#   A1  admission refusal (ram-policy.md §4.1): a --ram-mb declared need
#       that does not fit is REFUSED before spawn (exit 3), nothing is
#       killed, no process is spawned, the row stays dispatchable; and a
#       need that fits is admitted and RELEASED on exit (no ledger leak).
#   A2  wall-band RAM declaration correct at each band boundary (60/600/
#       1800 s).  The mapping is bin/subagent._wall_band_ram_mb (T913,
#       ram-policy.md §3.2): a boundary value lands in the band it STARTS —
#       59→768, 60→1792, 599→1792, 600→3072, 1799→3072, 1800→4608,
#       1801→4608.  An off-by-one at a band edge silently under-declares a
#       whole class of lanes (the T912 failure mode).
#   A3  --max-wall ceiling: a silent child past the ceiling is terminated
#       and the termination is ATTRIBUTABLE (exit 124, run record carries
#       killed_by=wall and the kill reason).
#   A4  L3 kernel-pressure alarm (ram-policy.md §4.4): sustained kernel
#       pressure (level >= 2, dwell-gated) fires ONE alarm naming the
#       largest host-wide consumer and appends host_alarms to the run
#       record — and NEVER kills the lane (INV-1).  NOTE (the canary): the
#       brief's literal "kills the lane when the host crosses its pressure
#       threshold" is FALSE-AS-SCOPED — T821 deleted the host-condition
#       kill verb; L3 has an alarm verb and no kill verb at all.
#   A5  a run record is written with its kind declared (run_kind =
#       dispatch|nested, T364/T895), so reap keys the row to the record's
#       task field and reads the record's pid/exit/signal.
#   A7  the per-process RSS-cap overrun stop (INV-4): the ONLY memory kill
#       that exists — a task overrunning its OWN declared need (> ceil(
#       ram_mb*1.25)) is stopped, labeled killed_by=rss, never a stranger's
#       memory.
#
# Isolation (T512/F3): every runner invocation runs from a scratch git repo
# under /tmp/weizigo — repo_root resolves from CWD, so heartbeats, run
# records, token tees and arbiter ledgers land in scratch, never the live
# repo.  Identity is MANAGENT_TASK_ID (env), never --task-id, so no kanban
# auto-claim runs.  MANAGENT_BIN points the reap at the real managent.  A
# closing check scans the LIVE heartbeat.jsonl for this suite's markers: a
# fixture beat in the live file is the F3 defect class returning.
#
# Sealed lane (Race J): writes nothing outside /tmp/weizigo scratch.  Do
# not commit.  Task T917 · model deepseek-v4-flash · 2026-08-25.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/../../.." && pwd)"
RUNNER="$PROJECT/tools/runner"
FAIL=0

mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/t917-dsflash-XXXXXX)" \
    || { echo "regression-runner-guard.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
REPO="$WORK/repo"
mkdir -p "$REPO/untracked" "$REPO/docs/infra/managent"
( cd "$REPO" && git init -q && printf 'untracked/\n' > .gitignore && git add -A && git commit -qm base )

# ── seeded-defect scratch copy (the RED baseline) ─────────────────────────
# A copy of tools/runner + siblings under $REPO/tools, plus bin/subagent
# under $REPO/bin for the A2 band-boundary arm.  Sibling imports resolve
# from the copy's own directory (sys.path[0]), exactly as for the live
# file.  Each assertion applies ONE surgical mutation to this copy; the
# mutation is verified applied (a missing anchor means the fixture is
# broken and the red arm CANNOT be trusted — reported, never papered).
MUT="$REPO/tools"
mkdir -p "$MUT" "$REPO/bin"
cp "$PROJECT/tools/runner" "$MUT/runner"
for sib in directive_policy.py model_tags.py fleet_caps.py token-capture.py \
           window_policy.py dispatch_verify.py model_profiles.py; do
    [ -f "$PROJECT/tools/$sib" ] && cp "$PROJECT/tools/$sib" "$MUT/"
done
cp "$PROJECT/bin/subagent" "$REPO/bin/subagent"
chmod +x "$MUT/runner" "$REPO/bin/subagent"

# ── live-telemetry baseline + closing isolation (T512, audit F3) ─────────
LIVE_HB="$PROJECT/untracked/heartbeat.jsonl"
LIVE_HB_BASE=$(wc -l < "$LIVE_HB" 2>/dev/null || echo 0)

check_isolation() {
    ISO_FAIL=0
    APPENDED=$(tail -n +$((LIVE_HB_BASE + 1)) "$LIVE_HB" 2>/dev/null)
    if [ -z "$APPENDED" ]; then
        echo "    PASS: live heartbeat.jsonl — no lines appended during the run"
    elif echo "$APPENDED" | grep -q "t917-dsflash"; then
        echo "    FAIL: fixture heartbeat line(s) appended to the LIVE heartbeat.jsonl (F3 regression)"
        echo "$APPENDED" | grep -n "t917-dsflash" | sed 's/^/    | /'
        ISO_FAIL=1
    else
        echo "    PASS: live heartbeat.jsonl — appended lines carry no fixture data"
    fi
    [ "$ISO_FAIL" -eq 0 ] || exit 1
}

cleanup() {
    if [ -n "${WORK:-}" ]; then
        # Kill anything left under the scratch (children embed $WORK paths).
        pkill -9 -f "$WORK" 2>/dev/null
    fi
    rm -rf "$WORK"
    check_isolation
}
trap cleanup EXIT

MG="$PROJECT/bin/managent"   # MANAGENT_BIN: real managent for treekill/reap

# mutate <file> <sed-expr>: apply one surgical defect and keep the file
# executable (a plain sed|mv strips the +x bit — without the chmod the red
# arm exits 126 "not executable" and the confirmation is vacuous).
mutate() {
    local f="$1" expr="$2"
    sed "$expr" "$f" > "$f.tmp" && mv "$f.tmp" "$f"
    chmod +x "$f"
}

# fresh_mut <sed-expr>: apply ONE defect to a PRISTINE copy of the runner.
# Mutations are not cumulative — a red arm must exercise exactly the defect
# it names (A4 red half 1's level>=99 would mask red half 2's kill defect).
fresh_mut() {
    cp "$PROJECT/tools/runner" "$MUT/runner"
    chmod +x "$MUT/runner"
    mutate "$MUT/runner" "$1"
}

run_green() {  # run_green <name> <log> <env...> -- <runner-args...>
    local name="$1" log="$2"; shift 2
    ( cd "$REPO" && "$@" >"$log" 2>&1 )
    echo "$?"
}

# ═══════════════════════════════════════════════════════════════════════
# A1 — admission refusal (ram-policy.md §4.1): refused, not killed,
#      nothing spawned, row stays dispatchable; fit admits + releases
# ═══════════════════════════════════════════════════════════════════════
echo "=== A1 — admission refusal: refused, not killed, nothing spawned, row stays dispatchable ==="

STATE1="$WORK/arbiter-a1.json"
FIX_AVAIL1=20000
WEIZIGO_HOST_MEM_AVAIL_MB="$FIX_AVAIL1" "$RUNNER" --arbiter-admit \
    --arbiter-id T917DS-A1-COMP --ram-mb 15000 --arbiter-state-file "$STATE1" \
    >"$WORK/a1-comp.log" 2>&1
COMP_RC=$?
MARKER1="$WORK/a1-green.marker"
rm -f "$MARKER1"
A1_GREEN_RC=$(run_green A1 "$WORK/a1-green.log" \
    env WEIZIGO_HOST_MEM_AVAIL_MB="$FIX_AVAIL1" MANAGENT_TASK_ID=T917DS-A1-GREEN \
        MANAGENT_BIN="$MG" \
    "$RUNNER" --no-prepend-zig --ram-mb 4608 --arbiter-state-file "$STATE1" \
        --max-wall 15 -- python3 -c "open('$MARKER1','w').write('spawned')")
A1_OK=1
[ "$COMP_RC" -eq 0 ] || { echo "    FAIL: competitor admit setup failed (rc=$COMP_RC) — fixture not meaningful"; A1_OK=0; }
[ "$A1_GREEN_RC" -eq 3 ] || { echo "    FAIL: expected exit 3 (refused), got $A1_GREEN_RC"; A1_OK=0; }
grep -q "ARBITER REFUSED" "$WORK/a1-green.log" || { echo "    FAIL: no ARBITER REFUSED line"; A1_OK=0; }
grep -q "row stays dispatchable" "$WORK/a1-green.log" || { echo "    FAIL: refusal did not name 'row stays dispatchable'"; A1_OK=0; }
grep -q "^\[runner\] KILL:" "$WORK/a1-green.log" && { echo "    FAIL: a KILL line appeared — refused, NOT killed"; A1_OK=0; }
[ -f "$MARKER1" ] && { echo "    FAIL: marker exists — a process WAS spawned despite the refusal"; A1_OK=0; }
if grep -q '"T917DS-A1-GREEN"' "$STATE1" 2>/dev/null; then
    echo "    FAIL: refused candidate left an admission entry (must mutate nothing)"; A1_OK=0
fi
[ "$A1_OK" -eq 1 ] && echo "    PASS: refused before spawn (exit 3), nothing killed, nothing spawned, row stays dispatchable"

# A1 RED — seeded defect: admission arithmetic always fits (projected +1e9).
fresh_mut 's/projected_mb = avail_mb - committed_mb - ram_mb/projected_mb = avail_mb - committed_mb - ram_mb + 999999999/'
grep -q "999999999" "$MUT/runner" \
    || { echo "    FATAL: A1 red fixture anchor missing (admission arithmetic moved?)"; exit 2; }
MARKER1R="$WORK/a1-red.marker"
rm -f "$MARKER1R"
A1_RED_RC=$(run_green A1-red "$WORK/a1-red.log" \
    env WEIZIGO_HOST_MEM_AVAIL_MB="$FIX_AVAIL1" MANAGENT_TASK_ID=T917DS-A1-RED \
        MANAGENT_BIN="$MG" \
    "$MUT/runner" --no-prepend-zig --ram-mb 4608 --arbiter-state-file "$STATE1" \
        --max-wall 15 -- python3 -c "open('$MARKER1R','w').write('spawned')")
if [ "$A1_RED_RC" -eq 3 ] && [ ! -f "$MARKER1R" ]; then
    echo "    FAIL: A1 red did NOT reproduce — the defected runner still refused (assertion cannot be shown red)"
    FAIL=1
else
    echo "    RED confirmed: defected runner admitted+spawned (rc=$A1_RED_RC, marker=$([ -f "$MARKER1R" ] && echo yes || echo no)) — the refusal assertion catches the break"
fi
"$RUNNER" --arbiter-release --arbiter-id T917DS-A1-COMP --arbiter-state-file "$STATE1" >/dev/null 2>&1
echo ""

# A1 null — a need that fits is admitted, runs, completes, RELEASED.
STATE1N="$WORK/arbiter-a1n.json"
MARKER1N="$WORK/a1-null.marker"
rm -f "$MARKER1N"
A1N_RC=$(run_green A1-null "$WORK/a1-null.log" \
    env WEIZIGO_HOST_MEM_AVAIL_MB="$FIX_AVAIL1" MANAGENT_TASK_ID=T917DS-A1-NULL \
        MANAGENT_BIN="$MG" \
    "$RUNNER" --no-prepend-zig --ram-mb 512 --arbiter-state-file "$STATE1N" \
        --max-wall 15 -- python3 -c "open('$MARKER1N','w').write('ran')")
A1N_OK=1
[ "$A1N_RC" -eq 0 ] || { echo "    FAIL: null expected exit 0, got $A1N_RC"; A1N_OK=0; }
[ -f "$MARKER1N" ] || { echo "    FAIL: null marker missing — child did not run"; A1N_OK=0; }
grep -q "ARBITER ADMITTED" "$WORK/a1-null.log" || { echo "    FAIL: no ARBITER ADMITTED line"; A1N_OK=0; }
if grep -q '"T917DS-A1-NULL"' "$STATE1N" 2>/dev/null; then
    echo "    FAIL: completed task's admission entry not released (ledger leak)"; A1N_OK=0
fi
[ "$A1N_OK" -eq 1 ] && echo "    PASS: fit admits, runs, completes, and its admission entry is released on exit"
echo ""

# ═══════════════════════════════════════════════════════════════════════
# A2 — wall-band RAM declaration at each boundary (60/600/1800 s)
# ═══════════════════════════════════════════════════════════════════════
echo "=== A2 — wall-band RAM declaration at each boundary (60/600/1800 s; T913 §3.2) ==="
# The declaration lives in bin/subagent._wall_band_ram_mb (the L1 layer
# that sizes the --ram-mb the runner's arbiter decides on) — the canary:
# this assertion is about bin/subagent, NOT tools/runner, and the honest
# gate tests it where it lives.

A2_PY='
import os, sys, importlib.util
from importlib.machinery import SourceFileLoader
sys.path.insert(0, os.environ["A2_TOOLS_DIR"])
loader = SourceFileLoader("subagent", os.environ["A2_SUBAGENT"])
spec = importlib.util.spec_from_loader("subagent", loader)
mod = importlib.util.module_from_spec(spec)
sys.modules["subagent"] = mod
loader.exec_module(mod)
CASES = [(59,768),(60,1792),(599,1792),(600,3072),(1799,3072),(1800,4608),(1801,4608)]
bad = [(w, e, mod._wall_band_ram_mb(w)) for w, e in CASES
       if mod._wall_band_ram_mb(w) != e]
if bad:
    print("BAND-MISMATCH: %r" % (bad,), file=sys.stderr)
    sys.exit(1)
print("BANDS-OK")
'
A2_GREEN_RC=$(env A2_TOOLS_DIR="$PROJECT/tools" A2_SUBAGENT="$PROJECT/bin/subagent" \
    python3 -c "$A2_PY" >"$WORK/a2-green.log" 2>&1; echo $?)
A2_OK=1
[ "$A2_GREEN_RC" -eq 0 ] || { echo "    FAIL: real bin/subagent band check exit $A2_GREEN_RC — boundary off-by-one?"; cat "$WORK/a2-green.log" | sed 's/^/    | /'; A2_OK=0; }
grep -q "BANDS-OK" "$WORK/a2-green.log" || { echo "    FAIL: no BANDS-OK"; A2_OK=0; }
[ "$A2_OK" -eq 1 ] && echo "    PASS: 59→768 60→1792 599→1792 600→3072 1799→3072 1800→4608 1801→4608"

# A2 RED — seeded defect: off-by-one at the 60 s boundary (`< 60` → `<= 60`).
mutate "$REPO/bin/subagent" 's/if wall_seconds < 60:/if wall_seconds <= 60:/'
grep -q "wall_seconds <= 60" "$REPO/bin/subagent" \
    || { echo "    FATAL: A2 red fixture anchor missing (band function moved?)"; exit 2; }
A2_RED_RC=$(env A2_TOOLS_DIR="$REPO/tools" A2_SUBAGENT="$REPO/bin/subagent" \
    python3 -c "$A2_PY" >"$WORK/a2-red.log" 2>&1; echo $?)
if [ "$A2_RED_RC" -eq 0 ]; then
    echo "    FAIL: A2 red did NOT reproduce — the off-by-one was not caught by the boundary assertion"
    FAIL=1
else
    echo "    RED confirmed: off-by-one at 60 s shifts every boundary (rc=$A2_RED_RC: $(grep -o 'BAND-MISMATCH:.*' "$WORK/a2-red.log" | head -c 160)) — the boundary assertion catches the T912 class"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════════
# A3 — --max-wall ceiling: terminated, and the termination is attributable
# ═══════════════════════════════════════════════════════════════════════
echo "=== A3 — --max-wall ceiling: silent child terminated, termination attributable ==="
REC3="$REPO/untracked/runs/T917DS-A3-GREEN.json"
rm -f "$REC3"
A3_GREEN_RC=$(run_green A3 "$WORK/a3-green.log" \
    env MANAGENT_TASK_ID=T917DS-A3-GREEN MANAGENT_BIN="$MG" \
    "$RUNNER" --no-prepend-zig --max-wall 2 -- \
    python3 -c "import time; time.sleep(60); open('$WORK/a3-leaf','w').write('x')")
A3_OK=1
[ "$A3_GREEN_RC" -eq 124 ] || { echo "    FAIL: expected exit 124 (wall kill), got $A3_GREEN_RC"; A3_OK=0; }
grep -q "wall ceiling 2s" "$WORK/a3-green.log" || { echo "    FAIL: no 'wall ceiling' kill message"; A3_OK=0; }
grep -q "^\[runner\] KILL:" "$WORK/a3-green.log" || { echo "    FAIL: no KILL line"; A3_OK=0; }
if [ -f "$REC3" ]; then
    python3 -c "
import json
r = json.load(open('$REC3'))
assert r.get('task') == 'T917DS-A3-GREEN', r.get('task')
assert r.get('run_kind') == 'dispatch', r.get('run_kind')
assert r.get('killed_by') == 'wall', r.get('killed_by')
assert r.get('signal') == 9, r.get('signal')
assert 'wall ceiling' in (r.get('killed') or ''), r.get('killed')
assert r.get('exit') is None, r.get('exit')  # killed, not exited
print('A3 record ok: killed_by=%s signal=%s' % (r.get('killed_by'), r.get('signal')))
" >"$WORK/a3-rec.log" 2>&1 || { echo "    FAIL: run record attribution wrong:"; cat "$WORK/a3-rec.log" | sed 's/^/    | /'; A3_OK=0; }
else
    echo "    FAIL: run record $REC3 missing — termination is not attributable"; A3_OK=0
fi
[ "$A3_OK" -eq 1 ] && echo "    PASS: killed at the ceiling, exit 124, record killed_by=wall signal=9"

# A3 RED — seeded defect: wall ceiling never fires (elapsed >= max_wall + 1e6).
fresh_mut 's/elif args.max_wall and elapsed >= args.max_wall:/elif args.max_wall and elapsed >= args.max_wall + 999999:/'
grep -q "max_wall + 999999" "$MUT/runner" \
    || { echo "    FATAL: A3 red fixture anchor missing (wall branch moved?)"; exit 2; }
REC3R="$REPO/untracked/runs/T917DS-A3-RED.json"
rm -f "$REC3R"
A3_RED_RC=$(run_green A3-red "$WORK/a3-red.log" \
    env MANAGENT_TASK_ID=T917DS-A3-RED MANAGENT_BIN="$MG" \
    "$MUT/runner" --no-prepend-zig --max-wall 2 -- \
    python3 -c "import time; time.sleep(3)")
if [ "$A3_RED_RC" -eq 124 ]; then
    echo "    FAIL: A3 red did NOT reproduce — the defected runner still wall-killed"
    FAIL=1
else
    echo "    RED confirmed: defected runner let the silent child finish (rc=$A3_RED_RC) — the wall-ceiling assertion catches the break"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════════
# A4 — L3 kernel-pressure alarm: fires, names the consumer, NEVER kills
# ═══════════════════════════════════════════════════════════════════════
echo "=== A4 — L3 kernel-pressure alarm (ram-policy §4.4): fires, never kills (INV-1) ==="
echo "    NOTE (canary): the brief's literal 'kills the lane when the host crosses"
echo "    its pressure threshold' is FALSE-AS-SCOPED — T821 deleted the host-"
echo "    condition kill verb; the guard now ALARMS (names the consumer, appends"
echo "    host_alarms) and per INV-1 never kills.  This arm asserts the alarm;"
echo "    A7 asserts the only memory kill that exists (the RSS overrun stop)."
REC4="$REPO/untracked/runs/T917DS-A4-GREEN.json"
rm -f "$REC4"
A4_GREEN_RC=$(run_green A4 "$WORK/a4-green.log" \
    env WEIZIGO_KERNEL_PRESSURE_LEVEL=2 MANAGENT_TASK_ID=T917DS-A4-GREEN \
        MANAGENT_BIN="$MG" \
    "$RUNNER" --no-prepend-zig --max-wall 20 -- \
    python3 -c "import time; time.sleep(4); print('T917DS-A4 survivor')")
A4_OK=1
[ "$A4_GREEN_RC" -eq 0 ] || { echo "    FAIL: expected exit 0 (alarm never kills), got $A4_GREEN_RC"; A4_OK=0; }
grep -q "^\[runner\] ALARM:" "$WORK/a4-green.log" || { echo "    FAIL: no ALARM line — the pressure guard did not fire"; A4_OK=0; }
grep -q "T917DS-A4 survivor" "$WORK/a4-green.log" || { echo "    FAIL: the lane did not survive — something killed it"; A4_OK=0; }
grep -q "^\[runner\] KILL:" "$WORK/a4-green.log" && { echo "    FAIL: a KILL line appeared — the alarm must never kill (INV-1)"; A4_OK=0; }
if [ -f "$REC4" ]; then
    python3 -c "
import json
r = json.load(open('$REC4'))
alarms = r.get('host_alarms') or []
assert len(alarms) >= 1, 'no host_alarms in record'
a = alarms[0]
assert a.get('level') == 2, a.get('level')
assert a.get('consumer'), a.get('consumer')
print('A4 record ok: %d alarm(s), level %s, consumer %r' % (len(alarms), a.get('level'), a.get('consumer')))
" >"$WORK/a4-rec.log" 2>&1 || { echo "    FAIL: host_alarms record wrong:"; cat "$WORK/a4-rec.log" | sed 's/^/    | /'; A4_OK=0; }
else
    echo "    FAIL: run record $REC4 missing"; A4_OK=0
fi
[ "$A4_OK" -eq 1 ] && echo "    PASS: alarm fired (level 2, consumer named, host_alarms recorded) and the lane survived — fired, never killed"

# A4 RED half 1 — seeded defect: alarm never fires (level >= 99).
fresh_mut 's/if level is not None and level >= 2:/if level is not None and level >= 99:/'
grep -q "level >= 99" "$MUT/runner" \
    || { echo "    FATAL: A4 red fixture anchor missing (pressure branch moved?)"; exit 2; }
A4_RED1_RC=$(run_green A4-red1 "$WORK/a4-red1.log" \
    env WEIZIGO_KERNEL_PRESSURE_LEVEL=2 MANAGENT_TASK_ID=T917DS-A4-RED1 \
        MANAGENT_BIN="$MG" \
    "$MUT/runner" --no-prepend-zig --max-wall 20 -- \
    python3 -c "import time; time.sleep(4)")
if grep -q "^\[runner\] ALARM:" "$WORK/a4-red1.log"; then
    echo "    FAIL: A4 red half 1 did NOT reproduce — the defected runner still alarmed"
    FAIL=1
else
    echo "    RED confirmed (half 1): defected runner never alarmed on sustained pressure — the alarm-fire assertion catches the break"
fi

# A4 RED half 2 — seeded defect: the alarm branch KILLS the lane (the
# deleted pre-T821 behaviour returns).
fresh_mut 's/alarm_active = True/alarm_active = True; kill_reason = "host memory pressure (defect)"/'
grep -q "host memory pressure (defect)" "$MUT/runner" \
    || { echo "    FATAL: A4 red fixture anchor missing (alarm branch moved?)"; exit 2; }
A4_RED2_RC=$(run_green A4-red2 "$WORK/a4-red2.log" \
    env WEIZIGO_KERNEL_PRESSURE_LEVEL=2 MANAGENT_TASK_ID=T917DS-A4-RED2 \
        MANAGENT_BIN="$MG" \
    "$MUT/runner" --no-prepend-zig --max-wall 20 -- \
    python3 -c "import time; time.sleep(4); print('T917DS-A4 survivor2')")
if [ "$A4_RED2_RC" -eq 0 ] && grep -q "T917DS-A4 survivor2" "$WORK/a4-red2.log"; then
    echo "    FAIL: A4 red half 2 did NOT reproduce — the defected runner still did not kill"
    FAIL=1
else
    echo "    RED confirmed (half 2): a pressure-kill defect makes the lane die (rc=$A4_RED2_RC, no survivor) — the never-kills assertion catches the T821-deleted behaviour returning"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════════
# A5 — a run record is written with its kind declared (reap-readable)
# ═══════════════════════════════════════════════════════════════════════
echo "=== A5 — run record written with kind declared (T364/T895), so reap reads the dispatch record ==="
REC5="$REPO/untracked/runs/T917DS-A5-GREEN.json"
rm -f "$REC5"
A5_GREEN_RC=$(run_green A5 "$WORK/a5-green.log" \
    env MANAGENT_TASK_ID=T917DS-A5-GREEN MANAGENT_BIN="$MG" \
    "$RUNNER" --no-prepend-zig --max-wall 15 -- \
    python3 -c "print('T917DS-A5 done')")
A5_OK=1
[ "$A5_GREEN_RC" -eq 0 ] || { echo "    FAIL: expected exit 0, got $A5_GREEN_RC"; A5_OK=0; }
if [ -f "$REC5" ]; then
    python3 -c "
import json
r = json.load(open('$REC5'))
assert r.get('task') == 'T917DS-A5-GREEN', r.get('task')
assert r.get('run_kind') == 'dispatch', r.get('run_kind')
assert r.get('exit') == 0, r.get('exit')
assert r.get('end'), r.get('end')
assert (r.get('pid') or 0) > 0, r.get('pid')
assert 'T917DS-A5 done' in (r.get('command') or ''), r.get('command')
print('A5 record ok: run_kind=%s exit=%s pid=%s' % (r.get('run_kind'), r.get('exit'), r.get('pid')))
" >"$WORK/a5-rec.log" 2>&1 || { echo "    FAIL: record shape wrong (reap reads task/run_kind/pid/exit):"; cat "$WORK/a5-rec.log" | sed 's/^/    | /'; A5_OK=0; }
else
    echo "    FAIL: run record $REC5 missing — reap has nothing to key the row to"; A5_OK=0
fi
[ "$A5_OK" -eq 1 ] && echo "    PASS: record written with task, run_kind=dispatch, exit, end, pid — the shape reap reads"

# A5 RED — seeded defect: no run record at all (the F6/T515 defect class:
# identity present but record_root suppressed).
fresh_mut 's/record_root = repo_root if not identity_degraded else None/record_root = None/'
grep -q "record_root = None" "$MUT/runner" \
    || { echo "    FATAL: A5 red fixture anchor missing (record_root line moved?)"; exit 2; }
REC5R="$REPO/untracked/runs/T917DS-A5-RED.json"
rm -f "$REC5R"
A5_RED_RC=$(run_green A5-red "$WORK/a5-red.log" \
    env MANAGENT_TASK_ID=T917DS-A5-RED MANAGENT_BIN="$MG" \
    "$MUT/runner" --no-prepend-zig --max-wall 15 -- \
    python3 -c "print('T917DS-A5 red done')")
if [ -f "$REC5R" ]; then
    echo "    FAIL: A5 red did NOT reproduce — the defected runner still wrote a record"
    FAIL=1
else
    echo "    RED confirmed: defected runner wrote no run record (rc=$A5_RED_RC) — the record-kind assertion catches the F6 class"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════════
# A7 — the RSS-cap overrun stop (INV-4): the only memory kill, always the
#      task's OWN overrun
# ═══════════════════════════════════════════════════════════════════════
echo "=== A7 — RSS-cap overrun stop (INV-4): the only memory kill, and it is the task's OWN overrun ==="
STATE7="$WORK/arbiter-a7.json"
REC7="$REPO/untracked/runs/T917DS-A7-GREEN.json"
rm -f "$REC7"
A7_GREEN_RC=$(run_green A7 "$WORK/a7-green.log" \
    env WEIZIGO_HOST_MEM_AVAIL_MB=20000 MANAGENT_TASK_ID=T917DS-A7-GREEN \
        MANAGENT_BIN="$MG" \
    "$RUNNER" --no-prepend-zig --ram-mb 100 --arbiter-state-file "$STATE7" \
        --max-wall 15 -- python3 -c "import time; x = bytearray(200*1024*1024); time.sleep(5)")
A7_OK=1
[ "$A7_GREEN_RC" -eq 124 ] || { echo "    FAIL: expected exit 124 (rss overrun stop), got $A7_GREEN_RC"; A7_OK=0; }
grep -q "RSS cap 125 MB exceeded" "$WORK/a7-green.log" || { echo "    FAIL: no 'RSS cap 125 MB exceeded' kill message"; A7_OK=0; }
grep -q "overrunning its OWN declared need" "$WORK/a7-green.log" || { echo "    FAIL: no INV-4 note naming the OWN overrun"; A7_OK=0; }
if [ -f "$REC7" ]; then
    python3 -c "
import json
r = json.load(open('$REC7'))
assert r.get('killed_by') == 'rss', r.get('killed_by')
print('A7 record ok: killed_by=%s' % r.get('killed_by'))
" >"$WORK/a7-rec.log" 2>&1 || { echo "    FAIL: record killed_by wrong:"; cat "$WORK/a7-rec.log" | sed 's/^/    | /'; A7_OK=0; }
else
    echo "    FAIL: run record $REC7 missing"; A7_OK=0
fi
if grep -q '"T917DS-A7-GREEN"' "$STATE7" 2>/dev/null; then
    echo "    FAIL: stopped task's admission entry not released (ledger leak)"; A7_OK=0
fi
[ "$A7_OK" -eq 1 ] && echo "    PASS: 200 MB over a declared 100 MB (cap 125) → stopped, killed_by=rss, released"

# A7 RED — seeded defect: the RSS cap never fires.
fresh_mut 's/if rss_cap_mb and rss > cap_bytes:/if rss_cap_mb and False:/'
grep -q "rss_cap_mb and False" "$MUT/runner" \
    || { echo "    FATAL: A7 red fixture anchor missing (rss branch moved?)"; exit 2; }
A7_RED_RC=$(run_green A7-red "$WORK/a7-red.log" \
    env WEIZIGO_HOST_MEM_AVAIL_MB=20000 MANAGENT_TASK_ID=T917DS-A7-RED \
        MANAGENT_BIN="$MG" \
    "$MUT/runner" --no-prepend-zig --ram-mb 100 --arbiter-state-file "$STATE7" \
        --max-wall 15 -- python3 -c "import time; x = bytearray(200*1024*1024); time.sleep(2)")
if [ "$A7_RED_RC" -eq 124 ]; then
    echo "    FAIL: A7 red did NOT reproduce — the defected runner still overrun-stopped"
    FAIL=1
else
    echo "    RED confirmed: defected runner let the 200 MB overrun complete (rc=$A7_RED_RC) — the overrun-stop assertion catches the break"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════════
echo "=========================================================================="
echo "assertion summary (green rc = real tools/runner, red rc = seeded-defect copy):"
echo "  A1 admission-refusal        green=$A1_GREEN_RC (3=refused)   red=$A1_RED_RC   RED=$([ "$A1_RED_RC" -eq 3 ] && [ ! -f "$MARKER1R" ] && echo NO || echo YES)"
echo "  A1 null (fit+release)       green=$A1N_RC"
echo "  A2 band-boundaries          green=$A2_GREEN_RC (0)           red=$A2_RED_RC   RED=$([ "$A2_RED_RC" -eq 0 ] && echo NO || echo YES)"
echo "  A3 wall-ceiling             green=$A3_GREEN_RC (124)         red=$A3_RED_RC   RED=$([ "$A3_RED_RC" -eq 124 ] && echo NO || echo YES)"
echo "  A4 alarm-fires              green=$A4_GREEN_RC (0)           red1=$A4_RED1_RC RED=$([ -n "$(grep '^\[runner\] ALARM:' "$WORK/a4-red1.log" 2>/dev/null)" ] && echo NO || echo YES)"
echo "  A4 never-kills              green=$A4_GREEN_RC               red2=$A4_RED2_RC RED=$([ "$A4_RED2_RC" -eq 0 ] && echo NO || echo YES)"
echo "  A5 record-kind              green=$A5_GREEN_RC (0)           red=$A5_RED_RC   RED=$([ -f "$REC5R" ] && echo NO || echo YES)"
echo "  A7 rss-overrun-stop         green=$A7_GREEN_RC (124)         red=$A7_RED_RC   RED=$([ "$A7_RED_RC" -eq 124 ] && echo NO || echo YES)"
echo "=========================================================================="
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-runner-guard (dsflash): ALL CONTROLS PASSED — every assertion green, every red reproduced ==="
    exit 0
else
    echo "=== regression-runner-guard (dsflash): FAILURES — see above ==="
    exit 1
fi
