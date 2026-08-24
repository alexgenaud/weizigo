#!/usr/bin/env bash
# regression-dispatch-caps.sh — T845 controls for bin/dispatch's fleet-cap gate
#
# T845's gap: tools/fleet-keeper.sh reads FLEET_CAP (default 5) and
# FLEET_FAMILY_CAP (per-family, "family=N") and refuses over them, but
# bin/dispatch — the door nearly all work actually launches through —
# contained ZERO references to either variable.  While the keeper sat
# refusing at 1, twelve workers ran (7 ollama + 5 deepseek), all dispatched
# explicitly.  Two doors, one gated — the fourth instance of the class.
#
# These controls pin the fix:
#
#   cap-2      FLEET_CAP=2 with two rows in_progress: a third dispatch is
#              REFUSED with the count (2/2) and the waiting tasks named;
#              one row leaves in_progress (reopen), the third succeeds.
#   family     FLEET_FAMILY_CAP="claude=1" with a claude row running:
#              a second claude dispatch is refused (1/1), a deepseek one
#              is allowed.
#   override   --override-cap=<reason> bypasses the caps for THIS dispatch
#              and records the reason to untracked/fleet-cap-overrides.jsonl
#              (real dispatch); an override without a reason is refused;
#              a dry-run override is reported but NOT recorded (a dry-run
#              is not a decision, T677 precedent).
#   null       under the cap, dispatch behaves exactly as today.
#   keeper     the keeper's log format is unchanged (`at cap (2/2) — no
#              dispatch`, `family-cap: ... at cap 1/1 — not dispatched`)
#              and its COUNT matches bin/dispatch's count — one counter,
#              one definition, from the same helper (tools/fleet_caps.py).
#   one-writer a dispatch whose holds intersect a RUNNING task's holds is
#              refused, naming the file and the holder; a different file
#              is allowed; --override-cap does NOT bypass this (T500, the
#              operator's non-negotiable).
#
# All fixtures are synthetic and run in a scratch dir under /tmp/weizigo —
# never the live repo, never the live kanban (MANAGENT_STORE), never
# docs/infra/model-perf.md (WEIZIGO_MODEL_PERF), never
# docs/infra/dispatch-heals.jsonl (WEIZIGO_DISPATCH_HEALS).  bin/dispatch
# is invoked with --test-root=$WORK; the keeper with FLEET_ROOT=$WORK, so
# every bundle/log/cooldown lands in scratch.  Fixture ids are T870x —
# above every live task — so the closing isolation scan can prove the
# suite wrote nothing to the live telemetry.
#
# Task: T845 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-24

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/.."
DISPATCH="$ROOT/bin/dispatch"
KEEPER="$ROOT/tools/fleet-keeper.sh"
MG="$ROOT/bin/managent"
FAIL=0

mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/t845-caps-XXXXXX)" || { echo "regression-dispatch-caps.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

# A stale depth stamp from a worker-run suite would trip the delegation-cap
# control before the caps gate is ever reached.
unset WEIZIGO_AGENT_DEPTH || true

# ── scratch repo + store ─────────────────────────────────────────────────
cd "$WORK"
git init -q
git config user.email t845@test
git config user.name T845
echo base > README.md
mkdir -p docs untracked
printf 'untracked/\n' > .gitignore
git add README.md .gitignore
git commit -qm base

STORE="$WORK/docs/infra/managent/tasks.json"
export MANAGENT_STORE="$STORE"
export WEIZIGO_MODEL_PERF="$WORK/perf-ledger.txt"
export WEIZIGO_DISPATCH_HEALS="$WORK/dispatch-heals.jsonl"
export REAL_MG="$MG"
# The keeper reads bundles/cooldown/log from FLEET_ROOT and forwards it to
# bin/dispatch as --test-root, so every keeper firing lands in scratch too.
export FLEET_ROOT="$WORK"

# ── live-telemetry baselines (isolation scan, T512 shape) ────────────────
LIVE_HEALS="$ROOT/docs/infra/dispatch-heals.jsonl"
LIVE_PERF="$ROOT/docs/infra/model-perf.md"
LIVE_HEALS_BASE=$(wc -l < "$LIVE_HEALS" 2>/dev/null || echo 0)
LIVE_PERF_BASE=$(wc -l < "$LIVE_PERF" 2>/dev/null || echo 0)

# ── stub worker (honest): claims the row and exits — stays in_progress so
#    a later dispatch stays refused, exactly the shape the keeper suite's
#    own stub uses.  Only the override arm's REAL dispatch runs it.
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
export FLEET_TEST_WORKER="$WORK/stub.py"

seed_task() {  # $1=id  $2=deliverable  $3=holds(optional)
    local meta="set=A type=infra deliverables=$2"
    [ -n "${3:-}" ] && meta="$meta holds=$3"
    printf '<!--managent %s-->\n# %s — T845 caps regression bundle\n**Landmark:** advances `L1 (dispatch tooling)` — fixture\n' "$meta" "$1" \
        > "$WORK/untracked/$1-bundle.md"
    "$MG" add "$1" >/dev/null 2>&1 || { echo "    FAIL: managent add $1"; FAIL=1; }
}

set_row_model() {  # $1=id  $2=model — the keeper reads a row's STORED model
    python3 - "$STORE" "$1" "$2" <<'PY'
import json, sys
store, tid, model = sys.argv[1], sys.argv[2], sys.argv[3]
doc = json.load(open(store))
doc[tid]["model"] = model
json.dump(doc, open(store, "w"), indent=1)
PY
}

# The earlier arms leave rows in_progress (claimed fixtures).  The keeper
# arms need a DETERMINISTIC store: exactly the rows each arm declares, no
# carry-over — regression-fleet-keeper.sh's seed_store precedent.
fresh_store() {
    python3 - "$STORE" <<'PY'
import json, sys
json.dump({}, open(sys.argv[1], "w"), indent=1)
PY
}

reset_keeper_state() {  # fresh keeper state so each keeper arm starts clean
    rm -f "$WORK/untracked/fleet-keeper.pressure.json"
    rm -f "$WORK/untracked/fleet-keeper.logjam.flag"
    rm -f "$WORK/untracked/fleet-keeper.heal.json"
    rm -f "$WORK/untracked/fleet-keeper.attempts.json"
    rm -f "$WORK/untracked/fleet-keeper.lane-down.json"
    rm -rf "$WORK/untracked/fleet-keeper.lock"
    rm -f "$WORK/untracked/fleet-keeper.wake"
    : > "$WORK/untracked/log/fleet-keeper.log"
}

row_status() {  # $1=id — status word from `managent show`
    "$MG" show "$1" 2>/dev/null | awk 'NR==2 && NF>=2 {print $2}'
}

echo "=== bin/dispatch fleet-cap regression (T845) ==="

# ── 1. total-cap fixture: 2 running, third refused; one leaves, third wins ─
echo "  1. cap-2: two in_progress → third dispatch refused with count;"
echo "     one row leaves in_progress → third succeeds"
seed_task T8701 findings/T8701.json
seed_task T8702 findings/T8702.json
seed_task T8703 findings/T8703.json
"$MG" claim T8701 --agent deepseek-v4-flash >/dev/null 2>&1
"$MG" claim T8702 --agent deepseek-v4-flash >/dev/null 2>&1
OUT=$(cd "$ROOT" && FLEET_CAP=2 "$DISPATCH" T8703 deepseek-v4-flash --dry-run --test-root="$WORK" 2>&1)
RC=$?
if [ "$RC" -ne 0 ] \
   && echo "$OUT" | grep -q "total cap: 2/2" \
   && echo "$OUT" | grep -q "T8701" \
   && echo "$OUT" | grep -q "T8702"; then
    echo "    PASS: refused at cap, message names cap 2/2 + both running tasks (rc=$RC)"
else
    echo "    FAIL: rc=$RC; expected cap refusal naming 2/2 and T8701/T8702"
    echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi
if [ -e "$WORK/untracked/log/t8703.log" ]; then
    echo "    FAIL: cap refusal spawned a dispatch (log exists)"
    FAIL=1
else
    echo "    PASS: nothing spawned on refusal"
fi
"$MG" reopen T8701 >/dev/null 2>&1
OUT=$(cd "$ROOT" && FLEET_CAP=2 "$DISPATCH" T8703 deepseek-v4-flash --dry-run --test-root="$WORK" 2>&1)
RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "dry-run T8703"; then
    echo "    PASS: one row left in_progress → third dispatch succeeded (rc=$RC)"
else
    echo "    FAIL: rc=$RC; expected success after T8701 left in_progress"
    echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi

# ── 2. per-family: claude at cap 1 → second claude refused, deepseek allowed ─
echo "  2. family: FLEET_FAMILY_CAP=claude=1 with a claude row running →"
echo "     second claude refused (1/1), deepseek allowed"
seed_task T8704 findings/T8704.json
seed_task T8705 findings/T8705.json
seed_task T8706 findings/T8706.json
"$MG" claim T8704 --agent claude-opus-5 >/dev/null 2>&1
OUT=$(cd "$ROOT" && FLEET_FAMILY_CAP="claude=1" "$DISPATCH" T8705 claude-sonnet-5 --dry-run --test-root="$WORK" 2>&1)
RC=$?
if [ "$RC" -ne 0 ] \
   && echo "$OUT" | grep -q "family claude is at its cap: 1/1" \
   && echo "$OUT" | grep -q "T8704"; then
    echo "    PASS: second claude refused, named family cap 1/1 + running T8704 (rc=$RC)"
else
    echo "    FAIL: rc=$RC; expected family-cap refusal naming 1/1 and T8704"
    echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi
OUT=$(cd "$ROOT" && FLEET_FAMILY_CAP="claude=1" "$DISPATCH" T8706 deepseek-v4-flash --dry-run --test-root="$WORK" 2>&1)
RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "dry-run T8706"; then
    echo "    PASS: deepseek dispatch allowed under the claude cap (rc=$RC)"
else
    echo "    FAIL: rc=$RC; expected deepseek to be allowed"
    echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi

# ── 3. override: recorded with reason; reason required; dry-run not recorded ─
echo "  3. override: without a reason → refused; with reason → bypass +"
echo "     recorded to the ledger (real dispatch); dry-run → not recorded"
fresh_store
seed_task T8707 findings/T8707.json
seed_task T8708 findings/T8708.json
"$MG" claim T8707 --agent deepseek-v4-flash >/dev/null 2>&1
OUT=$(cd "$ROOT" && FLEET_CAP=1 "$DISPATCH" T8708 deepseek-v4-flash --dry-run --test-root="$WORK" 2>&1)
RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "total cap: 1/1"; then
    echo "    PASS: at cap 1/1 without override → refused (rc=$RC)"
else
    echo "    FAIL: rc=$RC; expected cap refusal at 1/1"
    echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi
OUT=$(cd "$ROOT" && FLEET_CAP=1 "$DISPATCH" T8708 deepseek-v4-flash --dry-run \
        --override-cap="operator checked the fleet" --test-root="$WORK" 2>&1)
RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "dry-run T8708" && echo "$OUT" | grep -qi "override"; then
    echo "    PASS: override with reason bypassed the cap in dry-run (rc=$RC)"
else
    echo "    FAIL: rc=$RC; expected override to bypass in dry-run"
    echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi
if [ -e "$WORK/untracked/fleet-cap-overrides.jsonl" ]; then
    echo "    FAIL: dry-run override recorded to the ledger (a dry-run is not a decision)"
    FAIL=1
else
    echo "    PASS: dry-run override NOT recorded"
fi
OUT=$(cd "$ROOT" && FLEET_CAP=1 "$DISPATCH" T8708 deepseek-v4-flash --dry-run \
        --override-cap= --test-root="$WORK" 2>&1)
RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "requires a reason"; then
    echo "    PASS: empty override reason refused (rc=$RC)"
else
    echo "    FAIL: rc=$RC; expected 'requires a reason' for --override-cap="
    echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi
OUT=$(cd "$ROOT" && FLEET_CAP=1 "$DISPATCH" T8708 deepseek-v4-flash --dry-run \
        --override-cap --test-root="$WORK" 2>&1)
RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "requires a reason"; then
    echo "    PASS: bare --override-cap refused (rc=$RC)"
else
    echo "    FAIL: rc=$RC; expected 'requires a reason' for bare --override-cap"
    echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi
rm -f "$WORK/untracked/fleet-cap-overrides.jsonl"
OUT=$(cd "$ROOT" && FLEET_CAP=1 "$DISPATCH" T8708 deepseek-v4-flash \
        --override-cap="operator checked the fleet" --test-root="$WORK" --test-worker="$WORK/stub.py" 2>&1)
RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "^dispatched T8708"; then
    echo "    PASS: real dispatch with override succeeded, data line printed (rc=$RC)"
else
    echo "    FAIL: rc=$RC; expected 'dispatched T8708'"
    echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi
if [ -f "$WORK/untracked/fleet-cap-overrides.jsonl" ] \
   && grep -q '"task": "T8708"' "$WORK/untracked/fleet-cap-overrides.jsonl" \
   && grep -q "operator checked the fleet" "$WORK/untracked/fleet-cap-overrides.jsonl"; then
    echo "    PASS: override recorded with its reason to the scratch ledger"
else
    echo "    FAIL: override not recorded with reason"
    cat "$WORK/untracked/fleet-cap-overrides.jsonl" 2>/dev/null | sed 's/^/    | /'
    FAIL=1
fi

# ── 4. null: under the cap, dispatch behaves exactly as today ─────────────
echo "  4. null: under the cap, dispatch behaves exactly as today"
seed_task T8709 findings/T8709.json
OUT=$(cd "$ROOT" && "$DISPATCH" T8709 deepseek-v4-flash --dry-run --test-root="$WORK" 2>&1)
RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "dry-run T8709" && ! echo "$OUT" | grep -q "REFUSED"; then
    echo "    PASS: zero in_progress → dry-run dispatched (rc=$RC)"
else
    echo "    FAIL: rc=$RC; expected plain dry-run under the cap"
    echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi

# ── 5. keeper: log format unchanged + the shared counter (one definition) ─
# The keeper's count and bin/dispatch's count must agree: same fixture, both
# doors report 2/2 (total) and 1/1 (family) — one counter, one helper.
echo "  5. keeper: unchanged log format + shared counter (total 2/2)"
fresh_store
seed_task T8701 findings/T8701.json
seed_task T8702 findings/T8702.json
seed_task T8703 findings/T8703.json
"$MG" claim T8701 --agent deepseek-v4-flash >/dev/null 2>&1
"$MG" claim T8702 --agent deepseek-v4-flash >/dev/null 2>&1
reset_keeper_state
O=$(cd "$ROOT" && FLEET_CAP=2 FLEET_MODEL_DENY="" "$KEEPER" --once 2>&1)
RC=$?
if [ "$RC" -eq 0 ] && echo "$O" | grep -q "^cap$"; then
    echo "    PASS: keeper --once at cap printed 'cap' (rc=$RC)"
else
    echo "    FAIL: rc=$RC; expected keeper to print 'cap'"
    echo "$O" | sed 's/^/    | /'
    FAIL=1
fi
if grep -q "at cap (2/2) — no dispatch" "$WORK/untracked/log/fleet-keeper.log"; then
    echo "    PASS: keeper log format unchanged: 'at cap (2/2) — no dispatch'"
else
    echo "    FAIL: keeper log lacks 'at cap (2/2) — no dispatch'"
    tail -5 "$WORK/untracked/log/fleet-keeper.log" | sed 's/^/    | /'
    FAIL=1
fi
echo "  5b. keeper: shared counter (family 1/1) + family-cap log line"
fresh_store
seed_task T8710 findings/T8710.json
seed_task T8711 findings/T8711.json
seed_task T8712 findings/T8712.json
"$MG" claim T8710 --agent claude-opus-5 >/dev/null 2>&1
set_row_model T8711 claude-opus-5
set_row_model T8712 deepseek-v4-flash
reset_keeper_state
O=$(cd "$ROOT" && FLEET_FAMILY_CAP="claude=1" FLEET_MODEL_DENY="" "$KEEPER" --once 2>&1)
RC=$?
if [ "$RC" -eq 0 ] && echo "$O" | grep -q "^dispatched T8712 deepseek-v4-flash"; then
    echo "    PASS: keeper dispatched the deepseek lane under the claude cap (rc=$RC)"
else
    echo "    FAIL: rc=$RC; expected T8712 (deepseek) dispatched"
    echo "$O" | sed 's/^/    | /'
    FAIL=1
fi
if grep -q "family-cap: T8711 family claude at cap 1/1" "$WORK/untracked/log/fleet-keeper.log"; then
    echo "    PASS: keeper family-cap line format unchanged: 'family-cap: T8711 family claude at cap 1/1'"
else
    echo "    FAIL: keeper log lacks the family-cap line"
    tail -5 "$WORK/untracked/log/fleet-keeper.log" | sed 's/^/    | /'
    FAIL=1
fi

# ── 6. one-writer: holds intersect a running task → refused, override does
#    not bypass; a different file is allowed ───────────────────────────────
echo "  6. one-writer: held file refused naming the holder; different file"
echo "     allowed; --override-cap does not bypass the doctrine"
seed_task T8713 findings/T8713.json "src/retro.zig"
seed_task T8714 findings/T8714.json "src/retro.zig"
seed_task T8715 findings/T8715.json "src/rules.zig"
"$MG" claim T8713 --agent deepseek-v4-flash >/dev/null 2>&1
OUT=$(cd "$ROOT" && "$DISPATCH" T8714 deepseek-v4-flash --dry-run --test-root="$WORK" 2>&1)
RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "src/retro.zig" && echo "$OUT" | grep -q "T8713"; then
    echo "    PASS: held file refused, named the file + holder T8713 (rc=$RC)"
else
    echo "    FAIL: rc=$RC; expected one-writer refusal naming src/retro.zig + T8713"
    echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi
OUT=$(cd "$ROOT" && "$DISPATCH" T8714 deepseek-v4-flash --dry-run \
        --override-cap="operator checked" --test-root="$WORK" 2>&1)
RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "src/retro.zig"; then
    echo "    PASS: override does NOT bypass the one-writer refusal (rc=$RC)"
else
    echo "    FAIL: rc=$RC; expected one-writer refusal even with --override-cap"
    echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi
OUT=$(cd "$ROOT" && "$DISPATCH" T8715 deepseek-v4-flash --dry-run --test-root="$WORK" 2>&1)
RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "dry-run T8715"; then
    echo "    PASS: different file allowed (rc=$RC)"
else
    echo "    FAIL: rc=$RC; expected src/rules.zig dispatch to be allowed"
    echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi

# ── isolation: nothing of the suite reached live telemetry ────────────────
echo "  7. isolation: live dispatch-heals + model-perf gained no fixture data"
ISO_FAIL=0
APPENDED=$(tail -n +$((LIVE_HEALS_BASE + 1)) "$LIVE_HEALS" 2>/dev/null)
if [ -z "$APPENDED" ]; then
    echo "    PASS: docs/infra/dispatch-heals.jsonl — no lines appended during the run"
elif echo "$APPENDED" | grep -qE '"task_id": "T87(0[1-9]|1[0-5])"'; then
    echo "    FAIL: fixture heal record(s) appended to the LIVE heal log"
    echo "$APPENDED" | grep -nE '"task_id": "T87(0[1-9]|1[0-5])"' | sed 's/^/    | /'
    ISO_FAIL=1
else
    echo "    PASS: docs/infra/dispatch-heals.jsonl — appended lines carry no fixture data"
fi
APPENDED=$(tail -n +$((LIVE_PERF_BASE + 1)) "$LIVE_PERF" 2>/dev/null)
if [ -z "$APPENDED" ]; then
    echo "    PASS: docs/infra/model-perf.md — no lines appended during the run"
elif echo "$APPENDED" | grep -qE ' T87(0[1-9]|1[0-5]) '; then
    echo "    FAIL: fixture perf line(s) appended to the LIVE model-perf.md"
    echo "$APPENDED" | grep -nE ' T87(0[1-9]|1[0-5]) ' | sed 's/^/    | /'
    ISO_FAIL=1
else
    echo "    PASS: docs/infra/model-perf.md — appended lines carry no fixture data"
fi
[ "$ISO_FAIL" -eq 0 ] || FAIL=1

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-dispatch-caps: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-dispatch-caps: FAILURES ==="
    exit 1
fi
