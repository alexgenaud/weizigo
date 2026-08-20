#!/bin/sh
# regression-claimlint-volatile.sh — controls for the C10 VOLATILE check (T421).
#
# C2 DEAD-LINKS flags only paths that are MISSING. A /tmp citation whose file
# still exists is not missing, so it passes — and the defect only becomes
# visible after the evidence is destroyed, which is exactly too late. T421
# measured 344 /tmp paths cited in committed docs; 43 were already gone.
# C10 flags the citation CLASS: any evidence path outside the repo — /tmp,
# /private/tmp, an absolute path that does not resolve inside the tree, or
# untracked/ — whether or not the file currently exists. Report-only (T421):
# it must NOT move any existing floor; the C10 floor is proposed separately.
#
# Three checks, all run from the repo root:
#   seeded-defect: a fixture doc citing /tmp/weizigo/c10-seeded.json — a path
#                  that EXISTS on disk — MUST be reported by C10. This is the
#                  whole defect: the file is present, so C2 passes it.
#   null-control:  with the fixture removed, the fixture path must NOT appear
#                  in the output, and every pre-existing counter (C1a/C1b/C2/
#                  C3/C4/C5/C6/C7/C8/C9, A, calibration) must be byte-identical
#                  to the fixture-less baseline.
#   report-only:   C10 must not change the run's exit status (it reports; it
#                  does not fail, yet).
#
# Task: T421 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-08
# T448: kill-survival + startup check (glm-5.2/T448, 2026-08-19). The
# fixture doc ($FIXTURE) was previously removed only in the EXIT trap;
# a SIGKILLed run left it in the tree. T448 adds INT/TERM/HUP to the trap
# (safety net) and a start-up check that REFUSES to run if the fixture
# from a previous (killed) run is still present. SIGKILL bypasses traps,
# so the start-up check is the load-bearing half.

# T448 (kill-survival self-check recursion guard): the arm below
# re-invokes `sh "$0"` to exercise the start-up check against a planted
# stale fixture. Without this guard, the recursive invocation runs the
# SAME arm and creates the SAME fixture — infinite recursion until the
# OS kills the test (T448.2 observed 120s timeout, 2026-08-19). When
# SKIP_KILL_SURVIVAL=1 is set, we skip the arms section (including
# this guard's own arm) but keep the start-up check and the trap live
# so the recursive invocation can demonstrate the refusal and the
# clean re-entry in turn.
SKIP_KILL_SURVIVAL="${SKIP_KILL_SURVIVAL:-0}"

set -e

CLAIMLINT="zig-out/bin/weizigo-claimlint"
FIXTURE="docs/evidence/C10-VOLATILE-SEEDED.md"
SEEDED_PATH="/tmp/weizigo/c10-volatile-seeded-8f3a2e.json"

# ── T448: start-up check (load-bearing) ─────────────────────────────────
# If a previous run was killed mid-arm (SIGKILL, uncaught signal), the
# fixture doc from that run is still in the live tree. The pre-T448
# code would silently overwrite it on the next run — hiding the evidence
# that a run was killed, and leaving a brief window where the project's
# claimlint readings were not its own. Refuse to run until the operator
# inspects and removes the file by hand.
if [ -e "$FIXTURE" ]; then
    echo "regression-claimlint-volatile.sh: REFUSED — stale fixture from a previous run:" >&2
    echo "    $FIXTURE" >&2
    echo "A previous run was killed (SIGKILL or uncaught signal); the EXIT trap did not run." >&2
    echo "The startup check is the load-bearing guard — SIGKILL bypasses traps, and" >&2
    echo "tools/runner's SIGKILL on wall/CPU/RSS/progress guards is routine in this fleet." >&2
    echo "Remove the file by hand (after inspecting it is fixture-shaped and not yours)" >&2
    echo "and re-run. The script will not silently overwrite — that hides evidence (T445)." >&2
    exit 3
fi

cd "$(git rev-parse --show-toplevel)"

echo "=== regression-claimlint-volatile: pre-flight ==="
if ! test -x "$CLAIMLINT"; then
    echo "SKIP: $CLAIMLINT not found — build with 'zig build' first"
    exit 0
fi
echo "  $CLAIMLINT is executable"

# The seeded citation must point at a file that EXISTS — the whole defect is
# that an existing /tmp file passes every check until the sweep destroys it.
mkdir -p /tmp/weizigo
printf '{"seeded": true}\n' > "$SEEDED_PATH"
echo "  seeded target exists: $SEEDED_PATH"

TMPDIR=$(mktemp -d)
# T448: trap on EXIT/INT/TERM/HUP — previously EXIT only, so SIGKILL
# and an uncaught signal would leave the fixture in the live tree.
# The startup check above is the load-bearing guard; this trap is the
# safety net for signals that DO let cleanup run.
cleanup() { rm -rf "$TMPDIR"; rm -f "$FIXTURE"; }
trap cleanup EXIT INT TERM HUP

# T448 (kill-survival recursion guard): if the script is re-entered by
# the kill-survival arm below with SKIP_KILL_SURVIVAL=1 set, the
# recursive invocation must NOT run the arms (including itself). It
# already hit the start-up check (above) and the trap (set above) on
# the way in — both are what we are testing. Exit cleanly so the
# caller sees RC=3 from the start-up refusal (when the fixture is
# present) or RC=0 from a clean re-entry (when the cleanup removed it).
# Without this guard the recursive invocation would re-run the same
# arm and create the same fixture, recursing until the OS killed the
# test (T448.2 observed 120s timeout, 2026-08-19).
if [ "$SKIP_KILL_SURVIVAL" = "1" ]; then
    exit 0
fi

# ── baseline (no fixture): capture the run the tree is expected to keep ──
set +e
"$CLAIMLINT" > "$TMPDIR/baseline.out" 2>/dev/null
BASELINE_EXIT=$?
set -e
echo ""
echo "=== regression-claimlint-volatile: baseline (no fixture) ==="
echo "  baseline exit: $BASELINE_EXIT"

# ── seeded-defect: fixture doc citing an EXISTING /tmp path ─────────────
cat > "$FIXTURE" <<EOF
# C10 seeded fixture (T421 regression control — do not commit)

This fixture document cites an evidence path that exists on disk right now:

\`$SEEDED_PATH\`

Under the pre-T421 claimlint this citation passes every check — the file is
not missing — which is the whole defect. C10 must report it regardless.
EOF
echo ""
echo "=== regression-claimlint-volatile: seeded-defect ==="
echo "  fixture: $FIXTURE"
set +e
"$CLAIMLINT" > "$TMPDIR/seeded.out" 2>/dev/null
SEEDED_EXIT=$?
set -e
echo "  seeded exit: $SEEDED_EXIT (must equal baseline exit $BASELINE_EXIT — report-only)"

if ! grep -Fq "$SEEDED_PATH" "$TMPDIR/seeded.out"; then
    echo "FAIL: seeded-defect — $SEEDED_PATH (an EXISTING /tmp file) is not"
    echo "      reported by claimlint. This is the whole defect: a /tmp citation"
    echo "      whose file still exists passes C2 and stays invisible until the"
    echo "      evidence is destroyed. A control that has been red."
    exit 1
fi
echo "PASS: seeded-defect — an existing /tmp citation is reported"

if [ "$SEEDED_EXIT" -ne "$BASELINE_EXIT" ]; then
    echo "FAIL: report-only — C10 changed the exit status ($BASELINE_EXIT -> $SEEDED_EXIT)."
    echo "      C10 must report without failing the run; the floor is proposed separately."
    exit 1
fi
echo "PASS: report-only — C10 does not change the run's exit status"

# ── null-control: fixture removed, output returns to baseline ────────────
rm -f "$FIXTURE"
echo ""
echo "=== regression-claimlint-volatile: null-control ==="
set +e
"$CLAIMLINT" > "$TMPDIR/null.out" 2>/dev/null
NULL_EXIT=$?
set -e

if grep -Fq "$SEEDED_PATH" "$TMPDIR/null.out"; then
    echo "FAIL: null-control — $SEEDED_PATH still reported after the fixture was removed"
    exit 1
fi
echo "PASS: null-control — fixture path absent once the fixture doc is gone"

# The null run is on the same tree as the baseline (both fixture-less), so the
# outputs must be byte-identical — the C10 counter included. Any difference is
# a counter the new code moved, which the regression control forbids.
if ! cmp -s "$TMPDIR/baseline.out" "$TMPDIR/null.out"; then
    echo "FAIL: null-control — claimlint output differs between two identical runs:"
    diff "$TMPDIR/baseline.out" "$TMPDIR/null.out" | head -20
    exit 1
fi
echo "PASS: null-control — output byte-identical to baseline on the same tree"

# ── T448: kill-survival — start-up check refuses stale fixture ────────────
# Plant a stale fixture doc (mimics a SIGKILLed previous run leaving
# residue in the live tree) and re-invoke the script in a child shell
# WITH the recursion guard set, so the recursive invocation runs only
# the start-up check (and the other T448 plumbing) but skips THIS arm.
# Without the guard the recursive invocation would run the same arm and
# plant the same fixture, recursing until the OS killed the test
# (T448.2 observed a 120s timeout, 2026-08-19).
echo ""
echo "=== regression-claimlint-volatile: kill-survival self-check ==="
cat > "$FIXTURE" <<'EOF'
# stale fixture (T448 arm — do not commit)
EOF
# `set +e` locally so the recursive invocation's expected non-zero exit
# (the very thing this arm asserts on) does not abort us. `|| true`
# alone would mask the exit code from $?; capturing it before turning
# `set -e` back on is the only way to read it correctly.
set +e
OUT=$( SKIP_KILL_SURVIVAL=1 sh "$0" 2>&1 )
RC=$?
cleanup >/dev/null 2>&1
# Re-invoke after cleanup: must succeed again (proves the refusal was
# strictly caused by the stale fixture, not some other state). Same
# recursion guard — we want the start-up check only, not the whole suite.
OUT_CLEAN=$( SKIP_KILL_SURVIVAL=1 sh "$0" 2>&1 )
RC_CLEAN=$?
set -e
if [ "$RC" -eq 3 ] && echo "$OUT" | grep -q "REFUSED.*stale fixture" && echo "$OUT" | grep -q "$FIXTURE"; then
    echo "PASS: stale-fixture refusal — start-up check named the path (RC=3)"
else
    echo "FAIL: stale-fixture refusal (RC=$RC, expected 3):"
    echo "$OUT" | sed 's/^/      /' | head -5
    exit 1
fi
# The re-run after cleanup may also fail for its own reasons (e.g. the
# seeded /tmp file was rm'd by the trap on a previous interrupted run);
# we only assert it didn't fail with the stale-fixture refusal code.
if [ "$RC_CLEAN" -eq 3 ]; then
    echo "FAIL: clean re-run still refused with stale-fixture code — cleanup didn't remove the residue"
    exit 1
else
    echo "PASS: clean re-run did not refuse on stale-fixture grounds (RC=$RC_CLEAN)"
fi

# ── T448: null — live tree byte-identical after the full run ───────────
# After the suite completes, the live tree must carry no residue. We
# assert against the FIXTURE path specifically (a git-status --porcelain
# would catch unrelated user edits; this script only owns $FIXTURE).
echo ""
echo "=== regression-claimlint-volatile: null — no live-tree residue ==="
if [ ! -e "$FIXTURE" ]; then
    echo "PASS: $FIXTURE absent after the run"
else
    echo "FAIL: $FIXTURE still present after the run:"
    ls -la "$FIXTURE" | sed 's/^/      /'
    exit 1
fi

echo ""
echo "=== regression-claimlint-volatile: all controls passed ==="
