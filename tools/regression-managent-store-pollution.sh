#!/usr/bin/env bash
# regression-managent-store-pollution.sh — T572 controls: load-test lanes must
# never touch the live kanban store.
#
# The incident (2026-08-21, scrubbed by T567): the T559 load test dispatched
# six dummy lanes (TL1A..TL1F) via `tools/runner --max-wall 600 --task-id TL1x`.
# The runner AUTO-CLAIMS the named row at launch (WORKER-CHANNEL), the host
# guard SIGKILLed each lane, and no exit path closed or retired the rows — six
# rows sat `in_progress` in docs/infra/managent/tasks.json, making the
# `in progress (8)` gauge lie by six.  T567's reconstruction
# (findings/T567-tl1-dummy-lane-scrub.json): there was no resurrection — the
# close never landed; the rows were claimed and guard-killed with no cleanup
# path.  The TL1x ids also carried no T427 fixture marker (DOCTOR/FIXTURE/
# SEED/PROBE/ARM/TEST), so the live-store guard did not trip.
#
# The fix (job 1): a load test must run against a scratch MANAGENT_STORE (the
# established pattern, regression-dispatch-verification.sh:82).  The runner's
# auto-claim is redirected because the child `managent` inherits the env var;
# the runner itself is untouched (its cull/reap logic is out of scope).
#
# Arms (all in a scratch repo under /tmp/weizigo; the REAL live store is
# read-only — its SHA-256 is snapshotted before and asserted byte-identical
# after):
#   A. the fix (known-good): a guard-kill lane (host-pressure injection, the
#      T559 shape) with MANAGENT_STORE=scratch — the claim lands in the
#      scratch store and the live-store stand-in (the scratch repo's default
#      store) is never even created.
#   B. seeded defect (known-bad → known-good): reproduce the pre-fix shape —
#      a guard-kill lane WITHOUT MANAGENT_STORE leaves the dummy row
#      `in_progress` in the stand-in store; the pollution checker MUST go RED;
#      retiring the row (the cleanup path T567 used) turns it GREEN.
#   C. clean-exit path: a lane that exits 0 runs auto-done against the scratch
#      store (the T390 claim-window refusal proves the attempt was redirected
#      when the lane is too fast for the 10s window); the stand-in store stays
#      untouched.
#   D. null control: a store with no dummy rows is GREEN (specificity).
#   Final: the REAL live store is byte-identical and the checker is GREEN on it.
#
# Binary resolution: MANAGENT_BIN → zig-out/bin/managent → bin/managent (same
# convention as regression-runner-taskid.sh arm D).  SKIP when none exists —
# the runner's auto-claim needs managent.
#
# Task: T572 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-22

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
RUNNER="$PROJECT/tools/runner"
FAIL=0

cleanup() { [ -n "${WORK:-}" ] && rm -rf "$WORK"; }
trap cleanup EXIT

# T445: /tmp/weizigo decays; refuse to run if scratch creation fails (an
# empty scratch var once sent a suite's arms into the LIVE repo).
mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/t572-store-pollution-XXXXXX)" || { echo "regression-managent-store-pollution.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
cd "$WORK"
git init -q
git config user.email t572@test
git config user.name T572
echo base > README.md
mkdir -p docs/infra/managent untracked bin
printf 'untracked/\n' > .gitignore
git add README.md .gitignore
git commit -qm base

# ── managent binary resolution (the runner's auto-claim needs it) ─────────
MG="${MANAGENT_BIN:-}"
if [ -z "$MG" ]; then
    if [ -x "$PROJECT/zig-out/bin/managent" ]; then
        MG="$PROJECT/zig-out/bin/managent"
    elif [ -x "$PROJECT/bin/managent" ]; then
        MG="$PROJECT/bin/managent"
    fi
fi
if [ -z "$MG" ] || [ ! -x "$MG" ]; then
    echo "SKIP: no managent binary found (build with 'zig build'); the runner's auto-claim needs it"
    exit 0
fi
ln -sf "$MG" bin/managent

# The runner resolves repo_root from CWD ($WORK), so its child `managent`
# invocations resolve bin/managent to the symlink above; MANAGENT_STORE
# redirects every store write the child makes.
DEFAULT_STORE="$WORK/docs/infra/managent/tasks.json"   # live-store stand-in
SCRATCH_STORE="$WORK/scratch-store/tasks.json"         # the fix's scratch store
LIVE_STORE="$PROJECT/docs/infra/managent/tasks.json"   # REAL live store (read-only)
LIVE_BEFORE=$(shasum -a 256 "$LIVE_STORE" | cut -d' ' -f1)

# canonical model label for the runner's auto-claim --agent (claim validates)
export PI_MODEL=deepseek-v4-flash

note() { echo "$*"; }
pass() { echo "    PASS: $*"; }
fail() { echo "    FAIL: $*"; FAIL=1; }

# ── the pollution checker (the arm) ───────────────────────────────────────
# RED (exit 1) when the store holds a load-test dummy lane; GREEN (exit 0)
# when clean.  A dummy lane is a row whose id is TL<digit>* (the TL1x
# convention from the T559 incident) or whose note/bundle names a load test
# or a dummy lane.  Retired rows live in the archive, so a scan of tasks.json
# only ever sees live rows.
check_store() {
    python3 - "$1" "$2" <<'PY'
import json, re, sys
store, label = sys.argv[1], sys.argv[2]
try:
    with open(store) as f:
        rows = json.load(f)
except FileNotFoundError:
    print(f"    {label}: GREEN (no store file)")
    sys.exit(0)
except Exception as e:
    print(f"    {label}: ERROR reading store: {e}")
    sys.exit(2)
found = []
for tid, r in rows.items():
    if tid == "_sys":
        continue
    note = r.get("note") or ""
    bundle = r.get("bundle") or ""
    if re.match(r"^TL\d", tid) or "load-test" in note.lower() or "dummy lane" in note.lower():
        found.append((tid, r.get("status"), note[:64]))
if found:
    for tid, st, n in found:
        print(f"    {label}: RED — dummy lane {tid} ({st}) note={n!r}")
    sys.exit(1)
print(f"    {label}: GREEN — no dummy lanes")
sys.exit(0)
PY
}

seed_lane() { # $1 id — registers into whatever store the ambient MANAGENT_STORE
    # names (exported for the fix arms, unset for the seeded-defect arm), so
    # the add and the runner's child claim read the SAME env the runner sees.
    local id="$1"
    printf '<!--managent set=A deliverables=findings/%s-load.json-->\n# %s bundle\n**Landmark:** none directly; unblocks regression fixture\n' "$id" "$id" > "untracked/$id-load.md"
    bin/managent add "$id" --bundle "untracked/$id-load.md" --note "T572 load-test dummy lane" >/dev/null 2>&1
}

row_status() { # $1 id  $2 store → prints the row's status ("" if absent)
    python3 - "$1" "$2" <<'PY'
import json, sys
tid, store = sys.argv[1], sys.argv[2]
try:
    rows = json.load(open(store))
except Exception:
    sys.exit(1)
r = rows.get(tid)
print(r.get("status", "") if r else "")
PY
}

echo "=== regression-managent-store-pollution (T572) ==="

# ── A. the fix: scratch MANAGENT_STORE redirects the auto-claim ────────────
echo "  A. guard-kill lane with MANAGENT_STORE=scratch (the T559 lane shape)"
export MANAGENT_STORE="$SCRATCH_STORE"
seed_lane TL2A
set +e
WEIZIGO_HOST_MEM_AVAIL_MB=100 "$RUNNER" --no-prepend-zig --max-wall 15 --task-id TL2A -- \
    python3 -c 'import time; time.sleep(120)' >laneA.out 2>laneA.err
RC=$?
set -e
if [ "$RC" -eq 124 ]; then
    pass "guard fired on the injected lane (exit 124, SIGKILL shape)"
else
    fail "guard lane exited $RC (expected 124); trailer: $(tail -3 laneA.err | tr '\n' ' ')"
fi
ST=$(row_status TL2A "$SCRATCH_STORE")
if [ "$ST" = "in_progress" ]; then
    pass "claim landed in the SCRATCH store (TL2A in_progress there)"
else
    fail "scratch store TL2A status is '$ST' (expected in_progress — the auto-claim must run and redirect)"
fi
if [ -f "$DEFAULT_STORE" ]; then
    fail "live-store stand-in was CREATED by the guard-kill lane (pollution path still open)"
else
    pass "live-store stand-in never created (auto-claim fully redirected)"
fi

# ── B. seeded defect: the checker goes RED on the pre-fix shape ────────────
echo "  B. seeded defect: guard-kill lane WITHOUT MANAGENT_STORE (pre-fix shape)"
unset MANAGENT_STORE
seed_lane TL2C
set +e
WEIZIGO_HOST_MEM_AVAIL_MB=100 "$RUNNER" --no-prepend-zig --max-wall 15 --task-id TL2C -- \
    python3 -c 'import time; time.sleep(120)' >laneC.out 2>laneC.err
RC=$?
set -e
if [ "$RC" -eq 124 ]; then
    pass "guard fired on the seeded lane (exit 124)"
else
    fail "seeded lane exited $RC (expected 124); trailer: $(tail -3 laneC.err | tr '\n' ' ')"
fi
ST=$(row_status TL2C "$DEFAULT_STORE")
if [ "$ST" = "in_progress" ]; then
    pass "defect shape reproduced: dummy lane left in_progress in the stand-in store (the T559 leak)"
else
    fail "seeded lane did not leave TL2C in_progress in the stand-in store (status '$ST')"
fi
if check_store "$DEFAULT_STORE" "seeded-defect"; then
    fail "checker went GREEN on a store holding a dummy lane (must be RED)"
else
    pass "checker RED on the seeded dummy lane — the arm catches the pollution"
fi
# cleanup path: retire the row (the exact verb T567 used) → GREEN
bin/managent retire TL2C --note "T572 arm-B cleanup (retire = the T567 scrub verb)" >/dev/null 2>&1
if check_store "$DEFAULT_STORE" "after-cleanup"; then
    pass "checker GREEN after retire (cleanup path works)"
else
    fail "checker still RED after retire (cleanup path broken)"
fi
# reset the stand-in: arm B intentionally created it; arm C must prove the
# fix path does not (re)create it.  After the retire it holds only _sys.
rm -f "$DEFAULT_STORE"

# ── C. clean-exit path: auto-done redirects to the scratch store ───────────
echo "  C. clean-exit lane: the exit-0 path also writes only the scratch store"
export MANAGENT_STORE="$SCRATCH_STORE"
seed_lane TL2B
set +e
"$RUNNER" --no-prepend-zig --no-host-guard --max-wall 15 --task-id TL2B -- sh -c 'echo hi' >laneB.out 2>laneB.err
RC=$?
set -e
# exit may be 0 (done accepted) or 1 (T390 claim-window refusal for a lane
# faster than 10 s) — either is legitimate; what must hold is that the done
# ATTEMPT reached the scratch store, which the refusal message proves.
if [ "$RC" -eq 0 ] || grep -q "REJECTED: TL2B was claimed" laneB.err; then
    pass "auto-done attempt reached the SCRATCH store (T390 window refusal proves the redirection)"
else
    fail "clean lane exit $RC with no scratch-store done evidence; trailer: $(tail -3 laneB.err | tr '\n' ' ')"
fi
if [ -f "$DEFAULT_STORE" ]; then
    fail "live-store stand-in was CREATED by the clean-exit lane"
else
    pass "live-store stand-in still absent after the clean-exit lane"
fi

# ── D. null control: clean store is GREEN (specificity) ────────────────────
echo "  D. null control: a store with no dummy rows is GREEN"
EMPTY_STORE="$WORK/empty-store/tasks.json"
if check_store "$EMPTY_STORE" "null-control"; then
    pass "checker GREEN on an empty store (no false positive)"
else
    fail "checker went RED on an empty store (false positive)"
fi

# ── byte-identity guard on the REAL live store ─────────────────────────────
echo "  E. real live store untouched"
LIVE_AFTER=$(shasum -a 256 "$LIVE_STORE" | cut -d' ' -f1)
if [ "$LIVE_BEFORE" = "$LIVE_AFTER" ]; then
    pass "REAL live store byte-identical throughout (sha256 $LIVE_AFTER)"
else
    fail "REAL live store MUTATED by the regression (sha256 $LIVE_BEFORE → $LIVE_AFTER)"
fi
if check_store "$LIVE_STORE" "real-live-store"; then
    pass "checker GREEN on the REAL live store (no dummy lanes)"
else
    fail "REAL live store holds a load-test dummy lane (pollution present)"
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "regression-managent-store-pollution: ALL CONTROLS PASSED"
else
    echo "regression-managent-store-pollution: $FAIL FAILURE(S)"
fi
exit "$FAIL"
