#!/usr/bin/env bash
# regression-managent-integrity.sh
# T204 regression test: managent suggest collision-safety + audit detection
#
# Seeds a temp store with next_id ≤ an existing T-ID, runs suggest, asserts
# the existing record and bundle survive, and asserts audit flags the collision.
# Must be RED against current bin/managent before the fix lands.
#
# Usage:  tools/regression-managent-integrity.sh [--build]
#   --build: rebuild managent from source before testing

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
MG="$PROJECT/bin/managent"

FAIL=0

if [ "${1:-}" = "--build" ]; then
    echo "  rebuilding managent..."
    (cd "$PROJECT" && zig build -Doptimize=ReleaseSafe 2>&1)
    cp "$PROJECT/zig-out/bin/managent" "$MG"
fi

# ── Setup: temp store in ephemeral ──────────────────────────────────────────
TMPDIR="$(mktemp -d /tmp/weizigo/managent-integrity-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

# Create minimal repo structure the binary expects
mkdir -p "$TMPDIR/docs/infra/managent"
mkdir -p "$TMPDIR/untracked"
touch "$TMPDIR/.git"

# Seed an existing task T105 with next_id=105 (next_id ≤ max T-ID → collision)
# When suggest runs, it will read next_id=105 and mint T105, clobbering this one.
EXISTING_BUNDLE="untracked/T105-important-experiment.md"
echo "# T105 — important experiment" > "$TMPDIR/$EXISTING_BUNDLE"

# Record the bundle content hash for survival check
BUNDLE_HASH_BEFORE="$(sha256sum "$TMPDIR/$EXISTING_BUNDLE" | cut -d' ' -f1)"

cat > "$TMPDIR/docs/infra/managent/tasks.json" <<'JSONEOF'
{
  "T105": {
    "status": "dispatchable",
    "agent": null,
    "bundle": "untracked/T105-important-experiment.md",
    "set": "A",
    "holds": [],
    "needs": [],
    "caps": [],
    "added": "2026-08-01T00:00:00Z",
    "claimed": null,
    "done": null,
    "dispatched": null,
    "dispatched_to": null,
    "note": null,
    "claim_count": 0
  },
  "_sys": {
    "next_id": 105,
    "directive_next": 1
  }
}
JSONEOF

echo ""
echo "  T204 regression: managent integrity"

# ── Check 1: suggest does not destroy existing task record ───────────────────
echo "        1. suggest preserves existing task record"

ORIG_TASK_COUNT=$(cd "$TMPDIR" && "$MG" status --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d))" 2>/dev/null)
echo "           tasks before suggest: $ORIG_TASK_COUNT"

# Run suggest — note: this will try to read state_path from the repo root,
# but the binary finds repo root from cwd. We run from TMPDIR.
(cd "$TMPDIR" && "$MG" suggest "test-slug" 2>/dev/null) || true

TASK_COUNT_AFTER=$(cd "$TMPDIR" && "$MG" status --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d))" 2>/dev/null)
echo "           tasks after suggest: $TASK_COUNT_AFTER"

# Check that T105 still exists in the state
T105_EXISTS=$(cd "$TMPDIR" && "$MG" show T105 2>/dev/null)
if echo "$T105_EXISTS" | grep -q "T105"; then
    echo "           PASS: T105 record survives suggest"
else
    echo "           FAIL: T105 record lost after suggest"
    FAIL=1
fi

# ── Check 2: suggest does not destroy existing bundle file ───────────────────
echo "        2. suggest preserves existing bundle file"

BUNDLE_HASH_AFTER="$(sha256sum "$TMPDIR/$EXISTING_BUNDLE" 2>/dev/null | cut -d' ' -f1)"
if [ "$BUNDLE_HASH_BEFORE" = "$BUNDLE_HASH_AFTER" ]; then
    echo "           PASS: bundle file unchanged (hash: ${BUNDLE_HASH_BEFORE:0:16}...)"
else
    echo "           FAIL: bundle file was modified or overwritten"
    echo "           before: ${BUNDLE_HASH_BEFORE:0:16}..."
    echo "           after:  ${BUNDLE_HASH_AFTER:0:16}..."
    FAIL=1
fi

# ── Check 3: auto-correction of next_id on load ──────────────────────────────
echo "        3. parseStateJson auto-corrects next_id ≤ max(T-ID)"

# Seed a fresh state with the collision
cat > "$TMPDIR/docs/infra/managent/tasks.json" <<'JSONEOF'
{
  "T105": {
    "status": "dispatchable",
    "agent": null,
    "bundle": "untracked/T105-important-experiment.md",
    "set": "A",
    "holds": [],
    "needs": [],
    "caps": [],
    "added": "2026-08-01T00:00:00Z",
    "claimed": null,
    "done": null,
    "dispatched": null,
    "dispatched_to": null,
    "note": null,
    "claim_count": 0
  },
  "_sys": {
    "next_id": 100,
    "directive_next": 1
  }
}
JSONEOF

# Running suggest should auto-correct and mint T106, not T100 or T105
SUGGEST_OUT=$(cd "$TMPDIR" && "$MG" suggest "auto-correct-test" 2>/dev/null)
echo "           suggest output: $SUGGEST_OUT"

if echo "$SUGGEST_OUT" | grep -q "T106"; then
    echo "           PASS: suggest auto-corrected next_id and minted T106 (not T100 or T105)"
else
    echo "           FAIL: suggest did not auto-correct; output was: $SUGGEST_OUT"
    FAIL=1
fi

# Verify T105 still exists after auto-correction
T105_AFTER=$(cd "$TMPDIR" && "$MG" show T105 2>/dev/null)
if echo "$T105_AFTER" | grep -q "T105"; then
    echo "           PASS: T105 survives after auto-correction"
else
    echo "           FAIL: T105 lost after auto-correction"
    FAIL=1
fi

# Audit should now be clean (next_id was auto-corrected)
AUDIT_OUT2=$(cd "$TMPDIR" && "$MG" audit 2>/dev/null)
AUDIT_RC2=$?
if [ "$AUDIT_RC2" -eq 0 ]; then
    echo "           PASS: audit clean after auto-correction"
else
    echo "           FAIL: audit non-zero after auto-correction: $AUDIT_OUT2"
    FAIL=1
fi

# ── Check 4: T209 — suggest output is minimal dispatch line ────────────────
echo "        4. T209: suggest prints minimal dispatch line"

SUGGEST_OUT2=$(cd "$TMPDIR" && "$MG" suggest "t209-test" --model DSPro 2>/dev/null)
echo "           suggest output: $SUGGEST_OUT2"

if echo "$SUGGEST_OUT2" | grep -qE '^Follow untracked/T[0-9]+-t209-test\.md$'; then
    echo "           PASS: suggest prints 'Follow untracked/T<ID>-<slug>.md'"
else
    echo "           FAIL: suggest output did not match expected format"
    FAIL=1
fi

# ── Check 5: T209 — bundle template has deliverables= in meta header ───────
echo "        5. T209: bundle template has deliverables= in meta header"

LATEST_BUNDLE=$(cd "$TMPDIR" && ls untracked/T???-t209-test.md | tail -1)
META_LINE=$(head -1 "$TMPDIR/$LATEST_BUNDLE" 2>/dev/null)
echo "           meta: $META_LINE"

if echo "$META_LINE" | grep -q 'deliverables='; then
    echo "           PASS: bundle meta contains deliverables="
else
    echo "           FAIL: bundle meta missing deliverables=: $META_LINE"
    FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "  T204/T209: ALL CHECKS PASS"
else
    echo "  T204/T209: SOME CHECKS FAILED"
fi
exit "$FAIL"
