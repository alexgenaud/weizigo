#!/usr/bin/env bash
# regression-runner-guard.sh — T916 (Race J, lane ox-alpha)
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
# shown to fail is reported as such by this script and must not be counted
# as coverage.
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

if [ ! -x "$RUNNER" ]; then RUNNER="$REPO/tools/runner.py"; fi
[ -f "$RUNNER" ] || { echo "FATAL: tools/runner not found under $REPO"; exit 1; }
[ -f "$SUBAGENT" ] || { echo "FATAL: bin/subagent not found under $REPO"; exit 1; }

SCRATCH="${TMPDIR:-/tmp}/weizigo/regression-runner-guard.$$"
mkdir -p "$SCRATCH"
trap 'rm -rf "$SCRATCH"' EXIT

TOTAL=0 FAILED=0 RED_TOTAL=0 RED_FAILED=0
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

# make_mutant <src> <dst> <old> <new> — exit 0 iff <old> occurs >= 1 time.
make_mutant() {
    python3 - "$1" "$2" "$3" "$4" <<'PYEOF'
import sys
src, dst, old, new = sys.argv[1:5]
s = open(src).read()
n = s.count(old)
if n == 0:
    sys.exit(1)
open(dst, "w").write(s.replace(old, new))
print(f"mutant: {n} occurrence(s) replaced")
PYEOF
}

# ── scratch repo: the runner resolves repo root from cwd ────────────────
SREPO="$SCRATCH/repo"
mkdir -p "$SREPO/untracked"
git init -q "$SREPO" 2>/dev/null

RUNNER_ENV=(MANAGENT_RUN_IDENTITY= WEIZIGO_DISPATCH_VERIFY_UNPINNED=1)

# run_in_repo <identity> [VAR=val ...] -- <runner args...>
# Runs the runner with cwd=SREPO so records/heartbeats land in the scratch
# tree.  Identity comes via MANAGENT_TASK_ID only (--task-id would trigger
# managent auto-claim against the scratch repo).
run_in_repo() {
    local ident="$1"; shift
    ( cd "$SREPO" && env "${RUNNER_ENV[@]}" MANAGENT_TASK_ID="$ident" "$@" )
}

recfile() { printf '%s/untracked/runs/%s.json' "$SREPO" "$1"; }

jsonget() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d.get(sys.argv[2], ""))' "$1" "$2" 2>/dev/null; }

# ════════════════════════════════════════════════════════════════════
echo "== A1: admission refusal (L2, ram-policy §4.1) =="
# ════════════════════════════════════════════════════════════════════

A1STATE="$SCRATCH/a1-arbiter-state.json"
rm -f "$A1STATE"

# Green arm: declared need far exceeds injected host availability -> REFUSED.
WEIZIGO_HOST_MEM_AVAIL_MB=1000 python3 "$RUNNER" \
    --ram-mb 10000 --arbiter-id a1-refuse --arbiter-state-file "$A1STATE" \
    --arbiter-admit >"$SCRATCH/a1.out" 2>"$SCRATCH/a1.err"
rc=$?
check a1-refuse-exit3 "standalone admit with avail=1000 need=10000 refuses (observed rc=$rc)" \
    $([ "$rc" -eq 3 ] && echo 0 || echo 1)

grep -q '"admit": false' "$SCRATCH/a1.out"
check a1-verdict-json "refusal verdict carries admit:false ($SCRATCH/a1.out)" $?

python3 -c '
import json
st = json.load(open("'"$A1STATE"'"))
admitted = st.get("admitted", {})
sys_exit = 0 if "a1-refuse" not in admitted else 1
' 2>/dev/null
led_ok=$(python3 -c '
import json
try:
    st = json.load(open("'"$A1STATE"'"))
except OSError:
    st = {"admitted": {}}
print(0 if "a1-refuse" not in st.get("admitted", {}) else 1)')
check a1-ledger-unmutated "a refusal mutates nothing: identity NOT admitted into the ledger (row stays dispatchable)" "$led_ok"

# Null control: generous availability -> ADMITTED (the gate admits when it fits).
WEIZIGO_HOST_MEM_AVAIL_MB=100000 python3 "$RUNNER" \
    --ram-mb 10000 --arbiter-id a1-admit --arbiter-state-file "$A1STATE" \
    --arbiter-admit >"$SCRATCH/a1n.out" 2>/dev/null
rc=$?
check a1-null-admits "null control: same need with avail=100000 admits (observed rc=$rc)" \
    $([ "$rc" -eq 0 ] && echo 0 || echo 1)

# Committed-sum composition: one admitted lane consumes headroom, next candidate refused.
WEIZIGO_HOST_MEM_AVAIL_MB=10000 python3 "$RUNNER" \
    --ram-mb 4000 --arbiter-id a1-holder --arbiter-state-file "$A1STATE" \
    --arbiter-admit >/dev/null 2>&1
WEIZIGO_HOST_MEM_AVAIL_MB=10000 python3 "$RUNNER" \
    --ram-mb 8000 --arbiter-id a1-second --arbiter-state-file "$A1STATE" \
    --arbiter-preview >"$SCRATCH/a1c.out" 2>/dev/null
rc=$?   # preview: 3 = WOULD refuse — committed 4000 + candidate 8000 > 10000-reserve
check a1-committed-sum "committed lane counts against the next candidate (avail 10000, held 4000, want 8000 -> refuse; observed rc=$rc)" \
    $([ "$rc" -eq 3 ] && echo 0 || echo 1)
python3 "$RUNNER" --arbiter-release --arbiter-id a1-holder \
    --arbiter-state-file "$A1STATE" >/dev/null 2>&1

# Launch-path refusal: the full runner refuses BEFORE spawning the child.
rm -f "$SREPO/marker"
run_in_repo T916GRD-A1L \
    WEIZIGO_HOST_MEM_AVAIL_MB=1000 \
    python3 "$RUNNER" --ram-mb 60000 --arbiter-state-file "$A1STATE" \
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
    WEIZIGO_HOST_MEM_AVAIL_MB=1000 PYTHONPATH="$REPO/tools" \
        python3 "$MUTANT" --ram-mb 10000 --arbiter-id a1-red \
        --arbiter-state-file "$A1STATE" --arbiter-admit >/dev/null 2>&1
    mrc=$?
    # The mutant admits what the real runner refuses -> our exit-3 assertion
    # fires on it -> the assertion can fail.  That is what makes it coverage.
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

python3 - "$SUBAGENT" "$SCRATCH" <<'PYEOF'
import importlib.util, sys, types, os
from importlib.machinery import SourceFileLoader

subagent_path, scratch = sys.argv[1], sys.argv[2]

def load(path, name):
    # Stub window_policy so a relocated copy still imports (module-level
    # `import window_policy` after sys.path insertion).
    if "window_policy" not in sys.modules:
        stub = types.ModuleType("window_policy")
        for attr in ("WindowPolicy", "evaluate", "reset"):
            setattr(stub, attr, getattr(stub, attr, None))
        sys.modules["window_policy"] = stub
    # bin/subagent has no .py suffix: name the loader explicitly or the
    # spec comes back None and exec_module explodes.
    spec = importlib.util.spec_from_loader(
        name, SourceFileLoader(name, path))
    mod = importlib.util.module_from_spec(spec)
    try:
        spec.loader.exec_module(mod)
    except Exception:
        # Heavier fallback: extract just the two functions we assert on.
        src = open(path).read()
        ns = {}
        start = src.index("def _wall_band_ram_mb")
        end = src.index("def ", start + 10)
        exec(src[start:end], {"__builtins__": __builtins__}, ns)
        mod = types.SimpleNamespace(_wall_band_ram_mb=ns["_wall_band_ram_mb"])
    return mod

real = load(subagent_path, "subagent_real")

EXPECT = [(1,768),(59,768),(60,1792),(61,1792),(599,1792),
          (600,3072),(601,3072),(1799,3072),(1800,4608),(3600,4608)]

fails = []
for wall, want in EXPECT:
    got = real._wall_band_ram_mb(wall)
    if got != want:
        fails.append((wall, want, got))

with open(os.path.join(scratch, "a2.green"), "w") as f:
    f.write("OK" if not fails else "BROKEN %r" % (fails,))
with open(os.path.join(scratch, "a2.detail"), "w") as f:
    f.write("; ".join(f"{w}->{got}!={want}" for w, want, got in fails))

# Red control: shift the 600 s boundary by one second.  Exactly-600 s lanes
# then under-declare (3072 -> 1792): the T912 failure mode this table exists
# to prevent.  If our boundary checks do NOT catch it, they are decoration.
mutant_src = open(subagent_path).read()
old = "if wall_seconds < 600:"
new = "if wall_seconds <= 600:"
if old not in mutant_src:
    open(os.path.join(scratch, "a2.red"), "w").write("ANCHOR-MISSING")
else:
    mut_path = os.path.join(scratch, "subagent_mutant_a2.py")
    open(mut_path, "w").write(mutant_src.replace(old, new))
    mut = load(mut_path, "subagent_mutant_a2")
    caught = any(mut._wall_band_ram_mb(w) != want for w, want in EXPECT)
    open(os.path.join(scratch, "a2.red"), "w").write(
        "CAUGHT" if caught else "INSENSITIVE")
PYEOF

a2g=$(cat "$SCRATCH/a2.green")
if [ "$a2g" = "OK" ]; then
    ok a2-boundaries "band-start convention holds: 59->768, 60->1792, 599->1792, 600->3072, 1799->3072, 1800->4608"
else
    bad a2-boundaries "band boundary violated: $(cat "$SCRATCH/a2.detail")"
fi

case "$(cat "$SCRATCH/a2.red")" in
    CAUGHT)      red_caught a2-red "600s boundary shifted by 1s -> boundary assertion detects the off-by-one" ;;
    INSENSITIVE) red_missed a2-red "boundary mutation went undetected — assertion showed NO sensitivity" ;;
    *)           bad a2-red-harness "could not build band mutant ($(cat "$SCRATCH/a2.red"))" ;;
esac

# Unparseable wall falls to the TOP band (over-declaration is safe).
unp=$(python3 - "$SUBAGENT" <<'PYEOF'
import importlib.util, sys, types
from importlib.machinery import SourceFileLoader
if "window_policy" not in sys.modules:
    stub = types.ModuleType("window_policy")
    for attr in ("WindowPolicy", "evaluate", "reset"):
        setattr(stub, attr, getattr(stub, attr, None))
    sys.modules["window_policy"] = stub
spec = importlib.util.spec_from_loader(
    "sa_u", SourceFileLoader("sa_u", sys.argv[1]))
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
print(mod._declared_ram_mb("pi", "x/y", {}, None))
PYEOF
)
check a2-unparseable-top-band "unparseable expected-wall declares the top band 4608 (safe direction; got ${unp:-<err>})" \
    $([ "$unp" = "4608" ] && echo 0 || echo 1)

# ════════════════════════════════════════════════════════════════════
echo "== A3: --max-wall terminates a silent child, attribution intact =="
# ════════════════════════════════════════════════════════════════════

run_in_repo T916GRD-A3 python3 "$RUNNER" --max-wall 2 --poll-ms 250 \
    -- python3 -c 'import time; time.sleep(8)' \
    >"$SCRATCH/a3.out" 2>"$SCRATCH/a3.err"
rc=$?
check a3-exit124 "silent child past max-wall=2 killed; runner exit 124 (observed rc=$rc)" \
    $([ "$rc" -eq 124 ] && echo 0 || echo 1)
grep -q "wall ceiling" "$SCRATCH/a3.err"
check a3-names-guard "kill line names the guard (stderr contains 'wall ceiling')" $?

R3="$(recfile T916GRD-A3)"
if [ -f "$R3" ]; then
    kb=$(jsonget "$R3" killed_by); sig=$(jsonget "$R3" signal)
    check a3-attributable "run record attributes the kill: killed_by=$kb signal=$sig" \
        $([ "$kb" = "wall" ] && [ "$sig" = "9" ] && echo 0 || echo 1)
    grep -q '"wall_budget": 2' "$R3"
    check a3-budget-recorded "record joins the kill to its wall budget (wall_budget=2)" $?
else
    bad a3-attributable "no run record written at $R3"
fi

# Red control: disarm the wall ceiling -> child completes -> assertion fires.
MUTANT="$SCRATCH/runner-mutant-a3.py"
if make_mutant "$RUNNER" "$MUTANT" \
       'elif args.max_wall and elapsed >= args.max_wall:' \
       'elif False and args.max_wall and elapsed >= args.max_wall:'; then
    ( cd "$SREPO" && env "${RUNNER_ENV[@]}" MANAGENT_TASK_ID=T916GRD-A3R \
        PYTHONPATH="$REPO/tools" python3 "$MUTANT" --max-wall 2 --poll-ms 250 \
        -- python3 -c 'import time; time.sleep(6)' ) >/dev/null 2>&1
    mrc=$?
    if [ "$mrc" -ne 124 ]; then
        red_caught a3-red "wall ceiling disarmed -> mutant lets the child finish (rc=$mrc); exit-124 assertion detects it"
    else
        red_missed a3-red "mutant still wall-killed (rc=$mrc) — another guard masks the ceiling; assertion showed NO sensitivity"
    fi
else
    bad a3-red-harness "could not build wall-ceiling mutant"
fi

# ════════════════════════════════════════════════════════════════════
echo "== A4: kernel pressure ALARM fires sustained, never kills (L3) =="
# ════════════════════════════════════════════════════════════════════

run_in_repo T916GRD-A4 \
    WEIZIGO_KERNEL_PRESSURE_LEVEL=4 WEIZIGO_HOST_MEM_AVAIL_MB=100000 \
    python3 "$RUNNER" --poll-ms 300 --max-wall 30 \
    -- python3 -c 'import time; time.sleep(6)' \
    >"$SCRATCH/a4.out" 2>"$SCRATCH/a4.err"
rc=$?
check a4-child-survives "critical pressure does NOT kill the child; runner exits clean (observed rc=$rc)" \
    $([ "$rc" -eq 0 ] && echo 0 || echo 1)
grep -q "\[runner\] ALARM: host memory pressure" "$SCRATCH/a4.err"
check a4-alarm-fires "sustained pressure raises the ALARM (dwell 3 polls >= 2s)" $?

R4="$(recfile T916GRD-A4)"
if [ -f "$R4" ]; then
    alarms=$(python3 -c 'import json; d=json.load(open("'"$R4"'")); print(len(d.get("host_alarms") or []))')
    kb=$(jsonget "$R4" killed_by)
    cons=$(python3 -c 'import json; d=json.load(open("'"$R4"'")); a=(d.get("host_alarms") or [{}])[0]; print(a.get("consumer",""))')
    ex=$(jsonget "$R4" exit)
    check a4-record-alarm "alarm recorded in the run record (host_alarms=$alarms)" \
        $([ "${alarms:-0}" -ge 1 ] && echo 0 || echo 1)
    check a4-names-consumer "alarm NAMES the largest host process (consumer='$cons')" \
        $([ -n "$cons" ] && echo 0 || echo 1)
    check a4-no-kill-stamp "never kills: record shows normal exit=$ex and NO killed_by (got '${kb:-none}')" \
        $([ "$ex" = "0" ] && [ -z "$kb" ] && echo 0 || echo 1)
else
    bad a4-record-alarm "no run record at $R4"
    bad a4-names-consumer "(skipped — no record)" 1
    bad a4-no-kill-stamp "(skipped — no record)" 1
fi

# Null control: normal pressure level -> no alarm.
run_in_repo T916GRD-A4N \
    WEIZIGO_KERNEL_PRESSURE_LEVEL=1 WEIZIGO_HOST_MEM_AVAIL_MB=100000 \
    python3 "$RUNNER" --poll-ms 300 --max-wall 20 \
    -- python3 -c 'import time; time.sleep(4)' >/dev/null 2>"$SCRATCH/a4n.err"
grep -q "ALARM:" "$SCRATCH/a4n.err"
check a4-null-no-alarm "null control: level 1 produces no alarm" $([ $? -ne 0 ] && echo 0 || echo 1)

# Red control: raise the alarm threshold above critical -> alarm never fires.
MUTANT="$SCRATCH/runner-mutant-a4.py"
if make_mutant "$RUNNER" "$MUTANT" 'level >= 2' 'level >= 5'; then
    ( cd "$SREPO" && env "${RUNNER_ENV[@]}" MANAGENT_TASK_ID=T916GRD-A4R \
        PYTHONPATH="$REPO/tools" WEIZIGO_KERNEL_PRESSURE_LEVEL=4 \
        WEIZIGO_HOST_MEM_AVAIL_MB=100000 \
        python3 "$MUTANT" --poll-ms 300 --max-wall 20 \
        -- python3 -c 'import time; time.sleep(4)' ) >/dev/null 2>"$SCRATCH/a4r.err"
    if grep -q "ALARM: host memory pressure" "$SCRATCH/a4r.err"; then
        red_missed a4-red "threshold mutant still alarmed — assertion showed NO sensitivity"
    else
        red_caught a4-red "alarm threshold raised past critical -> no ALARM; alarm-present assertion detects it"
    fi
else
    bad a4-red-harness "could not build pressure-threshold mutant"
fi

# ════════════════════════════════════════════════════════════════════
echo "== A5: every run record declares its kind (T895) =="
# ════════════════════════════════════════════════════════════════════

run_in_repo T916GRD-A5 python3 "$RUNNER" --max-wall 20 -- sh -c 'exit 7' \
    >"$SCRATCH/a5.out" 2>"$SCRATCH/a5.err"
rc=$?
R5="$(recfile T916GRD-A5)"
if [ -f "$R5" ]; then
    kind=$(jsonget "$R5" run_kind)
    reason=$(jsonget "$R5" run_kind_reason)
    attempt=$(jsonget "$R5" attempt)
    check a5-kind-declared "dispatch record carries run_kind='$kind' (writer-declared, reader never infers)" \
        $([ "$kind" = "dispatch" ] && echo 0 || echo 1)
    check a5-kind-reason "kind carries its REASON ('$reason')" \
        $([ -n "$reason" ] && echo 0 || echo 1)
    check a5-attempt "attempt numbered (attempt=${attempt:-missing})" \
        $([ -n "$attempt" ] && echo 0 || echo 1)
else
    bad a5-kind-declared "no dispatch record at $R5"
    bad a5-kind-reason "(skipped)" 1
    bad a5-attempt "(skipped)" 1
fi
check a5-exit-forwarded "child's own exit forwarded (sh exit 7 -> runner rc=$rc)" \
    $([ "$rc" -eq 7 ] && echo 0 || echo 1)

# Nested classification: a runner started INSIDE its own dispatch's env
# (marker == identity) is classified nested and kept out of the dispatch slot.
( cd "$SREPO" && env "${RUNNER_ENV[@]}" \
    MANAGENT_TASK_ID=T916GRD-A5N MANAGENT_RUN_IDENTITY=T916GRD-A5N \
    python3 "$RUNNER" --max-wall 20 -- sh -c 'exit 0' ) >/dev/null 2>"$SCRATCH/a5n.err"
nested_count=$(ls "$SREPO/untracked/runs/nested/" 2>/dev/null | grep -c '^T916GRD-A5N\.' )
check a5-nested-segregated "nested run lands under runs/nested/ ($nested_count record(s)); bare dispatch slot untouched" \
    $([ "${nested_count:-0}" -ge 1 ] && [ ! -f "$(recfile T916GRD-A5N)" ] && echo 0 || echo 1)

# Red control: stop stamping run_kind -> declaration assertion fails.
MUTANT="$SCRATCH/runner-mutant-a5.py"
if make_mutant "$RUNNER" "$MUTANT" '"run_kind": run_kind,' '"run_kind_stamped_out": None,'; then
    ( cd "$SREPO" && env "${RUNNER_ENV[@]}" MANAGENT_TASK_ID=T916GRD-A5R \
        PYTHONPATH="$REPO/tools" python3 "$MUTANT" --max-wall 20 \
        -- sh -c 'exit 7' ) >/dev/null 2>&1
    R5R="$(recfile T916GRD-A5R)"
    rk=$(jsonget "$R5R" run_kind)
    if [ "$rk" != "dispatch" ]; then
        red_caught a5-red "run_kind stamp removed -> record lacks the field; declaration assertion detects it"
    else
        red_missed a5-red "mutant record still stamped run_kind — anchor hit a non-load-bearing site; assertion showed NO sensitivity"
    fi
else
    bad a5-red-harness "could not build run_kind mutant"
fi

# ════════════════════════════════════════════════════════════════════
echo ""
echo "== summary =="
echo "green arms : $((TOTAL-FAILED))/$TOTAL passed"
echo "red controls: $((RED_TOTAL-RED_FAILED))/$RED_TOTAL caught their defect"
if [ "$FAILED" -eq 0 ] && [ "$RED_FAILED" -eq 0 ] && [ "$TOTAL" -gt 0 ]; then
    echo "GUARD GREEN (and provably sensitive)"
    exit 0
fi
echo "GUARD RED — see $LOG"
exit 1
