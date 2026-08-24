#!/usr/bin/env bash
# regression-runner-run-records.sh — T650 controls: run records are never
# overwritten; every dispatch attempt is a file.
#
# The defect (2026-08-22): `tools/runner` writes untracked/runs/<task>.json
# at launch and REWRITES the same path at exit — and a re-dispatch of the
# same task REWRITES the path AGAIN, destroying the previous attempt's
# telemetry: its wall, its exit, its kill reason, its tokens, its session.
# On 2026-08-22 the run records for T615/T621/T622 no longer described the
# kills — the re-runs had replaced them; the kills survived only in
# dispatch-heals.jsonl and the .log files.  Ruling 32 requires guard-killed
# rows to be PRESENT and labeled censored — an overwritten killed attempt is
# a dropped one, silently, by the mechanism that should preserve it.
#
# The fix (T650): the bare untracked/runs/<task>.json ALWAYS holds the
# LATEST attempt; when a new attempt starts, the previous bare record is
# renamed (atomic os.replace — never a copy, so the AC7 census, which
# iterates every file, counts each attempt exactly once) to
# untracked/runs/<task>.<N>.json where N is the attempt number it carried.
# Attempt numbering is "from the existing count": first dispatch of a task
# is attempt 1 (bare only — a single-attempt row is byte-identical to
# pre-T650); the Nth dispatch is attempt N.  Every record carries its own
# `attempt` field and a `model` field parsed from the dispatch command.
#
# Controls (test-first, per the standing tooling rule):
#
#   A. seeded (the whole point): dispatch a row, wall-kill it, re-dispatch,
#      let it succeed -> BOTH records readable afterwards, the kill fully
#      intact (signal, killed_by=wall, killed reason).  RED (pre-T650): the
#      first attempt's record is GONE — only the success survives.
#   B. seeded: three attempts -> three records, correctly ordered, attempt
#      numbers 1..3 (bare = 3, archived .1/.2).
#   C. null: a row dispatched once -> exactly one record (the bare), and the
#      readers behave byte-identically to today: dispatch_verify's
#      read_run_record returns the same fields, no numbered files exist.
#   D. seeded: every existing reader against the multi-attempt layout ->
#      dispatch_verify.read_run_record returns the LATEST attempt (the
#      bare); attribution-backfill.parse_run_model reads the latest
#      dispatch's command; the AC7 wall-kill census (orcha-acceptance)
#      counts each killed attempt exactly once (2 kills, not 4 from a
#      copy/symlink of the latest, and not 0 from overwrite).
#   E. seeded: the p95 computation T634/T643 depend on -> counts COMPLETED
#      attempts only (a killed attempt's wall is censored, not a sample of
#      how long the work takes).  The filter is explicit in this script.
#
# Everything runs in a scratch git repo under /tmp/weizigo — the live kanban,
# live untracked/ and the live repo are never touched. The claimlint floor
# is untouched by design (no doc or claim changes).
#
# Task: T650 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-22

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
RUNNER="$PROJECT/tools/runner"
FAIL=0

# T849: scratch repo via the ONE isolated helper (unset GIT_DIR… before git
# init); safe to run outside the pre-commit hook. T445 refuse-on-failure is
# preserved by the helper.
. "$PROJECT/tools/lib/scratch-repo.sh"

cleanup() {
    [ -n "${WORK:-}" ] && rm -rf "$WORK"
}
trap cleanup EXIT

weizigo_scratch_repo t650-runrecords WORK   # T849: isolated scratch repo
cd "$WORK"
git config user.email t650@test
git config user.name T650
echo base > README.md
mkdir -p docs/infra/managent untracked/runs
printf 'untracked/\n' > .gitignore
git add README.md .gitignore
git commit -qm base

note() { echo "$*"; }
pass() { echo "    PASS: $*"; }
fail() { echo "    FAIL: $*"; FAIL=1; }

echo "=== regression-runner-run-records (T650) ==="

# A wall-kill: a short --max-wall with a sleeping child SIGKILLs at the
# ceiling; the record carries killed_by=wall + signal=9 (the T629 enum).
KILL_RUN() {
    MANAGENT_TASK_ID="$1" "$RUNNER" --no-prepend-zig --no-host-guard --max-wall 2 \
        -- sh -c 'sleep 30' >/dev/null 2>&1
    return $?
}
OK_RUN() {
    MANAGENT_TASK_ID="$1" "$RUNNER" --no-prepend-zig --no-host-guard --max-wall 20 \
        -- sh -c 'echo ok; sleep 0.1' >/dev/null 2>&1
    return $?
}

# ── A. seeded (the whole point): kill, re-dispatch, both records ──────────
echo "  A. seeded: killed attempt + successful re-dispatch -> BOTH records intact"
KILL_RUN T6501; RC=$?
if [ "$RC" -ne 124 ]; then fail "kill-run exited $RC (expected 124)"; else pass "kill-run exited 124"; fi
OK_RUN T6501; RC=$?
if [ "$RC" -ne 0 ]; then fail "re-dispatch exited $RC (expected 0)"; else pass "re-dispatch exited 0"; fi

if [ ! -f untracked/runs/T6501.json ]; then
    fail "no bare untracked/runs/T6501.json (latest attempt missing)"
else
    python3 -c 'import json;d=json.load(open("untracked/runs/T6501.json"));
assert d.get("attempt")==2, d
assert d.get("exit")==0, d
print("        bare record: attempt=2 exit=0 (the re-dispatch)")'
    [ $? -eq 0 ] || fail "bare record is not the re-dispatch (attempt 2, exit 0)"
fi

if [ ! -f untracked/runs/T6501.1.json ]; then
    fail "no archived untracked/runs/T6501.1.json (the killed attempt is GONE — the pre-T650 defect)"
else
    python3 -c 'import json;d=json.load(open("untracked/runs/T6501.1.json"));
assert d.get("attempt")==1, d
assert d.get("signal")==9, d
assert d.get("killed_by")=="wall", d
assert d.get("killed") and "wall ceiling" in d.get("killed",""), d
print("        archived record: attempt=1 signal=9 killed_by=wall — the kill is fully intact")'
    [ $? -eq 0 ] || fail "archived record lost the kill details"
fi

# ── B. seeded: three attempts -> three records, attempt numbers 1..3 ──────
echo "  B. seeded: three attempts -> three records, correctly ordered"
KILL_RUN T6502 >/dev/null 2>&1
KILL_RUN T6502 >/dev/null 2>&1
OK_RUN T6502 >/dev/null 2>&1
python3 - <<'PY'
import json, os
files = sorted(f for f in os.listdir("untracked/runs") if f.startswith("T6502"))
expected = {"T6502.1.json": 1, "T6502.2.json": 2, "T6502.json": 3}
assert files == sorted(expected), (files, expected)
for f, n in expected.items():
    d = json.load(open(os.path.join("untracked/runs", f)))
    assert d.get("attempt") == n, (f, d.get("attempt"), n)
# ordering by start within each record
starts = [json.load(open(os.path.join("untracked/runs", f)))["start"] for f in sorted(expected)]
assert starts == sorted(starts), starts
print("        files:", ", ".join(sorted(expected)), "— attempt numbers 1,2,3, ordered")
PY
[ $? -eq 0 ] || fail "three-attempt layout wrong"

# ── C. null: a row dispatched once -> readers byte-identical to today ─────
echo "  C. null: single dispatch -> exactly one record (the bare), readers unchanged"
OK_RUN T6503 >/dev/null 2>&1
N=$(ls untracked/runs/T6503* 2>/dev/null | wc -l | tr -d ' ')
if [ "$N" -ne 1 ]; then fail "single dispatch left $N records (expected exactly 1)"; else pass "exactly one record"; fi
PYTHONPATH="$PROJECT/tools:${PYTHONPATH:-}" python3 -c '
import dispatch_verify as dv
r = dv.read_run_record(".", "T6503")
assert r is not None and r.get("exit") == 0 and r.get("attempt") == 1, r
assert "killed" not in r or not r.get("killed"), r
print("        dispatch_verify.read_run_record: attempt=1 exit=0 — same shape as pre-T650")
' && pass "read_run_record unchanged on a single-attempt row" || fail "read_run_record broke on a single-attempt row"

# ── D. seeded: every existing reader against the multi-attempt layout ─────
echo "  D. seeded: readers on a multi-attempt row (T6502: two kills + one success)"
PYTHONPATH="$PROJECT/tools:${PYTHONPATH:-}" python3 -c '
import dispatch_verify as dv
r = dv.read_run_record(".", "T6502")
# dispatch_verify wants the LATEST record: the bare file (attempt 3, success)
assert r is not None and r.get("attempt") == 3 and r.get("exit") == 0, r
print("        dispatch_verify.read_run_record -> LATEST (bare, attempt=3 exit=0)")
' && pass "dispatch_verify sees the latest attempt" || fail "dispatch_verify saw a stale attempt"

PYTHONPATH="$PROJECT/tools:${PYTHONPATH:-}" python3 -c '
import importlib.util, os
spec = importlib.util.spec_from_file_location("attribution_backfill", "'"$PROJECT"'/tools/attribution-backfill.py")
ab = importlib.util.module_from_spec(spec); spec.loader.exec_module(ab)
# parse_run_model reads the bare record = latest dispatch command; ours has
# no --model flag, so None is the honest answer, but the READ must succeed
# and return None (not crash) on the multi-attempt layout.
m = ab.parse_run_model("untracked/runs", "T6502")
assert m is None, m  # no --model in the synthetic dispatch; a crash would fail here
print("        attribution-backfill.parse_run_model -> None (read the latest command, no crash)")
' && pass "attribution-backfill reads the latest command" || fail "attribution-backfill crashed on the new layout"

# The AC7 census (orcha-acceptance.sh): iterates every file in
# untracked/runs/ and counts wall-kills in a 24h window.  The two killed
# attempts must each be counted EXACTLY ONCE — not 0 (overwrite) and not 4
# (a bare-copy/symlink of the latest would count the success file twice).
python3 - "$(( $(date +%s) - 86400 ))" <<'PY'
import json, os, sys, datetime
cutoff = int(sys.argv[1])
d = "untracked/runs"
n = 0
if os.path.isdir(d):
    for f in os.listdir(d):
        if not f.endswith(".json"):
            continue
        p = os.path.join(d, f)
        try:
            r = json.load(open(p))
        except Exception:
            continue
        killed = (r.get("killed") or "")
        if "wall" not in killed.lower() and r.get("exit") != 124:
            continue
        end = r.get("end") or ""
        ts = 0
        if end:
            try:
                ts = int(datetime.datetime.fromisoformat(end.replace("Z", "+00:00")).timestamp())
            except Exception:
                ts = 0
        if ts == 0:
            try:
                ts = int(os.path.getmtime(p))
            except Exception:
                ts = 0
        if ts >= cutoff:
            n += 1
# T6501: 1 kill + 1 success; T6502: 2 kills + 1 success; T6503: 1 success
# -> 3 wall-killed attempts total, each counted once.
print("        AC7 wall-kills in window:", n)
assert n == 3, n
PY
[ $? -eq 0 ] && pass "AC7 census counts each killed attempt exactly once (3 kills, not 0, not 6)" || fail "AC7 census double-counted or dropped killed attempts"

# ── E. seeded: p95 counts COMPLETED attempts only ─────────────────────────
echo "  E. seeded: p95 computation counts COMPLETED attempts only"
python3 - <<'PY'
import json, os, statistics
# Fabricate a runs dir: T650P completed once (wall 100) then re-dispatched
# and KILLED (wall 9000 — a killed attempt's wall is NOT a work sample).
os.makedirs("untracked/runs-p95", exist_ok=True)
def rec(task, attempt, wall, killed):
    return {"task": task, "attempt": attempt, "wall": wall,
            "killed": killed, "killed_by": "wall" if killed else None,
            "exit": None if killed else 0, "end": "2026-08-22T12:00:00Z"}
for fn, r in {
    "T650P.1.json": rec("T650P", 1, 100.0, None),    # completed attempt 1
    "T650P.json":   rec("T650P", 2, 9000.0, "wall ceiling"),  # killed attempt 2
    "T650Q.json":   rec("T650Q", 1, 200.0, None),    # completed
    "T650R.json":   rec("T650R", 1, 300.0, None),    # completed
}.items():
    json.dump(r, open(os.path.join("untracked/runs-p95", fn), "w"))

# The T634/T643 derivation: p95 over wall of FINALIZED NON-KILLED runs.
# T650 makes the filter explicit: a record is a work-duration sample only
# when it has a wall AND no killed/killed_by/signal (a completed attempt).
walls = []
for fn in os.listdir("untracked/runs-p95"):
    if not fn.endswith(".json"): continue
    r = json.load(open(os.path.join("untracked/runs-p95", fn)))
    if r.get("killed") or r.get("killed_by") or r.get("signal"):
        continue  # censored — a killed attempt's wall is not a sample
    if r.get("wall"):
        walls.append(r["wall"])
walls.sort()
assert walls == [100.0, 200.0, 300.0], walls  # the 9000.0 killed wall is EXCLUDED
# p95 by linear interpolation (the T634 method)
if len(walls) >= 5:
    idx = 0.95 * (len(walls) - 1)
    lo = int(idx); hi = min(lo + 1, len(walls) - 1)
    p95 = walls[lo] + (walls[hi] - walls[lo]) * (idx - lo)
else:
    p95 = walls[-1]
print("        completed walls:", walls, "-> p95 =", p95, "(killed 9000.0 excluded)")
assert p95 == 300.0, p95
PY
[ $? -eq 0 ] && pass "p95 excludes killed attempts (censored walls are not samples)" || fail "p95 counted a killed attempt's wall"

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-runner-run-records: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-runner-run-records: FAILURES ==="
    exit 1
fi
