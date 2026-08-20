#!/usr/bin/env bash
# regression-managent-concurrency.sh — T545 controls for the store-writer flock
#
# T545 (2026-08-20, severity highest-of-day): three store writers took no
# flock over their whole read-modify-write, so any overlapping claim, close
# or attribution could be SILENTLY REVERTED.  Observed in the wild: `managent
# tell` issued four times in ~3 minutes with 14 workers live — all four
# printed `told … / directive D0NN`, NONE reached its target inbox, D042/D043
# were minted twice, and _sys.directive_next moved BACKWARDS 44 → 43.
#
# The audit (census in findings/T545-store-clobber.json) found FIVE affected
# writers, not three — the brief's survey missed cmdAssert (read outside the
# lock, stale snapshot written under it) and cmdSync/writeSyncData (no lock at
# all):
#
#   writer                 | shape before T545
#   -----------------------+-------------------------------------------------
#   main migration         | read unlocked → writeState (lock only on write)
#   cmdTell                | read unlocked → writeState (lock only on write)
#   cmdAssert              | read unlocked → writeStateLocked (STALE snapshot)
#   cmdStanding            | read unlocked → registerStanding writeState +
#   (registerStanding +    |   persistStandingState raw whole-file write
#    persistStandingState) |
#   cmdSync (writeSyncData)| raw read → raw whole-file rename, no lock at all
#
# The fix wraps each in the documented lock→read→modify→write→unlock order
# (writeStateLocked under the held flock), and `tell` additionally verifies
# the directive is readable back from the ledger after the write — a directive
# must never be silently lost.
#
# Controls (all against a scratch MANAGENT_STORE in a scratch git repo —
# never the live kanban, never the live directives ledger):
#
#   1. seeded: 10 concurrent `tell` calls → 10 DISTINCT directive ids, all 10
#      readable in the target inbox, counter advanced by exactly 10.
#      (Against pre-T545 code this fails: counter regresses and ids duplicate.)
#   2. seeded, the severe one: `tell` racing a `claim` → the claim SURVIVES.
#      Constructed deterministically via a held flock between the writer's
#      read and write, not a sleep-race.
#   3. seeded: a migration-triggering read racing a `done` close → the close
#      SURVIVES (same flock-hold construction).
#   4. seeded: concurrent `standing` + `set` → both effects survive.
#   5. null: a single `tell` on a quiet store → unchanged behaviour, one id.
#
# The flock-hold arms work because lockStore blocks the WRITER between its
# read and its write: the test injects the concurrent change while the writer
# is parked, then releases.  Pre-T545 code reads before parking (stale
# snapshot → injected change reverted); T545 code parks before reading (the
# injected change is read, and survives).
#
# Task: T545 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-20

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
FAIL=0

# ── binary resolution ─────────────────────────────────────────────────────
MG="${MANAGENT_BIN:-}"
if [ -z "$MG" ]; then
    if [ -x "$PROJECT/zig-out/bin/managent" ]; then
        MG="$PROJECT/zig-out/bin/managent"
    elif [ -x "$PROJECT/bin/managent" ]; then
        MG="$PROJECT/bin/managent"
    fi
fi
if [ -z "$MG" ]; then
    echo "SKIP: no managent binary found — build with 'zig build' (zig-out/bin/managent) or deploy (zig build deploy-managent)"
    exit 0
fi
if ! "$MG" help 2>&1 | grep -q "managent standing"; then
    echo "SKIP: $MG does not carry the standing command — rebuild from src/managent/main.zig"
    exit 0
fi

# T445: /tmp/weizigo decays. Create it, and REFUSE to run if scratch creation
# fails — an empty scratch var once sent fixtures into the LIVE repo
# (2026-08-18 incident).  cd "" succeeds silently; never rely on it.
mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/managent-concurrency-XXXXXX)" || { echo "regression-managent-concurrency.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
git init -q
git config user.email t545@test
git config user.name T545
mkdir -p docs/infra/managent docs/infra/dispatch docs/epistemic findings untracked/msg bin

# arm 4 needs a real claimlint in the scratch repo (standing runs it for the
# C3 reading + absorption partition; a missing marker is a LOUD failure by
# design).  Copy the project's built claimlint; SKIP arm 4 if it is absent.
HAVE_CLAIMLINT=0
if [ -x "$PROJECT/bin/weizigo-claimlint" ]; then
    cp "$PROJECT/bin/weizigo-claimlint" bin/
    HAVE_CLAIMLINT=1
    # Minimal register so claimlint's C3 parse has content and the marker
    # guard passes (same scaffold as regression-managent-standing.sh).
    cat > docs/epistemic/CLAIMS.md <<'MDEOF'
# scratch register — T545 standing control

## 2. The register

| ID | legacy | goban | claim | status | evidence | depends-on | dependents | narrowed | wrong-answer-pass-rate | tree |
|---|---|---|---|---|---|---|---|---|---|---|
| `GLOBAL.SCRATCH1` | S1 | all | scratch row one | PROVEN | `scratch.md:1` | — | — | 0 | ? | Z- |
| `GLOBAL.SCRATCH2` | S2 | all | scratch row two | PROVEN | `scratch.md:2` | — | — | 0 | ? | Z- |
| `GLOBAL.SCRATCH3` | S3 | all | scratch row three | PROVEN | `scratch.md:3` | — | — | 0 | ? | Z- |
MDEOF
    echo "scratch evidence" > scratch.md
fi

STORE="$WORK/docs/infra/managent/tasks.json"
export MANAGENT_STORE="$STORE"

git add -A
git commit -qm base

echo "=== managent-concurrency regression (T545 store-writer flock) ==="

# A well-formed seed row (the shape serializeState emits, so any writer's
# round-trip guard passes).  Used by every arm via python3.
seed_task() {  # seed_task <id> <status>
    python3 - "$STORE" "$1" "$2" <<'PYEOF'
import json, sys
p, tid, status = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    d = json.load(open(p))
except FileNotFoundError:
    d = {"_sys": {"next_id": 100, "directive_next": 1, "assertion_next": 1, "closes": 0, "duty_migrated": True}}
d[tid] = {"status": status, "agent": None, "model": None,
          "bundle": "untracked/%s-test.md" % tid, "set": "A", "holds": [], "needs": [], "caps": [],
          "added": "2026-08-20T00:00:00Z", "claimed": None, "done": None, "dispatched": None,
          "dispatched_to": None, "note": None, "verdict": None, "verdict_note": None,
          "claim_count": 0, "duty": False, "due_after": 0, "last_chunk_closes": 0,
          "last_chunk_ts": None, "last_chunk_verdict": None, "last_chunk_findings": None,
          "acceptance": None, "skip_acceptance_reason": None, "amendments": [], "epitaph": None}
json.dump(d, open(p, "w"))
PYEOF
}

ledger="$WORK/docs/infra/managent/directives.jsonl"

# ── arm 1: N concurrent tells → N distinct ids, all readable, counter +N ──
echo "  1. seeded: ${N:-10} concurrent tell calls"
N=10
seed_task T700 dispatchable
OUTDIR="$WORK/arm1"; mkdir -p "$OUTDIR"
PIDS=""
i=0
while [ "$i" -lt "$N" ]; do
    "$MG" tell T700 question --note "race-$i" >"$OUTDIR/tell-$i.out" 2>&1 &
    PIDS="$PIDS $!"
    i=$((i+1))
done
for p in $PIDS; do wait "$p"; done

python3 - "$STORE" "$N" "$ledger" "$MG" T700 <<'PYEOF' > "$OUTDIR/check.out" 2>&1
import json, subprocess, sys, os
store, n, ledger, mg, target = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4], sys.argv[5]
d = json.load(open(store))
counter = d["_sys"]["directive_next"]
lines = [l for l in open(ledger).read().splitlines() if l.strip()] if os.path.exists(ledger) else []
ids = [json.loads(l)["id"] for l in lines]
env = dict(os.environ)
inbox = subprocess.run([mg, "inbox", target], capture_output=True, text=True, env=env).stdout
shown = [ln.split()[0] for ln in inbox.splitlines() if ln.strip().startswith("D") and ln.split()[0][1:].isdigit()]
ok = (counter == 1 + n) and (len(ids) == n) and (len(set(ids)) == n) and (len(shown) == n)
print(f"counter={counter} (want {1+n}) ledger_ids={len(ids)} distinct={len(set(ids))} inbox_shown={len(shown)}")
print("ids:", sorted(ids))
print("ARM1-RESULT:", "PASS" if ok else "FAIL")
sys.exit(0 if ok else 1)
PYEOF
if [ "$?" -eq 0 ]; then
    echo "    PASS: $(tail -3 "$OUTDIR/check.out" | head -1 | sed 's/^/      /')"
else
    echo "    FAIL:"
    sed 's/^/      /' "$OUTDIR/check.out"
    FAIL=1
fi

# ── arm 2: tell racing a claim → the claim SURVIVES (flock-hold) ──────────
echo "  2. seeded: tell racing a claim — the claim survives (flock-hold)"
seed_task T701 dispatchable
python3 - "$STORE" T701 <<'PYEOF' > "$OUTDIR/arm2-reset.out" 2>&1
import json, sys
p, tid = sys.argv[1], sys.argv[2]
d = json.load(open(p))
d["_sys"]["directive_next"] = 1
json.dump(d, open(p, "w"))
PYEOF
python3 - "$STORE" "$MG" T701 <<'PYEOF' > "$OUTDIR/arm2.out" 2>&1
import fcntl, json, os, subprocess, sys, time
store, mg, tid = sys.argv[1], sys.argv[2], sys.argv[3]
lockfile = store + ".lockfile"
env = dict(os.environ)

# Park the writer between its read and its write: hold the flock, start tell.
fd = os.open(lockfile, os.O_RDWR | os.O_CREAT, 0o644)
fcntl.flock(fd, fcntl.LOCK_EX)
p = subprocess.Popen([mg, "tell", tid, "question", "--note", "arm2"],
                     stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, env=env)
time.sleep(0.4)
# Writer is parked at lockStore (T545: before its read; pre-T545: after its read).
# Simulate a concurrent `claim` landing in the window:
d = json.load(open(store))
d[tid]["status"] = "in_progress"
d[tid]["agent"] = "deepseek-v4-flash/T999"
d[tid]["claimed"] = "2026-08-20T00:05:00Z"
d[tid]["claim_count"] = 1
json.dump(d, open(store, "w"))
fcntl.flock(fd, fcntl.LOCK_UN)
os.close(fd)
out, _ = p.communicate(timeout=20)

d2 = json.load(open(store))
st, agent = d2[tid]["status"], d2[tid]["agent"]
ok = (st == "in_progress" and agent == "deepseek-v4-flash/T999") and (d2["_sys"]["directive_next"] == 2)
print(f"T701 after tell: status={st} agent={agent} directive_next={d2['_sys']['directive_next']}")
print("ARM2-RESULT:", "PASS (claim survived)" if ok else "FAIL (claim reverted)")
sys.exit(0 if ok else 1)
PYEOF
if [ "$?" -eq 0 ]; then
    echo "    PASS: $(grep '^T701' "$OUTDIR/arm2.out" | sed 's/^/      /')"
else
    echo "    FAIL:"
    sed 's/^/      /' "$OUTDIR/arm2.out"
    FAIL=1
fi

# ── arm 3: migration-triggering read racing a done → close survives ───────
echo "  3. seeded: migration-triggering read racing a done close"
seed_task T702 dispatchable
python3 - "$STORE" T702 <<'PYEOF' > "$OUTDIR/arm3-reset.out" 2>&1
import json, sys
p, tid = sys.argv[1], sys.argv[2]
d = json.load(open(p))
# claim_count=0 + agent + claimed makes migrateState want to write on ANY
# invocation (claim_count backfill), so the migration path is exercised.
d[tid]["agent"] = "deepseek-v4-flash/T998"
d[tid]["claimed"] = "2026-08-20T00:01:00Z"
d[tid]["claim_count"] = 0
json.dump(d, open(p, "w"))
PYEOF
python3 - "$STORE" "$MG" T702 <<'PYEOF' > "$OUTDIR/arm3.out" 2>&1
import fcntl, json, os, subprocess, sys, time
store, mg, tid = sys.argv[1], sys.argv[2], sys.argv[3]
lockfile = store + ".lockfile"
env = dict(os.environ)

fd = os.open(lockfile, os.O_RDWR | os.O_CREAT, 0o644)
fcntl.flock(fd, fcntl.LOCK_EX)
# `status` is an ordinary read — with pre-T545 code its migration write was
# the clobber vector (any invocation can migrate, observed [migrate] T535).
p = subprocess.Popen([mg, "status"], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, env=env)
time.sleep(0.4)
# Simulate a concurrent `done` close landing in the window:
d = json.load(open(store))
d[tid]["status"] = "done"
d[tid]["done"] = "2026-08-20T00:06:00Z"
d[tid]["verdict"] = "pass"
json.dump(d, open(store, "w"))
fcntl.flock(fd, fcntl.LOCK_UN)
os.close(fd)
out, _ = p.communicate(timeout=20)

d2 = json.load(open(store))
st = d2[tid]["status"]
ok = st == "done"
print(f"T702 after status: status={st}")
print("ARM3-RESULT:", "PASS (close survived)" if ok else "FAIL (close reverted by migration write)")
sys.exit(0 if ok else 1)
PYEOF
if [ "$?" -eq 0 ]; then
    echo "    PASS: $(grep '^T702' "$OUTDIR/arm3.out" | sed 's/^/      /')"
else
    echo "    FAIL:"
    sed 's/^/      /' "$OUTDIR/arm3.out"
    FAIL=1
fi

# ── arm 4: concurrent standing + set → both effects survive ───────────────
if [ "$HAVE_CLAIMLINT" -eq 1 ]; then
    echo "  4. seeded: concurrent standing + set"
    seed_task T703 dispatchable
    python3 - "$STORE" T703 <<'PYEOF' > "$OUTDIR/arm4-reset.out" 2>&1
import json, sys
p, tid = sys.argv[1], sys.argv[2]
d = json.load(open(p))
d["_sys"]["directive_next"] = 1
d[tid]["set"] = "A"
json.dump(d, open(p, "w"))
PYEOF
    python3 - "$STORE" "$MG" T703 <<'PYEOF' > "$OUTDIR/arm4.out" 2>&1
import fcntl, json, os, subprocess, sys, time
store, mg, tid = sys.argv[1], sys.argv[2], sys.argv[3]
lockfile = store + ".lockfile"
env = dict(os.environ)

fd = os.open(lockfile, os.O_RDWR | os.O_CREAT, 0o644)
fcntl.flock(fd, fcntl.LOCK_EX)
p = subprocess.Popen([mg, "standing"], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, env=env)
time.sleep(0.4)
# Simulate a concurrent `set T703 B` landing while standing is parked:
d = json.load(open(store))
d[tid]["set"] = "B"
json.dump(d, open(store, "w"))
fcntl.flock(fd, fcntl.LOCK_UN)
os.close(fd)
out, _ = p.communicate(timeout=60)

d2 = json.load(open(store))
s = d2[tid]["set"]
ok = s == "B"
print(f"T703 after standing: set={s}")
print("ARM4-RESULT:", "PASS (set survived standing's writes)" if ok else "FAIL (set reverted)")
sys.exit(0 if ok else 1)
PYEOF
    if [ "$?" -eq 0 ]; then
        echo "    PASS: $(grep '^T703' "$OUTDIR/arm4.out" | sed 's/^/      /')"
    else
        echo "    FAIL:"
        sed 's/^/      /' "$OUTDIR/arm4.out"
        FAIL=1
    fi
else
    echo "  4. SKIP: bin/weizigo-claimlint absent — standing control cannot run (build with 'zig build deploy-claimlint')"
fi

# ── arm 5: null — a single tell on a quiet store ──────────────────────────
echo "  5. null: a single tell on a quiet store"
seed_task T704 dispatchable
rm -f "$ledger"
python3 - "$STORE" <<'PYEOF' > "$OUTDIR/arm5-reset.out" 2>&1
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d["_sys"]["directive_next"] = 1
json.dump(d, open(p, "w"))
PYEOF
OUT5=$("$MG" tell T704 pause --note "null-arm" 2>&1)
RC5=$?
python3 - "$STORE" "$MG" T704 "$OUT5" <<'PYEOF' > "$OUTDIR/arm5.out" 2>&1
import json, os, subprocess, sys
store, mg, tid, out = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
d = json.load(open(store))
counter = d["_sys"]["directive_next"]
rows = [k for k in d if not k.startswith("_")]
ledger = os.path.join(os.path.dirname(store), "directives.jsonl")
lines = [l for l in open(ledger).read().splitlines() if l.strip()]
ids = [json.loads(l)["id"] for l in lines]
inbox = subprocess.run([mg, "inbox", tid], capture_output=True, text=True, env=dict(os.environ)).stdout
ok = (counter == 2) and (ids == ["D001"]) and ("D001" in inbox) and ("told T704 -> pause" in out)
print(f"counter={counter} ids={ids} inbox_has_D001={'D001' in inbox} rows={len(rows)}")
print("ARM5-RESULT:", "PASS" if ok else "FAIL")
sys.exit(0 if ok else 1)
PYEOF
if [ "$?" -eq 0 ] && [ "$RC5" -eq 0 ]; then
    echo "    PASS: $(grep '^counter' "$OUTDIR/arm5.out" | sed 's/^/      /')"
else
    echo "    FAIL: tell RC=$RC5"
    sed 's/^/      /' "$OUTDIR/arm5.out"
    FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-managent-concurrency: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-managent-concurrency: FAILURES ==="
    exit 1
fi
