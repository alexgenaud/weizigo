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
# The reds comparison is keyed on two failure classes and two summary counts,
# read from docs/infra/suite-truth.md:
#   RED module <name>      a test module whose tests crashed (signal ABRT)
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

MANIFEST="docs/infra/suite-truth.md"
SURFACES="docs/infra/suite-truth-manifest.md"
RUNNER="tools/runner"
LOG=""
# Empty on purpose: a captured-log comparison must NAME its evidence artifact.
# Defaulting it would silently pair a fresh manifest with a stale artifact from
# some earlier run and call the evidence surface green.
EVIDENCE=""
EVIDENCE_DEFAULT="untracked/log/suite-evidence.log"

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
    "")
      shift ;;
    *)
      echo "suite-truth: unknown argument '$1' (--log <file>, --manifest <file>, --surfaces <file>, --evidence <file>)" >&2
      exit 2 ;;
  esac
done

cd "$(git rev-parse --show-toplevel)" || { echo "suite-truth: not in a git repo" >&2; exit 2; }

# ── run the suite (or reuse a captured log) ────────────────────────────────
if [ -z "$LOG" ]; then
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
  echo "suite-truth: suite exit $SUITE_RC (a non-zero suite exit is expected while reds remain)"
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
trap 'rm -rf "$TMP"' EXIT

# Crashed test modules: `error: '<module>.test.<name>' terminated with signal ABRT`
grep -E "^error: '[^.']+\.test\." "$LOG" | sed -E "s/^error: '([^.']+)\.test\..*/\1/" | sort -u > "$TMP/obs.modules"

# Failed shell scripts: `failed command: ... && sh tools/<script>.sh`
grep -E "failed command:.* sh tools/[^ ]+\.sh" "$LOG" | sed -E "s/.* sh (tools\/[^ ]+\.sh).*/\1/" | sort -u > "$TMP/obs.scripts"

# Summary counts from the Build Summary line.
OBS_STEPS_FAILED=$(grep -oE "steps succeeded \([0-9]+ failed\)" "$LOG" | grep -oE "[0-9]+ failed" | grep -oE "[0-9]+" | tail -1)
OBS_TESTS_CRASHED=$(grep -oE "tests passed \([0-9]+ skipped, [0-9]+ crashed\)" "$LOG" | grep -oE "[0-9]+ crashed" | grep -oE "[0-9]+" | tail -1)

# ── extract the manifest's expected set ────────────────────────────────────
grep -E "^RED module " "$MANIFEST" | sed -E "s/^RED module //" | sort -u > "$TMP/man.modules"
grep -E "^RED script " "$MANIFEST" | sed -E "s/^RED script //" | sort -u > "$TMP/man.scripts"
MAN_STEPS_FAILED=$(grep -E "^COUNT steps-failed " "$MANIFEST" | sed -E "s/^COUNT steps-failed //" | tail -1)
MAN_TESTS_CRASHED=$(grep -E "^COUNT tests-crashed " "$MANIFEST" | sed -E "s/^COUNT tests-crashed //" | tail -1)

# ── compare ────────────────────────────────────────────────────────────────
DIRTY=0

echo ""
echo "=== suite-truth comparison ==="
echo "log: $LOG"

echo ""
echo "-- crashed test modules --"
echo "  observed: $(tr '\n' ' ' < "$TMP/obs.modules")"
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
  # The Build Summary tree lists only FAILED steps, one line each.
  CRASHED_STEPS=$(grep -cE "^\+- run test .*crash" "$LOG")
  COSMETIC=$((FC_TEST - CRASHED_STEPS))
  [ "$COSMETIC" -lt 0 ] && COSMETIC=0
  MAN_COSMETIC=$(grep -E "^CONSOLE cosmetic-failed-command " "$SURFACES" | sed -E "s/^CONSOLE cosmetic-failed-command //" | tail -1)
  [ -n "$MAN_COSMETIC" ] || MAN_COSMETIC=0
  echo "  test-binary 'failed command:' lines: $FC_TEST"
  echo "  crashed test steps (Build Summary):  $CRASHED_STEPS"
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
if [ -n "$OBS_STEPS_FAILED" ] && [ "$OBS_STEPS_FAILED" != "$MAN_STEPS_FAILED" ]; then
  echo "  MISMATCH: steps-failed observed $OBS_STEPS_FAILED != manifest $MAN_STEPS_FAILED"
  DIRTY=1
fi
if [ -n "$OBS_TESTS_CRASHED" ] && [ "$OBS_TESTS_CRASHED" != "$MAN_TESTS_CRASHED" ]; then
  echo "  MISMATCH: tests-crashed observed $OBS_TESTS_CRASHED != manifest $MAN_TESTS_CRASHED"
  DIRTY=1
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
