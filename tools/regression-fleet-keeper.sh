#!/usr/bin/env bash
# regression-fleet-keeper.sh
# T496 controls for tools/fleet-keeper.sh + tools/fleet-cooldown.sh — the
# dispatcher duty that keeps the fleet full and cools down on demand.
#
# Arms (scratch store + scratch repo only — never the live kanban, T445;
# MANAGENT_STORE + the keeper's FLEET_ROOT + bin/dispatch --test-root
# isolation, per T427/T476):
#
#   seeded (must be red before the loop exists):
#   1. six dispatchable tasks, cap 5, one in_progress → the keeper fires
#      until the cap is reached, oldest-with-met-needs first (T1..T4 in
#      added order; then a "cap" no-op).
#   2. cooldown flag present → the keeper fires nothing and logs the
#      reason.  Plus the dead-man's switch: an unreadable cooldown dir is
#      treated as cooldown-set (fail-safe on the cool side).
#
#   null:
#   3. empty queue → no-op, exits cleanly.
#   4. at cap (5 in_progress) → no-op ("cap").
#   5. a dispatchable row with an unmet need → not picked (defensive
#      needs check; managent would normally gate this itself, so this arm
#      seeds the store JSON directly).
#   6. a non-T id row (a claude/Orchestrator seat) and a duty row → not
#      picked; left for manual dispatch / the duty's own mechanism.
#
# T501 §13 arms (logjam-pressure state machine, docs/infra/fleet-keeper-design.md;
# red-first, scratch store/repo):
#   a. drop-then-solo — cap drops 5→4→3→2→1 as running holders complete,
#      then the freed anchor runs solo (cap resets to 5).
#   b. conflict-free still runs under pressure (holds-free task admitted).
#   c. a conflicting mutation never dispatches (holds ∩ inprog_holds).
#   d. no blocked next → cap stays C (NORMAL refill).
#   e. a held task whose hold is free dispatches immediately (no pressure).
#   f. model cooldown binds the pressure path (denied candidate not admitted;
#      denied anchor's model exits pressure).
#   g. logjam flag after FLEET_LOGJAM_FLAG minutes (telemetry only).
#   h. waiting=1 outranks priority; a bumped blocked task anchors pressure.
#
# T504 §5 arms (heal cooldown — a recently-healed row is parked, not re-fired;
# red-first, scratch store/repo):
#   T504-a. seeded: claim_count=2 + a recent T477 heal record → parked for the
#           window, and the exclusion is logged (also control d).
#   T504-b. null: after the window the row is eligible again (cooldown expires).
#   T504-c. null: a fresh row (claim_count=1, no heal) is dispatched normally.
#   T504-e. seeded: a fresh T477 heal record with claim_count=1 → parked (the
#           live T358 defect: dispatcher healed, keeper re-fired).
#
# Task: T496/T501/T504 · Model: glm-5.2 (T496/T501), deepseek-v4-pro (T504)
# Date: 2026-08-19 (T496), 2026-08-20 (T501/T504)

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
KEEPER="$ROOT/tools/fleet-keeper.sh"
COOLDOWN="$ROOT/tools/fleet-cooldown.sh"
MG="$ROOT/bin/managent"
DISPATCH="$ROOT/bin/dispatch"
FAIL=0

# T445: refuse to run if scratch cannot be created.
mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/t496-keeper-XXXXXX)" || { echo "regression-fleet-keeper.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

# A stale depth stamp would trip bin/dispatch's cap check.
unset WEIZIGO_AGENT_DEPTH || true
# A leaked DeepSeek-window carve (FLEET_MODEL_ALLOW/DENY in the caller's env)
# would deny glm-5.2 and break every arm's model resolution.  The suite owns
# these knobs (arm f sets/unset them explicitly); start clean (T504).
unset FLEET_MODEL_ALLOW FLEET_MODEL_DENY || true

# ── scratch repo + store ─────────────────────────────────────────────────
cd "$WORK"
git init -q
git config user.email t496@test
git config user.name T496
echo base > README.md
mkdir -p docs/infra/managent untracked untracked/log
printf 'untracked/\n' > .gitignore
git add README.md .gitignore
git commit -qm base

STORE="$WORK/docs/infra/managent/tasks.json"
export MANAGENT_STORE="$STORE"
export WEIZIGO_MODEL_PERF="$WORK/perf-ledger.txt"
export REAL_MG="$MG"

# The keeper reads cooldown/log/bundles from FLEET_ROOT and forwards it to
# bin/dispatch as --test-root, so every dispatch lands in scratch.
export FLEET_ROOT="$WORK"
export FLEET_TEST_WORKER="$WORK/stub.py"
export FLEET_DEFAULT_MODEL="glm-5.2"
export FLEET_CAP="5"
export FLEET_INTERVAL="1"

# ── stub worker: claims the row and exits (stays in_progress so the cap
#    holds — the keeper must observe the freed slot only when a row
#    actually leaves in_progress, which this stub never does).  Mirrors
#    tools/regression-dispatch.sh's honest stub shape.
cat > "$WORK/stub.py" <<'STUBEOF'
#!/usr/bin/env python3
import os, re, subprocess, sys
prompt = sys.argv[-1]
mg = os.environ["REAL_MG"]
task = re.search(r"managent claim (T\d+)", prompt).group(1)
model = re.search(r"managent claim \S+ --agent (\S+)", prompt).group(1)
subprocess.run([mg, "claim", task, "--agent", model], check=True)
# Intentionally do NOT done: stay in_progress so the cap holds for the test.
sys.exit(0)
STUBEOF
chmod +x "$WORK/stub.py"

# ── store seeding (direct JSON for deterministic `added` ordering) ───────
# managent's `added` is second-resolution; tasks added in the same second
# tie.  We write the store directly so T1..T6 carry distinct, ordered
# timestamps and the keeper's oldest-first pick is unambiguous.
seed_store() {  # $1 = python that prints the doc dict
  python3 - "$STORE" "$1" <<'PY'
import json, sys
store_path, doc_py = sys.argv[1], sys.argv[2]
ns = {"json": json}
exec(doc_py, ns)
doc = ns["doc"]
doc["_sys"] = {"next_id": 9000, "directive_next": 1, "assertion_next": 1,
               "closes": 0, "duty_migrated": True}
json.dump(doc, open(store_path, "w"), indent=1)
PY
}

# Full task record.  Args via env: ID,STATUS,SET,ADDED,NEEDS(comma),MODEL,DUTY
task_rec() {
ID="$1" STATUS="$2" SETV="$3" ADDED="$4" NEEDS="${5:-}" MODEL="${6:-}" DUTY="${7:-false}" HOLDS="${8:-}"
NEEDS_JSON="[]"
[ -n "$NEEDS" ] && NEEDS_JSON=$(python3 -c 'import json,sys;print(json.dumps(sys.argv[1].split(",")))' "$NEEDS")
MODEL_JSON="null"; [ -n "$MODEL" ] && MODEL_JSON="$MODEL"
HOLDS_JSON="[]"
[ -n "$HOLDS" ] && HOLDS_JSON=$(python3 -c 'import json,sys;print(json.dumps(sys.argv[1].split(",")))' "$HOLDS")
python3 - "$ID" "$STATUS" "$SETV" "$ADDED" "$NEEDS_JSON" "$MODEL_JSON" "$DUTY" "$HOLDS_JSON" <<'PY'
import json, sys
uid, status, setv, added, needs, model, duty, holds = sys.argv[1:9]
bundle = f"untracked/{uid}-bundle.md" if uid != "ORCHA-FLASH" else "untracked/ORCHA-SEAT-flash.md"
print(json.dumps({uid: {
    "status": status, "agent": None, "model": None if model == "null" else model,
    "bundle": bundle, "set": setv, "holds": json.loads(holds), "needs": json.loads(needs), "caps": [],
    "added": added, "claimed": "2026-08-19T21:00:00Z" if status == "in_progress" else None,
    "done": None, "dispatched": None, "dispatched_to": None, "note": None,
    "verdict": None, "verdict_note": None, "claim_count": 1 if status == "in_progress" else 0,
    "acceptance": None, "skip_acceptance_reason": None, "amendments": [], "epitaph": None,
    "duty": duty == "true", "due_after": 5, "last_chunk_closes": 0,
    "last_chunk_ts": None, "last_chunk_verdict": None, "last_chunk_findings": None,
}}))
PY
}

# Write a bundle for a task id (so the keeper's has_bundle and bin/dispatch agree).
seed_bundle() {  # $1=id  $2=deliverable  $3=priority  $4=waiting
  local meta="set=A deliverables=${2:-findings/x.json}"
  [ -n "${3:-}" ] && meta="$meta priority=$3"
  [ -n "${4:-}" ] && meta="$meta waiting=$4"
  printf '<!--managent %s-->\n# %s — fleet-keeper regression bundle\n' "$meta" "$1" \
      > "$WORK/untracked/$1-bundle.md"
}

row_status() {  # $1=id → status word from `managent show`
  "$MG" show "$1" 2>/dev/null | awk 'NR==2 && NF>=2 {print $2}'
}

# ── T501 helpers: pressure state on the scratch store ────────────────────
reset_keeper_state() {  # fresh pressure/log/flag/heal state for each arm
  rm -f "$WORK/untracked/fleet-keeper.pressure.json"
  rm -f "$WORK/untracked/fleet-keeper.logjam.flag"
  rm -f "$WORK/untracked/fleet-keeper.heal.json"
  rm -f "$WORK/docs/infra/dispatch-heals.jsonl"
  : > "$WORK/untracked/log/fleet-keeper.log"
}

set_row_status() {  # $1=id $2=status — flip a seeded row (simulate a completion)
  python3 - "$STORE" "$1" "$2" <<'PY'
import json, sys
store, tid, status = sys.argv[1], sys.argv[2], sys.argv[3]
doc = json.load(open(store))
if tid in doc:
    doc[tid]["status"] = status
    if status == "done":
        doc[tid]["done"] = "2026-08-20T00:00:00Z"
    else:
        doc[tid]["done"] = None
json.dump(doc, open(store, "w"), indent=1)
PY
}

pressure_field() {  # $1=field → raw value (empty when absent/null)
  python3 -c 'import json,sys
try:
    d = json.load(open(sys.argv[1]))
    v = d.get(sys.argv[2])
    if v is None:
        print("")
    else:
        print(v)
except Exception:
    print("")' "$WORK/untracked/fleet-keeper.pressure.json" "$1"
}

seed_pressure() {  # $1=anchor(or null) $2=drops $3=waiting_since_iso(or null) $4=running(comma)
  python3 - "$WORK/untracked/fleet-keeper.pressure.json" "$1" "$2" "$3" "$4" <<'PY'
import json, sys
path, anchor, drops, waiting, running = sys.argv[1:6]
state = {
    "anchor": None if anchor in ("", "null") else anchor,
    "drops": int(drops or 0),
    "waiting_since": None if waiting in ("", "null") else waiting,
    "running": [x for x in running.split(",") if x],
}
json.dump(state, open(path, "w"), indent=1)
PY
}

# ── T504 helpers: claim_count + heal state on the scratch store ──────────
set_claim_count() {  # $1=id $2=n — bump a seeded row's claim_count
  python3 - "$STORE" "$1" "$2" <<'PY'
import json, sys
store, tid, n = sys.argv[1], sys.argv[2], int(sys.argv[3])
doc = json.load(open(store))
if tid in doc:
    doc[tid]["claim_count"] = n
json.dump(doc, open(store, "w"), indent=1)
PY
}

seed_heal_log() {  # $1=id $2=iso_ts — one T477 dispatcher heal record
  printf '{"task_id": "%s", "model": "glm-5.2", "exit_code": 124, "wall_seconds": 350.9, "healed_by": "dispatcher", "timestamp": "%s"}\n' "$1" "$2" \
      >> "$WORK/docs/infra/dispatch-heals.jsonl"
}

seed_heal_state() {  # $1=id $2=healed_epoch(or empty) $3=seen_cc $4=seen_hl_ts(or empty)
  python3 - "$WORK/untracked/fleet-keeper.heal.json" "$1" "$2" "$3" "$4" <<'PY'
import json, sys
path, tid, healed, seen_cc, seen_hl = sys.argv[1:6]
state = {"healed": {}, "seen_hl": {}, "seen_cc": {}}
if healed:
    state["healed"][tid] = float(healed)
if seen_hl:
    state["seen_hl"][tid] = seen_hl
if seen_cc:
    state["seen_cc"][tid] = int(seen_cc)
json.dump(state, open(path, "w"), indent=1)
PY
}

echo "=== T496 fleet-keeper regression ==="

# ── arm 1: six dispatchable, cap 5, one in_progress → fire oldest first ─
echo "  1. seeded: six dispatchable, cap 5, one in_progress → fire T1..T4 then cap"
seed_bundle T0 findings/T0.json
seed_bundle T1 findings/T1.json
seed_bundle T2 findings/T2.json
seed_bundle T3 findings/T3.json
seed_bundle T4 findings/T4.json
seed_bundle T5 findings/T5.json
seed_bundle T6 findings/T6.json
DOC="$(cat <<EOF
doc = {}
for rec in [
  '$(task_rec T0 in_progress A 2026-08-19T21:00:00Z)',
  '$(task_rec T1 dispatchable A 2026-08-19T22:00:01Z)',
  '$(task_rec T2 dispatchable A 2026-08-19T22:00:02Z)',
  '$(task_rec T3 dispatchable A 2026-08-19T22:00:03Z)',
  '$(task_rec T4 dispatchable A 2026-08-19T22:00:04Z)',
  '$(task_rec T5 dispatchable A 2026-08-19T22:00:05Z)',
  '$(task_rec T6 dispatchable A 2026-08-19T22:00:06Z)',
]:
    r = json.loads(rec); doc[next(iter(r))] = r[next(iter(r))]
EOF
)"
seed_store "$DOC"

: > "$WORK/untracked/log/fleet-keeper.log"
FIRED=""
for want in T1 T2 T3 T4; do
  OUT=$(cd "$ROOT" && "$KEEPER" --once 2>&1); RC=$?
  if [ "$RC" -ne 0 ] || ! echo "$OUT" | grep -q "^dispatched $want "; then
    echo "    FAIL: expected to dispatch $want (rc=$RC); got:"; echo "$OUT" | sed 's/^/    | /'
    FAIL=1; break
  fi
  # wait for the stub to claim so in_progress climbs before the next pick
  for i in $(seq 1 60); do
    [ "$(row_status "$want")" = "in_progress" ] && break
    sleep 0.3
  done
  FIRED="$FIRED $want"
done
if [ -z "$FIRED" ] || [ "$FAIL" -ne 0 ]; then
  :
else
  # 5th iteration: at cap (T0 + T1..T4) → no-op
  OUT=$(cd "$ROOT" && "$KEEPER" --once 2>&1); RC=$?
  if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "^cap"; then
    echo "    PASS: fired$(echo "$FIRED" | sed 's/ /, /g') in added order, then cap no-op"
  else
    echo "    FAIL: expected cap no-op after filling (rc=$RC); got:"; echo "$OUT" | sed 's/^/    | /'
    FAIL=1
  fi
  if ! grep -q "cooldown\|at cap" "$WORK/untracked/log/fleet-keeper.log" 2>/dev/null; then
    :
  fi
  # T503 exploration-first: a model-less row gets the LEAST-DATA model, so the
  # fired model is dynamic; assert each firing is logged, not which model.
  if grep -q "dispatched T1 → " "$WORK/untracked/log/fleet-keeper.log" \
     && grep -q "dispatched T4 → " "$WORK/untracked/log/fleet-keeper.log"; then
    echo "    PASS: log records each firing"
  else
    echo "    FAIL: log missing firing lines"; tail -5 "$WORK/untracked/log/fleet-keeper.log" | sed 's/^/    | /'
    FAIL=1
  fi
fi

# ── arm 2a: cooldown flag present → fires nothing, logs the reason ───────
echo "  2a. seeded: cooldown flag present → fires nothing, logs reason"
DOC="$(cat <<EOF
doc = {}
for rec in [
  '$(task_rec T1 dispatchable A 2026-08-19T22:00:01Z)',
]:
    r = json.loads(rec); doc[next(iter(r))] = r[next(iter(r))]
EOF
)"
seed_store "$DOC"
: > "$WORK/untracked/log/fleet-keeper.log"
"$COOLDOWN" on >/dev/null 2>&1 || true
OUT=$(cd "$ROOT" && "$KEEPER" --once 2>&1); RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "^cooldown"; then
  echo "    PASS: cooldown set → keeper fired nothing (rc=$RC)"
else
  echo "    FAIL: expected cooldown no-op (rc=$RC); got:"; echo "$OUT" | sed 's/^/    | /'
  FAIL=1
fi
if grep -q "cooldown flag set" "$WORK/untracked/log/fleet-keeper.log"; then
  echo "    PASS: cooldown reason logged"
else
  echo "    FAIL: cooldown reason not logged"; tail -5 "$WORK/untracked/log/fleet-keeper.log" | sed 's/^/    | /'
  FAIL=1
fi
# confirm nothing was actually dispatched (T1 still dispatchable)
if [ "$(row_status T1)" = "dispatchable" ]; then
  echo "    PASS: T1 left dispatchable under cooldown"
else
  echo "    FAIL: T1 moved under cooldown (status=$(row_status T1))"
  FAIL=1
fi
"$COOLDOWN" off >/dev/null 2>&1 || true

# ── arm 2b: dead-man's switch — unreadable cooldown dir → cooldown ──────
echo "  2b. seeded: unreadable cooldown dir (missing untracked/) → cooldown"
DOC="$(cat <<EOF
doc = {}
for rec in [
  '$(task_rec T1 dispatchable A 2026-08-19T22:00:01Z)',
]:
    r = json.loads(rec); doc[next(iter(r))] = r[next(iter(r))]
EOF
)"
seed_store "$DOC"
# Point FLEET_ROOT at a dir with no untracked/ → listdir raises → cooldown.
NODIR="$WORK/nodir"
rm -rf "$NODIR"; mkdir -p "$NODIR"
OUT=$(cd "$ROOT" && FLEET_ROOT="$NODIR" "$KEEPER" --once 2>&1); RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "^cooldown"; then
  echo "    PASS: missing cooldown dir treated as cooldown (dead-man's switch)"
else
  echo "    FAIL: expected cooldown on unreadable dir (rc=$RC); got:"; echo "$OUT" | sed 's/^/    | /'
  FAIL=1
fi

# ── arm 3: empty queue → no-op, exits cleanly ───────────────────────────
echo "  3. null: empty queue → no-op, exits cleanly"
seed_store "doc = {}"
: > "$WORK/untracked/log/fleet-keeper.log"
OUT=$(cd "$ROOT" && "$KEEPER" --once 2>&1); RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "^none"; then
  echo "    PASS: empty queue → none, rc=0"
else
  echo "    FAIL: expected none on empty (rc=$RC); got:"; echo "$OUT" | sed 's/^/    | /'
  FAIL=1
fi

# ── arm 4: at cap (5 in_progress) → no-op ────────────────────────────────
echo "  4. null: at cap (5 in_progress) → no-op"
DOC="$(cat <<EOF
doc = {}
for rec in [
  '$(task_rec T1 in_progress A 2026-08-19T22:00:01Z)',
  '$(task_rec T2 in_progress A 2026-08-19T22:00:02Z)',
  '$(task_rec T3 in_progress A 2026-08-19T22:00:03Z)',
  '$(task_rec T4 in_progress A 2026-08-19T22:00:04Z)',
  '$(task_rec T5 in_progress A 2026-08-19T22:00:05Z)',
  '$(task_rec T6 dispatchable A 2026-08-19T22:00:06Z)',
]:
    r = json.loads(rec); doc[next(iter(r))] = r[next(iter(r))]
EOF
)"
seed_store "$DOC"
seed_bundle T6 findings/T6.json
: > "$WORK/untracked/log/fleet-keeper.log"
OUT=$(cd "$ROOT" && "$KEEPER" --once 2>&1); RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "^cap"; then
  echo "    PASS: at cap → cap no-op"
else
  echo "    FAIL: expected cap no-op (rc=$RC); got:"; echo "$OUT" | sed 's/^/    | /'
  FAIL=1
fi
if [ "$(row_status T6)" = "dispatchable" ]; then
  echo "    PASS: T6 left dispatchable at cap"
else
  echo "    FAIL: T6 moved despite cap (status=$(row_status T6))"
  FAIL=1
fi

# ── arm 5: dispatchable row with an unmet need → not picked ──────────────
echo "  5. null: dispatchable row with an unmet need → not picked"
DOC="$(cat <<EOF
doc = {}
for rec in [
  '$(task_rec T1 dispatchable A 2026-08-19T22:00:01Z)',
  '$(task_rec T2 dispatchable A 2026-08-19T22:00:02Z T1)',  # needs T1, not done
]:
    r = json.loads(rec); doc[next(iter(r))] = r[next(iter(r))]
EOF
)"
seed_store "$DOC"
seed_bundle T1 findings/T1.json
seed_bundle T2 findings/T2.json
: > "$WORK/untracked/log/fleet-keeper.log"
OUT=$(cd "$ROOT" && "$KEEPER" --once 2>&1); RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "^dispatched T1 "; then
  echo "    PASS: T1 (need-free) picked; T2 (unmet need) skipped"
else
  echo "    FAIL: expected T1 dispatched and T2 skipped (rc=$RC); got:"; echo "$OUT" | sed 's/^/    | /'
  FAIL=1
fi
# second iteration: T1 now in_progress (stub claimed it); T2 still has unmet need → none
for i in $(seq 1 60); do
  [ "$(row_status T1)" = "in_progress" ] && break
  sleep 0.3
done
OUT2=$(cd "$ROOT" && "$KEEPER" --once 2>&1); RC2=$?
if [ "$RC2" -eq 0 ] && echo "$OUT2" | grep -q "^none"; then
  echo "    PASS: with T1 in_progress, T2 (unmet need) not picked → none"
else
  echo "    FAIL: expected none with only unmet-need row left (rc=$RC2); got:"; echo "$OUT2" | sed 's/^/    | /'
  FAIL=1
fi

# ── arm 6: non-T id (claude/Orchestrator seat) + duty row → not picked ──
echo "  6. null: non-T seat row and a duty row → not picked"
DOC="$(cat <<EOF
doc = {}
for rec in [
  '$(task_rec T1 dispatchable A 2026-08-19T22:00:01Z)',
  '$(task_rec ORCHA-FLASH dispatchable A 2026-08-19T22:00:00Z)',
  '$(task_rec DRPLAY dispatchable H 2026-08-19T22:00:00Z "" "" true)',
]:
    r = json.loads(rec); doc[next(iter(r))] = r[next(iter(r))]
EOF
)"
seed_store "$DOC"
seed_bundle T1 findings/T1.json
seed_bundle ORCHA-FLASH docs/dummy
: > "$WORK/untracked/log/fleet-keeper.log"
OUT=$(cd "$ROOT" && "$KEEPER" --once 2>&1); RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "^dispatched T1 "; then
  echo "    PASS: T1 (T-id) picked; ORCHA-FLASH (seat) and DRPLAY (duty) skipped"
else
  echo "    FAIL: expected C1 dispatched only (rc=$RC); got:"; echo "$OUT" | sed 's/^/    | /'
  FAIL=1
fi
DRPLAY_STATUS=$("$MG" status --json 2>/dev/null | python3 -c 'import json,sys
print(next((r["status"] for r in json.load(sys.stdin) if r["id"]=="DRPLAY"), "?"))')
if [ "$(row_status ORCHA-FLASH)" = "dispatchable" ] && [ "$DRPLAY_STATUS" = "duty" ]; then
  echo "    PASS: seat and duty rows left untouched"
else
  echo "    FAIL: seat/duty row moved (ORCHA-FLASH=$(row_status ORCHA-FLASH) DRPLAY=$DRPLAY_STATUS)"
  FAIL=1
fi

# ── cooldown.sh on/off/status contract ───────────────────────────────────
echo "  7. tools/fleet-cooldown.sh on/off/status contract"
"$COOLDOWN" off >/dev/null 2>&1 || true   # clean slate
S=$("$COOLDOWN" status 2>&1)
if echo "$S" | grep -qi "off"; then
  echo "    PASS: status off when flag absent"
else
  echo "    FAIL: status not off when absent: $S"; FAIL=1
fi
ON=$("$COOLDOWN" on 2>&1)
if echo "$ON" | grep -qi "cooldown set" && [ -f "$WORK/untracked/fleet-keeper.cooldown" ]; then
  echo "    PASS: on writes the flag and announces"
else
  echo "    FAIL: on did not set the flag: $ON"; FAIL=1
fi
S2=$("$COOLDOWN" status 2>&1)
if echo "$S2" | grep -qi "on"; then
  echo "    PASS: status on when flag present"
else
  echo "    FAIL: status not on when present: $S2"; FAIL=1
fi
OFF=$("$COOLDOWN" off 2>&1)
if echo "$OFF" | grep -qi "cleared" && [ ! -f "$WORK/untracked/fleet-keeper.cooldown" ]; then
  echo "    PASS: off clears the flag and announces"
else
  echo "    FAIL: off did not clear: $OFF"; FAIL=1
fi

# ── T501 §13 arm a: drop-then-solo (seeded) ──────────────────────────────
echo "  a. seeded: pressure drops cap 5→4→3→2→1, then the anchor runs solo"
DOC="$(cat <<EOF
doc = {}
for rec in [
  '$(task_rec R1 in_progress A 2026-08-20T00:00:00Z "" glm-5.2 false a)',
  '$(task_rec R2 in_progress A 2026-08-20T00:00:01Z "" glm-5.2 false b)',
  '$(task_rec R3 in_progress A 2026-08-20T00:00:02Z "" glm-5.2 false)',
  '$(task_rec R4 in_progress A 2026-08-20T00:00:03Z "" glm-5.2 false)',
  '$(task_rec R5 in_progress A 2026-08-20T00:00:04Z "" glm-5.2 false)',
  '$(task_rec T100 dispatchable A 2026-08-20T00:01:00Z "" glm-5.2 false a,b)',
]:
    r = json.loads(rec); doc[next(iter(r))] = r[next(iter(r))]
EOF
)"
seed_store "$DOC"
seed_bundle T100 findings/T100.json 99
reset_keeper_state
OUT=$(cd "$ROOT" && "$KEEPER" --once 2>&1); RC=$?
if [ "$RC" -ne 0 ] || ! echo "$OUT" | grep -q "^cap"; then
  echo "    FAIL: entry iteration expected cap (5 running, anchor blocked) (rc=$RC); got:"; echo "$OUT" | sed 's/^/    | /'; FAIL=1
elif [ "$(pressure_field anchor)" = "T100" ] && [ "$(pressure_field drops)" = "0" ]; then
  echo "    PASS: entry anchors T100, drops=0"
else
  echo "    FAIL: entry pressure state anchor=$(pressure_field anchor) drops=$(pressure_field drops) (want T100/0)"; FAIL=1
fi
for pair in "R3 1" "R4 2" "R5 3" "R1 4"; do
  set -- $pair
  COMPLETE_ID="$1"; WANT_DROPS="$2"
  set_row_status "$COMPLETE_ID" done
  OUT=$(cd "$ROOT" && "$KEEPER" --once 2>&1); RC=$?
  DROPS=$(pressure_field drops)
  ANCHOR=$(pressure_field anchor)
  if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "^cap" && [ "$ANCHOR" = "T100" ] && [ "$DROPS" = "$WANT_DROPS" ]; then
    echo "    PASS: $COMPLETE_ID done → drops=$WANT_DROPS (C_eff shrinks), nothing dispatched"
  else
    echo "    FAIL: after $COMPLETE_ID done expected cap+drops=$WANT_DROPS (anchor=$ANCHOR drops=$DROPS rc=$RC); got:"; echo "$OUT" | sed 's/^/    | /'; FAIL=1
  fi
done
set_row_status R2 done
OUT=$(cd "$ROOT" && "$KEEPER" --once 2>&1); RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "^dispatched T100 " && [ "$(pressure_field anchor)" = "" ]; then
  echo "    PASS: R2 done frees T100 → dispatched solo, pressure reset (anchor null)"
else
  echo "    FAIL: after R2 done expected T100 solo dispatch + reset (anchor='$(pressure_field anchor)' rc=$RC); got:"; echo "$OUT" | sed 's/^/    | /'; FAIL=1
fi

# ── T501 §13 arm b: conflict-free still runs under pressure ──────────────
echo "  b. seeded: conflict-free task still runs under pressure"
DOC="$(cat <<EOF
doc = {}
for rec in [
  '$(task_rec R1 in_progress A 2026-08-20T00:00:00Z "" glm-5.2 false a)',
  '$(task_rec T100 dispatchable A 2026-08-20T00:01:00Z "" glm-5.2 false a)',
  '$(task_rec T200 dispatchable A 2026-08-20T00:01:01Z "" glm-5.2 false)',
]:
    r = json.loads(rec); doc[next(iter(r))] = r[next(iter(r))]
EOF
)"
seed_store "$DOC"
seed_bundle T100 findings/T100.json 99
seed_bundle T200 findings/T200.json 50
reset_keeper_state
OUT=$(cd "$ROOT" && "$KEEPER" --once 2>&1); RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "^dispatched T200 " && [ "$(pressure_field anchor)" = "T100" ]; then
  echo "    PASS: T100 anchors pressure; holds-free T200 admitted"
else
  echo "    FAIL: expected T200 dispatched while T100 anchored (rc=$RC anchor=$(pressure_field anchor)); got:"; echo "$OUT" | sed 's/^/    | /'; FAIL=1
fi

# ── T501 §13 arm c: a conflicting mutation never dispatches ──────────────
echo "  c. seeded: a conflicting mutation never dispatches under pressure"
DOC="$(cat <<EOF
doc = {}
for rec in [
  '$(task_rec R1 in_progress A 2026-08-20T00:00:00Z "" glm-5.2 false a)',
  '$(task_rec T100 dispatchable A 2026-08-20T00:01:00Z "" glm-5.2 false a)',
  '$(task_rec T300 dispatchable A 2026-08-20T00:01:01Z "" glm-5.2 false a)',
]:
    r = json.loads(rec); doc[next(iter(r))] = r[next(iter(r))]
EOF
)"
seed_store "$DOC"
seed_bundle T100 findings/T100.json 99
seed_bundle T300 findings/T300.json 90
reset_keeper_state
OUT=$(cd "$ROOT" && "$KEEPER" --once 2>&1); RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "^none" && [ "$(row_status T100)" = "dispatchable" ] && [ "$(row_status T300)" = "dispatchable" ]; then
  echo "    PASS: T300 (holds {a}) never dispatched — its holds intersect the running holder"
else
  echo "    FAIL: expected none with T100/T300 both conflict-blocked (rc=$RC); got:"; echo "$OUT" | sed 's/^/    | /'; FAIL=1
fi

# ── T501 §13 arm d: no blocked next → cap stays C (NORMAL refill) ───────
echo "  d. null: no blocked next → cap stays C, NORMAL refill"
DOC="$(cat <<EOF
doc = {}
for rec in [
  '$(task_rec R1 in_progress A 2026-08-20T00:00:00Z "" glm-5.2 false)',
  '$(task_rec T1 dispatchable A 2026-08-20T00:01:00Z "" glm-5.2 false)',
]:
    r = json.loads(rec); doc[next(iter(r))] = r[next(iter(r))]
EOF
)"
seed_store "$DOC"
seed_bundle T1 findings/T1.json
reset_keeper_state
OUT=$(cd "$ROOT" && "$KEEPER" --once 2>&1); RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "^dispatched T1 " && [ "$(pressure_field anchor)" = "" ] && [ "$(pressure_field drops)" = "0" ]; then
  echo "    PASS: holds-free next → NORMAL (anchor null, drops 0), dispatched"
else
  echo "    FAIL: expected NORMAL refill dispatch (rc=$RC anchor=$(pressure_field anchor) drops=$(pressure_field drops)); got:"; echo "$OUT" | sed 's/^/    | /'; FAIL=1
fi

# ── T501 §13 arm e: free-held task dispatches immediately (no pressure) ──
echo "  e. null: a held task whose hold is free dispatches immediately"
DOC="$(cat <<EOF
doc = {}
for rec in [
  '$(task_rec T100 dispatchable A 2026-08-20T00:01:00Z "" glm-5.2 false a)',
]:
    r = json.loads(rec); doc[next(iter(r))] = r[next(iter(r))]
EOF
)"
seed_store "$DOC"
seed_bundle T100 findings/T100.json 99
reset_keeper_state
OUT=$(cd "$ROOT" && "$KEEPER" --once 2>&1); RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "^dispatched T100 " && [ "$(pressure_field anchor)" = "" ]; then
  echo "    PASS: hold {a} is free (nothing running) → immediate dispatch, NORMAL"
else
  echo "    FAIL: expected immediate dispatch of free-held T100 (rc=$RC); got:"; echo "$OUT" | sed 's/^/    | /'; FAIL=1
fi

# ── T501 §13 arm f: model cooldown binds the pressure path ──────────────
echo "  f. seeded: model cooldown binds the pressure path"
DOC="$(cat <<EOF
doc = {}
for rec in [
  '$(task_rec R1 in_progress A 2026-08-20T00:00:00Z "" glm-5.2 false a)',
  '$(task_rec T100 dispatchable A 2026-08-20T00:01:00Z "" glm-5.2 false a)',
  '$(task_rec T200 dispatchable A 2026-08-20T00:01:01Z "" kimi-k2.7 false)',
]:
    r = json.loads(rec); doc[next(iter(r))] = r[next(iter(r))]
EOF
)"
seed_store "$DOC"
seed_bundle T100 findings/T100.json 99
seed_bundle T200 findings/T200.json 50
reset_keeper_state
export FLEET_MODEL_DENY="kimi-k2.7"
OUT=$(cd "$ROOT" && "$KEEPER" --once 2>&1); RC=$?
unset FLEET_MODEL_DENY
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "^none" && [ "$(row_status T200)" = "dispatchable" ] && [ "$(pressure_field anchor)" = "T100" ]; then
  echo "    PASS: denied model not admitted under pressure (T200 skipped, T100 anchored)"
else
  echo "    FAIL: f1 expected none + T200 skipped (rc=$RC anchor=$(pressure_field anchor)); got:"; echo "$OUT" | sed 's/^/    | /'; FAIL=1
fi
# f2: deny the ANCHOR's model → pressure exits (anchor null), free task runs
seed_store "$DOC"
seed_bundle T100 findings/T100.json 99
seed_bundle T200 findings/T200.json 50
seed_pressure T100 2 "$(python3 -c 'import datetime;print((datetime.datetime.now(datetime.timezone.utc)-datetime.timedelta(minutes=1)).strftime("%Y-%m-%dT%H:%M:%SZ"))')" R1
export FLEET_MODEL_DENY="glm-5.2"
OUT=$(cd "$ROOT" && "$KEEPER" --once 2>&1); RC=$?
unset FLEET_MODEL_DENY
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "^dispatched T200 " && [ "$(pressure_field anchor)" = "" ]; then
  echo "    PASS: anchor's model denied → pressure exits, T200 dispatched"
else
  echo "    FAIL: f2 expected pressure exit + T200 dispatch (rc=$RC anchor=$(pressure_field anchor)); got:"; echo "$OUT" | sed 's/^/    | /'; FAIL=1
fi

# ── T501 §13 arm g: logjam flag after FLEET_LOGJAM_FLAG minutes ──────────
echo "  g. seeded: logjam flag after FLEET_LOGJAM_FLAG minutes (telemetry only)"
DOC="$(cat <<EOF
doc = {}
for rec in [
  '$(task_rec R1 in_progress A 2026-08-20T00:00:00Z "" glm-5.2 false a)',
  '$(task_rec T100 dispatchable A 2026-08-20T00:01:00Z "" glm-5.2 false a)',
]:
    r = json.loads(rec); doc[next(iter(r))] = r[next(iter(r))]
EOF
)"
seed_store "$DOC"
seed_bundle T100 findings/T100.json 99
reset_keeper_state
OLD=$(python3 -c 'import datetime;print((datetime.datetime.now(datetime.timezone.utc)-datetime.timedelta(minutes=61)).strftime("%Y-%m-%dT%H:%M:%SZ"))')
seed_pressure T100 0 "$OLD" R1
export FLEET_LOGJAM_FLAG=60
OUT=$(cd "$ROOT" && "$KEEPER" --once 2>&1); RC=$?
unset FLEET_LOGJAM_FLAG
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "^none" && [ -f "$WORK/untracked/fleet-keeper.logjam.flag" ] && grep -q "T100" "$WORK/untracked/fleet-keeper.logjam.flag" && [ "$(row_status T100)" = "dispatchable" ]; then
  echo "    PASS: flag written, LOGJAM logged, nothing conflicting dispatched"
else
  echo "    FAIL: expected logjam flag + none (rc=$RC); got:"; echo "$OUT" | sed 's/^/    | /'; [ -f "$WORK/untracked/fleet-keeper.logjam.flag" ] && sed 's/^/    flag: /' "$WORK/untracked/fleet-keeper.logjam.flag"; FAIL=1
fi

# ── T514 arm g2: logjam flag cleared on pressure exit (F5 lifecycle) ──────
# F5: the flag is written but never removed when pressure exits, so it
# persists stale (naming a task that is now running while pressure.json
# says NORMAL).  The flag must be cleared by the keeper's own state machine
# the iteration the anchor is released (anchor → null), never hand-pruned.
echo "  g2. seeded: flag written under pressure → holder completes → pressure exits → flag removed (F5)"
DOC="$(cat <<EOF
doc = {}
for rec in [
  '$(task_rec R1 in_progress A 2026-08-20T00:00:00Z "" glm-5.2 false a)',
  '$(task_rec T100 dispatchable A 2026-08-20T00:01:00Z "" glm-5.2 false a)',
]:
    r = json.loads(rec); doc[next(iter(r))] = r[next(iter(r))]
EOF
)"
seed_store "$DOC"
seed_bundle T100 findings/T100.json 99
reset_keeper_state
OLD=$(python3 -c 'import datetime;print((datetime.datetime.now(datetime.timezone.utc)-datetime.timedelta(minutes=61)).strftime("%Y-%m-%dT%H:%M:%SZ"))')
seed_pressure T100 0 "$OLD" R1
export FLEET_LOGJAM_FLAG=60
# iter 1: T100 blocked by R1, waited 61min → flag written, nothing dispatched.
OUT=$(cd "$ROOT" && "$KEEPER" --once 2>&1); RC=$?
if [ "$RC" -eq 0 ] && [ -f "$WORK/untracked/fleet-keeper.logjam.flag" ] && grep -q "T100" "$WORK/untracked/fleet-keeper.logjam.flag"; then
  echo "    PASS: iter 1 wrote the flag naming T100 (blocked, waited 61min)"
else
  echo "    FAIL: g2 iter 1 expected flag naming T100 (rc=$RC); got:"; echo "$OUT" | sed 's/^/    | /'; [ -f "$WORK/untracked/fleet-keeper.logjam.flag" ] && sed 's/^/    flag: /' "$WORK/untracked/fleet-keeper.logjam.flag"; FAIL=1
fi
# iter 2: R1 completes → T100 frees and dispatches, pressure exits → flag removed.
set_row_status R1 done
OUT=$(cd "$ROOT" && "$KEEPER" --once 2>&1); RC=$?
unset FLEET_LOGJAM_FLAG
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "^dispatched T100 " && [ ! -e "$WORK/untracked/fleet-keeper.logjam.flag" ] && [ "$(pressure_field anchor)" = "" ]; then
  echo "    PASS: iter 2 pressure exited → T100 dispatched, flag removed, anchor null"
else
  echo "    FAIL: g2 iter 2 expected T100 dispatched + flag gone + anchor null (rc=$RC); got:"; echo "$OUT" | sed 's/^/    | /'; [ -e "$WORK/untracked/fleet-keeper.logjam.flag" ] && { echo "    stale flag still present:"; sed 's/^/    flag: /' "$WORK/untracked/fleet-keeper.logjam.flag"; }; echo "    anchor=$(pressure_field anchor)"; FAIL=1
fi

# ── T514 arm g3: logjam flag cleared on re-anchor (stale old-anchor flag) ─
# Re-anchor (a different task becomes the blocked next) releases the old
# anchor; its flag names the old anchor and is now stale.  The keeper must
# clear it — the new anchor's fresh waiting_since is below threshold, so no
# new flag is written this iteration either.
echo "  g3. seeded: flag names old anchor → old anchor model-denied, new blocked next → re-anchor clears stale flag"
DOC="$(cat <<EOF
doc = {}
for rec in [
  '$(task_rec R1 in_progress A 2026-08-20T00:00:00Z "" glm-5.2 false a)',
  '$(task_rec R2 in_progress A 2026-08-20T00:00:01Z "" glm-5.2 false b)',
  '$(task_rec T100 dispatchable A 2026-08-20T00:01:00Z "" kimi-k2.7 false a)',
  '$(task_rec T200 dispatchable A 2026-08-20T00:01:01Z "" glm-5.2 false b)',
]:
    r = json.loads(rec); doc[next(iter(r))] = r[next(iter(r))]
EOF
)"
seed_store "$DOC"
seed_bundle T100 findings/T100.json 99
seed_bundle T200 findings/T200.json 90
reset_keeper_state
OLD=$(python3 -c 'import datetime;print((datetime.datetime.now(datetime.timezone.utc)-datetime.timedelta(minutes=61)).strftime("%Y-%m-%dT%H:%M:%SZ"))')
seed_pressure T100 0 "$OLD" R1,R2
export FLEET_LOGJAM_FLAG=60
# iter 1: no deny → T100 (kimi) blocked by R1, waited 61min → flag written naming T100.
OUT=$(cd "$ROOT" && "$KEEPER" --once 2>&1); RC=$?
if [ "$RC" -eq 0 ] && [ -f "$WORK/untracked/fleet-keeper.logjam.flag" ] && grep -q "T100" "$WORK/untracked/fleet-keeper.logjam.flag"; then
  echo "    PASS: iter 1 wrote the flag naming T100 (blocked, waited 61min)"
else
  echo "    FAIL: g3 iter 1 expected flag naming T100 (rc=$RC); got:"; echo "$OUT" | sed 's/^/    | /'; [ -f "$WORK/untracked/fleet-keeper.logjam.flag" ] && sed 's/^/    flag: /' "$WORK/untracked/fleet-keeper.logjam.flag"; FAIL=1
fi
# iter 2: deny kimi → T100 leaves eligible; T200 (glm, holds b, blocked by R2) is the new blocked next → re-anchor.
export FLEET_MODEL_DENY="kimi-k2.7"
OUT=$(cd "$ROOT" && "$KEEPER" --once 2>&1); RC=$?
unset FLEET_MODEL_DENY FLEET_LOGJAM_FLAG
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "^none" && [ ! -e "$WORK/untracked/fleet-keeper.logjam.flag" ] && [ "$(pressure_field anchor)" = "T200" ]; then
  echo "    PASS: iter 2 re-anchored to T200 → stale T100 flag removed, no new flag (waited < 60min)"
else
  echo "    FAIL: g3 iter 2 expected re-anchor T200 + flag gone (rc=$RC); got:"; echo "$OUT" | sed 's/^/    | /'; [ -e "$WORK/untracked/fleet-keeper.logjam.flag" ] && { echo "    stale flag still present:"; sed 's/^/    flag: /' "$WORK/untracked/fleet-keeper.logjam.flag"; }; echo "    anchor=$(pressure_field anchor)"; FAIL=1
fi

# ── T514 arm g4: a hand-planted/stale flag is swept on a NORMAL iteration ─
# "never hand-planted": a flag the keeper did not write (hand-planted, or a
# leftover from a crashed previous run) is removed by the keeper's own sweep
# on the next iteration the pressure condition is false — not a manual `rm`.
echo "  g4. seeded: a hand-planted flag is swept on a NORMAL iteration (never hand-planted)"
DOC="$(cat <<EOF
doc = {}
for rec in [
  '$(task_rec T1 dispatchable A 2026-08-20T00:01:00Z "" glm-5.2 false)',
]:
    r = json.loads(rec); doc[next(iter(r))] = r[next(iter(r))]
EOF
)"
seed_store "$DOC"
seed_bundle T1 findings/T1.json
reset_keeper_state
# Hand-plant a stale flag the pressure state machine never produced.
printf 'T999 hand-planted stale flag waited=999min\n' > "$WORK/untracked/fleet-keeper.logjam.flag"
OUT=$(cd "$ROOT" && "$KEEPER" --once 2>&1); RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "^dispatched T1 " && [ ! -e "$WORK/untracked/fleet-keeper.logjam.flag" ] && [ "$(pressure_field anchor)" = "" ]; then
  echo "    PASS: hand-planted flag swept on a NORMAL iteration; T1 dispatched normally"
else
  echo "    FAIL: g4 expected hand-planted flag removed + T1 dispatched (rc=$RC); got:"; echo "$OUT" | sed 's/^/    | /'; [ -e "$WORK/untracked/fleet-keeper.logjam.flag" ] && echo "    stale flag still present"; echo "    anchor=$(pressure_field anchor)"; FAIL=1
fi

# ── T501 §13 arm h: waiting=1 outranks priority (the bump) ───────────────
echo "  h. seeded: waiting=1 outranks priority; a bumped blocked task anchors pressure"
# h0: nothing blocked → the waiting task is next despite lower priority
DOC="$(cat <<EOF
doc = {}
for rec in [
  '$(task_rec T400 dispatchable A 2026-08-20T00:01:00Z "" glm-5.2 false)',
  '$(task_rec T500 dispatchable A 2026-08-20T00:01:01Z "" glm-5.2 false)',
]:
    r = json.loads(rec); doc[next(iter(r))] = r[next(iter(r))]
EOF
)"
seed_store "$DOC"
seed_bundle T400 findings/T400.json 20 1
seed_bundle T500 findings/T500.json 99
reset_keeper_state
OUT=$(cd "$ROOT" && "$KEEPER" --once 2>&1); RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "^dispatched T400 "; then
  echo "    PASS: waiting=1 (p20) is next over priority 99"
else
  echo "    FAIL: h0 expected T400 (waiting=1) dispatched over T500 (p99) (rc=$RC); got:"; echo "$OUT" | sed 's/^/    | /'; FAIL=1
fi
# h1: the bumped task is conflict-blocked → it anchors pressure
DOC="$(cat <<EOF
doc = {}
for rec in [
  '$(task_rec R1 in_progress A 2026-08-20T00:00:00Z "" glm-5.2 false a)',
  '$(task_rec T400 dispatchable A 2026-08-20T00:01:00Z "" glm-5.2 false a)',
  '$(task_rec T500 dispatchable A 2026-08-20T00:01:01Z "" glm-5.2 false)',
]:
    r = json.loads(rec); doc[next(iter(r))] = r[next(iter(r))]
EOF
)"
seed_store "$DOC"
seed_bundle T400 findings/T400.json 20 1
seed_bundle T500 findings/T500.json 99
reset_keeper_state
OUT=$(cd "$ROOT" && "$KEEPER" --once 2>&1); RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "^dispatched T500 " && [ "$(pressure_field anchor)" = "T400" ]; then
  echo "    PASS: bumped blocked T400 anchors pressure; free T500 (p99) admitted"
else
  echo "    FAIL: h1 expected T400 anchored + T500 dispatched (rc=$RC anchor=$(pressure_field anchor)); got:"; echo "$OUT" | sed 's/^/    | /'; FAIL=1
fi

# ── T504 §5 arm a: a recently-healed row is parked, not re-fired ────────
echo "  T504-a. seeded: claim_count=2 + recent heal → parked for the window; exclusion logged"
DOC="$(cat <<EOF
doc = {}
for rec in [
  '$(task_rec T358 dispatchable A 2026-08-20T00:01:00Z "" glm-5.2 false)',
]:
    r = json.loads(rec); doc[next(iter(r))] = r[next(iter(r))]
EOF
)"
seed_store "$DOC"
seed_bundle T358 findings/T358.json
set_claim_count T358 2
reset_keeper_state
HEAL_TS=$(python3 -c 'import datetime;print(datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))')
seed_heal_log T358 "$HEAL_TS"
OUT=$(cd "$ROOT" && "$KEEPER" --once 2>&1); RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "^none" && [ "$(row_status T358)" = "dispatchable" ]; then
  echo "    PASS: healed T358 parked (not dispatched), row left dispatchable"
else
  echo "    FAIL: expected T358 parked (rc=$RC status=$(row_status T358)); got:"; echo "$OUT" | sed 's/^/    | /'; FAIL=1
fi
if grep -q "heal-cooldown: T358" "$WORK/untracked/log/fleet-keeper.log"; then
  echo "    PASS: exclusion logged (heal-cooldown: T358)"
else
  echo "    FAIL: exclusion not logged"; tail -5 "$WORK/untracked/log/fleet-keeper.log" | sed 's/^/    | /'; FAIL=1
fi
# persistence: a second iteration still parks it (cooldown ongoing, same signal)
OUT2=$(cd "$ROOT" && "$KEEPER" --once 2>&1); RC2=$?
if [ "$RC2" -eq 0 ] && echo "$OUT2" | grep -q "^none"; then
  echo "    PASS: cooldown persists across iterations (still parked)"
else
  echo "    FAIL: expected T358 still parked on the second iteration (rc=$RC2); got:"; echo "$OUT2" | sed 's/^/    | /'; FAIL=1
fi

# ── T504 §5 arm b: after the window the row is eligible again ───────────
echo "  T504-b. null: after the window the row is eligible again (cooldown expires)"
DOC="$(cat <<EOF
doc = {}
for rec in [
  '$(task_rec T358 dispatchable A 2026-08-20T00:01:00Z "" glm-5.2 false)',
]:
    r = json.loads(rec); doc[next(iter(r))] = r[next(iter(r))]
EOF
)"
seed_store "$DOC"
seed_bundle T358 findings/T358.json
set_claim_count T358 2
reset_keeper_state
OLD_EPOCH=$(python3 -c 'import time; print(time.time() - 700)')
seed_heal_state T358 "$OLD_EPOCH" 2 ""
OUT=$(cd "$ROOT" && "$KEEPER" --once 2>&1); RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "^dispatched T358 "; then
  echo "    PASS: expired cooldown → T358 dispatched again"
else
  echo "    FAIL: expected T358 dispatched after the window (rc=$RC); got:"; echo "$OUT" | sed 's/^/    | /'; FAIL=1
fi

# ── T504 §5 arm c: a fresh row is dispatched normally ───────────────────
echo "  T504-c. null: a fresh row (claim_count=1, no heal) is dispatched normally"
DOC="$(cat <<EOF
doc = {}
for rec in [
  '$(task_rec T1 dispatchable A 2026-08-20T00:01:00Z "" glm-5.2 false)',
]:
    r = json.loads(rec); doc[next(iter(r))] = r[next(iter(r))]
EOF
)"
seed_store "$DOC"
seed_bundle T1 findings/T1.json
set_claim_count T1 1
reset_keeper_state
OUT=$(cd "$ROOT" && "$KEEPER" --once 2>&1); RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "^dispatched T1 "; then
  echo "    PASS: fresh T1 (claim_count=1) dispatched normally"
else
  echo "    FAIL: expected T1 dispatched (rc=$RC); got:"; echo "$OUT" | sed 's/^/    | /'; FAIL=1
fi

# ── T504 §5 arm e: a fresh heal record parks even claim_count=1 ─────────
echo "  T504-e. seeded: a fresh T477 heal record with claim_count=1 → parked (the live T358 defect)"
DOC="$(cat <<EOF
doc = {}
for rec in [
  '$(task_rec T358 dispatchable A 2026-08-20T00:01:00Z "" glm-5.2 false)',
]:
    r = json.loads(rec); doc[next(iter(r))] = r[next(iter(r))]
EOF
)"
seed_store "$DOC"
seed_bundle T358 findings/T358.json
set_claim_count T358 1
reset_keeper_state
HEAL_TS=$(python3 -c 'import datetime;print(datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))')
seed_heal_log T358 "$HEAL_TS"
OUT=$(cd "$ROOT" && "$KEEPER" --once 2>&1); RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "^none" && [ "$(row_status T358)" = "dispatchable" ]; then
  echo "    PASS: fresh heal record parks T358 even at claim_count=1"
else
  echo "    FAIL: expected T358 parked on a fresh heal record (rc=$RC status=$(row_status T358)); got:"; echo "$OUT" | sed 's/^/    | /'; FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "=== regression-fleet-keeper: ALL CONTROLS PASSED ==="
  exit 0
else
  echo "=== regression-fleet-keeper: FAILURES ==="
  exit 1
fi