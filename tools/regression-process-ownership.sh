#!/usr/bin/env bash
# regression-process-ownership.sh — pass-1 acceptance controls for `managent treekill`
# (docs/infra/orcha-refactor/pass1/03-test.md — the authoritative arm list; 01-spec.md §5).
#
# Written BEFORE the verb exists (test-first, red-first — 03-test.md §5):
#
#   N1  null: never-existed anchor (2^31-1)      — exit 0, claimed=0 root=dead, one stdout line
#   N2  null: tree B survives A's --kill          — B alive+unstopped, B's row untouched (OWN-3)
#   N3  null: read-only is inert                  — full report, nothing signaled/stopped (G2)
#   N4  null: two concurrent --kill runs          — both exit 0, no double-kill report
#   N5  null: unreadable --ps-fixture             — exit 3 with a named reason (never a bare
#                                                   exit-0 empty-set report)
#   S1  seeded: live-root kill of the deep tree   — all target pids dead, caller chain alive,
#                                                   zero collateral scoped to target ∪ {R}, OWN-5
#   S2  seeded: dead session-leader root          — reparented (ppid 1) members dead, no live
#                                                   sid==anchor pid in the final scan (OWN-2)
#   S3  seeded: nested-session orphan (r3)        — without --seed: exit 5, survivor counted;
#                                                   with --seed: exit 0, zero survivors
#   S4  seeded: fork race under freeze            — 20 iterations, zero survivors each, wall bounded
#   S5  guards: anchor 1 / $PPID / root-owned;    — exit 4; other-uid member refused via
#       other-uid member (sudo, skip-loudly)        PRE-FILTER (D-34), bystander unstopped
#   S6  differential oracle                       — Zig closure == runner's _descendant_pids_ps
#                                                   on a churn-free tree (equality tree; D-27)
#   S7  --ps-fixture (sid column, D-37)           — G4 since-floor exclusion, G9 kill+fixture=2,
#                                                   stream split both directions, sid edge in fixture
#   S8  protected set + rollback                  — fabricated other-row run record inside the
#                                                   closure: exit 4, names the task, all running after
#   S9  kill-parity (B-3 retry)                   — odd pids survive the SIGKILL, even pids die:
#                                                   full --rounds budget spent, killed= honest across
#                                                   rounds (N4), exit 5 with real survivors
#   I1  integration, normal exit                  — real tools/runner, backgrounded sleeper:
#                                                   FAILS RED today (nothing after runner:1587 reaps)
#   I2  integration, ceiling                      — real tools/runner, low --rss-cap-mb, a
#                                                   session-ESCAPING tree (D-7): FAILS RED today
#                                                   (killpg at runner:1554 cannot reach the escapee)
#   I3  integration, exception path               — real tools/runner raises (RUNNER_TEST_RAISE),
#                                                   backgrounded sleeper reaped before the raise (C3)
#   M1-M4 instrument-mutation controls            — freeze-off⇒S4 fails, since-off⇒S7 fails,
#                                                   protect-off⇒S8 fails, rollback-off⇒S8's
#                                                   running-again clause fails
#
# Skip/red policy (03-test.md §0, §5): every arm that calls the verb SKIPs loudly while
# `managent treekill` is absent; I1/I2/I3 test the CURRENT runner and run regardless — they
# fail red until the verb lands and C1/C2/C3 are wired.  Exit 0 only when nothing failed.
#
# Contracts this test-first script FIXES for the build phase (they are the spec of record
# until 01-spec.md §5 is amended):
#   * --ps-fixture format, one process per line, whitespace-separated, sid column mandatory
#     (D-37):   pid ppid pgid sid start_epoch rss_kb comm
#   * instrument-mutation hook: env MANAGENT_OWN_MUTATE ∈ {freeze-off, since-off,
#     protect-off, rollback-off, kill-parity}; when active the verb MUST announce
#     "[treekill] MUTATION ACTIVE: <mode>" on stderr (so a control can prove the hook was
#     honored); unset env ⇒ production behaviour, byte-identical.
#   * stream split (checked structurally on EVERY verb call): stdout carries only data
#     records + the `treekill ...` summary line; stderr carries only diagnostics — no summary,
#     no tab-separated records.
#
# Scratch under /tmp/weizigo — the live kanban, live untracked/ and the live repo are never
# touched (D-26).  Binary resolution: $MANAGENT_BIN → zig-out/bin/managent → bin/managent,
# same convention as regression-orphan-reaper.sh.
#
# Acceptance also includes ONE HAND-TRACED end-to-end audit of a single reap (pid from spawn
# to death) — a human step, printed as a NOTE at the end; this script cannot discharge it.
#
# Task: pass-1 T556 lineage · Role: worker · Date: 2026-08-21

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
RUNNER="$PROJECT/tools/runner"
FAIL=0
LEFTOVERS=""

# ── per-arm denominators, fixed here, never left to the runner (03-test.md §0) ──
TREE_PIDS=14          # gen_tree.py: harness+toolshell+runner+command+5 sleepers+5 grands
TREE_TARGET=11        # command + 5 sleepers + 5 grands (the anchored subtree)
TREE_WAIT_STEPS=50    # x0.2s = 10s manifest-completeness timeout
REPARENT_STEPS=50     # x0.1s = 5s reparent-to-init wait (S2)
SETTLE_S=1            # post-verb settle before the independent ps oracle reads
OWN_ROUNDS=5          # passed explicitly on every kill call
OWN_SETTLE_MS=250     # passed explicitly on every kill call
S4_ITERS=20           # race iterations (a single pass proves nothing about a race)
S4_WARMUP_S=0.5       # racer chains a sleeper every ~5ms (fixed inside racer.py) — ~250 kids
S4_WALL_CAP_S=180     # whole-arm wall bound (G10 / D-39: the test fixes a wall)
M1_ITERS=10           # freeze-off control: rounds needed to show the race is real
NEVER_PID=2147483647  # 2^31-1, N1's never-existed anchor
FIX_SINCE=2000000000  # S7 fixture --since floor (epoch)

cleanup() {
    # SIGCONT first (a refused-rollback control may leave stopped pids), then kill
    # everything whose argv carries the scratch path, then explicit leftovers.
    if [ -n "${WORK:-}" ]; then
        pkill -CONT -f "$WORK" 2>/dev/null
        pkill -9 -f "$WORK" 2>/dev/null
    fi
    if [ -n "$LEFTOVERS" ]; then
        for p in $LEFTOVERS; do
            kill -CONT "$p" 2>/dev/null
            kill -9 "$p" 2>/dev/null
            kill -9 -- "-$p" 2>/dev/null
            wait "$p" 2>/dev/null
        done
    fi
    # other-uid members (S5) cannot be killed by us — best-effort via sudo -n
    if [ -f "${WORK:-/nonexistent}/sudo.pids" ]; then
        while read -r sp; do sudo -n kill -9 "$sp" 2>/dev/null; done < "$WORK/sudo.pids"
    fi
    [ -n "${WORK:-}" ] && rm -rf "$WORK"
}
trap cleanup EXIT

mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/own-regression-XXXXXX)" || { echo "regression-process-ownership.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
cd "$WORK"
git init -q
git config user.email own-regression@test
git config user.name OWNREG
echo base > README.md
mkdir -p docs untracked untracked/runs docs/infra/managent
printf 'untracked/\n' > .gitignore
git add README.md .gitignore
git commit -qm base

STORE="$WORK/docs/infra/managent/tasks.json"
export MANAGENT_STORE="$STORE"
export MARKER="$WORK"   # every planted process carries $WORK in its argv (scoped ps oracle)

# rows for G6's protected set: run records are written per-arm; a row with no record
# contributes nothing until its record lands (N2 uses TROWB, S8 TPROT, M3/M4 TPROT2/3).
cat > "$STORE" <<'JSONEOF'
{
  "TROWB":  {"status":"in_progress","agent":"test","model":"test","bundle":"untracked/own.md","set":"G","holds":[],"needs":[],"caps":[],"added":"2026-08-21T00:00:00Z","claimed":"2026-08-21T00:00:00Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"claim_count":1},
  "TPROT":  {"status":"in_progress","agent":"test","model":"test","bundle":"untracked/own.md","set":"G","holds":[],"needs":[],"caps":[],"added":"2026-08-21T00:00:00Z","claimed":"2026-08-21T00:00:00Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"claim_count":1},
  "TPROT2": {"status":"in_progress","agent":"test","model":"test","bundle":"untracked/own.md","set":"G","holds":[],"needs":[],"caps":[],"added":"2026-08-21T00:00:00Z","claimed":"2026-08-21T00:00:00Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"claim_count":1},
  "TPROT3": {"status":"in_progress","agent":"test","model":"test","bundle":"untracked/own.md","set":"G","holds":[],"needs":[],"caps":[],"added":"2026-08-21T00:00:00Z","claimed":"2026-08-21T00:00:00Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"claim_count":1},
  "_sys": {"next_id": 9000, "directive_next": 1}
}
JSONEOF

# ── managent binary resolution (regression-orphan-reaper.sh:91-101 convention) ──
MG="${MANAGENT_BIN:-}"
if [ -z "$MG" ]; then
    if [ -x "$PROJECT/zig-out/bin/managent" ]; then
        MG="$PROJECT/zig-out/bin/managent"
    elif [ -x "$PROJECT/bin/managent" ]; then
        MG="$PROJECT/bin/managent"
    fi
fi
HAVE_OWN=0
if [ -n "$MG" ] && "$MG" help 2>&1 | grep -q "managent treekill"; then
    HAVE_OWN=1
fi
if [ "$HAVE_OWN" -eq 0 ]; then
    echo "NOTE: managent binary does not carry the treekill verb (${MG:-no binary}) — arms"
    echo "      N1-N5 S1-S8 and the mutation controls M1-M4 SKIP loudly (D-13); the"
    echo "      integration arms I1/I2/I3 test the CURRENT runner and run — RED until C1/C2/C3 land."
fi
[ -x "$RUNNER" ] || { echo "FATAL: $RUNNER missing — I1/I2 cannot run" >&2; exit 2; }

# ── tree generator: the production shape (01-spec §3, 03-test S1) ────────────────
# harness → toolshell (setsid, session boundary 1 — the console harness setsids each
# tool command) → runner → command (setsid, session boundary 2 — tools/runner:1210)
# → 5 sleepers → 5 grands.  14 pids, 6 levels.  Each notes "role pid sid ppid".
cat > "$WORK/gen_tree.py" <<'PYEOF'
import os, sys, time
MAN = sys.argv[1]
def note(role):
    with open(MAN, "a") as f:
        f.write("%s %d %d %d\n" % (role, os.getpid(), os.getsid(0), os.getppid()))
def park():
    time.sleep(600)
    os._exit(0)
if "--setsid-root" in sys.argv[2:]:
    os.setsid()
note("harness")
if os.fork() == 0:
    os.setsid()                      # session boundary 1
    note("toolshell")
    if os.fork() == 0:
        note("runner")
        if os.fork() == 0:
            os.setsid()              # session boundary 2 (tools/runner:1210 analogue)
            note("command")
            for i in range(5):
                if os.fork() == 0:
                    note("sleeper%d" % i)
                    if os.fork() == 0:
                        note("grand%d" % i)
                        park()
                    park()
            park()
        park()
    park()
park()
PYEOF

# racer for S4/M1: forks a short sleeper chain (depth 2 -> 3 pids per event)
# every 5 ms (fixed here) forever.  Fast enough that WITHOUT the freeze the
# verb's closure loop cannot converge: each closure round re-reads the proc
# table every ~15-30 ms, and a fresh chain lands inside every such window, so
# closeOwnership grows every round and the verb exits 5 (survivors) instead of
# converging.  WITH the freeze the racer is SIGSTOP'd in round 1, so the tree
# is capped at the warmup's ~250 pids and the reap still converges to zero
# survivors.  Keep the warmup (S4_WARMUP_S) small: the round-2 freeze costs
# one `ps -o state=` probe (~2 ms) per warmup pid.
cat > "$WORK/racer.py" <<'PYEOF'
import os, sys, time
MAN = sys.argv[1]
def note():
    with open(MAN, "a") as f:
        f.write("%d\n" % os.getpid())
def chain(depth):
    note()
    if depth > 0:
        if os.fork() == 0:
            chain(depth - 1)
    time.sleep(60)
    os._exit(0)
note()
while True:
    if os.fork() == 0:
        chain(2)
    time.sleep(0.005)
PYEOF

# S5 small tree: harness → {other-uid member via sudo, same-uid python sleeper}.
cat > "$WORK/gen_s5.py" <<'PYEOF'
import os, sys, time, subprocess
MAN, SUDOF, WORK = sys.argv[1], sys.argv[2], sys.argv[3]
def note(role, pid):
    with open(MAN, "a") as f:
        f.write("%s %d\n" % (role, pid))
note("harness", os.getpid())
same = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(600)", WORK + "/s5-same"])
note("same", same.pid)
if SUDOF == "1":
    other = subprocess.Popen(["sudo", "-n", "sleep", "600"])
    note("sudo", other.pid)
    with open(WORK + "/sudo.pids", "a") as f:
        f.write("%d\n" % other.pid)
time.sleep(600)
PYEOF

# I1's backgrounded sleeper and I2's session-ESCAPING tree (D-7: without the setsid the
# escaper would sit in the runner child's pgid and killpg would reach it — I2 would pass
# today by accident; the escaping shape is required).
cat > "$WORK/bg_sleeper.py" <<'PYEOF'
import time
time.sleep(600)
PYEOF
cat > "$WORK/escape_tree.py" <<'PYEOF'
import os, time
os.setsid()                          # escape the runner child's session AND pgid
if os.fork() == 0:
    time.sleep(600)
    os._exit(0)
time.sleep(600)
PYEOF

# ── helpers ──────────────────────────────────────────────────────────────────────
spawn_tree() {  # spawn_tree <name> [--setsid-root]  → manifest $WORK/<name>.man
    local name=$1; shift
    local man="$WORK/$name.man"
    : > "$man"
    python3 "$WORK/gen_tree.py" "$man" "$@" >/dev/null 2>&1 &
    LEFTOVERS="$LEFTOVERS $!"
    local i=0
    while [ "$(wc -l < "$man" | tr -d ' ')" -lt "$TREE_PIDS" ]; do
        sleep 0.2
        i=$((i+1))
        if [ "$i" -ge "$TREE_WAIT_STEPS" ]; then
            echo "    FATAL: tree $name incomplete ($(wc -l < "$man") / $TREE_PIDS pids)" >&2
            return 1
        fi
    done
    return 0
}
tree_pid()          { awk -v r="$2" '$1==r{print $2}' "$1"; }
tree_target_pids()  { awk '$1=="command"||$1~/^sleeper/||$1~/^grand/{print $2}' "$1"; }
tree_chain_pids()   { awk '$1=="harness"||$1=="toolshell"||$1=="runner"{print $2}' "$1"; }
tree_sub_pids()     { awk '$1~/^sleeper/||$1~/^grand/{print $2}' "$1"; }  # below the command node

pid_state() { ps -o state= -p "$1" 2>/dev/null | head -1 | cut -c1; }
sid_of() {
    python3 -c 'import os,sys
try: print(os.getsid(int(sys.argv[1])))
except Exception: print(-1)' "$1"
}
live_marker_pids() {  # every live pid whose argv carries the scratch path ($MARKER, exported)
    ps -axo pid=,command= | awk 'index($0, ENVIRON["MARKER"]) {print $1}'
}

assert_all_dead() {  # <label> <pid...> — zombie-aware: a 'Z' (defunct) pid IS dead
    local lbl=$1; shift
    local live=""
    for p in "$@"; do
        local st
        st=$(pid_state "$p")
        # gone (empty state) or a zombie (Z) are both dead; anything else is alive
        if [ -n "$st" ] && [ "$st" != "Z" ]; then live="$live $p(state=$st)"; fi
    done
    if [ -n "$live" ]; then
        echo "    FAIL($lbl): still alive:$live"
        FAIL=1
        return 1
    fi
    return 0
}
assert_all_alive_unstopped() {  # <label> <pid...>
    local lbl=$1; shift
    local bad=""
    for p in "$@"; do
        if ! kill -0 "$p" 2>/dev/null; then bad="$bad $p(dead)"
        elif [ "$(pid_state "$p")" = "T" ]; then bad="$bad $p(stopped)"; fi
    done
    if [ -n "$bad" ]; then
        echo "    FAIL($lbl): not alive+running:$bad"
        FAIL=1
        return 1
    fi
    return 0
}

# run_treekill <tag> <verb-args...> — captures streams separately and enforces the stream
# split on EVERY call (03-test §0: every arm checks it at least once): stdout never
# carries [treekill] diagnostics; stderr never carries the summary or a data record.
OWN_OUT="" OWN_ERR=""
MUTATE=""
run_treekill() {
    local tag=$1; shift
    OWN_OUT="$WORK/treekill-$tag.out"; OWN_ERR="$WORK/treekill-$tag.err"
    if [ -n "$MUTATE" ]; then
        MANAGENT_OWN_MUTATE="$MUTATE" "$MG" treekill "$@" >"$OWN_OUT" 2>"$OWN_ERR"
    else
        "$MG" treekill "$@" >"$OWN_OUT" 2>"$OWN_ERR"
    fi
    local rc=$?
    if grep -q '^\[own\]' "$OWN_OUT" 2>/dev/null; then
        echo "    FAIL($tag): stdout carries [treekill] diagnostics (stream split)"
        FAIL=1
    fi
    if grep -Eq $'^treekill |\t.*\t.*\t.*\t.*\t.*\t' "$OWN_ERR" 2>/dev/null; then
        echo "    FAIL($tag): stderr carries data (summary or record — stream split)"
        FAIL=1
    fi
    return $rc
}
sum_field() {  # <outfile> <key> → value from the final `treekill ...` summary line
    grep '^treekill ' "$1" 2>/dev/null | tail -1 | grep -o "$2=[^ ]*" | head -1 | cut -d= -f2
}
data_pids() {  # claimed-record pids (col 1 of the 8-field tab records)
    awk -F'\t' 'NF>=8 {print $1}' "$1" 2>/dev/null
}
action_pids() {  # <outfile> <action> → pids whose record carries that action
    awk -F'\t' -v a="$2" 'NF>=8 && $7==a {print $1}' "$1" 2>/dev/null
}

echo "=== regression-process-ownership ==="

# a canary sleeper, planted once: N1's "ps unchanged" oracle and a standing bystander.
python3 -c 'import time; time.sleep(600)' "$WORK/canary" >/dev/null 2>&1 &
CANARY=$!
LEFTOVERS="$LEFTOVERS $CANARY"

if [ "$HAVE_OWN" -eq 1 ]; then

# ── N1: never-existed anchor ─────────────────────────────────────────────────────
echo "  N1. null: anchor $NEVER_PID never existed — exit 0, claimed=0 root=dead, one line, ps unchanged"
run_treekill n1 --anchor "$NEVER_PID"
RC=$?
LINES=$(wc -l < "$OWN_OUT" | tr -d ' ')
if [ "$RC" -eq 0 ] && [ "$LINES" -eq 1 ] && \
   grep -Eq "^treekill anchor=$NEVER_PID root=dead claimed=0 " "$OWN_OUT"; then
    echo "    PASS: exit 0, exactly one parseable summary line"
else
    echo "    FAIL: rc=$RC lines=$LINES summary: $(cat "$OWN_OUT" 2>/dev/null)"
    FAIL=1
fi
assert_all_alive_unstopped "N1 canary" "$CANARY" && echo "    PASS: bystander canary untouched (ps unchanged, scoped)"

# ── trees A and B: N3 (read-only), then S1's kill with N2's survivor watching ────
echo "  N3. null: read-only invocation on the live tree is inert (G2)"
spawn_tree treeA || FAIL=1
spawn_tree treeB --setsid-root || FAIL=1     # B: its own session (03-test N2)
A_CMD=$(tree_pid "$WORK/treeA.man" command)
B_ROOT=$(tree_pid "$WORK/treeB.man" harness)
# N2's fabricated backing: TROWB's run record points at B's root (D-26: not a live
# worker — a fabricated record for another in-progress row, per the scratch rule).
cat > untracked/runs/TROWB.json <<EOF
{"command": "gen_tree.py treeB", "launcher_pid": 1, "pgid": $B_ROOT, "pid": $B_ROOT, "start": "2026-08-21T00:00:00Z", "task": "TROWB"}
EOF
run_treekill n3 --anchor "$A_CMD"
RC=$?
NREC=$(data_pids "$OWN_OUT" | wc -l | tr -d ' ')
sleep "$SETTLE_S"
if [ "$RC" -eq 0 ] && [ "$NREC" -ge $((TREE_TARGET - 1)) ]; then
    echo "    PASS: full report ($NREC records), exit 0"
else
    echo "    FAIL: rc=$RC records=$NREC (expected >= $((TREE_TARGET - 1)))"
    FAIL=1
fi
# shellcheck disable=SC2046
assert_all_alive_unstopped "N3 inert" $(awk '{print $2}' "$WORK/treeA.man") && \
    echo "    PASS: nothing signaled, nothing stopped afterwards"

echo "  S1. seeded: --kill the live-root tree (anchor = the command node, D-28 named)"
BEFORE=$(live_marker_pids | sort)   # lexical: comm(1) input order
run_treekill s1 --anchor "$A_CMD" --kill --rounds "$OWN_ROUNDS" --settle-ms "$OWN_SETTLE_MS"
RC=$?
sleep "$SETTLE_S"
AFTER=$(live_marker_pids | sort)
if [ "$RC" -eq 0 ]; then
    echo "    PASS: exit 0"
else
    echo "    FAIL: exit $RC"
    FAIL=1
fi
# shellcheck disable=SC2046
assert_all_dead "S1 target" $(tree_target_pids "$WORK/treeA.man") && \
    echo "    PASS: every target pid dead by the independent ps oracle"
# shellcheck disable=SC2046
assert_all_alive_unstopped "S1 caller chain" $(tree_chain_pids "$WORK/treeA.man") && \
    echo "    PASS: caller chain (harness/toolshell/runner) alive"
# zero collateral, scoped to target ∪ {R} (D-8/D-29): the marker-scoped ps diff —
# every planted pid that died must be a target-tree member.
NEWLY_DEAD=$(comm -23 <(echo "$BEFORE") <(echo "$AFTER"))
COLLATERAL=""
for p in $NEWLY_DEAD; do
    tree_target_pids "$WORK/treeA.man" | grep -qx "$p" || COLLATERAL="$COLLATERAL $p"
done
if [ -z "$COLLATERAL" ]; then
    echo "    PASS: zero collateral in the scoped ps diff"
else
    echo "    FAIL: collateral deaths outside target ∪ {R}:$COLLATERAL"
    FAIL=1
fi
# verb counters vs the oracle (never the counters alone — 01-spec §1)
CLAIMED=$(sum_field "$OWN_OUT" claimed); SURV=$(sum_field "$OWN_OUT" survivors)
NREC=$(data_pids "$OWN_OUT" | wc -l | tr -d ' ')
if [ "${SURV:-x}" = "0" ] && [ "${CLAIMED:-0}" -ge $((TREE_TARGET - 1)) ] && [ "$NREC" -eq "${CLAIMED:-0}" ]; then
    echo "    PASS: counters agree with the oracle (claimed=$CLAIMED survivors=0, records=$NREC)"
else
    echo "    FAIL: counters disagree: claimed=${CLAIMED:-?} survivors=${SURV:-?} records=$NREC"
    FAIL=1
fi
# OWN-5: post-settle recompute — no target-subtree pid reappeared
LIVE_A=$(live_marker_pids | while read -r p; do tree_target_pids "$WORK/treeA.man" | grep -qx "$p" && echo "$p"; done)
if [ -z "$LIVE_A" ]; then
    echo "    PASS: OWN-5 — fresh scan after settle finds zero target members"
else
    echo "    FAIL: OWN-5 — live after settle:$LIVE_A"
    FAIL=1
fi

echo "  N2. null: tree B (own session) survived A's --kill; B's row untouched (OWN-3 scoped)"
# shellcheck disable=SC2046
assert_all_alive_unstopped "N2 tree B" $(awk '{print $2}' "$WORK/treeB.man") && \
    echo "    PASS: every tree-B pid alive and unstopped (no T state)"
if python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if d["TROWB"]["status"]=="in_progress" else 1)' "$STORE"; then
    echo "    PASS: TROWB row untouched (in_progress)"
else
    echo "    FAIL: TROWB row was modified"
    FAIL=1
fi

# ── N4: two concurrent --kill runs on one tree ───────────────────────────────────
echo "  N4. null: two concurrent --kill runs — both exit 0, no double-kill report"
spawn_tree treeC || FAIL=1
C_CMD=$(tree_pid "$WORK/treeC.man" command)
"$MG" treekill --anchor "$C_CMD" --kill --rounds "$OWN_ROUNDS" --settle-ms "$OWN_SETTLE_MS" \
    > "$WORK/treekill-n4a.out" 2> "$WORK/treekill-n4a.err" &
P1=$!
"$MG" treekill --anchor "$C_CMD" --kill --rounds "$OWN_ROUNDS" --settle-ms "$OWN_SETTLE_MS" \
    > "$WORK/treekill-n4b.out" 2> "$WORK/treekill-n4b.err" &
P2=$!
wait "$P1"; RC1=$?
wait "$P2"; RC2=$?
if [ "$RC1" -eq 0 ] && [ "$RC2" -eq 0 ]; then
    echo "    PASS: both concurrent runs exit 0"
else
    echo "    FAIL: exits $RC1 / $RC2"
    FAIL=1
fi
DOUBLE=$(comm -12 <(action_pids "$WORK/treekill-n4a.out" killed | sort) \
                  <(action_pids "$WORK/treekill-n4b.out" killed | sort))
if [ -z "$DOUBLE" ]; then
    echo "    PASS: no pid reported killed by both runs"
else
    echo "    FAIL: double-kill report for:$DOUBLE"
    FAIL=1
fi
sleep "$SETTLE_S"
# shellcheck disable=SC2046
assert_all_dead "N4 target" $(tree_target_pids "$WORK/treeC.man")

# ── N5: unreadable --ps-fixture ⇒ exit 3 (never a bare exit-0 empty-set report) ──
echo "  N5. null: unreadable --ps-fixture → exit 3 with a named reason"
run_treekill n5 --anchor "$NEVER_PID" --ps-fixture "$WORK/no-such-fixture.ps"
RC=$?
if [ "$RC" -eq 3 ] && grep -q "cannot read ps fixture" "$OWN_ERR"; then
    echo "    PASS: exit 3, diagnostic names the unreadable fixture"
else
    echo "    FAIL: rc=$RC (expected 3); stderr: $(cat "$OWN_ERR" 2>/dev/null)"
    FAIL=1
fi

# ── S2: dead session-leader root (the measured leak shape) ───────────────────────
echo "  S2. seeded: SIGKILL the anchor, wait for reparent to ppid 1, then treekill --anchor (OWN-2/D-28)"
spawn_tree treeD || FAIL=1
D_CMD=$(tree_pid "$WORK/treeD.man" command)
D_SLEEP0=$(tree_pid "$WORK/treeD.man" sleeper0)
kill -9 "$D_CMD"
i=0; REPARENTED=0
while [ "$i" -lt "$REPARENT_STEPS" ]; do
    PP=$(ps -o ppid= -p "$D_SLEEP0" 2>/dev/null | tr -d ' ')
    [ "$PP" = "1" ] && { REPARENTED=1; break; }
    sleep 0.1
    i=$((i+1))
done
if [ "$REPARENTED" -eq 1 ]; then
    echo "    PASS: members reparented to ppid 1 (the measured leak shape asserted)"
else
    echo "    FAIL: sleeper0 never reparented to init (ppid=${PP:-gone})"
    FAIL=1
fi
run_treekill s2 --anchor "$D_CMD" --kill --rounds "$OWN_ROUNDS" --settle-ms "$OWN_SETTLE_MS"
RC=$?
sleep "$SETTLE_S"
if [ "$RC" -eq 0 ]; then
    echo "    PASS: exit 0 on the dead-root anchor"
else
    echo "    FAIL: exit $RC"
    FAIL=1
fi
# shellcheck disable=SC2046
assert_all_dead "S2 reparented members" $(tree_sub_pids "$WORK/treeD.man") && \
    echo "    PASS: reparented members dead"
SIDLIVE=""
for p in $(live_marker_pids); do
    [ "$(sid_of "$p")" = "$D_CMD" ] && SIDLIVE="$SIDLIVE $p"
done
if [ -z "$SIDLIVE" ]; then
    echo "    PASS: no live pid with sid == anchor in the final scan"
else
    echo "    FAIL: live sid==anchor pids remain:$SIDLIVE"
    FAIL=1
fi

# ── S3: nested-session orphan — the r3 residue, with and without --seed ─────────
echo "  S3. seeded: nested session orphaned (r3) — without --seed verb exit 0 + oracle; with --seed exit 0"
spawn_tree treeE || FAIL=1
E_TOOL=$(tree_pid "$WORK/treeE.man" toolshell)
E_RUNNER=$(tree_pid "$WORK/treeE.man" runner)
E_CMD=$(tree_pid "$WORK/treeE.man" command)
SEED=$(tree_sub_pids "$WORK/treeE.man" | paste -sd, -)   # the pre-death walk (runner:1402 analogue)
# sever every edge: the intermediate session leader (command) AND its parent die together
kill -9 "$E_RUNNER" "$E_CMD"
sleep "$SETTLE_S"
run_treekill s3a --anchor "$E_TOOL" --kill --rounds "$OWN_ROUNDS" --settle-ms "$OWN_SETTLE_MS"
RC=$?
if [ "$RC" -eq 0 ]; then
    echo "    PASS: without --seed verb exit 0 (claims nothing — orphan invisible to the seedless closure); oracle below detects the r3 survivor"
else
    echo "    FAIL: without --seed rc=$RC (expected 0): $(grep '^treekill ' "$OWN_OUT" 2>/dev/null)"
    FAIL=1
fi
SUBLIVE=0
for p in $(tree_sub_pids "$WORK/treeE.man"); do kill -0 "$p" 2>/dev/null && SUBLIVE=$((SUBLIVE+1)); done
if [ "$SUBLIVE" -ge 1 ]; then
    echo "    PASS: oracle confirms the orphaned session survived the seedless call ($SUBLIVE live)"
else
    echo "    FAIL: seedless call reached the orphaned session (r3 not reproduced)"
    FAIL=1
fi
run_treekill s3b --anchor "$E_TOOL" --kill --seed "$SEED" --rounds "$OWN_ROUNDS" --settle-ms "$OWN_SETTLE_MS"
RC=$?
sleep "$SETTLE_S"
# shellcheck disable=SC2046
if [ "$RC" -eq 0 ] && assert_all_dead "S3 seeded" $(tree_sub_pids "$WORK/treeE.man"); then
    echo "    PASS: with --seed from the pre-death walk: exit 0, zero survivors"
else
    echo "    FAIL: with --seed rc=$RC or survivors remain"
    FAIL=1
fi

# ── S4: the fork race (freeze) ───────────────────────────────────────────────────
echo "  S4. seeded: spawner chains a sleeper every ~5ms during the reap — $S4_ITERS iterations"
S4_T0=$SECONDS
S4_BAD=0
i=1
while [ "$i" -le "$S4_ITERS" ]; do
    MANR="$WORK/racer-$i.man"
    : > "$MANR"
    python3 "$WORK/racer.py" "$MANR" >/dev/null 2>&1 &
    RACER=$!
    LEFTOVERS="$LEFTOVERS $RACER"
    sleep "$S4_WARMUP_S"
    run_treekill "s4-$i" --anchor "$RACER" --kill --rounds "$OWN_ROUNDS" --settle-ms "$OWN_SETTLE_MS"
    RC=$?
    sleep 0.3
    SURVIVE=$(ps -axo pid=,command= | grep -F "racer-$i.man" | grep -v grep | awk '{print $1}' | tr '\n' ' ')
    if [ "$RC" -ne 0 ] || [ -n "$SURVIVE" ]; then
        echo "    FAIL: iteration $i rc=$RC survivors:${SURVIVE:-none}"
        S4_BAD=1
        for p in $SURVIVE; do kill -9 "$p" 2>/dev/null; done
    fi
    i=$((i+1))
done
S4_WALL=$((SECONDS - S4_T0))
if [ "$S4_BAD" -eq 0 ]; then
    echo "    PASS: zero survivors in every one of the $S4_ITERS iterations"
else
    FAIL=1
fi
if [ "$S4_WALL" -le "$S4_WALL_CAP_S" ]; then
    echo "    PASS: wall bounded (${S4_WALL}s <= ${S4_WALL_CAP_S}s)"
else
    echo "    FAIL: wall ${S4_WALL}s exceeds the ${S4_WALL_CAP_S}s bound (G10/D-39)"
    FAIL=1
fi

# ── S5: guards — refused anchors and the other-uid member ────────────────────────
echo "  S5. guards: --anchor 1 / --anchor \$PPID / root-owned anchor all exit 4; nothing dies"
run_treekill s5-init --anchor 1 --kill --rounds "$OWN_ROUNDS" --settle-ms "$OWN_SETTLE_MS"
RC1=$?
run_treekill s5-ppid --anchor "$PPID" --kill --rounds "$OWN_ROUNDS" --settle-ms "$OWN_SETTLE_MS"
RC2=$?
ROOTPID=$(ps -axo pid=,uid= | awk '$2==0 && $1>1 {print $1; exit}')
RC3=4
if [ -n "$ROOTPID" ]; then
    run_treekill s5-root --anchor "$ROOTPID" --kill --rounds "$OWN_ROUNDS" --settle-ms "$OWN_SETTLE_MS"
    RC3=$?
else
    echo "    SKIP: no root-owned pid found to aim at (unexpected on macOS)"
fi
if [ "$RC1" -eq 4 ] && [ "$RC2" -eq 4 ] && [ "$RC3" -eq 4 ]; then
    echo "    PASS: pid 1, ancestor, and root-owned anchors all refused (exit 4, G1/G3)"
else
    echo "    FAIL: refused-anchor exits: pid1=$RC1 ppid=$RC2 root=$RC3 (all must be 4)"
    FAIL=1
fi
kill -0 1 2>/dev/null || true   # pid 1 is unkillable by us regardless; assert nothing of ours died
assert_all_alive_unstopped "S5 canary" "$CANARY"
# kill -0 cannot probe a root-owned pid from this euid (EPERM even when the
# process is alive), so liveness is asserted via ps state — the pid_state
# probe used by every other arm — not by signaling permission.
S5_ROOT_ST=$(pid_state "$ROOTPID")
if [ -n "$ROOTPID" ] && { [ -z "$S5_ROOT_ST" ] || [ "$S5_ROOT_ST" = "Z" ]; }; then
    echo "    FAIL: the root-owned target pid $ROOTPID died (state=${S5_ROOT_ST:-gone})"
    FAIL=1
fi

echo "  S5. guards: other-uid member inside the closure — refused via PRE-FILTER (D-34, G8)"
if sudo -n true 2>/dev/null; then
    : > "$WORK/s5.man"
    python3 "$WORK/gen_s5.py" "$WORK/s5.man" 1 "$WORK" >/dev/null 2>&1 &
    S5H=$!
    LEFTOVERS="$LEFTOVERS $S5H"
    i=0
    while [ "$(wc -l < "$WORK/s5.man" | tr -d ' ')" -lt 3 ] && [ "$i" -lt "$TREE_WAIT_STEPS" ]; do
        sleep 0.2; i=$((i+1))
    done
    SUDO_PID=$(tree_pid "$WORK/s5.man" sudo)
    SAME_PID=$(tree_pid "$WORK/s5.man" same)
    run_treekill s5-uid --anchor "$S5H" --kill --rounds "$OWN_ROUNDS" --settle-ms "$OWN_SETTLE_MS"
    RC=$?
    sleep "$SETTLE_S"
    REFUSED=$(sum_field "$OWN_OUT" refused)
    # exit-code note: 4 would mean whole-op refusal, which G8 rules out for a member;
    # 0-vs-5 (is a pre-filtered member a "survivor"?) is a D-40-adjacent design choice —
    # this arm pins the observables and accepts either non-refusal exit.
    if [ "$RC" -ne 4 ] && [ "${REFUSED:-0}" -ge 1 ]; then
        echo "    PASS: refused counted ($REFUSED) without whole-op refusal (rc=$RC)"
    else
        echo "    FAIL: rc=$RC refused=${REFUSED:-?} (member refusal must not abort the op)"
        FAIL=1
    fi
    if kill -0 "$SUDO_PID" 2>/dev/null && [ "$(pid_state "$SUDO_PID")" != "T" ]; then
        echo "    PASS: other-uid bystander alive and UNSTOPPED (pre-filter, not signal-and-observe)"
    else
        echo "    FAIL: other-uid bystander dead or stopped (state=$(pid_state "$SUDO_PID"))"
        FAIL=1
    fi
    assert_all_dead "S5 same-uid member" "$SAME_PID" && \
        echo "    PASS: the same-uid member died (the guard is scoped, not a blanket refusal)"
else
    echo "    SKIP: sudo -n unavailable — the other-uid arm cannot be seeded on this host (03-test S5)"
fi

# ── S6: differential oracle — Zig closure vs the runner's walker ─────────────────
echo "  S6. differential: Zig closure == runner _descendant_pids_ps on a churn-free tree (D-27)"
spawn_tree treeG || FAIL=1
G_CMD=$(tree_pid "$WORK/treeG.man" command)
run_treekill s6 --anchor "$G_CMD"
RC=$?
data_pids "$OWN_OUT" | sort -n > "$WORK/s6-zig.pids"
echo "$G_CMD" >> "$WORK/s6-zig.pids"        # normalize: both sides include the root
sort -n -u -o "$WORK/s6-zig.pids" "$WORK/s6-zig.pids"
python3 - "$RUNNER" "$G_CMD" > "$WORK/s6-py.pids" 2>"$WORK/s6-py.err" <<'PYEOF'
import importlib.machinery, importlib.util, sys
loader = importlib.machinery.SourceFileLoader("runner_mod", sys.argv[1])
spec = importlib.util.spec_from_loader("runner_mod", loader)
m = importlib.util.module_from_spec(spec)
loader.exec_module(m)
for p in sorted(m._descendant_pids_ps(int(sys.argv[2]))):
    print(p)
PYEOF
if [ $? -ne 0 ]; then
    echo "    FAIL: could not run the runner's walker as the oracle:"
    sed 's/^/      /' "$WORK/s6-py.err"
    FAIL=1
elif [ "$RC" -eq 0 ] && diff -q "$WORK/s6-zig.pids" "$WORK/s6-py.pids" >/dev/null; then
    echo "    PASS: identical pid sets ($(wc -l < "$WORK/s6-zig.pids" | tr -d ' ') pids) — mutual oracles"
else
    echo "    FAIL: rc=$RC; sets differ (OWN-1 is a superset only in general — this tree is built for equality):"
    diff "$WORK/s6-zig.pids" "$WORK/s6-py.pids" | sed 's/^/      /'
    FAIL=1
fi

# ── S7: --ps-fixture with the sid column (D-37) ──────────────────────────────────
echo "  S7. fixture: since-floor exclusion (G4), kill+fixture usage error (G9), stream split, sid edge"
FIX="$WORK/fixture.tbl"
# format fixed by this test (contract of record): pid ppid pgid sid start_epoch rss_kb comm
# 70000 = the (dead, absent) anchor; 70001 reachable ONLY via sid==anchor (the sid
# edge, exercised in fixture mode); 70002 via ppid; 70003 starts BELOW the floor.
cat > "$FIX" <<EOF
70001 1 70000 70000 2000000100 1024 sleeper-sid-edge
70002 70001 70000 70000 2000000200 1024 sleeper-ppid-edge
70003 1 70003 70000 1000000000 1024 sleeper-too-old
EOF
run_treekill s7 --anchor 70000 --since "$FIX_SINCE" --ps-fixture "$FIX"
RC=$?
CLAIMED=$(sum_field "$OWN_OUT" claimed)
if [ "$RC" -eq 0 ] && [ "${CLAIMED:-0}" -eq 2 ] && \
   data_pids "$OWN_OUT" | grep -qx 70001 && data_pids "$OWN_OUT" | grep -qx 70002 && \
   ! data_pids "$OWN_OUT" | grep -qx 70003; then
    echo "    PASS: sid-edge + ppid-edge members claimed, older-than-floor member excluded (G4)"
else
    echo "    FAIL: rc=$RC claimed=${CLAIMED:-?}; records: $(data_pids "$OWN_OUT" | tr '\n' ' ')"
    FAIL=1
fi
"$MG" treekill --anchor 70000 --kill --ps-fixture "$FIX" >/dev/null 2>&1
RC=$?
if [ "$RC" -eq 2 ]; then
    echo "    PASS: --kill --ps-fixture is a usage error (exit 2, G9)"
else
    echo "    FAIL: --kill --ps-fixture rc=$RC (expected 2)"
    FAIL=1
fi
# stream split, both directions, explicitly (03-test S7)
DATA=$("$MG" treekill --anchor 70000 --since "$FIX_SINCE" --ps-fixture "$FIX" 2>/dev/null)
"$MG" treekill --anchor 70000 --since "$FIX_SINCE" --ps-fixture "$FIX" 1>/dev/null 2>"$WORK/s7-erronly"
if [ -n "$DATA" ] && echo "$DATA" | grep -q '^treekill ' && \
   ! grep -Eq $'^treekill |\t' "$WORK/s7-erronly"; then
    echo "    PASS: 2>/dev/null still emits data; 1>/dev/null leaves no data on stderr"
else
    echo "    FAIL: stream split broken (data='$DATA' erronly='$(cat "$WORK/s7-erronly")')"
    FAIL=1
fi

# ── S8: protected set + rollback ─────────────────────────────────────────────────
echo "  S8. seeded: another row's fabricated run record inside the closure — refuse whole, roll back"
spawn_tree treeH || FAIL=1
H_CMD=$(tree_pid "$WORK/treeH.man" command)
H_PROT=$(tree_pid "$WORK/treeH.man" sleeper2)
cat > untracked/runs/TPROT.json <<EOF
{"command": "protected worker", "launcher_pid": 1, "pgid": $H_PROT, "pid": $H_PROT, "start": "2026-08-21T00:00:00Z", "task": "TPROT"}
EOF
run_treekill s8 --anchor "$H_CMD" --kill --rounds "$OWN_ROUNDS" --settle-ms "$OWN_SETTLE_MS"
RC=$?
sleep "$SETTLE_S"
if [ "$RC" -eq 4 ]; then
    echo "    PASS: exit 4 — whole operation refused (G5/G6)"
else
    echo "    FAIL: rc=$RC (expected 4)"
    FAIL=1
fi
if grep -q "TPROT" "$OWN_ERR"; then
    echo "    PASS: diagnostic names the owning task id (TPROT)"
else
    echo "    FAIL: stderr does not name TPROT: $(cat "$OWN_ERR")"
    FAIL=1
fi
# zero signals + rollback (G7): every tree pid alive AND running again (no T state)
# shellcheck disable=SC2046
assert_all_alive_unstopped "S8 rollback" $(awk '{print $2}' "$WORK/treeH.man") && \
    echo "    PASS: zero kills and every frozen pid running again (SIGCONT rollback)"
rm -f untracked/runs/TPROT.json   # do not protect tree H against later arms' scans

# ── S9: B-3 retry — a claimed member that outlives its SIGKILL (kill-parity) ──────
# The suite had NO arm forcing a SIGKILL survivor before this: S3's exit-5 is the
# seedless-closure orphan, S4 asserts ZERO survivors, M1's freeze-off produces
# closure-growth survivors.  So the retry path B-3 added (validate→kill→verify inside
# the --rounds loop) was unexercised — "ALL CONTROLS PASSED" verified the old
# behaviour, not the new feature (Opus B-3 review, 2026-08-21).  This arm closes that
# gap: kill-parity spares odd pids (marked killed, actually alive) and kills even pids,
# so the verb must spend the full budget retrying the odd survivors while keeping the
# even pids' killed= honest across rounds (N4 — never downgraded to vanished).
echo "  S9. seeded: kill-parity — survivors retried to the budget, killed= honest (B-3)"
spawn_tree treeI || FAIL=1
I_CMD=$(tree_pid "$WORK/treeI.man" command)
MUTATE=kill-parity
run_treekill s9 --anchor "$I_CMD" --kill --rounds 3 --settle-ms "$OWN_SETTLE_MS"
RC=$?
MUTATE=""
ROUNDS=$(sum_field "$OWN_OUT" rounds)
KILLED=$(sum_field "$OWN_OUT" killed)
SURV=$(sum_field "$OWN_OUT" survivors)
VANISHED=$(action_pids "$OWN_OUT" vanished | wc -l | tr -d ' ')
if [ "$RC" -eq 5 ] && [ "$ROUNDS" = "3" ] && [ "${SURV:-0}" -gt 0 ] && [ "${KILLED:-0}" -gt 0 ] && [ "$VANISHED" -eq 0 ]; then
    echo "    PASS: exit 5, rounds=3 budget spent, killed=$KILLED survivors=$SURV, zero downgraded to vanished"
else
    echo "    FAIL: rc=$RC rounds=${ROUNDS:-?} killed=${KILLED:-?} survivors=${SURV:-?} vanished=${VANISHED:-?}"
    FAIL=1
fi
# independent oracle: the odd (surviving) members must still be alive, the even members dead
SURV_PIDS=$(action_pids "$OWN_OUT" survived)
KILL_PIDS=$(action_pids "$OWN_OUT" killed)
# shellcheck disable=SC2086
assert_all_alive_unstopped "S9 survivors" $SURV_PIDS && \
    echo "    PASS: every reported survivor is genuinely alive (independent ps)"
# shellcheck disable=SC2086
assert_all_dead "S9 killed" $KILL_PIDS && \
    echo "    PASS: every reported killed pid is genuinely dead (independent ps)"
# clean up the survivors the mutation spared (they are real live pids)
pkill -9 -f "treeI.man" 2>/dev/null

# ── M1-M4: instrument-mutation controls (the arms that test the arms) ────────────
# Hook contract (fixed here, test-first): MANAGENT_OWN_MUTATE=<mode> disables exactly
# one mechanism and the verb announces "[treekill] MUTATION ACTIVE: <mode>" on stderr.
# An arm that cannot be made to fail by deleting the code it covers is decoration.
check_mutation_announced() {  # <errfile> <mode>
    if ! grep -q "MUTATION ACTIVE: $1" "$2" 2>/dev/null && ! grep -q "MUTATION ACTIVE: $1" "${OWN_ERR:-/dev/null}" 2>/dev/null; then
        echo "    FAIL: verb did not announce mutation '$1' — the control is decoration"
        FAIL=1
        return 1
    fi
    return 0
}

echo "  M1. mutation: freeze disabled ⇒ S4 must fail ($M1_ITERS race iterations)"
MUTATE="freeze-off"
M1_SURV=0
M1_ANNOUNCED=0
i=1
while [ "$i" -le "$M1_ITERS" ]; do
    MANR="$WORK/mut-racer-$i.man"
    : > "$MANR"
    python3 "$WORK/racer.py" "$MANR" >/dev/null 2>&1 &
    RACER=$!
    LEFTOVERS="$LEFTOVERS $RACER"
    sleep "$S4_WARMUP_S"
    run_treekill "m1-$i" --anchor "$RACER" --kill --rounds "$OWN_ROUNDS" --settle-ms "$OWN_SETTLE_MS"
    RC=$?
    grep -q "MUTATION ACTIVE: freeze-off" "$OWN_ERR" && M1_ANNOUNCED=1
    SURVIVE=$(ps -axo pid=,command= | grep -F "mut-racer-$i.man" | grep -v grep | awk '{print $1}' | tr '\n' ' ')
    [ "$RC" -eq 5 ] || [ -n "$SURVIVE" ] && M1_SURV=$((M1_SURV+1))
    for p in $SURVIVE; do kill -9 "$p" 2>/dev/null; done
    kill -9 "$RACER" 2>/dev/null
    i=$((i+1))
done
MUTATE=""
if [ "$M1_ANNOUNCED" -eq 0 ]; then
    echo "    FAIL: verb never announced freeze-off — the control is decoration"
    FAIL=1
elif [ "$M1_SURV" -ge 1 ]; then
    echo "    PASS: without the freeze the race leaked in $M1_SURV/$M1_ITERS iterations — S4 is sensitive"
else
    echo "    FAIL: freeze-off never produced a survivor in $M1_ITERS rounds — S4 cannot be failed (decoration)"
    FAIL=1
fi

echo "  M2. mutation: start-time filter disabled ⇒ S7 must fail"
MUTATE="since-off"
run_treekill m2 --anchor 70000 --since "$FIX_SINCE" --ps-fixture "$FIX"
MUTATE=""
if check_mutation_announced since-off "$OWN_ERR"; then
    if data_pids "$OWN_OUT" | grep -qx 70003; then
        echo "    PASS: with the floor gone the too-old member is claimed — S7 is sensitive"
    else
        echo "    FAIL: since-off did not admit the too-old member — S7 cannot be failed (decoration)"
        FAIL=1
    fi
fi

echo "  M3. mutation: protected-set check disabled ⇒ S8 must fail"
spawn_tree treeM3 || FAIL=1
M3_CMD=$(tree_pid "$WORK/treeM3.man" command)
M3_PROT=$(tree_pid "$WORK/treeM3.man" sleeper2)
cat > untracked/runs/TPROT2.json <<EOF
{"command": "protected worker", "launcher_pid": 1, "pgid": $M3_PROT, "pid": $M3_PROT, "start": "2026-08-21T00:00:00Z", "task": "TPROT2"}
EOF
MUTATE="protect-off"
run_treekill m3 --anchor "$M3_CMD" --kill --rounds "$OWN_ROUNDS" --settle-ms "$OWN_SETTLE_MS"
RC=$?
MUTATE=""
sleep "$SETTLE_S"
if check_mutation_announced protect-off "$OWN_ERR"; then
    if [ "$RC" -eq 0 ] && ! kill -0 "$M3_PROT" 2>/dev/null; then
        echo "    PASS: with the check gone the protected pid died — S8 is sensitive"
    else
        echo "    FAIL: protect-off rc=$RC, protected pid $(kill -0 "$M3_PROT" 2>/dev/null && echo alive || echo dead) — S8 cannot be failed (decoration)"
        FAIL=1
    fi
fi
rm -f untracked/runs/TPROT2.json

echo "  M4. mutation: rollback (SIGCONT-on-refusal) disabled ⇒ S8's running-again clause must fail"
spawn_tree treeM4 || FAIL=1
M4_CMD=$(tree_pid "$WORK/treeM4.man" command)
M4_PROT=$(tree_pid "$WORK/treeM4.man" sleeper2)
cat > untracked/runs/TPROT3.json <<EOF
{"command": "protected worker", "launcher_pid": 1, "pgid": $M4_PROT, "pid": $M4_PROT, "start": "2026-08-21T00:00:00Z", "task": "TPROT3"}
EOF
MUTATE="rollback-off"
run_treekill m4 --anchor "$M4_CMD" --kill --rounds "$OWN_ROUNDS" --settle-ms "$OWN_SETTLE_MS"
RC=$?
MUTATE=""
if check_mutation_announced rollback-off "$OWN_ERR"; then
    STOPPED=""
    for p in $(tree_target_pids "$WORK/treeM4.man"); do
        [ "$(pid_state "$p")" = "T" ] && STOPPED="$STOPPED $p"
    done
    if [ "$RC" -eq 4 ] && [ -n "$STOPPED" ]; then
        echo "    PASS: refusal without rollback left pids suspended:$STOPPED — the clause is sensitive"
    else
        echo "    FAIL: rollback-off rc=$RC, no pid left in T state — the running-again clause cannot be failed (decoration)"
        FAIL=1
    fi
    for p in $STOPPED; do kill -CONT "$p" 2>/dev/null; done
fi
rm -f untracked/runs/TPROT3.json

else
    echo "  N1-N4 S1-S8 M1-M4: SKIP (no managent binary carrying the treekill verb — phase-7 build lands it)"
fi

# ── I1/I2: the two integration arms that fail red today (03-test §3, §5) ─────────
echo "  I1. integration: real runner, normal exit, backgrounded sleeper — RED until C2 lands"
export MANAGENT_TASK_ID=TIOWN1
"$RUNNER" --no-prepend-zig --no-host-guard --max-wall 30 -- \
    sh -c "python3 '$WORK/bg_sleeper.py' '$WORK/i1tag' >/dev/null 2>&1 & exit 0" >/dev/null 2>&1
RC=$?
sleep "$SETTLE_S"
I1_LIVE=$(ps -axo pid=,command= | awk 'index($0, ENVIRON["MARKER"] "/bg_sleeper.py") {print $1}')
if [ "$RC" -ne 0 ]; then
    echo "    FAIL: runner itself exited $RC (arm invalid — expected a clean exit 0 run)"
    FAIL=1
elif [ -z "$I1_LIVE" ]; then
    echo "    PASS: the backgrounded sleeper is dead after the runner's normal exit (OWN-4/C2)"
else
    echo "    FAIL (RED expected today): sleeper$I1_LIVE survived the runner's normal exit — nothing after tools/runner:1587 reaps"
    FAIL=1
    for p in $I1_LIVE; do kill -9 "$p" 2>/dev/null; done
fi

echo "  I2. integration: real runner, low --rss-cap-mb, session-ESCAPING tree — RED until C1 lands"
export MANAGENT_TASK_ID=TIOWN2
"$RUNNER" --no-prepend-zig --no-host-guard --rss-cap-mb 32 --max-wall 60 -- \
    sh -c "python3 '$WORK/escape_tree.py' '$WORK/i2tag' >/dev/null 2>&1 & exec python3 -c 'import time; x = bytearray(268435456); time.sleep(120)' '$WORK/hogtag'" >/dev/null 2>&1
RC=$?
sleep "$SETTLE_S"
I2_LIVE=$(ps -axo pid=,command= | awk 'index($0, ENVIRON["MARKER"] "/escape_tree.py") || index($0, ENVIRON["MARKER"] "/hogtag") {print $1}')
if [ "$RC" -ne 124 ]; then
    echo "    FAIL: runner exited $RC, not 124 — the ceiling never fired (arm invalid)"
    FAIL=1
elif [ -z "$I2_LIVE" ]; then
    echo "    PASS: zero live descendants after exit 124 — equivalent-or-better than killpg (C1)"
else
    echo "    FAIL (RED expected today): escapees$I2_LIVE survived exit 124 — killpg at tools/runner:1554 cannot reach a setsid escaper (D-7)"
    FAIL=1
    for p in $I2_LIVE; do kill -9 "$p" 2>/dev/null; done
fi

echo "  I3. integration: real runner raises (exception path) — sleeper reaped before the raise (C3)"
# A nested git repo so the runner's _find_repo_root resolves to it (not the outer
# $WORK) and its untracked/runs stays empty — no leftover protected-set rows from
# N2/S8 can touch the I3 reap.  RUNNER_TEST_RAISE injects an exception inside the
# monitor loop after the first poll walk (so last_poll_pids is a real seed); the
# exception handler must reap the tree before re-raising (C3).
mkdir -p "$WORK/i3repo/untracked/runs" "$WORK/i3repo/docs/infra/managent"
( cd "$WORK/i3repo" && git init -q && printf 'untracked/\n' > .gitignore && echo base > README.md && git add -A && git commit -qm base )
export MANAGENT_TASK_ID=TIOWN3
export RUNNER_TEST_RAISE=1
( cd "$WORK/i3repo" && "$RUNNER" --no-prepend-zig --no-host-guard --max-wall 30 -- \
    sh -c "python3 '$WORK/bg_sleeper.py' '$WORK/i3tag' >/dev/null 2>&1 & sleep 600" ) >/dev/null 2>&1
RC=$?
unset RUNNER_TEST_RAISE
sleep "$SETTLE_S"
I3_LIVE=$(ps -axo pid=,command= | awk 'index($0, ENVIRON["MARKER"] "/bg_sleeper.py") {print $1}')
if [ "$RC" -eq 0 ]; then
    echo "    FAIL: runner exited 0 — the injected exception never fired (arm invalid)"
    FAIL=1
elif [ -z "$I3_LIVE" ]; then
    echo "    PASS: the backgrounded sleeper is dead after the runner raised (C3)"
else
    echo "    FAIL: sleeper$I3_LIVE survived the runner's exception — C3 reaps nothing on this path"
    FAIL=1
    for p in $I3_LIVE; do kill -9 "$p" 2>/dev/null; done
fi

echo ""
echo "NOTE: acceptance additionally requires ONE hand-traced end-to-end audit of a single"
echo "      reap (pid from spawn to death) — a human step this script cannot discharge."
echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-process-ownership: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-process-ownership: FAILURES (red is the expected state until the verb + C1/C2 land) ==="
    exit 1
fi
