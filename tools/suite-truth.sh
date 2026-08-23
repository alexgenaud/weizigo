#!/bin/sh
# suite-truth.sh — the gate that owns the redness of `zig build test`.
#
# T369 (deepseek-v4-pro, 2026-08-18).  The problem this exists to kill:
# `zig build test` has been red for a long time, every closed row re-derived
# its own story for why, and "pre-existing" was used 24 times to self-certify
# on a red suite.  A permanently-red suite is not a gate: every console can
# honestly call its red pre-existing.
#
# This script runs the FULL suite, extracts the observed failing set, and
# compares it against the manifest of KNOWN reds (docs/infra/suite-truth.md).
# It exits 0 only when observed == manifest.  A new red is loud; a red that
# got fixed must be struck from the manifest.  Ratchet down only — same shape
# as the claimlint floor.
#
# T531 (claude-opus-5, 2026-08-20) added the two-surfaces check.  Ruling 4
# (docs/status/ROADMAP-2026-08-20.md rev 3) settled T351: the suite has two
# output surfaces, not one.  The CONSOLE carries the pass/fail summary and owes
# zero failed-command noise; the ARTIFACT carries the [EXPECTED]/I4-I9
# instrument readings.  Both are gated here, against
# docs/infra/suite-truth-manifest.md, because a surface nobody reads is a
# surface nobody notices going quiet.
#
# Usage:
#   sh tools/suite-truth.sh              run the suite, then compare (≈14 min)
#   sh tools/suite-truth.sh --log F      skip the run; compare against a
#                                        captured suite log (controls/offline).
#                                        Needs --evidence too, or the evidence
#                                        surface is reported UNCHECKED.
#   sh tools/suite-truth.sh --manifest M override the reds manifest (controls)
#   sh tools/suite-truth.sh --surfaces M override the surfaces manifest
#   sh tools/suite-truth.sh --evidence F the run's evidence artifact
#
# The reds comparison is keyed on three failure classes and two summary counts,
# read from docs/infra/suite-truth.md:
#   RED module <name>      a test module whose tests crashed (signal ABRT)
#   RED compile <name>     a test module that failed to COMPILE (T564: the
#                          crash-regex does not see these — the failed step is
#                          the `zig test` invocation, not a crash line)
#   RED script <path>      a tools/*.sh regression that exited non-zero
#   COUNT steps-failed N   failed build steps (from the Build Summary line)
#   COUNT tests-crashed N  crashed tests (from the Build Summary line)
#
# The surfaces comparison is keyed on two lines read from
# docs/infra/suite-truth-manifest.md:
#   CONSOLE cosmetic-failed-command N  test-binary `failed command:` lines that
#                                      belong to no failed step — ratchet to 0
#   EVIDENCE <prefix>                  a reading the artifact must carry, matched
#                                      at the start of a line
#
# Task: T369 · Role: worker · Model: deepseek-v4-pro · Date: 2026-08-18
# Task: T531 (two surfaces) · Model: claude-opus-5 · Date: 2026-08-20
# Task: T789 (gate wiring) · Model: deepseek-v4-flash · Date: 2026-08-23
#
# T789 wired the three tiers the operator ruled on 2026-08-23 and closed the
# T788 gate-classification gap (the suite's failure mode shifted from crashes
# to assertion failures, and the crash-oriented regexes mis-read them):
#
#   TIER 2 (pre-consolidation, blocking) — this script, run explicitly:
#     `sh tools/suite-truth.sh` must exit 0 before any pass of the S06
#     script-consolidation or the S08 guard sprint lands. A red suite blocks
#     a consolidation pass; it does NOT block an unrelated commit.
#     Measured wall: 906 s (T788 baseline run 2026-08-23 ~16:32Z, guarded,
#     ReleaseSafe). Budget: the runner's 7200 s --max-wall ceiling below.
#
#   TIER 3 (scheduled, nightly on a quiet host) — `--scheduled`:
#     preflight refuses to start when a local model is resident (the
#     2026-08-08 load-contamination rule) or a fleet lane is in flight
#     (any tools/runner process) or another suite-truth run holds the lock;
#     writes its verdict to untracked/test-gate/last-result.json (where the
#     pre-commit hook reads it, so a red is visible without being asked);
#     expected wall 906 s — a run that doubles it is itself a signal.
#     A result older than its interval reads as UNKNOWN, never as green
#     (--read-result). TEST_GATE_FORCE=1 bypasses the preflight for controls.
#
#   GATE-CLASSIFICATION FIX (T788 finding, owned here):
#     - crashed modules (terminated with signal) and failed (assertion)
#       modules are extracted separately and both feed the module-level
#       RED comparison, reported apart;
#     - the Build Summary's `tests passed (N skipped, K failed)` form is
#       parsed (the old regex only read `K crashed` and silently returned
#       empty on the new form);
#     - the CONSOLE cosmetic calc subtracts failed steps as well as crashed
#       ones, so a real test failure is not counted as console noise;
#     - registered stderr leaks from passing test binaries (KNOWN_NOISE
#       below) are counted as debt, reported loudly, and ratcheted down
#       (a registered marker that stops appearing must be struck). The
#       mutant-battery M1-M10 leak (src/vb_mutants.zig, std.debug.print)
#       is the first entry; its fix is routing through evidence.print
#       (T531/T564 class, engine territory).

MANIFEST="docs/infra/suite-truth.md"
SURFACES="docs/infra/suite-truth-manifest.md"
RUNNER="tools/runner"
LOG=""
# Empty on purpose: a captured-log comparison must NAME its evidence artifact.
# Defaulting it would silently pair a fresh manifest with a stale artifact from
# some earlier run and call the evidence surface green.
EVIDENCE=""
EVIDENCE_DEFAULT="untracked/log/suite-evidence.log"
# T789: the result file the dashboard/hook reads (verdict + run date).
RESULT=""
RESULT_DEFAULT="untracked/test-gate/last-result.json"
# T789: staleness interval for --read-result (daily run + margin).
INTERVAL_HOURS="26"
# T789: scheduled mode (preflight + result write) / force result write on a
# captured-log comparison (controls only).
SCHEDULED=0
WRITE_RESULT=0
# T789: expected wall from the T788 baseline; a scheduled run that doubles it
# is itself a signal (host pressure or a slowed step).
EXPECTED_WALL_S="906"
# T789: KNOWN_NOISE — registered stderr leaks from PASSING test binaries,
# counted as debt (ratchet down; strike the entry when the leak is fixed).
# Format: <id>:<marker>:<owner>:<review-date>, entries separated by ';'.
# <marker> is a fixed string matched with index() within KNOWN_NOISE_WINDOW
# lines before a test-binary `failed command:` line (never a regex — the
# marker appears in test output, not in a format we control).
KNOWN_NOISE='vb_mutants-M1-M10-leak:[EXPECTED] M1-:T531/T564-class(evidence.print):2026-09-15'
KNOWN_NOISE_WINDOW="30"

# ── argument parsing ───────────────────────────────────────────────────────
while [ $# -gt 0 ]; do
  case "$1" in
    --log)
      [ -z "${2:-}" ] && { echo "suite-truth: --log needs a path" >&2; exit 2; }
      LOG="$2"; shift 2 ;;
    --manifest)
      [ -z "${2:-}" ] && { echo "suite-truth: --manifest needs a path" >&2; exit 2; }
      MANIFEST="$2"; shift 2 ;;
    --surfaces)
      [ -z "${2:-}" ] && { echo "suite-truth: --surfaces needs a path" >&2; exit 2; }
      SURFACES="$2"; shift 2 ;;
    --evidence)
      [ -z "${2:-}" ] && { echo "suite-truth: --evidence needs a path" >&2; exit 2; }
      EVIDENCE="$2"; shift 2 ;;
    --result)
      [ -z "${2:-}" ] && { echo "suite-truth: --result needs a path" >&2; exit 2; }
      RESULT="$2"; shift 2 ;;
    --interval-hours)
      [ -z "${2:-}" ] && { echo "suite-truth: --interval-hours needs a number" >&2; exit 2; }
      INTERVAL_HOURS="$2"; shift 2 ;;
    --read-result)
      SCHEDULED=0; READ_RESULT=1; shift ;;
    --scheduled)
      SCHEDULED=1; shift ;;
    --write-result)
      WRITE_RESULT=1; shift ;;
    --no-write-result)
      WRITE_RESULT=0; shift ;;
    "")
      shift ;;
    *)
      echo "suite-truth: unknown argument '$1' (--log <file>, --manifest <file>, --surfaces <file>, --evidence <file>, --result <file>, --interval-hours <n>, --read-result, --scheduled, --write-result, --no-write-result)" >&2
      exit 2 ;;
  esac
done

cd "$(git rev-parse --show-toplevel)" || { echo "suite-truth: not in a git repo" >&2; exit 2; }

# ── T789: read-result mode — surface the last run with a staleness verdict ──
# A result older than its interval reads as UNKNOWN, never as green (the
# 2026-08-21 manifest read as authoritative for two days after its own
# headline red was fixed). A RED result stays RED regardless of age — loud
# is the safe direction. Exit codes: 0 GREEN fresh · 1 RED · 2 UNKNOWN/stale
# · 3 absent/unreadable.
if [ "${READ_RESULT:-0}" = "1" ]; then
  [ -n "$RESULT" ] || RESULT="$(pwd)/$RESULT_DEFAULT"
  python3 - "$RESULT" "$INTERVAL_HOURS" <<'PYEOF'
import json, os, sys, time, datetime
path, interval_h = sys.argv[1], sys.argv[2]
try:
    interval = float(interval_h) * 3600
except ValueError:
    interval = 26 * 3600
if not os.path.isfile(path):
    print(f"test-gate: UNKNOWN - no suite-truth result recorded ({path}); a gate that has never run has nothing to say")
    sys.exit(3)
try:
    with open(path) as f:
        r = json.load(f)
except Exception as e:
    print(f"test-gate: UNKNOWN - result file {path} unreadable ({e}); treat as no-result")
    sys.exit(3)
run_ts = r.get("run_ts", "?")
wall = r.get("wall_s", "?")
log = r.get("log", "?")
verdict = r.get("verdict", "UNKNOWN")
now = time.time()
try:
    ts_norm = run_ts.replace("Z", "+00:00")
    age = now - datetime.datetime.fromisoformat(ts_norm).timestamp()
except Exception:
    age = None
if verdict == "RED":
    print(f"test-gate: RED - last full-suite run {run_ts} ({wall}s) failed its manifest comparison; the new red is loud: see {log}")
    sys.exit(1)
if age is not None and age > interval:
    print(f"test-gate: UNKNOWN - last result {run_ts} is older than {interval_h}h; a stale green reads as UNKNOWN, not green (run: sh tools/suite-truth.sh --scheduled)")
    sys.exit(2)
print(f"test-gate: GREEN - last full-suite run {run_ts} ({wall}s), observed == manifest")
sys.exit(0)
PYEOF
  RR_RC=$?
  exit "$RR_RC"
fi

# ── T789: scheduled preflight (quiet-host gate) ───────────────────────────
# The 2026-08-08 bogus 35-52 min readings came from a local model resident
# during a measured run. A scheduled run refuses to start while a local
# model is resident or fleet work is in flight; TEST_GATE_FORCE=1 bypasses
# the preflight (controls only). The refusal writes nothing — the previous
# result stands and ages toward UNKNOWN, which is the honest surface.
if [ "$SCHEDULED" -eq 1 ] && [ "${TEST_GATE_FORCE:-0}" != "1" ]; then
  if command -v ollama >/dev/null 2>&1 && ollama ps 2>/dev/null | awk 'NR > 1 && NF > 0' | grep -q .; then
    echo "suite-truth: REFUSED — a local model is resident (ollama ps non-empty); the load-contamination rule (2026-08-08) forbids a measured run" >&2
    exit 2
  fi
  if pgrep -f "mlx-engine" >/dev/null 2>&1; then
    echo "suite-truth: REFUSED — an mlx-engine runner is resident; wait for a quiet host" >&2
    exit 2
  fi
  if pgrep -f "tools/runner" >/dev/null 2>&1; then
    echo "suite-truth: REFUSED — fleet lanes are in flight (a tools/runner process is running); a scheduled suite wants a quiet host" >&2
    exit 2
  fi
  SCHED_LOCK="untracked/test-gate/suite-truth.lock"
  if [ -e "$SCHED_LOCK" ]; then
    echo "suite-truth: REFUSED — another suite-truth run is in flight ($SCHED_LOCK exists)" >&2
    exit 2
  fi
  mkdir -p "$(dirname "$SCHED_LOCK")"
  : > "$SCHED_LOCK"
  echo "suite-truth: scheduled preflight passed (no resident local model, no fleet runner, single instance)"
fi

# ── run the suite (or reuse a captured log) ────────────────────────────────
RUN_START_S=""
HOST_LOAD="?"
HOST_FREE_MB="?"
WALL_S="?"
if [ -z "$LOG" ]; then
  RUN_START_S=$(date +%s)
  HOST_LOAD=$(sysctl -n vm.loadavg 2>/dev/null || echo "?")
  HOST_FREE_MB=$(( $(vm_stat 2>/dev/null | awk '/Pages free/{print $3}' | tr -d '.') * 16 / 1024 )) 2>/dev/null || HOST_FREE_MB="?"
  if [ ! -x "$RUNNER" ]; then
    echo "suite-truth: $RUNNER missing — refuse to run an unguarded suite" >&2
    exit 2
  fi
  LOG="$(mktemp /tmp/weizigo/suite-truth-XXXXXX)" || { echo "suite-truth: mktemp failed" >&2; exit 2; }
  echo "suite-truth: running zig build test -Doptimize=ReleaseSafe (guarded) — log: $LOG"
  # The evidence artifact is TRUNCATED here, not appended to: an artifact that
  # carried lines from an earlier run would let a suite whose instruments went
  # silent still satisfy every EVIDENCE line — a green that means nothing.
  # Absolute, because not every addTest step in build.zig sets a cwd.
  [ -n "$EVIDENCE" ] || EVIDENCE="$(pwd)/$EVIDENCE_DEFAULT"
  case "$EVIDENCE" in /*) ;; *) EVIDENCE="$(pwd)/$EVIDENCE" ;; esac
  mkdir -p "$(dirname "$EVIDENCE")"
  : > "$EVIDENCE" || { echo "suite-truth: cannot write evidence artifact $EVIDENCE" >&2; exit 2; }
  echo "suite-truth: evidence artifact: $EVIDENCE (truncated)"
  export WEIZIGO_EVIDENCE="$EVIDENCE"
  # ReleaseSafe: the crashes this gate tracks are safety-check panics; they
  # are no-ops (UB) in ReleaseFast.  Flags match the 2026-08-18 run-2 measurement.
  "$RUNNER" --max-wall 7200 --max-cpu 28800 -- zig build test -Doptimize=ReleaseSafe >"$LOG" 2>&1
  SUITE_RC=$?
  WALL_S=$(( $(date +%s) - RUN_START_S ))
  echo "suite-truth: suite exit $SUITE_RC (a non-zero suite exit is expected while reds remain)"
  echo "suite-truth: wall ${WALL_S}s (expected ${EXPECTED_WALL_S}s, T788 baseline); load $HOST_LOAD; free ${HOST_FREE_MB}MB"
  if [ "$SCHEDULED" -eq 1 ] && [ "$WALL_S" -gt $((EXPECTED_WALL_S * 2)) ]; then
    echo "suite-truth: WALL SIGNAL — this run took ${WALL_S}s, more than 2× the expected ${EXPECTED_WALL_S}s. A doubled wall is itself a signal (host pressure or a slowed step); investigate before trusting its readings."
  fi
fi

if [ ! -f "$LOG" ]; then
  echo "suite-truth: log $LOG not found" >&2
  exit 2
fi
if [ ! -f "$MANIFEST" ]; then
  echo "suite-truth: manifest $MANIFEST not found" >&2
  exit 2
fi

# ── extract the observed failing set ───────────────────────────────────────
TMP="$(mktemp -d /tmp/weizigo/suite-truth-cmp-XXXXXX)" || { echo "suite-truth: mktemp failed" >&2; exit 2; }
# T789: the EXIT trap also clears the scheduled single-instance lock (the
# variable is empty for non-scheduled runs, so the rm is a harmless no-op).
trap 'rm -rf "$TMP"; rm -f "${SCHED_LOCK:-/nonexistent-suite-truth-lock}"' EXIT

# T789 (gate-classification fix): crashed modules and failed (assertion)
# modules are extracted SEPARATELY. The suite's failure mode shifted from
# crashes to assertion failures (T788), and the old single regex called
# everything "crashed". Both classes feed the module-level comparison below
# (a module that fails OR crashes is a red module), but they are reported
# apart so the manifest line says what really happened.
# Crashed test modules: `error: '<module>.test.<name>' terminated with signal ABRT`
grep -E "^error: '[^.']+\.test\..*terminated with signal" "$LOG" | sed -E "s/^error: '([^.']+)\.test\..*/\1/" | sort -u > "$TMP/obs.crashed"
# Failed (assertion) test modules: `error: '<module>.test.<name>' failed: ...`
grep -E "^error: '[^.']+\.test\..*failed:" "$LOG" | sed -E "s/^error: '([^.']+)\.test\..*/\1/" | sort -u > "$TMP/obs.failed"
cat "$TMP/obs.crashed" "$TMP/obs.failed" | sort -u > "$TMP/obs.modules"

# Compile-failing test modules: `failed command: ... zig test ... -Mroot=.../src/<mod>.zig`.
# A test target that fails to COMPILE never reaches the crash line the module
# regex reads (T564): the failed step's command is the `zig test` invocation
# itself, so the module is the basename of its -Mroot. Keep the two classes
# apart in the manifest (`RED module` vs `RED compile`) — a module can be in
# either class, and a compile failure hides the crash it would otherwise show.
grep -E "^failed command:.*zig test" "$LOG" | sed -E "s/.*-Mroot=[^ ]*\/src\/([^/]+\.zig).*/\1/" | sed -E 's/\.zig$//' | sort -u > "$TMP/obs.compile"

# Failed shell scripts: `failed command: ... && sh tools/<script>.sh`
grep -E "failed command:.* sh tools/[^ ]+\.sh" "$LOG" | sed -E "s/.* sh (tools\/[^ ]+\.sh).*/\1/" | sort -u > "$TMP/obs.scripts"

# Summary counts from the Build Summary line.
OBS_STEPS_FAILED=$(grep -oE "steps succeeded \([0-9]+ failed\)" "$LOG" | grep -oE "[0-9]+ failed" | grep -oE "[0-9]+" | tail -1)
# T789: the suite now prints `tests passed (N skipped, K failed)` (T788
# baseline) instead of `... K crashed`; the crash-only regex silently
# returned empty on the new form, making the COUNT comparison vacuous.
# Both forms are parsed; crashed stays gated, failed is reported loudly.
OBS_TESTS_CRASHED=$(grep -oE "tests passed \([0-9]+ skipped, [0-9]+ crashed\)" "$LOG" | grep -oE "[0-9]+ crashed" | grep -oE "[0-9]+" | tail -1)
OBS_TESTS_FAILED=$(grep -oE "tests passed \([0-9]+ skipped, [0-9]+ failed\)" "$LOG" | grep -oE "[0-9]+ failed" | grep -oE "[0-9]+" | tail -1)

# ── extract the manifest's expected set ────────────────────────────────────
grep -E "^RED module " "$MANIFEST" | sed -E "s/^RED module //" | sort -u > "$TMP/man.modules"
grep -E "^RED compile " "$MANIFEST" | sed -E "s/^RED compile //" | sort -u > "$TMP/man.compile"
grep -E "^RED script " "$MANIFEST" | sed -E "s/^RED script //" | sort -u > "$TMP/man.scripts"
MAN_STEPS_FAILED=$(grep -E "^COUNT steps-failed " "$MANIFEST" | sed -E "s/^COUNT steps-failed //" | tail -1)
MAN_TESTS_CRASHED=$(grep -E "^COUNT tests-crashed " "$MANIFEST" | sed -E "s/^COUNT tests-crashed //" | tail -1)

# ── compare ────────────────────────────────────────────────────────────────
DIRTY=0

echo ""
echo "=== suite-truth comparison ==="
echo "log: $LOG"

echo ""
echo "-- red test modules (crashed + failed) --"
echo "  observed: $(tr '\n' ' ' < "$TMP/obs.modules")"
echo "    crashed: $(tr '\n' ' ' < "$TMP/obs.crashed")"
echo "    failed : $(tr '\n' ' ' < "$TMP/obs.failed")  (T789: the suite fails by assertion now, not crash)"
echo "  manifest: $(tr '\n' ' ' < "$TMP/man.modules")"
ONLY_OBS_MOD=$(comm -23 "$TMP/obs.modules" "$TMP/man.modules")
ONLY_MAN_MOD=$(comm -13 "$TMP/obs.modules" "$TMP/man.modules")
if [ -n "$ONLY_OBS_MOD" ]; then
  echo "  NEW RED (not in manifest): $ONLY_OBS_MOD"
  DIRTY=1
fi
if [ -n "$ONLY_MAN_MOD" ]; then
  echo "  FIXED (in manifest, no longer crashing): $ONLY_MAN_MOD"
  DIRTY=1
fi

echo ""
echo "-- compile-failing test modules --"
echo "  observed: $(tr '\n' ' ' < "$TMP/obs.compile")"
echo "  manifest: $(tr '\n' ' ' < "$TMP/man.compile")"
ONLY_OBS_CFL=$(comm -23 "$TMP/obs.compile" "$TMP/man.compile")
ONLY_MAN_CFL=$(comm -13 "$TMP/obs.compile" "$TMP/man.compile")
if [ -n "$ONLY_OBS_CFL" ]; then
  echo "  NEW RED (not in manifest): $ONLY_OBS_CFL"
  DIRTY=1
fi
if [ -n "$ONLY_MAN_CFL" ]; then
  echo "  FIXED (in manifest, no longer failing to compile): $ONLY_MAN_CFL"
  DIRTY=1
fi

echo ""
echo "-- failed shell scripts --"
echo "  observed: $(tr '\n' ' ' < "$TMP/obs.scripts")"
echo "  manifest: $(tr '\n' ' ' < "$TMP/man.scripts")"
ONLY_OBS_SCR=$(comm -23 "$TMP/obs.scripts" "$TMP/man.scripts")
ONLY_MAN_SCR=$(comm -13 "$TMP/obs.scripts" "$TMP/man.scripts")
if [ -n "$ONLY_OBS_SCR" ]; then
  echo "  NEW RED (not in manifest): $ONLY_OBS_SCR"
  DIRTY=1
fi
if [ -n "$ONLY_MAN_SCR" ]; then
  echo "  FIXED (in manifest, no longer failing): $ONLY_MAN_SCR"
  DIRTY=1
fi

# ── surface 1: the console ─────────────────────────────────────────────────
#
# A `failed command:` line is honest when it belongs to a step that really
# failed, and noise when it does not.  Zig prints one for any test binary that
# wrote to stderr, pass or fail (Run.evalZigTest sets result_stderr on the
# success path), so before T531 every instrument reading cost the console one
# false red.  The count is relational, not a hardcoded total: cosmetic =
# test-binary failed-command lines minus crashed test steps.  It therefore
# stays meaningful as the real reds get fixed, and no one has to remember to
# re-baseline it.
echo ""
echo "-- surface 1: console --"
if [ -f "$SURFACES" ]; then
  FC_TEST=$(grep -cE "^failed command:.*/test --cache-dir" "$LOG")
  # The Build Summary tree lists only FAILED steps, one line each. The
  # tree appears TWICE: inline where each step failed, and again in the
  # recap after the "Build Summary:" line. Count the RECAP block only —
  # counting inline lines double-counts every failed step and hides
  # cosmetic noise (T789 found this on the 2026-08-23 verification run).
  SUMMARY_LN=$(grep -n "^Build Summary:" "$LOG" | tail -1 | cut -d: -f1)
  [ -n "$SUMMARY_LN" ] || SUMMARY_LN=1
  CRASHED_STEPS=$(tail -n +"$SUMMARY_LN" "$LOG" | grep -cE "^\+- run test .*crash")
  # T789: failed steps are subtracted too — a real test failure is not
  # console noise (T788: the main module's 3 failed tests were counted as
  # cosmetic because the calc only subtracted crash steps).
  FAILED_STEPS=$(tail -n +"$SUMMARY_LN" "$LOG" | grep -cE "^\+- run test .*fail")
  # T789: registered stderr leaks from passing test binaries (KNOWN_NOISE)
  # are debt, reported loudly, ratcheted down. The SUBTRACTION applies to
  # every log (real or captured — a quiet-host log compared offline must
  # reach the same verdict as the run that produced it); the RATCHET
  # (a marker that stops appearing must be struck) applies to REAL runs
  # only, because synthetic --log controls never contain the real suite's
  # noise markers and must not be told to strike the registry.
  KNOWN_LEAK_STEPS=0
  KNOWN_NOISE_FIXED=""
  if [ -n "$KNOWN_NOISE" ]; then
    echo "$KNOWN_NOISE" | tr ';' '\n' > "$TMP/known-noise-entries"
    while IFS= read -r entry; do
      [ -z "$entry" ] && continue
      id=${entry%%:*}
      rest=${entry#*:}
      marker=${rest%%:*}
      rest=${rest#*:}
      owner=${rest%%:*}
      review=${rest#*:}
      n=$(awk -v win="$KNOWN_NOISE_WINDOW" -v marker="$marker" '
        /^failed command:.*\/test --cache-dir/ {
          found = 0
          for (j = NR - win; j < NR; j++) {
            if (j >= 1 && index(line[j], marker) > 0) { found = 1; break }
          }
          if (found) count++
        }
        { line[NR] = $0 }
        END { print count + 0 }
      ' "$LOG")
      KNOWN_LEAK_STEPS=$((KNOWN_LEAK_STEPS + n))
      echo "    known leak: $id (${n} line(s), owner $owner, review $review)"
      if [ -n "$RUN_START_S" ] && ! grep -qF "$marker" "$LOG"; then
        KNOWN_NOISE_FIXED="${KNOWN_NOISE_FIXED}${id} "
      fi
    done < "$TMP/known-noise-entries"
  fi
  COSMETIC=$((FC_TEST - CRASHED_STEPS - FAILED_STEPS - KNOWN_LEAK_STEPS))
  [ "$COSMETIC" -lt 0 ] && COSMETIC=0
  MAN_COSMETIC=$(grep -E "^CONSOLE cosmetic-failed-command " "$SURFACES" | sed -E "s/^CONSOLE cosmetic-failed-command //" | tail -1)
  [ -n "$MAN_COSMETIC" ] || MAN_COSMETIC=0
  echo "  test-binary 'failed command:' lines: $FC_TEST"
  echo "  crashed test steps (Build Summary):  $CRASHED_STEPS"
  echo "  failed test steps (Build Summary):   $FAILED_STEPS (T789: subtracted — a real failure is not console noise)"
  echo "  known stderr leaks (KNOWN_NOISE):    $KNOWN_LEAK_STEPS"
  echo "  cosmetic (noise): observed=$COSMETIC manifest=$MAN_COSMETIC"
  if [ "$COSMETIC" -gt "$MAN_COSMETIC" ]; then
    echo "  REGRESSION: $COSMETIC cosmetic failed-command lines, manifest allows $MAN_COSMETIC."
    echo "    A passing test binary wrote to stderr.  Route the reading through"
    echo "    src/evidence.zig (evidence.print) instead of std.debug.print."
    DIRTY=1
  elif [ "$COSMETIC" -lt "$MAN_COSMETIC" ]; then
    echo "  RATCHET: only $COSMETIC cosmetic lines remain — lower CONSOLE"
    echo "    cosmetic-failed-command to $COSMETIC in $SURFACES."
    DIRTY=1
  fi
  # T789: a registered noise marker that stops appearing is a FIXED leak —
  # the registry must ratchet down (same discipline as the reds manifest).
  if [ -n "$KNOWN_NOISE_FIXED" ]; then
    echo "  RATCHET: registered noise no longer observed: $KNOWN_NOISE_FIXED"
    echo "    — strike the KNOWN_NOISE entry in tools/suite-truth.sh (a fixed leak must ratchet the registry down)."
    DIRTY=1
  fi
else
  echo "  UNCHECKED: surfaces manifest $SURFACES not found"
  DIRTY=1
fi

# ── surface 2: the evidence artifact ───────────────────────────────────────
#
# Every EVIDENCE prefix in the surfaces manifest must appear at the start of
# some line in the run's artifact.  This is the half that makes the console
# clean-up safe: an instrument whose reading stopped being emitted no longer
# hides in a quiet console, it fails here by name.
echo ""
echo "-- surface 2: evidence artifact --"
if [ ! -f "$SURFACES" ]; then
  echo "  UNCHECKED: surfaces manifest $SURFACES not found"
elif [ -z "$EVIDENCE" ]; then
  echo "  UNCHECKED: no evidence artifact named (pass --evidence with --log)."
  echo "    Not defaulted on purpose: a stale artifact would pass this check."
  DIRTY=1
elif [ ! -f "$EVIDENCE" ]; then
  echo "  MISSING: evidence artifact $EVIDENCE not found — the sink never wrote."
  DIRTY=1
else
  grep -E "^EVIDENCE " "$SURFACES" | sed -E "s/^EVIDENCE //" > "$TMP/man.evidence"
  EV_TOTAL=0
  EV_MISSING=0
  while IFS= read -r prefix; do
    [ -n "$prefix" ] || continue
    EV_TOTAL=$((EV_TOTAL + 1))
    if ! awk -v n="$prefix" 'index($0, n) == 1 { found = 1 } END { exit !found }' "$EVIDENCE"; then
      echo "  MISSING READING: $prefix"
      EV_MISSING=$((EV_MISSING + 1))
    fi
  done < "$TMP/man.evidence"
  echo "  artifact: $EVIDENCE ($(grep -c "" "$EVIDENCE") lines)"
  echo "  readings: $((EV_TOTAL - EV_MISSING))/$EV_TOTAL present"
  if [ "$EV_MISSING" -gt 0 ]; then
    echo "    An instrument stopped speaking, or its reading was reworded."
    echo "    Fix the instrument, or update the EVIDENCE line in $SURFACES."
    DIRTY=1
  fi
fi

echo ""
echo "-- summary counts --"
echo "  steps-failed: observed=$OBS_STEPS_FAILED manifest=$MAN_STEPS_FAILED"
echo "  tests-crashed: observed=$OBS_TESTS_CRASHED manifest=$MAN_TESTS_CRASHED"
echo "  tests-failed: observed=$OBS_TESTS_FAILED (T789: parsed from the new Build Summary form; gated by steps-failed)"
if [ -n "$OBS_STEPS_FAILED" ] && [ "$OBS_STEPS_FAILED" != "$MAN_STEPS_FAILED" ]; then
  echo "  MISMATCH: steps-failed observed $OBS_STEPS_FAILED != manifest $MAN_STEPS_FAILED"
  DIRTY=1
fi
if [ -n "$OBS_TESTS_CRASHED" ] && [ "$OBS_TESTS_CRASHED" != "$MAN_TESTS_CRASHED" ]; then
  echo "  MISMATCH: tests-crashed observed $OBS_TESTS_CRASHED != manifest $MAN_TESTS_CRASHED"
  DIRTY=1
fi

# ── T789: write the result file (tier 3 surface + hook staleness) ────────
# Written for a REAL suite run always; for a captured-log comparison only
# when --write-result (the controls' seeded-defect arm writes to a scratch
# path — a synthetic run must never clobber the live result).
if { [ -n "$RUN_START_S" ] || [ "$WRITE_RESULT" -eq 1 ]; }; then
  [ -n "$RESULT" ] || RESULT="$(pwd)/$RESULT_DEFAULT"
  mkdir -p "$(dirname "$RESULT")"
  [ -n "$WALL_S" ] || WALL_S=0
  {
    echo "$ONLY_OBS_MOD"
    echo "$ONLY_OBS_CFL"
    echo "$ONLY_OBS_SCR"
  } | grep -v '^$' > "$TMP/new-reds" 2>/dev/null || : > "$TMP/new-reds"
  python3 - "$RESULT" "$WALL_S" "$EXPECTED_WALL_S" "$HOST_LOAD" "$HOST_FREE_MB" "$LOG" "$EVIDENCE" "$MANIFEST" "$OBS_STEPS_FAILED" "$MAN_STEPS_FAILED" "$OBS_TESTS_CRASHED" "$OBS_TESTS_FAILED" "$KNOWN_LEAK_STEPS" "$COSMETIC" "$TMP/new-reds" "$DIRTY" <<'PYEOF'
import json, os, sys, time, datetime
(path, wall, exp_wall, load, free_mb, log, ev, man, obs_steps, man_steps, obs_crash, obs_fail, known_noise, cosmetic, newreds_file, dirty) = sys.argv[1:17]
verdict = "GREEN" if dirty == "0" else "RED"
new_reds = []
if os.path.isfile(newreds_file):
    with open(newreds_file) as f:
        new_reds = [l.rstrip("\n") for l in f if l.strip()]
def i0(v):
    try:
        return int(float(v))
    except Exception:
        return 0
rec = {
    "gate": "suite-truth",
    "verdict": verdict,
    "run_ts": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "wall_s": i0(wall),
    "expected_wall_s": i0(exp_wall),
    "load": load,
    "free_mb": free_mb,
    "local_model_resident": False,
    "log": log,
    "evidence": ev,
    "manifest": man,
    "observed_steps_failed": obs_steps,
    "manifest_steps_failed": man_steps,
    "tests_crashed": obs_crash,
    "tests_failed": obs_fail,
    "known_noise": int(known_noise),
    "console_cosmetic": int(cosmetic),
    "new_reds": new_reds,
}
with open(path, "w") as f:
    json.dump(rec, f, indent=2)
    f.write("\n")
print(f"suite-truth: result written to {path} (verdict={verdict})")
PYEOF
fi

echo ""
if [ "$DIRTY" -eq 0 ]; then
  echo "suite-truth: GREEN — observed failing set matches the manifest exactly,"
  echo "  the console carries no cosmetic noise, and every declared reading is"
  echo "  present in the evidence artifact."
  exit 0
else
  echo "suite-truth: RED — a surface differs from its manifest (see above)."
  echo "  A new red: add it to $MANIFEST (a RED/COUNT entry) after diagnosing it."
  echo "  A fixed red: strike its entry from $MANIFEST and ratchet the COUNTs down."
  exit 1
fi
