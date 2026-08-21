#!/bin/sh
# regression-suite-surfaces.sh — controls for the two-surfaces split (T531).
#
# Ruling 4 (docs/status/ROADMAP-2026-08-20.md rev 3) settled T351's bars
# conflict: the suite has two output surfaces.  The CONSOLE carries the
# pass/fail summary and owes zero failed-command noise; the ARTIFACT
# (untracked/log/suite-evidence.log, written by src/evidence.zig) carries the
# [EXPECTED]/I4-I9 instrument readings.  `tools/suite-truth.sh` gates both
# against docs/infra/suite-truth-manifest.md.
#
# A gate with no known-bad is a decoration, so each arm below pairs a control
# that must pass with a seeded defect that must be caught BY NAME:
#
#   1. null      synthetic clean run  → GREEN
#   2. seeded    one extra cosmetic `failed command:` → RED, names the count
#   3. seeded    a declared reading missing from the artifact → RED, names it
#   4. seeded    no --evidence with --log → RED (fail closed, never assumed)
#   5. seeded    fewer cosmetic lines than the manifest allows → RED (ratchet)
#   6. null      a real test binary using evidence.print writes the artifact
#                and NOTHING to stderr — the console half, which cannot be
#                asserted from inside a test binary
#   7. seeded    the same binary shape using std.debug.print DOES write stderr
#                — proof that arm 6 is measuring something
#
# Everything runs under /tmp/weizigo.  The live artifact, the live manifests
# and the live suite log are never written.
#
# Task: T531 · Role: worker · Model: claude-opus-5 · Date: 2026-08-20

set -e

cd "$(git rev-parse --show-toplevel)"
GATE="$PWD/tools/suite-truth.sh"

WORK="$(mktemp -d /tmp/weizigo/suite-surfaces-XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

FAILED=0
fail() { echo "  FAIL: $1"; FAILED=1; }
pass() { echo "  PASS: $1"; }

# ── fixtures ───────────────────────────────────────────────────────────────
#
# A synthetic suite log in the exact shape build_runner emits: one
# `failed command:` line per failed step, a Build Summary line, and the
# failed-step tree.  One crashed test step, one failed shell script.

make_log() {           # make_log <path> <extra-cosmetic-lines>
  out="$1"; cosmetic="$2"
  {
    echo "I4 2x2: violations=0 examined=28 ko_excluded=82"
    i=0
    while [ "$i" -lt "$cosmetic" ]; do
      echo "failed command: cd /repo && ./.zig-cache/o/cosmetic$i/test --cache-dir=./.zig-cache --seed=0x1 --listen=-"
      i=$((i + 1))
    done
    echo "error: 'fixturemod.test.a crashing test' terminated with signal ABRT"
    echo "failed command: cd /repo && ./.zig-cache/o/crashed0/test --cache-dir=./.zig-cache --seed=0x1 --listen=-"
    echo "failed command: cd /repo && sh tools/regression-fixture.sh"
    echo "Build Summary: 60/62 steps succeeded (2 failed); 900/901 tests passed (0 skipped, 1 crashed)"
    echo "test transitive failure"
    echo "+- run test 12 pass, 1 crash (13 total)"
    echo "+- run sh failure"
  } > "$out"
}

make_reds_manifest() { # make_reds_manifest <path> [compile-module]
  cat > "$1" <<EOF
# fixture reds manifest (T531 control)
RED module fixturemod
RED script tools/regression-fixture.sh
COUNT steps-failed 2
COUNT tests-crashed 1
EOF
  if [ -n "${2:-}" ]; then echo "RED compile $2" >> "$1"; fi
}

make_compile_manifest() { # make_compile_manifest <path> <compile-module> — counts match the compile-only log
  cat > "$1" <<EOF
# fixture reds manifest (T564 compile-class control)
RED compile $2
COUNT steps-failed 1
COUNT tests-crashed 0
EOF
}

make_compile_log() { # make_compile_log <path> — a module that fails to COMPILE, not to crash
  cat > "$1" <<'EOF'
I4 2x2: violations=0 examined=28 ko_excluded=82
failed command: cd /repo && /opt/homebrew/.../bin/zig test -OReleaseSafe --dep engine -Mroot=/repo/src/fixturecompile.zig -OReleaseSafe -Mengine=/repo/src/fixtureengine.zig --cache-dir .zig-cache --name test --listen=-
Build Summary: 61/62 steps succeeded (1 failed); 901/901 tests passed (0 skipped)
+- run test transitive failure
   +- compile test ReleaseSafe native 1 errors
EOF
}

make_surfaces_manifest() { # make_surfaces_manifest <path> <allowed-cosmetic>
  cat > "$1" <<EOF
# fixture surfaces manifest (T531 control)
CONSOLE cosmetic-failed-command $2
EVIDENCE I4 2x2: violations=
EVIDENCE [EXPECTED] evidence-sink control: artifact write ok
EOF
}

make_evidence() {      # make_evidence <path> <complete|missing>
  {
    echo "I4 2x2: violations=0 examined=28 ko_excluded=82"
    [ "$2" = complete ] && echo "[EXPECTED] evidence-sink control: artifact write ok"
  } > "$1"
  :
}

LOG_CLEAN="$WORK/clean.log";    make_log "$LOG_CLEAN" 0
LOG_NOISY="$WORK/noisy.log";    make_log "$LOG_NOISY" 1
REDS="$WORK/reds.md";           make_reds_manifest "$REDS"
SURF0="$WORK/surfaces0.md";     make_surfaces_manifest "$SURF0" 0
SURF2="$WORK/surfaces2.md";     make_surfaces_manifest "$SURF2" 2
EV_FULL="$WORK/evidence-full.log";    make_evidence "$EV_FULL" complete
EV_SHORT="$WORK/evidence-short.log";  make_evidence "$EV_SHORT" missing

run_gate() {           # run_gate <out> <args...>; never fails the script
  out="$1"; shift
  set +e
  sh "$GATE" "$@" > "$out" 2>&1
  rc=$?
  set -e
  echo "$rc"
}

# ── 1. null control ────────────────────────────────────────────────────────
echo "=== regression-suite-surfaces: 1. null — clean run is GREEN ==="
RC=$(run_gate "$WORK/o1" --log "$LOG_CLEAN" --manifest "$REDS" --surfaces "$SURF0" --evidence "$EV_FULL")
if [ "$RC" -eq 0 ]; then pass "clean synthetic run exits 0"; else
  fail "clean synthetic run exited $RC"; sed 's/^/    /' "$WORK/o1"
fi
grep -q "cosmetic (noise): observed=0 manifest=0" "$WORK/o1" \
  && pass "console surface reports 0 cosmetic" || fail "console surface did not report 0 cosmetic"
grep -q "readings: 2/2 present" "$WORK/o1" \
  && pass "evidence surface reports 2/2 readings" || fail "evidence surface count wrong"

# ── 2. seeded: cosmetic noise ──────────────────────────────────────────────
echo "=== regression-suite-surfaces: 2. seeded — a cosmetic failed-command is caught ==="
RC=$(run_gate "$WORK/o2" --log "$LOG_NOISY" --manifest "$REDS" --surfaces "$SURF0" --evidence "$EV_FULL")
[ "$RC" -ne 0 ] && pass "gate refuses the noisy run (exit $RC)" || fail "gate passed a noisy run"
grep -q "REGRESSION: 1 cosmetic failed-command lines" "$WORK/o2" \
  && pass "names the count" || { fail "did not name the cosmetic count"; sed 's/^/    /' "$WORK/o2"; }
grep -q "src/evidence.zig" "$WORK/o2" \
  && pass "names the remedy (evidence.print)" || fail "did not name the remedy"

# ── 3. seeded: a reading went silent ───────────────────────────────────────
echo "=== regression-suite-surfaces: 3. seeded — a missing reading is caught ==="
RC=$(run_gate "$WORK/o3" --log "$LOG_CLEAN" --manifest "$REDS" --surfaces "$SURF0" --evidence "$EV_SHORT")
[ "$RC" -ne 0 ] && pass "gate refuses the incomplete artifact (exit $RC)" || fail "gate passed a missing reading"
grep -q "MISSING READING: \[EXPECTED\] evidence-sink control" "$WORK/o3" \
  && pass "names the missing reading" || { fail "did not name the missing reading"; sed 's/^/    /' "$WORK/o3"; }
grep -q "readings: 1/2 present" "$WORK/o3" \
  && pass "reports 1/2 present" || fail "wrong present/total"

# ── 3b. seeded: a compile failure is a distinct reds class ───────────────
echo "=== regression-suite-surfaces: 3b. seeded — a module that fails to COMPILE is caught ==="
LOG_CFAIL="$WORK/compile-fail.log"; make_compile_log "$LOG_CFAIL"
REDS_CF="$WORK/reds-cf.md"; make_compile_manifest "$REDS_CF" notinmanifest
RC=$(run_gate "$WORK/o3b" --log "$LOG_CFAIL" --manifest "$REDS_CF" --surfaces "$SURF0" --evidence "$EV_FULL")
[ "$RC" -ne 0 ] && pass "gate refuses the compile failure (exit $RC)" \
  || fail "gate passed a module that failed to compile"
grep -q "NEW RED (not in manifest): fixturecompile" "$WORK/o3b" \
  && pass "names the compile-failing module" || { fail "did not name the module"; sed 's/^/    /' "$WORK/o3b"; }

# ── 3c. null: a declared compile failure matches ──────────────────────────
echo "=== regression-suite-surfaces: 3c. null — a declared compile failure is GREEN ==="
REDS_CF2="$WORK/reds-cf2.md"; make_compile_manifest "$REDS_CF2" fixturecompile
RC=$(run_gate "$WORK/o3c" --log "$LOG_CFAIL" --manifest "$REDS_CF2" --surfaces "$SURF0" --evidence "$EV_FULL")
[ "$RC" -eq 0 ] && pass "declared compile failure matches (exit 0)" \
  || { fail "declared compile failure exited $RC"; sed 's/^/    /' "$WORK/o3c"; }

# ── 4. seeded: no artifact named ───────────────────────────────────────────
echo "=== regression-suite-surfaces: 4. seeded — --log without --evidence fails closed ==="
RC=$(run_gate "$WORK/o4" --log "$LOG_CLEAN" --manifest "$REDS" --surfaces "$SURF0")
[ "$RC" -ne 0 ] && pass "gate refuses an unnamed artifact (exit $RC)" || fail "gate assumed an artifact"
grep -q "UNCHECKED: no evidence artifact named" "$WORK/o4" \
  && pass "says why" || fail "did not explain the refusal"

# ── 5. seeded: the ratchet only goes down ──────────────────────────────────
echo "=== regression-suite-surfaces: 5. seeded — a stale allowance is caught ==="
RC=$(run_gate "$WORK/o5" --log "$LOG_CLEAN" --manifest "$REDS" --surfaces "$SURF2" --evidence "$EV_FULL")
[ "$RC" -ne 0 ] && pass "gate refuses a manifest that allows more than observed (exit $RC)" \
  || fail "gate let a stale allowance stand"
grep -q "RATCHET: only 0 cosmetic lines remain" "$WORK/o5" \
  && pass "names the new floor" || { fail "did not name the new floor"; sed 's/^/    /' "$WORK/o5"; }

# ── 6/7. the console half, end to end ──────────────────────────────────────
#
# Arm 6 runs the real control binary; arm 7 runs a binary identical in every
# way except that it prints to stderr.  Together they show the console
# difference is caused by the sink and not by anything else.
echo "=== regression-suite-surfaces: 6. null — evidence.print writes the artifact, not stderr ==="
EV_LIVE="$WORK/live-evidence.log"
: > "$EV_LIVE"
set +e
WEIZIGO_EVIDENCE="$EV_LIVE" zig test -O ReleaseSafe src/evidence_control.zig \
  > "$WORK/o6.out" 2> "$WORK/o6.err"
RC=$?
set -e
if [ "$RC" -eq 0 ]; then pass "evidence_control tests pass"; else
  fail "evidence_control tests exited $RC"; sed 's/^/    /' "$WORK/o6.err"
fi
grep -q "artifact write ok" "$EV_LIVE" \
  && pass "the reading reached the artifact" || fail "the artifact did not get the reading"
if grep -q "artifact write ok" "$WORK/o6.err"; then
  fail "the reading ALSO reached stderr — the console is not clean"
else
  pass "no reading on stderr"
fi

echo "=== regression-suite-surfaces: 7. seeded — std.debug.print does reach stderr ==="
cat > "$WORK/seeded.zig" <<'ZIG'
const std = @import("std");
test "a passing test that writes a reading to stderr" {
    std.debug.print("artifact write ok\n", .{});
    try std.testing.expect(true);
}
ZIG
set +e
zig test -O ReleaseSafe "$WORK/seeded.zig" > "$WORK/o7.out" 2> "$WORK/o7.err"
RC=$?
set -e
[ "$RC" -eq 0 ] && pass "the seeded binary still passes its test" || fail "seeded binary exited $RC"
if grep -q "artifact write ok" "$WORK/o7.err"; then
  pass "std.debug.print reaches stderr (arm 6 measures a real difference)"
else
  fail "std.debug.print did NOT reach stderr — arm 6 proves nothing"
fi

echo ""
if [ "$FAILED" -eq 0 ]; then
  echo "=== regression-suite-surfaces: ALL CONTROLS PASSED ==="
  exit 0
fi
echo "=== regression-suite-surfaces: FAILURES ABOVE ==="
exit 1
