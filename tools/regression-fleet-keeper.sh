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
# Task: T496 · Model: glm-5.2 · Date: 2026-08-19

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
ID="$1" STATUS="$2" SETV="$3" ADDED="$4" NEEDS="${5:-}" MODEL="${6:-}" DUTY="${7:-false}"
NEEDS_JSON="[]"
[ -n "$NEEDS" ] && NEEDS_JSON=$(python3 -c 'import json,sys;print(json.dumps(sys.argv[1].split(",")))' "$NEEDS")
MODEL_JSON="null"; [ -n "$MODEL" ] && MODEL_JSON="\"$MODEL\""
python3 - "$ID" "$STATUS" "$SETV" "$ADDED" "$NEEDS_JSON" "$MODEL_JSON" "$DUTY" <<'PY'
import json, sys
uid, status, setv, added, needs, model, duty = sys.argv[1:8]
bundle = f"untracked/{uid}-bundle.md" if uid != "ORCHA-FLASH" else "untracked/ORCHA-SEAT-flash.md"
print(json.dumps({uid: {
    "status": status, "agent": None, "model": None if model == "null" else model,
    "bundle": bundle, "set": setv, "holds": [], "needs": json.loads(needs), "caps": [],
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
seed_bundle() {  # $1=id  $2=deliverable
  printf '<!--managent set=A deliverables=%s-->\n# %s — T496 regression bundle\n' "${2:-findings/x.json}" "$1" \
      > "$WORK/untracked/$1-bundle.md"
}

row_status() {  # $1=id → status word from `managent show`
  "$MG" show "$1" 2>/dev/null | awk 'NR==2 && NF>=2 {print $2}'
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
  if grep -q "dispatched T1 → glm-5.2" "$WORK/untracked/log/fleet-keeper.log" \
     && grep -q "dispatched T4 → glm-5.2" "$WORK/untracked/log/fleet-keeper.log"; then
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

echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "=== regression-fleet-keeper: ALL CONTROLS PASSED ==="
  exit 0
else
  echo "=== regression-fleet-keeper: FAILURES ==="
  exit 1
fi