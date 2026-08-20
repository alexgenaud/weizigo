#!/bin/sh
# regression-orcha-acceptance.sh — T537 controls: the acceptance verdict.
#
# T537 (acceptance verdict counts only FAIL): `ACCEPTANCE PASS` printed while
# AC2/AC6/AC7 were all warning.  Two defects:
#   (1) the summary only tested `$FAIL`, so a WARN could never surface;
#   (2) AC7 grepped every t*.log ever produced ("exit 124") — a cumulative-ever
#       counter labelled "today", monotonic by construction.
#
# T537 ships a three-state verdict (exit 0 clean / 1 FAIL / 2 WARN-only) and
# re-scopes AC7 to a 24 h window over run records (whose `killed` field carries
# the kill reason directly, T520).  This regression drives the real
# tools/orcha-acceptance.sh against a hermetic scratch repo (no managent, no
# live kanban, no live untracked/) and asserts the four brief controls plus the
# FAIL path:
#
#   A. one check WARN, none FAIL        -> summary names AC6, exit 2 (not 0).
#      (Against the pre-T537 script this FAILS: it would print ACCEPTANCE PASS.)
#   B. wall-kill 3 days ago + one today -> AC7 counts 1 (the old one drops out).
#   C. null: all checks PASS            -> ACCEPTANCE PASS, exit 0, no WARNING.
#   D. empty/no run-dir                 -> AC7 is 0 and does not error.
#   E. fleet idle with dispatchable     -> FAIL, exit 1, summary names AC2.
#
# Everything runs in a scratch git repo under /tmp/weizigo — the live repo and
# live kanban are never touched.
#
# Task: T537 · Role: worker · Model: deepseek-v4-pro · Date: 2026-08-20

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
ACC="$PROJECT/tools/orcha-acceptance.sh"
FAIL=0

cleanup() {
    [ -n "${WORK:-}" ] && rm -rf "$WORK"
}
trap cleanup EXIT

mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/t537-accept-XXXXXX)" || { echo "regression-orcha-acceptance.sh: FATAL — scratch mktemp failed" >&2; exit 2; }
cd "$WORK"
git init -q -b main
git config user.email t537@test
git config user.name T537
mkdir -p docs/infra untracked/runs untracked/log
echo base > README.md
printf 'untracked/\n' > .gitignore
git add README.md .gitignore
git commit -qm base

note() { echo "$*"; }
pass() { echo "    PASS: $*"; }
fail() { echo "    FAIL: $*"; FAIL=1; }

# ORCHA_NOW fixed so AC7's window is deterministic regardless of when this runs.
NOW=2000000000
# Clean fixtures written fresh before each arm.
write_status() { printf '%s' "$1" > "$WORK/status.json"; }
write_perf()    { printf '%s' "$1" > "$WORK/docs/infra/model-perf.md"; }
write_claimlint() { printf '%s' "$1" > "$WORK/claimlint.txt"; }
CLAIM_OK='== C0  PARSE ==
  non-conforming: 0 (all files conform to the findings schema)
  unabsorbed: 0 (all findings reflected in the register)
'
run_accept() {
    # $1 = expected exit code; remaining args = grep needles for --json output
    ORCHA_ROOT="$WORK" ORCHA_STATUS="$WORK/status.json" ORCHA_MANAGENT=/bin/true \
      ORCHA_CLAIMLINT="$WORK/claimlint.txt" ORCHA_NOW="$NOW" \
      sh "$ACC" --json
}

echo "=== regression-orcha-acceptance (T537) ==="

# ── A. one WARN, none FAIL -> summary names it, exit 2 ────────────────────
echo "  A. one WARN (AC6), none FAIL -> exit 2, summary names AC6"
write_status '[]'
write_perf 'dispatch-verify 2026-08-20 T601 glm-5.2 report=incomplete verified=fail fail=row'
write_claimlint "$CLAIM_OK"
rm -rf untracked/runs; mkdir -p untracked/runs
OUT=$(run_accept); RC=$?
SUM=$(printf '%s' "$OUT" | python3 -c 'import json,sys;print(json.load(sys.stdin)["summary"])' 2>/dev/null || echo PARSEFAIL)
if [ "$RC" -ne 2 ]; then fail "arm A exit $RC (expected 2 — WARN-only)"; else pass "arm A exit 2"; fi
case "$SUM" in
    *"ACCEPTANCE PASS WITH 1 WARNING(S)"*"AC6"*) pass "arm A summary names AC6: $SUM" ;;
    *) fail "arm A summary wrong: $SUM" ;;
esac
case "$SUM" in
    *"ACCEPTANCE PASS"*) : ;;
    *) fail "arm A summary not a PASS-WITH line: $SUM" ;;
esac

# ── B. AC7 window: 3-days-ago + today -> counts 1 ─────────────────────────
echo "  B. AC7 window: wall-kill 3 days ago + today -> counts 1"
write_status '[]'
write_perf ''
write_claimlint "$CLAIM_OK"
rm -rf untracked/runs; mkdir -p untracked/runs
python3 - "$NOW" <<'PY'
import json, sys, datetime
now = int(sys.argv[1])
def iso(ts): return datetime.datetime.fromtimestamp(ts, datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
old = now - 3*86400
new = now - 3600
json.dump({"task":"T701","killed":"wall ceiling 1200s reached","signal":9,"end":iso(old),"start":iso(old-1200),"wall":1200.0}, open("untracked/runs/T701.json","w"))
json.dump({"task":"T702","killed":"wall ceiling 1200s reached","signal":9,"end":iso(new),"start":iso(new-1200),"wall":1200.0}, open("untracked/runs/T702.json","w"))
PY
OUT=$(run_accept); RC=$?
AC7DETAIL=$(printf '%s' "$OUT" | python3 -c 'import json,sys;d=json.load(sys.stdin);print([c["detail"] for c in d["checks"] if c["ac"]=="AC7"][0])' 2>/dev/null || echo PARSEFAIL)
if [ "$RC" -ne 0 ]; then fail "arm B exit $RC (expected 0 — 1 is within bar)"; else pass "arm B exit 0"; fi
case "$AC7DETAIL" in
    1\ wall-kill*) pass "arm B AC7 counts 1: $AC7DETAIL" ;;
    *) fail "arm B AC7 detail wrong (expected '1 wall-kill…'): $AC7DETAIL" ;;
esac

# ── C. null: all PASS -> ACCEPTANCE PASS, exit 0, no WARNING text ─────────
echo "  C. null: all checks PASS -> exit 0, ACCEPTANCE PASS, no WARNING"
write_status '[]'
write_perf ''
write_claimlint "$CLAIM_OK"
rm -rf untracked/runs; mkdir -p untracked/runs
OUT=$(run_accept); RC=$?
SUM=$(printf '%s' "$OUT" | python3 -c 'import json,sys;print(json.load(sys.stdin)["summary"])' 2>/dev/null || echo PARSEFAIL)
if [ "$RC" -ne 0 ]; then fail "arm C exit $RC (expected 0)"; else pass "arm C exit 0"; fi
if [ "$SUM" = "ACCEPTANCE PASS" ]; then pass "arm C summary exactly 'ACCEPTANCE PASS'"; else fail "arm C summary wrong: $SUM"; fi
case "$SUM" in *WARNING*|*FAIL*) fail "arm C summary has warning/fail text: $SUM" ;; esac

# ── D. empty (absent) run/log dir -> AC7 0, no error ──────────────────────
echo "  D. absent run/log dir -> AC7 0, exit 0, no error"
write_status '[]'
write_perf ''
write_claimlint "$CLAIM_OK"
rm -rf untracked/runs untracked/log
OUT=$(run_accept); RC=$?
AC7V=$(printf '%s' "$OUT" | python3 -c 'import json,sys;d=json.load(sys.stdin);print([c["verdict"] for c in d["checks"] if c["ac"]=="AC7"][0])' 2>/dev/null || echo PARSEFAIL)
if [ "$RC" -ne 0 ]; then fail "arm D exit $RC (expected 0)"; else pass "arm D exit 0"; fi
if [ "$AC7V" = "PASS" ]; then pass "arm D AC7 PASS (0 wall-kills, no error)"; else fail "arm D AC7 verdict $AC7V"; fi

# ── E. fleet idle with dispatchable -> FAIL, exit 1, summary names AC2 ────
echo "  E. fleet idle -> FAIL, exit 1, summary names AC2"
write_status '[{"id":"T801","status":"dispatchable","set":"A","bundle":"untracked/T801-x.md"}]'
printf 'Landmark: L1.\n' > untracked/T801-x.md
write_perf ''
write_claimlint "$CLAIM_OK"
rm -rf untracked/runs; mkdir -p untracked/runs
OUT=$(run_accept); RC=$?
SUM=$(printf '%s' "$OUT" | python3 -c 'import json,sys;print(json.load(sys.stdin)["summary"])' 2>/dev/null || echo PARSEFAIL)
if [ "$RC" -ne 1 ]; then fail "arm E exit $RC (expected 1 — FAIL)"; else pass "arm E exit 1"; fi
case "$SUM" in
    *"ACCEPTANCE FAIL"*"AC2"*) pass "arm E summary names AC2: $SUM" ;;
    *) fail "arm E summary wrong: $SUM" ;;
esac

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "regression-orcha-acceptance: ALL CONTROLS PASSED"
    exit 0
else
    echo "regression-orcha-acceptance: FAILURES"
    exit 1
fi
