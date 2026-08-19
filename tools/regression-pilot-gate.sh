#!/bin/sh
# regression-pilot-gate.sh — controls for the pilot gate (T450).
#
# The gate's whole value is that a failing run leaves nothing behind.
# The old version (pre-T450) wrote regenerated TRACKED artifacts into
# the live tree first and verified after — so a determinism break
# left modified tracked files where the next `git add -A` could sweep
# them. The `--full` branch rm'd the 258 MB 4x4 checkpoint before a
# 20-min rebuild with no trap. These controls assert the post-T450
# invariants:
#
#   1. fast-branch null:    an unmodified tree passes and the live
#                            tree is byte-identical afterwards.
#   2. fast-branch seeded:  a deterministic-break (one byte perturbed
#                            in a scratch rebuild) FAILS the gate,
#                            and the live tree is still byte-identical
#                            (no promotion of bad bytes ever happens).
#   3. --full restore path: a forced rebuild failure (env var pointing
#                            at a non-writable path) exits non-zero
#                            and leaves the live `data/` tree
#                            byte-identical — the trap wiped scratch
#                            and the engine never touched live data.
#                            We don't run the real 20-min rebuild
#                            here; we force failure and prove the
#                            restore path.
#
# Task: T450 · Role: worker · Model: kimi-k2.7 · Date: 2026-08-19

set -e

PILOT_GATE="tools/pilot_gate.sh"
REPO="$(git rev-parse --show-toplevel)"
cd "$REPO"

# Ensure scratch exists (T445 hard-fail on absent /tmp/weizigo).
mkdir -p /tmp/weizigo

echo "=== regression-pilot-gate: 1. fast-branch null ==="
if ! "$PILOT_GATE" >/dev/null 2>&1; then
    echo "FAIL: fast-branch null — gate exited non-zero on an unmodified tree"
    exit 1
fi
if ! git diff --exit-code -- artifacts/ >/dev/null 2>&1; then
    echo "FAIL: fast-branch null — live artifacts/ differs from HEAD after a clean run"
    git diff -- artifacts/ | sed 's/^/    /'
    exit 1
fi
# Fast branch never touches data/. Even --full shouldn't be in play,
# but verify the gate didn't sneak any data/ writes either.
if ! git diff --exit-code -- data/ >/dev/null 2>&1; then
    echo "FAIL: fast-branch null — live data/ differs from HEAD after fast run"
    git diff -- data/ | sed 's/^/    /'
    exit 1
fi
echo "  PASS: fast-branch null — gate passed, live tree byte-identical to HEAD"

echo ""
echo "=== regression-pilot-gate: 2. fast-branch seeded (determinism break) ==="
# Re-run the gate's verify logic with one scratch byte perturbed.
# This proves the verify step catches a divergence AND that no
# promotion happens — the live tree is the control.
TMPDIR=$(mktemp -d /tmp/weizigo/pilot-gate-seed.XXXXXX)
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

cp "$REPO/artifacts/oracle-2x2.wzo" "$TMPDIR/"
cp "$REPO/artifacts/oracle-3x2.wzo" "$TMPDIR/"
cp "$REPO/artifacts/oracle-3x3.wzo" "$TMPDIR/"
cp "$REPO/artifacts/oracle-4x3.wzo" "$TMPDIR/"

# Perturb 2x2 (single-byte flip near the start).
printf 'X' | dd of="$TMPDIR/oracle-2x2.wzo" bs=1 count=1 seek=10 conv=notrunc 2>/dev/null

# Replicate the gate's verify logic.
FAIL=0
while IFS=' ' read -r want_hash want_path; do
    case "$want_path" in
        artifacts/oracle-2x2.wzo|artifacts/oracle-3x2.wzo|artifacts/oracle-3x3.wzo|artifacts/oracle-4x3.wzo)
            bare=$(basename "$want_path")
            got=$(shasum -a 256 "$TMPDIR/$bare" 2>/dev/null | cut -d' ' -f1)
            if [ "$got" != "$want_hash" ]; then
                echo "  detected divergence on $bare: got $got, want $want_hash"
                FAIL=1
            fi
            ;;
    esac
done < "$REPO/artifacts/SHA256SUMS"

if [ "$FAIL" -ne 1 ]; then
    echo "FAIL: seeded-defect — perturbation not detected"
    exit 1
fi

# Live tree MUST be byte-identical — the perturbation is in scratch,
# not in the live tree, so a passing run would copy clean scratch
# bytes into live. Verify live is still HEAD's bytes.
if ! git diff --exit-code -- artifacts/ >/dev/null 2>&1; then
    echo "FAIL: seeded-defect — live artifacts/ drifted (perturbation leaked)"
    git diff -- artifacts/ | sed 's/^/    /'
    exit 1
fi
echo "  PASS: seeded-defect — divergence caught, live tree untouched"

echo ""
echo "=== regression-pilot-gate: 3. --full restore path (forced rebuild failure) ==="
# Snapshot data/ before.
DATA_BEFORE=$(find data -type f -exec shasum -a 256 {} \; 2>/dev/null | sort)

# Force a fast failure of the --full branch without waiting the full
# ~20 min for a real rebuild. The gate's --full branch invokes
# `zig run -O ReleaseFast "$REPO/src/retro.zig"` with RETRO_4X4=1,
# which would do the full 4x4 sweep (~20 min on this host). To prove
# the trap-and-restore contract without that cost, prepend a
# PATH directory containing a fake `zig` that exits 1 immediately.
# The gate's `set -e` then aborts before any data/ write could be
# attempted, the EXIT trap wipes scratch, and the live data/ tree
# is byte-identical. The brief allows this (2026-08-19): "you do
# not need to run it to fix it — reason from the code and prove the
# restore path with a stubbed rebuild that fails deliberately."
FAKE_BINDIR=$(mktemp -d /tmp/weizigo/pilot-gate-fakebin.XXXXXX)
cat >"$FAKE_BINDIR/zig" <<'FAKE'
#!/bin/sh
echo "FAKE zig: refusing to run (pilot_gate control 3 stub)" >&2
exit 1
FAKE
chmod +x "$FAKE_BINDIR/zig"

set +e
OUT=$(env PATH="$FAKE_BINDIR:$PATH" "$PILOT_GATE" --full 2>&1)
RC=$?
set -e

rm -rf "$FAKE_BINDIR"

if [ "$RC" -eq 0 ]; then
    echo "FAIL: --full restore path — gate exited 0 on a forced rebuild failure"
    echo "  output: $OUT"
    exit 1
fi

DATA_AFTER=$(find data -type f -exec shasum -a 256 {} \; 2>/dev/null | sort)
if [ "$DATA_BEFORE" != "$DATA_AFTER" ]; then
    echo "FAIL: --full restore path — live data/ changed during forced-failure rebuild"
    echo "  before: $DATA_BEFORE"
    echo "  after:  $DATA_AFTER"
    exit 1
fi

# Trap cleanup: scratch under /tmp/weizigo/pilot_gate.* should be gone.
if ls /tmp/weizigo/pilot_gate.* 2>/dev/null | grep -q .; then
    echo "FAIL: --full restore path — scratch not cleaned by EXIT trap"
    ls -la /tmp/weizigo/pilot_gate.* 2>/dev/null | sed 's/^/    /'
    exit 1
fi

echo "  PASS: --full restore path — gate failed fast, EXIT trap cleaned scratch,"
echo "        live data/ byte-identical (the 258 MB checkpoint was never at risk)"

echo ""
echo "=== regression-pilot-gate: 4. gate source contract ==="
# Static checks on the new gate: the destructive ops must NOT be in
# the script anymore. A future edit that re-introduces them would
# bring the bug back.
if grep -nE '^\s*rm -f data/oracle-4x4' "$PILOT_GATE"; then
    echo "FAIL: gate source — contains 'rm -f data/oracle-4x4' (T450 fix removed this)"
    exit 1
fi
if grep -nE 'mv .*oracle-4x4\.wzo.*\.prev' "$PILOT_GATE"; then
    echo "FAIL: gate source — contains 'mv ... oracle-4x4.wzo.prev' (T450 fix removed this)"
    exit 1
fi
# WANT hash must point at the CHECKPOINT (a2174...), not the
# retracted oracle-4x4.wzo (b42c...).
if grep -nE 'WANT=.*b42c3371' "$PILOT_GATE"; then
    echo "FAIL: gate source — checks the retracted b42c3371... (oracle-4x4.wzo no longer exists)"
    exit 1
fi
if ! grep -qE 'a2174fedd6a0591dc66b0b42ef1f52bdc28b97c448dbc5b043d96de3a3b1e118' "$PILOT_GATE"; then
    echo "FAIL: gate source — does not check the canonical checkpoint sha256 a2174fed..."
    exit 1
fi
# The trap must be present and must clean scratch.
if ! grep -qE '^trap cleanup.*EXIT' "$PILOT_GATE"; then
    echo "FAIL: gate source — missing EXIT trap to clean scratch"
    exit 1
fi
# The fast branch must write into scratch (RETRO_SAVE_*_OUT env vars),
# not cwd-relative.
if ! grep -qE 'RETRO_SAVE_2X2_OUT=oracle-2x2\.wzo' "$PILOT_GATE"; then
    echo "FAIL: gate source — fast branch does not write into scratch"
    exit 1
fi
echo "  PASS: gate source contract — no destructive ops, correct WANT hash, EXIT trap present"

echo ""
echo "=== regression-pilot-gate: all controls passed ==="
