#!/usr/bin/env bash
# regression-runner-guard.sh — T919 (Race J, lane kimi-k2.7)
#
# Regression gate for tools/runner, the fleet's launch chokepoint.
# Declared contract this script enforces (docs/infra/host/ram-policy.md,
# tools/runner header comments):
#
#   A1  L2 admission: a lane whose declared RAM does not fit the host is
#       REFUSED before spawn (exit 3), nothing spawns, the ledger is not
#       mutated, and no running task is touched (INV-1/INV-3).
#   A2  Wall-band RAM declaration boundaries: exactly 60 s -> 1792 MB,
#       exactly 600 s -> 3072 MB, exactly 1800 s -> 4608 MB (T913 band-
#       start convention; an off-by-one silently under-declares a class
#       of lanes).  Lives in bin/subagent's _wall_band_ram_mb.
#   A3  --max-wall terminates a silent child and the termination is
#       attributable: exit 124, run record killed_by="wall", signal 9.
#   A4  The L3 memory-pressure backstop ALARMS on sustained kernel
#       pressure (dwell 3 polls >= 2 s), names the consumer in the run
#       record, and NEVER kills (record exits clean) — INV-1.
#   A5  Every run writes a run record whose kind ("run_kind") is declared
#       by the writer, never inferred by a reader (T895); nested runs are
#       segregated under untracked/runs/nested/.
#
# House rule: never trust a green test.  Every assertion ships with a RED
# control — the assertion is re-run against a deliberately broken copy of
# the code under test and MUST fail there.  An assertion that cannot be
# shown to fail is reported as such and must not be counted as coverage.
#
# Isolation: everything runs inside a throwaway git repo under
# /tmp/weizigo/, so run records, heartbeats and arbiter ledgers never
# touch the live untracked/.  The runner is executed, never modified; red
# controls use copies.  Stdlib-only + git + python3 required.
#
# Exit 0 = all assertions green AND every red control caught.
# Exit 1 = at least one failure (green arm or red control).

set -u

REPO="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
RUNNER="$REPO/tools/runner"
SUBAGENT="$REPO/bin/subagent"
MANAGENT="$REPO/bin/managent"

[ -f "$RUNNER" ] || { echo "FATAL: tools/runner not found under $REPO"; exit 1; }
[ -f "$SUBAGENT" ] || { echo "FATAL: bin/subagent not found under $REPO"; exit 1; }
[ -f "$MANAGENT" ] || { echo "FATAL: bin/managent not found under $REPO"; exit 1; }

SCRATCH="${TMPDIR:-/tmp}/weizigo/regression-runner-guard-kimi.$$"
mkdir -p "$SCRATCH"
trap 'rm -rf "$SCRATCH"' EXIT

SREPO="$SCRATCH/repo"
mkdir -p "$SREPO/untracked"
git init -q "$SREPO" 2>/dev/null

# Environment common to every runner invocation.  MANAGENT_TASK_ID (not
# --task-id) prevents auto-claim against the scratch repo; MANAGENT_BIN
# lets a mutant copy find the real managent binary; MANAGENT_RUN_IDENTITY
# is cleared so the nested-run test can set it itself.
RUNNER_ENV=(
    MANAGENT_RUN_IDENTITY=
    WEIZIGO_DISPATCH_VERIFY_UNPINNED=1
    MANAGENT_BIN="$MANAGENT"
)

TOTAL=0; FAILED=0; RED_TOTAL=0; RED_FAILED=0
LOG="$SCRATCH/results.log"
: >"$LOG"

ok()        { TOTAL=$((TOTAL+1));      echo "PASS       $1  $2" | tee -a "$LOG"; }
bad()       { TOTAL=$((TOTAL+1)); FAILED=$((FAILED+1));
              echo "FAIL       $1  $2" | tee -a "$LOG"; }
red_caught(){ RED_TOTAL=$((RED_TOTAL+1)); echo "RED-CAUGHT $1  $2" | tee -a "$LOG"; }
red_missed(){ RED_TOTAL=$((RED_TOTAL+1)); RED_FAILED=$((RED_FAILED+1));
              echo "RED-MISSED $1  $2 (assertion cannot detect its defect)" \
                | tee -a "$LOG"; }

# check <id> <desc> <sh-condition-result(0=held)>
check() {
    if [ "$3" -eq 0 ]; then ok "$1" "$2"; else bad "$1" "$2"; fi
}

# run_in_repo <identity> [VAR=val ...] -- <runner args...>
run_in_repo() {
    local ident="$1"; shift
    local envs=()
    while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do
        envs+=("$1"); shift
    done
    [ "${1:-}" = "--" ] && shift
    ( cd "$SREPO" && env "${RUNNER_ENV[@]}" "${envs[@]+"${envs[@]}"}" MANAGENT_TASK_ID="$ident" python3 "$RUNNER" "$@" )
}

recfile() { printf '%s/untracked/runs/%s.json' "$SREPO" "$1"; }
jsonget() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d.get(sys.argv[2], ""))' "$1" "$2" 2>/dev/null; }

# make_mutant <src> <dst> <old> <new> — exit 0 iff <old> occurs >= 1 time.
make_mutant() {
    python3 - "$1" "$2" "$3" "$4" <<'PYEOF'
import sys
src, dst, old, new = sys.argv[1:5]
s = open(src).read()
n = s.count(old)
if n == 0:
    sys.stderr.write(f"make_mutant: anchor {old!r} not found in {src}\n")
    sys.exit(1)
open(dst, "w").write(s.replace(old, new))
print(f"mutant: {n} occurrence(s) replaced")
PYEOF
}

# run_mutant <mutant.py> [extra env] -- <runner args...>
run_mutant() {
    local mutant="$1"; shift
    local envs=()
    while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do
        envs+=("$1"); shift
    done
    [ "${1:-}" = "--" ] && shift
    ( cd "$SREPO" && env "${RUNNER_ENV[@]}" PYTHONPATH="$REPO/tools" MANAGENT_BIN="$MANAGENT" "${envs[@]+"${envs[@]}"}" python3 "$mutant" "$@" )
}

# ════════════════════════════════════════════════════════════════════
echo "== A1: admission refusal (L2, ram-policy §4.1) =="
# ════════════════════════════════════════════════════════════════════

A1STATE="$SCRATCH/a1-arbiter-state.json"
rm -f "$A1STATE"

# Green: declared need far exceeds injected host availability -> REFUSED.
WEIZIGO_HOST_MEM_AVAIL_MB=1000 python3 "$RUNNER" \
    --ram-mb 10000 --arbiter-id a1-refuse --arbiter-state-file "$A1STATE" \
    --arbiter-admit >"$SCRATCH/a1.out" 2>"$SCRATCH/a1.err"
rc=$?
check a1-refuse-exit3 "standalone admit with avail=1000 need=10000 refuses (observed rc=$rc)" \
    $([ "$rc" -eq 3 ] && echo 0 || echo 1)

grep -q '"admit": false' "$SCRATCH/a1.out"
check a1-verdict-json "refusal verdict carries admit:false" $?

led_ok=$(python3 -c '
import json
try:
    st = json.load(open("'"$A1STATE"'"))
except OSError:
    st = {"admitted": {}}
print(0 if "a1-refuse" not in st.get("admitted", {}) else 1)')
check a1-ledger-unmutated "a refusal mutates nothing: identity NOT admitted into the ledger (row stays dispatchable)" "$led_ok"

# Null control: generous availability -> ADMITTED.
WEIZIGO_HOST_MEM_AVAIL_MB=100000 python3 "$RUNNER" \
    --ram-mb 10000 --arbiter-id a1-admit --arbiter-state-file "$A1STATE" \
    --arbiter-admit >"$SCRATCH/a1n.out" 2>/dev/null
rc=$?
check a1-null-admits "null control: same need with avail=100000 admits (observed rc=$rc)" \
    $([ "$rc" -eq 0 ] && echo 0 || echo 1)
python3 "$RUNNER" --arbiter-release --arbiter-id a1-admit \
    --arbiter-state-file "$A1STATE" >/dev/null 2>&1

# Committed-sum composition: one admitted lane consumes headroom, next refused.
rm -f "$A1STATE"
WEIZIGO_HOST_MEM_AVAIL_MB=10000 python3 "$RUNNER" \
    --ram-mb 4000 --arbiter-id a1-holder --arbiter-state-file "$A1STATE" \
    --arbiter-admit >/dev/null 2>&1
WEIZIGO_HOST_MEM_AVAIL_MB=10000 python3 "$RUNNER" \
    --ram-mb 8000 --arbiter-id a1-second --arbiter-state-file "$A1STATE" \
    --arbiter-preview >"$SCRATCH/a1c.out" 2>/dev/null
rc=$?
check a1-committed-sum "committed lane counts against the next candidate (avail 10000, held 4000, want 8000 -> refuse; observed rc=$rc)" \
    $([ "$rc" -eq 3 ] && echo 0 || echo 1)
python3 "$RUNNER" --arbiter-release --arbiter-id a1-holder \
    --arbiter-state-file "$A1STATE" >/dev/null 2>&1

# Launch-path refusal: the full runner refuses BEFORE spawning the child.
rm -f "$SREPO/marker"
run_in_repo T919GRD-A1L \
    WEIZIGO_HOST_MEM_AVAIL_MB=1000 \
    -- --ram-mb 60000 --arbiter-state-file "$A1STATE" \
    -- sh -c 'touch marker' >"$SCRATCH/a1l.out" 2>"$SCRATCH/a1l.err"
rc=$?
check a1-launch-refused "launch path refuses pre-spawn (observed rc=$rc)" \
    $([ "$rc" -eq 3 ] && echo 0 || echo 1)
check a1-launch-nospawn "nothing spawned on refusal: child marker file absent" \
    $([ ! -f "$SREPO/marker" ] && echo 0 || echo 1)
grep -q "ARBITER REFUSED" "$SCRATCH/a1l.err"
check a1-launch-names-reason "refusal names itself loudly on stderr (ARBITER REFUSED)" $?

# Red control: delete the reserve floor -> refusal becomes admission.
MUTANT="$SCRATCH/runner-mutant-a1.py"
if make_mutant "$RUNNER" "$MUTANT" \
       'ARBITER_RESERVE_MB = 4608' \
       'ARBITER_RESERVE_MB = -999999'; then
    rm -f "$A1STATE"
    WEIZIGO_HOST_MEM_AVAIL_MB=1000 \
        run_mutant "$MUTANT" \
        MANAGENT_TASK_ID=a1-red \
        -- --ram-mb 10000 --arbiter-id a1-red \
        --arbiter-state-file "$A1STATE" --arbiter-admit >/dev/null 2>&1
    mrc=$?
    if [ "$mrc" -ne 3 ]; then
        red_caught a1-red "reserve-floor deleted -> mutant admits (rc=$mrc); exit-3 assertion detects it"
    else
        red_missed a1-red "mutant still refused (rc=$mrc) — assertion showed NO sensitivity"
    fi
else
    bad a1-red-harness "could not build reserve-floor mutant (anchor string gone?)"
fi

# ════════════════════════════════════════════════════════════════════
echo "== A2: wall-band RAM declaration boundaries (bin/subagent, T913) =="
# ════════════════════════════════════════════════════════════════════

python3 - "$SUBAGENT" "$REPO" >"$SCRATCH/a2.out" 2>"$SCRATCH/a2.err" <<'PYEOF'
import sys
from importlib.machinery import SourceFileLoader
subagent_path, repo = sys.argv[1:3]
sys.path.insert(0, repo + "/tools")
sub = SourceFileLoader("subagent", subagent_path).load_module()
cases = [
    (1, 768),
    (59, 768),
    (60, 1792),
    (61, 1792),
    (599, 1792),
    (600, 3072),
    (601, 3072),
    (1799, 3072),
    (1800, 4608),
    (3600, 4608),
]
ok = True
for wall, expected in cases:
    got = sub._wall_band_ram_mb(wall)
    if got != expected:
        print(f"FAIL wall={wall}: expected {expected}, got {got}")
        ok = False
    else:
        print(f"OK wall={wall} -> {got}")
# unparseable wall -> top band (safe direction)
got = sub._declared_ram_mb("pi", None, {}, None)
print(f"unparseable -> {got}")
if got != 4608:
    ok = False
sys.exit(0 if ok else 1)
PYEOF
rc=$?
check a2-boundaries "wall-band boundaries match ram-policy.md §3.2 (observed rc=$rc)" $rc

# Red control: shift the 600-second boundary by one second.
MUTANT_SUB="$SCRATCH/subagent-mutant-a2.py"
if make_mutant "$SUBAGENT" "$MUTANT_SUB" \
       'wall_seconds < 600' \
       'wall_seconds <= 600'; then
    python3 - "$SUBAGENT" "$REPO" "$MUTANT_SUB" >"$SCRATCH/a2red.out" 2>"$SCRATCH/a2red.err" <<'PYEOF'
import sys
from importlib.machinery import SourceFileLoader
subagent_path, repo, mutant_path = sys.argv[1:4]
sys.path.insert(0, repo + "/tools")
sub = SourceFileLoader("subagent", mutant_path).load_module()
if sub._wall_band_ram_mb(600) == 1792:
    sys.exit(1)  # assertion should detect the boundary shift
else:
    sys.exit(0)
PYEOF
    mrc=$?
    if [ "$mrc" -eq 1 ]; then
        red_caught a2-red "boundary shifted '< 600' -> '<= 600' (600 s under-declares); assertion detects it"
    else
        red_missed a2-red "mutant not detected (rc=$mrc)"
    fi
else
    bad a2-red-harness "could not build boundary mutant (anchor string gone?)"
fi

# ════════════════════════════════════════════════════════════════════
echo "== A3: --max-wall termination is attributable =="
# ════════════════════════════════════════════════════════════════════

rm -f "$(recfile T919GRD-A3)"
run_in_repo T919GRD-A3 \
    -- --max-wall 2 -- \
    python3 -c 'import time; time.sleep(30)' >"$SCRATCH/a3.out" 2>"$SCRATCH/a3.err"
rc=$?
check a3-wall-kill-exit124 "silent child past --max-wall=2 exits runner 124 (observed rc=$rc)" \
    $([ "$rc" -eq 124 ] && echo 0 || echo 1)
grep -q "wall ceiling 2s" "$SCRATCH/a3.err"
check a3-wall-kill-named "stderr names the guard (wall ceiling ...)" $?
check a3-record-exists "run record written" \
    $([ -f "$(recfile T919GRD-A3)" ] && echo 0 || echo 1)
kb=$(jsonget "$(recfile T919GRD-A3)" killed_by)
check a3-killed-by-wall "run record killed_by='wall' (observed '$kb')" \
    $([ "$kb" = "wall" ] && echo 0 || echo 1)
sig=$(jsonget "$(recfile T919GRD-A3)" signal)
check a3-signal-9 "run record signal=9 (observed '$sig')" \
    $([ "$sig" = "9" ] && echo 0 || echo 1)
wb=$(jsonget "$(recfile T919GRD-A3)" wall_budget)
check a3-wall-budget-recorded "run record wall_budget=2 (observed '$wb')" \
    $([ "$wb" = "2" ] && echo 0 || echo 1)

# Red control: disarm the wall-ceiling branch.
MUTANT="$SCRATCH/runner-mutant-a3.py"
if make_mutant "$RUNNER" "$MUTANT" \
       'elif args.max_wall and elapsed >= args.max_wall:' \
       'elif False and args.max_wall and elapsed >= args.max_wall:'; then
    rm -f "$(recfile T919GRD-A3R)"
    run_mutant "$MUTANT" \
        MANAGENT_TASK_ID=T919GRD-A3R \
        -- --max-wall 2 -- \
        python3 -c 'import time; time.sleep(1)' >"$SCRATCH/a3r.out" 2>"$SCRATCH/a3r.err"
    mrc=$?
    if [ "$mrc" -ne 124 ]; then
        red_caught a3-red "wall-ceiling disarmed -> child finishes (rc=$mrc); exit-124 assertion detects it"
    else
        red_missed a3-red "mutant still killed (rc=$mrc)"
    fi
else
    bad a3-red-harness "could not build wall-ceiling mutant"
fi

# ════════════════════════════════════════════════════════════════════
echo "== A4: memory-pressure host guard (L3, ram-policy §4.4) =="
# ════════════════════════════════════════════════════════════════════

rm -f "$(recfile T919GRD-A4)"
run_in_repo T919GRD-A4 \
    WEIZIGO_KERNEL_PRESSURE_LEVEL=4 \
    -- --max-wall 30 --progress-timeout 0 -- \
    sh -c 'sleep 5' >"$SCRATCH/a4.out" 2>"$SCRATCH/a4.err"
rc=$?
check a4-clean-exit "injected pressure 4: child completes, runner exits 0 (observed rc=$rc)" \
    $([ "$rc" -eq 0 ] && echo 0 || echo 1)
grep -q "ALARM: host memory pressure level 4" "$SCRATCH/a4.err"
check a4-alarm-line "stderr ALARM names level-4 pressure" $?
ha=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(len(d.get("host_alarms", [])))' "$(recfile T919GRD-A4)" 2>/dev/null)
check a4-record-host-alarms "run record host_alarms non-empty (observed count=$ha)" \
    $([ "${ha:-0}" -ge 1 ] && echo 0 || echo 1)
kb=$(jsonget "$(recfile T919GRD-A4)" killed_by)
check a4-no-killed-by "pressure alarm never kills: killed_by absent/null (observed '$kb')" \
    $([ -z "$kb" ] && echo 0 || echo 1)
ex=$(jsonget "$(recfile T919GRD-A4)" exit)
check a4-record-exit-0 "run record exit=0 (observed '$ex')" \
    $([ "$ex" = "0" ] && echo 0 || echo 1)

# Null control: level 1 (normal) produces no alarm.
rm -f "$(recfile T919GRD-A4N)"
run_in_repo T919GRD-A4N \
    WEIZIGO_KERNEL_PRESSURE_LEVEL=1 \
    -- --max-wall 10 --progress-timeout 0 -- \
    sh -c 'sleep 2' >"$SCRATCH/a4n.out" 2>"$SCRATCH/a4n.err"
grep -q "ALARM: host memory pressure" "$SCRATCH/a4n.err"
check a4-null-no-alarm "level 1 (normal): no ALARM line on stderr" \
    $([ $? -ne 0 ] && echo 0 || echo 1)

# Red control: raise the threshold so the injected level 4 never alarms.
MUTANT="$SCRATCH/runner-mutant-a4.py"
if make_mutant "$RUNNER" "$MUTANT" \
       'if level is not None and level >= 2:' \
       'if level is not None and level >= 5:'; then
    rm -f "$(recfile T919GRD-A4R)"
    run_mutant "$MUTANT" \
        MANAGENT_TASK_ID=T919GRD-A4R WEIZIGO_KERNEL_PRESSURE_LEVEL=4 \
        -- --max-wall 10 --progress-timeout 0 -- \
        sh -c 'sleep 3' >"$SCRATCH/a4r.out" 2>"$SCRATCH/a4r.err"
    grep -q "ALARM: host memory pressure" "$SCRATCH/a4r.err"
    mrc=$?
    if [ "$mrc" -ne 0 ]; then
        red_caught a4-red "threshold 'level>=2' -> 'level>=5': critical pressure raises no alarm; assertion detects it"
    else
        red_missed a4-red "mutant still alarmed (mrc=$mrc)"
    fi
else
    bad a4-red-harness "could not build pressure-threshold mutant"
fi

# ════════════════════════════════════════════════════════════════════
echo "== A5: run record kind declared (T895) =="
# ════════════════════════════════════════════════════════════════════

rm -f "$(recfile T919GRD-A5)"
run_in_repo T919GRD-A5 \
    -- --max-wall 30 -- \
    sh -c 'exit 7' >"$SCRATCH/a5.out" 2>"$SCRATCH/a5.err"
rc=$?
check a5-child-exit-forwarded "child exit 7 forwarded verbatim (observed rc=$rc)" \
    $([ "$rc" -eq 7 ] && echo 0 || echo 1)
check a5-record-exists "run record written" \
    $([ -f "$(recfile T919GRD-A5)" ] && echo 0 || echo 1)
rk=$(jsonget "$(recfile T919GRD-A5)" run_kind)
check a5-run-kind-dispatch "run record run_kind='dispatch' (observed '$rk')" \
    $([ "$rk" = "dispatch" ] && echo 0 || echo 1)
rkr=$(jsonget "$(recfile T919GRD-A5)" run_kind_reason)
check a5-run-kind-reason "run record run_kind_reason non-empty" \
    $([ -n "$rkr" ] && echo 0 || echo 1)
at=$(jsonget "$(recfile T919GRD-A5)" attempt)
check a5-attempt-1 "run record attempt=1 (observed '$at')" \
    $([ "$at" = "1" ] && echo 0 || echo 1)

# Nested run: env marker == identity -> run_kind=nested, path under runs/nested/.
rm -f "$(recfile T919GRD-A5N)" "$SREPO/untracked/runs/nested/T919GRD-A5N".*
run_in_repo T919GRD-A5N \
    -- --max-wall 30 -- \
    sh -c "cd '$SREPO'; MANAGENT_TASK_ID=T919GRD-A5N python3 '$RUNNER' --max-wall 30 -- sh -c 'exit 11'" >"$SCRATCH/a5n.out" 2>"$SCRATCH/a5n.err"
rc=$?
check a5-nested-rc "nested child exit 11 forwarded (observed rc=$rc)" \
    $([ "$rc" -eq 11 ] && echo 0 || echo 1)
nested=$(find "$SREPO/untracked/runs/nested" -maxdepth 1 -name 'T919GRD-A5N.*' 2>/dev/null | head -n1)
check a5-nested-file "nested record exists under untracked/runs/nested/" \
    $([ -n "$nested" ] && echo 0 || echo 1)
if [ -n "$nested" ]; then
    nrk=$(jsonget "$nested" run_kind)
    check a5-nested-kind "nested record run_kind='nested' (observed '$nrk')" \
        $([ "$nrk" = "nested" ] && echo 0 || echo 1)
fi
# The dispatch slot must contain the parent (dispatch) record; the nested
# record must live separately under runs/nested/.
prk=$(jsonget "$(recfile T919GRD-A5N)" run_kind)
check a5-dispatch-slot-kept "dispatch slot bare record kept with run_kind='dispatch' (observed '$prk')" \
    $([ "$prk" = "dispatch" ] && echo 0 || echo 1)

# Red control: strip the run_kind stamp from the launch record.
MUTANT="$SCRATCH/runner-mutant-a5.py"
if make_mutant "$RUNNER" "$MUTANT" \
       '"run_kind": run_kind,' \
       '"run_kind_deleted": True,'; then
    rm -f "$(recfile T919GRD-A5R)" "$SREPO/untracked/runs/T919GRD-A5R.json"
    # Note: the mutant still writes the record but without run_kind.
    run_mutant "$MUTANT" \
        MANAGENT_TASK_ID=T919GRD-A5R \
        -- --max-wall 30 -- \
        sh -c 'exit 7' >"$SCRATCH/a5r.out" 2>"$SCRATCH/a5r.err"
    mrc=$?
    # We only care that the record lacks the field.
    if [ -f "$(recfile T919GRD-A5R)" ]; then
        mrk=$(jsonget "$(recfile T919GRD-A5R)" run_kind)
        if [ -z "$mrk" ]; then
            red_caught a5-red "run_kind field removed -> assertion fails on mutant"
        else
            red_missed a5-red "mutant still carried run_kind '$mrk'"
        fi
    else
        red_missed a5-red "mutant wrote no record at all"
    fi
else
    bad a5-red-harness "could not build run_kind mutant"
fi

# ════════════════════════════════════════════════════════════════════
# Summary
# ════════════════════════════════════════════════════════════════════

echo "== Summary =="
cat "$LOG"
printf "\nTOTAL green checks: %d  FAILED: %d\n" "$TOTAL" "$FAILED"
printf "TOTAL red controls: %d  MISSED: %d\n" "$RED_TOTAL" "$RED_FAILED"

if [ "$FAILED" -eq 0 ] && [ "$RED_FAILED" -eq 0 ]; then
    echo "RESULT: PASS — all green arms held and all red controls caught."
    exit 0
else
    echo "RESULT: FAIL — at least one green arm failed or a red control missed."
    exit 1
fi
