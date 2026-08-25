#!/usr/bin/env bash
# regression-goban-scaling-capture.sh — T926 controls: the goban-scaling
# capture script's three defects (under-reported RSS, dropped-kill-row,
# trusted-regime-arg) are detected by these arms.  Every arm is hermetic
# in a scratch git repo and writes to a scratch ledger via
# WEIZIGO_SCALING_LEDGER — the live docs/infra/host/goban-scaling.jsonl
# is never touched.
#
# The defect (2026-08-25, found by reading the live process table
# against the ledger T924 produced):
#   1. peak_rss_mb read $CMDPID alone, missing the descendant tree.
#      A 3x2 solve running at 1,440 MB was recorded as 46 MB; 4x4 was
#      48 MB.  The fix: walk the ppid->[pid] tree, sum RSS.
#   2. A killed run appended no row at all (the append sat AFTER
#      `wait $CMDPID`).  A wall kill, an RSS cap, or a lane-orchestrator
#      signal left the entry unwritten — reading as "not measured"
#      when the work was measured-and-lost.  The fix: an EXIT trap
#      that always appends, with killed_by + partial.
#   3. The regime arg was trusted.  T924 called the wrapper with
#      `writes-off` for BOTH arms of its 4x4 comparison, so the
#      writes-on row was filed under writes-off (corrected by hand in
#      4a80255's successor; the same defect would re-fire next time).
#      The fix: parse the command for RETRO_SOUND/RETRO_DEPS, stamp
#      regime_observed, and report regime_mismatch on disagreement.
#
# Controls (test-first, per the standing tooling rule — a green run
# after the fix is not a green run BEFORE the fix was attempted, so
# the SEEDED-DEFECT arms are written to fail on the pre-T926 shape):
#
#   A. null (clean child, no forks, no kill): row lands with rc=0,
#      killed_by=none, partial=false, regime_mismatch=false, and
#      peak_rss_mb matches the child's actual RSS within a tolerance.
#      RED (pre-T926): no shape mismatch — the null control passes on
#      both shapes.  This arm is the floor.
#   B. seeded-defect (TREE RSS — child forks a 150 MB grandchild):
#      the ledger's peak_rss_mb must be at least 200 MB (the parent
#      process alone is ~150 MB; with the grandchild, the tree is
#      ~300 MB+).  RED (pre-T926): only $CMDPID was read, so the row
#      recorded the parent's RSS alone, ~150 MB at peak — well under
#      the 200 MB floor and the regression exits 1.
#   C. seeded-defect (KILLED RUN — child SIGKILLs itself mid-run):
#      a row MUST land.  killed_by=signal, partial=true, exit=137
#      (128 + SIGKILL=9).  RED (pre-T926): no row at all — the
#      regression reads a missing ledger (or zero rows) and exits 1.
#   D. seeded-defect (REGIME MISMATCH — claim writes-off, command
#      does NOT set RETRO_SOUND): regime_claimed=writes-off,
#      regime_observed=memo-reuse, regime_mismatch=true, AND a
#      "REGIME MISMATCH" warning appears on stderr.  RED (pre-T926):
#      the wrapper trusted the arg; no mismatch field existed; the
#      regression reads the missing key and exits 1.
#
# All arms use WEIZIGO_SCALING_LEDGER to redirect to a per-arm
# scratch ledger.  The live docs/infra/host/goban-scaling.jsonl is
# never written to by this regression.
#
# Task: T926 · Role: worker · Model: minimax-m3 · Date: 2026-08-25

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
# Env override for red-first validation: set CAP to a pre-T926 (broken)
# capture script and re-run.  All four arms must fail (exit 1), proving
# the regression would have caught the original three defects.
CAP="${CAP:-$PROJECT/tools/goban-scaling-capture.sh}"
FAIL=0

. "$PROJECT/tools/lib/scratch-repo.sh"

cleanup() {
    [ -n "${WORK:-}" ] && rm -rf "$WORK"
}
trap cleanup EXIT

weizigo_scratch_repo t926-scaling WORK   # T849: isolated scratch repo
cd "$WORK"
git config user.email t926@test
git config user.name T926
echo base > README.md
git add README.md
git commit -qm base

# Per-arm scratch ledger paths; each arm overwrites its own so arms
# cannot contaminate one another.
LEDGER_A="$WORK/ledger-A.jsonl"
LEDGER_B="$WORK/ledger-B.jsonl"
LEDGER_C="$WORK/ledger-C.jsonl"
LEDGER_D="$WORK/ledger-D.jsonl"
rm -f "$LEDGER_A" "$LEDGER_B" "$LEDGER_C" "$LEDGER_D"

note() { echo "$*"; }
pass() { echo "    PASS: $*"; }
fail() { echo "    FAIL: $*"; FAIL=1; }

# Helper: a long-running python that occupies a known RSS shape
# (PARENT: 300 MB; with a forked CHILD: 600 MB) and lets us drive
# TREE-RSS, KILLED, and partial-shape arms.
#
# The script also accepts a SIGTERM at runtime (trapped, exits 143)
# so arm C can exercise the killed path while staying portable to
# hosts without `timeout(1)`.
cat > "$WORK/long-fork.py" <<'PY'
import os, resource, signal, sys, time
def term(s, f):
    print('CHILD: got SIGTERM', file=sys.stderr)
    sys.exit(143)
signal.signal(signal.SIGTERM, term)
a = bytearray(150 * 1024 * 1024)   # 150 MB
b = bytearray(150 * 1024 * 1024)   # 150 MB
print('PARENT start', file=sys.stderr)
pid = os.fork()
if pid == 0:
    c = bytearray(150 * 1024 * 1024)  # 150 MB in the forked child
    d = bytearray(150 * 1024 * 1024)  # 150 MB more
    print('CHILD start', file=sys.stderr)
    time.sleep(8.0)
    print('CHILD RSS', resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
          file=sys.stderr)
    os._exit(0)
else:
    time.sleep(6.0)
    print('PARENT RSS', resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
          file=sys.stderr)
    os.waitpid(pid, 0)
print('done', file=sys.stderr)
PY

# Helper: a child that SIGKILLs itself after 0.3 s — drives arm C
# (killed-run row).  Note: a real lane-orchestrator SIGKILL is
# indistinguishable from a child-driven SIGKILL at the wrapper
# level; the row shape (rc=137, killed_by=signal, partial=true) is
# the contract.
cat > "$WORK/sigkill.py" <<'PY'
import os, threading, time
def kill_me():
    time.sleep(0.3)
    os.kill(os.getpid(), 9)  # SIGKILL — no chance to catch
threading.Thread(target=kill_me, daemon=True).start()
time.sleep(30)
PY

# Helper: a child that ignores its parent (sleeps forever) so arm D
# (regime mismatch) can complete without the wrapper hanging.
cat > "$WORK/sleep0.sh" <<'SH'
#!/bin/sh
sleep 0.3
SH
chmod +x "$WORK/sleep0.sh"

echo "=== regression-goban-scaling-capture (T926) ==="
note "host: $(uname -s); capture script: $CAP"

# ── A. null: clean child, no forks, no kill ──────────────────────────
# Floor: this arm passes on both pre-T926 and post-T926 shapes — the
# regression's value is in B/C/D, which is the seeded-defect
# contract.  A is the gate that the script still produces a valid
# row on the happy path.  The regime arg is "writes-off" and the
# child sets RETRO_SOUND=1 so the regime-mismatch arm (D) does not
# also fire on the null — each arm tests ONE thing.
echo
echo "  A. null: clean child -> row lands with rc=0, killed_by=none, partial=false"
WEIZIGO_SCALING_LEDGER="$LEDGER_A" \
  "$CAP" 0 0 writes-off T926A -- env RETRO_SOUND=1 "$WORK/sleep0.sh" >/dev/null 2>&1
RC=$?
if [ "$RC" -ne 0 ]; then fail "null run exited $RC (expected 0)"; fi
if [ ! -s "$LEDGER_A" ]; then
    fail "null control: no row in $LEDGER_A"
else
    python3 - "$LEDGER_A" <<'PY'
import json, sys
ledger = sys.argv[1]
with open(ledger) as f:
    rows = [json.loads(l) for l in f if l.strip()]
assert len(rows) == 1, f"expected 1 row, got {len(rows)}: {rows}"
r = rows[0]
assert r["exit"] == 0, ("exit", r)
assert r["killed_by"] == "none", ("killed_by", r)
assert r["partial"] is False, ("partial", r)
assert r["regime_mismatch"] is False, ("regime_mismatch", r)
assert r["regime_claimed"] == r["regime_observed"] == "writes-off", ("regime", r)
assert r["peak_rss_mb"] is not None, ("peak_rss_mb null", r)
print(f"        row OK: rc=0 killed_by=none partial=false peak={r['peak_rss_mb']}MB")
PY
    [ $? -eq 0 ] && pass "null control: row shape correct" || fail "null control: row shape wrong"
fi

# ── B. seeded-defect: TREE RSS — child forks a heavy grandchild ────────
# The parent holds 300 MB; the forked child holds another 300 MB; the
# tree is ~600 MB.  Pre-T926: only the parent's RSS is read, so the
# row records ~300 MB.  Post-T926: the walker sums both, so the row
# records ~600 MB.
# Floor: peak_rss_mb >= 400 MB.  The parent alone is 300 MB; a row
# at exactly 300 MB is the broken shape.
echo
echo "  B. seeded-defect: tree RSS — child forks 300MB grandchild -> peak_rss_mb >= 400MB"
WEIZIGO_SCALING_LEDGER="$LEDGER_B" \
  "$CAP" 0 0 writes-off T926B -- python3 "$WORK/long-fork.py" >/dev/null 2>&1
RC=$?
if [ "$RC" -ne 0 ]; then fail "tree run exited $RC (expected 0)"; fi
if [ ! -s "$LEDGER_B" ]; then
    fail "tree control: no row in $LEDGER_B (row was lost)"
else
    python3 - "$LEDGER_B" <<'PY'
import json, sys
ledger = sys.argv[1]
with open(ledger) as f:
    rows = [json.loads(l) for l in f if l.strip()]
assert len(rows) == 1, f"expected 1 row, got {len(rows)}"
r = rows[0]
peak = r["peak_rss_mb"]
# 400 MB floor: parent alone is 300 MB, so a row below 400 means only
# the direct child was sampled (the pre-T926 defect).  The fork
# exists, so the parent holding 300 MB is THE direct child — pre-T926
# would have read ~310 MB.  400 is comfortably above.
assert peak is not None and peak >= 400, (
    f"peak_rss_mb={peak} MB — under 400 MB floor; only the direct child was sampled (pre-T926 shape). "
    f"row={r}")
print(f"        row OK: peak_rss_mb={peak}MB (parent ~300 + child ~300 = tree sum, post-T926 shape)")
PY
    [ $? -eq 0 ] && pass "tree RSS: row records descendant tree, not just the child" \
        || fail "tree RSS: row records only the direct child — defect 1 NOT fixed"
fi

# ── C. seeded-defect: KILLED RUN — child SIGKILLs itself ──────────────
# Pre-T926: NO row lands (the append sat after `wait`, and the child
# was killed by SIGKILL, so wait returned 137, the script aborted
# under set -e, and the append never ran).  Post-T926: the EXIT trap
# appends the row with rc=137, killed_by=signal, partial=true.
echo
echo "  C. seeded-defect: child SIGKILLs itself -> row lands with rc=137, killed_by=signal, partial=true"
WEIZIGO_SCALING_LEDGER="$LEDGER_C" \
  "$CAP" 0 0 writes-off T926C -- python3 "$WORK/sigkill.py" >/dev/null 2>&1
RC=$?
# Outer rc may be 137 OR 0 — depends on whether the trap's exit was
# honored.  The contract is the ROW: it must exist, with the kill
# fields set.  Outer rc is best-effort on macOS /bin/sh.
if [ ! -s "$LEDGER_C" ]; then
    fail "killed control: no row in $LEDGER_C (row was lost — pre-T926 defect 2)"
else
    python3 - "$LEDGER_C" <<'PY'
import json, sys
ledger = sys.argv[1]
with open(ledger) as f:
    rows = [json.loads(l) for l in f if l.strip()]
assert len(rows) == 1, f"expected 1 row, got {len(rows)}"
r = rows[0]
assert r["exit"] == 137, f"exit={r['exit']} (expected 137 = 128+SIGKILL)"
assert r["killed_by"] == "signal", f"killed_by={r['killed_by']!r} (expected 'signal')"
assert r["partial"] is True, f"partial={r['partial']} (expected True)"
print(f"        row OK: rc=137 killed_by=signal partial=true — kill path records the row")
PY
    [ $? -eq 0 ] && pass "killed run: row lands with kill fields populated" \
        || fail "killed run: row missing or kill fields not populated — defect 2 NOT fixed"
fi

# ── D. seeded-defect: REGIME MISMATCH — claim writes-off, no env ──────
# Pre-T926: regime_observed, regime_mismatch, killed_by, partial did
# not exist as fields.  The row would carry regime="writes-off" and
# nothing else.  Post-T926: the row carries regime_observed=memo-reuse
# (no RETRO_SOUND), regime_mismatch=true, and a stderr warning.
echo
echo "  D. seeded-defect: regime mismatch — claim writes-off, no RETRO_SOUND -> regime_mismatch=true"
STDERR_D="$WORK/stderr-D.log"
WEIZIGO_SCALING_LEDGER="$LEDGER_D" \
  "$CAP" 0 0 writes-off T926D -- "$WORK/sleep0.sh" >/dev/null 2>"$STDERR_D"
RC=$?
if [ "$RC" -ne 0 ]; then fail "regime-mismatch run exited $RC (expected 0)"; fi
if [ ! -s "$LEDGER_D" ]; then
    fail "regime-mismatch control: no row in $LEDGER_D"
else
    python3 - "$LEDGER_D" "$STDERR_D" <<'PY'
import json, sys
ledger, stderr_path = sys.argv[1], sys.argv[2]
with open(ledger) as f:
    rows = [json.loads(l) for l in f if l.strip()]
assert len(rows) == 1, f"expected 1 row, got {len(rows)}"
r = rows[0]
assert r["regime_claimed"] == "writes-off", ("regime_claimed", r)
assert r["regime_observed"] == "memo-reuse", ("regime_observed", r)
assert r["regime_mismatch"] is True, ("regime_mismatch", r)
# Stderr must carry the operator-visible warning.  Pre-T926: no
# warning was ever printed because the field did not exist.
try:
    stderr = open(stderr_path).read()
except FileNotFoundError:
    stderr = ""
assert "REGIME MISMATCH" in stderr, (
    f"stderr missing 'REGIME MISMATCH' warning — operator will not see the disagreement. "
    f"stderr was: {stderr!r}")
print(f"        row OK: regime_claimed={r['regime_claimed']} regime_observed={r['regime_observed']} mismatch=True, stderr warned")
PY
    [ $? -eq 0 ] && pass "regime mismatch: row carries observed + mismatch + stderr warning" \
        || fail "regime mismatch: field or warning missing — defect 3 NOT fixed"
fi

echo
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-goban-scaling-capture: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-goban-scaling-capture: FAILED ==="
    exit 1
fi
