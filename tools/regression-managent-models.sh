#!/usr/bin/env bash
# regression-managent-models.sh
# T517 regression test: `managent models` exposes the canonical model list
# (the single source of truth) so the keeper / dispatch / subagent /
# watch-fleet can shell out to it instead of maintaining four duplicate lists.
#
# F7 (docs/audits/2026-08-20-fleet-and-model-audit.md): model canonicalization
# was implemented ×4 with four definitions (managent canonical_models[],
# bin/dispatch MODELS, bin/subagent CLAUDE_MODELS, watch-fleet mdl()), and the
# keeper's least-data picker listed only the five non-Claude models — so a
# model-less row could never draw a Claude label and the T503 exploration-first
# rule could not sample them.  This script asserts managent now EXPOSES the one
# canonical list (including every Claude label) as a queryable verb.
#
# Arms (no kanban store required — `models` is a pure static lookup):
#   1. `managent models` prints exactly canonical_models[], one per line, in
#      canonical order, to stdout; stderr is silent on stdout (banner only).
#   2. source/binary drift guard: the binary's output equals the labels parsed
#      from src/managent/main.zig canonical_models[] (no second copy drifted).
#   3. `managent models --json` prints a valid JSON array whose elements equal
#      the plain-text set, in the same order.
#   4. stdout/stderr separation: `2>/dev/null` emits the data; `1>/dev/null`
#      emits nothing on stdout (AGENTS.md stdout=data, stderr=diagnostics).
#   5. F7 acceptance — every Claude label in canonical_models[] is present in
#      the exposed list (the canonical list includes the Claude seats).
#   6. pure static — `managent models` does not read or create a kanban store:
#      pointed at a nonexistent MANAGENT_STORE path, no tasks.json is created.
#
# Usage:  tools/regression-managent-models.sh [--build]
#   --build: rebuild managent from source before testing
#
# Must be RED against the pre-T517 binary (no `models` verb → "unknown
# command", exit 1) before the fix lands, and GREEN after.

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
MG="$PROJECT/bin/managent"
SRC="$PROJECT/src/managent/main.zig"

FAIL=0

if [ "${1:-}" = "--build" ]; then
    echo "  rebuilding managent..."
    (cd "$PROJECT" && "$PROJECT/tools/runner" --no-prepend-zig -- zig build -Doptimize=ReleaseSafe 2>&1)
    "$PROJECT/tools/deploy.sh" "$PROJECT/zig-out/bin/managent" "$MG"
fi

if [ ! -x "$MG" ]; then
    echo "SKIP: no managent binary (build with 'zig build') — T517 needs it"
    exit 0
fi

mkdir -p /tmp/weizigo
TMPDIR="$(mktemp -d /tmp/weizigo/managent-models-XXXXXX)" || { echo "regression-managent-models.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
trap 'rm -rf "$TMPDIR"' EXIT

# Extract the canonical list straight from source (the same sed
# regression-dispatch.sh control 13 uses) — the binary must match this.
CANON_FROM_SOURCE="$(sed -n '/const canonical_models/,/^};/p' "$SRC" \
        | grep -oE '"[a-z0-9.:-]+"' | tr -d '"')"
CANON_COUNT="$(printf '%s\n' "$CANON_FROM_SOURCE" | grep -c .)"

echo ""
echo "  T517 regression: managent models (canonical list exposed, $CANON_COUNT models)"

# ── Arm 1: `managent models` prints exactly canonical_models[], one per line ─
echo "        1. managent models prints canonical_models[], one per line, in order"
OUT="$(cd "$TMPDIR" && "$MG" models 2>/dev/null)" || true
if [ "$(printf '%s\n' "$OUT" | grep -c .)" -ne "$CANON_COUNT" ]; then
    echo "           FAIL: expected $CANON_COUNT lines, got $(printf '%s\n' "$OUT" | grep -c .)"
    printf '%s\n' "$OUT" | sed 's/^/             | /'
    FAIL=1
else
    echo "           PASS: $CANON_COUNT models printed, one per line"
fi

# ── Arm 2: source/binary drift guard ────────────────────────────────────────
echo "        2. binary output matches canonical_models[] parsed from source (no drift)"
if [ "$OUT" = "$CANON_FROM_SOURCE" ]; then
    echo "           PASS: binary == source (order and labels identical)"
else
    echo "           FAIL: binary output diverges from src/managent/main.zig canonical_models[]"
    printf '%s\n' "$CANON_FROM_SOURCE" > "$TMPDIR/canon.src"
    printf '%s\n' "$OUT" > "$TMPDIR/canon.bin"
    diff "$TMPDIR/canon.src" "$TMPDIR/canon.bin" | sed 's/^/             | /' || true
    FAIL=1
fi

# ── Arm 3: --json prints a valid JSON array equal to the set, same order ─────
echo "        3. managent models --json prints a valid JSON array, same order"
JSON_OUT="$(cd "$TMPDIR" && "$MG" models --json 2>/dev/null)" || true
python3 - "$JSON_OUT" "$OUT" <<'PYEOF'
import sys, json
try:
    arr = json.loads(sys.argv[1])
except Exception as e:
    print("           FAIL: --json output is not valid JSON: %s" % e)
    print("             | " + sys.argv[1].replace("\n", "\n             | "))
    sys.exit(1)
expected = [l for l in sys.argv[2].split("\n") if l]
fails = []
if not isinstance(arr, list):
    fails.append("top-level is %s, not a list" % type(arr).__name__)
elif len(arr) != len(expected):
    fails.append("len=%d, expected %d" % (len(arr), len(expected)))
elif arr != expected:
    fails.append("order/content mismatch: got %r, expected %r" % (arr, expected))
if fails:
    for f in fails:
        print("           FAIL: " + f)
    sys.exit(1)
print("           PASS: --json array of %d models, same order as plain text" % len(arr))
PYEOF
if [ $? -ne 0 ]; then FAIL=1; fi

# ── Arm 4: stdout/stderr separation (AGENTS.md) ──────────────────────────────
echo "        4. stdout=data, stderr=diagnostics (2>/dev/null emits data, 1>/dev/null silent)"
DATA_ONLY="$(cd "$TMPDIR" && "$MG" models 2>/dev/null)" || true
STDOUT_ONLY="$(cd "$TMPDIR" && "$MG" models 2>&1 1>/dev/null)" || true
# 2>/dev/null must still emit the full data set on stdout.
if [ "$(printf '%s\n' "$DATA_ONLY" | grep -c .)" -ne "$CANON_COUNT" ]; then
    echo "           FAIL: 2>/dev/null dropped stdout data (got $(printf '%s\n' "$DATA_ONLY" | grep -c .) lines)"
    FAIL=1
else
    echo "           PASS: 2>/dev/null emits all $CANON_COUNT data lines on stdout"
fi
# 1>/dev/null must emit NO model label on stdout (stderr may carry the banner).
printf '%s\n' "$CANON_FROM_SOURCE" > "$TMPDIR/canon.leak"
LEAK="$(printf '%s\n' "$STDOUT_ONLY" | grep -E '^[a-z0-9.:-]+$' | grep -Ff "$TMPDIR/canon.leak" || true)"
if [ -n "$LEAK" ]; then
    echo "           FAIL: a model label leaked to stderr under 1>/dev/null:"
    printf '%s\n' "$LEAK" | sed 's/^/             | /'
    FAIL=1
else
    echo "           PASS: no model label on stdout under 1>/dev/null (banner stays on stderr)"
fi

# ── Arm 5: F7 acceptance — every Claude label in canonical_models[] is exposed ─
echo "        5. F7 — every canonical Claude label is present in the exposed list"
CLAUDE_FROM_SOURCE="$(printf '%s\n' "$CANON_FROM_SOURCE" | grep '^claude-')"
CLAUDE_N="$(printf '%s\n' "$CLAUDE_FROM_SOURCE" | grep -c .)"
MISSING=""
while IFS= read -r lbl; do
    [ -z "$lbl" ] && continue
    if ! printf '%s\n' "$OUT" | grep -Fxq "$lbl"; then
        MISSING="$MISSING $lbl"
    fi
done <<< "$CLAUDE_FROM_SOURCE"
if [ -n "$MISSING" ]; then
    echo "           FAIL: Claude labels missing from managent models:$MISSING"
    FAIL=1
else
    echo "           PASS: all $CLAUDE_N canonical Claude labels are exposed"
fi

# ── Arm 6: pure static — no kanban store read or created ─────────────────────
echo "        6. pure static — managent models does not read or create a kanban store"
EMPTY_DIR="$TMPDIR/empty-store"
mkdir -p "$EMPTY_DIR/docs/infra/managent"
NO_STORE="$EMPTY_DIR/docs/infra/managent/tasks.json"
# Point MANAGENT_STORE at a path that does NOT exist; run models; assert the
# file is still absent (no migration, no read, no create).
(cd "$EMPTY_DIR" && MANAGENT_STORE="$NO_STORE" "$MG" models 2>/dev/null) >/dev/null || true
if [ -e "$NO_STORE" ]; then
    echo "           FAIL: managent models created $NO_STORE (must not touch the store)"
    FAIL=1
else
    echo "           PASS: no tasks.json created — models is a pure static lookup"
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "  T517: ALL CHECKS PASS"
else
    echo "  T517: SOME CHECKS FAILED"
fi
exit "$FAIL"