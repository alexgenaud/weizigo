#!/usr/bin/env bash
# regression-directive-kill.sh — T625 controls: a stale directive must not
# kill a fresh dispatch, and a directive-caused kill must never score as a
# model failure.
#
# Defect (T625, 2026-08-22): D047, a `pause` issued 2026-08-20T12:55:28Z,
# carried its discharge condition ("T545 goes first") only in English prose
# inside --note.  T545 closed `done`; nothing re-evaluated D047, so it kept
# killing fresh T544 dispatches — the launch-time check exited 124 and the
# mid-run poll SIGKILLed a running worker at 741 s — and every termination
# surfaced as `verified=fail` against deepseek-v4-pro and deepseek-v4-flash
# in docs/infra/model-perf.md.  The harness killed the worker; the record
# blamed the model.  Two false-negative rows in the ladder.
#
# The fix ships three mechanisms, all tested here:
#   1. discharge-by-condition — `managent tell <t> pause --until-done <row>`
#      is re-evaluated at apply time (the pause discharges when <row> is
#      `done` in the kanban);
#   2. staleness horizon — an unacked pause older than
#      WEIZIGO_DIRECTIVE_STALE_HOURS (default 24) is reported stale, not
#      enforced.  `kill` is never stale (an explicit halt must not expire).
#   3. self-identifying directive kills — tools/runner writes a run record
#      with kill_class=directive at launch-time refusal; tools/dispatch_verify
#      classifies directive kills and records verified=directive-kill (never
#      verified=fail); bin/dispatch refuses to launch a row a pending
#      directive would kill (no tokens spent before anyone learns).
#
# Controls (all hermetic — scratch repo under /tmp/weizigo, scratch
# MANAGENT_STORE / WEIZIGO_MODEL_PERF / WEIZIGO_DISPATCH_HEALS; the live
# kanban and ledger are never touched):
#   seeded  pending un-discharged pause -> bin/dispatch REFUSES before
#           spawning (no worker log created — nothing spent)
#   null    empty inbox -> dispatch proceeds (dry-run byte-identical)
#   seeded  pause --until-done T545 with T545 done -> NOT enforced: the
#           runner runs the command normally and reports the directive
#           discharged
#   seeded  pause --until-done T545 with T545 open -> enforced, as today:
#           the runner exits 124 and bin/dispatch refuses
#   seeded  stale pause (no condition, older than the horizon) -> reported
#           stale, NOT enforced
#   seeded  launch-time directive kill writes a run record naming the
#           directive (kill_class=directive, killed="directive ...")
#   seeded  dispatch_verify classifies a directive-kill run record / worker
#           log as verified=directive-kill — never verified=fail
#   null    a genuine wall-kill run record is still verified=fail (the fix
#           must not become a laundry for real failures — D048's warning)
#   seeded  managent tell --until-done writes the field into the ledger,
#           inbox shows it, ack preserves it, and kill --until-done is
#           refused
#
# Test-first (T625): the whole file is written BEFORE the fix; against the
# 2026-08-22 code every seeded arm FAILS (quote the red), the two null arms
# pass, and after the fix all arms pass.
#
# Task: T625 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-22

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
DISPATCH="$ROOT/bin/dispatch"
RUNNER="$ROOT/tools/runner"
MG=""
if [ -x "$ROOT/zig-out/bin/managent" ]; then
    MG="$ROOT/zig-out/bin/managent"
elif [ -x "$ROOT/bin/managent" ]; then
    MG="$ROOT/bin/managent"
fi
if [ -z "$MG" ]; then
    echo "SKIP: no managent binary found — build with 'zig build' (zig-out/bin/managent) or deploy"
    exit 0
fi
FAIL=0

mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/t625-directive-kill-XXXXXX)" || { echo "regression-directive-kill.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
git init -q
git config user.email t625@test
git config user.name T625
echo base > README.md
mkdir -p docs/infra/managent untracked/log untracked/runs findings
printf 'untracked/\n' > .gitignore
git add -A
git commit -qm base

STORE="$WORK/docs/infra/managent/tasks.json"
DIRECTIVES="$WORK/docs/infra/managent/directives.jsonl"
export MANAGENT_STORE="$STORE"
export WEIZIGO_MODEL_PERF="$WORK/perf-ledger.txt"
export WEIZIGO_DISPATCH_HEALS="$WORK/dispatch-heals.jsonl"
export ROOT WORK STORE
unset WEIZIGO_AGENT_DEPTH || true

now_ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# ── scratch-store row seeds (the shapes the live store uses) ─────────────
rec_disp() {
    printf '"%s":{"status":"dispatchable","agent":null,"bundle":"untracked/%s-bundle.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":null,"done":null,"dispatched":null,"dispatched_to":null,"note":null,"verdict":null,"verdict_note":null,"acceptance":null,"skip_acceptance_reason":null,"claim_count":0}' "$1" "$1"
}
rec_inprog() {
    printf '"%s":{"status":"in_progress","agent":"t625","model":"deepseek-v4-flash","bundle":"untracked/%s-bundle.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"2026-08-01T00:00:01Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"verdict":null,"verdict_note":null,"acceptance":null,"skip_acceptance_reason":null,"claim_count":1}' "$1" "$1"
}
rec_done() {
    printf '"%s":{"status":"done","agent":"t625","model":"deepseek-v4-flash","bundle":"untracked/%s-bundle.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"2026-08-01T00:00:01Z","done":"2026-08-02T00:00:00Z","dispatched":null,"dispatched_to":null,"note":null,"verdict":"pass","verdict_note":null,"acceptance":null,"skip_acceptance_reason":null,"claim_count":1}' "$1" "$1"
}
seed() {  # $1 = JSON body of one or more task records (no trailing comma)
    printf '{\n  %s,\n  "_sys": {"next_id": 9000, "directive_next": 1}\n}\n' "$1" > "$STORE"
}
# dispatchable row + a valid bundle (title gate T505 needs a <40-char title)
mkbundle() {  # $1 = task id
    cat > "untracked/$1-bundle.md" <<EOF
<!--managent set=A deliverables=findings/$1.json-->
# $1 — directive kill seeded

Seeded fixture bundle for the T625 directive-kill regression.
EOF
}

echo "=== regression-directive-kill ==="

# ── seeded 1: pending un-discharged pause -> bin/dispatch REFUSES ─────────
echo "  1. seeded: pending un-discharged pause → bin/dispatch refuses before spawning"
seed "$(rec_disp T6251)"
mkbundle T6251
printf '{"id":"D6251","target":"T6251","directive":"pause","note":"hold until further notice","from":"t625-reg","ts":"%s","read":false}\n' "$(now_ts)" > "$DIRECTIVES"
OUT=$("$DISPATCH" T6251 deepseek-v4-flash --test-root="$WORK" --test-worker=/bin/true 2>&1)
RC=$?
if [ "$RC" -eq 1 ] && printf '%s' "$OUT" | grep -q 'D6251' && [ ! -e untracked/log/t6251.log ]; then
    echo "    PASS: dispatch refused (rc=1), named D6251, nothing spawned"
else
    echo "    FAIL: rc=$RC; expected refusal naming D6251 and no worker log"
    printf '%s' "$OUT" | sed 's/^/      /' | tail -8
    [ -e untracked/log/t6251.log ] && echo "      (worker log WAS created — tokens spent before the refusal)"
    FAIL=1
fi

# ── null 2: empty inbox -> dispatch proceeds (byte-identical) ─────────────
echo "  2. null: empty inbox → dispatch proceeds (dry-run byte-identical)"
: > "$DIRECTIVES"
OUT=$("$DISPATCH" T6251 deepseek-v4-flash --test-root="$WORK" --dry-run 2>&1)
RC=$?
if [ "$RC" -eq 0 ] && printf '%s' "$OUT" | grep -q 'dry-run T6251'; then
    echo "    PASS: dry-run proceeds exactly as before (rc=0)"
else
    echo "    FAIL: rc=$RC; expected a plain dry-run proceed"
    printf '%s' "$OUT" | sed 's/^/      /' | tail -6
    FAIL=1
fi

# ── seeded 3: pause --until-done T545 with T545 done -> NOT enforced ──────
echo "  3. seeded: pause --until-done T545 with T545 done → not enforced, discharge reported"
seed "$(rec_disp T6253),$(rec_done T545)"
printf '{"id":"D6253","target":"T6253","directive":"pause","until_done":"T545","note":"T545 goes first","from":"t625-reg","ts":"%s","read":false}\n' "$(now_ts)" > "$DIRECTIVES"
OUT=$(cd "$WORK" && MANAGENT_TASK_ID=T6253 WEIZIGO_DIRECTIVE_STALE_HOURS=24 "$RUNNER" --no-prepend-zig -- sleep 0.2 2>&1)
RC=$?
if [ "$RC" -eq 0 ] && printf '%s' "$OUT" | grep -qi 'discharged'; then
    echo "    PASS: runner ran normally (rc=0) and reported the pause discharged"
else
    echo "    FAIL: rc=$RC; expected a normal run + discharge report (D047 would have discharged when T545 closed)"
    printf '%s' "$OUT" | sed 's/^/      /' | tail -8
    FAIL=1
fi

# ── seeded 4: pause --until-done T545 with T545 open -> enforced, as today ─
echo "  4. seeded: pause --until-done T545 with T545 open → enforced (runner 124 + dispatch refuses)"
seed "$(rec_disp T6254),$(rec_disp T545)"
mkbundle T6254
printf '{"id":"D6254","target":"T6254","directive":"pause","until_done":"T545","note":"wait for T545","from":"t625-reg","ts":"%s","read":false}\n' "$(now_ts)" > "$DIRECTIVES"
(cd "$WORK" && MANAGENT_TASK_ID=T6254 WEIZIGO_DIRECTIVE_STALE_HOURS=24 "$RUNNER" --no-prepend-zig -- sleep 0.2) >/dev/null 2>&1
RRC=$?
OUT=$("$DISPATCH" T6254 deepseek-v4-flash --test-root="$WORK" --dry-run 2>&1)
DRC=$?
if [ "$RRC" -eq 124 ] && [ "$DRC" -eq 1 ] && printf '%s' "$OUT" | grep -q 'D6254'; then
    echo "    PASS: runner stopped (rc=124) and dispatch refused (rc=1, named D6254)"
else
    echo "    FAIL: runner rc=$RRC dispatch rc=$DRC; expected 124 and a refusal naming D6254"
    FAIL=1
fi

# ── seeded 5: stale pause (no condition, older than the horizon) ──────────
echo "  5. seeded: stale pause (no condition, > 24h unacked) → reported stale, NOT enforced"
seed "$(rec_disp T6255)"
mkbundle T6255
STALE_TS=$(python3 -c "import time; print(time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime(time.time()-25*3600)))")
printf '{"id":"D6255","target":"T6255","directive":"pause","note":"ancient pause","from":"t625-reg","ts":"%s","read":false}\n' "$STALE_TS" > "$DIRECTIVES"
OUT=$(cd "$WORK" && MANAGENT_TASK_ID=T6255 WEIZIGO_DIRECTIVE_STALE_HOURS=24 "$RUNNER" --no-prepend-zig -- sleep 0.2 2>&1)
RRC=$?
DOUT=$("$DISPATCH" T6255 deepseek-v4-flash --test-root="$WORK" --dry-run 2>&1)
DRC=$?
if [ "$RRC" -eq 0 ] && printf '%s' "$OUT" | grep -qi 'stale' && [ "$DRC" -eq 0 ] && printf '%s' "$DOUT" | grep -qi 'stale'; then
    echo "    PASS: runner ran normally + reported stale; dispatch proceeded + reported stale"
else
    echo "    FAIL: runner rc=$RRC dispatch rc=$DRC; expected normal runs with a STALE report"
    printf '%s' "$OUT" | sed 's/^/      | /' | tail -5
    FAIL=1
fi

# ── seeded 6: launch-time directive kill writes a run record ──────────────
echo "  6. seeded: launch-time directive kill writes a run record (kill_class=directive)"
seed "$(rec_disp T6256)"
printf '{"id":"D6256","target":"T6256","directive":"pause","note":"launch refusal","from":"t625-reg","ts":"%s","read":false}\n' "$(now_ts)" > "$DIRECTIVES"
(cd "$WORK" && MANAGENT_TASK_ID=T6256 WEIZIGO_DIRECTIVE_STALE_HOURS=24 "$RUNNER" --no-prepend-zig -- sleep 0.2) >/dev/null 2>&1
RRC=$?
REC="$WORK/untracked/runs/t6256.json"
if [ "$RRC" -eq 124 ] && [ -f "$REC" ] \
   && grep -q '"kill_class": "directive"' "$REC" \
   && grep -q 'D6256' "$REC" \
   && grep -q '"killed": "directive' "$REC"; then
    echo "    PASS: exit 124 AND run record names the directive (kill_class=directive, killed=\"directive ...\")"
else
    echo "    FAIL: runner rc=$RRC; run record $REC"
    [ -f "$REC" ] && cat "$REC" | sed 's/^/      | /'
    [ ! -f "$REC" ] && echo "      (no run record — the kill was rc=124 and a log line, exactly the defect)"
    FAIL=1
fi

# ── seeded 7: dispatch_verify classifies directive kills ──────────────────
# The launch-refusal record exactly as tools/runner now writes it (arm 6),
# plus the pre-fix log-only signature as a fallback (a second row, T6260 —
# the classifier is keyed to real T<digits> ids).  Both must yield
# verified=directive-kill — never verified=fail.
echo "  7. seeded: dispatch_verify records a directive kill as verified=directive-kill, never verified=fail"
seed "$(rec_inprog T6257),$(rec_inprog T6260)"
mkdir -p untracked/runs untracked/log
cat > untracked/runs/t6257.json <<EOF
{"task": "T6257", "pid": 12345, "launcher_pid": 1, "start": "$(now_ts)", "start_epoch": 1, "command": "sleep 0.2", "brief_bytes": 10, "prompt_bytes": 10, "wall_budget": 30, "exit": 124, "wall": 0.0, "kill_class": "directive", "killed": "directive D6257 PAUSE from t625-reg (pending at launch)"}
EOF
# pre-fix fallback: only the worker log carries the old signature
printf '[runner] exit 124 (directive: pause/kill pending)\n' > untracked/log/t6260.log
python3 - "$STORE" <<'PYEOF'
import json, os, sys
sys.path.insert(0, os.environ["ROOT"] + "/tools")
import dispatch_verify
root = os.environ["WORK"]
store = os.environ["STORE"]
nonce = "NONCE-" + "0" * 16

c1 = dispatch_verify.verify_dispatch(
    root=root, task_id="T6257", model="deepseek-v4-flash", nonce=nonce,
    stdout="", rc=124, store_env=store, deliverables=[])
c2 = dispatch_verify.verify_dispatch(
    root=root, task_id="T6260", model="deepseek-v4-flash", nonce=nonce,
    stdout="", rc=124, store_env=store, deliverables=[])
for tag, perf in (("T6257(run-record)", c1[3]), ("T6260(log-fallback)", c2[3])):
    ok = perf[3] == "directive-kill"
    print("    %s -> verified=%s reason=%s (%s)" % (tag, perf[3], perf[4], "PASS" if ok else "FAIL"))
dispatch_verify.record_perf(root, c1[3])
dispatch_verify.record_perf(root, c2[3])
sys.exit(0 if (c1[3][3] == "directive-kill" and c2[3][3] == "directive-kill") else 1)
PYEOF
R1=$?
if [ "$R1" -eq 0 ] && ! grep -q "verified=fail" "$WEIZIGO_MODEL_PERF" \
   && grep -q "verified=directive-kill reason=D6257/pause" "$WEIZIGO_MODEL_PERF" \
   && grep -q "verified=directive-kill reason=unknown/pause" "$WEIZIGO_MODEL_PERF"; then
    echo "    PASS: both classified directive-kill; ledger has no verified=fail row for them"
else
    echo "    FAIL: classification or ledger wrong"
    cat "$WEIZIGO_MODEL_PERF" | sed 's/^/      | /'
    FAIL=1
fi

# ── null 8: a genuine wall-kill is still verified=fail (not laundered) ────
# D021: the same, with the log QUOTING a 429 — a watchdog-killed run whose
# worker quoted an old Ollama 429 from a document must still score as the
# watchdog kill it was (the T526 misclassification: recorded unreached
# reason=provider-429 against a run record that says killed=progress
# timeout).  Uses the REAL fixture log + run record (D021: do not
# synthesise).  SKIPs when the fixture is absent (fresh clone).
echo "  8. null: a genuine wall-kill is still verified=fail fail=row"
seed "$(rec_inprog T6258)"
cat > untracked/runs/t6258.json <<EOF
{"task": "T6258", "pid": 12346, "start": "$(now_ts)", "start_epoch": 1, "command": "sleep 0.2", "wall_budget": 2, "exit": 124, "signal": 9, "wall": 2.1, "killed": "wall ceiling 2s reached"}
EOF
python3 - "$STORE" <<'PYEOF'
import json, os, sys
sys.path.insert(0, os.environ["ROOT"] + "/tools")
import dispatch_verify
code, summary, details, perf = dispatch_verify.verify_dispatch(
    root=os.environ["WORK"], task_id="T6258", model="deepseek-v4-flash",
    nonce="NONCE-" + "0" * 16, stdout="", rc=124,
    store_env=os.environ["STORE"], deliverables=[])
print("    T6258 -> verified=%s reason=%s" % (perf[3], perf[4]))
sys.exit(0 if perf[3] == "fail" and perf[4] == "row" else 1)
PYEOF
if [ $? -eq 0 ]; then
    echo "    PASS: wall-kill still verified=fail fail=row (D048: the fix is not a laundry)"
else
    echo "    FAIL: wall-kill misclassified"
    FAIL=1
fi

# ── seeded 8b (D021): a quoted 429 + watchdog-kill record is the kill, not ─
# a refusal.  Uses the REAL T526 fixture (killed=progress timeout, worker
# quoted a historical 429 mid-run) — the exact false positive T612 found.
if [ -f "$ROOT/untracked/log/t526.log" ] && [ -f "$ROOT/untracked/runs/t526.json" ]; then
    echo "  8b. seeded (D021): quoted-429 log + watchdog-kill run record → verified=fail, never unreached"
    seed "$(rec_inprog T526)"
    mkdir -p untracked/log untracked/runs
    cp "$ROOT/untracked/log/t526.log" untracked/log/t526.log
    cp "$ROOT/untracked/runs/t526.json" untracked/runs/t526.json
    python3 - "$STORE" <<'PYEOF'
import json, os, sys
sys.path.insert(0, os.environ["ROOT"] + "/tools")
import dispatch_verify
root = os.environ["WORK"]
code, summary, details, perf = dispatch_verify.verify_dispatch(
    root=root, task_id="T526", model="deepseek-v4-flash",
    nonce="NONCE-" + "0" * 16, stdout="", rc=124,
    store_env=os.environ["STORE"], deliverables=[])
print("    T526 -> verified=%s reason=%s (run record killed=progress timeout)" % (perf[3], perf[4]))
# the run record names the watchdog kill — a provider refusal must NOT win
sys.exit(0 if perf[3] == "fail" and perf[4] == "row" else 1)
PYEOF
    if [ $? -eq 0 ]; then
        echo "    PASS: quoted-429 log does not launder a watchdog kill into unreached (T526 fixture)"
    else
        echo "    FAIL: quoted-429 log laundered the watchdog kill"
        FAIL=1
    fi
else
    echo "  SKIP 8b: real T526 fixtures absent (fresh clone) — run on the host that owns untracked/"
fi

# ── seeded 8c (D021): a REAL provider limit never scores as a model ───────
# failure.  Uses the REAL T615 fixture (Claude 5-hour session limit: "hit
# your session limit" — one word off the Ollama phrasing the old signature
# list carried) — the exact false negative T612 found.
if [ -f "$ROOT/untracked/log/t615.log" ]; then
    echo "  8c. seeded (D021): real Claude session-limit log → verified=unreached, never fail"
    seed "$(rec_inprog T615)"
    mkdir -p untracked/log
    cp "$ROOT/untracked/log/t615.log" untracked/log/t615.log
    python3 - "$STORE" <<'PYEOF'
import json, os, sys
sys.path.insert(0, os.environ["ROOT"] + "/tools")
import dispatch_verify
root = os.environ["WORK"]
code, summary, details, perf = dispatch_verify.verify_dispatch(
    root=root, task_id="T615", model="claude-fable-5",
    nonce="NONCE-" + "0" * 16, stdout="", rc=1,
    store_env=os.environ["STORE"], deliverables=[])
print("    T615 -> verified=%s reason=%s (log ends: hit your session limit)" % (perf[3], perf[4]))
sys.exit(0 if perf[3] == "unreached" and perf[4] == "provider-429" else 1)
PYEOF
    if [ $? -eq 0 ]; then
        echo "    PASS: real Claude session limit recorded unreached provider-429, not a model failure"
    else
        echo "    FAIL: real Claude session limit not classified unreached"
        FAIL=1
    fi
else
    echo "  SKIP 8c: real T615 fixture absent (fresh clone) — run on the host that owns untracked/"
fi

# ── seeded 8d (D021): a provider limit that CAUSED a harness kill still ───
# scores unreached — the refusal is terminal, not an incidental quote.
# Uses the REAL T616 fixture + run record: the Claude session limit blocked
# the lane, the runner's startup-liveness watchdog then killed the silent
# lane (record: killed=startup liveness timeout, signal 9) — the record
# names the harness, the log's tail names the provider.
if [ -f "$ROOT/untracked/log/t616.log" ] && [ -f "$ROOT/untracked/runs/t616.json" ]; then
    echo "  8d. seeded (D021): refusal that caused a harness kill → verified=unreached (T616 fixture)"
    seed "$(rec_inprog T616)"
    mkdir -p untracked/log untracked/runs
    cp "$ROOT/untracked/log/t616.log" untracked/log/t616.log
    cp "$ROOT/untracked/runs/t616.json" untracked/runs/t616.json
    python3 - "$STORE" <<'PYEOF'
import json, os, sys
sys.path.insert(0, os.environ["ROOT"] + "/tools")
import dispatch_verify
root = os.environ["WORK"]
code, summary, details, perf = dispatch_verify.verify_dispatch(
    root=root, task_id="T616", model="claude-opus-5",
    nonce="NONCE-" + "0" * 16, stdout="", rc=124,
    store_env=os.environ["STORE"], deliverables=[])
print("    T616 -> verified=%s reason=%s (record: startup liveness timeout; log tail: hit your session limit)" % (perf[3], perf[4]))
sys.exit(0 if perf[3] == "unreached" and perf[4] == "provider-429" else 1)
PYEOF
    if [ $? -eq 0 ]; then
        echo "    PASS: harness-kill-with-terminal-refusal recorded unreached provider-429, not a model failure"
    else
        echo "    FAIL: T616 misclassified"
        FAIL=1
    fi
else
    echo "  SKIP 8d: real T616 fixture absent (fresh clone) — run on the host that owns untracked/"
fi

# ── seeded 9: managent tell --until-done (write / display / ack / refuse) ─
echo "  9. seeded: tell --until-done writes+displays+survives ack; kill --until-done refused"
seed "$(rec_inprog T6259)"
: > "$DIRECTIVES"
"$MG" tell T6259 pause --until-done T545 --note 'until T545 closes' >/dev/null 2>&1
WROTE=FAIL
python3 - "$DIRECTIVES" <<'PYEOF' && WROTE=PASS
import json, sys
recs = [json.loads(l) for l in open(sys.argv[1]) if l.strip()]
assert len(recs) == 1, recs
assert recs[0]["directive"] == "pause", recs[0]
assert recs[0].get("until_done") == "T545", recs[0]
PYEOF
SHOWN=FAIL
"$MG" inbox T6259 2>/dev/null | grep -q 'until_done: T545' && SHOWN=PASS
ACKED=FAIL
"$MG" inbox T6259 --ack >/dev/null 2>&1
python3 - "$DIRECTIVES" <<'PYEOF' && ACKED=PASS
import json, sys
rec = [json.loads(l) for l in open(sys.argv[1]) if l.strip()][0]
assert rec["read"] is True, rec
assert rec.get("until_done") == "T545", rec
PYEOF
KREF=0
"$MG" tell T6259 kill --until-done T545 >/dev/null 2>&1 || KREF=1
if [ "$WROTE" = "PASS" ] && [ "$SHOWN" = "PASS" ] && [ "$ACKED" = "PASS" ] && [ "$KREF" -eq 1 ]; then
    echo "    PASS: until_done written, shown in inbox, survives ack; kill --until-done refused"
else
    echo "    FAIL: wrote=$WROTE shown=$SHOWN acked=$ACKED kill-refused=$KREF"
    cat "$DIRECTIVES" | sed 's/^/      | /'
    FAIL=1
fi

# ── cleanup + verdict ─────────────────────────────────────────────────────
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-directive-kill: all controls passed ==="
    exit 0
else
    echo "=== regression-directive-kill: FAILURES (see above) ==="
    exit 1
fi
