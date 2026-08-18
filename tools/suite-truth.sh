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
# Usage:
#   sh tools/suite-truth.sh              run the suite, then compare (≈14 min)
#   sh tools/suite-truth.sh --log F      skip the run; compare against a
#                                        captured suite log (controls/offline)
#   sh tools/suite-truth.sh --manifest M override the manifest path (controls)
#
# The comparison is keyed on two failure classes and two summary counts:
#   RED module <name>      a test module whose tests crashed (signal ABRT)
#   RED script <path>      a tools/*.sh regression that exited non-zero
#   COUNT steps-failed N   failed build steps (from the Build Summary line)
#   COUNT tests-crashed N  crashed tests (from the Build Summary line)
#
# Task: T369 · Role: worker · Model: deepseek-v4-pro · Date: 2026-08-18

MANIFEST="docs/infra/suite-truth.md"
RUNNER="tools/runner"
LOG=""

# ── argument parsing ───────────────────────────────────────────────────────
while [ $# -gt 0 ]; do
  case "$1" in
    --log)
      [ -z "${2:-}" ] && { echo "suite-truth: --log needs a path" >&2; exit 2; }
      LOG="$2"; shift 2 ;;
    --manifest)
      [ -z "${2:-}" ] && { echo "suite-truth: --manifest needs a path" >&2; exit 2; }
      MANIFEST="$2"; shift 2 ;;
    "")
      shift ;;
    *)
      echo "suite-truth: unknown argument '$1' (--log <file>, --manifest <file>)" >&2
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
  echo "suite-truth: GREEN — observed failing set matches the manifest exactly."
  exit 0
else
  echo "suite-truth: RED — observed failing set differs from the manifest (see above)."
  echo "  A new red: add it to $MANIFEST (a RED/COUNT entry) after diagnosing it."
  echo "  A fixed red: strike its entry from $MANIFEST and ratchet the COUNTs down."
  exit 1
fi
